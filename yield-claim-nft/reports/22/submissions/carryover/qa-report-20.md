# Carryover QA report — originating audit 20 (carried into yield-claim-nft-22)

> **Carryover QA report — audit 20** (run 20's `submissions/qa-report.md` was **never written**; this is the run-21 rebuild `reports/21/submissions/carryover/qa-report-20.md` (field text copied verbatim from `reports/20/findings/{low,qa}/*.json`), pruned again at run 22). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **Q-21**.
> Removed as no longer live: **L-21** (`6867d791f3…`, `fixed` @ `267660b`, human-applied 2026-10-02), **L-25** (`8ec2be7d59…`, `fixed` @ `267660b`, 2026-10-02), **Q-19** (`098396142d…`, `fixed` @ `267660b`, 2026-10-02); earlier: L-22, L-23, L-24, Q-20 (`wont-fix`, owner triage 2026-10-01). Faithfulness record F-02-048 is carried in `spec-conformance-20.md`.
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | Q-21 | ycn20q21 | `4c2f9c705c39776aba9242b9c1871f1e165a8f55faeeaefb93abe594e58b41e6` | `fix-pending` | yield-claim-nft-20 | yield-claim-nft-22 | yes | `src/dispatchers/UniPoolerV2.sol` |
>
> ⚠ **Q-21 is `fix-pending` — never suppressed, never auto-closed.** See the run-22 numbers update under the entry.

<details><summary>Provenance notes from the run-21 carryover header (kept verbatim: label-collision warnings, facet and instance notes)</summary>

> **Carryover QA report — audit 20.** Run 20's `submissions/qa-report.md` **was never written**, so there is no original document to prune. This file is rebuilt from run 20's per-finding records `yield-claim-nft/reports/20/findings/{low,qa}/*.json` (originating commit `2bfa0905`); field text is copied verbatim from those records and laid out in the QA-report format. Carried at `267660b`, run 21.
> Retained (still `fix-pending` in the ledger; `fix-pending` is never suppressed): **L-21, L-25, Q-19, Q-21**. Three of the four are verified **FIX-COMPLETE** at `267660b` and proposed `fixed`; the status stays `fix-pending` until a human applies `/ledger`. Q-21 is **NOT-ADDRESSED**.
> Removed as disposed (owner triage 2026-10-01, `wont-fix`): **L-22** (`a846cc40e6`), **L-23** (`c15c71fd22`), **L-24** (`8511fd5206`), **Q-20** (`a9037a2f96`). Faithfulness records F-01-048/F-02-048 are carried separately in `spec-conformance-20.md`.
> Locations link to `2bfa090` (where the findings were made). The run-21 status block under each entry gives the `267660b` lines.
> Issue IDs are the run-20 IDs from the records (`ycn20…`), copied verbatim.

</details>

---

## QA Findings

### [Q-21] Plan §5 sizes the zap against the full Balancer pool (~33.8k/34.8k) but the cutover seeds the V2 pair with only the protocol's 62.9% of BPT (~19.1k sUSDS / 21.9k phUSD per side, ~1.59x shallower): phUSD crosses $1 at a ~$636 zap, not ~$1k, so the intended no-ceiling arb skim on POL is larger than the plan states <!-- id: ycn20q21 -->

**Severity:** QA / Informational

**Location:** [`src/dispatchers/UniPoolerV2.sol#L386-L451`](https://github.com/Behodler/yield-claim-nft/blob/2bfa0905b30a10dafcfd8944dad3503b3b802d18/src/dispatchers/UniPoolerV2.sol#L386-L451) (`pool`) at `2bfa090`

**Description:** Not story-unsafe (deliberate design cost; arbitrageur posts $1 collateral per phUSD — per project memory this is closer to accepted design cost than loss). Surfaced because the depth premise is wrong. Depends on the open question whether EOA 0xc65f...e8db (37.1% BPT) migrates. Also corrects the depth premise used in DEDUP-20-03.

**Impact:** Plan §5 sizes zaps against full Balancer depth (~33.8k/34.8k) but the V2 seed is the protocol's 62.9% (~19.1k sUSDS / 21.9k phUSD): phUSD crosses $1 at a ~$636 zap, not ~$1k, so the intended POL arb skim per zap is larger than the plan states.

**Likelihood:** medium if plan numbers are used as-is

**Assumptions:** Keeper follows plan §5 sizing

**External requirements:** none

**Path:**

1. Keeper sizes zaps per plan -> overshoots $1 -> arbitrageurs skim the excess from POL (intended mechanism, mis-sized)

**Plan premise:** BalancerWinddownPlan §5 worked example (X ≈ 33,804, Y ≈ 34,817) vs 62.9% protocol BPT seed (~19.1k sUSDS / 21.9k phUSD)

**Open question:** Whether EOA 0xc65f…e8db (37.1% BPT) migrates into the V2 pair before Stage 2

**Severity justification:** Planning-document premise error affecting operator sizing of an intended (by-design) arb skim on POL; not a code defect and the skim itself is designed behaviour. Informational, carried in the QA bundle with sizing guidance (chunk pool() so post-zap spot <= $1).

**Recommendation:** Redo plan §5 at 62.9% depth or resolve the EOA question before Stage 2; keeper chunks pool() so post-zap spot <= $1.

**Fingerprint:** `4c2f9c705c39776aba9242b9c1871f1e165a8f55faeeaefb93abe594e58b41e6` (`UniPoolerV2.sol:pool:plan-zap-sizing-overstates-seeded-depth`)

> **Carryover status (run 21, `267660b`).** Ledger **Q-21** · `4c2f9c705c…` · status **`fix-pending`** · last seen `yield-claim-nft-21`.
> **Fix verification: NOT-ADDRESSED — stays `fix-pending`, still live.** The fix owed is a correction to BalancerWinddownPlan §5 (deferred to phStaging2:108, not landed at pin `a309040`). The run-21 edit to `pool()` was the L-25 sync fix, not an attempt at Q-21, so this is **not** an incomplete fix. Run-21 econ re-quantification: phUSD still crosses $1 at a ~$636 zap; the sync fix leaves that threshold unchanged but makes it computable from `quotePool` (donation sensitivity $423–$855).

> **Carryover status (run 22, `0fd6bdf`).** Ledger **Q-21** · `ycn20q21` · `4c2f9c705c39776aba9242b9c1871f1e165a8f55faeeaefb93abe594e58b41e6` · status **`fix-pending`** (fix owed, not yet verified) · last seen `yield-claim-nft-22` · re-observed by run 22 via DEDUP-006 (ECON-003 + F-03-052).
> **Numbers update (run 22, block 26,136,000):** the seed price inherited from Balancer is now **~0.924 USDS/phUSD** (plan §5 assumed 0.971 at block 26,093,540). Seeded share 18,656.33 sUSDS / 22,456.37 phUSD, so phUSD crosses $1 at a zap of **Δ\* ≈ $1,712** (1,539.7 sUSDS) — about **2.7x** the plan's **$638** (story-108 re-baseline) and Q-21's original ~$636. On-chain: `Vault.getPoolTokenInfo` balancesRaw `[29663475643465047886662, 35705515073095210602274]`, sUSDS rate 1.1119186.
> **Not proposed fixed.** No code changed under this finding (`UniPoolerV2.sol` unchanged `267660b..0fd6bdf`). The plan-side remediation (story-108's §5 re-baseline at $638) has itself drifted by ~2.7x, so it must not be used to close Q-21 — treat the remediation as not done. Any fix should state its block and mandate a live re-quote of Δ\* from the pair's balances right before Stage 2, rather than a fixed figure. Related new spec item: F-03-052 (`ycn22f3`, `8ab7d54dc9…`) — story-052's human seed-price confirmation is not carried into any enforced gate.
