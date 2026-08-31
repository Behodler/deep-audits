<!--
Script-audit review (script-review mode)
Project: phoenix-phase-2-staging
Run: phoenix-phase-2-staging-18
Entry point: migrate:saga2.3-rewire
Forge target: script/MigrateSaga2Rewire.s.sol:MigrateSaga2Rewire
HEAD: 3d5247488800ba3b1e9f158e71ec7f1be7e8258d
Fork-verified: mainnet @ block 25322425 (2.1 -> 2.2 -> 2.3 replay)
Findings: 0 High / 0 Medium / 3 Low (L-01, L-02, L-03)
-->

# Script Audit — `migrate:saga2.3-rewire`

**Project:** phoenix-phase-2-staging  ·  **Run:** phoenix-phase-2-staging-18
**Entry point:** `migrate:saga2.3-rewire`  →  `script/MigrateSaga2Rewire.s.sol:MigrateSaga2Rewire`
**HEAD:** `3d52474`  ·  **Verification:** mainnet fork @ block `25322425`, full `2.1 → 2.2 → 2.3` replay
**Result:** 0 High · 0 Medium · 3 Low (verification-completeness + cluster-hygiene)

---

## Scope and method

`migrate:saga2.3-rewire` is the **final** step (2.3 of 2.1→2.2→2.3) of the "MIGRATE SAGA 2 — InPlaceMigrator route". Its single job is to repoint the live `StableYieldAccumulator` (SYA, `0x3C69…8270`) off the OLD DOLA/USDC yield strategies (`0x90ce…` DOLA, `0x90af…` USDC) and onto the new V2 strategies (`ysDolaV2` / `ysUsdcV2`, both `ERC4626YieldStrategy`), then retire the OLD strategies and run a final `_verify()` gate set. It is declared "no address change": a pure on-chain registry repoint with an **empty JS chain** — `mainnet-addresses.ts` is never touched.

The script cannot be exercised raw against a live mainnet fork at the audit block: the staker still points at the OLD strategies, so 2.3's own preflight reverts `"DOLA not rewired - run 2.2"`, and the `saga2-deployments.json` that supplies the V2 addresses is absent until 2.1 broadcasts. Verification therefore **replays the full chain** `2.1 (deploy) → 2.2 (migrate) → 2.3 (rewire+verify)` under owner prank on one fork (block `25322425`, harness `test/AuditSaga2_3Rewire.t.sol`) and then exercises 2.3's exact body.

Saga 2.1 and 2.2 were audited as predecessors and are referenced here only as cluster context. 2.3 **assumes 2.2 completed**; 2.2's two wont-fix Mediums (M-01/M-02 — operator owns the `totalWithdrawal` window timing and allotment sizing) remain upstream operator responsibilities and are not re-litigated here. L-01 below is partly a downstream consequence of that boundary.

---

## Question 1 — Does it do what it intends?

**Yes. Fork-verified faithful.** Replaying the chain and running 2.3's exact body produced a clean, intended end-state with no reverts:

- **Repoint executes correctly.** `addYieldStrategy(ysDolaV2, DOLA)` and `addYieldStrategy(ysUsdcV2, USDC)` register the two V2 strategies; `removeYieldStrategy(OLD_DOLA_YS)` and `removeYieldStrategy(OLD_USDC_YS)` retire the OLD ones — exactly four intended registry mutations, each guarded on `isRegisteredStrategy` so a re-run is a clean no-op.
- **No selector drift.** The historical YS-31 / Q-SYA-SEL `0x3bBE` vs `0x3C69` mismatch lived on the now-**dead** pre-story-058 SYA `0x3bBE…7606a`. 2.3 correctly hardcodes the **live replacement** SYA `0x3C69…8270` (== `mainnet-addresses.ts`, `owner()` matches, holds the old-strategy registry). A PUSH4 selector scan against the deployed bytecode confirms all four called selectors — `addYieldStrategy 0x454ee0ca`, `removeYieldStrategy 0x3a8107cf`, `isRegisteredStrategy 0xcf82f169`, `owner() 0x8da5cb5b` — are present. `removeYieldStrategy` takes the **strategy** address (not the token), which the script honours.
- **Registry stays consistent.** The swap-and-pop deregistration preserves the USDe market strategy (`0xaC2e…`) at index 1 throughout. Before: `[OLD_DOLA(0), USDE(1), OLD_USDC(2)]`; after: `[ysDolaV2(0), USDE(1), ysUsdcV2(2)]`, length 3. Every member reads `isRegisteredStrategy==true` with a non-zero token; both removed strategies read `false` with a cleared token. No duplicate, no dangling pointer, no USDe collateral damage.
- **No stranded value at retirement.** 2.2 fully drains both OLD strategies (staker via `migrateOut`, minter via `totalWithdrawal`, accumulator surplus via `skimSurplus`) **before** 2.3 retires them. At the moment of `removeYieldStrategy`, both authorized clients (MINTER_V1, STAKER) read `totalBalanceOf==0` and `principalOf==0` on both OLD strategies. `removeYieldStrategy` only mutates SYA bookkeeping and never touches strategy funds, so even hypothetical residual stays owner-recoverable.
- **Idempotent.** Running 2.3 twice on the same post-2.2 state is a clean no-op — all four guards short-circuit, array length stays 3, `_verify()` passes both times. No half-rewired stuck state on the happy path.
- **All gates pass.** The 3 preflight `require`s (`ACCUMULATOR.owner()==OWNER`, staker rewired to ysDolaV2/ysUsdcV2) and all 8 `_verify()` post-conditions pass on the replayed fork, including staker principal `>0` on V2 (`~1060.7 DOLA`, `~1981.5 USDC`), `!withdrawDisabled`, `setAsideBufferSize==10`, and MINTER_V1 drained to zero on both OLD strategies.

---

## Question 2 — Does it introduce unintended side effects?

**No.** Fork diffing observed **exactly four intended state mutations and four events**, and nothing else:

```
YieldStrategyAdded(ysDolaV2)      — register V2 DOLA strategy
YieldStrategyAdded(ysUsdcV2)      — register V2 USDC strategy
YieldStrategyRemoved(OLD_DOLA_YS) — retire OLD DOLA strategy
YieldStrategyRemoved(OLD_USDC_YS) — retire OLD USDC strategy
```

- **Zero unintended writes.** No state write, event, or external mutation beyond the four registry mutations and their events.
- **No ownership change, no token transfer, no approval, no pause-state flip.**
- **USDe registration preserved untouched** at array index 1.
- **`mainnet-addresses.ts` untouched** — the JS chain is empty (`jsChain.pre == [] && jsChain.post == []`), confirming the "no address change" intent. 2.3 is a pure on-chain registry repoint, the same JS-less pattern as 2.2.

---

## Question 3 — Have other problems surfaced because of it?

No High or Medium. Three Low findings surfaced — all are **verification-completeness** or **cluster-hygiene** gaps adjacent to 2.3, not defects in 2.3's own state writes. 2.3 itself is faithful and safe; we credit that clean result plainly and do not manufacture severity.

### Closure / mutation map

```
                      migrate:saga2.3-rewire  (MigrateSaga2Rewire.s.sol)
                                   │  empty JS chain · no address change
   reads  saga2-deployments.json (.ysDolaV2 / .ysUsdcV2 / .minterV2)  ← written by 2.1
                                   │
            preflight: owner OK · staker rewired to V2 (proves 2.2 ran)
                                   │
                                   ▼
        ┌──────────  StableYieldAccumulator  0x3C69…8270  (live SYA)  ──────────┐
        │   + addYieldStrategy(ysDolaV2, DOLA)        + addYieldStrategy(ysUsdcV2, USDC)   │
        │   - removeYieldStrategy(OLD_DOLA 0x90ce)    - removeYieldStrategy(OLD_USDC 0x90af)│
        │   USDE market YS 0xaC2e…  →  PRESERVED (index 1)                                  │
        └──────────────────────────────────────────────────────────────────────┘
                                   │
                       _verify()  ▸ 8 gates pass  (◑ incomplete — see L-01 / L-02)
                                   │
   cluster context:  2.1 deploy ─▶ 2.2 migrate ─▶ [2.3]      DeregisterOldStrategiesFromSYA
   (predecessors, audited)                                    (superseded sibling — L-03,
                                                               hardcodes DEAD SYA 0x3bBE)
```

### L-01 — Low · final verification omits the cushion-1 (skimmed-surplus) buffer half

`IncompleteVerificationGate` — `MigrateSaga2Rewire.s.sol:_verify` (lines 99–101).
Record: `findings-classified.json` → `CLASS-S23-01`. Source: [`MigrateSaga2Rewire.s.sol#L99-L101`](https://github.com/Behodler/phoenix-phase-2-staging/blob/3d5247488800ba3b1e9f158e71ec7f1be7e8258d/script/MigrateSaga2Rewire.s.sol#L99-L101).

Per the owner's clarification, the strategy-side "set-aside" and the staker-side "buffer" are **one protocol-wide concept** realized via two cushions: (1) the skimmed DOLA/USDC surplus that 2.2 step 8 transfers to the staker as idle balance, and (2) the strategy-level 10% withholding for the staker on the new strategies. 2.3's `_verify()` asserts **only cushion-2** (`setAsideBufferSize==10`); it never asserts that cushion-1 landed, nor that `setAsideBufferRecipient == STAKER` on the new strategies.

The consequence is a **non-obvious operator footgun**: if 2.2 completes steps 1–7 but is interrupted at step 8 (the buffer transfer), an operator runs 2.3, all 8 gates pass green, and the migration is declared complete while the protocol-wide buffer is short by the entire skimmed surplus — with no gate having flagged it. This is partly a downstream consequence of the 2.2 boundary: 2.2's window/timing is operator-owned (its wont-fix Mediums), and 2.3's gate does not independently catch a 2.2 buffer-transfer miss. No assets are at direct risk — cushion-2 is independently in place and asserted, and the cushion-1 surplus is fungible idle balance the non-malicious owner can re-transfer manually — hence Low. The defect is that the **declared final step over-trusts a green result** because it only covers one half of a concept it presents as fully verified.

### L-02 — Low · verify drops two plan-mandated end-state gates (faithfulness F-S23-02)

`MissingPostStepConfiguration` — `MigrateSaga2Rewire.s.sol:_verify` (lines 103–114). **Faithfulness-routed (F-S23-02).**
Record: `findings-classified.json` → `CLASS-S23-02`. Source: [`MigrateSaga2Rewire.s.sol#L103-L114`](https://github.com/Behodler/phoenix-phase-2-staging/blob/3d5247488800ba3b1e9f158e71ec7f1be7e8258d/script/MigrateSaga2Rewire.s.sol#L103-L114).

Plan-doc §5 Script 3 step 4 / §5.4 enumerates a set of final gates and directs the step to "assert all" of them. 2.3's `_verify()` implements an **incomplete superset** of that list. Specifically it does not re-assert `phUSD.setMinter(minterV1)==false` / `setMinter(minterV2)==true` (the V1-off / V2-on phUSD minter-authority flip), nor the USDe-client wiring, and it **demotes the minterV2-seeded principal check to log-only** (`console.log` rather than a gate). This is a Law-2 faithfulness drift — the step whose stated job is "assert all" omits plan-mandated gates — so it is surfaced in the spec-conformance channel rather than buried in QA.

Severity stays Low: there is no standalone exploit and no asset/availability impact. Any underlying mis-set (V1 still a minter, or V2 not) would itself require a 2.1 failure at its `setMinter` step or a separate owner re-flip, both of which 2.1's own asserts independently cover; 2.3 merely fails to **re-check**. The minterV2-principal log-only relaxation is a documented, defensible choice (the plan notes the position "may be 0 if minter had no position") and is not itself the defect — the unchecked phUSD/USDe gates are. **Lineage:** this is adjacent to saga 2.1's L-02 (deploy script lacks post-write asserts, wont-fix). It is distinct (2.3 L-02 is "the declared FINAL verification step omits its own plan §5.4 gates"), so it is noted here for triage to fold into the 2.1 L-02 posture or action separately — **not re-reported** as a new copy.

### L-03 — Low · superseded sibling hardcodes the DEAD SYA and reads an empty inputs file

`StaleAddressConstant` — `DeregisterOldStrategiesFromSYA.s.sol:run` (lines 50–52).
Record: `findings-classified.json` → `CLASS-S23-03`. Source: [`DeregisterOldStrategiesFromSYA.s.sol#L50-L52`](https://github.com/Behodler/phoenix-phase-2-staging/blob/3d5247488800ba3b1e9f158e71ec7f1be7e8258d/script/DeregisterOldStrategiesFromSYA.s.sol#L50-L52).

A **superseded** ys-swap-lineage sibling (story 065) sits on the **same** SYA-deregister surface that 2.3 owns — it calls the identical `removeYieldStrategy(strategy)` on the same OLD strategies — but it still hardcodes `LIVE_SYA = 0x3bBE…7606a`, the **dead** pre-story-058 SYA, and reads `ys-swap-deployments.json`, which is **empty on disk**. If an operator confuses routes and runs it instead of (or alongside) 2.3, the empty-JSON read reverts in practice, or — since `0x3bBE` may still carry code and a matching owner — the `owner()` / code-length preflight is **not a guaranteed loud failure** and the script silently no-ops against the dead instance, leaving the operator believing the OLD strategies were deregistered when they were not.

This is surfaced under the **same-surface exception** (it is reachable from the saga-2 retirement surface 2.3 owns), not as unrelated scope. It is a non-obvious cross-route operator footgun (Law 3) at Low: no value is moved, lost, or stolen, and **2.3 itself is clean and authoritative** for saga-2 old-strategy deregistration (it targets the correct live `0x3C69`). **Lineage:** prior YS-31 / Q-SYA-SEL. Remediation is to quarantine or repoint the superseded sibling — no change to 2.3.

---

## Recommendations

1. **Complete the buffer gate (L-01).** Add assertions to `_verify()` covering cushion-1 and the recipient binding: `setAsideBufferRecipient == STAKER` on both new strategies, plus an assertion that the skimmed-surplus cushion landed (the staker's idle DOLA/USDC balance reflects the 2.2 step-8 transfer). This makes a green 2.3 verify mean the protocol-wide buffer is whole end-to-end, and lets 2.3 independently catch an interrupted-2.2 buffer-transfer miss.
2. **Complete the plan §5.4 gate set (L-02).** Re-assert `phUSD.minters(V1)==false` / `phUSD.minters(V2)==true` and the USDe client wiring in `_verify()`, and promote the `minterV2`-seeded principal check from `console.log` to an assertion (or document the log-only relaxation explicitly in-script so the deviation from "assert all" is intentional and visible).
3. **Quarantine or fix the superseded sibling (L-03).** Either delete `DeregisterOldStrategiesFromSYA.s.sol` or repoint its hardcoded `LIVE_SYA` from the dead `0x3bBE…` to the live `0x3C69…` and remove the empty-JSON dependency, so a wrong-route operator cannot silently no-op a believed deregistration.

---

## Verdict

`migrate:saga2.3-rewire` **does what it intends** (fork-verified faithful repoint + retire), **introduces no unintended side effects** (exactly four intended registry mutations, empty JS chain, USDe preserved, no ownership/transfer/approval/pause changes), and surfaces **no High or Medium issues**. The three Low findings are verification-completeness (L-01, L-02) and cluster-hygiene (L-03) gaps that harden the migration's final-gate signal and clean up a stale sibling — they do not call the safety of 2.3 itself into question.
