# QA Report for phoenix-nft-staking (run-19)

Cold-full regression scan @ commit `321d0a9` ([story-020] — NFTStakerDepletion rate-drift fix,
paying down the WATCH-18 cold-pass debt). This run produced **zero High/Medium findings**:
M-01 (depletion rate-drift, fp `b58b172e`) was re-confirmed STILL-FIXED by PoC-replay
(`test/PoC_DepletionRateDrift.t.sol` 3/3, full suite 269/269), regression count = 0.

Every item below is a Low / QA-tier residual: value-conserving spec/NatSpec drift, non-obvious
owner/operational footguns (Law-3, in scope), or a read-only reentrancy view window with no
in-scope consumer. None has an attacker path; none requires a coded PoC. Findings that carry a
Law-2 faithfulness component are cross-referenced (one line) to `spec-conformance.md`; the
faithfulness detail lives there, not here.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 5 |
| QA / Non-Critical | 2 |
| Centralization | 0 |
| **Total** | **7** |

New this run: L-01–L-04, Q-01, Q-02. L-05 is an existing **open** ledger item (run-18 L-01,
fp `e7bccb02`) republished with a **new dynamic strand** and a **corrected** adjudication. Two
further prior-run open Lows are cross-referenced (not re-typed) at the end. An automated
**4naly3er** QA/gas report is attached as an appendix in
[`4naly3er-report.md`](4naly3er-report.md).

---

## Low Risk Findings

### [L-01] NFTStakerDepletion.depositFor retains an unconditional tail window-restart; NatSpec "parity with stake" is stale <!-- id: pns19l1 -->

**Location**: [NFTStakerDepletion.sol#L748-L768](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L748-L768) (`depositFor`), unconditional tail recompute at [#L767](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L767).

**Description**: story-020 removed the permissionless `stake`/`unstake` tail `_recomputeSchedule` (this is what closed M-01 rate-drift, fp `b58b172e`, fixed @321d0a9). `depositFor` still carries an **unconditional** tail `_recomputeSchedule()` (L767) that restarts `windowEnd = now + windowSeconds` on **every** call, regardless of whether the budget actually changed. The NatSpec at L766-767 still claims "parity with stake" — that claim is now stale/false, because `stake()` no longer recomputes.

**Impact**: None to assets — `depositFor` is `onlyMigrator` (trusted surface, not permissionless), value-conserving, and solvency-safe. An attacker cannot repeatedly invoke it to grief the window. This is a faithfulness / stale-NatSpec residual, **not** a regression of M-01 (`regressionRuledOut: true`; different function surface, trusted caller). Each owner-orchestrated `migrateIn → depositFor` re-injection restarts the depletion window, deferring the horizon — value-conserving but divergent from the post-story-020 `stake()` semantics the NatSpec still asserts.

**Recommendation**: Gate the `depositFor` tail recompute on `inflow > 0` (mirroring the story-020 fix — restart the window only on a genuine budget increase), and correct the "parity with stake" NatSpec at L766-767.

*Faithfulness cross-ref: routed to spec-conformance as **F-19-01** (Law 2, honest Low) — see [`spec-conformance.md`](spec-conformance.md). Cross-ref M-01 (fp `b58b172e`, FIXED).*

---

### [L-02] finalizeAndReset revives the pool without re-arming the depletion window; organic stake earns zero until owner re-arm <!-- id: pns19l2 -->

**Location**: [NFTStakerDepletion.sol#L778-L784](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L778-L784) (`finalizeAndReset`); re-arm entrypoints `setDepletionWindow` [#L364](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L364) / `topUp`.

**Description**: `finalizeAndReset` revives a drained `Migrating` pool back to `Active` (L778-784) but does **not** recompute the schedule. Post-story-020, `stake()` no longer auto-rearms the window, so a *revive-then-organic-stake* sequence — a plain `stake()`, as opposed to a `depositFor` re-seed via the InPlace migrator (which self-heals through its own tail recompute, see L-01) — leaves `windowEnd` dormant and the new staker accrues **zero** rewards until the owner explicitly re-arms via `setDepletionWindow` / `topUp`.

**Impact**: None to assets — value is never lost and principal is untouched. Emissions **pause** (not destroyed) after an organic revive until the owner re-arms; fully owner-recoverable. This is a non-obvious *asymmetric* Law-3 owner footgun: the migrator path self-heals, the organic path does not, so a competent owner could be surprised that a clean `finalizeAndReset` leaves organic stakers earning nothing.

**Recommendation**: Have `finalizeAndReset` re-arm the window (recompute the schedule on revive), or emit an explicit `NEEDS-REARM` signal / document the required `setDepletionWindow` follow-up so the asymmetry with the self-healing `depositFor` path is not silent.

*Faithfulness cross-ref: routed to spec-conformance as **F-19-03** (Law 2) — see [`spec-conformance.md`](spec-conformance.md).*

---

### [L-03] unstake performs the outbound ERC1155 transfer before the tail recompute — read-only reentrancy view-inconsistency window (no in-scope consumer) <!-- id: pns19l3 -->

**Location**: [NFTStaker.sol#L458-L476](../../../../lib/phoenix-nft-staking/src/NFTStaker.sol#L458-L476) (`unstake`: `totalStaked -=` at ~L469, outbound `safeTransferFrom` at ~L471, tail `_recomputeSchedule` at ~L476). Same ordering in the hand-maintained copy [NFTStakerPriceScaled.sol#L497](../../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaled.sol#L497).

**Description**: In `unstake`, the outbound ERC1155 `safeTransferFrom` (which invokes `onERC1155Received` on a caller-chosen recipient) executes **before** the tail `_recomputeSchedule`. During the receive callback, `totalStaked` is already decremented while `rewardRate`/`windowEnd` still reflect the OLD pool, so the value-reporting views (`currentRewardRate` / `runwaySeconds` / `totalNFTValue`) return a transiently inconsistent snapshot. State-changing reentry is blocked by the contract-wide `nonReentrant`.

**Impact**: None demonstrated in scope (implausible-High ceiling, retained for visibility per Law 1 keep-not-drop). The exposure would only rise above Low if an in-scope oracle/integrator that prices collateral off these views inside the callback is later introduced — **none is known in scope**, and `nonReentrant` blocks any state-changing reentry.

**Recommendation**: Move the outbound ERC1155 transfer **after** `_recomputeSchedule` (strict CEI) so the value-reporting views are consistent throughout the receive callback. Re-escalate only if an in-scope consumer of these views appears. *(Per WATCH-17 maintenance-coupling: any fix must be mirrored into both `NFTStaker.sol` and `NFTStakerPriceScaled.sol`.)*

---

### [L-04] DeployBatchNFTMinter.s.sol assumes DISPATCHER_INDEX with no on-chain cross-check that the nudge token differs from dispatcher.primeToken() <!-- id: pns19l4 -->

**Location**: [DeployBatchNFTMinter.s.sol#L48-L99](../../../lib/phoenix-nft-staking/script/DeployBatchNFTMinter.s.sol#L48-L99) — `DISPATCHER_INDEX` (ASSUMED = 4) at [#L48](../../../lib/phoenix-nft-staking/script/DeployBatchNFTMinter.s.sol#L48), USDC nudge token at [#L38](../../../lib/phoenix-nft-staking/script/DeployBatchNFTMinter.s.sol#L38), existing minter guard at [#L69](../../../lib/phoenix-nft-staking/script/DeployBatchNFTMinter.s.sol#L69).

**Description**: The deploy script hardcodes `DISPATCHER_INDEX = 4` and USDC as the nudge token. It guards `USDC != TOKEN_MINTER` (L69) but does **not** verify on-chain that the nudge token differs from the pinned dispatcher's `primeToken()` — that equality is enforced only at `batchMint` **runtime**. A wrong index pins the batcher to the wrong dispatcher / payment asset at deploy, and the misconfig surfaces later as a runtime revert rather than a failed broadcast.

**Impact**: None directly — no funds lost. A wrong `DISPATCHER_INDEX` pins the `BatchNFTMinter` to the wrong dispatcher/payment asset; failure surfaces only at `batchMint` runtime (the equality guard reverts), forcing a redeploy/repoint. Non-obvious deploy-config coupling (Law-3 footgun), blast radius bounded by the runtime guard.

**Recommendation**: Add an on-chain deploy-time `assert` that `nudgeToken != dispatcher.primeToken()` **and** that the dispatcher resolved at `DISPATCHER_INDEX` is the intended one, failing the broadcast instead of deferring the misconfig to runtime.

---

### [L-05] InPlaceNFTStakerMigrator immutable stakedId has no live-parity assertion vs staker.stakedId() — migrateIn re-injection bricks after a post-deploy setStakedId reissue <!-- id: pns19l5 -->

> **Carryover + new strand.** This is the existing **open** ledger item **L-01** (fp `e7bccb02`, first seen run-18 — the *deploy-time mis-wire* strand). Republished here with the **new dynamic post-deploy strand** and a **CORRECTED** adjudication (the original code-scanner impact was wrong-direction). Do **not** auto-flip to fixed — see the re-audit trap below.

**Location**: [InPlaceNFTStakerMigrator.sol#L53](../../../../lib/phoenix-nft-staking/src/InPlaceNFTStakerMigrator.sol#L53) (immutable `stakedId`, set at [#L107](../../../../lib/phoenix-nft-staking/src/InPlaceNFTStakerMigrator.sol#L107)), `migrateIn` at [#L186](../../../../lib/phoenix-nft-staking/src/InPlaceNFTStakerMigrator.sol#L186); the staker's owner-mutable `setStakedId` (gated `onlyOwner` + `totalStaked == 0`) at [NFTStakerDepletion.sol#L333-L334](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L333-L334).

**Description**: One root cause — the migrator's immutable `stakedId` carries no **live**-parity assertion against the staker's owner-mutable `stakedId()`. Run-18 L-01 was the deploy-time mis-wire strand. The **new** dynamic strand: a legitimate `setStakedId(newId)` reissue (gated `onlyOwner` + `totalStaked == 0`, so it can only fire *after* all users are parked) drifts `staker.stakedId() → newId` while `migrator.stakedId` stays `oldId`.

**Corrected mechanics** (supersedes the code-scanner's inverted narrative; severity-auditor source-traced, see [`L-01-corrected-adjudication.md`](../L-01-corrected-adjudication.md)):
- The physically-parked ERC1155 units are `oldId`, and `migrator.stakedId == oldId` stays aligned with them forever.
- `claimTimedOut` transfers `migrator.stakedId = oldId` → matches parked tokens → **the permissionless escape hatch is INTACT.**
- `rescueERC1155` floors against `balanceOf(this, migrator.stakedId) = balanceOf(oldId)` vs `totalParked` → **the floor guards the correct balance → INTACT.**
- `migrateIn → staker.depositFor(user, amt)` pulls `stakedToken.safeTransferFrom(migrator, staker, staker.stakedId() = newId, amt)` from a migrator holding only `oldId` → **REVERTS.**

**Impact**: The **only** real consequence is that the owner's `migrateIn` re-injection path **bricks** after a mid-migration `setStakedId` reissue. Fully recoverable: parked users self-rescue via the permissionless `claimTimedOut` after `migrationTimeout` (1–30 days). No theft, no permanent principal loss, no permissionless griefing, no floor void, no hatch kill → **Low**.

**Recommendation** (the original code-scanner proposal is HARMFUL — do not follow it):
- **DO** assert `migrator.stakedId == staker.stakedId()` at the **entry** of `migrateIn` (fail-loud before the re-injection loop), **OR** block `setStakedId` while `totalParked > 0` at the migrator.
- **DO NOT** repoint `claimTimedOut` / `rescueERC1155` to read `staker.stakedId()` — the migrator physically holds `oldId`, so that would **break** the currently-working hatch and floor.

**Incomplete-fix / re-audit trap** (ledger WATCH-19-L01-incomplete-fix-trap): run-18 L-01's original remediation is a **constructor** cross-check, which passes at deploy then drifts on a later `setStakedId`. A constructor-only patch does **NOT** close this dynamic strand and **must not be auto-flipped to fixed** — verify a live parity assert at `migrateIn` (or a `totalParked > 0` reissue guard) against **both** the deploy-time and post-deploy strands before flipping.

---

## QA / Non-Critical Findings

### [Q-01] NFTStakerMigrator stores a dead, misleading stakedId immutable never referenced by migrate() <!-- id: pns19q1 -->

**Location**: [NFTStakerMigrator.sol#L44](../../../../lib/phoenix-nft-staking/src/NFTStakerMigrator.sol#L44) (immutable `stakedId`, set at [#L62](../../../../lib/phoenix-nft-staking/src/NFTStakerMigrator.sol#L62)); `migrate` at [#L81](../../../../lib/phoenix-nft-staking/src/NFTStakerMigrator.sol#L81).

**Description**: `NFTStakerMigrator` stores an immutable `stakedId` that `migrate()` never references and never asserts equal across the old/new stakers. A cross-staker `stakedId` mismatch surfaces only as a **hard revert with clean atomic rollback** (no partial state, no fund loss). The dead immutable is misleading — it implies a parity guarantee the code does not enforce.

This is a **distinct** contract and failure mode from the InPlaceNFTStakerMigrator strand (L-05): here a mismatch is a self-evident fail-loud revert-and-rollback, versus the silent `migrateIn` brick there. Kept separate.

**Impact**: None. Worst case is a self-evident revert at migration time with clean atomic rollback; the operator observes a failed migration and re-deploys with correct wiring. QA hardening only.

**Recommendation**: Either wire the immutable into a real cross-staker parity assert in `migrate()` (require the source/destination stakers agree with the migrator's `stakedId`), or remove the dead immutable so it stops implying an unenforced guarantee.

---

### [Q-02] NFTStakerDepletion._syncBudget no-hook-branch NatSpec claims "pure recompute" — post-story-020 it settles accrual only (doc drift) <!-- id: pns19q2 -->

**Location**: [NFTStakerDepletion.sol#L423-L435](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L423-L435) (`_syncBudget`, no-hook branch).

**Description**: Post-story-020, the no-hook branch of `_syncBudget` settles accrual only (pure `_updatePool`, no `_recomputeSchedule`), but the NatSpec still claims it "behaves like a pure recompute". The docstring was made stale **by** the story-020 fix. No functional impact: every config setter recomputes directly, so no code path relies on the stale claim.

**Impact**: None (documentation-only). Risk is future-maintenance confusion; runtime behaviour is correct and unchanged.

**Recommendation**: Update the `_syncBudget` no-hook-branch NatSpec to "settles accrual only; no recompute".

*Faithfulness cross-ref: routed to spec-conformance as **F-19-02** (Law 2, doc drift introduced by the fix) — see [`spec-conformance.md`](spec-conformance.md).*

---

## Centralization Risks

No new centralization-specific findings this run. (The owner privileges exercised by
`setStakedId`, `setDepletionWindow`, `finalizeAndReset`, `topUp`, and the migrators are all
`onlyOwner` and assumed non-malicious per the audit's owner-trust law; the *non-obvious*
consequences of those privileges are captured as the operational footguns L-02, L-04, and L-05
above, not as standalone centralization findings.)

---

## Prior-run open Low findings (cross-reference only — not re-typed)

These remain **open** on the ledger and were re-confirmed present @321d0a9 this run. They are
reproduced verbatim in their carryover stubs under
[`submissions/carryover/`](carryover/) and are **not** duplicated here (recall preserved via
the ledger; triage with `/ledger phoenix-nft-staking`).

- **batchMint missing `nonReentrant`** — `BatchNFTMinter.sol#L238-L257`, ledger label **L-01** / fp `9135cf79`, first seen run-12, status *submitted*. Not exploitable beyond Low (every reentry is self-defeating; validated Tier-3 PoC, 4 cases). Defense-in-depth. Stub: [`carryover/L-01-batchMint-reentrancy-CARRYOVER.md`](carryover/L-01-batchMint-reentrancy-CARRYOVER.md).
- **NFTStakerPriceScaled priceScale magnitude unchecked** — `NFTStakerPriceScaled.sol#L230-L435`, ledger label **L-08** / fp `0200236f`, first seen run-17, status *open*. Immutable `priceScale` is unbounded/decimal-unchecked beyond ctor `!= 0`; a wrong-magnitude deploy value silently mis-sizes emission/runway (solvency-safe, owner-correctable via `setTargetAPY`; Law-3 deploy-time footgun). Recommend a deploy-time assert `priceScale == 10**(rewardDecimals - priceDecimals)`. Stub: [`carryover/L-08-priceScale-magnitude-CARRYOVER.md`](carryover/L-08-priceScale-magnitude-CARRYOVER.md).

---

## Appendix — Automated 4naly3er QA/Gas Report

The canonical C4-style automated report was generated over the eight in-scope first-party
contracts (`src/*.sol`) @ `321d0a9` and attached at
[`4naly3er-report.md`](4naly3er-report.md). It ran cleanly using the submodule's own
`remappings.txt` + nested `lib/` (no remappings gap this run — the documented scratchpad
symlink workaround was not needed). Summary of automated buckets: **14 Gas-optimization**
classes, **23 Non-Critical** classes, and **12 Low** issue classes. These are tool-surfaced baseline
observations and are **not** individually triaged as findings — per the audit quality bar,
automated-tool output without a demonstrated H/M exploit path is not promoted; it is attached
for completeness and reviewer cross-reference.
