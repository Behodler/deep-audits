# Spec-Conformance Report — yield-claim-nft (run-11)

**Story under review:** `story-035` — *Add NudgeRatchet dispatcher + mint-debt hook (200% max / 100% default)*
**Audited commit:** `b8322ee83725ccba97a0ca5d1ddc5210aadb8441`
**Channel:** Law-2 faithfulness (spec-conformance). This report is **separate from the QA bundle**.
**Faithfulness record:** `F-02-035` (`reports/yield-claim-nft/11/findings/faithfulness/F-02-035-nudgeratchet-story-035-deviations.json`)

> **Labeling note.** This record is `F-02-035` (story-035-scoped), *not* bare `F-02`.
> Bare `F-02` is already taken by ledger entry `L-05`'s `faithfulnessTag`; using the
> story-scoped form avoids a label collision.

This report assesses whether `story-035`'s `NudgeRatchet` dispatcher and
`NudgeRatchetMintDebtHook` do what the story directs. Two deviations are recorded
(one Law-1 escalation, one cosmetic Law-2); the remaining acceptance criteria are
conformant and noted briefly at the end.

---

## F-02-035 (a) — Faithful-but-unsafe story: decimal-scale mint-debt under-mint (Law-1 escalation)

**Cross-ref:** Medium **M-03** (`reports/yield-claim-nft/11/submissions/M-03-submission.md`) — full description, impact, attack path, PoC, and recommendation live there. This section records the *faithfulness* dimension only.

### Story text (what was directed)

From the `story-035` commit message (`b8322ee`):

> `[story-035] Add NudgeRatchet dispatcher + mint-debt hook (200% max / 100% default)`
>
> - `src/V2/hooks/NudgeRatchetMintDebtHook.sol`: **near-copy of BalancerPoolerMintDebtHook**
>   with `MAX_RATIO=200` / `DEFAULT_RATIO=100`, inclusive setRatio guard, accurate ratio NatSpec.

The story directs the hook to be a **near-copy** of the existing `BalancerPoolerMintDebtHook`.
The parent hook computes its phUSD mint-debt with the formula `(amount * ratio) / 100`.

### Actual behaviour (what the code does)

`NudgeRatchetMintDebtHook.onDispatch` (`src/V2/hooks/NudgeRatchetMintDebtHook.sol:114`) copies the parent formula verbatim:

```solidity
function onDispatch(address minter, uint256 amount, bytes calldata) external {
    if (msg.sender != dispatcher) revert OnlyDispatcher();
    uint256 added = (amount * ratio) / 100;   // line 114
    if (added == 0) return;                     // line 115 — silent no-op guard
    mintDebt += added;
    emit DebtAccrued(minter, amount, added, mintDebt);
}
```

The critical difference the story did not account for: the **parent is fed 18-decimal USDS**,
but `NudgeRatchet` is **deploy-guarded to 6-decimal USDC**
(`src/V2/dispatchers/NudgeRatchet.sol:38`):

```solidity
require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");
```

while phUSD is 18-decimal. The verbatim `(amount * ratio) / 100` carries **no `*1e12`
normalization** between the 6-dp input `amount` and the 18-dp phUSD mint-debt output.

### Why this is a Law-1 case (flag the unsafe story)

A **faithful** implementation of the story — a literal near-copy of the parent's formula —
is therefore **economically wrong by ~1e12×** (an under-mint). Across the realistic USDC
operating range the computed `added` rounds below the line-115 guard threshold, so the
mint-debt accrual silently no-ops and the entire feature does nothing.

This is the canonical Law-1 *"flag the unsafe story"* situation: the story's own directed
behaviour (a verbatim near-copy) would ship a broken/economically-wrong feature. Under the
three-law hierarchy, Law-1 (no exploits / no broken-value accounting) overrides Law-2
faithfulness — we flag the **unsafe story**, rather than blessing a faithful-but-wrong
implementation. Because the deviation **also** has value-tracking impact, it additionally
carries an H/M label (**M-03**) with a full report and a passing PoC
(`workspace/yield-claim-nft/test/poc-M01-decimal-undermint.t.sol`: 5 USDC → 5_000_000 wei
phUSD vs intended 5e18, an exact 1e12× shortfall); `F-02-035 (a)` is its faithfulness cross-ref.

### Mandatory-re-audit-on-fix hazard

The current direction is **UNDER**-mint, which fails *safe* with respect to phUSD solvency
(no unbacked phUSD is created). **Any fix carries a sign-flip hazard:** a correction that
over-shoots past the exact `1e12` factor flips the bug to an **unbacked phUSD OVER-mint**
(DEDUP-001 / Law-1 solvency territory). The eventual fix is a **`MANDATORY-RE-AUDIT-ON-FIX`**
item: re-audit must confirm the scale factor is exactly `1e12` (USDC 6-dp → phUSD 18-dp) and
that no unbacked phUSD can be minted.

---

## F-02-035 (b) — "Ratchet" naming vs non-monotonic behaviour (cosmetic Law-2)

**Cross-ref:** QA **Q-06** (bundled in `reports/yield-claim-nft/11/submissions/qa-report.md`).

### Story text (what was directed)

The `story-035` acceptance criteria are: `MAX_RATIO=200`, `DEFAULT_RATIO=100`, an
**inclusive** `setRatio` guard, and accurate ratio NatSpec. The story says **nothing** about
monotonicity — there is no directed invariant that the ratio only moves one way.

### Actual behaviour (what the code does)

`setRatio` (`src/V2/hooks/NudgeRatchetMintDebtHook.sol:80`) is freely re-settable up *or* down
within `[0, MAX_RATIO]`:

```solidity
function setRatio(uint8 newRatio) external onlyOwner {
    if (newRatio > MAX_RATIO) revert RatioTooHigh();   // only an upper bound
    uint8 old = ratio;
    ratio = newRatio;                                   // freely up or down
    emit RatioUpdated(old, newRatio);
}
```

The name **"Ratchet"** connotes monotonic, one-way movement; the implementation imposes only
an upper bound and allows the ratio to be lowered as well as raised.

### Assessment

This is a **cosmetic Law-2 naming deviation** with **no asset impact**:

- The story's substantive acceptance criteria (max / default / inclusive guard / accurate
  NatSpec) say nothing about monotonicity, so the code does **not** violate any *directed*
  invariant — the deviation is between the name's connotation and the behaviour, not between
  the spec and the behaviour.
- The **parent `BalancerPoolerMintDebtHook` is non-monotonic too**, so the freely-settable
  ratio is consistent with the "near-copy" directive.

Recorded as **Q-06** in the QA bundle (rename/document to match the freely-settable ratio, or
enforce a monotonic-up `setRatio` if monotonicity is actually intended). No H/M label.

---

## Conformant items (noted, no finding)

The following `story-035` acceptance criteria were reviewed and found **faithful**:

- **`DEFAULT_RATIO = 100` (100% default)** and **`MAX_RATIO = 200` (200% max) enforced on-chain.**
  The constructor sets `ratio = DEFAULT_RATIO` and `setRatio` rejects `newRatio > MAX_RATIO`.
- **INCLUSIVE 200 bound with ACCURATE NatSpec.** `setRatio` accepts `200` and reverts only
  *strictly above* it, and the NatSpec documents this inclusivity accurately. This is a
  deliberate, *correct* improvement: `story-035` fixes the parent's prior **L-02**
  inclusive/exclusive NatSpec mismatch (ledger `L-02`, `BalancerPoolerMintDebtHook.setRatio`)
  rather than reproducing it.
- **Debt-accrual + `pull()` mechanism** — `onDispatch` accrues `mintDebt`; `pull()` realises
  accumulated debt by minting phUSD to `recipient` — present and wired as directed.
- **6-decimal USDC deploy guard** — `NudgeRatchet` constructor (`NudgeRatchet.sol:38`) enforces
  `decimals() == 6` at deploy, as directed. (This guard is precisely what makes F-02-035 (a)'s
  decimal mismatch deterministic rather than incidental.)
- **Sub-100% / zero ratio intended** — the silent `added == 0` no-op and sub-100% ratios mirror
  the parent's behaviour and are owner-trusted (Law-3), not deviations.

---

## Summary

| Ref | Deviation | Law | Channel | Cross-ref |
|-----|-----------|-----|---------|-----------|
| F-02-035 (a) | Verbatim `(amount*ratio)/100` near-copy under-mints 6-dp USDC → 18-dp phUSD by ~1e12× (faithful-but-unsafe story) | Law-1 (overrides faithfulness) | Main (Medium) + spec-conformance | **M-03** (PoC passing); `MANDATORY-RE-AUDIT-ON-FIX` |
| F-02-035 (b) | "Ratchet" name implies monotonicity; `setRatio` freely re-settable up/down | Law-2 (cosmetic) | QA / spec-conformance | **Q-06** |

All other `story-035` acceptance criteria are conformant.
