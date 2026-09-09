# stable-staker

Audit project. The shared audit laws, severity rules and pipeline conventions live in
the repository root `CLAUDE.md` one level up, which Claude loads automatically — this
file records only what is specific to stable-staker.

MasterChef-style yield farm supporting any number of staked (stable) tokens, rewarding stakers in phUSD (FlaxToken from the flax-token dependency). Rewards are not pre-funded; the contract is an authorized phUSD minter and mints rewards on claim/withdraw/migration. Optional per-token IYieldStrategy routing (from reflax-yield-vault) lets staked principal earn yield instead of sitting idle.

## Layout

| path | what it is |
|---|---|
| `src/` | the audited source, a git submodule of `git@github.com:Behodler/stable-staker.git`, **read-only** |
| `work/` | writable clone for PoCs and Tier-3 tests, gitignored, never scanned |
| `reports/NN/` | one directory per audit run, sequentially numbered |
| `ledger.json` | the persistent findings ledger for this project |

Never write to `src/`. PoCs and invariant tests go in `work/`.

## Identity

- Finding labels for this project are prefixed `ss`.
- Stories live in `~/code/product-owner/stories/stable-staker/` — **not** under a
  directory named `stable-staker`. Resolve a `[story-NNN]` tag by globbing that whole tree,
  across every state and sprint folder, never one of them.
- Tracked branch: `master`.

## Scope

Scope is default-in-scope: every first-party `.sol` under `src/` is in scope unless it
sits in `src/lib/`. 5 contracts were in scope at the last scope refresh. The registry's arrays are advisory focus hints, never the gate.

Focus contracts:

- `src/StableStakerV2.sol`
- `src/CrossVersionMigrator.sol`
- `src/versions/v1/StableStakerV1.sol`

## Known issues

Known issues are extracted from `src/CLAUDE.md` — 26 entries are cached in the registry under `knownIssues`.

## Working across projects

Sibling audit projects are directories beside this one under `~/code/audits/`. Read one
when a finding genuinely crosses a boundary; `~/code/audits/registered-projects.json` is
the index of all of them.
