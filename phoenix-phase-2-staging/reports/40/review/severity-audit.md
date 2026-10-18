# Run 40 severity audit (second opinion)

- Project: `phoenix-phase-2-staging`, full-audit contract scan, run 40, master @ `a4f9f3c`
- Inputs: `findings/**`, `filtered/classify-log.md`, `review/validity.md`, `docs/BalancerWinddownPlan.md`
- Read-only. No finding, submission or ledger file was modified.
- Date: 2026-10-13

## Bottom line

**No finding should become Medium. Run 40 stays at 0 H / 0 M, so the PoC and report stages are not triggered.**

L-01 and L-02 are genuinely borderline. I keep both at Low because I could not build a concrete path to protocol loss, and because the availability impact is a recoverable stall of tooling that is not yet wired to mainnet. It is not a protocol function going down. The doubt over L-04 is now resolved in the classifier's favour: I fork-verified that `enableRecoveryMode` is permissionless after a pool pause.

| Finding | Verdict | Severity |
|---|---|---|
| L-01 | CONFIRMED, with a sharper rationale and trigger | Low (borderline M, keep the HR flag) |
| L-02 | CONFIRMED; the impact text overstates "permanent" | Low |
| L-03 | CONFIRMED | Low |
| L-04 | CONFIRMED; the precondition is now fork-verified | Low (QA would also be defensible; do not downgrade) |
| L-05 | CONFIRMED, post-edit framing | Low |
| Q-01 | CONFIRMED | QA |
| Q-02 | CONFIRMED | QA |
| F-01 | CONFIRMED | F (Law 2) |
| F-02 | CONFIRMED (location edit per validity.md) | F (Law 2) |

---

## L-01: core EOA custody, dust-swap stall, no resume. CONFIRMED Low (borderline)

**The case for Medium is real.**
- The finding is fork-reproduced: a $0.03 swap strands about $41.3k of POL on the owner EOA.
- It contradicts story 103's 2026-10-07 custody requirement.
- C4 Medium covers "function or availability impacted".

**Why it still does not reach Medium:**

1. **No loss path survives scrutiny.** The custodian is the trusted owner (Law 3). In Scenario A the owner holds both legs. In Scenario B the owner holds the BPT.
   - The pair can be poisoned while the stall lasts (9a694ae01fe1), but poisoning does not turn the stall into a loss. With `totalSupply == 0`, a direct `pair.mint` credits only `balance - reserve`, so the griefer's 2-wei reserves are absorbed into the protocol's seed (plan L414).
   - What poisoning does force is new code: an atomic transfer-and-mint contract, because the Router would quote at the griefer's ratio and an EOA cannot batch. That is an operational cost, not a value loss.
2. **The question about the deadlines.** Does a stall cost anything once the post-30-Nov proportional recovery exit stays open? Principal: no. Plan L9 confirms index-4 minting continues, because `_dispatch` never calls Balancer. Plan L20/L38 say recovery stays open, and I verified on the fork that recovery mode can be enabled after a pause (see L-04).
   - The residual costs are time-value, plus phUSD having no deep DEX venue between the 30 Oct pause and completion of a hand recovery.
   - `pool()` stops on 30 Oct whether or not the cutover stalls, so the stall adds nothing there.
   - These costs are bounded, recoverable and owner-controlled, which is not the sustained availability loss C4 Medium needs.
3. **The trigger closes itself at the deadline.** This point is missing from the classifier's reasoning, and it strengthens the PROPORTIONAL-only re-weigh trigger. Scenario A/B needs a Balancer swap between simulation and the step-5 exit. From 30 Oct the pool is paused and swaps are blocked, so a RECOVERY-mode run cannot be split this way. The hazard exists only in the pre-deadline PROPORTIONAL window, which is exactly where the re-weigh trigger is aimed.
4. **It is not reachable on mainnet today.** The core's only importer is DeployMocks, and story 103 (incomplete) specifies a rewire onto the atomic escrow.

**Pushback on the classifier's reasoning.** "Runs 31–37 precedent" should not be load-bearing. Precedent does not set severity; points 1–4 do. Rewrite the rationale so it does not rest on precedent.

**Re-weigh trigger.** Endorse it, with one addition. Raise to Medium if any story-103 mainnet entry point or npm broadcast key runs core steps 4–6 as separate transactions in PROPORTIONAL mode before the 30 Oct pause, without the escrow or skip-if-done gates. At that point a cheap, third-party-triggerable stall would sit on the critical path of a hard deadline, and the story-103 custody requirement would be broken in production. Do not pre-close L-01 when story 103 lands; re-check it then (as DEDUP-009 notes).

## L-02: UniswapHelper honest first-LP brick (re-raises ycn L-26). CONFIRMED Low

**Checking the re-price claim.** Take the canonical pair after an honest 1e18 sUSDS / 1e18 phUSD first LP. At the live price (about 0.916 USDS per phUSD and about 1.11 USDS per sUSDS), the fair ratio is about 0.82 sUSDS per phUSD, so the 1:1 pair overprices phUSD by about 21%.

- **Re-pricing costs the protocol nothing.** Moving a roughly $2 pool to the fair ratio takes a swap of a few cents. The arbitrage gain goes to whoever does the swap, and the protocol can be that party. The loss falls on the mispriced first LP, through their own input.
- **Minting in after the re-price is ordinary.** Once `totalSupply > 0`, a mint at the reserve ratio gets pro-rata LP. Protocol dilution is about $2 in $41k, and the honest LP keeps their dust share.
- **A large honest first LP changes nothing.** If the first LP put in, say, $10k at the wrong ratio, the re-pricing arbitrage is a gain to the protocol, not a loss. At the right ratio no re-price is needed at all.
- **UniPoolerV2 accepting only the canonical pair does not matter.** The pair stays usable; only the seeding contracts are bricked.

So the claim holds: no protocol asset is at risk. It needs an atomic "re-price then mint" helper, because the `PairNotEmpty` gate in the core (step 2) and the escrow is permanent once `MINIMUM_LIQUIDITY` is locked.

**Overstatement in the impact text (wording edit, no severity change).** "Permanently bricks the Balancer-exit cutover design" overstates the impact. It permanently bricks the *current seeding contracts* (core step 2, escrow `PairNotEmpty`). Completing the cutover then needs new re-price-and-mint code before the deadline, and if that slips, the post-30-Oct recovery exit takes over. Reword it accordingly.

**Disclosure.** The wont-fix disclosure is adequate. The new trigger (an honest user going through a protocol-shipped helper) is a different root-cause location from L-26's adversarial grief. Low with the existing UI-exposure trigger is correct. The one-line reserve check should land before the story-111 broadcast.

## L-04: RECOVERY branch never enables Recovery Mode. CONFIRMED Low (precondition now verified)

I could not find any Balancer V3 Vault source (`VaultAdmin.enableRecoveryMode`) in the repo's lib trees. I verified the claim empirically on the real mainnet Vault instead.

- **Test:** `yield-claim-nft/work/test/UniPoolerCutoverEscrow.fork.t.sol::test_fork_case2_pausedPoolRecoveryExitSeedsNewPooler`, fork block 26,136,000.
- **Steps:** `V3_GOVERNANCE` calls `pausePool(BPT)`. `vm.prank(address(0xA11CE))` then calls `enableRecoveryMode(BPT)`, which succeeds. `isPoolInRecoveryMode` reads true, and a RECOVERY exit of 20,401.8 BPT seeds the new pooler.
- **Command:** `forge test --match-path test/UniPoolerCutoverEscrow.fork.t.sol --match-test test_fork_case2 --threads 1 -vv`, run from `yield-claim-nft/work` with RPC from `.envrc`.
- **Result:** `[PASS] (gas: 766947)`, 1 passed / 0 failed.

So plan L38 holds for the **pool-paused** case: an arbitrary address can enable Recovery Mode with one call. The core's RECOVERY branch fails closed in simulation before step 4 runs, so nothing is stranded, and the remedy is that one call.

**Residual gap (not fork-tested).** The **Vault-paused** case (after 30 Nov) without a pool pause was not exercised. From V3 design, `enableRecoveryMode` skips authentication when *either* the Vault or the pool is paused, and `removeLiquidityRecovery` has no pause gate. I am stating that from my knowledge of V3; it was not reproduced. Balancer also commits to enabling Recovery Mode "where needed" on 30 Oct. Story 103's forced-pause fork case should cover both pauses.

**Severity.** L-04 does not rise. QA would be defensible, given a one-call permissionless remedy and fail-closed behaviour. Keep Low anyway: the shipped upstream test certifies a property that is false on mainnet, and the documented deadline fallback does not work as written.

## Other findings

- **L-03: CONFIRMED Low.**
  - Mints revert loudly; users lose gas only.
  - The owner can finish by hand with `replaceDispatcher`.
  - The defect is the missing resume path that story 103 promises, and the reorder fix is concrete.
  - No asset risk, so Medium does not apply. It is not QA either, because index 4 is bricked indefinitely if the halt happens and the owner is not aware of it.
- **L-05: CONFIRMED Low, with the post-edit framing.**
  - The impact is that an advertised route on an immutable, ownerless helper cannot be used above about $1.5k, and fixing it needs a redeploy. That is a function impairment and fits Low.
  - With the weak-minOut facet removed (user input, MR-008), it has no asset-risk basis, so it cannot go higher.
- **Q-01: CONFIRMED QA.**
  - The residue on the retired pooler is recoverable through `rescueERC20` (onlyOwner, not pause-gated).
  - The step-11 revert needs the donation to be re-enabled, and live `batchDonationSize == 0`.
  - The interim-mint window is the broadcast window, with the UI in maintenance.
  - Upgrade check: about 1,957 sUSDS accrued in 12 days, but only mints *during the broadcast window* escape the baked rescue, so the amount at stake is small and recoverable. QA stands.
- **Q-02: CONFIRMED QA.**
  - It is a spec-level grief that is weaker than the existing sync brick (9a694ae01fe1), and the current core is not griefable through the owner-BPT clause, because step 5 exits the whole owner balance.
  - It is correctly tied to story 103.
- **F-01: CONFIRMED.** The story contradicts itself against its own 10-07/10-10 amendments. This is a pure Law-2 issue, and it correctly claims no exploit.
- **F-02: CONFIRMED.** The wrong holders are on-chain fact. Apply the validity.md location edit (`story-103 text L116/L213`, fingerprint unchanged).

## Understatement sweep (Law 1)

I looked specifically for a Low that hides asset risk:

- **L-01:** Can a poisoned pair plus a hand recovery lose value? Not if the recovery uses a direct `pair.mint`. Through the Router it would seed at the griefer's ratio, but a competent owner applying the plan-L414 price check would not do that.
- **L-02:** Can the re-price leak value? No (see above).
- **Q-01:** Is the unswept sUSDS lost? No, it is recoverable.

I found no hidden asset risk. All of these findings fall under owner-controlled recovery. The open exposure is time: the 30 Oct deadline is 17 days away. If story 103 has not landed atomically by then, re-run this assessment for L-01 and L-02 together.
