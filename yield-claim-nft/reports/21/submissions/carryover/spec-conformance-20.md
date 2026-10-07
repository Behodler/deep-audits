# Carryover Spec-Conformance Report — originating audit 20 (carried into yield-claim-nft-21)

> Pruned copy of `yield-claim-nft/reports/20/submissions/spec-conformance.md` (commit `2bfa090`), carried at `267660b`. Retained (still `open`): **F-01-048, F-02-048**. Removed: none; cross-reference sections (L-25, Q-21, L-21 — carried in `qa-report-20.md`), "Evaluated, not escalated", summary and the run-20 carryover block not copied.
> Run-21 disposition (see `../spec-conformance.md`): F-01-048 **proposed fixed** (doc half only; `/ledger yield-claim-nft fixed 771101e7`, human applies — does **not** close L-18 `482cefc33e` or F-01-047); F-02-048 **partially addressed**, stays open until phStaging2:108 lands.
> Relative links resolve from the original report's directory. *Text below each heading is a verbatim copy; the `Carryover status` block is added by the run-21 qa-bundler.* These are faithfulness (Law-2) records: they belong to the spec-conformance channel, not the QA bundle, and are carried here only so the run-21 carryover set is complete per `ledger-reconciliation.json`.

---

## F-01-048: `UniPoolerV2` inherits F-01-047 verbatim. `DonationSkipped` and the `_dispatch` NatSpec still list "dust", but the dust branch is a silent no-op

- **Ledger:** `ycn20f1` · fingerprint `771101e7d7e664ff84c4633629744ba385dc7497405a081ce5be48eed925f23d` · informational · status `open`
- **Location:** `src/dispatchers/UniPoolerV2.sol` L129-L131 (`DonationSkipped` NatSpec) and L284-L286 (`_dispatch` NatSpec). The dust branch itself is in `_psmDonate`, L349-L353.
- **Relation:** a new-contract instance of **F-01-047** (`5d6538f7…`, open, `BalancerPoolerV2`). It is filed as its own entry because story-050 deletes `BalancerPoolerV2`. If it were folded in, F-01-047 would close as code-removed while the same wrong documentation lives on in the replacement. Related monitoring gap: **L-18** (`482cefc3…`, open), which this run gains a UniPoolerV2 second location.

### Story text (what was directed)

> **Kept verbatim.** `_dispatch`, `_psmDonate`, `setBatchDonationSize`, … `rescueERC20` (also the LP exit), and `primeToken() == USDS`. Keep all events, errors and storage semantics the dispatch suite relies on.
>
> (story-048, Technical Details)

### Actual behaviour

Because the code was copied verbatim, the run-19 documentation defect was copied with it:

```solidity
/// @notice Emitted when a donation attempt is silently skipped (PSM outage / fee spike /
///         dust). `usdsParked` USDS stays on the contract for the next dispatch to retry.
event DonationSkipped(uint256 usdsParked);                                   // L129-L131
...
///      so any PSM failure (outage, fee spike, empty reserve, dust) parks the USDS instead   // L285
```

`_psmDonate` turns a dust sweep (`gemAmt == 0`) into a clean no-op (L349-L353: *"a dust-sized sweep whose gemAmt floors to zero must short-circuit to a clean no-op here rather than propagate a revert into the caller's catch"*). No revert ever reaches the `catch`, so `DonationSkipped` is **never** emitted for dust. The new contract-level NatSpec (L26-L32) leaves dust off its failure list, so the contract now contradicts itself.

### Deviation

Documented behaviour diverges from shipped behaviour. The code is correct. An operator who monitors `DonationSkipped` as the dust signal will never see it fire.

### Recommendation

Remove "dust" from the `DonationSkipped` and `_dispatch` NatSpec. The change touches comments only, so it does not breach story-048's verbatim-code clause.

> **Carryover status (run 21, `267660b`).** Ledger **F-01-048** · fingerprint `771101e7d7e664ff84c4633629744ba385dc7497405a081ce5be48eed925f23d` · status **`open`** · severity `informational` · first seen `yield-claim-nft-20` · last seen `yield-claim-nft-20` · re-observed by run-21 inputs: **yes**.
> Proposed `fixed` at 267660b (doc half only). Human applies: `/ledger yield-claim-nft fixed 771101e7`.

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
