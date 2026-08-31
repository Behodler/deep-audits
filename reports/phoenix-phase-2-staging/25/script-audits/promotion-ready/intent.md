# Intent — promotion-ready (phoenix-phase-2-staging @ 712cbdb, branch master)

Regression baseline `b9391b1`. Delta = story 077 (`src/views/DepositPageViewV3.sol`) +
story 078 (Phase 4f wiring, view-key collapse 58→55, `_parseProgressJson` hydration).
Both stories sit in `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-promotion-ready/`
(**auto-complete** = machine-approved, never human-reviewed; story 076 went to `complete`).

---

## Stated purpose — per npm key

### `promotion-ready:snapshot` (prerequisite, no forge, no broadcast)
- [x] `snapshot-depletion-stakers.js` → V1 depletion-staker list
- [x] `snapshot-phlimbo-v2-stakers.js` → `scripts/snapshots/phlimbo-v2-snapshot-latest.json`
      (verified present, block 25678190, 16 users, 11.0h old at audit time)

### `promotion-ready:dry` (**the preview variant** — the one this audit executed)
- [x] `check-phlimbo-snapshot-age.js --variant v2 --fail-on-stale` (gate)
- [x] `PREVIEW_MODE=true forge script … --rpc-url $RPC_MAINNET --slow -vvv`
- [x] Impersonates OWNER, signs nothing, broadcasts nothing
- [x] Writes **no** progress file (`_trackDeployment`/`_trackConfig` are `isPreview`-gated) —
      a preview CREATE address is fork-local fiction and would poison the patcher
- [ ] **Its `//promotion-ready:dry` doc key was NOT updated for Phase 4f** although `:dry`
      executes `_phase0_depositViewPreconditions()`, `_phase4f_depositViewCutover()`,
      `_phase7_depositViewAssertions()` and `_probeDepositPageView()`

### `promotion-ready:broadcast` (LIVE — never executed by this audit)
- [x] snapshot gate → `backup-mainnet-addresses.js` → forge `--broadcast --skip-simulation
      --slow --ledger --legacy --with-gas-price 0.5gwei --gas-estimate-multiplier 200`
- [x] → `patch-mainnet-addresses-promotion-ready.js` (MANDATORY, final state-mutating element)
- [x] → `npm run promotion-ready:verify` (read-only outcome verification, story 075)
- [x] Doc key **was** updated for story 078: names Phase 4f, its two extra Ledger sigs, and
      the 55-key set

### `promotion-ready:resume` (LIVE — never executed by this audit)
- [x] Identical to `:broadcast` **minus** `backup-mainnet-addresses.js`
- [ ] Doc key **NOT updated** for Phase 4f, though `:resume` runs it

### `promotion-ready:verify` (read-only)
- [x] `VerifyPromotionReady` inherits `DeployMainnetPromotionReady`, re-runs the whole
      `view`-only `_phase7_wiringAssertions()` against live post-broadcast state
- [x] Story 078 raised runtime addresses 16→17 and the `_requireNotPhusdMinter` sweep 15→16
- [ ] Doc key not amended for 4f

---

## Stated purpose — Phase 4f (the delta), from story 078 + NatSpec

- [x] Deploy `DepositPageViewV3(IPhlimboV3(newPhlimboV3), IERC20(PHUSD))` **after** Phase 4e
      (the view's `phlimbo` is immutable, so the V3 must already exist) and **before** Phase 5
- [x] `ViewRouter.setPage(keccak256("deposit"), …)` as the phase's **last** step — repointing
      earlier would show not-yet-migrated users a zero-balance V3 page
- [x] Fix the live bug: `pages("deposit")` has never once been repointed and still names
      `DepositPageView 0x50D4…03b8`, baked to **PhlimboEA V1**
- [x] Mint **no** address-book key for the new view — `ViewRouter` is the sole view key
- [x] Collapse `DepositView` / `DepositPageView` / `MintPageView` out of the address books
      (58→55), leaving `ViewRouter` as the only view-related key

## Declared pre-conditions

`_phase0_depositViewPreconditions()` (Phase 0, read-only, before any mutation):
- `VIEW_ROUTER.code.length > 0`
- `IViewRouterLike(VIEW_ROUTER).owner() == OWNER`
- incumbent `pages(DEPOSIT_KEY)` is **logged, deliberately not asserted** — pinning it would
  abort the very run that fixes it

`_phase4f_depositViewCutover()` (in-phase, before the broadcast body):
- `newPhlimboV3 != address(0)` ("Phase 4e must run first")
- `IViewRouterLike(VIEW_ROUTER).owner() == OWNER` (re-checked; `setPage` would otherwise
  revert with an opaque `OwnableUnauthorizedAccount`)

## Declared post-conditions

In-phase, immediately after the two mutations:
- `address(DepositPageViewV3(newDepositPageViewV3).phlimbo()) == newPhlimboV3`
- `address(DepositPageViewV3(newDepositPageViewV3).phUSD()) == PHUSD`
- `IViewRouterLike(VIEW_ROUTER).pages(DEPOSIT_KEY) == newDepositPageViewV3`

`_phase7_depositViewAssertions()` (`view`; re-run post-broadcast by `VerifyPromotionReady`):
- `newDepositPageViewV3 != address(0)` and `newPhlimboV3 != address(0)`
- `pages(DEPOSIT_KEY) == newDepositPageViewV3`
- `v.phlimbo() == newPhlimboV3` — *the assertion that matters*: pointer-equality alone
  would have passed happily throughout the V1→V2 era
- `v.phUSD() == PHUSD`
- `router.getNames(DEPOSIT_KEY).length == 23` and `router.getData(DEPOSIT_KEY, OWNER).length == 23`
  (exactly 23, not `>=`; story 078 §8 decision)

`VerifyPromotionReady` additions:
- `_requireResolved(newDepositPageViewV3, "DepositPageViewV3")` (17 runtime addresses)
- `_requireNotPhusdMinter(newDepositPageViewV3, "DepositPageViewV3")` (16 swept)

Phase 8 (`_probeDepositPageView()`, preview-only, **warns rather than reverts**):
- resolves `pages(DEPOSIT_KEY)`, warns if unregistered or ≠ this run's view
- `staticcall` `getNames`/`getData` through the router, warns on revert or length ≠ 23
- prints all 23 named field values for human eyeball

## Declared build premise — FALSE, and known to be false

Both stories 077 (:300) and 078 (:310) state as a load-bearing premise: *"Builds here use
legacy pipeline + optimizer, `via_ir` OFF. Do not turn `via_ir` on."* `foundry.toml:7` has
`via_ir = true` and always has. Story 077 **discloses and disposes of this itself**
(Autonomous Decision 1, and a self-filed `[low]` at :573). Measured under the real pipeline —
no EIP-170 exposure (see `side-effects.json.bytecodeSizes`).
