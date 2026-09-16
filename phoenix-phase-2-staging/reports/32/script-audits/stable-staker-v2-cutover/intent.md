# Intent — stable-staker-v2-cutover (run-32, src 884ccf8, PRE-BROADCAST)

Script: `script/CutoverStableStakerV2Mainnet.s.sol` + `script/helpers/StableStakerCutoverCore.sol`;
JS chain (broadcast only): `scripts/backup-mainnet-addresses.js` -> forge -> `scripts/patch-mainnet-addresses-stable-staker-v2.js` -> `:preview`.

## Story authority (Law 2)
Every glob below searched the whole `~/code/product-owner/stories/phStaging2` tree and returned exactly one hit.

| tag | path | state |
|---|---|---|
| story-083 (authoritative for the delta) | `auto-complete/phStaging2-stable-staker-v2/083-cutover-wei-slack-and-v1-pauser-unregister.md` | `auto-complete`: a non-standard state folder, machine-approved and not human-reviewed |
| story-082 (base script; 083 supersedes its Decision 9) | `auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md` | `auto-complete`: non-standard, machine-approved |
| story-080 (DeployMocks rehearsal, "THE TEMPLATE") | `auto-complete/phStaging2-stable-staker-v2/080-deploymocks-stablestakerv2-antimatter-cutover.md` | `auto-complete` |
| story-067 (zero-haircut floor) | `complete/phStaging2-ys-induced-stable-staker-migration-script/067-enforce-zero-haircut-floor-gate.md` | complete |
| story-062 (pause-window pattern) | `complete/phStaging2-ys-induced-stable-staker-migration-script/062-harden-ys-swap-migration-against-midsuite-halt.md` | complete |

Commits in the delta: `bdbd850` and `0855338` are `[story-083]`. `884ccf8` is untagged ("udpates") and changes only DeployMocks and anvil artefacts.

## Story-083 acceptance criteria vs the script at 884ccf8
- [x] `WEI_SLACK` changed 2 -> 1000, with NatSpec (L108-112). The `_maxLossBps` NatSpec is corrected (0855338).
- [x] `IPauserRegistry.unregister(address)` added (L969).
- [x] Phase 7 V1 block runs `setPauser(OWNER)` (gated), then `Pauser.unregister(V1)` (gated on `isRegistered`), then `pause()` if not paused. Each step has a read-back require (L554-568).
- [x] The V1 block runs BEFORE V2's pauser hand-back, which is the finalized marker (L570).
- [x] Phase 8 asserts V1 pauser == OWNER, V1 not registered, and V1 paused (L635-637).
- [x] Phase 0/1 resume logic is consistent. Fork-proven: resume after unregister-only, resume after the V2 pauser hand-back, and a full re-run after completion all pass (R1/R2/R3).
- [x] The patch-script comment now says V1 is "paused, and unregistered from the Pauser".
- [ ] NOT in 083's scope but carried forward as non-blocking: DeployMocks still uses a +2 wei slack and still leaves the dev V1 registered and unpaused. The `package.json` `//StableStakerV2Cutover` comment was also not updated (see drift findings).
- [ ] NOT addressed by 083 or 082: the Phase 1 -> Phase 7 window, in which V1 is paused, its pauser is OWNER, and it is still registered, bricks `Pauser.pause()` (new finding).

## Stated purpose (package.json comment + NatSpec + stories)
- [x] Pause V1 for the cutover window (story 062 pattern)
- [x] Deploy Antimatter (name "Antimatter", symbol "AM") owned by OWNER, wired to phUSD and PhusdStableMinter
- [x] Deploy StableStakerV2 and pause it before any `addToken`
- [x] Configure each V1 token from V1's live config: addToken, setClient, idle guard, setYieldStrategy, buffer copied from V1, `antimatterPerDay = C*21/10`
- [x] Mint rights: Antimatter.setApprovedMinter(V2), phUSD.setMinter(V2), phUSD.setMinter(Antimatter), plus a two-sided minter delta
- [x] CrossVersionMigrator with setMigrator on both stakers; per token: relinquish surplus, initiate, plan with the dust predicate, batch-migrate, post-conditions
- [x] Finalize: buffer recipient -> V2, revoke V1 phUSD mint, **retire V1 (pauser OWNER, unregistered, left PAUSED — story 083)**, V2 + Antimatter pauser -> Pauser and registered, V2 unpaused, claimEnabled false
- [x] Phase 8 wiring assertions; preview-only smoke tests

## Declared pre-conditions (Phase 0 + run())
- chainid == 1; RATE 21/10; MIGRATE_CHUNK in 1..50; STRAGGLER_CAP in (0, 1 cent]
- owner() == OWNER for V1, phUSD, Pauser, PhusdStableMinter, and each of the three strategies
- V1 pauser in {Pauser, OWNER}
- V1.getStakedTokens() is non-empty; each token is in the hard-coded strategy map and == V1.yieldStrategy(t) while the pool is Active
- no strategy is paused
- every token is registered on PhusdStableMinter with matching decimals
- V1 can mint phUSD while any pool is Active
- phUSD minter baseline mask has the V1 bit set (or every pool is Migrating); mintVersion is recorded

## Declared post-conditions
- Phases 2-5: read-backs (Antimatter name/symbol/owner/phUSD/minter; V2 version/antimatter/owner/paused; client, strategy, buffer, rate, autoAnnihilateAvailable; minter grants plus delta)
- Phase 6: migrator wiring and versionOf probes; each pool Migrating; V1 principalOf == 0; stragglers < cap; strict batch progress; per user, post > 0, post <= pre, and `pre - post <= pre*maxLossBps/1e4 + 1000`; V2 totalStaked == sum of stakers; "067 floor" `principalOf(V2) >= V2.totalStaked` (tautological, ledger F-01)
- Phase 7: no migratable stakers remain; buffer recipient == V2; V1 mint revoked; V1 pauser == OWNER, unregistered, paused; V2 unpaused; claimEnabled false
- Phase 8: 59 wiring requires, including the V1 retirement triple and V2/Antimatter registered

## Owner-trust framing (Law 3)
OWNER is non-malicious. The Phase 1 -> 7 pause brick is a footgun, not an owner attack. A competent owner following story 083 would expect the global breaker to work once they have cleared the pre-paused registrants. Story 083's own premise is that "once V1 is unregistered, that risk is gone", but that holds only for the end state.
