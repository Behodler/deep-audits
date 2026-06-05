# QA Report — reflax-yield-vault (run-08)

**Run:** reflax-yield-vault-08 · **Mode:** regression
**Baseline:** `5f9abdd` → **HEAD:** `a65dbf0`
**Story:** story-043 — "conservative principal crediting"
**In-scope changed file:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`

## Regression result

The regression scan of **story-043** surfaced **zero new High or Medium findings** and
**zero new ledger entries**. story-043 added a deposit-side haircut
(`creditedPrincipal = amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS`) — the full
deposit amount is swapped into the vault, but only the haircut value is credited as
principal and the gap is recognised as protocol surplus. This is **documented intended
design** (NatSpec L19-23, `_creditedPrincipal` L204-214, `Deposited` event L58-62); the
severity-classifier ruled it **Low** and the severity-auditor **REFUTED** it as Medium
(disposition DEDUP-001, suppressed). Its only durable residue is an amplification of the
already-open **L-01** (see the run-08 QA note below).

Accordingly, the body of this QA report is **carryover QA from prior runs** (still-open
Low + Centralization findings reconciled against the ledger) plus the **automated tooling
output**. Carryover findings are reproduced so they are not lost between runs; they are
**not newly discovered this run**. Triage them with `/ledger reflax-yield-vault`.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (carryover, open) | 6 |
| Centralization (carryover, open) | 1 |
| **Total** | **7** |

Open Lows carried forward: **L-01, L-03, L-04, L-05, L-06, L-07**.
Open Centralization: **C-01**.
(L-02 is `wont-fix`; M-03 `merged`; M-04 `false-positive`; M-01 `fixed`; M-02 `acknowledged` — none appear here.)

Appendices: automated 4naly3er QA/gas report, and a note on the deterministic SAST artifacts.

---

## Low Risk Findings (carryover from prior runs)

### [L-01] `slippageToleranceBps` default-0 plus setter missing sane cap (missing validation) <!-- id: ryv8l1 -->

> **Carryover — still open.** First seen reflax-yield-vault-05; still present at reflax-yield-vault-08. Not new this run.

**Location:** [`ERC4626MarketYieldStrategy.sol#L190-L195`](../../reflax-yield-vault-05/submissions/qa-report.md) (`setSlippageTolerance`)
**Status:** open · **Fingerprint:** `6460e353…` · **Original report:** `reports/reflax-yield-vault-05/submissions/qa-report.md`

**Description:** `slippageToleranceBps` defaults to 0 and `setSlippageTolerance` enforces no sane
upper bound, so the owner can set an arbitrarily loose tolerance. This was the compensating
control flagged against M-02 (NAV-anchored minOut) and is cited as a partial mitigation
surface for M-04 (`ryv7m4`).

**Run-08 QA note (no new finding):** story-043's "conservative principal crediting" adds a
**new deposit-side dependency** on this same uncapped parameter. The deposit path now credits
`creditedPrincipal = amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS` (`_creditedPrincipal`
L204-214; NatSpec L19-23; `Deposited` event L58-62). The crediting itself is documented intended
design (DEDUP-001 suppressed; classifier Low, auditor REFUTED), but it **materially widens the
blast radius of this Low**: the deposit-side haircut magnitude is bounded *only* by the still-missing
`slippageToleranceBps` upper cap. An owner setting a loose tolerance now haircuts depositors'
*credited principal* as well as swap `minOut`. (Note `slippageToleranceBps == MAX_BPS` would drive
credited principal to 0 and strand deposits — DEDUP-003, ruled reckless-admin known-invalid; the
durable residue is this missing-cap Low.)

**Recommendation (expanded):**
1. Enforce a hard, sane upper cap on `slippageToleranceBps` (e.g. a few hundred bps) inside
   `setSlippageTolerance`, and set a sensible nonzero default.
2. Add an explicit deposit-side entry to the `designDecisions` registry documenting the
   conservative-crediting haircut, so integrators do not mistake credited principal for the
   deposited amount.

```solidity
uint256 public constant MAX_SLIPPAGE_TOLERANCE_BPS = 500; // e.g. 5%

function setSlippageTolerance(uint256 newBps) external onlyOwner {
    require(newBps <= MAX_SLIPPAGE_TOLERANCE_BPS, "ERC4626MarketYieldStrategy: tolerance too high");
    // ...
}
```

Severity remains **Low**; status remains **open**.

---

### [L-03] No aggregate cap on per-client buffer percentages (total set-aside can reach 100% of `underlyingReceived`) <!-- id: ryv8l3 -->

> **Carryover — still open.** First seen reflax-yield-vault-07; still present at reflax-yield-vault-08. Not new this run.

**Location:** [`AYieldStrategy.sol#L253-L259`](../../reflax-yield-vault-07/findings/low/L-03.json) (`setSetAsideBuffer`)
**Status:** open · **Fingerprint:** `1a4e3e8f…` · **Extends:** C-01 · **Original:** `reports/reflax-yield-vault-07/findings/low/L-03.json`

**Description:** Per-client buffer percentages are set individually with no aggregate ceiling, so
the sum of set-aside buffers can reach 100% of `underlyingReceived`, reducing the recipient's take
to zero **with no revert**.

**Run-08 note:** story-043 did not touch the per-client buffer aggregate-cap gap. This run's
DEDUP-004 (buffer front-run amplification) was a duplicate that consolidates here; the
cross-client-principal angle was already adjudicated false-positive under M-04. Severity/status unchanged.

**Recommendation:** Enforce an aggregate buffer ceiling (< `MAX_BPS`, leaving a minimum recipient
share) when setting or updating any per-client buffer.

---

### [L-04] `setAsideBufferSize` persists after a client is deauthorized and silently resurrects on re-auth <!-- id: ryv8l4 -->

> **Carryover — still open.** First seen reflax-yield-vault-07. Not new this run.

**Location:** [`AYieldStrategy.sol#L183-L259`](../../reflax-yield-vault-07/findings/low/L-04.json) (`setClient` / `setSetAsideBuffer`)
**Status:** open · **Fingerprint:** `b51876fe…` · **Extends:** C-01 · **Original:** `reports/reflax-yield-vault-07/findings/low/L-04.json`

**Description:** A client's `setAsideBufferSize` is not cleared when the client is deauthorized.
On re-authorization the stale buffer percentage silently resurrects, applying a buffer the owner
may not have re-intended.

**Recommendation:** Zero out a client's `setAsideBufferSize` on deauthorization (in `setClient`
when removing), and require an explicit buffer re-set after re-authorization.

---

### [L-05] `SurplusSkimmed` event under-represents buffered-path beneficiaries — no event records per-client buffer redirection <!-- id: ryv8l5 -->

> **Carryover — still open.** First seen reflax-yield-vault-07. Not new this run.

**Location:** [`ERC4626MarketYieldStrategy.sol#L484-L519`](../../reflax-yield-vault-07/findings/low/L-05.json) (`_accrueSurplusShares` / `_distributeBuffer`)
**Status:** open · **Fingerprint:** `efcdb9dc…` · **Original:** `reports/reflax-yield-vault-07/findings/low/L-05.json` · folding candidate with L-06

**Description:** On the buffered skim path, surplus is redirected to per-client buffers, but the
`SurplusSkimmed` event records only the headline skim and not the per-client buffer redirection,
making off-chain accounting of who received what incomplete.

**Recommendation:** Emit a dedicated event (or extend `SurplusSkimmed`) recording each per-client
buffer amount on the buffered path.

---

### [L-06] `skimSurplus` return-value semantics are path-dependent — fast path returns swap output, buffered path returns recipient-receipt <!-- id: ryv8l6 -->

> **Carryover — still open.** First seen reflax-yield-vault-07. Not new this run.

**Location:** [`ERC4626MarketYieldStrategy.sol#L432-L521`](../../reflax-yield-vault-07/findings/low/L-06.json) (`_skimSurplus` / `_distributeBuffer`)
**Status:** open (borderline) · **Fingerprint:** `0f534a72…` · **Original:** `reports/reflax-yield-vault-07/findings/low/L-06.json` · folding candidate with L-05

**Description:** `skimSurplus` returns the swap output on the fast path but the recipient-receipt on
the buffered path. The NatSpec does not disambiguate, leaving room for integrators to mis-interpret
the return value depending on which path executed.

**Recommendation:** Make the return value path-independent (or split into two clearly-named values)
and document the exact semantics in NatSpec.

---

### [L-07] `setRoute` accepts `tokenIn == tokenOut` and paths with internal zero-gap segments — relies entirely on off-chain verification <!-- id: ryv8l7 -->

> **Carryover — still open.** First seen reflax-yield-vault-07. Not new this run.

**Location:** [`CurveAMMAdapter.sol#L62-L89`](../../reflax-yield-vault-07/findings/low/L-07.json) (`setRoute`)
**Status:** open · **Fingerprint:** `b28e77da…` · **Origin:** carry-forward · **Extends:** C-01 · **Original:** `reports/reflax-yield-vault-07/findings/low/L-07.json`

**Description:** `setRoute` performs no on-chain sanity check that `tokenIn != tokenOut` and does not
reject paths containing internal zero-gap segments, relying entirely on off-chain verification of
route correctness. (`CurveAMMAdapter` was unchanged by story-042/story-043.)

**Recommendation:** Add minimal on-chain route validation: reject `tokenIn == tokenOut` and any
zero-address / zero-gap internal segment.

---

## Centralization Risks (carryover from prior runs)

### [C-01] Centralization / owner-power bundle <!-- id: ryv8c1 -->

> **Carryover — still open.** First seen reflax-yield-vault-05; still present at reflax-yield-vault-08. Not new this run.

**Location:** `ERC4626MarketYieldStrategy.sol` — multiple owner-only setters: `setRoute`,
`setSlippageTolerance`, `depositAsOwner`, `withdrawAsOwner`, `emergencyWithdraw`, `setClient`
(authorized-client set), `setSetAsideBuffer` (per-client buffer), single-recipient skim,
two-phase total withdrawal.
**Status:** open · **Fingerprint:** `679c917d…` · **Extended by:** L-03, L-04, L-07 · **Original:** `reports/reflax-yield-vault-05/submissions/qa-report.md`

**Description:** The strategy concentrates broad operational power in a single owner across
routing, slippage tolerance, owner-initiated deposits/withdrawals, emergency withdrawal, the
authorized-client set, per-client buffers, and the two-phase total-withdrawal flow. Individual
setter-design defects within this envelope are documented as L-03, L-04, and L-07.

**Impact:** A compromised or careless owner can adversely reconfigure routing/tolerance, redirect
or strand surplus, or trigger emergency/total withdrawals. The risk is operational (parameter and
flow control) rather than a direct theft primitive on the curated-client model.

**Run-08 note (no new finding):** story-043's conservative-crediting haircut binds the
owner-controlled `slippageToleranceBps` to **deposit-side credited principal** as well as swap
`minOut`, broadening the owner-power envelope. The uncapped `setSlippageTolerance` setter remains
the locus and is tracked in detail under L-01. Severity/status unchanged.

**Recommendation:** Move high-impact setters behind a timelock and/or multisig; enforce on-chain
bounds where feasible (notably the `slippageToleranceBps` cap of L-01 and the aggregate buffer cap
of L-03); emit comprehensive events for all parameter changes (cf. L-05).

---

## Appendix A — Automated QA/Gas Report (4naly3er)

The canonical C4-style automated report was generated with **4naly3er** over the in-scope contract
`concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (built from the writable workspace at HEAD
`a65dbf0`; `lib/` is read-only). Full output is attached alongside this report:

- **`./4naly3er-report.md`** — Gas Optimizations (15 categories), Non-Critical Issues, Low Issues, Medium Issues.

These automated hits are the standard bot-report baseline (custom errors vs revert strings, cache
array length, `address(0)` checks, prefix-increment, etc.) and are informational; none escalate
beyond the QA tier and they are not re-listed individually above.

## Appendix B — Deterministic SAST Artifacts

The deterministic static-analysis artifacts for this run live in
`reports/reflax-yield-vault-08/tooling/`:

- `slither-output.json` (Slither 0.11.3) · `aderyn-report.json` (Aderyn 0.6.8) ·
  `semgrep-output.json` (Semgrep 1.163.0) · `static-analysis-findings.json` (triaged summary).

**Disposition:** the only non-noise Slither hits — `reentrancy-no-eth` (`_withdrawInternal` L354,
`_totalWithdraw` L416), `incorrect-equality` (`_totalWithdraw` L400), and `uninitialized-local`
(`_distributeBuffer` L536) — were all in **UNCHANGED** code, are **`nonReentrant`-guarded** or
**benign** (the `uninitialized-local` is a zero-defaulted accumulator; the strict-equality is a
deliberate branch guard), and were **dropped as noise** (disposition `SAST`). The story-043 changed
code (`_creditedPrincipal` L204-214 pure-math view; `_depositInternal`) produced **no high/medium
SAST hits** — the only detector touching the deposit path was reentrancy-benign on `_depositInternal`
(`nonReentrant`-guarded). Aderyn (0 high) and Semgrep (46 findings, all INFO/QA) added only
QA/style noise.
