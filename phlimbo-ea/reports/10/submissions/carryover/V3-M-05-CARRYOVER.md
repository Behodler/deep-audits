# [CARRYOVER] V3-M-05 — PhlimboV3 _claimRewards reverting reward transfer freezes a blocklisted staker's phUSD principal

> **⚠ FIX-PENDING STILL LIVE — possible incomplete fix.** This finding was triaged
> `fix-pending` (a fix was owed). The code has since changed, but the finding is
> **still flagged**. Either the fix has not landed yet, or it is incomplete.
> Verify with `/recheck phlimbo-ea V3-M-05` before assuming it is resolved.

- **Severity:** Medium
- **Status:** fix-pending (fix owed, not yet verified) — **INCOMPLETE-FIX**
- **Location:** `src/PhlimboV3.sol#L844-L877` (`_claimRewards`; stable leg :858, promo leg :873)
- **First seen:** phlimbo-ea-09  ·  **Still present as of:** phlimbo-ea-10
- **Original report:** [reports/phlimbo-ea/09/submissions/M-01.md](../../../09/submissions/M-01.md)
- **Fingerprint:** `69f8b29a…`

**Run-10 incomplete-fix note:** story-029 **closed** the UNprivileged USDC-blocklist stable/promo
vector (the reason this was Medium) by banking the stable (:876) and promo (:902) legs. It **left
the phUSD mint leg (:863) un-wrapped**, so a residual principal-freeze path survives on a
mint-authorization revocation. That residual is tracked as **V3-L-14** (`27e83ab2…`,
`DEDUP-10-001`) — Low, because its own trigger is owner-privileged and fully recoverable, and it
does **not** inherit this Medium. This entry is **kept `fix-pending`**; do **not** propose or
auto-flip to `fixed` until the phUSD leg is also banked. Cross-ref: V3-L-14.

See the original report for the full description, impact, attack path, PoC, and recommendation.
