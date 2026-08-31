# Contract Profiles — reflax-yield-vault @ 2306719 (run 12, cold scan)

Local-analysis profiles. Downstream agents may treat the "verified properties"
and "principal accounting invariant" as axioms; everything under
**Scanner attention** is deliberately *deferred* to interaction / econ scanners
(cross-contract or AMM-vs-vault-rate exploitability is out of local scope).

| Profile | Contract | Role |
|---|---|---|
| `ERC4626MarketYieldStrategy.profile.json` | `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` | PRIMARY (full) |
| `CurveAMMAdapter.profile.json` | `src/AMMAdapters/CurveAMMAdapter.sol` | PRIMARY (full) |
| `AYieldStrategy.supporting.profile.json` | `src/AYieldStrategy.sol` | base class (supporting) |
| `interfaces.light.profile.json` | IAMMAdapter, ICurveRouterNG, IYieldStrategy, IPausable | interfaces (light) |

## System shape

```
client/owner --underlying--> ERC4626MarketYieldStrategy --underlying--> CurveAMMAdapter --> Curve Router NG
       ^                              | holds VAULT SHARES (sUSDe)            (0x16C652...5353, TRUSTED)
       |                              v
   recipient <----underlying---- swap shares->underlying (withdraw / skim / migrate)
```

- The strategy never deposits into the ERC4626 vault directly; it **buys/sells the
  vault's share token on Curve** to dodge withdrawal restrictions (sUSDe 7-day cooldown).
- Single underlying per deployment (immutable). One AMM adapter (immutable). One Curve router (immutable).
- `AMMRoutes.json` supplies the USDe<->sUSDe Curve RouterNG routes (both directions,
  `swapParams` forward `[0,1,1,10,2]` / reverse `[1,0,1,10,2]`) used by deploy scripts to call `setRoute`.

## Key functions & value flows

- **deposit / depositAsOwner** — pull `amount` underlying, swap ALL to shares,
  credit **haircut** principal `amount*(MAX_BPS-slip)/MAX_BPS`; `minOut=convertToShares(creditedPrincipal)`.
  Returns creditedPrincipal (story-044). Surplus over haircut becomes protocol yield.
- **withdraw / withdrawAsOwner** — `sharesToSell=convertToShares(amount)` (capped to held shares),
  swap to underlying, send **actual** `underlyingReceived` to recipient, debit principal by the
  **REQUESTED** amount (design decision: shortfall accrues as protocol yield).
- **skimSurplus** (base, authorized withdrawer) — snapshot total value at the vault rate, sum per-client
  floored surplus shares, **loud aggregate-surplus ceiling** (M-01 fix), single swap, fast-path to
  recipient or buffered split. Principal untouched.
- **emergencyWithdraw** (owner) — transfers **raw shares** to owner, no swap, **no principal update**.
- **totalWithdrawal** (owner, two-phase 24h+48h) — proportional shares -> swap -> underlying to owner, zero client.
- **CurveAMMAdapter.swap** (permissionless) — pull amountIn, `forceApprove` router, `router.exchange`
  with `receiver=msg.sender`; stateless conduit. **Bidirectional invariant**: reverts unless BOTH
  directions configured.

## Verified local properties (axioms for downstream)

- Principal ledger invariant: `sum(clientBalances) == totalDeposited` (deposit/withdraw/totalWithdraw preserve it; skim & emergencyWithdraw do not touch it).
- Checked arithmetic throughout (0.8.x, no `unchecked`, no assembly).
- Reentrancy guards on all value-moving entrypoints except owner-only `emergencyWithdraw` (which only moves shares to the owner).
- `skimSurplus` client list is read from the on-chain `EnumerableSet`, not caller-supplied → structural fix for the M-01 duplicate over-skim.
- CurveAMMAdapter holds no persistent funds; output is routed straight to the caller.

## Fragile / scanner-attention (deferred exploitability)

1. **Vault-rate vs AMM-realizable-rate divergence (highest-value lead).** `minOut`,
   `totalBalanceOf`, surplus, and the "solvency invariant" are all denominated at the
   **vault rate** (`convertToAssets/Shares`), but funds are only realized at the **AMM
   (Curve) rate**. For sUSDe the Curve price can sit *below* cooldown-redeem fair value,
   so snapshots can overstate what a skim/withdraw actually realizes. → econ-scanner.
2. **Withdraw upside is uncapped (LOCAL-MKT-002, local-high).** Recipient gets the full
   `underlyingReceived` while principal is debited only by `amount`; `minOut` floors the
   downside but nothing caps the upside, so favorable AMM execution lets a withdrawer
   capture yield/other-clients' value that should route through `skimSurplus`. → econ/interaction.
3. **emergencyWithdraw share/principal desync (LOCAL-MKT-003, local-medium).** Shares leave,
   principal ledger stays → `totalBalanceOf` overstates and later withdrawers are clamped on a
   shrunken share pool (first-come drain). Owner-emergency footgun. → interaction (downstream reaction).
4. **Default `slippageToleranceBps == 0` is a deposit/withdraw DoS (LOCAL-MKT-001, local-medium).**
   At 0, `minOut` demands full vault-rate output the AMM won't give → all deposits/withdraws revert
   until owner sets a sane slippage. Non-obvious deploy-time footgun.
5. **Solvency-invariant rounding dust (LOCAL-MKT-004, local-low).** ERC4626 double round-down can put
   `convertToAssets(convertToShares(credited))` just below credited; accumulates on flat markets.
6. **CEI-after-external (LOCAL-MKT-005, local-low).** Principal updated after swap/transfer; safe only
   under nonReentrant + the standard non-hooked/non-FoT ERC20 assumption.
7. **Curve route config is endpoint-validated only (LOCAL-CRV-001/002, local-low).** `setRoute` checks
   `path[0]`/last-token, not `swapParams`/pools/coin-indices or reverse-route *inverse consistency*;
   `isPairFullyConfigured` checks only the `.configured` flag of the reverse. Misconfig misroutes one
   direction. Owner-trusted off-chain; cross-check against `AMMRoutes.json`. No token-rescue function.
8. **Unit mismatch (LOCAL-BASE-001, local-low).** `setAsideBufferSize` is percent (0–100);
   `slippageToleranceBps` is bps (0–10000).

## Trust assumptions (registry-aligned, treat as given)

- Standard non-fee-on-transfer ERC20 (USDe/sUSDe).
- Curve Router NG @ `0x16C6521Dff6baB339122a0FE25a9116693265353` is trusted (honors `minOut`, reports true output).
- ERC4626 vault share price only rises or stays flat — **no rebasing, no loss events** (a drop breaks the solvency invariant).
- Owner non-malicious; configures slippage, routes, clients, buffers correctly.
- Principal is decremented by the **requested** amount, not received (intended; shortfall = protocol yield).
- Bidirectional Curve route invariant assumed honored by deploy scripts / `AMMRoutes.json`.
