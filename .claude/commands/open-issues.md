List a project's undealt-with findings, filtered by a severity floor (default Medium and above)

# Purpose
Answer one question fast: **which findings in this project still need someone to act on them?**

Reads the persistent ledger `reports/ledgers/<project>.json` and shows only the findings that have **not** been resolved or triaged to a terminal decision — the *undealt-with* backlog — filtered to a severity floor that defaults to **Medium and above** (where the value leaks live; this suite is mostly DeFi).

This command is **read-only**. It never writes to ledgers, submodules, findings, or the registry. To change a finding's disposition use `/ledger <project> <action> <fingerprint>`.

# Definition: "undealt-with"
A finding is **dealt-with** (and therefore *hidden* by default) when its ledger status records a resolution or a deliberate human/process decision:
`fixed`, `acknowledged`, `wont-fix`, `false-positive`, `submitted`, `qa-bundled`, `merged`, `suppressed`.

A finding is **undealt-with** (and therefore *shown*) when its status is anything else — i.e. it is still awaiting work or a decision. In practice this is:
`open`, `pending`, `draft`, `needs-poc`, `ready`, `passing`, or any status not in the dealt-with set above.

Rationale: `open`/`pending` are untriaged; `draft`/`needs-poc`/`ready`/`passing` are in-flight (found and possibly PoC'd, but neither reported nor triaged away). All of these still require the auditor's attention, so they count as undealt-with. A finding whose status is unrecognized is treated as **undealt-with** (fail-open: better to surface it than silently bury it).

# Arguments
- `$ARGUMENTS` format: `<project-name> [severity-floor] [flags]`
- Project name is case-insensitive (normalized to lowercase-kebab), and must resolve in `registered-projects.json`.
- **Severity floor** (optional, default `medium`):
  - `high` (or `h`) → High only
  - `medium` (or `m`, `med`) → High + Medium **(default)**
  - `low` (or `l`, `qa`, `all`) → High + Medium + Low/QA/Centralization
- **Flags:**
  - `--include-dealt` → also list dealt-with findings (in a separate, dimmed section) so the full picture is visible. Off by default.
  - `--count` → print only the per-severity tally, no per-finding lines.

Severity ordering for the floor is `high > medium > low` (Centralization `C-XX` ranks with Low/QA).

# Orchestration Flow

## 1. Parse Arguments
Extract the project name (required, first token), the optional severity floor, and the optional flags. Default floor = `medium`. Reject an unknown floor token by listing the valid ones.

## 2. Resolve Project
Invoke **project-manager**: "Resolve friendly name (lowercase-kebab) and locate `reports/ledgers/<project>.json`."
- If the project is unknown: list registered projects and stop.
- If no ledger exists yet: report that there is nothing to triage and suggest `/analyze <project>` (or `/full-audit <project>`), then stop.

## 3. Load & Filter
Invoke **finding-manager**: "Load the ledger, select undealt-with findings at or above the severity floor."
- Load every entry from `reports/ledgers/<project>.json`.
- **Status filter:** keep entries whose `status` is **not** in the dealt-with set (`fixed`, `acknowledged`, `wont-fix`, `false-positive`, `submitted`, `qa-bundled`, `merged`, `suppressed`). Unrecognized statuses are kept (fail-open).
- **Severity filter:** keep entries whose `severity` is at or above the floor.
- Sort by severity (High → Medium → Low), then by label.
- If `--include-dealt`, also collect the dealt-with set for a secondary section.

## 4. Display Results
Group by severity. Show label, status, fingerprint prefix (8 chars), title, and provenance (first/last run). Example (`/open-issues phoenix-nft-staking`):
```
Undealt-with: phoenix-nft-staking  (floor: medium+ · ledger @ 9be4a87, updated 2026-05-30)
──────────────────────────────────────────────────────────────────────────────

High (1)
  H-03  [open]   a1f9c2b0  Reward-debt accounting drain on unstakeFor   first -12 · last -14

Medium (1)
  M-02  [open]   7c2e4419  Oracle staleness unchecked in price pull      first -13 · last -14

Summary
  Undealt-with at medium+: 2   (High 1 · Medium 1)
  Hidden below floor: 4 Low/QA   ·   Hidden as dealt-with: 5 (fixed 2 · acknowledged 1 · submitted 1 · wont-fix 1)

Next steps:
  /ledger phoenix-nft-staking                     # full triage view
  /recheck phoenix-nft-staking a1f9c2b0           # is H-03 still live at HEAD?
  /write-report phoenix-nft-staking M-02          # draft the submission
```
Always print the two "Hidden …" lines so nothing is silently dropped — the user can see exactly how many findings the floor and the dealt-with filter removed.

With `--count`, print only the Summary block. With `--include-dealt`, append a dimmed `Dealt-with (N)` section after the Summary listing those entries with their terminal status.

## 5. Empty Results
- **Nothing undealt-with at the floor:** `No undealt-with findings at medium+ for <project>. 🎉` then print the hidden-below-floor and dealt-with tallies so the user knows whether to lower the floor.
- **Empty ledger:** `Ledger exists but has no findings.` Suggest `/analyze <project>`.

# Agent Delegation (MANDATORY)
This command orchestrates; it does not read or filter files directly.
- **project-manager**: resolve project name, locate the ledger.
- **finding-manager**: load the ledger, apply the status + severity filters, format the grouped output.

The orchestrating agent MUST delegate the load/filter to **finding-manager** and MUST NOT read the ledger JSON itself.

# Critical Rules
1. **Read-only.** Never mutate the ledger, findings, submodules, or registry. Disposition changes go through `/ledger`.
2. **Fail-open on status.** An entry whose `status` is not a known dealt-with value is shown, never hidden.
3. **No silent truncation.** Always report how many findings were hidden by the severity floor and by the dealt-with filter.
4. **Fingerprints are stable** (`sha256(contract:function:rootCauseClass[:entryPoint])`); display an 8-char prefix and accept unique prefixes downstream.

# Examples
```
/open-issues phoenix-nft-staking
# High + Medium undealt-with findings (default floor)

/open-issues phoenix-nft-staking high
# High-severity undealt-with only

/open-issues stable-yield-accumulator all
# Every undealt-with finding incl. Low/QA/Centralization

/open-issues phoenix-phase-2-staging medium --count
# Just the tally, no per-finding lines

/open-issues phoenix-nft-staking medium --include-dealt
# Undealt-with at medium+, plus a dimmed list of already-resolved/triaged findings
```
