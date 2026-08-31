# Static Analysis (Tier 1) — stable-staker run 16

**Target:** `lib/stable-staker` @ `fa06de57729a37914b1db0490ec7f3e18e220828`
**Executed from:** `/home/justin/code/audits/workspace/stable-staker` (verified `diff -r` byte-identical `src/` vs the read-only submodule; the submodule was not touched)
**Date:** 2026-08-31
**Raw artifacts:** `/home/justin/code/audits/reports/stable-staker/16/static/`

| Tool | Version | Exit | Files analysed | 7/7 in-scope covered |
|---|---|---|---|---|
| Slither | 0.11.3 | 255 (= findings present; `success: true` in JSON) | 33 contracts / 10 src files | **YES** |
| Aderyn | 0.6.8 | 0 | 10 compiled files | **YES** |
| Semgrep | 1.163.0 | 0 | 8 + 2 (two runs) | YES, but only after a workaround — see below |
| 4naly3er | HEAD (`tools/4naly3er`) | 0 | 7 (explicit scope file) | **YES** |

---

## 1. Tool invocations, exit codes, coverage

### Slither

```
cd /home/justin/code/audits/workspace/stable-staker
PATH="$HOME/.foundry/bin:$PATH" slither . \
  --json <reportDir>/static/slither-output.json \
  --filter-paths "stable-staker/lib/" \
  --exclude naming-convention,solc-version,pragma,assembly
```

Exit **255** — this is Slither's normal "detectors fired" exit, not an error; `.success == true` in the JSON and the run line reads `. analyzed (33 contracts with 96 detectors), 71 result(s) found`.

Hazard 1 avoided: the filter is anchored to `stable-staker/lib/`, **not** bare `lib/`. Sanity-checked with a second run (`--print contract-summary`, exit 0) that enumerates the contracts Slither actually built an IR for:

| In-scope file | Slither contract present | Results in JSON |
|---|---|---|
| `src/StableStakerV2.sol` | `StableStakerV2` | yes |
| `src/CrossVersionMigrator.sol` | `CrossVersionMigrator` | yes |
| `src/InPlaceMigrator.sol` | `InPlaceMigrator` | yes |
| `src/versions/v1/StableStakerV1.sol` | `StableStakerV1` | yes |
| `src/versions/v1/IStableStakerV1.sol` | `IStableStakerV1` | analysed, 0 results (pure interface) |
| `src/versions/v1/vendor/FlaxToken.sol` | `FlaxToken` | yes |
| `src/versions/v1/vendor/IFlax.sol` | `IFlax` | yes |

**7/7 analysed.** Nested `lib/` deps (OZ, forge-std, pauser, reflax-yield-vault, antimatter) were filtered out as intended — OZ internals (`Math`, `SafeERC20`, `EnumerableSet`, …) appear in the contract-summary because they are inherited into first-party contracts, but produced no first-party-attributed results.

Detector histogram (71 results): `unused-return` 17, `timestamp` 12, `reentrancy-no-eth` 9, `calls-loop` 9, `uninitialized-local` 8, `reentrancy-events` 4, `missing-zero-check` 4, `reentrancy-benign` 3, `low-level-calls` 3, `unimplemented-functions` 1, `missing-inheritance` 1.

### Aderyn

```
cd /home/justin/code/audits/workspace/stable-staker
PATH="$HOME/.foundry/bin:$PATH" aderyn . --src src \
  --output <reportDir>/static/aderyn-report.json
```

Exit **0**. Log: `Ingesting 10 compiled files [solc : v0.8.28]`, `Running 88 detectors`. Ten files is the entire `src/` tree (7 in-scope + the 3 excluded `src/interfaces/*`), so the whole tree was picked up, not just the root — hazard 5 cleared. All 7 in-scope paths appear as `contract_path` values in the JSON.

Result: **1 high**, **11 low** issue classes.

### Semgrep

```
cd /home/justin/code/audits/workspace/stable-staker
semgrep --config p/smart-contracts --json \
  --output <reportDir>/static/semgrep-output.json src/
```

Exit **0**, 146 findings over **8** files, `Files matching .semgrepignore patterns: 2`.

**Under-coverage, reported honestly:** the 2 skipped files were `src/versions/v1/vendor/FlaxToken.sol` and `src/versions/v1/vendor/IFlax.sol` — Semgrep's *built-in* default ignore list excludes any `vendor/` directory, so a default invocation silently drops those two in-scope files. `--no-git-ignore` does not lift it (it is not a git ignore). Worked around by copying the two files to a scratch dir with an empty `.semgrepignore`:

```
cp src/versions/v1/vendor/*.sol <scratch>/vendorscan/ && touch <scratch>/vendorscan/.semgrepignore
cd <scratch>/vendorscan && semgrep --config p/smart-contracts --json \
  --output <reportDir>/static/semgrep-vendor.json .
```
Exit **0**, 2 files, 7 findings. Combined: **7/7 covered**.

Per hazard 4, this is worth nothing analytically. Every one of the 153 combined hits is from `solidity.performance.*` or `solidity.best-practice.use-ownable2step` (custom-errors-not-require ×83, short-revert-string ×16, prefix-increment ×15, checked-arith-in-loop ×11, state-var-read-in-loop ×10, nested-if ×4, non-payable-constructor ×5, ownable2step ×5, array-length-outside-loop ×3, multiple-require ×1). **Zero** security rules fired because `p/smart-contracts` contains none for Solidity. Semgrep's silence is evidence of nothing and is not cited anywhere below.

### 4naly3er

```
cd /home/justin/code/audits/tools/4naly3er
npx ts-node src/index.ts /home/justin/code/audits/workspace/stable-staker/ <scratch>/4naly3er-scope-run16.txt
```

Exit **0**. Hazard 3 respected: arg 2 is `basePath` = the **submodule root** (so `remappings.txt` resolves relative to it), arg 3 is the **scope list** naming exactly the 7 in-scope files, relative to basePath. No symlink was used. Tool echoed the 7-entry scope back. Per-file mention counts in the generated report: V2 43, V1 44, InPlaceMigrator 27, CrossVersionMigrator 23, FlaxToken 22, IStableStakerV1 6, IFlax 5 — **7/7 covered**.

Output is 14 GAS + 22 NC + 15 L + 2 M issue classes, ~148 KB. Saved verbatim to **`/home/justin/code/audits/reports/stable-staker/16/static/4naly3er-report.md`** for `qa-bundler` to pick up. Its gas/NC sections are not reproduced here.

---

## 2. Normalized findings

Deduplicated across tools; style/gas/QA noise dropped. Normalized JSON for the deduplicator: `/home/justin/code/audits/reports/stable-staker/16/static/static-analysis-findings.json`.

Nothing below rises to High or Medium on its own. Three items are worth a human look; the rest are documented as false positives so the deduplicator does not re-raise them.

### S-01 — `setYieldStrategy` and `finalizeAndReset` are the only state-mutating entry points without `nonReentrant`
**Tools:** Slither `reentrancy-no-eth` (V2:249, V1:257), Aderyn "Reentrancy: State change after external call"
`src/StableStakerV2.sol:249` / `src/versions/v1/StableStakerV1.sol:257`
```solidity
function setYieldStrategy(address token, IYieldStrategy strategy) external onlyOwner poolExists(token) {
```
`src/StableStakerV2.sol:673`
```solidity
function finalizeAndReset(address token) external onlyOwner poolExists(token) {
```
Every other mutator (`stake`, `withdraw`, `claim`, `emergencyWithdraw`, `initiateMigration`, `userMigrate`, `depositFor`) carries `nonReentrant`. `setYieldStrategy` makes two external calls into the **old** strategy (`_routeExit` → `relinquishPrincipal`/`withdraw`, V2:279 / V1:287) and one into the **new** one (`strategy.deposit`, V2:296 / V1:304) before/around writing `yieldStrategy[token]` at V2:286.

**Assessment: real as an observation, not exploitable as written.** The `require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty")` gate at V2:258 / V1:266 makes the `staked > 0` branch at V2:279 unreachable, so the only live external call is the idle sweep, and the strategy is owner-wired (Law 3: trusted, obvious). `finalizeAndReset` makes no external call at all. File as a hardening note (consistency of the guard), not a vulnerability.

### S-02 — `_reinjectWithTopup`'s reverts sit inside the `migrateIn` batch loop
**Tools:** Aderyn "Loop Contains `require`/`revert`" (`InPlaceMigrator.sol:231`), Slither `calls-loop` (`InPlaceMigrator.sol:263`, 5 call sites)
`src/InPlaceMigrator.sol:281-284`
```solidity
            require(
                topup <= IERC20(token).balanceOf(address(this)) - totalParked[token],
                "InPlaceMigrator: top-up surplus exhausted"
            );
```
`src/InPlaceMigrator.sol:294`
```solidity
        require(finalCredited >= amt - amt / 1000, "InPlaceMigrator: par not restored");
```
Both fire per-user inside the `migrateIn` slice loop, so one user whose gross-up exceeds the remaining surplus reverts the entire batch, and the surplus is consumed in slice order (earlier users drain the budget the later ones need).

**Assessment: real availability observation, self-limiting.** `migrateIn(token, start, end)` is paginated so the owner can re-slice around a blocker, and any user can self-rescue via the permissionless `claimTimedOut` hatch once `migrationTimeout` elapses. Consequence is a stuck owner batch, not stuck user funds. Ordering-dependence of the shared surplus budget is the part worth handing to econ-scanner.

### S-03 — `CrossVersionMigrator.migrate` has no shortfall top-up, unlike `InPlaceMigrator`
**Tools:** Slither `calls-loop` (`src/CrossVersionMigrator.sol:161` → `newStaker.depositFor` at :178); surfaced by SAST, judged by hand
`src/CrossVersionMigrator.sol:173-181`
```solidity
        IERC20(token).forceApprove(address(newStaker), total);

        uint256 migratedCount;
        for (uint256 i = 0; i < users.length; i++) {
            if (amounts[i] > 0) {
                newStaker.depositFor(token, users[i], amounts[i]);
                migratedCount++;
            }
        }
```
`InPlaceMigrator._reinjectWithTopup` deliberately snapshots `userInfo` around `depositFor` and grosses up the shortfall (the ss12m1 / M-07 fix). `CrossVersionMigrator.migrate` calls the same `depositFor` with no such snapshot, so if the destination staker haircuts the credit the user is silently underpaid. It also lacks `nonReentrant`.

**Assessment: a lead, not a proven static finding.** Whether the destination `depositFor` can credit less than it pulls depends on the destination's yield-strategy wiring, which SAST cannot settle. Handing to code-scanner / econ-scanner as a divergence to adjudicate rather than filing it here.

---

## 3. Explicit false positives (do not re-raise)

| Item | Tools | Why it is a false positive |
|---|---|---|
| `reentrancy-no-eth` on `stake`, `depositFor`, `initiateMigration`, `migrateIn` (V1 + V2, 7 rows) | Slither, Aderyn high | All four carry `nonReentrant`; Slither does not model OZ `ReentrancyGuard`. Also matches the pre-cleared reentrancy rows — Antimatter is a plain OZ ERC20 with no transfer hooks. |
| Aderyn High "State change after external call" @ `StableStakerV2.sol:495,506,513,538`, `StableStakerV1.sol:486`, `InPlaceMigrator.sol:166,226,227` | Aderyn | Same rows as above, inside `nonReentrant` functions. Aderyn's only "high" for this repo; it is entirely this pattern. |
| `reentrancy-benign` ×3, `reentrancy-events` ×4 | Slither | Event-ordering / benign-write subsets of the same guarded functions. |
| `unused-return` on `EnumerableSet.add/remove` (12 rows: `StableStakerV2.sol:337,358,406,617,717`, `StableStakerV1.sol:343,363,403,575,674`, `InPlaceMigrator.sol:175,242,319) | Slither, Aderyn "Unchecked Return" | Idempotent set ops; the boolean carries no information the callers do not already establish. `claimTimedOut:319` is guarded by `require(amount > 0)` two lines up, which implies membership. |
| `unused-return` on `_routeExit` @ `StableStakerV2.sol:279,486` | Slither, Aderyn | Deliberate and documented in-source: "The return value is deliberately NOT used: R is measured from this contract's own balance below, so the set-aside buffer counts toward the migration payout." `:279` is additionally dead code under the `totalStaked == 0` gate. |
| `unused-return` on `(amountBefore,) = staker.userInfo(...)` @ `InPlaceMigrator.sol:268,270,288` | Slither | Tuple destructuring that intentionally takes only `amount`; `rewardDebt` is irrelevant to the top-up math. |
| `unused-return` on `strategy.deposit(...)` @ `StableStakerV1.sol:304` | Slither, Aderyn | V1 is the **frozen** copy (`src/versions/v1/FROZEN.sha256`); its preserved defects are deliberately not actioned. V2:296 already captures the value as `credited` and emits `ProtocolPrincipalSwept`. Note the divergence, do not file it. |
| `uninitialized-local` ×8 (`CrossVersionMigrator.sol:164,175`, `InPlaceMigrator.sol:168,169,214,230`, `StableStakerV2.sol:575`, `StableStakerV1.sol:537`) | Slither, Aderyn | All are `uint256 total;` / `uint256 count;` loop accumulators. Solidity zero-initializes; zero is the intended start. |
| `timestamp` ×12 | Slither | 9 of the 12 are not timestamp comparisons at all — the detector taints on `poolInfo[token].totalStaked == 0`, `R > P`, `reward > 0`, `balanceOf(this) >= amount`. Per this suite's policy these were *kept* through filtering and inspected rather than dropped; the 3 genuine ones (`_updatePool:814`, `_pendingReward:748`, `claimTimedOut:310`) are second-granularity MasterChef accrual and a multi-hour `migrationTimeout` — miner drift of a few seconds is immaterial to both. |
| `low-level-calls` ×3 (`CrossVersionMigrator.sol:201,217,234`) | Slither | `staticcall` probes for `STAKER_VERSION()` / `migrator()` / `getStakedTokens()`; a revert is a *meaningful* answer here (the live V1 predates `STAKER_VERSION`) and each site checks `ok`. No value transfer. Documented as advisory-only in-source. |
| `missing-inheritance`: `StableStakerV1` should inherit `IStableStakerMigratable` | Slither | Structural-typing informational on the frozen V1; the interface postdates the freeze. |
| `unimplemented-functions` on `IFlax` | Slither | `IFlax` is an interface. Noise. |
| `missing-zero-check` ×4 | Slither | Dropped per the standard filter list; also covered by 4naly3er NC-2 / L-3 for the QA bundle. |
| EIP-170 / contract oversize | 4naly3er / `forge build --sizes` | **Not filed.** Settled policy: this repo builds unoptimized and oversize on purpose; the deploy profile in phase-2-staging uses optimizer + via_ir. |

---

## 4. Bottom line

No High or Medium is supportable from deterministic SAST at `fa06de5`. Coverage was complete on all four tools (7/7 in-scope files each) after fixing Semgrep's `vendor/` blind spot, and no tool errored. Three items go forward as leads for the interaction-tier agents: **S-01** (guard-consistency hardening), **S-02** (batch-ordering surplus contention in `migrateIn`), **S-03** (missing shortfall top-up in `CrossVersionMigrator.migrate` relative to its in-place sibling).
