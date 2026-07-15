# QA Report for phlimbo-ea (run 08)

**Commit**: `bf42c12` ([story-025] Regenerate .gas-snapshot for non-reverting forwarding + new tests)
**Scope**: `src/PhlimboV3.sol`, `src/MigratorV2V3.sol`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 7 |
| Centralization | 0 |
| Non-Critical / QA | 2 |
| **Total** | **9** |

| Label | Contract | Issue |
|-------|----------|-------|
| [L-01](#l-01) | PhlimboV3 | `_updatePool` truncation debits reward balance in full while the accumulator floors |
| [L-02](#l-02) | PhlimboV3 | Promo accrual during `Flushing` is poke-dependent (**fix-introduced by story-024**) |
| [L-03](#l-03) | MigratorV2V3 | Defective `_tryTransfer` cloned byte-identically; NatSpec asserts a guarantee the helper cannot honour |
| [L-04](#l-04) | MigratorV2V3 | `unclaimable` claim ordering lets an already-swept user take a later user's backed rewards |
| [L-05](#l-05) | MigratorV2V3 | `seedUsers` is unchunkable and can exceed the block gas limit with no alternative path |
| [L-06](#l-06) | PhlimboV3 + MigratorV2V3 | `_tryTransfer` reports success for a transfer to a codeless address |
| [L-07](#l-07) | PhlimboV3 | Zombie `_stakers` growth via `pauseWithdraw` (carryover, ledger V3-L-03) |
| [Q-01](#q-01) | PhlimboV3 | `pauseWithdraw` — **refuted as a vulnerability; retained as a trap warning** |
| [Q-02](#q-02) | MigratorV2V3 | Retired promo tokens fall outside `withdrawAll`'s live-slot sweep |

The 3 Medium findings from this run (`M-01` batchClaim promo destruction, `M-02` migrate cursor
brick, `V3-M-02` emergencyTransfer stale accounting) are submitted individually. Story/spec
deviations (`F-08-01`, `F-08-02`, `F-08-03`) are routed to the spec-conformance report.

---

## Low Risk Findings

<a id="l-01"></a>
### [L-01] `_updatePool` truncation debits the reward balance in full while the accumulator floors <!-- id: pe8l1 -->

**Location**: [PhlimboV3.sol `_updatePool`](../../../../lib/phlimbo-ea/src/PhlimboV3.sol)

**Description**: When `toDistribute * PRECISION < totalStaked`, the accumulator gains zero while
`rewardBalance` is debited in full. The emission is destroyed in accounting only — the tokens never
leave the contract, so they remain owner-recoverable via `emergencyTransfer`. The promo leg carries
identical arithmetic. The phUSD leg is correctly unaffected: it is mint-based with no balance debit,
so truncation strands nothing.

**Quantification at the deployed configuration** (6dp USDC reward / 18dp phUSD staked / `PRECISION = 1e18`):

| Measure | Value |
|---|---|
| Per-tx destruction ceiling | **0.011475 USDC** (wait-time-independent) |
| Organic loss over 138 days of real logs | **0.21%** |
| Griefing economics | ~$728 gas to destroy $40 — **18× loss-making** |
| 18dp control | ≈ 0% ⇒ **decimals-conditional** |

**PoC**: `workspace/phlimbo-ea/test/poc-PATTERN-001-updatepool-truncation.t.sol` — 8/8 pass.

**⚠ Latent scaling watch-note (carry to future runs)**: the loss scales with `totalStaked` and
**inversely** with stream size, and the ~249s zero-credit threshold is **already live** at current
parameters. Re-weigh toward Medium if phUSD supply grows materially while the USDC stream stays
thin, or if a smaller / lower-decimal promo stream is funded. Re-evaluate at ~10× `totalStaked`
growth or on funding a sub-50k 6dp promo.

**⚠ Not refutable by R6**: R6's "rounding favours the contract" addresses **solvency**; this finding
is about value **delivery**. Rounding that keeps tokens inside the contract is protocol-favouring for
solvency *and* user-adverse for delivery — both hold simultaneously. Conflating them would wrongly
close a live finding.

**Test-gap note**: `test_promo_6_decimal_partner_token` (PhlimboV3Test.t.sol:1271) warps
`PROMO_DURATION/2` in a single step, producing one large `toDistribute` where truncation is
negligible. The suite's only low-decimal test therefore **masks** this bug, which manifests only
under frequent small-elapsed updates.

**Recommendation**: One line per balance-backed leg — debit only what was actually credited and let
the remainder carry to the next update. The carry makes the fix self-healing.

```solidity
uint256 credited = (toDistribute * PRECISION) / totalStaked;   // floor
acc += credited;
rewardBalance -= (credited * totalStaked) / PRECISION;         // debit only what was credited
```

---

<a id="l-02"></a>
### [L-02] Promo accrual during `Flushing` is poke-dependent — fix-introduced by story-024 <!-- id: pe8l2 -->

**Location**: [PhlimboV3.sol `_updatePool` / `abortFlush`](../../../../lib/phlimbo-ea/src/PhlimboV3.sol)

**Description**: story-024 added a phase gate that freezes promo accrual during `Flushing`, but
`lastRewardTime` advances **outside** that gate. A permissionless call during the flush therefore
consumes a window the promo stream never accrued over, and on `abortFlush` the promo distribution
becomes path-dependent on that unrelated call. The freeze is a per-**call** property, not a
per-**window** one.

**Fix-introduced**: differentially proven against the pre-fix commit `69e2a2d` — this defect did not
exist before the story-024 fix wave. It is **not** a regression in the ledger sense (no prior finding
was marked fixed and reappeared), and the fix-introduced provenance does not change the severity.
Found independently by 5 agents, all ranking it Low.

**Why it stays Low**: tokens are **conserved** — the flush-window promo stays in `promoRewardBalance`
and continues streaming at the unchanged `promoRewardPerSecond`, so the stream tail simply runs
longer. The residual is *who* receives the window and *when*, not *how much* exists. Griefing costs
the griefer real `rewardToken` and captures nothing, and the vector is not profit-capturable:
`stake()` calls `_updatePool()` before setting `promoDebt`, so a new staker cannot position into the
deferred window. Abort-path only.

**Recommendation**: Bring `lastRewardTime` inside the phase gate, or track a separate promo-side
timestamp so the freeze becomes a property of the window rather than of the individual call.

*Story/spec face routed separately as `F-08-02`.*

---

<a id="l-03"></a>
### [L-03] Defective `_tryTransfer` cloned byte-identically into MigratorV2V3; NatSpec asserts a guarantee it cannot honour <!-- id: pe8l3 -->

**Location**: [PhlimboV3.sol#L818-821](../../../../lib/phlimbo-ea/src/PhlimboV3.sol) ≡
[MigratorV2V3.sol#L275-278](../../../../lib/phlimbo-ea/src/MigratorV2V3.sol) (md5 `9b80f3419b748e1c9a1de632827e3418`) ·
doc claim at [MigratorV2V3.sol#L57, #L61-62](../../../../lib/phlimbo-ea/src/MigratorV2V3.sol)

**Description**: story-025 cloned PhlimboV3's `_tryTransfer` **byte-identically** into MigratorV2V3,
inheriting open ledger finding **V3-L-02**'s unchecked `abi.decode` short-return defect into a second
contract. A token returning fewer than 32 bytes makes the unchecked `abi.decode` revert, which in the
migrator pins the cursor.

This is **propagation, not a duplicate**: a known-defective helper copied verbatim into a second
contract is a distinct instance requiring a distinct fix.

**The core of this entry is a doc-vs-code deviation.** story-025 upgraded the prose to an
**unconditional** guarantee the helper cannot honour:

> "reward forwarding never reverts … the cursor always advances and a single bad recipient can never
> brick a pass" — MigratorV2V3.sol:57, 61-62

Because the claim is unconditional, it is falsified by the existence of *any* short-returning token —
**regardless of whether such a token is realistic in this deployment**. The doc is now stronger than
the code on this leg.

**⚠ Scoping correction — do not overstate**: this is **not** made worse by `promoToken` being
arbitrary or owner-selected. That framing is **falsified by source**: `startPromotion`'s mandatory
`safeTransferFrom` ([PhlimboV3.sol#L346](../../../../lib/phlimbo-ea/src/PhlimboV3.sol)) reverts on a
short-returning token, so such a token **can never be installed as `promoToken`** in the first place.
This entry stands as a propagation/hygiene item on the strength of the doc deviation, not on an
inflated token-realism argument.

**Recommendation**: Replace both hand-rolled copies with OpenZeppelin `SafeERC20` (wrapped in the
existing try/bank pattern where non-reverting behaviour is required). **A single SafeERC20 adoption
resolves L-03 and L-06 together.** Failing that, correct the NatSpec so the guarantee is stated
conditionally.

*Shares story/spec face `F-08-01` with M-02 (same overstated brick-proofing claim, same NatSpec text).*

---

<a id="l-04"></a>
### [L-04] `unclaimable` claim ordering lets an already-swept user take a later user's backed rewards <!-- id: pe8l4 -->

**Location**: [MigratorV2V3.sol `withdrawAll` / `claimUnclaimable`](../../../../lib/phlimbo-ea/src/MigratorV2V3.sol) ·
doc at [MigratorV2V3.sol#L64-68](../../../../lib/phlimbo-ea/src/MigratorV2V3.sol), [#L239-242](../../../../lib/phlimbo-ea/src/MigratorV2V3.sol)

**Description**: `unclaimable[token][user]` is **per-user accounting over an unsegregated balance**,
with no aggregate tracked. `withdrawAll` sweeps the entire balance, leaves every `unclaimable` entry
intact, and — by design (MigratorV2V3.sol:239-242) — does **not** abort the pass. The pass resumes and
re-funds the contract with later users' banked rewards, and `claimUnclaimable` pays first-come,
first-served out of the common balance. The unbacked-ness therefore **migrates by claim ordering**
rather than staying with the users banked at sweep time.

**PoC'd**: alice banks 2500e18 → owner sweeps → alice's entry **still reads 2500e18** → pass resumes,
bob banks 2500e18 legitimately → **alice claims first and takes bob's 2500e18** → bob's claim
**reverts**, despite his entry reading 2500e18.

**Scope — what is and is not reported here**: the base case (owner sweeps, claims become unbacked) is
**suppressed as Law-3 obvious** and is documented verbatim: *"leaving those claims unbacked … the
accepted trade-off"* (MigratorV2V3.sol:64-68). An owner calling `withdrawAll` knows tokens leave.
Only the **ordering face** survives — and it is documented **nowhere**.

**The sharpest harm is an operational-record ambiguity**: after alice claims, her mapping entry is
**zeroed**. An owner reconciling from the **live mapping** sees her as settled and reimburses only bob
(self-correcting). An owner reconciling from the at-sweep `RewardForwardFailed` **event snapshot**
reimburses alice a **second time** (double-pay). The live mapping and the event history **disagree
about who is owed**, and the NatSpec instructs the owner to perform exactly this reconciliation
without saying which source to trust.

**Why Low**: value is conserved — the owner holds the swept funds and the obligation is
dischargeable, just not from on-chain state alone. No net destruction, no protocol availability
impact.

**Doc-accuracy sub-item**: story-025 rewrote the contract-level header and interface NatSpec but left
`withdrawAll`'s own function-level `@dev` at L239 reading *"Pure recovery sweep of stranded
balances"* — describing **pre-story-025** behaviour. Trivially fixable; noted separately so it is not
lost inside the structural fix.

**Recommendation**: Track an aggregate and exclude it from the sweep, so banked claims stay backed and
the sweep is honest about what it may take.

```solidity
mapping(address => uint256) public totalUnclaimable;   // incremented on bank, decremented on claim
// withdrawAll: sweep (balance - totalUnclaimable[token]) instead of the full balance
```

---

<a id="l-05"></a>
### [L-05] `seedUsers` is unchunkable and can exceed the block gas limit with no alternative path <!-- id: pe8l5 -->

**Location**: [MigratorV2V3.sol `seedUsers`](../../../../lib/phlimbo-ea/src/MigratorV2V3.sol)

**Description**: `seedUsers` replaces the user list **wholesale** in one unchunkable transaction
(O(N) delete + O(N) push). For a sufficiently large V2 user base the call exceeds the block gas limit,
and the list then cannot be seeded or re-seeded **at all** — there is no chunked path.

**Law-3 exception applies — this is a footgun, not centralization**: the owner **cannot know** N is
too large until the transaction fails. That is the definition of a non-obvious consequence, and
*"the owner should have chunked it"* is not available as a rebuttal because the function offers no
chunking to choose.

**Why it stays Low**: it fails **loudly** and **pre-migration** — the owner discovers it at seed time,
before any user state has moved and with no funds committed. Nothing is stuck, nothing is lost, and
the remedy (redeploy with a chunked seeder) is available at the cheapest possible moment. Contrast
M-02, which wedges **mid-pass** with the cursor pinned and user state in flight; that is what an
availability Medium looks like here.

**Recommendation**: Add a chunked seeding path — an explicit `clearUsers()` plus an appending
`seedUsers(address[] calldata)` callable across multiple transactions, with a `sealed` flag to close
seeding before the pass begins.

---

<a id="l-06"></a>
### [L-06] `_tryTransfer` reports success for a transfer to a codeless address <!-- id: pe8l6 -->

**Location**: [PhlimboV3.sol#L818-821](../../../../lib/phlimbo-ea/src/PhlimboV3.sol) ·
[MigratorV2V3.sol#L275-278](../../../../lib/phlimbo-ea/src/MigratorV2V3.sol) (both copies)

```solidity
return callSuccess && (returndata.length == 0 || abi.decode(returndata, (bool)));
```

**Description**: A raw call to a **codeless** address returns success with empty returndata, which
this line treats as success. A payment that never happened is recorded as paid — the hand-rolled
helper drops the `isContract` check that `SafeERC20` exists to provide. In PhlimboV3 this aligns the
debt and destroys the entitlement via the same path as M-01, but **without even banking it**.

**This is the opposite face of the same line as L-03**, and the two are **correctly not collapsed**:
the root causes differ (codeless-address-treated-as-success vs unchecked-`abi.decode` short-return)
and so do the minimal fixes (add an `isContract` check vs check returndata length) — empty returndata
yields a **false success**, short non-empty returndata yields a **spurious revert**. Adopting
`SafeERC20` resolves both at once.

**Why Low**: the trigger is an owner configuration error (a codeless address configured as a token —
e.g. a promo token not yet deployed, or a self-destructed/mis-typed address) that would surface
immediately across every other interaction with that token.

**Recommendation**: Adopt `SafeERC20` in both copies (see L-03), or add an explicit code-length check
before treating empty returndata as success.

---

<a id="l-07"></a>
### [L-07] Zombie `_stakers` growth via `pauseWithdraw` <!-- id: pe8l7 -->

**Location**: [PhlimboV3.sol `pauseWithdraw`](../../../../lib/phlimbo-ea/src/PhlimboV3.sol) ·
claim at [PhlimboV3.sol#L602-604](../../../../lib/phlimbo-ea/src/PhlimboV3.sol)

**Carryover**: ledger `V3-L-03` (`59e14f41`, open) — severity unchanged, no re-classification.

**Description**: `pauseWithdraw` never prunes `_stakers`, so members that have fully exited
(`amount == 0`) accumulate permanently and every future rotation must iterate them. This falsifies the
contract's own stated invariant at L602-604 — *"membership in `_stakers` ⟺ userInfo.amount > 0"*.

**Why it stays Low**: the superset is **safe** — Σ-pending remains exact, and a zombie member is
visited by the flush with `pending == 0` (harmless). The impact is **gas growth only**.

**Interaction note (does not re-weigh either entry)**: zombie growth compounds M-02's cursor
economics — a longer `_stakers` list means more chunks and more opportunities to hit a bricking index.

**Recommendation**: Either prune on full exit inside `pauseWithdraw`, or correct the L602-604 NatSpec
to state the invariant that actually holds (membership ⊇ {amount > 0}).

---

## Centralization Risks

None identified in this run.

The owner-privileged behaviours surfaced this run (`withdrawAll`'s unconditional sweep in L-04,
`seedUsers` in L-05) are filed as **Law-3 footguns** — non-obvious consequences a competent,
non-malicious owner would be surprised by — not as centralization risks. Obvious owner privileges are
trusted per Law 3 and suppressed.

---

## Non-Critical / QA Notes

<a id="q-01"></a>
### [Q-01] `pauseWithdraw` omits `_updatePool` — REFUTED as a vulnerability; retained as a TRAP WARNING <!-- id: pe8q1 -->

**Location**: [PhlimboV3.sol `pauseWithdraw`](../../../../lib/phlimbo-ea/src/PhlimboV3.sol) ·
documented intent at [PhlimboV3.sol#L522-525](../../../../lib/phlimbo-ea/src/PhlimboV3.sol)

**This entry exists for the trap warning, not for a defect.** It is retained verbatim so a future
reviewer does not "fix" it into a bug.

**The mechanical claim is TRUE**: `totalStaked` is mutated without calling `_updatePool`, and the
co-staker is over-credited by **+100%** (19.897650 vs 9.948825 legitimate; confirmed 8/8 including a
256-run fuzz). The arithmetic is exactly as reported. It is the **impact** that fails, not the
mechanism.

**The counterfactual INVERTS.** Running `_updatePool()` first recovers the exiter **zero wei** — the
forfeit comes from **debt realignment**, which is documented intent at PhlimboV3.sol:522-525, not from
the accumulator — and instead **strands 9.951174 USDC forever** in a slice nobody can claim, with **no
`rewardToken` rescue function**.

> ### ⚠ TRAP WARNING — DO NOT APPLY THE OBVIOUS FIX
>
> **A future reviewer pattern-matching on `totalStaked-mutated-without-_updatePool` WILL propose
> adding `_updatePool()` to `pauseWithdraw`. Under the live configuration that change WOULD INTRODUCE
> A VALUE-STRANDING BUG**: it recovers the exiter zero wei and permanently strands ~9.95 USDC per
> occurrence in an unclaimable slice, with no rescue function.
>
> **That reviewer will be right about the pattern and wrong about this instance.** The pattern is a
> known-good discipline elsewhere in this very codebase — which is exactly what makes the trap
> dangerous.
>
> **Second, independent reason the obvious fix is wrong**: known issue **KI-4** states verbatim that
> *"pauseWithdraw does NOT claim rewards or update pool — by design"*. The obvious fix contradicts the
> project's own stated design.
>
> **KI-4 is NOT a blanket suppression of `pauseWithdraw` findings.** M-05 and V2-M-03 are
> `pauseWithdraw` findings the project did **not** suppress under it. Cite KI-4 only against the
> obvious-fix proposal, never as a reason to drop a `pauseWithdraw` finding.

#### ⚠ MANDATORY SCOPING — the QA verdict is CONFIG-CONDITIONAL, not structural

**This is QA *under the live zero-APY configuration*, where the phUSD leg is dormant.** The scoping
below is load-bearing and must not be dropped:

- **Do NOT state that `sum(claimable) == emitted` EXACTLY ⇒ "structurally conserving" / "never
  insolvency" as a STRUCTURAL claim.** It is false as a structural claim. The property is
  **config-conditional**.
- **Do NOT state that the sibling-Medium precedent "doesn't transfer."** It does — under a different
  config.
- The phUSD leg was **dormant** in testing: `desiredAPYBps` (PhlimboV3.sol:63) has **no constructor
  initializer** ⇒ defaults to `0` ⇒ `phUSDPerSecond == 0`. `setUp()` never sets it; the sole
  `setDesiredAPY` call in the V3 suite is at PhlimboV3Test.t.sol:296, inside the unrelated
  `test_migrator_claim_routes_rewards_to_migrator`. Every `pauseWithdraw` test and the 08-06 probe
  therefore ran with the phUSD leg switched off.
- **phUSD is MINTED and UNCAPPED** ([PhlimboV3.sol#L786](../../../../lib/phlimbo-ea/src/PhlimboV3.sol)),
  unlike the fixed USDC pot. A forfeit is never minted, but a **redistribution IS** — so on the phUSD
  leg, **redistribution = supply expansion**.
- **Under non-zero APY the "obvious fix" HALVES an unbacked mint** rather than stranding value —
  proven at `workspace/phlimbo-ea/test/AuditProbe0806PhUSD.t.sol` (drift **19999 bps = 2.0× APY
  indefinitely**). The trap warning above is therefore scoped to the live zero-APY config; it is not
  a claim that the fix is wrong at every configuration.
- `pauseWithdraw` **also skips `_updatePhUSDEmissionRate`** — byte-for-byte the ledger findings
  **M-05** (V1, acknowledged) and **V2-M-03** (V2, wont-fix).

**QA holds ONLY because `desiredAPYBps` has no constructor initializer ⇒ 0 ⇒ the phUSD leg is
dormant.** Cross-references, so a future non-zero-APY config **re-emits** rather than reading this
entry as "no asset impact":

| Reference | Status | Relevance |
|---|---|---|
| **DEDUP-04** | suppressed, config-conditional | phUSD uncapped mint; carries a **RE-EMIT-HIGH trigger** if a non-zero APY is configured |
| **M-05** (V1) | acknowledged | same `_updatePhUSDEmissionRate` skip on `pauseWithdraw` |
| **V2-M-03** (V2) | wont-fix | same `_updatePhUSDEmissionRate` skip on `pauseWithdraw` |

**⚠ RE-EMIT TRIGGER**: if `setDesiredAPY` is ever called with a non-zero value on a live V3 deployment,
**this entry must be re-opened and re-weighed against M-05 / V2-M-03 / DEDUP-04** — the zero-APY
premise that holds it at QA no longer applies.

**Recommendation**: **No code change under the current zero-APY configuration.** Add a NatSpec note at
`pauseWithdraw` recording (a) that the `_updatePool` omission is deliberate and (b) that the omission
is only safe while `desiredAPYBps == 0`, pointing at this entry. Before enabling a non-zero APY, treat
the phUSD leg as an open Medium and re-evaluate M-05 / V2-M-03 together.

---

<a id="q-02"></a>
### [Q-02] Retired promo tokens fall outside `withdrawAll`'s live-slot sweep <!-- id: pe8q2 -->

**Location**: [MigratorV2V3.sol `withdrawAll`](../../../../lib/phlimbo-ea/src/MigratorV2V3.sol)

**Description**: `withdrawAll` reads only the **live** promo slot. Once a promotion rotates, a retired
promo token's balance held by the migrator is outside the escape hatch's coverage entirely and cannot
be swept.

**Why QA**: a coverage gap in an escape hatch, not a defect in the live path. No value is at risk in
normal operation and no user action is blocked; the gap only matters if the hatch is needed for a
retired token.

**Coupling**: this entry is coupled to **V3-Q-01**'s proposed closure (the sibling
`withdrawAll`-omits-a-`promoToken`-sweep note on PhlimboV3, `pe7q1`). Close them together — a fix that
addresses only the live slot on one contract leaves the same gap on the other.

**Recommendation**: Add an explicit `sweepToken(address token)` `onlyOwner` escape hatch so the
recovery surface is not coupled to whichever token currently occupies the live promo slot.

---

## Appendix: Automated SAST / Gas Report (4naly3er)

**4naly3er output unavailable for run 08 — the tool stalls in solc-js compilation and never emits a
report body. This reproduces the recurring gap recorded on run 07 verbatim.**

**What was attempted this run** (commit `bf42c12`):

1. **Direct run from the submodule root** — `yarn analyze <abs>/lib/phlimbo-ea/src`. phlimbo-ea ships
   a real `remappings.txt` (`forge-std/`, `@openzeppelin/`, `@reflax-yield-vault/`, `@flax-token/`),
   and the **documented foundry.toml-only remappings gap did NOT bite**: 4naly3er resolved and
   enumerated the full 12-file scope (`IFlax.sol`, `MigratorV1V2.sol`, `MigratorV2V3.sol`,
   `Phlimbo.sol`, `PhlimboV2.sol`, `PhlimboV3.sol`, and 6 interfaces) without error. The scratchpad
   staging workaround (`remappings.txt` + `src` symlink with absolute paths) was therefore **not
   required** and was not applied. `lib/` was never written to.
2. **Extended-budget re-run in the background** — same result.

In both attempts 4naly3er enumerated the scope, pegged a core at ~100% CPU inside the bundled solc-js
compile step, and **never advanced to emit the QA/gas findings section** (output frozen at the scope
listing) within the session's time budget. This is a **tool reliability limitation, not a scope or
configuration error**, and it matches prior runs against these OZ-heavy contracts. Run 06 is the last
run for which 4naly3er completed.

**Impact on this report: none.** Every Low/QA finding above was sourced from the full Tier-1/Tier-2/
Tier-3 pipeline (Slither, Aderyn and Semgrep all ran clean from the submodule root this run), not from
4naly3er. Only the automated bot-report *baseline* is missing.

**To obtain the baseline**: retry with a native-`solc` 4naly3er build, or allow a compile budget
longer than this session permitted.
