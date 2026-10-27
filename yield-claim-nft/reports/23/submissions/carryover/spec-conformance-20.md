# Carryover Spec-Conformance report — originating audit 20 (carried into yield-claim-nft-23)

> **Carryover Spec-Conformance report — audit 20** (pruned copy of `yield-claim-nft/reports/20/submissions/spec-conformance.md`, taken from the run-22 pruned carryover `reports/22/submissions/carryover/spec-conformance-20.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 23). Carried at `c5ad56d` (`c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238`), run 23, branch `master`.
> ⚠ Run 20's own `submissions/qa-report.md` was **never written**; this file descends from the run-21 rebuild (field text copied verbatim from `reports/20/findings/{low,qa}/*.json`).
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **F-02-048**.
> Removed as no longer live: **none since run 22** (no ledger status changed). 
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the source changes in this run's range `0fd6bdf..c5ad56d` are the new `src/NFTBonfire.sol` (story-053), the deletion of `src/dispatchers/BalancerPoolerV2.sol` and the Balancer interfaces (story-050), and comment/NatSpec-only renames in `NudgeRatchetDelayRelease.sol`, `Uniboost.sol` and `IUniboostPooler.sol`. No retained entry's code logic changed (`NFTMinterV2.sol`, `src/hooks/**` and `src/migration/**` are unchanged), no fix landed for any of them, and no human triage disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-23 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/20/submissions/`), not from this `carryover/` folder. Original report: [`reports/20/submissions/spec-conformance.md`](../../../20/submissions/spec-conformance.md). Re-verify every location against `c5ad56d` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks are kept as history; the run-23 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 23) | Re-observed in run 23 | Contract |
> |---|---|---|---|---|---|---|---|
> | F-02-048 | ycn20f2 | `49c7408c9404f84553b678d315f699d83eb62e6723b22f3930eaaa384980fc22` | `open` | yield-claim-nft-20 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |
>
> ⚠ **Q-21 is `fix-pending` — FIX-PENDING (fix not yet landed).** `UniPoolerV2.sol` is unchanged in `0fd6bdf..c5ad56d`. The fix is a plan-side correction routed to phStaging2 (story-103/108), so a yield-claim-nft rescan that still sees Q-21 is **not** an incomplete fix. Sanitizer note: the cutover is likely complete (gate cleared 2026-10-24, block 26260804; not verified on chain by the sanitizer), so Q-21 is a candidate for human closure `wont-fix (obsolete — cutover completed)`; never auto-closed. Run-22's numbers update is kept in `qa-report-22.md` § Q-21.

<details><summary>Provenance: run-22 carryover header (kept verbatim, including the nested run-21 provenance notes)</summary>

> **Carryover Spec-Conformance report — audit 20** (pruned copy of `yield-claim-nft/reports/20/submissions/spec-conformance.md`, taken from the run-21 pruned carryover `reports/21/submissions/carryover/spec-conformance-20.md`, pruned again at run 22). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **F-02-048**.
> Removed as no longer live: **F-01-048** (`771101e7d7…`, `fixed` @ `267660b`, human-applied 2026-10-02).
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | F-02-048 | ycn20f2 | `49c7408c9404f84553b678d315f699d83eb62e6723b22f3930eaaa384980fc22` | `open` | yield-claim-nft-20 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |

<details><summary>Provenance notes from the run-21 carryover header (kept verbatim: label-collision warnings, facet and instance notes)</summary>

> Pruned copy of `yield-claim-nft/reports/20/submissions/spec-conformance.md` (commit `2bfa090`), carried at `267660b`. Retained (still `open`): **F-01-048, F-02-048**. Removed: none; cross-reference sections (L-25, Q-21, L-21 — carried in `qa-report-20.md`), "Evaluated, not escalated", summary and the run-20 carryover block not copied.
> Run-21 disposition (see `../spec-conformance.md`): F-01-048 **proposed fixed** (doc half only; `/ledger yield-claim-nft fixed 771101e7`, human applies — does **not** close L-18 `482cefc33e` or F-01-047); F-02-048 **partially addressed**, stays open until phStaging2:108 lands.
> Relative links resolve from the original report's directory. *Text below each heading is a verbatim copy; the `Carryover status` block is added by the run-21 qa-bundler.* These are faithfulness (Law-2) records: they belong to the spec-conformance channel, not the QA bundle, and are carried here only so the run-21 carryover set is complete per `ledger-reconciliation.json`.

</details>

</details>

---

## F-02-048: the BalancerWinddownPlan Pauser steps conflict with story-048, and neither document names the pool-only kill switch

- **Ledger:** `ycn20f2` · fingerprint `49c7408c9404f84553b678d315f699d83eb62e6723b22f3930eaaa384980fc22` · informational · status `open` · footgun
- **Location:** `src/dispatchers/UniPoolerV2.sol` (contract surface: no `pauser()`. `pause()` is `onlyMinter` in the base `ATokenDispatcherV2`. `dispatch` is `whenNotPaused`.)
- **Nature:** the supporting plan conflicts with the authoritative story. **The code follows the story and has no defect.** The risk falls on the phStaging2:100/103 cutover script, which is written from the plan.

### Plan text (what the cutover author will read)

> Stage 1a Tests: "Dispatch still works while the pooler is paused."
>
> Stage 2, step 7 (Configure `UniPoolerV2`): "Register with the Pauser."
>
> Stage 2, step 10: "**Retire the old pooler:** pause it and unregister it from the Pauser."
>
> (BalancerWinddownPlan.md §4)

### Story text (authoritative)

> **The plan's test "Dispatch still works while the pooler is paused" contradicts the code.** `ATokenDispatcherV2.dispatch` is `whenNotPaused`, so dispatch cannot work while the pooler is paused.
>
> **Do NOT add a `pauser()`** to make the dispatcher Pauser-registrable. … `Pauser.register` requires `IPausable(c).pauser() == Pauser`, dispatchers have none, and no prior dispatcher cutover registered one.
>
> (story-048, Concerns, implemented as Autonomous Decision 5)

### Actual behaviour

`UniPoolerV2` has no `pauser()`, so it cannot be registered with the Pauser and plan step 7 would revert. `BalancerPoolerV2` was never registered, so the "unregister" in step 10 does nothing. Pausing either pooler blocks `dispatch`, which takes down index-4 mints together with `pool()`. The failure is loud and loses no funds. The plan's underlying goal of stopping pooling while keeping mints running *can* be met with owner `incrementAuthVersion()`, which revokes every authorized pooler of `pool()` and leaves `_dispatch` untouched. **Neither the plan nor the story names that lever.**

### Recommendation

Amend the plan as follows:
- Delete the Pauser registration in Stage 2 step 7 and the unregister in step 10.
- Rewrite the Stage 1a test as "dispatch works while `pool()` is unavailable".
- Record `incrementAuthVersion()` as the pool-only kill switch.

Check this when script-auditor runs on the `unipooler-cutover` entry point.

> **Carryover status (run 21, `267660b`).** Ledger **F-02-048** · fingerprint `49c7408c9404f84553b678d315f699d83eb62e6723b22f3930eaaa384980fc22` · status **`open`** · severity `informational` · first seen `yield-claim-nft-20` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.
> PARTIALLY-ADDRESSED (contract half only); stays open; re-evaluate when phStaging2:108 lands.
