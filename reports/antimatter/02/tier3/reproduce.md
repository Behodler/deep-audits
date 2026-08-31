# Tier-3 reproduction — antimatter @ c91bc1a

Workspace: `/home/justin/code/audits/workspace/antimatter` (HEAD = `c91bc1a`, "more precise mint requirement").
Never run any of this against `lib/antimatter`.

## Harness files (audit-authored; NOT part of the project's own suite)

- `test/audit/invariant/AntimatterHandler.sol`   — actors, seeded state, ghosts, per-call property checks
- `test/audit/invariant/AuditMocks.sol`          — `GuardedYieldStrategy` (reverts on unauthorised/short/zero deposit)
- `test/audit/invariant/AntimatterInvariant.t.sol` — Foundry invariant contracts + deterministic checks
- `test/audit/invariant/MedusaTarget.sol`        — `MedusaAntimatterTarget`, assertion-mode wrapper

## The `--skip` flag is load-bearing

`test/audit/audit-tests-stashed/**` (the run-01 harness, relocated one directory deeper by another
agent) does not compile: its relative imports `../../../src/Antimatter.sol` now resolve to
`test/src/Antimatter.sol`. Every command below skips it. Without the skip, `forge build` fails
before reaching anything in this directory.

## Commands actually run

```bash
cd /home/justin/code/audits/workspace/antimatter

# 1. build
forge build --skip '*audit-tests-stashed*'

# 2. deterministic checks (H-01, M-01, INV3, INV5, coverage walk, tripwire negative control)
forge test --skip '*audit-tests-stashed*' \
  --match-contract AntimatterInvariantTest --match-test 'test_' -vv

# 3. core stateful campaign  -> forge-core-invariants.txt
FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=128 FOUNDRY_INVARIANT_FAIL_ON_REVERT=false \
  forge test --skip '*audit-tests-stashed*' --match-contract 'AntimatterInvariantTest' -vv

# 4. daily-cap campaign (live maxMintPerDay) -> forge-dailycap-invariants.txt
FOUNDRY_INVARIANT_RUNS=128 FOUNDRY_INVARIANT_DEPTH=96 \
  forge test --skip '*audit-tests-stashed*' --match-contract 'AntimatterDailyCapInvariantTest' -vv

# 5. Medusa (workers=3 for WSL2)  -> medusa-run.txt
#    crytic-compile runs `forge build` over the whole tree, so the stashed dir must be moved aside
#    for the duration of the run and moved back afterwards:
mv test/audit/audit-tests-stashed /tmp/.../scratchpad/audit-tests-stashed
medusa fuzz --config medusa.json
mv /tmp/.../scratchpad/audit-tests-stashed test/audit/audit-tests-stashed
```

Echidna is NOT installed on this machine (`which echidna` -> not found). Medusa 1.5.1 was used as
the primary stateful fuzzer, so the fallback was never needed.

## Artifacts

| file | what |
|---|---|
| `forge-core-invariants.txt`   | full core campaign output, 256 runs x 128 depth (32,768 calls per invariant) |
| `forge-dailycap-invariants.txt` | live-cap campaign, incl. the two shrunk counterexamples |
| `medusa-run.txt`              | Medusa console log, 65,013 calls, 16/16 assertion tests passed |
| `medusa.json`                 | the exact config used (workers=3, testLimit=60000, callSequenceLength=60) |
| `medusa-lcov-Antimatter.info` | per-line hit counts for `src/Antimatter.sol` from the Medusa run |
| `medusa-test_results/`        | Medusa's own result records |
| `invariants.json`             | invariant definitions |
| `invariant-results.json`      | per-invariant verdicts |

## Anti-vacuousness evidence (read this before trusting any PASS)

`medusa-lcov-Antimatter.info` records hit counts on the settlement lines of `annihilate`:

```
DA:239,9316   _burn(msg.sender, amount)
DA:251,9062   minter.mint(stable, stableAmount)
DA:257,9062   the mintedForStable != expectedForStable check
DA:260,6607   _phUSD.mint(recipient, amount)          <-- full settlement reached 6,607 times
DA:261,6607   safeTransfer(recipient, mintedForStable)
DA:263,6607   emit Annihilated
```

Foundry side: `test_ZZ_coverageWalk` (600 deterministic actions, seed 42) reports
137 settled annihilations, 52 understated-decimals attempts, 53 hostile-donor attempts,
14 antimatter `transferFrom`s, 50 non-owner rescue attempts, 0 violations.

`test_ZZ_tripwireIsFalsifiable` is the negative control: with the actors' stablecoin approvals
revoked, `attemptedAnnihilate() > 0` but `okAnnihilate() == 0`, i.e. the tripwire genuinely can
fail and is not itself vacuous.
