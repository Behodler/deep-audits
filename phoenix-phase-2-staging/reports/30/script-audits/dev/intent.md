# Intent — `dev` (phoenix-phase-2-staging @ e6eded0 "slimmed down")

Entry point: `npm run dev` -> `./dev-local.sh` -> `forge script script/DeployMocks.s.sol:DeployMocks --broadcast --slow`
against a locally-started anvil (chainId 31337), then `simulate-yield.sh`, `extract:addresses`,
`generate:ts-anvil`, `serve`. There is **no** `:preview` / `:dry` variant: the only variant broadcasts.

## Stated purpose

### Authoritative (Law 2): the story documents
- **NO STORY AUTHORISES e6eded0.** The commit is untagged, its subject is "slimmed down", and an
  exhaustive glob of the whole `~/code/product-owner/stories/phStaging2` tree (all states, all
  sprint folders) tops out at story 081. There is no story 082+, and a full-tree grep for
  slim / trim / retire-the-rehearsal / remove-old-cutover returns zero hits.
- **story-079** (`complete/phStaging2-script-audit-26/079-*.md`) — the story this commit
  partially reverts. Its checklist items 536-541 mandate the Phase 7.6 dispatcher-swap rehearsal.
- **story-080** (`auto-complete/phStaging2-stable-staker-v2/080-*.md`) — the StableStakerV1->V2
  cutover rehearsal, RETAINED (exception #1).
- **story-081** (`auto-complete/.../081-dev-genesis-freshness-gate.md`) — `dev-local.sh` + the
  deployer-nonce require. Untouched by e6eded0.
- **story-073 / 076 / 078** — authored the staker-migration rehearsal, the PhlimboV2->V3 cutover
  and the keyless-page rule respectively. The first two are what e6eded0 deletes.

### The author's own restatement (in-source, e6eded0)
- [x] Retire the local rehearsals of cutovers that have already executed on mainnet
      (PhlimboV1->V2->V3, NFTStakerDepletion V1->V2, the index-1 Uniboost dispatcher swap).
- [x] Deploy PhlimboV3 as the only phlimbo generation; drop `PhlimboEA`/`PhlimboV2`,
      `MigratorV2V3`, `NFTStakerDepletion` (V1), `NFTStakerMigrator`, `DepositView`,
      `DepositPageView`.
- [x] Keep "2 exceptions": the StableStakerV1->V2 cutover (story 080) and the index-6
      `buggedPoolerV2Index6` disabled placeholder.
- [x] Keep the local chain fully working for the UI.

## Declared pre-conditions (asserted before / at the start of the broadcast)
| check | where | result |
|---|---|---|
| `block.chainid == 31337` | `run()` :406 | PASS |
| `vm.getNonce(deployer) == 0` (genesis-freshness gate, story 081) | `run()` :407-409 | PASS |
| nothing already answering on :8545 | `dev-local.sh` pre-flight | PASS |
| the listener pid on 8545 is the anvil this script started | `dev-local.sh` | PASS |
| `cast block-number <= 100` at hand-off | `dev-local.sh` | PASS (block 2) |
| `balancerPoolerV2.primeToken() == USDS` | `_deployStreamerAndBatchMinter` :2146 | PASS |
| `PhlimboV3.promoToken() == address(0)` on arrival | `_deployPhlimboV3` :2270 | PASS |
| index-6 dispatcher registered then disabled | Phase 3.6 :747-748 | PASS |

## Declared post-conditions (asserted after the mutations)
| check | where | result |
|---|---|---|
| `SYA.nudgeStreamer() == nudgeStreamer` | :1267 | PASS |
| index-7 hook `hookTypeId()` + `ratio() == 100` | `_pinNudgeRatchetStaticClaims` :1745 | PASS |
| PhlimboV3 mint grant landed at the current `mintVersion` | `_deployPhlimboV3` :2287 | PASS |
| PhlimboV3 seeding migrator stood down to `address(0)` | `_deployPhlimboV3` :2320 | PASS |
| PhlimboV3 `totalStaked == 300e18` | `_deployPhlimboV3` :2322 | PASS |
| Kendu promo `promoToken` + `promoPhase == Active` | `_armLocalKenduPromotion` | PASS |
| StableStakerV1 drained; V1/V2 migrator wired both sides; V1 mint grant revoked | `_rehearseStableStakerCutover` :1931-2040 | PASS |
| terminal end-state phUSD ACL table (11 rows) | `_sweepResidualPrivileges` :1766 | PASS |
| nudge-stream seeds credited exactly (fee-on-transfer probe) | `_seedNudgeStream` :2234 | PASS |

## Declared post-conditions that NO LONGER EXIST at e6eded0 (deleted with the rehearsals)
- mint-debt conservation across `hook.pull()` (with an explicit anti-vacuity gate)
- the fail-closed intermediate window (`hook.dispatcher() == new` while `configs(1).dispatcher == old`)
- `price` / `growthBasisPoints` / `disabled` preserved across `replaceDispatcher`
- `dispatcherToIndex` moved old -> new and the retired dispatcher resolves to 0
- the replacement Uniboost is USDC-primed (the reused hook's `scale` is immutable)
- **the one real NFT mint** that transitively proved the whole index-1/2/3 donation path — including
  that `setNudgeStreamer` had landed — was executable at all
