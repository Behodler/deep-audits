# Spec-Conformance Report — phlimbo-ea-06 (PhlimboV2)

> **Law 2 (Faithfulness to stories).** This report tracks deviations between the
> behaviour the project's `[story-NNN]` specifications promise and what the code
> actually does. It is deliberately **separate from the QA/gas bundle**: a
> spec-conformance deviation is a correctness-of-intent question, not a style or
> gas observation. Findings here are surfaced regardless of exploit likelihood;
> where a deviation *also* carries asset/availability impact, that manifestation
> is reported separately under its own H/M/C label and cross-referenced.

---

## V2-F-01 — `emergencyTransfer` breaks story-008 HIGH-5's safe-`pauseWithdraw`-exit promise (carried from V1)

- **Severity:** Faithfulness (Law-2 deviation) · Low
- **Status:** open
- **Contract / function:** `src/PhlimboV2.sol` — `emergencyTransfer` / `pauseWithdraw`
- **Location:** [`src/PhlimboV2.sol#L251-L291`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L251-L291)
- **Fingerprint:** `2147577c8f3dd6e63db0f4e274eb6be047a29233f3af168dc554c2ae24b9218e`
- **Carried from:** V1 ledger **F-01** (`inheritedFrom: F-01`) — the same faithfulness deviation persisted unchanged into V2.
- **Security cross-reference:** **V2-C-01** (`emergencyTransfer` drains without zeroing accounting + `setPauser(0)` permanent lock) — the asset/availability manifestation of this same mechanism, tracked under its own Centralization label and distinct fingerprint.

### The story (intended behaviour)

story-008's **HIGH-5** acceptance criterion promises stakers a guaranteed escape
hatch after an emergency:

> **story-008 / HIGH-5:** *Users can safely exit via `pauseWithdraw()` after an emergency.*

The design intent is unambiguous: the pause mechanism is not only a freeze, it is
paired with a *user-driven* recovery path. When the contract is paused — including
after the owner invokes the emergency function — any staker must be able to call
`pauseWithdraw()` and reclaim their principal. `pauseWithdraw` is explicitly
documented in the V2 source as the "Emergency exit mechanism" (L277).

### The actual behaviour in V2

`PhlimboV2.emergencyTransfer` (L251-263) sweeps the **entire** phUSD balance out of
the contract and then `_pause()`s, **without zeroing `userInfo` or `totalStaked`**:

```solidity
function emergencyTransfer(address recipient) external onlyOwner {
    uint256 phUSDBalance = phUSD.balanceOf(address(this));
    uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));

    if (phUSDBalance > 0) {
        IERC20(address(phUSD)).safeTransfer(recipient, phUSDBalance); // drains principal
    }
    if (rewardTokenBalance > 0) {
        rewardToken.safeTransfer(recipient, rewardTokenBalance);
    }

    _pause(); // contract now paused; accounting still shows every user's full stake
}
```

The accounting (`userInfo[*].amount`, `totalStaked`) is left intact, so the
contract still *believes* every staker is fully funded — but the phUSD backing
those balances is gone. The promised escape hatch then fails. `pauseWithdraw`
(L280-291) ends in a `safeTransfer` of the user's principal:

```solidity
function pauseWithdraw(uint256 amount) external whenPaused {
    UserInfo storage user = userInfo[msg.sender];
    require(user.amount >= amount, "Insufficient balance"); // passes — accounting untouched
    require(amount > 0, "Amount must be greater than 0");

    user.amount -= amount;
    totalStaked -= amount;

    IERC20(address(phUSD)).safeTransfer(msg.sender, amount); // L288 — REVERTS: no balance
    emit EmergencyWithdrawal(msg.sender, amount);
}
```

Because `emergencyTransfer` already removed all phUSD, the L288 `safeTransfer`
reverts for **every** staker (the contract holds nothing to send). The very state
in which `pauseWithdraw` is supposed to be the users' rescue — a paused, post-emergency
contract — is exactly the state in which `pauseWithdraw` cannot succeed.

### Deviation summary

| | story-008 / HIGH-5 (intended) | PhlimboV2 (actual) |
|---|---|---|
| Trigger | Emergency raised, contract paused | `emergencyTransfer` invoked, contract paused |
| Promise | Users **can** `pauseWithdraw()` to exit safely | `pauseWithdraw` **reverts for everyone** (drained balance) |
| Accounting | (implicitly) reflects recoverable principal | `userInfo`/`totalStaked` untouched → ledger over-states backing |

The safe-exit promise of HIGH-5 is **broken in V2 in the same shape as V1**: the
emergency path that the story designates as the users' recovery route is precisely
the path that disables their recovery route. This is a faithfulness deviation
independent of whether the owner is malicious — `emergencyTransfer` is the
sanctioned emergency response, and its sanctioned use silently voids the
story's stated guarantee.

### Recommendation (faithfulness)

Reconcile the implementation with story-008 HIGH-5: either (a) zero
`userInfo`/`totalStaked` inside `emergencyTransfer` so the accounting no longer
advertises an exit the contract cannot honour (and document that `pauseWithdraw`
is *not* available after a full sweep), or (b) restructure the emergency path so a
proportional `pauseWithdraw` claim survives a drain. Whichever route is chosen, the
story text and the code must agree — today they do not.

> The asset/availability consequences (permanent lock via the `_pause()` +
> `setPauser(0)` combination, principal stranded behind stale accounting) are
> reported and PoC-tracked under **V2-C-01**. This entry records only the Law-2
> deviation from story-008 HIGH-5.
