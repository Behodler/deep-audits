# Proposed ledger status changes — run 42 (`/audit-script phoenix-phase-2-staging dev`)

- **Run:** `phoenix-phase-2-staging-42`  ·  **src:** `d0060cb82d91f43c94c8d7f7a34fb50988957ac3`  ·  **branch:** `master`  ·  **delta:** `dfbf2f9..d0060cb`
- **Statuses changed by this run: NONE.** Every item below is a proposal. A human applies it with the `/ledger` command shown.
- All selectors are 12-hex fingerprint prefixes, which are unique in the ledger (selector rung 3, exact), so no confirmation round-trip is needed. Several of these entries have no issueId, and entry point `dev` reuses labels across runs, so **never select by label here**.
- `/ledger` has no `obsolete` status. "Close obsolete" is recorded as `wontfix` with an obsolete reason, which matches the precedent for ycn L-28.
- Fix-pending items: `fixed` may only be applied by a human. A finding that stopped tripping the scanner is not, on that alone, a verified fix.

## 1. Propose `fixed` (auditor verdict LIKELY-FIXED) — 7

### M-01 · `pps28m1` · `11311795cd60` · medium · current status `fix-pending`

- **Title:** `dev` is two concurrent shell pipelines with no anvil-ownership or genesis-freshness check: DeployMocks silently broadcasts a full rehearsal onto a pre-existing chain
- **Fingerprint:** `11311795cd60678435822a60f5df8ceb4350d465c12065ba56f7275164f3a8ee`
- **Run-42 verdict:** LIKELY-FIXED
- **Evidence:** dev-local.sh pre-flights (L50-101) + listener-pid check + nonce gate DeployMocks.s.sol:434-437. Empirical: a second ./dev-local.sh against the live stack exited 1 at the port-3001 gate; with API_PORT=3999 it exited 1 at 'something is already answering on http://localhost:8545'. Both exits happen before clean:local. Propose `fixed` (human applies).
- **Carried in:** `submissions/M-01-C2.md`

```
/ledger phoenix-phase-2-staging fixed 11311795cd60
```

### M-01 · no issueId (pre-scheme) · `a753907e2a4c` · medium · current status `fix-pending`

- **Title:** NudgeStreamer.collectNudge credits the buffer with the amount SENT, not received, against a POOLED per-token balance — one taxed token drains sibling streams and bricks batchMint for every reward token
- **Fingerprint:** `a753907e2a4c6261389ea642ede743e198b50741d4bcb43fa8bad900729174d1`
- **Run-42 verdict:** LIKELY-FIXED
- **Evidence:** lib/nft-staking/src/NudgeStreamer.sol:193-201 now credits `received = balanceOf(after) - heldBefore`, capped at amount, and reverts ZeroReceived. Snapshot taken after _settle (comment L176-183). Propose `fixed`. Ledger Q-01 d7242d7c43ac (stale NatSpec) already presumes this.
- **Carried in:** `submissions/M-01-C1.md`

```
/ledger phoenix-phase-2-staging fixed a753907e2a4c
```

### L-04 · `pps26l4` · `b8e3d59139ae` · low · current status `fix-pending`

- **Title:** The deploy script grants itself phUSD mint authority and never revokes it, while correctly revoking PhlimboV2's grant in the same run
- **Fingerprint:** `b8e3d59139aeee24bd97a6e1087c3e992ab4dee99949a7bde8c30d55ee5e84f6`
- **Run-42 verdict:** LIKELY-FIXED
- **Evidence:** _sweepResidualPrivileges (DeployMocks.s.sol:1870-1898) revokes the grant and asserts a 12-row ACL table. On chain: authorizedMinters(deployer) = (false, 1) with mintVersion 1. Propose `fixed`.
- **Carried in:** `submissions/carryover/qa-report-26.md`

```
/ledger phoenix-phase-2-staging fixed b8e3d59139ae
```

### L-02 · no issueId (pre-scheme) · `ce524709d965` · low · current status `open`

- **Title:** DeployMocks has no block.chainid guard at all, in direct contravention of the project's own CLAUDE.md, while every DeployMainnet* script carries one twice
- **Fingerprint:** `ce524709d965de786fc2b6f6a1e5d2e2139406346b8fd5f930fdabac679b36e0`
- **Run-42 verdict:** LIKELY-FIXED
- **Evidence:** DeployMocks.s.sol:433 `require(block.chainid == 31337, "DeployMocks: local only")`. Propose `fixed`.
- **Carried in:** `submissions/carryover/qa-report-21.md`

```
/ledger phoenix-phase-2-staging fixed ce524709d965
```

### (none) · no issueId (pre-scheme) · `0b497be32114` · qa · current status `open`

- **Title:** StableStaker deployed with migrator == address(0): terminal-migration path is permanently unreachable
- **Fingerprint:** `0b497be32114147aa44ea7328329eaab2f024fd22b3208804fe604b84cca86b3`
- **Run-42 verdict:** LIKELY-FIXED
- **Evidence:** V1 StableStaker migrator is now wired (setMigrator(address(migrator)) L2773, asserted L2775). V1 is retired at Phase 6.5b.
- **Carried in:** `submissions/carryover/qa-report-05.md`

```
/ledger phoenix-phase-2-staging fixed 0b497be32114
```

### L-03 · `pps28l3` · `669de8af7eb9` · low · current status `open`

- **Title:** `verify-stable-staker.sh` invokes two scripts that were moved to `script/archives/`, and the foundry.toml comment justifying the exclusion is falsified by that very reference
- **Fingerprint:** `669de8af7eb962ae5a276e5c1080b0de13af3bd44780e86b207c19b71955fc24`
- **Run-42 verdict:** LIKELY-FIXED
- **Evidence:** verify-stable-staker.sh now invokes script/interactions/StakeStableStaker.s.sol and ClaimWithdrawStableStaker.s.sol, which both exist (story-080 note at L13-15)
- **Carried in:** `submissions/carryover/qa-report-28.md`

```
/ledger phoenix-phase-2-staging fixed 669de8af7eb9
```

### L-07 · `pps28l7` · `98e727214903` · low · current status `open`

- **Title:** `server/deployments/local.json` was removed from git tracking, so `generate:ts-anvil` and `serve` now fail when run standalone
- **Fingerprint:** `98e72721490398830324ab4cb3e7f31cb746ca7bce1f3e46c92d58fc761509c1`
- **Run-42 verdict:** LIKELY-FIXED
- **Evidence:** server/deployments/local.json is git-tracked at d0060cb (git ls-files)
- **Carried in:** `submissions/carryover/qa-report-28.md`

```
/ledger phoenix-phase-2-staging fixed 98e727214903
```

## 2. Propose close as obsolete (`wontfix`, obsolete reason) — 9

### L-01 · `pps26l1` · `eda17642828a` · low · current status `fix-pending`

- **Title:** `dev` rehearses the cutover's end state but not its cutover mechanics: setDispatcher, replaceDispatcher and hook.pull() are executed zero times
- **Fingerprint:** `eda17642828a6dd3bce6890d9900add9d27a317f80b78212a30f123301d17fd4`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** The cutover rehearsal was retired by story 106 (setDispatcher/replaceDispatcher/hook.pull grep = 0 hits in DeployMocks). The class (RehearsalOmitsHighestRiskPhase) is invalid under the 2026-09-15 owner ruling, and the mainnet UniPooler cutover has executed. Propose wont-fix/obsolete.
- **Carried in:** `submissions/carryover/qa-report-26.md`

```
/ledger phoenix-phase-2-staging wontfix eda17642828a "obsolete: cutover rehearsal retired by story-106 (setDispatcher/replaceDispatcher/hook.pull = 0 hits in DeployMocks at d0060cb); mainnet UniPooler cutover executed; class ruling-invalid under 2026-09-15 UI-mock ruling (run-42)"
```

### L-01 · `pps39l1` · `9a694ae01fe1` · low · current status `open`

- **Title:** Shared UniPoolerCutoverCore step 2 has no recovery branch: a 2-wei donate+sync on the permissionless canonical sUSDS/phUSD pair makes the mainnet cutover core revert for good
- **Fingerprint:** `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** UniPoolerCutoverCore.sol moved to script/archives/helpers/ by 702a2b1 [story-107] and excluded from compilation (foundry.toml skip script/archives/**). DeployMocks references it only in a comment (L1990), and the mainnet cutover has executed. Note: the run-41 L-01 window entries (pps41l1/pps40l3) were already wont-fixed 10-19. Cross-entry caveat: run 41 (`unipooler-cutover`) recorded pps39l1 as still live in THAT entry point (re-surfaced as pps41l3); the run-41 window entries pps41l1/pps40l3 were wont-fixed 2026-10-19. This proposal is scoped to entry point `dev` only.
- **Carried in:** `submissions/carryover/qa-report-39.md`

```
/ledger phoenix-phase-2-staging wontfix 9a694ae01fe1 "obsolete for entry point dev: UniPoolerCutoverCore moved to script/archives/helpers/ by 702a2b1 [story-107], excluded from compilation, referenced by DeployMocks only in a comment; mainnet cutover executed (run-42)"
```

### L-01 · `pps27l1` · `65db3324e7d0` · low · current status `open`

- **Title:** The terminal privilege sweep bricks `npm run test:fund-user` on every fresh local chain, and the comment on the failing line still claims the deployer is an authorized minter
- **Fingerprint:** `65db3324e7d0bc49f2c26be40c067ec8d578a112a2088065f53bc726c2af42f9`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** FundTestUser.s.sol now lives only at script/archives/interactions/ and no package.json key references a fund-user script
- **Carried in:** `submissions/carryover/qa-report-27.md`

```
/ledger phoenix-phase-2-staging wontfix 65db3324e7d0 "obsolete: FundTestUser.s.sol lives only under script/archives/interactions/ and no package.json key references a fund-user script at d0060cb (run-42)"
```

### L-02 · `pps27l2` · `6af1ae30ed82` · low · current status `open`

- **Title:** The cutover rehearsal covers 1 of 5 mainnet dispatcher swaps and is not re-targetable to the other classes: `REHEARSAL_SWAP_INDEX` reads like a knob but the helper hard-codes the index-1 6-decimal Uniboost shape, so index 4 — the 18-decimal prime with the BPT custody shift — stays entirely unrehearsed
- **Fingerprint:** `6af1ae30ed82698039f24b41a9d1dc5a672bf3723ee364435c3df179457f85c5`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** _rehearseDispatcherSwap and REHEARSAL_SWAP_INDEX: 0 hits in DeployMocks (removed), and the class is ruling-invalid
- **Carried in:** `submissions/carryover/qa-report-27.md`

```
/ledger phoenix-phase-2-staging wontfix 6af1ae30ed82 "obsolete: _rehearseDispatcherSwap / REHEARSAL_SWAP_INDEX removed from DeployMocks (0 hits at d0060cb); class ruling-invalid under 2026-09-15 UI-mock ruling (run-42)"
```

### L-03 · `pps27l3` · `19e2e0c2d6a3` · low · current status `open`

- **Title:** The intermediate-window assertion pins the fail-closed premise instead of its consequence: deleting `UniboostMintDebtHook.onDispatch`'s OnlyDispatcher gate would leave the whole local rehearsal green while the property it exists to protect is gone
- **Fingerprint:** `19e2e0c2d6a35689a2216fc420de9ff53d0331ec45cec36b9ce31e8dcb85b6b9`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** _rehearseDispatcherSwap and REHEARSAL_SWAP_INDEX: 0 hits in DeployMocks (removed), and the class is ruling-invalid
- **Carried in:** `submissions/carryover/qa-report-27.md`

```
/ledger phoenix-phase-2-staging wontfix 19e2e0c2d6a3 "obsolete: _rehearseDispatcherSwap / REHEARSAL_SWAP_INDEX removed from DeployMocks (0 hits at d0060cb); class ruling-invalid under 2026-09-15 UI-mock ruling (run-42)"
```

### L-04 · `pps27l4` · `9ee101a0cc41` · low · current status `open`

- **Title:** The dispatcher swap retires a Uniboost still holding retained prime and never sweeps it — 20.03 USDC locally, a quarter of it created by the fix itself — and the mainnet twin `_swapUniboost` has the same no-sweep shape on live positions
- **Fingerprint:** `9ee101a0cc41eb9330ea64db0607f4e17afb65ce8d0afedafb497056dd080066`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** _rehearseDispatcherSwap and REHEARSAL_SWAP_INDEX: 0 hits in DeployMocks (removed), and the class is ruling-invalid
- **Carried in:** `submissions/carryover/qa-report-27.md`

```
/ledger phoenix-phase-2-staging wontfix 9ee101a0cc41 "obsolete: _rehearseDispatcherSwap / REHEARSAL_SWAP_INDEX removed from DeployMocks (0 hits at d0060cb); class ruling-invalid under 2026-09-15 UI-mock ruling (run-42)"
```

### Q-01 · `pps27q1` · `9067d8a232b5` · qa · current status `open`

- **Title:** Phase 7.6 asserts `configs` and both directions of `dispatcherToIndex` but not `tokenIdToDispatcher`, the third mapping `replaceDispatcher` repoints and the one that drives NFT metadata
- **Fingerprint:** `9067d8a232b53421317b2663c757a6b80f5dc77076d138bd691a8fcfff49f947`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** _rehearseDispatcherSwap and REHEARSAL_SWAP_INDEX: 0 hits in DeployMocks (removed), and the class is ruling-invalid
- **Carried in:** `submissions/carryover/qa-report-27.md`

```
/ledger phoenix-phase-2-staging wontfix 9067d8a232b5 "obsolete: _rehearseDispatcherSwap / REHEARSAL_SWAP_INDEX removed from DeployMocks (0 hits at d0060cb); class ruling-invalid under 2026-09-15 UI-mock ruling (run-42)"
```

### Q-02 · `pps27q2` · `e0ac78243e5f` · qa · current status `open`

- **Title:** The dormant leg mirrors mainnet's promo slot but not its address book: `local-addresses.ts` still ships a real, funded MockKendu where `mainnet-addresses.ts` ships `Kendu: 0x0`
- **Fingerprint:** `e0ac78243e5fe4b85b1d4165e2cea13c5d311f5153805bddb215b9b73a4b7644`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** _rehearsePhlimboV3Cutover: 0 hits
- **Carried in:** `submissions/carryover/qa-report-27.md`

```
/ledger phoenix-phase-2-staging wontfix e0ac78243e5f "obsolete: _rehearsePhlimboV3Cutover removed from DeployMocks (0 hits at d0060cb); class ruling-invalid under 2026-09-15 UI-mock ruling (run-42)"
```

### Q-01 · no issueId (pre-scheme) · `6537da6fb748` · qa · current status `open`

- **Title:** Migration rehearsal sizes the budget transfer as a fraction of a hard-coded CONSTANT rather than of the actual balance — moves 88.67%, not the documented 90%, and strands 345 phUSD in three untracked contracts
- **Fingerprint:** `6537da6fb7481a4c0cb2bb28d85793107a6d52bd65ee6c683d5e5db4d40004da`
- **Run-42 verdict:** OBSOLETE
- **Evidence:** _runStakerMigration: 0 hits
- **Carried in:** `submissions/carryover/qa-report-21.md`

```
/ledger phoenix-phase-2-staging wontfix 6537da6fb748 "obsolete: _runStakerMigration removed from DeployMocks (0 hits at d0060cb) (run-42)"
```

## 3. Propose `wont-fix` under the 2026-09-15 UI-mock ruling — 1

The 2026-09-15 owner ruling: `DeployMocks` is a UI mock, not a mainnet rehearsal, so rehearsal-fidelity findings against `dev` are invalid. The code is still present. Only the ruling disposes of it. The entry is `fix-pending`, so until a human runs this it stays rescanned and carried.

### L-03 · `pps26l3` · `12bcca3b617c` · low · current status `fix-pending`

- **Title:** The local chain arms a Kendu promotion that story 076 asserts must be dormant on mainnet, and never produces the dormant state the UI will actually ship against
- **Fingerprint:** `12bcca3b617c6c077babfad810a2457a1b8f3a5d352217b4acb135e8b9859e79`
- **Run-42 verdict:** STILL-PRESENT (code) / ruling-obsolete
- **Evidence:** _armLocalKenduPromotion (L3281) still arms the promo, and dev pins LOCAL_PROMO_KENDU=true. On chain: PhlimboV3.promoToken == MockKendu 0x0DCd..CD82. rootCauseClass RehearsalInvertsStatedMainnetInvariant is a rehearsal-fidelity class that the 2026-09-15 owner ruling declares invalid for dev. Recommend the human closes it wont-fix (ruling) rather than leaving it fix-pending.
- **Carried in:** `submissions/carryover/qa-report-26.md`

```
/ledger phoenix-phase-2-staging wontfix 12bcca3b617c "rehearsal-fidelity class (RehearsalInvertsStatedMainnetInvariant) ruled invalid for dev by the 2026-09-15 owner ruling: DeployMocks is a UI mock, not a mainnet rehearsal (run-42 proposal)"
```

## 4. HOLD — no command proposed for application — 1

### Q-01 · `pps26q1` · `1c98937375ad` · qa · current status `open`

- **Title:** The un-storied 'Story 079' work has no acceptance criteria anywhere to be graded against
- **Fingerprint:** `1c98937375adc20c171c86ba91246476283add1bf72736a0e945606c643d1e9e`
- **Run-42 verdict:** OBSOLETE (function) / ruling-invalid — HOLD
- **Evidence:** _rehearsePhlimboV3Cutover: 0 hits
- **Carried in:** `submissions/carryover/qa-report-26.md`

**Why HOLD:** the auditor rates this obsolete because `_rehearsePhlimboV3Cutover` has 0 hits at d0060cb. But the entry's function list (`run / _rehearsePhlimboV3Cutover / _armLocalKenduPromotion`) also names `_armLocalKenduPromotion`, which **survives** (DeployMocks L3281, still arming the Kendu promotion). A human must decide whether the 'story 079 does not exist' provenance gap still attaches to the surviving function. If it does not, close it with `/ledger phoenix-phase-2-staging wontfix 1c98937375ad "obsolete: ..."`. If it does, leave it `open`. Note that it also overlaps ledger F-03 `da94d1ba03fd` (story-provenance root), which audit 28 disclosed and kept apart.

## 5. Not proposed, but flagged for a human re-weigh

- `dcf756f7a897` (F-01 `pps28f1`, `dev` pins `LOCAL_PROMO_KENDU=true`): STILL-PRESENT, but its "dormant mainnet leg unreachable" premise is a rehearsal-fidelity argument. The human may want to weigh it against the 2026-09-15 ruling. No command is proposed.
- `1b461cb4d56c` (L-07, run 21) and `a807cc7a6699` (Q-04, run 21): NOT RE-EXAMINED. The scripts they cite (`script/interactions/TestBalancerDonation.s.sol`, `script/PreviewBatchMint40.s.sol`) appear to have moved, probably archived, so they are likely obsolete. **Unconfirmed**: verify before closing.

## 6. Ledger hygiene (not fixed by run 42; human `/ledger` or manual correction)

- **`f7de907d7981` label/severity mismatch:** label `M-02` (run 21), severity `low` (`downgradedFrom: medium`). The label is run-scoped and was left as is. Because it is Low it is carried in the QA channel (`carryover/qa-report-21.md`), as at run 39, and not as an `M-02-C<n>.md` full copy.
- **Mixed `reportPath` prefixes:** 158 ledger entries use the legacy `reports/phoenix-phase-2-staging/NN/…` form (from before the per-project layout) and 56 use `reports/NN/…`. Neither is the canonical audit-root-relative `phoenix-phase-2-staging/reports/NN/…`. Run 42 resolved the legacy form by stripping `reports/phoenix-phase-2-staging/` and wrote nothing back.
- **`entryPointBaselines.dev` key shape:** the run-42 write adds `lastRun` (as requested) and mirrors it to the legacy `lastAuditedRun` key. The prior baseline is chained under `previousBaseline`, as in every run since 21.
- **issueId-less pre-scheme entries:** the 16 run-05/run-21 `dev` entries carried this run have no issueId. This is expected and none was minted.
