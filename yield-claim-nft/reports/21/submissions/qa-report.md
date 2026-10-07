# QA Report for yield-claim-nft (run 21)

| | |
|---|---|
| **Project** | yield-claim-nft |
| **Run** | yield-claim-nft-21 |
| **Mode** | REGRESSION `2bfa090` → `267660b` (`master`) |
| **Audited commit** | [`267660b96b92160a21919b043e571f2dbe51d216`](https://github.com/Behodler/yield-claim-nft/tree/267660b96b92160a21919b043e571f2dbe51d216) |
| **Change under review** | story-051: `UniPoolerV2` hook guard, `sync()` before sizing, balance-based `quotePool`, canonical-pair constructor check (+ new `IUniswapV2Factory` interface) |
| **Automated baseline** | [`4naly3er-report.md`](./4naly3er-report.md) (Appendix A) |

This bundle holds every Low, Centralization and QA item of run 21. High/Medium findings: **none this run**. Law-2 deviations (F-01-051, F-02-051, F-03-051) are in [`spec-conformance.md`](./spec-conformance.md), not here. Open findings from earlier runs are **not** restated here; they are carried in full, one file per originating run, under [`carryover/`](./carryover/) (index in § Carryover).

## Summary

| Severity | New this run |
|----------|-------|
| Low Risk | 0 |
| Centralization | 0 |
| QA / Non-Critical | 2 (Q-22, Q-23) |
| **Total new** | **2** |

| Other sections | Count |
|---|---|
| Run-20 `fix-pending` items verified this run | 4: **3 FIX-COMPLETE** (L-21, L-25, Q-19, proposed `fixed`), **1 NOT-ADDRESSED** (Q-21) |
| Carried-over open entries (`carryover/`) | 40 (33 QA-channel in 9 `qa-report-NN.md`, 7 faithfulness in 4 `spec-conformance-NN.md`) |
| Static tool-noise items (Appendix B, not findings) | 19 |

**Why there are no new Lows.** The story-051 change set is small and every piece of it held under Tier-3 (4 invariants PASS on the real contract under both forge and Medusa; each invariant is falsified by a targeted mutant in the forge campaign and a deterministic replay, and M1 was additionally falsified under Medusa). The two new items are both comment/premise corrections. Both are kept rather than dropped because each corrects a premise that later reasoning depends on (Law 1, recall before tidiness).

**Labels** continue the ledger sequence (last `Q-21` → `Q-22`, `Q-23`). The next free labels are `L-26`, `Q-24`, `C-02`.

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

---

## Fix Verification: run-20 `fix-pending` items

Run 20 left four entries `fix-pending`. Each was re-checked against `267660b`. **No status has been changed.** `fix-pending` is human-set and is never closed automatically. The commands below are proposals for a human to apply, **selected by fingerprint**.

| Ledger | ID | Fingerprint | Verdict | Proposed | Human command |
|---|---|---|---|---|---|
| L-21 | `ycn20l21` | `6867d791f3…` | **FIX-COMPLETE** | `fixed` @ `267660b` | `/ledger yield-claim-nft fixed 6867d791` |
| L-25 | `ycn20l25` | `8ec2be7d59…` | **FIX-COMPLETE** | `fixed` @ `267660b` | `/ledger yield-claim-nft fixed 8ec2be7d` |
| Q-19 | `ycn20q19` | `098396142d…` | **FIX-COMPLETE** | `fixed` @ `267660b` | `/ledger yield-claim-nft fixed 09839614` |
| Q-21 | `ycn20q21` | `4c2f9c705c…` | **NOT-ADDRESSED** | stays `fix-pending` | none (still live, carried over) |

> ⚠ **Label hazard: select L-25 by fingerprint, never by `ycn20l24`.** Story-051 (twice), the body of commit `267660b` ("`- ycn20l24: pool() syncs the pair before reading reserves`") and the tests (`UniPoolerV2.t.sol:1604`, `UniPoolerV2.fork.t.sol:126`) all credit the sync fix to **`ycn20l24`**. That ID belongs to **L-24** `8511fd5206` (dust pre-seed, `wont-fix`), which this commit does **not** touch and whose status must not change. The sync fix closes **L-25** `8ec2be7d59`. The canonical-pair check closes **Q-19** `098396142d`, which neither the story nor the commit names. Filed as F-01-051 in the spec-conformance report.

**Evidence base** (all under `reports/21/`): `code-scan-findings.json` (fixVerification), `tier3-artifacts/invariants-summary.json` (INV1–INV4 + INV1b on forge 1,000,000 calls and Medusa 674,388 calls, 0 failures on the real contract; mutants M1–M4 each falsify their target invariant in the forge campaign and in the deterministic replay `Run21Replay.t.sol`, and only M1 (NoSync) was also run under Medusa, where it failed INV1/INV1b/INV2; so none of the passes is vacuous), `tier3-artifacts/symbolic-summary.json` (Halmos P1a–P1d, P2a, P2c, P3a, P3b, P4 PASS; **P2b UNVERIFIED**: the depth-2 run was killed by wall-clock at 7m29s, which is not a proof and is not cited as one), and the story-faithfulness re-runs in `work/` (verified byte-identical to `267660b`): **115/115 unit** (up from 99, none deleted) and **7/7 fork** against the real feeTo-on pair.

### L-21: fail-open hook wiring on `UniPoolerV2._dispatch`. FIX-COMPLETE

The guard now opens `_dispatch` ([`#L356`](https://github.com/Behodler/yield-claim-nft/blob/267660b96b92160a21919b043e571f2dbe51d216/src/dispatchers/UniPoolerV2.sol#L356)). `_defaultHook` is captured from the base constructor's hook at `:230`:

```solidity
if (address(hook) == _defaultHook) revert UniPoolerV2__HookNotSet();
```

- **INV3_L21_hookGuard** PASS on both engines. Mutant **M3** (guard deleted) fails it in the forge campaign ("index-4 mint SUCCEEDED while hook == constructor default"), and was not run under Medusa. The deterministic replay shows the same sequence reverting `HookNotSet` on the real contract.
- **Halmos:** P1a (default hook ⇒ exact `HookNotSet` selector), P1b (any other hook ⇒ never `HookNotSet`), P1c (completeness: a working hook succeeds), P1d (re-arm), P2a, P2c (depth-1 arbitrary call cannot re-key the guard) all PASS. P2b (depth 2) is UNVERIFIED. Concern is low because `_defaultHook` is `immutable`.
- Unit test `test_hookGuard_nftMinterMint_revertsUntilHookSet`.
- **Residuals (manual review, not findings):** MR21-01. A *freshly deployed* `DefaultDispatchHook` passes the guard. Story-051 documents this as a deliberate opt-out, and it needs a knowing owner action (Law 3); the human should confirm footgun status. MR21-02. The cutover ordering window still fails loud (owner sequencing, for the phStaging2 `/audit-script` to cover).
- This fix is specific to `UniPoolerV2`. It does **not** close the same class on Uniboost / PromotionUniV2_Eth (**L-09**, open, see `carryover/qa-report-13.md`).

### L-25: unsynced reserve sizing in `pool`/`quotePool`. FIX-COMPLETE

`pool()` now syncs immediately before reading reserves ([`#L461-L463`](https://github.com/Behodler/yield-claim-nft/blob/267660b96b92160a21919b043e571f2dbe51d216/src/dispatchers/UniPoolerV2.sol#L461-L463)), and `quotePool` sizes from the pair's token balances, which are the reserves `sync()` will set:

```solidity
// Fold any unsynced donation into the reserves before sizing (see contract dev notes).
IUniswapV2Pair(_pair).sync();
(uint256 rS,) = _reserves();
```

- **INV1_L25_noStrand**, **INV1b** and **INV2_quoteExecuteConsistent** PASS on both engines under adversarial donate/skim/swap/sync interleavings. The worst residual observed is 94 wei sUSDS at a 10:1 skew, 0 phUSD.
- Mutant **M1** (no `sync()`) fails INV1/INV1b/INV2 under both forge and Medusa; its replay strands 2.4857 sUSDS. Mutant **M2** (quote reads stale reserves) fails INV2 in the forge campaign and its replay; it was not run under Medusa.
- The 7/7 fork tests were confirmed to actually fork (`RPC_MAINNET` exported, 0.4M–4.3M gas per test), not just pass: `onlyForked` reports PASS when a test is skipped, so a pass alone would not prove the fork ran (VC-21-02).
- The faithfulness mutation (sync removed, quote reverted) reproduces the run-20 strand (103 phUSD / 411 sUSDS left over, `InsufficientLP`). Halmos **P4** PASS: every `pool()` gate precedes `sync()` (IFF form).
- **Run-20 PoC replay is INCONCLUSIVE (bit-rot).** `work/test/run20/DonationStrand.t.sol` no longer compiles: its `DeadRouter` lacks `factory()`, which the new canonical-pair constructor check calls (MR21-06). The verdict does not rely on that PoC. Refresh it before any `/recheck 8ec2be7d`.
- The NatSpec half of the owner's fix plan was carried out. The replacement "The zap" text adds a new inaccuracy about the donation mechanism and who benefits, filed separately as **F-02-051**. That is documentation only and does not make the code fix incomplete.

### Q-19: pair not bound to the router's factory. FIX-COMPLETE

The constructor now enforces the owner-confirmed fix plan, after the token-set check ([`#L220-L221`](https://github.com/Behodler/yield-claim-nft/blob/267660b96b92160a21919b043e571f2dbe51d216/src/dispatchers/UniPoolerV2.sol#L220-L221)):

```solidity
address canonical = IUniswapV2Factory(IUniswapV2Router02(router_).factory()).getPair(sUSDS_, phUSD_);
if (canonical != pair_) revert UniPoolerV2__PairNotCanonical(canonical, pair_);
```

- Halmos **P3a**: the constructor succeeds **iff** `getPair == pair_`, and otherwise reverts with exactly `PairNotCanonical(canonical, pair_)`. A missing pair (`0`) and a lookalike pair both revert. **P3b**: a token mismatch reverts first, whatever the factory returns.
- Residual MR21-03: the trust root is the caller-supplied `router_`, a trusted deploy input (Law 3).
- **Scope:** this closes Q-19 only. Q-19 and **L-24** share a title inherited from the run-20 group DEDUP-20-04. L-24 (third-party dust pre-seed) is untouched and stays `wont-fix`. Do not grade Q-19 incomplete because of L-24's residual, and do not close or reopen L-24 on the strength of this fix.

### Q-21: plan §5 zap sizing overstates seeded depth. NOT-ADDRESSED (still `fix-pending`)

The fix owed is a correction to BalancerWinddownPlan §5, deferred to phStaging2:108 and not landed at pin `a309040`. `267660b` did edit `pool()`, but that edit was the L-25 sync fix, not an attempt to fix Q-21, so this is **not** an incomplete fix. Re-quantified this run: phUSD still crosses $1 at about a **$636** zap, exactly as in run 20. The sync fix does not move that threshold, but it makes the threshold computable from `quotePool` (sensitivity to a donation: $423–$855). Keepers should keep chunking `pool()` so that post-zap spot ≤ $1. The entry is carried in full in `carryover/qa-report-20.md`.

---

## Carryover

Run 20 never wrote its `qa-report.md`. Its four `fix-pending` entries are rebuilt in full from `reports/20/findings/{low,qa}/*.json`. Every other open, `fix-pending` or `qa-bundled` entry is copied in full, pruned to its live entries, into one file per originating run. Disposed entries are named in each file's header. The labels are the originals, and this run's L/Q sequence does not renumber around them. The list is taken from `ledger-reconciliation.json`: **40 entries**, all present.

| File | Entries carried (ledger labels) | Disposed and removed |
|---|---|---|
| [`carryover/qa-report-08.md`](./carryover/qa-report-08.md) | L-01, L-02, Q-02, Q-03, Q-04, Q-09 (from report Q-01), **C-01** | L-03 (fixed); Q-01 NFTMigrator facet (fixed) |
| [`carryover/qa-report-10.md`](./carryover/qa-report-10.md) | L-04, L-05, L-07, Q-05 | L-06 (wont-fix) |
| [`carryover/qa-report-13.md`](./carryover/qa-report-13.md) | L-09, L-10, Q-10 | L-06 instance note (wont-fix) |
| [`carryover/qa-report-14.md`](./carryover/qa-report-14.md) | L-11 | none |
| [`carryover/qa-report-15.md`](./carryover/qa-report-15.md) | L-12, Q-11 | none |
| [`carryover/qa-report-17.md`](./carryover/qa-report-17.md) | Q-13, Q-14, Q-15 | L-13, Q-12, L-06 instance (wont-fix) |
| [`carryover/qa-report-18.md`](./carryover/qa-report-18.md) | Q-16, Q-17 | L-15, L-06, Q-12, L-13, F-01-044 (wont-fix) |
| [`carryover/qa-report-19.md`](./carryover/qa-report-19.md) | Q-18, L-16, L-17, L-18, L-19, L-20, M-06 (Low) | none (withdrawn Q-02/Q-03 never ledgered) |
| [`carryover/qa-report-20.md`](./carryover/qa-report-20.md) | L-21, L-25, Q-19 (proposed fixed), Q-21 (fix-pending) | L-22, L-23, L-24, Q-20 (wont-fix) |
| [`carryover/spec-conformance-15.md`](./carryover/spec-conformance-15.md) | F-01-043 | none |
| [`carryover/spec-conformance-18.md`](./carryover/spec-conformance-18.md) | F-01-045 | F-01-044 (wont-fix) |
| [`carryover/spec-conformance-19.md`](./carryover/spec-conformance-19.md) | F-01-047, F-02-046, F-03-046 | none |
| [`carryover/spec-conformance-20.md`](./carryover/spec-conformance-20.md) | F-01-048 (proposed fixed, doc half), F-02-048 | none |

The only open **Centralization** item is **C-01** (`d1c5aa860f`, run 08), which is carried. No new centralization item was raised this run: the story-051 owner levers (`setHook`, the deploy-time `router_`/`pair_`) are knowing owner actions under Law 3, and their non-obvious edges are parked as MR21-01/MR21-03.

Run-21 locations that are still live on `UniPoolerV2` for older entries (none was re-raised this run, and the absence of a re-raise is not a fix):

- **L-05:** `setBatchDonationSize :288`, `_dispatch :348-380`.
- **L-17:** sweep-and-retry still inside `if (donationEnabled)` at `:371-379`.
- **L-18:** the `gemAmt == 0` branch is still silent at `:416`. F-01-048's doc fix does not close it.
- **Q-18:** unpaired `forceApprove(streamer, gemAmt)` at `:434`.
- **Q-02:** `deposit` return ignored at `:366`.
- **Q-05:** `nonReentrant` is not the first modifier on `pool:450-454`.

---

## Parked, not dropped

These items are in `manual-review.json` and await a human decision; none of them was quality-filtered out.

- **MR21-01:** fresh-`DefaultDispatchHook` guard bypass.
- **MR21-02:** cutover ordering window.
- **MR21-03:** `router_` trust root.
- **MR21-04:** Halmos P2b unverified.
- **MR21-06:** L-25 PoC bit-rot.
- **MR21-07 / MR21-08:** recall flags against the `wont-fix` L-22/L-23 (deliberate quote poisoning; the owner may extend the `triageReason`) and L-24.

---

## Appendix A: Automated QA/Gas Report (4naly3er)

Full output: **[`4naly3er-report.md`](./4naly3er-report.md)** (6,280 lines).

- **Analysed: 36/36 in-scope files.** Every first-party `src/**/*.sol` (nested `src/lib/**` excluded) appears in the tool's scope echo, with 0 import-resolution failures. 35 files carry hits; the 36th, `src/interfaces/IBurnable.sol`, is a one-function interface with nothing to flag.
- **Invocation:** arg 3 = the 36-file scope list. basePath was first set to the submodule root `yield-claim-nft/src/`. That failed with `pauser/interfaces/IPausable.sol import not found`, because the submodule declares remappings only in `foundry.toml`, has no `remappings.txt`, and is read-only. The run was repeated with basePath = `yield-claim-nft/work/`, whose `src/` was verified **byte-identical** to `267660b` (`diff -rq` empty) and which carries an equivalent `remappings.txt`. Source was not modified.
- **Totals:** Medium 1 issue / 82 instances, Low 14 / 99, NC 32 / 593, Gas 20 / 639.
  - **M-1 "Centralization Risk for trusted owners" (82)** is suppressed as a class under Law 3. The only open centralization item is C-01.
  - The Low categories overlap items already ledgered or dispositioned: missing `address(0)` checks (Q-09), single-step Ownable (Q-04), zero-value transfers and `decimals()` (out of scope as non-standard-token issues), and "Prevent accidentally burning tokens" / `PUSH0` (informational). None of them is promoted to a finding without a demonstrated root cause.

## Appendix B: Static tool-noise bucket (summary only, not findings)

`deduplicated-findings.json → toolNoiseForQA` lists 19 SAST hits that were bucketed for QA visibility rather than dropped. Each one was reviewed and none is a finding:

| Class | Items | Disposition |
|---|---|---|
| `incorrect-equality` | **SLITHER-007** (`UniPoolerV2._balances:531`, **new**: the `bS == 0 \|\| bP == 0` EmptyPair zero-guard in a view), **SLITHER-008** (`_swapAmount:541`, **new** detector hit on unchanged code, surfaced by taint from the new `_balances()`; it is the `s == 0` revert), SLITHER-016 (`BalancerPoolerV2.getIdealBPT`) | Zero-guards, not dependencies on balance equality. A donation can only make the balances non-zero, and `pool()` sizes from the synced `_reserves()`. |
| `unused-return` | SLITHER-003/013 (`buyGem`, both poolers), SLITHER-004 (`UniPoolerV2.pool` addLiquidity amounts; the residual it hid was L-25, now FIX-COMPLETE), SLITHER-014/015 (Balancer `unlock`/`settle`), SLITHER-019 (Uniboost router) | Bounded by floors or exact approvals. Ledgered cousins: Q-02, Q-13, Q-14. |
| `calls-loop` | SLITHER-020 (`MultiPooler.pool`) | Bounded keeper batch; staleness is L-11. |
| `reentrancy-events` | SLITHER-009/027/028/021/023/024/025 | Event emitted after an external call, on self-gated or `nonReentrant` paths. The code-scan reentrancy checklist is clear. |
| `low-level-calls` | SLITHER-030 (`PromotionUniV2_Eth.rescueETH`) | Owner rescue with the return value checked (Law 3). |
| `timestamp` | **SLITHER-031** (`Uniboost.pool:266`, `deadline = block.timestamp`) | Same class as Q-12/Q-20 (`wont-fix`). Kept visible under the suite's timestamp policy, not re-filed. |

Separately, four ledger-covered static groups were suppressed this run against `wont-fix` entries (L-22/L-23, L-24, Q-20, Q-12). They are recorded in `ledger-reconciliation.json`, and MR21-07/08 keep the recall flags visible.
