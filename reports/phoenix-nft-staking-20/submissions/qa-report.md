# QA Report — phoenix-nft-staking

- **Run**: `reports/phoenix-nft-staking-20/`
- **Commit**: `0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54`
- **Baseline**: `321d0a96d7da9f261517fc53e2d14bf2b49f41c1`

> ⚠ **LABEL-COLLISION GUARD (orchestrator ruling R-3).** Run-20 labels are **run-scoped** and are NOT the
> ledger entries of the same name. Run-20 `H-01` = `1c222d54…` (NFTStakerDepletion.depositFor); ledger `H-01`
> = `858e9e80…` (BatchNFTMinter value-blind nudge gate). Run-20 `M-01` = `fcaca002…` (step-10 sweep); ledger
> `M-01` = `521c20ad…` / `b58b172e…`. Every reference below to a ledger entry is disambiguated **by
> fingerprint**. Never resolve a cross-run reference by label.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 7 |
| QA / Hardening | 5 |
| Centralization | 0 filed (57 instances dropped under Law 3 — see §Centralization) |
| **Total reported** | **12** |

---

## ⚠ 0. LIVE MAINNET OPERATOR ACTION ITEM — read first

**This is the most actionable item in the report and the only one concerning contracts that are live right
now.** It is filed below as **L-01**; it is hoisted here because it requires an owner transaction, not a code
change.

Read-only mainnet verification (block 25572875) found, on **both** deployed `BatchNFTMinter` instances:

| Instance | `pauser()` | `paused()` | Holdings |
|---|---|---|---|
| `0x81896F48…` (RatchetBatchNFTMinter) | `address(0)` | `false` | — |
| `0x86866e01…` | `address(0)` | `false` | **219.99 USDC** (intended, gated bounty) |

`BatchNFTMinter`'s own NatSpec states that `rescueERC20` is *"a race the owner will usually lose"* and that
*"pause first, then rescue"* is the only dependable recovery sequence. `pause()` is `onlyPauser`, so with
`pauser == address(0)` **that sequence cannot be executed**. The documented break-glass for the step-10 sweep
(M-01, `fcaca002…`) and the max-allowance over-spend (M-07, `ad36260f…`) is therefore currently
**unavailable on both live instances**, and the instance that actually holds value is the one with no
dependable recovery path.

**Ask:**
1. **Set a pauser on both live instances** (`0x81896F48…` and `0x86866e01…`).
2. And/or **bound the step-10 refund to the caller's own unspent payment**, which removes the dependence on
   the pause-then-rescue sequence entirely.

---

## Low Risk Findings

### [L-01] Neither live BatchNFTMinter instance has a pauser, so the contract's own documented recovery procedure cannot be executed <!-- id: pns20l1 -->

**Location**: [`src/BatchNFTMinter.sol#L190`](../../../lib/phoenix-nft-staking/src/BatchNFTMinter.sol#L190) (`pauser` / `rescueERC20`)
**Fingerprint**: `919b71fde69248438fb863899a453169bc4af041d6cd1c39424c69e4341ada24`

**Description**: `pauser() == address(0)` and `paused() == false` on both `0x81896F48…` and `0x86866e01…`.
The contract's NatSpec prescribes "pause first, then rescue" as the only dependable recovery sequence, and
`pause()` is `onlyPauser`. `DeployBatchNFTMinter.s.sol:38` even lists an unset pauser as an expected
*intermediate* deployment state, and nothing in script or NatSpec flags that leaving it unset silently
disables the documented procedure.

**Impact**: No direct loss. The documented break-glass is unexecutable on both deployed instances; any
recovery attempt degrades to the race the NatSpec says the owner loses. `0x86866e01…` holds 219.99 USDC.

**Recommendation**: Set a pauser on both instances, and/or bound the step-10 refund to the caller's own
unspent payment. See §0.

**Law-3 framing**: Non-obvious **owner footgun**, not a malicious-owner vector — a competent operator
following the contract's own runbook would be surprised the sequence is unavailable.

---

### [L-02] NFTStakerMigrator has no rescue function of any kind, no fallback and no receive <!-- id: pns20l2 -->

**Location**: [`src/NFTStakerMigrator.sol#L33`](../../../lib/phoenix-nft-staking/src/NFTStakerMigrator.sol#L33) (contract-level)
**Fingerprint**: `cb1b52790cf103d2dd67a1949625b8aefdeb080b951908b2a69968db671b4b42`

**Description**: The sibling `InPlaceNFTStakerMigrator` has both `rescueERC20` (:268) and a floor-guarded
`rescueERC1155` (:281). `NFTStakerMigrator` has neither, plus no `fallback` and no `receive`.

**Impact**: Any ERC20 that lands here — the H-01 misroute, a donation, an airdrop, a fat-fingered transfer —
is permanently unrecoverable by anyone including the owner. This absence is what converts H-01 from a
recoverable accounting misroute into permanent user-fund loss, and is the reason H-01 is High rather than
Medium. Deliberately **not** escalated here: the loss is filed once, at H-01.

**Recommendation**: Add a `rescueERC20`. This is cheap insurance **independent** of the H-01 call-site fix —
if H-01 is fixed only at the `depositFor` call site, this remains the reason any future misroute here is
terminal.

**Do not collapse with**: ledger `Q-01` `8b155727…` (dead immutable `stakedId`) — same contract, different
root cause.

---

### [L-03] The "pause for the migration" remedy halts every registered Phoenix contract; the granular workaround disables the circuit breaker <!-- id: pns20l3 -->

**Location**: [`src/NFTStakerPriceScaledMigrateReady.sol#L344`](../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaledMigrateReady.sol#L344) (`pause` / `setPauser`)
**Fingerprint**: `b48e5bec231a23ebd7b21d31cc24db9891661eb01a0b1ec2d4b098911afaf62d`

**Description**: `pause()` is `onlyPauser` and the registered pauser is the ecosystem-wide `Pauser`, whose
`pause()` halts **every** registered Phoenix contract at once and whose `unpause()` is `onlyOwner`. Pausing
this staker for a multi-slice migration therefore halts the whole ecosystem for hours or days. Repointing
`pauser` via `setPauser` for granular control disables the global circuit breaker for this staker during
exactly its most sensitive window, and breaks the Pauser's registry invariant (`Pauser.register` validates
`pausable.pauser() == address(this)`).

**Impact**: No value at risk. Two operational hazards: ecosystem-wide availability loss, and safety-mechanism
removal plus a broken registry invariant.

**Recommendation**: Fix M-05 (`bdf84579…`, un-gated `stake()`) in code with a `poolState` gate so the pause
remedy is never needed. If pause must be used, document the ecosystem-wide blast radius as an explicit
runbook warning and do **not** repoint `pauser`.

**Law-3 framing**: Non-obvious owner footgun — only the *scope* of the halt is the surprise.

---

### [L-04] `setMigrator` has no lifecycle gate and can be rotated while a migrator holds users' parked ERC1155 <!-- id: pns20l4 -->

**Location**: [`src/NFTStakerPriceScaledMigrateReady.sol#L339`](../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaledMigrateReady.sol#L339) (`setMigrator`)
**Fingerprint**: `066eccff0974e714bf4c92fd23345c1986dd7805411ef1732eccb48a1348cf2f`
**PoC**: `workspace/phoenix-nft-staking/test/PoC_Local002_005_MigrationFootguns.t.sol` — `testSetMigratorMidMigrationOrphansParkedStake` **PASS**

**Description**: `depositFor` is `onlyMigrator`, so rotating the pointer mid-migration immediately bricks the
old migrator's `migrateIn`. Parked stake can then leave only via `claimTimedOut`, which returns **stake only**
and drops the user out of the pool with no re-accrual and no automatic re-entry. The new migrator cannot reach
the parked ERC1155 either — it sits behind the `totalParked` floor enforced by `rescueERC1155`.

**Impact**: Principal is never lost and the rotation is reversible before any timeout elapses. The harm is
lost yield-continuity and an unplanned manual re-entry for N users.

**Recommendation**: Gate `setMigrator` on `poolState != Migrating`, or on `totalParked == 0`.

> ⚠ **FIX TRAP — trips standing `WATCH-19-L01-incomplete-fix-trap` (D-08).** Do **NOT** "fix" this by
> repointing `claimTimedOut` / `rescueERC1155` to `newId`. The migrator physically holds `oldId`, so those two
> functions currently **work**; repointing them would break a working hatch and a working floor.

---

### [L-05] story-021's `_recomputeSchedule()` in `finalizeAndReset` introduces two external calls into the only path back to Active <!-- id: pns20l5 -->

**Location**: [`src/NFTStakerPriceScaledMigrateReady.sol#L931`](../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaledMigrateReady.sol#L931) (`finalizeAndReset`)
**Fingerprint**: `69e60136d0025131e6a85476983a8007d5dcd82f485e18fe8a66b56670784245`

**Description**: The price-scaled delta adds `nftMinter.configs(dispatcherIndex)` and
`dispatcherHook.mintDebt()` to `finalizeAndReset` (`NFTStakerDepletion.finalizeAndReset` makes no external
calls). Either dependency reverting wedges the pool in `Migrating`, which blocks
`InPlaceNFTStakerMigrator.migrateIn` because `depositFor` requires Active. **The recompute itself is correct**
for the emission model — it closes the depletion copy's ledgered `L-02` on this copy — the finding is the new
dependency it drags in.

**Impact**: Availability only, and verified non-terminal **by execution**: `setDispatcherHook(address(0))` is
ungated, performs no recompute, always succeeds and immediately un-wedges. `setNFTMinter` is legal once
drained; parked stake exits via `claimTimedOut` regardless; `emergencyWithdraw` bypasses the hook entirely.

**Recommendation**: Wrap the two calls in `try/catch`, or document `setDispatcherHook(address(0))` as the
runbook un-wedge step.

**Do not collapse with**: L-06 — different dependency failures, different call sites, different remedies.
**Related ledger entry**: `51e8255bf7097d92215821e8b3dba8a78330008ace63e249346d1d847c406f9b` (L-02, open).

---

### [L-06] A staker wired to a `BalancerPoolerMintDebtHook` on which it is not the recipient reverts on EVERY `_syncBudget` path <!-- id: pns20l6 -->

**Location**: [`src/NFTStakerPriceScaledMigrateReady.sol#L467`](../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaledMigrateReady.sol#L467) (`_syncBudget`)
**Fingerprint**: `1887dbe136137b79a1aca4bfaa383d2a0b5f465d7601943c512dc775c11d7e22`
**Severity ceiling**: `medium` (recorded, not resolved)

**Description**: `pull()` is `onlyOwnerOrRecipient` and additionally reverts `RecipientUnset` when
`recipient == address(0)`. The staker calls it with `msg.sender == itself`, so `stake`, `unstake`, `claim`,
`depositFor`, `initiateMigration` and `pullAndRefresh` **all revert unconditionally — even when `mintDebt` is
zero**. In a cross-staker migration the target staker is *by construction* not yet the hook's recipient, so
wiring its `dispatcherHook` before flipping `hook.setRecipient` bricks the migration at the first
`depositFor`, leaving a partially-executed migration with the batch's ERC1155 already pulled into the migrator.

**Impact**: Availability only — no value at risk. `emergencyWithdraw` and `userMigrate` never call `pull()`,
so principal always escapes. Two independent owner-side un-brick routes exist (flip `hook.setRecipient`, or
`setDispatcherHook(address(0))`).

**Recommendation**: Document the wiring **order** as a mandatory runbook step — flip `hook.setRecipient`
**before** `setDispatcherHook` on the target — and add an orchestrator test that wires a real
recipient-guarded hook to the target. The in-repo tests never do, so the ordering constraint is currently
both untested and undocumented.

**Disclosed against (not collapsed)**: ledger `L-02` `966e717669f973ff2fff36e5ed65fb98e287700bbdfc5ab4e8047407d8b5b8b4`
(open, `src/NFTStakerDepletion.sol`) — same "hook bricks every `_syncBudget` path" class recurring on copy #4
via a **different** trigger (recipient authorisation on `pull()`, vs a reverting/unauthorized hook).

**Severity note**: held at Low on clean recoverability. If the operator judges a half-executed migration with
custody already moved to be an availability *event* rather than a config slip, Medium is defensible.

---

### [L-07] Fork-drift hazard escalated from precaution to REALISED defect — the watch must widen from three clones to four <!-- id: pns20l7 -->

**Location**: [`src/NFTStakerPriceScaledMigrateReady.sol`](../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaledMigrateReady.sol) (whole file)
**Fingerprint**: `368e23fb225d75185b20ddcda98c0fbb999bb74cacf2fed7c0f6e520ae38dfcb`
**Faithfulness twin**: `F-20-04`

**Description**: The repo now carries **four** hand-maintained ~1000-line stakers (`NFTStaker`,
`NFTStakerPriceScaled`, `NFTStakerDepletion`, `NFTStakerPriceScaledMigrateReady`) with no shared base. The new
file is a copy of a copy, and its own header states "Any future fix or audit change to either is NOT
automatically inherited." The anticipated failure mode **materialised inside the commit that created the
fourth clone**: story-021 named the `_safePay` → `_safePayTo` bug in its own body, called it "wrong in every
case", fixed it **only in the new copy**, and declared `NFTStakerDepletion.sol` untouched (verified true).

**Impact**: No direct impact; this is the structural cause and H-01 is the realised instance. Filed Low as a
standalone structural finding so the concrete loss is not double-counted.

**Recommendation**: Extract a shared base, or run a mandatory **4-way diff** on every staker change.

> ⚠ **`InvariantForkParity.t.sol` green is SCOPE-LIMITED and does not discharge this watch.** 3/3 PASS at
> 128k calls, but it compares **copy #2 against copy #4 only**, includes no `NFTStakerDepletion`, and exposes
> **no migration surface**. It does not test the `_safePay` drift at all. **A green forkParity is not evidence
> that fork drift is absent.**

**Watch-note consequence**: `WATCH-17-maintenance-coupling-drift` — **ESCALATE and WIDEN**, from a
precautionary 3-way diff to a mandatory 4-way diff, and from PRECAUTION to REALISED DEFECT.

**Standing direction rules preserved**:
- story-020's depletion rate/window fix must **NOT** be mirrored into the APY/runway copies (D-05).
- An eventual ledger `M-02` `emergencyWithdraw` rewardRate-resize **MUST** be mirrored into all four copies.
- The H-01 `_safePayTo` fix **MUST** be checked against all four copies before closing.

---

## QA / Hardening Findings

### [Q-01] The §6 witness for §4.5 never configures donations, so it certifies a property that is false in production <!-- id: pns20q1 -->

**Location**: [`test/BatchNFTMinterMultiTokenNudge.t.sol#L656`](../../../lib/phoenix-nft-staking/test/BatchNFTMinterMultiTokenNudge.t.sol#L656) (`test_DuplicateRewardTokenFailsClosed`)
**Fingerprint**: `cabd4a3d4f08fa7117e54b76c885f937390e46d83b32b440ff316e6b11a78489`
**Faithfulness twin**: `F-20-02`

**Description**: The witness calls `_fundPots()` only and never calls `nftMinter.setPerMintDonations(...)`,
so it runs at **D == 0** — the single configuration in which the §4.5 "fails closed" claim happens to hold.
It passes green while **M-02** (`a62fe01a…`, duplicate `rewardTokens` entries) is live on exactly the property
it claims to certify. The sibling §4.2 witnesses **do** configure donations, so the omission is inconsistent
*within the same file* — not a deliberate scoping choice.

**Impact**: No code defect and no value impact — the defect is in the assurance layer. False certification of
an in-scope `src/` property.

**Adjudication — stated as a rule, not a one-off**:

> `test/` in an `outOfScope` array excludes **hunting for vulnerabilities located inside test code**. It does
> **not** immunise the **assurance claim** the suite makes about in-scope `src/` code.

A finding of the form "the harness itself is exploitable" is out of scope — nobody deploys the harness. A
finding of the form "**the certification is false**" is a finding about in-scope code's assurance status, and
its file path is incidental; the blast radius is entirely in `src/`. Decisive here: the witness runs at
`D == 0`, passes green while a live Medium exists, and sibling witnesses in the same file do configure
donations. This project also has a recorded prior instance of exactly this failure mode (the "vacuous
invariant harness").

**Recommendation**: Re-arm the witness with a donating dispatcher as part of the M-02 fix.

**Do not collapse with M-02.** Merging them lets the coverage regression vanish the moment the code fix lands,
leaving the suite permanently unable to catch the class again.

---

### [Q-02] The mid-loop `onERC1155Received` attacker surface is real and attacker-controlled; the guard holds but NO test in the suite reaches it <!-- id: pns20q2 -->

**Location**: [`src/BatchNFTMinter.sol#L364`](../../../lib/phoenix-nft-staking/src/BatchNFTMinter.sol#L364) (`batchMint`)
**Fingerprint**: `d0ed2cf440cf1612c112207d2e7c2a8036a1547d2874e79cadd19c291020029b`

> 🔒 **LOAD-BEARING QA CEILING — valid at QA, KNOWN-INVALID if escalated.**
> The exposure is explicitly **future** ("any change dropping `nonReentrant` re-opens the surface") and the
> guard is *proven* to hold today by execution. Escalating this above QA makes it a match for the C4
> known-invalid "speculation on future code without demonstrated root cause". **Ceiling: QA.**

**Description**: The inbound acceptance hook fires once per mint **inside** the loop on a caller-chosen
`recipient` — `count` executions of attacker code between the pre-loop snapshot and the post-loop payout,
while the contract holds the whole payment budget and a live max allowance. The project's mock minter mints
via `MockERC1155.mint()`, a bare balance write that **skips `_checkOnERC1155Received` entirely**, so §4.3 is
certified by a witness that never reaches the hook it was written for. The only reentrancy witness proves the
guard at the reward-token transfer site with an **empty** nested reward array.

Same `test/`-scope rule as Q-01 applies: the finding is about the **assurance claim** on `src/`, not a
vulnerability located in test code.

**Impact**: **Not a live vulnerability.** The guard was proven sufficient by execution (D-21: re-entry reverts
with the exact `ReentrancyGuardReentrantCall` selector; a hook-driven mint pulls from the hook, not the
batcher). The finding is the absence of a regression tripwire.

**Recommendation**: Add a mock minter that actually invokes `_checkOnERC1155Received`, and a reentrancy
witness with a **non-empty** nested reward array.

> ⚠ **Rider on ledger `L-01`.** Its proposed close to `fixed` is **PARTIAL**. Recommendation (a) "add OZ
> `ReentrancyGuard`" is DONE. Recommendation (b) "make the refund credit a recorded amount instead of
> `balanceOf(this)`" is **NOT DONE** and is live as M-01 (`fcaca002…`) and M-07 (`ad36260f…`). Also,
> SAST-104/105 (`InPlaceNFTStakerMigrator.sol:152/:186` modifier order) must **not** be closed by reference
> to it (D-21).

---

### [Q-03] `minRewards` floors the contract's pre-transfer balance, not the delivered amount; a shrinking token additionally reverts the whole batch <!-- id: pns20q3 -->

**Location**: [`src/BatchNFTMinter.sol#L429-L458`](../../../lib/phoenix-nft-staking/src/BatchNFTMinter.sol#L429) (`_payRewards`)
**Fingerprint**: `bfdb50105ed27dc77927f62fe0b3e8f952d7441f072fc43edf2f470b4322b29c`

> 🔒 **LOAD-BEARING QA CEILING — valid at QA, KNOWN-INVALID if escalated.**
> Settled by **D-19** and carried forward unchanged. story-022 §4.4 documents FoT behaviour, so the "unless
> explicitly in scope" carve-out keeps the finding alive — but documenting a risk does not manufacture an
> attack path the value flow does not support: **the caller chooses both the token and the recipient**, the
> fee accrues to the token's own sink (no extraction), and there is **no path where A's token choice costs an
> unrelated B**. Escalating this makes it a plain fee-on-transfer known-invalid. **Ceiling: QA.**

**Description**: The payout amount is a balance snapshot taken before the mint loop and transferred verbatim
afterwards. (a) On a fee-on-transfer token the delivered amount is below the declared floor, so `minRewards`
does not do what a caller reading it as slippage protection would assume. (b) On a negatively-rebasing or
otherwise shrinking token, `safeTransfer(snapshot[i])` reverts and the **whole batch** — all mints, all other
reward tokens — rolls back: a one-token self-DoS on the entire batch.

**Impact**: Bounded by the tax rate on an asset the protocol does not use, borne by a recipient the **caller**
selected.

**Recommendation**: NatSpec reword at `BatchNFTMinter.sol:252-256` attributing the shortfall to `recipient`
rather than "the caller". No code change is required for this finding alone — **but** the D-16 clamp that
fixes M-02 (`a62fe01a…`) also fixes the payout-vs-delivered gap, so evaluate the two jointly.

> **Tier-3 rider — a proven-broken invariant lives here.** `invariant_fotFloor` **FAILS**: delivered
> **95e18** vs declared floor **100e18**, with `fotListedWithFloor: 11` in the census, so the path was
> genuinely exercised (not a vacuous harness). **The executed failure does not change the disposition** —
> a broken invariant is not an automatic Medium. It is recorded here so (i) it is not re-litigated next run,
> and (ii) suppressing this finding would not have deleted the only home of a proven broken invariant.
> Per binding constraint 1b: **do not escalate on `invariant_fotFloor` alone.**

---

### [Q-04] `totalPaid` floors at 0 on a net-positive call and `NudgePaid` emits the snapshot rather than the delivered amount <!-- id: pns20q4 -->

**Location**: [`src/BatchNFTMinter.sol#L384-L459`](../../../lib/phoenix-nft-staking/src/BatchNFTMinter.sol#L384) (`batchMint`)
**Fingerprint**: `47f2dc3addf7c52e6af4e68d7c3f17b57ebf4a6575ee55ed824cbe33714e5cc7`

**Description**:
(a) `totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0` reports **0 net spend** whenever
the contract held a pre-existing payment-token balance — i.e. it reads as a "free batch" on exactly the
transaction where the caller took someone else's pot.
(b) `NudgePaid(recipient, token, amount)` emits `snapshot[i]`, over-reporting delivery on any fee-on-transfer
or negatively-rebasing token.

**Impact**: No direct loss, but it blinds indexers, accounting jobs and UIs on precisely the transactions
where value moved unexpectedly — certain whenever M-01 (`fcaca002…`) or M-07 (`ad36260f…`) fires.

**Recommendation**: Report the true net spend and emit the delivered amount. Fix alongside M-01/M-07 rather
than deferring.

**Do not collapse on the FoT leg**: leg (a) is FoT-independent and survives on plain USDC.

---

### [Q-05] `unstake` sends the ERC1155 out before the tail `_recomputeScheduleIfActive()`, exposing inflated rate/runway views mid-callback <!-- id: pns20q5 -->

**Location**: [`src/NFTStakerPriceScaledMigrateReady.sol#L655-L657`](../../../lib/phoenix-nft-staking/src/NFTStakerPriceScaledMigrateReady.sol#L655) (`unstake`)
**Fingerprint**: `aabf6b89d2e1acb07ea122421c1d9fcdae793eac4af9c1915afcde576c5e35e8`

> 🔒 **LOAD-BEARING QA CEILING — valid at QA, KNOWN-INVALID if escalated.**
> The finding's own text concedes that a grep of `src/` finds **no on-chain consumer** of the inflated
> `pendingReward` / `currentRewardRate` / `runwaySeconds` reads. That is the C4 "unused view functions
> (QA at best)" pattern squarely. **Valid at QA; invalid at Low or above. Ceiling: QA.**

**Description**: `totalStaked` has already shrunk at :655 while `rewardRate` / `windowEnd` are still sized for
the pre-unstake, larger pool when control passes to an arbitrary contract recipient via `onERC1155Received` at
:657. `nonReentrant` blocks every state-mutating re-entry; the exposure is read-only and integrator-facing.

**Impact**: No in-protocol exploit and no consumer today. A **future** protocol pricing against these views
could be fed an inflated read.

**Recommendation**: Move `_recomputeScheduleIfActive()` **above** the :657 transfer. Nothing between them
depends on the transfer, so the change is **free and behaviour-preserving**, and it restores strict CEI.
`stake`, `claim`, `emergencyWithdraw`, `batchMigrate`, `userMigrate` and `_exitPosition` are all already
clean — this is a single isolated call site, not a pattern.

**Convergence**: SAST-008 (Slither `reentrancy-no-eth`) is the **only one of 46** static entries on these
files adjudicated REAL; code-scanner promoted it to CODE-007.

**Disclosed against (not collapsed)**: ledger `L-03`
`d37ab4bb9bf21ad28028d4e03a43b71bb60cb0a214c20b693b1c3f21f7c8c6c5` (open, `src/NFTStaker.sol`) — recurrence of
the same CEI-order defect on copy #4 with a new fingerprint.

---

## ⚠ Escalation gate for the three QA-ceiling findings

**Q-02, Q-03 and Q-05 each carry a load-bearing QA ceiling.** Each is valid exactly where it sits and becomes
a **known-invalid match** the moment it is escalated:

| Finding | Rule that fires on escalation |
|---|---|
| **Q-02** | Speculation on future code without demonstrated root cause |
| **Q-03** | Fee-on-transfer tokens (the §4.4 carve-out keeps it alive at QA, nothing more) |
| **Q-05** | Unused view functions (QA at best) |

**If any later run, agent or reviewer proposes raising one of these above QA, that proposal must re-enter the
validity check before it is accepted.** Do not promote them quietly on the strength of a failing invariant, a
new tool hit, or a fresh reading of the same facts.

---

## Centralization Risks

**No centralization findings are filed in this run.** The suppression is recorded here rather than left
silent.

**D-12 — 57 Aderyn "Centralization Risk" instances dropped under Law 3.** They cover owner control of
`setTargetAPY`, `setDispatcherHook`, `topUp` and similar. The owner is trusted and these are by design
(registry known-issue #1); "a malicious owner could…" is noise in a self-audit. The count and rationale are
preserved in the output JSON's `filterPolicy.centralizationNote` and here, so the suppression is auditable.
(4naly3er independently reports 64 instances of the same class — see Appendix A, M-2; same disposition.)

**Confirmed NOT swept up with them:** the three **non-obvious owner setters** survive as filed findings,
because Law 3 protects *knowing* owner actions, not footguns:

| Setter | Filed as |
|---|---|
| `setMigrator` | **L-04** (`066eccff…`) — rotation orphans parked custody |
| `setPauser` | **L-03** (`b48e5bec…`) — granular workaround disables the global circuit breaker |
| `setDispatcherIndex` | **M-06** (`fb17fc6d…`) — nothing ties `primeToken` to the contract's funding assets |

The Law-3 register is clean in both directions: 8/8 footguns are genuine surprises, 0 malicious-owner vectors.

---

## ⚠ Do-Not-Action Register

**These three "fixes" are wrong. Do not apply them, and do not let a future run re-suggest them.**

### DNA-1 — Aderyn SAST-109's `batchMigrate` advice is actively harmful (D-25)

SAST-109 advises making the `batchMigrate` loop "forgive on fail and return failed elements" — superficially
reasonable DoS-hardening. **Applying it is a regression**: silently skipping a user during a migration
**strands that user's position while the batch reports success**. The loop reverting is the correct
**fail-closed** behaviour here. **Rejected.**

### DNA-2 — Ledger `L-03` must be closed **MOOT**, never **`fixed`** (D-13)

Ledger `L-03` (`submitted`, "nudge-token equality guard") targets code that story-022 restructured. Its
implied remedy was *"skip the equality guard when the nudge is size-disabled"*. Under the new §4.1 that remedy
is **directly contrary to spec**: §4.1 requires the payment-token exclusion to run **unconditionally**,
precisely so a non-qualifying call cannot use the guard's behaviour to **probe payment-token balances**.
**Applying L-03 as written reintroduces the probe vector.** Close it `moot / superseded` with the trap warning
attached — a `fixed` disposition invites someone to later read a `submitted` Low with an obvious one-line fix
and reopen an information-leak path.

### DNA-3 — Do not fix the duplicate-token Medium (M-02, `a62fe01a…`) by re-reading `balanceOf`

Re-reading `balanceOf` at payout is **exactly the §4.2 refactor the spec warns against**, at both the snapshot
site and the payout site. **Correct fix**: clamp to `min(snapshot[i], balanceOf(this) - paidThisPass)`, or
dedupe the array. The correct clamp **also** fixes the FoT payout-vs-delivered gap in Q-03, so evaluate the
two jointly.

---

## Tooling Coverage Gaps (D-11) — silence is not clean

**A missing or vacuous result is never presented as verified-clean.**

| Tool | Status | Detail |
|---|---|---|
| **Semgrep** | ⚠ **VACUOUS — contributed nothing** | 189 hits were **all `INFO`** performance/style rules (`use-custom-error-not-require` ×105 etc.). A probe of `p/security-audit` matched only **2 multilang rules** and returned **0 findings**. Record as vacuous, **not** as clean. |
| **Aderyn** | ⚠ **Coverage hole** | Did **not** analyze `script/DeployBatchNFTMinter.s.sol` (Slither and Semgrep did) — a file that **carries an open finding** (L-01's deploy-time framing). |
| **Slither** | ✅ Trap avoided, sanity-checked | `--filter-paths` was anchored to `phoenix-nft-staking/lib/`, **not** bare `lib/` — bare `lib/` matches every first-party absolute path and would have produced a **false 0-result**. Sanity check passed: **131 raw results across 7 files**, not zero. |
| **4naly3er** | ✅ Ran clean | See Appendix A. Workaround applied for the known foundry.toml-only gap. |
| **Tier-3 `InvariantForkParity`** | ⚠ **Green is scope-limited** | 3/3 PASS at 128k calls, but compares **copies #2 and #4 only**, no `NFTStakerDepletion`, **no migration surface**, and does not test the `_safePay` drift. **Not evidence that fork drift is absent** (see L-07). |
| **Tier-3 `invariant_fotFloor`** | ❌ **BROKEN** | Delivered 95e18 vs declared floor 100e18, census `fotListedWithFloor: 11` (genuinely exercised). Recorded as a rider on **Q-03**; disposition deliberately unchanged. |

---

## Appendix A — 4naly3er automated QA/gas report

**Status: RAN SUCCESSFULLY.** Full output attached at
[`4naly3er-report.md`](./4naly3er-report.md) (5,615 lines).

**How it was run.** 4naly3er fails on foundry.toml-only projects because it requires a `remappings.txt`
inside `BASE_PATH`. The documented workaround was applied: a scratchpad directory was staged with a
`remappings.txt` rewritten to **absolute** submodule paths plus `src`/`script` symlinks into
`lib/phoenix-nft-staking`, and 4naly3er was run against that directory. **Nothing was written into `lib/`.**

**Scope analyzed (10 files):** `src/BatchNFTMinter.sol`, `src/INFTStakerMigratable.sol`, `src/INFTSupply.sol`,
`src/InPlaceNFTStakerMigrator.sol`, `src/NFTStaker.sol`, `src/NFTStakerDepletion.sol`,
`src/NFTStakerMigrator.sol`, `src/NFTStakerPriceScaled.sol`, `src/NFTStakerPriceScaledMigrateReady.sol`,
`script/DeployBatchNFTMinter.s.sol`.

### A.1 Medium Issues (2 classes)

| ID | Issue | Instances | Disposition |
|-|:-|:-:|:-|
| M-1 | Contracts are vulnerable to fee-on-transfer accounting-related issues | 5 | Superseded by **Q-03** (D-19 ceiling). Not re-filed. |
| M-2 | Centralization Risk for trusted owners | 64 | Dropped under **Law 3** (D-12), same disposition as Aderyn's 57. |

### A.2 Low Issues (11 classes)

| ID | Issue | Instances |
|-|:-|:-:|
| L-1 | Use a 2-step ownership transfer pattern | 6 |
| L-2 | Some tokens may revert when zero value transfers are made | 17 |
| L-3 | Missing checks for `address(0)` when assigning values to address state variables | 7 |
| L-4 | Division by zero not prevented | 16 |
| L-5 | Owner can renounce while system is paused | 5 |
| L-6 | Possible rounding issue | 8 |
| L-7 | Loss of precision | 50 |
| L-8 | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 8 |
| L-9 | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 7 |
| L-10 | Sweeping may break accounting if tokens with multiple addresses are used | 5 |
| L-11 | A year is not always 365 days | 4 |

### A.3 Non-Critical Issues (24 classes)

| ID | Issue | Instances |
|-|:-|:-:|
| NC-1 | Missing checks for `address(0)` when assigning values to address state variables | 7 |
| NC-2 | Constants should be in CONSTANT_CASE | 3 |
| NC-3 | Control structures do not follow the Solidity Style Guide | 61 |
| NC-4 | Delete rogue `console.log` imports | 1 |
| NC-5 | Consider disabling `renounceOwnership()` | 6 |
| NC-6 | Duplicated `require()`/`revert()` checks should be refactored to a modifier or function | 34 |
| NC-7 | Events should use parameters to convey information | 2 |
| NC-8 | Event missing indexed field | 26 |
| NC-9 | Events that mark critical parameter changes should contain both the old and the new value | 30 |
| NC-10 | Function ordering does not follow the Solidity style guide | 6 |
| NC-11 | Functions should not be longer than 50 lines | 105 |
| NC-12 | Lack of checks in setters | 14 |
| NC-13 | NatSpec is completely non-existent on functions that should have them | 33 |
| NC-14 | Incomplete NatSpec: `@param` is missing on actually documented functions | 19 |
| NC-15 | Use a `modifier` instead of a `require`/`if` statement for a special `msg.sender` actor | 22 |
| NC-16 | Constant state variables defined more than once | 14 |
| NC-17 | Consider using named mappings | 7 |
| NC-18 | `address`es shouldn't be hard-coded | 1 |
| NC-19 | Owner can renounce while system is paused | 5 |
| NC-20 | Adding a `return` statement when the function defines a named return variable is redundant | 4 |
| NC-21 | Take advantage of custom errors' return value property | 8 |
| NC-22 | Contract does not follow the Solidity style guide's suggested layout ordering | 5 |
| NC-23 | Event is missing `indexed` fields | 57 |
| NC-24 | Variables need not be initialized to zero | 8 |

### A.4 Gas Optimizations (14 classes)

| ID | Issue | Instances |
|-|:-|:-:|
| GAS-1 | `a = a + b` is more gas effective than `a += b` for state variables | 39 |
| GAS-2 | Use assembly to check for `address(0)` | 48 |
| GAS-3 | Cache array length outside of loop | 6 |
| GAS-4 | State variables should be cached in stack variables rather than re-read from storage | 2 |
| GAS-5 | For operations that will not overflow, you could use `unchecked` | 277 |
| GAS-6 | Use custom errors instead of revert strings to save gas | 104 |
| GAS-7 | Avoid contract existence checks by using low-level calls | 29 |
| GAS-8 | State variables only set in the constructor should be declared `immutable` | 18 |
| GAS-9 | Functions guaranteed to revert when called by normal users can be marked `payable` | 64 |
| GAS-10 | `++i` costs less gas than `i++` or `i += 1` (same for `--i`) | 11 |
| GAS-11 | Using `private` rather than `public` for constants saves gas | 18 |
| GAS-12 | Splitting `require()` statements that use `&&` saves gas | 1 |
| GAS-13 | Increments/decrements can be unchecked in for-loops | 11 |
| GAS-14 | Use `!= 0` instead of `> 0` for unsigned integer comparison | 86 |

**Reading note.** 4naly3er's `NC-*`/`GAS-*` classes are style and micro-optimisation output and are **not**
re-filed as findings — C4 discourages non-critical padding. They are attached in full for completeness. The
only two 4naly3er classes that intersect this run's manual findings are M-1 (→ Q-03) and M-2 (→ Law-3
suppression), both already dispositioned above.

---

*End of QA report. `reports/phoenix-nft-staking-20/` — commit `0d1a0b2`.*
