# How to reproduce this run's empirical results

Workspace: `/home/justin/code/audits/workspace/phoenix-phase-2-staging` @ `e1db0f1`. Never run from `lib/`.

1. **Full chain** (~15 min; ends in a long-lived `serve`, so background it):
   `npm run dev  > npm-run-dev.log 2>&1 &`
   Watch `~/.foundry/anvil/tmp/` concurrently to test closure hazard EH-01.
   Result here: completed end-to-end, 865 blocks, 381 broadcast txs, 70 creations, 0 reverts.

2. **M-01 incomplete-fix check** — copy `audit-archive/prior-run-tests/AuditDevNudgeStreamerFoT.t.sol`
   into `test/` and run `forge test --match-path ... -vv`. NO fork needed: the PoC deploys its own
   NudgeStreamer/FeeToken/MinterStubs. The tests ASSERT THE BUG EXISTS, so FAIL == fixed.
   `test_FIND1_D_probeIsVacuousOnNoFeeToken` is the non-vacuity control and must PASS.

3. **Live-state assertions** — `AuditRun26DevLiveState.t.sol` (below) must be run WITH
   `--fork-url http://127.0.0.1:8545` against the live anvil from step 1.
   WARNING: `audit-archive/prior-run-tests/AuditDevStreamerWiring.t.sol` hardcodes run-21 addresses and
   MUST be forked. Run un-forked it produces FALSE POSITIVES — a `.call()` to a code-less address
   returns `ok == true`, which reads as "the donor accepted address(0)". Do not trust an un-forked run.

4. **tsc lockstep** — TypeScript is not vendored in the repo. Install it in a scratch dir, copy
   `server/deployments/{addresses,mainnet-addresses,local-addresses}.ts` there, and run
   `tsc --noEmit --strict --skipLibCheck mainnet-addresses.ts local-addresses.ts`. Exit 0 here.

5. **Stale-TS demo** — with a completed deployment present, sha256 the four artifacts, run
   `npm run clean:local`, sha256 again, and hit `/health` + `/contracts`.
