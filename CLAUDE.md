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
- `lib/` - Git submodules containing auditable Solidity projects (Foundry convention)
- `reports/<project-name>/` - Generated audit reports with datetime-stamped filenames
- `documentation/` - C4 official documentation for reference

### Multi-Agent Workflow
Custom Claude Code commands orchestrate specialized agents:
1. **Analysis agents** - Scan for vulnerabilities in target contracts
2. **Deduplication agents** - Filter common/obvious issues found by tools like Mythril
3. **Sanitation agents** - Remove issues already documented in project's known issues
4. **POC agents** - Generate runnable Foundry unit tests proving vulnerabilities
5. **Report agents** - Compile findings in C4-compliant format

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

## C4 Bounty Severity Classifications

Bounties use different severity criteria. See `documentation/Bounties-*.md` for full details.

**Critical**: High impact + high likelihood. Impact includes:
- Direct theft of user funds (except unclaimed yield)
- Permanent freezing of funds/NFTs
- Protocol insolvency
- Governance manipulation

**High**: High impact, any likelihood. Impact includes:
- Theft of unclaimed yield/royalties
- Temporary freezing of funds/NFTs

### Bounty Mode Differences
- Only Critical and High severity accepted (no Medium, no QA/Low)
- Coded runnable PoC is **mandatory** for all findings
- $25 USDC deposit required per submission
- No QA report generated
- Use `/full-audit <project> bounty` or `/analyze <project> bounty`

### High Likelihood Definition (Required for Critical)
A vulnerability is "high likelihood" when:
1. Attacker controls creating requisite circumstances; AND
2. External circumstances can be reasonably expected and predicted using public info

Note: Exploit complexity/sophistication is NOT a factor in likelihood.

### Bounty Out of Scope
- Attacks requiring leaked keys/credentials
- Privileged address attacks (unless unintended privilege)
- External stablecoin depegging not caused by code bug
- Third-party oracle data issues
- Economic/governance attacks (51% attack)
- Centralization risks
- Best practice recommendations

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
