# Global Issue ID Scheme

A short, separator-free identifier that uniquely names any single finding across all
projects and runs, so a finding can be copy-pasted instead of referenced by absolute path.

## Format

```
<project-acronym><report#><type><issue#>
```

All lowercase, no separators. Example: `pv5m2` = phoenix-vault, report 05, **M**-02.

## Derivation (deterministic, from the run-dir name + the finding label)

Given a submission living at `reports/<run-dir>/submissions/...` with a C4 label like `M-02`:

1. **project-acronym** — split the run-dir name into family + run number by stripping the
   trailing `-<digits>` (`phoenix-vault-05` → family `phoenix-vault`, run `05`). Take the
   first letter of each hyphen-separated word of the **family name**, **dropping any
   pure-numeric word**. (`phoenix-phase-2` → `pp`, not `pp2`.)
2. **report#** — the stripped run number with leading zeros removed (`05` → `5`, `10` → `10`).
   A bare family dir with no `-NN` suffix (legacy/seed run) is report `0`.
3. **type** — the label letter, lowercased: `h` (High), `m` (Medium), `l` (Low),
   `c` (Centralization), `g` (Gas, if ever labeled).
4. **issue#** — the label number with leading zeros removed (`M-02` → `2`).

## Worked examples

| ID | Resolves to |
|----|-------------|
| `pv5m2` | `reports/phoenix-vault-05/submissions/M-02-*.md` |
| `pv5m1` | `reports/phoenix-vault-05/submissions/M-01-*.md` |
| `pv5c1` | the `### [C-01]` section inside `reports/phoenix-vault-05/submissions/qa-report.md` |
| `pv5l2` | the `### [L-02]` section inside `reports/phoenix-vault-05/submissions/qa-report.md` |
| `ya9c1` | first `[C-01]` of `reports/yield-accumulator-09/` |

## Current project acronyms

| Project (report-dir family) | Acronym |
|---|---|
| phoenix-vault | `pv` |
| yield-accumulator | `ya` |
| yield-claim-nft | `ycn` |
| nft-staking | `ns` |
| phlimbo-linear | `pl` |
| stable-yield-accumulator | `sya` |
| phoenix-phase-2 | `pp` |

The acronym keys off the **report-dir family name**, not the upstream repo name (e.g.
`yield-accumulator` audits the `stable-yield-accumulator` repo but its ID acronym is `ya`).

## Edge cases

- **Numeric words in a name** — dropped from the acronym so they never collide with the
  report number (`phoenix-phase-2` → `pp`).
- **Acronym collision** — none today. If two families ever produce the same acronym, extend
  the acronym by the next letter of the first differing word, and record the override here.
- **Where the stamp lives** — H/M findings carry the ID in the `ID:` line of their submission
  file's metadata comment. L/C findings have no own file, so the ID is an inline
  `<!-- id: pvNcM -->` comment on their `### [L-0x]` / `### [C-0x]` section header in
  `qa-report.md`.

## Resolving an ID back to a finding

The ID is regular enough to parse blind, but resolution should be confirmed against the live
`reports/` tree: find the family whose acronym matches the leading letters, then the
`<family>-<NN>` run dir, then the labeled submission file or `qa-report.md` section. The
filesystem disambiguates any theoretical numeric ambiguity.
