# Static Analysis — stable-staker run-15

- **Project**: stable-staker
- **Submodule HEAD**: `2146428bdd9adb1fbaf1c1feaa4fbf36133e5506`
- **Scan type**: deterministic SAST (Slither + Aderyn + Semgrep)
- **Scan date**: 2026-08-29
- **Analysed from**: `/home/justin/code/audits/workspace/stable-staker` (writable clone at the same commit; `lib/` untouched)
- **solc**: 0.8.28 (foundry.toml pin; source pragma `^0.8.20`)
- **Tool versions**: Slither 0.11.3, Aderyn 0.6.8, Semgrep 1.x (`p/smart-contracts`)

## Build precondition

24 audit-authored PoC files (`test/PoC_*.t.sol`, `test/invariant/`, `test/poc/`) were moved aside before
the run — they are bit-rotted against the old `src/StableStaker.sol` import path following the V1/V2 split
and are NOT repo breakage. With them aside, `forge build --force` returns **"Compiler run successful with
warnings"** (exit 0). They were restored after the scan. No file in `lib/stable-staker/` was modified.

---

## Coverage assertion (per tool)

In-scope set = 5 files. Coverage below is **files actually parsed/analysed**, not merely files that
produced findings.

| # | In-scope file | Slither | Aderyn | Semgrep |
|---|---|---|---|---|
| 1 | `src/StableStakerV2.sol` | ✅ analysed | ✅ 406 sloc | ✅ scanned |
| 2 | `src/versions/v1/StableStakerV1.sol` | ✅ analysed | ✅ 390 sloc | ✅ scanned |
| 3 | `src/CrossVersionMigrator.sol` | ✅ analysed | ✅ 72 sloc | ✅ scanned |
| 4 | `src/InPlaceMigrator.sol` | ✅ analysed | ✅ 160 sloc | ✅ scanned |
| 5 | `src/versions/v1/IStableStakerV1.sol` | ✅ analysed | ✅ 59 sloc | ✅ scanned |
| | **Coverage** | **5 / 5 PASS** | **5 / 5 PASS** | **5 / 5 PASS** |

**Evidence, not exit codes:**

- **Slither** — `--print contract-summary` enumerates 26 analysed contracts, which explicitly include
  `CrossVersionMigrator`, `InPlaceMigrator`, `StableStakerV2`, `IStableStakerV1`, and `StableStakerV1`
  (all 5 in-scope units, contract-by-contract). Run banner: `analyzed (26 contracts with 96 detectors),
  70 result(s) found`. Coverage is proved by the contract enumeration, not by findings-presence — file 5
  (`IStableStakerV1.sol`) produced no findings, which is expected for a pure interface, and its presence
  in the analysed-contract list is what makes that a real zero rather than a silent miss.
- **Aderyn** — `files_details` lists exactly 7 ingested source units (the 5 in-scope + the 2 out-of-scope
  `src/interfaces/` files), 1098 total sloc, `Ingesting 7 compiled files [solc : v0.8.28]`, 88 detectors run.
- **Semgrep** — `paths.scanned` lists the same 7 files; `Ran 50 rules on 7 files`.

### Slither `--filter-paths` trap — checked empirically, did NOT fire here

The prior-incident guidance was honoured: the authoritative run used the anchored filter
`--filter-paths "stable-staker/lib/,stable-staker/test/"`.

I then ran the naive `--filter-paths "lib/"` variant as a control. **Both produced identical output:
26 contracts, 70 results.** In Slither 0.11.3 on this Foundry project, `filter-paths` is matched against
the *relative* source path (`src/...`), not the absolute one, so `lib/` did not swallow the first-party
tree and no false-clean occurred. The trap is real in other configurations; it is recorded here as
**not reproduced at this tool version / project layout**, and the anchored form was used regardless.

Corollary worth noting: because matching is relative, the anchored pattern `stable-staker/lib/` also
matched nothing, so the project's nested `lib/` dependencies were *not* filtered out — yet zero findings
landed on any `lib/` path (all 70 results map to `src/`). Slither's Foundry integration skips `test/` from
the compilation unit on its own (no test or mock contract appears in the analysed list).

### Semgrep — coverage is real, security value is nil

Semgrep scanned all 5 in-scope files and returned 146 findings, but **every one of them comes from a
gas/style rule**. The 10 rules that fired were:

`use-ownable2step`, `array-length-outside-loop`, `non-payable-constructor`, `state-variable-read-in-a-loop`,
`unnecessary-checked-arithmetic-in-loop`, `use-custom-error-not-require`, `use-multiple-require`,
`use-nested-if`, `use-prefix-increment-not-postfix`, `use-short-revert-string`.

All 10 sit under `solidity.performance.*` or `solidity.best-practice.*`. **The `p/smart-contracts` pack
contains no Solidity security rules**, so a Semgrep result here — clean or otherwise — is not security
evidence and none of its 146 findings are carried forward. Its coverage row above attests that the files
were parsed, nothing more.

---

## Filtering summary

| Tool | Raw instances | Dropped (noise policy) | Carried forward |
|---|---|---|---|
| Slither | 70 | 7 | 63 |
| Aderyn | 81 | 26 | 55 |
| Semgrep | 146 | 146 | 0 |
| **Total** | **297** | **179** | **118** (→ 11 normalized classes) |

**Dropped** — `solc-version` / `pragma` (Aderyn *Unspecific Solidity Pragma* ×7, *PUSH0 Opcode* ×7),
`naming-convention`, `assembly`, `missing-zero-check` (Slither ×4, Aderyn *Address State Variable Set
Without Checks* ×4), *Literal Instead of Constant* ×2, *Modifier Invoked Only Once* ×2, *Costly operations
inside loop* ×4, `low-level-calls` ×3, and the whole Semgrep gas/style set ×146.

`low-level-calls` was dropped as **non-value-transfer only**: all three instances are
`staticcall` version-probes in `CrossVersionMigrator` (`_versionOf` :199, `_migratorOf` :215,
`_isRegisteredOn` :232) with no ETH or token movement.

**`timestamp` findings were deliberately RETAINED** (12 instances). This protocol is time-driven —
`_updatePool` accrual over `lastRewardTime`, `pendingReward`, and `InPlaceMigrator.claimTimedOut`'s
timeout hatch — so `block.timestamp` logic is load-bearing, not informational (Law 1: recall beats
tidiness). Dedup/severity-classifier decide their fate, not this stage.

---

## Normalized findings

Severity below is **tool-reported potential severity**, not C4 severity. Confidence reflects
cross-tool corroboration and manual sanity-checking of the guard context.

| ID | Class | Sev | Contract | Function | Line(s) | Tools | Conf |
|---|---|---|---|---|---|---|---|
| SA-01 | reentrancy-no-eth | potential-medium | StableStakerV2.sol | `stake` | 313 | slither | medium |
| SA-01 | reentrancy-no-eth | potential-medium | StableStakerV1.sol | `stake` | 327 | slither | medium |
| SA-02 | reentrancy-no-eth | potential-medium | StableStakerV2.sol | `depositFor` | 675 | slither | medium |
| SA-02 | reentrancy-no-eth | potential-medium | StableStakerV1.sol | `depositFor` | 654 | slither | medium |
| SA-03 | reentrancy-no-eth | potential-medium | StableStakerV2.sol | `setYieldStrategy` | 242 | slither+aderyn | medium |
| SA-03 | reentrancy-no-eth | potential-medium | StableStakerV1.sol | `setYieldStrategy` | 257 | slither+aderyn | medium |
| SA-04 | reentrancy-no-eth | potential-medium | StableStakerV2.sol | `initiateMigration` | 449 (478/489/496/521) | slither+aderyn | medium |
| SA-04 | reentrancy-no-eth | potential-medium | StableStakerV1.sol | `initiateMigration` | 463 (486) | slither+aderyn | medium |
| SA-05 | reentrancy-no-eth | potential-medium | InPlaceMigrator.sol | `migrateIn` | 203 (226/227) | slither+aderyn | medium |
| SA-06 | reentrancy-benign | potential-low | InPlaceMigrator.sol | `migrateOut` | 165 (166) | slither+aderyn | low |
| SA-07 | reentrancy-events | potential-low | CrossVersionMigrator.sol | `migrate` | 159 | slither | low |
| SA-08 | unused-return | potential-medium | StableStakerV2.sol | `stake` / `withdraw` / `emergencyWithdraw` / `depositFor` / `_exitPosition` | 313, 334, 379, 675, 578 | slither+aderyn | medium |
| SA-08 | unused-return | potential-medium | StableStakerV1.sol | `stake` / `withdraw` / `emergencyWithdraw` / `depositFor` / `_exitPosition` / `setYieldStrategy` | 327, 348, 393, 654, 557, 257 | slither+aderyn | medium |
| SA-08 | unused-return | potential-medium | InPlaceMigrator.sol | `migrateOut` / `migrateIn` / `_reinjectWithTopup` / `claimTimedOut` | 165, 203, 263, 307 | slither+aderyn | medium |
| SA-09 | uninitialized-local | potential-medium | InPlaceMigrator.sol | `migrateOut` (`total`,`count`), `migrateIn` (`total`,`count`) | 168, 169, 214, 230 | slither+aderyn | low |
| SA-09 | uninitialized-local | potential-medium | CrossVersionMigrator.sol | `migrate` (`total`, `migratedCount`) | 162, 173 | slither+aderyn | low |
| SA-09 | uninitialized-local | potential-medium | StableStakerV2.sol / StableStakerV1.sol | `_exitPosition` (`total`) | 558 / 537 | slither | low |
| SA-10 | calls-loop (DoS-by-batch) | potential-low | InPlaceMigrator.sol | `_reinjectWithTopup` | 263 (×6) | slither+aderyn | medium |
| SA-10 | calls-loop (DoS-by-batch) | potential-low | CrossVersionMigrator.sol | `migrate` | 159 | slither | medium |
| SA-10 | calls-loop (DoS-by-batch) | potential-low | StableStakerV2.sol / StableStakerV1.sol | `_exitPosition` | 578 / 557 | slither | medium |
| SA-11 | timestamp-dependence | potential-low | StableStakerV2.sol | `_updatePool`, `pendingReward`, `initiateMigration`, `finalizeAndReset`, `setYieldStrategy`, `_routeExit` | 766, 705, 449, 652, 242, 834 | slither | medium |
| SA-11 | timestamp-dependence | potential-low | StableStakerV1.sol | `_updatePool`, `pendingReward`, `finalizeAndReset`, `setYieldStrategy`, `_routeExit` | 744, 683, 631, 257, 812 | slither | medium |
| SA-11 | timestamp-dependence | potential-low | InPlaceMigrator.sol | `claimTimedOut` | 307 | slither | medium |
| SA-12 | modifier-order (`nonReentrant` not first) | potential-low | InPlaceMigrator.sol | `migrateOut`, `migrateIn` | 165, 203 | aderyn | low |
| SA-13 | missing-inheritance | potential-low | StableStakerV1.sol | contract-level | 79 | slither | high |
| SA-14 | centralization (aggregate) | potential-low | all 4 contracts | 24 owner-gated entry points | — | aderyn | low |

### Notes carried to dedup / severity-classifier

- **SA-01…SA-06 (reentrancy):** every flagged entry point carries `nonReentrant`, and the migrator paths
  additionally carry `onlyOwner` / `onlyMigrator`. `InPlaceMigrator.migrateIn` zeroes `parked`,
  `migrationBegin`, `totalParked` and removes the set member **before** `_reinjectWithTopup`'s
  `depositFor` — textbook CEI, documented in-source. `StableStakerV2.initiateMigration` writes
  `yieldStrategy`, `poolState` and `migrationInfo` after `_routeExit`/`relinquishPrincipal` under
  `nonReentrant onlyMigrator`. These read as **tool artifacts from cross-function state-write ordering**,
  not exploitable paths — but they are cross-tool corroborated and the strategy callee is an external
  contract, so they are carried forward rather than dropped at this stage.
- **SA-08 (`unused-return`) is almost entirely `EnumerableSet.add`/`remove` return values**, deliberately
  ignored. Both tools flag it; low real signal. The one worth a human glance is
  `initiateMigration`'s deliberate discard of `_routeExit`'s return (documented in-source: `R` is
  re-measured from the contract's own balance so the set-aside buffer counts toward payout).
- **SA-09 (`uninitialized-local`)** are `uint256 total; uint256 count;` loop accumulators relying on the
  zero default. Benign as written; retained only because uninitialized-local is a keep-class detector.
- **SA-10 (`calls-loop`)** is the batch-migration shape: an external strategy/staker call inside a
  per-user loop. Not a bug per se, but it is the mechanical basis of the batch-slice DoS/gas-bound
  questions this project has hit before, so it is worth pairing with the manual migration review.
- **SA-11 (`timestamp`)** retained by explicit policy; several instances are actually
  `require(totalStaked == 0)` strict-equality checks that Slither files under the timestamp detector
  (`setYieldStrategy` :266, `finalizeAndReset` :634) — those are the empty-pool gate, not time logic.
- **SA-13:** `StableStakerV1` implements the `IStableStakerMigratable` surface without declaring the
  inheritance. Frozen-V1 contract, so this is an observation about the declared interface surface rather
  than a defect to fix in place.
- **SA-14:** centralization instances are listed for completeness only. Under Law 3 the owner is trusted
  for knowing actions; only a *non-obvious* footgun among these would be reportable, and that judgement
  belongs to the manual reviewer, not to a detector count.

## Artifacts

- `/home/justin/code/audits/reports/stable-staker-15/slither-output.json`
- `/home/justin/code/audits/reports/stable-staker-15/slither-stdout.txt`
- `/home/justin/code/audits/reports/stable-staker-15/aderyn-report.json`
- `/home/justin/code/audits/reports/stable-staker-15/aderyn-stdout.txt`
- `/home/justin/code/audits/reports/stable-staker-15/semgrep-output.json`
- `/home/justin/code/audits/reports/stable-staker-15/semgrep-stdout.txt`

No tools were missing; all three ran to completion.
