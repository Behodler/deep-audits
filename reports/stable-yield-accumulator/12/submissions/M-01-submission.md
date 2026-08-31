<!--
ID: sya12m1
C4 Submission Metadata
Title: [M-01] Fail-open unconfigured-token fallback: one forgotten `setTokenConfig` on a strategy token (reward token configured) lets any NFT holder drain that sub-18-decimal strategy's full yield for ~0 payment (symmetric reward-token brick)
Root Cause Link: https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L586-L640
PoC File: workspace/stable-yield-accumulator/test/poc-M-01.t.sol
Severity: Medium (top of band; Plausible-High dissent recorded for the severity-auditor)
Status: NEW
Ledger Fingerprint: ecc2d126
Known-issue coverage: NOT covered by KI#2 (blesses the normalization math for CONFIGURED tokens only) or KI#8 (documents only the (0,0) => 18-dec default value, not this drain consequence).
Ledger cross-link: weaponizes ledger L-01 (standalone dust-only zero-payment floor) ~1e12x via decimal misconfig — keep both, cross-linked; do NOT re-escalate L-01.
-->

## Finding description and impact

### Summary

`claim()` prices a claimer's payment by normalizing each strategy's skimmed underlying to 18 decimals ([`_normalizeAmount` @ L489](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L489)), summing the result, applying the discount ([L497](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L497)), and denormalizing back to the reward token's decimals ([`_denormalizeAmount` @ L498](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L498)).

Both helpers treat an **unconfigured** token (`tokenConfigs[token].decimals == 0 && normalizedExchangeRate == 0` — the default struct state) as an 18-decimal, 1:1 passthrough:

- `_normalizeAmount` fallback at [L586-L609, branch L591-L593](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L586-L609)
- `_denormalizeAmount` fallback at [L617-L640, branch L622-L624](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L617-L640)

Nothing links registration or funding to a required config. [`addYieldStrategy(strategy, token)` @ L227](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L227) takes no decimals argument and never requires a `TokenConfig`; [`setRewardToken(_rewardToken)` @ L360](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L360) never requires one either. The decimals are set in a **separate, easy-to-forget** owner call, [`setTokenConfig` @ L280](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L280).

If a registered token is left unconfigured while it is **not** actually 18-decimal, the 18-decimal passthrough mis-scales its value by `10**(18 - actualDecimals)` (~`1e12` for 6-decimal stablecoins) — a realistic slip on a *stable*-yield hub where 6-decimal USDC/USDT are the dominant token type. The consequence depends on *which* token is unconfigured (see the deployment-state matrix under "Severity justification"): the drain arises only from the **asymmetric** case — the reward token correctly configured at sub-18 decimals (as it must be for normal operation) while a strategy token's config is forgotten — which floors the claimer's payment to zero. With *both* tokens unconfigured the two passthroughs cancel and the claimer pays ~fair value (no drain); an unconfigured reward token alone fail-safe bricks all claims. So the vulnerable state is **not** an insecure default reached by doing nothing — it is a plausible *partial* misconfiguration.

This is a non-obvious owner **footgun** (Law 3): it needs no malice, only a single forgotten `setTokenConfig` on a strategy token (most plausibly one added after launch) against an otherwise correctly-configured protocol, and the misconfiguration emits no hard error to signal the omission. It is explicitly *not* the suppressed malicious-owner centralization framing, and — per the matrix below — not an insecure-by-default state either (the zero-effort, nothing-configured deployment does not drain).

### Vulnerability details

The pricing pipeline in `claim()` ([L484-L509](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L484-L509)):

```solidity
uint256 underlyingReceived = IYieldStrategy(strategy).skimSurplus(token, msg.sender); // L484: real yield delivered to claimer
if (underlyingReceived > 0) {
    emit RewardsCollected(strategy, underlyingReceived);
    totalNormalizedYield += _normalizeAmount(underlyingReceived, token);             // L489: mis-scaled ~1e12x low
    strategiesWithYield++;
}
...
uint256 claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000;       // L497
uint256 actualPayment  = _denormalizeAmount(claimerPayment, rewardToken);             // L498: floors to 0
if (actualPayment < minRewardTokenSupplied) revert InsufficientYield();              // L501: min defaults to 0 -> no guard
...
IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), actualPayment);       // L509: transfers 0
```

The fail-open fallback that drives the mis-scale:

```solidity
function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {
    uint8 decimals = tokenConfigs[token].decimals;
    uint256 exchangeRate = tokenConfigs[token].normalizedExchangeRate;

    // If no config set, assume 18 decimals and 1:1 rate   <-- L590-L593: FAIL-OPEN
    if (decimals == 0 && exchangeRate == 0) {
        return amount;
    }
    ...
}
```

`_denormalizeAmount` carries the symmetric fallback at L622-L624 and, for a *configured* sub-18-decimal reward token, the real divisor at [L634](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L634) (`scaled / 10**(18 - decimals)`).

**Drain path (unconfigured strategy token):**

1. Precondition — a benign, non-attacker-controllable owner omission: the owner registers a sub-18-decimal strategy token via `addYieldStrategy(strategy, USDT)` (L227, no decimals arg, no `TokenConfig` required) and configures the reward token, but omits the separate `setTokenConfig(USDT, 6, 1e18)` (L280). `USDT` stays at the default `(decimals==0, rate==0)` state.
2. The unconfigured strategy accrues real yield, e.g. `1000` USDT (`1000e6` native).
3. Any valid-NFT holder calls `claim(nftIndex, minRewardTokenSupplied = 0, exemptStrategies = [all correctly-configured strategies])` to isolate the misconfigured one (`exemptStrategies` honored at [L473](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L473)).
4. `skimSurplus(USDT, msg.sender)` delivers the full `1000e6` USDT to the claimer (L484) — real value received, independent of SYA's pricing.
5. `_normalizeAmount(1000e6, USDT)` hits the fail-open branch (L591) and returns `1000e6` *treated as 18-dec*, so `totalNormalizedYield` is understated ~`1e12x` (L489). The contract's only zero-guard, `if (totalNormalizedYield == 0) revert ZeroAmount();` (L494), tests this **pre-floor** normalized sum — which is non-zero (`1e9`) — so it does not fire.
6. `claimerPayment = 1000e6 * (10000 - discount) / 10000` (L497); `actualPayment = _denormalizeAmount(...)` divides by `10**(18-6) = 1e12` (L634) and floors to **0** (L498). There is no second guard on the **post-floor** `actualPayment`.
7. `actualPayment(0) >= minRewardTokenSupplied(0)` passes (L501); the nudge/phlimbo split is `0`; `safeTransferFrom(msg.sender, this, 0)` succeeds (L509). Net: the claimer keeps `1000` USDT of real yield for `0` reward token; phlimbo/Limbo stakers receive nothing. Repeatable on every accrual.

**Brick path (unconfigured reward token):** a sub-18-decimal reward token left unconfigured makes `actualPayment` ~`1e12x` too large, so `safeTransferFrom` (L509) reverts and every yielding claim fails until the owner configures the token. This is a fail-safe availability outage of the sole core function, not value loss.

### Impact

Drain direction (under the asymmetric partial misconfiguration — reward token configured at sub-18 decimals, a strategy token's `setTokenConfig` forgotten): 100% of that unconfigured sub-18-decimal strategy's accrued, skimmed yield — the surplus owed to phlimbo / Limbo stakers — is delivered in full to any NFT holder for **zero** reward-token payment, repeatable on every accrual. The only attacker cost is one burned NFT plus gas. The PoC quantifies this exactly: `1000e6` of real underlying delivered to the claimer, `0` paid, `0` to phlimbo, `0` retained by SYA.

The asset lost is the protocol's in-motion / in-conversion yield routed to phlimbo — not user principal and not an SYA insolvency (SYA holds no strategy principal; it pulls payment from the claimer). The brick variant is a full availability outage of `claim()` (fail-safe).

### Severity justification (Medium, top of band; Plausible-High dissent disclosed)

Classified **Medium (M-01)** at the top of the band. The severity follows from the precondition, set out by this deployment-state matrix (verified against source at `71abe3e`):

| Reward token | Strategy token | Result |
|---|---|---|
| unconfigured | unconfigured | both hit the 18-dec / 1:1 passthrough; the scaling errors **cancel**; claimer pays ~fair value — **no drain** |
| **configured at <18 dec** | **left unconfigured (and actually <18 dec)** | strategy yield under-counted ~`1e12x`, then denormalized to the <18-dec reward token, flooring `actualPayment` to 0 — **DRAIN** (the PoC's exact case) |
| unconfigured | configured | `actualPayment` over-scales ~`1e12x`, `safeTransferFrom` reverts — fail-safe **brick**, not a drain |

Two consequences place this at Medium rather than High. First, **the no-precondition slice of this bug is empty**: the zero-effort, nothing-configured deployment does not drain (the two passthroughs cancel to ~fair payment), and a protocol configured per its own documented setup (a `TokenConfig` for every registered/reward token, per the submodule's "Token Config Mapping" core component) pays fair value — there is no attack against a correctly-configured protocol, which alone fails the C4 High bar (a true High needs a valid path against a correctly-configured protocol). Second, **the one slice that does drain is gated by an owner config state the attacker can neither create nor induce**: both `addYieldStrategy` ([L227](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L227)) and `setTokenConfig` ([L280](https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L280)) are `onlyOwner`, and nothing an external actor does can move a token into the unconfigured state. That attacker-uninducible, only-under-partial-misconfiguration precondition is precisely the C4 Medium carve-out — "leak value ... with stated assumptions, but external requirements" — and is the genuine cap, independent of whether the lost asset is yield or principal. There is no insolvency (SYA holds no strategy principal; it pulls payment from the claimer), and the brick variant is fail-safe.

**Plausible-High dissent (recorded for the severity-auditor).** A reasonable judge could still rate this Plausible-High even on the corrected (asymmetric partial-misconfiguration) framing: the required state — reward token configured, a single strategy token's `setTokenConfig` forgotten — is a realistic operational slip, most plausibly for a strategy added after launch, on exactly the 6-decimal stablecoins a "stable yield accumulator" is built for, and it carries **no hard owner signal** (`calculateClaimAmount` merely previews `0`, a soft cue a busy owner can miss). Impact-on-trigger is unambiguous, permissionless, repeatable, machine-verified 100% theft. Under that reading the partial misconfiguration is a plausible-enough real deployment that the "external requirement" reads more like an expected operational state than a mitigating assumption, i.e. direct loss via a valid path. This dissent is preserved but **not sustained as the primary ruling** — the no-precondition slice is empty and the precondition is attacker-uninducible — so it does not move the primary severity off Medium. The Medium-vs-High delta does not change remediation urgency: the fix is mandatory either way.

### Relationship to known issues and ledger L-01

- **KI#8** documents only the *value* the `(0,0)` struct resolves to (18-dec + 1:1 rate). It does **not** document the *consequence* — that leaving this default on a registered sub-18-decimal *strategy* token while the reward token is configured at sub-18 decimals enables a permissionless, zero-payment, 100%-of-yield drain (and that the mirror omission on the reward token is a fail-safe brick). The hazard is the missing enforcement on a partial config, not the default value.
- **KI#2** blesses the normalization *math* for **configured** tokens only; it says nothing about the unconfigured/in-use case.
- **KI#4 / KI#5** cover the depeg / discount owner-drain framing (the separate, suppressed C-01 centralization item) — a different root cause.
- **Ledger L-01** is the *standalone* zero-payment floor and is dust-only Low; it must **not** be re-escalated. M-01 is the amplified, exploitable form that weaponizes that floor ~`1e12x` via a decimal misconfiguration. Both entries are kept and cross-linked.

## Recommended mitigation steps

Make the unconfigured state **fail-closed**, not fail-open. Any one of the following closes the drain; shipping both the enforcement and the defense-in-depth check is recommended.

Add an explicit `configured` flag to `TokenConfig`, set only by `setTokenConfig`, and reject use of an unconfigured token instead of silently assuming 18 decimals:

```solidity
struct TokenConfig {
    uint8 decimals;
    uint256 normalizedExchangeRate;
    bool paused;
    bool configured; // NEW: distinguishes a real (0,0) config from "never set"
}

error TokenNotConfigured(address token);

function setTokenConfig(address token, uint8 decimals, uint256 normalizedExchangeRate) external onlyOwner {
    if (token == address(0)) revert ZeroAddress();
    if (decimals > 18) revert InvalidDecimals();
    tokenConfigs[token].decimals = decimals;
    tokenConfigs[token].normalizedExchangeRate = normalizedExchangeRate;
    tokenConfigs[token].configured = true; // NEW
    emit TokenConfigSet(token, decimals, normalizedExchangeRate);
}

function _normalizeAmount(uint256 amount, address token) internal view returns (uint256) {
    TokenConfig storage cfg = tokenConfigs[token];
    if (!cfg.configured) revert TokenNotConfigured(token); // was: silent 18-dec passthrough
    // ...existing scaling using cfg.decimals / cfg.normalizedExchangeRate...
}
// apply the identical !configured guard in _denormalizeAmount (replacing the L622-L624 fallback)
```

Enforce configuration at the registration / wiring sites so an unconfigured token can never become in-use:

```solidity
function addYieldStrategy(address strategy, address token) external onlyOwner {
    if (strategy == address(0)) revert ZeroAddress();
    if (token == address(0)) revert ZeroAddress();
    if (!tokenConfigs[token].configured) revert TokenNotConfigured(token); // NEW
    // ...
}

function setRewardToken(address _rewardToken) external onlyOwner {
    if (_rewardToken == address(0)) revert ZeroAddress();
    if (!tokenConfigs[_rewardToken].configured) revert TokenNotConfigured(_rewardToken); // NEW
    rewardToken = _rewardToken;
}
```

(Equivalently, fold the decimals argument directly into `addYieldStrategy`'s signature so a strategy cannot be registered without them.)

### Defense in depth

Regardless of which enforcement is chosen, reject a non-zero delivered yield that prices to a zero payment. This also hardens the standalone L-01 floor:

```solidity
uint256 actualPayment = _denormalizeAmount(claimerPayment, rewardToken);
if (actualPayment == 0) revert ZeroAmount(); // non-zero yield must cost a non-zero payment
```

Safe config order with the enforcement in place: call `setTokenConfig` for a token **before** `addYieldStrategy` / `setRewardToken` references it, and ship a deploy checklist requiring every strategy token and the reward token to be configured before claims are enabled. The `configured` flag additionally resolves PARK-08 (a genuine 0-decimal token is otherwise indistinguishable from an unconfigured one).

### Proof of concept

A passing Foundry PoC drives the **real** `src/StableYieldAccumulator.sol` `claim()` through `_normalizeAmount` (L489) and `_denormalizeAmount` (L498) over interface-faithful mocks (`skimSurplus` performs a genuine ERC20 transfer of the underlying to the claimer, so yield delivery is real, not faked). It runs against the project's own Foundry suite in `workspace/`.

File:

```
workspace/stable-yield-accumulator/test/poc-M-01.t.sol
```

Run:

```bash
cd workspace/stable-yield-accumulator && forge test --match-path 'test/poc-M-01.t.sol' -vvv
```

The drain test registers a 6-decimal strategy token and deliberately omits the one `setTokenConfig` call (the reward token is configured correctly at 6 decimals):

```solidity
function test_M01_unconfiguredStrategyToken_drainsYieldForZeroPayment() public {
    sya.addYieldStrategy(address(strat), address(stratToken));
    // <-- MISSING: sya.setTokenConfig(address(stratToken), 6, 1e18);  (the single forgotten call)

    strat.setSurplus(address(stratToken), yieldClient, 0, YIELD_NATIVE); // 1_000e6
    stratToken.mint(address(strat), YIELD_NATIVE);

    uint256 quotedPayment = sya.calculateClaimAmount(new address[](0)); // preview already advertises 0

    vm.prank(claimer);
    sya.claim(NFT_INDEX, 0, new address[](0)); // minRewardTokenSupplied = 0

    assertEq(yieldDelivered, YIELD_NATIVE, "claimer received 100% of the skimmed yield");
    assertEq(rewardPaid, 0, "DRAIN: claimer paid ZERO reward token for real yield");
    assertEq(quotedPayment, 0, "preview already advertised a 0 payment (no owner signal)");
    assertEq(phlimboReceived, 0, "phlimbo / Limbo stakers received nothing");
    assertEq(syaReceived, 0, "SYA retained nothing");
}
```

The control test is identical except it includes the forgotten `setTokenConfig`, proving the gap is the single missing call and not the amount:

```solidity
function test_M01_control_configuredStrategyToken_paysFullProportionally() public {
    sya.addYieldStrategy(address(strat), address(stratToken));
    sya.setTokenConfig(address(stratToken), 6, 1e18); // THE FIX: the one call forgotten above
    // ...same 1_000e6 yield, same claim...
    assertEq(rewardPaid, YIELD_NATIVE, "configured token charges the FULL proportional payment");
    assertEq(phlimboReceived, YIELD_NATIVE, "phlimbo received the full payment");
}
```

Captured output (`2 passed; 0 failed; 0 skipped`):

```
=== M-01 DRAIN (strategy token left UNCONFIGURED) ===
quoted payment (calculateClaimAmount): 0
yield delivered to claimer (6-dec):     1000000000   // 1000e6 real underlying out
actual reward paid by claimer:          0            // zero paid in
reward received by phlimbo:             0
reward retained by SYA:                 0

=== M-01 CONTROL (strategy token CONFIGURED) ===
actual reward paid by claimer:          1000000000   // full 1000e6 charged
reward received by phlimbo:             1000000000
```

This is independently corroborated by a halmos symbolic proof on real bytecode (SYMBOLIC-001 refutes `payment > 0` with a concrete counterexample; SYMBOLIC-002 proves the exact zero-payment region `totalNormalizedYield * (10000 - discountRate) / 10000 < 10**(18 - rewardTokenDecimals)`).

### Caveats and scope notes

To be precise about the boundaries of the PoC (disclosed honestly):

1. **Reward-token precondition for the clean zero.** The exact zero-payment result requires the **reward** token to be configured with fewer than 18 decimals. The PoC uses a 6-decimal USDC reward token, matching the spec's canonical reward token. With an 18-decimal reward token the mispricing manifests differently (not a clean zero).
2. **Exact zero holds below ~1,000,000 tokens/claim.** `rewardPaid == 0` is exact for per-claim skimmed yield below ~`1e12` native units (~`1,000,000` tokens at 6 decimals); above that the payment is a negligible ~`1e-12`-of-value dust — still an effective drain. The PoC's `1000`-token amount sits firmly in the floor-to-zero regime, so it is not amount-fragile.
3. **Workspace-relative PoC.** The PoC imports `src/StableYieldAccumulator.sol` and `test/mocks/SYAMocks.sol` via the project's remappings — correct and required for a workspace run against the project suite. A literal C4 paste would require inlining the `src` contract and the mocks.
