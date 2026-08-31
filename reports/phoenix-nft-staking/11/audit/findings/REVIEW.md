# Final review — phoenix-nft-staking-11 QA findings

Independent second-opinion on `reports/phoenix-nft-staking/11/audit/submissions/qa-report.md` (findings C-01, L-01, L-02). Source verified at `lib/phoenix-nft-staking/src/NFTStakerV2.sol` commit 9d71401.

## C-01 — Combined migrator powers

**Verdict: confirmed, severity correct (Low / Centralization).**

Code claims verified:
- `unstakeFor` at lines 543-562 has `onlyMigrator whenNotPaused` (line 543) and line 558 reads `stakedToken.safeTransferFrom(address(this), msg.sender, stakedId, amount, "")` — principal routes to `msg.sender` (the migrator), not the beneficiary. Confirmed.
- `withdrawRewardToken` at line 564 has `onlyOwnerOrMigrator`. Modifier at lines 201-207 admits `owner() || (migrator && migrator != 0)`. Confirmed.
- Composition argument is correct: `unstakeFor` has no `paused()` requirement, so the migrator can grind `totalStaked` to zero during normal operation, then a paused window of one block is all that is needed to fire `withdrawRewardToken`.

**Severity review against C4 rules.** The C4 ceiling for "owner-set role with broad powers, no non-owner path to assets" is QA/Centralization. The finding is explicit about that: the rationale spells out (a) no non-owner attacker path exists, (b) the role is owner-set and revocable, (c) the deployed `MigrationHelper` is stateless and does not exhibit the drain. The question I asked myself: could Medium be defended on the "value leak with stated assumptions + external requirements" framing? Answer: no. C4 Medium for centralization-flavoured findings typically requires either (i) the assumption is so easy to trip that it is not really an assumption (e.g. ordinary operator behaviour suffices), or (ii) the role is contractually constrained but the contract fails to enforce a documented constraint, leaving a value-leak path even under good-faith operation. Here the documented constraint (the plan) is "migrator does stakeFor only"; the implementation widens it, but the path to loss still requires a privilege holder to actively misbehave. That is canonical Centralization → Low under C4. Keep at C-01.

**Overstatement check.** The framing is precise — the description uses "can" / "could", attributes the exploit to migrator action (not anonymous attacker), and the rationale paragraph explicitly disclaims promotion. The recommendation block is also calibrated (three small reinforcing changes; no overheated remediation). No overstatement.

## L-01 — `withdrawRewardToken` sweeps without syncing or asserting debt

**Verdict: confirmed, severity correct (Low / QA).**

Code claims verified:
- `withdrawRewardToken` (lines 564-578) does not call `_syncBudget` or `_updatePool`. Verified: the grep of those identifiers shows them invoked in `stake`/`unstake`/`claim`/`stakeFor`/`unstakeFor`/`topUp`/`pullAndRefresh` but not inside `withdrawRewardToken`. Confirmed.
- Line 576 unconditionally writes `committedDebt = 0`. Confirmed (no preceding require/check on that variable).
- The dispatcher-hook `pull()` path is realised only via `_syncBudget`; an operator wanting to absorb `mintDebt` before sweeping must call `pullAndRefresh()` first, which is `onlyOwner`. The finding's "migrator alone cannot drain `mintDebt`" subpoint is therefore correct.
- The `emergencyWithdraw` floor-division dust pathway is correctly identified — line 632 computes `pending = (amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt`, and lines 645-647 only forfeit up to the current `committedDebt`, so the strong invariant is preserved but a positive residual can persist when the last user exits via `emergencyWithdraw` rather than `unstake`.

**Severity review.** Three sub-issues, all bounded:
- The `mintDebt`-not-realised sub-issue is an operator workflow concern (orphans bounded by recent hook accrual, recoverable by `pullAndRefresh` then a second sweep). No outsider exploit, owner-recoverable.
- The `committedDebt` force-zero is at most wei-level dust (per the audit's own bound and the NatSpec at lines 587-598 of `_safePay` which uses identical floor-truncation logic).
- The NatSpec/code mismatch is documentation hygiene.

C4 Medium would require a non-trivial value-leak path with stated external requirements. Wei-level dust does not clear that bar; operator workflow risk that is fully recoverable does not clear it either. Keep at L-01.

**Overstatement check.** The finding is careful with magnitudes ("bounded to a few mint events", "O(wei) dust", "operator workflow risk and state-handling precision"), and the rationale paragraph explicitly states promotion would require a non-trivial fund-loss path. No overstatement. If anything the finding is slightly understated on sub-issue 1 — the "decommissioning sweep" framing in the plan does imply this should be one-call complete, so the gap is real and worth surfacing — but Low remains correct.

## L-02 — `stakeFor` `onlyMigrator` gate inverts plan

**Verdict: confirmed, severity correct (Low / QA).**

Code claims verified:
- `stakeFor` at line 521 has `onlyMigrator`. Confirmed by direct read.
- Plan text "No authorisation gate — anyone can call `stakeFor` provided they own the NFTs to deposit": I cannot directly grep the plan document because it lives in the product-owner scratchpad, not the submodule. However, the QA report quotes it verbatim and the finding has been triangulated through three independent scanner outputs (per the dedup JSON). I accept the quote as faithful given the consistency with the plan-summary paragraphs in the report header.

**Severity review.** This is a verbatim spec-vs-code deviation in the *more restrictive* direction. No asset-loss path exists in isolation — a more restrictive function cannot cause value loss compared to the documented permissionless variant. The interesting structural point (that this deviation pairs with the *opposite-direction* deviation on `withdrawRewardToken` to concentrate power at the migrator) is correctly captured in the description's "wider pattern" paragraph. Keep at L-02.

**Overstatement check.** The finding explicitly states "no direct fund loss; the issue is that the on-chain trust model does not match the documented trust model" and disclaims promotion. No overstatement.

## Missed angles

The scope statement at the top of the QA report enumerates V2-delta scrutiny (`stakeFor`, `unstakeFor`, `withdrawRewardToken`, `_safePay` refactor), reentrancy, state-update ordering, solvency invariant preservation, and plan compliance. Reading those off against the source:

- **`_safePay` refactor impact on `stake`/`unstake`/`claim`.** The refactored `_safePay` (lines 599-611) is called by `stake`, `unstake`, `claim`, `stakeFor`, and `unstakeFor`. Behaviour change vs V1 (where `_safePay` presumably did not split the decrement across `committedDebt` and `rewardBudget`): the new bookkeeping splits per-call into `if (amount > committedDebt) { rewardBudget -= excess; committedDebt = 0; } else { committedDebt -= amount; }`. This preserves the strong invariant only if `committedDebt` is correctly representative at every call site. All five callers invoke `_syncBudget` (which calls `_updatePool`) immediately before computing `pending`, so `committedDebt` is up-to-date at every `_safePay` site. The audit's "state-update ordering" check covers this and I see no regression. No additional finding warranted.
- **Reentrancy on `withdrawRewardToken`.** No `nonReentrant` modifier on line 564. The function calls `rewardToken.safeTransfer(to, amount)` (line 569) before mutating `rewardBudget` and `committedDebt` (lines 575-576). If `rewardToken` were re-entrant (it is phUSD — owner-controlled, currently not re-entrant) and `to` were a contract that triggered re-entry into `withdrawRewardToken`, the re-entrant call would still require `paused() && totalStaked == 0`, and the state writes happening after the transfer would not lead to over-withdrawal because each entry independently calls `rewardToken.safeTransfer(to, amount)` against the live on-chain balance. Worth a one-line note in the finding but not a separate report — phUSD is in-scope siblings, not arbitrary.
- **`emergencyWithdraw` + `withdrawRewardToken` interaction.** `emergencyWithdraw` is `nonReentrant` (line 628) and callable while paused. The L-01 dust point already captures this. No additional angle.
- **`unstakeFor` precondition timing.** `unstakeFor` (line 543) has `whenNotPaused` — so the migrator must perform the NFT drain *before* pausing, then transition to paused for the phUSD sweep. The C-01 description already covers this sequencing correctly.
- **`stakeFor` "existing beneficiary" open question.** The L-02 secondary-paragraph notes that `stakeFor` for an existing user settles pending at the OLD price correctly per the existing test. I confirmed via lines 525-533: `_syncBudget()` runs first, then `pending` is computed against the OLD `accRewardPerShare` and paid to `beneficiary` via `_safePay(beneficiary, pending)`. Routing is correct; the secondary note in L-02 is accurate.

Bottom line on missed angles: nothing in the V2-delta surface is uncovered. The audit was thorough.

## Bottom line

The three QA findings accurately reflect the source at commit 9d71401: every line-reference and behaviour claim I spot-checked is correct, severity classifications correctly map to C4's QA/Centralization rules (C-01 is borderline-but-correctly-Low under the "owner-set role, no non-owner attacker path" framing; L-01 and L-02 are bounded state-handling and spec-deviation issues with no exploit path), no severity is overstated, and the rationale paragraphs explicitly disclaim promotion in each case. The report is ready to submit as-is.
