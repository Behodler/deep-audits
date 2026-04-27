<!--
C4 Submission Metadata
Title: [M-01] BatchNFTMinter wired to V1 ITokenMinter; non-functional against production NFTMinterV2
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/BatchNFTMinter.sol#L73
Severity: Medium
PoC File: workspace/nft-staking/test/poc-M-01.t.sol
-->

## Finding description and impact

### Lines of code

[`src/BatchNFTMinter.sol#L65-L78`](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/BatchNFTMinter.sol#L65-L78) (bug site at [L73](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/BatchNFTMinter.sol#L73))

Production wiring asserted in [`src/INFTSupply.sol#L15-L18`](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/INFTSupply.sol#L15-L18).

### Summary

`BatchNFTMinter` imports the **legacy V1** `ITokenMinter` interface and dispatches to the V1 3-arg `mint(address,uint256,address)` selector inside its loop. The contract that `BatchNFTMinter` is documented and deployed to call is `NFTMinterV2`, which **does not implement that selector**. Every `batchMint` invocation against the production minter therefore reverts atomically on the first inner `mint()` call, rendering the entire helper non-functional in production.

### Root cause

`BatchNFTMinter.sol` imports the V1 interface:

```solidity
import {ITokenMinter} from "yield-claim-nft/interfaces/ITokenMinter.sol";
```

and at line 73 it calls:

```solidity
nftMinter.mint(address(paymentToken), dispatcherIndex, recipient);
```

This compiles to selector `0x0d4d1513` (`mint(address,uint256,address)`).

The production minter — confirmed by the project's own `INFTSupply.sol` NatSpec at L15-L18, which states *"the production wiring of `INFTSupply` is a direct cast of the deployed `NFTMinterV2` address"* — is `NFTMinterV2`. `NFTMinterV2` exposes only:

| Signature | Selector |
|---|---|
| `mint(uint256,address)` | `0x94bf804d` |
| `mint(uint256,address,bytes)` | `0x73c02519` |

`NFTMinterV2` has no `fallback`/`receive` and no method registered to selector `0x0d4d1513`. The dispatcher therefore reverts with empty returndata on the first iteration, and the entire transaction (including the prior `safeTransferFrom(msg.sender -> contract, paymentAmount)` and `forceApprove(nftMinter, type(uint256).max)`) atomically rolls back.

### Why CI does not catch this

The repo's existing `BatchNFTMinter.t.sol` exercises the helper against a hand-rolled `MockITokenMinter` that mirrors the V1 ABI. The mock implements the V1 selector, so the test passes. The wiring mismatch only surfaces when the helper is pointed at the real `NFTMinterV2` deployment, which the test suite never does.

### Impact

Functional denial-of-service of the entire `BatchNFTMinter` helper against the spec-bound production minter:

- `batchMint` reverts atomically on the first inner `mint()` call.
- Users lose only gas — the prepayment is rolled back — so no principal is at risk.
- The deployed user-facing batch-mint helper (introduced in story-009 as a documented UX optimisation, and named as the recommended batch-mint entrypoint in its NatSpec) is 100% non-functional. Every honest user who follows the docs hits the revert.

### Severity rationale

**Medium.** No assets are at risk: the atomic revert returns the user's prepayment in the same transaction. C4 High requires assets to be "stolen/lost/compromised" — not the case here. C4 Medium covers situations where "function of the protocol or its availability could be impacted"; a deployed helper that is 100% non-functional against the spec-bound production minter is a textbook fit. The defect is deterministic (every call reverts) and trivially demonstrated, supporting a confident Medium.

### Proof of concept

Full Foundry PoC: [`workspace/nft-staking/test/poc-M-01.t.sol`](../../../../workspace/nft-staking/test/poc-M-01.t.sol).

The PoC stands up two scenarios sharing the same `BatchNFTMinter` and `MockERC20` payment token:

- **Bug** — wires the helper to a real `NFTMinterV2` + `GatherV2` dispatcher (matching the documented production topology) and calls `batchMint`. The call reverts atomically; the caller's balance is fully restored; no NFT is minted.
- **Control** — wires the *same* helper to a real V1 `NFTMinter` + `Gather` dispatcher with identical args. The call succeeds and the recipient receives one ERC1155 unit. This isolates the V1/V2 selector mismatch as the sole cause of the V2 revert.

Run with:

```bash
cd workspace/nft-staking
forge test --match-test test_M01 -vvv
```

### Tools used

Manual review; Foundry (`forge test`); selector cross-check via `keccak256` of canonical signatures.

## Recommended mitigation steps

Re-target `BatchNFTMinter` at `ITokenMinterV2` (`lib/mutable/yield-claim-nft/src/V2/interfaces/ITokenMinterV2.sol`) and call the 2-arg `mint(uint256,address)` overload:

```solidity
// src/BatchNFTMinter.sol
- import {ITokenMinter} from "yield-claim-nft/interfaces/ITokenMinter.sol";
+ import {ITokenMinterV2} from "yield-claim-nft/V2/interfaces/ITokenMinterV2.sol";

  function batchMint(
-     ITokenMinter nftMinter,
+     ITokenMinterV2 nftMinter,
      IERC20 paymentToken,
      uint256 dispatcherIndex,
      uint256 count,
      address recipient,
      uint256 maxPricePerMint
  ) external returns (uint256 totalPaid) {
      // ... unchanged setup ...
      for (uint256 i; i < count; ++i) {
-         nftMinter.mint(address(paymentToken), dispatcherIndex, recipient);
+         nftMinter.mint(dispatcherIndex, recipient);
      }
      // ... unchanged tail ...
  }
```

If forwarding `extraData` (e.g. for slippage-aware mints — see M-02) is desired, use the 3-arg V2 overload `mint(uint256,address,bytes)` instead.

Additionally, **add an integration test** that exercises `batchMint` against the real `NFTMinterV2` ABI (or, at minimum, against a mock that mirrors V2's selectors). The current `MockITokenMinter`-based suite masks this regression; equivalent V2 coverage should be a CI gate going forward.
