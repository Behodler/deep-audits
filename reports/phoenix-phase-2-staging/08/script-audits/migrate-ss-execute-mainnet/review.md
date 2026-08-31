# Script Review — `migrate:ss-execute-mainnet`

**Story 055 — StableStaker migration SET 2/2 (execute the cutover)**

---

## Run metadata

| Field | Value |
|---|---|
| Project | `phoenix-phase-2-staging` |
| Run dir | `phoenix-phase-2-staging-08` |
| Entry point | `migrate:ss-execute-mainnet` |
| Story tag | Story 055 (migration SET 2/2) |
| Forge target | `script/MigrateStableStakerMainnet.s.sol:MigrateStableStakerMainnet::run()` |
| Submodule HEAD | `c08882b51775800bfa3379dda6c0a6c493c56c24` |
| Mode | fork-preview (empirical) |
| Fork block | ~25234505 / 25234535 (ts 1780461647) |
| RPC | `RPC_MAINNET` (live) |
| Signer | Ledger `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (HD `m/44'/60'/46'/0/0`) |
| Predecessor | `migrate:ss-initiate-mainnet` (Story 054) — opens the 24–72h window this consumes |
| Regression reconciliation | per `entryPoint` — **all 4 findings new** (no prior `migrate:ss-execute-mainnet` baseline) |

The migration is executed as a **single atomic broadcast** in fixed phase order A→F, signed
from a Ledger, with a pre-broadcast `backup-mainnet-addresses.js` snapshot and a post-broadcast
`patch-mainnet-addresses-stable-staker.js` registry patch.

---

## Closure summary

The entry point resolves to one forge script plus a two-step JS chain, cutting across five
**live, mutated** on-chain contracts and a single off-chain registry file.

**Forge target import closure** (resolved via explicit `foundry.toml` remappings,
`auto_detect_remappings = false`):

- `lib/vault/.../ERC4626YieldStrategy.sol` — deployed x3 (Phase B), order DOLA→USDC→USDe.
- `lib/stable-staker/src/StableStaker.sol` — deployed x1 (Phase F).
- `lib/flax-token-v2/src/IFlax.sol`, `lib/vault/.../IYieldStrategy.sol`, OZ `IERC20`.

The script talks to the **already-deployed** live contracts through deliberate inline `ILive*`
shims (`ILiveYieldStrategy`, `ILiveMinter`, `ILiveSYA`, `ILivePauser`, `ILivePhUSD`) because the
deployed bytecode predates the current submodule source (EnumerableSet client refactor on the
strategies; the 7-field `stablecoinConfigs` struct on the minter). Selector shape was corroborated
by successful `eth_call` reads on the fork; strict source/bytecode equality was therefore left
`unverified` by design and is not meaningful here.

**On-chain targets**

| Constant | Address | Role |
|---|---|---|
| `PHUSD_STABLE_MINTER` | `0x435B…77E5` | mutated — `registerStablecoin`, `approveYS` |
| `SYA` | `0x3bBE…606a` | mutated — `addYieldStrategy` x3, `removeYieldStrategy` x3 |
| `PHUSD` (FlaxToken) | `0xf3B5…D605` | mutated — `setMinter(stableStaker, true)` |
| `PAUSER` | `0x7c5A…85a3` | mutated — `register(stableStaker)` |
| `OLD_YS_{DOLA,USDC,USDe}` | `0xE7aE…`/`0x8b4A…`/`0xFc62…` | replaced — drained then removed |
| `VAULT_{DOLA,USDC,USDe}` | AutoDOLA / AutoUSDC / sUSDe | referenced — reused as new-YS vaults |

**Off-chain state:** `server/deployments/mainnet-addresses.ts` — pre-step timestamped backup,
post-step overwrite of `YieldStrategy{Dola,USDC,USDe}` and a zero-only write of `StableStaker`
(aborts if the slot is non-zero).

**Cluster.** Predecessor `migrate:ss-initiate-mainnet` (Story 054) is the strongest link — same
three strategies, same minter client, same two-phase `totalWithdrawal`; it opens the window this
script consumes. Successors `StakeStableStaker` / `ClaimWithdrawStableStaker` (Story 051) exercise
the StableStaker this script deploys. `DeployMocks.s.sol` Phase 3.7 is the canonical local
deploy+wire reference this mainnet script mirrors.

---

## Side-effects summary

> **0 unintended on-chain writes** beyond stated purpose.
> **9 intended write groups** confirmed (USDe leg end-to-end; DOLA/USDC by source symmetry,
> oracle-blocked under time-warp — see Q3).
> **2 robustness observations** surfaced (oracle-liveness coupling → **L-01**; principal
> shrink on re-deposit → dropped as known ERC4626 rounding).
> **Global pre-flight PASSED** (5 of 7 owner gates asserted; 2 present-but-unguarded → **L-03**).
> **No post-broadcast read-back epilogue** → **L-02**.
> **Live preview correctly STOPped** at the Phase A executability gate (24h window not yet elapsed).

| Intended write | Target | Verified |
|---|---|---|
| Old-YS principal redeemed to OWNER; withdrawal state cleared | `OLD_YS_{…}` | USDe E2E |
| OWNER ERC20 balance += received | OWNER EOA | USDe E2E (+3762.379 USDe) |
| 3 new `ERC4626YieldStrategy` deployed (DOLA→USDC→USDe) | CREATE | USDe E2E (1); rest by symmetry |
| New-YS client/withdrawer/buffer/deposit wiring | new YS | USDe E2E |
| Minter config re-pointed to new YS (rate 1e18 preserved) | `PHUSD_STABLE_MINTER` | USDe E2E |
| SYA: add new x3 **then** remove old x3 (count stays 3) | `SYA` | USDe E2E |
| StableStaker authorized as phUSD minter | `PHUSD` | USDe E2E (claim minted) |
| StableStaker registered with Pauser | `PAUSER` | USDe E2E |
| StableStaker deployed + wired (rate, buffer) | StableStaker | USDe E2E (perSec 5e18/86400, buffer 10) |
| Registry patch (overwrite YS, zero-only StableStaker) | `mainnet-addresses.ts` (off-chain) | static |

---

## Q1 — Does it do what it intends?

**Verdict: intent met on the verified path.**

The script's stated purpose is a deterministic, owner-gated, single-broadcast cutover that
(A) drains the three old DOLA/USDC/USDe yield strategies via `totalWithdrawal → owner`,
(B) deploys three new `ERC4626YieldStrategy` reusing the same external vault + underlying,
(C) re-points the phUSD stable minter to the new strategies (preserving the 1e18 exchange rate)
and re-deposits the redeemed principal, (D) cuts the StableYieldAccumulator over (add-new
**before** remove-old), and (F) deploys and fully wires a new StableStaker as an additional phUSD
minter registered with the Pauser. Implementation matches that intent phase-for-phase.

Empirically, the **USDe leg ran end-to-end against live contracts** on the fork
(`test/AuditMigrateUSDeE2E.t.sol`): drain → deploy → minter cutover → SYA cutover → StableStaker
deploy + wire → successor stake/claim all functional. The successor claim minted ~5e18 phUSD,
landing just under the 5e18/day cap (`4.99999e18`), confirming the daily-rate wiring
(`phusdPerSecond = 5e18/86400 = 57870370370370`) and the 10% set-aside buffer took effect.

The **live preview** (no warp) reverted exactly as the script documents — at the Phase A
executability gate, because the Story-054 windows had been initiated only ~44 minutes before the
fork block, so the 24h waiting period was not elapsed. Global pre-flight (all asserted owners ==
`OWNER_ADDRESS`, non-zero singletons, daily rates 5/4/1 e18, buffer 10) passed before the gate.
This is the gate working as designed, not a defect.

Pre-conditions verified on the fork: `block.chainid == 1`; the five asserted owner gates; Phase B
`underlyingToken()`/`vault()` equality against the script constants; Phase C `exchangeRate == 1e18`
and `decimals == 18` for USDe. The fixed Phase-B deploy order and the "capture actual received via
balance delta rather than the Story-054 snapshot" approach are both faithful to the NatSpec.

---

## Q2 — Does it introduce unintended side effects?

**Verdict: zero unintended on-chain writes. Two robustness gaps surfaced; one became a finding.**

Every observed state write maps to the stated purpose (see side-effects table). No unrelated slot
was clobbered. Two non-purpose state characteristics were examined:

1. **Oracle-liveness coupling (→ L-01, Low).** The DOLA and USDC drain legs are transitively
   coupled to live third-party price oracles: the AutoDOLA/AutoUSDC vaults are Tokemak
   `AutopoolETH` proxies whose `redeem` prices the underlying via
   `CurveConvexDestinationVaultV2.getUnderlyerFloorPrice → CustomSetOracle` and `RootPriceOracle`
   (Chainlink ETH/USD). A stale feed at broadcast time reverts the redeem and, because Phase A is
   first in a single atomic broadcast, aborts the **entire** cutover with no partial state. The
   USDe leg (sUSDe/Ethena, no oracle dependency) redeemed cleanly, isolating the coupling to the
   two oracle-priced legs. The 24–72h window does **not** guarantee oracle freshness inside it.
   Impact is availability/operational and fully re-runnable — hence Low, **downgraded from the
   `medium` severity hint**: the atomic broadcast is all-or-nothing, so there is no fund loss and
   no half-applied state from this revert path.

2. **Principal shrink on cutover (examined, dropped as non-finding).** Re-deposited principal
   equals the actual vault redeem proceeds, which can be marginally less than the Story-054
   snapshot (USDe E2E: snapshot 3763.927, received 3762.379 → ~1.55 USDe per leg). This is the
   documented "use actual received" behaviour and is **correct** ERC4626 redeem rounding/cost; the
   exchange rate is preserved at 1e18. Dropped as a known-acceptable ERC4626 rounding artifact, not
   a defect — though it is neither asserted nor logged with tolerance (folded into L-02's
   epilogue recommendation).

Two further structural observations are recorded as findings under Q-scoped robustness:
**L-02** (no post-broadcast read-back epilogue) and **L-03** (incomplete owner pre-flight — see
the non-findings note on why this is a hardening gap rather than a live failure).

---

## Q3 — Have other problems surfaced (cluster / knock-on)?

**Verdict: no blocking cross-script problems. Window handshake is sound; successors functional.**

**Predecessor handshake (Story 054 → 055).** `migrate:ss-initiate-mainnet` opens the window via
the phase-1 `totalWithdrawal`. This script's Phase A gate correctly consumes the
`[initiatedAt+24h, initiatedAt+72h]` window: the gate STOPs before 24h (verified live preview) and
executes after (verified time-warp + USDe E2E). The Story-054 guidance to run 055 in
`[executableAt, executableAt+48h] = [init+24h, init+72h]` matches `TOTAL_DURATION = 72h`. Handling
is symmetric across all three strategies, and withdrawal-amount drift between the two legs is
absorbed by re-reading the balance delta rather than trusting the snapshot.

**Successors (Story 051).** `StakeStableStaker` and `ClaimWithdrawStableStaker` are empirically
functional after **this script alone** — the USDe E2E staked principal into the new YS and claimed
phUSD under the daily cap. The required wiring (`phUSD.setMinter(ss)`, `newYS.setClient(ss)`, pool
`addToken` + rate) is all performed in Phase F. **No skipped step blocks the successors.**

**Fork artifact, not a script bug.** The full-preview fork test reverted under time-warp because
warping `block.timestamp` ~23h forward to open the windows froze the DOLA/USDC Tokemak/Chainlink
oracles at the fork block, making them stale (`InvalidAge(89496)`; Chainlink `0x8d54ba1f`). This is
a fork-mechanics limitation of warping with frozen feeds — the real-world coupling it exposes is
captured factually in **L-01**, but the specific revert seen is not itself a defect in the script.

**Informational.** `StableStaker.migrator` is never set; only the `StableStakerMigrator` flow needs
it, which is not among the listed successors.

**Cross-entry-point links.** L-01 and L-02 are the execute-leg counterparts of thematically
adjacent open findings on the predecessor `migrate:ss-initiate-mainnet` (run-07): L-01 ↔ run-07
`L-03` (stale-snapshot / window-deferral risk), L-02 ↔ run-07 `L-02` (same trust-the-call-succeeded
pattern, no read-back). Both legs of the 054/055 pair omit a post-condition epilogue.

---

## Findings

| Label | Severity | Title | Finding file | Location |
|---|---|---|---|---|
| L-01 | Low | Phase A DOLA/USDC drain depends on un-guarded third-party oracle freshness; a stale Tokemak/Chainlink feed aborts the atomic single-broadcast cutover | [`findings/low/L-01-oracle-liveness-not-guarded.md`](../../findings/low/L-01-oracle-liveness-not-guarded.md) | `script/MigrateStableStakerMainnet.s.sol` — `_drainOne` |
| L-02 | QA | Script encodes no post-condition epilogue: minter repoint, SYA membership, phUSD minter auth, and principal are mutated but never re-read or asserted | [`findings/qa/L-02-missing-postcondition-epilogue.md`](../../findings/qa/L-02-missing-postcondition-epilogue.md) | `script/MigrateStableStakerMainnet.s.sol` — `run` / `_phaseC_minterCutoverAndRedeposit` |
| L-03 | Low | Incomplete owner pre-flight: `PHUSD.owner` / `PAUSER.owner` not asserted, so an ownership mismatch reverts only at Phase F, leaving a half-migrated non-idempotent state | [`findings/low/L-03-incomplete-access-control-preflight.md`](../../findings/low/L-03-incomplete-access-control-preflight.md) | `script/MigrateStableStakerMainnet.s.sol` — `_globalPreflight` |
| L-04 | QA | Off-chain address patch maps new strategies to tokens by positional CREATE index; a future Phase-B reorder silently mis-writes `mainnet-addresses.ts` | [`findings/qa/L-04-positional-address-mapping-fragility.md`](../../findings/qa/L-04-positional-address-mapping-fragility.md) | `scripts/patch-mainnet-addresses-stable-staker.js` — `resolveAddresses` |

**L-01 (Low).** Severity-hinted Medium, downgraded to Low: atomic broadcast is all-or-nothing, no
asset risk, no partial state, fully re-runnable; realistic failure is operational (wait-and-retry
inside the window, or re-run Story 054 if the window lapses). Recommend a pre-broadcast oracle
freshness smoke check (e.g. `previewRedeem` per vault, or read each feed's `updatedAt`) and/or
splitting the three drains so one stale leg cannot abort the whole cutover.

**L-02 (QA).** Defense-in-depth gap; all end states held on the fork. Recommend a post-broadcast
assert epilogue: minter `yieldStrategy == newYS` per token, SYA membership (new present / old
absent), phUSD minter authorization for the StableStaker, and `principalOf(new)` within tolerance
of the redeem proceeds.

**L-03 (Low).** Only 5 of 7 owner gates are asserted in `_globalPreflight`; `PHUSD.owner()` and
`PAUSER.owner()`/authorization are relied on by Phase F but unguarded. Both currently equal
`OWNER_ADDRESS` on the fork, so no live failure today — the risk is the lost fail-fast guarantee:
a mismatch at broadcast time would revert only after Phases A–D have mutated live state, leaving a
half-migrated non-idempotent state. Recommend adding both owner asserts to `_globalPreflight`.

**L-04 (QA).** Off-chain registry only — no on-chain effect, the cutover itself stays correct. The
JS patch keys strategies to tokens by CREATE ordinal, not by `underlyingToken()`; a future Phase-B
reorder would silently mis-map addresses. Recommend binding each deployed strategy to its token by
reading `underlyingToken()` (or the captured constructor arg) instead of positional order.

---

## Non-findings checked and cleared

- **`setMinter` is additive, not a revocation.** `phUSD.setMinter(stableStaker, true)` authorizes
  the new StableStaker as an *additional* minter; it does **not** revoke the pre-existing
  `PHUSD_STABLE_MINTER`. Verified on the fork: the pre-existing minter remains authorized and its
  `mintVersion` is unchanged (0). Not a finding.
- **Symmetric strategy handling.** All three legs (DOLA/USDC/USDe) are drained, redeployed,
  re-pointed and SYA-swapped through the same per-token code paths with no token-specific special
  casing beyond the intended per-token daily rates and decimals. No asymmetry defect.
- **Placeholder zero-write guard is sound.** The post-step `StableStaker` write is **zero-only**
  (aborts exit-4 if the slot is non-zero); the slot is confirmed `0x0` placeholder on-chain. The
  guard prevents clobbering an already-populated StableStaker address. Sound.
- **SYA is never left empty mid-run.** Phase D adds all three new strategies (`addYieldStrategy` +
  `setWithdrawer`) **before** removing any of the three old ones; the registered-strategy count
  stays at 3 throughout. Verified USDe E2E (add new, remove old, count unchanged). No empty-window
  exposure.
- **Successors functional after this script alone.** `StakeStableStaker` /
  `ClaimWithdrawStableStaker` work without any additional wiring — verified via the USDe E2E stake
  and reward-mint path. No skipped step.
- **Principal shrink on re-deposit.** Documented "use actual received" ERC4626 redeem rounding;
  correct behaviour with the 1e18 rate preserved. Dropped as known-acceptable (tolerance/logging
  folded into the L-02 epilogue recommendation).
