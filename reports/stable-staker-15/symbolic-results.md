# Symbolic Verification (Halmos) — stable-staker run-15

- **Project:** stable-staker · **HEAD:** `2146428bdd9adb1fbaf1c1feaa4fbf36133e5506` · **Branch:** `master`
- **Workspace:** `/home/justin/code/audits/workspace/stable-staker` (synced to `2146428`)
- **Tool:** Halmos **0.3.3** · forge 1.5.1-stable · solc 0.8.28
- **Solver:** **yices** (Halmos default, `yices-2.6.5`) unless stated. `z3` was also tried on the hard
  goals. `cvc5-int` and `bitwuzla` are **unavailable offline** — Halmos attempts to download them and
  the sandbox refuses (`RuntimeError('Download not allowed')`); that is recorded below as **ERROR**,
  which is *not* a result.
- **Test sources:** `workspace/stable-staker/test/symbolic/Run15_*.t.sol` + `SymParStrategy.sol`.
  Nothing under `test/invariant/` (the concurrent fuzz agent's area) was read from or written to.
- **Artifacts:** `reports/stable-staker-15/tier3/symbolic/`

> **Reading rule.** Only **[PASS]** is a proof, and only over the domain stated in its row.
> **[TIMEOUT]** and **[ERROR]** prove **nothing** and must never be cited as evidence of safety.

---

## 1. Per-property results

| # | Property | Verdict | Bound / domain proven under | Command | Artifact | Generality test |
|---|---|---|---|---|---|---|
| **1(a)** | Σ credits ≤ R (2 and 3 users) | **TIMEOUT** — *unverified, prove nothing* | attempted at 2^128, 2^64, 2^32, `uint64`/`uint32` params, fixed `P`, and a division-free axiomatization | see §2 | `halmos_tierA_unbounded.log`, `halmos_p1_axiom.log`, `halmos_p1_snapshots.log`, `halmos_p1_snapshot_under25_long.log` | n/a |
| **1(a′)** | Σ credits ≤ R **and** dust bound, all 2-user splits, at a **fixed snapshot** | **PASS** (2 of 6 snapshots) | `(P,R) = (3,2)` and `(P,R) = (400e6, 0)`; `p1` symbolic over full `uint256`; **N = 2 users** | `halmos --contract Run15CreditSnapshots --solver-timeout-assertion 45000 --statistics` | `halmos_p1_snapshots.log` | **Fails** — proves the arithmetic, not the safety |
| **1(a″)** | same, at realistic magnitudes (`P=400e6, R=300e6`; `P=999999999, R=333333333`; par; above-par) | **TIMEOUT** at 45 s and again at **480 s** | — | `halmos --contract Run15CreditSnapshots --function check_p1a_UNDER25 --solver-timeout-assertion 480000` | `halmos_p1_snapshot_under25_long.log` | n/a |
| **1(b)** | no individual credit exceeds `p_i` | **PASS** at 4 of 6 fixed snapshots; **TIMEOUT** fully symbolic | `p` symbolic over full `uint256` (assumed `≤ P`), at `(P,R)` = `(400e6,300e6)`, `(999999999,333333333)`, `(3,2)`, `(400e6,0)`. **TIMEOUT** at `R = P` and `R > P`. | `halmos --contract Run15CreditSnapshots --solver-timeout-assertion 45000 --statistics` | `halmos_p1_snapshots.log` | **Fails** — proves the arithmetic |
| **1(c)** | a donor of `D` cannot lift their own credit by more than `D`; donation is monotone | **TIMEOUT** — *unverified* | attempted at 2^127 and in the division-free axiomatization | `halmos --contract Run15CreditSymbolic --solver-timeout-assertion 120000 --statistics` | `halmos_tierA_unbounded.log`, `halmos_p1_axiom.log` | n/a |
| **1 (dust direction)** | paid total ≤ `min(R,P)` and short of it by ≤ 1 wei (N=2) | **PASS** at `(3,2)` and `(400e6,0)`; **TIMEOUT** elsewhere | as 1(a′) | as 1(a′) | `halmos_p1_snapshots.log` | **Fails** — proves the arithmetic |
| **2** | self-heal bound: `initiateMigration` clears the strategy books and the write-down is **exactly** the protocol excess above `totalStaked` — never user-backed principal | **PASS** | Real `StableStakerV2` bytecode. `p ∈ (0, 2^96)`, `excess ∈ [0, 2^96)`, both symbolic. **1 user, 1 token, 1 migration.** Strategy = `SymParStrategy` model (see §3). | `halmos --contract Run15Migration2Symbolic --solver-timeout-assertion 300000 --statistics` | `halmos_tierB_final.log` | **Passes** — a false implementation fails it |
| **2b** | same, with an **arbitrary absolute shortfall** on the strategy exit; `R` must equal the liquid position capped at par | **PASS** | as above, plus `cut ∈ [0, 2^96)` symbolic | same | `halmos_tierB_final.log` | **Passes** |
| **2c** | `booked` after the exit == `max(0, clientBalances − totalStaked)`, and the post-check clears | **PASS** | as 2b | same | `halmos_tierB_final.log` | **Passes** |
| **3** | per-user credits are independent of slice order, slice size and batch-vs-self method | **PASS** | Real bytecode, **two** `StableStakerV2` instances, **N = 2 users**, `p1,p2 ∈ (0, 2^80)`, shortfall `∈ [0, 2^80)`, all symbolic. Compares `batchMigrate([a,b])` against `userMigrate(a)` then `batchMigrate([b])`. | `halmos --contract Run15Migration2Symbolic --function check_p3 --solver-timeout-assertion 300000` | `halmos_p3.log`, `halmos_tierB_final.log` | **Passes** (weakly — see §4) |
| **4** | codeless-address fail-open (DEDUP-15-03) | **NOT SYMBOLIC** — exhaustive concrete case analysis, 6/6 PASS | — | `forge test --match-contract Run15ProbeCases -vv` | `forge_concrete_sanity.log` | n/a — it is a characterization, not a proof |

**Negative controls (guard against vacuous PASSes): both [FAIL] with concrete counterexamples**, which
is the intended outcome — it proves the Tier-B harness actually reaches the asserted post-migration
state instead of passing on all-reverting paths.

| Control | Verdict | Counterexample |
|---|---|---|
| `check_negctl_mustFail` (asserts `P != p`, false by construction) | **[FAIL]** ✓ | `p = 0x800000000000000000000000`, `excess = 0x800…` and `excess = 0` |
| `check_negctlP3_mustFail` (asserts both credits are 0 at par, false) | **[FAIL]** ✓ | reported in `halmos_negctl_p3.log` |

Additionally, every Tier-B harness has a **concrete driver** (`Run15_Sanity.t.sol`,
`Run15_Sanity2.t.sol`) that executes the same body with literal values and passes under `forge test`.

---

## 2. The central negative result: symbolic 256-bit `DIV` is intractable here

**Property 1 is intractable in its general form, and that was established rather than assumed.** The
credit formula `(amt * min(R,P)) / P` (`StableStakerV2._exitPosition:583-585`) was attacked in **seven**
encodings. Every one that leaves **two or more symbolic divisions** in the goal timed out, on both
solvers, at every input bound:

| Encoding | File | Result |
|---|---|---|
| Full `uint256`, bounded 2^127 / 2^128 by `vm.assume` | `Run15_Credit.t.sol` | **6/6 TIMEOUT** @120 s (yices) |
| Same, bounded 2^64 | `Run15_CreditBounded64.t.sol` | TIMEOUT @90 s (yices **and** z3) |
| Same, bounded 2^32 | `Run15_CreditBounded32.t.sol` | TIMEOUT @120 s |
| `uint64` parameters (64-bit symbols) | `Run15_CreditNarrow.t.sol` | TIMEOUT @120 s |
| `uint32` parameters | `Run15_CreditNarrow32.t.sol` | TIMEOUT @150 s (yices **and** z3) |
| Concrete denominator `P`, symbolic `R` | `Run15_CreditFixedP.t.sol` | TIMEOUT @120 s |
| Division-free axiomatization (`c*P ≤ p*S < c*P + P`) | `Run15_CreditAxiom.t.sol` | TIMEOUT @300 s and @240 s |
| **Concrete `(R,P)`, symbolic `p` — one division by a constant** | `Run15_CreditSnapshots.t.sol` | **PASS in 0.1–1.5 s** for the single-division goals |
| Concrete `(R,P)`, **two** divisions by the same constant (the 2-user sum) | `Run15_CreditSnapshots.t.sol` | TIMEOUT — even at **480 s** |

The cost tracks the **number of symbolic divisions in the goal**, not the magnitude of the inputs.
That has a direct methodological consequence worth recording: **`vm.assume` input bounding — the
standard Halmos timeout remedy — does not help for this class at all**, and no amount of it would
have. Narrowing to `uint32` did not help either. The eliminated-division rewrite is what works.

Consequently property 1 is **reported as intractable**, with the narrow fixed-snapshot PASSes offered
as exactly what they are, rather than being weakened into something vacuous that would PASS.

### What the fixed-snapshot PASSes do and do not say

`check_p1b_UNDER25` **[PASS]** is a genuine proof that *for every one of the 2^256 possible per-user
principals `p ≤ 400e6`, the credit paid at the snapshot `(P=400e6, R=300e6)` never exceeds `p`.* It is
**not** a proof for other snapshots — and notably the par (`R = P`) and above-par (`R > P`) snapshots
**timed out**, so the two cases an operator would consider most routine are precisely the two this run
could not decide. `(P,R) = (400e6, 0)` passes trivially (all credits are 0) and carries almost no
information; it is listed for completeness, not as evidence.

---

## 3. What property 2 was proven against (read before citing it)

The Tier-B proofs execute the **real `StableStakerV2` bytecode**, but the yield strategy is
`test/symbolic/SymParStrategy.sol`, a model — because `MockYieldStrategy` computes its payout as
`amount * valueFactorBps / 10000`, and **that one symbolic division alone made the property
undecidable**: the first attempt, against `MockYieldStrategy`, is `halmos_p2_mockstrategy_TIMEOUT.log`
(**TIMEOUT**, 38 paths, 300 s of solver time). `SymParStrategy` reproduces the two `AYieldStrategy`
behaviours the property depends on, verbatim:

- `_withdrawInternal:739-750` — cap the request to `clientBalances`, then debit **by the requested
  (capped) amount**, never by what was delivered;
- `_relinquishInternal:667-683` — cap to available, debit, move **no** shares.

and models the below-par delivery as a free **absolute** shortfall rather than a bps factor, which is
**strictly more general** than the real strategy's behaviour (every below-par delivery a bps factor can
produce is one of these, and so are ones it cannot).

**The residual gap is honest and must be stated wherever this result is used:** this is a proof about
`StableStakerV2` composed with a *faithful model* of the strategy's principal accounting, not about
`ERC4626YieldStrategy`'s bytecode. It is strong evidence that the self-heal cannot reach user-backed
principal, and it is a proof *conditional on the strategy debiting by the requested amount*. If a
future strategy debits by the **received** amount, the premise is gone and this result says nothing —
which is exactly the leg the sanitizer already parked as `MR-15-S1`.

---

## 4. Generality test, applied explicitly

- **Property 1 (all legs) — FAILS the generality test.** `floor(p·S/P) ≤ p` for `S ≤ P`, and
  `Σ floor(p_i·S/P) ≤ S`, hold for *any* implementation that computes a floored pro-rata against a
  denominator equal to the sum of the parts. These PASSes prove **the mathematics of the formula, not
  the safety of the contract**. Their security content comes entirely from facts established by
  *reading*, not by Halmos: that `P` is the immutable snapshot, that `S = min(R,P)`, and that
  `Σ p_i == P` is maintained by `totalStaked`. **Nothing in §1 rows 1(a′)/1(b)/dust should be filed as
  a finding or cited as a safety proof.** (Standing rule from the antimatter am3m7 reversal.)
- **Property 2 — PASSES the generality test.** It is not an identity: an implementation that read
  `principalOf` *before* the exit, or relinquished a fixed amount, or debited by the delivered amount,
  would fail `check_p2c`. It is a statement about this code's specific ordering.
- **Property 3 — PASSES, but weakly.** The two execution paths produce syntactically identical credit
  terms, so Halmos discharges the equality by simplification with **zero solver queries**
  (`models: 0.00s`). That is a real proof of term-identity, and term-identity is exactly the
  order-independence claim — but it would also hold for any implementation that divides by a stored
  constant, so its discriminating power is limited. Its value is that it is proven **on the real
  bytecode over symbolic principals**, which the run's fuzzing sampled rather than proved.
- **Property 4 — not a proof at all.** Six concrete cases, exhaustive over the *decision structure* of
  the two probes but not over returndata. Reported as characterization.

### Property 4 — the exact fail-open condition (case analysis)

`_isRegisteredOn` returns `true` when `!ok || data.length < 64`; `_migratorOf` returns
`probed == false` when `!ok || data.length < 32`. **Both gates therefore pass vacuously** whenever the
destination is:

1. **a codeless address** (EOA, or a not-yet-deployed CREATE2 target) — `staticcall` to an
   account with no code returns `ok = true` with **0 bytes**, so both probes fail open and
   `versionOf` additionally reports `1`. *(`test_p4_case1`)*
2. **a contract that reverts on both getters** *(`test_p4_case2`)*;
3. **a contract answering with short returndata** — ≤63 bytes for `getStakedTokens()` **and**
   ≤31 bytes for `migrator()` *(`test_p4_case3`)*.

Two boundaries are worth recording because they are *not* fail-open:

4. **The asymmetric band, 32–63 bytes** from `getStakedTokens()`: registration still fails open, but
   `migrator()` **is** decoded, so gate 2 becomes live and hard-reverts on a mismatch *(`test_p4_case4`)*.
5. **A genuinely empty registry** ABI-encodes to exactly 64 bytes, is decoded honestly, and correctly
   hard-reverts — the documented non-fail-open case *(`test_p4_case5`)*.

**Consequence, demonstrated:** in case 1 the pre-flight passes, `initiateMigration` opens the one-way
door on the **source** staker, and `migrate` then reverts at the first `depositFor`, stranding the pool
in `Migrating` against a destination that cannot receive. Users are **not** trapped — `userMigrate`
still pays them out at par into their own wallets *(`test_p4_case6`)*. This is a concrete
demonstration of DEDUP-15-03's mechanism and its blast radius; it does not change the finding's
severity on its own.

---

## 5. Machine-readable summary

```json
{
  "project": "stable-staker",
  "commit": "2146428bdd9adb1fbaf1c1feaa4fbf36133e5506",
  "tool": "halmos", "toolVersion": "0.3.3", "solver": "yices-2.6.5 (z3 cross-checked)",
  "proofs": [
    {"testName": "check_p2_selfHealNeverEatsUserPrincipal", "result": "PASS",
     "property": "initiateMigration clears the strategy books and R == P; the write-down is exactly the protocol excess",
     "domain": "real StableStakerV2 bytecode; p in (0,2^96), excess in [0,2^96); 1 user, 1 token, 1 migration; strategy = SymParStrategy model of AYieldStrategy principal accounting"},
    {"testName": "check_p2b_selfHealUnderwater", "result": "PASS",
     "property": "same under an arbitrary absolute exit shortfall; R == min(held, P)",
     "domain": "as above plus cut in [0,2^96)"},
    {"testName": "check_p2c_bookedIsAtMostProtocolExcess", "result": "PASS",
     "property": "booked == max(0, clientBalances - totalStaked); post-check clears",
     "domain": "as p2b"},
    {"testName": "check_p3_orderAndMethodIndependence", "result": "PASS",
     "property": "per-user credits are identical across slice order, slice size and batch-vs-self method",
     "domain": "real bytecode, 2 stakers, N=2 users, p1,p2 in (0,2^80), shortfall in [0,2^80); discharged by term-identity, 0 solver queries"},
    {"testName": "check_p1b_UNDER25 / _UNDER_ODD / _WEI / _ZERO", "result": "PASS",
     "property": "credit(p) <= p — ARITHMETIC IDENTITY, not a safety proof",
     "domain": "p symbolic over uint256 (p <= P) at fixed (P,R) = (400e6,300e6), (999999999,333333333), (3,2), (400e6,0)"},
    {"testName": "check_p1a_WEI / _ZERO", "result": "PASS",
     "property": "sum of 2-user credits <= R and dust shortfall <= 1 wei — ARITHMETIC IDENTITY",
     "domain": "all 2-user splits at (P,R) = (3,2) and (400e6,0) only"}
  ],
  "unverified": [
    {"testName": "check_p1a_sumCreditsLeqR_2users / _3users", "result": "TIMEOUT",
     "note": "NOT proven safe. Two+ symbolic 256-bit divisions; timed out in 7 encodings incl. 2^32 bounds, uint32 params, and a division-free axiomatization. Needs a solver with nonlinear integer arithmetic (cvc5-int/bitwuzla, unavailable offline) or a hand proof."},
    {"testName": "check_p1a_PAR / _UNDER25 / _UNDER_ODD / _ABOVE", "result": "TIMEOUT",
     "note": "NOT proven safe. Fixed snapshot, 2 divisions by a constant; still TIMEOUT at 480s."},
    {"testName": "check_p1b_PAR / _ABOVE", "result": "TIMEOUT",
     "note": "NOT proven safe. The par and above-par snapshots specifically could not be decided."},
    {"testName": "check_p1c_donorCannotProfit / donationIsMonotone", "result": "TIMEOUT",
     "note": "NOT proven safe. Donor bound is unverified in every encoding attempted."},
    {"testName": "check_p1_dustFavoursProtocol_2users (general)", "result": "TIMEOUT",
     "note": "NOT proven safe outside the two trivial snapshots."},
    {"testName": "check_p2_selfHeal (vs MockYieldStrategy)", "result": "TIMEOUT",
     "note": "Superseded by the division-free SymParStrategy PASS; recorded because the timeout is the evidence that the bps division, not the property, was the obstacle."},
    {"testName": "cvc5-int / bitwuzla runs", "result": "ERROR",
     "note": "Solver binaries not downloadable in this sandbox. No property was tested by these."}
  ],
  "findings": []
}
```

**No finding is raised by this stage.** No counterexample was found on any property; the only `[FAIL]`
results are the two deliberate negative controls.

---

## 6. Files written

| Path | What |
|---|---|
| `workspace/stable-staker/test/symbolic/Run15_Credit.t.sol` | Tier-A literal credit model (all TIMEOUT) |
| `…/Run15_CreditBounded64.t.sol`, `…Bounded32`, `…Narrow`, `…Narrow32`, `…FixedP`, `…FixedRP` | the bounding/narrowing ladder that establishes §2 |
| `…/Run15_CreditAxiom.t.sol` | division-free axiomatization (TIMEOUT) |
| `…/Run15_CreditSnapshots.t.sol` | fixed-snapshot family (6 PASS / 6 TIMEOUT) |
| `…/SymParStrategy.sol` | division-free faithful model of `AYieldStrategy` principal accounting |
| `…/Run15_Migration2.t.sol` | **Tier-B properties 2, 2b, 2c, 3 + both negative controls** |
| `…/Run15_Migration.t.sol` | first Tier-B attempt vs `MockYieldStrategy` (TIMEOUT; kept as evidence) |
| `…/Run15_ProbeCases.t.sol` | property-4 case enumeration |
| `…/Run15_Sanity.t.sol`, `…/Run15_Sanity2.t.sol` | concrete non-vacuity drivers |
| `reports/stable-staker-15/tier3/symbolic/*.log` | every raw Halmos/forge run cited above |

**Note for anyone re-running:** Halmos needs AST-bearing artifacts. A plain `forge build` or
`forge test` in between strips them and Halmos then reports `No tests with --match-contract …`, which
looks like a missing test rather than a build problem. Recover with `forge build --ast --force`.
