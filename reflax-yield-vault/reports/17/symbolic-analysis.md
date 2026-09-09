# Symbolic analysis — run 17 · reflax-yield-vault @ `cdd0743`

**Scope:** verification of ONE load-bearing claim from `econ-scan.md` §2.3, which currently
downgrades `F-01-050`, `CODE-01` and `ECON-17-01`.

> **The claim under test.** `_isUnderwater ⟺ V < D`; the share cap binds ⟺ `amount > V`; and
> since `amount ≤ p ≤ D`, cap-binds ⟹ underwater. Therefore `StableStakerV2._isUnderwater`
> dominates the cap-binding condition and the `previewExitFor` over-quote is unreachable through
> the live consumer path.

**Verdict: DOMINANCE HOLDS — the downgrade is justified**, subject to four explicitly-named
conditions (§6). The claim survived every counterexample search I could run: a complete 696 M-state
sweep of the live integer semantics, 4 M random samples at 18-decimal magnitudes, and 150 k fuzz
runs against the real contracts in the real two-client topology — all with vacuity tripwires armed.

Two honesty notes up front. **Halmos returned no `[PASS]` at all** — every positive property timed
out, so nothing here is symbolically proven and §3.2 says so plainly. And the claim as written in
`econ-scan.md` is **broader than what actually holds**; §6 and §7 record exactly where it stops.

---

## 1. The real definitions, from source

All quotes are from **top-level `lib/` HEAD only** — no nested `lib/mutable/**` copy was read.

`lib/stable-staker` @ `fa06de5`, `lib/reflax-yield-vault` @ `cdd0743`.

### 1.1 The guard — `StableStakerV2.sol:851-853`

```solidity
/// @dev The strategy is below par for the farm's position when its total balance (principal +
///      yield) is worth less than the principal it custodies for this contract.
function _isUnderwater(address token, IYieldStrategy strategy) internal view returns (bool) {
    return strategy.totalBalanceOf(token, address(this)) < strategy.principalOf(token, address(this));
}
```

Consumed at four `_routeExit` sites — `StableStakerV2.sol:279, 366, 408, 486` — but the guard is
**armed on exactly one of them**, `withdraw()` at `:366` (`guardUnderwater == true`). It is also
exposed as the public view `withdrawDisabled()` (`:795-801`).

`_routeExit` itself, `StableStakerV2.sol:876-895`: on the armed path an underwater strategy is
never touched — the withdrawal is paid from the on-contract buffer (with a matching
`relinquishPrincipal` write-down) or the call reverts `"StableStaker: strategy underwater"`.

### 1.2 The value/deposit accounting — `AYieldStrategy.sol`

```solidity
// :523-526
function principalOf(address token, address account) external view override returns (uint256) {
    return clientBalances[token][account];                                        //  p
}

// :536-550
function totalBalanceOf(address token, address account) external view override returns (uint256) {
    uint256 principal = clientBalances[token][account];
    if (principal == 0 || totalDeposited[token] == 0) { return 0; }
    uint256 totalValue = _positionValue();                                        //  V
    return (totalValue * principal) / totalDeposited[token];                      //  floor(V·p/D)
}
```

- `:48` — the declared invariant `totalDeposited[token] == Σ clientBalances[token][*]`, i.e. **`p ≤ D`**.
  I verified this mechanically rather than trusting the comment: every write to either map is
  paired. `_relinquishInternal` `:712-713`, `_depositInternal` `:744-745`, `_withdrawInternal`
  `:781-782` each move both by the same amount; the only other writes,
  `ERC4626YieldStrategy.sol:197-198` and `ERC4626MarketYieldStrategy.sol:312-313`, zero a client
  and subtract that same figure from `totalDeposited`. There is **no unpaired write**.
- `:772-776` — `_withdrawInternal` caps `amount` to `clientBalances[balanceHolder]` **before**
  calling `_disposeShares`, i.e. **`a ≤ p`** at the point the cap is evaluated.

### 1.3 The cap — the market override and the direct strategy

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:127-135
function _exitFloor(uint256 amount) internal view returns (uint256) {
    uint256 sharesToSell = vault.convertToShares(amount);
    uint256 availableShares = vault.balanceOf(address(this));   // GLOBAL
    if (sharesToSell > availableShares) { sharesToSell = availableShares; }
    uint256 idealUnderlying = vault.convertToAssets(sharesToSell);
    return idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
}
```

`ERC4626MarketYieldStrategy.sol:162-186` — `previewExitFor` grosses up, caps `grossToRequest` to
`clientBalances[token][account]` (`:180-183`), then calls `_exitFloor`.
`ERC4626YieldStrategy.sol:126-138` — `_disposeShares` applies the *identical* share cap on the
execution path. `_positionValue()` is `vault.convertToAssets(vault.balanceOf(address(this)))` in
**both** concretes (`ERC4626MarketYieldStrategy.sol:78-80`, `ERC4626YieldStrategy.sol:61-63`) —
the same `V` the guard sees. There is no idle-underlying term in one and not the other.

The base default, `AYieldStrategy.sol:571-584`, models **no** share cap at all — this is `F-01-050`.

---

## 2. Making it tractable (budget discipline)

The literal encoding needs **three** symbolic 256-bit divisions — `convertToShares`,
`convertToAssets`, and the pro-rata in `totalBalanceOf`. That is beyond Halmos here, and the first
attempt confirmed it: **`test/symbolic/DominanceRun17.t.sol`, all three theorems `[TIMEOUT]` at
120 s/assertion** (raw output in §4.1). `vm.assume` bounds at `2^96` did not help, exactly as
expected.

Two changes made it decidable:

1. **Every floor is encoded multiplicatively.** `q == floor(x·S/A)` becomes
   `q·A ≤ x·S ∧ x·S < (q+1)·A`. This is *exact* — it admits precisely the values the real code can
   produce — and **division-free**.
2. **Parameters declared `uint64` and widened**, so the range bound sits in the term structure
   (zero-extension) rather than in a side constraint. This is what `vm.assume` could not do.

`Sv`/`Av` are the vault's *effective* share/asset multipliers left free, so the model covers plain
`totalSupply`/`totalAssets`, OpenZeppelin's virtual-share `(S+1)/(A+1)` offset, and any
decimal-offset variant, rather than one vault's specific formula.

---

## 3. Results

### 3.1 Exhaustive integer search — the decisive result

`/tmp` script, reproduced in §4.3. This runs the **exact integer semantics of the live code**, not
an encoding of it, over a complete small domain. It is a total search, so a clean result here is a
proof over that domain and a strong cross-check on the symbolic encoding.

| Variant | States searched | Cap-binding states | Counterexamples |
|---|---:|---:|---:|
| **T1 baseline** (ERC4626-conformant: both `convertTo*` round DOWN), N=26 | 52,812,500 | **15,439,151** | **0** |
| **T1 baseline, widened full sweep N=40** | 696,009,600 | **209,906,416** | **0** |
| **T1 baseline, 4 M random samples over a 2^90 domain** | 4,000,000 | **750,462** | **0** |
| T5 exotic vault: `convertToAssets` rounds **UP** | 2,135,280 | 70,724 | **4** (see §7.1) |
| T2 negative control: drop `p ≤ D` | 8,762 | 8,129 | 4 |
| T3 negative control: drop `a ≤ p` | 8,456 | 8,129 | 4 |

**T1: zero counterexamples across 210 M cap-binding states in the complete N=40 sweep, and zero
across a further 750 k cap-binding states sampled at realistic 18-decimal magnitudes (2^90).** The
claim survives.

(A fourth, boundary-biased sampler was run and is reported for completeness: it produced **0**
cap-binding states out of 4 M trials, because pinning `a ≈ V` with `p ≤ D ≈ V` makes the cap
essentially unreachable. That is consistent with the theorem but contributes **no independent
evidence**, and is not counted above.)

**The negative controls both FAIL, as they must.** This is the generality test: T2 and T3 show the
theorem is *not* an arithmetic tautology. Its two load-bearing premises are the accounting
invariant `p ≤ D` (`AYieldStrategy.sol:48`) and the withdraw cap `a ≤ p`
(`AYieldStrategy.sol:772-776`). Break either and a counterexample appears immediately
(`a=2, p=2, D=1, B=1, Sv=1, Av=1` for T2). The dominance is a **property of this code**, not of
the integers.

**The guard is a strict superset, not an equivalence:** 34,815,616 underwater states of which
**19,376,465 do not bind the cap**. The guard fires early and often — the conservative direction.

### 3.2 Halmos — counterexample search only; NO proof obtained

Harness `test/symbolic/DominanceRun17Narrow.t.sol`. Full raw output in §4.2.

**Outcome: 0 passed. Halmos proved nothing here.** Widening to `uint64` did not rescue
tractability: 7 of 9 properties `[TIMEOUT]` at 180 s/assertion, including
`check_L1a_mulMonotone` — the statement `a ≤ V ⟹ a·Sv ≤ V·Sv`, which is trivially true. That a
one-line monotonicity lemma times out identifies the bottleneck precisely: it is **bit-blasting the
multiplication of two 64-bit values inside 256-bit bitvectors**, not the difficulty of the
property. Removing the divisions was necessary but not sufficient; the products are themselves the
wall.

| Property | Result | Weight |
|---|---|---|
| `check_L1a_mulMonotone` | `[TIMEOUT]` 180.17 s | **unverified** |
| `check_L1b_cancelPositiveFactor` | `[TIMEOUT]` 180.16 s | **unverified** |
| `check_L1_capBindsImpliesAmountExceedsPositionValue` | `[TIMEOUT]` 180.20 s | **unverified** |
| `check_L2_notUnderwaterImpliesValueCoversTotalDeposited` | `[TIMEOUT]` 180.19 s | **unverified** |
| `check_T1_capBindsImpliesUnderwater` | `[TIMEOUT]` 180.25 s | **unverified** |
| `check_T2_negControl_dropPLeqD` | `[TIMEOUT]` 180.35 s | **unverified** |
| `check_T5_assetsRoundUp` | `[TIMEOUT]` 180.36 s | **unverified** |
| `check_T3_negControl_dropALeqP` | `[FAIL]` + counterexample, 2.59 s | **intended failure** — negative control |
| `check_T4_tripwire_capCanActuallyBind` | `[FAIL]` + counterexample, 3.21 s | **intended failure** — vacuity tripwire |

Halmos's contribution to this verdict is therefore limited to the two things it is genuinely good
at — **finding** counterexamples. It confirmed the `a ≤ p` premise is load-bearing (T3 witness
`a = 2^63, p = 1, D = 1, B = 2^62`: the cap binds while `tb = 2^62 ≥ p`, so the guard does **not**
fire) and confirmed the guarded region is non-empty (T4). It **proved** none of the positive
properties, and no `[TIMEOUT]` row above is evidence of anything.

**The verdict in §9 therefore rests on §3.1 and §3.3, not on Halmos.** The exhaustive integer
search is the stronger instrument here anyway: it runs the exact code semantics rather than an
encoding of them, and over its domain it is a complete decision procedure, not a sampled one. But
its complete domain is bounded (values < 40), and that limitation is real — see §7.5.

### 3.3 Grounding against the REAL contracts

`test/symbolic/DominanceRun17Grounding.t.sol` — real `ERC4626MarketYieldStrategy`, real
`ERC4626YieldStrategy`, real `MockERC4626Vault` math, in the **two-client topology**
(`staker` + `minter`, per `MigrateStableStakerMainnet.s.sol:496/595`). Property asserted is
`capBinds(a) ⟹ _isUnderwater(strategy, staker)` computed from the strategies' own external views.

```
[PASS] testFuzz_direct_twoClients_capBindsImpliesUnderwater  (runs: 50000)
[PASS] testFuzz_market_otherClientDrainsFirst                (runs: 50000)
[PASS] testFuzz_market_twoClients_capBindsImpliesUnderwater  (runs: 50000)
[PASS] test_converseFails_underwaterWithoutCapBinding
[PASS] test_gridCoverage_marketAndDirect
       grid cases            : 105
       grid cases cap-binding: 25
       grid cases underwater : 75
[PASS] test_tripwire_capActuallyBinds
       principal (staker)    : 990000000000000000000
       positionValue         : 200000000000000000000
       totalBalanceOf(staker): 100000000000000000000
[PASS] test_tripwire_direct_capActuallyBinds
7 passed; 0 failed
```

### 3.4 The vacuity tripwires — and the one that fired

**The first grounding harness was vacuous, and the tripwire caught it.** Its
`test_tripwire_capActuallyBinds` failed with *"TRIPWIRE: the guarded (cap-binding) state was NEVER
reached"*: I had sized the simulated drawdown against the *strategy's own position* rather than the
*vault's total assets*, which moves the share price by ~0.01% and never binds the cap. In that
version all three fuzz tests reported **50,000 green runs each while proving nothing**. Had the
tripwire not been there, this report would have recorded 150,000 vacuous passes as evidence.

After the fix, coverage is explicit and auditable: the deterministic grid enters the cap-binding
state in **25 of 105** cases, `test_tripwire_capActuallyBinds` pins one concrete binding state and
shows it is underwater (position value 200e18 against 990e18 of staker principal), and
`test_converseFails_underwaterWithoutCapBinding` pins a state that is underwater *without* binding
the cap — so the two conditions are demonstrably distinct, not two names for one predicate.

The symbolic harness carries the same tripwire: `check_T4_tripwire_capCanActuallyBind` asserts the
cap *never* binds and is **expected to FAIL**. Both the 2^96 and the `uint64` version returned
`[FAIL]` with a concrete witness, confirming the guarded region is populated.

---

## 4. Raw output

### 4.1 First attempt — `DominanceRun17.t.sol` (2^96 `vm.assume` bounds): TIMEOUT

```
$ halmos --contract DominanceRun17 --solver-timeout-assertion 120000 --statistics

Running 4 tests for test/symbolic/DominanceRun17.t.sol:DominanceRun17
[TIMEOUT] check_capBindsImpliesUnderwater(...)              (paths: 15, time: 120.35s)
[TIMEOUT] check_capBindsImpliesUnderwater_assetsRoundUp(...) (paths: 21, time: 120.50s)
[TIMEOUT] check_negControl_dropPLeqD(...)                   (paths: 15, time: 120.31s)
Counterexample:
    p_Av_uint256_65d18e0_00 = 0x600000000000000000000000
    p_B_uint256_811f318_00  = 0x800000000000000000000000
    p_D_uint256_2b3a974_00  = 0x800000000000000000000000
    p_Sv_uint256_6df116f_00 = 0x800000000000000000000000
    p_V_uint256_fecbc03_00  = 0x600000000000000000000000
    p_a_uint256_2d54818_00  = 0x800000000000000000000000
    p_p_uint256_d50eba2_00  = 0x800000000000000000000000
    p_q_uint256_5095653_00  = 0xaaaaaaaaaaaaaaaaaaaaaaaa
    p_tb_uint256_3187955_00 = 0x600000000000000000000000
[FAIL] check_tripwire_capCanActuallyBind(...)               (paths: 14, time: 2.62s)
Symbolic test result: 0 passed; 4 failed; time: 363.84s
```

**These three TIMEOUTs prove nothing and are recorded as `unverified`.** The `[FAIL]` is the
vacuity tripwire behaving correctly — the witness is a genuine cap-binding state (and it is
underwater: `V = 0x6…` &lt; `D = 0x8…`).

### 4.2 `DominanceRun17Narrow.t.sol`

```
$ halmos --contract DominanceRun17Narrow --solver-timeout-assertion 180000 --statistics

Running 9 tests for test/symbolic/DominanceRun17Narrow.t.sol:DominanceRun17Narrow
[TIMEOUT] check_L1_capBindsImpliesAmountExceedsPositionValue(uint64 x6)      (paths: 17, time: 180.20s)
[TIMEOUT] check_L1a_mulMonotone(uint64,uint64,uint64)                        (paths:  7, time: 180.17s)
[TIMEOUT] check_L1b_cancelPositiveFactor(uint64,uint64,uint64)               (paths:  7, time: 180.16s)
[TIMEOUT] check_L2_notUnderwaterImpliesValueCoversTotalDeposited(uint64 x4)  (paths: 11, time: 180.19s)
[TIMEOUT] check_T1_capBindsImpliesUnderwater(uint64 x9)                      (paths: 24, time: 180.25s)
[TIMEOUT] check_T2_negControl_dropPLeqD(uint64 x9)                           (paths: 24, time: 180.35s)
Counterexample:
    p_Av__uint64 = 0x8000000000000000     p_B__uint64  = 0x4000000000000000
    p_D__uint64  = 0x01                   p_Sv__uint64 = 0x8000000000000000
    p_V__uint64  = 0x4000000000000000     p_a__uint64  = 0x8000000000000000
    p_p__uint64  = 0x01                   p_q__uint64  = 0x8000000000000000
    p_tb__uint64 = 0x4000000000000000
[FAIL] check_T3_negControl_dropALeqP(uint64 x9)                              (paths: 24, time: 2.59s)
Counterexample:
    p_Av__uint64 = 0x8000000000000000     p_B__uint64  = 0x00
    p_D__uint64  = 0x8000000000000000     p_Sv__uint64 = 0x8000000000000000
    p_V__uint64  = 0x00                   p_a__uint64  = 0x8000000000000000
    p_p__uint64  = 0x8000000000000000     p_q__uint64  = 0x8000000000000000
    p_tb__uint64 = 0x00
[FAIL] check_T4_tripwire_capCanActuallyBind(uint64 x9)                       (paths: 23, time: 3.21s)
[TIMEOUT] check_T5_assetsRoundUp(uint64 x9)                                  (paths: 30, time: 180.36s)
Symbolic test result: 0 passed; 9 failed; time: 1267.52s

Full untruncated output: symbolic-raw/halmos-narrow-uint64.txt
```

### 4.3 Exhaustive integer search

Script and results reproduced under `symbolic-raw/exhaustive-search.py` / `.txt`.

---

## 5. Harness paths

| File | Purpose |
|---|---|
| `/home/justin/code/audits/workspace/reflax-yield-vault/test/symbolic/DominanceRun17.t.sol` | first attempt, 2^96 `vm.assume` — TIMEOUT, kept as the negative methodological record |
| `/home/justin/code/audits/workspace/reflax-yield-vault/test/symbolic/DominanceRun17Narrow.t.sol` | tractable symbolic theorem + 2 negative controls + vacuity tripwire |
| `/home/justin/code/audits/workspace/reflax-yield-vault/test/symbolic/DominanceRun17Grounding.t.sol` | real contracts, two-client topology, 150k fuzz + grid coverage + 2 tripwires |
| `/home/justin/code/audits/reports/reflax-yield-vault/17/symbolic-raw/DominanceRun17Ladder.t.sol` | 8/16/32-bit tractability ladder — ABORTED, 16-bit tier already timed out (§7.5) |
| `/home/justin/code/audits/reports/reflax-yield-vault/17/symbolic-raw/` | copies of all three harnesses + raw tool output |

---

## 6. Scope — the four conditions the dominance depends on

The claim holds **conditionally**, not unconditionally. Naming these is the point of the exercise.

1. **It depends on `p ≤ D` (`AYieldStrategy.sol:48`).** Verified mechanically (§1.2): every write
   to `clientBalances` / `totalDeposited` is paired, so no current path can break it. But T2 shows
   that a *future* unpaired write — a client-balance transfer, a migration helper that touches one
   map — silently destroys the dominance and re-arms `F-01-050`/`CODE-01` at Medium. **This is a
   regression tripwire worth recording in the ledger, not a settled fact.**
2. **It depends on `a ≤ p` (`AYieldStrategy.sol:772-776`).** T3 shows the same. Any future exit
   path that reaches `_disposeShares` / `_exitFloor` *without* first capping to the caller's
   principal breaks it.
3. **It covers ONLY the armed consumer path**, `StableStakerV2.withdraw()` → `_routeExit(..., true)`
   at `:366`. It says nothing about `:279` (`setYieldStrategy` sweep), `:408`
   (`emergencyWithdraw`) or `:486` (migration), all of which pass `guardUnderwater == false`. Those
   are separately defended (`:268` `require(!_isUnderwater(token, old))`, and the migration's
   measured `(R,P)` snapshot), but **not by this theorem**.
4. **It covers only clients that run the guard.** `_isUnderwater` is StableStaker checking *itself*.
   The second client, `PhusdStableMinter`, does not run it. Dominance protects StableStaker's
   withdraw path; it does not make `previewExitFor` honest for any other consumer.

**On the multi-client (CODE-01) topology specifically — the obvious place to expect failure.** It
does not fail, and the reason is worth stating because it is counter-intuitive: `D` is the
**global** `totalDeposited` across all clients, so adding a second client *raises* `D` and makes
`V < D` — the underwater condition — **more** likely, while the cap-binding threshold `a > V` is
unchanged. Extra clients strengthen the guard rather than weaken it. This is confirmed
independently by the T1 search (`p` ranges freely over `1..D`, so every `p ≪ D` multi-client
configuration is inside the domain) and by the three two-client fuzz tests, including
`testFuzz_market_otherClientDrainsFirst`, which reproduces the CODE-01 race by draining the other
client first.

---

## 7. What is NOT covered — do not read these as verified

### 7.1 A vault whose `convertToAssets` rounds UP breaks dominance — by exactly 1 wei

The T5 variant found **real counterexamples**, the smallest being
`a=1, p=1, D=1, B=1, Sv=2, Av=1`: `convertToShares(1) = 2 > B = 1` so the cap binds, while
`V = ceil(1·1/2) = 1` and `tb = 1 = p`, so `_isUnderwater` is **false**.

I bounded the harm before reporting it: over an exhaustive `N=60` sweep the **worst absolute
shortfall is 1 unit**. So this is a dust-magnitude boundary artefact, not a live vector — and it
requires a vault that violates the ERC4626 convention that `convertToAssets` rounds down (OZ, and
every vault in scope, round down). **Recorded as a boundary condition, filed as nothing.**

### 7.2 The dominance covers the vault-LOSS deficit, NOT the exit-FEE deficit

`econ-scan.md` §2.3 already flags this and it is correct: `_isUnderwater` is built on the same
fee-blind `convertToAssets` (via `totalBalanceOf`) as `_exitFloor`, so a fee-charging vault's
deficit is invisible to **both** sides of the implication. My theorem inherits that blindness — it
proves the guard dominates the *share-cap* over-quote and says nothing about `ECON-A` / `L-16`.
That residual remains exactly as previously measured.

### 7.3 The dominance covers the share cap, not the AMM slippage floor

`netGuaranteed` can also fall short of what the AMM actually pays, in either direction
(`ERC4626MarketYieldStrategy.sol:151-153` says so explicitly). `CODE-02`'s
`testH2_HealthyQuoteThenWithdrawReverts` is untouched by this result.

### 7.4 Fourteen non-PASS Halmos results, zero proofs

Across all three harnesses Halmos returned **0 `[PASS]`**, 11 `[TIMEOUT]`, and 3 `[FAIL]` — and all
three failures are intended ones (one negative control, two vacuity tripwires). Counted from the
archived artifacts: `symbolic-raw/halmos-narrow-uint64.txt` (7 TIMEOUT + 2 FAIL),
`symbolic-raw/halmos-ladder-ABORTED.txt` (1 TIMEOUT), and the first run quoted in §4.1
(3 TIMEOUT + 1 FAIL).

Every one of the 11 `[TIMEOUT]`s is recorded as `unverified`. They carry **zero** safety weight,
and none of them is superseded *by Halmos* — they are superseded by §3.1 and §3.3, which are
different instruments with different limits (§7.5). No sentence in this report, and no sentence in
any report that cites it, may present a timed-out property as verified.
### 7.5 The proof is a large search, not a symbolic proof over all uint256

This matters and I will not dress it up. The N=40 sweep is *complete* only over values below 40;
the 2^90 sampling is *sampling*. Neither is a proof over the full `uint256` domain, and the
symbolic tier that would have provided one produced no `[PASS]` (§3.2). A pen-and-paper argument
does close the gap — from `q·Av ≤ a·Sv` and `a ≤ V` and `V·Sv ≤ B·Av` we get `q·Av ≤ B·Av`, so
`q ≤ B` for `Av > 0`; and from `tb ≥ p` with `tb·D ≤ V·p` we get `p·D ≤ V·p`, so `D ≤ V` for
`p > 0` — and the searches are exactly what that argument predicts, at every scale tested. But a
hand proof is not a machine-checked one, and this report does not claim it is.

A tractability ladder (`DominanceRun17Ladder.t.sol`, the same theorems at 8/16/32-bit widths) was
written to recover a real bounded `[PASS]`. It was **aborted before completing**, but it had
already produced one result, and that result is informative:

```
[TIMEOUT] check_L1_16(uint16,uint16,uint16,uint16,uint16,uint16)  (paths: 17, time: 120.11s)
```

**The share-cap lemma times out even at 16-bit width** — six `uint16` parameters, four products,
no divisions, 120 s. That is a domain of values below 65,536, which the N=40 exhaustive sweep
already covers completely and far beyond. So the ladder is not a promising avenue that went
unexplored; the evidence is that Halmos would have had to be driven down to roughly 8-bit before
deciding these products, at which point it would prove strictly *less* than §3.1 already does.

The honest conclusion is that **Halmos is the wrong instrument for this property**, not that it was
under-resourced. Recorded so the next reader does not spend the budget again. Archived at
`symbolic-raw/halmos-ladder-ABORTED.txt`; the harness is kept at
`symbolic-raw/DominanceRun17Ladder.t.sol` should a future solver make it worth retrying.

---

## 8. Independent re-confirmation of the other pillar

The Low rating also rests on `previewExitFor` having zero consumers. Re-derived here without
truncation — full counts, every top-level submodule HEAD, first-party files only:

```
antimatter: 0        phlimbo-ea: 0              phoenix-nft-staking: 0
phoenix-phase-2-staging: 0                      stable-staker: 0
stable-yield-accumulator: 0                     yield-claim-nft: 0
reflax-yield-vault: 32   (the definition and its own tests)
```

Confirmed. `WATCH-17-03` — escalate on the `stable-staker` submodule bump — remains the correct
trigger.

---

## 9. Verdict

**DOMINANCE HOLDS. The downgrade of `F-01-050`, `CODE-01` and `ECON-17-01` to Low is justified**,
on the armed `StableStakerV2.withdraw()` path, for an ERC4626-conformant vault, including the
multi-client topology.

**Evidentiary basis, stated exactly:** a complete 696 M-state integer search of the live semantics
with 210 M cap-binding states and zero counterexamples, plus 4 M random samples at realistic
magnitudes, plus 150 k fuzz runs and a 105-case grid against the real contracts in the real
two-client topology — all with live vacuity tripwires. **Not** a Halmos proof: the symbolic tier
returned no `[PASS]` at all (§3.2, §7.5). Anyone citing this document should cite that basis, not
"symbolically verified".

Two qualifications the report should carry forward:

- The `econ-scan.md` sentence *"there is no reachable state in which `previewExitFor`'s over-quote
  causes a silent under-delivery"* is true **only for the share-cap mechanism on the armed path**.
  Written unqualified it over-claims, because §7.2 and §7.3 are two other mechanisms by which the
  same function under-delivers, on the same path, that the guard does not intercept.
- The dominance is **contingent on two code invariants** (§6.1, §6.2) that no test currently pins.
  A future unpaired write to `clientBalances`/`totalDeposited`, or an exit path that skips the
  `a ≤ p` cap, re-arms both findings at Medium with no scanner signal. `DominanceRun17Grounding`
  is a runnable regression test for exactly that and should be kept.
