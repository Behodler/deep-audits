# [CARRYOVER] C-04 — Pauser can sandwich pause/unpause cycles to selectively deny yield to specific stakers

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Centralization (dual-listed as ledger L-05)
- **Status:** open (still-open carryover; flagged partial-match-KI-6)
- **Location:** `src/Phlimbo.sol#L197-L261` (`pause`/`unpause`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea/03/audit/findings/centralization/C-04-pause-unpause-sandwich.json](../../../../03/audit/findings/centralization/C-04-pause-unpause-sandwich.json)
- **Dual-listed (Low) report:** [reports/phlimbo-ea/03/audit/findings/low/L-05-pause-unpause-sandwich.json](../../../../03/audit/findings/low/L-05-pause-unpause-sandwich.json)
- **Fingerprint:** `745678e0…`

> Single unique finding, dual-listed as C-04 and L-05 in the ledger; one stub covers both.

See the original report for the full description, impact, attack path, PoC, and recommendation.
