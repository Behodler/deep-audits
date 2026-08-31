# QA Report for reflax-yield-vault — run-16

**Scope of this run:** regression scan @ `0110ce4` against the story-049 diff, plus **one newly-in-scope file** (`src/concreteYieldStrategies/ERC4626YieldStrategy.sol`, surfaced by the YS-01 / convertToAssets autopool fix). **0 new High/Medium.** Net-new QA this run: **2 Low** (`L-16` ECON-A, `L-17` CFG-01) and **1 spec-conformance** leg (`F-16-003`, documented separately in `submissions/spec-conformance.md` — NOT bundled here per Law-2). This run did **not** re-test the carryover Low/Centralization corpus (outside the story-049 diff); those are listed in the carryover summary table and remain OPEN.

## Summary

| Severity | Count (this run, net-new) | Carryover (still-open) |
|----------|---------------------------|------------------------|
| Low Risk | 2 (L-16, L-17) | 26 |
| Centralization | 0 net-new (C-01 re-observed) | 1 (C-01) |
| **Total featured** | **2 Low + 1 Centralization** | — |

Automated 4naly3er GAS/NC report: see **Appendix A**.

---

## Low Risk Findings

### [L-16] ERC4626YieldStrategy credits principal via fee-blind `convertToAssets`, persistently over-stating redeemable NAV <!-- id: ryv16l16 -->

**Location:** [`src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L115`](../../../../lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L115) (`_acquireShares`); propagates through `:62` (`principalOf`), `:153` (`totalBalanceOf`), `:224`, into base write-down site `AYieldStrategy.sol:748`, and out to cross-protocol consumer `StableStaker.sol:786`.

**Description:** story-049 (YS-01) changed the deposit credit in `_acquireShares` from `previewRedeem(sharesReceived)` to `convertToAssets(sharesReceived)` to fix a real Tokemak Autopool brick — some autopools mutate state inside `previewRedeem` and revert with `StateChangeDuringStaticCall` when it is called as an external view. The fix itself is correct and should **not** be reverted. The residual is that `convertToAssets` is the *fee-blind idle-NAV* exchange rate: on the deployed autopools `convertToAssets(shares) >= previewRedeem(shares)`, because `previewRedeem` reflects exit fees / curve effects that `convertToAssets` ignores. As a result `principalOf` / `totalBalanceOf` **persistently over-state the redeemable NAV** — the strategy books more principal than it could realise by actually redeeming.

**Measured magnitude (mainnet fork, re-verified via `cast` this run):**

| Autopool | Address | Over-statement |
|----------|---------|----------------|
| autoDOLA | `0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d` | **0.21 bps** |
| autoUSD | `0xa7569A44f348d3D70d8ad5889e50F78E33d80D35` | **1.07 bps** |

The gap is **flat across deposit size** (1 unit → 5M units), rising to ~3 bps only near full-pool-drain. Both are below protocol slippage tolerances on the deployed autopools, which is why this is an **honest Low at this configuration**.

**Escalation note (carry forward — magnitude is bound to the EXTERNAL vault's fee/curve config, NOT to this contract):** the over-credit scales **linearly with the wrapped vault's exit fee**. PoC: a 1% exit-fee vault yields a `10e18` over-credit on a `1000e18` deposit. **If a future strategy is ever wired to a non-trivial-exit-fee vault, this same code path is a MEDIUM** (depositors over-credited, last-out shortfall realisable). The `F-03` `StableStaker.sol:786` integration gate must be retained with a `magnitude = external vault fee config` annotation so a future high-fee vault is re-evaluated at Medium rather than silently inheriting this stale Low.

**Recommendation:** Mirror the sibling `ERC4626MarketYieldStrategy._creditedPrincipal` conservative haircut (lines ~106–133) — credit the conservative (lower) realisable value, or a STATICCALL-safe realisable value rather than the fee-blind `convertToAssets`. Do **not** revert to `previewRedeem` (that reintroduces the YS-01 Autopool STATICCALL brick).

**PoC evidence (workspace, both passing this run):**
- `workspace/reflax-yield-vault/test/poc-econ-a-exitfee-overcredit.t.sol` — mechanism: non-zero-exit-fee vault over-credits linearly with the fee; zero-fee vault shows no gap (2/2 passing).
- `workspace/reflax-yield-vault/test/fork-econ-a-autodola-navgap.t.sol` — real magnitude: `convertToAssets` vs `previewRedeem` gap on autoDOLA / autoUSD, flat across deposit size (6/6 passing).

**Cross-references:** `F-16-003` (NatSpec `:93/95` says "credits the full nominal amount (no haircut)" — doc-contradiction leg, see spec-conformance report); `F-03` / stable-staker `M-05` (cross-protocol consumer); resolves `DEDUP-15-006` (previewRedeem round-trip bound — marked resolved-into-ECON-A this run).

---

### [L-17] `addresses.json` records autoDOLA as a Vesper vaDAI VPool (non-ERC4626) — strategy bricks if used as deployment config <!-- id: ryv16l17 -->

**Location:** [`addresses.json`](../../../../lib/reflax-yield-vault/addresses.json) — chainId `"1"`.contracts.autoDOLA = `0x0538C8bAc84E95A9dF8aC10Aad17DbE81b9E36ee`.

**Description:** `addresses.json` records the mainnet autoDOLA address as `0x0538C8bAc84E95A9dF8aC10Aad17DbE81b9E36ee`. On-chain that address is `symbol() = "vaDAI"` — a **Vesper VPool, not a Tokemak Autopool and not an ERC4626**: `asset()`, `convertToAssets()`, and `totalAssets()` all **revert** against it. `ERC4626YieldStrategy` makes ERC4626 calls (`vault.deposit`, `vault.convertToAssets`, `vault.redeem`) on its configured vault, so wiring the strategy to `0x0538...36ee` would **brick it on every vault call**. The canonical Tokemak autoDOLA autopool is `0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d` (the address used in the L-16 fork measurement).

**Impact (in-scope = Low):** In *this* repo `addresses.json` is a pure reference file consumed by **nothing** in registered scope — there is no in-scope exploit or bricking path here, hence Low/QA visibility, not Medium. The flag exists so the wrong address is not silently propagated to a live deployment.

> **CRITICAL CROSS-REPO VERIFICATION FLAG — do NOT close until verified.** The live deployment wiring lives in **phoenix-phase-2-staging** (a separate repo, not checked in this run). **Verify that phoenix-phase-2-staging's deploy/migration wiring resolves autoDOLA to the real autopool `0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d`, NOT `0x0538...36ee`.** If any deploy script there reads this `addresses.json` autoDOLA entry (or otherwise resolves to `0x0538...`), it is a real **deployment-bricking bug in that project's scope (potentially Medium+)**. Keep CFG-01 OPEN until that cross-repo check is done.

**Recommendation:** Correct `addresses.json` mainnet autoDOLA to the canonical Tokemak autopool `0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d`. Cross-repo: audit phoenix-phase-2-staging's autoDOLA deployment wiring before treating this as benign.

---

## Centralization Risks

### [C-01] Owner-power bundle — emergency-withdraw owner trust + `_emergencyWithdraw` ledger desync (re-observed on newly-in-scope sibling) <!-- id: ryv16c1 -->

**Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (multiple owner setters) and the newly-in-scope sibling `src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L148-L170` (`_emergencyWithdraw`). First seen run-05; still present as of run-16. Fingerprint `679c917d…`.

**Description:** The owner-power bundle (emergency withdraw, parameter setters, route control) is carried over from [run-05's QA report](../../../05/submissions/qa-report.md). This run it was **re-observed on the newly-in-scope `ERC4626YieldStrategy.sol` sibling**: `_emergencyWithdraw` (`:148-170`) pulls funds out **without updating the strategy's principal/share ledger**, leaving `principalOf` / share accounting de-synced from the actual on-chain position after an emergency pull. This is the property that was downgraded from the original H-01 to centralization (an owner-trust action with a non-obvious ledger-desync consequence) and is **not** re-filed at High.

Folded in (one line): the `actualAmount` **dust-strand** at `:165-169` — `_emergencyWithdraw` records the requested amount rather than the `actualAmount` returned by the redeem, so any redeem shortfall/rounding leaves a small stranded discrepancy in the books.

**Impact:** After an owner emergency-withdraw, on-chain view functions (`principalOf`, `totalBalanceOf`) over-state the strategy's recoverable position until manually reconciled; downstream consumers (e.g. StableStaker accounting) read the stale figure. No external attacker; surfaced as an operational hazard under owner trust.

**Recommendation:** Update the principal/share ledger inside `_emergencyWithdraw` to reflect the actual redeemed `actualAmount` (mirror the normal-withdraw write-down path), so the ledger stays consistent after an emergency pull and no dust is stranded. See the [run-05 original report](../../../05/submissions/qa-report.md) for the full owner-power description, impact, and recommendation.

---

## Carryover Low / QA / Centralization summary (still-open, NOT re-tested this run)

These findings were reported in prior runs and remain **open** in the ledger. This run scanned only the story-049 diff + the newly-in-scope `ERC4626YieldStrategy.sol`, so the corpus below was not re-tested. Triage with `/ledger reflax-yield-vault`. Full write-ups live in the referenced prior-run reports.

| Label | Sev | First seen | Title (truncated) |
|-------|-----|-----------|-------------------|
| L-01 | Low | run-05 | `slippageToleranceBps` default-0 + setter missing sane cap |
| L-03 | Low | run-07 | No aggregate cap on per-client buffer percentages (total set-aside) |
| L-04 | Low | run-07 | `setAsideBufferSize` persists after client deauthorized |
| L-05 | Low | run-07 | `SurplusSkimmed` event under-represents buffered-path beneficiaries |
| L-06 | Low | run-07 | `skimSurplus` return-value semantics path-dependent |
| L-07 | Low | run-07 | `setRoute` accepts `tokenIn == tokenOut` / internal zero-gap paths |
| L-08 | Low | run-11 | `Ownable` used instead of `Ownable2Step` across all three contracts |
| L-09 | Low | run-11 | ERC4626 vault used as price oracle in surplus / skimSurplus calc |
| L-11 | Low | run-11 | `totalBalanceOf` and `principalOf` use different data sources |
| L-12 | Low | run-11 | `CurveAMMAdapter.swap` does not independently verify `amountOut >= minAmountOut` |
| L-13 | Low | run-12 | `_totalWithdraw` state-inconsistency: migration recorded as executed even on partial |
| L-14 | Low | run-15 | `totalWithdrawal` Phase-2 executes LIVE client balance, not Phase-1 snapshot |
| L-15 | Low | run-15 | story-047 pools ALL clients' set-aside buffers into one global setAside |
| L-01-run11 | Low | run-11 | CEI violation in `_withdrawInternal` (state after two external calls) |
| L-02-run11 | Low | run-11 | `safeIncreaseAllowance` unconditional before every AMM swap |
| L-03-run11 | Low | run-11 | `emergencyWithdraw` lacks `nonReentrant` guard (inconsistent with siblings) |
| L-04-run11 | Low | run-11 | `nonReentrant` not first modifier in declaration lists |
| L-05-run11 | Low | run-11 | Constructor `_owner` shadowing across three contracts |
| L-06-run11 | Low | run-11 | `WithdrawalExecuted` emits Phase-1 cached balance |
| L-07-run11 | Low | run-11 | `withdrawAsOwner` debits client principal while tokens go elsewhere |
| QA-01 | QA | run-11 | `abi.encodePacked()` with dynamic args into `keccak256` |
| QA-02 | QA | run-12 | `block.timestamp` drives two-phase withdrawal window |
| QA-03 | QA | run-12 | Unit-mismatch footgun: `setAsideBufferSize` PERCENT vs absolute |
| QA-04 | QA | run-12 | `totalWithdrawal` carries `whenNotPaused` — Global-Pauser blocks it |
| QA-05 | QA | run-12 | `CurveAMMAdapter` has no rescue/sweep function |
| QA-06 | QA | run-12 | `setClient` ignores bool return of `EnumerableSet.add/remove` |
| QA-07 | QA | run-12 | Integration caveat: `skimSurplus` return value (post-swap delta) |
| QA-08 | QA | run-12 | World-C skim-de-buffering owner footgun (routine `skimSurplus`) |
| QA-09 | QA | run-14 | Orphaned vault value after last `relinquishPrincipal` |

*Excluded from the open list:* `L-02` (wont-fix), `L-10` (false-positive).

---

## Appendix A — Automated 4naly3er GAS / NC report

The canonical C4-style automated QA/gas report was generated with **4naly3er** over the in-scope contracts (including the newly-in-scope `ERC4626YieldStrategy.sol`). Full output: [`4naly3er-report.md`](./4naly3er-report.md).

**Scope analysed:** `AYieldStrategy.sol`, `concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`, `concreteYieldStrategies/ERC4626YieldStrategy.sol`, `AMMAdapters/CurveAMMAdapter.sol`, plus interfaces and `mocks/MockERC20.sol`.

**Run note:** 4naly3er reads `remappings.txt`, but the source repo's `remappings.txt` omits the `pauser/=lib/mutable/pauser/src/` mapping that lives only in `foundry.toml` (so a direct run against `lib/` fails to compile with `pauser/interfaces/IPausable.sol import not found`). Because source repos are strictly read-only, 4naly3er was run against a temporary writable copy of the repo with a merged, newline-terminated `remappings.txt` — `lib/` was not modified. Output is byte-for-byte the tool's normal report.

**Result: 16 Gas Optimization classes + 22 Non-Critical classes.** Headline items:

- **GAS:** `a += b` vs `a = a + b` on state vars (8), `address(0)` assembly checks (23), unchecked-safe ops (95), custom errors vs revert strings (52), constructor-only vars → `immutable` (6).
- **NC:** missing `address(0)` checks in setters, magic numbers → `constant`s (7), critical-param events missing old+new value (7) and `indexed` fields (9+1), `renounceOwnership()` reachable while paused (NC-6/NC-17), functions >50 lines (78), absent NatSpec (2).

These are informational/gas-tier and are **not** promoted to standalone findings; they are attached as the automated baseline per C4 convention.
