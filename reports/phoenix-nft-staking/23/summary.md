# Run phoenix-nft-staking-23 — REGRESSION

- Type: Regression scan
- Submodule: `bb4fea0` → `9785bb9`
- Date: 2026-07-24

## Change set
The only diff between `bb4fea0` and `9785bb9` is the addition of one new first-party file:
- `src/INudgeStreamer.sol` — new 28-line first-party interface. Auto-in-scope per Law 1
  (default-in-scope denylist; new first-party contracts are scanned, never gated). Landed on
  untagged commits with NO `[story-NNN]`. **UNWIRED** — no implementation, no consumer, no import
  (grep-confirmed: only self-references).

## Result
- **0 new High / 0 new Medium / 0 new Low.**
- Nothing to PoC — an interface hosts no executable code path.
- All 64 prior ledger findings reconcile **unchanged** at their current statuses.
- No REGRESSION and no INCOMPLETE-FIX signal — no contract logic moved; only an interface
  declaration was added.
- No QA report, no spec-conformance report, no submissions this run.

## Design surfaces flagged (informational — for when an implementation lands)
- `registerStream(batchMinter, token, duration)` with `duration == 0` → potential div-by-zero / brick.
- Authorization ambiguity on `registerStream` / `collectNudge` (owner-only vs open donor).
- Mid-stream re-registration reconciliation of unvested balances (reset could strand/double-count).

## Watch-note recorded (WATCH-23-nudgestreamer-wiring)
When a concrete `NudgeStreamer` implementation and its wiring into `BatchNFTMinter` land, re-audit the
nudge over-funding cluster under the NEW time-vested model — synchronous-push assumptions of prior
findings do NOT carry over unchanged:
1. Re-validate `858e9e80` (BatchNFTMinter nudge MEV front-run + over-funding, wont-fix): streaming
   changes timing not totals; re-check whether vested `pullPendingStream` lets a recipient collect a
   nudge exceeding one mint cost, and whether the MEV window shifts from mint to `pullPendingStream`.
   The `858e9e80` acceptance basis (NFT has no redemption value, ~6.7x margin, caller-supplied
   rewardTokens not a vector) must be RE-VALIDATED, not assumed.
2. **HIGHEST PRIORITY**: revives run-22 M-01 (`43e8c486`, aggregate-nudge over-funding, Σ pots > 1 cost,
   PoC'd) — multiple donors `collectNudge` into the same recipientBatchMinter/token sum into one vested
   pot; confirm the streamer bounds AGGREGATE claimable to one mint cost (a per-stream cap does not
   close an aggregate hole).
3. New-surface checks: `registerStream` duration==0 div-by-zero/brick; unbounded duration; access
   control on registerStream/collectNudge; re-registration reconciliation of unvested balances;
   `pullPendingStream` reentrancy on token transfer; `pendingStream` vesting rounding must floor.
4. Solvency: verify the streamer escrows donor funds and a batchMinter can never pull more than
   collectNudge-deposited-and-vested (no mint-from-nothing analogue).

## ⚠ Ledger-write incident (resolved)
During this run the `finding-manager` subagent's ledger write silently reverted one finding
(`43e8c486`, run-22 M-01 aggregate-nudge) from `wont-fix` → `open`, discarding an uncommitted
working-tree triage, and self-reported "no status changes." Root cause: the write appears to have
rebuilt the file from `git show HEAD:` rather than editing the working-tree copy, so the uncommitted
`open→wont-fix` triage (present only in the working tree, invisible to a HEAD-diff) was lost, and the
agent's self-verification diffed only against HEAD. Caught by a session-start vs post-write status-count
diff (open39/wf16 → open40/wf15). The uncommitted state was unrecoverable from git (never `git add`ed)
and from all agent transcripts (none embed the full ledger). Restored to `wont-fix` per operator
confirmation; see the `[OPERATOR 2026-07-24]` marker on that finding's note.
