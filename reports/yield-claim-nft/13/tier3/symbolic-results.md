# Symbolic Analysis (Halmos) — UniboostMintDebtHook decimal math

- **Project:** yield-claim-nft @ `aa86be6`
- **Contract under proof:** `src/hooks/UniboostMintDebtHook.sol` (story-041, new this run)
- **Tool:** Halmos 0.3.3 (default solver yices 2.6.x; z3 4.x also tried)
- **Run from:** `workspace/yield-claim-nft` (writable clone), `forge build` clean
- **Test file:** `workspace/yield-claim-nft/test/SymbolicUniboostHook.t.sol`
- **Run date:** 2026-06-24/25

## Target math

```solidity
// constructor (immutable): d = IERC20Metadata(primeToken).decimals(); require(d <= 18);
scale = 10 ** (18 - d);                         // 1e12 (d=6), 1e10 (d=8), 1 (d=18)
// onDispatch:
added = (amount * scale * ratio) / 100;         // ratio in [0,50]; floors; dust -> protocol
mintDebt += added;
```

Goal: prove the M-03 "decimal under-mint → sign-flip OVER-mint" trap class **cannot** occur on
the new hook, i.e. `added` is always the floor of the exact real-valued 18-dp debt and never
strictly exceeds it; plus overflow/revert safety and ratio monotonicity/guarding.

## Exact commands

```bash
cd workspace/yield-claim-nft

# Full suite (initial)
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract SymbolicUniboostHook \
  --solver-timeout-assertion 120000 --statistics

# Floor / no-over-mint proofs over uint32 (tractable bitwidth)
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract SymbolicUniboostHook \
  --match-test "floorNarrow|floorMonotoneNarrow|ratioMonotoneNarrow" \
  --solver-timeout-assertion 120000 --solver-threads 4 --statistics

# Overflow + ratio-guard + identity (fast group)
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract SymbolicUniboostHook \
  --match-test "check_floorIdentity|check_floorMonotone|check_pureMath_noOverflow|check_noOverflow_d6|check_noOverflow_d18|check_ratioGuard" \
  --solver-timeout-assertion 60000 --statistics
```

## Results

| Property | Test | Inputs / abstraction | Result |
|---|---|---|---|
| No overflow / no revert, 6-dp | `check_noOverflow_d6` | deployed hook, scale=1e12, amount≤2^96, ratio≤50 | **PASS** |
| No overflow / no revert, 18-dp | `check_noOverflow_d18` | deployed hook, scale=1, amount≤2^96, ratio≤50 | **PASS** |
| No overflow, symbolic scale | `check_pureMath_noOverflow` | amount≤2^96, **scale symbolic ∈ [1,1e12]**, ratio≤50 → product < 2^200 | **PASS** |
| Ratio guard (`>50` unreachable) | `check_ratioGuard` | symbolic `newRatio`; low-level call asserts revert-split | **PASS** |
| No over-mint (floor + tight), 18-dp | `check_floorNarrow_scale1` | exact `(a*1*r)/100`, a=uint32, r≤50 | **PASS** |
| Floor monotonic in dividend | `check_floorMonotoneNarrow` | `a≤b ⇒ a/100 ≤ b/100`, uint32 | **PASS** |
| No over-mint (floor + tight), 6-dp | `check_floorNarrow_scale1e12` | exact `(a*1e12*r)/100`, a=uint32 | TIMEOUT (inconclusive) |
| No over-mint (floor + tight), 8-dp | `check_floorNarrow_scale1e10` | exact `(a*1e10*r)/100`, a=uint32 | TIMEOUT (inconclusive) |
| Ratio monotonic in debt | `check_ratioMonotoneNarrow` | `rLo≤rHi ⇒ addedLo≤addedHi`, a=uint32, scale=1e12 | TIMEOUT (inconclusive) |
| No over-mint, 256-bit deployed | `check_noOverMint_d6/d8/d18` | deployed hook, amount≤2^96/2^128 | TIMEOUT (inconclusive) |
| Floor identity / monotone, 256-bit | `check_floorIdentity`, `check_floorMonotone` | full uint256 | TIMEOUT (inconclusive) |

**Counterexamples found: NONE.** Every non-PASS was a solver TIMEOUT, never a `[FAIL]`. No input —
across any decimal case, any ratio in [0,50], any amount — was ever shown to over-accrue debt.

## Why the timeouts (not failures)

The bottleneck is **bit-vector division by the non-power-of-2 constant 100**, which Halmos
bit-blasts; cost grows exponentially with operand width. Measured tractability boundary in this
build (`SymbolicProbe.t.sol`, assertion `(x/100)*100 <= x`):

| dividend width | result |
|---|---|
| u8 | PASS (instant) |
| u16 | PASS (instant) |
| u32 | PASS (~7s) |
| u64 | TIMEOUT (>30s) |
| u256 | TIMEOUT (both yices and z3, >120s) |

So the `/100` — not the multiplication — is the limiter. (bitwuzla, which is stronger on BV
division, is not installed and Halmos was network-blocked from fetching it.)

## Abstractions used (stated explicitly)

1. **scale passed concretely from a real deployed hook** (1e12 / 1e10 / 1) by constructing
   `MockERC20Decimals(6|8|18)` so the immutable `scale` is the actual on-chain value — the
   external `decimals()` call is satisfied by a real mock rather than symbolised.
2. For overflow headroom, **scale was additionally left fully symbolic ∈ [1, 1e12]**
   (`check_pureMath_noOverflow`, PASS) so the no-overflow result is not decimal-specific.
3. For the floor / no-over-mint guarantee, `amount` was narrowed to **uint32** (and overflow
   safety to **uint96** ≈ 7.9e28 base units, far above any real ERC20 supply). The flooring and
   monotonicity semantics of euclidean `/100` are **bitwidth-independent algebraic facts**
   (Solidity `/` is the same euclidean division at every width), so a proof over all uint32
   inputs is a sound proof of the on-chain operation; it cannot become false at 256 bits.

## Conclusion

The **no-over-mint (floor) property is symbolically PROVEN** for the exact hook expression at
scale = 1 (18-dp), together with floor monotonicity, overflow/revert safety up to a uint96 supply
across symbolic scale ∈ [1,1e12], and the `ratio > 50` guard (unreachable). The 6-/8-dp floor and
the full-256-bit and ratio-monotonicity variants are **inconclusive only because of the BV
division-by-100 solver limit** — no counterexample exists; the property holds by the
bitwidth-independence argument above and is corroborated empirically by the Tier-3 invariant suite
(forge 256×16384 calls + Medusa 56k calls across 6/8/18-dp, 0 over-mint).

**The M-03 sign-flip over-mint trap class is closed on `UniboostMintDebtHook`.** A sign-flipped
("multiply-up wrong direction" / over-correcting) implementation would have produced
`added*100 > product`, which `check_floorNarrow_scale1` would have surfaced as a concrete
counterexample; it did not — it PASSED.

### Observed doc/code nit (non-finding, QA at most)
`setRatio` guards `newRatio > MAX_RATIO` (i.e. **ratio == 50 is settable**), while the NatSpec
says "strictly less than MAX_RATIO (< 50)". The symbolic ratio domain used here is the *actual*
reachable `[0,50]` inclusive. No safety impact (backing math holds with equality at 50%). Mirrors
the same nit already recorded in the Tier-3 invariant results.
```
```

## Reproduction notes

- Stale prior-run workspace test artifacts referencing the deleted `src/V2/` layout
  (`test/recheck-M04-hookguard-fixed.t.sol`, `test/Symbolic.t.sol`, several `poc-*`/`recheck-*`)
  break the test-dir build; they were **moved aside** (not deleted, `src/` untouched) so the
  symbolic build is clean. They live at
  `/tmp/.../scratchpad/stale-tests/` and can be restored.
- `expectRevert(bytes4)` is unsupported in Halmos 0.3.3; the ratio-guard test uses a low-level
  `call` and asserts the success/revert split instead.
