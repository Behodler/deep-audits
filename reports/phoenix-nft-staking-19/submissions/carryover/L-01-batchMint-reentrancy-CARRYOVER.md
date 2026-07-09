# [CARRYOVER] L-01 — batchMint lacks nonReentrant; ERC1155 onERC1155Received fires mid-loop

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-nft-staking`.

- **Severity:** Low
- **Status:** open (still-open; submitted)
- **Location:** `src/BatchNFTMinter.sol#L238-L257` (`batchMint`)
- **First seen:** phoenix-nft-staking-12  ·  **Still present as of:** phoenix-nft-staking-19
- **Original report:** [reports/phoenix-nft-staking-12/submissions/qa-report.md](../../phoenix-nft-staking-12/submissions/qa-report.md)
- **Fingerprint:** `9135cf79…`

Re-confirmed present @321d0a9 by this cold-full scan (DEDUP-19-001). NOT re-reported. Missing `nonReentrant` guard is real but not exploitable beyond Low (every reentry is self-defeating; validated Tier-3 PoC `workspace/phoenix-nft-staking/test/poc-L01-reentrancy.t.sol`, 4 cases). Defense-in-depth. See the original QA report for the full description, impact, attack path, PoC, and recommendation.
