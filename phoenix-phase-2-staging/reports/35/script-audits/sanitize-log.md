# Sanitize log: phoenix-phase-2-staging-35 (script audit)

Source 7ac6e70, branch master. Ledger read through jq projections only and not modified.

## 1. Known issues
- `src/known-issues.md` **does not exist at 7ac6e70** (`git ls-tree`), and no tracked file has a Known Issues section. The 11 registry `knownIssues` entries come from a cache with `knownIssuesSource: null`, so they cannot be checked and carry **no suppression authority** (memory: phstaging-known-issues-cache-unfalsifiable, in-source-natspec-carries-no-suppression-authority).
- Even on their wording, none of the 11 cover any finding in this run.
- **Removed: 0. Suppressed: 0.**

## 2. Fingerprints
The formula is `sha256(ledgerContract:function:rootCauseClass:entryPoint)` with the `lib/phoenix-phase-2-staging/` prefix. I confirmed the convention by recomputing ledger L-08 6022a9eb, Q-04 a6295695, L-07 d6896c6e and Q-02 1c859cde, and all four matched byte for byte.

| label | entryPoint | fingerprint | origin |
|---|---|---|---|
| L-09 | stable-staker-v2-cutover | 78cb5942d4834f366ab7d5600a449c73bb8d43833dd8b822e25801d623e39cc6 | new |
| L-10 | stable-staker-v2-cutover | 72e528c8715f0fb1e6c4fb3a7b98844c7f5cf0cc2211cb376a20cd2f3356dbc1 | new (incomplete fix of fixed L-07) |
| Q-05 | stable-staker-v2-cutover | df5f14bae8a75c93f0c162bd3d4b842c21215bd12656531f51b356ec7dd75bc6 | new |
| Q-06 | stable-staker-v2-cutover | e6e1f293bbad543573c8e564c9ee1f70a0139dc107fca28b629117292b79cfde | new |
| Q-07 | stable-staker-v2-cutover | 9c4e21bb9fd79d8bc0f09ed0089b2cd63d94bfdbcdd1e44728b1ef4b324ab08c | new |
| Q-01 | dola-ys-withdrawal:status | 8633815e4b2b833011046cf0ded65501329f76f0bf6fee6a79840d6b0e845a7f | new |
| Q-01 | initiate-dola-ys-withdrawal | 4cdafc61037cb255ee4422487b88a8f0654718b6fbef5c6bb658c66d9b6a879e | new |

Input strings are recorded verbatim in sanitized-findings.json. For Q-07 the function string is `loadExtractedAddresses (server/index.js)` exactly as filed, even though that code is in a different file from `contract`.

## 3. Reconciliation
No fingerprint matched, so there are **0 regressions, 0 still-open, 0 wont-fix re-filings and 0 abandoned**. No wont-fix entry was matched, so nothing needed disclosing. Semantic neighbours I checked:
- **L-10 is an incomplete fix of FIXED L-07 `d6896c6e843d`** (MissingGasBudgetPreflight, fixed 84e2324). The preflight mechanism landed, but CUTOVER_GAS_BUDGET was not recalculated after stories 091 and 092. The fingerprint differs because the function and rootCauseClass differ, so this is not a mislabel. It is the drift trap to watch for. **FLAG:** the auditor proposes keeping L-07 fixed and filing L-10. A human may choose to reopen L-07 instead.
- **Q-05 vs FIX-PENDING Q-04 `a62956952abd`.** Both concern the same `//stable-staker-v2-cutover:broadcast` comment but describe different defects. Both stay in, and neither suppresses the other. Q-05 is also not a regression of fixed Q-02 `1c859cde`, which was about the `//StableStakerV2Cutover` key.
- L-09 has the same rootCauseClass as `promotion-ready:broadcast` L-02 `b57dcb4bb594` (open), but a different script and entry point. It is not a duplicate.
- Q-06 is a different mechanism from fixed L-04 `46c05353` and L-05 `fc44ca36` (global-pause brick windows).
- Q-01@initiate: the `migrate:ss-initiate-mainnet` entries (3f4ce2fd, 54a00d2b, 198bb924) are about InitiateYieldStrategyWithdrawal.s.sol, a different script, so they are unrelated.

## 4. Carryover (not re-observed; propose only, no status changes)
| label | fingerprint | status | evidence | proposal |
|---|---|---|---|---|
| L-08 | 6022a9eb99899924db7239991e3f47124815eb4d15dec6ad2636ed32b88dd3ac | fix-pending | Code changed: ERC4626_MAX_LOSS_BPS went from 2 to 5 (story 088, e98ef26). On the fork, the DOLA exit loses 0.47 bps and the USDC exit 0.34 bps, against the 5 bps bound. | **PROPOSE fixed** (human applies via `/ledger`). Residual: the bound is only checked in forge's local pass (the L-09 class). Carry the report forward until the human applies it. |
| Q-04 | a62956952abd4fe22391f1fbff9f5e219961d003367a3c8a1dc4162529b9ea86 | fix-pending | **FIX-PENDING STILL LIVE (possible incomplete fix).** Story 088 edited the Phase 7 NatSpec and the //StableStakerV2Cutover HALT CAVEAT, but the //:broadcast overclaim is unchanged at 7ac6e70. | Keep fix-pending, carry forward, fix together with Q-05. |

dola-ys-withdrawal:status and initiate-dola-ys-withdrawal have no prior ledger entries. Every other stable-staker-v2-cutover entry is fixed or wont-fix, so none are carried forward.

## 5. Law-3 / scope check on Q-07
**Kept.** 7ac6e70 is a merge commit ("deploy") inside the audited delta, and I confirmed 6 conflict-marker lines in `server/deployments/local.json` at HEAD. This is a real repo defect. It is QA and has no security impact. It is not a rehearsal-fidelity claim, so the DeployMocks-is-UI-mock ruling does not apply. It is not an owner-trust matter either.

**FLAG, attribution only:** Q-07 affects the dev toolchain and arguably belongs under entryPoint `dev`, where open L-07 `98e72721` sits ("local.json removed from git tracking"). local.json is tracked again at 7ac6e70, so dev L-07 may no longer apply. I propose running `/recheck` on dev L-07. No status change.

## Totals
Input 7 → removed 0 → passed 7 (all `new`, branch `master`). Flagged for review: 3 (L-10, Q-05, Q-07).
