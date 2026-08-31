# Script Audit Review — `promotion-ready`

**Project**: phoenix-phase-2-staging @ `712cbdb` (branch `master`)
**Run**: `phoenix-phase-2-staging-25` — regression scan, baseline `b9391b1`
**Entry-point family**: `promotion-ready` — 5 executable npm keys (`:snapshot`, `:dry`, `:broadcast`, `:resume`, `:verify`) over one forge target (`script/DeployMainnetPromotionReady.s.sol`) plus its inheriting verifier (`script/VerifyPromotionReady.s.sol`)
**Mode**: fork-preview against live mainnet (Alchemy, chain tip ~block 25681402–25681503). `:dry` executed; `:broadcast` and `:resume` never executed.
**Delta audited**: `3c60824` [story-077] → `7debc83` [story-078] → `f556d22` [story-078 fix] → `712cbdb` (merge `sprint/promotion-ready`)

> This document **supplements** the run's submission artifacts — `submissions/qa-report.md` (the Low/QA bundle) and `submissions/spec-conformance.md` (the story-faithfulness record). It does not replace them. The fingerprints below are the authoritative ledger identities and are carried verbatim.

---

## Headline verdict

Stories 077 and 078 close the PhlimboV3 deposit-view gap **in design**, and the design is good. But the fix is **half-landed**.

- **Source side — landed.** The address-key collapse is committed at `712cbdb`: `DepositView`, `DepositPageView` and `MintPageView` are deleted from all three address books (58 → 55 keys in `addresses.ts` and `mainnet-addresses.ts`; 57 → 54 in `local-addresses.ts`). From this commit onward there is **no address-book key naming a deposit view**; the only sanctioned resolution path is `ViewRouter.pages(keccak256("deposit"))`.
- **Chain side — not landed.** The `setPage` that repoints that router entry at the new `DepositPageViewV3` lives at `DeployMainnetPromotionReady.s.sol:2077-2088` and fires **only** under `promotion-ready:broadcast`. Story 078 declares broadcast out of its own scope: *"no broadcast… story 072 remains on ice pending its Kendu fee-on-transfer preflight."*
- **Chain verified unchanged.** At block 25681503, `ViewRouter.pages(keccak256("deposit"))` still returns `0x50D4443782bB9A6e8D65dAcd593684EDd3FF03b8`, whose immutable `phlimbo()` binds `0x3984eBC8…19F4` — **PhlimboEA V1**.

**State this plainly: this is not a botched patch.** Phase 4f is correct, and it is fork-verified end to end. Its two stages simply landed in the wrong order. The ⚠ **INCOMPLETE FIX** signal applies for exactly one reason — a half-landed fix reads as done — and that is why the ordering constraint inherited from the parent finding (`6b63ef65…`) is the single most important carry-forward in this report: **(a) repoint the view against V3 before (b) moving any consumer onto router resolution.**

**Severity outcome: 0 High, 0 Medium.** 4 Low, 3 QA, 1 parked manual-review item. The severity reasoning is set out in full below; it is not an omission.

---

## 1. Does it do what it intends?

Substantially yes, and the evidence for that is empirical rather than inferential.

### 1.1 The preview ran clean against live mainnet

`promotion-ready:dry` (`PREVIEW_MODE=true`, impersonated OWNER, signs nothing, broadcasts nothing) was executed from `workspace/` against `$RPC_MAINNET`:

- **exit 0, no revert, ~6 minutes, 392 log lines.** No `--broadcast` and no `--ledger` flag was present at any point.
- **Snapshot gate passed** — `check-phlimbo-snapshot-age.js --variant v2 --fail-on-stale`: v2 snapshot 11.00h old against a 24h threshold.
- **Phase 0 preconditions all pass** — `VIEW_ROUTER` has code; `ViewRouter.owner()` is `0xCad1a786…D0B6`, identical to the script's `OWNER` constant at `:227`; the incumbent `pages("deposit")` is **logged and deliberately not asserted** (pinning it would abort the very run that fixes it — the right call).
- **Phase 4e conservation is EXACT** — baseline and V3 `totalStaked` both `13095559131012692364262`, with **zero** `UserMigrationSkipped` events across 16 users.
- **Phase 4f produced exactly its two declared writes and nothing else** — the `DepositPageViewV3` CREATE and the single `ViewRouter.pages[keccak256("deposit")]` update. No collateral write, no event, no ownership change, no approval, no token movement. `side-effects.json.unintendedEffects` is empty, and that emptiness is a measured result, not an unexamined default.
- **Phase 7 all-pass**, **Phase 8 printed all 23 named fields** for human eyeball.
- **The preview correctly wrote no progress file** (`_trackDeployment`/`_trackConfig` are `isPreview`-gated). This is right: a preview CREATE address is fork-local fiction and would poison the patcher if persisted.

### 1.2 The V3-nativeness proof is genuinely strong

This deserves specific credit, because the obvious version of this assertion would have been worthless.

`_phase7_depositViewAssertions()` does not merely check `pages(DEPOSIT_KEY) == newDepositPageViewV3` and `v.phlimbo() == newPhlimboV3`. It round-trips `router.getData(DEPOSIT_KEY, OWNER).length == 23` (exactly 23, not `>=`) through the router. Producing those 23 fields forces calls to `getPromoInfo()`, `stakerCount()`, `unclaimablePromoOf()`, `unclaimableStableOf()` and `unclaimablePhUSDOf()` — **every one of which reverts on a V1 or V2 Phlimbo.**

The significance: a pointer-only check would have passed happily throughout the entire V1→V2 era while the deposit page stayed bound to V1 — which is precisely the defect being fixed. This assertion cannot. It is the difference between a check that would have caught the bug and one that demonstrably did not.

(The in-phase post-assert `DepositPageViewV3(newDepositPageViewV3).phlimbo() == newPhlimboV3` **is** tautological on a fresh deploy — it reads back a constructor argument. It is not tautological on a `:resume`, where the address arrives from the progress file's `_isDeployed` branch, and that is the branch it actually guards.)

### 1.3 Failure recovery mid-4f fails closed

`_isDeployed` and `_isConfigured` are separate progress keys, and the phase orders the CREATE before the `setPage`. If a recorded CREATE never actually landed, the resume path calls `v.phlimbo()` on a codeless address and **reverts**, rather than repointing the router at nothing. Fail-closed is the correct disposition for a router repoint, and it is what the code does.

Sequencing is also correct in the other direction: `setPage` is the phase's **last** step. Repointing before the V3 exists and is migrated would show not-yet-migrated users a zero-balance page.

### 1.4 The attempt-1 defect was real, and its fix is not a vacuous harness

Commit `f556d22` fixed a genuinely blocking defect from story 078's first attempt: `_parseProgressJson` never hydrated `newDepositPageViewV3`, which would have aborted **100%** of post-broadcast `promotion-ready:verify` runs at `_requireResolved`.

The guard shipped with it — `test/VerifyPromotionReadyGuards.t.sol`, a project-tracked test — **re-reads every `_requireResolved` call site from source** and asserts the hydration count matches (17), rather than hardcoding the list. That means it catches the *next* instance of this class, not just this one. 9/9 pass; `test/DepositPageViewV3.t.sol` is 23/23. This is the opposite of a vacuous harness and should be recognised as such.

### 1.5 Story faithfulness

- **Story 077 — FAITHFUL.** 16/16 acceptance criteria MET.
- **Story 078 — SUBSTANTIALLY FAITHFUL.** 30/33 met; the three misses are documentation sweeps (see §3 and the root-cause family below), not behavioural deviations.
- **Key-set parity independently reproduced.** The patcher's own `interfaceKeys()` / `dataKeys()` regexes were re-implemented against `addresses.ts` and `mainnet-addresses.ts` at `712cbdb`: **interface = 55, data = 55, empty difference in both directions.** The "58" a naive regex reports is the three commented-out `Burner*` entries — not drift.
- Keys were **deleted, not commented out**, in all three files, matching story 078's own rule (*"a commented key is a booby trap: `dataKeys()` strips comments"*), and `DROPPED_CONTRACT_NAMES` was amended so a local anvil deploy cannot silently regenerate them.
- **`PhlimboV3` in `mainnet-addresses.ts` is still `0x0000…0000`** — independent confirmation that nothing in this family has ever been broadcast.

### 1.6 EIP-170 concern retired permanently

Both stories assert as a load-bearing premise that *"builds here use legacy pipeline + optimizer, `via_ir` OFF"*. `foundry.toml:7` has `via_ir = true` and always has. Measured under the **actual** pipeline (`via_ir=true`, `optimizer=true`, `optimizer_runs=10000`):

| Contract | Runtime bytes | Limit | Headroom |
|---|---:|---:|---:|
| DepositPageViewV3 | 6,482 | 24,576 | 18,094 |
| PhlimboV3 | 14,529 | 24,576 | 10,047 |
| MigratorV2V3 | 8,248 | 24,576 | 16,328 |

**No EIP-170 exposure.** The false premise cannot brick this deploy on size. Story 076's size check having been specified against the wrong pipeline is a documentation defect, not a live hazard. (The premise itself is handled as a process matter in §4.)

---

## 2. Does it introduce unintended side effects?

**No.** Phase 4f's write set is exactly its declared write set, and the deletions it performs leave nothing dangling on the executable paths.

- **Write set (fork-observed, exhaustive for the delta):**

  | # | Target | Effect | Intended |
  |---|---|---|:--:|
  | 1 | `DepositPageViewV3` (fork-local `0xA47A…Ed35`) | CREATE; immutables `phlimbo` = Phase-4e PhlimboV3, `phUSD` = `0xf3B5…D605` | yes |
  | 2 | `ViewRouter` `0xC17Ce1cE…631a` | `pages[keccak256("deposit")]`: `0x50D4…03b8` → the new view | yes |

  Both fork-local addresses are fiction by construction — no progress file is written in preview, and a real broadcast derives a different nonce-based CREATE address.

- **The deleted `patch-mainnet-addresses-deposit-view.js` has no dangling invoker.** Its only caller was the tail of `rewire-sya-to-phlimbo-v2:broadcast`, and that tail was removed in the same commit. **Confirmed clean.** The parallel `patch-mainnet-addresses-mintpageview.js` tail was likewise removed and the script is now inert (it can only exit 4), documented in-file.
- **The `keccak256("deposit")` slot is otherwise untouched anywhere on mainnet.** The only other `setPage(keccak256("deposit"), …)` in the entire repo is `DeployMocks.s.sol:1278`, chain 31337. That single fact is the load-bearing evidence for the claim that the mainnet deposit page has *never once* been repointed — while the `"mint"` slot has been repointed at least twice.
- **`patch-mainnet-addresses.js`'s `PROGRESS_TO_TS_KEY` map** lost its `ViewRouter` / `DepositPageView` / `MintPageView` rows. Harmless: that patcher is spent and `ViewRouter` is never redeployed. `ViewRouter` remains a live key in `mainnet-addresses.ts`.

The residues that *did* survive the sweep are documentation and dead code, and are filed as **L-02, L-04, Q-02, Q-03** (see §5).

---

## 3. Have other problems surfaced because of it?

### 3.1 The chain contradicts story 076 — and 077/078 were right to refuse its follow-up

Story 076's Concerns §4 asserts that **both** views are bound to V2. The chain disagrees.

| Contract | Address | Binds |
|---|---|---|
| `DepositPageView` (routed as `"deposit"`) | `0x50D4…03b8` | **PhlimboEA V1** `0x3984eBC8…19F4` |
| `DepositView` (not routed) | `0x0725…5251` | PhlimboV2 |

V1 identification is **positive, not inferred**: `userInfo` returns a 3-tuple (V2/V3 return more); `getPromoInfo()`, `stakerCount()` and `FIELD_COUNT()` all revert (absent on V1); `getNames()` returns 7 entries, not 23. Corroborated independently by `server/deployments/mainnet.backup.2026-03-19_*.ts:13`.

The origin is traceable: `script/RewireSYAToPhlimboV2.s.sol:45-50` records the V1→V2 decision in which `DepositPageView` was judged deprecated and deliberately **not** redeployed, while the one actually marked `@deprecated` (`DepositView`) **was** — producing exactly the inversion now confirmed on chain.

**The consequence is worth stating carefully.** Because story 076 had the binding backwards, it mis-specified its own follow-up (a) as a drop-in *"redeploy `DepositPageView` against V3"*. Executing that literally would have force-cast a V3 Phlimbo into a **V1-shaped** interface. And the `userInfo` arity change (3-tuple → 4-tuple) is one the ABI decoder **silently tolerates** — it accepts extra trailing returndata for static types. The redeploy would therefore have **appeared to work** while carrying no promo data at all: a silent, plausible, wrong deposit page shipped under the banner of a completed fix.

Stories 077 and 078 refused the *letter* of follow-up (a) and served its *intent* instead, by building a **V3-typed** contract (`DepositPageViewV3 is IPageView`, importing `IPhlimboV3`, destructuring `userInfo` as a 4-tuple). **This is the best decision in the delta**, and it is worth crediting explicitly: the correct response to a wrong specification was to fix the specification, and that is what happened.

### 3.2 Why the current window is hazardous rather than merely stale

PhlimboEA V1 is **paused** and holds **zero phUSD**, while still reporting `totalStaked() == 13,615.682e18`. A view bound to it therefore serves numbers that are believable, non-zero, and **fabricated** — not obviously-broken numbers a user would distrust.

Run-24's PoC, replayed at `712cbdb`, reproduces **STILL-LIVE 3/3**. It **compiles and runs** (3 passed, 0 failed, 1.05s), so this is a live reproduction, not bit-rot:

- a staker with a true position of **1517.63 phUSD renders as 0**;
- another with a true **729.67 renders as 398.86** — the more dangerous of the two, because a wrong non-zero number invites no scrutiny.

> **Provenance, stated explicitly:** this PoC (`test/poc-M-01-stale-view-router-deposit-page.t.sol`) is **audit-authored and untracked at `712cbdb`**. It is cited here as *audit evidence only*, and must not be counted as project test coverage. The project's own tracked coverage for this delta is `test/VerifyPromotionReadyGuards.t.sol` (9/9) and `test/DepositPageViewV3.t.sol` (23/23).

The replay does **not** impeach the fix. The fix is a broadcast-time change, and `promotion-ready` has never been broadcast. The PoC measures chain state; stories 077/078 changed source. That gap *is* L-01.

### 3.3 MR-25-01 — the 13,615.68e18 is residue, not stranded value (parked)

The V1 figure is **accounting residue** left by the V1→V2 migration: the phUSD moved with the migration and only the counter stayed behind. **Nothing is owed to V1 stakers**, and this is not stranded user value. It is also the empirical answer to the standing question *"why does V1 appear to hold more than V2?"*

Root cause lives in `lib/phlimbo-ea` V1's migration path — **outside** the `promotion-ready` closure this run audited. It is therefore **parked, not dropped**, in `manual-review.json` as **MR-25-01**. Recommended next step: a separate `/analyze` of phlimbo-ea V1's migration path, rather than expanding this audit's scope.

---

## 4. Process note — the `auto-complete` state folder

Stories 077 and 078 both sit in a **non-standard `auto-complete`** state folder (`~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-promotion-ready/`). Per story 078's own Autonomous Decision 1 this is **terminal** — machine approval resolving a block exactly as human approval would — making it a sibling of `complete`, not a staging area. Story 076, by contrast, went to normal `complete` and carries a `## Human-Confirmed` section recording its promotion.

**Consequence: stories 077 and 078 are machine-approved and were never human-reviewed.** That is the context in which the false *"`via_ir` OFF"* premise propagated across three consecutive stories. Note the direction of travel: story 077 **self-disclosed** the discrepancy (Autonomous Decision 1, plus a self-filed `[low]`), and story 078 then **restated the premise undisclosed**. The disclosure **regressed** between the two.

This is folded into the **existing open Low `c544c9f6`**, re-scoped to name stories 077 and 078. **No new finding is raised** for it.

---

## 5. Findings register

**0 High · 0 Medium · 4 Low · 3 QA · 1 parked (MR-25-01)**

Root-cause family — **L-02, Q-02 and L-04 share one cause: spent or deleted artefacts left stale guidance behind.** Story 078's sweep of dangling references was thorough in the JS patchers and in `package.json`, but missed the **Solidity** sites and the **doc keys**. Each is filed separately by design: different file, different fix site — merging them would let one fix silently mark the others resolved.

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-01**<br>`1beb1797…` | Low | Story 078's address-key collapse landed while the `ViewRouter` repoint that justifies it remains broadcast-gated; the only sanctioned deposit-view resolution path still binds PhlimboEA **V1**. ⚠ INCOMPLETE FIX of `6b63ef65…`. | Honor the inherited ordering constraint — repoint the view against V3 **before** moving any consumer onto router resolution. Gate the phlimbo-ui follow-up on **observed on-chain** `pages(keccak256("deposit")) == <DepositPageViewV3>`, not on story-078's completion status; in the interim either restore the `DepositView` key with a `DO NOT REMOVE until promotion-ready has broadcast` comment, or add an explicit "NOT YET REPOINTED" line to the `mainnet-addresses.ts:19-24` provenance block. | [`server/deployments/mainnet-addresses.ts`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/server/deployments/mainnet-addresses.ts) · repoint at [`DeployMainnetPromotionReady.s.sol#L2077-L2088`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMainnetPromotionReady.s.sol#L2077-L2088) |
| **L-02**<br>`83a40563…` | Low | Four `//`-prefixed `package.json` doc keys still describe a pre-Phase-4f runbook, though `:dry` and `:resume` execute Phase 4f and `:verify` asserts it. Only `//promotion-ready:broadcast` carries the story-078 text. No executable key is wrong. | Amend `//promotion-ready:resume` to name Phase 4f, its two `_isConfigured`-gated steps and the **two extra Ledger signatures**; amend `//promotion-ready:dry` for the Phase 0 preconditions and Phase 8 probe; amend `//promotion-ready:verify` for the 17th resolved address and 16th swept contract; refresh the top-level `//promotion-ready` narrative past story 076. Reword story 078's checklist line to enumerate the keys so one tick cannot cover a partial edit. | [`package.json`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/package.json) — `//promotion-ready` (`:282`), `:dry`, `:resume`, `:verify` |
| **L-03**<br>`449812a6…` | Low | `_printSummary` prints all 16 other new runtime addresses but omits `newDepositPageViewV3` — the one deployment deliberately given **no** address-book key, hence the one for which the transcript is the last human-readable record. | Add one line to `_printSummary` printing `newDepositPageViewV3`, with a note that it is intentionally keyless and resolvable via `ViewRouter.pages(keccak256("deposit"))`. Costs nothing and introduces no second resolution path. | [`DeployMainnetPromotionReady.s.sol#L3363`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMainnetPromotionReady.s.sol#L3363) |
| **L-04**<br>`e1d52b7b…` | Low | The spent `rewire-sya-to-phlimbo-v2:dry` / `:broadcast` keys remain npm-runnable against mainnet; running them would `setPhlimbo`/`approvePhlimbo` on the **live** SYA toward a wound-down PhlimboV2 and deploy a V2-bound view over a V3 protocol. Story 078 half-retired the leg by deleting its patcher tail — it is now spent **and** broken. | Delete the executable `:dry` / `:broadcast` keys, retaining only the `//` doc key as history; or prefix the command with `echo 'SPENT ONE-SHOT — refusing' && exit 1 &&`. Apply the same treatment to every other spent one-shot that is still npm-runnable. | [`package.json`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/package.json) — `rewire-sya-to-phlimbo-v2:broadcast` |
| **Q-01**<br>`a1ac89dc…` | QA | `promotion-ready:resume` retains the mutating address-book patcher but omits the leading `backup-mainnet-addresses.js` leg. The omission is deliberate and documented, and `mainnet-addresses.ts` is git-tracked, so a full pre-image always exists. | Restore the idempotent timestamped backup leg to `:resume` (a second snapshot costs nothing), **or** add a precondition to `patch-mainnet-addresses-promotion-ready.js` requiring a `mainnet.backup.*.ts` newer than the progress file, exiting non-zero otherwise. | [`package.json`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/package.json) — `promotion-ready:resume` |
| **Q-02**<br>`17b3642f…` | QA | A spent script still prints the operator instruction *"(patch mainnet-addresses.ts MintPageView -> this)"* — naming a key story 078 deleted. Fails visibly; no state is reachable by following it. | Delete or amend the line-94 instruction to state that `MintPageView` is no longer an address-book key and that view addresses resolve through `ViewRouter`; sweep the remaining Solidity scripts for the same class of stale operator instruction. | [`DeployMainnetMintPageView.s.sol#L94`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/DeployMainnetMintPageView.s.sol#L94) |
| **Q-03**<br>`55cbd7d0…` | QA | `patchFlatField`'s `update === true` unconditional-overwrite branch is dead — story 078 removed the sole `update: true` row (`MintPageView`). Filed as a **latent** hazard, not a present defect: unreachable at `712cbdb`. | Delete the unreachable `update===true` branch and its parameter; if retained for future use, add a unit test exercising the overwrite path so the first future `update: true` row does not go live against the mainnet address book untested. | [`scripts/patch-mainnet-addresses-ratchet.js`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/scripts/patch-mainnet-addresses-ratchet.js) — `patchFlatField` |

**MR-25-01** (parked, not filed): PhlimboEA V1 reports `totalStaked() == 13,615.682e18` against a zero phUSD balance — migration residue, **not** stranded user value; root cause outside this closure. See §3.3.

---

## 6. Severity honesty — why no Medium

Two candidates were considered for Medium and both were rejected on the record.

### L-01 — display-only ceiling

The impaired surface is a **front end in a separate repository** (`phlimbo-ui`). No on-chain function is impaired; this commit changed **no chain state**; withdrawal still transacts against real contracts with real numbers. The harm ceiling is what a user *sees*, which under C4 criteria does not reach *"assets at risk"* or *"protocol function or availability impacted"*. The key deletion also breaks at **compile time** under the repo's `tsc --strict` drift guard — a consumer cannot silently read a wrong address; it fails to build. That makes it a forced, visible decision point rather than a silent impact.

Two things must be recorded alongside that grade:

- The parent finding `6b63ef65…` was **human-regraded medium → low on 2026-08-04** on an impact basis (blast radius zero, because phlimbo-ui reads `DepositView` directly via `useDepositViewPolling.ts:94`). **L-01 reinforces that regrade rather than overriding it.**
- L-01 is nevertheless flagged **borderline**. Story 078 deletes exactly that escape hatch, and a human may reasonably read the deleted escape hatch as an *impact* change rather than a likelihood change, and restore Medium. Whatever the grade, **the (a)-before-(b) ordering constraint must survive it.**

### L-04 — disclosed, therefore Law-3 obvious

Running the retained `rewire-sya-to-phlimbo-v2` key would `setPhlimbo`/`approvePhlimbo` on the **live** StableYieldAccumulator — genuinely *"protocol function impacted"*, and the highest on-chain harm ceiling anywhere in this run's finding set. It stays below Medium because the consequence is **disclosed in its own adjacent doc key** (*"retained as history, not as a runnable leg"*). Under Law 3 a disclosed consequence is obvious to a competent, non-malicious owner rather than a footgun, and C4 lists reckless admin mistakes as known-invalid.

The **residual that is reported** is narrower and real: the key is still **executable**, one `npm run` from the live SYA, and story 078 has already broken it half-way by deleting its patcher tail.

Two grades moved during classification and both are recorded in the findings' `severityHistory`: **Q-01 was downgraded low → qa** after its premise (*"no recoverable pre-image"*) was struck as factually wrong — `mainnet-addresses.ts` is git-tracked and not gitignored, so `git checkout --` fully restores it; and **L-04 was upgraded qa → low** on harm-ceiling grounds, a one-notch move inside the same QA bundle.

---

## 7. What a reader should take away

1. **Phase 4f is good work.** It is correctly sequenced, fork-verified, fails closed on partial failure, and its central assertion is one that would actually have caught the bug it fixes. Its refusal of story 076's mis-specified follow-up (a) avoided shipping a silently-empty deposit page.
2. **It is not finished.** The source half is committed; the chain half is not, and will not be until `promotion-ready:broadcast` runs — which story 078 explicitly put out of scope pending story 072's Kendu fee-on-transfer preflight. Until then the routed deposit page serves believable, fabricated numbers from a paused, empty V1 contract.
3. **The ordering constraint is the load-bearing recommendation.** Gate any downstream consumer migration on the **observed on-chain** router value, never on a story's completion status.
4. **Nothing here is an emergency.** 0 High, 0 Medium; the remaining seven items are documentation drift, a missing summary line, a still-runnable spent key, and one dead branch.
