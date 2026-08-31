# reflax-yield-vault-07 — Contract Profile (Tier 1, regression mode)

- **Target commit:** `5f9abdd` (story-042)
- **Baseline:** `043ff2c` (reflax-yield-vault-06)
- **Story-042 surface:** `_skimSurplus` rewrite with per-client `setAsideBuffer` distribution
- **Canonical artefact:** `reports/reflax-yield-vault/07/contract-profile.json`

## In-scope contracts

| Contract | LOC | Verified local props | New local findings | Story-042 changed? |
|---|---|---|---|---|
| `ERC4626MarketYieldStrategy.sol` | 522 | nonReentrant on all external entry points; checked arithmetic (buffer% ≤ 100 enforced in parent); snapshot semantics preserved; aggregate-surplus ceiling intact; CEI deviations pre-existing (covered by guard) | LOCAL-001..005 (all info / advisory) | **Yes** — `_skimSurplus` factored into `_accrueSurplusShares` + `_distributeBuffer`; FAST PATH (no buffers) preserves baseline behaviour |
| `CurveAMMAdapter.sol` | 142 | onlyOwner on `setRoute`; bidirectional invariant in `swap`; constant-bounded loop in `setRoute` | LOCAL-006..008 (all low / info) | No |
| `IAMMAdapter.sol` | 23 | interface-only | — | No |
| `ICurveRouterNG.sol` | 35 | interface-only | — | No |
| `AMMRoutes.json` | (config) | bidirectional routes present; EIP-55 checksummed; i/j mirrored | LOCAL-009 (info — possible 2-hop redundancy) | No |

## story-042 delta — quick reference for downstream agents

### What changed in `_skimSurplus`
1. **Signature:** now returns `uint256 underlyingReceived`.
2. **Body:** split into two private helpers:
   - `_accrueSurplusShares(...)` — snapshot loop, emits `SurplusSkimmed` per surplus-bearing client, populates `bufferShares[]` out-param, accumulates `totalShares` (used by the M-01 aggregate-surplus ceiling) **before** the buffer-share reassignment.
   - `_distributeBuffer(...)` — second pass: `safeTransfer(clients[i], buf)` per surplus-bearing client where `buf = underlyingReceived * bufferShares[i] / totalShares`, remainder to `recipient`.
3. **Fast path / buffered path split:** when `totalBufferShares == 0` (the default, since `setAsideBufferSize` defaults to 0), the code falls through to the baseline single `safeTransfer(recipient, underlyingReceived)`.

### What is preserved
- Single aggregate swap (M-01 fix structure intact).
- `minOut = convertToAssets(totalShares) * (MAX_BPS - slippageToleranceBps) / MAX_BPS` — same NAV-anchored derivation as baseline (M-02 carries through unchanged).
- Aggregate-surplus ceiling `require(totalShares <= vault.convertToShares(aggregateSurplus), ...)` — same defensive bound, evaluated on pre-buffer `totalShares`.
- `clientBalances` / `totalDeposited` principal accounting still untouched by the skim path.

### What is new in trust surface
- Parent `setAsideBufferSize[client]` (mapping in `AYieldStrategy`) is read inside the loop — relies on the parent's `setSetAsideBuffer` to enforce `bufferPercent <= 100`. No other write path exists.
- New per-client `safeTransfer(clients[i], buf)` external calls in the buffered path. Each `clients[i]` is owner-authorized via the `_authorizedClients` EnumerableSet (so attacker cannot inject arbitrary `clients[]`).
- The `SurplusSkimmed` event still reports the **snapshot** surplus with `recipient` as the receiver — under the buffered path the actual underlying flow per client diverges from this. Flagged as LOCAL-005 for code-scanner.

## Carry-forward findings (from reflax-yield-vault-06)

| Label | Title | Behaviour under story-042 |
|---|---|---|
| **M-01** | Over-skim via duplicate `clients[]` | FIXED — story-042 preserves the fix (caller-supplied list still removed; ceiling on pre-buffer `totalShares` still active) |
| **M-02** | NAV-anchored `minOut` sandwich leak | Unchanged — single aggregate swap with same `minOut` derivation; buffers redistribute proceeds, not slippage |
| **L-01** | `slippageToleranceBps` default-0 + no cap | Unchanged — `setSlippageTolerance` not modified |
| **L-02** | `skimSurplus` unbounded iteration | STILL APPLIES; story-042 adds a second parallel iteration + a per-skim memory allocation. Asymptotic bound unchanged (still owner-controlled set size). |
| **C-01** | Centralization bundle | AMPLIFIED — `setSetAsideBuffer` is a new owner power; AYieldStrategy NatSpec acknowledges the can-front-run-skim quirk and accepts it under the protocol-owned-clients assumption |

## Local findings produced this run

All informational / defensive-coding; none are exploitable on their own. See `contract-profile.json` for full text.

- **LOCAL-001** parallel-array coupling between `_accrueSurplusShares` and `_distributeBuffer` (verified safe; flagged so future refactors don't desync)
- **LOCAL-002** fresh memory allocation `new uint256[](clients.length)` per skim (composes with L-02 cost increase)
- **LOCAL-003** floor-division rounding in buffer payout favours `recipient` (consistent with protocol rounding convention)
- **LOCAL-004** local variable `shares` name-shadowed to mean "buffer shares" mid-function (readability, not a defect)
- **LOCAL-005** `SurplusSkimmed` event topology under buffered path — event names `recipient` and reports snapshot surplus, but part of the proceeds actually flow to `clients[i]`. Spec/event-consistency note; underlying tokens are not lost.
- **LOCAL-006** `CurveAMMAdapter.swap` leaves an allowance to the trusted router after each call (overwritten on next call; trusted target; defensive-low)
- **LOCAL-007** No sweep function on `CurveAMMAdapter` — stuck tokens (theoretical) not recoverable (info)
- **LOCAL-008** `CurveAMMAdapter.setRoute` only validates first / last-non-zero of `path`, not the interleaved structure (relies on off-chain verification; low)
- **LOCAL-009** `AMMRoutes.json` USDe↔sUSDe routes encode two identical hops over the same pool address — verify intent vs. gas waste (econ-scanner)

## Downstream handoff

- **Code-scanner:** triage LOCAL-001, LOCAL-005, and the buffered-path SYA-bookkeeping interaction (return value vs. event sum mismatch documented in `lib/reflax-yield-vault/CLAUDE.md`).
- **Econ-scanner:** reconfirm M-02 under the buffered path (it should be unchanged — single swap, same minOut), and validate the AYieldStrategy NatSpec's "protocol-owned clients" assumption against the deployment plan (LOCAL-009 also belongs here).
- **Severity-classifier:** carry-forward severities hold absent new evidence; only LOCAL-005 has any plausibility to escalate beyond info pending code-scanner triage.
