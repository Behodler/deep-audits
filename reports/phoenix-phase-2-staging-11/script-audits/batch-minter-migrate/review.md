<!--
Script-audit review
Project: phoenix-phase-2-staging
Run: phoenix-phase-2-staging-11
Entry point: batch-minter-migrate (Story 057)
Mode: fork-preview, regression-reconciled per entryPoint (first audit of this entry point — all findings new)
Fork block: 25248523 (RPC live)
Generated: 2026-06-05
-->

# Script Audit — `batch-minter-migrate` (Story 057)

**Project:** phoenix-phase-2-staging &nbsp;|&nbsp; **Run:** phoenix-phase-2-staging-11
**Forge target:** [`script/MigrateBatchNFTMinter.s.sol:MigrateBatchNFTMinter.run()`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/MigrateBatchNFTMinter.s.sol)
**Mode:** fork-preview (live RPC) at block `25248523` &nbsp;|&nbsp; **Reconciliation:** regression-reconciled per `entryPoint` — first audit of this entry point, all findings are new.
**Sender / OWNER:** `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (Ledger `m/44'/60'/46'/0/0`)

## Abstract

The `batch-minter-migrate` entry point deploys the self-refund-fixed `BatchNFTMinter` (nft-staking `5f863d2`), repoints both real funders (`StableYieldAccumulator.nudge` and the live Sky-route `BalancerPoolerV2.batchMinter`) to it, drains the old minter's residual USDC into the new pot, restores the pooler `batchDonationSize` to 10%, and retires the old contract. The migration is **clean**: all 7 stated-purpose items are achieved, and all 6 pre-conditions and 7 post-conditions pass against the live mainnet fork — including the exact full-balance USDC drain (128.572549 OLD → new, `usdcSeeded == oldBal`, OLD left at 0). Every observed state write maps to the closure manifest's `mutated` set; there are **zero unintended side effects**. Two knock-on issues surfaced from the surrounding script cluster, both **Low/QA** with no asset impact: the sibling funder `mint-sell-donate` is fail-safe bricked because its hardcoded `BATCH_MINTER` constant still points at the now-retired old minter (BMM-L-01, downgraded from Medium, flagged borderline for human review), and the migrate script lacks the `require(block.chainid == 1)` network guard its sibling carries (BMM-L-02). One pre-existing observation (the new minter ships unpausable, `pauser == 0`) was suppressed as admin-trust/centralization whose root cause predates this entry point. No High or Medium findings.

---

## Scope and closure

The audited entry point resolves to a single forge script, `MigrateBatchNFTMinter.run()`, executed via the broadcast variant
`node scripts/backup-mainnet-addresses.js && forge script ... --broadcast --skip-simulation --slow --ledger ... && node scripts/patch-mainnet-addresses-batch-minter-migrate.js`,
and verified here via its preview variant (`PREVIEW_MODE=true ... -vvv`).

The transitive closure (`closure-manifest.json`) comprises:

- **Solidity:** the script imports `nft-staking/BatchNFTMinter.sol` (the self-refund-fixed instance at submodule HEAD `5f863d2`, the Story 057 target) plus `@yield-claim-nft/.../ITokenMinterV2.sol`; nft-staking's nested `yield-claim-nft/` and `pauser/` imports canonicalize through `foundry.toml` diamond-dependency redirects so a single physical source backs each interface. All on-chain peers (`SYA`, `POOLER`, old/new minter, `NFTMinterV2`) are reached through inline minimal interfaces.
- **On-chain set:** `newMinter` (deployed), `OLD_BATCH_MINTER 0x6e98…5071` (retired), `POOLER 0x7f74…786b` and `SYA 0x3bBE…606a` (mutated), `NFT_MINTER_V2 0x39Af…E10F`, `USDC`, `USDS`, `OWNER` (referenced).
- **Off-chain state:** `scripts/backup-mainnet-addresses.js` (pre, timestamped backup), the script's own `progress.batch-minter-migrate.1.json` (broadcast-only `vm.writeFile`), and `scripts/patch-mainnet-addresses-batch-minter-migrate.js` (post, rewrites `server/deployments/mainnet-addresses.ts`).
- **Cluster:** the predecessor template `batch-minter-replace` (Story 050), the sibling funder `mint-sell-donate`, the bleed-stop `SetBatchDonationSizeZeroIndex4`, the index-4 cutover `dispatcher-replace-sky-pooler` (Story 056), and several read-only diagnostics.

Two source paths remained unpinned (the `BalancerPoolerV2` and `StableYieldAccumulator` physical files — referenced only via inline interfaces, not Solidity imports). The impact is low: role and calls for both are fully corroborated by live RPC reads, and bytecode-vs-source verification was treated as corroboration, not a gate.

---

## 1. Does it do what it intends?

**Yes — the migration is clean. 7/7 stated purposes achieved; 6/6 pre-conditions and 7/7 post-conditions pass on the live fork.** The preview executed without reverting.

### Stated purpose vs. observed behaviour

| # | Stated purpose | Observed on fork (block 25248523) | Status |
|---|---|---|---|
| 1 | Deploy self-refund-fixed `BatchNFTMinter` | `new BatchNFTMinter(OWNER)`; ctor sets `owner = OWNER` | Achieved |
| 2 | Configure new minter identically to live | `tokenMinter = 0x39Af…E10F`, `dispatcherIndex = 4`, `nudgePaymentToken = USDC`, `nudgeSize = 40` | Achieved |
| 3 | Repoint the two real funders | `SYA.nudge` and `POOLER.batchMinter` both moved OLD → new | Achieved |
| 4 | Drain old USDC into new pot (plain `rescueERC20`) | OLD `128572549 → 0`, new `0 → 128572549` via single `Transfer`/`Rescued` | Achieved |
| 5 | Restore pooler `batchDonationSize` to 10%, after the repoint | `batchDonationSize 0 → 10` | Achieved |
| 6 | Retire old contract (assert 0 USDC, zero nudge config) | OLD `nudgePaymentToken → 0`, `nudgeSize 40 → 0` | Achieved |
| 7 | Persist progress JSON (broadcast only) for post-step JS | `_persist` via `vm.writeFile` (broadcast path; not exercised in preview) | Achieved (by design) |

### Pre-conditions (`_guards()`) — all pass

All six guards executed before any pointer or fund moves and held on the fork: new minter `tokenMinter != 0`; `dispatcherIndex == 4`; `nudgePaymentToken == USDC`; `NFTMinterV2.configs(4).dispatcher != 0`; index-4 dispatcher `primeToken() == USDS`; and the security-critical `nudgePaymentToken (USDC) != primeToken (USDS)` separation that protects `batchMint`.

### Post-conditions — all pass

`SYA.nudge() == newMinter`; `pooler.batchMinter() == newMinter`; **exact drain** `usdcSeeded == oldBal` (`128572549 == 128572549`); `pooler.owner() == OWNER`; `pooler.batchDonationSize() == 10`; `OLD minter USDC == 0` after drain; OLD nudge config zeroed. Ordering is correct — the donation restore lands **after** the repoint, so restored 10% donations flow to the new minter, not the retiring one.

### Verified non-findings (correct targeting)

- **Correct old-minter target.** The script targets the current-live old minter `0x6e9886AfDF07DD67dc70b8335E4e9DF14B445071` (Story 056), confirmed on-chain to hold code and ~128.57 USDC — **not** the Story 050 predecessor's old minter `0x4ef0…41f3`. The closure correctly distinguishes the two.
- **Correct (live) pooler.** The donation-restore is applied to the live index-4 Sky-route pooler `0x7f74…786b` (the contract `NFTMinterV2.configs(4)` actually returns), not the stale `0x26F89f` pooler that the pattern-template `SetBatchDonationSizeIndex4` hardcodes. No re-fire hazard versus the bleed-stop predecessor.
- **New minter is fully wired and the system is functional after this script alone.** The new minter's nudge token (USDC) matches the pooler's donation token, and `batchMint(4)` resolves via `NFTMinterV2.configs(4)` (dispatcher `0x7f74…786b`, `disabled == false`), which this migration leaves unchanged. The USDC ≠ USDS prime-token separation guard holds, so the 40-batch nudge path is safe.

---

## 2. Does it introduce unintended side effects?

**No. None.** Every observed state write maps to the closure manifest's `mutated` set; `unintendedEffects` is empty.

The fork preview recorded exactly eleven intended writes and no others:

- new `BatchNFTMinter`: `owner`, `tokenMinter`, `dispatcherIndex`, `nudgePaymentToken`, `nudgeSize`;
- `SYA.nudge` OLD → new;
- `POOLER.batchMinter` OLD → new and `POOLER.batchDonationSize` 0 → 10;
- USDC balance transfer OLD → new (full 128.572549) via `OLD.rescueERC20`;
- OLD minter `nudgePaymentToken → 0` and `nudgeSize → 0`.

All six external calls (`SYA.setNudgeAddress`, `POOLER.setBatchMinter`, `OLD.rescueERC20`, `POOLER.setBatchDonationSize`, `OLD.setNudgePaymentToken`, `OLD.setNudgeSize`) returned without reverting, and every emitted event corresponds to an intended write. Two deliberate non-actions were confirmed and are correct, not omissions: `nudgeSplit` is **left at 30** (zeroing it while the nudge is live would DoS `claim()`), and `setPauser` is not called (see the suppressed note below).

---

## 3. Have other problems surfaced because of it?

Yes — knock-on cluster issues only. All are **Low/QA**; none reach High or Medium. The migration itself is sound; these are consequences of the migration interacting with sibling scripts and repo conventions.

### BMM-L-01 — Stale hardcoded sibling constant bricks the `mint-sell-donate` funder *(downgraded from Medium; borderline — human review)*

- **Record:** [`findings/low/BMM-L-01-stale-hardcoded-sibling-constant.json`](../../findings/low/BMM-L-01-stale-hardcoded-sibling-constant.json)
- **Location:** [`script/MintSellAndDonateToBatchMinter.s.sol#L279-L308`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/MintSellAndDonateToBatchMinter.s.sol#L279-L308) (root cause); triggered by [`script/MigrateBatchNFTMinter.s.sol#L197`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/MigrateBatchNFTMinter.s.sol#L197)
- **Class:** Configuration-Safety / cluster-consistency / operational-drift

The migration repoints the live pooler to the new minter (`setBatchMinter(newMinter)` at line 197, asserted at line 199). The sibling funder `mint-sell-donate` — the only documented bulk path for refilling the nudge pot via PSM — hardcodes its donation target as a compile-time `address constant BATCH_MINTER = 0x6e98…5071` (line 279, the OLD minter, with no env override) and self-checks `require(IPoolerCfg(LIVE_POOLER).batchMinter() == BATCH_MINTER, "batchMinter != live pooler")` at line 308. Once the migration repoints the pooler, that equality no longer holds, so **every** subsequent `mint-sell-donate` run reverts at line 308 until the source constant is bumped and recompiled. Verified on the fork: the pooler's `batchMinter` becomes the new minter in preview while the funder's constant is unchanged.

**Impact:** none to assets. The revert is **fail-safe** — it fires before any phUSD is minted or any USDC moves, so nothing is stranded, stolen, or donated to the dead contract. The deployed protocol keeps working: the new minter still receives the one-time 128.57 USDC seed and the per-mint donate-forward. The only effect is that the bulk pot-refill path is temporarily inoperable.

**Why Low, not Medium:** zero assets at risk; the harm is reachable only via two privileged, Ledger-gated operator actions in sequence (run the migration, then run the funder without bumping its constant) with no external-attacker path; it is a deployment-script defect rather than an on-chain contract vulnerability; and it is trivially recoverable via a one-constant edit guided by a loud, self-documenting revert string. This is **borderline** and flagged for human review: a judge who reads the C4 Medium "availability" limb expansively could argue the only documented bulk-refill path being inoperable is an availability impact, and could push it to Medium if the bulk-refill funder is deemed protocol-critical rather than an internal ops convenience.

**Recommendation:** make the funder's `BATCH_MINTER` env/config-driven — resolve it at runtime from `IPoolerCfg(LIVE_POOLER).batchMinter()` and assert the resolved address has code — instead of pinning a compile-time constant. Alternatively, add a mandatory post-migration source-bump step to the Story 057 cutover runbook.

### BMM-L-02 — Missing `block.chainid` network guard *(confirmed Low)*

- **Record:** [`findings/low/BMM-L-02-missing-network-guard.json`](../../findings/low/BMM-L-02-missing-network-guard.json)
- **Location:** [`script/MigrateBatchNFTMinter.s.sol#L114-L140`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/MigrateBatchNFTMinter.s.sol#L114-L140)
- **Class:** Configuration-Safety / cluster-consistency

`run()` lacks a fail-fast `require(block.chainid == 1)` guard. The sibling `MintSellAndDonateToBatchMinter.s.sol` pins exactly that at line 289, and the repo's Configuration-Safety convention mandates it, so its absence here is a cluster inconsistency. **Impact:** none in practice — a broadcast against the wrong chain would almost certainly revert on the first call to a hardcoded mainnet address that has no code on the wrong chain, and the broadcast is Ledger-gated. There is no attacker path; only self-inflicted operator RPC misconfiguration. **Recommendation:** add `require(block.chainid == 1, "expected mainnet (1)")` at the top of `run()` (or gate behind `PREVIEW` for local), matching the sibling.

### Suppressed — Unpausable new minter (`pauser == address(0)`)

- **Recorded in:** [`suppressed-notes.json`](./suppressed-notes.json) (`BMM-L-02` original id)
- **Location:** `src/BatchNFTMinter.sol` (deployment / pauser wiring)

The new `BatchNFTMinter` is deployed with `pauser == address(0)`, leaving it without a working emergency stop. This is **suppressed, not silently dropped**, on two grounds: (1) it is admin-trust/centralization in class, and (2) the root cause predates this entry point — the old minter being replaced is equally unpausable (confirmed on-chain: OLD `pauser == 0x0`), so the migration neither introduces nor worsens it; the script merely matches the live instance by design. Per CLAUDE.md's known-invalid/out-of-scope classes (admin-trust/centralization; root cause OOS of the entry point) it is not written as an open finding. **Operator note:** confirm whether shipping a fund-holding contract unpausable-by-design is intended; if not, the fix belongs to the minter deployment pattern rather than this migration.

---

## Verdict

- **Intent:** fully realized — 7/7 purposes, 6/6 pre-conditions, 7/7 post-conditions verified on the live fork, including exact full-balance drain and correct step ordering.
- **Side effects:** none — every state write is intended; `unintendedEffects` empty.
- **Knock-on issues:** two Low/QA cluster-consistency items (BMM-L-01 borderline → human review; BMM-L-02 confirmed Low) plus one suppressed pre-existing centralization note.
- **High/Medium findings:** none.

The `batch-minter-migrate` script can be broadcast as-is. The standing recommendation is operational, not blocking: before relying on `mint-sell-donate` again, bump its `BATCH_MINTER` constant (BMM-L-01), and consider adding the chainid guard (BMM-L-02).
