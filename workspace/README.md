# Workspace Directory

This directory contains writable clones of source repos for PoC development.

## Purpose

- Source repos in `lib/` are read-only git submodules (for audit integrity)
- PoCs often need project test infrastructure (harnesses, mocks, fork config)
- C4 expects PoCs that can be dropped into project's `test/` directory
- Workspace enables full project-integrated PoC development

## Structure

```
workspace/
  panoptic/              # Clone of lib/2025-12-panoptic
    test/
      poc-H-01.t.sol     # Our PoC (uses project imports)
      poc-H-02.t.sol
      ...existing tests...
  moonwell/              # Clone of lib/moonwell-bug-bounty
    test/
      poc-CRIT-01.t.sol
      ...
```

## How It Works

1. `/full-audit <project> [bounty]` automatically creates workspace if needed
2. Workspace is cloned from same URL as the submodule (shallow clone)
3. Remote is removed to prevent accidental pushes
4. PoCs are written to `workspace/<project>/test/poc-*.t.sol`

## Running PoCs

```bash
cd workspace/panoptic
forge test --match-path test/poc-H-01.t.sol -vvv
```

## Git Status

- `workspace/*/` directories are `.gitignore`d
- Only this README and .gitkeep are tracked
- Workspace is recreated per-machine when needed

## PoC Naming Convention

- `poc-H-01.t.sol` - High severity finding 1
- `poc-M-02.t.sol` - Medium severity finding 2
- `poc-CRIT-01.t.sol` - Critical severity finding 1 (bounty)

This naming keeps PoCs at the same directory level as project tests,
ensuring import paths like `import "../src/Contract.sol"` work correctly.
