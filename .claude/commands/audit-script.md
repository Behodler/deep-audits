Audit a package.json script entry point and everything that goes into it
# Purpose
Audit a single **package.json script entry point** — not the whole project — and the precise slice of
contracts, on-chain state, off-chain state files, and sibling scripts it cuts across. Built for integration
mega-repos like `phoenix-phase-2-staging` that stage dozens of one-shot deployment/migration scripts over
nested submodules, where auditing the whole repo is wasteful but a specific operational script needs review.

It answers three questions about the chosen script:
1. **Does it do what it intends?** (intent vs. implementation)
2. **Does it introduce unintended side effects?** (state touched beyond its stated purpose)
3. **Have other problems surfaced because of it?** (cluster interactions, skipped steps, drift)

Output is **both** a narrative review (`review.md`) **and** structured findings fed through the normal
dedup → sanitize → classify → ledger pipeline, namespaced per entry point.

# Arguments
- `$ARGUMENTS` format: `<project-name> <npm-script-name> [--full] [--no-fork]`
- `<project-name>` — friendly name from registration (case-insensitive; lowercase-kebab normalized).
- `<npm-script-name>` — the **base** script key in the submodule's `package.json` (e.g. `RestoreMintAtIndex4`); the `:preview`/`:dry`/`:broadcast` variants are discovered automatically.
- `--full` — force a cold scan; otherwise findings are regression-reconciled against the ledger **per entry point**.
- `--no-fork` — skip on-chain side-effect verification; degrade to static reasoning (clearly flagged). Default is fork-based.
- Examples:
  - `phoenix-phase-2-staging RestoreMintAtIndex4` — fork-based audit of that entry point
  - `phoenix-phase-2-staging RestoreMintAtIndex4 --no-fork` — static-only, no RPC

# Orchestration Flow

## 1. Resolve project
Invoke **project-manager**: "Resolve friendly name, get scope, known issues, repoUrl/branch, current submodule HEAD, and the ledger."
- Unknown project → list registered projects, suggest `/add-project`, stop.
- Confirm `<npm-script-name>` exists as a key in `lib/<submodule>/package.json` (project-manager or a read-only check); if not, list the closest keys and stop.

## 1.5. Create versioned report directory
Invoke **project-manager**: "Create versioned report directory for this audit run" → `reports/<project>/XX/`. All artifacts for this entry point go under `reports/<project>/XX/script-audits/<entryPoint>/`.

## 2. Load environment and probe RPC (unless `--no-fork`)
- Source the **repo-root `.envrc`** (`direnv export bash`, or read it) to obtain `RPC_MAINNET` and `ETHERSCAN_API_KEY`. The user always keeps keys there (see project memory).
- **Liveness probe:** `cast block-number --rpc-url $RPC_MAINNET`. If it fails or `RPC_MAINNET` is unset, **alert the user that the key may be expired/rate-limited** and ask whether to refresh it or proceed with `--no-fork`. Do **not** silently degrade.
- On success, record the fork block for reproducibility. Set `forkAvailable` accordingly.

## 3. Map the closure
Invoke **script-closure-mapper**: "Resolve the entry point to its full transitive closure."
- Parses the npm command chain (forge target + pre/post node scripts + variants + intent comment).
- Resolves the Solidity import graph via `foundry.toml` remappings; classifies files `in-src` / `nested-submodule` / `external-lib`.
- Maps hardcoded on-chain addresses + inline interfaces to source contracts (resolves nested-submodule paths; corroborates bytecode via Etherscan when fork is up).
- Records off-chain state files the JS chain mutates, and the ranked **cluster** of sibling scripts (shared addresses / story tag / skipped-step / evidence).
- **Resolves the story documents** behind the entry point and its cluster (`storyDocs[]`) from the external, read-only tree `~/code/product-owner/stories/<storyDir>/` — see `registered-projects.json` → `storyPolicy`. A `[story-NNN]` commit subject is a pointer, not the story; the document holds the acceptance criteria the script is graded against (Law 2). Never report that a script could not be held accountable to its story because the story lives outside this repo.
- Output: `script-audits/<entryPoint>/entry-manifest.json` + `closure-manifest.json`.

```
Closure: RestoreMintAtIndex4
────────────────────────────
Forge target: script/RestoreMintAtIndex4.s.sol:RestoreMintAtIndex4 (chainId 1)
Solidity:     3 in-src (ViewRouter, IPageView, MintPageView)
On-chain:     4 addresses — 2 mutated (NFTMinterV2, ViewRouter), 1 referenced, 1 replaced
              NFTMinterV2 → lib/nft-staking/lib/mutable/yield-claim-nft/src/V2/NFTMinterV2.sol
Cluster:      DispatcherReplaceAtIndex4 (predecessor) · SetMinterOnIndex4Pooler (skipped-step)
              SetBatchDonationSizeIndex4 (sibling-config) · TempSimulate40MintsIndex4 (evidence)
```

## 4. Setup workspace
Invoke **project-manager**: "Ensure writable workspace exists" → `workspace/<project>/` (shallow-clone from submodule URL, remove remote, if absent). Preview runs and any PoCs execute here. `lib/` stays read-only.

## 5. Audit the script
Invoke **script-auditor**: "Extract intent, verify side effects on a fork, analyze cluster interactions."
- Builds `intent.md` (stated purpose + declared pre/post-conditions).
- Runs the **preview** variant from `workspace/` against the mainnet fork; captures all state writes, events, external calls, and pre/post-condition results into `side-effects.json`; flags writes beyond stated purpose as `unintendedEffects`.
- Reasons about cluster siblings against observed live state (e.g. is `mint(4)` actually functional given the skipped `SetMinterOnIndex4Pooler` step — confirm with a cheap fork check).
- Emits candidate findings tagged with `entryPoint`, `category`, and the real `contract` source path.
- If `--no-fork`: static mode, every empirical claim tagged `unverified`.

```
Side effects: RestoreMintAtIndex4 (fork-preview @ block ########)
──────────────────────────────────────────────────────────────
Preconditions:  4/4 passed
State writes:   2 intended (configs[4].disabled→false, pages['mint']→0x64FE…) · 0 unintended
Postconditions: 2/2 passed · getData(owner) smoke OK
Cluster:        ⚠ SetMinterOnIndex4Pooler skipped → checking mint(4) reachability…
```

## 6. Findings pipeline (reused)
Run the standard back half on the candidate findings:
- Invoke **deduplicator**: collapse duplicates/common issues.
- Invoke **sanitizer**: filter known issues, then reconcile against the ledger by `fingerprint` (which now folds in `entryPoint`, so reconciliation is per-script). Mark new / still-open / regression / suppressed.
- Invoke **severity-classifier**: C4 severity on new + regressed findings.
- Invoke **finding-manager**: write `reports/<project>/XX/findings/<sev>/`, set `entryPoint` on each record, upsert the ledger (full carryover copies for still-open: H/M as `submissions/<label>-C<n>.md`, QA as `submissions/carryover/qa-report-<NN>.md`).

## 7. Narrative review
Invoke **report-writer** (script-review mode): assemble `script-audits/<entryPoint>/review.md` from `intent.md`, `side-effects.json`, the cluster analysis, and the classified findings — structured around the three questions (intent / side effects / knock-on), linking each structured finding and its location.
- The **findings register** table is `Label | Sev | What | Mitigation | Where`. The `Mitigation` cell is a one-line compression of the finding's `recommendation` field and **must never be empty** — a finding filed without a stated fix is an incomplete finding, not a terse one. If `recommendation` is genuinely absent from the record, that is a defect to fix upstream in the classified finding, not to paper over in the table.

## 8. PoCs for High/Medium (where demonstrable)
For each new/regressed High/Medium whose impact is concretely reproducible (e.g. "mint(4) reverts after this script alone"):
- Invoke **poc-generator**: a fork-based forge test in `workspace/<project>/test/`.
- Invoke **poc-validator**: confirm it compiles and demonstrates the exact behavior.
- Invoke **finding-manager**: attach PoC + status.

## 8.5 Submissions (same output contract as `/full-audit`)
A script audit produces the **same submission artifacts** as a contract audit — the entry point changes what was scanned, not what a reader is owed. Everything lands in `reports/<project>/XX/submissions/`, alongside the carryover copies step 6 already writes there.

**Per High/Medium** — invoke **report-writer**, then **report-validator**, then **finding-manager** (status → `submitted`):
- One file per finding: `submissions/<label>.md` (e.g. `submissions/M-01.md`).
- The metadata header comment is identical to the contract-audit format, **plus** an `Entry Point:` line, and **must carry the `Fingerprint:`** exactly as written to the ledger — the `sha256(contract:function:rootCauseClass:entryPoint)` value from the finding's `fingerprint` field. Never recompute or shorten it; copy it verbatim so a submission, its `findings/<sev>/*.json` record and its ledger entry are joinable by string match.
```
<!--
ID: <sourceId>
C4 Submission Metadata
Project: <project> @ <commit> (run-XX, script audit)
Entry Point: <npm-script-name>
Title: [<label>] <title>
Root Cause Link: https://github.com/<org>/<repo>/blob/<commit>/<path>#L<start>-L<end>
Fingerprint: <finding.fingerprint verbatim>
PoC File: workspace/<project>/test/<poc>.t.sol   (or: none — <why>)
-->
```
- Body sections mirror the contract-audit report: Severity (+ rationale), Description, Impact, Proof of Concept (or why one is not demonstrable), and a **Recommended Mitigation** section rendering the finding's `recommendation` in full. **A submission with no Recommended Mitigation section does not pass `report-validator`.**

**Low + Centralization** — invoke **qa-bundler**: bundle into `submissions/qa-report.md`, one section per finding, each with its fingerprint and its recommendation. QA findings are bundled, not individually filed.

**Faithfulness (Law 2)** — invoke **finding-manager**: write `submissions/spec-conformance.md` from the `F-XX` findings, quoting the `[story-NNN]` acceptance text each deviation violates. Separate from the QA bundle.

**Label scoping.** Labels (`M-01`, `L-03`, …) are scoped to the run directory, matching `findings/<sev>/`. If a single run directory audits more than one entry point, namespace both the labels and the submission filenames per entry point (`submissions/<entryPoint>/<label>.md`) so nothing collides; the fingerprint is the collision-proof key either way.

## 9. Summary
```
Script Audit Complete: phoenix-phase-2-staging :: RestoreMintAtIndex4
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run: reports/phoenix-phase-2-staging/XX/   Mode: fork-preview | static   Regression | --full

Closure:   3 sol · 4 on-chain (2 mutated) · 4 cluster siblings
Intent:    2/2 purposes met · 4/4 pre · 2/2 post
Side fx:   0 unintended on-chain writes
Findings:  High 0 · Medium 1 (incomplete remediation: index-4 pooler not authorized) · Low 0
           ledger: 1 new · 0 still-open · 0 regression   (entryPoint=RestoreMintAtIndex4)

Review:    reports/phoenix-phase-2-staging/XX/script-audits/RestoreMintAtIndex4/review.md
Submissions: reports/phoenix-phase-2-staging/XX/submissions/
             Medium: M-01.md (fingerprint 4f2a1c9e…)
             QA:     qa-report.md (0 Low + 0 Centralization)
             Carryover: 0 still-open from prior runs
Artifacts: entry-manifest.json · closure-manifest.json · intent.md · side-effects.json
Ledger:    reports/phoenix-phase-2-staging/ledger.json (updated)

Next: /list-findings phoenix-phase-2-staging · /ledger phoenix-phase-2-staging
```

# Agent Delegation
- **project-manager**: resolve name, scope/known issues, versioned dir, workspace, ledger I/O
- **script-closure-mapper**: entry-point parse + transitive closure (sol/on-chain/js/cluster)
- **script-auditor**: intent extraction, fork-based side-effect verification, cluster-interaction analysis
- **deduplicator** → **sanitizer** → **severity-classifier** → **finding-manager**: standard findings pipeline (per-`entryPoint` reconciliation)
- **report-writer**: narrative `review.md` (script-review mode) **and** per-H/M `submissions/<label>.md` (C4 mode)
- **report-validator**: quality gate on each submission — rejects one with no Recommended Mitigation
- **qa-bundler**: `submissions/qa-report.md` from Low + Centralization
- **poc-generator** / **poc-validator**: fork-based PoCs for High/Medium

# Error Handling
- **Unknown project / missing script key**: list closest matches, stop.
- **RPC unset or liveness probe fails**: alert the user the key may be expired; offer `--no-fork` or a refreshed key — never silently degrade.
- **Unresolved imports / absent nested submodule**: closure-mapper records them in `unresolved`; continue with what resolves; suggest the SessionStart `git submodule update --init`.
- **Preview reverts**: capture the exact revert reason; treat a script that cannot preview against current state as a finding.
- **Missing tool** (cast/forge): note the gap, continue with available capabilities.

# Critical Rules
1. **Source repos are read-only** — closure mapping only reads `lib/`; all execution (preview, PoCs) runs from `workspace/`; never broadcast.
2. **Delegate, don't do** — the command orchestrates; every step is an agent invocation (CLAUDE.md Agent Delegation Policy).
3. **Per-entry-point namespace** — findings carry `entryPoint`; the fingerprint folds it in so script-audit findings never collide with contract-scan findings and regression reconciliation is per script.
3.5. **Same submission contract as a contract audit** — a script audit is not a lesser audit. Every new/regressed High and Medium gets its own `submissions/<label>.md` carrying the ledger fingerprint verbatim and a Recommended Mitigation section; Low/Centralization get the QA bundle; faithfulness gets `spec-conformance.md`. `review.md` is the narrative *in addition to* these, never a substitute for them.
4. **Alert on expired keys** — a failed RPC liveness probe is surfaced to the user, not silently downgraded to static mode.
5. **Bounded scope** — audit the entry point's closure + ranked cluster; if the root cause is a broad contract bug outside the slice, record it and recommend `/full-audit` rather than expanding scope.
