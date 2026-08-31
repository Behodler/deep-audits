# Spec Conformance — Law 2 (Story Faithfulness) · stable-staker run-15

- **Project:** `stable-staker` · **HEAD:** `2146428` · **Baseline:** `8856781` (run-14) · **Branch:** `master`
- **Run:** `stable-staker-15` · **Report dir:** `reports/stable-staker/15/`
- **Stories in range `8856781..2146428`:** `story-019` (state `complete`), `story-020` (state `auto-complete`), `story-021` (state `auto-complete`)
- **Story documents** (external, read-only — `~/code/product-owner/stories/stable-staker/`):
  - `complete/stable-staker-version-pivot/019-pivot-to-frozen-v1-and-evergreen-v2.md`
  - `auto-complete/stable-staker-version-pivot/020-self-heal-migration-divergence-and-count-buffer.md`
  - `auto-complete/stable-staker-version-pivot/021-cross-version-migrator-preflight-guards.md`

**This file is separate from the QA bundle by design.** A story/spec deviation is never buried in QA noise.
All three findings below also appear in `qa-report.md` **in addition to**, never instead of, their entry here.

**Verdict: 3 faithfulness deviations, all QA/Low tier. No Law-1 override triggered.** Story-020's *intended*
behaviour was examined independently of the code and found safe (see §F-03, "Law-1 override analysis").

| ID | Story | Run label | issueId | Fingerprint | Severity |
|---|---|---|---|---|---|
| **F-01** | story-021 | `L-02` (`DEDUP-15-04`) | `ss14l6` | `7cdb92fdc7…` *(existing entry, narrowed in place — no new fingerprint)* | Low |
| **F-02** | story-019 | `Q-02` (`DEDUP-15-08`) | `ss15q2` | `7c99f37444…` | QA |
| **F-03** | story-020 | `Q-03` (`DEDUP-15-09`) | `ss15q3` | `e5b8c1f715…` | QA |

---

## F-01 — story-021: the phUSD-minter precondition is left unguarded on a stated reason that is false, and the leg that actually bites is a different one

- **Finding:** `DEDUP-15-04` · run label **L-02** · **issueId `ss14l6`** · fingerprint `7cdb92fdc71a660c…` (unchanged)
- **Location:** [`src/CrossVersionMigrator.sol#L33-L61`](https://github.com/Behodler/stable-staker/blob/master/src/CrossVersionMigrator.sol#L33-L61) (NatSpec §C) and [`#L145-L150`](https://github.com/Behodler/stable-staker/blob/master/src/CrossVersionMigrator.sol#L145-L150) (guards)
- **Severity:** Low · **Law:** 2 · **Security escalation:** no · **Ledger action:** *narrow in place, do not close, do not mint a new fingerprint*

### What the story says

> "every precondition a runbook is currently trusted to satisfy must be either self-healed or **asserted on chain before the irreversible step**. A correctly ordered runbook should be a convenience, never a load-bearing safety mechanism."
>
> — story-021, *Governing principle*

And its own carve-out:

> "**The phUSD-minter precondition is not checkable from here.** Section (C)'s third requirement — the destination must be an authorized phUSD minter — lives on the `FlaxToken`, not on either staker, **and this contract holds no reference to it**. It stays a runbook item."
>
> — story-021, *Technical Details*

### What the code actually does

Two of the section-(C) preconditions are asserted on chain (`_isRegisteredOn`, `_migratorOf`) plus the
constructor aliasing guard — all correct, and correctly documented as advisory-on-probe-failure. The third is
unguarded, and the in-source NatSpec as amended by `2146428` repeats the story's word: it calls the precondition
"unguarded and **uncheckable from here**".

**"Uncheckable from here" is factually false at HEAD, and it is false specifically by the story's own technique.**
Verified in source this run:

- `IFlax public immutable phUSD;` is **public on both staker shapes** — `src/versions/v1/StableStakerV1.sol:90`
  **and** `src/StableStakerV2.sol:60` — exactly like `migrator()` and `getStakedTokens()`, so the same
  `staticcall` probe pattern already shipped reaches it with **zero** widening of `IStableStakerMigratable` and
  no import of `FlaxToken`.
- `FlaxToken` exposes `authorizedMinters(address) → MinterInfo{bool canMint, uint256 mintVersion}`
  (`lib/flax-token/src/FlaxToken.sol:100`) and `mintVersion()` as external views.
- A two-hop probe — `newStaker.phUSD()` → `flax.authorizedMinters(newStaker).canMint && .mintVersion == flax.mintVersion()`
  — is therefore constructible under the identical advisory-on-probe-failure policy the story already designed and shipped.

**Aggravator:** `FlaxToken.revokeAllMintPrivileges()` bumps the global `mintVersion` without touching `canMint`,
so a runbook step performed correctly weeks earlier can be silently void at initiate time. Only an
at-call-time on-chain check catches that — which is exactly the failure class this story's governing principle
exists to eliminate.

### The deviation, correctly attributed

The story's own reason for the carve-out does not hold, so the carve-out is unsupported. Per this repo's
standing rule, a falsely-exhaustive in-source claim **carries no suppression authority and raises severity
rather than lowering it**.

**But the consequence is materially smaller than the original faithfulness draft stated, and the correction is
recorded here rather than quietly dropped.** The draft claimed the minter precondition "surfaces only at the
first `depositFor` — i.e. **after** the source pool is already frozen". That is **struck**:
`StableStakerV2._settle` mints only `if (user.amount > 0)`, and a migrating user's destination position is
fresh, so `depositFor` mints nothing and **does not require the destination to be an authorized minter at all**.
Authorization is first needed at a later `claim`/`stake`/`withdraw` on the destination, by which time
`FlaxToken.setMinter` (plain `onlyOwner`, unconstrained by the frozen source) has been available throughout.
The **minter leg is a documentation defect only**.

**The leg that actually bites post-freeze is a different one — the destination POOL STATE.** `depositFor`
carries `require(poolState[token] == PoolState.Active, "StableStaker: pool not active")`, so a destination
already in `Migrating` reverts every `depositFor` in the **second** owner transaction, after the source has
been frozen. That is the timing trap, and it is unasserted.

### Impact and recommendation

Recoverable: the source sits in `Migrating` with emissions frozen while the owner fixes the destination, and
`userMigrate` remains a permissionless self-exit for every user throughout. No assets at risk → **Low**.

Assert `poolState == Active` on the destination before the irreversible step, and either add the two-hop minter
probe or amend §C to say "unguarded" **without** "uncheckable".

---

## F-02 — story-019: the frozen-file gate names an override CI does not implement, skips silently on some hosts, and misses the bypass that works

- **Finding:** `DEDUP-15-08` · run label **Q-02** · **issueId `ss15q2`** · fingerprint `7c99f3744421c61f026ad4e71fadad982f5b96389d739198bff5d08afe95184a`
- **Location:** [`.github/scripts/check-migration-surface.sh#L100-L113`](https://github.com/Behodler/stable-staker/blob/master/.github/scripts/check-migration-surface.sh#L100-L113) and [`#L118-L145`](https://github.com/Behodler/stable-staker/blob/master/.github/scripts/check-migration-surface.sh#L118-L145); echoed at `src/versions/README.md:72`
- **Severity:** QA · **Law:** 2 · **Security escalation:** no

### What the story says

> "Close `ss14l3` / `L-03` in that script: assert `src/versions/v1/StableStakerV1.sol` and
> `src/versions/v1/IStableStakerV1.sol` exist, and verify both against pinned `sha256` values held in
> `src/versions/v1/FROZEN.sha256`. **A missing file or a hash mismatch is a hard failure** naming
> `GOLDEN-RULE-OVERRIDE` as the only deliberate way past it."
>
> — story-019, *Checklist*

> "store expected `sha256sum` values in a pinned manifest (e.g. `src/versions/v1/FROZEN.sha256`) that the script
> verifies. A mismatch is a hard failure with a message naming **`GOLDEN-RULE-OVERRIDE` as the only deliberate
> way past it**."
>
> — story-019, *Technical Details — "Golden-rule enforcement, and the gap this restructure widens"*

### What the code actually does

Existence is asserted unconditionally — that half is correct. Content verification is not, in three separate ways.

**Instance 1 — the hash check skips with `status` untouched (`:100-113`).**

```bash
elif ! command -v sha256sum >/dev/null 2>&1; then
  echo "note: sha256sum unavailable; skipping the frozen-file hash verification." >&2
else
```

On any host without GNU `sha256sum`, an **edited** frozen V1 passes the gate **green** with a `note:` on stderr.
The story specified a hard failure; the implementation delivers a hard failure *or* a silent skip depending on
the host toolchain. This is precisely the shape of the defect `ss14l3` closed — "zero snapshots used to be a
mere `note:`" — reintroduced one layer down.

**Instance 2 — the named override is unimplemented in this layer (`:118-145`).** The gate prints, verbatim:

> "The ONLY deliberate way past this gate is a commit message carrying GOLDEN-RULE-OVERRIDE"

`check-migration-surface.sh` **never reads a commit message**; it ends `exit $status`, unconditionally. The
`GOLDEN-RULE-OVERRIDE` marker is implemented only in `.claude/hooks/protect-migration-surface.sh:39` — and
story-019's own Technical Details records that this hook "does not fire at all when the repo is driven as a
submodule from a product-owner worktree, **which is the normal case**". Verified independently: that hook
contains no reference to `FROZEN`, `sha256`, or `versions/v1` at all, so it has **never** protected frozen
*content* under any invocation.

**Instance 3 — an unnamed bypass does exist and passes green.** Editing a frozen file **and** regenerating
`FROZEN.sha256` in the same change satisfies every check: the `manifest_count != 2` guard rejects only an
emptied or extended manifest, never a **re-pinned** one. The gate's own prose says "Do NOT regenerate
FROZEN.sha256 to match an edit — that defeats the entire check", and nothing enforces it.

### The deviation

The implementation is faithful to the story's *literal* instruction (the story asked for that message). The
Law-2 defect is that the delivered guarantee is narrower than the guarantee the banner states: the named
override does not exist here, an unnamed one does, and on a host without `sha256sum` the check does not run at
all. An agent or developer told "the gate pins the frozen copy" will not discover that a same-commit re-pin is
invisible.

**Not suppressed by the disclosed known gap.** CLAUDE.md's explicit **"Known gap"** (derivable item N7) is
scoped to enforcement **layer 2** (the `PreToolUse` hook). This finding is about **layer 3**, the CI script — of
which the same document claims *"No blind spot about which directory an agent was driven from."*

### Impact and recommendation

Nothing on chain changes; this is defence-in-depth over deliberately frozen files → **QA**. CI (`ubuntu-latest`)
has `sha256sum` and the gate currently exits 0, so the deployed gate is intact; the exposure is the
local / pre-commit path the story itself directs developers at.

Either (a) make the CI gate honour a `GOLDEN-RULE-OVERRIDE` commit-message marker, or (b) rewrite the banner to
say what is true — the gate has no override, and the manifest is only as trustworthy as review of changes to
`FROZEN.sha256` itself. The cheap structural fix is adding `src/versions/v1/FROZEN.sha256` to a
CODEOWNERS / required-review path. Separately, set `status` on the `sha256sum`-absent branch.

**Disclosure / reconciliation.** Instance 2's first half substantially overlaps open QA ledger entry
`c8218865da` (*"CLAUDE.md's description of golden-rule enforcement layer 1 over-states what the hook does"*) —
the same false claim, restated in the script banner rather than in `CLAUDE.md`. It is **reconciled against**
that entry, not double-filed. The `sha256sum`-absent skip and the same-commit re-pin bypass are genuinely new.
Adjacent but distinct: `9abbb7b146` (`ss14l3`, the gate's blindness to *deletion*) — not merged.

**Standing dependency:** this gate is the *sole* enforcement of the invariant "V1 must never gain a
`STAKER_VERSION` getter", on which parked `MR-15-03` rests.

---

## F-03 — story-020: the compensating control that bounds its revert→silent-write-down conversion was never scheduled

- **Finding:** `DEDUP-15-09` · run label **Q-03** · **issueId `ss15q3`** · fingerprint `e5b8c1f715c004ce91a44e09a5ad0618e353c15c33eea4a3870702b99ea5533e`
- **Location:** [`src/StableStakerV2.sol`](https://github.com/Behodler/stable-staker/blob/master/src/StableStakerV2.sol) :: `initiateMigration` / `setYieldStrategy`
- **Severity:** QA · **Law:** 2 · **Security escalation:** no

### What the story says

> "**The self-heal makes a previously loud failure silent.** A divergence from an unknown cause — not the known
> sweep — will now be relinquished without anyone being asked. That is the owner's explicit decision, and
> `PrincipalDivergence` is the compensating control. **It is only a control if someone watches it**: the
> monitoring rule is to sum `ProtocolPrincipalSwept.credited` per token since the last `PoolReset`, and page
> when a `PrincipalDivergence.booked` exceeds that sum. **Nobody owns that alert yet.**"
>
> — story-020, *Concerns* (restated in its Review Results, "Issues Found" #1)

### What the code actually does — the on-chain half is faithful, line for line

Verified against the story's Technical Details:

- `PrincipalDivergence(token, P, booked, booked)` is emitted **unconditionally**, *before* the `booked > 0` guard;
- the `strategy == address(0)` short-circuit survives;
- the relinquish — not the event — carries the guard;
- the byte-identical `"StableStaker: incomplete exit"` post-check is retained;
- `setYieldStrategy` now captures `deposit`'s previously-discarded return and emits
  `ProtocolPrincipalSwept(token, strategy, idleBalance, credited)`, with the sweep behaviour unchanged.

**There is no code deviation.** What is missing is the **off-chain half the story itself names as the thing that
makes the new silence safe**: no alert, no owner, no follow-on story.

### The deviation

The story converts a fail-closed revert into a fail-open self-heal and bounds that conversion **solely** by an
alerting rule it specifies in prose and does not schedule. **The bound is therefore currently vacuous.**
Story-020's own machine triage graded this gap **`[medium]`** and the story **auto-completed anyway**, so no
human ratification step existed at which it would have become a follow-on story (see NOTE-2 below).

**Second instance — the surviving tripwire has no conforming-strategy coverage.** The sole test proving the
`"incomplete exit"` post-check still trips, `test_postCheck_incompleteExitReverts`, depends on
`UnderRealizingStrategy.relinquishPrincipal` being a **no-op stub** (`test/Migration.t.sol:845`) — the tripwire
is exercised only by a mock that deliberately violates the base contract. This is faithful to story-020 (which
declares the narrowing openly rather than hiding it) and is **not itself a deviation**, but it is recorded here
under this project's standing precedent that a no-op mock stub can fake a permanence result.

### Law-1 override analysis — story-020's intent was tested and is SAFE

Law 1 overrides Law 2, so the story's intended behaviour was examined independently of whether the code matches
it. Hypothesis: `initiateMigration` unconditionally relinquishing whatever the strategy still books — with the
story explicitly forbidding a bound (*"Do not add a `maxDivergenceBps` bound and do not add a revert path.
Decision recorded by the owner on 2026-08-29"*) — could silently write down principal users still have a claim on.

**Refuted against the real dependency.** `AYieldStrategy._withdrawInternal`
(`lib/reflax-yield-vault/src/AYieldStrategy.sol:732-752`) caps the request at `clientBalances[token][holder]`
**before** disposing shares and then decrements by the **requested (capped)** amount:

```solidity
// Decrement by the REQUESTED (capped) amount, not what was received — shortfall accrues as yield.
clientBalances[token][balanceHolder] -= amount;
```

So after `_routeExit(token, P, false)` the residual `booked` is exactly `max(0, priorPrincipal − P)` — the
`setYieldStrategy` sweep excess and third-party donations booked to the staker, i.e. **protocol money by the
empty-pool gate** — and nothing else. An under-realizing, underwater or illiquid strategy leaves `booked == 0`,
so the self-heal cannot reach a user-claimable balance. **No security escalation. Filed under Law 2.**

### Recommendation

Raise the monitoring story. The events needed are already emitted and the rule is already written down verbatim
in story-020's Concerns. Add conforming-strategy coverage for the `"incomplete exit"` tripwire.

---

## NOTE-2 — `auto-complete` is an unenumerated story state, and it is load-bearing for two of the three stories

`CLAUDE.md`'s `storyPolicy` enumerates `complete | incomplete | review | archive`. **Stories 020 and 021 sit in
`auto-complete/`.** The state folder is metadata, not a filter, so both were read in full and treated as fully
in scope — but the state changes the strength of the Law-2 baseline:

- Both carry `**Approved by**: story-batch workflow (machine approval — not human-reviewed)`.
- Both ran `--inline-delegation` and self-declare `Independence: reduced — these verdicts were reached by the
  agent that also performed the work`.
- **Story-020 auto-completed while carrying its own `[medium]`** non-blocking finding — which is F-03 above. A
  human ratification step is exactly where that would normally have been converted into a follow-on story.

Story-019, by contrast, was moved to `complete/` by a human `/set-complete` on 2026-08-29. Precedent exists in
this project's history (run-14: "stories 015–018 are machine-approved").

**Recommendation: register `auto-complete` in `registered-projects.json` → `storyPolicy`** so the enumeration
stops under-describing the tree, and treat a machine-approved story's carried-forward `[medium]` as an **open**
item rather than a closed one. Recorded as a process item in `manual-review.json` (`NOTE-2`); it is not a code
finding.

## NOTE-3 — nothing landed without a story

Every path in `8856781..2146428` maps to story-019, story-020 or story-021. The two files beyond story-019's
File Locations table (`CLAUDE.md`, `.claude/hooks/README.md`) are authorized by its Autonomous Decision 8;
`foundry.toml` matches its Build-profile section; all 12 test files are named in the three checklists.
**No un-storied behaviour.**

## Verified — NOT deviations (recorded so they are not re-derived as findings)

- **Story-020's "count the set-aside buffer in `R`" means the same buffer the code counts (B2).** The story
  defines the object as the on-contract idle balance; the code counts `IERC20(token).balanceOf(address(this))`
  capped at `P` — B2 in its entirety. B1 (`setAsideBufferSize`/`setAsideBufferRecipient`, a dial on the
  *strategy*) and B3 (`InPlaceMigrator`'s parked surplus) are different objects. No B1/B2/B3 mismatch exists.
  *(B1's silent dependency is a separate Low, `L-05`/`DEDUP-15-07` — not a story deviation.)*
- **Story-019's freeze fidelity.** `git show c3ec65b:src/StableStaker.sol` vs `src/versions/v1/StableStakerV1.sol`
  diverges only by the frozen header block and the two rename lines — exactly the story's "Permitted
  divergences" — and `sha256sum -c src/versions/v1/FROZEN.sha256` passes for both files. The preserved defects
  `ss14m1` / `ss14l8` are intact in V1 and fixed only in V2, as the story requires.
- **Story-021 does not over-claim closure.** Neither the story nor the shipped NatSpec claims total closure; the
  fail-open `staticcall` probes are a deliberate, documented version-agnosticism trade, and `_migratorOf`'s
  `probed` flag correctly prevents a failed probe masquerading as a definitive `address(0)`. The only over-claim
  is the word "uncheckable" — F-01.
- **Story-019's `foundry.toml` change.** `code_size_limit = 100000` under `[profile.default]` matches the
  story's Build-profile block in intent and rationale; the over-limit `forge build --sizes` output is
  deliberate and must not be filed.

## NOTE-4 — hygiene

`GOLDEN-RULE-OVERRIDE` appears verbatim in commit `21a7cef`, which did **not** retire V1 (recorded and judged
acceptable by story-019's own Decision 11). Any future tooling that greps history for the marker will get a
false positive. Interacts with F-02: the override channel is both unimplemented in CI and now polluted in
history. Parked in `manual-review.json`.
