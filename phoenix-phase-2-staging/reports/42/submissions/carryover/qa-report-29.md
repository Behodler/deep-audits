# Carryover QA report: audit 29 (entry point `dev`), re-carried at audit 42

> **Carryover QA report — audit 29** (cut down; carried by audit 42, run `phoenix-phase-2-staging-42`, `/audit-script phoenix-phase-2-staging dev`,
> src commit `d0060cb82d91f43c94c8d7f7a34fb50988957ac3`, branch `master`, delta `dfbf2f9..d0060cb`). This is a full copy, not a stub.
> **Everything after the run-42 index is preserved VERBATIM**, including every earlier carryover header. Where an
> earlier header says "as of audit NN", read "as of audit NN, and unchanged at audit 42 unless stated below".
>
> - **Retained (ledger status `open` or `fix-pending` as of audit 42): L-06, L-07, Q-03, F-04. That is 4 entries.**
> - **Removed as no longer live:** no entry of this bundle was disposed of between audit 39 and audit 42. Earlier removals (still in force): none. The body also keeps `L-05` (`2f86e3864ead…` / `pps29l5`) and `F-03` (`c476a12b04fa…` / `pps29f3`), which are still `open` but belong to entry point `test:stable-staker`; they are not counted in the dev retained set and run 42 did not examine them.
> - **Run-42 verdict mix:** NOT ×1, STILL-PRESENT ×3. A verdict is evidence, not a status change.
> - **Statuses changed by audit 42 in this file: NONE.** Proposed closures are listed in the index below with the exact
>   `/ledger` command, and collected in `../../script-audits/dev/proposed-status-changes.md`. Only a human applies them.
> - **Labels are the originals.** Gaps in the sequence are the removals named above, not omissions. Entry point `dev`
>   reuses labels across runs under different fingerprints, so **always select by fingerprint or issueId**.
> - **Line numbers below were accurate at the originating commit. Re-verify them against current HEAD `d0060cb` before acting.**
> - Source of the verbatim body: [`../../../39/submissions/carryover/qa-report-29.md`](../../../39/submissions/carryover/qa-report-29.md).

## Run-42 index of retained entries (verdict, proposed action, recommendation)

#### L-06 · `pps29l6` · low · ledger status `open`

- **Title:** Phase 6.5b leaves CrossVersionMigrator holding the migrator role on both stakers, unlike the Phase 7.4 cutover 400 lines below it, and the terminal residual-privilege sweep does not cover the migrator role
- **Fingerprint:** `08adbb6928403acea22a033a75ad797e7fe88f7bd15aff8c16af81f554cc3cd8`
- **Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol` (`_rehearseStableStakerCutover`)
- **Run-42 auditor verdict:** **STILL-PRESENT**. L2773-2774 set CrossVersionMigrator on V1 and V2; no revoke anywhere; the sweep does not cover the migrator role
- **Proposed human action:** None. Keep `open`.
- **Recommendation** (verbatim from the finding record `phoenix-phase-2-staging/reports/29/findings/low/L-06-missing-post-step-configuration.json`):

  > Mirror Phase 7.4: after `_assertStableStakerCutover` passes for all three pools, call `stableStaker.setMigrator(address(0))` with a read-back require, and add a migrator row to `_sweepResidualPrivileges` asserting the expected end-state migrator for every staker and Phlimbo the script deploys — the same table idiom `_requireLiveMinter` already uses, so drift names its own offender. If the destination V2 is intended to keep its migrator (the Phase 7.4 precedent leaves PhlimboV3's in place), assert that positively rather than leaving it unstated.

#### L-07 · `pps29l7` · low · ledger status `open`

- **Title:** A SIGINT or SIGTERM delivered to dev-local.sh's own pid rather than its process group leaves anvil running
- **Fingerprint:** `49b9904ee12a1abe85b63d458fee5ede6f8dd447a309191e51b4efd40a220a56`
- **Location:** `lib/phoenix-phase-2-staging/dev-local.sh` (`cleanup / trap`)
- **Run-42 auditor verdict:** **STILL-PRESENT (empirically confirmed)**. SIGTERM to dev-local.sh pid 25994 during serve: after 10 s anvil 26083 and node 35345 were still running and :8545 answered. The trap fired only when the serve child was killed ('Tearing down Anvil (pid 26083)...', exit 143).
- **Proposed human action:** None. Keep `open`.
- **Recommendation** (verbatim from the finding record `phoenix-phase-2-staging/reports/29/findings/low/L-07-deferred-trap-during-foreground-child.json`):

  > Have cleanup also kill anvil's process group, and stop blocking on a child that ignores the queued trap — e.g. run `npm run serve` in the background and `wait` on it (bash runs a pending trap as soon as `wait` is interrupted), or `exec` the server so there is no shell left to deceive. A one-line note in the script's usage comment that the stack must be stopped with Ctrl-C, not `kill <pid>`, would also close it.

#### Q-03 · `pps29q3` · qa · ledger status `open`

- **Title:** dev-local.sh duplicates start:anvil's flags inline, so editing the start:anvil key no longer reaches `npm run dev`
- **Fingerprint:** `111b6f04c9b72ba71e4ad9eb7d2dc5df01790dce7e97d1fe95e093d0ef9b41af`
- **Location:** `lib/phoenix-phase-2-staging/dev-local.sh` (`anvil launch`)
- **Run-42 auditor verdict:** **STILL-PRESENT**. dev-local.sh:115-116 says 'Flags are byte-identical to the start:anvil key' then runs --block-time 2. package.json start:anvil is --block-time 5 since untagged 6c9416d (2026-09-14). story-116 itself cites --block-time 5 for start:anvil, and its gas-check 'passes trivially' observation is a direct consequence of dev's block-time 2.
- **Proposed human action:** None. Keep `open`.
- **Recommendation** (verbatim from the finding record `phoenix-phase-2-staging/reports/29/findings/qa/Q-03-duplicated-configuration-surface.json`):

  > Keep the direct launch (the pid reasoning is correct) but stop duplicating the string: define the flags once — e.g. an `ANVIL_FLAGS` value sourced from a single file that `start:anvil` also uses, or have dev-local.sh read the flags out of package.json — or, at minimum, add a comment on the `start:anvil` key pointing at dev-local.sh:69 so an editor of either is told about the other.

#### F-04 · `pps29f4` · low · ledger status `open`

- **Title:** story-080's declared drift guard between mainnet-addresses.ts and the regenerated ContractAddresses interface does not exist, and the two files already disagree
- **Fingerprint:** `ee5aae66ac651277953db1b477d4ba66939701ec5aa7ffe013c2b26b9865e678`
- **Location:** `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts` (`mainnetAddresses: ContractAddresses`)
- **Run-42 auditor verdict:** **NOT RE-EXAMINED**. Outside the dfbf2f9..d0060cb dev delta and not touched by it; no run-42 evidence either way. Not a clean bill.
- **Proposed human action:** None this run. Keep `open`; re-examine at the next full-closure dev run.
- **Recommendation** (verbatim from the finding record `phoenix-phase-2-staging/reports/29/findings/faithfulness/F-04-unenforceable-declared-drift-guard.json`):

  > Add a minimal tsconfig.json covering server/deployments/*.ts with `strict: true`, and either declare the three Burner* keys on ContractAddresses (by adding their `_trackDeployment` calls, the codegen path story-080 itself insists on) or drop them from mainnet-addresses.ts. Then wire `tsc --noEmit` into the same GitHub workflow that already runs `forge fmt --check` / `forge build --sizes` / `forge test`, so the guard is enforced rather than asserted.

---

*The text below is a verbatim copy of `39/submissions/carryover/qa-report-29.md` (itself the run-39 carryover, with every earlier header preserved).*

---

# Carryover QA report: audit 29 (entry point `dev`), re-carried at audit 39

> ## Re-carried at audit 39. Read this first.
>
> **This block was prepended by audit 39** (run `phoenix-phase-2-staging-39`, commit `dfbf2f9`,
> baseline `e6eded0`, branch `master`, entry point `dev`). **Everything after the run-39 index,
> including every earlier carryover header, is preserved VERBATIM and has not been edited.** Where
> an earlier header says "as of audit 30", read it as "as of audit 30, and unchanged at audit 39 unless stated below". Run 39's statements below take precedence.
>
> - **Retained (still open or `fix-pending` as of audit 39): L-06, L-07, Q-03, F-04. That is 4 entries.**
> - **Removed as no longer live:** none. The body below also keeps `L-05` (`2f86e3864ead…` / `pps29l5`) and `F-03` (`c476a12b04fa…` / `pps29f3`). Both are **still open** but belong to entry point **`test:stable-staker`**, not `dev`. They are kept, not disposed of, and are **not counted** in the dev retained set. `Q-02*` in the body is the run-29 update to `pps28q2`, which is counted under audit 28.
> - **Statuses changed by audit 39 in this file: NONE.** Proposals are recorded in the ledger
>   (`run39` field and `note`). Only a human applies them, with `/ledger`.
> - **Labels are the originals.** Any gap in the sequence is one of the removals named above, not an omission.
>   Entry point `dev` reuses the same labels across runs under different fingerprints, so **always
>   select by fingerprint or issueId**.
> - Run-39 evidence update on `Q-03` (`111b6f04c9b7…`): the predicted drift has happened. `dev-local.sh` uses `--block-time 2` and `start:anvil` uses `--block-time 5` (untagged `6c9416d`), so the in-source 'byte-identical' claim is now false. Through the block time, it couples to run-39 `Q-01` (`pps39q1`).
> - The audit-29 Law-2 entries are appended in **Part B**, verbatim from the run-30 `spec-conformance-29.md` carryover.
> - **Line numbers below were accurate at the originating commit `9563c68`. Re-verify them against current HEAD `dfbf2f9` before acting.**
> - Source of the verbatim body: `../../30/submissions/carryover/qa-report-29.md` + `../../30/submissions/carryover/spec-conformance-29.md`.

## Run-39 index of retained entries (fingerprint + recommendation)

#### L-06 · `pps29l6` · low · status `open`

- **Title:** Phase 6.5b leaves CrossVersionMigrator holding the migrator role on both stakers, unlike the Phase 7.4 cutover 400 lines below it, and the terminal residual-privilege sweep does not cover the migrator role
- **Fingerprint:** `08adbb6928403acea22a033a75ad797e7fe88f7bd15aff8c16af81f554cc3cd8`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/29/findings/low/L-06-missing-post-step-configuration.json`):

  > Mirror Phase 7.4: after `_assertStableStakerCutover` passes for all three pools, call `stableStaker.setMigrator(address(0))` with a read-back require, and add a migrator row to `_sweepResidualPrivileges` asserting the expected end-state migrator for every staker and Phlimbo the script deploys — the same table idiom `_requireLiveMinter` already uses, so drift names its own offender. If the destination V2 is intended to keep its migrator (the Phase 7.4 precedent leaves PhlimboV3's in place), assert that positively rather than leaving it unstated.

#### L-07 · `pps29l7` · low · status `open`

- **Title:** A SIGINT or SIGTERM delivered to dev-local.sh's own pid rather than its process group leaves anvil running
- **Fingerprint:** `49b9904ee12a1abe85b63d458fee5ede6f8dd447a309191e51b4efd40a220a56`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). Re-observed during teardown.
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/29/findings/low/L-07-deferred-trap-during-foreground-child.json`):

  > Have cleanup also kill anvil's process group, and stop blocking on a child that ignores the queued trap — e.g. run `npm run serve` in the background and `wait` on it (bash runs a pending trap as soon as `wait` is interrupted), or `exec` the server so there is no shell left to deceive. A one-line note in the script's usage comment that the stack must be stopped with Ctrl-C, not `kill <pid>`, would also close it.

#### Q-03 · `pps29q3` · qa · status `open`

- **Title:** dev-local.sh duplicates start:anvil's flags inline, so editing the start:anvil key no longer reaches `npm run dev`
- **Fingerprint:** `111b6f04c9b72ba71e4ad9eb7d2dc5df01790dce7e97d1fe95e093d0ef9b41af`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). Evidence update: predicted drift realised - dev-local.sh --block-time 2 vs start:anvil --block-time 5 (untagged 6c9416d); in-source 'byte-identical' claim now false. Behavioural coupling: DEV39-02 residual magnitude depends on block time.
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/29/findings/qa/Q-03-duplicated-configuration-surface.json`):

  > Keep the direct launch (the pid reasoning is correct) but stop duplicating the string: define the flags once — e.g. an `ANVIL_FLAGS` value sourced from a single file that `start:anvil` also uses, or have dev-local.sh read the flags out of package.json — or, at minimum, add a comment on the `start:anvil` key pointing at dev-local.sh:69 so an editor of either is told about the other.

#### F-04 · `pps29f4` · low · status `open`

- **Title:** story-080's declared drift guard between mainnet-addresses.ts and the regenerated ContractAddresses interface does not exist, and the two files already disagree
- **Fingerprint:** `ee5aae66ac651277953db1b477d4ba66939701ec5aa7ffe013c2b26b9865e678`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/29/findings/faithfulness/F-04-unenforceable-declared-drift-guard.json`):

  > Add a minimal tsconfig.json covering server/deployments/*.ts with `strict: true`, and either declare the three Burner* keys on ContractAddresses (by adding their `_trackDeployment` calls, the codegen path story-080 itself insists on) or drop them from mainnet-addresses.ts. Then wire `tsc --noEmit` into the same GitHub workflow that already runs `forge fmt --check` / `forge build --sizes` / `forge test`, so the guard is enforced rather than asserted.

---

<!-- Part A: verbatim copy of reports/30/submissions/carryover/qa-report-29.md -->

# Part A: QA bundle (verbatim)

---

# Carryover QA report — audit 29 (entry point `dev`), carried at audit 30

> **Carryover QA report — audit 29** (copied in full from
> [`reports/29/submissions/qa-report.md`](../../29/submissions/qa-report.md)). Prepended header by
> audit 30; **the body below is a verbatim copy and has not been edited.**
>
> - **Retained (still open as of audit 30): `L-05, L-06, L-07, Q-02*, Q-03` — all five. Nothing
>   was cut, so there are no gaps in the label sequence.**
> - **Removed as no longer live: none.** No audit-29 `dev` finding has been fixed, acknowledged,
>   wont-fixed, ruled a false positive or abandoned.
> - `Q-02` keeps its original label and `issueId` `pps28q2` because it is an update to an existing
>   run-28 entry, not a new audit-29 finding.
> - Audit-29 `F-03`/`F-04` are Law-2 faithfulness findings and are carried in
>   [`spec-conformance-29.md`](spec-conformance-29.md), not here.
> - **Statuses changed by audit 30 in this file: NONE.**
> - **⚠ Audit-30 cross-reference — binding on the next re-triage of audit-29 `L-06`
>   (`08adbb692840…` / `pps29l6`):** `L-06`'s stated comparator is the Phase 7.4 / 7.6 cutover
>   rehearsal, which commit `e6eded0` **deleted** — audit 30 files that deletion as its `Q-02`
>   (`66671224826b…`). **`L-06`'s basis must therefore be RESTATED on `_deployPhlimboV3:2314-2321`
>   rather than re-verified against a landmark that no longer exists.** `L-06` is **not** fixed and
>   was not proposed fixed.
> - **Line numbers below were accurate at the originating commit `9563c68`. Re-verify against
>   current HEAD `e6eded0` before acting.**
>
> Run 30: `/audit-script` on entry point `dev`, commit `e6eded0`, baseline `9563c68`, branch `master`.

---

# QA Report — phoenix-phase-2-staging, audit 29

**Project**: phoenix-phase-2-staging
**Run**: `phoenix-phase-2-staging-29`
**Commit**: `9563c68094e516a91d27684252e6a103271d69cf` (branch `master`)
**Entry points audited**: `dev` and `test:stable-staker`
**Mode**: local-anvil **execution** (not static, not a mainnet fork) — every claim below is backed by a command that was run and its observed output.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 4 (`L-05`, `L-06`, `L-07`, `Q-02`*) |
| QA | 1 (`Q-03`) |
| Centralization | 0 |
| **Total (this run)** | **5** |

\* `Q-02` keeps its original `Q-`label and `issueId` because it is an **update to an existing open ledger entry** first minted at run 28, not a new finding. Its severity move `qa → low` is **proposed only**; a human applies it via `/ledger`.

There are **0 High and 0 Medium** findings in this run. This bundle and [`spec-conformance.md`](spec-conformance.md) are therefore the run's primary reader-facing output.

---

## Read this first — what this run actually found

**The headline is a positive result.** Story-081 set out to close run-28 `M-01` (`11311795cd60…`), the defect where `npm run dev` adopted a node whose provenance it never established. That fix was **proved complete by execution**, not by reading the patch:

- The port pre-flight in `dev-local.sh:48-55` **refuses** to start when anything already answers on `:8545` — observed both against a leftover local anvil and against a live mainnet fork (`Error: something is already answering on http://localhost:8545. ... Kill it (pkill anvil) and re-run.`).
- The genesis-freshness gate `require(vm.getNonce(deployer) == 0, ...)` at `DeployMocks.s.sol:445-446` **fires** on a dirty chain: trace `VM::getNonce(0xf39Fd6e5…) -> 1` then `[Revert] DeployMocks: chain is not fresh - a prior deployment is already on 8545; kill it and re-run`.
- The worst variant — a **mainnet-forked anvil forced to `--chain-id 31337`**, which slips past the chainid gate at `:443` — is **blocked**, because anvil funds its dev account on a fork but **preserves the forked nonce**: `cast nonce 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` → **7893**, the gate reverts, and `grep -c 'deployed at:'` → **0**. Zero mocks landed on forked mainnet state.
- **Phase 7.6's dispatcher-swap rehearsal was observed executing end to end** (not merely reached), in the fail-closed order `pull()` → `hook.setDispatcher(new)` → `new.setHook(hook)` → `replaceDispatcher(idx,new)`, as mined broadcast transactions #434/#438/#439/#440, all `status=0x1`, with a **non-vacuous** conservation assert seeded by a real `5015015000000000000` wei mint debt.

**Severity context — read this before weighing anything below.** `dev` is a **local developer rehearsal harness on a throwaway anvil chain (chainId 31337)**. There are **no user funds, no mainnet broadcast, and no external attacker** anywhere in this closure — the entry point's on-chain target set is empty by construction and all 477 transactions land on a disposable chain. The harm channel for every finding in this bundle is **false assurance about the mainnet cutover this rehearsal certifies**, not asset loss. None of these are talked up beyond that, and none should be.

### Pointers to the rest of this run's output

- **Law-2 faithfulness findings `F-03` and `F-04` are NOT in this bundle.** They live in [`spec-conformance.md`](spec-conformance.md), per Law 2. Do not look for them here.
- **Carryover QA from earlier audits is NOT re-bundled here.** Prior-run Low/QA entries still open (**37 entries** across audits 05, 21, 26, 27 and 28) are carried verbatim, one file per originating audit, under [`carryover/`](carryover/): `qa-report-05.md`, `qa-report-21.md`, `qa-report-26.md`, `qa-report-27.md`, `qa-report-28.md`. **Their `L-`/`Q-` sequences are separate from this run's** — audit 28 also has an `L-05`, and it is a different finding. **Key every reference on the fingerprint, never on the label.**
- **Automated SAST/gas appendix**: [`4naly3er-report.md`](4naly3er-report.md) — **read its scope note first**; it covers the 25 first-party `src/**` contracts only and provides **no** coverage of any finding below (see the appendix section at the end of this file).

---

## Low Risk Findings

### [L-05] `verify-stable-staker.sh` adopts a node it does not own and runs the V1→V2 cutover verification on it <!-- id: pps29l5 -->

| | |
|---|---|
| **Severity** | Low |
| **Entry point** | `test:stable-staker` |
| **Location** | `verify-stable-staker.sh` — readiness loop (lines 51-57) + `cleanup` (lines 32-40) |
| **Fingerprint** | `2f86e3864eadb6e29715fda85d1f5df51a5acf56dff39466505d7defadb69551` |
| **Issue ID** | `pps29l5` |
| **Root cause class** | `UnownedNodeAbsorbsRehearsal` |

**Description**

`verify-stable-staker.sh` starts its own anvil unconditionally — there is **no port pre-flight**, where `dev-local.sh:48-55` now has one. Its readiness loop (lines 51-57) polls only `cast block-number`, with **no `kill -0 "$ANVIL_PID"` liveness check** (`dev-local.sh:76-79` has one), no `ANVIL_UP` flag, and no listener-ownership comparison (`dev-local.sh:99-116` has one). When another process already holds `:8545`, the script's own anvil dies on `Address already in use`, the readiness loop is satisfied by the **foreign** node, and the script announces `Anvil is up.` about a pid that no longer exists. At exit, `cleanup()` kills that dead recorded pid and leaves the foreign node running.

`DeployMocks.s.sol:445` (`require(vm.getNonce(deployer) == 0, ...)`) still blocks the case where the foreign node carries a prior deployment, so adoption only succeeds against a **fresh** foreign node.

**Failure scenario**

A developer leaves an anvil running from an earlier session or another tool — they ran `npm run start:anvil` in a second terminal to poke at something, or a previous `test:stable-staker` exited via the path in this finding. That node is fresh: nothing has deployed to it, so the deployer's nonce is 0. The developer runs `npm run test:stable-staker`. The script's own anvil dies immediately on `Address already in use`; the readiness loop nevertheless sees the foreign node answer and prints `Anvil is up.`; `deploy:local` deploys the whole mock stack onto the foreign node, which passes both the chainid and the freshness gate because it is fresh; STEP 1-3 stake, advance the clock by a day, assert the Antimatter accrual and the withdraw, and the script reports `ALL ASSERTIONS PASSED`. The developer believes they exercised an isolated node they started and controlled; they did not, and the script never told them their anvil died. On exit, `cleanup` kills the dead pid and the foreign node survives at a deployer nonce of 480. The developer's next `npm run dev` now refuses at its pre-flight with `something is already answering on http://localhost:8545`, and their next `npm run test:stable-staker` reverts with `DeployMocks: chain is not fresh`, until they work out that they need to `pkill anvil`.

**The boundary, established by test.** The adopted node must be genuinely fresh for this to reach the assertions. Both worse variants fail closed. If the leftover node already carries a deployment, the freshness gate reverts before anything is deployed. If it is a mainnet fork forced to `--chain-id 31337` — the case that would have made the passing verification genuinely misleading, because the mock stack would land on top of real forked state — the gate **also** reverts, because the deployer is anvil's public account 0 and its real mainnet nonce is **7893** (measured on a live fork at block 25943238; zero mocks deployed, zero assertions reached). The harm is bounded to running on an unowned-but-equivalent node, plus the leftover-node wedge. That is what holds this at **Low** rather than Medium.

**Impact**

(a) The story-080 V1→V2 cutover verification — the automated check that certifies the migration mechanics before they are mirrored to mainnet — executes against a node the operator did not start, does not observe, and cannot attest to. Because the adopted node must be fresh for the deploy to succeed, what passed did legitimately pass; **the loss is the operator's ability to know that.** (b) The run leaves the now-dirty foreign node alive at deployer nonce 480, wedging both local entry points until a manual `pkill anvil`. (c) The `Anvil is up.` line is affirmatively **false** whenever this triggers — the specific misreport story-081 added `kill -0` to `dev-local.sh` to prevent. The impact does **not** extend to a mock stack landing on forked mainnet state; that variant was tested against a live mainnet fork and is blocked.

**Evidence** (executed test D2 — the load-bearing negative)

Setup, measured in the SAME shell invocation immediately before launching the sibling:

```console
$ anvil --host 0.0.0.0 --port 8545 --chain-id 31337 &
$ FPID=$(ss -lptnH 'sport = :8545' | grep -o 'pid=[0-9]*' | cut -d= -f2)
$ echo "FOREIGN anvil pid=$FPID nonce=$(cast nonce 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545)"
FOREIGN anvil pid=58309 nonce=0
```

Then `cd <project>/work && npm run test:stable-staker`. Observed in the log, in order:

```
=== Cleaning previous local deployment artifacts ===
Anvil pid: 58397
Anvil is up.
=== Deploying mocks (deploy:local) ===
...
=== verify-stable-staker.sh: ALL ASSERTIONS PASSED ===
```

`ps -p 58397` → *own anvil 58397 DEAD*. Neither gate fired at any point in the run: `grep -c 'chain is not fresh' D2.log` → `0` and `grep -c 'DeployMocks: local only' D2.log` → `0`, which independently confirms the deployer nonce was still 0 when `deploy:local` ran. After exit: `ps -p 58309` → `58309 anvil --host 0.0.0.0 --port 8545 --chain-id 31337` (**STILL ALIVE**), `cast nonce 0xf39Fd6e5… --rpc-url http://localhost:8545` → `480`.

*Control*: on a clean machine (test D) the same command passes and tears its own anvil down correctly — `Tearing down Anvil (pid 57455)...`, no residual process.

*Evidence caveat, stated plainly*: the nonce was measured at hand-off (immediately before `npm run test:stable-staker` was launched), not at the exact instant `deploy:local` executed. Nothing transacted as the deployer in between — the foreign anvil was started without `--block-time` and sat idle — and the two never-fired gates above prove the nonce was still 0 at the `require`.

**Recommendation**

Give `verify-stable-staker.sh` the same three guards `dev-local.sh` now has, or better, factor them into one shared helper both source: (1) a port pre-flight that refuses to start when `cast block-number` on `:8545` succeeds, with the same "kill it (`pkill anvil`) and re-run" message; (2) a `kill -0 "$ANVIL_PID"` check inside the readiness loop plus an `ANVIL_UP` flag, so a dead anvil fails loudly instead of the loop falling through on a foreign node's answer; (3) the `ss`/`lsof` listener-ownership comparison. Also upgrade `set -e` to `set -Eeuo pipefail` and widen `trap cleanup EXIT` to `EXIT INT TERM`, for the reason story-081 gave: the defect class being fixed is a discarded exit status.

**Triage notes — do not lose these**

> **RE-WEIGH TRIGGER (verbatim):** if the freshness gate is ever changed to something other than a nonce check on account 0, or if a fork target with an unused deployer enters the workflow, re-weigh to **Medium**.

- **Honest residual, recorded not suppressed**: the freshness gate is decisive because of *which key* anvil hands out (account 0 = `0xf39Fd6e5…`, a heavily-used public test key), **not by design**. A fork of a chain on which that address never transacted would still be adopted, and the mock stack would land on top of real forked state. That is a caveat and the re-weigh trigger above — not a Medium trigger today, because no such fork target is in this repo's workflow.
- **DO NOT COLLAPSE with ledger entry `11311795cd60`** (run-28 `M-01`, `dev`, `fix-pending`). Same root-cause *family*, **different entry point** (`test:stable-staker` vs `dev`), which is folded into the fingerprint by design. This is **not** a re-file and **not** an `incompleteFixOf` — the story-081 `dev` fix is **COMPLETE**, proved by execution. Filing it as an incomplete fix would wrongly signal that a correct patch is defective. **Do not close this when `11311795cd60` closes.**

---

### [L-06] Phase 6.5b leaves `CrossVersionMigrator` holding the migrator role on both stakers, and the residual-privilege sweep does not cover it <!-- id: pps29l6 -->

| | |
|---|---|
| **Severity** | Low |
| **Entry point** | `dev` |
| **Location** | `script/DeployMocks.s.sol#L2304-L2312` — `_rehearseStableStakerCutover` |
| **Fingerprint** | `08adbb6928403acea22a033a75ad797e7fe88f7bd15aff8c16af81f554cc3cd8` |
| **Issue ID** | `pps29l6` |
| **Root cause class** | `MissingPostStepConfiguration` |

**Description**

Phase 6.5b sets `stableStaker.setMigrator(migrator)` and `stableStakerV2.setMigrator(migrator)` (`DeployMocks.s.sol:2245-2246`) and **never unsets either**. It revokes the retired V1's phUSD mint grant at `:2308` — the residue story-080 explicitly asked it to decide about — but **not** its migrator role. The immediately comparable phase in the same file, the story-079 PhlimboV2→V3 cutover, does the opposite: step 12 at `DeployMocks.s.sol:2704-2706` is `phlimbo.setMigrator(address(0)); require(phlimbo.migrator() == address(0), ...); console.log("PhlimboV2.setMigrator(0) - migrator role revoked")`. The terminal `_sweepResidualPrivileges` (`:2038`, run-26 `L-04`), which exists precisely to catch leftover privileges, asserts only the phUSD minter table via `_requireLiveMinter` and has **no migrator row**.

**Failure scenario**

The mainnet StableStakerV1→V2 cutover is scripted, as intended, from this rehearsal — it is the only executable description of the sequence, and its post-conditions are what the operator trusts. The operator mirrors Phase 6.5b: seed, wire the migrator on both sides, initiate, page and migrate, assert the pools drained, revoke V1's phUSD grant, done. Every assertion passes and the terminal residual-privilege sweep reports a clean phUSD ACL, **because the sweep only knows about phUSD**. The live StableStakerV2 is left in production with a `CrossVersionMigrator` — a contract with no address-book key, so it does not appear in any address surface anyone reviews — permanently holding its `migrator` role. A single later owner-signed `initiateMigration` through that contract moves a production pool to `PoolState.Migrating`, at which point every stake, withdraw and claim reverts with `StableStaker: pool not active` until the pool is finalized and reset. The operator had no signal that the role was still live, because the sweep that exists to give exactly that signal does not check it.

**Impact**

The local chain ends every `dev` run with an untracked, address-book-less `CrossVersionMigrator` retaining `migrator` on the live StableStakerV2 — a role whose `initiateMigration` would move a production pool to `PoolState.Migrating` and block every stake/withdraw/claim (`StableStakerV1.sol:331/352/396` and the V2 equivalent). The rehearsal therefore does not exercise, and does not prove, the role tear-down step a mainnet cutover would need.

**Evidence**

```console
$ grep -n 'setMigrator' script/DeployMocks.s.sol
2214: ...
2245: stableStaker.setMigrator(migrator);
2246: stableStakerV2.setMigrator(migrator);
2704: phlimbo.setMigrator(address(0));          # Phase 7.4 precedent, 400 lines below
# no setMigrator(address(0)) anywhere in Phase 6.5b

$ grep -n 'onlyOwner' lib/stable-staker/src/CrossVersionMigrator.sol
147: function initiateMigration(address token) external onlyOwner
161: function migrate(address token, address[] calldata users) external onlyOwner
```

`_sweepResidualPrivileges` (`DeployMocks.s.sol:2038-2064`) contains only `_requireLiveMinter` rows. Observed in the happy-path run log (test A): `CrossVersionMigrator (untracked) deployed at: 0xe044814c9eD1e6442Af956a817c161192cBaE98F`, and the run ends with `end-state phUSD ACL asserted: deployer + PhlimboV2 + StableStakerV1 OUT, V3 + minter + StableStakerV2 + 5 hooks IN` — **and no migrator assertion of any kind**.

**Recommendation**

Mirror Phase 7.4: after `_assertStableStakerCutover` passes for all three pools, call `stableStaker.setMigrator(address(0))` with a read-back require, and add a migrator row to `_sweepResidualPrivileges` asserting the expected end-state migrator for every staker and Phlimbo the script deploys — the same table idiom `_requireLiveMinter` already uses, so drift names its own offender. If the destination V2 is intended to keep its migrator (the Phase 7.4 precedent leaves PhlimboV3's in place), assert that positively rather than leaving it unstated.

**Triage notes — do not lose these**

> **RE-WEIGH TO MEDIUM TRIGGER (verbatim):** the moment a mainnet StableStakerV1→V2 cutover script is actually derived from Phase 6.5b, the prospective leg becomes concrete and this is a **Medium**. Re-weigh at that point, do not wait for a second audit to rediscover it.

- **DO NOT COLLAPSE WITH, AND DO NOT LET IT CLOSE ALONGSIDE, ledger `b8e3d59139ae`** (`L-04`, deployer phUSD mint authority, `fix-pending`). Different function, different privilege, different holder, different remedy; `b8e3d59139ae`'s pending fix does not touch the migrator role, so a collapse would let this ride out on that fix and vanish when it closes. The `fix-pending` reconciliation for `b8e3d59139ae` is scoped **exactly** to phUSD mint authority for this reason.
- The recommendation's second half matters as much as the first: the `_sweepResidualPrivileges` migrator row is what makes future drift name its own offender.
- **Not** suppressed under the cached known-issues "Admin trust assumptions" entry: those 11 entries carry no suppression authority (`knownIssuesFile` absent at HEAD), and this is a **non-obvious owner footgun** (Law 3), not an asserted admin-trust assumption. `CrossVersionMigrator.initiateMigration` is `onlyOwner`, so this is not an access-control vector — it is a surprise.

---

### [L-07] A SIGINT/SIGTERM delivered to `dev-local.sh`'s own pid rather than its process group leaves anvil running <!-- id: pps29l7 -->

| | |
|---|---|
| **Severity** | Low |
| **Entry point** | `dev` |
| **Location** | `dev-local.sh#L35-L46` — `cleanup` / `trap` |
| **Fingerprint** | `49b9904ee12a1abe85b63d458fee5ede6f8dd447a309191e51b4efd40a220a56` |
| **Issue ID** | `pps29l7` |
| **Root cause class** | `DeferredTrapDuringForegroundChild` |

**Description**

`trap cleanup EXIT INT TERM` runs `cleanup` only once bash regains control. While `dev-local.sh` is blocked on its final foreground child, `npm run serve`, a trapped signal delivered to the **shell alone** is queued and never handled, because `npm run serve` never returns. An interactive **Ctrl-C is unaffected** — the terminal signals the entire foreground process group, so node exits, npm exits, and bash then runs `cleanup` — but `kill -INT <pid>` or `kill <pid>` against the pid a developer copies out of `ps` does not.

**Failure scenario**

A developer has `npm run dev` running, wants the port back, and does not have the terminal in front of them — they are in a second shell, or a script, or an editor task. They run `ps aux | grep dev-local`, take the pid, and `kill` it. Nothing happens: bash has the signal queued behind `npm run serve`, which never returns, so `cleanup` never runs. The developer sees no `Tearing down Anvil` line, assumes the kill landed, and moves on. anvil is still bound to `:8545` and its deployer nonce is now non-zero from the completed deployment, so their next `npm run dev` refuses at the pre-flight and their next `npm run deploy:local:forge` reverts with `DeployMocks: chain is not fresh` — the script telling them, correctly but confusingly, about a node they believe they already killed.

**Impact**

The developer believes they stopped the stack; anvil is still bound to `:8545` at a non-zero deployer nonce, so the next `npm run dev` refuses at its pre-flight and the next `npm run deploy:local:forge` reverts on the freshness gate until they `pkill anvil`.

**Evidence**

With the stack fully up (`dev-local.sh` pid 48591, anvil pid 48640, `npm run serve` answering HTTP 200 on `:3001`):

```console
$ kill -INT 48591          # the SCRIPT PID ALONE
# 6 seconds later:
dev-local ALIVE
48640 anvil --host 0.0.0.0 --port 8545 --chain-id 31337 --block-time 2
node server/index.js
$ cast block-number --rpc-url http://localhost:8545
583
```

*Control* — the same signal to the process **group**, i.e. what Ctrl-C does:

```console
$ kill -INT -48579
Tearing down Anvil (pid 48640)...
$ cast block-number --rpc-url http://localhost:8545
Error: error sending request for url (http://localhost:8545/)
```

**Recommendation**

Have `cleanup` also kill anvil's process group, and stop blocking on a child that ignores the queued trap — e.g. run `npm run serve` in the background and `wait` on it (bash runs a pending trap as soon as `wait` is interrupted), or `exec` the server so there is no shell left to deceive. A one-line note in the script's usage comment that the stack must be stopped with Ctrl-C, not `kill <pid>`, would also close it.

**Triage notes — do not lose these**

- **NOT an `incompleteFixOf` ledger `11311795cd60`.** That entry's claim is freshness/ownership *assertion*, which `dev-local.sh` now performs correctly; this is a residual gap in the same script, a **different mechanism**. Filing it as an incomplete fix would wrongly signal the story-081 patch is defective, when execution proved it complete.
- **NOT a story-081 faithfulness deviation.** Story-081's acceptance scopes teardown to the developer Ctrl-C-ing out, and that path works. The non-interactive kill was never claimed. It is a code Low, not an `F-XX`.
- **Chain to keep intact for triage**: **L-07 leaks the node → L-05 absorbs it → `11311795cd60` was the `dev`-side half, now fixed.** Three separate defects, not one finding. Do not collapse.

---

### [Q-02] `npm run dev` cannot run on a clean shell: `ANVIL_PRIVATE_KEY` is hard-required but set nowhere in the repository <!-- id: pps28q2 -->

| | |
|---|---|
| **Severity** | **qa → low (PROPOSED; human `/ledger` applies)** |
| **Entry point** | `dev` |
| **Location** | `script/DeployMocks.s.sol#L419` — `run` |
| **Fingerprint** | `d3aa1e35c995a93509a1c3ce85cbd6654319dd5623b20a67b0e7852f81bf602f` |
| **Issue ID** | `pps28q2` (minted at run 28 — **kept verbatim, never restamped**) |
| **Ledger root cause class** | `UndocumentedRequiredEnvVar` (**authoritative**) |
| **Ledger action** | **UPDATE** existing open entry `d3aa1e35c995…`. **Do NOT insert a new entry.** |

**Description**

`DeployMocks.s.sol:419` reads `vm.envUint("ANVIL_PRIVATE_KEY")`. Neither `dev-local.sh`, `package.json`, nor any tracked file in the repository sets or exports it; `git ls-files | grep -i env` returns nothing and there is no `.envrc`, `.env` or `.env.example` in the source tree. Its only in-repo occurrence is a literal inside `CLAUDE.md:476`, in a block headed "Required Variables in `.env`" — a file the repo neither ships nor ships an example of, even though `CLAUDE.md:93-94` lists `.env.example` in its own directory-layout diagram and `CLAUDE.md:454` instructs the reader to "Create `.envrc.example`". The same variable is read by `script/interactions/StakeStableStaker.s.sol:37` and `ClaimWithdrawStableStaker.s.sol:40`, so `npm run test:stable-staker` inherits the dependency.

**Failure scenario**

A new developer clones phoenix-phase-2-staging, runs `npm install`, and follows the documented entry point with `npm run dev`. The port pre-flight passes, `clean:local` runs and deletes two tracked files, anvil starts and all four shell gates pass — and then the forge leg reverts at `DeployMocks.s.sol:419` with `environment variable "ANVIL_PRIVATE_KEY" not found`. There is no `.env.example` in the tree to copy, so the only path to the value is finding the literal buried at `CLAUDE.md:476`. The developer is left with no dev stack and a working tree in which `broadcast/DeployMocks.s.sol/31337/run-latest.json` and `server/deployments/progress.31337.json` are now **deleted**.

**Impact**

A developer cloning the repo and running the documented entry point gets a revert rather than a dev stack. This audit's own happy-path run only succeeded because direnv had already exported the variable from an **out-of-repo** `.envrc`; re-running with `env -u ANVIL_PRIVATE_KEY` reproduced the failure. That escalates the *consequence* (entry point unrunnable, not merely undocumented), which is the basis of the proposed `qa → low` move.

**Evidence** (executed test B)

```console
$ cd <project>/work && env -u ANVIL_PRIVATE_KEY ./dev-local.sh
...
[4141] DeployMocks::run()
  |- [0] VM::envUint("ANVIL_PRIVATE_KEY") [staticcall]
  |   |- <- [Revert] vm.envUint: environment variable "ANVIL_PRIVATE_KEY" not found
Error: script failed: vm.envUint: environment variable "ANVIL_PRIVATE_KEY" not found
EXIT=1
```

The trap fired correctly (`Tearing down Anvil (pid 50443)...`; no residual anvil), and the failed run left two **tracked** files deleted (` D broadcast/DeployMocks.s.sol/31337/run-latest.json`, ` D server/deployments/progress.31337.json`).

Provenance of the value in the passing run: `/home/justin/code/audits/.envrc` line 18 plus a byte-identical **gitignored** copy at `<project>/work/.envrc` (`git check-ignore -v .envrc` → `.gitignore:6:.envrc`). `ls -a <project>/src | grep -i env` → no match.

**Recommendation**

Either default it in the script — `vm.envOr("ANVIL_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80))`, which is safe precisely because `DeployMocks.s.sol:443` already requires chainid 31337 and the key is anvil's publicly-known account 0 — or export it in `dev-local.sh` next to the existing `LOCAL_PROMO_KENDU=true`. Whichever is chosen, commit the `.env.example` / `.envrc.example` that `CLAUDE.md:93` and `:454` already promise, so the dependency is discoverable before the revert.

**Triage notes — do not lose these**

- The escalation is **PROPOSED ONLY** and must be applied by a human via `/ledger`. This is an **UPDATE** to open entry `d3aa1e35c995…`, not a new entry.
- **ROOT-CAUSE-CLASS DISCREPANCY, FLAGGED NOT SILENTLY RESOLVED.** The finding object's own `rootCauseClass` field reads `UndeclaredAmbientEnvDependency`, but the dedup block explicitly **rejects** that string and preserves the ledger's `UndocumentedRequiredEnvVar`. Both are recorded verbatim above. **The LEDGER value is authoritative**: fingerprinting on the finding's own string would re-mint `d3aa1e35c995` into a second fingerprint for one defect and orphan `Q-02`'s history (the ledger rootCauseClass mislabel trap). Do not use this finding's `rootCauseClass` as a fingerprint basis.
- **ACCURACY CORRECTION**, carried from the sanitizer and endorsed: `Q-02`'s original title text "nor documents it anywhere the operator will look" is **overstated** — the value *is* at `CLAUDE.md:476`. The accurate claim is that it is documented **only in prose** and provided by **no mechanism**. The escalation rests on the second half, which is verified.
- The failed-run tracked-file deletion is **not** a new finding: it is a sharpening of existing entry `bd268808fbd5` (note-append only, no fingerprint change).

---

## QA

### [Q-03] `dev-local.sh` duplicates `start:anvil`'s flags inline, so editing the `start:anvil` key no longer reaches `npm run dev` <!-- id: pps29q3 -->

| | |
|---|---|
| **Severity** | QA |
| **Entry point** | `dev` |
| **Location** | `dev-local.sh#L69-L71` — anvil launch |
| **Fingerprint** | `111b6f04c9b72ba71e4ad9eb7d2dc5df01790dce7e97d1fe95e093d0ef9b41af` |
| **Issue ID** | `pps29q3` |
| **Root cause class** | `DuplicatedConfigurationSurface` |

**Description**

`dev-local.sh:69` starts anvil directly rather than via `npm run start:anvil`, **for a good and documented reason**: `$!` must be anvil's own pid or the listener-ownership comparison at `:110` and the trap at `:36` would both be meaningless. The consequence is that the flag string now exists in two places, and `package.json`'s `start:anvil` key — left byte-identical on purpose — is no longer on `dev`'s path.

**Failure scenario**

A developer needs the local chain to mine instantly instead of every 2 seconds, or needs more pre-funded accounts, or wants to point the local stack at a fork. They edit the obvious place — the `start:anvil` key in `package.json` — confirm it by running `npm run start:anvil` directly, and see the new behaviour. They then run `npm run dev` and get the **old** configuration, with no error and no warning, because `dev-local.sh:69` carries its own copy of the flags. Debugging starts from the false premise that the flag change did not take effect at all.

**Impact**

A future change to the anvil configuration made in the obvious place (a different chain id, a `--fork-url`, a `--block-time` change, extra accounts) silently does not apply to `npm run dev`, and the two local environments diverge without any error.

**Evidence**

```console
$ jq -r '.scripts["start:anvil"]' package.json
anvil --host 0.0.0.0 --port 8545 --chain-id 31337 --block-time 2

$ sed -n '69p' dev-local.sh
anvil --host 0.0.0.0 --port 8545 --chain-id 31337 --block-time 2 &
```

Byte-identical as of `9563c68`. Corroborated at runtime: the happy-path run printed `Confirmed: pid 48640 owns 8545.`, i.e. the direct-launch pid reasoning works and should be kept.

**Recommendation**

Keep the direct launch (the pid reasoning is correct) but stop duplicating the string: define the flags once — e.g. an `ANVIL_FLAGS` value sourced from a single file that `start:anvil` also uses, or have `dev-local.sh` read the flags out of `package.json` — or, at minimum, add a comment on the `start:anvil` key pointing at `dev-local.sh:69` so an editor of either is told about the other.

**Triage notes — do not lose these**

- This is a **severity move, not a suppression**. The finding is retained in full. Dropping it would have been the report-tidiness trade Law 1 forbids; re-labelling it to the band its own rationale describes is not that trade.
- The **minimum acceptable remedy** is the cheapest one above: a comment on the `start:anvil` key pointing at `dev-local.sh:69`. If only one thing is done, do that — it converts a silent divergence into a visible one.
- **DO NOT COLLAPSE WITH `L-07`** (`DEDUP-29-07`). Same file is **not** a root cause: this is configuration duplication in the anvil **launch** line; `L-07` is signal delivery in the **trap/cleanup** path.

---

## Centralization Risks

**None filed this run.** The only privilege-shaped finding in this bundle, `L-06`, is filed as a **Low operational footgun** rather than a centralization risk: `CrossVersionMigrator.initiateMigration` and `.migrate` are both `onlyOwner`, and under Law 3 the owner is trusted for knowing actions. `L-06` qualifies because the consequence is **non-obvious** — the sweep that exists to report residual privileges does not report this one — not because the owner holds the role.

---

## Appendix — Automated report (4naly3er)

Attached as [`4naly3er-report.md`](4naly3er-report.md), generated against `lib/phoenix-phase-2-staging` @ `9563c68`.

**Scope, and what it does not cover.** The appendix analyses the **25 first-party `src/**/*.sol` files** (`src/mocks/`, `src/views/`) and reports gas/NC instances only. It **excludes**:

- `script/DeployMocks.s.sol` and `script/interactions/FundTestUser.s.sol` — the contracts `L-06` and `Q-02` are actually filed against. They were **re-attempted at HEAD `9563c68` and re-confirmed to fail**, with 12 `DeclarationError: Identifier already declared`, because 4naly3er's own solc invocation does not honour the repo's `lib/<a>/lib/<b>/=` diamond-canonicalization remappings (`foundry.toml:49-77`), so `IPausable` and siblings resolve from two physical files. This is a **tool limitation, not a defect in the scripts** — they compile cleanly under forge and were executed end to end on chain 31337 during this audit (477 tx / 477 receipts / 0 failed). The same limitation was recorded at run-25 and run-27; it was re-tested, not assumed. Remappings were supplied by materialising `foundry.toml`'s `remappings` array into a `remappings.txt` inside a throwaway hardlink copy of the submodule; `lib/` itself was **not** written to.
- `dev-local.sh` and `verify-stable-staker.sh` — the files `L-05`, `L-07` and `Q-03` are filed against. These are **shell**, which no Solidity SAST reaches at all.

**Consequence, stated so it cannot be misread**: the appendix neither corroborates nor contradicts any finding in this bundle. **A clean line there is not a clean line here.**


---

<!-- Part B: verbatim copy of reports/30/submissions/carryover/spec-conformance-29.md -->

# Part B: Law-2 / spec-conformance entries (verbatim)

---

# Carryover spec-conformance report — audit 29 (entry point `dev`), carried at audit 30

> **Carryover Law-2 report — audit 29** (copied in full from
> [`reports/29/submissions/spec-conformance.md`](../../29/submissions/spec-conformance.md)).
> Prepended header by audit 30; **the body below is a verbatim copy and has not been edited.**
>
> - **Retained (still open as of audit 30): `F-03` (`c476a12b04fa…` / `pps29f3`) and `F-04`
>   (`ee5aae66ac65…` / `pps29f4`), plus audit-28's `F-01`/`F-02` which that report already carried.**
> - **Removed as no longer live: none.**
> - **Statuses changed by audit 30 in this file: NONE.**
> - **⚠ `F-04` DO-NOT-COLLAPSE against `pps29f3` / `c476a12b04fa…` still binds at audit 30 and was
>   respected — the two were not merged.**
> - **Line numbers below were accurate at the originating commit `9563c68`. Re-verify against
>   current HEAD `e6eded0` before acting.**

---

# Spec Conformance (Law 2) — phoenix-phase-2-staging, script audit of the `dev` entry point (run 29)

**Project**: phoenix-phase-2-staging  ·  **Run**: `phoenix-phase-2-staging-29`
**Commit**: `9563c68094e516a91d27684252e6a103271d69cf` (`9563c68`), branch `master`
**Baseline**: `f929b5b` (`entryPointBaselines.dev`, set by run 28)
**Entry points**: `dev` (primary) and `test:stable-staker` (new — surfaced by this run)
**Delta commits**: `ac70af6` [story-080], `9563c68` [story-081]
**Mode**: local-anvil **real execution**, chain 31337 only. 11 executed tests. No mainnet fork.

This run raises **two new Law-2 findings** — `F-03` and `F-04`, both against **story-080** — and
**carries forward `F-01` and `F-02` unchanged**. Both new findings are Low: neither has asset, value
or availability impact, so **neither owes a separate High/Medium label or report**.

| Label | `issueId` | Fingerprint | Story | Deviation type | Severity |
|---|---|---|---|---|---|
| **F-03** | `pps29f3` | `c476a12b04fa…` | story-080 | **UNDECLARED** | Low |
| **F-04** | `pps29f4` | `ee5aae66ac65…` | story-080 | **DECLARED-BUT-UNMET** | Low |
| F-01 *(carried)* | `pps28f1` | `dcf756f7a897…` | story-079 | contravened | Low |
| F-02 *(carried)* | `pps28f2` | `beb259209f88…` | story-079 | contravened | Low |

## Stories graded against, and the weight their verification carries

Both delta stories live in **`auto-complete`** with **self-reported** verification:

- `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/080-deploymocks-stablestakerv2-antimatter-cutover.md`
- `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/081-dev-genesis-freshness-gate.md`

Three provenance facts bear on how much the ticked boxes are worth, and all three are stated in the
story documents themselves:

1. **story-080's review self-reports `independence: reduced`** — *"these verdicts were reached by one
   agent rather than five."* Independence from the *executor* is intact; independence among the
   reviewers is not.
2. **story-080 was auto-completed by machine approval**, *"Approved by: story-batch workflow (machine
   approval — not human-reviewed)"*, on a `PASSED` review that itself carried a `[medium] Verification
   gap`: *"the review did not independently re-execute `npm run test:stable-staker` (it needs a live
   anvil and a full deploy)."*
3. **story-081's four gates were hand-run only.**

**All four of story-081's gates were independently re-verified by execution in this run**, and
story-080's Phase 7.6 claim was likewise verified by execution (subject to the re-run provenance
caveat recorded in the run-26 carryover bundle). The verification gap story-080's own review flagged
as `[medium]` — `npm run test:stable-staker` never re-executed — **was closed by this audit**: the
harness was run on a clean machine, which is how `F-03` was found.

---

## F-03 — `verify-stable-staker.sh` and its `package.json` doc key both state an assertion the harness no longer makes <!-- id: pps29f3 -->

**Fingerprint**: `c476a12b04faf476e46dca810c87bb18357daab3760584328074bb7273267856`
**Basis**: `lib/phoenix-phase-2-staging/verify-stable-staker.sh:header comment (lines 6-10); package.json `//verify-stable-staker`:DocumentedAssertionDivergesFromImplementation:test:stable-staker`
**Location**: `verify-stable-staker.sh#L6-L10`; `package.json:36`
**Entry point**: `test:stable-staker` (**new** — this run created its ledger baseline)
**Deviation type**: **UNDECLARED**

### The acceptance text this violates, verbatim

From story-080's ticked acceptance checklist:

> changed the reward assertion from `~10 phUSD` claimed to `~10 Antimatter` **ACCRUED**

### What shipped

`ClaimWithdrawStableStaker.s.sol:86-98` asserts **the caller's pro-rata share**, not a flat ~10:

```
expected = (EXPECTED_DAILY_REWARD * stakedPrincipal) / totalStakedNow      // ±1% band
```

### The deviation

**The implementation is right and the documentation is wrong.** Story-080's *own* Phase 6.5b seeding
puts 12 more actors (1,200 DOLA) into the V1 DOLA pool and migrates them to V2, so the verifier's own
1,000 DOLA stake is a **minority** of V2's DOLA pool and its daily share is well under 10. A flat
"~10" assertion would now fail for a reason unrelated to configuration. Autonomous **Decision 8**
records the generalisation of the *assertions*:

> The reward assertion is now `10e18 * stakedPrincipal / totalStaked` ±1% … The flat figures would now
> fail for a reason unrelated to configuration, and deleting them would leave the rate unchecked.

**But two documentation surfaces still state the superseded assertion**, and neither the checklist
line nor Decision 8 records that they were left behind:

- `verify-stable-staker.sh:9` — `# the accrued reward (~10 Antimatter), that \`claim\` is still closed, and the`
- `package.json:36` — `assert ~10 Antimatter accrued`

So the deviation is **undeclared**: the checklist tick says one thing, the code does another (correctly),
and the story's deviation list is one entry short.

### Evidence — executed, not argued

Ran `npm run test:stable-staker` in `<project>/work/` on a clean machine. Observed:

```
claimableReward (Antimatter):                        4545507154882125000
Expected pro-rata daily reward (Antimatter):         4545454545454545454
Antimatter reward accrued (pro-rata share of 10/day): 4545507154882125000
=== verify-stable-staker.sh: ALL ASSERTIONS PASSED ===
```

**4.5455**, against a documented **~10**.

### Why it matters

A developer who changes the DOLA pool's `antimatterPerDay` rate, or adds a staker to the Phase 6.5b
seed set, will see `npm run test:stable-staker` fail on *"reward below the pro-rata daily lower
bound"*. They will read the script header and the `package.json` doc key — both of which say the
harness asserts *"~10 Antimatter accrued"* — see a printed **4.5455**, and conclude the emission rate
is broken. They will then go looking for a bug in `StableStakerV2`'s accrual maths, when the assertion
that actually fired is a pro-rata bound whose **denominator their change moved**. Both surfaces have
been wrong since `ac70af6`, and they point the investigation at the wrong contract.

### Recommendation (verbatim from the finding record)

> Update both strings to say the assertion is the caller's pro-rata share of the pool's 10
> Antimatter/day (the in-script comment at `ClaimWithdrawStableStaker.s.sol:86-91` already explains it
> well and can be quoted), and record the change as a story-080 Autonomous Decision so the checklist
> tick matches what shipped.

### Severity

**Low.** QA/documentation, no execution consequence — the harness itself is correct and self-documents
the change. Kept at Low rather than QA only because it is an **undeclared divergence from a ticked
story-080 acceptance line**, and the two stale surfaces are the first thing a developer reads when a
run fails.

**⚠ Do not collapse with `F-04`.** Different file, different mechanism (a stale human-readable
assertion string vs an absent type-level drift guard), different remedy. They share a story-080
**provenance**, which is not a shared root cause; collapsing on provenance would erase one of two
independent deviations.

---

## F-04 — story-080's declared drift guard does not exist, and the two files already disagree <!-- id: pps29f4 -->

**Fingerprint**: `ee5aae66ac651277953db1b477d4ba66939701ec5aa7ffe013c2b26b9865e678`
**Basis**: `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts:mainnetAddresses: ContractAddresses:UnenforceableDeclaredDriftGuard:dev`
**Location**: `server/deployments/mainnet-addresses.ts#L39`
**Entry point**: `dev`
**Deviation type**: **DECLARED-BUT-UNMET**

### The acceptance text this violates, verbatim

From story-080's ticked acceptance checklist:

> Confirm `tsc` passes — the `: ContractAddresses` annotation on `mainnetAddresses` is the **only drift
> guard** between the two files.

And from the story's Technical Details, stating the same premise:

> `server/deployments/mainnet-addresses.ts` is hand-maintained — mainnet codegen was removed in story
> 068 — and its key-set must mirror the generated interface exactly, since that `: ContractAddresses`
> annotation is the only drift guard. It must be edited in the same commit or `tsc` fails.

### What shipped

**No `tsconfig.json` exists anywhere outside `node_modules`/`lib`.** `tsc` has nothing to act on, so
the annotation is never checked. Autonomous **Decision 6** records this **honestly**:

> This repository contains **no `tsconfig.json`** anywhere outside `node_modules`/`lib`, so there is no
> TypeScript project to compile … **Decision**: Verified the actual drift guard directly — that the
> `ContractAddresses` interface key-set in the generated `server/deployments/addresses.ts` and the
> key-set of the hand-maintained `server/deployments/mainnet-addresses.ts` agree on **this story's
> keys** (`StableStaker` gone, `StableStakerV2` and `Antimatter` present).

**The honesty is creditable, and it is why this is Low rather than higher.** But the box is ticked, the
acceptance criterion is not met, and by the story's *own words* — *"the only drift guard"* — there is
now **no drift guard at all**.

### The guard would fail today if it existed

Decision 6's manual substitute checked only *this story's keys*. A full key-set comparison, run
independently this audit, finds the two files **already disagree**:

```
find <project>/work -maxdepth 2 -name 'tsconfig*.json' -not -path './node_modules/*'   ->  no results

interface keys: 56 | mainnet keys: 59 | local keys: 56
IN INTERFACE, MISSING FROM mainnet-addresses.ts:  []
IN mainnet-addresses.ts, NOT IN INTERFACE:        ['BurnerEYE', 'BurnerFlax', 'BurnerSCX']
interface-vs-local delta:                         []
```

The direction that would be a hard `tsc` error is clean; but `mainnet-addresses.ts` carries **three
keys the interface does not declare**, and TypeScript's **excess-property checking on a typed object
literal** would reject them. The check the story claims to have performed would **fail today**.

### Why it matters

`npm run dev` **regenerates** `server/deployments/addresses.ts` — the `ContractAddresses` interface —
on **every run**, via `server/generate-ts-addresses.js:63`. Any future `_trackDeployment` addition or
removal in `DeployMocks` therefore silently re-shapes the interface that `mainnet-addresses.ts` is
annotated against. **This delta already exercised that exact path** (`StableStaker` removed,
`Antimatter` and `StableStakerV2` added). The repo's CI runs `forge fmt --check`, `forge build --sizes`
and `forge test` — none of which has anything to say about TypeScript. The drift surfaces later, in a
downstream UI project that copies both files in and fails to build, or worse reads a key that silently
resolves to `undefined`.

### Recommendation (verbatim from the finding record)

> Add a minimal `tsconfig.json` covering `server/deployments/*.ts` with `strict: true`, and either
> declare the three `Burner*` keys on `ContractAddresses` (by adding their `_trackDeployment` calls,
> the codegen path story-080 itself insists on) or drop them from `mainnet-addresses.ts`. Then wire
> `tsc --noEmit` into the same GitHub workflow that already runs `forge fmt --check` /
> `forge build --sizes` / `forge test`, so the guard is **enforced** rather than **asserted**.

### Severity

**Low.** No runtime consequence in this repo — `mainnet-addresses.ts` is a hand-maintained copy-out
artifact and nothing in-tree reads it. But `dev` **regenerates the interface every run**, so the one
thing standing between a silent key-set drift and a broken downstream UI is a check the story claims to
have performed and that **no tool in this repo can perform**.

**⚠ Do not collapse with `F-03`** (see above), and **do not collapse with run-28 `L-07`**
(`98e727214903…` / `pps28l7`): that is a *de-tracked seed artifact* breaking standalone runs, this is
an *unenforced type annotation*. Same `server/deployments/` family, distinct defect.

---

## Story-080 deviations judged SAFE and honestly recorded

Law 2 grades **both directions**. Story-080 departed from its own checklist in five further places;
every one was **recorded in the story document** and every one is, on this audit's reading, **correct**.
They are listed here so the record is complete and so a later reader does not re-open a settled
question.

| # | Decision | What the checklist implied | What shipped, and why it is safe |
|---|---|---|---|
| **1** | **Decision 2** — USDe registered on `PhusdStableMinter` | Not contemplated | Registration was required for `autoAnnihilateAvailable(USDe)` to hold; without it the Phase 6.5a post-condition could not be asserted at all. Additive, local-only, and disclosed. |
| **2** | **Decision 3** — principal-conservation assertion is **per-strategy**, not universal | A universal conservation assert | A universal assert would be false by construction: ERC4626 rounding plus the 10% set-aside buffer make exact equality unattainable for the market strategy. The shipped form is `maxLossBps = 0` (exact + 2 wei) for DOLA/USDC and `100` for USDe — **the USDe band is the only relaxation**, and it is the narrowest one that can hold. Verified by execution: the postcondition passed with those bands. |
| **3** | **Decision 4** — the V1 phUSD mint grant is **REVOKED after** the cutover | Revocation, ordering unstated | Ordering is the whole safety property, and it shipped **correct**: `_assertStableStakerCutover` runs at `DeployMocks.s.sol:2296`, *then* `phUSD.setMinter(stableStaker, false)` at `:2308`. Revoking **before** the drain assert would have bricked the very migration being asserted. Verified by execution — postcondition *"V1 loses its phUSD mint grant, AFTER the drain assert"* **PASSED**. |
| **4** | **Decision 5** — the two archived interaction scripts were **retargeted**, not merely re-keyed | *"change their progress-JSON key to `.contracts.StableStakerV2.address`"* | Merely re-keying would point a `StableStakerV1`-typed script at a V2 address whose reward token is Antimatter and whose `claim` is disabled — **it would revert**. The scripts were retyped onto `StableStakerV2` and the claim leg now asserts the *closed door* (`claimEnabled` still false, no Antimatter minted, `withdraw` banks the accrual into the `unclaimedReward` backlog rather than forfeiting it). The story forbids enabling claims, so asserting the closed door is the only honest version of the reward leg. |
| **5** | **Decision 7 — the inversion** | *"Fix `verify-stable-staker.sh` lines 56 and 67 to point at `script/archives/interactions/`"* | **The implementation did the opposite of the literal instruction, and that is correct.** `foundry.toml:32` carries `skip = ["script/archives/**"]`, so a script under that path answers `Error: Could not find target contract` — the target is **excluded from compilation, so no path repair can make it runnable.** The executor verified this **by running it**, then `git mv`'d both files into `script/interactions/` — exactly the paths `verify-stable-staker.sh` already named — and left the shell script's two lines untouched, adding a comment recording why. The story's own Verification checklist requires `npm run test:stable-staker` to **run**, and the prescribed repair **cannot achieve that**. The alternative (removing `script/archives/**` from `skip`) was considered and correctly rejected: the rest of that directory is pinned to submodule interfaces that have moved on and no longer compiles. **Confirmed by execution this run — the harness runs.** |

**Decision 8** (`verify-stable-staker.sh`'s assertions generalised to pro-rata) belongs in this list on
its **code** half — the generalisation is right, for the reasons Decision 8 gives. Its **documentation**
half is what `F-03` files. **Decision 6** is what `F-04` files: honestly recorded, still unmet.

---

## Carried forward unchanged — F-01 and F-02 (story-079)

**Neither commit in this delta touches `_seedNudgeStream` or the `LOCAL_PROMO_KENDU` pin.** Both
findings are therefore **carried forward verbatim** — not re-derived, not re-graded, not
re-fingerprinted. **story-079's verbatim instruction — *"Do NOT gate the Kendu nudge stream"* — remains
contravened at `9563c68`.** Their ledger entries stay `open`; run 29 proposes nothing on either.

The two sections below are a **verbatim copy** of the audit-28 spec-conformance report. Line numbers and
links were accurate at `f929b5b`; **re-verify against `9563c68` before acting.**

---

## F-01 — `dev` pins `LOCAL_PROMO_KENDU=true`, making the dormant (day-one mainnet) leg unreachable <!-- id: pps28f1 -->

**Fingerprint**: `dcf756f7a8977d7d8f3b8b3fb96cbe478f392b057ac045cb0e5928164123d92a`
**Basis**: `lib/phoenix-phase-2-staging/package.json:dev:EntryPointPinsRehearsalToNonMainnetLeg:dev`
**Location**: `lib/phoenix-phase-2-staging/package.json:16` (the `dev` key)
**Story graded against**: story 079
**Story document**: `/home/justin/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`
**State folder**: `complete`  ·  **Sprint folder**: `phStaging2-script-audit-26`
**Story base commit** (from the document header): `1d8a3a7515adca7819c530a01a87c132863a5ae2` — exactly this audit's baseline.

### The acceptance text this violates, verbatim

From the story's *Explicitly OUT of scope (do not touch, do not "helpfully" fix)* list, line 32:

> - `src/` contracts, the UI repo, `package.json`, and `.envrc` secrets.

And from the story's closing checklist, line 547:

> - [x] Confirm no mainnet script, no `src/` contract and no `package.json` key was modified — `git status --porcelain` shows only `script/DeployMocks.s.sol`

That checkbox is **ticked** in the story document. It is false at `f929b5b`: `package.json:16` now
carries `LOCAL_PROMO_KENDU=true` inside the `dev` key.

For context, the fix story 079 was written to deliver (its remediation table, line 21):

> | `pps26l3` (L-03) | The Kendu promotion is armed unconditionally at the end of every local run, so the **dormant** promo state mainnet ships on day one is the one state `dev` can never produce | Gate the arming on a global boolean, default ON |

### The deviation

The contract-script half of that fix **landed correctly**. `DeployMocks.s.sol:398` reads
`armKenduPromo = vm.envOr("LOCAL_PROMO_KENDU", true)`, and a full dormant leg exists at `:400`,
`:1631-1639`, `:2044-2061` and `:2193-2199` — armed-by-default included, exactly as mandated.

The delta then added the assignment to the `dev` key itself:

```
"dev": "npm run clean:local && npm run start:anvil & sleep 3 && LOCAL_PROMO_KENDU=true npm run deploy:local && ./simulate-yield.sh && ..."
```

A command-prefix assignment **overrides the inherited environment**, so the toggle is inert from
outside. Verified:
`LOCAL_PROMO_KENDU=false bash -c 'LOCAL_PROMO_KENDU=true sh -c "echo \$LOCAL_PROMO_KENDU"'` → `true`
(control without the prefix → `false`). A developer who follows the instruction the script itself
prints cannot make it take effect.

The script contradicts its own entry point in three places:

- `DeployMocks.s.sol:210-213` (NatSpec): *"Set LOCAL_PROMO_KENDU=false to boot the DORMANT chain
  instead — the state mainnet actually ships on day one, and the one state this script could
  previously never produce."*
- `DeployMocks.s.sol:1634`, printed at the end of **every** `dev` run and captured verbatim in this
  run's live log: *"Set LOCAL_PROMO_KENDU=false to boot the DORMANT (day-one mainnet) chain"*.
- `DeployMocks.s.sol:1984`: *"Do not read the armed leg's behaviour as a prediction of mainnet's."*
  `dev` pins the rehearsal to precisely the leg its author says must not be read as a prediction.

The day-one mainnet configuration — `promoToken == address(0)`, `promoRewardBalance == 0`,
phUSD/Kendu streams whitelisted-but-unregistered — is therefore unreachable through `npm run dev`
without editing `package.json`. Story 076 (`complete/phStaging2-promotion-ready/076-…`, checklist
line 566) requires of the mainnet cutover:

> - [x] **No `startPromotion` call anywhere.**

So the shape the UI must render gracefully on day one is the one shape the entry point anyone runs
never produces, while the divergent armed shape is rehearsed every time.

This is **not an incomplete fix of L-03 as filed** — the fix landed complete. It is a correct fix
**partially reverted one layer up**, by one of the nine untagged commits in this delta.

### Consequence for triage (ledger)

- Ledger `L-03` / `pps26l3`, fingerprint `12bcca3b617c6c077babfad810a2457a1b8f3a5d352217b4acb135e8b9859e79`,
  status **`fix-pending`** — must be **HELD at `fix-pending`**.
- **Run-27's propose-fixed for this entry is WITHDRAWN.** The behaviour L-03 demands cannot be
  verified through the only entry point anyone runs, so no verification of the fix is possible from
  `dev` at `f929b5b`. A fix that cannot be exercised is not a verified fix.
- No status was changed by this run. This is a **proposal only**; apply nothing without
  `/ledger phoenix-phase-2-staging …`.

Local-only, so no funds are at risk. It is Low because it degrades the evidentiary value of the
rehearsal and silently undoes work a human triaged as `fix-pending` — the exact class the ledger's
INCOMPLETE-FIX rule exists to catch.

### Recommendation (verbatim from the finding record)

> Delete `LOCAL_PROMO_KENDU=true` from the `dev` key and let `vm.envOr`'s default supply the armed
> leg (identical behaviour, toggle restored). If an explicit armed default is wanted at the npm
> layer, add a second key (`dev:dormant` with `LOCAL_PROMO_KENDU=false`) rather than pinning the
> only one. Add a rehearsal obligation that BOTH legs are booted before a mainnet cutover, since
> only the dormant leg matches day one.

---

## F-02 — `_seedNudgeStream` gated behind the optional leg, disarming a load-bearing fee-on-transfer probe <!-- id: pps28f2 -->

**Fingerprint**: `beb259209f88e76e748c09fd10a3bdeb63339edcf9dab180b4bcacdc0caae798`
**Basis**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:_registerNudgeStreams / _seedNudgeStream:SafetyProbeGatedBehindOptionalLeg:dev`
**Location**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:2044-2061` (gating block); probe at `:2069-2096`
**Story graded against**: story 079
**Story document**: `/home/justin/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`
**State folder**: `complete`  ·  **Sprint folder**: `phStaging2-script-audit-26`

### The acceptance text this violates, verbatim

From *Implementation Notes*, lines 476-478:

> **Do NOT gate the Kendu nudge stream.** `_seedNudgeStream` (`:1781-1788`) mints MockKendu for the
> *nudge stream*, which is a different mechanism from the PhlimboV3 promotion and is unrelated to
> L-03. It stays unconditional.

The instruction is unambiguous, is bolded in the story, and gives its reason: the nudge stream is a
*different mechanism* from the PhlimboV3 promotion, so the promotion toggle has no business
governing it.

### The deviation

`git diff 1d8a3a7 f929b5b -- script/DeployMocks.s.sol` moves `nudgeStreamer.registerStream(phUSD)`,
`registerStream(mockKendu)` and **both** `_seedNudgeStream` calls inside `if (armKenduPromo) { … }
else { … }` at `:2044-2061`.

The consequence is concrete, not cosmetic. `_seedNudgeStream` is self-documented as doubling as the
fee-on-transfer probe and terminates at `:2096` in:

```solidity
require(received == amount, "nudge seed token is fee-on-transfer: streamer received < sent");
```

described in-source as *load-bearing, not decorative*. Under the gating, that assertion executes on
the **armed leg only**. The dormant leg — the one that matches day-one mainnet — performs no
seeding and therefore **runs no probe at all**, silently.

### Ordering hazard — state this before scheduling either fix

Today the probe does in fact run on every `npm run dev`, because F-01 pins `LOCAL_PROMO_KENDU=true`.
That is the *only* reason there is no live loss of coverage. The two defects therefore interlock:

- **Fixing F-01 alone ARMS F-02.** Unpin the env var without ungating the seed, and the very first
  `LOCAL_PROMO_KENDU=false` run — the dormant, day-one-mainnet rehearsal that F-01's whole purpose
  is to make reachable — becomes a rehearsal that quietly omits its own safety guard, with no error
  and no log line saying the probe was skipped.
- **F-01 and F-02 must be fixed together, F-02 first or simultaneously.** Ungate the seed (or hoist
  the probe out of it) *before or in the same change as* unpinning the `dev` key. Never the reverse
  order.

Low severity: local-only, no current loss of coverage. But it is a real Law-2 deviation with a
demonstrable safety consequence, and it landed on commits carrying no story tag at all.

### Recommendation (verbatim from the finding record)

> Either restore the seeding/probe as unconditional per story 079 (registering and seeding the
> phUSD/Kendu streams costs nothing on the dormant leg beyond two extra streams the UI is supposed
> to render gracefully anyway), or — if the dormant leg must genuinely leave them unregistered to
> mirror mainnet — hoist the fee-on-transfer probe out of `_seedNudgeStream` into an unconditional
> check that runs on both legs, and amend story 079 (or file a superseding story) rather than
> silently contradicting it.

---


---

## Law-1 override check

**No story graded in this run has an intended behaviour that would introduce an exploit.** Law 1 does
not override Law 2 anywhere here.

- **story-080** rehearses a V1→V2 cutover on a **local anvil, chain 31337 only**. Its most
  safety-relevant instruction — revoke V1's phUSD mint grant — ships in the **correct order** (after
  the drain assert), which is the ordering that avoids bricking the migration. Its relaxations are
  narrow and were verified: the USDe `maxLossBps = 100` band is the only one, DOLA and USDC are exact
  + 2 wei.
- **story-081** is purely defensive — it *adds* a freshness gate. Verified by execution to close the
  run-28 stale-anvil race, including the fork case (anvil preserves the forked deployer nonce, so
  forcing chainid 31337 does not disguise a fork).

Two Law-3 checks were applied and both passed the *surprise test*, so neither new finding is an
owner-misuse claim: a competent, non-malicious developer **would** be surprised that the documented
"~10 Antimatter" assertion is not the one that fires (`F-03`), and **would** be surprised that the
`tsc` guard the story names as the only drift guard cannot run at all (`F-04`).

## Remediation ordering

1. **`F-04` before `F-03`.** `F-04` is the one with a live drift surface — `dev` regenerates the
   interface on every run, and the two files already disagree by three keys. `F-03` is documentation
   and can follow at leisure.
2. **`F-03`'s two surfaces must be fixed together** (`verify-stable-staker.sh:6-10` **and**
   `package.json:36`). Fixing one leaves the other as the misleading one a developer reads first.
3. **`F-01` and `F-02` must be fixed together**, per the audit-28 ordering hazard retained above.
4. Record `F-03`'s fix as a story-080 Autonomous Decision, so the checklist tick and the shipped code
   agree — that is the deviation, more than the strings themselves.

---

## ⚠ Audit-30 escalation on `F-04` (`ee5aae66ac651277…` / `pps29f4`) — appended 2026-09-11

**Recorded by:** `finding-manager`, run `phoenix-phase-2-staging-30` (commit `e6eded0`, baseline
`9563c68`, branch `master`, entry point `dev`).

`F-04` was **re-observed live** at `e6eded0`. It reconciles onto the **existing** ledger entry
`ee5aae66ac651277953db1b477d4ba66939701ec5aa7ffe013c2b26b9865e678` as **still-open** — **one entry,
not two.** `lastSeenRun` was bumped to `phoenix-phase-2-staging-30`; the status remains **`open`**
and was not otherwise touched, and **no second entry was minted.**

The re-observation carries **materially new evidence that `F-04` did not have when it was filed at
run 29**. A plain copy-forward of the run-29 report would have buried it, so it is stated here:

1. **The unenforceable drift guard has now been used as the AFFIRMATIVE JUSTIFICATION for deleting
   a live mainnet contract's only published resolution path.** At run 29 the guard was a declared
   rule that did not exist and was not enforced. At run 30 it has become **load-bearing for an
   irreversible edit** — a rule that cannot be checked was cited as the reason a real key could be
   removed.

2. **The rule is not merely unenforced — it is UNEVENLY APPLIED.** The three Burner keys
   (`BurnerEYE`, `BurnerSCX`, `BurnerFlax`, at `:108-110`) have been retained since story 070 for
   *exactly* the historical-reference reason for which the PhlimboEA key was denied. The same guard
   admits three keys and excludes a fourth, with no stated distinction.

**Consequence.** This escalation may justify a **severity re-weigh on re-triage**. It does **not**
justify a second ledger entry, and none was created.

**Still binding:** `F-04`'s inherited **DO-NOT-COLLAPSE** against `pps29f3` / `c476a12b04fa…`.
Audit 30 respected it; the two entries were not merged.

**Related, filed separately this run:** audit-30 `L-03` (`85754b285c30ad49…` / `pps30l3`,
`UnverifiedMainnetClaimAsDeletionRationale`) touches the same file and the same deletion but is a
**different root cause with a non-overlapping fix** — "the factual assertion used as rationale is
false against the chain" vs "the RULE invoked as rationale is unenforceable and unevenly applied".
Deliberately not collapsed.
