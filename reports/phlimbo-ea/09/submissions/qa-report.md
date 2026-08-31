# QA Report for phlimbo-ea (run-09)

**Commit audited**: `02b9bc2`
**Scope**: `src/*.sol` (12 files), PhlimboV3 + MigratorV2V3 focus (stories 024–028)

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| Centralization | 0 |
| QA / Hardening notes | 3 |
| **Total** | **6** |

**No Centralization (C-XX) findings are filed this run.** The owner-privilege faces that
would ordinarily land here (`emergencyTransfer` sweeping a live bank, `setDesiredAPY`,
`setMigrator(0)`) are all *obvious* owner actions and are suppressed under Law 3. The
*non-obvious* consequences of two of them survive as L-02 below and as the triage caveat on
L-01 — filed as footguns against the code and prose that conceal them, not as
"the owner is powerful" findings.

**Routed elsewhere — do not look for them here:**

- The four spec-conformance findings **F-09-01, F-09-02, F-09-03, F-09-04** (SAN-09-005/006/007/008)
  are Law-2 story deviations and are filed in the **separate spec-conformance report** at
  honest severity. They are cross-referenced below where they bear on a QA item, but they are
  deliberately **not duplicated** into this bundle.
  > **Label caution:** `classified-findings.json` labels these same four findings **F-09-05…F-09-08**
  > (an offset set). The spec-conformance report's F-09-01…F-09-04 labels are the ones used
  > here and there. **Fingerprints are authoritative; the F-labels are not** — reconcile
  > against the ledger by fingerprint only. See that report's *Reconciliation note — label
  > mapping*.
- The two Mediums (SAN-09-001 `PhlimboV3._claimRewards` self-service blocklist freeze;
  SAN-09-002 `pauseWithdraw` stale-rate unbacked over-mint) are individual H/M submissions.

---

## Low Risk Findings

### [L-01] Reverting `rewardToken.safeTransfer` on `PhlimboV2`'s self-service path freezes staker principal <!-- id: pe9l1 -->

**Location**: [`src/PhlimboV2.sol#L500`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/PhlimboV2.sol#L500) (`_claimRewards`, :486–507)

**Description**: `_claimRewards` transfers the pending stable reward at `:500` before the
caller's principal is moved. If `rewardToken` is a token that **reverts on a blocked
recipient**, the transfer reverts and takes the entire `withdraw` with it. Every self-service
path into the position routes through `_claimRewards` (`:337`, `:373`, `:424`), so a
blocklisted V2 staker has no self-service access to their own phUSD principal.

**Which token exhibits this — stated precisely, because the two obvious candidates differ:**

| Token | Blocklist check | Reaches this bug? |
|---|---|---|
| **USDC** (`FiatTokenV2_2.transfer`) | `notBlacklisted(msg.sender)` **and** `notBlacklisted(to)` | **Yes** — recipient-side check reverts the transfer at `:500`. |
| **USDT** (`TetherToken.transfer`) | `require(!isBlackListed[msg.sender])` — **sender-side only** | **No** — a blacklisted USDT address can still *receive*. USDT does not trigger this at all. |

So this finding is **USDC-specific** (and applies to any other reward token with a
recipient-side revert). It is a **reverting blocklist**, not a fee-on-transfer token; the
dropped L-04 fee-on-transfer precedent does not reach it.

The project's own `MockBlocklistToken` (`test/Mocks.sol:105`) enforces
`require(!blocked[to], "recipient blocked")` in `_update` — a **recipient-side** revert. It
therefore models **USDC faithfully** and is the appropriate mock for these paths, which is what
makes this finding's PoC credible. (Its docblock misattributes that mechanism to USDT; the mock
itself is correct and must not be changed — filed separately as **Q-03**.)

No attacker and no owner error is required — the trigger is a third party (the token issuer)
acting for reasons unrelated to this protocol.

**Why Low, not Medium**: the defect is real (PoC 3/3) but **neutralized in the current
wiring**. [`MigratorV2V3.sol#L250`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/MigratorV2V3.sol#L250)
calls `phlimboV2.withdraw(amount, user)` — the **migrator** is `msg.sender` and therefore the
beneficiary, so the blocked user is never the transfer recipient. Principal reaches V3 intact
and the rewards leg banks via `_forward`/`_tryTransfer`. The already-running migration carries
affected stakers out automatically, with no special owner action.

**Migration does not dissolve the class — it relocates it.** `migrateOne` re-stakes via
[`phlimboV3.stake(amount, user)`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/MigratorV2V3.sol#L256)
(`:256`), so a cured V2 staker lands as a **V3 staker holding the same blocklisted reward
token** — i.e. squarely inside SAN-09-001, the V3 Medium. That is the honest reason Low is safe
here rather than a suppression: the exposure does not disappear at migration, it moves to a
contract where it is **already reported at Medium**. Nothing hides in the gap.

This is the **sibling** of that V3 Medium — same root-cause class, different contract,
different fingerprint. V2 has only the stable leg (no promo leg). On V3 the blocklisted staker
has zero recourse; on V2 they are carried out by a live, automatic cure. That difference is the
entire severity split.

> **BLOCKING triage caveat — the rescue and the cure are the same event.**
> The Low rests on the migrator routing, which is **designed to be removed**. When migration
> completes and the owner calls `setMigrator(0)`, the rescue disappears at the same moment the
> cure does. **Do not close this finding on "migration will cure it."**
>
> **At `setMigrator(0)`, if any blocklisted V2 staker remains, L-01 becomes M-01-equivalent
> (Medium).** Re-triage at migration completion; do not close.
>
> For the record, since it is easy to get wrong: V2's `pauseWithdraw` (`:280`) **does not call
> `_claimRewards` at all** — it claims no rewards and updates no pool (its own docblock at
> `:277-278` says so). It is a clean escape precisely because it never reaches `:500`.

**Recommendation**: Before `setMigrator(0)`, confirm no remaining V2 staker is blocklisted on
`rewardToken`; if any is, the residual exposure re-weighs toward the V3 Medium's severity and
this finding should be **re-triaged at migration completion, not closed**. The structural fix
is the `_tryTransfer` + per-user bank pattern the owner already wrote for story-027 on V3 —
V2 would need its own instance.

> **Ledger reconciliation — read before concluding L-01 rests on a live brick.**
> L-01's Low depends on the migrator's `_forward`/`_tryTransfer` bank being intact. Ledger
> entry **V3-M-01** — the same blocklist class, on the migrator — is still carried as
> **`fix-pending`**, which could be misread as "the rescue L-01 leans on is itself broken."
> It is not. **Run-09 verified story-025's fix as COMPLETE at HEAD** (code-scanner review plus
> Tier-3 PoC replay): the banking rescue **is intact in code**. What is unapplied is the
> **ledger status**, not the fix. `fix-pending` is human-set and never auto-closed, so the
> stale status is expected and correct process — it just must not be read as a live defect
> under L-01.

---

### [L-02] Re-promoting a retired token silently re-arms `emergencyTransfer` over its outstanding bank <!-- id: pe9l2 -->

**Location**: [`src/PhlimboV3.sol#L354`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/PhlimboV3.sol#L354) (`startPromotion`); docblock at [`#L322-323`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/PhlimboV3.sol#L322-L323)

**Description**: The `emergencyTransfer` docblock states **unconditionally**:

> *"A RETIRED token's bank (`promoToken == address(0)` for it) is unreachable here and stays
> pullable via `claimUnclaimablePromo`."*

That guarantee holds only while the token stays retired. `startPromotion` (`:354`) does not
reject a token that still has an outstanding balance in `unclaimablePromoOf` /
`totalUnclaimableOf`. A routine second campaign with the same partner token makes it the live
`promoToken` again, so `emergencyTransfer`'s `address(promoToken) != address(0)` carve-out
(`:334`) no longer excludes it — the sweep is silently re-armed over the **old** bank, and an
owner sweeping while trusting the docblock destroys users' banked entitlements.

The on-chain accounting itself is **correct** — the double-spend concern this grew out of is
refuted outright (PoC `test_C2`): `startPromotion` assigns `promoRewardBalance = amount` at
`:369` and never adopts the old bank as distributable, `finalizePromotion` reserves cumulative
`totalUnclaimableOf` at `:517`, and debt alignment at `:468` starts new pendings at zero. What
survives is a documentation footgun with a narrow trigger and no automatic loss.

**Law 3**: in scope as a footgun. This is *not* the "malicious owner sweeps a live bank" face —
that obvious face was suppressed upstream (DROP-09-06) and is not re-filed. This is the
non-obvious consequence a truthful-*looking* docblock actively conceals. A competent,
non-malicious owner running a repeat campaign would not expect it to re-arm a sweep over a
retired bank. Surprise ⇒ footgun.

**Recommendation** (one on-chain fix, two docs):

```solidity
// startPromotion, after the token validity checks:
require(totalUnclaimableOf[token] == 0, "Outstanding bank for token");
```

Then either require the bank be drained before re-use, or reconcile the bank lifecycle so a
re-promoted token's old bank stays excluded from the sweep. Separately, qualify the `:322-323`
docblock: the carve-out holds **only while the token is not re-promoted**.

> **Triage efficiency — do not pay twice.** The **same** `startPromotion` bank-lifecycle fix
> closes both this finding's on-chain leg and that of its faithfulness twin **F-09-03**
> (SAN-09-005, in the spec-conformance report). The two findings are kept distinct
> deliberately — different trigger orders (retire-then-re-promote here; sweep-then-re-use
> there), different falsified docs (`:322-323` here; `SolvencyDetermination.md` §4 there),
> different victims (a user loses a banked entitlement here; the protocol strands leftover
> there) — but the **code change is one**. The two documentation fixes remain separate and
> both are owed.

> **Not a duplicate of ledger entry V3-Q-03** (`f82f04fe`): that is a retired token *missed* by
> a sweep on `MigratorV2V3`; this is a retired bank *wrongly caught* by a sweep on `PhlimboV3`.
> Inverse defects on different contracts.
>
> **Label collision — do not conflate.** Ledger **V3-Q-03** (`f82f04fe`, above) and this run's
> new **Q-03** (`pe9q3`, the `MockBlocklistToken` docblock) are unrelated findings that happen
> to share a label across numbering spaces. Reconcile by fingerprint / issue ID, never by label.

---

### [L-03] `batchClaim` lacks the containment the byte-identical migrator path has — a revert inside the loop permanently pins the rotation <!-- id: pe9l3 -->

**Location**: [`src/PhlimboV3.sol#L450-487`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/PhlimboV3.sol#L450-L487) (`batchClaim`); helper at [`#L885-887`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/PhlimboV3.sol#L885-L887)

**Description**: `batchClaim` already handles a *failing* transfer well — `_tryTransfer`
(`:471`) returns false and the entitlement banks at `:479-480`. The gap is one level up: a
revert **inside `_tryTransfer` itself** is not contained. `_tryTransfer` is an internal call,
so its `abi.decode(returndata, (bool))` at `:887` reverts straight through the loop and aborts
the whole `batchClaim`.

The **identical helper** exists on `MigratorV2V3` (`:350`), where it is **fail-safe**: it runs
inside `migrateOne`, which the `migrate` loop invokes through a `try`/`catch` (`:202-204`), and
the owner has `skipCurrent` (`:284`) as a backstop for a stall the try/catch cannot absorb.
`batchClaim` has **neither**. The consequence is that `flushCursor` never advances past the
reverting staker, and `finalizePromotion` can never satisfy its
`require(flushCursor == _stakers.length(), "Flush incomplete")` gate at `:513`. The rotation
cannot complete. `abortFlush` (`:539`) unpins the contract but not the rotation.

**Why Low, not Medium**: "permanent rotation DoS" reads as an availability Medium and was
tested as one. It fails on **reachability**. Every statement in the loop was enumerated and
there is **exactly one** revert vector today — the `abi.decode` at `:887`, which *is* V3-L-02's
already-tracked defect, and which additionally needs an owner-selected promo token returning
malformed returndata. This finding therefore contributes no new reachable path today, and a
Medium resting on a vector already tracked at Low elsewhere would overstate.

**Honest caveat, stated rather than hidden**: the two are **reachability-coupled** today. What
survives independently is the **structural containment gap** — it persists for any *future*
revert vector introduced into the loop, and the migrator's own design shows the owner already
treats that backstop as necessary. No assets are at risk either way: banked entitlements
remain pullable via `claimUnclaimablePromo`.

**Recommendation**: give the flush the containment the migrator already has — wrap the per-user
body in an externally-callable self-call under `try`/`catch`, and/or add an owner
`skipCursor(uint256)` backstop mirroring `MigratorV2V3.skipCurrent`. Hardening `_tryTransfer`
against malformed returndata (`returndata.length == 0 || (returndata.length == 32 && abi.decode(...))`)
closes today's only vector but not the structural gap.

> If triage judges the structural gap not worth its own entry, **merge it into V3-L-02 as an
> aspect — do not drop it** (FLAG-09-04).

> **Absorbed fact** (shared with F-09-03; one fact, two findings citing it, no duplication):
> `emergencyTransfer` (`:325-342`) ends with `_pause()` at `:342`, and OZ's `_pause()` carries
> `whenNotPaused` — so `emergencyTransfer` **reverts while already paused**, including
> throughout the `Flushing` window, removing the stated last-resort exit. Correct sequence:
> `abortFlush` → `unpause` → `emergencyTransfer`.

---

## Centralization Risks

None filed this run. See the note under **Summary** for why, and L-02 / L-01's triage caveat
for the non-obvious owner-action consequences that were kept.

---

## QA / Hardening Notes

### [Q-01] `finalizePromotion` has no `nonReentrant`, so the contract-wide lock is never held across its external transfer <!-- id: pe9q1 -->

**Location**: [`src/PhlimboV3.sol#L511`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/PhlimboV3.sol#L511) (`finalizePromotion`); transfer at [`#L521`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/src/PhlimboV3.sol#L521)

> **This is a hardening note, not a finding. MR-09-005 was REFUTED as a vulnerability** — the
> full reachable set was enumerated and every member is harmless. It is recorded here because
> the protection is *incidental*, and incidental protection is worth one line to make
> deliberate.

**Description**: `finalizePromotion` (`:511`) carries `onlyOwner` but **no `nonReentrant`**.
Line `:521` is a real `retiredToken.safeTransfer(leftoverRecipient, leftover)` — an external
call to an owner-selected partner token — and it is followed by four state writes
(`promoToken`, `promoRewardPerSecond`, `promoRewardBalance`, `promoPhase`) at `:524-529`.
Because the modifier is absent, OpenZeppelin's contract-wide reentrancy lock is **never
acquired**, so *every* `nonReentrant` function in the contract (including `batchClaim` at
`:450`) is re-enterable from `:521` while `promoPhase` is still `Flushing` and the promo slot
is still populated.

**Why this is not a finding**: the reachable set is harmless, protected by four independent
gates — `beginFlush`'s `_pause()` at `:433`, the `:281` unpause bar ("Cannot unpause while
flushing"), `:513`'s `flushCursor == _stakers.length()` requirement, and `:824`'s phase gate.

**Why it is still worth a line**: none of those gates was placed to stop reentrancy. The
safety is a **coincidence of the pause lifecycle**, and it is one refactor away from not being
true. Note specifically that it does **not** rest on a no-ERC777/no-callback-token trust
assumption — which matters, because that assumption is exactly the one an owner could
unknowingly violate by choosing a callback-bearing promo token for a campaign. A one-line
modifier is cheaper than the standing watch-note this otherwise needs.

**Recommendation**:

```solidity
function finalizePromotion(address leftoverRecipient) external onlyOwner nonReentrant {
```

> **Do not collapse.** `finalizePromotion`'s missing `nonReentrant` and MR-09-001's missing
> `nonReentrant` on `pauseWithdraw` are distinct sites. Separately, `PhlimboV3.pauseWithdraw`
> now carries **three distinct root causes** (SAN-09-002's stale emission rate, V3-Q-02's
> accounting scope, MR-09-001's missing modifier) — a future run must not fold them together.

---

### [Q-02] No stateful invariant or fuzz suite covers the promo state machine; the failure-path bank is unit-tested only <!-- id: pe9q2 -->

**Location**: `test/` (7 tracked `.sol` files at `02b9bc2`)

> **Scope correction (in the project's favour).** An earlier scoping of this item alleged the
> project's own invariant harness passes vacuously, and recommended it adopt
> `MockBlocklistToken`. Both were wrong: no `test/invariant/` directory exists in the project
> (the vacuous harness was **our own** Tier-3 artifact), and the project **already has**
> `MockBlocklistToken` (`test/Mocks.sol:105`) plus `MockPausableToken` (`:131`) and
> `MockFalseReturnToken` (`:156`).
>
> **The project's unit coverage of `batchClaim`'s failure path is good** — `PhlimboV3Test.t.sol`
> exercises the `PromoClaimFailed` emission (`:1663`), the `unclaimablePromoOf` /
> `totalUnclaimableOf` writes (`:1669-1670`), bank-survives-rotation (`:1682-1683`),
> `claimUnclaimablePromo` making a user whole after unblocking (`:1712`), and partial-drain
> accounting (`:1785`). Only the narrower item below is a genuine project finding.

**What actually survives, as a genuine QA item**: the project tracks **zero stateful invariant
or fuzz tests** (`git ls-files | grep -i invariant` matches only forge-std's `StdInvariant.sol`;
the single `invariant_` string in `test/` is the unit-test name
`test_settleDebt_invariant_across_chunks`). The bank paths are covered by **hand-written unit
tests at fixed sequences only**. The promo state machine — `None → Active → Flushing → None`
across rotations, top-ups and aborts, intermixed with ordinary `stake`/`withdraw`/`claim`/
`collectReward` and time advance — is never explored by a solver. That matters concretely
here: this run's two Mediums are both **sequence-dependent** state defects that no fixed-sequence
unit test would surface, and one of them (SAN-09-002) was **independently caught by a stateful
invariant** (`invariant_phUSDRate_tracks_totalStaked`) which broke on its first run with a
3-call shrunk counterexample at 4.83× stale.

**Recommendation**: adopt a stateful invariant suite over the promo lifecycle and assert the
conservation identity `promoFunded == promoPaidOut + partnerToken.balanceOf(v3)` plus the
§4 solvency invariants. The mocks needed already exist — but **seed the promo token with
`MockBlocklistToken`, not `MockStable`**, or the bank invariants assert `0 == 0` over an empty
bank.

> **Why the tripwire is not optional**: this exact trap caught *this audit's own* first promo
> harness — `MockStable` as the promo token meant `_tryTransfer` (`:471`) never returned false,
> `unclaimablePromoOf` / `totalUnclaimableOf` (`:479-480`) were never written, and six bank
> invariants passed green over an empty bank. The failure mode is **silent by construction**,
> which is why the seeding choice and the abort-on-empty assertion belong in the suite itself.
>
> Cross-reference **F-09-04** (spec-conformance report): the absence of a Known Issues section
> and of any V3 coverage in `CLAUDE.md` is the documentation-side twin of this test-side gap.

---

### [Q-03] `MockBlocklistToken`'s docblock misattributes its own mechanism to USDT; the mock is correct and must not be "fixed" to match it <!-- id: pe9q3 -->

**Location**: [`test/Mocks.sol#L97-98`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/test/Mocks.sol#L97-L98) (docblock); implementation at [`#L105`](https://github.com/Behodler/phlimbo-ea/blob/02b9bc2/test/Mocks.sol#L105)

**Severity**: QA / informational — **the code is correct today**; nothing is at risk. This does
not rise to Low.

**Description**: `MockBlocklistToken`'s docblock describes it as:

> *"ERC20 with a **USDT-style** recipient blocklist. Transfers to a blocked address revert…"*

The implementation is a **recipient**-side blocklist — `require(!blocked[to], "recipient blocked")`
in `_update` (`:105`) — which is correct for the paths it was written to cover. But
**"USDT-style" is the wrong attribution**:

| Token | Actual check in `transfer` | Matches this mock? |
|---|---|---|
| **USDC** (`FiatTokenV2_2`) | `notBlacklisted(msg.sender)` **and** `notBlacklisted(to)` | **Yes** — recipient-side. |
| **USDT** (`TetherToken`) | `require(!isBlackListed[msg.sender])` — **sender-side only** | **No** — a blacklisted USDT address can still *receive*. |

The mock models **USDC**. Its comment names the one major blocklisting token whose semantics it
does *not* implement.

### ⚠ TRAP WARNING — FIX THE PROSE, NEVER THE MOCK

> A developer reconciling this mock against its own docblock would flip the check to
> **sender**-side (`require(!blocked[from])`) to make it genuinely "USDT-style". That would
> **silently stop covering the recipient-blocklist path the mock exists to test** — `_tryTransfer`
> (`PhlimboV3.sol:471`) would never fail, the bank at `:479-480` would never be written, and the
> failure-path tests would pass **vacuously** while asserting nothing. Every test stays green.
>
> This is the same shape as **F-09-01**'s do-not-invert-the-code trap: wrong prose over correct
> code, where "correcting" the code to match is the harmful move. **The mock is right. The
> comment is wrong.**

**Why this is worth an entry rather than a comment nit — the cost has already been paid once.**
This misattribution **propagated out of the test suite and into this run's submissions**. Both
the M-01 write-up and this QA report initially inherited it, stating *"USDC and USDT both revert
on a blocked recipient"* — and **M-01's primary C4 validity defense was very nearly argued on
the USDT weird-ERC20 carve-out**, i.e. on the one token that does not exhibit the behaviour at
all. A reviewer checking `TetherToken` would have refuted the defense in one step, on a finding
that is entirely valid on USDC. It was caught only at final review. A wrong comment on correct
code is not inert: it is load-bearing documentation for anyone reasoning about *which* real
token the covered path corresponds to.

**Recommendation**:

```solidity
// test/Mocks.sol:97 — retitle only. Do NOT touch the _update check at :105.
 * @notice ERC20 with a USDC-style recipient blocklist. Transfers to a blocked
 *         address revert — used to verify the non-reverting transfer paths:
```

USDC's `FiatTokenV2_2.transfer` carries `notBlacklisted(to)`, which is exactly what `:105`
implements. If genuine **USDT** coverage is also wanted, that is a **separate, additional** mock
modelling sender-side blocking — **not** a change to this one. (Note that a sender-side-blocked
protocol contract is a materially different scenario: it would block the contract's *outgoing*
transfers wholesale, not one user's receipt.)

---

## Carryover — referenced, not re-reported

**V3-L-01 (Linear-Depletion runway re-anchor)** now has a PoC and **stays Low**. The griefer's
marginal impact over the honest daily funding cadence is only **2.68pp**, and the stranded
balance drains to 1 wei by `t = 2D` — funds are **re-timed, not lost**. Recorded so the PoC's
existence is not mistaken for an escalation trigger in a future run.

---

## Tooling Gaps and Coverage Limitations

Recorded honestly per Law 1: a silent tool is not an all-clear. Three gaps materially affect
what this run's automated layer could have found.

| Gap | Effect | Status |
|---|---|---|
| **Slither `--filter-paths "lib/"` returns a false clean** | The submodule's absolute path `/home/justin/code/audits/lib/phlimbo-ea` **itself contains `lib/`**, so the filter excluded **every first-party file** and Slither reported **0 results over nothing**. A 0-result Slither run on this repo layout is meaningless. | **Must anchor to `phlimbo-ea/lib/`.** Any prior run reporting "Slither clean" on this project should be treated as unverified. |
| **Semgrep has no Solidity security ruleset** | `p/security-audit` and `p/solidity` both return **0 results over Solidity files** — the free registry carries no Solidity security rules. Semgrep's 161 findings on this project are **all INFO-level gas/style lint**. | **Semgrep silence is a coverage gap, not an all-clear.** Do not cite it as corroboration. |
| **SAST coverage was `src`-only (12 files)** | The **7 `test/*.sol` files were analyzed by no tool** — including `Mocks.sol`, on which the correctness of every failure-path unit test depends (see Q-02). | Open. Test-code defects would not have been caught by the automated layer this run. |

**4naly3er**: **ran successfully** after the known foundry.toml-only remapping gap was worked
around (see appendix). Output attached in full.

---

## Appendix — Automated Report (4naly3er)

Full output: [`4naly3er-report.md`](./4naly3er-report.md) (4,802 lines, 12 files in scope).
Exact remappings used: [`4naly3er-remappings-used.txt`](./4naly3er-remappings-used.txt).

**How it was made to run** (the established workaround, plus one project-specific addition):
`phlimbo-ea` *does* ship a `remappings.txt`, but its paths are **project-root-relative**
(`@openzeppelin/=lib/openzeppelin-contracts/`), which 4naly3er resolves against its own cwd
and not the submodule. A `remappings.txt` + `src` symlink were staged in the scratchpad with
**absolute** submodule paths. That alone was still insufficient: `PhlimboV3.sol`,
`MigratorV2V3.sol` and `PhlimboV2.sol` import `IPausable` by a **literal project-root-relative
path** —

```solidity
import {IPausable} from "lib/mutable/pauser/src/interfaces/IPausable.sol";
```

— which foundry resolves against the project root but 4naly3er does not. Adding an explicit
`lib/mutable/pauser/=<abs>/lib/mutable/pauser/` prefix remapping resolved it. **No gap
remains; the report below is complete for `src/`.**

### 4naly3er summary

| Class | Distinct issues | Instances |
|---|---:|---:|
| Gas Optimizations | 18 | 559 |
| Non-Critical | 22 | 415 |
| Low | 12 | 165 |
| Medium (bot-tier) | 3 | 53 |

**Reader's guidance — these are bot-tier signals, not audit findings.** They are attached as
the C4 QA/gas baseline and are deliberately **not** promoted into the Low section above. Three
warrant a note so triage does not mis-read them:

- **[M-3] "Centralization Risk for trusted owners" (37 instances)** — suppressed wholesale under
  Law 3. This is the automated tool restating that `onlyOwner` functions exist. It is not
  evidence of the C-XX section's emptiness being an oversight.
- **[M-1] "Vulnerable to fee-on-transfer accounting" (7 instances)** — a **false positive
  here**: `startPromotion` carries an explicit balance-delta guard at `:368`
  (`require(... - balanceBefore == amount, "Fee-on-transfer not supported")`), and
  fee-on-transfer tokens are rejected by policy. Do not confuse this with L-01/L-02's
  **reverting blocklist** mechanism, which is a different defect class entirely.
- **[L-2] "Some tokens may revert when zero value transfers are made" (34 instances)** —
  adjacent to but **not** L-01: the reward legs are all guarded by `if (pending > 0)`, so the
  zero-value case does not arise on the paths L-01 covers.
