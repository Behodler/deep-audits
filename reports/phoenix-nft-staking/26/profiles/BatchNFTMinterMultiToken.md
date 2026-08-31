# Contract Profile — `src/BatchNFTMinterMultiToken.sol`

- **Commit**: `9611312` (`[story-032] Remove the admin-time payment-token whitelist gate`)
- **Solidity**: `^0.8.20` (checked arithmetic; no `unchecked`, no assembly)
- **Inheritance**: `Ownable`, `Pausable`, `ReentrancyGuard`, `IPausable`
- **LOC**: 837 (≈180 code, the rest NatSpec) · external fns: 12 · state vars: 6 + 1 constant
- **Depth**: FULL (in-scope changed contract)

---

## 1. Verified local properties

### 1.1 Access control table

| Function | Gate | `whenNotPaused` | `nonReentrant` | Writes |
|---|---|---|---|---|
| `batchMint(count, recipient, paymentAmount, minRewards[])` | **none (permissionless)** | ✅ | ✅ | none — **no storage write anywhere in `batchMint`** |
| `setTokenMinter(ITokenMinterV2)` | `onlyOwner` | ✗ | ✗ | `tokenMinter` |
| `setDispatcherIndex(uint256)` | `onlyOwner` | ✗ | ✗ | `dispatcherIndex` |
| `setNudgeSize(uint256)` | `onlyOwner` | ✗ | ✗ | `nudgeSize` |
| `setNudgeTokenWhitelist(address, bool)` | `onlyOwner` | ✗ | ✗ | `_nudgeTokens`, `_nudgeTokenIndex` |
| `setNudgeStreamer(address)` | `onlyOwner` | ✗ | ✗ | `nudgeStreamer` |
| `setPauser(address)` | `onlyOwner` | ✗ | ✗ | `pauser` |
| `pause()` / `unpause()` | `onlyPauser` | ✗ | ✗ | `Pausable._paused` |
| `rescueERC20(IERC20, address, uint256)` | `onlyOwner` | ✗ | **✗** | none |
| `getNudgeTokens()` / `isNudgeToken(address)` | view | — | — | — |

**VERIFIED — `batchMint` is storage-write-free.** Every quantity it computes (`qualifies`, `snapshot`, `budget`, `refund`, `totalPaid`) is memory/stack-local. This is a strong local property: no reentrant or interleaved call can corrupt persistent accounting, because there is none. The contract's entire "state" from `batchMint`'s perspective is its ERC20 balances plus owner-set config.

**VERIFIED — no unset-gate footgun on `pauser`.** `onlyPauser` (`:248-251`) compares to `pauser`, which defaults to `address(0)`. `msg.sender` can never be `address(0)`, so an unconfigured `pauser` makes `pause()`/`unpause()` unreachable rather than universally callable. Matches the NatSpec claim at `:186`.

**Not verified / residual**: `rescueERC20` is `onlyOwner` but **not** `nonReentrant` and calls `safeTransfer` on an owner-supplied arbitrary token. It cannot be reached from inside `batchMint` (which is `nonReentrant`, and `rescueERC20` requires the owner as `msg.sender`), so there is no cross-function reentrancy path of consequence. Same shape as the V2-staker `rescueERC20` gap the sibling profile notes.

### 1.2 The two load-bearing ordering constraints — **BOTH HOLD at `9611312`**

The registry names *snapshot-before-pull* and *refund-before-payout*. Determined from code, not comments:

#### Constraint 1 — snapshot BEFORE pull: **HOLDS**

```
:538        uint256[] memory snapshot = _snapshotRewards(minRewards, qualifies);
                ↳ :801   uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;
:579   {
:580        uint256 heldBeforePull = paymentToken.balanceOf(address(this));
:581        paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);
```

`_snapshotRewards` is invoked at `:538`; the caller's funds arrive at `:581`. **41 lines and zero external calls separate them** (only comments and the opening of the block-scope at `:579`). Therefore, when `paymentToken ∈ _nudgeTokens`, the balance read at `:801` for that entry is the *uncontaminated standing pot* `P` — `paymentAmount` has not yet arrived and can never be paid back out as a reward. **VERIFIED.**

Additional ordering, also intact and required for the streamed funds to be counted: the streamer flush (`:528-536`) sits **before** the snapshot at `:538`.

#### Constraint 2 — refund BEFORE payout: **HOLDS**

```
:707   {
:708        uint256 available = paymentToken.balanceOf(address(this));
:709        uint256 refund = budget > available ? available : budget;
:710        if (refund / DUST_THRESHOLD != 0) {
:711            paymentToken.safeTransfer(msg.sender, refund);
:712            totalPaid = paymentAmount - refund;
…
:726   _payRewards(recipient, snapshot);
                ↳ :833   IERC20(rewardToken).safeTransfer(recipient, amount);
```

The refund transfer is at `:711`; the payout transfers begin at `:833`, reached from `:726`. Nothing between `:716` and `:726` but comments. **VERIFIED.**

**A precise correction to the stated rationale.** The NatSpec at `:659-665` justifies this order as "so a payout can never be funded out of a refund that is owed, and vice versa." In the **ordinary** case *both* orderings are solvent, so the constraint is not what makes the ordinary case work:

- balance at `:708` is `P + (credited − C) + D`
- refund needs `credited − C`, leaving `P + D`
- payout needs `snapshot == P` ≤ `P + D` ✅

The ordering's *actual* effect is in the **degraded** case: whichever transfer runs second absorbs any shortfall. Refund-first therefore charges erosion to the **pot / next claimant**, never to the caller. That is a deliberate and defensible choice, and the NatSpec's own "DURABLE RESIDUAL" note (`:695-702`) admits it. Recording it here so a future editor does not "restore symmetry" by swapping the order and silently move erosion onto callers.

**Both constraints were untouched by story-032.** `git diff 2ba764e 9611312 -- src/` shows no change inside `batchMint` — not the snapshot loop, not the budget block, not steps 9/10, not `DUST_THRESHOLD`. The diff is confined to the contract header NatSpec, the deleted `BatchMint__RewardTokenIsPaymentToken` error, `setNudgeTokenWhitelist`'s add branch, and `_resolvePaymentPath`'s doc comment.

### 1.3 Budget conservation — **VERIFIED**

```
:580-604   budget = min(balanceAfterPull − balanceBeforePull, paymentAmount)
:649       budget -= price          (only mutation, monotonically decreasing)
:709       refund  = min(budget, balanceOf(this))
:712       totalPaid = paymentAmount − refund
```

Chain: `refund ≤ budget ≤ paymentAmount`, therefore `:712` cannot underflow. This is the sole reason the bare subtraction at `:712` is safe — the NatSpec at `:591-603` names the `min` at `:604` as the load-bearing half and it is correct. `budget` is never re-derived from `balanceOf` after `:604`. **VERIFIED** — the `ycn19h1` conflation (`P + (A−C) + D`) cannot be reintroduced at any site in the current code.

`budget` is decremented by the **authoritative pre-mint price** re-read every iteration (`:646`), which matches `NFTMinterV2._executeMint`'s charge-then-ramp order, so no local ramp extrapolation exists to drift. **VERIFIED** against `INFTMinterV2.configs` (`lib/mutable/yield-claim-nft/src/interfaces/INFTMinterV2.sol`) — and that nested pin is byte-identical to top-level `lib/yield-claim-nft@d4cc563` for all three V2 interfaces, so there is no stale-pin ABI drift here.

`price > budget` reverts with a diagnostic (`:647`) rather than falling through to an opaque allowance error, and never draws the shortfall from the contract's own balance. **VERIFIED.**

### 1.4 Approval hygiene — **VERIFIED**

- `forceApprove(nftMinter, price)` at `:648` — an **absolute** target, set immediately before each single `mint`. Never a delta, so correctness is independent of whether the token decrements allowance on `transferFrom`.
- `forceApprove(nftMinter, 0)` at `:655` — unconditional revoke, idempotent, executes for every non-reverting path.
- The approved spender is always the owner-pinned `tokenMinter`; the approved token is always the derived `paymentToken`. **No whitelisted nudge token is ever approved to anyone** — there is no code path from `_nudgeTokens` to `forceApprove`.
- Max exposure at any instant is exactly one mint's price. Contrast the frozen twin `BatchNFTMinter:284`, which approves `type(uint256).max`.

### 1.5 Loops and gas

| Loop | Bound | Controlled by |
|---|---|---|
| `:532-534` streamer flush | `_nudgeTokens.length` | **owner** — 1 external call per entry |
| `:799-807` snapshot | `_nudgeTokens.length` | **owner** — 1 `balanceOf` per entry |
| `:829-835` payout | `snapshot.length` == whitelist length | **owner** — up to 1 `transfer` per entry |
| `:645-651` mint loop | `count` | **caller**, unbounded |

`count` is unbounded but the caller pays the gas and an over-large `count` self-reverts on budget exhaustion (`:647`) — DoS-on-self, not a finding. The three whitelist loops are owner-bounded; a long whitelist can push `batchMint` over the block gas limit and disable the contract for everyone. That is an owner footgun, but an obvious one (the owner adds entries one at a time and would observe the gas), so I do not flag it.

**No recursion, no weak randomness, no assembly, no transient storage, not upgradeable, no ETH path** (no `receive`/`fallback`/`payable`).

### 1.6 Whitelist set integrity — **VERIFIED**

`setNudgeTokenWhitelist` maintains a 1-based-index swap-and-pop set (`:328-349`):
- add reverts on duplicate (`:331-333`) ⇒ **duplicate entries are structurally impossible**, so `_payRewards` cannot double-pay a token (closes audit-21 M-02 by construction). VERIFIED.
- remove reverts when absent (`:338`); swap-and-pop maintains `_nudgeTokenIndex` for the moved element (`:340-344`) and deletes the removed key (`:346`). Index/array agreement is preserved on every branch. VERIFIED.
- `_nudgeTokens[i]` ↔ `_nudgeTokenIndex[t]` round-trip holds for all reachable sequences of add/remove.

**Verified consequence, already filed**: swap-and-pop **reorders** the list, and `minRewards` is positional. A remove+add pair leaves the length unchanged while permuting the order, so an in-flight caller's floor can bind to the wrong token with no length-mismatch revert to catch it. Disclosed in NatSpec (`:277-280`, `:445-451`). Ledger `6b8faaf6dc` (L, open) — **re-confirmed present, do not re-file.** story-032 widens the exposure marginally by making whitelist edits cheaper and possible while the minter/dispatcher are unset (§3.2), so edits are plausibly more frequent.

### 1.7 `qualifies` / floor semantics — **VERIFIED**

`qualifies = nudgeSize != 0 && count >= nudgeSize` (`:513`). Nothing else. There is **no expression anywhere in this contract relating the pot to the mint cost**, which the header states explicitly (`:118-130`) and which prior runs settled as accepted policy (yield-funded pot ⇒ over-funding is misallocation, not value leak).

Floor check `:803-805`: when the batch does **not** qualify, `available` is pinned to `0`, so any non-zero `minRewards[i]` reverts `BatchMint__RewardBelowMinimum`. Intended (a non-qualifying caller declaring a floor is asking for a reward they cannot get). The floor is on this contract's **pre-transfer balance**, not on the recipient's receipt — ledger `Q-03 bfdb50105e` (wont-fix), re-confirmed.

### 1.8 Reentrancy surface — **VERIFIED closed**

`batchMint` is `nonReentrant` and makes these outbound calls, in order: `configs()` (trusted minter), `primeToken()` (dispatcher), `pullPendingStream()` ×N (streamer, itself `nonReentrant`), `balanceOf` ×N on **arbitrary owner-whitelisted token code**, `balanceOf`/`transferFrom`/`balanceOf` on the payment token, then per iteration `configs()`/`forceApprove`/`mint()`, then `forceApprove(0)`, `balanceOf`, `transfer` (refund), `transfer` ×N (payout).

A mistakenly-whitelisted hostile token gets control at up to 2N+ points. Because `batchMint` writes **no storage** and holds `nonReentrant`, the only thing such a token can do is manipulate *balances*:
- push balance in during the step-5 pull window → capped by the `min` at `:604`, credited to nobody. VERIFIED closed.
- push balance in between `:538` and `:833` → increases `D`, benefits the *next* claimant. Benign.
- *remove* balance between `:538` (snapshot) and `:833` (payout) → `_payRewards`'s `safeTransfer` of the stale `snapshot[i]` reverts, bricking the batch. Fails closed; this is ledger `Q-03`'s territory.

There is no inbound ERC721/ERC1155 receive-hook surface on this contract — the minted NFTs go to `recipient`, never to `address(this)`. The `mint()` call does hand control to the trusted minter, which will `_mint`/`_safeMint` to `recipient`; at that instant this contract's approval to the minter is exactly `price` and already decremented from `budget` (`:648-650` order: approve, decrement, mint). VERIFIED — **`budget` is debited before the external `mint`**, so a reentrant path cannot spend the same budget twice even if `nonReentrant` were absent.

---

## 2. Interface abstraction

### 2.1 What it assumes of each callee

| Callee | Methods | Trust | Assumptions |
|---|---|---|---|
| `tokenMinter` (`ITokenMinterV2`/`INFTMinterV2`, owner-pinned) | `configs(index)`, `mint(index, recipient)` | **trusted** | `configs().price` is exactly what the *next* `mint` will charge (charge-then-ramp). `mint`'s `bool` return is **ignored** — a minter that returns `false` without reverting would be treated as success and the budget still debited. Safe only because the minter is trusted; noted as an assumption, not a finding. Assumes `mint` pulls **exactly** `price` via the allowance — if it pulled less, the surplus would silently become pot. |
| `dispatcher` (`ITokenDispatcherV2`, derived) | `primeToken()` | **trusted** | Return value used directly as the payment token with **no zero-address or contract check** (`:748`). A dispatcher returning `address(0)` makes every subsequent `paymentToken` call revert — fails closed. |
| `paymentToken` (derived, `IERC20`) | `balanceOf`, `transferFrom`, `approve`, `transfer` | **semi-trusted** | Via `SafeERC20`/`forceApprove`: return checked, non-standard-return tolerated, allowance-decrement behaviour **not** assumed (absolute approvals). Fee-on-transfer **is** handled (measured budget). Decimals **not** normalised — `DUST_THRESHOLD` is a raw `1e6` literal (§4.3). Balance is assumed not to shrink between `:604` and `:709` (the `available` cap degrades gracefully if it does; §1.2). |
| `_nudgeTokens[i]` (owner-whitelisted, `IERC20`) | `balanceOf`, `transfer` | **semi-trusted, arbitrary code** | Assumed to be a contract implementing `balanceOf` — **no validation at all** at the add site. Assumed non-reverting on `transfer` of a previously-observed balance. Fee-on-transfer/rebasing explicitly tolerated with the delivered amount unmeasured (`:429-433`). |
| `nudgeStreamer` (`INudgeStreamer`, owner-set) | `pullPendingStream(token)` | **semi-trusted** | Assumed to be a **guaranteed no-op, never a revert**, for an unregistered token. **There is no `try/catch` at `:533`** — any revert from any registered stream bricks the whole batch for every caller. |
| `recipient`, `msg.sender` as transfer destinations | — | **untrusted, credit-only** | Never `.call`ed. `recipient != address(0)` enforced (`:472`). |

### 2.2 What a caller may assume of `batchMint`

- Atomic: `count` mints to `recipient`, or full revert.
- Net spend is `totalPaid`; `refund ≤ budget ≤ paymentAmount` always; unspent budget **below `1e6` raw units is forfeited to the pot**, not returned.
- The reward received is this contract's **pre-loop** balance of each whitelisted token — never the post-loop balance, so the caller never receives their own batch's donations.
- `minRewards` must be **exactly** `getNudgeTokens().length` long and positionally aligned to a list that owner action can permute (§1.6).
- Whoever qualifies first takes the entire pot; `minRewards` protects only against paying mint costs for a pot already gone, not against losing the race.

---

## 3. story-032 — what now stands between an arbitrary token and each protected state

### 3.1 The gate that was removed

Deleted at `9611312` from the `allowed == true` branch:
```solidity
(,, IERC20 paymentToken) = _resolvePaymentPath();
if (token == address(paymentToken)) revert BatchMint__RewardTokenIsPaymentToken(token);
```
`_resolvePaymentPath()` itself reverts on `tokenMinter == address(0)`, `dispatcherIndex == 0`, and `dispatcher == address(0)`. So the deletion removed **four** admin-time reverts, not one: the payment-token identity check *and* three configuration-completeness preconditions that were an incidental side effect of calling the resolver.

### 3.2 Remaining runtime checks, per protected state

**(a) The tracked `budget` — NOTHING changed, and nothing *can*.**

Exhaustive: `budget` is written at `:604` and `:649` only. Its inputs are `paymentToken.balanceOf(this)` ×2, `paymentAmount`, and `configs().price`. **`_nudgeTokens` appears in none of them.** There is no data path — not even an indirect one — from whitelist content to `budget`. The whitelist cannot influence the refund's magnitude by any construction. **VERIFIED: no previously-guarded state is newly reachable here.**

The one *interaction* between the two is benign and pre-existing: when `paymentToken ∈ _nudgeTokens`, `_snapshotRewards` reads the payment token's balance at `:801`, which is `P` and not the caller's money (Constraint 1, §1.2). Solvency of paying that `P` out at `:833` after refunding `credited − C` at `:711` holds because the balance at that point is `P + D ≥ P`.

**(b) The per-mint approval — NOTHING changed, and nothing *can*.**

`forceApprove` appears at `:648` and `:655` only, both on `paymentToken` (derived from the pinned dispatcher) to `address(nftMinter)` (owner-pinned). A whitelisted token is **never** the subject of an approval and a whitelisted address is **never** a spender. Zero data path. **VERIFIED: no newly reachable state.**

**(c) The nudge pots — this is where the change lands.**

The whitelist *is* the pot definition, so removing an admin check on the whitelist directly widens what a pot can be. Remaining checks between an owner-supplied address and a payout:

| Layer | Check | Site |
|---|---|---|
| Admin — add | `msg.sender == owner()` | `onlyOwner`, `:328` |
| Admin — add | `token != address(0)` | `:330` |
| Admin — add | `_nudgeTokenIndex[token] == 0` (no duplicate) | `:331` |
| Admin — add | ~~payment-token identity~~ | **DELETED** |
| Admin — add | ~~minter/dispatcher configured~~ | **DELETED** (side effect) |
| Runtime | `!paused()` | `:466` |
| Runtime | `minRewards.length == _nudgeTokens.length` | `:473` |
| Runtime | minter + dispatcher configured, dispatcher non-zero | `:479` → `:739-747` |
| Runtime | `nudgeSize != 0 && count >= nudgeSize` | `:513` |
| Runtime | `balanceOf(this) >= minRewards[i]` | `:803` |
| Runtime | `nonReentrant` | `:467` |
| Runtime | payout is the pre-loop snapshot, skipped if `0` | `:801`, `:831` |

That is the complete list. There is **no ERC20-ness check, no contract check, no decimals check, and no payment-token check** at either admin or runtime.

### 3.3 Previously-guarded states now reachable — plainly

1. **`paymentToken ∈ _nudgeTokens` in a single owner call.** Previously required a two-step manoeuvre (whitelist X, then repoint `tokenMinter`/`dispatcherIndex` so X becomes the prime token). Now one call. **Owner-permitted by the 2026-07-25 decision; the arbitrage is accepted.** Mechanics: the payment token's pot is snapshotted pre-pull (`:801`, uncontaminated `P`), floor-checked, refund is budget-sourced, payout is `P`. Solvent and correct — the pot cannot leave via the refund for any `count`, `nudgeSize`, or dispatcher index. **No defect; recorded for completeness only.**

2. **A token can be whitelisted while `tokenMinter == address(0)` and/or `dispatcherIndex == 0`.** Previously `BatchMint__MinterNotConfigured` / `BatchMint__DispatcherNotConfigured`. The commit message names this as an intended side effect ("symmetric with the remove branch"). This is the genuinely *new* reachable state, and it has a downstream consequence the commit message does not trace:

   > `NudgeStreamer.registerStream` gates solely on `IMultiTokenNudgeWhitelist(batchMinter).isNudgeToken(token)` (`NudgeStreamer.sol:127`). With the whitelist now writable before the payment path exists, a stream can be **registered and then funded** via permissionless `collectNudge` against a batchMinter whose `batchMint` reverts `MinterNotConfigured` at `:479` — i.e. before step 3.5's flush can ever run. Donated funds sit in the streamer's buffer, and `NudgeStreamer` has **no rescue, no pause, and no deregistration** (ledger `4a1d8edc92`, open). Recovery requires completing the minter/dispatcher config and running a qualifying unpaused batch.

   This is a **deployment-ordering footgun**, not a fund loss: it is fully recoverable by finishing the configuration. But the check that made the bad ordering *impossible* is gone, and the commit message frames its removal purely as a convenience ("no longer an ordering constraint on deployment scripts") without noting that the constraint was also protecting the streamer-funding sequence. Under the repo's Law-3 test — *would a competent, non-malicious owner be surprised?* — **yes**: the runbook now permits an ordering whose consequence is donor funds parked in a contract with no escape hatch. Surfaced as an operational hazard; see §4.1.

3. **Pre-existing, not newly reachable, but worth stating**: the add branch never validated ERC20-ness, so whitelisting an EOA or a non-ERC20 contract has always bricked `batchMint` (the `balanceOf` at `:801` reverts on empty returndata) until the owner removes it. Unchanged by story-032; obvious owner error; not flagged.

### 3.4 Caller-supplied `rewardTokens` — **still NOT a vector. Re-confirmed, and structurally so.**

The prior assessment holds, and story-032 cannot have weakened it:

- `batchMint`'s only caller-supplied array is `uint256[] calldata minRewards` — **numbers, not addresses** (`:464`).
- The reward token set is read **exclusively** from storage `_nudgeTokens` at `:533`, `:800`, and `:832`. There is no calldata-sourced address anywhere in the reward path.
- `_nudgeTokens` is written **only** by `setNudgeTokenWhitelist`, which is `onlyOwner` (`:328`).
- story-032 removed a check on the **owner** path. A caller vector requires a **caller-controlled address**, and none exists. The removal is therefore incapable of reopening it.
- The only caller-controlled lever over the reward path is `count` (whether `qualifies` trips) and `minRewards[i]` (a revert threshold) — both true before story-025 removed the caller-selected model, both unchanged here.

**Conclusion: caller-supplied reward tokens remain structurally impossible. No re-litigation needed.**

---

## 4. Value flow map

`P` = standing pot (pre-existing whitelisted-token balances) · `A` = `paymentAmount` requested · `credited` = measured receipt of `A` · `C` = Σ prices charged · `D` = this batch's own dispatcher donations

| # | Flow | Debited | Credited | Order | Amount is… |
|---|---|---|---|---|---|
| V0 | Stream flush (per whitelisted token, if streamer set) | `NudgeStreamer` | **this contract** | step 3.5, `:533` — **first** | derived by the streamer; unmeasured here |
| V1 | Payment pull | `msg.sender` | this contract | step 5, `:581` | request `A`; **credit is a MEASURED delta capped at `A`** (`:582`, `:604`) |
| V2 | Per-mint charge (×`count`) | this contract (via allowance) | dispatcher/pool | step 6, `:650` | **STATED** — `configs().price` re-read per iteration (`:646`); `budget` debited *before* the call (`:649`) |
| V2b | Per-mint donation back (side effect of V2) | dispatcher | this contract | interleaved with V2 | unmeasured; accrues as `D`, invisible to `budget` and to `snapshot` |
| V3 | Refund | this contract | `msg.sender` | step 9, `:711` | **STATED** from the tracked counter — `min(budget, balanceOf)`; **suppressed entirely if `< 1e6` raw units** (`:710`) |
| V4 | Nudge payout (per whitelisted token) | this contract | `recipient` | step 10, `:833` — **last** | **STATED** from the step-4 pre-loop snapshot, deliberately stale (`:801`) |
| V5 | Rescue | this contract | owner-chosen `to` | any time, incl. paused | **STATED**, owner-supplied |
| — | NFT units (`count`) | minter | `recipient` | interleaved with V2 | **STATED** `count` |

**Measured vs stated summary**: exactly **one** measured quantity in the whole contract — the step-5 budget credit (V1). Everything else is stated. That asymmetry is intentional and is the core of the story-029 design: the *only* place a `balanceOf` difference is permitted is a bracket around a single transfer; every absolute `balanceOf` reading (`:708`, `:801`) is used either as a defensive cap or as a deliberately-stale snapshot, never as an entitlement.

**Ordering summary**: `V0 → snapshot(P) → V1 → (V2 ‖ V2b)×count → revoke → V3 → V4`. The two registry-named constraints are `snapshot(P)` before `V1`, and `V3` before `V4`. Both hold (§1.2).

---

## 5. Local findings

### 5.1 LOCAL-BM-01 — story-032 removes the precondition that made "fund the streamer before wiring the minter" impossible

- **Type**: owner/deployment-ordering footgun (operational hazard), Law-3 in-scope
- **Severity**: local-low
- **Sites**: `:328-335` (gate removed), `NudgeStreamer.sol:127` (the only registration gate), `:479` (where `batchMint` now reverts instead), `:532-534` (the flush that never runs)

See §3.3 item 2 for the full chain. Net effect: an owner following the now-permitted ordering can end up with permissionless donor funds in a `NudgeStreamer` buffer that no `batchMint` will ever flush, held by a contract with no rescue and no deregistration. Fully recoverable by completing configuration, so this is a runbook hazard rather than a loss.

- **Recommendation**: either keep a lightweight completeness assertion on the add branch (`tokenMinter != address(0) && dispatcherIndex != 0`) — which preserves the removed protection without reinstating the payment-token opinion story-032 deliberately dropped — or state the required ordering (configure minter + dispatcher → whitelist → register stream → fund) in the deployment runbook and the contract NatSpec.
- **Disclosure**: distinct from ledger `4a1d8edc92` (that finding is "the streamer has no rescue"; this one is "story-032 made a new route into needing one"). They compound; do not collapse.

### 5.2 Cross-contract handoff (do NOT adjudicate here)

The unguarded flush loop at `:532-534` — no `try/catch` — means any revert inside `NudgeStreamer.pullPendingStream` for any registered whitelisted token bricks `batchMint` for every caller. See `profiles/NudgeStreamer.md` §5.1 (`LOCAL-NS-01`) for the reachable route. Handoff to the interaction scanner.

### 5.3 Already-filed, re-confirmed present at `9611312` (do NOT re-file)

| Ledger | Status | Confirmed |
|---|---|---|
| `6b8faaf6dc` — swap-and-pop reorder vs positional `minRewards` | open | **Yes** (`:340-344`). story-032 marginally widens edit frequency. |
| `bfdb50105e` — `minRewards` floors pre-transfer balance; shrinking token reverts the batch | wont-fix | **Yes** (`:803`, `:833`). |
| `51aed27661` — decimals-blind `DUST_THRESHOLD`, misreported in NatSpec | merged | **Yes.** `:710` tests `refund / 1e6 != 0`; `:164-167` still claims "~10^-12 of a unit" **for an 18-decimal token only**. With a 6-dp prime token (USDC/phUSD-class, which `NFTStakerPriceScaled.sol:29` confirms is real) the forfeiture window is up to **0.999999 whole units per batch**, permanently, into the pot. |
| `38ea47b14c` — self-feeding pot from forfeited sub-threshold residue | wont-fix (low) | **Yes**, mechanism intact at `:713-715`. |
| `990d8c37b4` — `minReward == 0` silently opts out | wont-fix | **Yes** (`:803`, `0 < 0` false). |
| `43e8c48626` — aggregate multi-token pot can breach the snipe margin | wont-fix | **Yes.** story-032 does not change the aggregate; it makes building such a whitelist one call cheaper. |
| `2d34673536` — streamer flush leaked streamed buffer via the step-10 sweep under owner repoint | **fixed** | **Still fixed.** The runtime payment-token skip is gone and the sweep is budget-sourced; the flush at `:533` lands in a pot that is snapshotted pre-pull and refunded from a tracked counter. No regression. |

---

## 6. Could not verify from this contract

1. **Whether `mint()` charges exactly `configs().price`.** I read the *interface* (`ITokenMinterV2.mint` returns `bool`) but not `NFTMinterV2._executeMint`'s body — that lives in the `yield-claim-nft` sibling and is out of this profile's scope. The charge-then-ramp claim at `:631-636` is therefore **taken on the NatSpec's word**, not verified. If `mint` ever charged more than `configs().price`, the allowance at `:648` would cap it and the mint would revert (fails closed); if it charged less, the surplus would silently become pot. Handoff.
2. **That `mint()`'s ignored `bool` return is always paired with a revert on failure.** A minter returning `false` without reverting would let `batchMint` debit `budget` and mint nothing. The minter is owner-pinned and trusted, so this is an assumption, not a finding — but it is an unverified one.
3. **Live configuration**: actual `nudgeSize`, whitelist contents, `nudgeStreamer` address, and whether `paymentToken ∈ _nudgeTokens` on any deployed instance. Not in this repo by design; per prior-run notes, deploy records for this family have been unreliable and addresses should be resolved from chain.
4. **Whether the deployed frozen twin `BatchNFTMinter` and this contract share a `tokenMinter`/`dispatcherIndex`.** If they do, both draw on the same ramping price and the twin's `type(uint256).max` approval (`BatchNFTMinter:284`) coexists with this contract's exact-price discipline. Configuration question; handoff.
