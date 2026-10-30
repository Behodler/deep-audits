# Intent — balancer-lp-migrator

Entry point: `balancer-lp-migrator:{preview,broadcast,verify}` (package.json:85-88) @ 8765278
Story: **story-121** `~/code/product-owner/stories/phStaging2/auto-complete/balancer-lp-migrator/121-balancer-lp-migrator.md`
(state `auto-complete`, final; machine-approved, not human-reviewed). Doc key: "story 121: user-facing Balancer V3
phUSD/sUSDS BPT -> UniV2 phUSD/sUSDS migrator (proportional pre-pause, recovery post-BIP-928)".

## Stated purpose (story = authoritative; NatSpec/doc key = restatement — no gap found)

### Script (what the npm chain does)
- [x] Deploy ONE stateless, ownerless `BalancerLPMigrator(vault, v3Router, pool, uniRouter, sUSDS, phUSD)` from OWNER
      `0xCad1…D0B6` (Ledger m/44'/60'/46'/0/0). Uni/sUSDS/phUSD read from `mainnet-addresses.ts`; Balancer V3
      Vault/Router/pool hard-coded (story 107 removed the keys).
- [x] Broadcast only: write `progress.balancer-lp-migrator.1.json`; patcher fills ONLY the `BalancerLPMigrator`
      zero placeholder (SAME idempotent, collision exit 4, key-set drift exit 3); `:verify`; then
      `ledger-record.js DeployBalancerLPMigratorMainnet.s.sol 1` last (repo CLAUDE.md tax-ledger rule).
- [x] Preview: OWNER prank, no progress file, no ledger record.

### Contract (the real risk surface — `src/periphery/BalancerLPMigrator.sol`)
- [x] `migrate(bpt, minSUSDSOut, minPhUSDOut, amountSUSDSMin, amountPhUSDMin, to, deadline)`: pull BPT from
      msg.sender; exit mode decided on-chain (in recovery → recovery; pool or Vault paused → permissionless
      `enableRecoveryMode` then recovery; else proportional); plain ERC20 allowance to V3 Router (no Permit2), reset to 0;
      outs measured as balance deltas; Router02 `addLiquidity` with LP to `to`; approvals reset; unused sUSDS/phUSD
      refunded raw to msg.sender; emit `Migrated(...)` incl. mode.
- [x] Input guards: bpt>0, to≠0, deadline≥now, **all four mins > 0** ("Configuration Safety: no zero slippage floors").
- [x] Zero residual BPT/sUSDS/phUSD/LP and zero allowances after every call; no owner/admin/sweep/storage.
- [x] `previewMigrate(bpt)` view: proportional share rounded down, Router02 optimal amounts, leftover side, mode,
      expected LP (incl. `_mintFee` with live `feeTo`) — the UI's source for the four floors.
- [x] Every immutable public (`pool()` is the UI's only route to the BPT address).
- [x] Hooks 0.20.0 exports `balancerLpMigratorAbi` (hooks/generated.ts:608); not published.

## Declared pre-conditions (require before the CREATE)
- `block.chainid == 1`
- book keys `UniswapV2Router`, `SUSDS`, `PhUSD`, `PhusdSusdsPair` present and non-zero
- code at Vault, V3 Router, pool, Router02, sUSDS, phUSD, pair, and Router02.factory()
- `factory.getPair(sUSDS, phUSD) == PhusdSusdsPair`
- `Vault.getPoolTokens(pool)` is exactly {sUSDS, phUSD}
- progress file absent, OR names a migrator WITH code (then idempotent re-check, no tx; book must be 0 or equal)
- book `BalancerLPMigrator` key present and still zero when no progress file
- (constructor re-checks: non-zero inputs, token set, pair non-zero)

## Declared post-conditions (asserted after the CREATE / by :verify)
- migrator has code; vault/v3Router/pool/uniRouter/sUSDS/phUSD/pair == expected config
- `tokens[sUSDSIndex] == sUSDS`, `tokens[phUSDIndex] == phUSD`
- (:verify) progress vs book agree when both set; at least one non-zero
- (:verify) `previewMigrate(1e18)` returns non-zero sUSDS/phUSD out and non-zero LP (smoke test)

## Not declared / not asserted (gaps noted for findings)
- No assertion relates the floors a caller passes to `previewMigrate` — "non-zero" is the only on-chain slippage rule.
- `:verify` does not bind the address to OWNER's CREATE (a byte-identical third-party clone passes; see side-effects).
