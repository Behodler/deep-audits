# Script Review — `migrate:ys-swap-deploy`

**Entry point:** `migrate:ys-swap-deploy` → `script/DeployTempStableStakerAndMigrators.s.sol:DeployTempStableStakerAndMigrators.run()`
**Story:** Story 060 — yield-strategy swap migration (step 1 of 5)
**Project:** phoenix-phase-2-staging @ `b27c6ac`
**Fork verification:** mainnet fork, anvil @ block **25297358** (broadcast-equivalent advanced the shared fork to blocks 25297359–25297374)
**Mode:** fork-preview (`PREVIEW_MODE=true`, `vm.startPrank(OWNER)`) plus a broadcast-equivalent (`--broadcast --unlocked --sender OWNER`)

---

## Verdict

Step 1 *executes* its checklist faithfully — five contracts are deployed and eleven wiring calls land with zero unintended on-chain writes — but the artefact it produces is dead on arrival: the story-060 "fix" line it builds into both replacement strategies (`vault.previewRedeem(...)`) reverts under STATICCALL against the real Tokemak Autopool vaults, so every `deposit()` into `ysDolaV2`/`ysUsdcV2` reverts and the migration suite cannot complete on a faithful fork (YS-01, Medium). Even with that brick patched, two further problems surface from this one step: the SYA yield collector is never repointed at the new strategies, so post-migration DOLA/USDC yield is silently uncollectable and the buffer this script configures is dead config (YS-03, Medium); and a tracked-but-out-of-slice referral leaves the phUSD minter (~13.8k DOLA + ~11.9k USDC) on the known-buggy old strategies (YS-12, referral). **As written, the suite does not complete on a faithful fork** — the empirical findings below required code fixups (see the caveat in §2 and §4).

---

## 1. Does it do what it intends?

**Stated intent** (package.json `//ys-swap-migration` comment, script NatSpec header, and `docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md`): replace the buggy `ERC4626YieldStrategy` DOLA/USDC instances — whose over-credited principal makes the strategy appear underwater and blocks `StableStaker.withdraw` — via a two-leg bounce through a temporary staker. Step 1 deploys and wires everything the later legs need.

**Implementation matches the deployment checklist.** All ten checklist items were observed on the fork run:

| Intended action | Observed on fork |
|---|---|
| Deploy `ysDolaV2` = `ERC4626YieldStrategy(OWNER, DOLA, autoDOLA)` | `0xc4D5F377…88c7c7`, code present, ctor approves autoDOLA `type(uint256).max` |
| Deploy `ysUsdcV2` = `ERC4626YieldStrategy(OWNER, USDC, autoUSDC)` | `0x0C2d7516…E56a8a`, code present, ctor approves autoUSDC `type(uint256).max` |
| Deploy `tempStaker` = `StableStaker(phUSD, OWNER)` (holding pen, no strategy) | `0xAb510b16…9546EC1`, emission rate 0 |
| Deploy `migrator1` (original → temp) | `0x72813108…1B1b071` |
| Deploy `migrator2` (temp → original) | `0xd263E318…14DfFfC` |
| `phUSD.setMinter(tempStaker, true)` | `authorizedMinters(temp) == (true, 0)` |
| `tempStaker.addToken(DOLA)` + `addToken(USDC)` | `getStakedTokens() == [DOLA, USDC]` |
| `tempStaker.setMigrator(migrator1)` + `original.setMigrator(migrator1)` | both `migrator() == migrator1` (original was `0x0` pre-run — first-time write) |
| both V2: `setClient(original, true)`, `setSetAsideBufferRecipient(original)`, `setSetAsideBuffer(original, 10)` | client=true, recipient=original, buffer=10 on both |
| Write `script/migration-inputs/ys-swap-deployments.json` | written (broadcast) / `…-preview.json` (preview) |

**Pre-conditions all passed:** `block.chainid == 1`; `ORIGINAL_STABLE_STAKER.owner() == OWNER (0xCad1…D0B6)`; `PHUSD.owner() == OWNER`; non-zero address constants; `SETASIDE_BUFFER == 10 && <= 100` (tautological). The underwater state the suite exists to fix is confirmed live: `original.withdrawDisabled(DOLA) == true` (staker principal 1033.89 DOLA vs totalBalance 1033.69); three DOLA stakers cannot withdraw today.

**Where execution diverges from fitness.** The checklist marks *execution*, not *fitness*. Two intent-conformance deltas are material:

1. **Fix mechanism deviates from the doc — and the deviation is fatal.** The intent doc prescribes crediting `vault.convertToAssets(sharesReceived)`. The pinned vault source (`vault@ad12cb1`, `ERC4626YieldStrategy.sol:113`) credits `vault.previewRedeem(sharesReceived)`. On the actual targets — Tokemak Autopools, not plain ERC4626 vaults — these are not interchangeable. This is **YS-01** (§2).
2. **Buffer wired at 10%, contradicting a deliberate 25% chosen two days earlier.** The doc claims the live staker "has a 10% set-aside buffer configured"; the script hardcodes `SETASIDE_BUFFER = 10` with a pinning `require`. But `ReplaceSYAMainnet` (broadcast 2026-06-10) set 25% on all three live strategies, annotated `USER-SPECIFIED 2026-06-10: 25%`. Fork reads confirm the old DOLA and USDC strategies return `setAsideBufferSize(staker) == 25`. The script silently reverts the staker's below-par insulation to 10%. This is **YS-08** (§3).

Two further deltas were assessed benign: the optional `tempStaker.phUSDPerDay(...)` is unwired (emission rate 0 — stakers earn nothing during the bounce, but this also collapses the `setMinter(tempStaker, true)` risk window, since at `phusdPerSecond == 0` the temp staker can never mint a non-zero amount); and the doc's stale "the fixed code is not yet complete" remark (the fix line is in fact present at `ad12cb1`). The fix's own NatSpec is stale — its `@return`/`@dev` still describe "the full nominal amount" (**YS-18**, §3).

---

## 2. Does it introduce unintended side effects?

**On-chain: zero unintended writes.** The fork-preview captured exactly 16 transactions (5 CREATE + 11 calls) producing eleven state writes plus two ERC-20 max-allowances from the strategy constructors. Every one maps 1:1 to an intended action and was verified by reading the slot back:

- `phUSD._authorizedMinters[tempStaker]` `(false,0) → (true,0)`
- `tempStaker._registeredTokens += {DOLA, USDC}`, `tempStaker.migrator 0x0 → migrator1`
- `original.migrator 0x0 → migrator1` (first-time write, verified pre-run `0x0`)
- `ysDolaV2`/`ysUsdcV2`: `_authorizedClients += original`, `setAsideBufferRecipient → original`, `setAsideBufferSize[original] → 10`
- `allowance[ysDolaV2][autoDOLA]` / `allowance[ysUsdcV2][autoUSDC]` `0 → type(uint256).max` (standard adapter pattern, identical to the old strategies)

`side-effects.json` records `unintendedEffects: []`. No collateral mutation, no stray approval, no write outside the eleven-call manifest. **As a state-diff exercise, step 1 is clean.**

**The headline defect — YS-01 (Medium):** the *deployed strategies are non-functional*. This is not an unintended on-chain write; it is a deployment that produces unusable contracts.

> **YS-01 — `previewRedeem` reverts against the real Tokemak Autopool vaults.**
> File: [`lib/vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol:113`](https://github.com/Behodler/phoenix-phase-2-staging/blob/b27c6ac/lib/vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L113) (`vault@ad12cb1`), consumed at [`script/DeployTempStableStakerAndMigrators.s.sol:143,147`](https://github.com/Behodler/phoenix-phase-2-staging/blob/b27c6ac/script/DeployTempStableStakerAndMigrators.s.sol#L143-L147).
> Finding file: `reports/phoenix-phase-2-staging/12/findings/medium/YS-01-previewRedeem-vs-Tokemak-Autopool-brick.json`.

**The exact revert mechanism.** Inside `_acquireShares`, the story-060 fix computes `creditedPrincipal = vault.previewRedeem(sharesReceived)`. The deployment targets are not plain ERC4626 vaults: `autoDOLA` (`0x79eB84B5…0AA54d`, "Tokemak autoDOLA") and `autoUSDC` (`0xa7569A44…3d80D35`, "Tokemak autoUSD") are Tokemak **Autopool** proxies whose `previewRedeem` mutates state internally (it simulates the withdrawal queue). Solidity compiles the external `view` call as an EVM **STATICCALL**; the inner state write inside the Autopool then raises `StateChangeDuringStaticCall`, which consumes all forwarded gas and reverts the frame. Consequently **every `deposit()` into the freshly deployed `ysDolaV2`/`ysUsdcV2` reverts.**

Crucially, a top-level `eth_call` to `previewRedeem` *succeeds* (there is no static frame at the top level), which is exactly why the off-chain checks and the committed `…-preview.json` never caught it — the preview JSON was produced by a run that never actually deposits.

**Downstream blast radius (folded into YS-01 as impact, not separate findings):**
- `ResetAndRewire` (step 3) `setYieldStrategy` idle-sweep deposits the leg-1 skim proceeds into the V2 strategy → reverts.
- Every `Leg2Migration` (step 4) `depositFor → _routeDeposit → strategy.deposit` → reverts.

So if broadcast in order, the suite **bricks at step 3/4 — after leg 1 has already drained the original staker into the temp staker.** Parked principal stays withdrawable (zero emissions), so this is protocol-availability/function-impact, not asset loss — hence **Medium**, not High. The live DOLA-withdraw outage the suite exists to cure remains uncured.

**Empirical caveat (transparency).** Because the unmodified strategies revert on first deposit, the successor legs could not be exercised on a faithful fork. To audit steps 3–5 at all, the `previewRedeem` line had to be patched to the doc-prescribed `convertToAssets` and re-injected via `anvil_setCode`. The root-cause isolation test confirms the fix direction: against a contract STATICCALL, `previewRedeem` reverts on both vaults while `convertToAssets` succeeds (`autoDOLA.convertToAssets(1e18) = 1.16799e18`, `autoUSD = 1086674`). **The suite as committed does not complete on a faithful mainnet fork.**

> **Evidence:** `workspace/phoenix-phase-2-staging/test/AuditYsSwapDeployStep1.t.sol` — three passing fork tests at block 25297374: (1) a 1,000-DOLA deposit reverts; (2) a 1,000-USDC deposit reverts; (3) root-cause isolation (`previewRedeem` static-reverts on both vaults, `convertToAssets` succeeds). Trace shows the revert at `AutopoolETH::previewRedeem` with `StateChangeDuringStaticCall`. (`side-effects.json` → `postconditionResults[6]`.)

**Recommendation (YS-01):** switch the credit to `vault.convertToAssets(sharesReceived)` (verified static-callable on both Autopools) and re-deploy the V2 strategies before any later leg runs. Add a deposit smoke-test (a 1-wei `depositAsOwner`) or at minimum an in-script `try IERC4626(vault).previewRedeem(1e18)` static probe to step-1 preflight, so strategy/vault incompatibility fails at deploy time rather than mid-migration.

---

## 3. Have other problems surfaced because of it?

Step 1's wiring choices and omissions ripple across the rest of the story-060 suite. The cluster lens surfaces one Medium, two Lows, and one QA item rooted in *this* entry point, plus a referral.

### YS-03 — SYA never repointed at the V2 strategies (Medium, silent value leak)

> File: `script/DeployTempStableStakerAndMigrators.s.sol` `run()` — root cause at [L185-L193](https://github.com/Behodler/phoenix-phase-2-staging/blob/b27c6ac/script/DeployTempStableStakerAndMigrators.s.sol#L185-L193); missing verification at `PostMigrationCleanup.s.sol:137-246`.
> Finding file: `reports/phoenix-phase-2-staging/12/findings/medium/YS-03-SYA-not-repointed-to-V2.json`.

The live yield pipeline is `strategies → SYA.skimSurplus → Phlimbo/NFT-minter`, where the SYA is the *only* authorized withdrawer. The new SYA (`0x3C69…8270`) holds an on-chain strategy list of `[YS_DOLA_OLD, YS_USDE, YS_USDC_OLD]`, and `replace-sya` granted it withdrawer rights **only on the old strategies**. This deploy script wires the V2 strategies' clients and buffers but never calls `setWithdrawer(SYA, true)`, and no story-060 sibling re-points the SYA (`addYieldStrategy(ysDolaV2/ysUsdcV2)` / removal of old entries). After migration, all staker DOLA/USDC principal sits in V2 strategies whose surplus *nothing can skim*: yield to Phlimbo/NFT holders silently stops, and the 10% buffer this very script configured can never trigger (it only applies on skims).

Unlike YS-01/YS-02, **this failure is silent** — nothing reverts. Worse, the suite's final gate (`PostMigrationCleanup` "verify final state") asserts the V2 buffer *size* and *recipient* but never checks that a withdrawer/client consumer exists — it green-lights the dead config. Fork reads: `SYA.getYieldStrategies() == [0x90ce…7F9, 0xaC2e…f95, 0x90af…470]`; `ysDolaV2/ysUsdcV2.authorizedWithdrawers(SYA) == false` (suite greps clean for `setWithdrawer`). (`side-effects.json` → `clusterChecks[1]`.) Medium: ongoing, non-dust value leak on the two largest pools with an external-requirement recovery (owner rewire); principal is safe so it does not reach High.

**Recommendation:** extend the suite to `setWithdrawer(SYA, true)` on both V2 strategies and `SYA.addYieldStrategy(ysDolaV2, DOLA)` / `addYieldStrategy(ysUsdcV2, USDC)`; retire the old entries once the minter position (YS-12) is resolved. Add a cleanup post-condition that asserts a consumer exists for the configured buffer — *do not assert a buffer size without asserting a consumer for it.*

### YS-08 — Set-aside buffer downgraded 25% → 10% (Low footgun)

> File: [`script/DeployTempStableStakerAndMigrators.s.sol:84`](https://github.com/Behodler/phoenix-phase-2-staging/blob/b27c6ac/script/DeployTempStableStakerAndMigrators.s.sol#L84) (`SETASIDE_BUFFER=10`), L116 (`require ==10`), L188/L193 (`setSetAsideBuffer`).
> Finding file: `reports/phoenix-phase-2-staging/12/findings/low/YS-08-buffer-percent-stale-config.json`.

Detailed in §1 delta #2. A non-obvious owner footgun (Law-3 in-scope): the operator believes they are *preserving* existing protection while actually reducing the staker's below-par insulation by 60%, because the script pins the intent doc's stale 10% figure rather than the 25% deliberately chosen by `replace-sya` two days earlier (`ReplaceSYAMainnet.s.sol:132-136`). Moot until YS-03 is fixed (no skims reach the V2 strategies at all), which only compounds the configuration debt. **Recommendation:** confirm the intended buffer with the owner; if 25% stands, set `SETASIDE_BUFFER = 25` and cite the `replace-sya` decision in a comment; correct the stale doc figure.

### YS-13 — Non-idempotent broadcast, no resume path (Low footgun)

> File: `script/DeployTempStableStakerAndMigrators.s.sol` — no post-conditions after wiring; broadcast runs under `--skip-simulation --ledger`.
> Finding file: `reports/phoenix-phase-2-staging/12/findings/low/YS-13-skip-simulation-non-idempotent-no-resume.json`.

The script's only guards are pre-flight. After 5 deployments and 11 mutations it asserts nothing and prints a summary. Under `--broadcast --skip-simulation` with a Ledger, a mid-sequence failure (nonce hiccup, gas, an aborted Ledger confirmation) leaves half-wired live state — e.g. `setMinter(temp,true)` applied but migrators unset — with **no idempotent re-run**: re-running redeploys all five contracts and orphans the JSON consumers' addresses. The project's own history confirms this failure mode is real — story-055 needed `ResumeStableStakerMigration.s.sol` after a mid-run failure of the previous staker migration. Funds are not at risk (the migrate loop itself is replay-safe), so Low. **Recommendation:** append a `_postVerify()` (the pattern already exists in `ReplaceSYAMainnet.s.sol`) re-reading every mutated slot and the five deployments before writing the JSON; add an idempotent guard that skips deployment if a valid `ys-swap-deployments.json` already exists.

### YS-14 — Missing pauser registration (Low footgun)

> File: [`script/DeployTempStableStakerAndMigrators.s.sol:141-193`](https://github.com/Behodler/phoenix-phase-2-staging/blob/b27c6ac/script/DeployTempStableStakerAndMigrators.s.sol#L141-L193) (no `setPauser` anywhere in the suite).
> Finding file: `reports/phoenix-phase-2-staging/12/findings/low/YS-14-missing-pauser-registration.json`.

The live system registers global Pauser `0x7c5A…85a3` on the original staker and all three old strategies. This script deploys `ysDolaV2`, `ysUsdcV2` and the temp staker with `pauser == address(0)`, and no story-060 sibling sets it. Post-migration the V2 strategies custody the staker's *entire* DOLA/USDC principal yet sit outside emergency-pause coverage; the temp staker holds all bounced principal during the leg1→leg2 window with the same gap. Fork reads confirm `pauser() == 0x7c5A…85a3` on the original staker and old strategies, `0x0` on `ysDolaV2`/`ysUsdcV2`/`tempStaker`. A non-obvious incident-response footgun; owner can still act via Ownable controls, so Low. **Recommendation:** add `setPauser(0x7c5A…85a3)` for both V2 strategies (and optionally the temp staker for the bounce window) to step 1, mirroring the old strategies, and assert it as a post-condition.

### YS-18 — Stale NatSpec on the fixed strategy (QA)

> File: [`lib/vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/b27c6ac/lib/vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L93) — `_acquireShares` `@return` (L93) and `@dev` (L95-96) vs implementation (L110-113).
> Finding file: `reports/phoenix-phase-2-staging/12/findings/qa/YS-18-stale-natspec-on-fixed-strategy.json`.

The story-060 fix changed the credited principal from the nominal deposit amount to `vault.previewRedeem(sharesReceived)`, but the function's `@return`/`@dev` comments still describe the pre-fix behaviour ("the full nominal amount (no haircut)"). Documentation only — bundle into the QA report and correct it when the YS-01 fix is reworked to `convertToAssets`. This divergence is part of the same pattern as YS-01: the fix landed without review against its own spec.

### YS-12 — phUSD minter left on the buggy old strategies (Low; scoped analysis complete — minter code is unaffected)

> File: `lib/phUSD-stable-minter` (client position on `lib/vault` ERC4626YieldStrategy pre-fix builds `0x90ce…7F9` / `0x90af…470`); scope gap documented in `docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md`.
> Finding file: `reports/phoenix-phase-2-staging/12/findings/low/YS-12-minter-left-on-old-strategies-followup.json`.
> Remediation plan: `reports/phoenix-phase-2-staging/12/script-audits/migrate:ys-swap-deploy/YS-12-minter-followup-plan.md`.

The intent doc scopes the strategy replacement to the StableStaker client only — but the over-credit bug lives in the *strategy contracts*, which serve **two** clients. On fork, the phUSD stable-minter holds **13,816.56 DOLA** and **11,935.65 USDC** of principal on the buggy old strategies (`principalOf(DOLA, minter) == 13816564202291221245191`, `principalOf(USDC, minter) == 11935645684`) — roughly 13× and 6× the staker's exposure.

**Update (2026-06-12) — scoped `/analyze` of phUSD-stable-minter complete; this referral is resolved and downgraded to Low.** The minter is **architecturally immune** to the over-credit bug, so **no minter-code fix is needed or possible**: (1) `mint()` issues `phUSD = amount × exchangeRate × decimalAdjust` (`PhusdStableMinter.sol:243-256`) and never reads `principalOf`/`totalBalanceOf`/`_positionValue`, so over-credited principal cannot mint unbacked phUSD; (2) there is **no redemption path** (story-007 "Remove buggy withdraw"; no `withdraw`/`redeem`/`burn`), so "distorts minter redemptions" is moot; (3) the minter holds no levers over strategy accounting (only `deposit()`) — position movement is strategy-owner-side. The bug's only residual effect on the minter is conservative (`skimSurplus` *under*-skims its phantom surplus). What remains is a Low **migration-completeness** footgun owned by the strategy/migration side (same family as YS-03): the suite leaves the minter on the buggy old strategies, so new mints keep routing there and the residual shared-pool shortfall can land on the minter once the staker is evacuated first. **Fix is operational, not code:** repoint the *existing* minter onto `ysDolaV2`/`ysUsdcV2` (no new minter needed) and optionally consolidate its position — full sequence, post-conditions, the `registerStablecoin` cap-reset footgun, and the rejected new-minter alternative are in the remediation plan above. Blocked on the YS-01 `previewRedeem` fix (V2 strategies unusable until then).

---

## Cross-links (so the reader sees the recurrences across the suite)

These problems are not isolated to step 1 — they recur or amplify across the five-step suite, and are cross-linked to keep the picture coherent:

- **YS-01 ↔ YS-09 ↔ YS-13 (the `previewRedeem` brick family):**
  - **YS-01** (Medium, this entry) is the vault-call brick — the root cause.
  - **YS-09** (Medium, `migrate:ys-swap-reset`) is the script-level *amplification* at the reset entry: `--skip-simulation` + non-idempotent ordering + an unpaused halt window turn the brick into a mid-suite on-chain halt that leaves users parked, is non-resumable (`finalizeAndReset` is one-shot), and is publicly griefable via the story-010 empty-pool gate-relock. The most severe halt-state in the suite.
  - **YS-13** (Low, this entry) is the deploy/leg2 non-idempotent / no-resume family — the operational-robustness footgun distinct from the mid-suite reset halt.
- **YS-03 ↔ YS-08 ↔ YS-10 (the V2-strategy buffer/consumer surface):**
  - **YS-03** (Medium, this entry) — SYA never repointed; the buffer has no consumer (dead config).
  - **YS-08** (Low, this entry) — the buffer percentage is downgraded 25% → 10%.
  - **YS-10** (Medium, `migrate:ys-swap-cleanup`) — the cleanup's buffer-band post-condition is wrong, so the finalizer reverts on its own correctly-migrated state and never revokes the temp staker's phUSD minter authorization. Distinct root causes; cross-linked because all three concern the same buffer/consumer wiring this step set up.

---

## Suite-completion status (empirical)

Auditing the successor legs required code fixups on the fork (the `previewRedeem` brick was patched to `convertToAssets` via `anvil_setCode` so the legs could be exercised). With that caveat, the suite as committed at `b27c6ac` does **not** complete on a faithful mainnet fork:

- **Step 1 (this entry):** executes cleanly; produces non-functional strategies (**YS-01**) and leaves the SYA unwired (**YS-03**).
- **Step 2 (`leg1`):** reverts at its first mutation — the deployer is not an authorized withdrawer for `skimSurplus` on any old strategy and no step grants it (**YS-02**, Low; fails loud, no funds moved).
- **Step 3 (`reset`):** `setYieldStrategy` deposit reverts on the V2 strategy brick — the mid-suite halt amplification (**YS-09**, Medium).
- **Step 4 (`leg2`):** `depositFor → strategy.deposit` reverts on the same brick.
- **Step 5 (`cleanup`):** reverts on a wrong buffer-band post-condition, never revoking the temp minter (**YS-10**, Medium).

`ss9m7` compliance was confirmed: the suite uses a full terminal migration and `StableStaker.setYieldStrategy` retains the story-010 `totalStaked == 0` gate; `ResetAndRewire` only calls it after `finalizeAndReset`.

---

## Findings at this entry point (final severities)

| ID | Severity | One-line | Finding file |
|---|---|---|---|
| YS-01 | Medium | `previewRedeem` STATICCALL-reverts on Tokemak Autopools — V2 deposits dead-on-arrival | `findings/medium/YS-01-previewRedeem-vs-Tokemak-Autopool-brick.json` |
| YS-03 | Medium | SYA never repointed at V2 strategies — yield silently uncollectable, buffer dead | `findings/medium/YS-03-SYA-not-repointed-to-V2.json` |
| YS-08 | Low | Set-aside buffer downgraded 25% → 10% (stale doc figure pinned) | `findings/low/YS-08-buffer-percent-stale-config.json` |
| YS-13 | Low | Non-idempotent broadcast, no resume path / no post-conditions | `findings/low/YS-13-skip-simulation-non-idempotent-no-resume.json` |
| YS-14 | Low | V2 strategies + temp staker deployed without pauser registration | `findings/low/YS-14-missing-pauser-registration.json` |
| YS-18 | QA | Stale NatSpec on `_acquireShares` (says "full nominal amount") | `findings/qa/YS-18-stale-natspec-on-fixed-strategy.json` |
| YS-12 | Low | phUSD minter left on buggy old strategies — scoped `/analyze` complete: minter code unaffected; operational repoint follow-up | `findings/low/YS-12-minter-left-on-old-strategies-followup.json` |
