Add an auditable project as a git submodule with friendly name mapping
# Purpose
Orchestrate adding a new auditable project to the repository with a friendly name alias.

# Arguments
- `$ARGUMENTS` format: `<repo-url> [friendly-name]`
- Example: `https://github.com/Behodler/phoenix-nft-staking nft-staking`
- If friendly-name omitted, derive from repo name.

# Orchestration Flow

## 1. Parse Arguments
Extract repo URL and friendly name from $ARGUMENTS:
- Validate URL format (must be valid git URL).
- If no friendly name provided: derive from repo name (strip dates, "-c4", "-audit", etc.).
- **Normalize the friendly name to lowercase-kebab** (lowercase, spaces/underscores → `-`). This prevents divergent report trees.

## 2. Check for Conflicts
Invoke **project-manager**: "Check if friendly name already registered"
- If name exists: Present error and suggest alternatives
- If URL already added: Report existing mapping

## 3. Add Submodule
Invoke **project-manager**: "Add submodule without recursive flag"
- Command: `git submodule add <repo-url> lib/<repo-name>`
- **CRITICAL**: Never use --recursive flag
- Verify submodule added successfully
- Report any errors (repo not found, permission denied, etc.)

## 4. Register Project
Invoke **project-manager**: "Register project with friendly name"
- Update registered-projects.json:
  ```json
  {
    "projects": {
      "<friendly-name>": {
        "submodule": "<repo-directory-name>",
        "repoUrl": "<repo-url>",
        "defaultBranch": "main",
        "addedAt": "<ISO-timestamp>"
      }
    }
  }
  ```

## 5. Discover Scope
Invoke **project-manager**: "Discover contracts and scope for project"
- Find README.md and extract "In Scope" section
- List all .sol files in src/, contracts/, or root
- Identify main contracts vs. libraries/interfaces
- Update registered-projects.json with scope array

## 6. Extract Known Issues
Invoke **project-manager**: "Extract known issues from project documentation"
- Parse README for "Known Issues", "Known Limitations", "Out of Scope"
- Check for dedicated known-issues.md file
- Check for bot-report.md if present
- Store known issues path in registration

## 7. Initialize Ledger
Create an empty persistent ledger so the first run is treated as a full cold scan:
```
reports/ledgers/<friendly-name>.json   →  { "project": "<name>", "lastAuditedCommit": null, "findings": [] }
```
Run directories (`reports/<friendly-name>-XX/`) are created per-run by `/analyze`, not here.

## 8. Completion Report
Present to user:
- Friendly name registered (lowercase-kebab)
- Submodule location
- Number of contracts in scope
- Number of known issues found
- Next step: suggest `/analyze <friendly-name>`

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
| Check conflicts | project-manager | "Check if friendly name '{name}' or URL '{url}' already registered" |
| Add submodule | project-manager | "Add submodule {url} to lib/{dirname} without --recursive flag" |
| Register project | project-manager | "Register project '{name}' with submodule '{dirname}' and URL '{url}'" |
| Discover scope | project-manager | "Discover contracts and scope for project in lib/{dirname}" |
| Extract known issues | project-manager | "Extract known issues from documentation in lib/{dirname}" |
| Initialize ledger | project-manager | "Initialize empty ledger for '{name}'" |

# Error Handling
- **Invalid URL**: Report and ask for correction
- **Name conflict**: Suggest alternative names
- **Clone failure**: Report git error with suggestions
- **No scope found**: Warn and default to all .sol files

# Examples
```
/add-project https://github.com/Behodler/phoenix-nft-staking nft-staking
# Adds phoenix-nft-staking as submodule, registers as "nft-staking"

/add-project https://github.com/Behodler/reflax-yield-vault
# Adds repo, derives friendly name "reflax-yield-vault"
```

# Critical Rules
1. **NEVER use --recursive** when adding submodules
2. **NEVER modify source repos** after cloning
3. **Validate friendly names** before registration
4. **Preserve original state** of cloned repositories
