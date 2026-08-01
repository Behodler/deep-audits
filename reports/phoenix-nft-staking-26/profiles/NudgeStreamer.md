# Contract Profile — `src/NudgeStreamer.sol`

- **Commit**: `9611312` (`[story-032]`); this file last changed at `2ba764e` (`[story-031]`)
- **Solidity**: `^0.8.20` (checked arithmetic throughout; no `unchecked`, no assembly)
- **Inheritance**: `INudgeStreamer`, `Ownable`, `ReentrancyGuard`
- **LOC**: 272 · external/public fns: 4 · state vars: 1 mapping + 1 constant
- **Depth**: FULL (in-scope changed contract)

---

## 1. Verified local properties

### 1.1 Access control table

| Function | Visibility | Gate | Reentrancy | Writes |
|---|---|---|---|---|
| `registerStream(batchMinter, token, duration)` | external | `onlyOwner` | **NONE** | `s.duration`, `s.buffer`, `s.rewardPerSecond`, `s.lastUpdate` |
| `collectNudge(recipientBatchMinter, token, amount)` | external | **none (permissionless)** | `nonReentrant` | `s.buffer`, `s.rewardPerSecond`, `s.lastUpdate` |
| `pullPendingStream(token)` | external | **none** — but keyed on `msg.sender`, so a caller can only flush *its own* stream | `nonReentrant` | `s.buffer`, `s.lastUpdate` |
| `pendingStream(batchMinter, token)` | external view | none | n/a | — |
| `PRECISION`, `streams` | public getters | none | n/a | — |

`Ownable` also exposes `transferOwnership` / `renounceOwnership` (OZ defaults, unrestricted beyond `onlyOwner`). **`renounceOwnership` is reachable** and would permanently freeze `registerStream`, i.e. no new `(batchMinter, token)` pair could ever be registered. No `_disableInitializers` concern — this is a plain constructor deploy, not upgradeable.

**VERIFIED**: `pullPendingStream` cannot settle another party's stream. `streams[msg.sender][token]` (`:221`) makes the recipient identity structurally equal to `msg.sender`; the `recipient` argument to `_settle` is `msg.sender` (`:224`). There is no operator/on-behalf-of path.

**VERIFIED**: `collectNudge`'s `recipientBatchMinter` is caller-chosen, but the caller can only *give*, never take — the only transfer sourced from the caller is `safeTransferFrom(msg.sender, …)` (`:194`), and the only outbound transfer goes to `recipientBatchMinter` (`_settle` → `:243`). A donor cannot direct value to itself unless it *is* the batchMinter.

### 1.2 Ordering / CEI

**VERIFIED — effects before interactions at both transfer sites.**

`_settle` (`:238-246`):
```
uint256 settled = _accrued(s);
s.lastUpdate = block.timestamp;     // effect
if (settled > 0) {
    s.buffer -= settled;            // effect
    IERC20(token).safeTransfer(recipient, settled);   // interaction
```
`lastUpdate` and `buffer` are both written before the transfer, so a reentrant `pullPendingStream` would find `_accrued == 0`. Redundant with `nonReentrant` on both public entries, but it means `registerStream` — which is **not** `nonReentrant` and *does* call `_settle` (`:134`) — is still safe against a reentrant token: a re-entry into `collectNudge`/`pullPendingStream` finds settled state. It is not safe against a re-entry back into `registerStream` itself, but that path is `onlyOwner`.

**VERIFIED — the snapshot bracket in `collectNudge` encloses exactly one transfer.**
```
:161   _settle(s, recipientBatchMinter, token);      // OUTBOUND transfer (may fire)
:193   uint256 heldBefore = IERC20(token).balanceOf(address(this));
:194   IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
:195   uint256 received = IERC20(token).balanceOf(address(this)) - heldBefore;
```
`heldBefore` is read at `:193`, strictly after the `_settle` outbound transfer and immediately before the inbound pull, with no intervening state or calls. The NatSpec claim at `:176-183` ("a snapshot taken at function entry would span two transfers in opposite directions and net them against each other") is **correct as written and correctly implemented**.

### 1.3 Recompute-on-deposit-only

**VERIFIED.** `s.rewardPerSecond` is assigned at exactly two sites:
- `:139` in `registerStream`
- `:206` in `collectNudge`

`_settle` and `_accrued` never write it, and `pendingStream` is `view`. The phlimbo V1 bug (window reset on every touch) is not reproduced. This matches the ported `PhlimboV2._updatePool` semantics.

### 1.4 Arithmetic

| Expression | Site | Overflow reachable? | Rounding |
|---|---|---|---|
| `s.buffer * PRECISION / duration` | `:139`, `:206` | needs `buffer > 1.16e59`; not reachable for a real ERC20 | floor — under-states rate, dust stays in buffer (protocol-favouring) |
| `s.rewardPerSecond * elapsed / PRECISION` | `:268` | worst case `duration == 1`, `buffer ~1e30`, `elapsed ~1e10` → ~1e58 < 2^256. Not reachable | floor (protocol-favouring) |
| `balanceOf(this) - heldBefore` | `:195` | **underflows and reverts** if the token *decreases* this contract's balance during `transferFrom` (reflection token taxing the receiver's standing balance). Fails CLOSED (panic `0x11`, not a named error) | n/a |
| `s.buffer -= settled` | `:242` | cannot underflow: `_accrued` caps at `s.buffer` (`:270`) | n/a |
| `block.timestamp - s.lastUpdate` | `:267` | cannot underflow: `lastUpdate` only ever set to `block.timestamp` | n/a |

**VERIFIED — `PRECISION` is a fixed-point multiplier, not decimal normalisation.** It cancels: `(buffer·1e18/duration)·elapsed/1e18 == buffer·elapsed/duration`. Every stored value and every transfer is in the token's native units. For a 6-dp token (`buffer = 1e6`, `duration = 1e6`) → `rps = 1e18`, `accrued = elapsed` — no truncation to zero. The NatSpec at `:44-53` is accurate.

**No unbounded loops. No recursion. No weak randomness. No assembly. No transient storage. Not upgradeable — no initializer or storage-layout concern.**

### 1.5 Conservation / custody invariant — **PARTIALLY VERIFIED, see §5.1**

Claimed at `:55-62` and `:258`:
```
Σ buffer_i  <=  IERC20(token).balanceOf(address(this))     [over all pairs on one token]
```
- **Established at the credit site**: `received = min(balanceDelta, amount)` (`:195-196`) ⇒ each `buffer` increment is backed by a measured, capped receipt. **VERIFIED.**
- **Preserved by `_settle`**: decrements `buffer` and `balanceOf` by the same `settled`. **VERIFIED.**
- **NOT preserved against post-credit balance erosion.** The measurement is a one-shot reading across the pull. Nothing re-validates it. A token whose balance shrinks *after* the credit (negative rebase, deflationary burn-on-hold, blacklist-zeroing) breaks the sum, and this contract has no mechanism to detect or absorb it. The NatSpec's "by construction rather than by convention" (`:56-57`) is **over-broad**: the construction closes the fee-on-transfer direction at the credit site only.

### 1.6 Registration lifecycle — **verified gap**

There is **no deregistration path**. `registerStream` rejects `duration == 0` (`:126`), and no other function writes `s.duration`. Once `(batchMinter, token)` is registered it is registered forever. Combined with the absence of any owner withdrawal (§2.3), a buffer is recoverable only by the registered `batchMinter` calling `pullPendingStream`. `BatchNFTMinterMultiToken` calls it only from inside `batchMint`'s loop over `_nudgeTokens` (`:532-534`), so recovery requires the token to be (re-)whitelisted, the minter/dispatcher configured, and the contract unpaused. **Already filed — ledger `4a1d8edc92` (L, open).**

---

## 2. Interface abstraction

### 2.1 External entry points

```
registerStream(address batchMinter, address token, uint256 duration)   onlyOwner
  reverts: NudgeStreamer__ZeroDuration | NudgeStreamer__NotWhitelisted
           | (propagates any revert from batchMinter.isNudgeToken)
  calls:   IMultiTokenNudgeWhitelist(batchMinter).isNudgeToken(token)  [STATICCALL]
           IERC20(token).transfer(batchMinter, settled)                [via _settle]
  emits:   StreamRegistered, (Streamed)

collectNudge(address recipientBatchMinter, address token, uint256 amount)   nonReentrant
  reverts: NudgeStreamer__NotRegistered | ZeroAmount | ZeroReceived
           | panic 0x11 (balance-decreasing token)
  calls:   IERC20(token).transfer(recipientBatchMinter, settled)       [via _settle]
           IERC20(token).balanceOf(this)  x2
           IERC20(token).transferFrom(msg.sender, this, amount)
  emits:   (Streamed), NudgeCollected

pullPendingStream(address token)   nonReentrant
  reverts: never on unregistered (silent no-op, :222); propagates transfer reverts
  calls:   IERC20(token).transfer(msg.sender, settled)
  emits:   (Streamed)

pendingStream(address, address) view -> uint256
```

### 2.2 What it assumes of each callee

| Callee | Methods | Trust | Assumptions |
|---|---|---|---|
| `IERC20 token` (owner-vetted via the batchMinter whitelist) | `balanceOf`, `transfer`, `transferFrom` | **semi-trusted** | Via `SafeERC20`: return value checked, non-`bool`-returning tokens tolerated, revert-on-failure required. **Assumes the balance does not change except by this contract's own transfers** — see §5.1. No decimals assumption (`PRECISION` cancels). No assumption that `transferFrom` moves exactly `amount` — this is the story-031 change. |
| `IMultiTokenNudgeWhitelist batchMinter` (owner-supplied) | `isNudgeToken(address)` | **semi-trusted** | Declared `external view` in the local interface (`:16`) ⇒ compiled to `STATICCALL` ⇒ **cannot reenter or mutate**. VERIFIED. Assumed to revert (no such function) for a non-MultiToken target — this is the structural "only a MultiToken batchMinter can be registered" guard. **Assumed truthful**: a hostile address can trivially return `true` for any token, so this guard is a *typo screen for a trusted owner*, not an authorisation check. |
| `recipientBatchMinter` as transfer destination | — | **untrusted address, but only ever credited** | Never `.call`ed. Receives tokens via `safeTransfer`; if the token has a receive hook the recipient gets control while streamer state is already settled (§1.2) and `nonReentrant` is held. |

### 2.3 What a caller may assume of `NudgeStreamer`

- `collectNudge` is permissionless and **push-only**; a donor cannot withdraw.
- `collectNudge` credits `min(received, amount)`, **does not return the credited value**, and reports it in `NudgeCollected.amount`.
- `pullPendingStream` is a **guaranteed no-op, never a revert**, for an unregistered token — this is what makes `batchMint`'s blind loop over the whole whitelist safe *for unregistered entries*. It is **not** a no-op-on-failure for a *registered* entry: any revert propagates.
- There is **no `rescueERC20`, no owner withdrawal, no pause, and no deregistration.** Asymmetric with `BatchNFTMinterMultiToken.rescueERC20` and `NFTStaker.emergencyWithdraw`, both of which the repo treats as required escape hatches.
- `pendingStream` never mutates and never recomputes the rate.

---

## 3. Value flow map

All amounts are ERC20; there is no ETH path (no `receive`, no `payable`).

| # | Flow | Debited | Credited | Order | Amount is… |
|---|---|---|---|---|---|
| F1 | Settle-out (in `registerStream`, `collectNudge`, `pullPendingStream`) | `NudgeStreamer` | `recipient` (= `batchMinter`) | **first**, before any inbound | **derived** — `min(rewardPerSecond·elapsed/1e18, buffer)`, floor-rounded. A *stated* amount w.r.t. the transfer call; the recipient's actual receipt is unmeasured. |
| F2 | Donation pull | `msg.sender` (donor) | `NudgeStreamer` | **after F1** | request is `amount`; the **credit is a MEASURED balance delta**, capped: `min(balanceAfter − balanceBefore, amount)` (`:193-196`). This is the story-031 change. |

**Accounting asymmetry (verified, and deliberate):** F2 is measured, F1 is not. The streamer debits its own `buffer` by the amount it *asks* the token to transfer out, never by what the recipient actually receives. For a fee-on-transfer token the recipient therefore receives less than `buffer` was reduced by — the shortfall accretes as uncredited idle balance inside the streamer, which is the protocol-favouring direction and is consistent with the stated dust policy. It does mean `batchMint`'s snapshot (which reads the batchMinter's own `balanceOf`) sees the *net* arrival, so no over-payout results. **No caller relies on F1 being exact.**

**Ordering constraint (verified load-bearing):** F1 must precede the `heldBefore` read of F2. If reversed or widened, the two opposite-direction transfers net against each other and the measured credit is wrong by `settled`. Established at `:161` vs `:193`.

---

## 4. story-031 accounting — precise profile

**Where the delta is measured**: `:193` (`heldBefore`), `:194` (pull), `:195` (`received`), `:196` (cap at `amount`), `:199` (revert if zero), `:201` (`buffer += received`), `:206` (rate from `s.buffer`), `:211` (event carries `received`).

**Fee-on-transfer / taxed / reflection-on-send token**: credits strictly less than `amount`. The donor absorbs the tax. `Σ buffer_i <= balanceOf(this)` holds. The previously-possible failure mode — over-stated buffer ⇒ first-settling pair consumes a sibling's backing ⇒ sibling's `pullPendingStream` reverts ⇒ **`batchMint` bricked**, because `BatchNFTMinterMultiToken:532-534` loops `pullPendingStream` over the whole whitelist with no `try/catch` — is **closed for this direction**. The named `NudgeStreamer__ZeroReceived` (`:199`) handles the 100%-tax degenerate case with a distinct, diagnosable error.

**Donation-during-pull (token with a transfer callback)**: `received > amount` ⇒ capped to `amount` (`:196`); surplus is left as uncredited idle balance. Cannot be attributed to this stream. VERIFIED.

**Rebasing token — the residual, see §5.1.** A *positive* rebase leaves surplus uncredited (safe direction). A *negative* rebase after the credit breaks the custody invariant, and the credit site cannot defend it.

**Balance-decreasing-on-receive token**: `:195` underflows ⇒ revert. Fails closed.

**Does any caller still assume the SENT amount?**
- In-repo: the only `collectNudge` caller is `test/mocks/MockNudgeDonor.sol:15`, which forwards and ignores. No production in-repo caller.
- The function returns `void` (unchanged signature, deliberately — `INudgeStreamer.sol:20-23`), so **no on-chain consumer can learn the credited amount**. A donor contract that maintains its own "amount donated to the pot" counter from its *sent* figure will over-state the pot after story-031. The real production donor is `NudgeRatchet.dispatch` in the `yield-claim-nft` sibling.
- **UNVERIFIED — cross-repo.** I did not read `yield-claim-nft` (out of scope for this profile). Whether `NudgeRatchet` keeps a sent-amount-derived counter is a **handoff item for the interaction scanner**, not something I can settle from this repo. It is only reachable at all if a taxed/rebasing token is the nudge asset.
- Allowance hygiene: a donor doing `forceApprove(amount)` then `collectNudge(…, amount)` has its allowance fully consumed by `transferFrom` regardless of the tax (the token takes the tax on its own side), so no residual allowance is stranded. VERIFIED.
- **Event semantics changed under an unchanged ABI.** `NudgeCollected.amount` (`:112`) now carries the *credited receipt*, not the request, with no signature change and therefore **no compile-time or ABI-level signal to off-chain consumers**. `INudgeStreamer` documents this (`:14-18`). Correct choice, but the silent repoint is worth a QA note.

---

## 5. Local findings

### 5.1 LOCAL-NS-01 — the custody invariant is documented as holding "by construction"; it holds only against the fee direction

- **Type**: over-broad verified-property claim / documentation-vs-code divergence, with a DoS consequence
- **Severity**: local-medium (final severity is the classifier's call)
- **Site**: `NudgeStreamer.sol:55-62` (contract NatSpec), `:250-265` (`_accrued` NatSpec), `:193-196` (the credit)

`:56-57` asserts the credit is correct "**by construction** rather than by convention", and `:258` states `Σ buffer_i <= balanceOf(this)` as established "at ONE site". The credit site is a **one-shot measurement across a single transfer**, so it establishes the invariant only at credit time and only against balance *shortfalls during the pull*. Any post-credit erosion of the streamer's holdings of that token breaks the sum with nothing to detect it:

- negative-rebasing token,
- deflationary / burn-on-hold token,
- a token that zeroes a blacklisted holder's balance,
- an owner `rescue`-style function on the *token* side.

Consequence chain: sum exceeds custody ⇒ the first pair to settle is paid its full over-stated buffer ⇒ a sibling pair's `_settle` `safeTransfer` reverts ⇒ `pullPendingStream` reverts ⇒ **`BatchNFTMinterMultiToken.batchMint` is bricked for every caller**, because the flush loop at `:532-534` is unguarded. This is exactly the failure mode story-031's NatSpec describes at `:169-174`, reachable through a different door.

- **Reachability**: requires the owner to whitelist such a token *and* register a stream for it. Owner footgun (non-obvious: the in-source NatSpec actively tells the reader the invariant is structural), not a malicious-owner vector.
- **Adjacency to disclose** (do not silently collapse): ledger `Q-03 bfdb50105e` (wont-fix) covers a shrinking token reverting the batch **at the `_payRewards` site in the batchMinter**; ledger `L-03 6f46ec80f1` (open) covers a *different* NatSpec overclaim (burst-capture). This one is a **new claim introduced at `2ba764e`** at a **new site** (`NudgeStreamer` credit/settle), with the brick landing via the streamer flush loop. Per repo policy, in-source NatSpec carries no suppression authority and a falsely-exhaustive claim raises rather than lowers severity.
- **Recommendation**: soften `:56-62` and `:250-265` to name the direction actually closed, and/or wrap the flush loop at `BatchNFTMinterMultiToken:533` in `try/catch` so one under-backed stream cannot brick every batch.

### 5.2 LOCAL-NS-02 — `NudgeCollected.amount` silently repointed from request to receipt

- **Type**: off-chain consumer semantics change under an unchanged ABI
- **Severity**: local-low / QA
- **Site**: `:211` vs pre-`2ba764e` `emit … amount …`

Same event topic, same 4 fields, same types; the third non-indexed value now means something different. Any indexer that reconciled `Σ NudgeCollected.amount` against donor-side sent totals now disagrees with itself across the deployment boundary. Documented in `INudgeStreamer.sol:14-18`; there is no on-chain signal. Recommend a version bump or a new event name if any indexer spans both.

### 5.3 Already-filed, re-confirmed present at `9611312` (do NOT re-file)

| Ledger | Status | Confirmed at 9611312 |
|---|---|---|
| `4a1d8edc92` — no rescue; buffers strand on decommission / permanent de-whitelist | open | **Yes.** No owner withdrawal, no deregistration, `duration == 0` unreachable (`:126`). |
| `aaebb4b9b0` — `collectNudge` dust window-reset griefing | open | **Yes.** `_settle` at `:161` fires before any amount validation; `:206` resets the window over the full duration on any non-zero credited deposit. story-031 narrows it marginally (a 100%-tax dust deposit now reverts at `:199` instead of resetting the window) but does not close it — a 1-wei genuine deposit still resets. |
| `6f46ec80f1` — time-throttle not value-cap; NatSpec overclaim | open | **Yes.** Nothing in this contract relates the buffer to mint cost. |
| `cf332bf46c` — `INudgeStreamer` under-documents no-op/onlyOwner/recompute semantics | open | **Partially addressed.** story-031 added extensive `collectNudge` docs (`INudgeStreamer.sol:8-23`), but `pullPendingStream`'s no-op contract, `registerStream`'s `onlyOwner`, and recompute-on-deposit-only are still undocumented in the interface (`:30-42`). |

---

## 6. Could not verify from this contract

1. Whether the production donor (`NudgeRatchet` in `yield-claim-nft`) keeps a sent-amount-derived counter that story-031 desynchronises. Cross-repo; handoff to the interaction scanner.
2. Whether any deployed `NudgeStreamer` instance exists and what its registered `(batchMinter, token)` pairs and `duration` values are. Requires chain state; the repo has no deploy artifacts by design (`CLAUDE.md`: "This is NOT a deployment or staging repo").
3. Whether `duration == 1` (accepted by `:126`) is ever configured — it would collapse the anti-burst purpose to a one-second window. Owner config, not verifiable here.
