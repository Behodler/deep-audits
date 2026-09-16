# Script review: `initiate-dola-ys-withdrawal` (run 35)

- **Source**: [Behodler/phoenix-phase-2-staging @ `7ac6e70`](https://github.com/Behodler/phoenix-phase-2-staging/tree/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963), branch `master`, read-only. This is a cold audit with no prior ledger entries.
- **Script**: [`script/InitiateDolaStrategyWithdrawal.s.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/InitiateDolaStrategyWithdrawal.s.sol)
- **npm keys**: [package.json#L56-L58](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L56-L58) (`//InitiateDolaStrategyWithdrawal`, `:preview`, `:broadcast`).
- **Story**: story-090, `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/090-initiate-dola-strategy-minter-withdrawal.md`. It resolved to one document, in the `auto-complete` state, machine-approved. Its runtime consumer is story-092 (cutover Phase 0 and Phase 6b).
- **Mode**: fork preview on anvil at block 25990689. The broadcast was simulated with `--unlocked`. Nothing was sent to mainnet.
- **Primary report**: [`../../submissions/qa-report.md`](../../submissions/qa-report.md).

## Conclusion

The script is correct and minimal. It makes exactly the first `totalWithdrawal(DOLA, PhusdStableMinter)` call, writes only the three `withdrawalStates[DOLA][minter]` fields, and moves no value. It refuses to run the executing second call and fails closed after the cutover. **0 High, 0 Medium, 0 Low, 1 QA.** Q-01 covers operator output only: the printed "broadcast the cutover between executableAt and expiresAt" instruction ignores story 092's 6h start margin, and the printed timestamps come from forge's local pass rather than the mined block. The script follows story 090 faithfully. The defect is a conflict between stories 090 and 092.

## 1. Does it do what it intends?

**Yes.** Every story-090 acceptance criterion is met. The only exception is the instruction line, which is faithful to 090 but conflicts with 092.

| Story-090 intent | Result | Evidence |
|---|---|---|
| Start the clock only: the first `totalWithdrawal(DOLA, minter)` on 0x1760, with nothing moved | Met. 1 tx, 101,456 gas, `WithdrawalInitiated(DOLA, minter, 14594.562…, 1789569586, 1789591186)` | `fork-logs/02-initiate-broadcast-anvil.log`, `02-initiate-statediff.json` |
| Refuse the executing second call while pending, during both the wait and the window | Met by the preflight's status/timestamp ladder. Consistent with `AYieldStrategy._updateWithdrawalStatus`. The sponsor fork test covers it (not re-run here) | `intent.md` |
| Withdraw only the minter; reject V1 | Met (`client == minter && client != V1`) | `side-effects.json` |
| Assert the on-chain 6h / 72h constants | Met | `01-initiate-preview.log` |
| Preflight: chainid 1, owner, underlying DOLA, not paused, principal > 0 | Met | `01` |
| Read back status Initiated, `balance == principal`, `initiatedAt == block.timestamp` | Met, **but only in the local pass.** Printed 1789569551, mined 1789569586 | **Q-01**; `02` |
| Log executableAt / expiresAt and "broadcast the cutover between executableAt and expiresAt" | Met literally. **The instruction conflicts with story 092's `WINDOW_SAFETY_MARGIN`** | **Q-01** |

## 2. Unintended side effects?

**None.** The prestate state diff shows only:
- the three `withdrawalStates[DOLA][minter]` slots on 0x1760: `initiatedAt` 0 → 1789569586, `status` None → Initiated, `balance` 0 → 14594562039048160037533
- the OWNER nonce and gas spend

There were no other storage writes, events or external calls. After the cutover the preview reverts with "preflight: strategy is paused", which fails closed as intended. The message does not say that the withdrawal has already executed, which is a cosmetic gap and not filed.

## 3. Knock-on problems / cluster

- **This script starts the cutover's clock.** The mined `initiatedAt` (T0) fixes the cutover's legal start range at `[T0+6h, T0+72h)`, with the execute mined by `T0+78h`. The printed deadline is `expiresAt` (T0+78h), and it is computed from the local-pass timestamp. An operator who plans to it can start too late for Phase 0. Phase 0 fails closed, so the cost is re-initiating and waiting another 6h.
- **Out-of-band execute (OBS-35-I2).** For 72h, any OWNER `totalWithdrawal(DOLA, minter)`, for example from the skip-worktree'd `Temp.s.sol` on the same Ledger key, would execute the withdrawal out of order. Not filed under Law 3 (see below).
- **A global pause during the window** blocks the execute, because it is `whenNotPaused` (OBS-35-I3, documented). A lapse caused this way leads into cutover L-11.
- **Sibling finding.** `dola-ys-withdrawal:status` Q-01 has the same 6h-margin gap on the other operator signal.

## Findings register

Where links are pinned to `7ac6e70`.

| Label | Sev | Fingerprint | What | Mitigation | Where |
|---|---|---|---|---|---|
| Q-01 (issueId **pending**, see note) | QA, F-tagged (story 090 vs 092 conflict) | `4cdafc61037c` | The instruction "broadcast the cutover between executableAt and expiresAt" ignores the 6h `WINDOW_SAFETY_MARGIN`, and the printed timestamps and READBACK are local-pass values, not mined ones | Print "start between executableAt and expiresAt − 6h", label the timestamps as local-pass estimates and point to `dola-ys-withdrawal:status`, and have the PO update story 090's AC | [InitiateDolaStrategyWithdrawal.s.sol#L181-L196](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/InitiateDolaStrategyWithdrawal.s.sol#L181-L196) |

**issueId note.** Both run-35 Q-01 findings (this one and `dola-ys-withdrawal:status` Q-01) would derive to `pps35q1`. Neither was minted, and the ledger holds `issueId: null`. Use the fingerprint `4cdafc61037c` until a human chooses the ID.

## Refuted / not filed

| Obs | Verdict | Reason |
|---|---|---|
| OBS-35-I1 | Confirmed, not a finding | The snapshot balance equals principal. The execute sweeps live principal (P 14594.56 → R 14633.14 DOLA), as designed |
| OBS-35-I2 | Not filed (Law 3) | An out-of-band OWNER execute inside the window needs a knowing owner action in a window the owner opened, and the script and runbook both warn against it. "Pulls V1 stakers' value" is overstated because `_totalWithdraw` is pro-rata by principal. It only removes the minter cushion for V1's exit if autoDOLA is below par, and it is above par at 25990689 |
| OBS-35-I3 | Confirmed documented behaviour | A global pause during the window blocks the execute (`whenNotPaused`). The blast radius is covered by cutover L-11 |
| OBS-35-I4 | Not a finding | There is no ETH preflight. The script sends a single 101,456-gas transaction |
| OBS-35-08 | Not filed | The live cutover preview cannot run before `T0+6h`. Initiation moves nothing and can be re-initiated, and story 092 prescribes this order |
