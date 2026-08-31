> **Carryover QA report — audit 16** (cut down from `reports/reflax-yield-vault/16/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 17): **L-16, L-17**.
> Removed as no longer live / carried elsewhere: F-16-003 (faithfulness — see `spec-conformance-16.md`).
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Line numbers were accurate at the originating commit; re-verify against current HEAD (`cdd0743`).
>
> **Ledger mapping** (originating report label → ledger entry):
> - `L-16` → ledger `ECON-A` / `c50c08f9ee587c02`
> - `L-17` → ledger `CFG-01` / `0c12a2cfaf4b026a`

*The text below is a verbatim copy of the retained sections of the original report.*

---

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
