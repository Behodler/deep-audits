# Intent — dev (phoenix-phase-2-staging run-39, src dfbf2f9, baseline run-30 @ e6eded0)

Entry point: `npm run dev` -> `./dev-local.sh` -> clean:local -> anvil (31337, --block-time 2) ->
`LOCAL_PROMO_KENDU=true forge script script/DeployMocks.s.sol:DeployMocks --broadcast --slow` ->
simulate-yield.sh -> extract:addresses -> generate:ts-anvil -> serve.

Owner ruling 2026-09-15 applies: DeployMocks is a UI-testing mock stack, so mock-vs-mainnet fidelity
findings are invalid for `dev`. The exception is story 101 (Phase 11.7), whose stated intent IS a
dress rehearsal of the mainnet cutover.

## Stated purpose (authoritative stories first; package.json comment / NatSpec are restatements)

Story documents (globbed across the whole `~/code/product-owner/stories/phStaging2/` tree, one hit each):
- 101 `auto-complete/phStaging2-Balancexit/101-deploymocks-unipooler-cutover-rehearsal.md` (auto-complete, machine-approved)
- 100 `auto-complete/phStaging2-Balancexit/100-pin-bump-balancer-mock-exits-unipooler-cutover-core.md` (auto-complete; core shared with 103)
- 089 `auto-complete/phStaging2-stable-staker-v2/089-deploymocks-sdola-mock-and-v2-dola-destination.md` (auto-complete)
- 093, 102 (auto-complete); 081 (auto-complete, dev-local.sh); 103/104/106 incomplete (forward references only)

### Story 101 — Phase 11.7 `_rehearseUniPoolerCutover` (gradeable)
- [x] Build today's index-4 stack: mint at index 4 so sUSDS accrues, authorize the deployer, `pool()` so BalancerPoolerV2 holds mock BPT. EXECUTED (20 mints, 141.34 BPT pooled).
- [x] `incrementAuthVersion()`, then core steps (story 108 order 0–12) with the PROPORTIONAL exit. EXECUTED on-chain as separate broadcast txs.
- [x] Post-state asserts: `configs(4).dispatcher == UniPoolerV2`; `hook.dispatcher() == UniPoolerV2`; reserves == seed; LP on UniPoolerV2; a test mint dispatches, wraps and accrues debt; `quotePool` + `pool()` succeeds. Asserted in simulation, and the durable parts were re-read on the broadcast chain (see side-effects.json).
- [x] Track `UniPoolerV2` and `PhusdSusdsPair`; keep `BalancerPoolerV2` tracked. Extracted as `UniPooler` and `PhusdSusdsPair` (story 102).
- [x] Placement after Phase 3.6/3.7 and before `_sweepResidualPrivileges`.
- [~] "runs the exact mainnet cutover sequence against that stack": the sequence is the same code (inherited core), but step 11 takes the donation-live branch locally (local batchDonationSize = 30), while mainnet (batchDonationSize = 0 at block 26109485) will take the WRAP branch. The audit-local mainnet-fork probe (test A) shows that the wrap branch completes on live state, so this is an observation, not a finding: it is a value divergence of the kind the owner ruling excludes.

### Story 100 — shared `UniPoolerCutoverCore` (Law-1 relevant beyond dev: inherited by 103)
- [x] Steps 0–12 in phStaging2:108 order; Balancer V3 exit interfaces declared locally; exit mode by parameter; `minAmountsOut` > 0 and within the live-share tolerance; config copied live; no Pauser calls; `seedDeadline` caller-supplied and forward-dated.
- [x] Seed deadline survives a real multi-block broadcast (dev evidence: seed mined 1,080 s after the simulation timestamp, deadline sim+3600).
- [ ] Step 2's "pair must be empty" precondition has no recovery branch. A 2-wei donate+sync by any third party on the canonical pair (which does not exist yet on mainnet and is permissionless to create) makes the core revert at step 2 permanently (fork test B). The plan (§4 lines 410–414) covers only the in-window case and a recovery helper that is not in the core. -> candidate finding DEV39-01.

### Story 089 — Phase 9.7 `_repointDolaMinterAndSya` + MockSDOLA
- [x] MockSDOLA deployed; `YieldStrategyDola` (sDOLA) / `YieldStrategyDolaLegacy` (autoDOLA) keys; V2 DOLA on sDOLA.
- [x] Minter re-registered on the sDOLA strategy; collateral moved; SYA list and withdrawer flags swapped.
- [ ] "maxMintPerDay equals its value before re-registration": asserted, but vacuous. The local value is 0 and `registerStablecoin` resets to 0, so deleting `setMaxMintPerDay` would still pass. -> DEV39-04
- [ ] "minter principal cleared from the legacy strategy" (`require(principalOf == 0)`): TRUE ONLY IN SIMULATION. On the broadcast chain, 11,999,712,006,910 wei of principal remains. -> DEV39-02
- [ ] Disclosed follow-up, unlanded: simulate-yield.sh still feeds MockAutoDOLA. Empirically inert for the live DOLA path. -> DEV39-03

### Story 081 / dev-local.sh (unchanged since baseline)
- [x] Refuse to start next to a foreign node (re-verified: second invocation exit 1 at pre-flight, before clean:local).
- [x] DeployMocks refuses a non-fresh chain (re-verified: `DeployMocks: chain is not fresh ...`).
- [ ] In-source claim "Flags are byte-identical to the start:anvil key" is false at HEAD (2 s vs 5 s, untagged 6c9416d). This is the drift ledger Q-03 111b6f04c9b7 predicted (evidence update, not a new finding).

### Untagged in-delta edits (6c9416d, 884ccf8) — no story; graded against residual-privilege intent
- [x] Antimatter phUSD mint grant asserted live in the sweep; deployer phUSD minter revoked (on-chain `(false, 1)`).
- [x] setSetAsideBufferRecipient wiring asserted (V1 then V2).
- No new residual privilege found. The retired BalancerPoolerV2's minter is set to the deployer by core step 12, by design (story 100 Concerns); owner-trusted.

## Declared pre-conditions (require before effects)
- `block.chainid == 31337`; `vm.getNonce(deployer) == 0` (fresh chain)
- dev-local.sh: port 8545 free; listener pid == own anvil; block number <= 100
- Phase 11.7: BalancerPoolerV2 at index 4; deployer holds >= 6,500 phUSD; interim sUSDS > 0 and interim mint debt > 0 (anti-vacuity gates)
- Core step 0: owner owns old pooler, hook and minter; tolerances <= 100 bps; `block.timestamp < seedDeadline <= +1 day`; every pooler revoked; index/hook/pooler cross-pointing; pool tokens == {sUSDS, phUSD}; every minAmountsOut > 0
- Core step 2: pair reserves (0,0) AND balances (0,0)
- Phase 9.7: minter DOLA on the legacy strategy; minter legacy principal > 0

## Declared post-conditions
- Core: BPT fully exited; seed exact; LP on the new pooler; reserves == seed; mintDebt == 0 after pull; hook repointed; config copied; poolers authorized; price/growth/disabled preserved; old pooler drained and paused
- `_assertUniPoolerCutover` / `_ucPostCutoverMintAndPool` (story 101)
- `_assertDolaRepoint` (story 089)
- `_sweepResidualPrivileges` end-state phUSD ACL table
- NOTE: every forge-script `require` is evaluated in the SIMULATION pass. Post-conditions over time-dependent state are not re-checked on the broadcast chain (DEV39-02 is a concrete instance).
