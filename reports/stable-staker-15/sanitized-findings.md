# Sanitized Findings — stable-staker run-15

- **Project:** stable-staker · **HEAD:** `2146428` · **Baseline:** `8856781` (run-14) · **Branch:** `master` · **Mode:** REGRESSION
- **Stage:** sanitizer (known-issue filtering + OOS + ledger reconciliation), after deduplicator
- **Input:** `deduplicated-findings.md` (9 findings, DEDUP-15-01..09) + `manual-review.json` (4 parked, 4 flagged)
- **Ledger:** `reports/ledgers/stable-staker.json` (46 entries) — **READ ONLY this stage; not written.**

## Headline

**Input 9 · Suppressed 0 · Passed 9 · Flagged for human review 4 · Parked 5 (4 inherited + 1 added here).**

Nothing was suppressed as a known issue or as out of scope. That is not a null result: **three of the nine
findings sat directly under a cached known issue that this stage found has no suppression authority** (see §1).

---

## 1. Known-issues provenance verdict — **PARTIALLY UNFALSIFIABLE; two cached items have NO authority**

### 1.1 Does the declared source exist?

**YES.** Unlike the sibling defects recorded for `phStaging` and `phlimbo-ea`, the declared
`knownIssuesSource` = `lib/stable-staker/CLAUDE.md` **exists at HEAD `2146428`** (342 lines, verified via
`git -C lib/stable-staker cat-file -e 2146428:CLAUDE.md`) and is substantive. The 9 cached items were
re-extracted from it mechanically and diffed.

**But the cache is stale by 3 months.** `knownIssuesExtractedAt` = `2026-06-01`; the V1/V2 split landed in
stories 019–021, all after that date. The cache therefore describes a **pre-split** contract that no longer
exists at the path it names.

### 1.2 Cached-but-NOT-derivable (registry-only artifacts — **NO suppression authority**)

| # | Cached item (abbrev.) | Verdict | Why |
|---|---|---|---|
| **KI#7** | *"Replacing an in-use yield strategy does NOT auto-migrate funds — operator must drain it first **or replace only while `totalStaked == 0`** (documented operational requirement)"* | **AUTHORITY LOST** | HEAD no longer documents an operational *requirement*; it documents an **enforced revert**: `setYieldStrategy` reverts `"StableStaker: pool not empty"` unless `totalStaked == 0`. The cached item describes a pre-gate world where the operator could get this wrong. It cannot suppress anything, and it must not be read as blessing an *unenforced* operator obligation. (Confirms the run-14 note that KI#7/KI#8 lost authority.) |
| **KI#8** | *"Owner trust assumptions: owner controls addToken, phUSDPerDay, setPauser, setMigrator, setYieldStrategy — **centralization by design**. Migrator is a permissioned role"* | **NOT DERIVABLE — registry-authored** | HEAD's CLAUDE.md names those owner functions in the Wiring section but **contains no blanket "centralization by design" carve-out anywhere**. Where it does discuss owner power it takes the *opposite* posture — "can never be retargeted by a **compromised owner**", "an owner-mutable target is a **drain vector**". A blanket owner-trust carve-out was never in the stated source. **This is the item that would otherwise have suppressed DEDUP-15-06 and DEDUP-15-07 as "admin mistake". It cannot.** |
| KI#9 | *"…permissionless `emergencyWithdraw` escape hatch is callable **even while paused**, by design"* | **PARTIAL** — head clause derivable, tail clause registry-authored | CLAUDE.md states Behodler3 pausing and a "permissionless `emergencyWithdraw` escape hatch"; the **"even while paused"** qualifier is not in the source. Weak authority; nothing this run depends on it. |
| KI#6 | *"…`emergencyWithdraw` and **`migrateOut`** are intentionally NOT blocked"* | **DERIVABLE but function name is STALE** | HEAD says "`emergencyWithdraw` and **`initiateMigration`** are not blocked". Semantically the same carve-out; the cached wording names a function that no longer exists on V2. Repairable, not lost. |

KI#1–#5 re-derive cleanly and in substance from HEAD (Core safety invariant §; "Yield stays protocol-owned" ¶;
"Exits forward the **actual received** amount" ¶).

### 1.3 Derivable-but-NOT-cached (mechanical re-derivation would have **gained** these; a naive re-extract would also have silently *lost* the four above)

Seven design decisions are stated in the source with known-issue force and are **absent from the cache** — all
post-date 2026-06-01:

- **N1 — Golden rule: the migration triad is permanent** (3 frozen selectors, 4 enforcement layers).
- **N2 — "Fork on DEPLOY, not on change"**; `src/versions/v<N>/` holds frozen deployed snapshots.
- **N3 — "Frozen means frozen — including the bugs."** `ss14m1` and `ss14l8` are preserved deliberately in
  `src/versions/v1/`, and *"an audit that re-files those two findings against `src/versions/` should be
  triaged as 'deliberately preserved', not actioned."* **This is a genuine, newly-derivable suppression
  authority — scoped strictly to `src/versions/**`, and to those two findings.** It is correctly not needed
  this run (the deduplicator filed nothing against V1), and it supplies the basis for closing parked `SA-13`.
- **N4 — `STAKER_VERSION` is deliberately `2`, V1 has no getter, and a reverting `staticcall` must be read as
  "version 1"** — `CrossVersionMigrator.versionOf` "does exactly this". Blesses the *mechanism* in parked `MR-15-03`.
- **N5 — the `setYieldStrategy` empty-pool gate is enforced** (supersedes KI#7).
- **N6 — `CrossVersionMigrator` deliberately omits the surplus-funded top-up**, and the asymmetry
  *"wants a human decision before a cross-version migration is run on a live, underwater user base."*
  Note this is an **acknowledged-but-OPEN** item, not a closure — it defers a decision rather than disposing of one.
- **N7 — an explicit "Known gap"**: the `PreToolUse` hook only fires when `stable-staker` is the session's
  project root (**enforcement layer 2 only**). See §3, DEDUP-15-08 — it does **not** reach layer 3.

**Both directions of the provenance defect are therefore live here.** A mechanical re-extraction refreshes the
cache correctly for KI#7/#8/#9 (dropping two items that were never in the source) but would silently **lose**
nothing of value; conversely the *existing* cache is missing seven derivable items including one real
suppression rule (N3). Recommended: `project-manager` re-extract at `2146428`, drop KI#7 and KI#8, repair KI#6's
function name, and add N1–N7.

### 1.4 Per-KI authority after the V1/V2 split (brief item 4)

| KI | `StableStakerV2` | `versions/v1/StableStakerV1` | `CrossVersionMigrator` / `InPlaceMigrator` |
|---|---|---|---|
| #1 emission cap | yes | yes | n/a |
| #2 dust rounds down / flash-stake | yes | yes | n/a |
| #3 `phUSDPerDay` settles at old rate | yes | yes | n/a |
| #4 yield stays protocol-owned | yes | yes | **no** — CLAUDE.md's N6 explicitly carves the migrators out of the top-up logic |
| #5 actual-received vs requested | yes | yes | n/a |
| #6 underwater block carve-out | yes (**as `initiateMigration`**) | yes (as `migrateOut`) | n/a |
| #7 | **NO AUTHORITY** | — | — |
| #8 | **NO AUTHORITY** | — | — |
| #9 | weak (tail clause registry-only) | weak | n/a |
| **N3 frozen-means-frozen** | **no** | **YES (sole scope)** | **no** |

**No pre-split KI was allowed to suppress a V2-specific finding this run.**

---

## 2. Suppression rules applied — results

**Suppressed as known-issue: 0. Suppressed as out-of-scope: 0. Suppressed as C4 known-invalid: 0.**

Checks performed and cleared across all nine:

- **C4 known-invalid classes** — no finding rests on weird/non-standard ERC-20 behaviour, fee-on-transfer,
  CryptoPunks, the approve race, or user error/phishing. The static-analyzer's aggregate centralization class
  (SA-14, 24 owner-gated entry points) was already correctly dropped at dedup as a detector count, not a footgun.
- **Speculation on future code** — **one partial carve-out applied.** DEDUP-15-05 carries a latent leg
  (unbounded `relinquishPrincipal(booked)` given a custody adapter that debits by *received*) which the
  deduplicator already marked *"stated, not rated"*. Confirmed: **no such adapter exists in
  `reflax-yield-vault` today**, so that leg is speculation on future code without a demonstrated root cause and
  **must not be rated by severity-classifier.** The entry survives intact on its demonstrated leg (`R` may be
  `0`, the door is one-way, and the `PrincipalDivergence` payload is byte-identical to a clean migration).
  Parked visibly as `MR-15-S1` rather than deleted.
- **Law 3 / owner footguns** — DEDUP-15-06 and DEDUP-15-07 **survive**, argued in §3. The only cached item that
  could have suppressed them (KI#8) has no authority, and independently both fail the obviousness test.
- **In-source NatSpec authority** — **explicitly refused twice.** DEDUP-15-03's *"deliberate and correctly
  documented"* fail-open and DEDUP-15-04's *"uncheckable from here"* both carry zero suppression weight, and
  DEDUP-15-04's claim was verified **factually false** at HEAD (`phUSD` is `public` on both shapes;
  `FlaxToken.authorizedMinters` / `mintVersion` are external views, so the two-hop probe is constructible).
  Per standing rule a falsely-exhaustive in-source claim **raises** severity rather than lowering it.
  Same for DEDUP-15-06's `rescueERC20` NatSpec (*"purely buffer + dust"*): accurate before story-020, incomplete now.
- **Parent/forked & third-party root cause** — `AYieldStrategy` / `ERC4626YieldStrategy` live in the sibling
  repo `lib/reflax-yield-vault`. Two findings touch them and **both stay here**, because in both the defect is
  stable-staker's *unasserted dependency*, not the sibling's behaviour:
  - DEDUP-15-07 — `AYieldStrategy.setAsideBufferRecipient` behaves as designed; the gap is that
    `StableStakerV2:521` never reads or asserts it. **Stays.**
  - DEDUP-15-05 — the econ sub-leg (`_disposeShares` redeems with no minimum out) *is* root-caused in the
    sibling, but the filed defect is the missing floor on `StableStakerV2`'s own irreversible step, which is
    where the bound belongs. **Stays**, with a cross-repo pointer recorded for `reflax-yield-vault`.
- **`.github/scripts/`** — not in `outOfScope` (`test/`, `lib/`, `src/interfaces/`), first-party, and already
  precedented by open ledger entry `9abbb7b146` on the same file. DEDUP-15-08 is **in scope**.

---

## 3. Surviving findings — reconciliation status

| ID | Contract : function | Sev | **Reconciliation** | Ledger link |
|---|---|---|---|---|
| **DEDUP-15-01** | `StableStakerV2 :: initiateMigration` | Medium (contested) | **NEW** | — |
| **DEDUP-15-02** | `StableStakerV2 :: _routeExit` ↔ `initiateMigration` | Medium | **RE-RAISE of a `wont-fix` — NOT suppressed; flagged for human re-triage** | `69c7666eee` |
| **DEDUP-15-03** | `CrossVersionMigrator :: initiateMigration` / `_migratorOf` / `_isRegisteredOn` / ctor | Low | **NEW (`incompleteFixOf` `7cdb92fdc7`)** | `7cdb92fdc7` |
| **DEDUP-15-04** | `CrossVersionMigrator :: initiateMigration` (§C) | Low | **STILL-OPEN** (in-place narrowing, no new fingerprint) | `7cdb92fdc7` |
| **DEDUP-15-05** | `StableStakerV2 :: initiateMigration` (469, 496–527) | Low | **NEW** | related `7cdb92fdc7` (different contract) |
| **DEDUP-15-06** | `StableStakerV2 :: rescueERC20` | Low | **STILL-OPEN** (impact re-weigh, no new fingerprint) | `0790a76a00` |
| **DEDUP-15-07** | `StableStakerV2:521` ↔ `AYieldStrategy:63` | Low | **NEW** | caveats `f7991b64ad` |
| **DEDUP-15-08** | `.github/scripts/check-migration-surface.sh` | QA | **NEW**, with a **STILL-OPEN** overlap on leg 2's first half | new; overlaps `c8218865da`, adjacent `9abbb7b146` |
| **DEDUP-15-09** | `StableStakerV2 :: initiateMigration` / `setYieldStrategy` | QA | **NEW** | — |

**No REGRESSION and no INCOMPLETE-FIX status is asserted this run.** Both were considered and both were
declined on evidence, not on convenience:

- The candidate regression (*"a partially-failed exit can now proceed where V1 aborted"*) is **REFUTED** —
  `AYieldStrategy._withdrawInternal` debits the **requested (capped)** amount, so `booked == 0` on a below-par
  exit and V1 proceeded too. On the loss path V2 is strictly better for users than V1.
- `7cdb92fdc7` is **narrowed, not incompletely-fixed**: story-021 landed a real partial fix, and the residual
  splits cleanly into an in-place narrowing (15-04) and a distinct new fingerprint (15-03).

### Findings whose survival required an explicit argument

**DEDUP-15-02 — re-raise of an owner `wont-fix`. Not suppressed.**
The standing reconciliation rule suppresses a `wont-fix` match. It is **not applied here**, and the reason is
Law 1. The closure's own `triageReason` rests on a load-bearing concession, quoted verbatim in the dedup entry:
*"The report itself concedes there is no incremental victim (the slow staker is baseline-unchanged vs a
no-buffer world)."* **Story-020 falsified exactly that clause**: under V1 the buffer never entered the migration
payout, but under V2 `R = balanceOf(this)` makes it part of the pro-rata pool, so the incremental victim now
demonstrably exists. Suppressing a Medium whose *stated* basis for closure has been shown false would bury a
live issue behind a stale disposal. The disclosure requirements are met in full — the prior entry is named, the
`triageReason` is quoted, the re-file basis is stated, the un-disputed first clause of the closure is
explicitly conceded, and the owner's `reclassNote` is **not overridden**. This is a request to **re-triage on
new facts**, routed to the human at `/ledger`. Note its root-cause class differs from the prior entry's, so it
would mint its own fingerprint — it must be **linked to `69c7666eee`**, never filed as a naive new discovery.

**DEDUP-15-06 and DEDUP-15-07 — Law 3 owner footguns. Not suppressed.**
KI#8, the only candidate suppressor, has no authority (§1.2). Independently, both pass the obviousness test —
*would a competent, non-malicious owner be surprised by this consequence?* **Yes, in both cases:**

- **15-06 (`rescueERC20`)** — the owner is not merely unwarned, they are **actively misled by the contract's
  own NatSpec**, which asserts the balance is "purely buffer + dust" and cannot touch user value. That was true
  before story-020 and is false after it, because story-020 made the same balance the migration cushion. An
  owner performing a routine dust sweep, having read the documentation and been reassured by it, converts a par
  migration into a haircut migration. Surprise is not merely likely, it is manufactured. **Footgun, in scope.**
  Only the *unknowing* consequence is filed; malicious-owner variants are suppressed under Law 3 as required.
- **15-07 (`setAsideBufferRecipient`)** — a single off-chain address, set once on the strategy, silently
  determines whether the `ss14l8` fix delivers its promised cushion or approximately zero. The staker never
  reads it and never asserts it, and nothing in the runbook connects the two. **Footgun, in scope.**

**DEDUP-15-08 — not covered by the derivable "Known gap" (N7).**
CLAUDE.md's explicit `**Known gap**` is scoped to **enforcement layer 2** (the `PreToolUse` hook, which only
fires when `stable-staker` is the session root). DEDUP-15-08 is about **layer 3**, the CI script — of which the
same document claims *"No blind spot about which directory an agent was driven from."* The known gap therefore
does not reach it, and the finding's two mechanisms (a `sha256sum`-absent conditional skip that leaves `status`
untouched, and a same-commit edit-plus-re-pin of `FROZEN.sha256` that satisfies every check) are both outside
what was disclosed. Leg 2's first half overlaps open QA `c8218865da` and should be reconciled against it rather
than double-filed; the skip and the re-pin bypass are genuinely new.

---

## 4. Ledger reconciliation — fingerprint drift handling

The dedup report's drift rule was applied: **match by `function` + root-cause class, never by contract path.**
Independently re-derived at this stage against the live ledger:

- **28 of 46** entries are fingerprinted on `src/StableStaker.sol`, which **does not exist at HEAD**
  (`git ls-tree` confirms `src/StableStakerV2.sol` and `src/versions/v1/StableStakerV1.sol`).
- **2 more** are fingerprinted on `src/versions/IStableStakerV1.sol`; HEAD has
  `src/versions/**v1/**IStableStakerV1.sol` (`e3553aa70b` open/low, `9e9dbdc475` open/qa).
- **30 of 46 entries (65%) cannot reconcile on path.** None may be filed NEW or flagged REGRESSION on a path
  change alone.

**New hazard found at this stage and not in the dedup report — 7 of the 30 drifted entries have a `null`
`rootCauseClass`**, so the prescribed "function + root-cause class" match key **degrades to function-only** for
exactly the entries where it matters most:

| Fingerprint | Status | Sev | Function | Consequence of the null |
|---|---|---|---|---|
| `0790a76a00` | open | low | `rescueERC20` | **DEDUP-15-06 claims "same fingerprint, do not re-file" — that claim cannot be mechanically verified.** Match must be asserted by hand on `contract+function`. |
| `69c7666eee` | wont-fix | medium | `_routeExit` | The entry DEDUP-15-02 re-raises. A failed reconcile would drop the `wont-fix` suppression *and* lose the disclosure link. |
| `b5218ab272` | **submitted** | medium | `migrateOut` | Function renamed **and** class null — the hardest re-base in the ledger. |
| `3d61c9552f` | acknowledged | medium | `migrateOut` | Suppression silently stops applying if it fails to reconcile. |
| `35e9be8d59` | wont-fix | low | `migrateOut` | As above. |
| `59eebbf87b` | open | low | `batchMigrate` | Low risk (function name survives). |
| `7b0717792d` | open | info | `add` | Low risk. |

**`fix-pending` handling (never suppressed).** `dab5a65613` (medium, `setYieldStrategy`, rc `accounting-desync`)
is the sole `fix-pending` entry and is **drift-affected**. It was **not re-flagged** by any finding this run.
Per the fix-pending rule this is **not** grounds for an auto-flip to `fixed` — a fix that merely stops tripping
the scanner is not a verified fix, and here the scan did not even target it. Required handling:
**carry it forward in full, keep `fix-pending`, bump nothing, propose nothing.** It is the highest-consequence
drift case in the ledger: a failed reconcile would re-mint it as a NEW medium and lose the human's commitment to fix.

**Carryover required** (finding-manager must copy the original reports forward in full, never a stub):
`DEDUP-15-04` and `DEDUP-15-06` (still-open, in-place), `dab5a65613` (fix-pending), `d1aa40605d` (open, split),
and the remaining live `open` entries unchanged this run (`d47619d29f`, `59eebbf87b`, `7b0717792d`,
`f84992e9ac`, `a56f87780b`, `796f775ff3`, `ss9l1-fina`, `86fcf00ef7`, `4f143a9573`, `e3553aa70b`,
`9e9dbdc475`, `c8218865da`, `9abbb7b146`).

**Not carried over** (already triaged/disposed): the 4 `acknowledged`, 3 `wont-fix`, 5 `fixed`, 1
`false-positive`. **Exception: `69c7666eee` is `wont-fix` and is normally not carried — but because
DEDUP-15-02 re-raises it, its record must accompany that finding as the disclosure source.**

---

## 5. Parked — nothing dropped silently

The 4 inherited parks stand, two of them now with a **derivable-KI basis** they did not previously have:

| Parked ID | Disposition after sanitization |
|---|---|
| `MR-15-03` (`versionOf` infers v1 from a reverting staticcall) | **Stays parked.** Derivable item **N4** now shows the mechanism is explicitly by design (*"treat a revert as 'version 1' … `versionOf` does exactly this"*) — so the "this is a defect" framing is KI-suppressed. The **residual** is not: the invariant "V1 must never gain a `STAKER_VERSION` getter" is asserted by the same document and its only enforcement is the frozen-file hash check that **DEDUP-15-08 shows is bypassable two ways**. Keep the link. |
| `NOTE-2` (stories 020/021 in an unenumerated `auto-complete/` state) | Stays parked; process item. Sharpens **DEDUP-15-09**: story-020 auto-completed carrying its own `[medium]`, so no human ratification step existed where that would have become a follow-on story. |
| `NOTE-4` (`GOLDEN-RULE-OVERRIDE` verbatim in `21a7cef`, which did not retire V1) | Stays parked; hygiene. Fold into DEDUP-15-08's remediation if the gate is ever made to honour the marker. |
| `SA-13` (`StableStakerV1` implements the migratable surface without declaring inheritance) | **Now genuinely KI-closable.** Derivable item **N3** ("frozen means frozen — including the bugs"; re-files against `src/versions/` are *"deliberately preserved, not actioned"*) has authority over exactly this path. Recommend closing as unfixable-by-design, or folding into `9e9dbdc475` as triage prefers. **Left parked, not auto-suppressed** — the closing authority is a KI this stage newly derived and that is not yet in the registry cache. |

**Added by this stage** (appended to `manual-review.json`):

| Parked ID | Reason |
|---|---|
| `MR-15-S1` | DEDUP-15-05's latent `relinquishPrincipal(booked)` leg — carved out as C4 "speculation on future code without demonstrated root cause" (it requires a custody adapter debiting by *received*; none exists in `reflax-yield-vault` at HEAD). **Must not be rated** by severity-classifier. Parked rather than deleted so it re-enters scope the day such an adapter ships, and carrying the cross-repo pointer for `ERC4626YieldStrategy._disposeShares` (no minimum-out on redeem). |

---

## 6. Flagged for human review

1. **`DEDUP-15-02`** — re-raise of owner `wont-fix` `69c7666eee` on falsified-closure grounds. **Human re-triage
   required at `/ledger`.** Not suppressed; `reclassNote` not overridden.
2. **`d1aa40605d`** (`ss14m1`) — **SPLIT, do not close.** Fixed on V2; **still live on V1 mainnet**
   (`0xbce8ABC…79A`, DOLA and USDC revert `"incomplete exit"` today). The ledger has no split primitive.
3. **`7cdb92fdc7`** (`ss14l6`) — **narrow, do not close** as "addressed by story-021".
4. **`f7991b64ad`** (`ss14l8`) — **propose-fixed only**, and close **with the DEDUP-15-01 and DEDUP-15-07
   caveats attached**: the fix does not reach buffer already swept into the strategy, and its magnitude depends
   on an unasserted off-chain config.
5. **Known-issues cache refresh** — drop KI#7 and KI#8 (no authority), repair KI#6's stale function name, add
   N1–N7, and re-stamp `knownIssuesExtractedAt` at `2146428`.
6. **Fingerprint drift** — 30 of 46 entries; 7 of them with `null rootCauseClass`. Re-base by hand and diff
   against the start-of-run snapshot before any ledger write.

---

## 7. Ledger integrity

**No write was performed at this stage.** Verified byte-identical to the start-of-run snapshot:

```
f0715f8da616213a65c358df768879b9e50314577c8e0facaa3b74621e012145  scratchpad/ledger-snapshot-start.json
f0715f8da616213a65c358df768879b9e50314577c8e0facaa3b74621e012145  reports/ledgers/stable-staker.json
```
