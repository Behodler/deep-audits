# QA Report for yield-claim-nft (run 22)

| | |
|---|---|
| **Project** | yield-claim-nft |
| **Run** | yield-claim-nft-22 |
| **Mode** | REGRESSION `267660b` → `0fd6bdf` (`master`) |
| **Audited commit** | [`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`](https://github.com/Behodler/yield-claim-nft/tree/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630) |
| **Change under review** | story-052: new `src/migration/UniPoolerCutoverEscrow.sol`, a one-off escrow that exits the Balancer BPT and seeds the empty canonical sUSDS/phUSD Uniswap V2 pair for `UniPoolerV2` (plus its tests and `test/mocks/MockV3ExitRouter.sol`) |
| **Story** | story-052 (`~/code/product-owner/stories/yield-claim-nft/review/yield-claim-nft-Balancexit/052-unipooler-cutover-escrow.md`), state folder **`review/`** |
| **Automated baseline** | [`4naly3er-report.md`](./4naly3er-report.md) (Appendix A) |

This bundle holds every new Low and QA item from run 22. There are **no High/Medium findings and no Centralization findings this run.** The Law-2 deviations (F-01-052 … F-04-052, `ycn22f1`–`ycn22f4`) are in [`spec-conformance.md`](./spec-conformance.md), not here. Open findings from earlier runs are **not** restated here. They are carried in full, one file per originating run, under [`carryover/`](./carryover/) (index in § Carryover).

## ⚠ Awaiting triage

> **Seven run-22 entries have no human decision yet.** Each is `open` in `ledger.json` with no `triageReason`. Triage them with `/ledger yield-claim-nft`. Ledger state as of 2026-10-08.

### New this run, untriaged

| Label | Fingerprint | Sev. | Report | Item | Decision the owner faces |
|---|---|---|---|---|---|
| **L-28** | `d77a482de7` | Low (borderline QA) | § L-28 below | Tight exit floors plus a public-mempool `--slow` broadcast let anyone cheaply revert `exitAndSeed`. Shares one root with F-01-052. | Choose the broadcast route (private relay) and tolerance before Stage 2, or accept the grief risk. |
| **Q-24** | `88bfa94936` | QA | § Q-24 below | Escrow price protection is entirely off-chain; the sandwich was refuted on fork. | Acknowledge as designed, or add an on-chain band. |
| **Q-25** | `b4c10f0f89` | Info | § Q-25 below | The third party's 37.1% Balancer remainder stays a second venue, leaking $8–$11 of the Stage-4 peg lift. | Acknowledge, or coordinate the remainder's exit. |
| **F-01-052** | `2d7b84f0f5` | Info | [spec-conformance § F-01-052](./spec-conformance.md) | Story-052 overstates what the operator gate prevents. Security half is L-28. | Amend the story text; triage together with L-28. |
| **F-02-052** | `5a7732a4ea` | Low | [spec-conformance § F-02-052](./spec-conformance.md) | Story-052/103 assume the owner still holds 202.30 BPT; that tranche was burned at block 25,985,119. | **Human-only:** correct the floor sizing in stories 052/103 before broadcast. |
| **F-03-052** | `8ab7d54dc9` | Info | [spec-conformance § F-03-052](./spec-conformance.md) | The human seed-price confirmation is not enforced anywhere, and the plan figures are ~2.7× stale. | **Human-only:** fold into Q-21, or keep separate. |
| **F-04-052** | `298ee7bb3b` | Info | [spec-conformance § F-04-052](./spec-conformance.md) | The escrow landed on `master` while story-052 sits in `review/`. | Close out story-052, or note the acceptance criteria may still move. |

L-27 (`2268ead7cb`) was triaged `fix-pending` on 2026-10-08. **Its fix belongs to phStaging2 story-103, not to yield-claim-nft.** The cutover script must `require(old.pool() == escrow.bpt())` before every BPT transfer into the escrow (amendment doc: `~/code/product-owner/scratchpad/planning-docs/phoenix/phStaging2/story-103-amendment-l27-bpt-guard.md`). The escrow code is unchanged by that fix, so later yield-claim-nft scans will keep seeing L-27. Verify the fix through the phStaging2 `unipooler-cutover` script audit, not by rescanning this repo.

L-26 (`b2a29359fd`) is **not** in this table because it was triaged `wont-fix` on 2026-10-07: a poisoned pair makes `exitAndSeed` fail loud, and recovery is a manual `abort()`.

The three items in [§ Parked, not dropped](#parked-not-dropped) (PATTERN-MR-003, -004, -005) also await a human decision. They are manual-review items rather than ledger entries.

### Carryovers that bear on this run

Every carried entry except Q-21 also lacks a `triageReason` (30 open plus 10 `qa-bundled`). The ones below matter now because this run's only change is the escrow that exits Balancer and seeds `UniPoolerV2`, so each touches the cutover directly.

| Label | Fingerprint | Status | Carried in | Why it matters for the cutover |
|---|---|---|---|---|
| **Q-21** | `4c2f9c705c` | `fix-pending` | [qa-report-20](./carryover/qa-report-20.md) | Re-weighed this run: the zap that lifts phUSD to $1 is now ~$1,712, so story-108's re-baseline is itself 2.7× stale. Stays `fix-pending`; F-03-052 may fold in. See [§ Q-21](#q-21-fix-pending-numbers-update-reference-only). |
| **Q-23** | `ae13a21ad9` | open | [qa-report-21](./carryover/qa-report-21.md) | Re-observed in run 22. The Uniswap V2 fee switch is live on mainnet, which shifts `UniPoolerV2.quotePool` on the pair the escrow seeds. |
| **Q-22** | `7b76f3476e` | open | [qa-report-21](./carryover/qa-report-21.md) | Wrong overflow-bound NatSpec in `UniPoolerV2._swapAmount`, the code that runs on the seeded pair. |
| **F-01-051** | `a7a62c552d` | open | [spec-conformance-21](./carryover/spec-conformance-21.md) | Story-051 credits its fix to the wrong label (`ycn20l24` instead of L-25). |
| **F-02-051** | `1b38e9e2dc` | open | [spec-conformance-21](./carryover/spec-conformance-21.md) | `UniPoolerV2` NatSpec and story-051 misstate who benefits from an unsynced donation. |
| **F-03-051** | `22e17d58aa` | open | [spec-conformance-21](./carryover/spec-conformance-21.md) | Story-051 silently supersedes story-048's "dispatcher kept verbatim" clause. |
| **F-02-048** | `49c7408c94` | open | [spec-conformance-20](./carryover/spec-conformance-20.md) | `BalancerWinddownPlan` Stage 2 (the cutover itself) names Pauser steps that conflict with story-048. |
| **L-17** | `79a2cd4a79` | open | [qa-report-19](./carryover/qa-report-19.md) | `BalancerPoolerV2` parked USDS. Dedup linked it to L-27 as related but distinct, and the escrow's `wrapUsds` sweeps that same USDS. |
| **Q-02**, **Q-05** | `261859a435`, `13fe448d0e` | qa-bundled, open | [qa-report-08](./carryover/qa-report-08.md), [qa-report-10](./carryover/qa-report-10.md) | Re-observed in run 22 on `BalancerPoolerV2`, the contract this cutover retires. Both stay live until the cutover is broadcast. |

The other `BalancerPoolerV2` entries (L-05, L-18, Q-18, F-01-047) follow the same logic as Q-02 and Q-05. Once the cutover is broadcast and the old pooler is dead, they become candidates to close in one triage pass. Do not close them before then, because the contract still holds value until the escrow runs.

---

## Summary

| Severity | New this run |
|----------|-------|
| Low Risk | 3 (L-26, L-27, L-28) |
| Centralization | 0 |
| QA / Non-Critical | 2 (Q-24, Q-25) |
| **Total new** | **5** |

| Other sections | Count |
|---|---|
| Borderline severities, stated per item | 2: **L-26** (Low vs Medium), **L-28** (Low vs QA) |
| Re-raise of an owner `wont-fix`, disclosed | 1: **L-26** re-raises the root of **L-24** `8511fd5206` (`wont-fix`) |
| `fix-pending` entries re-weighed | 1: **Q-21** `4c2f9c705c`, numbers update only, stays `fix-pending` (§ Q-21) |
| Carried-over open entries (`carryover/`) | 41 (32 QA-channel entries in 10 `qa-report-NN.md`, 9 faithfulness records in 5 `spec-conformance-NN.md`) |
| Shared root, counted once | **L-28** and **F-01-052** (`ycn22f1`, now Informational in `spec-conformance.md`) are one DEDUP-004 root, never two independent issues |

**Final review.** This bundle was corrected after the step-7 final review: [`../final-review-severity.json`](../final-review-severity.json) (severity second opinion) and [`../final-review-validity.json`](../final-review-validity.json) (validity). Every item here was confirmed valid and **no label in this bundle changed**: L-26, L-27, L-28 stay Low, Q-24 stays QA (non-critical), Q-25 stays informational. Prose and citation corrections applied: L-26 (dust `pair.mint` costs ~1,001 wei per side, not ~1 wei; mitigation framed as a pre-broadcast decision; Medium re-weigh triggers recorded), L-27 (story-052 L345 / L208 cited; abort-and-reuse window; cross-ref L-26/L-28), L-28 (tight tolerance sourced to `BalancerWinddownPlan.md` L385, not story-103; cost stated as tolerance-dependent; shared root with F-01-052), Q-24 (retitled to lead with the fork refutation), Q-25 (figures are closed-form, stray-sUSDS variant is counterfactual). The only severity change of the review is F-01-052, Low → Informational, in `spec-conformance.md`.

**Labels** continue the ledger sequence (last `Q-23` → `L-26`…`L-28`, `Q-24`, `Q-25`). The next free labels are **`L-29`, `Q-26`, `C-02`**. Every item's evidence is a fork test in `yield-claim-nft/work/test/run22/` at mainnet block 26,136,000 (chainid 1). No High or Medium finding means no PoC is required. Tier 3 found no counterexample on the real escrow: invariants 12/12 PASS on forge and Medusa with mutant controls, and Halmos 4/4 PASS with generality mutants.

---

## Low Risk Findings

### [L-26] `exitAndSeed` can be permanently bricked for ~1 wei (sync) or ~1e3 wei per side (mint) + gas by poisoning the empty canonical sUSDS/phUSD pair. The escrow seeds only via Router02 behind a strict-empty gate and has no recovery path <!-- id: ycn22l26 -->

> **Triage (2026-10-07): wont-fix.** Owner: "I guess, it should just panic and then I'll have to figure out what to do if there is a pair. I think it's safe to mark as won't fix." The strict empty-pair gate is fail-loud by design and `abort()` fully restores the old pooler. Recovery from a poisoned pair is an attended operator decision, consistent with L-24 (`ycn20l24`, wont-fix 2026-10-01). The safe-recovery guidance below still applies.

**Severity:** Low. **Borderline Low vs Medium** (see *Borderline* below).

**Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L359-L375`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L359-L375) (`_requireEmptyPair`), called from [`exitAndSeed #L249`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L249). The Router02-only seed is at [`_seed #L393-L412`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L393-L412).

```solidity
function _requireEmptyPair() internal {
    (uint112 r0, uint112 r1,) = IUniswapV2Pair(_pair).getReserves();
    ...
    if (r0 == 0 && r1 == 0 && (b0 != 0 || b1 != 0)) {
        ICutoverPairSkim(_pair).skim(_newPooler);          // only unsynced dust is cleared
        ...
    }
    if (r0 != 0 || r1 != 0 || b0 != 0 || b1 != 0) {
        revert UniPoolerCutoverEscrow__PairNotEmpty(r0, r1, b0, b1);
    }
}
...
(uint256 a, uint256 b, uint256 liq) =
    IUniswapV2Router02(_uniRouter).addLiquidity(_sUSDS, _phUSD, s, p, s, p, _newPooler, deadline);   // :400
```

**Description:** The gate skims *unsynced* dust but cannot clear *synced* reserves. A griefer sends 1 wei of sUSDS to the pair and calls `sync()`. After that, `exitAndSeed` reverts `PairNotEmpty(1,0,1,0)` on every call (fork-confirmed on the real canonical pair and Router02). A dust first `pair.mint` has the same effect, but it is not a 1-wei attack: a first mint on an empty pair must satisfy `sqrt(a*b) > MINIMUM_LIQUIDITY` (1,000), so it costs on the order of 1,001 wei per side. Both variants are negligible in cost. The escrow seeds **only** through Router02 behind the strict `reserves == (0,0)` gate and has no mint-path branch. So the brick is permanent for this escrow, and redeploying the same escrow fails the same way.

The window is structural and spans several public broadcast txs: `createPair`, the `UniPoolerV2` deploy, the escrow deploy, `withdrawBPT`, the owner BPT transfer, and `exitAndSeed`. It exists because `UniPoolerV2`'s constructor requires the canonical pair to exist (`PairNotCanonical`) and the escrow reads `newPooler.pair()` at construction.

The brick is limited to this escrow. A direct transfer followed by `pair.mint(newPooler)` still seeds the poisoned pair and absorbs the dust (fork: 1000e18 per side minted 999999999999999999000 LP). So `UniPoolerV2` and the canonical pair stay usable.

**Impact:** No asset loss. `abort()` returns the whole BPT/sUSDS/phUSD/USDS to the old pooler, and the old pooler stays usable because `BalancerPoolerV2` keeps no BPT accounting (fork-proven under a normal pool, a paused pool and a paused vault). The impact is that this escrow's `exitAndSeed` can never succeed. The one-off cutover is delayed until a differently-shaped seeder is written, reviewed and deployed. The griefer gains nothing.

**Disclosure: this re-raises the root of an owner `wont-fix`.** The root, a permissionless dust pre-seed of the empty canonical sUSDS/phUSD pair, is the same as **L-24** (`ycn20l24`, fingerprint `8511fd5206fbe9a686ea64e1a375a39fdf55bfa3582d92fc46710a7e6e362f7f`, status **`wont-fix`**). L-24's `triageReason`, verbatim:

> Owner triage 2026-10-01: wont-fix. Owner: "This is a mild inconvenience at most." Basis: a third-party dust pre-seed only trips the cutover's fail-loud reserves==(0,0) precondition, so the impact is delay on a one-off cutover; the griefer gains nothing and the skew is cheaply and profitably arbitraged back. Safe-recovery guidance retained (footgun): if the pair is pre-seeded, arbitrage it to the target ratio, then seed via direct transfer + pair.mint with a reserve-ratio assertion. Never relax the precondition or router-addLiquidity with zero mins into a skewed pair. Does not cover Q-19 ycn20q19 (pair not bound to router factory), which is triaged separately.

**What is new.** L-24's `wont-fix` rests on recoverability: its own triageReason prescribes the safe recovery "seed via direct transfer + pair.mint with a reserve-ratio assertion". `UniPoolerCutoverEscrow`, a different contract written after that triage, **cannot execute that recovery**. It seeds only via Router02 behind a strict-empty gate, so one synced wei forces `abort()` and an un-reviewed replacement seeder. The owner did not weigh this on 2026-10-01. The severity is the same as L-24's. The locus and the missing recovery are new. A human may legitimately re-apply L-24's `wont-fix`. This record exists so that decision is made knowingly and not through silent suppression. It is **not** a regression of Q-19 (`ycn20q19`, `fixed`): the canonical-pair check at `UniPoolerV2.sol:220-221` is unchanged and intact.

**Borderline (Low vs Medium).** *For Medium:* the DoS is permanent for this escrow, costs the griefer ~1 wei (sync) or ~1e3 wei per side (mint) plus gas, and the escrow cannot run the recovery that L-24's `wont-fix` depended on. *For Low (the classification):* no asset is at risk, because `abort()` fully restores the old pooler (fork-proven). No ongoing protocol function is impaired: the old pooler keeps working, and the pair and `UniPoolerV2` can still be seeded through the mint path (fork-proven). The cost is delay plus a redeploy. The precedents, L-24 and phoenix-phase-2-staging run-39 L-01 (2-wei pair poisoning that blocks the story-103 core), are both Low. Story-052 asks the auditor to evaluate "DoS only; abort returns funds". That is confirmed, but `abort()` is not a recovery, because it cannot complete the cutover. The final review held Low and kept this flag so the human decides knowingly, before the story-103 broadcast, whether to re-apply L-24's `wont-fix`.

**Re-weigh to Medium if either holds:**

- **Hard deadline that exposes value.** The cutover acquires real time pressure where delay itself puts assets at risk, for example funds left in a Balancer pool known to be at risk, or a deadline after which the Proportional/Recovery exit is unavailable and value is lost.
- **No permissible replacement seeder.** A replacement path is shown to be unavailable, for example the story-052 L23 tax/accounting constraint forbids any other seeder contract. The cutover would then be permanently blockable.

**Recommended mitigation (a pre-broadcast decision for phStaging2 story-103/108):** decide this before broadcast so recovery is never improvised under pressure. Either:

1. **Add the mint-path branch now.** When `IUniswapV2Pair(pair).totalSupply() == 0`, seed by `safeTransfer`-ing both sides to the pair and calling `pair.mint(newPooler)` instead of Router02, and replace the strict-empty gate with a dust-tolerant reserve-ratio check plus an LP post-check; or
2. **Pre-write the recovery runbook.** Document the `abort()` + mint-path-seeder runbook, including a reserve-ratio assertion on the replacement seed, before broadcast.

Under either option, **never** seed through Router02 `addLiquidity` with zero or loose mins into a skewed pair. L-24's triageReason forbids exactly that.

**Evidence:** `work/test/run22/EscrowCrossContract.fork.t.sol::test_run22_oneWeiSyncPoison_blocksSeed_abortRestores_mintPathRecovers` PASS; `::test_run22_vaultPaused_withdrawAbortAndRecoveryExitWork` PASS; repo fork suite `test/UniPoolerCutoverEscrow.fork.t.sol` 4/4 PASS.

*Fingerprint `b2a29359fde54466776d650fd0a1097730653f4ed0fc21d380a3b9b00c0742f7` (`UniPoolerCutoverEscrow.sol:exitAndSeed:dos-empty-pair-poisoning`). issueId `ycn22l26`. Sources: LOCAL-001, PATTERN-001, CODE-001, SLITHER-004 (DEDUP-001 / CLASS-22-01). PATTERN-001's mechanical "potential-high" (first-depositor mapping) did not set the label: the gate reverts before any value moves, so no inflation or theft is possible.*

---

### [L-27] The escrow snapshots `_bpt` from the owner-mutable `oldPooler.pool()`. A `BalancerPoolerV2.setPool` between escrow deploy and `withdrawBPT` delivers a token that `exitAndSeed` rejects and `abort()` never returns, so it is stranded for good (owner ordering footgun) <!-- id: ycn22l27 -->

**Severity:** Low (Law-3 footgun).

**Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L199-L217`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L199-L217) (constructor snapshot), [`abort #L296-L299`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L296-L299), [`_returnAll #L415-L418`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L415-L418)

```solidity
address bpt_ = ICutoverOldPooler(oldPooler_).pool();      // :199, read once at deploy
...
_bpt = bpt_;                                               // :217, immutable
...
uint256 b = _returnAll(_bpt);                              // :296, abort() returns only the snapshot tokens
uint256 s = _returnAll(_sUSDS);
uint256 p = _returnAll(_phUSD);
uint256 u = _returnAll(_usds);
```

**Description:** Fork-confirmed against the deployed old pooler, where the owner can call `setPool`. The sequence is: the escrow is deployed, then the owner calls `setPool(X)`, then `withdrawBPT(escrow, n)`. The escrow receives token X, not its snapshot `_bpt`. `exitAndSeed` reverts `NoBPT`, and `abort()` moves only `_bpt/_sUSDS/_phUSD/_usds`, so X stays in the escrow forever. The escrow has no owner, no rescue path and immutable addresses. Story-103 does not call `setPool`, so this is not a live path. It is a non-obvious ordering hazard: a competent owner would not expect the escrow to bind silently to the pre-repoint BPT, or `abort()` to be unable to return the token `withdrawBPT` just delivered.

**Why this is not story-052's accepted no-rescue item.** Story-052 L345 accepts "no general rescue for arbitrary airdropped tokens outside the four handled tokens" as INFO. This case is different: the stranded token is not an airdrop. It arrives through the protocol's own `withdrawBPT`, the very call the runbook uses to fund the escrow, while `abort()` is documented as the universal undo.

**Impact:** Tokens of the new pool X that the owner sends to the escrow via `withdrawBPT` after `setPool(X)` are permanently stranded. The **original BPT is not affected**: it stays on the old pooler, where `rescueERC20` can reach it.

**Likelihood:** low. Story-052 L208 deploys the escrow and calls `withdrawBPT` in the same broadcast, so the first pass leaves no room for a repoint. The realistic window is **re-use of the escrow after an abort** followed by a `setPool` repoint before a second `withdrawBPT`. L-26 and L-28 are exactly what would force such an abort, so they are the main path to this footgun. The step is not in the runbook, and `BalancerPoolerV2` is being retired (story-050).

**Severity rationale:** It could be argued up to Medium (Law 3: "up to High if it enables direct asset loss"), because the stranding is permanent. It is held at Low because it needs two owner calls that story-103 does not contain, there is no external attack path, protocol availability is unaffected, and the main asset stays recoverable.

**Recommended mitigation (safe-config guidance):** In `UniPoolerCutoverCore`, assert `oldPooler.pool() == escrow.bpt()` in the same broadcast, immediately before `withdrawBPT(escrow, bal)`. Never call `setPool` on the old pooler while an escrow is live. Code-side option: have `abort()` also `_returnAll(ICutoverOldPooler(_oldPooler).pool())`, or expose a BPT-match check.

**Evidence:** `work/test/run22/EscrowCrossContract.fork.t.sol::test_run22_setPoolAfterDeploy_strandsNewPoolTokenInEscrow` PASS.

*Fingerprint `2268ead7cba40c097fd2723e45032f2afc947b04736bbc77b87450ba02111bd4` (`UniPoolerCutoverEscrow.sol:constructor:stale-immutable-snapshot-owner-footgun`). issueId `ycn22l27`. Sources: LOCAL-002, PATTERN-MR-002, CODE-002 (DEDUP-002 / CLASS-22-02). Not a match for L-17 `79a2cd4a79…` (`BalancerPoolerV2` config coupling, open), which is a different contract and mechanism. The generic no-rescue stranding (PATTERN-MR-003) stays parked separately. Cross-ref: L-26 (`ycn22l26`) and L-28 (`ycn22l28`), the abort-and-reuse drivers.*

---

### [L-28] Tight off-chain exit floors plus a public-mempool `--slow` broadcast let anyone cheaply revert `exitAndSeed` (cost scales with the chosen tolerance). Story-052's claim that the operator gate prevents the mid-cutover front-run revert is incomplete <!-- id: ycn22l28 -->

**Severity:** Low (footgun). **Borderline Low vs QA** (see *Borderline* below).

**Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L256-L266`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L256-L266) (floors passed to the exit). The design rationale is at [`#L63-L65`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L63-L65).

```solidity
///      The `operator` gate exists only to deny strangers control of timing and slippage floors
///      (sandwiching, front-running the cutover broadcast between `withdrawBPT` and
///      `exitAndSeed`, griefing `abort`). The custody guarantee does not depend on it.
...
        if (minAmountsOut.length != 2) revert UniPoolerCutoverEscrow__BadMinAmountsLength(minAmountsOut.length);
        for (uint256 i = 0; i < 2; i++) {
            if (minAmountsOut[i] == 0) revert UniPoolerCutoverEscrow__ZeroMinAmountOut(i);
        }
        ...
        _exit(mode, bptIn, minAmountsOut);
```

**Description:** Story-052 justifies the immutable-operator gate partly on the grounds that a stranger "front-running between the owner's `withdrawBPT` and `exitAndSeed` … would revert the forge broadcast mid-cutover". Story-103 broadcasts through the public mempool (`forge --broadcast --slow --ledger --legacy`, with no private relay, 103 L99), with floors quoted at simulation time. The runbook, phStaging2 `docs/BalancerWinddownPlan.md` **L385**, sets `minAmountsOut` to "the live proportional share minus a tight tolerance". (Story-103 L189 only asks for a quote helper with a tolerance argument, following `scripts/compute-min-bpt-poolerv2.js`, whose default is 100 bps = 1%. Story-052 L194 is a fork-test spec, not the runbook.) The gate does not stop the cheapest form of that front-run: any Balancer swap that moves one side past the tolerance makes the Vault revert. This is fork-proven at the repo's 1 bp tolerance. A 4 sUSDS → phUSD Balancer swap makes `exitAndSeed` revert with `AmountOutBelowMin(phUSD, 22,453.35e18, 22,454.12e18)`, and the griefer unwinds for a round-trip cost of 0.024 sUSDS (about $0.027) plus gas. **That cost is tolerance-dependent:** about $0.03 at the 1 bp test tolerance; at the story-103 helper-pattern default of 1% the griefer must move the pool roughly 100× further, a round trip of roughly a few hundred dollars notional (fees plus impact), still cheap and still unprofitable. Organic Balancer flow during the multi-tx `--slow` broadcast can trip the same check with no attacker. ECON-001 (see Q-24) proves a loose floor gives up no value, because sandwiching is net-negative. So the tight tolerance buys **no** economic protection and only maximises griefability.

**Impact:** Funds are safe: the tx is atomic, the BPT stays in the escrow, and the operator can re-quote and retry, or `abort()`. The impact is repeated liveness denial of the cutover at a tolerance-dependent cost per attempt (~$0.03 at 1 bp; roughly a few hundred dollars notional at 1%), plus a mid-broadcast revert that leaves the story-103 forge progress file inconsistent.

**Borderline (Low vs QA).** *For QA:* the revert is temporary, and both retry and `abort()` remain available. *For Low (the classification):* the runbook's own "tight tolerance" advice (`BalancerWinddownPlan.md` L385) maximises griefability while buying no protection, and a mid-broadcast revert poisons the progress file. That is a concrete operational hazard with a cheap fix, and a competent operator would expect tighter floors to be strictly safer. It is not Medium: the delay is recoverable, the operator can mitigate it, and no value is at risk.

**Recommended mitigation:** Size the exit tolerance for griefing resistance (e.g. 0.5–1%), not tight. ECON-001 shows sandwiching is net-negative at 1% and 5%. Use a private relay for `exitAndSeed` if one is available. Document that floor reverts are expected and recoverable, and how the progress file resumes after an `exitAndSeed` revert.

**Evidence:** `work/test/run22/EscrowSandwichEcon.fork.t.sol::test_run22_econ_tightFloor_griefCost` PASS (trace: Vault `AmountOutBelowMin(phUSD, 22,453.35e18, 22,454.12e18)`; grief round-trip cost 23961190401828642 wei sUSDS); `::test_run22_econ_sandwich_tol{100,500}bps_{buy,sell}Phusd` PASS.

*Fingerprint `d77a482de757221d9ff311a43a46c11b40aa7df997199914fad7469d7128b209` (`UniPoolerCutoverEscrow.sol:exitAndSeed:griefing-dos-tight-floors`). issueId `ycn22l28`. Sources: ECON-002, F-01-052 (DEDUP-004 / CLASS-22-03). The story-rationale half is filed separately as **F-01-052** (`ycn22f1`, Informational after final review) in `spec-conformance.md`. They share one root and are **not** counted as two independent issues in any tally. Related: Q-24 covers the same floors and the opposite failure mode.*

---

## QA / Non-Critical Findings

### [Q-24] Sandwich value-leak hypothesis on the escrow's exit and seed refuted on fork (attacker net-negative). Residual defence-in-depth note: by documented design (story-052 L223) price protection is off-chain, `minAmountsOut` is checked only for length 2 and non-zero, and the V2 seed inherits the Balancer spot ratio with no band <!-- id: ycn22q24 -->

**Severity:** QA (informational / defence in depth).

**Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L256-L270`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L256-L270)

```solidity
        if (minAmountsOut.length != 2) revert UniPoolerCutoverEscrow__BadMinAmountsLength(minAmountsOut.length);
        for (uint256 i = 0; i < 2; i++) {
            if (minAmountsOut[i] == 0) revert UniPoolerCutoverEscrow__ZeroMinAmountOut(i);   // 1 wei passes; order unchecked
        }
        ...
        // 5. Seed with the whole balances.
        uint256 s = IERC20(_sUSDS).balanceOf(address(this));
        uint256 p = IERC20(_phUSD).balanceOf(address(this));
        liquidity = _seed(s, p, deadline);                     // ratio = Balancer composition at exit
```

**Description:** Off-chain price protection is the documented design, not a defect: story-052 L223 makes `minAmountsOut` the exit's slippage guard. On-chain validation of `minAmountsOut` is minimal. A floor of 1 wei passes, and the token order is never checked against the pool's `[sUSDS, phUSD]`. The V2 seed ratio is whatever composition the Balancer pool has at exit, and story-103's floors are quoted from live state. So a pre-skewed Balancer pool would be baked into both the floors and the V2 seed price. Checked on-chain: the pool is a hookless 50/50 weighted pool (constant-product, like V2) with a 0.3% fee. For two constant-product venues, an LP position's value at a given price depends only on its invariant. Back-arbitraging both venues returns the attacker roughly their own slippage minus 0.3% fees on each leg, and protocol-owned liquidity is not extracted. Because the pool has no hooks, no V3 hook can adjust amounts or call back. The residual risk is a wrong-order or loose floor (PATTERN-002), which the escrow cannot detect.

**Impact:** None demonstrated. On fork, a sandwich that skews the Balancer pool inside the floors loses money for the attacker (−1.753 sUSDS at 1% tolerance, −8.808 sUSDS at 5%), and the protocol's seeded invariant rises slightly (+0.96 / +4.82 sUSDS at p0). This assumes the pool stays a hookless 50/50 weighted pool. A different curve or hooked pool would reopen the question.

**Recommended mitigation:** In `UniPoolerCutoverCore`, assert that `getPoolTokenInfo` order is `[sUSDS, phUSD]` when building `minAmountsOut`. Optionally add an on-chain ratio band on the seed.

**Evidence:** `work/test/run22/EscrowSandwichEcon.fork.t.sol::test_run22_econ_sandwich_tol100bps_buyPhusd` / `_sellPhusd` / `tol500bps_buyPhusd` / `_sellPhusd` PASS.

*Fingerprint `88bfa94936213380dceec14420e7b0131b707e29a6d949878e162a3981c45936` (`UniPoolerCutoverEscrow.sol:exitAndSeed:offchain-only-slippage-floor`). issueId `ycn22q24`. Sources: LOCAL-003, PATTERN-002, PATTERN-003, CODE-003, ECON-001, PATTERN-MR-001 (DEDUP-003 / CLASS-22-04). Related `wont-fix` entries: L-22 `a846cc40e6…` (tolerance is an accepted MEV budget) and L-06 `342075dfba…`. L-06's own triageReason says "If BalancerPoolerV2 is NOT retired, or is re-used by new code, this disposition should be revisited". It was revisited here and the conclusion is QA, so this is **not** suppressed under L-06. PATTERN-002/003's mechanical "potential-high" did not set the label.*

---

### [Q-25] After the cutover, the third party's 37.1% Balancer remainder stays a live second venue at the same price, so part of the Stage-4 peg lift is arbitraged into it ($8–$11 at current depth; V2 settles at ~$0.9735, not $1) <!-- id: ycn22q25 -->

**Severity:** QA (informational, opportunity cost).

**Location:** [`src/migration/UniPoolerCutoverEscrow.sol#L268-L270`](https://github.com/Behodler/yield-claim-nft/blob/0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630/src/migration/UniPoolerCutoverEscrow.sol#L268-L270)

```solidity
        uint256 s = IERC20(_sUSDS).balanceOf(address(this));
        uint256 p = IERC20(_phUSD).balanceOf(address(this));
        liquidity = _seed(s, p, deadline);
```

**Description:** The escrow migrates only the protocol's 62.9% share. The external EOA's 37.1% (11,007 sUSDS / 13,249 phUSD) stays on Balancer at the same price and remains swappable until Balancer swaps stop or that LP exits. Any later price lift on the V2 pair is partly arbitraged into the remainder. The figures below come from a **closed-form** constant-product model (ECON-004, confidence medium) on fork-state inputs. They were **not** fork-executed. Constant-product model, 0.3% fees on both venues:

- **Zap Δ\* = 1,540 sUSDS** (V2 to $1.000): the arbitrage moves 259.5 sUSDS through and nets 9.68 sUSDS (~$11). V2 settles at **$0.9735**, Balancer at $0.9678.
- **Stray-sUSDS variant (counterfactual, off the story-103 path):** if the old pooler's idle 1,308.1 sUSDS had been routed through the escrow before `exitAndSeed`, instead of `rescueERC20` → `UniPoolerV2` as story-103 step 9 specifies, the seed price becomes $0.9885 and the arbitrage nets 6.84 sUSDS (~$8).

The profile's claim that donor strays sent to the escrow are seeded as 100% POL at the donor's cost is confirmed.

**Impact:** Opportunity cost only, about $11 on the story-103 path (the ~$8 figure is the counterfactual variant), and nobody is harmed. Per the project rule, over-payment or misallocation of externally-derived yield is opportunity cost, not a value leak. This is distinct from **Q-21** (plan §5 zap sizing against seeded depth), which is a separate subject.

**Recommended mitigation:** Note in story-103 / plan §5 that the 37.1% Balancer remainder absorbs part of the peg lift until swaps stop or the LP exits, and resize the Stage-4 zap chunks for the combined depth.

**Evidence:** ECON-004 closed-form constant-product model on fork-state inputs (block 26,136,000), confidence medium.

*Fingerprint `b4c10f0f8938ec8a7bae9d6204cdc34844c8faf756807d56567dfa7aa0e1b5c9` (`UniPoolerCutoverEscrow.sol:exitAndSeed:cross-venue-arb-remainder`). issueId `ycn22q25`. Source: ECON-004 (DEDUP-007 / CLASS-22-05). Bundled into the Q sequence per the Q-21 precedent for informational items.*

---

## Q-21 (`fix-pending`): numbers update, reference only

**Q-21** (`ycn20q21`, fingerprint `4c2f9c705c39776aba9242b9c1871f1e165a8f55faeeaefb93abe594e58b41e6`, `fix-pending`) is **not** re-filed or restated here. The full entry is carried in [`carryover/qa-report-20.md`](./carryover/qa-report-20.md). `UniPoolerV2.sol` is unchanged in `267660b..0fd6bdf`. This run's re-weigh (ECON-003 + F-03-052, DEDUP-006; recorded in `reconciliation-log.json → fix-pending[0]`) only updates the numbers:

- The seed price inherited from Balancer is **~0.924 USDS/phUSD at block 26,136,000**. Plan §5 assumed 0.971 at block 26,093,540. Seeded share: 18,656.33 sUSDS / 22,456.37 phUSD (on-chain `Vault.getPoolTokenInfo` balancesRaw `[29663475643465047886662, 35705515073095210602274]`, sUSDS rate 1.1119186).
- phUSD now crosses $1 at a zap of **~$1,711.7**, not the ~$638 of the story-108 plan re-baseline or Q-21's original ~$636. That is about **2.7×**.
- **Status stays `fix-pending`; do not propose `fixed`.** Story-108's plan-§5 re-baseline (the fix intended for Q-21) landed and is itself already stale by 2.7×, so treat this as a plan-side incomplete fix. The plan figure moves with the market, so any fix should state its block and require a live re-quote before Stage 2 rather than a fixed number. The unenforced human seed-price confirmation is filed separately as F-03-052 (`ycn22f3`) in `spec-conformance.md`, and the human may fold it into Q-21.

---

## Carryover

Open earlier entries are **referenced, not duplicated**. finding-manager copied each originating run's QA and spec-conformance report into `carryover/`, pruned to its live (`open` / `qa-bundled` / `fix-pending`) entries, with disposed entries named in each file's header. The labels and `<!-- id -->` stamps are the originating run's. This run's L/Q sequence does not renumber around them. **41 entries.** No source under any carried entry changed in `267660b..0fd6bdf` (the only in-scope change is the new escrow file), so every carried entry is still live as last reported.

| File | Entries carried (ledger labels) | Removed since run 21 |
|---|---|---|
| [`carryover/qa-report-08.md`](./carryover/qa-report-08.md) | L-01, L-02, Q-02, Q-03, Q-04, Q-09, **C-01** | none |
| [`carryover/qa-report-10.md`](./carryover/qa-report-10.md) | L-04, L-05, L-07, Q-05 | none |
| [`carryover/qa-report-13.md`](./carryover/qa-report-13.md) | L-09, L-10, Q-10 | none |
| [`carryover/qa-report-14.md`](./carryover/qa-report-14.md) | L-11 | none |
| [`carryover/qa-report-15.md`](./carryover/qa-report-15.md) | L-12, Q-11 | none |
| [`carryover/qa-report-17.md`](./carryover/qa-report-17.md) | Q-13, Q-14, Q-15 | none |
| [`carryover/qa-report-18.md`](./carryover/qa-report-18.md) | Q-16, Q-17 | none |
| [`carryover/qa-report-19.md`](./carryover/qa-report-19.md) | M-06 (Low), L-16, L-17, L-18, L-19, L-20, Q-18 | none |
| [`carryover/qa-report-20.md`](./carryover/qa-report-20.md) | **Q-21** (`fix-pending`; numbers update above) | L-21, L-25, Q-19 (`fixed` @ `267660b`, human-applied 2026-10-02) |
| [`carryover/qa-report-21.md`](./carryover/qa-report-21.md) | Q-22, Q-23 | none |
| [`carryover/spec-conformance-15.md`](./carryover/spec-conformance-15.md) | F-01-043 | none |
| [`carryover/spec-conformance-18.md`](./carryover/spec-conformance-18.md) | F-01-045 | none |
| [`carryover/spec-conformance-19.md`](./carryover/spec-conformance-19.md) | F-01-047, F-02-046, F-03-046 | none |
| [`carryover/spec-conformance-20.md`](./carryover/spec-conformance-20.md) | F-02-048 | F-01-048 (`fixed` @ `267660b`, 2026-10-02) |
| [`carryover/spec-conformance-21.md`](./carryover/spec-conformance-21.md) | F-01-051, F-02-051, F-03-051 | none |

The only open **Centralization** item is still **C-01** (`d1c5aa860f`, run 08), which is carried. No new centralization item was raised: the escrow has no owner, and its immutable `operator` gate is a knowing deploy-time choice (Law 3). The non-obvious owner-ordering edge is filed as the footgun L-27.

---

## Parked, not dropped

These run-22 items are in `manual-review.json` and await a human decision. None of them was quality-filtered out.

- **PATTERN-MR-003** (`UniPoolerCutoverEscrow`, contract-wide): no rescue for non-protected tokens, and losing the immutable operator's key strands the escrow. Story-052 accepts this as INFO (Law-3 design). It is the generic stranding mechanism behind L-27, with a different mitigation.
- **PATTERN-MR-004** (`wrapUsds :287`, hint "potential-high", low confidence): the ERC-4626 deposit has no min-shares. Pattern-matcher and econ-scanner cleared it (sUSDS is priced off the `chi` accumulator, and the old pooler's USDS is 4.7e11 wei). Kept visible for that reason.
- **PATTERN-MR-005** (`_requireEmptyPair :366`): `skim(_newPooler)` leaves skimmed phUSD on `UniPoolerV2`, reachable only through the owner's `rescueERC20` (story-052 accepts this). `PairSkimmed` emits pre-skim balances, which is correct only because reserves are 0.
- PATTERN-MR-001/-002 (escrow) are kept verbatim as supporting context for Q-24/L-27. Three run-21 `UniPoolerV2` pattern items are carried unchanged.

---

## Appendix A: Automated QA/Gas Report (4naly3er)

Full output: **[`4naly3er-report.md`](./4naly3er-report.md)** (6,833 lines, raw and unedited).

- **Analysed: 37/37 in-scope files.** The scope list passed as arg 3 is `run-context.json → scope`. It was checked equal to a live `find src/src -name '*.sol'` (37 = 37, `diff` empty), and all 37 appear in the tool's scope echo with 0 import-resolution failures. 36 files carry hits, keyed by exact `File: <path>`. The 37th, `src/interfaces/IBurnable.sol`, is a one-function interface with nothing to flag, as in run 21. **`src/migration/UniPoolerCutoverEscrow.sol` is covered** (25 references).
- **Invocation:** basePath at the submodule root `yield-claim-nft/src/` was tried first, following the memory note. It failed with `pauser/interfaces/IPausable.sol import not found` → `TypeError: Cannot read properties of undefined (reading 'contents')`, because the submodule declares its remappings only in `foundry.toml` and is read-only. It was re-run with basePath = `yield-claim-nft/work/`, whose `src/` was verified **byte-identical** to `0fd6bdf` (`diff -rq src/src work/src` empty) and which carries an equivalent `remappings.txt`. Exit 0. Source was not modified.
- **Totals:** Medium 1 issue / 82 instances, Low 15 / 101, NC 34 / 644, Gas 20 / 733.
  - **M-1 "Centralization Risk for trusted owners" (82)** is suppressed as a class under Law 3. The only open centralization item is C-01.
  - **Low hits on the new escrow (2):** L-9 "Signature use at deadlines should be allowed" at `:260` concerns the operator's own exit deadline, not a signature, and rejecting `deadline == block.timestamp` has no value consequence (matches SLITHER-002). L-2 "zero value transfers" points to `:426`, past the end of the 425-line file, so it is a tool mis-attribution, and `_returnAll :417` already skips zero amounts. Neither is a finding.
  - The remaining Low categories overlap items already ledgered or dispositioned: missing `address(0)` checks (Q-09), single-step Ownable (Q-04), zero-value transfers and `decimals()` (out of scope as non-standard-token issues), and "Prevent accidentally burning tokens" / `PUSH0` (informational). None is promoted without a demonstrated root cause.

## Appendix B: Static tool-noise bucket (summary only, not findings)

`deduplicated-findings.json → removed` lists 11 escrow SAST hits that were reviewed and removed as tool noise. None is a finding:

| Class | Items | Disposition |
|---|---|---|
| Modifier order / constructor external calls | ADERYN-001, -002, -004, -005 | `onlyOperator` makes no external call, and the constructor calls are view getters on deploy-time inputs. Style only. |
| `require` in loop | ADERYN-003 (`:257`) | A fixed 2-iteration loop that rejects zero floors, as story-052 requires. Floor strength is Q-24/L-28. |
| `incorrect-equality` | SLITHER-001 (`:253`), -003 (`:285`), -006 (`:394`, `:406`) | Zero guards and fail-loud post-conditions on an atomic seed. A donation can only make a balance non-zero. |
| `timestamp` | SLITHER-002 (`:260`) | The deadline window `(now, now + 1 day]`. Validator drift of a few seconds has no value consequence. |
| `unused-return` | SLITHER-005 (`:382/:384`), -007 (`:408`) | The V3 router enforces the floors, BPT == 0 is post-checked, and `_seed` sizes from `balanceOf`. `blockTimestampLast` is not needed. |

SLITHER-004 was **not** noise: it was consumed into L-26 (DEDUP-001).
