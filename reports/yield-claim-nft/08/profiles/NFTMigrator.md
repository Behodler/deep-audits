# Profile: src/V2/NFTMigrator.sol

- solidityVersion: ^0.8.20
- inheritanceChain: Ownable
- LOC: 77 | functions: 5 (constructor, setMapping, setMappings, setInitialized, migrate)
- PRIMARY

## Verified Local Properties
- checkedArithmetic: true (0.8.20).
- accessControlled: setMapping/setMappings/setInitialized (onlyOwner). migrate (permissionless, acts only on caller's own balances).
- reentrancyGuarded: false (no guard). migrate burns then mints; both target trusted V1/V2 contracts.
- `setInitialized` validates every V1 index in [1, v1.nextIndex()) has a non-zero v2 mapping before flipping `initialized`.

## Local Findings

### LOCAL-004 — Unbounded nested loop in migrate(): per-unit mint loop is a gas/DoS risk (local-medium)
- function: migrate (line 62-76)
- Outer loop runs `v1.nextIndex()-1` iterations. Inner loop `for (j=0; j<balance; j++) v2.mintFor(v2Index, msg.sender)` performs ONE `mintFor` external call (with an `_mint` + event) per NFT unit held. A user holding a large ERC1155 balance of any V1 index (balances are uint256, and V1 `mintFor`/mint paths can accumulate large counts) will make `balance` external calls, which can exceed the block gas limit and make migration permanently unexecutable for that user (funds/NFTs strandable in the migration sense — V1 NFTs cannot be converted). ERC1155 semantics mean a single tokenId can legitimately hold a high quantity. There is no batch path (`_mintBatch`) and no cap.
- recommendation: mint the full `balance` in one call (add a quantity-aware mintFor / use ERC1155 `_mint(recipient, id, balance, "")`) instead of looping per unit; or paginate.
- NOTE: exploitability/severity (whether realistic balances reach the gas ceiling) is for severity-classifier; locally this is a confirmable unbounded-loop-over-balance.

### LOCAL-005 — Constructor lacks zero-address validation for v1/v2 (local-low / QA)
- function: constructor (line 25-28)
- `v1` and `v2` set without non-zero checks. Misconfiguration would brick migrate (revert on external call) rather than cause loss. Owner-deployment concern; low.

### LOCAL-006 — migrate() re-burn / double-migration safety (verified OK, note)
- migrate burns the full V1 balance via `v1.burn(msg.sender, i, balance)` before minting, so a second call finds balance==0 and is a no-op. No double-mint within a single sweep. Depends on V1.burn actually reducing balance (trusted V1). Not a finding; recorded as verified property.

## Interface Abstraction
- `migrate() external` — requires `initialized`. For each V1 index i in [1, v1.nextIndex()): reads caller's V1 balance; if >0, `v1.burn(caller, i, balance)` then `balance`× `v2.mintFor(indexMapping[i], caller)`. Permissionless; only affects caller.
- `setMapping(uint256,uint256) onlyOwner`, `setMappings(uint256[],uint256[]) onlyOwner` (length-checked), `setInitialized() onlyOwner`.
- views: v1, v2, initialized, indexMapping.

## External Calls / Trust Boundaries
- `v1.nextIndex()` (view), `IERC1155(v1).balanceOf(caller,i)`, `v1.burn(caller,i,balance)` — V1 NFTMinter (trusted, in-suite). Requires NFTMigrator to be an authorizedBurner on V1.
- `v2.mintFor(v2Index, caller)` — V2 NFTMinterV2 (trusted). Requires NFTMigrator to be an authorizedMinter on V2.

## Trust Assumptions
- Owner configures mappings and calls setInitialized exactly once (initialized is one-way to true; no un-set). After init, NEW V1 indexes registered later are NOT validated to have a mapping — migrate would map them to indexMapping[i]==0 and call `v2.mintFor(0, ...)`, which reverts (index 0 unregistered), bricking migrate for any user holding such a newly-added V1 index. DOWNSTREAM: interaction scanner should note the ordering coupling between V1 dispatcher registration and migrator initialization.
- NFTMigrator must hold authorizedBurner (V1) and authorizedMinter (V2). Roles granted by respective owners.
