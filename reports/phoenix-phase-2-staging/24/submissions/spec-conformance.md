# Spec Conformance — Law 2 Faithfulness Report

**Project:** `phoenix-phase-2-staging`
**Run:** `phoenix-phase-2-staging-24`
**Commit:** `b9391b199ef38d7bf5066b6cd81d21b283a3a4e1` (branch `master`)
**Entry-point suite:** `promotion-ready` — `:snapshot`, `:dry`, `:broadcast`, `:resume`, `:verify`
**Story audited:** **story-076** (sole delta since run-23 `c4396b1`)

> This report is **separate from the QA bundle** (`qa-report.md`). It records **Law-2 story/spec deviations only**:
> places where the implementation, or the story document's own recorded facts and ticked checklist items, do not
> match each other. Each entry also carries its normal severity placement — an `F-xx` label is *in addition to*,
> never *instead of*, the H/M/Low grade.

| Label | Finding | Severity | Location | Deviation in one line |
|---|---|---|---|---|
| **F-01** | L-05 | Low | `DeployMainnetPromotionReady.s.sol#L2418-L2454` | A property the docstring says is "asserted in Phase 7" is asserted nowhere. |
| **F-02** | L-04 | Low | `DeployMainnetPromotionReady.s.sol#L1684-L1688` | Autonomous Decision 2's non-vacuous proof sits inside a gate `:resume` skips, and nothing re-proves it. |
| **F-03** | L-07 | Low | `src/views/DepositPageView.sol#L9-L15` | Concerns §4's stated premise is factually false on chain; the scope exclusion and both follow-ups rest on it. |
| **F-04** | L-06 | Low | `foundry.toml#L1-L7` | A ticked Preflight item certifies a build profile this repository does not have. |

No High-severity faithfulness deviation was found. **All four are Low.** All four are deviations of
**record vs. reality** — three in the script/verifier, one in the story's own written premise — and none of them
requires an attacker.

> **F-03 was recorded at Medium (as `M-01`) when this report was first written.** A **human triage decision on
> 2026-08-04** re-graded it **Low**, and it is now `L-07` in `qa-report.md` at status **`fix-pending`**. **Its
> faithfulness substance is unchanged** — story-076 Concerns §4's premise is still false on chain — and the
> fingerprint is unchanged. Only the severity placement moved.

---

## F-01 — Phase 4e's docstring promises a Phase 7 assertion that does not exist

- **Finding:** L-05 (`PR24-01`) · **Severity:** Low · **Status:** open
- **Fingerprint:** `4bb60f7984ef7282718d7c8e395b5fabe89b34d1667cfbfa970262da6979bb73`
- **Entry point:** `promotion-ready:verify`
- **Location:** `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol` · `_phase7_phlimboV3Assertions` · L2418-L2454

### The story text this deviates from

> **Story 076, Review Results item 1 (lines 825-833)**, restated in the **Auto-Completed [low] at line 889**:
>
> "Phase 4e's docstring (:1643-1645) says the no-pause property is *asserted in Phase 7*, and Phase 7 logs
> *NOT paused*, but no `require(!v2.paused())` exists there, so `VerifyPromotionReady` would print *NOT paused*
> for a V2 someone paused post-broadcast."

The human confirmation at **story lines 896-901** accepted only the conservation `[medium]`. This `[low]` is
**acknowledged in the story but NOT dispositioned** — it is recorded and then left open, which is why it is filed
here rather than treated as a known-and-accepted deviation.

### The deviation

`_phase4e_phlimboV3Cutover`'s docstring at **:1643-1645** states of the no-pause and no-promotion properties:
*"NOT DONE ANYWHERE IN HERE, both deliberate and both asserted in Phase 7"*.

Phase 7 asserts the no-promotion negative (`promoToken() == 0`, `promoPhase() == None`, :2407-2408). It carries
**no pause assertion at all** — only a banner comment `// ---- V2 wound down, NOT paused. ----` (:2418) and a
console line `"PhlimboV2: ... NOT paused"` (:2454). Exhaustive grep over both script files shows the suite's only
V2 pause check is `require(!v2.paused(), ...)` at :1748-1751, which sits **inside** `if (!_isConfigured("p4e_migrate"))`
— skipped on every resume leg — and is unreachable from `VerifyPromotionReady`, which overrides `run()` and calls
Phase 7 only.

### Why it matters as a faithfulness deviation

The drifted comment sits inside the one control surface whose entire purpose (story 075; ledger Medium
`2c53e944ca…`, **fix-pending**) is to replace unticked human checklist lines with executable assertions. A reader
auditing the cutover from the logs would conclude the property was machine-verified. On its own the harm is small
— a paused V2 at `totalStaked == 0` traps nobody — which is why the code-side grade is Low.

### Remediation

Add `require(!IPhlimboV2Like(PHLIMBO_V2).paused(), "PhlimboV2 is paused - the migration cannot be trusted and the
log below would be false")` to `_phase7_phlimboV3Assertions`, beside the existing `desiredAPYBps() == 0` check at
:2419. It is `view`, so `VerifyPromotionReady` inherits it for free — exactly the property story 076 relied on for
every other Phase 7 addition. **If the owner prefers to allow a post-cutover pause, delete the "NOT paused" claim
at :1643-1645 and the log line at :2454 instead — but do not leave both.**

---

## F-02 — Autonomous Decision 2's non-vacuous proof does not hold on the resume path the story also documents

- **Finding:** L-04 (`PR24-02`) · **Severity:** Low · **Status:** open
- **Fingerprint:** `7bec406d1d46af89a6b476dde3c9c632e081693a92bdcb3dc5170590d669484e`
- **Entry point:** `promotion-ready:resume`
- **Location:** `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol` · `_setDesiredAPYTwoStep` · L1684-L1688

### The story text this deviates from

> **Story 076, Autonomous Decision 2:** the `desiredAPYBps() == bps` read-back is **vacuous when `bps == 0`**
> (both real cases here), so `require(!p.apySetInProgress())` was added so that a missed 100-block commit window
> **fails loudly**.

That is the story's own stated remedy for a vacuous read-back — an explicit assurance that the failure mode is
detected.

### The deviation

The non-vacuous proof (`require(!p.apySetInProgress())`, :1826-1832) lives **entirely inside**
`_setDesiredAPYTwoStep`, which Phase 4e calls only from within `if (!_isConfigured("p4e_v3_apy"))` (:1684-1688).
`_trackConfig("p4e_v3_apy")` is stamped into the progress file during forge's **local pass**
(`_trackConfig` → `_writeProgressFileWithStatus`, :3009-3015) — i.e. **before** either `setDesiredAPY` transaction
is dispatched.

So if the second (commit) transaction is rejected or dropped on the Ledger, the progress file already records the
step as done, a `:resume` **skips it**, and PhlimboV3 is left latched mid-preview with the APY uncommitted. Neither
Phase 7 nor `VerifyPromotionReady` re-proves it: `v3.desiredAPYBps()` appears in neither (:2419 checks V2 only),
and `apySetInProgress()` appears nowhere outside `_setDesiredAPYTwoStep`. Phase 8's `_probePhlimboV3StakeClaim`
cannot substitute — it is preview-only **and** it deliberately arms its own 1000-bps probe APY whenever it reads 0
(:2530-2535), **masking exactly this failure**.

The story documents the resume path and documents the assurance; the assurance does not survive onto that path.

### Why it is Low today, and the trigger that changes that

The mirrored target reads **0** on chain today (`PhlimboV2.desiredAPYBps() == 0`), so a missed commit leaves V3 at
the value it was going to be set to and the residue is a stuck `apySetInProgress` latch. The defect is structural,
not conditional: the script mirrors V2's APY **live** at :1685, so any legitimate retune before the Ledger session
arms it, and a resume leg would then leave PhlimboV3 emitting nothing while every post-cutover assertion and the
whole verifier report read green. (Note: `ForgeLocalPassPrecedesBroadcast` is a **recurring trap** on this project.)

### Remediation

Add two `view` assertions to `_phase7_phlimboV3Assertions` so `VerifyPromotionReady` inherits them:
`require(!IPhlimboAPYLike(newPhlimboV3).apySetInProgress(), "PhlimboV3 left latched mid-preview - the APY commit
never landed")` and `require(IPhlimboAPYLike(newPhlimboV3).desiredAPYBps() == IPhlimboV2Like(PHLIMBO_V2).desiredAPYBps(),
"PhlimboV3 APY does not mirror V2's")`. The second must be sequenced against step 11 (which zeroes V2) — either
capture the mirrored target as a write-once baseline alongside `phlimboV2StakedAtCutover`, or assert only the latch.
Add the same `!apySetInProgress()` check for PhlimboV2 next to the existing :2419 check.

> **Shared-mitigation note (FR-24-04):** a single Phase 0 `require(PhlimboV2.desiredAPYBps() == 0, …)` pins the
> currently-observed safe value instead of merely observing it, and neutralises the live-trigger leg of L-02, L-03
> and L-04 at once, at zero cost today. This is a **mitigation note only — explicitly not grounds for consolidating
> those findings**; each retains a residual it does not close (here: the resume-skipped latch assertion).

---

## F-03 — Story 076 Concerns §4 states a premise that is false on chain, and the scope exclusion plus both follow-ups rest on it

- **Finding:** **L-07** (`PR24-06`, originally filed `M-01`) · **Severity:** **Low** — re-graded from Medium by **human triage on 2026-08-04**; see the note at the end of this section · **Status:** **`fix-pending`** (a fix is owed; **not** `acknowledged`)
- **Fingerprint:** `6b63ef6516ac1751c6611aa0de8273427425eba6b1d771824d4526adf76e7cea`
- **Entry point:** `promotion-ready:broadcast`
- **Location:** `lib/phoenix-phase-2-staging/src/views/DepositPageView.sol` · `constructor` · L9-L15

### The story text this deviates from

> **Story 076, Concerns §4, line 475:**
> "So **both views are bound to V2**, and the live deposit UI is on the deprecated one."

On that premise the story declares the view layer **out of scope**, and records two follow-ups:
**(a)** redeploy `DepositPageView` against V3; **(b)** move phlimbo-ui's deposit page onto ViewRouter resolution
"the way the mint page already is".

### The deviation — verified on chain at block 25678182

- `ViewRouter.pages(keccak256("deposit"))` → `DepositPageView` **`0x50D4443782bB9A6e8D65dAcd593684EDd3FF03b8`**
- that view's immutable `phlimbo()` → **`0x3984eBC84d45a889dDAc595d13dc0aC2E54819F4` — PhlimboV1**, *not* PhlimboV2 `0x6084a02C…`
- only the **deprecated** `DepositView 0x0725722b…` is V2-bound (redeployed under the story-049 follow-up, `mainnet-addresses.ts:12`)

The premise is therefore **false for the router-registered surface**. The ViewRouter deposit page is already one
generation stale **today, pre-cutover**, and will be two generations stale after Phase 4e. A documented scope
exclusion rests on a false basis: **the risk it waived was never the risk that exists.**

### Consequences the exclusion did not price in

1. **The recorded remediation is inverted.** Performing follow-up **(b) before (a)** migrates the live deposit page
   *off* a V2-correct view *onto* a V1-bound router view — a two-generation regression at the moment the UI is
   supposed to be repaired. The required **(a)-then-(b)** ordering is recorded **nowhere**: `story-dependencies.md:222`
   holds both items only as an HTML comment marked *"not yet a story"*, with no numbered dependency row and no
   sequencing note. This is a textbook **Law-3 footgun** — a competent, non-malicious owner following their own
   written follow-ups would be surprised to find they had regressed the deposit page a generation.
2. **A certain, universal post-cutover display defect.** Phase 4e empties PhlimboV2 to `totalStaked == 0`. The
   deprecated `DepositView` that the live UI actually reads (`useDepositViewPolling.ts:94`) is V2-bound, so **every**
   migrated user's deposit page reads a zero balance while their principal sits in PhlimboV3, for as long as the
   redeploy is outstanding.

**No asset is at risk.** Balances are wrong on a display surface, not in accounting; withdrawals, migration and
every value-bearing path are unaffected, and there is no attack path of any kind. The grade originally rested on
**protocol-function/availability** grounds — availability of correct protocol state to every migrated user.

**As triaged (2026-08-04) the deviation stands at Low.** The consequence in point 2 above is a **known and accepted**
outcome recorded in story-076 Concerns §4 itself, and is already covered by run-22's `Q-01`; the live UI reads
`DepositView` directly (`useDepositViewPolling.ts:94`) and never resolves through the stale router page, so today's
live blast radius is zero; and point 1's ordering trap is contingent on a follow-up `story-dependencies.md:222`
marks *"not yet a story"*. **What remains — and what F-03 records — is the factual error in the story: it says V2,
the chain says V1.** That is a Low-grade spec deviation, and it is still owed a fix.

### Remediation

Correct the premise in the follow-up record at `story-dependencies.md:222` — `DepositPageView` is on PhlimboV1, not
V2 — and **state the ordering constraint explicitly**: the phStaging2 redeploy + `ViewRouter.setPage("deposit", …)`
re-registration MUST land before the phlimbo-ui migration. Number both follow-ups as real stories rather than
leaving them as comments, since they go live the moment story 072 broadcasts. In the interim, add a read-only
Phase 7 / verifier NOTE logging `DepositPageView.phlimbo()` and `DepositView.phlimbo()` alongside `newPhlimboV3`,
so the drift appears in the cutover record rather than being discovered by users.

> **Human-review flag — RESOLVED 2026-08-04.** The severity-classifier's deliberate Low → Medium move was flagged
> `borderline: true` for human review. A **human re-graded it Low** on **2026-08-04** and set it **`fix-pending`**
> ("funds aren't lost but this is important and needs tending to"). This is a **human triage decision, recorded —
> not an automated re-classification**. **The (a)-before-(b) ordering guidance survives the re-grade unchanged** and
> remains the lead item of the remediation above. The **fingerprint `6b63ef65…` is unchanged**; severity is not a
> fingerprint input, so the ledger identity and history are intact. Full text now lives in `qa-report.md` § `L-07`
> (the standalone `submissions/M-01.md` was retired into that section).

---

## F-04 — A ticked Preflight item certifies a build profile this repository does not have

- **Finding:** L-06 (`PR24-07`) · **Severity:** Low · **Status:** open
- **Fingerprint:** `c544c9f6e6c40cdb9fbd3625da54151bdbe25ea03b7ddc71766c4ae292ee8e72`
- **Entry point:** `promotion-ready:broadcast`
- **Location:** `lib/phoenix-phase-2-staging/foundry.toml` · L1-L7

> **DISCLOSURE — this is a re-file, not a fresh discovery.** The `phlimbo-ea` ledger carries this **OPEN** as
> **V3-L-19** (Low), fingerprint `38aefbfbe6da599fc5250a2cc73125465c845480e34b6a63984b2febae4a053c`, which
> anticipated this exact situation from the phlimbo side. Run-24 contributes the **deploy-site instance** plus the
> **false story-076 premise**. V3-L-19 also carries an **unresolved Low-vs-QA severity dispute** awaiting human
> triage; that dispute travels with this entry and was **deliberately not re-decided here** (FR-24-02). L-06's Low
> applies only to the `phoenix-phase-2-staging` deploy-site instance, on site-specific grounds.

### The story text this deviates from

> **Story 076, Implementation Notes, line 382:** "Per house knowledge, phlimbo builds use legacy + optimizer with
> `via_ir` **OFF**."
>
> **Story 076, Preflight, line 538 — TICKED `[x]`:** "Confirm `forge build` succeeds with `PhlimboV3` and
> `MigratorV2V3` imported via the existing `@phlimbo-ea/` remapping, and that `PhlimboV3` lands under the EIP-170
> 24 KB limit **in this repo's profile (optimizer on, `via_ir` off)**."

### The deviation

`phoenix-phase-2-staging/foundry.toml:1-7` sets `optimizer = true`, `optimizer_runs = 10000`, **`via_ir = true`**.
This repo's profile is `via_ir` **ON**. By contrast `lib/phlimbo-ea/foundry.toml:6-15` sets `via_ir = false`, with
an in-file comment explaining that `via_ir` caches `block.timestamp` and breaks repeated `vm.warp`.

Every phlimbo-ea test, and every audit of `PhlimboV3` / `MigratorV2V3` (stories 022-031, audits phlimbo-ea-07..11),
therefore validated **legacy-pipeline** bytecode. Story 076's Phase 4e is the code that actually `CREATE`s both
contracts on mainnet, and it compiles them under phStaging2's **via_ir** pipeline.

The EIP-170 *purpose* of the ticked criterion is satisfied — `PhlimboV3` measures **14,529 B** here, 10,047 B of
margin (`forge build --sizes`) — so nothing is blocked. But **the tick was recorded against a build profile that
does not exist in this repository.**

### Why it matters

Not an exploit, and no defect is demonstrated: `via_ir` and legacy are both supported solc pipelines. What is
demonstrated is an **assurance gap at the deploy site** — the artifact that will hold user principal is not the
artifact the audit and test suites exercised, and the story's own preflight records the opposite. Deploy-gate/QA
class; the severity should not exceed what that supports.

### Remediation

Either **(a)** run phlimbo-ea's `PhlimboV3`/`MigratorV2V3` suites once under a `FOUNDRY_PROFILE` with `via_ir = true`
and record the result, accepting the documented `vm.warp`/`block.timestamp` caveat by adjusting only the affected
tests; or **(b)** set `via_ir = false` for this repo's build of the phlimbo-ea sources — V3-L-19 records the measured
fact that the legacy build is 15,979 B with 8,597 B of EIP-170 margin, so `via_ir` is **not** load-bearing for the
size limit and can be dropped freely.

Independently: **correct story 076's Implementation Notes (line 382) and the Preflight tick (line 538) to say
`via_ir` is ON in phStaging2.**

---

## Notes on scope and suppression

- **Known-issue suppression was unavailable and nothing was suppressed.** The registry declares
  `knownIssuesFile: lib/phoenix-phase-2-staging/known-issues.md`, which **does not exist at HEAD** `b9391b1`. The
  11 known issues are a registry-only cache dated 2026-01-09, roughly seven months older than stories 072-076.
  Recorded as ledger watchNote **KI-24-01**.
- **The dry run corroborated story-076's own numbers.** It reproduced Autonomous Decision 8 exactly — 16 stakers,
  1 migrate call, 0 skips, conservation `13095559131012692364262` on both sides, Phase 8 mint leg
  `8219178082191678` with 0 banked — and incidentally **cleared story-072's Kendu fee-on-transfer preflight**
  (sent == received == credited). Those legs of the stories are **faithful**; no F-label is owed for them.
- **Ancestor control read-only.** Medium `2c53e944ca…` (**fix-pending**, story 075's post-broadcast verification
  gap) is the ancestor of F-01 and of L-02. It was **read only** — not re-graded, not closed, and no `fixed` was
  proposed by this run.
