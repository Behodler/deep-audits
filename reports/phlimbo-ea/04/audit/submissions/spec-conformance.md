# Spec-Conformance (Law-2 Faithfulness) Report — phlimbo-ea

> **Scope of this document.** This is the **faithfulness** report. It collects only
> `[story-NNN]` / spec **deviations** — places where the in-scope contract does not do
> what its governing story says. It is **separate from the QA bundle** (`qa-report.md`),
> which carries gas/style/QA noise. Per Law 2, a deviation is reported here regardless of
> exploit likelihood; where a deviation *also* has asset/value/availability impact it is
> ALSO reported under its own H/M label, and is cross-listed here with the H/M as the
> authoritative write-up.

- **Project:** `phlimbo-ea`  ·  **Run:** `phlimbo-ea-04`
- **In-scope file:** `src/Phlimbo.sol` (contract `PhlimboEA`, V1 — deployed)
- **Submodule HEAD:** `1b1a32c4d1d7ec81a043f40ffe9a6d408c89d301`
- **Story provenance:** No strict bracketed `[story-NNN]` commit touches `src/Phlimbo.sol`;
  the governing intents are inline-referenced story numbers in commit bodies ("story 005",
  "story 006", "story 008", "Story 014", "story 015"), untagged foundational commits, and
  `lib/phlimbo-ea/CLAUDE.md`. See `analysis/story-intents.md` for the full digest.

---

## Deviation 1 — M-01 (headline): "Linear Depletion" is implemented as exponential decay

- **Label:** `M-01` (cross-reference — full write-up + PoC in `submissions/M-01-linear-depletion-exponential-decay.md`)
- **Story:** foundational/untagged commit `2f678c3` (EMA → Linear Depletion migration); model named in story-005. Registry `designDecisions[0]`.
- **Classification:** **Law-1-escalated** — BOTH a Law-2 faithfulness deviation (implementation contradicts the stated model) AND a Law-1 value-impact issue (chronic under-delivery + permanent stranding of in-motion yield). Reported as a **Medium** (M-01); capped at Medium by the loss-of-yield rule (in-motion, owner-recoverable). Listed here as the **headline faithfulness deviation** because the contract's "Linear Depletion" naming and documentation are flatly inconsistent with its realized payout curve.

### Exact quoted spec/story text

- Contract NatSpec, `src/Phlimbo.sol#L15`:
  > "Staking yield farm for phUSD tokens with **Linear Depletion** reward distribution"
- `_updatePool` NatSpec, `src/Phlimbo.sol#L386`:
  > "Updates pool accumulators based on **linear depletion** reward rate"
- Commit `2f678c3` body (the migration that introduced the model): replaced EMA smoothing with
  `rewardPerSecond = rewardBalance / depletionDuration`, **"recalculating only when the balance
  changes (deposits or claims)"** — the model named "Linear Depletion" whose stated goal is to
  **"pay out rewardBalance evenly over depletionDuration."**
- Registry `designDecisions[0]`:
  > "Linear depletion model for reward distribution (rewardBalance / depletionDuration)"
- Submodule `lib/phlimbo-ea/CLAUDE.md` (upstream's own narrative):
  > "Has the **V1 rate-recompute bug**: `rewardPerSecond` is recomputed on every
  > stake/withdraw/claim, effectively re-anchoring the depletion window on each user interaction."

### Actual implementation behavior

`_updatePool` distributes the accrued reward, debits the balance, then **re-anchors the rate
against the reduced residual balance on every distributing interaction** — not only on funding:

- `lib/phlimbo-ea/src/Phlimbo.sol#L413` — `rewardBalance -= toDistribute;`
- `lib/phlimbo-ea/src/Phlimbo.sol#L416` — `rewardPerSecond = (rewardBalance * PRECISION) / depletionDuration;`  ← the re-anchor on **distribution**

The same recompute fires at every funding-class entry point too (`collectReward` at
`#L283`, `setDepletionDuration` at `#L188`), and `_updatePool` runs on every
`stake`/`withdraw`/`claim`/`collectReward`. Re-anchoring `rate = balance / D` after each
debit is the discrete form of `B'(t) = −B(t)/D`, whose solution is `B(t) = B0·e^(−t/D)`
(**exponential decay**) rather than the advertised linear `B(t) = B0·(1 − t/D)`. Over one
nominal `depletionDuration` with no new funding, `delivered(N) = R·(1 − (1 − 1/N)^N)`, which
falls from ~100% at a single update to the `1 − 1/e ≈ 63.2%` asymptote as the pool is poked
more often; the remaining ~37% recedes into an indefinite tail and a dust residual is
permanently stranded in `rewardBalance` (recoverable only by owner `emergencyTransfer`).

The "even payout over `depletionDuration`" guarantee therefore does not hold: the advertised
*linear* schedule is the only path the code never actually takes once the pool is touched more
than once per window. Upstream `PhlimboV2`/story-020 removes precisely this `_updatePool`
recompute, confirming the behavior is regarded internally as a defect, not intent. (Note:
`designDecisions[1]` "Rate recalculates after each balance change" *describes* the mechanism
but does not bless the emergent ~37% under-delivery, and the item is **not** in the formal
`knownIssues[]` list — so it is not an accepted/out-of-scope known issue.)

---

## Deviation 2 — F-01: emergencyTransfer breaks story-008 HIGH-5's promise of a safe `pauseWithdraw` exit

- **Label:** `F-01` (faithfulness-only — this report is the authoritative record)
- **Story:** story-008 **HIGH-5** (commit `d46506a`); cross-context parent story-049 (off-chain redistribution)
- **Classification:** **Faithfulness-only (Law-2).** No direct protocol value loss in the intended flow — the `emergencyTransfer` drain is a **knowing, trusted owner action** (Law 3), and the intended real-world flow (parent story-049: `emergencyTransfer(owner)` then off-chain redistribution) routes principal to the trusted owner. The deviation is purely that the story's **on-chain recovery guarantee does not exist**. Honest severity **Low**. The genuinely harmful corner of the same mechanism — `pauser == 0` permanent brick + dead escape hatch + non-zeroed accounting — is reported **separately as C-01** (ledger label `C-02`).

### Exact quoted spec/story text

story-008 HIGH-5 commit body (`d46506a`), relayed in `analysis/story-intents.md` L61 and L140-150:
> "emergencyTransfer(recipient) moves all tokens out and then _pause()s atomically; users get a
> no-rewards pauseWithdraw(amount) exit usable whenPaused"

and the explicit user-recovery promise:
> "After emergencyTransfer removes all tokens... **Users can safely exit via pauseWithdraw().**"

### Actual implementation behavior

`emergencyTransfer` (`lib/phlimbo-ea/src/Phlimbo.sol#L214-L227`) transfers the **entire**
`phUSD.balanceOf(address(this))` (`#L218-L220`) — which equals all staked principal — to
`recipient`, then `_pause()`s (`#L226`):

```solidity
// src/Phlimbo.sol#L214-L227
function emergencyTransfer(address recipient) external onlyOwner {
    uint256 phUSDBalance = phUSD.balanceOf(address(this));
    ...
    if (phUSDBalance > 0) {
        IERC20(address(phUSD)).safeTransfer(recipient, phUSDBalance); // L219 — drains ALL principal
    }
    ...
    _pause();                                                         // L226
}
```

`pauseWithdraw` (`#L245-L261`) decrements `user.amount`/`totalStaked` and then attempts to
return the principal:

- `lib/phlimbo-ea/src/Phlimbo.sol#L257` — `IERC20(address(phUSD)).safeTransfer(msg.sender, amount);`

With the contract drained of phUSD by the preceding `emergencyTransfer`, this `safeTransfer`
**reverts for every user**. The advertised on-chain "safe exit via `pauseWithdraw()` after
`emergencyTransfer`" therefore **does not exist**: `pauseWithdraw` is only coherent after a
plain `pause()` (no drain). The guarantee is mislabelled — post-drain recovery depends entirely
on the owner re-distributing off-chain (parent story-049), not on any on-chain path.

**Recommendation:** reconcile spec and code — either (a) update story-008 HIGH-5 to state that
recovery after `emergencyTransfer` is off-chain (story-049) with no on-chain `pauseWithdraw`
exit post-drain, or (b) make `emergencyTransfer` leave a recoverable on-chain path (do not drain
to zero, or zero the accounting on drain so `pauseWithdraw` degrades gracefully rather than
reverting). The harmful permanent-brick composition is tracked under C-01.

---

## Stories checked and found FAITHFUL (no deviation)

The following governing stories were checked against the current `src/Phlimbo.sol` and conform
to their stated acceptance criteria — **no deviation, reported for completeness:**

- **story-014 — Two-step APY (preview/commit)** [commit `50e468a`]: **FAITHFUL.** `setDesiredAPY`
  (`#L151-L172`) always previews on the first call (`apySetInProgress` defaults false ⇒ preview
  branch `#L153-L155`); the commit branch requires `apySetInProgress && block.number <=
  pendingAPYBlockNumber + 100 && bps == pendingAPYBps`, runs `_updatePool` then
  `_updatePhUSDEmissionRate` (`#L165-L168`), and clears `apySetInProgress`. A single call never
  mutates `desiredAPYBps`; commit requires the identical value within the 100-block window; state
  can always progress (never lockable). Matches the "preview→commit, same value within 100 blocks,
  never lockable" criteria.

- **story-015 — User-action events** [commit `01609fc`]: **FAITHFUL.** `Withdrawn` emits
  `actualWithdrawAmount` (the dust-adjusted amount; adjustment at `#L347-L351`, emit at `#L368`);
  `Staked` emits `recipient`, not `msg.sender` (`#L327`); `RewardsClaimed` emits the actual
  minted/transferred amounts and only when non-zero (`#L452-L453`). Matches the "events fire with
  the recipient/amount actually applied" criteria.

(Also confirmed faithful, for the record: story-008 HIGH-3's forbid-same-block-reward-inflation
protection survived the EMA→Linear-Depletion model swap via the `_updatePool` early-return at
`#L390` (`block.timestamp <= lastRewardTime`).)

---

## Cross-reference: other Law-2-tagged findings reported under their own labels

Surfaced here for recall (Law 1 — never drop a deviation from view); full write-ups live with
each label, not duplicated here:

| Finding | Story relation | Where reported |
|---------|----------------|----------------|
| M-03 — permissionless `collectReward` window-reset griefing | foundational `7529a45` (open `collectReward`) — story's safety reasoning incomplete | `submissions/M-03-permissionless-collectReward-griefing.md` |
| M-04 — `pauseWithdraw` phUSD over-mint on unpause | story-006 INV-7 (`phUSDPerSecond` tracks `totalStaked`) regressed by HIGH-5 `pauseWithdraw` | `submissions/M-04-pauseWithdraw-phUSD-overmint-on-unpause.md` |
| L-02 — `pauseWithdraw` minimum-stake bypass | story-008 HIGH-1 (MINIMUM_STAKE / dust prevention) weakened by HIGH-5 `pauseWithdraw` | QA bundle (`qa-report.md`) |
