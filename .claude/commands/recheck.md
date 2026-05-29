Re-verify a single known finding against the latest code without a full re-scan
# Purpose
Re-prove (or disprove) **one specific** ledger finding against the project's current submodule HEAD, cheaply and deterministically — *without* running discovery and *without* advancing the regression baseline.

This is **re-verification**, not discovery. It answers "does this exact finding still hold at HEAD, and did the fix land?" It does **not** look for new bugs, including bugs the fix may have introduced. When the change is broad, this command will tell you to run `/full-audit` instead.

Mechanism is **PoC-replay first**: if the finding has a runnable PoC, re-run it against the current code. A passing PoC is authoritative evidence the finding is still live; a PoC whose exploit assertion no longer holds is evidence the fix landed. Scanner re-run is a fallback only when no PoC exists.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-label-or-fingerprint> [--commit <ref>]`
- Project name is the friendly name (case-insensitive; normalized to lowercase-kebab).
- Finding selector: a ledger label (`M-01`) or a unique fingerprint prefix (`9addc2`).
- `--commit <ref>` re-verifies against a specific submodule commit instead of current HEAD (default: HEAD).
- Examples:
  - `reflax-yield-vault M-01` — re-verify M-01 against the freshly-pulled submodule HEAD
  - `reflax-yield-vault 9addc2` — same, selected by fingerprint prefix
  - `reflax-yield-vault M-02 --commit 7d11f66` — re-verify against a pinned commit

# THE INVARIANT THAT MAKES THIS SAFE
**recheck is baseline-preserving and single-entry.** Discovery scans (`/analyze`, `/full-audit`) earn the right to advance the regression baseline because they look at the whole scope; recheck does not. Therefore recheck:

1. **MUST NOT write `lastAuditedCommit`** on the ledger. That field is the regression diff baseline; advancing it after looking at only one finding would make all future regression scans silently skip everything that changed between the old baseline and now.
2. **MUST NOT bump `lastSeenRun`** — that field means "observed by a discovery scan." recheck records its result in dedicated recheck-only fields instead (see step 6).
3. **MUST touch only the target entry.** No other ledger entry, and no run pointer (`lastRun`), is modified.
4. **MUST NOT auto-overwrite a human triage status** (`acknowledged` / `wont-fix` / `false-positive`) or auto-flip `open`↔`fixed`. recheck *proposes* a status change and prints the exact `/ledger` command; the human confirms.

If you cannot honor all four, stop and tell the user to run `/full-audit` instead.

# Orchestration Flow

## 1. Resolve Project & Finding
Invoke **project-manager**: "Resolve friendly name to submodule path; get current HEAD"
- Normalize the name; look up the submodule in `registered-projects.json`.
- Get `lib/<submodule>`, the current submodule HEAD (the "latest code"), and the target commit (`--commit` if given, else HEAD).

Invoke **finding-manager**: "Load the ledger entry for this selector"
- Read `reports/ledgers/<project>.json`; match the label or fingerprint prefix to exactly one entry.
- Load its `fingerprint`, `status`, `severity`, `title`, `contract`, `function`, `lineStart/lineEnd`, `reportPath`, `firstSeenRun`, `fixedAtCommit`.
- If the selector matches a `merged` entry (e.g. M-03 → M-02), report the merge and recheck the surviving entry instead.

```
Recheck: reflax-yield-vault  M-01
─────────────────────────────
Finding:  _skimSurplusBatch over-skim via duplicate clients[]  (medium, status: open)
Owner run: reflax-yield-vault-05
Baseline:  lastAuditedCommit 7d11f66 (unchanged — recheck will NOT move it)
Target:    HEAD 7d11f66  →  (resolve actual)
```

## 2. Scope Guard — is this change narrow enough for a recheck?
Invoke **project-manager**: "Compute changed files between the finding's last-audited commit and the target commit"
- Read-only `git -C lib/<submodule> diff --name-only <lastAuditedCommit> <target>`.
- **If the diff is empty** (code identical to when the finding was recorded): report that nothing changed for this finding; no re-verification needed; exit (offer `/ledger` if the user wants to triage anyway).
- **If changed files extend beyond the finding's `contract`**: the change is broader than this finding. Print a warning and **recommend `/full-audit <project>`** — recheck cannot see new issues the broader change may have introduced. Proceed with the narrow recheck only if the user explicitly wants the single-finding answer anyway.

```
Scope check
───────────
Changed since 7d11f66: src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol (1 file)
Finding contract:       src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol
Verdict: NARROW — recheck is appropriate.
  (If this were broader than the finding's contract, you'd want /full-audit instead.)
```

## 3. Sync Workspace Source to the Target Commit (preserving PoCs)
Invoke **project-manager**: "Sync workspace source tree to the target commit, preserving test/ PoCs"
- The finding's PoC lives in `workspace/<project>/test/` (writable, gitignored). The PoC imports `workspace/<project>/src/...`, which may be **stale** relative to the freshly-pulled `lib/` submodule.
- Bring the workspace **source** to the target commit so the PoC runs against the latest code, **without** disturbing `test/` (the PoCs) and **without** touching `lib/` (read-only):
  - Re-point the workspace clone at the submodule's origin if its remote was removed, `git fetch` the target commit, then `git checkout <target> -- src/` (and any non-`test/` source dirs the project compiles). PoC files under `test/` are left exactly as-is.
  - If a clean source sync is not possible, recreate the workspace at the target commit and re-copy the finding's PoC into `test/`.
- Confirm the workspace source is at `<target>` and the PoC file is present.

## 4. Re-verify
### 4a. PoC-replay (preferred)
If the finding has a PoC (`workspace/<project>/test/poc-<label>*.t.sol` or recorded in the finding record):

Invoke **poc-validator**: "Replay the finding's PoC against the synced workspace and classify the outcome"
```bash
cd workspace/<project> && forge test --match-path test/poc-<label>*.t.sol -vvv
```
Classify into exactly one of three outcomes — distinguishing a real fix from PoC bit-rot is the whole point:

- **STILL-LIVE** — PoC compiles and its exploit assertions still pass. The finding holds at the target commit.
- **LIKELY-FIXED** — PoC compiles but the exploit assertion now fails / the exploit reverts at the patched code. Strong evidence the fix landed.
- **INCONCLUSIVE** — PoC no longer compiles (interface/signature drift from the refactor), so the assertion was never reached. This is *not* evidence of a fix — the PoC needs regenerating before any conclusion. Recommend `/generate-poc <project> <label>` then re-run `/recheck`.

### 4b. Scanner fallback (only if no PoC exists)
Invoke the finding's originating scanner — **code-scanner** for code-logic findings, **econ-scanner** for economic findings — scoped to the finding's `contract`/`function` only (pass the contract profile, not the whole scope). Map the result to STILL-LIVE / LIKELY-FIXED / INCONCLUSIVE. Note in the output that scanner re-verification is weaker than a PoC and recommend generating a PoC for a definitive answer.

## 5. Write the Re-verification Record
Write a focused addendum to the run that **owns** the finding (derived from `reportPath`), not a new versioned run dir:
- Path: `reports/<owner-run>/reverify/<label>-<short-target-commit>.md`
- Contents: target commit, changed-file scope, mechanism used (PoC-replay vs scanner), the forge output / assertion result, the outcome (STILL-LIVE / LIKELY-FIXED / INCONCLUSIVE), and the proposed ledger action.

This is explicitly an **addendum**, not an audit run — it must not create `reports/<project>-NN/` or move the ledger's `lastRun`.

## 6. Propose Ledger Update (single entry, recheck-only fields)
Invoke **finding-manager**: "Record recheck result on the target entry only — recheck-touch operation"
- Update **only** the target entry, adding/refreshing recheck-only fields (never `lastSeenRun`, never `lastAuditedCommit`):
  ```json
  "lastRecheckedCommit": "<target>",
  "lastRecheckedAt": "<iso8601>",
  "recheckResult": "still-live | likely-fixed | inconclusive"
  ```
- Set the ledger's top-level `updatedAt`. Do **not** touch `lastAuditedCommit` or `lastRun`.
- **Propose**, do not apply, any status change, and print the exact command:
  - LIKELY-FIXED on an `open` finding → recommend `/ledger <project> fixed <fingerprint>` (which records `fixedAtCommit`).
  - **STILL-LIVE on a `fixed` finding → REGRESSION.** Surface this loudly (a fix that was marked done is exploitable again is the highest-signal result) and recommend `/ledger <project> reopen <fingerprint>`. Do not auto-reopen.
  - STILL-LIVE on an `open` finding → no status change needed; the recheck fields record the confirmation.
  - Any result on an `acknowledged` / `wont-fix` / `false-positive` finding → report the result for information only; never change a human status.

## 7. Summary
```
Recheck Complete: reflax-yield-vault  M-01
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Target commit:  a1b2c3d  (baseline 7d11f66 left UNCHANGED)
Scope:          NARROW (1 file, within finding's contract)
Mechanism:      PoC-replay — workspace/reflax-yield-vault/test/poc-M01-overskim.t.sol
Result:         STILL-LIVE  ✓ exploit assertion still passes

Record:  reports/reflax-yield-vault-05/reverify/M-01-a1b2c3d.md
Ledger:  M-01 recheck fields updated (lastSeenRun / lastAuditedCommit NOT touched)

Proposed action: none — finding confirmed still open.
Note: recheck does not look for NEW issues. For coverage of the whole change, run /full-audit reflax-yield-vault.
```

# Agent Delegation
- **project-manager**: resolve name; current HEAD / target commit; changed-file scope guard; sync workspace source to target (preserving PoCs)
- **finding-manager**: load the ledger entry by selector; recheck-touch the single entry (recheck-only fields); propose (never apply) status changes
- **poc-validator**: replay the finding's PoC and classify STILL-LIVE / LIKELY-FIXED / INCONCLUSIVE
- **code-scanner** / **econ-scanner**: scoped re-verification fallback when no PoC exists

# Error Handling
- **Project/finding not found**: list registered projects or ledger entries.
- **Ambiguous selector**: list the entries the prefix matches; ask for a longer prefix.
- **No PoC and no scanner mapping**: report that the finding cannot be auto-verified; recommend `/generate-poc` first.
- **PoC won't compile after sync**: classify INCONCLUSIVE (interface drift), not fixed; recommend regenerating the PoC.
- **Workspace cannot be synced**: report the blocker; do not fall back to running against stale source (that would give a misleading result).
- **Broad change**: warn and recommend `/full-audit`; proceed narrowly only on explicit request.

# Critical Rules
1. **Baseline-preserving**: never write `lastAuditedCommit`; never bump `lastSeenRun`; never move `lastRun`.
2. **Single-entry**: touch only the target ledger entry.
3. **Propose, don't apply** status changes; respect human triage statuses absolutely.
4. **Never modify `lib/`** — read-only `git diff`/`git checkout` of the submodule is forbidden as a write; sync happens in the writable `workspace/` only.
5. **Distinguish fix from bit-rot**: a PoC that fails to *compile* is INCONCLUSIVE, never LIKELY-FIXED.
6. **Recheck is not discovery** — always remind the user it is blind to new issues; point to `/full-audit` for whole-change coverage.
