# Deduplicated Findings — phoenix-vault (reflax-yield-vault)

Reconciled across `code-scan.md`, `econ-scan.md`, `static-analysis.md`, `pattern-matches.md`, `invariant-results.md`, `symbolic-results.md`. Severity below is a dedup-stage estimate; final HM-vs-QA is the severity-classifier's call.

In-scope: `ERC4626MarketYieldStrategy.sol`, `CurveAMMAdapter.sol`, `IAMMAdapter.sol`, `ICurveRouterNG.sol`.

## Consolidated finding list

### DD-01 — `_skimSurplusBatch` lacks client deduplication → over-skim under-backs principal
- **Severity (dedup estimate):** Medium (third-party client loss; likelihood tempered by trusted `onlyAuthorizedWithdrawer`, but accidental-duplicate triggerable).
- **Primary location:** `ERC4626MarketYieldStrategy.sol:462-488` (loop `:468-478`, aggregate sell `:479-486`); entrypoint `AYieldStrategy.skimSurplusBatch`.
- **Rationale:** A duplicated address in caller-supplied `clients[]` adds that client's surplus shares once per occurrence; the only ceiling is total held shares (not true aggregate surplus), so the aggregate swap sells into the share pool backing other clients' principal while principal accounting stays untouched — surfacing later as an under-collateralized withdrawal.
- **Strength:** strongest, dual-confirmed. Stateful fuzz broke `shareBackingCoversPrincipal` + `skimCannotUnderbackPrincipal` (every shrunk Foundry/Medusa counterexample ends in a duplicate-`clients[]` skim); Halmos refuted the over-skim bound for `[A,A]` and `[A,A,B,B]` (exactly 2×) with the `[A,B]` dedup control proven safe; deterministic PoC leaves client B 20,000 below principal.
- **Merged from:** CODE-001; invariant `shareBackingCoversPrincipal` / `skimCannotUnderbackPrincipal` + PoC `test_CODE001_*`; Halmos `check_skim_single_duplicate_breaks` / `check_skim_no_overskim_duplicates` / `check_skim_dedup_exact`. PM-05 and S9 absorbed here as verified non-issues.
- **Decision:** kept standalone — distinct root cause (missing dedup), distinct fix (uniqueness enforcement / independent aggregate-surplus bound).

### DD-02 — NAV-anchored `minOut` is execution-price-blind → swaps sandwichable up to `slippageToleranceBps`
- **Severity (dedup estimate):** Medium (value leak ≤ `bps`×tradeSize per swap, under public-mempool + profitable-pool requirement).
- **Primary location:** minOut sites `ERC4626MarketYieldStrategy.sol:277, :322, :384, :436, :483`; adapter forwards verbatim `CurveAMMAdapter.sol:138`.
- **Rationale:** `minOut = fairValue × (1 - bps)` is derived from the vault's own `convertToShares/convertToAssets` (sUSDe NAV), which is independent of the Curve pool the trade clears on, so the floor cannot detect a skewed pool. A sandwich extracts up to the full `bps` per swap. NAV is non-manipulable atomically for USDe/sUSDe (so Medium, not High); the residual leak is structural and bounded only by an admin parameter.
- **Sub-point (amplifier, folded in):** no swap deadline. Neither `IAMMAdapter.swap` nor `ICurveRouterNG.exchange` takes a deadline (`ICurveRouterNG.sol:27-34`, `CurveAMMAdapter.sol:138`), so a pending tx can be held and executed when the pool is most favourable to a co-located sandwich. Widens DD-02's window.
- **Merged from:** ECON-01; ECON-04 (no-deadline → sub-point); PM-01 + PM-03; minOut-formula confirmations in symbolic-results.
- **Note:** PM-01's "flash-loan NAV manipulation" framing dismissed — sUSDe NAV has no atomic manipulation lever. A future deployment with an atomically-manipulable `vault` share price would escalate this to High (deployment constraint, not a current finding).

### DD-03 — Requested-not-received principal decrement socialises slippage losses → last-withdrawer insolvency
- **Severity (dedup estimate):** Medium (slow principal bleed across the shared pool; bounded by cumulative slippage).
- **Primary location:** `ERC4626MarketYieldStrategy._withdrawInternal` (sell/decrement `:316-336`); proportional view `totalBalanceOf` `:151`.
- **Rationale:** `_withdrawInternal` sells `convertToShares(amount)` (computed at fair NAV) but executes at the worse pool price, then debits `clientBalances`/`totalDeposited` by the full *requested* amount. Shares whose fair value exceeds the removed principal leave the pool, so real backing erodes faster than principal (INV-1 still holds). Over many adverse cycles, late withdrawers hit the `sharesToSell > availableShares` cap and recover less than principal while their principal is fully debited — a silent shortfall, no insolvency revert.
- **Strength:** corroborated — the same `shareBackingCoversPrincipal` invariant captures this backing-vs-principal drift; INV-1 held throughout.
- **Merged from:** ECON-03; static review-note #3; S6/S7 (verified safe, absorbed).
- **Decision:** kept **separate** from DD-02 (distinct mechanism: loss socialization via the shared share pool, not the swap price itself; distinct fix: debit by `min(requested, fairValueOfSharesSold)` / per-client backing). Cross-referenced. Reversible: presents cleanly as a sub-impact of DD-02 if a single MEV cluster is preferred.

### DD-04 — `slippageToleranceBps` defaults to 0 and setter permits `MAX_BPS` (100%) → DoS ↔ zero-protection
- **Severity (dedup estimate):** Medium / QA (config/validation defect; owner-misconfig caveat caps it).
- **Primary location:** state `ERC4626MarketYieldStrategy.sol:40` (no initializer); setter `:190-195` (only check `_bps <= MAX_BPS`).
- **Rationale:** One parameter, two failure modes. Default `0` → `minOut == ideal` → every real-fee swap reverts (inert until configured). Settable to `MAX_BPS` (10000) → `minOut == 0` → slippage protection fully off, making DD-02's sandwich unbounded. Genuine defects: missing nonzero default and missing sane upper cap (e.g. `require(bps <= 1000)`).
- **Strength:** `bps == MAX_BPS ⇒ minOut == 0` proven by Halmos (`check_minOut_maxBps_disables`, all paths); `MAX_BPS - bps` no-underflow proven.
- **Merged from:** ECON-02; PM-02; Halmos `check_minOut_maxBps_disables`.

### DD-05 — `_skimSurplusBatch` reverts the whole batch on a single zero-address entry (+ unbounded `clients[]`)
- **Severity (dedup estimate):** QA / Low.
- **Primary location:** `ERC4626MarketYieldStrategy.sol:470` (`require(client != address(0))` inside the loop); loop bound `:468`.
- **Rationale:** The zero-address `require` lives inside the per-client loop, so one bad entry reverts the entire batch and wastes prior gas — inconsistent with the graceful `continue` used for `principal == 0` / `surplus == 0`. Combined with the unbounded caller-supplied array, a self-inflicted availability footgun for the (trusted) withdrawer.
- **Merged from:** CODE-002; Aderyn A3; S10; PM-06 / LOCAL-001.

### DD-06 — Centralization / owner-power notes (bundle for QA report)
- **Severity (dedup estimate):** QA / Centralization (no HM; designed/authorized behaviour).
- **Primary locations:** `setRoute`, `setSlippageTolerance`, `depositAsOwner`, `withdrawAsOwner`, `emergencyWithdraw`, surplus-skim recipient, two-phase `totalWithdrawal`.
- **Rationale:** Authorized withdrawer can redirect *yield only* (never principal — INV-2 verified) to any recipient; owner emergency/bypass powers are acknowledged design; the two-phase `totalWithdrawal` timelock is economically sound and not bypassable.
- **Merged from:** ECON-05; ECON-06; Aderyn A1/A2; pattern `CENTRALIZATION-ADMIN`.

## Dropped — tool noise / verified non-bugs

**Tool noise:** all 64 Semgrep INFO findings; Aderyn A4–A8; Slither S11/S12 (`_owner` shadows `Ownable._owner`).

**Verified non-bugs (do NOT re-flag):**
- S1–S5 reentrancy on AMM-swap boundary: every value-moving entrypoint carries OZ `nonReentrant`; standard ERC20, trusted Curve Router; `emergencyWithdraw` moves shares to trusted owner with no accounting mutation.
- S6/S7 strict-equality guards: safe no-ops; drift captured by DD-03.
- S8 `setRoute` uninitialized `lastToken`: fully covered by guards.
- PM-04 swap return-value trust: diverges only under fee-on-transfer/weird ERC20 (out of scope).
- Permissionless `CurveAMMAdapter.swap`: output to `msg.sender`, `forceApprove` resets each call, no standing approvals.
- ERC4626 first-depositor/inflation: N/A (no self-minted shares).
- Out-of-scope Aderyn high (`abi.encodePacked` collision `AYieldStrategy.sol:263`): base class, scope context only.

## Flagged for severity-classifier review
- **DD-01 HM-vs-QA boundary:** real third-party loss + dual formal confirmation vs the `onlyAuthorizedWithdrawer` trusted-caller gate.
- **DD-03 vs DD-02 split:** kept separate; reversible if a single MEV cluster is preferred.
- **DD-04 owner-misconfig scope:** in-scope defect is the *missing validation* (no default, no sane cap).

## Traceability map (raw → consolidated)

| Raw ID(s) | Consolidated | Disposition |
|---|---|---|
| CODE-001; invariant share-backing + PoC; Halmos skim_* | DD-01 | standalone (strongest, confirmed) |
| ECON-01; PM-01; ECON-04; PM-03; Halmos minOut monotonic | DD-02 | merged (ECON-04/PM-03 = sub-point amplifier) |
| ECON-03; static review-note #3; S6/S7 | DD-03 | separate (distinct mechanism/fix), cross-ref DD-02 |
| ECON-02; PM-02; Halmos minOut_maxBps_disables | DD-04 | separate (config/validation defect) |
| CODE-002; Aderyn A3; S10; PM-06/LOCAL-001 | DD-05 | merged into one QA robustness item |
| ECON-05; ECON-06; Aderyn A1/A2; CENTRALIZATION-ADMIN | DD-06 | bundled QA/centralization |
| Semgrep×64; Aderyn A4–A8; S11/S12 | — | dropped (tool noise) |
| S1–S5; S8; PM-04; PM-05; permissionless swap; ERC4626-inflation; AYieldStrategy:263 | — | dropped (verified non-bug / OOS) |
