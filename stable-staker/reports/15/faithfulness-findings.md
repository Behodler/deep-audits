# Story-Faithfulness Findings — stable-staker run-15 (Law 2)

- **Range:** `8856781..2146428` on `master` (submodule HEAD `2146428bdd9adb1fbaf1c1feaa4fbf36133e5506`)
- **Scanned:** 2026-08-29 · regression mode · scanType `story-faithfulness`
- **Stories checked:** `story-019` (state `complete`), `story-020` (state `auto-complete`), `story-021` (state `auto-complete`)
- **Authority for structure:** `/home/justin/code/audits/reports/stable-staker/15/contract-profiles.md`
- **Verdict:** 4 faithfulness findings (all Low / QA-tier). **No Law-1 override triggered** — story-020's self-heal intent was tested for fail-open harm and the hypothesis was refuted against the real dependency (see §Law-1 analysis).

Story documents (read in full, read-only):

| Story | Document | State |
|---|---|---|
| 019 | `/home/justin/code/product-owner/stories/stable-staker/complete/stable-staker-version-pivot/019-pivot-to-frozen-v1-and-evergreen-v2.md` | `complete` (human `/set-complete`) |
| 020 | `/home/justin/code/product-owner/stories/stable-staker/auto-complete/stable-staker-version-pivot/020-self-heal-migration-divergence-and-count-buffer.md` | `auto-complete` (machine approval) |
| 021 | `/home/justin/code/product-owner/stories/stable-staker/auto-complete/stable-staker-version-pivot/021-cross-version-migrator-preflight-guards.md` | `auto-complete` (machine approval) |

---

## F-01 — story-019: the frozen-V1 hash gate degrades a "hard failure" into an advisory note

- **type:** faithfulness · **faithfulness:** true · **securityEscalation:** false · **lawImpacted:** 2
- **severity:** potential-low (QA) · **confidence:** high
- **file:** `/home/justin/code/audits/lib/stable-staker/.github/scripts/check-migration-surface.sh:100-113`

**specText** (story-019, Checklist):
> "Close `ss14l3` / `L-03` in that script: assert `src/versions/v1/StableStakerV1.sol` and `src/versions/v1/IStableStakerV1.sol` exist, and verify both against pinned `sha256` values held in `src/versions/v1/FROZEN.sha256`. **A missing file or a hash mismatch is a hard failure** naming `GOLDEN-RULE-OVERRIDE` as the only deliberate way past it."

**specSource:** story-019 document, Checklist (and Technical Details: "add a hash check … A mismatch is a hard failure").

**actualBehavior:** Existence is asserted unconditionally (correct). Content verification is not:

```bash
elif ! command -v sha256sum >/dev/null 2>&1; then
  echo "note: sha256sum unavailable; skipping the frozen-file hash verification." >&2
else
```

`status` is untouched on that branch, so on any host without GNU `sha256sum` an **edited** frozen V1 passes the gate green with a `note:` on stderr. That is precisely the shape of the defect `ss14l3` closed (zero snapshots used to be "a mere `note:`") reintroduced one layer down.

**deviation:** The story specifies a hard failure for a hash mismatch; the implementation delivers a hard failure *or* a silent skip depending on the host toolchain. The story's own Review Results already flag the macOS/`shasum` case as non-blocking; the Law-2 point is that the checklist criterion said "hard failure" and the code chose "skip".

**Why Low, not Medium:** the CI job runs on `ubuntu-latest` where `sha256sum` is present (verified: the gate exits 0 with `ok: frozen V1 files match their pinned sha256 values`), so the deployed gate is currently intact. The exposure is the local/pre-commit path the story itself points developers at.

---

## F-02 — story-019: the gate's own banner names an override CI does not implement, and misses the bypass that works

- **type:** faithfulness (falsely-exhaustive in-source claim) · **faithfulness:** true · **securityEscalation:** false · **lawImpacted:** 2
- **severity:** potential-low (QA / operational hazard, Law-3 footgun) · **confidence:** high
- **file:** `/home/justin/code/audits/lib/stable-staker/.github/scripts/check-migration-surface.sh:118-145`; echoed at `src/versions/README.md:72`

**specText** (story-019, Technical Details):
> "store expected `sha256sum` values in a pinned manifest (e.g. `src/versions/v1/FROZEN.sha256`) that the script verifies. A mismatch is a hard failure with a message naming **`GOLDEN-RULE-OVERRIDE` as the only deliberate way past it**."

**specSource:** story-019 document, "Golden-rule enforcement, and the gap this restructure widens".

**actualBehavior:** The gate prints, verbatim:
> "The ONLY deliberate way past this gate is a commit message carrying GOLDEN-RULE-OVERRIDE"

Both halves of that sentence are false in the environment the gate actually runs in:

1. **The named override does not exist in this layer.** `check-migration-surface.sh` never reads a commit message; it ends `exit $status` unconditionally. The `GOLDEN-RULE-OVERRIDE` marker is implemented only in `.claude/hooks/protect-migration-surface.sh:39` — and story-019's own Technical Details records that this hook "does not fire at all when the repo is driven as a submodule from a product-owner worktree, **which is the normal case**". Confirmed independently: the hook contains no reference to `FROZEN`, `sha256`, or `versions/v1` at all, so it has never protected frozen *content* under any invocation.
2. **An unnamed bypass does exist and passes green.** Editing a frozen file *and* regenerating `FROZEN.sha256` in the same change satisfies every check: the `manifest_count != 2` guard rejects only an emptied or extended manifest, never a re-pinned one. The gate's prose says "Do NOT regenerate FROZEN.sha256 to match an edit — that defeats the entire check", but nothing enforces it.

**deviation:** The implementation is faithful to the story's literal instruction (the story asked for that message). The Law-2 defect is that the story's own claim — "the only deliberate way past it" — is untrue as delivered, so the message misdescribes the protection to the next reader. Per this repo's standing rule, an in-source claim that is falsely exhaustive carries no suppression authority and is itself reportable: an agent told "the gate pins the frozen copy" will not discover that a same-commit re-pin is invisible.

**Recommended:** either (a) make the CI gate itself honour a `GOLDEN-RULE-OVERRIDE` commit-message marker, or (b) rewrite the banner to say what is true — the gate has no override, and the manifest is only as trustworthy as review of changes to `FROZEN.sha256` itself. Adding `src/versions/v1/FROZEN.sha256` to a CODEOWNERS/required-review path is the cheap structural fix.

---

## F-03 — story-021: the phUSD-minter precondition is left unguarded on a stated reason that does not hold

- **type:** faithfulness · **faithfulness:** true · **securityEscalation:** false · **lawImpacted:** 2
- **severity:** potential-low (operational hazard / Law-3 footgun) · **confidence:** high
- **contract:** `src/CrossVersionMigrator.sol` · **function:** `initiateMigration` · **lines:** 145-150 (guards), 33-61 (NatSpec §C)

**specText** (story-021, "Governing principle"):
> "every precondition a runbook is currently trusted to satisfy must be either self-healed or **asserted on chain before the irreversible step**. A correctly ordered runbook should be a convenience, never a load-bearing safety mechanism."

**specText** (story-021, Technical Details — the carve-out):
> "**The phUSD-minter precondition is not checkable from here.** Section (C)'s third requirement — the destination must be an authorized phUSD minter — lives on the `FlaxToken`, not on either staker, **and this contract holds no reference to it**. It stays a runbook item."

**specSource:** story-021 document.

**actualBehavior:** Two of three §(C) preconditions are asserted on chain (`_isRegisteredOn`, `_migratorOf`) plus the constructor aliasing guard — all correct and correctly documented as advisory-on-probe-failure. The third is unguarded, and the in-source NatSpec as amended by `2146428` calls it "unguarded and **uncheckable from here**".

**deviation:** "Uncheckable from here" is factually wrong, and it is wrong specifically by the story's own technique. Verified at HEAD:

- `IFlax public immutable phUSD;` — `src/versions/v1/StableStakerV1.sol:90` **and** `src/StableStakerV2.sol:60`. It is public on both shapes, exactly like `migrator()` and `getStakedTokens()`, so the same `staticcall` probe pattern reaches it with **zero** widening of `IStableStakerMigratable` and no import of `FlaxToken`.
- `FlaxToken` exposes `authorizedMinters(address) → MinterInfo{bool canMint, uint256 mintVersion}` (`lib/flax-token/src/FlaxToken.sol:100`) and `mintVersion()` as external views.
- A two-hop probe — `newStaker.phUSD()` → `flax.authorizedMinters(newStaker).canMint && .mintVersion == flax.mintVersion()` — is therefore constructible under the identical advisory-on-probe-failure policy the story already designed and shipped.

So the *one* precondition left unguarded is the one whose failure is most expensive: it surfaces only at the first `depositFor` — i.e. **after** the source pool is already frozen, decoupled and latched to `Migrating`.

**Aggravating (and the reason a runbook tick is not equivalent):** `FlaxToken.revokeAllMintPrivileges()` bumps the global `mintVersion`, silently invalidating a previously-authorized minter without touching its `canMint` flag. A runbook step performed correctly weeks earlier can therefore be void at initiate time; only an at-call-time on-chain check catches that, which is exactly the failure class this story's governing principle exists to eliminate.

**Why Low, not Medium:** recovery is straightforward and loses no funds. `migrate` is atomic, so a failing mint reverts the whole batch; the source sits in `Migrating` with emissions frozen while the owner calls `setMinter` on the destination and retries, and users retain the independent `userMigrate` self-exit throughout. This is a non-obvious owner footgun (in scope under Law 3), not a value-at-risk finding.

---

## F-04 — story-020: the compensating control the story relies on to bound its fail-open conversion does not exist

- **type:** faithfulness (unsatisfied acceptance condition) · **faithfulness:** true · **securityEscalation:** false · **lawImpacted:** 2
- **severity:** potential-low (operational hazard) · **confidence:** high
- **contract:** `src/StableStakerV2.sol` · **function:** `initiateMigration` / `setYieldStrategy`

**specText** (story-020, Concerns):
> "**The self-heal makes a previously loud failure silent.** A divergence from an unknown cause — not the known sweep — will now be relinquished without anyone being asked. That is the owner's explicit decision, and `PrincipalDivergence` is the compensating control. **It is only a control if someone watches it**: the monitoring rule is to sum `ProtocolPrincipalSwept.credited` per token since the last `PoolReset`, and page when a `PrincipalDivergence.booked` exceeds that sum. **Nobody owns that alert yet.**"

**specSource:** story-020 document, Concerns; restated in its Review Results ("Issues Found" #1) and carried into its `## Auto-Completed` block as a **`[medium]`** non-blocking finding.

**actualBehavior:** The on-chain half is implemented exactly as specified and verified line by line — `PrincipalDivergence(token, P, booked, booked)` is emitted unconditionally *before* the `booked > 0` guard, the `strategy == address(0)` short-circuit survives, the relinquish (not the event) carries the guard, the byte-identical `"StableStaker: incomplete exit"` post-check is retained, and `setYieldStrategy` now captures `deposit`'s previously-discarded return and emits `ProtocolPrincipalSwept(token, strategy, idleBalance, credited)` with the sweep behaviour unchanged. **The code is faithful.** What is missing is the off-chain half the story names as the thing that makes the silence safe: no alert, no owner, and no follow-on story.

**deviation:** The story converts a fail-closed revert into a fail-open self-heal and bounds that conversion *solely* by an alerting rule it specifies in prose and does not schedule. The bound is currently vacuous, and the story's own machine triage graded the gap `[medium]` and auto-completed anyway (see NOTE-2). Filed under Law 2 rather than Law 1 because the harm hypothesis was tested and refuted — see below.

**Recommended:** raise the monitoring story. The events needed are all emitted; the rule is already written down verbatim in story-020's Concerns.

---

## Law-1 override analysis — story-020's intent was tested and is SAFE

Law 1 overrides Law 2, so story-020's *intended* behaviour was examined independently of whether the code matches it. The specific hypothesis: `initiateMigration` unconditionally relinquishing whatever the strategy still books (`if (booked > 0) strategy.relinquishPrincipal(token, booked);`, with the story explicitly forbidding a bound — *"Do not add a `maxDivergenceBps` bound and do not add a revert path. Decision recorded by the owner on 2026-08-29"*) could silently write down principal that users still have a claim on, whenever the strategy fails to return tokens rather than merely holding excess.

**Refuted against the real dependency.** `AYieldStrategy._withdrawInternal` (`/home/justin/code/audits/lib/reflax-yield-vault/src/AYieldStrategy.sol:732-752`) caps the request at `clientBalances[token][holder]` **before** disposing shares and then decrements by the **requested (capped)** amount:

```solidity
// Decrement by the REQUESTED (capped) amount, not what was received — shortfall accrues as yield.
clientBalances[token][balanceHolder] -= amount;
```

Therefore after `_routeExit(token, P, false)` the residual `booked` is exactly `max(0, priorPrincipal − P)` — the `setYieldStrategy` sweep excess and third-party donations booked to the staker, i.e. protocol money by the empty-pool gate — and **nothing else**. An under-realizing, underwater or illiquid strategy leaves `booked == 0`, so the self-heal cannot reach a user-claimable balance; that shortfall surfaces where it always did, as `R < P` socialized uniformly through the immutable `(R,P)` snapshot. `_relinquishInternal` additionally caps at the client balance and moves no vault shares. **No security escalation; story-020's intent is safe as written.**

**NOTE-1 (watch item, manual-review channel).** A genuine erosion survives, correctly declared by the story rather than hidden by it: the `"incomplete exit"` post-check is no longer a tripwire for a strategy that fails to *return tokens*, only for one whose `relinquishPrincipal` fails to *write principal down*. The sole test proving it still trips, `test_postCheck_incompleteExitReverts`, depends on `UnderRealizingStrategy.relinquishPrincipal` being a **no-op stub** (`test/Migration.t.sol:845`) — the surviving tripwire is exercised only by a mock that deliberately violates the base contract, and has no coverage against a conforming strategy. This is faithful to story-020 ("it still catches a strategy whose relinquish does not actually write the principal down") and is **not** a deviation, but it is flagged given this project's standing precedent that a no-op mock stub can fake a permanence result.

---

## Verified — NOT a deviation

**Story-020's "count the set-aside buffer in `R`" means the same buffer the code counted (B2).** The parent brief asked specifically whether a B1/B2/B3 mismatch exists here. It does not. The story's Background defines the object unambiguously as the on-contract idle balance — *"`setYieldStrategy` sweeps the contract's whole idle balance … that idle balance is protocol money by construction — set-aside buffer, dust, donations"* and *"idle balance already sitting on the staker is subtracted straight back out"* — which is **B2** in the profile's disambiguation. The code counts `IERC20(token).balanceOf(address(this))` capped at `P`: B2 in its entirety. Residual terminology hazard only, recorded so a future reader does not re-derive a false mismatch: B1 (`setAsideBufferSize` / `setAsideBufferRecipient`, a percentage dial on the *strategy*) reaches the staker at all only if `setAsideBufferRecipient == staker`, which nothing on chain asserts; and B3 (`InPlaceMigrator`'s parked surplus) lives on a different contract entirely and is untouched. The code is a strict superset of the story's intent, so there is no Law-2 gap.

**Story-019's freeze fidelity.** `git show c3ec65b:src/StableStaker.sol` vs `src/versions/v1/StableStakerV1.sol` diverges only by the frozen header block and the two rename lines — exactly the "Permitted divergences" the story enumerates — and `sha256sum -c src/versions/v1/FROZEN.sha256` passes for both files (gate re-run this session, exit 0). The preserved defects `ss14m1` / `ss14l8` are intact in V1 and fixed only in V2, as the story requires ("They must remain present and unfixed in the frozen V1 — that is the whole point").

**Story-021 does not over-claim closure.** Despite the commit subject "Close the one-way door", neither the story nor the shipped NatSpec claims total closure: the story's Concerns state "the guard is a safety net for the known shapes, not a total one", and §(C)/ADVISORY-ON-PROBE-FAILURE in the contract says the same in the source. The fail-open `staticcall` probes are a deliberate, documented, version-agnosticism trade, and `_migratorOf`'s explicit `probed` flag correctly prevents a failed probe masquerading as a definitive `address(0)` — which is what the story mandated. The only over-claim is the word "uncheckable", covered by F-03.

**Story-019's `foundry.toml` change.** `code_size_limit = 100000` under `[profile.default]` matches the story's Build-profile block in intent and rationale; the over-limit `forge build --sizes` output is deliberate and must not be filed.

---

## NOTE-2 — `auto-complete` is an unenumerated state, and it is load-bearing here

`CLAUDE.md` enumerates `complete | incomplete | review | archive`. Stories 020 and 021 sit in **`auto-complete/`**. Treated as metadata and fully in scope, per the state-folder rule. It is worth surfacing because it changes the strength of the Law-2 baseline for two of the three stories:

- Both carry `**Approved by**: story-batch workflow (machine approval — **not human-reviewed**)`.
- Both ran `--inline-delegation` and self-declare `Independence: reduced — these verdicts were reached by the agent that also performed the work`.
- Story-020 auto-completed while carrying its own **`[medium]`** non-blocking finding (the unowned alert) — which is F-04. A human ratification step is exactly where that would normally have been converted into a follow-on story.

Story-019, by contrast, was moved to `complete/` by a human `/set-complete` on 2026-08-29. Precedent exists in this project's history (run-14: "stories 015-018 are machine-approved"). **Recommendation:** register `auto-complete` in `registered-projects.json` → `storyPolicy` so the enumeration stops under-describing the tree, and treat a machine-approved story's carried-forward `[medium]` as an open item rather than a closed one.

## NOTE-3 — nothing landed without a story

Every path in `8856781..2146428` maps to 019/020/021. The two files beyond story-019's File Locations table (`CLAUDE.md`, `.claude/hooks/README.md`) are authorized by its Autonomous Decision 8; `foundry.toml` matches its Build-profile section; all 12 test files are named in the three checklists. No un-storied behaviour.

## NOTE-4 — `GOLDEN-RULE-OVERRIDE` appears verbatim in commit `21a7cef`

Recorded by story-019's own Decision 11 and judged acceptable there (the marker was described, not invoked; the hook did not fire; the triad declaration counts rose 4→5, 2→3, 2→3, so the rename cannot read as a deletion). Not a deviation. Carried only as a hygiene note: the repo's history now contains the escape-hatch marker on a commit that did **not** retire V1, so any future tooling that greps history for the marker will get a false positive. Interacts with F-02 — the override channel is both unimplemented in CI and now polluted in history.
