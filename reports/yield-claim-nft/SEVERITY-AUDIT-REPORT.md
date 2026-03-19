# Severity Audit Report: ECON-007

## Finding: Price Overflow DoS from Compound Growth

| Field | Value |
|---|---|
| Finding ID | ECON-007 |
| Contract | NFTMinter.sol, line 206 |
| Claimed Severity | Medium |
| Assessed Severity | **Low / QA** |
| Agreement | **No -- Recommend Downgrade** |
| Confidence | High |

---

## Independent Analysis

### Code Under Review

```solidity
config.price = price + (price * config.growthBasisPoints) / 10000;
```

This is a compound growth formula applied on each mint. The claim is that this will overflow `uint256` after a finite number of mints, causing a revert that blocks minting for that dispatcher.

### Mathematical Verification

The overflow claim is technically correct. However, the critical question is what the price looks like at the point of overflow.

**Case 1: 1% growth (100 bp), initial price = 1 token (1e18 wei)**

| Mints | Price (tokens) | Context |
|-------|---------------|---------|
| 100 | ~2.7 | Reasonable |
| 500 | ~145 | Reasonable |
| 1,000 | ~21,000 | Expensive |
| 2,000 | ~439 million | Exceeds most individual holdings |
| 3,000 | ~9.2 trillion | Exceeds total supply of nearly all tokens |
| 4,000 | ~1.93e17 | Astronomically impossible |
| ~4,200 | Overflow | Academic |

**Case 2: 10% growth (1000 bp), initial price = 1 token**

Overflow occurs around 420 mints, but by that point the price is approximately 1e35 tokens -- far exceeding the total supply of any token in existence.

**Case 3: Extreme growth (500% / 50000 bp), initial price = 1 token**

Even in this extreme scenario, after just 12 mints the price already exceeds 2 billion tokens. The overflow at ~76 mints is irrelevant.

### Key Conclusion

The economic denial of service (price exceeding total token supply) occurs **orders of magnitude before** the arithmetic overflow. The overflow merely changes the revert reason from "ERC20: insufficient balance" (or "ERC20: insufficient allowance") to "arithmetic overflow." The functional outcome is identical: nobody can mint.

---

## Severity Assessment

### Why This Is Not Medium

Per C4 Medium criteria: "Assets not at direct risk, but **protocol function/availability impacted**."

The overflow does NOT independently impact protocol function or availability. The function is already completely unusable due to the price being economically impossible. The overflow is a redundant failure mode on top of an already-failed state.

Additionally:
- **No funds are at risk.** The overflow causes a clean revert; no tokens are lost or locked.
- **Owner can trivially recover.** `setPrice()` resets the price at any time. `setGrowthFactor()` can also adjust growth. Both are simple owner-only calls.
- **The root cause is admin configuration.** The owner sets `growthBasisPoints` without a cap. This is a centralization/admin-configuration concern, not a protocol vulnerability.

### Overlap with Centralization Finding

The user's prompt notes that C-01 already identifies "uncapped growthBasisPoints allows owner to halt minting." The overflow described in ECON-007 is a downstream consequence of the same root cause (uncapped exponential growth configured by the owner). Reporting it as a separate Medium inflates the issue count without identifying a distinct vulnerability.

### C4 Severity Framework Application

| Criterion | Assessment |
|---|---|
| Assets at risk? | No -- clean revert, no fund loss |
| Protocol function impacted? | No -- function already unusable due to price |
| Attack path? | None -- this is not exploitable by an attacker; it is an eventual mathematical inevitability of the owner's configuration |
| External conditions? | Requires thousands of mints to reach (or extreme owner misconfiguration) |
| Recovery? | Trivial -- owner calls setPrice() |

This fits squarely in QA/Low: a state-handling observation about the mathematical endpoint of an exponential curve, with no independent security impact.

---

## Recommendation

**Downgrade from Medium to Low/QA.**

The finding correctly identifies that an arithmetic overflow will eventually occur. However, it overstates the impact by framing the overflow as a "DoS" when in reality the protocol is already in a state of economic impossibility long before the overflow triggers. The overflow adds zero additional impact beyond what the exponential pricing curve already guarantees.

If the concern is that `growthBasisPoints` is uncapped and could lead to prohibitively expensive minting, that is a centralization/admin-configuration issue (QA), not a protocol vulnerability.
