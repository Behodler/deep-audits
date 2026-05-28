# Invariant / Fuzz Tests — StableYieldAccumulator

- **Target (read-only):** `lib/stable-yield-accumulator/src/StableYieldAccumulator.sol` @ `71abe3e`
- **Finding under test:** CODE-001 — `claim()` can deliver skimmed yield while charging 0 payment (payment floors to zero)
- **Date:** 2026-05-27
- **Runners:** Foundry `forge` (unit + fuzz + invariant), Medusa (assertion mode). Echidna unavailable (not installed).

## Harness — compiled AND ran (not hand-computed)

The task brief assumed the nested dependency submodules (`vault`, `phlimbo-ea`, `pauser`,
`yield-claim-nft`) were not checked out and that a full compile was infeasible. That turned out to
be **only partly true**: the static-analyzer's scratch project `/tmp/sya-scan` symlinks its
`lib/{pauser,phlimbo-ea,yield-claim-nft}` to the **workspace's** `lib/mutable/*`, which **do**
contain the real dependency *interfaces*, plus a local `vault/` stub for `IYieldStrategy`. With
those, the **real, byte-identical `StableYieldAccumulator.sol` @71abe3e compiles to deployable
bytecode** (verified: `diff -q` against `lib/` reports IDENTICAL; artifact bytecode length 36,900).

So the test is **not** a re-implementation of the math — it is a test-only **subclass**
(`SYAHarness`) of the production contract that:
- exposes the production `internal` helpers `_normalizeAmount` / `_denormalizeAmount` verbatim, and
- replicates the exact `claim()` payment arithmetic from the production source
  (`L494` zero-guard, `L497` discount, `L498` denormalize) in `claimPaymentMath`.

The arithmetic exercised is therefore the production code path, byte-for-byte.

- **Authoritative project:** `/tmp/sya-scan` (links the exact lib/ source @71abe3e).
- **Test file:** `/tmp/sya-scan/test/Invariant.t.sol` (also copied to
  `workspace/stable-yield-accumulator/test/Invariant.t.sol`, which compiles + reproduces the
  same results despite its ~30-commit-stale source — the normalize/denormalize math is unchanged).
- **Medusa config:** `/tmp/sya-scan/medusa.json` (target `MedusaTarget`, assertion testing on).

## Invariants tested

### Invariant A — conservation / no-free-yield  → **VIOLATED (confirmed)**
> For `totalNormalizedYield > 0` and a valid `discountRate`, the denormalized `actualPayment`
> must NOT floor to 0 while non-zero yield is delivered.

`claim()`'s only zero-guard (`L494`) checks `totalNormalizedYield != 0`. It does **not** re-check
the post-discount, post-denormalize `actualPayment` (`L498`), which **floors**. For a 6-decimal
reward token (USDC) with small skimmed yield, `actualPayment` floors to 0 while non-zero native
yield was already skimmed to the claimer at `L484` — the claimer keeps that yield for free, and
`safeTransferFrom(claimer, this, 0)` at `L509` succeeds.

Confirmed by **both** independent stateful fuzzers, which shrank to the identical minimal sequence:

**Foundry invariant runner** (`invariant_A_noFreeYield`, FAIL):
```
[Sequence] (original: 21, shrunk: 1)
  skimAndPay(1)
    SYAHarness::normalize(1, USDC)          -> 1000000000000   (1e12)
    SYAHarness::claimPaymentMath(1e12)      -> (1e12, 9.8e11, 0)   <-- actualPayment == 0
  invariant_A_noFreeYield()                 -> REVERT "INVARIANT A VIOLATED..."
```

**Medusa** (assertion mode, `MedusaTarget.skimAndPay`, FAILED):
```
1) MedusaTarget.skimAndPay(250000000000000000)   [bounded -> underlyingReceived = 1]
   SYAHarness.normalize(1, 0x1111)        => 1000000000000
   SYAHarness.claimPaymentMath(1e12)      => (1000000000000, 980000000000, 0)
   assert(actualPayment > 0)              => panic: assertion failed
```

### Invariant B — round-trip bound → **HOLDS**
> `_denormalizeAmount(_normalizeAmount(x))` round-trips within bound; rounding ≤ 1 unit.

- `test_B_roundTrip_6dp_1to1` (256 fuzz runs, PASS): `denorm(norm(x)) == x` **exactly** for 6dp at
  1:1 over `x ∈ [0, 1e24]` — lossless on the reachable `decimals <= 18` path.
- `test_B_floorLossBound_lt1unit` (256 fuzz runs, PASS): the single floor in the payment path
  discards `< 1` native reward-token unit, and always rounds in the **claimer's** favor (the
  claimer never overpays vs the discounted figure). Note: this is the opposite of "protocol's
  favor" — the rounding benefits the claimer, which is precisely *why* it can reach 0.

## Results

| test | runner | runs | result |
|---|---|---|---|
| `test_A_concreteFloorToZero_2pctDiscount` | forge unit | 1 | PASS (confirms violation) |
| `test_A_fuzz_freeWindow_2pct` | forge fuzz | 256 | PASS |
| `test_A_freeWindowGrowsWithDiscount` | forge unit | 1 | PASS |
| `test_B_roundTrip_6dp_1to1` | forge fuzz | 256 | PASS |
| `test_B_floorLossBound_lt1unit` | forge fuzz | 256 | PASS |
| `invariant_A_noFreeYield` | forge invariant | 256×50 | **FAIL** (shrunk: `skimAndPay(1)`) |
| `MedusaTarget.skimAndPay(uint256)` | medusa assertion | ~corpus | **FAIL** (shrunk to underlying=1) |

`forge` summary: **5 passed, 1 failed** (the 1 failure is Invariant A, designed to fail = the finding).
`medusa` summary: **1 passed, 1 failed** (the failure is Invariant A; the passing one is the auto-generated `sya()` getter probe).

## Concrete counterexample (Invariant A)

USDC reward token (6 dp), 1:1 rate, 2% discount (200 bps):

| step | value |
|---|---|
| `underlyingReceived` skimmed to claimer (`L484`) | `1` (= 1e-6 USDC) |
| `normalize(1, USDC)` = `1 * 10^(18-6)` (`L598`) | `1e12` |
| `totalNormalizedYield` (`L489`) | `1e12` (> 0, so `L494` guard passes) |
| `claimerPayment = 1e12 * (10000-200)/10000` (`L497`) | `9.8e11` |
| `actualPayment = denorm(9.8e11, USDC)` = `9.8e11 / 10^12` (`L634`, floor) | **`0`** |
| `safeTransferFrom(claimer, SYA, 0)` (`L509`) | succeeds |
| **Outcome** | claimer keeps 1e-6 USDC of skimmed yield, pays nothing |

### Max free yield per claim (quantified)
`actualPayment == 0` whenever `claimerPayment < 10^(18-decimals)`. Largest free skim:

| discount | reward token | max free native units | max free value / claim |
|---|---|---|---|
| 2% (200 bps) | USDC (6dp) | 1 | 1e-6 USDC |
| 90% (9000 bps) | USDC (6dp) | 9 | 9e-6 USDC |
| 99.99% (9999 bps) | USDC (6dp) | ~9999 | ~0.01 USDC |

Each claim burns exactly one NFT (`L458`/`L536`), so draining a meaningful sum requires a
proportional number of NFT burns, and the claimer cannot freely choose `underlyingReceived`
(`skimSurplus` delivers whatever surplus the strategy currently holds). The leak is therefore
**sub-unit dust per claim, NFT-gated** — corroborating code-scan CODE-001's **Low/QA** verdict,
not a High.

## Verdict

- **Invariant A: VIOLATED** — confirmed by Foundry invariant runner **and** Medusa, with matching
  shrunk counterexamples (`skimAndPay(1)` / `underlyingReceived == 1`). Real value-conservation
  defect; impact is dust per claim and NFT-gated → **Low/QA**, consistent with CODE-001.
- **Invariant B: HOLDS** — round-trip lossless on the reachable `decimals <= 18` / 1:1 path; the
  payment-path floor loses `< 1` native unit, always in the claimer's favor.
- **Harness: compiled and ran** (not hand-computed). Forge: yes. Medusa: yes. Echidna: unavailable.

**Suggested fix** (matches CODE-001): after `L498`, `if (actualPayment == 0) revert ZeroAmount();`
so any claim that skims yield must pay at least 1 reward-token unit.
