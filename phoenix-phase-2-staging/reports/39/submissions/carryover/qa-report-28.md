# Carryover QA report: audit 28 (entry point `dev`), re-carried at audit 39

> ## Re-carried at audit 39. Read this first.
>
> **This block was prepended by audit 39** (run `phoenix-phase-2-staging-39`, commit `dfbf2f9`,
> baseline `e6eded0`, branch `master`, entry point `dev`). **Everything after the run-39 index,
> including every earlier carryover header, is preserved VERBATIM and has not been edited.** Where
> an earlier header says "as of audit 30", read it as "as of audit 30, and unchanged at audit 39 unless stated below". Run 39's statements below take precedence.
>
> - **Retained (still open or `fix-pending` as of audit 39): L-01, L-02, L-03, L-04, L-05, L-06, L-07, F-01, F-02, F-03, Q-01, Q-02. That is 12 entries.**
> - **Removed as no longer live:** none from this bundle. Outside it: `M-02` (`8aa45828a222…` / `pps28m2`) is **wont-fix** and `M-03` (`3b7430a7a4b6…` / `pps28m3`) is **wont-fix**, both from owner triage on 2026-09-08, so neither is carried. `M-01` (`11311795cd60…` / `pps28m1`) is carried in full as [`M-01-C2.md`](../M-01-C2.md).
> - **Statuses changed by audit 39 in this file: NONE.** Proposals are recorded in the ledger
>   (`run39` field and `note`). Only a human applies them, with `/ledger`.
> - **Labels are the originals.** Any gap in the sequence is one of the removals named above, not an omission.
>   Entry point `dev` reuses the same labels across runs under different fingerprints, so **always
>   select by fingerprint or issueId**.
> - Run-39 evidence update on `L-06` (`bd268808fbd5…`): `clean:local` now deletes **4** tracked files, because untagged `6c9416d` re-added `server/deployments/local.json` to the tracked set. `dev` leaves a dirty tree on every run. `L-07` (`98e727214903…`) is **proposed `fixed`**, because its premise does not hold at HEAD (local.json is tracked again). **No status was changed.**
> - The audit-28 Law-2 entries (`F-01`/`F-02`/`F-03`) are appended in **Part B**, verbatim from the run-30 `spec-conformance-28.md` carryover, so this one file holds every live audit-28 QA-channel entry.
> - **Line numbers below were accurate at the originating commit `f929b5b`. Re-verify them against current HEAD `dfbf2f9` before acting.**
> - Source of the verbatim body: `../../30/submissions/carryover/qa-report-28.md` + `../../30/submissions/carryover/spec-conformance-28.md`.

## Run-39 index of retained entries (fingerprint + recommendation)

#### L-01 · `pps28l1` · low · status `open`

- **Title:** Top-level OpenZeppelin canonicalization to v5.6.1 changes ReentrancyGuard's storage layout relative to four contracts' own pins, creating a tested-bytecode / deployed-bytecode divergence
- **Fingerprint:** `c35f8cdc52dcbdf71c143d8c059d896bf99973b83df84d3f351d93d981448a36`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/low/L-01-oz-canonicalization-reentrancyguard-layout.json`):

  > Pin the top-level OpenZeppelin to a version at or below the lowest pin among the canonicalized submodules (5.1.0 here) so the built layout matches the deployed one, OR bump the submodules' own pins so every consumer genuinely targets 5.6.1 and the mainnet contracts are redeployed from that build. Whichever is chosen, add a `forge inspect <contract> storage-layout` snapshot test for `StableYieldAccumulator` and the three strategies so a future dependency bump that shifts a slot fails loudly. And file the story: this is a cross-cutting dependency change with no acceptance criteria anywhere.

#### L-02 · `pps28l2` · low · status `open`

- **Title:** The deployment progress file the API serves is written during the SIMULATION pass, ~15 minutes before the transactions it certifies are mined, and is never refreshed afterwards
- **Fingerprint:** `88af91804ec23988388adb33bf17ec90f86825dc6ec017a5b31bc142f415d4bb`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/low/L-02-progress-artifact-written-in-simulation.json`):

  > Move the progress write out of the forge script and into a post-broadcast step that reads `broadcast/DeployMocks.s.sol/31337/run-latest.json` — the file forge writes only after `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL` — and derives status and per-contract deployment from the actual receipts. A minimal version: add a `node server/build-progress.js 31337` step to `deploy:local` after the forge invocation, and have `_writeProgressFile` stamp `"deploymentStatus": "simulated"` so an unconverted artifact is self-identifying rather than falsely reassuring.

#### L-03 · `pps28l3` · low · status `open`

- **Title:** `verify-stable-staker.sh` invokes two scripts that were moved to `script/archives/`, and the foundry.toml comment justifying the exclusion is falsified by that very reference
- **Fingerprint:** `669de8af7eb962ae5a276e5c1080b0de13af3bd44780e86b207c19b71955fc24`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/low/L-03-verify-stable-staker-dangling-archive-refs.json`):

  > Repoint the two invocations at `script/archives/interactions/...` and narrow the `skip` glob so those two files still compile (e.g. `skip = ["script/archives/**"]` -> an explicit list, or `git mv` the two interaction scripts back out of `archives/` as story 080 did for its own two files). Correct the foundry.toml comment: it is not true that nothing outside the directory references the archives, and the next sweep will be reasoned about from that sentence.

#### L-04 · `pps28l4` · low · status `open`

- **Title:** `server/index.js` reports a healthy, fully-deployed protocol from a stale tracked progress file with no chain running anywhere
- **Fingerprint:** `8cd3c3bad599374f5dbace4e64fd1decde3e35315bbd392219c2eff10f0643a9`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/low/L-04-health-endpoint-decoupled-from-liveness.json`):

  > Make `/health` actually probe liveness: attempt an `eth_chainId` (or `eth_blockNumber`) against `http://localhost:8545`, plus a code-size check on one deployed address from `local.json`, and return a non-200 (or `status: "degraded"` with an explicit `chainReachable:false`/`addressesLoaded:false`) when either fails. Derive the startup banner from live chain reads rather than from the committed progress file, or label it explicitly as 'last recorded run' so it is not read as current state.

#### L-05 · `pps28l5` · low · status `open`

- **Title:** `dev` has no terminating success signal: `serve` blocks forever, so the entry point can never exit 0 and cannot be gated in CI
- **Fingerprint:** `c8c6fe8557a83a81a3448e013acdbb007aef6378d149c7f6e5603cc7e44bcdd0`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/low/L-05-dev-no-terminating-success-signal.json`):

  > Split the chain: add a `dev:ci` (or `bootstrap:local`) key that runs everything up to and including `generate:ts-anvil`, then exits 0 — that is the part with assertions and the part CI needs — and leave `dev` as `npm run dev:ci && npm run serve` for interactive use. Add a `trap 'kill $ANVIL_PID' EXIT` (or `concurrently --kill-others`) so terminating the foreground also tears down anvil. Then wire `dev:ci` into CI so DeployMocks' assertions actually run on every commit.

#### L-06 · `pps28l6` · low · status `open`

- **Title:** `clean:local` deletes git-TRACKED files and re-runs under a live anvil, wiping scratch state from under the node it is about to broadcast to
- **Fingerprint:** `bd268808fbd56c5f026b272d30da150dcbd2ec4aff06063c667d5275df97f850`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). Evidence update: clean:local now deletes 4 tracked files (local.json re-added to tracked set); dev leaves a dirty tree each run (UE-3).
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/low/L-06-clean-local-destructive-tracked-and-live-node.json`):

  > Untrack the generated artefacts (`git rm --cached server/deployments/progress.31337.json server/deployments/local.json` and add both to `.gitignore`) so `clean:local` only ever removes build output — or, if they are wanted as committed fixtures, drop them from the `rm` list and let the deploy overwrite them. Narrow the anvil scratch wipe to a project-scoped path rather than `~/.foundry/anvil/tmp/*`. Remove the leading `npm run clean:local` from `deploy:local` so the wipe happens exactly once, before anvil starts, rather than concurrently with it.

#### L-07 · `pps28l7` · low · status `open`

- **Title:** `server/deployments/local.json` was removed from git tracking, so `generate:ts-anvil` and `serve` now fail when run standalone
- **Fingerprint:** `98e72721490398830324ab4cb3e7f31cb746ca7bce1f3e46c92d58fc761509c1`
- **Run-39 reconciliation:** **PROPOSED `fixed` (NOT applied; status unchanged)**. Premise void at HEAD: server/deployments/local.json re-tracked by untagged 6c9416d. Human review. Side effect: re-tracking widens open L-06 bd268808fbd5 (clean:local now deletes 4 tracked files) - evidence update there.
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/low/L-07-local-json-detracked-no-fallback.json`):

  > Either re-track a representative `local.json` (it is generated output, so prefer not to) or, better, make both consumers fail with an actionable message: in `generate-ts-addresses.js:101-104` and `server/index.js:36-40`, name the producing command explicitly — e.g. `local.json not found. Run: npm run extract:addresses (after npm run deploy:local)`. Document the dependency order in the `//local-deploy` comment alongside the existing story-003 reference.

#### F-01 · `pps28f1` · low · status `open`

- **Title:** `dev` hardcodes `LOCAL_PROMO_KENDU=true`, making the dormant (day-one mainnet) leg unreachable through the only entry point developers run — partially reverting the story-079 fix for ledger L-03
- **Fingerprint:** `dcf756f7a8977d7d8f3b8b3fb96cbe478f392b057ac045cb0e5928164123d92a`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/faithfulness/F-01-dev-pins-local-promo-kendu-true.json`):

  > Delete `LOCAL_PROMO_KENDU=true` from the `dev` key and let `vm.envOr`'s default supply the armed leg (identical behaviour, toggle restored). If an explicit armed default is wanted at the npm layer, add a second key (`dev:dormant` with `LOCAL_PROMO_KENDU=false`) rather than pinning the only one. Add a rehearsal obligation that BOTH legs are booted before a mainnet cutover, since only the dormant leg matches day one.

#### F-02 · `pps28f2` · low · status `open`

- **Title:** Gating `_seedNudgeStream` on `LOCAL_PROMO_KENDU` silently disables a load-bearing fee-on-transfer probe on the dormant leg, contrary to story 079's explicit instruction
- **Fingerprint:** `beb259209f88e76e748c09fd10a3bdeb63339edcf9dab180b4bcacdc0caae798`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/faithfulness/F-02-seed-nudge-stream-gated-behind-optional-leg.json`):

  > Either restore the seeding/probe as unconditional per story 079 (registering and seeding the phUSD/Kendu streams costs nothing on the dormant leg beyond two extra streams the UI is supposed to render gracefully anyway), or — if the dormant leg must genuinely leave them unregistered to mirror mainnet — hoist the fee-on-transfer probe out of `_seedNudgeStream` into an unconditional check that runs on both legs, and amend story 079 (or file a superseding story) rather than silently contradicting it.

#### F-03 · `pps28f3` · low · status `open`

- **Title:** Shipped work with no story at all: the OpenZeppelin pin, the 108-file archives sweep and the 246-key package.json purge have no acceptance criteria, and all nine delta commits are untagged
- **Fingerprint:** `da94d1ba03fd07a0a6bedfab78b0aed8d00cb8c6aee0054489a5adb8b978d130`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/faithfulness/F-03-shipped-work-without-story.json`):

  > Write (or retro-write) stories with acceptance criteria for the three untracked changes before any further work builds on them — at minimum the OZ pin needs a stated compatibility target and the package.json purge needs an explicit list of what was intentionally retired versus swept. Merge `sprint/stable-staker-v2` or revert the story-080 code from master so code and story travel together. Restore `[story-NNN]` tagging on commits; the nine untagged commits are what made this delta ungradeable in the first place.

#### Q-01 · `pps28q1` · qa · status `open`

- **Title:** `_seedNudgeStream`'s NatSpec justifies its load-bearing assertion with a claim about `collectNudge` that stopped being true when ledger M-01 was fixed
- **Fingerprint:** `d7242d7c43ac0b2d8bb3903fb1bee66865d0bacfb7ae7c6d0037746d198324b6`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/qa/Q-01-stale-natspec-rationale-after-upstream-fix.json`):

  > Rewrite the comment to describe the current contract: `collectNudge` measures the received delta and caps it at `amount`, so the script-level `require(received == amount)` is now a stricter local check that the MOCK token is not taxed (which would silently change the seeded rate), not a defence against streamer over-credit. Cross-reference the M-01 fix so the two stay in sync. Propose M-01 (a753907e2a4c) FIXED — propose only, no ledger status changed here.

#### Q-02 · `pps28q2` · qa · status `open`

- **Title:** `dev` requires `ANVIL_PRIVATE_KEY` but neither sets it nor documents it anywhere the operator will look
- **Fingerprint:** `d3aa1e35c995a93509a1c3ce85cbd6654319dd5623b20a67b0e7852f81bf602f`
- **Run-39 reconciliation:** still-open (re-observed; no evidence of resolution). not re-filed; no evidence of resolution
- **Recommendation** (verbatim from the finding record `reports/phoenix-phase-2-staging/28/findings/qa/Q-02-undocumented-anvil-private-key.json`):

  > Use `vm.envOr("ANVIL_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80))` — it is the standard public anvil account-0 key and the script is chain-31337-only, so defaulting it is safe and removes the failure entirely. If an explicit opt-in is preferred instead, set it in the `dev` key and add a `.env.example`, and add a `require` with a message naming the variable so the failure is self-explaining.

---

<!-- Part A: verbatim copy of reports/30/submissions/carryover/qa-report-28.md -->

# Part A: QA bundle (verbatim)

---

# Carryover QA report — audit 28 (entry point `dev`), re-carried at audit 30

> ## Re-carried at audit 30 — read this first
>
> **This block was prepended by audit 30 (commit `e6eded0`, baseline `9563c68`, branch `master`,
> entry point `dev`). Everything below it — including audit 29's own carryover header — is
> preserved VERBATIM and has not been edited.**
>
> - **Retained (still open as of audit 30): `L-01, L-02, L-03, L-04, L-05, L-06, L-07, Q-01, Q-02`
>   — all nine. No gaps.**
> - **Removed as no longer live: none from this bundle.** For completeness, two audit-28 entries
>   *outside* it were disposed of by owner triage on 2026-09-08 and are not carried: `M-02`
>   (`8aa45828a222…` / `pps28m2`, `wont-fix`) and `M-03` (`3b7430a7a4b6…` / `pps28m3`, `wont-fix`).
>   Audit-28 `M-01` (`11311795cd60…` / `pps28m1`) is a Medium, carried separately and in full as
>   [`M-01-C2.md`](../M-01-C2.md). Audit-28 `F-01`/`F-02`/`F-03` are Law-2 faithfulness findings,
>   carried in [`spec-conformance-28.md`](spec-conformance-28.md).
> - **Statuses changed by audit 30 in this file: NONE.**
> - **⚠ Audit-30 cross-reference:** audit-28 `Q-01` (`d7242d7c43ac…`,
>   `StaleInSourceRationaleAfterUpstreamFix`) is the same stale-rationale family as audit 30's new
>   `Q-02` (`66671224826b…`, `StaleCrossReferenceToDeletedCode`). Different function, different
>   stale claim — deliberately **NOT collapsed**.
> - **Line numbers below were accurate at the originating commit `f929b5b`. Re-verify against
>   current HEAD `e6eded0` before acting.**

---

# Carryover QA report — audit 28 (entry point `dev`), carried at audit 29

> **Carryover QA report — audit 28** (copied from `reports/phoenix-phase-2-staging/28/submissions/qa-report.md`).
> Retained below (still open / untriaged as of **audit 29**): **L-01, L-02, L-03, L-04, L-05, L-06, L-07,
> Q-01, Q-02** — **all nine**. Nothing was cut from the Low/QA body, so there are **no gaps** in the label
> sequence.
> Removed as no longer live: **none from this bundle.** For completeness, two audit-28 entries *outside* it
> were disposed of by owner triage on 2026-09-08 and are **not** carried: **M-02** (`8aa45828a222…` /
> `pps28m2`, owner-downgraded to Low then **`wont-fix`**) and **M-03** (`3b7430a7a4b6…` / `pps28m3`,
> **`wont-fix`**). Audit-28 **M-01** (`11311795cd60…` / `pps28m1`) is a Medium and is carried separately and
> in full as [`M-01-C2.md`](../M-01-C2.md). Audit-28 **F-01/F-02/F-03** are Law-2 faithfulness findings and
> are carried in [`../spec-conformance.md`](../spec-conformance.md), not here.
> Labels are the originals and are **never renumbered**. They are a **separate sequence** from audit 05's,
> 21's, 26's, 27's and audit 29's own. Audit 29 mints `L-05`, `L-06`, `L-07`, `Q-03`, `F-03`, `F-04` on this
> same entry point — the `L-05` below is **audit 28's** (`c8c6fe8557a8…` / `pps28l5`, no terminating success
> signal), **not** audit 29's (`2f86e3864ead…` / `pps29l5`, the unowned-node adoption in
> `verify-stable-staker.sh`). **Key every reference on the fingerprint.**
> Line numbers were accurate at the originating commit `f929b5b`; **re-verify against current HEAD
> `9563c68` before acting.**

## ⚠ Status of each retained entry as of audit 29 — READ THIS BEFORE THE BODY

**Audit 29 changed no status on any entry in this file.** One entry was genuinely re-observed and
sharpened; the rest were not re-walked.

| Label | `issueId` | Fingerprint | Status | Audit-29 disposition |
|---|---|---|---|---|
| **L-01** | `pps28l1` | `c35f8cdc52dc…` | `open` | Not re-observed (OpenZeppelin canonicalization / `ReentrancyGuard` storage layout is outside this run's slice). Carried forward unchanged. |
| **L-02** | `pps28l2` | `88af91804ec2…` | `open` | Carried forward unchanged. **Still pinned apart from audit-21 `L-01` (`1e8cc0dc58ba…`)** — this is the *timing* finding whose class string was mislabelled onto that *value* entry (`FR-28-03`, still uncorrected, human `/ledger` only). |
| **L-03** | `pps28l3` | `669de8af7eb9…` | `open` | **Adjacent to two new audit-29 findings on the same file, and NOT collapsed with either.** `verify-stable-staker.sh` was retargeted by story-080 in this delta. This entry is *dangling references to `script/archives/`*; audit 29's `F-03` (`c476a12b04fa…` / `pps29f3`) is a *stale documented assertion* in the same script's header, and audit 29's `L-05` (`2f86e3864ead…` / `pps29l5`) is *unowned-node adoption* in its readiness loop. Three distinct defects in one file. Carried forward unchanged. |
| **L-04** | `pps28l4` | `8cd3c3bad599…` | `open` | Not re-observed. Carried forward unchanged. |
| **L-05** | `pps28l5` | `c8c6fe8557a8…` | `open` | Not re-observed — no audit-29 finding concerns `dev`'s exit semantics. Carried forward unchanged. **Not** audit 29's `L-05`. |
| **L-06** | `pps28l6` | `bd268808fbd5…` | `open` | **NOTE-ONLY UPDATE — no status change, no fingerprint change, no `rootCauseClass` edit.** Audit 29 records a **failed-run variant**: `clean:local` deletes git-**tracked** files (`broadcast/DeployMocks.s.sol/31337/run-latest.json`, `server/deployments/progress.31337.json`) and on a **failed** run they are never re-created, leaving a dirty tree and no stack. Same contract, same function, same entry point, same defect — only the **consequence** is worse, so it was deliberately **not** minted as a second fingerprint. **⚠ Scope shift:** the `…AndLiveNode` half of the class string `DestructiveCleanTouchesTrackedStateAndLiveNode` **no longer holds for `dev`**, because `dev-local.sh` (new in story-081) now runs `clean:local` **before** anvil starts. It **still holds** for `deploy:local` as invoked by `verify-stable-staker.sh`. Recorded as a note, **not** a re-classification — editing the class string would re-mint the fingerprint. |
| **L-07** | `pps28l7` | `98e727214903…` | `open` | Carried forward unchanged. **Adjacent to audit 29's `F-04` (`ee5aae66ac65…` / `pps29f4`) — same `server/deployments/` family, distinct defect, NOT collapsed.** This entry is a *de-tracked seed artifact* breaking standalone runs; `pps29f4` is an *unenforced type-level drift guard* between `mainnet-addresses.ts` and the regenerated `ContractAddresses` interface. |
| **Q-01** | `pps28q1` | `d7242d7c43ac…` | `open` | Not re-observed. Carried forward unchanged. **Not** audit 05's, 21's, 26's or 27's `Q-01` — six findings on this entry point now share the string. |
| **Q-02** | `pps28q2` | `d3aa1e35c995…` | `open` | **RE-OBSERVED AND SHARPENED — this is the one entry audit 29 bumped (`lastSeenRun` → `phoenix-phase-2-staging-29`).** Verified independently this run that `ANVIL_PRIVATE_KEY` appears in the tree **only** at `CLAUDE.md:476` (prose) and at seven `vm.envUint` call sites — no `.env`, no `.env.example` (the file the docs describe **does not exist**), no shell export — so **`npm run dev` cannot complete on a clean shell**. The **consequence** escalates from *undocumented* to *entry-point-unrunnable*. **PROPOSED (human `/ledger` only): severity `qa` → `low`. Not applied.** **⚠ FINGERPRINT INTEGRITY:** audit 29's finding proposed the class string `UndeclaredAmbientEnvDependency`; that was **rejected** and this entry's `UndocumentedRequiredEnvVar` was used **verbatim**, reproducing `d3aa1e35c995…` byte-for-byte (verified). Using the new string would have minted a second fingerprint for one defect and orphaned this entry's history. **⚠ Accuracy caveat:** the value **is** documented at `CLAUDE.md:476`, which partially contradicts the title's phrase *"nor documents it anywhere the operator will look"* — the accurate claim is that it is documented only in prose and **provided by no mechanism**. |

### Why nothing was flipped, and why non-re-observation means nothing

Audit 29 was `/audit-script` scoped to the `dev` entry point's closure over the `f929b5b → 9563c68` delta.
Eight of the nine entries above sit outside that slice, and **absence from a delta-scoped scan carries no
closure authority whatsoever**. Their `lastSeenRun` was deliberately left at `phoenix-phase-2-staging-28`
rather than bumped, precisely so the record cannot be misread as a fresh sighting. Nothing here was
suppressed, downgraded, disposed of, or marked `abandoned` — the code is merged on `master`.

### Known-issue suppression remains unavailable for this project

The registry's declared `knownIssuesFile` (`src/known-issues.md`) **does not exist** at HEAD `9563c68`, and
the 11 cached entries are an unfalsifiable registry-only 2026-01-09 cache. **No finding in this bundle, or
anywhere in audit 29, was suppressed on known-issue grounds.**

### Link resolution

Sibling run directories are **three** levels up from `submissions/carryover/` — `../../../<NN>/…`. The
copied body below was written from `28/submissions/`, so its relative links resolve against
`reports/phoenix-phase-2-staging/28/submissions/`, **not** against this directory.

*The text below is a verbatim copy of the audit-28 QA report — nothing was removed from it, because nothing
in it has been disposed of. Only this header carries new information. Do not re-severity or re-summarise
it; the copied body's own summary counts, commit and links describe **audit 28** as it stood at `f929b5b`.*

---

# QA Report — phoenix-phase-2-staging, script audit of the `dev` entry point (run 28)

**Project**: `phoenix-phase-2-staging`
**Entry point**: `dev` (`package.json:16`)
**Audited commit**: `f929b5b36629f73d17e350e383c77e2f24c40d71`
**Entry-point baseline for this delta**: `1d8a3a7515adca7819c530a01a87c132863a5ae2` → `f929b5b3…`
**Branch**: `master`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 7 |
| QA | 2 |
| Centralization | 0 |
| **Total** | **9** |

There are **no Centralization (C-XX) findings** this run. The three faithfulness findings
(`F-01`–`F-03`) are **not** part of this bundle; they are reported in `spec-conformance.md`.

Prior-run QA bundles are **not** merged here. They are carried over unchanged, pruned to what
remains open, under `submissions/carryover/` (`qa-report-05.md`, `-21.md`, `-26.md`, `-27.md`).
This run's `L-01`…`L-07` / `Q-01`…`Q-02` sequence covers **only** run-28's new findings.

### Reclassified after this bundle was written — `pps28m2` (owner triage, 2026-09-08)

The run-28 Medium **`pps28m2`** (`8aa45828a2227c34e254fff5779c4c91587e0a477a89800a7012360f3b8b7cef`,
`wagmi generate` silently dropping the `stableStakerAbi` export) was reclassified **Medium → Low** and
disposed **`wont-fix` (out of scope)** by the owner on 2026-09-08, verbatim: *"pps28m2 is not medium as no
funds are at risk. It's just a UI inconvenience that will be picked up at development time. It's also out of
scope for this audit which was about a script."* The audited entry point was the `dev` npm script;
`wagmi.config.ts` artifact resolution and the `update:hooks` → `npm publish` chain sit outside that closure.

It is **not** given an `L-` label in the sequence below and the count table above is unchanged, because the
bundle's numbering is run-scoped and the finding is disposed rather than live. It is recorded here so the
reclassification is visible in the QA channel rather than only in the ledger. The full technical record
remains at `submissions/M-02.md` and `findings/medium/M-02-wagmi-silent-stablestaker-abi-drop.json`, both
carrying the same triage banner.

---

## ⚠ Read this before cross-referencing: label collision hazard

Labels in this report are **run-scoped**. On this same entry point (`dev`), the ledger already
holds **pre-existing entries under the label strings `L-01`, `L-02` and `Q-01`, and those are
different findings from the ones bearing those labels here.**

| Label used here | This report's fingerprint | A *different* ledger entry also called this |
|---|---|---|
| `L-01` | `c35f8cdc52dcbdf71c143d8c059d896bf99973b83df84d3f351d93d981448a36` | ledger `L-01` `1e8cc0dc58ba0ecbe43faf12ea343e3d6eb784c36d3ad2b0141668e33777871e` (hard-coded `deploymentStatus`) |
| `L-02` | `88af91804ec23988388adb33bf17ec90f86825dc6ec017a5b31bc142f415d4bb` | ledger `L-02` `ec29eacd9501270a16ecd6c13c27e404357ab4e343bbfca5fd2fd421735170e4` (`clean:local` staleness asymmetry, **wont-fix**) |
| `Q-01` | `d7242d7c43ac0b2d8bb3903fb1bee66865d0bacfb7ae7c6d0037746d198324b6` | ledger `Q-01` (run-26 story-provenance entry) |

**Cross-reference by fingerprint only — never by label.** Every ledger operation, carryover copy
and triage note keyed off this report must use the 64-character fingerprint (or the `issueId`)
quoted verbatim in each section below. No fingerprint in this document has been shortened,
re-derived or recomputed; each is copied byte-for-byte from `classified-findings.json`.

---

## FR-28-03 — Latent ledger defect requiring a human `/ledger` correction

This is the highest-priority non-finding item in the run, and it is recorded here because the
QA bundle is where the affected findings live.

Ledger entry **`L-01` / `1e8cc0dc58ba0ecbe43faf12ea343e3d6eb784c36d3ad2b0141668e33777871e`**
(status `open`, entryPoint `dev`) carries:

- `rootCauseClass: "WriteBeforeBroadcast"` — a **timing** string;
- a **title and body describing the hard-coded `deploymentStatus: "completed"` VALUE**.

The class string and the finding do not describe the same defect. Worse, the class string is an
accurate description of **this run's `L-02`** (`88af91804ec2…`), which is the genuinely
timing-shaped finding: the progress artifact is written during forge's local *simulation* pass,
roughly fifteen minutes before the transactions it certifies are mined.

**Why it matters.** Left uncorrected, a future reconciliation pass that matches on
`rootCauseClass` could conclude that run-28's `L-02` and ledger `L-01` are the same finding and
**collapse them** — silently discarding the timing defect while the value defect stays open. That
is a recall failure of exactly the kind the pipeline exists to prevent.

**Disposition this run.** The ledger entry was deliberately left **byte-identical**. No status,
class or field was changed. Run-28's `L-02` is *pinned apart* from it, not merged.

**What is owed.** A human `/ledger` correction of the `rootCauseClass` on
`1e8cc0dc58ba…` to a value-shaped class. Note that this correction **will re-mint that entry's
fingerprint**, since the class string is part of the fingerprint basis — so the correction should
be made deliberately, and any artifact referring to `1e8cc0dc58ba…` (including the carryover
bundles) will need its reference updated at the same time.

Two further follow-up requests are recorded in the run artifacts and referenced from the sections
below: **FR-28-01** (a triage-shape question on story provenance, addressed in
`spec-conformance.md`) and **FR-28-02** (the tracked-vs-untracked tension between `L-06` and
`L-07`, described in both sections).

---

## Low Risk Findings

### [L-01] Top-level OpenZeppelin canonicalization to v5.6.1 shifts `ReentrancyGuard`'s storage layout relative to four contracts' own pins <!-- id: pps28l1 -->

**Fingerprint**: `c35f8cdc52dcbdf71c143d8c059d896bf99973b83df84d3f351d93d981448a36`
**Basis**: `lib/phoenix-phase-2-staging/foundry.toml:remappings:DependencyCanonicalizationAltersInheritedStorageLayout:dev`
**Location**: `lib/phoenix-phase-2-staging/foundry.toml:35-95` (remappings block), canonicalizing entries at `:110-127`

```toml
    # --- OpenZeppelin canonicalization (single top-level pin) -----------------
    # OZ is pinned at lib/openzeppelin-contracts @ v5.6.1 (tag 5fd1781b). Every
    # submodule vendors its OWN nested copy at a different commit (5.1.0 through
    # assorted 5.6.1-era master snapshots). Redirect each onto the single
    # top-level pin so there is exactly one physical EnumerableSet/SafeERC20/etc
    # -> no "Identifier already declared". Defensive: no first-party source
    # hard-codes a nested OZ path today, but the stable-staker entry previously
    # here existed because a real collision was hit once. Submodules are never
    # modified -- this is compiler-side path rewriting only.
    "lib/phUSD-stable-minter/lib/openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "lib/stable-staker/lib/openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "lib/stable-yield-accumulator/lib/openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "lib/vault/lib/openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "lib/flax-token-v2/lib/openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "lib/phlimbo-ea/lib/openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "lib/yield-claim-nft/lib/openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "lib/pauser/lib/immutable/openzeppelin-contracts/=lib/openzeppelin-contracts/",
    "lib/nft-staking/lib/immutable/openzeppelin-contracts/=lib/openzeppelin-contracts/"
```

**Description**

The delta canonicalizes every nested OpenZeppelin path onto one top-level v5.6.1 checkout,
overriding six submodules that pin their own versions. HEAD builds clean under the substitution
(`forge build` → EXIT 0), and roughly 96 reachable-file comparisons were made across the drifting
submodules:

- `Ownable.sol` — byte-identical in all six.
- `SafeERC20.sol` — rewritten in 5.5.0 but behaviour-preserving; the `SafeERC20FailedOperation(address)` error selector is unchanged.
- `ERC4626.sol` — the implementation is not reachable; only `interfaces/IERC4626.sol` is imported.
- `EnumerableSet.sol` — core byte-identical; the 5.x additions (`Bytes4Set`, `Arrays.replace`, `Math.clz`) are purely additive.

**One genuine divergence.** OZ 5.5.0 moved `ReentrancyGuard`'s `uint256 private _status` out of
slot 1 into an ERC-7201 namespaced slot (`REENTRANCY_GUARD_STORAGE`). Four in-scope contracts
inherit it while pinning a pre-5.5.0 OZ: `StableYieldAccumulator` (pins 5.1.0; live on mainnet at
`0x0cD353bfda674D04823B2826ffafB83B560D21B6`) and the three `AYieldStrategy` descendants
`YieldStrategyDola`, `YieldStrategyUSDe`, `YieldStrategyUSDC` (the vault pins 5.4.0). Under the
top-level pin, every storage slot after the old slot 1 shifts by one in the bytecode this
repository builds and tests.

This is deliberately **not** inflated. Nothing here is upgradeable, no proxy is involved, and no
first-party code reads a raw storage slot on these contracts (checked for `sload` / `vm.load` /
assembly slot access against all four). The runtime semantics of the guard are identical. What
this is, precisely, is a **reproducibility gap**: the bytecode `dev` deploys and the test suite
exercises is not the bytecode that was deployed to mainnet from the pinned sources.

Compounding: there is **no story** for this change. The full 81-file story tree was enumerated;
`5.6.1` appears nowhere, no story mentions an OZ pin, version or remapping change, and story 080 —
the only story naming `f929b5b` as its base — contains the string `openzeppelin` nowhere and
neither authorises nor presupposes the change.

**Impact**

Storage-layout equivalence between the audited/tested build and the mainnet build is no longer
guaranteed for four contracts, one of which is live. Any future work that *does* depend on layout —
an upgrade path, a storage-slot read, a `vm.load`-based test, a forked-state comparison — would be
reasoning from the wrong layout and would not be told. There is no exploit and no current
behavioural change, so this is a build-hygiene / reproducibility finding rather than a
vulnerability. It is ranked first among the Lows because it is the one Low whose subject matter is
live mainnet bytecode.

**Reopen trigger — re-weigh to Medium immediately** if any of the following becomes true for
`StableYieldAccumulator` or the three `AYieldStrategy` descendants:

1. an upgradeable / proxy pattern is introduced;
2. any code or test reads a raw storage slot (`vm.load`, assembly `sload`);
3. a forked-state slot comparison is added;
4. a redeploy is planned from the canonicalized build without re-verifying layout.

**Recommendation**

Pin the top-level OpenZeppelin to a version at or below the lowest pin among the canonicalized
submodules (5.1.0 here) so the built layout matches the deployed one, **or** bump the submodules'
own pins so every consumer genuinely targets 5.6.1 and the mainnet contracts are redeployed from
that build. Whichever is chosen, add a `forge inspect <contract> storage-layout` snapshot test for
`StableYieldAccumulator` and the three strategies so a future dependency bump that shifts a slot
fails loudly. And file the story: this is a cross-cutting dependency change with no acceptance
criteria anywhere.

---

### [L-02] The deployment progress file the API serves is written during the SIMULATION pass, ~15 minutes before the transactions it certifies are mined <!-- id: pps28l2 -->

**Fingerprint**: `88af91804ec23988388adb33bf17ec90f86825dc6ec017a5b31bc142f415d4bb`
**Basis**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:_writeProgressFile:ProgressArtifactWrittenInSimulationNotAfterBroadcast:dev`
**Location**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:1564` (write site), `:2620-2646` (`vm.writeJson`)

```solidity
        _sweepResidualPrivileges(deployer);

        vm.stopBroadcast();

        // ====== Write Progress File ======
        console.log("\n=== Writing Deployment Progress ===");
        _writeProgressFile();
```

**Description**

`run()` calls `_writeProgressFile()` at `:1564`, after `vm.stopBroadcast()` at `:1560`.
`_writeProgressFile` uses `vm.writeJson` — a cheatcode, not a transaction — so it executes during
forge's local **simulation** pass, before a single transaction has been dispatched, and is never
re-run after the broadcast completes.

Proved by file mtimes on the full clean run: `DEV_START=2026-09-07T11:28:36`;
`server/deployments/progress.31337.json` mtime `2026-09-07 11:28`; `ONCHAIN EXECUTION COMPLETE &
SUCCESSFUL` and `broadcast/DeployMocks.s.sol/31337/run-latest.json` at `11:43`. The artifact
asserting `"deploymentStatus": "completed"` for 72 contracts predates the 394 transactions that
deploy them by roughly fifteen minutes.

If the broadcast leg fails, reverts, is interrupted, or lands on the wrong chain (see the Medium
race finding), `progress.31337.json` still reads `completed` with all 72 contracts and their
addresses — because it was written from the simulation, where everything always succeeds.
`server/index.js` then loads exactly that file and serves it from `/progress`, `/contracts` and the
startup banner. This was confirmed end-to-end mid-audit: an earlier run whose broadcast was cut off
partway still left a `completed` progress file behind.

**Pinned apart from ledger `L-01` `1e8cc0dc58ba0ecbe43faf12ea343e3d6eb784c36d3ad2b0141668e33777871e`
(status `open`)** — and note that ledger entry bears the *same label string* as a different finding
in this report (see the collision warning above). The distinction is **timing versus value**:

- ledger `L-01` `1e8cc0dc58ba…` records that the status string is **hard-coded** to `"completed"` — the **VALUE** written;
- this finding records **WHEN** the file is written — during the simulation pass, never refreshed — the **TIMING**.

Fixing the hard-coded string alone would not help, because at write time the broadcast genuinely
has not started and no honest status is available yet. The two are not collapsed, and must not be.
See **FR-28-03** above: ledger `L-01`'s recorded `rootCauseClass` is `WriteBeforeBroadcast`, a
timing string that actually describes *this* finding — that mismatch is the collapse hazard, and it
requires a human `/ledger` correction.

**Impact**

The single artifact that everything downstream — the API, the generated TypeScript address
bindings, and any human checking whether the stack came up — treats as the record of a deployment
is a record of a dry run. It cannot distinguish a successful broadcast from a failed one, an
interrupted one, or one applied to a stale chain. Local-only, hence Low, but it is the mechanism by
which the other failure modes in this cluster stay invisible: it is the producer half of `L-04`'s
consumer-side over-claiming, and it is what lets the Medium stale-chain run emit a clean-looking
artifact.

**Recommendation**

Move the progress write out of the forge script and into a post-broadcast step that reads
`broadcast/DeployMocks.s.sol/31337/run-latest.json` — the file forge writes only after `ONCHAIN
EXECUTION COMPLETE & SUCCESSFUL` — and derives status and per-contract deployment from the actual
receipts. A minimal version: add a `node server/build-progress.js 31337` step to `deploy:local`
after the forge invocation, and have `_writeProgressFile` stamp `"deploymentStatus": "simulated"`
so an unconverted artifact is self-identifying rather than falsely reassuring.

---

### [L-03] `verify-stable-staker.sh` invokes two scripts that were moved to `script/archives/`, and the `foundry.toml` comment justifying the exclusion is falsified by that very reference <!-- id: pps28l3 -->

**Fingerprint**: `669de8af7eb962ae5a276e5c1080b0de13af3bd44780e86b207c19b71955fc24`
**Basis**: `lib/phoenix-phase-2-staging/verify-stable-staker.sh:STEP 1 / STEP 3:DanglingScriptReferenceAfterArchiveSweep:dev`
**Location**: `lib/phoenix-phase-2-staging/verify-stable-staker.sh:56` and `:67`; `lib/phoenix-phase-2-staging/foundry.toml:26-32`

```bash
echo "=== STEP 1: Stake into StableStaker DOLA pool ==="
forge script script/interactions/StakeStableStaker.s.sol:StakeStableStaker \
    --rpc-url "$RPC_URL" --broadcast -vv
...
echo "=== STEP 3: Claim + Withdraw and assert results ==="
forge script script/interactions/ClaimWithdrawStableStaker.s.sol:ClaimWithdrawStableStaker \
    --rpc-url "$RPC_URL" --broadcast -vv
```

```toml
# Archived one-off scripts. `script/archives/` holds the historical mainnet
# migration / interaction / redeploy scripts that were written as single-use
# actions before `script/interactions/Temp.s.sol` existed as the scratchpad.
# They are kept verbatim as references — they encode how past problems were
# solved and are useful when planning new scripts — but they are pinned to
# submodule interfaces that have since moved on, so they no longer compile.
# Excluding the whole directory keeps `forge build` green without deleting the
# history. Nothing outside the directory imports them.
skip = ["script/archives/**"]
```

**Description**

Both invoked paths are absent at HEAD; both files now live under `script/archives/interactions/`.
Running the exact command from the script yields `Error: No such file or directory (os error 2)`,
EXIT=1 — the script is dead end-to-end.

The `foundry.toml` comment justifies `skip = ["script/archives/**"]` with the claim *"Nothing
outside the directory imports them."* That claim is directly falsified by `verify-stable-staker.sh`,
which invokes two of them. In-source documentation carries no suppression authority, and a
justification comment that is demonstrably false is itself worth flagging: it is the sentence a
future reviewer would rely on to conclude the sweep was safe.

**Impact**

The stable-staker local verification harness — the stake → warp → claim/withdraw round trip that
proves the `StableStaker` wiring `dev` just deployed actually works — cannot be run at all. `dev`
deploys and wires `StableStaker` across three pools (observed in the live run: DOLA/USDC/USDe,
rates set, 10% set-aside buffer) but nothing exercises it afterwards. Local-only, and loudly
failing rather than silently wrong.

**Recommendation**

Repoint the two invocations at `script/archives/interactions/...` and narrow the `skip` glob so
those two files still compile (e.g. replace `skip = ["script/archives/**"]` with an explicit list),
or `git mv` the two interaction scripts back out of `archives/` as story 080 did for its own two
files. Correct the `foundry.toml` comment: it is not true that nothing outside the directory
references the archives, and the next sweep will be reasoned about from that sentence.

---

### [L-04] `server/index.js` reports a healthy, fully-deployed protocol from a stale tracked progress file with no chain running anywhere <!-- id: pps28l4 -->

**Fingerprint**: `8cd3c3bad599374f5dbace4e64fd1decde3e35315bbd392219c2eff10f0643a9`
**Basis**: `lib/phoenix-phase-2-staging/server/index.js:app.get('/health') / startup banner:HealthEndpointDecoupledFromLiveness:dev`
**Location**: `lib/phoenix-phase-2-staging/server/index.js:88-100` (`/health`), `:19-23` (progress load), `:193-194` (banner)

```javascript
app.get('/health', (req, res) => {
    const deployments = loadDeployments();
    const extracted = loadExtractedAddresses();

    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        deploymentsLoaded: deployments !== null,
        extractedAddressesLoaded: extracted !== null,
        chainId: 31337,
        network: 'anvil'
    });
});
```

```javascript
function loadDeployments() {
    try {
        const progressPath = path.join(__dirname, 'deployments', 'progress.31337.json');
        if (!fs.existsSync(progressPath)) {
            return null;
        }
        const data = fs.readFileSync(progressPath, 'utf-8');
        return JSON.parse(data);
```

**Description**

With no anvil running at all and `local.json` absent, `npm run serve` was started standalone and
probed:

- `GET /health` → HTTP 200, `{"status":"ok", ..., "extractedAddressesLoaded": false}`
- `GET /contracts` → HTTP 404
- startup banner → `Deployment Status: completed` / `Contracts Deployed: 72`

The banner and `deploymentStatus` are read from `server/deployments/progress.31337.json`, a file
committed to the repository. Nothing in `/health` makes an RPC call, so `ok` is a statement about
the process being alive, not about the protocol being deployed. Story 003's acceptance criterion
*"GET /health returns success response"* is therefore satisfied vacuously and cannot distinguish a
working stack from an empty one.

This compounds the stale-anvil race: after a Ctrl-C the server can be restarted against a leftover
chain and a committed progress file and report `completed / 72 contracts` for a deployment that
does not exist.

**Related, distinct — prior-entry disclosure.** Ledger `L-01`
`1e8cc0dc58ba0ecbe43faf12ea343e3d6eb784c36d3ad2b0141668e33777871e` (open, entryPoint `dev`) records
the **producer-side** defect: the progress file is *written* with a hard-coded
`deploymentStatus: "completed"`. This finding is the **consumer-side** one: `/health` and the
startup banner *read* that file — and, for `/health`, read nothing at all about the chain — and
present it as current liveness. The fixes are independent; correcting the writer would not stop
`/health` returning 200 with no chain running. Also distinct from ledger `Q-03`
`a37137b3e3695945979739c6f8094f869f7a45a4d4323e98b370f6f2ab161a2a` (same file, stale documentation
blob over-advertising a contract count) — a documentation count is not a liveness signal.

**Impact**

The one endpoint an operator or CI job would use to answer *"is the local stack up?"* returns
success in every state, including total absence of a chain, while the banner actively asserts a
completed 72-contract deployment. Local dev only, so no funds or mainnet state are at risk — but
the failure mode is silent over-claiming, which is what makes it worth reporting rather than the
missing `local.json` on its own.

**Recommendation**

Make `/health` actually probe liveness: attempt an `eth_chainId` (or `eth_blockNumber`) against
`http://localhost:8545`, plus a code-size check on one deployed address from `local.json`, and
return a non-200 (or `status: "degraded"` with an explicit `chainReachable:false` /
`addressesLoaded:false`) when either fails. Derive the startup banner from live chain reads rather
than from the committed progress file, or label it explicitly as "last recorded run" so it is not
read as current state.

---

### [L-05] `dev` has no terminating success signal: `serve` blocks forever, so the entry point can never exit 0 and cannot be gated in CI <!-- id: pps28l5 -->

**Fingerprint**: `c8c6fe8557a83a81a3448e013acdbb007aef6378d149c7f6e5603cc7e44bcdd0`
**Basis**: `lib/phoenix-phase-2-staging/package.json:dev:NoTerminatingSuccessSignal:dev`
**Location**: `lib/phoenix-phase-2-staging/package.json:16`

```json
"serve": "node server/index.js",
"dev": "npm run clean:local && npm run start:anvil & sleep 3 && LOCAL_PROMO_KENDU=true npm run deploy:local && ./simulate-yield.sh && npm run extract:addresses && npm run generate:ts-anvil && npm run serve",
```

**Description**

The final step of the `dev` chain is `npm run serve` → `node server/index.js`, an Express server
that blocks indefinitely. `dev` therefore has no exit-0 condition: success is judged by a human
reading console output. Verified by running the chain under `timeout --foreground 1750 npm run dev`
(DEV_EXIT=124) — the timeout was required precisely because the command has no natural end.

Three consequences compound with findings already filed:

1. `dev` cannot be used as a CI gate, so none of `DeployMocks`' ~40 in-script assertions ever run automatically;
2. Ctrl-C kills the foreground server but leaves pipeline A's backgrounded anvil alive, which is the stale-chain precondition for the Medium race finding;
3. because `/health` returns 200 unconditionally (`L-04`), there is no reliable programmatic signal of a good run from outside either.

The orphan was confirmed directly at teardown rather than inferred. After killing `serve`,
`npm run dev` returned EXIT 0 while pipeline A's anvil was still alive — `pgrep -af anvil` → pid
63568 `npm run start:anvil` plus 63594/63595 `anvil --host 0.0.0.0 --port 8545 --chain-id 31337
--block-time 2`, and `eth_chainId` on 8545 still answering `0x7a69`. It had to be killed by PID. So
the exact stale-chain precondition for the race finding is produced by the ordinary, successful way
this entry point ends.

**Impact**

The local rehearsal of the mainnet cutover — the run that exercises the PhlimboV2→V3 migration, the
dispatcher swap and the terminal privilege sweep — is not machine-verifiable. Its assertions only
protect whoever runs it by hand and reads the output. Local-only, hence Low, but it is the
structural reason the other defects in this cluster went undetected across a nine-commit delta.

**Recommendation**

Split the chain: add a `dev:ci` (or `bootstrap:local`) key that runs everything up to and including
`generate:ts-anvil`, then exits 0 — that is the part with assertions and the part CI needs — and
leave `dev` as `npm run dev:ci && npm run serve` for interactive use. Add a
`trap 'kill $ANVIL_PID' EXIT` (or `concurrently --kill-others`) so terminating the foreground also
tears down anvil. Then wire `dev:ci` into CI so `DeployMocks`' assertions actually run on every
commit.

---

### [L-06] `clean:local` deletes git-TRACKED files and re-runs under a live anvil, wiping scratch state from under the node it is about to broadcast to <!-- id: pps28l6 -->

**Fingerprint**: `bd268808fbd56c5f026b272d30da150dcbd2ec4aff06063c667d5275df97f850`
**Basis**: `lib/phoenix-phase-2-staging/package.json:clean:local / deploy:local:DestructiveCleanTouchesTrackedStateAndLiveNode:dev`
**Location**: `lib/phoenix-phase-2-staging/package.json:8-9`

```json
"clean:local": "rm -rf broadcast/*/31337 server/deployments/progress.31337.json server/deployments/local.json && rm -rf ~/.foundry/anvil/tmp/*",
"deploy:local": "npm run clean:local && forge script script/DeployMocks.s.sol:DeployMocks --rpc-url http://localhost:8545 --broadcast --slow --gas-estimate-multiplier 300",
```

**Description**

Two separate problems, both verified.

**(1) It deletes tracked files.** `server/deployments/progress.31337.json` is tracked at HEAD
(`git ls-tree f929b5b -- server/deployments/`), and `server/deployments/local.json` was tracked at
the diff base `1d8a3a7`. Running `clean:local` therefore dirties the working tree with deletions of
committed files — observed as `D server/deployments/progress.31337.json` in `git status` after
every `dev`. `rm -rf ~/.foundry/anvil/tmp/*` additionally reaches **outside** the repository into
the developer's home directory, deleting anvil scratch state belonging to any other project.

**(2) `deploy:local` re-runs `clean:local` a second time**, and by then anvil is already up
(pipeline A started it during the `sleep 3`). That second invocation deletes
`~/.foundry/anvil/tmp/*` out from under a **running** anvil, and deletes `broadcast/*/31337`
immediately before the forge run that is about to write it. Neither is currently fatal — anvil
holds its state in memory and forge recreates the broadcast dir — so this is latent rather than
live. But it is unsynchronised destruction of state belonging to a concurrently-running process,
and the ordering that makes it benign is not enforced anywhere.

**(3) A third artifact of the same design.** `server/deployments/addresses.ts` and
`server/deployments/local-addresses.ts` are also tracked, are **not** in `clean:local`'s delete
list, and are rewritten by `generate:ts-anvil` on every run with a change consisting solely of the
generation timestamp (`git diff` after the live run:
`-// Generated interface from local.json on 2026-08-10T21:51:16.749Z` /
`+// ... 2026-09-07T09:43:08.585Z`, one line each). So every `dev` run guarantees two tracked-file
modifications with zero semantic content, on top of the tracked deletions.

**Prior-entry disclosure.** Ledger entry `L-02`
`ec29eacd9501270a16ecd6c13c27e404357ab4e343bbfca5fd2fd421735170e4` on this same entry point is
**wont-fix** and also concerns `clean:local` — but its subject is the **opposite root cause**: it
records that `clean:local` deletes the JSON deployment artifacts while leaving the generated
TypeScript address files behind (a staleness asymmetry — *under*-deletion). Neither problem filed
here — deletion of git-tracked files, and the second invocation running concurrently with a live
anvil (*over*-deletion plus concurrency) — is covered by that entry or by the reasoning that closed
it. **The wont-fix rationale is not assumed to extend to this finding.** This is filed as a
distinct root cause, not a re-raise; the owner's wont-fix on the staleness asymmetry is not
disturbed. A triager may nonetheless prefer to reopen and broaden `ec29eacd9501…` rather than carry
a second entry on the same key — that is a `/ledger` shape decision, and this run deliberately did
not make it.

**Tension with `L-07` — FR-28-02.** This finding's recommendation points toward **untracking**
`server/deployments/local.json`; `L-07`'s points toward **re-tracking or seeding** it. Both
directions are presented honestly below and in `L-07`; see the FR-28-02 note at the end of `L-07`.

**Impact**

Working-tree noise that masks real changes in `git status` / `git diff` for anyone reviewing a
`dev` run, deletion of another project's anvil scratch state, and a latent race against the live
node. Local-only and recoverable with `git checkout`.

**Recommendation**

Untrack the generated artifacts (`git rm --cached server/deployments/progress.31337.json
server/deployments/local.json` and add both to `.gitignore`) so `clean:local` only ever removes
build output — or, if they are wanted as committed fixtures, drop them from the `rm` list and let
the deploy overwrite them. Narrow the anvil scratch wipe to a project-scoped path rather than
`~/.foundry/anvil/tmp/*`. Remove the leading `npm run clean:local` from `deploy:local` so the wipe
happens exactly once, before anvil starts, rather than concurrently with it.

---

### [L-07] `server/deployments/local.json` was removed from git tracking, so `generate:ts-anvil` and `serve` now fail when run standalone <!-- id: pps28l7 -->

**Fingerprint**: `98e72721490398830324ab4cb3e7f31cb746ca7bce1f3e46c92d58fc761509c1`
**Basis**: `lib/phoenix-phase-2-staging/server/generate-ts-addresses.js:main:SeedArtifactDeTrackedWithoutFallback:dev`
**Location**: `lib/phoenix-phase-2-staging/server/generate-ts-addresses.js:101-104`; `lib/phoenix-phase-2-staging/server/index.js:36-40`

```javascript
    if (!fs.existsSync(inputPath)) {
        console.error(`Error: Input file not found: ${inputPath}`);
        console.error("Run 'npm run extract:addresses' first.");
        process.exit(1);
    }
```

```javascript
function loadExtractedAddresses() {
    try {
        const localPath = path.join(__dirname, 'deployments', 'local.json');
        if (!fs.existsSync(localPath)) {
            return null;
        }
```

**Description**

`server/deployments/local.json` was tracked at the diff base
(`git ls-tree 1d8a3a7 -- server/deployments/local.json` → present) and is neither tracked nor
present at HEAD (`git ls-tree f929b5b` → empty; file absent on a clean checkout). It is now
produced only by `extract:addresses`, step 4 of the `dev` chain.

Verified on a clean checkout: `npm run generate:ts-anvil` standalone exits 1 via the guard at
`generate-ts-addresses.js:101-104`; `npm run serve` standalone starts but `/contracts` returns 404,
because `loadExtractedAddresses()` returns `null` silently. Both keys used to work from a fresh
clone. Only the full `dev` chain regenerates the file, and only after a ~15-minute deploy leg.

For accuracy: the `generate-ts-addresses.js` guard **does** name a producing command
(`Run 'npm run extract:addresses' first.`) — as the quoted code shows — though it does not mention
that `extract:addresses` itself requires a completed `deploy:local`. The `server/index.js` path
gives no message at all: the 404 is silent.

**Impact**

Two package.json entry points that were previously independently runnable are now hard-coupled to a
full local deployment. A developer regenerating TypeScript address bindings, or bringing up only
the API against a chain that is already deployed, hits an exit-1 or a bare 404. Local dev only.
Held at Low rather than QA because two previously runnable entry points lost their independence,
which is a small availability regression in the local toolchain.

**Recommendation**

Either re-track a representative `local.json` (it is generated output, so prefer not to) or, better,
make both consumers fail with an actionable message: at `generate-ts-addresses.js:101-104` extend
the existing pointer to name the full order — e.g. `local.json not found. Run: npm run
extract:addresses (after npm run deploy:local)` — and add the equivalent message on the
`server/index.js:36-40` path so the 404 is not silent. Document the dependency order in the
`//local-deploy` comment alongside the existing story-003 reference.

**FR-28-02 — opposed recommendations, a triager must pick one.** `L-06` and this finding touch the
same artifact from opposite ends and their remedies are in mild tension:

| | Direction | Rationale |
|---|---|---|
| `L-06` (`bd268808fbd5…`) | **Untrack** `local.json` (and `progress.31337.json`), `.gitignore` them | Stops `clean:local` dirtying the tree by deleting committed files |
| `L-07` (`98e727214903…`) | **Track / seed** a representative `local.json`, or at minimum make its absence self-explaining | Restores standalone `generate:ts-anvil` and `serve` from a fresh clone |

They are not silently harmonized here. A triager must choose **track-and-protect** (keep the file
committed, and remove it from `clean:local`'s `rm` list so the tree stays clean) **or**
**untrack-and-seed** (gitignore it, and ship a `local.example.json` plus actionable error messages
so the standalone keys still guide the developer). Both are coherent; picking one resolves both
findings, and picking neither leaves both open. Do not collapse the two entries — they have
distinct fingerprints and distinct evidence.

---

## QA Findings

### [Q-01] `_seedNudgeStream`'s NatSpec justifies its load-bearing assertion with a claim about `collectNudge` that stopped being true when ledger M-01 was fixed <!-- id: pps28q1 -->

**Fingerprint**: `d7242d7c43ac0b2d8bb3903fb1bee66865d0bacfb7ae7c6d0037746d198324b6`
**Basis**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:_seedNudgeStream:StaleInSourceRationaleAfterUpstreamFix:dev`
**Location**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:2069-2080`

```solidity
    ///      Doubles as the fee-on-transfer probe. `collectNudge` does
    ///      `safeTransferFrom(donor, streamer, amount)` and then credits `buffer += amount`
    ///      UNCONDITIONALLY — it never measures what actually landed. A taxed token would
    ///      therefore over-credit the buffer and the stream would run dry mid-window, so the
    ///      balance-delta assertion below is load-bearing, not decorative. The delta is exact
    ///      rather than approximate because the stream was registered moments ago with an empty
    ///      buffer, so `collectNudge`'s pre-settle transfers nothing out.
    function _seedNudgeStream(address deployer, address token, uint256 amount) internal {
```

**Description**

That description is false at HEAD. The `NudgeStreamer` this repository actually builds against —
resolved via the `nft-staking/=lib/nft-staking/src/` remapping from `DeployMocks.s.sol:72` — now
measures the delta explicitly, which is ledger finding `M-01`
(`a753907e2a4c6261389ea642ede743e198b50741d4bcb43fa8bad900729174d1`) landing complete:

```solidity
uint256 heldBefore = IERC20(token).balanceOf(address(this));
IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
uint256 received = IERC20(token).balanceOf(address(this)) - heldBefore;
if (received > amount) received = amount;
if (received == 0) revert NudgeStreamer__ZeroReceived();
s.buffer += received;
```

The over-credit failure mode the comment describes is structurally impossible now, and the cap
handles the donation direction too. The `require(received == amount, ...)` in the script is still a
valid fee-on-transfer probe for the **mock** tokens, but it no longer defends what it says it
defends.

This is pinned apart from ledger `M-01` `a753907e2a4c…` (status `fix-pending`): it is not a
restatement of the `collectNudge` defect, it is documentation drift *caused by* that defect being
fixed. Note the label-collision caveat above — a *different* ledger entry is also labelled `Q-01`.

**Impact**

A future reader — human or agent — reasoning about whether the streamer is safe against taxed
tokens will be told by this comment that the in-contract guard does not exist, when it does;
conversely, anyone deciding whether the script-level `require` can be relaxed will over-weight it.
Documentation drift only, no behavioural consequence. Reported rather than dropped because the
comment explicitly designates itself *load-bearing* — precisely the class of self-certifying
in-source claim that carries no suppression authority.

**Recommendation**

Rewrite the comment to describe the current contract: `collectNudge` measures the received delta
and caps it at `amount`, so the script-level `require(received == amount)` is now a stricter local
check that the mock token is not taxed (which would silently change the seeded rate), not a defence
against streamer over-credit. Cross-reference the `M-01` fix so the two stay in sync. **Propose
`M-01` (`a753907e2a4c…`) FIXED — propose only; no ledger status was changed by this audit.**

---

### [Q-02] `dev` requires `ANVIL_PRIVATE_KEY` but neither sets it nor documents it anywhere the operator will look <!-- id: pps28q2 -->

**Fingerprint**: `d3aa1e35c995a93509a1c3ce85cbd6654319dd5623b20a67b0e7852f81bf602f`
**Basis**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:run:UndocumentedRequiredEnvVar:dev`
**Location**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:387` (compare `:398`)

```solidity
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ANVIL_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
...
        armKenduPromo = vm.envOr("LOCAL_PROMO_KENDU", true);
```

**Description**

`DeployMocks.s.sol:387` reads `vm.envUint("ANVIL_PRIVATE_KEY")` with no default and no `envOr`
fallback. The `dev` key does not set it, there is no `.envrc` or `.env.example` in the submodule
that supplies it, and its only documentation is a line in the project `CLAUDE.md:476` naming the
well-known anvil account-0 key `0xac0974bec…ff80`. Without it exported, the whole chain aborts at
step 2 with a bare `forge` environment error — **after** pipeline A has already started a background
anvil, which then survives as an orphan.

That orphan is the point. **The orphaned anvil this failure leaves behind is exactly what
manufactures the stale-chain precondition on which the Medium finding `M-01` depends**: a
subsequent `dev` run finds port 8545 already answering `0x7a69` on a chain from a previous
lifetime, and proceeds against it. A first-run failure that would otherwise be trivial onboarding
friction is therefore also one of the concrete producers of the run's most serious finding, which
is why it is reported rather than dropped.

By contrast `LOCAL_PROMO_KENDU` at `:398` uses `vm.envOr` with a sensible default, so the pattern
for handling this correctly already exists eleven lines away.

**Impact**

First-run failure for any new developer or CI job, with an unhelpful error and an orphaned anvil
left behind. The key itself is the public anvil test key, so there is no secret-handling concern —
this is an onboarding footgun. Rated QA rather than Low because the failure is loud, immediate,
local and one line to fix; nothing is silently wrong.

**Recommendation**

Use `vm.envOr("ANVIL_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80))`
— it is the standard public anvil account-0 key and the script is chain-31337-only, so defaulting it
is safe and removes the failure entirely. If an explicit opt-in is preferred instead, set it in the
`dev` key, add a `.env.example`, and add a `require` with a message naming the variable so the
failure is self-explaining. Pair this with `L-05`'s teardown trap so a failed run cannot leave an
orphaned anvil behind either way.

---

## Automated QA / gas report (4naly3er)

**Not produced for this run — gap recorded rather than skipped silently.** 4naly3er is a
Solidity-source SAST/gas reporter; the `dev` entry point's findings are concentrated in
`package.json` shell orchestration, `server/*.js`, `foundry.toml` remappings and a
`script/DeployMocks.s.sol` forge script that is deploy tooling rather than deployed source. A
4naly3er pass over `lib/phoenix-phase-2-staging/src` would report on contracts outside this entry
point's closure and would not have surfaced any finding in this bundle. If a full-project
`/full-audit` of `phoenix-phase-2-staging` is run, attach its 4naly3er output there; it is not a
meaningful appendix to a single-script audit.


---

<!-- Part B: verbatim copy of reports/30/submissions/carryover/spec-conformance-28.md -->

# Part B: Law-2 / spec-conformance entries (verbatim)

---

# Carryover spec-conformance report — audit 28 (entry point `dev`), carried at audit 30

> **Carryover Law-2 report — audit 28** (copied in full from
> [`reports/28/submissions/spec-conformance.md`](../../28/submissions/spec-conformance.md)).
> Prepended header by audit 30; **the body below is a verbatim copy and has not been edited.**
>
> - **Retained (still open as of audit 30): `F-01` (`dcf756f7a897…` / `pps28f1`), `F-02`
>   (`beb259209f88…` / `pps28f2`), `F-03` (`da94d1ba03fd…` / `pps28f3`) — all three.**
> - **Removed as no longer live: none.**
> - **Statuses changed by audit 30 in this file: NONE.**
> - **⚠ Audit-30 cross-reference:** audit-28 `F-03` (`ShippedWorkWithoutAcceptanceCriteria`) and
>   audit-26 `Q-01` (`1c98937375ad…`, `StoryProvenanceGap`) cover work that **never had**
>   acceptance criteria. Audit 30's new `F-01` (`d862aec474e0…`,
>   `UnauthorisedReversalOfACompletedStory`) makes the **stronger and distinct** claim that work
>   which **had** accepted criteria, sitting in `complete/`, was silently and selectively reversed.
>   Deliberately **NOT collapsed** — but note this is the **third run in four** to raise an
>   un-storied-work finding on this entry point (run-26 `Q-01`, run-28 `F-03`, run-30 `F-01`).
>   **The recurrence is itself signal and should be weighed as a pattern, not triaged in isolation.**
> - **Line numbers below were accurate at the originating commit `f929b5b`. Re-verify against
>   current HEAD `e6eded0` before acting.**

---

# Spec Conformance (Law 2) — phoenix-phase-2-staging, script audit of the `dev` entry point (run 28)

**Project**: `phoenix-phase-2-staging`
**Entry point**: `dev` (`package.json:16`)
**Audited commit**: `f929b5b36629f73d17e350e383c77e2f24c40d71`
**Entry-point baseline for this delta**: `1d8a3a7515adca7819c530a01a87c132863a5ae2` → `f929b5b3…`
**Branch**: `master`
**Story tree consulted (READ-ONLY)**: `~/code/product-owner/stories/phStaging2/`

This is the **Law-2 faithfulness report**. It is separate from `submissions/qa-report.md` and
does not restate it: the Low/QA bundle grades *what the code does*, this document grades *whether
the code does what its story said*. Where a faithfulness finding shares evidence with a QA
finding, the QA entry is cited, not reproduced.

| ID | Issue ID | Fingerprint (prefix) | Severity | Deviation |
|---|---|---|---|---|
| F-01 | `pps28f1` | `dcf756f7a897…` | Low | `dev` pins `LOCAL_PROMO_KENDU=true`, modifying a `package.json` key story 079 forbade touching and making the dormant leg unreachable |
| F-02 | `pps28f2` | `beb259209f88…` | Low | `_seedNudgeStream` gated behind the optional leg, against story 079's explicit "stays unconditional" |
| F-03 | `pps28f3` | `da94d1ba03fd…` | Low | Three cross-cutting changes shipped with **no story and no acceptance criteria**; all nine delta commits untagged |

**Ordering hazard — read before scheduling any fix.** F-01 and F-02 are not independent. F-02 is
latent **today only because** F-01 pins the armed leg. Fixing F-01 alone — unpinning the env var
without ungating the seed — **arms the defect rather than closing it**. See *Combined remediation
ordering* below.

---

## F-01 — `dev` pins `LOCAL_PROMO_KENDU=true`, making the dormant (day-one mainnet) leg unreachable <!-- id: pps28f1 -->

**Fingerprint**: `dcf756f7a8977d7d8f3b8b3fb96cbe478f392b057ac045cb0e5928164123d92a`
**Basis**: `lib/phoenix-phase-2-staging/package.json:dev:EntryPointPinsRehearsalToNonMainnetLeg:dev`
**Location**: `lib/phoenix-phase-2-staging/package.json:16` (the `dev` key)
**Story graded against**: story 079
**Story document**: `/home/justin/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`
**State folder**: `complete`  ·  **Sprint folder**: `phStaging2-script-audit-26`
**Story base commit** (from the document header): `1d8a3a7515adca7819c530a01a87c132863a5ae2` — exactly this audit's baseline.

### The acceptance text this violates, verbatim

From the story's *Explicitly OUT of scope (do not touch, do not "helpfully" fix)* list, line 32:

> - `src/` contracts, the UI repo, `package.json`, and `.envrc` secrets.

And from the story's closing checklist, line 547:

> - [x] Confirm no mainnet script, no `src/` contract and no `package.json` key was modified — `git status --porcelain` shows only `script/DeployMocks.s.sol`

That checkbox is **ticked** in the story document. It is false at `f929b5b`: `package.json:16` now
carries `LOCAL_PROMO_KENDU=true` inside the `dev` key.

For context, the fix story 079 was written to deliver (its remediation table, line 21):

> | `pps26l3` (L-03) | The Kendu promotion is armed unconditionally at the end of every local run, so the **dormant** promo state mainnet ships on day one is the one state `dev` can never produce | Gate the arming on a global boolean, default ON |

### The deviation

The contract-script half of that fix **landed correctly**. `DeployMocks.s.sol:398` reads
`armKenduPromo = vm.envOr("LOCAL_PROMO_KENDU", true)`, and a full dormant leg exists at `:400`,
`:1631-1639`, `:2044-2061` and `:2193-2199` — armed-by-default included, exactly as mandated.

The delta then added the assignment to the `dev` key itself:

```
"dev": "npm run clean:local && npm run start:anvil & sleep 3 && LOCAL_PROMO_KENDU=true npm run deploy:local && ./simulate-yield.sh && ..."
```

A command-prefix assignment **overrides the inherited environment**, so the toggle is inert from
outside. Verified:
`LOCAL_PROMO_KENDU=false bash -c 'LOCAL_PROMO_KENDU=true sh -c "echo \$LOCAL_PROMO_KENDU"'` → `true`
(control without the prefix → `false`). A developer who follows the instruction the script itself
prints cannot make it take effect.

The script contradicts its own entry point in three places:

- `DeployMocks.s.sol:210-213` (NatSpec): *"Set LOCAL_PROMO_KENDU=false to boot the DORMANT chain
  instead — the state mainnet actually ships on day one, and the one state this script could
  previously never produce."*
- `DeployMocks.s.sol:1634`, printed at the end of **every** `dev` run and captured verbatim in this
  run's live log: *"Set LOCAL_PROMO_KENDU=false to boot the DORMANT (day-one mainnet) chain"*.
- `DeployMocks.s.sol:1984`: *"Do not read the armed leg's behaviour as a prediction of mainnet's."*
  `dev` pins the rehearsal to precisely the leg its author says must not be read as a prediction.

The day-one mainnet configuration — `promoToken == address(0)`, `promoRewardBalance == 0`,
phUSD/Kendu streams whitelisted-but-unregistered — is therefore unreachable through `npm run dev`
without editing `package.json`. Story 076 (`complete/phStaging2-promotion-ready/076-…`, checklist
line 566) requires of the mainnet cutover:

> - [x] **No `startPromotion` call anywhere.**

So the shape the UI must render gracefully on day one is the one shape the entry point anyone runs
never produces, while the divergent armed shape is rehearsed every time.

This is **not an incomplete fix of L-03 as filed** — the fix landed complete. It is a correct fix
**partially reverted one layer up**, by one of the nine untagged commits in this delta.

### Consequence for triage (ledger)

- Ledger `L-03` / `pps26l3`, fingerprint `12bcca3b617c6c077babfad810a2457a1b8f3a5d352217b4acb135e8b9859e79`,
  status **`fix-pending`** — must be **HELD at `fix-pending`**.
- **Run-27's propose-fixed for this entry is WITHDRAWN.** The behaviour L-03 demands cannot be
  verified through the only entry point anyone runs, so no verification of the fix is possible from
  `dev` at `f929b5b`. A fix that cannot be exercised is not a verified fix.
- No status was changed by this run. This is a **proposal only**; apply nothing without
  `/ledger phoenix-phase-2-staging …`.

Local-only, so no funds are at risk. It is Low because it degrades the evidentiary value of the
rehearsal and silently undoes work a human triaged as `fix-pending` — the exact class the ledger's
INCOMPLETE-FIX rule exists to catch.

### Recommendation (verbatim from the finding record)

> Delete `LOCAL_PROMO_KENDU=true` from the `dev` key and let `vm.envOr`'s default supply the armed
> leg (identical behaviour, toggle restored). If an explicit armed default is wanted at the npm
> layer, add a second key (`dev:dormant` with `LOCAL_PROMO_KENDU=false`) rather than pinning the
> only one. Add a rehearsal obligation that BOTH legs are booted before a mainnet cutover, since
> only the dormant leg matches day one.

---

## F-02 — `_seedNudgeStream` gated behind the optional leg, disarming a load-bearing fee-on-transfer probe <!-- id: pps28f2 -->

**Fingerprint**: `beb259209f88e76e748c09fd10a3bdeb63339edcf9dab180b4bcacdc0caae798`
**Basis**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:_registerNudgeStreams / _seedNudgeStream:SafetyProbeGatedBehindOptionalLeg:dev`
**Location**: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:2044-2061` (gating block); probe at `:2069-2096`
**Story graded against**: story 079
**Story document**: `/home/justin/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`
**State folder**: `complete`  ·  **Sprint folder**: `phStaging2-script-audit-26`

### The acceptance text this violates, verbatim

From *Implementation Notes*, lines 476-478:

> **Do NOT gate the Kendu nudge stream.** `_seedNudgeStream` (`:1781-1788`) mints MockKendu for the
> *nudge stream*, which is a different mechanism from the PhlimboV3 promotion and is unrelated to
> L-03. It stays unconditional.

The instruction is unambiguous, is bolded in the story, and gives its reason: the nudge stream is a
*different mechanism* from the PhlimboV3 promotion, so the promotion toggle has no business
governing it.

### The deviation

`git diff 1d8a3a7 f929b5b -- script/DeployMocks.s.sol` moves `nudgeStreamer.registerStream(phUSD)`,
`registerStream(mockKendu)` and **both** `_seedNudgeStream` calls inside `if (armKenduPromo) { … }
else { … }` at `:2044-2061`.

The consequence is concrete, not cosmetic. `_seedNudgeStream` is self-documented as doubling as the
fee-on-transfer probe and terminates at `:2096` in:

```solidity
require(received == amount, "nudge seed token is fee-on-transfer: streamer received < sent");
```

described in-source as *load-bearing, not decorative*. Under the gating, that assertion executes on
the **armed leg only**. The dormant leg — the one that matches day-one mainnet — performs no
seeding and therefore **runs no probe at all**, silently.

### Ordering hazard — state this before scheduling either fix

Today the probe does in fact run on every `npm run dev`, because F-01 pins `LOCAL_PROMO_KENDU=true`.
That is the *only* reason there is no live loss of coverage. The two defects therefore interlock:

- **Fixing F-01 alone ARMS F-02.** Unpin the env var without ungating the seed, and the very first
  `LOCAL_PROMO_KENDU=false` run — the dormant, day-one-mainnet rehearsal that F-01's whole purpose
  is to make reachable — becomes a rehearsal that quietly omits its own safety guard, with no error
  and no log line saying the probe was skipped.
- **F-01 and F-02 must be fixed together, F-02 first or simultaneously.** Ungate the seed (or hoist
  the probe out of it) *before or in the same change as* unpinning the `dev` key. Never the reverse
  order.

Low severity: local-only, no current loss of coverage. But it is a real Law-2 deviation with a
demonstrable safety consequence, and it landed on commits carrying no story tag at all.

### Recommendation (verbatim from the finding record)

> Either restore the seeding/probe as unconditional per story 079 (registering and seeding the
> phUSD/Kendu streams costs nothing on the dormant leg beyond two extra streams the UI is supposed
> to render gracefully anyway), or — if the dormant leg must genuinely leave them unregistered to
> mirror mainnet — hoist the fee-on-transfer probe out of `_seedNudgeStream` into an unconditional
> check that runs on both legs, and amend story 079 (or file a superseding story) rather than
> silently contradicting it.

---

## F-03 — Shipped work with no story at all <!-- id: pps28f3 -->

**Fingerprint**: `da94d1ba03fd07a0a6bedfab78b0aed8d00cb8c6aee0054489a5adb8b978d130`
**Basis**: `lib/phoenix-phase-2-staging/package.json:n/a (repository-level):ShippedWorkWithoutAcceptanceCriteria:dev`
**Scope**: repository-level, delta `1d8a3a7..f929b5b`
**Story graded against**: none — that is the finding.

### This is an ESTABLISHED ABSENCE, not an unavailable document

The complete phStaging2 story tree was enumerated:

```
find ~/code/product-owner/stories/phStaging2 -type f -name '*.md'   ->  81 files
```

across **every** state folder (`complete`, `auto-complete`, `incomplete`, `review`, `archive`) and
**every** sprint/worktree folder, highest story number `080`, no `081+`, no decimal insertion above
`045.5`. The tree was then grepped in full for `openzeppelin`, `archives`, `dedweight|deadweight`,
`LOCAL_PROMO_KENDU` and `antimatter`.

The stories below **do not exist**. This is a verified absence in an enumerated corpus — it is not
a case of a story being external, unavailable, or unreadable.

### The three untracked changes

| Change | Evidence | Story |
|---|---|---|
| OpenZeppelin single-pin canonicalization to v5.6.1 (new top-level `lib/openzeppelin-contracts` @ `5fd1781b`; `@openzeppelin/contracts/` repointed off `lib/phUSD-stable-minter`'s nested copy; 9 nested-OZ canonicalizing remaps added; `erc4626-tests/` and `halmos-cheatcodes/` remaps deleted) | commit `f38d413`; `foundry.toml` (+/−46) | **NO STORY EXISTS** |
| `script/archives/**` sweep — **108 files moved** — plus `skip` widened from 3 named files to the whole directory | commits `96a991b` / `f929b5b`; `foundry.toml` | **NO STORY EXISTS** |
| **246 `package.json` script keys deleted** (287 → 41; `git diff --numstat` = `2 248 package.json`; 246 keys removed, 0 added) | commits `96a991b` / `f929b5b` | **NO STORY EXISTS** |

The only archives mandate anywhere in the tree is story 080's two-file `git mv` **out of** archives,
whose Implementation Note (line 174) says the opposite of a sweep:

> - **Archived scripts stay on V1 and keep compiling.** Everything under `script/archives/` imports
>   `stable-staker/versions/v1/StableStakerV1.sol`, which is frozen and still present. Do not touch
>   them; they are mainnet history.

and whose Autonomous Decision 7 (line 303) explicitly **rejects** removing the `skip` directive.

### All nine delta commits are untagged

`git -C lib/phoenix-phase-2-staging log --format='%h%x09%s' 1d8a3a7..f929b5b` — **9 commits, zero
`[story-NNN]` tags**:

| SHA | Subject | Story tag |
|---|---|---|
| `2eb2d69` | trial run of dev | — |
| `287be7b` | Kendu readiness increases | — |
| `fd2e37a` | super serial | — |
| `d5cb253` | foundry update | — |
| `4e5cca1` | mainnet promotion ready deployment | — |
| `f38d413` | Pin OpenZeppelin as a top-level submodule at v5.6.1 | — |
| `8e614d6` | Add antimatter submodule; bump stable-staker (+ vault in lockstep) | — |
| `96a991b` | dedweight removal | — |
| `f929b5b` | dedweight removal | — |

Per CLAUDE.md, a `[story-NNN]` subject is only ever a *pointer* to the story document; none of these
even carries a pointer, and nothing was graded from a commit subject. Note also that `4e5cca1` is
the artifact of a **mainnet broadcast** landing with no story tag.

### `promotion-ready:verify` was deleted, and story 075 exists specifically to create it

Verified against the story document:

**`/home/justin/code/product-owner/stories/phStaging2/auto-complete/phStaging2-audit-fixes/075-promotion-ready-standalone-post-broadcast-verification-entry-point.md`**
**State folder**: `auto-complete`  ·  **Sprint folder**: `phStaging2-audit-fixes`

Its title carries the audit provenance explicitly:

> # Standalone Post-Broadcast Verification Entry Point for the Promotion-Ready Cutover (audit-22 M-01)

Its *File Locations* table (line 111):

> | `package.json` | New `promotion-ready:verify` key; append it to `:broadcast` (287) and `:resume` (289); update the `//promotion-ready:broadcast` doc key (286). |

Its completion record (lines 384-385):

> - [x] Added `promotion-ready:verify` (plus a `//promotion-ready:verify` doc key), appended at the end of the scripts block per the project CLAUDE.md ordering rule.
> - [x] Appended `&& npm run promotion-ready:verify` to `:broadcast` and `:resume`, after the patch script.

And its stated reason for existing (lines 20-22):

> Net: **on the broadcast path there is no outcome verification of any kind.** The design's only
> compensating control is procedural — story-072 checklist line 1195, which is unticked.

The 246-key purge removed `promotion-ready:verify` (confirmed mechanically: the key is present in
`1d8a3a7:package.json` and absent from `f929b5b:package.json`). **Nothing anywhere in the tree
authorises removing it.** The remediation an audit asked for, and a story was written to deliver,
was deleted by an untagged commit — leaving ledger entry `2c53e944caee…` (`fix-pending`, the
promotion-ready Medium) with its landed remedy gone. That defect is filed on its own evidence as
run-28 `M-03` (orphaned promotion-ready runbook); it appears here only as the faithfulness fact.

### Lineage to ledger `Q-01` — kept separate per FR-28-01

This finding **compounds**, and does not duplicate, standing ledger entry:

- **`Q-01` / `pps26q1`**, fingerprint `1c98937375adc20c171c86ba91246476283add1bf72736a0e945606c643d1e9e`,
  status **`open`**, severity QA, first seen `phoenix-phase-2-staging-26` — *"The un-storied 'Story
  079' work has no acceptance criteria anywhere to be graded against."*

**FR-28-01** was raised at the deduplicator precisely because run-28's F-03 and ledger `Q-01` share
a theme. They are **kept separate**, and the ledger entry was left byte-identical (no status, class
or field changed):

- `Q-01` is about a **prior** body of work (the pre-079 "Story 079" attribution and its 22 in-source
  references across 6 files) having no acceptance criteria. Story 079's own scope list, line 28,
  says of it: *"**This story is NOT that missing story.** Do not rewrite, renumber or remove any
  `Story 079` / `STORY 079` comment reference. Q-01 remains open."*
- `F-03` is about **this delta's** three cross-cutting changes having no story at all, plus nine
  untagged commits.

Collapsing them would discard one of the two absences. They are pinned apart.

### Why it matters

Three cross-cutting changes — one altering dependency resolution for the entire build, one removing
108 files from compilation, one removing 246 operator entry points — shipped to master with nothing
to grade them against and no reviewer checklist that would have caught the concrete defects they
introduced: the wagmi silent ABI drop (`M-02`), the orphaned promotion-ready runbook (`M-03`), the
dead verify harness (`L-03`) and the `ReentrancyGuard` storage-layout divergence (`L-01`). Each of
those is filed separately with its own evidence; **F-03 is the systemic root that explains them.**

### Recommendation (verbatim from the finding record)

> Write (or retro-write) stories with acceptance criteria for the three untracked changes before any
> further work builds on them — at minimum the OZ pin needs a stated compatibility target and the
> package.json purge needs an explicit list of what was intentionally retired versus swept. Merge
> `sprint/stable-staker-v2` or revert the story-080 code from master so code and story travel
> together. Restore `[story-NNN]` tagging on commits; the nine untagged commits are what made this
> delta ungradeable in the first place.

---

## Story 080 — the boundary condition for this grading

**Story document**: `/home/justin/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/080-deploymocks-stablestakerv2-antimatter-cutover.md`
**State folder**: `auto-complete`  ·  **Sprint folder**: `phStaging2-stable-staker-v2`
**Title**: *DeployMocks: deploy Antimatter + StableStakerV2 and rehearse the V1→V2 cutover*
**Base Commit (document header)**: `ac70af6fd497fbd190f6e0fa3a2dba07b896778a`, `Execution Type: new_worktree`

Story 080 is complete and reviewed — its Review Results record all 45 checkboxes substantiated
against the worktree diff at `ac70af6` — but it sits on the **UNMERGED** branch
`sprint/stable-staker-v2`, whose **merge-base with `master` is exactly `f929b5b`**: this audit's
HEAD, and the branch point of that worktree.

**What this means for grading.** The `dev` closure audited here is the **PRE-080 state**. Story
080's changes — the `StableStakerV2`/`Antimatter` address surface, the `antimatter/` remapping, the
`wagmi.config.ts` repoint, the `verify-stable-staker.sh` repair — are **not on master at
`f929b5b`** and were correctly excluded from the closure. Master carries the *preparatory* steps
(the `antimatter` submodule, the `StableStaker` → `StableStakerV1` retype in `DeployMocks`) without
the story that governs them.

**Story 080 is evidence, not a suppression.** It independently documents the three cluster breakages
this audit verified, as **pre-existing facts at `f929b5b`**:

> - **`wagmi.config.ts:75` is already broken.** It lists `'StableStaker.sol/StableStaker.json'`, but
>   the only compiled artifact is `out/StableStakerV1.sol/StableStakerV1.json` — there is no
>   `out/StableStaker.sol/`. The `stableStakerAbi` currently in `hooks/generated.ts` is a frozen
>   leftover carrying the V1 constructor shape, and a `wagmi generate` today would silently drop the
>   export. (line 170)

> - **`npm run test:stable-staker` is already broken.** `verify-stable-staker.sh` lines 56 and 67
>   invoke `script/interactions/StakeStableStaker.s.sol` and
>   `script/interactions/ClaimWithdrawStableStaker.s.sol`; both files moved to
>   `script/archives/interactions/`. (line 171)

> - **`foundry.lock` is stale** — it pins `lib/stable-staker` at `f5f6039`, disagreeing with the
>   actual `cf8de27`, and has no `lib/antimatter` entry. (line 173)

The grading consequence is stated plainly: **the breakages are real at the audited commit and are
reported as findings of this run.** A story that exists on an unmerged branch and *plans* to repair
them does not fix them on master, and is not grounds for suppression — it is corroboration that
they were **known**. Had story 080 been merged, these would be graded against its acceptance
criteria instead; it is not, so they are graded as they stand at `f929b5b`.

One consequence runs the other way and is disclosed: story 080's own *Autonomous Decision 7* shows
that a literal path repair inside `script/archives/` is **unachievable** while
`skip = ["script/archives/**"]` stands, because `forge script` answers `Error: Could not find target
contract`. That reinforces run-28 `L-03` rather than excusing it.

---

## Law-1 override check

**No story's own intended behaviour would introduce an exploit.** Law 1 does not override Law 2
anywhere in this run, and there is no unsafe story to flag.

Checked explicitly, against the story documents themselves rather than their commit subjects:

- **Story 079** (`complete`) — introduces `LOCAL_PROMO_KENDU` and the armed/dormant legs on the
  local 31337 chain, and *adds* a terminal residual-privilege sweep that revokes the deployer's
  phUSD mint grant. Its intent is safety-increasing; it explicitly forbids weakening
  `_armLocalKenduPromotion`'s four post-condition `require`s or moving its call site (line 534).
  Nothing in it, implemented faithfully, creates an exploitable state.
- **Story 075** (`auto-complete`) — adds a **read-only** `promotion-ready:verify` entry point. It
  mutates no state and closes an outcome-verification gap. Safety-increasing.
- **Story 076** (`complete`) — mandates *"No `startPromotion` call anywhere"* on the mainnet cutover:
  the conservative, dormant day-one shape. Safety-increasing.
- **Story 080** (`auto-complete`, unmerged) — a local-chain V1→V2 cutover rehearsal on 31337. It
  moves no submodule pin, touches no `src/` contract, and its Antimatter minting rights are granted
  on locally deployed mocks. No mainnet reach.

The three deviations reported here are **process and faithfulness deviations, not malicious acts**.
Law 3 applies as written: the owner is assumed non-malicious, and nothing in this document is a
"malicious owner could…" vector. Every deviation above is an unstoried or contradicted change whose
consequence is non-obvious to a competent, non-malicious operator — which is exactly why it is
surfaced rather than suppressed.

---

## Combined remediation ordering

1. **F-02 first, or simultaneously with F-01.** Ungate `_seedNudgeStream` (or hoist the
   fee-on-transfer `require` out of it into an unconditional check) so the probe runs on both legs.
2. **Then F-01.** Delete `LOCAL_PROMO_KENDU=true` from the `dev` key; add `dev:dormant` if an
   explicit second key is wanted. Do **not** do this step first — on its own it arms F-02.
3. **Hold ledger `L-03` `12bcca3b617c…` at `fix-pending`** until both legs are reachable and the
   dormant leg has been booted at least once. Run-27's propose-fixed is withdrawn.
4. **F-03 is not closed by 1–3.** Retro-write acceptance criteria for the OZ pin, the archives sweep
   and the `package.json` purge; decide explicitly whether `promotion-ready:verify` is restored or
   story 075 is superseded; merge `sprint/stable-staker-v2` or revert the story-080 code from
   master; restore `[story-NNN]` commit tagging.

**No ledger status was changed by this document.** All dispositions above are proposals, to be
applied — if at all — through `/ledger phoenix-phase-2-staging …`.
