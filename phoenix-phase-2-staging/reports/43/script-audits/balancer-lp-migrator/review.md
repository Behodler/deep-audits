# Script Review: `balancer-lp-migrator` (run 43)

**Project**: `phoenix-phase-2-staging`  ·  **Run**: `phoenix-phase-2-staging-43`
**Commit**: `8765278bebfffc46fed96996ea17df9cfa879fad` (`8765278`), branch `master`
**Entry point**: `balancer-lp-migrator:{preview,broadcast,verify}` (`package.json` L85-L88), introduced in `483175c`
**Fork block**: 26,303,097 (2026-10-30T04:11:59Z)
**Story**: story-121, `~/code/product-owner/stories/phStaging2/auto-complete/balancer-lp-migrator/121-balancer-lp-migrator.md` (state `auto-complete`, which is final; machine-approved, not human-reviewed)

**Result**: 0 High, 0 Medium, 1 Low (L-01, `pps43l1`, owner triage `wont-fix` on 2026-10-30). There are no faithfulness (`F-xx`) findings and no Centralization findings.

This review supplements the structured artefacts. It does not replace them:
- `reports/43/submissions/qa-report.md` (L-01)
- `reports/43/submissions/spec-conformance.md` (unsafe-story-rationale cross-reference)
- `reports/43/submissions/4naly3er-report.md`
- `reports/43/findings/low/balancer-lp-migrator__L-01.json`

Evidence:
- `evidence/preview.log`
- `evidence/run43-tests.log`: `work/test/audit-run43/BalancerLPMigratorRun43.fork.t.sol`, 19 passed, 0 failed

---

## What the entry point does

| Variant | Chain | Effect |
|---|---|---|
| `:preview` | `PREVIEW_MODE=true forge script DeployBalancerLPMigratorMainnet` with an OWNER prank | Simulated CREATE only. No progress file, no address-book write, no ledger record. |
| `:broadcast` | `backup-mainnet-addresses.js && forge --broadcast --ledger && patch-mainnet-addresses-balancer-lp-migrator.js && npm run balancer-lp-migrator:verify && ledger-record.js DeployBalancerLPMigratorMainnet.s.sol 1` | One CREATE of `BalancerLPMigrator` from OWNER `0xCad1…D0B6` (Ledger `m/44'/60'/46'/0/0`), followed by off-chain bookkeeping. |
| `:verify` | `forge script VerifyBalancerLPMigrator` (view) | Preflight, immutables check, and a `previewMigrate(1e18)` smoke test. |

The deployed contract, `src/periphery/BalancerLPMigrator.sol`, is the real risk surface. It is stateless and ownerless. Any holder of Balancer V3 phUSD/sUSDS BPT can call `migrate()` to exit into the Uniswap V2 phUSD/sUSDS pair in one transaction. The exit is proportional before the BIP-928 pause and uses recovery mode after it.

---

## 1. Intent: does it do what it intends?

**Yes.** Every story-121 acceptance criterion that the audit could exercise was confirmed on a fork at block 26,303,097.

### Deploy script (preview)

- **Preconditions, 7/7 pass:**
  - `chainid == 1`
  - the four book keys (`UniswapV2Router`, `SUSDS`, `PhUSD`, `PhusdSusdsPair`) are non-zero
  - code exists at all seven inputs and at `Router02.factory()`
  - `factory.getPair(sUSDS, phUSD) == PhusdSusdsPair` (`0x0b96…6F7f`)
  - `Vault.getPoolTokens(pool) == [sUSDS, phUSD]`
  - the progress file is absent
  - the book key `BalancerLPMigrator` is still the zero placeholder (`mainnet-addresses.ts` L175)
- **Postconditions, 3/3 pass:**
  - the migrator has code
  - all seven immutables match the expected configuration
  - `tokens[sUSDSIndex] == sUSDS` and `tokens[phUSDIndex] == phUSD`
- **The only on-chain write is the intended CREATE.** The contract lands at the predicted address `0x94f69b2eB445A8a74400FF3282d861CA0341cBd0` (8,327 bytes of runtime code, immutables only, no storage writes), and the OWNER nonce moves from 1790 to 1791.
- **No events are emitted at deploy time.** The only external calls are three views.
- **Constructor arguments match the story's address table and the book.** The Balancer Vault, V3 Router and pool are hard-coded constants, because story-107 removed those book keys. Router02, sUSDS and phUSD are read from `mainnet-addresses.ts`. Index order is sUSDS = 0, phUSD = 1.
- **Caveat on the predicted address.** `0x94f6…cBd0` only holds while the OWNER nonce stays at 1790. Any other OWNER transaction before the broadcast moves it. This affects nothing, because the patcher reads the address from the progress file and not from the prediction.

### `:verify` is non-vacuous

The audit ran an `R43Verify` harness that subclasses `VerifyBalancerLPMigrator` and overrides only the address sources (`_bookMigrator`, `_progressFile`).

| Case | Result |
|---|---|
| Deployed migrator in the book | PASS: preflight, immutables, `previewMigrate(1e18)` non-zero |
| No address in either source | reverts `verify: no BalancerLPMigrator address …` |
| Progress file names an address that never landed, book is zero | reverts `verify: BalancerLPMigrator has no code` |
| Address is a live contract that is not a migrator (the V2 pair) | reverts |
| Book and progress file disagree | reverts `verify: progress file and mainnet-addresses.ts name different migrators` |
| After `pausePool`, and after `pauseVault` | PASS, logs `RECOVERY` |
| Byte-identical clone deployed by a third party | PASS. This is informational only. `:verify` does not bind the address to OWNER's CREATE, but the address comes from forge's own progress file, so a clone can only be substituted by hand-editing it. Not filed. |

### `migrate()` and `previewMigrate()`

The holder `0xc65f…e8db` migrated its whole balance of 12,036.97 BPT. Floors were set at `previewMigrate` minus 1 bp, and the LP went to the holder.

- **Proportional path** (`test_r43_proportional_wholeHolder`):
  - out: 11,096.40 sUSDS and 13,145.69 phUSD
  - LP minted: 12,067.43
  - refund: 0 sUSDS and 16.37 phUSD. This is about 0.125% of the phUSD leg and reflects the gap between the pool ratio and the pair ratio.
  - recovery mode was not flipped
- **`previewMigrate` matches `migrate` within 2 wei.**
- **Every recovery variant succeeds with amounts identical to the proportional path:**
  - paused pool: the migrator calls `enableRecoveryMode` itself
  - paused Vault only: BPT `transferFrom`, the permissionless `enableRecoveryMode`, `Router.removeLiquidityRecovery` and the V2 add all work while the Vault is paused
  - pool and Vault both paused
  - governance-enabled recovery followed by a Vault pause: the already-in-recovery branch correctly skips `enableRecoveryMode`, which would otherwise revert `PoolInRecoveryMode`
  - two migrations in sequence after a pause: the first caller flips recovery, the second takes the already-in-recovery branch
- **The Balancer floor is enforced on the recovery exit.** Setting `minSUSDSOut` to the preview value plus 2 wei reverts inside the Vault.
- **No residue is left after any call:** 0 BPT, 0 sUSDS, 0 phUSD, 0 LP, and 0 allowances in the migrator.
- **Access model:** BPT is pulled only from `msg.sender`. A stranger cannot spend the holder's max allowance (`test_r43_cannotSpendSomeoneElsesAllowance`).

### Where intent and safety diverge

One story assertion is implemented faithfully but does not deliver the property it claims. Story-121 Technical Details step 1 requires "**all four** min amounts `> 0` (Configuration Safety: no zero slippage floors)." A 1-wei floor satisfies that rule and gives no protection against a sandwich of the Router02 add. This is **L-01**. Spec-conformance carries it as an unsafe-story-rationale note (Law 1 over Law 2), not as an `F-xx`.

---

## 2. Side effects: does it introduce unintended side effects?

**No unintended on-chain side effects.**

### On-chain

- **Deploy.** The only effects are one CREATE and the OWNER nonce increment. `side-effects.json` reports `unintendedEffects: []`.
- **First post-pause `migrate()`.** If the pool or Vault is paused and the pool is not yet in recovery mode, the first caller's `migrate()` calls the permissionless `Vault.enableRecoveryMode(pool)`.
  - This is **pool-wide**, and only Balancer governance can reverse it.
  - It is **intended** (story-121 Technical Details step 3) and harmless: after BIP-928 the only remaining action on the pool is to exit, and recovery mode is what keeps exits open.
  - Later callers take the already-in-recovery branch, which the sequential-migrations test confirms.

### Off-chain

These files are written by `:broadcast` only. `:preview` wrote nothing, which was checked with `git status` after the run.

| Step | Writes |
|---|---|
| `backup-mainnet-addresses.js` | a new `server/deployments/mainnet.backup.<ISO-stamp>.ts` on every run, unconditionally |
| forge (broadcast) | `server/deployments/progress.balancer-lp-migrator.1.json`, `broadcast/DeployBalancerLPMigratorMainnet.s.sol/1/run-latest.json`, `cache/` |
| `patch-mainnet-addresses-balancer-lp-migrator.js` | `mainnet-addresses.ts`, details below |
| `:verify` | nothing |
| `ledger-record.js` | appends to `ledger/transactions.csv` (append-only, de-duplicated on `chain_id + tx_hash`) |

The patcher's changes to `mainnet-addresses.ts`:
- It fills **only** the `BalancerLPMigrator` zero placeholder.
- If the slot already holds the same address, it treats the run as idempotent.
- If the slot holds a different non-zero address, it exits 4 (collision). Key-set drift exits 3.
- It rewrites the story-121 placeholder comment and inserts the dated header line once.

Every step is chained with `&&`. Any non-zero exit (forge, patcher exit codes 1 to 4, or a `:verify` revert) stops every later step, including `ledger-record`.

---

## 3. Knock-on and cluster: have other problems surfaced because of it?

The closure mapper ranked seven related scripts and contracts. None produced a new finding. The interactions that matter are below.

| Cluster member | Relation | Assessment |
|---|---|---|
| `DeployUniswapHelperMainnet.s.sol` / `VerifyUniswapHelper.s.sol` (stories 109, 111, 120) | Template. Same book-reader, preflight, progress/patcher/verify shape. Both add user liquidity to the same phUSD/sUSDS pair. | Story-121 deliberately chose a standalone contract rather than extending `UniswapHelper`. No shared state, and no interference beyond both being liquidity sources for the same pair. The run-36 L-12 pattern (patcher skips `:verify`) is **not** reproduced: `:verify` is chained after the patcher. |
| `script/UniPoolerPool.s.sol` (story-105, `unipooler:pool:*`) | Owner zap of sUSDS into the same V2 pair, which moves the reserves that `migrate()` adds against. | A `previewMigrate` quote taken before an owner zap is stale afterwards. With floors derived from that quote under a bounded tolerance, the stale quote **fails safe**: the Router02 floors bind and `migrate()` reverts. It does not deposit at a worse ratio. The `test_r43_sandwich_50bpFloors` test shows the same mechanism for 2,000-token and 10,000-token reserve moves. With 1-wei floors there is no such protection. That case is L-01. |
| `AntimatterPoolSeeder` (story-113; `antimatter-pool:sepolia*` only, no mainnet key) | Downstream consumer. It converts phUSD/sUSDS LP into AM/sUSDS LP, so the LP that `migrate()` mints is an input to that path. | `migrate()` mints standard V2 LP to `to` and keeps nothing. Nothing in this entry point changes the seeder's assumptions. No mainnet interaction exists today. |
| Archived `DeployMainnetUniPoolerCutover` (story-103) and `quote-balancer-exit-min-amounts.js` | Predecessor. Migrated the protocol's own BPT from the same pool to the same pair (block 26,254,520). | Its exit-floor logic is the closest precedent for `migrate()`'s four minimums. Story-121 covers the remaining third-party BPT. No off-chain floor quoter exists for third-party callers; they rely on `previewMigrate`. This feeds L-01's context. |
| Story-107 key removal (commit `702a2b1`) | Removed the Balancer book keys. | This is why the script hard-codes the Vault, V3 Router and pool constants. All three match the story table. |
| Archived `RevokeBalancerPoolersHoldingPattern` (story-099) | Balancexit stage 1. | Weak link. No shared Balancer V3 constant. Nothing to report. |

### Ledger-record ordering

`ledger-record.js` is the last step of `:broadcast`, after the patcher and `:verify`. This is exactly what the phStaging2 repo `CLAUDE.md` tax-ledger rule requires (*"Place it after any post-broadcast patch/verify steps … keep it last so it records the confirmed run"*, `src/CLAUDE.md` § Tax Ledger). One consequence follows. If `:verify` reverts after a broadcast has landed, the `&&` chain stops and the transaction is not recorded in `ledger/transactions.csv`. The operator must then record it by hand with `npm run ledger:record -- --tx 0x…`. The recorder supports this, and the rule documents it. Observation only, not a finding.

### Crashed broadcast

forge writes the progress file during its **local** pass, so after a crashed or dropped broadcast it can name an address that never landed.
- The `&&` chain means a failing forge step never reaches the patcher.
- If the patcher or `:verify` is run by hand against such a file, `:verify` reverts `BalancerLPMigrator has no code` (`test_r43_verify_failsOnNeverLandedProgressAddress`).
- A re-run of the deploy script refuses a progress file whose address has no code, because the precondition is "absent, OR names a migrator WITH code". The operator must delete the stale file before retrying.

The script header and the patcher header both document this. The failure is loud and needs a manual step, but it is safe.

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| L-01 (`pps43l1`) | Low. **Status: `wont-fix`** (owner triage 2026-10-30) | `migrate()` accepts 1-wei slippage floors, so the story's "no zero slippage floors" rule gives no protection against a sandwich of the Router02 add. Fork: up to 1,101.79 sUSDS (~5.0%) lost on a whole-holder migration; 50 bp floors derived from `previewMigrate` make every profitable sandwich revert. | **UI-side (owner's chosen mitigation):** the phlimbo-ui migrate modal derives all four floors from `previewMigrate(bpt)` at signing time, minus a bounded tolerance (≤ 50 bp suggested), with a short `deadline`. The contract is unchanged. Optional on-chain hardening and a story/NatSpec wording fix remain recommended in `qa-report.md`. **Reopen trigger:** the migrator is promoted for direct or Etherscan use without UI-derived floors, or the modal ships without deriving all four mins from `previewMigrate` at signing time. | [`src/periphery/BalancerLPMigrator.sol#L232-L246`](https://github.com/Behodler/phoenix-phase-2-staging/blob/8765278bebfffc46fed96996ea17df9cfa879fad/src/periphery/BalancerLPMigrator.sol#L232-L246) |

Fingerprint for L-01: `357565f8425a3e2c3007f71c92d5627ba22e9a91fd9ed51b7c5fee7254013fc8` (`sha256(src/periphery/BalancerLPMigrator.sol:migrate:IneffectiveSlippageFloor:balancer-lp-migrator)`).

Informational observations that were not filed:
- `:verify` passes a byte-identical third-party clone. The address cannot be reached without hand-editing the progress file.
- A transaction can go unrecorded in the tax ledger if `:verify` reverts after a landed broadcast. This ordering is what the rule requires, and there is a manual recovery path.
- The predicted CREATE address depends on the OWNER nonce staying at 1790.

---

## Notes

- **The known-issues source is stale.** `src/known-issues.md` does **not exist** at `8765278`. Both the project `CLAUDE.md` ("Known issues are extracted from `src/known-issues.md` — 11 entries are cached in the registry") and `registered-projects.json` (`knownIssuesFile: "phoenix-phase-2-staging/src/known-issues.md"`) still reference it. The cached 11 entries therefore cannot be checked against the source, and they carry no suppression authority. **No finding in this run was suppressed on known-issue grounds.** The project `CLAUDE.md` and the registry entry should be corrected or re-extracted through project-manager.
- **The workspace build needed an audit-local change.** The `work/foundry.toml` skip list was extended with `test/audit-run37/**` through `test/audit-run41/**`. Those earlier-run PoCs import scripts that story-107 archived, and they break compilation of the whole project. The change is confined to the writable `work/` clone. `src/` was not modified.
- **Limits of the fork evidence.**
  - The recovery paths were exercised through governance pranks (`pausePool` / `pauseVault` from `0xA29F…9888`). At fork block 26,303,097 the pool is neither paused nor in recovery mode, so post-BIP-928 behaviour on mainnet is simulated, not observed.
  - The Balancer V3 Vault, Router and pool are reached through local interfaces. There is no Balancer submodule, so their source was not resolved. Signatures were corroborated through Etherscan and selector presence.
  - A swap that manipulates the Balancer side was not tested. The holder owns about 100% of the BPT, so skewing the pool before the pause trades against the holder's own position at the attacker's expense, and swaps are blocked after the pause.
- **Not yet broadcast.** At `8765278` the book key is still the zero placeholder and hooks 0.20.0 is unpublished. Both are by design, per story-121 review notes.
