# Tier-3 Symbolic Analysis — `antimatter` (Halmos)

**Target:** `src/Antimatter.sol` — `annihilateFrom`, `toStableAmount`
**Harness:** `/home/justin/code/audits/workspace/antimatter/test/audit/symbolic/AntimatterSymbolic.t.sol`
(+ `SymMocks.sol` in the same directory)
**Raw solver output:** every run below is saved verbatim under
`/home/justin/code/audits/reports/antimatter/01/tier3/halmos-*.txt`

## Provenance

```
utc:                 2026-08-18T13:34:14Z
halmos:              halmos 0.3.3
forge:               forge Version: 1.5.1-stable
solc:                0.8.27 (foundry.toml)
workspace HEAD:      0bb82d867dba43bc514a508800826f90436c2ee3
lib/antimatter HEAD: 0bb82d867dba43bc514a508800826f90436c2ee3
```

## Reading these results

Halmos outcomes are **not** interchangeable and are never collapsed into "passed":

| Outcome | Meaning |
| --- | --- |
| `[PASS]` | Machine-checked proof over the stated domain. The only outcome that carries safety weight. |
| `[FAIL]` + Counterexample | Genuine refutation with concrete witness values. |
| `[TIMEOUT]` | **Proves nothing.** The solver could not decide. Not evidence of safety. |
| `[ERROR]` | The property was never tested. Not evidence of safety. |

Halmos **discards reverting paths**. An assertion placed after a call therefore proves the
property only over the paths on which that call *succeeds*, and a harness in which the call
always reverts would pass every property vacuously. Three `assert(false)` **tripwires** are
included for exactly this reason — each is REFUTED with a concrete witness, which is the
positive evidence that the success paths are genuinely reachable (see § Non-vacuity).

---

## Summary

| # | Property | Outcome | Domain |
| --- | --- | --- | --- |
| 1 | `toStableAmount` exactness (`s * 10**(18-d) == amount`), d = 6 | **PROVED** | unbounded `amount` |
| 1 | `toStableAmount` exactness, symbolic `d <= 18` | **PROVED** | unbounded `amount`, scale-generic (see caveat) |
| 1b | `toStableAmount` succeeds **iff** amount is exactly representable | **TIMEOUT** | unbounded and `amount < 2**128` both timed out |
| 2 | `annihilateFrom` leaves zero stablecoin **and** zero phUSD on the contract | **PROVED** | **unbounded** `amount`, **symbolic** `rate`, `amount % 1e12 == 0`, d = 6 |
| 3a | Caller's antimatter allowance over `from` falls by **exactly** `amount` | **PROVED** | `0 < amount < 2**96`, `amount <= grant < 2**200`, d = 6 |
| 3b | Caller with **no** stablecoin allowance cannot spend `from`'s stablecoin | **REFUTED (counterexample)** | — confirms CODE-001 |
| 4 | Minter's evaluation order `(s*rate*scale)/1e18` == intended `floor(amount*rate/1e18)` | **PROVED** | all `amount`, all `rate`, all `d <= 18`, on paths where both are computable |
| 4 | Overflow parity of those two evaluation orders | **TIMEOUT** | unbounded, `< 2**128`, and d-pinned variants all timed out |
| 4 | End-to-end phUSD delivered == `amount + stableHalf` | **TIMEOUT** | 6 configurations tried (see § Property 4) |
| 4 | Non-zero `amount` always yields a non-zero stable half | **REFUTED (counterexample)** | rounding-to-zero edge |

**Net:** 6 proof runs passed, 2 properties refuted with concrete witnesses, 3 timed out. The three
timeouts are **unverified**, not safe, and are listed in § Not covered.

---

## Property 1 — `toStableAmount` exactness

### 1a. PROVED — `d = 6` (USDC), unbounded amount

Command:

```
halmos --contract AntimatterSymbolic --function check_toStableAmount_exact_d6 \
       --solver-timeout-assertion 120000 --statistics
```

Verbatim tail (`halmos-p1-d6.txt`):

```
Running 1 tests for test/audit/symbolic/AntimatterSymbolic.t.sol:AntimatterSymbolic
setup: 0.07s (decode: 0.02s, run: 0.05s)
[PASS] check_toStableAmount_exact_d6(uint256) (paths: 3, time: 0.08s (paths: 0.08s, models: 0.00s), bounds: [])
Symbolic test result: 1 passed; 0 failed; time: 0.16s
```

For **every** `uint256 amount`, if `toStableAmount` returns `s` then `s * 1e12 == amount`
exactly. There is no silent truncation: the `stableAmount * scale != amount` guard at
`Antimatter.sol` in `toStableAmount` is sound.

### 1b. PROVED — symbolic decimals `d <= 18`, with an important caveat

Verbatim tail (`halmos-p1-symbolicd.txt`):

```
[PASS] check_toStableAmount_exact(uint256,uint8) (paths: 8, time: 0.24s (paths: 0.14s, models: 0.10s), bounds: [])
[PASS] check_toStableAmount_exact_d6(uint256) (paths: 3, time: 0.06s (paths: 0.06s, models: 0.00s), bounds: [])
```

**Caveat — Halmos does not concretize `10 ** (18 - d)` when `d` is symbolic.** A deliberate
harness probe establishes this rather than assuming it:

```
[FAIL] check_probe_symbolicExpIsConcrete(uint8) (paths: 5, ...)
WARNING  Counterexample (potentially invalid):
             p_d_uint8_fef84f0_00 = 0x00
```

(`halmos-probe-exp.txt`; re-run with `--smt-exp-by-const 18` gives the identical result,
`halmos-probe-exp-const18.txt` — that flag interprets a constant *exponent*, not a
constant base.) The probe asserts only `1 <= 10**(18-d) <= 1e18` and is refuted, so the
`EXP` term is over-approximated as an opaque 256-bit value.

**This does not weaken the PASS above — it strengthens it.** Over-approximation means the
property was proved for *every* value the scale term could take, a strict superset of the
19 true powers of ten. (The direction that *is* unsound under over-approximation is
counterexamples, which is why Halmos labels the probe's witness "potentially invalid";
no finding in this report rests on a counterexample from a symbolic-`d` path.)

### 1c. TIMEOUT — reverts-**iff**-inexact

The converse direction (every non-representable amount *must* revert, no spurious revert on
a representable one) could not be decided:

```
[TIMEOUT] check_toStableAmount_revertsIffInexact_d6(uint256) (paths: 6, time: 120.33s (paths: 0.11s, models: 120.21s), bounds: [])
```
```
[TIMEOUT] check_toStableAmount_revertsIffInexact_d6_b128(uint256) (paths: 6, time: 120.37s (paths: 0.15s, models: 120.22s), bounds: [])
```

(`halmos-p1-iff.txt`, `halmos-p1-iff-b128.txt`.) Bounding to `amount < 2**128` did not help —
the cost is the `amount % 1e12` / `amount / 1e12` pair over symbolic 256-bit operands, which is
bound-insensitive. **Unverified.** Note the forward direction (1a/1b) *is* proved, so what
remains unproven is only the absence of a spurious revert, not the absence of truncation.

---

## Property 2 — no residue on the contract

### PROVED — bounded form (d = 6, rate = 1e18)

Command:

```
halmos --contract AntimatterSymbolic --function check_annihilate_noResidue_d6 \
       --solver-timeout-assertion 180000 --statistics
```

Verbatim tail (`halmos-p2-noresidue.txt`):

```
Running 1 tests for test/audit/symbolic/AntimatterSymbolic.t.sol:AntimatterSymbolic
setup: 0.04s (decode: 0.00s, run: 0.04s)
[PASS] check_annihilate_noResidue_d6(uint256) (paths: 10, time: 0.32s (paths: 0.32s, models: 0.00s), bounds: [])
Symbolic test result: 1 passed; 0 failed; time: 0.37s
```

### PROVED — unbounded amount, symbolic exchange rate

The bound and the concrete rate both turned out to be unnecessary:

Command:

```
halmos --contract AntimatterSymbolic --function check_annihilate_noResidue_d6_unbounded \
       --solver-timeout-assertion 180000 --statistics
```

Verbatim tail (`halmos-p2-noresidue-unbounded.txt`):

```
Running 1 tests for test/audit/symbolic/AntimatterSymbolic.t.sol:AntimatterSymbolic
setup: 0.05s (decode: 0.01s, run: 0.05s)
[PASS] check_annihilate_noResidue_d6_unbounded(uint256,uint256) (paths: 9, time: 0.35s (paths: 0.35s, models: 0.00s), bounds: [])
Symbolic test result: 1 passed; 0 failed; time: 0.41s
```

For **every** `uint256 amount` that is exactly representable at 6 decimals and **every**
`uint256 exchangeRate`, after a successful `annihilateFrom` the contract holds zero
stablecoin, zero phUSD, **and** zero residual approval to the minter (`forceApprove(minter, 0)`
is effective). This is the full external-call path — Antimatter → `PhusdStableMinter.mint` →
`SymYieldStrategy.deposit` plus both ERC20s — not a stub of it. The measured-balance guard
`if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();`
is sound against the mocked token set.

Not covered by this proof: symbolic `d` (pinned to 6), and stablecoins that misbehave
(fee-on-transfer, rebasing, reentrant) — see § What was NOT covered.

## Property 3 — allowance soundness

### 3a. PROVED — the antimatter allowance falls by exactly `amount`

Verbatim tail (`halmos-p3a.txt`):

```
[PASS] check_allowance_spentExactly_d6(uint256,uint256) (paths: 10, time: 0.37s (paths: 0.37s, models: 0.00s), bounds: [])
[PASS] check_allowance_spentExactly_d6_k(uint256,uint256) (paths: 12, time: 0.39s (paths: 0.39s, models: 0.00s), bounds: [])
```

Domain: `0 < amount < 2**96`, `amount % 1e12 == 0`, `amount <= grant < 2**200`, `d = 6`,
`rate = 1e18`, `CALLER != FROM`. `_spendAllowance` debits exactly `amount` and no more.

### 3b. REFUTED — the stablecoin half needs no authority from the caller (CODE-001)

The property put to the solver is the *naive safety claim*: a caller holding **only** an
antimatter allowance over `from`, and **zero** allowance over `from`'s stablecoin, cannot
cause `from`'s stablecoin to move. Halmos refutes it:

Verbatim tail (`halmos-p3b.txt`):

```
Running 2 tests for test/audit/symbolic/AntimatterSymbolic.t.sol:AntimatterSymbolic
setup: 0.05s (decode: 0.01s, run: 0.04s)
Counterexample:
    p_amount_uint256_6e476fa_00 = 0xe8d4a5100000000000000000
[FAIL] check_callerCannotSpendStableWithoutStableAllowance_d6(uint256) (paths: 11, time: 1.42s (paths: 0.42s, models: 1.00s), bounds: [])
Counterexample:
    p_k_uint256_da9c84f_00 = 0x80000000000000000000
[FAIL] check_callerCannotSpendStableWithoutStableAllowance_d6_k(uint256) (paths: 10, time: 1.51s (paths: 0.40s, models: 1.10s), bounds: [])
Symbolic test result: 0 passed; 2 failed; time: 2.98s
```

Concrete witnesses:

| Variable | Hex | Decimal |
| --- | --- | --- |
| `amount` (direct form) | `0xe8d4a5100000000000000000` | `72057594037927936000000000000` (≈ 7.2e10 AM) |
| `k` (k-form; `amount = k * 1e12`) | `0x80000000000000000000` | `2**79` → `amount ≈ 6.04e17 AM` |

The counterexamples come from a fully **concrete** `d = 6` / `rate = 1e18` configuration, so
they are not affected by the symbolic-`EXP` over-approximation discussed under Property 1.

**What this demonstrates.** `annihilateFrom` derives *two* asset movements from *one* grant of
authority. The caller's antimatter allowance over `from` is checked and spent
(`_spendAllowance(from, msg.sender, amount)`), but the stablecoin leg is pulled by
`IERC20(stable).safeTransferFrom(from, address(this), stableAmount)` on the **contract's own**
standing approval from `from` — the caller's stablecoin allowance over `from` is never
consulted and is `0` in the counterexample. Anyone `from` grants an antimatter allowance to
thereby acquires the power to spend an equal, rescaled quantity of `from`'s stablecoin at a
time of the caller's choosing. This is the confirmed High **CODE-001**; the symbolic run
establishes it holds for the whole `amount` domain, not just a hand-picked value.

---

## Property 4 — conservation

### 4a. PROVED — the minter's evaluation order is equivalent to the intended formula

Verbatim tail (`halmos-p4-order.txt`):

```
[PASS] check_conservation_orderAgnostic(uint256,uint8,uint256) (paths: 12, time: 0.67s (paths: 0.06s, models: 0.60s), bounds: [])
```

For all `amount`, all `rate`, all `d <= 18`, given the representability constraint that
`toStableAmount` enforces: `PhusdStableMinter.calculateMintAmount`'s
`(s * rate * scale) / 1e18` equals the intended `floor(amount * rate / 1e18)`. The
rescale-then-multiply order introduces **no** precision loss relative to the intended
semantics. (Proved on the paths where both expressions are computable; the overflow question
is 4b.)

### 4b. TIMEOUT — overflow parity

Whether the two orders overflow on exactly the same inputs (i.e. whether the minter's order
introduces or hides a revert edge) could not be decided in any configuration:

```
[TIMEOUT] check_conservation_overflowParity(uint256,uint8,uint256)  (paths: 27, 120.38s)   halmos-p4-ovparity.txt
[TIMEOUT] check_conservation_overflowParity_d6(uint256,uint256)     (paths: 15, 120.28s)   halmos-p4-ovparity-d6.txt
[TIMEOUT] check_conservation_overflowParity_b128(uint256,uint8,uint256) (paths: 28, 120.44s) halmos-p4-ovparity-b128.txt
```

**Unverified.** By hand the two products are mathematically identical, so parity is expected —
but that is an argument, not a proof, and it is recorded here as unproven.

### 4c. TIMEOUT — end-to-end phUSD delivered

The end-to-end statement "`phUSD` delivered to the recipient == `amount + stableHalf`" timed
out in **every** configuration attempted. Each was a separate run with its own artifact:

| Variant | Config | Result |
| --- | --- | --- |
| `check_annihilate_conservation_d6` | d=6, rate=1e18, `amount < 2**96` | `[TIMEOUT]` 180.42s (`halmos-p4-e2e.txt`) |
| `check_annihilate_conservation_d6_k` | `amount = k*1e12`, `k < 2**80` | `[TIMEOUT]` 180.53s (`halmos-p4-e2e-k.txt`) |
| `check_annihilate_conservation_d6_k48` | `k < 2**48` | `[TIMEOUT]` 240.49s (`halmos-p4-e2e-k48.txt`) |
| `check_annihilate_conservation_d6_k32` | `k < 2**32` | `[TIMEOUT]` 240.44s (`halmos-p4-e2e-k32.txt`) |
| `check_annihilate_conservation_d6_k32` `--solver z3` | `k < 2**32` | `[TIMEOUT]` 254.39s (`halmos-p4-e2e-k32-z3.txt`) |
| `check_annihilate_conservation_d6_k32` `--solver cvc5-int` | `k < 2**32` | `[ERROR]` solver not installed, download disabled (`halmos-p4-e2e-k32-cvc5int.txt`) |
| `check_annihilate_conservation_d18` | d=18, rate=1e18, `amount < 2**96` | `[TIMEOUT]` 240.39s (`halmos-p4-e2e-d18.txt`) |
| `check_annihilate_conservation_vsMinterFormula_k` | symbolic rate, compared against `calculateMintAmount` | `[TIMEOUT]` 240.54s (`halmos-p4-e2e-vsformula.txt`) |

The obstruction is the division by `1e18` over a symbolic product inside the path condition;
it is **bound-insensitive** (tightening `k` from `2**80` to `2**32` changed nothing), so this
is not a case where a narrower domain buys a proof. `[TIMEOUT]` and `[ERROR]` here carry zero
safety weight: **end-to-end conservation is unverified.** What *is* proved is the arithmetic
core (4a) and the fact that nothing is left behind on the contract (Property 2).

### 4d. REFUTED — a non-zero annihilation can mint a zero stable half

Verbatim tail (`halmos-p4-nonzero.txt`):

```
Counterexample:
    p_amount_uint256_4c0e53a_00 = 0x746a52880000000
    p_rate_uint256_ce1c376_00 = 0x01
[FAIL] check_mintedForStable_alwaysNonZero_d6(uint256,uint256) (paths: 4, time: 1.04s (paths: 0.03s, models: 1.01s), bounds: [])
```

Witness: `amount = 524288000000000000` (0.524288e18, exactly representable at 6 decimals),
`exchangeRate = 1` wei. Then `floor(amount * rate / 1e18) == 0`, `mintedForStable == 0`, and
`annihilateFrom` reverts with `PhUSDNotReceived()` — **after** the stablecoin has already been
transferred in and deposited, so the whole call reverts and the annihilation is unavailable.
This is an availability edge at a mis-set (near-zero) exchange rate rather than a value leak:
nothing is lost, but the pair cannot be annihilated. Whether it merits a finding is a triage
call; it is recorded here because a fuzzer over "sensible" rates would not reach it.

---

## Non-vacuity

Because Halmos discards reverting paths, three tripwires assert `false` after an otherwise
identical successful flow. Each **must** be refuted; all three are:

`halmos-tripwires.txt`:

```
Counterexample:
    p_amount_uint256_1997d54_00 = 0xe8d4a5100000000000000000
[FAIL] check_tripwire_selfAnnihilateReachable(uint256) (paths: 9, time: 1.30s ...)
Counterexample:
    p_amount_uint256_0fec0f4_00 = 0xe8d4a5100000000000000000
[FAIL] check_tripwire_thirdPartyAnnihilateReachable(uint256) (paths: 9, time: 1.36s ...)
Symbolic test result: 0 passed; 2 failed; time: 2.72s
```

`halmos-tripwire-d18.txt`:

```
Counterexample:
    p_amount_uint256_f762eb1_00 = 0x800000000000000000000000
[FAIL] check_tripwire_d18Reachable(uint256) (paths: 8, time: 0.57s ...)
```

So the Property-2 and Property-3a PASSes are proofs over genuinely reachable success paths,
not vacuous truths over an all-reverting harness.

---

## What was NOT covered

Stated plainly, so no downstream report can read silence as coverage:

1. **End-to-end conservation (Property 4) is unproven.** Eight configurations, two solvers,
   bounds from `2**96` down to `2**32` — all `[TIMEOUT]`/`[ERROR]`. Not evidence of safety.
2. **`toStableAmount` reverts-iff-inexact (Property 1c) is unproven.** The forward exactness
   direction is proved; the absence of a spurious revert is not.
3. **Overflow parity (Property 4b) is unproven.**
4. **Every full-flow proof pins `d = 6` (or `d = 18`) and `rate = 1e18` concretely.** Symbolic
   decimals and a symbolic exchange rate were only carried through the *pure arithmetic*
   properties, never through `annihilateFrom`.
5. **Full-flow proofs are bounded** at `amount < 2**96` (or `k < 2**80`). A bounded proof is
   not a general one. The bound is far above any realistic supply but is stated as a bound.
6. **The external dependencies are audit-authored minimal mocks**, not the real FlaxToken or a
   real vault-RM yield strategy: `SymMocks.sol` supplies a compact ERC20, a phUSD stand-in with
   `mint`, and a yield strategy whose `deposit` pulls the token. The real
   `PhusdStableMinter` **is** used unmodified. Consequences: the phUSD token's own minter
   authorisation/version logic, the real strategy's accounting and revert surface, and any
   fee-on-transfer / rebasing / reentrant stablecoin behaviour are **out of the symbolic
   domain**. Antimatter's measured-balance guards (`StableNotDeposited`, `PhUSDNotReceived`)
   exist precisely for token misbehaviour, and this run does **not** exercise them against a
   misbehaving token — the Tier-2 unit/fuzz suites and the invariant harness cover that ground.
7. **The minter's 24h mint cap, pause flag, and `enabled` flag are left at their permissive
   defaults**, so the paths through `maxMintPerDay` / `paused` / disabled-stablecoin are not
   symbolically explored.
8. **Reentrancy is not a symbolic target here.** `nonReentrant` is present on `annihilateFrom`;
   the mocks make no re-entrant callback.

## Artifacts

```
/home/justin/code/audits/reports/antimatter/01/tier3/
  symbolic-results.md              (this file)
  provenance.txt
  halmos-p1-d6.txt                 [PASS]
  halmos-p1-symbolicd.txt          [PASS]
  halmos-p1-iff.txt                [TIMEOUT]
  halmos-p1-iff-b128.txt           [TIMEOUT]
  halmos-probe-exp.txt             [FAIL]  (harness probe: symbolic EXP is opaque)
  halmos-probe-exp-const18.txt     [FAIL]  (same, with --smt-exp-by-const 18)
  halmos-p2-noresidue.txt          [PASS]
  halmos-p2-noresidue-unbounded.txt [PASS] (unbounded amount, symbolic rate)
  halmos-p3a.txt                   [PASS] x2
  halmos-p3a-k.txt                 [PASS]
  halmos-p3b.txt                   [FAIL]  (CODE-001 counterexamples)
  halmos-p3b-k.txt                 [FAIL]  (CODE-001 counterexample)
  halmos-p4-order.txt              [PASS]
  halmos-p4-ovparity.txt           [TIMEOUT]
  halmos-p4-ovparity-d6.txt        [TIMEOUT]
  halmos-p4-ovparity-b128.txt      [TIMEOUT]
  halmos-p4-nonzero.txt            [FAIL]  (zero stable-half counterexample)
  halmos-p4-e2e.txt                [TIMEOUT]
  halmos-p4-e2e-k.txt              [TIMEOUT]
  halmos-p4-e2e-k48.txt            [TIMEOUT]
  halmos-p4-e2e-k32.txt            [TIMEOUT]
  halmos-p4-e2e-k32-z3.txt         [TIMEOUT]
  halmos-p4-e2e-k32-cvc5int.txt    [ERROR]
  halmos-p4-e2e-d18.txt            [TIMEOUT]
  halmos-p4-e2e-vsformula.txt      [TIMEOUT]
  halmos-tripwires.txt             [FAIL] x2 (required: proves non-vacuity)
  halmos-tripwire-d18.txt          [FAIL]    (required: proves non-vacuity)
  halmos-full-suite.txt            consolidated run, --solver-timeout-assertion 60000
```

## Consolidated run

One run over the whole contract, for a single cross-checkable artifact
(`halmos-full-suite.txt`). Note the shorter per-assertion budget (60s vs the 120-240s used in
the per-property runs above) — the individual runs are authoritative where they differ, and
they do not: the outcome of every test is identical.

```
halmos --contract AntimatterSymbolic --solver-timeout-assertion 60000 --statistics
```

```
Running 24 tests for test/audit/symbolic/AntimatterSymbolic.t.sol:AntimatterSymbolic
Symbolic test result: 6 passed; 18 failed; time: 673.05s
[time] total: 673.53s (build: 0.25s, load: 0.22s, tests: 673.05s)
```

**The `18 failed` headline is misleading and must not be quoted as-is.** Halmos counts
`[FAIL]`, `[TIMEOUT]` and `[ERROR]` all as "failed". Broken out:

| Bucket | Count | Tests |
| --- | --- | --- |
| `[PASS]` — proofs | 6 | `allowance_spentExactly_d6`, `allowance_spentExactly_d6_k`, `annihilate_noResidue_d6`, `conservation_orderAgnostic`, `toStableAmount_exact`, `toStableAmount_exact_d6` |
| `[FAIL]` — **intended** refutations (harness instruments) | 4 | 3 non-vacuity tripwires + the symbolic-`EXP` probe. These are *required* to fail. |
| `[FAIL]` — real refutations (findings) | 3 | `callerCannotSpendStableWithoutStableAllowance_d6`, `..._d6_k` (CODE-001), `mintedForStable_alwaysNonZero_d6` |
| `[TIMEOUT]` — **unverified, not safe** | 11 | 6 end-to-end conservation variants, 3 overflow-parity variants, 2 reverts-iff-inexact variants |

(The consolidated run predates the addition of `check_annihilate_noResidue_d6_unbounded`, so it
covers 24 of the harness's 25 tests; that test has its own artifact,
`halmos-p2-noresidue-unbounded.txt`.)

## Reproducing

```bash
cd /home/justin/code/audits/workspace/antimatter
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract AntimatterSymbolic \
  --function <check_name> \
  --solver-timeout-assertion 180000 \
  --statistics
```

Note on exit codes: `halmos` exits non-zero for `[FAIL]`, `[TIMEOUT]`, **and** `[ERROR]`
alike, so a CI wrapper must parse the per-test markers rather than trust the exit code —
otherwise a timeout and a refutation are indistinguishable, and treating either as the other
is the exact failure mode this report is written to avoid.
