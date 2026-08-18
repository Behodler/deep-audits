# Tier-3 Invariant Results — antimatter

- **Project**: `antimatter` @ `0bb82d867dba43bc514a508800826f90436c2ee3` (read from `lib/antimatter`, harness built in `workspace/antimatter`)
- **Run date**: 2026-08-18
- **Harness** (workspace, writable):
  - `/home/justin/code/audits/workspace/antimatter/test/audit/invariant/AntimatterInvariant.t.sol` — Foundry invariant contract + deterministic counterexamples
  - `/home/justin/code/audits/workspace/antimatter/test/audit/invariant/AntimatterHandler.sol` — stateful handler + ghosts
  - `/home/justin/code/audits/workspace/antimatter/test/audit/invariant/AuditMocks.sol` — `GuardedYieldStrategy`
  - `/home/justin/code/audits/workspace/antimatter/test/audit/invariant/MedusaTarget.sol` — self-deploying Medusa assertion target
  - `/home/justin/code/audits/workspace/antimatter/medusa.json`
- **Engines**: Foundry invariant runner **and** Medusa 1.5.1. Echidna is **not installed** on this machine (`which echidna` → nothing); it was not run and nothing here is attributed to it.
- **Result**: **6 invariants held, 4 broke.** Both engines independently produced the *same* pass/fail partition.

> **Honesty statement.** A passing invariant below means *no counterexample was found within the stated run depth*. It is absence of evidence, not proof. Only the four **failures** are proofs — each is a concrete, replayable counterexample. Nothing in this document should be read as "verified safe".

---

## 1. Verbatim `forge test` summary

Command:

```
FOUNDRY_INVARIANT_RUNS=512 FOUNDRY_INVARIANT_DEPTH=150 \
FOUNDRY_INVARIANT_FAIL_ON_REVERT=false FOUNDRY_INVARIANT_SHRINK_RUN_LIMIT=10000 \
forge test --match-contract AntimatterInvariantTest -v
```

```
Ran 14 tests for test/audit/invariant/AntimatterInvariant.t.sol:AntimatterInvariantTest
[PASS] invariant_01_noStableResidueOnAntimatter() (runs: 512, calls: 76800, reverts: 0)
[PASS] invariant_02_noPhusdResidueOnAntimatter() (runs: 512, calls: 76800, reverts: 0)
[PASS] invariant_03_burnImpliesDelivery() (runs: 512, calls: 76800, reverts: 0)
[PASS] invariant_04_unbackedPhusdEqualsAntimatterBurned() (runs: 512, calls: 76800, reverts: 0)
[PASS] invariant_05_stableCustodyMatchesPulled() (runs: 512, calls: 76800, reverts: 0)
[FAIL: CODE-001: caller moved stablecoin it was never approved for: 335696647 != 0]
 invariant_06_noStableSpentBeyondCallerAllowance() (runs: 0, calls: 0, reverts: 0)
[FAIL: CODE-001: phUSD proceeds of a holder's assets delivered to a caller-chosen third party: 6646395452000000000000 != 0]
 invariant_07_noValueRedirectedAwayFromOwner() (runs: 0, calls: 0, reverts: 0)
[PASS] invariant_08_supplyOnlyMovesViaMintAndAnnihilation() (runs: 512, calls: 76800, reverts: 0)
[FAIL: USDC: phUSD issued in 24h exceeded cap: 17473344466000000000000 > 10000000000000000000000]
 invariant_09_dailyCapGovernsAllIssuance() (runs: 0, calls: 0, reverts: 0)
[FAIL: USDC: minter cap charged for less than the phUSD actually issued: 1000000000000 != 2000000000000]
 invariant_10_minterCapChargedForFullIssuance() (runs: 0, calls: 0, reverts: 0)
[PASS] test_counterexample_allowanceConservation() (gas: 366152)
[PASS] test_counterexample_dailyCapDoubled() (gas: 345567)
[PASS] test_handlerReachability() (gas: 1274100)
[PASS] test_handlerRevertProfile() (gas: 152832658)
Suite result: FAILED. 10 passed; 4 failed; 0 skipped; finished in 28.66s (167.34s CPU time)
Ran 1 test suite in 28.66s (28.66s CPU time): 10 tests passed, 4 failed, 0 skipped (14 total tests)
```

(`runs: 0, calls: 0` on a failing line is Foundry's post-shrink counter, not the work done — the campaign that found each failure ran to the same 512×150 budget as the passing ones.)

---

## 2. Anti-vacuity evidence

A previous harness on a sibling project passed `0 == 0` because its mocks never failed and its guarded state was never written. Four independent defences here:

**(a) The dependency chain is real, not stubbed.** The harness deploys the *actual* `FlaxToken`, the *actual* `PhusdStableMinter`, and real OZ-ERC20 stablecoins at 6 and 18 decimals. Only the yield strategy is audit-authored (`GuardedYieldStrategy`), and it is deliberately hostile-to-sloppiness: it reverts on an unauthorised client, when paused, on a zero deposit, and when the token it actually received differs from the amount requested. It books real principal per `(token, recipient)`, and that booking is the *collateral* term of invariant 04/05 — if it silently accepted everything, those invariants would degenerate.

**(b) The minter's daily cap is LIVE.** `setMaxMintPerDay` is set to 10,000e18 for both stables and the minter genuinely enforces it (the handler records 121 swallowed inner reverts, dominated by `Daily mint limit exceeded`).

**(c) `afterInvariant()` abort-on-empty tripwire.** Every completed sequence asserts `handler.totalAnnihilations() > 0` and that the third-party path was attempted; a run in which the fuzzer never landed an annihilation fails loudly. It did not fire in any campaign. Medusa has no `afterInvariant` hook, so the equivalent is exposed there as a fuzzable `vacuityTripwire()` action (asserts once ≥25 annihilation attempts have been made) — it **passed**, i.e. annihilations were reached.

**(d) A harness bug was caught by these defences and fixed.** An earlier revision exposed a `seedMinted(uint256)` setter so the test could tell the handler about the setUp mint. The fuzzer promptly called it and broke invariant 08 — a *harness artefact*, not a contract defect. The ghost is now folded in at handler construction and no fuzzable function can move it, and the target selector set is now declared explicitly (six actions, nothing else). Invariant 08 passes cleanly afterwards. This is recorded rather than quietly repaired because it is the reason to trust the remaining 08 pass.

---

## 3. Handler call distribution

**Fuzzer-level (Foundry, per invariant campaign, 512 runs × depth 150 = 76,800 calls).** Representative table, `invariant_01`:

| Selector | Calls | Reverts | Discards |
|---|---|---|---|
| `annihilateOnBehalf` | 12,665 | 0 | 0 |
| `annihilateSelf` | 12,894 | 0 | 0 |
| `approveAntimatter` | 12,961 | 0 | 0 |
| `mintAntimatter` | 12,688 | 0 | 0 |
| `transferAntimatter` | 12,810 | 0 | 0 |
| `warp` | 12,782 | 0 | 0 |

The distribution is essentially uniform across all campaigns, so `annihilateFrom` was reached ~25,500 times per invariant (both paths).

**Inner (swallowed) revert profile.** The handler wraps `annihilateFrom` in a low-level call so a bad draw does not abort the sequence, which means the runner's `Reverts` column reads 0 and understates nothing but also shows nothing. `test_handlerRevertProfile` drives the *same* handler through a 3,000-call deterministic pseudo-random walk to measure it:

```
mintAntimatter        : 478
approveAntimatter     : 511
transferAntimatter    : 506
warp                  : 502
annihilateSelf calls  : 479      ok: 373   revert: 106
onBehalf calls        : 524      ok: 321   revert: 15
AM minted             : 1,153,125.519967e18
AM burned (annihil.)  : 1,081,292.018823e18
stable in (18dp)      : 1,081,292.018823e18
phUSD out AM leg      : 1,081,292.018823e18
phUSD out stable leg  : 1,081,292.018823e18
unauthorised stable   :   359,977.333371e18
```

694 settled annihilations, 121 inner reverts (≈12%), across both decimal regimes. The settlement path is genuinely exercised.

---

## 4. Per-invariant results

### PASS — Invariant 1: settle-whole-or-not-at-all

> *Statement.* In every state reachable by any interleaving of mint / approve / transfer / warp / annihilate-self / annihilate-on-behalf, `Antimatter` holds **zero** of every registered stablecoin and **zero** phUSD; and the antimatter destroyed by completed annihilations exactly equals the antimatter-leg phUSD delivered — no state exists with antimatter burned but phUSD undelivered, or with stablecoin stranded.

| Test | Result | Runs | Calls | Reverts |
|---|---|---|---|---|
| `invariant_01_noStableResidueOnAntimatter` | PASS | 512 | 76,800 | 0 |
| `invariant_02_noPhusdResidueOnAntimatter` | PASS | 512 | 76,800 | 0 |
| `invariant_03_burnImpliesDelivery` | PASS | 512 | 76,800 | 0 |

**Why this is a meaningful pass, not an empty one.** The states checked are not idle. Across the campaign the harness pushed ~25,500 annihilation attempts through two decimal regimes (USDC 6dp via the `10**(18-decimals)` rescale, DOLA 18dp with no rescale), with ~12% of them *reverting inside* `annihilateFrom` — predominantly on the minter's live daily cap, which reverts **after** `_burn` has already executed and after `safeTransferFrom` has already moved the stablecoin onto Antimatter. That is precisely the partial state the invariant forbids, and it was entered thousands of times; the whole-transaction revert unwound it every time. Two further genuine sources of mid-flight residue were live: the `StableNotDeposited` strict-equality check and the `PhUSDNotReceived` delta check. Interleaved `warp` calls also mean the checks ran across window boundaries rather than in one instant.

**What it does not prove.** All stablecoins here are well-behaved OZ ERC20s. The harness does not include a fee-on-transfer, rebasing, or reentrant stable, so the *fail-closed* behaviour claimed for those in the profile is not re-proved here (the project's own `test/Annihilation.t.sol:276` covers the reentrant case). Nor does it exercise `rescueERC20` or an owner mid-flight reconfiguration.

### PASS — Invariant 2: backing accounting

> *Statement.* `phUSD.totalSupply() − (stablecoin actually in custody, normalised to 18dp)` equals the cumulative antimatter burned, **exactly**. Equivalently: every unit of antimatter burned mints exactly one unit of phUSD against zero collateral.

| Test | Result | Runs | Calls | Reverts |
|---|---|---|---|---|
| `invariant_04_unbackedPhusdEqualsAntimatterBurned` | PASS | 512 | 76,800 | 0 |
| `invariant_05_stableCustodyMatchesPulled` | PASS | 512 | 76,800 | 0 |

**This is a quantification, not an all-clear.** The invariant *holds*, and what it establishes is that the uncollateralised leg is exactly 1:1 with antimatter burned — no more, no less, no rounding drift in either direction across 76,800 calls and both decimal regimes at `exchangeRate == 1e18`. The econ consequence stands as the profile states it (`backingOfEachPhUSDLeg.antimatterLeg`): outstanding antimatter is a standing claim on uncollateralised phUSD, and `Antimatter.mint()` has no cap. Invariant 05 separately confirms that every stablecoin unit pulled from a holder actually reached strategy custody — nothing evaporated between `from` and the vault.

**Scope limit.** `exchangeRate` is pinned at `1e18` for both stables throughout. Rate divergence (`AM-LOCAL-005`) is deliberately *not* fuzzed here, because a rate change makes the identity `unbacked == burned` no longer the right statement; that belongs to the econ lens, not to this invariant.

### **FAIL** — Invariant 3: allowance conservation (CODE-001)

> *Statement.* No caller may cause a decrease in an address's **stablecoin** balance greater than what that address approved **to that caller**.

| Test | Result | Engine | Counterexample |
|---|---|---|---|
| `invariant_06_noStableSpentBeyondCallerAllowance` | **FAIL** | Foundry + Medusa | below |
| `invariant_07_noValueRedirectedAwayFromOwner` | **FAIL** | Foundry + Medusa | below |

Foundry assertion output:

```
CODE-001: caller moved stablecoin it was never approved for: 335696647 != 0
CODE-001: phUSD proceeds of a holder's assets delivered to a caller-chosen third party: 6646395452000000000000 != 0
```

Foundry's shrinker is unreliable here (cumulative ghosts make it report a 1-call sequence that cannot reproduce from the post-`setUp` state) — that is called out rather than papered over. **Medusa's shrinker produced a clean 2-call minimisation**, and the harness also ships a hand-built deterministic replay.

Medusa shrunk sequence (`medusa fuzz --config medusa.json`):

```
1) MedusaAntimatterTarget.approveAntimatter(...)         sender=0x20000
2) MedusaAntimatterTarget.annihilateOnBehalf(...)        sender=0x20000
3) MedusaAntimatterTarget.check_06_...()                 sender=0x20000
   => AntimatterHandler.ghostStableSpentWithoutCallerAllowance() => 48748205000000000000
   => [panic: assertion failed]
```

Deterministic replay — `test_counterexample_allowanceConservation` (PASSES, i.e. it reproduces):

```
precondition: usdc.allowance(victim, attacker) == 0
1) victim:   antimatter.approve(attacker, 100e18)                          // ANTIMATTER allowance only
2) attacker: antimatter.annihilateFrom(usdc, victim, attacker, 100e18)
=> victim's USDC balance falls by 100e6
=> usdc.allowance(victim, attacker) is still 0 — the attacker never held one
=> phUSD.balanceOf(attacker) == 200e18   (full 2x proceeds)
=> phUSD.balanceOf(victim)   == 0
```

An antimatter allowance is silently a **dual-asset authority plus a value-redirection right**: it spends the grantor's stablecoin on Antimatter's own standing approval and delivers the entire ~2x phUSD to a caller-chosen address. This is the harness tripwire working as intended — a harness that did **not** break here would be broken.

### PASS — Invariant 4: no burn outside annihilation

> *Statement.* `antimatter.totalSupply()` moves only through `mint()` and through a completed `annihilateFrom`: `totalSupply == Σ minted − Σ burned-in-completed-annihilation`.

| Test | Result | Runs | Calls | Reverts |
|---|---|---|---|---|
| `invariant_08_supplyOnlyMovesViaMintAndAnnihilation` | PASS | 512 | 76,800 | 0 |

**Why this pass is meaningful.** It is an *exact equality over the whole campaign*, not a bound, and the burn side of the ledger is written only from a measured `totalSupply` delta after an observed-successful call — never from the requested `amount`. ~12,700 `transferAntimatter` calls and ~12,700 `mintAntimatter` calls per campaign moved supply and balances around between checks, and ~3,000 annihilations reverted *after* reaching `_burn`; none of that produced a single unaccounted unit. This is the dynamic complement to the project's static trip-wire `test_noPublicBurnEntryPoints`: that one proves no burn *selector* exists, this one proves no reachable *sequence* destroys supply another way.

### **FAIL** — Invariant 5: daily-cap honesty (CODE-003)

> *Statement.* phUSD issued per stablecoin inside any rolling 24h window is `<= maxMintPerDay`. The window mirrors `PhusdStableMinter.mint`'s own reset logic exactly.

| Test | Result | Engine |
|---|---|---|
| `invariant_09_dailyCapGovernsAllIssuance` | **FAIL** | Foundry + Medusa |
| `invariant_10_minterCapChargedForFullIssuance` | **FAIL** | Foundry + Medusa |

Foundry assertion output:

```
USDC: phUSD issued in 24h exceeded cap: 17473344466000000000000 > 10000000000000000000000
USDC: minter cap charged for less than the phUSD actually issued: 1000000000000 != 2000000000000
```

Medusa single-call counterexample for `check_10` (the Medusa mirror of `invariant_10`), which pins the ratio exactly:

```
1) MedusaAntimatterTarget.annihilateSelf(...)   sender=0x10000
2) invariant_10_minterCapChargedForFullIssuance()
   => peakIssuedInWindow(USDC)  => 9893392938000000000000
   => peakChargedInWindow(USDC) => 4946696469000000000000
   => [panic: assertion failed]        // exactly 2.000x
```

Deterministic replay — `test_counterexample_dailyCapDoubled` (PASSES, i.e. it reproduces):

```
cap:                     maxMintPerDay(DOLA) = 10,000e18
1) who: annihilateFrom(dola, who, who, 6_000e18)
=> minter's mintedToday   ==  6,000e18   (stable leg only)
=> phUSD.balanceOf(who)   == 12,000e18   (both legs)
=> 12,000e18 issued under a 10,000e18 cap, in ONE transaction
```

The minter charges its cap only for the leg it mints itself; the antimatter leg is minted directly by `Antimatter` against its own FlaxToken authorisation and is invisible to that accounting. An operator who sets `maxMintPerDay = X` to bound daily phUSD issuance actually permits `2X` at the intended 1:1 rate. Note the cap is *not* merely bypassed asymptotically — a single call can exceed it outright, as the replay shows.

---

## 5. Medusa run

```
medusa fuzz --config medusa.json      # medusa version 1.5.1
targetContracts: ["MedusaAntimatterTarget"], workers: 6, callSequenceLength: 100,
assertionTesting.enabled + testViewMethods, testLimit 200,000

elapsed: 1m18s, calls: 210,604 (9,661/sec), branches: 2,987, corpus: 57, failures: 24/2,106

[FAILED] check_06_noStableSpentBeyondCallerAllowance()
[FAILED] check_07_noValueRedirectedAwayFromOwner()
[FAILED] check_09_dailyCapGovernsAllIssuance()
[FAILED] check_10_minterCapChargedForFullIssuance()
[PASSED] check_01..05, check_08, vacuityTripwire, + the forwarding actions
Test summary: 23 test(s) passed, 4 test(s) failed
```

Medusa reproduces the Foundry partition exactly, from an independently-deployed system, and shrinks the two failure classes to 2-call and 1-call sequences.

**A discarded Medusa result, recorded so it is not mistaken for corroboration.** The first Medusa attempt pointed `targetContracts` at the Foundry test contract `AntimatterInvariantTest` and reported `28 test(s) passed, 0 failed` — including green on the four invariants Foundry proves broken. That result was **vacuous**: Medusa fuzzes the functions of the contract it deploys, so it was calling `setUp()`, `excludeSenders()`, `IS_TEST()` and the `invariant_*` views while the handler behind `targetContract(...)` was never driven. `MedusaTarget.sol` exists precisely to give Medusa a no-arg-constructor entry point that forwards to the same handler. A Medusa "all passed" on a Foundry invariant harness should be treated as a configuration error, not a result.

Its checks are named `check_*` rather than `invariant_*` for a second, related reason: with the `invariant_` prefix, `forge` also picked `MedusaAntimatterTarget` up as a *second* Foundry invariant suite with no `targetContract` restriction, producing duplicate and differently-targeted results. Medusa's assertion mode calls every view method regardless of prefix, so the rename costs nothing there. After the rename, `forge test --no-match-contract AntimatterInvariantTest` is clean: **61 passed, 0 failed** — the project's own suite plus the 11 pre-existing audit-authored Tier-2 PoCs (`test/audit/Tier2.t.sol`, `test/audit/Tier2b.t.sol`), neither of which was modified.

---

## 6. Summary table

| # | Invariant | Foundry | Medusa | Maps to |
|---|---|---|---|---|
| 1 | No stablecoin residue on Antimatter | PASS (512×150) | PASS | CLAUDE.md "settle whole or not at all" |
| 2 | No phUSD residue on Antimatter | PASS (512×150) | PASS | same |
| 3 | Burn implies antimatter-leg delivery | PASS (512×150) | PASS | same |
| 4 | Unbacked phUSD == cumulative antimatter burned | PASS (512×150) | PASS | econ: uncollateralised leg, quantified |
| 5 | Stable pulled == stable in custody | PASS (512×150) | PASS | econ |
| 6 | No stablecoin spent beyond caller's allowance | **FAIL** | **FAIL** | **CODE-001 (High)** |
| 7 | No phUSD proceeds redirected off the owner | **FAIL** | **FAIL** | **CODE-001 (High)** |
| 8 | Supply moves only via mint / annihilation | PASS (512×150) | PASS | CLAUDE.md "never expose a burn" |
| 9 | ≤ maxMintPerDay phUSD issued per 24h | **FAIL** | **FAIL** | **CODE-003 (2x cap)** |
| 10 | Minter cap charged for full issuance | **FAIL** | **FAIL** | **CODE-003 (exactly 2.000x)** |

**Candidates for symbolic proof (Halmos).** Invariants 3 and 8 are single-transaction algebraic statements over one function and are the natural handoff to the symbolic-analyzer, where fuzzing can be upgraded to an actual proof. Invariants 1/2 involve external-call sequencing and are less tractable symbolically. Nothing in this document is a proof.
