# Contract Profile — `src/BatchNFTMinter.sol`

- **Project**: phoenix-nft-staking @ `0d1a0b2` (`[story-022] Stage 6`)
- **Profiled**: 2026-07-20 (run-20)
- **Solidity**: `^0.8.20`, pinned `solc = "0.8.20"` in `foundry.toml`, no `via_ir`
- **Normative spec**: `docs/multi-token-nudge.md` (352 lines, NEW this cycle) — section refs below are to that doc
- **Prior profile**: `reports/phoenix-nft-staking-19/profiles/BatchNFTMinter.json` (nudge path fully RE-DERIVED; non-nudge surface carried forward)
- **Diff since run-19 baseline `321d0a9`**: `src/BatchNFTMinter.sol` +361/−? (near-rewrite of the nudge path), `test/BatchNFTMinterMultiTokenNudge.t.sol` +730 (new), mocks `MockFeeOnTransferERC20` / `MockReentrantERC20` added, `MockITokenMinterV2` donation hook widened to a list.

---

## 1. Role

Stateless-ish helper that loops `ITokenMinterV2.mint(dispatcherIndex, recipient)` `count` times in one transaction, pulling the aggregate payment once from `msg.sender`, and — when `count >= nudgeSize` — paying `recipient` this contract's **entire pre-loop balance** of every ERC20 the *caller* lists in `rewardTokens`.

Story-022 replaced the owner-set single `nudgePaymentToken` with a caller-selected multi-token model. Owner retains control of **eligibility only** (`nudgeSize`); the reward asset is now untrusted caller input.

---

## 2. Verified properties

| Property | Status | Evidence |
| --- | --- | --- |
| `checkedArithmetic` | **verified** | 0.8.20, no `unchecked`, no assembly. Only arithmetic is `remaining / DUST_THRESHOLD` and `paymentAmount - remaining` (guarded by a `>` ternary). |
| `noUnboundedLoops` | **violated-by-design (benign)** | Two caller-bounded loops: mint loop over `count` (L363) and the snapshot/payout passes over `rewardTokens.length` (L424, L454). All gas + real mint cost is paid by the caller; block gas limit is the bound (§4.5, §8). No third-party can be griefed by a long array. |
| `reentrancyGuarded` | **verified** | `nonReentrant` on `batchMint` (L300), OZ non-transient `ReentrancyGuard` (L11, L82) per §4.3. Closes run-19 `LOCAL-BM-001`. See §6 below for the residual (non-reentrant) callback surface. |
| `accessControlled` | **verified** | `onlyOwner`: `setTokenMinter`, `setDispatcherIndex`, `setNudgeSize`, `setPauser`, `rescueERC20`. `onlyPauser`: `pause`, `unpause`. `whenNotPaused`: `batchMint` only (§4.6 — setters and `rescueERC20` deliberately stay live while paused). |
| `initializerProtected` | **n/a** | Not upgradeable; plain `constructor(address initialOwner)`. No proxy, no storage-layout constraint. |
| `noWeakRandomness` | **verified** | No `block.*` / `blockhash` / `prevrandao` anywhere. Eligibility is the pure numeric `count >= nudgeSize` test. |
| `noStaleApproval` | **verified** | `forceApprove(minter, max)` (L360) → loop → `forceApprove(minter, 0)` (L368). A revert anywhere rolls the whole tx back, so no residual allowance can survive. |
| `atomicRollback` | **verified** | Any floor breach, mint revert, or failed transfer reverts the entire batch (§4.6). |
| `arrayLengthValidated` | **verified** | `rewardTokens.length != minRewards.length` → `BatchMint__ArrayLengthMismatch` (L304), *before* any external call. `_payRewards` iterates `snapshot.length` and indexes `rewardTokens[i]` — safe only because of this check; the two arrays are always equal-length by construction. |
| `emptyArrayPath` | **verified** | `rewardTokens.length == 0` → zero-length `snapshot`, zero-iteration passes, no reward, no event. Legal per §2. Reachable independently of `nudgeSize`. |
| `paymentTokenExclusionUnconditional` | **verified (as written) / partially vacuous (as motivated)** | L426 fires on every element before the balance read and before any funds move, including when `qualifies == false`. It does what §4.1 says. But its **stated purpose** — "the only thing standing between a caller and the payment-token balance held mid-transaction" — is **not achieved**; see LOCAL-BM20-002. |
| `snapshotBeforeMintLoop` | **verified (ordering) / defeated (effect)** | Snapshot at L354 precedes the pull (L357) and the loop (L363); payout at L378. Ordering is exactly §3 steps 4→9. But the donate-forward *effect* §4.2 exists to guarantee is bypassable via duplicate array entries — see LOCAL-BM20-001. |
| `duplicatesFailClosed` (§4.5 claim) | **VIOLATED** | PoC in §5. |
| `noEtherHandling` | **verified** | No `receive`/`fallback`/`payable`. ETH cannot be sent or stranded; no `rescueETH` needed. |
| `storageSafety` | **verified** | 4 slots (`tokenMinter`, `dispatcherIndex`, `nudgeSize`, `pauser`) + OZ `Ownable`/`Pausable`/`ReentrancyGuard`. No mapping, no dynamic storage, no delegatecall, no transient storage. `_status` from OZ `ReentrancyGuard` is a new slot appended by inheritance — irrelevant (not upgradeable). |
| `zeroAddressChecks` | **likely** | `recipient != 0`, `rescue to != 0`, `tokenMinter != 0`, `dispatcherIndex != 0` and `dispatcher != 0` all checked. `setTokenMinter(0)` / `setDispatcherIndex(0)` / `setPauser(0)` are *intentional* disable sentinels. Not checked: `paymentToken` (i.e. `dispatcher.primeToken()`) may be `address(0)` — the subsequent `safeTransferFrom` on a non-contract reverts via SafeERC20's `address.code.length` check, so it fails closed. |

---

## 3. Interface abstraction

### External entry points

| Function | Access | Persistent state written | External calls | Reentrancy |
| --- | --- | --- | --- | --- |
| `batchMint(count, recipient, paymentAmount, rewardTokens[], minRewards[])` → `totalPaid` | public, `whenNotPaused`, `nonReentrant` | **none** (only transient ERC20 allowance) | `INFTMinterV2.configs(idx)`; `ITokenDispatcherV2.primeToken()`; `IERC20(rewardTokens[i]).balanceOf` ×n; `paymentToken.transferFrom(msg.sender)`; `paymentToken.approve(minter, max/0)`; `tokenMinter.mint()` ×count (→ inbound `onERC1155Received(recipient)`); `IERC20(rewardTokens[i]).transfer(recipient)` ×n; `paymentToken.balanceOf`; `paymentToken.transfer(msg.sender)` | guarded |
| `rescueERC20(token, to, amount)` | `onlyOwner` (callable while paused) | none | `token.safeTransfer(to, amount)` | **unguarded** (owner-only, no cross-function invariant to break — `batchMint` holds no persistent balance-derived state between calls) |
| `setTokenMinter(ITokenMinterV2)` | `onlyOwner` | `tokenMinter` | none | n/a |
| `setDispatcherIndex(uint256)` | `onlyOwner` | `dispatcherIndex` | none | n/a |
| `setNudgeSize(uint256)` | `onlyOwner` | `nudgeSize` | none | n/a |
| `setPauser(address)` | `onlyOwner` | `pauser` | none | n/a |
| `pause()` / `unpause()` | `onlyPauser` (string-`require`, not a custom error) | `Pausable._paused` | none | n/a |

### External-call trust map

| Target | Methods | Trust | Notes |
| --- | --- | --- | --- |
| `tokenMinter` (`ITokenMinterV2`/`INFTMinterV2`) | `mint`, `configs` | **trusted** — owner-pinned state, not a call parameter | Pinning is what closed the historical caller-supplied-minter drain (H-01 lineage). `configs(idx)` is destructured as `(address dispatcher,,,)` — positional coupling to `INFTMinterV2`'s tuple; an ABI drift in `yield-claim-nft` silently repoints the payment asset. **Defer to interaction analysis.** |
| `dispatcher` (`ITokenDispatcherV2`) | `primeToken()` | **trusted** (resolved from the trusted minter) | Return value becomes the payment asset *and* the §4.1 exclusion key. |
| `paymentToken` (= `dispatcher.primeToken()`, mainnet: USDS via `BalancerPoolerV2`) | `transferFrom`, `approve`, `balanceOf`, `transfer` | **semi-trusted** | Assumed standard, non-FoT, non-rebasing. FoT here would break the dust-sweep/`totalPaid` ledger. |
| `rewardTokens[i]` | `balanceOf`, `transfer` | **UNTRUSTED — arbitrary caller-supplied address** | New attack surface introduced by story-022. Executes arbitrary code twice per element, inside `batchMint`. `MockReentrantERC20` is the witness. |
| `recipient` | inbound `onERC1155Received` (via `tokenMinter.mint` → ERC1155 `_mint`) | **UNTRUSTED** | Inbound callback fires `count` times *between* the snapshot and the payout. It cannot reenter `batchMint` (guard), but it runs while the contract holds the caller's payment budget and an open `type(uint256).max` allowance to the minter. |
| `msg.sender` | `paymentToken.transfer` (dust sweep) | untrusted, but plain-ERC20 transfer only | |

### State-mutation map

| Variable | Type | Mutators | Readers |
| --- | --- | --- | --- |
| `tokenMinter` | `ITokenMinterV2` | `setTokenMinter` | `batchMint` |
| `dispatcherIndex` | `uint256` | `setDispatcherIndex` | `batchMint` |
| `nudgeSize` | `uint256` | `setNudgeSize` | `batchMint` |
| `pauser` | `address` | `setPauser` | `onlyPauser` modifier |
| `Pausable._paused` | `bool` | `pause`/`unpause` | `batchMint` |
| `ReentrancyGuard._status` | `uint256` | `nonReentrant` (`batchMint`) | same |
| `Ownable._owner` | `address` | `transferOwnership`/`renounceOwnership` (inherited, not overridden) | `onlyOwner` |

**`batchMint` writes no persistent contract state.** All effects are token balances and the transient allowance. This is why the payout leak (LOCAL-BM20-001) is a *balance-accounting* issue, not a storage one.

### Events

`NudgeSizeChanged`, `NudgePaid(recipient, token, amount)` (once per token actually transferred), `TokenMinterSet`, `DispatcherIndexSet`, `Rescued`, `PauserChanged`. Removed this cycle: `NudgePaymentTokenChanged`.

### Errors

`BatchMint__ZeroCount`, `BatchMint__ZeroRecipient`, `BatchMint__RewardTokenIsPaymentToken(token)` *(new)*, `BatchMint__ArrayLengthMismatch(tokensLength, minsLength)` *(new)*, `BatchMint__MinterNotConfigured`, `BatchMint__DispatcherNotConfigured`, `BatchMint__RewardBelowMinimum(token, minReward, actualReward)` *(gained a `token` field)*, `Rescue__ZeroRecipient`. Removed: `BatchMint__NudgeTokenMatchesPaymentToken`.

---

## 4. Who can claim the nudge — precise characterization

The NatSpec warning at L51–L61 ("tokens sent to this contract may be claimed by anyone who qualifies") is accurate but under-specifies the preconditions. Exactly:

**A payout of `rewardTokens[i]` occurs iff ALL of:**

1. `!paused()`;
2. `tokenMinter != address(0)` and `dispatcherIndex != 0` and `configs(dispatcherIndex).dispatcher != address(0)`;
3. `nudgeSize != 0` **and** `count >= nudgeSize` (`qualifies`);
4. `rewardTokens[i] != dispatcher.primeToken()`;
5. the caller holds and has approved enough `paymentToken` to cover the dispatcher's *cumulative ramping* cost of `count` mints (a partial approval reverts inside the loop, rolling everything back);
6. the pre-loop balance is `>= minRewards[i]` and `!= 0`.

**Beneficiary is `recipient`, NOT `msg.sender`.** The caller freely directs the entire pot to an arbitrary address; nothing ties the reward recipient to the payer. The NFTs also go to `recipient`. (`msg.sender` separately receives the payment-token dust sweep — see LOCAL-BM20-002.)

**Cost floor.** Qualifying costs `Σ_{k<count} price·r^k` of real payment token routed to the dispatcher, which per §1/§5 is by construction larger than the pot. This is what makes the mechanism a nudge and not a honeypot — *provided* the owner never over-funds. Over-funding beyond the mint cost is the standing owner footgun (memory: `phoenix-nft-staking-batchminter-nudge`); story-022 does not change it, and by making *every* token claimable it widens the set of assets over-funding can apply to.

**No FIFO / no accrual.** Winner-take-all, first qualifying tx in the block takes the whole balance of every token it lists. `minRewards` protects only the *loser* from paying mint costs for a sniped pot (§5). MEV posture explicitly unchanged and accepted.

**`rescueERC20` is now a race the owner usually loses** — correctly re-documented at L191–L201. The only dependable sequence is pause → rescue.

---

## 5. Local findings

### LOCAL-BM20-001 — Duplicate `rewardTokens` entries do NOT "fail closed"; a batcher can reclaim its own mid-loop donations, defeating §4.2

- **Type**: spec violation / incentive leak (missing dedupe + snapshot-vs-live-balance mismatch)
- **Severity (local)**: `local-high` — final severity to severity-classifier; the *economic* ceiling is bounded (see below), so Medium is the likely landing spot.
- **Function**: `batchMint` → `_snapshotRewards` (L416–436) / `_payRewards` (L452–461)
- **Lines**: 429 (`snapshot[i] = available` — same value written for every duplicate), 458 (`safeTransfer(recipient, amount)` — paid per entry with no cumulative cap)

**Claim under test.** §4.5 and the NatSpec at L261–L264 both assert that duplicate entries "fail closed": *"both snapshot the same balance. The first transfer drains it; the second either reverts on insufficient balance or transfers into a now-empty pot."* This is the stated justification for having no dedupe pass.

**Why it is false.** The claim assumes the contract's balance of the token at payout time equals the snapshot. It does not — §4.2 is built on the fact that *the dispatcher donates reward token into this contract on every mint*, so at payout time the live balance is `B + D` where `B` is the snapshot (prior pot) and `D` is this batch's own donations. `BalancerPoolerV2` confirms the mechanic on mainnet: `ISkyPSM(psm).buyGem(batchMinter, gemAmt)` delivers USDC straight to the batch minter on every mint (`lib/mutable/yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol:260`), while `primeToken()` is USDS — so the donated asset is *not* excluded by the §4.1 guard and is exactly what a caller lists.

With `k` duplicate entries the payout pass transfers `B` k times and succeeds while `k·B <= B + D`. Therefore whenever `D >= B` — i.e. whenever this batch's donations are at least the pot the previous batch left behind, which is the *normal steady state* since each claim resets the pot to ~0 and refills it with the claimer's own donations — the duplicate succeeds and the batcher pockets its own donations instead of leaving them to seed the next claimant. That is precisely the "funding their own reward within a single transaction" outcome §4.2 declares itself to be "the only thing preventing".

**PoC** (`workspace/phoenix-nft-staking/test/PoC_DuplicateRewardWithDonations.t.sol`, both pass at `0d1a0b2`):

```
[PASS] test_DuplicateDoesNotFailClosedWhenDispatcherDonates()   // 2 entries -> recipient gets 2*B, donations partly clawed back
[PASS] test_ManyDuplicatesDrainOwnDonationsEntirely()           // 6 entries -> contract balance 0; recipient gets B + all of D
```

The second case leaves the contract with **zero** reward balance: the next claimant's pot is fully destroyed.

**Why the existing witness test misses it.** `test_DuplicateRewardTokenFailsClosed` (`test/BatchNFTMinterMultiTokenNudge.t.sol:656`) never calls `setPerMintDonation`, so it runs with `D == 0` — the one configuration in which the claim holds and the one the spec says does not occur in production. The test therefore certifies the property under an assumption §4.2 explicitly denies. This is a test-coverage gap, not just a code gap.

**Impact.** No third-party funds are stolen: the extractable amount is capped at `B + D`, all of which is either the prior pot (legitimately winnable in full by a single non-duplicate entry) or the batcher's own donations. The damage is (a) the donate-forward incentive is nullified at the batcher's option — the mechanism degenerates toward a per-batch rebate, weakening the "every claim is net-positive for the protocol" argument in §1 by the donation amount; (b) the next claimant's pot can be zeroed; (c) a load-bearing documented invariant is false, which is a Law-2 faithfulness break against `docs/multi-token-nudge.md` §4.2/§4.5.

**Recommendation.** Cheapest O(n) fix that preserves the no-dedupe stance: cap cumulative payout per token against the live balance, e.g. in `_payRewards` use `amount = Math.min(snapshot[i], liveBalance - Σ paidSoFar)` — or, more directly aligned with §4.2, record the total snapshotted amount per token and require the post-payout balance to be `>= preLoopBalance - snapshotTotal`. Alternatively make duplicates revert explicitly rather than relying on an emergent property. Either way §4.5 must be rewritten and the witness test re-run **with donations configured**.

---

### LOCAL-BM20-002 — The payment-token balance is sweepable by any caller at `count = 1`, so the §4.1 guard does not achieve its stated purpose

- **Type**: doc/code mismatch + unpriced value leak
- **Severity (local)**: `local-low` (behaviour is documented at L63–L68 as a feature; the *rationale* around it at §4.1 / L51–L56 is wrong)
- **Function**: `batchMint` step 10 (L381–L387)

Step 10 sweeps the contract's **entire** payment-token balance (not merely the caller's unspent surplus) to `msg.sender` whenever it is `>= DUST_THRESHOLD`. It is gated by neither `nudgeSize` nor `qualifies`. Consequently:

- §4.1's premise — that the payment-token exclusion "is the thing standing between a caller and the payment-token balance held mid-transaction" — is only true for **sub-`DUST_THRESHOLD` (1e6 wei) residue**. Any larger payment-token balance is already claimable, more cheaply than the nudge (one mint instead of `nudgeSize`).
- The contract-level NatSpec at L51–L56 says every balance "other than the dispatcher's payment token, which is excluded by an explicit guard" can be swept by a qualifying caller. Read plainly this implies the payment token is protected. It is not; it is *more* exposed.
- `rescueERC20`'s "race you will lose" caveat (L191–L201) understates the payment-token case: that race is lost to a `count = 1` caller, not only to a `nudgeSize` batcher.
- `totalPaid` floors at 0 (`paymentAmount > remaining ? paymentAmount - remaining : 0`), so when the contract held a donation the return value reports 0 while the caller is net **positive**. Off-chain consumers reading `totalPaid` as "net spend" get a wrong number on exactly the paths where money moved the other way.

**PoC**: `PoC_PaymentTokenSweep.test_AnyoneSweepsPaymentTokenBalanceWithoutQualifying` — 500e18 of stranded payment token swept by a non-qualifying `count = 1` caller, `totalPaid == 0`.

**Recommendation**: either bound the sweep to the caller's own unspent budget (track `paymentAmount − amountSpent` rather than reading `balanceOf`), or correct §4.1 and the contract NatSpec to state that the payment token is *not* protected and that only sub-threshold dust survives a batch. Ledger note: the sweep-the-whole-balance behaviour predates story-022 — reconcile against run-19 entries before filing as new.

---

### LOCAL-BM20-003 — Fee-on-transfer reward token: the fee is borne by `recipient`, who may not be the caller who accepted the risk

- **Type**: documented-risk residue
- **Severity (local)**: `local-low` (§4.4 accepts the shortfall explicitly; do not re-litigate the decision)
- **Function**: `_payRewards` (L458), floor check at `_snapshotRewards` (L431)

`minRewards[i]` is a floor on the **contract's pre-transfer balance**, never on delivered amount, so a fee-on-transfer or negatively-rebasing token clears the floor and delivers less. This is §4.4 and is pinned by `test_FeeOnTransferDeliversBelowMinReward` (5% tax, delivered 950e18 against a 1000e18 floor). Two residues worth surfacing rather than closing:

1. The NatSpec frames the tradeoff as "at the caller's discretion", but the shortfall lands on `recipient`, which is an arbitrary caller-chosen address. The party who bears the loss is not necessarily the party who consented. Only material when a UI/integrator passes a third-party recipient.
2. `NudgePaid(recipient, token, amount)` emits the **snapshot** amount, not the delivered amount, so on any FoT/rebasing token the event over-reports what the recipient received. Any off-chain accounting keyed on `NudgePaid` inherits the error. (QA.)

Note the reward-token address is untrusted input, so "the protocol does not use this asset class" is not a containment argument here the way it is for the payment token — it is only an argument that no *honest* caller will hit it.

---

### LOCAL-BM20-004 — Unbounded caller-supplied arrays and `count` (accepted, recorded for completeness)

- **Severity (local)**: `local-info`
- `count` (L363) and `rewardTokens.length` (L424/L454) are unbounded; memory for `snapshot` grows with the array. All costs fall on the caller, no shared resource is consumed, and §4.5/§8 accept this explicitly. No DoS on other users. Recorded so the unbounded-loop checklist item is not silently ticked.

---

### Carried forward / resolved from run-19

- `LOCAL-BM-001` (reentrancy surface: unguarded `batchMint` with an untrusted `onERC1155Received` recipient callback) — **resolved** by `nonReentrant` (L300) per §4.3, verified by `test_RevertWhen_RewardTokenReentersBatchMint` (exact `ReentrancyGuardReentrantCall` selector). The residual callback surface is characterized in §6 below.
- `LOCAL-BM-002` (winner-take-all pot / over-funding footgun) — **still live**, unchanged by story-022 and broadened to every ERC20 the contract holds. Reconcile against the existing ledger entry rather than re-filing.

---

## 6. Reentrancy surface after `nonReentrant` — residual analysis

Three arbitrary-code hooks fire inside `batchMint`, all attacker-reachable:

1. **`onERC1155Received(recipient)`**, `count` times inside the mint loop — *between* the snapshot and the payout, while the contract holds the caller's payment budget and an open `type(uint256).max` allowance to the minter.
2. **`rewardTokens[i].balanceOf`** (view-typed but the callee is arbitrary and may mutate state — Solidity's `view` on `_snapshotRewards` constrains *this* contract, not the callee) during the snapshot pass.
3. **`rewardTokens[i].transfer`** during the payout pass, once per element.

Local conclusion: **the guard is sufficient for this contract's own invariants.** Re-entry into `batchMint` reverts; every other entry point is `onlyOwner` or `onlyPauser`, and `batchMint` writes no persistent state that a cross-function re-entry could desynchronize. Within-transaction manipulations available to hook 2/3 are self-harming only:

- hook 3 on token `A` moving token `B` out of the contract makes `B`'s later `safeTransfer` revert → whole batch rolls back (caller's loss);
- hook 2 inflating a balance before its own snapshot only pays the caller back their own tokens;
- pushing payment token in mid-tx enlarges the caller's own step-10 sweep — net-zero for them, and already characterized by LOCAL-BM20-002.

**Deferred to interaction analysis (do not adjudicate here):** the `onERC1155Received` hook can call *other* protocol contracts (`NFTStaker*`, dispatcher, `yield-claim-nft` hooks) mid-mint-loop while this contract's allowance to the minter is `type(uint256).max`; and `configs()` tuple-positional coupling to `INFTMinterV2` (an ABI drift silently repoints `paymentToken`, which is the §4.1 exclusion key — cf. the phStaging `YS-20 minter-repoint ABI-drift` precedent).

---

## 7. Trust assumptions (for downstream agents)

1. `tokenMinter` and `dispatcherIndex` are owner-pinned and correct; `configs(idx)` returns the dispatcher at tuple position 0 and `primeToken()` returns the asset the minter actually pulls. If these diverge, the §4.1 exclusion key is wrong and the payment token becomes listable as a reward.
2. `paymentToken` (USDS on mainnet via `BalancerPoolerV2`) is a standard, non-FoT, non-rebasing ERC20. The dust-sweep/`totalPaid` ledger assumes this.
3. The dispatcher donates a **different** asset (USDC) than `primeToken()` (USDS) on every mint. If a future dispatcher ever donated its own prime token, the §4.1 guard would make the nudge unclaimable through the reward path and it would instead flow out through the step-10 sweep to any `count = 1` caller.
4. `rewardTokens[i]` is fully untrusted arbitrary code. No assumption of ERC20 conformance beyond "reverts or returns" (SafeERC20 handles the non-standard return).
5. `recipient` is fully untrusted and receives an ERC1155 callback `count` times per batch.
6. Owner is non-malicious (Law 3) and funds the pot conservatively — the "not a honeypot" argument in §1 holds *only* while the pot stays below the `nudgeSize` mint cost. Over-funding is a live footgun, now applying to every asset the contract holds.
7. `pauser` is the Phoenix global Pauser; pausing is the only reliable precondition for `rescueERC20`.

---

## 8. Complexity

| Metric | Value |
| --- | --- |
| LOC (incl. NatSpec) | 462 |
| Functions | 10 (`batchMint`, 2 private helpers, 5 owner setters, `pause`/`unpause`, `rescueERC20`) — plus inherited |
| State variables | 4 own (+ OZ `Ownable`/`Pausable`/`ReentrancyGuard`) |
| Distinct external call sites | 9 |
| Loops | 3 (mint ×count, snapshot ×n, payout ×n) |
| Assembly / unchecked / delegatecall | none |
| Inheritance | `Ownable`, `Pausable`, `ReentrancyGuard`, `IPausable` |

Note: the private-helper extraction (`_snapshotRewards`, `_payRewards`) is stack-pressure-driven (0.8.20, no `via_ir`), not a semantic split — the helpers are `private` and single-call-site, so no new external surface.
