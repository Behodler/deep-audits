# QA Report — phoenix-phase-2-staging (run-25)

| | |
|-|-|
| **Project** | `phoenix-phase-2-staging` |
| **Commit** | `712cbdb` (`master`) |
| **Run** | `phoenix-phase-2-staging-25` |
| **Audit type** | **Script audit** (`/audit-script`) — the unit of review is a `package.json` entry point and its transitive closure, not a contract set |
| **Entry point family** | `promotion-ready` (`:snapshot`, `:dry`, `:broadcast`, `:resume`, `:verify`) |
| **Audit mode** | Fork-preview execution against live mainnet state, plus static reasoning over the closure |
| **Story under review** | `story-078` (Phase 4f) |

**This QA report is the primary submission artifact for run-25.** The run produced **0 High and 0 Medium** findings; there are consequently no individual `submissions/<label>.md` files. Everything below is Low or QA, and the report should be read as what it is — a low-severity run over a deployment suite that is, on the evidence, in good shape.

## Summary

| Severity | Count |
|----------|------:|
| Low Risk | 4 |
| QA / hardening | 3 |
| Centralization | 0 |
| **Total** | **7** |

| Label | Title | Entry point |
|-------|-------|-------------|
| [L-01](#l-01) | Story 078's address-key collapse landed while the ViewRouter repoint that justifies it remains broadcast-gated | `promotion-ready:broadcast` |
| [L-02](#l-02) | Four `package.json` doc keys still describe a pre-Phase-4f runbook | `promotion-ready:resume` |
| [L-03](#l-03) | The one keyless deployment is also the one omitted from the operator summary | `promotion-ready:broadcast` |
| [L-04](#l-04) | A spent one-shot key remains executable against the live StableYieldAccumulator | `promotion-ready:broadcast` |
| [Q-01](#q-01) | `promotion-ready:resume` omits the address-book backup while retaining the mutating patcher | `promotion-ready:resume` |
| [Q-02](#q-02) | A spent script still instructs the operator to patch a key story 078 deleted | `promotion-ready:broadcast` |
| [Q-03](#q-03) | Dead unconditional-overwrite branch retained in the address-book patcher (latent) | `promotion-ready:broadcast` |

Ordering is the severity-classifier's ranking and is load-bearing: L-01 leads because it carries this run's only ⚠ INCOMPLETE FIX signal; Q-03 is last because it is a latent hazard with no reachable path at `712cbdb`.

---

## Low Risk Findings

<a name="l-01"></a>
### [L-01] Story 078's address-key collapse landed while the ViewRouter repoint that justifies it remains broadcast-gated, leaving the only sanctioned deposit-view resolution path bound to PhlimboEA V1 <!-- id: pps25l1 -->

**Severity**: Low — ⚠ **INCOMPLETE FIX** signal
**Entry point**: `promotion-ready:broadcast`
**Fingerprint**: `1beb1797733b64e6725d003a16f6ff71a6a118b90410178e63c3c1bf3a1620ba`
**Incomplete fix of**: `6b63ef6516ac1751c6611aa0de8273427425eba6b1d771824d4526adf76e7cea`
**Location**: `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts` — `mainnetAddresses` (DepositView key removal)
**Root cause class**: `SourceDeKeyPrecedesChainRepoint`
**Story**: `story-078` (see also spec-conformance `F-25-04`)

**Description**

Story 078 (Phase 4f) has two halves that land on different clocks, and only one of them is present at `712cbdb`.

*Source side (landed).* The address-key collapse is committed: `DepositView`, `DepositPageView` and `MintPageView` are removed from all three address books, including `server/deployments/mainnet-addresses.ts`. From `712cbdb` onward there is no address-book key naming a deposit view; the only sanctioned resolution path is `ViewRouter.pages(keccak256("deposit"))`.

*Chain side (not landed).* The `setPage` call that repoints that router entry at the new `DepositPageViewV3` lives in `DeployMainnetPromotionReady.s.sol:2077-2088` and fires **only** under `promotion-ready:broadcast`. Story 078 explicitly places broadcast outside its own scope — *"no broadcast… story 072 remains on ice pending its Kendu fee-on-transfer preflight"*. The repoint that justifies the de-key has therefore neither executed nor been scheduled by this story.

Chain-verified unchanged at block `25681503`: `ViewRouter.pages(keccak256("deposit"))` still returns `0x50D4…03b8`, whose immutable `phlimbo()` binds `0x3984eBC8…` = **PhlimboEA V1**. The V1 identification is positive, not inferred: `userInfo` returns a 3-tuple (V2/V3 return more); `getPromoInfo()`, `stakerCount()` and `FIELD_COUNT()` all revert (absent on V1); `getNames()` returns 7 entries; and the identification is corroborated by `mainnet.backup.2026-03-19_*.ts:13`.

What makes the window hazardous rather than merely stale: V1 is **paused** and holds **zero** phUSD while still reporting `totalStaked() = 13,615.68e18`. A view bound to it therefore serves plausible fabricated numbers, not obvious errors (see `manual-review.json` → MR-25-01).

**This is not a botched patch.** Story 078's Phase 4f is a *correct, fork-verified* fix for the parent finding `6b63ef65`. Its two stages simply landed in the wrong order. The ⚠ INCOMPLETE FIX signal applies for the reason it always applies: a half-landed fix reads as done.

**Impact**

Read-side only. No funds are at risk, no chain state was changed by this commit, and the key removal breaks **at compile time, loudly**, under the repo's `tsc --strict` drift guard — a consumer that referenced a deleted key cannot silently read a wrong address, it fails to build.

Magnitude of the display error, from run-24's PoC replayed at `712cbdb` (STILL-LIVE 3/3): a staker whose true balance is 1517.63 phUSD renders as 0; another whose true balance is 729.67 renders as 398.86. The second case is the dangerous one — a believable non-zero number that is simply wrong.

*Evidence note:* that PoC (`test/poc-M-01-stale-view-router-deposit-page.t.sol`) is **audit-authored and untracked at `712cbdb`**. It is cited here as audit evidence only, and must not be read as project test coverage.

The residual is a **window**, not a break: between `712cbdb` and the eventual broadcast, the only sanctioned deposit-view resolution path resolves to a PhlimboEA V1-bound view.

**Recommended Mitigation**

Honor `6b63ef65`'s `fixOrderingConstraint` — **(a) repoint the view against V3, THEN (b) move any consumer onto router resolution.** Concretely: gate the phlimbo-ui follow-up story on *observed* on-chain `pages(keccak256("deposit")) == <DepositPageViewV3>`, not on story-078's completion status. In the interim either:

1. restore the `DepositView` key with an inline `// DO NOT REMOVE until promotion-ready has broadcast — ViewRouter.pages('deposit') still names a PhlimboEA V1 view`; or
2. add an explicit `NOT YET REPOINTED` line to the `mainnet-addresses.ts:19-24` provenance block, which currently reads as though the collapse is complete.

**Note for human review (borderline)**

Graded Low, deliberately not re-inflated to Medium. The parent `6b63ef65` was human-regraded Medium → Low on 2026-08-04 on an **impact** basis (blast radius zero — phlimbo-ui reads `DepositView` directly via `useDepositViewPolling.ts:94`). Story 078 deletes that escape hatch, which is arguably an impact change rather than pure likelihood; the severity-classifier rejected Medium because the deletion breaks at *compile time* under `tsc --strict`, making it a forced visible decision point rather than an impact. **A human may reasonably restore Medium.** The `(a)`-before-`(b)` ordering constraint survives either grade and must be carried through any re-grade unchanged.

---

<a name="l-02"></a>
### [L-02] Four package.json doc keys still describe a pre-Phase-4f script, though `:dry` and `:resume` execute Phase 4f and `:verify` asserts it <!-- id: pps25l2 -->

**Severity**: Low
**Entry point**: `promotion-ready:resume`
**Fingerprint**: `83a40563860e4bedcbd3164153ffd411f50cec95cdd23ec47009777a5bfe9fa1`
**Location**: `lib/phoenix-phase-2-staging/package.json` — `//promotion-ready:dry` / `//promotion-ready:resume` / `//promotion-ready:verify`
**Root cause class**: `RunbookDriftAgainstExecutedPhase`
**Story**: `story-078` (see also spec-conformance `F-25-01`)

**Description**

Four `//`-prefixed documentation keys in `package.json` still describe a pre-Phase-4f promotion-ready runbook.

The drift is **four** doc strings, not three. `//promotion-ready` (line 282) is itself stale — its narrative ends at story 076. `//promotion-ready:dry`, `//promotion-ready:resume` and `//promotion-ready:verify` are likewise pre-078. Only `//promotion-ready:broadcast` (line 287) carries the STORY 078 text.

Stated precisely, so the finding is not overstated: **`:verify` does not execute Phase 4f.** It runs a separate script (`VerifyPromotionReady.s.sol`) that resolves a 17th runtime address inside read-only assertions. The drift is confined to **doc strings** — **no executable key is wrong**.

Story 078's own checklist ticks *"Update the //-prefixed doc keys… describing the broadcast legs"* (plural), implemented as exactly one key. A single checklist tick covered a partial edit.

**Impact**

These doc keys are the operator runbook for a ~60-signature Ledger session. An operator resuming a crashed cutover budgets signatures against `//promotion-ready:resume` and then meets two unannounced hardware-wallet prompts late in the session — exactly the point at which an unexpected prompt reads as "something is wrong" and invites an abort.

The failure mode is fail-closed, which is why this stays Low: rejecting the unexpected prompts leaves the router unrepointed, which is the pre-existing state, and Phase 4f is `_isConfigured`-gated and idempotent, so a re-run of `:resume` completes normally. No state is corrupted by the surprise; the cost is operator confidence and session time.

**Recommended Mitigation**

Amend `//promotion-ready:resume` to name Phase 4f, its two `_isConfigured`-gated steps and the two extra Ledger signatures; amend `//promotion-ready:dry` to name the Phase 0 precondition block and the Phase 8 deposit probe; amend `//promotion-ready:verify` for the 17th resolved address and 16th swept contract; refresh the top-level `//promotion-ready` narrative past story 076. Reword the story-078 checklist line to enumerate the keys so a single tick cannot cover a partial edit.

*Fingerprint note:* the `//` prefix on this entry's function value is load-bearing — it separates this doc-key family from the executable-key family in [L-04](#l-04). It must never be normalized away.

---

<a name="l-03"></a>
### [L-03] The one deployment deliberately given no address-book key is also the one omitted from the operator summary <!-- id: pps25l3 -->

**Severity**: Low
**Entry point**: `promotion-ready:broadcast`
**Fingerprint**: `449812a684363c7bc6612d7f07ca8abf75791925df4a4719925bb045b5e56a2d`
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetPromotionReady.s.sol:3363` — `_printSummary`
**Root cause class**: `KeylessDeploymentOmittedFromOperatorRecord`

**Description**

`_printSummary` prints all 16 other new runtime addresses produced by the cutover — including transients that will never be referenced again, such as `MigratorV2V3` and the three staker migrators — but omits `newDepositPageViewV3`.

That omission matters specifically because `DepositPageViewV3` is the one deployment story 078 deliberately gave **no** address-book key: it is resolvable only through the on-chain router. It is therefore the single deployment for which the operator transcript is the last human-readable record, and it is the one the transcript drops.

The progress JSON is not a substitute. Under `--broadcast --skip-simulation` the progress file is written during forge's **local** pass, so the CREATE address it records is a *prediction*; if an earlier CREATE fails, the nonce shifts and the prediction is wrong. The only durable record of the deployed address is on-chain `ViewRouter.pages()`.

**Mitigating fact — this is a transcript gap, not a verification gap.** Phase 7 (`:2546-2559`) *hard-requires* that the router page equals `newDepositPageViewV3` and that the view's `phlimbo` / `phUSD` immutables are correct, and `:2860-2872` prints a loud mismatch diagnostic. The script verifies what it deployed; it simply does not tell the operator the address.

**Impact**

Operational / record-keeping only, and fails closed: a wrong or shifted address is caught by the Phase 7 requirement and aborts. The residual is that a post-run operator reading only the summary has no recorded address for the one contract with no address-book key, and must go back to chain to recover it.

**Recommended Mitigation**

Add one line to `_printSummary`:

```solidity
console.log("DepositPageViewV3 (story 078): ", newDepositPageViewV3);
```

with a trailing note that it is intentionally keyless and resolvable via `ViewRouter.pages(keccak256("deposit"))`. Costs nothing and reintroduces no second resolution path.

---

<a name="l-04"></a>
### [L-04] A spent one-shot key remains executable and would repoint the live StableYieldAccumulator at a wound-down PhlimboV2 <!-- id: pps25l4 -->

**Severity**: Low (upgraded from QA — see note)
**Entry point**: `promotion-ready:broadcast`
**Fingerprint**: `e1d52b7b2e77e0ee03071b4f3512791eaddbd54e5b1f6922e446b06abb656e0d`
**Location**: `lib/phoenix-phase-2-staging/package.json` — `rewire-sya-to-phlimbo-v2:broadcast` (and `:dry`)
**Root cause class**: `SpentOneShotRetainedAsRunnable`

**Description**

The `rewire-sya-to-phlimbo-v2:dry` and `rewire-sya-to-phlimbo-v2:broadcast` `package.json` keys are a **spent** one-shot migration leg that remains npm-runnable against mainnet.

If executed today it would call `setPhlimbo(PHLIMBO_V2)` plus `approvePhlimbo` on the **live** StableYieldAccumulator, repointing the yield feed at a wound-down PhlimboV2 (APY 0, mint revoked), and would deploy a V2-bound `DepositView` over a V3 protocol. That is the highest on-chain harm ceiling of anything in this run's finding set — every other finding here tops out at documentation or display.

It stays below Medium because the consequence is **disclosed** in the adjacent `//rewire-sya-to-phlimbo-v2` doc key, which states the keys are *"retained as history, not as a runnable leg"*. Under Law 3 that makes the harm obvious to a competent, non-malicious owner rather than a footgun, and C4 lists reckless admin mistakes as known-invalid.

The reportable residual is narrower and real: the key is still **executable**, and story 078 already half-retired it by removing its trailing `patch-mainnet-addresses-deposit-view.js` call. It is now both spent *and* broken — a leg nobody intends to run, that no longer does what its own name says, still sitting one `npm run` away from the live SYA.

Related but **not merged**: [Q-02](#q-02) is the same theme (a spent one-shot carrying stale guidance) in a different file with a different fix site. The two are cross-referenced only; fixing one does not resolve the other.

**Impact**

Bounded by an owner deliberately invoking a key documented as history. If invoked: the live SYA's yield feed points at a wound-down PhlimboV2 (APY 0), and a V2-bound `DepositView` is deployed over a V3 protocol. Recovery is a re-run of the correct rewire, so this is disruption and operator time, not permanent loss.

**Recommended Mitigation**

Delete the executable `rewire-sya-to-phlimbo-v2:dry` and `:broadcast` keys, retaining only the `//` doc key as history; or prefix the command with `echo 'SPENT ONE-SHOT — refusing' && exit 1 &&`. Apply the same treatment to any other spent one-shot that remains npm-runnable.

**Note for human review (borderline)**

Upgraded QA → Low by the severity-classifier on harm-ceiling grounds (the only finding in the set whose ceiling is on-chain). **A human may reasonably prefer the auditor's original QA grade**; the move is one notch inside this same QA bundle either way.

*Fingerprint note:* this entry's function is the **executable** key name, without a `//` prefix. The `//`-prefixed doc keys are a different fingerprint family — see [L-02](#l-02).

---

## QA / Hardening Notes

<a name="q-01"></a>
### [Q-01] `promotion-ready:resume` omits the address-book backup while retaining the mutating patcher <!-- id: pps25q1 -->

**Severity**: QA (downgraded from Low — premise corrected)
**Entry point**: `promotion-ready:resume`
**Fingerprint**: `a1ac89dc84b6db021799d3b3b53424ee185a8e85e4a85ec8c64a847b5c082029`
**Location**: `lib/phoenix-phase-2-staging/package.json` — `promotion-ready:resume`
**Root cause class**: `MutatingPatchWithoutBackupPrecondition`

**Description**

`promotion-ready:resume` retains the mutating `patch-mainnet-addresses-promotion-ready.js` step but omits the leading `backup-mainnet-addresses.js` leg that `:broadcast` runs.

**Premise correction (why this was downgraded).** This finding was originally graded Low on the premise that there was *no recoverable pre-image*. That premise was factually wrong and has been struck. **`server/deployments/mainnet-addresses.ts` is git-tracked and is not gitignored** — verified with `git ls-files --error-unmatch` (exit 0) and `git check-ignore` (no match). `git diff` shows the delta and `git checkout --` restores the file in full; that is the true recovery path. `backup-mainnet-addresses.js` writes a convenience timestamped sibling copy, and is not the recovery mechanism.

The corrected residual is narrower: an **asymmetry between `:broadcast` and `:resume`** — and even that omission is deliberate and documented, the doc key stating it *"OMITS the leading address backup (already taken by the crashed :broadcast run)"*. Realising the hazard requires an operator to invoke `:resume` as the **first** call of a session, contradicting the key's own definition, *and* to be unable to use git. Hence QA.

**Impact**

Negligible in practice. Worst case is an operator who starts a session with `:resume` (contrary to the key's definition) and does not reach for git, and so has no timestamped sibling copy of the address book to hand. The authoritative pre-image remains in version control throughout.

**Recommended Mitigation**

Either restore the idempotent, timestamped backup leg to `:resume` (a second snapshot costs nothing), or add a precondition to `patch-mainnet-addresses-promotion-ready.js` that a `mainnet.backup.*.ts` exists newer than the progress file and exit non-zero otherwise. Note that the git-tracked status of `mainnet-addresses.ts` already provides the true recovery path.

---

<a name="q-02"></a>
### [Q-02] A spent script still instructs the operator to patch a mainnet-addresses key that story 078 deleted <!-- id: pps25q2 -->

**Severity**: QA
**Entry point**: `promotion-ready:broadcast`
**Fingerprint**: `17b3642f61351922a637c23183aaf8ad9f3587600fdcc6bdf8ac697007af0087`
**Location**: `lib/phoenix-phase-2-staging/script/DeployMainnetMintPageView.s.sol:94` — `run`
**Root cause class**: `StaleOperatorInstructionForDeletedKey`
**Story**: `story-078` (see also spec-conformance `F-25-07`)

**Description**

`DeployMainnetMintPageView.s.sol:94` still prints the operator instruction *"(patch mainnet-addresses.ts MintPageView -> this)"*. Story 078 deleted the `MintPageView` address-book key and swept the dangling references in `package.json` and in both JS patchers — but not this Solidity site. The script is itself spent; the instruction it prints now names a key that no longer exists.

**Filed standalone. This is deliberately NOT merged with [L-04](#l-04)** — different file, different fix site, different root cause. The two share only a theme ("a spent one-shot carries stale guidance"). Merging them would let a fix to one silently mark the other resolved.

**Impact**

Documentation only, and fails visibly: an operator who follows the instruction finds no `MintPageView` key to patch and stops immediately. No state is reachable from following it.

**Recommended Mitigation**

Delete or amend the line 94 instruction to state that `MintPageView` is no longer an address-book key and that view addresses now resolve through `ViewRouter`. Sweep the remaining Solidity scripts for the same class of stale operator instruction.

---

<a name="q-03"></a>
### [Q-03] Dead unconditional-overwrite branch retained in the mainnet address-book patcher (latent) <!-- id: pps25q3 -->

**Severity**: QA — **latent**, conditioned on a future `update: true` row being added; **not a present defect**
**Entry point**: `promotion-ready:broadcast`
**Fingerprint**: `55cbd7d0ee910370571aa069dd67b7dbc4bccab6760ef600f8bbb3acba79eb0e`
**Location**: `lib/phoenix-phase-2-staging/scripts/patch-mainnet-addresses-ratchet.js` — `patchFlatField`
**Root cause class**: `DeadBranchAfterRowRemoval`

**Description**

`patchFlatField` carries an `update === true` branch performing an unconditional overwrite of an existing address-book field. That branch is dead: story 078 removed the sole row that set `update: true` (`MintPageView`). The source self-documents its own deadness — line 134 notes *"no field uses this since story 078"*, and line 51 records the removed row.

There is **no reachable path to it at `712cbdb`**. It is kept in the record only because it is an untested unconditional-overwrite path inside a script that rewrites the mainnet address book: if a future `update: true` row is added, that path goes live having never been exercised. This is the lowest-value item in the run.

**Impact**

None at `712cbdb` (unreachable). Conditional future impact: the first `update: true` row added would exercise an untested overwrite path against the mainnet address book.

**Recommended Mitigation**

Delete the unreachable `update === true` branch and its parameter; if retained for future use, add a unit test exercising the overwrite path so a future `update: true` row does not go live untested.

---

## Closing Notes

**Visibly-parked item, outside this run's closure.** `reports/phoenix-phase-2-staging/25/manual-review.json` records **MR-25-01**: PhlimboEA V1 (`0x3984eBC8…19F4`) reports `totalStaked() == 13,615.682e18` against a phUSD balance of **zero**. The assessment is that this is accounting residue the V1→V2 migration never cleared — not stranded user value — but its root cause lives in `lib/phlimbo-ea` V1's migration path, outside the `promotion-ready` entry-point closure this run audited, so it is parked rather than filed. It is not dropped, and it is the reason [L-01](#l-01)'s window is hazardous rather than obviously-broken: the routed view serves believable non-zero numbers backed by an empty contract. Recommended next step is a separate `/analyze` of phlimbo-ea V1's migration path; do not expand this audit to reach it.

**Law-2 faithfulness findings** (story-078 conformance, labels `F-25-xx`) are reported separately in `spec-conformance.md` and are not restated here. `L-01`, `L-02` and `Q-02` each carry a corresponding `F-` label (`F-25-04`, `F-25-01`, `F-25-07`) linking the two reports.

**Automated report.** `submissions/4naly3er-report.md` carries the 4naly3er gas/NC baseline for this run. Its scope is limited to `src/views/*.sol` — the first-party view contracts in the closure. `script/*.s.sol` was attempted and excluded: 4naly3er's own solc invocation does not honour the repo's `lib/<a>/lib/<b>/=` diamond-canonicalization remappings, so `DeployMainnetPromotionReady.s.sol` fails to compile there with duplicate-identity `TypeError`s (`ITokenMinterV2`, `IUniboostMintDebtHook` resolved from two physical files). Those scripts compile cleanly under `forge`; this is a tool limitation, recorded rather than left silent.

**Carryover.** QA findings from earlier `phoenix-phase-2-staging` audits are not merged into this bundle. Where still open, they are copied per originating audit under `submissions/carryover/`.
