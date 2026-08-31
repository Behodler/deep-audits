> **Carryover QA report — audit 14** (cut down from `reports/reflax-yield-vault/14/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 17): **QA-09**.
> Removed as no longer live / carried elsewhere: every other section in run-14's report was itself a carryover from runs 05/07/11/12 and is carried under its own originating audit; F-03 (faithfulness — see `spec-conformance-14.md`).
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping** (originating report label → ledger entry):
> - `QA-09` → ledger `QA-09` / `86409a56b6fc3c8b`

*The text below is a verbatim copy of the retained sections of the original report.*

---

### [QA-09] Orphaned vault value after the last `relinquishPrincipal` (NEW this run) <!-- id: ryv14qa9 -->

> Promoted to the top of the bundle as the only genuinely new operational hazard this run. Tracked in the ledger under the `QA-`/footgun series; severity is Low (operational-sequencing footgun, no insolvency).

**Location:** [`src/AYieldStrategy.sol#L507-L521`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L507-L521) — `relinquishPrincipal` / `_relinquishInternal` (residual) and `totalBalanceOf`
**Story:** story-045 (`relinquishPrincipal` primitive), story-046 (deposit/withdraw hoist)
**Classification:** Law-3 non-obvious owner/integrator footgun (in scope as an operational hazard). Value-conservation holds.

**Mechanism.** `relinquishPrincipal` decrements `totalDeposited` (and the caller's `clientBalances`) **without disposing the backing vault shares**. This share-untouched write-down is intended per the `IYieldStrategy` NatSpec (L34-41): on a later recovery the orphaned value is re-attributed to yield. The hazard arises at one edge the NatSpec does not contemplate — driving the **last** remaining principal to zero:

1. The last authorized client calls `relinquishPrincipal` repeatedly (or the owner calls the `…AsOwner` variant) until `clientBalances` and `totalDeposited` reach `0` while `getTotalShares() > 0` (the shares are deliberately left in place).
2. The residual vault value is now **un-attributable and frozen**: `_skimSurplus` early-returns whenever `totalDeposited == 0`, so no skim can distribute it. The value sits idle.
3. The instant fresh principal re-enters, that single depositor's `totalBalanceOf = totalValue * principal / totalDeposited` momentarily inflates to reflect the **entire** residual position (the new principal is briefly the sole denominator).
4. A subsequent `skimSurplus` then delivers the **full residual** to that recipient.

**Impact.** Mis-attribution / sequencing hazard: residual yield value that belonged to the protocol's books is captured in full by whoever deposits first after a complete relinquish-to-zero. Crucially:

- **No value creation.** The Tier-3 value-conservation invariant holds across a 128k-call fuzz over both in-scope concrete strategies. This is an internal redistribution inside the protocol's own books — **not** insolvency, **not** a leak across the protocol boundary.
- **The beneficiary is protocol-owned.** `setClient` is `onlyOwner`; the recipient/next-depositor is an owner-curated client, never an external attacker. There is no third-party theft primitive here.

**The non-obvious footgun (Law 3).** The owner is trusted for *knowing* actions, but this consequence is *unknowing*. Apply the surprise test: a competent, non-malicious integrator who sequences a relinquish-to-zero while live residual shares remain would be **surprised** that (a) the residual silently freezes and (b) it is then handed in full to the first re-depositor rather than remaining attributed where they expect. Surprise ⇒ footgun ⇒ in scope. This is filed as an operational hazard with safe-config guidance, **not** as a "malicious owner could…" vector (which would be suppressed under Law 3). Per Law 1 it is parked visibly here rather than dropped, even though value-conservation holds.

**Documentation check.** NOT blessed. The `IYieldStrategy` NatSpec (L34-41) blesses the share-untouched write-down and the value-to-yield re-attribution "on recovery," but it presumes a *surviving recovery path* (a remaining client). It does not document the `totalDeposited == 0`-with-live-shares orphan, nor the re-capture-on-redeposit edge. No `designDecision` (including #2, requested-not-received, which is a withdraw-path rule) and no `systemAssumption` covers it; `knownIssuesCount = 0`.

**Recommendation.** Any one of the following closes the hazard:

1. **Dispose proportionally on relinquish** — redeem/burn the vault shares proportional to the principal being relinquished, so shares and `totalDeposited` move together and no residual is orphaned. *(Preferred — removes the edge entirely.)*
2. **Block or sweep the terminal case** — when a relinquish would drive `totalDeposited` to `0` while `getTotalShares() > 0`, either revert the final full relinquish or require an explicit owner sweep that attributes the residual to a protocol sink before zeroing.
3. **Document the sequencing rule** — if neither code path is adopted, document the residual-attribution rule explicitly: never relinquish-to-zero while live residual shares remain, and define who the residual belongs to on re-entry.

---

The remaining Low findings below are **open carryovers** reconciled against the ledger this run (`lastSeenRun` bumped to `reflax-yield-vault-14`, status unchanged). Each is stated briefly with its location and recommendation; the full carryover stubs for the items re-flagged by this run's scanners live under `reports/reflax-yield-vault/14/submissions/carryover/` (`L-01-run11`, `L-07`, `L-13`), and the originating finding records are linked per entry.
