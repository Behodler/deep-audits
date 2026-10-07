# Spec-Conformance Report (Law-2 Faithfulness): yield-claim-nft, run 21

- **Run:** `yield-claim-nft-21` · regression `2bfa090..267660b` · branch `master` · HEAD `267660b96b92160a21919b043e571f2dbe51d216`
- **Stories in range:** story-051 (UniPoolerV2 audit fixes: hook guard, sync before sizing, canonical pair). Its code has landed while the story still sits in **review**, so its acceptance criteria may still move. story-048 (auto-complete) was re-graded because story-051 alters a clause it states.
  - story-051: `~/code/product-owner/stories/yield-claim-nft/review/yield-claim-nft-Balancexit/051-unipoolerv2-audit-fixes-hook-guard-sync-canonical-pair.md`
  - story-048: `~/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/048-unipoolerv2-uniswap-v2-zap-pooler.md`
  - Related plan story: phStaging2:108 (`review`), which corrects the plan-doc half of ycn20f2 / ycn20q21. It has **not** landed in the audited phoenix-phase-2-staging pin `a309040`.

## Purpose

This report covers Law 2 only: does each feature do what its `[story-NNN]` document says? It is kept separate from the QA bundle. None of the three new deviations has asset, value or availability impact, so none carries an H/M/L label. All three are informational and are reported here so the owner can see them.

## Verdicts

| Story | Verdict |
|---|---|
| story-051 | **Faithful in code.** The `HookNotSet` guard, sync-before-sizing and the canonical-pair check all landed as specified, and all three are verified (see the fix-pending proposals in `ledger-reconciliation.json`). There are **two documentation/spec deviations**: F-01-051 (the story labels the fix with the wrong finding ID) and F-02-051 (the story and NatSpec describe the donation mechanism and its beneficiary incorrectly). |
| story-048 | **Superseded in one clause.** story-051 overrides the "verbatim / identical dispatcher" clause without amending story-048 or recording a waiver (F-03-051). The override is a security improvement. |

**Law-1 override check:** no story was escalated as unsafe. All three deviations are informational and have no attack path.

---

## F-01-051: story-051, commit 267660b and the tests credit the sync fix to `ycn20l24` (L-24, wont-fix) instead of `ycn20l25` (L-25)

- **Ledger:** `ycn21f1` · fingerprint `a7a62c552d5da85932cfe214a26403ebdceb93f1559ee16b9d5011504f211b29` · informational · status `open`
- **Location:** `src/dispatchers/UniPoolerV2.sol` L461-L463 (`pool()`: `sync()` before `_reserves()`)
- **Detail:** `reports/21/findings/faithfulness/F-01-051-faithfulness-story051-finding-label-mismatch.json`

### Story text (what was directed)

> 2. **ycn20l24 — sync before sizing the zap.** `pool()` calls `pair.sync()` before reading reserves, and `quotePool()` sizes from the pair's token balances (what `sync()` would produce), so an unsynced donation to the pair can no longer strand non-dust phUSD on the pooler …
>
> (story-051, Overview item 2; the checklist repeats it as "Write a failing unit test reproducing ycn20l24")

The same label appears in the 267660b commit body ("ycn20l24: pool() syncs the pair…"), in the `test/UniPoolerV2.t.sol` section header (L1604) and in the `test/UniPoolerV2.fork.t.sol` docstring (L126).

### Actual behaviour

In the ledger, `ycn20l24` is **L-24** (`8511fd5206`, **wont-fix**), the third-party dust pre-seed grief. The sync finding is `ycn20l25` / **L-25** (`8ec2be7d59`, fix-pending). The canonical-pair change, which remediates **Q-19** (`ycn20q19`, `098396142d`), has no label anywhere in the story, the commit or the tests.

### Deviation

The labels in the spec and commit do not match the ledger, which makes reconciliation hazardous. A closer working from labels could close L-24, whose dust pre-seed half is untouched, and leave L-25 open, or do the reverse. Every misdirection fails safe or fails loud. Fix-pending entries are never suppressed, and an L-24 wrongly flipped to fixed would come back as a REGRESSION. That means no Law-1 hazard and no security label.

### Recommendation

Change story-051 and the test labels to `ycn20l25`, and cite `ycn20q19` for the canonical-pair check. Until that is done, **close entries by fingerprint only**: `/ledger yield-claim-nft fixed 8ec2be7d` (L-25) and `… fixed 09839614` (Q-19). Never use `ycn20l24`.

---

## F-02-051: the "The zap" NatSpec and story-051 misstate the donation mechanism and who benefits from it

- **Ledger:** `ycn21f2` · fingerprint `1b38e9e2dceb6e5af67e18b16ddc9d07eb565b280e8db474cb0e8f6fa9de9af3` · informational · status `open`
- **Location:** `src/dispatchers/UniPoolerV2.sol` L56-L62 (contract `@dev` "The zap")
- **Detail:** `reports/21/findings/faithfulness/F-02-051-faithfulness-story051-natspec-donation-mechanism-premise.json`
- **Relation:** this text is the NatSpec half of L-25's owner fix plan. It does **not** affect the FIX-COMPLETE verdict on L-25's code. See also Q-23 (`ycn21q23`, feeTo is live).

### Story text (what was directed)

> Uniswap V2 `swap()` computes `amountIn` from `balance - (reserve - amountOut)`, and `mint()` from `balance - reserve`. UniPoolerV2 sizes the swap from stored reserves (`getReserves()`), so any unsynced balance in the pair is credited to our swap/mint by the real pair maths …
>
> (story-051, Background)

> `sync()` sets reserves to current balances, folding any donation into the reserves (to the LPs, overwhelmingly the protocol), so the reserve-derived `s` balances again.
>
> (story-051, Implementation Notes)

The shipped NatSpec says the same: an unsynced donation "would be absorbed into our swap and LP mint", and syncing folds it "to the pair's LPs, overwhelmingly this contract's POL".

### Actual behaviour

Without a sync, the router fixes `amountOut` from the stale reserves. The donation only enlarges the `amountIn` that `swap()` computes, which loosens the K check, and `swap()`'s `_update()` then folds it into the reserves. The pooler gets nothing extra from either the swap or the mint. The stranding happens because the router's `_addLiquidity` quotes against the shifted post-swap reserves while `s` was sized on the stale ones. Whether or not the pair is synced first, the donation accrues pro rata to the LP holders that existed before our mint. Because the mainnet V2 `feeTo` is **on** (`0xf385…5f85`) and `sync()` does not touch `kLast`, `feeTo` also takes about 1/6 of the sqrt(k) growth at the next mint or burn. "Overwhelmingly this contract's POL" holds only to the extent that UniPoolerV2 custodies the pre-existing LP. The phStaging2 cutover script decides that, not this contract.

### Deviation

The deviation is in the comment and the story premise only. The code is correct, and syncing before sizing is the right fix under either description. The `quotePool` claim that a live fee "only raises our LP" was checked and holds: fork tests on the real feeTo-on pair show LP >= quote.

### Recommendation

Reword the NatSpec to: *"without a sync, a donation is folded into reserves by swap()'s _update after s was sized on the stale reserves, so addLiquidity's optimal-amount selection no longer matches the two legs. Syncing first folds it before sizing. Either way the donation accrues pro-rata to existing LP holders (and to feeTo's protocol-fee share)."* Mirror the correction in story-051's Background and Implementation Notes.

---

## F-03-051: story-051 silently supersedes story-048's "mint path kept verbatim / identical dispatcher" clause

- **Ledger:** `ycn21f3` · fingerprint `22e17d58aa306d14eacf8e36e621a9a9809995a6cf8342f50765ab65562cd4cf` · informational · status `open`
- **Location:** `src/dispatchers/UniPoolerV2.sol` L356 (`_dispatch`, first statement)
- **Detail:** `reports/21/findings/faithfulness/F-03-051-faithfulness-story051-implicit-story-waiver.json`

### Story text (what was directed)

> The mint path (`_dispatch`) is kept verbatim, so the NFT minter, the mint-debt hook and NFT index 4 all see an identical dispatcher.
>
> (story-048, Overview)

> - The `_dispatch` override copied **verbatim**: the USDS→sUSDS wrap, the PSM donation through `NudgeStreamer`, and the `try/catch` isolation.
>
> (story-048, Plan §4 Stage 1a)

> **Kept verbatim.** `_dispatch`, `_psmDonate`, `setBatchDonationSize`, … and `primeToken() == USDS`.
>
> (story-048, Technical Details)

### Actual behaviour

With comments stripped, `UniPoolerV2._dispatch` now differs from `BalancerPoolerV2._dispatch` by exactly one statement, `if (address(hook) == _defaultHook) revert UniPoolerV2__HookNotSet();`. `_psmDonate` differs only in its revert-string prefixes. Until `setHook` is called, an un-hooked UniPoolerV2 reverts every index-4 mint, where BalancerPoolerV2 would silently accrue zero debt. The contract's `@dev` header was reworded to match (story-051 Autonomous Decision 8).

### Deviation

story-051 mandates the guard, and as the later, owner-directed spec it governs, so the code does not violate Law 2. However, story-051 never says it waives story-048's clause, and story-048 still asserts it. Anyone grading against story-048 alone would report a false deviation, or might "restore" verbatim parity and reopen L-21. The divergence is intended and safer, so Law 1 is not engaged.

### Recommendation

Add a one-line supersession note to story-048 or story-051: *"the `_dispatch` verbatim clause is amended by story-051: the hook-not-set guard is the only behavioural difference."* No code change is needed. Move story-051 out of `review/` once it is accepted.

---

## Carried-over run-20 faithfulness records

### F-01-048 (`ycn20f1`, `771101e7d7…`): **proposed fixed, awaiting a human decision**

- **Status:** `open` (unchanged). The ledger now records `proposedStatus: fixed`, `proposedCommit: 267660b`, `proposedAt: yield-claim-nft-21`.
- **Run-21 verdict:** ADDRESSED (documentation only; code unchanged). The `DonationSkipped` `@notice` and the `_dispatch` `@notice` no longer list "dust". Both now state that a zero-`gemAmt` sweep is a silent no-op that emits no event, and the contract Donation section and the `_psmDonate` comments agree with them.
- **To apply:** `/ledger yield-claim-nft fixed 771101e7`
- **Caveat:** this closes the documentation half only. **L-18** (`482cefc33e`), the code-level event silence including its UniPoolerV2 `_psmDonate` second location, stays open. F-01-047 (BalancerPoolerV2) is deliberately left untouched under story-050.
- **Original report:** [reports/20/submissions/spec-conformance.md § F-01-048](../../20/submissions/spec-conformance.md)

### F-02-048 (`ycn20f2`, `49c7408c94…`): **still open (partially addressed)**

- **Status:** `open`, `lastSeenRun` set to `yield-claim-nft-21`.
- **Run-21 verdict:** PARTIALLY-ADDRESSED. The contract half has landed: the UniPoolerV2 "Kill switches" NatSpec names `incrementAuthVersion()` as the pool-only switch and states that `pause()` is `onlyMinter` and blocks both dispatch and `pool()`. The finding's actual subject is the phStaging2 `docs/BalancerWinddownPlan.md`, which at pin `a309040` still says "Dispatch still works while the pooler is paused" (L307), "Register with the Pauser" (L382) and "pause it and unregister it from the Pauser" (L385).
- **Next step:** re-evaluate once phStaging2:108 (currently `review`, Review Status ISSUES_FOUND) lands in the pin.
- **Original report:** [reports/20/submissions/spec-conformance.md § F-02-048](../../20/submissions/spec-conformance.md)

### Other faithfulness records still open in the ledger (not re-graded this run)

The code these records cover is outside the `2bfa090..267660b` diff, so they were not re-graded. Not being re-observed does **not** mean they are fixed, and their statuses are unchanged.

| Record | Fingerprint | Contract | Original report |
|---|---|---|---|
| F-01-043 | `6753c76b07` | NudgeRatchetDelayRelease | `reports/15/submissions/spec-conformance.md` |
| F-01-045 | `25212e80ee` | PromotionUniV2_Eth | `reports/18/submissions/spec-conformance.md` |
| F-01-047 | `5d6538f76f` | BalancerPoolerV2 | `reports/19/submissions/spec-conformance.md` |
| F-02-046 | `26baeb3e77` | NudgeRatchet | `reports/19/submissions/spec-conformance.md` |
| F-03-046 | `38151cebd7` | NudgeRatchetDelayRelease | `reports/19/submissions/spec-conformance.md` |

---

## Summary

| ID | issueId | Story | Kind | Severity | Status |
|---|---|---|---|---|---|
| F-01-051 | ycn21f1 | story-051 | finding-label mismatch (ledger traceability) | informational | open (new) |
| F-02-051 | ycn21f2 | story-051 | mechanism/beneficiary premise in NatSpec and story | informational | open (new) |
| F-03-051 | ycn21f3 | story-048 → story-051 | implicit supersession of the verbatim clause | informational | open (new) |
| F-01-048 | ycn20f1 | story-048 | documentation deviation | informational | open, **proposed fixed** (human applies) |
| F-02-048 | ycn20f2 | story-048 | plan/story conflict (Pauser steps) | informational | open (partially addressed) |
