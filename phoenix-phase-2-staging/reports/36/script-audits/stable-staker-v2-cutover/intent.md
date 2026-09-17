# Intent — stable-staker-v2-cutover (run-36, delta 7ac6e70..91ed727, fix wave for audit-35)

Sources @ 91ed727: `script/CutoverStableStakerV2Mainnet.s.sol` (`:preview`/`:broadcast`), `script/VerifyStableStakerV2Cutover.s.sol` (`:verify`), `scripts/patch-mainnet-addresses-stable-staker-v2.js` (`:broadcast` tail), npm L49–55.

Stories (each one glob hit, all `auto-complete` = complete, machine-approved): **093** (2420920, feb89a8), **094** (0622ec9), **095** (0f00562, 0433062), **096** (d0722f6, a2b9d75, bff40f3). 082–092 carried from runs 34/35 unchanged except where the stories below touch them. The story checklists are the acceptance criteria (no "Acceptance Criteria" heading exists).

Empirical basis: sponsor story tests (49/49 pass, `fork-logs/01`), a REAL two-leg anvil broadcast at fork block 25994908 (`fork-logs/00`–`11`), and a REAL story-096 lapsed-window path broadcast (`fork-logs/pending-path/`).

## Stated purpose — delta (story checklists authoritative)
### Story 093 (Q-06)
- [x] Conflict markers removed; `git grep '^(<<<<<<<|=======|>>>>>>>)( |$)'` over tracked non-lib files at 91ed727 returns nothing; every `server/deployments/*.json` parses.
- [x] CI step (before forge fmt/build) fails on markers and runs JSON.parse over `server/deployments/*.json`.
### Story 094 (L-09) — two broadcast legs
- [x] A broadcast that executes the minter `totalWithdrawal` ends its leg after the execute, status `awaiting_reseed`. **Real (non-preview) branch confirmed on anvil**: leg 1 = 44 txs, last = `totalWithdrawal`, no approve/noMintDeposit signed; patch tail exits 2 with the instructive LEG 1 message.
- [x] Leg 2 re-seeds the MINED R. Anvil: local-pass R 14620768299424230618909, mined R 14620769498660152819444 (+0.0012 DOLA); leg 2 logged the NOTE and deposited the mined value; OWNER DOLA back to 0 (= ownerDolaBeforeExec).
- [x] Approve `ceil(1.5R)` only when allowance < R. Live allowance is `type(uint256).max` → no approve signed (leg 2 = 21 txs). Dead code on today's state, covered by sponsor tests.
- [x] Verifier: OWNER DOLA residual equality + mined-R lower bound from summed `Transfer(0x1760→OWNER)` logs. Anvil verify: "OWNER DOLA residual 0; mined R 14620769498660152819444, transfers 1", CUTOVER VERIFIED.
- [x] NatSpec halt-point (b) and package.json comments describe the two legs.
- Story-rejected alternative accepted: option 2 (conservative tranche + sweep) — rejected because a 5 bps margin would still revert on the 0.27% skim injection. Option 1 closes the defect (verified above).
### Story 095 (L-10, Q-05, Q-04)
- [x] `CUTOVER_GAS_BUDGET = 27_000_000`, 1.2× kept. Re-measured post-094 at block 25994908 (staker counts unchanged DOLA 9 / USDC 13 / USDe 7): leg-1 binding peak **25,173,447** (USDe migrate, tx 42), leg-2 peak 1,297,700. 27M holds with 7.26% headroom (32.4M with the factor).
  - The NatSpec's "67-tx figure stays an upper bound" is not literally true across blocks (leg-1 peak is 10,346 gas above the cited 25,163,101 — state drift, 0.04%); immaterial.
- [x] Breaker paragraph rewritten: two dead windows, Phase 7 coverage gaps (Q-04), 1-based per-leg counts (44 / 21, verified against the anvil run).
- Story-rejected alternative accepted: dynamic `:preview`-computed budget (human fixed 27M). Residual (staker growth erodes headroom) is bounded: +1 USDe staker ≈ +1.15M on the peak, so ~6 extra USDe stakers before the 1.2×-inclusive requirement is binding; and a shortfall now fails mid-session only after preflight said OK, which is the same class L-10 described, but not reachable at current counts. Not refiled.
### Story 096 (L-11 — ledger wont-fix; owner chose to act; not re-escalated)
- [x] Resume past Phase 6 with a non-executable window (lapsed / not initiated / waiting / <6h left) runs 6b(a) (DOLA minting disabled), skips the rest of 6b, runs Phase 7 (V2 unpaused + registered), Phase 8 asserts the pending shape, status `awaiting_minter_window`. **Real broadcast confirmed** (pending-path P6: V2 `paused=false`, status `awaiting_minter_window`, `v2LiveBeforeMinterMove: true`).
- [x] Fresh session / halt before Phase 6 with lapsed window still hard-fails (sponsor tests).
- [x] Verifier refuses the pending state: manual `:verify` → `verify: Phase6b: PENDING … 29 per-user credits (incl. live V2 balances) verified`.
- [x] Sticky marker relaxes only the two live-balance comparisons after completion (sponsor test `pendingWithdrawThenCompleted_verifierPasses`).
- [ ] **Runbook/NatSpec claim: "the :broadcast tail stops at :verify by design: that :verify is the one that checks the per-user credits against LIVE V2 balances".** FALSE on a real chain: the patcher exits 2 on `awaiting_minter_window` before `:verify` (pending-path P7; see finding L-12).

## Declared pre-conditions (delta)
- Phase 0 window gate: `_resumePastPhase6() && !_minterWithdrawalExecutable(6h)` → defer; else `_requireMinterWithdrawalExecutable("Phase0", 6h)`.
- Broadcast: OWNER on-chain ETH ≥ 27M × price × 1.2, per leg.
- Leg 2 re-seed: `minterExecRecorded`, OWNER DOLA > ownerDolaBeforeExec, R within the source loss bound.

## Declared post-conditions (delta)
- Leg 1: progress `awaiting_reseed`; Phase 8 not run in that leg.
- Leg 2 / completion: `_doneMinterReseeded`, OWNER DOLA == ownerDolaBeforeExec (local pass) and re-checked on chain by `:verify` (mined-R bound + residual).
- Pending: Phase 8 pending shape (config recorded, registration still 0x1760, minting disabled, not executed, source still registered); status never `completed`; `:verify` reverts PENDING.
