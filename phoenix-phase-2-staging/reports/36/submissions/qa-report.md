# QA Report for phoenix-phase-2-staging, run 36 (script audit)

- **Run**: `phoenix-phase-2-staging-36`
- **Source**: [Behodler/phoenix-phase-2-staging @ `91ed727`](https://github.com/Behodler/phoenix-phase-2-staging/tree/91ed727138e09720a28e70707d7d3df40a7d7ee2), branch `master`, read-only
- **Cluster (entry points)**: `stable-staker-v2-cutover`, `initiate-dola-ys-withdrawal`, `dola-ys-withdrawal:status`
- **Stories**: 093–097, under `~/code/product-owner/stories/phStaging2/`
- **Inputs**: `reports/36/findings/medium/stable-staker-v2-cutover__M-01.json`, `reports/36/script-audits/classified-findings.json`, `reports/36/submissions/spec-conformance.md`
- **Fork evidence**: real broadcasts on an anvil mainnet fork at block 25994908. Every `fork-logs/…` path below is relative to `reports/36/script-audits/`.

> **L-12 re-rated to M-01 by human triage 2026-09-17 → [`M-01.md`](./M-01.md).** The finding formerly filed here as L-12 (`pps36l12`, fingerprint `cf684d5dc289…`) is now Medium **M-01** (`pps36m1`). The owner confirmed that the frontend reads `StableStakerV2` from `mainnet-addresses.ts`, which turns the lapsed-window `0x0` address window into an availability impact. Its full text, PoC and mitigation are in `M-01.md` only. It is no longer part of this bundle.
>
> **Carryover is not in this file.** Earlier QA findings are carried in their own pruned copies, not merged or renumbered here (see [Carryover QA](#carryover-qa-not-re-sectioned-here)). Faithfulness is cross-listed in [`spec-conformance.md`](./spec-conformance.md) as F-04 → M-01.

## Summary

| Severity | New this run | Total in this bundle |
|----------|-------------:|---------------------:|
| Low Risk | 0 | 0 |
| Centralization | 0 | 0 |
| **Total** | **0** | **0** |

This run produced no Low and no centralization findings. Its only new finding is the Medium [M-01](./M-01.md), which was re-rated from L-12.

### Carryover QA (not re-sectioned here)

Carryover files for earlier audits:

- [`carryover/qa-report-34.md`](./carryover/qa-report-34.md): **Q-04** (`pps34q4`). L-08 (`pps34l8`) was removed as `fixed`.
- [`carryover/qa-report-35.md`](./carryover/qa-report-35.md): **L-09, L-10, Q-05, Q-06** (`stable-staker-v2-cutover`), **Q-01** (`dola-ys-withdrawal:status`) and **Q-01** (`initiate-dola-ys-withdrawal`). L-11 (`pps35l11`) had been removed from that copy while it was `wont-fix`.

None of these entries is flagged at `91ed727`. The seven retained entries, plus L-11, were verified on the fork evidence in `script-audits/cluster-analysis.md`. **Human triage applied `fixed` to all eight on 2026-09-17.** That same triage also minted issueIds for the two `Q-01` entries:

| Entry point | Label | issueId | Fingerprint | Status | Applied |
|---|---|---|---|---|---|
| stable-staker-v2-cutover | Q-04 (run 34) | `pps34q4` | `a62956952abd…` | **fixed** (was fix-pending) | APPLIED 2026-09-17 |
| stable-staker-v2-cutover | L-09 | `pps35l9` | `78cb5942d483…` | **fixed** (was fix-pending) | APPLIED 2026-09-17 |
| stable-staker-v2-cutover | L-10 | `pps35l10` | `72e528c8715f…` | **fixed** (was fix-pending) | APPLIED 2026-09-17 |
| stable-staker-v2-cutover | L-11 | `pps35l11` | `e6e1f293bbad…` | **fixed** (was wont-fix; story 096 fix verified on a real broadcast) | APPLIED 2026-09-17 |
| stable-staker-v2-cutover | Q-05 | `pps35q5` | `df5f14bae8a7…` | **fixed** (was open) | APPLIED 2026-09-17 |
| stable-staker-v2-cutover | Q-06 | `pps35q6` | `9c4e21bb9fd7…` | **fixed** (was open) | APPLIED 2026-09-17 |
| dola-ys-withdrawal:status | Q-01 | `pps35q7` | `8633815e4b2b…` | **fixed** (was open) | APPLIED 2026-09-17 |
| initiate-dola-ys-withdrawal | Q-01 | `pps35q8` | `4cdafc61037c…` | **fixed** (was open) | APPLIED 2026-09-17 |

The carryover copies above were written before this triage. They still show the pre-triage statuses and the unminted `Q-01` issueIds, so read the statuses and issueIds from this table (and the ledger).

---

## Low Risk Findings

None this run. L-12 was re-rated to M-01 ([`M-01.md`](./M-01.md)).

---

## Centralization Risks

None this run.

---

## Appendix: automated QA baseline (4naly3er)

**Not attached. The tool ran but crashed, the same as run 35.** `yarn analyze` in `tools/4naly3er` was run against the submodule root `phoenix-phase-2-staging/src` with a scope file listing `script/CutoverStableStakerV2Mainnet.s.sol`, `script/DolaStrategyWithdrawalStatus.s.sol`, `script/InitiateDolaStrategyWithdrawal.s.sol` and `script/VerifyStableStakerV2Cutover.s.sol`. It exited 1 inside the solc-0.8.27 wasm compile with `TypeError: Cannot read properties of undefined (reading 'contents')`, which points to an import-resolution failure on the scripts' nested `lib/` remappings. No `4naly3er-report.md` was written, because an empty file would read as a clean result. The M-01 (formerly L-12) root cause is in a JavaScript file, which 4naly3er does not analyse in any case. This run's QA therefore has **no bot-report baseline**.
