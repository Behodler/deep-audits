# Carryover QA Report — originating audit 15 (carried into yield-claim-nft-19)

> **Carryover QA report — audit 15** (cut down from `reports/yield-claim-nft-15/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 19): **L-12, Q-11**.
> Removed as no longer live: **none** — both of audit 15's authored findings are still open. Structural sections not copied: audit 15's own "Carryover open findings" table (recall pointers, carried here per originating audit), "Centralization Risks" (none that run) and the 4naly3er appendix.
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers and links were accurate at the originating commit (`f46a5cb (run-15)`); re-verify against current HEAD (`d4cc563`).
> These entries were **not re-examined** in the run-19 range (stories 046/047, dispatcher/streamer surface); they are carried for recall (Law 1), and their `lastSeenRun` was deliberately **not** bumped.
>
> ⚠ **Label-collision warning:** run-19's own C4 labels `L-04`/`L-05` are **new, unrelated findings** (ledger `L-19` / `9fdcb0c6…` and `L-20` / `1c1e0001…`). The `L-04`/`L-05` below are the **ledger** entries `674c799b…` / `e527a712…`. Do not conflate.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

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
