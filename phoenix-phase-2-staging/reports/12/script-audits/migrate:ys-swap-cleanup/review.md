# Script Review — `migrate:ys-swap-cleanup`

**Entry point:** `migrate:ys-swap-cleanup` (broadcast) / `migrate:ys-swap-cleanup-preview`
**Forge target:** `script/PostMigrationCleanup.s.sol:PostMigrationCleanup` — `run()`
**Story:** Story 060 — yield-strategy swap migration (June 12 2026), **step 5/5 (final)**
**Commit:** `b27c6ac`
**Intent doc:** `docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md` (Step 6 + Set-Aside Buffer + Post-Migration Options)
**Fork verification:** mainnet fork @ block 25297401 (advanced to 25297403), chainId 1

---

## Verdict

The YS-swap migration itself **succeeded end-to-end** — the fork withdraw smoke-test proves a migrated USDC staker withdrew their full principal (9,997,602 → 9,996,436 USDC received plus phUSD reward, `userInfo.amount → 0`, tx status 1) through the V2 `autoUSDC` redeem path, confirming the story-060 `convertToAssets`/`_acquireShares` fix works and users are restored. The **finalizer script, however, bricks itself**: it reverts at verify-5b on the very state the migration correctly produces (a USDC buffer 51× over a wrong "skim sanity band"), so it never reaches its sole mutation and the temp staker's phUSD minter authorization is never revoked. On top of that revert, two cluster-level items are silently left dangling — migrator2 still set on the live original staker, and the SYA never repointed to the V2 strategies. The underlying chain state is solvent; this is an availability/operational-integrity problem in the finalizer, not a loss of funds.

---

## 1. Does it do what it intends?

### Stated intent
`PostMigrationCleanup` is a **verify-then-revoke** finalizer. Per NatSpec and doc Step 6 it should:

1. Run **12 read-only `require` verifications** that the YS-swap migration left a consistent end-state.
2. Perform its **sole mutation** — `phUSD.setMinter(tempStaker, false)`, revoking the temp staker's phUSD minter authorization.
3. Declare the migration COMPLETE.

The 12 verifications gate the revocation: temp staker fully drained (V1a/1b), original repopulated to leg-2 counts (V2/V3), V2 principal positive (V4/V5), **hard solvency** `principalOf >= totalStaked` (V4b/5b), per-token **skim sanity band** (V4b-band/V5b-band, conditional on a non-zero skim), withdrawals re-enabled (V6/V7), 10% set-aside buffer size + recipient on both V2 strategies (V8–V11), and the USDe skim balance (V12, conditional).

### What the fork shows
The preconditions all pass (chainid==1, both input JSON files parse, `phUSD.owner() == 0xCad1…D0B6`). Of the 12 post-conditions, **11 pass on the real post-migration state** — including both hard-solvency checks (`ysDolaV2.principalOf` 1060.128 ≥ `totalStaked` 1033.350; `ysUsdcV2.principalOf` 1981492890 ≥ `totalStaked` 1954262977). The single failure is **V5b-band**.

So the verification logic is *mostly* correct and the state it is checking is genuinely healthy — the migration produced a solvent, repopulated, withdrawal-enabled end-state, and the smoke-test confirms users are whole. But the script **does NOT achieve its intent**, because it reverts before reaching the revoke, leaving its sole mutation un-executed. See finding **YS-10** below.

The hard-solvency portion of the gate (the part that actually matters for safety) *does* pass; it is the *diagnostic* band that the finalizer wrongly hard-asserts that fails.

---

## 2. Does it introduce unintended side effects?

**No.** The closure-mapper's claim of a single mutation is confirmed **EXACTLY** on the fork: the `-vvvv` trace shows one SSTORE-bearing external call and one event across the whole run.

- **Intended mutation:** `phUSD.setMinter(tempStaker, false)` — `_authorizedMinters[tempStaker].canMint: true → false`, emitting `MinterSet(tempStaker, canMint=false, mintVersion=0)`.
- **Unintended mutations:** none. The other 11 external calls are read-only views (`stakerCount` / `poolInfo` / `principalOf` / `withdrawDisabled` / `setAsideBufferSize` / `setAsideBufferRecipient` / `balanceOf`). No clobbering of unrelated state. Although `foundry.toml` grants read-write `fs_permissions` on `script/migration-inputs/`, this script performs **no file writes** — uniquely among the story-060 broadcast legs it leaves `mainnet-addresses.ts` untouched (that doc step-6 item is correctly delegated to `migrate:ys-swap-reset`'s patch JS).

The important caveat: **the script REVERTS before it ever reaches that one intended mutation**. So in practice, as written, it introduces *zero* side effects — not because it is side-effect-free by design, but because it never gets that far. To capture the post-mutation side-effect surface at all, the auditor had to apply the **FX-4 fixup** (below). With the band removed, the single intended mutation executes cleanly and is the only state write.

> **FX-4 (auditor fork-fixup):** cloned the script as `PostMigrationCleanupFX4` with the two `[skim/2, skim*2]` band requires (V4b-band, V5b-band) **neutralized** and the hard-solvency requires **retained**. This mirrors the recommended remediation for YS-10; it is not a fork artifact. With FX-4 the preview no longer reverts, the broadcast executes, all 12 (remaining) verifications pass, and the temp staker's minter is revoked. This is how the side-effect ledger above was captured.

---

## 3. Have other problems surfaced because of it?

Two cluster-level gaps that this final-gate step is uniquely positioned to catch — and does not. Both are skipped-step omissions across the story-060 suite that cleanup, as "the last gate", inherits responsibility for.

### (a) migrator2 left set on the live original staker — **YS-11 (Low)**
No story-060 script ever calls `original.setMigrator(address(0))` after leg 2. Cleanup revokes the phUSD minter but neither clears nor verifies the migrator. On the fork, after cleanup, both `original.migrator()` and `tempStaker.migrator()` still return migrator2 (`0xd263…FFfC`), an immutable `StableStakerMigrator(old=temp, new=original)`. Because `StableStaker.initiateMigration` is `onlyMigrator`, migrator2 remains an authorized path to **terminally migrate the live, repopulated original pool**: one owner call to `migrator2.initiateMigration(DOLA/USDC)` would freeze emissions, realize+decouple the V2 strategy, set the pool `active=true` (irreversible — no resume path), and thereafter expose a **permissionless `userMigrate`**. The intent doc's "Post-Migration Options" only justifies leaving the migrator set for *optional surplus re-injection* and frames revocation as the expected terminal action ("do it before revoking migrator permissions"). Leaving it standing after a step whose own summary prints "migration COMPLETE" is therefore an **undocumented, non-obvious privileged surface** — a Law-3 owner footgun, in scope as an operational hazard.

This is **distinct** from the stable-staker ledger item **ss9l1** (`finalizeAndReset` emission/strategy reset): ss9l1 is a *contract-function* omission, whereas YS-11 is a *deployment-script* omission (no `setMigrator(0)` revocation step). Cross-link only, not a duplicate.

### (b) SYA never repointed to the V2 strategies — folded into **YS-03 (Medium, deploy entry)**
The doc bills step 6 as "verify final state". Cleanup verifies V2 principal, buffer *size* (==10) and buffer *recipient*, but never verifies that the StableYieldAccumulator (SYA) / minter client was repointed to, or registered as a withdrawer/client on, the V2 strategies. No story-060 script touches the SYA. Its strategy registry and 25% buffer config still point at the **old, post-skim-drained** DOLA/USDC strategies; the V2 strategies have only the StableStaker as a 10% client. Consequence: post-swap DOLA/USDC organic yield is **uncollectable on the SYA side**, and the 10% buffer cleanup proudly verifies (V8/V10) is **dead config with no consumer**.

The economic loss (silently severed yield collection on the two largest staker pools) is owned by **YS-03**, rooted at the deploy entry (`DeployTempStableStakerAndMigrators.s.sol:185-193`). The **missing-verification angle** — that cleanup is the *last place the suite could have caught this and instead green-lights the dead-buffer config* — was deliberately **folded into YS-03's recommendation** rather than reported separately, to avoid telling the reader the same gap twice. The folding preserves the "last gate should have asserted a consumer exists for the buffer it checks" recommendation as the second half of YS-03's fix. It adds a fix location, not severity.

---

## Findings at this entry point

| ID | Severity | Title | Source |
|----|----------|-------|--------|
| **YS-10** | **Medium** | verify-5b USDC skim band reverts on the very state the migration produces, bricking the finalizer (temp minter never revoked) | `findings/medium/YS-10-cleanup-buffer-band-wrong-postcondition.json` |
| **YS-11** | **Low** | Story-060 leaves migrator2 set on the live original staker after declaring migration COMPLETE — standing terminal-migration footgun | `findings/low/YS-11-standing-migrator-after-complete.json` |
| YS-03 | Medium (deploy entry) | SYA not repointed to V2; cleanup never verifies SYA wiring (missing-verification angle folded in) | `findings/medium/YS-03-SYA-not-repointed-to-V2.json` |

### YS-10 — the headline (Medium)
**Location:** `lib/phoenix-phase-2-staging/script/PostMigrationCleanup.s.sol:197-202`
**Root cause:** `WrongPostConditionInvariant`

The per-token "buffer sanity band" requires
`buffer = principalOf(token, original) - poolInfo(token).totalStaked ∈ [<token>Skimmed/2, <token>Skimmed*2]`,
on the script's own stated premise (comment L169-180) that `buffer ≈ <token>Skimmed`. **That premise is false.** The buffer is dominated not by the leg-1 *skim* but by the leg-1 `initiateMigration` **realize-over-credit surplus**: `initiateMigration` realizes the whole old-strategy position `R` into idle balance, which exceeds the credited `P` by the strategy's accrued yield; `ResetAndRewire`'s `setYieldStrategy` idle-sweep then folds that entire excess into V2 principal.

**Band math (fork):**

| Quantity | Value (raw) | ~USDC |
|----------|-------------|-------|
| `ysUsdcV2.principalOf(USDC, original)` | 1,981,492,890 | 1981.49 |
| `original.poolInfo(USDC).totalStaked` | 1,954,262,977 | 1954.26 |
| **buffer actual** | **27,229,913** | **~27.2** |
| `usdcSkimmed` (recorded) | 532,748 | ~0.53 |
| band low (`skim/2`) | 266,374 | |
| band high (`skim*2`) | 1,065,496 | |
| **buffer / skim ratio** | **51.1×** | over upper bound |

The unmodified script therefore **REVERTS** at `Verify 5b FAILED: USDC buffer not within sanity band of usdcSkimmed`, **before** the sole mutation — so `phUSD.setMinter(tempStaker, false)` never runs, and the migration can never be declared COMPLETE by this script as written. The DOLA pool has the same shape (~26.78 DOLA buffer) and escapes the revert **only because `dolaSkimmed == 0` disables its band branch** — confirming it is the band, not the state, that is wrong.

**Impact:** The story-060 final step is non-functional against its own correctly-migrated mainnet state. Operators following the runbook hit an unexplained revert at the finalizer; the temp staker retains a **live phUSD minter authorization indefinitely** (the standing mint-capable surface this cleanup exists to remove); "migration COMPLETE" is never signalled. Funds are not at risk and the state is solvent (both hard-solvency checks pass) — availability/operational-integrity, hence **Medium**, not High.

**Empirical proof it is the sole blocker:** the FX-4 variant (band removed, hard solvency retained) passes all 12 checks and successfully revokes the minter (`authorizedMinters(tempStaker) == (false, 0)` post-broadcast).

**Recommendation:** Drop the `[skim/2, skim*2]` band entirely and keep only the hard solvency invariant (`principalOf >= totalStaked`, already at 4b/5b) — the real safety property; the script's own comment admits the band is "diagnostic-only … inexact". If a surplus sanity bound is genuinely desired, base it on the realize-over-credit accounting (leg-1 realized `R` minus credited `P`, available from the migrator's emitted totals), not the skim alone, and **log** the `≈skim` comparison rather than `require`-ing it.

### YS-11 — standing migrator footgun (Low)
**Location:** `lib/phoenix-phase-2-staging/script/PostMigrationCleanup.s.sol:248-296`
**Root cause:** `MissingPostStepConfiguration` (Law-3 owner footgun)

See section 3(a). Detail in `findings/low/YS-11-standing-migrator-after-complete.json`. **Recommendation:** either (a) add `original.setMigrator(address(0))` (and on temp) as an explicit step-6 action after the verifies, or (b) if option-2 re-injection is genuinely intended, have cleanup **verify** the migrator is the expected migrator2 and emit a loud operator instruction that revocation is still pending — and document the standing privilege in the runbook. At minimum, cleanup should assert the post-migration migrator state it leaves behind rather than silently ignoring it.

### YS-03 — SYA not repointed (Medium, owned by deploy entry)
See section 3(b). Full finding at `findings/medium/YS-03-SYA-not-repointed-to-V2.json`; the cleanup missing-verification angle is folded into its recommendation.

---

## End-state ledger (fork, post-FX-4 broadcast)

| Item | State | Correct? |
|------|-------|----------|
| Temp staker drained (DOLA/USDC) | 0 / 0 | ✅ correct |
| Original repopulated (DOLA/USDC stakers) | 3 / 6 (== leg2 snapshot) | ✅ correct |
| V2 principal > 0 (DOLA/USDC) | 1060.128 / 1981.49 | ✅ correct |
| Hard solvency `principalOf >= totalStaked` | both pass (buffers +26.78 DOLA / +27.2 USDC) | ✅ correct, solvent |
| Withdrawals re-enabled (DOLA/USDC) | false / false | ✅ correct |
| 10% set-aside buffer size + recipient on both V2 | 10 / original | ✅ correct (size) — but no SYA consumer (YS-03) |
| USDe skim balance on original | 40.18e18 ≥ 12.31e18 skimmed | ✅ correct |
| **Migrated-user withdraw smoke-test** | full principal restored, status 1, reward minted | ✅ **migration genuinely works** |
| Temp staker phUSD minter | **still `true` (unmodified) — revoked only under FX-4** | ❌ **dangling (YS-10)** |
| migrator2 on live original / temp staker | **still set (`0xd263…FFfC`)** | ❌ **dangling (YS-11)** |
| SYA repointed to V2 strategies | **never wired; cleanup never checks** | ❌ **dangling (YS-03)** |

**Net:** the protocol state is solvent and users are restored, but the finalizer cannot run as written, and three post-migration items are left dangling — one (the dangling minter) directly caused by the YS-10 revert, two (migrator2, SYA) by skipped suite steps the final gate fails to catch.
