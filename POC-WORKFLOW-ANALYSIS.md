# PoC Workflow Analysis: Solving the Read-Only Submodule Problem

**Date:** 2026-01-06
**Author:** Claude Code Analysis
**Status:** ✅ IMPLEMENTED

## Problem Statement

C4 expects PoCs that can be "dropped into" the target project's test suite and run immediately. However, our current architecture uses git submodules for source repos which are strictly read-only (for audit integrity). This creates a tension:

- **Current approach**: Standalone PoCs that only import `forge-std/Test.sol` and inline all dependencies
- **Limitation**: Complex findings that need project test harnesses, mocks, or fork infrastructure require manual validation
- **Example**: H-01 and H-02 in panoptic-01 are marked `NEEDS_MANUAL_VALIDATION` because they require `RiskEngineHarness` and `MockCollateralTracker`

## Alternatives Analyzed

### Option 1: Copy Repo, Delete `.git`

**Mechanism**: Copy the entire source repo into `reports/<project>/code/` and delete the `.git` directory.

**Pros**:
- Simple to implement
- No git conflicts or remote push risks
- Can freely modify files

**Cons**:
- **No diff visibility**: Hard to see what changed vs original
- **No change tracking**: PoC additions not tracked in git
- **Large duplication**: Full repo copy per project
- **Sync issues**: If source updates, workspace is stale

**Implementation Effort**: Low
**Workflow Changes**: Minimal

---

### Option 2: Clone Repo, Remove Remote

**Mechanism**: Clone the repo into `reports/<project>/workspace/`, then run `git remote remove origin` to prevent accidental pushes.

**Pros**:
- Full git history preserved
- Can commit PoC additions locally
- Easy to diff workspace vs pristine submodule
- No accidental push to original

**Cons**:
- Code duplication (though smaller than Option 1 due to git)
- Need to manage two copies (submodule + workspace)
- Workspace commits mixed with original history

**Implementation Effort**: Low
**Workflow Changes**: Moderate

---

### Option 3: Fork, Clone Locally

**Mechanism**: Fork the repo on GitHub, clone the fork into workspace.

**Pros**:
- Full git functionality including push
- Clear attribution of PoC work
- Can share PoCs via PR to fork

**Cons**:
- **Automation complexity**: Forking requires GitHub API (gh repo fork)
- **Public visibility**: Forks may be public, revealing findings before disclosure
- **Account coupling**: Requires authenticated GH operations
- **Private repo issues**: C4 repos are often private during competition

**Implementation Effort**: High
**Workflow Changes**: Significant

---

### Option 4: Foundry Remappings (Enhanced Current Approach)

**Mechanism**: Keep submodules read-only, use advanced remappings to make tests in `reports/` reference submodule code.

**Pros**:
- No code duplication
- Submodule stays pristine
- Single source of truth

**Cons**:
- **Infrastructure gap**: Can't use project test harnesses without copying them
- **Import path hell**: Complex remapping for nested imports
- **Doesn't solve the problem**: PoCs still can't be dropped into project test suite

**Implementation Effort**: Medium
**Workflow Changes**: None (but doesn't solve the core issue)

---

### Option 5: Working Copy Pattern (Recommended)

**Mechanism**: Hybrid approach maintaining both pristine reference and writable workspace.

**Structure**:
```
lib/                           <- Pristine submodules (read-only, audit reference)
  2025-12-panoptic/

workspace/                     <- Working copies for PoC development
  panoptic/                    <- Clone of same repo
    test/
      poc-H-01.t.sol           <- PoCs in test/ directly (same import depth)
      poc-H-02.t.sol
      existing-project-test.t.sol  <- Project's original tests
```

**Why `test/` not `test/pocs/`**: Import paths must match C4 expectations. A test in `test/pocs/` would need `../../src/Contract.sol` instead of `../src/Contract.sol`, breaking the drop-in requirement. Using a `poc-*.t.sol` naming convention keeps imports correct while distinguishing our files.

**Workflow**:
1. `lib/<project>` remains pristine submodule (never touched)
2. `workspace/<project>` is a clone with remote removed
3. PoCs developed in `workspace/<project>/test/poc-*.t.sol`
4. Tests run naturally: `cd workspace/panoptic && forge test --match-path test/poc-H-01*.sol`
5. For submission: PoCs are ready to copy-paste or provide as diff

**Git Management Options**:

| Approach | Pros | Cons |
|----------|------|------|
| **A. `.gitignore` workspace/** | Simple, no clutter | Must recreate workspace per machine |
| **B. Commit workspace (exclude .git)** | Portable, PoCs tracked | Large commits, noise |
| **C. Track only test/pocs/** | Clean, focused | Complex .gitignore rules |

**Recommendation**: Option A (`.gitignore workspace/`) with a setup script.

**Pros**:
- PoCs can use full project infrastructure
- Clean separation: pristine reference vs working copy
- Easy diffing: `diff lib/panoptic/src/Contract.sol workspace/panoptic/src/Contract.sol`
- Submission-ready: PoCs work as-is in project context
- Audit integrity preserved: submodule is untouched

**Cons**:
- Disk duplication (mitigated by shallow clones)
- Setup step required per project
- Must sync if source changes during audit

**Implementation Effort**: Medium
**Workflow Changes**: Moderate

---

### Option 6: Git Worktree

**Mechanism**: Use `git worktree` to create a linked working tree of the submodule.

**Pros**:
- No full clone needed
- Git-native feature

**Cons**:
- **Worktrees are linked**: Changes in worktree affect submodule state
- **Submodule complexity**: Worktrees of submodules behave strangely
- **Not isolated**: Defeats the read-only guarantee

**Implementation Effort**: Medium
**Workflow Changes**: Significant
**Verdict**: Not recommended due to linkage issues

---

## Recommendation: Option 5 (Working Copy Pattern)

### Why This Approach

1. **Maintains audit integrity**: `lib/` submodules remain pristine and can be verified against C4 source
2. **Enables full PoC capability**: Workspace has all project infrastructure (harnesses, mocks, fork config)
3. **Submission-ready**: PoCs written in `workspace/<project>/test/pocs/` are directly usable
4. **Clear separation**: Easy to distinguish audit reference from working code
5. **Diffable**: Can compare workspace modifications against pristine submodule

### Implementation Plan

#### Phase 1: Add Workspace Infrastructure

**New directory structure**:
```
workspace/           <- New top-level directory
  .gitkeep           <- Placeholder so dir exists
  README.md          <- Instructions for workspace setup
```

**Update `.gitignore`**:
```gitignore
# Workspace directories (recreated per machine)
workspace/*/
!workspace/.gitkeep
!workspace/README.md
```

#### Phase 2: Create Setup Script/Command

New skill: `/setup-workspace <project>` that:

1. Looks up project in registered-projects.json
2. Gets the original git URL from submodule config
3. Creates `workspace/<project>/` via shallow clone
4. Removes remote: `git remote remove origin`
5. Creates `test/pocs/` directory
6. Copies `foundry.toml` if needed for fork config
7. Reports success with instructions

**Script pseudocode**:
```bash
#!/bin/bash
PROJECT=$1
SUBMODULE_PATH="lib/$PROJECT"

# Get original URL from submodule
URL=$(git config --file .gitmodules submodule."$SUBMODULE_PATH".url)

# Shallow clone into workspace
git clone --depth 1 "$URL" "workspace/$PROJECT"

# Remove remote to prevent accidental push
cd "workspace/$PROJECT"
git remote remove origin

echo "Workspace ready: workspace/$PROJECT"
echo "Add PoCs to: workspace/$PROJECT/test/poc-*.t.sol"
```

#### Phase 3: Update PoC Generator Agent

Modify `poc-generator.md` to:

1. Check if `workspace/<project>` exists
2. If yes: Write PoCs to `workspace/<project>/test/poc-<label>.t.sol`
3. If no: Fall back to standalone PoC in `reports/<project>/pocs/`
4. Update validation to run from workspace context

**Decision tree for PoC type**:
```
Is vulnerability demonstrable with pure math/logic?
├─ Yes → Standalone PoC (only forge-std/Test.sol)
└─ No → Does workspace/<project> exist?
    ├─ Yes → Project-integrated PoC
    └─ No → Request /setup-workspace or fall back to standalone
```

#### Phase 4: Update Report Generator

When generating submission reports:
1. If PoC is in workspace: Provide as diff or copy
2. If PoC is standalone: Include directly
3. Add instructions for evaluator if workspace-based

### Export for Submission

For workspace-based PoCs, provide two formats:

**Format A: As diff**
```bash
cd workspace/panoptic
git diff HEAD -- test/poc-H-01.t.sol > H-01.patch
```
Evaluator applies: `git apply H-01.patch`

**Format B: As file with instructions**
```
## PoC for H-01

Save the following to `test/poc-H-01.t.sol` and run:
```bash
forge test --match-contract H01PoCTest -vvv
```

[PoC code here]
```

### Migration Path

**Existing projects**: No change needed. Current standalone PoCs continue to work.

**New projects**:
1. Run `/add-project <name>` (adds submodule as before)
2. Run `/setup-workspace <name>` (creates writable workspace)
3. Develop PoCs in workspace

**Hybrid approach**: Some findings (pure math) can still use standalone PoCs. Complex findings use workspace.

---

## Comparison Matrix

| Criterion | Opt 1: Copy | Opt 2: Clone, no remote | Opt 3: Fork | Opt 4: Remappings | **Opt 5: Working Copy** |
|-----------|-------------|-------------------------|-------------|-------------------|-------------------------|
| Audit integrity | Good | Good | Medium | Best | Best |
| Full PoC capability | Yes | Yes | Yes | Limited | Yes |
| Submission-ready | No | Partial | Yes | No | Yes |
| Implementation effort | Low | Low | High | Medium | Medium |
| Automation friendly | Yes | Yes | Complex | Yes | Yes |
| Diff visibility | Poor | Good | Good | N/A | Good |
| Disk usage | High | Medium | Medium | None | Medium |

---

## Files to Modify

1. **New file**: `workspace/README.md` - Setup instructions
2. **Update**: `.gitignore` - Add workspace rules
3. **Update**: `.claude/agents/poc-generator.md` - Add workspace awareness
4. **New skill**: `.claude/commands/setup-workspace.md` - Workspace creation
5. **Update**: `CLAUDE.md` - Document new workflow

---

## Conclusion

**Option 5 (Working Copy Pattern)** provides the best balance:

- Preserves the audit integrity guarantee of read-only submodules
- Enables PoCs that use full project infrastructure
- Produces submission-ready PoCs that work in project context
- Requires moderate implementation effort
- Is automatable via a new `/setup-workspace` command

The key insight is that we don't need to choose between pristine reference and workable PoC environment—we can have both. The submodule in `lib/` serves as the audit reference, while the workspace clone enables practical PoC development.

### Implementation Complete

The following files have been updated:

1. **`.claude/agents/project-manager.md`** - Added workspace management methods:
   - `create_workspace(friendly_name)` - Creates workspace from submodule URL
   - `get_workspace(friendly_name)` - Checks if workspace exists
   - `workspace_exists(friendly_name)` - Boolean check

2. **`.claude/commands/full-audit.md`** - Added Step 1.3: Workspace Setup
   - Automatically creates workspace if not exists when running `/full-audit`
   - Displays workspace path in summary output
   - PoC paths now point to `workspace/<project>/test/poc-*.t.sol`

3. **`.claude/agents/poc-generator.md`** - Updated for workspace-first approach:
   - Checks for workspace before generating PoC
   - If workspace exists: writes to `workspace/<project>/test/poc-<label>.t.sol`
   - If no workspace: falls back to standalone PoC in `reports/<project>/pocs/`
   - Updated workflow, naming conventions, and validation steps

4. **`workspace/`** directory - To be created on first use (`.gitignore`d)

### Usage

```bash
# Running full-audit automatically sets up workspace
/full-audit moonwell bounty

# Or manually create workspace
# (project-manager will clone from submodule URL, remove remote)
```

### Next Steps (Manual)

1. Add `workspace/` to `.gitignore`
2. Test with existing bounty project (e.g., moonwell)
3. Verify H-01/H-02 panoptic findings work with project harnesses
