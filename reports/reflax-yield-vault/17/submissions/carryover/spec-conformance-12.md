> **Carryover spec-conformance report — audit 12** (cut down from `reports/reflax-yield-vault/12/submissions/spec-conformance.md`).
> Retained below (still open / untriaged as of audit 17): **F-01, F-02**.
> Removed as carried elsewhere: none — both run-12 faithfulness entries are still open.
> Labels are the originals. Law-2 faithfulness entries are carried in this channel, **never** folded into the QA bundle.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping**:
> - `F-01` → `ec9191e420d54444`
> - `F-02` → `fd58cf00a7e3abab`

*The text below is a verbatim copy of the retained sections of the original report.*

---

## F-01 — story-043 "provable solvency invariant" is overstated by ERC4626 double round-down dust

- **Severity:** Faithfulness (informational / spec-claim drift) — **no security impact demonstrated**
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L207-L210` (`_creditedPrincipal` NatSpec / `_depositInternal`), additional sites L304, L312, L318, L323
- **Fingerprint:** `ec9191e420d544443d4625c9b2150cf725b06328b41eb4c58e0ff2572bb5ee04`
- **Derives from:** story-043 (commit `a65dbf0` body) and the `_creditedPrincipal` NatSpec, lines 207-210

### What the story/spec says

story-043, restated in the `_creditedPrincipal` NatSpec (L207-L210), claims:

> "`fairValueOfShares >= creditedPrincipal` — a **provable** solvency invariant."

The intended design is conservative crediting: a deposit sets `minOut = convertToShares(creditedPrincipal)` and requires `sharesReceived >= minOut`, so the strategy is never credited with more principal than the shares it actually received are worth.

### What the code actually does

The conservative-crediting *intent* is faithfully implemented — `sharesReceived >= minOut` is enforced. However, the literal "**provable** `fairValue >= creditedPrincipal`" claim does not hold exactly, because ERC4626 `convertToShares` **and** `convertToAssets` both round **down**:

```
convertToAssets( convertToShares(creditedPrincipal) )  <=  creditedPrincipal
```

The round-trip can land a few wei **below** `creditedPrincipal`. So what is actually proven is `fairValue >= (a quantity that may itself be sub-wei/few-wei below creditedPrincipal)` — i.e. `fairValue >= creditedPrincipal - dust`, not the strict `fairValue >= creditedPrincipal` the story asserts as "provable." The dust accumulates on flat (no-yield) markets where the round-trip is exercised repeatedly without appreciation to mask it.

### The gap

The deviation is in the **word "provable"**: the invariant is correct up to ERC4626 double-round-down dust, but the story states it as an exact, provable bound. This is a spec-claim overstatement, not a behavioural defect — the implementation is, if anything, *more* conservative than a naive reading would expect.

### Severity rationale (honest)

**Informational / faithfulness only.** The discrepancy is sub-wei to few-wei rounding dust per deposit, always rounding in the protocol's favor on the crediting side. There is **no realizable asset impact**, no attack path, and no exploitability — it is an always-present rounding artifact inherent to ERC4626. The conservative-crediting behavior the story actually cares about conforms; only the absolute "provable" qualifier is too strong.

### Cross-reference to the solvency-accounting findings (M-01-run12 / M-02)

F-01 sits in the **same solvency-accounting area** discussed by this run's `M-01-run12` (classified **invalid**) and the **acknowledged `M-02`** (realizable-value vs. vault-rate gap). F-01 is best read as the **documentation-level shadow** of that realizable-vs-vault-rate gap: the "provable solvency" wording overstates exactness in exactly the spot where realizable value can diverge from the vault's quoted rate. **It carries no additional security impact beyond the already-acknowledged M-02** — it neither widens that gap nor introduces a new one; it only flags that the story's prose claims more precision than the rounding model delivers. No new H/M label is warranted.

### Recommendation

Amend the story-043 claim to `fairValue >= creditedPrincipal - dust` (acknowledge the ERC4626 round-down), **or** add a small protocol-favoring epsilon to `minOut` so the round-trip cannot dip below `creditedPrincipal` and the original wording becomes literally true.

---

## F-02 — IYieldStrategy NatSpec still names the SurplusTracker / SurplusWithdrawer systems that story-037 removed

- **Severity:** Faithfulness (informational / doc staleness) — **no security impact**
- **Location:** `src/interfaces/IYieldStrategy.sol#L49-L61` (NatSpec, lines 49 and 61)
- **Fingerprint:** `fd58cf00a7e3abab634aefca50035f352ecad9f4ec945cf906fc31f024dfac26`
- **Derives from:** story-037 (removed the SurplusTracker / SurplusWithdrawer systems)

### What the story/spec says

story-037 **removed** the SurplusTracker and SurplusWithdrawer systems: their contracts, interfaces, and tests were deleted. The post-story-037 reality is that no in-scope code implements or references those systems.

### What the code/doc actually does

`IYieldStrategy.sol` NatSpec was not updated to match. It still names the deleted systems:

- **Line 49:** references "the SurplusTracker system"
- **Line 61:** references "the SurplusWithdrawer system"

No in-scope code references the removed systems — the staleness is confined to the interface's documentation comments.

### The gap

The interface NatSpec documents architecture that story-037 deleted. A reader of `IYieldStrategy` would be led to believe SurplusTracker/SurplusWithdrawer still exist. Pure doc/spec drift against the story-037 reality.

### Severity rationale (honest)

**Informational / faithfulness only.** This is pure NatSpec staleness with **no code behind it** and therefore **no security consequence whatsoever** — nothing reads, branches on, or depends on the removed systems. It is surfaced as an `F-XX` (rather than buried in the gas/style bundle) solely because Law-2 requires story deviations to remain visible to the owner, even when impact is nil.

### Recommendation

Update the `IYieldStrategy` NatSpec (lines 49 and 61) to drop the references to the removed SurplusTracker / SurplusWithdrawer systems.

---
