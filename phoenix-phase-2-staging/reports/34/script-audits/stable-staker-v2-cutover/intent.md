# Intent — stable-staker-v2-cutover (run 34, regression 29aeb2b..84e2324)

Source commit `84e2324` (merge of `9ea09d5` [story-087] + `3275151` [story-087] NatSpec polish).
Untagged `0a497f5` / `49d7804` touch only `src/mocks/MockAutoDOLA.sol`, its test and anvil artefacts (DeployMocks consumers only; no intersection with either cutover forge target).

## Authoritative story documents (Law 2)
Resolved by globbing `~/code/product-owner/stories/phStaging2` (one hit each):
- 082 `auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md` (base script)
- 083 `…/083-cutover-wei-slack-and-v1-pauser-unregister.md` (WEI_SLACK 1000, V1 retirement)
- 084 `…/084-cutover-close-global-pause-window.md` (Phase 1 unregister-before-pause, preview breaker stages)
- 085 `…/085-cutover-aggregate-principal-floor.md` (aggregate floor — superseded by 087)
- 086 `…/086-cutover-readonly-post-broadcast-verifier.md` (`:verify`)
- **087** `…/087-cutover-audit33-breaker-window-selfexit-gate-eth-preflight.md` — the story under regression (30 acceptance items, sections A–E)

### Governance observations (surface to the human; not code findings)
- All of 080–087 sit in an `auto-complete/` state folder that is **not** in the documented state set (`complete|incomplete|review|archive`). Each carries an `## Auto-Completed` stamp "Approved by: story-batch workflow (machine approval — not human-reviewed)".
- 087 was auto-completed with **Review Status: ISSUES_FOUND**, triaged "non-blocking". Carried-forward issue: the archived `preview-mainnet.log` and `anvil-broadcast-preflight-refusal.log` predate the final build (superseded `max(env, tx.gasprice)` formula; in-EVM OWNER balance read).
- Every step of 087 (execution, review, polish, auto-complete) ran with `--inline-delegation`; the story itself records "Independence: reduced".
- Timestamp inconsistency: the `Auto-Completed` stamp and `Base Commit Updated` are dated `2026-09-15T23:46:26Z`, *earlier* than the Autonomous Decisions (`2026-09-16T00:20Z`) and Review (`2026-09-16T02:05Z`) it claims to act on.
- Checklist E3 ("Run `:preview` against mainnet RPC; confirm every `GLOBAL_PAUSE|…|SUCCEEDED` stage") is ticked `[x]`, but the story's own Verification Results say the live preview **failed in Phase 6** at block 25985945 (stages after-phase6..8 never ran live). Run 34 supplies the missing evidence: at block 25988932 all nine stages SUCCEED (see side-effects.json).
- 087 "FOR THE HUMAN": `ERC4626_MAX_LOSS_BPS = 2` is too tight for live autoDOLA; deliberately not retuned (Concerns rule out retuning bps constants). That is a **knowing** owner deferral (Law 3). Run 34 found the constraint is block-regime dependent (see candidate finding L-08-candidate).

## Stated purpose (story 082 base + 083–087 amendments; `//StableStakerV2Cutover` restates it)
- [x] Phase 0: preconditions (owners, pausers, strategy map, PhusdStableMinter registration, phUSD minter baseline)
- [x] Phase 1: retire V1 — `setPauser(OWNER)` → `Pauser.unregister(V1)` → `pause()`; V1 left paused, pauser OWNER, unregistered (084)
- [x] Phase 2: deploy Antimatter (name Antimatter / symbol AM, owner OWNER), wire phUSD + PhusdStableMinter
- [x] Phase 3: deploy StableStakerV2, `setPauser(OWNER)` + `pause()` before any `addToken` (V2 unregistered)
- [x] Phase 4: per V1 token: addToken / setClient / idle guard / setYieldStrategy / buffer copy / antimatterPerDay = V1 phusdPerSecond·86400·2.1
- [x] Phase 5: grant V2 Antimatter mint, V2 phUSD mint, Antimatter phUSD mint; two-sided minter delta
- [x] Phase 6: CrossVersionMigrator + setMigrator both sides; per token relinquish surplus → initiate → plan (dust predicate, 1-cent straggler cap) → batch migrate (25) → post-conditions
- [x] Phase 7 (087 order): buffer recipient → V2; revoke V1 phUSD mint; V1 retirement backstop; **V2 setPauser(Pauser) → V2 unpause → register(V2) → Antimatter setPauser(Pauser) → require(!antimatter.paused()) → register(Antimatter)**; claimEnabled stays false
- [x] Phase 8: wiring assertions incl. registrant sweep (every registrant unpaused, pauser == Pauser)
- [x] (087 L-07) broadcast refuses to start unless on-chain OWNER ETH ≥ 22,000,000 · CUTOVER_GAS_PRICE_WEI · 1.2; preview logs `ETH_BUDGET|OK|SHORTFALL`
- [x] (087 L-05 class check) preview proves the permissionless breaker strictly after every phase (9 stages)
- [x] (087 L-06) loss gate anchored on V1's immutable `(R, P)`: exit-realization bound; verifier adds a self-exit-net aggregate

## Declared pre-conditions (require before/at start)
- `block.chainid == 1`; `MIGRATE_CHUNK ∈ [1,50]`; straggler cap ∈ (0, 1 cent]
- progress-file addresses must have code (else "trim the progress file" abort)
- Phase 0: owners/pausers/strategy map/minter registration as expected; strategies not paused ("Phase0: strategy paused")
- broadcast only: `CUTOVER_GAS_PRICE_WEI` set and `eth_getBalance(OWNER) ≥ required` (`_preflightOwnerEth`, S L319)
- preview only: `GLOBAL_PAUSE|phase0` (V1-only tolerant)
- Phase 6 initiate: market-exit pre-quote ≥ minOut; ERC4626 `maxRedeem ≥ shares`; `maxDeposit ≥ migratable credit`; stragglers < cap

## Declared post-conditions (require after each step)
- Phase 1/7: V1 pauser OWNER, unregistered, paused
- Phase 6 (`_assertPoolPostMigration`, core L471-535): V1 Migrating; V1 stakerCount == stragglers; V1 totalStaked == straggler principal; per user (this leg) `pre − post ≤ pre·bps/10000 + 1000 wei` (2 bps ERC4626, 61 bps USDe); V2 totalStaked == Σ V2 stakers; **exit-realization bound** `(min(R,P) + 1000) · 10000 ≥ P · (10000 − bps)`; lockstep `strategy.principalOf(V2) ≥ V2 totalStaked`
- Phase 7: `_doneV2Unpaused` before register; `_doneV2PauseWired`, `_doneAntimatterPauseWired`, `_doneClaimStillDisabled`
- Phase 8: phUSD minter delta (only V1 bit cleared), Antimatter minter set {V2}, per-pool wiring, registrant sweep
- preview only: strict `GLOBAL_PAUSE|after-phase1..8|SUCCEEDED`, smoke tests
- `:verify` (post-broadcast, read-only): every phase done-condition on chain; realization bound; per-user credit→credited ≤ bps + 1000 wei for non-self-exit `MigratedOut`; per-pool `V2 booked ≥ (P − v1Staked − selfExitedUpperBound)·(1−bps) − nMigrated·1000`; vacuity guard keyed on `P > v1Staked + selfExited + stragglerCap`
