# yield-claim-nft — Run 13 (REGRESSION)

- **Project:** yield-claim-nft
- **Run:** yield-claim-nft-13
- **Mode:** REGRESSION
- **Commit range:** `7f5cac1..aa86be6`
- **Baseline commit:** `7f5cac1205c14d66bfaf69392b04541fb44bcf2c`
- **Audited commit (new HEAD):** `aa86be663aacc8b1da8d833dd3382094a1e0572a`
- **Stories:** story-040 (Uniboost buy-and-pool UniV2 dispatcher) + story-041 (UniboostMintDebtHook, prime-decimals-aware phUSD debt accrual)
- **Date:** 2026-06-24

## Executive summary

This regression run covers two **new in-scope files** introduced by stories 040/041, both effectively
cold-scan targets:

- `src/dispatchers/Uniboost.sol` — a buy-and-pool Uniswap V2 dispatcher (third dispatcher of its family).
- `src/hooks/UniboostMintDebtHook.sol` — a prime-decimals-aware phUSD mint-debt accrual hook.

**Verdict: 0 High, 0 Medium, 4 Low, 2 QA, 0 regressions.** Two genuinely new findings were surfaced
(`L-09`, `L-10`) plus one new QA item (`Q-10`); the remaining Lows are dedup-instances of existing open
findings on the new contracts, annotated rather than re-counted as new. No exploit path was found, and
Tier-3 fuzzing + symbolic analysis confirm the protocol's core ≥2:1 over-backing invariant holds on the
new hook.

## Verdict

| Severity | Count |
|----------|-------|
| High | 0 |
| Medium | 0 |
| Low (new) | 2 (`L-09`, `L-10`) |
| Low (dedup-instances of existing open) | 2+ (`L-06`, `L-05`, `L-02`) |
| QA (new) | 1 (`Q-10`) |
| QA (dedup/spec) | 1 (`L-02` spec-conformance facet) |
| Regressions | 0 |

`L-09`, `L-10`, `Q-10` are the new ledger label assignments for this run.

## New findings

| Label | Severity | Location | Summary | Fix |
|-------|----------|----------|---------|-----|
| `L-09` | Low | `src/hooks/UniboostMintDebtHook.sol` | No `hookTypeId` guard → an unwired hook accrues **0 phUSD debt** (M-04-class footgun reborn on a 3rd dispatcher; `Q-08` precedent). Surfaced for **explicit owner triage**, not auto-wont-fixed. | Add a wired-hook guard / non-zero `hookTypeId` assert mirroring the M-04 remediation, or wire the hook before registering the dispatcher. |
| `L-10` | Low | `src/hooks/UniboostMintDebtHook.sol` (ctor) | Hook decimal scale is **decoupled** from the dispatcher's prime decimals → deploy-time mis-scale can **over-mint unbacked phUSD** if mis-deployed. | One-line constructor assert binding the hook scale to `dispatcher.primeToken()` decimals. |
| `Q-10` | QA | `src/dispatchers/Uniboost.sol` (`setPool`) | `setPool` leaves `_primeToPairPath` stale — pool repointed without refreshing the cached swap path. | Recompute / clear `_primeToPairPath` inside `setPool`. |

### Dedup-instances (annotated, not new findings)

These are existing open Lows re-confirmed on the new Uniboost contracts; they inherit their existing
labels and are annotated in `findings/`, not re-counted:

- `L-06` — `pool()` single-sided LP-add MEV sandwich (recurs on `Uniboost.pool`).
- `L-05` — `donationSplit` ↔ `ratio` decoupling (recurs on Uniboost config surface).
- `L-02` — `setRatio` accepts `== MAX_RATIO` vs the "strictly `<`" NatSpec (also a faithfulness /
  spec-conformance item; see below).

## Faithfulness (Law 2)

- **story-040 — FAITHFUL.** No deviations. The buy-and-pool dispatcher implements its story as written.
- **story-041 — 3 deviations:**
  - **`F-04-041`** — hook scale decoupled from dispatcher prime decimals (↔ `L-10`).
  - **`F-05-041`** — missing-wire / no `hookTypeId` guard (↔ `L-09`).
  - **`L-02` NatSpec nit** — `setRatio` boundary contradicts "strictly `<`" documentation.
- **No unsafe story intent.** Debt is accrued on the **gross** amount (over-backs, never under-backs),
  and the `0/0` `addLiquidity` mins are bounded by upstream floors plus a `minLP` guard — neither story's
  intended behaviour introduces a Law-1 exploit.

Full detail in `submissions/spec-conformance.md`.

## Tier-3 verification

- **Foundry invariants:** 256 runs × 16 384 calls, `fail_on_revert = true`, across **6 / 8 / 18-decimal**
  configurations — **all PASS**. Confirmed ≥2:1 over-backing, no over-mint, no debt resurrection, and the
  ratio bound hold.
- **Medusa:** 56 000 calls — **PASS** (no invariant violations).
- **Halmos (symbolic):** no counterexample found. **No-over-mint PROVEN** at `scale = 1` plus
  bitwidth-independence. The remaining properties hit solver **TIMEOUT** (division-by-100 bit-blast),
  which are inconclusive, **not** failures.
- The **M-03 sign-flip over-mint trap class is CLOSED** on `UniboostMintDebtHook`.

Results: `tier3/invariant-results.md`, `tier3/symbolic-results.md`.

## Refuted leads (Law-1, kept visible)

- **ECON-001 — double-mint:** REFUTED. The donation recipient is external and there is exactly **one
  debt accrual per dispatch** (OOS per the suppressed `DEDUP-001` unbacked-phUSD boundary).
- **ECON-002 — under-backing:** REFUTED. `ratio ≤ 50` guarantees a **≥2:1** backing buffer.

## Watch entries preserved

Out of this run's changed scope, untouched, **no regression** — carried forward as-is:

- **M-04** — literal-pair drift watch (`NudgeRatchet`).
- **Q-07 / Q-08** — wont-fix.

## Ledger label assignments (this run)

| Label | Severity | Status |
|-------|----------|--------|
| `L-09` | Low | open — flagged for **explicit owner triage** (not auto-wont-fixed) |
| `L-10` | Low | open |
| `Q-10` | QA | qa-bundled |

`lastRun` → `yield-claim-nft-13`; `lastAuditedCommit` → `aa86be663aacc8b1da8d833dd3382094a1e0572a`.

## Artifacts

- QA report: `reports/yield-claim-nft/13/submissions/qa-report.md` (+ `4naly3er-report.md`)
- Spec-conformance: `reports/yield-claim-nft/13/submissions/spec-conformance.md`
- Findings (classified + ledger records): `reports/yield-claim-nft/13/findings/`
- Tier-3: `reports/yield-claim-nft/13/tier3/{invariant-results.md,symbolic-results.md}`
- Profiles: `reports/yield-claim-nft/13/profiles/`
- Static analysis: `reports/yield-claim-nft/13/static/`
- Ledger: `reports/yield-claim-nft/ledger.json`
</content>
</invoke>
