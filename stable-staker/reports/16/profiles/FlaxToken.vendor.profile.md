# Profile: src/versions/v1/vendor/FlaxToken.sol + IFlax.sol (NEW first-party) @ fa06de5

Vendored by story-024 from `Behodler/flax-token-v2@f5300117e94bd30349fb88f426d434ef1ccddce0`,
replacing the deleted `lib/flax-token` submodule. Remapping `flax-token/=src/versions/v1/vendor/`
(remappings.txt:3, foundry.toml:25) keeps every import site — including the two hash-pinned frozen
V1 files — byte-unchanged.

## (c) Diff against the deleted upstream — **VERIFIED IDENTICAL**

The old submodule pointer is recoverable: `git ls-tree 2146428 lib/flax-token` →
`f5300117e94bd30349fb88f426d434ef1ccddce0`, exactly the commit the vendored header claims, and the
checkout is still present locally. Stripping only the inserted header comment block:

```
diff vendored/FlaxToken.sol  upstream/src/FlaxToken.sol  → only "\ No newline at end of file"
diff vendored/IFlax.sol      upstream/src/IFlax.sol      → only "\ No newline at end of file"
```

**No behavioural difference whatsoever.** Specifically unchanged: mint authorization
(`_authorizedMinters[msg.sender].canMint` + `mintVersion` match, :333-344), `setMinter` onlyOwner
:319, `revokeAllMintPrivileges` version bump :363, allowance-based `burn` :352, ERC20 name/symbol
`("Phoenix USD","phUSD")` :308, decimals (inherited OZ default 18, no override), no hooks, no
transfer restrictions, no supply cap, zero initial supply, pragma `^0.8.13`.

Status: **VERIFIED**, not UNABLE-TO-COMPARE.

## Interface abstraction (FlaxToken)

| Function | Access | Writes |
|---|---|---|
| `setMinter(minter,canMint)` | onlyOwner | `_authorizedMinters[minter]` |
| `mint(recipient,amount)` | authorized minter at current `mintVersion` | ERC20 supply/balance |
| `burn(holder,amount)` | anyone with allowance over `holder` | allowance, supply/balance |
| `revokeAllMintPrivileges()` | onlyOwner | `mintVersion++` (mass revocation) |
| `transferOwnership` / `renounceOwnership` | onlyOwner | `_owner` |
| views | `mintVersion`, `authorizedMinters`, `name`, `symbol`, `decimals`, `owner`, full ERC20 |

Properties: no loops; checked arithmetic (0.8.x); no reentrancy surface (no external calls beyond
OZ ERC20 internals); no initializer; no pause. `burn` deliberately allowance-gated, which is the
phUSD redemption/annihilation surface used by `PhusdStableMinter`.

## Local findings

**LOCAL-V01 — duplicate `FlaxToken` artifact in the build (QA / build hazard).** `flax-token/`
now resolves to `src/versions/v1/vendor/` while `@phUSD/` resolves to
`lib/antimatter/lib/flax-token-v2/src/` (remappings.txt:3 and :7). Both currently hash-identical
(`80a31efb…` / `d8d0f908…`, same commit `f5300117`), so `forge build` produces two `FlaxToken`
artifacts with the same contract name from different paths. Consequences: (i) any
`vm.getCode("FlaxToken.sol")` / artifact-by-name lookup becomes ambiguous, and (ii) a future
`lib/antimatter` submodule bump silently drifts the two copies apart with no CI check —
`.github/scripts/check-migration-surface.sh` asserts `FROZEN.sha256` holds exactly two entries and
deliberately does NOT pin the vendored pair (stated in the file header itself). Recommend pinning
the vendored copies' hashes in CI, or asserting they equal the `@phUSD/` copies.

**Not a finding:** the vendored files being under `src/` makes them deployable artifacts of this
repo. That is inherent to the vendoring decision and is what lets the frozen V1 snapshot compile.
