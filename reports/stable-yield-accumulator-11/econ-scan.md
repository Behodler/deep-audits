# Economic Scan — StableYieldAccumulator

- **Target:** `lib/stable-yield-accumulator/src/StableYieldAccumulator.sol` @ 71abe3e
- **Tier:** 2 (econ-scanner) — reasoning over `profile.md` + `pattern-matches.md`, source read selectively.
- **Economic model:** permissionless arbitrage hop. Claimer pays one `rewardToken`, receives batched
  surplus skimmed from all registered strategies; pays `yield * (10000 - discountRate)/10000` denormalized
  to reward-token decimals. Payment split `nudgeSplit`% to `nudge`, remainder to Phlimbo. 1 ERC1155 burned
  per claim. Cross-stable value via owner-set `normalizedExchangeRate` (no oracle).
- **Date:** 2026-05-27

> Local arithmetic correctness (rounding *direction* per function, decimals<=18 bound, split conservation
> I4) is trusted from the profile. This scan is the protocol-side conservation / incentive layer only.

---

## ECON-01 — `actualPayment` floors to 0 while yield is delivered: free-yield dust leak (the rounding-to-zero seed)

- **Severity guess:** LOW (QA). Real protocol-side leak, but de-minimis and economically self-limiting.
- **Where:** `claim()` L494–L509; `_denormalizeAmount` L617–L640.

**The math.** Yield is accumulated at 18dp from *actual* `underlyingReceived` (L489). Payment:

```
claimerPayment = totalNormalizedYield * (10000 - discountRate) / 10000     // 18dp  (L497)
actualPayment  = _denormalizeAmount(claimerPayment, rewardToken)           // reward-token dp (L498)
```

For a 6dp reward token (USDC) with config `{decimals:6, rate:1e18}`, `_denormalizeAmount` floors:
`actualPayment = claimerPayment / 1e12` (L634). The only zero-payment guard is
`totalNormalizedYield == 0 -> ZeroAmount` (L494). There is **no** `actualPayment == 0` guard. So when
`claimerPayment < 1e12` (18dp), `actualPayment == 0`, `safeTransferFrom(...,0)` succeeds, and the claimer
keeps the skimmed yield while paying **nothing** to Phlimbo.

**Quantifying max extractable value per claim.**
- `1e12` in 18dp normalized = `1e12 / 1e18` USD = **$1e-6** = exactly one USDC-wei (6dp smallest unit).
- At the documented `discountRate = 200` (2%): `claimerPayment ≈ totalNormalizedYield * 0.98`. To floor to 0
  you need `totalNormalizedYield < ~1.0204e12`, i.e. **< ~1 USDC-wei of normalized yield (~$0.000001)**.
- The free yield delivered to the claimer is the underlying skimmed, which is at most that same
  ~1-reward-token-wei of value. **Ceiling: under one reward-token-unit (sub-$0.000001) of value per claim.**

**Who profits / who loses.** Claimer gains ≤ ~1 reward-token-wei of yield for free; Phlimbo (stakers) loses
the same. Per-claim magnitude is below the smallest payable unit by construction.

**Repeatable / profitable?** No. Every claim burns exactly 1 ERC1155 NFT (L536) and runs the full
multi-strategy `skimSurplus` loop + 3–5 external calls (gas easily $0.10s–$1s on L1). The extractable value
($1e-6 per claim) is dwarfed by NFT cost + gas by ~5–6 orders of magnitude. **Not profitable; cannot be
batched to escape the per-claim NFT+gas cost** (1 NFT burned per `claim`, no loop inside a single claim that
re-triggers the floor). It is a genuine protocol-side conservation gap (the contract should arguably revert
on `actualPayment == 0` for symmetry with the `totalNormalizedYield == 0` guard) but the impact is dust.

**Interaction with high discount (amplification check).** At `discountRate = 9999` (99.99%), the floor-to-0
threshold rises to `totalNormalizedYield < ~1e16` = **~$0.01** of normalized yield free per claim. Still
sub-cent, still 1 NFT + full-loop gas per claim — uneconomic. The amplifier is the owner-set discount
(see ECON-02), not a claimer-side exploit.

**Recommendation (QA):** add `if (actualPayment == 0) revert ZeroAmount();` after L498 so a claim that
delivers yield but rounds payment to nothing reverts (claimer simply waits for more surplus to accrue). This
is a conservation hardening, not a fix for an active exploit.

**Verdict:** Genuine but de-minimis protocol-side leak. **LOW/QA**, not High/Medium — the per-claim ceiling
is below one payable unit and the NFT+gas cost makes it strictly unprofitable to farm.

---

## ECON-02 — `discountRate` up to 10000 bps (100%) = free yield; owner-set depeg rate as value lever

- **Severity guess:** QA / Centralization (Low). NOT an exploit — designed owner behavior.
- **Where:** `setDiscountRate` L324–L330 (`rate > 10000` reverts, so `==10000` allowed); `_denormalizeAmount`
  exchange-rate path L628–L630; `setTokenConfig` rate unbounded above.

**Analysis.** At `discountRate == 10000`, `claimerPayment = totalNormalizedYield * 0 / 10000 = 0`, so the
claimer pays nothing and receives all skimmed surplus. Likewise the owner-set `normalizedExchangeRate` is the
*only* cross-stable price and has no upper bound (`setTokenConfig` L280 checks only `decimals<=18`). A
near-zero (non-zero) rate makes claimers underpay; an inflated rate makes them overpay.

**Why this is QA, not High.** Both levers are `onlyOwner`. The economic model in the submodule CLAUDE.md
explicitly states the owner adjusts rates "for permanent depegs" and sets the discount as the claimer
incentive. A 100% discount or an adversarial exchange rate is *reckless/compromised admin* — per the project
exclusion list ("reckless admin mistakes" are known-invalid) and the prior-guidance rule against framing
designed owner behavior as an exploit. There is no privilege-escalation path: a non-owner cannot set these.

**Bounded-leak / depeg framing (parametric, per prior guidance).** The author has previously accepted the
oracle-free, owner-set-rate tradeoff as a bounded leak (reflax NAV-floor precedent). I do **not** re-litigate
it. Framed parametrically: for an off-true exchange rate error `e` (fraction), per-claim value transfer is
`|e| * totalNormalizedYield` denormalized, capped by available surplus and the owner's willingness to set a
wrong rate. This is the accepted oracle-free design surface, not a new finding.

**Recommendation (QA only, optional):** if the protocol wants a guardrail against fat-finger, cap
`discountRate` below 10000 (e.g. <= 5000) and add a sane upper bound on `normalizedExchangeRate`. Owner-trust
remains the security model; this is defense-in-depth, not a vulnerability.

**Verdict:** Centralization/QA. Reject any "owner can drain via 100% discount" High framing — that is
designed owner authority, explicitly documented, and excluded.

---

## ECON-03 — NFT-per-claim economics: accumulate-then-claim and griefing — NOT exploitable

- **Severity guess:** Informational (no finding).
- **Where:** `_validateAndBurnNFT` L531–L540 (burns exactly 1, magnitude-independent); `claim` L443.

**Accumulate-then-claim ("wait for huge yield, claim with 1 cheap NFT").** This is the **intended
mechanism**, not a game. The discount is the explicit reward for performing the conversion; the NFT is a
permission gate, not a yield-proportional fee. A claimer who waits for large surplus pays
`yield*(1-discount)` for it — they do not get the yield free, they get the *discount* on it. The protocol
receives full payment-minus-discount to Phlimbo regardless of timing. No value leaks: bigger yield => bigger
payment. There is no economic flaw here; sizing the claim is exactly what claimers are incentivized to do.

**Griefing ("claim tiny yield repeatedly to waste others' opportunity").** To claim, an attacker must (a)
hold a valid NFT and burn it, and (b) pay `yield*(1-discount)` for whatever surplus exists. Claiming tiny
surplus repeatedly burns the attacker's own NFTs and gas while *paying Phlimbo the (discounted) value each
time* — the surplus is consolidated, which is the protocol's goal. The attacker cannot deny others surplus
that doesn't exist yet, and any surplus they take is paid for. This is self-funded, counter-productive grief
with no victim — not a finding (mirrors PM-02's self-funded-donation verdict).

**MEV / sandwich on who claims accumulated surplus.** Claiming is a pure race: first valid NFT-holder to land
the tx gets the discount spread on currently-accrued surplus. This is **designed permissionless competition**
("decentralized conversion" per CLAUDE.md) — the spread is the incentive that is *supposed* to be competed
for. A searcher front-running another claimer simply means the conversion happens; Phlimbo still receives the
discounted payment. No protocol value is extracted by ordering — only the claimer-side spread is contested
among claimers (a transfer between competing claimers, not a protocol loss). Standard, documented MEV
exposure; not a vulnerability.

**Verdict:** No finding. The "wait and claim big" behavior is the design; griefing is self-funded; MEV is the
intended permissionless race. Reject any framing of intended claimer behavior as an exploit.

---

## ECON-04 — `nudgeSplit` routing / rounding — conservative, no leak

- **Severity guess:** Informational (no finding) — confirms profile I4.
- **Where:** `claim` L512–L520.

`nudgeAmount = actualPayment * nudgeSplit / 100`; `phlimboAmount = actualPayment - nudgeAmount`. The split is
**subtraction-derived**, so `nudgeAmount + phlimboAmount == actualPayment` exactly with zero dust loss
(profile I4 VERIFIED). Rounding on `nudgeAmount` floors toward Phlimbo (the protocol recipient), i.e. any
sub-unit favors Phlimbo, never the `nudge`. `nudgeSplit <= 100` enforced (L397). The `nudgeSplit>0 &&
nudge==0` inconsistent state reverts inside `claim` (I7, L506) rather than mis-routing. No value leaks to or
from `nudge` beyond the configured percentage. No finding.

---

## ECON-05 — `exemptStrategies` imbalance check — payment tracks delivered yield, no skim/pay mismatch

- **Severity guess:** Informational (no finding).
- **Where:** `claim` exempt loop L471–L479 vs accumulation L484–L491; mirrored in `calculateClaimAmount`.

**Concern tested:** can a claimer skim *some* strategies' yield while the payment is computed over a
*different* set, underpaying? **No.** The exempt check (L472–L479) `continue`s *before* `skimSurplus`
(L484) — an exempted strategy is neither skimmed nor accumulated. Payment is built only from
`underlyingReceived` of strategies that were actually skimmed (L489). Skim-set and pay-set are the **same
set** by construction. `calculateClaimAmount` applies the identical exempt filter (L659–L672), so the preview
matches the charge. Exempting a strategy reduces *both* the yield received and the payment owed
symmetrically — no imbalance, no underpayment. `exemptStrategies` is purely a DoS escape hatch (route around a
reverting strategy), with no value asymmetry. No finding.

> Note: a malformed `exemptStrategies` reverts before the NFT burn (profile I5), so the escape hatch cannot be
> abused to consume NFTs. Confirmed.

---

## Summary (concise)

| ID | Title | Severity | Verdict |
|---|---|---|---|
| ECON-01 | `actualPayment` floors to 0 while yield delivered (no `actualPayment==0` guard) | **LOW/QA** | Genuine but de-minimis (≤ ~1 reward-token-wei/claim, ~$1e-6); strictly unprofitable — 1 NFT + full-loop gas per claim dwarfs it. Recommend revert-on-zero hardening. |
| ECON-02 | 100% discount + unbounded exchange rate = owner value lever | QA / Centralization | Designed owner authority, documented depeg adjustment; excluded "reckless admin". Optional guardrail caps only. Not an exploit. |
| ECON-03 | NFT-per-claim: accumulate-and-claim / grief / MEV | Info (no finding) | "Wait & claim big" is the intended mechanism (discount, not free yield); grief is self-funded; MEV is the designed permissionless race. |
| ECON-04 | `nudgeSplit` routing/rounding | Info (no finding) | Subtraction-derived split, exact conservation, floors toward Phlimbo. |
| ECON-05 | `exemptStrategies` skim/pay imbalance | Info (no finding) | Exempt filter precedes skim; pay-set == skim-set; symmetric. |

**Headline:** No High/Medium economic finding. The strongest seed (rounding-to-zero, ECON-01) is a real
conservation gap but bounded to sub-one-reward-token-unit per claim and made strictly unprofitable by the
mandatory 1-NFT-burn + full-loop gas cost — **LOW/QA** at most. All other seeds resolve to designed owner
authority (excluded) or designed/intended claimer behavior (reject-the-framing per project guidance).
