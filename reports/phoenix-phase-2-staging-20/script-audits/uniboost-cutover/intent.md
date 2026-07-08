# Intent — uniboost-cutover (Story 071, submodule HEAD c5956a9)

Script: `script/DeployMainnetUniboostCutover.s.sol:DeployMainnetUniboostCutover`
Mode audited: **fork-preview** (`PREVIEW_MODE=true ... --rpc-url $RPC_MAINNET --slow -vvv`) against live mainnet, block ~25485632. Preview **ran successfully** (no revert; `_verifyFinalState` passed).

## Stated purpose (from package.json `//uniboost-cutover`, NatSpec, and DeployMocks Story-070 parity)
Two coordinated cutovers in one Ledger signing session (non-atomic multi-tx):

- [x] **(A) Uniboost cutover at indices 1/2/3.** Replace the three live BurnerV2 dispatchers (EYE/SCX/FLX) with `Uniboost` dispatchers, each backed by a live `<TOKEN>/WETH` UniV2 pool + a `UniboostMintDebtHook` + an `NFTStakerDepletion` staker; a `MultiPooler` wired as each Uniboost's sole authorized pooler (deployer/OWNER = MultiPooler.pooler).
- [x] **MANDATORY reprice** after each `replaceDispatcher(idx)`: `setPrice(idx,10e6)` + `setGrowthFactor(idx,2)` — because `replaceDispatcher` preserves the burners' 18-dp target-token price (464.279e18 / 1.737e18 / 22876.13e18) and the new Uniboost is USDC-6dp-primed.
- [x] **(B) Index-7 ratchet swap.** Swap `NudgeRatchet` → `NudgeRatchetDelayRelease` (deployer whitelisted releaser) with a fresh `NudgeRatchetMintDebtHook`; drain-first via `RatchetNFTStaker.pullAndRefresh()`; repoint the existing `RatchetNFTStaker`; decommission the old ratchet hook. Index-7 price/growth left UNTOUCHED at 70e6/0 (correct — both old and new index-7 dispatchers are USDC-6dp).

## Parity contract vs DeployMocks (Story 070, blueprint)
| Param | Mock (070) | Mainnet (071) | Verdict |
|---|---|---|---|
| Uniboost price | 10e6 (10 USDC) | 10e6 | parity |
| Uniboost growth | 10 bps | **2 bps** | **deliberate documented delta** (require-gated) |
| Donation split | 50 | 50 | parity |
| Hook ratio | DEFAULT_RATIO=50 (unset) | DEFAULT_RATIO=50 (unset) | parity |
| Donation recipient | index-4 LSP BatchNFTMinter | BATCH_NFT_MINTER 0x86866e.. (index-4 LSP) | parity |
| Depletion window | 12 mo | 12 mo | parity |
| MultiPooler.pooler | deployer | OWNER | parity (operator EOA) |
| Index-7 price/growth | 70e6/0-ish (USDC) | 70e6/0 untouched | parity |
Only divergence is the **documented** 10→2 bps growth override. No undocumented divergence found. (Mock's per-Uniboost UI `BatchNFTMinter` loopers are intentionally NOT ported — UI convenience, nudge-disabled, hold no funds.)

## Declared pre-conditions (Phase 0 `require` before mutation) — ALL HOLD LIVE
- `NFTMinterV2.owner() == OWNER` ✓ | `RatchetNFTStaker.owner() == OWNER` ✓ | `phUSD.owner() == OWNER` ✓
- `configs(1)==BURNER_EYE`, `configs(2)==BURNER_SCX`, `configs(3)==BURNER_FLX`, `configs(7)==OLD_NUDGE_RATCHET` ✓
- `OLD_NUDGE_RATCHET.batchMinter() == BATCH_NFT_MINTER (0x86866e..)` and `!= 0` ✓ (depends on cluster dep `FixRatchetBatchMinterSink`, Story 069 — confirmed applied on-chain)
- 3 target pools sane (pair has code, target token present, reserves > 0) ✓

## Configuration Safety gate (require guards before broadcast) — all deliberate, none defaulted
- `UNIBOOST_PRICE == 10e6` | `UNIBOOST_GROWTH_BPS == 2` | `0 < DONATION_SPLIT <= 100` | `1 <= DEPLETION_WINDOW_MONTHS <= 120` | core addrs != 0. All present and pass.

## Declared post-conditions
Per-index (`_swapBurner`): `configs(idx).dispatcher==uniboost && price==10e6 && growth==2` ✓
Phase 4: drain `OLD_RATCHET_HOOK.mintDebt()==0` after `pullAndRefresh` ✓ | `configs(7).dispatcher==newRatchet` ✓ | `RatchetNFTStaker.dispatcherHook()==newRatchetHook` ✓
`_verifyFinalState` (final, read-only): configs(1/2/3) dispatcher+price+growth, configs(7) dispatcher, RatchetNFTStaker.dispatcherHook ✓

### Post-condition COVERAGE GAP (see candidate finding UBC-03)
`_verifyFinalState` does NOT assert: the 5 phUSD minter grants/revoke, the 3 Uniboost donation recipient/split, the 3 Uniboost hook.recipient==staker, MultiPooler pooler-auth, the 3 staker dispatcherHook/depletionWindow/Pauser registration, NudgeRatchetDelayRelease.setMinter/setReleaser, newRatchetHook.recipient==staker, old-hook phUSD-minter revoked. All of these DO execute in a full pass, but a silent mis-wire on any of them still reports "verified."
