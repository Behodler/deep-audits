> **Carryover QA report — audit 15** (cut down from `reports/reflax-yield-vault/15/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 17): **L-14, L-15**.
> Removed as no longer live / carried elsewhere: C-01 (originating audit is **05**); F-04 and F-05 (faithfulness — see `spec-conformance-15.md`); the run-15 'open carryovers' index sections, which are pointers to other audits' findings rather than run-15 findings.
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping** (originating report label → ledger entry):
> - `L-14` → ledger `L-14` / `8537db26cf1d2cc1`
> - `L-15` → ledger `L-15` / `adfdab3463372c8b`

*The text below is a verbatim copy of the retained sections of the original report.*

---

### [L-14] `totalWithdrawal` Phase-2 executes the LIVE client balance, not the Phase-1 announced snapshot; story-048's 6h/72h retiming shrinks the documented community-reaction window 4x <!-- id: ryv15l14 -->

**Location:** [`src/AYieldStrategy.sol#L822-L860`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L822-L860) (`_initiateWithdrawal` snapshot → `_executeWithdrawal` cached pass-down), [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L209-L240`](../../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L209-L240) (`_totalWithdraw` ignores the `amount` parameter), [`src/AYieldStrategy.sol#L84-L86`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L84-L86) (`WAITING_PERIOD = 6 hours`, `EXECUTION_WINDOW = 72 hours`)
**Story:** story-048 (`ad12cb1`) · **Source:** `findings/low/L-14-totalwithdrawal-announced-vs-executed-live-drift.json`
**Classification:** Law-3 non-obvious owner/operator footgun + commitment-transparency weakening. Surprise test passes. Value-conservation holds.

**Mechanism.** The two-phase `totalWithdrawal` announces an amount at Phase 1 (`_initiateWithdrawal` snapshots `state.balance` and emits `WithdrawalInitiated`), but Phase 2 does not honor it: `_executeWithdrawal` passes the cached snapshot down, and `ERC4626MarketYieldStrategy._totalWithdraw` **ignores the `amount` parameter**, re-reads `clientBalances` live, and sells proportional shares for the **full live balance**. Deposits arriving between Phase 1 and Phase 2 are swept in excess of the announced figure (Tier-3 detector: executed `1,209,632e18` vs announced `278,585e18` after a mid-window deposit at the 6h boundary). story-048 additionally retimed the window — `WAITING_PERIOD` 24h→6h, `EXECUTION_WINDOW` 48h→72h (78h total) — shrinking the community reaction window 4x and widening the drift horizon, while three documentation sources still claim 24h/48h (doc leg: F-05 / doc-fix item 2 below). Compounding the opacity, `WithdrawalExecuted` emits the cached *announced* amount rather than the actual swept amount (open **L-06-run11**), so on-chain observers can detect neither the true timing nor the true amount.

**Impact.** No external asset theft, loss, or compromise: every trigger is `onlyOwner`, proceeds go to `owner()`, and value-conservation holds. The harmed asset is **informational** — the anti-rug commitment that the announced amount and documented reaction window represent. A competent, non-malicious owner running a legitimate migration unknowingly sweeps client deposits made after the announcement, and the protocol's documented transparency commitment overstates the community's actual reaction window (6h, not 24h).

**Severity cap rationale (Law 1, FAITH-15-005).** The 6h retiming is story-blessed and **not** an unsafe story: zero-delay owner exfiltration already exists via `emergencyWithdraw` (no timelock, works while paused — standing C-01), so the waiting period was never the binding rug protection. That domination argument is precisely why this cannot exceed Low.

**H-02 boundary.** This is **not** a re-escalation of false-positive H-02. H-02's adjudicated-and-rejected claims — the High theft framing (circular/owner-funded) and the underflow brick (spurious symbolic artifact) — stay suppressed. The root-cause class here (announced-vs-executed commitment-transparency gap as an operational hazard, plus the diff-new story-048 retiming) was never adjudicated, carries a deliberately distinct fingerprint (`8537db26…`), and is capped at Low.

**Recommendation.**
1. Pin Phase-2 execution to `min(announced snapshot, live balance)`, or require re-initiation when the live balance exceeds the announced figure.
2. Fix `WithdrawalExecuted` to emit the actual swept amount (jointly with L-06-run11).
3. Update the 24h/48h documentation (doc-fix item 2 / F-05) and re-size off-chain monitoring/alerting SLAs to the 6h reaction window (C-01 text refresh, DISC-15-003).

---

### [L-15] story-047 pools ALL clients' set-aside buffers into one global `setAsideBufferRecipient` — silent cross-client subsidy in multi-client configurations <!-- id: ryv15l15 -->

**Location:** [`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L353-L372`](../../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L353-L372) (`_distributeBuffer` single aggregate transfer), [`src/AYieldStrategy.sol#L318-L341`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L318-L341) (per-client `setSetAsideBuffer` setter), [`src/AYieldStrategy.sol#L352-L357`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L352-L357) (recipient setter), stale NatSpec at [`src/AYieldStrategy.sol#L51-L53`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L51-L53) and [`src/interfaces/IYieldStrategy.sol#L130-L132`](../../../../lib/reflax-yield-vault/src/interfaces/IYieldStrategy.sol#L130-L132)
**Story:** story-047 (`933620d`) · **Source:** `findings/low/L-15-global-buffer-recipient-cross-client-subsidy.json`
**Classification:** Law-3 non-obvious owner config footgun (independently retained by FAITH-15-006). Implementation is **faithful** to story-047; Tier-3 `bufferConservation` passes (forge 256x250, Medusa 200k).

**Mechanism.** Since story-047, the set-aside buffer is **never returned to the contributing client** — `_distributeBuffer` sums all clients' set-asides and sends the aggregate in a single `safeTransfer` to the global `setAsideBufferRecipient`. The hazard is distributional inside the protocol's own books: in a future multi-client deployment where the owner sets nonzero `setAsideBufferSize` for more than one client (plausible, because the setter is per-client and its NatSpec still describes the superseded story-042 *per-client reserve* semantics), every non-recipient client's dip-absorption reserve is silently routed to the single recipient. A non-recipient client's underwater-exit path, sized against the documented story-042 reserve, reverts or under-delivers when the dip arrives. The per-client setter shape plus the stale NatSpec **actively teach the owner the wrong model**.

**Impact.** No value leaves the protocol (realized *surplus only* is redirected; principal accounting untouched; conservation verified). Funds are not lost — they sit at the recipient — but the non-recipient client's availability assumption is broken until manually rebalanced. No external attacker exists anywhere in the path. Not an unsafe story (Law-1/Law-2 check, FAITH-15-006): the redirect is explicit, loudly documented on the recipient side, and story-047 removes the old front-run-the-skim self-benefit incentive.

**Recommendation.**
1. **Safe config:** set nonzero `setAsideBufferSize` ONLY for the client that is (or funnels to) the `setAsideBufferRecipient`.
2. Consider an on-chain guard rejecting nonzero buffers for clients other than the recipient's funnel, or making the recipient per-client.
3. Fix the stale per-client-reserve NatSpec (doc-fix item 1 / F-04 below).
4. Observability: the missing per-skim event recording the recipient-vs-buffer split is tracked as an **extended recommendation on open L-05** (ledger annotation DISC-15-005: emit `BufferSetAside(token, totalSetAside, recipient)`) — the missing event is what would otherwise obscure this routing on-chain. No parallel item is opened here.

---
