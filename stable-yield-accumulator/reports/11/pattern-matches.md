# Pattern Matches — StableYieldAccumulator

- **Project:** stable-yield-accumulator
- **Target:** `lib/stable-yield-accumulator/src/StableYieldAccumulator.sol` @ 71abe3e
- **Scan type:** pattern-matching (historical vulnerability DB)
- **Patterns checked:** 22
- **Date:** 2026-05-27

> Confidence reflects how well the contract matches a *known pattern signature* and whether
> mitigations are present. These feed later LLM reasoning (code-scanner / econ-scanner), NOT
> the final report. A HIGH here means "worth a focused look", not "confirmed bug".

---

## Findings (medium/high confidence — flagged for review)

### PM-01 — DIVISION-PRECISION / Rounding-direction (decimal normalization) — MED
- **Pattern:** DIVISION-PRECISION (arithmetic, MEDIUM) + class-specific rounding-direction.
- **Where:** `_normalizeAmount` L586-609, `_denormalizeAmount` L617-640, `claim()` L497-498, `calculateClaimAmount` L684-687.
- **Rationale:** Round-trip normalize→discount→denormalize uses truncating integer division in several places:
  `discount` is `totalNormalizedYield * (10000 - discountRate) / 10000` (L497/684); `_denormalizeAmount` does
  `scaled * 1e18 / exchangeRate` then `scaled / 10**(18-decimals)` (L629, L634). When `rewardToken` has 6 decimals
  (USDC), denormalizing from 18→6 floors away up to ~1e12 wei of normalized value per claim. Direction question:
  does the claimer pay *less* than the yield they extract (rounds in claimer's favor, value leak to claimer) — the
  yield is summed at 18-dp precision but the payment is floored to reward-token dp. Worth a focused conservation check.
- **Mitigation present:** `minRewardTokenSupplied` slippage param protects the *claimer*, not the protocol. No
  round-up-on-payment. NOT a full mitigation against protocol-side leak.
- **Confidence:** MED — signature matches (div in fee/scale math), but exploitability depends on magnitudes; hand-off to econ-scanner.

### PM-02 — FIRST-DEPOSITOR-ATTACK / ERC4626-INFLATION (analog) — LOW→MED (FLAG, likely N/A)
- **Pattern:** FIRST-DEPOSITOR-ATTACK (economic, HIGH) / ERC4626-INFLATION.
- **Where:** claim/yield accounting, `_getYieldForStrategy` L552-564, `claim()` L460-494.
- **Rationale:** Contract is NOT an ERC4626 share vault — there is no share token, no `totalSupply()`, no
  mint-on-deposit, no exchange rate derived from `assets/supply`. Yield is read directly from each strategy
  (`totalBalanceOf - principalOf`). The classic inflation/first-depositor signatures (`totalSupply()==0`,
  `shares = assets*supply/assets`) are **absent**. So the canonical pattern does not apply. The *donation* angle
  that could still matter: an attacker can `transfer` underlying directly into a strategy to inflate
  `totalBalanceOf` (surplus), but the donated value is paid out to the claimer 1:1 via `skimSurplus`, so it is
  self-funded grief at best — push to econ-scanner, not a share-inflation match.
- **Confidence:** LOW that the DB pattern matches; recorded as a FLAG so reasoning agents don't re-derive it.

### PM-03 — DOS-UNBOUNDED-LOOP — MED
- **Pattern:** DOS-UNBOUNDED-LOOP (dos, MEDIUM).
- **Where:** `claim()` outer loop over `yieldStrategies` L464 with nested loop over `exemptStrategies` L473
  (O(n*m)); `removeYieldStrategy` L247; `calculateClaimAmount` L659/L667; `getTotalYield` L740;
  `_getYieldForStrategy` loops `getAuthorizedClients()` L556; `canClaim` loops `1..nextIndex()` L706.
- **Rationale:** `yieldStrategies` and each strategy's authorized-clients list are owner/strategy-grown and unbounded.
  `claim()` iterates ALL strategies × ALL clients × exempt list every call; if these grow large, claim can exceed
  block gas → claims become un-callable (availability DoS). `canClaim` iterates all NFT indices and is a view (bot
  helper) so lower impact, but still unbounded.
- **Mitigation present:** strategy count is owner-curated (small N expected), and `exemptStrategies` lets callers
  route around a single bad strategy — but does not bound total iteration cost.
- **Confidence:** MED — signature matches strongly; impact gated on real-world list sizes. Flag for code-scanner.

### PM-04 — CENTRALIZATION-ADMin — LOW (QA expected)
- **Pattern:** CENTRALIZATION-ADMIN (centralization, LOW).
- **Where:** `onlyOwner` on `setTokenConfig` L280 (decimals + exchangeRate), `setDiscountRate` L324,
  `addYieldStrategy`/`removeYieldStrategy` L227/L243, `setPhlimbo` L348, `setRewardToken` L360, `setNudge*`
  L385/L396, `setNFTMinter` L414, `approvePhlimbo` L369; single `owner` (OZ Ownable, no timelock/multisig in-contract).
- **Rationale:** Owner sets `normalizedExchangeRate` and `decimals` arbitrarily (the de-facto price oracle, no bounds
  beyond `decimals<=18`), can repoint `rewardToken`/`phlimbo`/`nudge`, and can set `discountRate` up to 100%
  (L325 allows `rate == 10000`, i.e. claimers pay 0). This is the design ("owner can adjust for permanent depegs")
  so per CLAUDE.md it is QA/Low unless it enables theft. Note for econ-scanner: malicious/compromised owner can set
  `exchangeRate` very low or `discountRate=10000` to let a claimer drain all strategy surplus for ~nothing —
  borderline rug vector, flag for plausibility review.
- **Mitigation present:** Behodler3 pause redundancy; pauser can halt claims. No timelock.
- **Confidence:** LOW (standard centralization) but the depeg-rate / 100%-discount lever is worth an econ look.

### PM-05 — RETURN-VALUE-IGNORE / ERC20 no-return (USDT) — LOW (mitigated)
- **Pattern:** RETURN-VALUE-IGNORE (code-quality, MEDIUM).
- **Where:** token transfers in `claim()` L509/L516, `approvePhlimbo` L373.
- **Rationale:** Contract uses `SafeERC20` (`safeTransferFrom`/`safeTransfer`/`forceApprove`, L58 `using SafeERC20`),
  which handles USDT-style non-returning tokens correctly. `IPhlimbo(phlimbo).collectReward` L519 is a pull where
  SYA pre-approves via `approvePhlimbo` — not a raw transfer. Pattern is effectively mitigated.
- **Mitigation present:** SafeERC20 throughout. **Skip** unless a raw `.transfer`/`.call` surfaces elsewhere (none found).
- **Confidence:** LOW (no live match) — recorded as cleared.

---

## Reentrancy assessment (REENTRANCY-ERC777) — cleared, MED→LOW

- **Pattern:** REENTRANCY-ERC777 (reentrancy, HIGH).
- **Where:** `claim()` makes multiple external calls: `_validateAndBurnNFT` (ERC1155 `burn`, has a receiver-hook
  surface) L458/L536, `skimSurplus` (sends tokens to `msg.sender`) L484, `safeTransferFrom` L509, `safeTransfer` to
  `nudge` L516, `collectReward` L519.
- **Rationale:** `claim()` carries `nonReentrant` (L447) AND `whenNotPaused`. The ERC1155 burn and the
  token-out callbacks (ERC777/ERC1155 receiver hooks) are exactly the REENTRANCY-ERC777 surface, BUT the guard
  blocks re-entry into `claim`. Residual risk = cross-function reentrancy into *other* non-guarded state-changers
  during a callback — but all the other state-mutating externals are `onlyOwner`/`onlyPauser`, not reachable by the
  claimer mid-callback. State updates inside `claim` are local accumulators, not persistent balances that a reentrant
  call could double-spend. **Pattern signature matches but mitigation (nonReentrant) is present.**
- **Confidence:** LOW that an exploitable reentrancy exists; MED that it deserves a confirmatory read by code-scanner
  given the number of external callbacks in one function. Flagged, not asserted.

---

## Patterns checked and ruled out (no match)

| Pattern | Verdict | Why |
|---|---|---|
| ERC4626-INFLATION | N/A | No share token / `totalSupply` / share mint; not a 4626 vault (see PM-02). |
| ORACLE-STALE | N/A | No oracle; 1:1 rates by design, owner-set. No `latestRoundData`/`AggregatorV3`. |
| ORACLE-ROUNDID | N/A | Same — no Chainlink. |
| SIGNATURE-REPLAY | N/A | No `ecrecover`/`ECDSA`/EIP-712 signatures anywhere. |
| FRONTRUN-APPROVE | N/A | Only `forceApprove` (owner→phlimbo); no user approve race in-contract. KNOWN-INVALID class anyway. |
| FLASH-LOAN-PRICE | N/A | No spot-price/reserves read; rates are config, not pool-derived. (Note: an external ClaimArbitrage consumer uses flash loans, but that is OOS — per-repo scope.) |
| UNSAFE-DOWNCAST | N/A | No narrowing casts; `decimals` is `uint8` from config, all math in `uint256`. |
| UNPROTECTED-INIT | N/A | No initializer/proxy; constructor-based (`Ownable(msg.sender)`), non-upgradeable. |
| STORAGE-COLLISION | N/A | No `delegatecall`/proxy. |
| MISSING-SLIPPAGE | N/A (cleared) | `claim` exposes `minRewardTokenSupplied` (L443, L501) — slippage protection present. |
| SELFDESTRUCT-FORCE-ETH | N/A | No `address(this).balance` logic; not payable. |
| DOUBLE-VOTING | N/A | No governance/voting. |
| PERMIT-FRONTRUN | N/A | No `permit`. |
| INCORRECT-OPERATOR | LOW/info | `setDiscountRate` allows `rate == 10000` (`> 10000` reverts, L325) → 100% discount permitted; `nudgeSplit` allows `==100` (L397). Likely intentional bounds; noted for code-scanner, not flagged as a match. |
| CROSS-CHAIN-REPLAY | N/A | No bridge/`chainid`/LZ/CCIP. |
| TIMELOCK-BYPASS | N/A | No timelock in-contract. |

---

## Summary for downstream agents

- **Highest-value flags:** PM-01 (rounding-direction / decimal round-trip conservation in claim payment vs. yield
  delivered) and PM-03 (unbounded-loop DoS in `claim`). Both MED.
- **Econ-scanner hand-offs:** PM-01 (does claimer underpay vs. extracted surplus?), PM-04 (owner depeg-rate /
  100%-discount lever as rug vector — plausibility), PM-02 (direct-donation surplus grief, self-funded).
- **Cleared with mitigation:** reentrancy (nonReentrant), missing-slippage (minRewardTokenSupplied), ERC20 no-return
  (SafeERC20). Fee-on-transfer remains a KNOWN-INVALID exclusion unless explicitly in scope.
- This contract is an accumulator/claim router, NOT an ERC4626 share vault — first-depositor/inflation share patterns
  do not structurally apply.
