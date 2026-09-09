# Sanitization Report — phoenix-nft-staking run-25

> ## ⚠ SUPERSEDED IN PART — M-01 AND M-02 WITHDRAWN (2026-07-26)
>
> **Run-25 `M-01` (`pns25m1` / `DEDUP-25-01` / ledger `96823199d298…`) and `M-02` (`pns25m2` /
> `DEDUP-25-02` / ledger `c7a410602b29…`) were WITHDRAWN by owner correction on 2026-07-26 and are
> now ledger status `false-positive`.** Every reference below that treats M-01 or M-02 as a live
> Medium — including cross-references, re-weigh recommendations, KI-scope determinations and
> "value is priced in M-01" pointers — is **superseded**. See `submissions/M-01.md` for the full
> reasoning.
>
> **In one line:** the nudge pot is funded by *externally-derived yield on protocol-owned capital*,
> never principal and never user deposits, so a pot exceeding one qualifying batch's cost is an
> accepted **subsidy rate / marketing spend** (opportunity cost), not a value leak. `NudgeStreamer`
> meters release so the market finds a clearing price; empirically the pot has never once reached
> 50 % of the qualifying cost before someone minted. Recorded as `registered-projects.json` **KI #16**.
>
> **Still reportable (Law 1 — narrow suppression):** (a) the pot leaving without `nudgeSize` real
> mints paid; (b) `refund > paymentAmount`; (c) a non-qualifying batch extracting pot-sized value;
> (d) **a claimant taking other users' money** — which is why **M-03 survives** (forfeited sub-dust
> residue is other callers' money), re-weigh to **Low** *proposed*, not applied.
>
> **Run-25's reading of KI #15 carve-out (d) was too broad** — (d) covers *accidental* over-funding,
> not a deliberately-set subsidy rate. Every MR-05 / "re-weigh" / "acceptance-scope drift"
> recommendation below that rests on that reading is **withdrawn**.
>
> **Ledger entries `43e8c48626ee…` and `858e9e807abe…` are untouched** — run-25's re-weigh of them
> is **withdrawn**; their `wont-fix` rationale stands unchallenged. The **surviving accurate residue**
> of M-01 is the documentation mismatch already filed as **L-02** (`75305ec0…` / `a7dffb34…`), whose
> correct fix is to **restate the sentence as a subsidy policy, not to add a code bound** — and no
> value claim attaches to it.

---

- **Project**: `phoenix-nft-staking` @ `5015f1b` (regression of story-029, baseline `d75229d`)
- **Input**: 11 consolidated findings (`findings-deduped.md`)
- **Known issues applied**: 15, from `registered-projects.json` (`knownIssuesSource`: `lib/phoenix-nft-staking/CLAUDE.md`, story-008 rewrite) + the C4 known-invalid list
- **Ledger reconciled against**: `reports/phoenix-nft-staking/ledger.json` (69 entries: 44 open, 15 wont-fix, 4 fix-pending, 3 submitted, 2 false-positive, 1 fixed; `lastAuditedCommit d75229d`, `lastRun phoenix-nft-staking-24`) — **READ-ONLY. No ledger write was performed. finding-manager owns writes.**

| metric | count |
|---|---|
| input findings | 11 |
| **passed (survive to classification)** | **9 new + 1 still-open recurrence = 10** |
| suppressed | **1** (DEDUP-25-09) |
| flagged for human review | **3** (DEDUP-25-05, DEDUP-25-07, DEDUP-25-09) |
| declined suppressions recorded | 3 |

---

## 1. KI #15 — VERIFICATION OF THE CARVE-OUT (the load-bearing question)

**The carve-out exists exactly as the deduplicator described.** KI #15's text, read directly, ends:

> "SCOPE OF THIS SUPPRESSION IS NARROW (Law 1) - the following remain REPORTABLE at full severity and are NOT covered: (a) any path where the pot leaves without the caller paying for nudgeSize real mints; (b) any path where refund > paymentAmount; (c) any path where a NON-QUALIFYING batch extracts pot-sized value (a recurrence of yield-claim-nft d06e3191.../ycn19h1 or phoenix 2d34673536...); **(d) the aggregate over-funding class (858e9e80..., and the run-22 sigma-pots Medium), which is about the pot being too LARGE relative to cost - a different claim from the comparison being easy.**"

**Consequences applied:**

- **DEDUP-25-01 and DEDUP-25-03 are NOT suppressed.** Both are squarely class (d): they are claims that Σ(pots) is too LARGE relative to the qualifying cost (4× at the project's own fixture; and self-arming without any funding action). Neither claims "the comparison is easy" — the accepted claim. They pass through at full severity.
- **DEDUP-25-02 is NOT suppressed** and is additionally *outside* KI #15 on a second, independent ground: it **falsifies KI #15's own stated premise**. The acceptance rests verbatim on *"the pot is by construction a fraction of the cost … every claim is net-positive for the protocol"*; with `NudgeRatchet._dispatch` recycling 100 % of the qualifying cost back into the pot — **metered** via `forceApprove(streamer, bal)` + `collectNudge(...)` at `NudgeRatchet.sol:156-161` @ yield-claim-nft `d4cc563`, NOT the deleted `:100` leaf transfer; `NudgeStreamer` is value-conserving so total delivered = total deposited, making the falsification **timing-independent**, the claim is cash-neutral to the protocol and no code bounds the relation. An acceptance covers the risk **as it stood**; it cannot cover a risk whose stated bound does not exist.
- **The four claims KI #15 genuinely suppresses are absent.** I checked each of the 11 against *"batching is profitable"*, *"the pot is sniped by MEV bots"*, *"payment token should not be whitelisted as a nudge token"*, *"setNudgeTokenWhitelist no longer rejects the payment token"*. **None of the 11 states any of them**, and no writeup should reintroduce them. `scan-code.md` §C, `scan-econ.md` §5 (ECON-004) and `manual-review.json` MR-05 each independently record the same non-filing.
- **Carve-outs (a)/(b)/(c) are clean at `5015f1b`** and mint nothing: no path releases the pot without `nudgeSize` real mints; `refund > paymentAmount` is invariant-proven impossible (`invariant_RefundNeverExceedsPaymentAmount`, 128,000 calls, both configurations); a non-qualifying batch takes nothing (`test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing`, passing, plus `invariant_PotOnlyLeavesViaQualifyingPayout`). **`ycn19h1` is genuinely closed at the root.**
- **ACCEPTANCE-SCOPE DRIFT — ROUTED TO THE HUMAN, NOT DECIDED HERE.** Story-029 widened the surface KI #15 was written over in three respects (MR-05): the pot set grew, the stated premise is falsified, and the accepted risk was *static* (framed as an owner over-funding event) whereas the delivered risk is **self-arming** — 6-8 mints via the ratchet channel, 72-744 batches via the dust channel, with **no funding event at all**. Recommended: re-confirm the 2026-07-25 acceptance against the enlarged surface, or narrow it. **Do not treat it as covering DEDUP-25-01/-02/-03.**

---

## 2. Suppressed findings (each named with the specific rule and reason)

| id | label | disposition | rule | reason |
|---|---|---|---|---|
| DEDUP-25-09 | Q-02 | **SUPPRESSED as a standalone finding; residual MERGED FORWARD into DEDUP-25-08** | **C4 known-invalid**: *"Non-standard/weird ERC-20 tokens (except USDT)"* + *"Fee-on-transfer tokens (unless explicitly in scope)"* | The exploit requires the owner-configured `primeToken()` to be **simultaneously** fee-on-transfer **and** to expose a sender-side transfer hook (ERC777 `tokensToSend` / ERC1363 callback). Two weird-ERC20 properties at once, neither in scope, no in-scope token exhibiting them (`NudgeRatchet` in fact *mandates* plain 6-decimal USDC at its constructor). Selecting such a token as the prime token is an **obvious-harm** owner action, so Law 3 suppresses rather than excepts it. |

**This is not a silent drop (Law 1).** Three things are preserved:

1. **The token-agnostic residual survives**, folded verbatim into DEDUP-25-08 (Q-01) as an explicit sub-paragraph: *"`budget` is a one-shot measurement pinned once at `:581` and never re-validated, so any post-`:581` erosion of this contract's payment-token holdings is charged to `P`, silently."* That claim needs **no** weird token — P-03 ranks a negative-rebase prime token as an independent mechanism, and DEDUP-25-08 already owns the false-comment defect at the same site. The C4 rule invalidates the *weird-token exploit narrative*, not the *unreconciled-measurement residual*.
2. **P-04's DoS tail survives** in the same place: once erosion exceeds `P + D`, the step-9/10 swap turns a silent pot shrink into a `batchMint` **revert on the payout leg**.
3. **This suppression is flagged for human review** — see §4, FLAG-02.

### Declined suppressions (recorded so they are not re-litigated)

| candidate | KI / rule that *nearly* applied | why suppression was DECLINED |
|---|---|---|
| DEDUP-25-04 (L-01), DEDUP-25-02 (M-02) | **KI #1** — *"Owner trust assumptions … centralization is by design"*; C4 *"Reckless admin mistakes"* | Law-3 **exception**: both are *non-obvious* footguns. DEDUP-25-04's bad arm is not a hypothetical repoint at all — `NudgeRatchet`'s constructor **requires** a 6-decimal token (`NudgeRatchet.sol:84` @ `d4cc563`), so `DUST_THRESHOLD = 1e6` is structurally *one whole payment token* **on the intended path, by upstream deploy-time enforcement**. DEDUP-25-02 composes two settings that are each the contract's designed purpose. A competent, non-malicious owner would be surprised by both consequences ⇒ footgun ⇒ in scope. No malicious-owner vector is asserted anywhere. |
| DEDUP-25-01 (M-01) | C4 *"Reckless admin mistakes"* (the arming config) | `docs/multi-token-nudge.md` §4.1 **affirmatively blesses** the collision configuration as *"permitted and safe, not forbidden"*. An owner following the project's own documentation is not committing an admin mistake. |
| DEDUP-25-01 / -02 / -03 | **KI #15** | Excluded by KI #15's **own carve-out (d)**, verified verbatim in §1. |
| all 11 | **KI #3, #5, #6, #7, #8, #9, #10, #11, #12, #13, #14** | Not applicable — every one of these governs `NFTStaker*` emission/accrual/migration semantics. `git diff --stat d75229d..5015f1b` changes exactly one `src/` file and it is `BatchNFTMinterMultiToken.sol`. NM-07 independently confirmed **zero** Linear-Depletion signature hits in the audited file. Checked-with-no-match, not skipped. |
| all 11 | **KI #2, #4** (pauser trust, live hook rotation) | No finding rests on pauser behaviour or on hook-rotation timing. |
| all 11 | C4 *"Common findings from automated tools without demonstrated HM exploit path"* | The static-analyzer output that fits this description was already routed to `manual-review.json` MR-01/MR-03 by the deduplicator (visible channel). None of the 11 is a bare tool hit; each carries a hand-verified path. |

---

## 3. Surviving findings (10)

| id | label | severity carried | origin | note to severity-classifier |
|---|---|---|---|---|
| DEDUP-25-01 | ~~M-01~~ **WITHDRAWN (false-positive, 2026-07-26)** | ~~Medium~~ **n/a** | **WITHDRAWN** | KI #15 carve-out (d). Re-file disclosure against `43e8c486` + `858e9e80` is **mandatory and must survive into the submission** — prior entry named, `triageReason` quoted, re-file basis stated. Neither wont-fix is overridden. |
| DEDUP-25-02 | ~~M-02~~ **WITHDRAWN (false-positive, 2026-07-26, with parent)** | ~~Medium~~ **n/a** | **WITHDRAWN** | Distinct root-cause class (cross-contract value recycling); no ledger match. Independently falsifies KI #15's premise. |
| DEDUP-25-03 | M-03 | Low → **flagged for Medium re-weigh** | **NEW** (own bucket: **expiring closure**) | Per `expired-closure-vs-regression`: **NOT a regression** — no patch was reverted, so the writeup must not send anyone to restore one. Correct disposition is a **standing monitor** on `P` vs `nudgeSize × price`. |
| DEDUP-25-04 | L-01 | Low (Medium argument recorded) | **NEW** | No dust-threshold entry exists anywhere in the 69. The 6-decimal arm is mandated upstream, not hypothetical. |
| DEDUP-25-05 | L-02 | Low/QA | **STILL-OPEN (recurrence)** — see §4 FLAG-01 | **Do NOT regenerate a report this run.** Carry the originals forward in full. |
| DEDUP-25-06 | L-03 | Low (watch-note) | **NEW** | The conditionality on `ad36260f`'s propose-`fixed`. Must ship *with* that proposal so the fix is not read as unconditional. |
| DEDUP-25-07 | L-04 | Low (watch-note) | **NEW** (partial overlap) — see §4 FLAG-03 | Fourth clone under fork-drift watch. |
| DEDUP-25-08 | Q-01 | QA | **NEW** | **Now also carries DEDUP-25-09's token-agnostic residual** (unreconciled one-shot `budget` measurement) and P-04's DoS tail. |
| DEDUP-25-10 | Q-03 | QA | **NEW** | Future-regression trap; pin both obligations at the `:580` `min` site. |
| DEDUP-25-11 | Q-04 | QA | **NEW** | Candidate merge with DEDUP-25-05 at report time (F-25-03's own note). Adjacent to open ledger `a7dffb34c990…` but a **different doc section and a different claim** (scope overshoot at §4.1, vs false premise at §1) — the ledger explicitly forbids collapsing doc/code twins. |

---

## 4. Flagged for human review (3)

**FLAG-01 — DEDUP-25-05 is a RECURRENCE of two *open* ledger entries, not a new finding.** Semantic match, high confidence:

- `75305ec0242b81580370518010c737b002a788ded54868271aec77d0c4542fa9` — **L-04, low, `open`**, `src/BatchNFTMinterMultiToken.sol :: batchMint (gate :352, payout :452-461)`, *"The NatSpec honeypot dismissal — 'the pot is by construction a fraction of the cost of the nudgeSize mints' — is asserted as an invariant but enforced nowhere."* Same contract, same function, same root-cause class; only the line numbers drifted (`:352` → `:507-511`) across the story-025/029 rewrites.
- `a7dffb34c9904a7fa9fb9e5f831bb72c04f70cd239b5631dda9d25bf5845ce51` — **F-20-07, low, `open`**, the **doc-site twin** at `docs/multi-token-nudge.md §1`.

**Disposition**: `origin: "still-open"` for both; bump `lastSeenRun` to `phoenix-nft-staking-25`; **do not regenerate a report this run**; **carry both originals forward in full** to `submissions/carryover/` (never a pointer stub). `75305ec0`'s note is explicit — *"⚠ DO NOT COLLAPSE THE TWO — different artefacts, different fixes"* and *"do not re-add the value claim on this entry"* (the anti-double-counting split with the nudge lineage is load-bearing). Run-25 honours both: DEDUP-25-05 carries no value claim; the value lives in DEDUP-25-01.

**Delta worth a human's attention, recorded rather than filed**: the docs were **rewritten in this range** and the false "by construction" sentence was **re-asserted**, and it is now the quoted justification for KI #15's suppression rule. A false premise propagated into a suppression rule is a Law-1 recall concern. That is an argument for *escalating the existing open entries*, not for minting a twelfth finding.

**FLAG-02 — DEDUP-25-09's suppression (C4 weird-ERC20 / fee-on-transfer).** Surfaced because the finding sits one owner-setter away from being in scope: `primeToken()` is owner-repointable, so the "not in scope" judgement is a statement about *current token selection*, not about the code. If any future `dispatcherIndex` resolves to a rebasing or hooked prime token, **re-open it** — and note that its residual is already live inside DEDUP-25-08 regardless, via the negative-rebase mechanism, which needs no weird-token exemption at all.

**FLAG-03 — DEDUP-25-07 partially overlaps existing ledger coverage; one leg is genuinely unanchored.** Verified against the ledger:

- The **approval leg** (`BatchNFTMinter.sol:284`, `type(uint256).max`) *is* covered: `ad36260f`'s `relocation.appliesTo` reads *"BOTH — frozen :284, new :360"*, and its 2026-07-25 note keeps scope over the frozen file explicitly (*"that file is still unfixable and the operational controls still stand"*). `ad36260f` is `fix-pending` ⇒ never suppressed ⇒ this leg stays visible.
- The **`balanceOf`-sweep leg** (`:280`, `:305-307`) is **NOT anchored on the frozen file**. `858e9e80`'s own note states it: *"⚠ STILL UNANCHORED: the FROZEN, MAINNET-DEPLOYED src/BatchNFTMinter.sol retains this same single-token nudge lineage verbatim … and has NO ledger entry of its own; this entry anchors the multi-token file only."*
- Open entry `c847207db213…` (M-02, `open`, medium) is fork drift on the same file but a **different root cause** (missing `ReentrancyGuard`) — related, **not** a duplicate; do not collapse.

**Disposition**: kept as a Low watch-note, `origin: "new"`, with the coverage map above attached. The question it exists to force — *is V1 separately deployed with a pot?* — is for the triager. Per `919b71fde692…` (open) neither live `BatchNFTMinter` instance has a pauser, so if it *is* funded there is no break-glass.

---

## 5. Ledger reconciliation verdicts (READ-ONLY — verified against the actual entries)

### 5.1 The four verdicts I was asked to verify

**`ad36260fc91f6842edf20e13b32f03b645683d2834499f46f835f0e8bff09b6d` — M-07, `fix-pending` — CONFIRMED COMPLETE. `origin: "propose-fixed"`. PROPOSAL ONLY — a human applies it.**

Ledger root cause: *"`forceApprove(nftMinter, type(uint256).max)` lets an under-funded batch silently spend the contract's own payment-token balance."* Verified at source, not inherited:

| Requirement for the old exploit | Status at `5015f1b` |
|---|---|
| A standing allowance wider than one mint | **gone** — `:624` `forceApprove(address(nftMinter), price)`, an absolute write of the exact next charge |
| The minter able to draw beyond the caller's credit | **gone** — `:623` `if (price > budget) revert BatchMint__PaymentBudgetExhausted(i, price, budget)` executes *before* the approval is written |
| Any residual allowance after the call | **gone** — `:631` `forceApprove(minter, 0)`, unconditional on every non-reverting path |

`NFTMinterV2._executeMint` performs exactly one debit per `mint` and it is the sole `transferFrom` in that file, so aggregate outflow is `Σ price_i ≤ budget ≤ credited`: the pot `P` is **structurally unreachable by the minter**, not merely harder to reach. No residual path was constructible. The imported PoC pins the *new* revert (`test_PaymentTokenAsNudge_underFundedBatchRevertsWithBudgetExhausted`) rather than the symptom.

**The remedy also matches the tighter 2026-07-25 plan, not the superseded one.** The ledger note requires a cap *"at a SINGLE MINT'S EXACT PRICE, re-asserted ABSOLUTELY (never by delta) on every iteration, then zeroed after the loop"*, with the refund sourced solely from a memory-tracked budget so `refund <= paymentAmount` holds **by construction** (the run-20 D-35 property). All four properties are present at `:623/:624/:631/:580` and D-35 is now **invariant-proven** (`invariant_RefundNeverExceedsPaymentAmount`, 128,000 calls, both configurations).

⚠ **Conditions to attach to the proposal** (so it is not read as unconditional): DEDUP-25-06 (the cross-repo lockstep invariant that makes it hold is silent and un-asserted locally) and DEDUP-25-07 (the frozen V1 leg is *unfixed by design and stays in scope* — do not let a `fixed` flip on the multi-token file be read as closing the frozen file).

**`1c222d54852333a8a166c267329d3b4c02adb65faa2842bbc1e48f3c8b88bd37` — H-01, `fix-pending` — CONFIRMED NOT IMPLICATED. UNTOUCHED.**

Verified: ledger `contract` is `src/NFTStakerDepletion.sol`, `function depositFor`, `:756`. `git diff --stat d75229d..5015f1b` lists exactly one `src/` file and it is `BatchNFTMinterMultiToken.sol`. Code **unchanged** since `lastAuditedCommit`, finding neither fixed nor regressed. Classification: **`FIX-PENDING (fix not yet landed)`** — expected, low signal, *not* the `⚠ FIX-PENDING STILL LIVE` heading (that requires the code to have changed). Not suppressed, not re-analysed, **carried forward**. `lastSeenRun` bump only.

**`43e8c48626ee74b51d538bd9ed12bf4898b976818f6fb44fea844ff3757daefe` — M-01, `wont-fix` — ⛔ **RE-WEIGH WITHDRAWN 2026-07-26. STATUS NOT TOUCHED, RATIONALE STANDS UNCHALLENGED.**

Verified premise inversion. Its 2026-07-24 operator triage reads verbatim: *"Owner-accepted as a bounded operational property … **Safe config remains: keep Σ(pot_i) < nudgeSize*mintPrice** … RE-ARM trigger unchanged: re-rate the moment a live/pending deployment funds the whitelist so Σ(pot_i) approaches/exceeds one qualifying cost."*

- **Inverted by DEDUP-25-01**: that Σ was computed over a pot set that structurally **excluded** the payment token, because at triage time `_snapshotRewards` skipped it at runtime. Story-029 deleted the skip. At the project's own fixture Σ/C = **4.00×**.
- **Expiring per DEDUP-25-03**: the safe-config is **not a configuration a non-malicious owner can hold** — INV-25-02 shows 72 ordinary non-qualifying batches, with no owner action, push `P` past break-even.
- **Disposition**: `wont-fix` **preserved verbatim, not clobbered**. DEDUP-25-01 is filed as a **new finding with full re-file disclosure** (prior entry named, `triageReason` quoted, re-file basis stated), **not** as an override and **not** as a status change. The entry's own re-arm trigger has fired and needs human re-rating.

**`858e9e807abee888b378db210bae982f23fe7b5d91052321e204d7ba568579b7` — H-01, `wont-fix` — RE-WEIGH REQUIRED. STATUS NOT TOUCHED.**

Two of its own enumerated RE-RATE triggers are **met**, on its own terms:

- **(b)** *"nudge pot … exceeding nudgeSize x 70.000000 USDC"* — DEDUP-25-01 puts Σ at 4× the qualifying cost at fixture config; DEDUP-25-03 shows the threshold is crossed by ordinary usage.
- **(e)** *"deployment of src/BatchNFTMinterMultiToken.sol behind any value-forwarding dispatcher"* — **`NudgeRatchet` IS a value-forwarding dispatcher** (`_dispatch` forwards its full balance to `batchMinter` via the streamer, `NudgeRatchet.sol:156-161` @ `d4cc563`; metered over `duration`, but forwarded in full), and DEDUP-25-02 shows the forwarding target is this contract's own pot.
- The quoted 2026-07-21 ground — *"THE 6.7x MARGIN IS REAL"* (94.953127 USDC pot vs ~634 USDS qualifying cost at block 25577241) — is a **point measurement** that story-029 re-denominates by adding a pool to the sum.
- **Disposition**: `wont-fix` **preserved verbatim, not clobbered**; `severityNote`, the RE-ARM trigger list, and the coupling note to `521c20ad…` all left intact. The trigger firing is reported; the re-rate is the human's.

### 5.2 Recurrence check against the 44 open entries

| finding | matched open entry | verdict |
|---|---|---|
| DEDUP-25-05 | `75305ec0242b…` (L-04, open) + `a7dffb34c990…` (F-20-07, open, doc twin) | **RECURRENCE ⇒ `still-open`** — see FLAG-01 |
| DEDUP-25-07 | `c847207db213…` (M-02, open, fork drift on same file) | **related, NOT duplicate** — different root cause (ReentrancyGuard). Approval leg covered by `ad36260f`; sweep leg **unanchored**. See FLAG-03 |
| DEDUP-25-01 | `43e8c486…`, `858e9e80…` (both wont-fix), `fcaca002…`, `7a1718e9…` (wont-fix) | **NEW** — root-cause class changed (`_snapshotRewards` scope, not the gate or the sweep) ⇒ new fingerprint. Not a recurrence of any *open* entry. |
| DEDUP-25-11 | `a7dffb34c990…` (doc site §1) | **NEW** — different doc section (§4.1 heading, written this range) and different claim (scope overshoot, not false premise). Ledger forbids collapsing doc/code twins. |
| DEDUP-25-02, -03, -04, -06, -08, -10 | none | **NEW** |

### 5.3 Two additional ledger observations surfaced during reconciliation (NOT decided here)

**`2d34673536a16ad1c7f1230e8f4c3d31f729e35b56b4c267700be531b6664f7f` — L-04, `open`, low — PROPOSE `fixed` (human-only), COUPLED.** This entry — *"Streamer flush ignores the runtime payment-token skip → streamed buffer leaks to caller via step-10 sweep"* — names **story-029 as its own remedy**: *"the payment token becomes a first-class nudge token (the :558 runtime skip is DELETED), and the step-10 balance-derived sweep is replaced by a refund of a locally-tracked caller budget, taken BEFORE the payout. Plan: docs/phoenix-nft-staking-payment-token-as-nudge-token-plan.md. Propose `fixed` only after that plan's §8 suite passes."* Story-faithfulness confirms all of that landed and the §8 suite is green (535/535, both invariant campaigns at 128,000 calls). **⚠ Its own note is binding: this entry is the phoenix-side twin of yield-claim-nft `d06e3191…` (ycn19h1, `fix-pending`), and *"NEITHER ENTRY MAY BE CLOSED UNTIL THE OTHER IS (Law 1)."*** Do not close one ledger's copy alone. Note also that the chosen remedy is precisely what **created** DEDUP-25-01/-03 — the fix is real, and it moved value into a different exit.

**`a62fe01a25e2…` — M-02, `fix-pending`, medium — PROPOSE `fixed` (human-only); flagged as a coverage gap.** Root cause: *"duplicate `rewardTokens` entries pay the same pre-loop snapshot k times."* At `5015f1b` both `_snapshotRewards` (`:749-765`) and `_payRewards` (`:784-793`) walk the `_nudgeTokens` **storage set**, not a caller-supplied array; the NatSpec at `:745-748` states *"Duplicate entries are structurally impossible (§4.5): the whitelist is a set, and `setNudgeTokenWhitelist` reverts on re-add. No dedupe pass is needed — by construction, not by scan."* The root cause is structurally absent. **⚠ Honest caveat, stated rather than glossed:** this was **not** the object of any tier this run (the delta scan targeted the budget/approval/skip legs), and `_snapshotRewards` **was rewritten in this range** — so this is a *code-changed, no-longer-flagged* case, which per the fix-pending rules is a **propose-only**, never an auto-flip. A scanner ceasing to flag it is not a verified fix. Recommend `/recheck phoenix-nft-staking a62fe01a` before any human applies `fixed`. Not suppressed, carried forward.

---

## 6. Handoff to finding-manager

1. **9 NEW findings** (DEDUP-25-01, -02, -03, -04, -06, -07, -08, -10, -11) → severity-classifier, then reporting. DEDUP-25-08 must carry the merged DEDUP-25-09 residual.
2. **1 STILL-OPEN recurrence** (DEDUP-25-05 ⇒ `75305ec0…` + `a7dffb34…`): bump `lastSeenRun`, **do not regenerate**, **copy both original reports forward in full** into `submissions/carryover/`. Never a pointer stub.
3. **1 SUPPRESSED** (DEDUP-25-09): log with rule and reason; do not file.
4. **CARRYOVER of the two untouched `fix-pending` entries** — `1c222d5485…` (H-01) and, pending `/recheck`, `a62fe01a…` (M-02): copied forward beside the new findings. `fix-pending` is never suppressed and never auto-closed.
5. **PROPOSALS ONLY — a human applies every one of these**: `ad36260f…` → `fixed` (conditioned on DEDUP-25-06/-07); `2d346735…` → `fixed` (coupled to yield-claim-nft `d06e3191…`, neither closes alone); `a62fe01a…` → `fixed` **after** `/recheck`.
6. **DO NOT CLOBBER** `43e8c486…` or `858e9e80…`. Their `wont-fix` status, `severityNote`, RE-ARM trigger lists and coupling notes stay byte-identical. Their re-weigh is carried *inside* DEDUP-25-01's writeup, as disclosure — never as a status change.
7. **Ledger write integrity**: per `verify-subagent-ledger-writes`, diff the post-write status counts against this session's snapshot — **44 open / 15 wont-fix / 4 fix-pending / 3 submitted / 2 false-positive / 1 fixed = 69**. This project has a documented history of a finding-manager silently reverting a `wont-fix` (run-23, `43e8c486` — the same entry re-weighed here).
