# QA Report — phoenix-vault (reflax-yield-vault)

**Run:** `phoenix-vault-07`
**Submodule:** `lib/reflax-yield-vault`
**Commit:** `5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6`
**Baseline:** `phoenix-vault-06` (`043ff2cb5ee9808961b50311fb5ecb742b63a6e9`)
**Story under review:** story-042 — per-client `setAsideBuffer` added to `skimSurplus`
**Scope:** `src/AYieldStrategy.sol`, `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`, `src/AMMAdapters/CurveAMMAdapter.sol`, `src/AMMAdapters/IAMMAdapter.sol`, `src/AMMAdapters/ICurveRouterNG.sol`, `src/interfaces/IYieldStrategy.sol`

This report bundles all open Low-severity and Centralization findings for the engagement. High/Medium findings (this run: M-04) are submitted separately. An automated SAST/gas baseline produced by **4naly3er** is attached as an appendix.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 6 (L-01, L-02, L-03, L-04, L-05 (folds L-06), L-07) |
| Centralization | 1 (C-01) |
| **Total** | **7** |

| ID | Origin | Title |
|----|--------|-------|
| [L-01](#l-01-slippagetolerancebps-default-0-and-setter-has-no-upper-cap) | carry-forward (open since run-05) | `slippageToleranceBps` default-0 and setter has no upper cap |
| [L-02](#l-02-skimsurplus-iterates-the-full-authorized-client-set-no-pagination-wont-fix) | carry-forward (`wont-fix`) | `skimSurplus` iterates the full authorized-client set, no pagination |
| [L-03](#l-03-no-aggregate-cap-on-per-client-setasidebuffer-recipient-take-can-collapse-to-zero) | new | No aggregate cap on per-client `setAsideBuffer` — recipient take can collapse to zero |
| [L-04](#l-04-stale-setasidebuffersize-on-client-re-add) | new | Stale `setAsideBufferSize` survives `setClient(_, false)` and silently re-activates on re-add |
| [L-05](#l-05-buffered-path-integration-transparency-event-and-return-value-drift) | new (folds L-06) | Buffered-path integration transparency — `SurplusSkimmed` under-represents beneficiaries and return value is path-dependent |
| [L-07](#l-07-setroute-accepts-identity-and-zero-gap-paths) | carry-forward (LOCAL-008 re-elevated) | `setRoute` accepts `tokenIn == tokenOut` and paths with internal zero-gap segments |
| [C-01](#c-01-owner-power-bundle-centralization-envelope) | carry-forward (extended this run) | Owner-power bundle / centralization envelope |

L-06 was classified by both classifier and finding-manager as a folding candidate with L-05; this bundle folds it into L-05 as a second sub-point ("Return-value semantics") rather than reporting it separately, because both findings address the same buffered-path integration-transparency surface and a single fix-direction resolves both.

---

## Low Risk Findings

### [L-01] `slippageToleranceBps` default-0 and setter has no upper cap <!-- id: pv7l1 -->

**Status:** Reconfirmed OPEN at phoenix-vault-07. Originally reported in [`reports/phoenix-vault-05/submissions/qa-report.md`](../../phoenix-vault-05/submissions/qa-report.md). Carried forward unchanged — `setSlippageTolerance` (`ERC4626MarketYieldStrategy.sol#L190-L195`) is untouched by story-042. The full original write-up (uninitialized state + over-permissive `[0, MAX_BPS]` band) stands; refer to the phoenix-vault-05 report for code excerpts.

**Location:**
- [`ERC4626MarketYieldStrategy.sol#L40`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L40) — `uint256 public slippageToleranceBps;` (no initializer)
- [`ERC4626MarketYieldStrategy.sol#L190-L195`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190-L195) — `setSlippageTolerance` (only checks `_bps <= MAX_BPS`)

**Impact:** Availability-until-configured on a fresh deploy (default-0 ⇒ swap must clear at exact NAV, which any non-zero fee/spread defeats) and an over-permissive parameter band that defeats the purpose of the protective floor.

**Run-07 note (cross-link with M-04):** M-04 (this run) demonstrates that under non-zero aggregate buffer `f`, the recipient's effective slippage is amplified to `slippageToleranceBps / (1 - f)`. M-04 recommendation (1) — "enforce `slippageToleranceBps <= MAX_SLIPPAGE_BPS` with a tight protocol-policy ceiling and a non-zero floor" — **is the precise resolution L-01 has been asking for**. Implementing M-04 rec (1) closes L-01 as a by-product; this QA item is retained so the carry-forward record stays accurate. No additional recommendation needed beyond M-04 rec (1).

---

### [L-02] `skimSurplus` iterates the full authorized-client set, no pagination (`wont-fix`) <!-- id: pv7l2 -->

**Status:** Reconfirmed `wont-fix` carry-forward at phoenix-vault-07. Original entry in [`reports/phoenix-vault-05/submissions/qa-report.md`](../../phoenix-vault-05/submissions/qa-report.md), restated/narrowed at phoenix-vault-06 (the zero-address whole-batch revert sub-vector was structurally resolved by story-041; the unbounded-loop sub-vector persists in transformed form). Author acknowledgement: *"This is almost certainly unlikely to become an issue as we're likely to never have more than 3 clients."* Recorded here for completeness; no fix expected.

**Location:** [`ERC4626MarketYieldStrategy.sol#L419-L429`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L419-L429) (snapshot-accrual loop) and [`#L511-L519`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L511-L519) (distribution loop, new in story-042).

**Run-07 note:** story-042 ADDS a parallel iteration (`_distributeBuffer`) plus a fresh `new uint256[](clients.length)` allocation on each skim, **doubling the per-iteration constant factor** but not the asymptotic bound (`O(n)` over the owner-grown authorized-client set is unchanged). The pattern-matcher and slither calls-loop signal (SA-007 / PATTERN-003) consolidate into this entry. Per `wont-fix` triage, no recommendation is restated; the author's bounded-client-count posture remains authoritative.

---

### [L-03] No aggregate cap on per-client `setAsideBuffer` — recipient take can collapse to zero <!-- id: pv7l3 -->

**Origin:** New at phoenix-vault-07 (story-042). Extends C-01.

**Location:**
- [`AYieldStrategy.sol#L253-L259`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AYieldStrategy.sol#L253-L259) — `setSetAsideBuffer` (per-client `bufferPercent <= 100` check only)
- [`ERC4626MarketYieldStrategy.sol#L503-L521`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L503-L521) — `_distributeBuffer` (silent collapse to `toRecipient == 0`)

**Description:**

`setSetAsideBuffer` enforces only the per-client ceiling `bufferPercent <= 100`. The sum of `setAsideBufferSize[client]` across the authorized-client set is never checked. With multiple clients at high buffer percentages, the principal-weighted sum used by `_accrueSurplusShares` (`L487`: `shares * setAsideBufferSize[client] / 100`) can drive `totalBufferShares` toward `totalShares`. In `_distributeBuffer`:

```solidity
// L518-L519
toRecipient = underlyingReceived - totalSetAside;
if (toRecipient > 0) underlyingToken.safeTransfer(recipient, toRecipient);
```

At a sum-weighted buffer fraction `f = totalBufferShares / totalShares == 1`, `toRecipient == 0`, the skim completes successfully with no revert, and the `recipient` parameter of `skimSurplus(token, recipient)` is effectively a no-op. The withdrawer's call still emits `SurplusSkimmed` events naming `recipient`, but `recipient` receives nothing while every wei flows to the authorized clients.

**Impact:** No direct loss — all funds remain protocol-owned (set-aside slices go to authorized clients). The withdrawer (and any downstream integrator pricing in expected yield from `skimSurplus`) sees zero proceeds despite the swap consuming all surplus value and incurring slippage. Companion enabler for M-04's worst-case parametric leak (as `f → 1`, `1/(1-f) → ∞`).

**Recommended action (revert on misconfiguration, per `feedback_revert_over_silent_clamp`):**

Track an aggregate buffer-weight metric on `setSetAsideBuffer` calls and enforce a configurable ceiling, e.g. on the *unweighted* sum of `bufferPercent` values, or on the principal-weighted projection. A revert-loud option:

```solidity
uint256 public constant MAX_AGGREGATE_BUFFER_BPS = 9000; // 90%, policy choice
uint256 public aggregateBufferUnweighted; // sum of per-client bufferPercent

function setSetAsideBuffer(address client, uint256 bufferPercent) external onlyOwner {
    require(client != address(0), "...");
    require(bufferPercent <= 100, "...");
    uint256 old = setAsideBufferSize[client];
    uint256 newAgg = aggregateBufferUnweighted - old + bufferPercent;
    require(newAgg * 100 <= MAX_AGGREGATE_BUFFER_BPS, "aggregate buffer exceeds cap");
    aggregateBufferUnweighted = newAgg;
    setAsideBufferSize[client] = bufferPercent;
    emit SetAsideBufferSet(client, old, bufferPercent);
}
```

Alternatively, add a require in `_distributeBuffer` rejecting `toRecipient == 0 && underlyingReceived > 0` so an all-clients-at-100% misconfiguration reverts loudly rather than silently zeroing the recipient. Prefer the setter-side revert because it surfaces the bad configuration at the moment it is set, not on a skim hours/days later.

---

### [L-04] Stale `setAsideBufferSize` survives `setClient(_, false)` and silently re-activates on re-add <!-- id: pv7l4 -->

**Origin:** New at phoenix-vault-07 (story-042). Extends C-01.

**Location:**
- [`AYieldStrategy.sol#L183-L193`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AYieldStrategy.sol#L183-L193) — `setClient` (no buffer-clear on deauth)
- [`AYieldStrategy.sol#L253-L259`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AYieldStrategy.sol#L253-L259) — `setSetAsideBuffer` (no membership guard)
- [`ERC4626MarketYieldStrategy.sol#L487`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L487) — child reads parent storage via `setAsideBufferSize[client]`

**Description:**

`setClient(client, false)` removes `client` from `_authorizedClients` but does not zero `setAsideBufferSize[client]`. Symmetrically, `setSetAsideBuffer` writes the per-client buffer with no `_authorizedClients.contains(client)` precondition. As a result, the invariant *"`setAsideBufferSize[client] != 0` ⇒ `_authorizedClients.contains(client)`"* does **not** hold.

Sequence:
1. Owner: `setSetAsideBuffer(clientA, 50)` → `setAsideBufferSize[clientA] = 50`.
2. Owner: `setClient(clientA, false)` → `_authorizedClients` drops `clientA`; `setAsideBufferSize[clientA]` still 50.
3. Owner re-adds: `setClient(clientA, true)` (e.g. post-incident, after address rotation).
4. Next `skimSurplus`: `_accrueSurplusShares` reads `setAsideBufferSize[clientA] = 50` and diverts 50% of `clientA`'s principal-weighted surplus to `clientA` — even though no fresh `setSetAsideBuffer` call was made in this re-auth cycle.

**Impact:** No direct loss; all funds remain protocol-owned (every client is a protocol-owned contract per the `setSetAsideBuffer` `AUDITOR NOTE` at `AYieldStrategy.sol#L246`). The misallocation is bounded by the size of the next skim and the stale buffer setting. The operator footgun is a realistic source of malformed configuration: an operator re-authorizing a previously-removed client is unlikely to think to also re-write the buffer to its intended new value.

**Recommended action (per `feedback_revert_over_silent_clamp`):**

Clear `setAsideBufferSize[client]` in `setClient(client, false)`:

```solidity
function setClient(address client, bool _auth) external override onlyOwner {
    require(client != address(0), "...");
    if (_auth) {
        _authorizedClients.add(client);
    } else {
        _authorizedClients.remove(client);
        uint256 old = setAsideBufferSize[client];
        if (old != 0) {
            setAsideBufferSize[client] = 0;
            emit SetAsideBufferSet(client, old, 0);
        }
    }
    emit ClientAuthorizationSet(client, _auth);
}
```

Additionally — or alternatively — require `_authorizedClients.contains(client)` in `setSetAsideBuffer` so writes to never-or-no-longer-authorized addresses revert. Option (a) is preferred because it establishes the invariant statelessly: a non-authorized client cannot carry a non-zero buffer regardless of which order setters are called in.

---

### [L-05] Buffered-path integration transparency — event and return-value drift <!-- id: pv7l5 -->

**Origin:** New at phoenix-vault-07 (story-042). Folds L-06 (`pv7l6` — return-value semantics) as a sub-point per finding-manager guidance: both address the same buffered-path integration surface and a single documentation/event fix-direction resolves both.

**Location:**
- [`ERC4626MarketYieldStrategy.sol#L484`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L484) — `SurplusSkimmed` emit
- [`ERC4626MarketYieldStrategy.sol#L511-L519`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L511-L519) — silent `safeTransfer(clients[i], buf)` per surplus-bearing client
- [`ERC4626MarketYieldStrategy.sol#L443-L446`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L443-L446) — fast-path return (gross swap output)
- [`ERC4626MarketYieldStrategy.sol#L450`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L450), [`L518-L520`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L518-L520) — buffered-path return (`toRecipient = underlyingReceived - totalSetAside`)
- [`AYieldStrategy.sol#L352-L357`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AYieldStrategy.sol#L352-L357) — interface NatSpec (path-agnostic)

**Description (two sub-points framed against a single integration contract):**

**(a) `SurplusSkimmed` under-represents buffered-path beneficiaries.** On the buffered path, `_distributeBuffer` (`L511-L519`) executes one `underlyingToken.safeTransfer(clients[i], buf)` per surplus-bearing client whose `setAsideBufferSize[client] > 0`. The only event emitted across the skim is `SurplusSkimmed(token, client, msg.sender, surplus, recipient)` in `_accrueSurplusShares` (`L484`), which (i) reports the *snapshot* surplus in vault-asset terms (pre-redeem/pre-swap), not the actual underlying received per client, and (ii) names `recipient` as the receiver even when most of the proceeds for that client actually go to `clients[i]`. No event marks the buffer-redirected transfer. An indexer reconstructing fund flow from `SurplusSkimmed` will attribute the entire surplus to `recipient` and miss the per-client buffer transfers entirely.

**(b) `skimSurplus` return-value semantics are path-dependent.** The fast path (`L443-L446`, `totalBufferShares == 0`) returns `underlyingReceived` — the gross swap output, which on the fast path *is* the amount delivered to `recipient`. The buffered path (`L450` → `_distributeBuffer`) returns `toRecipient = underlyingReceived - totalSetAside` — the **net** amount delivered to `recipient`. Both paths consistently return "what arrived at `recipient`", and an integrator anchoring a slippage floor against the return value is protected by construction (the buffered-path return is more conservative). The risk is documentation/maintainability: the interface NatSpec at `AYieldStrategy.sol#L352-L357` is path-agnostic, and a future refactor that adds a fast-path buffer or tax would silently change the semantics on that path. Per `feedback_per_repo_audit_scope`, this is framed as a submodule-contract clarification, not a consumer-side audit gap — the consumer cannot tighten the contract on its end.

**Impact:** No direct loss today. Off-chain accounting drift for any indexer or reconciliation pipeline consuming `SurplusSkimmed` as the authoritative receipt event under the buffered path. Documentation/maintainability hazard for the return-value semantic on future fast-path extension.

**Recommended action (single coordinated fix):**

1. **Event:** Add a `SurplusBuffered(address indexed token, address indexed client, uint256 amount)` event in `_distributeBuffer` emitted whenever `buf > 0`, and either (i) also emit a `SurplusForwarded(token, recipient, amount)` for `toRecipient`, or (ii) extend the existing `SurplusSkimmed` event with a `bufferAmount` field and re-emit it from `_distributeBuffer` instead of `_accrueSurplusShares`. An indexer can then sum buffer transfers and forwarded amounts independently of the snapshot-surplus figures.
2. **NatSpec / return-value contract:** Tighten the `skimSurplus` NatSpec on `AYieldStrategy.sol#L352-L357` (and on `IYieldStrategy`) to make the semantic explicit:

   > Returns the actual underlying delivered to `recipient`. On the buffered path this is reduced by the sum of all per-client set-aside transfers; the gross swap output can be recovered by summing the `SurplusBuffered` events plus the return value.

3. **(Optional, minor-version)** Introduce a two-return-value variant — `(uint256 toRecipient, uint256 totalSwapped)` — so the gross/net split is on-chain rather than reconstructed from events.
4. **Unit test:** Assert return-value equality on both paths (gross == net when no buffer) and the buffered-path drift `gross - net == sum(buf_i)`.

---

### [L-07] `setRoute` accepts identity and zero-gap paths <!-- id: pv7l7 -->

**Origin:** Carry-forward of LOCAL-008 (CurveAMMAdapter unchanged by story-042; contract-profile confirms no diff in `src/AMMAdapters/` between `043ff2c` and `5f9abdd`). First-time ledger appearance, surfaced fresh this run via convergent slither + aderyn + profiler + code-scanner signals. Extends C-01.

**Location:** [`CurveAMMAdapter.sol#L62-L89`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AMMAdapters/CurveAMMAdapter.sol#L62-L89) — `setRoute`; see also [`L74`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AMMAdapters/CurveAMMAdapter.sol#L74) (uninitialized `lastToken` flagged by slither SA-005; functionally safe today because `path[0] != 0` ⇒ `lastToken >= tokenIn` after the loop).

**Description:**

`setRoute` validates only four properties: `tokenIn != 0`, `tokenOut != 0`, `path[0] == tokenIn`, and the last non-zero entry in `path` equals `tokenOut`. It does **not** check:

- `tokenIn != tokenOut` — an identity route is accepted.
- That `path` is contiguously non-zero up to the last token slot — e.g. `[tokenIn, 0, pool, 0, tokenOut, 0, ...]` with an internal zero gap passes (`path[0]` ok, last non-zero entry `== tokenOut`).
- That `swapParams` and `pools` are consistent with the path topology.

Verification of these properties is fully delegated to off-chain procedures (per submodule CLAUDE.md *AMM Route Configuration* section). The on-chain `setRoute` is the strategy's only on-chain interface for route correctness, and it has no defense-in-depth against a malformed payload from a deployment script or operator submission.

**Impact:** No direct theft — Curve Router NG enforces `minAmountOut` at the AMM and the strategy layer applies a NAV-anchored `minOut` on top. The realistic outcome is **strategy DoS**: the first swap against a malformed route reverts at the router or produces zero output, and deposit/withdraw/`skimSurplus` revert until the operator re-runs `setRoute` with a corrected payload. Availability-only, bounded by time-to-fix. Owner-only setter — same trust boundary as the rest of the centralization envelope.

**Recommended action (revert on malformed input, per `feedback_revert_over_silent_clamp`):**

```solidity
function setRoute(
    address tokenIn,
    address tokenOut,
    address[11] calldata path,
    uint256[5][5] calldata swapParams,
    address[5] calldata pools
) external onlyOwner {
    require(tokenIn != address(0), "CurveAMMAdapter: tokenIn cannot be zero");
    require(tokenOut != address(0), "CurveAMMAdapter: tokenOut cannot be zero");
    require(tokenIn != tokenOut, "CurveAMMAdapter: identity route"); // (a)
    require(path[0] == tokenIn, "CurveAMMAdapter: path[0] must equal tokenIn");

    // (b) walk the path enforcing no internal zero-gap segment.
    // After the first zero is observed, no further non-zero entry is allowed.
    bool tailReached = false;
    address lastToken = tokenIn;
    for (uint256 i = 1; i < 11; i++) {
        if (path[i] == address(0)) {
            tailReached = true;
        } else {
            require(!tailReached, "CurveAMMAdapter: internal zero-gap in path");
            lastToken = path[i];
        }
    }
    require(lastToken == tokenOut, "CurveAMMAdapter: path must end at tokenOut");

    Route storage r = routes[tokenIn][tokenOut];
    r.path = path;
    r.swapParams = swapParams;
    r.pools = pools;
    r.configured = true;

    emit RouteSet(tokenIn, tokenOut);
}
```

The require-loud form is preferred over silent clamping (e.g. truncating the path at the first zero) so the operator learns of the malformed payload at submission time rather than at first-swap time. Off-chain verification remains valuable as a first line of defense; on-chain validation is defense-in-depth against the realistic "typo or copy-paste error in a deployment script" path, which off-chain procedure cannot rule out.

---

## Centralization Risks

### [C-01] Owner-power bundle / centralization envelope <!-- id: pv7c1 -->

**Status:** Reconfirmed OPEN at phoenix-vault-07. Original write-up in [`reports/phoenix-vault-05/submissions/qa-report.md`](../../phoenix-vault-05/submissions/qa-report.md). The trust model — owner is expected to be a trusted multisig acting in the protocol's and clients' interest; the authorized withdrawer can redirect yield/surplus only, never principal — remains the project's authoritative posture. This entry is retained for completeness and to track the envelope's growth across runs.

**Owner-power surface as of `5f9abdd`:**
- `setRoute` ([`CurveAMMAdapter.sol#L62-L89`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AMMAdapters/CurveAMMAdapter.sol#L62-L89)) — full AMM-route control.
- `setSlippageTolerance` ([`ERC4626MarketYieldStrategy.sol#L190-L195`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L190-L195)) — protective floor (see L-01 and M-04).
- `depositAsOwner` / `withdrawAsOwner` — owner moves positions on behalf of the strategy.
- `emergencyWithdraw` + the two-phase total-withdrawal timelock (24h wait / 48h execute, inherited from `AYieldStrategy`).
- `setClient(address, bool)` ([`AYieldStrategy.sol#L183-L193`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AYieldStrategy.sol#L183-L193)) — owner-managed `_authorizedClients` set.
- **`setSetAsideBuffer(address, uint256)` ([`AYieldStrategy.sol#L253-L259`](https://github.com/Behodler/reflax-yield-vault/blob/5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6/src/AYieldStrategy.sol#L253-L259)) — NEW IN STORY-042.** Per-client buffer percentage routing surplus back to clients on each skim.
- `setWithdrawer` — authorized-withdrawer role management.
- `setPauser` / pause control (inherited).
- Skim recipient selection (`skimSurplus(token, recipient)`) — withdrawer-gated, yield-only.

**Run-07 envelope growth (story-042):** the envelope expanded by one setter (`setSetAsideBuffer`) and one piece of per-client state (`setAsideBufferSize[client]`). Three new Lows extend this envelope as specific setter-design defects within it:

- **L-03** — no aggregate cap on `setSetAsideBuffer`; sum-weighted buffer reaching 100% silently zeros the recipient take.
- **L-04** — `setAsideBufferSize[client]` is not cleared on `setClient(_, false)`; the stale value silently re-activates on re-auth.
- **L-07** — `CurveAMMAdapter.setRoute` accepts identity and zero-gap paths with no on-chain defense-in-depth.

Each of L-03/L-04/L-07 should be read as a *setter-design defect within* the C-01 envelope, not as separate centralization findings: even a benevolent multisig owner has no in-contract defense against a fat-finger across these surfaces, which is the gap the recommendations on those entries address.

**Impact:** Unchanged from the original write-up. Yield/route/slippage/emergency redirection on owner-key compromise; principal accounting remains protected by the verified withdrawer-yield-only boundary and the two-phase total-withdrawal timelock.

**Recommended action (unchanged from phoenix-vault-05 + run-07 additions):**
- Hold the owner role in a multisig; consider a timelock on `setRoute`, `setSlippageTolerance`, and now `setSetAsideBuffer` so route, slippage, and buffer changes are observable before they take effect.
- Emit events (with old/new values) on every privileged parameter change. `setSlippageTolerance` already does; `setRoute` does not include old/new values (and cannot easily, given the 11-slot path); `setSetAsideBuffer` already does (`SetAsideBufferSet(client, old, bufferPercent)`).
- Implement the L-03 / L-04 / L-07 setter-side recommendations as defense-in-depth within the envelope; they reduce blast radius from operator footgun without altering the trust model.
- Document the trust model (owner = trusted multisig; withdrawer = yield-only; clients = protocol-owned) prominently for integrators so the boundary between redirectable yield and protected principal stays explicit even as the envelope grows.

---

## Appendix — Automated analysis (4naly3er)

The automated C4-style SAST/gas report below was produced by **4naly3er** over the seven in-scope source files at commit `5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6`. It is included as the standard bot-report baseline. Items here are largely gas/best-practice and informational; where they overlap the manual findings above (notably the missing-validation patterns around setters and the in-loop array length cache), the manual findings are authoritative.

**How it was run:**

```bash
# In-scope sources staged with @openzeppelin and the pauser/IPausable
# remapping flattened under node_modules/ so 4naly3er's solc resolver can
# compile the AST cleanly (the lib only ships interface shims of the
# pauser sibling submodule, which 4naly3er cannot follow via remappings.txt).
cd tools/4naly3er
yarn analyze <stage>/src <stage>/scope.txt
```

The full markdown is in [`4naly3er-report.md`](./4naly3er-report.md). Summary of categories surfaced (counts are 4naly3er's category buckets, not per-instance):

- **Gas Optimizations (16 categories):** GAS-1 `a = a + b` vs `a += b` for state vars; GAS-2 assembly `address(0)` check; GAS-3 bool storage overhead; GAS-4 cache array length outside loop (relevant to the two skim loops noted in L-02); GAS-5 cache state vars in stack; GAS-6 `unchecked` for non-overflowing ops; GAS-7 custom errors vs revert strings; GAS-8 avoid existence checks via low-level calls; GAS-9 single-use stack caches; GAS-10 constructor-only state should be `immutable`; GAS-11 mark privileged-revert functions `payable`; GAS-12 `++i` over `i++`; GAS-13 `private` constants over `public`; GAS-14 avoid `this` for external; GAS-15 unchecked for-loop increments; GAS-16 `!= 0` over `> 0`.
- **Non-Critical (22 categories):** NC-1 zero-address checks on state assignment; NC-2 enum indices; NC-3 `string.concat` over `abi.encodePacked`; NC-4 magic numbers (the `100` divisor in `setAsideBufferSize` math is a representative instance); NC-5 control-structure style; NC-6 disable `renounceOwnership()`; NC-7 duplicated requires; NC-8/NC-20 missing-indexed event fields; NC-9 events should carry old+new values (already done on `SlippageToleranceSet` and `SetAsideBufferSet`); NC-10/NC-17 layout/style ordering; NC-11 functions longer than 50 lines (`_skimSurplus`); NC-12 checks in setters (overlaps L-03, L-04, L-07); NC-13 modifier vs `require` for special `msg.sender`; NC-14 named mappings; NC-15 renounce-while-paused; NC-16 redundant `return` w/ named returns; NC-18 number-literal underscores; NC-19 internal naming convention; NC-21 `public` → `external`; NC-22 explicit zero init.
- **Low (13 categories):** L-1 `approve()`/`safeApprove()` zero-baseline revert (overlaps the `safeIncreaseAllowance` pattern in `_skimSurplus`); L-2 / L-11 two-step ownership / `Ownable2Step` (carries weight against C-01's owner-key concentration); L-3 zero-value transfer reverts on weird ERC-20s; L-4 zero-address checks on state assignment; L-5 `abi.encodePacked` with dynamic types into hashes; L-6 division-by-zero not prevented; L-7 renounce-while-paused; L-8 rounding; L-9 loss of precision; L-10 `PUSH0` on non-mainnet under 0.8.20+; L-12 assembly-optimizer-bug-susceptible solc; L-13 unsafe ERC20 ops.
- **Medium (3 categories):** M-1 fee-on-transfer token accounting (per project known-invalid list, fee-on-transfer is out of scope unless explicitly in scope; recorded for completeness); M-2 centralization risk for trusted owners (overlaps C-01; the manual write-up is authoritative); M-3 `increaseAllowance`/`decreaseAllowance` revert on mainnet USDT (the strategy uses `safeIncreaseAllowance` against the vault token, not USDT; not impactful on the in-scope deployment, but worth flagging for any future USDT-collateralized strategy variant).

See the attached report for per-instance line references and code links.
