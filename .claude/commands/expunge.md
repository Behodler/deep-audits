Completely remove a project and all traces from the repository
# Purpose
Orchestrate the complete removal of an auditable project from the repository. This includes removing the git submodule, all generated reports, findings, and registration data. After expunge, it should be as if the project never existed.

# Arguments
- `$ARGUMENTS` format: `<friendly-name>`
- Example: `pooltogether`
- The friendly name must match a registered project

# Orchestration Flow

## 1. Parse Arguments
Extract friendly name from $ARGUMENTS:
- Validate friendly name is provided
- Trim whitespace

## 2. Resolve Project
Invoke **project-manager**: "Resolve friendly name to get project details"
- Get submodule name from registered-projects.json
- If project not found: Report error and list registered projects
- Confirm project exists in lib/ directory

## 3. Confirm Removal
Present to user what will be removed (resolve the actual paths first):
- Submodule path: `lib/<submodule-name>`
- The project's report directory: `reports/<friendly-name>/` — every numbered run dir and the ledger it contains
- Workspace clone: `workspace/<friendly-name>/`
- Registration entry in registered-projects.json
- Ask for confirmation before proceeding (this is destructive)

## 4. Remove Git Submodule
Invoke **project-manager**: "Remove git submodule completely"
Steps to execute:
1. `git submodule deinit -f lib/<submodule-name>`
2. `git rm -f lib/<submodule-name>`
3. Remove `.git/modules/<submodule-name>` if it exists
- Report any errors during removal

## 5. Remove Reports, Ledger, and Workspace
Invoke **project-manager**: "Remove all run artifacts for project"
- Delete the project's report directory: `rm -rf reports/<friendly-name>/`. It holds every run dir (findings/, submissions/, pocs/, *.json) and `ledger.json`. Name the directory exactly — never a `reports/<friendly-name>*` prefix glob, which would also match a project whose name extends this one.
- Delete the workspace clone: `workspace/<friendly-name>/`.

## 6. Unregister Project
Invoke **project-manager**: "Remove project from registered-projects.json"
- Remove the project entry from the projects object
- Preserve other registered projects
- Write updated JSON back to file

## 7. Verify Clean State
Invoke **project-manager**: "Verify project has been completely removed"
- Confirm `lib/<submodule-name>` no longer exists
- Confirm `reports/<friendly-name>/` is gone, and no `workspace/<friendly-name>/`
- Confirm project not in registered-projects.json
- Check .gitmodules no longer references the submodule

## 8. Completion Report
Present to user:
- Submodule removed
- Reports deleted
- Registration removed
- Confirmation that project traces have been expunged

# Agent Delegation (MANDATORY)

**CRITICAL: This command MUST delegate to agents. Direct tool usage is FORBIDDEN.**

The orchestrating agent's ONLY permitted actions are:
1. Parse arguments from the command input
2. Invoke the project-manager agent with specific tasks
3. Report results to the user

All file operations, git operations, and directory deletion MUST be performed by the project-manager agent, not the orchestrating agent.

**If you find yourself using Bash, Read, Write, Glob, or Grep directly in this command, STOP. You are violating the architecture.**

## Required Delegations
| Task | Agent | Prompt Pattern |
|------|-------|----------------|
| Resolve project | project-manager | "Resolve friendly name '{name}' to get submodule path and project details" |
| Remove submodule | project-manager | "Remove git submodule at lib/{submodule} completely (deinit, rm, clean modules)" |
| Remove artifacts | project-manager | "Remove reports/{name}/ and workspace/{name}/" |
| Unregister | project-manager | "Remove project '{name}' from registered-projects.json" |
| Verify removal | project-manager | "Verify project '{name}' has been completely expunged" |

# Error Handling
- **Project not found**: Report error and list available projects
- **Submodule removal fails**: Report git error, suggest manual cleanup
- **Permission denied**: Report and suggest running with appropriate permissions
- **Partial failure**: Report what was removed and what remains

# Examples
```
/expunge phoenix-nft-staking
# Removes lib/phoenix-nft-staking, reports/phoenix-nft-staking/ (runs + ledger),
# workspace/phoenix-nft-staking/, and registration
```

# Critical Rules
1. **Confirm before destruction** - Always show what will be deleted and get confirmation
2. **Complete removal** - All traces must be removed (submodule, reports, registration)
3. **Preserve other projects** - Only remove the specified project
4. **Report failures** - If any step fails, report what was and wasn't removed
