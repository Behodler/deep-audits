> **Carryover spec-conformance report — audit 14** (cut down from `reports/reflax-yield-vault/14/submissions/spec-conformance.md`).
> Retained below (still open / untriaged as of audit 17): **F-03**.
> Removed as carried elsewhere: F-01 and F-02 sections (they are run-12 carryovers in that report — carried under audit **12**).
> Labels are the originals. Law-2 faithfulness entries are carried in this channel, **never** folded into the QA bundle.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping**:
> - `F-03` → `52f9b84a54ec9a65`

*The text below is a verbatim copy of the retained sections of the original report.*

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
