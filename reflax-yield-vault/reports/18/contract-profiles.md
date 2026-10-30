# Contract Profiles — reflax-yield-vault @ `4788ed4` (run 18, regression)

Baseline: `cdd0743` (run 17). Range: `25276b8` [story-051] revert `previewExitFor`; `4788ed4` [story-052] `CurveAMMAdapter.setRoute` contiguity (M-01 class, sya-harvester origin).
Format matches run 17 (`reports/17/contract-profiles.md`): one file, one section per contract. Unchanged contracts carry the run-17 profile forward by reference.

## 0. Headline facts for downstream agents

1. **story-051 is a pure, exact revert.** `IYieldStrategy.sol` and `AYieldStrategy.sol` at HEAD are byte-identical to `0110ce4` (pre-story-050). `ERC4626MarketYieldStrategy.sol` differs from `0110ce4` only by one `forge fmt` reflow of the `setAsideBufferRecipient` require (`:291`). `git diff cdd0743..HEAD` on the three files contains **zero added lines**, only deletions. `grep -rn "previewExitFor|_exitFloor|netGuaranteed|grossToRequest" src/` returns no hits at HEAD (CLAUDE.md and docs included). Unused `Math` import removed with it. No `Math.` use remains.
2. **`_disposeShares` / minOut semantics are unchanged** from both run 17 and pre-050 (`ERC4626MarketYieldStrategy.sol:158-180`). It was never modified by story-050/051. Only its deleted twin `_exitFloor` is gone.
3. **No sibling consumer of `previewExitFor` exists.** grep over `~/code/audits/*/src` excluding `lib/` found none, so the revert causes no cross-repo ABI break. The only breakage is in the 8 audit-authored run-17 harnesses in `work/` (already listed in run-context skip set). That is not a finding.
4. **story-052's validator is a faithful port and closes the M-01 gap class.** Two residual acceptances were probed and confirmed empirically (see §1, LOCAL-001/002). Probe: `/home/justin/code/audits/reflax-yield-vault/work/test/profile-run18/SetRouteResidual.t.sol`, 3/3 PASS. Audit-authored, never file it as upstream code.

---

## 1. `src/AMMAdapters/CurveAMMAdapter.sol` (CHANGED, +68) — PRIMARY

**Type:** `contract CurveAMMAdapter is IAMMAdapter, Ownable` (OZ v5 `Ownable(_owner)`), pragma `^0.8.13`, compiled 0.8.30. Not upgradeable. No assembly, no `unchecked`.
**State:** `router` (`ICurveRouterNG` immutable, `:37`, non-zero checked `:72`); `routes[tokenIn][tokenOut] => Route{address[11] path; uint256[5][5] swapParams; address[5] pools; bool configured}` (private, `:29-40`).
**Events:** `RouteSet(tokenIn, tokenOut)` `:43`, `Swapped(...)` `:46`.
**New custom errors (additive ABI):** `InvalidRouteEmpty` `:49`, `InvalidRouteEnd(expected, delivered)` `:52`, `InvalidRouteGap(index)` `:55`, `InvalidRouteToken(index)` `:58`, `InvalidRouteSwapParams(hop)` `:61`, `InvalidRoutePools(hop)` `:64`. Function signatures and events are unchanged.

### setRoute validator (`:96-143`): check-by-check verification against Router NG v1.1

| # | Check | Code | Verdict |
|---|---|---|---|
| 1 | `tokenIn != 0`, `tokenOut != 0`, `path[0] == tokenIn` (order preserved per story) | `:103-105` | verified |
| 2 | k = leading hops with `path[2k+1] != 0`, bounded `k < 5` | `:108-109` | verified. Probes indices 1,3,5,7,9 only. `2*4+1 = 9` is the last index, so there is no OOB. |
| 3 | k ≥ 1 | `:111` | verified. Rejects zero-hop, including the zero-hop self-route (test `zeroHopSelfRouteRejected`). |
| 4 | Every entry after the executed prefix is zero, `path[2k+1..10]` | `:113-115` | verified. For k<5 this covers the empty pool slot (zero by definition) plus every trailing token and pool slot. For k=5 the loop is empty and `path[10]` is the delivered token. **Trailing-slot zero padding is fully enforced.** |
| 5 | Executed intermediate tokens `path[2i]`, `0<i<k`, are non-zero | `:117-119` | verified. `path[0]` is non-zero by check 1. `path[2k]` is non-zero because it must equal non-zero `tokenOut` (check 6). So every executed token slot is non-zero. |
| 6 | `path[2k] == tokenOut` | `:120-121` | verified. The delivered token equals the router's actual stop-at-first-gap output token. **The M-01 gapped route `[USDe,pool,crvUSD,0,…,sUSDe]` is now rejected** (by check 4, `InvalidRouteGap(10)`). |
| 7 | Executed rows `h<k`: `swap_type != 0 && != 9` | `:125-127` | verified for {0,9}. **Values ≥ 10 are accepted** (LOCAL-002). `i`, `j`, `pool_type` and `n_coins` of executed rows are not validated. |
| 8 | Unexecuted rows `h≥k` all-zero; unexecuted `pools[h] == 0` | `:128-133` | verified. Executed-hop `pools[h]` is unconstrained by design (meta-swap base pools). |
| 9 | A rejected call does not overwrite a stored route | revert-before-write `:136-140` | verified. Pinned by test `gappedRouteDoesNotOverwriteValidRoute`. |

**Questions from the brief:**
- *Is the contiguity rule fully enforced (11-slot path, swap_params, pools, hop count, zero gaps, trailing padding)?* **Yes**, for the structural rule Router NG uses to pick hops and the delivered token. The executed prefix, the delivered token, the unexecuted rows/pools and the trailing padding are all pinned exactly.
- *Is tokenIn==tokenOut rejected only via k≥1, and is that sufficient?* **No, it is not sufficient.** k≥1 only kills the zero-hop no-op. A cyclic route `A→P1→B→P2→A` (k=2), or a 1-hop `[A,P1,A]` with `i==j`, passes `setRoute(A,A,…)`. Because `routes[A][A]` is both the forward and the reverse slot, one call also satisfies the bidirectional gate (`isPairFullyConfigured(A,A) == true`). Confirmed by probe tests 1 and 2. The story allowed "k ≥ 1 (and/or tokenIn != tokenOut)", so the implementation is story-conformant. The explicit `tokenIn != tokenOut` guard that ledger L-07 asks for is still absent. → LOCAL-001 (residual of L-07).
- *Are both directions / the bidirectional requirement validated?* Each direction is validated independently at `setRoute`. Bidirectionality is enforced only at `swap` time (`:180-182`). Nothing checks that the reverse route is a structural mirror (same pools reversed, swapped i/j). Different pools per direction are legitimate, so this is a trust note, not a finding. The self-pair degenerate case is covered by LOCAL-001.
- *Are route tokens consistent with swap_params?* **Not validated on-chain**, and it cannot be without calling `pool.coins(i/j)`. A wrong `i`/`j` stores a structurally valid route whose pool emits a different coin than `path[2h+2]`. Router NG accounts by the output token's balance (likely; not re-verified against router bytecode this run), so a mismatch shows up as an `_expected` revert at swap time. When minOut == 0 it can also strand coin j in the router. Off-chain verification only (trust assumption T-3). This is the same residual as the "relies entirely on off-chain verification" half of L-07.
- *Does swap() re-check amountOut?* **No.** `swap` (`:174-195`) is byte-unchanged by story-052. It returns `router.exchange(...)` (`:192`) with no balance-delta measurement at `msg.sender` and no `amountOut >= minAmountOut` check. **Ledger L-12 `6e771a84e82d` stays open.**

### Local findings

- **LOCAL-001 — `setRoute` still accepts `tokenIn == tokenOut` with ≥1 hop. A single call configures a self-pair that trivially satisfies the bidirectional gate.** `CurveAMMAdapter.sol:103-121` (no `tokenIn != tokenOut` check), `:169-171`/`:180-182` (the same mapping slot serves forward and reverse). Probe tests `test_cyclicSelfPairAcceptedAndSelfSatisfiesBidirectional` and `test_oneHopSelfPairSameIndexAccepted` PASS. Impact is local and small. No strategy calls `swap(x,x,…)`, because `vault != underlyingToken`. A permissionless caller who uses it only round-trips its own funds. This is the unremediated half of **L-07 `b28e77daefb3`**. Recommend reconciling it as L-07 *partially fixed*: the zero-gap half is fixed, the tokenIn==tokenOut half remains. It should not get a new fingerprint. Suggested severity: **QA/Low**. Fix: `if (tokenIn == tokenOut) revert …` after `:104`.
- **LOCAL-002 — The swap_type validator is a denylist {0, 9}, not the Router NG v1.1 allowlist {1..8}.** `CurveAMMAdapter.sol:126-127`. `swap_type` 10 and `type(uint256).max` are accepted and stored (probe `test_swapTypeAboveNineAccepted` PASS). Router NG v1.1 dispatches 1-8 and raises "Bad swap type" otherwise (likely; the NatSpec at `:91-92` and ICurveRouterNG `:19-20` assert only 0/9). The result is a stored route that reverts on every `swap`. That freezes the strategy's deposit, withdraw and skim paths until the owner overwrites the route with `setRoute`, which is recoverable since there is no `clearRoute` lock-in. This is an owner-authored misconfig, but the validator's NatSpec reads as if swap_type validity is enforced, so it is a mild footgun. It is the direct analogue of sya-harvester run-02 L-05 (swap_type ≥ 9), which the owner rated QA. Suggested severity: **QA**. Fix: `if (swapType == 0 || swapType > 8) revert`.
- (No other local findings. Loops are constant-bounded: ≤5, ≤11, 5×5. Access control is complete on the only mutator.)

### Verified local properties

| Property | Status | Evidence |
|---|---|---|
| noUnboundedLoops | verified | `:109`, `:113`, `:117`, `:124-134`: constant bounds |
| checkedArithmetic | verified | 0.8.x, no `unchecked`/assembly. `2*k+1 ≤ 11` |
| accessControlled | verified | `setRoute` onlyOwner `:102`; `swap` permissionless by design |
| reentrancyGuarded | none (n/a) | `swap` holds no balance across calls; exact-amount `forceApprove` `:189` |
| initializerProtected | n/a | constructor-only |
| contiguity enforced (Router NG stop-at-first-gap) | verified | checks 2-6, 8 |
| tokenIn != tokenOut | **violated** | LOCAL-001 |
| swap_type allowlist | **violated** | LOCAL-002 (denylist only) |
| swap_params i/j ↔ path token consistency | unverified | not checkable on-chain. T-3 |
| amountOut re-check in swap | **absent** | L-12 open, `:192` |
| weak randomness | verified absent | — |
| inbound callbacks | none | plain ERC20 via SafeERC20; no 721/1155/777 hooks |

### Interface abstraction

| Entry point | Access | State | External calls | Guard |
|---|---|---|---|---|
| `setRoute(address,address,address[11],uint256[5][5],address[5])` | onlyOwner | `routes[in][out]` (overwrite; no clear) | none | — |
| `getRoute(address,address)` view | none | — | — | — |
| `isPairFullyConfigured(address,address)` view | none | — | — | — |
| `swap(tokenIn,tokenOut,amountIn,minAmountOut)` | **none** | none persistent | `IERC20(tokenIn).safeTransferFrom(msg.sender)` `:186`; `forceApprove(router, amountIn)` `:189`; `router.exchange(..., receiver=msg.sender)` `:192` | none |
| inherited `transferOwnership`/`renounceOwnership` | onlyOwner | owner | — | — |

External calls: `router` (Curve Router NG, semi-trusted, immutable). `tokenIn` (semi-trusted ERC20, chosen by caller but must have a configured route).

### Trust assumptions
- T-1: The router is genuine Curve Router NG v1.1 and enforces `_expected` internally (L-12 depends on this).
- T-2: Owner-authored routes are correct beyond structure. Pool addresses, coin indices, pool_type and n_coins are verified off-chain.
- T-3: Route tokens match pool coins at indices i/j. Not validated on-chain.
- T-4 (deployment, footgun carried from run-context/story-052): the **live mainnet adapter `0x2D02…D6f` predates this validator**. It is immutable, not a proxy, and is held as immutable `ammAdapter` by `YieldStrategyUSDe`. Any owner `setRoute` there runs the old weak "last non-zero == tokenOut" check, so an M-01 gapped route could still be stored on mainnet. Its current routes are valid. Documented and deliberate (story-052 Concerns; vault CLAUDE.md). Downstream should surface it as an operational hazard: check routes off-chain against the new rule before any mainnet `setRoute`.

---

## 2. `src/AMMAdapters/ICurveRouterNG.sol` (CHANGED, +6 NatSpec only)
Only lines `:16-20` were added: NatSpec on stop-at-first-gap semantics, plus the revert note "swap_type 0 or 9 … Bad swap type". `exchange` signature `:33-40` is unchanged, `payable`. Note: the NatSpec states only the 0/9 cases. See LOCAL-002 for values ≥ 10. No local findings.

## 3. `src/AMMAdapters/IAMMAdapter.sol` (UNCHANGED)
Run-17 §5 carries forward. Single non-view `swap`; no quote member.

---

## 4. `src/interfaces/IYieldStrategy.sol` (CHANGED, −50)
Removes `previewExitFor(address,address,uint256) view returns (uint256,uint256)` (selector removed from the ABI). Byte-identical to `0110ce4`. All remaining members are unchanged (`:24-152`). No sibling repo consumes the removed member (grep, top-level `src/` only, `lib/` excluded). Any off-chain or UI caller of the selector would now revert on the selector miss. None is known; run-17 H-6 had already established zero consumers. No local findings.

## 5. `src/AYieldStrategy.sol` (CHANGED, −33)
Removes the base `previewExitFor` default (old `:571-583`). Byte-identical to `0110ce4`. Run-17 §2 tables carry forward unchanged **minus the `previewExitFor` row**: state variables, access control, nonReentrant coverage (`deposit :591`, `withdraw :609`, `depositAsOwner :627`, `withdrawAsOwner :644`, `relinquish* :649/:654`, `totalWithdrawal :417`, `skimSurplus :461`; `emergencyWithdraw :402` is unguarded, onlyOwner, pre-existing), and the `totalDeposited == Σ clientBalances` invariant (verified). Line numbers shift by −33 after old `:549`: `_withdrawInternal` is now `:732`, `_disposeShares` hook `:790`. No local findings.

## 6. `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (CHANGED, −78)
Removes `_exitFloor` (old `:129-137`), the `previewExitFor` override (old `:162-186`) and the `Math` import. There are **no leftover references**.
- `_disposeShares` (`:158-180`) is **unchanged**: `sharesToSell = min(convertToShares(amount), balanceOf(this))`; `minOut = convertToAssets(sharesToSell) * (MAX_BPS - bps) / MAX_BPS`; `ammAdapter.swap(vault, underlying, sharesToSell, minOut)`; `safeTransfer(recipient, underlyingReceived)` with the adapter's *returned* amount (couples to L-12). The removal changed no minOut semantics. minOut is still derived from live vault state at execution, and `slippageToleranceBps == MAX_BPS` still yields minOut 0 (run-17 H-8 footgun persists).
- `_acquireShares :123-147`, `_totalWithdraw :209-240`, `_skimSurplus :254-296` (+ helpers `:310-369`) are unchanged.
- External calls and trust: run-17 §3 carries forward (vault semi-trusted, `asset()==underlying` unchecked; adapter semi-trusted; no inbound callbacks).
- **Ledger reconciliation hints (proposals only; humans apply):** every finding whose `function` is `previewExitFor` (L-18, L-19, L-21, L-24, L-26, QA-10, QA-11, INFO-01) or `_exitFloor` (L-20 `6f57473e6b01`) now targets deleted code, so they are fixed-by-removal candidates. **L-22 `7a66fe7d5a96`** ("quoted floor not honoured", function `_disposeShares`) has lost its premise because no quote exists any more. `_disposeShares` survives unchanged, but the defect as titled needs the quote. Propose closing it as obsolete/fixed-by-removal. If the scanners re-raise the bare live-state-minOut behaviour, it is a different root cause and needs a fresh entry with disclosure. L-23/L-25/L-27/L-28/L-29/QA-12 cover untouched functions and stay as they are.
- No new local findings.

## 7. `src/concreteYieldStrategies/ERC4626YieldStrategy.sol` (UNCHANGED)
Not in the diff. It never overrode `previewExitFor`, so the inherited member just disappears with the base. Run-17 §4 carries forward minus the preview discussion (`_disposeShares` is still no-minOut `vault.redeem`; QA-12 raw approve in the constructor stays open). No refresh needed.

---

## 8. Complexity (HEAD)

| File | LOC | Ext/pub fns | Ext call sites | State vars |
|---|---|---|---|---|
| AYieldStrategy.sol | 885 | 25 | via hooks | 8 (+3 const) |
| ERC4626MarketYieldStrategy.sol | 370 | 2 own (+inherited) | vault ~10, adapter ×3, token transfers | 3 (+1 const) |
| ERC4626YieldStrategy.sol | 327 | 4 own | vault ~10 | 1 |
| CurveAMMAdapter.sol | 196 | 4 (+Ownable) | router ×1, token ×2 | 2 |
| IYieldStrategy / IAMMAdapter / ICurveRouterNG | 153 / 23 / 41 | interfaces | — | — |

## 9. Hand-offs to interaction scanners (not adjudicated here)
- H-A: `_disposeShares`/`_skimSurplus` minOut comes from live `vault.convertToAssets`. Check whether a cheap vault-rate move (e.g. a donation on the target vault) inflates minOut into a forced-revert DoS on withdraw/skim. This needs the vault implementation, so it belongs to cross-contract analysis.
- H-B: L-12 coupling. `_disposeShares :177` and `_skimSurplus` forward the adapter's *returned* amount, not a measured balance delta. If the router's return value and the delivered amount ever diverge, the result is a revert (over-report) or orphaned underlying in the strategy (under-report).
- H-C: T-4 mainnet adapter divergence. Any phStaging2 script that calls `setRoute` on `0x2D02…D6f` should be checked against the new rule.
