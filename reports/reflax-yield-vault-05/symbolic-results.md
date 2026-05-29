# Symbolic-Analyzer Results — phoenix-vault (reflax-yield-vault)

- Project: phoenix-vault (maps to `lib/reflax-yield-vault`)
- Tool: Halmos 0.3.3 (SMT: yices 2.6.5 / z3 — bitwuzla unavailable offline), forge 1.5.1 fuzz corroboration
- Run timestamp: 2026-05-25
- Target: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (share/principal accounting math)
- Harnesses (writable workspace, NOT in lib/):
  - `workspace/phoenix-vault/test/symbolic/AccountingSymbolic.t.sol` (Halmos `check_` properties)
  - `workspace/phoenix-vault/test/symbolic/AccountingFuzz.t.sol` (forge fuzz corroboration of division-heavy properties Halmos cannot close)

## Method / why a harness

The full strategy cannot be symbolically executed: every value path calls into the
ERC4626 vault (`convertToShares`/`convertToAssets`/`balanceOf`) and the AMM adapter
(`swap`), all opaque to the solver. Per the agent's degrade-gracefully mandate, the pure
accounting arithmetic was extracted verbatim into a minimal symbolic harness. The ERC4626
price is modeled as a symbolic monotone linear rate (`shares = assets*1e18/rate`,
`assets = shares*rate/1e18`), matching the profiles' trust assumption that
`convertToShares/convertToAssets` are honest, monotone oracles. The batch loop's
per-occurrence accumulation is replicated for the concrete `[A,A,B,B]` / `[A,A]` duplicate
triggers from CODE-001.

## Results summary

| Property | Tool | Result | Meaning |
|---|---|---|---|
| `check_skim_single_duplicate_breaks` | Halmos | **FAIL (refuted)** | CODE-001 confirmed: one duplicate doubles the skim past true surplus |
| `check_skim_no_overskim_duplicates` (`[A,A,B,B]`) | Halmos | **FAIL (refuted)** | CODE-001 confirmed: batch skims 2x the true aggregate surplus |
| `check_skim_dedup_exact` (`[A,B]`) | Halmos | **PASS (proven)** | Positive control: deduplicated batch never over-skims (all paths) |
| `check_minOut_maxBps_disables` | Halmos | **PASS (proven)** | ECON-02: `bps == MAX_BPS` ⇒ `minOut == 0` (protection fully off) |
| `check_minOut_no_underflow` | Halmos | **PASS (proven)** | INV-3: `MAX_BPS - bps` never underflows for `bps <= MAX_BPS` |
| `check_minOut_monotonic` (`minOut <= ideal`) | Halmos | TIMEOUT → **fuzz PASS** | mul/div defeats SMT; 50k-run fuzz holds |
| `check_minOut_weakens_with_bps` (monotone in bps) | Halmos | TIMEOUT → **fuzz PASS** | mul/div defeats SMT; 50k-run fuzz holds |
| `check_totalBalanceOf_bounded` | Halmos | TIMEOUT → **fuzz PASS** | symbolic divisor defeats SMT; 50k-run fuzz holds |
| `check_withdraw_shareCap_safe` | Halmos | TIMEOUT → **fuzz PASS** | symbolic-rate division defeats SMT; 50k-run fuzz holds |

forge fuzz: `AccountingFuzz` — 6 properties, **50,000 runs each, 0 failures** (incl. the
over-skim violation `testFuzz_overskim_duplicate`, which asserts `batchShares > trueSurplus`
for all inputs and passed — i.e. the bug is universal).

---

## Property 1 — Skim surplus bound (CODE-001): REFUTED (bug confirmed)

**Claim under test (safety property):** the total surplus shares removed by `_skimSurplusBatch`
over a `clients[]` array is bounded by the true aggregate surplus (each distinct client counted
once). Halmos was asked to prove `batchShares <= trueSurplusShares`.

**Verdict: REFUTED.** Halmos found counterexamples in both the single-duplicate `[A,A]` and the
`[A,A,B,B]` configurations. The batch loop (`ERC4626MarketYieldStrategy.sol:468-478`) iterates
the caller-supplied array with no dedup and no seen-set, accumulating `convertToShares(surplus)`
once per *occurrence*. The only ceiling later applied is `availableShares` (the strategy's entire
vault-share balance, line 481) — never the true aggregate surplus.

Decoded counterexamples (units = vault shares):

- **`[A,A]` (single duplicate):** `surplusA = 2^63`, `rate = 2^79` ⇒ `surplusShares = 15,258,789,062,500`.
  - true surplus shares = `15,258,789,062,500`
  - batch accumulates = `30,517,578,125,000` (exactly 2×)
  - **over-skim = 15,258,789,062,500 shares** (100% excess).
- **`[A,A,B,B]`:** `principalA = principalB = 2^63`, `totalValue = 2^95`, `rate = 2^79`.
  - true surplus shares = `65,535,999,969,482,421,875,000`
  - batch accumulates = `131,071,999,938,964,843,750,000` (exactly 2×)
  - **over-skim = 65,535,999,969,482,421,875,000 shares.**

In both cases the batch tries to sell ~2× the legitimate surplus. Capped only by total held
shares (`2S << 2P+2S`, so the cap does not bite), the extra shares come out of the pool backing
clients' principal. Because `clientBalances`/`totalDeposited` are intentionally untouched (INV-2),
the shortfall surfaces later as an under-collateralized withdrawal, not an immediate revert.

**Positive control (`check_skim_dedup_exact`, clients = `[A,B]`): PASS over all 18 paths** — with
each client counted once, `batchShares <= trueSurplusShares` holds universally. This isolates the
root cause precisely to the *missing deduplication*, not to the surplus math itself.

This is a mathematical proof (counterexample existence) corroborating CODE-001. The
`onlyAuthorizedWithdrawer` gate tempers likelihood (trusted caller), but an accidental duplicate
in an off-chain-assembled batch deterministically over-skims and bleeds third-party backing —
consistent with the code-scan's Medium estimate. Final severity is the classifier's call.

## Property 2 — minOut monotonicity (ECON-01/02): PARTIALLY PROVEN

- `check_minOut_maxBps_disables`: **PROVEN (PASS).** For all `ideal`, `bps == MAX_BPS` ⇒
  `minOut = ideal*(MAX_BPS-MAX_BPS)/MAX_BPS == 0`. ECON-02's "100% slippage tolerance fully
  disables protection" is symbolically confirmed: every swap then accepts any output ≥ 0.
- `check_minOut_no_underflow`: **PROVEN (PASS).** `MAX_BPS - bps` never underflows given the
  setter's `bps <= MAX_BPS` (INV-3).
- `check_minOut_monotonic` (`minOut <= ideal`) and `check_minOut_weakens_with_bps`
  (`minOut` non-increasing in `bps`): **Halmos TIMEOUT** even at `uint64 ideal`/`uint16 bps`
  with both yices and z3 (the `product / MAX_BPS` division stalls the model phase — a known
  Halmos limitation on non-constant-power division, not evidence of a violation).
  **Corroborated by forge fuzz at 50,000 runs (0 failures).**

  Closed-form proof of the two timed-out properties (both trivial):
  - Floor bound: `minOut = ⌊ideal·(K−b)/K⌋ ≤ ideal·(K−b)/K ≤ ideal` since `0 ≤ K−b ≤ K`.
    Equality at `b=0`; `minOut=0` at `b=K`. ∎
  - Monotonicity: for `b₁ ≤ b₂`, `(K−b₁) ≥ (K−b₂)`, and `x ↦ ⌊ideal·x/K⌋` is non-decreasing,
    so `minOut(b₁) ≥ minOut(b₂)`. ∎

  Confirms `minOut = fairAmount·(MAX_BPS−bps)/MAX_BPS` is exactly the contract's formula
  (lines 277, 322, 384, 436, 483) and that protection degrades smoothly to zero at `bps = MAX_BPS`
  — the structural basis for ECON-01 (slippage cap = `bps` vs fair NAV) and ECON-02.

## Property 3 — No underflow/overflow in proportional share math: VERIFIED (fuzz) + proof

- `check_totalBalanceOf_bounded`: a single client's proportional value
  `(totalValue·principal)/totalDeposited` never exceeds `totalValue` when `principal ≤ totalDeposited`
  (INV-1). **Halmos TIMEOUT** (symbolic *divisor* `totalDeposited` is the hardest SMT case);
  **fuzz PASS at 50k runs.** Proof: `principal ≤ totalDeposited` ⇒ `principal/totalDeposited ≤ 1`
  ⇒ `⌊totalValue·principal/totalDeposited⌋ ≤ totalValue`. No underflow: `totalBalanceOf` early-returns
  on `principal==0 || totalDeposited==0` (lines 142-144), so the divisor is always > 0. ∎
- `check_withdraw_shareCap_safe`: after the cap (`:316-318`) `sharesToSell ≤ availableShares`, and
  `idealUnderlying = convertToAssets(sharesToSell) ≤ convertToAssets(availableShares)`. **Halmos
  TIMEOUT** (symbolic-rate division); **fuzz PASS at 50k runs.** Confirms the strategy never tries
  to sell more shares than it holds and the `minOut` is computed on the post-cap amount (consistent
  floor). No overflow under 0.8.x checked arithmetic (no `unchecked`/assembly — profiles INV).

---

## What was proven / refuted / inconclusive

- **Refuted (bug confirmed, mathematically):** CODE-001 — `_skimSurplusBatch` over-skims to exactly
  2× the true surplus for `[A,A]` and `[A,A,B,B]`; Halmos counterexamples decoded above. Root cause
  isolated to missing dedup (the `[A,B]` control proves correct).
- **Proven (Halmos, all paths):** ECON-02 `bps==MAX_BPS ⇒ minOut==0`; `MAX_BPS−bps` no underflow;
  deduplicated batch never over-skims.
- **Inconclusive on Halmos / proven by fuzz + closed form:** minOut floor bound, minOut monotonicity,
  `totalBalanceOf` bound, withdraw share-cap safety — all defeated the SMT solver's division handling
  (offline, bitwuzla unavailable), but pass 50,000 fuzz runs each with no counterexample and have
  trivial closed-form proofs given here.

## Limitations encountered

- Halmos cannot symbolically execute the strategy directly (external vault/adapter calls) — harness
  extraction was required, as anticipated by the agent spec.
- Properties whose arithmetic includes a division by a non-constant-power term (`X/MAX_BPS` with
  symbolic `X`, or division by a symbolic `totalDeposited`/`rate`) time out on the locally available
  solvers (yices, z3). bitwuzla (which handles bitvector division far better) could not be used:
  the environment blocks solver downloads (`HALMOS_ALLOW_DOWNLOAD` unset, per the offline-safe
  toolchain policy). These were closed via 50k-run forge fuzzing plus closed-form proofs instead.
- No `lib/` files were modified; all artifacts live under `workspace/phoenix-vault/test/symbolic/`.

## Reproduce

```bash
cd workspace/phoenix-vault
# Halmos-tractable properties (CODE-001 refutation + ECON-02 + dedup control):
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos --contract AccountingSymbolic \
  --solver-timeout-assertion 60000 --statistics \
  --match-test '^check_(minOut_maxBps|minOut_no_under|skim_)'
# Fuzz corroboration of the division-heavy properties:
PATH="$HOME/.foundry/bin:$PATH" FOUNDRY_FUZZ_RUNS=50000 forge test --match-contract AccountingFuzz
```
