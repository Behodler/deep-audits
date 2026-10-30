# Decision log: reflax-yield-vault-18 final review

**Date:** 2026-10-28 · **Run:** `reflax-yield-vault-18` · **HEAD:** `4788ed41747b923165745af748a078bfb534ba20` (`master`)
**Inputs:** `severity-audit.json`, `validity-review.json`, `poc/L-30-validate.txt`, `poc/L-30-forge.txt`
**Ledger backup before these corrections:** `reports/18/ledger-backup-pre-corrections.json`

**No ledger `status` was changed.** All six run-18 entries are still `open`. Every status change below is a proposal for a human `/ledger` command.

## 1. L-30 promoted to M-05 (orchestrator decision, borderline)

- **Fingerprint:** `d5a0f7dc1f9df28b04c28b7179e230bc9cb42ac02d013a760db384251769ad9c` (unchanged)
- **Issue ID:** `ryv18l30` became `ryv18m5`. This is a relabel within the same run, made before publication. `ryv18l30` and `L-30` are kept in `aliases`. The label L-30 is retired and will not be reused.
- **Severity-auditor position: Medium (flagged for the human).** A fork probe showed that a gapped USDe→sUSDe route on the live adapter `0x2D02…D6f` *silently and permanently* strands deposits as crvUSD. It does this at the live B = 30, because `minOut` is denominated in sUSDe shares (794.28) and about 1001 crvUSD clears it. The strategy has no rescue path, found by full selector enumeration. Impact is High and likelihood is Low (an owner config action), which gives Medium. This is the same class as sya-harvester M-01.
- **PoC-validator / validity position: Low.** It agreed on every fact: the 5/5 PoC passes, with 1001.0035 crvUSD per 1000 USDe, V2 under-backed by 490.86, co-clients diluted by 506.14, and a strategy deficit of 994.74. It rated the finding Low because the precondition is a future owner `setRoute` on the pre-052 adapter. `src/CLAUDE.md:258` already warns about that adapter, which weakens the Law-3 surprise.
- **Decision: Medium.** Grounds: Law 1 (recall beats tidiness), and consistency with sya-harvester M-01, which is the same class and rated Medium. **The human may downgrade it.**
- 2026-10-28 owner triage: severity confirmed Medium (borderline resolved); interim control phStaging2 0285372.
- **Corrections applied:** The deposit side strands silently: the strategy trusts the router's return value, records it as `sharesReceived`, and emits a `Deposited` event that looks normal. The withdraw side reverts only because the strategy holds 0 idle USDe ("ERC20: transfer amount exceeds balance"). Current exposure is "None at present": there are 2 `RouteSet` logs and both routes are contiguous. Recommendations (a) to (d) are recorded: redeploy the adapter and strategy, or migrate; dry-run every payload against the HEAD validator on a fork and put that step in the phStaging2 runbook; measure balance deltas (links L-12 `6e771a84e82d`); enumerate `AMMRoutes.json` keys with `vm.parseJsonKeys` (absorbs F-06).
- PoC: `work/test/poc-run18-L30-LiveAdapterGappedRouteStrand.t.sol`, patch `reports/18/poc/L-30.patch`, status `poc-validated`.
- The record moved from `findings/low/L-30-*.json` to `findings/medium/M-05-live-adapter-gapped-route-strands-deposits.json`. **`submissions/M-05.md` has not been written yet.** The ledger `reportPath` points to that intended path.

## 2. L-31: stays Low, reframed

The restored quote now includes the words "through an AMM-backed strategy" (`StableStakerV2.sol:496-499`). The finding is reframed: story-028 assumes a rounding-scale top-up for direct strategies, and the proven 1.38 bps autoUSD discount breaks that assumption. The unverified manipulation step moved out of `attackPath` and into `escalationTrigger`.

## 3. L-32: stays Low, still a draft

The precondition is corrected. Below par requires an sUSDe NAV decline, a prior `emergencyWithdraw`, or an M-05 strand. It cannot come from an AMM discount. Reachability at the live bytecode is high-confidence, based on source lineage unchanged at `5cf462e`, `2306719`, `2f6774d` and HEAD.

## 4. QA-13: kept at QA

QA-13 is not dropped (Law 1: no silent drop). `validityConcern` is set to "leaning drop — transient retriable revert; meaningful content (pressure to raise B) cross-referenced into L-01 annotation". A Morpho Blue flash-loan note was added: the "not flash-loanable" claim is unverified and probably false, and the verdict is unchanged.

## 5. F-06: proposed false-positive (not applied)

The validity review found F-06 INVALID. `AMMRoutes.json` has exactly 2 routes and both are tested, and `src/CLAUDE.md` says "add a case there". The status stays `open`, with `proposedStatus: "false-positive"` and a `proposalRun18` reason recorded. The hardening point is absorbed into M-05 (d). Command for the human: `/ledger reflax-yield-vault false-positive 7ef86352a3dd`.

## 6. L-01 (`6460e35331df`) annotation

The `MAX_BPS` sub-claim is an obvious misconfiguration (Law 3, trusted). The valid footgun: raising B to cure reverting exits silently raises StableStakerV2's phUSD-mint ceiling. The Medium trigger is B above about 100 bps.

## 7. L-23 (`e6088a0ec55e`) kept Low

Both reviewers agree. The probe refutes the harm, because the AMM counterparty funds the over-delivery. QA is defensible, but the finding is not downgraded without human sign-off. The retirement of the "V2 ⇒ MEDIUM" trigger is still only a proposal.

## 8. No status changes applied

The status counts are identical before and after these corrections: open 60, false-positive 6, downgraded-to-centralization 2, fixed 1, merged 1, wont-fix 1 (71 entries).
2026-10-28 owner triage: L-02 81ee07506e42 wont-fix → fix-pending; fix = deauthorize StableStakerV1 only (old minter retains principal); verify on chain.
2026-10-28 owner triage: L-31 b9203a0da756 open → wont-fix; remedy = move USDC YieldStrategy off autoUSD at next cutover (phStaging2 CLAUDE.md); reopen conditions recorded.
