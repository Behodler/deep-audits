# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This repository contains the audit tooling used to review the Phoenix/Behodler smart-contract suite. Findings are written in a format compatible with Code4rena (C4) conventions so the same artefacts can be repurposed if a Phoenix component is ever submitted to a public audit; treat the C4 framing as an output spec, not a contest goal.

## Audit Philosophy — The Three-Law Hierarchy

Every audit decision — what to scan, what to report, how to rank, what to suppress — obeys a strict, ordered hierarchy. Lower laws yield to higher ones (Asimov-style). When laws conflict, the lowest-numbered one wins. This hierarchy is the authority behind the agent rules; where a C4 convention contradicts it, the laws win (C4 is an output spec, not the goal).

1. **No exploits (security is paramount).** This is DeFi; a live exploit is the worst possible outcome. **Recall beats report-tidiness** — never silently drop a plausibly-security-relevant finding to keep a report clean. If a finding must be set aside, park it in a *visible* channel (manual-review / spec-conformance / carryover) with the reason, never in a log nobody reads.
2. **Faithfulness to stories.** Features must do what the `[story-NNN]` they derive from says. **The story documents themselves live outside this repo, in `~/code/product-owner/stories/`** — a `[story-NNN]` commit subject is a *pointer* to one of those documents, not the story. Read the document (see **Stories** under Critical Rules); supporting intent also lives in `lib/<project>/docs/` and the project `CLAUDE.md`. **Law 1 overrides:** if a story's own intended behaviour would introduce an exploit, flag the unsafe story — do not bless a faithful-but-exploitable implementation.
3. **The owner is trusted — for KNOWING actions only.** Assume the owner is **non-malicious**: never report "a malicious owner could…" vectors (a self-audit cannot stop a malicious owner, and the owner is not their own adversary — such findings are pure noise). But an owner action with a *non-obvious* consequence that **unknowingly** enables a Law-1 exploit or breaks a Law-2 story is a **footgun**, and footguns are **in scope** — surfaced as operational hazards with safe-config guidance, at honest severity. The test: *"would a competent, non-malicious owner be surprised by this consequence?"* Surprise ⇒ footgun ⇒ report. Obvious ⇒ trusted ⇒ suppress.

## Terminology

- **Source repo** - A repository containing the Solidity project to be audited. Source repos are added as git submodules in `lib/`.
- **Project name** - Always the upstream repo name. The submodule dir (`lib/<name>`), the registry key in `registered-projects.json`, the report-dir family (`reports/<name>-XX/`), the ledger (`reports/ledgers/<name>.json`), and the workspace dir (`workspace/<name>/`) are all the **same canonical string**. There is no separate "friendly name" alias — project name and repo name must agree.

## Critical Rules

**Source repos are strictly read-only.** Never modify files in source repos. Never commit to source repos. They must remain exactly as cloned from the upstream Behodler-org repository.

**Submodules are initialized recursively.** This project audits the *living latest* of each repo **and its nested dependencies** — we are not crystallizing a pinned ABI, we are reviewing the code as it actually is today. Adding (`/add-project`), updating (`/update-lib`), and the SessionStart hook all init `--recursive` by default. Read-only still applies: pull the full nested tree, but never modify it. `/update-lib` accepts `--no-recursive` as an explicit per-run opt-out.

**Scope is default-in-scope — a denylist, not an allowlist (Law 1).** Every first-party `.sol` in a submodule is in scope by default; the only baked-in exclusion is the project's own nested `lib/**` (third-party + forked deps, handled at the findings layer). A **new** first-party contract introduced by a code change — a fresh migrator, a new strategy — is **automatically in scope and scanned**, never silently dropped and never gated behind a "is this in scope?" confirmation. The per-project `scope` array in `registered-projects.json` is an advisory focus hint and cached snapshot, **never** the gate; see `registered-projects.json` → `scopePolicy` for the authoritative semantics. Rationale: recall beats report-tidiness — risking extra tokens on a contract nobody cares about is acceptable; risking a live exploit in a contract that slipped under the radar is not. Cull noise at **triage** (`/ledger`), not by withholding the scan. A project may add *extra* human-chosen exclusions to its `outOfScope`, but under-scoping must never hide a first-party contract.

**Stories are external, and must always be retrieved (Law 2).** The `[story-NNN]` prefix on a commit subject (e.g. `[story-073] Seed phUSD/Kendu nudge streams…`) is a **pointer**, not the story. The authoritative story documents live in the read-only tree `~/code/product-owner/stories/`, laid out as:

```
~/code/product-owner/stories/<storyDir>/<complete|incomplete|review|archive>/<sprint>/<NNN>-<slug>.md
```

- **Story numbers are unique project-wide** — across every state folder and every sprint/worktree folder. Decimal insertions exist (`045.5-...`). Resolve a tag by globbing the *whole* project tree, never one sprint or one state:
  `find ~/code/product-owner/stories/<storyDir> -type f -name '<NNN>-*.md' -o -type f -name '<NNN>.*-*.md'`
- **The state folder is metadata, not a filter.** `incomplete` / `review` stories are still in scope (code frequently lands before the story is closed out), and `archive` still explains shipped behaviour. Note which state a story came from — a landed feature whose story sits in `incomplete` is itself worth flagging.
- **The directory name is not the project name** (`reflax-yield-vault` → `vault-RM`, `phoenix-phase-2-staging` → `phStaging2`). Never guess it. Use the project's `storyDir` field in `registered-projects.json` — a verified cache of the **authoritative** mapping in `~/code/product-owner/registered-project-list.md`, which lists `<storyDir>:<path under ~/code/>` per line and resolves mechanically via `git -C ~/code/<path> remote get-url origin` (the remote's basename is the audit project name). If a lookup misses or a project is added, re-derive from that file and refresh `storyDir`.
- **Read-only, like `lib/`.** Never write to the stories tree.
- **Never grade faithfulness from a commit subject alone, and never report "the story is external / unavailable."** If a glob returns zero hits, say the story genuinely does not exist; if it returns several, report the ambiguity rather than picking one. This applies to `/analyze`, `/full-audit`, **and `/audit-script`** — a deployment script is judged against its story exactly like a contract is. Authoritative semantics: `registered-projects.json` → `storyPolicy`.

## Architecture

### Directory Structure
- `lib/` - Git submodules containing auditable Solidity projects (read-only audit references)
- `~/code/product-owner/stories/<storyDir>/` - **External, read-only** story documents; the Law-2 source of truth (see Critical Rules → Stories)
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
Re-running `/analyze <project>` or `/full-audit <project>` defaults to a **regression scan** when a ledger exists: it focuses on files changed since the last audited commit and reconciles findings against the ledger, so previously-seen issues are not re-reported. A finding that reappears after being marked `fixed` is flagged as a **REGRESSION**. Pass `--full` to force a cold scan. Triage findings (fix-pending / acknowledge / wont-fix / fixed / reopen) with `/ledger <project>`; those statuses are authoritative and never auto-overwritten.

**`fix-pending` vs `acknowledged` — a Law-1 distinction.** Both say "the finding is valid", but they are opposites downstream and must never be conflated:

- **`acknowledged`** = *accepted and disposed of* ("we're living with it"). **Suppressed** from future scans, no carryover stub, hidden by `/open-issues`. Correct for a residual risk the owner has decided to carry.
- **`fix-pending`** = *accepted and a fix is owed* ("we're fixing it"). **Never suppressed** — rescanned, stubbed, and shown by `/open-issues` exactly like `open`, until a human marks it `fixed`.

A finding the owner intends to fix must **never** be filed as `acknowledged`: suppression would remove a live bug from every future scan precisely when someone is depending on the fix landing correctly, so an incomplete or absent fix would go unnoticed. When a triage instruction sounds like *"acknowledged, will fix"*, the operative word is **will fix** → `fix-pending`. If ambiguous, ask; never default to `acknowledged`.

`fix-pending` is human-set and never auto-closed — `/analyze`, `/full-audit`, and `/recheck` may *propose* `fixed` but only a human applies it (a fix that merely stops tripping the scanner is not a verified fix). If the code changed and the finding survived, that is an **⚠ INCOMPLETE FIX** signal, ranked second only to a REGRESSION: an incomplete fix is more dangerous than an unfixed bug, because it reads as done.

### Re-verifying a single finding (`/recheck`)
`/recheck <project> <label-or-fingerprint>` re-proves **one** finding against the current submodule HEAD without running discovery. It is **PoC-replay first**: it syncs the writable `workspace/` source to the target commit (preserving the PoC), re-runs the finding's PoC, and classifies the result as **STILL-LIVE** / **LIKELY-FIXED** / **INCONCLUSIVE** (a PoC that no longer *compiles* is inconclusive bit-rot, not a fix). Use it for a localized post-fix re-check; the command itself bounces you to `/full-audit` when the change is broader than the finding's contract.

`/recheck` is deliberately **baseline-preserving and single-entry**: it never writes `lastAuditedCommit`, never bumps `lastSeenRun`, never moves `lastRun`, and never auto-flips a status — it records its outcome in recheck-only fields (`lastRecheckedCommit`/`lastRecheckedAt`/`recheckResult`) on the one entry and *proposes* the `/ledger` command for any status change. Pick `/recheck` to answer "is this specific finding still real?"; pick the regression `/full-audit` to also catch issues the fix may have introduced — `/recheck` is blind to new bugs by design.

### Auditing a script entry point (`/audit-script`)
For integration mega-repos (e.g. `phoenix-phase-2-staging`) that stage dozens of one-shot deployment/migration scripts over nested submodules, auditing the whole project is wasteful — but a **specific operational script** often needs review. `/audit-script <project> <npm-script-name> [--full] [--no-fork]` scopes the audit to a single `package.json` script entry point and the precise slice it cuts across, answering: does it do what it intends, does it introduce unintended side effects, and have other problems surfaced because of it.

It resolves the **transitive closure** of the entry point — the forge/JS command chain, the Solidity import graph (via `foundry.toml` remappings), the deployed on-chain addresses it mutates (mapped back to nested-submodule source), the off-chain state files the JS chain writes, and a ranked **cluster** of sibling scripts that touch the same contracts (shared addresses / story tag / skipped-step / `Temp`/`Fix` evidence). It then verifies side effects empirically by running the script's **preview** variant against a mainnet fork (from `workspace/`, never `lib/`) and diffing observed state writes against the script's stated intent and its own `require`/assert pre/post-conditions. Output is **both** a narrative `review.md` and structured findings fed through the normal dedup → sanitize → classify → ledger pipeline.

Findings carry an `entryPoint` discriminator that is folded into the fingerprint (`sha256(contract:function:rootCauseClass[:entryPoint])`), so script-audit findings reconcile **per entry point**, never collide with contract-scan findings on the same `contract:function`, and an empty `entryPoint` reproduces the legacy hash byte-for-byte (so `/analyze` and `/full-audit` are unaffected). Fork-based verification reads `RPC_MAINNET`/`ETHERSCAN_API_KEY` from the repo-root `.envrc`; a failed RPC liveness probe **alerts the user** (possible expired key) rather than silently degrading — pass `--no-fork` for static-only reasoning. New agents: **script-closure-mapper** (scope resolution) and **script-auditor** (intent + side-effect + cluster lens).

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
- Reckless admin mistakes — owner acting maliciously, or a misconfig whose harm is *obvious* (Law 3). **Exception:** a *non-obvious* owner footgun that unknowingly enables an exploit or breaks a story is **in scope** as an operational hazard, not invalid.
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
