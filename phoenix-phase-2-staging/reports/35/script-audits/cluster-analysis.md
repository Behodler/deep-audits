# Cluster analysis — run-35 (initiate-dola-ys-withdrawal → dola-ys-withdrawal:status → stable-staker-v2-cutover)

Source 7ac6e70. Fork: anvil at mainnet block 25990689. Nothing was broadcast to mainnet. All execution ran from `work/`, which was restored afterwards. The logs are under `fork-logs/`.

## Fork sequence achieved
| # | Step | Result | Evidence |
|---|---|---|---|
| 1 | `initiate-dola-ys-withdrawal:preview` | PASS. READBACK OK; minter P 14594.562 DOLA | 01 |
| 1b | Initiate broadcast on anvil (`--unlocked`) | Tx OK, 101,456 gas. Only 3 slots written (`withdrawalStates[DOLA][minter]`). WithdrawalInitiated emitted | 02 (+ prestate state diff) |
| 2 | Aged `initiatedAt` by 6h1m | A real 6h warp reverts the execute `InvalidDataReturned()` (fork-frozen Chainlink, verified), so the slot was aged instead, as the sponsor tests do | — |
| 2b | `dola-ys-withdrawal:status` | EXECUTABLE | 03 |
| 2c | Same, aged 75h | Status still says "cutover may broadcast now"; the cutover preview reverts on WINDOW_SAFETY_MARGIN | 04 |
| 3 | `stable-staker-v2-cutover:preview` | PASS on all phases and 11 GLOBAL_PAUSE stages; smoke tests pass; ETH_BUDGET SHORTFALL | 05 |
| 3b | `:broadcast` (anvil `--unlocked`) at the live OWNER ETH balance | Preflight refuses; 0 txs sent | 06 |
| 3c | `:broadcast` with OWNER funded to exactly 0.00792 ETH | 67 txs, 22,982,701 gas; completes with 4.7% headroom left | 07 |
| 3d | Patch script | PATCH/FILL/SAME, key-set 57 = 57 | 08 |
| 4 | `:verify` | PASS (29 per-user credits) | 09 |
| 4b | Post-cutover status | "withdrawal completed / strategy retired" | 10 |
| 4c | Initiate preview post-cutover | Reverts "strategy is paused" (fail-closed) | 10b |
| 4d | Smoke `:preview` | PASS | 11 |
| 5 | `:broadcast` with a claim-equivalent skim injected after the local pass | tx #48 noMintDeposit reverts `SafeMath: subtraction underflow`; halt with 14,593.85 DOLA on OWNER | 12 |
| 5b | Resume `:broadcast` | Re-derives R live; converges | 13 |
| 5c | `:verify` | PASS | 14 |
| 6 | Harness test: window lapse after Phase 6 | PASS (stakers frozen, resume blocked) | 16 |

## Coupling verdicts
- **initiate → cutover Phase 0 / 6b.** The coupling works as designed on real bytecode:
  - V1's exit is not gated by the pending withdrawal (Phase 6 passed with status Initiated).
  - The execute resets status to None.
  - The status script and the initiate preflight both read the retired state correctly afterwards.
- **Local pass vs mined state (the core cross-script hazard).** The cutover's first run bakes Phase 6b's R. See L-09.
  - Clean run: 0.002309 DOLA stranded on OWNER, verify green.
  - Perturbed run: halt with the collateral on the EOA; resume converges.
  - A mid-session SYA claim is the realistic trigger (claims came about every 5 days over the last 30; the last was 38.7k blocks before the fork block). Phase 6's relinquish adds ~27 DOLA of skimmable surplus mid-session, which makes a claim more attractive.
  - Also a local-pass artifact: initiate's printed timestamps (local 1789569551 vs mined 1789569586).
- **Window × halt × pause.** A halt past T0+78h after Phase 6 leaves V1+V2 paused until re-initiate + 6h (Q-06, fork-proven). A global pause during the window blocks the execute (documented). L-09(b) and L-10 are the two realistic halt sources inside the window, and they compound with this.
- **Status as go signal.** It ignores the 6h start margin and the strategy's pause flag (status Q-01). Initiate's instruction line has the same gap (initiate Q-01, a 090-vs-092 story conflict).
- **Temp.s.sol (OBS-35-I2).** Not filed under Law 3: it needs a knowing out-of-band owner action inside a window the owner opened. The "pulls V1 stakers' value" framing is overstated, since `_totalWithdraw` is pro-rata by principal. The real consequence is loss of the minter cushion for V1's exit, and only if autoDOLA is below par (it is above par at the fork block).
- **Off-chain address book.** The patch script works despite the committed conflict markers; the dev-server breakage is Q-07. The mainnet-addresses consumers switch `YieldStrategyDola` to the sDOLA strategy as story 089/092 intend.
- **Budget.** The 67-tx session exceeds the 22M constant; the binding tx is #41 (USDe migrate) at 25.16M. L-10 is an incomplete fix of L-07.

## Side-effect classification (cutover)
- **Intended:** all writes listed in `stable-staker-v2-cutover/side-effects.json`. External protocol internals (Tokemak, sDOLA, sUSDe, Curve) are touched only through the intended exits and deposits.
- **Unintended:**
  - UE-01: DOLA residual on OWNER (L-09).
  - UE-02: halt state and a dangling approval under perturbation (L-09).
- **Unintended but benign:**
  - UE-04: standing OWNER→minter approval removed.
  - UE-05: mint-window counters reset (story-acknowledged, nil at this block).
- **Value routing:** UE-03, 38.58 DOLA of surplus re-seeded as minter principal (story-intended, opportunity cost).

## Prior ledger (stable-staker-v2-cutover)
- **L-08: propose fixed.** The bound is 5 bps against 0.47 bps DOLA / 0.34 bps USDC measured.
- **Q-04: still live.** The `:broadcast` comment is unchanged; fix it together with Q-05.
- **L-07:** stays fixed; L-10 carries `incompleteFixOf`.
- **All other fixed entries:** no regression observed on the fork.

## Not re-verified empirically
- The DOLA-mint-before-disable trigger for L-09(a). There were 0 DOLA mints in the last 30 days, so the mechanism was shown with price drift only.
- A Tokemak valuation down-step as the trigger for L-09(b). The skim was used instead.
- Live-bytecode equality for 0x1760, the minter and SYA (Etherscan-unverified; selector and behaviour corroborated on the fork only).
