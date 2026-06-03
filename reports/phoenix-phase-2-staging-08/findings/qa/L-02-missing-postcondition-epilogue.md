# L-02 — Script encodes no post-condition epilogue: minter repoint, SYA membership, phUSD minter auth, and principal are mutated but never re-read or asserted

- **Severity:** QA
- **Status:** draft (new)
- **Entry point:** `migrate:ss-execute-mainnet`
- **Category:** intent-mismatch
- **Root cause class:** MissingPostStepConfiguration
- **Location:** `script/MigrateStableStakerMainnet.s.sol` — `run` / `_phaseC_minterCutoverAndRedeposit`
- **Fork-verified:** yes (empirical end states confirmed via USDe E2E, fork block 25234535, HEAD `c08882b`)
- **Fingerprint:** `4364352e87de50d806a76721a4f130fce6766c416e97ea01614d62d910df86d0`

## Description

`MigrateStableStakerMainnet` asserts inline **pre**-conditions before each step (Phase A
window/executability, Phase B `underlyingToken()`/`vault()`, Phase C `exchangeRate == 1e18`
and `decimals`, Phase D `isRegisteredStrategy(old)`), but adds **no post-broadcast
verification block**. After the cutover it never re-reads or asserts the resulting end
state:

- `minter.stablecoinConfigs(token).yieldStrategy == newYS` (Phase C re-point) — not asserted.
- `SYA` contains `newYS` and no longer contains `oldYS` (Phase D) — `isRegisteredStrategy`
  is checked only as a *pre*-condition of removal, not re-checked after.
- `phUSD._authorizedMinters[stableStaker].canMint == true` (Phase F) — not asserted.
- `newYS.principalOf(token, minter)` is logged but not asserted against the redeem proceeds.

The script trusts each setter to have taken effect without proving the end state.

## Impact

QA. Defense-in-depth / operational-confidence gap, not a fund-loss path. All end states
held on the fork, so under current code the missing epilogue masks nothing today; but a
broadcast operator relying on the script's own output has no on-chain confirmation that the
re-point, SYA swap, and minter authorization actually landed.

## Fork-verification note

Empirically verified: the USDe leg was run end-to-end against live contracts (drain →
deploy → minter cutover → SYA swap → phUSD setMinter → StableStaker deploy/wire → successor
stake/claim). Every post-condition listed above held (`yieldStrategy == newYS`,
`principalOf == received`, SYA add-new/remove-old with count unchanged at 3, successor claim
minted phUSD under the daily cap). The script simply does not self-assert any of them
(`postconditionResults[].note: "script does NOT self-assert this"`).

## Cluster / cross-entry-point note

This is the execute-leg counterpart of the missing-post-condition finding recorded against
the predecessor entry point `migrate:ss-initiate-mainnet` (run-07 `L-02`, fingerprint
`3f4ce2fd6ae3399112fe1d1c787545062d84275ecd27dc9967aed46a2caa0ca3`), which flagged the same
trust-the-call-succeeded pattern for the initiation window. Both legs of the 054/055 pair
omit a read-back epilogue.

## Recommendation

Add an explicit post-broadcast assert epilogue that re-reads and requires: minter
`yieldStrategy == newYS` per token, SYA membership (new present, old absent), phUSD minter
authorization for the new StableStaker, and `principalOf(new)` within tolerance of the
redeem proceeds.
