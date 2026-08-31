# Script Audit Review — `dispatcher-replace-sky-pooler` (Story 056)

**Project:** phoenix-phase-2-staging
**Entry point:** `dispatcher-replace-sky-pooler` (`script/DispatcherReplaceSkyPoolerAtIndex4.s.sol:DispatcherReplaceSkyPoolerAtIndex4`)
**Submodule HEAD:** `0bbbe8ca1ed0cb57c38ea5bbfa0fa9a71642636f`
**Variants audited:** `:dry` (PREVIEW_MODE, owner-pranked, no broadcast) and `:broadcast` (ledger-signed, `--skip-simulation`, JS backup + patch wrappers)
**Verification:** mainnet fork at block **25241930** (`RPC_MAINNET`), fork-preview execution of the `:dry` path plus a dedicated mint-probe PoC.

## Summary

Story 056 cuts the NFTMinterV2 **index-4** dispatcher over from the live "nudge" `BalancerPoolerV2` (`0x26F8…b38A`) to a freshly deployed Sky-PSM-route `BalancerPoolerV2` plus a new `BalancerPoolerMintDebtHook`, migrating BPT and sUSDS, validating the Sky USDS→USDC `buyGem` donation route once, and finishing with a single-arg `pool(minBPT)`. The cutover is otherwise well-constructed: all 16 ordered steps execute, every one of the script's own pre/post-conditions passes on the fork (8/8 pre-conditions, post-conditions all green), and the JS backup/patch wrappers are self-validating against both the on-file and on-chain OLD addresses.

The audit surfaces **one Medium and one Low**:

- **M-01** — the cutover never calls `newPooler.setMinter(NFT_MINTER_V2)`, so the new dispatcher's `_minter` stays `address(0)` and every `mint(4)` reverts `"ATokenDispatcherV2: caller is not minter"` after broadcast. The script's dry-mode self-check passes green over this break (it never asserts `mint(4)`), so the defect can ship to production undetected. Fork-proven at block 25241930.
- **L-01** — the `:broadcast` variant runs `--skip-simulation` with an offline-derived, stale-able `minBPT` floor and no enforced live re-query.

A third candidate — the Ledger HD-derivation dependency (`m/44'/60'/46'/0/0` must resolve to `OWNER_ADDRESS`) — was **suppressed as a known admin-trust issue** (see "Suppressed findings" below).

---

## 1. Does it do what it intends?

**Intent vs. implementation: matched on every explicitly-stated step; broken on the one implicit load-bearing purpose.**

The stated purpose (NatSpec + Story-056 comment) decomposes into six explicit goals and one implicit one. All six explicit goals are implemented and fork-verified:

| Stated goal | Implementation | Fork result |
|---|---|---|
| Deploy Sky-route `BalancerPoolerV2` + new `BalancerPoolerMintDebtHook` | steps 4–5 | deployed, wired |
| Migrate old pooler BPT + sUSDS into new pooler | steps 8–9 (sweep to owner), 11 (re-seed) | oldPooler BPT→0, sUSDS→0; newPooler seeded |
| Re-point `configs[4].dispatcher` → newPooler, NFT id stays 4 | step 13 `replaceDispatcher(4,newPooler)` | `configs(4).dispatcher == newPooler` |
| Rotate hook; authorize newHook as phUSD minter; decommission oldHook | steps 6, 12, 14 | `dispatcherHook==newHook`; `MinterSet(newHook,true)/(oldHook,false)` |
| Validate Sky USDS→USDC `buyGem` route once (10% of swept sUSDS) | step 10 | USDC delta == gemAmt (64.419303 USDC), tout=0, conv=1e12 |
| Seed remaining ~90% sUSDS + BPT, call `pool(minBPT>0)` | steps 11, 15 | `pool()` minted +287.9 BPT, sUSDS→0, floor 284e18 held |

The script defends itself well. Its declared pre-conditions are real drift guards — `configs(4).dispatcher == LIVE_INDEX4_POOLER`, `NFTStaker.owner() == NFTMinterV2.owner() == OWNER_ADDRESS`, `oldHook.mintDebt() == 0` after `pullAndRefresh`, PSM `tout <= MAX_TOUT`, `minBPT > 0` on a real network — and all eight pass against live chain state at the fork block. Its post-conditions (`_step16_postStateLog`) assert the dispatcher pointer, hook rotation, BPT migration, and sUSDS drain, and all pass.

**The gap is the seventh, implicit goal.** The whole reason index 4 keeps NFT id 4 and merely re-points its dispatcher is that **`mint(4)` must keep working** after the cutover. That invariant is **neither asserted nor achieved**. `_step16_postStateLog` (lines 603–657) encodes no `mint(4)`/`_minter` check, so a dry run reports "All post-state invariants hold" while index 4 is left unmintable. The one invariant that matters most for the stated purpose is the one the spec is silent on. This is **M-01** and is detailed in Section 2.

**Verdict:** The script does everything it explicitly says, and its own checks all pass — but it does not achieve its load-bearing implicit purpose, and its self-check cannot tell the difference.

---

## 2. Does it introduce unintended side effects?

### 2.1 [M-01 / Medium] New dispatcher left unmintable — `setMinter` omitted (both variants)

**Finding record:** [`findings/medium/M-01-sky-pooler-cutover-missing-setminter.json`](../../findings/medium/M-01-sky-pooler-cutover-missing-setminter.json)
**Code location:** `script/DispatcherReplaceSkyPoolerAtIndex4.s.sol` lines 603–657 (`_step16_postStateLog`), root cause is the absence of any `newPooler.setMinter(NFT_MINTER_V2)` call across steps 3–15.
**Fingerprint:** `85d794b386b15b201963dc03cdc36b8607f1a87b45e939323af0b1563d38aea7`

The script deploys a fresh `BalancerPoolerV2` (an `ATokenDispatcherV2`), re-points `configs(4).dispatcher` to it (step 13), rotates the phUSD mint hook (steps 6/14), migrates BPT, and drains sUSDS — but **never calls `newPooler.setMinter(NFT_MINTER_V2)`**. The freshly deployed dispatcher's internal `_minter` therefore stays at its default `address(0)`. `NFTMinterV2.mint(4)` routes through `dispatcher.dispatch()`, gated by the `onlyMinter` modifier `require(msg.sender == _minter, "ATokenDispatcherV2: caller is not minter")`; with `_minter == address(0)` that require can never pass, so **every `mint(4)` reverts the moment the cutover broadcasts**, for every caller, until a privileged owner follow-up transaction is sent.

The two variants fail differently and compoundingly:

- **`:dry`** produces a **FALSE GREEN.** `_step16_postStateLog` verifies the dispatcher pointer, hook rotation, BPT migration, and sUSDS drain, but never asserts `mint(4)`/`_minter`, so the preview reports all invariants holding over a broken cutover.
- **`:broadcast`** then **actually ships the break.** Steps 3–14 re-point the dispatcher and sweep funds, but the missing `setMinter` leaves `_minter == address(0)` on the now-live index-4 dispatcher.

**No assets are at risk** — user funds, BPT, and the migrated sUSDS/Sky-route positions remain safe and fully recoverable — which is why this is Medium, not High under C4 (availability/function impact without asset loss, recoverable by a single privileged `setMinter` transaction). But the availability break is total for the affected function, ships via the audited code path with no attacker and no special conditions, and reaches production behind a green self-check.

**Fork proof (block 25241930):** the storage slot confirms the asymmetry — the **old** pooler's dispatcher `_minter` slot holds `0x39Af…2e10f` (`NFT_MINTER_V2`, set by the Story-048 `SetMinterOnIndex4Pooler` back-fill), while the **new** pooler starts at `0` and the script never restores it. The PoC `test_mint4_reverts_after_cutover_alone` reverts with exactly `"ATokenDispatcherV2: caller is not minter"`; the companion `test_mint4_succeeds_once_setMinter_applied` passes only once `newPooler.setMinter(NFT_MINTER_V2)` is applied.

**PoC reproduction:**

```bash
cd workspace/phoenix-phase-2-staging
source ../../.envrc   # RPC_MAINNET, ETHERSCAN_API_KEY
forge test \
  --match-path test/AuditSkyPoolerMintIndex4.t.sol \
  --fork-url "$RPC_MAINNET" \
  --fork-block-number 25241930 \
  -vvv
```

**Remediation:**
1. Add `newPooler.setMinter(NFT_MINTER_V2)` to the cutover sequence (mirroring the predecessor's `SetMinterOnIndex4Pooler.s.sol`) so the fresh dispatcher's `_minter` is authorized **atomically** as part of the broadcast.
2. Add a `mint(4)` post-condition smoke assertion to `_step16_postStateLog` — e.g. assert `newPooler.minter() == NFT_MINTER_V2`, or a static-call `mint(4)` probe — so the dry run **can no longer ship green over a bricked mint path**.

### 2.2 Transient owner custody of BPT + sUSDS (intended / atomic)

All migrated BPT (4515e18) and swept sUSDS (586.34e18) transit through `OWNER_ADDRESS` (an EOA) mid-cutover (steps 8/9 sweep → step 11 re-seed) before landing in the new pooler. This is **intended** by design (sweep-then-reseed) and is atomic within a single broadcast transaction, so it is **not a standalone finding**. It is recorded for completeness: a mid-script failure between steps 8/9 and 11 would park protocol funds on the owner EOA, recoverable by the owner.

### 2.3 `:broadcast`-specific surface

**JS backup + patch wrappers — clean.** The pre-step `backup-mainnet-addresses.js` is copy-only (writes a timestamped snapshot, mutates nothing). The post-step `patch-mainnet-addresses-dispatcher-replace-sky-pooler.js` patches `mainnet-addresses.ts` only after matching CREATE txs **by exact `contractName`** (`BalancerPoolerV2`, `BalancerPoolerMintDebtHook`), not positional ordering — so the nested `DefaultDispatchHook` deployed inside the `ATokenDispatcherV2` constructor (recorded as an inner `additionalContracts` entry, not a top-level CREATE) does not break the `creates.length === 2` guard. The patch's OLD-address expectations (`0x26f8…b38a` pooler, `0x1427…727e` hook) match **both** `mainnet-addresses.ts` and live chain, so it will not refuse (exit 3) on a clean single run. This was cross-checked against the predecessor's `broadcast/DispatcherReplaceAtIndex4.s.sol/1/run-latest.json` (exactly two top-level CREATEs in the same order).

**`--skip-simulation` + offline stale-able `minBPT` — see L-01 below.**

### 2.4 [L-01 / Low] `--skip-simulation` with an offline-derived stale-able `minBPT` (`:broadcast`)

**Finding record:** [`findings/low/L-01-skip-simulation-stale-minbpt.json`](../../findings/low/L-01-skip-simulation-stale-minbpt.json)
**Code location:** `script/DispatcherReplaceSkyPoolerAtIndex4.s.sol` lines 542–602 (`_step15_pool`); `DEFAULT_MIN_BPT = 284e18` at line 108; broadcast command at script header line 55.
**Fingerprint:** `d32e99aa64bb082b2a761fabc74a6ad999f7a83db3a82a938214be7a1b2410f1`

The final step seeds the pool and calls `pool(minBPT)` with `minBPT` as a slippage **floor**. `minBPT` defaults to `DEFAULT_MIN_BPT = 284e18`, derived **offline** from a one-time Balancer Router ideal-BPT quote against a snapshot of seed/pool state (overridable via `MIN_BPT_WEI`). The documented broadcast command runs `--skip-simulation --slow`, so forge does not pre-execute `pool(minBPT)` against current live state. The seed is read live (partially self-correcting), but the floor is not re-queried live, and the code comment itself instructs the operator to "Re-query before broadcast if state moved" — making safety depend on an out-of-band operator step.

Two bounded, operator-conditioned tail risks: (a) a too-**high** stale floor reverts `pool()` **after** the irreversible steps 3–14 have applied, stranding a half-applied cutover needing manual repair; (b) a too-**low** stale floor weakens slippage protection on the single LP add. Both require material pool/seed drift beyond the held margin **and** the operator skipping the documented re-query. At the audit block a ~1.4% margin held (seed 527.80 sUSDS, 287.9 BPT minted vs the 284e18 floor), so no value leak was demonstrated under realistic conditions — hence **Low**.

**Remediation:** re-derive `minBPT` live inside `_step15_pool` via `queryAddLiquidityUnbalanced` against the actual current seed (applying the slippage bps to the live quote), or refuse to broadcast unless `MIN_BPT_WEI` is explicitly supplied for the current state. If `--skip-simulation` must be retained for `--slow` nonce sequencing, add an in-script live freshness assert so a drifted floor aborts **before** the irreversible steps rather than at the final `pool()`.

---

## 3. Have other problems surfaced because of it? (cluster / knock-on)

### 3.1 The skipped-step sibling confirms M-01 is part of the spec

`SetMinterOnIndex4Pooler.s.sol` (Story 048, shared addresses `NFT_MINTER_V2`, `LIVE_INDEX4_POOLER`) exists **precisely to authorize `NFTMinterV2` as the minter on a fresh index-4 pooler** — it was the back-fill for Story-048 cutover step 11, which had been skipped on the original V1→V2 cutover. The Sky cutover here mirrors `batchMinter` but does **not** re-run a `setMinter` equivalent. This is direct corroboration that `setMinter` is a required wiring step of an index-4 pooler swap, not an optional nicety — i.e. **M-01 is a re-occurrence of a known spec step, omitted again** on a new pooler. (The classifier records M-01 as the same root-cause class as the ledger's open `RestoreMintAtIndex4` finding, but a distinct per-entry-point fingerprint — not a regression.)

### 3.2 Predecessor state holds

The predecessor `DispatcherReplaceAtIndex4` (Story 048) state is intact at the fork block: the old nudge pooler and old hook are live, index-4 is wired (`configs(4) == LIVE_INDEX4_POOLER`, `dispatcherHook == 0x1427…727e`), and all relevant owners (`NFTStaker`, `NFTMinterV2`, `PHUSD`, `oldPooler`) resolve to `OWNER_ADDRESS` `0xCad1…D0B6`. The cutover's drift guards therefore fire against a known-good baseline.

### 3.3 `SetBatchDonationSizeIndex4` inheritance — healthy

The cutover mirrors `batchDonationSize` from the **live** old pooler onto the new pooler (step 7), so it inherits whatever value is on chain — including, hypothetically, a zeroed one. At the fork block the live `batchDonationSize == 10`, so the mirror carries a healthy value. No issue under current state.

### 3.4 The `MaxImbalanceRatioExceeded` trail is genuinely resolved, not merely bypassed

The `TempSimulate40MintsIndex4` / `DisableNudgeAndDivertDonations` cluster (plus the `FixBalancerPoolerV2SetMinter` family) is the surfaced-problem trail that motivated this Story-056 cutover: the live index-4 pooler's `pool()` reverts on `MaxImbalanceRatioExceeded`, and donations had to be diverted/disabled as a stop-gap. This cutover's headline fix is rerouting donations through the **Sky PSM `buyGem`** path. The fork validation confirms the reroute **actually works** — step 10's `buyGem(batchMinter, gemAmt)` succeeds with `USDC delta == gemAmt` (tout=0, conv=1e12), and the final `pool()` mints +287.9 BPT without tripping the imbalance guard. The underlying problem is **genuinely resolved by the Sky-PSM route**, not merely worked around.

---

## Suppressed findings

- **Ledger HD-derivation dependency (Low, suppressed — admin-trust known issue).** The broadcast signs with `--ledger --hd-paths "m/44'/60'/46'/0/0"`; if HD index 46 does not derive `OWNER_ADDRESS` `0xCad1…D0B6`, the broadcast reverts on the first `onlyOwner` call (`pullAndRefresh`). This cannot be verified without the physical Ledger. It is **suppressed as a known admin-trust issue** (reckless/incorrect admin key configuration is out of scope per the project's known-invalid list); the operator-confirmation requirement is noted here for operational completeness, not raised as a finding. All four ownership reads resolve to `0xCad1…D0B6` on live chain, so the configured signer is correct **if** the Ledger derives that address.

---

## Findings index

| Label | Severity | Title | Variant | Record |
|---|---|---|---|---|
| M-01 | Medium | Sky-pooler cutover leaves index-4 unmintable: `newPooler._minter` never set, `mint(4)` reverts | both | [medium/M-01-…json](../../findings/medium/M-01-sky-pooler-cutover-missing-setminter.json) |
| L-01 | Low | Broadcast uses `--skip-simulation` with an offline-derived stale-able `minBPT`; no live re-query enforced | broadcast | [low/L-01-…json](../../findings/low/L-01-skip-simulation-stale-minbpt.json) |

**Fork verification block:** 25241930 (mainnet, chainId 1). Variant executed for state-write capture: `:dry` (PREVIEW_MODE, owner-pranked). M-01 PoC: `workspace/phoenix-phase-2-staging/test/AuditSkyPoolerMintIndex4.t.sol` (validated 2026-06-04).
