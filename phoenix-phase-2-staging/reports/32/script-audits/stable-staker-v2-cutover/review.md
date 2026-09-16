# Script review: `stable-staker-v2-cutover`

| | |
|---|---|
| Project | phoenix-phase-2-staging |
| Run | 32 (script-audit, **regression** against run 31 @ `1c1608c`) |
| Entry point | `stable-staker-v2-cutover` (`:preview` / `:broadcast`); forge target `script/CutoverStableStakerV2Mainnet.s.sol:CutoverStableStakerV2Mainnet` |
| Stories | story-083 (authoritative for the delta; supersedes story-082 Decision 9 and its 2-wei slack) and story-082 (base script) |
| Source | [`884ccf8`](https://github.com/Behodler/phoenix-phase-2-staging/tree/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e) on `master` |
| Delta since run 31 | `bdbd850` [story-083], `0855338` [story-083 polish], `884ccf8` (untagged, touches DeployMocks and anvil artefacts only) |
| Script | [`script/CutoverStableStakerV2Mainnet.s.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol), [`script/helpers/StableStakerCutoverCore.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/helpers/StableStakerCutoverCore.sol) (byte-identical to `1c1608c`) |
| Mode | fork-preview at mainnet block **25978784** |
| Outcome | 0 High, 0 Medium. New: 1 Low (L-04), 1 QA (Q-02). Still open: L-02 (widened), L-03, F-01. L-01 proposed `fixed`. Triaged wont-fix (invalid, out of scope) by owner 2026-09-15: Q-03 (new) and Q-01 (run 31) — not live. |

## Status: pre-broadcast

The cutover has **not** been broadcast at `884ccf8`. There is no `server/deployments/progress.stable-staker-v2-cutover.1.json` and no `broadcast/CutoverStableStakerV2Mainnet.s.sol/` directory. The `StableStakerV2` and `Antimatter` keys in `server/deployments/mainnet-addresses.ts` are still zero placeholders. On chain at block 25978784, StableStakerV1 `0xbce8…079A` is registered with the Pauser and unpaused, and OWNER's nonce (1631) shows no cutover transaction. Everything below is a pre-flight review; every open item can still be fixed before anything is signed.

**Story provenance.** Globbing the whole `~/code/product-owner/stories/phStaging2/` tree returned exactly one document per tag:

- story-083: `auto-complete/phStaging2-stable-staker-v2/083-cutover-wei-slack-and-v1-pauser-unregister.md`
- story-082: `auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md`

Both sit in **`auto-complete/`**, which is not one of the standard state folders (`complete` / `incomplete` / `review` / `archive`). Both carry the stamp "machine approval — not human-reviewed". Their carried-forward observations are therefore surfaced here rather than treated as owner-accepted. Supporting stories: story-080 (DeployMocks rehearsal, "THE TEMPLATE"), story-067 (zero-haircut floor), story-062 (pause-window pattern), all resolved uniquely.

---

## 1. Does it do what it intends?

**Yes.** Every story-083 acceptance criterion is met, and the happy path passes against live state.

### Story-083 acceptance criteria at `884ccf8`

| Criterion | Status | Where |
|---|---|---|
| `WEI_SLACK` 2 → 1000, with NatSpec; `_maxLossBps` NatSpec corrected | met | L108-L112 |
| `IPauserRegistry.unregister(address)` added | met | L969 |
| Phase 7 V1 block: `setPauser(OWNER)` (gated) → `Pauser.unregister(V1)` (gated on `isRegistered`) → `pause()` if not paused, each with a read-back `require` | met | L554-L568 |
| V1 block runs before V2's pauser hand-back (the finalized marker) | met | L570 |
| Phase 8 asserts V1 pauser == OWNER, V1 not registered, V1 paused | met | L635-L637 |
| Phase 0/1 resume logic consistent | met, fork-proven (`test_R1` resume after unregister-only, `test_R2` resume after V2 pauser hand-back, `test_R3` full re-run after completion) | L272-L290 |
| Patch-script comment says V1 is "paused, and unregistered from the Pauser" | met | `scripts/patch-mainnet-addresses-stable-staker-v2.js` |

One item sits outside 083's checklist and is filed: the `package.json` operator doc key was not updated (Q-02). ~~The DeployMocks rehearsal still uses the old slack and end state (Q-03)~~ — Triaged wont-fix (invalid, out of scope) by owner 2026-09-15: DeployMocks is a UI-testing mock stack, not a fidelity rehearsal of the mainnet cutover script; divergence from the mainnet script's wiring/end state is not a defect.

### Fork preview

The `:preview` variant was run exactly as `package.json` defines it, plus `--fork-block-number 25978784`, from `work/` (whose copies of the script, core, DeployMocks, dust test, `package.json` and `foundry.toml` were `cmp`-identical to `src/`). No `--broadcast`; no progress file before or after. Result: **PASS, forge exit 0.**

| Check family | Evaluated | Passed | Change from run 31 |
|---|---|---|---|
| Preconditions (config + Phase 0) | 27 | 27 | unchanged |
| Step post-conditions (Phases 2 to 7) | 192 | 192 | +3 V1 retirement read-backs |
| Phase 8 wiring assertions | 60 | 60 | −2 old V1 asserts, +3 retirement asserts |
| Preview smoke tests | 12 | 12 | unchanged |

- **Every staker migrated.** DOLA 9, USDC 13, USDe 7 (29 users, one batch per pool), 0 stragglers, 0 zero-credit positions. V1 `stakerCount` and `totalStaked` end at 0 on every pool.
- **Story-060 surplus relinquished** before `initiateMigration`: 26.898455742910213445 DOLA and 27.043385 USDC; USDe had none.
- **Retirement landed as story 083 specifies.** The preview prints `V1 pauser -> OWNER, unregistered from Pauser, left paused; V2 + Antimatter registered with Pauser; V2 unpaused`.
- **The global breaker works at the end state.** `test_B`: an EYE-funded `Pauser.pause()` succeeds 26/26 before the cutover and 27/27 after finalize (V2 and Antimatter both paused); an owner `unpause()` afterwards leaves retired V1 paused.
- **Retired V1 behaves as intended** (`test_S`): `stake` reverts `EnforcedPause`; a former user's `userMigrate` reverts `nothing staked`; `emergencyWithdraw` reverts `pool not active`; the owner's `rescueERC20` of idle buffers still works while paused.
- **The fork harness is 13/13 PASS** (`work/test/audit-run32/CutoverAuditRun32.t.sol`, audit-authored, prank-only, inherits the unmodified script).

### `WEI_SLACK = 1000`: safe, and still bounded by bps for real positions

Per-user losses at block 25978784 (`test_A`):

| Pool | Users | Worst loss | Bound | Users over the pre-083 bound (bps + 2 wei) | Users where the wei term dominates |
|---|---|---|---|---|---|
| DOLA | 9 | 0.003392648088142725 DOLA | 2 bps + 1000 wei | 0 | 0 |
| USDC | 13 | 0.057966 USDC | 2 bps + 1000 wei | 0 | 7 (six dust positions of 12-90 wei, each losing exactly 2 wei; one 4.83 USDC position losing 418 wei against a 965-wei bps term) |
| USDe | 7 | 3.499065473879431359 USDe | 61 bps + 1000 wei | 0 | 0 |

- The 1000-wei term binds only where `pre * bps / 1e4 < 1000`: USDC positions under 5 USDC and 18-decimal positions under 5e6 wei. The bps term remains the binding gate for every position of economic size.
- The most the change can hide beyond the old bound is 998 wei per user: 0.000998 USDC, or about 1e-15 DOLA/USDe. Across all 29 users that is **under $0.03**.
- It closes run-31 L-01. `test_L1`: a planted 9-wei DOLA stake (8 wei of principal) now lets the full run pass with a 5-wei V2 credit; under `WEI_SLACK = 2` the same PoC reverted. `test_L2`: an exhaustive search over stakes of 1 to 2000 wei finds a worst loss of 3 wei (DOLA) and 2 wei (USDC), with 0 inputs above the bound; the `slack = 2` control puts 319 DOLA inputs above it.

**Story-083's stated motivation does not reproduce at this block.** Story 083 (line 14) and the script NatSpec (L109-L110) say simulated round trips "lost more than 2 wei per user and tripped the Phase 6 post-migration assert". At block 25978784 no live staker exceeds the pre-083 bound; the live population would pass with `WEI_SLACK = 2`. The closure manifest also notes that story 083 never recorded a measured loss above 2 wei. The 1000-wei slack is still justified, because it is what defeats the planted-dust stall in L-01, but the NatSpec rationale describes a condition that was not observed. This is recorded as an observation, not filed.

### Where intent and implementation still diverge

- **The "067 floor" still cannot fail (F-01, open).** `StableStakerCutoverCore.sol` is unchanged; `principalOf(V2)` equals `V2.totalStaked` exactly on all three pools again. Story 083 loosened the only real loss gate (the per-user bound), which makes the missing aggregate floor slightly more relevant, but no asset impact is shown.
- **The post-broadcast `:preview` still does not verify (L-02, open, widened).** Story 083's three new retirement steps are also `if (!done) do();` gates, so preview now also masks a missing V1 retirement (`test_C3`).

---

## 2. Unintended side effects

**One unintended effect, and it is transient.** Everything else the fork observed maps to a declared step or to the venue activity the exit and re-deposit mechanically require.

### L-04: the Phase 1 → Phase 7 window bricks the global pause (new, Low, footgun)

Phase 1 sets V1's pauser to OWNER and pauses V1 ([L283-L285](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L283-L285)). V1 is removed from the Pauser only in Phase 7 ([L559](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L559)), roughly 40 transactions later. `Pauser.pause()` loops `IPausable(c).pause()` over every registrant with no try/catch (`lib/pauser/src/Pauser.sol` L56-69, nested submodule), so for the whole window it reaches V1 at index 18 and reverts.

Fork evidence (`test_W_windowBricksGlobalPause`):

- After Phase 1: `V1.paused=true | V1.pauser==OWNER | V1.registered=true`; EYE-funded `Pauser.pause()` → **REVERTED "StableStaker: only pauser"**.
- After the real Phase 6: same revert.
- `WINDOW_OWNER_DIRECT_PAUSERS | 1of26`: during the window OWNER is the direct pauser of V1 only, so the owner cannot reach the other 25 registrants (yield strategies holding staker principal, PhlimboV3, hooks) through the Pauser either.
- Remedy: `Pauser.unregister(V1)` inside the window → global pause **SUCCEEDED 25/25**, and the **unmodified** `run()` then completes because the Phase 7 gate skips. `test_W2` proves the same ordering from fresh Phase 0 state.

The window lasts the whole `--slow` Ledger session. Because Phase 6 contains `STOP AND REPORT` reverts and the resume runbook halts the run, it has no upper bound if a run stops between Phase 1 and Phase 7 and nobody resumes it.

**Why Low, not Medium.** No asset moves because of this and no user-facing function loses availability. The harm requires an independent incident on a registrant during the window, and the owner can restore the breaker with one transaction. Run-31 L-03, a broader and permanent version of the same impact class, is rated Low. **Why in scope.** Story 083's own rationale ("once V1 is unregistered, that risk is gone", line 15) covers only the end state. An owner who has just cleared the registry so the breaker works would not expect the cutover to break it again (Law 3 footgun). The script is faithful to 083's wording; the gap is in the story's safety reasoning (Law 1 over Law 2). The ordering predates 083 (story 082 also paused V1 in Phase 1), but in run 31 it was hidden behind the two pre-paused registrants.

### Residual state and benign effects

| Effect | Disposition |
|---|---|
| Pauser registry reorder: `0x17E25Cca844bC71c1E663E089fF11aFD266B5795` moves from index 25 to index 18 | **Benign.** Inherent to `unregister`'s swap-and-pop; no index-sensitive consumer. Registry goes 26 → 27 (V1 out; V2 at 25, Antimatter at 26). Pauser emits `ContractUnregistered(V1)` and two `ContractRegistered`. |
| CrossVersionMigrator keeps the migrator role on V1 and V2 | **Inert**, same as run 31. `test_S`: the migrator's owner-called `initiateMigration` reverts `pool not active` on all three pools. The dev-path analogue stays recorded as ledger L-06 `08adbb692840`. Not filed. |
| V1 idle set-aside buffers stay on retired V1 (6.997 DOLA, 10.430702 USDC, 49.8455 USDe) | Covered by ledger **F-02** `436848b0e31b`, owner-triaged **wont-fix** on 2026-09-14 (by design; do not recommend a top-up path). The owner's `rescueERC20` works while V1 is paused. Not re-filed. |
| phUSD minter mask 511 → 510 | **Intended.** Only the V1 bit cleared; `mintVersion` stays 0; V2 and Antimatter grants are new mappings. |
| phUSD supply +87.152395901387108137 | **Intended.** Equals the frozen V1 pending rewards minted in `batchMigrate` (story 082). |
| Strategies (YS_DOLA, YS_USDC, YS_USDE) | Intended: V2 authorised as client, buffers copied (10/10/25), recipient V1 → V2 where the strategy supports it, V1 principal to 0. |

The preview emitted 459 events; V1 accounts for 233 raw slot writes and the Pauser for 14. No write was attributed to a contract outside the declared closure.

---

## 3. Knock-on problems and the sibling-script cluster

### The owner's hand-signed registry cleanup cleared run-31's live brick

Story 083 names an out-of-band prerequisite: unregister the two already-paused registrants that made `Pauser.pause()` revert protocol-wide in run 31 (manual-review item MR-31-SSV2C-01, the root cause behind L-03's end-state clause). The closure manifest confirms OWNER did this by hand, with no in-repo script:

| Contract | `setPauser(OWNER)` | `Pauser.unregister` | State now |
|---|---|---|---|
| `0x3984eBC84d45a889dDAc595d13dc0aC2E54819F4` (old PhlimboEA) | block 25978109, nonce 1625 | block 25978110, nonce 1626 | paused, pauser OWNER, unregistered |
| `0xf5F91E8240a0320CAC40b799B25F944a61090E5B` (old USDC YS) | block 25978112, nonce 1627 | block 25978114, nonce 1628 | paused, pauser OWNER, unregistered |

The registry went from 28 to 26 registrants, all unpaused with pauser == Pauser, and `test_B` shows a live global pause succeeding **26/26**. Two consequences:

- **The live protocol-wide brick is gone**, so V2 and Antimatter no longer arrive behind a dead breaker.
- **L-04 is now the only thing that breaks the breaker**, and only during the cutover window. That is why it surfaced this run.

L-03 stays **open** nonetheless: its end state is clean only because of the owner's on-chain action, and its clause (b) is still live, since Phase 8 asserts registration and never simulates `Pauser.pause()`. Nothing in the script would catch a new pre-paused registrant appearing before broadcast.

### Cluster

| Rank | Sibling | Relation | Knock-on |
|---|---|---|---|
| 1 | `script/DeployMocks.s.sol`, `_deployAntimatterAndStableStakerV2` / `_rehearseStableStakerCutover` (`dev`, story-080) | Anvil rehearsal the mainnet script says it mirrors | ~~**Q-03 (new):** still asserts `+ 2` wei (L2090) and never retires dev V1.~~ ~~**Q-01:** `884ccf8` added the Antimatter phUSD grant (L1897-L1906), but nothing local calls `autoAnnihilate`.~~ Both triaged wont-fix (invalid, out of scope) by owner 2026-09-15: DeployMocks is a UI-testing mock stack, not a fidelity rehearsal of the mainnet cutover script; divergence from the mainnet script's wiring/end state is not a defect. |
| 2 | OWNER hand-signed txs (nonces 1625-1628) | Out-of-band prerequisite named in story 083 | Cleared MR-31-SSV2C-01 (above). Not reproducible from the repo. |
| 3 | `package.json` `//StableStakerV2Cutover` doc key (L49) | Operator guidance read before signing | **Q-02 (new):** still says "2 bps + 2 wei" and "V1 pauser back to Pauser and V1 UNPAUSED", the opposite of the script's end state and of its own preview output. `package.json` is unchanged since `1c1608c`. |
| 4 | `test/StableStakerCutoverDust.t.sol` | Tests the shared helper | Unchanged. Market branch still runs only with `RPC_MAINNET` set. |
| 5 | `verify-stable-staker.sh` → `ClaimWithdrawStableStaker.s.sol` (`test:stable-staker`) | Local V2 verification | Unchanged; `autoAnnihilate` appears only in a comment (L24) and a log string (L106). (Formerly cited as Q-01's open half; Q-01 is triaged wont-fix (invalid, out of scope) by owner 2026-09-15.) |
| 6 | Archived saga2 set (stories 060/062/067) | Source of the surplus, pause pattern and floor | F-01 remains the third recurrence of the story-067-floor class (after YS-26 `018c109ec76f` and YS-32 `523ef3df52a6`). |
| 7 | `promotion-ready` (stories 071/073/076) | Source of the gas flags and minter delta | L-02 remains in the `ForgeLocalPassPrecedesBroadcast` family (fix-pending M-01 `2c53e944caee`). |

**L-02 widened.** `test_C3`: after a full cutover, V1 is unpaused, handed back to the Pauser and re-registered; preview `run()` re-performs `setPauser` / `unregister` / `pause` under prank and reports `MASK_V1_RETIRE | preview run() PASSED although V1 was registered+unpaused on-chain`. `test_C` (missing V1 mint revoke) and `test_C2` (paused V2) are still masked as in run 31.

**F-01 still tautological.** Exact equality on all three pools: DOLA `1222723447469613917497`, USDC `1968305934`, USDe `2557834010080189682235`.

**Tooling gap.** 4naly3er produced **no report** this run, as in run 31. The project resolves imports only through `foundry.toml`, which 4naly3er does not read. A staged run with generated absolute remappings first failed on a root-relative import in a nested dependency; with an added `lib/` remapping it compiled, then ran to the 480-second cap and wrote nothing. There is no automated QA baseline; every finding comes from the script-audit pipeline and the fork harness.

---

## Run-31 reconciliation

| Run-31 label | `issueId` | Fingerprint | Run-32 disposition | Evidence |
|---|---|---|---|---|
| L-01 (dust stalls cutover) | `pps31l1` | `e0d4df1ddb69…` | **Propose `fixed`** (not applied; human action: `/ledger phoenix-phase-2-staging fixed e0d4df1ddb69`) | `WEI_SLACK = 1000` (L112); `test_L1` planted dust passes; `test_L2` 0 of 2000 inputs above bound |
| L-02 (preview re-performs missing steps) | `pps31l2` | `2c82d65e65e1…` | **Still open, surface widened** by story 083 | `test_C`, `test_C2` reproduced; new `test_C3` masks missing V1 retirement |
| L-03 (V2/Antimatter behind a dead breaker; Phase 8 asserts registration only) | `pps31l3` | `0711215fcc17…` | **Open.** End state is clean only because of the owner's hand-signed unregister of `0x3984…` / `0xf5F9…`; Phase 8 still never simulates a pause | `test_B` 26/26 and 27/27; Phase 8 L638-L639 check `isRegistered` only |
| F-01 ("067 floor" tautological) | `pps31f1` | `dfed42790952…` | **Still open**, code unchanged | `test_A` POSTPOOL exact equality |
| Q-01 (rehearsal omits Antimatter grant; no `autoAnnihilate` locally) | `pps31q1` | `ca095edfd77e…` | **Triaged wont-fix (invalid, out of scope) by owner 2026-09-15.** DeployMocks is a UI-testing mock stack, not a fidelity rehearsal of the mainnet cutover script; divergence from the mainnet script's wiring/end state is not a defect. The run-32 incomplete-fix signal is superseded; no fix is owed. | `git diff 1c1608c 884ccf8`; verifier scripts unchanged |
| F-02 (stakers bear loss while protocol keeps buffers/surplus) | `pps31f2` | `436848b0e31b…` | **wont-fix** (owner, 2026-09-14). Suppressed, not re-graded | V1 idle buffers observed, as designed |
| F-03 (Antimatter phUSD grant outside story-082 list) | `pps31f3` | `103002cc2990…` | **wont-fix** (owner, 2026-09-14: story oversight, grant accepted). Suppressed | — |

No regressions. MR-31-SSV2C-01 (the protocol-wide pre-paused-registrant brick) is resolved on chain by the owner.

---

## Before broadcast

1. **Fix L-04 (strongly recommended).** In `_phase1_pauseV1`, call `Pauser.unregister(V1)` (gated on `isRegistered`, with a `require(!isRegistered)` read-back) after `setPauser(OWNER)` and **before** `pause()`. Keep the Phase 7 block as the idempotent backstop. This is fork-proven compatible (`test_W`, `test_W2`): the unmodified Phase 7 gates skip and the resume paths still converge. Until this lands, the runbook should state that a halted run must be resumed, or V1 unregistered by hand, before the operator walks away.
2. **Fix Q-02 (recommended).** Update the `//StableStakerV2Cutover` key: 2 bps + 1000 wei on the ERC4626 pools and 61 bps + 1000 wei on USDe; V1 pauser → OWNER, `Pauser.unregister(V1)`, V1 left paused; note the extra transaction. If item 1 lands, describe the unregister under Phase 1. The audience of this text is the Ledger signer.
3. **Optionally, add L-03's simulated-pause assert.** A preview-only full `Pauser.pause()` (deal EYE, approve, call inside `snapshotState` / `revertToState`) at Phase 0, after Phase 1, and at Phase 8. This closes L-03 clause (b), would have surfaced L-04 automatically, and catches any new pre-paused registrant that appears between now and broadcast.

L-02 and F-01 do not block the broadcast (Q-01 and Q-03 are triaged wont-fix (invalid, out of scope) by owner 2026-09-15 and are not action items). L-02 matters most **after** broadcast: until an assert-only verifier exists, a green post-broadcast `:preview` should not be read as proof that every step landed; check the V1 retirement triple, V1 mint revocation and V2 unpaused state directly on chain.

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| L-04 | Low | **New.** From Phase 1 until Phase 7's `Pauser.unregister(V1)`, V1 is paused with pauser OWNER but still registered, so the permissionless global `Pauser.pause()` reverts ("StableStaker: only pauser") for all 26 registrants for the whole session, or indefinitely after a halt. Footgun; fork-reproduced (`test_W`). | Move `Pauser.unregister(V1)` into Phase 1 before `pause()`, keep Phase 7 as backstop, and add a preview-only simulated `Pauser.pause()` at Phase 0, after Phase 1 and at Phase 8. | [CutoverStableStakerV2Mainnet.s.sol#L272-L290](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L272-L290), [#L550-L568](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L550-L568) |
| L-02 | Low | **Still open, widened.** The post-broadcast `:preview` re-performs any outstanding step under prank instead of asserting it, so a partial cutover verifies green; now also masks a missing V1 retirement (`test_C3`). | Add an assert-only verify mode gated on on-chain state that requires every done-condition (including the V1 retirement triple) and re-checks per-user loss from on-chain receipts, never mutating. | [CutoverStableStakerV2Mainnet.s.sol#L146-L643](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L146-L643) |
| L-03 | Low | **Open.** V2's and Antimatter's only pause authority is the Pauser, and Phase 8 asserts registration, not a working breaker. The end-state brick is absent only because the owner hand-unregistered two pre-paused registrants. | Add a Phase 0/8 check that a simulated `Pauser.pause()` succeeds (or every registrant is `!paused()`); the stale-entry cleanup half is done on chain. | [CutoverStableStakerV2Mainnet.s.sol#L570-L575](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L570-L575), [#L638-L639](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L638-L639) |
| L-01 | Low | **Proposed fixed.** The fixed 2-wei per-user slack let a 9-wei DOLA stake revert the Phase 6 post-condition. `WEI_SLACK = 1000` removes the stall (`test_L1`, `test_L2`). | Applied by story 083 (`WEI_SLACK = 1000`); a human flips the ledger entry to `fixed`. | [CutoverStableStakerV2Mainnet.s.sol#L108-L112](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/CutoverStableStakerV2Mainnet.s.sol#L108-L112) |
| F-01 | Low | **Still open.** The "067 floor" compares two identically booked values and cannot fail; story-067's pre-migration anchor is not implemented. Slightly more relevant now that the per-user gate is looser. | Require `V2.totalStaked >= P * (MAX_BPS - maxLossBps) / MAX_BPS - n * WEI_SLACK` with `P` = V1 `principalSnapshot`, or rename the check and record the relaxation as human-accepted. | [StableStakerCutoverCore.sol#L469-L471](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/helpers/StableStakerCutoverCore.sol#L469-L471) |
| Q-02 | QA | **New.** The `//StableStakerV2Cutover` operator doc key still describes the superseded story-082 end state ("2 bps + 2 wei", "V1 pauser back to Pauser and V1 UNPAUSED"), contradicting the script and its preview output. | Rewrite the key to story 083's end state (1000-wei slack; V1 pauser OWNER, unregistered, left paused) and note the extra unregister transaction. | [package.json#L49](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/package.json#L49) |
| ~~Q-03~~ | QA | **Triaged wont-fix (invalid, out of scope) by owner 2026-09-15.** DeployMocks is a UI-testing mock stack, not a fidelity rehearsal of the mainnet cutover script; divergence from the mainnet script's wiring/end state is not a defect. Original: ~~The story-080 DeployMocks rehearsal still asserts a 2-wei slack and leaves dev V1 unpaused and registered, so it no longer rehearses story 083's end state or its forced `setPauser → unregister → pause` ordering.~~ | None owed (wont-fix). | [DeployMocks.s.sol#L2075-L2095](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/DeployMocks.s.sol#L2075-L2095) |
| ~~Q-01~~ | QA | **Triaged wont-fix (invalid, out of scope) by owner 2026-09-15.** DeployMocks is a UI-testing mock stack, not a fidelity rehearsal of the mainnet cutover script; divergence from the mainnet script's wiring/end state is not a defect. Original: ~~The Antimatter phUSD grant was added to DeployMocks in `884ccf8`, but no local script or test calls `autoAnnihilate`.~~ | None owed (wont-fix). | [DeployMocks.s.sol#L1897-L1906](https://github.com/Behodler/phoenix-phase-2-staging/blob/884ccf8c4fc2cd0ece179745bf2ea381e2bba51e/script/DeployMocks.s.sol#L1897-L1906) |

F-02 and F-03 are owner-triaged wont-fix and are not listed. Q-01 and Q-03 were owner-triaged wont-fix (invalid, out of scope) on 2026-09-15 and are shown struck through for the record. L-02 and F-01 are also graded in `submissions/spec-conformance.md`. Full write-ups: `submissions/qa-report.md` (L-04, Q-02, L-02; Q-03 and Q-01 in its triaged section), `submissions/spec-conformance.md` (F-01, L-02), and `submissions/carryover/` (run-31 text of L-01, L-03, F-02, F-03). Line numbers above were re-verified against `884ccf8`.

### Fingerprints

All entries carry `entryPoint: stable-staker-v2-cutover` and `branch: master`.

- L-04 (`pps32l4`): `46c053534c586895fece77ca5a74f0991e02d36f5c513251c6847e84787f96b6`
- Q-02 (`pps32q2`): `1c859cdebb6424756c073b1358559f38d84feff33eb6f6a6563414e352a03542`
- Q-03 (`pps32q3`): `30510f331ea8d0067a9552be68956070da9429bcaaaf01c9bd3647a8e890a815` — wont-fix (owner, 2026-09-15)
- L-02 (`pps31l2`): `2c82d65e65e163c9f986c669aaf0b56abcfc80ae9f91016dd3f84fc1fb6b7da7`
- F-01 (`pps31f1`): `dfed4279095251f3acd34987e79e3a1eecfce16adaca31cc6c776e8f724e713a`
- Q-01 (`pps31q1`): `ca095edfd77eb5c995570804e32901905437b90bc37ed74d5484860593878257` — wont-fix (owner, 2026-09-15)
- L-01 (`pps31l1`): `e0d4df1ddb699c8f34e034209cf8a6311bffa3bfd79429662637976f527dd054`
- L-03 (`pps31l3`): `0711215fcc1767f9aff5cee42cead479a605b37e56ccbfb5d025eaac211cae06`

---

*Evidence:* `entry-manifest.json`, `closure-manifest.json`, `intent.md`, `side-effects.json`, `classified-findings.json`, `fork-logs/preview-25978784.log`, `fork-logs/h32-test_{A,B,C,C2,C3,L1,L2,R1,R2,R3,S,W,W2}_*.log`. Harness: `phoenix-phase-2-staging/work/test/audit-run32/CutoverAuditRun32.t.sol`, written by the audit and not part of the audited source.
