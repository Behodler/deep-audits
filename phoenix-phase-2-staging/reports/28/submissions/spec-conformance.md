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
