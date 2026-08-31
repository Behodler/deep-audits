# Econ-Scan Report — reflax-yield-vault (reflax-yield-vault)

- Project: reflax-yield-vault (maps to `lib/reflax-yield-vault`)
- Scan type: economic / protocol-wide (Tier 2)
- Scan timestamp: 2026-05-25
- In-scope: `ERC4626MarketYieldStrategy.sol`, `CurveAMMAdapter.sol`, `IAMMAdapter.sol`, `ICurveRouterNG.sol` (context: `AYieldStrategy.sol`, `IYieldStrategy.sol`)
- Tier-1 inputs consumed: `profiles.md`, `pattern-matches.md`, `static-analysis.md`
- In-scope deployment per `AMMRoutes.json`: underlying = **USDe** (`0x4c9E…68B3`), vault = **sUSDe** (`0x9D39…3497`), settlement = Curve Router NG via the USDe↔sUSDe StableSwap route.

---

## Setting the scene: what the NAV anchor actually is

Every value-moving path (`_depositInternal`, `_withdrawInternal`, `_totalWithdraw`, `_skimSurplus`, `_skimSurplusBatch`) computes its swap floor as:

```
minOut = ideal * (MAX_BPS - slippageToleranceBps) / MAX_BPS
```

where `ideal` is `vault.convertToShares(amount)` (deposit, USDe→sUSDe) or `vault.convertToAssets(shares)` (withdraw/skim, sUSDe→USDe). The Curve adapter adds **no independent price bound** — it forwards `minAmountOut` verbatim to the router (`CurveAMMAdapter.sol:138`).

For the in-scope deployment the "vault" is **sUSDe (Ethena staked USDe)**. Its `convertToAssets/convertToShares` derive from `totalAssets()/totalSupply()`, where `totalAssets()` is the USDe held by the sUSDe contract net of the linear-vesting reward stream (≈8h vesting). This rate:

- is **not** an AMM spot price and has **no flash-loan-atomic manipulation lever** — you cannot raise sUSDe.totalAssets without actually transferring USDe into it (a gift to all holders), and mint/burn move supply and assets in lockstep at the prevailing ratio;
- drifts **slowly and monotonically upward** as rewards vest (the contract even documents "share prices only increase or stay flat");
- is therefore a *sticky, non-manipulable, but execution-price-blind* reference.

This single fact governs the entire PM-01 verdict and several findings below.

---

## VERDICT on PM-01 (NAV-anchored minOut)

**Confirmed as a real, correctly-classified weakness, but it is a Medium (value-leak under stated assumptions), not a High.** The NAV anchor is *safe* (not atomically manipulable for USDe/sUSDe) but *blind to AMM execution price*. The danger is not flash-loan NAV manipulation; it is that the floor is computed from a reference that does not track the venue the trade clears on, so the realised slippage cap is `slippageToleranceBps` measured against fair NAV — and that cap is the **only** thing standing between the trade and a sandwich. With the default/again-misconfigured `bps`, or a loosely-set `bps`, an MEV sandwich can extract up to the full tolerance on every deposit and withdrawal. NAV-as-anchor is acceptable *precisely because* it is non-manipulable for this asset; the residual risk is bounded by `bps`, which makes ECON-01 a configuration-coupled value leak rather than a standalone theft primitive. See ECON-01.

---

## Findings

### ECON-01 — Sandwichable swaps: NAV-anchored minOut caps slippage at `slippageToleranceBps` against fair value, not against execution price (Medium)

**Economic mechanism.** `minOut` is `fairValue * (1 - bps)`. A sandwich attacker who front-runs the strategy's Curve swap pushes the USDe/sUSDe pool off-peg, the strategy's trade executes at the worsened marginal price, and the attacker back-runs to restore the pool and bank the difference. The NAV floor only rejects the trade if realised output falls below `fairValue * (1 - bps)`. So the attacker's profit per swap is bounded by, and approaches, `bps × tradeSize` — the floor does nothing to detect that the *pool* was skewed, because the reference (sUSDe NAV) is independent of the pool state.

Because USDe/sUSDe is a tight stable-pair pool, organic slippage is tiny, so the operator is incentivised to set `bps` small (e.g. 10–50 bps). That is good. But the leak is *structural*: whatever `bps` is set to is extractable per round-trip, and there is no TWAP, no per-block price-impact check, and no deadline (PM-03/ECON-04) to narrow the window.

**Concrete scenario (numbers).** Operator sets `bps = 50` (0.5%). Client deposits 1,000,000 USDe.
- Strategy computes `idealShares = convertToShares(1,000,000)` and `minOut = idealShares × 0.995`.
- Attacker front-runs: buys sUSDe in the pool, raising its USDe-denominated price by ~0.4%.
- Strategy buys sUSDe at the skewed price; it still receives ≥ `minOut` (0.5% tolerance absorbs the 0.4% skew), so the swap succeeds.
- Attacker back-runs, selling the sUSDe back; nets ≈ 0.4% × 1,000,000 ≈ **~4,000 USDe** minus gas/pool fees, paid out of the client's purchased share count.
- On the matching withdrawal the same sandwich is available again.

**Preconditions.** A nonzero `bps` (required for the strategy to function at all on a real pool — see ECON-02), a public mempool (no private-orderflow/relay submission), and pool depth small enough that the round-trip sandwich nets more than Curve fees + gas. Per-tx ceiling is `bps × tradeSize`.

**Who loses what.** The depositing/withdrawing **client loses principal-equivalent value** (fewer shares bought / less USDe received) up to `bps`. It is *not* limited to yield — deposit-side leakage reduces the share count backing the client's principal, and `_withdrawInternal` decrements principal by the requested amount regardless, so the shortfall is socialised into the remaining share pool (see ECON-03). Attacker = arbitrary MEV searcher; protocol/other clients bear residual via the shared share pool.

**Severity rationale.** Value leak with an external requirement (public mempool + profitable pool conditions) and bounded by an admin-set parameter → **Medium**. Not High: no atomic NAV manipulation, no unbounded theft, and the operator can (and on a stable pair will) hold `bps` low. Mitigations: route swaps through a private relay, set `bps` as tight as the pool's organic slippage allows, and/or add a real execution-price/TWAP cross-check in the adapter.

---

### ECON-02 — `slippageToleranceBps` is unbounded at 100% and defaults to 0: misconfiguration flips between full-DoS and zero-protection (Medium → at most Medium; centralization-flavoured)

**Economic mechanism.** Two failure modes from one parameter:
- **Default 0** (no constructor init): `minOut == ideal` (0% tolerance). Any real Curve fee/spread makes every swap revert → strategy is inert until the owner calls `setSlippageTolerance`. Availability, not loss.
- **Set to `MAX_BPS` (10000 = 100%)**: `minOut = 0`. Slippage protection is fully disabled; *every* swap accepts any output ≥ 0, so ECON-01's sandwich is unbounded (attacker takes the entire trade value minus dust). The setter's only check is `_bps <= MAX_BPS`, which *permits* the catastrophic 100% value.

**Concrete scenario.** Owner intends 0.5% but fat-fingers `5000` (meant 50). `minOut` becomes `ideal × 0.5`. A sandwich can now extract up to 50% of every deposit/withdrawal — e.g. a 1,000,000 USDe deposit can be drained to ~500,000 USDe of shares. Funds are not "stolen by the owner," but the parameter space lets a single typo turn every client flow into a 50%-haircut faucet for MEV.

**Preconditions.** Owner misconfiguration (acknowledged-trusted owner) OR deployment with default 0 (inert). Per audit rules owner mistakes are largely out of scope, which caps this at **Medium/QA**; the *missing sane upper bound* (e.g. require `bps <= 1000`) and *missing nonzero default* are the genuine code defects worth a recommendation.

**Who loses what.** Default-0: nobody loses, strategy just doesn't work (operational). 100%/loose: clients lose up to `bps` per swap to MEV (as ECON-01). Recommend a hard cap well below 100% and a sane constructor default so neither extreme is reachable.

---

### ECON-03 — Requested-vs-received principal decrement socialises sandwich/slippage losses onto the remaining share pool; not directly drainable but creates real accounting drift (Medium)

This is the economic *consequence* of the INTENDED design note (decrement principal by requested, not received). The design itself is not a bug — but its **interaction with ECON-01/ECON-02 and the shared share pool** is an economic effect Tier 1 explicitly deferred here, so it is evaluated, not re-flagged.

**Economic mechanism.** `_withdrawInternal` sells `sharesToSell = convertToShares(amount)` (capped to held shares), forwards `underlyingReceived` to the recipient, then debits `clientBalances[holder] -= amount` and `totalDeposited -= amount` by the **requested** `amount`. The proportional-value view `totalBalanceOf = totalValue × principal / totalDeposited` means each remaining client's claim is `(their principal / Σ principal) × (USDe value of all held shares)`.

Key asymmetry: when a withdrawing client is sandwiched (ECON-01) or eats slippage, the strategy **sells more shares than fair value would require to honour `minOut`'s loose floor** but only debits the requested principal. The shares actually leave the pool; the principal denominator drops by the requested (full) amount. Net effect:

- The withdrawing client receives less USDe than their principal-share would fairly command (they absorb their own slippage — fine, intended).
- But because `convertToShares(amount)` is computed at fair NAV while the *execution* is at a worse pool price, the strategy can burn shares whose fair value exceeds the principal removed from the denominator, **depleting the per-share backing of everyone left**. Over many sandwiched cycles `Σ clientBalances` (principal) stays exact (INV-1 holds) but `vault.balanceOf(strategy)` (real backing) erodes faster than principal, so `totalBalanceOf` for late clients falls **below** their principal.

**Last-withdrawer insolvency.** Combine with ECON-01 over N cycles: the final clients to withdraw find `convertToShares(theirPrincipal) > availableShares`. The `sharesToSell > availableShares` cap (`:316`) silently sells only what's left; they get back less than principal, while their principal is still fully debited. There is no on-chain insolvency revert — it surfaces as the last clients being unable to recover principal. Yield (surplus) is consumed first, then principal backing.

**Concrete scenario (rough numbers).** 10 clients, 100,000 USDe each (1,000,000 total). Pool is repeatedly sandwiched at the configured `bps = 50`, leaking ~0.5% per withdrawal. After 8 clients fully withdraw, each leaked ~0.5% of their trade into MEV that came partly out of shared backing; the share pool now backs ~995,000-equivalent minus cumulative leak. The last 2 clients (200,000 principal) find the pool backs < 200,000 USDe of sUSDe; they withdraw at a loss while their principal is zeroed. The drift is bounded by total cumulative slippage, so it is a slow bleed, not an instant drain — hence Medium, not High.

**Preconditions.** Repeated sandwiching or sustained adverse slippage (ECON-01), multiple clients sharing one strategy instance, no surplus buffer left to absorb the bleed.

**Who loses what.** Late/last withdrawers lose principal; the leak is funded by MEV searchers; the protocol's "shortfall accrues as yield" framing is *inverted* under adverse execution — the shortfall accrues as a **negative** yield socialised across the pool. Recommend: debit principal by `min(requested, fairValueOfSharesActuallySold)` or track backing per-client, OR document that one strategy instance must not be shared across mutually-distrusting clients.

---

### ECON-04 — No swap deadline widens the MEV/stale-price window on every path (Low/QA, amplifier of ECON-01)

**Economic mechanism.** Neither `IAMMAdapter.swap` nor `ICurveRouterNG.exchange` accepts a deadline (PM-03). A validator/builder can hold a pending deposit/withdraw tx and execute it later when the USDe/sUSDe pool is most favourable to a co-located sandwich, bounded only by the NAV floor (which, per ECON-01, doesn't track the pool). This does not create a new loss class; it removes the time bound on ECON-01's window.

**Who loses what.** Same parties as ECON-01; marginal. Standalone severity **Low/QA**; matters mainly as an amplifier. Recommend threading a `deadline` into the adapter interface (acknowledging the current `ICurveRouterNG` binding omits it).

---

### ECON-05 — Surplus skim economics: who can call, redirection, rounding (Low / informational — design is sound)

**Assessment.** `skimSurplus`/`skimSurplusBatch` are `onlyAuthorizedWithdrawer` (owner-granted). Principal is provably never mutated (INV-2, verified): both single and batch paths leave `clientBalances`/`totalDeposited` untouched and only sell shares above the principal line. The batch path snapshots `totalValue` once and floors `convertToShares(surplus)` per client (protocol-favouring rounding), and the recipient is a caller-supplied address.

- **Can yield be redirected/stolen?** An authorized withdrawer can send skimmed surplus to any `recipient`, including themselves. This is *designed* withdrawer power (the role exists to harvest yield to a treasury). Per the audit rule (designed/authorized behaviour is not an "attack") this is **not** a finding — it is a centralization note: a compromised/misbehaving withdrawer can divert *yield only*, never principal. **QA/Centralization.**
- **Rounding direction.** All `convertToShares`/`convertToAssets` and the `× (MAX_BPS - bps)/MAX_BPS` haircut floor → favour the protocol; per-client flooring in the batch loop accumulates at most dust (≤ 1 wei × clients). Protocol-favouring, bounded, intended. **Not a finding.**
- The batch's surplus is exposed to the **same ECON-01 sandwich** on its single aggregate swap, but proceeds go to a treasury recipient, so the loss (if any) is to harvested yield, not principal — lower stakes.

No standalone HM here; recorded as QA/centralization context.

---

### ECON-06 — Two-phase `totalWithdrawal` timelock: economically sound, minor griefing only (Low/QA)

**Assessment.** Phase 1 caches `balance` and starts a 24h wait; Phase 2 (after 24h, within 72h) executes `_totalWithdraw`, which **re-derives** `sharesToSell` live from current `clientBalances`/`totalDeposited` (`:379`) — the cached `amount` is effectively unused for sizing. State is reset before the external call (`_executeWithdrawal`), so no reentrancy lever.

- **Can the timelock be bypassed?** No. There is a single execute path; `None/Expired → initiate`, `Initiated → revert (still waiting)`, `Executable → execute`. No way to shortcut the 24h. The owner could re-initiate repeatedly, but each cycle still imposes ≥24h — the community always gets advance notice via `WithdrawalInitiated`. The mechanism does what the README claims (community rug-protection notice window).
- **Griefing.** Because sizing is recomputed live, a Phase-1 snapshot of `balance` that later shrinks (e.g. the owner runs `withdrawAsOwner` or a skim in between) just means Phase 2 withdraws the current proportional amount — no over-withdrawal, INV-1 preserved. The only "griefing" is the owner being able to keep a client's `withdrawalStates` perpetually in flux, which is self-inflicted owner behaviour (trusted). 
- **Interaction with ECON-01:** Phase 2's swap is sandwichable like any other, and proceeds go to `owner()` for redistribution — loss (if any) lands on the migrating funds, mitigated by the owner being able to choose execution conditions within the 48h window.

No HM. **QA/Centralization** at most. The timelock is the correct rug-mitigation control and is not economically bypassable.

---

## Items explicitly evaluated and dismissed (no re-flag)

- **Flash-loan atomic NAV manipulation of `convertToAssets`/`convertToShares`:** **Not viable for USDe/sUSDe.** sUSDe NAV is an internal totalAssets/totalSupply ratio with reward vesting, not an AMM spot. No same-tx lever raises it without a real USDe donation (which benefits all holders, not the attacker). The NAV anchor is a *poor-but-safe* slippage reference — this is the core reason PM-01 is Medium, not High. (Note: a *different* future deployment whose `vault` had an atomically-manipulable share price would convert ECON-01 into a High; flagged as a deployment constraint.)
- **First-depositor / ERC4626 inflation:** N/A — strategy mints no shares of its own; it tracks raw-underlying principal and buys external shares (confirms profiles.md suppression).
- **Permissionless adapter `swap`:** confirmed no standing approvals or inter-call balances to capture; `forceApprove` resets each call. Not exploitable.
- **Owner emergency powers** (`emergencyWithdraw` raw shares, `depositAsOwner`/`withdrawAsOwner` bypass pause): centralization, acknowledged design → QA/Centralization, not HM.
- **Unbounded `clients[]` loop (LOCAL-001/PM-06):** trusted `onlyAuthorizedWithdrawer`, caller-bounded array → self-DoS, QA.

---

## Summary table

| ID | Title | Severity | Loss class | Bearer |
|----|-------|----------|-----------|--------|
| ECON-01 | NAV-anchored minOut → sandwichable, slippage capped at `bps` vs fair value | **Medium** | value leak ≤ `bps`×size per swap | depositing/withdrawing client (then socialised) |
| ECON-02 | `slippageToleranceBps` 0-default / 100%-max: DoS ↔ zero-protection | **Medium / QA** | inert, or unbounded leak if maxed | clients / availability |
| ECON-03 | Requested-not-received decrement socialises slippage; last-withdrawer insolvency | **Medium** | principal bleed over many cycles | late/last withdrawers, shared pool |
| ECON-04 | No swap deadline widens MEV window | Low/QA | amplifier of ECON-01 | as ECON-01 |
| ECON-05 | Surplus skim redirection / rounding | QA/Centralization | yield only (designed power) | n/a (authorized) |
| ECON-06 | Two-phase timelock | QA/Centralization | none (sound) | n/a |

**Headline:** the strongest finding cluster is the NAV-anchored slippage floor (ECON-01) and its socialisation via requested-not-received accounting (ECON-03), both Medium. PM-01's "flash-loan NAV manipulation" framing does **not** hold for the in-scope USDe/sUSDe asset (NAV is non-manipulable atomically); the real, demonstrable risk is execution-price-blind slippage capped only by an admin parameter (ECON-01/02), bleeding into shared-pool principal over time (ECON-03).
