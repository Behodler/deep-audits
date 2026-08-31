# Code Scan — PromotionUniV2_Eth.sol (story-044, HEAD 8dd8963)

- **Scanner:** code-scanner (Tier 2, interaction-level)
- **Target:** `src/dispatchers/PromotionUniV2_Eth.sol` (401 LOC)
- **Context read:** `ATokenDispatcherV2.sol`, `IUniswapV2Router02.sol`, `IBalancerVault.sol`, `BalancerTypes.sol`, `ISkyPSM.sol`, `UniboostMintDebtHook.sol`, sibling `Uniboost.sol`
- **Date:** 2026-07-18

## Verdict

**No confirmed High or Medium code-level implementation bug.** The two-leg zap, the 50/50 split, the Balancer `unlock`→callback flow, the PSM/ERC4626 wrap, and the `addLiquidity` call all trace correctly, with the correct variables, amounts, decimals, token ordering, and approve/reset discipline. The `IUniswapV2Router02` signatures match the canonical mainnet Router02 exactly — **no interface delta**. The residual issues are Low/QA (open-`receive` ETH sweep) or defer to econ-scanner (LP-add MEV) or are DEDUP-001-suppressed (backing convention).

---

## Trace confirmations (things checked and CLEARED)

These were the requested deep-dive items. Each is confirmed benign so they are not re-raised as bugs:

1. **ETH source for Leg B (traced precisely).** In `_legB` (L332-346) the ETH is the *output of the USDC→ETH swap* (`swapExactTokensForETH`, path `[USDC, WETH]`, router unwraps WETH→native and sends to `address(this)` via `receive()`). It is **not** `msg.value` (neither `pool` nor `_legB` is payable) and not pre-funded under normal operation. `ethBal = address(this).balance` (L342) then sweeps the *entire* balance into `swapExactETHForTokens{value: ethBal}`. Because exact-in ETH swaps consume all input, **no ETH dust is left by a normal `pool()`** — the balance is fully spent. Pre-existing ETH can only arrive via the open `receive()` (see L-1 below).

2. **Wrong-variable / wrong-amount / off-by-one sweep — none found.** `halfA + halfB == amountIn` (L286-287, odd wei to Leg B). `_legA(halfA)`, `_legB(halfB)`. `addLiquidity(phUSD, promotionToken, phusdBal, promoBal, …)` (L299-301) — token order matches amount order. `unlockCallback` (L361-379): `tokenIn=sUSDS`, `tokenOut=phUSD`, `amountGivenRaw=sharesIn`, `limitRaw=minPhusdOut` — direction and EXACT_IN floor correct. `phusdOut` (return of `_legA`) is used only in the `Pooled` emit; `addLiquidity` correctly uses live balances. No mismatch.

3. **Decimals.** `sellGem` return `usdsOut` (18dp USDS) is used directly as the `sUSDS.deposit` input and as `shares` source — the code consumes PSM/ERC4626 **return values** rather than hand-scaling, so the 6dp→18dp USDC→USDS jump cannot be mis-scaled here. Confirmed against `ISkyPSM.sellGem` (returns `usdsOutWad`).

4. **Slippage floors — `minLP` does protect the phUSD side.** Every leg has a floor: Leg A Balancer swap `limitRaw = minPhusdOut` (L372), Leg B `minEthOut`/`minPromoOut` (router `amountOutMin`), plus `require(liquidity >= minLP)` (L302). UniV2 `liquidity = min(amtA·supply/resA, amtB·supply/resB)`, so `minLP` is bounded by the *scarcer* side — a short phUSD side depresses `liquidity` and trips `minLP`. So `minLP` jointly guards both sides (given a tight caller quote). The only unbounded piece is `amountAMin=amountBMin=0` on `addLiquidity` (L300) — see NOTE-2 (MEV, econ-scanner).

5. **forceApprove reset / allowance leftovers.** PSM (L316/318), Leg-B router (L336/340), and `addLiquidity` router approvals (L297-298/303-304) are all reset to 0. The one non-reset is `forceApprove(sUSDS, usdsOut)` (L321) — but `IERC4626.deposit(usdsOut, …)` pulls exactly `usdsOut`, consuming the allowance to 0. No exploitable residual allowance. (Profile invariant #6 has this benign exception.)

6. **Reentrancy / CEI across `receive()` and the Balancer callback.** `pool` and `dispatch` share the OZ `ReentrancyGuard` `_status` (base L118-123 + L281), so a promotion-token callback, the ETH `receive()`, or the Balancer callback cannot re-enter either. `unlockCallback` is `external` without `nonReentrant` **but** hard-gated `msg.sender == BALANCER_VAULT` (L362); Balancer V3 `unlock` dispatches the callback to *the unlock caller only*, so no third party can drive this contract's `unlockCallback` / sUSDS transfer — it is reachable solely inside this contract's own guarded `pool()` frame. No cross-function reentrancy target (all setters/`rescue*` are `onlyOwner`). No public view is used as an oracle → no read-only-reentrancy victim surface. ERC721/1155/777 hooks: N/A (no NFT mint / no `_safeMint` here).

7. **Balancer `settle`/`swap` unchecked returns — safe.** `settle` credit and `swap` amounts are unchecked, but Balancer V3 `unlock` reverts if the transient debt is not fully settled, and `settle(sUSDS, sharesIn)` uses the exact transferred amount as the hint; a shortfall reverts the whole `pool()`. No value can leak. sUSDS is not fee-on-transfer. Informational only.

8. **Interface delta — NONE.** `swapExactTokensForETH(uint,uint,address[],address,uint)`, `swapExactETHForTokens(uint,address[],address,uint) payable`, `addLiquidity(address,address,uint,uint,uint,uint,address,uint)` all byte-match mainnet Router02 (`0x7a25…2488D`). No signature mismatch / no phantom function.

---

## Findings

### L-1 (Low / QA) — Open `receive()` + whole-balance ETH sweep folds stray ETH into the next pooler's promotion buy
- **Location:** `PromotionUniV2_Eth.sol` `receive()` L400; `_legB` L342-345 (`ethBal = address(this).balance` → `swapExactETHForTokens{value: ethBal}`)
- **Status:** CONFIRMED (behavior traced) — severity honestly Low/QA, not H/M.
- **Scenario:** `receive()` (L400) accepts native ETH from anyone. `_legB` swaps the **entire** contract ETH balance, not just this call's swap output. Any ETH sitting on the contract at `pool()` time — an accidental transfer, or a deliberate donation/grief — is irreversibly converted to `promotionToken` and added to protocol-owned LP on the next `pool()`.
- **Why it is NOT H/M:** the swept ETH becomes `promotionToken` → into the phUSD/promotion LP, which is **protocol-owned** (withdrawn only via owner `rescueERC20`). The griefer/sender loses their ETH; the protocol *gains* LP. There is no theft and no third-party profit. `minPromoOut` still holds (more ETH ⇒ more promotion out). A DoS via UniV2 `uint112` reserve overflow would require donating >`uint112`-worth of ETH — infeasible.
- **Known-invalid overlap:** the accidental-send variant is "user input mistake" (C4 known-invalid). The deliberate-donation variant benefits the protocol. Net: report as QA transparency, not a security bug.
- **Note for owner:** `rescueETH` (L393) can recover stray ETH, but a pooler can front-run it; operationally, sweep stray ETH before authorizing a `pool()` if it must not enter LP.

### NOTE-2 (defer to econ-scanner) — `addLiquidity` called with `amountAMin = amountBMin = 0`
- **Location:** L299-301. Only `minLP` (L302, caller-supplied) backstops the LP add against a sandwich that skews the pair ratio immediately before `addLiquidity`. This is an MEV/pricing concern (out of code-scanner scope per the agent's OOS list) and is by-design per the profile (§5). Flagged for **econ-scanner** to assess whether a loose `minLP` quote is exploitable; no code defect.

### NOTE-3 (DEDUP-001, suppressed) — gross-amount hook vs donation split & ≤50% mint-debt ratio
- **Location:** `_dispatch` L255-262 (donates `amount*split/100` USDC to `batchMinter`, retains remainder) + base `hook.onDispatch(GROSS amount)` (base L125) + `UniboostMintDebtHook.onDispatch` mints `amount*scale*ratio/100`, `ratio ≤ 50`.
- **Assessment:** the hook mints phUSD debt on **gross** USDC at **≤50%**, while the dispatcher (Leg A) plus `batchMinter` between them convert the **full** gross USDC into phUSD/LP backing. Direction is **over-backing, not under-mint** — the split relocates *where* backing is pooled, it does not create unbacked phUSD (provided `batchMinter` does not itself double-accrue debt on the donated USDC, a cross-contract assumption owned by the BalancerPooler wiring). Same convention as Uniboost/BalancerPoolerV2. This is the **DEDUP-001** area and is **suppressed** per task instruction — recorded here for traceability, not raised.

### NOTE-4 (carried, not new) — L-09 fail-open hook class is reachable
- No `hookTypeId` guard; `hook` defaults to the no-op `DefaultDispatchHook`. If the owner never wires `UniboostMintDebtHook`/mint-debt hook, `dispatch` silently accrues zero debt. Same class as the ledger's L-09 (Uniboost). Reachable here; carried, not a new PromotionUniV2_Eth-specific defect.

---

## Ranked summary

| Rank | ID | Severity | Type | Status | One-liner |
|---|---|---|---|---|---|
| 1 | L-1 | Low/QA | stray-ETH sweep | CONFIRMED | Open `receive()` + whole-balance sweep folds stray ETH into next promotion buy → protocol LP (no theft; accidental-send is known-invalid) |
| 2 | NOTE-2 | (econ) | MEV | defer | `addLiquidity` minA/minB = 0; only caller `minLP` guards the LP add — econ-scanner to judge |
| 3 | NOTE-3 | (suppressed) | backing | DEDUP-001 | gross-hook + ≤50% ratio = over-backing not under-mint; suppressed |
| 4 | NOTE-4 | (carried) | fail-open hook | carried | L-09 unwired-hook class reachable (no type guard); not new here |

**Bottom line:** the NEW code is implemented correctly. No wrong-variable, wrong-amount, off-by-one, decimals, slippage-application, approval-leak, interface-mismatch, or reentrancy/CEI defect was found. The only genuinely new surface (native-ETH Leg B) yields one Low/QA item (L-1); everything material is either MEV (econ), DEDUP-001-suppressed, or a carried class.
