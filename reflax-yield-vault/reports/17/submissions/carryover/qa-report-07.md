> **Carryover QA report — audit 07** (cut down from `reports/reflax-yield-vault/07/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 17): **L-03, L-04, L-05, L-07**.
> Removed as no longer live / carried elsewhere: L-01 and C-01 (originating audit is **05** — carried in `qa-report-05.md`, not here); L-02 (**wont-fix**).
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping** (originating report label → ledger entry):
> - `L-03` → L-03 / `1a4e3e8f13bdc492`
> - `L-04` → L-04 / `b51876fec3edfc30`
> - `L-05` → L-05 / `efcdb9dc8ff03289` **and** L-06 / `0f534a726502d274` (this run-07 section covers both ledger entries)
> - `L-07` → L-07 / `b28e77daefb32529`

*The text below is a verbatim copy of the retained sections of the original report.*

---

### [L-03] No aggregate cap on per-client `setAsideBuffer` — recipient take can collapse to zero <!-- id: ryv7l3 -->

**Origin:** New at reflax-yield-vault-07 (story-042). Extends C-01.

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

### [L-04] Stale `setAsideBufferSize` survives `setClient(_, false)` and silently re-activates on re-add <!-- id: ryv7l4 -->

**Origin:** New at reflax-yield-vault-07 (story-042). Extends C-01.

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

### [L-05] Buffered-path integration transparency — event and return-value drift <!-- id: ryv7l5 -->

**Origin:** New at reflax-yield-vault-07 (story-042). Folds L-06 (`ryv7l6` — return-value semantics) as a sub-point per finding-manager guidance: both address the same buffered-path integration surface and a single documentation/event fix-direction resolves both.

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

### [L-07] `setRoute` accepts identity and zero-gap paths <!-- id: ryv7l7 -->

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
