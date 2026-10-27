# Carryover QA report — originating audit 21 (carried into yield-claim-nft-23)

> **Carryover QA report — audit 21** (pruned copy of `yield-claim-nft/reports/21/submissions/qa-report.md`, taken from the run-22 pruned carryover `reports/22/submissions/carryover/qa-report-21.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 23). Carried at `c5ad56d` (`c5ad56df5b5dc3f68a6f6a5e4e5f95ef532a2238`), run 23, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **Q-22, Q-23**.
> Removed as no longer live: **none since run 22** (no ledger status changed). 
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the source changes in this run's range `0fd6bdf..c5ad56d` are the new `src/NFTBonfire.sol` (story-053), the deletion of `src/dispatchers/BalancerPoolerV2.sol` and the Balancer interfaces (story-050), and comment/NatSpec-only renames in `NudgeRatchetDelayRelease.sol`, `Uniboost.sol` and `IUniboostPooler.sol`. No retained entry's code logic changed (`NFTMinterV2.sol`, `src/hooks/**` and `src/migration/**` are unchanged), no fix landed for any of them, and no human triage disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-23 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/21/submissions/`), not from this `carryover/` folder. Original report: [`reports/21/submissions/qa-report.md`](../../../21/submissions/qa-report.md). Re-verify every location against `c5ad56d` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks are kept as history; the run-23 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 23) | Re-observed in run 23 | Contract |
> |---|---|---|---|---|---|---|---|
> | Q-22 | ycn21q22 | `7b76f3476e3799ce95d2a3894701dd1034ae3c9e6c15ff1aaabbf42ccbb942f2` | `open` | yield-claim-nft-21 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |
> | Q-23 | ycn21q23 | `ae13a21ad90ba7ee27762455c011d52bc93a48d4e178428092fb33c0a33c4476` | `open` | yield-claim-nft-21 | yield-claim-nft-22 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |

<details><summary>Provenance: run-22 carryover header (kept verbatim, including the nested run-21 provenance notes)</summary>

> **Carryover QA report — audit 21** (pruned copy of `yield-claim-nft/reports/21/submissions/qa-report.md` (originating commit `267660b`)). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **Q-22, Q-23**.
> Removed as no longer live: none of the run's new findings (Q-22, Q-23 both still `open`). Structural sections not copied: preamble/Summary, "Fix Verification: run-20 `fix-pending` items" (L-21, L-25, Q-19 since closed `fixed` 2026-10-02; its Q-21 paragraph is carried under Q-21 in `qa-report-20.md`), the Carryover index (superseded by this run's carryover set), "Parked, not dropped" (MR21-* live in `reports/21/manual-review.json`), and Appendices A/B (4naly3er and static tool noise, regenerated each run).
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | Q-22 | ycn21q22 | `7b76f3476e3799ce95d2a3894701dd1034ae3c9e6c15ff1aaabbf42ccbb942f2` | `open` | yield-claim-nft-21 | yield-claim-nft-21 | no (carried; code unchanged) | `src/dispatchers/UniPoolerV2.sol` |
> | Q-23 | ycn21q23 | `ae13a21ad90ba7ee27762455c011d52bc93a48d4e178428092fb33c0a33c4476` | `open` | yield-claim-nft-21 | yield-claim-nft-22 | yes | `src/dispatchers/UniPoolerV2.sol` |

</details>

---

## QA / Non-Critical Findings

### [Q-22] `UniPoolerV2` "Overflow bound" NatSpec still bounds `_swapAmount`'s checked product by `uint112` reserves and a balance cap, and neither holds for `quotePool` after `267660b` <!-- id: ycn21q22 -->

**Location:** [`src/dispatchers/UniPoolerV2.sol#L72-L76`](https://github.com/Behodler/yield-claim-nft/blob/267660b96b92160a21919b043e571f2dbe51d216/src/dispatchers/UniPoolerV2.sol#L72-L76) (contract dev notes), feeding [`quotePool` #L501-L502](https://github.com/Behodler/yield-claim-nft/blob/267660b96b92160a21919b043e571f2dbe51d216/src/dispatchers/UniPoolerV2.sol#L501-L502) and [`_balances` #L529-L535](https://github.com/Behodler/yield-claim-nft/blob/267660b96b92160a21919b043e571f2dbe51d216/src/dispatchers/UniPoolerV2.sol#L529-L535)

**Description:** The dev note justifies the checked product inside `_swapAmount` with two premises:

```solidity
///      **Overflow bound.** `r * (r * 3988009 + a * 3988000)` is evaluated with checked
///      arithmetic. V2 reserves are `uint112` (< 5.2e33), and `a` is capped by this contract's
///      sUSDS balance which, to be added as liquidity at all, must also fit `uint112`; the product
///      is then below 5.2e33 * (5.2e33 * 4e6 * 2) ~= 2.2e74, far under 2^256 ~= 1.16e77. An
///      out-of-range input reverts rather than wrapping.
```

`267660b` switched `quotePool` from `getReserves()` to `_balances()`, so `r` on the quote path is now a `uint256` `balanceOf(pair)`, not a `uint112` reserve:

```solidity
function quotePool(uint256 sUSDSIn) external view returns (uint256 swapIn, uint256 phusdOut, uint256 expectedLP) {
    (uint256 rS, uint256 rP) = _balances();          // :502, uint256 balanceOf(pair)
    swapIn = _swapAmount(rS, sUSDSIn);
```

`quotePool` also never caps `sUSDSIn` by the contract's balance. Its own `@dev` says it "does not check the contract's balance, so it can quote hypothetical amounts". So the second premise has never held for `quotePool`. `pool()` still meets both premises: `sync()` reverts above `uint112` (`UniswapV2: OVERFLOW`), and `:459` caps `sUSDSIn` at the contract balance.

**Impact:** None. The comment is wrong, but the arithmetic is checked, so the note's conclusion ("an out-of-range input reverts rather than wrapping") still holds. Overflow needs `r` above about 1.7e35 wei (1.7e17 sUSDS), which is far beyond sUSDS supply and about 30x the `uint112` cap. The only possible effect is that a view call reverts on an absurd hypothetical input.

**Recommendation:** State the bound separately for each call site:

```solidity
///      **Overflow bound.** pool(): r is a uint112 reserve read after sync() and a <= this
///      contract's sUSDS balance, so the product stays below ~2.2e74. quotePool(): r is a uint256
///      balanceOf(pair) and a is caller-supplied and unbounded, so an absurd input reverts (checked
///      arithmetic). That is acceptable for a view.
```

*Severity: QA / NC (comment accuracy). Ledger `7b76f3476e…`, `open`. Sources: profile LOCAL-Q-01, CODE-21-001 (DEDUP-21-01).*

---

### [Q-23] The Uniswap V2 fee switch is live on the mainnet factory. `quotePool`'s NatSpec treats fee-on as hypothetical, and code-scan MR-004 cleared the `sync()`/`feeTo` interaction on the false premise "feeTo is off" <!-- id: ycn21q23 -->

**Location:** [`src/dispatchers/UniPoolerV2.sol#L492-L518`](https://github.com/Behodler/yield-claim-nft/blob/267660b96b92160a21919b043e571f2dbe51d216/src/dispatchers/UniPoolerV2.sol#L492-L518) (`quotePool` NatSpec and `expectedLP` computation)

**Description:** The `quotePool` NatSpec reads:

```solidity
///      hypothetical amounts. `expectedLP` assumes the factory protocol fee is off; when it is
///      on, the pair mints the fee share before ours, which only raises our LP, so the quote
///      remains a valid floor.
...
        uint256 ts = IUniswapV2Pair(_pair).totalSupply();
        expectedLP = Math.min((amtS * ts) / rS2, (amtP * ts) / rP2);
```

The fee is **on**. `cast call 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f "feeTo()"` returns `0xf38521f130fcCF29dB1961597bc5d2B60F995f85` (switched on by UNIfication, Dec 2025; `BalancerWinddownPlan.md:174` already records it). This has two consequences:

1. At the zap's `addLiquidity`, `_mintFee` mints `feeTo` about 1/6 of the `sqrt(k)` growth since `kLast`. That growth includes swap fees and any donation folded in by `sync()`, because `sync()` updates reserves without touching `kLast`.
2. `expectedLP` is computed from the pre-fee `totalSupply`, so the "fee on" branch of the NatSpec is the live case, not the hypothetical one.

The NatSpec's conditional reasoning is **correct**. `_mintFee` raises `_totalSupply` before our liquidity is computed, so minted LP ≥ quoted LP and `minLP` remains a valid floor in LP units. Fork tests on the real feeTo-on pair assert LP ≥ quote (7/7). What is wrong is the *pipeline premise*: code-scan MR-004 cleared the `sync()`/`feeTo` interaction because "feeTo is off on the mainnet V2 factory". Its conclusion survives; its reasoning does not.

**Impact:** None from `UniPoolerV2` code. The feeTo dilution is standard V2 pair economics, falls on every LP, and the pooler neither causes nor worsens it. The finding matters for downstream reasoning: any analysis of who benefits from a donation folded in by `sync()` (see F-02-051 in the spec-conformance report) must allow for `feeTo`'s ~1/6 cut of k-growth.

**Recommendation:** Rewrite the NatSpec to say that `feeTo` is live on the mainnet factory, and drop the "assumes the fee is off" framing. **Pipeline directive:** later runs and agents must carry "feeTo LIVE (governance-mutable)" as a premise and must not inherit "feeTo is off" from MR-004.

*Severity: QA / NC (premise correction). Ledger `ae13a21ad9…`, `open`. Sources: ECON-21-002, code-scan setAside MR-004, PATTERN-MR-002 (DEDUP-21-05).*
