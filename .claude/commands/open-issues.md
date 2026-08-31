---
model: claude-sonnet-4-6
---
List a project's undealt-with findings, filtered by a severity floor (default Medium and above)

# Purpose
Answer one question fast: **which findings in this project still need someone to act on them?**

Reads the persistent ledger `reports/<project>/ledger.json` and shows only the findings that have **not** been resolved or triaged to a terminal decision — the *undealt-with* backlog — filtered to a severity floor that defaults to **Medium and above** (where the value leaks live; this suite is mostly DeFi).

This command is **read-only**. It never writes to ledgers, submodules, findings, or the registry. To change a finding's disposition use `/ledger <project> <action> <selector>`, passing the issue ID shown in the first column (`pns12h3`).

# Definition: "undealt-with"
A finding is **dealt-with** (and therefore *hidden* by default) when its ledger status records a resolution or a deliberate human/process decision:
`fixed`, `acknowledged`, `wont-fix`, `false-positive`, `abandoned`, `submitted`, `qa-bundled`, `merged`, `suppressed`.

**`abandoned` is dealt-with** — the branch that carried the finding was discarded, so there is no live code left to act on. It stays hidden unless the branch returns (`/ledger <project> reopen <fingerprint>`), and it is tallied separately from `wont-fix` in the hidden line, because "the code went away" and "we chose to live with it" are different facts.

A finding is **undealt-with** (and therefore *shown*) when its status is anything else — i.e. it is still awaiting work or a decision. In practice this is:
`open`, `fix-pending`, `pending`, `draft`, `needs-poc`, `ready`, `passing`, or any status not in the dealt-with set above.

**`fix-pending` is undealt-with, not dealt-with.** It is a human triage decision, but the decision was *"this is real and we will fix it"* — the work is outstanding, so the finding stays visible until a human marks it `fixed`. Do not group it with `acknowledged`; they have opposite meanings (`acknowledged` = living with it, `fix-pending` = fixing it) and opposite scan behaviour.

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
Invoke **project-manager**: "Resolve friendly name (lowercase-kebab) and locate `reports/<project>/ledger.json`."
- If the project is unknown: list registered projects and stop.
- If no ledger exists yet: report that there is nothing to triage and suggest `/analyze <project>` (or `/full-audit <project>`), then stop.

## 3. Load & Filter
Invoke **finding-manager**: "Load the ledger, select undealt-with findings at or above the severity floor."
- Load every entry from `reports/<project>/ledger.json`.
- **Status filter:** keep entries whose `status` is **not** in the dealt-with set (`fixed`, `acknowledged`, `wont-fix`, `false-positive`, `abandoned`, `submitted`, `qa-bundled`, `merged`, `suppressed`). Unrecognized statuses are kept (fail-open). **`fix-pending` is deliberately NOT in the dealt-with set** — a fix is owed, so it is undealt-with by definition and must always be shown.
- **Severity filter:** keep entries whose `severity` is at or above the floor.
- Sort by severity (High → Medium → Low), then by label.
- If `--include-dealt`, also collect the dealt-with set for a secondary section.

## 4. Display Results
Group by severity. Show **issue ID first**, then label, status, fingerprint prefix (8 chars), title, and provenance (first/last run). Example (`/open-issues phoenix-nft-staking`):
```
Undealt-with: phoenix-nft-staking  (floor: medium+ · branch main @ 9be4a87, updated 2026-05-30)
──────────────────────────────────────────────────────────────────────────────

High (2)
  pns12h3  H-03  [open]         a1f9c2b0  Reward-debt accounting drain on unstakeFor   first -12 · last -14
  pns14h4  H-04  [fix-pending]  88ae7589  Promo flush over-credit  (fix owed)          first -14 · last -14

Medium (1)
  pns13m2  M-02  [open]   7c2e4419  Oracle staleness unchecked in price pull      first -13 · last -14

Summary
  Undealt-with at medium+: 3   (High 2 · Medium 1)
  Hidden below floor: 4 Low/QA   ·   Hidden as dealt-with: 7 (fixed 2 · acknowledged 1 · submitted 1 · wont-fix 1 · abandoned 2)

Next steps:
  /ledger phoenix-nft-staking                     # full triage view
  /recheck phoenix-nft-staking pns12h3            # is H-03 still live at HEAD?
  /write-report phoenix-nft-staking pns13m2       # draft the submission
```
The issue ID (`pns12h3` = phoenix-nft-staking, report 12, H-03) is the permanent, typeable
handle — it is what to paste into `/ledger` or `/recheck`. The label is run-scoped and the
fingerprint is the machine key; both stay visible but neither leads. An entry that predates the
ID backfill prints `—` in that column and is addressed by fingerprint instead; that is expected
on historical findings, never a defect.
When the ledger holds findings from more than one branch, append the branch to each line (`branch feat/nudge-v3`, or `branch feat/nudge-v3 +main` when `branchesSeen` spans several) and name the branch the submodule is currently parked on in the header — a Medium that only exists on an unmerged feature branch is a different call from one on the trunk.

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
4. **Lead with the issue ID.** `issueId` (`pns12h3`) is the permanent human handle — minted once at first sighting, never recomputed — and is the first column. `fingerprint` (`sha256(contract:function:rootCauseClass[:entryPoint])`) is the machine key: display an 8-char prefix, secondary. A missing `issueId` on a historical entry prints `—` and is never treated as corruption.

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
