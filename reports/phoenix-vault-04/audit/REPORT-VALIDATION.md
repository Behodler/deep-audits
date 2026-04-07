# Phoenix-Vault-04 Submission Validation Report

Validator: report-validator agent
Date: 2026-04-07
Reports validated: 6 (H-01, H-02, H-03, H-04, H-05, M-01)

## Summary verdict

**STATUS: NOT READY FOR SUBMISSION — multiple blocking issues found.**

The technical content of all six reports is strong: each finding describes a real, exploitable vulnerability with accurate code references and clear impact. However, the submission package has several mechanical/format problems that will hurt scoring or cause confusion at the form-paste stage. Most are quick to fix.

The most important issues, in priority order:

1. **PoC files are missing on disk for 5 of 6 findings.** Only `H-02-poc.t.sol` actually exists in `audit/pocs/`. The H-01 PoC is inlined in the markdown body (and works — I verified it compiles and passes against `lib/reflax-yield-vault`), but the H-03, H-04, H-05, and M-01 reports reference PoC files that do not exist anywhere. C4 mandates "coded, runnable PoC required for all High/Medium findings". This is a blocking issue for H-03, H-04, H-05, and M-01.
2. **H-01 has a third `## Proof of Concept` heading.** C4 form format requires exactly two `##` headings (`## Finding description and impact` and `## Recommended mitigation steps`). H-01's PoC must be moved to a separate file and the inlined section converted to a `### Proof of Concept` subheading under one of the two top-level sections, or removed entirely.
3. **Three titles exceed the 100-character hard cap** (H-02 = 111, H-03 = 119, H-04 = 111). They will need to be shortened.
4. **Metadata header inconsistency.** Only H-01 has a `Severity:` field. H-03 uses a `/blob/main/` URL while every other report uses the pinned `/blob/f328d52/` commit hash — `main` will float and break the link if upstream moves.
5. **Cross-finding deduplication risk.** H-02, H-03, H-05 share a root cause family. H-03 and H-05 explicitly call this out and differentiate themselves; H-02 does not. A judge may merge H-02 with the others if H-02 doesn't make a clear distinction up front.

Detail follows.

---

## H-01 — AMM withdraw slippage anchored to vault internal rate

**Status: FAIL (format)**

### What's right
- Real, exploitable, structurally clear bug. Round-trip `convertToShares -> convertToAssets` cancels the price-per-share factor, so `minOut` is anchored to the requested underlying amount and any AMM discount above `slippageToleranceBps` bricks every withdrawal — independent of withdrawal size.
- The inlined PoC compiles and **both tests pass** when run against `lib/reflax-yield-vault` at commit `f328d52`. I verified this directly with `forge test --match-contract PoC_H01_SlippageAnchorBricksWithdrawals -vv`.
- Source line references are accurate: `_depositInternal` slippage block at L275-L283, `_withdrawInternal` slippage block at L313-L328, `_totalWithdraw` swap at L378-L390, `_withdrawFrom` swap at L428-L442. The L276-L283 reference in the metadata for the deposit block is one line tighter than the actual block (which starts at L275 with the comment) but is functionally accurate.
- Mitigation discussion is thorough (4 options, with the preferred fix anchored to AMM-quoted output) and matches the code architecture.
- Severity-justified: clear DoS path on a strategy whose stated purpose is to handle the exact AMM-discount scenario that breaks it.

### Issues
- **BLOCKER (format): Three `##` headings.** The report has `## Finding description and impact`, `## Recommended mitigation steps`, AND `## Proof of Concept`. C4 form format requires exactly two. Fix: move the PoC to a separate file (`H-01-poc.t.sol`) under `audit/pocs/`, demote the heading to `### Proof of Concept` under "Finding description and impact", or drop the inlined PoC text entirely from the body and let the separate file carry it.
- **BLOCKER (PoC file): no `audit/pocs/H-01-poc.t.sol` file exists.** The metadata says `PoC File: test/poc-H-01.t.sol` but no such file exists in the audit folder, and the workspace `test/poc-H-01.t.sol` is for the unrelated `ERC4626YieldStrategy` (not the strategy this finding targets). The inlined PoC works — it just needs to be saved as a standalone file.
- Title length: 93 chars. Within hard cap, but over the 80-char preference. Acceptable.

---

## H-02 — Withdraws decrement principal by REQUESTED not RECEIVED

**Status: FAIL (title length, dedup framing)**

### What's right
- Vulnerability is real and the PoC file is the **only one that actually exists** at `audit/pocs/H-02-poc.t.sol`. I ran it against `lib/reflax-yield-vault` and it **passes**:
  - Alice (first to withdraw): receives 1000e18 underlying.
  - Bob (last to withdraw): receives only 500e18 underlying despite identical position.
  - Bob's principal is debited by the full 1000e18.
- Code reference range L302-L339 matches `_withdrawInternal` exactly. The principal-debit lines L335-L336 are also correctly identified.
- The report correctly anticipates and rebuts the obvious "but the NatSpec at lines 22-23 documents this" defense, showing why the documented "rounding favors protocol" rule does not apply once the dislocation is large.
- Mitigation options are concrete and ordered by invasiveness.

### Issues
- **BLOCKER (title length): 111 chars exceeds the 100-char hard cap.** Suggested shorter form: `[H-02] Bank-run on AMM dislocation: principal debited by requested, not received`. Length: 79.
- **WARNING (dedup framing): Does not differentiate from H-03/H-05.** H-03 and H-05 both contain explicit "Relationship to other findings" sections that argue for distinctness. H-02 does not. A C4 judge skimming three reports in the same root-cause family could legitimately merge H-02 into one of the others. Recommend adding a short paragraph at the bottom of the impact section noting that H-02 is the *withdrawal-side asymmetric loss*, distinct from H-03 (deposit-side dilution) and H-05 (withdrawFrom cross-client drain), and that the three vectors compose into different attack scenarios.
- Metadata header is missing a `Severity:` field. Only H-01 has one. Either add it to H-02-H-05/M-01 or remove it from H-01 for consistency.

---

## H-03 — Deposit accounting in underlying units lets fair-rate depositor steal value

**Status: FAIL (PoC missing, title length, URL pinning)**

### What's right
- The bug is real and the math walkthrough is precise. Two depositors at different AMM rates own different numbers of shares; the pro-rata view in `totalBalanceOf` redistributes their value unfairly.
- The "Concrete attack / dilution path" section walks through the numbers cleanly: 1000 underlying at 1.25 rate buys 1250 shares; same 1000 at 1:1 buys 1000 shares; total 2250 shares; pro-rata says each owns 1125 — but at fair price, 1250 shares are worth 1250 and 1000 shares are worth 1000, so the dilution is exactly 125 in each direction.
- Includes an explicit "Relationship to H-02" section that clearly differentiates this finding from H-02. This is exactly what's needed for cross-finding deduplication defense.
- Code references are accurate (L273-L291 for `_depositInternal`, L138-L152 for `totalBalanceOf`, L411-L451 for `_withdrawFrom`).
- Recommended mitigation is thorough; preferred fix (track shares per client) eliminates the entire bug class.

### Issues
- **BLOCKER (PoC missing): `H-03-poc.t.sol` is referenced in metadata but does not exist on disk anywhere.** Neither in `audit/pocs/`, nor in workspace test directory, nor in lib. The submission cannot be submitted as High without a working coded PoC; C4 explicitly requires this. The body claims the PoC exists at `test/poc-H-03.t.sol` and contains `test_LateFairRateDepositorDilutesEarlyDiscountDepositor` — needs to actually be written.
- **BLOCKER (title length): 119 chars exceeds the 100-char hard cap.** Suggested shorter form: `[H-03] Deposit dilutes earlier discount-rate depositors via underlying-unit accounting`. Length: 86.
- **BLOCKER (URL): root cause link uses `/blob/main/` instead of pinned `/blob/f328d52/` commit hash.** Every other report uses the commit hash. `main` will float — if upstream moves, the link breaks and the L273-L291 highlighted range may shift to unrelated code. Inline links inside the body also use `/blob/main/` and need to be repinned.
- Missing `Severity:` field in metadata.

---

## H-04 — Two-phase total withdrawal cache is meaningless

**Status: FAIL (PoC missing, title length)**

### What's right
- Bug is real. `_totalWithdraw(address token, address client, uint256 amount)` declares `amount` in its signature, requires `amount > 0`, then never uses it again — instead reading `clientBalances[token][client]` live. I confirmed this against the source at L368-L399.
- The two-PoC-test approach (deposit-side desync and withdrawal-side desync) covers both directions of the cache mismatch.
- Code references for both the parent (`AYieldStrategy.sol#L379-L417` for `_initiateWithdrawal`/`_executeWithdrawal`) and the child (`L368-L399`) are accurate.
- Mitigation Option A (honor the cached amount as an upper bound) is the cleanest fix and is correctly characterized as the smallest change.
- The point about `WithdrawalInitiated` being publicly observable and the executable timestamp being deterministic is a real and underappreciated concern.

### Issues
- **BLOCKER (PoC missing): `poc-H-04.t.sol` is referenced but does not exist on disk anywhere.** The body describes two specific tests (`test_DepositDuringWindowGetsSweptByPhase2`, `test_CachedBalanceIsIgnoredByChild`) but the file is not present. Must be written before submission.
- **BLOCKER (title length): 111 chars exceeds the 100-char hard cap.** Suggested shorter form: `[H-04] Two-phase total withdrawal ignores cached snapshot, sweeps live balance instead`. Length: 87.
- **MINOR**: The "Bug A — Delay bypass" framing in the impact section could be misread as overlapping with M-01 (the `emergencyWithdraw` finding). Recommend adding a one-line note that H-04 attacks `totalWithdrawal` (the supposedly-protected path) while M-01 attacks `emergencyWithdraw` (the always-bypassable path) — they are distinct functions and distinct bugs.
- Missing `Severity:` field in metadata.

---

## H-05 — Surplus extraction sells from shared share pool

**Status: FAIL (PoC missing, title length OK)**

### What's right
- Bug is real and is the cleanest realization of the shared-share-pool root cause. No deposit/withdraw race needed, no price movement timing — a single `withdrawFrom` call drains other clients' surplus.
- The walkthrough (two clients deposit 100, vault doubles, A withdraws 100 surplus, both A and B end up with 50 surplus) is mathematically clean and obviously correct from inspection of the code.
- Includes a "Relationship to other findings" section that explicitly differentiates from H-02 and H-03.
- Code reference L411-L451 matches `_withdrawFrom` exactly.
- Recommended mitigation correctly identifies that this is a per-client share accounting problem, not a per-call cap problem.
- Severity is justified — any authorized withdrawer can drain any other client's yield with a single call. No prerequisite, no race, no privileged access to the victim.
- Title length: 85 chars. Within hard cap.

### Issues
- **BLOCKER (PoC missing): `poc-H-05.t.sol` is referenced but does not exist on disk anywhere.** The body describes two specific tests (`test_ExtractingClientASurplusReducesClientBSurplus`, `test_RepeatedExtractionsDrainAllOfClientB`) with specific expected output (8 iterations to drain B from 100 to ~0.39). Must be written and verified before submission.
- Missing `Severity:` field in metadata.

---

## M-01 — emergencyWithdraw bypasses 24h rugpull delay

**Status: FAIL (PoC missing, otherwise clean)**

### What's right
- Two distinct, real bugs in a single function correctly identified:
  - **Bug A**: `emergencyWithdraw` is `onlyOwner` with no delay/window/pause guard — confirmed against `AYieldStrategy.sol#L227-L233`.
  - **Bug B**: `_emergencyWithdraw` only moves shares, leaving `clientBalances` and `totalDeposited` stale — confirmed against `ERC4626MarketYieldStrategy.sol#L350-L359`.
- Severity is correctly justified at Medium (not High) on the basis that exploitation requires owner action. The report explicitly acknowledges the centralization vector and explains why the impact is still material (silent zeroing of client principal on subsequent withdrawals).
- The "honest use" failure scenario is the strongest part: even if the owner is benign, the next client withdrawal silently zeros their principal because `availablePrincipal` is read stale-high but `availableShares` is read live-zero, then principal is debited by the requested amount and AMM swap happens with `0` shares in. This is a real, owner-action-not-required-after-emergency footgun.
- Code references are accurate.
- Title length: 98 chars. Within hard cap.
- Mitigation correctly notes both bugs need to be fixed separately.

### Issues
- **BLOCKER (PoC missing): `poc-M-01.t.sol` is referenced but does not exist on disk anywhere.** Two specific tests are described (`test_EmergencyWithdrawIsSingleTransactionNoDelay`, `test_EmergencyWithdrawLeavesAccountingStale`) with specific assertions. Must be written and verified before submission.
- Missing `Severity:` field in metadata.

---

## Cross-finding deduplication assessment

The user specifically asked whether H-02, H-03, and H-05 differentiate themselves enough to avoid being merged as duplicates by the judge.

**Verdict: H-03 and H-05 are well-defended; H-02 is at risk of being merged.**

| Finding | Attack surface             | Trigger          | Differentiation in body                |
|---------|----------------------------|------------------|----------------------------------------|
| H-02    | `_withdrawInternal`        | AMM dislocation + withdraw race | NONE — does not mention H-03 or H-05 |
| H-03    | `_depositInternal`         | AMM dislocation + late deposit  | YES — has explicit "Relationship to H-02" section |
| H-05    | `_withdrawFrom`            | Single call from any withdrawer | YES — has explicit "Relationship to other findings" section |

The technical distinctions are genuine — these are three different functions, three different code paths, three different attack triggers — but a fast judge skimming three reports in the same root-cause family will lean on whatever the report itself argues. H-03 and H-05 do this work; H-02 does not.

**Recommendation:** Add 2-3 sentences to H-02's impact section noting that H-02 is the *withdraw-side asymmetric loss* triggered by the order of withdrawal under AMM dislocation, distinct from H-03's *deposit-side silent dilution* (no withdrawal needed) and H-05's *withdrawFrom cross-client surplus drain* (no AMM movement needed). Note that the three compose: an attacker can dilute via H-03, then realize via H-02, while H-05 is independently exercisable.

---

## Master fix list (in order)

### Blockers (must fix before submission)

1. **Write `audit/pocs/H-01-poc.t.sol`** — extract the PoC currently inlined in the H-01 markdown body to a standalone file. Verified to compile and pass against `lib/reflax-yield-vault@f328d52`.
2. **Write `audit/pocs/H-03-poc.t.sol`** — must implement `test_LateFairRateDepositorDilutesEarlyDiscountDepositor` matching the math walkthrough in the report (Alice 1000 @ 1.25 rate → 1250 shares; Bob 1000 @ 1:1 → 1000 shares; assert 125-underlying zero-sum dilution).
3. **Write `audit/pocs/H-04-poc.t.sol`** — must implement `test_DepositDuringWindowGetsSweptByPhase2` and `test_CachedBalanceIsIgnoredByChild` exactly as described in the report body.
4. **Write `audit/pocs/H-05-poc.t.sol`** — must implement `test_ExtractingClientASurplusReducesClientBSurplus` and `test_RepeatedExtractionsDrainAllOfClientB`.
5. **Write `audit/pocs/M-01-poc.t.sol`** — must implement `test_EmergencyWithdrawIsSingleTransactionNoDelay` and `test_EmergencyWithdrawLeavesAccountingStale`.
6. **Remove the `## Proof of Concept` heading from H-01-submission.md** OR demote it to `### Proof of Concept`. C4 form format requires exactly two `##` headings.
7. **Shorten H-02 title** from 111 chars to ≤100. Suggested: `[H-02] Bank-run on AMM dislocation: principal debited by requested, not received`.
8. **Shorten H-03 title** from 119 chars to ≤100. Suggested: `[H-03] Deposit dilutes earlier discount-rate depositors via underlying-unit accounting`.
9. **Shorten H-04 title** from 111 chars to ≤100. Suggested: `[H-04] Two-phase total withdrawal ignores cached snapshot, sweeps live balance instead`.
10. **Repin H-03 root cause link and inline links** from `/blob/main/` to `/blob/f328d52/` to match all other reports.
11. **Add a 2-3 sentence dedup-defense paragraph to H-02** explaining how it differs from H-03 and H-05.

### Non-blockers (recommended)

12. Add a `Severity:` field to H-02, H-03, H-04, H-05, M-01 metadata, or remove it from H-01, for consistency.
13. Standardize PoC file naming. Currently: `test/poc-H-01.t.sol`, `H-02-poc.t.sol`, `H-03-poc.t.sol`, `poc-H-04.t.sol`, `poc-H-05.t.sol`, `poc-M-01.t.sol`. Pick one convention (recommend `H-NN-poc.t.sol` since that's what H-02 already uses).
14. H-04 could add a one-liner clarifying that it attacks `totalWithdrawal` while M-01 attacks `emergencyWithdraw` — distinct functions, distinct bugs — to prevent judge confusion.

---

## What I verified directly

- Read all six submission files in full.
- Read `lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (453 lines) and `AYieldStrategy.sol` (443 lines) and cross-checked every line range cited in every report.
- Verified `simulateYield` exists in `MockERC4626Vault.sol` (referenced by H-01 inlined PoC).
- Verified `MockAMMAdapter.sol` exists in `lib/reflax-yield-vault/test/mocks/`.
- Compiled and ran the H-02 PoC against `lib/reflax-yield-vault` at commit `f328d52`: `[PASS] test_FirstWithdrawerEatsTheYield_LastWithdrawerEatsTheLoss`. PoC works.
- Compiled and ran the H-01 inlined PoC (extracted to a temp file) against the same lib: `[PASS] test_DepositSucceedsAtFavorableRate` and `[PASS] test_WithdrawRevertsWhenMarketPriceBelowInternalRate`. PoC works.
- Confirmed H-03, H-04, H-05, M-01 PoC files do NOT exist anywhere on disk (searched `audit/pocs/`, `workspace/reflax-yield-vault/test/`, `lib/reflax-yield-vault/test/`).
- Confirmed all six reports have NO `#` (top-level) headings.
- Confirmed five of six reports have exactly two `##` headings (H-01 has three).
- Verified all six titles are correctly labeled `[H-NN]` / `[M-NN]`.

## What I did NOT verify

- I did not write the missing PoC files. The missing PoCs are well-specified in the report bodies, but they need to be implemented and run to confirm they actually compile and pass.
- I did not run a full forge test suite — only the specific PoC tests I extracted.
- I did not check for "known issues" overlap; no known-issues file was provided in the audit folder.
