# Script review: `dola-ys-withdrawal:status` (run 35)

- **Source**: [Behodler/phoenix-phase-2-staging @ `7ac6e70`](https://github.com/Behodler/phoenix-phase-2-staging/tree/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963), branch `master`, read-only. This is a cold audit with no prior ledger entries.
- **Script**: [`script/DolaStrategyWithdrawalStatus.s.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/DolaStrategyWithdrawalStatus.s.sol)
- **npm key**: [package.json#L59](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L59). There is no dedicated `//` comment. `//InitiateDolaStrategyWithdrawal` (L56) calls the script "read-only and safe anytime".
- **Stories**:
  - story-090 created the script.
  - story-092 added the post-retirement annotation, and its runbook step 2 uses this script as the go check before the cutover.
  - Both stories are in the `auto-complete` state and machine-approved.
- **Mode**: run verbatim against an anvil fork of block 25990689, at four chain states. Time was moved by rewriting `initiatedAt` in storage.
- **Primary report**: [`../../submissions/qa-report.md`](../../submissions/qa-report.md).

## Conclusion

The script is genuinely read-only (`run()` is `view`, with no sender and no broadcast) and reports the strategy's own withdrawal state correctly in every state tested, including after the cutover. **0 High, 0 Medium, 0 Low, 1 QA.** Q-01: the script's go signal, "EXECUTABLE - cutover may broadcast now", does not match the gate of the script it gates. It is printed during the last 6h of the window, when cutover Phase 0 refuses to start, and while the strategy is paused, when the execute would revert. The consumer fails closed before signing, so there is no asset impact.

## 1. Does it do what it intends?

**Mostly.** It reports the strategy's state faithfully. As the story-092 go signal it overstates readiness.

| Intent | Result | Evidence |
|---|---|---|
| Read-only, safe anytime | Met. `view`, no prank or broadcast | `entry-manifest.json` |
| Print stored status, principal vs snapshot, seconds to executable and to expiry (or "expired (lazy)") | Met. At +6h1m: Initiated / EXECUTABLE, 259,131 s to expiry | `fork-logs/03-status-executable.log` |
| Print whether the minter's DOLA registration still points at 0x1760 | Met (`true` before, sDOLA strategy `0x55Bc…` after) | `03`, `10` |
| Story 092: after the cutover, print "withdrawal completed / strategy retired" | Met | `fork-logs/10-status-postcutover.log` |
| Story-092 runbook step 2: act as the operator's go signal | **Overstated.** At +75h it printed "EXECUTABLE - cutover may broadcast now" (10,783 s left), while cutover `:preview` reverted on `WINDOW_SAFETY_MARGIN`. EXECUTABLE is also printed regardless of `strategy.paused()` | **Q-01**; `04-status-last6h.log` vs `04-cutover-preview-last6h.log` |

The EXECUTABLE range `[initiatedAt+6h, initiatedAt+78h]` matches the contract's inclusive `<= initiatedAt + TOTAL_DURATION`, so the mismatch is with the *consumer's* gate, not the contract's.

## 2. Unintended side effects?

**None.** The script makes no state writes and emits no events. It makes only view calls: `withdrawalStates`, `principalOf` and `paused` on 0x1760, and `stablecoinConfigs(DOLA)` on the minter.

## 3. Knock-on problems / cluster

- **It is the gate between the other two entry points.** An operator who trusts EXECUTABLE in the last 6h wastes a preview or broadcast attempt, then has to wait for expiry, re-initiate and wait another 6h. That delay does not freeze stakers, because Phase 0 runs before any transaction. The dangerous case is a halt *after* Phase 6 (cutover L-11), which this signal does not cause.
- **Sibling finding.** `initiate-dola-ys-withdrawal` Q-01 prints a deadline with the same missing margin. Neither operator signal reflects `WINDOW_SAFETY_MARGIN`. Fixing only one leaves the other misleading.
- **Duplicated constant.** The margin lives only in [CutoverStableStakerV2Mainnet.s.sol#L264](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L264). Any fix should import it rather than copy it.

## Findings register

Where links are pinned to `7ac6e70`.

| Label | Sev | Fingerprint | What | Mitigation | Where |
|---|---|---|---|---|---|
| Q-01 (issueId **pending**, see note) | QA, F-tagged (story-092 runbook step 2 vs Phase 0 margin) | `8633815e4b2b` | Prints "EXECUTABLE - cutover may broadcast now" through the last 6h of the window and while the strategy is paused. In both cases the cutover refuses to start or the execute reverts | Split the output into "may START (>6h left)" and "too late to start (<6h left)", add a PAUSED override, and import `WINDOW_SAFETY_MARGIN` from a shared constant | [DolaStrategyWithdrawalStatus.s.sol#L53-L60](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/DolaStrategyWithdrawalStatus.s.sol#L53-L60), gate at [Cutover#L264](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L264) |

**issueId note.** Both run-35 Q-01 findings (this one and `initiate-dola-ys-withdrawal` Q-01) would derive to `pps35q1`. Neither was minted, and the ledger holds `issueId: null`. Use the fingerprint `8633815e4b2b` until a human chooses the ID.

**Quote provenance.** The phrase "must say EXECUTABLE" is not in story 092 itself. It comes from the story-092-mandated `//StableStakerV2Cutover` runbook comment (package.json L49). Story 092's own wording is "wait ≥6h, then check `dola-ys-withdrawal:status`".

## Refuted / not filed

| Obs | Verdict | Reason |
|---|---|---|
| OBS-35-S1 (no chainid guard) | Refuted | `run()` is `view`, so it cannot mutate. On a non-mainnet chain the hard-coded addresses have no code and the typed calls revert, so the script fails rather than misreports. An anvil fork of mainnet (chainid 1) is read faithfully |
| S-35-02 (EXECUTABLE while paused) | Folded into Q-01 | Verified statically. `strategy paused: true` prints on a separate line, but the phase line still says EXECUTABLE |
| OBS-35-S2 (stored `Expired` branch) | Noted, harmless | Unreachable, because a lazy update happens only inside `totalWithdrawal`, which re-initiates in the same call |
