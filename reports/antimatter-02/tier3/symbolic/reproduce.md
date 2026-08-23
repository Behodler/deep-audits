# Symbolic verification — antimatter @ c91bc1a (Halmos)

Workspace: `/home/justin/code/audits/workspace/antimatter` (HEAD = `c91bc1a`).
Never run any of this against `lib/antimatter`.

## Toolchain (exact)

| | |
|---|---|
| halmos | 0.3.3 (`~/.local/bin/halmos`) |
| default solver | yices 2.6.x (halmos default; not overridden) |
| forge | 1.5.1-stable (b0a9dd9) |
| solc | 0.8.27 |
| solver threads | 2 (WSL2 parallelism cap) |

## Harness files (audit-authored, run-02 port)

- `test/audit/symbolic/SymMocks.sol` — `SymERC20`, `SymFlax`, `SymYieldStrategy`, and the new
  `RawDecimalsToken` whose `decimals()` returns caller-chosen RAW bytes (any length) or reverts.
- `test/audit/symbolic/Sym1_ThirdPartyPower.t.sol` — SYM-1 (ledger H-01, `033432b0e6`).
- `test/audit/symbolic/Sym2_Decimals.t.sol` — SYM-2 shape/crosscheck cases (ledger M-01, `a1c81428a4`).
- `test/audit/symbolic/Sym2_ConcreteD.t.sol` — SYM-2 with `d` pinned to each of 0..18.

The run-01 harness (`test/audit/audit-tests-stashed/**`) was bit-rotted twice (wrong relative
import depth, plus calls to the removed 4-arg `annihilateFrom`). It was NOT repaired; the two
properties were re-authored against the current 3-arg
`annihilate(address stable, address recipient, uint256 amount)`.

## Two build gotchas (both load-bearing)

1. **Halmos needs `ast` in the artifacts.** A plain `forge build` overwrites the artifacts
   without the AST and halmos then reports
   `Skipped <C>.json due to parsing failure: KeyError: 'ast'` followed by `No tests with
   --match-contract ...`. Always `forge build --ast` before/between halmos runs.
2. **`test/audit/audit-tests-stashed/` must be moved aside** for the duration (halmos shells out
   to `forge build`, which has no `--skip` passthrough). It is moved back at the end of the run.

## Commands actually run

```bash
cd /home/justin/code/audits/workspace/antimatter
mv test/audit/audit-tests-stashed <scratch>/audit-tests-stashed
forge build --ast --force

# SYM-2, concrete d = 0..18 (19 tests)         -> halmos-sym2-concreteD.txt
halmos --contract Sym2ConcreteD --solver-timeout-assertion 120000 --solver-threads 2 --statistics

# SYM-2, non-vacuity + mutation controls        -> halmos-sym2-tripwires.txt / halmos-sym2-mutation.txt
halmos --contract Sym2ConcreteD --function check_sym2_tripwire --solver-timeout-assertion 120000 --solver-threads 2 --statistics
halmos --contract Sym2ConcreteD --function check_sym2_mutation  --solver-timeout-assertion 120000 --solver-threads 2 --statistics

# SYM-2, adversarial returndata shapes + symbolic-d crosscheck -> halmos-sym2-shapes.txt
halmos --contract Sym2Decimals --solver-timeout-assertion 120000 --solver-threads 2 --statistics

# SYM-1, owner-gated surface + ERC20 surface + tripwires -> halmos-sym1-partA.txt
halmos --contract Sym1ThirdPartyPower \
  --function 'check_sym1_bCannot|check_sym1_transfer|check_sym1_tripwire' \
  --solver-timeout-assertion 120000 --solver-threads 2 --statistics

# SYM-1, annihilate on the registered stablecoin -> halmos-sym1-annihilate-registered.txt
halmos --contract Sym1ThirdPartyPower --function 'check_sym1_annihilate_registered' \
  --solver-timeout-assertion 300000 --solver-threads 2 --statistics

# SYM-1, annihilate with a symbolic `stable` address -> halmos-sym1-annihilate-symstable.txt
halmos --contract Sym1ThirdPartyPower --function 'check_sym1_annihilate$' \
  --solver-timeout-assertion 300000 --solver-threads 2 --statistics

# SYM-1, umbrella: arbitrary symbolic calldata over the whole ABI -> halmos-sym1-umbrella.txt
halmos --contract Sym1ThirdPartyPower --function 'check_sym1_arbitraryCallByB' \
  --solver-timeout-assertion 300000 --solver-threads 2 --statistics

mv <scratch>/audit-tests-stashed test/audit/audit-tests-stashed
```

## Halmos limitation discovered in this run (affects how every result must be read)

`check_sym2_probe_symbolicExpIsConcrete` is **REFUTED**, with a counterexample halmos itself
labels *"Counterexample (potentially invalid)"*. Halmos 0.3.3 over-approximates `EXP` with a
**symbolic exponent** as an uninterpreted term: it cannot prove `1 <= 10**(18-d) <= 1e18` for
`d <= 18`. `--smt-exp-by-const 19` does not change this (`halmos-sym2-shapes.txt`, and the
probe re-run under that flag).

Consequences, stated precisely:

- Over-approximation is **sound in the PASS direction** (the solver considers a superset of real
  behaviours), so a symbolic-`d` PASS is still a valid proof — but only of the *relational* form
  of a property, since the scale VALUE is unconstrained.
- Any claim about the *numeric* scale therefore needs `d` concrete. That is why
  `Sym2_ConcreteD.t.sol` enumerates `d = 0..18` (the entire reachable domain: `d > 18` is proven
  unreachable separately by `check_sym2_registeredAbove18_unreachable`).
- A symbolic-`d` **FAIL** may be spurious and is never treated as a counterexample here.

## Why `assert(false)` was abandoned for unreachability claims

A bare `target.f(); assert(false);` yields halmos `[ERROR] ... all paths have been reverted`,
which is ambiguous: it looks identical whether the property holds or the harness broke before
reaching the target. Every unreachability claim here instead uses a `try/catch` (SYM-2) or a
low-level `call` (SYM-1) and asserts the **exact revert selector**, so the test itself has a live
non-reverting path and a `[PASS]` is unambiguous.

## Solver of record: z3, NOT the halmos default

The halmos default solver (**yices**) TIMED OUT at 300s on two SYM-1 properties
(`halmos-sym1-annihilate-registered.txt`, `halmos-sym1-annihilate-split.txt`). **z3 discharges
both in 10-25 seconds.** Every headline verdict in `symbolic-results.json` is taken from a
`--solver z3` run. The yices timeout artifacts are retained and listed under `supersededRuns`;
they are INCONCLUSIVE and carry no safety weight on their own.

```bash
halmos --contract Sym1ThirdPartyPower --solver z3 --solver-timeout-assertion 600000 \
  --solver-threads 2 --statistics          # -> halmos-sym1-FULL-z3.txt
halmos --contract Sym2Decimals   --solver z3 --solver-timeout-assertion 600000 \
  --solver-threads 2 --statistics          # -> halmos-sym2-shapes-z3.txt
halmos --contract Sym2ConcreteD  --solver z3 --solver-timeout-assertion 600000 \
  --solver-threads 2 --statistics          # -> halmos-sym2-concreteD-z3.txt
```

## SYM-1 frame — exactly what was symbolic, concrete, and excluded

**Contracts under test are the REAL ones**: `src/Antimatter.sol` and the real
`lib/phUSD-stable-minter/src/PhusdStableMinter.sol`.

**Symbolic (unbounded uint256 / address unless noted):**
- A's and B's antimatter balances; A's and B's stablecoin balances.
- The antimatter allowance A grants B (the H-01 precondition).
- The `stable`, `recipient` and `amount` arguments of `annihilate`.
- In `check_sym1_arbitraryCallByB`, the ENTIRE calldata, generated from the Antimatter ABI by
  `svm.createCalldata("Antimatter")` — covering `annihilate`, `mint`, `rescueERC20`, `setPhUSD`,
  `setPhUSDMinter`, `setApprovedMinter`, and the inherited ERC20 `transfer` / `transferFrom` /
  `approve`, plus all views.

**Concrete (fixed by the harness):**
- `msg.sender = B` on the call under test; `B != A`, `B != owner`, `B` not an approved minter.
- The registered stablecoin used by the `_registered` tests: decimals **6**, exchange rate
  **1e18**, `maxMintPerDay` **0** (cap disabled), `enabled` true, minter not paused.
  (`check_sym1_annihilate` leaves the `stable` argument fully symbolic instead.)
- phUSD and the yield strategy are the minimal mocks in `SymMocks.sol`.
- The approved-minter set is **non-empty** (address `0x4444` is a genuine approved minter, B is
  not), so the `onlyApprovedMinters` membership test is exercised against real membership.

**Loop / array bounds imposed:** none were needed. Antimatter's external ABI takes no dynamic
arrays or `bytes`, so `createCalldata` needed no array-length bound, and no test unrolls a loop.
The `EnumerableSet` is exercised only through `contains`.

**Explicitly OUTSIDE the frame (NOT proven):**
- **Exactly ONE call by B is executed.** This is a single-transaction property; multi-call
  sequences are covered by the Tier-3 stateful campaign, not here.
- **Re-entrancy.** The mocks do not re-enter Antimatter, so a hostile stablecoin re-entering
  through `safeTransferFrom` is not covered by these proofs. (`ReentrancyGuard` is present and
  was exercised by the Tier-2/Tier-3 harnesses.)
- `maxMintPerDay > 0` (live daily cap) was not exercised here.

## SYM-2 frame — exactly what was symbolic, and the enumerated bounds

**Symbolic and UNBOUNDED:** `amount` (full uint256), and the 32-byte word the token's
`decimals()` returns (full uint256 — so answers above 255 and answers differing from the
registration are inside the domain).

**Enumerated rather than symbolic, and why:**
1. **Registered decimals `d`: enumerated concretely over 0..18** in `Sym2_ConcreteD.t.sol`.
   *Reason:* halmos over-approximates `10 ** (18 - d)` when `d` is symbolic (see the probe
   above). *What this excludes:* nothing reachable — `d > 18` reverts `UnsupportedDecimals`
   before the exponent is ever evaluated, and that is proven separately and symbolically by
   `check_sym2_registeredAbove18_unreachable` (which reaches no EXP). So 0..18 is the complete
   reachable domain, not a convenience cut.
2. **`decimals()` returndata LENGTH: enumerated over {revert, 0, 31, 32, 33, 64}.**
   *Reason:* a symbolic-length `bytes` return is not expressible in the mock.
   *What this excludes:* lengths other than 0/31/33/64 in the "not 32" class were not
   individually executed. The guard under test is `data.length != 32`, a single comparison with
   no length-dependent arithmetic, and 32 (the only accepting length) IS covered exhaustively
   with a fully symbolic word — so the residual risk here is low, but it is an enumeration and
   is labelled as one rather than claimed as a proof over all lengths.

**Concrete:** exchange rate 1e18; the `PhusdStableMinter` is the real contract; phUSD and the
yield strategy are mocks (never called on the `toStableAmount` path).

## Verdicts

| property | verdict | domain |
|---|---|---|
| **SYM-1** NO-THIRD-PARTY-POWER (H-01, `033432b0e6`) | **PROVEN** | unbounded, single call, frame above |
| **SYM-2** DECIMALS-CROSSCHECK (M-01, `a1c81428a4`) | **PROVEN** | `amount` and answer word unbounded; `d` enumerated 0..18 (complete reachable domain); returndata length enumerated |

Non-vacuity: 10 controls, all REFUTED as required, including a **mutation control**
(`check_sym2_mutation_d06_expectFail`) that asserts the negation of the SYM-2 crosscheck and
fails, proving the assertion is load-bearing. One control
(`check_sym1_tripwire_umbrellaReachesBurn`) produced a witness halmos flagged
*"potentially invalid"* — the umbrella's coverage of the burn path is therefore corroborated but
not cleanly witnessed; the burn path's reachability is established cleanly instead by
`check_sym1_tripwire_bSelfAnnihilateReachable`, and the annihilate property is proven directly
by `check_sym1_annihilate_registered`.
