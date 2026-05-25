# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This repository contains the audit tooling used to review the Phoenix/Behodler smart-contract suite. Findings are written in a format compatible with Code4rena (C4) conventions so the same artefacts can be repurposed if a Phoenix component is ever submitted to a public audit; treat the C4 framing as an output spec, not a contest goal.

## Terminology

- **Source repo** - A repository containing the Solidity project to be audited. Source repos are added as git submodules in `lib/`.

## Critical Rules

**Source repos are strictly read-only.** Never modify files in source repos. Never commit to source repos. They must remain exactly as cloned from the upstream Behodler-org repository.

**Never use recursive submodule commands.** When adding or updating source repos, do not use `--recursive` flag. We must experience the repo exactly as the original developers intended, without pulling nested dependencies.

## Architecture

### Directory Structure
- `lib/` - Git submodules containing auditable Solidity projects (read-only audit references)
- `workspace/<project>/` - Writable clones for PoC/test development (gitignored; PoCs and Tier-3 tests live here)
- `reports/<project>-XX/` - Per-run audit output, sequentially versioned
- `reports/ledgers/<project>.json` - Persistent findings ledger (open/fixed/triaged across runs)
- `patterns/` - Vulnerability pattern database
- `tools/` - Cloned auditing tools (e.g. 4naly3er)
- `documentation/` - C4 official documentation for reference

### Tooling
The `.claude/hooks/session-start.sh` SessionStart hook provisions the deterministic toolchain (idempotent, network-failure-safe): Foundry, Slither, Halmos, Aderyn, Medusa, Semgrep, and 4naly3er, plus `git submodule update --init`. The pipeline degrades gracefully when a tool is missing.

### Multi-Agent Workflow
Custom Claude Code commands orchestrate specialized agents in tiers:
1. **Tier 1 (local + deterministic)** - contract-profiler, static-analyzer (Slither + Aderyn + Semgrep), pattern-matcher
2. **Tier 2 (interaction)** - code-scanner, econ-scanner (LLM reasoning over profiles)
3. **Tier 3 (verification)** - invariant-generator (forge + Medusa/Echidna), symbolic-analyzer (Halmos)
4. **Filtering** - deduplicator, then sanitizer (known issues + ledger reconciliation)
5. **Output** - severity-classifier, finding-manager (writes run dir + upserts ledger), poc-generator, report-writer, qa-bundler

### Re-running an audit (regression mode)
Re-running `/analyze <project>` or `/full-audit <project>` defaults to a **regression scan** when a ledger exists: it focuses on files changed since the last audited commit and reconciles findings against the ledger, so previously-seen issues are not re-reported. A finding that reappears after being marked `fixed` is flagged as a **REGRESSION**. Pass `--full` to force a cold scan. Triage findings (acknowledge / wont-fix / fixed / reopen) with `/ledger <project>`; those statuses are authoritative and never auto-overwritten.

### Agent Delegation Policy (MANDATORY)

**Commands that specify agent delegation MUST use agents. Direct tool execution by the orchestrating agent is forbidden.**

When a command file specifies "Invoke **agent-name**" or lists agents under "Agent Delegation", the top-level agent:
- MUST delegate to the specified agent using the Task tool
- MUST NOT perform the work directly using Bash, Read, Write, Glob, Grep, or other tools
- Acts only as an orchestrator: parse input, delegate to agents, report results

**Why this matters:**
- Agents encapsulate domain-specific logic and validation
- Agent invocations create auditable execution traces
- The architecture assumes separation between orchestration and execution
- "Simple enough to do directly" is not a valid reason to skip delegation

**If a command says to invoke an agent, invoke the agent. No exceptions.**

## Build Commands

```bash
# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Build project
forge build

# Run tests
forge test

# Run single test
forge test --match-test testFunctionName

# Run tests with verbosity
forge test -vvvv

# Add auditable project as submodule
git submodule add <repo-url> lib/<project-name>
```

## C4 Severity Classifications (Regular Audits)

**High (3)**: Assets can be stolen/lost/compromised directly or via valid attack path without hypotheticals.

**Medium (2)**: Assets not at direct risk, but protocol function/availability impacted, or value leak with stated assumptions and external requirements.

**QA/Low**: State handling issues, spec deviations, centralization risks. Non-critical issues are discouraged.

### Plausibility Sub-Categories for High Severity
- **Plausible High** - Realistic attack scenarios
- **Implausible High** - Requires extraordinary circumstances (validator collusion, economic black swans)

## Report Requirements

### Submission Format
- High/Medium findings submitted individually
- Low/Governance findings bundled in single QA report
- Use labels: `H-01`, `M-01`, `L-01`, `C-01` (centralization)
- Include code location links
- Professional audit tone - credibility depends on accuracy and clarity

### Proof of Concept Requirements
- Coded, runnable PoC required for all High/Medium findings
- Must use the target project's test suite
- PoC must demonstrate the exact revert error, not just revert
- Provide as diff that can be applied to existing test files

### Known Invalid Findings
- Non-standard/weird ERC-20 tokens (except USDT)
- Fee-on-transfer tokens (unless explicitly in scope)
- CryptoPunks support
- Approve race condition / safeApprove front-running
- User input mistakes / phishing
- Reckless admin mistakes
- Unused view functions (QA at best)
- Speculation on future code without demonstrated root cause

### Out of Scope
- Issues in parent/forked contracts where root cause is OOS
- Issues already in project's known issues section
- Common findings from automated tools without demonstrated HM exploit path

## Quality Standards

Reports must match professional audit quality. The pipeline rejects:
- LLM-generated nonsense or low-effort reports
- Overstated severity (a finding's impact must justify its label)
- Findings without sufficient proof (a reader should not need additional research)

Low-value or duplicate findings dilute the report. Prioritise unique, high-impact issues over obvious vulnerabilities any tool would surface.
