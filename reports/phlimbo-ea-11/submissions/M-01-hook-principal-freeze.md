<!--
ID: pe11m1
C4 Submission Metadata
Title: [M-01] Un-try/catch'd IPhlimboHook freezes every staker's principal pool-wide; PhlimboV3 has no hook-exempt exit and the sole remedy is now concentrated in the owner
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV3.sol#L780-L782
PoC File: PoC_CODE001_HookPrincipalFreeze.t.sol
Severity: Medium (CONFIRMED by severity-auditor; VALID/high-confidence by validity-checker)
Commit: f279c62
Fingerprint: 4f97b39e8f95fa60c4f444df14757f363ddccf8d4eea49886c9b69f812bf4794
Origin: CODE-001 -> DEDUP-11-002 -> CLASS-11-001
Materiality: config-conditional (inert until setHook is called with a non-zero address) — see "Honest scope"
-->

## Finding description and impact

### Summary

`PhlimboV3` invokes the optional `IPhlimboHook` with **no `try`/`catch`** at the tail of all three principal-moving functions. A reverting hook unwinds the entire call — including `withdraw`'s principal `safeTransfer` — so **every staker's principal is frozen pool-wide, indefinitely, with no user-side recourse**, until the owner calls `setHook(address(0))`.

| Call site | Function | Code |
|---|---|---|
| [`PhlimboV3.sol#L730`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV3.sol#L729-L731) | `stake` | `hook.onDeposit(msg.sender, user, amount);` |
| [`PhlimboV3.sol#L781`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV3.sol#L780-L782) | `withdraw` | `hook.onWithdraw(msg.sender, user, actualWithdrawAmount);` |
| [`PhlimboV3.sol#L813`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV3.sol#L812-L814) | `claim` | `hook.onClaim(msg.sender, user, pendingPhUSDAmount, pendingRewardAmount);` |

The mechanism itself is old — the hook leg is inherited from `PhlimboV2` and is **not** introduced by any story in this baseline window. What changed is its **materiality**.

### Why this is surfaced at this baseline

**1. story-031 made the hook the *sole* remaining principal-freeze path.** The three-story arc (027 stable/promo bank, 029 non-reverting reward forwarding, 031 phUSD mint bank) was spent making every reward leg in `_claimRewards` non-reverting. Story-031 banked the last one — the phUSD mint at [`:913`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV3.sol#L913). That `try`/`catch` is now the **only** `try`/`catch` in the entire file; the three hook sites above remain bare. The hook is what is left.

**2. story-030 removed PhlimboV3's second, independently-held remedy.** Ledger entry **V2-L-09** (`08da5bba`, open, low, `src/PhlimboV2.sol`) records this exact mechanism and states its Low rationale in full:

> "Reverting/gas-heavy `IPhlimboHook` bricks stake/withdraw/claim (no try/catch); **pauseWithdraw is hook-exempt so a principal exit survives**."

Story-030 removed `pauseWithdraw` from V3. Verified by untruncated full-file grep at `f279c62`: `src/PhlimboV3.sol` contains **zero** occurrences of `pauseWithdraw` and **zero** of `emergencyWithdraw`. PhlimboV3 has no hook-exempt exit of any kind.

**A precision point that narrows this argument, stated because it is true.** That V2 exit was never a *unilateral user* escape. `PhlimboV2.pauseWithdraw` is `whenPaused` ([`:280`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV2.sol#L280)) and `PhlimboV2.pause()` requires `msg.sender == pauser` ([`:270`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV2.sol#L270)). On V2, a privileged party had to act first — exactly as on V3. So the accurate V2→V3 delta is **not** "users could escape and now cannot". It is:

> V2 has **two independently-held privileged remedies** — the `pauser` role could free principal without the owner. V3 has **one**: only the owner, via `setHook(address(0))`.

That is a genuine reduction in remedy redundancy, and it does void V2-L-09's stated Low rationale as applied to V3. But it is a marginal difference, not a full severity band, and **the Medium below deliberately does not rest on it.**

### Failure path

No attacker is involved at any step.

1. **Owner calls `setHook(analyticsHook)`** — a legitimate, first-class, shipped feature: an observer for points, boosters, or indexing. The hook is benign and correctly written.
2. **The owner's post-`setHook` smoke test passes.** Stake, withdraw and claim all work (`test_CODE001_B`). Nothing signals a principal hazard.
3. **Time passes — 30 days in the PoC. No owner action occurs at or near the freeze.**
4. **The hook begins reverting for a third-party reason it does not control**: a dependency registry pauses, an upgraded downstream contract changes behaviour, an oracle reverts, gas growth exceeds the stipend, or an arithmetic edge trips.
5. **Every `stake`/`withdraw`/`claim` now reverts pool-wide.** `withdraw` still *reaches* its principal `safeTransfer` at [`:774`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV3.sol#L774) — the transfer executes and is then unwound by the hook revert at `:781`.
6. **No user recourse.** Enumerated empirically below.
7. **The freeze persists until the owner notices** and calls `setHook(address(0))`. Duration is bounded only by owner monitoring latency, not by any protocol mechanism.

The trigger is **time-shifted away from the owner's decision**, which is precisely why it evades the owner's validation. This is the core of the footgun: the action that arms it looks completely benign at the moment it is performed.

### Impact

Pool-wide denial of service on principal. Every staker is frozen simultaneously, for an indefinite duration, with zero self-service recovery and no ability to compel the remedy. Rewards are frozen alongside principal (`claim` is on the same leg).

Principal is **frozen, never stolen**: no theft path, no permanent loss, and one cheap `setHook(address(0))` transaction fully restores withdrawals (`test_CODE001_E`). That recoverability is the honest basis for **Medium rather than High**.

Medium rather than Low, on two independent grounds:

- **Literal C4 fit.** Medium is "assets not at direct risk, but the function of the protocol or its availability could be impacted... with stated assumptions and external requirements." A pool-wide, indefinite withdrawal brick is availability impact in its purest form, and the trigger is a textbook external requirement: a third-party revert inside the hook's own execution, outside both the owner's and the users' control at the moment it fires.
- **Internal consistency — an *a fortiori* argument from an owner-ratified precedent.** This project already rates a **strictly narrower** instance of this impact shape at Medium. **V3-M-05** (`69f8b29a`, fix-pending) freezes a **single** blocklisted staker's principal on a genuinely external trigger (a USDC blocklist), and the **owner ratified it at human triage** — triageReason: *"valid Medium, fix owed."* M-01 freezes **every** staker on a likewise-external trigger. Same trigger class, strictly worse blast radius, and the impact shape is already owner-accepted as Medium. If a single-staker freeze on an external trigger is an owner-ratified Medium, a pool-wide freeze on an external trigger cannot be a Low.

This argument stands independent of the V2 story above and independent of the disclosure debate below — it needs neither.

**A precedent this report does not use, foreclosed so no reader reaches for it.** An earlier draft also cited **V3-M-07** for consistency. That citation is **withdrawn**: V3-M-07's Medium rested on the premise that its trigger was "an external shared-ecosystem-token revocation PhlimboV3 does not control", and this run disproved that premise from mainnet broadcast receipts — `MigratePhlimboV1ToV2.s.sol/1/run-latest.json` shows a single EOA (`0xcad1a786…`) calling `setMinter` on phUSD (`onlyOwner` on FlaxToken) *and* `emergencyTransfer`/`setMigrator`/`setPauser` on Phlimbo in the same run, all status `0x1`. Phlimbo's owner and FlaxToken's owner are the same party, so V3-M-07's trigger is not external and it is a weak precedent. M-01 does not lean on it.

### The interface documents this behaviour — and why that does not downgrade the finding

**The concession first, without hedging.** `src/interfaces/IPhlimboHook.sol` explicitly documents the propagation:

> "Hooks fire AFTER all internal state mutations and external token transfers complete, inside PhlimboV2's `nonReentrant` guard. **The owner of PhlimboV2 is trusted to set non-malicious hooks; a reverting hook will revert the outer call.**"

This is real, it is accurate, and it names this finding's exact mechanism in plain words. This is **not** an undocumented behaviour, and any framing that called the propagation itself a hidden trap would be dishonest. A competent owner who reads this interface knows a reverting hook reverts the outer call. That is the strongest single point against this finding and it is raised here rather than left for a reviewer to find. It does not carry the weight required, for four reasons.

**1. The disclosure addresses the case that is not reported, and is silent on the case that is.** Read the sentence as written: the semicolon binds the propagation to the **malice** frame — its plain reading is "do not attach a hostile hook, because a hostile hook can revert your calls." The malicious-hook case is trusted-owner-exempt and is **expressly not what is reported here**. The reported case — a benign, correctly-written hook that begins reverting 30 days later for a third-party reason — is not addressed by that sentence at all.

**2. The disclosed fact and the undisclosed consequence are different propositions.** "A reverting hook will revert the outer call" is a *mechanism*. "A reverting hook freezes every staker's principal, with the sole remedy concentrated in one party" is a *consequence*. On PhlimboV2 — the only contract the docblock names — the mechanism was true and the consequence was materially milder, because a second, independently-held privileged remedy existed. The docblock is a V2-era artifact written for a contract with a different remedy structure. **Its truth value never changed; its meaning got worse.**

**3. The disclosure is V2-scoped by its own text, and absent at the point of action.** `IPhlimboHook.sol` names **PhlimboV2 three times** ("invoked by PhlimboV2", "inside PhlimboV2's `nonReentrant` guard", "The owner of PhlimboV2 is trusted...") and **never mentions V3**. It is inherited by V3 only via import. Meanwhile `PhlimboV3.sol` carries no hook-revert disclosure anywhere, and `setHook`'s own NatSpec ([`:330-333`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV3.sol#L330-L334)) — what an owner actually reads at the moment of the one load-bearing action in this finding — is in full:

```solidity
/**
 * @notice Sets the hook contract invoked after stake/withdraw/claim.
 * @dev Accepts address(0) to disable the hook.
 */
function setHook(address _hook) external onlyOwner {   // :334
```

No warning at all.

**4. The protocol's own conduct contradicts the disclosure's implication.** Three consecutive stories were spent for the express purpose of ensuring a failing reward leg can never freeze principal, and the contract profile asserts INV-01 — "a user's principal is never frozen by a failing reward payout" — HOLDS at `f279c62`. An owner who watched those stories land will reasonably believe principal cannot freeze on a downstream failure. In the hooked configuration it can. The code shape reinforces the belief: the hook is the **last statement** of each function, after all state writes and after the principal transfer, reading as fire-and-forget.

**Net effect:** the disclosure moves this from "undocumented trap" to "**documented mechanism whose safety context changed and whose governing doc was never updated**". That is still a Medium availability hazard. It is not a Low, and it is not a claim that the protocol hid anything.

### "The sponsor tested this behaviour, so it is intended" — foreclosed by git provenance

The sharpest available attack on this finding is that the project's own suite contains three tests named `test_hook_revert_propagates_on_{stake,withdraw,claim}` — i.e. the sponsor knew about the propagation, tested it, and affirmed it as intended design. The provenance of those artifacts answers it, and every claim here is verifiable by `git`:

| Artifact | Provenance | Verified by |
|---|---|---|
| `src/interfaces/IPhlimboHook.sol` | Untouched since **`ac42de6 [story-020] PhlimboV2 with fixed depletion, migrator role, and hook system`** — a **V2** commit | `git log -- src/interfaces/IPhlimboHook.sol` |
| `test_hook_revert_propagates_on_withdraw` | Entered via **`8099db7 [story-022] Phase 1a: verbatim V2 copy as PhlimboV3 + IPhlimboV3, V2 suite ported and green`** — a **verbatim V2 port** | `git log -S` on the test name |
| story-030 (`e32588d`) | Deleted `pauseWithdraw` and touched **no hook file at all** — removed 163 lines of tests across `.gas-snapshot`, `PhlimboV3.sol`, `IPhlimboV3.sol`, `PhlimboV3Test.t.sol`, without revisiting a single hook artifact | `git show --stat e32588d` |

**Every artifact evidencing intent predates the change that made the consequence severe.** The interface docblock is V2-scoped by *provenance*, not merely by the text of its docblock; the tests are a verbatim V2 port carried across unexamined; and the story that changed the remedy structure never revisited either.

What those tests actually affirm is **atomicity**, not survivability. `test/PhlimboV3Test.t.sol:501`'s own assertion message is `"state preserved on revert"` — it checks that a reverting hook cleanly rolls back, which is correct and desirable. **No test or doc anywhere asks the next question: "and now how does the staker get their principal out?"** Until story-030, the answer was `pauseWithdraw`. Nobody re-asked it afterwards.

### Honest scope and limits

These are stated plainly rather than buried, because they genuinely bound the finding:

- **Inert at the shipped config.** `hook` is zero-initialized ([`:102`](https://github.com/Behodler/phlimbo-ea/blob/f279c62/src/PhlimboV3.sol#L100-L102)), no hook contract is deployed, no hook implementation exists in the repo outside test mocks, and every call site is zero-address guarded. `setHook` is `onlyOwner`. **No unprivileged path arms this** (`test_CODE001_G` asserts both facts). If no hook is ever set, this finding never bites. It arms the moment `setHook` receives a non-zero address.
- **This is a non-obvious owner footgun, not an unprivileged exploit.** The owner's knowing act is "attach an observer"; the freeze is emergent, third-party, and time-shifted. The owner is not staged as an attacker anywhere in this report or its PoC — a malicious-owner framing would be out of scope and is not what is claimed.
- **The gate is "a shipped feature is not yet in use", not "this is dead code."** The hook system ships with a setter, a `HookSet` event, a dedicated interface file, and test mocks. It exists to be used; using it is expected operation, not misconfiguration.
- **The propagation itself is not a novel discovery** — see the provenance section above. The novel contributions are **(a)** the empirical no-escape enumeration on V3 and **(b)** the observation that V2-L-09's stated Low rationale no longer applies to V3. Neither is the propagation.
- **The Tier-3 green does not clear this.** `invariant-results` explicitly records "Reverting IPhlimboHook not modelled (no hook set)". INV-PRINCIPAL-LIVE proves principal survives a failing **reward** leg, not a failing **hook**. The 500k Foundry / 1.51M Medusa campaign is **silent** here, not exculpatory.

### Proof of Concept

`PoC_CODE001_HookPrincipalFreeze.t.sol` — **8/8 passing** against `PhlimboV3` at clean HEAD `f279c62`.

```bash
cd workspace/phlimbo-ea && forge test --match-path test/PoC_CODE001_HookPrincipalFreeze.t.sol -vv
```

```
Ran 8 tests for test/PoC_CODE001_HookPrincipalFreeze.t.sol:CODE001PoCTest
[PASS] test_CODE001_A_baseline_noHook_stakeAndWithdrawWork() (gas: 170167)
[PASS] test_CODE001_B_ownerAttachesHealthyHook_nothingLooksWrong() (gas: 297906)
[PASS] test_CODE001_C_hookReverts_freezesPrincipal_exactError() (gas: 285284)
Logs:
  exact revert returndata from withdraw(): 0x24522f34
  RegistryPaused selector: 0x24522f3400000000000000000000000000000000000000000000000000000000

[PASS] test_CODE001_D2_v2_pauseWithdraw_rescuesStaker_v3_hasNoEquivalent() (gas: 2199465)
[PASS] test_CODE001_D_noHookExemptExitExists_onV3() (gas: 743254)
[PASS] test_CODE001_E_setHookZero_fullyRestoresWithdrawals() (gas: 229338)
[PASS] test_CODE001_F_mirrorHookOnLivePool_panicUnderflow_freezesPrincipal() (gas: 443359)
Logs:
  exact revert returndata from withdraw(): 0x4e487b710000000000000000000000000000000000000000000000000000000000000011

[PASS] test_CODE001_G_inertAtShippedConfig_requiresSetHook() (gas: 191049)
Suite result: ok. 8 passed; 0 failed; 0 skipped
```

**Exact revert errors.** The PoC does not use `expectRevert` string matching. It calls `PhlimboV3` via a low-level call and asserts the **returndata byte-for-byte**, so the precise payload propagating out of `withdraw` is proven, not inferred:

- `RegistryPaused()` = **`0x24522f34`**, propagating **unwrapped** out of `PhlimboV3.withdraw` (test C).
- `Panic(0x11)` (arithmetic underflow) = **`0x4e487b71...0011`**, likewise unwrapped (test F).

```solidity
// test C — the exact assertion
(bool ok, bytes memory ret) =
    _rawCall(alice, abi.encodeWithSelector(PhlimboV3.withdraw.selector, STAKE_AMOUNT, alice));

assertFalse(ok, "withdraw reverted");
assertEq(
    ret,
    abi.encodeWithSelector(PointsRegistry.RegistryPaused.selector),
    "EXACT revert: PointsRegistry.RegistryPaused() propagates unwrapped out of PhlimboV3.withdraw"
);
// Principal did not move. The safeTransfer at :774 executed and was then unwound at :781.
assertEq(phUSD.balanceOf(alice), aliceBefore, "alice received nothing");
assertEq(phUSD.balanceOf(address(phlimbo)), poolBefore, "principal still trapped in the pool");
assertEq(_stakedOf(alice), STAKE_AMOUNT, "position intact but inert -- FROZEN");
```

**Both hooks are modelled as things a competent, non-malicious owner would plausibly attach**, not as griefing contracts:

- `PointsObserverHook` — forwards stake/withdraw/claim into a points registry that is pausable **by its own operator, not by the Phlimbo owner**. This models the time-shift: healthy at `setHook` time, reverting 30 days later, with no Phlimbo-owner action at that moment.
- `MirrorAccountingHook` (test F) — mirrors staked balances into its own accounting. It is **correct for every user who stakes after it is attached**, so bob (post-attach) exits fine and the owner's smoke test passes; alice, who pre-dates the hook, has an empty mirror, so `onWithdraw`'s `-=` underflows and her principal freezes. Attaching an observer to a *live* pool is the realistic case, and this is what it costs.

**No escape path — enumerated empirically, not asserted** (`test_CODE001_D_noHookExemptExitExists_onV3`). Every user-callable exit is driven against a live frozen position, with a real accrued reward balance so `claim` has something to do:

| # | Path attempted | Result |
|---|---|---|
| 1 | `withdraw(full)` | reverts `RegistryPaused()` — hook at `:781` |
| 2 | `withdraw(half)` | reverts `RegistryPaused()` — no smaller-amount escape |
| 3 | `claim` | reverts `RegistryPaused()` — hook at `:813`; rewards frozen too |
| 4 | `stake` | reverts `RegistryPaused()` — hook at `:730`; cannot even top up |
| 5 | `claimUnclaimableStable` / `claimUnclaimablePhUSD` / `claimUnclaimablePromo` | hook-**exempt**, but carry only **banked rewards, never principal** — `"Nothing to claim"` |
| 6 | `batchClaim` | permissionless but promo-only and phase-gated — `"Promo phase must be Flushing"` |
| 7 | `pauseWithdraw(uint256)` / `emergencyWithdraw(uint256)` | **selectors absent** from PhlimboV3; no fallback |
| 8 | `emergencyTransfer` | `OwnableUnauthorizedAccount(alice)` — owner-only and terminal; the staker cannot compel it |
| 9 | `pause()` then `withdraw` | `EnforcedPause()` — **pausing closes the last gate rather than opening one.** On V2, pausing *enabled* the pauser-held `pauseWithdraw` remedy; on V3 it merely adds a second gate ahead of the hook |

Net: `assertEq(_stakedOf(alice), STAKE_AMOUNT, "principal FROZEN with no self-service path out")`.

`test_CODE001_D2_v2_pauseWithdraw_rescuesStaker_v3_hasNoEquivalent` runs the **identical** hook failure against both contracts to isolate the remedy-structure delta. Note its scope honestly: the V2 leg requires `vm.prank(pauser); v2.pause();` first — it demonstrates the **pauser-held second remedy**, not a unilateral user escape.

### Tools Used

Foundry (`forge test`), manual review, `git log`/`git show` for artifact provenance, Slither, Aderyn, Semgrep, Medusa/Foundry invariant campaigns (silent on this leg — see "Honest scope"), untruncated full-file grep for the `pauseWithdraw`/`emergencyWithdraw`/`try` claims.

## Recommended mitigation steps

**Wrap the three hook invocations in `try`/`catch`. This is the correct and sufficient fix, full stop.** A hook is an observer; it must not be load-bearing on principal. Story-031 has just established the in-house precedent for exactly this pattern on the phUSD mint leg at `:913`, and stories 027/029 did the same for the stable and promo legs — this applies the identical, already-accepted discipline to the one leg that was missed:

```solidity
// src/PhlimboV3.sol:780-782  (withdraw; apply the same shape at :730 stake and :813 claim)
if (address(hook) != address(0)) {
    try hook.onWithdraw(msg.sender, user, actualWithdrawAmount) {
        // no-op
    } catch {
        emit HookCallFailed(msg.sender, user, actualWithdrawAmount);
    }
}
```

Add the corresponding event so the failure is loud rather than silent (verified absent at `f279c62`):

```solidity
event HookCallFailed(address indexed caller, address indexed user, uint256 amount);
```

**Also forward an explicit gas stipend.** A bare `catch` bounds a *reverting* hook but not a *gas-hungry* one — V2-L-09's own title names both ("Reverting/**gas-heavy** IPhlimboHook bricks stake/withdraw/claim"). Use `try hook.onWithdraw{gas: HOOK_GAS_LIMIT}(...)` so a hook whose gas cost grows over time cannot consume the caller's budget and brick the path by exhaustion rather than by revert.

Together these make INV-01 true as stated, rather than true only under a narrow reading of "reward payout".

### Explicitly NOT recommended: reinstating a `pauseWithdraw`-equivalent

A reader reaching for the symmetrical fix — "restore the hook-exempt exit story-030 deleted" — should not. It is foreclosed here in-band because it is **regression-inducing and ineffective**:

1. **It regresses V3-M-06** (`efdc3c4f`, medium, **fixed** at `e32588d`). V3-M-06 *is* `pauseWithdraw`: it skipped `_updatePhUSDEmissionRate`, inflating phUSD emission by exactly S0/S1 and minting the excess uncapped. Its closureNote reads *"story-030 removed pauseWithdraw entirely; over-emission path eliminated at root."* Reinstating the function reintroduces that Medium verbatim.
2. **Patching around (1) walks into V3-Q-02's retained trap warning** (`93cdca59`). Adding `_updatePool` to the reinstated function is the other leg of a pincer, and V3-Q-02's entry exists *solely* to carry the warning: *"THE OBVIOUS REMEDIATION STRANDS VALUE THE CURRENT CODE PRESERVES... Retained as QA specifically so a future run does not fix this into a worse state."* Omit `_updatePool` ⇒ V3-M-06 regression; add it ⇒ V3-Q-02's trap.
3. **It breaks the staker-set freeze `beginFlush` depends on.** A `whenPaused` exit is callable during Flushing (`beginFlush` calls `_pause()`, and `unpause` reverts while flushing). `beginFlush`'s NatSpec states the design premise directly: *"Pausing blocks all whenNotPaused ops, so from this point every user's amount and the staker set are frozen"* — and `finalizePromotion` requires `flushCursor == _stakers.length()`. A reinstated `pauseWithdraw` would mutate `user.amount`, `totalStaked` and `_stakers` membership mid-flush, against a cursor iterating that set.
4. **It does not even solve this finding.** `pauseWithdraw` is `whenPaused`, so it is unreachable until a privileged party pauses — and that same party could simply call `setHook(address(0))`, which is strictly better (restores everything, preserves rewards, no dust rules). The "alternative" is both hazardous and ineffective for the finding it would be offered against.

If defence-in-depth is wanted, the honest line is the operational guidance below — not resurrecting a removed function.

### Operational guidance until the fix lands

Do **not** call `setHook` with a non-zero address. If a hook must be wired first: (a) treat `setHook` as a protocol-critical change, not an analytics tweak; (b) monitor `withdraw` revert rates continuously — the freeze is silent and arrives with no owner action; (c) pre-authorize an operator to call `setHook(address(0))` as a break-glass, since the freeze's duration is bounded only by owner monitoring latency; (d) prefer a hook with no external dependencies — the PoC's trigger is a dependency registry pausing, not a bug in the hook itself.

**If the hook is intentionally load-bearing on principal**, say so explicitly in `PhlimboV3.setHook`'s NatSpec and reconcile it against INV-01 — because the current code shape (hook last, after all state writes and after the principal transfer, reading as fire-and-forget) asserts the opposite. Separately, `IPhlimboHook.sol`'s docblock should be updated: it names PhlimboV2 exclusively, has not been touched since a V2 commit, and describes a remedy structure that no longer exists on V3.

### Related ledger entries — disclosed, not collapsed

- **V2-L-09** (`08da5bba`, **open**, low, `src/PhlimboV2.sol`) — same mechanism, different contract, different fingerprint. Re-file disclosure per the "disclose when re-filing" discipline: V2-L-09 is open and was **never human-triaged down**, so this is not a silent override of a triaged entry. **Consistency note flagged for triage:** this run's severity-audit (UF-01) holds that since the V2/V3 delta is "two privileged remedies vs one" rather than "escape vs no escape", the hook-freeze class is a Medium on *both* contracts, and recommends **re-weighing V2-L-09 to Medium** rather than treating M-01 as overstated. This matters materially — PhlimboV2 is live on mainnet at `0x6084a02c…2aee0` with real stakers currently being migrated. Resolve via `/ledger phlimbo-ea`; the two entries should end up consistent either way.
- **V3-M-05** (`69f8b29a`, fix-pending) — **the load-bearing severity precedent** (see Impact), and **a sibling, not an `incompleteFixOf`**. M-05's root cause is a reverting reward transfer *inside* `_claimRewards`; the hook leg is *outside* `_claimRewards` and was never in M-05's scope. Closing M-05 is correct on its own terms.
- **V3-M-07** (`27e83ab2`) — **not used as a precedent**; its "external trigger" premise was refuted this run (see Impact).
- **V3-M-06** (`efdc3c4f`, fixed) — this finding does **not** discharge V3-M-06's verification obligation (a), and no such claim is made. That obligation is scoped to the `beginFlush` pause window, which is hook-independent; M-01 concerns a hooked configuration and has nothing to say about it. The severity-audit separately examined that window and **refuted** the hazard: stakers are indeed frozen during a flush, but that freeze is intended, documented in `beginFlush`'s NatSpec, and load-bearing for the flush cursor's soundness. V3-M-06's `fixed` status stands.
- **Closure caveat (important):** the run-11 propose-fixed on V3-M-05 must **not** be recorded as establishing "principal can never freeze in PhlimboV3." This finding is the standing counterexample. That closure is correct for its own stated scope — the reward legs — but does not reach the hook leg.
