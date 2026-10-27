# Spec-Conformance Report (Law-2 Faithfulness): yield-claim-nft, run 23

- **Run:** `yield-claim-nft-23` · regression `0fd6bdf..c5ad56d` · branch `master` · HEAD `c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238`
- **Stories in range** (each resolved by globbing the whole `~/code/product-owner/stories/yield-claim-nft` tree for `<NNN>-*.md` / `<NNN>.*-*.md`; one hit each):

| Story | State | Document | Commits |
|---|---|---|---|
| story-050: delete Balancer interfaces post wind-down | **auto-complete** (final, equivalent to `complete`) | `~/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/050-delete-balancer-interfaces-post-winddown.md` | `6d5168d` (merged via `18be7c3`) |
| story-053: NFT bonfire, burn for antimatter | **auto-complete** (final, equivalent to `complete`) | `~/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-nft-bonfire/053-nft-bonfire-burn-for-antimatter.md` | `cacd040` (RED), `c5ad56d` (GREEN) |

- **Contracts:** `src/NFTBonfire.sol` (new, story-053); `src/dispatchers/BalancerPoolerV2.sol`, `src/interfaces/balancer/*`, `test/BalancerPoolerV2.t.sol`, `MockERC4626Wrapper.sol` deleted (story-050); comment-only edits to `NudgeRatchetDelayRelease.sol`, `Uniboost.sol`, `IUniboostPooler.sol` (story-050).
- **Sources:** `reports/23/faithfulness-findings.json` (per-criterion verdicts), `reports/23/findings/faithfulness/F-02-053-faithfulness-story053-checklist-not-literally-true.json`, `reports/23/story-intents.md`, and the two story documents above (read directly for every quotation below).

## Purpose

This report covers Law 2 only: does each feature do what its `[story-NNN]` document says? It is kept separate from the QA bundle (`qa-report.md`). The run produced **one** ledger-tracked faithfulness record (**F-02-053**, informational) and **one** cross-reference (**F-01-053**), which points at **L-29** in `qa-report.md` and is not filed separately. No deviation has asset or value impact that would need an H/M label, and no story was escalated as unsafe under Law 1.

## Verdict

| Story | Verdict |
|---|---|
| story-050 | **Conformant: 8/8 criteria pass, 0 deviations.** The gate was cleared early by a knowing owner decision (see [§ story-050 gate note](#story-050-gate-note-cleared-ahead-of-30-nov-not-filed)). |
| story-053 | **The contract conforms to every behavioural criterion (14/15 pass).** The one failing criterion is a ticked process checkbox (F-02-053). One protection the story describes is inactive by default, which is a gap in the story text rather than the code (F-01-053 → L-29). |

---

## F-02-053: story-053's ticked checklist item "`forge fmt --check`, `forge build --sizes` and `forge test -vvv` all pass (the whole suite)" is not true repo-wide

- **Ledger:** `ycn23f2` · fingerprint `67ed3c0bc203efd7b86b570f665a41759c81772a1fc1a6f39093d2cf94645498` · **Informational** · status `open` (new this run) · branch `master`
- **Location:** repo-wide (CI). No contract location.
- **Detail:** `reports/23/findings/faithfulness/F-02-053-faithfulness-story053-checklist-not-literally-true.json`
- **Cross-ref:** none. No security half, so no paired H/M/L label.

### Story text (what was directed)

> - CI runs `forge fmt --check`, `forge build --sizes` and `forge test -vvv`. All three must pass.
>
> (story-053 L45, Toolchain)

> - [x] `forge fmt --check`, `forge build --sizes` and `forge test -vvv` all pass (the whole suite, not just the new file)
>
> (story-053 L123, Checklist; **ticked**)

### Actual behaviour

- `forge fmt --check` on the story's own files (`src/NFTBonfire.sol`, `test/NFTBonfire.t.sol`) exits 0. Re-checked read-only at `c5ad56d`.
- Repo-wide, `forge fmt --check` reports **10** `Diff in` files, all of which predate the story: `src/dispatchers/{NudgeRatchet,NudgeRatchetDelayRelease,PromotionUniV2_Eth,Uniboost}.sol`, `src/interfaces/uniswap/IUniswapV2Router02.sol`, `test/{BalancerPoolerMintDebtHook,NudgeRatchetDelayRelease,PromotionUniV2_Eth}.t.sol`, `test/integration/NudgeStreamerDonorIntegration.t.sol` and `test/mocks/MockERC4626.sol` (list per story-053 review, L199).
- The story's own review records that `forge build --sizes` fails EIP-170 on the pre-existing `PromotionUniV2_Eth` (24,770 B, margin -194). CI sets `FOUNDRY_PROFILE: ci`, but `foundry.toml` defines only `[profile.default]`, so no optimizer runs (story-053 L161, L200). **This size claim was not re-run in this audit**, because build output would be written into the read-only submodule tree. It rests on the story's own review.
- `forge test` passes 658/658 with `RPC_MAINNET` sourced, according to the story (L162).

### Deviation

A ticked acceptance criterion is false repo-wide, so the CI job the story describes would fail on `master`. The executor disclosed this openly (story-053 Autonomous Decision 2, L160-164), and the review carried it forward as a non-blocking `[medium]` (L256) before the story was auto-completed. Contract behaviour is unaffected. EIP-170 is suspended deliberately only for stable-staker. No equivalent suspension is recorded for yield-claim-nft, so the size failure stays in this report.

### Recommended follow-up

Write a housekeeping story (see [§ Missing follow-up stories](#missing-follow-up-stories-and-the-obligations-they-must-carry), item 4): run `forge fmt` on the drifted files and add a `[profile.ci]` with `optimizer = true` so that `PromotionUniV2_Eth` fits EIP-170 under CI. The story notes that reformatting deployed-source contracts changes source hashes against verified commits (L163). The housekeeping story should therefore choose explicitly between a formatter exclusion and a reformat.

---

## F-01-053 (cross-reference only, not a ledger entry): the `maxPayout` idle-period protection is off by default, and pause does not stop accrual

**Filed as L-29** (`ycn23l29`, fingerprint `589c642bd003b3c93411625096cd88a96b411ee134284d4b60cae2bd70f1ba6c`, Low, borderline Low/Medium) in [`qa-report.md` § L-29](./qa-report.md#l-29-nftbonfire-maxpayout-defaults-to-unlimited-and-pause-does-not-stop-accrual-so-an-idle-stretch-becomes-one-large-mint-for-the-first-burner-and-a-reactive-cap-is-front-runnable). It shares a root with CODE-001 and ECON-001 and is counted once there. It is recorded here only so that the Law-2 view shows the story's own internal gap.

### Story text (what was directed)

> - `maxPayout` therefore **caps the pot itself**. Accrual above the cap is never paid out: a burn pays at most `maxPayout`, and the pot resets to zero regardless. This is the accrual cap that prevents a long idle period from turning into one large mint.
>
> (story-053 L77, Accrual semantics)

> `uint256 public maxPayout;       // cap on accrued pot / per-burn payout; 0 = unlimited`
>
> (story-053 L57, Contract shape)

> - **Pause does not freeze accrual.** Only a rate of 0 stops accrual. Pause is the emergency stop on burns; the rate is the economic lever.
>
> (story-053 L141)

> - phStaging2: deploying NFTBonfire, `setAuthorizedBurner`, `setApprovedMinter`, Pauser registration, setting the initial rate, the submodule pin bump. This is a follow-up story in phStaging2, ordered after phStaging2:116.
>
> (story-053 L128, Out of Scope)

### Actual behaviour

The code matches the letter of the story. `maxPayout` defaults to 0 ([NFTBonfire.sol#L30-L32](https://github.com/Behodler/yield-claim-nft/blob/c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238/src/NFTBonfire.sol#L30-L32)), and `pendingPayout()` returns raw accrual when the cap is 0 ([L114-L121](https://github.com/Behodler/yield-claim-nft/blob/c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238/src/NFTBonfire.sol#L114-L121)). `pause()` does not checkpoint or stop accrual ([L143-L156](https://github.com/Behodler/yield-claim-nft/blob/c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238/src/NFTBonfire.sol#L143-L156)). Until the owner sets the cap, the safeguard the story names does nothing. Lowering the cap after a pot has built up is front-runnable unless burns are stopped first.

### Deviation (in the story, not the code)

The story names the cap as *the* protection against an idle period turning into one large mint, but leaves it off by default. It hands "setting the initial rate" to a follow-up deploy story without saying that `setMaxPayout` must come first, and that follow-up story does not exist yet. **Law-1 assessment:** no escalation. Total emission is bounded by ∫`ratePerDay`·dt. `setRatePerDay` checkpoints before every change, so time before the rate was first enabled is never paid out. The uncapped default concentrates the budgeted dilution on one burner but does not enlarge it. Severity and the safe-configuration sequence are in L-29. The obligations it creates are listed under the deploy story in [§ Missing follow-up stories](#missing-follow-up-stories-and-the-obligations-they-must-carry).

---

## Conformance summary per story

### story-053 (auto-complete): NFTBonfire

Source: `reports/23/faithfulness-findings.json → criteria.story-053`. Line numbers refer to `src/NFTBonfire.sol` at `c5ad56d`.

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| 1 | Constructor stores immutables and sets owner, `lastUpdate == block.timestamp`, `ratePerDay == 0`, `maxPayout == 0`; reverts `NFTBonfire__ZeroAddress` on a zero `nftMinter_` / `antimatter_` | PASS | L83-88; `test_constructor_*` |
| 2 | `burn` reverts `NFTBonfire__BurningDisabled` while `ratePerDay == 0` | PASS | L98 |
| 3 | Raw accrual = `accruedStored + (now-lastUpdate)*ratePerDay/1 days` (floor); `pendingPayout` capped at `maxPayout` when non-zero | PASS | L118-121; linear, floor and fuzz tests |
| 4 | `burn`: `whenNotPaused` + `nonReentrant`; `PayoutBelowMinimum` check; effects, then `nftMinter.burn(msg.sender, tokenId, 1)`, mint only if payout > 0, emit, return | PASS | L97-112, strict CEI order |
| 5 | The holder is always `msg.sender`; no function takes a holder/from parameter | PASS | L106 is the only burn call; `test_burn_cannotBurnAnotherHoldersToken`, `test_noHolderParameter_burnSelectorIsTwoUints` |
| 6 | A second burn in the same block pays 0 with no `mint(…,0)`; reverts when `minPayout > 0` | PASS | L107; `test_burn_secondBurnSameBlock*` |
| 7 | `maxPayout` is unlimited by default; with a cap, payout is capped, the excess forfeited and the pot reset to 0 | PASS | L120, L103; `test_maxPayout_*`. The default is the subject of F-01-053 / L-29 |
| 8 | Checkpoint before any parameter change (capped at the current max) | PASS | L128/L136 `_checkpoint()`; L159-162; `test_setMaxPayout_checkpointsCappedAtOldMax`, `test_setMaxPayout_loweringCapsStoredPot`. The GREEN commit flipped the RED assertion to match the spec; story Decision 3 discloses this |
| 9 | Owner-only setters (`OwnableUnauthorizedAccount`); events carry old and new values | PASS | L127-146 |
| 10 | Pauser pattern (`NFTBonfire__NotPauser`, `PauserChanged`, `_pause`/`_unpause`, admin setters callable while paused, `pauser()` satisfies `IPausable`) | PASS | L74-77, L143-156. The pauser is unset at deploy: see Q-27 |
| 11 | Accrual continues through pause | PASS | `test_pause_accrualContinuesAndUnpauseRestoresBurn`. This behaviour is part of F-01-053 / L-29 |
| 12 | Reentrancy via mint fails | PASS | `nonReentrant` + CEI; `test_burn_reentrancyBlocked` |
| 13 | All token IDs are equal; an unauthorised burner gets a string revert | PASS | `test_burn_differentTokenIdsSharePot`, `test_burn_revertsWhenNotAuthorisedBurner`. Because every ID pays the same pot, the cheapest mint route sets the ticket price: see L-30 |
| 14 | `NFTBonfire__*` custom errors, NatSpec on every public item, `^0.8.20`, `IMintable` (no antimatter submodule), no existing contract modified | PASS | `git diff 18be7c3..c5ad56d` touches only `src/NFTBonfire.sol` and `test/NFTBonfire.t.sol` |
| 15 | `fmt --check` / `build --sizes` / `test` pass across the whole suite | **DEVIATION** | **F-02-053** |

**Law-1 story review:** no unsafe-story escalation. The story knowingly accepts front-running of the winner-takes-all pot (L100, L136), and `minPayout` fully protects an honest burner, because a reverted burn keeps the NFT. The uncapped default and accrual during pause are also knowingly accepted (L57, L141). Emission is bounded by rate × time, so both only concentrate the budget. The core invariant, that only the caller's own NFT can be burned, holds.

### story-050 (auto-complete): delete Balancer interfaces post wind-down

Source: `reports/23/faithfulness-findings.json → criteria.story-050`.

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| 1 | Gate: `GATE CLEARED: winddown-confirmed` line present; phStaging2:106 terminal; 052 terminal and its escrow present | PASS | See [§ story-050 gate note](#story-050-gate-note-cleared-ahead-of-30-nov-not-filed) |
| 2 | The Balancer-importer grep returns nothing (exit 1) after deletion | PASS | Re-run at `c5ad56d`: no output, exit 1 |
| 3 | Delete `src/interfaces/balancer/*`, `BalancerPoolerV2.sol`, `test/BalancerPoolerV2.t.sol`, `MockERC4626Wrapper.sol` | PASS | All absent; `0fd6bdf..6d5168d` shows exactly these deletions |
| 4 | `NudgeStreamerDonorIntegration` no longer depends on Balancer; the retarget/retire decision is recorded | PASS | Retargeted to UniPoolerV2 (Decision 2); only comment mentions remain (L76/L162) |
| 5 | `BalancerPoolerMintDebtHook` + `IBalancerPoolerMintDebtHook` untouched | PASS | `git diff --stat 0fd6bdf c5ad56d` on both is empty |
| 6 | Escrow (`src/migration`, its tests, `MockV3ExitRouter`) has no diff | PASS | Empty diff |
| 7 | Refresh stale comments in NudgeRatchetDelayRelease, MintPageView, Uniboost (comments only) | PASS | The non-comment diff is empty. MintPageView lives in phStaging2 and is picked up by phStaging2:107 (exists, `auto-complete`) |
| 8 | phStaging2 importer list in the execution summary; phStaging2 not modified | PASS | Both branches listed |

**Law-1 story review:** the change is a source-only deletion with no on-chain effect. The deployed `BalancerPoolerV2` `0x7f6874332c4629429d70D15f685A8230323F11F1` was verified inert at mainnet block 26280480: paused, unregistered from NFTMinterV2 (`dispatcherToIndex == 0`; index 4 → UniPoolerV2), every token balance 0, and both streamer allowances 0.

**Ledger consequence (proposal only, never auto-applied):** seven open entries anchored in the deleted file can no longer be observed by a regression scan. One of them is the faithfulness record **F-01-047** (`5d6538f76f`, carried in [`carryover/spec-conformance-19.md`](carryover/spec-conformance-19.md), where it is parked for triage). Proposed disposition: close all seven as `wont-fix` (obsolete), not `fixed` (no fix was made) and not `abandoned` (merged code, not a discarded branch). The full list is in [`qa-report.md` § Human triage proposals, item 1](./qa-report.md#1-balancerpoolerv2-deleted-propose-wont-fix-obsolete-for-7-entries). A human must apply it via `/ledger`.

---

## story-050 gate note: cleared ahead of 30 Nov (not filed)

> This story must not execute until the human has cleared: `winddown-confirmed`. This means that after 30 Nov 2026 the human has confirmed on-chain that pooler BPT = 0, owner BPT = 0, and the old BalancerPoolerV2 (`0x7f6874332c4629429d70D15f685A8230323F11F1`) is drained and paused.
>
> (story-050 L9, Execution Gate)

> GATE CLEARED: winddown-confirmed — 2026-10-24 — mainnet block 26260804: BalancerPoolerV2 0x7f68…F11F1 paused()=true; pooler BPT … balanceOf=0; owner … BPT=0; pooler phUSD/USDS/sUSDS/USDC/ETH all 0. Cleared ahead of 30 Nov on the human's instruction (all funds migrated).
>
> (story-050 L12)

The story text says the gate clears "after 30 Nov 2026". It was cleared on **2026-10-24**, at block 26260804, on explicit human instruction. That is a **knowing owner decision** (Law 3). The date was a proxy for the wind-down having finished, and the on-chain preconditions behind it were re-verified independently at block 26280480 (above). **Not filed** as a faithfulness deviation.

---

## Missing follow-up stories and the obligations they must carry

story-053 (L18, L128-130) pushes deployment, wiring, SYA de-gating and the UI to follow-up stories. Each was searched for across the whole `~/code/product-owner/stories/` tree on 2026-10-27.

| # | Follow-up | Exists? | Obligations it must carry (Law 1 / Law 2) |
|---|---|---|---|
| 1 | **phStaging2: NFTBonfire deploy/wiring** (`setAuthorizedBurner`, `setApprovedMinter`, Pauser registration, initial rate, pin bump), "ordered after phStaging2:116" | **No.** phStaging2:116 exists (`incomplete/phStaging2-sya-and-pool/116-deploymocks-sya-harvester-config-and-smoke.md`), but no story mentions NFTBonfire anywhere in phStaging2 | (a) **`setMaxPayout(rate × 1-2 days)` before the first non-zero `setRatePerDay`**, and enable the rate only after `setAuthorizedBurner` and `setApprovedMinter` have landed (L-29 / F-01-053). (b) **Stop burns before any cap change**: `pause()` or `setRatePerDay(0)`, then `setMaxPayout`, then resume. Never re-cap while burns are live (L-29). (c) **`setPauser(globalPauser)` and `Pauser.register(bonfire)` before the rate goes live**, both checked by the phStaging2 verifier. The runbook must state that pausing NFTMinterV2 does not stop NFTBonfire and that `setRatePerDay(0)` is the stop that needs no pauser (Q-27; re-rate to Low if omitted). (d) **Revoke the stale NFTMigrator mint route**: `NFTMinterV2.setAuthorizedMinter(0x22c0fc1aae66873abd029448eaf15a2fd7eed140, false)` and/or pause V1 `NFTMinter` `0xd936461f…`, then enumerate `authorizedMinters` (L-30). The fix is on chain, so a yield-claim-nft rescan that still reports L-30 is not an incomplete fix |
| 2 | **yield-accumulator: remove SYA NFT gating and revoke SYA's burner authorisation on NFTMinterV2** (story-053 L18, L129) | **No.** Only the historical 019/020 (which added the gating) match. phlimbo-ui:089 already carries `FORGE_HARVEST_REQUIRES_NFT = true; // flip to false once SYA NFT gating is removed` | Revoke `setAuthorizedBurner(SYA, false)` **in the same change set** that removes gating. If the gating is removed but the burner authorisation is left in place, an authorised burner that is no longer needed stays live on an ERC1155 whose `burn` has no approval check. Until this lands, NFTs have two competing sinks (SYA harvest and the bonfire), which the story intends to end |
| 3 | **phlimbo-ui: bonfire burn button** (story-053 L100, L130) | **Partly.** `phlimbo-ui/incomplete/forge/090-forge-nft-bonfire-mock.md` (sprint 27) builds a **mocked** row and sets `FORGE_BONFIRE_MIN_PAYOUT_BPS = 9800` (`minPayout` = pot × 98%), calling the figure illustrative (L99). No story wires the live contract. *Correction to the faithfulness scan, which reported that no phlimbo-ui story exists.* | The live wiring story must submit **`minPayout = pendingPayout() - tolerance`, never 0** (Q-26; story-053 L100), with an owner-confirmed tolerance. It must also show the burn as disabled while `ratePerDay == 0` or while paused, and keep 090's irreversible-burn confirmation dialog |
| 4 | **Housekeeping: `forge fmt` the drifted files and add `[profile.ci]` with the optimizer** (story-053 Decision 2 alternatives, L164; review L256) | **No** | Clear F-02-053 so that the CI gate the stories tick is real. Choose explicitly between reformatting deployed-source contracts (source-hash drift against verified commits) and a formatter exclusion |

Related to story-050: phStaging2:107 (pin bump + MintPageView comment refresh) **exists** (`auto-complete`). phlimbo-ui step U4 (remove the legacy Balancer displays, story-050 L16) has **no story yet**. U4 has no security impact and is listed for completeness.

---

## Carryover index

Still-live faithfulness records from earlier audits are **not** merged into this report. Each originating audit has its own pruned file under `yield-claim-nft/reports/23/submissions/carryover/` (written by finding-manager, not modified here). No spec-conformance entry changed ledger status between run 22 and run 23.

| File | Live entries carried | Also parked (pending human triage) |
|---|---|---|
| [`carryover/spec-conformance-15.md`](carryover/spec-conformance-15.md) | F-01-043 | |
| [`carryover/spec-conformance-18.md`](carryover/spec-conformance-18.md) | F-01-045 | |
| [`carryover/spec-conformance-19.md`](carryover/spec-conformance-19.md) | F-02-046, F-03-046 | F-01-047 (BalancerPoolerV2 deleted by story-050; proposed `wont-fix` (obsolete)) |
| [`carryover/spec-conformance-20.md`](carryover/spec-conformance-20.md) | F-02-048 | |
| [`carryover/spec-conformance-21.md`](carryover/spec-conformance-21.md) | F-01-051, F-02-051, F-03-051 | |
| [`carryover/spec-conformance-22.md`](carryover/spec-conformance-22.md) | F-01-052, F-03-052, F-04-052 | (F-02-052 removed: `fixed` @ `0fd6bdf`, human-applied 2026-10-19) |

The QA carryovers (`qa-report-NN.md`) sit in the same directory and are indexed by `qa-report.md`. There are no High/Medium carryovers this run.

---

## Summary

| | Count | Records |
|---|---|---|
| New faithfulness records (ledger) | 1 | F-02-053 (`ycn23f2`, informational) |
| Cross-references (not separate entries) | 1 | F-01-053 → L-29 (`ycn23l29`) |
| Stories checked | 2 | story-050 (8/8 pass), story-053 (14/15 pass) |
| Unsafe-story (Law 1) escalations | 0 | |
| Not filed (knowing owner decision) | 1 | story-050 gate cleared ahead of 30 Nov |
| Missing follow-up stories | 3 missing, 1 partial | deploy/wiring, SYA de-gate + burner revoke, housekeeping; phlimbo-ui live wiring (mock 090 exists) |
| Carried-over faithfulness records | 11 live + 1 parked | see Carryover index |
