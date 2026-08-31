# QA Report for stable-staker

**Run**: stable-staker-01
**Commit**: f524cc361ac6c5dbba12ca69f3559c61a7997022
**Scope**: `src/StableStaker.sol`, `src/StableStakerMigrator.sol`

## Summary

| Severity | Count |
|----------|-------|
| Centralization | 1 |
| Low Risk | 2 |
| Informational | 2 |
| **Total** | **5** |

| ID | Title |
|----|-------|
| C-01 | `rescueERC20` can sweep the buffer backing underwater withdrawals |
| L-01 | Unbounded per-user external-call loop in `migrateOut` / `migrate` |
| L-02 | Unused return value of `EnumerableSet.add` / `remove` |
| I-01 | Underwater buffer pays at par first-come-first-served (by design) |
| I-02 | Break-even deposit→withdraw round-trip can grief the underwater buffer |

An automated SAST/gas baseline produced by **4naly3er** is attached as an appendix at the end of this document.

---

## Centralization Risks

### [C-01] `rescueERC20` can sweep the buffer backing underwater withdrawals <!-- id: ss1c1 -->

**Severity**: Centralization

**Location**: [`src/StableStaker.sol#L521-L528`](../../../lib/stable-staker/src/StableStaker.sol#L521-L528)

**Description**: `rescueERC20` is guarded so the owner cannot sweep accounted user principal: it computes a `reserved` amount and requires `bal >= reserved + amount`. However, the reserve is only non-zero when **no** strategy is set:

```solidity
function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
    require(to != address(0), "StableStaker: zero recipient");
    uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0; // L523
    uint256 bal = IERC20(token).balanceOf(address(this));
    require(bal >= reserved + amount, "StableStaker: would touch user principal");
    IERC20(token).safeTransfer(to, amount);
    emit ERC20Rescued(token, to, amount);
}
```

When a yield strategy is set, principal lives inside the strategy and `reserved` collapses to `0`, so the owner may sweep the **entire on-contract balance**. That balance is exactly the protocol-owned buffer that backs at-par underwater withdrawals via `_routeExit`'s buffer branch (see M-02). Sweeping it does not steal accounted user principal (the swept funds are protocol-owned), but it removes the backstop that lets pending underwater withdrawals settle at par.

**Impact**: A trusted owner can drain the buffer that backstops withdrawals while the strategy is underwater, flipping in-flight at-par buffer withdrawals (`_routeExit` buffer branch, `src/StableStaker.sol:498`) to revert (`StableStaker: strategy underwater`). This degrades availability of the only at-par exit path during the precise window users most need it. Owner-only; no theft of user principal.

**Recommendation**: When a strategy is set, reserve the buffer that backs at-par exits from rescue rather than reserving `0`, e.g. compute a non-zero reserve from the strategy's reported shortfall (`max(0, principalOf - totalBalanceOf)`) so the buffer cannot be swept while underwater. Alternatively, explicitly document the on-contract balance as discretionary protocol funds that are not guaranteed to back underwater withdrawals.

---

## Low Risk Findings

### [L-01] Unbounded per-user external-call loop in `migrateOut` / `migrate` <!-- id: ss1l1 -->

**Severity**: Low

**Location**: [`src/StableStaker.sol#L327`](../../../lib/stable-staker/src/StableStaker.sol#L327) (within `migrateOut`, `L301-L337`); [`src/StableStakerMigrator.sol#L60`](../../../lib/stable-staker/src/StableStakerMigrator.sol#L60) (within `migrate`, `L45-L65`)

**Description**: Both migration paths iterate over an operator-supplied `users[]` batch and perform an external call per user with no bound on batch size:

- `StableStaker.migrateOut` mints rewards per user (`phUSD.mint` reached via `_settle`) and removes each user from the staker set inside the loop (`src/StableStaker.sol:327`).
- `StableStakerMigrator.migrate` calls `newStaker.depositFor(...)` per user inside the loop (`src/StableStakerMigrator.sol:60`).

An oversized `users[]` array can push the transaction past the block gas limit, causing that batch to revert and become un-processable as a single call.

**Impact**: Denial of service confined to a single oversized batch. The caller is permissioned (`onlyMigrator` / `onlyOwner`), and the condition is fully recoverable: the operator re-batches into smaller slices, paging the staker set via `getStakers` / `getStakersRange` / `stakerCount`. No funds at risk and no state corruption.

**Recommendation**: Enforce or document a maximum batch size and rely on the existing pagination (`getStakersRange`) to process large staker sets across multiple transactions.

---

### [L-02] Unused return value of `EnumerableSet.add` / `remove` <!-- id: ss1l2 -->

**Severity**: Low (QA / Info)

**Location**: [`src/StableStaker.sol`](../../../lib/stable-staker/src/StableStaker.sol) — `add` at `L233`, `L361`; `remove` at `L250`, `L287`, `L323`

**Description**: `StableStaker` ignores the boolean success value returned by `EnumerableSet.AddressSet.add` (lines 233, 361) and `EnumerableSet.AddressSet.remove` (lines 250, 287, 323). The return signals whether membership actually changed.

**Impact**: Benign in context. `EnumerableSet` membership operations are idempotent — adding an existing member or removing an absent member is a no-op that leaves the set in the intended state — and the surrounding logic does not depend on the membership-delta. This is a code-quality observation only; no security impact.

**Recommendation**: Optionally check the return value where a membership-delta is semantically meaningful (or document that the idempotent behaviour is intentional). No change is required given the idempotency.

---

## Informational / Design Notes

### [I-01] Underwater buffer pays at par first-come-first-served (intended design) <!-- id: ss1i1 -->

**Severity**: Informational (intended design)

**Location**: [`src/StableStaker.sol#L494-L502`](../../../lib/stable-staker/src/StableStaker.sol#L494-L502) (the `_routeExit` underwater buffer branch)

**Description**: While a token's strategy is below par (`_isUnderwater`), `withdraw` satisfies exits from the shared, protocol-owned on-contract buffer **at par** on a first-come-first-served basis until the buffer is exhausted, after which it reverts (`StableStaker: strategy underwater`) and remaining stakers fall back to `emergencyWithdraw` (their own strategy haircut) or wait for recovery. Two stakers with identical positions can therefore receive different payouts based solely on withdraw ordering.

This was originally raised as a Medium (M-02). After review it is **classified as intended design** and is recorded here as an informational note rather than a finding:

- The behaviour is a deliberate code path (it has a dedicated `BufferWithdrawn` event) implementing the documented invariant that *a non-migrating user cannot be forced to realise a loss*. Paying routine, daily-volume withdrawals at par from idle protocol surplus during a **transient, mean-reverting** underwater dip is the design goal — it avoids sparking panic and avoids forcing users to redeem shares at the bottom (which would disproportionately hurt the protocol and remaining stakers when the strategy recovers). Bank-run / mass-exit is a separate scenario handled by `migrateOut` with pro-rata distribution (`guardUnderwater=false`).
- There is **no incremental victim**: a slow staker's payout is identical to a no-buffer world (their own strategy haircut either way). The buffer only makes an early withdrawer exit at par; the "leaked" asset is protocol-owned surplus the protocol deliberately spends this way.
- The FCFS property is inherent to any finite par-payment buffer. The candidate mitigations (block the buffer branch, or apply a pro-rata haircut to buffer payouts) would **defeat** the stated design goal by forcing reverts or forced loss-realisation on routine withdrawals.

**Recommendation**: No code change required. Optionally document the buffer's FCFS-at-par semantics so integrators understand that during an underwater window the at-par exit path is best-effort and finite. (See also C-01, which recommends the buffer not be sweepable by `rescueERC20` while underwater so the backstop the design relies on cannot be removed out from under in-flight withdrawals.)

---

### [I-02] Break-even deposit→withdraw round-trip can grief the underwater buffer <!-- id: ss1i2 -->

**Severity**: Informational (griefing only — no profit)

**Location**: [`src/StableStaker.sol#L472-L477`](../../../lib/stable-staker/src/StableStaker.sol#L472-L477) (`_routeDeposit`) and [`#L494-L502`](../../../lib/stable-staker/src/StableStaker.sol#L494-L502) (`_routeExit` buffer branch)

**Description**: While underwater, a non-staker can `stake` and then `withdraw` the same amount within one block. The deposit routes straight into the below-par strategy (crediting `user.amount` 1:1), while the withdrawal is paid **at par from the separate on-contract buffer** (redeeming zero strategy shares). The actor puts `a` into the strategy and pulls `a` out of the buffer.

**Impact**: **Break-even for the actor — there is no profitable extraction.** The round-trip nets to zero for the caller (in `a`, out `a`, 1:1 credit, no underwater discount on deposit), so there is no economic incentive to do it. Its only effect is a **liquidity-composition shift**: the protocol's liquid buffer (`−a`) is swapped for an orphaned, unclaimed strategy contribution (`~a`) which recovers to par as the (transient, by-design) dip mean-reverts — netting ≈0 for the protocol. The sole adversarial framing is **griefing**: an actor pays gas to temporarily consume the buffer and deny the at-par reprieve to genuine stakers, until the buffer refills or the strategy recovers. No funds are stolen and no party profits, so this does not rise to a standalone Low/Medium; it is recorded for completeness. It was investigated as a potential separate value-extraction finding and **rejected** because no profit mechanism exists.

**Recommendation**: No change required for the break-even round-trip itself. If griefing of the at-par buffer is a concern, the C-01 / I-01 mitigations (reserve the buffer against rescue while underwater; document the buffer as best-effort) bound the exposure; a same-block stake-then-withdraw guard would also remove the griefing vector but is unnecessary given the absence of profit.

---

## Appendix: Automated Tool Output (4naly3er)

The following section is the **unmodified, automated** output of [4naly3er](https://github.com/Picodes/4naly3er), a static SAST/gas analyzer, run over the in-scope contracts. It is included as a baseline and is **not** hand-verified. Items here may overlap with, or be subsumed by, the manually triaged findings above (e.g. 4naly3er `L-5` overlaps the manual L-01 unbounded-loop finding, `L-11` / `M-2` overlap the manual C-01 rescue/centralization finding). Treat the manual findings above as authoritative; the automated output is informational.

> **Tool**: 4naly3er
> **Invocation**: `yarn analyze lib/stable-staker/src`
> **Compiler**: `solc-0.8.26` (added to the 4naly3er toolchain so the OpenZeppelin v5.6.1 `^0.8.24` imports compile; the project itself pins `solc 0.8.28`). The bundled `solc-0.8.23` default could not satisfy the OZ pragma — see "Tooling note" below.
> **Full report**: [`4naly3er-report.md`](./4naly3er-report.md)

**Tooling note**: On first run, 4naly3er failed to build the AST because its bundled compilers stop at `solc-0.8.23`, below the `^0.8.24` floor required by the project's OpenZeppelin v5.6.1 `EnumerableSet` import. Adding `solc-0.8.26` to 4naly3er's own dependency set (the tool under `tools/`, never the read-only source repo) resolved the version mismatch and the analysis completed cleanly. The complete markdown report is saved alongside this file as `4naly3er-report.md`; its summary tables are reproduced below for convenience.

### 4naly3er summary

**Gas Optimizations** (13 categories): `a += b` vs `a = a + b` (8), assembly `address(0)` checks (11), cache array length (3), `unchecked` for non-overflowing ops (55), custom errors vs revert strings (19), avoid contract-existence checks (7), single-use stack cache (1), `immutable` constructor-only state (3), `payable` admin functions (8), `++i` vs `i++` (5), `private` constants (2), unchecked loop increments (4), `!= 0` vs `> 0` (14).

**Non-Critical** (19 categories): missing `address(0)` checks, style-guide ordering, two-step procedures, `renounceOwnership`, duplicated `require` checks, events missing old/new values, function ordering / length, setter checks, incomplete NatSpec, modifier-vs-require for actors, named mappings, renounce-while-paused, redundant `return`, layout ordering, number-literal underscores, unindexed event fields, zero-initialised variables.

**Low** (11 categories): two-step ownership transfer (3), zero-value transfer reverts (5), missing `address(0)` check (1), division by zero (2), **external calls in unbounded for-loop / DoS (1)** — overlaps manual L-01, renounce-while-paused (1), rounding (2), precision loss (12), `PUSH0` on 0.8.20+ (2), `Ownable2Step` (2), **sweep accounting with multi-address tokens (1)** — relates to manual C-01.

**Medium** (2 categories): fee-on-transfer accounting (1) — note fee-on-transfer tokens are a known-invalid class per the audit ruleset; **centralization risk for trusted owners (11)** — the broad automated centralization sweep, of which the specific buffer-sweep concern is captured as manual C-01.
