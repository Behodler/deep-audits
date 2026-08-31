# Intent — migrate:ys-swap-deploy (DeployTempStableStakerAndMigrators.s.sol, story 060 step 1)

## Stated purpose (package.json `//ys-swap-migration` comment + script NatSpec + docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md)
Replace the buggy `ERC4626YieldStrategy` DOLA/USDC instances (over-credited principal makes the
strategy appear underwater, blocking `StableStaker.withdraw`) via a two-leg bounce through a temp
staker. Step 1 deploys and wires everything the later legs need:

- [x] Deploy `ysDolaV2` — fresh `ERC4626YieldStrategy(OWNER, DOLA, autoDOLA 0x79eB…A54d)` (fixed build, vault @ ad12cb1)
- [x] Deploy `ysUsdcV2` — fresh `ERC4626YieldStrategy(OWNER, USDC, autoUSD 0xa756…0D35)`
- [x] Deploy `tempStaker` — fresh `StableStaker(phUSD, OWNER)` holding pen (no yield strategies — transit only)
- [x] Deploy `migrator1` — `StableStakerMigrator(original → temp)` (leg 1)
- [x] Deploy `migrator2` — `StableStakerMigrator(temp → original)` (leg 2)
- [x] Wire `phUSD.setMinter(tempStaker, true)`
- [x] Wire `tempStaker.addToken(DOLA)` + `addToken(USDC)`
- [x] Wire `tempStaker.setMigrator(migrator1)` + `original.setMigrator(migrator1)`
- [x] Wire both V2 strategies: `setClient(original, true)`, `setSetAsideBufferRecipient(original)`, `setSetAsideBuffer(original, 10)`
- [x] Write `script/migration-inputs/ys-swap-deployments.json` (broadcast) / `…-preview.json` (preview)

All checked items were observed on the fork run (see side-effects.json). The checklist marks
*execution*, not *fitness* — see candidate findings for where the executed wiring fails its purpose.

## Declared pre-conditions (`_globalPreflight`, before broadcast)
- `IStakerOwnable(ORIGINAL_STABLE_STAKER).owner() == OWNER_ADDRESS` — PASSED on fork
- `IPhUSDSetMinter(PHUSD).owner() == OWNER_ADDRESS` — PASSED on fork
- Non-zero constants: OWNER, ORIGINAL_STABLE_STAKER, PHUSD, AUTODOLA_VAULT, AUTOUSDC_VAULT — PASSED (compile-time constants)
- `SETASIDE_BUFFER == 10 && <= 100` — PASSED (tautological; pins the doc's 10% figure)
- `setUp()`: `block.chainid == 1` — PASSED

## Declared post-conditions (after broadcast)
**None.** The script asserts nothing after its 5 deployments + 11 wiring calls; it prints a summary
and exits. All end-state verification in side-effects.json was performed by the auditor, not the
script. (See candidate finding on missing post-conditions / resume path.)

## Intent-conformance deltas (doc vs. script vs. pinned source)
1. **Fix mechanism deviates from doc — and the deviation is fatal.** The doc (lines 11–14)
   prescribes crediting `vault.convertToAssets(sharesReceived)`. The pinned vault source
   (ad12cb1, ERC4626YieldStrategy.sol:113) credits `vault.previewRedeem(sharesReceived)`.
   On the *actual* targets — Tokemak Autopools, not plain ERC4626 vaults — `previewRedeem`
   mutates state internally and reverts (`StateChangeDuringStaticCall`) when reached through a
   contract's STATICCALL, so **every `deposit()` into ysDolaV2/ysUsdcV2 reverts**. The
   doc-prescribed `convertToAssets` works. Proven by fork test (candidate finding #1).
2. **Doc says the fixed code "is not yet complete"** — stale: vault @ ad12cb1 contains the fix
   line. The fix's NatSpec is itself stale ("the full nominal `amount`"). (Finding #6.)
3. **Buffer wired at deploy time, sized 10%** — the doc defers buffer setup to post-leg-2
   verification and claims "the live original staker has a 10% set-aside buffer configured".
   Stale: replace-sya (2026-06-10, user-specified) set the staker buffer to **25%** on all three
   live strategies (read back 25 on fork). The V2 strategies get 10%. (Finding #4.)
4. **Doc's optional `tempStaker.phUSDPerDay(...)`** is not wired; tempStaker emission rate is 0.
   Benign (doc marks it optional): stakers simply earn no phUSD during the bounce window, and the
   zero rate also collapses the `setMinter(tempStaker, true)` risk window — with
   `phusdPerSecond == 0` the temp staker can never mint a non-zero amount, withdrawals from the
   temp staker stay enabled (idle hold, never underwater), and `depositFor` works while paused.
   Temp-staker bounce config assessed safe for the window.
5. **Pauser drift (not in doc):** original staker and old strategies register global Pauser
   `0x7c5A…85a3`; tempStaker and both V2 strategies leave `pauser == address(0)` and no suite
   sibling sets it. (Finding #5.)
