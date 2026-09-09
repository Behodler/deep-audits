# stable-yield-accumulator

Audit project. The shared audit laws, severity rules and pipeline conventions live in
the repository root `CLAUDE.md` one level up, which Claude loads automatically — this
file records only what is specific to stable-yield-accumulator.

Consolidates yield strategy rewards from multiple stablecoins into a single reward token for simplified Phlimbo distribution. Part of the Phoenix/Behodler ecosystem.

## Layout

| path | what it is |
|---|---|
| `src/` | the audited source, a git submodule of `https://github.com/Behodler/stable-yield-accumulator`, **read-only** |
| `work/` | writable clone for PoCs and Tier-3 tests, gitignored, never scanned |
| `reports/NN/` | one directory per audit run, sequentially numbered |
| `ledger.json` | the persistent findings ledger for this project |

Never write to `src/`. PoCs and invariant tests go in `work/`.

## Identity

- Finding labels for this project are prefixed `sya`.
- Stories live in `~/code/product-owner/stories/yield-accumulator/` — **not** under a
  directory named `stable-yield-accumulator`. Resolve a `[story-NNN]` tag by globbing that whole tree,
  across every state and sprint folder, never one of them.
- Tracked branch: `master`.

## Scope

Scope is default-in-scope: every first-party `.sol` under `src/` is in scope unless it
sits in `src/lib/`. 1 contracts were in scope at the last scope refresh. The registry's arrays are advisory focus hints, never the gate.

## Known issues

Known issues are extracted from `src/CLAUDE.md` — 8 entries are cached in the registry under `knownIssues`.

## Working across projects

Sibling audit projects are directories beside this one under `~/code/audits/`. Read one
when a finding genuinely crosses a boundary; `~/code/audits/registered-projects.json` is
the index of all of them.
