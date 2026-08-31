# QA Report for yield-claim-nft (run-11, story-035 NudgeRatchet)

**Audited commit:** `b8322ee83725ccba97a0ca5d1ddc5210aadb8441`
**Scope:** story-035 — `NudgeRatchet` dispatcher and `NudgeRatchetMintDebtHook`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 1 |
| QA / Non-Critical | 1 |
| **Total findings** | **2** |

Two additional items are recorded as QA notes (not standalone findings): a defense-in-depth
modifier-ordering observation attached to the existing open ledger theme **Q-05**, and a trivial
unused-import cleanup. An automated 4naly3er QA/gas report for the two story-035 contracts is
attached as **Appendix A** (`4naly3er-report.md`).

---

## Low Risk Findings

### [L-08] `NudgeRatchet` has no `rescueERC20`; out-of-band USDC is permanently stranded <!-- id: ycn11l8 -->

**Location:** [`src/V2/dispatchers/NudgeRatchet.sol#L59-L61`](../../../lib/yield-claim-nft/src/V2/dispatchers/NudgeRatchet.sol) (`_dispatch`); whole-contract — no rescue function present. Sibling reference: `src/V2/dispatchers/BalancerPoolerV2.sol#L350` (`rescueERC20`).

**Description:** `NudgeRatchet._dispatch` forwards only the explicitly-passed `amount` with a single `safeTransfer`:

```solidity
function _dispatch(address, uint256 amount, bytes calldata /* extraData */) internal override {
    IERC20(_token).safeTransfer(batchMinter, amount);
}
```

Any USDC that reaches the contract out-of-band — a direct transfer, dust, or an over-send beyond the dispatched `amount` — is never swept by `_dispatch` and cannot otherwise be recovered: `NudgeRatchet` exposes no owner recovery / `rescueERC20` function. This is an asymmetry against the sibling dispatcher `BalancerPoolerV2`, which does provide an owner-only `rescueERC20` (`BalancerPoolerV2.sol:350`).

**Impact:** Bounded fund-stranding. Only out-of-band funds are affected — there is no effect on dispatched amounts or in-protocol accounting, so the loss is limited to mistakenly- or dust-transferred tokens. This keeps the finding at QA-bundled Low rather than Medium.

**Recommendation:** Add an owner-only `rescueERC20` mirroring `BalancerPoolerV2.sol:350` so out-of-band tokens can be recovered, or explicitly document that `NudgeRatchet` must never receive out-of-band transfers.

```solidity
function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
}
```

---

## QA / Non-Critical Findings

### [QA-06] Non-monotonic "ratchet" naming: `setRatio` freely re-sets `ratio` up or down <!-- id: ycn11q6 -->

**Location:** [`src/V2/hooks/NudgeRatchetMintDebtHook.sol#L80-L85`](../../../lib/yield-claim-nft/src/V2/hooks/NudgeRatchetMintDebtHook.sol) (`setRatio`).

**Description:** The "Ratchet" name (`NudgeRatchet` / `NudgeRatchetMintDebtHook`) implies a monotonic, one-directional (up-only) mechanism. However, `setRatio` accepts any value in the inclusive range `[0, MAX_RATIO]` — up **or** down — with no monotonicity constraint:

```solidity
function setRatio(uint8 newRatio) external onlyOwner {
    if (newRatio > MAX_RATIO) revert RatioTooHigh();   // only an upper bound; no `>= old` check
    uint8 old = ratio;
    ratio = newRatio;
    emit RatioUpdated(old, newRatio);
}
```

This is a cosmetic Law-2 spec/naming deviation: the implementation is internally consistent and safe, but the name advertises a monotonic invariant the code does not enforce. The faithfulness aspect of this same story-035 observation is tracked as **F-02-035** in the dedicated spec-conformance report; the naming/QA aspect is bundled here.

**Impact:** Cosmetic / spec-conformance only — no asset, value, or availability impact. The risk is reader/operator confusion: anyone relying on the "ratchet" name to assume the ratio can only increase would be mistaken.

**Recommendation:** Either enforce monotonic-up semantics in `setRatio` (`require(newRatio >= ratio)`) to match the "ratchet" name, or rename the component / document that the ratio is freely settable in both directions so the name does not over-promise a monotonic invariant.

---

## Additional QA Notes (not standalone findings)

**STATIC-003 — `nonReentrant` is not the first modifier on `pull()` (additional instance under open ledger theme Q-05).**
In `NudgeRatchetMintDebtHook.pull()` (`src/V2/hooks/NudgeRatchetMintDebtHook.sol:123`), the modifier order is `onlyOwnerOrRecipient nonReentrant` — the access check precedes the reentrancy guard:

```solidity
function pull() external onlyOwnerOrRecipient nonReentrant { ... }
```

As a defense-in-depth convention, `nonReentrant` is usually placed first so the guard engages before any other modifier logic. Here it is safe: the preceding `onlyOwnerOrRecipient` is a pure `msg.sender` check with no external interaction, so ordering has no exploitable consequence. This is the same modifier-ordering theme already open in the ledger as **Q-05** (on a different function/contract); it is recorded as an additional instance under that theme rather than as a new fingerprinted finding.

**STATIC-004 — Unused import (trivial cleanup).**
`NudgeRatchet.sol:8` imports `ITokenDispatcherV2`, but the symbol is referenced only in an `@inheritdoc` doc comment, not as a base contract or type. The import can be removed (or, if `@inheritdoc ITokenDispatcherV2` resolution is desired, this is purely cosmetic). No functional impact.

```solidity
import {ITokenDispatcherV2} from "../interfaces/ITokenDispatcherV2.sol"; // unused as a type
```

---

## Appendix A — Automated QA/Gas Report (4naly3er)

The canonical C4-style automated report was generated with **4naly3er** scoped to the two
story-035 contracts and is attached alongside this file as
[`4naly3er-report.md`](./4naly3er-report.md).

Scope analyzed:
- `src/V2/dispatchers/NudgeRatchet.sol`
- `src/V2/hooks/NudgeRatchetMintDebtHook.sol`

Tooling note: 4naly3er's bundled `solc-0.8.26` cannot compile the project's full
bleeding-edge OpenZeppelin tree (modern modules such as `Base58`/`RLP`/WebAuthn verifiers
overflow the pinned compiler). The analysis was therefore run with a **scope file** limited to
the two story-035 contracts, which compiles only their actual import closure and produces a
clean report. The automated output is a baseline bot report (gas optimizations, NC, and Low
style items); its items are advisory and are not promoted into the hand-authored findings above
unless independently judged material.
