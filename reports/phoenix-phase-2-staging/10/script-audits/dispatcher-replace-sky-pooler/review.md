# Script Audit Review (Regression) — `dispatcher-replace-sky-pooler` (Story 056)

**Project:** phoenix-phase-2-staging
**Entry point:** `dispatcher-replace-sky-pooler` (`script/DispatcherReplaceSkyPoolerAtIndex4.s.sol:DispatcherReplaceSkyPoolerAtIndex4`)
**Submodule HEAD:** `30775401304c1ff622206c19fc404c1a1d16ac53` (prior audited `0bbbe8ca1ed0cb57c38ea5bbfa0fa9a71642636f`, run `phoenix-phase-2-staging-09`)
**Mode:** Regression follow-up. The forge target was rewritten (approx. **+250/-58**) specifically to remediate run-09 **M-01**.
**Variants audited:** `:dry` (PREVIEW_MODE, owner-pranked, no broadcast) and `:broadcast` (ledger-signed, `--skip-simulation`, JS backup + patch wrappers)
**Verification:** mainnet fork at block **25242176** (`RPC_MAINNET`, chainId 1), fork-preview execution of the `:dry` path end-to-end, plus two dedicated mint-probe PoCs.

---

## Regression verdict

| | |
|---|---|
| **M-01 (Medium)** | **FIXED** (empirical) — ledger status `acknowledged` is preserved (authoritative human triage); the audit **proposes** `/ledger phoenix-phase-2-staging` to mark it `fixed`. |
| **L-01 (Low)** | **STILL-OPEN (mitigated)** — the stranding sub-impact is neutralized; weak-slippage / silent-LP-deferral residual persists. Remains a valid Low. |
| **New findings** | **0.** No new material issue introduced by the rewrite. |
| **Cluster / knock-on** | **Clean.** All previously-standalone wiring steps are folded inline and asserted; no new skipped-step gap. |
| **Fork** | block **25242176** (mainnet, chainId 1); `:dry` preview ran clean end-to-end through step 17. |

This is a follow-up re-verification, not a fresh discovery. The two findings below are reconciliations of the run-09 baseline against HEAD `30775401`; no new findings were opened.

---

## 1. Does it do what it intends?

**Intent vs. implementation: matched on every stated step, and — newly in this revision — on the load-bearing implicit purpose that run-09 flagged as broken.**

Story 056 cuts the NFTMinterV2 **index-4** dispatcher over from the live "nudge" `BalancerPoolerV2` (`0x26F8…b38A`) to a freshly deployed Sky-PSM-route `BalancerPoolerV2` plus a new `BalancerPoolerMintDebtHook`, migrating BPT and sUSDS, validating the Sky USDS→USDC `buyGem` donation route once, and finishing with a single-arg `pool(minBPT)`. NFT id 4 and the NFTStaker binding (stakedId=4 / dispatcherIndex=4) are unchanged — only `configs[4].dispatcher` flips.

The `:dry` preview executed clean **end-to-end through step 17** on the fork (no revert). Every one of the script's declared pre-conditions passed against live chain state at the fork block, and every post-condition passed:

| Stated goal | Implementation | Fork result @ 25242176 |
|---|---|---|
| Deploy Sky-route `BalancerPoolerV2` + new `BalancerPoolerMintDebtHook` | steps 4–5 | deployed, wired |
| **Authorize NFTMinterV2 as the new pooler's `_minter`** so `mint(4)` keeps working | **step 6 (NEW): `newPooler.setMinter(NFT_MINTER_V2)` + `require(vm.load(slot1)==NFT_MINTER_V2)`** | `_minter == NFT_MINTER_V2`, asserted on both variants — the M-01 fix |
| Migrate old pooler BPT + sUSDS into new pooler | steps 8–9 (sweep to owner), 11 (re-seed) | oldPooler BPT→0, sUSDS→0; newPooler seeded |
| Re-point `configs[4].dispatcher` → newPooler, NFT id stays 4 | step 13 `replaceDispatcher(4,newPooler)` | `configs(4).dispatcher == newPooler` |
| Rotate hook; authorize newHook as phUSD minter; decommission oldHook | steps 6, 12, 14 | `dispatcherHook==newHook`; `MinterSet(newHook,true)/(oldHook,false)` |
| Validate Sky USDS→USDC `buyGem` route once (10% of swept sUSDS) | step 10 | USDC delta == gemAmt (64.419519 USDC), tout=0, conv=1e12 |
| Seed remaining ~90% sUSDS + BPT, call `pool(minBPT>0)` | steps 11, 17 (try/catch) | `pool()` minted +293.6 BPT (preview), sUSDS→0, floor 284e18 held |
| **Prove index 4 remains mintable post-cutover** | **step 16 (NEW, preview-only): deal USDS, `mint(4)`, assert NFT +1 + hook debt** | `mint(4)` succeeds, id-4 balance 0→1, hook mintDebt accrued |

The script's drift guards remain real and all fire green against live chain: `configs(4).dispatcher == LIVE_INDEX4_POOLER (0x26F8…b38A)`, `NFTStaker.owner() == NFTMinterV2.owner() == OWNER_ADDRESS (0xCad1…D0B6)`, `oldHook.mintDebt() == 0` after `pullAndRefresh`, PSM `tout <= MAX_TOUT`, `minBPT > 0` on a real network, and the **new** `poolerAuthVersion(OWNER) == authVersion` and `slot1 == NFT_MINTER_V2` checks.

**Closure of the run-09 gap.** Run-09 found that the script did everything it explicitly said but did not achieve its one load-bearing implicit purpose — `mint(4)` keeping working — and that its self-check could not tell the difference (`_step*_postStateLog` never asserted `mint(4)`/`_minter`). HEAD `30775401` closes that gap on both fronts: it (a) performs the missing wiring (`setMinter` at step 6), (b) hard-asserts it via a raw-storage `require` that runs on the broadcast path, and (c) adds a preview-only end-to-end `mint(4)` smoke test (step 16). The script now refuses to proceed with an unwired dispatcher.

**Verdict:** The script does everything it explicitly states, its own pre/post-conditions all pass, and — unlike run-09 — it now both achieves and self-checks the load-bearing implicit purpose. **Intent is fully met.**

---

## 2. Does it introduce unintended side effects?

**No new material side effects.** The rewrite (+250/-58) is additive wiring plus assertions; it does not change the cutover's fund-movement topology, the JS backup/patch wrappers, or the broadcast surface beyond folding previously-standalone steps inline. The captured state writes match intent exactly.

### 2.1 Intended on-chain writes (all verified on the fork)

| Contract | Write | Intended |
|---|---|---|
| `BalancerPoolerV2` (newPooler, deployed) | constructed; **slot1 `_minter = NFT_MINTER_V2`** (step 6 fix); hook / `batchDonationSize=10` / `batchMinter` / `psm=SKY_PSM` / `maxTout=1%` / poolerAuth set; seeded sUSDS+BPT; `pool()` mints BPT | yes |
| `BalancerPoolerMintDebtHook` (newHook, deployed) | constructed `dispatcher=newPooler`; recipient → NFTStaker | yes |
| `BalancerPoolerV2` (oldPooler `0x26F8…b38A`) | BPT 4515.272e18 → 0 (`withdrawBPT`), sUSDS 586.341e18 → 0 (`rescueERC20`) | yes |
| `NFTMinterV2` (`0x39Af…2e10f`) | `configs[4].dispatcher` 0x26F8…b38A → newPooler (+ index/tokenId maps) | yes |
| `NFTStaker` (`0xc851…a13b`) | `dispatcherHook` oldHook → newHook (+ reward-schedule recompute) | yes |
| `PHUSD` (`0xf3B5…D605`) | `authorizedMinters[newHook]=(true)`, `authorizedMinters[oldHook]=(false)` | yes |
| Sky PSM / sUSDS / USDS / USDC | redeem 10% sUSDS→USDS; `buyGem` USDS→USDC to batchMinter (delta 64.419519 USDC); LP add via Balancer vault | yes |

All intended; no unexpected writes captured.

### 2.2 Transient owner custody of BPT + sUSDS (intended / atomic — unchanged)

All migrated BPT (4515e18) and swept sUSDS (586e18) transit through `OWNER_ADDRESS` (an EOA) mid-cutover (steps 8/9 sweep → step 11 re-seed). This is intended sweep-then-reseed design, atomic within one broadcast transaction, and recoverable by the owner — **not a standalone finding**, carried over unchanged from run-09.

### 2.3 Preview-vs-broadcast seeding delta — INFO-ONLY, explicitly NOT a finding

The new preview-only step 16 (`mint(4)`) wraps USDS→sUSDS into the new pooler **before** the preview's step-17 `pool()`. As a result the **preview** seeds ~538.4 sUSDS and mints ~293.6 BPT, whereas a **real broadcast** (where step 16 never runs, gated behind `isPreview`) seeds ~527.8 sUSDS and mints ~287.9 BPT. The preview's `pool()` is therefore not a perfectly faithful `minBPT` calibration.

This is recorded as **information only and is explicitly NOT a finding**: the `DEFAULT_MIN_BPT = 284e18` floor holds with margin in **both** cases (preview ~293.6 BPT, broadcast ~287.9 BPT, both ≥ 284e18). The delta is a benign artifact of the belt-and-suspenders e2e proof being preview-only; it does not affect broadcast behavior or the floor's adequacy.

### 2.4 `:broadcast`-specific surface — unchanged and clean

The JS backup (`backup-mainnet-addresses.js`, copy-only) and patch (`patch-mainnet-addresses-dispatcher-replace-sky-pooler.js`, exactly-2-CREATE match by `contractName`, OLD-address self-validation guard) wrappers are **unchanged from run-09** and remain clean — the nested `DefaultDispatchHook` is an inner `additionalContracts` entry, not a top-level CREATE, so the `creates.length === 2` guard holds. The only residual broadcast concern is the `--skip-simulation` / stale-`minBPT` issue, reconciled as **L-01** below.

---

## Reconciled findings

### M-01 [Medium] — FIXED (proposed)

> Sky-pooler cutover leaves index-4 unmintable: `newPooler._minter` never set to NFTMinterV2, `mint(4)` reverts

- **Finding record:** [`findings/medium/M-01-sky-pooler-cutover-missing-setminter.RECONCILED.json`](../../findings/medium/M-01-sky-pooler-cutover-missing-setminter.RECONCILED.json)
- **Source location:** `script/DispatcherReplaceSkyPoolerAtIndex4.s.sol` — fix at `_step6_wireNewHook` (lines 340–372); root-cause surface `lib/yield-claim-nft/src/V2/dispatchers/ATokenDispatcherV2.sol:44-87` (`onlyMinter` gate / `setMinter`).
- **Fingerprint:** `85d794b386b15b201963dc03cdc36b8607f1a87b45e939323af0b1563d38aea7`
- **Ledger status:** `acknowledged` (human triage, authoritative — **not** auto-flipped). **Empirical verdict: FIXED.** Proposed action: `/ledger phoenix-phase-2-staging` to mark M-01 / fingerprint `85d794b3…` fixed.

**The fix.** The rewrite adds, at step 6, `BalancerPoolerV2(newPooler).setMinter(NFT_MINTER_V2)`, immediately guarded by an unconditional, fail-closed `require(vm.load(newPooler, slot1) == NFT_MINTER_V2)`. Both statements run on the **broadcast** path (not gated by `isPreview`), so if `setMinter` ever failed to take, the `require` aborts the broadcast **before** `replaceDispatcher(4, …)` — the cutover can no longer commit with an unwired dispatcher. A preview-only end-to-end `mint(4)` proof (step 16) is added as additional, belt-and-suspenders evidence.

**Empirical verification (three independent ways, fork block 25242176):**
1. **Run-09 reproduction PoC** `test/AuditSkyPoolerMintIndex4.t.sol` — `test_mint4_reverts_after_cutover_alone` **no longer reverts** (its `expectRevert` now fails because `mint(4)` succeeds). This is the strongest "fixed" signal under recheck semantics — the bug-reproduction expectation no longer holds, and the PoC still **compiles** (so this is a genuine fix, not bit-rot).
2. **New PoC** `test/AuditSkyPoolerMintIndex4_Fixed.t.sol` — `test_mint4_succeeds_after_cutover_alone_FIXED` **passes**: after the cutover runs **alone** (no follow-up tx), a fresh `USER` mints one id-4 NFT.
3. **Preview step 16** mints one id-4 NFT to the owner (balance 0→1, hook mintDebt accrued).

**Original concern-flags validated.** The two open questions from the regression brief are both resolved:
- *Is slot1 truly `_minter` for this freshly-deployed bytecode?* **Yes.** `ATokenDispatcherV2` layout is `slot0 = Pausable._paused (low byte) packed with Ownable._owner`, `slot1 = _minter`. Confirmed via post-deploy `vm.load` on the freshly-deployed pooler (`== 0x39Af…2e10f`) **and** live `cast storage` slot1 on the existing pooler. Identical bytecode ⇒ identical layout.
- *Is the broadcast-only path sufficient given step 16 is preview-only?* **Yes.** The step-6 `setMinter` + `require(slot1==…)` run **unconditionally** on broadcast and fail closed; the preview e2e mint is additional, not the sole guarantee.

**No assets were ever at risk** (the run-09 break was an availability/function impact, recoverable by a single privileged tx); the rewrite removes the break entirely.

**PoC reproduction:**

```bash
cd workspace/phoenix-phase-2-staging
source ../../.envrc   # RPC_MAINNET, ETHERSCAN_API_KEY
# (i) run-09 reproduction now fails its expectRevert (fix confirmed, still compiles):
forge test --match-path test/AuditSkyPoolerMintIndex4.t.sol \
  --fork-url "$RPC_MAINNET" --fork-block-number 25242176 -vvv
# (ii) fresh-user mint after cutover alone passes:
forge test --match-path test/AuditSkyPoolerMintIndex4_Fixed.t.sol \
  --fork-url "$RPC_MAINNET" --fork-block-number 25242176 -vvv
```

PoC paths:
- `workspace/phoenix-phase-2-staging/test/AuditSkyPoolerMintIndex4.t.sol` (run-09 reproduction; now fails-to-revert = fixed)
- `workspace/phoenix-phase-2-staging/test/AuditSkyPoolerMintIndex4_Fixed.t.sol` (fresh-user post-cutover mint; passes)

### L-01 [Low] — STILL-OPEN (mitigated)

> Broadcast uses `--skip-simulation` with an offline-derived stale-able `minBPT`; no live re-query enforced

- **Finding record:** [`findings/low/L-01-skip-simulation-stale-minbpt.RECONCILED.json`](../../findings/low/L-01-skip-simulation-stale-minbpt.RECONCILED.json)
- **Source location:** `script/DispatcherReplaceSkyPoolerAtIndex4.s.sol` — `_step17_finalPool` (lines 692–770); `DEFAULT_MIN_BPT = 284e18` at line 109; broadcast `--skip-simulation` at `package.json` line 183. Root-cause surface `lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol:269-275` (`pool`).
- **Fingerprint:** `d32e99aa64bb082b2a761fabc74a6ad999f7a83db3a82a938214be7a1b2410f1`
- **Ledger status:** `open` (low) — unchanged.

**What is unchanged.** The `:broadcast` variant still runs `--skip-simulation`, and `minBPT` is still supplied from the offline-derived `DEFAULT_MIN_BPT = 284e18` (or `MIN_BPT_WEI` env), with **no live in-script re-query**. The Balancer V3 `queryAddLiquidityUnbalanced` quote still cannot run from a tx frame (`NotStaticCall`), so the floor remains an offline constant the operator must refresh per the code comment. The seed is read live (partially self-correcting); the floor is not.

**What the rewrite mitigated.** `pool()` is now wrapped in a **try/catch** (step 17). A too-high stale floor that reverts `pool()` no longer rolls back or strands the already-committed dispatcher cutover — it logs "LP add DEFERRED", parks the seeded sUSDS recoverably, and the owner re-pools later with a fresh `minBPT`. **Fork-proven (block 25242176):** forcing `MIN_BPT_WEI=1e23` reverts `pool()`, but the cutover (`replaceDispatcher`, hook rotation) stays committed, the step-16 `mint(4)` still succeeds, and the sUSDS parks recoverable. The run-09 worst case — a stale-too-high `minBPT` stranding a half-applied cutover — is neutralized.

**Residual (keeps L-01 open).** A stale-**too-low** floor still weakens slippage protection on the single LP add (no in-script auto-detection); a stale-**too-high** floor silently defers the LP add (sUSDS parks un-LP'd until a manual re-pool). Both require pool/seed drift beyond the held margin **and** the operator skipping the documented `MIN_BPT_WEI` re-query. At the audit block a margin held (broadcast-equivalent seed ~527.8 sUSDS → ~287.9 BPT vs the 284e18 floor), so no value leak was demonstrated under realistic conditions — hence it **remains a Low**, mitigated but not closed.

**Remediation:** re-derive `minBPT` live before broadcast via the documented `cast queryAddLiquidityUnbalanced` for the actual current seed and set `MIN_BPT_WEI` explicitly; or refuse to broadcast unless `MIN_BPT_WEI` is supplied for current state. The try/catch isolation is a good safety net but does not remove the stale-floor / weak-slippage residual.

---

## 3. Have other problems surfaced? (cluster / knock-on)

**Cluster is clean. No new skipped-step gap, no knock-on regression.** The rewrite's headline effect on the cluster is that several previously-standalone operational scripts are now **redundant** because their action is folded inline and asserted:

- **`SetMinterOnIndex4Pooler` — REDUNDANT.** Its `setMinter(NFT_MINTER_V2)` is folded inline at step 6 with the slot1 `require`. Confirmed equivalent (same call, same `_minter` slot). No separate run needed.
- **`FixBalancerPoolerV2SetMinter` — REDUNDANT.** Same inline fix; the historical mainnet hotfix that originally proved M-01 in production is no longer needed for this cutover.
- **`AuthorizeOwnerAsPoolerV2` — REDUNDANT.** `setAuthorizedPooler(OWNER,true)` is folded at step 7 with a `poolerAuthVersion(OWNER)==authVersion` assertion; the owner is verified authorized on the new pooler (and `pool()` succeeded as OWNER on the fork).

Remaining wiring is all present and asserted on the new pooler:
- `setBatchDonationSize` mirrors the live value **`= 10`** (healthy, not zeroed) from the old pooler.
- `setBatchMinter` mirrors the current live `BatchNFTMinter` (`0x6e98…5071`, Story 050); the validation `buyGem` delivered USDC to it correctly.
- `setPSM(SKY_PSM)` and `setMaxTout(1%)` are wired; the Sky USDS→USDC donation route is exercised end-to-end (auto-donation inside `_dispatch` during the step-16 mint, plus the step-10 manual validation).
- `NFTStaker.setDispatcherHook(newHook)` is done (step 12) and asserted; the hook recipient is set to NFTStaker (step 6).

**No new skipped-step gap** — every previously-standalone wiring step is folded inline and asserted, which is precisely what closed M-01. The `MaxImbalanceRatioExceeded` trail (`TempSimulate40MintsIndex4` / `DisableNudgeAndDivertDonations` / `FixBalancerPoolerV2SetMinter` family) that motivated this Story-056 cutover remains genuinely resolved by the Sky-PSM `buyGem` reroute, confirmed by the clean step-10 validation and the floor-respecting final `pool()`.

---

## Findings index

| Label | Severity | Regression verdict | Title | Variant | Record |
|---|---|---|---|---|---|
| M-01 | Medium | **FIXED** (proposed; ledger `acknowledged`) | `newPooler._minter` never set → `mint(4)` reverts | both | [medium/M-01-…RECONCILED.json](../../findings/medium/M-01-sky-pooler-cutover-missing-setminter.RECONCILED.json) |
| L-01 | Low | **STILL-OPEN (mitigated)** | `--skip-simulation` + offline stale-able `minBPT` | broadcast | [low/L-01-…RECONCILED.json](../../findings/low/L-01-skip-simulation-stale-minbpt.RECONCILED.json) |

**Fork verification block:** 25242176 (mainnet, chainId 1). Variant executed for state-write capture and the preview e2e mint: `:dry` (PREVIEW_MODE, owner-pranked), clean through step 17.
**M-01 PoCs:** `workspace/phoenix-phase-2-staging/test/AuditSkyPoolerMintIndex4.t.sol`, `workspace/phoenix-phase-2-staging/test/AuditSkyPoolerMintIndex4_Fixed.t.sol`.
**Proposed ledger action:** `/ledger phoenix-phase-2-staging` — mark M-01 (`85d794b3…`) fixed; leave L-01 open with a note that the stranding sub-impact is resolved.
**New findings introduced by the rewrite:** none (the preview-vs-broadcast seeding delta in §2.3 is info-only).
