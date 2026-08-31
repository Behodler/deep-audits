# Script Audit — `deploy:ratchet-mainnet`

| Field | Value |
|-------|-------|
| Project | `phoenix-phase-2-staging` |
| Entry point | `deploy:ratchet-mainnet` (`forge script DeployMainnetNudgeRatchet`) |
| Target commit | `3c46ebc` |
| Run | `phoenix-phase-2-staging-19` |
| Mode | fork-preview (regression-reconciled, fresh entry point — 0 prior collisions) |
| Fork block | mainnet `25356592` (chainId 1, live RPC) |
| Owner / signer | `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (Ledger, HD path `m/44'/60'/46'/0/0`) |
| Story | promotes story-068 local NudgeRatchet integration to mainnet; patcher tags story-069 |

### Nested source pins (verified)

| Submodule | Pin | Note |
|-----------|-----|------|
| `lib/yield-claim-nft` | `7b86dec` | story-038, **ahead** of run-11 `b8322ee` — contains the M-03 & M-04 fixes |
| `lib/nft-staking` | `eee9d3a` | story-017 `NFTStakerPriceScaled` |
| `lib/flax-token-v2` | `f5300117` | phUSD == FlaxToken instance |
| `lib/pauser` | `545928d` | global Pauser |

---

## Executive summary

`deploy:ratchet-mainnet` is a single-broadcast mainnet deployment that promotes the locally-staged NudgeRatchet integration (story-068, `DeployMocks` Phase 3.7) onto mainnet. The command chain is:

```
node scripts/backup-mainnet-addresses.js
  → forge script DeployMainnetNudgeRatchet --broadcast --skip-simulation --slow --ledger
  → node scripts/patch-mainnet-addresses-ratchet.js
```

The script deploys five contracts, performs four on-chain mutations against live contracts, and the post-broadcast Node patcher performs one destructive off-chain write. Because the broadcast runs under `--skip-simulation`, the in-script `require` gates are the *only* pre-flight guard — this audit treats them as load-bearing.

The script was exercised via its `deploy:ratchet-mainnet-preview` variant (`PREVIEW_MODE=true`, owner pranked, no broadcast and no JS stages) against a mainnet fork at block `25356592`. The result is clean on all three audit questions:

- **Q1 — Does it do what it intends?** YES. All 18 steps executed, every `require` gate passed, and all three `_verifyWiring` post-conditions held.
- **Q2 — Unintended side effects?** NONE. Every observed state write maps to the declared 5-deploy + 4-mutation + 1-destructive-patch surface; the three plausible over-reach vectors were explicitly refuted on the fork.
- **Q3 — Knock-on / cluster problems?** Both prior NudgeRatchet ledger findings (M-03, M-04) are confirmed FIXED at the pinned `yield-claim-nft@7b86dec` and fork-verified end-to-end.

Net new findings: **1 Low** (resume-resilience footgun) and **2 QA** (documentation / provenance nits). No High or Medium. The script is faithful to its story-069 intent and introduces no unintended on-chain side effects.

### Closure at a glance

| Surface | Count | Detail |
|---------|-------|--------|
| Contracts deployed | 5 | `RatchetBatchNFTMinter`(=BatchNFTMinter), `NudgeRatchet`, `NudgeRatchetMintDebtHook`, `RatchetNFTStaker`(=NFTStakerPriceScaled), `MintPageView` |
| On-chain mutations | 4 | NFTMinterV2 `registerDispatcher(ratchet,10e6,100)` → index 7; phUSD `setMinter(hook,true)`; ViewRouter `setPage("mint", newMintPageView)`; Pauser `register(RatchetNFTStaker)` |
| Destructive off-chain write | 1 | patcher UPDATE-overwrites the live `MintPageView` key in `mainnet-addresses.ts` (only non-zero key it replaces) |
| Key constants | — | `RATCHET_PRICE_SCALE = 1e12`, `RATCHET_INITIAL_PRICE = 10e6`, `RATCHET_GROWTH_BPS = 100`, `TARGET_APY = 0.45e18` |

---

## Q1 — Does the script do what it intends? **YES**

The preview variant ran to completion against the fork without reverting. The declared intent (deploy the five ratchet contracts, wire them, register the dispatcher at index 7, redeploy/repoint `MintPageView`, then patch the off-chain address book) was satisfied in full.

### Pre-conditions — all gates passed

Because `--skip-simulation` disables forge's pre-simulation, the in-script `require` gates are the sole pre-flight. All passed on the fork:

- `block.chainid == 1`.
- Config-safety gates: `RATCHET_INITIAL_PRICE > 0`, `RATCHET_GROWTH_BPS > 0`, `TARGET_APY > 0`, `RATCHET_PRICE_SCALE > 0`, non-zero `USDC`/`USDS`/`PHUSD`/`OWNER_ADDRESS`.
- `NudgeRatchet` ctor `USDC.decimals() == 6` (6-dp payment-token guard).
- `registerDispatcher` gate `nudgeRatchetHook != 0` (the M-04 ordering guard — hook must be wired before registration).
- Live-state ownership: NFTMinterV2, ViewRouter, Pauser, and phUSD all confirmed owned by `0xCad1…D0B6` at block `25356592` (`cast call`).
- `NFTMinterV2.nextIndex == 7`, `configs(7)` empty, `configs(6).disabled == true` (the permanently-disabled bugged pooler).

### Post-conditions — all `_verifyWiring` asserts held

- `dispatcherToIndex(nudgeRatchet) == 7` (also asserted inline at the registration step).
- `MintPageView.nftMinter() == NFTMinterV2`.
- `ViewRouter.pages(keccak256("mint")) == newMintPageView`.

This promotes the story-068 local integration to mainnet; the patcher header tags the on-chain rollout as story-069.

---

## Q2 — Does the script introduce unintended side effects? **NONE**

Every state write observed on the fork maps cleanly onto the declared surface (5 deploys + 4 on-chain mutations + 1 destructive off-chain patch). The three over-reach vectors most plausible for a deployment of this shape were each explicitly tested and refuted:

1. **phUSD minter grant does not open an unbacked-mint surface.** `phUSD.setMinter(hook, true)` only *adds* the new `NudgeRatchetMintDebtHook` as an authorized minter. The pre-existing index-4 pooler hook (`0x4A26…`) remains authorized — that is the intended multi-dispatcher design, serving the still-active index-4 dispatcher, not a surface introduced by this script.

2. **Repointing the ViewRouter `mint` page does not drop index 4.** The newly deployed `MintPageView` is a strict *superset* of the outgoing view (`OLD_MINT_PAGE_VIEW 0x64FE…D119`): it serves EYE/1, SCX/2, Flax/3, USDS/4 (pooler), WBTC/5, **plus the new Ratchet/7 entry** and burn totals. The repoint adds index 7 without dropping index 4, satisfying the story-048 NOTICE requirement.

3. **Break-glass coverage is present (not a YS-21-style gap).** The ratchet and hook are intentionally left unregistered with the Pauser because their dispatch is `onlyMinter`-gated behind NFTMinterV2's mint path, and NFTMinterV2 is already Pauser-registered. A global pause via NFTMinterV2 makes the index-7 mint revert `"Contract is paused"`, confirmed empirically on the fork. The new `RatchetNFTStaker` is itself Pauser-registered (step 16). There is no unpausable mint path.

The fork run recorded no unintended state writes (`unintendedEffects: []`).

---

## Q3 — Knock-on / cluster problems? **Both prior NudgeRatchet ledger findings confirmed FIXED**

This slice cuts directly across the two open `yield-claim-nft` ledger findings on the NudgeRatchet (run-11, story-035 @ `b8322ee`). The pinned submodule (`7b86dec`) is ahead of that commit and carries the fixes; both were re-proved end-to-end on the fork.

- **M-03 — 1e12× decimal under-mint (sign-flip over-correct re-audit trap): FIXED, correct direction.** On the fork, a 10 USDC (`10e6`) mint at index 7 accrues *exactly* `10e18` phUSD debt and `pull()` realises exactly `10e18` to the staker. The audit asserted the result is neither `10e6` (uncorrected) nor `10e30` (over-corrected) — confirming the fix moved in the correct direction, not the dangerous over-correction direction the M-03 re-audit note warns about. Root: `NudgeRatchetMintDebtHook.onDispatch` `added = (amount * 1e12 * ratio) / 100`, multiply-then-divide flooring.

- **M-04 — unwired-hook zero-debt footgun: FIXED.** The script wires the hook on the ratchet (step 6) and grants phUSD minter authority (step 7) *before* `registerDispatcher` (step 8). The `require(hook != 0)` registration gate plus the dispatcher's `hookTypeId` guard mean the first index-7 mint accrues and realises debt — no silent zero-debt mint at deploy completion.

- **M-04 residual inter-step window — BENIGN.** There is a window where the dispatcher is registered (step 8) before `hook.recipient` is set (step 12). A mint during this window still accrues `10e18` debt; `pull()` reverts `RecipientUnset`, but the debt *persists* and is fully recoverable once the recipient is set. No debt is lost and no unbacked phUSD is produced.

### Cluster context

The dominant cluster relationship is with the story-048 `RedeployMintPageViewV2` predecessor: that script carries the explicit NOTICE that the ratchet rollout must redeploy `MintPageView` so the index-7 entry resolves — and steps 17–18 of this deploy *are* that redeploy and repoint. Both write the same ViewRouter `mint` page; the superset check above confirms the ordering is safe. The local `DeployMocks` Phase 3.7 (story-068) is the template this script mirrors; the only flagged divergence (batch-minter deployed first here vs. last locally) does not affect wiring correctness.

---

## Findings

| ID | Severity | Title | Location | Record |
|----|----------|-------|----------|--------|
| L-01 | Low | NonAtomicResumeOnConsumedNextIndex | `script/DeployMainnetNudgeRatchet.s.sol:_registerRatchetDispatcher` (L422–443) | [findings/low/L-01-nonatomic-resume-consumed-nextindex.json](../../findings/low/L-01-nonatomic-resume-consumed-nextindex.json) |
| QA-01 | QA | DocstringStepNumberingMismatch | `script/DeployMainnetNudgeRatchet.s.sol:run` `@notice` (L36–58) | [findings/qa/QA-01-docstring-step-numbering-mismatch.json](../../findings/qa/QA-01-docstring-step-numbering-mismatch.json) |
| QA-02 | QA | ConditionalHeaderRegexNoOp | `scripts/patch-mainnet-addresses-ratchet.js:run` (L176–183) | [findings/qa/QA-02-conditional-header-regex-noop.json](../../findings/qa/QA-02-conditional-header-regex-noop.json) |

### L-01 — Non-atomic resume on a consumed `nextIndex` (Low, footgun)

`registerDispatcher` consumes `NFTMinterV2.nextIndex` (7 → 8) as a side effect of registration. Under `--skip-simulation --slow`, the resumable progress file is flushed via `vm.writeFile` *after* the registration tx lands. A crash in the tx-land-to-flush gap leaves the on-chain index already consumed (now 8) while the progress file still marks the step pending. On resume, the script redeploys and re-registers a fresh `NudgeRatchet`, which lands at index 8, and the inline `require(ratchetIndex == 7)` drift guard reverts — halting the resume and leaving the originally-registered ratchet orphaned at index 7.

This is an operational availability hazard on resume only: no asset loss, no theft path, recoverable via manual progress-file repair, requires a crash inside a narrow non-atomic window, and is owner-operated. It qualifies as a Law-3 footgun because a competent, non-malicious operator would be surprised that a mid-broadcast crash *bricks* the resume rather than continuing it. The `require(ratchetIndex == 7)` assertion itself is a correct drift guard and must be retained — it is the redeploy-on-resume that should be made idempotent. Fix: flush progress atomically with (or strictly before) the consuming tx, or add an idempotent already-registered pre-check before redeploy.

### QA-01 — Docstring step-numbering mismatch (QA)

The `@notice` step block above `run()` drifts from the body and its in-body section headers: `registerDispatcher` is documented as step 9 but executes as step 8; `setDispatcherIndex` is documented as step 3 but executes as step 9. The execution *ordering* is correct and the on-chain effect is unaffected — only the docstring numbering is wrong, and it could mislead an operator reading the header during a resume or triage. Fix: renumber the `@notice` block to match the body.

### QA-02 — Conditional header-regex no-op (QA)

The story-069 provenance-header injection in the patcher uses an anchored replace (`/(\/\/ Updated [^\n]*\n)(?=import)/`) that only matches when a prior `// Updated` line already precedes the import block. If no such line exists, the replace silently no-ops and the provenance/audit-trail header is never written. Address patching is independent and still succeeds — only the audit-trail header is lost. Fix: add an unconditional prepend fallback when the anchored regex does not match.

---

## Empirical evidence

The fork preview and the M-03/M-04 confirmations are preserved as a runnable PoC in the writable workspace:

`workspace/phoenix-phase-2-staging/test/AuditRatchetMainnetDeploy.t.sol` — 4 tests passing (fork preview + M-03 decimal direction + M-04 wiring + benign residual window).

---

## Verdict

The `deploy:ratchet-mainnet` script is **faithful to its story-069 intent**, **introduces no unintended on-chain side effects**, and the two prior ledger findings this slice could have re-surfaced (M-03, M-04) are **confirmed fixed** on the fork at the pinned `yield-claim-nft@7b86dec`. The three plausible over-reach vectors (phUSD minter grant, ViewRouter page drop, break-glass gap) were each explicitly refuted. Net new exposure is a single Low resume-resilience footgun (L-01) plus two QA documentation/provenance nits (QA-01, QA-02). No High or Medium findings. The script is suitable for mainnet broadcast subject to the operator awareness noted in L-01.
