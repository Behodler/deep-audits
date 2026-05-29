---
name: nft-staking-batchminter-nudge
description: nft-staking BatchNFTMinter nudge-pot — H-01 history, story-014 fix, and what survives owner-driven invalidation
metadata:
  type: project
---

`phoenix-nft-staking` `src/BatchNFTMinter.sol` `batchMint` pays the **entire** `nudgePaymentToken` balance to a caller-chosen recipient on a purely count-based gate (`count >= nudgeSize`), never comparing payout to value paid (winner-take-all "nudge" bonus pot).

History:
- Run-12 H-01 (valid High at the time): permissionless drain via a **caller-chosen** cheap/zero-price dispatcher.
- story-014 (commit 031ffda) FIXED that permissionless vector by pinning the minter + `dispatcherIndex` to owner state; caller can no longer choose the dispatcher/token.
- The original mainnet exploit documented in the in-code NatSpec (caller-supplied no-op minter) is therefore fixed.

What remains after applying [[owner-driven-attacks-invalid]]:
- Residual "drain" sub-vectors all require owner config (pinning a `price==0` dispatcher, or over-funding the pot vs `nudgeSize*price`) → **owner-driven, invalid**. H-01 does not survive as a standalone High on current code.
- The genuinely permissionless residual is the **MEV/first-claimer front-run** of the winner-take-all pot (M-01): a searcher copies an honest qualifying `batchMint` with `recipient=self` and scoops a legitimately-funded bonus, denying it to the honest participant. This is the surviving valid finding (Medium-ish; no principal loss, honest user still gets NFTs).

Cross-contract: sibling `yield-claim-nft/src/V2/NFTMinterV2.sol` has no `price>0` check (registerDispatcher/setPrice/mint) — relevant only to the now-invalid owner-driven path.
