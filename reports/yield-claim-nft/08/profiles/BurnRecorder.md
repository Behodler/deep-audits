# Profile: src/BurnRecorder.sol  (CONTEXT, shared by V1+V2 Burners)

- ^0.8.20 | IBurnRecorder, Ownable

## Verified Local Properties
- accessControlled: setBurner/registerToken (onlyOwner), burn (onlyBurner). checkedArithmetic (0.8.20). noUnboundedLoops.
- `burn(token,amount)`: totalBurnt[token]+=amount; emits tokenBurnt. Pure accounting, no token movement (the actual burn happens in the calling dispatcher).
- registerToken/getTokenAtIndex are enumeration helpers; registerToken does not dedupe (same token can be registered twice at different indexes) — cosmetic, no security impact.

## Local Findings
- None of HM severity. registerToken duplicate-allow is QA at most.

## Interface Abstraction
- `burn(address token, uint256 amount) onlyBurner` — accumulate + event.
- `setBurner(addr,bool) onlyOwner`, `registerToken(addr) onlyOwner`.
- views: getTotalBurnt, getTokenCount, getTokenAtIndex.

## Trust Assumptions
- Owner authorizes burner contracts (Burner / BurnerV2). It is purely a logging/accounting ledger; no funds. Mis-set burners only corrupt the off-chain-readable totals. Owner trusted (OOS).
