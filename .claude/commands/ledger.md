View and triage the persistent findings ledger for a project
# Purpose
Inspect and update `reports/ledgers/<project>.json` — the persistent record of which findings are open, fixed, or triaged across audit runs. Triage decisions recorded here are respected by future `/analyze` and `/full-audit` runs (acknowledged/wont-fix/false-positive findings are suppressed; `fix-pending` findings keep being rescanned; reappearing fixed findings are flagged as regressions).

# Arguments
- `$ARGUMENTS` format: `<project-name> [action] [fingerprint] [note]`
- Project name is case-insensitive (normalized to lowercase-kebab).
- Actions:
  - *(none)* → list the ledger
  - `fixpending <fingerprint> [note]` → mark `fix-pending` — **valid finding, fix owed.** Stays in the scan.
  - `ack <fingerprint> [note]` → mark `acknowledged` — **disposal.** Suppressed from future scans.
  - `wontfix <fingerprint> [note]` → mark `wont-fix`
  - `false-positive <fingerprint> [note]` → mark `false-positive`
  - `fixed <fingerprint>` → mark `fixed` (records current submodule commit)
  - `reopen <fingerprint>` → set back to `open`

## Choosing between `fixpending` and `ack`

These two look similar in a triage conversation ("yes, that's real") but have **opposite** downstream effects. Get this right:

| | `fixpending` | `ack` |
|---|---|---|
| Means | valid, **and we're fixing it** | valid, **and we're living with it** |
| Future scans | **rescanned** (never suppressed) | **suppressed** |
| Carryover stub | yes | no |
| `/open-issues` | shown as undealt-with | hidden as dealt-with |

**If the human says "acknowledged, will fix" — or anything else that promises a fix — that is `fixpending`, NOT `ack`.** The word "acknowledged" in their sentence describes accepting the finding, not disposing of it. Choosing `ack` there silently removes a live bug from every future scan, which is the exact failure `fix-pending` exists to prevent (Law 1: recall beats report-tidiness). When a triage instruction is ambiguous between the two, **ask** — do not guess, and do not default to `ack`.

# Orchestration Flow

## 1. Resolve Project
Invoke **project-manager**: "Resolve friendly name (lowercase-kebab)" and locate `reports/ledgers/<project>.json`. If absent, report that no ledger exists yet (run `/analyze` first).

## 2a. List (no action)
Invoke **finding-manager**: "Load and summarize the ledger"
```
Ledger: phoenix-nft-staking   (lastAuditedCommit a1b2c3d, updated 2026-05-24)
─────────────────────────────────────────────────────────────────
OPEN (3)
  H  a1f9..  Reward debt accounting drain        first phoenix-nft-staking-09 · last -12
  M  7c2e..  Missing staleness check on oracle   first phoenix-nft-staking-11 · last -12
  L  3b80..  Unindexed event                     first phoenix-nft-staking-12 · last -12
FIX-PENDING (1)   ← still scanned; fix owed
  H  88ae..  Promo flush over-credit             "will fix: gate accrual on phase"
FIXED (7)
  H  9d44..  Migrator drain via unstakeFor       fixed at 0fae12 (phoenix-nft-staking-08)
ACKNOWLEDGED (2)   ← suppressed from future scans
  C  5e11..  Single-admin migrator key (by design)   "trusted multisig" 
WONT-FIX (0)   FALSE-POSITIVE (0)
```
List `FIX-PENDING` in its own section directly after `OPEN` — **never** collapse it into `ACKNOWLEDGED`. The two sections carry opposite scan semantics, so the annotations above ("still scanned" / "suppressed") are load-bearing: keep them.

## 2b. Update (action given)
Invoke **finding-manager**: "Update ledger entry status"
- Apply the new status to the entry with the given fingerprint (a unique prefix is acceptable).
- For `fixed`, record `fixedAtCommit` = current submodule HEAD.
- For `fix-pending`, leave `fixedAtCommit` **null** — a fix is owed, not landed. Record the plan in the note.
- Store the optional note. Set `updatedAt`.
- Never delete entries — status changes only (preserves regression detection).
- Confirm the change. When setting `fix-pending`, state in the confirmation that the finding **stays in the scan** and remains visible to `/open-issues`; when setting `acknowledged`, state that it is now **suppressed from future scans**. The human should never have to infer which of the two they got.

# Agent Delegation
- **project-manager**: resolve name, locate ledger
- **finding-manager**: read/update ledger entries

# Critical Rules
1. **Statuses set here are authoritative** — automated runs never overwrite them.
2. **Never delete ledger entries** — a `fixed` entry must persist so a reappearance is caught as a regression.
3. **Fingerprints are stable** — `sha256(contract:function:rootCauseClass)`; accept unique prefixes for convenience.
4. **`ack` is a disposal; `fixpending` is not** — `ack` suppresses the finding from every future scan. Only use it when the finding will *not* be fixed. A promise to fix is `fixpending`. If the instruction is ambiguous, ask rather than defaulting to `ack`.
5. **`fix-pending` is never auto-resolved** — only a human `/ledger … fixed` closes it. `/analyze`, `/full-audit`, and `/recheck` may *propose* the flip; they never apply it.
