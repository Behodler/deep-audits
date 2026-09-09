# reflax-yield-vault

Audit project. The shared audit laws, severity rules and pipeline conventions live in
the repository root `CLAUDE.md` one level up, which Claude loads automatically — this
file records only what is specific to reflax-yield-vault.

NEW: ERC4626MarketYieldStrategy + CurveAMMAdapter. The market strategy buys/sells ERC4626 vault tokens via AMM (instead of direct vault.deposit/withdraw) to handle vaults with restrictions (e.g., sUSDe cooldown). CurveAMMAdapter implements the IAMMAdapter interface against Curve Router NG and enforces bidirectional route configuration. AMMRoutes.json supplies pre-computed deployment routes (currently USDe<->sUSDe).

## Layout

| path | what it is |
|---|---|
| `src/` | the audited source, a git submodule of `https://github.com/Behodler/reflax-yield-vault`, **read-only** |
| `work/` | writable clone for PoCs and Tier-3 tests, gitignored, never scanned |
| `reports/NN/` | one directory per audit run, sequentially numbered |
| `ledger.json` | the persistent findings ledger for this project |

Never write to `src/`. PoCs and invariant tests go in `work/`.

## Identity

- Finding labels for this project are prefixed `ryv`.
- Stories live in `~/code/product-owner/stories/vault-RM/` — **not** under a
  directory named `reflax-yield-vault`. Resolve a `[story-NNN]` tag by globbing that whole tree,
  across every state and sprint folder, never one of them.
- Tracked branch: `master`.

## Scope

Scope is default-in-scope: every first-party `.sol` under `src/` is in scope unless it
sits in `src/lib/`. 7 contracts were in scope at the last scope refresh. The registry's arrays are advisory focus hints, never the gate.

## Known issues

Known issues are extracted from `src/CLAUDE.md`, and cached in the registry under `knownIssues`.

## Working across projects

Sibling audit projects are directories beside this one under `~/code/audits/`. Read one
when a finding genuinely crosses a boundary; `~/code/audits/registered-projects.json` is
the index of all of them.
