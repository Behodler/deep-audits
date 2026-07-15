# Spec Conformance Report — phlimbo-ea (run 08)

**Project:** phlimbo-ea
**Run:** phlimbo-ea-08
**HEAD:** `bf42c12e3ad9d834373e8439f0e992aa8870aca4`
**Baseline:** `7045a96ecaf15e9443cc969664278b51a9a9c046`
**Stories audited:** `story-024`, `story-025`
**Law:** 2 (faithfulness to stories)

> **This report is separate from the QA bundle by design.** Faithfulness deviations are
> Law-2 defects — a feature not doing what its story says — not gas or style noise. A
> deviation that ALSO carries asset/value/availability impact receives an H/M label and its
> own submission; the F-label here is that finding's faithfulness cross-reference.

---

## Spec sources and their gaps

**Sources used:**

| Source | Role |
| --- | --- |
| git commit `d61a7a3` body (story-024 Green) | Primary story-024 intent |
| git commit `69e2a2d` body (story-024 Red) | story-024 acceptance framing |
| git commit `ef98cd9` body (story-025 fix) | Primary story-025 intent |
| git commit `27482c2` body (story-025 tests) | story-025 test scope |
| `lib/phlimbo-ea/SolvencyDetermination.md` §4–§5 | V3 design doc |
| NatSpec in `src/MigratorV2V3.sol` + `src/interfaces/IMigratorV2V3.sol` | Contract-level intent |

**⚠ Gaps that constrain every finding below:**

1. **`SolvencyDetermination.md` never mentions `MigratorV2V3` at all** — a grep for `Migrator`
   returns nothing. The migrator's **only** intent sources are its story commit messages and
   its own NatSpec. F-08-01, F-08-02 and F-08-04 are therefore anchored on commit text +
   NatSpec **only**; no design-doc criteria were invented to support them.
2. **`lib/phlimbo-ea/CLAUDE.md` is stale** — its contract inventory stops at V2 and never
   mentions `PhlimboV3` or `MigratorV2V3`, the exact contracts audited this run. It is not
   usable as a V3 intent source.

---

## Story verdicts

### story-024 — **FAITHFUL. Complete. Safe.**

**Commits:** `69e2a2d`, `d61a7a3`, `09ee051`
**Verdict:** FAITHFUL — complete, no deviation, story intent is safe (no Law-1 override).

All five acceptance criteria are **MET**:

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Freeze `accPromoPerShare` during Flushing **at the accrual site** | MET | `src/PhlimboV3.sol:757` — `if (address(promoToken) != address(0) && promoPhase != PromoPhase.Flushing)` inside `_updatePool`. Gate is at the accrual site, not on callers. |
| 2 | `collectReward` (permissionless), `setDesiredAPY`, `setDepletionDuration` all reach `_updatePool` while paused — all three must be covered | MET | All three reach `_updatePool` (L555, L232, L249) and all three are gated by the single accrual-site check. Every `_updatePool` caller was enumerated (L232, 249, 343, 368, 389, 413, 555, 581, 628, 675). No ungated accrual path remains during Flushing. |
| 3 | Mirror the gate in `pendingPromo` so the view cannot over-report mid-rotation | MET | `src/PhlimboV3.sol:884` — same `promoPhase != PromoPhase.Flushing` conjunct. View and accrual agree. |
| 4 | Correct the three stale invariant comments attributing the freeze to pausing | MET | **Exactly three** comment blocks corrected: header §2(b) (L32-38), `accPromoPerShare` state-var docstring (L121-127), `beginFlush` `@dev` (L400-409). Count matches the story exactly. |
| 5 | Includes `forge fmt` normalization of the touched file (declared scope) | MET — no smuggled logic | `forge fmt --check src/PhlimboV3.sol` **exits 0** at HEAD. Full-diff read confirms the **only** semantic deltas in `d61a7a3` are the two `promoPhase != PromoPhase.Flushing` conjuncts (L757, L884). |

**Lifecycle composition — verified, not assumed.** `startPromotion` (L335-355) calls
`_updatePool()` **before** assigning `promoToken`, and `finalizePromotion` zeroes `promoToken`
— so a stale `lastRewardTime` spanning a flush window can never retro-accrue against the
**next** promo token. This was the most plausible way to reintroduce V3-H-01, and it is closed.

**Law-1 assessment: SAFE.** The story's intended behaviour (freeze accrual during Flushing) is
the correct fix for V3-H-01 and introduces no new exploit. Enforcement at the single accrual
site makes it future-proof against new call sites, exactly as the story argues.

**One unconsidered side effect** — see **F-08-03**.

---

### story-025 — **SUBSTANTIALLY FAITHFUL. No scope creep.** 3 Low deviations.

**Commits:** `ef98cd9`, `27482c2`, `bf42c12`
**Verdict:** SUBSTANTIALLY FAITHFUL with 3 deviations (all Low). Story intent is **not** unsafe
(no Law-1 override), but trade-off (a) is a genuine Law-3 owner footgun.

| Criterion | Status |
| --- | --- |
| Copy house `_tryTransfer` helper from PhlimboV3 | MET (byte-identical) — **but see F-08-01**: the copied helper carries an OPEN known defect (V3-L-02) |
| `_forward` banks failed forwards into per-user `unclaimable` + emits `RewardForwardFailed` instead of reverting, so the cursor always advances | MET for the PoC'd blocklist vector; **NOT unconditional — see F-08-01** |
| Permissionless `claimUnclaimable` pull (CEI) | MET — `src/MigratorV2V3.sol:227-233`; entry zeroed **before** `safeTransfer`; `nonReentrant` |
| `withdrawAll` extended to sweep live promo token; `WithdrawnAll` extended with promo amount | MET (declared scope) — **but see F-08-02 and F-08-04** |
| Recovery-note NatSpec rewritten (audit F-01): drop the unreachable escape, document the banked-claims trade-off | MET at the header (L57-68) — **function-level `@dev` left stale, see F-08-02** |

**Scope-creep assessment: CLEAN.** Every `src`/interface change in `ef98cd9` maps to a bullet in
its own commit message. The `unclaimable` public mapping and its interface view are the
necessary mechanics of a declared bullet. Test/snapshot commits (`27482c2`, `bf42c12`) touch
**zero** `src` files (verified via `git log --stat`).

**Law-1 assessment: story intent is NOT unsafe.** No unprivileged attacker path, no theft; harm
is owner-action-gated and owner-reversible.

**Neither story is unsafe under Law 1.**

---

## ⚠ MANDATORY CORRECTION — the trade-off (a) asymmetry was assessed INVERTED

The `story-faithfulness` scan's `tradeOffAssessment (a)` reasoned as follows, and it is
**wrong in direction**:

> "House precedent makes the choice defensible: `PhlimboV3.finalizePromotion` ALSO sweeps
> `unclaimablePromo` to `leftoverRecipient` and zeroes it — the house baseline FORFEITS banked
> failed-transfer claims outright, with no per-user claim at all. `MigratorV2V3` is strictly
> MORE generous… Law 3: do not report a deliberate, documented design the owner chose."

**This claim is INVERTED and MUST NOT propagate to any finding.** Severity-classifier and
severity-auditor independently resolved the asymmetry the other way (dedup **FR-04**):

> **`MigratorV2V3`'s per-user bank + permissionless pull is the CORRECT STANDARD.
> `PhlimboV3`'s aggregate forfeiture is the DEFECT.**

**Why the correction stands:**

1. **Law 1 is dispositive.** When two sibling designs conflict, the one that **destroys user
   funds** cannot be the trusted baseline that excuses the other. An argument of the form
   "PhlimboV3 confiscates, so the migrator's lesser trade-off is fine" **derives its permission
   from the very defect under review**. That is bootstrapping, not a baseline.
2. **PhlimboV3's own spec sides with the pull.** `SolvencyDetermination.md` §4 counts
   `unclaimablePromo` as a **liability the balance must cover**, justified with *"Failed
   transfers stay inside … the tokens never left, so the invariant is undisturbed"* — the doc
   treats the bank as **preserved value**. The migrator's pull is what the spec describes;
   PhlimboV3's sweep is what deviates from it.
3. **story-025's own commit message confirms the direction.** The team took the idiom **from**
   PhlimboV3, recognized **in the sibling** that banking alone was insufficient, built
   `claimUnclaimable` — and **never back-applied it** to PhlimboV3.
4. **Honesty of prose.** The migrator states its trade-off explicitly; PhlimboV3's NatSpec
   (L141-142) promises the amount is *"banked for out-of-band handling"* — an out-of-band
   mechanism that **does not exist anywhere in the contract** (`unclaimablePromo` is a
   write-only counter: incremented L454, zeroed L487, read nowhere in contract logic).

**Consequence recorded here:** PhlimboV3's forfeiture is now **Medium M-01 (run label) /
08-02** in this run, not a blessed baseline. No finding in this report is softened by
"the house does this everywhere" — **PhlimboV3 is the outlier, not the norm**, and the
asymmetry is evidence **for** the finding.

---

## F-08-01 — story-025's brick-proofing guarantee is UNCONDITIONAL in prose, CONDITIONAL in code

- **Severity:** Low
- **Story:** `story-025`
- **Law impacted:** 2
- **Confidence:** high
- **Location:** `src/MigratorV2V3.sol#L275-L290` (`_tryTransfer` / `_forward` / `migrate`)
- **Cross-refs:** V3-L-02 (open) · V3-F-02 (open) · V3-M-01 (fix-pending)
- **Security twin:** 08-04 (Low)

### The spec says

From `src/MigratorV2V3.sol:57-61` (header NatSpec, **written by story-025**):

> "Recovery note: reward forwarding **never reverts**. Each delta is sent with the
> non-reverting `_tryTransfer`; if a recipient cannot receive a token (e.g. a blocklisted
> address), the amount is banked into the per-user `unclaimable` mapping and
> `RewardForwardFailed` is emitted, so the cursor always advances and **a single bad recipient
> can never brick a pass**."

From `src/MigratorV2V3.sol:270-272`:

> "Non-reverting ERC20 transfer used by the migration pass: a single blocklisted or otherwise
> reverting recipient **must not brick** `migrate`."

From commit `ef98cd9`:

> "Copy house `_tryTransfer` helper from PhlimboV3; add `_forward` that banks failed forwards …
> instead of reverting, **so the cursor always advances**."

### The code does

`_tryTransfer` (L275-278) is a **byte-identical** copy of PhlimboV3's helper — including its
unchecked `abi.decode(returndata, (bool))` with **no length check**.

For a token whose `transfer` returns non-empty return-data **shorter than 32 bytes** (or a
32-byte word that is not a valid bool), `abi.decode` **reverts inside `_tryTransfer`**. The
revert propagates through `_forward` → the `migrate` loop → the whole chunk, pinning
`migrateIterator`. Forwarding therefore does **not** "never revert", and such a recipient/token
**can** still brick a pass.

### The deviation

The story's claim is **unconditional** ("never reverts", "can never brick a pass"); the helper
it copied only delivers non-reversion for tokens that **revert-or-return-clean**.

story-025 **knowingly copied the house helper while its defect was live and OPEN in the ledger
as V3-L-02** — byte-identically (md5 `9b80f3419b748e1c9a1de632827e3418`; `PhlimboV3.sol:818-821`
== `MigratorV2V3.sol:275-278`) — and then upgraded the prose to a **stronger guarantee than the
helper can honour**.

**⚠ Scoping correction — do not overstate.** An earlier draft of this entry claimed the exposure
is materially **worse** in the migrator because `promoToken` is an arbitrary owner-selected
partner token. That framing is **withdrawn as falsified by source**: `PhlimboV3.startPromotion`
performs a **mandatory** `safeTransferFrom` at
[PhlimboV3.sol#L346](../../../../lib/phlimbo-ea/src/PhlimboV3.sol) *before* `promoToken` is
assigned (L349), so a short-returning token reverts at install time and **can never be installed
as `promoToken` at all**. The claimed reachability does not exist.

What carries this deviation is the **doc-vs-code core, which is independent of token realism**:
the NatSpec guarantee is **unconditional**, so it is falsified by the mere existence of any
short-returning token, whether or not one is reachable here. This is a **propagation/hygiene**
entry — an open defect replicated into a second contract, under prose stronger than the code.

### Impact

Narrow and token-gated — this rules out the primary blocklist vector, since USDT-style blocklist
reverts return no data and bank correctly. No fund loss; owner-recoverable. Rated **Low**,
consistent with the prior run's rating of the identical class as V3-L-02 (Low).

### Recommendation

Add the length check to **both** copies:

```solidity
return callSuccess && (returndata.length == 0 || (returndata.length >= 32 && abi.decode(returndata, (bool))));
```

**Fixing the house helper in PhlimboV3 alone will NOT fix the migrator — the code is
duplicated, not shared.**

### ⚠ Do not collapse as a duplicate

**DISTINCT** from V3-L-02 and V3-F-02 (both `src/PhlimboV3.sol:_tryTransfer/batchClaim`). This
instance is `src/MigratorV2V3.sol:_tryTransfer/migrate` — **different contract, different call
site, different blast radius** (migration pass vs flush chunk), **newly introduced at
`ef98cd9`**. It is a **replication of the class into a new contract by a fix commit**.

**Sanitizer note:** do **not** auto-suppress under the C4 known-invalid "non-standard/weird
ERC-20 tokens". **This entry does not rest on token realism at all**, so that pattern does not
reach it: it is carried by the byte-identical propagation of a still-open defect (V3-L-02) into a
second contract, under a NatSpec guarantee that is **unconditional** — both of which hold
regardless of which tokens are ever onboarded. (The earlier grounds — "`promoToken` is an
arbitrary owner-selected token" — are withdrawn as falsified by source, per the scoping
correction above. The non-suppression decision is **unchanged and still correct**; do not read
that withdrawal as a reason to suppress.)

---

## F-08-02 — `withdrawAll`: the trade-off is documented in two of three places, and the liability it confiscates is INVISIBLE

- **Severity:** Low
- **Story:** `story-025`
- **Law impacted:** 2 (with a Law-3 footgun analysis)
- **Confidence:** high
- **Location:** `src/MigratorV2V3.sol#L237-L265` (`withdrawAll`)
- **Security twin:** 08-09 (Low)

### The spec says — and it CONTRADICTS ITSELF

**(i)** `src/MigratorV2V3.sol:63-68` — header, **rewritten by story-025**:

> "`withdrawAll` remains a LAST-DITCH escape hatch: it sweeps this contract's **ENTIRE** phUSD,
> reward-token and (live) promo-token balances, **INCLUDING amounts banked in `unclaimable`,
> leaving those claims unbacked**. Reimbursing affected users after such a sweep is an
> out-of-band owner obligation."

**(ii)** `src/MigratorV2V3.sol:239` — the function's own `@dev`, **NOT updated by story-025**:

> "**Pure recovery sweep of stranded balances.**"

Commit `ef98cd9` declared the bullet:

> "Rewrite the recovery-note NatSpec (audit F-01): … **document the banked-claims trade-off**"

### The code does

story-025 rewrote the **contract-level header** and the **interface NatSpec** to disclose that
`withdrawAll` confiscates banked user claims — but left `withdrawAll`'s own function-level
`@dev` at L239 reading **"Pure recovery sweep of stranded balances"**. That text describes the
**pre-story-025** behaviour, when the contract only ever held rewards transiently within a
single tx and a sweep genuinely **could not** touch user-owed value.

The two docs now **contradict each other on the single most consequential property of the
function**, and **the stale one sits directly above the code**.

### The deviation

The story's own bullet — "document the banked-claims trade-off" — is only **partially
executed**: the trade-off is documented in **two of the three** places that describe
`withdrawAll`, and the one left stale is **the one an owner reads at the call site**.

Compounding it: story-025 introduced a **new class of contract-held liability** (per-user banked
`unclaimable`) with **no aggregate accounting**:

- no `totalUnclaimable[token]`
- no aggregate view
- no enumeration

The owner therefore **cannot determine, before or after calling `withdrawAll`, WHETHER the sweep
stranded anything or WHOM to reimburse**. The "out-of-band owner obligation" the NatSpec assigns
them is **not dischargeable from on-chain state alone** — it requires off-chain
`RewardForwardFailed` replay, netted against `UnclaimableClaimed`.

### Law-3 footgun analysis — the surprise is the INVISIBILITY, not the rule

**Would a competent, non-malicious owner be surprised?**

The **design choice itself** (unconditional sweep) is deliberate and documented. **This finding
does not contest it.** *(Note: the `story-faithfulness` scan additionally defended it as
"strictly more generous than the house baseline" — that defence is **withdrawn** per the
mandatory correction above; PhlimboV3's forfeiture is the defect, not the baseline. The finding
stands on invisibility alone, which is unaffected.)*

**The SURPRISE is the invisibility:**

- **PhlimboV3 exposes its banked liability** as the aggregate view `unclaimablePromo()`.
- **`SolvencyDetermination.md` §5 elevates it to a term any observer can check:**
  `promoToken.balanceOf(phlimbo) − promoRewardBalance − Σ pendingPromo − unclaimablePromo >= 0`.
- **The migrator copied the helper but not the liability-accounting discipline**, and is
  **absent from the solvency doc entirely**.

An owner sweeping dust after a completed pass — `withdrawAll`'s original innocuous purpose,
**still asserted verbatim at L239** — has **no on-chain signal that anything is owed**, and the
resulting failed claim surfaces to the user as a **generic ERC20 insufficient-balance revert**,
not as "swept".

**Surprise ⇒ footgun ⇒ in scope as an operational hazard.**

### Impact

**Low.** Owner-action-gated, no unprivileged attacker path, no theft, bounded by banked amounts,
reversible by owner reimbursement. **Not** a Law-1 story-unsafe escalation.

### Recommendation

1. **Update the L239 `@dev` to match the header** — one line, removes a direct contradiction.
2. **Add `mapping(address => uint256) public totalUnclaimable`**, maintained in `_forward` /
   `claimUnclaimable`, so the liability is visible **before** a sweep and the out-of-band
   reimbursement obligation is dischargeable on-chain.
3. *Optionally* have `withdrawAll` sweep `balance - totalUnclaimable[token]`, preserving the
   hatch while keeping claims backed — **but that IS a design change and is the owner's call
   under Law 3.**

---

## F-08-03 — story-024's gate makes an aborted flush's promo window path-dependent on an unprivileged caller

- **Severity:** Low
- **Story:** `story-024`
- **Law impacted:** 2
- **Confidence:** **medium** (recorded honestly — see below)
- **Location:** `src/PhlimboV3.sol#L495-L502` (`abortFlush`), gate at `#L757` (`_updatePool`)
- **Security twin:** 08-01 (Low)

### The spec says

story-024 (`d61a7a3`):

> "Freeze `accPromoPerShare` during Flushing **at the accrual site**"

`SolvencyDetermination.md` §4:

> "`abortFlush` is **solvency-neutral**: `batchClaim` payments were correct early claims, so
> returning to Active leaves state **consistent**."

`src/PhlimboV3.sol:499-500` (`abortFlush` `@dev`):

> "**Always safe**: `batchClaim` is just early forced claims with debts correctly aligned, so a
> partial flush leaves **fully consistent state**."

### The code does

The gate skips promo accrual during Flushing — but **`_updatePool` still advances
`lastRewardTime = block.timestamp` unconditionally (L768)**. Neither `batchClaim`,
`finalizePromotion`, nor `abortFlush` calls `_updatePool` (verified).

So on the `abortFlush` path, **whether stakers are paid for the flush window depends on whether
ANYONE happened to call `_updatePool` during it**:

- **If nobody did** — `lastRewardTime` is still the `beginFlush` timestamp, and the whole window
  **accrues retroactively** once the phase returns to Active.
- **If someone did** — that elapsed promo time is **permanently skipped**, and its tokens remain
  in `promoRewardBalance`, ultimately reaching `leftoverRecipient` at the eventual finalize.

**`collectReward` is permissionless and gated only on `amount > 0`**, so **any third party can
force the second outcome for ~1 wei of `rewardToken`** immediately before an `abortFlush`.

### The deviation

**Not a contradiction of any explicit criterion** — the story specifies the freeze, not the
abort semantics, and **solvency-neutrality DOES still hold** (retro-accrual is capped by
`promoRewardBalance` and fully balance-conserving; nothing is over-distributed).

This is a **behavioural side effect the gate INTRODUCED and the story did not consider**:

- **Pre-gate:** promo accrual across a flush window was **continuous and path-independent** —
  that was V3-H-01.
- **Post-gate:** the flush window's promo accrual **on the abort path** is **path-dependent on
  an unprivileged caller**.

The documented claim that `abortFlush` "leaves fully consistent state" is **true for solvency
but silent on this distribution non-determinism**.

### Impact

**Low — and deliberately not rated higher.** Grief-only with **zero attacker profit** (value
moves from stakers to the owner-chosen `leftoverRecipient`, **never to the caller**). Bounded by
`promoRewardPerSecond × flush duration`, and flush windows are short owner-driven operations.
Affects the **abort path only** — on the normal finalize path the window is skipped regardless,
which is the intended freeze semantic.

Tier-3 (R3) independently **refutes both loss and over-emission**: the flush-window promo stays
in `promoRewardBalance` (500e18 vs 300e18) and continues streaming at the unchanged
`promoRewardPerSecond`, so **the stream tail simply extends**. Tokens are **conserved**.

**Surfaced per Law 1 (recall over tidiness) rather than suppressed.** Confidence is **medium**;
the classifier would not object to QA.

### Recommendation

Either **call `_updatePool()` inside `abortFlush`** before restoring phase Active (making the
window deterministically skipped, matching the finalize path), **or document that an aborted
flush's promo window is intentionally path-dependent**. The former is **one line** and removes
the non-determinism entirely.

---

## F-08-04 — `withdrawAll`'s "LAST-DITCH escape hatch" cannot recover a RETIRED promo token

- **Severity:** QA / informational
- **Story:** `story-025`
- **Law impacted:** 2
- **Confidence:** medium
- **Location:** `src/MigratorV2V3.sol#L248-L262` (`withdrawAll`)
- **Security twin:** 08-10 (QA)

### The spec says

`src/MigratorV2V3.sol:63-65` (story-025):

> "`withdrawAll` remains a **LAST-DITCH escape hatch**: it sweeps this contract's ENTIRE phUSD,
> reward-token and **(live)** promo-token balances"

Commit `ef98cd9`:

> "Extend `withdrawAll` to sweep the **live** promo token"

### The code does

`withdrawAll` reads **only the LIVE promo slot** (`phlimboV3.promoToken()`, L250).

A **retired** promo token — one banked into `unclaimable[tokenA][user]` during promo A, after
`PhlimboV3.finalizePromotion` has zeroed `promoToken` and promo B has started — is
**permanently unsweepable by the owner**, and is claimable **only** by the affected user via
`claimUnclaimable`. If that user is permanently blocked, the balance is **stranded forever with
no recovery path**.

### The deviation

**Faithful to the letter** — the story and NatSpec both say "live", and the parenthetical is
accurate. This is **not a story violation**.

It is a **coverage gap in the "LAST-DITCH escape hatch" narrative**: the hatch cannot recover
every token the contract can hold. Filed as **informational for completeness**.

### Impact

**QA/informational.** Narrow reachability (requires a failed forward during promo A **plus** a
rotation to promo B), dust-scale, and the gap is **user-protective rather than harmful** — it is
the **mirror image of F-08-02**. Explicitly low-value; **do not promote**.

---

## ⚠ Additional Law-2 defect routed here by severity-classifier (not from the story-faithfulness scan)

> **Recorded rather than dropped, per Law 1 (recall over report-tidiness).** This item was
> routed to spec-conformance by `severity-classifier` via `CLASS-08-02.specConflictRouting`,
> which states it *"survives independently of this finding's severity"*. It is **not** one of
> the four F-08 findings enumerated by the run instruction, so it is recorded **without an
> F-label** pending the human's decision on whether to label and track it. Flagged in the
> run report as an open question.

### `SolvencyDetermination.md` contradicts itself on whether banked promo is OWED

**Contract:** `src/PhlimboV3.sol` · **Related finding:** 08-02 (Medium, run label M-01)

**§4's invariant (lines 78-82)** requires:

> `promoToken.balanceOf(phlimbo) >= promoRewardBalance + Σ pendingPromo + unclaimablePromo`

— counting the bank as a **liability the balance must COVER**, and justifying it with:

> "Failed transfers stay inside … **the tokens never left, so the invariant is undisturbed**"

— which frames the bank as **PRESERVED value**.

**The Rotation-solvency section (lines 107-111)** calls the **same quantity "unencumbered"** and
**sweeps it**.

**Both cannot be true.**

**The rotation argument is additionally CIRCULAR — verified in source and decisive.** It
reasons: *"`flushCursor == stakerCount`, so every `promoDebt` is aligned, so `Σ pendingPromo ==
0`, so the entire remaining balance is unencumbered."* But `Σ pendingPromo` is zero **precisely
because L448 aligned the debt and destroyed the entitlement**. **The doc cites the consequence
of the defect as proof there is no defect.**

**Compounding:** the contract's own NatSpec (L141-142) says the amount is *"banked for
out-of-band handling"* — but **no out-of-band mechanism exists anywhere in PhlimboV3**
(`unclaimablePromo` is a **write-only counter**: incremented L454, zeroed L487, **read nowhere**
in contract logic).

**Law-2 defect:** the design doc **does not know its own position** on whether banked promo is
owed. This is the spec-side root of Medium 08-02, and it is why "the project's own test blesses
it" (`PhlimboV3Test.t.sol:1676-1686`) is **not** a valid severity refutation — Law 1 outranks
Law 2, and intended behaviour that destroys user funds is flagged as an **unsafe story**, never
blessed.

---

## Summary

| ID | Severity | Story | Contract | Deviation | Security twin |
| --- | --- | --- | --- | --- | --- |
| **F-08-01** | Low | story-025 | `MigratorV2V3.sol` | "never reverts" / "can never brick a pass" is unconditional in prose, conditional in code (copied V3-L-02 `abi.decode` defect) | 08-04 |
| **F-08-02** | Low | story-025 | `MigratorV2V3.sol` | Banked-claims trade-off documented in 2 of 3 places; L239 `@dev` still "Pure recovery sweep"; liability has no aggregate accounting ⇒ invisible | 08-09 |
| **F-08-03** | Low *(med. confidence)* | story-024 | `PhlimboV3.sol` | `abortFlush` never calls `_updatePool`; gate makes aborted-flush promo window path-dependent on an unprivileged caller | 08-01 |
| **F-08-04** | QA | story-025 | `MigratorV2V3.sol` | Retired promo tokens unsweepable — "LAST-DITCH hatch" coverage gap (faithful to the letter) | 08-10 |
| *(unlabelled)* | — | story-022/024 | `SolvencyDetermination.md` | Doc contradicts itself: §4 liability vs Rotation "unencumbered"; rotation argument circular | 08-02 (M) |

**Story verdicts:** story-024 **FAITHFUL, complete, safe**. story-025 **SUBSTANTIALLY FAITHFUL,
no scope creep**, 3 Low deviations. **Neither story is unsafe under Law 1.**

**Mechanical-commit verification: CLEAN.** `09ee051` and `bf42c12` touch **only**
`.gas-snapshot`; every changed line conforms to the strict pattern
`^[+-][A-Za-z0-9_]+:test[A-Za-z0-9_]*\(\) \(gas: [0-9]+\)$` — zero non-conforming lines, no
config or prose smuggled in. `27482c2` touches only `test/MigratorV2V3Test.t.sol` and
`test/Mocks.sol`.

## Considered and explicitly NOT filed

Recorded so a future run does not re-derive them:

- **story-024 gate composition with `startPromotion`** — VERIFIED SAFE. `startPromotion` calls
  `_updatePool()` before assigning `promoToken`; finalize zeroes it. The most plausible V3-H-01
  reintroduction path, and it is closed.
- **story-025 trade-off (b) (`_forward` banking)** — VERIFIED SAFE. The debt is **not**
  signal-only (`unclaimable(address,address)` is a public interface view,
  `IMigratorV2V3.sol:122`); backed 1:1 by construction; balance-diff bracketing uses **deltas**
  so banked funds are never double-forwarded; entries keyed by token **address** so rotation
  does not orphan a claim; `nonReentrant` + CEI. Strictly better than the revert-everyone
  behaviour it replaced (that was V3-M-01). *Caveat: (b)'s safety is conditional on (a) not
  being exercised — that composition is exactly what F-08-02 tracks.*
- **`withdrawAll`'s new external call to `phlimboV3.promoToken()`** — REJECTED. `phlimboV3` is
  immutable and set at construction; `promoToken()` is a plain public getter that cannot
  realistically revert.
- **`WithdrawnAll` ABI widening** `(address,uint256,uint256)` → `(address,uint256,uint256,uint256)`
  — declared in the story, **not** scope creep. Cross-repo coordination note only: any
  `phoenix-phase-2-staging` indexer decoding this event needs the new signature. No such
  consumer found in this repo; not filed, to avoid speculation.
- **`claimUnclaimable`'s arbitrary `token` parameter** — REJECTED. `unclaimable[token][msg.sender]`
  can only be non-zero for phUSD/rewardToken/promoToken, and `amount == 0` reverts, so an
  attacker-supplied address is inert.
