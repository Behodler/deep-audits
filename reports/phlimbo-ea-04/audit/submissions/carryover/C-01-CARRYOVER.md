# [CARRYOVER] C-01 — setDepletionDuration has no minimum-duration floor and no two-step gate; one-tx flash drain of rewardBalance

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Centralization
- **Status:** open (still-open carryover)
- **Location:** `src/Phlimbo.sol#L178-L191` (`setDepletionDuration`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea-03/audit/findings/centralization/C-01-setDepletionDuration-flash-drain.json](../../../../phlimbo-ea-03/audit/findings/centralization/C-01-setDepletionDuration-flash-drain.json)
- **Fingerprint:** `344d5f03…`

> **Note on labels:** this is **ledger** label C-01 (setDepletionDuration flash-drain).
> It is NOT this run's run-label C-01 (which is the setPauser(0)+emergencyTransfer
> footgun = ledger C-02). Carryover stubs use ledger labels.

See the original report for the full description, impact, attack path, PoC, and recommendation.
