# Spec Conformance (Law 2) — stable-staker run 17

**Project:** stable-staker · **Commit audited:** `96d39ed` · **Baseline:** `fa06de5` · **Branch:** `master`
**Story under review:** `[story-025]` — *Force Annihilation on Claim: Gate `claim()` Behind an Owner Flag and Add `autoAnnihilate()`*
**Story document:** `/home/justin/code/product-owner/stories/stable-staker/auto-complete/stable-staker-auto-annihilate/025-force-annihilation-on-claim.md`
**Declared known-issues source:** `lib/stable-staker/CLAUDE.md` (520 lines at HEAD) — see `reports/stable-staker/17/known-issues-96d39ed.md`

This report covers Law 2 (faithfulness to stories) only. It is deliberately **not** part of the QA
bundle: these are deviations between what the specification says the code does and what the code
does, not gas or style observations. Two of the six also carry security-adjacent or operational
consequence and appear in their own report as well; the cross-references are named per section and
summarised at the end.

---

## 0. Process signal — read this before the individual items

**Six independent deviations from a single story is itself the finding.** No one of them is a High
or a Medium; the density is the observation, and it is a statement about how this story reached
`main`, not about any one line of code.

The provenance, stated plainly and without inference:

- **Story-025 sits in `auto-complete`.** Its completion stamp reads, verbatim:

  > **Approved by**: story-batch workflow (machine approval — not human-reviewed)
  > **Review Status acted on**: ISSUES_FOUND
  > **Triage verdict**: non-blocking

  The approval acted on a `Review Status` of `ISSUES_FOUND` that the workflow had itself produced,
  and the triage verdict that reclassified those issues as non-blocking was, by the stamp's own
  admission, "supplied by the driver and was not re-evaluated by this skill".

- **Round 2 was rejected outright by its own reviewer**, with a blocking `[high]`:

  > **Result**: FAILED (blocking) — fix-forward revision, attempt 2.
  > **[high] Shortfall floor is an unachievable exact equality against a real ERC4626 vault**

  Round 3 is the fix-forward against that rejection.

- **Every round ran `--inline-delegation` with a self-declared reduction in independence.** Each of
  the six delegation blocks in the story carries:

  > **Mode**: --inline-delegation (workflow nesting limit)
  > **Independence**: reduced

  For rounds 1 and 2 and the polish pass this reads "reduced — these verdicts were reached by the
  agent that also performed the work"; for the round-3 review, "reduced — these five verdicts were
  reached by one agent rather than five separately-spawned ones".

The consequence for this audit is bounded and specific: the story's own assertions cannot be
treated as reviewed statements of intent, so every claim in it was re-derived from the code. Five
of the six items below are cases where doing that produced a different answer than the document
gives. The sixth (F-06) is the reviewer's own blocking finding, only partly discharged.

---

## F-01 — The Auditor Note's stated ground for accepting the raw-mint loophole is factually false, and `autoAnnihilate` is not "the only reward path"

**Severity:** Low (adjudicated, not deferred) · **Law-3 footgun: yes** · **Load-bearing item of this report.**
**Code:** `lib/stable-staker/src/StableStakerV2.sol:419`, `:540`, `:596`, `:604-605`
**Spec:** story-025 lines 15-16 (Story Overview) and lines 194-214 (Auditor Note); mirrored into
`lib/stable-staker/CLAUDE.md:184-203` as known issue **N24**.

### What the spec says

Story Overview, verbatim (story-025:15-16):

> So: `claim()` becomes owner-gated and is **off by default**, and a new `autoAnnihilate()` becomes
> the only reward path.

Auditor Note — Annihilation Exceeding Principal, verbatim (story-025:203-211), on why the raw-mint
escape valve is acceptable:

> This is a knowing, documented loophole around the disabled `claim()`. We accept it because:
>
> - The alternative — reverting — strands a user whose rewards have outgrown their stake, with no path
>   to their own accrued value. That is a far worse failure than a leak in a temporary teaching gate.
> - The condition requires reward accrual to exceed staked principal, which at realistic emission
>   rates takes a long time relative to how long the gate is intended to stay closed.
> - `claimEnabled` is expected to be flipped on within weeks. The gate is pedagogy, not a security
>   boundary, and should never be relied upon as one.

### What the code does

The second bullet is the acceptance rationale, and it is false. It reasons **only** about the
numerator — reward accrual organically outgrowing principal — and never about a caller **shrinking
the denominator** to meet the backlog. Since story-022, `withdraw` does not pay settled reward; it
books it:

- `withdraw` carries no `claimEnabled` gate (`StableStakerV2.sol:400-405`) and settles the entire
  pending reward into the backlog mapping while zeroing the position:

  ```solidity
  // StableStakerV2.sol:411-419
  uint256 pending = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION - user.rewardDebt;
  user.amount -= amount;
  ...
  if (pending > 0) {
      unclaimedReward[token][msg.sender] += pending;
  }
  ```

- `autoAnnihilate` then computes `principalAsAntimatter = user.amount * scale` at `:540`. With
  `user.amount == 0` the cap is zero, `netWanted` is zero, the annihilate block at `:598-603` is
  skipped entirely, and `excessBase` is the whole backlog, delivered raw at `:604-605`:

  ```solidity
  // StableStakerV2.sol:604-605
  if (excess > 0) {
      antimatter.mint(msg.sender, excess);
  }
  ```

The "condition [that] requires reward accrual to exceed staked principal" is therefore reached by
**one ordinary transaction**, at any reward-to-principal ratio, permissionlessly and with no
capital, MEV, race or special configuration — while `claim()` is simultaneously reverting
`"StableStaker: claim disabled"`. A partial withdraw tunes exactly how much is taken raw.

The Story Overview claim is separately false, and the contract's own NatSpec says so at
`StableStakerV2.sol:431-433`:

> /// @dev CLOSED BY DEFAULT since story 025 — see {claimEnabled}. It is no longer the only
> ///      user-facing path that mints: {autoAnnihilate} mints too (to this contract, and to the
> ///      caller for any excess over their principal) …

A third minting path also exists: the terminal-migration exit at `StableStakerV2.sol:845-850` is
deliberately ungated by `claimEnabled` and mints `owed` raw.

### Impact and standing

Conservation is exact and was measured, not assumed: the bypass pays a staker precisely what
`claim()` would have paid and not one wei more (INV-1/INV-2 PASS, zero overshoot over the emission
ceiling across ~943k calls; deterministic replay delivered 10000 bps of entitlement). No asset is at
risk, nothing is diluted, nothing is created. What is defeated is a pedagogical throttle that
`CLAUDE.md:184-203` itself declines to treat as a boundary. That is the honest Low.

What the Low must not swallow is the **falsified rationale**. Under the standing rule that
falsely-exhaustive documentation raises rather than lowers severity, this is the one item in the run
that must be read rather than skimmed: the owner will size the teaching phase, and the rate at which
raw Antimatter enters circulation, against a bound that does not exist.

### Law-3 footgun — safe-config guidance

Surprise test: **PASS**. A competent, non-malicious owner reading the Auditor Note believes the
raw-mint path is rate-limited by an emission-vs-principal race and therefore negligible over a
weeks-long gate. It is not rate-limited at all.

- **Treat `claimEnabled` as delivering ZERO throttle from day one.** Do not size the teaching phase,
  or any downstream expectation about circulating Antimatter, on the assumption that the gate slows
  delivery.
- If a real throttle is wanted, gate the `:605` raw-mint leg on the same flag — accepting that this
  re-strands the `owed > principal` user the Note was written to protect.
- Otherwise, keep the behaviour and **correct the documented bound** in both story-025 and
  `CLAUDE.md:184-203`.
- Note the asymmetry, and do not treat it as a mitigation: during a pause of the *foreign* Antimatter
  contract the ordinary path is dead (`annihilate` is `whenNotPaused`) but this bypass still works,
  because the zero-principal path skips the annihilate block and `antimatter.mint` is not
  `whenNotPaused`. A staker who knows the trick is unaffected; one who does not is locked out.

**Also reported as:** a Low in `qa-report.md` (source finding `CLASS-001`), cross-referenced there as
F-01. Flagged for human review: a reader who disagrees with the owner's non-reliance disclaimer —
for instance if any phUSD-backing assumption turns out to depend on the teaching phase after all —
should re-weigh it to Medium, and this classification must not stand in the way of that.

---

## F-02 — `CLAUDE.md`'s headline states the NET debit that round 2 identified as the underflow bug; the code debits the GROSS

**Severity:** QA · **Documentation defect in the declared known-issues source.**
**Code:** `lib/stable-staker/src/StableStakerV2.sol:565-566`
**Spec:** `lib/stable-staker/CLAUDE.md:89-94` (headline), contradicted by `CLAUDE.md:119-122` (bullet)

### What the spec says

`CLAUDE.md`, section "The claim gate and `autoAnnihilate` (story 025)", the first paragraph a reader
meets, verbatim (`CLAUDE.md:89-93`):

> While it is down, `autoAnnihilate(address token, uint256 minPhUSDOut)` is the reward path:
> it mints the caller's owed Antimatter to the staker itself, annihilates it against a slice of
> the caller's **own booked principal**, decrements `userInfo.amount` and `poolInfo.totalStaked`
> **by the stable half**, and Antimatter mints the resulting phUSD straight to the caller.

### What the code does

`StableStakerV2.sol:565-566` debits the **gross**:

```solidity
user.amount -= gross;
pool.totalStaked -= gross;
```

The net-based debit the headline describes is precisely the defect story-025's own round-2 reopen
identified, verbatim (story-025:689-691):

> 2. Cap the **GROSS** figure at the caller's own principal (`user.amount`) — **not** the net figure.
>    The current cap is `principalAsAntimatter = user.amount * scale`; if the cap stays on the net
>    amount then `user.amount -= stableNeeded` underflows for exactly the user annihilating their
>    whole position.

A later bullet in the *same* `CLAUDE.md` section states the correct semantics (`CLAUDE.md:119-122`):

> …caps that **gross** (never the net) at the caller's own `user.amount`, and debits `user.amount`
> and `pool.totalStaked` by it.

So the document contradicts itself about the function under review, and the superseded — and
known-buggy — version is the one it presents first. The paragraph was added in `afa7b80` (round 1)
and left uncorrected by `57eb02d` (round 2) and `a961e10` (round 3).

### Impact

None behavioural: the code is correct. It is retained and routed here rather than dropped for two
reasons that outrank its severity. First, the defect is in the **declared known-issues source
itself** — a document that contradicts itself about the function under review lowers confidence in
every suppression later extracted from that section, and that must be carried into the next run's
extraction note. Second, this is the **second** "CLAUDE.md documents a superseded model" entry on
this project (after `ss9f3-clau`, still open), which makes it a pattern rather than a typo.

**Also reported as:** a QA item in `qa-report.md` (source finding `CLASS-009`), cross-referenced there
as F-02.

---

## F-03 — `autoAnnihilateAvailable` returns `true` in exactly the state where `autoAnnihilate` reverts, inverting Decision 4's own rationale

**Severity:** Low
**Code:** `lib/stable-staker/src/StableStakerV2.sol:1051-1068` (the view; early return at `:1057-1060`), revert at `:557`
**Spec:** story-025 lines 827-842, "## Autonomous Decisions — Round 2", Decision 4

### What the spec says

Decision 4's rationale, verbatim (story-025:836-840):

> - **Rationale**: The checklist asks the view to stay consistent with what the call will do, and
>   refusing is strictly better than handing out raw Antimatter. The probe is skipped when the
>   strategy custodies nothing for the pool, because then there is no principal to annihilate
>   against and the reward-outran-principal path still legitimately works — reporting `false` there
>   would be the inconsistent answer.

### What the code does

The view early-returns `true` whenever the strategy custodies nothing:

```solidity
// StableStakerV2.sol:1057-1060
IYieldStrategy strategy = yieldStrategy[token];
if (address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0) {
    return true;
}
```

But a staker can hold `user.amount > 0` in exactly that state — principal left idle after a
buffer-path `relinquishPrincipal`, or a strategy set before deposits routed into it. Both
`previewExitFor` implementations cap `grossToRequest` at the strategy's per-client ledger
(`lib/reflax-yield-vault/src/AYieldStrategy.sol:579-581`,
`lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:181-184`), so
`grossQuote == 0` and the real call reverts at `StableStakerV2.sol:557`:

```solidity
require(netWanted == 0 || grossQuote > 0, "StableStaker: exit unavailable");
```

Decision 4 argued that `false` would be the inconsistent answer. The code makes `true` the
inconsistent one — a green button on a pool where every call reverts, which is the exact failure
mode Decision 4 exists to prevent.

A second, independent inaccuracy sits in the same view: the 1-unit probe at `:1061-1062` is
near-vacuous. For the direct strategy, `previewExitFor(1)` returns `min(1, clientBalances)` and
`clientBalances >= 1` is *already* guaranteed by the `principalOf != 0` early return, so that leg is
a tautology; for the market strategy, `ceilDiv(1 * MAX_BPS, MAX_BPS - slip) == 1` for any
`slip < 5000` bps. The probe detects exactly one condition: a 100% slippage tolerance.

### Impact

No asset impact — a misleading UI and gas wasted on a reverting transaction. It is Low rather than QA
because the view is *consumed* (by the UI it was written for), not unused. Its practical weight is
that it is the third diagnostic misdirection in the same debugging session: `CLASS-003`'s revert
message blames an honest strategy, `CLASS-002`'s remedy note points at the wrong constant, and this
view shows a live button on a dead pool. It is also the second
availability-view-disagrees-with-its-transaction entry on StableStaker (after `a56f87780b`, open, on
`withdrawDisabled`, which errs in the opposite direction). Known issue **N26** does not reach it:
N26 establishes that the preview *inside* `autoAnnihilate` is untrusted and re-checked against a
measured delta, which says nothing about a public view's contract with its callers, and neither N26
nor N18 covers the `principalOf == 0` early return.

**Also reported as:** a Low in `qa-report.md` (source finding `CLASS-010`), cross-referenced there as
F-03. Consumer-side instance of reflax-yield-vault L-21 / `833f7f6c72` ("`netGuaranteed > 0` is a
false green") — route, do not duplicate.

---

## F-04 — The promised "MANDATORY MEASUREMENT" is vacuous on the underwater branch, and the docs assert an untouched buffer that is demonstrably touched

**Severity:** Low
**Code:** `lib/stable-staker/src/StableStakerV2.sol:580-589` (the measurement), `:1184-1192` (`_routeExit`'s underwater branch, with the load-bearing check at `:1190`), `:607-610` (the surplus transfer)
**Spec:** story-025:748 and :754 (round-2 checklist); `lib/stable-staker/CLAUDE.md:151-156` (round-3 carve-out) — known issue **N19**

### What the spec says

Round-2 checklist, verbatim (story-025:748):

> - [x] Add the **mandatory post-withdraw measurement**: measure the actual balance delta returned by
>   `_routeExit` and revert with an explicit `StableStaker: <phrase>` string when the received amount
>   is below what the annihilation needs. A manipulated or over-quoting preview must fail the
>   transaction, never silently draw on the idle buffer

Round-2 checklist, verbatim (story-025:754):

> - [x] Tests — confirm the **idle buffer is untouched** across every case above: assert StableStaker's
>   idle stable balance is unchanged by `autoAnnihilate` in the full-credit, haircut, whole-position
>   and lying-preview scenarios

`CLAUDE.md:151-156`, the round-3 carve-out, verbatim:

> The carve-out is the **underwater** path, which `autoAnnihilate` shares with `withdraw` and
> does not change: when `_isUnderwater` is true, `_routeExit` pays the whole request out of the
> idle balance plus `relinquishPrincipal` and returns the nominal amount without measuring
> anything.

### What the code does

The measurement the checklist promises is at `StableStakerV2.sol:580-589`:

```solidity
// MANDATORY MEASUREMENT. The preview is advisory: …
uint256 allowance = EXIT_ROUNDING_ALLOWANCE + (netFloor * EXIT_ROUNDING_ALLOWANCE_BPS) / MAX_BPS;
uint256 floorWithAllowance = netFloor > allowance ? netFloor - allowance : 0;
require(received > 0 && received >= floorWithAllowance, "StableStaker: exit shortfall");
```

On the underwater branch it can never fire. `_routeExit` returns the **nominal** `amount` without
touching the strategy or measuring anything:

```solidity
// StableStakerV2.sol:1184-1192
if (guardUnderwater && _isUnderwater(token, strategy)) {
    if (t.balanceOf(address(this)) >= amount) {
        emit BufferWithdrawn(token, msg.sender, amount);
        strategy.relinquishPrincipal(token, amount);
        return amount;
    }
    revert("StableStaker: strategy underwater");
}
```

So `received == gross`, and since `netFloor = netQuote * gross / grossQuote <= gross`, the
comparison `received >= floorWithAllowance` holds identically. The branch is nonetheless **safe**,
but for an unrelated reason the documentation does not connect to the guard: `:1188` independently
checks `t.balanceOf(address(this)) >= amount` before paying, so a buffer that cannot cover the draw
reverts there rather than passing a vacuous floor check downstream. This is a documented carve-out
whose safety argument rests somewhere other than where the NatSpec points.

The checklist's "idle buffer is untouched" claim is separately false on this branch, and not only
editorially: `gross` was grossed up by the strategy's slippage tolerance for a haircut that does not
occur here, so `surplus = gross - netWanted > 0` is `safeTransfer`'d to the caller **out of the
shared idle buffer** at `:607-610`, and `relinquishPrincipal(token, gross)` at `:1190` writes the
strategy's booked principal down by the inflated figure.

No test covers `autoAnnihilate` against an underwater strategy — even though round 3 corrected
`MockYieldStrategy.previewExitFor` (Decision 3) *specifically so the case could be tested*. The
correction landed; the test did not.

### Impact

Not a value leak and not a Law-1 escalation: `user.amount` is debited by the same gross, and an
equivalent `withdraw` already draws at par from the buffer. What is undisclosed is the **rate** —
`autoAnnihilate` draws the tolerance-inflated gross from a scarce, first-come buffer for a
transaction that economically needs only `netWanted`, accelerating exhaustion against later stakers
by the gross-up factor. Kept at Low rather than QA because the falsified claim is behavioural, and
because the missing test is the one that would have caught the economic rate finding
(`CLASS-006`).

Known issue **N19** is the only item that speaks to this and is **not permitted to suppress it**, on
two independent grounds: the section N19 cites as its justification does not exist in the file (see
§ Documentation defects below), and a known issue cannot suppress a finding whose content is that
the same documentation describes only the un-grossed draw.

**Also reported as:** a Low in `qa-report.md` (source finding `CLASS-011`), cross-referenced there as
F-04. The economic sibling — the buffer-drawdown *rate* disclosed against two `wont-fix` entries,
whose remedy is an owner sizing re-check rather than a doc edit and a test — is `CLASS-006`, kept
deliberately separate. The same vacuity is described from the other side by reflax-yield-vault L-27 /
`d9bd595066`.

---

## F-05 — The story bounds the raw-mint gate-bypass by the AMM slippage tolerance; the real bound is `min(user.amount, clientBalances[token][staker])`

**Severity:** Low
**Code:** `lib/stable-staker/src/StableStakerV2.sol:554-560` (the two caps), `:596` (the raw-mint remainder)
**Spec:** story-025:716-720, "## Reopened — Round 2", Front-running analysis — known issue **N20**

### What the spec says

Verbatim (story-025:716-720):

> - **Self-sandwiching to defeat the claim gate.** A worse AMM rate means less stable returns for the
>   same principal, so less Antimatter is annihilated and more is minted raw — which is precisely what
>   the closed `claim()` exists to prevent. It is bounded: `ERC4626MarketYieldStrategy` enforces
>   `minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS` internally and reverts
>   before `autoAnnihilate` ever sees the proceeds, so the extractable amount is capped at the
>   tolerance and costs a real AMM round trip. **Accepted.**

The same claim is mirrored into `CLAUDE.md:162-167` and extracted as known issue **N20**.

### What the code does

A **second** cap exists, and it is neither tolerance-related nor caller-set. Both `previewExitFor`
implementations cap `grossToRequest` at the strategy's per-client ledger,
`clientBalances[token][address(this)]`; `autoAnnihilate` then caps again at the caller's own
principal:

```solidity
// StableStakerV2.sol:554-560
(uint256 grossQuote, uint256 netQuote) = _previewExit(token, netWanted);
require(netWanted == 0 || grossQuote > 0, "StableStaker: exit unavailable");
gross = grossQuote > user.amount ? user.amount : grossQuote;
netFloor = grossQuote == 0 ? 0 : (netQuote * gross) / grossQuote;
```

The effective bound on the annihilated half is therefore `min(user.amount, clientBalances[token][staker])`.
When the second term binds, `grossQuote`, `gross`, `netFloor` and `netUsed` all shrink below
`netWanted`, and the shortfall is minted **raw** at `:596`:

```solidity
uint256 excess = excessBase + (netWanted - netUsed) * scale;
```

On `ERC4626MarketYieldStrategy` this cap binds **structurally**, not occasionally: `_acquireShares`
books the haircut-adjusted `creditedPrincipal` rather than the nominal deposit, so `clientBalances`
sits permanently below the pool's nominal `totalStaked`.

### Impact

Explicitly **not** a value leak, and explicitly not an attack vector — the second cap is
protocol-level, not caller-steerable. Conservation still holds exactly: `owed` in equals annihilated
plus raw-minted plus carried dust, independently verified by ECON-005 and by INV-1/INV-2 (PASS, zero
overshoot). It stays Low, and stays a documentation finding, because what is falsified is a
**security bound the owner reasons from**, not prose.

Known issue **N20** is the natural suppressor and is refused on a specific ground worth restating:
N20 is not a neighbouring item that happens to overlap — it *is* the claim this finding falsifies,
and a known issue cannot suppress the finding demonstrating that the known issue's own reasoning is
incomplete. Suppressing here would preserve a false bound inside the project's own documentation.

Kept strictly distinct from F-01: this corrects the *stated bound* on the raw-mint path (a doc
edit); F-01 is the *existence* of a far wider, unrelated channel into the same line (a design
question). Fixing either does nothing for the other.

**Also reported as:** a Low in `qa-report.md` (source finding `CLASS-012`), cross-referenced there as
F-05.

---

## F-06 — Round 3 discharged the reviewer's blocking finding for the rounding case only; the fee case is deferred to an override that does not exist at the pinned commit

**Severity:** Low, with an **armed escalation trigger to Medium**
**Code:** `lib/stable-staker/src/StableStakerV2.sol:578-592` (the allowance and the floor), `:70`/`:78` (`EXIT_ROUNDING_ALLOWANCE = 2`, `EXIT_ROUNDING_ALLOWANCE_BPS = 1`, both `constant`, no setter)
**Spec:** story-025:1044-1046 (Review Failure Report, blocking `[high]`), :1007-1008, and :1096-1120 (Round 3, Decision 1) — known issue **N18**

### What the spec says

The blocking review's first required remedy, verbatim (story-025:1044-1046):

> - [x] Re-derive the shortfall floor so a double-rounded-down ERC4626 delivery of
>       `amount - 1` (or a routine haircut) does **not** revert `autoAnnihilate`.

and its statement of stakes, verbatim:

> Because `claimEnabled == false` by default, `autoAnnihilate` is the **only** reward path, so
> the story's stated goal fails in production.

### What the code does

Round 3 answered with a bounded rounding allowance (Decision 1), landed at `:587-589`:

```solidity
uint256 allowance = EXIT_ROUNDING_ALLOWANCE + (netFloor * EXIT_ROUNDING_ALLOWANCE_BPS) / MAX_BPS;
uint256 floorWithAllowance = netFloor > allowance ? netFloor - allowance : 0;
require(received > 0 && received >= floorWithAllowance, "StableStaker: exit shortfall");
```

That satisfies the reviewer's **rounding-scale** criterion — "a routine haircut" it does not.
`ERC4626YieldStrategy` does not override `previewExitFor`, so `netFloor` collapses to the
`AYieldStrategy` capped identity, while `_disposeShares` redeems the fee-free
`convertToShares(amount)` and the vault returns assets net of its own fee. Any exit fee above
**1.00 bp** trips `"StableStaker: exit shortfall"` on every call above
`N = 2 / (f - 1e-4)` raw units — and with `claimEnabled` false that is the only reward path.

Decision 1 defers this case explicitly, on the reasoning that a fee-charging vault "genuinely wants
its own `previewExitFor` override in vault-RM rather than a fudge factor here". No such override
exists at the pinned `lib/reflax-yield-vault` commit `cdd0743`. The round-3 regression fixture —
`MockERC4626Vault`, OpenZeppelin's reference `ERC4626` plus a donation helper — charges **no fee**
and is therefore structurally incapable of detecting the residual, which is the same class of
fixture blindness that let the round-2 defect reach review.

### Impact and standing

**Not live at HEAD**, and that negative was measured this run rather than carried: fresh mainnet fork
measurement (block 25878600, cold-cache re-fetch, 5/5 tests pass) puts autoDOLA at **0.473049 bps**
and autoUSD at **0.535370 bps**, both under the 1 bp allowance, with no revert observed at any reward
size on either pool. Halmos corroborates the boundary exactly: `check_noBrick` passes at 0 / 0.47 /
0.54 / 0.90 / 1.00-exact bp, `check_crossing_101_hundredthsBp` fails with a counterexample, and
`check_control_5bp` fails as the positive control proving the harness can find a brick when one
exists. Reporting this as a live Medium would be overstatement.

It stays open at Low for three reasons that survive the refutation and that **N18** does not reach.
N18 legitimately suppresses the "widen the allowance" remedy — the 1 bp figure was chosen
deliberately below any real haircut, and INV-6's scaling law shows the flat 2 units are load-bearing
and must not be reduced. It says nothing about: (i) both deciding constants being `constant` with no
setter, so an operator has no parameter remedy if the trigger fires — only a redeploy or the absent
vault-RM override; (ii) nothing in the wiring runbook tying reward-path liveness to an *external*
vault's fee parameter, so nobody is watching the 0.46-0.53 bp of headroom; (iii) the revert string
naming the strategy rather than the constant, pointing diagnosis at the wrong contract. The decimals
cliff sharpens it: the flat 2-unit leg is worth 2e-6 USDC on a 6-decimal pool but 2e-18 DOLA on an
18-decimal pool, where the entire margin is the 1 bp.

This is **not** the C4 fee-on-transfer-token exclusion: the fee is charged by a wired ERC4626
autopool on redemption, not by a token transfer hook.

**Escalation trigger (armed, do not close):** wired autopool modeled exit discount `f > 1.00 bp`
exactly ⇒ Medium (availability of the sole reward path). Monitor by re-running
`reports/stable-staker/17/poc/Run17_ECON001_ExitFeeBrick.t.sol::test_measure_autopool_exit_haircut_bps`
against the live autopools — pure measurement, needs no protocol state. The trigger is an external
parameter outside this protocol's control, so the finding must not be closed on the strength of
today's measurement.

**Also reported as:** a Low in `qa-report.md` (source finding `CLASS-002`), cross-referenced there as
F-06. Consumer side of reflax-yield-vault L-19 / `302656e234` and ECON-A / `c50c08f9ee` — route, do
not duplicate.

---

## Documentation defects in the declared known-issues source

Recorded here, separately from the deviations above, because they **degrade the authority of future
sanitization**. `lib/stable-staker/CLAUDE.md` is the project's only declared known-issues source
(`README.md` is a generic Foundry template), and every suppression this pipeline applies to a
stable-staker finding is extracted from it. Both defects are in the story-025 section, and both were
introduced or left standing by the same machine-approved rounds described in §0.

1. **The headline `autoAnnihilate` description states the round-1 net debit that round 2 identified
   as a bug.** `CLAUDE.md:92` says the function "decrements `userInfo.amount` and
   `poolInfo.totalStaked` by the stable half"; the code debits the gross at
   `StableStakerV2.sol:565-566`, and `CLAUDE.md:121-122` states the correct semantics one section
   later. This is **F-02** above; it is repeated here because its standing as a *documentation
   authority* defect is distinct from its standing as a Law-2 deviation. A source that contradicts
   itself about the function under review cannot carry unqualified suppression weight for that
   function.

2. **The underwater-buffer carve-out justifies itself by citing a section that does not exist.**
   `CLAUDE.md:151-156` (known issue **N19**) closes with, verbatim:

   > That is the buffer doing exactly the job it exists for, and it is deliberate — see "idle balance is
   > automatically buffer" above — but it means "the buffer is untouched" is a statement about the
   > normal path, not an invariant of every call.

   No section titled or phrased "idle balance is automatically buffer" exists anywhere in
   `CLAUDE.md` at HEAD: `grep -n 'idle balance is automatically buffer' lib/stable-staker/CLAUDE.md`
   matches **only** this self-reference at line 155. The carve-out's stated authority is unanchored —
   it asserts a prior justification that was never written.

**Consequence for sanitization, to be carried into the next run's known-issues extraction:** N19
carries no suppression authority over F-04, both because its cited ground does not exist and because
a known issue cannot suppress a finding whose content is the incompleteness of that known issue's
own reasoning. The same principle governs N20 versus F-05. Neither ruling is a general demotion of
`CLAUDE.md`; the other twenty-four extracted items are anchored and stand.

---

## Cross-reference summary

Law 2 says these are spec deviations; a deviation that *also* carries security, value or
availability impact is reported in its own severity-bearing report as well, linked by its F-label.

| F | Source | Severity | Also appears in | Escalation / flags |
|---|---|---|---|---|
| **F-01** | CLASS-001 | Low | `qa-report.md` | **Law-3 footgun**, safe-config guidance above; flagged for human re-weigh to Medium |
| **F-02** | CLASS-009 | QA | `qa-report.md` | Documentation-authority defect (§ above) |
| **F-03** | CLASS-010 | Low | `qa-report.md` | Cross-repo: reflax-yield-vault L-21 / `833f7f6c72` |
| **F-04** | CLASS-011 | Low | `qa-report.md` | Documentation-authority defect (§ above); economic sibling `CLASS-006` kept separate; reflax L-27 / `d9bd595066` |
| **F-05** | CLASS-012 | Low | `qa-report.md` | Refuses suppression by N20 |
| **F-06** | CLASS-002 | Low | `qa-report.md` | **Armed escalation trigger to Medium**; cross-repo: reflax L-19 / `302656e234`, ECON-A / `c50c08f9ee` |

All six are Low or QA in their own right. None is a High or a Medium. The finding of this report is
their number and their common origin, stated in §0.

QA labels (`L-xx` / `Q-xx`) are assigned by the QA bundler; the `CLASS-` ids above are the stable
join key between this report and `findings/classified.json` until the ledger fingerprints are minted.
