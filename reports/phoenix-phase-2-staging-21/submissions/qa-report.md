# QA Report — phoenix-phase-2-staging (script audit, entry point `dev`)

**Project:** phoenix-phase-2-staging
**Commit:** `3fb4e34`
**Run:** `reports/phoenix-phase-2-staging-21/` (run-21, `/audit-script`)
**Entry point:** `dev` (npm script `dev`; forge target `script/DeployMocks.s.sol`)
**Story scope:** story-073 (related: story-072)

This is the single QA/Low submission bundle for run-21. High/Medium findings are filed
individually as `submissions/M-01.md` and `submissions/M-02.md`. Law-2 spec-conformance
findings are indexed in `submissions/spec-conformance.md`; see **Faithfulness routing** below —
routing is preserved here, not flattened.

## Counts

| Bucket | Count |
|---|---|
| Low (`L-01`…`L-09`) | 9 |
| QA (`Q-01`…`Q-04`) | 4 |
| Centralization (`C-XX`) | 0 |
| **This run's total in this bundle** | **13** |
| Carryover from prior audits (separate label sequence, not counted above) | 1 |

## Automated QA/gas report (4naly3er) — absent by design

No 4naly3er report was produced for this run and none is attached. Run-21 is a **script audit**
scoped to one npm entry point (`dev`) and its transitive closure, not a whole-submodule contract
sweep, so the automated SAST/gas sweep 4naly3er provides was not run. Its absence is recorded
here rather than represented by a fabricated appendix. If a full-project baseline is wanted,
run `/full-audit phoenix-phase-2-staging` and take the 4naly3er appendix from that run.

## Faithfulness routing (Law 2) — preserved, not flattened

Per `findings/spec-conformance.md`, five findings in this run carry `F-` labels. Their routing
is reproduced verbatim below and is authoritative over this bundle's ordering:

| F-label | Run label | Severity | Routing |
|---|---|---|---|
| **F-01** | L-07 | low | PRIMARY — home is `submissions/spec-conformance.md` |
| **F-02** | L-08 | low | PRIMARY — home is `submissions/spec-conformance.md` |
| **F-03** | Q-04 | qa | PRIMARY — **QA severity but owner-visible, NOT bundled** |
| **F-04** | L-09 | low | PRIMARY — Law-1 story-unsafe escalation, home is `submissions/spec-conformance.md` |
| **F-05** | L-02 | low | **CROSS-REFERENCE ONLY — primary home stays the QA/Low bundle; not double-counted** |

L-07, L-08, L-09 and Q-04 appear in this bundle **for completeness of the Low/QA record only**;
their primary home is the spec-conformance report and they must be read there. Q-04 in particular
is flagged in the routing index as *"PRIMARY — QA severity but owner-visible, NOT bundled"* — that
caveat is carried here verbatim rather than silently absorbed, and the QA bundle does not claim
custody of it. L-02 is the one `F-` finding whose primary home **is** this bundle.

Severity totals for the run (0 High / 2 Medium / 9 Low / 4 QA = 15) do not double-count F-05/L-02.

---

# Low Risk Findings

### [L-01] `progress.31337.json` is written with a hard-coded `deploymentStatus: "completed"` during forge's local-execution phase, before any transaction is broadcast <!-- id: pps21l1 -->

**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol` — `_writeProgressFile`, L1918–L1945
**Entry Point:** `dev`
**Source ID:** `DEV-04`
**Fingerprint:** `1e8cc0dc58ba0ecbe43faf12ea343e3d6eb784c36d3ad2b0141668e33777871e`
**Propagation:** PROPAGATES-TO-MAINNET (as a pattern — this shape has already poisoned three committed mainnet progress files)

**Description**

`_writeProgressFile()` emits `"deploymentStatus": "completed"` as a string LITERAL (:1922), derived from nothing, and is called after `vm.stopBroadcast()` — i.e. during forge's local execution pass, before the broadcast begins. The file also hard-codes `"chainId": 31337` (:1919) rather than reading `block.chainid`, and hard-codes its own output path (:1943). It contains no timestamp and no deployer field, so a stale file is byte-indistinguishable from a fresh one.

**Impact**

Benign in isolation on anvil — DeployMocks never reads a progress file (no `vm.readFile`/`parseJson` anywhere) and `clean:local` deletes it first, so there is no resume consumer to mislead. It is NOT benign as a pattern: `package.json`'s `//uniboost-cutover:resume` doc comment records this exact shape already producing three committed `progress.uniboost-cutover.1.POISONED*.bak` files on mainnet, where a crashed broadcast left a file positively asserting completion. Combined with the total absence of a chain-id guard (DEV-05 / L-02), a mis-pointed RPC would produce a progress file that positively asserts it is anvil output.

**Recommended Mitigation**

For the mainnet port, do not inherit this. Use `DeployMainnetUniboostBatchMinters.s.sol:214`'s `_isDeployed` (which additionally requires `a.code.length > 0`) as the source of truth for resume, and treat the progress file as advisory. Locally, at minimum read `block.chainid` rather than hard-coding 31337, and add a timestamp so staleness is detectable.

---

### [L-02] `DeployMocks` has no `block.chainid` guard at all, in direct contravention of the project's own CLAUDE.md, while every `DeployMainnet*` script carries one twice <!-- id: pps21l2 -->

**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol` — `run`, L290
**Entry Point:** `dev`
**Source ID:** `DEV-05`
**Fingerprint:** `ce524709d965de786fc2b6f6a1e5d2e2139406346b8fd5f930fdabac679b36e0`
**Faithfulness:** **F-05 — CROSS-REFERENCE ONLY.** Primary home is **this** QA/Low bundle; listed in `submissions/spec-conformance.md` so the story-level deviation is visible to the owner, but **not counted twice** in the severity totals.
**Propagation:** LOCAL-ONLY (the guard's absence is the finding; the port must add one)

**Description**

Line :290 merely LOGS the chain id. There is no `require(block.chainid == 31337)` anywhere in the 1946-line file. All seven `DeployMainnet*` scripts carry `require(block.chainid == 1)`, most of them twice (`setUp` + `run`). The project's own CLAUDE.md is explicit: *'Anvil may relax these checks for local iteration, but the relaxation must be gated behind an explicit `block.chainid == 31337` branch and clearly commented — never share an unsafe default code path between local and real networks.'* The same file also lists *'Mock contracts with unlimited minting / Default Anvil private keys / Unrestricted permissions / Simplified initialization'* under *'Local Development Only — NEVER deploy these configurations to Sepolia or Mainnet.'*

Story 073's own line 66 states *'No mainnet contact of any kind. Everything here targets chainId 31337'* as a flat property; nothing in `DeployMocks.s.sol` enforces it (the F-05 cross-reference).

**Impact**

Story 073 enlarges the ungated surface: unrestricted `MockKendu.mint`, `phUSD.setMinter(deployer, true)` granted at :1648 and :1731 and never revoked (verified live: `authorizedMinters(deployer) == (true, 1)` after the run), the 300-ETH `WETH9.deposit` at :1460, real `PhusdStableMinter.mint` calls in Phases 9/9.5/9.55/9.6, and the entire destructive V1-staker teardown (pause + pauser repoint to an EOA + unregister from the global Pauser). The only thing preventing this script from running against a non-anvil RPC is the operator typing the right `--rpc-url`. This is a footgun in the Law-3 sense: a competent non-malicious operator would be surprised that the one script in the repo containing every unsafe local relaxation is also the only one with no chain gate.

**Recommended Mitigation**

Add `require(block.chainid == 31337, "DeployMocks: anvil only")` in `run()` before `vm.startBroadcast`. Independently, revoke the two `phUSD.setMinter(deployer, true)` grants at the end of the run and post-assert `authorizedMinters(deployer).canMint == false`, so the port inherits a revoke-and-assert habit rather than a standing grant.

---

### [L-03] `mainnet-addresses.ts` carries `0x0` placeholders for `Kendu` and `NudgeStreamer` that are type-indistinguishable from real addresses <!-- id: pps21l3 -->

**Location:** `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts` L64–L131 (data file) + `server/generate-ts-addresses.js:generateInterfaceFile`
**Entry Point:** `dev`
**Source ID:** `DEV-06`
**Fingerprint:** `3177eed94ecb62181138179a2d2c1e1c9be6830b111ba69f2f0a1bd483b93237`
**Propagation:** PROPAGATES-TO-MAINNET

**Description**

`generate-ts-addresses.js` regenerates `addresses.ts`'s `ContractAddresses` interface from `local.json` — i.e. from ANVIL data — emitting `${name}: string;` for every one of the 57 keys, all required, all plain `string`. The hand-maintained `mainnet-addresses.ts` is annotated `: ContractAddresses`, so a purely local mock addition forces a placeholder into the mainnet address book. Story-073 commit `d241e61` did exactly that for `Kendu` (:64) and `NudgeStreamer` (:131), both `0x0000…0000`. Nothing in the type system, the file, or the :3001 API distinguishes a placeholder from a real address.

**Impact**

A mainnet script sourcing `NudgeStreamer` or `Kendu` from this file gets `address(0)`. IMPORTANT CORRECTION to the prior framing: this does NOT produce a silent mis-wire on the donor path — all six donors reject `setNudgeStreamer(address(0))` explicitly, and `setNudgeTokenWhitelist(address(0), true)` reverts `BatchMint__ZeroNudgeToken`, so those legs fail LOUDLY at deploy time. The one silent consumer is `BatchNFTMinterMultiToken.setNudgeStreamer`, which has no guard (see DEV-03 / `submissions/M-02.md`). The residual risk is therefore (a) that one silent leg and (b) a general operator-trust problem: the file's zero addresses read as data, not as 'not yet deployed'.

**Recommended Mitigation**

Introduce a branded or optional type for not-yet-deployed entries (e.g. `NudgeStreamer?: string` or a `type NotDeployed = "0x0"` union) so the compiler distinguishes them, or split the interface into a mainnet-required core and an anvil-only extension so local mock additions stop type-gating the mainnet address book. At minimum, add a runtime guard in any mainnet script: `require(addr != address(0), "<name> not deployed")` at the point of read.

---

### [L-04] `mainnet-addresses.ts` comments describe three real, non-zero mainnet addresses as "not yet deployed / zero placeholders", inverting exactly the distinction the mainnet port depends on <!-- id: pps21l4 -->

**Location:** `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts` L136–L145 (data file)
**Entry Point:** `dev`
**Source ID:** `DEV-07`
**Fingerprint:** `dcce8f512418ce0b422b63f812f5a3b4a1d0a02dfa56f8694188bf229f536b75`
**Propagation:** PROPAGATES-TO-MAINNET

**Description**

The comments at :136 and :142 read *'NudgeRatchet dispatcher + its mint-debt hook — not yet deployed on mainnet (story 068). Zero placeholders so this file still satisfies the ContractAddresses interface'* and *'Dedicated NFTStaker … not yet deployed on mainnet (story 068)'*. The values beneath them are real, non-zero, deployed mainnet addresses: NudgeRatchet `0xd4ea91f6096A75a1c34A3c25D7725dE1f5c49f68`, NudgeRatchetMintDebtHook `0x09AceB96337df1316e0D2d7EEEa44d754D1f8d05`, RatchetNFTStaker `0x299b0071def42d35eaf5ea24cc0a71cf10655a64`, RatchetBatchNFTMinter `0x81896f48a95abea255cd38a3010e985b6051a1c7`.

**Impact**

Seventy lines above, two entries in the SAME file genuinely are zero placeholders (DEV-06 / L-03). An operator reading this file to decide what still needs deploying gets the answer exactly backwards for four entries. Given the stated next step is a hand-written differential mainnet script that must source live addresses from this file and distinguish deployed from not-deployed, this is the single most decision-relevant piece of misinformation in the address book. It is also a Law-3 footgun: the comment is the artifact a competent operator would trust.

**Recommended Mitigation**

Correct the four comments to record the actual deployment dates and the story that shipped them. Adopt a single, machine-checkable convention for 'not yet deployed' (see DEV-06 / L-03) so a comment can never contradict a value. Consider a lint/CI check asserting that any entry commented 'not yet deployed' holds `address(0)` and vice versa.

---

### [L-05] `extract-addresses.js` strips a leading `Mock` before every drop-list and rename, and writes the result with no collision guard <!-- id: pps21l5 -->

**Location:** `lib/phoenix-phase-2-staging/server/extract-addresses.js` — `extractAddresses`, L107–L144
**Entry Point:** `dev`
**Source ID:** `DEV-08`
**Fingerprint:** `4c3e1fb7f2d351b073354ce4f7df8b8ac3bbb9313e8d3d6f1a30e8eee2f3f5ca`
**Propagation:** PROPAGATES-TO-MAINNET (the interface it generates gates the mainnet address book)

**Description**

`const displayName = name.startsWith('Mock') ? name.slice(4) : name;` (:107) is a blind 4-character slice applied BEFORE the `DROPPED_CONTRACT_NAMES` check (:110), the UniV2-backing drop (:116), the V1-NFT drop (:122) and the V2→base rename (:137–141). The final write at :144 is an unguarded assignment with no duplicate detection. Separately, three mocks bypass the strip entirely because they are tracked under an already-stripped key (`MockUSDe` as `USDe` :327, `MockSUSDe` as `SUSDe` :333, `MockMarketAMMAdapter` as `USDeAMMAdapter` :446), so the file carries two conventions for the same job.

**Impact**

Two effects. (1) Nothing downstream marks a mock as a mock — verified on the live run: `local.json`, `addresses.ts`, `local-addresses.ts` and the :3001 API contain ZERO keys beginning with `Mock`; `MockPhUSD` is served as `PhUSD`, `MockKendu` as `Kendu`, `MockAutoDOLA` as `AutoDOLA`. A UI or operator reading the address book cannot tell a 22-line stub from the real Balancer router. (2) The missing collision guard is a latent silent-clobber: a future contract tracked as `MockNFTMinterV2` would strip to `NFTMinterV2`, hit the V2 rename, and overwrite the REAL `NFTMinter` key with no error; one tracked as `MockNFTMigrator` would be silently dropped. No collision exists today (verified across all 99 track keys), but the mainnet key set is hand-maintained and must mirror this generated interface exactly, so a silent overwrite points the UI at the wrong contract.

**Recommended Mitigation**

Add a duplicate-key assertion before the write at :144 (`if (extracted.contracts[displayName]) throw new Error(...)`). Move the `Mock` strip AFTER the drop-lists and rename so it cannot interact with them. Consider emitting an `isMock: true` flag on stripped entries so the UI and the :3001 API can surface the distinction rather than erasing it.

---

### [L-06] `DeployMocks` asserts none of story 073's headline stream state, and the one probe that covers it is vacuous by construction <!-- id: pps21l6 -->

**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol` — `_deployStreamerAndBatchMinter` / `_seedNudgeStream`, L1617–L1664
**Entry Point:** `dev`
**Source ID:** `DEV-09`
**Fingerprint:** `c76a8f9f94795987c0d2aa5626c69a8afc430b24423cf3c853b9199022e4e9d1`
**Story:** story-073
**Propagation:** LOCAL-ONLY

**Description**

The script's 17 `require`s include no post-condition on `streams(batchMinter, token).duration == LOCAL_STREAM_DURATION`, on any buffer being non-zero, or on `pendingStream` accruing — the three facts story 073 exists to establish. Of the seven `setNudgeStreamer` calls only the SYA leg is post-asserted (:1129). The one probe touching stream state (:1661/:1664) runs solely against `MockKendu` and `MockPhUSD`, both fee-free by construction, so it cannot fail (see DEV-01 / `submissions/M-01.md`).

**Impact**

The story's reported outcome rests on `console.log` output rather than on-chain assertions, so a regression in the wiring would produce a green run. NOTE IN MITIGATION: the author's technical reason for not asserting accrual in-script is sound and documented at `script/interactions/TestNudgePayout.s.sol:157-168` — a forge script's `require`s all execute in the simulation pass where every statement shares one block timestamp, so `pendingStream` reads 0 there regardless of the live chain. This is a genuine tooling constraint, not negligence. The gap is therefore in the RUNBOOK, not the script: nothing in the `dev` chain performs the out-of-band verification the author says is required.

**Recommended Mitigation**

Add the out-of-band verification to the `dev` chain as a scripted step (a `verify:streams` npm entry doing the `cast` reads and failing non-zero), so the property is enforced rather than documented. Post-assert all seven `setNudgeStreamer` calls, not just SYA. The same verification step is required in the mainnet runbook — see `differential-gap.md` §4.5.

---

### [L-07] `test:balancer-donation` is ticked twice as the index-4 streamer regression test, but the script was never modified by story 073 and cannot exercise the streamer at all <!-- id: pps21l7 -->

> **Faithfulness routing: F-01 — PRIMARY home is [`spec-conformance.md`](./spec-conformance.md).**
> Reproduced here for completeness of the Low record only. Law 2 requires this deviation to be read
> at honest severity in the spec-conformance report, not buried in the QA bundle.

**Location:** `lib/phoenix-phase-2-staging/script/interactions/TestBalancerDonation.s.sol` — `run`, L129–L135
**Entry Point:** `dev`
**Source ID:** `FAITH-001`
**Fingerprint:** `1b461cb4d56c1607982164ffdbc7af435af24483c3d17a37eb1c508450e5c487`
**Story:** story-073 (lines 505, 538, 539)
**Propagation:** LOCAL-ONLY-BUT-MASKS-MAINNET-RISK

**Description**

`script/interactions/TestBalancerDonation.s.sol` is not touched by any of story 073's three commits (`3fb4e34`, `d241e61`, `c054833`); `git log` shows its last modification is `4c5c3cd [story-070]`. Checklist lines 505 and 539 are nonetheless ticked, 505 asserting that every `batchMint` call site found in preflight was updated and 539 asserting that `test:balancer-donation` passes *'after their batchMint call sites are updated'*. The script survives unmodified only because it never calls `batchMint`: grep confirms it contains no `batchMint`, `collectNudge` or `nudgeStreamer` reference. Instead it hand-rolls the donation route — :129 `psm.buyGem(batchNFTMinterAddr, gemAmt)` — and asserts `require(usdcDelta == gemAmt, "donation USDC mismatch")` at :135 against the BATCH MINTER's USDC balance. Post-story-073, the real index-4 donation routes USDC into the NudgeStreamer via `collectNudge` (`DeployMocks.s.sol:779-784`), not to the batch minter.

**Impact**

A green `npm run test:balancer-donation` is consistent with the index-4 streamer being entirely unwired, so it proves nothing about the repair story 073 exists to deliver — while story line 538 explicitly directs the reader to treat this family of smoke tests as *'the direct regression test for the streamer-unset breakage'*. The aggravating factor is which leg is masked: index-4 is the ONE leg where the pre-story breakage was SILENT, because `_dispatch`'s try/catch swallows the revert inside `_psmDonate` and the mint still succeeds (stated verbatim at `DeployMocks.s.sol:779-781`). The leg with no natural alarm is therefore the leg whose designated regression test cannot fail for the relevant reason. Story 072 inherits the same index-4 cutover and would inherit this test as its evidence of repair.

**Recommended Mitigation**

Either (a) rewrite `TestBalancerDonation.s.sol` to drive `BalancerPoolerV2`'s OWN dispatch path end-to-end and assert on the NudgeStreamer buffer delta for `(batchNFTMinter, USDC)` — i.e. assert the thing the story repaired — or (b) untick lines 505 and 539 as they pertain to this script and record in Autonomous Decisions that `test:balancer-donation` is a PSM-route smoke test that does not cover the streamer leg. Do not leave it ticked as-is. Additionally, add the index-4 case to the story-072 feedback list with the explicit instruction that the assertion must be on the streamer buffer, not the batch minter's balance, since the cutover reproduces this topology on mainnet.

---

### [L-08] Checklist line 544 is ticked certifying a four-clause, seven-leg on-chain confirmation, of which one clause and one leg are actually asserted <!-- id: pps21l8 -->

> **Faithfulness routing: F-02 — PRIMARY home is [`spec-conformance.md`](./spec-conformance.md).**
> Reproduced here for completeness of the Low record only.

**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol` — `run` (story-073 Verification checklist line 544), L889–L1129
**Entry Point:** `dev`
**Source ID:** `FAITH-002`
**Fingerprint:** `daab9e86d033b10b13ecaa02bfa9bd6ece7e93ed412ea4a16b238fa78430d63b`
**Story:** story-073
**Propagation:** LOCAL-ONLY
**Confidence caveat:** Story acceptance criteria are NON-FINAL — story 073 moved from `review/` to `complete/` mid-run and still carries an embedded `Review Status: ISSUES_FOUND`; story 072 is in `incomplete/` with line 514 unticked. Recorded as confidence, NOT as severity inflation.

**Description**

Story 073 Verification line 544 is ticked and certifies four clauses: `configs(1..5,7)` resolve as expected; index 7 is a NudgeRatchet; all six donors' `nudgeStreamer()` return the streamer; and the three `UniboostStaker*` keys point at V2 instances holding the migrated totals. In source, only the second has an assertion — `require(ratchetIndex == 7, "NudgeRatchet must occupy dispatcher index 7")` at `DeployMocks.s.sol:889`. The six-donor clause spans seven `setNudgeStreamer` calls of which exactly one, the StableYieldAccumulator leg at :1129, is post-asserted. The `configs(1..5,7)` and `UniboostStaker*`-hold-V2 clauses have no assertion at all, and no out-of-band evidence is recorded for them anywhere in the story — unlike Autonomous Decision #8, which moves the stream-accrual check out of band explicitly and for a documented technical reason.

**Impact**

The story's evidence trail over-states what was confirmed by three clauses out of four and by six `setNudgeStreamer` legs out of seven. Because line 544 is the story's ONLY end-to-end wiring confirmation, a regression in dispatcher configuration, in any of the five unasserted donor streamer legs, or in the `UniboostStaker*` V2 repointing would leave the checklist reading as fully confirmed. This is the second instance in one story of the class the story's own review flagged as HIGH Issue 1 (*'Checklist line 537 is ticked but has no implementing code'*), which makes the checklist's overall evidentiary value the real finding.

**Recommended Mitigation**

Either implement line 544's clauses as script post-conditions — assert `configs(1..5,7)` resolve, assert all six donors' `nudgeStreamer() == streamer` (the seven-leg fix DEV-09 / L-06 also asks for), and assert each `UniboostStaker*` key resolves to a V2 instance with the expected `totalStaked` — or untick line 544 and record the `cast` transcript that discharges it, as AD#8 does for stream accrual. Do not leave it ticked without either. Process-level: before `/set-complete`, require every ticked Verification line in story 073 to carry a code pointer or a recorded transcript; the reviewer found one instance of this class and there are at least two.

---

### [L-09] Both stories instruct whitelisting Kendu on the shared multi-token batch minter while the only two artefacts that could prove Kendu is not fee-on-transfer are respectively vacuous and undone <!-- id: pps21l9 -->

> **Faithfulness routing: F-04 — PRIMARY home is [`spec-conformance.md`](./spec-conformance.md)**
> (Law-1 story-unsafe escalation). Reproduced here for completeness of the Low record only.

**Location:** `lib/nft-staking/src/NudgeStreamer.sol` — `registerStream` / `collectNudge` (story-sanctioned KENDU whitelist), L149–L150
**Entry Point:** `dev`
**Source ID:** `FAITH-L1-001`
**Fingerprint:** `acabc052baaa956e35d5f668f303ce40f244c0778b8154f71ff318ad46c74709`
**Story:** story-072 (lines 292, 458–463, 469, 514) / story-073 (line 503, 496, 540)
**Propagation:** PROPAGATES-TO-MAINNET
**Confidence caveat:** Story acceptance criteria are NON-FINAL — story 073 carries `Review Status: ISSUES_FOUND`; story 072 is `incomplete/` with line 514 unticked. Recorded as confidence, NOT as severity inflation.

**Description**

Story 072 (lines 292, 522) and story 073 (Change 2, line 503) both instruct `setNudgeTokenWhitelist(KENDU, true)` on the shared `BatchNFTMinterMultiToken`, while `NudgeStreamer.collectNudge` credits `s.buffer += amount` unmeasured against pooled per-token custody (the DEV-01 defect, `NudgeStreamer.sol:149-150`, filed as `submissions/M-01.md`). Story 072 is aware and installs the correct guard at lines 458–463 — *'If Kendu taxes transfers, it must not be whitelisted … The dry run must transfer a non-zero Kendu amount through collectNudge and assert the received balance equals the sent amount before this goes to broadcast'* — but its implementing Preflight line 514 is UNTICKED, so the real-token round-trip has not been performed. The apparent local substitute, story 073's `_seedNudgeStream` (`DeployMocks.s.sol:1645-1666`), asserts `require(received == amount, "nudge seed token is fee-on-transfer: streamer received < sent")` at :1661 — but against `MockKendu`, which story 073 line 496 itself defines as having no transfer fee. It proves a mock is fee-free and is vacuous as evidence about the real Kendu Inu at `0xaa95f26e30001251fb905d264aa7b00ee9df6c18`.

**Impact**

No armed path in the configuration the stories specify: story 072 line 469 registers a stream for USDC only and leaves phUSD/Kendu whitelisted-but-unregistered, so `collectNudge` is never called on Kendu, no Kendu buffer exists, and `pullPendingStream` no-ops on it. The residual is a latent arm-switch. One later `registerStream(newBM, KENDU, DURATION)` — routine-looking, the ordinary way to enable a reward slot, with no fee-on-transfer probe at that admission point and no re-review implied — arms DEV-01's pooled-custody drain against the LIVE USDC buffer: a taxed Kendu donation over-credits its buffer relative to custody, the shortfall is settled out of the shared per-token balance, and because `batchMint` loops `pullPendingStream` over the entire `getNudgeTokens()` whitelist inside one transaction, the revert takes down minting for EVERY reward token including USDC. The operator's evidence points the wrong way: a green `deploy:local` displays an FoT assertion passing, which is positive reason not to run story 072's line 514.

**Recommended Mitigation**

BEFORE the story-072 broadcast, discharge line 514 for real: round-trip a non-zero amount of the actual Kendu token at `0xaa95f26e30001251fb905d264aa7b00ee9df6c18` through `collectNudge` on a mainnet fork and assert `received == sent`. Record the transcript in the story; story 073's `MockKendu` probe does not discharge it and should be annotated to say so, since its assertion message currently reads as a general FoT guard. Structurally, move the admission check on-chain: probe for fee-on-transfer inside `registerStream` (already owner-gated and the natural admission point) so arming a taxed token fails closed rather than depending on a checklist — this is the same fix DEV-01 recommends and it closes both. Until then, do NOT register a Kendu stream, and record the whitelist-without-stream state as a deliberate, documented configuration with the arming hazard spelled out beside it.

**Reopen trigger (escalate to Medium)** — carried verbatim from the finding record:

- **Condition — ANY of:** (a) `registerStream(<any batchMinter>, KENDU, *)` is executed on mainnet — or on any chain holding a real USDC buffer — without a COMPLETED real-token round-trip against `0xaa95f26e30001251fb905d264aa7b00ee9df6c18`; (b) any second `(batchMinter, token)` pair is registered on a token that already has a registered stream, which arms DEV-01's cross-pair drain irrespective of Kendu; (c) a donor other than the USDC donors begins pushing into the streamer.
- **On trigger:** This finding becomes a live Medium instance of DEV-01 against real custody. Re-rate immediately; do not wait for the next scheduled run.
- **Blocking pre-broadcast action (mandatory):** Tick story 072 Preflight line 514 against the REAL Kendu token at `0xaa95f26e30001251fb905d264aa7b00ee9df6c18`, not against `MockKendu`. Story 073's `_seedNudgeStream` probe does NOT discharge it.

---

# QA Findings

### [Q-01] Migration rehearsal sizes the budget transfer as a fraction of a hard-coded CONSTANT rather than of the actual balance <!-- id: pps21q1 -->

**Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol` — `_runStakerMigration`, L1831–L1832
**Entry Point:** `dev`
**Source ID:** `DEV-02`
**Fingerprint:** `6537da6fb7481a4c0cb2bb28d85793107a6d52bd65ee6c683d5e5db4d40004da`
**Story:** story-073 (Autonomous Decision #4)
**Propagation:** LOCAL-ONLY (but the formula must never be ported — see `differential-gap.md` §3.1)
**Confidence caveat:** Story acceptance criteria are NON-FINAL (see L-08). Recorded as confidence, NOT as severity inflation.

**Description**

`uint256 movable = (REHEARSAL_STAKER_BUDGET * 90) / 100;` computes 90% of a hard-coded seed constant, not 90% of the staker's actual phUSD balance. Between the `topUp(REHEARSAL_STAKER_BUDGET)` at :1734 and the migration, the three seed NFT mints route through the Uniboost donation branch and the `UniboostMintDebtHook` mints additional phUSD INTO the V1 staker. That contribution is excluded from the transfer entirely. The in-source comment at :1822–1830 describes the result as *'a flat 90%'* and :1788 says it *'leaves an arbitrary 10% stranded'* — both understate the divergence.

**Impact**

Measured on the live chain: V1 actual balance 1015.014 phUSD, moved 900, so the actual fraction moved is 88.67% and the stranded residual is 115.014 phUSD (11.33%) per staker — 345.042 phUSD across the three. The post-condition at :1712 (`phUSD.balanceOf(v2) > 0`) cannot detect this: it proves non-zero, not correctly-sized. On mainnet, where the mint-debt hook has been minting into the live stakers for months, the seed constant would be an arbitrary and possibly small fraction of the real balance, so 'flat 90%' could move almost any proportion. The author explicitly disclaims the number (:1783–1789: *'Do not read this 90% as a validated answer; the rehearsal proves nothing about sizing'*) and hands sizing to story 072 as OPEN.

**Recommended Mitigation**

For the mainnet port: compute `balance - committedDebt` at execution time, or move the budget in a separate transaction after `initiateMigration` has frozen `committedDebt`. The forge simulate-then-replay defect that forced the constant does not apply on mainnet, where every `*:broadcast` npm entry uses `--skip-simulation`. Port the ORDERING finding the rehearsal exists to produce (settle+freeze before moving the budget, :1778–1781); do not port the number. Locally, either track the rehearsal artifacts or assert the residual explicitly.

---

### [Q-02] `MockERC4626Wrapper` is deployed, pre-funded with 1,000,000 mock USDC and exported to the UI as `WaUSDC`, but serves a route removed in story-034 and has zero first-party consumers <!-- id: pps21q2 -->

**Location:** `lib/phoenix-phase-2-staging/src/mocks/MockERC4626Wrapper.sol` L1–L69 (dead deployment); deployed at `script/DeployMocks.s.sol:677`, funded at :686
**Entry Point:** `dev`
**Source ID:** `DEV-10`
**Fingerprint:** `f5bb2b654c9a23452e48fd642a8baf0244918aaa1dc570bb98e7406ca0c09bf0`
**Propagation:** LOCAL-ONLY
**Triage note:** Known-issues suppression was BLOCKED this run (the declared `knownIssuesFile` does not exist on disk), so nothing was suppressed on an unfalsifiable list. Q-02 is the one finding a live list would plausibly have caught under *"mock contracts with unlimited minting (testing infrastructure only)"*; it is kept live and flagged for explicit human triage.

**Description**

The sUSDS→waUSDC donation route this mock serves was replaced by the Sky PSM in story-034 and is described in-source as *'structurally dead'* (`BalancerPoolerV2.sol:23-29`). Its only caller is `MockBalancerVault.swap` (:165), which is itself never invoked by first-party code (zero `swap(` hits in `BalancerPoolerV2.sol`). The mock is nevertheless deployed at `DeployMocks.s.sol:677`, funded with 1,000,000 mock USDC at :686, and exported to the address book and the :3001 API as `WaUSDC`.

**Impact**

Noise in the address book that the UI and any operator reading it must ignore. The mock's `mintShares` is unauthenticated and its `redeem` enforces no allowance (:54–56, :64–68), so the 1M is freely drainable by anyone on the local chain — harmless on anvil, but it means a contract with no purpose holds the largest single mock balance in the deployment. `MockBalancerVault.swap`/`setSwapRate` are dead for the same reason.

**Recommended Mitigation**

Delete `MockERC4626Wrapper`, its deployment and funding steps, and `MockBalancerVault.swap`/`setSwapRate`. Do not carry any of it into the mainnet port.

---

### [Q-03] The :3001 API's root doc blob advertises 18 available contracts while the endpoint serves 57, and CORS is open to every origin <!-- id: pps21q3 -->

**Location:** `lib/phoenix-phase-2-staging/server/index.js` — `GET /`, `app.use(cors())`, L1–L200
**Entry Point:** `dev`
**Source ID:** `DEV-11`
**Fingerprint:** `a37137b3e3695945979739c6f8094f869f7a45a4d4323e98b370f6f2ab161a2a`
**Propagation:** LOCAL-ONLY

**Description**

`GET /` returns a static documentation blob listing a hand-written `availableContracts` array of 18 names; `GET /contracts` actually serves 57. Both loaders are hard-wired to chainId 31337 and the response shape does not match the `{networks:{...}, activeNetwork, availableNetworks}` contract documented in the project CLAUDE.md. `cors()` is applied with no origin allowlist.

**Impact**

A UI developer integrating against the documented surface sees a third of what exists. Local-only and low consequence — anvil binds loopback here, though `npm run start:anvil` uses `--host 0.0.0.0`, which binds every interface.

**Recommended Mitigation**

Derive the root blob's contract list from `local.json` rather than hand-maintaining it, or drop the list and point at `/contracts`. Reconcile the response shape with CLAUDE.md, or update CLAUDE.md to describe what is actually served.

---

### [Q-04] The preflight `batchMint` call-site sweep missed two scripts that still bind the legacy scalar-`minReward` signature <!-- id: pps21q4 -->

> **Faithfulness routing: F-03 — PRIMARY home is [`spec-conformance.md`](./spec-conformance.md).**
> The routing index flags this finding, verbatim, as:
> **"PRIMARY — QA severity but owner-visible, NOT bundled"**, with the rationale
> *"Routed to the spec-conformance report at honest severity. QA severity, but NOT bundled into
> QA/gas noise: Law 2 requires a story deviation to remain visible to the owner, and the story-072
> feedback omission is the actionable part."*
> It is listed here **only** so the QA record is complete. This bundle does not take custody of it,
> and it is not to be read as a bundled QA item.

**Location:** `lib/phoenix-phase-2-staging/script/PreviewBatchMint40.s.sol` — `run` / `IBatchNFTMinterLike.batchMint`, L55–L145; also `script/interactions/SimulateMainnetNudgeMint.s.sol:77`
**Entry Point:** `dev`
**Source ID:** `FAITH-003`
**Fingerprint:** `a807cc7a66991388e22dfa8a50ec1bddeb4f491ad5efdd82bc861028f81a9321`
**Story:** story-073 (Preflight line 491, Change 2 line 505)
**Propagation:** PROPAGATES-TO-MAINNET (break-on-cutover only — a tooling break at the moment of the story-072 cutover, not a mainnet state impact)
**Confidence caveat:** Story acceptance criteria are NON-FINAL (see L-08). Recorded as confidence, NOT as severity inflation.

**Description**

Story 073 preflight line 491 instructs `grep -rn "batchMint(" script/ scripts/ test/` and to list EVERY call site needing the new form, parenthetically expecting `TestNudgePayout.s.sol` and `TestBalancerDonation.s.sol`. Two further call sites exist inside that grep's own scope and were not listed: `script/PreviewBatchMint40.s.sol` declares the legacy signature at :55 (`function batchMint(uint256 count, address recipient, uint256 paymentAmount, uint256 minReward)`) and calls it at :145, and `script/interactions/SimulateMainnetNudgeMint.s.sol` calls `batch.batchMint(count, recipient, payment, 0)` at :77. Both bind the legacy SCALAR `minReward`; `BatchNFTMinterMultiToken.sol:470` takes `uint256[] calldata minRewards`. (Note: both forms are four-argument; the difference is the fourth parameter's type, not the arity.)

**Impact**

Correct at this commit — both scripts target the live mainnet legacy `BatchNFTMinter` and match its signature — but both break the moment story 072 cuts the mainnet index-4 minter over to `BatchNFTMinterMultiToken`, and story 073's 'findings to feed back into story 072' set omits them, so nothing carries the problem across the cutover boundary. Aggravating detail: `SimulateMainnetNudgeMint.s.sol:77` wraps the call in try/catch and its low-level branch merely logs `'REVERT low-level'`, so post-cutover it will not fail loudly but will emit output resembling a simulation result — in a tool whose purpose is to tell an operator whether a mainnet mint will succeed.

**Recommended Mitigation**

Add `script/PreviewBatchMint40.s.sol` (:55 interface, :145 call) and `script/interactions/SimulateMainnetNudgeMint.s.sol` (:77) to story 073's 'findings to feed back into story 072' list, and convert both to the `uint256[] calldata minRewards` form as part of the cutover — re-fetching `getNudgeTokens()` rather than hardcoding a length, exactly as line 505 requires of the other two. Independently, replace `SimulateMainnetNudgeMint`'s low-level catch branch with a hard failure or a clearly-labelled `'SIGNATURE MISMATCH'` diagnostic, so a post-cutover ABI break cannot read as a simulation result.

---

# Carryover (prior audits) — SEPARATE label sequence

**Do not conflate with this run's `Q-01`…`Q-04` above.** The entry below is the **audit-05** `Q-01`;
it is a different finding with a different fingerprint. Labels in carryover files are the originals
from their originating run and are never renumbered into this run's sequence.

| Item | Value |
|---|---|
| Full carryover copy | [`../findings/carryover/qa-report-05.md`](../findings/carryover/qa-report-05.md) |
| Original label | **Q-01** (run `phoenix-phase-2-staging-05` — *not* this run's Q-01) |
| Severity | QA (unchanged since first report) |
| Status | `open` (untriaged) |
| Fingerprint | `0b497be32114147aa44ea7328329eaab2f024fd22b3208804fe604b84cca86b3` |
| Entry point | `dev` |
| First seen / last re-observed | `phoenix-phase-2-staging-05` / `phoenix-phase-2-staging-06` |

**This finding was NOT re-observed by audit 21, and that is NOT evidence of a fix.** Run-21 was
story-073-scoped (`dev` entry point) and did not re-walk the affected area. Absence from a
story-scoped run carries no closure authority: status remains `open`, `lastSeenRun` was deliberately
not bumped, and no ledger status was changed for it by this run. To close it, re-verify explicitly
(`/recheck phoenix-phase-2-staging 0b497be32114…`, or a full `dev` re-scan).

The carryover file is the authoritative copy; its content is not restated or re-severitied here.

---

## Cross-references

- **Medium findings (filed individually):** `submissions/M-01.md` (`NudgeStreamer.collectNudge` pooled-custody / unmeasured buffer credit — the DEV-01 defect referenced by L-06 and L-09), `submissions/M-02.md` (`BatchNFTMinterMultiToken.setNudgeStreamer` unguarded and silent — the silent consumer referenced by L-03).
- **Law-2 spec conformance:** `submissions/spec-conformance.md` (F-01…F-05).
- **Narrative review:** `script-audits/dev/review.md` (§5 findings register, §6 caveats and limits).
- **Machine-readable records:** `findings/low/*.json`, `findings/qa/*.json`.
