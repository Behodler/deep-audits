# Spec Conformance (Law 2 — Faithfulness) — `phoenix-phase-2-staging-22`

**Entry point:** `promotion-ready:broadcast`
**Script:** `script/DeployMainnetPromotionReady.s.sol`
**Story:** `story-072` — *Mainnet Promotion: NudgeStreamer Cutover, MultiToken BatchMinter, Donor Redeploys, and Silent StakerDepletion→V2 Migration*
**Story document:** `~/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/072-mainnet-nudgestreamer-cutover-multitoken-batchminter-staker-v2-migration.md` (1,516 lines, state `complete`)
**Submodule HEAD graded:** `5ae94bd`
**Deviations found:** 3 — **F-01** (Medium, also `M-01`), **F-02** (Low, also `L-05`), **F-03** (Low, also `L-08`)

---

## 0. Grading basis — which text is authoritative

This story has been **replanned in place**, and grading it against its original text would manufacture false deviations. The authoritative text is the corrected text. The story says so itself, at lines 10–21:

> **Line 10 (verbatim):**
> `> ### Revision 2026-08-01 — replanned against current upstream`
>
> **Lines 19–21 (verbatim):**
> `> **Do not execute against the original text.** In particular Phase 6's original`
> `> "pause → rescue full balance → initiateMigration" ordering is *proven to revert*,`
> `> and `v1.pause()` has no owner-callable route.`

Accordingly, this report grades the script against, and only against:

1. the **`[REVISED 2026-08-01]` / `[REPLACED 2026-08-01]` / `[RESOLVED 2026-08-01]`** body text and the corrected Phase 6 ordering at checklist line 1172;
2. **`## Review Results`** (lines 1452–1477, status `ISSUES_FOUND`, 40 PASS / 1 FAIL / 2 PARTIAL / 1 UNVERIFIABLE of 44 ticked items);
3. **`## Post-review corrections 2026-08-01`** (lines 1481–1514), which resolve both review findings;
4. the **11 `Autonomous Decisions`** (lines 1199–1376), each of which is treated as declared intent that the code must match — two of them (Decision 2, Decision 5) are load-bearing to the deviations below.

Superseded text is **not** graded. Specifically, the original Phase 6 ordering, the pre-`[REPLACED]` `setNudgeTokenWhitelist` ordering constraint, the "immutable hook dispatcher" claim, and the pre-correction mint-authority and Kendu-conditionality claims are all excluded from the deviation set as *already retracted by the story*.

### 0.1 A state-vs-reality mismatch worth flagging on its own

The story is filed under **`complete/`**. **The cutover has not been broadcast.** The story records this without ambiguity:

> **Line 1439 (verbatim):**
> `- **NOTHING WAS BROADCAST.** The mainnet Ledger session remains a human step.`

> **Lines 1424–1426 (verbatim):**
> `**Unticked, deliberately.** The two checklist items marked *(Post-broadcast, HUMAN step)* —`
> `the on-chain confirmation sweep and the live index-4 `BatchDonatedViaPSM` mint. Both require`
> `the Ledger broadcast, which this execution did not and must not perform.`

Of 46 checklist items, **44 are ticked** and exactly **two** are unticked: **line 1195** and **line 1197**. Both are post-broadcast human confirmations. (These 46 are the only checkboxes anywhere in the document.)

Project doctrine says a story whose state does not match reality is itself worth flagging. The usual case is a *landed feature whose story sits in `incomplete`*. **Here the mismatch runs the other way** — the story is **closed while the work it describes has not been executed** — and that direction matters more, not less, for this audit:

- A reader scanning the checklist sees 44 of 46 ticks and a `complete` folder, and will reasonably read the operation as done and verified.
- The two boxes that are *not* ticked are not cosmetic leftovers. **They are the audit's primary compensating controls** — they are the only outcome verification the design defines for the broadcast path (see F-01). Their unticked state is the single most load-bearing fact in this run's severity assignment.
- A `complete` filing creates pressure to treat them as closed-by-implication. They are not, and they must be executed as hard, signed-off gates during the Ledger session.

This is recorded as a **process observation**, not a code finding: no code change addresses it. The correct disposition is either to move the story back to `review` until the broadcast lands, or to add an explicit "closed pending broadcast" marker to the header banner.

---

## F-01 — The story's fix for one comment-drift defect reassigned the mint-authority check to an unticked box, leaving it verified on no path

- **Severity:** Medium · **Finding:** `M-01` · **Fingerprint:** `2c53e944caee2e74a1a351c9b30b9e92cd8feac28203e8d5c1c9b7d9e8b4102f`
- **Story checklist lines:** **1167** and **1190** (both ticked) · **Compensating controls:** **1195** and **1197** (both **unticked**)
- **Code:** `script/DeployMainnetPromotionReady.s.sol` — `run` **`:400-411`** (Phase 7 call site **`:400`**) / `_phase7_wiringAssertions` body **`:1451-1568`**; Phase 8 broadcast gate **`:402-408`**; corrected docblock **`:68-73`**

### The cascade

This is the deviation to read first, because it is not a simple drift — it is a **remedy that opened a second, unclosed gap**.

The original defect was found by the story's own review. Review Results, **line 1463 (verbatim)**:

> `- **Claims**: Issues found — 40 PASS / 1 FAIL / 2 PARTIAL / 1 UNVERIFIABLE of 44 ticked items. The FAIL: checklist line 1167 claims "assert mint authority is byte-identical before and after", and `DeployMainnetPromotionReady.s.sol:68` states Phase 7 does so — **that assertion was never written** (`grep isMinter|minters` returns nothing). The invariant itself holds by construction (zero `phUSD.setMinter` calls in the script), so this is a false claim about verification, not a functional defect.`

The story then corrected the *claim* rather than writing the *assertion*. Post-review correction #1, **lines 1487–1493 (verbatim)**:

> `**1. The mint-authority claim (review FAIL).** The script's docblock said *"Phase 7 asserts the`
> `five hooks' authorisation is byte-identical to Phase 0's reading."* No such assertion exists —`
> `neither phase reads phUSD's minter set. Corrected rather than implemented: the invariant holds`
> `**by construction** (zero `phUSD.setMinter` calls anywhere in the script, so nothing can change`
> `it), and the confirmation is the post-broadcast HUMAN checklist item that reads phUSD's minter`
> `set on-chain after the Ledger session. `DeployMainnetPromotionReady.s.sol:68-73` now states`
> `exactly that, and checklist line 1167 above was corrected to match.`

The correction is honest and the "by construction" premise is **sound** — this audit verified it independently at source: there are **zero** `phUSD.setMinter` calls in the script; all three `setMinter` call sites (**`:799`**, **`:951`**, **`:1073`**) are `dispatcher.setMinter(NFTMinterV2)`; `PHUSD` appears only as an `IERC20` `balanceOf`/`approve` target and as a whitelist argument.

But the correction **transferred the verification obligation to a named destination** — and that destination is not discharged.

### Deviation 1 — checklist line 1167 (ticked)

> **Line 1167 (verbatim):**
> `- [x] **Hooks are REPOINTED, not redeployed** — for all five: `pull()` → `hook.setDispatcher(new)` → `newDispatcher.setHook(hook)`, in that order (fail-closed). **Zero `phUSD.setMinter` calls in the whole script**, so mint authority is byte-identical before and after **by construction**. [CORRECTED 2026-08-01 post-review — no on-chain assertion is written; the check is the post-broadcast HUMAN item at the end of this checklist. The script comment claiming Phase 7 asserts it has been fixed.]`

**What the code actually does.** The repoint ordering half of this item is **faithful** (see §4). The mint-authority half is where the deviation sits. The item's own bracketed correction reassigns the check to *"the post-broadcast HUMAN item at the end of this checklist"* — that item is **line 1195**, and line 1195 is **unticked**:

> **Line 1195 (verbatim, unticked):**
> `- [ ] (Post-broadcast, HUMAN step) confirm on-chain: `configs(1..4,7)` resolve to the new dispatchers with price/growth preserved; the old DelayRelease holds 0 USDC and the old batch-minter holds 0 USDC **and is `paused()`**; **the rescued ~349 USDC (98.04 + 250.77) sits in the streamer's buffer, not on `newBM`**; the ratchet hook's 70 phUSD `mintDebt` was pulled and all five hooks now read `dispatcher == ` their new dispatcher with `ratio`/`recipient` intact; **phUSD's minter set is byte-identical to its pre-cutover state**; the new pooler holds the full 16,338.8190 BPT, is owned by the Ledger, and the old pooler holds 0; each V1 staker has `totalStaked == 0`, is unregistered from the Pauser, and its V2 counterpart holds the migrated total plus a non-zero phUSD budget; every donor's `nudgeStreamer()` returns the new streamer; `streams(newBM, USDC/phUSD/KENDU).duration` read 10/30/30 days.`

Its sibling control is unticked too:

> **Line 1197 (verbatim, unticked):**
> `- [ ] (Post-broadcast, HUMAN step) trigger one index-4 mint and assert `BatchDonatedViaPSM` fired — a green transaction is **not** evidence for the pooler.`

**Net effect:** the check exists in **no** automated path (by design, per the correction) and in **no** discharged procedural path (because line 1195 is unticked). **No verification of mint-authority invariance exists on any path.** The story's remedy for the first comment-drift defect created a second gap, and closed neither.

### Deviation 2 — checklist line 1190 (ticked, and the tick is *earned*)

> **Line 1190 (verbatim):**
> `- [x] `npm run promotion-ready:dry` against live mainnet: no revert, all phase-0 and phase-7 assertions pass, no progress file written in preview.`

**What the code actually does.** This statement is **accurate for the dry run** and the tick is earned — this audit's own fork replay reproduces it (exit 0, every Phase 0 precondition and Phase 7 read-back passing, no progress file). The deviation is one of **scope of claim**, not of truth.

Line 1190 is the *only* verification evidence the story records, while the `//promotion-ready:broadcast` package.json annotation presents Phase 7's full bidirectional wiring read-back as the verification gate for the cutover generally. A reader of the ticked checklist is entitled to conclude the **broadcast** is verified. It is not, for a structural reason: `forge script` executes the entire Solidity body **once, locally**, collecting calldata; the ~60 transactions are signed on the Ledger and dispatched **afterwards**. Every assertion in the script — Phase 0 preconditions, in-phase post-conditions (BPT conservation `:892-895`, `newBM` balance unchanged `:728-731`, `old.paused()` `:1134`, V1 `totalStaked == 0` `:1394`) and the whole of Phase 7 (called at **`:400`**, body `_phase7_wiringAssertions` at **`:1451-1568`**) — has already evaluated against **pre-broadcast local state** before transaction #1 leaves the machine. Phase 8, which holds the BLOCKING probes, is gated off entirely under `--broadcast` (**`:402-408`**).

The assertions prove the **plan** is internally consistent. They never prove the **chain** matches it.

### Why this is Medium and not merely a documentation defect

The undetected end state is a real availability impact, not just a missing report: a half-applied cutover leaves one or more dispatcher indices in the fail-closed intermediate state the story itself documents at line 1194(c) — `hook.setDispatcher(new)` landed, `replaceDispatcher(idx, new)` not — so mints on that index revert `OnlyDispatcher` **indefinitely** rather than intermittently, with nothing raising a signal. Full reasoning, the L-02 fix-ordering dependency, and the recommended `promotion-ready:verify` entry point are in `submissions/M-01.md`.

### The zero-code control that discharges most of this

**Tick lines 1195 and 1197 as mandatory, blocking, signed-off steps before the Ledger key is disconnected.** No code change required. This is the single highest-value pre-broadcast action in the run.

---

## F-02 — A ticked criterion's second clause is only printed as prose, and the branch that would have proven it is structurally unreachable

- **Severity:** Low · **Finding:** `L-05` · **Fingerprint:** `3c957109ef53404376145e81a57d23db18474cc1ba0174dc7fc0f4f60e33190d`
- **Story checklist line:** **1166** (ticked)
- **Code:** `script/DeployMainnetPromotionReady.s.sol` — `_phase4d_retireOldBatchMinter`, **`:1137-1148`** (residue read `:1140`, prose log `:1146`, vacuous `require` `:1148`); `paused()` assertion **`:1134`**

> **Line 1166 (verbatim):**
> `- [x] Phase 4d (after every donor is repointed): retire the old batch-minter — `setPauser(OWNER)` then `pause()`. **Do not register it with the global `Pauser`.** Assert `paused() == true` and that `rescueERC20` still works while paused.`

**What the code actually does.** Three of the item's four obligations are met. `setPauser(OWNER)` then `pause()` run; the minter is deliberately **not** registered with the global `Pauser`; and `paused() == true` **is** asserted at **`:1134`**.

The fourth obligation — *"and that `rescueERC20` still works while paused"* — **is not asserted anywhere.** The `else` branch at **`:1146`** merely **logs the claim as prose** (`"rescueERC20 remains available while paused"`), and the `if (residue > 0)` branch that would have *exercised* `rescueERC20` on a paused contract is **structurally unreachable**:

`uint256 residue = IERC20(USDC).balanceOf(OLD_BATCH_MINTER)` at **`:1140`** evaluates in forge's **local pass**, seconds after Phase 3's **local** rescue — so `residue` reads 0 there, the branch is never taken, and **no rescue transaction is ever queued into the broadcast plan**. The trailing `require(balanceOf(OLD_BATCH_MINTER) == 0)` at **`:1148`** evaluates in the same local pass and passes vacuously. The fork run confirms it empirically: it logged *"no residue to sweep."*

A ticked acceptance criterion therefore claims an assertion that the code only prints as a sentence.

**Second, independent deviation — Autonomous Decision 2 contradicts the code it describes.** Lines 1228–1235 (verbatim):

> `**Decision.** After `pause()`, Phase 4d re-reads the old minter's USDC balance and, if`
> `non-zero, rescues it to `OWNER` and `collectNudge`s it into the stream, then `require`s the`
> `balance is zero.`
>
> `**Rationale.** It closes a guaranteed leak and simultaneously *demonstrates* the story's own`
> `requested assertion that "`rescueERC20` still works while paused" rather than merely`
> `claiming it. On the dry run the residue was 0 (Phase 3 ran seconds earlier); on a real`
> `multi-hour Ledger session it will not be.`

The rationale's own premise — donors keep pushing USDC at the old sink through the multi-hour session — is correct, and it is exactly why the leak is **not** closed: the branch that would close it is decided at local-exec time, not broadcast time. The decision claims the leak is structurally closed when it is procedurally open. **Retracting that "structurally closed" claim is not optional**, regardless of which remediation is chosen.

**Impact is bounded and fully recoverable** — `rescueERC20` is `onlyOwner` and not pause-gated, so any stranded residue can be swept later. The reportable substance is the **false confidence**, which is why this sits at Low and is routed here.

---

## F-03 — "a donation on each of the four donor paths" is ticked; three run, and Autonomous Decision 5 rests on the missing two

- **Severity:** Low · **Finding:** `L-08` · **Fingerprint:** `d5d55f34c5d6ffa3f24c7833b43d707dbba4e1336eb558db9f7a3bde54946576`
- **Story checklist line:** **1174** (ticked)
- **Code:** `script/DeployMainnetPromotionReady.s.sol` — `_probeDonorPaths` / `_assertSlot`, **`:1665-1707`**; the mirrored claim in-code at **`:1575-1580`**

> **Line 1174 (verbatim):**
> `- [x] Phase 8 (PREVIEW only): mock `batchMint`s; a donation on each of the four donor paths with the pooler asserted **positively** via `BatchDonatedViaPSM` + a balance increase; the Kendu no-tax round trip; stream accrual/flush (magnitudes verified out of band); and the `ArrayLengthMismatch` negative test **outside `vm.startBroadcast`**.`

**What the code actually does.** `_probeDonorPaths` (**`:1665-1707`**) exercises **three** dispatcher indices: `_mintOnce(IDX_EYE)` (index 1), `_mintOnce(IDX_RATCHET)` (index 7), and the inline pooler mint at `IDX_POOLER` (index 4). **Indices 2 (Uniboost SCX) and 3 (Uniboost FLX) are never minted through.** Fork evidence is explicit: `idx2` and `idx3` read **NOT TESTED**. The tick is unearned on its own terms, independently of how many paths *"four"* was meant to enumerate.

**Why the gap matters beyond coverage arithmetic.** Autonomous Decision 5 (lines 1286–1304) removes the `dispatcher.minter()` read-back from Phase 7 on **correct** grounds — `ATokenDispatcherV2._minter` is `internal` with no public accessor, so the value is genuinely unreadable — and substitutes a functional argument, lines 1296–1300 (verbatim):

> `**Rationale.** `ATokenDispatcherV2._minter` is `internal` (`:25`) with no public accessor and`
> `` `ITokenDispatcherV2` declares no getter — the value is genuinely unreadable. Phase 8's mints ``
> `verify it *more* strongly than a read-back would: `dispatch` is `onlyMinter` (`:44-47`), so a`
> `dispatcher whose minter was not set reverts `"ATokenDispatcherV2: caller is not minter"` on`
> `the first mint through its index, which all three donor-path probes exercise.`

The same claim is repeated verbatim in code at **`:1575-1580`**. It is **false as written for indices 2 and 3**: `newUniboostSCX.setMinter()` and `newUniboostFLX.setMinter()` have neither a read-back (structurally impossible) nor a functional probe (absent). A documented verification *argument* is doing work it cannot do.

The underlying misconfiguration is **not realistically reachable** — all three Uniboosts are configured by the same `_swapUniboost` body in one `ub_<label>_config` block, so a `setMinter` omission on SCX/FLX but not EYE is not a plausible failure mode. That is why this is Low, not Medium. The fix is two lines using an existing helper.

### F-02 and F-03 are the same defect class the story itself legislates against

Both deviations are **comment/claim drift**: a statement in the story or in the script asserts a verification that the code does not perform. This story made that class an **explicit acceptance criterion of its own**:

> **Line 1161 (verbatim):**
> `- [x] **Every comment traceable to pinned source** — no `BatchMint__RewardTokenIsPaymentToken`, no whitelist-ordering claim, no "immutable hook dispatcher", no owner-arg SYA ctor, and 073's *corrected* budget docblock (ordering proven, sizing open).`

And commit **`5ae94bd`** — the commit graded by this audit — **was itself a comment-drift fix**, landing exactly two such corrections (post-review corrections #1 and #2, story lines 1481–1503). Lines 1483–1485 (verbatim):

> `Both review findings were documentation-accuracy defects. Both are fixed; **no contract call,`
> `no ordering and no on-chain behaviour changed**, and the dry run is unaffected (comments only,`
> `plus one console-summary string in the patcher).`

**F-02 and F-03 are two more members of that class that survived the review which caught the other two.** The review found 1 FAIL and 1 sanity-check drift; this audit finds two additional instances of the identical pattern. That is the useful signal for the owner: the class is not exhausted by a targeted review pass, and line 1161's tick should be read as *"the named instances were cleared"*, not *"the file is now drift-free"*.

---

## 4. Verified faithful — what the script got right against the story

Faithfulness is not a defect list. The following were checked against the corrected story text and **confirmed conformant**. They are recorded so a future run does not re-litigate them, and so the three deviations above are read against an accurate baseline.

| # | Story requirement | Verification |
|---|---|---|
| 1 | **Phase 6 corrected ordering** (checklist line 1172) — deploy V2 → window/pauser/register → deploy migrator → `setMigrator` both sides → `v1.setPauser(OWNER)` + `Pauser.unregister(v1)` + `v1.pause()` → `initiateMigration()` → batched `migrate(users)` → assert `totalStaked` conservation → **then** sweep → repoint hook | Implemented in the **corrected** order, **not** the superseded original that the banner at lines 19–21 records as *proven to revert*. Independently confirmed by Review Results line 1467 (*"Phase 6's corrected pause/migrate/sweep order"*). Fork: V1 `totalStaked == 0`, V2 holds 2 / 146 / 13, V1 unregistered from the `Pauser`. |
| 2 | **Zero `phUSD.setMinter` calls in the whole script** (line 1167) | **Verified at source.** All three `setMinter` call sites — **`:799`**, **`:951`**, **`:1073`** — are `dispatcher.setMinter(NFTMinterV2)`. `PHUSD` appears only as an `IERC20` `balanceOf`/`approve` target and a whitelist argument. The *"by construction"* premise is **sound**; only its *verification* is missing (F-01). |
| 3 | **Phase 4d sequenced after Phase 5**, per Autonomous Decision 1 (lines 1205–1221) | `_phase4d_retireOldBatchMinter()` is called after `_phase5_...()` in `run()`, honouring the governing invariant ("**once every donor has been repointed at `newBM`**", lines 1208–1209, verbatim including the story's own bold) over the label. The sixth donor is the `StableYieldAccumulator`, repointed in Phase 5. Correct call. |
| 4 | **Hooks repointed fail-closed, all five** (line 1167) — `pull()` → `hook.setDispatcher(new)` → `newDispatcher.setHook(hook)` → `replaceDispatcher(idx, new)` | Ordering honoured at **every** index (1/2/3/4/7). `mintDebt == 0` asserted after each `pull()`; the ratchet hook's 70.0 phUSD was pulled. `price`/`growth` preserved across every `replaceDispatcher`: `10002000/2`, `10298263/2`, `10022018/2`, `16373620392788442852/1`, `70000000/0`. The reverse order would leak value silently; it is not used anywhere. |
| 5 | **`registerStream` ×3 at 10/30/30 days as named constants** (line 1164) | `DURATION_USDC` / `DURATION_PHUSD` / `DURATION_KENDU` are named constants; on-chain result `streams[newBM][USDC/phUSD/KENDU].duration == 864000 / 2592000 / 2592000`. Gate asserted, `NUDGE_SIZE == 40`. |
| 6 | **`:broadcast` ends with `&& node scripts/patch-mainnet-addresses-promotion-ready.js`** (line 1193) — `&&` not `;`, preceded by the backup script, repeated on `:resume`; 57 == 57; non-zero exit on collision | Confirmed in `package.json`: the chain is `node scripts/backup-mainnet-addresses.js && forge script … && node scripts/patch-mainnet-addresses-promotion-ready.js`, with the patcher repeated on the `:resume` leg. Patcher adds/removes **no** keys; post-patch key-set is re-checked against the `ContractAddresses` interface at **57 == 57** (mismatch ⇒ exit 3); documented non-zero exits 1/2/3/4, with collision ⇒ exit 4. A missing `mainnet-addresses.ts` throws and `&&` stops the chain **before** forge runs (fail-closed). |
| 7 | **Runtime values used, not the story's stale literals** | Positively demonstrated. Old batch-minter USDC drifted `98.040608 → 225.040608`; DelayRelease USDC drifted `250.77 → 123.77`; **both runtime values were used**. The aggregate (`348.810608`) coincidentally still matches the story's *"~349 USDC (98.04 + 250.77)"* while **both components moved** — which is affirmative proof the literals are not consulted. Corroborated by the story's own sanity-check re-run at line 1441 (SCX sweep `709.150` vs the recorded `709.182`). |
| 8 | **BLOCKING Kendu fee-on-transfer preflight** (checklist line 1154) | **Discharged against the real token with an exact result.** Story line 1392 (verbatim): *"**Kendu fee-on-transfer preflight: PASS.** `1e24` units sent through `collectNudge`;"* — continuing on line 1393 (verbatim): *"streamer received `1e24`; credited buffer delta `1e24`. Exact, not approximate."* Corroborated off-chain by `buyTotalFees() == 0`, `sellTotalFees() == 0`, `limitsInEffect() == false`, and `owner() == address(0)` — ownership **renounced**, so the fee switches can never be moved again. The probe is genuine: `deal()` only seeds the balance; `collectNudge` performs a real `transferFrom` through Kendu's transfer path. Line 1154's tick is **earned**. |

Also confirmed conformant and not re-litigated here: Phase 0's 17-target `owner()` sweep, the resume-aware dispatcher-slot assertions, the six BPT custody guard rails with exact conservation both ways (`16338818951239025717919` in and out), the positive `BatchDonatedViaPSM` pooler assertion with `DonationSkipped == false`, and the `Pauser` registry end-state (`+newBM`, `+newSYA`, `+3` V2 stakers; `−OLD_SYA`, `−3` V1 stakers, retired minter deliberately absent).

---

## 5. Explicitly NOT an F-class deviation — `PR-01` / `L-04` (the procedural-vs-structural Kendu gate)

**`L-04` is a security finding only. It is not a Law-2 faithfulness defect, and it must not be re-filed as one.**

`L-04` observes that Kendu's fee-on-transfer gate is **procedural, not structural**: the whitelist call at **`:640-644`** is unconditional *with respect to the Phase 8 fee-on-transfer probe* (it is wrapped only in `if (!_isConfigured("bm_wl_kendu"))`, a resume-idempotency guard that carries no probe dependency), while the BLOCKING probe lives in Phase 8, which executes only under `PREVIEW_MODE` and therefore **never runs in a `--broadcast` run**. Against a naive reading of BLOCKING checklist line 1154, that looks like a departure.

It is not, because **the story discloses and accepts it in its own text**, in three places:

> **Line 1464 (verbatim), under `## Review Results`:**
> `- **Second comment drift** (sanity-check): `:1851-1852` and the patch script's header claim Kendu is "recorded ONLY if the Phase 8 fee-on-transfer probe passed". In a broadcast run Phase 8 never executes and Kendu is whitelisted unconditionally at `:633`/`:637` — the gate is procedural (run `:dry` first), not structural, and the patcher's `SKIP-OPT` branch is unreachable.`

> **Line 1498 (verbatim), under `## Post-review corrections 2026-08-01` #2:**
> `gate is **procedural** — run `promotion-ready:dry` first and let `_probeKenduFeeOnTransfer`'s`

Post-review correction #2 (lines 1495–1503) then **accepts** the procedural gate and corrects the four places that claimed otherwise (the whitelist call site, the progress-file `names[]` entry, the patcher header, and the `SKIP-OPT` summary line), retaining `optional: true` on the `Kendu` field and re-documenting it as a defensive fallback rather than the expected negative outcome.

Line 1154's tick is likewise **earned**, on real evidence: the PASS is recorded at story lines **1392** and **1436** against the **real** Kendu token with an exact `1e24` round trip.

**Law 2 is therefore satisfied.** There is no undisclosed departure from stated behaviour: the story states the gate is procedural, and the code implements a procedural gate. The residual — that a broadcast-only operator who skipped `:dry` would whitelist Kendu without the probe — is a **security** concern about control strength, correctly filed as `L-04` in `qa-report.md`, with its disclosed ledger relationship to `acabc052` (`dev` / `L-09`) and its impact-chain dependency on the fix-pending `a753907e` preserved there.

*(For the same reason, `Q-01` — the untracked mint-UI breakage — is not F-class either: the story **declares** the breakage at lines 376–377, 1194(a) and 1447. The finding is that the remediation is unscheduled, which is a scheduling gap, not a faithfulness gap.)*

---

## 6. Cross-reference — audit-model recall gap `MR-22-01`

Recorded here because it must reach a document a human reads, and because it bears on how much assurance a "the script was audited" statement carries.

The `deploymentStatus: "completed"`-decided-in-the-local-pass pattern shipped on **two prior mainnet cutover scripts** — `DeployMainnetNudgeRatchet.s.sol:811` and `DeployMainnetUniboostCutover.s.sol:802` — each of which **was script-audited** (run-19 and run-20 respectively), and **neither audit filed it**. It was first filed only in run-21, as ledger entry `1e8cc0dc`. **Three of the six `_writeProgressFileWithStatus` users remain unexamined.** Enumerated at `5ae94bd` by definition site, the six are `DeployMainnetNFTStaking.s.sol:519`, `DeployMainnetNFTV2.s.sol:750`, `DeployMainnetNudgePoolerV2.s.sol:1049`, `DeployMainnetNudgeRatchet.s.sol:818`, `DeployMainnetPromotionReady.s.sol:1984`, and `DeployMainnetUniboostCutover.s.sol:809`. **Three were examined** — `DeployMainnetNudgeRatchet.s.sol` (run-19), `DeployMainnetUniboostCutover.s.sol` (run-20), and `DeployMainnetPromotionReady.s.sol` (this run, filed as `L-03`). **The three genuinely unexamined are `DeployMainnetNFTStaking.s.sol:519`, `DeployMainnetNFTV2.s.sol:750`, and `DeployMainnetNudgePoolerV2.s.sol:1049`** — the sweep should name them rather than re-derive them.

This is a defect in the audit **model**, not in the code, and carries no C4 severity. Its code-side realisation for this entry point is `L-03`, classified and reported in `qa-report.md`. It is carried as a ledger watch-note.

---

## 7. Summary

| Label | Severity | Finding | Story line(s) | One-line deviation |
|---|---|---|---|---|
| **F-01** | Medium | `M-01` | **1167**, **1190** (ticked); **1195**, **1197** (unticked) | The post-review correction reassigned the mint-authority check to the post-broadcast human item at line 1195, which is unticked — so the check exists on **no** path; and the ticked dry-run evidence at line 1190 does not extend to the broadcast, where every assertion evaluates before dispatch. |
| **F-02** | Low | `L-05` | **1166** (ticked) | *"Assert … that `rescueERC20` still works while paused"* is only **printed as prose** at `:1146`; the branch that would prove it is unreachable in the local pass, and Autonomous Decision 2 calls a still-open leak *"structurally closed"*. |
| **F-03** | Low | `L-08` | **1174** (ticked) | *"a donation on each of the four donor paths"* is ticked; **three** run (indices 1, 4, 7). Indices 2 and 3 are never exercised, which makes Autonomous Decision 5's substituted verification argument false as written. |

**Not F-class:** `L-04` (Kendu procedural gate — disclosed and accepted at story lines 1464 / 1498 and post-review correction #2; security finding only) and `Q-01` (UI breakage — declared by the story; scheduling gap).

**Highest-value pre-broadcast action, requiring no code change:** tick story-072 checklist lines **1195** and **1197** as mandatory, blocking, signed-off steps before the Ledger key is disconnected. That single action discharges most of F-01/`M-01`'s impact.

---

*All story quotations in this report were verified verbatim, character-for-character, against `072-mainnet-nudgestreamer-cutover-multitoken-batchminter-staker-v2-migration.md` at its current revision. Line numbers are as of that revision; the story is actively edited in place, so re-verify line numbers (not text) before citing them elsewhere.*
