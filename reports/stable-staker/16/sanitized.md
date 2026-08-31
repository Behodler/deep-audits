# Sanitization + ledger reconciliation — stable-staker run-16

- **Project:** stable-staker · **Commit:** `fa06de5` · **Range:** `2146428..fa06de5` (stories 022 / 023 / 024) · **Branch:** `master`
- **Agent:** sanitizer · **Date:** 2026-08-31
- **Inputs:** `reports/stable-staker/16/findings-deduped.md` (DEDUP-001..010, SPEC-F-01..04, MR-16-01..03, §4 reconcile-only), `reports/stable-staker/ledger.json` (53 entries), `lib/stable-staker/CLAUDE.md` @ `fa06de5`
- **LEDGER WAS NOT MODIFIED.** Zero writes. Every ledger action below is a *proposal* for a human at `/ledger`. Verify against a start-of-run snapshot before applying (memory: `verify-subagent-ledger-writes`).
- **Headline:** 14 findings adjudicated. **11 KEEP · 1 SUPPRESS (routed to a visible channel, not deleted) · 2 RE-WEIGH · 2 reconcile as still-open (not re-filed).** **Zero findings were removed from the run.** No suppression was applied on the strength of a cached known issue.

---

## 0. Executive summary of the three gating results

1. **The cached known-issues array is STALE and partially UNFALSIFIABLE.** The declared source `lib/stable-staker/CLAUDE.md` **does exist at HEAD** (unlike `phlimbo-ea` / `phStaging`), so re-extraction was possible — but it was rewritten in this very range (`+68 / −16` lines). Of the 9 cached items: **5 survive reworded, 1 survives verbatim-equivalent, 2 are SUPERSEDED, 1 has NO TEXT IN THE LIVE SOURCE AT ALL.** Ten *new* design decisions are extractable that the cache does not carry. **Two cached items were relied on for suppression: none. One live item (N7) is the only known issue that suppressed anything this run, and it suppressed half of one manual-review item.**
2. **The redemption premise is void for V2 — but no cached KI ever stated it.** The honest finding (which the deduplicator reached independently) is that the "reward token is mint-on-demand with no redemption, so over-crediting is not a loss" premise lived at the **scanner/memory level**, not in the KI array or in any `triageReason`. That is *worse* than a stale KI, because there is no artifact to reopen. The two cached items that come closest are named in §1.3 and are explicitly denied authority over the V2 reward leg.
3. **Fingerprint drift is real and quantified.** 25 of 53 entries do not reproduce from the stored `contract:function:rootCauseClass`. 12 of those reproduce only on the **legacy `src/StableStaker.sol` path** (run-15 story-019 rename, already annotated). **Exactly one entry — `d47619d29f0dcfc9` — is a confirmed casualty of story-023's `phUSDPerDay → antimatterPerDay` rename**, and a cold run *will* re-file it as new under a different hash. The remaining 13 never reproduced (composite/prose `contract`/`function` fields predating the convention). Full mechanical table in §2.

---

## 1. Known-issues re-extraction at `fa06de5` (gates all suppression)

**Source:** `lib/stable-staker/CLAUDE.md`, read at `git show fa06de5:CLAUDE.md`. Registry cache: `knownIssuesCount: 9`, `knownIssuesExtractedAt: 2026-06-01`.
**Verdict on the cache: DO NOT USE AS-IS.** It is 3 months old and describes a pre-story-022/023/024 contract.

### 1.1 Diff of the cached 9 against the live source

| # | Cached text (abbrev.) | Live status at `fa06de5` | Suppression authority |
|---|---|---|---|
| **KI#1** | "Core emission-cap invariant: no sequence of user actions can **mint** more than **phUSDPerDay**…; `_updatePool` only writer of **accPhusdPerShare** … `elapsed * phusdPerSecond`" | **PRESENT, REWORDED — and the verb changed.** Live: "no sequence of user actions can **accrue** more than `antimatterPerDay`…", `accAntimatterPerShare`, `elapsed * antimatterPerSecond`, **plus a new clause** "Since story 022 … The statement carrying the invariant is `sum(unclaimedReward) + minted <= cap`." | **RETAINED for the arithmetic bound only.** Does **not** suppress DEDUP-001 (which concedes the cap holds and attacks its *cost basis*). See §1.3. |
| **KI#2** | "Integer-division dust rounds DOWN (protocol's favour); empty-pool windows accrue nothing; flash staking earns nothing — by design" | **PRESENT, substantively verbatim** ("Empty-pool windows accrue nothing; flash staking earns nothing; …dust (which always rounds DOWN)"). | **RETAINED.** Authoritative for §6.1 items 3 and 4 (rounding + flash-stake refutations), which is why those were already cleared. **Does not reach DEDUP-001** — a 1-wei pool is not an empty pool. |
| **KI#3** | "**phUSDPerDay** settles the pool at the OLD rate before changing it — by design" | **PRESENT, reworded** ("`antimatterPerDay` settles the pool at the old rate before changing it"). | **RETAINED.** Authoritative for §6.2 item 12. |
| **KI#4** | "Yield stays protocol-owned: stakers only ever get principal back plus **phUSD** emissions; … the farm never reads `totalBalanceOf` to credit a user" | **PRESENT, reworded** ("Stakers only ever get their *principal* back plus **Antimatter** emissions"). | **RETAINED for the custody claim.** **DENIED as a harmlessness argument** for the reward leg — see §1.3. |
| **KI#5** | "Exits forward the ACTUAL received amount while internal accounting decrements the REQUESTED amount; differences remain protocol-owned" | **PRESENT, verbatim.** | **RETAINED.** Authoritative for §4 reconcile-only (`69c7666e` / `0dca43f3`). |
| **KI#6** | "Underwater withdraw block … `emergencyWithdraw` and **`migrateOut`** are intentionally NOT blocked" | **PRESENT but REWORDED — and the cached wording names a function that no longer exists.** Live: "`emergencyWithdraw` and **`initiateMigration`** are **not** blocked by the underwater guard". `migrateOut` was removed in run-07 (`7e9ef80`). | **RETAINED on the live wording only.** A future reconciliation must not match on the cached `migrateOut` string. |
| **KI#7** | "Replacing an in-use yield strategy does NOT auto-migrate funds; **operator must drain it first** or replace only while `totalStaked == 0` (**documented operational requirement**)" | **SUPERSEDED.** Live text: "**`setYieldStrategy` reverts (`\"StableStaker: pool not empty\"`) unless `totalStaked == 0`** — strategy (un)wiring is an empty-pool-only operation." The advisory runbook obligation is now an **enforced revert**. | **NO AUTHORITY as worded.** The cached "operator must drain it first" describes a shipped behaviour that no longer exists. Consistent with memory `stable-staker-run14-notes` ("KI#7/KI#8 lost authority"). **Nothing was suppressed with it.** |
| **KI#8** | "Owner trust assumptions: owner controls `addToken`, **`phUSDPerDay`**, `setPauser`, `setMigrator`, `setYieldStrategy` — **centralization by design**" | **PRESENT, reworded** (rename to `antimatterPerDay`; the wiring/ownership prose is live). | **NO SUPPRESSION AUTHORITY over footguns.** A blanket "centralization by design" line cannot dispose of a *non-obvious* owner footgun under Law 3 — the repo CLAUDE.md scopes owner trust to **knowing** actions. Consistent with memory `stable-staker-run15-notes` ("KI owner-trust item has no authority"). This is load-bearing for DEDUP-001, DEDUP-002, DEDUP-005, DEDUP-006, DEDUP-007. |
| **KI#9** | "Behodler3 pausing via pauser/IPausable; **permissionless `emergencyWithdraw` escape hatch is callable even while paused, by design**" | **THE PAUSE CLAUSE IS ABSENT FROM THE LIVE SOURCE.** `grep -n "paused\|Paused" CLAUDE.md` at `fa06de5` returns **exactly one line** — line 32, "`claim` is still `whenNotPaused`, so a pause now withholds the accumulated backlog too." The "`emergencyWithdraw` callable while paused" sentence does not appear anywhere in the file. The pausing *mechanism* is still described ("Behodler3 pausing (`pauser` + `IPausable`)"). | **THE PAUSE-EXEMPTION HALF HAS NO SUPPRESSION AUTHORITY.** Its text no longer appears in the declared source. This is the item that would have been reached for against **MR-16-02**; it is refused. (The behaviour may still be true in the contract — that is a question for the scanner, not a licence to suppress.) |

### 1.2 New design decisions extractable at `fa06de5` that the cache does not carry

These are the *real* live known-issue surface. Recommended for the registry (`knownIssuesExtractedAt: 2026-08-31`, `knownIssuesCount: 17`). **N2 and N7 are the only ones with any bearing on this run's findings.**

| ID | Live text | Used to suppress? |
|---|---|---|
| **N1** | Emissions token by version: V2 emits Antimatter; frozen `StableStakerV1` emits phUSD "and always will — the live mainnet V1 instance is deployed and unpatchable, so that is correct and permanent, not an oversight." | No — no run-16 finding contests it. |
| **N2** | "there is **no phUSD-style `mintVersion` mass revocation**, so per-minter `setApprovedMinter(x, false)` is the only way to revoke." | **NO.** This states a *fact*; it does not dispose of the consequence. It matches none of the KNOWN ISSUE PATTERNS ("we are aware", "acknowledged", "won't fix", "design decision"). It is a **precondition of DEDUP-006 and DEDUP-002, not an answer to them.** Refused as a suppressor. |
| **N3** | "`emergencyWithdraw` forfeits the `unclaimedReward` backlog as well as the live pending — … never mints." | **Partial.** Covers the *forfeit*; silent on where the forfeited amount **goes**. See DEDUP-003. |
| **N4** | "`claim` is still `whenNotPaused`, so a pause now withholds the accumulated backlog too." | **Partial.** Covers `claim`; silent on `_exitPosition`. See MR-16-02. |
| **N5** | "`pendingReward` is unchanged and is the **live projection only**, excluding the backlog — its meaning must stay identical to the frozen V1 selector of the same name." | **Partial.** Covers the *design intent*; the word "unchanged" is itself contested by DEDUP-004. See DEDUP-004. |
| **N6** | Frozen V1's known defects `ss14m1` / `ss14l8` are preserved deliberately; "An audit that re-files those two findings against `src/versions/` should be triaged as **'deliberately preserved', not actioned**." | Not triggered — **no run-16 finding targets `src/versions/v1/StableStakerV1.sol`.** Standing authority, unused this run. |
| **N7** | "`CrossVersionMigrator` **deliberately does NOT** carry that [top-up] logic — a cross-version migration through an underwater strategy credits the uniform snapshot haircut. That asymmetry is a real product difference and **wants a human decision** before a cross-version migration is run on a live, underwater user base." | **YES — the only suppression exercised this run.** Suppresses the *asymmetry* half of MR-16-01. See §5. |
| **N8** | Sibling-repo compile fallout from the story-018 `StableStakerMigrator` deletion is "**deliberately left unrepaired** and tracked as a cross-repo follow-up." | Not triggered by any run-16 finding; relevant to a future `/audit-script`. |
| **N9** | PreToolUse hook "**Known gap**: a hook only fires when `stable-staker` is the session's project root, and this repo is normally driven as a submodule." | **NO** — this is a *different* gap from SPEC-F-04's (which is that the hook's `PROTECTED` array does not cover `src/versions/` at all). Do not conflate. |
| **N10** | `GOLDEN-RULE-OVERRIDE` commit-message escape hatch, "recorded permanently in git history". | Not triggered. (§3's observation that story-023's commit body spells the literal sentinel is a *hygiene* note, preserved.) |

### 1.3 KIs whose reasoning rests on the premise story-023 DESTROYED — named explicitly, as required

Story-023 replaced the V2 emissions token with **Antimatter** (`lib/antimatter` @ top-level HEAD `3a96fb7`): a plain OZ `ERC20`, no cap, freely transferable, and **redeemable via a permissionless `annihilate`** whose antimatter leg mints **1:1 unbacked phUSD** at `src/Antimatter.sol:294` (`_phUSD.mint(recipient, amount)` — **VERIFIED AT THE NESTED PIN `a5570ce`, which is the commit stable-staker actually compiles against (run-16 re-confirmed: `annihilate` :253-298, `_burn` :270, backed leg `minter.mint` :282, unbacked leg `_phUSD.mint` :294). Note the direction: `a5570ce` HAS the `Pausable` mixin and top-level `3a96fb7` has DROPPED it. Do not cite `3a96fb7` line numbers**). Antimatter is `Ownable`, **not** `Ownable2Step`, with `renounceOwnership` inherited and un-overridden.

**Honest result: NO cached KI states the void premise verbatim.** No suppression is being reversed, because none was ever anchored there. What must nevertheless be denied authority:

| Item | Premise-void ruling |
|---|---|
| **KI#4** ("stakers only ever get principal back plus emissions; yield stays protocol-owned") | **VOID as a harmlessness argument for the V2 reward leg.** Its custody half stands. It must not be read as "emissions are costless" — under Antimatter each emitted unit is a bearer claim on ~1e18 unbacked phUSD, so an over-emission is **net new dilution, not misallocation**. Still valid for the frozen V1. |
| **KI#1** (cap invariant) | **NOT void, but NOT a suppressor.** It bounds *quantity*; it says nothing about *cost basis*. The live rewrite restates it token-agnostically without ever saying it is now a **dilution budget denominated in phUSD backing** — which is itself SPEC-F-02's evidence. |
| **KI#2** ("empty-pool windows accrue nothing") | **Not void, and not on point.** True and unchanged. DEDUP-001 concerns a pool holding **1 wei**, which is the opposite case. Reaching for KI#2 against DEDUP-001 would be a misread. |
| Memory `minter-cushion-socialized-losses-intended` | **VOID for the V2 reward leg** (AM holders redeem permissionlessly). Still valid for the phUSD minter role and for V1. |
| Memory `externally-derived-yield-opportunity-cost-not-loss` | **VOID for the V2 reward leg.** AM emissions are freshly-minted claims on phUSD backing, not Tokemak-style yield on protocol-owned capital. Still valid for the Phoenix pots it was written about. |
| Memory `phstaging-ys12-minter-immune` | **Unaffected as written**, but flagged so the reasoning is not transplanted to AM by analogy. |
| **Class rule** | Any future `REWARD-ACCRUAL-ORDER` / `MINT-ON-DEMAND-OVERMINT` / `ROUNDING-DIRECTION` hit **on the V2 reward leg** must be severity-derived fresh, never auto-downgraded to opportunity cost. |

### 1.4 Documentation carries no suppression authority — and one live doc claim is now DISPROVED

`CLAUDE.md:12-13` at `fa06de5` asserts, unconditionally and with **no migration carve-out**:

> "That is deliberate robustness: a revoked minter role, or any Antimatter revert, **can no longer brick a principal path**."

The run-16 PoC (`test/poc/Run16_M01_MigrationExitMintTrap.t.sol`, **PASSING**) reproduces the exact revert `Antimatter.NotApprovedMinter`, selector `0x6830132b`, with **100% of the pool's `totalStaked` trapped**. Per the standing rule (memory `in-source-natspec-carries-no-suppression-authority`): a doc that self-certifies exhaustively and is **wrong** **RAISES** severity; it never suppresses. Same for `docs/deferred-reward-accrual-plan.md:37-38` and the in-source NatSpec at `StableStakerV2.sol:387-390` and `:828-831`. This is load-bearing for **DEDUP-002** and is the whole of **SPEC-F-01**.

---

## 2. Fingerprint drift — mechanically derived, not eyeballed

Method: for each of the 53 entries, recompute `sha256(contract:function:rootCauseClass[:entryPoint])` over the stored fields **and** over legacy variants (`StableStakerV2.sol → StableStaker.sol`; `antimatterPerDay ↔ phUSDPerDay`), and compare to the stored fingerprint.

| Bucket | Count | Meaning |
|---|---|---|
| Reproduces from stored fields as-is | **28 / 53** | Healthy. |
| Reproduces **only** on the legacy `src/StableStaker.sol` path | **12** | Run-15 story-019 rename. Already annotated on-entry (`pathDrift`); identity is the fingerprint, not the path. No action. |
| **Reproduces only on the legacy `phUSDPerDay` function name** | **1** | **Story-023 casualty. See below.** |
| Never reproduced (composite / prose `contract` or `function` fields predating the convention; or a literal-string fingerprint) | **12** | Pre-existing; not caused by this range. Includes `ss9l1-…` and `ss9f3-…`, whose "fingerprints" are label strings, not hashes. |

### 2.1 The single confirmed story-023 rename casualty

| Entry | `d47619d29f0dcfc9` — *"phUSDPerDay sub-86400-wei/day budget floors phusdPerSecond to 0 (silent zero emission)"*, Low, **open**, firstSeen run-07, lastSeen run-15 |
|---|---|
| Reproduces only from | `src/StableStaker.sol:phUSDPerDay:silent-zero-emission` |
| Live preimage at `fa06de5` | `src/StableStakerV2.sol:antimatterPerDay:silent-zero-emission` |
| **Hash a fresh scan would mint** | **`6aa67015fc658da37be1ea256b3134d872df17450c0f4ce7b4d5fcfb94ca4d6f`** |
| Consequence | A `--full` cold run **will re-file this open Low as a new finding** under `6aa67015…` and the original will silently age out. **Never read the non-reproduction as resolution.** |
| Also stale | Title and `description` still say phUSD/`phusdPerSecond`. The arithmetic is unchanged after the rename; AM is 18-dec, so an 86400-wei/day budget stays economically absurd and the finding stays **Low**. |

**Constructor-arg rename (`IFlax` → `IAntimatter`): zero ledger casualties.** No entry is keyed on `constructor`. Its only victim is the **run-15 PoC** — see §4.4.

### 2.2 Fingerprints this run would mint (computed, for the human's use)

| Finding | Proposed preimage | Fingerprint (16) |
|---|---|---|
| DEDUP-001 | `src/StableStakerV2.sol:_updatePool:empty-pool-emission-cliff-dilution` | `3102c29c8407a0e1` |
| DEDUP-002 | *(do NOT mint — re-weigh `e4567dc343655af9` instead; see §4.1)* | ~~`fe5e8b27732ac75e`~~ |
| DEDUP-003 | `src/StableStakerV2.sol:emergencyWithdraw:stale-index-emission-recycle` | `0651258fcc7f607d` |
| DEDUP-004 | `src/StableStakerV2.sol:pendingReward:view-excludes-settled-backlog` | `708283cc026fdeb4` |
| DEDUP-005 | `src/StableStakerV2.sol:depositFor:missing-zero-address-recipient-guard` | `f35d1dc03602cac8` |
| DEDUP-006 | `src/StableStakerV2.sol:claim:retired-staker-perpetual-minter-surface` | `f9a08a4021e57cdf` |
| DEDUP-007 | `src/InPlaceMigrator.sol:migrateIn:sliced-reinjection-emission-overshare` | `d7a3b9d4421f2b9e` |
| DEDUP-008 | *(do NOT mint — reconciles to `f0cb5f7cddd…`; see §3)* | ~~`e9a30240d72c4cca`~~ |
| DEDUP-009 | `remappings.txt:vendored-flax-duplicate-artifact:unpinned-vendor-drift` | `17404e3df9dab691` |
| DEDUP-010 | *(do NOT mint — routed to QA under `b197e829fb8468fe`; see §3)* | ~~`a8a164d41b4eebd6`~~ |

---

## 3. Per-finding disposition

Every finding gets **KEEP / SUPPRESS / RE-WEIGH**, its reconciliation `origin`, and the **authority** relied on. Nothing is dropped; every set-aside item names its visible channel.

| # | Finding (abbrev.) | Sev (carried) | Verdict | Origin | Authority / reason |
|---|---|---|---|---|---|
| **DEDUP-001** | Empty-pool emission cliff: 1 wei converts a dormant pool into a full-rate permissionlessly-capturable AM dilution stream | HIGH | **KEEP** | **NEW** `3102c29c…` | **Suppression refused.** KI#1 bounds quantity, not cost basis, and DEDUP-001 concedes the cap holds. KI#2 ("empty-pool windows accrue nothing") is true and **not on point** — the attack stakes 1 wei, so the pool is not empty. KI#8 (owner trust) cannot dispose of a non-obvious footgun (Law 3). Premise (`Antimatter.sol:294`) verified at the nested pin `a5570ce` that the project compiles against. Not C4-invalid: not a malicious-owner vector; the surprise test is applied explicitly. **Triggers the §4.2 re-weigh of `ss9l1` + `86fcf00e`.** |
| **DEDUP-002** | `_exitPosition` inline mint is the sole `Migrating` principal exit; mint failure traps 100% of principal (**PoC PASSING**) | MEDIUM | **RE-WEIGH** — reopen `e4567dc343655af9`, do **not** mint a new fingerprint | **still-open (re-weighed)** | Full disclosure adjudication in **§4.1**. |
| **DEDUP-003** | `emergencyWithdraw` shrinks `totalStaked` without `_updatePool`, recycling forfeited emissions to survivors | LOW | **KEEP** (hold at Low) | **NEW** `0651258f…` | **Partial KI match — FLAGGED, not suppressed.** Live **N3** documents that the hatch *forfeits* the backlog and never mints; it is silent on where the forfeited amount **goes** (recycled to survivors through a stale index). The finding does not dispute the forfeit. **Severity guard-rail:** the story-023 premise change must **not** pull this upward — the defect emits nothing extra, and the deduplicator's re-derived cap proof is independent. The phoenix sibling `911c54fd` (wont-fix) has **no cross-project suppression authority** and a different mechanism (per-position rate, no shared denominator). |
| **DEDUP-004** | `pendingReward` reads **zero** for a fully-owed user after any `stake`/`withdraw`/`depositFor` | LOW | **KEEP** (as QA/Low) — **flagged partial match** | **NEW** `708283cc…` | **Partial KI match — human review requested.** Live **N5** is a genuine design decision ("`pendingReward` is … the **live projection only**, excluding the backlog") and disposes of the *semantic-change* half. It does **not** dispose of two residuals: (a) the KI's own word "**unchanged**" is misleading — the formula is unchanged, the *meaning for a settled user* is not, since V1 had no `unclaimedReward`; (b) integrators that **branch** on the value break. Recommend the residual be filed as a **doc correction + the MR-16-03 cross-repo watch**, not a behaviour change. **Set aside nothing.** |
| **DEDUP-005** | `depositFor` has no zero-address recipient guard; consequence is an unfixable `Migrating` brick | LOW (hardening) | **KEEP** | **NEW** `f35d1dc0…` | No KI on point. **Adjacency disclosure (required):** two `depositFor` entries exist — `eae10d6031d96318` (*missing `require(credited > 0)`*, **fixed**) and `8d5ceff20ca74fbd` (*zero-**credit** phantom staker bricks `finalizeAndReset`*, **fixed**). Both are **different root-cause classes** (zero *credit*, not zero *address*), so this is **NOT a regression of either** — do not let "depositFor guard, fixed" be read as covering it. Reachability honestly stated as blocked today (both shipped migrators skip zero-credit users); filed as hardening because `migrator` is an owner-settable pointer, so the protection lives outside the contract that suffers. |
| **DEDUP-006** | Retired stakers must remain approved AM minters (and unpaused) forever, against a token with no mass revocation | LOW (Medium argument carried) | **KEEP** | **NEW** `f9a08a40…` | **Suppression refused on N2.** Live **N2** ("no phUSD-style `mintVersion` mass revocation…") states the **precondition** of this finding, not a disposal of it: it matches none of the KNOWN ISSUE PATTERNS and contains no "we are aware / accepted / by design" clause about the *consequence*. **N4** covers `claim`'s pause behaviour only. Verified present in live source; verified as non-disposing. The Medium argument (mass revocation is `n` transactions, non-atomic) travels to severity-classifier untouched. |
| **DEDUP-007** | Sliced migration re-injection hands the first slice the whole emission budget of the inter-slice interval | LOW | **KEEP** | **NEW** `d7a3b9d4…` | No KI on point. Not C4-invalid: page order is owner-chosen but the ~83% over-share is a **non-obvious** consequence of an ordinary paginated re-injection ⇒ footgun, not "reckless admin". Not user-exploitable, so it is not a malicious-owner vector either. |
| **DEDUP-008** | `_reinjectWithTopup` per-user reverts inside the `migrateIn` batch loop; shared top-up surplus consumed in slice order | LOW | **RECONCILE — do not re-file** | **still-open** → `f0cb5f7cdddeea0a` | **This is not new.** `f0cb5f7cdddeea0a` (*"InPlaceMigrator.migrateIn surplus-underfunding batch revert + no cross-slice…"*, Low, **open**) is the same defect; `bda951d9f1ce1fef` (*"Poison/zero-credit user reverts the whole `migrateIn` slice"*, Low, **open**) is the adjacent liveness half. Corroborated by the run's own coverage assertion: **both migrators had a NatSpec-only diff with zero executable change in `2146428..fa06de5`** (confirmed independently three times). Minting `e9a30240…` would **mis-attribute a run-13 defect to this range**. Bump `lastSeenRun`, **carry the original report forward in full**. The deduplicator's DEDUP-007-vs-DEDUP-008 separation argument is **upheld** — they remain distinct; only DEDUP-008's *novelty* is denied. |
| **DEDUP-009** | Two same-named `FlaxToken` build artifacts, no CI pin on the vendored copy | QA | **KEEP** | **NEW** `17404e3d…` | Genuinely new in this range (story-024). CLAUDE.md's dependency section documents the vendoring and says "Keeping the remapping NAME is what spares every import site" — it is **silent on the hash pin**, so there is no design-decision KI to suppress with. Not tool noise: the *drift* risk is a build-integrity hazard on the compile-time definition of the frozen V1's imports. |
| **DEDUP-010** | `setYieldStrategy` / `finalizeAndReset` lack `nonReentrant` | QA / hardening | **SUPPRESS at H/M — ROUTED to QA, not deleted** | **still-open** → fold under `b197e829fb8468fe` | **C4 known-invalid: "common findings from automated tools without a demonstrated H/M exploit path."** The deduplicator itself establishes non-exploitability: the `staked > 0` branch is **unreachable** behind the `totalStaked == 0` gate (which live **KI#7-as-superseded** now *enforces*), `finalizeAndReset` makes no external call, and OZ's guard is contract-wide. Owner-wired strategy ⇒ Law 3 *obvious*, so no footgun carve-out applies. **Visible channel:** append as a note to existing QA entry `b197e829fb8468fe` (*"Stale NatSpec + structurally-dead in-place drain branch"*, submitted-qa) — same function, same dead-branch subject. **Do not mint `a8a164d4…`.** Flagged for human: if the empty-pool gate is ever relaxed, this becomes live and must be re-raised. |
| **SPEC-F-01** | story-022's "principal paths never call phUSD at all" criterion is not met on the migration exit; docs assert it unconditionally | potential-medium | **KEEP** → `spec-conformance.md` | **NEW** (Law-2 channel) | **Not subject to KI suppression by construction:** the claim *is* that the doc is wrong, so citing the doc would be circular (§1.4). Cross-ref DEDUP-002 / `e4567dc34365`; **kept separate** per the run ruling — a Law-2 deviation has a distinct remedy (correct the story/docs). |
| **SPEC-F-02** | story-023 is silent on the redemption consequence and laundered story-022's token-specific risk conclusion into a token-agnostic one | potential-medium | **KEEP** → `spec-conformance.md` | **NEW** (Law-2 channel) | **Corroborated by this sanitization.** §1.1's KI#1 row is independent evidence: the live cap statement was rewritten token-agnostically *without* stating it is now a dilution budget denominated in phUSD backing. Adjacent ledger doc entries `ss9f3-claudemd-…` (doc-lag, open) and `c8218865da2c8fea` / Q-03 (CLAUDE.md overstates golden-rule enforcement, qa, open) are **different sections and different claims — do not collapse.** |
| **SPEC-F-03** | story-022 Decision 3's "nothing is stranded" has an unstated third precondition story-023 removed | potential-low | **KEEP** → `spec-conformance.md` | **NEW** (Law-2 channel) | Same N2 ruling as DEDUP-006: the live source states the revocation model as fact and never revisits Decision 3. Non-obvious consequence of ordinary decommissioning hygiene ⇒ in scope. |
| **SPEC-F-04** | The vendored pair has **zero** gate; story-024 declined to pin it on a factually-wrong CI premise; the stated second line of defence does not exist | potential-low | **KEEP** → `spec-conformance.md` | **NEW** (Law-2 channel) | **Not suppressed by N9.** N9's "Known gap" is *session-project-root scoping*; SPEC-F-04's gap is that the hook's `PROTECTED` array covers only the migration triad and never `src/versions/`. Different gaps — do not conflate. **Adjacency disclosure:** `9abbb7b1463dbef7` (CI gate + hook fail to prevent **deletion**, Low, open) and `7c99f3744421c61f` / Q-02 (frozen-V1 CI gate under-enforces, QA, open) concern the **frozen pair**; SPEC-F-04 concerns the **vendored pair**, a different asset with a different (zero) gate. Do not collapse. |

### 3.1 Manual-review items (visible channel, carried unchanged unless noted)

| # | Item | Verdict |
|---|---|---|
| **MR-16-01** | `CrossVersionMigrator.migrate` calls `depositFor` with no snapshot and no gross-up (vs `InPlaceMigrator._reinjectWithTopup`) | **PARTIALLY SUPPRESSED — the only KI suppression exercised this run.** The **asymmetry itself** is disposed of by live **N7**, quoted verbatim and confirmed present at `fa06de5`: *"`CrossVersionMigrator` **deliberately does NOT** carry that logic … That asymmetry is a real product difference and **wants a human decision** before a cross-version migration is run on a live, underwater user base."* That is an explicit design decision. **NOT suppressed:** the residual question of whether `depositFor` can credit **less than it pulls at all** — N7 presumes the haircut is the *understood snapshot* haircut and asserts nothing about credit exactness. **KEEP in manual review** with that carve, at preliminary Medium if confirmed. Memory `mock-no-op-stub-fakes-permanence` applies: do **not** close by assuming the haircut cannot happen; needs a fork/harness against a real haircutting destination strategy. |
| **MR-16-02** | Pause does not freeze reward minting on the migration path | **KEEP** in manual review at QA/informational. **Suppression refused:** the cached **KI#9** pause-exemption clause **has no text in the live source** (§1.1), and live **N4** covers `claim` only, never `_exitPosition`. No over-mint occurs (`_updatePool` no-ops while `Migrating`), so it is a completeness gap in the pause, not a value bug — but it is materially different now that the reward unit is redeemable. |
| **MR-16-03** | Cross-repo watch: phStaging `ClaimWithdrawStableStaker.s.sol` breaks against a V2 staker | **KEEP** as a cross-repo route. Not a stable-staker defect and must not be filed as one. Route to the next `/audit-script` on `phoenix-phase-2-staging`; pairs with the run's other cross-repo observation (story-023's ABI break `phUSD()` → `antimatter()`). Recommend a `crossRepoRoutes` entry alongside the existing `SS15M1-PHSTAGING`. |

### 3.2 §4 reconcile-only items — confirmed, no re-file

| Item | Ledger entry | Reconciliation |
|---|---|---|
| `amountPerDay / 86400` floors to zero | `d47619d29f0dcfc9` (Low, **open**) | **still-open.** **DRIFT ALERT — see §2.1.** Title/description stale (say phUSD). Arithmetic unchanged post-rename; stays Low. |
| Requested-vs-received withdrawal skew | `69c7666eee33698e` (**wont-fix**) + `0dca43f3156be442` (**acknowledged**) | Suppressed as prior human dispositions **and** covered by live **KI#5** (verified present verbatim). No executable change in range. Not carried forward (human already triaged). |
| Unbounded per-user external-call loop | `59eebbf87b3d0a71` (Low, **open**) | **still-open.** Carry forward. |
| Dust-stake grief of the empty-pool gate | `787e9faceb60e76e` / L-01 (**submitted-qa**) | **still-open.** Severity basis unchanged by story-023 (availability nuisance, no dilution leg). |
| `InPlaceMigrator:227` `forceApprove(balanceOf)` vs NatSpec | `f84992e9ac16ce59` / ss13l4 (QA, **open**) | **still-open.** NatSpec-only diff in range. |

---

## 4. The four specific adjudications requested

### 4.1 DEDUP-002 vs `e4567dc343655af9` — **RE-WEIGH + DISCLOSE** (recommended)

**Prior entry, named as policy requires:** `e4567dc343655af9` — *"Terminal migration has no mint-free escape hatch if phUSD minter rights are revoked mid-migration"*, **Low**, **wont-fix**, first seen run-03, last seen run-07, `reports/stable-staker/03/submissions/qa-report.md`. Reproduces only from the legacy preimage `src/StableStaker.sol:userMigrate:availability-dependency-on-mint`.

**Its `triageReason`, quoted verbatim and in full:**

> "Intended design (user triage 2026-06-08, via /review-finding ss7m3). emergencyWithdraw/withdraw/deposit are deliberately frozen once migrationInfo[token].active because initiateMigration captures an immutable (R,P) snapshot and every exit pays a fixed pro-rata credit p_i*min(R,P)/P; a live exit during migration would mutate P and corrupt the snapshot (StableStaker.sol:306-307, 335-340). The Law-2 'faithfulness gap' framing is therefore invalid. The residual 'revoke staker's phUSD minter while migration active -> exits revert' sliver is an obvious admin misstep (Law 3 out-of-scope) and recoverable. Not submittable."

**Conceded without reservation (the un-disputed half).** The first clause stands entirely: the `Migrating` freeze of `withdraw`/`emergencyWithdraw`/`depositFor` **is** intended design and **is** required to protect the `(R,P)` snapshot. Nothing here asks for that to change, and no recommended mitigation touches it. The prior `reclassNote` is **not overridden**. **SPEC-F-01 is not a re-litigation of the rejected Law-2 framing** — it is a different claim, against story-022's *own explicit acceptance criterion* ("with the minter role revoked, `stake`, `withdraw` and `emergencyWithdraw` all still succeed"), which did not exist in June 2026.

**Re-file basis — the closure is falsified on its own stated terms, on the Law-3 axis, not the premise axis.** Confirmed: the closure rested on **Law 3**, so it is **NOT an expired closure** on the redemption-premise axis, and it must not be reopened on that ground. It is reopened because the two load-bearing words of its own final sentence no longer hold:

1. **"obvious admin misstep" → falsified.** The realistic trigger is not a blunder mid-migration; it is `Antimatter.setApprovedMinter(staker, false)` as **ordinary decommissioning order** or routine incident response. Its consequence — freezing an *unrelated pool's principal* — is invisible from Antimatter, invisible from `emergencyWithdraw`, and **actively contradicted by the project's own live documentation** (`CLAUDE.md:12-13`, §1.4). A competent non-malicious owner would be surprised. That is the definition of a **non-obvious footgun**, which Law 3 places **in scope** and which the C4 "reckless admin mistakes" filter explicitly does not catch (§6).
2. **"and recoverable" → now conditional, and demonstrably not always true.** `antimatter` is `immutable` (`StableStakerV2.sol:60`), constructor-only, no setter. **Antimatter is plain `Ownable`, not `Ownable2Step`, with `renounceOwnership` inherited and un-overridden** (verified at top-level `lib/antimatter` HEAD `3a96fb7`). An owner who revokes and *then* renounces — each step individually reasonable — makes the trap **permanent and unrecoverable by anyone**. `rescueERC20` is exactly tight during migration (`reserved == totalStaked`), so nothing is rescuable. The 2026-06 triage could not weigh this: phUSD's `FlaxToken` was a different token under different controls.
3. **A passing PoC now exists**, which did not in run-03/07: exact revert `Antimatter.NotApprovedMinter`, selector `0x6830132b`, **100% of `totalStaked` trapped**, with recovery-by-re-approval demonstrated in the same test (which is *why* the base case is Medium, not High).

**The counter-argument, carried in full and not suppressed** (the deduplicator's own honest point): the old token had `FlaxToken.revokeAllMintPrivileges()`; Antimatter has only per-minter revocation, which arguably makes *accidental blanket* revocation **less** likely — i.e. on that one sub-axis the wont-fix rationale got **stronger**. **Weighing:** this narrows the *blanket-accident* path but does nothing to point (2) — permanence — which is the axis the closure's own word "recoverable" rests on, and which is decided by `renounceOwnership` + an `immutable` token pointer, not by revocation granularity. Point (2) is therefore decisive.

**RECOMMENDATION: re-weigh, do not leave as wont-fix, and do not mint a new fingerprint.** Reopen `e4567dc343655af9` at **Medium**, preserving its fingerprint as identity (it is the same structural defect; a new hash under `_exitPosition` would fracture 5 runs of history and is exactly the silent-re-file failure mode of memory `disclose-when-refiling-owner-wontfix`). Annotate the function drift: filed against `userMigrate`, the root cause sits in `_exitPosition:620`, reached by **both** `userMigrate` and `batchMigrate`. Update the stale title (says "phUSD minter rights"; the live token is Antimatter).

**The honest alternative, stated so the human can choose it:** leave `wont-fix` and file only SPEC-F-01 (the doc lie). **Not recommended** — under Law 1 that keeps a PoC-proven, now-permanently-unrecoverable 100%-principal trap suppressed from every future scan on the strength of a rationale whose own operative word ("recoverable") has been falsified.

**Proposed command (human applies):**
```
/ledger stable-staker reopen e4567dc3 --severity medium \
  --reason "Re-weigh on falsified-closure grounds, not premise expiry. Prior wont-fix (2026-06-08, ss7m3) rested on Law 3: 'an obvious admin misstep ... and recoverable'. Both clauses falsified: (a) trigger is ordinary decommissioning order, consequence contradicted by the project's own CLAUDE.md:12-13 => non-obvious footgun, in scope; (b) 'recoverable' is now conditional - antimatter is immutable with no setter and Antimatter is plain Ownable with a live renounceOwnership (lib/antimatter@3a96fb7), so revoke-then-renounce is permanent. Passing PoC: Antimatter.NotApprovedMinter 0x6830132b, 100% of totalStaked trapped. The intended-design half of the prior triageReason (the Migrating freeze protecting the (R,P) snapshot) is CONCEDED and untouched; the prior reclassNote is NOT overridden. Counter-argument recorded: no mass revocation makes blanket accidents LESS likely - narrows the accident path, does not touch permanence."
```

### 4.2 `ss9l1` and `86fcf00ef786f496` — **RE-WEIGH, preserve fingerprints, DO NOT COLLAPSE**

Both are **`open`**, so **nothing is currently suppressed and Law-1 exposure is bounded** — this is a rationale-correction and severity question, not a recall failure. But both carry stated rationales that story-023 **inverted**, and as written they instruct a future reader that emission dilution is harmless. That is the danger.

**`ss9l1-finalizeAndReset-revival-stale-emission-rate`** (Low, open, run-09→13, `reports/stable-staker/09/submissions/qa-report.md`)
- Void text (`impact`): *"QA / Law-3 non-obvious owner-config footgun. **Emission cap not violated, no principal at risk.**"*
- Why void: the second clause was the whole downgrade. Under Antimatter, emissions the pool should never have paid are bearer claims on unbacked phUSD; "no principal at risk" is true of the *staked stablecoin* and false of the *protocol's phUSD backing*.
- **Corrected `impact` text (proposed verbatim):** *"Law-3 non-obvious owner-config footgun. The per-second emission CAP is NOT violated and no **staked principal** is at risk. **Since story-023 (2026-08-31) the emitted unit is Antimatter, redeemable 1:1 for unbacked phUSD via the permissionless `Antimatter.annihilate` (`lib/antimatter/src/Antimatter.sol:294`), so emission on a revived pool that the operator believed dormant is net new dilution of phUSD backing — a real cost, not a redistribution. The prior 'no principal is at risk' framing rested on the pre-story-023 premise that the reward token had no redemption path, and that premise is VOID for V2.** Recommend `finalizeAndReset` zero `antimatterPerSecond` (or require explicit re-config) and clear/re-assert the `yieldStrategy` binding on revival."*
- **Severity: Low → Medium** (final call to severity-classifier). Its recommendation — *"zero the rate on revival"* — **is DEDUP-001's primary mitigation**, which is the strongest evidence the two share a root cause.

**`86fcf00ef786f496` / ss12l3 / L-03** (QA, open, run-12→13, `reports/stable-staker/12/submissions/qa-report.md`)
- Void text (`description`): *"Sole residual: **emission-share dilution (normal MasterChef TVL dilution of in-motion/unmatured yield, not a leak).**"*
- Why void: **exactly inverted.** Under Antimatter, emission dilution **is** the leak, realised at `Antimatter.sol:294`. The entry's refutation of the *theft / inflation / rate-manipulation* angle remains **correct and should be preserved verbatim** — only the final "so the residual is harmless" step fails.
- **Corrected `description` tail (proposed verbatim):** *"…Sole residual: emission-share dilution. **RE-WEIGHED 2026-08-31 (run-16): the 'not a leak' inference is VOID for V2. It rested on the reward token being mint-on-demand with no redemption path; story-023 replaced phUSD with Antimatter, which is redeemable 1:1 for unbacked phUSD via the permissionless `annihilate` (`lib/antimatter/src/Antimatter.sol:294`). Emission captured by an interloper in the revival window is therefore net new dilution of phUSD backing, not MasterChef TVL redistribution among legitimate stakers. The refutations above (theft, share-price inflation, rate manipulation) are UNAFFECTED and remain correct.**"*
- **Severity: QA → Low or Medium** (severity-classifier's call).

**DO NOT COLLAPSE either into DEDUP-001 — the distinct trigger conditions that would be lost:**

| | Trigger that is unique to it |
|---|---|
| **`ss9l1`** | Requires a **`finalizeAndReset` revival** and its remedy is *inside `finalizeAndReset`* (zero the rate / re-assert the strategy binding on revival). It additionally carries a **`yieldStrategy` re-wiring** leg that DEDUP-001 does not have at all. Collapsing loses the strategy-rebinding half entirely. |
| **`86fcf00e`** | The **permissionless-stake race in the revival window specifically before `migrateIn`** — an *operational sequencing* hazard whose remedy is a **pause-wrap of the out→reset→rewire→in session** (and it is already bundled with `ss9l1`/`787e9fac` under a shared "revival-window pause-wrap" QA recommendation). DEDUP-001's remedy is per-pool rate hygiene, which does **not** close a race inside a single migration session. |
| **DEDUP-001** | Covers **four** windows, two of which (**(c) retired pool** and **(d) organic emptying**) require **no migration at all** and are the *default end-state*. Neither ledger entry reaches those. |

**Recommended structure:** keep all three entries, cross-linked (`relatedFindings`), with DEDUP-001 as the class parent. `ss9l1` and `86fcf00e` are the two *migration-specific* instances; DEDUP-001 is the general statement plus the two non-migration windows.

**Proposed commands (human applies):**
```
/ledger stable-staker reweigh ss9l1 --severity medium \
  --reason "Void premise (story-023): 'no principal at risk' rested on phUSD having no redemption path. V2 emits Antimatter, redeemable 1:1 for unbacked phUSD (Antimatter.sol:294). Fingerprint PRESERVED. Related: DEDUP-001 (class parent), 86fcf00e. Retains its unique yieldStrategy-rebinding leg - do not collapse."
/ledger stable-staker reweigh 86fcf00e --severity low \
  --reason "Void premise (story-023): 'emission-share dilution ... not a leak' is INVERTED under Antimatter. Theft/inflation/rate-manipulation refutations UNAFFECTED and preserved. Fingerprint PRESERVED. Retains its unique pre-migrateIn revival-race trigger and pause-wrap remedy - do not collapse into DEDUP-001."
```

### 4.3 The `fix-pending` entry — present unconditionally, **never suppressed**

**`dab5a65613c7af50`** — *"Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers"*, **Medium**, **`fix-pending`**, `src/StableStakerV2.sol` / `setYieldStrategy` / `accounting-desync`, first seen run-06, last seen run-10, `reports/stable-staker/06/submissions/M-01-idle-pool-adoption-discards-credited.md`, PoC `workspace/stable-staker/test/PoC_M01_AdoptionHaircut.t.sol` (**passing**).

- **Re-tripped by a scanner this run? No.** **This changes nothing.** `fix-pending` is reported regardless of whether any scanner re-flagged it. It is **not** a known issue, is **not** `acknowledged`, and is **never** semantically matched to KI#7/KI#8 or to any "we are aware that…" pattern.
- **Did its code change in range?** **No.** `git diff 2146428..fa06de5 -- src/StableStakerV2.sol` contains **no hunk covering `setYieldStrategy`** (hunks jump `@@ -200,14 @@` → `@@ -309,7 @@`, straddling the function). Stories 022/023 touched deferred accrual and the token swap, not strategy adoption.
- **Bucket: `FIX-PENDING (fix not yet landed)`** — expected, low signal. **Explicitly NOT** `⚠ FIX-PENDING STILL LIVE (possible incomplete fix)`, because the code did not change.
- **Carryover: MANDATORY.** Copy `reports/stable-staker/06/submissions/M-01-idle-pool-adoption-discards-credited.md` **forward in full** to `reports/stable-staker/16/submissions/ss6m1-C1.md` (label per finding-manager convention). **Never a pointer stub.** Bump `lastSeenRun` → `stable-staker-16`; keep `branch: master`, append `master` to `branchesSeen`.
- **HTQ-14-02 HOLD is still ARMED.** The proposed closure of this entry and its `fixGroup` siblings `dbdc3ac9b9` (M-06, acknowledged) and `969722dc9e` (M-07, acknowledged) remains **HELD**: the shared fix basis (the story-010 `setYieldStrategy` empty-pool gate) is precisely what creates `d1aa4060`'s brick. **Do not propose `fixed`. Do not close the group.**
- **No status change is proposed for this entry.**

### 4.4 Run-15's par-exit front-run Medium — **PoC bit-rot is INCONCLUSIVE, status UNCHANGED**

**`2b9a89d29c34df41`** / ss15m1 / M-01 — *"Par-exit front-run on the migration cushion"*, **Medium**, **`wont-fix`** (human-set 2026-08-29, `statusSetBy: human`, `humanSet: true`), `reports/stable-staker/15/submissions/M-01.md`.

- Its PoC no longer compiles after story-023's `IFlax` → `IAntimatter` constructor-argument rename and was **quarantined**.
- **Ruling, stated explicitly as requested: a PoC that no longer *compiles* is INCONCLUSIVE BIT-ROT, NOT evidence of a fix.** Per `/recheck` semantics, a failure to build classifies as **INCONCLUSIVE**, never LIKELY-FIXED. No `proposedStatus`, no `recheckResult`, no `lastSeenRun` bump, and **no status change** is proposed.
- **Status stays `wont-fix`, byte-identical.** It is human-set and this agent does not touch human statuses.
- **`REOPEN-ss15m1` stays ARMED.** Its conditions are unaffected by the rename: *"A migration is executed WITHOUT the `pause()` wrapper"* / *"Any script calls `StableStakerV2.initiateMigration` with `withdraw` left open."* Checked by `/audit-script` on phStaging (`crossRepoRoutes` → `SS15M1-PHSTAGING`; memory `stable-staker-m01-pause-obligation`).
- **Carryover: none.** `wont-fix` is a human disposal and is not carried forward. But note it is **not suppressed by this agent's judgement** — it is suppressed by a human decision with a live reopen trigger.
- **Housekeeping, flagged not applied:** the quarantined PoC should be repaired (`IFlax` → `IAntimatter`) so a future `/recheck` is not blocked. Record on-entry as `pocCaveat`, not as a status change.

---

## 5. Suppression register — every removal, with the KI text and its live-source confirmation

**Exactly one KI-based suppression and one C4-known-invalid suppression were applied. Neither deletes anything.**

| # | Item suppressed | Authority | KI text quoted | Present in live source at `fa06de5`? | Where it went (visible channel) |
|---|---|---|---|---|---|
| **S-1** | MR-16-01, the **asymmetry half only** (that `CrossVersionMigrator` lacks `InPlaceMigrator`'s gross-up) | Known issue **N7** (design decision) | *"`CrossVersionMigrator` deliberately does NOT carry that logic — a cross-version migration through an underwater strategy credits the uniform snapshot haircut. That asymmetry is a real product difference and wants a human decision before a cross-version migration is run on a live, underwater user base."* | **YES — confirmed present**, `CLAUDE.md` §"The two migrators". | `manual-review.json` MR-16-01, **carved**: the residual (can `depositFor` credit less than it pulls at all?) is **NOT suppressed** and needs fork verification. |
| **S-2** | DEDUP-010 (missing `nonReentrant`) **at H/M only** | C4 known-invalid: *"Common findings from automated tools without demonstrated HM exploit path"* | n/a (C4 rule, not a project KI) | n/a | `qa-report.md`, folded as a note under existing entry `b197e829fb8468fe`. Re-raise trigger recorded: **if the `totalStaked == 0` empty-pool gate is ever relaxed, the `staked > 0` branch becomes reachable and this must be re-scanned.** |

| Suppressions **refused**, and why (recorded so a future run does not retry them) |
|---|
| **KI#1 → DEDUP-001.** Bounds quantity, not cost basis; the finding concedes the cap. |
| **KI#2 → DEDUP-001.** "Empty-pool windows accrue nothing" is true and off-point (attack stakes 1 wei). |
| **KI#4 → DEDUP-001 / DEDUP-007.** Custody claim only; **void** as a harmlessness argument for the V2 reward leg (§1.3). |
| **KI#7 → DEDUP-010 / `787e9fac`.** Text superseded by an enforced revert; no authority as worded. |
| **KI#8 → DEDUP-001/002/005/006/007.** "Centralization by design" cannot dispose of a **non-obvious** footgun (Law 3). |
| **KI#9 → MR-16-02.** The pause-exemption clause **has no text in the live source**. |
| **N2 → DEDUP-006 / SPEC-F-03.** States the precondition, not a disposal; no acceptance language. |
| **N3 → DEDUP-003.** Covers the forfeit, not the recycling. |
| **N4 → MR-16-02.** Covers `claim`, not `_exitPosition`. |
| **N5 → DEDUP-004.** Covers the design intent; the residual (misleading "unchanged" + integrator break) survives. **Flagged as a partial match for human review.** |
| **N9 → SPEC-F-04.** A different hook gap. |
| **`CLAUDE.md:12-13` → DEDUP-002 / SPEC-F-01.** A doc that asserts the opposite of shipped behaviour **raises** severity; it never suppresses. |
| **Prior wont-fix `e4567dc34365` → DEDUP-002.** Falsified on its own Law-3 terms; re-weighed with full disclosure, not auto-suppressed. See §4.1. |

---

## 6. C4 known-invalid filter

Applied: weird/non-standard ERC-20 (except USDT); fee-on-transfer; approve race / `safeApprove` front-running; user error / phishing; unused view functions; tool noise without an H/M exploit path; **"a malicious owner could…"**.

- **One drop:** DEDUP-010, on the tool-noise rule — **routed to QA, not deleted** (§5, S-2).
- **Pre-cleared upstream and confirmed here** (deduplicator §6.2 items 9-10): `FEE-ON-TRANSFER-ACCOUNTING` correctly no-match (`_pullToken` credits the balance delta; `notVulnerableWhen` satisfied exactly), and `FRONTRUN-APPROVE` no-match (`SafeERC20.forceApprove` used exclusively, never raw `approve`). Nothing to drop.
- **Zero malicious-owner vectors were filed anywhere in this run** — independently re-verified against every owner-facing finding.

**Footgun carve-out — applied and NOT filtered.** The following are **non-obvious owner footguns** under Law 3 and stay in the run at honest severity, with safe-config guidance:

| Finding | The ordinary action | The non-obvious consequence | Surprise test |
|---|---|---|---|
| **DEDUP-002** (explicitly named in the task, explicitly retained) | `Antimatter.setApprovedMinter(staker, false)` during **ordinary decommissioning** or incident response | Freezes **100% of an unrelated pool's principal** during `Migrating`; made **permanent** by Antimatter's live `renounceOwnership` (plain `Ownable`, not `Ownable2Step`) against an `immutable` token pointer with no setter | **Surprised** — and the project's own `CLAUDE.md:12-13` tells the owner the opposite. ⇒ **in scope** |
| **DEDUP-001** | Leaving `antimatterPerDay` set on a drained / retired / pre-launch pool | A pool with zero users carries a live, permissionlessly-triggerable dilution liability | **Surprised.** Safe config: `antimatterPerDay(token, 0)` on every pre-launch, drained and retired pool |
| **DEDUP-005** | Wiring a migrator that could credit `address(0)` | Unfixable-by-construction `Migrating` brick; `migrator` is an owner-settable pointer so the protection lives outside the contract that suffers | **Surprised.** Safe config: one-line `require(user != address(0))` |
| **DEDUP-006** | De-approving a decommissioned staker's minter role | Permanently strands every residual `unclaimedReward` backlog; no mass revocation exists to collapse the growing minter set | **Surprised.** Safe config: terminal batch sweep before revoking |
| **DEDUP-007** | Paginating `migrateIn` across days | Page-1 users capture ~83% over-share of the interval's emissions from page-3 users | **Surprised.** Safe config: `antimatterPerDay(token, 0)` across the re-injection, or single-tx `migrateIn` |
| **SPEC-F-03** | Same as DEDUP-006, from the story side | Story-022 Decision 3's "nothing is stranded" has an unstated third precondition | **Surprised** ⇒ in scope |

---

## 7. Proposed ledger operations (READ-ONLY — nothing written; for a human at `/ledger`)

**Precondition:** diff the ledger against a start-of-run snapshot before and after applying (memory `verify-subagent-ledger-writes`).

### 7.1 New entries to upsert (7)

| Label | Fingerprint | Sev (prelim) | Contract / function / rootCauseClass | Report |
|---|---|---|---|---|
| ss16h1 | `3102c29c8407a0e1…` | high | `src/StableStakerV2.sol` / `_updatePool` / `empty-pool-emission-cliff-dilution` | `submissions/H-01.md` |
| ss16l1 | `0651258fcc7f607d…` | low | `src/StableStakerV2.sol` / `emergencyWithdraw` / `stale-index-emission-recycle` | qa-report |
| ss16l2 | `708283cc026fdeb4…` | low | `src/StableStakerV2.sol` / `pendingReward` / `view-excludes-settled-backlog` | qa-report |
| ss16l3 | `f35d1dc03602cac8…` | low | `src/StableStakerV2.sol` / `depositFor` / `missing-zero-address-recipient-guard` | qa-report |
| ss16l4 | `f9a08a4021e57cdf…` | low | `src/StableStakerV2.sol` / `claim` / `retired-staker-perpetual-minter-surface` | qa-report |
| ss16l5 | `d7a3b9d4421f2b9e…` | low | `src/InPlaceMigrator.sol` / `migrateIn` / `sliced-reinjection-emission-overshare` | qa-report |
| ss16q1 | `17404e3df9dab691…` | qa | `remappings.txt` / `vendored-flax-duplicate-artifact` / `unpinned-vendor-drift` | qa-report |

All: `origin: "new"`, `firstSeenRun`/`lastSeenRun`: `stable-staker-16`, `branch: "master"`, `branchesSeen: ["master"]`, `entryPoint: null`.
**Do NOT mint** `fe5e8b27…` (DEDUP-002 → §4.1), `e9a30240…` (DEDUP-008 → §7.3), `a8a164d4…` (DEDUP-010 → §7.4).

### 7.2 Re-weighs (3) — fingerprints preserved

```
/ledger stable-staker reopen  e4567dc3 --severity medium   # §4.1 - full disclosure text there
/ledger stable-staker reweigh ss9l1    --severity medium   # §4.2 - corrected impact text there
/ledger stable-staker reweigh 86fcf00e --severity low      # §4.2 - corrected description text there
```

### 7.3 Still-open re-sightings — bump `lastSeenRun` → `stable-staker-16`, **carry reports forward in full**

`f0cb5f7cdddeea0a` (DEDUP-008; **do not re-file**), `bda951d9f1ce1fef`, `d47619d29f0dcfc9` (+ drift annotation, §2.1), `59eebbf87b3d0a71`, `787e9faceb60e76e`, `f84992e9ac16ce59`, **`dab5a65613c7af50` (fix-pending — §4.3, carryover MANDATORY)**.

### 7.4 Annotation-only (no status change)

| Entry | Annotation |
|---|---|
| `d47619d29f0dcfc9` | `fingerprintDrift: { atRun: "stable-staker-16", cause: "story-023 phUSDPerDay -> antimatterPerDay", reproducesOnlyFrom: "src/StableStaker.sol:phUSDPerDay:silent-zero-emission", liveHashWouldBe: "6aa67015fc658da37be1ea256b3134d872df17450c0f4ce7b4d5fcfb94ca4d6f", fingerprintRecomputed: false }` + title/description refresh (phUSD → Antimatter). |
| `b197e829fb8468fe` | Append DEDUP-010's `nonReentrant` observation + the re-raise trigger (empty-pool gate relaxed). |
| `2b9a89d29c34df41` | `pocCaveat`: PoC bit-rotted on the `IFlax → IAntimatter` rename; **INCONCLUSIVE, not a fix**. **No status change. `REOPEN-ss15m1` stays ARMED.** |
| `eae10d6031d96318`, `8d5ceff20ca74fbd` | `adjacent`: run-16 `f35d1dc0…` is zero-**address**, not zero-**credit** — **not a regression of either**. |
| `9abbb7b1463dbef7`, `7c99f3744421c61f` | `adjacent`: SPEC-F-04 concerns the **vendored** pair (zero gates); these concern the **frozen** pair. Do not collapse. |
| `ss9f3-claudemd-…`, `c8218865da2c8fea` | `adjacent`: SPEC-F-02 / §1.4 concern **different CLAUDE.md sections and claims**. Do not collapse. |

### 7.5 Registry refresh (`registered-projects.json`, human to apply)

`knownIssues` → the 6 surviving reworded/verbatim cached items **plus N1-N10**, `knownIssuesCount: 17`, `knownIssuesExtractedAt: "2026-08-31"`, and a `knownIssuesNote` recording that **KI#7 is superseded, KI#9's pause clause has no live text, and KI#4's harmlessness reading is void for the V2 reward leg.** Also update `description` (still says rewards are in phUSD/FlaxToken).

**Do not re-derive the array from `CLAUDE.md` alone in future without preserving these carve-outs** — memory `phoenix-nft-staking-ki-provenance-defect` records that re-deriving from the stated source silently loses registry-authored rulings.

### 7.6 Cross-repo routes

| ID | Target | Content |
|---|---|---|
| SS16-PHSTAGING-01 | `phoenix-phase-2-staging` | MR-16-03: `ClaimWithdrawStableStaker.s.sol:57-63` `require(pending > 0)` aborts falsely under DEDUP-004, **and** asserts a phUSD balance delta after `claim` (V2 pays AM). Latent today (targets V1). |
| SS16-PHSTAGING-02 | `phoenix-phase-2-staging` | story-023 ABI break: `phUSD()` → `antimatter()` etc. breaks `reflax-mint` / `phase-2-staging` on their next pin bump. |
| *(existing)* SS15M1-PHSTAGING | `phoenix-phase-2-staging` | **Unchanged, still ARMED** — §4.4. |

---

## 8. Reconciliation totals

| | |
|---|---|
| Input findings | 14 (10 DEDUP + 4 SPEC) + 3 manual-review + 5 reconcile-only |
| **KEEP** | **11** (DEDUP-001/003/004/005/006/007/009 + SPEC-F-01/02/03/04) |
| **RE-WEIGH** | **2 ledger entries** (`ss9l1`, `86fcf00e`) + **1 finding→entry** (DEDUP-002 → `e4567dc3`) |
| **SUPPRESS** | **1** (DEDUP-010, C4 tool-noise) + **½** (MR-16-01 asymmetry half, KI N7) — **both routed to visible channels, neither deleted** |
| **Reconcile as still-open, not re-filed** | **2** (DEDUP-008 → `f0cb5f7c`; DEDUP-002 → `e4567dc3`) |
| **Flagged for human review** | **4** (DEDUP-002 re-file basis §4.1; `ss9l1`/`86fcf00e` re-weigh §4.2; DEDUP-004 partial N5 match; DEDUP-010 QA routing) |
| **Findings removed from the run** | **0** |
| **Ledger writes performed** | **0** |
| **Human-set statuses changed** | **0** (`fix-pending` ×1, `wont-fix` ×4, `acknowledged` ×5, `false-positive` ×1, `submitted`/`submitted-qa` ×3 — all untouched) |
