Show how far each registered project's last audit lags behind upstream
# Purpose
Print a one-table-per-invocation summary of every project in `registered-projects.json` showing the last-audited commit, the current upstream HEAD on the tracked branch, and how many commits behind the audit is — so it's obvious which projects need a fresh `/full-audit` (or at least an `/update-lib` + re-scan).

This command is read-only. It never writes to ledgers, submodules, or the registry.

# Arguments
- `$ARGUMENTS` format: `[--no-fetch]`
- Default behaviour: fetch each submodule's tracked branch from `origin` before reporting, so "behind" is authoritative.
- `--no-fetch`: skip the fetch step and use whatever refs are already local. Faster and works offline, but may understate "behind" if you haven't fetched recently. Mark the output as `(no-fetch)` so the staleness is visible.

# Orchestration Flow

## 1. Parse Arguments
Detect the optional `--no-fetch` flag (also accept `no-fetch`, `--offline`). Default `fetch = true`.

## 2. Delegate
Invoke **project-manager**: "Build audit-status table for all registered projects (fetch=<true|false>)."

The project-manager performs the following for every entry in `registered-projects.json`:

### 2a. Resolve project
- Friendly name (lowercase-kebab key)
- `submodule` field → `lib/<submodule>`
- `defaultBranch` (fallback chain identical to `/update-lib`: `projects.<name>.defaultBranch` → `.gitmodules` `branch` → `git -C lib/<sub> remote show origin | awk '/HEAD branch/ {print $NF}'`)
- Skip the project with a clear note if `lib/<submodule>` does not exist on disk.

### 2b. Determine remote HEAD
- If `fetch = true`: `git -C lib/<sub> fetch --quiet origin <branch>` (do not modify the working tree; do **not** check out, pull, or merge).
- Then: `remoteHead = git -C lib/<sub> rev-parse origin/<branch>` (short via `--short`).
- On fetch failure (no network, auth issue), record an error string for that row and continue — do not abort the whole table.

### 2c. Determine last-audited commit
- Load `reports/ledgers/<friendly>.json` if it exists and read `lastAuditedCommit`.
- If the ledger is absent or has no `lastAuditedCommit`: record `(no ledger)` and skip the behind-count for that row. Do **not** fall back to the parent repo's submodule pointer — the pointer can be bumped without an audit, so it is not authoritative.
- Also surface `lastRun` from the ledger if present (e.g., `reflax-yield-vault-06`) so the row links to a specific report directory.

### 2d. Compute behind / ahead
For rows that have both an audited commit and a remote HEAD:
- `behind = git -C lib/<sub> rev-list --count <audited>..origin/<branch>` — how many upstream commits the audit has not yet seen.
- `ahead = git -C lib/<sub> rev-list --count origin/<branch>..<audited>` — non-zero if the audited commit is not an ancestor of upstream (e.g., upstream was force-pushed or the audit ran on a branch). Surface this as a warning, not a normal state.
- If `git cat-file -e <audited>` fails, the audited SHA is not present locally — record `(missing audited SHA)` and skip the count rather than guessing.
- Status label:
  - `up-to-date` when `behind == 0 && ahead == 0`
  - `<N> behind` when `behind > 0 && ahead == 0`
  - `diverged (+<ahead>/-<behind>)` when `ahead > 0`

## 3. Render Table
Print one table to stdout. Columns:

```
project              submodule                 branch    audited    upstream   behind        last run
─────────────────────────────────────────────────────────────────────────────────────────────────────
reflax-yield-vault        reflax-yield-vault        master    043ff2c    5f9abdd     7 behind     reflax-yield-vault-06
stable-yield-accumulator    stable-yield-accumulator  master    71abe3e    71abe3e    up-to-date    stable-yield-accumulator-11
phoenix-nft-staking          phoenix-nft-staking       master    (no ledger)  9d71401   —            phoenix-nft-staking-11
…
```

Notes for the renderer:
- Use the **friendly name** (registry key) in column 1, not the submodule directory.
- Short SHAs only (7 chars). Print the full SHA only on `--verbose` (future extension; not required now).
- If `--no-fetch` was passed, append ` (no-fetch — counts may be stale)` to the table header.
- Sort rows by `behind` descending so the most-lagging projects float to the top; `(no ledger)` and error rows sort last.
- After the table, print a one-line summary: e.g. `4 projects · 2 up-to-date · 1 behind · 1 no ledger`.

## 4. Do Not
- Do not modify the working tree, the submodule pointer, the ledger, or `registered-projects.json`.
- Do not check out branches inside submodules. `git fetch` only.
- Do not invoke `/full-audit` or `/update-lib` from this command — only report.
