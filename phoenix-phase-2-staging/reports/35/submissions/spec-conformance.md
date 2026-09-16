# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit run 35 (3 entry points)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `7ac6e7077b3f1bddbb7d7c98b15ff4502df92963` (branch `master`)
- **Entry points**: `stable-staker-v2-cutover` (baseline `84e2324`, run 34), `initiate-dola-ys-withdrawal` (cold), `dola-ys-withdrawal:status` (cold)
- **Faithfulness-tagged findings**: 4 (L-09, L-10, Q-01@status, Q-01@initiate). None is filed as a standalone `F-XX`. Each is a **pointer** to its primary report in `qa-report.md`, because each also has an operational impact and is rated Low or QA there.

## Story resolution

Every story was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree. Each tag matched exactly one document.

| Story | Path (under `~/code/product-owner/stories/phStaging2/`) | State folder | Approval |
|---|---|---|---|
| 087 | `auto-complete/phStaging2-stable-staker-v2/087-cutover-audit33-breaker-window-selfexit-gate-eth-preflight.md` | `auto-complete` | "story-batch workflow (machine approval — not human-reviewed)" (L352) |
| 090 | `auto-complete/phStaging2-stable-staker-v2/090-initiate-dola-strategy-minter-withdrawal.md` | `auto-complete` | "story-batch workflow (machine approval — not human-reviewed)" (L238) |
| 092 | `auto-complete/phStaging2-stable-staker-v2/092-cutover-minter-sya-repoint-and-retire-autodola-strategy.md` | `auto-complete` | "story-batch workflow (machine approval — not human-reviewed)" (L334) |

> **State-folder note.** All three stories sit in `auto-complete`, which is **not** one of the states listed in `registered-projects.json` → `storyPolicy` (`complete|incomplete|review|archive`). The folder is treated as metadata, not as a filter, so the stories stay in scope. `storyPolicy` should be extended to name this state.
>
> **Approval note.** Story 090 (and also 087 and 092) records **machine approval, not human review**. The 090-vs-092 conflict below is therefore a conflict between two machine-approved documents. No human has signed off on either wording.

---

## Pointer: L-09 (`pps35l9`), `stable-staker-v2-cutover`, story-092 step 5

- **Fingerprint**: `78cb5942d4834f366ab7d5600a449c73bb8d43833dd8b822e25801d623e39cc6`
- **Location**: `script/CutoverStableStakerV2Mainnet.s.sol#L1116-L1145` (`_minterReseedSdola`)
- **Severity**: Low (borderline Medium, flagged for human review). Primary report in `qa-report.md`.

**Story text (092, Technical Details step 5, L73), verbatim:**
> 5. **Re-seed**: `DOLA.forceApprove(minter, R)` then `minter.noMintDeposit(newYS, DOLA, R)`. Assert `newYS.principalOf(DOLA, minter)` is within bound of R (destination bps + WEI_SLACK). Assert OWNER's DOLA balance is back to its level before execution, so no DOLA is left on OWNER.

**Acceptance criterion (092, L180), verbatim:**
> - [x] `DOLA.forceApprove(minter, R)`; `noMintDeposit(newYS, DOLA, R)`; assert minter principal on newYS within bound; assert OWNER DOLA back to its level before execution

**Deviation.** The assert exists (L1142), but under `--broadcast --skip-simulation --slow --ledger` it runs only in forge's local pass. R is a literal baked from that pass. On chain, the execute redeems at the live price. If it delivers more than R, the excess stays on OWNER and `:verify` does not check OWNER's residual DOLA. If it delivers less, `noMintDeposit` reverts and ~14.59k DOLA of phUSD collateral is left on the OWNER EOA. The AC's intent ("no DOLA is left on OWNER") is therefore not enforced on the mined state. The halt-point (b) NatSpec claim that a differing local-pass R "cannot strand or over-deposit" is also false outside the resume path. Evidence: fork-logs UE-35-01/02, `09-verify-clean.log`, `12-*`.

## Pointer: L-10 (`pps35l10`), `stable-staker-v2-cutover`, story-087 budget criterion

- **Fingerprint**: `72e528c8715f0fb1e6c4fb3a7b98844c7f5cf0cc2211cb376a20cd2f3356dbc1`
- **Location**: `script/CutoverStableStakerV2Mainnet.s.sol#L410-L421` (`_preflightOwnerEth`, `CUTOVER_GAS_BUDGET`)
- **Severity**: Low. **⚠ INCOMPLETE FIX of fixed L-07 `d6896c6e843d` (`pps33l7`).** L-07 was left `fixed`, and a human decides whether to reopen it. Primary report in `qa-report.md`.

**Acceptance criteria (087, L183-L184, L187), verbatim:**
> - [x] Add `_preflightOwnerEth()` called from `run()` **only when not preview**, before `vm.startBroadcast()`, and **not** from `_phase0_preconditions` (the verifier calls that). It requires the gas-price env var to be set (loud revert if missing) and `OWNER.balance >= CUTOVER_GAS_BUDGET * max(gasPriceEnv, tx.gasprice) * 12 / 10`.
> - [x] Derive `CUTOVER_GAS_BUDGET` from `anvil-broadcast-gas-budget.txt`: total `gasUsed` (18,317,077) plus headroom for the upfront gas-**limit** check under `--gas-estimate-multiplier 200` (at least the largest late-run limit, #37's 3,383,096), rounded up; document the derivation in NatSpec. Full-run budget applies on resumes too (see Concerns).
>
> - [x] State the ETH budget in the `//…:broadcast` doc key (formula plus the figure at 0.3 and 0.35 gwei), correct "~47 transactions" to 46, and say to top up OWNER before signing.

**Story 087 problem statement (L136), verbatim:**
> Forge 1.5.1 sends txs one by one and aborts mid-run with `-32003 Insufficient funds`.

**Deviation.** The budget's derivation rule is tied to the 46-tx rehearsal. Stories 091 and 092 grew the session to 67 txs (22,982,701 gas used), but `CUTOVER_GAS_BUDGET = 22_000_000` was not re-derived. The same sizing rule now requires 25.16M, so 95% of the 20% margin is already consumed. The control the story added to prevent a mid-run `-32003` halt no longer meets its stated intent. Story 092's own Decision 3 (L247) still describes "a ~46-tx `--slow` Ledger session". Evidence: `fork-logs/07-gas-analysis.txt`, `07-cutover-broadcast-budgetExact.log`.

## Pointer: Q-01 @ `dola-ys-withdrawal:status` (issueId **not minted**, see note), story-092 runbook step 2

- **Fingerprint**: `8633815e4b2b833011046cf0ded65501329f76f0bf6fee6a79840d6b0e845a7f`
- **Location**: `script/DolaStrategyWithdrawalStatus.s.sol#L53-L60` (`run`)
- **Severity**: QA. Primary report in `qa-report.md`.

**Story text (092, broadcast order, L140-L146), verbatim:**
> Broadcast order:
>
> 1. `initiate-dola-ys-withdrawal:broadcast`
> 2. wait ≥6h, then check `dola-ys-withdrawal:status`
> 3. `stable-staker-v2-cutover:preview`, then `:broadcast`, within the window (minus the safety margin)

**Phase 0 acceptance criterion (092, L173), verbatim:**
> - [x] Phase 0: require minter withdrawal Initiated and `initiatedAt+6h <= now < initiatedAt+78h - WINDOW_SAFETY_MARGIN` (commented constant), with operator guidance on failure

**Status-reporter spec (090, L81), verbatim:**
> - seconds until executable and until expiry (or "expired (lazy)")

**Deviation.** Story 092 makes the status script the operator's go check, and gates the cutover's start on the 6h `WINDOW_SAFETY_MARGIN` (Decision 3: 6 hours). The script prints "EXECUTABLE - cutover may broadcast now" for the whole `[initiatedAt+6h, initiatedAt+78h]` window, including the last 6h, and also while the strategy is paused. In both cases `:preview`/`:broadcast` refuses in Phase 0, or the execute (`whenNotPaused`) reverts. The consumer fails closed before signing. **Quote provenance:** the phrase "must say EXECUTABLE" cited in the classifier's `storyAcceptanceViolated` does **not** appear in story 092. It comes from the story-092-mandated `package.json` `//StableStakerV2Cutover` runbook (src `package.json` L49). The story's own wording is the step-2 line quoted above. Evidence: `fork-logs/04-status-last6h.log` vs `04-cutover-preview-last6h.log`.

## Pointer: Q-01 @ `initiate-dola-ys-withdrawal` (issueId **not minted**, see note), story 090 vs 092 conflict

- **Fingerprint**: `4cdafc61037cb255ee4422487b88a8f0654718b6fbef5c6bb658c66d9b6a879e`
- **Location**: `script/InitiateDolaStrategyWithdrawal.s.sol#L181-L196` (`run`)
- **Severity**: QA. This is a story conflict, not an unsafe story. Primary report in `qa-report.md`.

**Story 090 (machine-approved), L72-L73, verbatim:**
> - Read back `withdrawalStates(DOLA, minter)`: status == Initiated, `balance == principal` (captured just before), `initiatedAt == block.timestamp`.
> - Log `executableAt = initiatedAt + 6h` and `expiresAt = initiatedAt + 78h`, as unix timestamps and in an ISO-like readable form, plus: "broadcast the cutover between executableAt and expiresAt".

**Story 090 AC (L124), verbatim:**
> - [x] Log executableAt / expiresAt (unix + readable) and the "broadcast the cutover between executableAt and expiresAt" instruction

**Story 092 (machine-approved), Phase 0 (L60), verbatim:**
> - If the minter phase is NOT yet done, require status Initiated and `initiatedAt + 6h <= block.timestamp < initiatedAt + 78h - WINDOW_SAFETY_MARGIN`. `WINDOW_SAFETY_MARGIN` is a constant with a comment justifying it (e.g. a few hours covering a slow Ledger session). On failure, revert with guidance: "run initiate-dola-ys-withdrawal:broadcast and wait (see dola-ys-withdrawal:status)".

**Deviation.** The script is **faithful to story 090's literal text**, but that text conflicts with story 092's later 6h start gate, and story 090 was not updated. An operator who follows the printed instruction can plan against a deadline up to 6h (plus signing latency) too late. Separately, the read-back and printed timestamps run after `vm.stopBroadcast()` in forge's local pass. Story 090's `initiatedAt == block.timestamp` read-back therefore holds only locally. The mined `initiatedAt` is later (1789569551 local vs 1789569586 mined, `fork-logs/02-initiate-broadcast-anvil.log`, `02-initiate-statediff.json`). Resolve the conflict in the story text (090's AC) as well as in the script.

---

## Not faithfulness-tagged this run
L-11 (`pps35l11`, `e6e1f293bbad`), Q-05 (`pps35q5`, `df5f14bae8a7`) and Q-06 (`pps35q6`, `9c4e21bb9fd7`) have no story-deviation tag. They appear in `qa-report.md` only. Carryover L-08 (`pps34l8`) and Q-04 (`pps34q4`) were faithfulness-tagged in run 34. Their pointers live in `reports/34/submissions/spec-conformance.md`, and their current state is in `carryover/qa-report-34.md`.

## issueId note
Both new Q-01 findings use per-entry-point label sequencing, so both would mint `pps35q1`. To keep `issueId` unique, neither was minted, and both ledger entries carry `issueIdPending`. Select them by fingerprint (`8633815e4b2b`, `4cdafc61037c`) until a human decides.
