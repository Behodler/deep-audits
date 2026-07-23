#!/usr/bin/env python3
"""Build deduplicated-findings.json for phoenix-nft-staking-22 and append
symbolic/pattern carryovers to manual-review.json. Pure file reasoning, no tooling."""
import json, os

RD = "/home/justin/code/audits/reports/phoenix-nft-staking-22"
static = json.load(open(f"{RD}/static-analysis-findings.json"))

CHANGED = {"src/NFTStakerDepletionV2.sol", "src/BatchNFTMinterMultiToken.sol",
           "src/NFTStakerPriceScaledMigrateReady.sol"}
MIGRATORS = {"src/NFTStakerMigrator.sol", "src/InPlaceNFTStakerMigrator.sol"}
# frozen/unchanged: NFTStaker, NFTStakerPriceScaled, NFTStakerDepletion, BatchNFTMinter

def scope(c):
    if c in CHANGED: return "changed"
    if c in MIGRATORS: return "interaction-partner-unchanged"
    return "frozen-unchanged"

REENT = {"reentrancy-no-eth", "reentrancy-benign", "reentrancy-events"}
groups = {}
for f in static["findings"]:
    t = f["type"]
    key = ("reentrancy" if t in REENT else t, scope(f["contract"]))
    groups.setdefault(key, []).append(f)

DISPOSITIONS = {
 ("reentrancy","changed"): ("refuted-by-tier2",
  "CODE-VER-05/CODE-VER-06: contract-wide OZ ReentrancyGuard on every mutator, CEI (positions zeroed before ERC1155 transfer), inbound ERC1155 hooks have receiver=this (ERC1155Holder), phUSD non-callback, batchMint nonReentrant with pre-loop pot snapshot; read-only reentrancy cleared (views consistent during callback window). Tier-3: 24k forge calls/invariant + 120,054 Medusa calls, 0 counterexamples on solvency/conservation."),
 ("reentrancy","interaction-partner-unchanged"): ("carryover-to-ledger",
  "Migrator code unchanged in c881a42..bb4fea0 (regression window); reentrancy surface audited runs 19-21. Tier-3 this run exercised migrator flows against fixed V2: captured==0, totalUnforwarded==0 (invariant-results antiVacuity). Sanitizer to reconcile against ledger; no new instance."),
 ("reentrancy","frozen-unchanged"): ("carryover-to-ledger",
  "DEPLOYED-FROZEN contracts, zero behavioral drift this window (faithfulness: comment-only). Prior-run dispositions govern; sanitizer reconcile."),
 ("timestamp","changed"): ("tool-noise",
  "All block.timestamp uses are accrual/window math (windowEnd, elapsed, lastRewardTime) — no value-bearing randomness. Pattern-matcher WEAK-PRNG explicit no-match note covers the 20 V2 references."),
 ("timestamp","interaction-partner-unchanged"): ("tool-noise", "Same accrual/deadline math class; unchanged code."),
 ("timestamp","frozen-unchanged"): ("tool-noise", "Same class on frozen contracts; prior runs."),
 ("calls-loop","changed"): ("tool-noise-known-class",
  "batchMint loop = known self-DoS L-02 class (e35388bf, see MR-004); batchMigrate/_safePayTo loops = known migration cluster (memory: migration-cluster-triage; M-05 bdf84579 backstop). Loop-revert on _snapshotRewards floors is the documented minRewards design. No new unbounded third-party griefing path (pattern DOS-UNBOUNDED-LOOP no-match beyond MR-004)."),
 ("calls-loop","interaction-partner-unchanged"): ("carryover-to-ledger",
  "Migrator loop-revert (reverting-recipient brick class) is ledgered migration-cluster territory; unchanged code."),
 ("calls-loop","frozen-unchanged"): ("carryover-to-ledger", "Frozen contracts; prior-run dispositions govern."),
 ("uninitialized-local","changed"): ("refuted-by-tier2",
  "CODE-VER-06: zero-default accumulator pattern (batchMigrate:702 totalAmount, batchMint:419 counters, :543 payout locals) — benign false positives."),
 ("uninitialized-local","interaction-partner-unchanged"): ("tool-noise", "Same zero-default accumulator pattern in migrator loops (total/count)."),
 ("uninitialized-local","frozen-unchanged"): ("tool-noise", "Same accumulator pattern; frozen code."),
 ("unused-return","changed"): ("tool-noise",
  "Ignored mint()/tuple returns in batchMint (CODE-VER-07 interaction review clean: length-checked, index-bound payout) and _recomputeSchedule tuple destructuring in MigrateReady — style-level; no value path depends on the discarded value."),
 ("unused-return","frozen-unchanged"): ("tool-noise", "Same destructuring pattern on frozen contracts."),
 ("incorrect-modifier","changed"): ("tool-noise",
  "nonReentrant-not-first ordering: preceding modifiers (whenNotPaused/onlyMigrator) make no external calls, so ordering is inert. QA-style at best."),
 ("incorrect-modifier","interaction-partner-unchanged"): ("tool-noise", "Same inert modifier-ordering note; unchanged code."),
 ("incorrect-equality","changed"): ("refuted-by-tier2",
  "runwaySeconds() rewardRate==0 strict equality is a division-by-zero guard on a view (CODE-VER-06) — benign."),
 ("incorrect-equality","interaction-partner-unchanged"): ("tool-noise",
  "claimableAt strict equality on a view-only schedule lookup; unchanged migrator code, prior-run covered."),
 ("incorrect-equality","frozen-unchanged"): ("tool-noise", "Same div-by-zero guard on frozen V1 runwaySeconds()."),
 ("unchecked-transfer","interaction-partner-unchanged"): ("carryover-to-ledger",
  "Aderyn unsafe-ERC20 on migrator forward legs; token is phUSD (protocol standard ERC20, reverts on failure). Unchanged code; sanitizer reconcile — QA ceiling."),
}

consolidated = []
cull_log = []
for (cls, sc), items in sorted(groups.items()):
    disp, reason = DISPOSITIONS[(cls, sc)]
    ids = [f["id"] for f in items]
    rep = {"class": cls, "scope": sc, "disposition": disp, "count": len(items),
           "originalIds": ids,
           "instances": [{"contract": f["contract"], "line": f["line"], "severity": f["severity"], "source": f["source"]} for f in items],
           "reason": reason}
    consolidated.append(rep)
    for f in items:
        cull_log.append({"originalId": f["id"], "action": disp,
                         "survivingRepresentative": f"consolidatedStatic[{cls}/{sc}]",
                         "reason": f"{cls} class, {sc} scope: see consolidated group reason"})

out = {
 "project": "phoenix-nft-staking",
 "run": "phoenix-nft-staking-22",
 "commit": "bb4fea02ceecce879bab15122b1f378f76d2a0b6",
 "stage": "deduplication",
 "mode": "regression / fix-wave (stories 025/026/027), window c881a42..bb4fea0",
 "dedupTimestamp": "2026-07-23T00:00:00Z",
 "inputs": {
   "static-analysis-findings.json": {"raw": static["findingsCount"], "note": f"{static['filteredCount']} already filtered upstream by static-analyzer"},
   "pattern-matches.json": {"findings": 1, "manualReview": 2},
   "manual-review.json (pre-existing)": {"entries": 5},
   "code-findings.json": {"findings": 0, "verificationRecords": 7},
   "econ-findings.json": {"findings": 1, "verificationRecords": 4},
   "faithfulness-findings.json": {"findings": 0, "verdicts": 4, "storyUnsafeFlags": 0},
   "invariant-results.json": {"failures": 0, "passed": 9},
   "symbolic-results.json": {"failed": 1, "proofs": 10, "timeout": 9, "errored": 7, "methodology": 1}
 },
 "rawFindingCount": static["findingsCount"] + 1 + 1 + 1,
 "dedupedCandidateCount": 3,
 "candidateFindings": [
  {
   "id": "DEDUP-22-001",
   "originalIds": ["ECON-22-01", "PATTERN-001"],
   "severity": "low",
   "severityNote": "econ-scanner Low (owner footgun); pattern-matcher potential-medium on the base class — base class is already dispositioned (858e9e80 wont-fix), so the live delta is the Low aggregation footgun. Severity-classifier to confirm.",
   "type": "owner-over-funding-footgun-amplified (multi-token aggregate nudge pot)",
   "contract": "src/BatchNFTMinterMultiToken.sol",
   "function": "batchMint / setNudgeTokenWhitelist / _payRewards",
   "lines": {"batchMint": 364, "payout": 434, "potSnapshot": 410},
   "rootCause": "story-025 pays the ENTIRE pre-loop pot of EVERY whitelisted nudge token to one qualifying recipient on a count-only gate. The nudge-snipe profitability threshold therefore becomes the AGGREGATE pot across the whole whitelist, not per-token: an owner funding N tokens each safely under the per-token margin can unknowingly breach the margin in aggregate, making a front-run snipe (mint exactly nudgeSize, sweep every pot) net-profitable.",
   "mergeRationale": "PATTERN-001 (BATCH-PAYOUT-FIXED-POT regression anchor) and ECON-22-01 share contract + nudge-pot root cause. PATTERN-001's base class (count-gated whole-pot payout, caller-chosen recipient) reconciles to ledger history: H-01 story-014 fix + 858e9e80 over-funding wont-fix (run-21) — the sanitizer must NOT re-report the base class as novel. ECON-22-01's aggregation delta is genuinely NEW to the multi-token rework and is the surviving reportable content.",
   "refileDisclosure": "Per memory 'disclose-when-refiling-owner-wontfix': prior entry 858e9e80 (over-funding footgun, wont-fix run-21) covers the per-token pot on BatchNFTMinter. Re-file basis: story-025's multi-token whitelist changes the safe-funding invariant from per-token to whitelist-aggregate — a materially different (and less obvious) operating constraint on a NEW contract; new fingerprint expected, dedup will not auto-match. Not a silent override of the wont-fix.",
   "presentMitigations": ["Pot snapshotted pre-loop (donation self-refund leg closed; test_OwnDonationsDoNotRefundToBatcher)",
     "nudgeSize genuine paid mints = real sunk cost (NFT has no redemption leg; econ ECON-VER-04 re-verified the premise holds under V2 — staking yield is a capped mint-funded closed loop)"],
   "suggestedFix": "Cap per-batch payout, or pay only one designated token's pot per qualifying batch; alternatively document the aggregate-margin operating rule.",
   "lawFraming": "Law 3 non-obvious owner footgun (competent owner reasoning per-token would be surprised); Law-1 relevance only via owner misconfiguration.",
   "confidence": "medium",
   "relatedLedger": ["858e9e80 (wont-fix run-21)"]
  },
  {
   "id": "DEDUP-22-002",
   "originalIds": ["BMT-LOCAL-01 (profile)", "PATTERN-MR-002"],
   "severity": "low",
   "severityNote": "ceiling Low/QA per both sources; value impact bounded (minRewards is floor-only, whole balance paid regardless).",
   "type": "whitelist swap-and-pop index-rebind race (minRewards floors bind to wrong tokens)",
   "contract": "src/BatchNFTMinterMultiToken.sol",
   "function": "batchMint / setNudgeTokenWhitelist",
   "lines": {"swapAndPop": 224, "positionalBinding": "minRewards[i] <-> _nudgeTokens[i]"},
   "rootCause": "setNudgeTokenWhitelist swap-and-pop reorders _nudgeTokens; batchMint binds minRewards[] positionally. An owner remove+add pair of SAME length landing between a caller's getNudgeTokens() fetch and their batchMint silently binds the caller's slippage floors to the wrong tokens (length check cannot catch it) — floors under-protect exactly when they are needed.",
   "mergeRationale": "Tier-1 profile local finding BMT-LOCAL-01 and pattern-matcher PATTERN-MR-002 are the same root cause at the same site; code-scanner CODE-VER-07 and econ ECON-VER-03 both independently confirm it as the sole residual management hazard of the story-025 rework. Consolidated; promoted from parked manual-review to candidate finding on triple corroboration.",
   "suggestedFix": "Encode floors as (token, minReward) pairs and match by address, not index; or version/nonce the whitelist and require the caller to pass the expected nonce.",
   "lawFraming": "Law 3 non-obvious owner-timing footgun harming a third-party caller (not the owner) — in scope at Low.",
   "confidence": "medium",
   "relatedLedger": []
  },
  {
   "id": "DEDUP-22-003",
   "originalIds": ["MR-003"],
   "severity": "low",
   "severityNote": "timing-shift only, no value leak — econ ECON-VER-01 independently verified budget conservation (lower rate over longer window; rate totalStaked-independent, no per-share dilution).",
   "type": "depositFor unconditional tail _recomputeSchedule resets depletion window (L-01 class on new V2 file)",
   "contract": "src/NFTStakerDepletionV2.sol",
   "function": "depositFor",
   "lines": {"recomputeTail": 793},
   "rootCause": "Every migrator-driven depositFor resets windowEnd = now + windowSeconds, extending the depletion runway. Bounded: onlyMigrator + Active-gated; shifts emission TIMING, never total value.",
   "mergeRationale": "Promoted from manual-review MR-003: the mechanism is confirmed at source by econ-scanner (not just pattern inference), and the class is ledgered OPEN as ced20f2e (L-01) against V1 NFTStakerDepletion.depositFor. V2 is a NEW file — new fingerprint, dedup will not auto-match — so a V2-side entry is required to keep the open class visible on the contract that will actually be deployed.",
   "refileDisclosure": "Reconciles to ced20f2e (L-01, open) — same class, new contract; finding-manager should link the entries (relatedTo), not treat as independent discoveries.",
   "confidence": "high",
   "relatedLedger": ["ced20f2e (L-01, open, V1)"]
  }
 ],
 "informationalRecords": [
  {
   "id": "DEDUP-22-INFO-01",
   "originalIds": ["SYMBOLIC-22-001"],
   "disposition": "informational-expected (designed witness, not a vulnerability)",
   "detail": "check_pendingNeverExceedsEpochShare FAIL is the documented ~1-wei user-favouring rounding across two floored accrual snapshots, absorbed by _safePay's dust branch. NOT a new finding. CAVEAT preserved: the companion <=1-wei bound (check_pendingExceedsShareByAtMostOne) TIMED OUT this run — the 1-wei ceiling is fuzz-supported, NOT symbolically proven; carried in manual-review MR-007."
  },
  {
   "id": "DEDUP-22-INFO-02",
   "originalIds": ["SYMBOLIC-22-META-01"],
   "disposition": "methodology finding (harness-defect class, survives as process knowledge)",
   "detail": "Default halmos PRUNES external-call reverts: 'no-revert' checks asserting on an external harness call are structurally unfalsifiable. Four prior-session PASSes downgraded to zero weight (vacuousPasses). Future no-revert proofs must encode via low-level call + assert on success flag. Carried in manual-review MR-008."
  }
 ],
 "fixConfirmations_doNotDrop": [
  {"focus": "story-026 depositFor settlement (run-20 High / run-21 M-03 at source)",
   "verdict": "FIX COMPLETE on NFTStakerDepletionV2 — triple-verified: code (CODE-VER-01: no forced-settlement, no ss12m1 haircut, no double-pay, reentrancy-safe), econ (ECON-VER-02 independent), symbolic PROOF on real bytecode (check_depositFor_paysUserExactlyOnce, 15 paths; migrator delta==0), fuzz (migratorLeak==0 over 144k calls)."},
  {"focus": "story-027 stake() Active gate (audit-20 M-05 / bdf84579 wedge)",
   "verdict": "WEDGE CLOSED for NEW deployments — PROVEN unbounded-domain on real bytecode of BOTH V2 and MigrateReady (stake reverts while Migrating for every caller/amount); all drain paths verified open (CODE-VER-03); finalizeAndReset stayed reachable in fuzz. Deployed-frozen V1 stays ungated by design — M-05 (bdf84579) remains the load-bearing backstop for LIVE instances; candidate closure applies to new deployments ONLY."},
  {"focus": "M-03 migrator capture-and-forward guard (b3243f42)",
   "verdict": "STILL LOAD-BEARING for the three DEPLOYED-FROZEN V1 depletion stakers (EYE/SCX/FLX). The V2 source fix is ADDITIVE. DO NOT collapse/close b3243f42 — flagged independently by code, econ, and faithfulness agents."},
  {"focus": "V2 clone drift check",
   "verdict": "Name-normalized diff shows ONLY the two intended deltas (stake gate 557, _safePayTo 782). MAINTENANCE COUPLING watch-note: V2 + MigrateReady + PriceScaled are hand-maintained clones; future NFTStaker-family fixes must be manually mirrored and both files diffed next run."}
 ],
 "consolidatedStatic": consolidated,
 "cullLog": cull_log,
 "manualReviewDispositions": [
  {"id": "MR-001", "disposition": "remains-parked", "note": "MasterChef accrual-ordering anchor; mitigations verified present by code-scanner + pattern no-match notes; b58b172e (M-01 Linear-Depletion) NOT reintroduced (also symbolically proven rate is totalStaked-independent, check_recomputeSchedule_totalStakedIndependent). Human confirm-and-close at triage."},
  {"id": "MR-002", "disposition": "remains-parked", "note": "Runway-depletion anchor; mitigations confirmed + 9/9 invariants held incl. solvency. NOTE: the floor-safety arithmetic (check_recomputeSchedule_floorSafe) TIMED OUT symbolically — closure rests on fuzz + source argument (see MR-007)."},
  {"id": "MR-003", "disposition": "promoted", "note": "Promoted to DEDUP-22-003 (Low candidate, ced20f2e class on V2, new fingerprint)."},
  {"id": "MR-004", "disposition": "remains-parked", "note": "batchMint self-DoS loop reconciles to e35388bf (L-02, submitted) — same class, multi-token variant. Sanitizer/human: link, do not re-report."},
  {"id": "MR-005", "disposition": "remains-parked", "note": "ERC1155-receive reentrancy MITIGATED on new contract (nonReentrant + pre-loop snapshot; corroborated CODE-VER-07). Frozen BatchNFTMinter instance (c847207c M-02 open) is OUT of this change window — do not close it on the strength of the new contract's guard."}
 ],
 "manualReviewAppended": ["MR-006 (PATTERN-MR-001: V2 emergencyWithdraw M-02 class reconcile)", "MR-007 (symbolic unverified carryover: SymbolicScheduleMath ERROR set + 6 TIMEOUT families)", "MR-008 (halmos vacuous-pass methodology carryover)"],
 "zeroFindingAttestations": {
   "code-findings": "0 new interaction findings (7 verification records preserved above)",
   "econ-findings": "1 finding (merged into DEDUP-22-001); M-02 emergencyWithdraw class present verbatim on V2 = known wont-fix, routed to MR-006 not silently accepted",
   "faithfulness": "stories 025/026/027 all faithful, 0 securityEscalations, 0 storyUnsafeFlags; V1/interface changes comment-only (zero behavioral drift)",
   "invariants": "9/9 held (24k forge calls/invariant + 120,054 Medusa calls, anti-vacuity census armed) — bug-finding evidence, not proof",
   "symbolic": "2 regression targets PROVEN on real bytecode; 1 designed-witness FAIL (INFO-01); 9 TIMEOUT + 7 ERROR carry ZERO safety weight → MR-007"
 }
}

with open(f"{RD}/deduplicated-findings.json", "w") as fh:
    json.dump(out, fh, indent=1)

# ---- append carryovers to manual-review.json ----
mr = json.load(open(f"{RD}/manual-review.json"))
mr["manualReview"].extend([
 {
  "id": "MR-006",
  "source": "pattern-matcher (pattern-matches.json manualReview PATTERN-MR-001) via deduplicator",
  "patternId": "EMISSION-WINDOW-BOUNDARY",
  "type": "emergencyWithdraw-skips-recompute (M-02 survivor over-emission class)",
  "severity": "potential-medium",
  "contract": "src/NFTStakerDepletionV2.sol",
  "line": 639,
  "confidence": "low",
  "description": "V2 inherits the NFTStaker emergencyWithdraw escape-hatch design verbatim: skips _syncBudget/_updatePool, recycles forfeited pending from committedDebt into rewardBudget without schedule recompute — the historical M-02 survivor-over-emission class. Attenuated in the depletion model (rate = budget/window is totalStaked-independent, so a leaver does not directly re-rate survivors), and econ-scanner ECON-VER-01 verified it present-verbatim/not-a-regression. M-02 is WON'T-FIX (owner-ack 2026-06-09) on the ORIGINAL contract; V2 is a NEW file → new fingerprint, dedup will not auto-match. Human decision needed: fold under the M-02 wont-fix (extend disposition to V2) or file a V2-side linked stub. Per 'disclose-when-refiling-owner-wontfix': prior entry = M-02 (memory: phoenix-nft-staking-emergencywithdraw-overemission); the original wont-fix rationale (deployed + no migrate-on-behalf + pullAndRefresh mitigation) was instance-specific — V2 is NOT yet deployed, so the rationale does not automatically transfer.",
  "reconciliation": {"relatedLedger": "M-02 run-16 wont-fix", "newFingerprintExpected": True}
 },
 {
  "id": "MR-007",
  "source": "symbolic-analyzer (symbolic-results.json unverified) via deduplicator",
  "type": "symbolic-unverified-carryover",
  "severity": "methodology-carryover (zero safety weight, NOT evidence of a bug OR of safety)",
  "contract": "src/NFTStakerDepletionV2.sol + NFTStakerPriceScaled family",
  "confidence": "n/a",
  "description": "Properties NOT proven in run-22 under the mandatory WSL2 resource caps (60s/assertion, 4G scope). (1) SymbolicScheduleMath — ALL 7 PriceScaled schedule checks (recomputeNoOverflow_inDomain, S_exact_underProductBound, S_neverWraps_unbounded, rateRoundsDown, runwayNeverOverCommitsBudget, budgetPlusDebtNeverExceedsV, latestPriceRoundsDownBoundedByScale) ERRORED: yices-smt2 OOM-killed at 2.3GB inside its cgroup on Math.mulDiv 512-bit encodings. Untouched by stories 026/027; needs a bounded re-encoding avoiding full mulDiv or a larger-memory host. (2) Six TIMEOUT families on V2 accrual arithmetic incl. check_recomputeSchedule_floorSafe (rate*window <= budget floor direction) and check_pendingExceedsShareByAtMostOne (the <=1-wei ceiling companion to the designed witness SYMBOLIC-22-001) — all fuzz-held (144k calls) but symbolically OPEN. These remain unproven obligations for future runs; do not cite run-22 as having proven them.",
  "reconciliation": {"carryover": True, "retryGuidance": "longer solver budget on beefier host, or bounded re-encodings; see symbolic-results.json resourceCaps + unverified"}
 },
 {
  "id": "MR-008",
  "source": "symbolic-analyzer (SYMBOLIC-22-META-01) via deduplicator",
  "type": "methodology — halmos prunes external-call reverts",
  "severity": "process-carryover",
  "contract": "test harnesses (SymbolicAccrual/SymbolicAccrualBounded)",
  "confidence": "high (proven by SymbolicRevertProbe: reachable checked-underflow still PASSes)",
  "description": "Default halmos silently PRUNES external-call reverts, so 'no-revert' checks asserting on an external harness call are structurally unfalsifiable. Four prior-session PASSes (check_safePayNoUnderflow_underStrongInvariant, check_safePayNoRevert_atCommittedDebtFloor, check_safePayNoRevert_withMintDebtInflatedBudget, check_safePayUnderflowUnreachable_freeState) carry ZERO weight for their intended property — do NOT cite them as proof _safePay cannot revert; the LOCAL-007 revert-window question stays with fuzz + manual reasoning. Future no-revert proofs: low-level call + assert on success flag (as SymbolicStakeGateV2 does).",
  "reconciliation": {"carryover": True}
 }
])
mr["manualReviewCount"] = len(mr["manualReview"])
mr["note"] = mr.get("note","") + " | run-22 deduplicator appended MR-006..MR-008 (pattern M-02-class reconcile + symbolic unverified/methodology carryovers); MR-003 promoted to DEDUP-22-003."
with open(f"{RD}/manual-review.json", "w") as fh:
    json.dump(mr, fh, indent=1)

print("deduplicated-findings.json written:",
      len(out["candidateFindings"]), "candidates,",
      len(consolidated), "static groups,",
      len(cull_log), "cull-log rows;",
      "manual-review entries now", mr["manualReviewCount"])
