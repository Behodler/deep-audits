# Spec Conformance (Law 2) — stable-staker run-16

Scan type: story-faithfulness | Source: `lib/stable-staker` @ `fa06de5` | Range `2146428..fa06de5`

**Stories checked:** story-022, story-023, story-024.

**State-folder note.** All three resolve to `~/code/product-owner/stories/stable-staker/auto-complete/`,
i.e. closed out — but `auto-complete` is *machine* approval, not human review. Each carries an
explicit `**Approved by**: story-batch workflow (machine approval — not human-reviewed)` stamp.
Stories 023 and 024 were auto-completed on a review status of **`ISSUES_FOUND`**, triaged
non-blocking by the same automated workflow. Only story-022 closed on `PASSED`. Every review in
all three ran `--inline-delegation` with self-declared "Independence: reduced". The acceptance
criteria below are therefore treated as authoritative *text*, but their sign-off carries no
independent-human weight.

---

## story-022 — Defer reward payout to explicit claim

**Verdict: implemented, with one stated criterion not achieved on one path (F-01).**

Mechanically the story landed item-for-item. Verified at `fa06de5`:

| Story requirement | Landed |
|---|---|
| standalone `mapping(...) public unclaimedReward` beside `userInfo`, not a 3rd `UserInfo` field | `src/StableStakerV2.sol:96` |
| `_settle` takes `token`, books instead of minting | `:832-839` — `unclaimedReward[token][account] += pending;`, no mint |
| `withdraw` books | `:362` |
| `claim` pays `unclaimed + pending`, zeroes slot, emits combined, revert string unchanged | `:379-386` — `require(owed > 0, "StableStaker: nothing to claim")`, `antimatter.mint(msg.sender, owed)` |
| `emergencyWithdraw` zeroes the backlog | `:404` |
| `_exitPosition` pays `pending + unclaimed`, zeroes **before** the mint, emits combined | `:611-621` — zero at `:615`, mint at `:620`, `emit MigratedOut(token, account, credit, owed)` |
| `_pendingReward` internal helper, no `this.` self-call | `:740`, `:745`; `pendingReward` delegates at `:731` |
| `claimableReward = unclaimed + projection` | `:739-741` |
| neither name added to `IStableStaker` / `IStableStakerMigratable` | confirmed; `git diff 2146428 fa06de5 -- src/interfaces/IStableStaker.sol` empty |
| `src/versions/v1/**` untouched | `git diff 2146428 fa06de5 -- src/versions/` shows only the new `vendor/` files + README (story-024) |

Exactly two `antimatter.mint(` sites remain (`:385`, `:620`), down from four. The `amt == 0`
early-return in `_exitPosition` (`:598-601`) preserves a fully-withdrawn user's backlog rather
than confiscating it — a deviation from checklist box *"Verify both `batchMigrate` and
`userMigrate` exits leave `unclaimedReward` at zero"*, but one the story itself sanctions in
Autonomous Decision 3. Faithful. (Its safety argument does not survive story-023 — see F-03.)

---

### F-01 — story-022's headline robustness criterion is not met on the migration exit, and the docs state it unconditionally

- **type:** faithfulness (with security escalation — hands off to LOCAL-002)
- **storyTag:** story-022
- **severity:** potential-medium
- **contract/function:** `src/StableStakerV2.sol` — `_exitPosition`
- **line:** 620 (range 598-621); interacts with `:397`, `:347`
- **lawImpacted:** 2, escalating to 1
- **confidence:** high

**specText** (story-022, Story Overview, verbatim):

> "After this change the principal paths never call phUSD at all, so phUSD availability can never
> trap or degrade principal handling."

and, from the same story's Tests section, the criterion it calls *"the headline win, assert
explicitly"*:

> "**Robustness (the headline win, assert explicitly)**: with the staker's phUSD minter role
> revoked, `stake`, `withdraw` and `emergencyWithdraw` all still succeed, and only `claim` reverts."

**specSource:** `~/code/product-owner/stories/stable-staker/auto-complete/stable-staker-no-auto-claim/022-defer-reward-payout-to-claim.md` lines 16 and 240.

**actualBehavior.** `_exitPosition` still mints:

```solidity
// src/StableStakerV2.sol:619-621
if (owed > 0) {
    antimatter.mint(account, owed);
}
```

and it is the **only** principal exit while `poolState == PoolState.Migrating`:

```solidity
// src/StableStakerV2.sol:397   (emergencyWithdraw)
require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
// src/StableStakerV2.sol:347   (withdraw) — same Active gate
```

`_exitPosition` is reached only from `batchMigrate` and `userMigrate`. If the reward token reverts
mid-migration — a de-approved minter, a paused or upgraded token, any revert — both exits revert,
and `finalizeAndReset` cannot rescue the pool because it requires `stakerCount == 0 && totalStaked == 0`.
100% of the pool's principal is trapped with no hatch.

**deviation.** The story lists two requirements that are mutually inconsistent: (a) *principal paths
never call the reward token*, and (b) call-site change 5, *"`_exitPosition` (578–602) — pay
`pending + unclaimedReward[token][account]`, zeroing the unclaimed slot before the mint"*. Since
`_exitPosition` is a principal path — the sole one during Migrating — (b) contradicts (a). The
implementation faithfully executed (b) and silently dropped (a) for that path. The story's own test
list encodes the gap: the robustness test enumerates `stake`, `withdraw`, `emergencyWithdraw` and
stops, and the terminal-migration bullet asserts payment, never survival-under-revert. Nothing in
the story or the suite exercises "migration exit with the minter revoked".

**Adjudication (asked explicitly): this is BOTH an unimplemented story requirement AND documentation
that overstates what shipped — and the documentation half is the aggravating factor, not the
mitigating one.** The unqualified guarantee shipped into two places:

```
lib/stable-staker/CLAUDE.md:12-13
  "That is deliberate robustness: a revoked minter role, or any Antimatter revert, can no longer
   brick a principal path."

lib/stable-staker/docs/deferred-reward-accrual-plan.md:37-38
  "The principal paths now never call the reward token at all, so its availability can neither
   trap nor degrade principal handling."
```

Both are stated as absolutes with no migration carve-out, and the in-source NatSpec repeats it at
`src/StableStakerV2.sol:830-831` ("Never calls Antimatter, so a revoked minter role cannot brick
the principal paths that reach here") — true of `_settle` in isolation, but read as a whole-contract
property by anyone skimming. Per repo policy, an in-repo doc asserting its own exhaustiveness carries
**no suppression authority** and **raises** severity: a future operator reading CLAUDE.md:12-13 will
believe revoking the staker's minter role during an incident is principal-safe, and during a
migration it is not.

**Recommended remedy** (the story's own shape, applied consistently): make `_exitPosition` book
rather than mint — `unclaimedReward[token][account] = owed;` with principal paid unconditionally —
or wrap the mint so a revert cannot block the exit. Either way, correct CLAUDE.md:12-13 and
plan §2 to name the migration exit as the one path that still calls the reward token.

---

## story-023 — Antimatter emissions token for V2

**Verdict: implementation faithful; the STORY is unsafe under Law 1 by omission (F-02).**

Mechanical conformance is complete. `src/interfaces/IAntimatter.sol` exists with `mint` and nothing
else; `src/StableStakerV2.sol` holds `IAntimatter public immutable antimatter;` and mints at `:385`
and `:620`; `phusdPerSecond`/`accPhusdPerShare`/`phUSDPerDay` are renamed; `src/versions/v1/*.sol`
is byte-unchanged; `grep -rn -i "flax\|phusd" src/ --include=*.sol` outside `src/versions/` returns
only comments in `CrossVersionMigrator.sol:36,56`, the explanatory NatSpec in `IAntimatter.sol:8`,
and the incidental `reflax-yield-vault` import at `StableStakerV2.sol:12`. The `annihilate`
prohibition holds: `grep -rn "annihilate\|setPhUSD\|setPhUSDMinter" src/` → no hits. The
`IStableStakerMigratable.sol` change is the single sanctioned comment on line 47.

### F-02 — story-023 swaps the emissions token to one with a permissionless redemption path and is silent on the consequence; it also launders story-022's token-specific risk conclusion into a token-agnostic one

- **type:** story-unsafe
- **securityEscalation:** true
- **storyTag:** story-023 (regressing story-022)
- **severity:** potential-medium — routed to econ-scanner for impact sizing, not asserted as High here
- **contract:** `src/StableStakerV2.sol` (emissions leg); premise in `lib/antimatter/src/Antimatter.sol:226-267`
- **lawImpacted:** 1 (overriding 2)
- **confidence:** high (on the omission; the *magnitude* is econ-scanner's call)

**Answering the question directly: the story does NOT acknowledge the consequence. It is silent, and
that silence is the finding.**

`grep -n -i "dilut\|unbacked\|backing\|peg\|redeem\|redemption\|liabilit"` over the full story
document returns **two hits, neither of them the point**: line 207 (`annihilate` burns the caller's
own balance) and line 237 (a naming convention). There is no assessment anywhere in the story of
what emitting a redeemable bearer token costs the protocol.

The story frames the swap as a mechanical type change:

> "`function mint(address to, uint256 amount) external onlyApprovedMinters { _mint(to, amount); }` —
> signature **identical** to `IFlax.mint`, so the two call sites need only a type change."
> — story-023 line 66-67

Against the profiler's established premise (`Antimatter.context.md`; `lib/antimatter/src/Antimatter.sol:226-267`):
`annihilate` is permissionless, AM is a plain uncapped freely-transferable OZ ERC20, and `:263`
mints the AM half as **phUSD with no stablecoin behind it**. So each emitted AM is a bearer claim
on ~1e18 unbacked phUSD, realisable by any third party. phUSD's "authorized minter, no user
redemption path" property — the thing that made over-crediting economically inert — is gone. The
story never states this, never bounds it, and never re-derives the emission cap in economic terms.
`antimatterPerDay` remains owner-set and unbounded (`StableStakerV2.sol:214-218`).

**Two aggravating specifics, both quotable:**

1. **The story asserts there is no hole, in the one place it discusses `annihilate` at all.**
   > "Reinforcing fact worth recording: `annihilate` burns `msg.sender`'s **own** balance and
   > consults no allowance, so a staking contract holding an allowance over a user could not
   > annihilate on that user's behalf regardless. **The prohibition is about scope discipline, not
   > about closing a hole.**" — story-023 lines 207-209

   That refutes a vector nobody raised (staker-annihilates-on-user's-behalf) and, having done so,
   declares the area clear. The actual exposure is the reverse direction: the *recipient* of
   emissions annihilates their own AM, exactly as designed. The story's only other `annihilate`
   mention frames the residual risk as cosmetic:
   > "**Emissions dust**: … odd-wei emission amounts become unannihilatable dust for holders.
   > **Recorded for downstream awareness ONLY.**" — lines 341-345

   A falsely-narrow scoping statement of this kind carries no suppression authority.

2. **It silently invalidated story-022's risk assessment and rewrote the words to hide the fact.**
   Story-022 line 41 recorded, deliberately, in phUSD terms:
   > "Known downside carried deliberately: deferral builds an unbounded off-schedule mint liability
   > realisable all at once. That is a **phUSD peg / market-depth** concern, not a solvency one."

   Story-023's docs pass rewrote that sentence in place. `git diff 045d13c 2d609cb -- docs/deferred-reward-accrual-plan.md`:
   ```diff
   -realisable all at once. That is a phUSD peg / market-depth concern, not a solvency one, and is what
   +realisable all at once. That is a reward-token market-depth concern, not a solvency one, and is what
   ```
   The **subject** was substituted; the **conclusion** ("not a solvency one") was preserved
   untouched. But that conclusion followed *from* phUSD's properties. Under Antimatter it does not:
   the deferred `unclaimedReward` backlog is now an unbounded, uncapped claim that converts 1:1 into
   unbacked phUSD on demand. The live text at `docs/deferred-reward-accrual-plan.md:126-129` now
   asserts a solvency-safety conclusion that no story ever re-derived for the token it names.

**Law-3 footgun rider.** Two owner-facing consequences follow that neither story states and a
competent non-malicious owner would be surprised by: (i) an `antimatterPerDay` rate calibrated
under the phUSD premise is now a phUSD dilution rate; (ii) story-023 line 338-340 records that
Antimatter has **no `mintVersion` mass revocation** — "per-minter `setApprovedMinter(x, false)` is
the only revocation" — so incident response must enumerate minters, and, per F-01, doing so
mid-migration bricks the pool.

**Not a finding, to be explicit (Law 3):** choosing Antimatter as V2's reward token is the owner's
design decision and is trusted. What is reported is that the story making the swap recorded no
consequence analysis, and that its doc edit converted a token-specific safety conclusion into a
token-agnostic one without re-deriving it.

**Downstream handoff.** Every ledger suppression whose stated rationale is "the reward token has no
redemption value / over-crediting the minter is opportunity cost, not loss" must be **re-derived,
not carried forward**, for StableStakerV2 at `fa06de5`. Frozen V1 (still phUSD) is unaffected.

---

### F-03 — story-022's "nothing is stranded" argument depends on an assumption story-023 removed

- **type:** faithfulness (cross-story regression) / operational hazard
- **storyTag:** story-022 (Autonomous Decision 3), regressed by story-023
- **severity:** potential-low
- **contract/function:** `src/StableStakerV2.sol` — `_exitPosition` (`:598-601`), `claim` (`:375`)
- **lawImpacted:** 2, with a Law-3 footgun component
- **confidence:** high

**specText** (story-022, Autonomous Decision 3, verbatim):

> "Kept the early return unchanged … **`claim` remains open to them** — it is `poolExists`-gated but
> not `PoolState`-gated, and `finalizeAndReset` does not clear `unclaimedReward` — so **nothing is
> stranded**."

confirmed by the reviewer at story-022 line 457-459 and carried into the auto-complete triage as a
[low] "the chosen path works".

**actualBehavior.** The code matches: `_exitPosition:598-601` returns before zeroing, so a
fully-withdrawn user's backlog survives migration, and `claim:375` carries no `PoolState` gate.
But `claim:385` calls `antimatter.mint`. The non-strandedness argument therefore has a third,
unstated precondition: **the old staker must remain an approved Antimatter minter, and unpaused,
indefinitely after a cross-version migration**.

**deviation.** Under phUSD that precondition was cheap and the story could reasonably leave it
implicit. Story-023 changed the revocation model and never revisited Decision 3: it records at
lines 338-340 that Antimatter has no `mintVersion` mass revocation and that per-minter
`setApprovedMinter(x, false)` is the only mechanism. De-approving a decommissioned staker after a
completed migration is the obvious, correct-looking hygiene step — and it permanently strands every
residual `unclaimedReward` backlog on that contract, with no on-chain guard and no runbook entry.
This is a non-obvious consequence of an ordinary owner action: footgun, in scope.

**Recommended remedy:** documentation, not code — record in `CLAUDE.md` that a retired staker must
retain its approved-minter status until residual `unclaimedReward` balances are drained, or add a
one-line drain step to the migration runbook. Story-022's own listed alternative ("pay the backlog
before the early return") would also close it but changes `_exitPosition` semantics.

---

## story-024 — Vendor flax-token into frozen V1

**Verdict: the vendoring itself is faithful and exact. One accepted trade-off rests on a false
premise (F-04). The duplicate-artifact hazard is within the story's declared intent (note, not a finding).**

**Asked: did the story require exactly a verbatim vendoring with no behavioural change? Yes,
verbatim, and yes, no behavioural change — and both held.**

> "**Copy the two files VERBATIM** — byte-for-byte, no reformatting, no comment tidying, no pragma
> bumps — apart from a provenance header." — story-024 lines 218-221
>
> "Note the naming oddity to **preserve rather than 'fix'** … Vendor the files as they are; do not
> tidy their comments." — lines 122-126
>
> "**Therefore: the two frozen files stay BYTE-IDENTICAL, and the redirection happens at the
> REMAPPING.**" — lines 69-70

All confirmed at `fa06de5`. The profiler's byte-comparison against `f5300117` holds (header
insertion + trailing newline only, no behavioural difference). The redirection is at the remapping —
`remappings.txt:3` and `foundry.toml` both read `flax-token/=src/versions/v1/vendor/`, so no import
site changed; `git diff 2d609cb..fa06de5 -- test/` is empty. `FROZEN.sha256` retains exactly its two
original lines and `git diff 2146428 fa06de5 -- src/versions/` shows no change to
`StableStakerV1.sol` or `IStableStakerV1.sol`. The header sits below the SPDX+pragma, matching the
in-repo `StableStakerV1.sol` precedent. No behavioural change: the vendored `FlaxToken` retains
`mintVersion` authorization, `revokeAllMintPrivileges`, allowance-gated `burn`, and
`("Phoenix USD","phUSD")`.

### F-04 — the vendored pair is the compile-time definition of the frozen V1's imports and is protected by no gate; the story declined to pin it on a premise that is factually wrong

- **type:** invariant-violation (weakens a documented project invariant) / faithfulness
- **storyTag:** story-024
- **severity:** potential-low (QA / integrity-of-controls; no live-value path)
- **contract:** `src/versions/v1/vendor/IFlax.sol`, `src/versions/v1/vendor/FlaxToken.sol`
- **lawImpacted:** 2
- **confidence:** high

**specText** (story-024, Technical Details, stated as settled and non-negotiable):

> "**The vendored copies MUST NOT be added to `src/versions/v1/FROZEN.sha256`.** This is not a
> trade-off to weigh; it is a hard constraint.
>
> `.github/scripts/check-migration-surface.sh` asserts that the manifest holds **exactly two
> entries** (`manifest_count == 2`) and fails loudly if the manifest grows. Adding
> `vendor/IFlax.sol` and `vendor/FlaxToken.sol` to it breaks CI outright."
> — lines 156-162
>
> "The vendored files are ordinary tracked source. They are protected by review and by the fact that
> V1 is frozen, not by a hash pin." — lines 171-172

**actualBehavior.** The premise is false. The gate is first-party and the "2" is not a constant —
it is `${#FROZEN_FILES[@]}`, the length of a hard-coded array two lines above it:

```bash
# .github/scripts/check-migration-surface.sh:88
FROZEN_FILES=(src/versions/v1/StableStakerV1.sol src/versions/v1/IStableStakerV1.sol)
...
# :103-105
manifest_count=$(grep -cvE '^\s*(#|$)' "$FROZEN_MANIFEST" || true)
if (( manifest_count != ${#FROZEN_FILES[@]} )); then
  fail "$FROZEN_MANIFEST pins $manifest_count file(s); expected ${#FROZEN_FILES[@]}."
```

Adding the two vendored paths to both the array and the manifest keeps the check green — a two-line
edit to a script this repo owns. There was no CI obstacle; the story mistook a self-imposed
tooling parameter for an immovable constraint, and reached a real design conclusion on it while
explicitly forbidding anyone from re-weighing it ("not a trade-off to weigh").

**deviation.** The consequence is a genuine reduction in the frozen-surface guarantee that the
story's own purpose depends on. After this change, `src/versions/v1/StableStakerV1.sol` is
hash-pinned, but the `IFlax` **it compiles against** is not — the frozen V1's compiled behaviour
can now be altered by editing an unpinned sibling file inside the same directory, with every gate
still green. Before story-024 that surface was a submodule gitlink (pinned by `.gitmodules` +
`foundry.lock` + git's own object hashing); after, it is loose tracked source with no pin at all.
`src/versions/README.md` itself frames the coupling as the thing being managed:

> "External types that *must* be imported (`IYieldStrategy`, `IFlax`) are a known coupling: if those
> submodule interfaces change shape, the frozen files inherit the churn." — quoted at story-024 lines 76-78

**Compounding: the story's stated second line of defence does not exist.** Story-024 lines 65-66
(echoed in story-023) claim:

> "Those hashes are verified by `.github/scripts/check-migration-surface.sh` (check 4) and **edits are
> blocked at edit time by the `PreToolUse` hook `.claude/hooks/protect-migration-surface.sh`**."

The hook does no such thing. Its entire guard is the three golden-rule declarations —
`PROTECTED=(initiateMigration batchMigrate depositFor)` at `.claude/hooks/protect-migration-surface.sh:38`,
used at `:155`, `:177` and `:236`. `grep -n "src/versions" ` over that file returns only two prose
comments (`:22`, `:67`); there is no path-based deny for `src/versions/v1/`. So the frozen pair has
**one** gate (CI), not two, and the vendored pair — the story's residual protection being "review" —
has **zero**.

**Recommended remedy:** append both vendored paths to `FROZEN_FILES` and to `FROZEN.sha256` (the
check then passes at 4 == 4), or add a CI assertion that the vendored copies equal the `@phUSD/`
copies. Separately, correct the two stories' claim about what the `PreToolUse` hook enforces.

---

### Note (adjudicated: WITHIN story intent — not a finding)

**Duplicate `FlaxToken` artifact in the build** (profiler LOCAL-V01). `flax-token/` resolves to
`src/versions/v1/vendor/` while `@phUSD/` resolves to `lib/antimatter/lib/flax-token-v2/src/`
(`remappings.txt:3` and `:7`); both are `f5300117` today, so `forge build` emits two same-named
`FlaxToken` artifacts, and an `lib/antimatter` bump drifts them apart unchecked.

**This is within the story's declared intent and is therefore not filed as a Law-2 deviation.**
Story-024 scopes it out twice, explicitly and with human sign-off:

> "**Scope is stable-staker's OWN direct dependency list, not the transitive tree.** … Whatever
> arrives underneath `lib/antimatter/` is antimatter's business and is explicitly **NOT** a concern
> for this story." — lines 19-22
>
> "**Transitive reappearance of flax-token-v2 under `lib/antimatter/` is explicitly OUT OF SCOPE**
> and accepted by the human. Do not chase it." — lines 338-339

Under Law 3 that is a trusted, obvious-consequence scoping decision, not a footgun. Note also that
for the frozen V1 the pinned vendored copy is the *desired* outcome — it is precisely the churn
insulation `src/versions/README.md` wanted. The residual — artifact-name ambiguity for
`vm.getCode("FlaxToken.sol")` and silent divergence — is a build-hygiene item for **qa-bundler**,
carried as LOCAL-V01, not a story deviation. The pin gap that *is* reportable is F-04, which
concerns the absence of any hash pin on the vendored pair, not the existence of the duplicate.

---

## Carried observations (no finding)

- **story-023 public ABI break** — `phUSD()` → `antimatter()`, `phUSDPerDay` → `antimatterPerDay`,
  constructor arg `IFlax` → `IAntimatter`. Deliberate, V2-only, recorded in the story's Decision 6;
  every downstream consumer is explicitly out of scope. Auto-complete carried it forward as
  [medium]: `reflax-mint/phase-2-staging` breaks on its next `lib/stable-staker` pin bump. Relevant
  to `/audit-script` on phStaging, not a defect here.
- **`MigratedOut.reward` semantics** — now `pending + unclaimed`. Specified by story-022 and flagged
  in its Concerns; off-chain consumers read a different number. Faithful, recorded.
- **story-023 commit `2d609cb`** spells the literal sentinel `GOLDEN-RULE-OVERRIDE` in its body,
  which `protect-migration-surface.sh` substring-matches. Self-reported, no harm (gate green,
  migration surface unchanged). Noted because it makes future commit-message auditing unreliable.
- **story-024 stale git-module dir** (58 MB under the worktree's `.git/worktrees/.../modules/`)
  despite a ticked box. Local-only, invisible to a fresh clone. Self-reported.

## Handoffs

| To | Item |
|---|---|
| code-scanner | F-01 — confirm the mid-migration principal trap (profiler LOCAL-002); severity by impact |
| econ-scanner | F-02 — size the AM→unbacked-phUSD dilution; **re-derive, do not carry forward**, every suppression resting on "reward token has no redemption value" |
| sanitizer | F-02 invalidates the ledger/memory premises `minter-cushion-socialized-losses-intended` and `externally-derived-yield-opportunity-cost-not-loss` **for V2 only**; frozen V1 unaffected |
| qa-bundler | F-03 (runbook), F-04 (CI pin), LOCAL-V01 (duplicate artifact) |
