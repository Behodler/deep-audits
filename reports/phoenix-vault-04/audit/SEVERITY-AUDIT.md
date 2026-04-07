# Severity Audit Report — phoenix-vault-04

**Auditor:** severity-auditor (independent second opinion)
**Date:** 2026-04-07
**Scope:** 6 in-flight findings (5 High, 1 Medium) on `ERC4626MarketYieldStrategy` and parent `AYieldStrategy`
**Standard:** C4 regular-audit severity criteria

---

## Executive summary

| ID   | Claimed | Audited | Verdict       | Confidence |
|------|---------|---------|---------------|------------|
| H-01 | High    | Medium  | **Downgrade** | High       |
| H-02 | High    | High    | Confirm       | Medium     |
| H-03 | High    | High    | Confirm       | High       |
| H-04 | High    | Medium  | **Downgrade** | Medium     |
| H-05 | High    | High    | Confirm       | High       |
| M-01 | Medium  | Medium  | Confirm (with note) | High |

**Net change:** 5 High + 1 Medium  →  3 High + 3 Medium.

**Cross-finding clustering:** H-02, H-03, H-05 share a single root cause (per-client accounting in underlying units against a shared share pool) but each demonstrates an independent, non-overlapping exploit primitive (withdraw race, deposit dilution, surplus drain). They should remain three separate submissions — see "Clustering analysis" below.

---

## Per-finding analysis

### H-01 — Slippage anchored to vault rate (DoS + sandwich)

**Claimed:** High. **Audited: Medium.**

**What the code does** (lines 276-283, 313-328, 378-390, 428-442): every Curve swap path computes `minOut = idealUnits * (MAX_BPS - slippageToleranceBps) / MAX_BPS` where `idealUnits` comes from `vault.convertToShares` / `vault.convertToAssets`. The vault's internal rate is a slow-moving accumulator and bears no necessary relationship to the live AMM marginal price.

**Two distinct impacts asserted:**

1. **DoS on withdraw during AMM discount.** True. If the AMM trades sUSDe at, say, 0.98 USDe (a routine condition for sUSDe-style assets), `convertToAssets` returns ~1.0 per share, slippageBps is single-digit bps, and the swap simply reverts. Withdraws are bricked until the AMM price re-converges. This is a **protocol availability impact**, not direct theft.
2. **Sandwich extraction.** Asserted but materially weaker than claimed. The vault-rate-anchored `minOut` is conservative (>= the AMM-fair price) so the **swap reverts** rather than executing at an unfavorable price. A sandwich attack against a deposit/withdraw would normally need the swap to *succeed* at a manipulated price; here it would mostly *fail*. The sandwich primitive only works in the narrow case where `slippageToleranceBps` has been set wide enough to absorb the manipulation, in which case any `minOut` anchor (vault rate or oracle) would have the same problem.

**Severity assessment:**
- Impact 1 (DoS) is genuine and exploitable under routine market conditions. That maps cleanly to C4 Medium: *"protocol function/availability impacted"*. It is not direct theft of assets.
- Impact 2 (sandwich) is conditional on owner having mis-set `slippageToleranceBps` wide. This is closer to centralization-risk / configuration-risk. Even granting it, it does not push the finding to High because the asset loss path requires *both* an unfavorable owner config *and* a manipulating MEV actor — that is "value leak with stated assumptions and external requirements" = Medium.

**Verdict: Downgrade to Medium.** The DoS-on-withdraw framing alone supports Medium under C4 criteria. Reframing the report around availability impact (and dropping or scoping down the sandwich claim) would be more defensible.

**Notes for the writer:**
- Reframe primary impact as "withdrawal DoS during routine AMM dislocation" with the sandwich as a secondary supporting observation.
- The fix recommendation (oracle anchor or AMM marginal-price anchor) is independent of which impact you lead with.

---

### H-02 — `_withdrawInternal` decrements by requested, no per-client share cap

**Claimed:** High. **Audited: High.**

**What the code does** (lines 302-339): `_withdrawInternal` computes `sharesToSell = vault.convertToShares(amount)`, caps to global `availableShares`, swaps, and decrements `clientBalances[token][balanceHolder] -= amount` and `totalDeposited[token] -= amount`. There is no cap of `sharesToSell` to the calling client's pro-rata slice of the global share pool.

**Specific concern raised: is this a known issue?** The contract NatSpec says:

> Principal is decremented by requested amount, not received amount, so any shortfall accumulates as protocol-owned yield.

The documented rounding rule covers the *single-client* case where slippage produces dust. It does **not** anticipate the *multi-client* case where Client A's withdrawal under AMM dislocation burns more shares than A's pro-rata entitlement, with the missing shares coming from B's and C's pro-rata pools rather than from "protocol yield."

Concrete numerical example:
- A, B each deposited 1000 USDe; AMM was at par; pool holds ~2000 sUSDe shares; `totalDeposited = 2000`.
- AMM dislocates to 0.90 USDe per sUSDe.
- A withdraws full 1000. `sharesToSell = convertToShares(1000) = ~1000 / 1.0 = 1000` shares (vault rate is unchanged). Only ~900 USDe is received. A's principal is decremented by the full 1000.
- After: pool has ~1000 shares, `totalDeposited = 1000`, B's `clientBalances = 1000`.
- B's pro-rata share of the remaining pool is `1000 * 1000 / 1000 = 1000` shares — but those 1000 shares only redeem to ~900 USDe. B has been forced to absorb A's slippage.

**Why this exceeds the documented intent:** the documented rule says "shortfall accumulates as protocol yield." That is a truthful description for solo-client deployments, where the shortfall stays in the same pool that the next withdraw of the same client will draw from. In a multi-client deployment, the shortfall instead transfers to *other* clients. The text "protocol-owned yield" suggests the protocol benefits — not that other clients lose. The asymmetric, cross-client wealth transfer under non-trivial dislocation is **not** documented and **not** a routine rounding effect.

**Severity assessment:**
- Direct loss of one client's funds to another client.
- No special prerequisites beyond an AMM/vault rate divergence (a routine condition for sUSDe and similar).
- Exploitable by any client; first-mover advantage during a peg event.
- The "documented" defense is weak — documentation describes single-client rounding, not multi-client wealth transfer.

**Verdict: Confirm High.** Confidence Medium because a judge might interpret the natspec broadly and rule it as a known issue. **Mitigation:** the report should explicitly distinguish "documented rounding bias" from "undocumented cross-client share transfer under dislocation," and quantify the dislocation threshold below which the bug is dust and above which it's wealth transfer.

---

### H-03 — Deposit accounting in underlying units lets fair-rate depositor dilute discount-rate depositor

**Claimed:** High. **Audited: High.**

**What the code does** (lines 273-291): `_depositInternal` swaps `amount` underlying for `sharesReceived` shares via the AMM, then unconditionally sets `clientBalances[token][recipient] += amount` and `totalDeposited[token] += amount`. The actual `sharesReceived` is discarded for accounting purposes.

**Pro-rata effect:** all subsequent withdrawals compute `sharesToWithdraw = totalShares * clientBalance / totalDeposited`. Two clients who deposited 1000 USDe at *different* AMM rates have identical `clientBalances` but contributed different share quantities. The withdrawal pro-rata gives them identical shares — meaning the depositor who got more shares per underlying *subsidizes* the depositor who got fewer.

**Severity assessment:**
- Direct value transfer between depositors. No external requirements other than the AMM rate fluctuating between two deposits — a continuous condition.
- No privileged access required.
- Independent of H-02 (this happens at deposit time, not withdraw time, and works even when no peg dislocation exists at withdraw time).
- Fix is structural: track `clientShares` not `clientBalances`.

**Verdict: Confirm High.** Confidence High. This is the cleanest of the three "shared pool" findings — the loss happens deterministically with any rate fluctuation between deposits.

---

### H-04 — Two-phase total withdrawal cache desync

**Claimed:** High. **Audited: Medium.**

**What the code does:** `_initiateWithdrawal` (parent, lines 379-394) snapshots `state.balance = this.balanceOf(token, client)`, which in this concrete strategy returns `principalOf` = `clientBalances[token][client]` (line 162-164). 24 hours later, `_executeWithdrawal` (parent, lines 403-417) calls `_totalWithdraw(token, client, withdrawAmount)` passing the cached `withdrawAmount`. The concrete `_totalWithdraw` (lines 368-399) **ignores** the passed `amount` parameter for share calculation and instead recomputes:

```solidity
uint256 clientStoredBalance = clientBalances[token][client];   // LIVE read
uint256 sharesToSell = (totalShares * clientStoredBalance) / totalDeposited[token];  // LIVE
```

So the cache is not just under-snapshotting (no `totalShares`/`totalDeposited` snapshot) — it's also **completely unused for the actual computation**. The cached `amount` parameter is dead.

**Exploit assessment:**
1. **Original requestor diluted by intra-window deposits.** If a client deposits during the 24h window, `totalDeposited` and `totalShares` both increase proportionally (if the AMM is fair), so `(totalShares * clientStoredBalance) / totalDeposited` is approximately *unchanged*. Dilution requires the intra-window deposit to be at an unfair AMM rate — which is the H-03 bug, not a separate H-04 bug. In the fair-AMM case, H-04's "dilution" claim has no impact.
2. **Honest depositor swept into Phase 2.** This claim is wrong on inspection. `_totalWithdraw` only zeros `clientBalances[token][client]` for the *original requesting client*. An honest unrelated depositor's `clientBalances` is untouched. They are not "swept." However: their share of the *vault share pool* is reduced because the requesting client's `clientStoredBalance` may have grown (due to the requestor's own intra-window deposits, or the requestor's pro-rata share of the pool ballooning). In the most adversarial reading, the honest depositor's `totalBalanceOf` decreases, but they retain their `clientBalances` — so this collapses into the same H-02 / H-03 pattern.
3. **Real bug that survives:** the cached `amount` is a misleading API. A reader of `_executeWithdrawal` reasonably assumes the snapshot is binding. It is not. **But** the actual exploit primitive is just another instance of "live shared-pool reads expose all clients to each other," which is the H-02/H-03/H-05 root cause already covered.

**Severity assessment:**
- The "rugpull protection" framing is the strongest framing for High, but the rugpull-protection delay still works (the 24h delay still elapses; the owner still cannot front-run it). The cache being meaningless does not let the owner *bypass* the delay — it just lets the executed amount float.
- The asset-loss path collapses into H-02/H-03's root cause once you trace it.
- The standalone "dead cache parameter" finding is a spec/code mismatch with no independent exploit primitive: that is QA/Low at best.
- Net: there is a real *protocol availability/correctness* issue (the snapshot doesn't snapshot what it claims to), but no independent direct-theft path beyond what H-02/H-03 already cover.

**Verdict: Downgrade to Medium.** The "cache is meaningless" framing maps to *"protocol function impacted; spec deviation with security-relevant correctness implications"*. The exploit-path framing is double-counting H-02/H-03.

**Notes for the writer:**
- Consider whether to keep H-04 at all. If H-02 and H-03 are accepted, H-04's marginal value to the judge is mostly the "dead parameter" observation, which is QA. If H-02/H-03 are rejected as known issues, H-04's framing as "two-phase rugpull protection is structurally broken" gives the judge a distinct angle on the same underlying bug — keep at Medium.

---

### H-05 — `_withdrawFrom` surplus extraction operates on shared share pool

**Claimed:** High. **Audited: High.**

**What the code does** (lines 411-451): `_withdrawFrom` computes `surplus = totalBalanceOf(client) - principal`, requires `amount <= surplus`, then burns `convertToShares(amount)` shares from the global pool. The `surplus` is computed pro-rata against the *shared* share pool, and the burn comes from the *shared* share pool.

**Walkthrough confirming the bug:**
- A and B each deposit 1000 USDe; pool holds 2000 shares; `totalDeposited = 2000`.
- Pool yields 25%: pool now holds 2000 shares worth 2500 USDe.
- A's `totalBalanceOf = (2500 * 1000) / 2000 = 1250`; surplus = 250.
- B's surplus is also 250.
- A's authorized withdrawer calls `withdrawFrom(USDe, A, 250, recipient)`.
- The require `amount <= surplus` passes (250 <= 250).
- `sharesToSell = convertToShares(250) ~= 200` shares.
- After: pool holds 1800 shares worth 2250 USDe. `totalDeposited = 2000` (unchanged).
- B's `totalBalanceOf = (2250 * 1000) / 2000 = 1125`; B's surplus = 125. **B lost 125 of surplus.**
- A "fairly" should have gotten only 125 (their half of the pool's 250 surplus), but extracted 250. **A stole 125 from B.**

**Severity assessment:**
- Direct theft of one client's surplus by another client's authorized withdrawer.
- No external requirements; no peg dislocation needed.
- Routine yield accrual is sufficient; first-mover wins.
- Distinct from H-02 (which is about peg loss) and H-03 (which is about deposit-time accounting).
- The `withdrawFrom` parent function checks `clientBalance >= amount` using `balanceOf` = `principalOf`, so the require is `amount <= principal`. Combined with the inner require `amount <= surplus`, the bound is `amount <= min(principal, surplus)` — but the surplus is over-counted vs other clients, so the bound is loose enough to drain.

**Verdict: Confirm High.** Confidence High. The `_withdrawFrom`-specific surplus inflation primitive is independent of H-02/H-03 (works without any AMM dislocation, works on yield rather than principal, requires the authorized-withdrawer role).

---

### M-01 — `_emergencyWithdraw` bypasses delay and skews accounting

**Claimed:** Medium. **Audited: Medium.**

**What the code does** (lines 350-359): `_emergencyWithdraw` transfers vault shares directly to the owner. It does not decrement `clientBalances` or `totalDeposited`. The parent `emergencyWithdraw` (lines 227-233) is `onlyOwner` and has no waiting period.

**Two framings:**
1. **Delay bypass.** The `totalWithdrawal` function has the 24h two-phase delay billed as "rugpull protection." `emergencyWithdraw` is a parallel one-shot owner-only path with no delay. By itself this is **Centralization** — owner can rug instantly. Not Medium.
2. **Accounting skew.** After any owner emergency-withdraw (legitimate or otherwise), the strategy's `clientBalances` and `totalDeposited` no longer match the actual share pool. Subsequent client withdrawals compute against stale `totalDeposited`, so:
   - `sharesToSell = convertToShares(amount)` returns more shares than `availableShares`, hits the cap, and clients receive partial fills.
   - The `clientBalances[token][balanceHolder] -= amount` decrement still happens against the requested amount, so principal disappears even though clients received nothing.
   - Worse: the partial-fill cap means later clients get nothing, but their `clientBalances` is still nonzero — they're stuck with phantom principal that maps to zero shares.

**Severity assessment:**
- Framing 1 alone = Centralization (bundle separately, not Medium).
- Framing 2 = real, automatic, post-emergency accounting corruption that affects honest clients even when the owner used the function legitimately. That maps to C4 Medium: *"protocol function/availability impacted, value leak with stated assumptions"*. The "stated assumption" is "owner ever invokes the emergency path" which is realistic.
- Framing 2 is **not** Centralization because the harm continues after the owner's privileged action ends and is not under owner control.

**Verdict: Confirm Medium.** Confidence High.

**Important framing note:** the report should lead with the accounting-skew bug (Framing 2) and mention the delay-bypass (Framing 1) as a secondary observation. Leading with the delay-bypass risks the judge dismissing the entire finding as Centralization. The justification field in the JSON already does this — the writer should preserve that emphasis in the markdown report.

---

## Clustering analysis: H-02, H-03, H-04, H-05

**Question:** Should these collapse into a single Medium because they share the root cause "client accounting in underlying units against a shared share pool"?

**Analysis:** They share a root cause but each demonstrates a distinct exploit primitive that is independently triggerable and produces independently observable losses.

| Finding | Trigger condition | Loss vector | Affected role |
|---------|-------------------|-------------|---------------|
| H-02 | AMM/vault rate divergence at withdraw time | Slippage + missing per-client share cap → first withdrawer takes more shares than fair pro-rata | Any client |
| H-03 | AMM/vault rate divergence at deposit time | Deposit credits underlying-units, not received-shares → late depositor gets free shares | Any client (silent) |
| H-04 | Two-phase window state drift | Cached snapshot is meaningless; phase 2 reads live state | totalWithdrawal target |
| H-05 | Routine yield accrual + multiple clients | Surplus extraction over-counts because pool is shared | Authorized withdrawer role |

H-02 and H-03 both happen at *normal* operation; they are the strongest standalone Highs. H-05 happens to a *different role* (authorized withdrawer, not client) and requires no peg dislocation. H-04's exploit primitive collapses into H-02/H-03 once you trace it, which is part of why I'm downgrading it.

**C4 judge perspective:** A judge familiar with shared-pool accounting bugs may see H-02, H-03, H-05 as duplicates of one root cause and consolidate the payout. However, the C4 norm is that distinct exploit primitives merit distinct submissions even when the root cause is common — the judge generally preserves the separate findings but groups them under a single "fix" recommendation. **Recommendation:** submit as three separate Highs (H-02, H-03, H-05) with explicit cross-references to each other and a shared "Recommended Mitigation" section that reframes accounting around `clientShares` instead of `clientBalances`. Acknowledging the shared root cause openly is better than pretending they're independent — the judge will see it either way.

**Drop H-04 from the cluster** — submit separately at Medium with the "dead cache parameter" framing.

---

## Specific concerns addressed

### "Is H-02 a known issue (Low/Informational), or does the practical impact under AMM dislocation exceed the documented intent?"

**Answer:** The user's read is correct. The natspec at lines 22-23 documents the *single-client* rounding bias ("shortfall accumulates as protocol yield"). The *multi-client* asymmetric outcome under non-trivial AMM dislocation (where shortfall transfers to other clients rather than to the protocol) is **not** documented. The text "protocol-owned yield" implies the protocol benefits — it does not warn that other clients are debited.

The risk for the judge is interpretive: if the judge reads the natspec broadly as "we accept arbitrary shortfall in multi-client deployments," they may dismiss as known. If they read it narrowly as "rounding dust accumulates as yield," they accept H-02 as a real finding.

**Recommendation for the report writer:** explicitly acknowledge the natspec, then quantify the threshold above which the effect ceases to be "rounding dust" and becomes "wealth transfer." Numerically: at 0.5 bps slippage, dust; at 100+ bps slippage (a routine sUSDe condition during stress), full pro-rata wealth transfer. This framing makes it materially harder for the judge to dismiss as documented.

### "H-01 has two distinct impacts: (a) DoS on withdrawal during discount and (b) sandwich extraction. Both Highs?"

**Answer: neither is High.** (a) is a clean Medium (availability impact). (b) is structurally weak because the vault-anchored `minOut` is *conservative* — it makes swaps revert rather than execute at a manipulated price, which is the *opposite* of what enables a sandwich. The sandwich claim only works under wide owner-set slippage tolerance, which is configuration-dependent.

**Recommendation:** keep as a single finding at Medium, lead with DoS, drop or de-emphasize sandwich.

### "H-02, H-03, H-05 — one Medium or three Highs?"

**Answer: three Highs.** See clustering analysis above. They share a root cause but have distinct, independently exploitable primitives. C4 norm preserves separate findings in this situation; consolidation would be a judge-discretion decision after submission, not a pre-submission consolidation.

### "M-01 — Medium or Centralization?"

**Answer: Medium**, because the accounting-skew bug persists *after* the owner's privileged action and harms clients automatically, independent of further owner intent. The delay-bypass framing alone would be Centralization, but the post-action accounting corruption is Medium. The current writeup correctly emphasizes the accounting bug as the load-bearing impact.

---

## Cross-finding recommendations

1. **H-01:** Downgrade to Medium. Reframe around withdrawal DoS during AMM dislocation. Drop or scope down the sandwich claim.
2. **H-02, H-03, H-05:** Submit as three separate Highs. Add explicit cross-references and a shared "Recommended Mitigation" pointing at structural per-client share tracking.
3. **H-04:** Downgrade to Medium. Reframe around the dead `amount` parameter and the snapshot being structurally insufficient (no `totalShares`/`totalDeposited` snapshot). De-emphasize the "honest depositor swept" claim, which collapses into H-02/H-03.
4. **M-01:** Confirm Medium. Lead with accounting skew, mention delay bypass second.
5. **Cumulative submission count:** 3 High + 3 Medium (was 5 High + 1 Medium).

---

## Confidence and judgment notes

- **High confidence verdicts:** H-01 downgrade, H-03 confirm, H-05 confirm, M-01 confirm.
- **Medium confidence verdicts:** H-02 confirm (judge interpretation of natspec is the swing factor), H-04 downgrade (could plausibly stay High if you find a non-H-02/H-03 exploit primitive).
- **Areas where I could be wrong:**
  - If the AMM adapter behavior is asymmetric (e.g., `idealUnits` is computed from a route that *can* execute at a manipulated rate), the H-01 sandwich claim becomes stronger. Worth a 5-minute review of `IAMMAdapter` and the Curve adapter implementation.
  - If H-04 has a non-H-02/H-03 exploit primitive I've missed (e.g., a path where the cache desync causes share-pool inflation rather than dilution), the downgrade could be wrong.

---

## Files referenced

- `/home/justin/code/C4/solidity-audit/lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
- `/home/justin/code/C4/solidity-audit/lib/reflax-yield-vault/src/AYieldStrategy.sol`
- `/home/justin/code/C4/solidity-audit/reports/phoenix-vault-04/audit/findings/high/H-01.json` through `H-05.json`
- `/home/justin/code/C4/solidity-audit/reports/phoenix-vault-04/audit/findings/medium/M-01.json`
