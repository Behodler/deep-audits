<!--
ID: 521c20ad (ledger fingerprint — this record mints NO new finding ID and NO M-nn label)
C4 Submission Metadata — ⚠ EXPIRED-CLOSURE / LEDGER-REOPEN PROPOSAL
Title: MEV / first-claimer front-run of the winner-take-all nudge pot — CLOSURE RATIONALE EXPIRED VIA RELOCATION
       (ledger M-01, currently status=fixed, ⚠ OWNER-SIGNED 2026-06-09 TRIAGE AFFECTED)
Record kind: LEDGER-REOPEN-PROPOSAL. NOT a new finding. NOT a code regression. NOT labelled M-nn.
Project: phoenix-nft-staking
Run: phoenix-nft-staking-21 @ c881a428c87ef4ef42ba07a71be5d49101c9006d
Baseline: 0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54
Ledger fingerprint: 521c20ad48b388ea37eea906fb5e5495885952fcd944a3377fee24f274434d60
Current ledger status: fixed  (fixedAtCommit 5f863d27…, marked fixed per OWNER TRIAGE 2026-06-09)
Proposed status: reopen — PROPOSAL ONLY. An agent does not flip the status (D-09).
Severity AT HEAD: Medium
Contract at HEAD: src/BatchNFTMinterMultiToken.sol (batchMint)
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/c881a428c87ef4ef42ba07a71be5d49101c9006d/src/BatchNFTMinterMultiToken.sol#L288-L291
PoC File: workspace/phoenix-nft-staking/test/PoC_NudgeLineage_MevFrontrunNudge.t.sol (2/2 PASS @ c881a42, poc-replay.md §4.2)
Mainnet evidence: reports/phoenix-nft-staking-21/mainnet-verification-ECON-001.md (chainid 1, block 25577241, read-only)
Coupled to: ledger L-05 990d8c37… (wont-fix) — the closure depends on a mitigation L-05 declares default-off
Prior proposal: run-20 CLASS-010 → REOPEN-ledger-M-01-521c20ad — ⚠ NEVER APPLIED
-->

> ### ⚠ Read this framing first
>
> **This is NOT a code regression. The reasoning that closed this finding expired.**
>
> **No patch was reverted, and no path got worse.** There is no intact guard for anyone to "restore".
> **story-014's owner-pinning of the minter and `dispatcherIndex` is intact** and proven intact at HEAD
> (`test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED`, poc-replay.md §4.3, PASS) — the
> closure's first premise, *"a free claim is impossible"*, **still holds**. Do not use this record to
> argue that the pinning should be revisited.
>
> **This record carries NO `M-nn` label, by design** (run-20 R-2 / D-29). It mints no new defect, and
> numbering it would double-count one defect to the reader. This is the **ledger-side consequence only**.

> ### ⚠ An OWNER-SIGNED 2026-06-09 TRIAGE IS AFFECTED
>
> This entry was marked `fixed` by an explicit human triage dated **2026-06-09**, not by an automated
> reconciliation. That decision is quoted verbatim below, together with the specific facts that have
> since falsified parts of its reasoning. **This entry needs the operator's eyes more than any other in
> this run.** The coupled 2026-05-30 triage of ledger `L-05` (`990d8c37…`, `wont-fix`) **stands unchanged
> and is not overridden here** — quoting it is the disclosure obligation being discharged, per the
> disclose-when-re-filing rule.

> **⚠ Label-collision guard.** This record concerns **ledger `M-01` = `521c20ad…`**. It is **not**
> ledger `M-01` `fcaca002…` (step-10 sweep), **not** ledger `M-01` `b58b172e…` (`NFTStakerDepletion`
> rate drift), and **not** run-21's own `M-01` `7a1718e9…`. Four distinct findings share the label
> `M-01` in this project — **disambiguate by fingerprint, never by label.**

## Finding description and impact

### The prior disposition, quoted verbatim

The ledger entry `521c20ad…` currently reads `status: fixed`, closed on this owner triage:

> *"**[FIXED 2026-06-09]** The core actionable harm was honest-user overpayment: a caller pays
> nudgeSize×mintPrice expecting a reward and receives nothing. **This is fully closed by the `minReward`
> slippage floor (story-015)**: if the pot has been front-run, the batch reverts atomically and the
> honest user pays nothing. The remaining race — who wins the pot among qualifying batches — is an
> accepted gas-auction among genuine protocol participants, each of whom must pay the full mint cost.
> `nudgeSize` ensures no free-claim path exists (story-009). **Marked fixed at HEAD 5f863d27 per owner
> triage 2026-06-09.**"*

and, in the `severityNote`:

> *"[2026-06-09] FIXED: threat model scoped to honest-user protection (loser-overpay), not MEV race
> capture. minReward closes the actionable harm; race-to-win is accepted protocol behavior."*

The entry already carries the run-20 flag:

> `humanReviewFlag`: *"⚠ EXPIRED-CLOSURE — REOPEN PROPOSED (run-20); **OWNER-SIGNED 2026-06-09 triage
> affected**. Status left `fixed` pending human decision (D-09)."*

### Why the closure expired — relocation, not regression

story-022 Stage 7 (`fba4991`) **relocated** the nudge code from `src/BatchNFTMinter.sol` to the new
`src/BatchNFTMinterMultiToken.sol` — the same mechanism as the companion record `858e9e80…`. The move
mints a **new `contract:function` fingerprint that dedup cannot match** against the `fixed` entry, so the
finding will **never self-reconcile**. No patch was removed; the closure's *anchor* moved out from under it.

### The specific fact that falsifies the closure's mitigation premise

The 2026-06-09 triage rests on `minReward` **fully** closing the harm. It does not, and the contract says
so in its own words at
[`BatchNFTMinterMultiToken.sol:288-291`](https://github.com/Behodler/phoenix-nft-staking/blob/c881a428c87ef4ef42ba07a71be5d49101c9006d/src/BatchNFTMinterMultiToken.sol#L288-L291):

> the floor *"does **NOT** stop a front-runner from winning the pot — whoever qualifies first still takes
> the entire balance-based payout; the floor only stops the loser from minting for less than they
> declared."*

**The floor protects the LOSER'S CAPITAL, not the OUTCOME of the race.**

Two further disclosures owed to the operator:

- **The mitigation is default-off.** The floor only fires if the caller sets it, and its default is `0` —
  the state of affairs accepted under **ledger `L-05` (`990d8c37…`, `wont-fix`)**, whose accepted position
  is that the obligation lives at the front-end. **Nobody has been identified as owning that obligation,
  and no run has ever checked it.** That 2026-05-30 triage stands; it is named here so the two entries
  are not read in isolation from each other.
- **story-022 materially widened the transferred obligation.** `minReward` went from a **scalar** to a
  **per-token `minRewards[]` array parallel to a caller-supplied `rewardTokens[]`**, under an explicit
  *"Array hygiene is the caller's responsibility"* disclaimer. That is a **larger integration obligation
  than the one accepted on 2026-05-30, and it has never been re-triaged.**

### PoC evidence

`workspace/phoenix-nft-staking/test/PoC_NudgeLineage_MevFrontrunNudge.t.sol` — **2/2 PASS** against the
relocated code at `c881a42` (poc-replay.md §4.2). PoC convention: **PASS = defect reproduced.**

| Test | Numbers |
|---|---|
| `test_M01_searcherFrontrunsHonestNudgeClaimant` | Pot **50,000e18**. Searcher outlay **5,256.33e18** → gains **50,000e18**, the whole pot, with `NudgePaid` emitted **to the searcher**. The honest user then genuinely qualifies — mints 5 NFTs, pays **5,947.05e18** — and receives **0**, with **no `NudgePaid` log** to them (asserted). |
| `test_M01_minRewardsFloorDoesNotStopTheFrontRun` | With a floor set, the honest transaction reverts with the exact error **`BatchMint__RewardBelowMinimum(nudgeToken, 50000e18, 0)`**. The loser's *capital* is spared; the **front-run outcome is unchanged**. |

**The floor bounded fairly.** It is not worthless — the second test shows a correctly-set floor does real
work in sparing the loser's outlay. It is **narrower than "fully closed", not absent.**

The attack path is four steps: the nudge is winner-take-all against a pre-loop snapshot; a searcher
observes an honest qualifying batch in the mempool; the searcher front-runs it with its own qualifying
batch and takes the entire pot; the honest batch executes, qualifies, and is paid nothing.

### ⚠ Present exposure — bounded honestly

**The mechanic is proven in code. Present drainability is NOT claimed, and present profitability is NOT
asserted.**

Fresh read-only reads, chainid 1, block **25577241** (`mainnet-verification-ECON-001.md`):

- **`src/BatchNFTMinterMultiToken.sol` — the file this is re-filed against — is NOT deployed** (selector
  `0xca0ced0b` absent from all five known instances). Per run-20 R-6 this is not used to bound severity;
  it is stated so nobody reads the reopen as an emergency.
- A **real 94.953127 USDC pot exists** on `0x86866e01…029d`, with `nudgeSize = 40`. It is reachable
  **only through its intended gate**, at a genuine **~634+ USDS** cost (40 mints at 15.857984 USDS).
  **Winning it today costs the searcher more than it pays** — **the designed, loss-making bounty
  operating as intended.**
- The pot is visibly being paid out through that gate and re-accumulating: **270.014282 USDC** at block
  25540000 → **94.953127** at block 25577241. The race is live; it is simply not currently profitable.

### ⚠ Run-20 already proposed this reopen, and it was never applied

Run-20 filed `CLASS-010 → REOPEN-ledger-M-01-521c20ad`. **The operator never applied it.** The status is
still `fixed` and the run-20 `humanReviewFlag` is still on the entry. This run re-proposes it with fresh
PoC evidence against the relocated file and fresh mainnet reads at a newer block.

### Severity at HEAD: Medium

A value leak — the honest claimant's expected payout — via an unpreventable MEV race, PoC-proven live in
code, with the assumption (pot > qualifying cost) and the external requirement (pot funding) both stated.
Filed as a reopen rather than a numbered Medium so that one defect is not counted twice.

### ⚠ RE-ARM TRIGGER — the funding relation that holds this at Medium, and what inverts it

Like the companion record `858e9e80…`, this entry is held below High by **exactly one relation**: *the
nudge pot is smaller than the cost of `nudgeSize` mints*, so winning the race costs the searcher more
than it pays. That relation is **asserted in NatSpec and enforced nowhere** — filed this run as `L-04`
(`75305ec0…`) and carried as ledger `F-20-07` (`a7dffb34…`). It is **operator funding practice, not a
code bound**, and it is the only thing making the live race unprofitable rather than a standing MEV
bounty. The arming condition ships with the finding rather than being left for the next reader.

Live parameters at block 25577241 (`mainnet-verification-ECON-001.md`): `0x86866e01…029d` holds a
**94.953127 USDC** pot with `nudgeSize = 40` at **15.857984 USDS/mint** — i.e. **~634 USDS to qualify**.
The race is **live and running** (pot observed at 270.014282 USDC @ block 25540000 → 94.953127 @ block
25577241); it is simply not currently profitable.

**RE-RATE TO HIGH IMMEDIATELY**, without waiting for a scheduled run, on any of:

- **(a)** the nudge pot on `0x86866e01…029d` exceeding **~634 USDS-equivalent** (`nudgeSize ×` current
  mint price) — at that point front-running the honest claimant is **net-profitable** and searchers
  arrive without any further change;
- **(b)** the nudge pot on `0x81896F48…A1C7` exceeding `nudgeSize × 70.000000 USDC`, on the same test;
- **(c)** any reduction of `nudgeSize`, or of the per-mint price, that lowers the qualifying cost below
  the standing pot — the relation inverts from **either** side;
- **(d)** `NudgeRatchet.batchMinter()` (`0x7A4eD111…`) being repointed between instances such that the
  USDC donation stream lands where the pot outgrows the qualifying cost (the same one-call operator move
  flagged as trigger (c) on run-21 `M-01`);
- **(e)** deployment of `src/BatchNFTMinterMultiToken.sol` behind a value-forwarding dispatcher — the
  caller-supplied `rewardTokens[]` array widens the set of assets a searcher can race for beyond the one
  operator-chosen nudge token.

⚠ Note the interaction with the closure's own mitigation: `minReward` is **default-off** (ledger `L-05`
`990d8c37…`, `wont-fix`, front-end obligation with **no identified owner and never verified by any
run**). If the pot relation inverts while that obligation is still unowned, the honest claimant has
**neither** a profitable-race deterrent **nor** an active slippage floor.

**Law-3 note (footgun, in scope).** Triggers (c) and (d) are ordinary operator moves. A competent,
non-malicious owner would be surprised that a routine repoint or price change converts a
designed-and-accepted gas auction into a standing profitable MEV extraction against honest users. Footgun,
not a malicious-owner vector; not filed as one.

## Recommended mitigation steps

### 1. Ledger action — reopen against the EXISTING fingerprint

**Reopen `521c20ad48b388ea37eea906fb5e5495885952fcd944a3377fee24f274434d60`.** Do **not** mint a new
fingerprint. Re-anchor it to `src/BatchNFTMinterMultiToken.sol:batchMint`.

### 2. If the residual is still acceptable, re-close it against HEAD's premises

Leaving it `fixed` asserts the harm was **eliminated**, when the mitigation the closure called *"fully
closed"* is documented **in-contract** as partial and is default-off. If the operator still accepts the
residual — a legitimate position — the correct disposition is `acknowledged` / `wont-fix` **with a
rationale rewritten against HEAD**, i.e. one that accounts for (a) the per-token `minRewards[]` array
widening and (b) the unowned front-end obligation recorded in ledger `L-05`.

### 3. Re-triage ledger `L-05` (`990d8c37…`) alongside this

The 2026-05-30 `wont-fix` accepted a **scalar** default-zero floor with a front-end obligation. HEAD ships
a **caller-supplied token array** with per-token floors and an explicit *"array hygiene is the caller's
responsibility"* disclaimer. The accepted object and the shipped object are not the same object. Identify
who owns the front-end obligation, or accept it again explicitly against the widened surface.

### 4. Do not collapse with the companion reopen `858e9e80…`

`521c20ad…` is the **race** (who wins among qualifying callers). `858e9e80…` is the value-blind **gate**
(payout decoupled from outlay). **Two distinct defects, two distinct fixes.** Run-20 filed two separate
reopens for exactly this reason (D-29), and that separation is honoured here.
