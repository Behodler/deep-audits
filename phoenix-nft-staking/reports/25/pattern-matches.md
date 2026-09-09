# Pattern Matches — phoenix-nft-staking run-25 (story-029)

- **Target**: `lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol` @ `5015f1b`
- **Delta**: `d75229d..5015f1b`
- **Pattern DB**: `patterns/vulnerability-patterns.json` v1.1 — **35 patterns loaded, 35 checked, 0 skipped**
- **Scan type**: pattern-matching (Tier 1), delta-scoped
- **External context read**: `lib/phoenix-nft-staking/lib/mutable/yield-claim-nft/src/NFTMinterV2.sol` (`_executeMint`), ledger `reports/phoenix-nft-staking/ledger.json`

> Nothing below is suppressed for tidiness. Near-misses are reported with the specific reason the
> code escapes, because a thin escape margin is itself a finding (Law 1).

---

## Ranked pattern hits

### P-01 — BATCH-PAYOUT-FIXED-POT (recurrence of ledger `43e8c486` / `858e9e80`)
**Confidence: HIGH (as a recurrence); severity: potential-medium**
**Location**: `src/BatchNFTMinterMultiToken.sol:507-510` (gate), `:749-765` (`_snapshotRewards`), `:485` (removed skip)

The qualification gate is **unchanged and still value-blind**:

```solidity
qualifies = _nudgeSize != 0 && count >= _nudgeSize;   // L510
```

Story-029 did not touch the gate — it *widened what the gate can release*. The runtime
payment-token skip (`if (rewardToken == paymentToken) continue;`) was **deleted** from
`_snapshotRewards`, so when the owner repoints `tokenMinter`/`dispatcherIndex` such that the
derived `primeToken()` is also a whitelisted nudge token, that token's standing pot `P` is now
**snapshotted, floor-checked and paid out to a caller-chosen `recipient`** on a count-only gate.
Previously that pool was excluded from the payout entirely.

Why it matches `BATCH-PAYOUT-FIXED-POT`:
- `vulnerableWhen: full pot / contract balance paid out on a count-only gate` — yes, L510.
- `vulnerableWhen: payout recipient is caller-chosen` — yes, `recipient` is a `batchMint` param.
- `vulnerableWhen: payout not compared to the value the caller contributed` — yes; a batch of
  exactly `nudgeSize` at the minimum ramped price collects the whole accumulated `P`.
- Mitigation `pot snapshotted BEFORE the loop` **is** present (L535, pre-pull) and is what makes
  the *donate-forward* half correct — but it does not bound payout by contributed value.

**Recurrence status — REBIRTH ON NEW CODE, do not auto-suppress.** This is the same root class as
`43e8c48626ee` (M-01, *"multi-token whitelist aggregates the nudge-pot so a per-token-safe owner
funding can breach the snipe margin"*, **wont-fix**) and `858e9e807abe` (H-01, *"value-blind nudge
gate: full pot paid on count-only gate regardless of value paid"*, **wont-fix**). Per
`disclose-when-refiling-owner-wontfix`: story-029 adds a **new pool** (the payment token itself) to
the aggregate those two entries were triaged against, so the owner's prior risk arithmetic —
"Σ pots < 1 batch cost" — was computed over a strictly smaller set and no longer covers the
current code. It must be re-weighed by a human, not inherited. New fingerprint expected
(`_snapshotRewards` root cause changed); name both prior entries when filing.

Aggravating link: the payment-token pot is **self-feeding** via P-02 (every sub-dust refund
forfeiture lands in it), so it grows without any owner funding action at all.

---

### P-02 — FEE-ON-TRANSFER-ACCOUNTING / stranded-value: `DUST_THRESHOLD` is decimals-blind and all-or-nothing
**Confidence: HIGH (mechanism); severity: potential-medium**
**Location**: `src/BatchNFTMinterMultiToken.sol:146` (`DUST_THRESHOLD = 1e6`), `:660-668` (refund gate)

```solidity
uint256 internal constant DUST_THRESHOLD = 1e6;                    // L146
...
uint256 refund = budget > available ? available : budget;          // L661
if (refund / DUST_THRESHOLD != 0) { ... } else { totalPaid = paymentAmount; }   // L662-667
```

The payment token is **not fixed** — it is `ITokenDispatcherV2(dispatcher).primeToken()`
(`_resolvePaymentPath`, L705), owner-repointable. `DUST_THRESHOLD` is a raw wei constant with no
decimals normalisation:

| payment token decimals | value silently forfeited per batch |
|---|---|
| 18 (phUSD) | < 1e-12 token — genuinely dust |
| 6 (USDC-family) | **up to 0.999999 USDC — a full token** |

The gate is also **all-or-nothing, not partial**: a refund of 999,999 units is dropped *in its
entirety*, not partially paid. And the forfeited value does not stay neutral — it becomes part of
`P`, i.e. it is transferred to whoever wins the next qualifying batch (P-01). So on a 6-decimal
dispatcher this is a repeatable, caller-funded subsidy from every non-qualifying batcher to the
next qualifying one.

`totalPaid = paymentAmount` in the else-branch is arithmetically honest (the caller *did* part with
`paymentAmount`), so this is a value-routing issue, not a reporting bug.

**Owner-footgun framing (Law 3)**: a competent owner repointing `dispatcherIndex` at a 6-decimal
prime token would be *surprised* that per-batch refunds under one whole token vanish into the nudge
pot. Surprise ⇒ footgun ⇒ in scope. Safe-config guidance: scale `DUST_THRESHOLD` off
`IERC20Metadata(paymentToken).decimals()`, or lower it to a value that is dust at 6 decimals.

---

### P-03 — FEE-ON-TRANSFER-ACCOUNTING: the `min` is one-sided in **time**; the `available` cap is vacuous exactly where it is claimed to help
**Confidence: MEDIUM; severity: potential-medium (potential-low if the token set is provably static-balance)**
**Location**: `src/BatchNFTMinterMultiToken.sol:576-582` (measurement), `:658-661` (cap)

```solidity
uint256 heldBeforePull = paymentToken.balanceOf(address(this));
paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);
uint256 credited = paymentToken.balanceOf(address(this)) - heldBeforePull;
budget = credited < paymentAmount ? credited : paymentAmount;      // L581
...
uint256 available = paymentToken.balanceOf(address(this));         // L660
uint256 refund = budget > available ? available : budget;          // L661
```

The bracket at L577-579 correctly measures the **one inbound transfer**, and the prompt's question —
*"the `min` is one-sided, what about the OTHER side?"* — resolves as follows. The `min` is one-sided
in **direction** deliberately and correctly (it blocks a mid-pull donation being credited to the
batcher). It is also one-sided in **time**, and that is not deliberate: `budget` is pinned once at
L581 and is thereafter **never re-validated against the caller's actual remaining credit**. Any
mechanism that erodes this contract's payment-token holdings *after* L581 without going through
`budget -= price` leaves `budget` over-stating the caller's credit, and the difference is drawn out
of `P`.

Candidate mechanisms, ranked:
1. **Negative rebase** (rebasing payment token) between L581 and L660. `budget` is nominal; every
   pool shrinks; `refund = credited - C` now exceeds the caller's shrunk share; the balance to cover
   it is `P`. Requires an owner-configured rebasing `primeToken()`.
2. Any minter/dispatcher path debiting more than the quoted `price`. **Escapes** — see NM-01.

The load-bearing defect is the `available` cap. Its comment (L655-657) claims it is retained *"so an
unforeseen shortfall degrades into a smaller refund rather than a revert"*. It cannot do that:
`available` is an **absolute** `balanceOf` and therefore equals `P + (credited − C) + D`. It only
binds once the shortfall has already consumed `P` **and** `D` in full. In the exact scenario it is
retained for, it is non-binding — the shortfall is silently absorbed by the pot instead of degrading
the refund. The cap is not a weaker version of the right check; it is the wrong check, at the one
site the file elsewhere forbids absolute `balanceOf` reads (L599-608). A cap that actually did what
the comment claims would be a *caller-scoped* one, and no such quantity is tracked after L581.

This is the `ycn19h1` conflation returning through the refund's *ceiling* rather than its *source* —
the source fix is genuinely correct and this does not undo it, but the residual is the same pool
mixing the fix was written to eliminate.

---

### P-04 — REWARD-ACCRUAL-ORDER (ordering-dependency of the step-9/10 swap): **checked, escapes**, margin recorded
**Confidence: LOW as a finding; recorded for the margin. → `manualReview`**
**Location**: `src/BatchNFTMinterMultiToken.sol:658-679`

The prompt asks whether swapping refund (step 9) before `_payRewards` (step 10) opens a path where
the pot underfunds the payout. It does **not**, on any path I can construct:

- `snapshot` is captured at L535 **pre-pull**, so `snapshot[pt] = P` is uncontaminated.
- At the payout site the balance is `P + (credited − C) + D − refund`, and `refund ≤ budget ≤ credited`,
  so at least `P + D` remains. `_payRewards` needs `P`. Solvent by construction.
- The reverse order would have been the dangerous one (payout first could leave < refund owed).

**Margin**: the solvency proof consumes the *entire* slack of `refund ≤ credited`. If P-03's erosion
path is live, the refund overdraw comes out of `P` **before** `_payRewards` runs, so the payout leg
is what reverts (or under-pays). i.e. P-03 and the step-9/10 order interact: the swap converts
P-03's leak from a silent pot shrink into a **`batchMint` revert** once `P + D` is exhausted — a DoS
tail on the same root cause. Worth one line in any P-03 write-up; not separately reportable.

---

### P-05 — DOS-UNBOUNDED-LOOP: streamer flush loop
**Confidence: LOW; severity: potential-low. → `manualReview`**
**Location**: `src/BatchNFTMinterMultiToken.sol:521-528`

`pullPendingStream` is called once per whitelisted token, unconditionally, on **every** `batchMint`
— an external call per entry, with no length bound other than the owner's whitelist size. Mitigation
present: the array is owner-controlled (`notVulnerableWhen: array bounded`), so this is a Law-3
footgun rather than a permissionless DoS. Records as a gas/liveness ceiling on whitelist growth,
compounded by the second full-length pass in `_snapshotRewards` and a third in `_payRewards`.

---

## Near-misses (escape reasons stated; thin margins flagged)

### NM-01 — FEE-ON-TRANSFER on the **outbound** leg — ESCAPES, margin comfortable
The measurement brackets only the inbound pull; the per-mint outflow is quoted (`budget -= price`,
L625) not measured. I chased this as the obvious hole. It escapes: `NFTMinterV2._executeMint`
(yield-claim-nft `src/NFTMinterV2.sol:183`) does
`IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price)` — the batcher is debited
**exactly `price`** even under the standard fee-on-transfer model (the fee is skimmed from what the
*dispatcher receives*, measured there at L182-184). So `budget` and the actual outflow stay in
lockstep. Escape depends on the minter never debiting more than the quoted `price`; the minter is
owner-pinned and trusted, so this is sound today. Note it is a **cross-repo** invariant: a
yield-claim-nft change to `_executeMint`'s charge would silently break phoenix-nft-staking's budget
arithmetic with no local signal here.

### NM-02 — REENTRANCY-ERC721-RECEIVE / ERC1155 acceptance hook — ESCAPES, **THIN MARGIN**
`_executeMint` ends in `_mint(recipient, resolvedTokenId, 1, "")` (NFTMinterV2.sol:196). OZ ERC1155
`_mint` runs `_doSafeTransferAcceptanceCheck`, so a **caller-chosen `recipient`** contract's
`onERC1155Received` fires **inside** the `batchMint` loop (L621-627), i.e. between the pull and the
refund, with a live `forceApprove(minter, price)` standing.

Escapes for three independent reasons, all of which must hold:
1. `nonReentrant` (L464) blocks re-entering `batchMint`.
2. **CEI holds within the iteration** — `budget -= price` (L625) executes *before* `nftMinter.mint`
   (L626), so the hook cannot observe an un-decremented budget.
3. The standing allowance is exactly `price` and is only spendable by the minter charging
   *its own* `msg.sender`; a hook calling `NFTMinterV2.mint` becomes `msg.sender` itself and pays
   its own funds.

**Margin is thin on (2) and (3).** Moving `budget -= price` after the mint, or restoring any
approval wider than the single next charge, makes this live. This is precisely why the story-029
absolute-per-iteration approval is load-bearing and not a cosmetic tidy-up — record it as an
invariant to protect, not an incidental refactor.

### NM-03 — read-then-act TOCTOU on `configs()` — ESCAPES by design, but has a griefing tail
`config.price` is **global and ramps on every mint by anyone** (`_executeMint` L188). Between a
caller's off-chain quote and inclusion, third parties can ramp it. Escapes as a *correctness* issue
because the price is re-read every iteration (L622) immediately before the mint that charges it, and
`_executeMint` charges pre-ramp `config.price` — the read is exact, by construction, not by
convention. The residual is liveness: a front-runner's mints can push `price > budget` and revert
the whole batch via `BatchMint__PaymentBudgetExhausted`. **Not a regression** — pre-029 the same
shortfall also reverted (on allowance/balance), and pre-029 it could instead *silently spend the
contract's own balance*, which was ledger `ad36260f` (see below). Story-029 strictly improves this.

### NM-04 — approval-residue / non-decrementing-allowance tokens — ESCAPES cleanly
Every `forceApprove` (L624, L631) sets an **absolute** target. Idempotent for decrementing tokens,
corrective for non-decrementing ones; L631 zeroes unconditionally. Correctness is independent of the
token's allowance semantics. No `FRONTRUN-APPROVE` exposure either — this contract is the approver,
not a user, and the approve→spend window is atomic within one transaction.

### NM-05 — `INCORRECT-OPERATOR` on the two new boundaries — ESCAPES
`if (price > budget) revert` (L623) correctly admits `price == budget`.
`if (refund / DUST_THRESHOLD != 0)` (L662) is exactly `refund >= 1e6`. Both boundaries are
semantically right; the *magnitude* of the second is the issue (P-02), not its operator.

### NM-06 — `totalPaid` floor-guard removal — ESCAPES, **THIN MARGIN**, coupling undocumented
`totalPaid = paymentAmount - refund` (L664) lost its `paymentAmount > refund ? ... : 0` guard. It
cannot underflow, because `refund ≤ budget ≤ paymentAmount` — but that holds **solely** because of
the `min` at L581. The L560-570 comment justifies that `min` as a *donation-routing* defence and
mentions underflow only in passing. The `min` is now a **single point of failure for two unrelated
properties**. A future author reasoning only about donations could weaken it (e.g. to a floor) and
reintroduce an underflow-revert DoS at L664 with no local warning. Worth a QA note pinning the
second obligation at the `min` site.

### NM-07 — Linear-Depletion class — NOT APPLICABLE
Checked against `REWARD-RUNWAY-DEPLETION` / `EMISSION-WINDOW-BOUNDATION` signatures
(`rewardRate`, `windowEnd`, `lastRewardTime`, `elapsed`, `accPhusdPerShare`, `rewardDebt`,
`_updatePool`, `_recomputeSchedule`). **Zero hits** in `BatchNFTMinterMultiToken.sol` — this
contract holds no accumulator, no time-based accrual and no emission schedule. The pot is a plain
balance. The project's historical Linear-Depletion family lives in `NFTStakerDepletion*.sol`, which
story-029 does not touch. Checked-with-no-match, not an error.

### NM-08 — REENTRANCY-ERC777 / CROSS-FUNCTION / READONLY — ESCAPE
`_payRewards` transfers to a caller-chosen `recipient` after the refund, so a hooked nudge token
fires a callback — but `nonReentrant` still holds at that point, all state is settled, and the
contract exposes no value-reporting view for a read-only-reentrancy integrator to price against.
Sibling functions reachable during any callback (`setNudgeTokenWhitelist`, `rescueERC20`,
`setNudgeSize`) are all `onlyOwner`. No shared mutable state outside `batchMint`.

---

## Ledger reconciliation

| fingerprint | label | status | story-029 effect |
|---|---|---|---|
| `ad36260fc91f` | M-07 medium | **fix-pending** | **ADDRESSED — propose `fixed`.** The entry's root cause is *"`forceApprove(nftMinter, type(uint256).max)` lets an under-funded batch silently spend the contract's own payment[-token balance]"*. L624 now approves the **exact next price** only, L623 reverts `BatchMint__PaymentBudgetExhausted` before any over-spend, and L631 zeroes. The silent-overspend path is structurally gone. Human applies the status per CLAUDE.md — do not auto-flip. |
| `43e8c48626ee` | M-01 medium | wont-fix | **RECURRENCE — see P-01.** Prior triage was computed over a strictly smaller pot set; story-029 adds the payment token to the aggregate. Re-weigh; do not inherit the wont-fix. |
| `858e9e807abe` | H-01 high | wont-fix | **RECURRENCE — see P-01.** The value-blind count-only gate (L510) is untouched and now releases one more pool. Same disclosure obligation. |
| `1c222d548523` | H-01 high | fix-pending | **NOT IMPLICATED.** Root cause is `NFTStakerDepletion.depositFor` paying the migrator; different contract, untouched by story-029. |

---

## Coverage / errors

- `patternsChecked`: **35** (full v1.1 DB) · `patternsSkipped`: **[]** — no pattern carried a
  `note` marking it C4 QA/known-issue *and* matched, so nothing was routed out. `FRONTRUN-APPROVE`
  matched on signature but is a genuine non-match on the merits (NM-04), not a skip.
- `errors`: none. All targeted files readable; the nested `NFTMinterV2.sol` cross-repo read
  succeeded, so NM-01's escape is evidence-backed rather than assumed.
- Delta-scoped by instruction. Sibling `src/BatchNFTMinter.sol` (the V1 that still uses
  `type(uint256).max` approval and a `balanceOf` sweep, L284/L305) was **not** rescanned here; it is
  the pre-029 shape and is presumed covered by the existing `ad36260f`/`858e9e80` entries. Flagging
  as a **fork-drift watch-note** consistent with this project's existing fork-drift tracking: V1 did
  not receive the story-029 fix.
