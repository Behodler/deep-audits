# QA Report for phoenix-nft-staking

**Run:** `phoenix-nft-staking-16` (cold scan, `--full`)
**Submodule HEAD:** `5f863d27ebbab5df20131a4592996537cd8bf503`
**In-scope sources:** `src/NFTStaker.sol`, `src/BatchNFTMinter.sol`
**Repo:** https://github.com/Behodler/phoenix-nft-staking

This QA report bundles the Low-severity findings for this run. Two Low findings are **new this run** (L-06, L-07); three are **carryover** from prior runs (L-01..L-03) and are referenced, not re-explained. No new Centralization findings were raised — the project's owner-only setters are centralization-by-design and already documented in the project's known-issues (see the by-design note below). An automated QA/gas appendix (4naly3er) is attached.

---

## Summary

| ID | Title | Status |
|----|-------|--------|
| [L-06](#l-06-transient-solvency-invariant-window-toptupsettargetapy-recompute-rewardbudget-without-a-preceding-pull) | Transient solvency-invariant window: `topUp`/`setTargetAPY` recompute `rewardBudget` without a preceding `pull()` | NEW |
| [L-07](#l-07-documentation-drift-docs-label-a-superseded-reward-model-as-the-current-spec) | Documentation drift: docs label a superseded reward model as the "current spec" | NEW |
| [L-01](#carryover-findings-referenced) | `batchMint` lacks `nonReentrant` (defense-in-depth) | CARRYOVER (open) |
| [L-02](#carryover-findings-referenced) | Uncapped `count` loop in `batchMint` (self-bounded) | CARRYOVER (open) |
| [L-03](#carryover-findings-referenced) | Nudge-token equality guard over-broad revert | CARRYOVER (open) |

| Severity | Count (this run) |
|----------|------------------|
| Low Risk (new) | 2 |
| Low Risk (carryover, referenced) | 3 |
| Centralization | 0 (by-design; see note) |
| **Total Low/QA bundled** | **5** |

---

## Low Risk Findings

### [L-06] Transient solvency-invariant window: `topUp`/`setTargetAPY` recompute `rewardBudget` without a preceding `pull()` <!-- id: pns16l6 -->

**Location:**
- [`NFTStaker.sol#L264` — `setTargetAPY`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L264)
- [`NFTStaker.sol#L278` — `topUp`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L278)
- [`NFTStaker.sol#L385-L421` — `_recomputeSchedule` (sizes budget on `V = balance + mintDebt`, L405)](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L385-L421)
- [`NFTStaker.sol#L113-L122` — the documented "Solvency holds at ALL times" invariant](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/NFTStaker.sol#L113-L122)

**Cross-ref:** spec-conformance **F-02**.

**Description:** Both `topUp` and `setTargetAPY` call `_recomputeSchedule()` **without** a preceding `_syncBudget()` / `pull()`. `_recomputeSchedule` sizes `rewardBudget` on `V = balanceOf(this) + dispatcherHook.mintDebt()` (L405), so when un-pulled `mintDebt > 0` sits at the dispatcher hook, the recompute folds that un-pulled debt into `rewardBudget`. As a result `rewardBudget + committedDebt` transiently **over-states** the on-chain balance by exactly the un-pulled `mintDebt`. The contract's "Critical Invariant" comment (L113-L122) asserts `balance == rewardBudget + committedDebt` holds *at all times*; in this window it holds only *eventually*.

**Impact:** No directly extractable value — the over-statement is phantom. Every payout flows through `_safePay`, which gates on the contract's actual `balanceOf` and reverts on a real shortfall, so the phantom budget is never drainable. Equality self-heals on the next user entrypoint (`stake`/`unstake`/`claim`/`pullAndRefresh`), each of which runs `_syncBudget` → `pull()` before any `_safePay`. The only adverse tail is a contingent, owner-recoverable claim-DoS if the dispatcher hook is rotated or broken inside the window so the assumed `mintDebt` never materialises. PoC-confirmed (Tier-3 scenario F02): the ledger over-states by exactly `mintDebt`, `_safePay` still gates, and `pull()` restores strict equality.

**Recommendation:** Either (a) route `topUp` / `setTargetAPY` through `_syncBudget()` so a `pull()` precedes the recompute (weigh this against the intentional dispatcher-hook-independence property, Feature Spec item 7), or (b) correct the invariant wording from a strict "at all times" claim to an eventually-consistent one — e.g. `balance + mintDebt == rewardBudget + committedDebt`, with a note that strict on-balance equality is restored on every `_syncBudget` and that the interim over-statement is never payable because `_safePay` gates on actual balance.

```solidity
// Option (a): pull before recompute in the two config setters
function setTargetAPY(uint256 newAPY) external onlyOwner {
    _syncBudget();        // pull() first -> recompute sees true balance
    targetAPY = newAPY;
    _recomputeSchedule();
}
```

---

### [L-07] Documentation drift: docs label a superseded reward model as the "current spec" <!-- id: pns16l7 -->

**Location:**
- [`docs/runway-dynamics-and-apy-as-policy.md`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/docs/runway-dynamics-and-apy-as-policy.md) — labels the stale TOTAL-SUPPLY `T` model as the "current spec"
- [`docs/design.md`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/docs/design.md) — still describes the abandoned 540-day fixed-window model

**Cross-ref:** spec-conformance **F-03**; reward-model change tracked as **M-03**.

**Description:** The shipped code is correct: it uses the TOTAL-STAKED model, emitting against the staked subset `S = totalStaked * latestPrice`. The defect is purely documentation-vs-code drift. `docs/runway-dynamics-and-apy-as-policy.md` still presents a superseded TOTAL-SUPPLY `T` model as the "current spec," and `docs/design.md` is fully stale (the abandoned 540-day fixed-window model). A document calling a superseded model the "current spec" is a Law-2 spec-vs-code deviation.

**Impact:** No direct asset impact and no code defect. The realistic harm is operational: an owner consulting the stale runway tables / model to choose `targetAPY` works from `T` (aggregate notional) where the code uses `S` (staked subset), so the doc-derived runway will not match real on-chain runway and the owner mis-sizes `targetAPY` (runway over- or under-provisioned). This is a **non-obvious Law-3 owner footgun** (stale tuning guidance), not an auto-invalid reckless-admin issue. It is recoverable by re-tuning via `setTargetAPY` / `topUp`.

**Recommendation:** Update `docs/runway-dynamics-and-apy-as-policy.md` to the shipped total-staked `S` model and mark `docs/design.md`'s 540-day fixed-window model as superseded/historical. Point owner APY-tuning guidance at the live `runwaySeconds()` / `currentRewardRate()` views rather than static tables, so tuning tracks real on-chain state.

---

## Carryover Findings (referenced)

These three Lows were first reported in `phoenix-nft-staking-12`, remain **open** (not fixed, not triaged), and were re-confirmed present at HEAD `5f863d2`. They are referenced here so they are not lost between runs; the full descriptions, impacts, PoCs, and recommendations live in the original report ([`reports/phoenix-nft-staking/12/submissions/qa-report.md`](../../12/submissions/qa-report.md)) and the carryover stubs in [`submissions/carryover/`](./carryover/). Triage with `/ledger phoenix-nft-staking`.

- **L-01 — `batchMint` lacks `nonReentrant`** ([`BatchNFTMinter.sol#L238-L257`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/BatchNFTMinter.sol#L238-L257)). Re-confirmed this run (SLITHER-001 / PATTERN-001). The ERC1155 `onERC1155Received` callback fires mid-loop, but the High third-party-theft escalation is **not supported** — the nested frame's `forceApprove(minter, 0)` revokes the outer loop's approval, so the issue stays Low. *Recommendation:* add a `nonReentrant` modifier as cheap defense-in-depth insurance; no severity change.
- **L-02 — Uncapped `count` loop in `batchMint`** ([`BatchNFTMinter.sol#L238-L240`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/BatchNFTMinter.sol#L238-L240)). Self-bounded: the caller pays for each mint, so an oversized `count` reverts the caller's own transaction (self-DoS only, no third-party impact). No severity change.
- **L-03 — Nudge-token equality guard over-broad revert** ([`BatchNFTMinter.sol#L230-L233`](https://github.com/Behodler/phoenix-nft-staking/blob/5f863d2/src/BatchNFTMinter.sol#L230-L233)). The equality guard reverts even when nudge is size-disabled. QA/usability nit; ledger records it live at HEAD `5f863d2` (unchanged by story-016). No severity change.

---

## Centralization Risks

**No new centralization findings this run.** The owner-only setters across both contracts (`setTokenMinter`, `setDispatcherIndex`, `setNudgeSize`, `setNudgePaymentToken`, `setPauser`, `rescueERC20`, `setTargetAPY`, `topUp`, `pullAndRefresh`, etc.) are **centralization-by-design** and are already covered in the project's documented known-issues. Per the audit's owner-trust law (CLAUDE.md Law 3), the owner is trusted for knowing actions; these privileged setters are not reported as standalone C-findings. (The one non-obvious owner-footgun consequence surfaced this run is captured at honest severity as L-06/L-07 above, not as a centralization finding.)

The automated appendix below (4naly3er **M-2 "Centralization Risk for trusted owners"**, 18 instances) enumerates these same by-design owner privileges for completeness.

---

## Appendix A — Automated QA/Gas Report (4naly3er)

**Tool:** 4naly3er (the canonical C4-style automated QA/gas report generator), run from `tools/4naly3er` against the in-scope sources `src/NFTStaker.sol` and `src/BatchNFTMinter.sol`.
**Command:**

```bash
cd tools/4naly3er && yarn analyze \
  /home/justin/code/audits/lib/phoenix-nft-staking/src \
  /tmp/nft-staking-scope.txt
```

**Status:** ran successfully (`Done in 1.89s`). Full markdown output is attached as a sibling file: [`submissions/4naly3er-report.md`](./4naly3er-report.md).

**Summary of automated categories** (instance counts):

| Category | Issues | Notable items |
|----------|--------|---------------|
| Gas Optimizations (GAS-1..GAS-10) | 10 | unchecked math (61), `a = a+b` vs `a += b` (7), custom errors vs revert strings (16), `!= 0` vs `> 0` (16) |
| Non-Critical (NC-1..NC-18) | 18 | events missing old/new value (11) & `indexed` fields, missing `address(0)` checks, NatSpec gaps, style/layout ordering |
| Low (4naly3er L-1..L-11) | 11 | 2-step ownership transfer, zero-value transfer reverts, division-by-zero / precision, `PUSH0` on non-mainnet chains, 365-day year |
| Medium (4naly3er M-1..M-2) | 2 | fee-on-transfer accounting (2); **Centralization Risk for trusted owners (18)** |

> **Note on label namespaces:** the `L-*` / `M-*` labels *inside* the 4naly3er appendix are the tool's own internal numbering and are **distinct** from this report's manually-triaged `L-06`/`L-07` labels. The tool's Medium/Low items are bot-baseline observations; the manual triage above is authoritative for severity. Per CLAUDE.md, common automated-tool findings are not escalated without a demonstrated H/M exploit path — 4naly3er's `M-1` (fee-on-transfer) and `M-2` (owner centralization) fall under known-invalid / by-design and are retained here only as the bot-report baseline.

---

*Compiled by the qa-bundler agent for run `phoenix-nft-staking-16`.*
