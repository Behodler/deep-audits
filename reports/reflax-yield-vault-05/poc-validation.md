# PoC Validation — phoenix-vault-05 (poc-validator)

Independent validation of the three Medium-finding PoCs. All run against the real in-scope
`src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`, which is **byte-identical** to the
read-only `lib/reflax-yield-vault` version (verified via `diff -q`). PoCs import the real contract
directly — no shadow reimplementation.

Run command: `cd workspace/phoenix-vault && forge test --match-path 'test/poc-M0X-*.t.sol' -vv`

## Mock fidelity (shared across all three)
- `MockAMMAdapter.swap` genuinely enforces `require(amountOut >= minAmountOut)` (line 63). So the
  contract's own `minOut` slippage logic is the thing under test — the mock does not bypass it.
- `MockERC4626Vault` uses standard proportional share math (`shares = assets*supply/totalAssets`),
  a faithful ERC4626 stand-in. `simulateYield` raises NAV by adding backing assets without minting
  shares — correct yield modelling.
- Neither mock fakes the vulnerability; the bugs live in the real contract's accounting.

---

## M-01 — `_skimSurplusBatch` over-skim via duplicate `clients[]`

**Verdict: PASS — proves claimed impact.**

Both tests pass. Demonstrated numbers (A,B deposit 100k each, +20% NAV):
- true aggregate surplus = 40,000 USDe
- value actually skimmed = **79,999.99… USDe ≈ 2×** true surplus (`[A,A,B,B]`)
- `totalDeposited` unchanged at 200,000 (loss silent in principal accounting; INV-1 holds)
- held-share backing 240,000 → **160,000 USDe**, i.e. **below** the 200,000 recorded principal
- client B claim falls to **80,000 USDe** → **20,000 below** B's 100,000 principal

The over-skim is a real loss: the duplicate-counted shares sold come out of the pool backing
*other* clients' principal (backing < principal proves it). The control test
(`test_M01_uniqueListIsSafe_control`) shows a unique `[A,B]` list leaves principal fully backed —
cleanly isolating duplication as root cause. Adapter is NAV-synced so no slippage contaminates the
result; this is a pure accounting defect, exactly as claimed.

No concern that the mock fakes it: the loop at `:468-478` reads `clientBalances` (untouched by the
caller) and sums `convertToShares(surplus)` once per array entry, ceilinged only by total held
shares (`:481`). The 2× comes from the real contract logic.

---

## M-02 — NAV-anchored `minOut` is execution-price-blind

**Verdict: PASS — proves claimed impact.**

Both deposit and withdraw legs pass. Demonstrated numbers (1,000,000 USDe trade, bps=50):
- deposit: fair shares 1,000,000; NAV floor 995,000; shares bought **995,000** (clears floor, no
  revert); principal debited full 1,000,000; backing value 995,000 → **leak ≈ 5,000 USDe**.
- withdraw: fair out 1,000,000; NAV floor 995,000; received **995,000**; **leak ≈ 5,000 USDe**.

This genuinely proves the claim: the swap clears at exactly the NAV-derived floor
(`assertGe(out, navFloor)` passes) yet delivers strictly below fair NAV value
(`assertLt(out, fairValue)` passes), and the leak equals `bps × tradeSize` to 0.1% precision. The
floor is computed from `vault.convertToShares/convertToAssets` (NAV), completely independent of the
execution price the adapter delivers — so the whole tolerance is extractable per swap. The mock
delivering `(1 - bps)` of fair NAV is a legitimate model of a sandwiched/off-peg pool; the real
contract's floor genuinely fails to catch it because it never observes execution price.

Note: this is a conditional value leak requiring public-mempool + profitable pool skew + external
MEV, consistent with the Medium classification (not a direct-theft High).

---

## M-03 — Requested-not-received decrement socialises slippage → last-withdrawer shortfall

**Verdict: PASS (compiles, runs, assertions hold) — BUT NOT an independent finding.**

The PoC passes and its numbers are internally honest (10×100k; backing 995,000 at start; 9 early
withdrawers each get full 100,000; last withdrawer hits the `:316-318` share cap and receives only
95,000 → silent 5,000 shortfall = the whole pool's socialised under-collateral).

### Independence verdict: M-03 is a DOWNSTREAM CONSEQUENCE of M-02, not independent.

I wrote and ran a counterfactual probe (since removed) to settle this definitively:

**CASE A — fair deposits (NO M-02 leak), adverse withdraw leg (0.995x within floor):**
- Pool starts fully collateralized (backing == principal == 1,000,000).
- Result: **every** withdrawer, including the last, receives exactly **99,500** (500 shortfall each).
- The slippage is spread evenly — each client absorbs only their own swap's slippage. The last
  withdrawer is NOT singled out; there is no 5,000 concentration.

**CASE B — fair deposits, fair withdraws:** last withdrawer gets full 100,000 (sanity baseline).

The "last withdrawer absorbs the WHOLE pool's loss" socialization in the M-03 PoC manifests **only
because** the PoC injects the M-02 deposit-side leak (`skewedDepositRate = 0.995e18` on the deposit
leg) to make the pool under-collateralized from inception. Without that precondition (CASE A), the
requested-not-received decrement does NOT socialise — it distributes slippage evenly and produces
no concentrated last-withdrawer shortfall.

This exactly matches the generator's own "Note on M-03 modelling" and the classifier's "closest
call / defensible as M-02 sub-impact" flag. The requested-not-received accounting
(`clientBalances -= amount` on `:335-336`) is the *amplification mechanism* that lets the M-02
deficit concentrate on the last exiter, but it produces no standalone loss on a correctly
collateralized pool. The root-cause loss primitive is M-02 (or M-01); M-03 is its distribution.

**Recommendation to severity-auditor:** Do NOT keep M-03 as an independent Medium. It is a
sub-impact / amplifier of M-02. Either (a) merge it into M-02 as an "impact amplification: deposit
leak concentrates on last withdrawer via requested-not-received debit" section, or (b) downgrade to
Low. It cannot stand alone because it has no independent loss primitive — its precondition is
another finding's leak.

---

## Summary

| Finding | Compiles | Runs | Assertions pass | Proves claimed impact | Mock fakes result? | Notes |
|---|---|---|---|---|---|---|
| M-01 | yes | yes | yes (2/2) | YES | No | Real ~2× over-skim, backing < principal, B short 20k. Solid Medium. |
| M-02 | yes | yes | yes (2/2) | YES | No | Floor blind to execution price; ~5k leak per 1M trade = bps×size. Solid Medium. |
| M-03 | yes | yes | yes (1/1) | Mechanically yes, but **dependent on M-02** | No (but precondition injected) | NOT independent — counterfactual (fair deposits) shows no socialization. Merge into M-02 or downgrade. |

All PoCs reference the real in-scope contract (verified identical to read-only lib). No PoC contains
a tautological assertion; each compares a measured on-chain quantity against fair value / principal.
