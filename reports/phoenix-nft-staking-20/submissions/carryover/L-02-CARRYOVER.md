# [CARRYOVER] L-02 — Uncapped `count` loop in `batchMint`

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (`submitted` is an awaiting-triage status, not a human
> disposal — it is treated exactly like `open`). It is reproduced here so it is not lost
> between runs. Triage it with `/ledger phoenix-nft-staking`.

> ⚠ **LABEL-COLLISION GUARD (run-20 ruling R-3).** This `L-02` is the **ledger** entry
> `e35388bf…` on `src/BatchNFTMinter.sol`. It is **NOT** run-20's own `L-02`
> (`cb1b5279…`, `NFTStakerMigrator` has no rescue function). Disambiguate by fingerprint,
> never by label.

- **Severity:** Low
- **Status:** submitted (still-open)
- **Location:** `src/BatchNFTMinter.sol#L238-L240` (`batchMint`)
- **First seen:** phoenix-nft-staking-12  ·  **Still present as of:** phoenix-nft-staking-20
- **Original report:** [reports/phoenix-nft-staking-12/submissions/qa-report.md](../../phoenix-nft-staking-12/submissions/qa-report.md)
- **Fingerprint:** `e35388bfa2b5bbdb5c66fcac5682a63e45c9086b4e1a37dc3bff981445b37666`

**Re-observed this run as DEDUP-20-022.** story-022 added a **second and third** caller-sized
loop to the same function that already carried this finding for the first: the `count` mint loop
at `:363`, plus two passes over `rewardTokens` at `:424` and `:454`. There is no `MAX_COUNT`,
no `MAX_REWARD_TOKENS` and no pagination. All gas is paid by the caller and the failure mode is
**self-DoS**, so the impact is confined — and the behaviour is now explicitly spec-blessed by
`docs/multi-token-nudge.md` §4.5 (*"Long arrays: gas is paid by the caller; the block gas limit is
the bound"*). Severity is **unchanged at Low/QA**; no status change is proposed.

See the original report for the full description, impact, attack path and recommendation.
