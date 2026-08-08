# Global Issue ID Scheme

A short, separator-free identifier that uniquely names any single finding across all
projects and runs, so a finding can be copy-pasted instead of referenced by absolute path.

**This is the primary human handle for a finding.** It is minted once, persisted in the
ledger as `issueId`, printed first by every command that lists findings, and accepted as a
selector by every command that takes one. The machine-readable authority for prefixes and
policy is `registered-projects.json` → `idPolicy` + `projects.<name>.idPrefix`; this document
is the narrative spec behind it.

## Format

```
<project-acronym><report#><type><issue#>
```

All lowercase, no separators. Example: `ryv5m2` = reflax-yield-vault, report 05, **M**-02.

## The three identifiers (none is redundant)

| | Scope | Assigned | Job |
|---|---|---|---|
| `issueId` — `sya14m1` | global, permanent | **minted once**, at first sighting | the handle humans type, quote and cross-reference |
| `fingerprint` — `eda17642…` | global, permanent | **computed** from `contract:function:rootCauseClass[:entryPoint]` | machine reconciliation across runs |
| `label` — `M-01` | one run dir | **reassigned every run** | pointer into a single report |

The fingerprint cannot be replaced by the issueId, and this is the whole reason both exist: a
fingerprint is *derived from the code*, so a scan five runs later re-computes the same value
with no lookup table. That is what powers regression detection, `fix-pending` survival and
incomplete-fix flagging. Nothing re-derives "this is `sya14m1`" from a contract. Conversely a
sha is unusable as a human handle. Keep both; show the issueId first.

## Derivation (deterministic, from the run-dir name + the finding label)

Given a submission living at `reports/<run-dir>/submissions/...` with a C4 label like `M-02`:

1. **project-acronym** — read `projects.<name>.idPrefix` from `registered-projects.json`. That
   field is **authoritative**; do not re-derive when it is present. It was originally derived
   by taking the first letter of each hyphen-separated word of the project name, **dropping
   any pure-numeric word** (`phoenix-phase-2-staging` → `pps`, not `pp2s`), and that rule is
   still how a *new* project's prefix is proposed — but once written it is fixed, so a later
   rename or collision-override never silently changes existing IDs.
2. **report#** — the run number with leading zeros removed (`05` → `5`, `26` → `26`).
   A bare family dir with no `-NN` suffix (legacy/seed run) is report `0`.
3. **type** — the label letter, lowercased: `h` (High), `m` (Medium), `l` (Low),
   `c` (Centralization), `f` (Faithfulness / spec-conformance), `q` (QA / hardening note —
   both `Q-0x` and `QA-0x` labels map to `q`), `g` (Gas, if ever labeled).
4. **issue#** — the label number with leading zeros removed (`M-02` → `2`).

### Mint once, never recompute

The ID is minted at the run where the finding is **first seen** and never re-minted,
renumbered or recomputed afterwards. `report#` and `issue#` therefore encode `firstSeenRun`
and the **original** label — not the current run — exactly like `firstSeenRun` itself. A
finding first filed as M-01 in run 12 stays `sya12m1` forever, even when it is carried into
run 18 under a different label. Recomputing on a later run would invalidate every
cross-reference sitting in triage notes, memories and plan documents.

Carryover follows the same rule: a carried-over report keeps the originating run's ID, which
is what makes `M-01-C1.md` traceable back to the audit that first raised it.

### Canonical padding

Numbers are written **unpadded**: `sya14m1`, not `sya14m02`. Some run-14
stable-yield-accumulator entries were minted zero-padded (`sya14m02`, `sya14l07`) before this
was pinned down; those are left as-is rather than rewritten, and resolution treats padded and
unpadded forms as equivalent, so `sya14m2` finds `sya14m02`. Mint new IDs unpadded.

## Worked examples

| ID | Resolves to |
|----|-------------|
| `ryv5m2` | `reports/reflax-yield-vault-05/submissions/M-02-*.md` |
| `ryv5m1` | `reports/reflax-yield-vault-05/submissions/M-01-*.md` |
| `ryv5c1` | the `### [C-01]` section inside `reports/reflax-yield-vault-05/submissions/qa-report.md` |
| `ryv5l2` | the `### [L-02]` section inside `reports/reflax-yield-vault-05/submissions/qa-report.md` |
| `sya9c1` | first `[C-01]` of `reports/stable-yield-accumulator-09/` |

## Current project acronyms

Mirrored from `registered-projects.json` → `projects.<name>.idPrefix`, which is the
authoritative machine-readable copy. When they disagree, the registry wins; update this table
to match rather than the other way round.

| Project (= repo / submodule / report-dir family) | Acronym |
|---|---|
| reflax-yield-vault | `ryv` |
| stable-yield-accumulator | `sya` |
| yield-claim-nft | `ycn` |
| phoenix-nft-staking | `pns` |
| phlimbo-ea | `pe` |
| phoenix-phase-2-staging | `pps` |
| stable-staker | `ss` |

Project names, submodule directories, and report-dir family names are all the same string
now (the upstream repo name), so the acronym derives from that single canonical name.

## Edge cases

- **Numeric words in a name** — dropped from the acronym so they never collide with the
  report number (`phoenix-phase-2-staging` → `pps`).
- **Acronym collision** — none today. If two families ever produce the same acronym, extend
  the acronym by the next letter of the first differing word, and record the override here.
- **Where the stamp lives** — the ledger entry's `issueId` field is the record of truth. H/M
  findings additionally carry the ID in the `ID:` line of their submission file's metadata
  comment; L/C/QA findings have no own file, so the ID is an inline `<!-- id: ryv5c1 -->`
  comment on their `### [L-0x]` / `### [C-0x]` section header in `qa-report.md`.
- **Missing IDs are expected, not corruption** — only phoenix-phase-2-staging runs 25–26 and
  the ledgers that already carried IDs natively were backfilled. Historical entries elsewhere
  have no `issueId` by deliberate decision. Never treat the absence as damage, never auto-mint
  one during a scan, and never skip an entry because it lacks one — fall through to the
  fingerprint rung.
- **Legacy field names** — `id` (stable-staker), `internalId` (phlimbo-ea) and `issueId` all
  hold the same thing; read all three, write only `issueId`.

## Resolving a selector back to a finding

A selector typed at a terminal is a convenience for a human, **not a parser contract**. Walk
the ladder below and resolve at the first rung that yields exactly one entry. A near-miss gets
resolved and announced; it is never rejected on a syntax technicality.

1. **issueId, exact** — after normalising: lowercase, strip `-`, `_`, `#` and spaces. So
   `PPS-26-L-1`, `pps26L1` and `pps 26 l 1` all reach `pps26l1`.
2. **issueId, tolerant** — zero-padding is ignored in both directions (`pps26l01` ≡ `pps26l1`);
   `qa` ≡ `q`; and when the command already knows the project from its own first argument, a
   bare `<report#><type><issue#>` is accepted (`26l1`, or even `l1` for the newest run).
3. **fingerprint** — full, or any unique prefix of ≥4 hex characters, case-insensitive.
4. **run label** — `M-01`, scoped to the project's newest run unless a run is named
   (`M-01@25`, `25 M-01`, `-25 M-01`).
5. **free text** — matched against `title`, `contract`, `function` and `rootCauseClass`.
   "the deployer minter grant one", "stale address book" — rank the candidates and take the
   clear winner if there is one.

**Announce every non-exact resolution**, on one line, before acting:

```
Resolved "deployer minter grant" → pps26l4  b8e3d591  "The deploy script grants itself phUSD mint authority and never revokes it"
```

**Read-only vs mutating.** For read-only commands (`/open-issues`, `/list-findings`,
`/report-view`, `/recheck`) an unambiguous rung-4 or rung-5 match may be used directly once
announced. For a **mutating** command — any `/ledger` status change — a rung-4 or rung-5 match
must be **confirmed by the human before writing**. Triaging the wrong finding marks a live bug
`wont-fix`, which is precisely the Law-1 failure the ledger exists to prevent; the confirmation
costs one line and the mistake costs an exploit.

**Ambiguity never resolves silently.** List up to 5 ranked candidates with their issueIds,
fingerprint prefixes and titles, and ask. Zero matches lists the nearest few rather than just
reporting failure.
