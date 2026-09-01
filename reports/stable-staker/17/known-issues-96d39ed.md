# stable-staker — known-issues re-extraction at HEAD `96d39ed`

- **Submodule HEAD:** `96d39ed4c3eab5e77f9ce2a18034432f793ca46c` (branch `master`, tree clean)
- **Declared source:** `lib/stable-staker/CLAUDE.md` (520 lines at HEAD)
- **Prior extraction:** 9 items, `2026-06-01`
- **This extraction:** `2026-09-01`
- **Diff range that invalidated the cache:** `fa06de5..96d39ed` — `CLAUDE.md` +128 lines (purely
  additive in this range; the story-025 claim-gate / `autoAnnihilate` block, lines 86–203)
- **No dedicated known-issues file exists.** `lib/stable-staker/known-issues.md` is absent;
  `README.md` is a generic Foundry template. `CLAUDE.md` is the only declared source.

> Read-only: nothing under `lib/` was modified during this extraction.

---

## 1. Derived list at HEAD (verbatim, with file:line)

All citations are `lib/stable-staker/CLAUDE.md:<line>` unless stated otherwise.

### Emission / accounting

**N1 — Core emission-cap invariant.** `CLAUDE.md:71-77`
> "No sequence of user actions can **accrue** more than `antimatterPerDay` for a token over any
> window, and cumulative *minted* is always `<=` cumulative *accrued*. The only writer of
> `accAntimatterPerShare` is `_updatePool`, which folds in exactly `elapsed * antimatterPerSecond`
> per update"

**N2 — Dust rounds down; empty windows and flash staking earn nothing.** `CLAUDE.md:75-77`
> "the sum of all stakers' pending increase equals that minus integer-division dust (which always
> rounds DOWN). Empty-pool windows accrue nothing; flash staking earns nothing;"

**N3 — Rate change settles at the old rate first.** `CLAUDE.md:76-77`
> "`antimatterPerDay` settles the pool at the old rate before changing it."

**N4 — Deferred booking (story 022): the backlog is forfeitable and pausable.** `CLAUDE.md:30-34`
> "- `emergencyWithdraw` forfeits the `unclaimedReward` backlog as well as the live pending — the
>   escape hatch stays the single rule "no reward, principal out", and never mints.
> - `claim` is still `whenNotPaused`, so a pause now withholds the accumulated backlog too."

Supporting invariant restatement, `CLAUDE.md:79-82`:
> "The statement carrying the invariant is `sum(unclaimedReward) + minted <= cap`."

### Yield-strategy custody

**N5 — Yield stays protocol-owned.** `CLAUDE.md:248-252`
> "**Yield stays protocol-owned.** Stakers only ever get their *principal* back plus Antimatter
> emissions. … the farm never reads `totalBalanceOf` to credit a user. Accrued yield accumulates
> inside the strategy as protocol-owned surplus (skimmed elsewhere via the strategy's
> `skimSurplus`)."

**N6 — Exits forward actual received, accounting debits requested.** `CLAUDE.md:243-246`
> "Exits forward the **actual received** amount (balance delta), while internal principal accounting
> is decremented by the **requested** amount — sub-amount differences remain protocol-owned
> yield/loss (consistent with `ERC4626YieldStrategy`'s rounding rule)."
>
> **NARROWED at HEAD** — `autoAnnihilate` no longer follows this blanket rule; see N18/N26.

**N7 — Underwater withdraw block.** `CLAUDE.md:254-260`
> "While a token's strategy is underwater, `withdraw` reverts (`StableStaker: strategy underwater`)
> so a non-migrating user cannot be forced to realise a loss. `emergencyWithdraw` and
> `initiateMigration` are **not** blocked by the underwater guard — they accept the haircut so the
> escape hatch and migrations always work."

**N8 — `setYieldStrategy` is an empty-pool-only operation.** `CLAUDE.md:240`
> "**`setYieldStrategy` reverts (`"StableStaker: pool not empty"`) unless `totalStaked == 0`** —
> strategy (un)wiring is an empty-pool-only operation. To change strategy on a live pool, drain it
> to empty via the terminal migration runbook … and then wire the fresh strategy on the revived
> empty pool."

### Migration

**N9 — Terminal migration is terminal; no resume path.** `CLAUDE.md:270-273`
> "Migration is terminal: once engaged a token's pool can never resume healthy operation (no resume
> path), and `stake` / `withdraw` / `emergencyWithdraw` / the old staker's `depositFor` are blocked
> while `active` to preserve the snapshot."

**N10 — `CrossVersionMigrator` does not compensate the underwater haircut.** `CLAUDE.md:285-289`
> "Only `InPlaceMigrator` makes users whole after an underwater exit … `CrossVersionMigrator`
> deliberately does NOT carry that logic — a cross-version migration through an underwater strategy
> credits the uniform snapshot haircut. That asymmetry is a real product difference and wants a
> human decision before a cross-version migration is run on a live, underwater user base."

**N11 — Frozen V1 defects are deliberately preserved (explicit triage instruction).**
`CLAUDE.md:412-418`
> "Its known defects — `ss14m1` (terminal migration bricked by `setYieldStrategy`'s unrecorded idle
> sweep) and `ss14l8` (set-aside buffer excluded from the migration realized amount `R`) — are
> preserved **deliberately**. … An audit that re-files those two findings against `src/versions/`
> should be triaged as "deliberately preserved", not actioned."

**N12 — Frozen V1 emits phUSD permanently.** `CLAUDE.md:16-18`
> "The byte-frozen `src/versions/v1/StableStakerV1.sol` emits **phUSD** and always will — the live
> mainnet V1 instance is deployed and unpatchable, so that is correct and permanent, not an
> oversight."

**N13 — V1 has no `STAKER_VERSION`; a typed probe reverts.** `CLAUDE.md:434-440`
> "Because V1 has no `STAKER_VERSION` getter, **a static call to it reverts**. Any code that probes
> a staker's version must treat a revert as "version 1" … the frozen `StableStakerV1.sol` must
> **never gain a `STAKER_VERSION` getter**"

**N14 — Removed `StableStakerMigrator` leaves sibling repo files uncompilable, deliberately.**
`CLAUDE.md:308-312`
> "Known fallout, deliberately left unrepaired and tracked as a cross-repo follow-up: in the sibling
> `reflax-mint/phase-2-staging` repo, `script/DeployTempStableStakerAndMigrators.s.sol` and
> `test/YsSwapMigrationHardening.t.sol` import the deleted contract and no longer compile."

**N15 — Migration-surface hook has a known gap.** `CLAUDE.md:353-354`
> "**Known gap**: a hook only fires when `stable-staker` is the session's project root, and this
> repo is normally driven as a submodule"

### Claim gate and `autoAnnihilate` (story 025 — all NEW)

**N16 — `claimEnabled` is false on deployment; `autoAnnihilate` is the only reward path while down.**
`CLAUDE.md:88-97`
> "`claim()` is gated by an owner-settable `claimEnabled` flag and is **false on deployment**.
> While it is down, `autoAnnihilate(address token, uint256 minPhUSDOut)` is the reward path … This
> is a **teaching phase, not a permanent design**."

**N17 — Sub-unit dust stays in `unclaimedReward`.** `CLAUDE.md:109-111`
> "**Sub-unit dust** left by that flooring stays in `unclaimedReward` — not minted, not transferred.
> It accrues to the next call, so it is neither stranded nor a dust-sized bypass of a closed gate,
> and it rounds in the protocol's favour."

**N18 — The exit floor carries a rounding allowance only.** `CLAUDE.md:133-142`
> "**The floor carries a ROUNDING allowance, and only a rounding allowance**
> (`EXIT_ROUNDING_ALLOWANCE` = 2 raw units, plus `EXIT_ROUNDING_ALLOWANCE_BPS` = 1 bp). … One basis
> point is far below any real haircut, so a genuinely short delivery — or a preview lying to widen
> the raw-mint path around the closed `claim` — still reverts."

**N19 — The idle buffer is never the payer *on a solvent strategy*; the underwater path is the
carve-out.** `CLAUDE.md:143-156`
> "**The idle buffer is never the payer** *on a solvent strategy*. … The carve-out is the
> **underwater** path … when `_isUnderwater` is true, `_routeExit` pays the whole request out of the
> idle balance plus `relinquishPrincipal` and returns the nominal amount without measuring anything.
> That is the buffer doing exactly the job it exists for, and it is deliberate — see "idle balance is
> automatically buffer" above — but it means "the buffer is untouched" is a statement about the
> normal path, not an invariant of every call."
>
> **DANGLING CROSS-REFERENCE.** The section "idle balance is automatically buffer" that this
> carve-out cites as its justification **does not exist anywhere in `CLAUDE.md` at HEAD**
> (`grep -n 'idle balance is automatically buffer'` matches only this self-reference at line 155).
> The carve-out's stated authority is therefore unanchored: it asserts a prior justification that
> was never written. See the authority ruling in §4.

**N20 — Self-sandwiching is bounded and accepted.** `CLAUDE.md:162-167`
> "**Self-sandwiching is bounded and accepted.** A worse AMM rate annihilates less and mints more
> raw Antimatter, which is what the closed `claim` exists to prevent — but
> `ERC4626MarketYieldStrategy` enforces its own `minOut` from `slippageToleranceBps` and reverts
> before `autoAnnihilate` sees the proceeds, so the extractable amount is capped at the tolerance and
> costs a real AMM round trip."

**N21 — Registered-stable coupling is an operational precondition.** `CLAUDE.md:170-175`
> "`Antimatter.toStableAmount` reverts `StablecoinNotRegistered` unless the pool token is also
> registered with `PhusdStableMinter`. **Registering a pool token with the stable minter is now part
> of the pool-registration runbook.**"

**N22 — The migration mint is deliberately not gated by `claimEnabled`.** `CLAUDE.md:176-177`
> "**The migration carve-out.** The Antimatter mint inside `_exitPosition` is deliberately **not**
> gated by `claimEnabled`. Gating it would let a closed claim gate brick migration."

**N23 — The two-pause deadlock is an owner operational obligation.** `CLAUDE.md:178-182`
> "**The two-pause deadlock.** `Antimatter.annihilate` is `whenNotPaused` against *Antimatter's* own
> Phoenix pauser, which StableStaker does not control. With `claimEnabled == false`, an
> antimatter-side pause leaves stakers with no reward path at all. The intended response is
> operational, not a code path: **the owner flips `claimEnabled` to true for the duration of any
> antimatter pause.** That is an obligation on whoever holds the StableStaker owner key."

**N24 — Auditor note: annihilation exceeding principal.** `CLAUDE.md:184-203` — quoted verbatim and
ruled on in §4.

**N25 — Decimals are read live, not cached.** `CLAUDE.md:101-108`
> "The scale is read **live** from `IERC20Metadata(token).decimals()` rather than cached at
> `addToken`: a cache would need backfilling … whereas a live read fails closed."

**N26 — The exit preview is advisory and manipulable; the delta is measured.** `CLAUDE.md:127-132`
> "**The preview is advisory only.** It reads live AMM state and is manipulable within a block, and
> it is built on the fee-free `convertToAssets` … so it over-quotes on a fee-charging vault. The real
> balance delta across the exit is therefore **measured**, and a delivery below the pro-rated
> guarantee reverts `"StableStaker: exit shortfall"`. A lying preview must fail the transaction."

---

## 2. Cached-list reconciliation (9 items)

| # | Cached item (abridged) | Verdict at HEAD | Anchor |
|---|---|---|---|
| C1 | Emission-cap invariant, `phUSDPerDay` / `accPhusdPerShare` | **KEPT (drifted)** | N1 `:71-77` |
| C2 | Dust rounds DOWN; empty windows; flash staking | **KEPT** | N2 `:75-77` |
| C3 | `phUSDPerDay` settles at the OLD rate | **KEPT (drifted)** | N3 `:76-77` |
| C4 | Yield stays protocol-owned | **KEPT (drifted)** | N5 `:248-252` |
| C5 | Exits forward actual received; debit requested | **KEPT but NARROWED** | N6 `:243-246`; narrowed by N18/N26 |
| C6 | Underwater withdraw block; `emergencyWithdraw`/`migrateOut` not blocked | **KEPT (drifted)** | N7 `:254-260` |
| C7 | Replacing an in-use strategy does NOT auto-migrate; operator must drain first | **GONE (superseded)** | replaced by N8 `:240` |
| C8 | Owner trust assumptions / centralization by design | **REGISTRY-ONLY** | no anchor in `CLAUDE.md` |
| C9 | Behodler3 pausing; permissionless `emergencyWithdraw` callable even while paused | **KEPT-PARTIAL** — one clause registry-only | N-partial `:43-44` |

### Drift detail (C1, C3, C4, C6)

The cached text is written in the **phUSD** vocabulary. At HEAD the evergreen `StableStakerV2`
emits **Antimatter** (story 023), so `phUSDPerDay` → `antimatterPerDay` and `accPhusdPerShare` →
`accAntimatterPerShare`. The *substance* survives; only the identifiers moved. C6 additionally
names `migrateOut`, which no longer exists — the hook is `initiateMigration` (`:257`).

C1 also **understates the invariant at HEAD**. Since story 022 reward is *booked* rather than
transferred, so "cumulative minted <= cap" alone is no longer the whole statement; `CLAUDE.md:81`
now carries `sum(unclaimedReward) + minted <= cap`. A sanitizer applying the cached wording could
wave through a defect in the *booking* leg. Use N1 + N4, not C1.

### C5 — kept but materially narrowed

C5 states the blanket rule that sub-amount differences "remain protocol-owned yield/loss". At HEAD
`autoAnnihilate` explicitly **does not** work that way: it measures the balance delta and reverts
`"StableStaker: exit shortfall"` below a floor slackened only by 2 raw units + 1 bp (N18, N26), and
over-delivery is forwarded to the caller rather than retained (`:145-147`). C5 therefore still
describes `withdraw` / `emergencyWithdraw` / `initiateMigration` but **must not** be used to
suppress a finding on the `autoAnnihilate` exit path.

### C7 — GONE, and the gap is older than this diff range

The cached item describes an unguarded footgun: an owner *may* replace a live strategy, and is
merely *expected* to drain it first ("documented operational requirement"). At HEAD that is not
possible — `CLAUDE.md:240` documents a hard revert, `"StableStaker: pool not empty"`, unless
`totalStaked == 0`. The hazard the item described cannot occur, so **C7 has lost all suppression
authority**. Note this supersession is **not** in `fa06de5..96d39ed`; the empty-pool gate predates
this range, meaning the 2026-06-01 cache had already been wrong for multiple runs.

Corollary for triage: because the operation is now gated rather than merely discouraged, a finding
about strategy replacement on a live pool is now a finding about **the gate and the migration
runbook that routes around it** (N8, N9, N10), not about the old footgun. Do not silence it with C7.

---

## 3. Provenance check — registry-authored items

Per the standing rule, an item with no anchor in its declared source is **not** a known issue; it is
an unfalsifiable cache entry. Naming them explicitly so re-derivation does not silently drop them.

### C8 — REGISTRY-ONLY (whole item)

> "Owner trust assumptions: owner controls addToken, phUSDPerDay emission budget, setPauser,
> setMigrator, setYieldStrategy - centralization by design. Migrator is a permissioned role
> (migrateOut/depositFor callable only by configured migrator)"

`CLAUDE.md` at HEAD contains **no** occurrence of "centraliz", "owner trust", or "trusted"
(verified by grep), and exactly **one** occurrence of `onlyOwner` (`:225`, on `setYieldStrategy`).
The item's framing — "centralization by design" — is audit-registry prose, not project
documentation. It is preserved verbatim under `knownIssuesRegistryOnly` in the registry.

**Suppression authority: NONE as a project known issue.** It is redundant anyway: the trusted,
non-malicious owner is already Law 3 of the repo hierarchy, which governs regardless of what any
project's `CLAUDE.md` says. Owner *footguns* — the two-pause deadlock (N23), the
`claimEnabled`-flip obligation (N16/N23) — remain in scope as operational hazards and C8 must not
be used to suppress them.

### C9 — KEPT-PARTIAL; one clause is registry-only, and it is now wrong

> "Behodler3 pausing via pauser/IPausable; permissionless emergencyWithdraw escape hatch is callable
> even while paused, by design"

- Derivable half: `CLAUDE.md:43-44` — "Behodler3 pausing (`pauser` + `IPausable`), and a
  permissionless `emergencyWithdraw` escape hatch."
- **Registry-only half:** "callable even while paused, by design". `CLAUDE.md` never states this.
  It happens to be true of the modifier set in source (`src/StableStakerV2.sol:620` —
  `external nonReentrant`, no `whenNotPaused`), but that is derived from *code*, not from the
  declared source, and the registry presents it as documented intent.
- **And it is now incomplete in a way that matters:** at HEAD `emergencyWithdraw` **is** blocked by
  pool state — `src/StableStakerV2.sol:623`,
  `require(poolState[token] == PoolState.Active, "StableStaker: pool not active")`. The escape
  hatch is unconditional with respect to *pausing* but not with respect to *terminal migration*.
  C9's "callable even while paused" must therefore never be generalized to "always callable".

**Suppression authority:** the pausing/permissionless half may suppress; the "even while paused,
by design" clause may suppress a pause-interaction finding **only** where the finding is about
pausing specifically, and never a finding about `emergencyWithdraw` availability during terminal
migration.

---

## 4. Authority ruling — the story-025 "Auditor note"

### Verbatim (`lib/stable-staker/CLAUDE.md:184-203`)

> ### Auditor note — annihilation exceeding principal
>
> When a user's claimable antimatter exceeds their booked principal, the excess cannot be
> annihilated — there is no principal left to annihilate it against. Of the available responses
> (revert, hold the excess indefinitely, force a partial claim), we deliberately choose to **mint
> the excess directly to the user, exactly as a claim would**.
>
> This is a knowing, documented loophole around the disabled `claim()`. We accept it because:
>
> - The alternative — reverting — strands a user whose rewards have outgrown their stake, with no
>   path to their own accrued value. That is a far worse failure than a leak in a temporary
>   teaching gate.
> - The condition requires reward accrual to exceed staked principal, which at realistic emission
>   rates takes a long time relative to how long the gate is intended to stay closed.
> - `claimEnabled` is expected to be flipped on within weeks. The gate is pedagogy, not a security
>   boundary, and should never be relied upon as one.
>
> Auditors should read `claimEnabled` as a UX mechanism with a deliberate escape valve, **not** as
> an access control. Nothing in the protocol's safety argument may depend on antimatter being
> unobtainable while the flag is false.

### Ruling

In-source prose that addresses itself to auditors carries **zero** intrinsic suppression authority.
A doc cannot sanitize a finding by declaring the behaviour acceptable; it can only establish
*intent*. Split accordingly.

**(a) What it MAY legitimately suppress — one thing only.**
It establishes that the raw-mint-on-excess path is **intentional**, not an oversight. It therefore
suppresses a **Law-2 faithfulness** finding of the shape *"`autoAnnihilate` mints Antimatter
directly to the caller when `owed > principal`, apparently bypassing the closed `claim` gate by
accident."* That framing is refuted: the behaviour is documented and chosen. Confirmed in source at
`src/StableStakerV2.sol` — `excessBase = owed - capped` with `capped = min(owed, user.amount * scale)`.

**(b) What it does NOT suppress — everything else, including a Law-1 finding on the same code.**
Intent is not safety. The note's own rationale bullet 2 is **falsely exhaustive**, and under the
standing rule a falsely-exhaustive doc raises severity rather than lowering it:

> "The condition requires reward accrual to exceed staked principal, which at realistic emission
> rates takes a long time"

That argument covers only **organic accrual growing the numerator**. It does not address a caller
**shrinking the denominator**, which is a single ordinary transaction. Since story 022, `withdraw`
*books* the settled reward into `unclaimedReward` rather than paying it (`CLAUDE.md:79-81`), so a
staker may `withdraw` their principal to (or near) zero, carry the full backlog, and then call
`autoAnnihilate`, at which point `capped` collapses to ~0 and `excessBase` is the **entire**
backlog, minted raw to the caller. `require(netWanted > 0 || excessBase > 0, ...)` admits the
`netWanted == 0` case explicitly. The waiting period the note relies on is not required.

The note may not suppress that finding. It is a live Law-1 lead for this run and should be scanned,
not sanitized.

**(c) The note's closing paragraph is self-limiting, and binds in the other direction.**

> "Nothing in the protocol's safety argument may depend on antimatter being unobtainable while the
> flag is false."

This is the project explicitly refusing to let `claimEnabled` serve as a mitigation. Any finding
elsewhere in this run whose severity was going to be discounted *because the claim gate is closed*
must **not** be so discounted. The note removes suppression authority; it does not add it.

**(d) Unverifiable operational assertions suppress nothing.**
"`claimEnabled` is expected to be flipped on within weeks" is a forward-looking operational claim
with no on-chain enforcement — there is no timelock, no auto-open, nothing that makes it true. It
cannot bound the exposure window of any finding.

**(e) Related — N19's dangling cross-reference.**
The underwater buffer carve-out (`:151-156`) justifies itself by pointing at a section, "idle
balance is automatically buffer", that **does not exist in the file**. A carve-out whose stated
authority is absent is undocumented for suppression purposes: N19 may be cited as evidence of
*intent*, but it may not suppress a finding about the underwater path drawing on the shared buffer.

---

## 5. Sanitizer permissions for run 17

**PERMITTED to suppress** (derivable from `CLAUDE.md` at HEAD, in the vocabulary of HEAD):

N1, N2, N3, N4, N5, N7, N8, N9, N10, N11, N12, N13, N14, N15, N16, N17, N18, N20, N21, N22, N23,
N25, N26 — each only within the scope its quoted text actually covers.

**PERMITTED WITH LIMITS:**

- **N6 / C5** — applies to `withdraw` / `emergencyWithdraw` / `initiateMigration` only. **Not** to
  the `autoAnnihilate` exit path.
- **N19** — establishes intent for the underwater buffer carve-out but **may not suppress**: its
  cited justification section does not exist.
- **N24** (auditor note) — suppresses only the Law-2 "unintended bypass" framing. See §4.
- **C9 (partial)** — pausing/permissionless half only; never generalize to "always callable".

**NOT PERMITTED to suppress anything:**

- **C7** — superseded by the `setYieldStrategy` empty-pool gate; the hazard no longer exists.
- **C8** — registry-authored, no anchor in the declared source. Law 3 already covers the trusted
  owner; owner footguns stay in scope.
- **C9's "callable even while paused, by design" clause** — registry-authored, and incomplete at
  HEAD (`PoolState.Active` gate).
- **N24's rationale bullets 2 and 3** — falsely exhaustive / unverifiable.

**Explicitly flagged as a live lead, not suppressible:** the `withdraw`-to-shrink-principal route to
a full raw mint of the `unclaimedReward` backlog around a closed `claim` gate (§4(b)).

---

## 6. Counts

| Bucket | Count |
|---|---|
| Cached items KEPT (incl. vocabulary drift) | 6 (C1–C6) |
| Cached items KEPT-PARTIAL | 1 (C9) |
| Cached items GONE / superseded | 1 (C7) |
| Cached items REGISTRY-ONLY (no anchor in declared source) | 1 whole (C8) + 1 clause (C9) |
| NEW at HEAD | 20 (N4, N8–N26) |
| Total derived at HEAD | 26 (N1–N26) |
