# Tier-3 Invariant Results — UniboostMintDebtHook backing-solvency

- Project: `yield-claim-nft` @ `aa86be6` ([story-041] UniboostMintDebtHook)
- In scope: `src/dispatchers/Uniboost.sol`, `src/hooks/UniboostMintDebtHook.sol`
- Focus: CONFIRM the no-overmint / over-backing safety claimed by Tier-2 econ-scanner (no H/M found).
- Runners: forge invariant runner (PASS) + Medusa 1.5.1 (PASS). Echidna not installed (skipped).
- Outcome: ALL invariants PASS. No counterexample. Over-backing (>=2:1) and decimal no-overmint CONFIRMED.

## Artifacts

- Forge invariant suite: `workspace/yield-claim-nft/test/InvariantUniboost.t.sol` (handler-based, decimals 6/8/18 simultaneously)
- Medusa target: `workspace/yield-claim-nft/test/MedusaUniboost.sol` (self-contained, 6dp / scale=1e12 worst case)
- Medusa config: `workspace/yield-claim-nft/medusa.json` (targetContracts = `MedusaUniboostTarget`)

## Commands & seed (reproducible)

Forge (fail-on-revert, fixed seed):
```
cd workspace/yield-claim-nft
FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=64 FOUNDRY_INVARIANT_FAIL_ON_REVERT=true \
  forge test --match-contract InvariantUniboost --fuzz-seed 0xA11CE -vv
```
Medusa:
```
cd workspace/yield-claim-nft
medusa fuzz --config medusa.json
```

Workaround for the stale test file: `test/recheck-M04-hookguard-fixed.t.sol` (references deleted
`src/V2/` layout, breaks the test-dir build) was moved out of `test/` into the scratchpad before
running. It is a workspace artifact; `src/` was not touched.

## Invariants & results

| # | Invariant | Property | Forge | Medusa |
|---|-----------|----------|-------|--------|
| 1 | `invariant_backingOverCollateralized` | `2 * (outstandingDebt + realisedMint) <= grossPrimeScaled` — phUSD debt never exceeds 50% of gross 18dp-scaled prime dispatched (the >=2:1 buffer) | PASS | PASS |
| 2 | `invariant_debtMatchesGhostExpectation` / `invariant_debtMatchesGhost` | `mintDebt == ghost` where ghost re-derives `sum floor(amount*scale*ratio/100)` independently; realised mint matches too — no over-mint, dust floors to protocol | PASS | PASS |
| 3 | `invariant_ratioWithinBound` | live `ratio <= MAX_RATIO (50)` always; `setRatio(>50)` reverts `RatioTooHigh` | PASS | PASS |
| 4 | `invariant_noDebtResurrection` | minted phUSD == ghost realised; `pull()` mints exactly the outstanding debt and zeroes it; no double-pull / resurrection | PASS | PASS |

Forge: `runs: 256, calls: 16384, reverts: 0` per invariant, across three hooks (6/8/18 dp) at once,
with `fail_on_revert=true` (every fuzzed dispatch/setRatio/pull was a valid in-scope sequence —
zero spurious reverts). Medusa: 56,011 calls, 8 workers, 877 branches, 17 tests passed / 0 failed
(the `0/579` are the deliberately-asserted out-of-bound `setRatio` reverts, not invariant failures).

## Mechanism notes (why it holds)

- `onDispatch`: `added = (amount * scale * ratio) / 100`, `scale = 10**(18-decimals)`, `ratio <= 50`.
  Multiply-then-divide floors → accrued debt for any dispatch is `<= floor(gross_18dp / 2)`, so
  summed debt is always `<= gross/2`. Rounding dust accrues to the protocol, never to the recipient
  (under-mint direction only). Constructor enforces `decimals <= 18` (`scale >= 1`), so scaling can
  only fill missing low-order digits — it cannot inflate value.
- `pull`: caches `debt`, zeroes `mintDebt` BEFORE minting, `nonReentrant` — exact-once realisation;
  re-entry / double-pull cannot mint twice (verified by the unit suite's reentrancy test too).

## Observation (not a finding — already in the unit suite & NatSpec)

`setRatio` uses `if (newRatio > MAX_RATIO) revert` with `MAX_RATIO == 50`, so `ratio == 50` is
settable. The NatSpec says "strictly `< MAX_RATIO`" / "max settable is `MAX_RATIO - 1`", which
reads as an exclusive bound, but the code (and the unit test `test_setRatio_50Succeeds_andEmits`)
treat 50 as inclusive. This is a doc/code wording mismatch, not a safety issue: 50% is exactly the
documented `DEFAULT_RATIO` and the design's intended ceiling, and the >=2:1 backing invariant holds
with equality at ratio=50 (debt == gross/2, backing == 2x). No over-backing violation. QA-tier
nit at most; surfaced here for transparency, not escalation.

## Conclusion

The Tier-2 econ-scanner claim is CONFIRMED by both stateful fuzzers: UniboostMintDebtHook's phUSD
mint-debt is always conservatively (>=2:1) backed by dispatched prime, the prime-decimals scaling
never over-mints (floors dust to the protocol across 6/8/18 dp and fuzzed amounts up to 1e30),
the ratio bound holds at all times, and `pull()` realises debt exactly once. No High/Medium.
