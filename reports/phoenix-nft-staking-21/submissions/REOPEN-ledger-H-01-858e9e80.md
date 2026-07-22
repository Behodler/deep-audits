<!--
ID: 858e9e80 (ledger fingerprint — this record mints NO new finding ID and NO M-nn label)
C4 Submission Metadata — ⚠ EXPIRED-CLOSURE / LEDGER-REOPEN PROPOSAL
Title: Value-blind nudge gate — CLOSURE RATIONALE EXPIRED VIA RELOCATION (ledger H-01, currently status=fixed)
Record kind: LEDGER-REOPEN-PROPOSAL. NOT a new finding. NOT a code regression. NOT labelled M-nn.
Project: phoenix-nft-staking
Run: phoenix-nft-staking-21 @ c881a428c87ef4ef42ba07a71be5d49101c9006d
Baseline: 0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54
Ledger fingerprint: 858e9e807abee888b378db210bae982f23fe7b5d91052321e204d7ba568579b7
Current ledger status: fixed  (fixedAtCommit 031ffda; lastRecheckedCommit 5f863d27, 2026-06-05, recheckResult STILL-FIXED)
Proposed status: reopen — PROPOSAL ONLY. An agent does not flip the status (D-09).
Severity AT HEAD: Medium  (the ledger entry was HIGH at run phoenix-nft-staking-12)
Contract at HEAD: src/BatchNFTMinterMultiToken.sol (batchMint / _snapshotRewards / _payRewards)
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/c881a428c87ef4ef42ba07a71be5d49101c9006d/src/BatchNFTMinterMultiToken.sol#L352
PoC File: workspace/phoenix-nft-staking/test/PoC_NudgeLineage_H01.t.sol (4/4 PASS @ c881a42, poc-replay.md §4.1)
Corroboration: test/InvariantBatchNudge.t.sol — invariant_sweep BROKEN (poc-replay.md §4.4)
Mainnet evidence: reports/phoenix-nft-staking-21/mainnet-verification-ECON-001.md (chainid 1, block 25577241, read-only)
Prior proposal: run-20 CLASS-009 → REOPEN-ledger-H-01-858e9e80 (D-26/D-27/D-29) — ⚠ NEVER APPLIED
-->

> ### ⚠ Read this framing first
>
> **This is NOT a code regression. The reasoning that closed this finding expired.**
>
> **No patch was reverted. There is no intact patch to restore.** story-014's owner-pinning of the minter
> and `dispatcherIndex` is **intact**, and is **proven intact at HEAD** by the negative control
> `test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED` (poc-replay.md §4.3, PASS —
> *"variant A remains correctly closed"*). **Do not use this record to argue that the pinning should be
> revisited, and do not send a fixer to restore a guard that is working.**
>
> **This record carries NO `M-nn` label, by design** (run-20 R-2 / D-29). It mints no new defect: the
> mechanic is already filed live this run as `M-01` (`7a1718e9…`) and is carried by ledger `M-02`
> (`a62fe01a…`). Numbering it would double-count one defect to the reader. This is the **ledger-side
> consequence only**.

> **⚠ Label-collision guard.** This record concerns **ledger `H-01` = `858e9e80…`**. It is **not**
> run-20's `H-01` `1c222d5485…` (`NFTStakerDepletion.depositFor`, fix-pending) and **not** run-21's
> `M-01` `7a1718e9…`. This project's ledger reuses `H-01`/`M-01`/`L-01` across different contracts and
> different runs — **disambiguate by fingerprint, never by label.**

## Finding description and impact

### The prior disposition, quoted verbatim

The ledger entry `858e9e80…` currently reads `status: fixed`, with this `severityNote`:

> *"Was a valid High at run phoenix-nft-staking-12 (permissionless caller-chosen-dispatcher drain).
> **FIXED by story-014 at HEAD 031ffda. Residual value-blindness is owner-driven only and invalid**;
> retained as QA design note L-04 in phoenix-nft-staking-13."*

and this `note`:

> *"story-014 fixed the permissionless caller-chosen-dispatcher drain (the run-12 valid High) by
> owner-pinning the minter and dispatcherIndex; **residual value-blindness only exploitable via owner
> misconfiguration (zero-price pinned dispatcher / over-funded pot) => owner-driven, invalid.** NOT a
> regression: this is a confirmed fix of the permissionless vector."*

It also already carries the run-20 flag:

> `humanReviewFlag`: *"⚠ EXPIRED-CLOSURE — REOPEN PROPOSED (run-20). Status left `fixed` pending human
> decision (D-09)."*

### Why the closure expired — two grounds, neither of them a regression

**(a) Relocation.** story-022 Stage 7 (`fba4991`) moved the nudge code out of `src/BatchNFTMinter.sol`
into the new `src/BatchNFTMinterMultiToken.sol`. That mints a **new `contract:function` fingerprint that
dedup cannot match** against the `fixed` entry. The finding will therefore **never self-reconcile** — it
needs an explicit reopen against the existing fingerprint.

**(b) The owner-pinning premise that the "invalid" judgement rested on is gone.** The closure held the
residual value-blindness to be *"owner-driven only"*. On the relocated sibling, `rewardTokens` is a
**caller-supplied array** — **the caller, not the owner, now names the asset**. Law 3 protects the
owner-trusted surface; it cannot reach a facet an unprivileged caller reaches without the owner. The
predicate the judgement was applied to is **false at HEAD**.

*(Ground (1) of the run-15 sanitizer suppression of the same lineage — `eeb62b84…`, reckless-admin — is
falsified by the same fact: the demonstrated path is **unprivileged**. That suppression was a sanitizer
action, not a human triage, so **no owner decision is being overridden** by saying so.)*

### The defect at HEAD

1. The gate at
   [`BatchNFTMinterMultiToken.sol:352`](https://github.com/Behodler/phoenix-nft-staking/blob/c881a428c87ef4ef42ba07a71be5d49101c9006d/src/BatchNFTMinterMultiToken.sol#L352)
   is purely numeric — `count >= nudgeSize` — a **count compared to a count, paying out a value**.
2. `_snapshotRewards` (`:424`) takes a full pre-loop `balanceOf` of each **caller-supplied** reward token.
3. `_payRewards` (`:452-461`) pays the whole snapshot, **winner-take-all**, to a caller-chosen `recipient`.
4. Qualifying costs the price of `nudgeSize` mints; the payout is whatever the contract holds. The two
   are **decoupled**.

The NatSpec's *"by construction"* bound is backed by **no code** — filed separately this run as `L-04`
and carried as ledger `F-20-07` (`a7dffb34…`).

### PoC evidence

`workspace/phoenix-nft-staking/test/PoC_NudgeLineage_H01.t.sol` — **4/4 PASS** against the relocated code
at `c881a42` (poc-replay.md §4.1). PoC convention: **PASS = defect reproduced.**

| Test | Numbers |
|---|---|
| `test_PoC_H01_AttackerDrainsFullNudgePool` | Attacker mints `nudgeSize = 5`, spends **5,256.33 phUSD**, takes **50,000 USDC** — the entire pot. An honest 50-NFT batch spends **110,294.59 phUSD** and receives **0**. Asserts `stolen == NUDGE_REFILL_AMOUNT` and `pot == 0`. |
| `test_PoC_H01_PotIsNotBoundedByMintCost` | Cost to qualify **5,256.33 phUSD** vs pot captured **50,000** — the payout is not bounded by outlay. |
| `test_PoC_H01_RecipientAsymmetry` | Payer pays **5,256.33 phUSD**; a `recipient != msg.sender` receives all 5 NFTs **and** the full **50,000 USDC**; the payer receives **0**. |
| `test_PoC_H01_ThresholdGamingAcrossRefills` | 3 refill cycles: attacker spends 5,256 / 5,947 / 6,728 phUSD and takes 50,000 each — **150,000 USDC total**. |

**Corroborating stateful fuzz** (poc-replay.md §4.4, non-vacuous — handler call counts in the thousands):
`invariant_sweep` — *"the sweep must never leave a caller net-positive"* — is **BROKEN**, shrunk to a
caller **net gain of 18,969.39e18** against a 19,000e18 pot across cold runs. This is the same
value-blind class expressed as a stateful invariant against the real contract.

The multi-token split **moved** this code; it did not fix it. story-022's `minRewards` addition does not
close it (see the companion record `521c20ad…`).

### ⚠ Present exposure — bounded honestly

**The mechanic is proven in code. Present drainability is NOT claimed.**

Fresh read-only reads, chainid 1, block **25577241** (`mainnet-verification-ECON-001.md`):

- **`src/BatchNFTMinterMultiToken.sol` — the file this is re-filed against — is NOT deployed.** Selector
  `0xca0ced0b` is absent from all five known instances. (Per run-20 R-6 this is *not* used to bound
  severity; it is stated so nobody reads the reopen as an emergency.)
- The **lineage is live on the frozen deployed instances**, which retain their own single-token nudge
  (`nudgePaymentToken` at `:87`/`:149`/`:260`) verbatim.
- A **real 94.953127 USDC pot exists** on `0x86866e01…029d`. It is that instance's **nudge token**, and
  it is reachable **only through its intended gate**: `nudgeSize = 40` at 15.857984 USDS per mint, i.e. a
  genuine **~634+ USDS** cost. That is **loss-making for the attacker** — **the designed bounty operating
  as intended, not a drain.**
- The pot is visibly being paid out through that gate and re-accumulating: 270.014282 USDC at block
  25540000 → 94.953127 at block 25577241.

**The report must not claim funds are currently drainable, and this one does not.** Profitability today
is a *configuration property* (the pot-versus-cost ratio), not a code bound. The reopen is warranted on
**the code defect**.

### ⚠ Run-20 already proposed this reopen, and it was never applied

Run-20 filed `CLASS-009 → REOPEN-ledger-H-01-858e9e80` (rulings D-26 / D-27 / D-29). **The operator never
applied it.** The ledger entry still carries the run-20 `humanReviewFlag` verbatim, and the status is
still `fixed`. This run re-proposes it with **fresh PoC evidence against the relocated file** and fresh
mainnet reads at a newer block.

### Severity at HEAD: Medium

Assessed on HEAD's evidence, not inherited from the run-12 High. The defect is PoC-proven live in code,
but at present parameters the payout is **smaller than the qualifying cost**, so **no value is presently
extractable** — a value leak with stated assumptions (pot > qualifying cost) and external requirements
(pot funding). It was High at run-12 when that relation was inverted, and it **returns to High if the
relation inverts again**.

Filed as a reopen rather than a numbered Medium because the mechanic is already carried by live findings
this run and a new label would inflate the count.

### ⚠ RE-ARM TRIGGER — the funding relation that holds this at Medium, and what inverts it

This entry is held below High by **exactly one relation**: *the nudge pot is smaller than the cost of
`nudgeSize` mints*. That relation is **asserted in NatSpec and enforced nowhere** — filed this run as
`L-04` (`75305ec0…`) and carried as ledger `F-20-07` (`a7dffb34…`). It is **operator funding practice,
not a code bound**, and **this entry was a valid High at run phoenix-nft-staking-12, when the relation
was inverted.** It returns to High the moment it inverts again, so the arming condition ships with the
finding rather than being left for the next reader to rediscover.

Live parameters at block 25577241 (`mainnet-verification-ECON-001.md`): `0x86866e01…029d` holds a
**94.953127 USDC** pot with `nudgeSize = 40` at **15.857984 USDS/mint** — i.e. **~634 USDS to qualify**.
The pot is ~15 % of the qualifying cost; the relation holds today with roughly a 6.7× margin.

**RE-RATE TO HIGH IMMEDIATELY**, without waiting for a scheduled run, on any of:

- **(a)** the nudge pot on `0x86866e01…029d` exceeding **~634 USDS-equivalent** (i.e. `nudgeSize ×`
  current mint price) — today ~94.95 USDC against that bar;
- **(b)** the nudge pot on `0x81896F48…A1C7` exceeding `nudgeSize × 70.000000 USDC`, on the same test;
- **(c)** any reduction of `nudgeSize`, or of the per-mint price, that lowers the qualifying cost below
  the standing pot — the relation can invert from **either** side, and the price side is the one an
  operator is most likely to change for unrelated reasons;
- **(d)** `NudgeRatchet.batchMinter()` (`0x7A4eD111…`) being repointed between instances such that the
  USDC donation stream lands on an instance where the pot grows faster than the qualifying cost — the
  same one-call operator move flagged as trigger (c) on run-21 `M-01`, and one the operator has made
  repeatedly (`FixRatchetBatchMinterSink`, `DisableNudgeAndDivertDonations`,
  `DispatcherReplaceSkyPoolerAtIndex4`);
- **(e)** deployment of `src/BatchNFTMinterMultiToken.sol` behind any dispatcher that forwards value into
  it — on that file `rewardTokens` is **caller-supplied**, so the caller names the asset and the pot is
  no longer a single operator-chosen token.

**Law-3 note (footgun, in scope).** Each of (c) and (d) is an *ordinary* operator move. A competent,
non-malicious owner would be surprised that a routine repoint or a price change converts a loss-making
designed bounty into a profitable drain. That is a footgun, not a malicious-owner vector, and it is not
filed as one.

## Recommended mitigation steps

### 1. Ledger action — reopen against the EXISTING fingerprint

**Reopen `858e9e807abee888b378db210bae982f23fe7b5d91052321e204d7ba568579b7`.** Do **not** mint a new
fingerprint; a new entry would sever the run-12 → run-21 history that makes this legible.

Re-anchor the entry to `src/BatchNFTMinterMultiToken.sol` (gate `:352`, snapshot `:424`, payout
`:452-461`), and record that the lineage remains structurally present on the frozen deployed file.

### 2. If the residual is still judged acceptable, re-close it against HEAD's premises

Leaving it `fixed` is wrong under either reading: it asserts the residual was **eliminated**, when it was
**dismissed on a premise that is now false**. If the facet is acceptable, the correct disposition is
`acknowledged` / `wont-fix` **with a rewritten rationale that does not rest on the dead owner-driven
premise** — i.e. one written against a caller-supplied `rewardTokens` array.

### 3. Code — make the gate value-aware

The gate compares a count and pays a value. Bound the payout by the caller's actual outlay, or cap it as
a fraction of the qualifying mint cost, so the NatSpec's *"by construction"* claim is backed by code
rather than by operator funding discipline (see `L-04` and ledger `F-20-07` `a7dffb34…`).

### 4. Do not collapse with the companion reopen `521c20ad…`

`858e9e80…` is the value-blind **gate** (payout decoupled from outlay). `521c20ad…` is the **race** for
it (who wins among qualifying callers). **Two distinct defects, two distinct fixes.** Run-20 filed two
separate reopens for exactly this reason (D-29), and that separation is honoured here.
