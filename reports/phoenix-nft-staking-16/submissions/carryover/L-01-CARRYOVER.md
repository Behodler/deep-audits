# [CARRYOVER] L-01 — batchMint lacks nonReentrant; ERC1155 onERC1155Received fires mid-loop

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-nft-staking`.

- **Severity:** Low
- **Status:** open (still-open / submitted)
- **Location:** `src/BatchNFTMinter.sol#L238-L257` (`batchMint`)
- **First seen:** phoenix-nft-staking-12  ·  **Still present as of:** phoenix-nft-staking-16
- **Original report:** [reports/phoenix-nft-staking-12/submissions/qa-report.md](../../../phoenix-nft-staking-12/submissions/qa-report.md)
- **Fingerprint:** `9135cf79…`

Re-confirmed this run (SLITHER-001 / PATTERN-001 at HEAD 5f863d2); the missing `nonReentrant`
guard persists but remains **not exploitable beyond Low** (the High third-party-theft escalation
is not supported — the nested frame's `forceApprove(minter,0)` revokes the outer loop's approval).
No severity change.

See the original report for the full description, impact, attack path, PoC, and recommendation.
