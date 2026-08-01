# Intent — `promotion-ready:broadcast` (story 072)

Sources, in Law-2 precedence order:
1. **Story doc (authoritative)** — `~/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/072-mainnet-nudgestreamer-cutover-multitoken-batchminter-staker-v2-migration.md`, graded against the **"Revision 2026-08-01 — replanned against current upstream"** text, its `## Review Results`, `## Post-review corrections 2026-08-01` and the 11 `## Autonomous Decisions`.
2. The four `//`-prefixed `package.json` annotation keys (`//promotion-ready`, `//promotion-ready:dry`, `//promotion-ready:broadcast`, `//promotion-ready:resume`). **`promotion-ready:snapshot` has no annotation** despite being named a hard prerequisite by three of the other four.
3. `script/DeployMainnetPromotionReady.s.sol:30-132` NatSpec + per-phase docblocks.

Commit `5ae94bd` is itself a **comment-drift fix**; `d301059` recorded the pooler's creation-tx calldata as ctor-arg provenance. The story's own checklist demands **"every comment traceable to pinned source"** (line 1161), so comment-vs-code drift is graded as a first-class defect class here.

## Stated purpose — five coupled changes

- [x] **1. Deploy `NudgeStreamer(OWNER)`** and convert all six donors from "push USDC at the batch-minter" to "approve + `collectNudge` through the streamer", replacing the burst pot with linear release.
- [x] **2. Redeploy all four donor dispatchers** — `BalancerPoolerV2` (idx 4, six-arg ctor, prime token *derived* from sUSDS), `Uniboost` ×3 (idx 1/2/3), `NudgeRatchet` (idx 7, replacing the `NudgeRatchetDelayRelease` stopgap) — plus `StableYieldAccumulator` (no-arg ctor ⇒ broadcasting Ledger key becomes owner). Every live instance is a pre-streamer build (`nudgeStreamer()` reverts) so none can be patched in place.
- [x] **3. Replace the shared `BatchNFTMinter` with `BatchNFTMinterMultiToken`**, whitelist USDC/phUSD/Kendu, `registerStream` at 10/30/30 days as named constants, and route the rescued pot **through the streamer**, never onto the minter.
- [x] **4. Silently migrate** the three `NFTStakerDepletion` instances to `NFTStakerDepletionV2` via `NFTStakerMigrator` — zero user action.
- [x] **5. Retire the old batch minter** — `setPauser(OWNER)` + `pause()`, deliberately **NOT** registered with the global `Pauser`.

## Declared design invariants (the script's self-declared spec)

- [x] **Hooks are REPOINTED, not redeployed** (`:56-94`). Per index: `pull()` → `hook.setDispatcher(new)` → `newDispatcher.setHook(hook)` → `replaceDispatcher(idx, new)`. Fail-closed in one direction only; the reverse order leaks value silently.
- [x] **ZERO `phUSD.setMinter` calls in the whole script** ⇒ mint authority byte-identical **by construction**. `:68-73` explicitly states this is **not** asserted on-chain and defers to a post-broadcast HUMAN checklist item (post-review correction #1).
- [x] **Nothing about balances is assumed** (`:97-100`) — every figure read at runtime; abort on *structural* drift only.
- [x] **Phase 4d runs AFTER Phase 5** (Autonomous Decision 1) because the sixth donor (SYA) is repointed in Phase 5.
- [ ] **Kendu's fee-on-transfer gate is PROCEDURAL, not structural** — whitelist at `:640-644` is unconditional; the BLOCKING probe lives in Phase 8, which runs only under `PREVIEW_MODE`. Acknowledged in post-review correction #2.

## Declared pre-conditions (Phase 0, `require`-gated, no mutation)

- `owner() == OWNER` on all **17** mutation targets (minter, Pauser, old BM, 5 old dispatchers, old SYA, 5 hooks, 3 V1 stakers).
- Dispatcher slots 1/2/3/4/7 hold their pre-cutover dispatcher **or** the progress-file replacement (resume-aware, `_requireSlot` `:524`).
- Prime tokens: idx 4 == USDS (**pricing basis**, re-labelled after `nft-staking:032` deleted the whitelist tripwire), idx 1/2/3/7 == USDC.
- All six donor sinks still point at `OLD_BATCH_MINTER`.
- `nudgeStreamer()` **reverts** on all five live donor dispatchers (pre-streamer builds).
- Pooler ctor mirror: `sUSDS` / `pool` / `vault` / `psm` match constants. `router_` / `sUSDSIsFirst_` are `private immutable` with no getter — **structurally unassertable**; provenance is creation-tx calldata (`:204-213`).
- Five hooks: `dispatcher`, `recipient` un-drifted; ratio/`mintDebt` logged.
- `bptAtPhase0 > 0 || newPooler != 0` — refuse a fresh run against a zero-BPT pooler.
- Three V1 stakers: `stakedId`/`dispatcherIndex`/`rewardToken`/`stakedToken` un-drifted and `pauser() == global Pauser` (073 finding 2).
- Config gate in `run()` `:358-366`: durations 10/30/30 days, `NUDGE_SIZE == 40`, split in range, window 1..120, `SWEEP_HEADROOM_BPS` in range.
- **NOT declared:** any probe for `scripts/snapshots/depletion-stakers-latest.json`, despite it being a hard prerequisite. (Finding PR-03.)

## Declared post-conditions

**In-phase (assert-on-write):** stream buffer grew by exactly the amount sent and the streamer allowance returned to 0 (`:744-753`); `newBM` USDC balance **unchanged** across Phase 3; old BM USDC == 0; BPT conservation both ways (`:892-895`); rescue-destination deltas (`:1014-1015`); `price`/`growth` preserved across every `replaceDispatcher`; hook `mintDebt == 0` after each `pull()`; `old.paused()`; V1 `totalStaked == 0` and V2 `totalStaked == v2Before + preTotal`.

**Phase 7 (read-back, outside the broadcast/prank block):** 5 dispatcher↔minter triples; 5 hook↔dispatcher↔recipient pairs; 5 staker `dispatcherHook`; 6 donor→batch-minter; 6 donor→streamer; batch-minter whitelist/streams (10/30/30); Pauser registry **5 in, 4 out, retired minter deliberately absent**; migrator wired both sides ×3; V1 drained / V2 funded; SYA strategies/burner/registry swapped and old instance inert; retiring contracts drained; `newPooler` BPT `>= bptAtPhase0`.

**Phase 8 (PREVIEW only):** BLOCKING Kendu no-tax round trip; `MintPageView.getData()`; donor paths (idx 1, 4, 7) with the pooler verified **positively** via `BatchDonatedViaPSM` + no `DonationSkipped`; qualifying 40-mint `batchMint` after `vm.warp`; `BatchMint__ArrayLengthMismatch` negative test outside any prank block; BPT recovery path.

## Knowingly-accepted breakage (declared)

- Mints on indices 1/2/3/4/7 revert `OnlyDispatcher` intermittently for the duration of the Ledger session — "the correct failure direction".
- The **live mint UI is BROKEN** until a `phlimbo-ui` story ships a 3-element `minRewards` array + `getNudgeTokens()` re-fetch. Story line 1447: that follow-up story is **"still unraised"**.
- Two batch-minter ABIs coexist post-cutover.
