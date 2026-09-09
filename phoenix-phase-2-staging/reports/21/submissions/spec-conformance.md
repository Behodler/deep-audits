# Spec-conformance report (Law 2) — phoenix-phase-2-staging @ `3fb4e34`

**Run:** `phoenix-phase-2-staging-21` (script audit) · **Entry point:** `dev` (npm script `dev` → `script/DeployMocks.s.sol`)
**Story scope:** story-073 (primary), story-072 (related — the mainnet cutover this rehearsal feeds)

> **Law 2 — story/spec deviations are routed here at honest severity and are NEVER buried in the QA/gas bundle.**
> This report is the faithfulness deliverable for the run. It is **separate from** `qa-report.md`; a finding
> appearing here is not thereby a QA finding, and a finding whose primary home is the QA/Low bundle appears
> here only as a labelled cross-reference.

## Story documents resolved

Both `[story-NNN]` tags resolved to exactly one document each, by globbing the whole `phStaging2` project tree
across every state folder and every sprint/worktree folder. Neither tag was ambiguous; neither failed to resolve.

| Tag | State folder | Resolved path | Length |
|---|---|---|---|
| **story-073** | `complete/` | `~/code/product-owner/stories/phStaging2/complete/phStaging2-nudge-streamer/073-deploymocks-nudgestreamer-multitoken-batchminter-staker-v2-local-mirror.md` | 840 lines |
| **story-072** | `incomplete/` | `~/code/product-owner/stories/phStaging2/incomplete/phStaging2-promotion-ready/072-mainnet-nudgestreamer-cutover-multitoken-batchminter-staker-v2-migration.md` | 550 lines |

All acceptance-criteria text quoted below was re-read from these documents at audit time and is verbatim.
Per project policy, the state folder is metadata, not a filter: `incomplete` story 072 is fully in scope,
and its unticked lines are load-bearing evidence rather than an excuse to skip it.

### ⚠ Confidence caveat — acceptance criteria are NON-FINAL

- **Story 073 sits in `complete/` but carries an embedded `Review Status: ISSUES_FOUND`** (line 738), with
  two open HIGH issues recorded by its own `/review-work` pass at line 761 onward. It moved from `review/`
  to `complete/` mid-run.
- **Story 072 is in `incomplete/`**, and its Preflight line 514 — the real-token Kendu fee-on-transfer
  round-trip — is **unticked**.

Consequently, criteria quoted here may yet change, and F-02 and F-04 in particular carry explicit close
triggers. **This is recorded as confidence, never as severity inflation.** No finding below is rated up
because a story is unfinished, and none is rated down because a story is marked complete.

A second, narrower caveat on line numbers: story 073's own Review Issue 1 cites "checklist line 537", which
is the line number *as the reviewer saw it*; in the document's current state that checklist item is line 540.
Where a finding record cites a story line, the quoted **text** is authoritative and has been re-verified;
the numeral may drift by a line or two as the story is edited.

## Routing table

| F-label | Source id | Run label | Severity | Routing | Record |
|---|---|---|---|---|---|
| **F-01** | `FAITH-001` | **L-07** | low | PRIMARY | [`L-07-…json`](../findings/low/L-07-balancer-donation-test-certified-as-streamer-regression.json) |
| **F-02** | `FAITH-002` | **L-08** | low | PRIMARY | [`L-08-…json`](../findings/low/L-08-checklist-544-ticked-without-implementation.json) |
| **F-03** | `FAITH-003` | **Q-04** | qa | PRIMARY — QA severity but owner-visible, **NOT** bundled | [`Q-04-…json`](../findings/qa/Q-04-incomplete-batchmint-callsite-preflight-sweep.json) |
| **F-04** | `FAITH-L1-001` | **L-09** | low | PRIMARY — **Law-1 story-unsafe escalation** | [`L-09-…json`](../findings/low/L-09-kendu-whitelist-sanctioned-without-real-token-roundtrip.json) |
| **F-05** | `DEV-05` | **L-02** | low | **CROSS-REFERENCE ONLY** — primary home stays the QA/Low bundle; not double-counted | [`L-02-…json`](../findings/low/L-02-deploymocks-missing-chainid-guard.json) |

Severity totals for the run are **0 High / 2 Medium / 9 Low / 4 QA = 15**. F-05 is counted once, in the Low
bundle. F-01, F-02 and F-04 are counted once each, in the Low bundle, and are reported here because Law 2
requires the story deviation itself to be owner-visible. F-03 is counted once, in the QA set, but is
deliberately **not** bundled into `qa-report.md`'s narrative — see its entry.

---

## F-01 — L-07 (`FAITH-001`, low) — PRIMARY

**`test:balancer-donation` is certified as the index-4 streamer regression test, but the script was never
modified by story 073 and cannot exercise the streamer at all.**

- **Location:** `lib/phoenix-phase-2-staging/script/interactions/TestBalancerDonation.s.sol#L129-L135` (`run`)
- **Fingerprint:** `1b461cb4d56c1607982164ffdbc7af435af24483c3d17a37eb1c508450e5c487`
- **Root cause class:** `UnmodifiedTestCertifiedAsRegressionCoverage` · **Propagation:** LOCAL-ONLY-BUT-MASKS-MAINNET-RISK

### Acceptance criterion violated (story 073, `complete/`)

> **Line 538 (ticked)** — "Smoke-test a donation on each donor path — a Uniboost mint, an index-7 ratchet
> dispatch, a `BalancerPoolerV2` batch donation and an SYA `claim()` — and assert `collectNudge` does not
> revert on any of them. **This is the direct regression test for the streamer-unset breakage.**"

> **Line 539 (ticked)** — "`npm run test:nudge-payout` and `npm run test:balancer-donation` pass against a
> fresh deploy (after their `batchMint` call sites are updated); record that `npm run test:nft-flow` is dead
> (its driver is in `foundry.toml` `skip`)."

> **Line 505 (ticked)** — "Update every `batchMint(` call site found in preflight to the 4-arg / length-3
> `minRewards` form, re-fetching `getNudgeTokens()` rather than hardcoding 3."

### Implemented behaviour

`TestBalancerDonation.s.sol` is untouched by all three of story 073's commits (`3fb4e34`, `d241e61`,
`c054833`); `git log` shows its last modification is `4c5c3cd [story-070]`. It survives unmodified only
because it has **no `batchMint` call site at all** — grep finds no `batchMint`, no `collectNudge` and no
`nudgeStreamer` reference in the file. Instead it hand-rolls the donation route itself at `:129`
(`psm.buyGem(batchNFTMinterAddr, gemAmt)`) and asserts at `:135`
`require(usdcDelta == gemAmt, "donation USDC mismatch")` against the **batch minter's** USDC balance.

Post-story-073 the real index-4 donation no longer terminates at the batch minter: `BalancerPoolerV2` routes
USDC into the `NudgeStreamer` via `collectNudge` (wired at `DeployMocks.s.sol:779-784`). The script therefore
asserts a post-condition of the topology story 073 **replaced**, over a path the contract no longer takes.
A green `npm run test:balancer-donation` is fully consistent with the index-4 streamer being entirely unwired.

The aggravating detail is *which* leg this masks. Index-4 is the one leg whose pre-story breakage was
**silent** — the source comment at `DeployMocks.s.sol:779-781` says so in terms: the donation reverts inside
`_psmDonate`, `_dispatch`'s try/catch swallows it, and the mint still succeeds. The leg with no natural alarm
is the leg whose designated regression test cannot fail for the relevant reason.

Nothing is broken today: the audit independently confirmed `balancerPoolerV2.setNudgeStreamer(nudgeStreamer)`
at `DeployMocks.s.sol:784` and read a non-zero USDC buffer (44855551) on the streamer out of band. The defect
is in the ability to **detect** a future break, which is why this is Low and not Medium.

### Recommended Mitigation

Either (a) rewrite `TestBalancerDonation.s.sol` to drive `BalancerPoolerV2`'s **own** dispatch path
end-to-end and assert on the `NudgeStreamer` buffer delta for `(batchNFTMinter, USDC)` — i.e. assert the thing
the story repaired — or (b) untick lines 505 and 539 as they pertain to this script and record in Autonomous
Decisions that `test:balancer-donation` is a PSM-route smoke test that does not cover the streamer leg. Do not
leave it ticked as-is.

Additionally, add the index-4 case to the story-072 feedback list with the explicit instruction that the
assertion must be on the **streamer buffer**, not the batch minter's balance, since the cutover reproduces
this topology on mainnet.

---

## F-02 — L-08 (`FAITH-002`, low) — PRIMARY

**Checklist line 544 is ticked certifying a four-clause, seven-leg on-chain confirmation, of which one clause
and one leg are actually asserted — the second instance in one story of the exact class the story's own review
caught at HIGH.**

- **Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol#L889-L1129` (`run`, story-073 Verification checklist line 544)
- **Fingerprint:** `daab9e86d033b10b13ecaa02bfa9bd6ece7e93ed412ea4a16b238fa78430d63b`
- **Root cause class:** `TickedChecklistWithoutImplementation` · **Propagation:** LOCAL-ONLY

### Acceptance criterion violated (story 073, `complete/`)

> **Line 544 (ticked)** — "Confirm on the local chain: `configs(1..5,7)` resolve as expected, index 7 is a
> `NudgeRatchet`, all six donors' `nudgeStreamer()` return the streamer, and the three `UniboostStaker*` keys
> point at V2 instances holding the migrated totals."

For contrast, the story's own embedded **Review Results, Issue 1 (HIGH)** at line 761:

> "**(HIGH) Checklist line 537 is ticked but has no implementing code.** … Either implement it or untick the
> box and record the zero slots in Autonomous Decisions."

### Implemented behaviour

Line 544 certifies four distinct clauses. Exactly one has implementing code:

| Clause | Implementing assertion |
|---|---|
| (a) `configs(1..5,7)` resolve as expected | **none** |
| (b) index 7 is a `NudgeRatchet` | `require(ratchetIndex == 7, "NudgeRatchet must occupy dispatcher index 7")` at `DeployMocks.s.sol:889` |
| (c) all six donors' `nudgeStreamer()` return the streamer | 1 of 7 `setNudgeStreamer` legs post-asserted — the StableYieldAccumulator leg at `:1129` |
| (d) three `UniboostStaker*` keys point at V2 instances holding migrated totals | **none** |

No out-of-band evidence is recorded anywhere in the story for the unimplemented clauses. That is the
distinction the story's **own Autonomous Decision #8** (line 645, "`TestNudgePayout` was rewritten, and its
stream assertions moved out of band") draws correctly: AD#8 moves a check out of band explicitly and for a
documented technical reason. Line 544 does not — the tick is unsupported rather than merely uncoded.

The underlying state is in fact **correct**; the audit performed the missing confirmation out of band with
`cast` (duration 21600 on all three tokens; buffers USDC 44855551, phUSD 5000e18, Kendu 50000e18;
`pendingStream` non-zero on all three; index 7 is the `NudgeRatchet`). The defect is in the certification, not
in the chain — which is exactly why this is Low and not Medium. What lifts it clear of QA is that this is the
**second** instance in one story of the class the story's own reviewer already flagged at HIGH, which makes
the checklist's overall evidentiary value the real finding.

### Recommended Mitigation

Either implement line 544's clauses as script post-conditions — assert `configs(1..5,7)` resolve, assert all
six donors' `nudgeStreamer() == streamer` (the seven-leg fix the QA-bundled `DEV-09` also asks for), and
assert each `UniboostStaker*` key resolves to a V2 instance with the expected `totalStaked` — or untick line
544 and record the `cast` transcript that discharges it, as AD#8 does for stream accrual. Do not leave it
ticked without either.

Process-level: before `/set-complete`, require every ticked Verification line in story 073 to carry a code
pointer or a recorded transcript. The reviewer found one instance of this class; there are at least two.

**Close trigger:** if line 544's four clauses are actually asserted across all seven `setNudgeStreamer` legs,
this may be closed.

---

## F-03 — Q-04 (`FAITH-003`, qa) — PRIMARY, QA severity but owner-visible and **NOT bundled**

**The preflight `batchMint` call-site sweep missed two scripts that still bind the legacy scalar-`minReward`
signature — correct today, silently broken on the story-072 cutover, and absent from the feedback list.**

- **Location:** `lib/phoenix-phase-2-staging/script/PreviewBatchMint40.s.sol#L55-L145` (`run` / `IBatchNFTMinterLike.batchMint`); also `script/interactions/SimulateMainnetNudgeMint.s.sol:77`
- **Fingerprint:** `a807cc7a66991388e22dfa8a50ec1bddeb4f491ad5efdd82bc861028f81a9321`
- **Root cause class:** `IncompletePreflightCallSiteSweep` · **Propagation:** PROPAGATES-TO-MAINNET (break-on-cutover — a tooling break at the moment of cutover, not a mainnet state impact)

> **Routing note.** This finding is QA severity and is nonetheless filed here at PRIMARY, not folded into
> `qa-report.md`. Law 2 requires a story deviation to remain visible to the owner, and the actionable part —
> the omission from story 073's "findings to feed back into story 072" set — has an owner-visible deadline
> (before the cutover broadcast). Burying it in a QA/gas bundle is precisely the burial Law 2 forbids.

### Acceptance criteria violated (story 073, `complete/`)

> **Preflight line 491 (ticked)** — "`grep -rn "batchMint(" script/ scripts/ test/` and list every call site
> needing the 4-arg / length-3 form (expect `TestNudgePayout.s.sol`, `TestBalancerDonation.s.sol`)."

> **Change 2, line 505 (ticked)** — "Update every `batchMint(` call site found in preflight to the 4-arg /
> length-3 `minRewards` form, re-fetching `getNudgeTokens()` rather than hardcoding 3."

### Implemented behaviour

Line 491 instructs an **exhaustive** grep over `script/ scripts/ test/` and to list *every* call site,
parenthetically expecting two. Two more exist inside that grep's own stated scope and were not listed:

- `script/PreviewBatchMint40.s.sol:55` declares
  `function batchMint(uint256 count, address recipient, uint256 paymentAmount, uint256 minReward)` — the
  legacy **scalar**-`minReward` form — and calls it at `:145`.
- `script/interactions/SimulateMainnetNudgeMint.s.sol:77` calls
  `batch.batchMint(count, recipient, payment, 0)`, again binding the scalar form.

`BatchNFTMinterMultiToken.sol:470` takes `uint256[] calldata minRewards`. (Both forms are four-argument; the
difference is the fourth parameter's **type**, not the arity — the fix is a signature change, so the
distinction matters.) Line 505's "update every call site found in preflight" inherits the shortfall.

Both scripts are correct **at this commit** — they target the live mainnet legacy `BatchNFTMinter` and match
its signature, and neither broadcasts. Both break the moment story 072 cuts the mainnet index-4 minter over to
`BatchNFTMinterMultiToken`, and story 073's "findings to feed back into story 072" set omits them, so the one
mechanism that would carry the problem across the cutover boundary does not have it.

Aggravating detail, and why the fix is owed rather than optional: `SimulateMainnetNudgeMint.s.sol:77` wraps
its call in try/catch whose low-level branch merely `console.log`s `"REVERT low-level"`. Post-cutover it will
not fail loudly — it will print something resembling a simulation result, in a tool whose entire purpose is to
tell an operator whether a mainnet mint will succeed.

### Recommended Mitigation

Add `script/PreviewBatchMint40.s.sol` (`:55` interface, `:145` call) and
`script/interactions/SimulateMainnetNudgeMint.s.sol` (`:77`) to story 073's "findings to feed back into story
072" list, and convert both to the `uint256[] calldata minRewards` form as part of the cutover — re-fetching
`getNudgeTokens()` rather than hardcoding a length, exactly as line 505 requires of the other two.

Independently, replace `SimulateMainnetNudgeMint`'s low-level catch branch with a hard failure or a clearly
labelled `SIGNATURE MISMATCH` diagnostic, so a post-cutover ABI break cannot read as a simulation result.

---

## F-04 — L-09 (`FAITH-L1-001`, low) — PRIMARY, **Law-1 story-unsafe escalation**

**Both stories instruct whitelisting Kendu on the shared multi-token batch minter while the only two artefacts
that could prove Kendu is not fee-on-transfer are respectively undone and vacuous — leaving a latent arm-switch
where one routine `registerStream` would point the M-01 / DEV-01 pooled-custody defect at the live USDC buffer.**

- **Location:** `lib/nft-staking/src/NudgeStreamer.sol#L149-L150` (`registerStream` / `collectNudge`, story-sanctioned KENDU whitelist)
- **Fingerprint:** `acabc052baaa956e35d5f668f303ce40f244c0778b8154f71ff318ad46c74709`
- **Root cause class:** `UnverifiedTokenAdmissionSanctionedByStory` · **Category:** story-unsafe · **Propagation:** PROPAGATES-TO-MAINNET
- **`securityEscalation: true`** · **Plausibility:** plausible-but-unarmed
- **Shared PoC (supporting evidence only):** `workspace/phoenix-phase-2-staging/test/AuditDevNudgeStreamerFoT.t.sol`, 4/4 PASS

> **Why this is a Law-1 escalation and not a Law-2 note.** Law 1 overrides Law 2: where a story's own intended
> behaviour would introduce an exploit condition, the unsafe **story** is flagged rather than the faithful
> implementation blessed. Here the stories are the proximate cause — they *instruct* admitting an unverified
> memecoin into a contract that assumes exact delivery. Rated purely as a **non-malicious-owner footgun**
> under Law 3; no part of this finding depends on the owner acting against the protocol.

### Acceptance criteria at issue

**Story 072 (`incomplete/`), Concerns, lines 458-463** — the guard the story itself correctly installs:

> "**Kendu is a meme token and the streamer has no fee-on-transfer support.** Kendu Inu (`0xaa95f26e…`, 18dp)
> has a renounced `owner()` (`0x0`), which is reassuring — no live tax switch — but `NudgeStreamer` and
> `BatchNFTMinterMultiToken` both assume `transfer(x)` delivers exactly `x`. **The dry run must transfer a
> non-zero Kendu amount through `collectNudge` and assert the received balance equals the sent amount** before
> this goes to broadcast. If Kendu taxes transfers, it must not be whitelisted."

**Story 072, Preflight line 514 — UNTICKED (`- [ ]`)** — the implementing step:

> "Confirm Kendu is not fee-on-transfer by round-tripping a non-zero amount through `collectNudge`."

**Story 072, line 468-469** — the fact that keeps this unarmed today:

> "I have planned `registerStream` for USDC only, and left phUSD/Kendu whitelisted-but-unregistered."

**Story 073 (`complete/`), line 494** — the definition that makes the local probe vacuous
*(the finding record cites this as "line 496"; the text is verbatim, the numeral has drifted by two)*:

> "New 18-decimal mock ERC20 mirroring `MockSCX` (public `mint`, no `IBurnable`, **no transfer fee**)"

**Story 073, Verification line 540 — TICKED** — the probe that appears to discharge the obligation:

> "Seed a phUSD and a Kendu donation through `collectNudge` so all three reward slots are non-zero; assert the
> Kendu amount received equals the amount sent (no fee-on-transfer)."

### Implemented behaviour

Story 072 (lines 292, 522) and story 073 (Change 2, line 503) both instruct
`setNudgeTokenWhitelist(KENDU, true)` on the shared `BatchNFTMinterMultiToken`, while
`NudgeStreamer.collectNudge` credits `s.buffer += amount` **unmeasured** against pooled per-token custody
(`NudgeStreamer.sol:149-150` — the M-01 / DEV-01 defect).

Both artefacts that appear to discharge the fee-on-transfer obligation fail to:

1. **Story 072's own guard is undone.** Preflight line 514 is unticked; the real-token round-trip against
   `0xaa95f26e30001251fb905d264aa7b00ee9df6c18` has not been performed.
2. **Story 073's probe is vacuous.** `_seedNudgeStream` (`DeployMocks.s.sol:1645-1666`) genuinely exists and
   genuinely asserts, at `:1661`,
   `require(received == amount, "nudge seed token is fee-on-transfer: streamer received < sent")` — but it
   runs against `MockKendu`, which story 073 line 494 **itself defines** as having no transfer fee. It proves
   a mock is fee-free. It **cannot fail**, while its assertion string reads as though a general FoT guard had
   been exercised.

Under this repo's standing principle that falsely-exhaustive or self-certifying evidence *raises* severity, a
probe that looks like a guard but cannot fail is worse than no probe: an operator who ran `deploy:local` has
**watched an FoT assertion pass** and therefore has positive reason not to run story 072's line 514. The
evidence points the wrong way.

**There is no armed path today**, and that is why this is Low rather than Medium. With `registerStream` for
USDC only, `collectNudge` is never called on Kendu, no Kendu buffer exists, and `pullPendingStream` no-ops on
the unregistered token; the DEV-01 drain additionally needs two pairs sharing one token, and a token with zero
registered streams shares nothing. The sanctioned end-state is genuinely inert, exactly as story 072 claims.
Rating it Medium would also double-count M-01 / DEV-01, which already carries this impact at Medium with a
passing PoC.

The residual is a **latent arm-switch**. One later `registerStream(newBM, KENDU, DURATION)` — a routine-looking,
owner-gated call that reads as "turn on the Kendu reward slot", with no FoT probe at that admission point —
arms the token. If Kendu taxes, the buffer over-credits relative to custody, the shortfall is settled out of
the shared per-token balance, and because `batchMint` loops `pullPendingStream` over the whole
`getNudgeTokens()` whitelist inside one transaction, the revert takes down minting for **every** reward token
including the live USDC leg. Apply the Law-3 test — would a competent, non-malicious owner be surprised that
enabling a *new* reward slot could consume the backing of the *existing* one? Yes. Footgun, therefore in scope.

**Net: LOW severity, MEDIUM-grade priority.** The severity reflects that nothing is armed; the priority
reflects that the only thing between the current state and DEV-01-on-live-custody is one routine owner call
whose safety nobody has verified.

### REOPEN-AS-MEDIUM trigger (mandatory)

Escalate to **medium** immediately — do not wait for the next scheduled run — on **any** of:

- (a) `registerStream(<any batchMinter>, KENDU, *)` executed on mainnet, or on any chain holding a real USDC
  buffer, **without** a completed real-token round-trip against `0xaa95f26e30001251fb905d264aa7b00ee9df6c18`;
- (b) any second `(batchMinter, token)` pair registered on a token that already has a registered stream —
  which arms DEV-01's cross-pair drain irrespective of Kendu;
- (c) any donor other than the USDC donors beginning to push into the streamer.

**BLOCKING PRE-BROADCAST ACTION:** tick story 072 Preflight line 514 against the **real** Kendu token at
`0xaa95f26e30001251fb905d264aa7b00ee9df6c18`. Story 073's `MockKendu` probe does **not** discharge it.

### Recommended Mitigation

Before the story-072 broadcast, discharge line 514 for real: round-trip a non-zero amount of the actual Kendu
token at `0xaa95f26e30001251fb905d264aa7b00ee9df6c18` through `collectNudge` on a mainnet fork and assert
`received == sent`. Record the transcript in the story. Story 073's `MockKendu` probe does not discharge it and
should be annotated to say so, since its assertion message currently reads as a general FoT guard.

Structurally, move the admission check on-chain: probe for fee-on-transfer inside `registerStream` — already
owner-gated and the natural admission point — so arming a taxed token fails closed rather than depending on a
checklist. This is the same fix M-01 / DEV-01 recommends and it closes both.

Until then, do **not** register a Kendu stream, and record the whitelist-without-stream state as a deliberate,
documented configuration with the arming hazard spelled out beside it.

**Close trigger:** ticking story 072 Preflight line 514 against the real token (not `MockKendu`) closes this
finding outright.

---

## F-05 — L-02 (`DEV-05`, low) — **CROSS-REFERENCE ONLY**

**`DeployMocks` has no `block.chainid` guard at all, while every `DeployMainnet*` script carries one twice —
and story 073 states the chain restriction as a flat property of the work.**

- **Location:** `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol#L290` (`run`)
- **Fingerprint:** `ce524709d965de786fc2b6f6a1e5d2e2139406346b8fd5f930fdabac679b36e0`
- **Root cause class:** `MissingChainGuard` · **Propagation:** LOCAL-ONLY

> **Routing.** **CROSS-REFERENCE ONLY.** This finding's primary home is and remains the QA/Low bundle
> (`qa-report.md`). It is listed here so the story-level deviation is visible to the owner, and it is
> **not double-counted** in the severity totals.

### Acceptance criterion violated (story 073, `complete/`)

> **Line 66** — "No mainnet contact of any kind. Everything here targets chainId **31337**."

### Implemented behaviour

The story asserts the property in the indicative; nothing in the code enforces it. `DeployMocks.s.sol:290`
merely **logs** `block.chainid` — a grep for `block.chainid` across the 1946-line file returns that single hit,
inside a `console.log`. There is no `require(block.chainid == 31337)` anywhere. All seven `DeployMainnet*`
scripts carry `require(block.chainid == 1)`, most of them twice (`setUp` + `run`). The project's own
`CLAUDE.md` is explicit that the anvil relaxation "must be gated behind an explicit `block.chainid == 31337`
branch and clearly commented — never share an unsafe default code path between local and real networks."

This is the one script carrying every documented unsafe local relaxation: unrestricted `MockKendu.mint`,
`phUSD.setMinter(deployer, true)` granted at `:1648` and `:1731` and **never revoked** (verified live
post-run: `authorizedMinters(deployer) == (true, 1)`; grep for `setMinter(.*false)` returns nothing), the
300-ETH `WETH9.deposit` at `:1460`, real `PhusdStableMinter.mint` calls in Phases 9/9.5/9.55/9.6, and the
destructive V1-staker teardown (pause + pauser repoint to an EOA + unregister from the global Pauser).

**What story line 66 changes** is the *character* of the finding, not its severity: it is no longer merely an
intra-repo convention asymmetry plus a `CLAUDE.md` rule, it is a **documented invariant that is not held**.
Severity is held at **Low** deliberately, against a three-source stack: running a script literally named
`DeployMocks` against a production RPC is an *obvious*-consequence operator error, which Law 3 keeps out of
scope; only the intra-repo asymmetry is non-obvious, and asymmetry alone carries no impact. Three documents
asserting the same unenforced property raise confidence and fix priority; they do not manufacture impact.

**Disclosed re-file / systemic signal:** ledger entry `8468af472d` (low, **open**, entryPoint
`batch-minter-migrate`) is the same `MissingChainGuard` class on `MigrateBatchNFTMinter`. Different script and
entry point ⇒ different fingerprint by design. The prior entry is `open`, so no human triage is overridden,
and it is **not modified by this run**. Two simultaneously-open instances of one class argue for a shared
chain-guard modifier across `script/`, not two point fixes.

### Recommended Mitigation

Add `require(block.chainid == 31337, "DeployMocks: anvil only")` in `run()` before `vm.startBroadcast`.

Independently — and this is the highest-value part of the fix, the part most likely to be lost in a QA
bundle — revoke the two `phUSD.setMinter(deployer, true)` grants at `:1648` and `:1731` at the end of the run
and post-assert `authorizedMinters(deployer).canMint == false`, so the mainnet port inherits a
revoke-and-assert habit rather than a standing minter grant.

Treat as one class-level remediation with `8468af472d`.

---

## Close triggers summary

- **F-02 / L-08** — closable if line 544's four clauses are actually asserted across all seven
  `setNudgeStreamer` legs.
- **F-04 / L-09** — closable if story 072 Preflight line 514 is ticked against the **real** Kendu token
  `0xaa95f26e30001251fb905d264aa7b00ee9df6c18` (not `MockKendu`). Carries a mandatory REOPEN-AS-MEDIUM trigger
  and a blocking pre-broadcast action; see the finding record's `reopenTrigger`.
- **F-01 / L-07**, **F-03 / Q-04**, **F-05 / L-02** — closable on the remediations stated above; no
  conditional escalation attached.

## Related artifacts

- Routing index (source of this report): [`findings/spec-conformance.md`](../findings/spec-conformance.md)
- Narrative script review: [`script-audits/dev/review.md`](../script-audits/dev/review.md)
- QA/Low bundle (primary home of F-05): [`qa-report.md`](./qa-report.md)
- Medium submissions: [`M-01.md`](./M-01.md) (DEV-01, the impact carrier for F-04) · [`M-02.md`](./M-02.md)
- Carryover from prior audits: [`carryover/`](./carryover/)
