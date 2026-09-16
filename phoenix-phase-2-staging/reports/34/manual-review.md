# Manual review: phoenix-phase-2-staging run 34 (`stable-staker-v2-cutover`)

- **Run**: `phoenix-phase-2-staging-34`. **Commit**: `84e2324829bd6470ea4a42480290c5239dbec49e` (branch `master`). **Baseline**: `29aeb2b` (run 33).
- **Source**: `reports/34/script-audits/stable-staker-v2-cutover/manual-review.json`, plus the ledger's `manualReview` array for the item restated from run 31.
- **Purpose**: this is the Law-1 visible parking channel. None of these items is a ledger finding, and none has been dropped. Each one needs either a human decision or a human action.

| ID | Kind | Confidence | Needs |
|---|---|---|---|
| MR-34-SSV2C-01 | Audit-tooling observation (Law-1 visibility) | high | Retire or skip the run-33 harness, and repoint the run-33 PoC references |
| MR-34-SSV2C-02 | Operational action required before broadcast | high | Top up OWNER ETH |
| MR-34-SSV2C-03 | Acknowledged residual (story 087 Concerns) | medium | Re-evaluate if L-08 rec 4 is declined |
| MR-34-SSV2C-04 | Gap in the audit method | high | Harden breaker-liveness probes |
| MR-31-SSV2C-01 | Out-of-slice root cause (restated) | n/a | **Still OPEN, awaiting human decision** |

---

## MR-34-SSV2C-01: the run-33 audit harness no longer compiles (tooling / Law-1 visibility)

The run-33 harness `work/test/audit-run33/CutoverAuditRun33.t.sol` no longer compiles at `84e2324`, because story 087 deleted `_aggregatePrincipalFloor`. Unless the file is skipped, it also breaks the whole `work/` build. Run 34 ported its scenarios to `work/test/audit-run34/CutoverAuditRun34.t.sol`, where all 19 tests pass.

**Why it matters:** a `/recheck` that replays a run-33 PoC will read INCONCLUSIVE (bit-rot), and an unskipped build fails for every suite. Several ledger entries still point `pocPath` at the run-33 file: L-05 `fc44ca36`, L-06 `cf4b531a` and L-07 `d6896c6e`.

**Action (human):** retire or skip the run-33 harness, and point the run-33 ledger PoC references at the run-34 ports. Finding-manager did not rewrite `pocPath`. That field records the evidence at the time of filing.

## MR-34-SSV2C-02: OWNER ETH shortfall before broadcast (operational)

At block 25988932 the live preview reports `ETH_BUDGET|SHORTFALL` of 0.001495080548312714 ETH: OWNER holds 0.006425 ETH but needs 0.00792 ETH at 0.3 gwei. As a result, `_preflightOwnerEth` would refuse `:broadcast` today.

This is the L-07 fix working as intended, not a defect. A top-up is still owed before broadcast. The budget was derived from a rehearsal at block 25981150, so re-derive it if staker counts grow materially.

## MR-34-SSV2C-03: the USDe exit-realization bound covers the exit leg only (acknowledged residual)

The exit-realization bound uses `_maxLossBps` (61 bps for USDe) on the exit leg alone. On a resume or verifier leg, the USDe exit leg is bounded but the round trip is not.

Story 087 Concerns acknowledge this, which makes it a knowing owner decision under Law 3, so it is not filed as a finding. It is parked here because it compounds L-08 (`pps34l8`): the verifier checks only the re-deposit leg per user.

**Action (human):** if L-08 recommendation 4 (a per-user total check in the verifier) is declined, re-evaluate whether anything other than the per-pool aggregate bounds the USDe total.

## MR-34-SSV2C-04: the halt-point liveness probe checks only registered contracts (audit-method gap)

`test_P7_everyHaltPoint_breakerLive_resumeConverges` scores a halt point "LIVE" when `Pauser.pause()` does not revert and every contract currently registered is paused. It never checks whether V2 or Antimatter is actually reached. That is why it reported halt 5 as LIVE and missed the Q-04 (`pps34q4`) window. It was caught only by the gap-fix test `test_P7_halt5_globalPauseCannotReachV2`.

The probe has two further limits: it runs its resume in preview mode (`previewFlag = true`), and it forks at 25981150 rather than the live block.

**Action:** future breaker-liveness probes, in both the audit harness and the project's Phase-8/preview `GLOBAL_PAUSE` probe, should assert that the **target contracts are paused**, not only that `pause()` did not revert.

---

## MR-31-SSV2C-01 (restated): live mainnet Pauser `pause()` brick. STILL OPEN, awaiting human decision

- **Raised:** run 31 (2026-09-14). **Ledger status:** `OPEN - awaiting human decision`, `ruling: null`. Run 34 did not modify it.
- **Summary:** the global Pauser `0x7c5A8EeF1d836450C019FB036453ac6eC97885a3` loops `pause()` over every registrant without try/catch. When run 31 raised this item, two registered contracts were already paused: PhlimboEA V1 `0x3984eBC8…` and the retired USDC yield strategy `0xf5F91E82…`. `Pauser.pause()` therefore reverted `EnforcedPause` (0xd93c0665), which left the permissionless EYE-burn emergency stop dead for about 30 contracts. The condition predates story 082. `unpause()` has the same fragility in the other direction.
- **Run-32 observation (unchanged):** the owner unregistered both stale registrants on-chain at blocks 25978110 and 25978114. The brick is therefore **cleared by external state, not by any code or script guard**.
- **Run-34 observation:** at block 25988932 the live preview shows 26 registrants, none paused, and a strict simulated global pause succeeds at all 9 stages. The brick is still absent. No structural guard prevents it from recurring: any registrant that is paused while still registered re-bricks the loop.
- **Why it is still open:** an entry-point-scoped run cannot file a protocol-wide registry finding, and the Pauser repo is not a registered audit project. The recommendation still stands. Track it as a separate ops/registry-hygiene entry, rated on its protocol-wide impact, and consider registering the Pauser repo. Run 34 made no ruling.
