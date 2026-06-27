# QA Report — yield-claim-nft

| Field | Value |
|-------|-------|
| Project | yield-claim-nft |
| Run | yield-claim-nft-15 |
| Submodule commit | `f46a5cb` |
| Story | story-043 (`NudgeRatchetDelayRelease` — hold-and-release USDC dispatcher variant) |
| Mode | Regression scan (baseline run-14 @ `4f80541`) |

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (new this run) | 1 |
| QA (new this run) | 1 |
| Low Risk (open carryover) | 7 |
| QA (open carryover) | 2 |
| Centralization | 0 |
| **Total** | **11** |

This run introduced one new first-party contract, `src/dispatchers/NudgeRatchetDelayRelease.sol`
(a hold-and-release sibling of `NudgeRatchet` that retains dispatched USDC and only forwards it
to the owner-pinned `batchMinter` when a whitelisted releaser calls `release(amount)`),
auto-pulled into scope under the default-in-scope denylist. It produced exactly two new findings
(L-12, Q-11). No High, Medium, Centralization, or regression findings surfaced. The remaining
open Low/QA items are carried over from prior runs and are referenced — not re-authored — in the
carryover section below.

---

## Low Risk Findings

### [L-12] Pause freezes mint/debt accrual but not USDC custody on `NudgeRatchetDelayRelease` <!-- id: ycn15l12 -->

**Location**: [`src/dispatchers/NudgeRatchetDelayRelease.sol#L108-L121`](../../../lib/yield-claim-nft/src/dispatchers/NudgeRatchetDelayRelease.sol#L108-L121) (`release`, `rescueERC20`), contrasted with the `whenNotPaused`-gated `dispatch` inherited from `ATokenDispatcherV2`

**Classification**: Low — non-obvious Law-3 owner/operator operational footgun (in scope as an operational hazard). Severity confirmed by the severity-classifier (`CLASS-15-001`); no malicious-owner framing — releasers and owner are trusted.

**Description**:
The dispatcher's inbound side, `dispatch()`, is `whenNotPaused`: pausing the contract halts new USDC inflow and the post-`_dispatch` `hook.onDispatch` phUSD mint-debt accrual. The two custody-moving functions, however, are **not** pause-gated:

- `release(uint256 amount)` is `onlyReleaser nonReentrant` and unconditionally `safeTransfer`s held USDC to the owner-pinned `batchMinter`.
- `rescueERC20(address,address,uint256)` is `onlyOwner` and, by design (per its NatSpec), is not pause-gated.

Consequently, pausing the dispatcher does **not** produce the intuitive "freeze everything" effect. A trusted whitelisted releaser can continue to relocate already-held USDC to the `batchMinter` while the contract is paused, and the owner can continue to call `rescueERC20`. The mint/debt side is frozen; the custody side is not.

**Impact**:
No theft and no loss — backing is conserved, not destroyed. `release()` can only send USDC to the owner-pinned `batchMinter` (the intended sink), and `rescueERC20()` is `onlyOwner`; no third party gains funds and total system backing is preserved (relocated, not minted/burned). The hazard is **surprising pause semantics**: an owner who pauses expecting a complete custody freeze — without also revoking releasers — would be surprised that held USDC can still flow out. This is the non-obvious consequence that makes it a footgun rather than trusted-owner noise. It is the same pause-bypass class as the open carryover **L-04** (privileged paths ignoring the global `paused` flag), here on the new story-043 dispatcher.

**Recommendation**:
Make the pause semantics explicit and safe-by-default. Either:

- Decide that custody movement should also halt under pause and add `whenNotPaused` to `release()` (and reconsider `rescueERC20`'s deliberate exemption); or
- Keep the current design but document that a pause only freezes inbound mint/debt accrual, and that to **truly freeze custody** the owner must also revoke every releaser:

```solidity
// to fully freeze custody during a pause, in addition to pause():
setReleaser(eachReleaser, false);
```

No code change is strictly required if the operational rule is documented; the load-bearing fix is making the asymmetric pause semantics non-surprising to a competent operator.

---

## QA Findings

### [Q-11] `_dispatch` drops the sibling `NudgeRatchet`'s in-contract `require(bal >= amount)` backing tripwire <!-- id: ycn15q11 -->

**Location**: [`src/dispatchers/NudgeRatchetDelayRelease.sol#L131-L143`](../../../lib/yield-claim-nft/src/dispatchers/NudgeRatchetDelayRelease.sol#L131-L143) (`_dispatch`)

**Classification**: QA — latent defense-in-depth / robustness gap (no live root cause). Severity confirmed by the severity-classifier (`CLASS-15-002`). Kept **distinct** from the suppressed DEDUP-001 (external phUSD backing model): this is the narrower dropped in-contract assertion, not the backing-model debate.

**Description**:
`NudgeRatchetDelayRelease._dispatch` deliberately performs no transfer (USDC is held until a releaser forwards it), but in doing so it also omits the sibling `NudgeRatchet`'s defensive `require(IERC20(_token).balanceOf(address(this)) >= amount)` backing tripwire — the in-contract assertion that the dispatched `amount` is actually backed by held tokens before debt accrues against it.

In the shipped wiring there is no live exploit: `dispatch` is `onlyMinter`, and `NFTMinterV2` dispatches exactly its measured balance-delta `actualReceived`, so accrued mint-debt equals on-contract USDC by construction and the dropped check would be trivially satisfied and never trip. The gap is **latent only** under a future, non-default `setMinter()` repoint to a caller that passes an un-measured `amount` not backed by a real `transferFrom` — a precondition that does not exist at `f46a5cb`. Per C4 ("speculation on future code without demonstrated root cause"), this stays at QA.

**Recommendation**:
Restore parity with the sibling and keep the backing invariant self-defended in-contract. The check is cheap and stays `view`:

```solidity
function _dispatch(address, uint256 amount, bytes calldata) internal view override {
    require(
        INudgeRatchetMintDebtHook(address(hook)).hookTypeId() == EXPECTED_HOOK_TYPE_ID,
        "NudgeRatchetDelayRelease: hook is not NudgeRatchetMintDebtHook"
    );
    require(
        IERC20(_token).balanceOf(address(this)) >= amount,
        "NudgeRatchetDelayRelease: amount not backed by held balance"
    );
}
```

---

## Carryover open findings

The findings below remain **open** in the ledger from prior runs. They are outside run-15's
changed-file scope (the only changed file this run is the new
`src/dispatchers/NudgeRatchetDelayRelease.sol`) and are **not re-authored** here. Each links to
its authoritative writeup and to its run-14 carryover stub. Triage via `/ledger yield-claim-nft`.

| Label | Severity | One-line | Authoritative report | Stub |
|-------|----------|----------|----------------------|------|
| L-04 | Low | Privileged `mintFor()`/`burn()` ignore global `paused` + per-index disabled flags (`NFTMinterV2.sol#L206-L214`) — same pause-bypass class as new L-12 | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](../../yield-claim-nft-14/submissions/carryover/L-04-CARRYOVER.md) |
| L-05 | Low | No on-chain invariant couples `BalancerPoolerV2.batchDonationSize` and `Hook.ratio` (missing `batchDonationSize + ratio <= 100` guardrail) | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](../../yield-claim-nft-14/submissions/carryover/L-05-CARRYOVER.md) |
| L-06 | Low | Single-sided sUSDS LP-add relies solely on off-chain keeper `minBPT` with no on-chain price reference (MEV sandwich) | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](../../yield-claim-nft-14/submissions/carryover/L-06-CARRYOVER.md) |
| L-07 | Low | `replaceDispatcher()` carries stale per-index price to a new dispatcher whose `primeToken` may have different decimals (price re-denomination) | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](../../yield-claim-nft-14/submissions/carryover/L-07-CARRYOVER.md) |
| L-09 | Low | `Uniboost` has no `hookTypeId` guard: an unwired/wrong dispatch hook silently accrues zero phUSD debt (M-04 fail-open class reborn on a third dispatcher) | [yield-claim-nft-13 qa-report](../../yield-claim-nft-13/submissions/qa-report.md) | [stub](../../yield-claim-nft-14/submissions/carryover/L-09-CARRYOVER.md) |
| L-10 | Low | `UniboostMintDebtHook.scale` derived from the hook's own ctor `primeToken_` with no on-chain tie to dispatcher `primeToken()`; decimals mismatch mis-scales all debt | [yield-claim-nft-13 qa-report](../../yield-claim-nft-13/submissions/qa-report.md) | [stub](../../yield-claim-nft-14/submissions/carryover/L-10-CARRYOVER.md) |
| L-11 | Low | `MultiPooler` same-pool in-batch floor staleness (atomic-batch self-DoS on shared UniV2 pool; primary self-DoS, no theft) | [yield-claim-nft-14 qa-report](../../yield-claim-nft-14/submissions/qa-report.md) | — |
| Q-05 | QA | `nonReentrant` is not the first modifier on `pool()`/the hook-guarded entry (defense-in-depth) | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](../../yield-claim-nft-14/submissions/carryover/Q-05-CARRYOVER.md) |
| Q-10 | QA | `setPool` repoints `_pairToken` without re-validating stored custom `_primeToPairPath` (stale path can route swap to wrong token) | [yield-claim-nft-13 qa-report](../../yield-claim-nft-13/submissions/qa-report.md) | [stub](../../yield-claim-nft-14/submissions/carryover/Q-10-CARRYOVER.md) |

---

## Centralization Risks

None new this run. The `NudgeRatchetDelayRelease` privileges — owner-settable `batchMinter`,
the owner-managed `releasers` whitelist, the admin-controlled release rate, and the
`onlyOwner` `rescueERC20` escape hatch — are trusted, non-malicious operational levers under
Law 3 and are documented as accepted design properties in the contract's own NatSpec. The only
non-obvious consequence of these privileges (pause does not freeze custody) is captured as the
L-12 footgun above; the latent in-contract backing-assertion gap is Q-11.

---

## Appendix — Automated QA/Gas Report (4naly3er)

**Status: NOT GENERATED — tooling gap persists (carried over from run-14).**

4naly3er (`tools/4naly3er`) was re-run against `lib/yield-claim-nft/src` this run and again failed
to compile the scope. The submodule depends on a **mutable sibling interface**
(`pauser/interfaces/IPausable.sol`) resolved at build time via the project's `foundry.toml`
remappings into `lib/mutable/`; 4naly3er's standalone `solc` invocation does not apply those
remappings, so the import is unresolvable and the compiler aborts:

```
pauser/interfaces/IPausable.sol import not found
Make sure you can compile the contracts in the original repository.
TypeError: Cannot read properties of undefined (reading 'contents')
```

Per the agent runbook, the gap is noted (visible, not silently omitted) and the manual QA bundle
proceeds. The deterministic SAST baseline for this run is instead supplied by the static-analyzer's
Slither / Aderyn / Semgrep dumps already produced under `reports/yield-claim-nft-15/`:

- `slither-output.json`
- `aderyn-report.json`
- `semgrep-output.json`
- normalized to `static-analysis-findings.json`

**None of their raw hits survived triage as new findings.** All eight normalized hits were dropped
as noise or as out-of-scope/known-pattern in `deduplicated-findings.json`:

| Tool ID | Raw hit | Disposition |
|---------|---------|-------------|
| ADERYN-001 (potential-high) | "state assignment after external call" — `_token = token_` after `IERC20Metadata(token_).decimals()` in constructor | Dropped — constructor decimals read is not a reentrancy/ordering risk |
| ADERYN-002 (potential-low) | `release()` `nonReentrant` is not the first modifier | Dropped — same defense-in-depth class as carryover Q-05; not new |
| ADERYN-003 (potential-high) | `abi.encodePacked` with dynamic types before hash | Dropped — not in the new contract's reachable path |
| SLITHER-001 (potential-medium) | division-before-multiplication in `gemAmt` | Dropped — pre-existing PSM math, not story-043 |
| SLITHER-002..005 (potential-low) | strict-equality `== 0`, ignored return values, `block.timestamp` router deadline | Dropped — known-pattern / pre-existing; collapsed into existing L-06 surface |

To regenerate 4naly3er for a future run, point it at a remapping-aware checkout (e.g. run from a
`workspace/` clone with `forge`-resolved deps, or pass an explicit remapping/scope file) rather
than the bare `lib/<submodule>/src` directory.
