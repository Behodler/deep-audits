# Cluster analysis — run 36 (fix wave for audit-35, stories 093–097)

Chain block for live reads: 25994830. Fork block for both real anvil broadcasts: 25994908. The `src` pin is 91ed727, executed from `work/` (clean at 91ed727). All logs are under `fork-logs/`. The driver scripts (`drive.sh`, `drive-pending.sh`, `gas.js`) sit beside the logs and are audit harness, not sponsor code. Mainnet was never broadcast to.

## Verdicts on prior entries (graded against the stories)

| Entry | Ledger | Verdict | Evidence |
|---|---|---|---|
| L-09 `78cb5942` | fix-pending | **FIXED (propose fixed)** | Real two-leg anvil broadcast. Leg 1 is 44 txs and ends at `totalWithdrawal`; status `awaiting_reseed`; the tail exits 2 with the instructive message. Local-pass R was 14620768299424230618909 and mined R 14620769498660152819444. Before story 094 the 0.0012-DOLA difference would have been stranded on OWNER. Leg 2 re-seeded the mined R, OWNER DOLA went back to 0, and `:verify` passed with residual 0 and mined R taken from 1 Transfer log. The sponsor's skim-injection test (mined R < local R) passes. |
| L-10 `72e528c8` | fix-pending | **FIXED (propose fixed)** | Re-measured after story 094 on anvil at 25994908, staker counts unchanged at 9/13/7. Leg-1 binding peak is 25,173,447 and leg-2 is 1,297,700, so 27M leaves 7.26% headroom (7.2M with 1.2×). Tx counts 44/21 match the runbook. Story 095 rejected the dynamic budget; see below. |
| Q-05 `df5f14ba` | open | **FIXED (propose fixed)** | The breaker paragraph names both dead windows and the Phase 7 coverage gaps. Per-leg 1-based counts were checked against the anvil run: V1 window at txs 1→2; autoDOLA setPauser/unregister at leg-2 txs 11→12. |
| Q-04 `a6295695` | fix-pending | **FIXED (propose fixed)** | The doc overclaim (halt 5) is corrected in `//stable-staker-v2-cutover:broadcast` and the NatSpec. The probe hardening was worded "Optionally" in the run-34 recommendation, and story 095 did not take it up. The existing probe already asserts that every *registrant* is paused. The uncovered case is exactly the documented unregistered gap. No residual hazard beyond what is now documented. |
| Q-06 `9c4e21bb` | open | **FIXED (propose fixed)** | At 91ed727 the marker `git grep` over non-lib files is empty, every `server/deployments/*.json` parses, and a CI step runs before fmt/build. |
| status Q-01 `8633815e` | open | **FIXED (propose fixed)** | Phase strings follow the story. At every anvil stage (WAITING, START_OK, expired, none) the status output agreed with the cutover's actual gate. The last-6h and paused cases are covered by sponsor tests (pass). The copy-with-drift-test was accepted (below). The PHASE_NONE override exclusion was accepted: initiate's preflight `require(!strategy.paused())` blocks the only follow-on action. |
| initiate Q-01 `4cdafc61` | open | **FIXED (propose fixed)** | The margin line, start deadline, LOCAL-PASS ESTIMATE labels and status pointer are printed. Estimate vs mined was 1789619459 vs 1789619475. Story 090's AC text is still unedited; that is a PO task outside the repo, not a code defect. Both Q-01 entries still need issueIds (ledger task). |
| L-11 `e6e1f293` | wont-fix | **Not re-escalated** (owner chose to act via story 096) | The fix works on a real broadcast: V2 was unpaused on the lapsed resume and the verifier refuses the pending state. The new code introduces one defect: **L-12** (below). |

## Story-rejected mitigations: accepted, and why

- **094, option 2 (conservative tranche + sweep): accepted.** Option 1 fully closes both L-09 branches, as the real broadcast above shows. The 1.5R approve is the human's headroom decision, and it is harmless: `noMintDeposit` is onlyOwner and pulls from msg.sender. On today's state it is dead code, because the allowance is max.
- **094, mined-R sourced from summed logs (OBS-36-C04): no finding.** The sum can only tighten the lower bound, so a false PASS is impossible. An over-deposit is caught separately by the residual equality. A false FAIL requires an OWNER-originated DOLA outflow from 0x1760 (`emergencyWithdraw`/`withdrawAsOwner` are onlyOwner). That failure is loud and fully under owner control. A double execute is impossible.
- **095, dynamic `:preview` budget: accepted.** It was re-measured after 094 with 7.26% raw headroom. Each extra USDe staker costs about 1.15M, so around 6 more stakers fit before the 1.2×-inclusive requirement binds. The NatSpec already tells the operator to re-derive if staker counts grow. The claim that the "67-tx figure stays an upper bound" is 10,346 gas short at this block (state drift), which is immaterial.
- **097, copied constant + drift test instead of an import: accepted.** The drift guard is a non-fork test that runs in CI and passes.
- **097, no paused override on PHASE_NONE (I1/S1): accepted.** It cannot mislead an operator into a bad initiate, because initiate reverts on a paused strategy.

## Leads checked with no finding

- **C05 (collateral on OWNER between legs, real leg-end branch).** The real non-preview branch now has empirical coverage: 44 txs, `vm.stopBroadcast` ends the leg cleanly, and forge exits 0. Leg 2 is idempotent and state-gated. A halt *at* the execute (pending-path P3) left the status as `awaiting_reseed` although the execute reverted, because the status is written in the local pass. That is harmless: forge exits 1, so the `&&` tail never runs, and the resume re-derives from chain and converged. It is informational. Between legs, about 14.6k DOLA sits on the trusted OWNER EOA for operator latency. The story chose this knowingly, and it is not a finding.
- **Anvil caveat for any future rehearsal.** The DOLA Chainlink round must stay fresh for the whole session. At 25994830 it had about 6 minutes left, and the execute reverted `InvalidDataReturned()` on the non-updating fork (attempt 1, archived). On mainnet the feed heartbeats, so there is nothing to file.
- **OWNER ETH** is 0.006425 ETH against 0.00972 ETH required. This is the L-07 preflight working as designed, per the run-34 precedent. It is not a finding.

## Ordering and completeness

The happy path runs initiate → 6h → preview → leg 1 → leg 2 → patch → verify → preview. It converged end to end on the fork, and the post-cutover status reads "none pending". The 096 alternative path (halt at the execute → lapse → resume) also converged into `awaiting_minter_window` with V2 live. Its only gap is L-12.

## New candidate findings

- **L-12 (Low, cutover).** On the pending path the `:broadcast` tail exits 2 at the patcher. `:verify` (with the live V2 balance checks the completed verifier later skips) and `:preview` are never chained, and `mainnet-addresses.ts` stays at 0x0 while V2 is live. The recommendation is an `awaiting_minter_window` patcher branch that fills V2/Antimatter only and exits 0, or instructs a manual `:verify` immediately, plus a guard test. See `candidate-findings.json`.
