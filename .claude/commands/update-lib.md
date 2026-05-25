Update a git submodule to its latest remote commit and commit the pointer bump at the repo root
# Purpose
Keep `lib/` submodules aligned with upstream by fetching the latest commit on the tracked branch, moving the submodule pointer, and recording the change in a root-level commit using the project's standard message format:

```
Update <submodule-dirname> to latest (<short-sha>)
```

# Arguments
- `$ARGUMENTS` format: `[name]` (optional)
- `name` may be either:
  - a friendly name from `registered-projects.json` (e.g., `yield-claim-nft`, `phoenix-vault`), resolved to its `submodule` field, OR
  - a raw submodule directory under `lib/` (e.g., `yield-claim-nft`, `reflax-yield-vault`)
- If omitted, the orchestrator MUST prompt the user to either:
  1. pick a specific submodule, or
  2. update all submodules under `lib/`

# Orchestration Flow

## 1. Parse Arguments
- If `$ARGUMENTS` is non-empty:
  - Treat it as the target name and proceed to step 2
- If `$ARGUMENTS` is empty:
  - List the directory entries under `lib/` plus the friendly-name mappings in `registered-projects.json`
  - Ask the user: "Update all submodules, or name a specific one?"
  - Wait for the user's choice before delegating
  - If the user picks "all", pass that intent to project-manager; otherwise resolve the chosen name

## 2. Delegate Update (single submodule)
Invoke **project-manager**: "Update submodule '<name>' to latest and commit at repo root"
- Resolve `<name>` to a submodule directory (`lib/<dirname>`) by:
  1. Looking up `projects.<name>.submodule` in `registered-projects.json`, else
  2. Treating `<name>` as the submodule directory itself
- Validate `lib/<dirname>` exists and is listed in `.gitmodules`
- Record the current (old) short SHA: `git -C lib/<dirname> rev-parse --short HEAD`
- Determine the tracked branch, in order of preference:
  1. `projects.<friendly>.defaultBranch` from `registered-projects.json`
  2. The `branch` key in `.gitmodules` for this submodule, if any
  3. The submodule's remote HEAD (`git -C lib/<dirname> remote show origin | awk '/HEAD branch/ {print $NF}'`)
- Fetch and fast-forward (NEVER use `--recursive`):
  1. `git -C lib/<dirname> fetch origin`
  2. `git -C lib/<dirname> checkout <branch>`
  3. `git -C lib/<dirname> pull --ff-only origin <branch>`
- Capture the new short SHA: `git -C lib/<dirname> rev-parse --short HEAD`
- If old == new: report "already up to date" and do NOT create a commit
- Otherwise:
  1. Stage ONLY the pointer move at root: `git add lib/<dirname>`
  2. Verify the staged diff only touches `lib/<dirname>` (no unrelated files)
  3. Commit at repo root with message exactly: `Update <dirname> to latest (<new-short-sha>)`
  4. Do NOT use `--no-verify` or bypass hooks

## 3. Delegate Update (all submodules)
Invoke **project-manager**: "Update every submodule under lib/ to latest and commit each at repo root"
- Enumerate submodules from `.gitmodules`
- For each submodule, perform steps from section 2 (resolve branch, fetch, fast-forward, commit)
- Create one commit per submodule that actually moved (matches existing convention — see recent history)
- Continue through the list even if an individual submodule fails; collect errors and report at the end

## 4. Completion Report
Present to user:
- For each submodule processed: `<dirname>`, `<old-sha>` → `<new-sha>`, or `already up to date`, or `error: <reason>`
- The list of commit SHAs created at the repo root
- Any skipped submodules and the reason

# Agent Delegation (MANDATORY)

**CRITICAL: This command MUST delegate to agents. Direct tool usage is FORBIDDEN for submodule and git operations.**

The orchestrating agent's ONLY permitted actions are:
1. Parse `$ARGUMENTS`
2. When no argument is given, prompt the user and list available submodules
3. Invoke the **project-manager** agent with a specific task
4. Report results to the user

All git operations (fetch, checkout, pull, add, commit), filesystem inspection of `lib/`, and reads of `registered-projects.json` / `.gitmodules` needed to drive the update MUST be performed by the project-manager agent, not the orchestrator.

**If you find yourself using Bash, Read, Write, Glob, or Grep directly in this command, STOP. You are violating the architecture.**

## Required Delegations
| Task | Agent | Prompt Pattern |
|------|-------|----------------|
| Resolve name | project-manager | "Resolve '{name}' to a submodule directory under lib/ using registered-projects.json; fall back to raw dirname" |
| Update single | project-manager | "Update submodule lib/{dirname} to latest on its tracked branch (no --recursive). If HEAD moved, stage `lib/{dirname}` and commit at repo root with message `Update {dirname} to latest (<new-short-sha>)`. Skip if already up to date." |
| Update all | project-manager | "For every submodule in .gitmodules, update to latest on its tracked branch (no --recursive). Commit each moved pointer at repo root with the standard message. Report per-submodule old→new SHAs and errors." |

# Error Handling
- **Name not found**: report that `<name>` matches neither a friendly name in `registered-projects.json` nor a directory under `lib/`, and list valid choices
- **Dirty working tree inside `lib/<dirname>`**: abort that submodule and report — do not force-discard changes
- **Staged diff touches files outside `lib/<dirname>`**: abort the commit and report; the user likely has unrelated staged work
- **Non-fast-forward upstream**: report the divergence and stop; do not attempt rebase or force
- **Detached HEAD with no tracked branch discoverable**: report and skip

# Critical Rules
1. **NEVER use `--recursive`** when fetching/updating submodules (see CLAUDE.md)
2. **NEVER modify files inside source repos** — only move the submodule pointer from the outer repo
3. **Commit only the pointer change** — stage `lib/<dirname>` by path, never `git add -A`
4. **Never bypass hooks** (`--no-verify`, `--no-gpg-sign`) unless the user explicitly asks
5. One commit per submodule that moved; do not squash multi-submodule updates into a single commit

# Examples
```
/update-lib yield-claim-nft
# Fetches lib/yield-claim-nft to latest on its tracked branch
# Commits at root: "Update yield-claim-nft to latest (<new-short-sha>)"

/update-lib yield-claim-nft
# Same as above — friendly name resolved via registered-projects.json -> submodule "yield-claim-nft"

/update-lib phoenix-vault
# Friendly name -> lib/reflax-yield-vault
# Commits: "Update reflax-yield-vault to latest (<new-short-sha>)"

/update-lib
# Orchestrator lists submodules and asks: "Update all, or name one?"
# Then delegates accordingly
```
