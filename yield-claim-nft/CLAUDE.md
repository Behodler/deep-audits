# yield-claim-nft

Audit project. The shared audit laws, severity rules and pipeline conventions live in
the repository root `CLAUDE.md` one level up, which Claude loads automatically — this
file records only what is specific to yield-claim-nft.

## Layout

| path | what it is |
|---|---|
| `src/` | the audited source, a git submodule of `git@github.com:Behodler/yield-claim-nft.git`, **read-only** |
| `work/` | writable clone for PoCs and Tier-3 tests, gitignored, never scanned |
| `reports/NN/` | one directory per audit run, sequentially numbered |
| `ledger.json` | the persistent findings ledger for this project |

Never write to `src/`. PoCs and invariant tests go in `work/`.

## Identity

- Finding labels for this project are prefixed `ycn`.
- Stories live in `~/code/product-owner/stories/yield-claim-nft/` — **not** under a
  directory named `yield-claim-nft`. Resolve a `[story-NNN]` tag by globbing that whole tree,
  across every state and sprint folder, never one of them.
- Tracked branch: `master`.

## Scope

Scope is default-in-scope: every first-party `.sol` under `src/` is in scope unless it
sits in `src/lib/`. 13 contracts were in scope at the last scope refresh. The registry's arrays are advisory focus hints, never the gate.

Focus contracts:

- `src/hooks/BalancerPoolerMintDebtHook.sol`
- `src/NFTMinterV2.sol`
- `src/dispatchers/BalancerPoolerV2.sol`
- `src/dispatchers/BurnerV2.sol`
- `src/dispatchers/GatherV2.sol`
- `src/dispatchers/ATokenDispatcherV2.sol`
- `src/dispatchers/NudgeRatchet.sol`
- `src/dispatchers/Uniboost.sol`
- `src/hooks/DefaultDispatchHook.sol`
- `src/hooks/NudgeRatchetMintDebtHook.sol`
- `src/hooks/UniboostMintDebtHook.sol`
- `src/MultiPooler.sol`

## Known issues

No known-issues document has been located in the source repo, so the registry's `knownIssues` array is the only cache.

## Working across projects

Sibling audit projects are directories beside this one under `~/code/audits/`. Read one
when a finding genuinely crosses a boundary; `~/code/audits/registered-projects.json` is
the index of all of them.
