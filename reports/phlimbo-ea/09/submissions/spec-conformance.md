# Spec-Conformance Report (Law 2 — Faithfulness to Stories)

**Project:** phlimbo-ea
**Run:** phlimbo-ea-09
**Range:** `7045a96..02b9bc2`
**HEAD:** `02b9bc2` — *[story-028] Regenerate .gas-snapshot for skip-reason capture + new tests*
**Stories in range:** story-024, story-025, story-026, story-027, story-028
**Scope of this document:** Law 2 (faithfulness to stories) only. This report is **separate from the QA bundle**, which carries gas/style/Low noise. Findings here are routed at honest severity and are not buried.

---

## Headline

**All five stories in range (024, 025, 026, 027, 028) are FAITHFUL.**

**No Law-1 override fires.** Each story's *own intended behaviour* was independently checked for whether the intent — implemented exactly as specified — would introduce an exploit. None does:

- **story-024** — freezing `accPromoPerShare` accrual during `Flushing` is strictly conservative; it under-credits rather than over-credits, and debts were aligned to the frozen accumulator.
- **story-025** — banking failed forwards instead of reverting preserves cursor advance; the pull path is CEI-ordered and self-scoped.
- **story-026** — skipping a dust position is availability-preserving and leaves the V2 position untouched and the user's.
- **story-027** — the deliberately ungated (`whenNotPaused`-free) `claimUnclaimablePromo` pull was the clause most worth challenging under Law 1, and it survives (see *Refuted* below). Ungating is **required**, not merely convenient: `beginFlush` pauses, so a `whenNotPaused` gate would lock a blocked-then-unblocked staker out of self-rescue for the entire flush window.
- **story-028** — capturing revert reasons is observability-only; no state consequence.

**The deviations below are documentation/asymmetry defects, not behavioural ones.** In every case the on-chain code is correct as written; what is wrong is a document, a comment, or an unreconciled lifecycle between two documents. One (F-09-01) is a case where the *prose is wrong and the code is right*, and correcting the code to match the prose would cause asset loss.

### Severity summary

| Label | Story | Severity | Subject | Defect class |
|---|---|---|---|---|
| F-09-03 | story-027 | **Low** | `SolvencyDetermination.md` §4 + `finalizePromotion` | Falsified solvency invariant + phantom reserve |
| F-09-01 | story-026 | QA | `IMigratorV2V3.migrate` NatSpec | Interface drift (DRIFT-001) — **trap** |
| F-09-02 | story-028 | QA | `IMigratorV2V3.UserMigrationSkipped` NatSpec | Self-contradicting invariant |
| F-09-04 | 024–028 (all) | QA | `lib/phlimbo-ea/CLAUDE.md` | Spec omits the entire audit surface |
| *(V3-L-08)* | story-025 vs 027 | — | `MigratorV2V3.withdrawAll` | Cross-story asymmetry — **reconciles to existing ledger entry**, not a new finding |

---

## F-09-03 — story-027's new retired-token solvency invariant does not survive an `emergencyTransfer` (Low)

- **Upstream ID:** SAN-09-005 / CLASS-005 · **Fingerprint:** `9169babef5b785683138641b0bac3c5f95450d50ccdb0149ecaf65d09bcd4097`
- **Story:** story-027 (`13623b2`); invariant added in this very range by `1c4e1a9`
- **Filed against:** `SolvencyDetermination.md` §4 + step 5, and `src/PhlimboV3.sol` `finalizePromotion` — **not** against `emergencyTransfer`
- **Location:** `SolvencyDetermination.md:84-95`, `SolvencyDetermination.md:177-182`, `src/PhlimboV3.sol:517-519`

### The spec text it violates

`SolvencyDetermination.md:84-95` — **added in this range by story-027** — states the invariant verbatim:

> A separate invariant holds for every token `t` ever used as a promo token,
> including retired ones (`promoToken == address(0)` or rotated to another token):
>
> ```
> t.balanceOf(phlimbo) >= totalUnclaimableOf[t]
> ```
>
> because `finalizePromotion` reserves the bank from its sweep and the only exit
> for a banked amount is the user's own `claimUnclaimablePromo` pull, which
> decrements `totalUnclaimableOf[t]` by exactly the amount transferred.
> (`emergencyTransfer` is the owner-gated exception for the *live* token only —
> it sweeps the live token's bank; a retired token's bank is out of its reach.)

Restated as a public procedure step at `SolvencyDetermination.md:177-182`:

> 5. For every token `t` ever used as a promo token (enumerable off-chain from
>    `PromotionStarted` logs), including retired ones where
>    `getPromoInfo().token` no longer points at `t`:
>    `t.balanceOf(phlimbo) − totalUnclaimableOf(t) >= 0` (§4). A retired token
>    with a non-zero bank holds a real liability even while `promoToken == 0`;
>    step 4 alone does not cover it.

The same unconditional carve-out is restated in-source at `src/PhlimboV3.sol:321-323`:

> A RETIRED token's bank (promoToken == address(0) for it) is unreachable here and stays pullable via `claimUnclaimablePromo`.

### The actual behaviour

`emergencyTransfer` (`src/PhlimboV3.sol:325-341`) sweeps the live promo token's entire balance — bank included, by design — at `src/PhlimboV3.sol:334-339`, but **does not clear** `unclaimablePromoOf` or `totalUnclaimableOf`. The bank becomes a pure liability record with no backing.

The token then **retires** (via `finalizePromotion`, or simply by rotating to another token). At that moment the doc's carve-out — scoped to the *live* token — stops applying, and the invariant is permanently false for `t`:

```
totalUnclaimableOf[t] > 0  ==  t.balanceOf(phlimbo)   →   step 5 reports insolvency, forever
```

No code path restores it. The published step-5 procedure will report the contract insolvent for `t` indefinitely, to any observer following the protocol's own documented method.

### Second-order effect — the sharper leg: phantom reserve

Because the stale bank is never cleared, re-promoting `t` makes `finalizePromotion` reserve a **phantom** bank. Verified at `src/PhlimboV3.sol:517-519`:

```solidity
uint256 banked = totalUnclaimableOf[address(retiredToken)];
uint256 balance = retiredToken.balanceOf(address(this));
uint256 leftover = balance > banked ? balance - banked : 0;
```

`banked` is the phantom amount; the **new** promotion's genuine leftover is stranded by exactly that much. The slot is zeroed at `:521-523`, so the only remaining exits are another promotion in `t` or another `emergencyTransfer`. The saturating subtraction prevents a revert — but not the strand.

### Scope discipline — ejector-seat precedent (do not violate)

> **Do NOT propose accounting inside `emergencyTransfer`.** The ejector-seat precedent governs: `emergencyTransfer` and `pauseWithdraw` are terminal by design (story-022, *"recovery out-of-band"*), and prior finding **pe7m2 was closed INVALID on exactly this ground**. This finding is filed against the **doc** and **`finalizePromotion`**; the optional on-chain leg lands in **`startPromotion`**. No accounting is proposed inside the ejector seat.

Stated as fact for triage, not argued: `emergencyTransfer` terminates in `_pause()` (`src/PhlimboV3.sol:341`), and OZ's `_pause()` carries `whenNotPaused` — so `emergencyTransfer` **reverts while already paused**, including for the whole `Flushing` window (`beginFlush` pauses). The reachable delta is therefore narrow: `emergencyTransfer` must fire while a bank is live **and** the contract unpaused; the phantom-reserve leg additionally needs unpause + re-promotion of the **same** token.

### Why Low rather than QA

Held at Low rather than QA because the falsified invariant was written **in this very range** (story-027) and is a **solvency** invariant — a fresh, load-bearing guarantee a reader would rely on. That is materially more consequential than a NatSpec ordering nit (contrast F-09-01/02/04 at QA). No user assets are at risk; the protocol-side strand is bounded to a new promotion's leftover.

### Recommendation

1. **Documentary (cheapest correct fix, does not touch the ejector seat):** amend §4 to scope the retired-token invariant — *"absent an `emergencyTransfer`, which sweeps the live token's bank and leaves an unbacked record; reimbursement is then an out-of-band owner obligation, as with `MigratorV2V3.withdrawAll`"* — and carry the same caveat into step 5, so an observer does not read a post-ejector contract as anomalously insolvent.
2. **Optional on-chain (only if the phantom strand is judged worth closing):** reconcile the bank lifecycle in **`startPromotion`** (reject or zero a stale bank for a token being re-promoted).

### Cross-reference — pay once for the on-chain fix

Its QA twin **SAN-09-004 / CLASS-004** (`df605bea…`, *retired bank swept after re-promotion*) shares one on-chain leg: **a single `startPromotion` fix closes both**. Do not pay twice for it. The **two documentation fixes remain separate and both are owed** — they falsify different docs (§4 + step 5 here; the `:321-323` docblock there).

**Do not collapse the two findings.** They are paired, not duplicate: different reports (spec-conformance vs QA), different trigger orders (sweep-then-retire vs retire-then-re-promote), different falsified docs, different victims (protocol strands leftover vs user loses a banked entitlement). Neither is a special case of the other.

---

## F-09-01 — `IMigratorV2V3.migrate` NatSpec states the wrong execution order (QA) — DRIFT-001

- **Upstream ID:** SAN-09-006 / CLASS-006 · **Fingerprint:** `1df7ed85b792c609c5e9e062fe027e8244dc9651c8ca4c4176bf40134f892e13`
- **Story:** story-026 (`af6a20f`) · **Cross-ref:** `profiles/interface-drift.json` DRIFT-001
- **Location:** `src/interfaces/IMigratorV2V3.sol:109-113` (prose) vs `src/MigratorV2V3.sol:250` / `:256` / `:268-272` (impl)

### The spec text it violates

`src/interfaces/IMigratorV2V3.sol:109-113`:

> Migrates up to `maxIterations` users from the cursor: live-reads each
> user's V2 position, skips zero positions, withdraws the position from
> V2 (principal + auto-claimed rewards land in this contract), **forwards
> the reward deltas to the user, and re-stakes the principal into V3** on
> the user's behalf.

The prose orders it **withdraw → forward → restake**.

### The actual behaviour

`migrateOne` executes **withdraw → stake → forward**:

- `src/MigratorV2V3.sol:250` — `phlimboV2.withdraw(amount, user);`
- `src/MigratorV2V3.sol:256` — `phlimboV3.stake(amount, user);`
- `src/MigratorV2V3.sol:268-272` — `_forward(...)` × 3

### THE IMPLEMENTATION IS CORRECT

The balance deltas **bracket the whole withdraw+stake block** — snapshots at `src/MigratorV2V3.sol:243-246`, deltas computed at `:260-264` — so forwarding **must** follow the stake for the principal to net out and leave the delta equal to the reward component alone. The code states this itself at `:259-260`:

> The principal was received then restaked, so it nets out: the phUSD delta is exactly the reward component.

This is a **docs-only defect**. No asset or availability consequence exists today.

### ⚠ TRAP WARNING — LOAD-BEARING, MUST SURVIVE EDITING AND BUNDLING

> **Inverting the code to match the prose would forward the PRINCIPAL to the user as if it were a reward.** With forwarding moved before the stake, the phUSD delta no longer nets out — the bracket would capture the withdrawn principal and `_forward` would push it to the user, after which the restake has nothing to stake. This would convert a comment nit into direct asset loss.
>
> **FIX THE PROSE. DO NOT TOUCH THE CODE.**

**On severity:** the trap does **not** raise this finding's severity. The code is correct today and nothing is at risk; speculation about a bad future fix is not a present vulnerability. But the warning is load-bearing and **must not be stripped** when this finding is bundled, summarised, or re-labelled.

### Recommendation

Correct the prose at `src/interfaces/IMigratorV2V3.sol:111-113` to read **withdraw → re-stake the principal into V3 → forward the reward deltas**. Do not touch `src/MigratorV2V3.sol`.

### Why reported at all

Law 2: a pure spec deviation with no security impact is still reported **visibly** (as F-09-01) rather than dropped into gas-report noise — and here the prose is not merely wrong, it is *dangerously* wrong.

---

## F-09-02 — story-028's stated invariant is a biconditional the code does not satisfy (QA)

- **Upstream ID:** SAN-09-007 / CLASS-007 · **Fingerprint:** `c39652b74df0d58cc6a243871376e94afc1d106fd9b1ebe4a88e22ef101bae48`
- **Story:** story-028 (`d130006`)
- **Location:** `src/interfaces/IMigratorV2V3.sol:68-73` (spec) vs `src/MigratorV2V3.sol:199-201` (impl)

story-028 is **mechanically faithful** — the event was widened to 3 args, dust emits `""` (`src/MigratorV2V3.sol:189`), `skipCurrent` emits `""` (`:286`), and the catch emits the raw `reason` bytes (`:200`). The *direction* of the mapping is right. Its **stated invariant** is not.

### The spec text it violates

story-028 (`d130006`) body:

> Widen UserMigrationSkipped with a trailing un-indexed bytes reason:
> - empty reason = skipped without attempting (dust band, skipCurrent)
> - non-empty = raw ABI-encoded revert data caught from the migrateOne self-call

Restated as a hard invariant at `src/interfaces/IMigratorV2V3.sol:68-73`:

> INVARIANT: empty (`reason.length == 0`) means the migration was skipped WITHOUT
> being attempted (dust band or `skipCurrent`); non-empty means the
> `migrateOne` self-call was attempted and reverted with this data
> (standard encodings: `Error(string)` selector 0x08c379a0,
> `Panic(uint256)` selector 0x4e487b71, **or empty returndata reverts**).

### The actual behaviour

The catch at `src/MigratorV2V3.sol:199-201` emits whatever returndata the reverting `migrateOne` produced — **including nothing**. A bare `revert()`, a `require(cond)` with no message anywhere in the withdraw/stake/hook chain, or an out-of-gas in the sub-call under the 63/64 rule all yield `reason.length == 0` **from the attempted branch**.

So `empty reason` does **not** imply *not attempted*. Two defects, one text:

1. **The invariant is false.** It is asserted as a biconditional; the code satisfies only one direction (`non-empty ⇒ attempted-and-reverted`).
2. **The interface contradicts *itself in the same sentence*.** It lists *"empty returndata reverts"* as a member of the **non-empty** clause. An empty-returndata revert cannot be non-empty.

The ambiguity lands **precisely on story-028's stated purpose** — letting the owner read the events to tell a genuinely bad position from a misconfiguration. An empty-returndata revert currently reads as **dust** and would be silently written off: exactly the outcome story-028 exists to prevent.

**The OOG case is not hypothetical.** The same contract anticipates it explicitly — `skipCurrent`'s own NatSpec at `src/interfaces/IMigratorV2V3.sol:135-136` reads *"a way the migrateOne try/catch cannot absorb (e.g. gas exhaustion under the 63/64 rule)"*, echoed at `src/MigratorV2V3.sol:72` and `:280`.

### Why QA and not Low

The ambiguity **is resolvable off-chain today**, and that is what holds it at QA: the `amount` field disambiguates all three empty-reason cases.

| Case | `reason` | `amount` |
|---|---|---|
| `skipCurrent` | `""` | `== 0` |
| Dust band | `""` | `0 < amount < MINIMUM_STAKE` (1e15) |
| Attempted, empty revert | `""` | `>= MINIMUM_STAKE` |

No user is stranded by the contract — only by a misreading the data itself can correct. **But** the owner can only use the `amount` workaround **if they know to**, and the interface currently tells them the opposite. That is why it is not dropped.

### Recommendation

Either:

- **(a)** correct the invariant prose to the true, one-directional statement — *"non-empty implies attempted-and-reverted; empty means either not attempted or attempted with no returndata — disambiguate via `amount` against MINIMUM_STAKE"*; or
- **(b)** make it a real biconditional by emitting a non-empty sentinel from the catch when `reason.length == 0`.

**(a) is sufficient and cheaper.**

### Cross-reference — must survive V3-M-04's closure

Bears directly on **V3-M-04's residual OOG vector**. The OOG skip that V3-M-04's fix leaves as a documented scope limitation is *exactly* the case this ambiguity would cause an owner to misread as dust. **This cross-reference must survive V3-M-04's closure.**

---

## F-09-04 — the project spec omits the entire audit surface (QA)

- **Upstream ID:** SAN-09-008 / CLASS-008 · **Fingerprint:** `aedfcdb0869a96c92335c2bd1abee707dc11cb570d1bd3b20287eb8893b851fb`
- **Stories:** 024, 025, 026, 027, 028 (all)
- **Location:** `lib/phlimbo-ea/CLAUDE.md`

### The spec text it violates

Audit-root `CLAUDE.md`, Law 2:

> Stories live in `[story-NNN]`-tagged git commit messages, `lib/<project>/docs/`, and the project `CLAUDE.md`.

### The actual behaviour — verified this run

- `lib/phlimbo-ea/CLAUDE.md` is **120 lines** and contains **zero** occurrences of `PhlimboV3` or `MigratorV2V3` (verified by `grep` at `02b9bc2`).
- **No `docs/` directory exists.** The only design doc is the root-level `SolvencyDetermination.md`.

Both contracts — the entire subject of stories 023–028 and of this run's scope, across runs 07, 08 and 09 — are absent from the project spec. Of Law 2's three named story sources, one is empty and one does not exist.

This is a **documentation gap, not a code deviation**.

### ⚠ A future run must not read that silence as absence of intent

Every faithfulness verdict in this run rests on **commit bodies + interface NatSpec + `SolvencyDetermination.md`**. A future run that tries to reconcile V3 behaviour against `CLAUDE.md` will find nothing, and **must not** conclude the behaviour was unintended.

### Why this also blocks known-issues suppression

This is the **root** of the run's known-issues block, and the two are one defect with two symptoms: the same `CLAUDE.md` is the registry's `knownIssuesSource` for all **10 cached KIs**, yet `PhlimboV3` and `MigratorV2V3` appear **zero** times in it. A spec file that does not mention the audit surface cannot support known issues about it. The KIs are V1-era and not re-derivable from source; the standing memo records **KI-10 and KI-4 nearly suppressing valid V3 findings** in a prior run. Suppression stays blocked until the file is re-extracted.

### Recommendation

Add a V3 section to `lib/phlimbo-ea/CLAUDE.md` covering `PhlimboV3` + `MigratorV2V3` and their Critical Invariants (the §4 solvency invariants, §2.1 accumulator-never-reset, the frozen-staker-set property). **Also add a genuine Known Issues section**, which would let a future run re-derive a falsifiable KI set and lift the block. Low effort, high leverage for every subsequent audit.

---

## Cross-reference — the `withdrawAll` faithfulness lens reconciles to **V3-L-08** (existing open Low)

*Not a new run-09 finding. Recorded here so the Law-2 lens on `withdrawAll` is traceable to where it is tracked.*

The story-faithfulness scan raised the story-025 / story-027 sweep-vs-reserve asymmetry on `MigratorV2V3.withdrawAll` (`src/MigratorV2V3.sol:319-338`). The **deduplicator dispositioned it into existing ledger entry V3-L-08** (`faa2d9ba`, **open**, Low — *"withdrawAll strands banked unclaimable (no `totalUnclaimable`)"*): same contract, same function, same root cause, and V3-L-08 already carries a faithfulness ref (**F-08-02**) and the stronger PoC. It is therefore **correctly reconciled, not dropped** — and it is absent from `classified-findings.json` because that set contains only **NEW** findings, while V3-L-08 is pre-existing.

**This is NOT a deviation from story-025's text.** story-025 (`ef98cd9`) asked for *"Extend withdrawAll to sweep the live promo token"* + *"document the banked-claims trade-off"*, and got exactly that. The trade-off is explicitly documented at `IMigratorV2V3.withdrawAll`:

> Owner-only LAST-DITCH recovery sweep… including amounts banked in `unclaimable`, whose claims become unbacked (reimbursement is then an out-of-band owner obligation).

Under **Law 3**, a documented, owner-gated, explicitly-reasoned trade-off is a **trusted design choice, not a footgun**. Within this one range the owner fixed the sweep-eats-the-bank problem in `PhlimboV3` (reservation at `:517-519`) but left the structurally identical shape in `withdrawAll`, which sweeps all three token balances in full with no reservation and does not clear `unclaimable`. story-027 states the principle the owner adopted, at `src/PhlimboV3.sol:504-505`: banked amounts *"belong to users, not to `leftoverRecipient`."*

### ⚠ Nuance attaching to V3-L-08 — worth a fresh triage look even though the entry is already open

One detail keeps `withdrawAll` from being a clean mirror of the PhlimboV3 ejector seat, and it is **the genuinely new part of this lens** (dedup recorded it only as an attached note):

- **`PhlimboV3.emergencyTransfer` is TERMINAL** — it ends in `_pause()` (`src/PhlimboV3.sol:341`) and reverts if already paused.
- **`MigratorV2V3.withdrawAll` is explicitly NON-TERMINAL** — `src/MigratorV2V3.sol:314-316`: *"does NOT abort the pass… the seeded list and iterator are untouched and migration can resume."*

**So the migrator can be swept and then keep migrating, with banked users' claims silently unbacked while the pass continues to look healthy.** That resumability is exactly what distinguishes `withdrawAll` from the terminal ejector seat, and therefore **the ejector-seat precedent (story-022 / pe7m2) does NOT automatically cover it** — which is the usual reason a sweep-the-bank finding is set aside. **An existing Low whose rationale has changed deserves a fresh glance**: V3-L-08 should be re-read against this nuance rather than left to sit on its prior reasoning.

### Recommendation

No code change required if the owner affirms the documented trade-off. If closing is preferred, mirror the PhlimboV3 pattern: track a per-token aggregate in `_forward` and reserve it in `withdrawAll` with the same saturating subtraction. **Do NOT propose accounting inside `PhlimboV3.emergencyTransfer`** — the ejector-seat precedent (pe7m2, closed INVALID) governs there.

---

## Positive finding — story-027 does NOT walk into the V3-Q-02 trap, and did not avoid it by accident

*Not a deviation. Recorded explicitly as evidence the process works.*

**V3-Q-02** (ledger `93cdca59`) is retained solely as a warning that *the obvious fix in the banking area strands value the current code preserves* — `pauseWithdraw`'s debt-realignment forfeits **look like** an unbanked entitlement, and "fixing" them into a bank would strand value the sweep currently conserves exactly (`sum(claimable) == emitted`, `claims <= balance` always).

**story-027 draws the line in exactly the right place — and writes the rationale down in-source.** `src/PhlimboV3.sol:501-505` (`finalizePromotion` NatSpec):

> Forfeit-sweep vs bank-retain (audit-08 M-01): `pauseWithdraw` forfeits
> realign the debt with NOTHING banked — those tokens are legitimately
> swept here as leftover. Failed flush transfers, by contrast, are banked
> per-user in `batchClaim` and reserved from this sweep via
> `totalUnclaimableOf`; they belong to users, not to `leftoverRecipient`.

This is the decisive point: the distinction is **recorded as a rationale**, not arrived at by accident. Three independent facts confirm it, each source-verified this run:

1. **The bank has exactly one write site.** `unclaimablePromoOf` / `totalUnclaimableOf` are incremented **only** at `src/PhlimboV3.sol:479-480` — inside `batchClaim`'s failed-`_tryTransfer` branch (`:466-481`). The only other mutation is the decrement in `claimUnclaimablePromo` at `:564-565`. Exhaustively verified by grep across `src/PhlimboV3.sol`; no other write exists.
2. **`pauseWithdraw` touches no bank.** Confirmed — it appears at no bank write site. So the reservation covers exactly the failed-transfer set and no forfeits, and V3-Q-02's conserving accounting is untouched.
3. **The saturating subtraction at `:519` is a second, independent trap-avoidance.** `leftover = balance > banked ? balance - banked : 0` — deliberate, and documented as such at `:507-509`: *"even under accounting drift this function must never revert — stranding some leftover is preferable to pinning the contract in `Flushing` forever."* Even under accounting drift, finalize cannot revert, so the fix **cannot pin the contract in Flushing** — the failure mode the trap warning most feared.

> ### Recommendation: **V3-Q-02 stays RETAINED**
>
> story-027 is **evidence the warning worked, not grounds to close it.** The warning is what the correct line was drawn against; retiring it removes the guard for the next change in this area.

---

## Also record — refuted, and should not be re-raised

Recorded so future runs do not re-litigate settled ground.

1. **`claimUnclaimablePromo`'s attacker-supplied `token` argument — REFUTED.** Checked under Law 1. The mapping is written **only** by `batchClaim` with the real promo token (`src/PhlimboV3.sol:479-480`), so an arbitrary-token argument reads `0` and reverts `"Nothing to claim"` (`:563`). There is no path to drain an unrelated token. The function is additionally self-scoped to `msg.sender`, CEI-ordered (state zeroed at `:564-565` before the transfer), and `nonReentrant`.
2. **The dust off-by-one — REFUTED; the boundary is EXACT.** `migrate` skips on `amount < minStake` (`src/MigratorV2V3.sol:186`) and `PhlimboV3.stake` requires `amount >= MINIMUM_STAKE` (`src/PhlimboV3.sol:644`) — precisely complementary. story-026's claim *"a live position below V3's MINIMUM_STAKE can never be staked into V3"* is **true**, and is **not** weakened by second-pass cumulation: `stake`'s guard tests the **incremental** `amount`, not `userDetails.amount + amount`, so a dust position is unstakeable regardless of the user's existing V3 balance.
3. **The live-bank `emergencyTransfer` sweep itself — NOT a standalone finding.** Deliberate, documented (`src/PhlimboV3.sol:316-323` and `IPhlimboV3.sol:267-270`), owner-gated and terminal. Ejector-seat precedent (story-022 / pe7m2). Its one non-obvious *consequence* — the doc invariant it falsifies plus the phantom reserve — is filed as **F-09-03** against the doc and `finalizePromotion` instead.

### ⚠ `migrateOne` must NOT carry `nonReentrant` — watch-note

> **This is correct as written. Do not "fix" it.**
>
> `migrate` already holds OZ v5's **single shared** ReentrancyGuard lock when it self-calls, so a guarded `migrateOne` would revert `ReentrancyGuardReentrantCall` **into the catch** — producing a per-user skip for **every** user: a silently no-op pass that still emits a clean-looking `migrateIterator == -1` completion. The `"Only self"` gate at `src/MigratorV2V3.sol:236` is the correct substitute.
>
> The contract documents this itself at `src/MigratorV2V3.sol:228-233`:
>
> > MUST NOT carry `nonReentrant`: OZ v5's ReentrancyGuard is a single lock shared across all guarded functions, and `migrate` already holds it when it self-calls — a guarded migrateOne would revert ReentrancyGuardReentrantCall and the catch would silently skip EVERY user. Protected by the "Only self" gate instead.
>
> **Two agents independently confirmed the current code is correct as written.**
>
> **This watch-note must SURVIVE V3-M-04's closure**, because it guards the very fix that closes it.

---

## Reconciliation note — label mapping (read before triage)

The two inputs to this report **disagree on faithfulness labels**. This report uses the story-faithfulness scan's labels (F-09-01…F-09-05); `classified-findings.json` assigns the same four findings an offset set (F-09-05…F-09-08). Mapping, by fingerprint:

| This report | Upstream sanitizer ID | Classifier ID | Classifier label | Fingerprint |
|---|---|---|---|---|
| **F-09-03** (Low) | SAN-09-005 | CLASS-005 | F-09-05 | `9169babe…` |
| **F-09-01** (QA) | SAN-09-006 | CLASS-006 | F-09-06 | `1df7ed85…` |
| **F-09-02** (QA) | SAN-09-007 | CLASS-007 | F-09-07 | `c39652b7…` |
| **F-09-04** (QA) | SAN-09-008 | CLASS-008 | F-09-08 | `aedfcdb0…` |
| *(scan F-09-05)* | *collapsed by dedup* | — | — | **`faa2d9ba…`** → existing ledger Low **V3-L-08** |

**Fingerprints are authoritative; the F-labels are not.** Reconcile against the ledger by fingerprint only.

The scan's fifth faithfulness finding carries **no run-09 F-label**: the deduplicator collapsed it into pre-existing open ledger entry **V3-L-08** (`faa2d9ba`, which already carries faithfulness ref F-08-02 and the stronger PoC). Its absence from `classified-findings.json` is correct — that set holds only NEW findings. It is documented above as a cross-reference, with the non-terminal-sweep nuance attached for triage. Note also that `classified-findings.json` reports the story-027 bank write site as `batchClaim:468-476` and the finalize rationale as `:507-512`; both were re-read at `02b9bc2` and corrected here to **`:479-480`** and **`:501-505`** respectively (`:507-509` is the *saturating-subtraction* rationale, a different clause).
</content>
</invoke>
