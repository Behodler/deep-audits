# Story-Faithfulness Report — stable-staker run-12

- **Project:** stable-staker
- **Submodule HEAD:** `ffa4947` — `[story-012] Add InPlaceMigrator: in-place single-staker yield-strategy swap`
- **Scope:** `src/InPlaceMigrator.sol` (new, +316 LOC) — regression mode
- **Scan type:** story-faithfulness (Law 2, with Law-1 override check)
- **Stories checked:** `story-012` (origin); cross-referenced `story-010` (empty-pool gate), `story-011` (depositFor zero-credit guard), `story-003`/`story-004` (`min(R,P)/P` socialization).

---

## 1. Story-012 intent (verbatim source quotes)

There is **no `docs/` design narrative** for in-place migration (grep of `lib/stable-staker/docs/`
returned nothing; the dir does not exist). Intent is resolved from three in-repo sources, in
priority order:

**(a) Commit body** (`git show ffa4947`):
> "Drains users into the migrator's own custody (migrateOut -> park), lets the operator run
> finalizeAndReset + setYieldStrategy on the now-empty pool, then **re-injects the same users into
> the same staker** (migrateIn). Permissionless self-only claimTimedOut escape hatch returns
> principal if the operator stalls."

**(b) Source NatSpec — the acceptance-criteria text:**
- (A), `InPlaceMigrator.sol:16`: *"This contract **safely** changes a per-token dependency (e.g. an
  `IYieldStrategy`) on a single live `StableStaker` …"*
- `migrateIn` NatSpec, `InPlaceMigrator.sol:168-169`: *"Re-inject a slice `[start, end)` of
  currently-parked users back into the SAME staker, **crediting each user the exact principal that
  was parked for them.**"*
- (F), `InPlaceMigrator.sol:50-52`: the timeout hatch *"returns PRINCIPAL ONLY"* — phUSD already
  minted at `migrateOut`.

**(c) Project CLAUDE.md** (the standing invariant the story inherits):
- *"`src/StableStakerMigrator.sol` — moves a batch of users from one `StableStaker` to another …
  **preserving principal** and minting earned rewards."* (InPlaceMigrator is the in-place sibling
  of this tool — same principal-preservation contract.)
- *"Stakers only ever get their **principal** back plus phUSD emissions."*
- *"`setYieldStrategy` reverts … unless `totalStaked == 0` … To change strategy on a live pool,
  drain it to empty via the terminal migration runbook … and then wire the fresh strategy on the
  revived empty pool."* (story-010 — the gate this contract is the orchestration tool for.)

**Distilled acceptance criteria:**
- **AC-1 (par-preservation on re-injection):** each user re-injected via `migrateIn` is credited
  the *exact* principal parked for them on the same staker.
- **AC-2 (principal recoverable):** the timeout hatch returns each user's full parked principal.
- **AC-3 (safety):** the orchestrated drain/park/refill is a *safe* substitute for the forbidden
  hot-swap — i.e. it must not re-introduce the loss vectors the empty-pool gate (story-010) was
  built to eliminate.

---

## 2. Findings

### F-12-001 — `migrateIn` zeroes full parked amount but credits only the (possibly haircut) strategy return — violates AC-1 "exact principal"
- **type:** faithfulness (+ Law-1 override candidate — see §3)
- **verdict:** **DEVIATION** (UNSAFE-STORY if the design intends silent socialization; see §3)
- **severity:** potential-medium
- **contract / function:** `src/InPlaceMigrator.sol` — `migrateIn`
- **line:** 215 (`parked[token][user] = 0`) vs 223 (`staker.depositFor(token, user, amt)`);
  range 207-224.
- **specText:** story-012 `migrateIn` NatSpec, `InPlaceMigrator.sol:168-169` — *"crediting each
  user the **exact principal that was parked** for them"*; reinforced by CLAUDE.md *"Stakers only
  ever get their principal back."*
- **specSource:** source NatSpec at HEAD `ffa4947` + project CLAUDE.md "Yield strategies" /
  "Terminal migration" sections.
- **actualBehavior:** `migrateIn` zeroes `parked[token][user]` to the full parked `amt`
  (`InPlaceMigrator.sol:215`), decrements `totalParked` by the full `amt` (line 217), then calls
  `staker.depositFor(token, user, amt)`. Inside the staker, `depositFor` credits **not `amt`** but
  the return of `_routeDeposit` (`StableStaker.sol:631-633`): `credited = strategy.deposit(token,
  amount, this)` (`StableStaker.sol:762`). For any haircutting strategy (AMM/ERC4626 deposit
  slippage, MockYieldStrategy with `depositSlippageBps > 0` at `MockYieldStrategy.sol:82`),
  `credited < amt`. The user's on-staker `info.amount` is therefore `< parked`, while the migrator
  has irreversibly zeroed their parked balance. **The shortfall is silently absorbed by the user**;
  there is no event, no revert, no residual `parked` to reclaim.
- **deviation:** AC-1 requires the *exact* parked principal be re-credited. The implementation
  guarantees the *exact `amt` is pulled from the migrator and approved* (the migrator-side
  accounting is internally consistent — INV-1 holds), but does **not** guarantee the *user is
  credited that amount* on the revived pool. "Exact principal parked" is honoured on the debit side,
  broken on the credit side.
- **lawImpacted:** 2 (faithfulness) — escalates to 1 under §3.
- **confidence:** high (mechanism verified end-to-end in source; the only thing that makes it
  benign is a par-preserving strategy, which is exactly what the tests use and the operator may not
  have at re-injection time).
- **note on testing:** all 14 `InPlaceMigrator.t.sol` tests construct `new MockYieldStrategy()`
  with default (zero) `depositSlippageBps`, so this path is **untested against a haircutting
  strategy**. The contract's own (A) NatSpec asserts the swap is "safe"; the safety claim is unproven
  for the realistic (haircutting) strategy class that motivates a strategy swap in the first place.

---

### F-12-002 — Running the in-place flow on a below-par (underwater) strategy parks less than original principal — AC-1 broken at the OUT leg
- **type:** faithfulness / footgun (Law 3 — non-obvious owner consequence)
- **verdict:** **DEVIATION** (faithful to the *staker's* `min(R,P)/P` socialization, but contradicts
  story-012's "made whole" framing — a genuine intent conflict)
- **severity:** potential-low-to-medium (operational hazard)
- **contract / function:** `src/InPlaceMigrator.sol` — `migrateOut` (consumes
  `StableStaker.batchMigrate` → `_exitPosition`)
- **line:** `InPlaceMigrator.sol:153` (`parked[token][users[i]] += amt`) where `amt` is the staker's
  realized credit `p_i·min(R,P)/P` computed at `StableStaker.sol:527-528`.
- **specText:** story-012 (A) `InPlaceMigrator.sol:16` *"safely changes a per-token dependency"* +
  CLAUDE.md *"preserving principal"*. The contract presents itself as a strategy-*rewire* tool, not
  a loss-realization event.
- **specSource:** source NatSpec + CLAUDE.md "Terminal migration mode" (`min(R,P)/P`).
- **actualBehavior:** `initiateMigration` realizes the old strategy at `R`; if `R < P` (strategy was
  underwater), `_exitPosition` caps each credit at `p_i·R/P < p_i` (`StableStaker.sol:527`). The
  migrator parks exactly that haircut credit (`migrateOut`), and `migrateIn` later re-credits only
  that. The underwater delta is **permanently lost** to every staker, with no on-migrator signal.
- **deviation:** This is *faithful* to the documented staker socialization (story-003/004) and is
  therefore **not a new bug in the migrator** — but it is a non-obvious operator footgun. The
  empty-pool gate's runbook and the migrator's "safely changes a per-token dependency" framing
  invite an operator to run this flow to *swap an impaired strategy*, which is precisely when `R<P`
  and the flow silently realizes the loss. Note `initiateMigration` is deliberately **not** blocked
  by the underwater guard (CLAUDE.md: escape hatch / migration always work). A competent operator
  would be surprised that "rewire the strategy" also means "realize the current underwater loss for
  every user." → **report as operational hazard with safe-config guidance** (only run on an at/above-
  par strategy; check `withdrawDisabled(token)` / `_isUnderwater` first).
- **lawImpacted:** 2/3.
- **confidence:** high.

---

### F-12-003 — `depositFor` revert-on-zero-credit can brick a whole `migrateIn` slice; un-creditable user stuck until timeout
- **type:** faithfulness / availability (interaction with story-011 guard)
- **verdict:** **DEVIATION** (availability of the migration, not loss) — operational hazard
- **severity:** potential-low
- **contract / function:** `src/InPlaceMigrator.sol` — `migrateIn`
- **line:** 223 (`staker.depositFor`) → `StableStaker.sol:632` `require(credited > 0, "nothing
  credited")` (story-011, `c3ec65b`).
- **specText:** story-012 commit body — *"re-injects the same users into the same staker"* (the
  story promises the batch round-trips the users back).
- **specSource:** commit body + story-011 guard.
- **actualBehavior:** if a high-slippage strategy haircuts a dust user's `amt` to zero credit,
  `depositFor` reverts; because `migrateIn` processes the slice in one transaction with no per-user
  try/catch, the **whole slice reverts**. The operator must re-page around the bad user, who remains
  parked until `claimTimedOut`. No value lost (user can self-recover principal), but the story's
  clean "re-inject everyone" path does not hold for that user.
- **deviation:** story implies a complete round-trip; implementation can strand individual users on
  a haircutting strategy. Faithful "skip already-claimed (amt==0)" handling exists (line 210), but
  there is no handling for *strategy-credits-zero*.
- **lawImpacted:** 2.
- **confidence:** high (mechanism), medium (likelihood — needs a genuinely high-slippage strategy +
  dust position).

---

## 3. Law-1 override analysis — is story-012's own intent unsafe?

**Question (from the task):** story-012 re-enables in-place yield-strategy migration that the
story-010 empty-pool gate deliberately forbade (because of underwater/haircut/slippage harms
M-01/M-05/M-06/M-07). Does the *intended* design re-introduce those vectors?

**Finding:** **PARTIALLY — the haircut/slippage residual (M-07 class) is RE-INTRODUCED at the
re-injection leg, but the gate's actual job (the desync the gate was built to prevent) is NOT.**

- **What the empty-pool gate (story-010) actually prevented:** an *in-place `setYieldStrategy` swap
  on a live pool* would sweep idle into a new strategy / leave principal accounting desynced from
  the strategy's `principalOf` while `totalStaked > 0` (M-01/M-06/M-07). story-012 does **not** do a
  hot-swap — it drains the pool to genuinely `totalStaked == 0`, so the gate is satisfied *honestly*
  (per profile §4 ordering hazards). The desync the gate forbids does **not** occur: the pool is
  truly empty at `setYieldStrategy` time. **This part of story-012 is safe and is a legitimate use
  of the runbook CLAUDE.md itself documents.** ✅

- **What story-012 re-introduces:** the M-07-class *deposit-haircut / execution-slippage* residual
  is **relocated** from the (now-impossible) swap into the `migrateIn → depositFor` leg (F-12-001).
  The user is re-deposited into the NEW strategy and credited only the strategy's haircut return,
  while the migrator has booked them as fully repaid. This is the same "credited < requested" loss
  the gate-era reasoning worried about — the gate did not *eliminate* it, it *forbade the path that
  triggered it on a live pool*; story-012 re-opens a path that triggers it. ⚠️

**Verdict on the story:** story-012's *intent* — "safely change a strategy on a live staker" — is
**not faithfully safe as written**, because the "made whole / exact principal" promise (AC-1) is
unconditionally asserted (NatSpec (A)/(F), CLAUDE.md "principal back") while the implementation only
delivers it for a *par-preserving* strategy. A faithful reading of the safety claim is **falsified
by a haircutting target strategy** — exactly the realistic case. This is therefore flagged as a
**story-safety concern (Law-1 override candidate)**: do not bless the "safe" claim. The concrete
loss vector is F-12-001; its security/value impact (silent per-user principal underpayment on
re-injection) is handed to econ-scanner for severity classification (it competes for Medium —
value leak under the stated assumption that the new strategy haircuts deposits; not High because it
requires an owner to run the flow against a haircutting strategy, an in-scope *non-obvious footgun*,
and the loss is bounded by the deposit slippage, not a full drain).

**No fabricated criteria:** AC-1/AC-2/AC-3 are all directly quoted from in-repo NatSpec/CLAUDE.md;
no acceptance criterion was invented.

---

## 4. Items that are FAITHFUL (checked, no finding)

- **AC-2 (timeout hatch returns full principal):** `claimTimedOut` transfers `parked[msg.sender]`
  in full (`InPlaceMigrator.sol:240-254`), CEI-guarded, self-scoped, principal-only. **FAITHFUL.**
  (Returns the *parked* amount — which is itself the realized credit, see F-12-002, not the
  pre-migration principal; faithful to what was parked.)
- **Immutable staker target (D):** no owner-supplied re-injection sink; matches story intent that a
  compromised key cannot strand parked users at a malicious target. **FAITHFUL.**
- **Rescue floor (G):** `rescueERC20` fenced below `totalParked` (`InPlaceMigrator.sol:271-272`).
  Cannot touch parked principal while `balanceOf ≥ totalParked` (holds — INV-3). **FAITHFUL.**
- **Idempotent `migrateOut` re-run:** `+=` with `batchMigrate` returning 0 for exited positions;
  no double-park. **FAITHFUL.**
- **No double-pay across `migrateIn` / `claimTimedOut`:** zeroed `parked` + set removal; the other
  path skips on `amt==0`. **FAITHFUL.**
- **Empty-pool gate honoured honestly:** `setYieldStrategy` reached only after the pool is genuinely
  drained to `totalStaked==0`; the gate is satisfied, not bypassed. **FAITHFUL** (and the core of
  why the orchestration is legitimate — see §3).

---

## 5. Structured output

```json
{
  "project": "stable-staker",
  "scanTimestamp": "2026-06-15T00:00:00Z",
  "scanType": "story-faithfulness",
  "storiesChecked": ["story-012"],
  "findings": [
    {
      "id": "F-12-001",
      "type": "faithfulness",
      "faithfulness": true,
      "securityEscalation": true,
      "storyTag": "story-012",
      "severity": "potential-medium",
      "contract": "src/InPlaceMigrator.sol",
      "function": "migrateIn",
      "line": 215, "lineStart": 207, "lineEnd": 224,
      "specText": "story-012 migrateIn NatSpec (InPlaceMigrator.sol:168-169): \"crediting each user the exact principal that was parked for them\"; CLAUDE.md: \"Stakers only ever get their principal back\".",
      "specSource": "source NatSpec @ffa4947 + project CLAUDE.md",
      "actualBehavior": "migrateIn zeroes parked[user] to full amt and decrements totalParked by full amt, then depositFor credits only _routeDeposit return (strategy.deposit can return < amt). User credited less than parked; shortfall silently absorbed, no residual, no event.",
      "deviation": "AC-1 'exact principal' honoured on debit side, broken on credit side for any haircutting strategy. Untested (mock uses zero slippage).",
      "lawImpacted": 1,
      "confidence": "high"
    },
    {
      "id": "F-12-002",
      "type": "faithfulness",
      "faithfulness": true,
      "securityEscalation": false,
      "storyTag": "story-012",
      "severity": "potential-low",
      "contract": "src/InPlaceMigrator.sol",
      "function": "migrateOut",
      "line": 153, "lineStart": 145, "lineEnd": 163,
      "specText": "story-012 (A) InPlaceMigrator.sol:16 'safely changes a per-token dependency'; CLAUDE.md 'preserving principal'.",
      "specSource": "source NatSpec + CLAUDE.md Terminal migration mode (min(R,P)/P)",
      "actualBehavior": "On an underwater strategy (R<P), batchMigrate caps credit at p_i*R/P (StableStaker.sol:527); migrateOut parks only that haircut, migrateIn re-credits only that. Underwater delta permanently lost, no migrator-side signal.",
      "deviation": "Faithful to staker socialization (story-003/004) -> NOT a new migrator bug, but contradicts 'safe rewire / preserving principal' framing; non-obvious operator footgun.",
      "lawImpacted": 3,
      "confidence": "high"
    },
    {
      "id": "F-12-003",
      "type": "faithfulness",
      "faithfulness": true,
      "securityEscalation": false,
      "storyTag": "story-012",
      "severity": "potential-low",
      "contract": "src/InPlaceMigrator.sol",
      "function": "migrateIn",
      "line": 223, "lineStart": 207, "lineEnd": 224,
      "specText": "story-012 commit body: 're-injects the same users into the same staker'.",
      "specSource": "git commit ffa4947 body + story-011 guard (StableStaker.sol:632)",
      "actualBehavior": "If new strategy haircuts a dust user to zero credit, depositFor's require(credited>0) reverts the WHOLE slice; user stuck parked until claimTimedOut. No per-user try/catch.",
      "deviation": "Story implies complete round-trip; a single un-creditable user can block any slice containing it. No loss (self-recover), but migration availability deviation.",
      "lawImpacted": 2,
      "confidence": "high"
    }
  ]
}
```
