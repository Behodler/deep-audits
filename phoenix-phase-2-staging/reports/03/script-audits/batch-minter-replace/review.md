# Script Review — `batch-minter-replace`

**Entry point:** `script/ReplaceBatchNFTMinter.s.sol:ReplaceBatchNFTMinter` (npm/forge script `batch-minter-replace`)
**Story:** 050 — redeploy fixed BatchNFTMinter, repoint SYA + BalancerPoolerV2, seed nudge pot from BPT, retire old contract
**Project:** `phoenix-phase-2-staging`
**Run:** `reports/phoenix-phase-2-staging/03`
**Mode:** fork-preview (impersonates `OWNER` via `vm.startPrank`, no broadcast)
**Fork block:** `25207560` (RPC_MAINNET head ~25207560–25207599 during the run)
**Preview command:** `PREVIEW_MODE=true forge script ...:ReplaceBatchNFTMinter --rpc-url $RPC_MAINNET --sender 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6 --slow -vvvv` → `Script ran successfully.` (no revert)

## Summary

`ReplaceBatchNFTMinter` is the Story-050 one-shot mainnet cutover that supersedes the
`DisableNudgeAndDivertDonations` stop-gap: it deploys the fixed, minter-pinned `BatchNFTMinter`,
configures it (`setTokenMinter` → `setDispatcherIndex(4)` → `setNudgePaymentToken(USDC)` →
`setNudgeSize(40)`), repoints the two real funders (`SYA.setNudgeAddress`,
`BalancerPoolerV2.setBatchMinter`), seeds the new USDC nudge pot from a proportional BPT exit
(sUSDS + phUSD → swap sUSDS→waUSDC→USDC, burn the phUSD leg), and neutralizes the old contract
(`setNudgePaymentToken(0)`, `setNudgeSize(0)`).

On the fork the script executes cleanly: **6/6 preconditions passed, all 13 observed state writes
are intended (zero unintended on-chain writes), and 3/3 postconditions passed.** The cutover
mechanically does what its NatSpec describes. The findings are not crashes or unintended writes —
they are *gaps between the script's stated intent ("so the nudge works again") and what the cutover
actually leaves behind*, plus a slippage-design weakness inherited from a sibling rescue script.

Two Medium findings (one borderline), two Low findings. No High. No regressions against the
existing ledger; the one ledger-adjacent risk (RestoreMintAtIndex4 M-01, the `mint(4)`
authorization gap) was checked and verified clean for this entry point.

| Label | Sev | Title | Record |
|-------|-----|-------|--------|
| BMR-M-01 | Medium | Cutover leaves `SYA.nudgeSplit` at 0 — repointed pot is never refunded by the claim path (incomplete migration) | `findings/medium/BMR-M-01-nudgesplit-zero-incomplete-migration.json` |
| BMR-M-02 | Medium *(borderline)* | Proportional BPT exit uses `minAmountsOut=[0,0]` — unbounded slippage on the seed swap | `findings/medium/BMR-M-02-bpt-exit-unbounded-slippage.json` |
| BMR-L-01 | Low | Retire guard `require(USDC.balanceOf(OLD)==0)` is dust-griefable, aborting the migration | `findings/low/BMR-L-01-retire-guard-grief.json` |
| BMR-L-02 | Low | Seed delta logged but never asserted at the script level (weak postcondition) | `findings/low/BMR-L-02-seed-delta-not-asserted.json` |

---

## 1. Does it do what it intends?

**Verdict: mechanically yes, but the stated purpose is only half-achieved.**

Every step of the Story-050 checklist executed on the fork, and every guard the script declares
held:

- **Preconditions (6/6 in `_guards()` + 4 sizing guards + the helper floor — all passed):**
  `tokenMinter != 0` (`0x39Af…E10F`), `dispatcherIndex == 4`, `nudgePaymentToken == USDC`,
  index-4 `dispatcher != 0` (POOLER `0x26F8…38A`), drift guard `primeToken == USDS` (`0xdC03…384F`),
  exploit guard `nudgePaymentToken != primeToken` (USDC != USDS), `poolSusdsValue > 0`
  (13396.5e18 USDS-eq), `poolerBpt > 0` (2214.4e18), `bptSlice (49.879e18) >= minBptWei (40e18)`,
  and the SeedSwapHelper floor `usdcReceived (50418020) >= minUsdcOut (47000000)`.
- **Writes (13/13 intended):** new minter deployed and configured; `SYA.nudge`
  `OLD_BATCH_MINTER → newMinter`; `pooler.batchMinter` `OWNER → newMinter`; BPT slice 49.879e18
  withdrawn; proportional exit released [45.999e18 sUSDS, 54.134e18 phUSD]; sUSDS→waUSDC→USDC
  unwound to **50.418 USDC** into the new pot; **54.134e18 phUSD burned**; old minter nudge config
  zeroed (idempotent — already 0 from the stop-gap).
- **Postconditions (3/3):** `SYA.nudge() == newMinter`, `BalancerPoolerV2.batchMinter() == newMinter`,
  `USDC.balanceOf(newMinter) > 0` (50.418 USDC seeded).

**The headline gap (BMR-M-01).** The predecessor stop-gap's *primary* funding cut was
`SYA.setNudgeSplit(0)` — `SYA.claim()` routes `nudgeSplit%` of each claim's USDC to `SYA.nudge`.
This cutover repoints the `nudge` *pointer* and seeds a one-time ~50.4 USDC bootstrap, **but never
calls `setNudgeSplit`** (full trace inspected — only `setNudgeAddress` is issued on SYA), and
`SYA.nudgeSplit()` is verified `== 0` both before and after the run. The pointer is restored but the
lever that makes the pointer meaningful is left at the stop-gap value: after the one-time seed is
consumed, the new minter receives **0% of every subsequent claim**, so the migrated nudge mechanism
is inert. The script reports success and `mainnet-addresses.ts` is rewritten, so an operator reading
the logs would reasonably believe the cutover is complete. This is the classic
*MissingPostStepConfiguration* intent-vs-claim mismatch and is the most consequential finding in
this review. See **BMR-M-01** (`findings/medium/BMR-M-01-nudgesplit-zero-incomplete-migration.json`;
root cause in `lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L385-L406`).

---

## 2. Does it introduce unintended side effects?

**Verdict: no unintended on-chain writes; one MEV/slippage exposure on an intended write.**

Side-effect diffing found **no state write beyond the stated-purpose set** — every observed write
is explained by the closure manifest's `mutated` list (`unintendedEffects: severity none`). The
transient legs (sUSDS routed through OWNER+helper, waUSDC minted then redeemed) are fully unwound.

The exposure is in *how* an intended write is performed. The proportional exit
`removeLiquidityProportional(LP_POOL, bptSlice, [0,0], false, "")` is called with **both per-leg
`minAmountsOut` hardcoded to 0** — directly contrary to the repo's NON-NEGOTIABLE Configuration
Safety rule ("a zero slippage bound is an open invitation to sandwich/MEV"). The *only* slippage
floor in the entire seed path is the single downstream `MIN_USDC_OUT = 47e6` inside `SeedSwapHelper`,
which covers only the sUSDS→USDC leg; against the observed 50.418e6 output that rejects only a
~6.8% haircut, and the **phUSD leg (54.134e18 burned) has no floor at all.** Because the broadcast
is a public, owner-signed mainnet tx (`--slow`, no private mempool noted), a searcher can move the
WeightedPool reserves around the exit and the StablePool around the swap to extract up to the USDC-leg
margin plus an unbounded share on the unfloored phUSD leg.

This is **BMR-M-02** (`findings/medium/BMR-M-02-bpt-exit-unbounded-slippage.json`;
`script/ReplaceBatchNFTMinter.s.sol#L366-L391`), and it is **flagged borderline for human review.**
At the as-run calibrated size the direct loss on the floored leg is small (~6.8% of ~50 USDC,
dust-adjacent), which alone would argue Low. It is held at Medium by three factors that are *not* the
observed haircut: (a) the phUSD leg is entirely unfloored, so that loss is genuinely unbounded rather
than capped at 6.8%; (b) `SEED_USDS_TARGET`/slice are env-overridable and a prior default was ~4×
larger, so exposure scales linearly with no new guard; and (c) it violates the repo's stated
non-negotiable slippage gate. A judge could reasonably land this at Low if the phUSD-leg loss is
shown to be de-minimis at the calibrated size and env-overrides are deemed out of scope — hence the
human-review flag.

---

## 3. Have other problems surfaced because of it?

**Verdict: it partially supersedes its predecessor and is verified clean against the one ledger-adjacent risk; two robustness defects round out the cluster picture.**

**Predecessor — `DisableNudgeAndDivertDonations` (3 shared addresses; strongest link).** The stop-gap
made three writes: `SYA.nudgeSplit = 0` (primary funding cut), `pooler.batchMinter = OWNER`, and
zeroed the old minter's nudge config. This cutover **overwrites the two pointers but not
`nudgeSplit`** — so it supersedes the stop-gap *only partially*. The pointer half is restored; the
funding half is not. This is exactly the mechanism behind **BMR-M-01** and is the central
cluster-interaction observation of the review.

**Skipped-step / sibling-config — `SetMinterOnIndex4Pooler` / `FixBalancerPoolerV2SetMinter` (ledger M-01 territory) — VERIFIED CLEAN.** The index-4 pooler's internal `_minter`
(base `ATokenDispatcherV2`, gates dispatch via `onlyMinter`) is **already** set to `NFTMinterV2`
(`0x39Af…E10F`) on-chain. This script calls only `setBatchMinter` (a *different* field) and never
touches `_minter`, so it **neither breaks nor re-introduces** the `mint(4)` authorization gap that
produced ledger M-01 for the sibling `RestoreMintAtIndex4`. `mint(4)` authorization is intact for
POOLER `0x26F8…38A`. Verified clean for this entry point — no regression.

**Origin — Story 047 (`DeployMainnetNudgePoolerV2`) and `RescuePoolAndDonateUSDC` (evidence).** The
deploy/config/repoint mechanics are copied from the original Story-047 deploy, and the
BPT→swap→seed→burn machinery (including the `minAmountsOut=[0,0]` pattern and the single downstream
USDC floor) is inherited from `RescuePoolAndDonateUSDC`. The slippage weakness in BMR-M-02 is
therefore a copied design, not a one-off.

**Two robustness defects (QA bundle):**

- **BMR-L-01 — retire-guard grief** (`findings/low/BMR-L-01-retire-guard-grief.json`;
  `script/ReplaceBatchNFTMinter.s.sol#L419-L427`). `_retireOld()` asserts
  `require(USDC.balanceOf(OLD_BATCH_MINTER) == 0)`. `balanceOf` is externally writable: a 1-wei USDC
  transfer to the old contract front-running the broadcast makes the require revert. Under the as-run
  single-tx path the revert rolls back atomically (no inconsistent state lands), so this is Low — but
  it is a cheap, repeatable grief that can hold the cutover hostage, and the guard does not actually
  prove what it claims (`balance==0` ≠ permanently drained). Trivially defeated by a private mempool.
- **BMR-L-02 — weak seed postcondition** (`findings/low/BMR-L-02-seed-delta-not-asserted.json`;
  `script/ReplaceBatchNFTMinter.s.sol#L388-L435`). The script computes
  `usdcOut = balanceOf(newMinter) - potBefore` and logs it but never `require()`s it `> 0` /
  `>= minUsdcOut` at the script level, and `MIN_USDC_OUT` is env-overridable with no
  `require(minUsdcOut > 0)` floor-on-the-floor. The helper floor held this run (unverified failure
  path), so it is a defense-in-depth gap — but if the floor were overridden to 0 a degenerate seed
  would pass silently and **compound BMR-M-01** (the migration would look complete while the new
  minter holds ~0 USDC). Naturally pairs with BMR-M-01 in the narrative.

---

## Cross-references

- **BMR-M-01 ↔ BMR-L-02:** the weak seed postcondition compounds the unfunded-pot problem — a 0/short
  seed on top of `nudgeSplit==0` would leave the new mechanism dead with no signal to the operator.
- **BMR-M-02 ↔ BMR-L-02:** both stem from the seed path; M-02 is the live slippage exposure, L-02 the
  missing script-level floor that would have caught a degenerate outcome.
- **BMR-L-01 ↔ BMR-M-02:** both are mitigated operationally by broadcasting through a private mempool.

## Recommendations (consolidated)

1. **Restore the funding lever (BMR-M-01):** add `SYA.setNudgeSplit(<intended %>)` to `_repoint()`
   with a `require(SYA.nudgeSplit() == intended)` postcondition; or, if deferral is intentional, say
   so explicitly in the header and progress JSON so the cutover is not mistaken for complete.
2. **Floor the exit legs (BMR-M-02):** derive non-zero per-leg `minAmountsOut` from the live Vault
   balances already read in `_seedFromBpt`, tighten `MIN_USDC_OUT` to a small slack over a fresh
   quote, `require()` all floors `> 0`, and consider a private mempool for the seed swap.
3. **Harden the retire guard (BMR-L-01):** gate retirement on the old contract's own non-attacker-
   writable config rather than its externally-writable USDC balance, or sweep the old USDC within
   the script instead of asserting someone else has.
4. **Assert the seed (BMR-L-02):** `require(minUsdcOut > 0 && minBptWei > 0)` at the top of the
   mainnet branch and `require(usdcOut >= minUsdcOut)` as a script-level postcondition before
   retire/persist.

---

*Verification basis: fork-preview at block ~25207560, `PREVIEW_MODE=true` (impersonated OWNER, no
broadcast). All four findings reconcile per `entryPoint=batch-minter-replace`; no collision with the
existing ledger's `RestoreMintAtIndex4` labels (BMR- prefix namespacing). BMR-M-02 is flagged for
human severity review.*
