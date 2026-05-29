# Classified Findings — phoenix-vault (reflax-yield-vault)

Cold scan, no ledger, no regressions. All 6 survivors are `origin: new`. Verified against `lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (skim loop `:462-488`, withdraw accounting `:302-339`, slippage state `:40` / setter `:190-195`).

## Distribution: 3 Medium, 2 Low, 1 Centralization. No High.

| Label | Orig | Title | Severity | Plausibility |
|---|---|---|---|---|
| M-01 | DD-01 | `_skimSurplusBatch` over-skim via duplicate `clients[]` under-backs principal | Medium | n/a |
| M-02 | DD-02 | NAV-anchored `minOut` is execution-price-blind → sandwichable value leak | Medium | — |
| M-03 | DD-03 | Requested-not-received decrement socialises slippage → last-withdrawer shortfall | Medium | — |
| L-01 | DD-04 | `slippageToleranceBps` default-0 + setter missing sane cap (missing validation) | QA/Low | — |
| L-02 | DD-05 | `_skimSurplusBatch` whole-batch revert on single zero-address entry | QA/Low | — |
| C-01 | DD-06 | Centralization / owner-power bundle | QA/Centralization | — |

---

### M-01 (DD-01) — `_skimSurplusBatch` over-skim under duplicate `clients[]` — Medium
Third-party clients' principal backing. Duplicated address in caller-supplied `clients[]` counted once per occurrence (`:476`, no dedup), ceilinged only by total held shares (`:481`). Aggregate swap sells into the pool backing *other* clients' principal while `clientBalances` is intentionally untouched. Dual-confirmed: Foundry+Medusa invariant breaks (`shareBackingCoversPrincipal` / `skimCannotUnderbackPrincipal`); Halmos exact-2× counterexample for `[A,A]`/`[A,A,B,B]` with `[A,B]` proven safe; deterministic PoC leaves client B 20,000 below principal on 100k deposit. Trigger gated by `onlyAuthorizedWithdrawer` (trusted), realistic via accidental duplicate. Below C4 High bar (no external attacker / not direct theft; trusted-role trigger is a likelihood discount, not a validity bar) → Medium with confirmed PoC. **HM-vs-QA boundary flagged.**

### M-02 (DD-02) — NAV-anchored minOut execution-price-blind — Medium
`minOut = idealUnderlying × (MAX_BPS − bps) / MAX_BPS` derived from vault `convertToAssets` (sUSDe NAV), independent of the Curve pool the trade clears on (`:321-322`, `:435-436`, `:482-483`; adapter forwards verbatim). Floor can't detect a skewed pool; sandwich extracts up to `bps × tradeSize` per swap; no swap deadline widens the window. sUSDe NAV not atomically manipulable (flash-loan framing dismissed). Conditional value leak under public-mempool + profitable-pool-skew assumptions with external MEV requirement → Medium.

### M-03 (DD-03) — Requested-not-received decrement socialises slippage — Medium
`_withdrawInternal` sells `convertToShares(amount)` at fair NAV but executes worse, then debits `clientBalances`/`totalDeposited` by full *requested* `amount` (`:333-336`). Shares worth more than removed principal leave the pool → backing erodes faster than ledger (INV-1 holds). Over adverse cycles, late withdrawer hits the `sharesToSell > availableShares` cap (`:316-318`) and recovers less than debited principal — silent. Cross-client principal loss (opposite beneficiary to DD#2's "accrues to protocol"), bounded by cumulative slippage. Distinct mechanism/fix from M-02 → Medium, separate. **Closest call — defensible as M-02 sub-impact or Low; flagged.**

### L-01 (DD-04) — slippageToleranceBps default-0 + missing sane cap — QA/Low
(a) No initializer (`:40`) → defaults `0` → `minOut == ideal` → swaps revert until configured (availability-until-configured, fixed by one owner call). (b) `setSlippageTolerance` (`:190-195`) checks only `_bps <= MAX_BPS`, no sane cap (Halmos: `bps == MAX_BPS ⇒ minOut == 0`). Pure missing-validation; "owner sets 100%" is an excluded reckless-admin narrative and NOT the stated impact → QA/Low.

### L-02 (DD-05) — whole-batch revert on single zero-address entry — QA/Low
`require(client != address(0))` inside the loop (`:470`) reverts the whole batch — inconsistent with the graceful `continue` for `principal==0`/`surplus==0`. Plus unbounded caller-supplied array. Self-inflicted by trusted caller, no third-party harm, no asset loss → QA/Low.

### C-01 (DD-06) — Centralization / owner-power bundle — QA/Centralization
`setRoute`, `setSlippageTolerance`, `depositAsOwner`, `withdrawAsOwner`, `emergencyWithdraw`, skim recipient, two-phase `totalWithdrawal`. Withdrawer redirects *yield only* (never principal — INV-2 verified); owner emergency/bypass powers acknowledged; timelock sound and not bypassable. Designed/authorized behaviour (SA#5 + DD#5) → QA/Centralization bundle.

---

### Classifier notes
- No High. M-01's confirmed loss is gated by a trusted role with operational-slip trigger and no external attacker — capped at Medium per C4 High bar.
- M-03 is the closest call (defensible as M-02 sub-impact or Low); kept Medium + separate per dedup decision.
- L-01 impact must remain framed as missing validation.
