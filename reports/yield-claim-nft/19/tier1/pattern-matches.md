# Pattern Matches — yield-claim-nft run-19

**Commit:** `d4cc563` (stories 046 / 047)
**Pattern DB:** `patterns/vulnerability-patterns.json` v1.1 — **35 patterns checked**, 1 skipped (routed, not dropped)
**Scope:** the four donor dispatchers changed by stories 046/047
**Tier:** 1 (deterministic pattern matching) — *severity is NOT classified here; the `potential-*` labels are the DB's own severity mapping.*

The change under review: all four dispatchers replaced a leaf `safeTransfer(sink, amount)` with
`forceApprove(streamer, exactAmount)` + `INudgeStreamer(streamer).collectNudge(sink, token, amount)`.

`lib/phoenix-nft-staking/src/NudgeStreamer.sol` and `BatchNFTMinterMultiToken.sol` are nested
third-party deps and are **not** first-party findings targets. They were read to fix the semantics
the first-party dispatchers now depend on; matches rooted there are filed against the **first-party
caller** that relies on the behaviour.

---

## Findings (medium/high confidence) — ranked

| # | Pattern | Location | Confidence |
|---|---------|----------|------------|
| PATTERN-001 | `REWARD-RUNWAY-DEPLETION` — caller-side rate-drift | `NudgeRatchet.sol:160` (+ 3 siblings) | **high** |
| PATTERN-002 | `CENTRALIZATION-ADMIN` → owner footgun: stranded value on re-key | `Uniboost.sol:250` (+ 3 siblings) | **high** |
| PATTERN-003 | Two-pointer divergence (uninitialized critical pointer, silent variant) | `NudgeRatchet.sol:157` (+ 3 siblings) | **high** |
| PATTERN-004 | `DOS-EXTERNAL-DEPENDENCY` — mint liveness coupled to unenforced config | `NudgeRatchet.sol:156` | **high** |
| PATTERN-005 | `BATCH-PAYOUT-FIXED-POT` — assumed mitigation is not a mitigation | `BalancerPoolerV2.sol:37` (+ 3) | medium |
| PATTERN-006 | `MINT-ON-DEMAND-OVERMINT` (adjacent) — widened catch vs gross-amount debt | `BalancerPoolerV2.sol:290` | medium |
| PATTERN-007 | Silent-skip branch replaced a revert **and lost its event** | `BalancerPoolerV2.sol:329` | **high** |
| PATTERN-008 | Live-read of mutable external config (`psm.gem()`) | `BalancerPoolerV2.sol:345` | medium |

### PATTERN-001 — caller-side rate-drift (the question the brief asked)

`NudgeStreamer.collectNudge` recomputes `s.rewardPerSecond = s.buffer * 1e18 / s.duration`
(`NudgeStreamer.sol:153`) on **every** deposit, re-stretching the **whole residual buffer** over a
**fresh full duration**.

The phlimbo `_updatePool` port is internally faithful — phoenix-nft-staking run-24's conclusion
holds and is re-confirmed against source (see `REWARD-ACCRUAL-ORDER` below). **The drift is
introduced caller-side.** All four dispatchers call `collectNudge` on every dispatch, i.e. **once
per NFT mint** — precisely the pathological cadence for a reset-on-deposit rate.

With donations of size `d` arriving every `dt << duration`, the released fraction per interval is
`buffer * dt / duration`, so the buffer converges to a steady state of `d * duration / dt` instead
of draining. Concretely: `duration` = 7 days with one mint per hour ⇒ **~168 donations' worth of
USDC permanently resident in the streamer**. Compounding this, PATTERN-002 establishes that
resident balance has no recovery path.

### PATTERN-002 — stranded value, no rescue

Value routed into the streamer is addressable **only** as `buffer[(recipient, token)]` and drainable
**only** by that exact recipient calling `pullPendingStream`. Verified exhaustively against
`NudgeStreamer.sol`'s function list: `registerStream`, `collectNudge`, `pullPendingStream`,
`pendingStream` — **no owner rescue or sweep exists**.

An owner calling `Uniboost.setRecipient` (or `setBatchMinter` on the other three) after donations
have accumulated **permanently orphans the old pair's buffer**. The dispatchers' `rescueERC20`
cannot reach it (the value has left the dispatcher), and `NudgeRatchet` has no `rescueERC20` at all.

A competent, non-malicious owner would be surprised that a routine recipient re-point strands funds
⇒ **footgun, in scope** (Law 3).

### PATTERN-003 — two independent pointers that must agree

The dispatcher's `nudgeStreamer` and `BatchNFTMinterMultiToken`'s **own** `nudgeStreamer` are
independently set and must agree. The dispatcher side enforces only `!= address(0)` on itself. The
recipient side is a **silent no-op**:

```solidity
// BatchNFTMinterMultiToken.sol:446
address _nudgeStreamer = nudgeStreamer;
if (_nudgeStreamer != address(0)) { /* ... pullPendingStream loop ... */ }
```

If the batchMinter's pointer is unset or points at a *different* streamer, every donation still
succeeds and accumulates — but is **never flushed into the nudge pot**. No revert, no event
anywhere in the system indicates the divergence.

### PATTERN-004 — NudgeRatchet is the odd one out

The only one of the four with **no disable switch and no try/catch**. `batchMinter` cannot be zeroed
(constructor *and* `setBatchMinter` both require non-zero), there is no `donationSplit`, and
`bal >= amount` is already required — so **any non-zero balance forces the streamer path
unconditionally**.

`nudgeStreamer == 0`, an unregistered `(batchMinter, token)` pair, or *any* revert inside
`collectNudge` (including `NudgeStreamer._settle`'s outbound USDC transfer to the batchMinter — e.g.
a USDC blacklist) reverts `dispatch`, which reverts `NFTMinterV2.mint`: **the whole mint bricks**,
not just the donation. The removed `safeTransfer` made the deploy-to-wire window unreachable; it is
now a live brick window.

The NatSpec pre-declares this "NOT an audit finding". Recorded anyway per Law 1 — the reasoning
tiers adjudicate, the pattern tier does not auto-suppress on an author's say-so.

### PATTERN-005 — the streamer is a timing throttle, not a value cap

All four dispatchers' NatSpec frames the streamer as the batch-minter being "paid over time rather
than in a lump". Verified: true of the arrival **rate** only. It puts **no ceiling** on what a single
`batchMint` can capture — the batchMinter flushes via `pullPendingStream` at step 3.5 and then
snapshots its **whole balance**, winner-take-all. Given time to accrue, one caller still takes the
entire amount in one transaction.

Flagged so the mitigation is not **miscredited**: any reasoning that treats this hop as an
anti-over-funding *value* cap — cf. phoenix-nft-staking run-22 aggregate-nudge over-funding — is
unsupported by the implementation (`isItAValueCap: false`).

### PATTERN-006 — widened catch vs gross-amount debt

The `try this._psmDonate{} catch` region grew from PSM-only to **PSM + streamer wiring + the
streamer's own outbound settle transfer**. Newly swallowed: `"nudgeStreamer unset"`,
`NudgeStreamer__NotRegistered()`, any failure inside `_settle`'s outbound transfer
(`NudgeStreamer.sol:187`), and a non-conforming/EOA streamer.

Meanwhile `hook.onDispatch` fires with the **gross** amount (`ATokenDispatcherV2.sol:125`) regardless
of donation outcome — mint-debt accrues even when the donation silently skips. Value is not lost
(the next dispatch re-sweeps), but the quiet-outage window is materially wider, and every distinct
failure cause collapses into one undifferentiated `DonationSkipped`.

### PATTERN-007 — the dust branch lost its event

Confirmed in diff:

```solidity
- require(gemAmt > 0, "BalancerPoolerV2: donation dust");
+ if (gemAmt > 0) {
```

The guard is **load-bearing and correct** (it keeps `NudgeStreamer__ZeroAmount()` out of the catch).
But the observability regression is real: previously the dust case reverted into the catch and
emitted `DonationSkipped`; now `_psmDonate` returns successfully and emits **nothing**. The
contract's own NatSpec still tells operators to "watch `DonationSkipped` and the contract's USDS
balance" — which no longer covers this branch.

Same event-silent shape exists natively (not as a delta) at `Uniboost.sol:246` and
`PromotionUniV2_Eth.sol:392`.

### PATTERN-008 — `psm.gem()` read live

`address gem = ISkyPSM(psm).gem();` (`:345`) is read on every call, and `psm` is owner-settable. A
`setPSM` re-point to a PSM with a different gem silently changes the token identity handed to
`collectNudge` ⇒ unregistered pair ⇒ `NotRegistered` ⇒ swallowed ⇒ USDS parks indefinitely behind
one `DonationSkipped`.

Note the asymmetry: `PromotionUniV2_Eth` pins USDC as a `constant` and `NudgeRatchet` pins an
immutable 6-dp token — neither can drift. **BalancerPoolerV2 is the sole live-read.**

---

## Manual review (low confidence — routed, not dropped)

| # | Pattern | Location | Why it's low, why it's kept |
|---|---------|----------|------------------------------|
| PATTERN-M01 | `FRONTRUN-APPROVE` → residual allowance | `BalancerPoolerV2.sol:346` + 3 siblings | Skipped as primary per its `note`; kept for the twist below |
| PATTERN-M02 | `REENTRANCY-ERC777` | `Uniboost.sol:250` | Defended today; rests on a deployment policy |
| PATTERN-M03 | `FEE-ON-TRANSFER-ACCOUNTING` | `Uniboost.sol:250` | FoT is invalid here, but the cross-stream twist is a different claim |
| PATTERN-M04 | `DIVISION-PRECISION` | `BalancerPoolerV2.sol:330` | Intended and protocol-favouring; adjudicated, not silent |
| PATTERN-M05 | `SELFDESTRUCT-FORCE-ETH` | `PromotionUniV2_Eth.sol:509`,`:589` | run-17 L-13 carryover — reconcile, don't re-file |

**PATTERN-M01 (residual allowance).** All four `forceApprove(streamer, exactAmount)` and **never
reset to zero**. In `BalancerPoolerV2` this is directly asymmetric with the PSM allowance eleven
lines earlier, which *is* zeroed (`:336`). Every other `forceApprove` in these contracts
(`Uniboost:275/279, 300/306`; `PromoEth:466/472, 483/485, 503/507`) is paired with a zeroing reset —
**the streamer approve is the sole unpaired one.** Mitigation verified: `collectNudge:149` pulls
exactly `amount`, so with the canonical streamer the residual is provably zero and any failure rolls
back atomically. The exposure is conditional on `nudgeStreamer` being re-pointed (owner-settable,
semi-trusted, **cross-repo**) to an under-pulling implementation. Low confidence that it is
exploitable today — kept because the safe-today property rests entirely on an *external* contract's
implementation detail rather than on any local invariant.

**PATTERN-M02 (reentrancy).** `collectNudge` fires an **outbound** transfer to the batchMinter inside
`_settle` (`:187`) **before** pulling the donor's tokens (`:149`) — a hook-bearing token gets control
mid-collect, inside the dispatcher's own `dispatch`. Defences verified: `dispatch` is contract-wide
`nonReentrant` (OZ guard — so `pool` shares the lock and `REENTRANCY-CROSS-FUNCTION` does not apply),
`collectNudge`/`pullPendingStream` are themselves `nonReentrant`, and `_settle` is CEI-correct.
Token restriction holds for three of four (NudgeRatchet 6-dp require, PromoEth `constant` USDC,
BalancerPoolerV2's PSM gem). **Uniboost is the exception** — `_primeToken` is an unrestricted
constructor arg with no allowlist or decimal guard.

**PATTERN-M03 (FoT cross-stream twist).** `collectNudge` credits `s.buffer += amount` without a
balance-delta measurement. Generic FoT is C4-invalid and permanently invalid on this project family
— but the streamer holds **all streams in one token balance**, and its claimed solvency invariant
(`sum(buffers) == held balance`) is justified *precisely* by "every buffer is only credited by an
actual transferFrom of that same amount". One FoT/rebasing token admitted through Uniboost's
unrestricted prime breaks that invariant, so `_settle` for one stream could draw down **another
stream's backing**. Cross-stream contamination ≠ ordinary FoT under-crediting, hence routed rather
than auto-suppressed.

---

## Skipped patterns

| Pattern | Reason | Disposition |
|---------|--------|-------------|
| `FRONTRUN-APPROVE` | `note` marks it C4 QA/known-issue ⇒ not emitted as a primary finding | **Matched with a plausible twist** ⇒ routed to `manualReview` as PATTERN-M01. Not discarded. |

---

## Historical re-fire checks

| Class | Result | Evidence |
|-------|--------|----------|
| **M-04 unwired-hook zero-debt** | **CLEAN** — does not re-fire | `NudgeRatchet.sol:137` still enforces `hookTypeId() == keccak256("NudgeRatchetMintDebtHook.v1")`, so a missing/wrong hook is a **loud revert**, not silent zero-debt. Unchanged by story-046. PATTERN-006 is adjacent but distinct: there the hook *is* wired and debt *does* accrue — the gap is on the delivered-value side. |
| **M-03 decimal under-mint** | **CLEAN** — no new conversion | All four pass the amount **verbatim** to `collectNudge`; no `decimals()` read on the streamer path. `PRECISION = 1e18` cancels (`rate = buf*1e18/dur`, `accrued = rate*elapsed/1e18`); native units preserved. For a 1 USDC buffer, `rewardPerSecond = 1e24/duration` — truncation needs `duration > 1e24` s. |
| **L-09 / L-10 hook-scale** | **CLEAN in range** | `hook.onDispatch` still fires with the gross `amount` (`ATokenDispatcherV2.sol:125`), unchanged. No new hook-side scaling. |
| **run-17 L-13 ETH sweep** | **PRESENT, UNCHANGED** | `PromotionUniV2_Eth.sol:509` + `:589`, outside the diff. Surfaced only because the contract is new-in-scope. Routed as PATTERN-M05 — reconcile against the existing ledger entry. |

---

## Patterns checked with no match (21)

`ERC4626-INFLATION` (consumer of `sUSDS.deposit`, issues no shares) · `ORACLE-STALE` /
`ORACLE-ROUNDID` (zero `latestRoundData` hits) · `SIGNATURE-REPLAY` (zero `ecrecover` hits) ·
`FLASH-LOAN-PRICE` (balance sweeps present but no spot price derived; a third-party top-up only
increases the donation at their own expense) · `UNSAFE-DOWNCAST` (zero hits; all arithmetic
`uint256`) · `UNPROTECTED-INIT` / `STORAGE-COLLISION` (constructor-only, non-upgradeable) ·
`MISSING-SLIPPAGE` (swap sites in `pool()`, outside the diff; `require(liquidity >= minLP)` intact) ·
`RETURN-VALUE-IGNORE` (SafeERC20 throughout) · `DOS-UNBOUNDED-LOOP` (no loops on changed paths) ·
`DOUBLE-VOTING` · `PERMIT-FRONTRUN` · `FIRST-DEPOSITOR-ATTACK` · `INCORRECT-OPERATOR` (each boundary
reviewed individually; no off-by-one — the `require`→`if` change is filed as PATTERN-007) ·
`CROSS-CHAIN-REPLAY` · `TIMELOCK-BYPASS` · `EMISSION-WINDOW-BOUNDARY` (subsumed by PATTERN-001) ·
`YIELD-PRINCIPAL-ACCOUNTING-SKEW` · `TWO-STEP-COMMIT-WINDOW` · `REENTRANCY-ERC721-RECEIVE` ·
`REENTRANCY-READONLY` · `REENTRANCY-CROSS-FUNCTION` · `WEAK-PRNG` · `CENTRALIZATION-ADMIN`
(generic admin risk suppressed per Law 3; the two non-obvious footguns promoted to PATTERN-002/008).

**Two negatives worth stating explicitly, because a silence here would be misread:**

- **`REWARD-ACCRUAL-ORDER` — regression anchor CLEAN.** `collectNudge:146` calls `_settle` at the
  **old** rate *before* the buffer mutation (`:150`) and *before* the rate recompute (`:153`);
  `registerStream` does the same. `notVulnerableWhen` ("rate setters settle at the OLD rate before
  mutating the rate") is satisfied. run-24's "port is faithful" holds against source.
- **`ROUNDING-DIRECTION` — standing watch adjudicated CLEAN.** Every rounding decision on the changed
  paths floors *against* the recipient: `gemAmt` floors (never over-credits), `donationAmount =
  amount*split/100` floors (donates less), `_accrued` floors and caps at `buffer`. No two-leg
  asymmetry and no profitable round-trip — these are one-way donors with no redemption leg.

---

## Coverage

- All four contracts read in full and cross-checked against their profiles and against
  `git diff ef5fd64~2..d4cc563`. **No unreadable files; `errors[]` is empty.**
- Every negative signature claim comes from an **untruncated** grep over the complete file set —
  no `| head` truncation was used to support any absence claim.
- `PromotionUniV2_Eth.sol` was **absent from the cached `scope` array** and was scanned anyway under
  the default-in-scope denylist policy.
