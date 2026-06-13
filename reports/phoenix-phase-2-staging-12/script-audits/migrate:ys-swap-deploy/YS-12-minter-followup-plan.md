# YS-12 — Scoped analysis outcome & recommended migration follow-up (phUSD minter)

**Date:** 2026-06-12
**Project:** phoenix-phase-2-staging (run-12, `b27c6ac`)
**Subject:** `PhusdStableMinter` (`lib/phUSD-stable-minter`) as a standing client of the buggy old
`ERC4626YieldStrategy` builds `0x90ce…7F9` (DOLA) / `0x90af…470` (USDC).

> This is an audit artifact. The upstream `docs/stable-staker-migrations/` live in a read-only
> submodule, so this plan is written here for the team to adopt into that runbook. It is the
> resolution of the YS-12 referral ("route to a scoped `/analyze` of phUSD-stable-minter").

---

## 1. Outcome of the scoped analysis: the minter needs **no code fix**

The over-credit bug (`_acquireShares` crediting the full nominal `amount` instead of
`previewRedeem(sharesReceived)` — story-060) **cannot harm the phUSD minter**, and **no fix is
possible or needed in `PhusdStableMinter`**. Three structural facts decide this:

1. **Minting is fully decoupled from strategy accounting.** `mint()` issues
   `phUSD = amount × exchangeRate × decimalAdjust` (`calculateMintAmount`,
   `PhusdStableMinter.sol:243-256`). It never reads `principalOf` / `totalBalanceOf` /
   `_positionValue`. The over-credited principal cannot mint a single unit of unbacked phUSD —
   issuance is identical whether the strategy over-credits or not.

2. **There is no redemption path.** The minter is one-way; `withdraw` was removed in story-007
   ("Remove buggy withdraw"). There is no `withdraw`/`redeem`/`burn`. YS-12's core hypothesis —
   *"distorts minter redemptions"* — is moot: there are no minter redemptions to distort.

3. **The minter holds no levers over strategy accounting.** Its only strategy call is
   `deposit(...)`. Any movement of its position is performed by the **strategy owner** via
   `withdrawAsOwner` / `totalWithdrawal` / `relinquishPrincipalAsOwner` / `emergencyWithdraw` —
   all strategy-side, none reachable from the minter.

Consequently the bug's only residual effects on the minter are strategy-side and **conservative**:
`skimSurplus` computes the minter's surplus as `totalBalanceOf − principal`, and an over-credited
principal *understates* surplus, so it **under-skims** (never over-skims) the minter's phantom
yield.

**YS-12 is therefore reclassified from provisional Medium (minter-side referral) to Low —
a migration-completeness follow-up owned by the strategy/migration side, not a minter-code bug,
and not independently exploitable.**

## 2. The real (Low) exposure that remains

The old strategy is **shared** (StableStaker + minter; the minter is ~13× the staker's DOLA and
~6× its USDC). Because the over-credit makes the strategy "appear underwater," evacuating one
client at its over-credited principal can shift the below-par shortfall onto whoever remains. The
story-060 suite drains the **staker first** (its `(R,P)` snapshot socializes the haircut across the
staker's own users) and then **leaves the minter standing on the buggy old strategies
indefinitely** — nothing in the 5-script suite re-registers the minter onto `ysDolaV2`/`ysUsdcV2`
(the same scope gap as YS-03, which leaves the SYA unwired). Two concrete consequences:

- **Fresh user mints keep routing into a known-buggy strategy** (`mint → deposit` into
  `0x90ce…7F9` / `0x90af…470`).
- **The minter can inherit the residual below-par shortfall** on the shared pool once the staker
  has left.

Neither is a minter-code defect; both are fixed operationally by bringing the minter across in
(or immediately after) the migration, on a correctly-accounting V2 strategy.

---

## 3. Recommended remediation — repoint the **existing** minter (preferred)

A new minter is **not** required. `registerStablecoin` is owner-re-callable and overwrites the
config, and the strategy owner can evacuate the minter's existing position. Repointing avoids
re-wiring `phUSD.setMinter`, the UI/`mainnet-addresses` minter address, and every downstream
approval. **Prerequisite: YS-01 (`previewRedeem` STATICCALL brick) must be fixed first** — the V2
strategies are non-functional until then, so this whole follow-up is blocked on the same fix as
the staker legs.

Owner of both old strategies, both V2 strategies, and the minter is the deployer multisig/EOA, so
this is a coordinated owner sequence. Run it **after** Leg 2 + Reset (Step 5 of the story-060
runbook), when the staker is back on V2 and the minter is effectively the **sole remaining client**
on each old strategy.

### Phase A — Repoint future mints (do this regardless of position evacuation)

For each token `T ∈ {DOLA, USDC}` with its V2 strategy `ysTV2`:

1. `ysTV2.setClient(minter, true)` — authorize the minter on the new strategy.
2. `minter.registerStablecoin(T, ysTV2, exchangeRate, decimals)` — repoint config to V2.
   - **FOOTGUN:** `registerStablecoin` rewrites the whole `StablecoinConfig` struct, resetting
     `maxMintPerDay`, `mintedToday`, `lastMintTimestamp` to **0** (`PhusdStableMinter.sol:120-128`).
     If the live minter has a daily mint cap configured, **it is silently removed.** Re-read the
     live cap first and re-apply it in step 4.
   - Re-confirm `exchangeRate` and `decimals` against the live config — do not assume 1e18/defaults
     (Configuration Safety gate).
3. `minter.approveYS(T, ysTV2)` — max-approve the new strategy to pull `T` from the minter
   (the old approval is now dead; optionally `forceApprove(oldStrat, 0)` to revoke it).
4. `minter.setMaxMintPerDay(T, <live cap>)` — restore the cap zeroed in step 2.

**Post-condition assertions** (add to the follow-up script):
- `minter.getStablecoinConfig(T).yieldStrategy == ysTV2`
- `ysTV2.authorizedClients(minter) == true`
- `IERC20(T).allowance(minter, ysTV2) == type(uint256).max`
- `minter.getStablecoinConfig(T).maxMintPerDay == <live cap>`

After Phase A, every new `mint()` lands in the correctly-accounting V2 strategy.

### Phase B — Evacuate the existing position off the old strategy (consolidate backing)

Performed by the **strategy owner** on each old strategy `oldT`, with the minter as the sole
remaining client (so it cleanly receives all residual real value — no cross-client dilution):

1. `p = oldT.principalOf(T, minter)` — the minter's (over-credited) recorded principal.
2. `oldT.withdrawAsOwner(minter, operator, p)` — redeems backing shares (capped to available
   shares, so the minter receives the **real residual value**, which may be `< p` if the autopool
   is genuinely below par) to `operator`, and **debits the minter's `clientBalances`/`totalDeposited`
   to 0** (`_withdrawInternal` decrements by the requested-capped amount). Prefer `withdrawAsOwner`
   over `emergencyWithdraw` precisely because it zeroes the stale accounting; `emergencyWithdraw`
   redeems shares but leaves `clientBalances` non-zero.
3. `recovered = <T received by operator>`; `IERC20(T).approve(minter, recovered)`.
4. `minter.noMintDeposit(ysTV2, T, recovered)` — re-deposits the recovered real tokens into V2,
   crediting the minter, **without** minting new phUSD (seeding, not minting). Backing is now
   consolidated on the correctly-accounting strategy.

**Post-condition assertions:**
- `oldT.principalOf(T, minter) == 0`
- `ysTV2.principalOf(T, minter) ≈ recovered` (exact under the story-060 fix:
  `convertToAssets`/`previewRedeem` of the deposit)

> Note on genuine below-par: if `recovered < p` because the autopool actually lost value, that is a
> pre-existing phUSD-collateralization reality, **not** caused by the bug or the migration — the
> migration merely relocates the minter onto a strategy that accounts for it honestly. Surface any
> realized shortfall to the treasury as a backing-health item; it is not minter-fixable.

### Optional — true-up before evacuation if the minter is NOT the sole client

If, for any reason, Phase B runs while another over-credited client still shares `oldT`, call
`oldT.relinquishPrincipalAsOwner(minter, oldT.principalOf(T, minter) − oldT.totalBalanceOf(T, minter))`
first to write the minter's recorded principal down to its real value, so the shortfall is not
shifted between clients. With the recommended ordering (minter evacuated last, as sole client) this
is unnecessary.

---

## 4. Alternative (NOT preferred): deploy a fresh minter

Deploy a new `PhusdStableMinter`, wire it to the V2 strategies, and retire the old minter
(`setStablecoinEnabled(T, false)` on the old, or `phUSD.setMinter(oldMinter, false)`). Rejected as
the default because it is strictly more disruptive for no accounting benefit:

- Requires `phUSD.setMinter(newMinter, true)` (governance/owner action on the phUSD token).
- Requires updating the minter address in `mainnet-addresses.ts`, the UI, and any integrators.
- Still requires Phase B to evacuate the **old** minter's position off the old strategies.
- The existing minter has no state worth discarding (one-way, no redeem, no per-user balances —
  only owner config), so a fresh instance buys nothing.

Choose this path only if the team independently wants to rotate the minter for unrelated reasons.

---

## 5. Suggested script

Add a `PhusdMinterRepoint.s.sol` (run after `PostMigrationCleanup`), or fold Phase A into
`ResetAndRewire.s.sol` alongside the SYA re-wire that YS-03 also requires (both are the same
"suite only migrated the staker client" gap). It should:

- Guard on `block.chainid` and require the V2 strategies are live and non-bricked (YS-01 fixed).
- Read the live `maxMintPerDay`, `exchangeRate`, `decimals` per token before re-registering.
- Execute Phase A (and optionally Phase B), then assert every post-condition above and revert on
  any mismatch (mirror the `_postVerify()` pattern in `ReplaceSYAMainnet.s.sol`).
