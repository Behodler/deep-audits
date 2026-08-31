# Spec Conformance (Law 2) — stable-staker, audit run 16

**Project:** stable-staker · **Commit:** `lib/stable-staker` @ `fa06de5` · **Range:** `2146428..fa06de5`
**Stories in range:** story-022, story-023, story-024
**Deviations filed:** F-01 (Medium-equivalent), F-02 (Medium-equivalent, story-unsafe / Law-1 override), F-03 (Low), F-04 (Low)

This report covers Law-2 faithfulness only: whether the shipped code does what the story it derives
from says it does, and whether the story's own stated intent is itself safe. Findings with asset,
value, or availability impact are reported separately under their own H/M labels; the cross-references
below name them. A faithfulness finding and its security twin are **not** the same finding and are
not collapsed — they have different remedies.

---

## 0. Process observation — the standing of these three stories

This section is recorded first because it is load-bearing context for how much weight a reader
should give the acceptance criteria quoted throughout this report.

All three stories resolve under
`~/code/product-owner/stories/stable-staker/auto-complete/`. `auto-complete` denotes **machine
approval, not human review**. Each story carries an explicit stamp:

> `**Approved by**: story-batch workflow (machine approval — not human-reviewed)`

- **story-022** closed on a review status of `PASSED`.
- **story-023** and **story-024** were auto-completed on a review status of **`ISSUES_FOUND`**,
  which the same automated workflow then triaged as non-blocking.
- Every review across all three ran with `--inline-delegation` and a self-declared
  **"Independence: reduced"**.

The acceptance criteria are therefore treated in this report as authoritative *text* — they are the
specification the code is graded against — but their sign-off carries no independent-human weight.
Two of the four deviations below (F-02, F-04) are defects in the story text itself that a human
reviewer would plausibly have caught.

### Documentation authority, stated once and applied throughout

Per repository policy, **in-source NatSpec and in-repo project documentation carry no suppression
authority**, and documentation that asserts its own exhaustiveness **raises** severity rather than
lowering it: an operator who reads an unqualified safety guarantee will act on it, so a false
guarantee is what converts an avoidable hazard into a non-obvious one. This run contains three
instances, each cited in place below:

1. `lib/stable-staker/CLAUDE.md:12-13` — the unconditional "can no longer brick a principal path"
   claim (F-01).
2. `lib/stable-staker/docs/deferred-reward-accrual-plan.md:126-129` — a solvency-safety conclusion
   preserved verbatim across a token substitution that invalidated its derivation (F-02).
3. `lib/stable-staker/CLAUDE.md:75` — "integer-division dust (which always rounds DOWN)", stated as
   an invariant and disproved by this run's Tier-3 fuzzing by 1 wei.

---

## F-01 — story-022's headline robustness criterion is not met on the migration exit, and the docs state it unconditionally

| | |
|---|---|
| **Severity (faithfulness)** | **Medium-equivalent** |
| **Story** | story-022 — *Defer reward payout to explicit claim* |
| **Law impacted** | 2, escalating to 1 |
| **Location** | `src/StableStakerV2.sol:620` (range 598–621); interacts with `:347`, `:397` |
| **Security twin** | **M-01** — migration-exit mint trap (**PoC passing**). Cross-referenced, not collapsed. |
| **Confidence** | High |

### Story text (verbatim)

From story-022, Story Overview (line 16):

> "After this change the principal paths never call phUSD at all, so phUSD availability can never
> trap or degrade principal handling."

From the same story's Tests section (line 240), the criterion the story itself calls *"the headline
win, assert explicitly"*:

> "**Robustness (the headline win, assert explicitly)**: with the staker's phUSD minter role
> revoked, `stake`, `withdraw` and `emergencyWithdraw` all still succeed, and only `claim` reverts."

**Source:** `~/code/product-owner/stories/stable-staker/auto-complete/stable-staker-no-auto-claim/022-defer-reward-payout-to-claim.md`, lines 16 and 240.

### Actual behaviour

`_exitPosition` still mints:

```solidity
// src/StableStakerV2.sol:598-621
function _exitPosition(address token, address account) internal returns (uint256 credit) {
    UserInfo storage info = userInfo[token][account];
    uint256 amt = info.amount;
    if (amt == 0) {
        return 0;
    }
    ...
    uint256 owed = unclaimedReward[token][account] + pending;

    info.amount = 0;
    info.rewardDebt = 0;
    unclaimedReward[token][account] = 0;
    pool.totalStaked -= amt;
    _stakers[token].remove(account);

    if (owed > 0) {
        antimatter.mint(account, owed);      // <-- :620
    }
    emit MigratedOut(token, account, credit, owed);
```

and it is the **only** principal exit while `poolState == PoolState.Migrating`. Both alternatives are
gated to `Active`:

```solidity
// src/StableStakerV2.sol:347   (withdraw)
require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
// src/StableStakerV2.sol:397   (emergencyWithdraw)
require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
```

`_exitPosition` is reached only from `batchMigrate` and `userMigrate`. If the reward token reverts
mid-migration — a de-approved minter, a paused or upgraded token, any revert at all — both exits
revert; `finalizeAndReset` cannot rescue the pool because it requires `stakerCount == 0 &&
totalStaked == 0`. The full principal of the pool is trapped with no hatch.

### The deviation

**The story is internally contradictory, and the implementation faithfully executed one half of it
while silently dropping the other.** Story-022 states two requirements that cannot both hold:

- **(a)** the principal paths never call the reward token (Story Overview, quoted above), asserted
  again as the explicit robustness test; and
- **(b)** call-site change 5: *"`_exitPosition` (578–602) — pay `pending + unclaimedReward[token][account]`,
  zeroing the unclaimed slot before the mint"*.

`_exitPosition` **is** a principal path — the sole one during `Migrating` — so (b) requires precisely
the mint that (a) forbids. The implementation did (b) exactly as written. This is not developer
error against a clear spec; it is a specification defect that the machine review did not catch.

The story's own test list encodes the same gap: the robustness test enumerates `stake`, `withdraw`
and `emergencyWithdraw` and stops, and the terminal-migration bullet asserts *payment*, never
*survival under revert*. Nothing in the story, and nothing in the suite, exercises "migration exit
with the minter revoked".

### Aggravating factor — the guarantee shipped unconditionally into operator-facing documentation

```
lib/stable-staker/CLAUDE.md:12-13
  "That is deliberate robustness: a revoked minter role, or any Antimatter revert, can no longer
   brick a principal path."

lib/stable-staker/docs/deferred-reward-accrual-plan.md:37-38
  "The principal paths now never call the reward token at all, so its availability can neither
   trap nor degrade principal handling."
```

Both are absolutes with **no migration carve-out**. The in-source NatSpec repeats the framing at
`src/StableStakerV2.sol:829-830`:

```solidity
/// @dev Book any outstanding pending reward for an existing position to {unclaimedReward}, where
///      {claim} will mint it. Never calls Antimatter, so a revoked minter role cannot brick the
///      principal paths that reach here. Assumes pool is current.
```

— true of `_settle` in isolation, and read as a whole-contract property by anyone skimming.

Per the authority rule in §0, these documents carry **no suppression authority** and the false
exhaustiveness **raises** the severity of this finding: an operator reading `CLAUDE.md:12-13` will
believe that revoking the staker's minter role during an incident is principal-safe. During a
migration it is not. This is exactly what makes M-01's trigger non-obvious rather than reckless.
The finding is also **not suppressible by construction** — the claim *is* that the documentation is
wrong, so citing the documentation would be circular.

### Relationship to M-01

**Status update, 2026-08-31 — F-01 is UNCHANGED and REMAINS VALID.** Its security twin `M-01` was downgraded to **Low** and re-labelled **`L-10`** by owner triage on **operational** grounds (fail-loud on the attended, `onlyMigrator` migration path is intended behaviour, and its recommended mitigation was rejected); **the Law-2 deviation stands entirely on its own** — story-022's headline acceptance criterion is still unmet on the migration exit, the story's requirements (a) and (b) are still mutually inconsistent, no test still exercises "migration exit with the minter revoked", and `CLAUDE.md:12-13` still states the guarantee unconditionally. Nothing below is retracted or re-severitied; the owner triage explicitly preserves the documentation-correction remedy, which is F-01's remedy, not the contract fix.

M-01 reports the security consequence (100% of a pool's principal frozen; PoC passing) and is
remediated in the contract. F-01 reports two distinct defects M-01 does not cover: a story whose
requirements contradict each other and whose acceptance test does not test its own headline claim,
and operator documentation that states a guarantee the code does not provide. The remedies are
different and both are owed.

### Recommended remedy

Apply the story's own shape consistently: make `_exitPosition` **book** rather than mint —
`unclaimedReward[token][account] = owed;` with principal paid unconditionally — or wrap the mint so
that a revert cannot block the exit. Independently of the code fix, correct `CLAUDE.md:12-13` and
`docs/deferred-reward-accrual-plan.md:37-38` to name the migration exit as the one path that still
calls the reward token, and extend the robustness test to cover it.

---

## F-02 — story-023 swapped the emissions token for one with a permissionless redemption path, is silent on the consequence, and rewrote story-022's token-specific risk conclusion into a token-agnostic one

| | |
|---|---|
| **Severity (faithfulness)** | **Medium-equivalent** — filed as **story-unsafe**; Law 1 overrides Law 2 |
| **Story** | story-023 — *Antimatter emissions token for V2* (regressing story-022) |
| **Law impacted** | **1**, overriding 2 |
| **Location** | `src/StableStakerV2.sol` (emissions leg, mints at `:385` and `:620`); premise at `lib/antimatter/src/Antimatter.sol:253-298` **at the nested pin `a5570ce`** (the commit `stable-staker` records and compiles against — `git -C lib/stable-staker ls-tree HEAD lib/antimatter` → `a5570ce1e968…`). Do **not** cite top-level `lib/antimatter` HEAD `3a96fb7`; its line numbers differ. |
| **Security twin** | **H-01** — empty-pool emission cliff. Cross-referenced, not collapsed. |
| **Confidence** | High on the omission; magnitude is the econ lane's call |

**This is the Law-1 override case: the finding is against the STORY, not merely the code.** The
implementation of story-023 is mechanically faithful in every respect — `IAntimatter.sol` exists with
`mint` and nothing else, the two mint sites are typed correctly, the `phusdPerSecond` /
`accPhusdPerShare` / `phUSDPerDay` renames landed, `src/versions/v1/*.sol` is byte-unchanged, and the
`annihilate` prohibition holds (`grep -rn "annihilate\|setPhUSD\|setPhUSDMinter" src/` returns no
hits). Choosing Antimatter as V2's reward token is the owner's design decision and is trusted under
Law 3. What is reported is that the story making the swap performed **no consequence analysis at
all**, and that its documentation pass converted a token-specific safety conclusion into a
token-agnostic one without re-deriving it.

### The silence is the finding

A grep for the entire concept space over the full story document:

```
grep -n -i "dilut\|unbacked\|backing\|peg\|redeem\|redemption\|liabilit" 023-*.md
```

returns **two hits, neither of them the point**: line 207 (`annihilate` burns the caller's own
balance) and line 237 (a naming convention). There is no assessment anywhere in the story of what it
costs the protocol to emit a redeemable bearer token.

The story frames the swap as a mechanical type change (lines 66-67, verbatim):

> "`function mint(address to, uint256 amount) external onlyApprovedMinters { _mint(to, amount); }` —
> signature **identical** to `IFlax.mint`, so the two call sites need only a type change."

Against the established premise (`lib/antimatter/src/Antimatter.sol:253-298` at the pin `a5570ce`):
`annihilate` is permissionless, AM is a plain uncapped freely-transferable ERC-20, and `:294`
(`_phUSD.mint(recipient, amount);`) mints the AM half as **phUSD with no stablecoin behind it**,
alongside the separately-backed half routed through `minter.mint(stable, stableAmount)` at `:282`.
*(Citation note: an earlier draft cited `:226-267`/`:263`, which are top-level-HEAD `3a96fb7` numbers.
At the pin `a5570ce` — the code that actually compiles here — `:263` is
`PhusdStableMinter minter = phUSDMinter;`, not a mint at all. Verified at `a5570ce`.)* Each emitted AM is therefore a bearer claim on ~1e18 unbacked
phUSD, realisable by any third party. phUSD's "authorized minter, no user redemption path" property —
the thing that made over-crediting economically inert, and the premise on which several prior ledger
suppressions rest — is gone. The story never states this, never bounds it, and never re-derives the
emission cap in economic terms; `antimatterPerDay` remains owner-set and unbounded
(`src/StableStakerV2.sol:214-218`).

### Aggravator 1 — the story refutes a vector nobody raised, then declares the area clear

Story-023, lines 207-209 (verbatim):

> "Reinforcing fact worth recording: `annihilate` burns `msg.sender`'s **own** balance and consults
> no allowance, so a staking contract holding an allowance over a user could not annihilate on that
> user's behalf regardless. **The prohibition is about scope discipline, not about closing a hole.**"

The vector disposed of here — *staker annihilates on a user's behalf* — was never the exposure. The
actual exposure runs the other direction: the **recipient** of emissions annihilates their **own**
AM, exactly as the token is designed to be used. Having refuted the irrelevant case, the story
declares the area clear. Its only other mention of `annihilate` frames the residual as cosmetic
(lines 341-345):

> "**Emissions dust**: … odd-wei emission amounts become unannihilatable dust for holders.
> **Recorded for downstream awareness ONLY.**"

A falsely-narrow scoping statement of this kind carries no suppression authority.

### Aggravator 2 — the docs pass silently rewrote story-022's risk analysis

Story-022, line 41, recorded the downside deliberately and **in phUSD terms**:

> "Known downside carried deliberately: deferral builds an unbounded off-schedule mint liability
> realisable all at once. That is a **phUSD peg / market-depth** concern, not a solvency one."

Story-023's documentation pass rewrote that sentence in place. `git diff 045d13c 2d609cb -- docs/deferred-reward-accrual-plan.md`:

```diff
-realisable all at once. That is a phUSD peg / market-depth concern, not a solvency one, and is what
+realisable all at once. That is a reward-token market-depth concern, not a solvency one, and is what
```

The **subject** was substituted (`phUSD peg` → `reward-token`); the **conclusion** — "not a solvency
one" — was preserved untouched. But that conclusion **followed from** phUSD's no-redemption property.
Antimatter does not have that property. Under Antimatter the deferred `unclaimedReward` backlog is an
unbounded, uncapped claim that converts 1:1 into unbacked phUSD on demand. The live text at
`docs/deferred-reward-accrual-plan.md:126-129` now reads:

> "Known downside carried deliberately: deferral builds an unbounded off-schedule mint liability
> realisable all at once. That is a reward-token market-depth concern, not a solvency one, and is what
> the coming minting overhaul addresses."

— asserting a solvency-safety conclusion that **no story ever re-derived for the token it names**.
This is the second of the three documentation instances flagged in §0, and per that rule it raises
severity rather than lowering it.

The same laundering is visible independently in this run's known-issues re-extraction: the live cap
statement was rewritten token-agnostically without ever stating that it is now a **dilution budget
denominated in phUSD backing**.

### Law-3 footgun rider

Two owner-facing consequences follow that neither story states and that a competent, non-malicious
owner would be surprised by:

1. An `antimatterPerDay` rate calibrated under the phUSD premise is now a **phUSD dilution rate**.
2. Story-023 lines 338-340 record that Antimatter has **no `mintVersion` mass revocation** —
   *"per-minter `setApprovedMinter(x, false)` is the only revocation"* — so incident response must
   enumerate minters one at a time, and, per F-01, doing so mid-migration bricks the pool.

### Relationship to H-01

H-01 sizes and reports the security consequence (empty-pool emission cliff; 1 wei arms a full-rate,
permissionlessly-capturable unbacked-phUSD dilution stream). F-02 reports the reasoning failure that
produced it — a story that changed the economic character of the reward leg without recording any
consequence, and a docs edit that preserved a conclusion whose derivation it had just invalidated.
Fixing H-01 does not fix F-02, and vice versa.

### Recommended remedy

Re-derive, in the story record and in `docs/deferred-reward-accrual-plan.md`, the economic
consequence of the token swap: state explicitly that `antimatterPerDay` is now a phUSD dilution
budget, restate or withdraw the "not a solvency one" conclusion for Antimatter, and bound the
emission rate accordingly. **Every existing suppression whose stated rationale is "the reward token
has no redemption value / over-crediting the minter is opportunity cost, not loss" must be
re-derived, not carried forward, for StableStakerV2 at `fa06de5`.** Frozen V1 (still phUSD) is
unaffected.

---

## F-03 — story-022's "nothing is stranded" argument rests on an unstated precondition that story-023 removed

| | |
|---|---|
| **Severity (faithfulness)** | **Low-equivalent** |
| **Story** | story-022, Autonomous Decision 3 — regressed by story-023 |
| **Law impacted** | 2, with a Law-3 footgun component |
| **Location** | `src/StableStakerV2.sol:598-601` (`_exitPosition` early return), `:376` (`claim`) |
| **QA cross-reference** | **L-04** |
| **Confidence** | High |

### Story text (verbatim)

Story-022, Autonomous Decision 3:

> "Kept the early return unchanged … **`claim` remains open to them** — it is `poolExists`-gated but
> not `PoolState`-gated, and `finalizeAndReset` does not clear `unclaimedReward` — so **nothing is
> stranded**."

Confirmed by the reviewer at story-022 lines 457-459 and carried into the auto-complete triage as a
`[low]` "the chosen path works".

### Actual behaviour

The code matches the story exactly. `_exitPosition` returns before zeroing, so a fully-withdrawn
user's backlog survives migration:

```solidity
// src/StableStakerV2.sol:598-601
uint256 amt = info.amount;
if (amt == 0) {
    return 0;
}
```

and `claim` carries no `PoolState` gate — but it does carry `whenNotPaused`, and it mints:

```solidity
// src/StableStakerV2.sol:376
function claim(address token) external nonReentrant whenNotPaused poolExists(token) {
    ...
    require(owed > 0, "StableStaker: nothing to claim");
    unclaimedReward[token][msg.sender] = 0;
    user.rewardDebt = (user.amount * pool.accAntimatterPerShare) / ACC_PRECISION;
    antimatter.mint(msg.sender, owed);      // :385
```

The non-strandedness argument therefore has a **third, unstated precondition**: the retired staker
must remain an approved Antimatter minter, **and unpaused**, indefinitely after a cross-version
migration.

### The deviation

Under phUSD that precondition was cheap, and story-022 could reasonably leave it implicit.
Story-023 changed the revocation model and **never revisited Decision 3**: it records at lines
338-340 that Antimatter has no `mintVersion` mass revocation and that per-minter
`setApprovedMinter(x, false)` is the only mechanism. De-approving a decommissioned staker after a
completed migration is the obvious, correct-looking hygiene step — and it permanently strands every
residual `unclaimedReward` backlog on that contract, with no on-chain guard and no runbook entry.
That is a non-obvious consequence of an ordinary owner action: a footgun, and in scope under Law 3.

### Confirming evidence — Tier-3 fuzzing

The precondition is not hypothetical. This run's Tier-3 campaign made the population concrete:
`batchMigrate` **skipped zero-principal users holding a non-zero backlog on all 21 occurrences in the
campaign** — i.e. the early return fires routinely, not exceptionally, and every occurrence leaves a
backlog whose only exit is `claim`. Because `claim` is `whenNotPaused`, a retired staker left paused
strands those backlogs permanently, in addition to the minter-revocation path. Two independent
ordinary operational acts — revoke the decommissioned minter, or leave the decommissioned contract
paused — each produce permanent stranding.

Held at Low rather than Medium because revocation is reversible by a single call and the exposure is
the availability of a modest residual backlog, not loss.

### Recommended remedy

Primarily documentation: record in `CLAUDE.md` and in the migration runbook that a retired staker
must retain approved-minter status **and remain unpaused** until residual `unclaimedReward` balances
are drained, or add a terminal backlog-sweep step to the migration procedure. Story-022's own listed
alternative ("pay the backlog before the early return") would also close it, at the cost of changing
`_exitPosition` semantics.

---

## F-04 — the vendored V1 pair is protected by no gate, and story-024 declined to pin it on a premise that is factually wrong

| | |
|---|---|
| **Severity (faithfulness)** | **Low-equivalent** (QA / integrity-of-controls; no live-value path) |
| **Story** | story-024 — *Vendor flax-token into frozen V1* |
| **Law impacted** | 2 |
| **Location** | `src/versions/v1/vendor/IFlax.sol`, `src/versions/v1/vendor/FlaxToken.sol`; gate at `.github/scripts/check-migration-surface.sh:88` |
| **QA cross-reference** | **Q-01** |
| **Confidence** | High |

**The vendoring itself is byte-faithful and exactly as specified.** Story-024 required a verbatim
copy with no behavioural change, and both held:

> "**Copy the two files VERBATIM** — byte-for-byte, no reformatting, no comment tidying, no pragma
> bumps — apart from a provenance header." — story-024, lines 218-221
>
> "Note the naming oddity to **preserve rather than 'fix'** … Vendor the files as they are; do not
> tidy their comments." — lines 122-126
>
> "**Therefore: the two frozen files stay BYTE-IDENTICAL, and the redirection happens at the
> REMAPPING.**" — lines 69-70

All confirmed at `fa06de5`: the byte comparison against `f5300117` differs only by the provenance
header and a trailing newline; the redirection is at the remapping (`remappings.txt:3` and
`foundry.toml:25` both read `flax-token/=src/versions/v1/vendor/`), so no import site changed;
`git diff 2d609cb..fa06de5 -- test/` is empty; `FROZEN.sha256` retains exactly its two original
lines; and `git diff 2146428 fa06de5 -- src/versions/` shows no change to `StableStakerV1.sol` or
`IStableStakerV1.sol`.

**The finding is the absence of a hash pin on the vendored pair**, and the false premise on which
the story ruled that absence non-negotiable.

### Story text (verbatim), stated as settled and not open to re-weighing

Story-024, Technical Details, lines 156-162:

> "**The vendored copies MUST NOT be added to `src/versions/v1/FROZEN.sha256`.** This is not a
> trade-off to weigh; it is a hard constraint.
>
> `.github/scripts/check-migration-surface.sh` asserts that the manifest holds **exactly two
> entries** (`manifest_count == 2`) and fails loudly if the manifest grows. Adding
> `vendor/IFlax.sol` and `vendor/FlaxToken.sol` to it breaks CI outright."

and lines 171-172:

> "The vendored files are ordinary tracked source. They are protected by review and by the fact that
> V1 is frozen, not by a hash pin."

### Actual behaviour — the premise is false

The gate is first-party and the "2" is not a constant. It is `${#FROZEN_FILES[@]}`, the length of a
hard-coded array declared two lines above the check, in a script this repository owns:

```bash
# .github/scripts/check-migration-surface.sh:88
FROZEN_FILES=(src/versions/v1/StableStakerV1.sol src/versions/v1/IStableStakerV1.sol)
...
# :103-105
manifest_count=$(grep -cvE '^\s*(#|$)' "$FROZEN_MANIFEST" || true)
if (( manifest_count != ${#FROZEN_FILES[@]} )); then
  fail "$FROZEN_MANIFEST pins $manifest_count file(s); expected ${#FROZEN_FILES[@]}."
```

Adding the two vendored paths to **both** the array and the manifest keeps the check green at
`4 == 4` — a two-line edit. There was no CI obstacle. The story mistook a self-imposed tooling
parameter for an immovable external constraint, reached a real design conclusion on it, and
explicitly forbade anyone from re-weighing it ("not a trade-off to weigh").

### The deviation

The consequence is a genuine reduction in the frozen-surface guarantee that the story's own purpose
depends on. After this change, `src/versions/v1/StableStakerV1.sol` is hash-pinned, but the `IFlax`
**it compiles against** is not: the frozen V1's compiled behaviour can now be altered by editing an
unpinned sibling file inside the same directory, with every gate still green. Before story-024 that
surface was a submodule gitlink, pinned by `.gitmodules`, `foundry.lock` and git's own object
hashing; after it, it is loose tracked source with no pin at all. `src/versions/README.md` frames the
coupling as precisely the thing being managed (quoted at story-024, lines 76-78):

> "External types that *must* be imported (`IYieldStrategy`, `IFlax`) are a known coupling: if those
> submodule interfaces change shape, the frozen files inherit the churn."

### Compounding — the stated second line of defence does not exist

Story-024 lines 65-66 (echoed in story-023) claim:

> "Those hashes are verified by `.github/scripts/check-migration-surface.sh` (check 4) and **edits are
> blocked at edit time by the `PreToolUse` hook `.claude/hooks/protect-migration-surface.sh`**."

The hook does no such thing. Its entire guard is the three golden-rule declarations:

```bash
# .claude/hooks/protect-migration-surface.sh:38
PROTECTED=(initiateMigration batchMigrate depositFor)
```

used at `:155`, `:177` and `:236`. `grep -n "src/versions" ` over that file returns only two prose
comments (`:22`, `:67`); there is **no path-based deny for `src/versions/v1/`**. Net effect: the
frozen pair has **one** gate (CI), not the two the stories claim; the vendored pair — whose stated
residual protection is "review" — has **zero**.

### Recommended remedy

Append both vendored paths to `FROZEN_FILES` and to `FROZEN.sha256` (the check then passes at
`4 == 4`), or add a CI assertion that the vendored copies equal the `@phUSD/` copies. Separately,
correct both stories' claim about what the `PreToolUse` hook enforces.

---

## Adjudicated as within story intent — recorded, not filed

**Duplicate `FlaxToken` artifact in the build.** `flax-token/` resolves to `src/versions/v1/vendor/`
while `@phUSD/` resolves to `lib/antimatter/lib/flax-token-v2/src/` (`remappings.txt:3` and `:7`).
Both are `f5300117` today, so `forge build` emits two same-named `FlaxToken` artifacts, and a
`lib/antimatter` bump would drift them apart unchecked.

This is **not** filed as a Law-2 deviation: story-024 scopes it out twice, explicitly and with human
sign-off.

> "**Scope is stable-staker's OWN direct dependency list, not the transitive tree.** … Whatever
> arrives underneath `lib/antimatter/` is antimatter's business and is explicitly **NOT** a concern
> for this story." — lines 19-22
>
> "**Transitive reappearance of flax-token-v2 under `lib/antimatter/` is explicitly OUT OF SCOPE**
> and accepted by the human. Do not chase it." — lines 338-339

Under Law 3 that is a trusted scoping decision with an obvious consequence, not a footgun. For the
frozen V1, the pinned vendored copy is the *desired* outcome — it is exactly the churn insulation
`src/versions/README.md` asked for. The residual (artifact-name ambiguity for
`vm.getCode("FlaxToken.sol")`, and silent divergence on a bump) is a build-hygiene item carried to
the QA bundle. The pin gap that **is** reportable is F-04, which concerns the absence of any hash pin
on the vendored pair, not the existence of the duplicate.

---

## Other observations carried without a finding

- **story-023 public ABI break** — `phUSD()` → `antimatter()`, `phUSDPerDay` → `antimatterPerDay`,
  constructor argument `IFlax` → `IAntimatter`. Deliberate, V2-only, recorded in the story's
  Decision 6; downstream consumers are explicitly out of scope. The auto-complete triage carried it
  forward as `[medium]`: `reflax-mint` / `phase-2-staging` break on their next `lib/stable-staker`
  pin bump. Relevant to a phStaging script audit, not a defect here.
- **`MigratedOut.reward` semantics** — now `pending + unclaimed`. Specified by story-022 and flagged
  in its own Concerns section; off-chain consumers will read a different number. Faithful, recorded.
- **story-023 commit `2d609cb`** spells the literal sentinel `GOLDEN-RULE-OVERRIDE` in its body,
  which `protect-migration-surface.sh` substring-matches. Self-reported; no harm here (gate green,
  migration surface unchanged), but it makes future commit-message auditing unreliable.
- **story-024 stale git-module directory** (~58 MB under the worktree's `.git/worktrees/.../modules/`)
  despite a ticked checklist box. Local-only, invisible to a fresh clone. Self-reported.
- **`CLAUDE.md:75` rounding claim** — "stakers' pending increase equals that minus integer-division
  dust (which always rounds DOWN)" is stated as an invariant and was **disproved by this run's Tier-3
  fuzzing by 1 wei**. The third of the three documentation instances in §0; recorded here because the
  overstated absolute, not the wei, is the point.

---

## Summary

| ID | Story | Type | Severity (faithfulness) | Security cross-ref |
|---|---|---|---|---|
| **F-01** | story-022 | Requirement not met on one path + false unconditional doc claim | **Medium-equivalent** (unchanged) | **M-01 → `L-10`** (PoC passing; downgraded to **Low** / `wont-fix` on 2026-08-31 by owner triage on operational grounds — **F-01 is unaffected**) |
| **F-02** | story-023 | **Story-unsafe** — silent on the redemption consequence; laundered a token-specific conclusion | **Medium-equivalent** (Law 1 over Law 2) | **H-01** |
| **F-03** | story-022 (regressed by story-023) | Unstated precondition; ordinary-hygiene footgun | Low-equivalent | L-04 |
| **F-04** | story-024 | Control-integrity gap accepted on a false premise | Low-equivalent | Q-01 |

Each faithfulness finding is kept separate from its security twin: the remedies differ, and closing
the security finding does not discharge the specification or documentation defect.
