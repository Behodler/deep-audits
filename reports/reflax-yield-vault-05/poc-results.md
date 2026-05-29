# PoC Results — phoenix-vault (reflax-yield-vault)

- Project: phoenix-vault (maps to `lib/reflax-yield-vault`)
- Target: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
- Harness: deterministic, mock-based (no mainnet fork). Mocks:
  `test/mocks/MockERC4626Vault.sol`, `test/mocks/MockAMMAdapter.sol`, `src/mocks/MockERC20.sol`.
- Run: `cd workspace/phoenix-vault && forge test --match-path 'test/poc-*.t.sol' -vv`
- Result: **5/5 tests PASS** (the bug-demonstrating assertions pass, proving the findings).

| Finding | File | Status |
|---|---|---|
| M-01 | `workspace/phoenix-vault/test/poc-M01-overskim.t.sol` | compiles, runs, PASSES |
| M-02 | `workspace/phoenix-vault/test/poc-M02-nav-sandwich.t.sol` | compiles, runs, PASSES |
| M-03 | `workspace/phoenix-vault/test/poc-M03-socialized-slippage.t.sol` | compiles, runs, PASSES |

---

## M-01 — `_skimSurplusBatch` over-skim via duplicate `clients[]`

File: `workspace/phoenix-vault/test/poc-M01-overskim.t.sol`
Vulnerable code: `ERC4626MarketYieldStrategy.sol#L462-L488` (loop `:468-478`, ceiling `:481`).

Ported and cleaned from the confirmed invariant PoC (`test/invariant/CODE001_Poc.t.sol`).
Two tests: an exploit and a unique-list control.

Key assertions (`test_M01_duplicateClientsOverSkim`):
- `assertApproxEqRel(skimmed, 2 * trueAggregateSurplus, 1%)` — duplicate `[A,A,B,B]` skims ~2x.
- `assertLt(heldValueAfter, totalDeposited)` — held-share value falls below recorded principal.
- `assertLt(bClaim, 100_000e18)` — client B can no longer recover full principal.

Demonstrated numbers (A,B deposit 100k each, +20% NAV yield):
- true aggregate surplus = 40,000 USDe
- value actually skimmed = **79,999.99… USDe ≈ 2×** the true surplus
- `totalDeposited` unchanged at 200,000 (loss is silent in principal accounting; INV-1 holds)
- held-share value 240,000 → **160,000 USDe** (below 200,000 principal)
- client B claim falls to **80,000 USDe** → **20,000 below** B's 100,000 principal

Control (`test_M01_uniqueListIsSafe_control`): same deposit/yield with unique `[A,B]` leaves
principal fully backed and both clients recoverable — confirming duplication is the root cause.

Mock fidelity: adapter execution price synced to fair NAV before each swap, so the over-skim is
isolated as a **pure accounting defect** (no slippage economics).

---

## M-02 — NAV-anchored `minOut` is execution-price-blind

File: `workspace/phoenix-vault/test/poc-M02-nav-sandwich.t.sol`
Vulnerable code: deposit `:276-277`, withdraw `:321-322`, skim `:435-436`/`:482-483`.

The PoC sets `slippageToleranceBps = 50` (0.5%) and configures the MockAMMAdapter to deliver
exactly `(1 - bps)` of fair NAV — the worst output the NAV-derived floor still accepts — modelling
a sandwich that skews the pool below NAV but not below the floor. Two tests cover deposit and
withdraw legs.

Key assertions:
- `assertGe(out, navFloor)` — the skewed swap **clears** the NAV floor (no revert; protection
  "passes"). This is the point: `minOut` is computed from vault NAV and does NOT bound execution
  price.
- `assertLt(out, fairValue)` — the protocol nonetheless received strictly less than fair NAV value.
- `assertApproxEqRel(leak, bps * tradeSize, 0.1%)` — the leak equals the full tolerance.

Demonstrated numbers (1,000,000 USDe trade, bps = 50):
- deposit: fair shares 1,000,000; NAV floor 995,000; shares bought **995,000**; principal still
  debited at full 1,000,000; **value leaked ≈ 5,000 USDe = bps × tradeSize**.
- withdraw: fair out 1,000,000; NAV floor 995,000; received **995,000**; **leaked ≈ 5,000 USDe**.

This proves the floor caps slippage at `bps` against fair value, not against the venue price — so
the entire tolerance is extractable per swap by an MEV sandwich.

---

## M-03 — requested-not-received decrement socialises slippage → last-withdrawer shortfall

File: `workspace/phoenix-vault/test/poc-M03-socialized-slippage.t.sol`
Vulnerable code: `_withdrawInternal` `:302-339` (shares from NAV `:314`, cap `:316-318`,
requested-amount debit `:335-336`).

This is the econ-scan's "combine with ECON-01 over N cycles" mechanism, faithfully reproduced.
10 clients deposit 100,000 each while the swap venue is sustainedly adverse (deposits clear at
0.5% below NAV — the M-02 leak), so the pool is under-collateralized from inception. Withdraw leg
then runs at fair NAV; the requested-not-received debit (full 100,000 per client) drains the
under-collateralized pool. INV-1 holds throughout (`principalOf` zeroed per withdrawer;
`totalDeposited` tracks exactly).

Key assertions:
- `assertLt(backingStart, totalPrincipal)` — pool under-collateralized from inception
  (995,000 backing vs 1,000,000 principal) while INV-1 holds.
- `assertLt(sharesLeft, sharesRequested)` — the LAST withdrawer hits the
  `sharesToSell > availableShares` cap (`:316-318`).
- `assertLt(lastGot, DEPOSIT)` — last withdrawer recovers less than fully-debited principal.
- `assertApproxEqRel(DEPOSIT - lastGot, totalPoolLeak, 2%)` — the last client absorbs the whole
  pool's socialised under-collateral, not just one swap's slippage.

Demonstrated numbers (10 × 100,000, bps = 50):
- aggregate principal 1,000,000; held-share backing **995,000** at start (5,000 deposit-side leak).
- 9 early clients each fully recover **100,000** (full principal debited), draining the pool.
- last client: shares requested 100,000 > available **95,000** (cap hit); receives only
  **95,000** against fully-debited 100,000 → **silent 5,000 USDe shortfall**, exactly the pool's
  total socialised under-collateral. No insolvency revert fires.

### Note on M-03 modelling (important)
A pure *withdraw-side* skew on a flat NAV does **not** socialise on this contract: the strategy
sells `convertToShares(amount)` shares (worth `amount` at NAV) and debits principal by `amount`,
so the burned-share value equals the principal removed and each withdrawer absorbs only their own
slippage (verified — that variant left backing == principal exactly and is faithful, not a bug).
The socialised last-withdrawer shortfall therefore requires the pool to already be
under-collateralized (the M-02/ECON-01 deposit-side leak), exactly as ECON-03 states ("combine
with ECON-01 over N cycles"). The PoC injects that leak on the deposit leg, which is the
mechanistically honest way to demonstrate the shortfall. M-03 is real but is structurally a
**consequence of M-02 plus the requested-not-received accounting**, not an independent loss
primitive — consistent with the classifier's "closest call / defensible as M-02 sub-impact" flag.

---

## Reproduce

```bash
cd workspace/phoenix-vault
forge test --match-path 'test/poc-*.t.sol' -vv
# or per finding:
forge test --match-contract M01PoCTest -vv
forge test --match-contract M02PoCTest -vv
forge test --match-contract M03PoCTest -vv
```
