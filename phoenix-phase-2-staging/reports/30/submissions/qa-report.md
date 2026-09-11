# QA Report — phoenix-phase-2-staging

**Run**: `reports/30` · **Commit**: `e6eded0` · **Baseline**: `9563c68` · **Branch**: `master`
**Entry point**: `dev` (script audit of `script/DeployMocks.s.sol`)

## Run outcome

This run produced **0 High and 0 Medium findings**. There are therefore **no individual H/M
submissions** for it — the `submissions/` directory carries this QA bundle and the run's
spec-conformance report only. No coded PoC is owed: C4 requires one for High/Medium findings, and
this run has neither. (`submissions/M-01-C1.md` and `M-01-C2.md` are **re-carried** Mediums from
earlier runs, still `fix-pending` and unchanged by audit 30 — they are not findings of this run.)

Three Low findings (**L-01**, **L-02**, **L-03**) were raised and are filed **individually** under
`reports/30/findings/low/`; two of the three are faithfulness / spec-conformance items and belong to
`spec-conformance.md`, not here. They are deliberately **not** bundled into this report and are not
renumbered by it.

Carryover QA from earlier audits is **not** merged here. Prior-run bundles, pruned to their still-open
entries, are copied verbatim to `submissions/carryover/qa-report-<NN>.md`. The `Q-XX` sequence below
covers only this run's new findings; entry point `dev` already carries a `Q-01` from runs 21, 26, 27
and 28 under different fingerprints, so **always disambiguate these by fingerprint, never by label**.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (bundled here) | 0 |
| QA | 3 |
| Centralization | 0 |
| **Total** | **3** |

No centralization-risk findings were raised this run.

An automated 4naly3er pass is attached as **`submissions/4naly3er-report.md`**. Read its provenance
header before relying on it: it covers 22 first-party files (`src/views/`, `src/mocks/`) but
**could not analyse `script/DeployMocks.s.sol`**, which is where Q-01 and Q-02 live. Its silence on
that file is a tool limitation, not a clean result.

---

## QA Findings

### [Q-02] Stale references to the deleted Phase 7.4 survive in the retained StableStaker cutover and in the toggle documentation <!-- id: pps30q2 -->

**Fingerprint**: `66671224826b16690cf8dda784af7fc04b650c2f23e13fcfef50c57e243ce574`
**Location**: `script/DeployMocks.s.sol:408` and `script/DeployMocks.s.sol:2031`
(`run` / `_rehearseStableStakerCutover`) · Root-cause class `StaleCrossReferenceToDeletedCode`

> Listed first among the QA items **solely because of the binding triage dependency below**, not
> because of its own impact.

**Description**

The story-080 slimming removed the Phase 7.4 cutover, but two in-source references to it survived.

*Instance 1 — `:408`, a stale navigational pointer.* The `LOCAL_PROMO_KENDU` toggle comment tells the
reader they need not scroll "to Phase 7.4" to see which leg they got:

```solidity
// Script-audit run-26, L-03. Resolved ONCE, here, and logged loudly next to the deployer
// and chain-id lines so a developer reading the transcript knows which leg they got
// without scrolling to Phase 7.4. ...
armKenduPromo = vm.envOr("LOCAL_PROMO_KENDU", true);
```

The arming now happens in Phase 3, inside `_deployPhlimboV3`. The pointer sends a reader to a phase
that no longer exists.

*Instance 2 — `:2031`, the one that matters.* Inside the **retained** story-080 StableStaker cutover,
the justification for revoking `StableStakerV1`'s phUSD mint grant is a comparison to the deleted code:

```solidity
// ---- 4. V1 is empty and inert. Take its phUSD mint authority away.
//         ... This mirrors PhlimboV2's treatment in the Phase 7.4 cutover.
//         Safe because V1 is provably drained: `stakerCount == 0` and `totalStaked == 0`
//         were asserted for all three pools above, ...
phUSD.setMinter(address(stableStaker), false);
```

The `setMinter(false)` call is live and executes regardless. What is lost is the *reviewability* of it:
the comparator that justifies a still-live privileged action cannot be checked by any future reader.
An unverifiable justification for a live privileged action is worse than an absent one, because it
reads as reasoned.

**Impact**

QA. Comments only — not a single byte of executed behaviour changes. The revoke at `:2031` happens or
does not happen independently of whether the comment justifying it points at code that still exists.
The finding is reported rather than dropped because it is a reviewability defect on a live privileged
action, and because of the ledger dependency below.

**BINDING TRIAGE DEPENDENCY — open ledger entry `08adbb692840…` (pps29l6, run-29 L-06)**

This is stated here in full rather than compressed to a cross-reference line, because losing it would
cause a false "cannot reproduce" at that entry's next re-triage.

Ledger entry `08adbb692840…` (label L-06, run-29, **status open**, root-cause class
`MissingPostStepConfiguration`, function `_rehearseStableStakerCutover`) states its basis on the
**Phase 7.4 cutover "400 lines below it"** — precisely the code this finding reports as deleted at
`e6eded0`. A re-triage that tries to verify L-06 against that landmark will find nothing there and may
close or mis-judge the entry on that basis.

**L-06's basis must instead be RESTATED on `script/DeployMocks.s.sol:_deployPhlimboV3:2314-2321`**,
which is the live in-file precedent for the same pattern — a privileged grant taken out and then
*read back* rather than fired and forgotten:

```solidity
// Stand the seeding grant down. Read back rather than fire-and-forget: a farm left with a
// live migrator is a farm where one address can move anybody's position.
v3.setMigrator(address(0));
require(v3.migrator() == address(0), "PhlimboV3 seeding migrator was not stood down");
```

L-06 and this finding are **distinct and must not be collapsed**: L-06 is that the migrator role is
actually left held; this finding is that a comment justifying a still-live revoke cites a comparator
that no longer exists. Different root-cause classes, different fixes (a role change versus a comment
repoint). A note recording this dependency has been appended to the L-06 ledger entry.

Related, not a duplicate: `d7242d7c43ac…` (run-28 Q-01, `StaleInSourceRationaleAfterUpstreamFix`) —
same stale-rationale family, different function and different stale claim.

**Recommendation**

Repoint `:2031` at `_deployPhlimboV3:2287-2321`, which is the live in-file precedent for both the mint
grant and the role stand-down, and drop the Phase 7.4 pointer at `:408`. When re-triaging L-06, restate
its basis on `_deployPhlimboV3:2314-2321` — the slimmed code now demonstrates the correct pattern one
screen away from the place that omits it.

---

### [Q-03] `DepositView.sol` and `DepositPageView.sol` are now first-party in-scope contracts with zero deployers, retained only as wagmi ABIs and a revival guard <!-- id: pps30q3 -->

**Fingerprint**: `e15cd2e251414517607a2cc9e2d4a7a8892448bba9ad1d330f178a331747ea14`
**Location**: `src/views/DepositView.sol` and `src/views/DepositPageView.sol` (whole contracts) ·
Root-cause class `OrphanedFirstPartySource`

**Description**

Neither contract has a deployer at `e6eded0`. No script in the live build constructs either one; the
only remaining construction site is under `script/archives/`, which `foundry.toml` excludes from the
build entirely (`skip = ["script/archives/**"]`). Their names sit in `server/extract-addresses.js`
`DROPPED_CONTRACT_NAMES` as a deliberate revival guard:

```javascript
const DROPPED_CONTRACT_NAMES = [
    "NFTMigrator",
    "BuggedPoolerV2Index6",
    "DepositView",
    "DepositPageView",
    "MintPageView",
];
```

What keeps this from being ordinary dead-code noise is a demonstrated root cause. Both are typed
against a V1/V2-shaped `IPhlimbo` whose `userInfo` is a **3-tuple**:

```solidity
// src/views/DepositView.sol:76        and  src/views/DepositPageView.sol:35
(uint256 amount,,) = phlimbo.userInfo(user);
```

`PhlimboV3.userInfo` returns a **4-tuple** — a fact the live replacement documents explicitly:

```solidity
// src/views/DepositPageViewV3.sol:29, :156
//  `PhlimboV3.userInfo(address)` returns a **4**-tuple (`amount`, `phUSDDebt`, ...
(uint256 amount,,,) = phlimbo.userInfo(user); // 4-tuple in V3
```

Because the orphaned views declare their own narrower interface, an instance pointed at V3 decodes the
first three words of a four-word return and **succeeds silently** rather than reverting. Meanwhile both
ABIs remain published in `wagmi.config.ts:105-106`, reachable to UI consumers, with nothing in the
build preventing someone from wiring one up.

**Impact**

QA. C4 places unused view functions at QA at best, and these are entire unused view *contracts*. There
is no asset impact today: nothing deploys them, so realising the hazard requires a future consumer to
deploy or wire one against V3 — code that does not exist. The finding earns its place in the report on
the strength of the demonstrated silent-mis-decode root cause, not on an elevated label. A silent
mis-decode is genuinely worse than a revert, and that is the part worth acting on.

**CROSS-LINK — fix-pending ledger entry `6b63ef65…`**

`DepositPageView` is simultaneously the subject of ledger entry `6b63ef6516ac…` (run-24 M-01, label
L-07, **status fix-pending**, root-cause class `StaleImmutableViewPointerAcrossCutover`, entry point
**`promotion-ready:broadcast`**) — a *live* view bound to the wrong phlimbo generation.

These are **different defects at different entry points and must not be collapsed**: that entry
concerns a deployed instance owed a fix; this one concerns first-party source with no deployer at all.
But the two interact at remediation time — **a "delete both sources" fix here would act on the same
contract that `6b63ef65…` still owes an open, unfulfilled obligation on**. Resolve the fix-pending
entry's disposition before deleting the source, or the deletion will silently moot an obligation a
human has not yet signed off. This is the reason the retype option below is preferred over deletion.

Nearest neighbour, kept separate: `f5bb2b654c9a…` (run-21 Q-02, `DeadScaffolding`, `MockERC4626Wrapper`)
— a *deployed*, funded mock serving a removed route, with no mis-decode hazard.

**Recommendation**

Delete both sources and their wagmi entries, or add a compile-time impossibility (retype against
`IPhlimboV3`, which will not compile against the 3-tuple). Keeping the `extract-addresses.js` guard
entries is correct either way and should be noted as deliberate.

*Preference, given the cross-link above*: the retype option closes the hazard permanently at compile
time without touching a contract that carries an open fix-pending obligation elsewhere.

---

### [Q-01] The three `UniboostStakerV2` instances are published to the UI with zero stake and a zero phUSD reward budget <!-- id: pps30q1 -->

**Fingerprint**: `bb029fb3cabf67c8cdbd406e6ddce62f04c9b74d68d1609729d48146b5b31061`
**Location**: `script/DeployMocks.s.sol:2407-2434` (`_deployUniboostStaker`) ·
Root-cause class `ProducerRemovedConsumerRetained`

**Description**

The V1 staker rehearsal was removed at this commit, and with it went the only producers of staker
funding: `topUp` call sites went 6 → 0 and `depositFor(address,uint256)` went 9 → 0
(`artifacts/s1-selector-counts-head.log` versus `s1-selector-counts-baseline.log`). The consumer was
retained. `_deployUniboostStaker` deploys each staker, wires the hook, and sets a deliberate 12-month
depletion window — but never tops it up:

```solidity
staker.setDispatcherHook(IUniboostMintDebtHook(address(hook)));
// pull() is onlyOwnerOrRecipient; the staker must be the hook's recipient to sweep mint debt.
hook.setRecipient(address(staker));
// Depletion window = 12 months (one APY-year analogue). Bounded 1..120. Budget is refilled
// by the hook's pull() on dispatch; rate = budget/windowSeconds. Deliberate, non-default.
staker.setDepletionWindow(12);
```

All three stakers end the script at `totalStaked = 0`, `phUSD.balanceOf = 0`, `rewardBudget = 0`,
`rewardRate = 0`, with `depletionWindowMonths = 12`
(`artifacts/s2-uniboost-stakers-head.log`).

**Impact**

QA — and this is the weakest of the run's candidates on impact. Nothing is bricked and nothing is
stranded: `setDepletionWindow(12)` against a zero budget is **inert** (rate 0, `windowEnd = now + 365d`;
verified against `NFTStakerDepletionV2.sol:435-450`), and the state **self-heals on the first
`hook.pull()`**, which funds the budget organically. There is no lost detector and no defect in shipped
behaviour — this is a local, throwaway-chain fixture in a correct-but-unseeded state. What it costs is
representativeness: the chain the UI is tested against ships three reward-bearing contracts that emit
nothing, which is not the "fully working" end state the script claims.

It is reported rather than dropped because it has a concrete, reproducible end state and a concrete fix.

**Related, not duplicated**: this shares an upstream cause with Q-02 — the same deletion removed
`topUp`/`depositFor` — but the retained consumer here is `_deployUniboostStaker`, a different function
with a different fix, and it is kept distinct.

**Recommendation**

Either call `staker.topUp(REHEARSAL_STAKER_BUDGET)` once per staker inside `_deployUniboostStaker`
(the constant already existed at `9563c68`), or restore the single index-1 mint so `hook.pull()` funds
them organically. Assert `rewardRate > 0` afterwards so a future removal fails loudly.

> The `assert rewardRate > 0` half is the durable value in this recommendation and is worth keeping even
> though the finding is QA: it is what converts a silent re-occurrence of this class into a loud one.

---

## Appendix

**`submissions/4naly3er-report.md`** — automated SAST/gas report for this run. 22 first-party files
analysed (`src/views/`, `src/mocks/`), 0 AST failures. `script/DeployMocks.s.sol` is **not covered**
(solc `DeclarationError: Identifier already declared`, caused by nested-submodule duplicate dependency
copies that 4naly3er's resolver does not canonicalise the way forge does); that gap is documented in
the report's own header and covers the locations of Q-01 and Q-02.
