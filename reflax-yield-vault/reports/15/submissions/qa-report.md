# QA Report — reflax-yield-vault (run reflax-yield-vault-15)

**Scope:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`, `src/AYieldStrategy.sol`, `src/interfaces/IYieldStrategy.sol` (changed in range; `AYieldStrategy`/`IYieldStrategy` are parents of the in-scope concrete strategy)
**Baseline → HEAD:** `2f6774d` → `ad12cb1` (story-047 global `setAsideBufferRecipient` + story-048 `creditedPrincipal` fix / preview functions / 6h-72h withdrawal retiming)
**Mode:** regression scan reconciled against `reports/reflax-yield-vault/ledger.json` · **0 new High/Medium** · 0 regressions (the sole `fixed` entry M-01 did not reappear; skim invariants pass)

This document bundles the run's Low-severity and Centralization findings into a single QA report, per C4 convention. The run produced exactly **two genuinely new findings, both Lows and both Law-3 operational footguns** surfaced by the two stories: **L-14** (announced-vs-executed drift on `totalWithdrawal` plus the story-048 reaction-window shrink) and **L-15** (story-047 cross-client buffer subsidy in multi-client configs). Both stories are **faithful on behaviour** (FAITH-15-001/002 CONFORMS); the stale-documentation conflicts they left behind are adjudicated in the dedicated [`spec-conformance.md`](spec-conformance.md) (F-04/F-05) and surface here only as the two consolidated **doc-fix items** below. All other Low/QA/Centralization items are open carryovers reconciled by the ledger this run; per run-14 convention they are listed briefly rather than restated (full text: [`reports/reflax-yield-vault/14/submissions/qa-report.md`](../../14/submissions/qa-report.md)). The automated 4naly3er gas/QA baseline is attached as an appendix (`4naly3er-report.md`).

Out of this bundle by design:
- **F-04 / F-05** (faithfulness/spec deviations) — routed to the **spec-conformance** report (Law 2); only their consolidated doc-fix legs appear here, cross-referenced rather than duplicated.
- **L-02** (unbounded skim loop) — triaged **wont-fix**; **L-10** (`setRoute` `lastToken`) — **false-positive**; **M-02 / H-02 / M-01-run12** — **false-positive** (H-02's High framing stays suppressed; see the L-14 boundary note); **H-01 / H-03** — downgraded into the C-01 envelope.
- **DEDUP-15-005** (buffer-inflow attribution at StableStaker) and **DEDUP-15-006** (`previewRedeem(previewDeposit(x)) <= x` vault-property bound) — parked in `findings/manual-review/`; the former fires in the next stable-staker regression run (with the F-03 Medium re-evaluation gate), the latter is gated on the `ERC4626YieldStrategy.sol` scope decision (ACTION-15-002).
- The **BufferSetAside-event** recommendation (emit `BufferSetAside(token, totalSetAside, recipient)` so the story-047 aggregate split is reconstructable off-chain) lives as an **extended recommendation on L-05's ledger annotation** (DISC-15-005) — it is referenced from L-15 below, not opened as a parallel item.

---

## Summary

| Severity | Count |
|----------|-------|
| Low Risk — **new this run** | **2** (L-14, L-15) |
| Low Risk — open carryovers | 18 |
| Centralization | 1 (C-01, narrative text-refreshed) |
| QA / Informational — open carryovers | 9 (QA-02 title text-refreshed) |
| Doc-fix items (consolidated from F-04/F-05 + L-14/L-15 doc legs) | 2 |
| **Total open Low/C/QA** | **30** |

---

## New this run — Operational footguns

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

## Documentation fixes (consolidated)

The run's two faithfulness deviations (F-04, F-05) are documentation-only; their full Law-2 analysis lives in [`spec-conformance.md`](spec-conformance.md) and is **not duplicated here**. For the project team's convenience the QA bundle carries exactly **two consolidated doc-fix work items**:

**Doc-fix 1 — Buffer-semantics NatSpec (merges F-04 with L-15's NatSpec leg; ONE item, not two).**
Update [`AYieldStrategy.sol#L51-L53`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L51-L53) and [`IYieldStrategy.sol#L130-L132`](../../../../lib/reflax-yield-vault/src/interfaces/IYieldStrategy.sol#L130-L132): the stale story-042 text still promises the percentage is "returned to the client" as a per-client reserve, directly contradicting the (correct) story-047 `setAsideBufferRecipient` NatSpec a few lines below it. Rewrite both to state the percentage is **protocol-level yield routing to `setAsideBufferRecipient`**, not a client reserve. This single NatSpec pass closes F-04 and removes the wrong mental model that arms the L-15 footgun.

**Doc-fix 2 — Two-phase withdrawal timings (F-05).**
Update [`AYieldStrategy.sol#L414`](../../../../lib/reflax-yield-vault/src/AYieldStrategy.sol#L414) and [`IYieldStrategy.sol#L101`](../../../../lib/reflax-yield-vault/src/interfaces/IYieldStrategy.sol#L101) from "24-hour waiting / 48-hour window" to the story-048 constants **6h waiting / 72h execution (78h total)**; the registry `designDecision #5` update is a project-manager action item (ACTION-15-001), and any user-facing docs citing a 24h reaction window should be refreshed alongside the monitoring SLAs (see L-14). QA-02's title and C-01's narrative were already text-refreshed in the ledger this run (DISC-15-002/003).

---

## Centralization Risks

### [C-01] Centralization / owner-power bundle (carryover, narrative refreshed) <!-- id: ryv15c1 -->

**Location:** `ERC4626MarketYieldStrategy.sol` + `AYieldStrategy.sol` + `CurveAMMAdapter.sol` — multiple privileged setters and withdrawal paths
**Source:** open since run-05; full statement in [`run-14 §C-01`](../../14/submissions/qa-report.md#c-01-centralization--owner-power-bundle) · ledger `run15Note` (DISC-15-003)

The standing owner-power bundle continues open; this run changes its **narrative, not its status**:

- **Reaction-window re-size:** all references to a "24-hour" community-reaction window on the two-phase `totalWithdrawal` are superseded by story-048 — the waiting period is now **6 hours** (execution window 72h, 78h total). Off-chain monitoring/alerting SLAs sized to 24h must be re-sized to 6h.
- **Envelope growth:** story-047 adds `setSetAsideBufferRecipient` to the owner-setter envelope — a global redirect of *all* clients' buffer set-asides to one address (the specific multi-client footgun is L-15).
- The `emergencyWithdraw` zero-delay escape hatch remains the dominating owner path (the basis of the FAITH-15-005 Law-1 assessment capping L-14 at Low).

**Recommendation (unchanged + this run's delta):** document the trust model for integrators; add the setter bounds from L-01/L-03; consider timelock/multisig over the highest-impact setters — now including `setAsideBufferRecipient` — and re-publish the *actual* 6h/72h migration timings so the community-reaction commitment is honest (doc-fix 2).

---

## Open carryovers (reconciled, listed briefly per run-14 convention)

All items below remain **open** in the ledger. "Bumped" = re-observed at `ad12cb1` this run (`lastSeenRun` → run-15); others were not re-triggered (their code regions are unchanged) and carry forward untouched. Full finding text and per-item `<!-- id: ryv14… -->` stamps: [`run-14 qa-report.md`](../../14/submissions/qa-report.md). Carryover stubs for the items re-flagged by this run's scanners: [`submissions/carryover/`](carryover/).

### Low (18 open carryovers)

| ID | Title (abbrev.) | This run |
|----|-----------------|----------|
| L-01 | `slippageToleranceBps` default-0, no sane upper cap | **bumped** · stub |
| L-03 | No aggregate cap on per-client set-aside buffers | — |
| L-04 | `setAsideBufferSize` persists after deauthorization | — |
| L-05 | `SurplusSkimmed` under-represents buffered-path beneficiaries | **annotated** (DISC-15-005): story-047 rewrote the covered surface; extended recommendation = emit `BufferSetAside(token, totalSetAside, recipient)`; cross-ref L-15 |
| L-06 | `skimSurplus` return-value semantics path-dependent | — |
| L-07 | `setRoute` endpoint-only validation | **bumped** · stub |
| L-08 | Single-step ownership transfer (`Ownable` vs `Ownable2Step`) | **bumped** · stub |
| L-09 | ERC4626 rate read twice in a tx can revert (time-weighted vaults) | **bumped** (DEDUP-15-004 facet of acknowledged M-02 cluster) |
| L-11 | `totalBalanceOf` / `principalOf` inconsistent data sources | **bumped** (same M-02-cluster facet) |
| L-12 | `CurveAMMAdapter.swap` no independent `minAmountOut` re-check | — |
| L-13 | `_totalWithdraw` marks migration complete on floor-to-zero shares | **bumped** · stub (benign shrink/zero direction; L-14 covers the growth direction) |
| L-01-run11 | CEI violation in `_withdrawInternal` / `_totalWithdraw` | **bumped** · stub |
| L-02-run11 | Residual AMM allowance accumulation on partial revert | — |
| L-03-run11 | `emergencyWithdraw` lacks `nonReentrant` | — |
| L-04-run11 | `nonReentrant` not first modifier | **bumped** · stub |
| L-05-run11 | Constructor `_owner` shadowing (three contracts) | **bumped** · stub |
| L-06-run11 | `WithdrawalExecuted` emits stale Phase-1 amount | **bumped** · stub — now **compounds L-14** (hides announced-vs-executed drift); fix jointly |
| L-07-run11 | `withdrawAsOwner` event omits drained client | — |

### QA / Informational (9 open carryovers)

| ID | Title (abbrev.) | This run |
|----|-----------------|----------|
| QA-01 | `abi.encodePacked` with dynamic types in revert-message hashing | — |
| QA-02 | `block.timestamp` drives the two-phase withdrawal window | **bumped + title text-refreshed** to the story-048 constants (6h waiting / 72h execution) per DISC-15-002; status/severity unchanged — the retiming *substance* is L-14, not here |
| QA-03 | Unit mismatch: percent buffer vs bps slippage | — |
| QA-04 | `whenNotPaused` blocks `totalWithdrawal` | — |
| QA-05 | `CurveAMMAdapter` has no rescue/sweep | — |
| QA-06 | `setClient` ignores `EnumerableSet` return value | **bumped** (re-observed by this run's static pass; unchanged) |
| QA-07 | `skimSurplus` return value can diverge from summed events | — |
| QA-08 | Skim de-buffering strips the depeg cushion (owner footgun) | — |
| QA-09 | Orphaned vault value after last `relinquishPrincipal` (run-14 headline) | — (consumer-side `relinquishPrincipal` wiring is now live at `StableStaker.sol:786`; the F-03 Medium re-evaluation gate fires in the next **stable-staker** regression run, not here) |

---

## Appendix: 4naly3er Automated Report

The canonical C4-style automated QA/gas report (4naly3er) was generated over the three in-scope changed files at `ad12cb1` and is attached alongside this document:

- **`reports/reflax-yield-vault/15/submissions/4naly3er-report.md`**

It covers `ERC4626MarketYieldStrategy.sol`, `AYieldStrategy.sol`, and `IYieldStrategy.sol`, and reports **16 Gas-optimization categories**, **21 Non-Critical categories**, **11 Low categories**, and **2 Medium categories**. The automated items are the bot-report baseline, not independently triaged findings; the notable overlaps with the manual bundle:

- 4naly3er **M-1** (centralization risk for trusted owners, 12 instances — now including the story-047 `setAsideBufferRecipient` setter and story-048-era `relinquishPrincipalAsOwner`) is the automated view of manual **C-01**.
- 4naly3er **M-2** (`increaseAllowance` won't work for mainnet USDT, 4 instances) flags the `safeIncreaseAllowance` call-sites already tracked as manual **L-02-run11**; the USDT-compat framing is a known-invalid C4 pattern for this protocol (the underlying/vault tokens are fixed and not USDT) and is left to the bot report.
- 4naly3er **L-1 / L-10** (2-step ownership / `Ownable2Step`) corroborate manual **L-08**; **L-6 / NC-5 / NC-15** (renounce while paused) sit inside the C-01 envelope.
- 4naly3er **L-4 / NC-2** (`abi.encodePacked` to a hash function) corroborate manual **QA-01**.
- 4naly3er **L-3 / NC-1** (missing `address(0)` checks) and **NC-11** (lack of checks in setters) sit alongside manual **L-01 / L-03** — note story-047's new recipient setter *does* zero-address-validate (FAITH-15-001).
- 4naly3er **L-5 / L-7 / L-8** (division-by-zero, rounding, precision loss) are the automated view of the ERC4626 rate-read class captured in **L-09 / L-11**.
- 4naly3er **NC-8** (events should carry old+new values) and **NC-7 / NC-20** (missing indexed fields) align with the event-quality manual Lows **L-05 / L-06-run11 / L-07-run11** and the L-05 `BufferSetAside` extended recommendation.
- 4naly3er **L-9** (PUSH0 / chain-compatibility) is a deployment-target note, not a protocol exploit.

No automated finding surfaced a High/Medium protocol exploit beyond what the manual pipeline already adjudicated.

*Tooling note:* 4naly3er was run from `tools/4naly3er` against a symlink mirror of the project (`src/` and `lib/` symlinked unchanged from `lib/reflax-yield-vault/`) with a `remappings.txt` supplying the `@openzeppelin/` and `pauser/` remappings, because `lib/` is strictly read-only and the project resolves the `pauser/` remapping via `foundry.toml` rather than `remappings.txt`. Scope was restricted to the three in-scope changed files via a scope file. No source file was modified.
