# Script review: `stable-staker-v2-cutover` (run 37, delta `91ed727..1349be8`)

| | |
|---|---|
| Project | phoenix-phase-2-staging |
| Entry point | `stable-staker-v2-cutover` |
| Source commit | `1349be82a717fcf9a30725d2e9cc047b4f3721d6` (branch `master`) |
| Delta | `91ed727..1349be8`, one commit: "Cutover: ZERO set-aside buffer for V2 on the sDOLA destination strategy" |
| Fork block | 26033797 |
| Result | **0 High / 0 Medium.** One Low (spec conformance), one Low (stale comment), one QA note |

## Answer: did 1349be8 open a vulnerability?

**No.** Setting V2's set-aside buffer to 0 on the sDOLA destination strategy does not open a vulnerability. It is marginally *safer* than the 10% the stories call for. The only issue it creates is paperwork: the code no longer matches story 091 Decision 6 or story 082 Phase 4 (F-05). The fix belongs in the story, not the code.

Why:

1. **The pct only feeds skim, not V2's exit path.** The buffer pct is stored per client and read in exactly one place, `ERC4626YieldStrategy._accrueSurplusShares` (L289), which is reached through `skim`. `StableStakerV2` never reads the pct. Its "buffer" is simply its idle token balance. `_routeExit` touches that balance only when `totalBalanceOf(V2) < principalOf(V2)`.
2. **That condition can't be reached on sDOLA without an owner action.** V2 is underwater only if the whole strategy's value `V` falls below total deposits `td`. The strategy rounds every operation in the protocol's favour, so `V >= td` holds. sDOLA's DOLA-per-share is monotone non-decreasing. We checked this in the sDOLA source and in readings either side of a week boundary: `1421201262130544134` → `1421201262130544134` → `1421201263518711686`.
3. **An independently reproduced fork harness confirms it.** `work/test/audit-run37/SdolaZeroBuffer.fork.t.sol` runs the real strategy against real sDOLA at live sizes. Result: 5 passed, 0 failed. The invariant ran 24 runs / 960 calls with 0 reverts and a minimum headroom of 0 wei, so `V >= td` held exactly. A second agent re-ran it and got the same result. We also checked that the harness can fail. A mutant that adds an owner `emergencyWithdraw` breaks it with `V2 underwater: 1261545922576837129858 < 1261625489338208966406`. The only path to underwater is that `emergencyWithdraw`, which is a deliberate owner action and therefore trusted under Law 3.
4. **A 10% buffer would barely have helped.** A guarded exit needs its *whole* amount sitting idle. At current accrual, a 10% skim-fed buffer would only have covered exits smaller than about 8 DOLA per year.

## Intent

Stated purpose (commit message + `_targetBufferPct` NatSpec). Each item was checked against the source:

- DOLA: V2's `setAsideBufferSize` on the sDOLA `ERC4626YieldStrategy` is **0**. A fresh strategy already defaults to 0. Phase 4 writes `setSetAsideBuffer(V2, 0)` only if a resumed run finds a non-zero value. **Verified.**
- USDC / USDe: unchanged. V2 gets V1's pct copied from the same source strategy (10 / 25). **Verified.** These values are enforced by the script's `require`s. The project fork test does not assert them directly (see Hardening).
- The pct is keyed on the destination *strategy* (`_destinationStrategyFor(t) == sdolaStrategy`), not on the token. `_destinationStrategyFor(DOLA)` reverts while `sdolaStrategy == 0`, so there is no silent fallback to autoDOLA. **Verified.**
- Resuming a partial run works. The Phase 4 postcondition (L1043-1045), the Phase 8 re-assertion (L1496-1499) and the verifier (`VerifyStableStakerV2Cutover` L268-275) all use the same `_targetBufferPct` predicate. **Verified.**
- Phase 7 still points the sDOLA strategy's `setAsideBufferRecipient` at V2. Nothing reads it while every client pct is 0, but it stays correct if one ever becomes non-zero.

**Law 2 (story faithfulness).** No `[story-NNN]` tag. Story 091 (`auto-complete`) L97 and Decision 6 (L195-197) require V2's pct on the destination to equal V1's source pct. Story 082 (`auto-complete`) L73 / L172 expect DOLA 10 / USDC 10 / USDe 25. No story in `~/code/product-owner/stories/phStaging2/` authorises zero (checked every state folder; latest story is 097). The deviation is safe (see above), so this is F-05, with the mitigation "amend the story, keep the code".

## Side effects

- **Beneficial: SYA `getYield` now matches skim.** With pct 0, the yield preview equals what skim actually delivers (`3847949730348279480` vs `3847949730348279479`, a 1-wei rounding gap). Before, the preview overstated the payout by the buffer slice.
- **Beneficial: skim no longer reverts on an unset recipient.** With pct 0, no buffer transfer happens, so skim cannot revert in the window before Phase 7 sets the recipient.
- **Neutral: recipient repoint.** Written and asserted, never read while pct is 0.
- **Preview run.** The fork preview stopped at Phase 0 on the expected DOLA gate: `totalWithdrawal` not initiated (stories 090/097). This commit did not cause the stop, and no later phase ran on the fork. The empirical evidence for the delta is therefore the dedicated harness above, not the preview.

## Knock-on

- **Future V2 migration off sDOLA (Q-07).** `initiateMigration` measures R from balances. With no idle cushion, R can come out a few wei short of P because share redemption rounds down. This is unverified and dust-scale. Accept and document, or pre-fund V2 with a nominal amount of DOLA before `initiateMigration`.
- **stable-staker M-01 `335586f9a1` (forfeiture trap)** is still open in the stable-staker ledger. This commit does not make it more reachable for DOLA: with pct 0 there is no buffer to forfeit, and the underwater path it depends on needs the owner action described above.
- **stable-staker `ss14l8`** is still `open` in the stable-staker ledger, but the source at this commit looks fixed. It is a candidate for `/recheck stable-staker ss14l8`. No status was changed from here.
- **Runbook (L-13).** The `package.json` L49 comment still says the pct is "copied from V1's source" for every token. The script header NatSpec (L68-73) was updated. `package.json` was not.

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| F-05 `pps37f5` | Low (spec-conformance) | Zero set-aside buffer on the sDOLA destination departs from story 091 Decision 6 / story 082 Phase 4, and no story authorises it. Fingerprint `566ff01323c3ded2012685017a40ec662f67f8fcd574576333a505f7ba4ebfdf` | Amend story 091 (L97, Decision 6 at L197) and 082 (L73, L172) to record 0 for the sDOLA destination. Keep the code | `script/CutoverStableStakerV2Mainnet.s.sol` L2102 (`_targetBufferPct`); stories 091 L97/L197, 082 L73/L172 |
| L-13 `pps37l13` | Low | The `package.json` runbook comment still says the pct is "copied from V1's source" for every token. Fingerprint `071ce9f9120a4ff30e468a6c8a5c0671c2b020c750d3099cc6f95806c83c9a9f` | Update the comment: DOLA → 0 on sDOLA; USDC/USDe → V1's pct | `package.json` L49 (`//StableStakerV2Cutover`) |
| Q-07 `pps37q7` | QA (unverified) | With V2's sDOLA pct at 0, `initiateMigration`'s balance-measured R has no idle top-up, so a future terminal migration off sDOLA can realise R a few wei below P. Fingerprint `7c0c0c7c443a7a9321d9b2bc858d514ef436cbd27fe3a764b1f4d04cc7352b3b` | Accept and document. Optionally pre-fund V2 with a nominal amount of DOLA before `initiateMigration` | stable-staker `src/StableStakerV2.sol` L830 |

There is no High or Medium, so no individual submissions or PoCs. Details are in `reports/37/submissions/spec-conformance.md` (F-05) and `reports/37/submissions/qa-report.md` (L-13, Q-07).

## Caveats

- **The project's own cutover fork test was not re-run independently.** One agent reported "50 passed". Only the audit harness `SdolaZeroBuffer.fork.t.sol` was re-run by a second agent.
- **Suggested hardening (not filed).** Add assertions to the project cutover test that USDC and USDe land at V2 pct 10 / 25. Today only the script `require`s enforce this.
- **Harness hygiene (audit-authored, not findings).** `SdolaZeroBuffer.fork.t.sol` has no pinned fuzz/invariant config, and it passes silently when no RPC is set. Pin the config and fail hard on a missing `RPC_MAINNET` before reusing it.
