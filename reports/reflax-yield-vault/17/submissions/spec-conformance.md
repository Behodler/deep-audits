# Spec-Conformance Report (Law-2 Faithfulness) — reflax-yield-vault-17

- **Project**: reflax-yield-vault · **Branch**: `master` · **Commit**: `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9` `[story-050] previewExitFor on IYieldStrategy`
- **Baseline**: `0110ce44e1b9da0944595765eb0ae12affc50d7e` (`branchBaselines.master`, run-16)
- **Date**: 2026-08-31

## Scope and conventions

Law-2 entries are reported **here**, never folded into the QA/gas bundle — a behavioural deviation from a story is
reported where the owner will see it even when its security impact is nil. Each F-17-xx below is the faithfulness
**channel** for a finding that is ledgered **once** under its Low/QA label; they are cross-references, **not**
separate ledger entries and **not** separate fingerprints.

| # | Deviation | Verdict | Ledgered as | Channel note |
|---|---|---|---|---|
| **F-17-01** | Base `previewExitFor`'s `netGuaranteed` is a **ceiling**, not the floor its NatSpec "guarantees" | DEVIATES · open | **L-18** / `5351fd4d3f8cf3cf` | Also in the QA bundle (security leg) |
| **F-17-02** | story-050 criterion 10 forbade the fee-aware `previewRedeem`, so the contract ships **two exit previews that disagree** | DEVIATES — *the criterion itself is the defect* | **L-19** / `302656e234435430` | Also in the QA bundle (value leg) |
| **F-17-03** | `ceilDiv` gross-up compensates the bps leg but not the ERC4626 share round-trip; `netGuaranteed` can land below `netWanted` | DEVIATES (dust) | **QA-10** / `e868f28953a9723a` | **Channel-only**: routed here, *not* into the QA bundle |
| **F-17-04** | story-025's mandated "measure the delta and revert" safeguard is **structurally incapable of firing** | DEVIATES — safeguard inert | **L-27** / `d9bd595066efb970` | **Cross-repo** (stable-staker), `F-03` precedent |

**Carryover:** the still-open faithfulness entries from prior audits are carried in full at
[`carryover/spec-conformance-12.md`](carryover/spec-conformance-12.md) (`F-01`, `F-02`),
[`carryover/spec-conformance-14.md`](carryover/spec-conformance-14.md) (`F-03`),
[`carryover/spec-conformance-15.md`](carryover/spec-conformance-15.md) (`F-04`, `F-05`) and
[`carryover/spec-conformance-16.md`](carryover/spec-conformance-16.md) (`F-16-003`).

---

## F-17-01 — the base default's `netGuaranteed` is a ceiling, not the floor its NatSpec "guarantees" (ledgered as L-18)

### What the story says (intent)

story-050 adds `previewExitFor` to `IYieldStrategy` as a pre-flight integration surface, and its NatSpec uses the
word **"guarantees"** for the returned `netGuaranteed`.

### What the code actually does

`AYieldStrategy.sol:571-583` computes `grossToRequest = min(netWanted, clientBalances[token][account])` and then
sets `netGuaranteed = grossToRequest`. It quotes **booked principal**, and models the vault share balance **not at
all**. Reached in production through `ERC4626YieldStrategy`, which does not override it.

### The gap

On a below-par position the published number is an **upper bound on what can be delivered**, not a lower bound
beneath it. Probe: `1000e18` quoted, `500e18` delivered after a 50% vault drawdown.

### Severity rationale (honest)

Filed at **Low**, not Medium: `previewExitFor` has **zero consumers** at every sibling repo's current top-level
HEAD (verified three times independently, untruncated), so the mis-quote is consumed by nobody today. The C4
"speculation on future code" invalid category does **not** apply — the root cause is demonstrated in code and by a
passing PoC; only the *consumer* is future.

**The Low rests on a contingency that nothing pins.** `StableStakerV2._isUnderwater` strictly dominates the
cap-binding condition on the armed `withdraw()` path (696 M-state exhaustive integer search over the live
semantics, 210 M cap-binding states, 0 counterexamples; 150 k fuzz + a 105-case grid against the real contracts in
the real two-client topology, with live vacuity tripwires — one fired and caught a vacuous first harness).
**This is not a Halmos proof: the symbolic tier returned 0 `[PASS]` / 7 `[TIMEOUT]`. Never write "symbolically
verified".** The dominance rests on two invariants — `p ≤ D` (`AYieldStrategy.sol:48`) and `a ≤ p` (`:772-776`) —
**neither of which any test pins** (`MR-17-05`). A future change breaking either re-arms this at **Medium with no
scanner signal**. `DominanceRun17Grounding.t.sol` is the runnable regression guard and should be kept.

### Recommendation

Model the share balance in the base preview as `_exitFloor` does, or strike "guarantees" from the NatSpec and
document the return as a non-binding upper estimate. **Non-collapse:** a fix that merely copies `_exitFloor` into
the base closes this and **spreads L-20 to the direct strategy** — fix them together.

---

## F-17-02 — story-050 criterion 10 is itself the source of the deviation (ledgered as L-19)

### What the story says (intent)

story-050 criterion 10 **deliberately forbade** `previewExitFor` from using `previewRedeem`, and the resulting
function's NatSpec nonetheless carries the word "guarantees".

### What the code actually does

Both previews derive `netGuaranteed` from the fee-free `vault.convertToAssets` (base at `:571-583`; market via
`_exitFloor` at `ERC4626MarketYieldStrategy.sol:127-137`, `convertToAssets` at `:133`). EIP-4626 requires
`previewRedeem` to express redemption fees and `convertToAssets` to ignore them. `ERC4626YieldStrategy` **already
exposes the fee-aware quote** at `:83-85`.

### The gap

The contract now ships **two exit previews that disagree by the vault's exit fee, with the newer one carrying the
word "guarantees"**. This is the unusual case where the deviation is not an implementation slip: the story's own
acceptance criterion mandates the fee-blind read.

### Severity rationale — measured, not assumed

`F-16-003`'s gate ("the gate must re-weigh severity against the *actual* vault wired at the integration point, not
inherit `ECON-A`'s stale Low") is **TRIPPED** this run by the deployed Tokemak wiring, and is **now adjudicated**
rather than carried a second time. Measured on mainnet at **block 25878009** against each deployed strategy's own
`vault()`:

| Autopool | `convertToAssets` | `previewRedeem` | Divergence |
|---|---|---|---|
| autoDOLA `0x79eB84B5…` | `1000000014462599280` | `999952721565253485` | `47292897345795` → **0.004729%** |
| autoUSD `0xa7569A44…` | `999999` | `999946` | `53` → **0.005300%** |

Divergence is **non-zero on both live Autopools and in the harmful direction** — the root cause is confirmed live,
not hypothetical — but at **~0.5 basis points** it is three orders of magnitude below anything the C4 Medium
value-leak limb contemplates, on a quote no code reads. **Neither `ECON-A`'s stale Low is inherited, nor a Medium
asserted on an assumed fee.** The finding rests at **Low on its spec-deviation weight**, which is where its real
substance lives.

> **⚠ Trigger correction, carried from the severity audit and load-bearing.** The classifier's escalation trigger
> read *"any non-zero divergence ⇒ Medium immediately"*. Divergence **is** already non-zero, so left as written
> that trigger is mechanically satisfied and would **manufacture a false Medium on 0.5 bps** at the next triage.
> **It is replaced by a magnitude threshold:** `convertToAssets`/`previewRedeem` divergence on a wired Autopool
> **≥ 10 bps**, or any step change in Tokemak's fee parameters ⇒ re-weigh to Medium.

### Recommendation

Read a fee-aware quote (`previewRedeem`, or subtract the measured delta). **`F-01-050`'s proposed remedy — cap by
`_positionValue()` — does not work**: `assertEq(posValue, net)` passes because `_positionValue` is built on the same
fee-blind conversion (`ERC4626YieldStrategy.sol:61-63`), making it numerically identical to the number it was meant
to correct.

---

## F-17-03 — the `ceilDiv` gross-up does not compensate the share round-trip (ledgered as QA-10)

### What the story says (intent)

story-050 claims `netGuaranteed >= netWanted` when no cap binds.

### What the code actually does

`previewExitFor` grosses the request up with `Math.ceilDiv` to compensate the slippage-bps leg, but the subsequent
`convertToShares` → `convertToAssets` round-trip **floors twice** and the `ceilDiv` does not compensate that.

### The gap

`netGuaranteed` can land **1 wei** below `netWanted`. Analytic bound `netWanted − netGuaranteed ≤ ⌈A/S⌉ + 2` raw
base units, confirmed by a 256-run fuzz with no counterexample, reproduced at near-unity and ~3× share prices.

### Severity rationale

**QA.** `ROUNDING-DIRECTION` classifies it **known-benign**: `ceilDiv` rounds the *request* up (protocol-favouring)
and the double floor rounds the *quote* down. **No user-favouring leg, no repeatable round-trip profit**;
`DIVISION-PRECISION` refuted (mul-before-div throughout).

**Channel disagreement with the source pass, resolved here.** Severity QA is agreed; the **channel** is not. A pure
behavioural deviation with no security impact is still a story deviation, so under Law 2 it is reported here and
**not** buried in the QA/gas bundle.

> **Process signal.** **Two consecutive stories (043, 050) have each claimed a provable property that the ERC4626
> double round-down does not deliver.** See `F-01` / `ec9191e420d54444` (open) — the **deposit** side of the same
> arithmetic. **Disclose, do not collapse:** different side, on a function that did not exist at `F-01`'s commit.

### Recommendation

Compensate the share round-trip in the gross-up, or correct story-050's claimed property to state the dust
tolerance explicitly. Line-citation note: the gross-up statement is at **line 176** at `cdd0743`, not `:174`
(`:174` is the closing brace of the `denominator == 0` guard).

---

## F-17-04 — story-025's mandated safeguard is structurally incapable of firing (ledgered as L-27, cross-repo)

### What the story says (intent)

story-025 mandates that `_routeExit` **measure the delta actually received and revert** when a lying preview leaves
the consumer short, and its acceptance test requires asserting *"the idle buffer is untouched … in the lying-preview
scenario"*. Story state folder: **`incomplete`** — a landed dependency whose story is not closed out is itself worth
the owner's attention.

### What the code actually does

Verified directly against `lib/stable-staker` HEAD (`fa06de5`), `src/StableStakerV2.sol:876` `_routeExit`:

```solidity
if (guardUnderwater && _isUnderwater(token, strategy)) {
    if (t.balanceOf(address(this)) >= amount) {
        emit BufferWithdrawn(token, msg.sender, amount);
        strategy.relinquishPrincipal(token, amount);
        return amount;                      // <-- full requested amount, from idle
    }
    revert("StableStaker: strategy underwater");
}
```

and against reflax `AYieldStrategy._relinquishInternal` (`:700-716`), whose NatSpec states *"vault shares are
deliberately untouched"* — confirmed: the body writes `clientBalances` and `totalDeposited` only, **no external
call, zero assets moved**.

### The gap

The underwater branch returns `amount` unconditionally, so **`received == needed` by construction**, the mandated
`StableStaker:` revert is **unreachable on that path**, and story-025's acceptance test passes trivially against a
full-credit mock while being **unsatisfiable against a real below-par strategy**. **A green checklist here is a
false negative.**

Downstream: the buffer is thin by construction (10% of skim proceeds, `MigrateStableStakerMainnet.s.sol:597`); one
large staker's whole-position `autoAnnihilate` empties it, after which `_routeExit` takes
`revert("StableStaker: strategy underwater")` and **every other staker's `withdraw()` is bricked** until the
position recovers or the owner refunds.

### Filing correction (applied)

The defect is **entirely in `StableStakerV2._routeExit`**, not in reflax `previewExitFor` — reflax's preview is not
wrong here and `relinquishPrincipal` behaves exactly as documented. It is therefore fingerprinted on
`StableStakerV2._routeExit` and carried as a **cross-repo integration entry**, following the existing
`F-03` / `52f9b84a54ec9a65` precedent in this ledger. This is **not** the "issues in parent/forked contracts where
root cause is OOS" heading: `stable-staker` is a registered, **first-party, separately-audited** project in this
suite. Cross-repo is a **routing** question here, never an invalidity one.

### Severity rationale

**Low**, capped behind a dated trigger. **Availability, not value leak** — buffer depletion itself is **opportunity
cost** under the externally-derived-yield rule and is **explicitly not filed as a leak**. The naive "consumer trusts
`netGuaranteed`, buffer eats the difference" finding is deliberately **not** filed.

**Escalation to Medium requires the conjunction of all three:** (1) `stable-staker` bumps `lib/reflax-yield-vault`
to a story-050 commit **and** lands `autoAnnihilate`; (2) `autoAnnihilate` sources through
`_routeExit(..., guardUnderwater = true)`; (3) the wired strategy can go below par (**true today** for both
Tokemak-Autopool direct strategies and the USDe market strategy).

### Recommendation

Make the safeguard fire on the **shortfall** rather than on `received < needed` (which cannot occur on this branch),
and revise story-025's acceptance test so it is satisfiable against a real below-par strategy rather than only
against a full-credit mock.

**Gates:** rides the existing `F-03` / `52f9b84a54ec9a65` gate and feeds `QA-09` / `86409a56b6fc3c8b`. **Not a
duplicate of either** — `F-03` is double-counting across the call; this is the consumer's own safeguard being inert.
**Handle both gates in the same pass as `WATCH-17-03`.**

---

## Conformance verification records (no findings)

- **story-050 behaviour otherwise CONFORMS.** `previewExitFor` is declared on `IYieldStrategy.sol:79`, implemented
  on the base at `AYieldStrategy.sol:571-583` and overridden by the market strategy at
  `ERC4626MarketYieldStrategy.sol:162-186`; the diff is purely additive (`+171` lines across four `src/` files).
- **`WATCH-17-02` (parked as `MR-17-07`) — the Law-2 baseline under this run is soft.** story-050 sits in
  `auto-complete` with the trailer *"Approved by: story-batch workflow (machine approval — not human-reviewed)"*,
  and both its Execute and Review steps ran `--inline-delegation` with a self-declared *"Independence: reduced"*.
  **`F-17-01` and `F-17-03` are both inside the blind spot that review declared out of its own reach.** If the
  acceptance criteria are later revised, the Law-2 baseline under several findings here moves.

## Triage

Triage these with `/ledger reflax-yield-vault`. Each F-17-xx is a channel for a single ledgered finding — triaging
the Low/QA entry triages the faithfulness leg with it.
