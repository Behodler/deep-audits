> ## ⚠ SUPERSEDED IN PART — 2026-08-23. Every `M-07` reference below is stale.
>
> Ledger entry `am3m7` (`aa6a092cacb3c93c`, `M-07`) was triaged **wont-fix** by the owner on
> 2026-08-23 and the audit accepts the reasoning; see the withdrawal banner at the top of
> `submissions/M-07.md` for the full argument. **This run raised 0 surviving Mediums.** The body
> below is preserved verbatim as the audit record, but wherever it treats `M-07` as a live Medium it
> is superseded. Four specific rules stated below are **withdrawn**:
>
> 1. **The `FLAG-04` publication rule** — `L-03` (`0ed1c6e3270816c5`) is no longer proposed for a
>    low → medium re-weigh and does not publish as an appendix to `submissions/M-07.md`. At `R = 0`
>    the delivered total is exactly `amount`, so any floor above `amount` reverts; `L-03` therefore
>    reaches only a caller who passes the documented, deliberate zero waiver. It stays **Low** and
>    **open**. No summary should read "1 Medium loss channel (2 entries)" — the correct count is
>    **0 Mediums**.
> 2. **`Q-06`'s binding closure bar on `M-07`** is **moot**, since `M-07` is closed by triage rather
>    than by a fix and there is nothing left for a project test to prove.
> 3. **`Q-06`'s re-weigh condition** (hold at QA while `M-07` is open, re-weigh to Low on its
>    closure) is withdrawn along with the inert-band limb it rested on. `Q-06` survives at QA on its
>    **independent** limb only: one floor test is named for a condition it does not actually test.
> 4. **`F-05`'s second limb** — that story-003's carried-forward `[medium]` is a real defect
>    dispositioned "on a rationale the arithmetic refutes" — is withdrawn. `F-05` survives at Low on
>    its **first** limb only, which never depended on `M-07`: story-003 was planned, executed **and**
>    reviewed by the same harness with no independent reviewer, then machine-approved.
>
> Nothing here is retracted into silence. `L-03`, `Q-06` and `F-05` all remain **open** in the
> ledger on their surviving limbs, and `M-07` carries reopen triggers on its ledger entry.

---

# Spec-Conformance Report (Law 2) — antimatter-03

**Project:** antimatter · **Commit:** `3a96fb7` (`3a96fb7de072b29515986f92282cdece7b12d4ca`) · **Branch:** `master`
**Repo:** https://github.com/Behodler/antimatter · **Run:** antimatter-03 (regression scan, `c91bc1a..3a96fb7`)

Law-2 findings are labelled `F-xx` and reported here at honest severity. They are **never** folded
into the QA/gas bundle — a deviation from stated behaviour is not noise. Fingerprints below are
carried **verbatim** from `reports/antimatter/ledger.json`; none was re-derived (this project is
under an active fingerprint-drift trap across two signature changes — see §8).

| Label | issueId | Fingerprint | Severity | Ledger status | Subject |
|---|---|---|---|---|---|
| **F-05** | `am3f5` | `a507f00ae1fbc38c` | Low | **new this run** | The unsafe story: story-003 prescribes the inert floor verbatim, and its machine-approved self-review disposes of the resulting Medium on a rationale the arithmetic refutes (**Law 1 overrides Law 2**) |
| **F-01** | `am1f1` | `3aac91383dcb6060` | Low | **`fix-pending`** | **⚠ INCOMPLETE FIX** — story-003 IS F-01's fix; the minimum-output parameter landed and the defect survived |
| F-03 | `am1f3` | `9d06644ddad24e5a` | Low | open | Re-weigh: the documented 2x value property is now **unenforced** — lines unchanged, claim materially more wrong |
| F-02 | `am1f2` | `78612be9264d2b49` | Low | open | Worsened: the burn trip-wire now names a signature that never existed and omits the one that did |
| F-04 | `am2f4` | `d34180996ba41ff8` | Low | open → **propose `fixed`** | Moot by deletion — the unstoried settlement post-condition has been removed. **Not a verified fix.** |

**Ordering note.** All five sit in the Low band, so the sections below are ordered by signal, not by
band: F-05 first because it is the Law-1-overrides-Law-2 judgement this run exists to make, F-01
second because an incomplete fix ranks second only to a regression and **this run has zero
regressions**, then the carried-forward re-weighs with F-03 at the head of them.

**Delta under review — one story, two commits, both tagged.**

| Commit | Subject | Story |
|---|---|---|
| `1ca99d7` | story-003 (red — failing tests first) | story-003 |
| `3a96fb7` | story-003 (green — implementation) | story-003 |

There is **no untagged commit in this delta**. That is a genuine improvement over `c91bc1a..`, and it
is what makes F-04's own remedy ("write the story") satisfied on its own terms — see §7.

---

## 1. Story resolution — three tags, three documents, all read in full

Stories were resolved by globbing the **whole** antimatter story tree, not one sprint and not one
state folder. Nothing in this report is graded from a commit subject, and at no point is "the story
is external / unavailable" offered as an answer. The stories tree was read only, never written.

| Tag | Document | State folder | Role in this run |
|---|---|---|---|
| story-001 | `~/code/product-owner/stories/antimatter/auto-complete/annihilate/001-replace-annihilate-from-with-annihilate.md` | **`auto-complete/`** | preservation check only (implementation unchanged in this delta) |
| story-002 | `~/code/product-owner/stories/antimatter/auto-complete/annihilate/002-cross-check-registered-decimals-against-token.md` | **`auto-complete/`** | preservation check only (implementation unchanged in this delta) |
| story-003 | `~/code/product-owner/stories/antimatter/auto-complete/audit-fixes/003-add-min-phusd-out-slippage-floor-to-annihilate.md` | **`auto-complete/`** | the delta under audit; read in full (386 lines) |

**All three sit in `auto-complete/`, and that is itself worth flagging.** `auto-complete/` is not one
of the canonical state folders (`complete` / `incomplete` / `review` / `archive`). It is the
destination of a batch workflow that moves a story to a completed state under machine approval. Every
story this project has ever shipped has arrived through that folder, which means **no antimatter story
has yet been closed out by a human**. Run-02 recorded this for stories 001 and 002 as a process
observation with no finding attached; this run files it, because in story-003 the machine approval
did something the earlier two did not — it **dispositioned a live [medium] finding** (§3).

---

## 2. Implementation faithfulness — FAITHFUL, and two clean negatives

### 2.1 The story-003 implementation is FAITHFUL. That is stated affirmatively, and immediately qualified.

Every prescribed edit landed verbatim or semantically identically:

- the trailing `uint256 minPhUSDOut` on `annihilate` (`src/Antimatter.sol:226`);
- deletion of the comment, the `expectedForStable` declaration and the `expectedForStable == 0`
  guard that stood at `c91bc1a:232-235`;
- the exactness check at `c91bc1a:257` replaced by the one-sided floor at `:259-260`;
- `PhUSDNotReceived` and `PhUSDAmountMismatch` deleted, `InsufficientPhUSDOut(uint256,uint256)`
  declared with house-style NatSpec at `:80-83`;
- the NatSpec block extended at `:213-225`;
- effects/interactions ordering and the measured-balance checks at `:243`, `:244`, `:254` unmoved.

The executor's only departures are behaviour-identical and explicitly licensed by the story: hoisting
`uint256 totalPhUSD = amount + mintedForStable;` into a local at `:259` and reusing it in the event's
final field at `:266` (story-003:88 — *"Compute the sum once into a local if `forge fmt` line length
or readability suffers"*), passing `0` uniformly at the non-slippage call sites (story-003:98), and
renaming `test_overPhUSDMintReverts` to `test_overPhUSDMintNowSucceeds`.

**There is therefore no implementation-level deviation to report — and grading this run's
faithfulness as "clean" on that basis would be exactly the blessing Law 1 forbids.** See §3.

### 2.2 Clean negative — H-01 (`033432b0e650af67`), story-001's dual-asset allowance fix: NO REGRESSION

Verified **against source at HEAD**, not against story-003's self-certifying checklist item
(story-003:122). The antimatter half is still a self-burn of the caller:

```solidity
239:        _burn(msg.sender, amount);
...
246:        IERC20(stable).safeTransferFrom(msg.sender, address(this), stableAmount);
```

`grep` over `src/` finds **no `from` parameter, no `annihilateFrom`, no permit path and no delegate
path** anywhere; the only `msg.sender` occurrences are `:126-127` (minter auth), `:207` (NatSpec),
`:239` and `:246`, plus the event at `:266`. The signature gained **only** a trailing value parameter
(`:226`), which is precisely what story-003's Background (line 15) mandated: *"it adds a trailing
value parameter only. It must NOT reintroduce any `from`, delegate, permit-style, or third-party
caller path."* `recipient` is only ever credited (`:263-264`). Story-001's guarantee is intact.

### 2.3 Clean negative — M-01 (`a1c81428a47ad295`), story-002's decimals cross-check: NO REGRESSION

Also verified against source at HEAD rather than against story-003's checklist item (story-003:121).
`toStableAmount` is called at `:235`, **unconditionally, before the burn and before every external
call**, and it is the sole producer of `stableAmount` on the annihilate path:

```solidity
235:        uint256 stableAmount = toStableAmount(stable, amount);
```

Its body still reaches the cross-check on every path — the `staticcall` at `:295`,
`DecimalsUnavailable` at `:296` and `DecimalsMismatch` at `:299` are all downstream of unconditional
control flow, and the only earlier exits (`PhUSDMinterNotSet`, `StablecoinNotRegistered`,
`UnsupportedDecimals`) fail closed. Story-003 deleted only the `minter.calculateMintAmount` call,
which sat **after** `toStableAmount` and never gated it. No route around the guard was introduced.
(The closure of M-01 remains **boundary-scoped** per `WATCH-02-03`: it covers the antimatter path
only, and `PhusdStableMinter.mint` remains permissionlessly mis-scalable.)

### 2.4 Zero regressions this run

No `fixed` ledger entry reappeared at `3a96fb7`. Both clean negatives above were re-derived from
source, not inherited from a prior run's verdict or from a story's own checklist. That is what makes
F-01's incomplete fix (§4) the run's top signal: with no regression above it, an incomplete fix is
the highest-ranked reconciliation the standing rule recognises.

---

## 3. F-05 — `am3f5` · `a507f00ae1fbc38c` · Low · **NEW**

**The unsafe story: story-003 prescribes the inert floor verbatim, and its machine-approved
self-review disposes of the resulting Medium on a rationale the arithmetic refutes**

`process` · `story-003` · story document
`~/code/product-owner/stories/antimatter/auto-complete/audit-fixes/003-add-min-phusd-out-slippage-floor-to-annihilate.md`
Code cross-reference: **M-07** (`aa6a092cacb3c93c`, `submissions/M-07.md`) · `src/Antimatter.sol:258-266`

> ### LEAD WITH THIS: **THE IMPLEMENTATION IS FAITHFUL. THIS IS NOT A DEVIATION.**
> The executor did not depart from the story. The story **prescribes the defective check verbatim**
> in its Technical Details. This section is the Law-1-overrides-Law-2 clause made concrete —
> *"if a story's own intended behaviour would introduce an exploit, flag the unsafe story — do not
> bless a faithful-but-exploitable implementation."* Saying otherwise would misdirect the fix.

### 3.1 The story's own prescribed code

story-003, Technical Details, lines 56-66 — the line to REPLACE, and what it becomes:

```solidity
// was (src/Antimatter.sol:257 at c91bc1a):
        if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(expectedForStable, mintedForStable);

// becomes, per the story:
        if (mintedForStable + amount < minPhUSDOut) revert InsufficientPhUSDOut(minPhUSDOut, mintedForStable + amount);
```

And that is exactly what landed, at `src/Antimatter.sol:256-266`:

```solidity
256:        uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;
257:
258:        // The caller's floor, measured against the total both halves come to.
259:        uint256 totalPhUSD = amount + mintedForStable;
260:        if (totalPhUSD < minPhUSDOut) revert InsufficientPhUSDOut(minPhUSDOut, totalPhUSD);
261:
262:        // The antimatter half, minted straight to the recipient.
263:        _phUSD.mint(recipient, amount);
264:        IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);
265:
266:        emit Annihilated(stable, msg.sender, recipient, amount, stableAmount, totalPhUSD);
```

`mintedForStable` is a `uint256`, so `totalPhUSD >= amount` **always** holds and the predicate
`totalPhUSD < minPhUSDOut` is **unsatisfiable for every `minPhUSDOut` in `[0, amount]`** — not merely
for zero. The protection a caller actually buys is `minPhUSDOut - amount`, which is `<= 0` across
that whole range. Halmos proves it over an unbounded domain: `check_invA_d18` and `check_invA_d06`
both PASS with four required-fail falsifiability controls
(`reports/antimatter/03/tier3/halmos-sym3-invA.txt`).

The asset consequence is counted **once**, at Medium, on **M-07** (`aa6a092cacb3c93c`). It is not
re-counted here. What is counted here is the story.

### 3.2 The three stated decisions being challenged

**(a) Deleting the protocol-side zero guard as "quote duplication".** story-003:45-52 instructs:

> **Lines to DELETE (`src/Antimatter.sol:232-235`):**
> ```solidity
>         // What the minter says it will mint for that deposit. Measuring against its own quote,
>         // rather than merely against zero, means a short mint cannot pass unnoticed.
>         uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);
>         if (expectedForStable == 0) revert PhUSDNotReceived();
> ```

The story's Overview (line 11) frames the whole change as removing *"the on-chain quote
duplication"*. The `calculateMintAmount` lookup was duplication. **The zero check was not.** It was
the only protocol-side check that the stable half fetched **anything at all**, and it is **orthogonal
to the exactness check the story set out to remove**: one asks *"did the minter agree with itself?"*,
the other asks *"is there a stable leg at all?"*. The story deletes both in the same breath and never
justifies the second leg separately. Nothing protocol-side replaced it, so at `3a96fb7` there is no
non-waivable floor of any kind on the stablecoin half.

**(b) Choosing the COMBINED total as the floor's unit, justified by symmetry with the event field.**
story-003:68:

> *"So `mintedForStable + amount` is the total phUSD delivered to `recipient` — the identical value
> already emitted as the event's final field at line 263 (`amount + mintedForStable`)."*

The stated justification is that the floor's unit should match a **log field**. That is a
presentation convenience, and it is the choice that creates the inert band: **the only leg that can
move is the stable half.** A caller who expresses the floor in the natural unit — *"my stable half
must fetch at least X"* — lands inside `[0, amount]` and silently buys nothing. Correct usage
requires `minPhUSDOut = amount + expectedStableHalf`, which the NatSpec at `:222-225` does state, but
which inverts the intuitive unit:

```solidity
222:    /// @param minPhUSDOut The least phUSD the caller will accept in total, counting both halves —
223:    ///        an 18-decimal phUSD quantity, never in `stable`'s decimals. Compute it off chain.
```

**(c) Confining the waiver to `== 0` and calling it "the caller's own protection".** story-003:140,
in Concerns:

> *"**`minPhUSDOut == 0` is permitted**: it waives the caller's own protection rather than exposing
> the protocol, and rejecting it would break composability for callers that genuinely do not care.
> Documented in NatSpec instead of enforced."*

and story-003:86, in Implementation Notes:

> *"A caller passing `minPhUSDOut == 0` at a zero rate would receive only the antimatter half."*

**The arithmetic refutes the confinement.** The waiver is not opt-in at a single sentinel value; it
is the default across a contiguous range of apparently-meaningful values, `[0, amount]`. A caller who
passes a **non-zero** floor in that band — who believes they are exercising the protection, not
waiving it — gets the identical outcome. And the contract neither rejects nor records an inert floor:
there is no `require(minPhUSDOut > amount)`, and `minPhUSDOut` is **absent from the `Annihilated`
event** at `:266`, so an honoured floor is indistinguishable from an inert one after the fact.

### 3.3 The process finding — a machine wrote it, executed it, reviewed it, and approved it

story-003 sits in **`auto-complete/`**, and its trailer at line 361 reads:

> **Approved by**: story-batch workflow (**machine approval — not human-reviewed**)

Both Autonomous Decisions sections state that no validation subagent could be dispatched — at
planning time (lines 184-198) and again at review time (lines 329-345). The story asked, in its own
words, for exactly what it did not get. story-003:197-198:

> *"**The independence this delegation buys is genuinely absent here, so this story's review carries
> more weight than usual — it should get a real reviewer, not a rubber stamp.**"*

and the Review Results Executive Summary, lines 266-267:

> *"…written and reviewed without a single independent agent in the loop. The findings below are the
> product of direct inspection, not of the validator pipeline."*

**The request was never met; it was closed by the machine.** The trailer records
*"Review Status acted on: PASSED"* and *"Triage verdict: non-blocking"* (lines 362-363).

**And the carried-forward `[medium]` IS this defect.** story-003:366:

> *"[medium] `minPhUSDOut == 0` at a zero exchange rate lets the caller surrender the stable half for
> only the antimatter half. This is the explicitly planned and NatSpec-documented semantics of a
> waived slippage floor (**standard `minOut == 0` DeFi behaviour**), asserted by
> `test_zeroMinPhUSDOutDisablesFloor`, and the settles-whole-or-not-at-all invariant still holds.
> **It is a caller-side protection the caller opted out of, not a protocol defect** — worth a UI rule
> that never submits a zero floor."*

That is **M-07**, dispositioned non-blocking. Its entire stated ground is that the caller **chose**
to waive protection by passing zero. Halmos INV-A refutes it: **`[1, amount]` waives identically**,
so a caller passing a non-zero floor lands in the same place. *"Standard `minOut == 0` DeFi
behaviour"* is precisely what this is **not** — in the standard pattern a non-zero `minOut` **binds**.
Compounding it, the story's Concerns pre-committed to the same reasoning at line 140, and the same
harness that wrote that sentence reviewed it and approved it. **No independent step existed at which
the arithmetic could have been checked.**

### 3.4 A machine self-certification carries no suppression authority

Stated plainly, because a downstream stage could otherwise read the story's `PASSED` verdict as owner
acceptance or as a known-issue suppression. **It is neither.** No human approved it; the story
document itself asked for a reviewer that was never dispatched; and a `[medium]` dispositioned
non-blocking by the same harness that wrote it is not a triage. Where a self-certification is
falsely exhaustive it **raises** severity rather than lowering it. The sanitizer reached the same
conclusion independently (`selfCertificationsRefused` / SC-01, verdict `PASS — SURVIVES SANITIZATION
IN FULL`).

**This run is the independent review the story asked for.** That is the whole reason F-05 sits at
Low rather than at the QA floor: this is not merely "no independent reviewer", which alone would be
a process note. It is that the acceptance record **affirmatively disposes of** the defect this run
files as a Medium, on a stated ground the run's own proof refutes, in the tree that the next story
will read as settled context.

Two things are deliberately **not** claimed. The work is not accused of infidelity — the
implementation matches the story exactly (§2.1). And no reward-hacking is alleged: the review re-ran
the build and suite, verified each checklist claim against the code, and disclosed its own
non-independence prominently in three separate places. **The failure is not dishonesty. It is that a
self-review cannot catch an error that the story's own reasoning already contains.**

### 3.5 Band, and why Low is both the floor and the ceiling

Low. A story document is not deployed and puts no asset at risk, so QA/Low is the ceiling and
anything higher would overstate a process artifact — the asset impact belongs to M-07 and L-03 and is
counted there. It is lifted off the QA floor by the recorded disposition, which is the false-closure
class this pipeline has been bitten by repeatedly. **Routing is not negotiable:** this belongs in
spec-conformance and **never** in the QA bundle, at any band.

### 3.6 Disposition — HUMAN ONLY (binding)

> **If this entry is ever dispositioned, the disposition must come from a HUMAN. No machine verdict
> may retire it, including a future run of this pipeline. Retiring a machine-approved-self-review
> finding by machine approval would reproduce the exact defect it reports.**

1. A **human** must revisit story-003's Auto-Completed non-blocking item 2 and record that its ground
   is refuted: the inertness is not confined to `minPhUSDOut == 0` and is not the standard
   `minOut == 0` pattern. Until that is done, the story tree carries an acceptance of M-07 that a
   later story may reasonably build on.
2. Re-open the request the story itself made and the batch closed: story-003 should receive a real
   independent review, because the defect it shipped is **upstream of the executor** and only an
   independent step could have caught it.
3. Treat machine approval as **unavailable** for a story whose own Review Results ask for a human,
   and for any story whose carried-forward findings include a `[medium]`.
4. Code remedy is M-07's, not this section's: either measure the floor against the stable leg alone,
   or keep the combined total and revert on an inert floor; in either case restore a protocol-side,
   non-waivable `mintedForStable == 0` revert, and add `minPhUSDOut` to the `Annihilated` event.

### 3.7 Relation to F-04

F-04 reported an **untagged** commit with no authorising story. story-003 **is** tagged, which is
what F-04's remedy asked for, so F-04's proposed closure is correct on its own terms (§7). But the
**process gap F-04 named has recurred in a new form in this very delta**: a tagged story,
machine-approved, with no independent reviewer. **Closing F-04 must not be read as the process
concern being retired — that concern now lives here.**

---

## 4. F-01 — `am1f1` · `3aac91383dcb6060` · Low · **`fix-pending`** · ⚠ **INCOMPLETE FIX**

**The spec's measured-balance discipline is applied in full to the stablecoin leg but only nominally
to the phUSD leg: no minimum-output guard on an already-irreversible burn**

`src/Antimatter.sol` · `annihilate` · guard now at **L260**
Fingerprint basis: `src/Antimatter.sol:annihilateFrom:MissingMinimumOutputGuardOnIrreversibleBurn`
(**drift-affected — never re-derive**)

> ### THE RUN'S HIGHEST-SIGNAL ITEM.
> The code changed since `lastAuditedCommit` and the finding **survived**. With zero regressions this
> run (§2.4), an incomplete fix is the top-ranked reconciliation: it is more dangerous than an
> unfixed bug, because **it reads as done**.
>
> **STATUS STAYS `fix-pending`. This section PROPOSES; it applies nothing.** `fix-pending` is never
> auto-closed and never suppressed.

### 4.1 story-003 IS F-01's fix, and it implements the agreed formulation verbatim

`WATCH-02-02` set the closure bar in run-02: closure requires *"evidence of a **caller-supplied
minimum output** — e.g. a `uint256 minPhUSDOut` parameter checked as
`amount + mintedForStable >= minPhUSDOut` before `:260`."* story-003 implements that formulation
**verbatim**. The parameter exists (`:226`), it is checked against `amount + mintedForStable`
(`:259-260`), and it is checked before settlement.

**The bar is met — and the bar named the defective denomination.** A closure bar that specifies the
combined total is satisfied by an implementation whose combined total can never fall below `amount`.
**The bar failed, not the executor.** A diff-driven or grep-driven pass would read the fix as landed;
where two tiers disagreed (the code tier proposed `fixed`, story-faithfulness returned INCOMPLETE
FIX), the disposition that **preserves** the finding is taken — nothing closes on a tie.

### 4.2 What the delta genuinely DOES cover — recorded, because it is real progress

A caller who states a floor **strictly above `amount`** is now genuinely protected for the whole
excess above `amount`, and the failure **unwinds the irreversible burn** rather than settling short.
Proven by the project's own `test_shortPhUSDMintReverts` (`test/Annihilation.t.sol:302`).

### 4.3 What it does NOT cover

- **(a)** The guard is **inert** for every `minPhUSDOut` in `[0, amount]` → carried at Medium as
  **M-07** (`aa6a092cacb3c93c`), recorded as **`incompleteFixOf`** this entry.
- **(b)** The guard is **one-sided**; the upside bound reconciles to `abe4305ac8f0c44f` (`wont-fix`)
  and is **not** re-filed.
- **(c)** The guard is entirely **caller-supplied**. It replaced a **protocol-side** check with an
  **integrator obligation**; there is now no protocol-side floor of any kind on the stablecoin half →
  `0ed1c6e3270816c5` (L-03).

One hypothesis from F-01's own fix plan was assessed and **retired**: *"an integrator whose ABI
defaults the new parameter to 0"*. `annihilate(address,address,uint256,uint256)` is a **different
selector** from the retired 3-arg form, so an un-migrated integrator reverts loudly rather than
silently passing zero.

### 4.4 The falsified triage premise — quoted verbatim from the ledger

F-01's `triageReason` (human-set, 2026-08-21) records the agreed fix and its rationale. Quoted
**byte-exact as stored**, ASCII hyphens included:

> "FIX-PENDING - owner-accepted 2026-08-21 (in-session instruction). The defect is CONFIRMED VALID and a fix is OWED; this entry is therefore NEVER suppressed - it is rescanned, carried over and shown by /open-issues until a human marks it fixed. AGREED FIX: add a caller-supplied `uint256 minPhUSDOut` parameter to `annihilate` and check the caller's TOTAL receipt against it, i.e. `if (amount + mintedForStable < minPhUSDOut) revert ...` before settlement. This satisfies WATCH-02-02's closure bar (a CALLER-SUPPLIED minimum-output parameter) exactly. SIMPLIFICATION ACCEPTED BY THE OWNER: the pre-burn quote `expectedForStable = minter.calculateMintAmount(...)` and its zero check `if (expectedForStable == 0) revert PhUSDNotReceived();` are BOTH REMOVED, along with the post-mint exact-equality check `if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(...)`. Rationale (owner): the caller's own minimum is the real protection, so re-deriving the minter's quote inside annihilate is redundant calculation. **The audit agrees the zero check carries no state risk once removed - it was a fail-fast BEFORE the irreversible burn, and a post-burn revert unwinds the whole transaction anyway, so its only value was gas.**"

**Halmos refutes that premise.** INV-A proves that over `minPhUSDOut in [0, amount]`, **nothing
reverts post-burn** — so the call **settles** rather than unwinding. The deleted check's value was
never gas; it was the only protocol-side liveness guard on the stable leg
(`reports/antimatter/03/tier3/halmos-sym3-invA.txt`).

Three rulings follow:

1. **That sentence is not owner acceptance of the resulting loss** and carries **no suppression
   authority** over `0ed1c6e3270816c5` or `aa6a092cacb3c93c`. It is a promise-to-fix whose
   accompanying reasoning has since been refuted — the opposite of a disposal.
2. **It is the strongest corroboration of the INCOMPLETE-FIX verdict: the incompleteness was baked
   into the AGREED FIX PLAN, not introduced by the executor.** The same unsafe reasoning was agreed
   at the triage layer here and, independently, at the story layer (§3.2(a)) — which is why an
   independent reviewer was the control that mattered and why its absence is filed rather than noted.
3. It raises M-07's **likelihood** grade to MODERATE, because the configuration that triggers the
   loss is the one the owner was told was safe. It does **not** raise M-07's band.

**A human should decide whether to amend F-01's `triageReason` to record the falsified premise. This
run proposes only.**

### 4.5 No double counting

The residual Medium is carried **once**, on **M-07** (`submissions/M-07.md`, `aa6a092cacb3c93c`),
which is annotated `incompleteFixOf` → `3aac91383dcb6060`. F-01's own band is deliberately **left
alone** at Low: re-weighing it upward as well would count the same defect twice. M-07 and L-03 are
in turn **one loss channel with two independent mitigations** and must not be presented as two
independent Mediums.

---

## 5. F-03 — `am1f3` · `9d06644ddad24e5a` · Low · open · **RE-WEIGH, top of the carried Low findings**

**The contract-header NatSpec justifies the unbacked mint with a redemption symmetry that does not
exist, and states a 2x output the code does not guarantee — and the code no longer enforces the floor
case at all**

`src/Antimatter.sol` · contract-header NatSpec · **L14-L21**, claim at **L17-L19**
Also: `lib/antimatter/CLAUDE.md:99`
Fingerprint basis: `src/Antimatter.sol:contract-header NatSpec:NatSpecOverstatesGuarantee`

> **THIS IS THE FINDING A DIFF-DRIVEN PASS WOULD MISS**, and it is stated first among the carried
> entries for that reason. Its lines did not change. **Its truth value did.**
> `RECONCILE TO 9d06644ddad24e5a` — do **not** mint a new fingerprint for the 2x claim.

### 5.1 The spec text — unchanged, byte-for-byte

`src/Antimatter.sol:17-19`:

```solidity
17: /// @dev Antimatter is handed out as a staking reward across the protocol. Held on its own it is
18: ///      inert; brought together with an equal quantity of a supported stablecoin it annihilates,
19: ///      and the pair is emitted as phUSD — twice the quantity, since both halves are redeemed.
```

and the repo's own `lib/antimatter/CLAUDE.md:99`:

> *"antimatter's entire value to a holder is that it **annihilates into phUSD worth twice its
> quantity**."*

Neither line was touched by this delta. The original defect stands verbatim: **"both halves are
redeemed" is false** — phUSD has no redemption path anywhere in the protocol, and the antimatter half
is minted at `:263` with no asset entering the protocol for it — and **"twice the quantity" is
refuted by the repo's own green test**, `test_annihilateHonoursMinterExchangeRate`, which asserts
195, not 200.

### 5.2 The actual behaviour, and what changed underneath the unchanged text

At `c91bc1a` a settled annihilation was anchored on **both** sides:

- `if (expectedForStable == 0) revert PhUSDNotReceived();` reverted the exact-zero-rate case
  **pre-burn**; and
- `if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(...)` forced the stable leg
  to equal the minter's own quote.

So the documented 2x, while never guaranteed at par, **could not degrade all the way to 1x without
reverting**. At `3a96fb7` **both anchors are gone.** `mintedForStable == amount * R / 1e18` exactly
(decimals cancel) and is accepted at whatever `R` the minter holds:

```solidity
256:        uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;
259:        uint256 totalPhUSD = amount + mintedForStable;
260:        if (totalPhUSD < minPhUSDOut) revert InsufficientPhUSDOut(minPhUSDOut, totalPhUSD);
263:        _phUSD.mint(recipient, amount);
```

**At `R == 0` the call now SETTLES at exactly 1x**, where it previously reverted — the caller's whole
stablecoin half is pulled at `:246`, approved and consumed by `minter.mint` at `:251`, deposited
one-way into the yield strategy, and only the antimatter half is delivered, with `Annihilated`
emitted at `:266` as if normal. The gap between `CLAUDE.md:99` and the code is therefore **no longer
a matter of rounding and par**: the documented value proposition's **floor case is now a reachable,
silent, non-reverting outcome**.

### 5.3 Escalation DECLINED — deliberately, and on the record

F-03 stays at **Low**. The asset impact of that settlement is **M-07's and L-03's, and it is already
counted there**; escalating F-03 would count the same loss a **third** time. What F-03 uniquely
carries is the **documentation half** — a stated **value property** that is no longer enforced
anywhere — and that is why it heads the carried Low findings in this report rather than being folded
into a severity elsewhere.

### 5.4 Annotation — the story's checklist could not have caught this

story-003's checklist line 131 asserts *"no change needed"* for `CLAUDE.md` lines 93/95/99/110, on
the ground that both mandated invariants still hold and that a `grep` *"found no mention of
`calculateMintAmount`, of a quote, or of the `annihilate` signature"*. That is **correct for lines
93/95/110 and for both invariants** — the never-expose-a-burn and settles-whole-or-not-at-all
properties do still hold. **It does not answer for line 99**, which states a **value property** rather
than an invariant, and which the grep the story performed could not have surfaced.

### 5.5 Recommendation

Correct `:17-19`: only the stablecoin half is a redemption; the antimatter half is an
uncollateralised mint. State the `exchangeRate` dependence of the total rather than a flat 2x.
Correct `CLAUDE.md:99` in the same pass, and correct story-001's Background (lines 43-46), which
reproduced the false claim verbatim into the story tree.

---

## 6. F-02 — `am1f2` · `78612be9264d2b49` · Low · open · **WORSENED**

**The invariant trip-wire `CLAUDE.md` nominates for "never expose a burn" is a four-name denylist,
not an invariant check — and it now names one signature that never existed while missing the one that
did**

`test/Annihilation.t.sol` · `test_noPublicBurnEntryPoints` · probe list at **L457-L458**
Fingerprint basis: `test/Annihilation.t.sol:test_noPublicBurnEntryPoints:DenylistTestSubstitutedForInvariant`

> **Also carried in the QA bundle** at `submissions/qa-report.md` → *Carryover — Low Risk*, `[F-02]`.
> The full body lives there and is **not duplicated here**; this section records the Law-2 re-weigh
> and the new evidence from this delta. Both routings point at one ledger entry — reconcile to
> `78612be9264d2b49`, do not mint a second fingerprint.

### 6.1 The spec text it is nominated to enforce

`lib/antimatter/CLAUDE.md:90-93` (and `:105` for the nomination), and the nomination immediately after:

> *"No `burn`, no `burnFrom`, no `ERC20Burnable`, no owner-callable "clawback", no `transfer` to
> `address(0)` path, and **no new entry point that reaches `_burn` except `annihilate`**."*
>
> *"`test_noPublicBurnEntryPoints` in `test/Annihilation.t.sol` **is a trip-wire for this rule.**"*

### 6.2 The actual behaviour at `3a96fb7`

```solidity
454:        // The last entry is the two-argument `annihilate(address,uint256)`, a *different* selector
455:        // from the real entry point `annihilate(address,address,uint256,uint256)`. It is here to
456:        // forbid a shortened burn shortcut, not the annihilation function itself.
457:        string[4] memory signatures =
458:            ["burn(uint256)", "burn(address,uint256)", "burnFrom(address,uint256)", "annihilate(address,uint256)"];
```

The list still names **`annihilate(address,uint256)`** — a form that has **never existed in this
contract** — and does **not** name **`annihilate(address,address,uint256)`**, which **did** exist at
`c91bc1a` (story-001's own signature) and is now retired. This is the **second selector change in
three stories**, and per story-003:90 (*"update the comment text only, never the assertions"*) **only
the comment at `:454-456` moved.** The story's compliance with its own instruction was correct and is
**not itself a finding**.

The consequence is the finding: **no assertion in the suite tracks the entry point's identity at
all**, so the denylist would keep passing across any future signature change — **including one that
added a burn-reaching path**. The trip-wire is now demonstrably **decoupled from the invariant it is
nominated to enforce**.

### 6.3 Escalation DECLINED — the invariant itself was independently re-proved intact

**The defect is the trip-wire's decoupling from its invariant, not a live burn exposure.** The
property still holds and was re-proved **this run**, not inherited: `test_CTRL_noBurnSurfaceOutsideAnnihilation`
plus `invariant_1_soleBurn` over 256 runs / 128,000 calls, **no counterexample**;
`src/Antimatter.sol` still contains exactly one `_burn`, at `:239` inside `annihilate`. That
counter-evidence travels with the finding. Stays **Low**, at the head of the trip-wire class.

### 6.4 Recommendation (unchanged, plus one addition)

Replace the name-denylist with a real property assertion — `totalSupply` non-decreasing across every
non-annihilation external call, exercised with fuzzed calldata, or a source assertion (exactly one
`_burn`, inside `annihilate`). Add explicit probes for the clawback and transfer-to-zero cases the
rule names, and fix the one-argument encoding. **New:** remediation must also amend **story-001:175**,
which instructs that the four entries be kept as-is and thereby gave the denylist's shape written
authority.

---

## 7. F-04 — `am2f4` · `d34180996ba41ff8` · Low · open → **PROPOSE `fixed`** (moot by deletion)

**An untagged commit rewrites the annihilation settlement post-condition on top of a two-story
fix-wave: no story authorises it, story-001 explicitly forbade touching that logic, and story-001's
acceptance checklist still self-certifies that it was preserved**

`src/Antimatter.sol` · `annihilate` · L229-L248 at `c91bc1a` — **code no longer exists at `3a96fb7`**
Fingerprint basis: `src/Antimatter.sol:annihilate:UnstoriedBehaviouralChangeToSettlementPath`

> **Its ledger record carries a binding routing directive** — *"ROUTED TO
> `submissions/spec-conformance.md` ONLY — NEVER THE QA BUNDLE, AT ANY BAND"* — so its **full body
> belongs here**. The QA bundle records only its status, so that a QA reader does not find it simply
> missing.

### 7.1 What F-04 reported

The untagged commit `c91bc1a` — subject *"more precise mint requirement"*, **no `[story-NNN]` tag** —
rewrote the annihilation settlement post-condition on top of a two-story fix-wave, replacing the
post-hoc non-zero check with a pre-computed quote plus an exact-equality assertion:

```solidity
232:        // What the minter says it will mint for that deposit. Measuring against its own quote,
233:        // rather than merely against zero, means a short mint cannot pass unnoticed.
234:        uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);
235:        if (expectedForStable == 0) revert PhUSDNotReceived();
...
257:        if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(expectedForStable, mintedForStable);
```

Neither story sanctioned it. story-002 was confined to `toStableAmount`. **story-001, Required
deltas #5 (lines 122-126), placed the logic explicitly out of bounds:**

> *"Everything else — the check order, the burn-before-interactions ordering, the balance snapshots,
> the `forceApprove`/reset pair, the **`StableNotDeposited` and `PhUSDNotReceived` assertions**, the
> split `_phUSD.mint(recipient, amount)` + `safeTransfer(recipient, mintedForStable)` delivery —
> stays exactly as it is. **This story is a signature and authorisation change, not a rewrite of the
> settlement logic.**"*

And **story-001's acceptance checklist at line 198 is TICKED**:

```
- [x] Preserve the existing settlement order and all balance-measured assertions unchanged
      (`StableNotDeposited`, `PhUSDNotReceived`, `forceApprove` reset).
```

TRUE at `c394ee3`, FALSE at `c91bc1a` — a closed story self-certifying a preservation that no longer
held, on the one function every open finding on this project passes through.

### 7.2 Why it is proposed `fixed` — and why that is MOOT BY DELETION, NOT A VERIFIED FIX

**story-003 has deleted exactly the code that commit introduced.** `grep` over `src/` at `3a96fb7`
finds **no residual reference** to `calculateMintAmount`, `PhUSDNotReceived` or
`PhUSDAmountMismatch`; the error block at `:76-83` now declares `StableNotDeposited` and
`InsufficientPhUSDOut` where the two deleted errors stood. The code the finding is about is gone,
**deliberately, under a story that names it** — which is precisely what F-04's remedy asked for
(*"write the story"*), and the delta contains **no untagged commit at all**.

> **Say it on the entry: this is a disposal by deletion, not a verified fix.** Nobody reviewed the
> unstoried change and found it sound; the code it concerned was removed for an unrelated reason. A
> future re-introduction of a settlement post-condition would **not** be a regression against a
> repaired guard — it would be new code needing fresh review.

**Status change is a human's to apply.** This run proposes only:
`/ledger antimatter fixed am2f4`.

### 7.3 Two residues that TRAVEL — closing F-04 does not retire them

- **(a) story-001's acceptance checklist still self-certifies untruly.** Line 198's ticked box
  remains in the story tree asserting that the settlement assertions were preserved unchanged. That
  is still **untrue of the historical record**, and deleting the code does not correct the document.
  It should be corrected in the same pass as §5.5.
- **(b) The process gap recurs as F-05.** F-04's substance was *"an unreviewed behavioural change to
  the settlement path with nothing in the story tree recording the decision."* This delta has a
  tagged story — and that story was **machine-approved with no independent reviewer**, and its
  acceptance record disposes of a live Medium on a refuted ground. The shape moved; it did not go
  away. **Closing F-04 must not be read as the process concern being retired.**

---

## 8. Standing rules applied in this report

**In-source NatSpec, `CLAUDE.md`, and a story document carry NO suppression authority.** None can
retire a finding, downgrade one, or serve as evidence that a behaviour is safe. A document
establishing that a behaviour is *intended* says nothing about whether it is *safe* — that is decided
against Law 1, which outranks Law 2. This run applies the rule at its sharpest: story-003's `PASSED`
review, its `non-blocking` triage verdict, and its machine approval are **not** owner acceptance and
**not** a known-issue suppression (§3.4).

**A falsely-exhaustive document RAISES severity rather than lowering it.** F-02, because `CLAUDE.md`
nominates a test as *the* trip-wire for a load-bearing invariant and that test cannot detect what its
own rule prohibits. F-03, because the header NatSpec and `CLAUDE.md:99` state a value property that
the code, since this delta, no longer enforces even at its floor case. F-05, because the story's
carried-forward `[medium]` reads as a considered disposition and its ground is refuted.

**Law 1 overrides Law 2.** §3 is that clause exercised: a faithful implementation of an unsafe story
is not a clean bill of health. The faithfulness verdict is stated affirmatively (§2.1) **and**
immediately qualified, so no reader can take "no deviation found" as "nothing wrong here".

**No double counting, and no silent drops.** The single loss channel is counted **once** at Medium on
**M-07** (`aa6a092cacb3c93c`, `submissions/M-07.md`) with **L-03** (`0ed1c6e3270816c5`) as its second,
independent mitigation. F-01 keeps its band, F-03's escalation is declined on the record, F-05 is
capped at Low. Every finding with security or value impact also appears in its own H/M report:
**M-07 is the cross-reference for both F-01 and F-05.** Nothing here was set aside without a visible
channel and a stated reason.

**Fingerprint discipline — an ACTIVE drift trap.** Twelve pre-existing ledger fingerprints are
basis-anchored on the retired function name `annihilateFrom` and will **not** re-derive from current
source; `annihilate` has now changed selector a **second** time (3-arg → 4-arg), so entries minted on
the 3-arg name are exposed the same way. **Every fingerprint in this report was carried verbatim from
`reports/antimatter/ledger.json` and none was recomputed.** `a507f00ae1fbc38c` (F-05) was carried
verbatim from the sanitizer on the basis `process:story-003:MachineApprovedSelfReview`, which is
process-anchored and therefore drift-immune.

**Sanitizer note.** No known-issues document exists for this project at `3a96fb7`, so known-issue
suppression has no authority over anything in this report. F-05 passed the sanitizer
(`PASS — SURVIVES SANITIZATION IN FULL`, `selfCertificationsRefused` / SC-01).

**Nothing in this report was applied to the ledger.** Every status word here — `propose fixed` on
F-04, `fix-pending unchanged` on F-01, the re-weighs on F-02 and F-03 — is a **proposal for a human**.
A separate upsert step follows.
