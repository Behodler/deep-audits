# Intent — batch-minter-migrate (Story 057)

Forge target: `script/MigrateBatchNFTMinter.s.sol:MigrateBatchNFTMinter.run()`
Preview sender / owner: `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6`
Fork block: 25248523 (RPC live)

## Stated purpose (from `//mint`/story-057 comment + NatSpec)
- [ ] Deploy the self-refund-fixed `BatchNFTMinter` (nft-staking `5f863d2`: snapshots the nudge pot BEFORE the mint loop so a 40-batcher receives only the PRIOR pot).
- [ ] Configure the new minter identically to the live one: `setTokenMinter(NFTMinterV2)`, `setDispatcherIndex(4)`, `setNudgePaymentToken(USDC)`, `setNudgeSize(40)`. Pauser intentionally left at `address(0)` to match the live instance.
- [ ] Repoint the two real funders to the new minter: `SYA.setNudgeAddress(new)` and `BalancerPoolerV2.setBatchMinter(new)`. `nudgeSplit` is deliberately LEFT at 30 (zeroing it while nudge live would DoS `claim()`).
- [ ] Drain the OLD minter's residual USDC into the new pot via a plain `rescueERC20(USDC, new, bal)` (no BPT exit/swap dance).
- [ ] Restore the pooler `batchDonationSize` to 10% (zeroed earlier as the interim bleed-stop), AFTER the repoint so restored donations flow to the NEW minter.
- [ ] Retire the OLD contract: assert it holds 0 USDC, then zero its nudge config (`nudgePaymentToken=0`, `nudgeSize=0`).
- [ ] Persist progress JSON (broadcast only) for the post-step `patch-mainnet-addresses` JS.

## Declared pre-conditions (require/guards before funds/pointers move — `_guards()`)
- new minter `tokenMinter() != 0`
- new minter `dispatcherIndex() == 4`
- new minter `nudgePaymentToken() == USDC`
- `NFTMinterV2.configs(4).dispatcher != 0` (index-4 dispatcher present)
- `dispatcher.primeToken() == USDS` (index-4 is the USDS/Balancer pooler path)
- new minter `nudgePaymentToken() != primeToken` (the security-critical batchMint guard: nudge token must differ from prime/payment token)

## Declared post-conditions (require/asserts after each step)
- `_repoint`: `SYA.nudge() == newMinter`; `pooler.batchMinter() == newMinter`
- `_drainAndSeed`: `usdcSeeded == oldBal` (exact-drain assertion — new-pot delta equals the old balance read live)
- `_restoreDonation`: `pooler.owner() == OWNER` (owner guard); `pooler.batchDonationSize() == 10`
- `_retireOld`: `IERC20(USDC).balanceOf(OLD) == 0` (drain-completeness assertion); then idempotent zeroing of old nudge config

## Access / trust assumptions
- Single owner-signed broadcast (Ledger `m/44'/60'/46'/0/0`, sender `0xCad1…D0B6`).
- Assumes `OWNER` is the owner of: the deployed new minter (ctor arg), `SYA` (setNudgeAddress is owner-gated), the live pooler (asserted via `pooler.owner() == OWNER`), and the OLD minter (rescueERC20 / setNudge* are owner-gated).
- No `block.chainid == 1` guard in-script (relies on `--rpc-url $RPC_MAINNET` + hardcoded mainnet constants). Sibling `mint-sell-donate` DOES pin chainid; this one does not.

## Not done by design (documented in-script)
- `setPauser` not called — new minter `pauser` stays `address(0)` (matches live old instance; both are therefore unpausable — a pre-existing design choice, not introduced here).
- `nudgeSplit` left at 30.
