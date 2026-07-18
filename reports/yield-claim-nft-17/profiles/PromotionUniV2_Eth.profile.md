# Contract Profile — PromotionUniV2_Eth.sol

- **Contract:** `src/dispatchers/PromotionUniV2_Eth.sol` (401 LOC, story-044)
- **Profiled:** 2026-07-18
- **Solidity:** `^0.8.20` (checked arithmetic)
- **Scope note:** Local single-contract profile. Base `ATokenDispatcherV2`, interface `IUniswapV2Router02`, and hooks read as trust boundaries only — not analyzed for their own findings.

---

## 1. Inheritance chain

```
PromotionUniV2_Eth
 └─ ATokenDispatcherV2 (abstract)
     ├─ ITokenDispatcherV2 (interface)
     ├─ Pausable        (OZ)
     ├─ Ownable         (OZ)
     └─ ReentrancyGuard (OZ)
 └─ IUnlockCallback     (Balancer V3 unlock callback interface)
```

`using SafeERC20 for IERC20`.

### Base functions relied on (NOT overridden)
- `dispatch(address,uint256,bytes)` — **non-virtual** template-method entry point on the base. Applies `nonReentrant + onlyMinter + whenNotPaused`, calls `_dispatch(...)`, then unconditionally calls `hook.onDispatch(...)`. PromotionUniV2_Eth does **not** and **must not** re-declare these modifiers.
- `pause()/unpause()` — `onlyMinter`.
- `setMinter`, `setHook`, `setMetadata`, `name/image/description`, `hook` getter — base owner/minter surface, inherited unchanged.
- `hook` state var — initialized to a freshly-deployed no-op `DefaultDispatchHook` in the base constructor; never zero.

### Functions overridden
- `_dispatch(address,uint256,bytes)` — internal virtual extension point. Only override.

### Interface functions implemented
- `primeToken()` → `USDC` (pure override of `ITokenDispatcherV2`).
- `unlockCallback(bytes)` → Balancer V3 callback (from `IUnlockCallback`).

---

## 2. External / public function surface

| Function | Vis | Access control | State mutated / effect |
|---|---|---|---|
| `dispatch(minter,amount,extraData)` | external | `onlyMinter` + `whenNotPaused` + `nonReentrant` (base) | calls `_dispatch` then `hook.onDispatch` |
| `pool(amountIn,minPhusdOut,minEthOut,minPromoOut,minLP)` | external | `onlyAuthorizedPooler` + `whenNotPaused` + `nonReentrant` | consumes retained USDC; acquires phUSD (Leg A) + promotion (Leg B); adds LP; approvals set/reset; emits `Pooled` |
| `primeToken()` | external pure | none | — (returns USDC) |
| `targetPool()` | external view | none | — |
| `ethToPromotionPath()` | public view | none | — |
| `setPool(newPair)` | external | `onlyOwner` | `_targetPair` (validated) |
| `setEthToPromotionPath(path)` | external | `onlyOwner` | `_ethToPromotionPath` (validated) |
| `setPSM(newPSM)` | external | `onlyOwner` | `psm` (non-zero) |
| `setMaxTin(newMaxTin)` | external | `onlyOwner` | `maxTin` (no bound check) |
| `setDonationSplit(newSplit)` | external | `onlyOwner` | `donationSplit` (≤100) |
| `setBatchMinter(newBatchMinter)` | external | `onlyOwner` | `batchMinter` (zero allowed = disables donation) |
| `setAuthorizedPooler(pooler,authorized)` | external | `onlyOwner` | `poolerAuthVersion[pooler]` |
| `incrementAuthVersion()` | external | `onlyOwner` | `authVersion++` (mass-revoke) |
| `rescueERC20(token,to,amount)` | external | `onlyOwner`, **not pause-gated** | transfers any ERC20 out (also LP-withdrawal path) |
| `rescueETH(to,amount)` | external | `onlyOwner`, **not pause-gated** | native ETH out via `.call` |
| `receive()` | external payable | **none (open)** | accepts native ETH |
| `unlockCallback(data)` | external | `require(msg.sender == BALANCER_VAULT)` | Balancer pay→swap→settle→sendTo |

Internal: `_dispatch`, `_setPool`, `_legA`, `_legB`, `_swapSusdsForPhusd`.

**Base owner surface also present:** `setMinter`, `setHook`, `setMetadata`, `pause`, `unpause`.

---

## 3. Donation-split dispatch logic

`_dispatch(_, amount, _)` (called with USDC already on-contract):
- `donationEnabled = batchMinter != address(0) && donationSplit > 0`.
- `donationAmount = donationEnabled ? amount * donationSplit / 100 : 0`.
- Transfers `donationAmount` USDC to `batchMinter`; remainder stays as prime balance for the next `pool()`.
- **Gross-amount hook convention:** the base then calls `hook.onDispatch(minter, amount, extraData)` with the **GROSS** `amount` (pre-donation) — mint-debt accrues on the full dispatched USDC regardless of the donation cut. Same convention as Uniboost / BalancerPoolerV2.

Arithmetic: `amount * donationSplit / 100`, `donationSplit ≤ 100` enforced by setter; 0.8 checked. No rounding surprise (donation rounds down, remainder retained).

---

## 4. `pool()` — the two-legged zap (the NEW surface)

`pool(amountIn, minPhusdOut, minEthOut, minPromoOut, minLP)`:
1. `require(amountIn > 0)`, `require(amountIn <= USDC.balanceOf(this))`.
2. `halfA = amountIn/2`, `halfB = amountIn - halfA` (odd wei goes to Leg B).
3. `phusdOut = _legA(halfA, minPhusdOut)`.
4. `_legB(halfB, minEthOut, minPromoOut)`.
5. `addLiquidity(phUSD, promotionToken, phusdBal, promoBal, 0, 0, this, block.timestamp)` using **full contract balances** of phUSD and promotion (not just leg outputs — pre-existing dust is swept in). `require(liquidity >= minLP)`.
6. Approvals reset to 0 for both tokens; emits `Pooled`.

### Leg A — USDC → phUSD (Balancer path)
`_legA(usdcAmount, minPhusdOut)`:
- Step 1: `require(ISkyPSM(psm).tin() <= maxTin)`; `forceApprove(psm, usdcAmount)`; `sellGem(this, usdcAmount)` → USDS; approve reset to 0. **PSM has no per-tx slippage floor** — the only Leg-A-step-1 protection is the `maxTin` ceiling (default 1e16 = 1%).
- Step 2: `forceApprove(sUSDS, usdsOut)`; `IERC4626(sUSDS).deposit(usdsOut, this)` → shares.
- Step 3: `_swapSusdsForPhusd(shares, minPhusdOut)` → phUSD via Balancer V3 `unlock`→`unlockCallback` (EXACT_IN, `limitRaw = minPhusdOut`).

`unlockCallback(data)`:
- `require(msg.sender == BALANCER_VAULT)`.
- Order: `sUSDS.safeTransfer(vault, sharesIn)` (pay) → `vault.swap(EXACT_IN, limitRaw=minPhusdOut)` → `vault.settle(sUSDS, sharesIn)` → `vault.sendTo(phUSD, this, amountOut)`. Returns `amountOut`.

### Leg B — USDC → ETH → promotion (the ETH / UniV2 path — genuinely new)
`_legB(usdcAmount, minEthOut, minPromoOut)`:
- `forceApprove(UNIV2_ROUTER, usdcAmount)`; `swapExactTokensForETH(usdcAmount, minEthOut, [USDC,WETH], this, block.timestamp)`; approve reset to 0.
- `ethBal = address(this).balance` — **reads the ENTIRE contract ETH balance, not just this swap's output** — then `swapExactETHForTokens{value: ethBal}(minPromoOut, ethToPromotionPath(), this, block.timestamp)`.

---

## 5. Slippage floor handling

| Leg | Floor param | Enforced by |
|---|---|---|
| Leg A PSM sell | (none per-tx) | `maxTin` ceiling only (`tin() <= maxTin`) |
| Leg A Balancer swap | `minPhusdOut` | `limitRaw` on EXACT_IN swap |
| Leg B USDC→ETH | `minEthOut` | router `amountOutMin` |
| Leg B ETH→promotion | `minPromoOut` | router `amountOutMin` |
| addLiquidity | `minLP` | post-call `require(liquidity >= minLP)` |

**Note:** `addLiquidity` is called with `amountAMin = amountBMin = 0`. Per-token add-slippage is intentionally unbounded; the design relies on the four leg floors + the final `minLP` to bound overall slippage. The router consumes the pool's live ratio and refunds the excess side; residual dust remains on-contract. All floors are **caller-supplied** by the authorized pooler (off-chain quoted) — correctness of MEV protection depends on the pooler passing tight values.

---

## 6. `setPool` / path validation, pooler-auth gating

- `_setPool(newPair)`: `require(newPair != 0)`; reads `token0()/token1()`; requires the pair's token set equals `{phUSD, promotionToken}` order-agnostically; stores `_targetPair`; emits `PoolSet`. Called in constructor and by `setPool` (onlyOwner).
- `setEthToPromotionPath(path)`: `require(path.length >= 2)`, `path[0] == WETH`, `path[last] == promotionToken`. Interior hops unvalidated (owner-trusted). Empty path ⇒ default `[WETH, promotionToken]` via `ethToPromotionPath()`.
- **Pooler auth (verbatim from Uniboost):** `onlyAuthorizedPooler` requires `poolerAuthVersion[msg.sender] == authVersion`. `setAuthorizedPooler` sets/deletes; `incrementAuthVersion` mass-revokes. `authVersion` initialized to 1 in constructor.

---

## 7. Value-handling surface

- `rescueERC20(token,to,amount)` — onlyOwner, **not pause-gated**; requires `to != 0`. This is the **only LP-withdrawal path** — the pair LP token accrues on the dispatcher as protocol-owned liquidity and is pulled out here. Also sweeps any prime USDC / phUSD / promotion / sUSDS / USDS dust.
- `rescueETH(to,amount)` — onlyOwner, **not pause-gated**; requires `to != 0`; native `.call{value}`.
- `receive()` — **open, no access control.** Documented purpose: accept the ETH unwrapped by `swapExactTokensForETH` in Leg B. But it accepts ETH from anyone.

---

## 8. Hardcoded literals

**No `keccak256` / `hookTypeId` / `bytes32` type-tag literal is declared in this contract.** The ledger M-04 literal-drift watch (`NudgeRatchet.sol:31`, `NudgeRatchetMintDebtHook.sol:31`, `NudgeRatchetDelayRelease.sol:52`, all `keccak256("NudgeRatchetMintDebtHook.v1")`) has **no counterpart here** — nothing to byte-compare. This dispatcher does NOT gate its hook by type-id.

Address / numeric constants (mainnet-fixed, for downstream cross-check):
```
phUSD          = 0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605  (18dp)
USDC           = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  (6dp, prime)
USDS           = 0xdC035D45d973E3EC169d2276DDab16f1e407384F  (18dp)
sUSDS          = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD  (ERC4626)
WETH           = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9  (V3)
BALANCER_POOL  = 0x642BB6860b4776CC10b26B8f361Fd139E7f0db04  (phUSD/sUSDS 50/50)
UNIV2_ROUTER   = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
WAD            = 1e18
psm (default)  = 0xA188EEC8F81263234dA3622A406892F3D630f98c  (owner-settable)
maxTin (default)= 1e16 (1%)
```
Downstream note: `USDC` literal `0xA0b8…eB48` matches the canonical mainnet USDC; `psm` default matches the Sky `UsdsPsmWrapper` documented in `ISkyPSM.sol`. No manual-review flag on the literals themselves, but a downstream address-verification pass is warranted (they are copied constants).

---

## 9. Hook path — L-09 fail-open class (REACHABLE HERE)

- PromotionUniV2_Eth uses the **same `_dispatch` → base `dispatch` → `hook.onDispatch(...)` path as Uniboost**, with **no `hookTypeId` guard** (grep-confirmed: no `keccak256`/`hookTypeId` in this file; Uniboost likewise has none; only `NudgeRatchet*` gate by `EXPECTED_HOOK_TYPE_ID`).
- `hook` defaults to a no-op `DefaultDispatchHook` (base constructor). Unless the owner calls `setHook(mintDebtHook)` to wire the real mint-debt hook, `dispatch` **silently accrues zero mint-debt** — the no-op default just returns. This is exactly the ledger **L-09 fail-open class** (unwired-hook, no type guard).
- **Unwired-hook fail-open is reachable here.** The contract deploys/operates fully functionally with the default no-op hook; nothing in the mint or dispatch path forces the mint-debt hook to be attached, and no `hookTypeId()` verification exists to reject a wrong/absent hook. Surface for interaction analysis (mint-debt accounting) — not adjudicated locally.
- `setHook` (base) requires non-zero but does NOT verify hook type/behaviour; a reverting/misbehaving hook bricks `dispatch` until swapped (base-documented).

---

## 10. Key invariants (should hold — for downstream verification)

1. **Backing / mint-debt:** every `dispatch` that credits a mint must accrue mint-debt on the GROSS USDC via the hook — HOLDS ONLY IF the real mint-debt hook is wired (see §9; fail-open otherwise).
2. **Value conservation in `pool()`:** all `amountIn` USDC is converted through the two legs into pool-owned LP + on-contract dust; no path leaks USDC to an unauthorized party (donation path is `_dispatch`-only, not `pool`).
3. **Slippage:** `phusdOut >= minPhusdOut`, ETH `>= minEthOut`, promotion `>= minPromoOut`, `liquidity >= minLP`, `tin <= maxTin` — all caller/owner-parameterized; correctness depends on tight off-chain quotes.
4. **Pool identity:** `_targetPair` always holds exactly `{phUSD, promotionToken}` (enforced in `_setPool`).
5. **Auth:** only `poolerAuthVersion[caller] == authVersion` can `pool()`; `incrementAuthVersion` mass-revokes.
6. **Approvals:** every `forceApprove(spender, x)` in `pool()`/`_legA()` is reset to 0 after use (no lingering allowance) — verified for PSM, UNIV2_ROUTER (both legs + addLiquidity).
7. **ETH balance:** `_legB` sweeps the ENTIRE contract ETH balance into the promotion buy — invariant assumes no unrelated ETH resides on-contract at `pool()` time (see risk note below).

---

## 11. External call surface & reentrancy / CEI

**Untrusted / semi-trusted external calls:**
| Target | Methods | Trust | Notes |
|---|---|---|---|
| `promotionToken` (per-partner) | transfer/transferFrom via router, `balanceOf` | **semi-trusted (config)** | owner-chosen per partner; if fee-on-transfer / rebasing / malicious-callback token, leg accounting & LP add skew. Router-mediated. |
| `IUniswapV2Router02` (UNIV2_ROUTER) | `swapExactTokensForETH`, `swapExactETHForTokens`, `addLiquidity` | trusted (canonical) | but internally calls promotion token & sends native ETH to `receive()` |
| Balancer V3 vault | `unlock`/`swap`/`settle`/`sendTo`; re-enters `unlockCallback` | trusted | callback gated `msg.sender == BALANCER_VAULT` |
| Sky PSM (`psm`) | `sellGem`, `tin` | trusted (owner-set, default canonical) | no per-tx slippage; `maxTin` ceiling only |
| `sUSDS` ERC4626 | `deposit` | trusted | |
| `batchMinter` | USDC `safeTransfer` | semi-trusted | receives donation cut |
| `to` in rescueETH | `.call{value}` | owner-chosen | onlyOwner |

**Reentrancy / CEI:**
- `dispatch` and `pool` both carry `nonReentrant` on the **shared** OZ `ReentrancyGuard` `_status` — a callback (promotion-token hook, ETH receive, Balancer callback) cannot re-enter either `dispatch` or `pool` mid-`pool()`.
- `unlockCallback` is `external` **without** `nonReentrant`, but is hard-gated to `BALANCER_VAULT` only, and is only reached inside the guarded `pool()` frame.
- **Unguarded owner state-changers** (`rescue*`, all setters) are NOT `nonReentrant`, but are `onlyOwner`, so an external token/vault cannot invoke them — no reentrancy path into unguarded mutators from swap callbacks.
- CEI in `pool()`: external calls are interleaved with balance reads; final `addLiquidity` uses post-leg balances. Guarded by `nonReentrant`, so intermediate-state reentrancy is blocked. `unlockCallback` follows Balancer's mandated pay→swap→settle→sendTo order.

---

## 12. NEW risk surface vs prior dispatchers (Uniboost / BalancerPoolerV2)

The prior dispatchers were **token-only** (Balancer + UniV2 token↔token). PromotionUniV2_Eth is the **first to touch native ETH**, and adds:

1. **Native-ETH round-trip (Leg B):** USDC→ETH→promotion via two UniV2 swaps. Introduces an **open `receive()`** and a **full-balance ETH sweep** (`ethBal = address(this).balance`) — `_legB` swaps the entire contract ETH balance, not just the current swap's output. Any ETH pre-deposited (via the open `receive()`, a prior partial Leg B, or `selfdestruct`/coinbase) is folded into the promotion buy of whichever pooler calls next. Surface for downstream: cross-`pool()` ETH accounting / third-party ETH-donation griefing (bounded by `minPromoOut`, but the extra ETH becomes promotion the donor didn't intend — value routed to pool, not stolen). Flagged for interaction analysis, not adjudicated locally.
2. **`rescueETH` + non-pause-gated escape hatches** — new value-egress surface (ETH) beyond `rescueERC20`.
3. **Two extra slippage params** (`minEthOut`, `minPromoOut`) and a **longer, owner-mutable swap path** (`setEthToPromotionPath`, interior hops unvalidated) — more caller-quote surface and more MEV sandwich legs (four swaps + LP add per `pool()`).
4. **Same L-09 fail-open hook path** as Uniboost — carried over, not fixed (no `hookTypeId` guard). Reachable.
5. **`maxTin` has no upper bound in `setMaxTin`** — owner could set it high, removing the only Leg-A PSM slippage protection (owner footgun, non-malicious-owner test applies; surface for triage).

**No local (single-contract) HIGH findings surfaced** — arithmetic is checked, no unbounded loops, no weak randomness, initializer N/A (non-upgradeable), access control present on all mutators (pooler/owner/minter). The material risks are **interaction-level** (mint-debt fail-open, ETH-sweep accounting, four-leg MEV, promotion-token trust) and are recorded above as trust boundaries / invariants for the interaction scanner.
