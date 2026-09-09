# QA Report — stable-staker (run 18)

**Project**: stable-staker
**Commit**: `cf8de2718816a1c7df794dafb9d567e5694d826d` (`cf8de27`, branch `master`)
**Primary contract**: `src/StableStakerV2.sol`
**Date**: 2026-09-01

> **Deployment status.** `StableStakerV2` is **UNDEPLOYED**. Mainnet runs the frozen `StableStakerV1`
> at `0xbce8ABC09BaEDCabE93419bF875f6186e182079A`. Nothing in this report is live on mainnet today.
> This lowers urgency; it does not lower correctness, and one item below (Q-02) turns on an
> undeployed-ness premise that this run could only half-verify.

Faithfulness (Law 2) items — **F-01 through F-04** — are **not** in this bundle. They are reported
separately in `submissions/spec-conformance.md`, per the standing rule that story/spec deviations
never enter the QA bundle.

> ## ⚠ POST-REVIEW SEVERITY CHANGES AFFECTING THIS BUNDLE (applied 2026-09-01) — **ROUTING NOW APPLIED**
>
> Two severity calls in this run were overturned by an independent **severity-auditor** and the
> overturns were adjudicated and **accepted** by the coordinator. Both affect this bundle. The
> C4-convention re-routing of the affected bodies between files **has now been applied**
> (`reportRoutingOwed` / `HTQ-18-06` discharged); this note records what moved.
>
> - **`L-01` / `ss18l1` is now a MEDIUM** and has **LEFT this bundle**. Mediums are submitted
>   individually, so its body now lives at **`submissions/L-01.md`**. A **pointer stub** remains
>   below under "Low Risk Findings" so the move is visible and nothing is lost. It is the
>   **contested call of the run** (`HTQ-18-06`) and is flagged for deliberate human triage.
> - **`M-02` / `ss18m2` is now a LOW** and has **JOINED this bundle** — its full L-tier section is
>   below, after `L-03`. **That section is its canonical home.** `submissions/M-02.md` is retained in
>   place as the long-form detailed write-up, with its banner pointing back here.
>
> **Labels and severities therefore intentionally disagree on two findings.** `L-01` is a Medium and
> `M-02` is a Low. Labels are run-scoped and issueIds encode the *original* label, so neither is ever
> renumbered or re-minted on a severity change — read severity from the stated severity, never from
> the letter in the label or the issueId.
>
> Post-change run totals: **0 High, 2 Medium (`ss18m1`, `ss18l1`), 4 Low (`ss18m2`, `ss18l2`,
> `ss18l3`, `ss18f4`), 3 QA, 1 non-severity-bearing faithfulness item.**

## Summary

**Bundle membership after the post-review routing change** (this table counts what is actually in
this file, not what was in it as first written):

| Severity | Count | Members |
|----------|-------|---------|
| Low Risk | 3 | `M-02` (`ss18m2`), `L-02` (`ss18l2`), `L-03` (`ss18l3`) |
| QA | 2 | `Q-01` (`ss18q1`), `Q-02` (`ss18q2`) |
| Centralization | 0 | — |
| **Total** | **5** | |

No centralization findings were raised this run.

**Membership changes, stated explicitly.** `M-02` / `ss18m2` **entered** this bundle (Medium → Low);
`L-01` / `ss18l1` **left** it (Low → Medium) for `submissions/L-01.md`, leaving a pointer stub. The
bundle total is unchanged at **5** because the two swapped places. The run's fourth Low, **`F-04` /
`ss18f4`**, is **not** in this bundle: it is a Law-2 faithfulness item and is reported in
`submissions/spec-conformance.md`, per the standing rule that story/spec deviations never enter the
QA bundle.

A further six Tier-1 (SAST) items were raised and dispositioned without being filed as findings.
They are recorded in **Appendix A** so the dispositions are auditable rather than invisible.

---

## Low Risk Findings

### [L-01] — MOVED OUT OF THIS BUNDLE: it is a **MEDIUM**, filed individually <!-- id: ss18l1 -->

> **Pointer stub — the body of this finding has moved. Nothing has been deleted.**
>
> **`L-01` / `ss18l1` — "The shortfall top-up mints phUSD directly against `FlaxToken`, bypassing both
> of `PhusdStableMinter`'s controls"** was raised **Low → MEDIUM** post-review (2026-09-01), on an
> independent severity-auditor overturn adjudicated and **accepted** by the coordinator.
>
> **Per C4 convention, Mediums are submitted individually.** Its full write-up — description, the
> `:646-647` quotation, the `PhusdStableMinter` contrast, the PoC and its size-independent control,
> the raise basis and the mitigation — now lives at:
>
> ### → **`submissions/L-01.md`**
>
> **Ledger fingerprint:** `9c5733dfad13be7c8d41c0dd5b00b5eae19587eba3169b5f8f00310f3237c027`
>
> **The label `L-01` and the issueId `ss18l1` are retained and are NOT severity claims.** IssueIds are
> minted once from the *original* label and are never re-minted on a severity change. This is a
> **Medium** carrying a label beginning with "L".
>
> **It is the CONTESTED CALL OF RUN 18** (`HTQ-18-06`) — two agents disagreed and the coordinator
> adjudicated for Medium, on the Law-1 ground that an under-filed structural mint-control bypass is
> the more expensive error. A human triager should re-weigh it deliberately, in `L-01.md`.
>
> **This item is no longer part of the QA bundle** and is excluded from the bundle counts above.

---

### [L-02] The internally-computed `minPhUSDOut` is tautological and can never bind <!-- id: ss18l2 -->

**Location**: `src/StableStakerV2.sol#L672-L688` (`_annihilateMeasured`)

**Description**

`_annihilateMeasured` computes the floor it passes to `Antimatter.annihilate` in the argument list of
that same call:

```solidity
// src/StableStakerV2.sol:681-686
antimatter.mint(address(this), annihilatable);
IERC20(token).forceApprove(address(antimatter), netUsed);
antimatter.annihilate(
    token, address(this), annihilatable, annihilatable + stableMinter.calculateMintAmount(token, netUsed)
);
IERC20(token).forceApprove(address(antimatter), 0);
```

`Antimatter` checks `totalPhUSD = amount + mintedForStable` against `minPhUSDOut`, and
`mintedForStable` is produced by exactly the same `calculateMintAmount` on exactly the same
`(token, netUsed)`, with no fee and no partial fill:

```solidity
// lib/antimatter/lib/phUSD-stable-minter/src/PhusdStableMinter.sol:212, 232
uint256 phUSDAmount = calculateMintAmount(stablecoin, amount);
...
IMintableToken(phUSD).mint(msg.sender, phUSDAmount);
```

So `totalPhUSD == minPhUSDOut` **identically, with zero margin, on every call**. The guard cannot
fire.

Neither hazard the NatSpec claims it defends against is catchable here:

```solidity
// src/StableStakerV2.sol:664-667
*      `minPhUSDOut` is `annihilatable + calculateMintAmount(token, netUsed)` — an EXACT floor on
*      what is actually being annihilated. Passing zero would waive Antimatter's only guard
*      against the exchange rate moving, or a mint cap biting, between this quote and the burn,
*      and would turn any such movement into silent extra inflation on the top-up above.
```

- **Rate movement between quote and burn** cannot occur: the quote is evaluated in the *argument
  expression of the very call it guards*, so there is no intervening external call and therefore no
  window for the rate to move in.
- **A `maxMintPerDay` bite** cannot be caught by a floor: the cap **reverts**
  (`require(... , "Daily mint limit exceeded")`, `PhusdStableMinter.sol:221`) rather than
  under-delivering, so the transaction is already gone before any floor is compared.

**Known-issue interaction**

This is **not suppressed**, and the direction matters: known issue **N32** is the item that *asserts*
this floor "remains the only in-path guard against the exchange rate moving, or a mint cap biting".
A known issue cannot suppress the finding that refutes its own stated rationale — N32 is materially
weakened wherever it is cited for that proposition.

**Recommendation**

Either give the floor real margin from an independent quote source (one read before the call, not
inside it), or delete it and correct the NatSpec at `:664-667` and `:1170`-adjacent prose that claims
protection it does not provide. A guard that reads as protection but is provably inert is worse than
no guard, because it deters the addition of a real one.

---

### [L-03] Sub-unit backlog is stranded once emissions stop <!-- id: ss18l3 -->

**Location**: `src/StableStakerV2.sol#L540-L547` (`autoAnnihilate`), `#L705` (`emergencyWithdraw`)

**Description**

For a user with non-zero principal whose owed reward satisfies `0 < owed < scale`:

```solidity
// src/StableStakerV2.sol:537-547
uint256 principalAsAntimatter = user.amount * scale;
// Capped at the caller's own principal, then floored to something `token` can express:
// toStableAmount reverts on a finer amount rather than rounding it away.
uint256 capped = owed < principalAsAntimatter ? owed : principalAsAntimatter;
netWanted = capped / scale;
// The ONLY excess left: reward with no principal to annihilate it against. The exit
// haircut no longer displaces anything, because the protocol tops the payout up.
excess = owed - capped;
require(netWanted > 0 || excess > 0, "StableStaker: nothing to annihilate");
// The sub-unit remainder, carried in the mapping rather than paid out.
unclaimedReward[token][msg.sender] = capped - netWanted * scale;
```

With `owed < principalAsAntimatter` we get `capped == owed`; with `owed < scale` we get
`netWanted == 0`; and `excess == owed - capped == 0`. The `require` at `:545` therefore reverts
`"StableStaker: nothing to annihilate"`.

Ordinarily this is a transient dust window that the next accrual clears. It becomes terminal once
`antimatterPerDay` is `0` — the backlog can never grow past `scale` again — and `claimEnabled` is
false. In that state the user has **no reward path at all**:

- `claim` is shut (`claimEnabled == false`);
- `autoAnnihilate` reverts at `:545`;
- `emergencyWithdraw` returns principal but **zeroes the backlog**:

```solidity
// src/StableStakerV2.sol:704-705
// Forfeit the backlog too: the hatch stays the single rule "no reward, principal out".
unclaimedReward[token][msg.sender] = 0;
```

*(The forfeiture is at `:705`; earlier internal notes cited `:702`, which is the `user.amount = 0`
line. The mechanism is unchanged.)*

The amount at stake is bounded by one `scale` unit — dust — which is why this is Low and not higher.

**Relationship to existing ledger entries — deliberately kept separate**

- This is the **rebirth of open entry `7e86c0cf` (ss17l4)** on a *new revert site*. That entry's
  original revert (`"exit shortfall"` on a sub-share-price amount) was deleted along with
  `previewExitFor`; the dust-window liveness class survived and now trips
  `require(netWanted > 0 || excess > 0)` instead. Recorded explicitly so the rebirth is not buried
  inside a moot-by-deletion disposition of the ancestor.
- It is **NOT** a duplicate of open entry `fb7a089a` (ss17l3), which is a **zero-principal** holder on
  a **Migrating** pool. This one is **non-zero principal**, sub-unit owed, on an **Active** pool with
  emissions stopped. Different precondition, different fix. A human at `/ledger` may choose to merge
  them; this report does not.

**Recommendation**

Allow a sub-unit backlog to be swept (or folded forward into the next accrual) rather than reverting —
for example, treat `netWanted == 0 && excess == 0 && unclaimedReward > 0` as a no-op success that
leaves the remainder in place, so the call composes instead of blocking a UI flow.

---

### [M-02] `autoAnnihilate` consumes the shared underwater-withdrawal buffer <!-- id: ss18m2 -->

> **Severity: LOW.** Lowered from Medium post-review (2026-09-01) on an independent severity-auditor
> overturn, adjudicated and **accepted** by the coordinator. **The label `M-02` and the issueId
> `ss18m2` are retained and are NOT severity claims** — issueIds are minted once from the *original*
> label and are never re-minted on a severity change. This is a **Low** carrying a label beginning
> with "M". Per C4 convention it therefore belongs in this bundle, which is why it appears here.

**Ledger fingerprint**: `5b6ea4c61d88e942d4d9f36495cb62b3397d3b305ba0d53aab107611f8ea5398`

**Location**: `src/StableStakerV2.sol#L560-L562` (`autoAnnihilate`); secondary site
`src/StableStakerV2.sol#L1313-L1324` (`_routeExit`, underwater branch)

**Full write-up**: `submissions/M-02.md` — retained in place as the detailed record (PoC output,
negative controls, re-file disclosure, reconciliation). **This section is the canonical home**; the
individual file is the long form and its banner points here.

**Mechanism**

`autoAnnihilate` routes its principal exit through `_routeExit` with the underwater guard on. On the
underwater branch `_routeExit` returns the full requested amount **without any token arriving from
the strategy** — it writes recorded principal down and signals "use the buffer" — and the idle stable
balance is then actually spent when `Antimatter` is approved to pull it. So the **reward** path every
staker is steered into while `claimEnabled` is false draws on the shared underwater-**withdrawal**
buffer. On that same branch the advertised top-up does not fire (`received == gross == netWanted` ⇒
`delivered == target` ⇒ `phUSDMinted == 0`), so the shortfall is paid out of pooled assets rather
than out of fresh phUSD.

**The load-bearing premise is FALSIFIED by the source**

The finding was filed at Medium on an **asymmetry** claim: that `withdraw` consumes the buffer 1:1
with a position *leaving*, while `autoAnnihilate` is a repeatable reward action whose caller *keeps*
their position. That is **not what the code does**. `autoAnnihilate` debits principal identically, at
`src/StableStakerV2.sol:554-560`:

```solidity
gross = netWanted > user.amount ? user.amount : netWanted;
user.amount      -= gross;
pool.totalStaked -= gross;
```

Every call burns principal **1:1 exactly as `withdraw` does**, and `netWanted` is capped at the
caller's own principal (`netWanted = min(owed, user.amount * scale) / scale`) — making
`autoAnnihilate` a **strictly narrower** buffer consumer than a same-size `withdraw`, not a broader
one. The cited debit triple was independently re-read at `cf8de27` before the downgrade was applied
and reproduces as quoted.

**The PoC's control is the wrong control**

`PoC_ss18m2_BufferSpend.t.sol` (audit-authored, in `workspace/` — **not** a project test) passes 4/4,
but its counterfactual is *"buffer intact"* versus *"Alice's `autoAnnihilate`"*. The **correct**
control is *"Alice's `withdraw(dai, 50 ether)`"* versus *"Alice's `autoAnnihilate(dai)`"*. In the
PoC's own setup an equivalent-size `withdraw` routes the identical underwater branch, draws the
identical `50e18`, and **denies Bob identically**. Bob is therefore **not an incremental victim**
against the right baseline — which is precisely the premise the re-file basis claimed to falsify in
won't-fix `69c7666e`. **Re-file basis #2 does not survive**; the disclosure on `69c7666e` has been
amended accordingly, and that entry's won't-fix status is unchanged by this run.

**What survives, at Low**

Re-file basis #1, **partially**, as a **rate** argument. `69c7666e` sized the buffer against
**withdrawal** demand; while `claimEnabled` is false, a staker who wants only their *reward* is
**forced** into a principal exit that draws that buffer. That shifts the **rate** of buffer
consumption above what voluntary-exit demand predicts. It is a **likelihood** argument on an
**already-accepted mechanism**, with an **unchanged ceiling** — which is Low, not Medium.

**Reopen trigger (armed, human-actionable), verbatim**

> Restore to Medium if a PoC control demonstrates `autoAnnihilate` drawing buffer that an
> equivalent-size `withdraw` by the same caller could not — e.g. a path where `autoAnnihilate` draws
> without a matching `user.amount` debit, or where a per-caller draw exceeds their principal.

Actionable by a human at `/ledger`, or by any later run that lands such a PoC control.

**⚠ THIS DOWNGRADE IS NOT AN INTENT-BASED SUPPRESSION**

It does **not** rest on design intent, **not** on `CLAUDE.md`, and **not** on
`test/AutoAnnihilate.t.sol:389` (which *is* present at `cf8de27` and *does* evidence intent). It
rests **solely** on the source-level falsification of the asymmetry claim and on the PoC's missing
control.

**The N19 no-suppression-authority ruling STANDS, unchanged.** The run-18 known-issues re-extraction
rules on it twice — *"N19 — caveat STANDS, no suppression authority ... N19 evidences intent and
nothing more"*, and sanitizer usage rule 3, *"N19 suppresses nothing (unanchored self-citation)"*.
**MR-18-02 remains a live contested ruling in `manual-review.json`.** Nobody may later re-read this
Low as intent-based suppression.

**Cross-references**

- **F-04 / `ss18f4` is UNAFFECTED** by this downgrade and is now the **primary surviving artifact** of
  this line — the `:485-488` NatSpec invariant text is false as written on the underwater branch
  regardless of how this finding resolves. It must not be swept up here.
- **COMPOUND-18-A**: with **L-03 / `ss18l3`**. Strategy underwater with the buffer exhausted +
  `claimEnabled` false + `emergencyWithdraw` zeroing the backlog at `StableStakerV2.sol:705` leaves a
  staker with **no non-forfeiting reward path**, and the stranded amount is then the **full backlog**.
  `setClaimEnabled(true)` clears it in one owner transaction, so **Low stands for each member** — the
  compound is recorded so the interaction is visible, not to escalate either.
- **`d84cdfd4`** (proposed fixed) — closing it must **not** be read as authority to suppress this.
- Reborn from **`eff1ce4b`** (L-05, run 17), whose specific root cause (the tolerance-inflated `gross`
  draw) was deleted with `previewExitFor` — **moot by deletion, explicitly not "fixed"**.

**Recommendation**

Do not let the reward path consume the withdrawal buffer — gate `autoAnnihilate` on `!_isUnderwater`
(rewards are deferrable; a solvent exit is not), or reserve the buffer against outstanding withdrawal
demand so a harvest can never consume the last unit a withdrawal needs. See `M-02.md` for the full
options and the independent documentation fix (**F-04**).


---

## QA

### [Q-01] The `gross` clamp is provably redundant but fails silently rather than loudly <!-- id: ss18q1 -->

**Location**: `src/StableStakerV2.sol#L550-L554` (`autoAnnihilate`)

**Description**

```solidity
// src/StableStakerV2.sol:550-554
// Request exactly the net the annihilation needs. `netWanted` is ALREADY capped at the
// caller's principal above (`capped = owed < principalAsAntimatter ? ...`), so this
// second clamp is belt-and-braces rather than load-bearing — kept because the debit
// below underflows if it is ever wrong.
gross = netWanted > user.amount ? user.amount : netWanted;
```

The clamp is genuinely redundant **at HEAD**: `capped <= user.amount * scale` implies
`netWanted = capped / scale <= user.amount`, so `gross == netWanted` always.

The problem is the **failure mode if that premise is ever broken**, not the redundancy. Downstream,
`netUsed` clamps against `netWanted` and the frictionless `target` is sized on `netWanted`:

```solidity
// src/StableStakerV2.sol:578-580
uint256 netUsed = received < netWanted ? received : netWanted;
annihilatable = netUsed * scale;
(phUSDPaid, phUSDMinted) = _annihilateAndTopUp(token, netUsed, netWanted, scale);

// src/StableStakerV2.sol:640
uint256 target = netWanted * scale + stableMinter.calculateMintAmount(token, netWanted);
```

So if a refactor ever made `netWanted > user.amount`, the contract would exit for the *clamped*
`gross` but pay a target sized on the *unclamped* `netWanted` — minting the difference as free phUSD
— instead of reverting.

The in-source justification is backwards. "the debit below underflows if it is ever wrong" is not
true: the debit is `user.amount -= gross` (`:559`), and `gross` **is** the clamped value, so the
clamp is precisely what *prevents* the underflow from ever surfacing. The comment credits the clamp
with a loud failure it in fact suppresses.

**Recommendation**

```solidity
require(gross == netWanted, "StableStaker: gross/netWanted divergence");
```

so the premise fails loudly at the point it breaks, rather than silently paying an undebited target.

**Why QA and not higher**: no value is at risk at `cf8de27` — the premise holds. C4 treats
speculation on future code without a demonstrated live root cause as invalid, so this is filed at QA
on the strength of the *misleading comment plus silent failure mode*, not on a claimed vulnerability.

*Note: this item was raised independently by two Tier-2 agents (code-scanner and econ-scanner) on the
same line with the same recommendation. That is recorded as corroboration, and both write-ups are
merged above; it is not two findings.*

---

### [Q-02] `AutoAnnihilated` gained two fields; the ABI break's "free" premise is only half-verified <!-- id: ss18q2 -->

**Location**: `src/StableStakerV2.sol#L183-L190` (event), `#L519` (function)

**Description**

Story 028 made two ABI-breaking changes. The **function signature** change —
`autoAnnihilate(address,uint256)` → `autoAnnihilate(address)` — is documented verbatim by known issue
**N32** and is suppressed accordingly. What N32 does **not** address is the event:

```solidity
// src/StableStakerV2.sol:183-190
event AutoAnnihilated(
    address indexed token,
    address indexed user,
    uint256 antimatterBurned,
    uint256 principalConsumed,
    uint256 excessMinted,
    uint256 phUSDPaid,
    ...
);
```

Two fields (`phUSDPaid`, `phUSDMinted`) were added. Unlike a signature change, an event topic change
**fails silently**: an indexer keyed on the old topic simply stops matching. There is no revert, no
failed transaction, and nothing on-chain to notice.

**The unverified premise**

N32 justifies the break as "free because V2 is undeployed and `phase-2-staging` has no V2 deploy
script" — story-028 states the same:

> "Breaking ABI change, and free — V2 is undeployed and `phase-2-staging` has no V2 deploy script."
> — `028-cover-annihilation-shortfall-with-minted-phusd.md:344-345`

That is a **checkable factual claim about a sibling repository**, and this run checked only the
in-repo half. At `cf8de27`, `src/interfaces`, both migrators (`CrossVersionMigrator`,
`InPlaceMigrator`) and `src/versions` were grepped: **no consumer**. **`phoenix-phase-2-staging` was
NOT checked.**

The premise is therefore **unverified, not false**. It is carried here as an open cross-repo
obligation rather than asserted as a defect — dropping it would silently discard the only unverified
load-bearing premise in the change.

**Open obligation**

> **Repo**: `phoenix-phase-2-staging` — confirm that no V2 deploy script, script helper, test or
> indexer binds `autoAnnihilate(address,uint256)` or the old `AutoAnnihilated` event topic.

**Recommendation**

Discharge the cross-repo check above. If any indexer binds the old topic, consider emitting the old
event alongside the new one for one release rather than relying on consumers noticing a silent stop.

---

## Appendix A — Tier-1 (SAST) items raised and dispositioned

These are **not findings**. They are recorded so the dispositions are visible and auditable, per the
project rule that recall beats report-tidiness and that a set-aside item is parked in a visible
channel rather than a log nobody reads. Full records live in
`reports/stable-staker/18/manual-review.json` (MR-18-S1..S4) and
`reports/stable-staker/18/deduplicated-findings.json` (`staticAnalysisDisposition`).

| ID | Tool / check | Location | Disposition |
|----|--------------|----------|-------------|
| S-01 | Slither `divide-before-multiply` | `StableStakerV2.sol:541`, `:579` | **RESOLVED-BENIGN** |
| S-02 | Slither `incorrect-equality` | `StableStakerV2.sol:676` | **FALSE POSITIVE** |
| S-03 | Slither `uninitialized-local` (x3) | `StableStakerV2.sol:568-570` | **FALSE POSITIVE** |
| S-04 | Slither `timestamp` | `StableStakerV2.sol` (emission accrual) | **FALSE POSITIVE** |
| S-05 | Slither `unused-return` | `_stakers.remove` | **FALSE POSITIVE** |

**S-01 — divide-before-multiply at `:541` / `:579`. RESOLVED-BENIGN.**
The pattern is the *deliberate* sub-unit dust carry documented by N2/N17:

```solidity
// src/StableStakerV2.sol:541, 547
netWanted = capped / scale;
unclaimedReward[token][msg.sender] = capped - netWanted * scale;
// src/StableStakerV2.sol:579
annihilatable = netUsed * scale;
```

The truncated remainder is not lost — it is written back to `unclaimedReward` at `:547`. Independently
of the tool, the code-scanner **proved** the decimals arithmetic correct in **both directions** with a
worked 6-decimal example. Two independent lines of evidence, so this is a proof rather than a triage
guess.

**S-02 — `annihilatable == 0` at `:676`. FALSE POSITIVE.**
The comparison is against an internally computed `uint256` (`netUsed * scale`, `:579`), not against an
oracle reading or a token balance. The strict-equality hazard the rule models — an externally
influenced value that can be nudged past an exact boundary — does not apply.

**S-03 — three uninitialized locals at `:568-570`. FALSE POSITIVE.**
`annihilatable`, `phUSDPaid` and `phUSDMinted` are each assigned on every reachable path before use;
where the `gross > 0` branch is not taken, the zero value is the intended one and is what the event
at `:591` reports.

**S-04 — `block.timestamp` dependence. FALSE POSITIVE.**
Emission accrual is intentionally time-based at **day** granularity. Miner/proposer timestamp drift is
orders of magnitude below that granularity, so the manipulation the rule models cannot move the
result.

**S-05 — unused return on `_stakers.remove`. FALSE POSITIVE for this run's changed surface.**
`EnumerableSet.remove`'s boolean is genuinely not needed at `:563`; membership is already implied by
`user.amount == 0`. Noted for continuity: an unused-return item is already an **open** informational
ledger entry at `7b0717792d` (EnumerableSet `add`/`remove`). The S-05 instances were cross-checked
against it and do **not** land on that entry's sites, so they belong here and not there. Recorded so a
later run does not re-derive the distinction.

*Two further Tier-1 dispositions are recorded in `deduplicated-findings.json` and are noted here only
for completeness: Aderyn's HIGH reentrancy (**A-01**) is resolved-benign — every implicated function
carries `nonReentrant` and OpenZeppelin's guard is contract-wide, so the cross-function variant the
tools model cannot occur; and Aderyn's batch-DoS on `InPlaceMigrator` (**A-03**) reconciles to four
**open** ledger entries in the existing migration slice-ordering cluster (`59eebbf87b`, `f0cb5f7cdd`,
`bf5018deab`, `bda951d9f1`) and is corroboration of those, not a new finding.*

---

## Appendix B — Automated QA/Gas report (4naly3er)

The canonical C4-style automated report is attached at
**`reports/stable-staker/18/submissions/4naly3er-report.md`** (4,220 lines).

**Provenance and coverage verification.** The report was generated during this run
(`reports/stable-staker/18/static/4naly3er.md`, 2026-09-01) against
`basePath = /home/justin/code/audits/lib/stable-staker` at `cf8de27`, with the scope list passed as
argument 3 (`static/4naly3er-scope.txt`). It was **reused rather than re-run**, on verified coverage:
the report contains 179 `File:` blocks spanning **10 unique files**, a superset of every first-party
in-scope file —

```
src/CrossVersionMigrator.sol
src/InPlaceMigrator.sol
src/StableStakerV2.sol
src/versions/v1/IStableStakerV1.sol
src/versions/v1/StableStakerV1.sol
src/versions/v1/vendor/FlaxToken.sol
src/versions/v1/vendor/IFlax.sol
src/interfaces/IAntimatter.sol
src/interfaces/IPhUSD.sol
src/interfaces/IPhusdStableMinter.sol
```

— i.e. all five files in the project's registered `scope` array plus the two frozen V1 vendor files,
with the three `src/interfaces/` files (nominally `outOfScope`) covered as a bonus. No file in scope
is missing from the output.

The report is **automated tool output, not audit findings**. Per C4 convention its contents are
supplied as a QA/gas baseline; common findings from automated tools without a demonstrated H/M
exploit path are out of scope as findings. Headline counts: 15 gas-optimization classes (notably
185 unchecked-arithmetic opportunities and 86 revert-string-to-custom-error conversions) and the
standard non-critical/low classes. None of the five findings above originates from it.
