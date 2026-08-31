# Contract profile — `src/BatchNFTMinter.sol` (DEPLOYED / FROZEN)

- Run: `phoenix-nft-staking-21`
- Submodule HEAD: `c881a42`
- Profiled: **COLD** (file was REVERTED this cycle — prior run-20 profile describes a
  different contract and must NOT be reused)
- Solidity: `^0.8.20`; LOC 313; no `unchecked`, no assembly
- Inheritance: `Ownable`, `Pausable`, `IPausable` (`:62`) — **note: NO `ReentrancyGuard`**

## 1. Provenance — the "verbatim restore" claim, mechanically checked

Claim under test: `BatchNFTMinter.sol` at HEAD is its state at `99a55ac` (the last commit
before story-022 Stage 1) plus one added `@notice`.

`git diff 99a55ac c881a42 -- src/BatchNFTMinter.sol` yields **exactly one hunk**: six added
`@notice` lines at `:14-19` marking the file DEPLOYED/FROZEN. Zero other insertions, zero
deletions, zero modifications.

**CLAIM VERIFIED. No unannounced change.** See `FORK-PARITY-5WAY.md` §B.

The revert is a genuine restore of the pre-story-022 single-token contract, not a
re-implementation. Every executable line matches the version audited in prior runs, so
**prior findings against this file remain valid without re-derivation** — the run-20 profile's
*conclusions about the multi-token nudge* do not apply here (that code moved out), but every
conclusion about the single-token nudge does.

## 2. External / public surface

| Function | Vis | Access | Guards | State written | External calls |
|---|---|---|---|---|---|
| `constructor(address)` `:65` | — | — | — | `Ownable._owner` | none |
| `setTokenMinter(ITokenMinterV2)` `:126` | external | `onlyOwner` | — | `tokenMinter` | none |
| `setDispatcherIndex(uint256)` `:135` | external | `onlyOwner` | — | `dispatcherIndex` | none |
| `setNudgeSize(uint256)` `:142` | external | `onlyOwner` | — | `nudgeSize` | none |
| `setNudgePaymentToken(address)` `:149` | external | `onlyOwner` | — | `nudgePaymentToken` | none |
| `setPauser(address)` `:156` | external | `onlyOwner` | — | `pauser` | none |
| `pause()` `:164` / `unpause()` `:169` | external | `onlyPauser` `:118` | — | `Pausable._paused` | none |
| `rescueERC20(IERC20,address,uint256)` `:181` | external | `onlyOwner` | callable while paused | none | CALL `transfer` |
| `batchMint(uint256,address,uint256,uint256)` `:238` | external | **permissionless** | `whenNotPaused` **only** | none | see §3 |

State: `DUST_THRESHOLD` `:70`, `tokenMinter` `:74`, `dispatcherIndex` `:81`, `nudgeSize` `:84`,
`nudgePaymentToken` `:87`, `pauser` `:91`. No per-user accounting.

## 3. `batchMint` call graph, in execution order

| Line | Call | Opcode | Trust |
|---|---|---|---|
| `:255` | `INFTMinterV2(nftMinter).configs(idx)` | STATICCALL | owner-pinned |
| `:258` | `ITokenDispatcherV2(dispatcher).primeToken()` | STATICCALL | derived |
| `:280` | `IERC20(nudgePaymentToken).balanceOf(this)` | STATICCALL | **owner-set**, not caller-set |
| `:283` | `paymentToken.safeTransferFrom(msg.sender, this, amt)` | CALL | derived |
| `:284` | `paymentToken.forceApprove(nftMinter, max)` | CALL | derived |
| `:287` | `nftMinter.mint(idx, recipient)` × `count` | CALL | owner-pinned |
| `:290` | `paymentToken.forceApprove(nftMinter, 0)` | CALL | derived |
| `:301` | `IERC20(nudgePaymentToken).safeTransfer(recipient, amt)` | CALL | **owner-set** |
| `:305` | `paymentToken.balanceOf(this)` | STATICCALL | derived |
| `:307` | `paymentToken.safeTransfer(msg.sender, remaining)` | CALL | derived |

**The absence of `ReentrancyGuard` here is CORRECT and is the key structural difference from
the multi-token sibling.** In this contract every external callee is owner-configured
(`tokenMinter`, `nudgePaymentToken`) or derived from owner-configured state (`paymentToken`).
There is no caller-supplied address that this contract calls. The sibling added
`ReentrancyGuard` precisely because `rewardTokens` made the payout pass caller-controlled
(`BatchNFTMinterMultiToken.sol:78-81`). Do not report the missing guard here as a defect
without a caller-controlled callee — there is none.

## 4. Verified local properties

| Property | Status | Evidence |
|---|---|---|
| Checked arithmetic | **verified** | `^0.8.20`, no `unchecked`, no assembly |
| Weak randomness | **verified absent** | no block/tx entropy source anywhere in the file |
| Access control on all admin setters | **verified** | `:126/:135/:142/:149/:156/:181` `onlyOwner`; `:164/:169` `onlyPauser` |
| No caller-supplied external-call target | **verified** | §3 |
| Nudge token ≠ payment token, enforced pre-funds-movement | **verified** | `:260-263`, before the pull at `:283` |
| Nudge snapshotted pre-loop, paid post-loop | **verified** | read `:280`, transfer `:301` |
| `minReward` floor | **verified, but checked LATE** | `:296` — see LOCAL-101 |
| Reentrancy guard | **absent, and correctly so** | §3 |
| Unbounded loop | **VIOLATED (1 site, accepted)** | `:286`, `count`, caller-paid |
| ERC721/1155 receive hooks | **none** | not a receiver |
| Initializer protection | **n/a** | plain constructor |

## 5. Local findings

**LOCAL-101 — the `minReward` floor is evaluated AFTER the mint loop, not before it.**
`:296-298`. The revert is atomic so no funds are lost, but the caller pays for `count`
executed mints' worth of gas before the check fires. In the multi-token sibling this was moved
to the pre-loop snapshot pass (`BatchNFTMinterMultiToken.sol:431-433`, explicitly annotated as
"a pure gas improvement; the atomic rollback guarantee is identical either way"). **This is a
known, deliberate divergence — the frozen file is not to be fixed.** Recorded so that
`FORK-PARITY-5WAY.md` §B can classify it as an intended, deployment-frozen delta rather than
drift. Severity: **QA at most**, and arguably not reportable at all given the DEPLOYED/FROZEN
marker at `:14-19`.

**LOCAL-102 — nudge front-run / MEV, and over-funding.** Pre-existing, previously triaged.
`:231-235` explicitly states the floor "does NOT stop a front-runner from winning the pot".
This is the ledger's standing BatchNFTMinter nudge finding. **No new evidence this run.** Do
not re-file; reconcile against the existing ledger entry.

## 6. Scope note for downstream

This file is marked **DEPLOYED — FROZEN** at `:14-19` and the repo's `CLAUDE.md` now declares
the whole submodule a non-deployment repo (story-022 Stage 8 deleted
`script/DeployBatchNFTMinter.s.sol`). Two consequences:

1. Any finding here is against **live on-chain bytecode**. There is no "just fix it" path;
   remediation is operational (pause, rescue, redeploy as the multi-token sibling).
2. A finding that reproduces on **both** this file and the sibling should be reported once,
   against the sibling (which is still changeable), with this file named as the deployed
   instance. Do not double-count.
