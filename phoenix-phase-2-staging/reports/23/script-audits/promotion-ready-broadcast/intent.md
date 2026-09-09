# Intent — story-072 promotion-ready suite (`promotion-ready:broadcast` + `:verify`)

Submodule HEAD `c4396b19aea6b7b09573ba90e2e65ca9293d20a1` (branch `master`).
Audited as a **suite** of 5 npm keys: `:snapshot`, `:dry`, `:broadcast`, `:resume`, `:verify`.

## Stated purpose

### From story-072 (authoritative — `complete/phStaging2-promotion-ready/072-…md`, 46 checklist items, 44 ticked)
One differential mainnet Ledger broadcast promoting nft-staking@9611312 / yield-claim-nft@9c18020 /
stable-yield-accumulator@6eab35c. Five coupled changes:

- [x] (1) Deploy `NudgeStreamer`; convert every donor from "push USDC at the batch minter" to
      "approve + `collectNudge` through the streamer" — **verified green in `:dry`** (Phase 1/3/4b/4c)
- [x] (2) Redeploy all four donor dispatchers — BalancerPoolerV2 (idx 4), Uniboost ×3 (idx 1/2/3),
      NudgeRatchet (idx 7) — plus StableYieldAccumulator — **verified green** (Phase 4a/4b/4c/5)
- [x] (3) Replace the shared BatchNFTMinter with `BatchNFTMinterMultiToken`; whitelist USDC/phUSD/Kendu;
      `registerStream` at 10/30/30 days — **verified green** (Phase 2; streams read 864000/2592000/2592000 s)
- [x] (4) Silently migrate the three `NFTStakerDepletion` instances to V2 via `NFTStakerMigrator`
      — **verified green** (Phase 6; conservation OK at 2 / 156 / 13 units)
- [x] (5) Retire the old batch minter (`setPauser(OWNER)` + `pause()`) — **verified green** (Phase 4d)
- [x] Hooks REPOINTED not redeployed ⇒ **zero `phUSD.setMinter` calls** — confirmed: no `setMinter` on
      PHUSD anywhere in the closure; mint-authority mask read 270080 / mintVersion 0, unchanged
- [x] Per-index order `pull()` → `hook.setDispatcher(new)` → `new.setHook(hook)` → `replaceDispatcher(idx)`
      (fail-closed) — confirmed in `:dry` log for all five indices
- [x] Price/growth preserved across every `replaceDispatcher` — confirmed
      (idx4 `16571277525846989826/1`, idx1 `10002000/2`, idx2 `10318873/2`, idx3 `10022018/2`, idx7 `70000000/0`)
- [x] BPT conserved old → new pooler — confirmed (`16867526417628291567945`, full position moved)
- [ ] **line 1195 — post-broadcast HUMAN check** (on-chain confirmation of the whole end state).
      Largely discharged mechanically by story-075's `:verify`; **quotes stale expected figures** (see F-05).
- [ ] **line 1197 — post-broadcast HUMAN check**: trigger one index-4 mint and assert `BatchDonatedViaPSM`
      fired. **Explicitly NOT discharged by `:verify`** (verifier's own run() epilogue says so). See F-01.

### From story-074 (`auto-complete/phStaging2-audit-fixes/074-…md`) — closes run-22 **L-02**
- [x] Persist the Phase-0 BPT reading as write-once `baselines.bptAtCutover` (decimal STRING, top-level
      sibling of `contracts`) so it survives hand-trimming across resume legs
- [x] Phase 7 conservation assertion made non-vacuous
- [x] Phase 0 ABORTS rather than silently re-deriving 0 when `pooler_bpt` is configured but the baseline is absent
- [x] Monotonic floor `bptAtPhase0 = max(persisted, live)`
- Story states: *"weakening any rail re-classifies L-02 as Medium."* **No rail is weakened — rails were added.**

### From story-075 (`auto-complete/phStaging2-audit-fixes/075-…md`) — closes run-22 **M-01**
- [x] Standalone read-only `forge script` re-runs Phase 7's absolute wiring assertions against LIVE
      post-broadcast state
- [x] Consumes story-074's persisted baseline and NEVER re-derives it (no live-read fallback)
- [x] Adds a phUSD mint-authority invariance check that existed on no path before
- [x] Chained onto `:broadcast` and `:resume` with `&&`; every check a `require`
- [x] Source-level guard test pins read-only-ness
- [x] **line 396 — `npm run promotion-ready:dry` against live mainnet.** Was UNTICKED
      ("Autonomous Decision 2: no RPC in the headless environment"), described by the story as its
      **primary regression gate**. **DISCHARGED BY THIS AUDIT — executed, exit 0, all 8 phases green.**

## Declared pre-conditions (Phase 0, `require`-gated, no mutation) — all PASSED on live state
- Configuration-safety gate: `DURATION_USDC == 10 days`, `DURATION_PHUSD == DURATION_KENDU == 30 days`,
  `NUDGE_SIZE == 40`, `0 < DONATION_SPLIT <= 100`, `1 <= DEPLETION_WINDOW_MONTHS <= 120`,
  `0 < SWEEP_HEADROOM_BPS < 10000` (`:382-398`)
- `block.chainid == 1` in both `setUp()` and `run()`
- All **17** mutation targets `.owner() == OWNER` (`:455-473`)
- Dispatcher lineup at 1/2/3/4/7 resume-aware (`:477-482`)
- Prime tokens: idx4 == USDS (pricing basis), idx1/2/3/7 == USDC (`:492-497`)
- All six donors point at the shared old BatchNFTMinter
- `nudgeStreamer()` reverts on every live donor ⇒ pre-streamer builds confirmed
- BPT baseline: `bptAtPhase0 = max(persisted, live) > 0` (`:549`, `:571`)
- RESUME ABORT if `_isConfigured("pooler_bpt") && !bptBaselineFromProgressFile` (`:564`)
- phUSD mint-authority baseline RECORDED (mask 270080, mintVersion 0) — records, never aborts
  (story-075 Autonomous Decision 4)

## Declared post-conditions (Phase 7 read-back) — all PASSED
- 5 indices repointed both ways; 5 dispatcher↔hook pairs met; all six donors → new batch minter and → streamer
- 3 streams armed at 10/30/30 days; Pauser registry 5 in / 4 out, retired minter deliberately absent
- V1 drained / V2 funded / migrators wired both sides; SYA strategies+burner+registry swapped, old inert
- Retired contracts drained; `balanceOf(OLD_POOLER) == 0`;
  **`balanceOf(newPooler) >= bptAtPhase0`** (`:1725` — the L-02 fix) plus the stopgap floor (`:1729`)

## Declared post-conditions (`:verify`, story-075) — could not execute (correctly)
- Rejects `PREVIEW_MODE` (`:97`); requires progress file + all 14 addresses non-zero (`:105-131`)
- Requires `baselines.bptAtCutover` present AND `> 0`, no fallback (`:147-154`)
- Re-runs `_phase7_wiringAssertions()` against live state; phUSD mint-authority invariance (`:169-208`)

## Preview-only checks (Phase 8 — `if (isPreview)` ONLY, never on the broadcast path)
All executed green in this audit's `:dry` run:
- Kendu fee-on-transfer probe (**BLOCKING**): sent == received == credited == 1e24 ⇒ "NOT fee-on-transfer"
- `MintPageView.getData()` resolved, 39 rows
- Donor paths incl. **positive `BatchDonatedViaPSM == true` / `DonationSkipped == false`** on the pooler
- 40-mint qualifying batch after `vm.warp(+1 day)`; `ArrayLengthMismatch` negative test; BPT recovery path
