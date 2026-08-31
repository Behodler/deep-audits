# Spec Conformance — Law-2 Faithfulness Report

**Project:** `phoenix-phase-2-staging`
**Commit:** `712cbdb` (`Merge branch 'sprint/promotion-ready'`)
**Run:** `phoenix-phase-2-staging-25` (script audit)
**Entry-point family:** `promotion-ready` (`:snapshot`, `:dry`, `:broadcast`, `:resume`, `:verify`)
**Range audited:** `b9391b1..712cbdb`

Commits in range:

| Commit | Subject |
|---|---|
| `3c60824` | `[story-077] Add DepositPageViewV3, a PhlimboV3-native deposit page view` |
| `7debc83` | `[story-078] Wire DepositPageViewV3 into the cutover; collapse view keys onto ViewRouter` |
| `f556d22` | `[story-078] Hydrate newDepositPageViewV3 in _parseProgressJson; guard the class` |

## Stories resolved and read

All three story documents below were retrieved and read in full. None was unavailable.

| Tag | State folder | Full resolved path |
|---|---|---|
| story-077 | `auto-complete` | `/home/justin/code/product-owner/stories/phStaging2/auto-complete/phStaging2-promotion-ready/077-depositpageviewv3-phlimbov3-native-deposit-page-view.md` |
| story-078 | `auto-complete` | `/home/justin/code/product-owner/stories/phStaging2/auto-complete/phStaging2-promotion-ready/078-wire-depositpageviewv3-into-cutover-and-collapse-view-keys-onto-viewrouter.md` |
| story-076 (parent) | `complete` | `/home/justin/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/076-phlimbo-v3-cutover-migration-in-promotion-ready-script.md` |

**A note on the `auto-complete` state folder.** Stories 077 and 078 sit in `auto-complete/`, which is a **non-standard state folder**: both carry an `## Auto-Completed` section reading *"**Approved by**: story-batch workflow (machine approval — not human-reviewed)"* (077:569, 078:837). Story 076, by contrast, went through the normal `complete/` path. Per CLAUDE.md, **state is metadata, not a filter** — an `auto-complete` story is graded here exactly as a `complete` one is, and its acceptance criteria are equally binding. The distinction is recorded for one reason only: the non-blocking findings carried forward in an auto-completed story's own tail (077:572-576, 078:840-843) have been triaged by a machine, not a human, so this report treats them as *inputs to be re-graded*, not as dispositions already accepted by an owner. Story 078's Autonomous Decision 1 (`:411-423`) relies on exactly this property — it unblocked itself on 077 because *"`auto-complete/` is terminal by design"* — and that reliance is correct under the documented rule, but it means neither story's premises were ever checked by a person before both landed.

**Scope of this document.** This is the Law-2 report and is **separate from the QA bundle** (`qa-report.md`). Where a deviation here is also filed as a Low/QA finding, it is cross-referenced by **ledger fingerprint**, quoted verbatim — one fingerprint, two labels. Nothing here is duplicated from the QA bundle beyond the identifying fingerprint and label.

---

## Grades

### story-077 — **FAITHFUL**

All **16** acceptance criteria (the `## Checklist` at `:372-392`) are MET.

Highlights, verified against source rather than against the story's own prose:

- **The 23-field wire contract matches the story's Technical Details table (`:174-198`) index-for-index.** `FIELD_COUNT = 23` (`src/views/DepositPageViewV3.sol:103`) sizes both arrays (`:118`, `:148`).
- **Indices 0-6 are byte-for-byte the predecessor's names and sources**, preserving the additive-migration promise the story makes at `:171-172` (*"Indices **0–6 keep their exact names, order and semantics**, so the migration is strictly additive for every field the UI reads today."*).
- **`userInfo` is destructured as a 4-tuple** — `(uint256 amount,,,) = phlimbo.userInfo(user); // 4-tuple in V3` (`DepositPageViewV3.sol:156`). This is the single most load-bearing criterion in 077 and it is met literally.
- **Fields 13-17 come from a single `getPromoInfo()` call** (`:174`), as required by `077:200-208`, not six separate getters.
- **All four never-revert hazards are handled** (`077:267-282`): never-staked user, `address(0)`, no promo token (short-circuit), and a promo token without `decimals()` (try/catch with an `18` fallback).
- **Zero-address constructor guards restored** (`:109-110`), which 077:244-246 explicitly calls out as repairing a `DepositPageView` regression.

Two **disclosed beyond-spec additions** were found, both recorded in the story's own review (`077:539-541`) and its auto-completion tail (`077:574`):

1. `uint256 public constant FIELD_COUNT = 23;` (`:103`) — a public constant the spec did not ask for.
2. A zero-address `continue` inside `getRetiredPromoBanks` (`:218`).

Neither perturbs the 23-entry `getNames()`/`getData()` wire contract that story 078 depends on and asserts. **No F-label is raised for either** — a disclosed, tested addition that does not move the contract surface is not a deviation.

### story-078 — **SUBSTANTIALLY FAITHFUL**

Of **33** acceptance criteria across the three checklist blocks (`:364-404`):

- **30 MET**
- **1 NOT MET** → **F-25-01** (doc-key update incomplete)
- **1 met in substance but not in letter** → **F-25-06** (declined checklist literal; the code is more correct than the story text)
- **1 scope overrun** → **F-25-05** (self-disclosed, net improvement)

**Key-set parity independently reproduced.** The story's central mechanical claim at `:266` — *"Parity after the change: **55 == 55**"* — was re-derived in this audit from the patcher's own `interfaceKeys()`/`dataKeys()` extractors: **interface = 55, data = 55, empty difference in both directions**. The `DROPPED_CONTRACT_NAMES` addition that makes the deletion durable against regeneration (`:262-264`) is present, and the keys are **deleted, not commented out**, as `:293-294` demands.

### story-076 follow-up (a) — **PARTIALLY DISCHARGED**

Story 076 raised two follow-ups at `:486-492`. Follow-up **(a)** is the one stories 077/078 exist to discharge:

> **Quoted verbatim, `076:486-489`:**
> *"Decision: **out of scope** — this story is script-and-tooling only. **Two follow-ups must be raised**: (a) a phStaging2 story to redeploy `DepositPageView` against V3 and re-register it with `ViewRouter` (and decide whether to redeploy or finally retire the deprecated `DepositView`); (b) a `phlimbo-ui` story to move the deposit page onto `ViewRouter` resolution the way the mint page already is, which is what makes future phlimbo swaps a no-op for the UI."*

Assessment, by obligation:

| Obligation in (a) | State at `712cbdb` |
|---|---|
| Build a V3-capable deposit view | **Complete, and better than specified** — see F-25-03 |
| Re-register it with `ViewRouter` — *in code* | **Complete** — `_phase4f_depositViewCutover()`, `setPage` last, `_isConfigured`-gated, post-asserted |
| Re-register it with `ViewRouter` — *on chain* | **NOT DONE** |
| Decide the deprecated `DepositView`'s fate | **Decided** — source kept (078 Concerns §4), key deleted |

The on-chain registration obligation is **written but unexecuted**. It is gated behind a broadcast that story 078 itself places out of scope:

> **Quoted verbatim, `078:39-41`:**
> *"- **Out**: **no broadcast.** Story 072 has never been broadcast and remains on ice pending its Kendu fee-on-transfer preflight. This story is script-and-tooling only, validated by dry run."*

**Any claim that follow-up (a) is closed is premature by exactly one broadcast.** The code is ready; the chain is unchanged. The `ViewRouter`'s `deposit` page at `712cbdb` still resolves to `0x50D4443782bB9A6e8D65dAcd593684EDd3FF03b8`, confirmed live during the executor's own dry run (`078:488-491`).

**The (a)-before-(b) ordering constraint remains LIVE, and story 078 has TIGHTENED it.** Follow-up (b) may only be executed after (a) has landed *on chain*; 078's deletion of the `DepositView` key removes the fallback that made a premature (b) survivable. This is the substance of **F-25-04**.

---

## Findings

All labels in this run are namespaced **`F-25-NN`** to avoid collision with prior runs' `F-03` / `F-04`.

### F-25-01 — Doc-key update incomplete (low) · story-078

**Ledger fingerprint:** `83a40563860e4bedcbd3164153ffd411f50cec95cdd23ec47009777a5bfe9fa1`
**Also filed as:** `L-02` in the QA bundle — **one fingerprint, two labels**, not two findings.

**Spec, quoted verbatim** (`078:400`, Checklist → Codegen and validation):

> *"- [x] Update the `//`-prefixed doc keys in `package.json` describing the broadcast legs"*

Supporting spec text (`078:151`, File Locations):

> *"| `package.json` | **Modify** | Update the `//`-prefixed doc keys that assert the "58-key set" (`:287`) and describe the broadcast legs |"*

**Spec source:** `/home/justin/code/product-owner/stories/phStaging2/auto-complete/phStaging2-promotion-ready/078-wire-depositpageviewv3-into-cutover-and-collapse-view-keys-onto-viewrouter.md:400`

**Actual behavior.** The checklist item is ticked. Of the five `//`-prefixed `promotion-ready` doc keys in `package.json`, exactly **one** was amended:

| Line | Key | Mentions story 078 / Phase 4f |
|---|---|---|
| 282 | `//promotion-ready` | **no** |
| 285 | `//promotion-ready:dry` | **no** |
| 287 | `//promotion-ready:broadcast` | **yes** — carries the STORY 078 / Phase 4f text |
| 289 | `//promotion-ready:resume` | **no** |
| 291 | `//promotion-ready:verify` | **no** |

**Deviation.** The criterion is plural (*"doc keys"*, *"the broadcast legs"*) and was satisfied for one leg only. `:dry` and `:resume` both now execute Phase 4f, and `:verify` now asserts it (`VerifyPromotionReady.s.sol:312`, plus the 17th resolved address), yet all three still describe a pre-Phase-4f runbook. The top-level `//promotion-ready` narrative (`:282`) still terminates at story 076. The ticked box overstates what was done; the story's own wording made a single tick able to cover a partial edit.

---

### F-25-02 — False premise: "`via_ir` OFF" (low) · story-077 **and** story-078

**Spec, quoted verbatim** (`077:298-304`, Implementation Notes → Build constraints):

> *"### Build constraints*
>
> *Builds here use **legacy pipeline + optimizer, `via_ir` OFF**. Do not enable `via_ir` to chase a size or stack error — an EIP-170 complaint on a contract this small almost certainly means the optimizer is off, and `via_ir` caches `block.timestamp` in a way that breaks repeated `vm.warp` in tests. This view is far under the size limit regardless; `MintPageView` is 210 lines with 39 fields and deploys at ~1.76M gas."*

**Spec, quoted verbatim** (`078:310`, Implementation Notes):

> *"- Builds use **legacy pipeline + optimizer, `via_ir` OFF**. Do not turn `via_ir` on."*

**Spec sources:**
`…/077-depositpageviewv3-phlimbov3-native-deposit-page-view.md:298-304`
`…/078-wire-depositpageviewv3-into-cutover-and-collapse-view-keys-onto-viewrouter.md:310`

**Actual behavior.** `lib/phoenix-phase-2-staging/foundry.toml:5-7`:

```toml
optimizer = true
optimizer_runs = 10000
via_ir = true
```

The premise is false, and has been false for the whole range. Neither story changed it — correctly, in both cases; `foundry.toml` is out of scope for both.

**Measured under the REAL pipeline** (`via_ir = true`, `optimizer_runs = 10000`), during this run:

| Contract | Runtime bytecode | EIP-170 limit | Headroom |
|---|---|---|---|
| `DepositPageViewV3` | 6,482 bytes | 24,576 | 74% free |
| `PhlimboV3` | 14,529 bytes | 24,576 | 41% free |

**There is no live EIP-170 hazard.** That is the honest bottom line and the reason this stays low.

Two consequences nonetheless survive:

1. **Story 076's `PhlimboV3` size check was specified against the wrong pipeline.** A size assertion is only meaningful against the bytecode that will actually be deployed; the premise named a pipeline this repo does not use. The number happens to be safe under the real pipeline, but that is luck, not verification.
2. **The `vm.warp` / `block.timestamp` caching hazard the premise warns about is REAL, not hypothetical** — precisely *because* `via_ir` is on. Story 077's executor hit it and mitigated correctly, capturing `uint256 t0 = block.timestamp` once and warping to absolute `t0 + X` offsets (`077:408-411`). The mitigation is sound; it is only needed because the premise is inverted.

**Asymmetric disclosure — the part that matters.** Story 077 **self-disclosed** the falsity: Autonomous Decision 1 (`077:399-413`) states it outright — *"The worktree's `foundry.toml` actually has `via_ir = true` (with `optimizer = true`, `optimizer_runs = 10000`)"* — and the story self-files it as a carried-forward `[low]` at `:573`. Story 078 then **restated the same false premise, undisclosed**, at `:310`, with no decision-log entry and no acknowledgement of 077's correction one story earlier in the same sprint.

**The disclosure REGRESSED.** And this is now the **third consecutive story** carrying the premise: 076 → 077 → 078. A premise that gets corrected in a decision log and then reappears uncorrected in the next story is not being fixed; it is being re-copied from a template.

**Disposition.** Folded into the existing **open Low** ledger entry `c544c9f6e6c40cdb9fbd3625da54151bdbe25ea03b7ddc71766c4ae292ee8e72` (`storyTag` re-scoped to `story-076, story-077, story-078`). **No new ledger finding is created by this run.**

That entry carries an **unresolved cross-ledger Low-vs-QA severity dispute** with `phlimbo-ea` `V3-L-19` (fingerprint `38aefbfbe6da599fc5250a2cc73125465c845480e34b6a63984b2febae4a053c`), flagged for human triage. **This run did NOT re-decide that dispute**; it travels forward untouched.

---

### F-25-03 — False premise: "both views are bound to V2" (informational) · story-076

**Spec, quoted verbatim** (`076:475`, Concerns §4):

> *"So both views are bound to V2, and the live deposit UI is on the deprecated one."*

And, quoted verbatim (`076:477-484`):

> *"**Correction to an earlier draft of this story: `userInfo` does NOT break.** V3 appends `promoDebt` as the **fourth** field, leaving `amount`/`phUSDDebt`/`stableDebt` in place (`PhlimboV3.sol:199-204` vs `PhlimboV2.sol:107-111`). Both views destructure the 3-tuple via `IPhlimbo` (`DepositPageView.sol:35`, `DepositView.sol:76`), and Solidity's return decoder tolerates extra trailing returndata — the three fields still decode correctly. The problem is purely the **baked immutable address**, exactly as in the V1→V2 transition, which story 049 solved with a follow-up redeploy…"*

And follow-up (a), quoted verbatim (`076:486-489`), reproduced in full in the Grades section above — the operative words being *"a phStaging2 story to **redeploy `DepositPageView` against V3** and re-register it with `ViewRouter`"*.

**Spec source:** `/home/justin/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/076-phlimbo-v3-cutover-migration-in-promotion-ready-script.md:475, :477-484, :486-489`

**Actual behavior.** The premise is wrong about *which* V it is. The live chain resolves:

```
ViewRouter (0xC17Ce1cE5ebB43fc0cfda9Fe8BbC849c0894631a)
  .pages(keccak256("deposit"))
    -> DepositPageView  0x50D4443782bB9A6e8D65dAcd593684EDd3FF03b8
         -> immutable phlimbo = 0x3984eBC8…19F4  == PhlimboEA V1
```

The routed deposit view is bound to **V1**, not V2. Only the *deprecated, unrouted* `DepositView` is on V2. Stories 077 and 078 both independently re-derived and corrected this (`077:53-60`, `078:64-71`), so the error did not propagate into the delivered work.

**The consequence, stated carefully — this is the important part.** Follow-up (a) was specified as a drop-in: *"redeploy `DepositPageView` against V3"*. Story 076's own correction block (`:477-484`) argues that a re-cast is safe because the ABI decoder tolerates the extra trailing word. That reasoning is **technically accurate and operationally dangerous**: the `userInfo` arity change from a 3-tuple to a 4-tuple is **silently tolerated** by the decoder for static types, so a literal execution of follow-up (a) — force-cast the existing V1-typed view onto V3 and redeploy — would have **appeared to work**: no revert, a plausible `stakedBalance`, and **no promotional-reward data at all**, in the sprint whose entire purpose is to ship the promotional-reward subsystem.

**Stories 077 and 078 correctly refused the letter and served the intent.** Rather than redeploying the V1-typed contract, they built a **V3-typed** one so the compiler enforces the shape. The reasoning is documented in both places:

- `story-077:62-90` — *"### Why a V2-era view cannot simply be re-cast onto V3 … A force-cast would therefore *appear* to work while being undefined-by-accident and carrying none of the promo data. Type the new view against `IPhlimboV3` and let the compiler enforce the 4-tuple."*
- `src/views/DepositPageViewV3.sol:27-35` — the same argument carried into the shipped contract's own NatSpec, ending *"This contract types against `IPhlimboV3` and destructures the 4-tuple explicitly so the compiler enforces the shape."*

**Credit is due explicitly: this is the correct handling of a defective spec.** A faithful-to-the-letter execution would have produced a silently-wrong deposit page. The executors identified the defect, documented it, and delivered the story's *intent*. **No corrective action is owed.** Recorded as informational so that the 076 text is not later mined as authority for a re-cast.

---

### F-25-04 — Story-unsafe: sanctioned break lands before the path that replaces it (low) · story-078

**Ledger fingerprint:** `1beb1797733b64e6725d003a16f6ff71a6a118b90410178e63c3c1bf3a1620ba`
**Also filed as:** `L-01` in the QA bundle — one fingerprint, two labels.

**Law-1 override candidate, resolved as a Law-3 footgun.**

**Spec, quoted verbatim** (`078:18-28`, Story Overview, the key-collapse half):

> *"2. **Collapse the address surface onto the router.** Remove the `DepositView`, `DepositPageView` and `MintPageView` keys from the `ContractAddresses` interface and from every address book that implements it, leaving `ViewRouter` as the sole view-related key. Deliberately do **not** add a `DepositPageViewV3` key — the whole point is that consumers resolve views through `ViewRouter.pages(keccak256("<page>"))`, not through a hand-maintained address book.*
>
> *The second half is a deliberate downstream-breaking change. The Phoenix UI is the only real consumer of these keys (`addresses.ts:3` — "This interface can be copied directly into UI projects"), and adapting it is out of scope for this repo. That is an accepted, owner-sanctioned cost."*

**Spec, quoted verbatim** (`078:39-41`, Scope):

> *"- **Out**: **no broadcast.** Story 072 has never been broadcast and remains on ice pending its Kendu fee-on-transfer preflight. This story is script-and-tooling only, validated by dry run."*

**Spec source:** `…/078-wire-depositpageviewv3-into-cutover-and-collapse-view-keys-onto-viewrouter.md:18-28, :39-41, :72`

**Actual behavior.** The story's two halves land on **different clocks**, and only one of them is at `712cbdb`:

- **Source side — landed.** All three view keys are gone from `addresses.ts`, `local-addresses.ts` and `mainnet-addresses.ts` (parity `55 == 55`), and `DROPPED_CONTRACT_NAMES` makes the deletion durable. From `712cbdb` onward, the **only sanctioned resolution path** for a deposit view is `ViewRouter.pages(keccak256("deposit"))`.
- **Chain side — not landed.** The `setPage` that repoints that router entry sits inside `_phase4f_depositViewCutover()`, reachable only via `promotion-ready:broadcast`, which 078 puts explicitly out of scope and which story 072 keeps on ice.

**Deviation.** The story **sanctions the downstream break** — and that sanction is legitimate; the owner accepted the UI cost knowingly. What the story never states is that **the sanctioned replacement path is provably wrong until the broadcast lands.** `pages(keccak256("deposit"))` today returns a `DepositPageView` bound to PhlimboEA **V1**. A consumer that does exactly what the story tells it to do gets V1 numbers.

The story reads as though Phase 4f has already executed. Quoted verbatim (`078:72`):

> *"This story performs the first one."*

— of the mainnet deposit-page repoints. It performs it in *code*. It does not perform it on *chain*, and nothing in the Story Overview or the header separates those two senses.

**Why this is in scope under Law 3.** Removing the UI's `DepositView` fallback **forces story-076 follow-up (b) into exactly the (b)-before-(a) window that (a) was meant to close first**. That inversion is precisely the ordering constraint recorded on the parent ledger entry `6b63ef6516ac1751c6611aa0de8273427425eba6b1d771824d4526adf76e7cea` (`fixOrderingConstraint`). A competent, non-malicious owner reading story 078 would reasonably conclude the deposit page is now router-resolved and safe to migrate the UI onto. It is not, and will not be until a broadcast that the same story defers. **Non-obvious owner consequence ⇒ footgun ⇒ in scope.**

**Why Low and not Medium.** No funds move. No chain state was changed by this commit. The break is **compile-time-loud** — a consumer referencing a deleted key fails to build under the downstream `tsc --strict` guard rather than silently reading a wrong address. It is a forced, visible decision point, not a silent impact. This grading is recorded as `borderline` on the ledger entry with the reasoning preserved for human re-weighing; this report does not re-decide it.

---

### F-25-05 — Scope overrun, self-disclosed (informational) · story-078

**Spec, quoted verbatim** (`078:32-37`, Scope → In):

> *"- **In**: `script/DeployMainnetPromotionReady.s.sol`, `script/VerifyPromotionReady.s.sol`, `server/deployments/addresses.ts`, `server/deployments/mainnet-addresses.ts`, `server/deployments/local-addresses.ts`, `server/extract-addresses.js`, `scripts/patch-mainnet-addresses-promotion-ready.js`, `scripts/patch-mainnet-addresses-deposit-view.js`, `scripts/patch-mainnet-addresses.js`, `server/index.js`, `wagmi.config.ts`, `hooks/generated.ts` (regenerated), `hooks/package.json`, `package.json`."*

**Spec source:** `…/078-…viewrouter.md:32-37`

**Actual behavior.** Three files outside that list were changed:

| File | Nature | Disclosure |
|---|---|---|
| `test/VerifyPromotionReadyGuards.t.sol` | **New.** The Scope names no `test/` path at all. | Decision 6 (`078:646-667`) |
| `scripts/patch-mainnet-addresses-mintpageview.js` | Modified | Decision 7 (`078:669-681`) |
| `scripts/patch-mainnet-addresses-ratchet.js` | Modified | Decision 7 (`078:669-681`) |

**Deviation.** Each is a **net improvement**, each was disclosed before the fact, and the reviewer independently confirmed that dropping the ratchet patcher's `MintPageView` row cannot make `matchDeploysToExpected()` fail (`078:776-781`). The new test file directly answers the attempt-1 failure report's own instruction to pin the class of bug rather than the symptom.

**This is NOT a defect.** It is recorded here for **visibility**: the extension is currently documented only inside a decision log within an auto-completed — that is, machine-approved, never human-reviewed — story. A scope extension that no person has seen should be surfaced somewhere a person reads.

---

### F-25-06 — Declined checklist literal; the code is more correct than the story (informational) · story-078

**Spec, quoted verbatim** (`078:375`, Checklist → Script):

> *"- [x] Add `DepositPageViewV3` to the `_requireNotPhusdMinter` sweep in `VerifyPromotionReady._verifyMintAuthorityInvariance()`, bumping the count 16 → 17 **including the log string**"*

And, quoted verbatim (`078:204-208`, Technical Details):

> *"2. **`_requireNotPhusdMinter` sweep** in `VerifyPromotionReady._verifyMintAuthorityInvariance()` (`:169-208`), which asserts *"none of the N newly deployed contracts holds phUSD mint authority"* and logs the count. `DepositPageViewV3` **is** a newly deployed contract and **must** be added to that sweep, bumping N from 16 to 17 — including the log string. Story 076 already bumped it 14 → 16; this is the same edit one more time."*

**Spec source:** `…/078-…viewrouter.md:375, :204-208`

**Actual behavior.** `script/VerifyPromotionReady.s.sol:308-313`:

```solidity
// Story 078: DepositPageViewV3 is a newly deployed contract, so it joins the sweep. It is
// a pure view with no mint call anywhere in it, which is exactly why the sweep — not a
// judgement call — is what proves it holds no authority. 15 -> 16 swept, 17 new contracts
// in total once the positively-asserted PhlimboV3 is counted.
_requireNotPhusdMinter(newDepositPageViewV3, "DepositPageViewV3");
console.log("  none of the other 16 newly deployed contracts holds phUSD mint authority");
```

The log string says **16**, and there are exactly **16** `_requireNotPhusdMinter` call sites. The story's **17** counted `PhlimboV3`, which is **deliberately EXCLUDED** from the sweep because it is *positively asserted* to hold mint authority — sweeping it would assert the opposite of the invariant.

The reconciliation is documented at `078:453-465` (Decision 4): *"The story's 16 → 17 counts all new contracts; the code's number counts only those actually swept. Both are correct on their own terms, so I matched the number to the thing the string describes."*

**The code is MORE correct than the story text.** Writing `17` into the log string, as the checklist literally demands, would have made the message assert a count the loop does not perform. **Not a defect** — recorded because the checklist box is ticked against a literal that was, correctly, declined.

---

### F-25-07 — Residual stale reference in the dangling-reference sweep (qa) · story-078

**Ledger fingerprint:** `17b3642f61351922a637c23183aaf8ad9f3587600fdcc6bdf8ac697007af0087`
**Also filed as:** `Q-02` in the QA bundle — one fingerprint, two labels.

**Spec, quoted verbatim** (`078:277-280`, Technical Details):

> *"**Do not add a `DepositPageViewV3` key anywhere.** Its address is published by `ViewRouter.pages(keccak256("deposit"))` on-chain and recorded in `server/deployments/progress.1.json` by `_trackDeployment`. Adding a key would recreate the exact dual-resolution problem this story removes."*

The corresponding sweep obligation, quoted verbatim (`078:391-392`, Checklist → Address surface):

> *"- [x] Remove the dead `ViewRouter`/`DepositPageView`/`MintPageView` entries from `PROGRESS_TO_TS_KEY` in `scripts/patch-mainnet-addresses.js:38-40`*
> *- [x] Remove `'DepositView'` from `server/index.js:80`"*

**Spec source:** `…/078-…viewrouter.md:277-280, :391-392`

**Actual behavior.** `script/DeployMainnetMintPageView.s.sol:94` still prints:

```solidity
console.log("\nNEW MintPageView:", newMintPageView, "(patch mainnet-addresses.ts MintPageView -> this)");
```

**Deviation.** Story 078 deleted the `MintPageView` address-book key and swept the dangling references it created — **twice in JS** (`patch-mainnet-addresses.js`, `patch-mainnet-addresses-mintpageview.js`) and **once in `package.json`**. The sweep was **not extended to the one Solidity site**. The instruction now tells an operator to patch a key that no longer exists.

Impact is documentation-only and fails visibly: an operator who follows it finds no `MintPageView` key and stops. Filed standalone and deliberately **not merged** with the spent-one-shot Low (`L-04`) — different file, different fix site, different root cause; merging would let a fix to one silently mark the other resolved.

---

## Positive process note

Story 078's own review chain **caught a genuinely blocking defect in attempt 1 and fixed it properly**, and that deserves the record.

The defect (`078:582-618`): `DeployMainnetPromotionReady._parseProgressJson()` hydrated every runtime address member from the parsed `deployments` map — including story 076's `newPhlimboV3` and `migratorV2V3` — but **never hydrated `newDepositPageViewV3`**. The member was assigned only inside `_phase4f_depositViewCutover()`, which the read-only verifier never runs. `VerifyPromotionReady._loadAndValidateProgressFile():155` would then have called `_requireResolved(newDepositPageViewV3, "DepositPageViewV3")` against `address(0)` and reverted.

**Consequence had it shipped:** `promotion-ready:broadcast`'s trailing `&& npm run promotion-ready:verify` — the only outcome verification the broadcast path has at all — would have failed **100% of the time** after an otherwise successful cutover, and none of Phase 7's new deposit-page assertions would ever have executed. The dry run structurally could not surface it: it writes no progress file and never invokes the verifier.

The fix landed in `f556d22` at `script/DeployMainnetPromotionReady.s.sol:3069`, inside `_parseProgressJson()`'s own body. What makes it worth recording is that the executor **did not stop at the one-liner**. Decision 6 (`078:646-667`) added `test_everyRequiredAddressIsHydratedFromProgressFile()`, a **source-derived** guard: it re-reads every `_requireResolved(member, "Name")` call site out of the verifier's source and demands a matching `member = deployments["Name"].addr;` inside `_parseProgressJson`'s own body, asserting the count is 17. The scoping to that function body is load-bearing — Phase 4f assigns the same member from the same map at `:2056`, so an unscoped search would have **passed on the broken code**. The guard would therefore catch the *next* instance, not merely the one that was found.

Non-vacuity was established twice: by the executor reverting the fix and observing the failure, and independently by the reviewer establishing it structurally from the `_parseProgressJsonBody()` slice boundaries rather than trusting that experiment (`078:749-753`). Final state: **9/9 pass** in the guards suite; the wider run reports 76 passed / 0 failed / 3 skipped with `.envrc` sourced.

**This is recorded as evidence the review loop worked. It is not an open finding.**

---

## Recommendations

1. **Correct the "`via_ir` OFF" premise in the SPRINT TEMPLATE, not just in one story's decision log.** It has now survived **three consecutive stories** (076 → 077 → 078) and, worse, **one disclosure regression** — 077 caught and disclosed it, 078 restated it undisclosed. Fixing it story-by-story has demonstrably failed; the text is being re-copied from a source upstream of the individual story. Correct that source. The measured headroom (6,482 / 14,529 bytes against 24,576) means this is cheap to do calmly, before it is expensive.

2. **Gate the `phlimbo-ui` follow-up (b) on OBSERVED on-chain state, not on a story's completion status.** The gate must be `ViewRouter.pages(keccak256("deposit")) == <DepositPageViewV3>` read from chain — **not** story-078 being in `auto-complete/`. Story 078 is complete and the router is still bound to PhlimboEA V1; those two facts are not in tension, and any process that treats story completion as a proxy for chain state will invert the (a)-before-(b) ordering exactly as F-25-04 describes.

3. **Extend the dangling-reference sweep to Solidity sites** when an address-book key is deleted (F-25-07), and **enumerate doc keys individually in checklists** so one tick cannot cover a partial edit (F-25-01).
