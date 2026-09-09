# Context: lib/antimatter @ a5570ce (working tree 3a96fb7) — the new emissions token

NOT in scope (nested dep). Read to establish the load-bearing premise for run-16.

`lib/antimatter/src/Antimatter.sol` — `contract Antimatter is ERC20, Ownable, ReentrancyGuard`,
`ERC20("Antimatter","AM")` :132.

| Property | Answer | Evidence |
|---|---|---|
| Mint authorization | owner OR members of an owner-managed `EnumerableSet` | `onlyApprovedMinters` :125-130, `setApprovedMinter(address,bool)` :164, `mint` :192 |
| Revocation | per-minter only; **no** phUSD-style `mintVersion` mass revocation | :164-168 |
| Supply cap | **NONE** — `_mint` is unbounded | :193 |
| Decimals | **18** (OZ default, no override) | no `decimals()` in the file |
| Transferable | **YES** — plain, unrestricted OZ ERC20; no pause, no allowlist, no hooks | :22 |
| Burnable | yes, self-burn only, inside `annihilate` | :239 |
| **Redeemable** | **YES** | `annihilate` :226-267 |

## (a) THE PREMISE HAS CHANGED — state plainly

phUSD's property that made over-crediting a *minter* economically inert was: mint-on-demand,
authorized minter, **no user redemption path**. **Antimatter does not share that property.**

`Antimatter.annihilate(stable, recipient, amount, minPhUSDOut)` is permissionless and lets any
holder pair `amount` AM (18dp) with the decimal-rescaled equal quantity of a registered stablecoin
and receive **both** halves as phUSD:

```solidity
_burn(msg.sender, amount);                       // :239  the AM half
...
minter.mint(stable, stableAmount);               // :251  stablecoin half -> phUSD, backed
uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;   // :256
uint256 totalPhUSD = amount + mintedForStable;   // :259
_phUSD.mint(recipient, amount);                  // :263  the AM half, minted 1:1, UNBACKED
IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);          // :264
```

Consequences that downstream agents must treat as axioms for this run:

1. **1 AM is a bearer claim on 1e18 phUSD minted with no stablecoin behind it** (:263). The
   stablecoin half at :251 is backed and deposited into a yield strategy; the antimatter half is
   not. Emitting AM is therefore a real dilution liability, not a marketing spend.
2. **AM is freely transferable and has no cap**, so an over-emission is immediately realisable by
   an arbitrary third party — there is no "the minter cannot redeem" cushion.
3. **Therefore every existing ledger suppression whose stated rationale is "the reward token has no
   redemption value / over-crediting the minter is opportunity cost, not loss" is INVALID for
   StableStakerV2 at fa06de5 and must be re-derived, not carried forward.** This includes the
   memory notes *minter-cushion-socialized-losses-intended* and
   *externally-derived-yield-opportunity-cost-not-loss* as applied to V2's reward leg. The frozen
   V1 (which still emits phUSD directly) is unaffected — the premise change is V2-only.
4. `annihilate` requires the caller to bring the matching stablecoin, so the exploit economics are
   "AM holder converts N AM + N stable into 2N phUSD", i.e. AM's marginal value to a holder is up
   to 1 phUSD per AM, capped by the stable minter's exchange rate and the caller's own capital.
   This is a bound to hand econ-scanner, not a claim of free money.
5. Operational: `Antimatter.setApprovedMinter` is the only revocation, and it is per-minter. There
   is no equivalent of `revokeAllMintPrivileges`, so an incident response must enumerate minters.
