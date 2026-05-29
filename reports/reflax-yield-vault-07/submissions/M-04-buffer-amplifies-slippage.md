<!--
ID: pv7m4
C4 Submission Metadata
Label: M-04
Title: [M-04] Slippage amplification under per-client setAsideBuffer breaches NAV-anchored minOut acceptance bound
Severity: Medium
Root Cause Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L432-L451
Supporting Code Link: https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L503-L521
PoC File: workspace/phoenix-vault/test/poc-M04-buffer-amplifies-slippage.t.sol
Related: M-02 (acknowledged) — this finding is a distinct, parametrically-activated breach of M-02's acceptance bound, not a duplicate.
-->

## Finding description and impact

### Summary

`ERC4626MarketYieldStrategy._skimSurplus` derives the swap's `minOut` from the **aggregate** surplus shares, but `_distributeBuffer` pays the per-client set-aside buffers off the top of the actually-received underlying and forwards only the remainder to the skim recipient. The swap's absolute slippage allowance (in underlying terms) is therefore unchanged by the buffer configuration, while the recipient's principal slice is reduced by `(1 - f)`, where `f := totalBufferShares / totalShares` is the aggregate buffer fraction. The recipient's per-skim leak, measured as a fraction of the recipient's own take, scales as `slippageToleranceBps / (1 - f)`.

The M-02 acknowledgement memo accepted the NAV-anchored `minOut` design on the explicit parametric ground that the per-swap leak is bounded by `slippageToleranceBps × tradeSize` against recipient principal. Story-042's per-client `setAsideBuffer` activates a distribution path that breaches that bound: at `f = 0.5` the recipient's effective slippage is 2x the configured tolerance; at `f = 0.75` it is 4x; as `f → 1` the recipient-fractional leak is unbounded. Because `f` is an in-design, owner-configurable parameter (via `setSetAsideBuffer`, the setter introduced by story-042) with no aggregate cap and no upper bound on `slippageToleranceBps`, the breach is reachable through normal operator action — no adversary required.

### Vulnerability details

The vulnerable distribution path is in `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`. `_skimSurplus` computes `minOut` against the full `totalShares` (the unbuffered aggregate), executes a single swap, and then either fast-paths the proceeds to `recipient` (no buffers configured) or splits them via `_distributeBuffer`:

```solidity
// ERC4626MarketYieldStrategy.sol:432-451
// minOut is computed on the full `totalShares`: the whole surplus is sold in ONE swap; only the
// distribution of the proceeds changes when buffers are set, so slippage behavior is unchanged.
uint256 idealUnderlying = vault.convertToAssets(totalShares);
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
IERC20(address(vault)).safeIncreaseAllowance(address(ammAdapter), totalShares);
underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);

// FAST PATH — no buffers configured (the default): forward the whole swap output to `recipient`.
if (totalBufferShares == 0) {
    underlyingToken.safeTransfer(recipient, underlyingReceived);
    return underlyingReceived;
}

// BUFFERED PATH — split the actual proceeds: each client gets its proportional share of the
// set-aside, the remainder goes to `recipient`. Principal tracking intentionally untouched.
return _distributeBuffer(clients, bufferShares, underlyingReceived, totalShares, recipient);
```

`_distributeBuffer` sends each client its proportional buffer slice off the actual swap proceeds, and only the residual is forwarded to the recipient:

```solidity
// ERC4626MarketYieldStrategy.sol:503-521
function _distributeBuffer(...) private returns (uint256 toRecipient) {
    uint256 totalSetAside;
    for (uint256 i = 0; i < clients.length; i++) {
        if (bufferShares[i] == 0) continue;
        uint256 buf = underlyingReceived * bufferShares[i] / totalShares; // actual-tokens, proportional
        if (buf == 0) continue;
        totalSetAside += buf;
        underlyingToken.safeTransfer(clients[i], buf);   // set aside back to the client
    }
    toRecipient = underlyingReceived - totalSetAside;     // dust (rounding) favors recipient
    if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);
    return toRecipient;
}
```

The structural property this creates:

- `idealUnderlying = convertToAssets(totalShares)` is computed on the **full** aggregate (including the buffered slice).
- `minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS` therefore allows the entire swap to clear up to `slippageToleranceBps` below fair NAV on the *full* trade size.
- The buffered slice (`totalSetAside`) is paid to clients off the top, *before* any slippage attribution.
- `toRecipient = underlyingReceived - totalSetAside`, so the recipient absorbs the entire absolute slippage delta over a principal share of only `(1 - f) × idealUnderlying`.

In closed form, with `f := totalBufferShares / totalShares` and a worst-case fill at exactly `minOut`:

```
absoluteLeak                   = idealUnderlying × slippageBps / MAX_BPS         (unchanged by f)
recipientPrincipal             = (1 - f) × idealUnderlying
effectiveBps(recipient)        = absoluteLeak / recipientPrincipal × MAX_BPS
                               = slippageBps / (1 - f)
```

### Activation path (no adversary required)

The trigger is in-design operator behaviour, not an exploit:

1. The owner configures one or more authorised clients with non-trivial `setAsideBufferSize` via `setSetAsideBuffer` (the story-042 setter in `AYieldStrategy.sol`, `onlyOwner`). The setter accepts any percent in `[0, 100]`; there is no aggregate cap.
2. The aggregate buffer fraction `f = totalBufferShares / totalShares` becomes non-zero.
3. Any `skimSurplus` executes against a vault NAV that diverges from the AMM clearing price — the same precondition class M-02's acceptance memo accepted as residual (sandwich window, depeg, thin liquidity).
4. The swap clears within `slippageToleranceBps` of fair NAV (the tolerance the M-02 memo treated as bounded), the buffered slice is paid to clients off the top without slippage attribution, and the recipient receives `toRecipient` — a slice that absorbs the full absolute leak over a smaller principal.

The mechanism is parametric, not adversarial: every additional basis point of `f` proportionally amplifies the recipient's effective slippage. The recipient never opts in to this trade-off and never sees the realised `effectiveBps(recipient)` ex-ante.

### Relationship to M-02 (acknowledged) — distinct deliverable, not a duplicate

M-02 ("NAV-anchored `minOut` is execution-price-blind") was acknowledged on the explicit parametric ground recorded in the ledger memo: the residual per-swap leak is bounded by `slippageToleranceBps × tradeSize` measured against recipient principal, and at the deployed default (no buffers configured) the recipient's take equals the full trade output, so `effectiveBps(recipient) == slippageBps`.

Story-042 invalidates that ground state. With `f > 0` the recipient's take is structurally less than the trade output, and the same absolute leak is concentrated onto a smaller denominator. The M-02 acceptance memo's bound holds only at `f = 0`; for any `f > 0` it is broken by construction. This is reportable as a distinct Medium for two reasons: (a) it is a new code path introduced by story-042 (`_distributeBuffer` plus the `setSetAsideBuffer` setter), and (b) it changes the parametric form of the bound the acceptance memo was contingent on. The memo must either be re-confirmed under the new parametric bound `slippageBps / (1 - f)` or mitigated per the recommendations below.

### Impact — f-sweep from the PoC

The PoC (`workspace/phoenix-vault/test/poc-M04-buffer-amplifies-slippage.t.sol`) instantiates the real in-scope `ERC4626MarketYieldStrategy` against a deterministic AMM that fills at exactly `minOut` (the worst-case price the slippage tolerance still admits — i.e. the worst case the M-02 acceptance memo's parametric bound is supposed to cover). It scans `f ∈ {0%, 25%, 50%, 75%}` with `slippageToleranceBps = 100` (1%), and measures `effectiveBps(recipient) = absoluteLeak / recipientPrincipal`:

| Aggregate buffer fraction `f` | Configured `slippageToleranceBps` | Predicted `slippageBps / (1 - f)` | Measured effective bps against recipient principal | M-02 bound (`bps × recipientPrincipal`) |
|---|---|---|---|---|
| 0%   | 100 (1%) | 100  | ~100 (matches M-02 bound) | holds exactly |
| 25%  | 100 (1%) | 133  | ~133 | **breached** |
| 50%  | 100 (1%) | 200  | ~200 | **breached (2x)** |
| 75%  | 100 (1%) | 400  | ~400 | **breached (4x)** |

Tolerance per row: ±5 bps (rounding). All four sweep tests plus the dedicated `f = 50%` bound-breach test pass at submodule commit `5f9abdd`.

The absolute per-swap leak is still bounded by the AMM `minOut` (a depositor-facing bound the swap reverts under), so this is a value-leak finding under stated assumptions rather than an unbounded theft primitive — hence Medium. The acknowledged parametric bound the design relies on, however, is broken: the recipient's effective slippage tolerance is set implicitly by `f`, not by `slippageToleranceBps`, and `f` is operator-configurable with no aggregate cap and no upper bound on the multiplier.

### Borderline note (Medium vs High)

Held at Medium because (a) the absolute per-swap leak remains bounded by the AMM `minOut`, (b) recipients are owner-curated protocol-owned counterparties under the M-02 memo's framing, and (c) the parametric breach requires an owner-set non-zero buffer fraction. The classification should be revisited as High if (i) deployment ships with non-trivial buffer defaults without an aggregate cap and without a low `slippageToleranceBps` ceiling, or (ii) a future strategy is deployed against an ERC4626 whose share price is atomically manipulable — in that combined surface the recipient-fractional amplification of an atomic NAV manipulation becomes a direct theft primitive rather than a parametric leak.

### Proof of Concept

A runnable Foundry PoC is provided at `workspace/phoenix-vault/test/poc-M04-buffer-amplifies-slippage.t.sol`. It imports the in-scope `ERC4626MarketYieldStrategy` directly (the real contract at `lib/reflax-yield-vault@5f9abdd`), uses faithful `MockERC4626Vault` (standard proportional share math) and `MockERC20` mocks, and a `SlippageAtMinOutAMM` adapter that genuinely enforces `amountOut >= minAmountOut` — the strategy's own `minOut` derivation and `_distributeBuffer` path are the components under test.

Run:

```bash
cd workspace/phoenix-vault
forge test --match-path 'test/poc-M04-buffer-amplifies-slippage.t.sol' -vv
```

Five tests, all passing at commit `5f9abdd`:

- `test_buffer_amplifies_recipient_slippage_bound_breach` — one-shot at `f = 50%`, `slippageBps = 100`. Asserts `effectiveBps ≈ 200` (== `slippageBps / (1 - f)`) and explicitly asserts the M-02 acceptance bound (`absoluteLeak <= bps × recipientPrincipal / MAX_BPS`) is breached by ~2x.
- `test_sweep_f00_baseline_matches_slippageBps` — `f = 0%`: `effectiveBps ≈ 100`. Confirms the M-02 bound holds exactly at the deployed-default state.
- `test_sweep_f25_amplified` — `f = 25%`: `effectiveBps ≈ 133` (matches `slippageBps × MAX_BPS / (MAX_BPS - 2500)`); explicitly asserts `> SLIPPAGE_BPS`.
- `test_sweep_f50_amplified` — `f = 50%`: `effectiveBps ≈ 200`; `> SLIPPAGE_BPS`.
- `test_sweep_f75_amplified` — `f = 75%`: `effectiveBps ≈ 400`; `> SLIPPAGE_BPS`.

Test methodology notes:

- The AMM is rigged to land at exactly `minAmountOut`. This is the worst tolerated price the slippage cap permits, and is the realisation the M-02 acceptance memo's parametric bound was supposed to cover. Any below-NAV fill in the rigged window is the slippage residual the memo accepted at `f = 0`; this PoC measures what happens to the *recipient's* fractional take under the same realisation as `f` increases.
- The `f`-sweep configures four equal-principal clients with a uniform per-client buffer percentage, so the aggregate fraction `f` equals the per-client percentage. Equal principals ensure each client's surplus shares are equal, making `f` directly controllable.
- The test recomputes `f` and `idealUnderlying` from public strategy state immediately before the skim (mirroring `_accrueSurplusShares`), then compares `absoluteLeak / recipientPrincipal` to `slippageBps / (1 - f)`.

## Recommended mitigation steps

Three layered mitigations, in increasing order of structural strength. (b) and (c) are independently sufficient to restore an effective parametric bound on the recipient's effective slippage; (a) is a cheap bound-tightening that also addresses L-01 from this run's QA bundle.

### 1. Cap `slippageToleranceBps` (cheap, also fixes L-01)

`setSlippageTolerance` currently accepts any value in `[0, MAX_BPS]`. Add a hard ceiling appropriate for the stable-pair route (e.g. 50 bps) so a misconfiguration cannot stack with a non-zero `f` to produce a multi-percent recipient-fractional leak:

```solidity
uint256 private constant MAX_SLIPPAGE_BPS = 50; // example: tune per route
function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps <= MAX_SLIPPAGE_BPS, "ERC4626MarketYieldStrategy: slippage cap exceeded");
    slippageToleranceBps = _bps;
}
```

This caps the *base* of the amplification but does not bound the multiplier `1 / (1 - f)`.

### 2. Introduce an aggregate buffer cap (bounds the multiplier `1 / (1 - f)` by design)

Track aggregate buffer-weighted exposure on every `setSetAsideBuffer` call and revert if a configuration would push the protocol-wide buffer fraction above a documented ceiling (e.g. 50%). Per `feedback_revert_over_silent_clamp`, prefer `require` over silent clamping — operator-generated bad input should fail loudly, not be silently absorbed:

```solidity
uint256 private constant MAX_AGGREGATE_BUFFER_BPS = 5000; // 50%
function setSetAsideBuffer(address client, uint256 bufferPercent) external override onlyOwner {
    // existing checks ...
    // Enforce an invariant on the resulting aggregate buffer fraction.
    require(
        _projectedAggregateBufferBps(client, bufferPercent) <= MAX_AGGREGATE_BUFFER_BPS,
        "AYieldStrategy: aggregate buffer cap exceeded"
    );
    // existing state update ...
}
```

Combined with (1), this bounds `effectiveBps(recipient) <= MAX_SLIPPAGE_BPS / (1 - MAX_AGGREGATE_BUFFER_BPS / MAX_BPS)` — a hard, predictable parametric ceiling.

### 3. Derive `minOut` against the recipient's share, not the pre-buffer total (structural fix)

The structural root cause is that `minOut` is anchored to `idealUnderlying = convertToAssets(totalShares)` — the full pre-buffer aggregate — while the recipient only receives `(1 - f) × underlyingReceived`. Re-anchor `minOut` to the recipient's expected share:

```solidity
uint256 idealUnderlying = vault.convertToAssets(totalShares);
uint256 idealRecipient  = vault.convertToAssets(totalShares - totalBufferShares);
uint256 minOutRecipient = idealRecipient * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
// existing aggregate minOut for the swap call:
uint256 minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) / MAX_BPS;
underlyingReceived = ammAdapter.swap(address(vault), address(underlyingToken), totalShares, minOut);
// after distributing buffers, verify the recipient's take meets its own bound:
toRecipient = _distributeBuffer(clients, bufferShares, underlyingReceived, totalShares, recipient);
require(toRecipient >= minOutRecipient, "ERC4626MarketYieldStrategy: recipient minOut not met");
```

Under (3) the recipient is guaranteed `slippageToleranceBps` against its own principal regardless of `f`. The trade still goes through the AMM exactly once, the buffer slice is still paid first, and the protocol reverts (per `feedback_revert_over_silent_clamp`) rather than silently delivering an amplified leak. This is the only mitigation that re-establishes the parametric form `effectiveBps(recipient) <= slippageToleranceBps` the M-02 acceptance memo relies on, independent of the operator's `f` configuration.
