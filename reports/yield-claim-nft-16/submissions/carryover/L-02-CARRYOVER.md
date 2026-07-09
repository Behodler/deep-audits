# [CARRYOVER] L-02 — setRatio accepts ratio == MAX_RATIO, contradicting documented strict-less-than invariant

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged away). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low (qa-bundled)
- **Status:** open / qa-bundled (re-confirmed still-open at f46a5cb in run-16)
- **Location:** `src/hooks/BalancerPoolerMintDebtHook.sol#L77-L82` (`setRatio`); byte-identical instance at `src/hooks/UniboostMintDebtHook.sol#L95-L101` (`setRatio`)
- **First seen:** yield-claim-nft-08  ·  **Still present as of:** yield-claim-nft-16
- **Original report:** [reports/yield-claim-nft-08/submissions/qa-report.md](../../yield-claim-nft-08/submissions/qa-report.md)
- **Fingerprint:** `5425119c…`
- **Run-16 added datum (L-02 echo, not a new label):** `DEFAULT_RATIO` was raised 30→50 (commit `924b188`), so the deployed `DEFAULT_RATIO` now equals `MAX_RATIO == 50` and already sits on the inclusive boundary the strict-`<` NatSpec forbids on **both** hooks. Same fingerprint; recorded as an instanceNote on L-02, no new label minted (subsumes the deduplicator's mis-flagged F-16-01/PATTERN-001/CODE-003).

See the original report for the full description, impact, attack path, and recommendation.
