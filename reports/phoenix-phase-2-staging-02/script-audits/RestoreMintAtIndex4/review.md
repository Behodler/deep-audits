# Script Review — `RestoreMintAtIndex4`

| Field | Value |
|-------|-------|
| Project | `phoenix-phase-2-staging` |
| Entry point | `RestoreMintAtIndex4` (`script/RestoreMintAtIndex4.s.sol:RestoreMintAtIndex4.run`) |
| Run | `phoenix-phase-2-staging-02` |
| Submodule commit | `02a76d0` |
| Mode | `fork-preview` — mainnet fork; preconditions validated at block `25148200`, live HEAD state read at ~`25202737` |
| Story | 048 follow-up |

**What this script does.** `RestoreMintAtIndex4` is a two-write, owner-signed remediation for fallout from the Story-048 V1→V2 dispatcher cutover. It (1) calls `NFTMinterV2.setDispatcherDisabled(4, false)` to re-enable dispatcher index 4 — Story-047 had set `configs[4].disabled = true`, and the `DispatcherReplaceAtIndex4` cutover replaced the index-4 dispatcher without clearing that flag — and (2) calls `ViewRouter.setPage(keccak256("mint"), 0x64FE63ca…)` to repoint the ViewRouter `"mint"` page at the index-4 `MintPageView` (reading USDS), displacing the index-6 view at `0xeBEc…`. Both calls are `onlyOwner` and broadcast in a single Ledger session (HD path `m/44'/60'/46'/0/0`, index 46), guarded front and back by drift `require`s.

---

## Closure audited

The audited slice (everything that flows into the entry point) is:

**Solidity (in-src / reachable)**
- `src/views/ViewRouter.sol` — mutated target; `owner()`, `pages(...)`, `setPage(...)`.
- `src/views/IPageView.sol` — interface used by the post-condition smoke test.
- `src/views/MintPageView.sol` — concrete view behind `TARGET_MINT_PAGE_VIEW` (reached via `IPageView`, not imported).
- `NFTMinterV2.sol` (nested submodule `lib/nft-staking/lib/mutable/yield-claim-nft/src/V2/`) — reached via the inline `INFTMinterV2Disable` interface; selector/struct shape (`configs(uint256)` → `(dispatcher, price, growthBasisPoints, disabled)`, `setDispatcherDisabled` `onlyOwner`) matches the resolved source.

**On-chain targets**
- `NFTMinterV2` `0x39Af…E10F` — **mutated** (`configs[4].disabled`).
- `ViewRouter` `0xC17Ce…631a` — **mutated** (`pages["mint"]`).
- `MintPageView` `0x64FE63ca…` — **referenced** (write target + `getData` smoke test).
- `MintPageView` `0xeBEc…` — **replaced** (expected pre-state `"mint"` page).
- `OWNER_ADDRESS` `0xCad1…D0B6` — EOA / Ledger signer; not a contract target.

None of the on-chain targets are Etherscan-verified (V1 endpoint deprecated, V2 reports unverified); `codeMatchesSource` is `unverified`, with identity corroborated by inline-interface selector and struct-shape matches against resolved source.

**Cluster siblings (ranked, Story-048 family)**
1. `DispatcherReplaceAtIndex4` — **predecessor**: the V1→V2 cutover (step 10 `replaceDispatcher(4, NEW_POOLER 0x26F8…)`, step 14 `setDispatcherDisabled(6, true)`); left `configs[4].disabled = true`, which is exactly this script's action 1.
2. `SetMinterOnIndex4Pooler` — **skipped-step**: cutover step 11 `NEW_POOLER.setMinter(NFT_MINTER_V2)`, required for `mint(4)` to clear `ATokenDispatcherV2.dispatch`'s `onlyMinter` gate. Not part of this script.
3. `SetBatchDonationSizeIndex4` — **sibling-config**: sets `batchDonationSize = 10%` on `NEW_POOLER`.
4. `TempSimulate40MintsIndex4` — **evidence**: temp fork sim applying all three pending owner fixes (`setDispatcherDisabled(4,false)` + `setMinter` + `setBatchDonationSize(10)`) before minting x40; its existence confirms this script is one of three changes needed for a working index-4 mint path.
5. `RedeployMintPageViewV2` — **conflict / successor**: treats this script's TARGET `0x64FE…` as the OLD page to replace and bumps the view source to index 6 — the inverse of this script's intent.

---

## Q1 — Does it do what it intends?

**Yes.** The two intended writes are faithfully implemented and match the stated `@notice`/intent:

- Action 1 — `setDispatcherDisabled(4, false)` flips `configs[4].disabled` `true → false`.
- Action 2 — `setPage(keccak256("mint"), 0x64FE…)` repoints the `"mint"` page from `0xeBEc…` to `0x64FE…`.

Pre- and post-conditions are coherent and mutually consistent: the pre-flight asserts mainnet chain id, `ViewRouter.owner() == OWNER_ADDRESS`, the drift guards (`pages("mint") == 0xeBEc…`, `configs(4).disabled == true`), `extcodesize(TARGET) > 0`, and `configs(4).dispatcher != 0`; the post-flight re-asserts the two written values. On the fork at block `25148200` — the exact window the script was designed for — all pre-conditions pass, both writes land, and both post-conditions hold. The TARGET `0x64FE…` is the correct value for live state: at HEAD the `"mint"` page is already `0x64FE…` and its source reads the live index-4 dispatcher.

The script's effects are **already applied on mainnet**. At HEAD (~block `25202737`) the preview reverts on its own drift guard — `"Unexpected current mint page (state has drifted; review before running)"` — because `pages("mint")` is already `0x64FE…` (== TARGET) and `configs(4).disabled` is already `false`. This is **correct behaviour**: the guard is doing its job, refusing to re-apply an already-applied change.

---

## Q2 — Unintended side effects?

**None.** The fork preview at block `25148200` produced exactly the two intended writes and nothing else:

| Contract | Slot | From | To | Intended |
|----------|------|------|----|----------|
| `NFTMinterV2` `0x39Af…E10F` | `configs[4].disabled` | `true` | `false` | ✔ |
| `ViewRouter` `0xC17Ce…631a` | `pages[keccak256("mint")]` | `0xeBEc…` | `0x64FE…` | ✔ |

Two corresponding events fired and only those two — `NFTMinterV2.DispatcherDisabledChanged(index=4, disabled=false)` and `ViewRouter.PageRegistered(page=keccak256("mint"), implementation=0x64FE…)`. The single external call (`MintPageView(0x64FE…).getData(OWNER)`) did not revert and the smoke test passed. The recorded `unintendedEffects` set is empty: zero unintended state writes, zero unintended events, zero external mutations beyond the two owner-authorised calls.

---

## Q3 — Have other problems surfaced?

Two fork-demonstrated problems and one weakness surfaced. Note that these are properties of the broader Story-048 remediation and the script's self-reporting — the two writes themselves are clean (Q2).

### M-01 (Medium) — `mint(4)` still dead after this script alone

The script re-enables index 4 and repoints the page, then prints `"RESTORE COMPLETE"`, but the cutover omitted `NEW_POOLER.setMinter(NFT_MINTER_V2)` (the separate `SetMinterOnIndex4Pooler` step). The mint path `mint() → ATokenDispatcherV2.dispatch()` is `onlyMinter`-gated, so with the pooler's minter unset, `mint(4)` reverts `"ATokenDispatcherV2: caller is not minter"`. The A/B fork test proves it: running this script's `NFTMinter` write alone then `mint(4)` reverts at the `onlyMinter` gate (USDS `transferFrom` succeeds, `dispatch()` fails); adding `setMinter(NFT_MINTER_V2)` mints 1 NFT successfully. The post-conditions pass vacuously because they check view flags, not the mint path, so an operator running this script in isolation is told minting is restored when it is not. Mitigated in production because the separate `setMinter` step is run there.

- Location: `script/RestoreMintAtIndex4.s.sol` `run()` [L93-L117](https://github.com/Behodler/phoenix-phase-2-staging/blob/02a76d0/script/RestoreMintAtIndex4.s.sol#L93-L117)
- PoC: `workspace/phoenix-phase-2-staging/test/AuditRestoreMintIndex4.t.sol` (passing, fork A/B at block `25148200`)
- Record: `reports/phoenix-phase-2-staging-02/findings/medium/M-01-restore-mint-index4-non-functional.json`

### M-02 (Medium) — `RedeployMintPageViewV2` conflict

The successor script `RedeployMintPageViewV2` hardcodes this script's TARGET `0x64FE…` as the OLD view to replace, on the (inverted) assumption that `0x64FE…` reads the disabled index-6 pooler, and deploys a fresh view bumped to index 6. Its `require(currentMintPage == OLD_MINT_PAGE_VIEW)` guard **passes** — precisely because `RestoreMintAtIndex4` set `pages("mint") = 0x64FE…` — so the guard offers no protection and broadcasting it would repoint the `"mint"` page back to the disabled index-6 view, breaking the mint page. This contradicts live state, where index 4 is live and index 6 is disabled (`configs[6].disabled == true`, dispatcher `0x4da1…f73d`). `RedeployMintPageViewV2` has not been run. (`0x64FE…` exposes no `dispatcherIndex()` getter, so the inverted assumption cannot be caught by an on-chain read.)

- Location: `script/RedeployMintPageViewV2.s.sol` `run()` [L49-L96](https://github.com/Behodler/phoenix-phase-2-staging/blob/02a76d0/script/RedeployMintPageViewV2.s.sol#L49-L96)
- Record: `reports/phoenix-phase-2-staging-02/findings/medium/M-02-redeploy-mintpageview-stale-index.json`

### L-01 (Low) — vacuous post-condition smoke test

The post-condition smoke test only calls `IPageView(TARGET).getData(OWNER_ADDRESS)` and asserts the two view flags; it never exercises `mint(4)`. Because of M-01, `"RESTORE COMPLETE"` therefore prints even when minting is broken. The success assertion is misleading and should not be relied on as proof the mint path works.

- Location: `script/RestoreMintAtIndex4.s.sol` `run()` [L106-L117](https://github.com/Behodler/phoenix-phase-2-staging/blob/02a76d0/script/RestoreMintAtIndex4.s.sol#L106-L117)
- Record: `reports/phoenix-phase-2-staging-02/findings/low/L-01-vacuous-postcondition-smoke-test.json`

---

## Verdict & recommendations

`RestoreMintAtIndex4` is **correct in isolation**: it implements exactly the two writes it intends, its drift guards are sound (correctly refusing to re-apply at HEAD), and the fork preview shows no unintended side effects. Its weaknesses are relational and self-reporting:

1. **It is one of at least two required owner actions.** On its own it does not restore a working `mint(4)`; `SetMinterOnIndex4Pooler` (`NEW_POOLER.setMinter(NFT_MINTER_V2)`) must also run. Fold `setMinter` into this script or document the ordered runbook explicitly. (M-01)
2. **Reconcile `RedeployMintPageViewV2`'s stale index assumptions** before it is ever broadcast. Its `OLD == 0x64FE…` premise is inverted relative to live state, and its `require` guard passes for the wrong reason; running it would break the mint page. (M-02)
3. **Strengthen the post-condition.** Assert `NEW_POOLER.minter() == NFT_MINTER_V2` and simulate the full `mint(4)` path before printing `"RESTORE COMPLETE"`, so the success message cannot fire while minting is dead. (L-01)

All three findings are recorded under `reports/phoenix-phase-2-staging-02/findings/` (M-01 medium, M-02 medium, L-01 low) and the ledger entries are namespaced `entryPoint = RestoreMintAtIndex4`.
