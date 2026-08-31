Add an auditable project as a git submodule, named after its upstream repository
# Purpose
Orchestrate adding a new auditable project to the repository. **A project is always named after its upstream repo directory** — the submodule directory name, the registry key, the report-dir family, the ledger filename, and the workspace dir are all the same canonical string. There is no separate "friendly name"; project name and repo name must agree.

# Arguments
- `$ARGUMENTS` format: `<repo-url>`
- Example: `https://github.com/Behodler/phoenix-nft-staking`
- The project name is **derived from the repo**, not supplied by the caller.

# Orchestration Flow

## 1. Parse Arguments & Derive Name
Extract the repo URL from $ARGUMENTS:
- Validate URL format (must be valid git URL).
- **Derive the canonical project name from the repo**: take the last path segment of the URL and strip a trailing `.git` (e.g. `https://github.com/Behodler/phoenix-nft-staking[.git]` → `phoenix-nft-staking`). Do **not** strip or rewrite the name beyond that — it must match the upstream repo exactly so the submodule directory and the project name are identical.
- Reject a URL whose derived name is not lowercase-kebab; do not silently transform it (ask the user to confirm the upstream repo name instead of inventing a divergent alias).

## 2. Check for Conflicts
Invoke **project-manager**: "Check if project name already registered"
- If name exists: Present error and report the existing mapping.
- If URL already added: Report existing registration.

## 3. Add Submodule
Invoke **project-manager**: "Add submodule and initialize its nested tree recursively"
- Command: `git submodule add <repo-url> lib/<repo-name>` then `git -C lib/<repo-name> submodule update --init --recursive`
- **CRITICAL**: Pull the full nested submodule tree — we audit the latest version of the repo *and* its dependencies, not a frozen pin
- The `lib/` directory name MUST equal the derived project name.
- Verify submodule added successfully
- Report any errors (repo not found, permission denied, etc.)

## 4. Register Project
Invoke **project-manager**: "Register project under its repo name"
- Update registered-projects.json (the key equals the submodule directory name):
  ```json
  {
    "projects": {
      "<repo-name>": {
        "submodule": "<repo-name>",
        "repoUrl": "<repo-url>",
        "defaultBranch": "main",
        "addedAt": "<ISO-timestamp>"
      }
    }
  }
  ```
- The `submodule` field is retained for backwards compatibility and MUST equal the key.

## 5. Discover Scope (default-in-scope)
Invoke **project-manager**: "Discover contracts and scope for project"
- Scope is a **denylist**: every first-party `.sol` is in scope except the project's nested `lib/**` (see `registered-projects.json` → `scopePolicy`). No allowlist curation is required to start auditing.
- List all first-party `.sol` (`git -C lib/<name> ls-files '*.sol'` minus `lib/**`) and write it to the `scope` array as a **cached snapshot** (advisory; the live computed set is authoritative).
- Optionally record README "In Scope" hints into `scopeFocus`, but never use them to *narrow* the gate — README under-scoping must not hide a first-party contract.
- Leave `outOfScope` empty by default (only `lib/**` is excluded); a human may add extra exclusions later.

## 6. Extract Known Issues
Invoke **project-manager**: "Extract known issues from project documentation"
- Parse README for "Known Issues", "Known Limitations", "Out of Scope"
- Check for dedicated known-issues.md file
- Check for bot-report.md if present
- Store known issues path in registration

## 7. Initialize Ledger
Create `reports/<repo-name>/` and an empty persistent ledger inside it, so the first run is treated as a full cold scan:
```
reports/<repo-name>/ledger.json   →  { "project": "<repo-name>", "lastAuditedCommit": null, "findings": [] }
```
Run directories (`reports/<repo-name>/XX/`) are created per-run by `/analyze`, not here.

## 8. Completion Report
Present to user:
- Project name (= upstream repo name)
- Submodule location
- Number of contracts in scope
- Number of known issues found
- Next step: suggest `/analyze <repo-name>`

# Agent Delegation (MANDATORY)

**CRITICAL: This command MUST delegate to agents. Direct tool usage is FORBIDDEN.**

The orchestrating agent's ONLY permitted actions are:
1. Parse arguments from the command input
2. Invoke the project-manager agent with specific tasks
3. Report results to the user

All file operations, git operations, and data extraction MUST be performed by the project-manager agent, not the orchestrating agent.

**If you find yourself using Bash, Read, Write, Glob, or Grep directly in this command, STOP. You are violating the architecture.**

## Required Delegations
| Task | Agent | Prompt Pattern |
|------|-------|----------------|
| Check conflicts | project-manager | "Check if project '{name}' or URL '{url}' already registered" |
| Add submodule | project-manager | "Add submodule {url} to lib/{name} and run `git -C lib/{name} submodule update --init --recursive`" |
| Register project | project-manager | "Register project '{name}' with submodule '{name}' and URL '{url}'" |
| Discover scope | project-manager | "Discover contracts and scope for project in lib/{name}" |
| Extract known issues | project-manager | "Extract known issues from documentation in lib/{name}" |
| Initialize ledger | project-manager | "Initialize empty ledger for '{name}'" |

# Error Handling
- **Invalid URL**: Report and ask for correction
- **Name conflict**: Report the existing registration (do not auto-suffix — a project maps 1:1 to a repo)
- **Clone failure**: Report git error with suggestions
- **No README scope section**: not an error — default-in-scope already covers all first-party .sol; record the full list as the snapshot
- **Non-kebab repo name**: Ask the user to confirm the upstream name rather than inventing an alias

# Examples
```
/add-project https://github.com/Behodler/phoenix-nft-staking
# Adds lib/phoenix-nft-staking, registers project "phoenix-nft-staking"

/add-project https://github.com/Behodler/reflax-yield-vault
# Adds lib/reflax-yield-vault, registers project "reflax-yield-vault"
```

# Critical Rules
1. **Project name == repo name == submodule dir** — never diverge; there is no alias argument
2. **ALWAYS use --recursive** when adding submodules — audit the latest of the repo and its nested deps
3. **NEVER modify source repos** after cloning
4. **Preserve original state** of cloned repositories
