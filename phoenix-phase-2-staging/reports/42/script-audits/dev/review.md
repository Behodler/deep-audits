# Script review: `dev` (`npm run dev` → `./dev-local.sh`), run 42

| | |
|---|---|
| Project | `phoenix-phase-2-staging` @ `d0060cb` (story-116 HEAD), branch `master`, read-only |
| Run | `phoenix-phase-2-staging-42`, `/audit-script phoenix-phase-2-staging dev` |
| Delta | `dfbf2f9..d0060cb` (run-39 baseline): 50 commits (41 story-tagged), 34 closure files changed, stories 103–116 (all `auto-complete`) |
| Mode | **Live execution** of the real chain on a fresh local anvil (31337) from `work/`. Mainnet RPC used **read-only** at block ~26282664 for the story-116 Decision-2 cross-check. Nothing was broadcast off-local. |
| Grading frame | Owner ruling 2026-09-15: DeployMocks/`dev` is a UI-testing mock stack, not a mainnet rehearsal. Rehearsal fidelity is not graded. |
| Outcome | **0 High / 0 Medium. 0 new findings.** 1 Law-2 recurrence (F-03, Low). Statuses changed by this run: **none** (proposals only). |

Inputs: `entry-manifest.json`, `closure-manifest.json`, `intent.md`, `side-effects.json`, `cluster-analysis.json`, `candidate-findings.json`, `sanitized-findings.json`, `proposed-status-changes.md`, `../../findings/low/F-03-shipped-work-without-story-recurrence.json`, `../../submissions/{spec-conformance.md, M-01-C1.md, M-01-C2.md, carryover/README.md}`.

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| F-03 (`pps28f3`, `da94d1ba03fd`) | Low | Recurrence. Untagged commits in `dev`'s closure have no story to be graded against: `9762281` (dev-local.sh API-port pre-flight, +47 lines), `18b5ac6` ("Accounting layer", package.json) and `58c3b4f` ("sepolia deploy", package.json + `UniswapHelperLocalStack.sol`). The gate works and fails safe. This is a provenance gap only. | Retro-file a story (or add an addendum to story 081) with the API-port gate's acceptance criteria, cover the other two commits the same way or record them as policy-exempt chores, and tag future commits. | `dev-local.sh` (9762281); `package.json` (18b5ac6, 58c3b4f). Report: `../../submissions/spec-conformance.md` |

F-03 reproduces the existing fingerprint triple byte-for-byte. It folds into ledger `da94d1ba03fd`, which stays `open` with `lastSeenRun` bumped. No new entry was opened and no ID was minted.

## 1. Does it do what it intends?

**Yes.** The real chain ran end-to-end through `serve`. Every step in `intent.md`'s checklist was met.

| Step | Result |
|---|---|
| Pre-flight (port 3001 free, :8545 silent) | Pass |
| `clean:local` → owned anvil (`--block-time 2`), listener pid == anvil pid, block ≤ 100 | Pass |
| `DeployMocks` broadcast | **438/438 receipts status 1**, 75 creates, blocks 82–519. Every `require` passed (Phases 1–11.12 plus the terminal sweep). |
| `simulate-yield.sh` | Status 1. MockAutoDOLA went from 1000.12 to 3300.12 DOLA (see §2). |
| `extract:addresses` / `generate:ts-anvil` | 60 UI addresses, every one has code |
| `serve` | `/health` ok on chain 31337. `/contracts` returns 60 keys. |
| Negative tests | Re-running against the live stack exited 1 at the port-3001 gate. With `API_PORT=3999` it exited 1 at the :8545 gate. **Both exits happen before `clean:local`, so nothing was deleted.** |

**Where the checks run.** Every DeployMocks post-condition runs in forge's local simulation. The broadcast itself is checked only by its receipts. For that reason the key end-state was re-read on chain independently. The results are below.

### Story 116 (SYAHarvester wiring): FAITHFUL

| Criterion | On-chain evidence |
|---|---|
| USDe registered with SYA (`setTokenConfig`, `addYieldStrategy`, `setWithdrawer`) | `getYieldStrategies()` = [USDC, sDOLA, USDe]. `YieldStrategyUSDe.authorizedWithdrawers(SYA) == true`. |
| Deploy `SYAHarvester(owner, poolManager, sya, routerNG)`; `setEthPool` | Txs #422–424. Immutables asserted. ETH/USDC fee 3000, tick spacing 60, no hooks. |
| DOLA route 1 hop, USDe route 2 hops via crvUSD, USDC unrouted, Router-NG contiguous | Harvest events show `[DOLA, MockCurveDolaMetaPool, USDC]` and `[USDe, UsdeCrvusdPool, crvUSD, CrvusdUsdcPool, USDC]`. `getRoute(USDC).configured == false`. Forge suite `SyaHarvesterLocalHarvest.t.sol` passes 7/7, including the gapped-route and truncated-route rejections. |
| Yield seeded; caller holds a claim NFT and approval | Pass |
| Smoke harvest sells DOLA and USDe, ETH out > 0, gas check passes | On-chain tx #432 (block 514): 2941.9 DOLA and 196.3 USDe sold, **0.6019 ETH** out. The harvester ends with 0 ETH and 0 USDC. |
| `_sweepResidualPrivileges` conventions | owner == deployer, `isApprovedForAll(deployer, harvester) == false`, yield re-seeded (`calculateClaimAmount` = 3,348.34 USDC) |
| `SYAHarvester` UI key, with zero placeholders on mainnet and Sepolia | local key has code. `mainnet-addresses.ts` and `sepolia-addresses.ts` both carry the zero placeholder. |
| Story-116 commit claim: "no existing address moved" | **Confirmed.** Regenerated artifacts differ from `d0060cb` only in timestamps. The broadcast has 0 `contractAddress` differences. Calldata differs only in the deadline word of 9 txs. |
| Decision 2 (mainnet SYA carries USDe) | Mainnet read at block 26282664 matches the story. The story's own reviewer could not re-verify this. |

Note on the gas check, not filed. On anvil the harvester's own gas check passes vacuously, because the effective gas price is 9 wei. The script substitutes a stricter 50-gwei proxy, but computes it from *simulated* gas (1,089,986), whereas the on-chain harvest used 1,367,306. The proxy still holds against the on-chain gas: 0.0714 ETH required against 0.6019 ETH paid. Story 116 Decision 6 discloses this.

A UI-path probe on the handed-over chain also succeeded: the deployer approved the harvester and called `harvest([],4,1)`, receiving 0.40075 ETH.

### Delta stories (dev slice)

| Story | Verdict | Basis |
|---|---|---|
| 115 | FAITHFUL | Infra deployed and asserted. V4 pool seeded. `PoolModifyLiquidityTest` refunded its 1 ETH margin. Infra keys are filtered from the UI. "forge build green" held in the workspace only after the audit-local `remappings.txt` was moved aside (see §3). |
| 114 | FAITHFUL | Seeder's AM-minter role revoked on chain. The deployer holds 102,312.5e18 AM/sUSDS LP, and the sweep does not touch it. |
| 113 | FAITHFUL (dev slice) | `MockPhUSD.burn` spends the allowance and then burns, as the story specifies |
| 112 | FAITHFUL | 181k sUSDS / 231k phUSD targets met, UniPoolerV2 holds the LP, no address moved |
| 109/110/111 | FAITHFUL (dev slice) | Phase 11.8 requires passed. `UniswapHelper` key resolves to code. |
| 103/105/106/107 | FAITHFUL (dev slice) | No Balancer mocks remain. `configs(4) == UniPoolerV2` on chain. Cutover core archived. |
| 104 | FAITHFUL (dev slice) | Extract/generate pipeline output byte-identical apart from timestamps |
| 117 (`incomplete`) | Out of scope | See §3 |

The only Law-2 gap is the untagged work listed under F-03.

## 2. Unintended side effects

**None new. No unintended effect is attributable to the delta.** This run confirmed three pre-existing effects empirically:

| Effect | Ledger | Observation |
|---|---|---|
| `simulate-yield.sh` mints 2300 DOLA into MockAutoDOLA, which no live consumer reads | `b8036903340e` (F-01, `pps39f1`) | `YieldStrategyDolaLegacy` holds 100% of the shares (6.944e15 of 6.944e15). Story 089 de-registered it from both the minter and SYA, and SYA's on-chain list is USDC, sDOLA, USDe. |
| `clean:local` deletes a tracked broadcast file, and the run re-creates it under a new untracked name | `bd268808fbd5` (L-06, `pps28l6`) | `git status` shows ` D` plus `??` after every run |
| Minter principal is stranded on the de-registered legacy strategy | `9fa8eee3010e` (Q-01, `pps39q1`) | The 6.944e15 shares are still held on chain |

Also re-confirmed live: SIGTERM to `dev-local.sh` while `serve` is in the foreground does not tear down anvil or node until the serve child dies (`49b9904ee12a`, L-07, `pps29l7`). `ANVIL_PRIVATE_KEY` is still undocumented in the chain, and this run worked only because the auditor exported it (`d3aa1e35c995`, Q-02, `pps28q2`).

All workspace files were restored to `d0060cb` after the run.

## 3. Knock-on and cluster effects

No new cluster finding.

- **DeployMocksSepolia vs the key set.** `dev` regenerates `server/deployments/addresses.ts` from 31337 alone, so that file is the `ContractAddresses` key-set authority **for every chain**. Stories 115 and 116 added `SYAHarvester` to the set, but `DeployMocksSepolia.s.sol` has no SYAHarvester phase (0 references). The gap is currently covered by a zero placeholder in `sepolia-addresses.ts` (and in `mainnet-addresses.ts`), as story 116 specifies. This run's regeneration was byte-identical apart from timestamps, so it introduced no key-set drift. The underlying class, an anvil-derived type gating other chains, is unchanged and already tracked (`3177eed94ecb`, `ee5aae66ac65`). Any future local-only key will need the same placeholder on Sepolia and mainnet, or `generate:ts-sepolia` will fail.
- **Story 117 (CurveAMMAdapter last-non-zero, `incomplete`).** `dev` does not exercise CurveAMMAdapter. The local USDe strategy uses `MockMarketAMMAdapter` (DeployMocks.s.sol:622), and the new 2-hop route lives in the harvester's own validated route storage, not in `CurveAMMAdapter.setRoute`. Story 116 marks 117 as out of scope. This run can neither raise nor lower that risk.
- **`remappings.txt` (audit workspace only, not upstream).** An untracked `work/remappings.txt` (dated 2026-10-01) overrode the story-115 `v4-core/` remap in `foundry.toml` and broke the build. It was moved aside to `work/audit-archive/pre-run42-sync/` and stays there. The upstream repo is unaffected. Separately, six untracked audit PoCs in `work/test/audit-run38..41` import paths archived by `702a2b1` [story-107]. They break a plain `forge test` in the workspace, so this run used `--skip 'test/audit-run*/**'`. That is also audit-local.
- **Archived cutover core.** `UniPoolerCutoverCore` now lives in `script/archives/`, which is excluded from compilation, and DeployMocks references it only in a comment. As a result `9a694ae01fe1` is obsolete for `dev`.
- **`start:anvil` block time.** `dev-local.sh` claims its anvil flags are "byte-identical to the start:anvil key", but it uses `--block-time 2` while `start:anvil` uses `--block-time 5` (`111b6f04c9b7`, still present). All 9 deadline-bearing txs share a deadline of simulation timestamp + 1 h. At block-time 2 the last one mined about 16 minutes in. At block-time 5 the estimate is about 34 minutes, so the window still holds. Note only.
- **Phase 6.5b migrator.** `CrossVersionMigrator` is still set on both stakers and never revoked (`08adbb692840`, still present).
- **Skipped steps:** none. `dev` is self-contained and every step ran.

## Reconciliation of carried entries

All **53** open (48) or fix-pending (5) `dev` entries were carried (`../../submissions/carryover/README.md`). Every proposal and its exact `/ledger` command is in **[`proposed-status-changes.md`](proposed-status-changes.md)**. **No status was changed by this run.**

| Verdict bucket | n | Entries |
|---|---|---|
| LIKELY-FIXED → propose `fixed` (human applies) | 7 | `11311795cd60` (M-01 `pps28m1`; the anvil-ownership gates were verified by the negative tests above), `a753907e2a4c` (M-01 run 21; NudgeStreamer now credits the received amount), `b8e3d59139ae`, `ce524709d965`, `0b497be32114`, `669de8af7eb9`, `98e727214903` |
| OBSOLETE → propose `wontfix` with an obsolete reason | 9 | `eda17642828a`, `9a694ae01fe1`, `65db3324e7d0`, `6af1ae30ed82`, `19e2e0c2d6a3`, `9ee101a0cc41`, `9067d8a232b5`, `e0ac78243e5f`, `6537da6fb748` |
| Ruling-obsolete → propose `wontfix` (ruling) | 1 | `12bcca3b617c` (see below) |
| **HOLD** | 1 | `1c98937375ad` (see below) |
| STILL-PRESENT (no action) | 17 | includes F-03 `da94d1ba03fd` (recurrence) and the empirically re-confirmed `b8036903340e`, `49b9904ee12a`, `bd268808fbd5` |
| NOT RE-EXAMINED (outside the delta and untouched by it) | 18 | see the carryover index |

The two Medium carry-overs, `M-01-C1.md` (`a753907e2a4c`) and `M-01-C2.md` (`11311795cd60`), are both proposed `fixed`. Both are `fix-pending`, so they stay rescanned until a human applies the change.

- **`12bcca3b617c` (L-03 `pps26l3`, fix-pending): proposed `wontfix`.** The code is **still present**: `_armLocalKenduPromotion` (L3281) arms the Kendu promo, and on chain `PhlimboV3.promoToken == MockKendu`. However, its class (`RehearsalInvertsStatedMainnetInvariant`) is rehearsal fidelity, which the 2026-09-15 ruling declares invalid for `dev`. A ruling disposes of it, not a fix. While it remains `fix-pending` it keeps being rescanned and carried.
- **`1c98937375ad` (Q-01 `pps26q1`, open): HOLD, no command proposed.** `_rehearsePhlimboV3Cutover` is gone, but the entry also names `_armLocalKenduPromotion`, which survives. A human must decide whether the "story 079 does not exist" provenance gap still attaches to the surviving function. If it does, the entry stays `open`. It also overlaps F-03 `da94d1ba03fd`, which audit 28 kept separate.
- **Flagged for a human re-weigh, no proposal made:** `dcf756f7a897` (F-01 `pps28f1`). Its premise is rehearsal fidelity and so is sensitive to the ruling. `1b461cb4d56c` and `a807cc7a6699` cite scripts that appear to have been archived. They are likely obsolete, but this is **unconfirmed**.
- **Ledger hygiene (manual):** `f7de907d7981` has label `M-02` but severity `low`. `reportPath` prefixes are mixed. 16 run-05/21 entries predate the issueId scheme and have no issueId.
