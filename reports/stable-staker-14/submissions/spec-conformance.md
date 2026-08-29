# Spec Conformance (Law 2) — stable-staker run-14

- **Project:** stable-staker
- **Submodule HEAD:** `8856781` (regression baseline `d95f4a6`)
- **Branch:** `master`
- **Stories in range:** 014, 015, 016, 017, 018
- **Compiled:** 2026-08-27

**Five** faithfulness findings belong to this report. Four are filed below, one section each;
the fifth (**L-08**) is a standalone section file in this same directory, linked from the table and
from its own section at the end of this report. They carry this run's Low labels so the QA bundle's
pointer table resolves; the `F-` numbers are the story-faithfulness scan's own cross-references,
retained for traceability.

| Label | Issue ID | Faithfulness ref | Story / authority | Subject |
|---|---|---|---|---|
| L-01 | `ss14l1` | F-06 | story-018 | Dust-poison: batch-survival guard tests the wrong side of the transfer |
| L-02 | `ss14l2` | F-05 | story-018 | Haircut mis-attribution: the destination-side leg is undocumented |
| L-03 | `ss14l3` | F-02 | story-017 | Golden-rule gate is blind to snapshot **deletion** |
| L-04 | `ss14l4` | F-01 | story-015 | Snapshot ritual targets master HEAD, not the deploy commit |
| L-08 | `ss14l8` | — | owner statement, 2026-08-28 | Terminal migration ignores the set-aside buffer — **[`L-08-set-aside-buffer-not-swept.md`](L-08-set-aside-buffer-not-swept.md)** |

> **There is no L-07 in this run.** `L-07` was retired when the finding that briefly held it was
> re-escalated to `M-01` (`ss14m1`); the label must not be reused, so the buffer finding took `L-08`.
> The run's Lows are `L-01`–`L-06` and `L-08`.

---

## Provenance of the evidence base

This section is recorded because it bears on the weight a reader should give the stories'
own Execution and Review sections. It is a statement of fact about the story records, not a
judgement about the code.

| Story | Commit | State folder | Approval record |
|---|---|---|---|
| story-014 | `51700cf` | `complete/` | human-reviewed |
| story-015 | `c4f62ab` | `auto-complete/` | machine approval — not human-reviewed |
| story-016 | `01a3e66` | `auto-complete/` | machine approval — not human-reviewed |
| story-017 | `f56df78` | `auto-complete/` | machine approval — not human-reviewed |
| story-018 | `8856781` | `auto-complete/` | machine approval — not human-reviewed |

Story-018's own record discloses that both its execution and its review ran in
`--inline-delegation` mode with no validator subagents:

> "**Mode**: --inline-delegation (agent nesting limit — no Task/Agent tool was available to this
> session)"

and its review section states that its own verdict is *"the only surviving independent verdict on
this story"*. Story-015's reviewer likewise recorded the drift defect that becomes L-04 below as a
non-blocking `[low]` and carried it forward without correcting the story text.

Story-014 sits in `complete/`, is human-reviewed, and its evidence held up under re-derivation.

**Every load-bearing claim in this report was re-derived from git and from source.** Story-recorded
Execution Findings and Review Results were treated as claims to be checked, not as evidence.

---

## [L-01] Dust-poison: the batch-survival guard tests the SOURCE credit while the revert fires on the DESTINATION credit <!-- id: ss14l1 -->

- **Severity:** Low (high band) — liveness, no value loss
- **Faithfulness ref:** F-06 · **Story:** story-018 · **Law impacted:** 2
- **Contract:** `src/CrossVersionMigrator.sol:134` (guard) / `src/StableStaker.sol:642` (revert)
- **Class:** `wrong-side-zero-credit-guard`

### The spec text

Story-018 made this an explicit, deliberate decision point:

> "**`depositFor` reverts on zero credit.** Story 011 added
> `require(credited > 0, "StableStaker: nothing credited")`. A dust user whose credit rounds to zero
> will revert the whole batch. Story 013 recorded this as open item L-01 / `ss12l1` and explicitly
> left it out of scope. **Decide deliberately here**: either skip zero-credit users (recommended —
> the retired `StableStakerMigrator` already guarded with `if (amounts[i] > 0)`, and that guard must
> carry over) or document that batches must be pre-filtered off-chain. **Do not silently inherit the
> landmine.**"

The delivered contract records that decision as closed, in NatSpec section (D)
(`src/CrossVersionMigrator.sol:39-47`):

> "(D) ZERO-CREDIT USERS ARE SKIPPED, NOT PASSED THROUGH. `StableStaker.depositFor` reverts with
> "StableStaker: nothing credited" when the credit rounds to zero (story 011). A single dust user
> whose snapshot credit floors to 0 would therefore revert an entire batch. **The
> `if (amounts[i] > 0)` guard below skips those users so the batch survives** — the open item
> L-01 / `ss12l1` dust interaction recorded by story 013. … **The alternative — requiring batches to
> be pre-filtered off-chain — was rejected as a landmine.**"

### The actual behaviour

The guard reads the **source-side** snapshot credit returned by `oldStaker.batchMigrate`. The revert
it exists to prevent fires on the **destination-side** booked credit, which is a different quantity
computed inside the destination staker's yield strategy.

`src/CrossVersionMigrator.sol:118-136`:

```solidity
function migrate(address token, address[] calldata users) external onlyOwner {
    uint256[] memory amounts = oldStaker.batchMigrate(token, users);   // :119  SOURCE-side credits
    ...
    for (uint256 i = 0; i < users.length; i++) {
        if (amounts[i] > 0) {                                          // :134  tests the SOURCE side
            newStaker.depositFor(token, users[i], amounts[i]);         // :135
```

`src/StableStaker.sol:640-646` — the revert the guard is supposed to be preventing:

```solidity
uint256 received = _pullToken(token, msg.sender, amount);      // :640
uint256 credited = _routeDeposit(token, received);             // :641  DESTINATION-side credit
require(credited > 0, "StableStaker: nothing credited");       // :642
```

A strictly positive `amounts[i]` therefore satisfies the guard and can still produce
`credited == 0` — or revert even earlier. **There are two distinct kill paths, and both end the
batch atomically:**

**(1) Destination strategy above par — the realistic production wiring.** The batch dies *inside the
strategy*, before `_routeDeposit` ever returns. Depositing 1 wei into an ERC-4626 vault priced above
par mints zero shares
(`reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol:107-108`):

```solidity
sharesReceived = vault.deposit(amount, address(this));
require(sharesReceived > 0, "ERC4626YieldStrategy: no shares received");   // :108
```

Exact revert string: **`ERC4626YieldStrategy: no shares received`**.

**(2) Destination strategy below par.** One share *is* minted, but the credit is booked at the
share's asset value, which floors back to zero
(`ERC4626YieldStrategy.sol:115`):

```solidity
creditedPrincipal = vault.convertToAssets(sharesReceived);   // :115  floors 1 share -> 0 assets
```

`_routeDeposit` therefore returns `0` for a strictly positive `received`, and
`src/StableStaker.sol:642` reverts with the exact string **`StableStaker: nothing credited`**.

Closed-form trigger window, derived and fuzzed: `ceil(sharePrice) - 1` wei above par; 1 wei below
par; zero at par or against an idle (strategy-unset) destination. Observed at ≤ 9 wei across 2,000
fuzz runs.

### Why this is not the fee-on-transfer carve-out

The dust position is planted by an ordinary `stake(X); withdraw(X - 1)` against a **plain ERC-20**.
No fee-on-transfer token, no rebasing token, and no non-standard token appears anywhere on the path
— verified independently twice. The C4 "fee-on-transfer / weird ERC-20" known-invalid carve-out
therefore does not apply.

### Impact

Two layers.

- **Layer (i) — recoverable, but the contract's own documentation forbids the remedy.** The batch
  reverts atomically with the migrator holding nothing. The operator's fix is to drop the offending
  address and re-batch off-chain — which is precisely the remedy section (D) names "a landmine" and
  records as **rejected**. An operator following the NatSpec has been told the failure cannot happen
  *and* told not to use the workaround that works.
- **Layer (ii) — a liveness wedge that survives this migrator, but is clearable by the owner.** The
  affected user cannot be batch-migrated through **this** migrator to a **strategy-backed**
  destination: `CrossVersionMigrator` exposes no raw passthrough, and `StableStaker.batchMigrate` is
  `onlyMigrator`. In the unremediated state `finalizeAndReset` stays blocked — the PoC validator
  observed `finalizeAndReset reverted: StableStaker: stakers remain`. It is cleared by **either** of
  two routes: the dust holder self-exits via the permissionless `userMigrate`, **or** the owner
  routes them through a **strategy-less staging staker** using a replacement migrator.

  The owner remedy works because `_routeDeposit` returns `amount` **in full** when no strategy is
  set, so the `require(credited > 0)` that trips against a strategy-backed destination does not trip
  against an idle one (`src/StableStaker.sol:767-772`):

  ```solidity
  function _routeDeposit(address token, uint256 amount) internal returns (uint256 credited) {
      IYieldStrategy strategy = yieldStrategy[token];
      if (address(strategy) == address(0)) {
          return amount; // idle hold: full credit          // :770
      }
      return strategy.deposit(token, amount, address(this));
  }
  ```

  The re-pointing is unobstructed because the **staker's** `migrator` field is a plain owner-settable
  address with no `poolState`, pause, or existence gate (`src/StableStaker.sol:200-203`) — even
  though the **migrator's** own endpoints are immutable:

  ```solidity
  function setMigrator(address _migrator) external onlyOwner {   // :200
      migrator = _migrator;
      emit MigratorSet(_migrator);
  }
  ```

  Confirmed empirically (`workspace/stable-staker/test/poc/ZZ_AuditorProbe.t.sol`, PASS):

  ```
  OWNER REMEDY: 1-wei wedge holder migrated, dest credit: 1
  OWNER REMEDY: source pool revived, state: 0
  ```

  This is the same `setMigrator` mechanism that carries **`L-06`** (`ss14l6`, the unvalidated
  one-way door plus constructible self-aliased migrator, in `submissions/qa-report.md`). `L-06` was
  originally classified Medium on the premise that the self-aliased case has **no** owner remedy —
  leaving every user to call `userMigrate` individually, so one unresponsive or lost-key staker
  would wedge a funded pool permanently. The poc-validator refuted that premise, and the
  severity-auditor independently re-ran the probe and verified the mechanism in source before ruling
  the downgrade to Low correct. Recovery is three owner transactions — deploy a replacement
  migrator, `setMigrator` on each end — with **zero user cooperation**, and it works because the
  terminal `(R, P)` snapshot lives on the **staker** in `migrationInfo[token]`
  (`src/StableStaker.sol:128`, written at `:476`) rather than on the migrator, so a replacement
  migrator inherits it intact and pays identical credits.

  The owner-settable `migrator` pointer is therefore a **recurring, load-bearing escape hatch across
  this run's severity reasoning, not a one-off**. It cut both ways: it downgraded `L-06` from Medium,
  and it struck the false "unclearable" claim from this finding.

This is a **permissionless grief, not an accident-only rounding note**: the position is planted
deliberately for the cost of gas, and a deliberate griefer has no incentive to self-exit — so the
owner remedy above, not the holder's goodwill, is what actually clears layer (ii).

The Law-2 defect is that the guard **carries a false safety claim**. Section (D) and story-018 both
assert the failure mode is closed; it is open in the one case that matters.

### Ledger cross-reference

Same **root-cause class** as two open ledger Lows on the sibling `InPlaceMigrator`:

| Fingerprint | Status | Location | Title |
|---|---|---|---|
| `bda951d9f1` | open, low | `InPlaceMigrator.migrateIn` | Poison/zero-credit user reverts the whole `migrateIn` slice |
| `bf5018deab` | open, low | `InPlaceMigrator._reinjectWithTopup` | Small-principal top-up truncation reverts the `migrateIn` batch |

Kept separate, disclosed rather than merged. **What is new here:** neither sibling ships a guard for
this failure at all, so neither carries a false NatSpec safety claim. This one does. Fixing either
sibling does not fix this, and fixing this does not fix either sibling.

### Recommended mitigation

Move the zero-credit decision to the side the revert actually tests: either have the destination
expose a `previewCredit`-style view the migrator can consult before calling `depositFor`, or accept
per-user failure without killing the batch (try/catch around the `depositFor` call, emitting the
skipped user). Correct section (D) either way: it currently states a guarantee the code does not
deliver, and rejects the only remedy available today.

---

## [L-02] Haircut mis-attribution: NatSpec (E) and story-018 both blame an underwater SOURCE; the destination-side haircut is independent and bites on a healthy migration <!-- id: ss14l2 -->

- **Severity:** Low — documentation / mis-attribution axis only (see scope note)
- **Faithfulness ref:** F-05 · **Story:** story-018 · **Law impacted:** 2
- **Contract:** `src/CrossVersionMigrator.sol:49-57` (NatSpec §E), `:135` (the credit leg) /
  `src/StableStaker.sol:640-646`
- **Class:** `documentation-misattribution-of-an-independent-loss-leg`

### The spec text

Story-018 instructed that the non-compensation be stated **plainly rather than implicitly**:

> "**Underwater haircuts are not compensated by this contract.** Story 013's top-up logic lives in
> `InPlaceMigrator._reinjectWithTopup` and is specific to the park-and-reinject flow. A cross-staker
> migration through an underwater strategy will credit less than the snapshot principal. **State
> this plainly in the contract NatSpec rather than leaving it implicit**".

The delivered NatSpec, section (E) (`src/CrossVersionMigrator.sol:49-57`):

> "(E) UNDERWATER HAIRCUTS ARE NOT COMPENSATED HERE. If the **old staker's** yield strategy is
> underwater, `batchMigrate` pays each user the uniform snapshot credit `p_i*min(R,P)/P`, which is
> LESS than their principal. **This contract redeposits exactly what it received and no more**; it
> does not top anyone up. Story 013's surplus-funded top-up lives in
> `InPlaceMigrator._reinjectWithTopup` and is specific to the park-and-reinject flow … A
> cross-version migration through an underwater strategy credits the haircut, and that asymmetry
> with `InPlaceMigrator` is a deliberate, human-visible product difference."

### The actual behaviour

Section (E) is written entirely in **source-side** terms. There is a second, fully independent
haircut on the **destination** side that does not require the source to be underwater at all.

`src/StableStaker.sol:640-646` credits `credited`, not `amount`:

```solidity
uint256 received = _pullToken(token, msg.sender, amount);      // :640
uint256 credited = _routeDeposit(token, received);             // :641
require(credited > 0, "StableStaker: nothing credited");       // :642
info.amount      += credited;                                  // :643
pool.totalStaked += credited;                                  // :644
```

Against `ERC4626MarketYieldStrategy` the booked credit is a deterministic haircut, applied
unconditionally — not a loss condition
(`reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:105-107`):

```solidity
function _creditedPrincipal(uint256 amount) internal view returns (uint256) {
    return amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS;   // :107
}
```

At `slippageToleranceBps = 100` that is **1% of migrated principal, applied in full on a perfectly
healthy migration where `R == P` and the source strategy is at or above par.**

The sentence "This contract redeposits exactly what it received and no more" is **true of the
transfer and false of the user's outcome** — and it sits inside a NatSpec block that reads as
exhaustive on the subject of uncompensated shortfall. A reader takes it to mean "the user ends up
with what was redeposited", which is exactly what the destination haircut breaks.

The confusion is cemented by story-018's own test plan, which describes the very knob that models
this case as modelling something else:

> "Mocks available: `test/mocks/MockERC20.sol` (configurable decimals) and
> `test/mocks/MockYieldStrategy.sol` (settable `valueFactor` bps, `setDepositSlippageBps`), **the
> latter being how underwater conditions are simulated**."

Deposit slippage is not an underwater condition. The consequence is that the
**healthy-source-with-haircutting-destination case is unmodelled by the story and by the test suite
alike** — there is no test that exercises it, because the story does not know it exists.

Neither event surfaces the gap. `MigratedAcrossVersions` emits the **source** total
(`src/CrossVersionMigrator.sol:141-143`); `DepositedFor` emits only `credited`
(`src/StableStaker.sol:646`). No observer sees both numbers.

### Impact

An operator reading section (E) concludes the risk is confined to a *known-underwater source*
strategy, verifies the source is healthy, and clears the migration — without checking the
destination's `slippageToleranceBps`, producing an uncompensated shortfall on every user in the
batch. That is a Law-3 footgun: a competent, non-malicious owner would be surprised.

Where the value goes, for accuracy: the portion consumed by real AMM execution **leaks to
third-party LPs**; the remainder is **retained inside the destination strategy as protocol-owned
surplus**. It is not a single homogeneous transfer.

**Reach today is ~1 wei.** The currently-targeted destination route is the direct
`ERC4626YieldStrategy` (Tokemak `autoDOLA` / `autoUSD`), which credits at the share exchange rate and
haircuts only by share rounding. The 1%-scale exposure is latent and contingent on a market/AMM-backed
destination being wired.

### Scope note — what is filed here and what is not

**Filed here: the documentation / mis-attribution defect only.** The underlying **code** defect — the
`amount` vs `credited` asymmetry itself — is **not** a new finding: it is open ledger Low
**`4f143a9573`**, same root cause, unchanged severity and unchanged reach in kind. That entry is being
**scope-extended** to `src/CrossVersionMigrator.sol:135` rather than re-filed, so a second fingerprint
is not minted for one asymmetry.

For the record: `3d61c9552f` (acknowledged) and `b5218ab2` (submitted) sit on the **deleted**
`migrateOut` path and are the wrong repoint target. `4f143a9573` is the correct one.

Cross-reference: `L-05` in `submissions/qa-report.md` (no rescue path on `CrossVersionMigrator`) —
this finding is the documentation defect that *invites* the owner pre-funding scenario `L-05`'s
missing rescue path cannot remedy.

### Recommended mitigation

Extend section (E) with the destination leg — cite `StableStaker.depositFor`'s
`credited = _routeDeposit(token, received)` and ledger entry `4f143a9573`, and state explicitly that
the haircut applies **even when the source is healthy**. Replace "redeposits exactly what it received
and no more" with wording that names what the *user* is credited. Correct story-018's mock
description, and add the healthy-source / haircutting-destination test the current plan omits.

---

## [L-03] The golden-rule gate is blind to snapshot DELETION <!-- id: ss14l3 -->

- **Severity:** Low — process/tooling; no runtime asset or availability consequence
- **Faithfulness ref:** F-02 · **Story:** story-017 · **Law impacted:** 2
- **Files:** `.github/scripts/check-migration-surface.sh:52-56`,
  `.claude/hooks/protect-migration-surface.sh:231-250`
- **Class:** `enforcement-gate-blind-to-deletion`

### The spec text

Story-017 promised three layers of defence, and named version snapshots as a gap it closes:

> "Three layers of defence, weakest to strongest:
> 1. **Documentation** — the rule stated loudly in `CLAUDE.md` …
> 2. **A Claude Code `PreToolUse` hook** — sounds alarm bells and **rejects the tool call** …
> 3. **A CI gate + Solidity test** — catches anything the hook misses, on every push."

> "Story 014 already made the compiler an enforcer for `StableStaker` itself … That covers the
> concrete contract but not the interfaces, **not the version snapshots**, and not an agent that
> 'fixes' the build by deleting the interface member too. **This story closes those gaps.**"

`CLAUDE.md` layer 3 states the coverage as universal:

> "A CI gate — `.github/scripts/check-migration-surface.sh`, run on every push. Checks the perpetual
> interface, the evergreen implementation, and that **every** `src/versions/` snapshot still reads
> `is IStableStakerMigratable`."

And story-015 set the snapshot's charter:

> "This file is never edited again. It is kept in source **perpetually** — until the live V1 instance
> is genuinely empty and dead."

### The actual behaviour

Running the **tracked CI gate verbatim** over a scratch copy of `src/` at HEAD, across six mutations:

| Mutation | Gate exit |
|---|---|
| baseline (unmodified HEAD) | `0` |
| (a) remove `, IStableStaker` from the `StableStaker` inheritance list | **`0` — PASS, not caught** |
| (b) delete `depositFor` from `src/interfaces/IStableStakerMigratable.sol` | `1` — caught |
| (c1) remove `is IStableStakerMigratable` from `IStableStakerV1.sol` | `1` — caught |
| (c2) **delete `src/versions/IStableStakerV1.sol` entirely** | **`0` — PASS, NOT CAUGHT** |
| (d) rename `depositFor` on `src/StableStaker.sol` | `1` — caught |

**Mechanism, layer 3.** `.github/scripts/check-migration-surface.sh:52-56` handles the empty
snapshot set with an `echo` and no `fail()`, so `status` is never set:

```bash
shopt -s nullglob
snapshots=(src/versions/IStableStakerV*.sol)                       # :52-53
if (( ${#snapshots[@]} == 0 )); then                               # :54
  echo "note: no version snapshots under src/versions/ yet."       # :55  no fail(), status untouched
fi                                                                 # :56
```

Every `fail()` in that script sets `status=1`; this branch calls `echo`. Deleting the only snapshot
empties the set and the loop that follows iterates zero times, so "every snapshot inherits the
perpetual interface" is satisfied **vacuously**.

**Mechanism, layer 2 — the hook misses it independently.** The authoritative Bash/commit branch
counts `function <name>(` declarations across `src/` in the staged tree versus `HEAD`
(`.claude/hooks/protect-migration-surface.sh:231-250`):

```bash
count_in_tree() {
  # $1 = tree-ish, $2 = function name
  git -C "$repo_dir" grep -hoE "function[[:space:]]+$2[[:space:]]*\(" "$1" -- 'src/' | wc -l
}
for name in "${PROTECTED[@]}"; do
  head_n=$(count_in_tree HEAD "$name")
  staged_n=$(count_in_tree "$staged_tree" "$name")
  ...
  if (( staged_n < head_n )); then deny "This commit removes a declaration of \`$name\` from src/."
```

`IStableStakerV1` **inherits** the triad (`is IStableStakerMigratable`) rather than declaring it, so
deleting the entire file changes that count by exactly zero and the commit is waved through.

### Impact

Both defence layers guard a snapshot's **content**; neither guards its **existence** — and perpetual
existence is that directory's entire stated purpose. The precedent story-015 cites for why the
directory exists is itself a *deletion*, not an edit:

> "Precedent from the sibling repo is the reason this matters: `phase-2-staging/foundry.toml` carries
> a compile-skip list because *'these legacy scripts are hard-wired to the V1 yield-claim-nft
> contracts … that story-039 removed from the submodule'*. **Deleting a V1 from a submodule broke
> downstream deployment scripts.** Keeping V1 in source perpetually is the direct remedy."

The consequence is now concrete: once story-016 added `STAKER_VERSION` at
`src/StableStaker.sol:57`, `src/versions/IStableStakerV1.sol` became **the only accurate description
in this repo of the live mainnet instance `0xbce8ABC09BaEDCabE93419bF875f6186e182079A`**.

### Mitigating factor — the deletion is NOT silent

Both purpose-built enforcement layers miss the deletion, but the repository is not left without a
tripwire. Two tracked test files import the snapshot directly, verified at HEAD `8856781`:

```
test/GoldenRule.t.sol:7            import "../src/versions/IStableStakerV1.sol";
test/StableStakerV1Snapshot.t.sol:6  import "../src/versions/IStableStakerV1.sol";
```

Removing the file therefore **breaks compilation**, and CI fails loudly on the build step. A reader
must not take this finding to mean the snapshot can be deleted with every check green — it cannot.

### Why the finding still stands

The gap is a genuine Law-2 process defect on its own terms:

- The two mechanisms **designed** to protect the golden rule — the CI gate story-017 promised would
  "catch anything the hook misses", and the `PreToolUse` hook — are **both blind to deletion**, which
  is the failure mode the cited precedent actually describes.
- The build break is an **incidental side effect** of two test files happening to import the file,
  not a designed guard. Nothing pins those imports; a test refactor, a consolidation, or a
  rewrite that binds the snapshot by interface rather than import would remove the tripwire
  **silently**, leaving exactly the undefended state the enforcement layers were supposed to
  prevent.
- An agent "fixing the build" after deleting the snapshot has an obvious, locally-reasonable repair
  available — drop the two imports — and both purpose-built layers would still pass.

No adversary is required and no runtime state is affected. Given the loud build break, this finding
is defensibly QA; it is held at **Low** because the defect is in the enforcement layers themselves
rather than in the incidental protection that currently compensates for them.

### Related but separate

Mutation (a) shows that the compiler — `CLAUDE.md`'s "layer 1" — is removable at will, since nothing
in layers 2–4 protects the inheritance list itself. This is a **documentation-accuracy nit, not a
broken guarantee**: the CI gate still catches the mutation that actually matters, because it greps
`src/StableStaker.sol` directly rather than relying on the inheritance declaration surviving. Filed
as **Q-03** in `submissions/qa-report.md`; cross-referenced here only.

### Recommended mitigation

In `check-migration-surface.sh`, call `fail()` rather than `echo` when the snapshot set is empty, and
additionally assert that every snapshot tracked at `HEAD` still exists in the checked-out tree. In the
hook, add a file-existence check for `src/versions/*.sol` present at `HEAD` alongside the declaration
count.

---

## [L-04] The snapshot ritual targets master HEAD rather than the deploy commit <!-- id: ss14l4 -->

- **Severity:** Low — procedural / forward-looking; the delivered artifact is accurate
- **Faithfulness ref:** F-01 · **Story:** story-015 (ritual written into `CLAUDE.md` by story-016) ·
  **Law impacted:** 2
- **Contract:** `src/versions/IStableStakerV1.sol`
- **Class:** `wrong-provenance-for-perpetual-snapshot`

### The spec text

Story-015 justified extracting the snapshot from master HEAD on a specific factual premise:

> "**The source is not drifted.** `phase-2-staging` pinned `lib/stable-staker` to `c3ec65b` on the
> deploy date, and `git diff --stat c3ec65b..HEAD -- src/` shows only `InPlaceMigrator.sol` and
> `interfaces/IStableStaker.sol` changed since. `StableStaker.sol` at master HEAD is byte-identical
> to the deployed bytecode's source, so the V1 snapshot can be extracted mechanically from the
> current file with **zero archaeology and zero drift risk**."

> "Deployment reconciliation against mainnet is the human's job and is explicitly out of scope for
> this story — **the snapshot is taken from master HEAD.**"

### The actual behaviour

Re-run independently:

```
$ git -C lib/stable-staker diff --stat c3ec65b HEAD -- src/
 src/CrossVersionMigrator.sol               | 162 ++
 src/InPlaceMigrator.sol                    | 384 ++
 src/StableStaker.sol                       |  16 +-      <-- the premise says this is unchanged
 src/StableStakerMigrator.sol               |  85 --
 src/interfaces/IStableStaker.sol           |  62 +-
 src/interfaces/IStableStakerMigratable.sol |  68 ++
 src/versions/IStableStakerV1.sol           | 203 ++
 src/versions/README.md                     |  89 ++

$ git -C lib/stable-staker log --oneline c3ec65b..HEAD -- src/StableStaker.sol
01a3e66 [story-016] Add STAKER_VERSION identity and write the snapshot ritual
51700cf [story-014] Bind StableStaker to the golden-rule migration interface
```

`src/StableStaker.sol` **did** change in that range — 16 lines across two commits. **The premise is
false as written.**

### The delivered artifact is nonetheless accurate — stated plainly

This must not be read as a claim that the snapshot is wrong. It is right, and that was verified
independently rather than taken from the story:

- **At the snapshot commit `c4f62ab`**, the only delta to `StableStaker.sol` versus `c3ec65b` was
  story-014's ABI-neutral retype: one import, one inheritance entry, four `override` keywords. **No
  member was added, removed, or re-signatured.**
- **Member-by-member check:** all 37 declared members of `src/versions/IStableStakerV1.sol` — 20
  external/public functions, the inherited migration triad, 10 public state-variable auto-getters,
  the `Ownable` triad, and 16 events (an extracted-declaration `diff` of the two files' event blocks
  is empty) — match `src/StableStaker.sol`.
- **Live on-chain selector probing** over mainnet RPC against
  `0xbce8ABC09BaEDCabE93419bF875f6186e182079A` confirmed **all 37 declared members resolve on the
  deployed contract: zero phantoms, zero signature drift, zero missing callable members.**
  Etherscan could not be used — the address is **unverified** — so this was direct selector probing
  with two validated controls.
- **`STAKER_VERSION` is correctly ABSENT from the snapshot.** On-chain, the getter reverts with empty
  return data, which independently corroborates `CrossVersionMigrator._versionOf`'s
  `!ok -> return 1` fallback against the real deployment
  (`src/CrossVersionMigrator.sol:157-161`).

No consumer binding `IStableStakerV1` to the live instance will hit a selector-does-not-resolve
revert today.

### The defect: procedural and forward-looking

Story-015 established, and story-016 wrote into `CLAUDE.md` as the standing ritual, that snapshots
are extracted **from master HEAD** rather than from the **deploy commit**:

> `CLAUDE.md`, §"The snapshot-on-deploy ritual", step 1:
> "Freeze the current external surface into `src/versions/IStableStakerV<N>.sol`, where `<N>` is the
> current value of `STAKER_VERSION`."

At today's HEAD that premise is **already materially false**. Story-016 added a real ABI member the
live instance lacks (`src/StableStaker.sol:53-57`):

```solidity
/// @dev The live V1 instance (0xbce8...079A) predates this constant and does NOT expose
///      it. Any version probe must therefore tolerate the call reverting — absence of
///      `STAKER_VERSION` means version 1.
uint256 public constant STAKER_VERSION = 2;   // :57
```

A future V2 snapshot author following the documented ritual, and relying on story-015's
now-false "zero drift risk" precedent, would freeze a surface that **was never deployed** — the exact
failure `src/versions/` exists to prevent. `CrossVersionMigrator`'s central design rationale
(section (A): the narrowest-possible-dependency argument) rests on these snapshots being faithful
records of deployed surfaces, so the extraction procedure not producing one is a live Law-2 defect
even while the current artifact is clean.

Story-015's own reviewer flagged the prose defect as `[low]` and carried it forward as non-blocking;
the story document still asserts the false premise.

### Recommended mitigation

Amend the `CLAUDE.md` ritual to pin snapshot extraction to the **deploy commit** (`git show
<deployCommit>:src/StableStaker.sol`), not master HEAD, and to record that commit in the snapshot's
NatSpec alongside the address — step 4 already asks for the source commit, which the current step-1
procedure cannot honestly satisfy. Correct story-015's Background.

Cross-reference: **Q-01** in `submissions/qa-report.md` records inaccuracies in this snapshot's own
NatSpec (the "16 events" claim and the "Known external coupling" block). A snapshot whose
self-description is inaccurate **and** whose deletion is missed by both purpose-built enforcement
layers (`L-03`, which a compile break does still catch incidentally) is weaker than either defect
implies alone.

---

## Claims that were tested and HELD

Recorded so this report is not read as one-sided. Both were re-derived, not accepted from the story.

### story-018's "strict functional superset" claim is TRUE

> "`CrossVersionMigrator` is a strict functional superset of it: same owner-only `initiateMigration`
> forwarder, same `batchMigrate` → sum → `forceApprove` → per-user `depositFor` loop, same
> `if (amounts[i] > 0)` zero-credit skip, same both-ends-immutable constructor. It adds only a
> narrower interface dependency, the version probe, and a richer event. **Nothing is lost
> behaviourally.**"

The deleted contract was recovered (`git show d95f4a6:src/StableStakerMigrator.sol`, 85 lines) and
compared member by member against `src/CrossVersionMigrator.sol`:

| Retired `StableStakerMigrator` | `CrossVersionMigrator` | Verdict |
|---|---|---|
| `constructor(IStableStaker, IStableStaker, address)`, two zero-address `require`s, both targets `immutable` | same shape, targets retyped `IStableStakerMigratable`, same `require`s, same `immutable` | preserved |
| `oldStaker()` / `newStaker()` public immutables | same (ABI-identical — both encode as `address`) | preserved |
| `initiateMigration(address) onlyOwner` forwarder | `:107-109`, identical | preserved |
| `migrate(address,address[]) onlyOwner` | `:118-143`, line-for-line equivalent | preserved |
| `event Migrated(address,uint256,uint256)` | `event MigratedAcrossVersions(...)` (+2 fields) | superset |
| — | `versionOf` / `_versionOf` probe `:153-161` | added |

The retired contract's **entire** surface was `constructor`, `initiateMigration`, `migrate`, two
immutable getters and `Ownable` — **no rescue, no sweep, no alternative entry point, no owner escape
hatch, no setter.** Nothing was lost. The claim holds. (The event rename is an off-chain indexing
break, but no live `StableStakerMigrator` instance exists, so nothing indexes the old topic.)

### story-014's compile-time bypass IS closed

Story-014's review nominated story-017 as the closer of this gap:

> "**The compile-time enforcement is bypassable** by deleting `, IStableStaker` from the inheritance
> list — an agent 'fixing the build' after removing a golden function could do exactly that."

Verified closed. The CI gate greps the **implementation file directly**
(`check-migration-surface.sh:27-50`):

```bash
IFACE=src/interfaces/IStableStakerMigratable.sol
IMPL=src/StableStaker.sol
PROTECTED=(initiateMigration batchMigrate depositFor)
for f in "$IFACE" "$IMPL"; do
  for name in "${PROTECTED[@]}"; do
    if grep -qE "function[[:space:]]+$name[[:space:]]*\(" "$f"; then echo "ok: $f declares $name"
    else fail "$f no longer declares '$name'." ; fi
```

Mutation (d) — removing a golden function from `StableStaker.sol` — exits `1` whether or not
`is IStableStaker` is present. `test/GoldenRule.t.sol:34-36` additionally pins the three selectors to
hard-coded bytes (`0x71726c92`, `0x0ad9aeb9`, `0xb3db428b`), catching a coordinated
interface-plus-implementation re-signature. Both checklist items are genuinely delivered.

---

## Law-1 override check — is any story's own intent unsafe?

No escalation. Assessed and cleared:

- **story-016**, `STAKER_VERSION = 2` while the deployed instance is V1 and reverts on the getter.
  Deliberate, reasoned in the story's Concerns, documented in the constant's NatSpec and in
  `CLAUDE.md`. The only consumer (`CrossVersionMigrator._versionOf`) implements the
  revert-means-1 contract correctly, and the probe is advisory only — no behaviour branches on it
  (§F, `:59-62`) — so a misread version cannot mis-route funds.
- **story-017**, the `GOLDEN-RULE-OVERRIDE` commit-message escape hatch: an intentional, loudly
  warned door for the day V1 is dead. Legitimate — a rule with no sanctioned exit gets worked around
  destructively. Nit: the hook matches the marker anywhere in the Bash command string (`:200`), so
  any commit message merely *containing* the phrase bypasses; low consequence, since the CI gate is
  independent of the hook.
- **story-017**'s disclosed hook blind spot (it fires only when `stable-staker` is the session
  project root, and this repo is normally driven as a submodule) is stated in `CLAUDE.md` layer 2 as
  a "Known gap" and is the stated reason the CI gate exists. Disclosed, not a finding.
- **story-018**, shipping a migrator with no top-up parity: deliberate product asymmetry, flagged in
  the story's own Concerns as *"a real product difference worth a human decision before this migrator
  is used on the live base"*. Law 3 applies. The **documentation** gap around it is `L-02`; the intent
  itself is not unsafe.
- **story-018**, deleting a contract that two `phase-2-staging` files import: breakage is intentional,
  scoped to the abandoned ys-swap saga, human-accepted, and recorded with the git recovery path.

## Faithful and verified — no finding

- **story-014** superset claim: `src/interfaces/IStableStaker.sol` at `d95f4a6` resolved to
  `{initiateMigration, batchMigrate, depositFor, userInfo}`; at HEAD it resolves to
  `IStableStakerMigratable{initiateMigration, batchMigrate, depositFor}` + `userInfo`. Identical
  member set, identical signatures. The three moved into the new parent interface verbatim (NatSpec
  relocated character-for-character), and the import path is unchanged for consumers. Acceptance bar
  *"must not change the deployed ABI or behaviour"* holds.
- **story-016**: `STAKER_VERSION` present at `src/StableStaker.sol:57` as `uint256 public constant`
  = `2` with the required NatSpec; the ritual is written into `CLAUDE.md` in all five steps;
  `src/versions/IStableStakerV1.sol` was not edited by the story; no `version()` function was added,
  per instruction.
- **story-018**: `grep -rn "StableStakerMigrator" src/ test/` is clean, and
  `src/InPlaceMigrator.sol`'s diff across `d95f4a6..HEAD` is comment-only (verified line by line —
  every changed line sits inside the header NatSpec block).

## Cross-references into the QA bundle

- **Q-02** — `migrate`'s two loops iterate different bounds (`amounts.length` at `:122` vs
  `users.length` at `:133`, indexing `amounts[i]`). A Law-2 nick against section (A)'s stated goal of
  surviving arbitrary future staker redesigns, but nil reach today; filed as QA.
- **Q-03** — `CLAUDE.md` over-states golden-rule enforcement layer 1 (see `L-03`, *Related but
  separate*).

---

## [L-08] Terminal migration ignores the set-aside buffer, haircutting users while liquid cushion sits idle <!-- id: ss14l8 -->

**Filed in full as a standalone section file:
[`L-08-set-aside-buffer-not-swept.md`](L-08-set-aside-buffer-not-swept.md)** (same directory).
It is kept separate rather than inlined because it is the only finding in this report whose
authority is a direct owner statement rather than a story document, and it carries its own
mitigation, safety argument and severity debate at length.

- **Issue ID:** `ss14l8` · **Fingerprint:** `f7991b64adc3503e1f57825d8f34eb213d233d3d85cc72724eb3c69dd6c99388`
- **Severity:** Low (the Medium counter-argument is argued in the file, and the call is the owner's)
- **Location:** `src/StableStaker.sol:472-475` (`initiateMigration`; root cause in `_routeExit:801-803`)
- **Authority (Law 2):** the owner's stated intent, 2026-08-28 — *"I want all yield and setAside
  buffer swept into principal during a migration… erring on the side of the user if possible."*
  The implementation deliberately does the opposite, and says so in its own comment.
- **In one line:** `R` is the strategy-withdrawal delta only, so the staker's idle set-aside buffer
  never enters `credit = amt * min(R, P) / P` — when a strategy is underwater every user is haircut
  while the liquid cushion sits unused on the same contract.
- **Cross-references (do not merge):** `ss14m1`/M-01 (`d1aa4060`, same function, different defect);
  `0790a76a`; `69c7666eee`; `0dca43f315`.
