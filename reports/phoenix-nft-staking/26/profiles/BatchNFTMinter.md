# Contract Profile — `src/BatchNFTMinter.sol` (interface-abstraction depth only)

- **Commit**: `9611312` · **UNCHANGED this range** (confirmed: `git diff 2ba764e 9611312 -- src/` and `git diff d2506c1 2ba764e -- src/` both show zero hunks in this file)
- **Solidity**: `^0.8.20` · **LOC**: 313 · **Inheritance**: `Ownable`, `Pausable`, `IPausable` — **note: NO `ReentrancyGuard`**
- **Status per its own header (`:14-19`)**: **DEPLOYED — FROZEN.** Kept only so the on-chain bytecode has matching source plus a regression suite.
- **Depth**: interface abstraction only — profiled as the direct counterpart/precedent for the changed multi-token sibling. Local properties are **not** re-derived; the deployed source is frozen and its findings history is already in the ledger.

---

## 1. Why it is in this profile set

It is **not** an on-chain counterparty of anything in this range: no import, no address field, no call site connects it to `BatchNFTMinterMultiToken` or `NudgeStreamer`. It matters for exactly one reason named by the story-032 commit message:

> its differently-named `BatchMint__NudgeTokenMatchesPaymentToken` runtime gate is still load-bearing and survives intact.

**VERIFIED — that gate is present and unmodified at `9611312`:**
```solidity
:260   address _nudgeTokenEntry = nudgePaymentToken;
:261   if (_nudgeTokenEntry != address(0) && _nudgeTokenEntry == address(paymentToken)) {
:262       revert BatchMint__NudgeTokenMatchesPaymentToken();
:263   }
```
It fires at **runtime, inside `batchMint`, before any funds move** (`:283` is the first transfer) — a different check at a different site from the admin-time `BatchMint__RewardTokenIsPaymentToken` that story-032 deleted from the sibling. Story-032 did **not** touch it, and it must not be confused with the deleted one during triage.

**Why the twin still needs it while the sibling does not** — and this is the load-bearing distinction:

| | `BatchNFTMinter` (frozen) | `BatchNFTMinterMultiToken` |
|---|---|---|
| Refund source | **absolute `balanceOf` sweep** (`:305`) | tracked `budget` counter |
| Refund amount | `remaining = paymentToken.balanceOf(this)` — i.e. `P + (A−C) + D` | `min(budget, balanceOf)` |
| Payment/nudge collision | **must be forbidden** — the sweep would hand the pot to any caller | safe; pot is unreachable from the refund |
| Payout vs refund order | payout `:301` **before** refund `:307` | refund `:711` **before** payout `:833` |

The twin is the `ycn19h1` shape: `:305`'s absolute read conflates the standing pot, the caller's unspent budget, and this batch's donations. Its `:261-263` gate is the **only** thing keeping the payment token out of that conflation. So the sibling's design fix (budget-sourced refund) and the twin's config gate are two different remedies for the same hazard, and removing the sibling's gate says nothing about the twin's. **Correct as the commit claims.**

Note the twin's payout-before-refund order is the **opposite** of the sibling's refund-before-payout. Both are safe *given their own refund source*, but the constraint is not transferable — do not "harmonise" them.

---

## 2. Interface abstraction

### 2.1 External entry points

| Function | Gate | `whenNotPaused` | `nonReentrant` | Writes |
|---|---|---|---|---|
| `batchMint(count, recipient, paymentAmount, minReward)` → `totalPaid` | none | ✅ | **✗ (none exists)** | none |
| `setTokenMinter` / `setDispatcherIndex` / `setNudgeSize` / `setNudgePaymentToken` / `setPauser` | `onlyOwner` | ✗ | ✗ | respective var |
| `rescueERC20(token, to, amount)` | `onlyOwner` | ✗ | ✗ | none |
| `pause()` / `unpause()` | `onlyPauser` | ✗ | ✗ | `_paused` |
| `tokenMinter`, `dispatcherIndex`, `nudgeSize`, `nudgePaymentToken`, `pauser` | public getters | — | — | — |

**Signature difference from the sibling**: `minReward` is a **single `uint256`**, not `uint256[] calldata` — a single nudge token, so no positional-array alignment hazard and no `ArrayLengthMismatch`. The sibling's swap-and-pop reorder finding (`6b8faaf6dc`) has no analogue here.

**`batchMint` writes no storage** (same as the sibling), and there is **no `ReentrancyGuard`**. Safe only because every external call goes to either the trusted pinned minter or a single owner-set `nudgePaymentToken`, and there is no persistent state to corrupt. A hostile `nudgePaymentToken` could reenter `batchMint`, but each nested call independently snapshots and pays out, bounded by the actual balance — it degrades to "the pot is paid to whoever qualifies", which is already the accepted design. Recorded as an observation about frozen code, not a finding.

### 2.2 What it assumes of each callee

| Callee | Methods | Trust | Assumptions |
|---|---|---|---|
| `tokenMinter` (owner-pinned) | `configs(index)`, `mint(index, recipient)` | trusted | `bool` return **ignored**. Granted `type(uint256).max` allowance for the whole loop (`:284`) — no per-mint price re-read, no exact-price discipline. This is the concrete behavioural difference the sibling was built to remove. |
| `dispatcher` (derived) | `primeToken()` | trusted | used directly, no zero/contract check (`:258`) |
| `paymentToken` (derived) | `balanceOf`, `transferFrom`, `approve`, `transfer` | semi-trusted | `SafeERC20`/`forceApprove`. **Fee-on-transfer NOT handled** — `paymentAmount` is trusted as a quote (`:283`), which is exactly why `:308` needs its `paymentAmount > remaining ? … : 0` floor guard that the sibling deliberately removed. Decimals not normalised (`DUST_THRESHOLD == 1e6`). |
| `nudgePaymentToken` (owner-set) | `balanceOf`, `transfer` | semi-trusted | no ERC20-ness or contract validation; must differ from `paymentToken` (`:261`) |
| `recipient`, `msg.sender` | — | untrusted, credit-only | never `.call`ed; `recipient != address(0)` (`:245`) |

**No `NudgeStreamer` integration** — no `nudgeStreamer` field, no `INudgeStreamer` import, no `pullPendingStream` call. The streamer is a multi-token-only feature. VERIFIED by grep.

### 2.3 What a caller may assume

- Atomic `count` mints to `recipient`, or full revert.
- Nudge is a **single** token, paid as the full pre-loop balance when `nudgeSize != 0 && count >= nudgeSize && nudgePaymentToken != 0`.
- Refund is a **balance sweep**, not a budget refund: dispatcher-side dust and third-party donations of the payment token **do** flow to `msg.sender` (documented at `:48-53`). This is intended behaviour for this contract.
- Sub-`1e6`-raw-unit residue is retained (same decimals-blind constant as the sibling).
- Nudge is paid **before** the refund sweep, and the `minReward` floor is checked **after** the mint loop (`:296`) — so a front-run caller pays gas for `count` mints before reverting, unlike the sibling which floor-checks pre-pull at `:803`.

---

## 3. Value flow map

| # | Flow | Debited | Credited | Order | Amount is… |
|---|---|---|---|---|---|
| T1 | Payment pull | `msg.sender` | this contract | `:283` — first | **STATED** `paymentAmount`, unmeasured (no FoT handling) |
| T2 | Blanket approval | — | — | `:284` | `type(uint256).max` |
| T3 | Per-mint charge ×`count` | this contract (allowance) | dispatcher/pool | `:287` | **STATED** by the minter; this contract tracks nothing |
| T3b | Per-mint nudge-token donation | dispatcher | this contract | interleaved | unmeasured; accrues after the `:280` snapshot |
| T4 | Revoke | — | — | `:290` | `0`, absolute |
| T5 | Nudge payout | this contract | `recipient` | `:301` — **before** refund | **STATED** from the pre-loop snapshot at `:280` |
| T6 | Refund sweep | this contract | `msg.sender` | `:307` — last | **absolute `balanceOf`** at `:305` — a *measured balance*, not a tracked amount; sweeps pot + unspent + donations of the payment token |
| T7 | Rescue | this contract | owner-chosen | any time | **STATED** |

**Contrast with the sibling** (the whole point of the multi-token rewrite): the twin has **zero** internally-tracked payment quantities. `paymentAmount` is a trusted quote and the refund is an absolute reading. The sibling replaced both — measured credit in, tracked counter out.

**Shared with the sibling, and intact in both**: the *donate-forward* mechanic. The nudge balance is snapshotted **before** the mint loop (`:280`) and paid **after** it (`:301`), so a batcher receives only the prior pot and its own batch's donations seed the next claimant. Same property, same rationale, independently implemented.

---

## 4. Findings posture

**None filed against this contract from this profile.** It is frozen deployed source, unchanged this range, and its history is already in the ledger. Two properties recorded for triage reference only:

1. `BatchMint__NudgeTokenMatchesPaymentToken` (`:261-263`) is **intact and still load-bearing**. It is a *runtime* gate on the *twin*, and it is **not** the check story-032 deleted (that was the *admin-time* `BatchMint__RewardTokenIsPaymentToken` on the *sibling*). If a scanner flags the sibling's removal, it must not also flag or "restore" this one, and it must not report this one as surviving dead code.
2. `DUST_THRESHOLD == 1e6` is decimals-blind here too (`:70`, `:306`), with the same NatSpec misstatement (`:67-69` claims "~10^-12 of a unit", true only at 18 decimals). Ledger `51aed27661` (merged) covers the class. Frozen source ⇒ not actionable here.

---

## 5. Could not verify

1. Whether the deployed twin and the multi-token sibling share a `tokenMinter` / `dispatcherIndex`. If they do, both mint against the same ramping price curve and the twin's `type(uint256).max` standing approval coexists with the sibling's exact-price discipline on the same token. **Configuration question, resolvable only from chain state** — and per prior-run notes for this family, deploy records have been unreliable and addresses should be resolved from chain, not from `mainnet-addresses` files.
2. Whether the twin is currently configured with a `nudgePaymentToken` at all (`address(0)` disables the whole feature and makes `:261-263` vacuous). Chain state.
3. `NFTMinterV2._executeMint`'s actual charge behaviour — interface read, implementation not (lives in `yield-claim-nft`).
