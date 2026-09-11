# Intent — `dev` (phoenix-phase-2-staging, run-29, @9563c68)

Entry point: `npm run dev` -> `./dev-local.sh`.
Target: a **locally-spawned anvil**, chainId 31337, no `--fork-url`. Not a mainnet fork; `forkAvailable=false`
is correct and is **not** degraded mode. Every claim below was verified by actually running the stack in
`<project>/work/`.

## Stated purpose
package.json has no `//dev` doc key; `dev` sits under `//serve-and-dev` ("Story 003 — API server + local dev
orchestration"). Authoritative intent is story-080 + story-081 (both `auto-complete`, self-reported verification).

- [x] Stand up a **fresh, exclusively-owned** local anvil and refuse to run next to a foreign/leftover node (story-081)
- [x] Deploy the whole Phase-2 mock stack from source (DeployMocks.s.sol, 3050 lines)
- [x] **story-080**: deploy Antimatter + StableStakerV2 (Phase 6.5a) and **rehearse the V1->V2 cutover** (Phase 6.5b)
- [x] Simulate yield, extract addresses, regenerate the TS address surface
- [x] Serve the local API, and tear the anvil down when the developer Ctrl-Cs out of it (story-081)

## Declared pre-conditions
Shell (`dev-local.sh`):
- P1 `cast block-number` on :8545 must FAIL — port must be free (48-55, HARD)
- P2 anvil pid alive + answering within 30s (73-91, HARD)
- P3 listener pid on :8545 == the anvil we started (99-116, **SOFT** — warn-only if neither `ss` nor `lsof`)
- P4 `cast block-number` <= 100 (118-128, HARD)

Solidity (`script/DeployMocks.s.sol:run()`):
- P5 `require(block.chainid == 31337, "DeployMocks: local only")` (:443, run-28 L-02)
- P6 `require(vm.getNonce(deployer) == 0, "DeployMocks: chain is not fresh - a prior deployment is already on 8545; kill it and re-run")` (:445-446, **the run-28 M-01 remediation**)
- P7 `vm.envUint("ANVIL_PRIVATE_KEY")` (:419) — undeclared ambient dependency, set nowhere in the repo

## Declared post-conditions
Phase 6.5a: `STAKER_VERSION()==2`; `antimatter.isApprovedMinter(V2)` by **read-back** (setter is a silent no-op);
`stableStakerV2.phUSDMintAvailable()`; `autoAnnihilateAvailable(token)` per pool; `!claimEnabled`.
Phase 6.5b: seeded principal > 0 per actor; `stakerCount(token)==SS_CUTOVER_ACTORS` after seeding; migrator wired
both sides + `versionOf` probes; strict progress per batch; `batches > 1`; then `_assertStableStakerCutover`:
`v1.stakerCount==0`, `v1.totalStaked==0`, per-actor `post>0`, `post<=pre`, `pre-post <= pre*maxLossBps/10000 + 2`
(maxLossBps 0 for DOLA/USDC, 100 for USDe), `V2 totalStaked == sum(post)`.
Terminal: `_sweepResidualPrivileges` / `_requireLiveMinter` table — StableStakerV1 **false**, StableStakerV2 **true**.

## Cleanup contract
`trap cleanup EXIT INT TERM` (35-46) kills the anvil this script started.

## Verified end state (empirical, this run)
Every one of the above held on a clean machine. See `side-effects.json`.
