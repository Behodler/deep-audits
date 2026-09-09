# yield-claim-nft — Run 14 Final Review

- **Run:** yield-claim-nft-14
- **Mode:** Regression scan @ submodule HEAD `4f80541` (story-042)
- **Baseline:** prior `lastAuditedCommit` `aa86be6` (run-13)
- **Net result:** 1 new Low finding (L-11), 0 High, 0 Medium, 0 regressions.

## Scope change this run

Story-042 introduced a new first-party contract, **`src/MultiPooler.sol`** — an
atomic batch-pooler (`onlyPooler` trusted keeper) that wraps multiple
`Uniboost.pool` calls into a single all-or-nothing transaction — plus its
interface `src/interfaces/IUniboostPooler.sol`. Both were auto-pulled into scope
(default-in-scope denylist) and added to the registry scope snapshot.

## Scanners run

contract-profiler · static-analyzer (Slither / Aderyn / Semgrep) ·
pattern-matcher · code-scanner · econ-scanner · story-faithfulness ·
deduplicator → sanitizer → validity-checker → severity-classifier →
severity-auditor.

**Tier-3 (invariant-generator / symbolic-analyzer) SKIPPED** — rationale: no
High/Medium candidate surfaced, and the single Low is an off-chain keeper
batch-ordering footgun (the staleness arises from off-chain floor computation vs.
in-batch on-chain reserve drift), which is not expressible as an on-chain
invariant. Nothing for fork/symbolic execution to add.

## New finding

### L-11 (ECON-042-01) — MultiPooler same-pool in-batch floor staleness — **Low**, footgun, open, qa-bundled

- **Location:** `src/MultiPooler.sol#L60-L67` (`pool`)
- **Fingerprint:** `531916f4…`
- **Class:** non-obvious Law-3 owner/keeper footgun (in scope).

`MultiPooler.pool` batches `Uniboost.pool` calls atomically. If two `PoolCall`
rows target dispatchers sitting on the **same** UniV2 pool, an earlier row's
swaps move the shared pool reserves, **staling the later row's off-chain-computed
min floors**. Dual impact:

- **Primary (expected):** the whole atomic batch **reverts** against the staled
  on-chain floors → **self-inflicted DoS** (wasted gas, no loss of funds).
- **Secondary:** a **floor-bounded degraded LP add** if floors are set loose
  enough to clear.

POL-only, no theft, keeper-avoidable, and the **default one-pool-per-dispatcher
deployment is unaffected**. Kept by the sanitizer + validity-checker (not a
known-invalid); Low confirmed by both severity-classifier and severity-auditor.

**Safe-config guidance:** do not co-batch same-pool dispatchers in a single
`MultiPooler.pool` call; if unavoidable, order the rows and size each floor to
tolerate in-batch reserve drift from earlier rows on the shared pool.

## Reconciliation of existing findings

- **L-06** (`342075d…`, Uniboost/Balancer off-chain-floor LP-add MEV, Low/open):
  **still present** — PATTERN-001 + SLITHER-002 collapsed into it this run (same
  off-chain-floor MEV-sandwich root-cause class). econ-scanner confirmed
  story-042 does **not** escalate it: the new `amountIn` parameterization is
  **MEV-neutral-to-beneficial**. Status unchanged (open/Low); `lastSeenRun`
  bumped to yield-claim-nft-14.
- **L-09 / L-10** (Uniboost no-hookTypeId-guard / UniboostMintDebtHook.scale):
  the `_dispatch`/hook path is **not** in the story-042 diff (MultiPooler does not
  touch hooks). Untouched open carryover.
- **L-04, L-05, L-07, Q-05, Q-10:** outside this run's changed files. Untouched
  open carryover.
- **M-04** (NudgeRatchet hookTypeId literal-pair guard, fixed): NudgeRatchet is
  **not** in the diff → the literal-pair drift watch did **not** trip → **no
  regression**; stays `fixed`.

## Verdicts

- **code-scanner:** clean — no new implementation bug beyond the batch-ordering
  footgun.
- **story-faithfulness:** clean — MultiPooler faithfully implements the
  story-042 atomic-batch intent; L-11 is an operational hazard, not a spec
  deviation (`faithfulness: false`).

## Open carryover findings (kept visible — see `submissions/carryover/`)

L-04, L-05, L-06, L-07, L-09, L-10, Q-05, Q-10 remain **open** in the ledger.
Thin carryover stubs were written so none is dropped from view in run-14; triage
via `/ledger yield-claim-nft`.

## Ledger state after run-14

- `lastAuditedCommit` → `4f8054139b5ca0ffc3efd37da873715ad501b4e9`
- `lastRun` → `yield-claim-nft-14`
- Entries: 27 total — open 9, fixed 7, qa-bundled 7, wont-fix 3, suppressed 1.
