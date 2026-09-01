# QA Report for stable-staker (run 17)

**Commit audited**: `96d39ed`
**Scope**: `src/**` (10 Solidity files), plus cross-repo configuration and documentation defects that bear on this scope.

## Summary

| Severity | Count | Severity-bearing |
|----------|-------|------------------|
| Low Risk | 9 | 9 |
| QA / Process | 2 | 1 — **[Q-01] is `severityBearing: false`** and is **not** counted in the tally |
| Centralization | 0 | 0 |
| **Total** | **11 items** | **10 severity-bearing findings** |

**Read the table with this caveat.** The 11 is a count of *items in this bundle*, not of severity-bearing
findings. **[Q-01]** is a cross-repo ledger-reconciliation obligation, not a defect in this project; it is
carried here so it cannot be dropped, and it is flagged `severityBearing: false` in `classified.json` so it
cannot inflate the finding count. Counting the whole run (this bundle plus the separately-submitted Medium),
the run raises **12 items, of which 11 are severity-bearing**.

No Centralization findings were raised this run. The owner-privilege surface that automated tooling flags (see the appendix, 4naly3er M-2, 36 instances) is the trusted, non-malicious owner assumed by this project's audit charter, and is not reportable as such. The one owner-facing hazard worth an operator's attention this run is stated inside **[L-01]** and **[L-05]** rather than as a separate centralization entry.

The Medium raised this run — the story-025 reward-forfeiture trap on `emergencyWithdraw` — is submitted separately and is **not** part of this bundle.

---

## Low Risk Findings

### [L-01] The `claimEnabled` gate is bypassable in two ordinary transactions, and story-025's stated ground for accepting the loophole is falsified <!-- id: ss17l1 -->

**Law-2 cross-reference**: reported as **F-01** in `spec-conformance.md` (source finding `CLASS-001`).

**Location**: [`src/StableStakerV2.sol#L417-L419`](../../../../lib/stable-staker/src/StableStakerV2.sol#L417), [`#L540`](../../../../lib/stable-staker/src/StableStakerV2.sol#L540), [`#L605`](../../../../lib/stable-staker/src/StableStakerV2.sol#L605)

**Description**: With `claimEnabled == false` (the deployment default), `claim()` reverts `StableStaker: claim disabled`, and story-025 intends a weeks-long "teaching phase" in which reward can only be taken via `autoAnnihilate`, annihilated against principal. That throttle is fully defeated by two ordinary calls:

1. `withdraw(token, user.amount)` — **ungated**. Lines 417-419 settle the entire pending reward into `unclaimedReward` and zero `user.amount`.
2. `autoAnnihilate(token, 0)` — `principalAsAntimatter = user.amount * scale == 0` (:540), so the cap and `netWanted` collapse to zero, the annihilate block is skipped entirely, and `excessBase` is the whole backlog. Line 605 `antimatter.mint(msg.sender, excess)` delivers 100% of it raw to the caller's wallet.

A partial withdraw tunes exactly how much is taken raw; the position can then be re-staked.

**The accepted rationale does not cover this.** Story-025's ground for tolerating a raw-mint path reasons only about *rewards outgrowing principal* — a condition it argues takes a long time to arise. It never reasons about a caller **shrinking principal** via `withdraw`, which is the actual mechanism here and takes one ordinary transaction, not a long time. The premise the acceptance rests on is therefore not the premise that governs. This also works while Antimatter itself is paused.

**Evidence**: Tier-3 deterministic replay `Run17_ClaimGateBypass::test_twoTransactionsDrainTheWholeBacklogWithTheGateShut` delivered `4166666666666666661600` wei = 10,000 bps = **100% of entitlement**, raw, in two transactions, with the gate shut. The ungated raw mint at :605 executed 13,630 times under Medusa line coverage, so the path is not a harness artifact.

**Bound (stated so the finding is not over-read)**: **Conservation is exact.** The bypass pays the staker precisely what `claim()` would have paid and not one wei more. INV-1/INV-2 measured **zero over-emission** over the emission ceiling across ~943,000 calls (640,640 Foundry + 302,817 Medusa); the 1024-wei `DUST_SLACK` was never consumed. No dilution of other stakers, no principal-accounting breach (INV-3 PASS), no protocol funds moved. What is defeated is a pedagogical throttle, not a solvency property — which is why this is Low and not Medium.

**Recommendation**: Gate the raw-mint leg on the same flag that gates `claim()`, since raw delivery is economically the same event:

```solidity
// StableStakerV2.sol, before the raw mint at :605
if (excess > 0) {
    require(claimEnabled, "StableStaker: claim disabled");
    antimatter.mint(msg.sender, excess);
}
```

If the raw leg must stay open for the underwater/dust cases, gate instead on `user.amount == 0` at entry to `autoAnnihilate`, so a fully-withdrawn caller cannot use the zero-principal shortcut. Either way, correct the story's stated rationale so a future reader does not re-derive the acceptance from the falsified premise.

---

### [L-02] The exit-shortfall floor is blind to a fee-charging ERC4626 vault; the live-Medium case is REFUTED by measurement, with an armed escalation trigger <!-- id: ss17l2 -->

**Law-2 cross-reference**: reported as **F-06** in `spec-conformance.md` (source finding `CLASS-002`).

**Location**: [`src/StableStakerV2.sol#L588`](../../../../lib/stable-staker/src/StableStakerV2.sol#L588) (`autoAnnihilate` shortfall check, `EXIT_ROUNDING_ALLOWANCE` + 1 bp proportional allowance)

**Description**: `autoAnnihilate` requires the amount received from the strategy to clear a floor of `netFloor` less a flat 2 raw units and a 1 bp proportional allowance. That floor is blind to an ERC4626 vault that charges an exit fee: the haircut is proportional, so it scales with the request while the flat 2 units do not, and any haircut above the 1 bp allowance reverts every call above `N = 2 / (f - 1e-4)` raw units.

**This is NOT live, and the Medium case was refuted by measurement performed in this run — not carried from a prior audit.** A fresh mainnet fork at **block 25,878,600** (cold cache, re-fetched over RPC in 74.50s; numbers reproduced identically, 5/5 tests pass) measured:

| Pool | Measured exit discount | Allowance | Headroom |
|------|-----------------------|-----------|----------|
| autoDOLA | **0.473049 bps** | 1.00 bp | ~2.11x |
| autoUSD | **0.535370 bps** | 1.00 bp | ~1.87x |

**No revert was observed at any reward size**, from dust to full principal, on either pool. Halmos corroborates the boundary exactly: `check_noBrick` PASSes at 0 / 0.47 / 0.54 / 0.90 and at **exactly 1.00 bp**; `check_crossing_101_hundredthsBp` FAILs with a counterexample, making **1.01 bp the smallest reverting haircut** (minimal reverting `netFloor` = 2,009,901 ≈ **2.01 USDC**); and `check_control_5bp` FAILs as the positive control, proving the harness can find the brick when one exists.

**Escalation trigger (armed)**: the deciding parameter is **external** — the wired Tokemak autopool's modeled exit discount. Three facts make the residual Low worth carrying rather than closing:

- The margin is only **~1.85x** and **does not grow with position size** — it is a fixed ~0.5 bp of headroom regardless of TVL.
- Both allowances are `constant` with **no setter**. If the trigger fires there is no parameter remedy — only a redeploy, or a fee-aware `previewExitFor` override in `reflax-yield-vault` that does not exist at the pinned commit `cdd0743`.
- Nothing in the wiring runbook ties reward-path liveness to an external vault's fee parameter, so nobody is watching the headroom.

Crossing 1 bp converts this into a **hard DoS of the reward path**, because with `claimEnabled` false `autoAnnihilate` is the intended sole reward path. The decimals cliff sharpens it: the flat 2-unit allowance is worth 2e-6 USDC on a 6-decimal pool but 2e-18 DOLA on an 18-decimal pool, where the entire margin is the 1 bp. The revert string also names the *strategy* rather than the constant, pointing diagnosis at the wrong contract.

**Recommendation**: Do **not** widen the 1 bp allowance — it was chosen deliberately below any real haircut, and per L-04 the flat 2 is load-bearing. Instead:

1. Add an off-chain monitor on the wired autopools' exit discount, alerting at 0.8 bp (before the 1.00 bp cliff).
2. Make the allowance an owner-settable parameter with a hard upper bound, so a trigger event has a remedy short of redeploy.
3. Change the revert string to name the constant rather than the strategy, e.g. `"StableStaker: exit below EXIT_BPS_ALLOWANCE"`.

---

### [L-03] A zero-principal backlog holder has no reward path at all on a Migrating pool while `claimEnabled` is false <!-- id: ss17l3 -->

**Location**: [`src/StableStakerV2.sol#L440`](../../../../lib/stable-staker/src/StableStakerV2.sol#L440), [`#L517`](../../../../lib/stable-staker/src/StableStakerV2.sol#L517), [`#L630`](../../../../lib/stable-staker/src/StableStakerV2.sol#L630), [`#L866`](../../../../lib/stable-staker/src/StableStakerV2.sol#L866)

**Description**: A staker with `user.amount == 0` and a non-zero `unclaimedReward` on a pool moved to `Migrating` matches none of the four exits: `claim` is blocked by the flag (:440, which has no `PoolState` gate), `autoAnnihilate` requires `Active` (:517), `userMigrate` requires `amount > 0` (:866), and `emergencyWithdraw` requires `Active` and forfeits anyway (:630).

Note the coupling: **this is precisely the user state L-01's bypass creates.** A staker who uses the bypass and is caught mid-migration is wedged. `claim`'s own NatSpec at :435-437 names this exact user ("someone who fully withdrew and has not claimed yet"), so the class is known to the code's own author.

The backlog **survives** `finalizeAndReset`, which clears only `migrationInfo` and `poolState` — so nothing is destroyed. Recovery is possible, but only through an owner action (`setClaimEnabled(true)`) or by the pool being revived to `Active`. Owner-recoverable with value intact is why this is Low and not the Medium.

**Recommendation**: Make `claim()` `PoolState`-aware, so the flag cannot close the last door on a migrating pool:

```solidity
// :440 — allow the claim gate to be bypassed for a user with no live position on a non-Active pool
require(
    claimEnabled || (pool.state != PoolState.Active && userInfo[token][msg.sender].amount == 0),
    "StableStaker: claim disabled"
);
```

---

### [L-04] Dust-window liveness failure: a caller owed a sub-share-price amount reverts `exit shortfall`, accusing an honest ERC4626 strategy of lying <!-- id: ss17l4 -->

**Location**: [`src/StableStakerV2.sol#L588`](../../../../lib/stable-staker/src/StableStakerV2.sol#L588); `reflax-yield-vault/src/ERC4626YieldStrategy.sol#L126-L138`

**Description**: A caller owed exactly 1 wei has `netWanted == 1`; `_disposeShares` double-rounds down, `convertToShares(1) == 0`, `redeem` delivers 0, and `require(received > 0)` at :588 reverts `StableStaker: exit shortfall`. The message accuses an honest strategy of misreporting when the real cause is integer rounding against a yielded vault.

**This is a genuinely observed transient, not a theoretical one**: **50 of 17,729** gate-closed attempts (0.28%) at HEAD. Crucially, **46 of the 50 landed on pool 1 — the REAL `ERC4626YieldStrategy` over a real OZ vault** — so the result comes from production code, not from a permissive mock; the 4 pool-2 hits are discounted as non-load-bearing. The counterexample share price was 1.2467 assets/share.

It is **self-healing**: the owed dust remains in `unclaimedReward` and the call succeeds once further accrual pushes `owed` above the boundary. Nothing is lost and no path is permanently closed, which is why this stays Low. The real cost is diagnostic — with L-02's remedy note and L-06's false green, an operator debugging a stuck reward path is pointed at the wrong contract three times over.

**Critically, `EXIT_ROUNDING_ALLOWANCE = 2` is load-bearing and must NOT be reduced.** INV-6's scaling law shows the floor fails whenever `assetsPerShare > 2 + netFloor / 10_000`; the flat 2 is what holds it. It must not be raised for this finding either — the correct fix is upstream of the floor.

**Recommendation**: Short-circuit the dust case before the floor is consulted, leaving the constant untouched:

```solidity
// before the strategy exit in autoAnnihilate
uint256 shares = IERC4626(vault).convertToShares(netWanted);
if (shares == 0) return; // owed dust; leave it in unclaimedReward to accrue
```

---

### [L-05] ADDENDUM to wont-fix ledger entry `69c7666eee` — `autoAnnihilate` draws a tolerance-inflated GROSS from the shared buffer per unit of reward <!-- id: ss17l5 -->

**Location**: [`src/StableStakerV2.sol#L558`](../../../../lib/stable-staker/src/StableStakerV2.sol#L558), [`#L607-L609`](../../../../lib/stable-staker/src/StableStakerV2.sol#L607), `_routeExit` [`#L1186-L1195`](../../../../lib/stable-staker/src/StableStakerV2.sol#L1186)

**This is an addendum to an existing owner-triaged entry, not an independent finding.** The underlying value-transfer class is **ledger entry `69c7666eee`** — *"Underwater withdraw buffer is FCFS at par, socializing strategy loss onto slow stakers"* — closed **wont-fix** with the owner's triage reason: *"Intended design (confirmed by protocol owner)... sized for daily-volume withdrawals."* A second entry, `2b9a89d29c`, is wont-fix on the merits VALID, closed only because the mitigation is operational and lives in `phoenix-phase-2-staging`.

It is disclosed here rather than suppressed because both prior entries are fingerprinted on `_routeExit`, and filing on `autoAnnihilate` mints a **different fingerprint for the same root cause** — with 28/46 fingerprint drift already recorded on this project, dedup would have passed it through as new. Naming the prior entry is the point of this section.

**The only new content is the RATE.** Nothing else here is new, and no new exposure is claimed: the per-caller bite is still capped by the caller's own principal (`gross = min(grossQuote, user.amount)`, :558), so the buffer drain is no larger than `withdraw` already permits, and the caller is value-neutral against their own books (debited `gross` at :565-566, receives `netWanted` plus surplus; zero PnL versus `withdraw(gross)`). **It is not an extraction.**

What is new is that `autoAnnihilate` consumes `1/(1 - slip)` times more buffer *per unit of reward annihilated* than the transaction economically needs, where `withdraw` requests exactly `amount` — and because `claimEnabled` ships false, the caller cannot opt out by claiming instead. **Tier-3 measured a single call paying `202767365267183752539` raw units — 202.77 units of `surplus` — to one caller out of the shared idle buffer, at 1.5% exit slippage with the strategy 2% below par.** The `:1190` carve-out was reached 6,387 times across the two campaigns.

**Why this bears on the owner's own decision**: `69c7666eee`'s triage reason sizes the buffer for **daily WITHDRAWAL volume**. Story-025 adds a new, grossed-up, reward-driven draw to that same pool, which the sizing input did not contemplate. That is an input to the owner's sizing re-check, not a reversal of the wont-fix.

**Current exposure is NIL on the wired configuration.** For the wired direct `ERC4626YieldStrategy`, `previewExitFor` is the capped identity, so `grossQuote == netWanted`, `surplus` is always 0, and the :607-609 surplus leg is dead code. The rate above is latent against a future **market** strategy.

**Recommendation**: No code change is proposed — the class is owner-accepted. Re-run the buffer sizing with reward-driven draw included in the daily-volume input **before** a market strategy is wired, and record the revised sizing basis against `69c7666eee`.

---

### [L-06] `autoAnnihilateAvailable` returns true in exactly the state where `autoAnnihilate` reverts, and its probe is near-vacuous <!-- id: ss17l6 -->

**Law-2 cross-reference**: reported as **F-03** in `spec-conformance.md` (source finding `CLASS-010`).

**Location**: [`src/StableStakerV2.sol#L1058`](../../../../lib/stable-staker/src/StableStakerV2.sol#L1058), [`#L1061`](../../../../lib/stable-staker/src/StableStakerV2.sol#L1061)

**Description**: Two independent inaccuracies in one view:

1. **False green.** The view early-returns `true` whenever `strategy.principalOf(token, address(this)) == 0` (:1058). A staker can hold `user.amount > 0` in that state — principal idle after a buffer-path `relinquishPrincipal`, or a strategy set before deposits routed into it. Both `previewExitFor` implementations cap `grossToRequest` at `clientBalances`, so `grossQuote == 0` and :557 reverts `StableStaker: exit unavailable`.
2. **Vacuous probe.** The 1-unit probe at :1061 detects essentially nothing. For the direct strategy, `previewExitFor(1)` returns `min(1, clientBalances)` and `clientBalances >= 1` is *already* guaranteed by the `principalOf != 0` early-return — the strategy leg is a tautology. For the market strategy, `ceilDiv(1 * MAX_BPS, MAX_BPS - slip) == 1` for any `slip < 5000` bps. The view detects exactly one condition: a 100% slippage tolerance.

This inverts story-025's Round-2 Decision 4, which reasons that returning **false** would be the inconsistent answer; the code makes **true** the inconsistent answer. The impact is a misleading UI and gas wasted on a reverting transaction — capped at Low by the standing rule on view functions, though it is Low rather than QA because the view *is* consumed by the UI it was written for. It is the third diagnostic misdirection in the same debugging session (with L-04 and L-02), and is widened by both: the probe can see neither a fee-charging vault nor a dust revert.

This is also the **second** availability-view-disagrees-with-its-transaction entry on StableStaker, after open entry `a56f87780b` on `withdrawDisabled`, which errs in the opposite direction — a systemic pattern worth stating once.

**Recommendation**: Drop the `principalOf == 0` early-return and probe with the caller's actual figure rather than 1 unit:

```solidity
function autoAnnihilateAvailable(address token, address user) external view returns (bool) {
    uint256 netWanted = _netWantedFor(token, user);
    if (netWanted == 0) return false;
    try strategy.previewExitFor(token, address(this), netWanted) returns (uint256 q) {
        return q > 0;
    } catch { return false; }
}
```

---

### [L-07] CARRYOVER, re-confirmed unfixed on-chain this run: `addresses.json` records autoDOLA as a Vesper vault whose `asset()` and `totalAssets()` revert <!-- id: ss17l7 -->

**Location**: `reflax-yield-vault` deployment config, `addresses.json` (autoDOLA record). Prior entry: **`0c12a2cfaf` (CFG-01)**, still open.

**Description**: The address recorded as autoDOLA, **`0x0538...36ee`**, is a **Vesper vault, not a Tokemak autopool**: `asset()` and `totalAssets()` **revert** on it. Deploying against this record produces a hard wiring failure. Re-confirmed on-chain during this run's fork work (block **25,878,600**, same session as the L-02 measurement artifact) — this is a re-confirmation of a still-unfixed carryover, not a re-file.

The correct autoDOLA is **`0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d`**.

**Why it belongs in a stable-staker report**: L-02's entire liveness argument turns on *which* autopool is wired. A config naming a non-ERC4626 contract as autoDOLA does not produce a fee brick — it produces a hard construction failure — and it also means the reassuring 0.473 bps autoDOLA measurement describes the **correct** autopool, not necessarily the one this config would deploy against.

The C4 third-party/out-of-scope-dependency exclusion does not apply: the defect is a wrong on-chain address **record**, not a bug in a third-party contract. Because the failure is at construction/wiring — attended and fail-loud — no asset or availability limb is reached in a deployed system, so it stays Low.

**Recommendation**: Correct the record to `0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d`, and add a deployment-time assertion that every configured autopool answers `asset()` and `totalAssets()` before wiring proceeds. Do not mint a new stable-staker ledger entry; carry the re-confirmation date onto `0c12a2cfaf`, which stays open.

---

### [L-08] The story bounds the raw-mint path by the AMM slippage tolerance; the real bound is `min(user.amount, clientBalances)`, and the second term is neither user-controllable nor tolerance-bounded <!-- id: ss17l8 -->

**Law-2 cross-reference**: reported as **F-05** in `spec-conformance.md` (source finding `CLASS-012`).

**Location**: [`src/StableStakerV2.sol#L596`](../../../../lib/stable-staker/src/StableStakerV2.sol#L596); story-025 Round-2 front-running analysis

**Description**: Story-025 states that the raw-mint path *"is bounded: `ERC4626MarketYieldStrategy` enforces `minOut`... internally and reverts before `autoAnnihilate` ever sees the proceeds, so the extractable amount is capped at the tolerance."* A **second, unmodelled cap** exists and it is neither tolerance-related nor caller-set: both `previewExitFor` implementations cap `grossToRequest` at `clientBalances[token][address(this)]`. When it binds, `grossQuote`, `gross`, `netFloor` and `netUsed` all shrink below `netWanted`, and the remainder is minted raw via `excess = excessBase + (netWanted - netUsed) * scale` (:596). On `ERC4626MarketYieldStrategy` the cap binds **structurally**, because `_acquireShares` books the haircut `creditedPrincipal` rather than the nominal deposit, so `clientBalances` is permanently below the pool's nominal `totalStaked`.

**This is explicitly not a value leak.** Conservation still holds — `owed in == annihilated + raw-minted + carried dust`, independently verified by ECON-005 and INV-1/INV-2 (PASS, zero overshoot). No Antimatter is created beyond what the caller was owed, and the second cap is not something a caller can steer. What is falsified is a **security bound the owner reasons from**, which is why this is not dropped to QA.

Kept strictly distinct from L-01: this corrects the *stated bound* on the raw-mint path (a documentation edit); L-01 is the *existence* of a far wider, unrelated channel into the same line (a design question). Fixing one does nothing for the other.

**Recommendation**: Correct story-025's bound statement to `min(user.amount, clientBalances[token][address(this)])`, and note that on a market strategy the second term binds structurally and is protocol-level rather than tolerance-bounded.

---

### [L-09] The docs describe only the un-grossed underwater buffer draw, and no test covers `autoAnnihilate` against an underwater strategy <!-- id: ss17l9 -->

**Law-2 cross-reference**: reported as **F-04** in `spec-conformance.md` (source finding `CLASS-011`).

**Location**: `lib/stable-staker/CLAUDE.md` (round-3 carve-out, commit `a961e10`); `test/` (missing coverage); [`src/StableStakerV2.sol#L580-L586`](../../../../lib/stable-staker/src/StableStakerV2.sol#L580)

**Description**: Two mutually reinforcing gaps in the same place.

**The documented behaviour is false at HEAD.** The CLAUDE.md round-3 carve-out states that when `_isUnderwater` is true, `_routeExit` *"pays the whole request out of the idle balance plus `relinquishPrincipal` and returns the nominal amount without measuring anything"*, and story-025's Round-2 checklist states *"Tests — confirm the idle buffer is UNTOUCHED across every case above."* In fact `surplus = gross - netWanted > 0` is `safeTransfer`red to the caller **out of the shared idle buffer**, and `relinquishPrincipal(token, gross)` writes booked principal down by the **inflated** figure. The buffer is demonstrably not untouched.

**The test that would have caught it does not exist.** No test covers `autoAnnihilate` against an underwater strategy — even though round 3 corrected `MockYieldStrategy.previewExitFor` *specifically so the case could be tested*. The correction landed; the test did not. This is how L-05's rate went unobserved.

Recorded alongside: the `"MANDATORY MEASUREMENT"` promised by the NatSpec at :580-586 is **vacuous** on this branch (`received == gross >= netFloor` always). That is a documented carve-out and is safe, because `t.balanceOf(this) >= amount` is checked directly at :1190 — but the NatSpec overstates what it does.

Kept at Low rather than QA because the falsified claim is **behavioural, not editorial**, and because the missing test is the one that would have caught L-05.

**Recommendation**: Correct the CLAUDE.md carve-out and the NatSpec at :580-586 to describe the grossed-up draw and the surplus transfer, and add the underwater `autoAnnihilate` test the round-3 mock correction was made to enable, asserting the buffer delta explicitly.

---

## QA / Process Items

### [Q-01] Cross-repo routing obligation: `StableStakerV2:556` is `previewExitFor`'s first production consumer anywhere in the tree, firing reflax-yield-vault's WATCH-17-03 on five Low findings at once <!-- id: ss17q1 -->

**Location**: [`src/StableStakerV2.sol#L556`](../../../../lib/stable-staker/src/StableStakerV2.sol#L556) → `_previewExit` → [`#L1175`](../../../../lib/stable-staker/src/StableStakerV2.sol#L1175) → `strategy.previewExitFor`

**This is a ledger-reconciliation obligation, not a security finding, and must not be counted as one in any severity tally.**

reflax-yield-vault run-17 held five `previewExitFor` findings at Low on WATCH-17-03, whose premise reads verbatim: *"`previewExitFor` has ZERO CONSUMERS across all nine top-level submodule HEADs, verified THREE times independently and untruncated."* **That premise is now false.** Carrying those five Low ratings forward unexamined would be a recall failure.

The arming analysis, carried rather than flattened:

- **L-18 (`5351fd4d3f`, "the documented FLOOR is really a CEILING") — ARMS.** `previewExitFor` returns `min(netWanted, clientBalances)` from storage with no vault call, cannot see the `availableShares` cap inside `_disposeShares`, and `autoAnnihilate` consumes exactly that value as `netFloor`. It is **dominated, not exploitable**, because `autoAnnihilate` passes `guardUnderwater = true` at :579 and the cap-binds-implies-underwater dominance routes the call to the buffer branch or a revert first. **Critical caveat: that dominance rests on two invariants no test pins** (`AYieldStrategy.sol:48` `p <= D`, and `:772-776` `a <= p`). Keep the `DominanceRun17Grounding` test.
- **L-23 (`e6088a0ec5`) — ARMS.** Held at Low because "V1 is wired, not V2". `autoAnnihilate` is V2-only code, so that rating **expires the moment V2 is deployed**. V2 has zero broadcast hits today, so the Low still holds — but only today.
- **L-22 — DOES NOT ARM.** Preview (:556) and execution (:579) are in the same transaction with no intervening external call and no attacker-controlled callback (`nonReentrant`, CEI holds to :571).
- **L-19** — its fee leg is partly settled for the current wiring by this run's fork measurement (see **L-02**) and now stands at Low on spec-deviation weight rather than availability.

**Action**: Reconcile against the reflax-yield-vault ledger WATCH-17-03 before this run closes. Record under `ledger.crossRepoRoutes`; do **not** mint a stable-staker finding entry.

---

### [Q-02] CLAUDE.md's headline description of `autoAnnihilate` states the round-1 NET debit, which round 2 identified as the underflow bug — the document contradicts itself, and the wrong version is what a reader meets first <!-- id: ss17q2 -->

**Law-2 cross-reference**: reported as **F-02** in `spec-conformance.md` (source finding `CLASS-009`).

**Location**: `lib/stable-staker/CLAUDE.md:85-93` (the "stable half" claim at `:92`) (section "The claim gate and autoAnnihilate (story 025)", added in `afa7b80`, left uncorrected by `57eb02d` and `a961e10`)

**Description**: The section states that `autoAnnihilate` *"decrements `userInfo.amount` and `poolInfo.totalStaked` by the STABLE HALF"* — the NET-debit model that story-025's own Round-2 reopen identified as the **underflow bug** (*"if the cap stays on the net amount then `user.amount -= stableNeeded` UNDERFLOWS for exactly the user annihilating their whole position"*). A later bullet in the *same section* states the correct semantics, so the document contradicts itself and the wrong version is what a reader meets first.

**The code is correct** — `src/StableStakerV2.sol:565-566` debits the GROSS (`user.amount -= gross; pool.totalStaked -= gross`) — so nothing behavioural turns on this, which is why it is QA rather than Low.

It is not dropped, for two reasons. First, the defect is in the **declared known-issues source itself**: a document that contradicts itself about the function under review lowers confidence in every future suppression extracted from that section, and that should be carried into the next run's extraction note. Second, it is the **second** CLAUDE.md-documents-a-superseded-model entry on this project, after `ss9f3-clau` (still open) — a pattern, not an isolated typo.

**Recommendation**: Correct the headline bullet to state the GROSS debit, matching :565-566 and the later bullet in the same section.

---

## Appendix A — 4naly3er automated report

**Status: RAN SUCCESSFULLY.** Full output attached at [`4naly3er-report.md`](./4naly3er-report.md) (4,373 lines).

**Coverage: 10 of 10 in-scope Solidity files**, all resolved with the project's own `remappings.txt`:

```
src/CrossVersionMigrator.sol            src/interfaces/IStableStakerMigratable.sol
src/InPlaceMigrator.sol                 src/versions/v1/IStableStakerV1.sol
src/StableStakerV2.sol                  src/versions/v1/StableStakerV1.sol
src/interfaces/IAntimatter.sol          src/versions/v1/vendor/FlaxToken.sol
src/interfaces/IStableStaker.sol        src/versions/v1/vendor/IFlax.sol
```

Invocation (note: the third argument is a **scope list**, not a remappings file; `remappings.txt` resolves relative to `BASE_PATH`, so `BASE_PATH` must be the submodule root):

```bash
cd tools/4naly3er
yarn analyze /home/justin/code/audits/lib/stable-staker /tmp/ss17-scope.txt \
  https://github.com/Behodler/stable-staker
```

**Aggregate**: 16 gas-optimization categories, 23 non-critical categories, 15 low categories, 2 medium categories.

| Category | Notable entries |
|----------|-----------------|
| Gas | `unchecked` for non-overflowing ops (183), custom errors instead of revert strings (85), `!= 0` vs `> 0` (48), assembly `address(0)` checks (27) |
| Non-critical | Functions longer than 50 lines (125), missing `indexed` event fields (44), duplicated `require`/`revert` (33), incomplete NatSpec `@param` (24), named mappings (18) |
| Low | Loss of precision (27), 2-step `transferOwnership` (10), division-by-zero not prevented (8), zero-value-transfer reverts (15), possible rounding (4) |
| Medium | Fee-on-transfer accounting (2); centralization risk for trusted owners (36) |

**Adjudication of the automated Medium categories** — neither is filed as a finding:

- **Fee-on-transfer accounting (2 instances, `StableStakerV2.sol:1113`)** is a standing known-invalid class for this audit unless fee-on-transfer tokens are explicitly in scope, which they are not.
- **Centralization risk for trusted owners (36 instances)** is the trusted, non-malicious owner. Per this project's charter, "a malicious owner could…" vectors are not reportable. The genuinely non-obvious owner-facing hazards this run are stated in **L-01** and **L-05**.

**Deliberately NOT filed**: this repository builds **unoptimized and over the EIP-170 contract size limit on purpose** — the source-repo profile is unoptimized while the deploy profile is staging (`optimizer` + `via_ir`). The oversize is therefore not a QA item and is excluded from this bundle.

---

## Appendix B — Semgrep INFO-level style/gas aggregate

157 INFO-level hits, summarized rather than enumerated. **None carry security signal**; they are retained here in aggregate so nothing is invisible. Source: `findings/static-analysis-findings.json` → `semgrepInfoAggregate`.

| Rule | Hits |
|------|-----:|
| `use-custom-error-not-require` | 88 |
| `use-short-revert-string` | 17 |
| `use-prefix-increment-not-postfix` | 14 |
| `unnecessary-checked-arithmetic-in-loop` | 11 |
| `state-variable-read-in-a-loop` | 10 |
| `use-ownable2step` | 4 |
| `non-payable-constructor` | 4 |
| `use-nested-if` | 4 |
| `array-length-outside-loop` | 3 |
| `use-multiple-require` | 2 |
| **Total** | **157** |

These overlap substantially with 4naly3er's GAS-7 (85 custom-error instances), GAS-12 (15 prefix-increment), GAS-15 (11 unchecked loop increments) and L-1/L-12 (2-step ownership) categories; they are two tools reporting the same style surface and should be treated as one backlog item, not two.
