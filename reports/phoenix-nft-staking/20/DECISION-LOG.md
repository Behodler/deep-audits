# Decision Log — phoenix-nft-staking run-20

**Run:** `reports/phoenix-nft-staking/20/`
**Date:** 2026-07-20
**Baseline:** `321d0a96d7da9f261517fc53e2d14bf2b49f41c1` (run-19, story-020)
**HEAD:** `0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54` (story-022 Stage 6)
**Mode:** REGRESSION + cold treatment of new/rewritten files

The operator requested a fully autonomous run ("don't prompt me for decisions … just note all decision forks
that would usually require my input"). Every fork below was resolved by me, not by the operator. Each entry
records the fork, the option taken, the reasoning, and what a reversal would cost.

---

## D-01 — Run mode: regression, but the two changed files are scanned COLD

**Fork.** A ledger exists and `--full` was not passed, so the default is a regression scan. But this cycle
added a **new 1005-line first-party contract** (`src/NFTStakerPriceScaledMigrateReady.sol`, story-021) and
**near-rewrote** the nudge payout path of `src/BatchNFTMinter.sol` (story-022, +361 lines). A pure
"focus on the diff" regression pass would under-serve both.

**Decision.** Hybrid: regression-mode reconciliation against the ledger for the untouched six contracts,
but `BatchNFTMinter.sol` and `NFTStakerPriceScaledMigrateReady.sol` are profiled and scanned **as if cold** —
full re-derivation, prior profiles not trusted on the changed paths.

**Why.** This is what `scopePolicy.newFileHandling` already mandates for new first-party contracts, and the
operator explicitly asked for "everything new in particular". Law 1 (recall beats report-tidiness) makes the
extra token spend the cheap side of the trade.

**Reversal cost.** None meaningful — a superset of the default behaviour.

---

## D-02 — `script/DeployBatchNFTMinter.s.sol` kept in scope despite absence from the cached snapshot

**Fork.** The cached `scope` array in `registered-projects.json` (7 entries, snapshotted at run-18) does not
list `script/DeployBatchNFTMinter.s.sol`. It is first-party, it is not in the project's own nested `lib/**`,
it is not in the project's `outOfScope`, and story-022 changed it.

**Decision.** In scope. Scanned.

**Why.** Scope is a denylist, not an allowlist — the cached array is an advisory snapshot, never the gate.
Corroborating evidence: the ledger already carries an **open L-04** on this exact file, so it has been
scanned in practice before; treating the snapshot as authoritative would have silently dropped a file with
a live open finding.

**Reversal cost.** Low — if the operator considers deploy scripts out of scope, add an explicit
`outOfScope` glob and re-triage L-04.

---

## D-03 — Scope snapshot drift left UNWRITTEN during resolution; deferred to the finding-manager step

**Fork.** The computed in-scope set is 9 files; the cached snapshot has 7. The resolver could have silently
refreshed the snapshot as a side effect.

**Decision.** Not written during resolution. The refresh is deferred to the deliberate finding-manager /
ledger-upsert step at the end of the run.

**Why.** A silent snapshot rewrite during resolution hides the drift in a diff nobody reads. Surfacing it as
one deliberate change keeps the "which contracts got added, and when" question auditable.

**Reversal cost.** None — the snapshot is advisory either way.

---

## D-04 — Cached known-issues treated as NON-authoritative for everything after story-016

**Fork.** `knownIssuesSource` points at `lib/phoenix-nft-staking/CLAUDE.md`. The path is **valid** (unlike
phlimbo-ea / phStaging), but the file has not been touched since **2026-04-25** (commit `3087b8e`,
story-008), and it contains **no dedicated Known Issues / Out of Scope / Limitations section** — the 14
cached "known issues" were *derived* by a prior run from the Feature Specification and Critical Invariants
sections. The file predates stories 017–022 entirely and describes only `NFTStaker` + `BatchNFTMinter`.

**Decision.** The sanitizer may use the 14 cached KIs to suppress findings **only** on pre-story-022
semantics of `src/NFTStaker.sol` and `src/BatchNFTMinter.sol`. They may **not** suppress any finding on:
the multi-token nudge (story-022), any of the four staker copies beyond base `NFTStaker`, either migrator,
or `NFTStakerPriceScaledMigrateReady`. The normative spec for the new nudge behaviour is
`docs/multi-token-nudge.md` (added this cycle), not `CLAUDE.md`.

**Why.** This is the exact failure mode recorded for phlimbo-ea, where unfalsifiable cached KIs nearly
suppressed live V3 findings. Two cached `designDecisions` entries are already *actively contradicted* by
HEAD (they assume the now-removed `nudgePaymentToken` / `setNudgePaymentToken`). Law 1: a stale suppression
list must not be allowed to hide a live bug.

**Reversal cost.** Moderate — if the operator disagrees, the affected findings are all still in the run
output and can be re-suppressed via `/ledger`. The unsafe direction (over-suppression) is the one that
cannot be undone, so I took the recall-preserving side.

**Follow-up owed:** `CLAUDE.md` needs a real Known Issues section, or the registry needs a re-extraction.

---

## D-05 — Fork-drift watch re-scoped from THREE copies to FOUR

**Fork.** `WATCH-17-maintenance-coupling-drift` mandates an N-way parity diff every run, currently scoped to
`NFTStaker` ↔ `NFTStakerPriceScaled` ↔ `NFTStakerDepletion`. story-021 added a fourth copy.

**Decision.** The watch is re-scoped to a **4-way** diff this run and permanently thereafter. The standing
direction rule is carried forward unchanged: **story-020's depletion rate/window fix must NOT be mirrored
into the APY/runway copies.**

**Why.** Mechanical consequence of the new file; leaving the watch at three would let the newest copy drift
unobserved — and it is the copy most likely to drift, being a hand-made fork of a fork.

**Reversal cost.** None.

---

## D-06 — Workspace synced forward; PoC assets preserved as `.bak`

**Fork.** The workspace sat 7 commits behind at the old baseline and had no git remote (by policy). Syncing
risked clobbering four untracked PoC files from prior runs.

**Decision.** One-shot local fetch from the submodule's object store (no remote persisted), then detached
checkout of `0d1a0b2`. All four `.bak` PoCs preserved untouched. `lib/` never written.

**Verification.** `forge build` clean; `forge test` **333 passed / 0 failed**, matching the upstream claim
at this commit exactly.

**Known consequence.** Three of the four parked PoCs (`poc-H-01`, `poc-MevFrontrunNudge`, `poc-NudgeDrain`)
target `batchMint`, whose **signature changed** this cycle. Expect replay bit-rot. Per `/recheck` semantics
a PoC that no longer *compiles* is **INCONCLUSIVE**, never evidence of a fix — recorded here so no
downstream step reads a compile failure as a green light.

---

## D-07 — `WATCH-19-nudge-law1-reopen-trigger` premises must be re-tested, not assumed

**Fork.** The accepted (fixed/wont-fix) BatchNFTMinter nudge lineage — H-01 value-blind nudge gate, M-01 MEV
nudge-pot front-run, L-05 `minReward==0` opts out of the slippage guard — rests on two premises: (1) the pot
is smaller than `nudgeSize * mintPrice`, and (2) minted NFTs have no realizable/redemption path. story-022
rewrote exactly this payout path into a **caller-selected multi-token** payout with **no dedupe**, plus
explicit fee-on-transfer and reentrancy test witnesses.

**Decision.** Both premises are re-tested from source this run rather than inherited. Any finding whose
suppression depended on them is re-derived, not auto-carried.

**Why.** Law 1. A suppression premise that silently stops holding is how a live exploit gets filed as
"already known".

---

## D-08 — `WATCH-19-L01-incomplete-fix-trap` honoured: no auto-flip on constructor-only patches

**Fork.** Ledger L-01 (`e7bccb02…`, `InPlaceNFTStakerMigrator` immutable `stakedId` parity) carries an
explicit trap note.

**Decision.** Not auto-flipped. The direction note is carried forward verbatim: **do NOT repoint
`claimTimedOut` / `rescueERC1155` to `newId`.** Any proposed status change is *proposed only*, for human
application via `/ledger`.

---

## D-09 — Status changes are PROPOSED, never applied

**Fork.** The operator is away and cannot triage. Several ledger entries look likely to have been resolved
by this cycle — notably **L-04** (`script/DeployBatchNFTMinter.s.sol` hardcoded `DISPATCHER_INDEX`/USDC
nudge token), whose target code story-022 explicitly deleted, and the submitted **L-01** (missing
`nonReentrant`), which the story-022 `ReentrancyGuard` inheritance appears to address.

**Decision.** No status is auto-flipped to `fixed`. Every candidate is re-derived from source, and the
outcome is recorded as a **proposal** with the exact `/ledger` command to apply it.

**Why.** Project rule: a fix that merely stops tripping the scanner is not a verified fix; only a human
applies `fixed`. This is doubly right when the operator is absent — an auto-flip made in their absence is a
suppression they never saw.

---

## D-10 — Severity of new findings set by the pipeline; disputes recorded, not silently resolved

**Fork.** With no operator available, a severity disagreement between `severity-classifier` and
`severity-auditor` has no tiebreaker.

**Decision.** Where the two disagree, the finding is filed at the **higher** severity with the dispute
recorded inline and flagged in the final summary for human re-weigh.

**Why.** Filing high-and-flagged is recoverable; filing low-and-forgotten is not. Precedent: run-18, where
the severity-auditor's downgrades were accepted only after human review.

---

## D-11 — Semgrep's silence recorded as a TOOL GAP, not as a clean result

**Fork.** Semgrep returned 0 security findings. That could be reported as "clean".

**Decision.** Recorded explicitly as **vacuous**. The `p/smart-contracts` pack's 189 hits were all `INFO`
performance/style rules (`use-custom-error-not-require` ×105 etc.); a probe of `p/security-audit` matched only
2 multilang rules and returned 0 findings. Semgrep contributed **nothing** to this scan.

**Why.** Project law: a missing or vacuous result must never be presented as verified-clean. Also recorded:
**Aderyn did not analyze `script/DeployBatchNFTMinter.s.sol`** (Slither and Semgrep did) — a real, if minor,
coverage hole on a file that carries an open finding.

**Also verified:** the known Slither trap was avoided — `--filter-paths` was anchored to
`phoenix-nft-staking/lib/` rather than bare `lib/` (which would have filtered every first-party file and
produced a false 0-result). Sanity check passed: 131 raw results across 7 files, not zero.

---

## D-12 — Aderyn "Centralization Risk" (57 instances) dropped under Law 3, but the count is preserved

**Fork.** Aderyn emitted 57 centralization-risk instances covering owner control of `setTargetAPY`,
`setDispatcherHook`, `topUp`, etc.

**Decision.** Dropped from the findings stream — the owner is trusted and these are by design (registry
known-issue #1). But the count and rationale are written into the output JSON's
`filterPolicy.centralizationNote` so the suppression is visible rather than silent.

**Why.** Law 3: "a malicious owner could…" is noise. But Law 1 says a set-aside finding is parked in a
visible channel, never a log nobody reads.

---

## D-13 — ⚠ Ledger **L-03** to be closed **MOOT**, not **FIXED** — its stated remedy is now a FIX TRAP

**Fork.** Ledger entry L-03 (`submitted`, "nudge-token equality guard") targets code story-022 restructured.
The tempting disposition is `fixed`.

**Decision.** Propose **moot / superseded**, explicitly NOT `fixed`, with a trap warning attached.

**Why — this is the most important disposition call in the run.** L-03's implied remedy was *"skip the
equality guard when the nudge is size-disabled."* Under the new §4.1 that remedy is **directly contrary to
spec**: §4.1 requires the payment-token exclusion to run **unconditionally**, precisely so a non-qualifying
call cannot use the guard's behaviour to probe payment-token balances. **Applying L-03 as written would
reintroduce a probe vector.**

**Consequence if ignored.** Someone reading the ledger later sees a `submitted` Low with an obvious-looking
one-line fix, applies it, and reopens an information-leak path. The trap warning must survive into the
ledger entry text itself, not just this log.

---

## D-14 — Fork-drift hazard is no longer hypothetical; it MATERIALISED inside its own commit

**Fork.** `WATCH-17-maintenance-coupling-drift` has been a standing *precautionary* note for three runs. It
could be renewed unchanged.

**Decision.** Escalated from precaution to **realised defect**, and widened to four copies.

**Why.** story-021's commit body itself names the `_safePay` → `_safePayTo` bug ("*which would pay the
migrator*") and its ported NatSpec calls the `_safePay` form *"wrong in every case"* — then fixes it **only
in the new copy** and declares `NFTStakerDepletion.sol` untouched (verified true). So the watch note's
anticipated failure mode — a fix authored in a clone and never back-ported — happened in the very commit
that created the fourth clone. Three independent agents (fork-parity, faithfulness, code-scan) converged on
it.

**Consequence.** This is filed as a live finding against `NFTStakerDepletion.sol:756`, not as a watch-note
renewal. Recovery is asymmetric and that drives severity: `InPlaceNFTStakerMigrator` has an owner
`rescueERC20`; **`NFTStakerMigrator` has no rescue function at all**, so phUSD routed there is permanently
stranded.

---

## D-15 — Inherited findings on the new clone are DISCLOSED, not re-filed with fresh fingerprints

**Fork.** The new copy #4 inherits verbatim several already-triaged findings: **L-08** (`priceScale`
magnitude unchecked), **M-02** (`emergencyWithdraw` over-emission — owner-acked **wont-fix** 2026-06-09),
and the ledger L-02/L-03 depletion analogues. A new contract mints a **new fingerprint**, which dedup will
not link to the prior entry — so these would silently re-enter the report as "new".

**Decision.** Recorded as *inherited-unchanged* against the existing entries, not minted as new findings.

**⚠ One exception, and it is a Law-1 disclosure obligation.** For **M-02**, the owner's wont-fix rationale
was: *(a) not deployed, (b) no migrate-on-behalf, (c) `pullAndRefresh` mitigation.* Copy #4 **adds
migrate-on-behalf** (`batchMigrate` / `depositFor`) — so premise (b) no longer holds on this contract.
Per the standing "disclose when re-filing an owner wont-fix" rule, this is surfaced with the prior triage
quoted and the re-file basis stated, rather than either silently re-filing or silently inheriting the
suppression. **The operator should re-read the M-02 acceptance in light of the changed premise.**

---

## D-16 — Suppression premises behind the accepted nudge lineage were re-derived, not inherited

**Fork.** `WATCH-19-nudge-law1-reopen-trigger` conditions the accepted nudge findings on two premises. The
cheap path is to carry the suppressions forward.

**Decision.** Both premises re-tested from source. Result: the story-022 rewrite **does** change the
economics — the duplicate-token defect (F-20-01) is production-live under the pinned
`DISPATCHER_INDEX = 4` (`BalancerPoolerV2`, `primeToken() == USDS`, forwarding a **USDC** cut to the
batcher on every dispatch, so USDC is simultaneously a legal reward token and a per-mint donation).

**Fix trap recorded.** The obvious remedy for F-20-01 — re-read `balanceOf` at payout — is *exactly* the
§4.2 refactor the spec warns against at both the snapshot site and the payout site. A correct fix must clamp
to `min(snapshot[i], balanceOf(this))` or dedupe, **not** re-read. Pattern-matcher notes this also fixes the
FoT payout-vs-delivered gap, so the two should be evaluated jointly.

---

## D-17 — Live mainnet RPC reads authorised (read-only) to settle a severity question

**Fork.** The econ scan found the step-10 payment-token sweep is not hypothetical: on
`RatchetBatchNFTMinter` (`0x81896f48…`) the payment token **and** the donated asset are both USDC
(`NudgeRatchet.sol:104` forwards 100% of every USDC mint price to `batchMinter`;
`DeployMainnetNudgeRatchet.s.sol:342,458`). That makes the pot unclaimable through the legitimate §4.1 nudge
path and fully sweepable by any `count == 1` caller. **Whether this is Medium or High depends on live
on-chain state** — specifically the current USDC balance sitting on that contract and whether
`NudgeRatchet.batchMinter()` has been repointed.

**Decision.** Authorised a **read-only** mainnet verification (`cast call` / `cast balance` against
`RPC_MAINNET` from the repo-root `.envrc`). No transactions, no writes, no state changes.

**Why.** Severity must be evidence-backed, and the difference between "latent hazard" and "funds exposed
right now" is not something I should guess at while the operator is away. Reading public chain state is
non-destructive and outward-facing only in the trivial sense of an RPC query.

**What I did NOT do.** I did not attempt any remediation, did not run `FixRatchetBatchMinterSink.s.sol`, and
did not touch any private key or broadcast path. If the pot turns out to be live and large, that is an
**operator action item**, not something an audit run should act on unilaterally.

---

## D-18 — ECON-001 filed as a NEW finding of a PRE-EXISTING defect (not a regression, not a carryover)

**Fork.** The step-10 sweep is byte-identical since `ab07199 [story-013]` (2026-05-29) — it **predates**
story-022 and is unchanged by it. But all 22 ledger entries were checked and **none covers it**. So it is
neither a regression (never was marked fixed) nor a carryover (never was filed).

**Decision.** File as a **new** finding, with the provenance stated explicitly in the report so nobody reads
it as "introduced by story-022".

**Why it surfaced now.** story-022 *added* the §4.1 guard, which upgrades the leak from "dust escapes" to
"the pot can **only** escape this way" — the guard blocks the legitimate claimer while leaving the sweep
open. The new code didn't create the sink; it closed the honest exit next to it.

---

## D-19 — Fee-on-transfer (ECON-006) kept at QA despite §4.4 documenting it

**Fork.** FoT findings are normally C4-invalid. story-022's §4.4 explicitly brings FoT in scope by
documenting it, which could be read as making it reportable at real severity.

**Decision.** Stays **QA**. Recommend only a NatSpec reword (attribute the shortfall to `recipient`, not
"the caller").

**Why.** Documenting a risk makes it discussable; it does not manufacture an attack path the value flow
doesn't support. Here the caller chooses *both* the token and the recipient, the fee accrues to the token's
own sink (no extraction), and there is **no path where A's token choice costs an unrelated B**. Reasoned
both ways and landed on QA deliberately — recording it so the reasoning isn't re-litigated next run.

---

## D-20 — Two premises behind the accepted nudge lineage have measurably DEGRADED

Recording this as a fork because it changes the standing of previously-accepted findings, and I resolved it
without the operator.

- **Premise (1) "pot < `nudgeSize · mintPrice`" — DEGRADED.** It still holds empirically (~6× margin
  observed) but **no longer by construction**. The primary funder is `StableYieldAccumulator.claim()`
  routing `nudgeSplit`% (30, cut to 20 on 2026-06-10) to the nudge address
  (`StableYieldAccumulator.sol:512-516`) — an unbounded, time-accumulating stream with **no relationship to
  mint cost**. Nothing in the contract bounds the pot; only bot competition does.
- **Premise (2) "minted NFTs have no realizable path" — NO LONGER HOLDS.** `NFTMinterV2` is a plain
  `ERC1155Supply` with no transfer restriction, and units stake for phUSD at 30% (`NFTStaker`) / 45%
  (`NFTStakerPriceScaled`) APY. On the ratchet path the mint is literally free. Only "no burn-for-underlying"
  survives (`NFTMinterV2.sol:341-345`).

**Decision.** Filed as **ECON-004 (Low)** — no standalone loss, but it is the amplifier that sets the
ceiling on the two Mediums, and it removes the safety argument the spec's §1 leans on. Surfaced rather than
folded silently into the existing suppressions.

---

## D-21 — Refutations recorded with source, so they are not re-derived every run

Several candidate findings were **killed with evidence** rather than left hedged. Recording them so future
runs inherit the refutation, not the suspicion:

- **SAST-034 (ignored `mint()` return) — REFUTED.** `NFTMinterV2._executeMint` either reverts on its four
  `require`s or returns unconditional `true` (`:200`). No path returns `false`; a caller can never be charged
  for `count` and receive fewer.
- **Modifier order (SAST-103) — REFUTED, no window.** `whenNotPaused` expands to one SLOAD + conditional
  revert — no external call and no user code before `_status` is armed. ⚠ **But do NOT close SAST-104/105
  (`InPlaceNFTStakerMigrator.sol:152/:186`) by reference to this** — they need the same check run
  independently.
- **`configs` tuple drift — NOT the phStaging YS-20 severity class → QA.** The exclusion key cannot
  desynchronize (batcher `:322` and `NFTMinterV2._executeMint` `:177` read `primeToken()` from the same
  dispatcher at the same tuple position, so a wrong dispatcher yields a wrong-but-**consistent** pair), and a
  reorder displacing `dispatcher` from position 0 **fails closed**. Both PoC-proven.
- **Hostile-token surface is half what the profile assumed.** `IERC20.balanceOf` is `view`, so solc emits a
  **STATICCALL** at `:429` — the snapshot read cannot mutate state (proven: a storage-writing `balanceOf`
  bricks the batch). The only mutative hostile-token hook is `safeTransfer` at `:458`.
- **The mid-loop ERC1155 receive hook is real and attacker-controlled, and the guard HOLDS** — proven by
  wiring a hook-firing minter: re-entry reverts with the exact `ReentrancyGuardReentrantCall` selector.
  ⚠ The finding here is a **test-coverage gap**, not a vulnerability: `MockERC1155.mint()` skips
  `_checkOnERC1155Received` entirely, so §4.3 is currently certified by a witness that never reaches the hook
  it was written for.

---

## D-22 — ECON-001 settled at **Medium**, not High, on live on-chain evidence

**Fork.** ECON-001 (payment-token sweep on `RatchetBatchNFTMinter`) was proposed Medium with an explicit
"re-rate **High** if `NudgeRatchet.batchMinter()` still points at `0x81896f48…`". That is a High-vs-Medium
call I had to make without the operator.

**Evidence gathered** (read-only, Alchemy, block 25572875 — full detail in
`mainnet-verification-ECON-001.md`):
- `RatchetBatchNFTMinter` = `0x81896F48a95AbeA255cd38a3010E985b6051A1C7`, `dispatcherIndex()` = 7,
  and that dispatcher's `primeToken()` = canonical USDC — **the mechanic in the finding is real.**
- **`NudgeRatchet.batchMinter()` → `0x86866e01a115C17892Ed04c548F2e8638851029d` — REPOINTED.** The
  entrypoint==sink identity is broken.
- **`RatchetBatchNFTMinter` holds 0 USDC, 0 USDS, 0 ETH.** Archive reads show it was **also 0 at the block
  before the fix** — the self-refund returned funds within the same tx, so no inter-block pot ever existed
  and **no historical loss occurred via this path.**
- `FixRatchetBatchMinterSink.s.sol`'s two owner calls are recorded on chain 1 with receipt status `0x1` at
  blocks 25356884/25356885, corroborated by the live read.

**Decision.** **Medium.** Not High (no funds exposed now, none ever lost this way), not Low (the un-gated
sweep at `BatchNFTMinter.sol:381-383` is unchanged, `0x81896F48…` is deliberately retained and still live
with USDC as its swept payment token, and one `setBatchMinter` — or any USDC airdrop to it — re-arms it
instantly).

**Why I'm comfortable deciding this one alone.** The evidence is unambiguous and numeric, and it resolves
*downward*. Had it resolved upward I would have escalated it to the top of the summary as an urgent item
rather than filing it normally.

---

## D-23 — NEW hardening item surfaced by the verification: **no pauser on either live instance**

Not a fork I was asked to resolve, but a material fact found while verifying D-22, so it is recorded rather
than buried in the appendix.

`pauser() == address(0)` and `paused() == false` on **both** `0x81896F48…` **and** `0x86866e01…` — and
`0x86866e01…` is the instance actually holding **219.99 USDC** as an intended, gated bounty. The contract's
own NatSpec says `rescueERC20` is *"a race the owner will usually lose"* and that *"pause first, then
rescue"* is the only dependable sequence — **which is unavailable when `pauser == 0`.**

So the documented recovery procedure for this contract cannot currently be executed on either deployed
instance. Filed as a hardening ask (set a pauser on both, and/or bound the step-10 refund to the caller's
own unspent payment).

---

## D-24 — ⚠ Possible INCOMPLETE FIX of run-18 M-01 flagged for arbitration, not silently re-filed

**Fork.** Ledger **M-01** (`b58b172e…`, `NFTStakerDepletion` linear-depletion rate-drift, PoC'd at 63.26%
in run-18) is marked **`fixed`** by story-020. The staker econ scan reached the **same class** again through
a *different* path: operator-chosen `migrateIn` slice ordering. PoC `test_ECON_G` shows slice-1 users
receiving **120%** of slice-2 users (48.98 vs 40.76 phUSD) on `NFTStakerDepletion`, because they split the
entire pool-wide stream alone while later slices sit parked.

This is the phlimbo-ea **Linear-Depletion class** and the run-18 M-01 class — reached via the **migration**
path. **story-020 fixed the `unstake` path, not this one.**

**Decision.** I did **not** auto-flip M-01 to reopened, and I did **not** let it be filed as an unrelated new
Low. It goes to severity arbitration explicitly labelled as a **possible incomplete fix**, which project law
ranks second only to a REGRESSION in signal — *"an incomplete fix is more dangerous than an unfixed bug,
because it reads as done."*

**The honest counter-argument, recorded so arbitration is fair.** run-18 M-01 was *automatic* rate drift
triggered by ordinary `unstake`. This is *operator-chosen* slice ordering during a migration the operator
controls, with a clean remedy (`setTargetAPY(0)` immediately after `finalizeAndReset`, restore after the last
slice). That difference is why the scanning agent proposed **Low (ceiling Medium)** rather than reopening
M-01 outright. Both framings are in the finding record; **a human should pick.**

**Why this matters even at Low.** The same slice-ordering mechanism on the *price-scaled* copy measures
1000 bps (`test_ECON_A`), and a self-advancing user beats the operator queue for 1666 bps (`test_ECON_H`,
filed separately as ECON-03 — different actor, different mechanism, so fixing one does not fix the other).

---

## D-25 — Aderyn's suggested remedy on `batchMigrate` REJECTED as actively harmful

**Fork.** SAST-109 (Aderyn) advises "forgive on fail and return failed elements" for the `batchMigrate` loop
— superficially reasonable DoS-hardening advice.

**Decision.** **Rejected, and recorded as a do-not-action item** rather than silently dropped.

**Why.** Applying it would be a *regression*: silently skipping a user during a migration strands that
user's position while the batch reports success. The loop reverting is the correct fail-closed behaviour
here. This is exactly the shape of "obvious fix that strands funds" that this project has been bitten by
before, so it is written down rather than left to be re-suggested next run.

---

*(Entries D-26+ appended below as the run proceeds.)*

---

## D-26 — Nudge-lineage PoC debt DISCHARGED, and the two expired closures it exposed were filed as REOPENS, not as new findings

**Fork.** D-06 predicted bit-rot: three of the four parked nudge PoCs targeted `batchMint`, whose signature
story-022 changed. A compile failure is `INCONCLUSIVE` under `/recheck` semantics, never a fix — so the run
could have (a) recorded a verification-debt watch note and moved on, or (b) paid the debt inside the run by
re-authoring the PoCs against the new API.

**Decision.** Paid it inside the run. All four PoCs were re-authored against the story-022
`batchMint(uint256 count, address recipient, uint256 paymentAmount, address[] rewardTokens, uint256[] minRewards)`
API and pass **11/11 at `0d1a0b2`**. The proposed `WATCH-20-nudge-poc-verification-debt` was **withdrawn
before creation** — there is nothing left to watch. The four `.bak` originals were left untouched.

**What that discharge exposed, and how it is filed.** The replays falsify the premises behind two ledger
entries currently marked `fixed`: ledger **H-01** (`858e9e80…`) and ledger **M-01** (`521c20ad…`, owner-signed
triage 2026-06-09). Both are recorded as **⚠ EXPIRED-CLOSURE reopen proposals** against their existing
fingerprints — **status not flipped** (D-09), both `humanMustPick`.

**Why.** A verification debt carried forward is a suppression nobody re-examines. Law 1 makes paying it the
cheap side: the alternative was to leave two `fixed` entries resting on premises this run's own executed
witnesses contradict, with a watch note as the only trace. The debt was payable in one agent-hour; leaving it
would have cost a full cycle of false assurance.

**Reversal cost.** Near zero. The PoCs are additive files in `workspace/`; nothing in `lib/` was touched and
no ledger status was changed. If the operator judges both residuals acceptable, they re-close both entries
with rewritten rationales — a `/ledger` command each.

---

## D-27 — Framed as INVALID CLOSURE, not as CODE REGRESSION — and that distinction is load-bearing

**Fork.** The two expired closures could have been filed as **regressions** (the finding reappeared) or as
**invalid closures** (the finding never went away; the reasoning that dismissed it did). The first is a
stronger-sounding signal and would have topped the run summary.

**Decision.** **Invalid closure.** Both entries state explicitly what is *not* being asserted: no code
regressed. story-014's owner-pinning of the minter and `dispatcherIndex` is **intact and proven intact** by
`test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED` (`BatchNFTMinter.sol:101`, resolved `:315-323`)
— and both entries carry a **DO NOT DISTURB IT** instruction.

**Why.** A false regression call is not a conservative error, it is a misdirection: it points the fixer at
the wrong commit and invites them to "restore" a guard that never broke, which on this contract means
touching the one leg that still holds. The honest claim is narrower and stronger — **ledger H-01's leg 2 fails
on its own predicate**. The closure read *"residual value-blindness only exploitable via owner misconfiguration
⇒ owner-driven ⇒ invalid"*, but at HEAD over-funding is **not an owner action at all**
(`BatchNFTMinter.sol:45-46`: *"Permissionless top-up. Anyone can seed the batch incentive with any ERC20 simply
by sending it here. No owner transaction is involved."*). Law 3 protects the owner-trusted surface; it cannot
reach a facet a permissionless third-party stream reaches without the owner. This is **not** a re-litigation of
Law 3 — the predicate Law 3 was applied to is false.

**The disposition that is wrong under either reading.** Leaving these `fixed`. `fixed` asserts the defect was
*eliminated*; here it was *dismissed* on a premise that has since become false. If the residual is still
acceptable, the correct disposition is `acknowledged` / `wont-fix` with a rationale rewritten against HEAD's
premises. Both entries say so.

**Bounding, so the escalation is not oversold.** D-22's read-only mainnet reads stand: zero present exposure,
no historical loss via this path, `batchMinter()` repointed, and no principal theft in any of the 11 replay
tests. The PoCs prove the **mechanic**, not present exposure. That bound is written into both ledger entries,
not just here.

**Reversal cost.** Low and symmetric — the operator picks reopen, or re-closes with a new rationale.

---

## D-28 — R-1: CLASS-016 raised Low → Medium, but the severity-auditor's proposed MERGE is REJECTED

**Fork.** The severity-auditor filed one severity dispute in the whole run, and it was an *understatement*
call: CLASS-016 (`userMigrate` self-advance, `6d2d6284…`) was filed Low while CLASS-005 (operator slice
ordering, `a0967cce…`) was escalated to Medium — even though CLASS-016's measured edge is **larger** (1666 bps
vs 1000 bps). Its preferred remedy was to **merge** the two into a single Medium with two actors and two
magnitudes; failing that, to raise CLASS-016 standalone.

**Decision, in two parts.**

1. **Raise to Medium — accepted.** The declared distinguisher was agency (*"any user can protect themselves
   with two transactions"*), and it does not survive the measurements: the victim and the loss are **the
   same** — Bob receives `36.986e18` in `test_ECON_A` and `36.986e18` in `test_ECON_H`. Same victim, same
   harm, same shared budget; only the beneficiary differs. C4 rates impact. Agency describes a mitigation
   available to an *attentive* user; it is not a bound on the harm to the *actual* victim, and every MEV
   finding in DeFi could be argued away as "the victim could have been faster."
2. **Merge — rejected, against the auditor's recommendation.** The dedup `doNotCollapseRegister` (from D-24)
   forbids exactly this pairing: **different actor, different mechanism, and fixing one does not fix the
   other.** Gating `userMigrate` closes the self-advance route and leaves slice ordering fully open; fixing
   slice ordering leaves self-advance fully open. A merge would let a fix for one **read as closing both** —
   the precise failure this project has been bitten by before. They are filed as **two Mediums, each with its
   own remediation**, plus a **reciprocal cross-reference** on both: *"related mechanism, independent fix
   required — see X."*

**Why record the rejection in the finding text and not only here.** A future reader who sees two adjacent
Mediums with one shared remedy (`targetAPY = 0` during the staggered window) will reach for the merge
themselves. The reasoning has to travel with the findings, not sit in a log.

**Reversal cost.** Low. If the operator prefers the merged shape, the two records collapse cleanly — but the
merged finding must then carry **both** remediations explicitly, or the merge re-creates the hazard it was
meant to tidy.

---

## D-29 — R-2: the two reopen candidates do NOT get `M-08` / `M-09` labels

**Fork.** The classifier labelled the expired-closure entries `M-08` and `M-09`. Every individual label was
correct at HEAD, but publishing them in the `M-nn` sequence makes the report read as **nine Mediums for
roughly seven distinct defects** — count inflation, as the severity-auditor objected on presentation grounds.

**Decision.** They are filed as **ledger-reopen proposals against their existing fingerprints**, severity
Medium-at-HEAD, in a distinct **⚠ EXPIRED-CLOSURE** section (`findings/reopen/`) — **outside the new-findings
numbering entirely**. The `M-08` slot went instead to the D-28 raise.

**Why.** They mint **no new defect**: the mechanic is already filed live as run-20 M-01, M-02 and L-07. What
they are is a **ledger-side consequence** — entries whose `fixed` status is no longer supported. Both
artefacts are genuinely needed (fixing the report without touching the ledger leaves two entries reading as
done), but numbering a ledger consequence as a new finding double-counts it to the reader while the finding
bodies say it does not.

**Reversal cost.** None — labels only. The fingerprints are the identity, and R-3's collision guard makes that
explicit everywhere.

---

## D-30 — R-3: label-collision guard, because run-20 mints its own `H-01` and `M-01`

**Fork.** Run-20's own `H-01` (`1c222d5485…`, `NFTStakerDepletion.depositFor`) and `M-01` (`fcaca00259…`,
BatchNFTMinter step-10 sweep) share labels with **three** different ledger entries: ledger H-01 `858e9e80…`,
ledger M-01 `521c20ad…` **and** ledger M-01 `b58b172e…`. This run discusses all five in the same documents,
several times in the same paragraph.

**Decision.** A collision warning is placed on **every** finding record, at the top of the run's label map
(`findings/LABEL-MAP.json`), in the ledger's top-level `notes`, in each affected ledger entry's note, and on
the carryover stub. **Every reference to a colliding label must be disambiguated by fingerprint.**

**Why.** The specific failure this prevents is a fixer reading "H-01 reopened" and patching `BatchNFTMinter`
when the High is in `NFTStakerDepletion`, or reading "M-01 is fixed" and believing the depletion rate-drift
arbitration is settled. Labels are per-run and reused; the fingerprint is the identity. This is cheap and
mechanical, and the cost of getting it wrong is a fix applied to the wrong contract.

**Reversal cost.** None.

---

## D-31 — R-4/R-5/R-6/R-7: four reasoning corrections applied without changing any label

Grouped because they share a rationale: **a correct label resting on a bad argument is a finding a reviewer
can dismantle.** None of the four changes a severity.

- **R-4 — CLASS-012 routes to spec-conformance (`F-20-07`), not to the security stream.** It claims no
  standalone loss and explicitly avoids double-counting M-01/M-02; reframed as an independent security Low it
  would be an overstatement. It is **not** suppressed and **not** downgraded — it gets no `L-xx` label, a
  ledger entry at Low, and a home in the spec-conformance report where the owner will see it. (validity-checker
  §9, boundary 6.)
- **R-5 — CLASS-007's stated ground is replaced.** The classifier's ground — *"filing it Low next to its
  Medium twin risks the operator-facing remedy being skipped"* — is **report-management, not severity**, and is
  exactly the reasoning that produces inflation. Struck. The substituted ground is availability: the repoint is
  an expected maintenance action, performed **in a different repository**, that kills the nudge outright, and
  **two of the three real dispatchers are unsafe today**. Also recorded on the finding: this is the **weakest
  Medium in the run** and the one to cut if a human trims exactly one.
- **R-6 — CLASS-001 (High) scope tightened, label confirmed.** The `info.amount > 0` guard at `:753` means only
  users with a **pre-existing position on the target** lose anything, and the PoC's 82,191.78 phUSD is a **lab
  magnitude, not a predicted loss**. Both are stated. High stands: *"not deployed"* is a deployment-status fact,
  not a severity bound — discounting for it would make every pre-deployment self-audit finding Low, inverting
  the point of auditing before deployment — and `NFTStakerMigrator`'s own NatSpec (`:9-11`) names
  `NFTStakerDepletion` as its documented target type.
- **R-7 — CLASS-003's bound corrected.** *"The observed mainnet shape still fails closed"* is weak, because
  `D` scales with `count`, **which the attacker chooses**. A precondition the attacker can create for
  themselves does not cap severity. The Medium now rests on the sounder bound: incremental extraction is capped
  by the caller's **own** donation — donate-forward defeat, not third-party theft.

**Why.** Same label, sounder footing, in all four cases. The alternative — shipping a correct severity behind an
argument the first careful reviewer can pick apart — costs credibility on the findings that matter most.

**Reversal cost.** None; no label moves.

---

## D-32 — The `test/` out-of-scope glob read NARROWLY, and the question escalated rather than answered

**Fork.** The project's `outOfScope` includes `test/`. Two findings sit on that boundary: **Q-01**
(`cabd4a3d…`, the §4.5 witness that never configures donations and so passes at `D == 0` while M-02 is live)
and **Q-02** (`d0ed2cf4…`, filed against `src/` but likewise a test-coverage defect).

**Decision.** Adopted the validity-checker's **narrow** reading and kept both at QA, **with the scope question
flagged for the operator to ratify rather than treated as settled**:

> `test/` in an `outOfScope` array excludes **hunting for vulnerabilities located inside test code**. It does
> not immunise the **assurance claim** the suite makes about in-scope code.

**Why.** A finding whose subject is "there is a bug in the harness" is out of scope — nobody deploys the
harness. A finding whose subject is "**the certification is false** — the witness for §4.5 passes without ever
exercising §4.5's premise" is a finding about **in-scope code's assurance status**, and its file path is
incidental; the blast radius is entirely in `src/`. Three concrete facts make this mechanical rather than a
judgement call: the witness calls `_fundPots()` and never `setPerMintDonations(...)`; it passes green while
M-02 is live on the exact property it claims to certify; and the **sibling §4.2 witnesses in the same file DO
configure donations**, so the omission is not a deliberate scoping choice. This project also has a recorded
prior instance of exactly this failure mode (the vacuous-invariant-harness memory).

**Why it is escalated and not just decided.** Under the broad reading Q-01 drops to a non-finding — and so
does the §4.5 tripwire and Q-02's. That is an operator call about what they want audited, not an audit call.
Q-01 is filed with `humanMustPick`.

**Reversal cost.** Low, and asymmetric in the safe direction: keeping a QA item costs a line in the bundle;
dropping it removes the only tripwire that would catch the M-02 class re-entering after the code fix lands.

---

## D-33 — The severity-auditor's net disagreement was UPWARD, and no downgrade was manufactured to balance it

**Fork.** The independent second opinion confirmed **23 of 24** findings, disputed exactly one — **upward** —
and explicitly declined to invent a downgrade for symmetry. The validity-checker separately returned **zero
invalid findings**. Two clean sweeps in the same run is an unusual result, and the tempting reading is that
the pipeline went soft.

**Decision.** Recorded as-is. No compensating downgrade was applied anywhere, and the auditor's own statement
of the asymmetry is preserved: *overstatement costs reviewer time; understatement can leave a live exploit.*
Where a downgrade and an as-is call were both defensible, the higher severity stood and was flagged.

**Why this is not softness, in evidence.** Seven escalations were **declined** and the declines are on the
record (M-02 held off High, Q-03 held at QA against a *failing* Tier-3 invariant, L-02 held at Low to avoid
double-counting H-01, L-01, Q-05, Q-02). Two Law-3 suppressions were made and made **visibly** (57 Aderyn
centralization instances dropped at D-12, with the count preserved). And the one severity dispute that did
arrive was resolved by *raising* a finding — which is the direction that costs the pipeline something.

**The counter-arguments that point downward are preserved, not buried.** Two are recorded verbatim on their
findings so the operator sees the strongest case against each Medium: (a) `BatchNFTMinter.sol:63-70` documents
the step-10 sweep as **intended** — a legitimate Medium→Low argument on M-01, answerable because the NatSpec
anticipates an incidental donation rather than a continuous dispatcher-fed pot that §4.1 makes claimable *only*
through the sweep; (b) M-06 is named as the weakest Medium and the one to cut if exactly one is trimmed.

**Standing bias declared.** This run resolves ties upward by policy (D-10) *because the operator is absent*.
Filing high-and-flagged is recoverable in one `/ledger` command; filing low-and-forgotten is not. When the
operator returns, the ten `humanMustPick` flags are the intended re-weigh surface — the severity distribution
should be read as **the pipeline's proposal**, not as a settled result.

**Reversal cost.** One `/ledger` command per finding, and every disputed call carries its counter-reading
verbatim so the re-weigh does not require re-deriving anything.

---

## D-34 — Bookkeeping forks resolved at this step

Recorded together; each was a small fork that would normally get a nod from the operator.

- **Scope snapshot refreshed 7 → 9 (discharging D-03).** The advisory `scope` array in
  `registered-projects.json` now lists `src/NFTStakerPriceScaledMigrateReady.sol` and
  `script/DeployBatchNFTMinter.s.sol` as one deliberate, reviewable change rather than a silent side effect of
  resolution. The array remains an **advisory hint**, never the gate.
- **`lastAuditedCommit` advanced to `0d1a0b2` and `lastRun` to `phoenix-nft-staking-20`.** Legitimate here
  because run-20 **did** perform full discovery — unlike the run-19 cold-pass-debt case (WATCH-18), where a
  PoC-replay-only verification deliberately left the baseline behind.
- **Low labels renumbered contiguously.** R-1 and R-4 removed two items from the Low sequence, so Lows were
  renumbered `L-01..L-07` rather than leaving gaps. Nothing had been submitted under the classifier's
  provisional labels, so no label is reused or skipped. The full old→new mapping is in
  `findings/LABEL-MAP.json`.
- **One carryover stub written** (ledger L-02 `e35388bf…`), plus a **visibility index** of the eleven open
  ledger entries this regression run did not re-observe. Absence of re-observation is **not** evidence of a fix
  and is labelled as such; no status is proposed for any of them (Law 1 — no open finding drops out of view).
- **Registers carried forward intact:** six fix traps, the do-not-action register (D-25's `batchMigrate`
  advice remains **actively harmful**; D-13's L-03 probe-vector trap is embedded verbatim **in the ledger entry
  text**, not only here; D-16's `balanceOf` re-read trap; TRAP-6 — fixing `_safePay` alone leaves the next
  misroute equally permanent), and the tooling coverage gaps (Semgrep vacuous; Aderyn did not analyze
  `script/DeployBatchNFTMinter.s.sol`, the file carrying open ledger L-04).

---

## D-35 — An invented "durable fix" was caught at validation and DELETED, not softened

**Fork.** Both `REOPEN-*` finding records carry no `recommendation` field — they are ledger-disposition
proposals, not code findings. The report-writer filled that gap by authoring a `totalPaid`-relative payout cap
and shipping it as **"The durable fix"**. The cheap resolution was to keep it with a caveat.

**Decision.** **Deleted from both reports.** Replaced with an explicitly *unvalidated* "property to establish"
("relate payout to realised spend"), carrying the caveat that killed the patch.

**Why.** The validator traced it and it does not work: `totalPaid` is `batchMint`'s named return, assigned
only at step 10 (`:384`/`:386`), *after* `_payRewards` at `:378`. Applied literally the cap is **0 at the
point of use**, so **every nudge payout clamps to zero** — the patch disables the feature it claims to bound.
It is further contradicted by two of this run's own findings (Q-04 "totalPaid floors at 0"; M-07 "totalPaid
under-reports the true dispatcher cost") and smuggles in an undeclared `maxNudgeBps`, converting
winner-take-all into spend-proportional payout — a design change backed by no PoC.

**The general rule this establishes.** An audit report must never ship a patch shape nobody validated.
Subordinating an invented fix to a real recommendation is *not* the same as attributing it: a reader cannot
distinguish an authored guess from H-01's genuinely source-derived `_safePayTo` swap. Where a finding record
has no remediation, the honest output is a property to establish, marked unvalidated — not a code block.

**Reversal cost.** None. The ledger disposition, its `alternativeIfYouDisagree` branch, and the NatSpec
correction (independently sound) were all retained.

---

## D-36 — Cross-reference label error (E-1) corrected in both reopen reports

**Fork.** Both reopen reports cited the mechanic as already filed "as M-01, M-02 and **L-07** (Low)". Run-20
`L-07` is `368e23fb22…`, a *staker* fork-drift finding on `NFTStakerPriceScaledMigrateReady` — **wrong
contract family**. The intended referent was `F-20-07` (`a7dffb34c9…`), which R-4 had deliberately stripped of
any `L-xx` label.

**Decision.** Corrected to `F-20-07` with fingerprint and the R-4 note.

**Why it is recorded rather than quietly fixed.** This is exactly the failure mode R-3's label-collision guard
exists to prevent — a wrong label sends a fix to the wrong contract — and it survived three earlier stages
before validation caught it. Worth knowing that the guard needed the validator to actually fire.

**Second-order catch, also recorded.** The correction string as first specified pointed readers at
`submissions/spec-conformance.md`, but that document contains only F-20-01…F-20-06; **F-20-07 is not in it**
(its record is `findings/faithfulness/F-20-07-*.json`). Following the instruction literally would have
reproduced the same wrong-destination class it was fixing. The applied text carries the concrete record path.

---

## D-37 — Residual precision question left OPEN for the operator, not resolved

**Fork.** E-4 established that `PoC_DepletionRateDrift.t.sol` never calls `unstake` — it exercises
`stake` + repeated `claim()`. The PoC characterisation was corrected everywhere. But `M-03.md:31` still says
*"story-020 closed the **`unstake`** path"*, which is a claim about the **fix**, not about the PoC, and was
therefore outside E-4's scope.

**Decision.** Left untouched and surfaced as an open question rather than silently rewritten.

**Why it matters (and why it is not blocking).** If the run-18 → story-020 lineage has been describing that
fix as closing the "`unstake` path" when the evidence actually exercises the `stake`/`claim` accrual path,
then the vocabulary around ledger M-01 `b58b172e…` is imprecise across several runs. **M-03's load-bearing
claim is unaffected** — the PoC imports only `NFTStakerDepletion` and never calls `migrateIn`/`depositFor`, so
it genuinely does not cover the migration path, which is the whole basis of the incomplete-fix argument.
Rewriting a multi-run characterisation of someone else's fix on an audit run's own initiative is exactly the
kind of change that should have a human behind it.

**Action owed.** When dispositioning M-03, confirm which code path story-020 actually changed.
