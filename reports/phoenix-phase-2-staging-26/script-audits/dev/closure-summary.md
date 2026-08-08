# Closure summary — `dev` (phoenix-phase-2-staging @ e1db0f1)

Scope map for audit run `reports/phoenix-phase-2-staging-26/`. This document maps blast radius; it does
not judge correctness. Severity is `script-auditor`'s call.

**Entry point context (from the requester):** `dev` is a LOCAL TESTING script only (anvil, chain 31337).
Mocks and shortcuts are admissible provided they do not conceal bugs. It was recently brought up to date
with the promo-ready cutover for two reasons — (a) rehearse the mainnet cutover sequence locally, and
(b) prepare the UI for mainnet.

---

## 1. The chain

```
job 1 (BACKGROUND, exit status never checked)
  clean:local && start:anvil
job 2 (FOREGROUND, pure && chain)
  sleep 3 && deploy:local && ./simulate-yield.sh && extract:addresses && generate:ts-anvil && serve
```

`&` binds looser than `&&`, so the line splits into exactly two jobs at the `&`. No `dev:preview`,
`dev:dry` or `dev:broadcast` variant exists — **this is the only entry point in the package.json with no
non-broadcasting sibling**, so it cannot be rehearsed the way every mainnet key can.

`deploy:local` runs `forge script script/DeployMocks.s.sol:DeployMocks --rpc-url http://localhost:8545
--broadcast --slow --gas-estimate-multiplier 300`. Note the multiplier is **300 locally vs 200 on the
mainnet cutover** — story 073's review already flagged the blanket 300 as "permanently masking
simulation/broadcast gas divergence for all future DeployMocks work".

`dev` is also the only entry key in the file carrying no `//<key>` doc comment of its own, despite being
the local mirror of the entire cutover. The nearest documentation is the `//local-deploy` (Story 003) and
`//serve-and-dev` (Story 003) group headers.

### Confirmed: `clean:local` runs twice, and the second run races live anvil

Verified. `dev` invokes it directly in job 1; `deploy:local` invokes it again ~3s later in the
foreground — i.e. **after anvil is up**. That second run ends in `rm -rf ~/.foundry/anvil/tmp/*`, which
deletes the tmp working files of the *running* anvil rather than of a previous one. The `~/.foundry`
leg was added in this delta (commit `7d3862e`). The first clean is the correctly ordered one; the second
is both redundant and the hazardous one.

Unlike the three sibling local-flow keys (`test:nft-flow`, `test:nudge-payout`, `test:balancer-donation`),
which all end `&& kill %1`, `dev` never kills anvil — deliberate, since `serve` is long-lived, but a
failed chain leaves an orphaned anvil on port 8545.

---

## 2. Solidity closure

**144 files, 0 unresolved, all submodules recursively checked out.** Rooted at
`script/DeployMocks.s.sol:DeployMocks`, resolved through `foundry.toml`'s authoritative 60-rule
`remappings` array (`auto_detect_remappings = false`).

| class | count |
|---|---|
| external-lib (forge-std, OZ) | 52 |
| in-src (`src/mocks/*`, `src/views/*`) | 25 |
| in-script (`DeployMocks`, `helpers/UniswapV2Deployer`) | 2 |
| nested-submodule: yield-claim-nft | 29 |
| nested-submodule: nft-staking | 12 |
| nested-submodule: phlimbo-ea | 10 |
| nested-submodule: vault (reflax-yield-vault) | 5 |
| nested-submodule: pauser | 4 |
| nested-submodule: stable-yield-accumulator | 2 |
| nested-submodule: stable-staker | 1 |
| nested-submodule: phUSD-stable-minter | 1 |
| nested-submodule: flax-token-v2 | 1 |

**Resolution note worth carrying forward.** solc normalizes a relative import to a source-unit name and
*then* applies remappings. That second pass is load-bearing here: foundry.toml's "Diamond-dependency
canonicalization" block redirects each submodule's own nested vendored copy of a shared dep onto the
single top-level pin. Resolving relatives naively over-counts the graph by 2 files and reports two
physical copies of interfaces solc in fact unifies. The corrected graph is what the manifest carries.

Three files are deployed but invisible to the import graph — `script/uniswap-artifacts/{WETH9,
UniswapV2Factory,UniswapV2Router02}.json`, loaded via `vm.getCode`/`vm.deployCode`.

---

## 3. On-chain surface

76 distinct creations plus 6 factory-created UniV2 pairs. Roughly 26 mocks, 44 real first-party
submodule contracts, 5 in-src views, 3 artifact-bytecode deploys.

**Hardcoded addresses: CLEAN.** Exactly six 20-byte literals exist and all six are well-known anvil
default accounts (#1–#6), split into two deliberately disjoint actor sets so an NFT-side reward transfer
cannot be mistaken for a phlimbo-side one. **No mainnet address leaks in** — no real USDC, no Sky PSM, no
Balancer, no Curve, and notably no `0xCad1…D0B6` owner constant. Contrast `DeployMainnetPromotionReady.s.sol`,
which carries all of those as literals.

**No chain guard.** `block.chainid` appears exactly once, at `DeployMocks.s.sol:365`, inside a
`console.log`. There is no `require(block.chainid == 31337)`. The repo's own CLAUDE.md mandates that
anvil relaxations "must be gated behind an explicit `block.chainid == 31337` branch"; this script is
composed almost entirely of such relaxations. The only "31337" is a hardcoded *string* in the emitted
progress JSON and in the output filename, which would silently mislabel a non-anvil run. Notably,
`script/interactions/AddressLoader.sol` **added exactly such a require in this same delta**, with the
rationale "on mainnet that is an approve/transfer to a stranger's contract".

**No resumability, by design.** No `vm.readFile`, no `_isConfigured` guards, no skip logic — documented
at `:1818-1822` ("every local run is a FRESH leg by construction"). `deploymentStatus:"completed"` is
written unconditionally, so the local progress file can never record `in_progress` or `failed`. The
mainnet counterpart *is* resume-guarded, which means the progress-poisoning failure class that stories
074 and the `//promotion-ready:resume` doc treat as the cutover's sharpest edge is structurally
un-rehearsable locally.

**Unrevoked privilege:** `phUSD.setMinter(deployer, true)` is granted at `:1784`, `:2025` and `:2122`
and never revoked — live at end of script. Carried forward from story 073's own review.

---

## 4. Off-chain state

| file | written by | read by | git-tracked |
|---|---|---|---|
| `server/deployments/progress.31337.json` | `DeployMocks:2334` (pre-broadcast) | simulate-yield.sh, extract-addresses.js, index.js | yes |
| `broadcast/DeployMocks.s.sol/31337/run-*.json` | forge | *nobody in this chain* | yes |
| `server/deployments/local.json` | extract-addresses.js | generate-ts-addresses.js, index.js, **AddressLoader.sol** | yes |
| `server/deployments/addresses.ts` | generate-ts-addresses.js (1st) | **mainnet-addresses.ts** | yes |
| `server/deployments/local-addresses.ts` | generate-ts-addresses.js (2nd) | the UI repo | yes |

Name→address mapping is **by name** from the progress file, never positional-CREATE matching against
broadcast artifacts. The fragile positional pattern exists only in the mainnet `patch-mainnet-addresses-*.js`
family; the local path is on the safe side.

### Ordering hazards

- **OC-01 — a local anvil run rewrites the mainnet address book's type guard.** `mainnet-addresses.ts`
  imports `ContractAddresses` from `./addresses`, and `addresses.ts` is regenerated on every local run
  from anvil's `local.json`. A contract on mainnet but not `_trackDeployment`ed locally vanishes from the
  interface, silently un-typing the mainnet key; a purely local mock becomes a *required* key on the
  mainnet object. The `DROPPED_CONTRACT_NAMES` denylist exists solely to hold this line, and only a code
  comment enforces the lockstep. Story 078 says it outright: "hand-deleting a key from addresses.ts is
  not durable — the next local anvil deploy regenerates it."
- **OC-02 — the progress file is written pre-broadcast and can lie**, exactly as package.json documents
  for the mainnet keys. On abort the `&&` chain stops but the lying file survives on disk until the next
  `deploy:local`.
- **OC-03 — `simulate-yield.sh` consumes the file, not the chain.** It sources MockDola/MockAutoDOLA from
  the progress file with no `cast code` probe. Composed with OC-02, a partial deploy leaves it minting to
  a code-less address; `cast send` to an EOA-shaped target succeeds as a plain call, both `totalAssets()`
  reads are `2>/dev/null`, and the script prints "Done!". Sharpest silent no-op in the chain. It also only
  simulates yield for the DOLA leg — nothing for USDC, USDe, StableStaker or the NudgeStreamer.
- **OC-04 — non-atomic three-file write** with no run-id or checksum tying `local.json`, `addresses.ts`
  and `local-addresses.ts` together.
- **OC-05 — `clean:local` leaves the `.ts` outputs stale.** On a chain that aborts after the clean you get
  *no* JSON and *stale* TypeScript, which reads as a successful prior deploy to the only consumers that
  matter (the UI repo).
- **OC-07 — new coupling.** `AddressLoader.sol` was rewritten this delta from hardcoded literals to
  `vm.readFile("server/deployments/local.json")`. Every `interact:*` / `view:*` / `admin:*` / `test:*` key
  now structurally depends on `dev` having run. Its own comment states the old constants had drifted to a
  code-less address and "the scripts built on it had been failing silently long before the PhlimboV3 cutover".

---

## 5. Promotion-ready mirror — what `dev` does and does not reproduce

| # | Behaviour | Status |
|---|---|---|
| a | NudgeStreamer + push→`collectNudge` conversion on all donors | **MIRRORED** (superset) |
| b | Redeploy 4 donor dispatchers (BalancerPoolerV2 idx4 six-arg, Uniboost ×3, NudgeRatchet idx7) | **PARTIAL** — right shapes/indices, wrong mechanic |
| c | BatchNFTMinterMultiToken + USDC/phUSD/Kendu whitelist + registerStream | **MIRRORED in shape**, divergent config (6h ×3 vs 10/30/30d) |
| d | NFTStakerDepletion → V2 via NFTStakerMigrator | **FULLY MIRRORED** ×3 |
| e | Retire old batch minter (`setPauser(OWNER)` + `pause()`) | **OMITTED** — no analogue |
| f | Hooks REPOINTED not redeployed (`pull → setDispatcher → setHook → replaceDispatcher`) | **OMITTED ENTIRELY** |
| g | PhlimboV3 + two-step APY + mint grant + MigratorV2V3 + V2 wind-down | **FULLY MIRRORED** + local-only addition |
| h | DepositPageViewV3 + `setPage("deposit")` | **FULLY MIRRORED**, incl. the displacement |
| i | MintPageView / `"mint"` page | present, but not a promotion-ready behaviour |
| j | StableStaker / strategies / phUSD minter | deployed locally, not a promotion-ready behaviour |
| k | Story 074 write-once BPT baseline across resume legs | **NO ANALOGUE** |
| l | Story 075 standalone post-broadcast verifier | **NO ANALOGUE** |
| m | Mainnet preamble (snapshots, staleness gate, backup, patcher) | **NO ANALOGUE** |

**Verdict: `dev` mirrors the cutover's END STATE well and its CUTOVER MECHANICS poorly.** Everything that
is a greenfield deploy-and-wire (a, c, g, h) is faithfully reproduced. But every behaviour specifically
about *replacing a live contract* is absent, because the local chain has no incumbent to replace.

Two items deserve emphasis:

- **(f) is the largest structural gap.** `setDispatcher` is never called anywhere in `DeployMocks.s.sol`,
  and no `pull()` is invoked. The mainnet script documents this ordering at `:148-150` and warns that
  **the reverse order leaks value silently** (the new dispatcher goes live carrying a fresh
  `DefaultDispatchHook` and accrues no mint debt). The riskiest ordering in the entire cutover is not
  rehearsed by the local mirror at all. `replaceDispatcher` likewise appears nowhere.

- **(g) contains a deliberate inversion of a stated mainnet invariant.** `_armLocalKenduPromotion`
  (`:1902-1921`) arms a 10,000-Kendu / 1-day promotion on PhlimboV3. Story 076 asserts the exact opposite
  for mainnet — `promoToken == address(0)`, Kendu deliberately *not* set, and Phase 7 asserts the negative.
  The script flags this at `:183-198` as "A DELIBERATE DIVERGENCE FROM MAINNET, not a prediction of it",
  justified because with no promotion running every new V3 UI field reads zero, indistinguishable from a
  broken binding. It is sequenced dead-last so the migrator's `promoToken`-delta path stays dormant during
  the migration. Admissible under the local-testing framing, but it is the one place where the local chain
  deliberately shows the UI a state mainnet is asserted *not* to be in.

Sanctioned divergences (declared in stories 072/073 — **do not report as bugs**): 6h stream window vs
10/30/30 days; three streams locally vs USDC-only endogenous funding on mainnet; phUSD/Kendu seeded by a
synthetic deployer-donor; two coexisting batch-minter ABIs; the flat 90% rehearsal budget move
(explicitly "not solved", and story 072 says do not copy it); `--gas-estimate-multiplier 300`.

---

## 6. Story resolution (Law 2)

All seven required stories resolved to **exactly one document each** — no ambiguity, no misses.

| tag | state | dev-chain relevance |
|---|---|---|
| 072 | complete | indirect — mainnet twin; names DeployMocks as a *read-only reference* |
| 073 | complete | **PRIMARY** — the only local-mirror story with dev-chain acceptance criteria |
| 074 | **auto-complete** | none |
| 075 | **auto-complete** | none |
| 076 | complete (human-confirmed 2026-08-04, promoted from auto-complete) | **none required** — never mentions DeployMocks |
| 077 | **auto-complete** | explicitly out of scope for `script/` |
| 078 | **auto-complete** | mixed — changes the local JS chain, forbids DeployMocks changes |

Ancillary stories also resolved: 003, 013, 028, 059, 068, 070, 071 (all `complete`).

### Flag: a fifth state folder

The tree has `complete`, `incomplete`, `review` and **`auto-complete`** — the last is outside the
documented `complete|incomplete|review|archive` set (and there is no `archive` in this project).
`auto-complete` is machine-terminal: each story there carries "Approved by: story-batch workflow
(**machine approval — not human-reviewed**)". **Four of the seven** stories in this closure closed that
way, including *both* audit-remediation stories (074/075, which remediate run-22 M-01 and L-02) and both
view stories. Story 075's own declared primary regression gate (`npm run promotion-ready:dry`) was never
run. This is metadata, not a scope filter — all remain in scope.

### Flag: `Story 079` does not exist

Stated plainly, per Law 2. `script/DeployMocks.s.sol` references **"Story 079" ten times**, and
`script/interactions/AddressLoader.sol` once more. Globbing the *entire* phStaging2 tree across all five
state folders for `079-*.md` and `079.*-*.md` returns **zero hits**; the highest existing phStaging2 story
is 078. The only 079 anywhere under `~/code/product-owner/stories` belongs to a different project
(`phoenix/…/079-create-global-logging-utility…`) and is unrelated.

Every occurrence was introduced by the head commit `e1db0f1` ("dev script brought up to speed with
promot-ready cutover") — which is itself **untagged**, carrying no `[story-NNN]` prefix. The delta base
`3fb4e34` contains zero occurrences.

The work so attributed is not incidental. It is the whole subject of this audit: the PhlimboV3 Phase 7.4
rehearsal, the local-only Kendu promotion that inverts a stated mainnet invariant, the keyless
DepositPageViewV3 registration, and the AddressLoader rewrite. It is also **not covered by any story that
does exist** — 076 and 077 scope themselves to mainnet `script/`/`src/` only and never mention DeployMocks,
and 078 explicitly instructs *"Do not modify `DeployMocks.s.sol`."*

So there is no acceptance criterion anywhere against which this change can be graded for faithfulness.
That is a scope finding for `script-auditor`, not a severity call — and note the code itself is unusually
well commented, with each divergence argued in place. The gap is provenance, not care.

---

## 7. Delta `3fb4e34..e1db0f1` — 45 files, 23 commits

**Inside the closure (14):** `script/DeployMocks.s.sol` (+421, the subject), `src/views/DepositPageViewV3.sol`
(+233 new), `server/extract-addresses.js` (+25, denylist only), `server/index.js` (+3, one line),
`package.json` (+23), `foundry.toml` (+7, an `fs_permissions` read entry — **remappings unchanged**),
gitlinks `lib/nft-staking` (d2506c1→9611312) and `lib/phlimbo-ea` (6cb0bc0→f279c62, **the bump that makes
Phase 7.4 possible** — PhlimboV3 and MigratorV2V3 come from it), plus six committed output artifacts.

**Outside (31):** `DeployMainnetPromotionReady.s.sol` (+3571), `VerifyPromotionReady.s.sol` (+326),
`AddressLoader.sol` + 9 interaction scripts (output-closure, not import-closure), the snapshot/patcher JS
family, `mainnet-addresses.ts`, four new test suites, and the wagmi/hooks bundle (+2363, hooks 0.11.0→0.12.0
— the "prepare the UI" half; note `dev` itself never runs `generate:hooks`).

**Sizing caveat:** six of the 45 changed files are committed *output artifacts of running `dev` itself*,
accounting for roughly 40,000 of the delta's ~50,000 changed lines. `git diff --stat` badly overstates the
authored change. Two commits (`f29ecb0` "recent deploy of anvil", `3e0f1a5` "local run") are pure artifact
commits.

---

## 8. Handover notes for `script-auditor`

1. **No preview variant.** Any empirical verification must broadcast against a fresh local anvil from
   `workspace/`, never `lib/`. Budget for `clean:local` deleting `~/.foundry/anvil/tmp/*` twice.
2. **The local-testing framing is load-bearing but not unlimited.** Mocks and shortcuts are admissible
   *provided they do not conceal bugs*. The candidates worth testing against that bar are OC-03
   (silent no-op yield simulation), OC-01/OC-05 (stale or skewed UI artifacts that read as a good deploy),
   and the missing chain guard.
3. **Do not re-litigate the sanctioned divergences** listed in §5 — they are declared in stories 072/073.
4. **The strongest scope observations** are the `Story 079` provenance gap (§6), the omitted hook-repoint
   ordering (§5f), and the `addresses.ts` cross-chain type coupling (OC-01).
5. **Cluster is bounded to 10 entries**, ranked in `closure-manifest.json`. Ranks 1–4 are the ones that
   matter; rank 10 is included only to mark it explicitly out of bounds.
