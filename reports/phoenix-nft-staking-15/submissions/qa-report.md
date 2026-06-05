# QA Report for phoenix-nft-staking

**Run**: `phoenix-nft-staking-15` (regression scan, story-016)
**HEAD**: `5f863d27ebbab5df20131a4592996537cd8bf503`
**Scope**: `src/BatchNFTMinter.sol`, `src/NFTStaker.sol`
**Date**: 2026-06-05

## Summary

This was a **clean regression run**. No new Low or Centralization findings were
discovered. The carryover Lows from prior runs were re-confirmed present but remain
**already-submitted** (reported in `phoenix-nft-staking-12`'s QA bundle) — they are listed
below as references, not as new entries. The single new candidate surfaced this run
(ECON-002 / DEDUP-004) was suppressed by the sanitizer as known-invalid; it is recorded for
transparency only.

| Severity | New this run | Carryover (already reported) |
|----------|:------------:|:----------------------------:|
| Low Risk | 0 | 3 (L-01, L-02, L-03) |
| Centralization | 0 | 0 |
| **Total new reportable** | **0** | — |

The automated 4naly3er QA/gas baseline is attached as
[Appendix A](#appendix-a--4naly3er-automated-report).

---

## New Findings

**None.** This regression run produced no new Low-severity or Centralization findings against
HEAD `5f863d2`.

---

## Carryover Low-Risk Findings (already submitted — reference only)

The following Lows were re-confirmed present this run by the Tier-1 static pass
(SLITHER-001 / PATTERN-001 / PATTERN-003). They are **already reported** in the
`phoenix-nft-staking-12` QA report and tracked as `submitted` in the ledger; they are
**not re-counted** here.

### [L-01] `batchMint` lacks `nonReentrant`; ERC1155 `onERC1155Received` fires mid-loop <!-- id: pns15l1 -->

**Location**: [`src/BatchNFTMinter.sol#L238-L257`](../../../lib/phoenix-nft-staking/src/BatchNFTMinter.sol#L238)
**Status**: submitted (carryover from `phoenix-nft-staking-12`)
**Original report**: `reports/phoenix-nft-staking-12/submissions/qa-report.md`

The minting loop has no reentrancy guard, so an ERC1155 recipient's `onERC1155Received`
callback executes mid-loop. Re-examined in `phoenix-nft-staking-14` with a 4-case validated
Tier-3 PoC: the issue **stays Low** — the clean theft path atomically reverts (the nested
frame's `forceApprove(minter, 0)` revokes the outer loop's approval), and the only
value-moving paths require honest-caller misconfiguration (known-invalid) or hit the documented
donate-forward with the owner `rescueERC20` hatch. Re-confirmed present at HEAD `5f863d2`;
story-016's snapshot-before-loop change does not reintroduce a drain.
**Recommendation**: add OZ `ReentrancyGuard`; track the refund credit as a recorded amount
rather than `balanceOf(this)`.

### [L-02] Uncapped count loop in `batchMint` <!-- id: pns15l2 -->

**Location**: [`src/BatchNFTMinter.sol#L238-L240`](../../../lib/phoenix-nft-staking/src/BatchNFTMinter.sol#L238)
**Status**: submitted (carryover from `phoenix-nft-staking-12`)
**Original report**: `reports/phoenix-nft-staking-12/submissions/qa-report.md`

`count` is unbounded, so a sufficiently large value causes the mint loop to exceed the block
gas limit (self-inflicted DoS / griefing of integrating front-ends). Unchanged at HEAD
`5f863d2`.
**Recommendation**: enforce a sane `maxBatchSize` cap.

### [L-03] Nudge-token equality guard reverts even when nudge is size-disabled <!-- id: pns15l3 -->

**Location**: [`src/BatchNFTMinter.sol#L230-L233`](../../../lib/phoenix-nft-staking/src/BatchNFTMinter.sol#L230)
**Status**: submitted (carryover from `phoenix-nft-staking-12`)
**Original report**: `reports/phoenix-nft-staking-12/submissions/qa-report.md`

The nudge-token-vs-payment-token equality guard reverts even when the nudge is size-disabled
(`nudgeSize == 0`), making the guard over-broad. QA/usability nit. Unchanged by story-016 at
HEAD `5f863d2`.
**Recommendation**: gate the equality check on the nudge actually being active.

---

## Centralization Risks

**No new centralization findings this run.** For reference, the standing owner-operational
trust assumptions (owner-pinned minter / `dispatcherIndex`, `rescueERC20` sweep hatch, and the
M-01 acceptance invariant "keep the nudge pot `< nudgeSize × mintPrice`") are documented under
the `M-01` ledger entry and are accepted owner-operational conditions, not code-enforced. The
4naly3er automated pass independently flags the broad owner-trust surface as M-2 (18 instances)
in [Appendix A](#appendix-a--4naly3er-automated-report).

---

## Considered and Suppressed (transparency note)

- **ECON-002 / DEDUP-004 — value strand via monotonic seed (value-blind nudge payout):**
  surfaced as a new candidate this run and **SUPPRESSED** by the sanitizer (not reported).
  Grounds: (1) reckless-admin known-invalid — requires owner misconfiguration; (2) intentional
  donate-forward design; (3) the owner `rescueERC20` escape hatch covers any stranded value;
  (4) the triggering dispatcher dependency is out of scope. Recorded as a `false-positive`
  ledger entry so it is not re-surfaced next run. Shares the value-blind-nudge-payout theme
  retained as the L-04 design note under the H-01 ledger entry.

## Out-of-band triage references (not QA entries)

- **L-05** (`minReward == 0` default silently opts out of the slippage guard) — **wont-fix**
  at the contract level (the zero default is required for legitimate non-nudge batches);
  enforcement of a non-zero, pot-based `minReward` for nudge-qualifying batches now lives at
  the integration/UI layer.
- **M-01** (MEV / first-claimer front-run of the winner-take-all nudge pot) — **acknowledged**;
  story-016 further mitigates it (snapshot-before-loop means the winner no longer recoups their
  own donations, reducing MEV profitability). Tracked at Medium, not QA.

---

## Appendix A — 4naly3er Automated Report

The canonical C4-style automated QA/gas report (4naly3er) was generated this run against
`lib/phoenix-nft-staking/src` (scope resolved to `BatchNFTMinter.sol`, `INFTSupply.sol`,
`NFTStaker.sol`). Full output: [`4naly3er-report.md`](./4naly3er-report.md).

Headline automated counts (informational bot baseline, not triaged findings):

| Class | Categories | Notable |
|-------|:----------:|---------|
| Gas Optimizations | 10 (GAS-1 … GAS-10) | unchecked arithmetic (61), custom errors over revert strings (16), immutable constructor vars (2) |
| Non-Critical | 18 (NC-1 … NC-18) | missing zero-address checks (3), setters lack checks (7), non-existent NatSpec (8), missing indexed event fields |
| Low | 11 (L-1 … L-11) | 2-step ownership transfer, zero-value transfer reverts, division-by-zero (4), precision loss (12), `PUSH0` chain compatibility |
| Medium | 2 (M-1, M-2) | fee-on-transfer accounting (2), **centralization risk for trusted owners (18)** |

These automated categories are the standard C4 bot baseline and overlap several known-invalid
classes for this project (fee-on-transfer and weird-ERC20 are out of scope per the project's
known-issues policy; broad owner-trust is the accepted owner-operational model). They are
attached for completeness and are not promoted to triaged findings.
