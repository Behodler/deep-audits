# Script Audit — `uniboost-cutover`

| Field | Value |
|-------|-------|
| Project | `phoenix-phase-2-staging` |
| Entry point | `uniboost-cutover` (`forge script DeployMainnetUniboostCutover`) |
| Target commit | `c5956a9` (submodule HEAD) |
| Run | `phoenix-phase-2-staging-20` |
| Mode | fork-preview (fresh entry point — 0 prior fingerprint collisions) |
| Fork block | mainnet `25485632` (chainId 1, live RPC read-only) |
| Owner / signer | `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (Ledger, HD path `m/44'/60'/46'/0/0`) |
| Story | story-071 — mainnet differential deploy promoting story-070 `DeployMocks` |

### Nested source pins (at HEAD `c5956a9`)

| Submodule | Pin | Note |
|-----------|-----|------|
| `lib/yield-claim-nft` | `f46a5cb` | story-043 — source of `NFTMinterV2`, `Uniboost`, `UniboostMintDebtHook`, `MultiPooler`, `NudgeRatchetDelayRelease`, `NudgeRatchetMintDebtHook`, `BurnRecorder` |
| `lib/nft-staking` | `321d0a9` | source of `NFTStakerDepletion` (new Uniboost stakers) and `NFTStakerPriceScaled` (the reused `RatchetNFTStaker`) |
| `lib/flax-token-v2` | `f5300117` | phUSD == `FlaxToken` instance (mutated via `setMinter`) |
| `lib/pauser` | `545928d` | global `Pauser` |

### Scope of this audit

This is a **scoped script-audit** of a single `package.json` entry point (`uniboost-cutover`), **not** a full-project regression of `phoenix-phase-2-staging`. It resolves and reviews only the transitive closure of the `DeployMainnetUniboostCutover` cutover — the forge/JS command chain, the Solidity import graph, the on-chain addresses it mutates, the off-chain files it writes, and the sibling scripts that touch the same contracts. Contracts outside that closure were not re-scanned. Accordingly the project's `lastAuditedCommit` baseline stays at `0e190e8` (the run-15 ys-swap saga); this entry-point audit does not advance it.

---

## Executive summary

`uniboost-cutover` is a mainnet differential deploy that promotes story-070's local `DeployMocks` staging (Uniboost dispatcher stack + index-7 ratchet swap) onto mainnet in a **single Ledger signing session**. It performs two coordinated cutovers against the live `NFTMinterV2` (`0x39Af08…`):

- **(A) Uniboost cutover at indices 1/2/3.** Replace the three live `BurnerV2` dispatchers (EYE / SCX / FLX) with `Uniboost` dispatchers, each backed by a live `<TOKEN>/WETH` UniV2 pool, a `UniboostMintDebtHook`, and an `NFTStakerDepletion` staker, with a single `MultiPooler` wired as each Uniboost's sole authorized pooler. Because `replaceDispatcher` preserves the outgoing burner's 18-decimal target-token price, each replace is followed by a **mandatory** `setPrice(idx,10e6)` + `setGrowthFactor(idx,2)` reprice onto the USDC-6dp Uniboost basis.
- **(B) Index-7 ratchet swap.** Swap `NudgeRatchet` → `NudgeRatchetDelayRelease` (drain-first) with a fresh `NudgeRatchetMintDebtHook`, repoint the existing `RatchetNFTStaker`, and decommission the old ratchet hook. Index-7 price/growth (`70e6/0`) is deliberately left untouched — both the old and new index-7 dispatchers are USDC-6dp.

The command chain for the live rollout is:

```
node scripts/backup-mainnet-addresses.js
  → forge script DeployMainnetUniboostCutover --broadcast --skip-simulation --slow --ledger
  → node scripts/patch-mainnet-addresses-uniboost-cutover.js
```

The `:broadcast` variant is a **non-atomic, multi-transaction** sequence (~12 CREATE + ~28 config/mutation txs). `--slow` submits and confirms each tx before the next; `--skip-simulation` disables forge's pre-flight, so the in-script `require` gates are the **only** pre-flight guard and are treated as load-bearing. The script writes `server/deployments/progress.uniboost-cutover.1.json` after every CREATE and config step so a mid-flight halt can be resumed idempotently.

The audit exercised the `:dry` preview variant (`PREVIEW_MODE=true`, owner pranked, no broadcast and no JS stages) against a mainnet fork at block `25485632`. The result is clean on all three audit questions:

- **Q1 — Does it do what it intends?** YES. The preview ran end-to-end without reverting; every Phase-0 precondition, every `require` post-condition, and `_verifyFinalState` passed. Parity with the story-070 `DeployMocks` blueprint is exact except the single documented delta (Uniboost growth `10 → 2` bps, require-gated).
- **Q2 — Unintended side effects?** NONE. Every observed state write maps to declared intent; `unintendedEffects: []`. Five over-reach vectors were explicitly refuted on the fork.
- **Q3 — Knock-on / cluster problems?** **3 Low** operational footguns, all tied to the non-atomic multi-tx broadcast (abort / resume / verification-surface). No High or Medium.

Net new findings: **0 High, 0 Medium, 3 Low**. The script is faithful to its story-071 intent and introduces no unintended on-chain side effects; the residual exposure is entirely operator-timing / assurance-surface hazard on a partial or resumed broadcast.

### Closure at a glance

| Surface | Count | Detail |
|---------|-------|--------|
| Solidity imports (direct) | 18 | all resolve to concrete files under `lib/` at HEAD; `NFTMinterV2` + 6 dispatcher/hook/staker sources + `Pauser` + `BurnRecorder` + OZ IERC20/IERC1155 + forge-std |
| On-chain addresses | 21 | 6 mutated (`NFTMinterV2`, phUSD, `Pauser`, `BurnRecorder`, `RatchetNFTStaker`, + owner EOA) · 5 replaced (3 burners, old ratchet, old hook) · 10 referenced (tokens / pools / router / batch-minter) |
| CREATE deployments | 12 | 3× `Uniboost` + 3× `UniboostMintDebtHook` + `MultiPooler` + 3× `NFTStakerDepletion` + `NudgeRatchetDelayRelease` + `NudgeRatchetMintDebtHook` |
| Off-chain files | 3 | `progress.uniboost-cutover.1.json` (checkpoint, write) · `mainnet-addresses.ts` (backup + positional patch) · `broadcast/…/run-latest.json` (read by patcher) |
| Cluster scripts | 5 | `DeployMocks` (blueprint) · `DeployMainnetNudgeRatchet` (predecessor) · `FixRatchetBatchMinterSink` (predecessor) · `DispatcherReplaceAtIndex4` (sibling-config) · `CutoverAndRevokeOldMinter` (evaluated-out) |

---

## Fork preview

| Property | Value |
|----------|-------|
| Variant | `uniboost-cutover:dry` — `PREVIEW_MODE=true forge script … --rpc-url $RPC_MAINNET --slow -vvv` |
| Actor | `vm.startPrank(OWNER)` (impersonated owner, no signing, no broadcast, no progress file) |
| Fork block | mainnet `25485632` |
| Reverted | no — *"Script ran successfully."* |
| Preconditions | **all pass** (9/9) |
| Post-conditions | **all pass** — per-index `configs(1/2/3)` {dispatcher, price==10e6, growth==2}; `configs(7).dispatcher==newRatchet` (price/growth 70e6/0 untouched); `RatchetNFTStaker.dispatcherHook()==newRatchetHook`; `OLD_RATCHET_HOOK.mintDebt()==0` after drain |
| Unintended writes | **0** (`unintendedEffects: []`) |

**Phase-0 preconditions verified live at the fork block:**

- `NFTMinterV2.owner() == RatchetNFTStaker.owner() == phUSD.owner() == OWNER` (`0xCad1…D0B6`).
- `configs(1)==BURNER_EYE` (`0x13fb51BC…`, price `464.279e18`, growth `1000`), `configs(2)==BURNER_SCX` (`0xA833603f…`, `1.737e18`), `configs(3)==BURNER_FLX` (`0xb63b5702…`, `22876.13e18`), `configs(7)==OLD_NUDGE_RATCHET` (`0x7A4eD111…`, `70e6/0`).
- `OLD_NUDGE_RATCHET.batchMinter() == BATCH_NFT_MINTER` (`0x86866e…`) and `!= 0` — the `RATCHET_SINK` precondition established by the `FixRatchetBatchMinterSink` predecessor (story-069), confirmed applied live.
- 3 target pools sane (pair has code, target token present, reserves > 0).

**Configuration-safety gates** (require-guarded before any mutation, all present and passing, none defaulted): `UNIBOOST_PRICE == 10e6`, `UNIBOOST_GROWTH_BPS == 2`, `0 < DONATION_SPLIT <= 100`, `1 <= DEPLETION_WINDOW_MONTHS <= 120`, core addresses `!= 0`.

Because the `:dry` variant is a live read-only `eth_call` preview (no fork-isolation flag, prank instead of broadcast), the observed state and every gate reflect true mainnet state at block `25485632`.

---

## Q1 — Does the script do what it intends? **YES**

The preview ran to completion without reverting, and the declared end state was reached in full. The two cutovers execute across six phases (setUp chain-id guard → config-safety gates → progress-file load → Phase 0 preconditions → Phase 1 deploy/wire Uniboost stack → Phase 2 replace+reprice → Phase 3 donation config + staker deploy/wire → Phase 4 drain-first index-7 swap → Phase 5 burner cleanup → `_verifyFinalState` → Phase 6 progress-write).

### Parity with the story-070 `DeployMocks` blueprint

The story-071 mainnet script is a differential promotion of the story-070 local mock deploy — the only other script that builds the Uniboost / `MultiPooler` / `NudgeRatchetDelayRelease` stack. The wiring parameters match the blueprint exactly, with a single documented divergence:

| Param | Mock (070) | Mainnet (071) | Verdict |
|-------|-----------|---------------|---------|
| Uniboost price | `10e6` | `10e6` | parity |
| Uniboost growth | `10` bps | **`2` bps** | **deliberate documented delta** (require-gated) |
| Donation split | `50` | `50` | parity |
| Hook ratio | `DEFAULT_RATIO=50` (unset) | `DEFAULT_RATIO=50` (unset) | parity |
| Donation recipient | index-4 LSP `BatchNFTMinter` | `BATCH_NFT_MINTER 0x86866e…` (index-4 LSP) | parity |
| Depletion window | 12 mo | 12 mo | parity |
| `MultiPooler.pooler` | deployer | OWNER | parity (operator EOA) |
| Index-7 price/growth | `70e6/0` (USDC) | `70e6/0` untouched | parity |

The only divergence is the require-gated `10 → 2` bps growth override, which is documented in the script's own config-safety gate (`UNIBOOST_GROWTH_BPS == 2`). No undocumented divergence was found. The mock's per-Uniboost UI `BatchNFTMinter` loopers are intentionally not ported (UI convenience, nudge-disabled, hold no funds) — an expected omission, not a wiring gap.

### Reprice correctness

The mandatory `setPrice(idx,10e6)` + `setGrowthFactor(idx,2)` after each `replaceDispatcher(1/2/3)` is confirmed necessary and correct: `replaceDispatcher` preserves the outgoing burner's 18-decimal target-token price (`464.279e18 / 1.737e18 / 22876.13e18`), which is meaningless on the USDC-6dp Uniboost basis. Leaving index-7 untouched is likewise correct — both the old `NudgeRatchet` and new `NudgeRatchetDelayRelease` require `USDC.decimals()==6` in their constructor, and the live `70e6/0` is a valid 6-dp USDC price.

---

## Q2 — Does the script introduce unintended side effects? **NONE**

Every state write observed on the fork maps cleanly onto declared intent (`unintendedEffects: []`). The full mutation set is:

- **`NFTMinterV2` configs** — full swap of slots 1/2/3 (`{dispatcher, price, growth}` → `{uniboost, 10e6, 2}`); dispatcher-only swap of slot 7 (price/growth `70e6/0` left intact); `dispatcherToIndex` / `tokenIdToDispatcher` re-pointed for indices 1/2/3/7.
- **phUSD `setMinter` — exactly 5 calls.** 3 Uniboost hooks + the new ratchet hook granted (`false → true`); the old ratchet hook revoked (`true → false`). The 3 retired `BurnerV2` dispatchers were **never** phUSD minters (they burn target tokens), so no stray minter is left behind and no additional revoke is owed.
- **`Pauser.register` ×3** — the 3 new `NFTStakerDepletion` stakers.
- **`BurnRecorder.setBurner(false) ×3** — Phase-5 cleanup of the 3 retired burners (verified holding 0/0/0 target tokens on the fork).
- **`RatchetNFTStaker`** — `pullAndRefresh()` drains the old hook's `mintDebt` to 0 (realized to the staker), then `setDispatcherHook(newRatchetHook)`.
- **12 CREATE deployments** — all owner-initialized and wired per intent.

There is **no** ownership change, **no** write to any untouched dispatcher index, and **no** token exfiltration. Five over-reach vectors most plausible for a cutover of this shape were each explicitly refuted on the fork:

1. **Live-but-unwired hook window does not revert or mis-mint (M-04 class).** Both `UniboostMintDebtHook.onDispatch` and `NudgeRatchetMintDebtHook.onDispatch` only accrue `mintDebt += added`, gated to `dispatcher`; they never read `recipient` and never mint at dispatch time (recipient is used only by `pull()`). A mint in the replace-before-wire window succeeds — prime charged, debt accrued to the hook ledger, NFT minted — and the debt is fully recoverable once the staker is wired and `pull()` runs. This is unlike yield-claim-nft M-04 (which reverted on an absent/wrong hook). The index-7 `NudgeRatchetDelayRelease._dispatch` `hookTypeId` guard is satisfied *before* `replaceDispatcher(7)` (`setHook` precedes the replace), so no `_dispatch` revert.
2. **Off-chain patcher positional CREATE mapping is correct.** The patcher matches CREATE txs by `contractName`, consuming first-unseen in order; the script's deploy order is EYE → SCX → FLX for each repeated-name contract, and the interleaved single `MultiPooler` does not perturb name-scoped matching. `DefaultDispatchHooks` created inside dispatcher constructors are internal (`additionalContracts`), not top-level CREATE txs, so they do not shift positions. Abort guards are correct (exit 2 on progress != `completed`, exit 4 on non-zero collision, exit 3 on missing CREATE). `mainnet-addresses.ts` confirmed: 10 zero placeholders + 2 live ratchet keys, 55 keys total; the patcher only fills/updates, never adds/removes keys.
3. **Index-7 needs no reprice.** Both index-7 dispatchers are USDC-6dp-primed; leaving `70e6/0` untouched is correct.
4. **Uniboost config does not over-mint / under-back phUSD.** Per 10 USDC mint: the hook accrues 5 phUSD (ratio 50), the Uniboost donates 5 USDC to the LSP and retains 5 USDC (POL) — ≥ 2:1 over-backing, consistent with the yield-claim-nft run-13 Tier-3 result. The `NudgeRatchetDelayRelease` debt/release decoupling is documented accepted design and conserves backing.
5. **No value stranded on the decommissioned old ratchet/hook.** Fork: `OLD_RATCHET_HOOK.mintDebt()==0` after `pullAndRefresh`, `OLD_NUDGE_RATCHET` stranded USDC `== 0`, retired burner target balances `0/0/0`.

---

## Q3 — Knock-on / cluster problems? **3 Low operational footguns**

All three findings share one root context: the live rollout is a **non-atomic, multi-tx Ledger broadcast** (`--slow --skip-simulation`). The happy path was fork-previewed clean; each finding is an abort / resume / verification-surface hazard on a *partial* or *resumed* broadcast, not a live happy-path defect. None is an external-attacker vector — the only actor is the trusted-but-fallible operator — and none is a malicious or obvious-misuse admin action, so known-issue #10 (admin trust) is correctly not applied to swallow them (Law 3: non-obvious operator footguns are in scope).

### Findings

| ID | Severity | Function (source) | Impact (one line) | Recommendation |
|----|----------|-------------------|-------------------|----------------|
| [UBC-01](../../findings/low/UBC-01-nonatomic-midflight-mint-revert-window.json) | Low | `_swapBurner` (`DeployMainnetUniboostCutover.s.sol` L412–436) | replace→reprice gap leaves an index transiently mint-reverting (fail-safe); persists if the broadcast aborts inside the window | Bundle replace+setPrice+setGrowthFactor per index, or disable the index around the reprice; document the fail-safe window |
| [UBC-02](../../findings/low/UBC-02-coarse-resume-unwired-staker.json) | Low (ceiling) | `_finalizeUniboost` (L452–493) | staker CREATE + 5 wiring txs share one checkpoint → a precisely-timed abort makes resume permanently skip wiring, silently; recoverable, no loss | Checkpoint each wiring step (mirror Phases 1/2/4) or split the guard so wiring re-runs on resume; add staker-wiring invariants to `_verifyFinalState` |
| [UBC-03](../../findings/low/UBC-03-incomplete-postcondition-verification.json) | Low | `_verifyFinalState` (L621–641) | "verified" banner covers only ~5 of ~25 mutations — a mis-wire (incl. UBC-02) completes silently | Extend `_verifyFinalState` to positively assert the full wiring set (5 phUSD minter grants/revoke, donation config, hook.recipient, pooler-auth, staker wiring, releaser/minter) |

### UBC-01 — Non-atomic replace→reprice window (Low, footgun; fail-safe)

Under `--slow --skip-simulation`, `replaceDispatcher(idx, uniboost)`, `setPrice(idx,10e6)` and `setGrowthFactor(idx,2)` inside `_swapBurner` are three separate on-chain txs. Between the replace and the reprice, `configs[idx]` points at the USDC-6dp Uniboost but still carries the old burner's 18-dp price (`464.279e18 / 1.737e18 / 22876.13e18`); a mint on that index in the gap would require `transferFrom` of `~4.6e14 … 2.3e16` raw USDC and **reverts**. This is a **fail-safe (deny) direction** — no under-charge, no mis-mint, no loss — the opposite of a value leak. Under `--slow` the window is seconds-to-minutes; if the broadcast aborts (Ledger reject / gas / RPC) precisely between the two txs, the index stays mint-reverting until the operator re-runs. Resume **heals** it: `_swapBurner` checkpoints (`_trackConfig`) only after all three txs and the post-assert succeed, so a resume idempotently re-runs the whole block (the second `replaceDispatcher` is a no-op because `dispatcherToIndex[uniboost]==index`). Low: no loss, fail-safe direction, self-healing, narrow operator-controlled window.

**Refuted headline hypothesis (recorded for transparency):** the live-but-unwired-hook window at the affected index is **benign** — the mint-debt hooks only accrue recoverable `mintDebt` and never mint or read `recipient` at dispatch (see Q2 vector 1), so a mint that lands *after* the reprice but *before* the staker is wired is loss-free and fully recoverable via `pull()`.

### UBC-02 — Coarse resume checkpoint granularity (Low, ceiling-of-band; footgun)

This is the highest-value finding. In `_finalizeUniboost` the staker block is guarded by `if (_isDeployed(stakerName)) return staker;`. Immediately after `new NFTStakerDepletion(...)`, the script calls `_trackDeployment` (sets `deployed=true`) then `_writeProgressFile()` (persists `deployed=true`) **before** performing the five wiring txs — `setDispatcherHook(hook)`, `hook.setRecipient(staker)`, `setDepletionWindow(12)`, `setPauser(PAUSER)`, `Pauser.register(staker)` — with **no per-step checkpoint** (every other phase checkpoints each config step individually).

If a broadcast lands the CREATE but not (all of) the wiring, a resume sees `_isDeployed(stakerName)==true` and **returns early**, permanently skipping the wiring. The result is a deployed-but-unwired staker: `dispatcherHook==0` (cannot `pull()` → accrued phUSD mint-debt is never realized to stakers), `hook.recipient != staker` (debt not directed to the pool), `depletionWindow==0`, and the staker unregistered with the global `Pauser` (no pause / break-glass coverage). The Uniboost staker feature is non-functional until manually repaired — and because `_verifyFinalState` asserts none of it, the run still prints a **success/verified banner**, so the misconfiguration is **silent** and can persist in production until someone notices debt is not accruing.

It stays **Low (ceiling of band)**, not Medium, on three conservative factors: (1) **no loss** — the accrued mint-debt is parked in the hook ledger and fully recoverable once an owner replays the wiring and `pull()`s; nothing leaks to an attacker or a burn; (2) the trigger is a precisely-timed abort of a controlled, operator-initiated one-shot broadcast — low likelihood, no external-attacker surface; (3) recovery uses known, in-script steps. This is the same **non-atomic-resume class** as the run-19 `deploy:ratchet-mainnet` L-01 (a consistent precedent), but the severity is re-derived on its own facts. The silent-availability aggravator is real and is a reason to fix **both** UBC-02 and UBC-03 — not a reason to relabel a recoverable, no-loss, precisely-timed footgun as Medium.

### UBC-03 — Incomplete post-condition verification (Low, assurance-surface)

`_verifyFinalState` positively asserts only `configs(1/2/3)` {dispatcher, price, growth}, `configs(7).dispatcher`, and `RatchetNFTStaker.dispatcherHook` — roughly **5 of ~25** safety-critical mutations. It omits: the 4 phUSD minter grants + 1 revoke (incl. `OLD_RATCHET_HOOK`); the 3 `setRecipient(BATCH_NFT_MINTER)` + `setDonationSplit(50)`; the 3 Uniboost `hook.setRecipient(staker)`; `MultiPooler.setPooler` + the 3 `setAuthorizedPooler`; the 3 staker `dispatcherHook` / `depletionWindow` / `Pauser` registrations (the exact UBC-02 case); and `NudgeRatchetDelayRelease.setMinter/setReleaser` + `newRatchetHook.setRecipient`.

On the happy path this is purely assurance-surface: every omitted mutation *does* execute under its own guard in a clean full pass (fork-preview confirmed), so there is no live defect and no asset impact. Its real weight is as the **missing detection layer** that would have converted UBC-02's silent skip — or a hand-edited/corrupted `progress.1.json` (a resume workflow the project's `CLAUDE.md` explicitly documents) — into a loud, caught revert. Low: no impact absent an upstream mis-wire, but genuine operational weight as the safety net for a real-money mainnet cutover.

---

## Cluster analysis

The entry point cuts across a 5-script cluster on the shared `NFTMinterV2` / index-7 / `BATCH_NFT_MINTER` surface:

- **`DeployMocks` (story-070, blueprint).** The story-070 local (anvil 31337) mock deploy whose Uniboost-stack + index-7 ratchet-swap this script promotes to mainnet ("promoting Story 070's DeployMocks changes to mainnet"). It is the **primary conformance reference** — the mainnet wiring must match the mock's parity, and it does, with the sole deliberate `10 → 2` bps growth override (see Q1 parity table). Strongest structural signal.
- **`DeployMainnetNudgeRatchet` (story-069, predecessor).** Deployed the **old** plain `NudgeRatchet` at index 7 that this script now swaps for `NudgeRatchetDelayRelease`. It establishes the index-7 baseline (`price 70e6 / growth 0`) this script leaves untouched, and this script explicitly mirrors its single-broadcast + progress-file resume pattern. Its own non-atomic-resume footgun (run-19 L-01) is the class-sibling of UBC-02.
- **`FixRatchetBatchMinterSink` (story-069, corrective predecessor).** Set `OLD_NUDGE_RATCHET.setBatchMinter(0x86866e…)` — exactly the `RATCHET_SINK` this script's Phase-0 reads and `require()`s `== BATCH_NFT_MINTER`. Had that corrective not landed (or reverted), this script's precondition would fail; the live `batchMinter()` read confirms the sink is in the expected state.
- **`DispatcherReplaceAtIndex4` (story-048, sibling-config).** Same `replaceDispatcher` cutover pattern on the same `NFTMinterV2` but at a disjoint index (4). Prior art for the "replaceDispatcher preserves price/decimals" hazard that motivates UBC-01's reprice — useful precedent, not an ordering dependency.
- **`CutoverAndRevokeOldMinter` (story-065, evaluated-out).** Evaluated per task and excluded from the active cluster: it cuts the phUSD **stable-minter** flow (a different "minter" concept than `NFTMinterV2`) and shares none of this script's address constants or indices.

---

## Verdict

The `uniboost-cutover` script is **faithful to its story-071 intent** and **introduces no unintended on-chain side effects**. The fork preview ran end-to-end without reverting; all Phase-0 preconditions, all `require` post-conditions, and `_verifyFinalState` passed; parity with the story-070 `DeployMocks` blueprint is exact but for the single require-gated `10 → 2` bps growth delta; and five plausible over-reach vectors (live-but-unwired hook window, off-chain patcher positional mapping, index-7 reprice, over-mint/under-backing, stranded old-ratchet value) were each explicitly refuted on the fork.

Net new exposure is **3 Low** operational footguns, all rooted in the non-atomic multi-tx Ledger broadcast: UBC-01 (fail-safe replace→reprice window, self-healing on resume), UBC-02 (coarse resume checkpoint that can silently cement an unwired staker — the ceiling-of-Low, borderline-Medium item and the highest-value finding), and UBC-03 (partial `_verifyFinalState` that would fail to catch UBC-02). **No High or Medium.** The script is suitable for mainnet broadcast subject to the operator awareness noted in UBC-01/02/03 — in particular, extending `_verifyFinalState` to positively assert the full wiring set (UBC-03) directly closes the silent-failure surface behind UBC-02.

As a scoped script-audit, this run does not advance the project baseline; `lastAuditedCommit` remains `0e190e8`.
