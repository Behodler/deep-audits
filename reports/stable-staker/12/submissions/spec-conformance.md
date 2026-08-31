# Spec-Conformance Report (Law 2 — Story Faithfulness) — stable-staker run-12

- **Project:** stable-staker
- **Submodule HEAD:** `ffa4947` — `[story-012] Add InPlaceMigrator: in-place single-staker yield-strategy swap`
- **Scope:** `src/InPlaceMigrator.sol` (new, +316 LOC) — regression mode
- **Story under test:** `story-012` (origin); cross-referenced `story-003`/`story-004` (`min(R,P)/P` socialization), `story-010` (empty-pool gate), `story-011` (`depositFor` zero-credit guard).
- **Source faithfulness analysis:** [../faithfulness.md](../faithfulness.md)

---

## What this report is — and is NOT

This is the **Law 2 (faithfulness-to-stories)** report. It records cases where the code does
something other than what its governing `[story-012]` commit body, source NatSpec, or the project
CLAUDE.md invariants say it should. It is **deliberately separate** from the gas/style/QA bundle
([qa-report.md](./qa-report.md)): those are housekeeping nits; the findings below are *spec
deviations* — the contract is internally consistent but does not keep the promise its own story
makes.

Per the repo convention, a faithfulness deviation that **also carries security/value impact** is
reported in BOTH places: the H/M submission (where it is severity-classified and PoC'd) and here,
cross-referenced, so the deviation is never lost behind a severity label. The other two deviations
here are availability/footgun-class and map to QA Low findings; they are listed here as well so the
full set of story-012 deviations lives in one place.

All acceptance criteria below are quoted **verbatim** from in-repo NatSpec / commit body / CLAUDE.md
as captured in `faithfulness.md`. No acceptance criterion was invented.

### Story-012 acceptance criteria (distilled, verbatim sources)

- **AC-1 (par-preservation on re-injection)** — `migrateIn` NatSpec, `InPlaceMigrator.sol:168-169`:
  *"Re-inject a slice `[start, end)` of currently-parked users back into the SAME staker,
  **crediting each user the exact principal that was parked for them.**"* Reinforced by CLAUDE.md:
  *"Stakers only ever get their **principal** back plus phUSD emissions."*
- **AC-2 (principal recoverable)** — timeout hatch (F), `InPlaceMigrator.sol:50-52`: *"returns
  PRINCIPAL ONLY."* — **FAITHFUL** at HEAD (see faithfulness.md §4; no finding).
- **AC-3 (safety)** — contract header (A), `InPlaceMigrator.sol:16`: *"This contract **safely**
  changes a per-token dependency (e.g. an `IYieldStrategy`) on a single live `StableStaker` …"*

---

## F-12-001 — `migrateIn` credits the strategy's (haircut) return, not the exact parked principal

- **Verdict:** **DEVIATION** — and, because the "safe / exact principal" claim is asserted
  unconditionally, an **UNSAFE-STORY** candidate (Law-1 override; see §"Law-1 override" below).
- **Law impacted:** 2 (faithfulness), escalating to 1 (security/value).
- **Location:** `src/InPlaceMigrator.sol:215` (`parked[token][user] = 0`) vs `:223`
  (`staker.depositFor(token, user, amt)`); range **L207-L224**.
- **Function:** `migrateIn`.

**Spec text it violates (verbatim):**
> AC-1, `migrateIn` NatSpec (`InPlaceMigrator.sol:168-169`): *"…crediting each user the **exact
> principal that was parked** for them."*
> CLAUDE.md: *"Stakers only ever get their **principal** back plus phUSD emissions."*

**Actual on-chain behavior:**
`migrateIn` zeroes `parked[token][user]` to the **full** parked `amt` (`InPlaceMigrator.sol:215`)
and decrements `totalParked` by the full `amt` (`:217`), then calls
`staker.depositFor(token, user, amt)` (`:223`). Inside the staker, `depositFor` credits **not
`amt`** but the return of `_routeDeposit` (`StableStaker.sol:631-633`):
`credited = strategy.deposit(token, amount, this)` (`StableStaker.sol:762`). For any haircutting
strategy (AMM/ERC4626 deposit slippage, or `MockYieldStrategy` with `depositSlippageBps > 0`),
`credited < amt`. The user's on-staker `info.amount` is therefore `< parked`, while the migrator has
**irreversibly zeroed** their parked balance — no residual to reclaim, no event, no revert. The
shortfall is silently absorbed by the user.

**Why it is a deviation:** AC-1 requires the exact parked principal be re-credited. The
implementation honours "exact `amt`" on the **debit** side (migrator-side accounting is internally
consistent — INV-1 holds) but breaks it on the **credit** side for any non-par strategy. Untested:
all 14 `InPlaceMigrator.t.sol` tests use a `MockYieldStrategy` with default (zero)
`depositSlippageBps`, so the realistic haircutting path — the very case that motivates a strategy
swap — is unproven, while NatSpec (A) asserts the swap is "safe."

**>> CROSS-REFERENCE — this carries security/value impact and is ALSO reported as a Medium.**
This is the **same issue** as **M-01 (`ss12m1`)** — *"In-place migration re-injection silently
underpays stakers when the new yield strategy haircuts deposits."* It is severity-classified and
PoC-proven there (per-user principal underpayment is a value leak under the stated assumption that
the new strategy haircuts deposits; bounded by deposit slippage, gated behind an in-scope
non-obvious owner footgun → Medium, not High).
- Full security write-up + PoC: [./M-01.md](./M-01.md)
- M-01 fingerprint: `src/InPlaceMigrator.sol:migrateIn:yield-principal-accounting-skew-deposit-leg`

---

## F-12-002 — In-place flow on an underwater strategy parks less than original principal (AC-1 broken at the OUT leg)

- **Verdict:** **DEVIATION** — faithful to the staker's documented `min(R,P)/P` socialization, but
  contradicts story-012's "safely changes a per-token dependency" / "preserving principal" framing.
  A genuine **intent conflict**, surfaced as a Law-3 non-obvious owner footgun.
- **Law impacted:** 2 / 3.
- **Location:** `src/InPlaceMigrator.sol:153` (`parked[token][users[i]] += amt`), where `amt` is the
  staker's realized credit `p_i·min(R,P)/P` computed at `StableStaker.sol:527-528`; range L145-L163.
- **Function:** `migrateOut` (consumes `StableStaker.batchMigrate` → `_exitPosition`).

**Spec text it violates (verbatim):**
> AC-3 / (A), `InPlaceMigrator.sol:16`: *"This contract **safely** changes a per-token dependency
> (e.g. an `IYieldStrategy`) on a single live `StableStaker` …"*
> CLAUDE.md: *"…**preserving principal** and minting earned rewards."*

**Actual on-chain behavior:**
`initiateMigration` realizes the old strategy at `R`; if `R < P` (strategy underwater),
`_exitPosition` caps each credit at `p_i·R/P < p_i` (`StableStaker.sol:527`). `migrateOut` parks
exactly that haircut credit (`InPlaceMigrator.sol:153`), and `migrateIn` later re-credits only that.
The underwater delta `p_i·(1 − R/P)` is **permanently lost** to every staker, with no migrator-side
signal. `initiateMigration` is deliberately **not** blocked by the underwater guard (escape
hatch/migration must always work), so the loss is realized silently.

**Why it is a deviation (not a new bug):** the arithmetic is *faithful* to the documented staker
socialization (story-003/004) — it is **not** a new migrator bug. But the migrator's "safely
changes a per-token dependency" framing invites an operator to run this flow to *swap an impaired
strategy*, which is precisely when `R<P` and the flow silently realizes the loss. A competent,
non-malicious operator would be surprised that "rewire the strategy" also means "crystallize the
current underwater loss for every user" → in-scope footgun. Safe-config guidance: only run on an
at/above-par strategy; check `withdrawDisabled(token)` / `_isUnderwater` first.

**>> CROSS-REFERENCE — operational hazard, reported as QA Low.**
Mapped to **L-02 (`ss12l2`)** — *"Underwater-migration operator footgun: in-place flow silently
crystallizes the socialized haircut."*
- QA write-up: [./qa-report.md](./qa-report.md) (section L-02)

---

## F-12-003 — `depositFor` revert-on-zero-credit can brick a whole `migrateIn` slice

- **Verdict:** **DEVIATION** (availability of the migration, not loss) — operational hazard.
- **Law impacted:** 2.
- **Location:** `src/InPlaceMigrator.sol:223` (`staker.depositFor`) → `StableStaker.sol:632`
  `require(credited > 0, "nothing credited")` (story-011, `c3ec65b`); range L207-L224.
- **Function:** `migrateIn`.

**Spec text it violates (verbatim):**
> story-012 commit body (`git show ffa4947`): *"…then **re-injects the same users into the same
> staker** (migrateIn)."* — the story promises the batch round-trips the users back.

**Actual on-chain behavior:**
If a high-slippage strategy haircuts a dust user's `amt` to zero credit, `depositFor`'s
`require(credited > 0)` reverts. Because `migrateIn` processes the slice in a single transaction with
**no per-user try/catch**, the **whole slice reverts**. The operator must re-page around the bad
user, who remains parked until `claimTimedOut`. No value is lost (the user self-recovers principal
via the timeout hatch), but the story's clean "re-inject everyone" round-trip does not hold for that
user. Faithful "skip already-claimed (`amt==0`)" handling exists (`:210-213`), but there is no
handling for the *strategy-credits-zero* case.

**Why it is a deviation:** the story implies a complete round-trip; the implementation can strand
individual users on a haircutting strategy and let one un-creditable user block any slice containing
it.

**>> CROSS-REFERENCE — availability footgun, reported as QA Low.**
Mapped to **L-01 (`ss12l1`)** — *"Poison/zero-credit user reverts the whole `migrateIn` slice."*
Tier-3 Scenario 3 confirmed: the slice reverts, then `claimTimedOut` returns full principal.
- QA write-up: [./qa-report.md](./qa-report.md) (section L-01)

---

## Law-1 override — is story-012's own intent unsafe?

story-012 re-enables in-place yield-strategy migration that the story-010 empty-pool gate
deliberately forbade. The question is whether the *intended* design re-introduces the
underwater/haircut/slippage harms (M-01/M-05/M-06/M-07 class) the gate was built to eliminate.

**Verdict: PARTIALLY.**
- **Safe part:** story-012 does **not** hot-swap. It drains the pool to genuinely
  `totalStaked == 0`, so `setYieldStrategy` is reached only on a truly empty pool — the gate is
  satisfied *honestly*, not bypassed. The desync the gate forbids does **not** occur. This is a
  legitimate use of the runbook CLAUDE.md itself documents. **FAITHFUL.**
- **Unsafe part:** the M-07-class deposit-haircut/execution-slippage residual is **relocated**, not
  eliminated — it reappears at the `migrateIn → depositFor` leg (**F-12-001**). The user is
  re-deposited into the NEW strategy and credited only the haircut return, while the migrator has
  booked them as fully repaid.

Therefore the story's AC-3/AC-1 promise — "safely change a strategy on a live staker," "exact
principal" — is **not faithfully safe as written**: it is unconditionally asserted in NatSpec
(A)/(F) and CLAUDE.md, but the implementation only delivers it for a *par-preserving* strategy, and
is **falsified by a haircutting target strategy** (the realistic case). Do not bless the "safe"
claim. The concrete loss vector is F-12-001 → M-01.

---

## Summary

| ID | Verdict | Law | Spec violated | Cross-ref |
|----|---------|-----|---------------|-----------|
| **F-12-001** | DEVIATION / UNSAFE-STORY | 2 → 1 | AC-1 "crediting each user the exact principal that was parked" | **M-01 (`ss12m1`)** — Medium, PoC'd |
| **F-12-002** | DEVIATION (footgun) | 2 / 3 | AC-3 "safely changes a per-token dependency" / CLAUDE.md "preserving principal" | **L-02 (`ss12l2`)** — QA Low |
| **F-12-003** | DEVIATION (availability) | 2 | commit body "re-injects the same users into the same staker" | **L-01 (`ss12l1`)** — QA Low |

**Faithful (no finding):** AC-2 timeout hatch returns full parked principal; immutable staker
target; rescue floor fenced below `totalParked`; idempotent `migrateOut`; no double-pay across
`migrateIn`/`claimTimedOut`; empty-pool gate honoured honestly (faithfulness.md §4).

**Bottom line:** three story-012 deviations, all on `InPlaceMigrator.sol`. One (F-12-001) carries
real value impact and is the same root cause as Medium M-01 — it appears in both this report and
M-01.md by convention. The other two are operator footgun / availability deviations cross-referenced
to QA Low L-02 and L-01. The overarching Law-2 conclusion: story-012's "safe / exact principal"
claim holds **only** for a par-preserving target strategy; against a haircutting strategy the very
case that motivates the swap the claim is falsified, so the story's safety assertion is flagged as a
Law-1 override candidate and should not be blessed as written.
