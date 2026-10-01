# Sanitize log: script-audit `balancer-holding` (phoenix-phase-2-staging, run 38)

- Input: `deduped-findings.json` (2 findings)
- Output: `sanitized-findings.json` (2 passed, 0 removed, 0 flagged)
- Submodule: `master` @ `a309040`. All findings stamped `branch: master`, `branchesSeen: ["master"]`.

## 1. Known-issue filtering

Sources checked:
- `registered-projects.json` → `knownIssues` for phoenix-phase-2-staging: 11 cached one-liners. Per prior determination (memory: *phstaging-known-issues-cache-unfalsifiable*), the cache carries **no suppression authority**.
- `src/known-issues.md`: **not present** at `a309040`, and `git log --all -- known-issues.md` shows it never existed in the submodule history. `knownIssuesSource` in the registry is `null`. The project CLAUDE.md says KIs come from that file, so the cache cannot be traced to any human-authored source. This is consistent with the unfalsifiable-cache determination. Warning only; it does not change the outcome.
- In-source NatSpec: no suppression authority (memory: *in-source-natspec-carries-no-suppression-authority*).

| Finding | Closest KI | Decision |
|---|---|---|
| DEDUP-001 | #10 "Admin trust assumptions ... (operational risk)" | **Not matched.** The KI is a generic statement with no authority. The finding is not about trusting the admin: a knowing owner grant leaves every safety gate (`:verify`, the holding-broadcast gate, story-103 step 0) silently green. That is a non-obvious footgun, which is the Law 3 exception, so it stays in scope. |
| DEDUP-002 | none | **Not matched.** No KI covers documentation provenance. |

No out-of-scope removals: both files are first-party `script/` sources, outside `src/lib/**`.

## 2. Ledger reconciliation

Fingerprint = `sha256(contract:function:rootCauseClass:entryPoint)` (printf without a trailing newline).

| Finding | Fingerprint input | Fingerprint | Ledger match | Origin |
|---|---|---|---|---|
| DEDUP-001 | `script/VerifyBalancerHolding.s.sol:run:IncompletePostconditionCoverage:balancer-holding` | `59527bfa84786a87002d80b9bf678c5e798c4d9b2905609ac0f786bd46737632` | none (exact + 10-char prefix) | **new** |
| DEDUP-002 | `script/RevokeBalancerPoolersHoldingPattern.s.sol:(contract NatSpec):MisleadingDocumentation:balancer-holding` | `b469855d97e475c98d72fd0fd71f0766f3f106d9704be2b4c48b780680f65788` | none (exact + 10-char prefix) | **new** |

Supporting checks, all done with jq projections only (the ledger was never read whole):
- `entryPointBaselines` has no `balancer-holding` key (33 keys present). This is the entry point's first audit.
- No ledger entry has `entryPoint == "balancer-holding"`. A contract regex for Balancer, VerifyBalancerHolding or RevokeBalancer returns only L-07 `1b461cb4…` (entryPoint `dev`, TestBalancerDonation). That is an unrelated test-script finding, so no match.
- Title search for authVersion, holding pattern, WhitelistPoolersV2, 0x7f68 or RevokeBalancer returns 0 entries.
- No `fixed`, `abandoned`, `fix-pending`, `acknowledged`, `wont-fix` or `false-positive` match. That gives no regressions, no incomplete-fix signal and no suppressions.
- Still-open carryover for this entry point: none, because the entry point is new.

The ledger was **not** written.

## 3. Law-1 accounting

- Removed: 0. Flagged for review: 0. Nothing was set aside, and both findings go on to classification.
- Cross-references recorded by dedup (yield-claim-nft L-06 `342075df…` open, L-03 `e29ae08e…` fixed, pps `d32e99aa…` on dispatcher-replace-sky-pooler) are context only. None is a ledger match under this entry point's fingerprint domain.
