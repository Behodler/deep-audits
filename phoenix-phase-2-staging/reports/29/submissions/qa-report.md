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
