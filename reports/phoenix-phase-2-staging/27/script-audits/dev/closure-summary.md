# `dev` closure — phoenix-phase-2-staging run-27 (regression)

HEAD `1d8a3a7515adca7819c530a01a87c132863a5ae2` (master) · baseline `e1db0f1` · chain **31337** (local anvil, **not** a fork)

## 1. Entry point

`dev` (package.json:16) is a seven-step chain; only step 3 is Solidity.

| # | key | what it does |
|---|---|---|
| 1 | `clean:local` (:8) | deletes `broadcast/*/31337`, `progress.31337.json`, `local.json`, anvil tmp. **Does not** delete `addresses.ts` / `local-addresses.ts` (standing run-26 L-02) |
| 2 | `start:anvil` (:7) | backgrounded; `sleep 3` is the only readiness gate |
| 3 | `deploy:local` (:9) | re-runs `clean:local`, then `forge script script/DeployMocks.s.sol:DeployMocks --broadcast --slow --gas-estimate-multiplier 300` |
| 4 | `./simulate-yield.sh` | shell |
| 5 | `extract:addresses` (:11) | `progress.31337.json` → `local.json` |
| 6 | `generate:ts-anvil` (:13) | `local.json` → `local-addresses.ts` (+ shared `addresses.ts`) |
| 7 | `serve` (:15) | `node server/index.js` |

No `dev:preview` / `dev:dry` / `dev:broadcast` variants, no `//dev` doc comment. Deployer key from `vm.envUint("ANVIL_PRIVATE_KEY")` (DeployMocks.s.sol:387); `LOCAL_PROMO_KENDU` is the only other env read.

## 2. The delta (+293 / −1, one file)

All of it is story **079**, remediating run-26 `pps26l1` / `pps26l3` / `pps26l4`. Exact HEAD line numbers:

| symbol | declared | called |
|---|---|---|
| `armKenduPromo` (contract field) | :213 | assigned :398 (`vm.envOr("LOCAL_PROMO_KENDU", true)`); read :399, :400, :1630, :1631, :2174 |
| `REHEARSAL_SWAP_INDEX = 1` | :225 | :1774 |
| `_rehearseDispatcherSwap` | :1768 (body 1768–1871, doc 1746–1767) | **:1271** — Phase 7.6, between Phase 7.5 (:1262) and Phase 8 |
| `_accrueIndex1MintDebt` | :1878 | :1780 |
| `_pinNudgeRatchetStaticClaims` | :1893 | :1869 |
| `_sweepResidualPrivileges` | :1914 | **:1558** — last statement before `vm.stopBroadcast()` (:1560) |
| `_requireLiveMinter` | :1939 | :1921–:1930 (10-row ACL table) |
| `_armLocalKenduPromotion` **call site gated** | helper :2194 (unchanged) | gate :2174–:2183 (was one unconditional line) |

**Address-book mutation** (:1864–1866): `uniboostEYE = newUb; deployments["UniboostEYE"].addr = address(newUb);` — an in-place edit, deliberately *not* `_trackDeployment`'d because that also pushes onto `contractNames` (:2587) and would emit a duplicate progress-file key. **Verified: `contractNames` receives `"UniboostEYE"` exactly once (:668), so Decision 8's rationale is correct.** No new `_markConfigured`; the existing one at :1513 runs after :1271, so ordering is consistent.

Phase 7.6 executes the mainnet ordering once on index 1: `pull()` :1794 → `new Uniboost` :1805 → `_wireUniboost` :1807 → primeToken/decimals :1813–1818 → `hook.setDispatcher` :1821 → `newUb.setHook` :1822 → intermediate-window asserts :1828–1834 → `replaceDispatcher` :1839 → config-preservation :1840–1846 → post-swap invariants :1849–1853 → `_finalizeUniboost` :1858.

## 3. Import graph

`foundry.toml` sets `auto_detect_remappings = false`; the explicit array is authoritative and canonicalizes **every** nested `lib/<sub>/lib/mutable/**` copy onto the single top-level pin — so no stale nested source is compiled. Delta-relevant resolutions (all top-level, all present):

- `Uniboost` → `lib/yield-claim-nft/src/dispatchers/Uniboost.sol`
- `UniboostMintDebtHook` → `lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol`
- `NFTMinterV2` → `lib/yield-claim-nft/src/NFTMinterV2.sol` (`replaceDispatcher` :227–247, `dispatcherToIndex` :34, `tokenIdToDispatcher` repointed :244)
- `NudgeRatchetMintDebtHook` → `lib/yield-claim-nft/src/hooks/NudgeRatchetMintDebtHook.sol`
- `MultiPooler` → `lib/yield-claim-nft/src/MultiPooler.sol`
- `NudgeStreamer` / `BatchNFTMinter` / `BatchNFTMinterMultiToken` / `NFTStakerDepletionV2` → `lib/nft-staking/src/…`
- `MockPhUSD` → `src/mocks/MockPhUSD.sol` (`setMinter` onlyOwner :33, mint gate :46–48, `authorizedMinters` :68, `mintVersion` :18, `revokeAllMintPrivileges` :76)

Pins used: yield-claim-nft `9c18020`, nft-staking `9611312`, phlimbo-ea `f279c62`, stable-staker `d95f4a6`, SYA `6eab35c`, vault `0110ce4`. Everything resolved — **zero unresolved imports**.

## 4. Off-chain state

`progress.31337.json` keys come solely from `contractNames[]`; `extract-addresses.js:121` iterates `progressData.contracts` into `local.json` (:171); `generate-ts-addresses.js` emits `local-addresses.ts` (:136) and the shared `addresses.ts` (:63), guarding hand-maintained `mainnet-addresses.ts` (:80). `AddressLoader.sol:32` reads `local.json`, anvil-only-enforced at :41–49.

Delta impact: the progress file carries **one** `UniboostEYE` key holding the *replacement* address. The incumbent's address is recorded nowhere off-chain.

## 5. Cluster (ranked)

1. **`script/interactions/FundTestUser.s.sol` — BROKEN BY THE DELTA.** Confirmed at HEAD: `MockPhUSD(phUSD).mint(testUser, phUSDAmount);` at **:46**, broadcast at :43 under `AddressLoader.getDefaultPrivateKey()` = `0xac0974be…f2ff80` (anvil #0, the deployer). **No `setMinter(deployer, true)` re-grant exists anywhere in the file**, which is unchanged since commit `04c4443`. `npm run test:fund-user` (package.json:44) will revert `"Not authorized to mint"` (MockPhUSD.sol:48) on a fresh chain. Story 079 discloses this as Decision 4 (:627–638) and repeats it in Concerns (:707–709), deferring the one-line fix. A grep sweep confirms this is the **only** local off-`dev`-path consumer of the deployer's phUSD grant.
2. **`DeployMainnetPromotionReady.s.sol`** — the mirrored source of truth. Ordering contract at **:148** (`hook.pull() → hook.setDispatcher(new) → new.setHook(hook) → replaceDispatcher(idx,new)`); the local citation "…:146-158" is accurate. Mainnet call counts: `pull()` ×5 (:1300, :1456×3, :1584), `setDispatcher` ×5 (:1341, :1519×3, :1623), `setHook` ×5 (:1342, :1520×3, :1624), `replaceDispatcher` ×5 (:1363, :1528×3, :1632) across indices 1/2/3/4/7 (:446–450). Local mirrors **1 of 5**, on index 1, one dispatcher class. Index 7 is pinned statically instead; **index 4 (BalancerPoolerV2, USDS-primed, BPT custody shift :1393) has no local mechanical mirror at all.** Local asserts *more* per-index than mainnet (`disabled`, `price < 1e12`, plus the intermediate window).
3. **`VerifyPromotionReady.s.sol`** — read-only; no swap calls. Touches `UniboostEYE` at :136 and :294 (`_requireNotPhusdMinter`), the mainnet analogue of the new local ACL table. Pinned read-only in `fs_permissions` under story 075.
4. `DeployMainnetUniboostCutover.s.sol` — predecessor; reads `deployments["UniboostEYE"].addr` at :723.
5. `script/interactions/TestNudgePayout.s.sol` — mints at index 1 (:119) but resolves through `configs` at mint time, **not** a cached address, so the repoint is transparent. No pre-swap address dependency found anywhere else.

## 6. Story set

079 (complete, `phStaging2-script-audit-26`, base commit == audited HEAD), 073 (complete), 076 (complete), 077 (auto-complete), 078 (auto-complete). Paths in `closure-manifest.json` → `storyDocs`.

### Law-2 tension on story 078 — CONFIRMED, narrowly scoped

Exact text, `078-wire-depositpageviewv3-into-cutover-and-collapse-view-keys-onto-viewrouter.md`:

```
299: - **`DeployMocks.s.sol` keeps deploying all four views locally.** Adding them to
300:   `DROPPED_CONTRACT_NAMES` only stops them being *published* into the generated interface;
301:   the local anvil environment is unaffected. Do not modify `DeployMocks.s.sol`.
```

The ledger's line number and quote are exact. But it is the trailing clause of a bullet about `DROPPED_CONTRACT_NAMES`, inside story 078's own constraints section — it reads as story-local, not repo-standing. Story 079 is later, names that file as its *sole* in-scope file, and the +293/−1 diff touches **zero** view surfaces (`DepositPageView*`, `MintPageView`, `ViewRouter`, `DROPPED_CONTRACT_NAMES` are all untouched). Tension appears nominal, but it is a real cross-story directive conflict — left for grading, not dismissed.

## 7. Observations for the auditor (not judgements)

- **OBS-01** The "hook REUSED, no new `phUSD.setMinter` grant" claim (:1762–1764) **verifies**: :1807 calls `_wireUniboost` (:1712, `setMinter(nftMinterV2)` + `setAuthorizedPooler`), not the similarly-named `_deployUniboostHook` (:1722, which is what grants phUSD).
- **OBS-02** `_finalizeUniboost` (:1736) has **unnamed, unused** 2nd and 4th parameters — passing `hook` and `deployer` at :1858 is decorative.
- **OBS-03** `Uniboost` retains (100−`donationSplit`)% of prime USDC for a later `pool()` (Uniboost.sol:222–238; split is 50). `_accrueIndex1MintDebt` now deterministically creates that residue on the **incumbent**, which is swapped out immediately after with no sweep. Mainnet `_swapUniboost` has no sweep either.
- **OBS-04** `replaceDispatcher` also repoints `tokenIdToDispatcher[index]` (NFTMinterV2.sol:244); Phase 7.6 asserts `configs` and both directions of `dispatcherToIndex` but **not** `tokenIdToDispatcher`.
- **OBS-05** In-source step numbering skips 6 (0,1,2,3,4,5,7,8,9,10) — the skipped live probe, story 079 Decision 9 / :719.
- **OBS-06** `dev` races anvil startup on a bare `sleep 3` (pre-existing).
- **OBS-07** `require(price < 1e12, "index price is not 6-decimal-shaped")` (:1846) is a magnitude heuristic with no mainnet counterpart.

## 8. Unresolved

`./simulate-yield.sh` and `server/index.js` not enumerated for state reads (no delta impact expected); bytecode corroboration N/A on 31337 (recorded `skipped`, not a gap); scope of the 078:301 directive not decidable from the document.
