# Classification log: phoenix-phase-2-staging-35 (script audit)

Source 7ac6e70 (read-only), branch master. Input: sanitized-findings.json (7). Ledger and fingerprints not modified.

**Result: 0 High, 0 Medium, 3 Low, 4 QA, 0 Centralization. 4 faithfulness tags.**

| entryPoint | final label | proposed | severity | F-tag | fingerprint (12) |
|---|---|---|---|---|---|
| stable-staker-v2-cutover | L-09 | L-09 | Low (borderline M, flagged) | F-L-09 (story-092 step 5) | 78cb5942d483 |
| stable-staker-v2-cutover | L-10 | L-10 | Low, INCOMPLETE FIX of L-07 d6896c6e843d | F-L-10 (story-087 budget AC) | 72e528c8715f |
| stable-staker-v2-cutover | L-11 | Q-06 | Low (raised from QA, borderline, flagged) | none | e6e1f293bbad |
| stable-staker-v2-cutover | Q-05 | Q-05 | QA/NC | none | df5f14bae8a7 |
| stable-staker-v2-cutover | Q-06 | Q-07 | QA/NC (entryPoint attribution flag: dev) | none | 9c4e21bb9fd7 |
| dola-ys-withdrawal:status | Q-01 | Q-01 | QA/NC | F-Q-01@status (story-092 runbook step 2 vs Phase 0 margin) | 8633815e4b2b |
| initiate-dola-ys-withdrawal | Q-01 | Q-01 | QA/NC | F-Q-01@initiate (story 090 vs 092 conflict) | 4cdafc61037c |

## L-09: realism checks (source-verified)
- **Trigger reachability.** `StableYieldAccumulator.claim` (lib/stable-yield-accumulator/src/StableYieldAccumulator.sol:560) is permissionless to any holder of the claim NFT, which burns one unit. It loops every listed strategy and calls `skimSurplus(token, msg.sender)` (L601). `AYieldStrategy.skimSurplus` is `onlyAuthorizedWithdrawer` (lib/vault/src/AYieldStrategy.sol:461), and SYA is that withdrawer. 0x1760 stays SYA-listed until tx #52, and halt note (f) confirms the source is unpaused. The injection (inject-driver.sh) called `skimSurplus(DOLA, claimer)` with SYA impersonated, which is exactly the per-strategy call inside claim. It was mined in the same block as tx #42, so after the local pass and before the execute. The ordering therefore matches the headline and the PoC proves the stated claim, not a narrower one.
- **Frequency.** 5 claims in 30 days (sya-rewardscollected-30d.tsv, 15 rows / 3 strategies). The exposure is session start to tx #43, which is tens of minutes under `--slow --ledger`. That gives well under 1% per session from claims. A Tokemak valuation down-step larger than accretion since the start (~0.011 DOLA/h) also triggers it, and its probability is unquantified. No DOLA mints were seen in 30 days.
- **Revert sensitivity.** OWNER holds ~0 DOLA of its own, so any shortfall reverts `noMintDeposit`, even 1 wei.
- **Impact bound.** Collateral sits on the trusted OWNER EOA, and the resume converges (13-*, 14-*). The dangling approval is inert: both `safeTransferFrom` sites in PhusdStableMinter (L167 onlyOwner noMintDeposit, L226 mint) pull from msg.sender. DOLA minting stays off and V2 stays paused, but both are already off by design during the session.
- **Verdict: Low.** Medium is not met. Nothing is lost, the halt is loud on an attended path, and recovery is one documented resume. It stays above QA because a story-092 AC and the halt (b) NatSpec safety claim are unenforced on the mined state, and `:verify` cannot see the excess branch. Compare run-22 M-01 (Medium): that case had *no* outcome verification. Here `:verify` covers registration and principal, and only OWNER's residual is missing. **Re-rate to Medium** if the halt compounds with a late-window start (L-11) or claim frequency or pool size grows materially.

## L-10
- `--legacy --with-gas-price $CUTOVER_GAS_PRICE_WEI` fixes the price, and the preflight reads the same env var, so the price cannot drift. Gas is the only variable. At 0.3 gwei the funded 26.4M gas-equivalent (0.00792 ETH) completed. The node's upfront check peaks at 25,163,101 on tx #41, leaving 4.7% slack (07-gas-analysis.txt).
- The preflight fails loud only when OWNER is below the *stated* budget (06: refused, 0 txs). Nothing guards the case where the stated budget is itself too low. This is a footgun under Law 3: a competent owner who trusts ETH_BUDGET|OK would be surprised by a -32003 halt mid-Phase 6.
- Low, not Medium: it is resumable, nothing is lost, and it needs staker growth or limit variance on top. **INCOMPLETE FIX of FIXED L-07 d6896c6e843d.** A human decides whether to reopen L-07 or keep L-10 separate.

## L-11 (was Q-06)
The owner controls timing, but the consequence is not obvious. The RE-INITIATE PATH runbook says "rerun step 1, wait 6h, resume; every completed step skips". It never says that the Phase 0 window gate sits ahead of the Phase 7 V2 unpause, which freezes every migrated staker for the halt, plus re-initiation, plus at least 6h (fork-proven, test_R35_OBS04). Phase 0 allows a start up to 6h before expiry, so a halt with a few hours of operator latency is enough. That availability impact on user funds lifts it out of QA. The compound precondition, the bounded duration and full recoverability keep it below Medium. **Flagged: QA vs Low borderline.** It was relabelled because its severity changed, and the old Q-07 became Q-06 so the QA labels stay sequential.

## QA items
- **Q-05.** The second dead window is documented in //StableStakerV2Cutover and in halt (g), and preview probes it. The stale :broadcast key is a comment defect. Fix it together with fix-pending Q-04 a62956952abd. Neither suppresses the other.
- **Q-06 (was Q-07).** Committed conflict markers affect only dev/UI, and the mainnet patch is unaffected. Attribution flag: it may belong under entryPoint `dev`.
- **Q-01@status.** The signal is wrong in the last 6h and while paused, but the consumer fails closed before signing. Tagged F because story-092 runbook step 2 uses this signal as the go signal.
- **Q-01@initiate.** The script is faithful to story-090's literal AC, but that AC conflicts with story-092's margin, and the timestamps come from the local pass. Fail-safe. F-tagged as a story conflict (the story is not unsafe).

## Flags for human review
1. L-09: Low/Medium borderline.
2. L-10: incomplete fix of fixed L-07.
3. L-11: QA/Low borderline, and the label changed from Q-06.
4. Q-06 (was Q-07): entryPoint attribution (dev).
