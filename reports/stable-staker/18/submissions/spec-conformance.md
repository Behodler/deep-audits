# Spec Conformance Report (Law 2 — Faithfulness) — stable-staker (run 18)

**Project**: stable-staker
**Commit**: `cf8de2718816a1c7df794dafb9d567e5694d826d` (`cf8de27`, branch `master`)
**Primary contract**: `src/StableStakerV2.sol`
**Stories**: `~/code/product-owner/stories/stable-staker/auto-complete/phusd-shortfall/`
— `026-restore-phusd-minting-capability.md`, `027-bump-vault-past-revert-and-strip-exit-preview.md`,
`028-cover-annihilation-shortfall-with-minted-phusd.md`
**Date**: 2026-09-01

This report is the Law-2 channel and is **separate from `submissions/qa-report.md`** by design. The
security narratives for M-01 and M-02 live in their own submissions and are **cited, never restated,
here**.

---

## Standing caveat on the evidentiary weight of all three stories

All three stories in this batch carry the same approval and independence disclosures. Quoting them
verbatim:

> **Approved by**: story-batch workflow (machine approval — not human-reviewed)
> — `026-*.md:553`, `027-*.md:539`, `028-*.md:640`

> **Independence**: reduced — these verdicts were reached by the agent that also performed the work
> — `026-*.md:346`, `027-*.md:324`, `028-*.md:373` (and repeated at `026:460,587`, `027:417,570`,
> `028:474,663`)

Story 028 is explicit that the reduction is structural rather than incidental:

> "these verdicts were reached by a single agent rather than five independent [validators] ... the
> outer layer of independence is intact; the inner layer is not."
> — `028-*.md:474-476`

**Consequence for this audit.** Every checked acceptance box in these three stories is a **claim by
the implementing agent about its own work**, not independent evidence. Where a story asserts a
property (a test passes, a non-goal holds, an invariant survives), this run verified it against the
source at `cf8de27` rather than accepting the tick. Two of the four items below are cases where the
tick and the code disagree.

Note also that these stories sit under `auto-complete/`, not `complete/`. Per the standing rule that
the state folder is metadata and not a filter, they are in scope regardless; the state is recorded
because a landed feature whose story has not been closed out by a human is itself worth flagging.

---

## [F-01] Story-unsafe escalation: the stories model only the self-sandwich <!-- id: ss18f1 -->

**Law**: Law 1 overriding Law 2 — the stories' *own intended behaviour* carries the hazard, so the
finding is against the story, not merely against the implementation.
**Location**: `src/StableStakerV2.sol#L519-L592` (`autoAnnihilate`);
`028-cover-annihilation-shortfall-with-minted-phusd.md:325-332`;
`lib/stable-staker/CLAUDE.md:227-236`
**Severity-bearing**: **No.** This is a Law-2 item and must never enter the H/M tally.

### The story text

Story 028 prices the extraction risk exactly once, in its Concerns section:

> "**The top-up is extractable, and this is the accepted cost of the design.** A user who sandwiches
> their own `autoAnnihilate` through `ERC4626MarketYieldStrategy`'s AMM keeps the sandwich profit AND
> still receives the frictionless payout, because the protocol mints the difference. It is bounded
> three ways: the strategy enforces `minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) /
> MAX_BPS` internally and reverts below it, so extraction per call is capped at the configured
> tolerance; it costs a real AMM round trip; and it is bounded by the caller's own stake and accrued
> antimatter. **Human decision: accepted.** Shifting slippage onto the protocol is the explicit goal.
> The operational lever is `slippageToleranceBps` — set it as tightly as the market allows."
> — `028-*.md:325-332`

Stories 026 and 027 contain no extraction analysis at all; 028 is the whole of the decision record.

### The deviation

**Every actor in that paragraph is the same person.** "A user who sandwiches **their own**
`autoAnnihilate`". The third bound — "bounded by the caller's own stake and accrued antimatter" —
is a bound on the **victim's** position, and it only limits the attacker because the story assumes
attacker and victim are the same party.

`autoAnnihilate` is permissionless with respect to the AMM. Nothing in the code restricts who may
place trades around another staker's call:

```solidity
// src/StableStakerV2.sol:574-580
uint256 received = _routeExit(token, gross, true);
// MEASURED DELTA. {_routeExit} returns what actually arrived, which a selling strategy
// may haircut below the request. Only what arrived is ever annihilated; the difference in
// VALUE is made up in freshly minted phUSD, never out of the idle buffer.
uint256 netUsed = received < netWanted ? received : netWanted;
annihilatable = netUsed * scale;
(phUSDPaid, phUSDMinted) = _annihilateAndTopUp(token, netUsed, netWanted, scale);
```

A **third-party** sandwicher is bounded by the *victim's* stake and accrual — a quantity the
accepting human never saw, never sized, and never priced. The decision record accepted a bound that
does not hold for the actor who actually matters.

### The `CLAUDE.md` claim, and why it is materially wrong

The project's own design note dismisses the residual risk:

> "Ordinary sandwiching of the exit is not new: a plain `withdraw` sells into the same AMM with the
> same protection."
> — `lib/stable-staker/CLAUDE.md:235-236`

This is true about the **mechanics** and wrong about the **economics**. Same `minOut`, different
incidence:

| | plain `withdraw` | `autoAnnihilate` |
|---|---|---|
| Who chose the trade | the user | the user |
| Who absorbs the slippage | **the user** | **the protocol** (minted top-up, `:644-647`) |
| Victim's incentive to defend | strong — it is their money | **none** — they are made whole |

Under `withdraw`, the party who eats the loss is the party who chose the trade, so they have every
incentive to time it, split it, or decline it. Under `autoAnnihilate` the *identical* sandwich costs
the protocol, because the shortfall is made up in freshly minted phUSD:

```solidity
// src/StableStakerV2.sol:640-647
uint256 target = netWanted * scale + stableMinter.calculateMintAmount(token, netWanted);
...
phUSDMinted = target > delivered ? target - delivered : 0;
if (phUSDMinted > 0) {
    require(phUSDMintAvailable(), "StableStaker: phUSD mint unavailable");
    _phUSD().mint(address(this), phUSDMinted);
}
```

The make-whole guarantee is precisely what **removes the victim's defensive incentive**. "The same
protection" describes the `minOut`; it does not describe who is protected.

### The knob that was removed

Story 028 also deleted the caller's ability to set their own floor:

> "**`minPhUSDOut` leaves the ABI** on the human's instruction — the end user gains nothing from it
> once StableStaker guarantees the payout."
> — `028-*.md:341-342`

> "Per human decision: the caller gains nothing from setting it, because StableStaker itself now
> guarantees the payout."
> — `028-*.md:187-188`

The reasoning is **correct on its own terms** — a made-whole caller genuinely gains nothing from a
personal floor. But it has a second consequence the story does not record: with the parameter gone,
**no user can decline to be a vector**. A staker who would rather set a tight floor and accept a
revert than have their call used to mint protocol-funded top-ups no longer has that option. The
removal is faithful to the human instruction and simultaneously eliminates the last caller-side
lever.

### Recommendation

1. Amend the story / decision record to price the **third-party** sandwicher explicitly, since the
   accepted bound ("the caller's own stake and accrual") does not apply to them.
2. Correct `CLAUDE.md:235-236` — the mechanics claim is sound, the economics claim is not.

*For the security narrative, exploitability and sizing, see the **M-01** submission. It is stated
once, there, and is not restated here: different channel, different law (Law 2 vs Law 1), different
remedy (amend the record and correct the doc, vs. bound and report `slippageToleranceBps`).*

---

## [F-02] `autoAnnihilateAvailable` NatSpec asserts a false universal negative <!-- id: ss17l6 -->

> **THIS IS NOT A NEW FINDING.** It is a **recurrence** of **open** ledger entry
> **`19c0886b`** (`ss17l6` / L-06, run stable-staker-17) with expanded evidence.
> **No new fingerprint was minted**, the issue ID is the originating run's and is **not** restamped
> to run 18, and the entry is **not** marked fixed or moot. One entry, two output surfaces (the
> ledger entry and this report).
>
> A prior coordinator list named this entry among the moot-by-deletion set. **That was wrong**, and
> the correction is honoured here: it is verified **STILL-LIVE** at `cf8de27`.

**Location**: `src/StableStakerV2.sol#L1107-L1130` (NatSpec + view), `#L1315-L1324` (`_routeExit`)
**Severity**: Low (unchanged from the run-17 entry; only the evidence expanded)

### The claim

```solidity
// src/StableStakerV2.sol:1117-1121
*      There is no strategy-side condition left to check. The exit is sized against what the
*      strategy actually DELIVERS (measured in {autoAnnihilate}) rather than against a quote it
*      issues in advance, so no strategy configuration can make {autoAnnihilate} unavailable —
*      an under-delivering exit simply annihilates less. What remains is purely the stable-minter
*      registration question this view exists to answer.
```

This is a universal negative — "**no** strategy configuration can make `autoAnnihilate`
unavailable" — and it is checkably false.

### The counter-example

`autoAnnihilate` passes `guardUnderwater = true`:

```solidity
// src/StableStakerV2.sol:572-574
// Underwater guard ON, matching {withdraw}: this is a voluntary principal exit, not an
// escape hatch, so it must not realize a loss the user did not opt into.
uint256 received = _routeExit(token, gross, true);
```

and `_routeExit` reverts on that path when the buffer cannot cover the exit:

```solidity
// src/StableStakerV2.sol:1315-1324
if (guardUnderwater && _isUnderwater(token, strategy)) {
    // Underwater: try to satisfy the entire withdraw from the on-contract buffer.
    // Caller forwards the returned amount via safeTransfer, so we just signal
    // "use the buffer" by returning `amount` without touching the strategy.
    if (t.balanceOf(address(this)) >= amount) {
        emit BufferWithdrawn(token, msg.sender, amount);
        strategy.relinquishPrincipal(token, amount);
        return amount;
    }
    revert("StableStaker: strategy underwater");
}
```

An underwater strategy **is** a strategy-side condition, and it makes `autoAnnihilate` revert while
the view returns `true`. Meanwhile the view itself checks only one thing:

```solidity
// src/StableStakerV2.sol:1123-1130
function autoAnnihilateAvailable(address token) public view returns (bool) {
    (bool ok, bytes memory data) =
        address(antimatter).staticcall(abi.encodeCall(IAntimatter.toStableAmount, (token, 1e18)));
    if (!ok || data.length != 32) {
        return false;
    }
    return true;
}
```

### New evidence this run

Story 028 introduced **four further revert paths** the view cannot see, all of them reachable from
the `require(phUSDMintAvailable(), ...)` gate at `:646` and its dependencies:

1. **phUSD unset on Antimatter** — `phUSDToken()` returns `address(0)`, `phUSDMintAvailable()`
   returns false (`:1184-1186`).
2. **phUSD mint unavailable** — a revoked grant or a global `mintVersion` bump
   (`revokeAllMintPrivileges()`), which the NatSpec at `:1170-1175` itself flags as "a live
   operational hazard".
3. **The stable minter's own pause / `enabled` flag** — `require(!paused, ...)` and
   `require(config.enabled, ...)` in `PhusdStableMinter.mint`.
4. **`maxMintPerDay`** — `require(config.mintedToday + phUSDAmount <= config.maxMintPerDay, "Daily
   mint limit exceeded")`.

The run-17 wording was weaker prose; the current text is an explicit universal negative, which is a
**stronger and more checkably false** claim than the version originally filed.

### Impact

A UI or integrator that trusts this view pre-flights **green** and then reverts on-chain, with a
foreign or misleading error string, in at least five distinct configurations.

### Recommendation

Either make the view reflect the actual transaction preconditions (underwater state, phUSD mint
availability, minter pause/enabled, daily cap), or delete the universal-negative paragraph at
`:1117-1121`. A view named `...Available` that answers a narrower question than its name implies is
worse than no view.

---

## [F-03] `phUSDMintAvailable`'s "nothing consumes this yet" — its consumer landed in the same commit <!-- id: ss18f3 -->

**Location**: `src/StableStakerV2.sol#L1177-L1180` (NatSpec) vs `#L646` (the consumer)
**Severity**: QA

### The claim

```solidity
// src/StableStakerV2.sol:1177-1180
*      Staticcalled rather than called directly so that an unset, non-contract or ABI-divergent
*      phUSD answers `false` instead of reverting the caller. Nothing in this contract consumes
*      this yet; it exists so the shortfall path can degrade rather than assume, and so the
*      capability is observable and testable before its consumer lands.
```

### The actual behaviour at the same commit

```solidity
// src/StableStakerV2.sol:645-648
if (phUSDMinted > 0) {
    require(phUSDMintAvailable(), "StableStaker: phUSD mint unavailable");
    _phUSD().mint(address(this), phUSDMinted);
}
```

The consumer is not pending — it is present at `cf8de27`, in the same commit as the doc that says it
has not landed.

### Why this matters beyond tidiness

Story 028's own checklist carried the requirement:

> "- [x] Decide, implement and DOCUMENT what happens when the phUSD mint is unavailable (revert vs
> fall back to raw antimatter), using story 026's probe rather than surfacing a foreign `"phUSD: ..."`
> string"
> — `028-*.md:303`

The story confirms the decision and implementation:

> "`phUSDMintAvailable()` before minting and reverts `"StableStaker: phUSD mint unavailable"` — our
> [string]"
> — `028-*.md:380`

Two of the three obligations — **decide** and **implement** — were met. The third, **DOCUMENT**, was
ticked but not delivered: the probe's own documentation is the one place an operator would look, and
it still says nothing uses it. This is precisely the doc that would tell an operator that a revoked
mint grant now closes the reward path (the `revokeAllMintPrivileges` footgun described in the same
NatSpec block at `:1170-1175`).

### Recommendation

Update `:1177-1180` to name `_annihilateAndTopUp` at `:646` as the consumer, and state the
consequence: revert, not fall back.

---

## [F-04] The contract NatSpec states the buffer invariant unqualified <!-- id: ss18f4 -->

**Location**: `src/StableStakerV2.sol#L484-L488`
**Severity**: Low
**Independence**: **lands independently of M-02's disposition** — see below.

> **Post-review note (2026-09-01).** M-02 / `ss18m2` was **lowered to Low** by an accepted
> severity-auditor overturn. **F-04 is unaffected and is now the primary surviving artifact of that
> line.** The `:484-488` text is false as written on the underwater branch **regardless of how M-02
> resolves**, so F-04 must not be swept up in, lowered by, or retired on the strength of that
> downgrade.

### The claim

```solidity
// src/StableStakerV2.sol:482-488
*        d. The frictionless target — `netWanted * scale` for the antimatter half plus
*           {IPhusdStableMinter-calculateMintAmount}`(token, netWanted)` for the stable half — is
*           compared against the phUSD actually delivered, and the protocol MINTS the difference.
*           The top-up is new phUSD, NOT a draw on this contract's idle stable balance: that
*           balance is the shared underwater-withdrawal buffer, and the invariant that
*           `autoAnnihilate` never spends a unit of it survives intact. No other staker's position
*           is touched by one caller's exit haircut.
```

Two claims, both unqualified: an **invariant** that `autoAnnihilate` never spends a unit of the
buffer, and the assertion that **no other staker's position is touched**.

The story it derives from makes the same claim:

> "The top-up is **freshly minted phUSD**, not drawn from any pooled asset, so no other staker's
> position is touched. The buffer-untouched invariant survives and must be asserted directly."
> — `028-*.md:338-340`

### The actual behaviour

The M-02 PoC falsifies both, via the underwater branch of `_routeExit`, which pays the exit **out of
the on-contract buffer**:

```solidity
// src/StableStakerV2.sol:1315-1323
if (guardUnderwater && _isUnderwater(token, strategy)) {
    // Underwater: try to satisfy the entire withdraw from the on-contract buffer.
    ...
    if (t.balanceOf(address(this)) >= amount) {
        emit BufferWithdrawn(token, msg.sender, amount);
        strategy.relinquishPrincipal(token, amount);
        return amount;
    }
```

`autoAnnihilate` reaches this branch at `:574` with `guardUnderwater = true`. The buffer is spent, on
the `autoAnnihilate` path, contradicting the word "never".

### Why this is filed separately from `CLAUDE.md`'s treatment

`lib/stable-staker/CLAUDE.md` **does** qualify the claim — it describes it as a statement about the
normal path rather than an invariant of every call. That qualification does not reach an integrator,
because the artifact an integrator reads is the **contract**, and the contract states it flatly, with
no carve-out, and adds a second sentence ("No other staker's position is touched") that the
qualification does not cover at all.

Per the standing project principle that **in-source NatSpec carries no suppression authority**, a
falsely-exhaustive doc **raises** severity rather than sanitizing the defect. A comment that
overstates an invariant is not neutral: it is the thing that stops a reviewer from checking.

### This lands independently of M-02

The code fix (do not let the reward path consume the withdraw buffer, or gate `autoAnnihilate` on
`!_isUnderwater`) and the doc fix (qualify `:484-488`) are separate changes with separate risk.
**If the owner wont-fixes M-02 on design intent, this item still has to land** — indeed a wont-fix on
intent makes the unqualified comment *more* wrong, not less, because the behaviour it misdescribes
becomes permanent.

### Recommendation

Qualify the comment at `:484-488` to the normal (non-underwater) path, and delete or qualify the "No
other staker's position is touched by one caller's exit haircut" sentence.

*For the mechanism, PoC and sizing, see the **M-02** submission.*

---

## Clean negatives

These were checked and cleared. They are audit output in their own right — recorded so a later run
does not re-derive them, and so this report states what was examined rather than only what failed.

**1. No ABI drift on `IPhUSD` / `IPhusdStableMinter` / `IAntimatter`.**
All signatures were verified against the real contracts. `IPhUSD.MinterInfo`'s layout is
**byte-identical to `IFlax`**'s, and the 64-byte decode in `phUSDMintAvailable` is correct for it:

```solidity
// src/StableStakerV2.sol:1187-1192
(bool infoOk, bytes memory infoData) =
    token.staticcall(abi.encodeCall(IPhUSD.authorizedMinters, (address(this))));
if (!infoOk || infoData.length != 64) {
    return false;
}
IPhUSD.MinterInfo memory info = abi.decode(infoData, (IPhUSD.MinterInfo));
```

Two `uint256`-slot members ⇒ 64 bytes. The length guard is exact, and a divergent phUSD answers
`false` rather than reverting, as the NatSpec claims.

**2. Decimals and truncation arithmetic correct in both directions.**
Proved with a worked 6-decimal example. The single truncation (`netWanted = capped / scale`, `:541`)
is compensated by the remainder carry (`unclaimedReward = capped - netWanted * scale`, `:547`), and
the truncation inside `calculateMintAmount` floors — i.e. favours the protocol, as `:638-639` states.
This is the evidence that resolves Slither's `divide-before-multiply` (S-01) as benign; see
`qa-report.md`, Appendix A.

**3. No reentrancy path.**
OpenZeppelin's guard is **contract-wide** and every function on the implicated surface carries
`nonReentrant`, so the cross-function variant Slither and Aderyn model cannot occur. *This does not
touch the separate, still-open informational entry `796f775ff3` (`initiateMigration` CEI ordering).*

**4. No double-credit in the remainder arithmetic.**
The `excess` antimatter mint and the sub-unit remainder carry are **mutually exclusive by
construction**: `excess = owed - capped` (`:544`) is non-zero only when
`capped == principalAsAntimatter`, and in that case `capped` is an exact multiple of `scale`, so the
remainder `capped - netWanted * scale` (`:547`) is zero. The two payout legs can never both fire on
the same reward unit.

**5. Stories 026 and 027 verified faithful.**
Story 026's explicit non-goal —

> "**Explicit non-goal:** no change to `claim`, `stake`, `withdraw`, `emergencyWithdraw`,
> `_exitPosition`, `antimatterPerDay`, `accAntimatterPerShare`, or any reward arithmetic."
> — `026-*.md:20-21`

— was **diff-verified across the whole commit range**, not accepted on the story's own tick. The
story's claim that its diff "contains **zero removed lines** — it is purely additive" (`026-*.md:467`)
holds, and the named reward-arithmetic surfaces are untouched. Story 027 (vault bump, exit-preview
strip) is likewise faithful; the removal of `previewExitFor` is the deletion that re-sited the L-03
dust-window class recorded in `qa-report.md`.

---

## Files

| Artifact | Path |
|---|---|
| This report | `reports/stable-staker/18/submissions/spec-conformance.md` |
| QA bundle (Low + QA) | `reports/stable-staker/18/submissions/qa-report.md` |
| Automated QA/gas appendix | `reports/stable-staker/18/submissions/4naly3er-report.md` |
