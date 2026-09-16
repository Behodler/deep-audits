# Intent — stable-staker-v2-cutover (run-33, src 29aeb2b, PRE-BROADCAST, regression 884ccf8..29aeb2b)

Forge targets: `script/CutoverStableStakerV2Mainnet.s.sol` (`:preview`, `:broadcast`) + `script/helpers/StableStakerCutoverCore.sol`;
`script/VerifyStableStakerV2Cutover.s.sol` (`:verify`, new in story 086, inherits the cutover and overrides `run()`).
JS chain for `:broadcast`: `backup-mainnet-addresses.js` -> forge broadcast -> `patch-mainnet-addresses-stable-staker-v2.js` -> `:verify` -> `:preview`.

## Story authority (Law 2)
Each tag was globbed across the whole `~/code/product-owner/stories/phStaging2` tree and returned exactly one hit. All five sit in
`auto-complete/phStaging2-stable-staker-v2/`, a non-standard state folder. These stories were **machine-approved by the story-batch
workflow and not human-reviewed**, and their reviews ran with reduced independence (`--inline-delegation`).

| tag | file | commits | grades |
|---|---|---|---|
| story-082 | `082-mainnet-stable-staker-v2-cutover-script.md` | 272f94b, 7046127, 1c1608c | base intent. 083-086 supersede Decision 9, the preview-as-verification claim and the tautological 067 floor |
| story-083 | `083-cutover-wei-slack-and-v1-pauser-unregister.md` | bdbd850, 0855338 | WEI_SLACK 1000; V1 retire triple (moved to Phase 1 by 084) |
| story-084 | `084-cutover-close-global-pause-window.md` | 12a36ba | Phase-1 retire ordering, simulated global pause, Phase-8 registrant sweep (audit L-04, L-03b) |
| story-085 | `085-cutover-aggregate-principal-floor.md` | f453949 | real aggregate floor; lockstep rename (audit F-01) |
| story-086 | `086-cutover-readonly-post-broadcast-verifier.md` | 2f9ee1c, 29aeb2b | read-only verifier chained before preview (audit L-02) |

## Acceptance criteria vs the script at 29aeb2b (fork-checked at block 25981150)
### story-084
- [x] Phase 1 runs `setPauser(OWNER)` -> `Pauser.unregister(V1)` -> `pause()`, each step gated and read back (`_retireV1`, L329-348). Fork check: the breaker is live after every step except the forced single transaction between `setPauser` and `unregister` (`test_L04_breakerAtEveryPhase1StepAndPhase`).
- [x] The `V1 already paused - skipped` early return is removed. A resume converges.
- [x] Phase 7 keeps `_retireV1` as a backstop.
- [x] `IPauserRegistry` is extended. `_assertGlobalPauseWorks` runs at phase0, after-phase1 and after-phase8. Live preview at 25981150 shows `SUCCEEDED` with 26, 25 and 27 registrants.
- [x] Phase 8 sweeps every registrant.
- [ ] **Not met: the claim that the breaker "stays live all session"** (script NatSpec L35-36; `//:broadcast` doc key L52 says "for the whole Ledger session"). Phase 7 registers V2 with the Pauser (L606) while V2 is still paused, and does not unpause it until L614. `Pauser.pause()` reverts `EnforcedPause()` for those 3 transactions. A preview on a run halted there reverts at phase0 because the tolerance covers V1 only (`test_P7W_registeredWhilePausedWindow`). New candidate finding NEW-01.
### story-085
- [x] Loud requires: `P > 0` and `P >= v1Staked` (`_aggregatePrincipalFloor` L427).
- [x] Aggregate floor with saturating slack (L510-518). Fork falsification: a 5 bps DOLA exit haircut trips the floor on the resume/verifier shape, and the old lockstep passes it. A 1 bps haircut, inside the 2 bps bound, passes (`test_F01_*`).
- [x] The lockstep was renamed. It is still `>=`, while its revert string says `!=` (carried nit, not re-filed).
- [ ] **Gap: the floor treats a staker's permissionless `V1.userMigrate` self-exit during the Migrating window as a principal loss.** P includes the self-exited principal, but V2 never receives it. The result is a false "below floor" revert in `:verify` and in every resume or preview leg (`test_SX_*`). New candidate finding NEW-02.
### story-086
- [x] `run()` is virtual. The `_done*`/`_v1*` predicates are shared by the phase gates and the verifier.
- [x] The verifier is read-only, rejects `PREVIEW_MODE`, loads addresses with code checks and ignores `deploymentStatus`. **The live hydration path is now exercised end to end** on an anvil mainnet fork: a real `--broadcast` wrote the progress file (`cutoverStartBlock` 25981150), the patcher ran, and the real `:verify` passed with 29/29 per-user credits re-checked. Negative runs failed as expected: a regranted V1 mint, and `CUTOVER_START_BLOCK` set too late (vacuity guard).
- [x] Phase 1-7 done-condition requires, live re-plan, race detection, the story-085 floor, the story-084 sweep and Phase 8 are all present.
- [x] `:broadcast` chains `patch && :verify && :preview`. The `:preview` doc key no longer claims to verify.
- [x] Provider `eth_getLogs`: ranges of 5000, 20001 and 100001 blocks were accepted by the `RPC_MAINNET` provider (read-only probe).
- [ ] The verifier's floor inherits NEW-02: it can report principal loss on a correct cutover.
### story-083 / 082 (still in force)
- [x] WEI_SLACK is 1000. The planted 8-wei DOLA and 2-wei USDC dust positions pass (`test_L01_plantedDust`).
- [x] Every 082 purpose line below holds at the fork block. The preview passes end to end.
- [ ] The `package.json` `//StableStakerV2Cutover` (L49) operator comment is still stale (ledger Q-02, still live). It now also contradicts 084 ("pause V1", "V1 pauser back to Pauser and V1 UNPAUSED") and 085 ("strategy principal >= V2 booked"), and it does not mention `:verify`.

## Stated purpose (082 as amended by 083-086)
- [x] Phase 1: retire V1. It is unregistered from the Pauser before it is paused, and its pauser is OWNER.
- [x] Deploy Antimatter ("Antimatter"/"AM", owner OWNER), wired to phUSD and PhusdStableMinter.
- [x] Deploy StableStakerV2 and pause it before any addToken.
- [x] Per token: addToken, setClient, idle guard, setYieldStrategy, V1's buffer %, `antimatterPerDay = C*21/10`.
- [x] Mint rights: V2 on Antimatter; V2 and Antimatter on phUSD; two-sided minter delta (live mask 511 -> 510).
- [x] CrossVersionMigrator; per token relinquish surplus (DOLA 26.898 DOLA, USDC 27.043385 USDC), initiate, plan, batch-migrate (9/13/7 users, 0 stragglers), post-conditions.
- [x] Finalize: buffer recipients -> V2 (DOLA/USDC), revoke V1 mint, V2 and Antimatter -> Pauser and registered, V2 unpaused, claimEnabled false.
- [x] Phase 8 wiring and registrant sweep. Preview smoke tests pass.
- [x] Post-broadcast: `:verify` requires every phase from chain state and never performs a step.

## Declared pre-conditions (Phase 0 + run())
chainid 1; RATE 21/10; MIGRATE_CHUNK 1..50; STRAGGLER_CAP (0, 1 cent]; owner()==OWNER for V1, phUSD, Pauser, PhusdStableMinter and the 3 strategies;
V1 pauser in {Pauser, OWNER}; V1 token list non-empty; each token in the strategy map and == V1.yieldStrategy while Active; no strategy paused;
each token registered on PhusdStableMinter with matching decimals; V1 can mint phUSD while any pool is Active; phUSD minter baseline has the V1 bit
(or all pools Migrating); preview-only: simulated global pause at phase0 (tolerates a V1-only breakage).
Verifier adds: not PREVIEW_MODE; persisted minter baseline present; cutoverStartBlock set and not in the future.

## Declared post-conditions
- Phase 1: V1 pauser == OWNER, V1 not registered, V1 paused; preview after-phase1 global pause strict.
- Phases 2-5: identity and wiring read-backs; minter delta.
- Phase 6: pool Migrating; V1 principalOf == 0; stragglers < cap; strict batch progress; per-user `pre-post <= pre*bps + 1000`; V2 totalStaked == sum of stakers; **aggregate floor** `v2Staked >= (P - v1Staked)(1-bps) - n*1000`; lockstep `principalOf(V2) >= v2Staked`.
- Phase 7: no migratable V1 stakers; recipient == V2; V1 mint revoked; retire triple; V2/Antimatter pause wired; V2 unpaused; claimEnabled false.
- Phase 8: wiring requires plus a sweep of every registrant (unpaused, pauser == Pauser); preview after-phase8 global pause strict.
- Verifier: all of the above from chain state, plus per-(token,user) MigratedOut -> DepositedFor within the loss bound and `V2 userInfo >= credited`.

## Owner-trust framing (Law 3)
OWNER is non-malicious. NEW-01 is a footgun. Story 084 and the runbook tell the operator that the breaker stays live for the whole session, and that a halt is only dangerous between `setPauser` and `unregister`. A competent owner who halts inside Phase 7 would not expect the breaker to be dead, or the runbook's `:preview` to refuse to run. NEW-02 is not an owner action. Any V1 staker can trigger it by self-exiting, which is a designed escape hatch. NEW-03 (ETH budget) concerns operator preparation.
