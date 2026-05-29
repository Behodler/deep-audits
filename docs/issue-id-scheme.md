# Global Issue ID Scheme

A short, separator-free identifier that uniquely names any single finding across all
projects and runs, so a finding can be copy-pasted instead of referenced by absolute path.

## Format

```
<project-acronym><report#><type><issue#>
```

All lowercase, no separators. Example: `ryv5m2` = reflax-yield-vault, report 05, **M**-02.

## Derivation (deterministic, from the run-dir name + the finding label)

Given a submission living at `reports/<run-dir>/submissions/...` with a C4 label like `M-02`:

1. **project-acronym** — split the run-dir name into family + run number by stripping the
   trailing `-<digits>` (`reflax-yield-vault-05` → family `reflax-yield-vault`, run `05`). Take the
   first letter of each hyphen-separated word of the **family name**, **dropping any
   pure-numeric word**. (`phoenix-phase-2-staging` → `pps`, not `pp2s`.)
2. **report#** — the stripped run number with leading zeros removed (`05` → `5`, `10` → `10`).
   A bare family dir with no `-NN` suffix (legacy/seed run) is report `0`.
3. **type** — the label letter, lowercased: `h` (High), `m` (Medium), `l` (Low),
   `c` (Centralization), `g` (Gas, if ever labeled).
4. **issue#** — the label number with leading zeros removed (`M-02` → `2`).

## Worked examples

| ID | Resolves to |
|----|-------------|
| `ryv5m2` | `reports/reflax-yield-vault-05/submissions/M-02-*.md` |
| `ryv5m1` | `reports/reflax-yield-vault-05/submissions/M-01-*.md` |
| `ryv5c1` | the `### [C-01]` section inside `reports/reflax-yield-vault-05/submissions/qa-report.md` |
| `ryv5l2` | the `### [L-02]` section inside `reports/reflax-yield-vault-05/submissions/qa-report.md` |
| `sya9c1` | first `[C-01]` of `reports/stable-yield-accumulator-09/` |

## Current project acronyms

| Project (= repo / submodule / report-dir family) | Acronym |
|---|---|
| reflax-yield-vault | `ryv` |
| stable-yield-accumulator | `sya` |
| yield-claim-nft | `ycn` |
| phoenix-nft-staking | `pns` |
| phlimbo-ea | `pe` |
| phoenix-phase-2-staging | `pps` |

Project names, submodule directories, and report-dir family names are all the same string
now (the upstream repo name), so the acronym derives from that single canonical name.

## Edge cases

- **Numeric words in a name** — dropped from the acronym so they never collide with the
  report number (`phoenix-phase-2-staging` → `pps`).
- **Acronym collision** — none today. If two families ever produce the same acronym, extend
  the acronym by the next letter of the first differing word, and record the override here.
- **Where the stamp lives** — H/M findings carry the ID in the `ID:` line of their submission
  file's metadata comment. L/C findings have no own file, so the ID is an inline
  `<!-- id: ryvNcM -->` comment on their `### [L-0x]` / `### [C-0x]` section header in
  `qa-report.md`.

## Resolving an ID back to a finding

The ID is regular enough to parse blind, but resolution should be confirmed against the live
`reports/` tree: find the family whose acronym matches the leading letters, then the
`<family>-<NN>` run dir, then the labeled submission file or `qa-report.md` section. The
filesystem disambiguates any theoretical numeric ambiguity.
