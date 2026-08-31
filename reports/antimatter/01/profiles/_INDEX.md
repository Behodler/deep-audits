# antimatter-01 — contract profiles

COLD scan. Target read-only tree: `/home/justin/code/audits/lib/antimatter` @ `0bb82d8` ("annihilate").

| File | Subject | Kind |
|---|---|---|
| `Antimatter.json` | `src/Antimatter.sol` | Full local profile — first-party, in scope |
| `PhusdStableMinter.json` | `lib/phUSD-stable-minter/src/PhusdStableMinter.sol` | Interface abstraction — trust boundary |
| `FlaxToken-phUSD.json` | `lib/flax-token-v2/src/{FlaxToken,IFlax}.sol` | Interface abstraction — trust boundary |
| `IYieldStrategy.json` | `.../vault/src/interfaces/IYieldStrategy.sol` | Interface abstraction — trust boundary, BRANCH PIN |

## Tree provenance (read this before making any cross-repo claim)

`ls /home/justin/code/audits/lib` lists: antimatter, forge-std, openzeppelin-contracts, phlimbo-ea,
phoenix-nft-staking, phoenix-phase-2-staging, reflax-yield-vault, stable-staker,
stable-yield-accumulator, yield-claim-nft.

There is **no** top-level `lib/phUSD-stable-minter` and **no** top-level `lib/flax-token-v2` sibling.
Every claim about the minter, phUSD and the yield strategy in these profiles was read from
antimatter's own **nested** pins, which are stale by construction:

- `lib/phUSD-stable-minter` @ `d6ed1156` (2026-05-27)
- `lib/flax-token-v2` @ `f5300117` (2025-11-20) — ~9 months old
- `lib/phUSD-stable-minter/lib/vault` @ `043ff2c` — **branch `sprint/ERC4626-restrictions`, not master**;
  `merge-base(master, 043ff2c) == 043ff2c`, so it is a strict ancestor (behind), not a fork.
  Master head is `0110ce4` (story-049). Statements about master were read via
  `git show master:<path>` inside the nested vault clone.

Consumers of these profiles: do not upgrade a nested-tree observation into a claim about deployed
code without re-reading the deployed tree. The one place this bites is recorded in
`IYieldStrategy.json` → `whatDependsOnTheBranchPin.depositSignature`.
