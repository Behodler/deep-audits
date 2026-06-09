# Spec-Conformance Report — reflax-yield-vault

**Run:** reflax-yield-vault-14
**Audited commit:** `2f6774d`
**Channel:** Law-2 (Faithfulness to stories). This report is intentionally **separate from the QA/gas bundle** — these are story/spec deviations, not gas or style noise.

---

## Scope and conventions

This report collects the project's **faithfulness findings** (`F-XX`): places where the implementation, documentation, or a forward-looking integration constraint deviates from — or overstates — the `[story-NNN]` it derives from. Per the Three-Law hierarchy, a faithfulness deviation that *also* carries asset/value/availability impact would additionally receive an H/M label and an individual report; none of the entries below cross that line **at this commit**. F-03 is recorded here precisely because filing it at H/M now would be speculation on future code (known-invalid), yet dropping it would lose a real cross-protocol constraint — so it lives in this visible channel until the wiring lands.

| ID | Subject | Status | Origin | Severity-on-this-channel |
|----|---------|--------|--------|--------------------------|
| **F-03** | Cross-protocol integration assumption for deferred stable-staker M-05 wiring of `relinquishPrincipal` | open | **NEW (this run)** | Faithfulness — gates a **Medium re-eval** when the wiring lands |
| **F-01** | story-043 "provable solvency invariant" overstated (ERC4626 double round-down) | open | carryover (first seen run-12) | Faithfulness — negligible security impact |
| **F-02** | Stale `SurplusTracker` / `SurplusWithdrawer` NatSpec in `IYieldStrategy.sol` | open | carryover (first seen run-12) | Faithfulness — documentation only |

---

## F-03 — Cross-protocol integration assumption: deferred stable-staker M-05 wiring of `relinquishPrincipal` (NEW)

**Status:** open · **Origin:** new (reflax-yield-vault-14) · **Stories:** `story-045` (the `relinquishPrincipal` primitive), `story-046` (deposit/withdraw hoist)
**Location:** `src/AYieldStrategy.sol` — `relinquishPrincipal` / `_relinquishInternal` (impl `L620`; shared write-down `L638`); interface intent in `src/interfaces/IYieldStrategy.sol#L34-L41`
**Fingerprint:** `52f9b84a…` (`sha256(src/AYieldStrategy.sol:relinquishPrincipal:cross-protocol-double-count-integration-assumption)`, empty `entryPoint`, legacy hash form)
**Cross-reference:** deferred **stable-staker M-05** (`0dca43f3`) — a valid, owner-accepted Medium whose pro-rata-haircut fix is DEFERRED pending exactly this reflax `relinquishPrincipal` story.

### This is the headline of this run, and it is forward-looking by design

`story-045` introduced `relinquishPrincipal` as a **primitive staged ahead of its consumer**. There is **no callsite in stable-staker** (or anywhere outside reflax-yield-vault) at this commit — verified by grep across all nested submodules. The primitive therefore has no current asset impact; it is a contract the future caller must honor.

### What the story / spec says (intent)

The `IYieldStrategy.relinquishPrincipal` NatSpec states the intent precisely (`src/interfaces/IYieldStrategy.sol#L34-L41`):

> Write down the caller's own recorded principal by `amount`, WITHOUT touching the underlying vault's shares (no redeem/withdraw/transfer). Decrements both `clientBalances[token][msg.sender]` and `totalDeposited[token]`, preserving the invariant `totalDeposited == Σ clientBalances`. **Intended for a principal-only client (e.g. the stable-staker) to release dormant principal so the corresponding vault value flows to yield on recovery rather than remaining a principal claim.** Over-requests are capped to the caller's available principal. Client-gated (`onlyAuthorizedClient`).

The shared write-down body confirms the on-chain semantics (`src/AYieldStrategy.sol#L629-L638`):

> Shared write-down logic … Operates purely on recorded principal; agnostic to how that principal was credited. Decrements BOTH `clientBalances` and `totalDeposited` by the same (capped) amount and touches vault shares in NO way — no deposit/redeem/withdraw/swap/transfer.

### Actual behavior at this commit

The primitive is correct in isolation: it writes down one client's recorded principal, leaves the backing ERC4626 shares untouched, and thereby **releases that backing vault value as surplus to the remaining clients** (since `totalDeposited` drops while real share value does not). There is no defect *in reflax*. The exposure is entirely at the **integration boundary** that does not yet exist.

### The integration invariant that MUST hold

When the deferred stable-staker M-05 wiring lands and a stable-staker caller invokes `relinquishPrincipal`, the following cross-protocol invariant must hold for value to be conserved:

1. **Pay-out / write-off BEFORE relinquish.** The caller MUST settle the principal to its end user — pay it out, or write it off — **before** calling `relinquishPrincipal`. The reflax write-down is irreversible and share-silent; it must mirror a settlement that has already occurred on the stable-staker side, not anticipate one.
2. **No double-credit of the freed surplus to the same owner.** The caller MUST NOT *also* re-credit the resulting reflax-side surplus (the vault value that now flows to yield) back to the **same** owner whose principal it just settled. Doing both — settling the principal to the owner AND re-crediting the released surplus to that same owner — **counts the same value on both sides of the integration**: a cross-protocol double-count.

Stated as an invariant the stable-staker implementer can assert at the integration point:

> For any owner `o` and amount `p`: at most one of `{ stable-staker pays/writes-off p to o, reflax surplus released by relinquishing p is credited to o }` may take economic effect. The principal `p` is settled to `o` exactly once across both protocols.

### Severity disposition

- **This run:** Faithfulness only. No callsite exists; filing at H/M now would be "speculation on future code without demonstrated root cause" (explicitly known-invalid per the audit charter). Recorded — not dropped — per Law-1 so the constraint is audited when the wiring lands.
- **Gating re-eval:** This finding **gates a Medium re-evaluation** at the stable-staker integration point IF/WHEN the `relinquishPrincipal` caller wiring lands **and** violates the pay-out-then-relinquish / no-double-credit constraint. A cross-protocol value double-count is value-leak-with-stated-assumptions territory (C4 Medium). It binds to the deferred stable-staker **M-05** (`0dca43f3`).

### Recommendation (actionable for the stable-staker implementer)

When wiring `relinquishPrincipal` as the reflax-side of the deferred M-05 pro-rata-haircut fix:

- Assert that the principal has already been paid out or written off to the end user **before** the relinquish call (order it last in the settlement sequence, not first).
- Do **not** re-credit the freed reflax surplus to the owner whose principal was just settled; the surplus is intended to flow to *remaining* clients' yield, per the `relinquishPrincipal` intent, not back to the relinquishing owner.
- Add an integration test that fails if the same `(owner, amount)` is both settled on the stable-staker side and re-credited from the reflax surplus.
- Re-route this finding to a **Medium** with an individual report and PoC at that point.

---

## F-01 — story-043 "provable solvency invariant" overstated (carryover, open)

**Status:** open · **Origin:** carryover · **First seen:** reflax-yield-vault-12 · **Still present as of:** reflax-yield-vault-14
**Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L207-L210` — `_depositInternal` / `_creditedPrincipal` (related sites `L304, L312, L318, L323`)
**Fingerprint:** `ec9191e4…`
**Original report:** [`reports/reflax-yield-vault-12/findings/faithfulness/F-01-provable-solvency-invariant-overstated.json`](../../reflax-yield-vault-12/findings/faithfulness/F-01-provable-solvency-invariant-overstated.json)

### What the story / spec says

`story-043` (commit `a65dbf0`) and the `_creditedPrincipal` NatSpec (lines 207-210) describe the conservative-crediting design and characterize its solvency property as:

> `fairValueOfShares >= creditedPrincipal` — a **provable** solvency invariant.

### Actual behavior

`minOut = convertToShares(creditedPrincipal)` guarantees `sharesReceived >= minOut`, but because ERC4626 `convertToShares` and `convertToAssets` **both round DOWN**, the round-trip `convertToAssets(convertToShares(creditedPrincipal))` can land a few wei **below** `creditedPrincipal`. The chain therefore proves `fairValue >=` (a value possibly below `creditedPrincipal`), not `>= creditedPrincipal`. The **"provable" qualifier is overstated**; the conservative-crediting *intent* is faithfully implemented. The dust accumulates on flat markets but carries no realizable asset impact and is not exploitable.

### story-046 hoist note

This finding **survives the story-046 deposit/withdraw hoist unchanged** — the double-round-down logic was **relocated, not regressed**. It is an un-regressed faithfulness carryover (DEDUP-CAR-003), re-observed but not re-triggered by changed files this run; severity and status are unchanged.

### Recommendation

Amend the claim to `fairValue >= creditedPrincipal − dust`, **or** add a small protocol-favoring epsilon to `minOut` so the round-trip cannot dip below `creditedPrincipal`.

---

## F-02 — Stale `SurplusTracker` / `SurplusWithdrawer` NatSpec in `IYieldStrategy.sol` (carryover, open)

**Status:** open · **Origin:** carryover · **First seen:** reflax-yield-vault-12 · **Still present as of:** reflax-yield-vault-14
**Location:** `src/interfaces/IYieldStrategy.sol` — NatSpec at **L63** (`principalOf`) and **L75** (`totalBalanceOf`)
**Fingerprint:** `fd58cf00…`
**Original report:** [`reports/reflax-yield-vault-12/findings/faithfulness/F-02-iyieldstrategy-natspec-staleness.json`](../../reflax-yield-vault-12/findings/faithfulness/F-02-iyieldstrategy-natspec-staleness.json)

### What the story / spec says

`story-037` **removed** the `SurplusTracker` and `SurplusWithdrawer` contracts, interfaces, and tests from the project. After that story, the codebase should no longer document those systems as live.

### Actual behavior

`IYieldStrategy.sol` NatSpec still names the removed systems:

- `L63` (`principalOf` `@dev`): *"This is the basis for calculating surplus yield in the **SurplusTracker** system."*
- `L75` (`totalBalanceOf` `@dev`): *"…the accumulated yield that can be extracted via the **SurplusWithdrawer** system."*

This is **pure NatSpec staleness** — no in-scope code references the removed systems, no security or behavioral impact. (Surplus accounting today flows through `skimSurplus` / the `SurplusSkimmed` events, not the deleted Tracker/Withdrawer.)

### story-046 hoist note

**Un-regressed by the story-046 hoist** — the interface NatSpec was not touched, so the stale references persist exactly as before (DEDUP-CAR-003). Severity and status unchanged.

### Recommendation

Update the `IYieldStrategy` NatSpec to drop references to the removed `SurplusTracker` / `SurplusWithdrawer` systems; point readers at `skimSurplus` and the `SurplusSkimmed` event semantics instead.

---

## Triage

All three entries are `open`. Triage with `/ledger reflax-yield-vault`. F-03 is the action item for the **stable-staker** team: honor the pay-out-then-relinquish / no-double-credit invariant when wiring the deferred M-05 fix, and re-evaluate it to **Medium** at that integration point.
