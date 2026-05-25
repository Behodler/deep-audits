View and triage the persistent findings ledger for a project
# Purpose
Inspect and update `reports/ledgers/<project>.json` — the persistent record of which findings are open, fixed, or triaged across audit runs. Triage decisions recorded here are respected by future `/analyze` and `/full-audit` runs (acknowledged/wont-fix/false-positive findings are suppressed; reappearing fixed findings are flagged as regressions).

# Arguments
- `$ARGUMENTS` format: `<project-name> [action] [fingerprint] [note]`
- Project name is case-insensitive (normalized to lowercase-kebab).
- Actions:
  - *(none)* → list the ledger
  - `ack <fingerprint> [note]` → mark `acknowledged`
  - `wontfix <fingerprint> [note]` → mark `wont-fix`
  - `false-positive <fingerprint> [note]` → mark `false-positive`
  - `fixed <fingerprint>` → mark `fixed` (records current submodule commit)
  - `reopen <fingerprint>` → set back to `open`

# Orchestration Flow

## 1. Resolve Project
Invoke **project-manager**: "Resolve friendly name (lowercase-kebab)" and locate `reports/ledgers/<project>.json`. If absent, report that no ledger exists yet (run `/analyze` first).

## 2a. List (no action)
Invoke **finding-manager**: "Load and summarize the ledger"
```
Ledger: nft-staking   (lastAuditedCommit a1b2c3d, updated 2026-05-24)
─────────────────────────────────────────────────────────────────
OPEN (3)
  H  a1f9..  Reward debt accounting drain        first nft-staking-09 · last -12
  M  7c2e..  Missing staleness check on oracle   first nft-staking-11 · last -12
  L  3b80..  Unindexed event                     first nft-staking-12 · last -12
FIXED (7)
  H  9d44..  Migrator drain via unstakeFor       fixed at 0fae12 (nft-staking-08)
ACKNOWLEDGED (2)
  C  5e11..  Single-admin migrator key (by design)   "trusted multisig" 
WONT-FIX (0)   FALSE-POSITIVE (0)
```

## 2b. Update (action given)
Invoke **finding-manager**: "Update ledger entry status"
- Apply the new status to the entry with the given fingerprint (a unique prefix is acceptable).
- For `fixed`, record `fixedAtCommit` = current submodule HEAD.
- Store the optional note. Set `updatedAt`.
- Never delete entries — status changes only (preserves regression detection).
- Confirm the change.

# Agent Delegation
- **project-manager**: resolve name, locate ledger
- **finding-manager**: read/update ledger entries

# Critical Rules
1. **Statuses set here are authoritative** — automated runs never overwrite them.
2. **Never delete ledger entries** — a `fixed` entry must persist so a reappearance is caught as a regression.
3. **Fingerprints are stable** — `sha256(contract:function:rootCauseClass)`; accept unique prefixes for convenience.
