# Pattern-Matcher Report — stable-staker

- **Project:** stable-staker
- **Scan timestamp:** 2026-06-01
- **Scan type:** pattern-matching (historical vulnerability pattern DB)
- **Pattern DB:** `patterns/vulnerability-patterns.json` (v1.0, 22 patterns)
- **In scope:**
  - `src/StableStaker.sol` (MasterChef-style multi-token stable yield farm, on-demand phUSD mint, per-token IYieldStrategy routing)
  - `src/StableStakerMigrator.sol` (permissioned batch migration)
- **Patterns checked:** 22
- **Candidate findings (medium+ confidence):** 5

> Note: this agent reports *candidate pattern matches* for downstream LLM scanners (code-scanner / econ-scanner) to confirm or kill. Confidence reflects signature + condition match strength, not exploitability. The protocol's documented core invariant (no window mints more than `phUSDPerDay`) and several deliberate design choices (idle-buffer underwater path, protocol-owned yield) blunt some classic MasterChef matches — those are flagged as LOW / informational, not promoted.

---

## Ranked candidate matches

### 1. DOS-UNBOUNDED-LOOP — `StableStaker.migrateOut` / `StableStakerMigrator.migrate` — MEDIUM
- **Where:** `StableStaker.sol:312` (`for (uint256 i = 0; i < users.length; i++)` in `migrateOut`); `StableStakerMigrator.sol:49` and `:60` (two loops over `amounts` / `users`).
- **Signature match:** `for (uint256 i = 0; i < ...length` — direct hit.
- **Conditions met:** loop body does a `phUSD.mint` per user and the migrator loop does a `depositFor` (external call + `_updatePool` + `_settle`, itself a mint) per user. The batch is operator-supplied (`users[]`), and `getStakers` returns the full unbounded staker set. A batch sized to the full staker set on a popular pool can exceed the block gas limit and brick a migration batch.
- **Mitigations present (partial):** `getStakersRange(start, end)` paging exists and the docstring instructs building batches off-chain — so this is operator-controllable, not user-triggerable. That caps severity (permissioned caller, recoverable by re-batching).
- **Rationale:** Unbounded per-user external-call loop in a permissioned batch path; DoS only if operator over-sizes a batch — confirm gas envelope and whether a partially-failing batch corrupts cross-staker accounting.
- **Confidence:** medium.

### 2. RETURN-VALUE-IGNORE / external-call-trust (IYieldStrategy) — `StableStaker._routeExit` / `_routeDeposit` — MEDIUM
- **Where:** `_routeDeposit` `StableStaker.sol:472-477`, `_routeExit` `:488-507`, `setYieldStrategy` sweep `:196-199`.
- **Signature match:** strategy `.deposit(...)` / `.withdraw(...)` external calls whose effects are trusted via balance-delta, plus `strategy.totalBalanceOf` / `principalOf` reads driving the underwater guard.
- **Conditions met:** principal accounting is decremented by the *requested* amount while the user is paid the *measured received* (balance delta). A misbehaving / lossy / lying strategy (totalBalanceOf vs principalOf semantics are explicitly "ambiguous/deprecated" in `IYieldStrategy.balanceOf`) can drift contract-internal `totalStaked` away from redeemable principal. The underwater guard (`_isUnderwater`) is the only protection and is bypassed on `emergencyWithdraw` and `migrateOut` (both pass `guardUnderwater=false` by design).
- **Mitigations present:** balance-delta measurement (not trusting return value), `forceApprove`, documented protocol-owned-yield model, underwater block on the normal `withdraw` path.
- **Rationale:** Cross-trust on an external strategy adapter whose `principalOf`/`totalBalanceOf` are the sole accounting oracle; accounting-drift / loss-attribution edge cases (especially the buffer-satisfies-withdraw branch at `:498`) warrant econ-scanner review.
- **Confidence:** medium.

### 3. REENTRANCY-ERC777 / strategy-callback reentrancy — `StableStaker` principal paths — MEDIUM→LOW
- **Where:** `stake` `:228-234`, `withdraw` `:253-260`, `emergencyWithdraw` `:289-291`, `depositFor` `:356-362`. Token transfers via `_pullToken`/`safeTransfer` and external `strategy.deposit/withdraw` calls.
- **Signature match:** `transferFrom(` / `transfer(` + `IERC20` + external strategy call.
- **Conditions met (partially):** state-changing external interactions exist; an ERC777-style or hook-bearing staked token, or a malicious/compromised yield strategy, could re-enter. The contract is NOT strictly CEI everywhere — e.g. `withdraw` mints (`:254`) and then calls `_routeExit`→`strategy.withdraw` and `safeTransfer` after state is already updated.
- **Mitigations present (strong):** every external user/migrator entry point carries `nonReentrant` (`stake`, `withdraw`, `claim`, `emergencyWithdraw`, `migrateOut`, `depositFor`). `rescueERC20` is the only non-guarded external mutator and has no post-transfer state. This largely closes single-function reentrancy; residual risk is cross-function via a malicious strategy, which is a trusted owner-set component.
- **Rationale:** Signatures match but the blanket `nonReentrant` + trusted-strategy assumption demote this; flagged so a scanner can confirm there is no read-only / cross-pool reentrancy via strategy callbacks.
- **Confidence:** low-medium (kept at medium for downstream confirmation of cross-function/strategy-callback vectors).

### 4. DIVISION-PRECISION / rounding (MasterChef reward debt) — `StableStaker` reward math — LOW (informational)
- **Where:** `_updatePool` `:441` (`(reward * ACC_PRECISION) / pool.totalStaked`), `_settle` `:449`, `stake/withdraw/claim/migrateOut/depositFor` reward-debt lines (`:232,245,248,268,270,319,360`), `phUSDPerDay` `:152` (`amountPerDay / SECONDS_PER_DAY`).
- **Signature match:** classic `a * X / b` accumulator division; reward-debt subtraction.
- **Conditions met (partially):** integer division dust exists. `phUSDPerDay` divides before storing the per-second rate, so a daily budget not divisible by 86400 silently rounds the rate down (emission under-shoot, not over-mint).
- **Why NOT promoted:** `ACC_PRECISION = 1e18` scaling is applied *before* division (mul-before-div), the canonical safe ordering. The documented invariant is that dust always rounds DOWN so realized emission ≤ budget — this is a deliberate, safety-favourable rounding direction, not a value-extraction bug. No first-depositor `accPerShare` inflation vector here because rewards are minted (not redeemed from a shared pool) and `totalStaked==0` windows fast-forward `lastRewardTime` accruing nothing.
- **Rationale:** Precision-loss signatures match but the rounding direction is protective and matches the stated invariant; informational only.
- **Confidence:** low.

### 5. CENTRALIZATION-ADMIN — `StableStaker` owner/migrator/pauser; `StableStakerMigrator` owner — LOW (informational)
- **Where:** `onlyOwner` config (`addToken`, `phUSDPerDay`, `setMigrator`, `setPauser`, `setYieldStrategy`, `rescueERC20`), `onlyMigrator` (`migrateOut`, `depositFor`), `onlyPauser`.
- **Signature match:** `onlyOwner`, `require(msg.sender == ...)`.
- **Conditions met:** owner sets emission rate (mint pressure on phUSD), can set an arbitrary yield strategy (custodies all principal), and `migrator` can move/credit user principal with zero user action (`migrateOut`/`depositFor`). `rescueERC20` is bounded to not touch reserved principal (`:521-528`) — a good guard worth verifying for the strategy-set branch where `reserved = 0`.
- **Why NOT promoted:** per C4 / project rules, centralization is QA/Low unless it enables a rug pull. Note the rescue guard sets `reserved = 0` when a strategy is set (principal assumed inside the strategy) — verify no path leaves real principal idle in-contract while a strategy is set (sweep on `setYieldStrategy` handles initial adoption, but a replaced-but-not-drained strategy is documented as an operator hazard).
- **Rationale:** Standard privileged-role surface; informational, but the `rescueERC20` reserved=0 branch and arbitrary-strategy power are worth a sanity pass.
- **Confidence:** low.

---

## Patterns checked and NOT matched (no signature / not applicable)

| Pattern ID | Result | Reason |
|---|---|---|
| ERC4626-INFLATION | not applicable | Not an ERC4626 share vault; no `shares = assets * totalSupply / totalAssets`. Rewards are minted, principal is 1:1 (`user.amount`), no share token. |
| FIRST-DEPOSITOR-ATTACK | not applicable | No `totalSupply()==0` share-exchange-rate branch. `totalStaked==0` only fast-forwards `lastRewardTime`; principal accounting is 1:1, not rate-based. |
| ORACLE-STALE / ORACLE-ROUNDID | not applicable | No `latestRoundData()` / Chainlink / oracle usage. |
| SIGNATURE-REPLAY | not applicable | No `ecrecover` / `ECDSA` / signatures. |
| FRONTRUN-APPROVE | not applicable | No user-facing `approve` race; only internal `forceApprove`. |
| FLASH-LOAN-PRICE | not applicable | No spot-price / reserves / `slot0` reads; no price-derived decisions. |
| UNSAFE-DOWNCAST | not matched | No `uintN(` narrowing casts; all accounting is `uint256`. |
| UNPROTECTED-INIT | not applicable | No `initialize` / `Initializable`; constructor-based, not a proxy. |
| STORAGE-COLLISION | not applicable | No `delegatecall` / proxy. |
| MISSING-SLIPPAGE | not applicable | No `swap`/`exchange`; no user-facing AMM trade. (Strategy may swap internally — out of these contracts' scope.) |
| SELFDESTRUCT-FORCE-ETH | not applicable | No ETH handling / `address(this).balance` logic. |
| DOUBLE-VOTING | not applicable | No governance / voting. |
| PERMIT-FRONTRUN | not applicable | No `permit`. |
| CROSS-CHAIN-REPLAY | not applicable | No bridge / `lzReceive` / `block.chainid`. |
| TIMELOCK-BYPASS | not applicable | No timelock in these contracts. |
| INCORRECT-OPERATOR | not matched | Boundary checks (`getStakersRange` clamp `:392`, `require(start<=end)` `:395`, `user.amount>=amount` `:242`) reviewed; no obvious off-by-one. Left for scanner confirmation. |
