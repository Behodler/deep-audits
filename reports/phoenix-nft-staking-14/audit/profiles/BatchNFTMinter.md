# Contract Profile: BatchNFTMinter

- **Contract:** `src/BatchNFTMinter.sol`
- **Project:** phoenix-nft-staking
- **Commit:** `9be4a87a62e5ed1d25a013c4f8a033eaa41de2f6`
- **Solidity:** `^0.8.20` (checked arithmetic)
- **Inheritance:** `Ownable`, `Pausable`, `IPausable`
- **Libraries:** `SafeERC20` for `IERC20`
- **Profile scope:** local single-contract analysis. Related contracts (`NFTStaker.sol`, `INFTSupply.sol`) read only for trust-boundary context; not analyzed. `NFTStaker` does not call `BatchNFTMinter` — they are independent units that share the same `tokenMinter` / `dispatcherIndex` external dependency.
- **Regression context:** story-015 added a `minReward` 4th param to `batchMint()` and error `BatchMint__RewardBelowMinimum(uint256,uint256)`, mitigating M-01 (MEV first-claimer front-run of the winner-take-all nudge pot).

---

## 1. Purpose

Stateless-looper helper that calls `ITokenMinterV2.mint(index, recipient)` `count` times in one tx, pulling the aggregate payment once upfront, refunding dust afterward. Layered on top is an **owner-administered "nudge" incentive**: when a batch is large enough (`count >= nudgeSize`) the contract pays out its **entire balance of a separate `nudgePaymentToken`** to the `recipient`. The contract is externally funded (e.g. a yield funnel directing USDC in).

---

## 2. Public / External Functions

| Function | Visibility | Access control | Pausable | State mutated | External calls |
|---|---|---|---|---|---|
| `constructor(address initialOwner)` | — | sets owner | — | owner | none |
| `setTokenMinter(ITokenMinterV2)` | external | `onlyOwner` | callable while paused | `tokenMinter` | none |
| `setDispatcherIndex(uint256)` | external | `onlyOwner` | callable while paused | `dispatcherIndex` | none |
| `setNudgeSize(uint256)` | external | `onlyOwner` | callable while paused | `nudgeSize` | none |
| `setNudgePaymentToken(address)` | external | `onlyOwner` | callable while paused | `nudgePaymentToken` | none |
| `setPauser(address)` | external | `onlyOwner` | callable while paused | `pauser` | none |
| `pause()` | external (override) | `onlyPauser` | — | `_paused` | none |
| `unpause()` | external (override) | `onlyPauser` | — | `_paused` | none |
| `rescueERC20(IERC20,address,uint256)` | external | `onlyOwner` | callable while paused | none (moves tokens) | `token.safeTransfer` |
| `batchMint(uint256 count, address recipient, uint256 paymentAmount, uint256 minReward)` | external | **none** (permissionless) | `whenNotPaused` | none (storage); moves tokens | see flow below |

Notes:
- `pause`/`unpause` are gated on `pauser`, **not** owner — owner can only rotate the pauser address. If `pauser == address(0)` pausing is impossible (`onlyPauser` reverts on `msg.sender == address(0)` being unreachable from EOAs).
- `rescueERC20` has no token restriction by design (owner is already trusted via nudge setters); only a zero-`to` guard.
- `batchMint` is the only permissionless entry point and the only state-flow of interest.

---

## 3. State Variables & Invariants

| Variable | Type | Mutators | Readers | Notes |
|---|---|---|---|---|
| `DUST_THRESHOLD` | `uint256` constant = `1e6` | — | `batchMint` | refund floor |
| `tokenMinter` | `ITokenMinterV2` (public) | `setTokenMinter` | `batchMint` | `address(0)` disables batchMint |
| `dispatcherIndex` | `uint256` (public) | `setDispatcherIndex` | `batchMint` | `0` disables (V2 `nextIndex` starts at 1) |
| `nudgeSize` | `uint256` (public) | `setNudgeSize` | `batchMint` | `0` disables nudge |
| `nudgePaymentToken` | `address` (public) | `setNudgePaymentToken` | `batchMint` | `address(0)` disables nudge |
| `pauser` | `address` (public) | `setPauser` | `onlyPauser` | `address(0)` disables pausing |
| `_paused` (OZ Pausable) | `bool` | `pause/unpause` | `whenNotPaused` | gates only `batchMint` |

**Design/config invariants:**
- The contract holds **no per-user accounting state** — it is a pass-through looper plus an externally-funded pot. All "balance" is the live ERC20 `balanceOf(this)` of the payment token and the nudge token.
- Config invariant (enforced per-call, up-front, in `batchMint`): if `nudgePaymentToken != 0` it MUST differ from the derived `paymentToken` (dispatcher's `primeToken()`), else `BatchMint__NudgeTokenMatchesPaymentToken`. Since the payment token is now derived (not caller-supplied), this is effectively a deploy-time config invariant.
- Nudge payout is **winner-take-all on full balance** — there is no per-caller share; `nudgeAmount = balanceOf(nudgeToken, this)`.

---

## 4. `batchMint` Flow (detailed)

Ordering, line by line (L227–294):

1. **Param guards** (L233–234): `count == 0` → `BatchMint__ZeroCount`; `recipient == 0` → `BatchMint__ZeroRecipient`.
2. **Minter resolution** (L236–239): load `tokenMinter` into local `nftMinter`; `address(0)` → `BatchMint__MinterNotConfigured`.
3. **Dispatcher resolution** (L241–245): load `dispatcherIndex`; `0` → `BatchMint__DispatcherNotConfigured`. **External staticcall** `INFTMinterV2(nftMinter).configs(idx)` to fetch `dispatcher`; zero dispatcher → `BatchMint__DispatcherNotConfigured`.
4. **Payment token derivation** (L247): **External staticcall** `ITokenDispatcherV2(dispatcher).primeToken()` → `paymentToken`. Caller cannot supply a wrong/zero asset.
5. **Nudge/payment collision guard** (L249–252): if `nudgePaymentToken` set and `== paymentToken` → revert **before any funds move**.
6. **Pull payment** (L254): `paymentToken.safeTransferFrom(msg.sender, this, paymentAmount)`. **External call #1 (value-in).**
7. **Approve minter** (L255): `paymentToken.forceApprove(nftMinter, type(uint256).max)`. **External call.**
8. **Mint loop** (L257–259): `for i in 0..count: nftMinter.mint(dispatcherIndex, recipient)`. **`count` external calls.** Each pulls the dispatcher's ramping price from this contract's approved balance. If `paymentAmount` is short, an inner `mint` reverts → whole batch rolls back.
9. **Revoke approval** (L261): `paymentToken.forceApprove(nftMinter, 0)`. **External call.**
10. **Nudge computation** (L268–272): `nudgeAmount = 0` unless `nudgeSize != 0 && count >= nudgeSize && nudgePaymentToken != 0`, in which case `nudgeAmount = IERC20(nudgeToken).balanceOf(this)` (**external staticcall**, full balance).
11. **minReward slippage floor** (L278–280, story-015): `if (nudgeAmount < minReward) revert BatchMint__RewardBelowMinimum(minReward, nudgeAmount)`. This reverts the entire batch (mints + payment pull roll back). `minReward == 0` never trips.
12. **Nudge payout** (L282–285): if `nudgeAmount != 0`: `IERC20(nudgeToken).safeTransfer(recipient, nudgeAmount)` + `NudgePaid` event. **External call (value-out to recipient-controlled token transfer).**
13. **Dust refund** (L287–293): `remaining = paymentToken.balanceOf(this)` (**external staticcall**); if `remaining / DUST_THRESHOLD != 0` (i.e. `remaining >= 1e6`): `safeTransfer(msg.sender, remaining)` (**external call**) and `totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0`. Else `totalPaid = paymentAmount`, sub-threshold residue stays in contract.

### Nudge-pot + minReward semantics (key)
- The reward is the **full nudge-token balance at the moment of computation**, not a per-mint or per-caller amount. Whoever first submits a qualifying batch takes the entire pot.
- `minReward` is a **loser-protection** floor, not a winner guarantee. Quoting the contract's own NatSpec (L221–224): it "does NOT stop a front-runner from winning the pot — whoever qualifies first still takes the entire balance-based payout; the floor only stops the loser from minting for less than they declared." So M-01's economic root cause (winner-take-all on a public numeric gate) is **mitigated for the front-run victim's cost exposure**, not eliminated as an MEV race.
- Because `nudgeAmount` is read fresh at step 10 (after the mint loop), and the floor check at step 11 precedes the payout and refund, a caller setting `minReward > 0` will atomically revert (paying nothing, minting nothing) if the pot was drained by an earlier tx in the same block.

---

## 5. External Calls & Reentrancy Surface

Ordered external calls within `batchMint`:

1. `configs(idx)` — staticcall, trusted minter (view)
2. `primeToken()` — staticcall, trusted dispatcher (view)
3. `paymentToken.safeTransferFrom(msg.sender, this, paymentAmount)` — payment token transfer
4. `paymentToken.forceApprove(minter, max)` — approve
5. `nftMinter.mint(...)` × `count` — **trusted minter, but each mint internally moves the dispatcher's prime token** (the dispatcher may be arbitrary contract logic behind the trusted minter facade)
6. `paymentToken.forceApprove(minter, 0)` — approve
7. `nudgeToken.balanceOf(this)` — staticcall
8. `nudgeToken.safeTransfer(recipient, nudgeAmount)` — **value-out**
9. `paymentToken.balanceOf(this)` — staticcall
10. `paymentToken.safeTransfer(msg.sender, remaining)` — **value-out**

**Reentrancy posture (local observation, exploitability deferred to interaction analysis):**
- There is **no `ReentrancyGuard`** on this contract (unlike sibling `NFTStaker`). `batchMint` is `whenNotPaused` only.
- The contract holds **no mutable accounting storage**, so a classic checks-effects-interactions reentrancy on internal balances is structurally limited — every "balance" decision is a fresh `balanceOf` read. There is no state to corrupt by re-entering.
- However, the nudge payout and the dust refund are **balanceOf-driven, not amount-tracked**. The relevant local property to hand downstream: *if any external call in the chain (a hostile payment token, a hostile dispatcher inside `mint`, or a hostile nudge token / ERC-1155 recipient hook) can re-enter `batchMint`, the re-entrant call reads the live `balanceOf` afresh.* Two ordering facts matter for the interaction agent:
  - The nudge `balanceOf` (step 7) is read **after** the mint loop and the floor check is computed against it; a re-entrant qualifying batch that runs *before* the outer payout could read the same full pot, but the **first** transfer (step 8) zeroes it for whoever runs second (second caller's `nudgeAmount` becomes 0 → reverts if their `minReward>0`, or pays 0). No double-spend of the pot results from a single funding because the second `balanceOf` reflects the first transfer.
  - The dust refund uses `balanceOf(this)` (step 9) at the very end; a re-entrant call that deposits/withdraws payment token mid-flow changes what gets swept, but the contract claims sub-threshold residue is intentionally left and griefer pre-deposits "donate to the next caller."
- **`tokenMinter` and `dispatcher` are owner-pinned and treated as trusted** (the whole story-009→drain-vector narrative is about removing the caller-supplied-minter drain). Reentrancy through `mint()` therefore depends on the trustworthiness of the owner-configured minter/dispatcher — a cross-contract concern (deferred). The `recipient` and the two ERC20 tokens are the untrusted-edge actors for callback purposes; standard ERC20 `transfer`/`transferFrom`/`balanceOf` do not hand control to `recipient`, so under the project's standard-ERC20 trust assumption no recipient callback exists. A non-standard token with transfer hooks (ERC-777-style) would open a callback — out of scope per project known-invalid list unless explicitly in scope.

---

## 6. Verified Local Properties

| Property | Status | Notes |
|---|---|---|
| `checkedArithmetic` | verified | `^0.8.20`, no `unchecked` blocks, no assembly. `paymentAmount - remaining` guarded by ternary; `++i` in checked context. |
| `noUnboundedLoops` | **violated (local)** | mint loop bound is `count`, a caller-supplied `uint256` with no max. See LOCAL-001. |
| `accessControlled` (admin setters) | verified | all setters `onlyOwner`; `pause/unpause` `onlyPauser`; `rescueERC20` `onlyOwner` + zero-`to` guard. |
| `reentrancyGuarded` | **none** | no `ReentrancyGuard`; mitigated by stateless (balanceOf-driven) design, not by a guard. See §5. |
| `initializerProtected` | n/a | not upgradeable; constructor-only init. |
| `pauseMechanism` | verified | OZ `Pausable`; only `batchMint` gated; admin + rescue stay live (intentional). |
| `uninitializedStorage` | verified | all config defaults to disabled sentinels (`0` / `address(0)`); `batchMint` reverts cleanly when unconfigured. |
| `precisionLoss / rounding` | verified-benign | only arithmetic is `remaining / DUST_THRESHOLD != 0` (a `>= 1e6` test) and `paymentAmount - remaining`; no fee/share math. |
| `eventsOnStateChange` | verified | every setter + nudge payout + rescue emits; mint loop itself emits via the minter, not here. |

---

## 7. Local Findings

### LOCAL-001 — Unbounded mint loop (caller-controlled `count`)
- **Type:** unbounded-loop / gas-griefing (self-inflicted DoS)
- **Severity (local):** local-low
- **Function:** `batchMint`, L257–259
- **Description:** `for (i; i < count; ++i) nftMinter.mint(...)` loops `count` times where `count` is an unbounded caller argument. A large `count` runs out of gas; each iteration also makes an external `mint` call. This is self-griefing (the caller pays gas and funds the mints), not a vector against other users or the pot — but it caps batch size at the block gas limit / dispatcher per-mint cost, and there is no explicit max-iteration guard or pagination.
- **Recommendation:** if a deterministic ceiling is desired, add a `maxBatch` config knob; otherwise document the gas-bound expectation. Low priority given economic self-cost.

### LOCAL-002 — No reentrancy guard on the only value-moving entry point (informational, for interaction agent)
- **Type:** reentrancy-surface
- **Severity (local):** local-info (exploitability deferred — cross-contract)
- **Function:** `batchMint`
- **Description:** `batchMint` makes 8+ external calls (incl. `count` minter calls and two value-out `safeTransfer`s) with no `nonReentrant`. The contract is stateless (all decisions via fresh `balanceOf`), which structurally blunts classic reentrancy, but the nudge payout and dust refund are balance-driven. Whether a callback exists at all depends on the trustworthiness of the owner-pinned minter/dispatcher and on token standard-ness (ERC-777-style hooks). Flagging for the interaction agent to confirm no `mint()` callback path re-enters before the nudge `balanceOf`/transfer pair.
- **Recommendation:** consider adding OZ `ReentrancyGuard` to `batchMint` as defense-in-depth (sibling `NFTStaker` already uses it). Cheap, removes the entire class from reasoning.

### LOCAL-003 — `minReward` does not prevent the MEV race it targets, only the loser's wasted spend (spec/observation)
- **Type:** spec-deviation / mitigation-scope
- **Severity (local):** local-low (informational, self-documented)
- **Function:** `batchMint`, L268–280
- **Description:** story-015's `minReward` (M-01 mitigation) is a slippage floor: it reverts the loser's batch so they don't pay mint costs for a sniped reward. It does **not** make the pot non-winner-take-all and does not stop a front-runner from winning. The contract's own NatSpec (L221–224) states this explicitly, so it is a documented scope limit rather than a hidden gap. Confirm downstream (econ-scanner) that "loser doesn't overpay" is the intended and sufficient M-01 remediation, given the pot remains a public `count >= nudgeSize` race. A caller who leaves `minReward == 0` (the default / backward-compatible value) gets **no protection at all** — they will mint and pay even if the pot is empty.
- **Recommendation:** ensure off-chain callers default `minReward` to the expected pot size, not `0`; consider documenting that `minReward == 0` opts out of the M-01 fix.

---

## 8. Trust Assumptions

1. `tokenMinter` (and the `dispatcher` resolved via `configs(dispatcherIndex)`) are **owner-configured and trusted**. The contract's security narrative explicitly hinges on the minter being pinned state, not a call parameter — this closes the story-009 caller-supplied-minter drain of the nudge pot.
2. `paymentToken` is the dispatcher's `primeToken()` and is assumed a standard ERC20 (no fee-on-transfer, no rebasing). Fee-on-transfer would break the `paymentAmount` budget math and the dust-sweep accounting (project known-invalid except USDT).
3. `nudgePaymentToken` is a standard ERC20 distinct from `paymentToken` (enforced per-call). The pot is externally funded; the contract trusts whoever funds it.
4. Owner is trusted: `rescueERC20` can move any token (including the nudge pot) out at will; nudge knobs can be flipped at any time, including while paused (centralization acknowledged).
5. `pauser` is trusted to pause/unpause; owner can rotate it. `pauser == 0` makes the contract unpausable.
6. Standard-ERC20 / no-token-callback assumption is what keeps `recipient` from gaining reentrant control during the nudge/refund transfers.

---

## 9. Interface Abstraction (for downstream agents)

**External entry points:**
- `batchMint(uint256 count, address recipient, uint256 paymentAmount, uint256 minReward) -> uint256 totalPaid`
  - access: none (permissionless); gate: `whenNotPaused`
  - reads config: `tokenMinter`, `dispatcherIndex`, `nudgeSize`, `nudgePaymentToken`
  - external calls (in order): `minter.configs`, `dispatcher.primeToken`, `paymentToken.transferFrom(caller→this)`, `paymentToken.approve(minter,max)`, `minter.mint × count`, `paymentToken.approve(minter,0)`, `nudgeToken.balanceOf`, `nudgeToken.transfer(recipient)`, `paymentToken.balanceOf`, `paymentToken.transfer(caller)`
  - value flow: pulls `paymentAmount` of derived token from caller; pays full `nudgeToken` balance to `recipient` if `count >= nudgeSize`; refunds payment-token surplus `>= 1e6` to caller
  - reentrancy guard: NONE
- Admin (all `onlyOwner`, callable while paused): `setTokenMinter`, `setDispatcherIndex`, `setNudgeSize`, `setNudgePaymentToken`, `setPauser`, `rescueERC20(token,to,amount)`
- Pause (`onlyPauser`): `pause`, `unpause`

**External dependencies (trust boundaries):**
- `ITokenMinterV2 tokenMinter` — methods `configs` (via INFTMinterV2 cast), `mint(index,recipient)`. trust: trusted (owner-pinned).
- `ITokenDispatcherV2 dispatcher` (resolved at runtime) — method `primeToken()`. trust: trusted (owner-pinned via minter config).
- `IERC20 paymentToken` (= dispatcher.primeToken) — `transferFrom`, `forceApprove`, `transfer`, `balanceOf`. trust: semi-trusted standard ERC20.
- `IERC20 nudgePaymentToken` — `balanceOf`, `transfer`. trust: semi-trusted standard ERC20, externally funded.
- `address recipient` — receives mints and nudge payout; no direct callback under standard-ERC20 assumption. trust: untrusted.

**Events:** `NudgeSizeChanged`, `NudgePaymentTokenChanged`, `NudgePaid`, `TokenMinterSet`, `DispatcherIndexSet`, `Rescued`, `PauserChanged`.
**Modifiers:** `onlyOwner`, `onlyPauser`, `whenNotPaused`.

---

## 10. Complexity

| Metric | Value |
|---|---|
| LOC | 295 |
| external/public functions | 10 (+ constructor) |
| permissionless entry points | 1 (`batchMint`) |
| external calls in hot path | up to `count + 9` |
| state variables (mutable config) | 5 (+ OZ `_paused`, `_owner`) |
| custom errors | 7 |
| assembly blocks | 0 |
| unchecked blocks | 0 |
