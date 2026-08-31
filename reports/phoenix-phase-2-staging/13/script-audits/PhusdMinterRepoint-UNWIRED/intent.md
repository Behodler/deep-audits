# Intent — PhusdMinterRepoint (UNWIRED, story-064 / YS-12)
## Stated purpose
- Phase A: repoint phUSD minter config for DOLA/USDC onto the new V2 strategies (setClient, registerStablecoin, approveYS, restore maxMintPerDay)
- Phase B: evacuate the minter's old-strategy position (withdrawAsOwner -> re-seed V2 via noMintDeposit, no new phUSD minted)
## Declared pre/post-conditions
- pre: ys non-zero; owner() on minter + 4 strategies; reads 7-field stablecoinConfigs
- post: V2 authorizedClients(minter); allowance max; config.yieldStrategy==V2; config.maxMintPerDay==savedCap; old principalOf==0; V2 principalOf>0
## Verdict: NON-FUNCTIONAL against live minter (HIGH). Live minter 0x435B..77E5 is an OLDER 4-field build with no setMaxMintPerDay; the 7-field decode + cap setter make preview revert before any mutation. Also UNWIRED (no preview gate, NatSpec keeps --skip-simulation). NEW Low: Phase B re-seeds with below-par recovered, no solvency floor.
