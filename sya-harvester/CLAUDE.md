# sya-harvester

Audit project. The shared audit laws, severity rules and pipeline conventions live in
the repository root `CLAUDE.md` one level up, which Claude loads automatically — this
file records only what is specific to sya-harvester.

Public, stateless flash-loan helper: inside a Uniswap V4 `unlock` it borrows USDC, claims
discounted yield from `StableYieldAccumulator` (SYA), sells each yield token to USDC along an
owner-registered Curve Router NG route, swaps the surplus to native ETH, settles, and pays the
caller in ETH subject to `minEthOut` and an on-chain `Unprofitable` gas check. Ships with an
operator script, `script/harvest.sh`.

## Layout

| path | what it is |
|---|---|
| `src/` | the audited source, a git submodule of `https://github.com/Behodler/sya-harvester`, **read-only** |
| `work/` | writable clone for PoCs and Tier-3 tests, gitignored, never scanned |
| `reports/NN/` | one directory per audit run, sequentially numbered |
| `ledger.json` | the persistent findings ledger for this project |

Never write to `src/`. PoCs and invariant tests go in `work/`.

## Identity

- Finding labels for this project are prefixed `sh`.
- Stories live in `~/code/product-owner/stories/sya-harvester/`. Here the directory happens to
  equal the project name, but always resolve it through the registry's `storyDir` field. Glob
  the whole tree, across every state and sprint folder.
- Tracked branch: `master`.

## Scope

Scope is default-in-scope: every first-party `.sol` under `src/` is in scope unless it sits in
`src/lib/`. 16 files were in scope at registration; the principal contract is
`src/SYAHarvester.sol`. The registry's arrays are advisory focus hints, never the gate.

**Non-Solidity operator code.** `script/harvest.sh` (bash + `cast` + `bc`) computes `minEthOut`
and the gas limit and submits privately; it is the caller's only slippage protection in
practice. `test/script/harvest_anvil.sh` is its Anvil-fork test. A contract-only scan misses
both; review them explicitly (story-005).

**Cross-repo.** `src/lib/stable-yield-accumulator` is a nested pin of the sibling audit project
`stable-yield-accumulator`; for cross-repo claims read `../stable-yield-accumulator/src`, not
the nested pin.

## Known issues

No known-issues document exists at registration (README and `src/CLAUDE.md` carry no Known
Issues / Out of Scope section). The `src/CLAUDE.md` "Design decisions" are cached as
`designDecisions`: audit context with no suppression authority.

## Working across projects

Sibling audit projects are directories beside this one under `~/code/audits/`. Read one
when a finding genuinely crosses a boundary; `~/code/audits/registered-projects.json` is
the index of all of them.
