> **Carryover spec-conformance report — audit 16** (cut down from `reports/reflax-yield-vault/16/submissions/spec-conformance.md`).
> Retained below (still open / untriaged as of audit 17): **F-16-003**.
> Removed as carried elsewhere: F-16-004 (declared in its own report as a **MIRROR of F-05, not a new entry** — carried under audit **15** as F-05); the F-03 section (run-14 carryover).
> Labels are the originals. Law-2 faithfulness entries are carried in this channel, **never** folded into the QA bundle.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping**:
> - `F-16-003` → `c705bd94ec78fd23`

*The text below is a verbatim copy of the retained sections of the original report.*

---

## F-16-003 — `_acquireShares` NatSpec "no haircut" contradicts the `convertToAssets` credit (NEW)

**Status:** open · **Origin:** new (reflax-yield-vault-16) · **Story:** `story-049` (commit `0110ce4`)
**Location:** `src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L93-L95` (NatSpec) vs `#L115` (code)
**Fingerprint:** `c705bd94…` (`sha256(...:_acquireShares-natspec:full-nominal-no-haircut-contradicts-converttoassets-credit)`, empty `entryPoint`)
**Cross-reference:** **ECON-A / L-16** carries the value leg (fee-blind `convertToAssets` over-states redeemable NAV). This entry is the documentation contradiction only.

### What the story says (intent)

> story-049: "credit principal via `convertToAssets`" — book the current exchange-rate value of the shares actually received (so entry-fee / share-rounding discrepancies are not over-credited), and use `convertToAssets` (not `previewRedeem`) because some real vaults (Tokemak Autopools) revert with `StateChangeDuringStaticCall` inside `previewRedeem`.

### What the stale docs still say

> `ERC4626YieldStrategy.sol:93`: "@return creditedPrincipal The principal the base should book — the full nominal `amount`"
> `ERC4626YieldStrategy.sol:95`: "@dev Direct ERC4626 deposit: credits the full nominal amount (no haircut)."

### Actual behavior at this commit

`ERC4626YieldStrategy.sol:115`: `creditedPrincipal = vault.convertToAssets(sharesReceived);` — a value **below** the nominal `amount` whenever the vault has any entry-fee / share-rounding discrepancy, i.e. **a haircut**. The inline comment three lines above the credit (`:112-114`) even explains the haircut, directly contradicting the `@dev` block. An integrator reading the NatSpec would wrongly conclude the full deposited amount is booked as principal.

### Recommendation

Update `ERC4626YieldStrategy.sol:93/95` NatSpec to state that `_acquireShares` credits the current exchange-rate value of the shares actually received (`convertToAssets(sharesReceived)`), **not** the full nominal amount — drop the "no haircut" claim.

---
