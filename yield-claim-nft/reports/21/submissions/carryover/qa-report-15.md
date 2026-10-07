# Carryover QA Report — originating audit 15 (carried into yield-claim-nft-21)

> **Carryover QA report — audit 15** (pruned copy of `yield-claim-nft/reports/15/submissions/qa-report.md`; originating commit `f46a5cb`; carried at `267660b`, run 21).
> Retained (still `open`): **L-12, Q-11**. Removed as disposed: **none**. The "Carryover open findings" table (pointers only), "Centralization Risks" (none) and the 4naly3er appendix are not copied.
> Ledger titles differ from the report headings (same fingerprints): L-12 = "Pausing the dispatcher does not freeze custody: release()/rescueERC20(...)"; Q-11 = "Delay-release variant drops the sibling NudgeRatchet's in-contract require...".
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder, and many point at the retired `lib/yield-claim-nft/...` reference tree. Re-verify every location against `267660b` before acting.
> Global issue IDs in the `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped). Where an originating report minted an ID inconsistently (run 08 stamped QA items with `l`), the original stamp is kept and the discrepancy is noted, not corrected.
> *The finding text below each heading is a verbatim copy of the originating report; the `Carryover status` block after each section is added by the run-21 qa-bundler.*

---

## Low Risk Findings

### [L-12] Pause freezes mint/debt accrual but not USDC custody on `NudgeRatchetDelayRelease` <!-- id: ycn15l12 -->

**Location**: [`src/dispatchers/NudgeRatchetDelayRelease.sol#L108-L121`](../../../../lib/yield-claim-nft/src/dispatchers/NudgeRatchetDelayRelease.sol#L108-L121) (`release`, `rescueERC20`), contrasted with the `whenNotPaused`-gated `dispatch` inherited from `ATokenDispatcherV2`

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

> **Carryover status (run 21, `267660b`).** Ledger **L-12** · fingerprint `d9d8e16a04523a16311b8ee328b58ba29d7d6145db57d6fed948f39d95cec33e` · status **`open`** · severity `low` · first seen `yield-claim-nft-15` · last seen `yield-claim-nft-16` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.

---

## QA Findings

### [Q-11] `_dispatch` drops the sibling `NudgeRatchet`'s in-contract `require(bal >= amount)` backing tripwire <!-- id: ycn15q11 -->

**Location**: [`src/dispatchers/NudgeRatchetDelayRelease.sol#L131-L143`](../../../../lib/yield-claim-nft/src/dispatchers/NudgeRatchetDelayRelease.sol#L131-L143) (`_dispatch`)

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

> **Carryover status (run 21, `267660b`).** Ledger **Q-11** · fingerprint `205afcf03c96ec937639b67795df51410c479654975fd20c3d81e184d94989dd` · status **`open`** · severity `qa` · first seen `yield-claim-nft-15` · last seen `yield-claim-nft-16` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
