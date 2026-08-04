# Spec Conformance (Law 2 — Faithfulness) — `phoenix-phase-2-staging-23`

**Project:** phoenix-phase-2-staging
**Commit:** `c4396b19aea6b7b09573ba90e2e65ca9293d20a1` (`c4396b1`)  ·  **Branch:** `master`
**Entry points:** `promotion-ready:broadcast`, `promotion-ready:verify`
**Fork verification block:** 25670926
**Story:** `story-072` — *Mainnet NudgeStreamer cutover, MultiToken BatchMinter, Staker V2 migration*
**Story document (READ-ONLY, quoted not modified):**
`~/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/072-mainnet-nudgestreamer-cutover-multitoken-batchminter-staker-v2-migration.md`

---

## 0. Grading basis

Law 2 grades the implementation against the **story document**, not against a commit subject.
Story-072's acceptance criteria form a **46-item checklist**. As of `c4396b1`, **44 rows are
ticked** and exactly **two are not** — and those two unticked rows are, precisely, the two
faithfulness findings below.

That coincidence is the whole point of this report. Both unticked rows are `(Post-broadcast,
HUMAN step)` items: the story deliberately deferred them to a human because they cannot be
asserted before dispatch. Run-23 finds that **one of them is mechanisable and has in fact
already been mechanised** (F-01), and that **the other one's stated expected values are factually
wrong** against live mainnet (F-02). Neither is a coding defect in the ordinary sense — the
Solidity is faithful — but both are genuine story deviations, and Law 2 routes them here rather
than burying them in the QA bundle.

Both are graded **Low**. Neither is inflated: neither puts assets at risk, and F-01's underlying
mechanism was proven **working** on a live fork at this exact commit.

---

## F-01-072 — The mechanised form of checklist line 1197 exists, passes, and is gated behind `if (isPreview)`, so the broadcast path never runs it

- **Severity:** Low  ·  **QA label:** `L-01`  ·  **Fingerprint:** `2212c1c4e8c8cd2271cc3c0c5c7e9180d0e2597cfbbdd97631431724e899525d`
- **Entry point:** `promotion-ready:broadcast`
- **Location:** `script/DeployMainnetPromotionReady.s.sol:439` (`_phase8_previewSmokeTests`)

### The acceptance text it deviates from — story-072, line 1197 (UNTICKED)

> `- [ ] (Post-broadcast, HUMAN step) trigger one index-4 mint and assert `BatchDonatedViaPSM` fired — a green transaction is **not** evidence for the pooler.`

Note the story's own emphasis: *a green transaction is not evidence for the pooler*. The story
correctly anticipated the exact failure mode — a mint that succeeds while the donation silently
does not happen — and legislated a specific control against it.

### The deviation

`_probePoolerDonation`, inside `_phase8_previewSmokeTests`, performs **exactly the assertion line
1197 describes**: it triggers an index-4 mint and checks that `BatchDonatedViaPSM` fired and
`DonationSkipped` did not. It is written, it is correct, and this session's live-fork `:dry` run
**passed it green** (`BatchDonatedViaPSM = true`, `DonationSkipped = false`, USDC stream-buffer
delta 2485691).

Phase 8 is reachable only under `if (isPreview)`. The broadcast path never executes it, so the
acceptance criterion it discharges remains an unenforced human step. Compounding this,
`BalancerPoolerV2._psmDonate` is wrapped in `try/catch`: a post-cutover donation failure is
swallowed, the mint still succeeds, and every wiring assertion in `:verify` still passes — because
the wiring is genuinely correct. The wiring is not the thing that would be broken.

And the verifier built by story-075 to close the verification gap **explicitly declines this row**:
`VerifyPromotionReady.s.sol:85-86` states in its own epilogue that this remains *"STILL A HUMAN
STEP … line 1197"*.

So the suite ships without discharging an acceptance criterion **it is mechanically capable of
discharging, and has already written the code for**. That is the deviation.

### Why Low and not Medium

The Medium case ("protocol function impacted") was tested and rejected on two grounds. First, there
is no demonstrated impairment — the mechanism was proven working on a live fork at this commit, so
this is a missing **detector**, not a broken function. Second, the thing that would be
under-delivered is externally-derived yield routed onto a protocol-owned nudge pot, which this
project does not treat as a value leak in either direction. Consistency: run-22 graded its
`L-04` — the same *BlockingProbeGatedToPreviewOnly* family — as Low.

### Recommendation

Add a `promotion-ready:verify-mint` npm key that runs the **existing** Phase 8 pooler probe in
`PREVIEW_MODE` against live **post**-cutover state: prank OWNER, trigger one index-4 mint, and
`require` that `BatchDonatedViaPSM` fired and `DonationSkipped` did not. It needs no broadcast and
no signing, so it chains after `:verify` with the same `&&` discipline — converting line 1197 from
an unenforced human step into a fail-closed gate. **Until that ships, tick line 1197 explicitly
before disconnecting the Ledger.** Secondary: expose `BALANCER_ROUTER` and `SUSDS_IS_FIRST` via
public getters so Phase 0 and `:verify` can assert them at all — both are `private immutable` with
no getter today, hence unassertable.

---

## F-02-072 — Checklist line 1195 states expected values that are both stale and structurally incomplete against the state its own suite produces

- **Severity:** Low  ·  **QA label:** `L-02`  ·  **Fingerprint:** `d99738d3a05c44aa0171efb976164815c8dec5c8d75ab5762d0cfd894b364c29`
- **Entry point:** `promotion-ready:broadcast`
- **Location:** `script/DeployMainnetPromotionReady.s.sol:544-558` (`_phase0_preconditions`)

### The acceptance text it deviates from — story-072, line 1195 (UNTICKED)

> `- [ ] (Post-broadcast, HUMAN step) confirm on-chain: `configs(1..4,7)` resolve to the new dispatchers with price/growth preserved; the old DelayRelease holds 0 USDC and the old batch-minter holds 0 USDC **and is `paused()`**; **the rescued ~349 USDC (98.04 + 250.77) sits in the streamer's buffer, not on `newBM`**; the ratchet hook's 70 phUSD `mintDebt` was pulled and all five hooks now read `dispatcher == ` their new dispatcher with `ratio`/`recipient` intact; **phUSD's minter set is byte-identical to its pre-cutover state**; the new pooler holds the full 16,338.8190 BPT, is owned by the Ledger, and the old pooler holds 0; each V1 staker has `totalStaked == 0`, is unregistered from the Pauser, and its V2 counterpart holds the migrated total plus a non-zero phUSD budget; every donor's `nudgeStreamer()` returns the new streamer; `streams(newBM, USDC/phUSD/KENDU).duration` read 10/30/30 days.`

This is the story's designated post-cutover confirmation sweep — the compensating control for
everything `:verify` cannot mechanise. It is the *other* unticked row.

### The deviation

**This is a deviation in the story text itself, not in the implementation.** The code is faithful:
Phase 0 derives the BPT baseline **live** (`bptAtPhase0` == the measured
`16867526417628291567945`), no assertion anywhere references the stale literal, and the
`16,338.819e18` figure survives only as a self-contained fixture in
`test/BptBaselinePersistence.t.sol:96`. What is degraded is the **human control**.

Measured against live mainnet at `c4396b1` (fork block 25670926), two of the row's quoted figures
are wrong:

| Line 1195 asserts | Live measurement | Nature of the mismatch |
|---|---|---|
| new pooler holds **16,338.8190 BPT** | **16,867.5264 BPT** | stale (arithmetic drift) |
| rescued **~349 USDC (98.04 + 250.77)** in the streamer buffer | **530.761796 USDC**, decomposing as 99.224124 (old batch minter) + 380.000000 (DelayRelease) + **51.537672 (UniboostSCX residual prime)** | **structural** — a third component the checklist never names |

The second mismatch is the serious one: it is not an arithmetic drift but a **structural**
incompleteness. The control does not know what it is counting. A control that names two of three
sources will drift again the moment a fourth donor appears.

### Why this matters (Law 3 footgun — in scope)

A competent, non-malicious operator would be **surprised** to find every figure in a control they
were told to rely on mismatching, and the surprise pushes in a dangerous direction:

- **Benign branch (certain to occur):** the operator treats the mismatch as a real failure and
  raises an alarm on a healthy cutover. Confusion and delay — but line 1195 is *post*-broadcast, so
  it cannot leave a partially-applied cutover.
- **Dangerous branch:** the operator reconciles it as *"the checklist numbers are always a bit
  off"*, and the control becomes calibrated to be waved through. A **genuine** BPT shortfall or a
  missing buffer component on the day then reads exactly like the noise they have been trained to
  ignore.

The BPT half is partially backstopped — `:verify` consumes story-074's persisted write-once
baseline and re-runs the Phase 7 conservation assertion. **The USDC-buffer half is backstopped by
nothing**, and that is precisely the half whose decomposition is structurally incomplete.

### Why Low and not Medium

The code is correct and derives everything live; the primary quantity (BPT) is independently
re-checked against a write-once persisted baseline; and material harm requires a *compounding*
conditional — operator numbness **and** a simultaneous genuine shortfall. The branch that is
certain to occur (false alarm) is post-broadcast and cannot cause a partial application. Medium
would require a function or availability impact this cannot produce on its own.

### Recommendation

Stop hardcoding balances in a human checklist. Rewrite line 1195 to read: *"confirm the new
pooler's BPT equals the `BPT cutover baseline` printed by Phase 0 of the immediately preceding
`:dry` run, and the streamer buffer equals its final `collectNudge -> stream buffer now` figure"* —
the script already prints both, under a `--- stranded value (live) ---` header built for exactly
this purpose. Additionally, have `_printSummary()` emit a copy-paste **POST-BROADCAST HUMAN
CHECKLIST** block with the live-derived expected values filled in, so the operator compares against
measurements taken minutes earlier rather than prose written weeks earlier. When rewriting,
enumerate **all three** buffer components — or better, quote only the total the script prints.

---

## 3. Why F-01 and F-02 are kept separate

Both touch the story-072 checklist, so a collapse was considered and **refused** by the
deduplicator, a refusal carried through classification and preserved here. They are opposite
failure modes with non-overlapping fixes:

| | F-01 (line 1197) | F-02 (line 1195) |
|---|---|---|
| Shape | **enforceable but unenforced** | **stated but wrong** |
| Failure mode | fails **silent** | fails **noisy**, then numb |
| Fix direction | move an existing probe **into** an automated post-broadcast leg | **rewrite the prose** to reference live-derived figures |
| Fixing one… | …does nothing for the other | …does nothing for the other |

---

## 4. Explicitly NOT graded as faithfulness deviations

Recorded so the absence is visible rather than silent (Law 1):

- **`L-03` / F-02-orig** (`5c6d2c9e3b9806b8…`, verifier progress-file gate) — story-075 required
  *"every check a require"* and a standalone read-only verifier; **both were delivered**. The
  gate's semantics were never specified, so this is an uncovered residual, not a deviation.
- **`L-04` / F-03-orig** (`80a741a27fe0fded…`, unbound `baselines.bptAtCutover` provenance) —
  story-074's four rails all landed and one was **tightened**. Explicitly not a deviation. Note
  further that story-074's own conditional-Medium trigger (*"weakening any rail re-classifies L-02
  as Medium"*) **does not fire** and was **not** used to inflate the finding: no rail was weakened.
- **`Q-01` / F-04-orig** (`5e2e125056eb91ae…`, `_requireNoBroadcastFlag` naming) — no story
  specifies the guard's naming or the test's scanning strategy.
- **`L-05` / F-06-orig** (`f59e177a97c88429…`, snapshot address-set provenance) — story-072
  criterion (4), *"silently migrate the three NFTStakerDepletion instances"*, **is met**; no
  provenance check was ever specified. This is a **security** finding, not a spec deviation.
  **Corrected 2026-08-03:** this entry was filed during the run as `M-01` (Medium) and has since been
  **walked back to Low and relabelled `L-05`** — an adversarial PoC validation refuted its
  mid-sequence premise (forge's local pass precedes any broadcast, so the failure is an *atomic
  pre-broadcast abort*, not a partially-applied cutover). The fingerprint is unchanged. See
  `decisions.md` → **Decision 4**. Two figures quoted in the original record are also corrected: the
  three stakers hold **1 / 2 / 3 users** — the "2 / 156 / 13" in the withdrawn Medium were **stake
  units**, not user counts. The Law-2 grading above is **unaffected** by the walk-back.

---

## 5. Continuity — run-22's faithfulness findings

Run-22 tagged three findings `faithfulness: true` and reported them as `F-01`, `F-02` and `F-03`
in `reports/phoenix-phase-2-staging-22/submissions/spec-conformance.md`. **None has been triaged;
all three remain `open` in the ledger and are carried over in full this run** — the Medium at
`submissions/M-01-C1.md` and the Lows in `submissions/carryover/qa-report-22.md`.

| Run-22 | Ledger fingerprint | Substance | Status as of run-23 |
|---|---|---|---|
| `M-01` (F-01) | `2c53e944caee2e74…` | mint-authority check reassigned to an unticked box, verified on no path; checklist lines 1167 and 1190 | **open**; `fixed` **proposed, not applied** — story-075's verifier addresses it, but run-23's `L-03` is filed against that verifier |
| `L-05` (F-02) | `3c957109ef534043…` | a ticked criterion's second clause printed only as prose; the proving branch structurally unreachable | **open**, untriaged |
| `L-08` (F-03) | `d5d55f34c5d6ffa3…` | *"a donation on each of the four donor paths"* ticked; three run, and Autonomous Decision 5 rests on the missing two | **open**, untriaged |

**The through-line across both audits is one pattern:** story-072's checklist repeatedly ticks
rows whose verification is deferred to a human step that is never taken, or asserted by a branch
that never executes on the broadcast path. Run-22 found three instances; run-23 finds the two
remaining **unticked** rows are the same shape. `F-01-072` above is the cheapest structural exit
from that pattern, because the mechanised check already exists and already passes.

Also carried for continuity: run-22's cross-run recall gap **`MR-22-01`** counted six users of the
`_writeProgressFileWithStatus` local-pass idiom across the mainnet cutover scripts. Run-23 found a
**seventh**, and the first **inside a contract introduced specifically to close a verification
gap** (`L-03`). The gap was not narrowed by omission — it **widened**.

---

## 6. Summary

| | |
|---|---|
| Story checklist rows | 46 |
| Ticked | 44 |
| **Unticked** | **2 — lines 1195 and 1197, both reported above** |
| Faithfulness findings this run | 2 (`F-01-072`, `F-02-072`), both **Low** |
| Faithfulness findings carried from run-22 | 3, all still `open`, none triaged |
| Law-1 escalations from a story's own intent | **none** — no story-072 or story-074/075 requirement is itself unsafe |

Neither finding this run has an H/M security twin, so neither takes an additional H/M label; both
are cross-referenced from the QA report as `L-01` and `L-02`.
