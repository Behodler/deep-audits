<!--
title: Nudge payout sweeps full balance to caller-supplied recipient — deterministic frontrun, refill arbitrage, recipient asymmetry, and threshold gaming
root_cause_link: https://github.com/Behodler/phoenix-nft-staking/blob/24b3f58/src/BatchNFTMinter.sol#L137-L155
severity: High
poc_file: workspace/nft-staking/test/poc-H-01.t.sol
-->

## Finding description and impact

### Summary

`BatchNFTMinter.batchMint` pays the **entire** `IERC20(_nudgeTokenEntry).balanceOf(address(this))` to a **caller-supplied** `recipient` whenever `count >= nudgeSize`, with no proportionality to `count`, no link between `recipient` and `msg.sender`, and no rate limiting. The combination converts the externally-funded nudge pool into a winner-takes-all prize that any MEV searcher can claim by submitting the cheapest qualifying batch (`count == nudgeSize`), and lets a malicious wrapper redirect the nudge to an arbitrary address while the user funds the call. The honest large-batch user the incentive is designed to subsidise is structurally outraced on every refill cycle.

### Vulnerability details

The nudge-payout block at [`BatchNFTMinter.sol#L137-L155`](https://github.com/Behodler/phoenix-nft-staking/blob/24b3f58/src/BatchNFTMinter.sol#L137-L155) pays the contract's full nudge-token balance to the caller-supplied `recipient` whenever the batch threshold is met:

```solidity
// BatchNFTMinter.sol#L137-L155
address _nudgeTokenEntry = nudgePaymentToken;
uint256 _nudgeSize = nudgeSize;
if (
    _nudgeTokenEntry != address(0) &&
    _nudgeSize > 0 &&
    count >= _nudgeSize
) {
    uint256 nudgeBalance = IERC20(_nudgeTokenEntry).balanceOf(address(this));
    if (nudgeBalance > 0) {
        IERC20(_nudgeTokenEntry).safeTransfer(recipient, nudgeBalance);
    }
}
```

Three structural decisions compound:

1. **Balance-sweep payout.** The transferred amount is `balanceOf(address(this))` rather than a per-batch cap. Any single qualifying call drains the pool to zero.
2. **Threshold inequality with no scaling.** The qualifier is `count >= nudgeSize`. A batch of 5 (assuming `nudgeSize == 5`) and a batch of 1,000 receive identical nudges, so rational callers converge on the cheapest qualifying batch.
3. **`recipient` decoupled from `msg.sender`.** The dispatcher payment is pulled from `msg.sender` and the dust refund is returned to `msg.sender`, but the nudge transfer is sent to the caller-supplied `recipient`. The payer and the nudge beneficiary need not be the same account.

The PoC at `workspace/nft-staking/test/poc-H-01.t.sol` demonstrates three concrete attack vectors driven by this single broken invariant. All three tests pass under `forge test --match-path test/poc-H-01.t.sol -vv`.

#### (A) Mempool-race full-pool drain — `test_PoC_H01_AttackerDrainsFullNudgePool`

The yield funnel transfers `50,000` USDC into the helper. An attacker observes the inbound transfer in the mempool and submits `batchMint(count = nudgeSize = 5, recipient = attacker, paymentAmount = cost(5))`. The PoC measures:

- Attacker spends **5,256 phUSD** for a 5-mint batch (compounding price from `startPrice = 1,000 phUSD`, `growthBps = 250`).
- Attacker captures the **entire 50,000 USDC** pool — roughly a **9.5x** return on the qualifying batch.
- An honest 50-mint batch submitted immediately afterward sees `balanceOf(batchMinter) == 0` and receives **0** USDC despite paying the dispatcher for ten times more mints.

The honest user was the intended beneficiary of the nudge (NatSpec lines 19-22 describe the feature as incentivising larger batches). The PoC shows that goal is structurally unreachable.

#### (B) Recipient asymmetry — payer is not receiver — `test_PoC_H01_RecipientAsymmetry`

A user signs a `batchMint` call routed through a malicious wrapper. `msg.sender` is the user, `recipient` is the wrapper's exfil address. The PoC verifies post-call:

- `payToken.balanceOf(attacker) == before - cost` (the user funded the entire payment).
- `nudgeToken.balanceOf(attackerNudgeReceiver) == before + 50,000 USDC` (the nudge accrued to the wrapper).
- `nudgeToken.balanceOf(attacker) == before` (the payer received zero nudge).
- `nft.balanceOf(attackerNudgeReceiver, DISPATCHER_INDEX) == count` (the NFTs were also routed away from the payer).

The dispatcher payment is pulled from `msg.sender`; the externally funded nudge is paid to `recipient`. A wrapper / front-end can silently capture the entire nudge from any user it interposes on. The same primitive lets `recipient` be set to an arbitrary protocol contract (e.g. `NFTStaker`) with no rescue path, permanently stranding both the minted NFTs and the nudge.

#### (C) Threshold gaming across refills — `test_PoC_H01_ThresholdGamingAcrossRefills`

Across three successive refill cycles the attacker submits `count == nudgeSize` every time. Because compounding price growth ratchets `currentPrice` upward across cycles, the per-cycle cost rises but the per-cycle reward is constant at the full pool:

| Cycle | Attacker phUSD spent | Attacker USDC stolen |
|------:|--------------------:|---------------------:|
| 1     | 5,256               | 50,000               |
| 2     | 5,947               | 50,000               |
| 3     | 6,728               | 50,000               |

Total: **150,000 USDC drained** over three refill cycles. The cost per cycle compounds modestly, but the reward is invariant, so the attacker's strategy remains profitable indefinitely. Honest large-batch users continue to receive zero nudge across every cycle.

### Impact

The owner-funded incentive budget is captured in full by the cheapest qualifying caller on every refill. Concretely:

- **Direct loss of incentive capital.** Every refill of the nudge pool is fully drainable by a single qualifying batch. With public mempools and standard MEV bundling, the loss is deterministic, not probabilistic.
- **Honest batchers receive nothing.** The intended beneficiaries — users submitting genuinely large batches — are structurally outraced. The protocol pays them 0 even when the pool was funded specifically to subsidise their batch.
- **Recipient asymmetry weaponises wrappers.** Any front-end or aggregator can silently divert the nudge while the user funds the call, with no on-chain signal to the user.
- **Cross-contract grief.** The recipient asymmetry lets any caller set `recipient` to a contract with no rescue path, permanently stranding the nudge tokens and the minted NFTs.
- **Stated design intent unreachable.** The NatSpec frames the nudge as an incentive to encourage larger batch sizes. With balance-sweep payout, no scaling, and no payer-receiver link, larger batches are economically dominated by minimum qualifying batches.

The asset at risk is the full `nudgePaymentToken` balance of `BatchNFTMinter` at any time. In the production wiring this is owner-supplied or yield-funnel-supplied USDC.

### Proof of Concept

A standalone Foundry test is provided at `workspace/nft-staking/test/poc-H-01.t.sol`. The file contains three tests, one per attack vector, and is self-contained against the existing `BatchNFTMinter` source plus the in-tree `MockITokenMinterV2`, `MockERC1155`, and `MockERC20` helpers used elsewhere in the test suite.

To reproduce:

```bash
cd workspace/nft-staking
forge test --match-path test/poc-H-01.t.sol -vv
```

All three tests pass and emit the quantitative numbers cited in the Vulnerability details section. To exercise the PoC against a fresh checkout, drop `poc-H-01.t.sol` into `test/` of the `phoenix-nft-staking` submodule and run the command above.

## Recommended mitigation steps

The root cause is a single broken invariant — the nudge has no per-claim limit, no payer/receiver link, and no scaling with batch size. Mitigations should be combined; any single change in isolation leaves at least one of the three attack vectors viable.

1. **Pay proportionally to `count` rather than the full balance.** Replace the balance-sweep with `nudgePerBatch * count / nudgeSize`, capped at the current balance. Removes the threshold-gaming cliff and aligns the incentive with batch size.
2. **Cap per-call payout.** If proportionality is undesirable, configure an owner-set `nudgePerBatch` and pay `min(balance, nudgePerBatch)` per qualifying batch. Drains the pool over many batches rather than in a single transaction, so a single frontrun captures only one batch's share.
3. **Restrict `recipient` to `msg.sender` for the nudge transfer.** Decouple NFT recipient from nudge recipient: continue to mint NFTs to `recipient` (preserving the existing UX) but pay the nudge to `msg.sender`. Closes the wrapper-extraction vector and the recipient-as-protocol-contract grief.
4. **Pull-based claim with a distribution schedule.** Replace push-payout with an accrual model: track per-user qualifying batch counts and let recipients claim against a schedule the funnel controls. Removes the mempool race entirely.
5. **Allowlist or commit-reveal the qualifying caller.** If push-payout is retained, gate it on an allowlisted distributor or a commit-reveal so that the qualifying call cannot be constructed reactively from a refill observation.
6. **Scale the qualifier with batch size.** Replace `count >= nudgeSize` with a non-trivial requirement that scales — e.g. require `count >= nudgeSize` *and* pay `nudgePerBatch * min(count, maxNudgedBatch) / nudgeSize` — so that batches above the threshold are strictly preferred over the minimum qualifying batch.
7. **Fold the refill into the distribution.** If the funnel is the sole funder, expose a single `refillAndDistribute(...)` entrypoint that funds the pool and pays out atomically to a deterministic recipient set, eliminating the public-mempool reaction window.

A minimal patch addressing the highest-impact subset would (i) pay `nudgePerBatch * count / nudgeSize` capped at balance, and (ii) send the nudge to `msg.sender` rather than `recipient`. That single change closes vectors (A), (B), and (C) together.
