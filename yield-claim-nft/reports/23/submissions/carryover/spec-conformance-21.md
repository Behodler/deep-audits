# Carryover Spec-Conformance report — originating audit 21 (carried into yield-claim-nft-23)

> **Carryover Spec-Conformance report — audit 21** (pruned copy of `yield-claim-nft/reports/21/submissions/spec-conformance.md`, taken from the run-22 pruned carryover `reports/22/submissions/carryover/spec-conformance-21.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 23). Carried at `c5ad56d` (`c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238`), run 23, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **F-01-051, F-02-051, F-03-051**.
> Removed as no longer live: **none since run 22** (no ledger status changed). 
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the source changes in this run's range `0fd6bdf..c5ad56d` are the new `src/NFTBonfire.sol` (story-053), the deletion of `src/dispatchers/BalancerPoolerV2.sol` and the Balancer interfaces (story-050), and comment/NatSpec-only renames in `NudgeRatchetDelayRelease.sol`, `Uniboost.sol` and `IUniboostPooler.sol`. No retained entry's code logic changed (`NFTMinterV2.sol`, `src/hooks/**` and `src/migration/**` are unchanged), no fix landed for any of them, and no human triage disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-23 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/21/submissions/`), not from this `carryover/` folder. Original report: [`reports/21/submissions/spec-conformance.md`](../../../21/submissions/spec-conformance.md). Re-verify every location against `c5ad56d` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks are kept as history; the run-23 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 23) | Re-observed in run 23 | Contract |
> |---|---|---|---|---|---|---|---|
> | F-01-051 | ycn21f1 | `a7a62c552d5da85932cfe214a26403ebdceb93f1559ee16b9d5011504f211b29` | `open` | yield-claim-nft-21 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |
> | F-02-051 | ycn21f2 | `1b38e9e2dceb6e5af67e18b16ddc9d07eb565b280e8db474cb0e8f6fa9de9af3` | `open` | yield-claim-nft-21 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |
> | F-03-051 | ycn21f3 | `22e17d58aa306d14eacf8e36e621a9a9809995a6cf8342f50765ab65562cd4cf` | `open` | yield-claim-nft-21 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |

<details><summary>Provenance: run-22 carryover header (kept verbatim, including the nested run-21 provenance notes)</summary>

> **Carryover Spec-Conformance report — audit 21** (pruned copy of `yield-claim-nft/reports/21/submissions/spec-conformance.md` (originating commit `267660b`). Faithfulness (Law-2) records belong to the spec-conformance channel, not the QA bundle). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **F-01-051, F-02-051, F-03-051**.
> Removed as no longer live: none of the run's new records (F-01-051, F-02-051, F-03-051 all still `open`). Not copied: header/Purpose/Verdicts/Summary and "Carried-over run-20 faithfulness records" (F-01-048 since `fixed`; F-02-048 carried in `spec-conformance-20.md`; the older open records are carried in their own files).
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | F-01-051 | ycn21f1 | `a7a62c552d5da85932cfe214a26403ebdceb93f1559ee16b9d5011504f211b29` | `open` | yield-claim-nft-21 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |
> | F-02-051 | ycn21f2 | `1b38e9e2dceb6e5af67e18b16ddc9d07eb565b280e8db474cb0e8f6fa9de9af3` | `open` | yield-claim-nft-21 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |
> | F-03-051 | ycn21f3 | `22e17d58aa306d14eacf8e36e621a9a9809995a6cf8342f50765ab65562cd4cf` | `open` | yield-claim-nft-21 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |

</details>

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
