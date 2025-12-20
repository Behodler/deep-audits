Move a submission to the rejected folder
# Purpose
Move a finding submission to the rejected folder when it is determined to be invalid, out of scope, or otherwise not suitable for submission.

# Arguments
- `$ARGUMENTS` format: `<project-name> <finding-id>`
- Example: `panoptic M-01`
- finding-id: The finding identifier (e.g., H-01, M-01, L-01)

# Orchestration Flow

## 1. Parse Arguments
Extract project name and finding ID from $ARGUMENTS:
- Validate project name exists in registered-projects.json
- Validate finding ID format (H-XX, M-XX, or L-XX)

## 2. Locate Submission
Invoke **finding-manager**: "Locate submission file for finding"
- Search in `reports/<project-name>/submissions/` for matching file
- Expected pattern: `<finding-id>-submission.md`
- If not found: Report error and list available submissions

## 3. Ensure Rejected Directory
Invoke **finding-manager**: "Ensure rejected directory exists"
- Create `reports/<project-name>/submissions/rejected/` if not exists

## 4. Move Submission
Invoke **finding-manager**: "Move submission to rejected folder"
- Move file from `reports/<project-name>/submissions/<finding-id>-submission.md`
- To `reports/<project-name>/submissions/rejected/<finding-id>-submission.md`

## 5. Update Finding Status (Optional)
Invoke **finding-manager**: "Update finding status to rejected"
- If finding JSON exists in `reports/<project-name>/findings/`, update status field

## 6. Completion Report
Present to user:
- Submission moved successfully
- New location path
- Reminder that file can be restored if needed

# Agent Delegation (MANDATORY)

**CRITICAL: This command MUST delegate to agents. Direct tool usage is FORBIDDEN.**

The orchestrating agent's ONLY permitted actions are:
1. Parse arguments from the command input
2. Invoke the finding-manager agent with specific tasks
3. Report results to the user

All file operations MUST be performed by the finding-manager agent.

## Required Delegations
| Task | Agent | Prompt Pattern |
|------|-------|----------------|
| Locate submission | finding-manager | "Find submission file for {finding-id} in project {project}" |
| Ensure directory | finding-manager | "Create rejected directory in reports/{project}/submissions/ if not exists" |
| Move file | finding-manager | "Move {finding-id}-submission.md to rejected folder for project {project}" |
| Update status | finding-manager | "Update status of {finding-id} to rejected in project {project}" |

# Error Handling
- **Project not found**: Report and list registered projects
- **Submission not found**: List available submissions in project
- **Already rejected**: Report that submission is already in rejected folder

# Examples
```
/reject-submission panoptic M-01
# Moves M-01-submission.md to reports/panoptic/submissions/rejected/

/reject-submission aave-v4 H-02
# Moves H-02-submission.md to reports/aave-v4/submissions/rejected/
```

# Recovery
To restore a rejected submission, manually move it back:
```bash
mv reports/<project>/submissions/rejected/<finding-id>-submission.md reports/<project>/submissions/
```
