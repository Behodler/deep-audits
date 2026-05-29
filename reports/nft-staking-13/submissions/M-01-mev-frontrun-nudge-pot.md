<!--
ID: ns13m1
C4 Submission Metadata
Title: [M-01] MEV / first-claimer front-running lets a searcher steal the entire nudge bonus from honest batch-minters
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L245-L258
PoC File: poc-MevFrontrunNudge.t.sol
Ledger Fingerprint: 521c20ad48b388ea37eea906fb5e5495885952fcd944a3377fee24f274434d60
-->

## Finding description and impact

### Summary

`BatchNFTMinter.batchMint` pays out its **entire** `nudgePaymentToken` balance to a **caller-chosen** `recipient` the instant the purely numeric condition `count >= nudgeSize` is satisfied ([`BatchNFTMinter.sol#L245-L258`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L245-L258)). The nudge is **winner-take-all, permissionless, and unbound from `msg.sender`**: there is no sender-binding, no commit-reveal, and no per-participant accounting.

Because `batchMint` is public and `recipient` is a free parameter, any honest user who funds `nudgeSize` real mints to qualify for the bonus can be **front-run in the public mempool** by a searcher who submits an identical-qualifying `batchMint` with `recipient = self` at a higher priority fee. The searcher pays the **same real mint cost** (the owner-pinned dispatcher charges a normal, non-zero ramping price) and scoops the **whole pot**. The honest user's batch still lands, still pays its full mint cost, still mints its NFTs — but finds the pot already at zero and receives **nothing**.

### Scope and distinction from the prior-run High (not a duplicate)

This finding is a **distinct root cause** from the prior-run H-01 (the permissionless caller-chosen-cheap-dispatcher drain). That earlier drain — where an attacker passed a no-op / cheap dispatcher to qualify for near-zero cost — **was fixed by story-014**: the `minter` and `dispatcherIndex` are now owner-pinned and the payment asset is derived from the pinned dispatcher's `primeToken()` ([`BatchNFTMinter.sol#L226-L231`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L226-L231)). This report does **not** claim a pot drain via cheap/zero pricing or misconfiguration; that residual value-blindness is owner-driven and out of scope.

The harm reported here survives that fix entirely. It does not depend on a cheap dispatcher, a zero price, or any admin error:

- the dispatcher is owner-pinned with a **normal non-zero ramping price**;
- the pot is a **legitimately-funded bonus** (`pot >> nudgeSize × price`) — exactly the feature's intended operating state;
- **both** the searcher and the honest user pay the **full real mint cost**.

The remaining defect is purely the **first-come, winner-take-all allocation** of the pot to whoever wins the priority-gas auction in the mempool, rather than to the honest participants who fund the batch-minting work the bonus is meant to reward.

### Vulnerability details

The nudge payout block in `batchMint`:

```solidity
//note to reviewer: I (dev) changed nudgeToken to reuse _nudgeTokenEntry
uint256 _nudgeSize = nudgeSize;
if (_nudgeSize != 0 && count >= _nudgeSize) {              // (1) PURELY NUMERIC gate (~L246)
    if (_nudgeTokenEntry != address(0)) {
        uint256 nudgeAmount = IERC20(_nudgeTokenEntry).balanceOf(address(this)); // (2) FULL balance
        if (nudgeAmount != 0) {
            IERC20(_nudgeTokenEntry).safeTransfer(recipient, nudgeAmount);       // (3) to CALLER-CHOSEN recipient
            emit NudgePaid(recipient, _nudgeTokenEntry, nudgeAmount);
        }
    }
}
```

Three properties combine to make the bonus capturable by a front-runner:

1. **The gate is permissionless and stateless.** `batchMint` is `external whenNotPaused` with no caller restriction, and the qualifying predicate `count >= nudgeSize` is satisfiable by *any* address that pays for `nudgeSize` real mints. Whoever's transaction lands first wins.
2. **The payout is the full pot, atomically.** The first qualifying call in any block sweeps the **entire** `nudgePaymentToken` balance, leaving nothing for subsequent qualifiers in the same block — there is no pro-rata split and no carry-over to the honest claimant.
3. **`recipient` is unbound from `msg.sender`.** The bonus is sent to the address the caller names, not to a participant identity tied to who actually paid. A searcher copies an honest user's qualifying parameters, swaps `recipient` to itself, and bids a higher priority fee.

The classic MEV sequence:

1. Honest user broadcasts `batchMint(nudgeSize, honest, payment)` to the public mempool to claim the funded bonus.
2. A searcher observes it, submits `batchMint(nudgeSize, searcher, payment)` with a higher priority fee, and is ordered first.
3. The searcher's call clears `count >= nudgeSize`, sweeps the **entire** pot to itself, paying only the ordinary mint cost.
4. The honest user's call still executes, still mints `nudgeSize` NFTs and pays the real (now slightly ramped) mint cost — but the pot is already zero, so `nudgeAmount == 0` and the honest user receives nothing.

This is the textbook profile of an unprotected, value-bearing, permissionless payout: a public reward that any observer can redirect to themselves by reordering. The only external requirement is a normal public mempool with a priority-fee market — the default environment for the target chain.

### Impact

The externally-funded nudge incentive is **systematically diverted to MEV bots / first-movers** instead of reaching the honest participants who perform the batch-minting work the feature is designed to reward. The bonus is reliably captured by a parasitic actor; honest qualifiers are denied the incentive they paid to earn.

This is a **value leak with a stated external requirement** (public mempool / priority-fee market), which maps to Medium under C4: protocol assets are not directly stolen from the protocol's principal, but the protocol's intended economic function is defeated and externally-funded value is leaked to an unintended actor along a realistic attack path.

Honest framing of the boundaries:

- **This is not principal theft from the protocol.** Honest users still receive the NFTs they paid for; staking deposits and mint payments are unaffected. What is stolen is the **discretionary bonus** that was funded to incentivise large batches.
- **No admin error or misconfiguration is required.** Funding the pot with a meaningful bonus *is* the intended use of the feature, and the dispatcher price is normal and non-zero. The finding holds under the feature's intended operating state.

### Proof of Concept

A runnable Foundry PoC using the project's test suite (project `BatchNFTMinter` + project `MockERC1155` / `MockERC20`, with a minter mock that faithfully implements the `INFTMinterV2.configs` resolution and `ITokenMinterV2.mint` ramping-price ladder the helper actually exercises) is included in the next section. It models the realistic, fix-compliant configuration:

- the minter and dispatcher are **owner-pinned** (post story-014);
- the dispatcher charges a **normal non-zero ramping price** (`START_PRICE = 1000`, `GROWTH_BPS = 250`);
- the pot is a **legitimately-funded** `50,000`-token bonus;
- `nudgeSize = 5`.

It demonstrates the searcher front-running an honest qualifier and capturing the entire pot.

Run:

```
cd workspace/nft-staking && forge test --match-path test/poc-MevFrontrunNudge.t.sol -vv
```

Exact output:

```
Ran 1 test for test/poc-MevFrontrunNudge.t.sol:MevFrontrunNudgePoCTest
[PASS] test_M01_searcherFrontrunsHonestNudgeClaimant() (gas: 530517)
Logs:
  === M-01 PoC: MEV front-run of winner-take-all nudge pot ===
    pot size (wei)                 : 50000000000000000000000
    searcher mint outlay (wei)     : 5256328515625000000000
    searcher nudge gained (wei)    : 50000000000000000000000
    honest mint cost paid (wei)    : 5947053252229312896727
    honest NFTs minted             : 5
    honest nudge gained (wei)      : 0
  === VULNERABILITY CONFIRMED: searcher scooped pot; honest qualifier got 0 ===

Suite result: ok. 1 passed; 0 failed; 0 skipped
```

The searcher gains the full **50,000**-token pot for an ordinary mint outlay of **~5,256**; the honest user mints all 5 NFTs, pays **~5,947** in real mint cost, and receives **0** nudge — the bonus they qualified for was already swept by the front-runner.

## Recommended mitigation steps

Make the nudge allocation resistant to first-claimer / front-run capture so the bonus reaches the addresses that actually paid for the qualifying mints, rather than whoever wins the priority-gas auction. Options, in rough order of robustness:

1. **Bind the nudge to the actual payer with pro-rata accounting.** Track each participant's genuine qualifying spend and distribute the pot pro-rata across qualifiers over a window, instead of sweeping the full balance to a single caller-chosen `recipient`. This removes the winner-take-all race entirely.

2. **Replace the full-balance sweep with a per-qualifying-mint accrual, claimable by the payer.** Accrue a bounded nudge entitlement to `msg.sender` (or a participant identity tied to who paid) as qualifying mints occur, and let that address claim it. The bonus then cannot be redirected to an unrelated `recipient` by a front-runner.

3. **Use a commit-reveal / sealed mechanism** for nudge claims so the qualifying intent is not observable-and-copyable in the public mempool before it lands.

4. **At minimum, cap the payout to a function of the value actually paid by that caller** (e.g. `min(potBalance, k × totalPaid)`), rather than releasing the full pot. This bounds the windfall a front-runner can extract per call and removes the winner-take-all incentive to snipe.

Illustrative shape for option 4 (bounded, payer-relative payout):

```solidity
// totalPaid is the caller's genuine net spend across the loop (already computed below)
uint256 potBalance = IERC20(_nudgeTokenEntry).balanceOf(address(this));
uint256 payout = Math.min(potBalance, nudgeFactor * totalPaid); // bounded & payer-relative
if (payout != 0) {
    IERC20(_nudgeTokenEntry).safeTransfer(recipient, payout);
    emit NudgePaid(recipient, _nudgeTokenEntry, payout);
}
```

This preserves the intended large-batch incentive while ensuring no single front-running call can scoop a pot worth many multiples of what the caller genuinely spent.
