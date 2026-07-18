# Pattern-Match Report — PromotionUniV2_Eth (yield-claim-nft run-17)

- **Project:** yield-claim-nft
- **Primary target:** `src/dispatchers/PromotionUniV2_Eth.sol` (story-044, first ETH + UniswapV2 swap-and-pool path)
- **Context read:** `src/dispatchers/ATokenDispatcherV2.sol` (base), `src/interfaces/uniswap/IUniswapV2Router02.sol`
- **Pattern DB:** `patterns/vulnerability-patterns.json` v1.1 — **35 patterns loaded, 35 checked**
- **Scan type:** pattern-matching (Tier 1). Matches below are pattern hits with context, NOT confirmed findings — Tier-2/3 adjudicate.

Confidence ≠ severity. Low-confidence = "unsure the pattern applies", not "low impact".

---

## Ranked matches (by exploitability)

### 1. MISSING-SLIPPAGE — addLiquidity minAmounts=0, block.timestamp deadlines, floors may be zero  [Medium] confidence: high
- **Lines:** 299-301 (`addLiquidity(..., 0, 0, address(this), block.timestamp)`), 337-338 (`swapExactTokensForETH(..., minEthOut, ..., block.timestamp)`), 343-344 (`swapExactETHForTokens{value: ethBal}(minPromoOut, ..., block.timestamp)`), 375 (Balancer swap `limitRaw: minPhusdOut`).
- **Why it matches:** The `addLiquidity` call passes `amountAMin=0, amountBMin=0` (line 300). Every router/vault call uses `block.timestamp` as the deadline, which can never expire (deadline == the mining block's own time) — this is the canonical "useless deadline" and provides zero protection against a held/delayed tx. The three swap floors (`minPhusdOut`/`minEthOut`/`minPromoOut`) and `minLP` are caller-supplied and the contract does **not** require any of them to be > 0.
- **Vulnerable-when met:** `amountOutMin = 0` possible (floors can be zero), `block.timestamp` deadline (no protection). The whole `pool()` path executes four market operations (USDC→ETH→promo, sUSDS→phUSD, addLiquidity at live ratio) that are individually sandwichable.
- **Mitigations present (reduce, not eliminate):** `pool()` is `onlyAuthorizedPooler whenNotPaused nonReentrant`; `require(liquidity >= minLP)` post-check (line 302); `minLP` + leg floors, IF the pooler sets them tight. Because the caller is an owner-authorized keeper, a correctly-parameterized call is protected — but a keeper misconfig (zero floors / zero minLP) leaves the protocol's own USDC fully exposed to a sandwich on a public mempool tx. Operational footgun + MEV.
- **Preliminary severity:** Medium (keeper-parameterized; drops to Low if floors are always tight off-chain). Deadline-always-`block.timestamp` sub-issue is Low/QA on its own.

### 2. FLASH-LOAN-PRICE — addLiquidity deposits at live (manipulable) reserve ratio  [Medium] confidence: medium
- **Lines:** 292-301 (comment: "The router consumes the pool's live ratio"), 295-296 (`balanceOf` reads), 300 (`addLiquidity`).
- **Why it matches:** The amount of each side actually pooled is decided by the pair's **spot reserves** at call time (UniV2 `addLiquidity` optimal-amount logic). An attacker who skews the phUSD/promotion reserves immediately before the pooling tx forces the deposit at a bad ratio, refunding one side as dust and minting less LP; `getReserves()`/`balanceOf(pair)` spot reliance with no TWAP.
- **Mitigations present:** The single guard is `require(liquidity >= minLP)` (line 302). If `minLP` is set meaningfully this bounds the loss; if `minLP == 0` the guard is vacuous. Same caller-trust caveat as #1.
- **Preliminary severity:** Medium (overlaps #1; the two are the same root exposure — spot-ratio pooling with caller-supplied floors).

### 3. SELFDESTRUCT-FORCE-ETH / stuck-ETH — `address(this).balance` swept into Leg B swap  [Low] confidence: high
- **Lines:** 342 (`uint256 ethBal = address(this).balance;`), 343 (`swapExactETHForTokens{value: ethBal}`), 400 (`receive() external payable {}`), 393-397 (`rescueETH`).
- **Why it matches:** Leg B step 2 swaps the **entire** contract ETH balance, not just the ETH produced by step 1's `swapExactTokensForETH`. `receive()` accepts arbitrary ETH and ETH can be force-sent via `selfdestruct`, so `address(this).balance` is not a faithful measure of "ETH from this leg". Logic depends on the exact ETH balance with no isolation of unexpected ETH.
- **Impact:** Not theft — surplus/forced ETH is swept into promotion tokens and pooled (or, with a tight `minPromoOut` computed only for step-1's ETH, simply produces more output than the floor, which passes). Worst case is mis-attribution of donated/forced ETH into the pool. `rescueETH` (owner) is the escape hatch.
- **Preliminary severity:** Low / QA footgun.

### 4. MINT-ON-DEMAND-OVERMINT / phUSD external-backing (DEDUP-001 class)  [flag + note suppression] confidence: medium
- **Lines:** 255-262 (`_dispatch`: donation forwards `donationSplit%` of USDC to `batchMinter`), doc 250-254 ("the base then calls `hook.onDispatch(minter, amount)` with the GROSS amount, so mint-debt accrues on the full dispatched USDC regardless of the donation").
- **Why it matches:** Mint-debt / phUSD accrual is taken on the **gross** dispatched USDC while a fraction of that USDC physically leaves to `batchMinter`. The phUSD minted against the dispatch is backed by less-than-gross retained USDC — the recurring phUSD under-backing shape (MINT-ON-DEMAND-OVERMINT signatures `mint(` / `phUSD`).
- **Suppression note:** This is the **DEDUP-001 external-backing** class, which is **project-suppressed** for yield-claim-nft (phUSD backing is handled externally to the dispatcher; NFTs have no redemption leg). Flagged for completeness per Law 1 — NOT proposed as a new finding. Route to sanitizer for DEDUP-001 reconciliation. Do not escalate absent a new unbacked-mint path.

### 5. CENTRALIZATION-ADMIN / hook fail-open (ledger L-09 / Q-08 carryover)  [Low/QA] confidence: medium
- **Lines:** base `ATokenDispatcherV2.setHook` (94-99, non-zero-checked only); `_dispatch` here adds no `hookTypeId` guard; per-partner owner setters here (`setPool`, `setEthToPromotionPath`, `setPSM`, `setMaxTin`, `setDonationSplit`, `setBatchMinter`, `setAuthorizedPooler`).
- **Why it matches:** Continuation of the ledger **L-09/Q-08 dispatcher-hook-with-no-hookTypeId-guard** class — the hook path validates only non-zero, not hook identity/type. No new hook path is introduced by this contract (it inherits the base dispatch), so this is a carryover reference, not a fresh instance.
- **Preliminary severity:** Low/QA. Owner-configuration surface is Law-3 trusted for obvious misuse; surfaced as reference. `setEthToPromotionPath` routing to an illiquid intermediate is an obvious owner footgun → suppress.

### 6. REENTRANCY-ERC777 — arbitrary `promotionToken` transfer hooks  [Low] confidence: low
- **Lines:** `promotionToken` is a per-partner arbitrary ERC20 (80, 137); transfers occur in `_legB`/`addLiquidity` (295-301, 343-345); `unlockCallback` (361) is external, guarded only by `msg.sender == BALANCER_VAULT` and NOT by the `nonReentrant` lock.
- **Why it matches:** If `promotionToken` is ERC777-like (transfer hook), a token transfer during `pool()` hands control to the token mid-flow. Cross-function reentrancy candidate (REENTRANCY-CROSS-FUNCTION signatures too).
- **Mitigations present:** `pool()` and `dispatch()` are `nonReentrant` (shared OZ lock), so reentry into them is blocked; `unlockCallback` is only callable by the Balancer vault during our own `unlock`; rescue fns are `onlyOwner`. No profitable reentry target found — the hook has nowhere useful to land.
- **Preliminary severity:** Low. Flagged so Tier-2 confirms the sibling set (unlockCallback lock-sharing) is genuinely safe.

### 7. RETURN-VALUE-IGNORE / leftover dust — addLiquidity unused `amountA`/`amountB`  [QA] confidence: high
- **Lines:** 299-301 (`(,, uint256 liquidity)` — the two consumed-amount returns discarded).
- **Why it matches:** `addLiquidity` returns the actually-consumed `amountA`/`amountB`; only `liquidity` is captured. The unconsumed side is refunded and accrues as dust.
- **Not vulnerable:** This is **by design** (documented lines 292-294: "residual dust accrues on the dispatcher for the next pool()"), and `liquidity` IS checked against `minLP`. QA-only note.

---

## Checked, NO material match (recorded for coverage)

- **FEE-ON-TRANSFER-ACCOUNTING** — checked: `promotionToken` is arbitrary/per-partner, BUT the pooled amounts are read from `balanceOf(address(this))` (lines 295-296) *after* the swaps, i.e. measured actual balance, not a requested `amount`. The pooling leg is therefore NOT FoT-vulnerable. (The `_dispatch` gross-vs-net accrual is the phUSD-backing issue in match #4, not a FoT skew.)
- **ERC4626-INFLATION / FIRST-DEPOSITOR-ATTACK** — checked: `IERC4626(sUSDS).deposit` (322) is a deposit INTO Sky's audited sUSDS as a normal depositor; no first-depositor / share-inflation surface created here. No match.
- **REENTRANCY-READONLY** — checked: no value-reporting view (price/totalAssets/exchangeRate) is exposed on this contract; `targetPool`/`ethToPromotionPath` are config views. No match.
- **REENTRANCY-ERC721-RECEIVE** — no NFT mint/safeTransfer in this contract. No match.
- **ROUNDING-DIRECTION / DIVISION-PRECISION** — `amountIn/2` then `halfB = amountIn - halfA` (286-287) loses no wei; no user-favouring conversion. No match.
- **ORACLE-STALE / ORACLE-ROUNDID / FLASH-LOAN-PRICE(oracle-read)** — no Chainlink/oracle read. (Spot-reserve reliance captured in match #2.)
- **SIGNATURE-REPLAY / PERMIT-FRONTRUN / CROSS-CHAIN-REPLAY** — no ecrecover/permit/bridge. No match.
- **UNPROTECTED-INIT / STORAGE-COLLISION** — constructor-initialized, not a proxy/initializer pattern. No match.
- **UNSAFE-DOWNCAST** — no narrowing casts. No match.
- **DOS-UNBOUNDED-LOOP** — no loops (`_ethToPromotionPath` is owner-bounded, iterated only inside router). No match.
- **INCORRECT-OPERATOR** — `require(... <= maxTin)` / `<= balanceOf` are value guards, not deadline/window boundaries. No match.
- **Staking-yield family** (REWARD-ACCRUAL-ORDER, REWARD-RUNWAY-DEPLETION, EMISSION-WINDOW-BOUNDARY, BATCH-PAYOUT-FIXED-POT, YIELD-PRINCIPAL-ACCOUNTING-SKEW, TWO-STEP-COMMIT-WINDOW): checked (general MasterChef/accumulator signatures) — no `accRewardPerShare`/`rewardDebt`/`_updatePool`/`rewardRate`/emission-window logic in this dispatcher. No match. (Phoenix regression anchors absent by design — this is a zap dispatcher, not a farm.)
- **WEAK-PRNG, DOUBLE-VOTING, TIMELOCK-BYPASS** — no randomness/governance/timelock surface. No match.

## Skipped patterns
- **FRONTRUN-APPROVE** — `note` says C4 treats as QA/known-issue; `forceApprove(...,0)` reset pattern used (303-304, 318, 340). No plausible HM twist. Skipped from primary findings, recorded here.

---

## Notes for downstream (dedup / sanitizer / Tier-2)
- Matches #1 and #2 are the same root exposure (spot-ratio pooling + caller-supplied floors) — dedup should collapse to one Medium and let econ-scanner confirm whether an authorized-pooler-only entry point + `minLP` guard reduces this to Low.
- Match #4 must reconcile against **DEDUP-001** (project-suppressed) — flagged, not filed.
- Match #5 must reconcile against ledger **L-09 / Q-08** — carryover reference, not a new instance.
- Owner-config footguns (`setEthToPromotionPath`, `setMaxTin`, `setBatchMinter`) are Law-3 obvious → suppress.
