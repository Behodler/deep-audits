# Severity Audit Report -- stable-yield-accumulator-07

**Project**: StableYieldAccumulator
**Contract**: `lib/stable-yield-accumulator/src/StableYieldAccumulator.sol`
**Mode**: Regular Audit (C4 severity criteria)
**Date**: 2026-03-05

---

## Executive Summary

Two findings were reviewed. One disagreement was identified: M-01 is recommended for downgrade from Medium to QA/Low. M-02 is confirmed as Medium.

| Finding | Claimed | Assessed | Agreement | Confidence |
|---------|---------|----------|-----------|------------|
| M-01    | Medium  | QA/Low   | NO        | High       |
| M-02    | Medium  | Medium   | YES       | Medium     |

---

## M-01: Discount rate boundary allows 10000 (100%), enabling zero-payment yield extraction

### Claimed Severity: Medium
### Assessed Severity: QA/Low
### Verdict: DOWNGRADE

### Validity Assessment

The code defect is **real**. Line 330 uses `rate > 10000` (strict greater-than), which allows `rate == 10000`. When `discountRate` equals 10000, the payment formula at line 456 produces zero:

```
claimerPayment = totalNormalizedYield * (10000 - 10000) / 10000 = 0
```

The claimer receives all yield tokens and pays nothing. This is a genuine off-by-one bug in the validation logic.

### Why This Is QA/Low, Not Medium

**1. Admin-gated trigger (C4 known invalid pattern)**

The `setDiscountRate` function is `onlyOwner`. No external attacker can set the discount rate. The entire exploit path begins with the owner deliberately calling `setDiscountRate(10000)`. Per C4 guidelines, "reckless admin mistakes" are a known invalid finding pattern.

The submission argues this is a validation bug rather than an admin mistake. This framing has some merit -- the developer wrote a boundary check that fails at the edge. However, the practical exploitation still requires the admin to intentionally set a 100% discount, which any reasonable admin would understand means "free."

**2. Adjacent values produce nearly identical impact**

The code already allows `rate = 9999` (99.99% discount). At rate=9999, the claimer pays:
```
totalNormalizedYield * 1 / 10000 = 0.01% of yield value
```

For 1000 USDC of yield, the claimer pays 0.10 USDC. The economic difference between rate=9999 and rate=10000 is negligible. The off-by-one at the boundary does not create a meaningfully distinct security threat compared to values the code explicitly permits.

**3. No external attacker exploitation**

The severity matrix requires consideration of likelihood. The attack has zero likelihood from external actors -- it can only be triggered by the contract owner. Combined with the marginal impact difference at the boundary, this does not meet Medium criteria.

### Recommendation

Downgrade to QA/Low. The off-by-one is a valid code quality finding that should be fixed (`rate >= 10000`), but it does not constitute a Medium-severity vulnerability. Include in the QA report as a boundary validation defect.

---

## M-02: NFT index validation missing dispatcher verification

### Claimed Severity: Medium
### Assessed Severity: Medium
### Verdict: CONFIRMED

### Validity Assessment

The finding is **valid**. The `_validateAndBurnNFT` function (lines 472-489) accepts any dispatcher index from the caller and validates only that:

1. A dispatcher exists at that index (`dispatcher != address(0)`)
2. The caller holds the corresponding token

It does **not** verify that the dispatcher at the given index is the one designated for StableYieldAccumulator claim operations.

### Why Medium Is Correct

**1. The NFTMinter is designed as a multi-dispatcher system**

The INFTMinter interface exposes `configs(index)` returning `(dispatcher, price, growthBasisPoints)`, `nextIndex()`, and `dispatcherToIndex()`. The per-dispatcher `price` and `growthBasisPoints` fields confirm that different dispatchers have different pricing models. This is not speculative -- the interface is architecturally designed for multiple dispatchers.

**2. The attack path is concrete**

If dispatcher A (the intended SYA claim dispatcher) charges 10 USDC per NFT and dispatcher B (a promotional dispatcher) charges 0.01 USDC per NFT, a user mints from dispatcher B and passes B's index to `claim()`. The NFT is burned, the claim proceeds, and the user has bypassed 99.9% of the intended claim-access cost. No hypotheticals are required -- just that multiple dispatchers exist with different pricing, which is the system's intended design.

**3. Impact is economic, not direct asset theft**

The impact is a value leak through bypassed pricing, not direct asset theft. This aligns with C4's Medium criteria: "value leak with stated assumptions and external requirements." The assumption (multiple dispatchers with different prices) is well-supported by the interface design.

**4. External conditions are realistic but required**

The exploit requires the NFTMinter to actually have multiple dispatchers registered. While highly likely given the design, this is an external condition, which correctly places this at Medium rather than High.

### Caveats

- **Confidence is medium** because we only have the INFTMinter interface, not the implementation. We cannot confirm multi-dispatcher deployment scenarios with certainty.
- If the protocol intentionally allows any NFT type for claims (treating it as a general membership gate rather than a priced access gate), this would be working-as-designed. The per-dispatcher pricing model makes this interpretation less likely, but it cannot be fully ruled out without developer confirmation.

---

## Overall Assessment

**M-01** should be moved to the QA report. It is a real code defect but requires admin action to trigger and produces negligible marginal impact compared to adjacent allowed values.

**M-02** should be submitted as Medium. The missing dispatcher verification in a multi-dispatcher NFT system is a genuine design gap with concrete economic impact.
