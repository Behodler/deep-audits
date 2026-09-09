# Sanitized Findings — stable-staker run-13 (story-013, `InPlaceMigrator._reinjectWithTopup`)

- **Submodule HEAD:** `d95f4a6fa6391386c547e45e9bf99b3c39f2fe35` (story-013 "Add surplus-funded re-injection top-up (M-01 haircut fix)")
- **Diff baseline:** `ffa4947` (story-012)
- **Mode:** regression
- **Known-issues source:** `registered-projects.json` → `stable-staker.knownIssues` (9 items, extracted from `lib/stable-staker/CLAUDE.md`). `lib/stable-staker/CLAUDE.md` itself has no literal "Known Issues" heading; the 9 design-decision items in the registry are authoritative.
- **Ledger:** `reports/stable-staker/ledger.json`
- **Input:** `reports/stable-staker/13/deduplicated.md` (DEDUP-13-001..004, all Low/QA)
- **Timestamp:** 2026-06-15

## Result summary

| | |
|---|---|
| Input findings | 4 |
| Known-issue / OOS suppressions | 0 |
| Ledger suppressions (acknowledged/wont-fix/false-positive) | 0 |
| Still-open same-fingerprint carryovers | 0 |
| Survivors (new) | 4 |
| Regressions | 0 |
| Flagged for human review | 0 (no borderline matches) |

All four dedup findings **SURVIVE** sanitization. No new finding collides with a known issue, an out-of-scope category, or a same-fingerprint ledger entry. The headline of this run is a **ledger reconciliation proposal**, not a suppression: `ss12m1` (M-01, the haircut bug story-013 was written to fix) is empirically PROVEN FIXED and is proposed `open → fixed`.

---

## Per-finding sanitize decisions (three-law hierarchy)

### DEDUP-13-001 — Underfunded `migrateIn` batch revert + greedy cross-slice surplus drain → **KEEP (Low footgun)**

**Decision: KEEP. Not suppressed by KI#7 or KI#8.**

Justification (Law 3 footgun test — *"would a competent, non-malicious owner be surprised by this consequence?"* → YES):

- **KI#7** ("replacing an in-use strategy does NOT auto-migrate — operator must drain first or replace only while `totalStaked==0`") is about the `setYieldStrategy` healthy-rewire precondition. It does **not** speak to `InPlaceMigrator.migrateIn`, a *new* (story-012) sanctioned path that did not exist when KI#7 was written. The contract's own gross-up math (`topup = mulDiv(amt - credited, amt, credited)`, `src/InPlaceMigrator.sol:276`) silently introduces a **surplus pre-funding requirement** that is invisible at the call site: the operator must separately pre-fund grossed-up surplus over and above the parked principal, or every `migrateIn` slice that routes through a haircutting strategy reverts atomically (`require(topup <= balanceOf - totalParked)`, `:280-281`). A competent operator running the documented `migrateOut → reset → migrateIn` runbook would be surprised that `migrateIn` bricks unless they did a *separate, undocumented* gross-up pre-funding step. That surprise is the footgun signature → **in scope** under Law 3, not an "operator runbook step" suppression.
- **KI#8** owner-trust blesses *who* may call (owner / migrator) and *that* the owner controls config — it does not bless a non-obvious revert-on-underfunding coupling. No malicious-owner vector here (the path is `onlyOwner`+`nonReentrant`+`private` helper, no permissionless griefing); this is a *knowing-action-with-non-obvious-consequence* footgun, which Law 3 keeps.
- **Error-quality sub-point (folded CODE-002):** the surplus `require` subtracts `balanceOf - totalParked` (`:281`) which underflows to a panic `0x11` instead of a readable message when surplus is exhausted — masks the real under-funding root cause from the operator. Kept as a sub-point of the same path.
- **Severity stays Low:** atomic revert (no principal loss), and `claimTimedOut` (`:306`, permissionless, self-scoped) guarantees eventual principal recovery. The conditional-Medium argument ("if the story-013 runbook fails to document the surplus pre-funding precondition") is a **severity/faithfulness question routed downstream** to severity-classifier + story-faithfulness — it is NOT a sanitizer suppression and does not change the keep decision.

**Ledger collision check:** distinct from `ss12l1` (`bda951d9`, open, `nonatomic-per-user-deposit-loop-dos` / `require(credited>0)` zero-credit poison user). Same DoS *symptom* on the same `migrateIn` loop, **different root cause** (surplus underfunding vs zero-credit guard) → distinct `rootCauseClass` → no fingerprint collision. Keep separate.

---

### DEDUP-13-002 — `rescueERC20` vs top-up budget coupling bricks par-restoration → **KEEP (Low footgun)**

**Decision: KEEP. Not suppressed by KI#8.**

Justification (Law 3 footgun):

- The coupling is **non-obvious**: `rescueERC20` (`:337-339`) and the `_reinjectWithTopup` surplus budget (`:280-281`) draw from the *same* unescrowed `balanceOf - totalParked` quantity. An owner who pre-funds surplus, then sweeps "stray" balance via `rescueERC20` mid-migration (a reasonable housekeeping action), unknowingly removes the in-flight top-up budget and triggers the DEDUP-13-001 revert. A competent non-malicious owner would be surprised that a sweep fenced *above* the `totalParked` principal floor (which the contract NatSpec at `:329-339` advertises as "incapable of touching principal") can nonetheless **brick an in-progress migration**. Surprise ⇒ footgun ⇒ in scope.
- **KI#8** owner-trust does not bless this: there is no malicious-owner framing (the principal floor is intact; no user loses principal — only a migration stall, backstopped by `claimTimedOut`). The kept value is the *non-obvious inter-function coupling*, exactly the operational hazard Law 3 keeps.
- **Note:** this is the only borderline-adjacent case (it shares a quantity with DEDUP-13-001 and a *pattern* with ledger `0790a76a`), but the footgun test resolves cleanly to KEEP — **not** flagged for human review, because the decision is not uncertain.

**Ledger collision check:** thematically near `0790a76a` (open Low, "rescueERC20 can sweep the buffer backing underwater withdrawals", `StableStaker.sol:rescueERC20`) — same *pattern* (rescue sweeps an unescrowed in-flight reserve) but **different contract** (`InPlaceMigrator` vs `StableStaker`), different reserve (top-up surplus vs underwater buffer), different fingerprint (`contract:function` differs). Pattern-parallel, distinct location → no collision. Keep separate.

---

### DEDUP-13-003 — Small-principal top-up truncation reverts `migrateIn` → **KEEP (Low/QA)**

**Decision: KEEP. NOT subsumed by KI#2.**

Justification:

- This is an **implementation-quality / availability** finding, not an owner-action, so the owner-trust laws do not reach it. Two compounding facets on the same root (integer truncation on a small principal):
  1. **CODE-001:** when the shortfall grosses up to `topup == 0` (`mulDiv` floors, `:276`), the second `depositFor(token, user, 0)` hits `require(amount > 0)` and reverts the whole atomic batch — the `if (credited < amt)` predicate (`:273`) and `depositFor`'s `> 0` precondition are misaligned; control never reaches the `finalCredited` backstop (`:288-292`).
  2. **CODE-004:** for `amt < 1000` raw units, `amt/1000 == 0`, so `require(finalCredited >= amt - amt/1000)` (`:292`) collapses to **zero-tolerance exact-par**; since the gross-up rounds DOWN, `finalCredited` is generically a few wei short → revert. The advertised "0.1% slack" evaporates below `amt = 1000` units.
- **KI#2 cross-check (explicit, as instructed):** KI#2 is "*Integer-division dust always rounds DOWN (in protocol's favor)*" — it blesses **reward-emission dust** rounding down silently. DEDUP-13-003 is a **top-up truncation causing a REVERT** on the migration path, not a silent dust loss in reward accounting. Different mechanism (revert vs silent round-down), different code (`_reinjectWithTopup` top-up vs `_updatePool` reward dust), different impact (availability DoS vs sub-wei reward loss). **Distinct → not subsumed.** Keep.

**Ledger collision check:** sibling DoS trigger on the same `migrateIn` loop alongside `ss12l1` (`bda951d9`) and DEDUP-13-001 — **distinct root cause** (truncation arithmetic vs zero-credit guard vs surplus underfunding). No collision. Keep separate.

---

### DEDUP-13-004 — Dangling `forceApprove(staker, balanceOf)` allowance contradicts in-code comment → **KEEP (QA / info)**

**Decision: KEEP as QA/info. Not suppressed.**

Justification:

- The kept value is a **verifiable code-vs-comment contradiction** (Law 1 "park it in a visible channel" — a spec-conformance/QA hygiene note, not a security vector). The NatSpec at `src/InPlaceMigrator.sol:190-192` explicitly claims `forceApprove` "is set to the EXACT slice total ... and never left dangling ... nothing lingers." The code at `:225-226` actually approves `balanceOf(address(this))` (which exceeds `total + Σtopup`), so a residual allowance `balanceOf - (total + Σtopup)` is granted to `staker` after the batch. The comment's invariant is **false as written**.
- **Bounded, not an exploit:** `staker` is `immutable` and trusted, so under Law 3 owner-trust no value is at risk from the residual allowance itself; the next `migrateIn` overwrites (no monotonic accumulation). This is *why* it stays QA/info and is not escalated — but the contradiction is a genuine documentation/hygiene defect worth surfacing (recall-beats-tidiness; do not silently drop). Recommend `forceApprove(staker, total + projectedTopups)` or a trailing `forceApprove(staker, 0)`. KEEP.

**Ledger collision check:** none.

---

## Surviving findings (with fingerprints)

Fingerprint = `sha256(contract:function:rootCauseClass[:entryPoint])`. All four are contract-scan findings on the new `InPlaceMigrator.sol` entry point (`entryPoint = null`/absent, legacy-hash form). `function` uses the public entry `migrateIn` where the root manifests at the call site, and the `_reinjectWithTopup` private helper where the root is internal — matching the dedup's `Contract:function` rows.

| ID | Survives | Label | Sev | Contract:function | rootCauseClass | Fingerprint (preimage) |
|---|---|---|---|---|---|---|
| DEDUP-13-001 | YES (new) | L-01 footgun | Low | `src/InPlaceMigrator.sol:migrateIn` | `surplus-underfunding-batch-revert / no-cross-slice-reservation` | `sha256("src/InPlaceMigrator.sol:migrateIn:surplus-underfunding-batch-revert / no-cross-slice-reservation")` |
| DEDUP-13-002 | YES (new) | L-02 footgun | Low | `src/InPlaceMigrator.sol:rescueERC20` | `rescue-vs-topup-budget-coupling` | `sha256("src/InPlaceMigrator.sol:rescueERC20:rescue-vs-topup-budget-coupling")` |
| DEDUP-13-003 | YES (new) | L-03 QA | Low/QA | `src/InPlaceMigrator.sol:_reinjectWithTopup` | `small-principal-topup-truncation-reverts-batch` | `sha256("src/InPlaceMigrator.sol:_reinjectWithTopup:small-principal-topup-truncation-reverts-batch")` |
| DEDUP-13-004 | YES (info/QA) | L-04 QA | Low/QA | `src/InPlaceMigrator.sol:migrateIn` | `dangling-allowance-comment-mismatch` | `sha256("src/InPlaceMigrator.sol:migrateIn:dangling-allowance-comment-mismatch")` |

> Note: DEDUP-13-001 and DEDUP-13-004 share `contract:function` (`InPlaceMigrator.sol:migrateIn`) but carry **different `rootCauseClass`**, so their fingerprints are distinct — no self-collision. (Compute the literal sha256 over the preimage string at ledger-upsert time in finding-manager; preimages above are exact.)

All four are `origin: "new"` — none matches an `open` ledger fingerprint (no `still-open` carryover), none matches a `fixed` ancestor (no regression), none matches an `acknowledged`/`wont-fix`/`false-positive` entry (no suppression).

---

## Ledger reconciliation actions (PROPOSE only — never auto-overwrite human status)

### 1. ss12m1 (`970d7307`, M-01, currently `open`) → PROPOSE `open → fixed` — HEADLINE

- **Evidence:** story-013 (`d95f4a6`) adds the surplus-funded re-injection top-up that closes the `InPlaceMigrator.migrateIn` re-injection haircut (the per-user silent principal loss). Econ-scan / PoC-replay verifies par is restored to **within 1 wei** and the zero-surplus case **reverts atomically** (no silent under-credit). This is the literal change story-013 implements.
- **Status flip rationale:** `open` is a machine status (not a human triage decision), so per reconciliation rules a verified `fixed` may be proposed. Recorded as a proposal for project-manager / finding-manager to apply on the ledger.
- **Proposed command:** `/ledger stable-staker fixed ss12m1 --commit d95f4a6`
- **Caveat:** the four *new* run-13 findings (DEDUP-13-001..004) are all **availability/QA residue of this very fix** (the top-up path itself). They do **not** reopen the value-loss ss12m1 closes — every new failure mode is an atomic revert (no silent under-credit), so ss12m1 stays fixed. Flag this to the human: the fix is correct on the value-loss axis; the new findings are operational-hardening follow-ups on the same code.

### 2. Cross-cut flags — NOT reintroduced by story-013, status UNCHANGED

- **`dab5a656`** (M-01, idle-pool adoption discards credited; `acknowledged`, proposed-fixed @125f585): story-013 touches `InPlaceMigrator` only, not `setYieldStrategy`. **Not re-verified, status unchanged.** Note for human: ss12m1 (the migrateIn sibling of this family) is now fixed by story-013, but that does **not** close the `setYieldStrategy` adoption-discard door — keep weighing `dab5a656` on its own gate basis.
- **`969722dc`** (ss9m7 / M-07, rate-vs-execution residual; `acknowledged`): econ-scan confirms **M-07 is NOT reintroduced** by story-013. In-scope strategies book credited principal as a **constant linear haircut**, so the story-013 gross-up (`topup = shortfall * amt / credited`) uses the **same ratio** the first deposit was haircut by — the rate-vs-execution bypass that defines M-07 is **structurally impossible** on this path. Status unchanged (`acknowledged`); story-013 does not affect it.

### 3. All other open ledger items — UNCHANGED

story-013 is a single-file diff on `InPlaceMigrator.sol`. It does not touch `StableStaker.sol` internals, so every other ledger entry (`0790a76a`, `59eebbf8`, `7b071779`, `b5218ab2`, `4f143a95`, `a56f8778`, `d47619d2`, `796f775f`, `dbdc3ac9`, `0dca43f3`, `e4567dc3`, the `fixed`/`wont-fix`/`submitted` set) is **not touched** and left exactly as-is. No human-owned status (`acknowledged`/`wont-fix`/`false-positive`/`submitted`) is flipped by this pass.

### Carryover stubs

`ss12l1` (`bda951d9`, open) and the other still-open prior-run findings are **not re-reported** this run (no same-fingerprint match among the new findings). They require thin **carryover stubs** under `reports/stable-staker/13/submissions/carryover/` — handed to finding-manager. (DEDUP-13-001 and DEDUP-13-003 are *siblings* of `ss12l1` on the same loop but distinct root cause → they proceed as new findings, and `ss12l1` itself still needs its carryover stub.)
