# phoenix-phase-2-staging-21 — parked items & run notes (`dev` entry point)

Run: `phoenix-phase-2-staging-21` · Entry point: `dev` · Audited commit: `3fb4e34`
Story scope: **story-073** (with story-072 as the related cutover story)
Filed: 0 High / 2 Medium / 9 Low / 4 QA = **15 findings**, all `entryPoint: "dev"`

This file is the run's **visible parked channel** (Law 1: nothing security-relevant is set aside into a log nobody reads). Everything below is deliberately **NOT** filed as a `dev` finding, with the reason stated.

---

## 1. PARKED — MR-DEV-001 (do **not** mint under `entryPoint: dev`)

**`ERC4626YieldStrategy.previewRedeem` / `previewDeposit` view passthroughs still STATICCALL the underlying vault — the story-060 / YS-01 Tokemak fix is one-directional.**

- **Contract:** `lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` `#L73-L85`
- **Proposed root cause class:** `StaticcallOnStateMutatingPreview`
- **Propagation:** PROPAGATES-TO-MAINNET
- **Confidence:** high (source-verified this run against **top-level** `lib/reflax-yield-vault` HEAD, not a nested stale pin)

`:73-75 return vault.previewDeposit(assets);` and `:83-85 return vault.previewRedeem(shares);` are both declared `external view`, so Solidity emits a **STATICCALL**. Against a real Tokemak Autopool these two views revert with `StateChangeDuringStaticCall` for **every** caller, always; against `MockAutoDOLA` (a plain un-overridden OZ ERC4626) they return a clean number, always — so the local rig reports green on the exact behaviour that already bricked this project's YS-swap suite.

Twenty lines below, `:110-115` credits principal via `vault.convertToAssets(sharesReceived)` with an in-source comment naming the hazard verbatim. **The authors knew the hazard and hardened exactly one call site.** Blast radius today is UI/keeper reads (no first-party on-chain caller found), which is why this is parked for triage rather than asserted as a Medium.

### Why it is NOT filed here
It is a **`reflax-yield-vault` contract defect, outside this entry point's slice**. Minting it as a `dev` finding would file a vault bug against a devnet deploy script's entry point.

### Recommended action
**File it against the `reflax-yield-vault` project**, with its own fingerprint, and with this disclosure attached:

> **Disclosure vs `phoenix-phase-2-staging` ledger entry `28d5044e4e` (YS-01 lineage, medium, `acknowledged`, entryPoint `migrate:ys-swap-deploy`).**
> The prior entry is *"Story-060 fix line (vault.previewRedeem) reverts against the real Tokemak Autopool vaults"*, acknowledged on the **`_acquireShares`** deposit path — the path subsequently fixed by the `convertToAssets` swap. That acknowledgement does **not** cover `previewRedeem`/`previewDeposit` at `:73-85`, which are a **different function** (⇒ **different fingerprint**) and were never touched.
> **This must NOT be auto-suppressed under `28d5044e4e`, and `28d5044e4e`'s `acknowledged` status must not be altered.** (It was not altered by this run.)

Corroborating memory: *stable-yield-accumulator run-14 — "the guard is ONE-DIRECTIONAL, residual paths reproduce."* Same shape, independently observed here.

### Secondary gaps recorded in the same mock-fidelity section
1. No `maxRedeem`/`maxWithdraw` check before `vault.redeem` in `_disposeShares` (`:128-135`): against a real Autopool with a liquid reserve below the request, user withdrawals brick. Locally impossible to reproduce.
2. `MockAutoDOLA._updateYield()` mints assets into the vault **before** `super._deposit` mints shares, so `convertToAssets(sharesReceived) > amount` and `creditedPrincipal` at `:115` can **exceed** the deposited amount — the precise opposite of that line's stated intent. **Any local invariant asserting "principal is never over-credited" passes VACUOUSLY.** Flagged because a vacuous harness is a known repeat failure mode in this repo.

---

## 2. Known-issues suppression was **BLOCKED** this run

`registered-projects.json` declares `knownIssuesFile: lib/phoenix-phase-2-staging/known-issues.md` with `knownIssuesCount: 11`, but **that file does not exist on disk** (verified this run). The 11 cached entries are a non-re-derivable snapshot dated `2026-01-09T15:30:00Z` — the same unfalsifiable-known-issues failure mode previously recorded for `phlimbo-ea`.

**Under Law 1, no finding was suppressed on that basis. Suppressions this run: 0.**

Entries that a live list would plausibly have touched, and why each was kept:

| Finding | Cached KI | Disposition |
|---|---|---|
| **Q-02** (`DEV-10`) | KI #2 "Mock contracts with unlimited minting (testing infrastructure only)" | **The one finding a live list would plausibly have suppressed.** Kept live; flagged for **explicit human triage** — do not let an unverifiable list close it silently. |
| M-01 (`DEV-01`) | KI #2 (mis-stretch risk: vacuity evidence involves MockKendu/MockPhUSD) | Kept — and would be wrong even with a live list: the defect is in the **first-party** `NudgeStreamer.sol`, not in a mock. |
| M-02 (`DEV-03`) | KI #10 "Admin trust assumptions" | Kept — Law 3 keeps **non-obvious** owner footguns in scope. |
| L-06 (`DEV-09`) | KI #7 "Circular reference … documented deployment order" | Kept — L-06 is about **missing post-step assertions** on `setNudgeStreamer`, not deployment ordering. |

**Remediation:** re-extract known issues from the submodule at HEAD (`project-manager`) **before** any future run is permitted to suppress on this list, **or** clear `knownIssuesFile`/`knownIssues` from the registry.

---

## 3. Story-state finality (affects L-08 / F-02 and L-09 / F-04)

- **Story 073** moved from `review/` to **`complete/`** mid-run, and **still carries an embedded `Review Status: ISSUES_FOUND`** (2 open HIGH issues at the time of that review). Review Issue 1 (the absent phUSD/Kendu `collectNudge` seed) *was* remediated at `3fb4e34` — `_seedNudgeStream` now exists at `DeployMocks.s.sol:1645-1666` with a real `received == amount` assertion. **FAITH-002 / L-08 is a second, still-open instance of the same class at line 544, not a re-file of Issue 1.**
- **Story 072** is in **`incomplete/`** with **line 514 unticked**.

**Both stories' acceptance criteria are therefore NON-FINAL.** This is recorded as a per-finding **confidence caveat**, explicitly **not** as severity inflation. **Close trigger:** if the two checklists are completed *properly* (line 544's four clauses actually asserted across all seven legs; line 514 ticked against the real Kendu token), **FAITH-002 / L-08 and FAITH-L1-001 / L-09 may be closed.**

---

## 4. Sepolia is **intentionally retired** — do NOT file it as a gap

Owner decision, **2026-07-29**: the deploy ladder is **anvil → mainnet by design**. The absent Sepolia rung is **not** a finding, **not** a coverage gap, and **must not** be filed anywhere, in this run or any future one.

---

## 5. Ledger entries deliberately left untouched by this run

No pre-existing ledger entry's `status`, `triageReason` or `reclassNote` was modified. Specifically preserved:

| Ledger | Entry | State | Note |
|---|---|---|---|
| phoenix-nft-staking | `bfdb50105e` | Q-03, qa, **wont-fix** | Carries a **⚠ TIER-3 RIDER** that must not be edited out. M-01 is a *disclosed re-file*, **not** an override — flagged for human re-weigh only. |
| yield-claim-nft | `c91bef813d` | M-04, **fixed** | Precedent cited by M-02; status untouched. |
| yield-claim-nft | `563df2e64a` | L-09, open | Precedent for keeping a new instance open rather than folding it under a `fixed` sibling. |
| phoenix-phase-2-staging | `8468af472d` | low, **open**, entryPoint `batch-minter-migrate` | Same class as L-02, different entryPoint ⇒ different fingerprint **by design**. Both legitimately open. |
| stable-yield-accumulator | `5292756503` / `0xd62cbfe8` | M-02, **fixed** | Its closure deferred three residual paths **to this audit venue**; L-06 answers that the script post-asserts 1 of 7 legs. **Status NOT modified** — recorded for human re-weigh of the closure basis. |
| reflax-yield-vault / phoenix-phase-2-staging | `28d5044e4e` | medium, **acknowledged** | MR-DEV-001 must not be auto-suppressed under it; status untouched. |
| phoenix-phase-2-staging | `0b497be32114…` | qa, **open**, entryPoint `dev` | **Not re-observed** this run — but this run was story-scoped, so **absence is not evidence of a fix**. Left `open`, `lastSeenRun` NOT bumped, carried forward in full at [`findings/carryover/qa-report-05.md`](carryover/qa-report-05.md). |
| phoenix-phase-2-staging | `c294d93f77…` | low, **fixed**, entryPoint `dev` | Not re-flagged; **no regression** observed. Stays `fixed`. |

**`lastAuditedCommit` was NOT advanced.** It remains `0e190e8`. This run was story-073-scoped, not a full project scan; only the per-entry-point baseline for `dev` was advanced to `3fb4e34`.
