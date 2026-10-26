# Sanitization log: sya-harvester run 02 (regression)

- Commit 6b862aa on `master`; baseline 62c19c86be1594dcf82e8af794fcd6c28f9a8fc0 (lastRun sya-harvester-01)
- Input: `reports/02/dedup/deduplicated-findings.json`, 16 canonical rows
- Ledger index: `reports/02/run-setup.json` triageIndex (12 entries), cross-checked against `ledger.json` with a jq field projection only (`label, fingerprint, fingerprintInput, status, severity, firstSeenRun, lastSeenRun, branch, branchesSeen, reportPath`). The whole ledger was never read, and the ledger was not written.

## 1. Known issues and out of scope

- Known issues: none. Registry knownIssuesCount is 0, and README and `src/CLAUDE.md` have no Known Issues or Out of Scope section.
- `designDecisions` and in-source NatSpec have no suppression authority, so nothing was matched against them.
- No row is in `src/lib/**`. The two `test/` rows (Q-05, Q-06) are carried ledger findings about first-party test and fixture fidelity. They are not tool noise, so they stay.
- **Removals: 0.**

## 2. Fingerprint verification

For every row I recomputed `sha256(fingerprintInput)`, where the input is `contract:function:rootCauseClass` and `entryPoint` is empty. All 12 carried rows match their ledger fingerprint exactly. None of the 4 new fingerprints collides with any of the 12 ledger entries.

| Row | Fingerprint | Ledger | Status | Bucket |
|---|---|---|---|---|
| DEDUP-02-M01 | 004d4547d9 | M-01 | fix-pending | **FIX-PENDING, LIKELY-FIXED** |
| DEDUP-02-L01 | d7744b9d24 | L-01 | open | still-open |
| DEDUP-02-L02 | 464b942691 | L-02 | open | still-open |
| DEDUP-02-L03 | 4994fe853f | L-03 | open | still-open |
| DEDUP-02-L04 | 8cc1530764 | L-04 | open | still-open |
| DEDUP-02-Q01 | e95e3c9bae | Q-01 | open | still-open |
| DEDUP-02-Q02 | 0df667c2a6 | Q-02 | open | still-open |
| DEDUP-02-Q03 | fed35932d0 | Q-03 | open | still-open |
| DEDUP-02-Q04 | dd56134239 | Q-04 | open | still-open |
| DEDUP-02-Q05 | bec3cacbc1 | Q-05 | open | still-open |
| DEDUP-02-Q06 | 500b52898d | Q-06 | open | still-open |
| DEDUP-02-Q07 | 23efa79596 | Q-07 | open | still-open |
| DEDUP-02-N01 | 3dc3002290 | none | none | new |
| DEDUP-02-N02 | f8cfb5533d | none | none | new |
| DEDUP-02-N03 | 213ac28601 | none | none | new |
| DEDUP-02-N04 | 7ae00c3a37 | none | none | new (splitFrom M-01) |

Ledger statuses present: 1 fix-pending, 11 open. There are no acknowledged, wont-fix, false-positive, abandoned or fixed entries, so **no suppressions and no regressions are possible this run.** Every row is stamped `branch: master`. The carried entries are already `branchesSeen: [master]`.

## 3. M-01 (fix-pending): LIKELY-FIXED, not suppressed

`setRoute` changed between 62c19c8 and 6b862aa: the validator was rewritten and `InvalidRouteGap`, `InvalidRouteToken`, `InvalidRouteSwapParams` and `InvalidRoutePools` were added. The heading is therefore one of the "code changed" cases. **The evidence shows the exploit no longer reproduces, so this is not "FIX-PENDING STILL LIVE".**

Evidence:
- **Fork replay, re-run by me at 6b862aa:** `work/test/audit/CodeScan02M01Replay.fork.t.sol` with `MAINNET_RPC_URL=$RPC_MAINNET`.
  - `test_M01_gapRoute_strandsCrvUsd_andUnderpaysCaller` and `test_M01_validator_acceptsGap_rejectsHonestWrongEnd` both now fail with `InvalidRouteGap(10)` at `setRoute`.
  - The control and `test_fork_M01_gapRoute_rejectedBySetRoute` pass, as do the upstream fork tests.
- **Halmos:** `check_R1_soundReal` passes (22 paths) and `check_R0_kZeroOnlyForReward` passes. Sources: `symbolic/halmos-R1-real.log` and `symbolic/halmos-R0.log`.
- **Invariants:** `invariant_noStranding` and `invariant_routeRegistrySound` pass over 2000 runs x 200000 calls. Source: `invariants/forge-adversarial.log`.

Decision:
- Status stays `fix-pending`. Origin is `still-open`, `lastSeenRun` is bumped, no report is regenerated, and a full carryover copy goes in as `submissions/M-01-C<n>.md`.
- **Proposal: `/ledger sya-harvester fixed M-01`, for a human to apply.** Do not auto-flip it.

Caveats for the human:
1. The original PoC `work/test/poc-M-01-gap-route-strand.t.sol` does not compile. Its `_gapPath` collides with a non-virtual `_gapPath` at `test/fork/SYAHarvester.fork.t.sol:414`, and the failure breaks compilation of the whole workspace. I reproduced with `--skip test/poc-M-01-gap-route-strand.t.sol`. `/recheck` needs the rename or the skip.
2. The A-group symbolic checks (A1..A7) were not re-run at 6b862aa.
3. There is no swapParams-row mutant, so R1 clauses (e) and (f) are not shown to discriminate.
4. The story-001 Law-2 residual is split out as N04. If the human would rather keep it as a note on M-01, M-01 should not close until story-001 is amended or a no-amend policy is recorded.

## 4. still-open (11 entries): carryover, not re-reported

L-01..L-04 and Q-01..Q-07: origin `still-open`, bump `lastSeenRun` to sya-harvester-02, and no report is regenerated. finding-manager copies them forward in full (not as a stub) into `submissions/carryover/qa-report-01.md`. The source is `sya-harvester/reports/01/submissions/qa-report.md`. Every entry has firstSeenRun sya-harvester-01.

Notes:
- Q-06 is partially addressed: sub-issue 2 by the Router NG-faithful mock, while residual sub-issue 4 remains. It stays open, and the human may want to re-scope its title at triage.
- L-04's root is unaddressed: the KNOWN_ERRORS additions only cover the new harvester errors.

## 5. new (4 rows): proceed to classification

- **N01** (`setRoute`, swap_type >= 9 accepted). This sits next to the M-01 fix, but its failure mode is a fail-loud revert ("Bad swap type"), not a silent strand. It is classified **new, not incompleteFixOf M-01**, and kept. severity-classifier decides between QA and Low.
- **N02** (story-006 premise about k=0 delivery is wrong). Info, spec-conformance.
- **N03** (story-007 premise about `_pools` and swap types 3/5/7 is wrong). Info, spec-conformance.
- **N04** (story-001 is unamended and still prescribes the last-non-zero rule plus the vulnerable CurveAMMAdapter template). QA, spec-conformance. **splitFrom M-01 (004d4547d9).** It has its own rootCauseClass, so M-01 can be proposed fixed without hiding this residual.

## Bucket counts

| Bucket | Count |
|---|---|
| new | 4 |
| still-open (open) | 11 |
| fix-pending, LIKELY-FIXED | 1 |
| fix-pending, STILL LIVE | 0 |
| regression | 0 |
| suppressed (ledger status) | 0 |
| known issue / OOS removed | 0 |
| **total** | **16** |
