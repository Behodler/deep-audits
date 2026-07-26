# QA Report — phoenix-nft-staking

> ## ⚠ SUPERSEDED IN PART — M-01 AND M-02 WITHDRAWN (2026-07-26)
>
> **Run-25 `M-01` (`pns25m1` / `DEDUP-25-01` / ledger `96823199d298…`) and `M-02` (`pns25m2` /
> `DEDUP-25-02` / ledger `c7a410602b29…`) were WITHDRAWN by owner correction on 2026-07-26 and are
> now ledger status `false-positive`.** Every reference below that treats M-01 or M-02 as a live
> Medium — including cross-references, re-weigh recommendations, KI-scope determinations and
> "value is priced in M-01" pointers — is **superseded**. See `submissions/M-01.md` for the full
> reasoning.
>
> **In one line:** the nudge pot is funded by *externally-derived yield on protocol-owned capital*,
> never principal and never user deposits, so a pot exceeding one qualifying batch's cost is an
> accepted **subsidy rate / marketing spend** (opportunity cost), not a value leak. `NudgeStreamer`
> meters release so the market finds a clearing price; empirically the pot has never once reached
> 50 % of the qualifying cost before someone minted. Recorded as `registered-projects.json` **KI #16**.
>
> **Still reportable (Law 1 — narrow suppression):** (a) the pot leaving without `nudgeSize` real
> mints paid; (b) `refund > paymentAmount`; (c) a non-qualifying batch extracting pot-sized value;
> (d) **a claimant taking other users' money** — which is why **M-03 survives** (forfeited sub-dust
> residue is other callers' money), re-weigh to **Low** *proposed*, not applied.
>
> **Run-25's reading of KI #15 carve-out (d) was too broad** — (d) covers *accidental* over-funding,
> not a deliberately-set subsidy rate. Every MR-05 / "re-weigh" / "acceptance-scope drift"
> recommendation below that rests on that reading is **withdrawn**.
>
> **Ledger entries `43e8c48626ee…` and `858e9e807abe…` are untouched** — run-25's re-weigh of them
> is **withdrawn**; their `wont-fix` rationale stands unchallenged. The **surviving accurate residue**
> of M-01 is the documentation mismatch already filed as **L-02** (`75305ec0…` / `a7dffb34…`), whose
> correct fix is to **restate the sentence as a subsidy policy, not to add a code bound** — and no
> value claim attaches to it.

---

- **Project**: `phoenix-nft-staking` @ [`5015f1b`](https://github.com/Behodler/phoenix-nft-staking/tree/5015f1b)
- **Run**: `phoenix-nft-staking-25` (regression of **story-029**, baseline `d75229d`)
- **Delta**: `git diff --stat d75229d..5015f1b` changes exactly one `src/` file — `src/BatchNFTMinterMultiToken.sol`

This is the single QA bundle for run-25. High/Medium findings are submitted separately
(`M-01.md`, `M-02.md`, `M-03.md`) — **but `M-01.md` and `M-02.md` were WITHDRAWN on 2026-07-26
(owner correction; ledger status `false-positive`) and must not be submitted. `M-03.md` survives,
with a re-weigh to Low *proposed* (not applied).** Faithfulness (Law-2) findings for this run are filed in the
spec-conformance report, not here. QA carried over from earlier audits lives under
`submissions/carryover/` and is deliberately not restated or renumbered into this sequence.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 2 |
| QA / hardening | 2 |
| Centralization | 0 |
| **Total** | **4** |

| Label | Title |
|---|---|
| [L-03](#L-03) | Budget/charge lockstep is a silent cross-repo invariant; a live `price` allowance stands across two callbacks |
| [L-04](#L-04) | Fork drift — V1 `BatchNFTMinter.sol` never received story-029 |
| [Q-01](#Q-01) | The `available` cap cannot do what its comment claims; non-binding on every constructible path |
| [Q-02](#Q-02) | The `:580` `min` is a single point of failure for two properties, only one documented |

### Label gaps — all intentional, nothing is renumbered

- **`L-01` is absent because it was MERGED INTO `M-03`.** L-01 ("Decimals-blind `DUST_THRESHOLD`;
  sub-dust refund forfeiture is un-refundable, pot-directed and misreported") shares file,
  function, root-cause class and fix with M-03 — their fingerprints collide under
  `sha256(contract:function:rootCauseClass)`. **See `M-03.md`**, which now carries L-01's two
  distinct claims (the decimals-blindness of `DUST_THRESHOLD` at `:146`, and the `totalPaid`
  misreport at `:666`) alongside the accretion consequence. M-03 is itself flagged for triage as
  borderline-Low, so a triager who disagrees with the Medium should re-rate the merged entry
  rather than re-splitting L-01 out of it.
- **`L-02` and `Q-03` are absent by design** — they are Law-2 faithfulness findings and belong to
  the spec-conformance report.

The remaining labels are not renumbered around any of these gaps.

---

## Low Risk Findings

<a name="L-03"></a>
### [L-03] Budget/charge lockstep is a silent cross-repo invariant; a live `price` allowance stands across two callbacks <!-- id: pns25l3 -->

**Location**: [`src/BatchNFTMinterMultiToken.sol#L621-L627`](https://github.com/Behodler/phoenix-nft-staking/blob/5015f1b/src/BatchNFTMinterMultiToken.sol#L621-L627)

**This is a watch-note, not a bug today.** It is filed so that the propose-`fixed` on ledger
entry `ad36260f…` (M-07, unbounded minter approval) is **not read as unconditional**.

**Description**

```solidity
paymentToken.forceApprove(address(nftMinter), price);   // :624
budget -= price;                                        // :625  quoted, never measured
nftMinter.mint(_dispatcherIndex, recipient);            // :626
```

The outflow leg is **quoted, not measured** — the deliberate inverse of the measured inbound
bracket at `:577-579`. Correctness therefore rests on a property of a *different repository*:
that `NFTMinterV2._executeMint` debits this contract exactly `config.price`, exactly once, per
`mint`. That was verified at source for this run (`yield-claim-nft/src/NFTMinterV2.sol:183` is
the sole `transferFrom` in the file) and it holds today. Nothing in phoenix-nft-staking asserts
it, and nothing here would notice if it stopped holding — `budget` would simply be wrong rather
than reverting.

The exposure is that `_executeMint` makes two external calls after the debit and before
returning: `dispatch(...)` on the configured dispatcher (`:191`) and `_mint(recipient, …)`
(`:196`), the latter firing `onERC1155Received` on a **caller-chosen recipient**. With a payment
token that does not decrement allowance on `transferFrom`, the `forceApprove(minter, price)`
written at `:624` is still standing during both callbacks.

**The escape holds today on three grounds, two of them thin:**

1. `nonReentrant` at `:464` blocks re-entering `batchMint`.
2. `budget -= price` at `:625` executes *before* the mint at `:626`, so a hook cannot observe an
   un-decremented budget — CEI holds within the iteration. **Thin**: moving the decrement after
   the mint makes this live.
3. The standing allowance is exactly one mint's price and is spender-locked — the minter's
   single `transferFrom` sources `msg.sender`, so a callback cannot direct it at this contract's
   allowance. **Thin**: widening the approval, or any future `mintOnBehalf(address from, …)`,
   batching inside `_executeMint`, or a second charge per mint, re-opens `ad36260f` **against
   the nudge pot, with no local signal in this repository**.

The per-iteration *absolute* approval is load-bearing, not a cosmetic tidy-up. It should be
recorded as an invariant to protect, not refactored for elegance.

**Cross-repo re-verification at `yield-claim-nft` `d4cc563` — the escape holds, and the watch-note
is strengthened.** `NFTMinterV2.sol` is **byte-identical** between the stale nested gitlink
(`aa86be6`) and the authoritative `d4cc563`, and `:183` remains the **sole** `transferFrom` in the
file, so the escape argument above holds exactly as written.

What *has* changed is the shape of the `dispatch` leg. At `d4cc563` it is **no longer a leaf
transfer**: `NudgeRatchet._dispatch` now does `forceApprove(streamer, bal)` +
`INudgeStreamer(streamer).collectNudge(...)` (`NudgeRatchet.sol:156-161`), so **inside the mint
loop**, the call reaches an **owner-repointable third contract** which performs both an outbound
`_settle` transfer and an inbound `transferFrom`. The escape still holds on the same three
grounds — in particular, the batcher's `forceApprove` at `:624` is spender-locked to the *minter*,
and `collectNudge`'s `transferFrom` sources the **ratchet**, not the batcher, so the batcher's
standing allowance is unreachable from it.

But the call depth between `budget -= price` and the return of `mint` has grown from one external
contract to three, one of which is repointable by owner setter after deployment. **That is exactly
the drift this watch-note exists to catch**, and it strengthens rather than weakens its thesis:
the correctness of `budget` still rests on an unasserted property of another repository, and that
repository's call graph is now wider than when the property was verified.

**Recommendation**

Make the lockstep locally checkable rather than inherited:

```solidity
// post-loop, after the mint loop completes
uint256 spent = creditedAtEntry - paymentToken.balanceOf(address(this)) + potAtEntry;
require(spent == sumOfPrices, "BatchMint: outflow != quoted");
```

or bracket the single `mint` with a `balanceOf` measurement. Note the bracket is not free: the
payment token may itself be donated back inside the same call by the dispatcher, so a naive
bracket would under-count. An explicit post-loop assertion that the aggregate debit equals
`Σ price` is the cheaper option. Either way, add a comment at `:625` naming
`NFTMinterV2._executeMint`'s one-debit-per-mint property as the assumption being relied on.

---

<a name="L-04"></a>
### [L-04] Fork drift — V1 `BatchNFTMinter.sol` never received story-029 <!-- id: pns25l4 -->

**Location**: [`src/BatchNFTMinter.sol#L280`](https://github.com/Behodler/phoenix-nft-staking/blob/5015f1b/src/BatchNFTMinter.sol#L280), [`#L284`](https://github.com/Behodler/phoenix-nft-staking/blob/5015f1b/src/BatchNFTMinter.sol#L284), [`#L305`](https://github.com/Behodler/phoenix-nft-staking/blob/5015f1b/src/BatchNFTMinter.sol#L305)

**Description**

Story-029 rewrote the payment/refund accounting in `BatchNFTMinterMultiToken.sol`. Its V1
sibling was not touched and is blob-identical to `d75229d`. Confirmed at `5015f1b`:

```
src/BatchNFTMinter.sol:280:  uint256 nudgeAmount = paymentToken.balanceOf(address(this));
src/BatchNFTMinter.sol:284:  paymentToken.forceApprove(address(nftMinter), type(uint256).max);
src/BatchNFTMinter.sol:305:  uint256 remaining = paymentToken.balanceOf(address(this));
src/BatchNFTMinter.sol:306:  if (remaining / DUST_THRESHOLD != 0) {
src/BatchNFTMinter.sol:307:      paymentToken.safeTransfer(msg.sender, remaining);
```

This is the exact pre-029 shape: an unbounded approval (the `ad36260f` root cause) alongside a
`balanceOf`-sourced sweep (the `ycn19h1` root cause). This is divergence by omission, not a
change — it is the fourth clone under this project's existing fork-drift watch
(`NFTStakerPriceScaled`, `DepletionV2`, `NFTStakerPriceScaledMigrateReady`).

**Coverage map, stated honestly — one leg is anchored, one is not:**

| Leg | Ledger coverage |
|---|---|
| **Approval** (`:284`, `type(uint256).max`) | **Anchored.** `ad36260f`'s `relocation.appliesTo` reads *"BOTH — frozen :284, new :360"*, and it is `fix-pending`, so it is never suppressed and stays visible on every future scan. |
| **`balanceOf` sweep** (`:280`, `:305-307`) | **Genuinely unanchored.** Per `858e9e80`'s own note: *"⚠ STILL UNANCHORED: the FROZEN, MAINNET-DEPLOYED src/BatchNFTMinter.sol retains this same single-token nudge lineage verbatim … and has NO ledger entry of its own; this entry anchors the multi-token file only."* |

**Filed Low because severity here is conditional on a deployment fact this scan cannot resolve.**
**Escalation trigger**: if V1 is separately deployed **and holds a non-zero payment-token
balance**, this is **Medium at minimum** — and per open ledger entry `919b71fd…` neither live
`BatchNFTMinter` instance has a pauser, so there would be no break-glass.

**Open question for the triager**: *is V1 deployed, and does it hold a pot?* Answering it
converts this finding into either a closure or a Medium.

**Do not collapse** with open ledger entry `c847207db213…` (M-02, fork drift on the same file).
That entry's root cause is a missing `ReentrancyGuard` — related, but a different defect.

**Recommendation**

Open a ledger entry against the `balanceOf`-sweep leg on the frozen file so it is anchored in its
own right rather than by adjacency, and record V1's deployment/funding status. If V1 holds no pot
and never will, document that as the standing safe-config and note it in the fork-drift register.

---

## QA / Hardening Notes

<a name="Q-01"></a>
### [Q-01] The `available` cap cannot do what its comment claims; non-binding on every constructible path <!-- id: pns25q1 -->

**Location**: [`src/BatchNFTMinterMultiToken.sol#L647-L661`](https://github.com/Behodler/phoenix-nft-staking/blob/5015f1b/src/BatchNFTMinterMultiToken.sol#L647-L661)

**Impact today: none.** Filed as a hardening note because the comment would mislead the next
author into believing a protection exists.

**Description**

The comment at `:647-655` retains the `available` cap *"only so an unforeseen shortfall degrades
into a smaller refund rather than a revert."* It cannot serve that purpose. `available` is an
**absolute** `balanceOf`, so it equals `P + (credited − C) + D` — the pot, plus this caller's
unspent credit, plus any donations landing during the call. A shortfall in the caller's own
credit therefore does not make `available` bind until the pot `P` **and** this batch's donations
`D` have already been consumed in full. In exactly the scenario the comment names, the shortfall
is **silently absorbed by the pot** instead of degrading the refund. A cap doing what the prose
claims would have to be caller-scoped, and no such quantity is tracked after `:581`.

Separately, the cap is provably **non-binding today**: `budget ≤ credited` (the `:580` `min`)
and `available = P + (credited − C) + D ≥ credited − C ≥ budget`, so `refund == budget` on every
constructible path. It is dead code that reads as a safety net.

**Merged residual (from the suppressed DEDUP-25-09 — retained rather than dropped)**

`budget` is a **one-shot measurement pinned once at `:581` and never re-validated**. Any
post-`:581` erosion of this contract's payment-token holdings is therefore charged to the pot,
silently. **This needs no weird token** — a negative-rebase prime token is sufficient on its own,
independently of the transfer-hook narrative below.

**DoS tail**: once such erosion exceeds `P + D`, the step-9/10 payout swap turns a silent pot
shrink into a `batchMint` **revert on the payout leg** — a liveness failure, not just a leak.

**Scope note and re-open condition**: the standalone exploit narrative — a payment token that is
*simultaneously* fee-on-transfer *and* exposes a sender-side transfer hook (ERC777
`tokensToSend` / ERC1363 callback), letting an attacker restore `budget` mid-pull and charge the
fee to the pot — was **suppressed as C4 known-invalid** (weird ERC-20 + fee-on-transfer, neither
in scope; `NudgeRatchet` in fact mandates plain 6-decimal USDC). **Re-open it** if any future
`dispatcherIndex` resolves to a rebasing or hooked prime token. `primeToken()` is
owner-repointable, so that suppression is a statement about current token selection, not about
the code.

**Recommendation**

Either delete the cap and let an impossible shortfall revert honestly, or track a caller-scoped
quantity and cap on that. In either case, correct or remove the comment at `:647-655` — the
sequence `balanceOf` read at `:660` sits at the one kind of site the file elsewhere explicitly
forbids absolute reads (`:585-605`), and the misleading comment is what would let a future
erosion mechanism pass review.

---

<a name="Q-02"></a>
### [Q-02] The `:580` `min` is a single point of failure for two properties, only one documented <!-- id: pns25q2 -->

**Location**: [`src/BatchNFTMinterMultiToken.sol#L562-L581`](https://github.com/Behodler/phoenix-nft-staking/blob/5015f1b/src/BatchNFTMinterMultiToken.sol#L562-L581) (the `min` at `:580`), consequence at [`#L664`](https://github.com/Behodler/phoenix-nft-staking/blob/5015f1b/src/BatchNFTMinterMultiToken.sol#L664)

**This is a future-regression trap, not a present defect.** The code at `5015f1b` is correct.

**Description**

```solidity
budget = credited < paymentAmount ? credited : paymentAmount;   // :580
...
totalPaid = paymentAmount - refund;                             // :664  — guard REMOVED
```

`d75229d` had `totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0`.
Story-029 **deliberately removed** the `>` guard — commit `0318089` §3.3 names its *absence* as
the marker of the fix. The removal is safe, but **only** because `refund ≤ budget ≤ paymentAmount`,
and that holds **solely** because of the `min` at `:580`.

The problem is that the 20-line comment at `:562-571` justifies that `min` **entirely on
donation-routing grounds** — that a mid-pull donation must not raise `budget` above
`paymentAmount` — and mentions underflow in one clause of one sentence. A future author
reasoning only about donation routing (relaxing the cap to a floor, or replacing `min` with the
measured `credited` on the grounds that "measuring is strictly more honest") reintroduces an
**underflow revert DoS** at `:664` with no local warning and no test name pointing at it. The
deleted guard is the documented marker of a landed fix, so its absence will read as intentional
and correct — which it is, but only conditionally.

**Recommendation**

Pin both obligations at the `min` site, so the second one is not silently load-bearing:

```solidity
// INVARIANT (two obligations, both discharged here — do not relax either):
//   1. donation routing: a mid-pull donation must not raise budget above paymentAmount;
//   2. underflow safety : refund <= budget <= paymentAmount is what makes the unguarded
//                         `totalPaid = paymentAmount - refund` at :664 safe. Story-029
//                         removed that guard on the strength of THIS line.
budget = credited < paymentAmount ? credited : paymentAmount;   // :580
```

A regression test named for obligation (2) — asserting `batchMint` does not revert when
`credited < paymentAmount` — would give the trap a failing signal.

---

## Appendix A — Automated report (4naly3er)

**Status: generated successfully.** Full output:
[`reports/phoenix-nft-staking-25/submissions/4naly3er-report.md`](./4naly3er-report.md) (7,951 lines).

Command used (basePath points at the **submodule root** so `remappings.txt` resolves relative to
it; the third argument is a **scope list**, not a remappings file):

```bash
cd tools/4naly3er
yarn analyze /home/justin/code/audits/lib/phoenix-nft-staking/ <scope-list>.txt
# scope list = all 14 first-party src/*.sol paths, relative to basePath
```

This appendix is a mechanically generated baseline. It is **separate from and subordinate to**
the reasoned findings above; none of the items below were promoted into this bundle, and no
severity in this appendix should be read as this audit's assessment.

**Medium (automated classification — not this audit's severities)**

| | Issue | Instances |
|-|:-|:-:|
| M-1 | Contracts are vulnerable to fee-on-transfer accounting-related issues | 8 |
| M-2 | Centralization Risk for trusted owners | 92 |
| M-3 | Return values of `transfer()`/`transferFrom()` not checked | 2 |
| M-4 | Unsafe use of `transfer()`/`transferFrom()` with `IERC20` | 2 |

M-1 is out of scope per the C4 known-invalid list (fee-on-transfer tokens). M-2's 92 instances
are the tool's blanket `onlyOwner` count and are **not** filed as Centralization findings — under
this audit's Law-3 the owner is trusted for knowing actions, and none of the 92 met the footgun
test. M-3/M-4 are on library-adjacent call sites; no unchecked-return exploit path was
constructible.

**Low (automated classification)**

| | Issue | Instances |
|-|:-|:-:|
| L-1 | Use a 2-step ownership transfer pattern | 9 |
| L-2 | Some tokens may revert when zero value transfers are made | 32 |
| L-3 | Missing checks for `address(0)` when assigning values to address state variables | 12 |
| L-4 | Division by zero not prevented | 22 |
| L-5 | Owner can renounce while system is paused | 7 |
| L-6 | Possible rounding issue | 10 |
| L-7 | Loss of precision | 65 |
| L-8 | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 9 |
| L-9 | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 10 |
| L-10 | Sweeping may break accounting if tokens with multiple addresses are used | 9 |
| L-11 | Unsafe ERC20 operation(s) | 2 |
| L-12 | A year is not always 365 days | 5 |

(12 Low classes, 192 instances total.)

**Non-critical**: 25 classes, 709 instances (style, NatSpec, event indexing, naming).
**Gas**: 14 classes, 976 instances. Both are reproduced in full in the linked file and are not
summarised here; C4 discourages non-critical items and this audit does not file them.

---

## Appendix B — Parked / not filed

The following were set aside during this run **with a reason**, in the Law-1 visible channel
(`reports/phoenix-nft-staking-25/manual-review.json`). Nothing here was dropped; each awaits a
human decision at `/ledger` triage. Listed so they are discoverable from the report.

| id | Item | Why parked | Ask of the triager |
|---|---|---|---|
| **MR-01** | 14 Aderyn `reentrancy-state-change` potential-highs (plus 38 Slither `reentrancy-no-eth`, 8 benign, 6 events) across `InPlaceNFTStakerMigrator`, `NFTStaker`, `NFTStakerDepletion`/`V2`, `NFTStakerMigrator`, `NFTStakerPriceScaled`(`MigrateReady`), `NudgeStreamer` | All the same rule on the same pre-existing staker/migrator shape inside functions carrying `nonReentrant`; the detector is known FP-prone against that guard. All sit **outside the story-029 regression range** (the delta touches exactly one `src/` file, none of these). Parked as a **deferral, not a verdict** — the sites were not opened individually. | Confirm they carry prior triage from runs 1-24. If any of these contracts enters a future delta, re-derive at source — the FP prior is a statement about the detector, not a per-site proof. |
| **MR-02** | Streamer-flush loop gas ceiling — `INudgeStreamer.pullPendingStream` is called once per whitelisted nudge token, unconditionally, on **every** `batchMint` (`:521-533`), compounded by full-length passes at `:756` and `:786` | The array is **owner-bounded**, making this a Law-3 gas/liveness ceiling rather than a permissionless DoS. The escape is a *bound*, not an absence of risk. Cost is pre-existing; story-029 only block-scoped the loop. | Decide whether a whitelist-length cap belongs in a future QA bundle. **Whitelist growth is the re-arm trigger** — three full-length passes per `batchMint` puts the practical ceiling on nudge-token count lower than it looks. |
| **MR-03** | `amount == 0` strict-equality skip-guard in `_payRewards` (`:788`) | It is a skip-guard (do not transfer zero), not a value comparison against a manipulable quantity, so strict equality is correct for its purpose. Pre-existing, unchanged lines, no constructible impact. Named rather than deleted so it is not invisible. | Confirm suppression. No code change recommended. |
| **MR-04** | Near-miss margin register: NM-03 (`configs()` TOCTOU), NM-04 (absolute `forceApprove` semantics), NM-05 (new boundary operators), NM-07 (Linear-Depletion class not applicable — zero signature hits), NM-08 (ERC777 / cross-function / read-only reentrancy), P-04 (step-9/10 swap soundness) | Checked-and-escapes. Recorded so a future run inherits the escape **reasons**, not just the verdicts. NM-01 and NM-02 are deliberately **not** here — their margins are load-bearing and are filed above as **L-03**. | No action. Retain so a later run does not re-derive these from scratch or, worse, silently assume them. |
| **MR-05** | KI #15 scope determination — story-029 widened the risk accepted on 2026-07-25 in three respects | (1) M-01/M-03 fall inside KI #15's own carve-out **(d)** (*"the aggregate over-funding class … about the pot being too LARGE relative to cost"*), i.e. inside the carve-out, not the acceptance. (2) The acceptance's stated premise ("the pot is by construction a fraction of the cost") is falsified. (3) The accepted risk was static; the delivered risk is **self-arming**. The four claims KI #15 suppresses are **not** re-filed anywhere in this run. | Re-confirm the acceptance against the enlarged surface, or narrow it. **Do not treat the 2026-07-25 acceptance as covering M-01/M-02/M-03.** ⛔ **MR-05 IS WITHDRAWN 2026-07-26.** The KI-scope-drift determination rested on reading KI #15 carve-out (d) as covering a deliberately-set subsidy rate; it does not (see KI #16). M-01/M-02 are `false-positive`; **do not re-weigh ledger `43e8c48626ee…` or `858e9e807abe…` — their re-arm triggers are NOT met on pot-size grounds and their `wont-fix` rationale stands unchallenged.** |
