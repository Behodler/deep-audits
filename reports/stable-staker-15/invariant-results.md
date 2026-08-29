# Tier-3 Invariant Verification — stable-staker run-15

- **Submodule HEAD:** `2146428` (`[story-021] Polish: file the constructor aliasing guard as enforced…`)
- **Workspace:** `/home/justin/code/audits/workspace/stable-staker/` (never `lib/`)
- **Date:** 2026-08-29
- **Engines:** Foundry `forge 1.5.1-stable` (fuzz + invariant runners) and **Medusa `1.5.1`**. Echidna not needed (Medusa available).
- **Inputs read:** `reports/stable-staker-15/contract-profiles.md`, `reports/stable-staker-15/code-findings.md`

> **Honesty rule.** Every PASS below means *no counterexample was found within the stated run depth*.
> That is absence of evidence, not proof of safety. Only the two REFUTATIONS (INV-1 / CODE-001) are
> positive results, and they are positive because a **fixed, deterministic exhibit** reproduces the
> finding's own scenario against the real strategy and gets a different number — not because a fuzz
> campaign came back green.

---

## 0. Files produced

| Path | What |
|---|---|
| `workspace/stable-staker/test/invariant/Run15_MigrationProperties.t.sol` | Property/fuzz suite: INV-1…INV-6 + four fixed exhibits |
| `workspace/stable-staker/test/invariant/ReceivedDecrementERC4626Strategy.sol` | Hypothetical adapter for the CODE-004 arm (labelled, never used for a conclusion about deployed code) |
| `workspace/stable-staker/test/invariant/Run15Handler.sol` | Cheatcode-free, constructor-seeded stateful handler — driven by **both** engines |
| `workspace/stable-staker/test/invariant/Run15_Stateful.t.sol` | Foundry invariant contract A–F + `afterInvariant()` tripwire + deterministic reachability report |
| `workspace/stable-staker/medusa-run15.json` | Medusa config (target `Run15Handler`) |
| `workspace/stable-staker/medusa-run15-negctl.json` | Medusa **negative-control** config |
| `reports/stable-staker-15/tier3/forge-properties.log` | forge fuzz artifact |
| `reports/stable-staker-15/tier3/forge-invariants.log` | forge invariant artifact |
| `reports/stable-staker-15/tier3/medusa-run15.log`, `medusa-run15-1M.log` | Medusa artifacts |
| `reports/stable-staker-15/tier3/medusa-negctl.log` | Medusa negative-control artifact (engine proven able to fail) |
| `workspace/stable-staker/medusa-corpus-run15/` | Medusa corpus (`call_sequences/`, `coverage/`, `test_results/`) |

**Build note.** 24 stale audit-authored test files from run-14 still `import "../../src/StableStaker.sol"`,
which no longer exists at this HEAD (story-020 renamed it `StableStakerV2.sol`). They were moved to
`workspace/stable-staker/.audit-quarantine/` so the tree compiles. Nothing under `src/` was touched.

---

## 1. Strategy fidelity — which strategy each result ran against

The audit brief requires that no "safe"/"permanent" conclusion be drawn through an empty-bodied mock.

| Arm | Strategy actually used | Real code? |
|---|---|---|
| **INV-1, INV-3, INV-4, INV-5, INV-6, EXHIBITS A/B/D, stateful A–F, all Medusa properties** | `reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` on the real `AYieldStrategy` base, over `MockERC4626Vault` | **YES** — real `_withdrawInternal` (requested-amount write-down), real `_relinquishInternal` (pure write-down, no shares move), real `_disposeShares` (share-capped `vault.redeem`) |
| **INV-1 control arm, EXHIBIT C** | `test/mocks/MockYieldStrategy.sol` | Mock — used **only** to reproduce and label CODE-001's own number |
| **INV-2** | `ReceivedDecrementERC4626Strategy` (written for this run) | Deliberately hypothetical; identical share mechanics to `ERC4626YieldStrategy`, one rule inverted |

`MockYieldStrategy.relinquishPrincipalAsOwner`, `emergencyWithdraw`, `totalWithdrawal`,
`setSetAsideBuffer*` are empty stubs — **none of them is on any path this suite exercises**
(`initiateMigration` calls only `principalOf` / `withdraw` / `relinquishPrincipal`). The
`UnderRealizingStrategy` at `test/Migration.t.sol:845` is not used anywhere in this suite.

---

## 2. PRIMARY RESULT — CODE-001 is **REFUTED** for the deployed strategy family

### 2.1 The invariant, as generalised

> For any swept-buffer amount `S`, staked total `T` and strategy realisation ratio `r`, the payout
> ratio users receive after `initiateMigration` is never worse than the ratio they would receive if
> `booked` had been **withdrawn** rather than written off.

The counterfactual arm is **executed, not computed**: the same scenario is replayed on a second
deployment where `AYieldStrategy.withdrawAsOwner(staker, staker, booked)` realises the excess into
the staker's balance *before* `initiateMigration`. That is an upper bound on CODE-001's own proposed
mitigation ("`strategy.withdraw(token, booked, address(this))` first, then relinquish").

**Result: PASS.** `payoutB − payoutA ≤ 2 wei` over the entire fuzzed domain — the 1–2 wei being
ERC4626 floor-division on a two-leg vs one-leg redeem, protocol-neutral dust.

```
forge test --match-contract Run15MigrationProperties --fuzz-runs 5000 --fuzz-seed 15
  [PASS] testFuzz_INV1_selfHealNeverWorseThanRealiseFirst   (runs: 5000)
  [PASS] testFuzz_INV1_tripwire_harmWindow                   (runs: 5000)
```
Fuzz domain: `T ∈ [1e6, 1e15]`, `S ∈ [0, 3T]` (covers `S = 0` and `S > T`),
`L ∈ [0, S+T]` ⇒ `r ∈ [0, 1]` including both endpoints. The tripwire arm additionally forces
`S ≥ 1e6` and `L > S`, i.e. the exact window CODE-001 describes.

### 2.2 Why CODE-001's number does not reproduce

`AYieldStrategy`'s concretes do **not** haircut a withdrawal proportionally. `_disposeShares`
computes `vault.convertToShares(amount)` and **caps that to the strategy's share balance**. The
swept buffer's *shares are still in that balance*, so a below-par exit of `P` consumes them and the
buffer softens the migration **through the strategy leg**, before D4 ever measures a balance.

`MockYieldStrategy.withdraw` instead pays `amount * valueFactorBps / 10000` with **no share cap**.
That single divergence is the whole of CODE-001's 45,000 USDC.

**EXHIBIT A** — CODE-001's own inputs (`S = 50,000`, `T = 1,000,000`, strategy at 90% of par) on the
real `ERC4626YieldStrategy`:

```
R (real ERC4626YieldStrategy): 945000.000000
P:                             1000000.000000
protocol-owned residue left in the strategy: 0.000000
```

`R = 945,000` is **exactly the counterfactual CODE-001 names** ("`R = 945,000`, users paid 94.5%").
The shipped code already delivers it. **EXHIBIT C** reruns the same inputs on `MockYieldStrategy`
and reproduces the finding's `R = 900,000`, isolating the divergence to the mock.

### 2.3 The corollary the fuzzer actually proved

```
if (P - R > 2) assertEq(residualInStrategy, 0)
```
holds over 5,000 runs: **a materially below-par exit is share-capped, therefore it has already
consumed every share, therefore there is nothing left for a "withdraw before relinquish" mitigation
to realise.** The self-heal is then writing off principal that is genuinely unbacked.
Conversely when the exit is *not* share-capped, users are paid at par and the residue that survives
is protocol surplus above par (**EXHIBIT B**: 140,000 of protocol capital on a 5% loss with a
200,000 buffer), which the "stakers get principal + phUSD only" invariant says is not theirs.

### 2.4 Recommended disposition for CODE-001

- The **Medium rating and the 45,000-USDC stranded-value claim do not survive**. They are an
  artifact of `MockYieldStrategy`'s non-share-capped `withdraw`, not of `StableStakerV2`.
- What remains true is narrower and is already CODE-004's territory: *under a custody adapter whose
  realisation is proportional-without-share-cap*, relinquishing `booked` forfeits value the balance
  measurement would otherwise have counted. Neither `ERC4626YieldStrategy` nor
  `ERC4626MarketYieldStrategy` (top-level `lib/reflax-yield-vault` HEAD) is such an adapter — both
  share the identical `convertToShares → cap to available shares` prologue.
- The proposed mitigation is **not free** in a multi-client strategy: see §5.
- The existing PoC `test/poc/Run15_CodeScan.t.sol::test_selfHeal_destroys_the_buffer_D4_was_meant_to_spend`
  passes only because it uses the mock; it should carry that caveat or be re-based on a real strategy.

---

## 3. Results table

| # | Invariant | Verdict | Engine / command | Depth | Artifact |
|---|---|---|---|---|---|
| **INV-1** | Self-heal payout ≥ realise-first payout (CODE-001 generalised), real `ERC4626YieldStrategy` | **PASS → CODE-001 REFUTED** | `forge test --match-contract Run15MigrationProperties --fuzz-runs 5000 --fuzz-seed 15` | 5,000 runs | `tier3/forge-properties.log` |
| **INV-1t** | Same, bounds forced into the harm window (`S>0`, `L>S`, so `booked>0 ∧ R<P` every run) | **PASS** | idem | 5,000 runs | idem |
| **INV-1c** | Control: the same scenario under `MockYieldStrategy` yields `R = P·r` exactly | **PASS** (documents the mock's semantics) | idem | 5,000 runs | idem |
| **INV-2** | Hypothetical received-decrement adapter changes the meaning of `booked` (CODE-004 residual) | **PASS — CODE-004 residual CONFIRMED as stated** | idem | 5,000 runs | idem |
| **INV-3** | `batchMigrate` slice-order / slice-size independence, and batch ≡ `userMigrate` | **PASS** | idem | 5,000 runs | idem |
| **INV-4** | Donation `D` never lowers a payout, never exceeds par, donor cannot extract | **PASS** | idem | 5,000 runs | idem |
| **INV-5** | No-brick: drain → `finalizeAndReset` → re-wire → re-stake always available | **PASS** | idem | 5,000 runs | idem |
| **INV-6** | Conservation: credits paid ≤ `R`, staker balance delta == credits, ≤ 1 wei dust/user | **PASS** | idem | 5,000 runs | idem |
| **INV-A** | `totalStaked == Σ userInfo.amount` at all times | **PASS** | `FOUNDRY_INVARIANT_RUNS=512 FOUNDRY_INVARIANT_DEPTH=500 forge test --match-contract Run15StatefulInvariants --fuzz-seed 15` | 512 runs × 500 calls = **256,000 calls** | `tier3/forge-invariants.log` |
| **INV-B** | While `Migrating`, idle balance ≥ Σ remaining snapshot credits | **PASS** | idem | 256,000 calls | idem |
| **INV-C** | `R ≤ P` always | **PASS** | idem | 256,000 calls | idem |
| **INV-D** | Aggregate paid out ≤ aggregate migrated principal (donations not extractable) | **PASS** | idem | 256,000 calls | idem |
| **INV-E** | `stakerCount == 0 ⟺ totalStaked == 0` (the `finalizeAndReset` dual gate is always satisfiable) | **PASS** | idem | 256,000 calls | idem |
| **INV-F** | Self-heal always clears `booked`; strategy always decoupled while `Migrating` | **PASS** | idem | 256,000 calls | idem |
| **MED-A…G** | Same seven properties, Medusa | **PASS** | `medusa fuzz --config medusa-run15.json` | see §4 | `tier3/medusa-run15*.log` + `medusa-corpus-run15/` |
| **NEGCTL** | Deliberately-false property, to prove Medusa reports failures | **FAILED as designed** (exit 7) | `medusa fuzz --config medusa-run15-negctl.json` | 2,000 | `tier3/medusa-negctl.log` |

---

## 4. Medusa runs

```
cd /home/justin/code/audits/workspace/stable-staker
medusa fuzz --config medusa-run15.json
```
- target: `Run15Handler`; workers 6; `callSequenceLength` 100; assertion **and** property testing on
  (`testPrefixes: ["property_"]`); `blockTimestampDelayMax` 86400 so time really advances.
- **Run 1 (`testLimit` 200,000):** `calls: 200,244`, `seq: 1,999`, `branches: 3,490`, `corpus: 75`,
  **43 tests passed / 0 failed** — `tier3/medusa-run15.log`.
- **Run 2 (`testLimit` 1,000,000):** see `tier3/medusa-run15-1M.log` (§4.1).
- Corpus on disk: `workspace/stable-staker/medusa-corpus-run15/` — 75 `call_sequences/*.json`,
  `coverage/coverage_report.html`, `coverage/lcov.info`, `test_results/`.

### 4.1 Long run

```
medusa fuzz --config medusa-run15.json      # testLimit 1,000,000
fuzz: elapsed: 3m51s, calls: 1,000,278 (4,982/sec), seq/s: 49, branches: 3,527,
      corpus: 80, failures: 0/10,048
Test summary: 43 test(s) passed, 0 test(s) failed
```
All seven `property_*` tests and every auto-derived assertion test passed over **1,000,278 calls /
10,048 sequences**. Corpus and coverage artifacts: `workspace/stable-staker/medusa-corpus-run15/`
(`call_sequences/` — 80 JSON sequences, `coverage/coverage_report.html`, `coverage/lcov.info`).

Echidna was not run: Medusa is the designated primary and was available, so the fallback was not needed.

---

## 5. Secondary results and observations

### 5.1 INV-2 — CODE-004's residual is CONFIRMED, exactly as written

Against `ReceivedDecrementERC4626Strategy` (identical share mechanics, principal decremented by
**received** instead of **requested**) with **no swept buffer at all** (`S = 0`), every fuzz run
reaches `R < P` and:

- `booked` after `_routeExit` is **pure user shortfall**, not sweep surplus;
- the self-heal relinquishes it, so `strategy.principalOf(...) == 0`;
- the `"incomplete exit"` post-check is therefore **satisfied by construction**;
- the pool latches `Migrating` with `R` collapsed to whatever landed and **no floor of any kind**.

This is precisely the residual CODE-004 describes, and it is the reason
`AYieldStrategy._withdrawInternal`'s "decrement by the REQUESTED (capped) amount — shortfall accrues
as yield" rule (`lib/reflax-yield-vault/src/AYieldStrategy.sol:747`) is load-bearing rather than
incidental. CODE-004's proposed mitigation (keep `_routeExit`'s return value and require
`booked == 0 || received + booked >= P`) is the right shape and should be kept **independently of
CODE-001's disposition** — it is what stops a future adapter from silently deleting the floor.

### 5.2 Cross-repo observation (EXHIBIT D) — the share cap is *global*, not per client

`_disposeShares` caps at `vault.balanceOf(address(this))` — the strategy's **total** share balance
across every authorized client, not the withdrawing client's pro-rata slice. With a sibling client
holding 1,000,000 alongside the staker's 1,000,000 and a 40% loss on the combined position:

```
sibling client value before: 600000.000000
sibling client value after : 200000.000001
```
The staker exits **at par** and the entire realised loss lands on the sibling. Two consequences worth
recording:

1. This is a `reflax-yield-vault` property (`AYieldStrategy` concretes), not a `StableStakerV2`
   defect. **Closed 2026-08-29 by the owner as INTENDED DESIGN, not a finding** (route `T3-03`): the
   sibling clients on these vaults are phUSD minters that **mint without redeeming**, so the global
   cap is the deliberate cushion that lets stable-staker meet user stake obligations at par. The
   arithmetic above is unchanged and the multi-client precondition is confirmed on mainnet — only the
   reading of it changed. **It must not be "fixed" into a per-client cap**: that would break the
   cushion. Any change to its cap semantics still requires re-running INV-1, as a departure from
   intent rather than a remedy.
2. **CODE-001's proposed mitigation is not free.** In a multi-client strategy, "withdraw `booked`
   before relinquishing it" pulls *additional* shares out of a pool that also backs siblings. On a
   single-client strategy it is a no-op (INV-1); on a multi-client one it is a transfer from the
   siblings to this staker's users. Neither is the "recover stranded value" the finding assumes.

### 5.3 What did **not** move

- **Slice ordering (INV-3)** — one batch of three, fuzzed-size reversed batches, and all-self-migrate
  produce **bit-identical** per-user credits across 5,000 runs with odd principals and below-par `R`.
  The immutable `(R, P)` snapshot does what the profile claims.
- **Donation (INV-4)** — 5,000 runs over `D ∈ [0, 5T]`: a donation never lowered a payout, never
  pushed a payout above par, the donor never recovered a wei, and `userMigrate` reverts for a
  non-staker. Consistent with the run-15 H3 refutation; **no new unlock found**.
- **No-brick (INV-5 / INV-E)** — every reachable `Migrating` state drained via `userMigrate` +
  `batchMigrate`, satisfied the `finalizeAndReset` dual gate, revived to `Active`, accepted a new
  strategy and a new stake. The stateful campaign restarted the epoch repeatedly
  (`g_finalized > 0` in the reachability report).
- **Conservation (INV-6 / INV-A / INV-B / INV-D)** — no path through `initiateMigration`,
  `batchMigrate`, `userMigrate` or `finalizeAndReset` created or destroyed value beyond
  floor-division dust (≤ 1 wei per user, protocol-favouring).

---

## 6. Anti-vacuousness — tripwire outcomes (reported explicitly)

**Tripwire result: ALL GREEN, and demonstrably able to go red.**

| Tripwire | Where | Outcome |
|---|---|---|
| `afterInvariant()` coverage gate (stakes, ≥1 migration, `booked > 0` seen, ≥1 below-par migration, credits paid, an exit path used, phUSD minted) | `Run15_Stateful.t.sol` | **PASSED** on the final campaign. **It FAILED the first campaign** — `TRIPWIRE: no phUSD was ever minted: 0 <= 0` — because the Foundry invariant runner never advances `block.timestamp`; a `warpTime` entry point was added and the seed now accrues 3 days before the seeded exit. This is direct evidence the gate is not decorative. |
| Constructor `require`s: sweep booked == 50,000; migration begun; `R < P`; batch exit paid > 0; phUSD minted (when a cheatcode host is present) | `Run15Handler` constructor | **PASSED.** Under Medusa these are the deployment-time tripwire: the target contract cannot deploy unless the guarded state was reached, and a deployment failure is reported before any fuzzing. |
| `property_G_seedSurvives()` | `Run15Handler` | **PASSED** in both Medusa runs — the guarded state is still asserted-reached at the end. |
| Per-run asserts inside the property suite (`booked > 0`, `R < P`, `bookedBefore == S+T`, `credits > 0`, `poolState == Migrating`) | `Run15_MigrationProperties.t.sol` | **PASSED** at 5,000 runs each. Two of them **fired during development** (`TRIPWIRE: mock booked nothing` — I was reading `principalOf` *after* the self-heal had zeroed it; `TRIPWIRE: no credits were paid at all` — `r → 0` made every credit zero), and both were fixed by correcting the harness, not by weakening the assert. |
| `INV-1` corollary | `Run15_MigrationProperties.t.sol` | **FIRED** during development (`a below-par exit leaves no realisable residue: 2076853718581033 > 1`), which is how the 1–2 wei redeem-dust band was identified and bounded rather than papered over. |
| Medusa **negative control** `negctl_alwaysFalse()` | `medusa-run15-negctl.json` | **FAILED as designed**, exit code 7, with a shrunk call sequence and execution trace — proving the Medusa configuration actually reports property failures rather than exiting green on a misconfiguration. |

No invariant in this suite can pass `0 == 0`: every one of them reads live pool state that the
constructor has already driven into a below-par migration with `booked > 0`.

---

## 7. Findings raised by this campaign

| ID | Statement | Severity | Status |
|---|---|---|---|
| **T3-01** | **CODE-001 does not reproduce against the deployed strategy family.** Its stranded-value figure is an artifact of `MockYieldStrategy.withdraw`'s missing share cap. On the real `ERC4626YieldStrategy`, CODE-001's own inputs already yield the counterfactual it asks for (`R = 945,000`). | — (refutation) | Recommend CODE-001 be **withdrawn or re-scoped to the CODE-004 adapter caveat**, with its PoC re-based on a real strategy. |
| **T3-02** | CODE-004's residual is real and reproducible under an adapter that writes principal down by *received*: the `"incomplete exit"` tripwire is then satisfied by construction and terminal migration proceeds with **no floor on `R`**. | Low (as filed) | **Confirmed.** Keep the mitigation regardless of T3-01. |
| **T3-03** | `AYieldStrategy` concretes cap share disposal at the strategy's **total** share balance, so one client's below-par exit can be satisfied out of a sibling client's backing (EXHIBIT D: sibling 600,000 → 200,000 while the staker exits at par). | Observation | **Cross-repo** — belongs to `reflax-yield-vault`, not `stable-staker`. Also means CODE-001's mitigation would be a transfer *from* siblings, not a recovery of stranded value. |

No failing invariant, and therefore **no new High** from this tier.

---

## 8. Reproduction

```bash
cd /home/justin/code/audits/workspace/stable-staker

# property suite (INV-1..INV-6 + exhibits)
forge test --match-contract Run15MigrationProperties --fuzz-runs 5000 --fuzz-seed 15 -vv

# the single decisive exhibit
forge test --match-test test_EXHIBIT_A_code001_scenario_on_real_erc4626_strategy -vv
forge test --match-test test_EXHIBIT_C_mockProducesTheCode001Number -vv

# stateful invariants A-F + reachability report
FOUNDRY_INVARIANT_RUNS=512 FOUNDRY_INVARIANT_DEPTH=500 \
  forge test --match-contract Run15StatefulInvariants --fuzz-seed 15 -vv

# Medusa (primary stateful fuzzer)
medusa fuzz --config medusa-run15.json
# engine sanity: must FAIL
medusa fuzz --config medusa-run15-negctl.json
```

**Caveat on scope of the refutation.** INV-1 is proven against the two concrete strategies present at
the top-level `lib/reflax-yield-vault` HEAD. It is *not* a statement about an arbitrary future
`IYieldStrategy`; INV-2 shows exactly what breaks when the base's write-down rule is changed. If a new
concrete strategy lands, INV-1 must be re-run against it before CODE-001's refutation is carried over.
