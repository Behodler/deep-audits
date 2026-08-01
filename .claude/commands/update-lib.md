---
model: claude-sonnet-4-6
---
Update a git submodule to its latest remote commit and commit the pointer bump at the repo root
# Purpose
Keep `lib/` submodules aligned with upstream by fetching the latest commit on the tracked branch, moving the submodule pointer, and recording the change in a root-level commit using the project's standard message format:

```
Update <submodule-dirname> to latest (<short-sha>)
```

# Arguments
- `$ARGUMENTS` format: `[name] [--branch <branch>] [--no-recursive]` (all optional)
- `name` may be either:
  - a friendly name from `registered-projects.json` (e.g., `yield-claim-nft`, `reflax-yield-vault`), resolved to its `submodule` field, OR
  - a raw submodule directory under `lib/` (e.g., `yield-claim-nft`, `reflax-yield-vault`)
- `--branch <branch>` (optional): **switch the submodule to `<branch>` and pull it**, instead of updating whatever branch it is currently parked on. Accept `--branch <b>`, `-b <b>`, and `--branch=<b>`. Only a branch that already exists on `origin` is accepted — this command **never creates a branch** locally or upstream (see Error Handling). When given, the branch becomes the project's `currentBranch` in `registered-projects.json`; when omitted, the submodule stays on its current branch and `currentBranch` is left alone. Authoritative semantics: `registered-projects.json` → `branchPolicy`.
  - `--branch` is **only valid with a specific `name`**. Reject it for the "all submodules" path — branch names are not shared across repos.
  - To go back to the trunk, pass the default branch explicitly (`/update-lib <name> --branch master`).
- `--no-recursive` (optional flag): when present, skip initializing/updating the submodule's own nested submodules. **Default is recursive** — we audit the latest version of each repo *and* its nested dependencies, so the full nested tree is synced unless this flag opts out. Accept common spellings (`--no-recursive`, `no-recursive`, `--shallow`) and strip the flag from the value before resolving `name`. (For back-compat, an explicit `--recursive`/`recursive` is accepted and simply confirms the default.)
- If `name` is omitted, the orchestrator MUST prompt the user to either:
  1. pick a specific submodule, or
  2. update all submodules under `lib/`

# Orchestration Flow

## 1. Parse Arguments
- First, detect and strip the optional recursion flag. `--no-recursive`/`no-recursive`/`--shallow` → `recursive = false`; an explicit `--recursive`/`recursive` → `recursive = true`; **absent → `recursive = true` (default)**.
- Then detect and strip the optional branch flag (`--branch <b>`, `-b <b>`, `--branch=<b>`) → `branch = <b>`; absent → `branch = null` (stay on the current branch). The remaining token(s) are the `name`.
- If `branch` is set but `name` is empty, or the user chose "all": **reject** — "`--branch` targets one submodule; branch names are not shared across repos." Ask which submodule they meant.
- If the remaining `name` is non-empty:
  - Treat it as the target name and proceed to step 2, passing `recursive` and `branch` through to the delegated task
- If `name` is empty:
  - List the directory entries under `lib/` plus the friendly-name mappings in `registered-projects.json`
  - Ask the user: "Update all submodules, or name a specific one?"
  - Wait for the user's choice before delegating
  - If the user picks "all", pass that intent (with `recursive`) to project-manager; otherwise resolve the chosen name

## 2. Delegate Update (single submodule)
Invoke **project-manager**: "Update submodule '<name>' to latest and commit at repo root"
- Resolve `<name>` to a submodule directory (`lib/<dirname>`) by:
  1. Looking up `projects.<name>.submodule` in `registered-projects.json`, else
  2. Treating `<name>` as the submodule directory itself
- Validate `lib/<dirname>` exists and is listed in `.gitmodules`
- Record the current (old) short SHA: `git -C lib/<dirname> rev-parse --short HEAD` and the current branch: `git -C lib/<dirname> rev-parse --abbrev-ref HEAD`
- Determine the **target branch**:
  - If `--branch <b>` was passed → `<b>` (an explicit switch; see "Branch switch" below)
  - Otherwise, in order of preference: `projects.<friendly>.currentBranch` → `projects.<friendly>.defaultBranch` → the `branch` key in `.gitmodules` for this submodule → the submodule's remote HEAD (`git -C lib/<dirname> remote show origin | awk '/HEAD branch/ {print $NF}'`)
- Fetch and fast-forward:
  1. `git -C lib/<dirname> fetch origin` (add `--prune` so branches deleted upstream disappear locally — this is what makes discarded-branch detection work)
  2. **Branch switch (only when `--branch` was passed and `<b>` differs from the current branch):**
     - Verify the branch exists upstream: `git -C lib/<dirname> rev-parse --verify origin/<b>`. **If it does not exist, ABORT** and list `git -C lib/<dirname> branch -r`. Never `checkout -b` a branch that has no upstream — see Critical Rules.
     - Verify the submodule working tree is clean (`git -C lib/<dirname> status --porcelain`); abort if not, exactly as for a normal update.
     - `git -C lib/<dirname> checkout <b>` (or `git -C lib/<dirname> checkout -b <b> --track origin/<b>` when no local branch exists yet — this only materialises an existing *remote* branch locally, it never invents one)
  3. `git -C lib/<dirname> checkout <branch>` (no-op when already there)
  4. `git -C lib/<dirname> pull --ff-only origin <branch>`
- Capture the new short SHA: `git -C lib/<dirname> rev-parse --short HEAD`
- **Unless `--no-recursive` was passed** (the default is recursive), after the pointer has moved, sync the submodule's own nested submodules: `git -C lib/<dirname> submodule update --init --recursive`. (With `--no-recursive`: skip this — leave nested submodules untouched.) A branch switch commonly moves nested pins, so this matters most here.
- **Record the branch in the registry (only when `--branch` was passed):** set `projects.<friendly>.currentBranch = <b>` and `projects.<friendly>.branchSwitchedAt = <now, ISO-8601>`. **Never** touch `defaultBranch` — it records the upstream trunk and is what abandonment and merge checks compare against. If the target is a raw submodule dirname with no registry entry, report that the switch was made but not recorded, and name the missing project.
- If old == new **and the branch did not change**: report "already up to date" and do NOT create a commit
- Otherwise:
  1. Stage ONLY the pointer move at root: `git add lib/<dirname>`
  2. Verify the staged diff only touches `lib/<dirname>` (no unrelated files)
  3. Commit at repo root with message exactly:
     - `Update <dirname> to latest (<new-short-sha>)` when on the default branch, or
     - `Update <dirname> to latest on <branch> (<new-short-sha>)` when on any other branch — the branch must be visible in root history, since the audit that follows is scoped to it
     - When `--branch` also changed `currentBranch`, stage `registered-projects.json` in the **same** commit (it is the record of which branch that pointer belongs to) and note the switch in the commit body: `Switched lib/<dirname> from <old-branch> to <branch>.`
  4. Do NOT use `--no-verify` or bypass hooks

### Branch-switch audit warning (MANDATORY)
When the branch actually changed, the delegated agent must also read `reports/ledgers/<friendly>.json` (if present) and report, without modifying it:
- the ledger's `branchBaselines.<new-branch>` entry — the last commit audited **on this branch** — or `(no baseline on this branch)` if absent
- that the next `/analyze` / `/full-audit` will baseline against `branchBaselines[<new-branch>]`, falling back to `git merge-base <new-branch> <defaultBranch>` when the branch has never been audited, so the regression delta covers exactly the branch's own commits
- how many ledger findings carry `branch == <old-branch>` and were **only** ever seen there — those are the entries that would become abandonment candidates if `<old-branch>` is discarded

Never diff or reconcile a scan on one branch against another branch's `lastAuditedCommit` (Law 1: the delta would silently hide code). See `registered-projects.json` → `branchPolicy.perBranchBaseline`.

## 3. Delegate Update (all submodules)
Invoke **project-manager**: "Update every submodule under lib/ to latest and commit each at repo root"
- Enumerate submodules from `.gitmodules`
- For each submodule, perform steps from section 2 (resolve branch, fetch, fast-forward, commit)
- Create one commit per submodule that actually moved (matches existing convention — see recent history)
- Continue through the list even if an individual submodule fails; collect errors and report at the end

## 4. Completion Report
Present to user:
- For each submodule processed: `<dirname>`, `<old-sha>` → `<new-sha>`, or `already up to date`, or `error: <reason>`
- The branch each submodule is now parked on, and — when it changed — `<old-branch>` → `<new-branch>` plus the branch-switch audit warning from section 2
- The list of commit SHAs created at the repo root
- Any skipped submodules and the reason

```
lib/phoenix-nft-staking   main → feat/nudge-v3     9611312 → 4ab77e1
  registry: currentBranch = feat/nudge-v3 (defaultBranch main unchanged)
  audit baseline on this branch: (none) → next scan baselines at merge-base with main (9611312)
  ledger: 14 findings seen only on `main`; they stay live (main is the trunk)
  root commit: Update phoenix-nft-staking to latest on feat/nudge-v3 (4ab77e1)
```

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
| Update single | project-manager | "Update submodule lib/{dirname} to latest on its tracked branch (recursive={true\|false}, default true — when true, also run `git -C lib/{dirname} submodule update --init --recursive` after the pointer moves; when false, leave nested submodules untouched). If HEAD moved, stage `lib/{dirname}` and commit at repo root with message `Update {dirname} to latest (<new-short-sha>)`. Skip if already up to date." |
| Switch branch | project-manager | "Switch submodule lib/{dirname} to existing upstream branch `{branch}` and fast-forward it (recursive={true\|false}). Abort if `origin/{branch}` does not exist or the tree is dirty; never create a branch. Set projects.{friendly}.currentBranch={branch} + branchSwitchedAt, leave defaultBranch untouched, and commit the pointer + registry together with message `Update {dirname} to latest on {branch} (<new-short-sha>)`. Then report the ledger's branchBaselines for {branch} and the count of findings seen only on the previous branch — read-only, do not modify the ledger." |
| Update all | project-manager | "For every submodule in .gitmodules, update to latest on its tracked branch (recursive={true\|false}, default true, applied to each). Commit each moved pointer at repo root with the standard message. Report per-submodule old→new SHAs and errors." |

# Error Handling
- **Name not found**: report that `<name>` matches neither a friendly name in `registered-projects.json` nor a directory under `lib/`, and list valid choices
- **Dirty working tree inside `lib/<dirname>`**: abort that submodule and report — do not force-discard changes
- **Staged diff touches files outside `lib/<dirname>`**: abort the commit and report; the user likely has unrelated staged work
- **Non-fast-forward upstream**: report the divergence and stop; do not attempt rebase or force
- **Detached HEAD with no tracked branch discoverable**: report and skip
- **`--branch <b>` where `origin/<b>` does not exist**: abort **without touching the working tree**. Report that `<b>` is not a branch on this repo's origin and list the remote branches (`git -C lib/<dirname> branch -r`). Do **not** create it, do **not** fall back to the default branch silently, and do **not** guess at a near-miss name — offer the closest matches and let the user re-run.
- **`--branch` with no name / with "all"**: reject and ask which submodule (branch names are per-repo).
- **`--branch` on a submodule with no registry entry**: perform the switch, but report clearly that `currentBranch` could not be recorded because `<name>` is not in `registered-projects.json` — subsequent audits will fall back to `.gitmodules` / remote HEAD and will not know the audit is branch-scoped.
- **Branch switch with a dirty submodule tree**: abort and report, same as any other update. Never `checkout -f` or stash.

# Critical Rules
1. **Recursive by default.** Always initialize/update nested submodules (`git submodule update --init --recursive` inside the source repo) so we audit the latest of the repo *and* its nested deps. Only skip this when the user passes `--no-recursive`.
2. **NEVER modify files inside source repos** — only move the submodule pointer from the outer repo
3. **Commit only the pointer change** — stage `lib/<dirname>` by path, never `git add -A`
4. **Never bypass hooks** (`--no-verify`, `--no-gpg-sign`) unless the user explicitly asks
5. One commit per submodule that moved; do not squash multi-submodule updates into a single commit
6. **`--branch` only ever follows an existing upstream branch.** Never `git branch`, `checkout -b` without `--track origin/<b>`, `push`, or otherwise create/alter refs in the source repo. We are moving our own read pointer, not doing the project's branching.
7. **`defaultBranch` is immutable here** — a branch switch writes `currentBranch`/`branchSwitchedAt` only. `defaultBranch` is the trunk that merged-branch and abandonment checks compare against; overwriting it would make a discarded feature branch look like the trunk.
8. **A branch switch is never silent.** The root commit message names the branch, and the completion report states which branch the submodule is now parked on plus its audit baseline on that branch.

# Examples
```
/update-lib yield-claim-nft
# Fetches lib/yield-claim-nft to latest on its tracked branch
# Commits at root: "Update yield-claim-nft to latest (<new-short-sha>)"

/update-lib yield-claim-nft
# Same as above — friendly name resolved via registered-projects.json -> submodule "yield-claim-nft"

/update-lib reflax-yield-vault
# Friendly name -> lib/reflax-yield-vault
# Commits: "Update reflax-yield-vault to latest (<new-short-sha>)"

/update-lib
# Orchestrator lists submodules and asks: "Update all, or name one?"
# Then delegates accordingly

/update-lib stable-yield-accumulator
# Fetches lib/stable-yield-accumulator to latest, then (recursive by default) syncs its
# nested submodules via `git -C lib/stable-yield-accumulator submodule update --init --recursive`
# Commits at root: "Update stable-yield-accumulator to latest (<new-short-sha>)"

/update-lib stable-yield-accumulator --no-recursive
# Same fast-forward + pointer-bump, but leaves nested submodules untouched (opt-out)

/update-lib phoenix-nft-staking --branch feat/nudge-v3
# Verifies origin/feat/nudge-v3 exists, checks it out, pulls --ff-only, syncs nested submodules
# Registry: currentBranch = "feat/nudge-v3", branchSwitchedAt = now (defaultBranch untouched)
# Commits at root: "Update phoenix-nft-staking to latest on feat/nudge-v3 (<sha>)"
# Findings from the next audit are tagged branch = "feat/nudge-v3"

/update-lib phoenix-nft-staking --branch main
# Switches back to the trunk; currentBranch = "main" again.
# If feat/nudge-v3 is then discarded upstream:
#   /ledger phoenix-nft-staking abandon-branch feat/nudge-v3
```
