# QA Report for phoenix-phase-2-staging

**Run**: 42 (script audit, `/audit-script phoenix-phase-2-staging dev`)
**Entry Point**: `dev`
**Commit**: `d0060cb` (tracked branch `master`)

## Summary

| Severity | Count (new this run) |
|----------|-------|
| Low Risk | 0 |
| Centralization | 0 |
| **Total** | **0** |

Run 42 produced **no new or regressed Low or Centralization findings** for the `dev` entry point. This run therefore assigns no L-XX or C-XX labels and mints no `pps42l*` or `pps42c*` issue IDs.

## Where the rest of this run's findings are

- **Faithfulness (Law 2):** the only run-42 finding is the recurrence of F-03 (fingerprint `da94d1ba03fd…`, Low). It is a story/spec deviation, so it is reported in [`spec-conformance.md`](spec-conformance.md) and not in this QA bundle.
- **Carried-over QA/Low (still `open` or `fix-pending`):** these are not merged into this bundle and not renumbered. Each originating audit has its own pruned file under [`carryover/`](carryover/), and [`carryover/README.md`](carryover/README.md) indexes them with run-42 verdicts and proposed `/ledger` commands. The carried-over Mediums are [`M-01-C1.md`](M-01-C1.md) and [`M-01-C2.md`](M-01-C2.md).

## Automated QA appendix (4naly3er)

No 4naly3er report is attached for this run. Run 42 is a script-scoped audit with no new Solidity QA surface to bundle, and `4naly3er-report.md` was not produced. This is a known gap, not a clean result: run `yarn analyze` from `tools/4naly3er` against `phoenix-phase-2-staging/src` if a bot-report baseline is needed.
