<!--
ID: 521c20ad (ledger fingerprint — this record mints NO new finding ID)
C4 Submission Metadata — ⚠ EXPIRED-CLOSURE / LEDGER-REOPEN PROPOSAL
Title: MEV / first-claimer front-run of the winner-take-all nudge pot — CLOSURE RATIONALE EXPIRED
       (ledger M-01, currently status=fixed, owner-triaged 2026-06-09)
Record kind: LEDGER-REOPEN-PROPOSAL. NOT a new finding. NOT a code regression.
Ledger fingerprint: 521c20ad48b388ea37eea906fb5e5495885952fcd944a3377fee24f274434d60
Current ledger status: fixed  (⚠ OWNER-SIGNED TRIAGE 2026-06-09 AFFECTED)
Proposed status: reopen — PROPOSAL ONLY. D-09 forbids an agent flipping the status.
Severity AT HEAD: Medium  (assessed on HEAD's evidence, not inherited)
Contract: src/BatchNFTMinter.sol  (batchMint)
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L285-L291
PoC Files: workspace/phoenix-nft-staking/test/PoC_NudgeLineage_MevFrontrunNudge.t.sol (2/2 PASS @0d1a0b2)
           workspace/phoenix-nft-staking/test/PoC_NudgeLineage_M01PriceInflation.t.sol (2/2 PASS @0d1a0b2)
Replay verdict: STILL-LIVE, 2/2
Run: phoenix-nft-staking-20 @ 0d1a0b2
Provenance: CLASS-010 (classifier label "M-09" WITHDRAWN by orchestrator ruling R-2)
Coupled to: ledger L-05 (990d8c37…, wont-fix) — the closure depends on a mitigation L-05 declares default-off.
⚠ LABEL COLLISION: this record concerns LEDGER M-01 = 521c20ad…. Run-20's own M-01 is
fcaca002… (BatchNFTMinter step-10 sweep) and is a DIFFERENT finding. A second ledger entry,
b58b172e… (NFTStakerDepletion rate drift), also carries the label M-01.
Always disambiguate by fingerprint, never by label.
-->

## Finding description and impact

> ### ⚠ Read this framing first
>
> **The code did not regress. The reasoning that closed this finding expired.**
>
> This record asserts an **invalid closure**, not a code regression. No path got worse between the 2026-06-09 triage and HEAD, and the first of the four premises the closure rests on still holds.
>
> **story-014's fix is intact, and is PROVEN intact.** The minter and `dispatcherIndex` are owner-pinned ([`BatchNFTMinter.sol#L101`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L101), resolved at [`#L315-L323`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L315-L323)), confirmed at HEAD by `test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED`. **Do not use this report to argue that the pinning should be revisited.**
>
> Filing this as a regression would send a reader to restore a patch that already works. It is not that.
>
> Stated plainly: **the economic object the owner accepted on 2026-06-09 is not the economic object that exists at HEAD.** The closure accepted *"an ordinary gas auction among real participants."* With premises 2 and 3 gone, it is a gas auction over a **pure-profit pot a bot can realise without ever intending to participate**.

### The four premises, re-checked against HEAD

| # | Premise the 2026-06-09 `fixed` rests on | Status at HEAD |
|---|---|---|
| **P1** | A free claim is impossible — the minter and dispatcher are owner-pinned. | **HOLDS ✅** — same evidence as the companion reopen record (`858e9e80…`), leg 1. |
| **P2** | The pot stays below the cost of `nudgeSize` mints. | **✗ DEGRADED / UNENFORCED — and self-triggering.** |
| **P3** | The minted NFTs have no realisable path — no secondary market, so a pure MEV bot cannot recoup. | **✗ DEAD.** |
| **P4** | The `minReward` slippage floor fully closes the harm. | **✗ CONDITIONAL**, on a separate accepted `wont-fix`. |

**P2 — self-triggering, and now triggered.** The ledger entry states its own trigger condition, in its own words:

> *"if the yield funnel ever lets the pot exceed the cost of `nudgeSize` mints, pure-profit MEV returns."*

That condition is now executed, at **9.5×** and **20,000×** profit ratios (see the companion record `858e9e80…`). The premise was recorded as *"owner-operational, not code-enforced"*, and source confirms it: `nudgeSize` ([`#L106`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L106)) constrains a **count**, never a value. Nothing in the contract holds P2 up.

**P3 — dead, and this entry's own re-triage predicted it.** The run-16 re-triage of this very ledger entry warned: *"the acceptance invariant does NOT bound loss if the minted NFTs carry realisable value."* At HEAD they do. `NFTMinterV2` is a plain `ERC1155Supply` with no transfer restriction; ratchet-minted NFTs stake without restriction and claimed **12.58 phUSD in 30 days** (`test_M01_NudgeMintedNFTsAreImmediatelyRealizable`). On the ratchet path the mint is free. A bot with no interest in the protocol can now recoup — which is precisely the case P3 excluded.

**P4 — conditional on an accepted `wont-fix`, and narrower than claimed.** The closure calls the harm *"fully closed by the `minReward` slippage floor."* The floor only fires if the caller sets it, and its default is 0 — the state of affairs accepted under **ledger L-05** (`990d8c37…`, `wont-fix`). The contract itself says so, at [`#L287-L291`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L287-L291):

> ```
> /// `0` = no floor. NOTE: this does NOT
> ///  stop a front-runner from winning the pot —
> ///  whoever qualifies first still takes the entire
> ///  balance-based payout; the floor only stops the
> ///  loser from minting for less than they declared.
> ```

The mitigation the closure called *"fully closed"* is documented **in-contract** as partial. Worse, **story-022 widened the surface it has to cover** — `minRewards` went from a scalar to a per-token array, with a caller-supplied token list, under an explicit *"Array hygiene is the caller's responsibility"* disclaimer ([`#L258-L266`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L258-L266)) — **without L-05 being re-triaged**.

The un-floored path is reproduced end to end: an honest user mints **5 real NFTs**, pays **5,947.05**, and receives **0** (`test_M01_searcherFrontrunsHonestNudgeClaimant`).

> **P4 bounded fairly.** The floor is not worthless. `test_M01_minRewardsFloorDoesNotStopTheFrontRun` shows that with a *correct* floor set, the loser's batch reverts and their capital **is** spared. The floor does real work. It is **narrower than "fully closed", not absent** — it protects the loser's outlay, it does not protect the pot.
>
> **Unowned obligation.** No party has been identified as responsible for verifying that the front-end supplies a non-zero, pot-based `minRewards[]`. Until an owner for that verification is named, P4 has no backing. Tracked as `WATCH-20-minrewards-frontend-obligation-unowned`. Ledger L-05 and this entry lean on each other and **neither can be read alone**.

### Attack path

1. The pot exceeds the cost of a qualifying batch. Nothing in code enforces the margin (see `858e9e80…`).
2. An honest user assembles and submits a legitimate nudge-qualifying batch.
3. A searcher front-runs it with the minimum qualifying batch and takes the entire balance-based payout.
4. The honest user's transaction still mints — they pay full price and receive **0** reward.
5. The searcher's minted NFTs are immediately realisable: unrestricted `ERC1155Supply`, stakeable for phUSD, and free to mint on the ratchet path.

### Impact

**Direct.** An honest user who mints 5 real NFTs and pays **5,947.05** receives **0**, while a searcher with an outlay of **5,256.33** takes the **50,000** pot. That is the exact harm the 2026-06-09 closure said had been eliminated.

**Second leg — existing stakers.** The price-inflation lineage measures a rate increase of **+252 bps** and a runway reduction of **−780,595 s (−9 days)** per 5-mint round, compounding on the second round (`test_M01_NudgeInflatesPriceShortensRunway`). Stakers who never touched the nudge lose 9 days of runway per round.

### Severity at HEAD, and honest bounds

**Medium at HEAD.** Assessed on HEAD's evidence, not inherited — it happens to land back at Medium.

- **Not High.** No principal theft. No third-party deposits at risk. Zero present on-chain exposure. Front-running a public incentive pot is a classic MEV shape rather than direct asset compromise.
- **Not Low.** The honest user demonstrably pays real money and receives zero, the staker-runway impact is measurable, and **three of the four premises the owner's `fixed` rests on no longer support it**.

> **⚠ Bound this prominently.** D-22's read-only mainnet reads at block 25572875 show **zero present exposure**: `RatchetBatchNFTMinter` (`0x81896F48…`) holds 0 USDC, 0 USDS and 0 ETH; archive reads confirm it was also 0 at the block before the fix, so **no historical loss occurred via this path**; `NudgeRatchet.batchMinter()` has been repointed to `0x86866e01…`. **No principal theft appears in any of the 11 replay tests. These PoCs prove the mechanic, not funds currently at risk.**

### Why this must not be double-counted

This record mints **no new finding**. The mechanic is already filed live this run as **M-01** (`fcaca002…`), **M-02** and **F-20-07** (`a7dffb34…`, spec-conformance track; record at `findings/faithfulness/F-20-07-watch-19-re-derivation-one-of-the-two.json`; no `L-xx` label per ruling R-4). Per orchestrator ruling R-2 it deliberately carries no `M-nn` label — publishing it as `M-09` alongside the new Mediums would make the report read as nine Mediums for roughly seven distinct defects. What it carries is the **ledger-side consequence**: an owner-signed `fixed` whose supporting premises no longer hold.

### Proof of concept

```bash
forge test --match-path test/PoC_NudgeLineage_MevFrontrunNudge.t.sol -vvv  # 2/2 PASS @0d1a0b2
forge test --match-path test/PoC_NudgeLineage_M01PriceInflation.t.sol -vvv # 2/2 PASS @0d1a0b2
```

Replay verdict: **STILL-LIVE, 2/2**.

- `test_M01_searcherFrontrunsHonestNudgeClaimant` — the un-floored front-run; honest user pays 5,947.05, receives 0.
- `test_M01_minRewardsFloorDoesNotStopTheFrontRun` — the floor's real but narrow effect (P4 bound).
- `test_M01_NudgeMintedNFTsAreImmediatelyRealizable` — 12.58 phUSD in 30 days (P3 dead).
- `test_M01_NudgeInflatesPriceShortensRunway` — +252 bps, −9 days runway per round.

Full replay narrative: `reports/phoenix-nft-staking-20/nudge-lineage-poc-replay.md`.

## Recommended mitigation steps

### Primary recommendation — ledger disposition (this is a proposal only)

Under D-09 an agent may not flip a ledger status, and this entry carries an **owner-signed 2026-06-09 triage**. The proposal is:

> **REOPEN** on fingerprint `521c20ad…`, at Medium-at-HEAD. P1 holds and the owner-pinning must not be disturbed.

**alternativeIfYouDisagree.** If the operator judges the residual still acceptable, re-close it with a rationale **written against HEAD's premises** — one that does not rest on P2 (unenforced and now triggered), P3 (dead), or P4 (conditional on the accepted `wont-fix` at ledger L-05). Do **not** leave it `fixed` on a rationale whose P2/P3/P4 legs this run's own PoCs falsify. `fixed` asserts elimination; what happened here was dismissal, on grounds that have since lapsed.

### Supporting actions

1. **Re-triage ledger L-05** (`990d8c37…`). It was accepted as `wont-fix` before story-022 widened `minRewards` from a scalar to a caller-supplied per-token array. This entry's closure depends on L-05's mitigation being effective; L-05's acceptance depends on the harm being small. Neither can be read alone.
2. **Name an owner for the front-end obligation.** Someone must be accountable for the UI supplying a non-zero, pot-based `minRewards[]`, or P4 has no backing at all (`WATCH-20-minrewards-frontend-obligation-unowned`).

### Code-level remediation, if the residual is to be closed

**No validated patch is offered here, and none should be inferred.** The property to establish is the
same one the companion record (`858e9e80…`) identifies: relate the payout to the caller's realised
spend rather than to a bare count, so that winning the race is not, by itself, profitable.

> ⚠ **Unvalidated direction — do not implement as written.** This is a property to establish, not a
> reviewed patch. In particular, `totalPaid` is **not** usable as the basis without restructuring:
> it is `batchMint`'s named return, assigned only at step 10 (`:384`/`:386`), *after* `_payRewards`
> runs at `:378`. Any cap expressed against `totalPaid` at the payout site reads **zero** and would
> silently disable the nudge entirely. `totalPaid` is also floored at 0 on a net-positive call
> (run-20 Q-04, `47f2dc3a…`), is manipulable through the step-10 sweep filed as run-20 M-01
> (`fcaca002…`), and under-reports true dispatcher cost whenever the contract's own balance funds an
> under-funded batch (run-20 M-07). Whatever basis is chosen must be derived and PoC'd before it is
> shipped.

A caller-set `minRewards` floor is a useful complement — it protects the loser's outlay — but it is not a substitute, by the contract's own admission at [`#L287-L291`](https://github.com/Behodler/phoenix-nft-staking/blob/main/src/BatchNFTMinter.sol#L287-L291).
