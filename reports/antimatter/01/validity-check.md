# Validity Check — antimatter run-01

**Project**: antimatter · **Commit**: `0bb82d867dba43bc514a508800826f90436c2ee3` (`master`)
**Input**: `findings/classified.json` (19 findings) + `submissions/*.md`
**Stage**: C4 known-invalid / scope filter, applied after severity classification
**Date**: 2026-08-18

> **Nothing is deleted by this stage.** Law 1 — recall beats report-tidiness. Every ruling below,
> including the two INVALIDs, is a *disposition*, not a removal: the finding stays in
> `classified.json` and in the ledger with the ruling attached, so a later run reconciles it rather
> than re-discovering it.

---

## Verdict summary

| Label | Severity | Verdict | One-line reason |
|-------|----------|---------|-----------------|
| H-01 | High | **VALID** | Not the approve race; one grant of authority moves a second asset |
| M-01 | Medium | **VALID** | Non-obvious owner footgun (Law-3 carve-out), asymmetric fail-open |
| M-02 | Medium | **VALID** | Faithful-but-unsafe; NatSpec carries no suppression authority |
| M-03 | Medium | **VALID** | Root cause is Antimatter's own uncounted mint leg at `:236`, not the minter |
| M-04 | Medium | **VALID** | Surprising halves only; the obvious half was already suppressed |
| M-05 | Medium | **VALID (scope-caveated)** | Antimatter creates the 2x asymmetry; strongest fix is OOS |
| M-06 | Medium *(parked)* | **INVALID AS FILED / VALID RESIDUAL** | OOS root cause + stale pin; the first-party half survives via L-01/F-01 |
| L-01 | Low | **QUESTIONABLE** | Exploit leg needs a hook-bearing (non-standard) ERC20 |
| L-02 | Low | **VALID** | Non-obvious mutual lock, PoC'd |
| L-03 | Low | **QUESTIONABLE** | Symbolic-only witness; unreachable by any sensible rate |
| C-01 | Low | **QUESTIONABLE** | Trigger is an obvious owner act in an OOS contract; only the unobservability is first-party |
| C-02 | QA | **QUESTIONABLE** | Centralization inventory, not a defect; correctly already at QA |
| F-01 | Low | **VALID** | Spec-conformance channel, first-party |
| F-02 | Low | **VALID (non-security)** | Test-quality observation, correctly routed to spec-conformance |
| F-03 | Low | **VALID** | Falsely-exhaustive NatSpec; documented policy raises rather than lowers weight |
| Q-01 | QA | **VALID** | Naming/shadowing, correctly QA |
| Q-02 | QA | **QUESTIONABLE** | Matches "user input mistakes"; must never leave QA |
| Q-03 | QA | **QUESTIONABLE** | "Unused view function" — QA at best, by the letter of the list |
| Q-04 | QA | **INVALID AS A SUBMITTED FINDING** | Tool noise in non-production mocks with no exploit path |

**Net effect on the submission set**: the six individually-submitted findings (H-01, M-01…M-05) all
survive. One QA entry (Q-04) should move out of the numbered bundle into the tool appendix. M-06 was
already correctly withheld. Three QA/Low entries (Q-02, Q-03, C-02) are inventory-grade and must
never be elevated in a future run.

---

## Patterns tested against the whole set

| C4 invalid pattern | Result |
|---|---|
| Non-standard / weird ERC20 (except USDT) | Cleared globally; **one partial hit** — L-01 (see ruling) |
| Fee-on-transfer | Not filed. `annihilateFrom` fails **closed** on FoT via the `:230` residue check; already recorded as checked-and-cleared upstream |
| CryptoPunks | No hit |
| Approve race / `safeApprove` front-running | **No hit.** H-01 superficially resembles it and is expressly not it — see H-01 |
| User input mistakes / phishing | **One hit** — Q-02 (caller supplies `recipient == address(this)`) |
| Reckless admin (malice, or *obvious*-harm misconfig) | **No malicious-owner finding is filed anywhere.** Three obvious-harm items were already suppressed upstream (MR-02 self-registration; the "raise the rate to emit more" half of M-04; SA-008 Ownable enumeration). Verified independently. |
| Unused view functions | **One hit** — Q-03 |
| Speculation on future code without demonstrated root cause | **No hit.** M-06 is an *unverified claim about a real current upstream state*, which is a different defect — see M-06 |
| Automated-tool findings without a demonstrated H/M path | **One hit** — Q-04 |
| Root cause in an OOS parent / forked / third-party contract | **Adjudicated individually** for M-03, M-05, M-06, C-01 — see below |

**Scope basis used.** `registered-projects.json` → `antimatter`: `outOfScope: []`, so only the baked-in
`lib/**` denylist applies. First-party = `src/Antimatter.sol` plus `test/**` (including `test/mocks/**`).
`lib/antimatter/lib/phUSD-stable-minter` and `lib/antimatter/lib/flax-token-v2` are **nested third-party
pins and therefore out of scope** — findings whose *root cause* lives there are invalid as Antimatter
findings, findings where Antimatter *makes the call, defines the ratio, or can self-defend* are not.

---

## Rulings

### H-01 — VALID (High sustained)

The pattern name does not do the work here. Three candidate invalids were tested and all fail:

- **Approve race / `safeApprove` front-running — does not apply.** The approve race is a *timing*
  defect: an allowance is spent twice across a re-approval. Nothing races here. The victim's ERC20
  antimatter allowance is spent exactly once and correctly (Halmos separately *proved* the antimatter
  allowance falls by exactly `amount`). The defect is **authority scope, not ordering**: source
  re-read at `src/Antimatter.sol:214-237` confirms the sole `_spendAllowance` is over antimatter,
  while `:222` debits a **second asset** — the victim's stablecoin — on Antimatter's own standing
  approval, and `:236-237` deliver the whole ~2x phUSD to a caller-named `recipient`. `approve(bob, N)`
  on antimatter is de facto also an approval over the grantor's stablecoin. That is a distinct
  root-cause class from the approve race and is not on the invalid list.
- **User mistake / phishing — does not apply.** The victim performs exactly the two actions the
  protocol requires and documents: the stablecoin approval is *mandatory* to annihilate at all, and
  third-party annihilation is a shipped, unit-tested flow (`test/Annihilation.t.sol:130-141`) that the
  NatSpec at `:189-192` advertises. A user cannot "preview" a consequence that the approval UI cannot
  express — she is never asked about the second asset.
- **Intentional design — does not apply.** Even were it intended, Law 1 overrides Law 2, and an ERC20
  approver cannot consent to the movement of an asset she was not asked about.

Root cause is entirely first-party (`src/Antimatter.sol`), and the mitigation is one line in it.
Evidence is unusually strong (PoC + two invariant engines + clean Medusa shrink + deterministic replay
+ a Halmos refutation over the amount domain), so no element rests on assertion.

### M-01 — VALID (non-obvious owner footgun)

**Reckless-admin does NOT apply**, and the *asymmetry* is what proves it. The identical mistake in the
opposite direction (decimals overstated) fails **closed** with a revert, so the operator has positive
reason to believe the parameter is self-checking; the dangerous direction is absorbed in total silence
because both contracts make the same error and it cancels inside `calculateMintAmount` — no revert, no
event anomaly, no on-chain signal. Footgun test: a competent, non-malicious owner **would be surprised**
⇒ in scope. Post-arming, the exploitation is permissionless and needs no owner at all.

**Scope**: the misregistered `decimals` lives in the OOS minter's `stablecoinConfigs`, but Antimatter is
the contract that **reads it at `:250` and defines the pairing ratio from it at `:254-256`**, and it can
self-defend in one line (compare against `IERC20Metadata(stable).decimals()`). First-party. Valid.

### M-02 — VALID

"Intentional design flagged as a bug" was tested and rejected. Two independent grounds: (a) Law 1
overrides Law 2 — a faithful-but-exploitable design is reportable; (b) the only artefact stating the
intent is in-source NatSpec, which **carries no suppression authority**, and which F-03 shows to be
economically inaccurate on its own terms. Law-2 is separately *unresolvable* for this project
(no `storyDir`, no story tag, zero content hits across the stories tree), so there is no authority
anywhere that could bless the design. Not the "externally-derived yield = opportunity cost" class
either: this is phUSD minted against **no incoming value**, diluting non-consenting holders, not
protocol-owned yield being over-spent.

### M-03 — VALID, and the scope boundary falls on Antimatter's side

This is the one most likely to be mis-ruled as "root cause in the OOS minter". It is not.

- The *cap* (`maxMintPerDay`) belongs to `PhusdStableMinter` (OOS), and the minter's own accounting is
  **correct**: it charges exactly for the phUSD it issues at `:227`.
- The defect is that **Antimatter holds an independent FlaxToken mint authorisation and uses it at
  `:236` — `_phUSD.mint(recipient, amount)` — entirely outside the minter's counter**. That line is
  first-party. Nothing in the minter is broken; Antimatter routes half its issuance around it.
- Antimatter can self-defend without touching the minter (per-period cap on its own leg at `:236`), and
  the safe-config guidance is addressed to the operator of Antimatter.

Reckless-admin also does not apply: an operator entering X as a daily phUSD cap and receiving 2X is
surprised by definition — discovering it requires knowing a *second* contract holds an independent mint
right. Verdict **VALID**, root cause in scope.

### M-04 — VALID, with the invalid half already excised

The "raise the rate to emit more" half **is** an obvious owner consequence and is correctly suppressed
upstream (`law3Routing.suppressedAsObvious`) rather than counted toward severity. The finding rests on
the two *surprising* halves — that lowering the rate can never reach parity (a safety lever that cannot
do the job it appears to do, floor of 1x regardless of setting, because the AM leg at `:236` is
rate-independent), and that a rate change silently re-prices a *different* control (`maxMintPerDay`).
Both are non-obvious and undocumented on either side ⇒ footgun ⇒ in scope. The retained Halmos proof is
cited as scoping evidence (an arbitrary rate strands no assets), never as an all-clear — correct.

### M-05 — VALID, scope-caveated

**Root cause straddles.** The shared counter is the minter's, and the cleanest mitigation ("give the
annihilation path its own budget") lands in OOS code. But the finding is not a criticism of the counter:
it is that **Antimatter consumes the general on-ramp's budget while issuing 2x per unit of it**, an
asymmetry created wholly by Antimatter's dual-leg design at `:227` + `:236`. The alternative mitigation
already listed — charge the antimatter leg too — is a first-party change, and is the same fix as M-03.
So Antimatter *makes the call* and *can self-defend*: **not** an OOS-root-cause invalid.

Two honesty caveats to carry into the submission rather than treat as invalidators:
- The DoS requires **live antimatter emission**, which does not exist yet (PARK-003: zero hits for
  `antimatter` across phoenix-phase-2-staging). This is an *external requirement*, which C4 Medium
  expressly permits — it is not "speculation on future code", because the code and the path both exist
  today at `0bb82d8`.
- Confidence is `medium` and no PoC or invariant failure backs this one (unlike M-01/M-03). That is
  correctly recorded and must not be inflated in the write-up.

### M-06 — INVALID AS FILED (OOS root cause) / VALID RESIDUAL — and it is correctly parked

Three separate tests, with different answers:

1. **OOS root cause — HITS.** The claimed defect is that `PhusdStableMinter` makes a bare statement call
   to `IYieldStrategy.deposit` and discards the return value. That contract is a nested `lib/**` pin and
   is out of scope; the shortfall, if real, originates there. **As an Antimatter finding about the
   strategy's crediting behaviour, this is invalid.**
2. **Speculation on future code — DOES NOT APPLY.** This is the distinction the brief asked for and it
   matters. The claim is not about code that might be written; it is about a **real, existing upstream
   state** read from a stale nested pin (`lib/phUSD-stable-minter` @ `d6ed115`, itself pinned to a
   `043ff2c`-era vault). The correct label is **UNVERIFIED**, not speculative. Calling it speculation
   would wrongly imply there is nothing to check; there is — a specific, bounded, checkable question.
3. **Is it presented as verified? — NO, and this is correct.** Confirmed: `parked: true`,
   `status: PARKED-MANUAL-REVIEW`, `submittable: false`,
   `verificationStatus: "UNVERIFIED — severity label is PROVISIONAL"`, `plausibility: UNADJUDICATED`,
   attack path prefixed `(NOT DEMONSTRATED)`. **No `submissions/M-06.md` exists**, and both
   `submissions/README.md` and `qa-report.md` state the exclusion and its reason. The Medium label is
   explicitly a triage-ordering placeholder. Nothing to correct.

**Valid residual, and it is not gated behind the park.** The first-party half — that `:233` accepts any
non-zero `mintedForStable` instead of asserting against `minter.calculateMintAmount(stable, stableAmount)`
— is squarely Antimatter's own post-condition, is a self-defence Antimatter can implement unilaterally,
and is already carried unparked by **L-01, F-01 and M-04's recommendation**. So the OOS ruling costs the
report nothing actionable.

**Disposition**: keep parked. Do **not** submit, PoC as fact, or cite as a known shortfall. Resolve by
reading the **deployed** minter and strategy per the standing nested-pin rule (never from the nested pin);
if the deployed minter is the `043ff2c`-era build, close as not-applicable.

### C-01 — QUESTIONABLE (down-rank; do not submit as a centralization defect)

Split it: the *trigger* is `FlaxToken.revokeAllMintPrivileges`, which is (a) in an OOS nested contract
and (b) an owner act whose consequence — revoking mint rights stops minting — is **obvious**, i.e. the
reckless-admin invalid. Only the second half is first-party and non-obvious: **Antimatter exposes no view
of its own authorisation status**, so integrators cannot tell in advance that annihilation will revert.
Keep that half as a QA/informational observability note; drop the framing that presents an OOS owner
action as a centralization risk of Antimatter.

### C-02 — QUESTIONABLE (correctly already QA)

"No local kill switch" is a design-inventory statement, not a demonstrated defect, and is adjacent to the
admin-assumption invalid. It is honest as an inventory line at QA and must not be elevated. Note the
partial mitigation already in the tree: `setStablecoinEnabled(false)` on the minter is a real full stop.

### L-01 — QUESTIONABLE (reframe; keep at Low)

The demonstrated exploit leg injects phUSD **from the stablecoin's transfer hook** — i.e. it needs a
registered stablecoin that is a non-standard, hook-bearing ERC20. That is the C4 "weird ERC20" invalid,
and no such token is registered. The **valid** residual is token-agnostic and should carry the finding:
`mintedForStable` is a **balance delta used as an attribution**, so the `:233` guard is one-sided and any
phUSD arriving in-window is forwarded to a caller-chosen recipient. Same mitigation as F-01/M-06's
residual. Keep at Low; present the hook PoC as an *illustration of the weak guard*, not as the exploit.

### L-02 — VALID

Mutually locking setters, PoC'd in both orderings, first-party, and a non-obvious consequence of two
ordinary owner calls. Textbook footgun.

### L-03 — QUESTIONABLE (keep at Low, keep the honest caveat visible)

Two soft hits. (a) It is owner-driven — but non-obvious, since an operator reaching for a *throttle*
would not expect a **hard brick** (`PhUSDNotReceived` on the whole annihilation), so the Law-3 carve-out
holds. (b) It brushes "unrealistic edge case": the witness is symbolic-only (`rate = 1 wei`, recorded as
"a fuzzer over sensible rates would not reach it"). Keep it as a fat-finger footgun, and keep that
reachability caveat in the write-up — without it the entry overstates.

### F-01 / F-02 / F-03 — VALID (spec-conformance channel, not the QA bundle)

F-01 (no minimum-output guard on an already-irreversible burn) is first-party and shares M-06's residual
mitigation. F-02 is a *test-quality* observation — the "never expose a burn" trip-wire is a four-name
denylist rather than an invariant — which is not a vulnerability and is correctly routed to
spec-conformance rather than presented as a security finding. F-03 is the reverse of a "documentation gap":
the NatSpec asserts a redemption symmetry that does not exist and a 2x the code does not guarantee.
Per standing policy, in-source NatSpec carries **no suppression authority**, and falsely-exhaustive docs
*raise* weight rather than excusing the behaviour they describe. All three routed correctly.

### Q-01 — VALID (QA)

`toStableAmount` is a decimals-only rescale mis-readable as a phUSD preview, and the local `decimals`
shadows `ERC20.decimals()`. Real, first-party, correctly QA-band.

### Q-02 — QUESTIONABLE (matches "user input mistakes"; never elevate)

`recipient == address(this)` is supplied by the caller, so the C4 user-input-mistake invalid applies to
the *harm*. The residual observation — `recipient` is guarded against `address(0)` but not against
`address(this)`, so the guard set is inconsistent — is a legitimate one-line hardening note. Correct at
QA; must never move above it, and the PoC must not be presented as an attack.

### Q-03 — QUESTIONABLE ("unused view function", QA at best)

`approvedMinters()` copying an unbounded `EnumerableSet` to memory in a **view** is precisely the
"unused view functions — QA at best" item. No on-chain caller, no exploit path, no gas impact on any
state-changing path. Already at QA, which is the ceiling; retained as an informational note only.

### Q-04 — INVALID AS A SUBMITTED FINDING (retain as tooling inventory)

The brief's tension resolves cleanly once **scope** and **report-worthiness** are separated:

- **In scope: yes.** `test/**` and `test/mocks/**` are first-party and in scope under the default-in-scope
  denylist (`outOfScope: []`). "It's only tests" is *not* a suppression ground, and the scanning was
  correct.
- **A valid finding: no.** All three clusters (SA-011 ignored `transfer` return in `test_transfer`;
  SA-012 ignored `approve` returns across four test lines; SA-013 missing zero-checks in
  `ReentrantStable`) are raw tool output in **non-production mock/harness code with no exploit path and
  no deployed artefact**. That is exactly "common findings from automated tools without a demonstrated
  H/M exploit path", and mock files cannot produce one by construction — the mock is the thing being
  controlled by the test.
- **Disposition:** move it out of the numbered QA findings and into **Appendix A alongside the 4naly3er
  output**, as a "tool results accounted for" inventory table. Do not delete it — accounting for the
  tools' output is the legitimate purpose it serves, and the existing triage note already says so. It
  simply should not occupy a `Q-` slot, because a numbered QA finding asserts a claim about the protocol
  and this one does not.

Two supporting points, both already handled correctly upstream and re-confirmed here: 297 static results
were filtered before classification (recorded in `tier1/static-analysis-findings.json`), and the
audit-authored PoCs under `workspace/antimatter/test/audit/**` are **not** present in `lib/antimatter @
0bb82d8` — they must never be filed as project files nor cited as project test coverage.

---

## Cross-cutting confirmations

- **No malicious-owner vector is filed anywhere** in the set. Independently verified against all 19
  findings, not merely accepted from `law3Routing`.
- **Fee-on-transfer and rebasing** are not filed; the `:230` residue check makes them fail closed, and
  they are C4-invalid regardless. Correct on both counts.
- **USDT exception** is not engaged — no finding depends on USDT's non-standard approve or missing
  return value.
- **Every High/Medium that is submitted has a first-party root cause** in `src/Antimatter.sol`. The one
  finding with an OOS root cause (M-06) is the one finding withheld from submission.
- **PoC provenance** is stated honestly throughout; invariant PASSes are used as quantification, never as
  all-clears; Halmos TIMEOUTs are parked as non-coverage (MR-21). No validity ruling above relies on a
  PASS or a TIMEOUT.

## Actions for the report-writer

1. **Q-04** — relocate from the numbered QA findings into Appendix A next to the 4naly3er output. Keep
   the content and the triage note; drop the `Q-` label.
2. **C-01** — restate as a first-party *observability* gap (Antimatter cannot report its own mint
   authorisation), not as a centralization risk arising from an OOS owner action.
3. **L-01** — lead with the token-agnostic delta-as-attribution weakness; demote the hook-bearing-ERC20
   PoC to an illustration, with the non-standard-token caveat stated.
4. **L-03** — retain the "unreachable by any sensible rate; symbolic witness only" caveat in the body.
5. **M-05** — carry the two honesty caveats (emission not yet live; `medium` confidence, no PoC) into the
   submission text.
6. **M-06** — no change. Keep parked, unsubmitted, and labelled UNVERIFIED.

---

## Correction note appended 2026-08-18 (review pass) — body above unchanged

**This note is appended, not merged.** Everything above is the reviewer's dated record of what was
actually said and must be read as written; nothing in the body has been edited.

**Superseded:** the M-06 park rationale referenced above — that the claim rests on a *stale
`phUSD-stable-minter` pin* — is factually wrong. antimatter pins `lib/phUSD-stable-minter` at
`d6ed1156`, and that commit **is** the minter's remote `master` tip, so the **minter pin is current**.

**Corrected rationale:** the stale layer is one level deeper —
`lib/phUSD-stable-minter/lib/vault` is pinned at `043ff2c` while vault's remote `master` is `0110ce4`,
**11 commits ahead**, including stories 043/044/048/049, which introduced `deposit()` returning
`creditedPrincipal`. What cannot be adjudicated at commit `0bb82d8` is therefore **which
yield-strategy / vault version is actually deployed**, since the finding depends on the deployed
strategy's `deposit()` return behaviour — not on the minter's version.

**Re-check instruction:** read the **deployed** yield strategy (resolved from chain). **Do not
re-check the `phUSD-stable-minter` pin** — it is already current and would wrongly read as the park
being resolved.

The corrected rationale is carried in: `findings/medium/M-06-*.json`, `findings/classified.json`,
`findings/sanitized.json`, `findings/deduplicated.json`, `tier2/econ-findings.json`,
`manual-review.json`, `submissions/README.md`, `submissions/qa-report.md`,
`submissions/spec-conformance.md`, and the `am1m6` entry in `reports/antimatter/ledger.json`.

**Scope of this note:** rationale only. No severity, label, fingerprint, status or verdict recorded
above is altered by it — including this document's own rulings, which stand as issued.
