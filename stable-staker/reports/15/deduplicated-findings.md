# Deduplicated Findings — stable-staker run-15

- **Project:** stable-staker · **HEAD:** `2146428` · **Baseline:** `8856781` (run-14) · **Mode:** REGRESSION
- **Stage:** deduplicator (Tier-4 filtering, before sanitizer)
- **Inputs:** `code-findings.md`, `econ-findings.md`, `faithfulness-findings.md`, `pattern-findings.md`, `static-analysis.md`
- **Ledger consulted:** `reports/stable-staker/ledger.json` (46 entries) + start-of-run snapshot `…/scratchpad/ledger-snapshot-start.json`
- **Parked channel:** `reports/stable-staker/15/manual-review.json` (4 entries) — nothing was silently dropped.

Input findings: 4 code + 5 econ + 4 faithfulness (+4 notes) + 4 pattern manual-review + 14 SAST classes = **35 raw items**.
Output: **9 consolidated findings** (2 Medium, 5 Low, 2 QA), of which **2 carry no new fingerprint** (in-place re-weighs of existing ledger entries), plus 6 reconciliation-only rows, 4 parked, and 13 SAST classes dropped with reasons.

---

## 1. Consolidated finding list

| ID | Contract : function | Root-cause class | Sev | Novelty | Provenance |
|---|---|---|---|---|---|
| **DEDUP-15-01** | `StableStakerV2 :: initiateMigration` (466–527) | value-routing — write-down where a *realization* was required | **Medium** | NEW | code-scanner (PoC) |
| **DEDUP-15-02** | `StableStakerV2 :: _routeExit` ↔ `initiateMigration` | allocation-rule arbitrage (par/FCFS while `Active` vs pro-rata while `Migrating`) | **Medium** | **re-raise of `69c7666e` (wont-fix)** | econ-scanner |
| **DEDUP-15-03** | `CrossVersionMigrator :: initiateMigration`, `_migratorOf`, `_isRegisteredOn`, constructor | fail-open existence validation | Low | **incomplete-fix-of `7cdb92fd`** | code-scanner (PoC) + pattern-matcher |
| **DEDUP-15-04** | `CrossVersionMigrator :: initiateMigration` (§C NatSpec) | unasserted destination preconditions + falsely-exhaustive in-source claim | Low | **re-weigh of `7cdb92fd` — NO new fingerprint** | story-faithfulness + code-scanner + pattern-matcher |
| **DEDUP-15-05** | `StableStakerV2 :: initiateMigration` (469, 496–527) | no floor on the irreversible step + discarded discriminator | Low | NEW | code-scanner + econ-scanner + static-analyzer |
| **DEDUP-15-06** | `StableStakerV2 :: rescueERC20` (868–875) | owner footgun — non-obvious consequence (Law 3) | Low | **impact re-weigh of `0790a76a` — NO new fingerprint** | econ-scanner |
| **DEDUP-15-07** | `StableStakerV2:521` ↔ `AYieldStrategy:63` (`setAsideBufferRecipient`) | cross-contract trust assumption / unasserted off-chain config | Low | NEW | econ-scanner |
| **DEDUP-15-08** | `.github/scripts/check-migration-surface.sh` (100–113, 118–145) | CI gate under-enforces its own stated guarantee (2 instances) | QA | NEW (leg 1 overlaps `c8218865da`) | story-faithfulness |
| **DEDUP-15-09** | `StableStakerV2 :: initiateMigration` / `setYieldStrategy` | compensating control is nominal, not real (2 instances) | QA | NEW | story-faithfulness |

---

## 2. Entries

### DEDUP-15-01 — the self-heal *relinquishes* the swept buffer instead of *withdrawing* it, defeating the same story's own D4
- **originalIds:** `CODE-001`
- **contract:function:** `src/StableStakerV2.sol :: initiateMigration`
- **root cause class:** intra-story self-inconsistency / value-routing
- **severity:** Medium (**severity contested** — code-scanner itself argues Low is defensible under the standing "protocol-owned surplus is not loss" carve-out; flagged for severity-classifier, §5)
- **novelty:** NEW — both halves land in `69c6fef`; no ledger fingerprint matches `StableStakerV2:initiateMigration` on this root-cause class
- **provenance:** code-scanner only; PoC `test_selfHeal_destroys_the_buffer_D4_was_meant_to_spend` (PASS)
- **kept whole because:** D3 (`relinquishPrincipal(booked)`) writes principal down without moving shares, so the capital never reaches the balance D4 (`R = balanceOf`) is about to measure. Mitigation is a code change *inside* `initiateMigration` (withdraw before relinquish). This is the only entry this run with a code-level fix at that site.

**Overlap 1 resolved — DISTINCT from DEDUP-15-06 / DEDUP-15-07 (do not merge).** All three end at the same *consequence* ("the migration cushion `R` is smaller than story-020 promised"), but they are three different root causes, at three different sites, with three non-overlapping mitigations:

| | DEDUP-15-01 | DEDUP-15-06 | DEDUP-15-07 |
|---|---|---|---|
| site | `initiateMigration` D3 | `rescueERC20` | `AYieldStrategy.setAsideBufferRecipient` |
| actor | none (automatic, in-transaction) | owner, discretionary, days earlier | off-chain config, set once |
| mechanism | buffer already in the strategy is written off instead of realized | buffer on the contract is swept away | buffer never arrives on the contract |
| fix | Solidity change in `initiateMigration` | NatSpec + runbook (already-ledgered fingerprint) | cross-repo config assertion / new view |

Merging them would collapse one fixable code defect into two operational notes and lose the code fix, and would fold a **new** fingerprint into an **existing** one (`0790a76a`), suppressing the new defect behind an already-open Low. They are cross-linked as a "cushion-erosion" family instead.

---

### DEDUP-15-02 — story-020 turns the FCFS par-exit buffer into a front-run on the migration cushion
- **originalIds:** `ECON-15-01`
- **contract:function:** `src/StableStakerV2.sol :: _routeExit` (834–856) interacting with `initiateMigration` (512–527)
- **root cause class:** incentive misalignment / cross-path value transfer
- **severity:** Medium · **provenance:** econ-scanner
- **novelty:** **re-raise of owner wont-fix `69c7666eee33698e7f4f2cce7ab94406e40929494e19a2517a2a324e5c9ea73d`**

**DISCLOSURE (carried intact, per the re-file rule).** Prior entry `69c7666e…`, *"Underwater withdraw buffer is FCFS at par, socializing strategy loss onto slow stakers"*, Medium, **wont-fix**, triaged 2026-06-01. Its `triageReason`, quoted verbatim in the part that matters:

> "Intended design (confirmed by protocol owner) … bank-run / mass-exit is handled separately by migrateOut with pro-rata distribution. **The report itself concedes there is no incremental victim (the slow staker is baseline-unchanged vs a no-buffer world).**"

**Re-file basis:** story-020 falsified the emphasised clause, which was the load-bearing half of the closure. Under V1 the buffer never entered the migration payout, so a slow staker's credit was identical with or without it. Under V2, `R = balanceOf(this)` makes B2 part of the pro-rata pool, so every par exit taken while `Active` now removes cushion that would otherwise have been distributed to the whole cohort. The incremental victim now exists and is quantified (5,000,000 USDC zero-sum transfer on the scanner's worked example). The **first** clause of the closure (par exits during transient dips avoid forcing loss realisation) is *not* disputed, and the recommendation is deliberately narrower than the two fixes the owner rejected — the free runbook option `pause() → initiateMigration() → unpause()` needs zero code change. The owner's `reclassNote` is **not** overridden; this is a request to re-triage on new facts.

---

### DEDUP-15-03 — CrossVersionMigrator pre-flight fails open against a **codeless** destination
- **originalIds:** `CODE-002`, `MR-15-02`
- **contract:function:** `src/CrossVersionMigrator.sol :: initiateMigration` (145–150), `_migratorOf` (214–218), `_isRegisteredOn` (231–239), constructor (121–129)
- **root cause class:** fail-open validation / missing existence check
- **severity:** Low · **novelty:** **incomplete-fix-of `7cdb92fdc7`** (story-021 addresses the recognised-shape case only)
- **provenance:** code-scanner (PoC `test_CVM_preflight_failsOpen_on_codeless_destination`) + pattern-matcher MR-15-02

**Overlap 4 resolved — MERGED.** Same contract, same two functions, same root cause: a `staticcall` to a non-answering target returns `ok == true` with short data and every guard waives itself. MR-15-02's residual — *"the failure mode that waives the check is indistinguishable from the failure mode that should block it (an OOG on a large `getStakedTokens()`)"* — is not a second defect; CODE-002 states the same OOG leg verbatim and adds the concrete, PoC'd instance (a codeless / typo'd / wrong-network destination) plus the constructor `code.length` fix that closes both. MR-15-02 contributes two things that are preserved in the merged entry and must not be lost: (a) the verified fact that the fail-open is *deliberate and correctly documented* for version-agnosticism, and (b) the check that `< 64` does **not** accidentally swallow the empty-registry case (an empty registry ABI-encodes to exactly 64 bytes and is honestly rejected). Both narrow the finding to "the probe cannot distinguish *absent* from *unknown shape*", which is exactly the fix the constructor guard delivers.

Filed as an **incomplete fix of `7cdb92fd`, not a fresh discovery**, and with a distinct root-cause class (`fail-open-existence-check`) from that entry's own (`missing-destination-precondition`) so the two do not collide on one fingerprint. Impact is enumerated and bounded — the PoC drives freeze *and* recovery via `oldStaker.setMigrator`; no permanence is claimed.

---

### DEDUP-15-04 — destination preconditions: two of five asserted, and the in-source "uncheckable" claim is false — but the consequence is **materially smaller than F-03 stated**
- **originalIds:** `F-03`, `CODE-003`, `MR-15-01`
- **contract:function:** `src/CrossVersionMigrator.sol :: initiateMigration` (§C NatSpec 33–61, guards 145–150)
- **root cause class:** unasserted destination precondition + falsely-exhaustive in-source claim
- **severity:** Low · **provenance:** story-faithfulness (F-03) + code-scanner (CODE-003, the narrowing) + pattern-matcher (MR-15-01)
- **novelty:** **re-weigh of `7cdb92fdc7` — NO new fingerprint.** Same `contract:function`, same root-cause class as that open Low, which story-021 *partially* fixed. It must be **narrowed, not closed** — update the existing entry's narrative rather than minting a new one.

**Overlap 3 resolved — ONE reconciled entry, carrying the NARROWED impact. The overstated version is not carried forward.**

What survives from F-03 (verified independently this stage, at HEAD):
- `IFlax public immutable phUSD` is public on **both** shapes (`StableStakerV1.sol:90`, `StableStakerV2.sol:60`), and `FlaxToken` exposes `authorizedMinters(address)` and `mintVersion()` as external views (`setMinter` at `:44` `onlyOwner`, `revokeAllMintPrivileges` at `:88` bumping `mintVersion`, `mint` at `:58` requiring `minterInfo.mintVersion == mintVersion`). The two-hop probe is therefore **constructible under the migrator's own already-shipped advisory-on-probe-failure policy**. The NatSpec word *"uncheckable from here"* is factually wrong, and per this project's standing rule a falsely-exhaustive in-source claim carries no suppression authority and is itself reportable.
- The `revokeAllMintPrivileges` aggravator is real: a runbook step performed correctly weeks earlier can be silently void at initiate time, because the version bump does not touch `canMint`.

What is **struck** from F-03 by CODE-003 (verified in source this stage, not taken on report):
- F-03's claim that this precondition *"surfaces only at the first `depositFor` — i.e. **after** the source pool is already frozen"* is **wrong**. `StableStakerV2._settle` mints **only** `if (user.amount > 0)`; a migrating user's destination position is fresh (`amount == 0`), so `depositFor` mints nothing and **does not require the destination to be an authorized minter at all**. The migration completes. Authorization is first needed at a later `claim`/`stake`/`withdraw` on the destination — by which time `FlaxToken.setMinter` (plain `onlyOwner`, unconstrained by the frozen source) has been available the whole time.
- Consequently the "most expensive unguarded precondition" framing, the frozen-source timing trap, and the atomic-batch-revert recovery narrative all fall away. The minter leg on its own is **QA-tier documentation correction**, not an operational hazard.

What MR-15-01 adds that CODE-003 does **not** neutralise (and which is why the entry stays Low rather than dropping to QA): the **destination pool-state** precondition is also unasserted, and it *does* bite at migrate time — `depositFor` carries `require(poolState[token] == PoolState.Active, "StableStaker: pool not active")` (verified in `StableStakerV2.sol`), so a destination already `Migrating` reverts every `depositFor` in the *second* owner transaction, after the source is frozen. That is the timing trap F-03 mis-attributed to the minter.

**Net reconciled impact:** story-021 asserts 2 of 5 §C preconditions. Of the three left: the **pool-state** one is a genuine post-freeze operational trap (Low, recoverable — source sits in `Migrating` with emissions frozen while the owner fixes the destination; `userMigrate` remains a permissionless self-exit throughout); the **minter** one is a documentation defect only; the third is covered by DEDUP-15-03. Recommendation: assert destination `poolState == Active`, and either add the two-hop minter probe or correct §C to say "unguarded" without "uncheckable".

---

### DEDUP-15-05 — the one-way door has no minimum-realization floor, and the only discriminator that could supply one is deliberately discarded
- **originalIds:** `CODE-004`, `ECON-15-03`, `ECON-15-05`, `SA-08` (the one instance worth a human glance)
- **contract:function:** `src/StableStakerV2.sol :: initiateMigration` (469, 496–527)
- **root cause class:** missing bound on an irreversible step / lost invariant discriminator
- **severity:** Low · **provenance:** code-scanner + econ-scanner (×2) + static-analyzer
- **novelty:** NEW. Related to `7cdb92fd` but on a **different contract:function** (`StableStakerV2`, not `CrossVersionMigrator`), so it mints its own fingerprint legitimately. ECON-15-03 described itself as "extending `ss14l6`" — treat as *related*, not as the same entry.

**Overlaps 2 and 5 resolved together — ONE entry, because they are one mitigation line.**

- **ECON-15-03 ≡ CODE-004's residual.** Same contract, same function, same root cause: nothing compares `R` against `P` except to cap it, so `initiateMigration` completes at any `R` including `0`, irreversibly, and reports it with a `PrincipalDivergence(token, P, 0, 0)` payload byte-identical to a clean migration. Two scanners reaching the same defect from opposite directions (code: "the tripwire lost its discriminator"; econ: "`ERC4626YieldStrategy._disposeShares` redeems with no minimum out"). Merged.
- **ECON-15-05 ≡ CODE-004's observability leg.** Both name `_routeExit`'s discarded return value at `:469` as the defect. It is not a separate finding: the *same* one-line change supplies both the floor and the event decomposition — `uint256 delivered = _routeExit(token, P, false); require(booked == 0 || delivered + booked >= P, "StableStaker: exit shortfall");` plus emitting `delivered`. Filing them apart would put one code change in two report entries.
- **Severity:** Low, the highest of the three (ECON-15-05 alone was QA). The QA-tier observability recommendation is preserved as a sub-leg, not dropped.

**Corrections preserved from the merge (they lower the severity and must not be lost):** the "a partially-failed exit can now proceed where V1 aborted" framing is **REFUTED** for the current strategy family — `AYieldStrategy._withdrawInternal` debits the **requested (capped)** amount, so `booked == 0` on a below-par exit and **V1 proceeded too**. Story-020 removed a *reconciliation* brick, not a loss guard; on the loss path V2 is strictly better for users than V1. This is **not a regression**. The unbounded `relinquishPrincipal(booked)` leg is latent (it requires a custody adapter that debits by *received*; none exists in `reflax-yield-vault` today) and is stated, not rated.

**Overlap 2, second half — `MR-15-03` is NOT part of this entry.** The run brief grouped `MR-15-03` with CODE-004/ECON-15-03 as "no floor on R". That premise is incorrect: MR-15-03 is `versionOf` inferring version 1 from a *reverting* `staticcall` (`CrossVersionMigrator:198-202`) — a different contract, a different function, and a version-detection root cause with nothing to do with `R`. It is not merged and not dropped; it is **parked** (§4, `MR-15-03`).

---

### DEDUP-15-06 — `rescueERC20` reserves nothing while a strategy is set, so a routine dust sweep converts a par migration into a haircut migration
- **originalIds:** `ECON-15-02`
- **contract:function:** `src/StableStakerV2.sol :: rescueERC20` (868–875)
- **root cause class:** owner footgun, non-obvious consequence (Law 3 in-scope)
- **severity:** Low · **provenance:** econ-scanner
- **novelty:** **impact re-weigh of open Low `0790a76a00ed176437d53a474145b1b5eac1a0359034e1dde31b98470b9837bb`** (*"rescueERC20 can sweep the buffer backing underwater withdrawals"*) — same `contract:function`, same root cause. **NO new fingerprint; do not re-file.** Update the existing entry: story-020 made the swept balance the *migration cushion*, so a single `onlyOwner` call whose NatSpec says it cannot touch user value now moves a 15,000,000 USDC swing across the cohort on the scanner's worked example. The NatSpec justification ("the contract balance is purely buffer + dust") was accurate before story-020 and is now incomplete.
- Only the **unknowing** consequence is filed; malicious-owner variants are suppressed under Law 3.

---

### DEDUP-15-07 — the `ss14l8` fix is only as large as an off-chain config nobody asserts
- **originalIds:** `ECON-15-04`
- **contract:function:** `src/StableStakerV2.sol:521` ↔ `lib/reflax-yield-vault/src/AYieldStrategy.sol:63` (`setAsideBufferRecipient`)
- **root cause class:** cross-contract trust-assumption gap
- **severity:** Low · **novelty:** NEW · **provenance:** econ-scanner
- Kept separate from DEDUP-15-01/06 (see the Overlap-1 table). It is also the reason `f7991b64` (`ss14l8`) should be closed **with a caveat**: the cushion the fix promises is ~0 whenever `setAsideBufferRecipient` points at a treasury — one address for the whole strategy, never read or asserted by the staker.

---

### DEDUP-15-08 — the frozen-V1 CI gate under-enforces its own stated guarantee (2 instances)
- **originalIds:** `F-01`, `F-02`
- **contract:function:** `.github/scripts/check-migration-surface.sh` (100–113 and 118–145); echoed at `src/versions/README.md:72`
- **root cause class:** CI gate / in-source claim over-states the protection delivered (Law 2 deviation)
- **severity:** QA · **novelty:** NEW · **provenance:** story-faithfulness
- **consolidated because** both are the same file, the same guarantee ("a mismatch is a hard failure … the ONLY deliberate way past this gate is `GOLDEN-RULE-OVERRIDE`"), and one review/mitigation surface. Instances:
  1. **Conditional skip** — on a host without GNU `sha256sum` the hash verification is skipped with `status` untouched, so an *edited* frozen V1 passes green with a `note:` on stderr. That is the shape of the defect `ss14l3` closed, reintroduced one layer down. CI (`ubuntu-latest`) is currently intact; exposure is the local/pre-commit path the story itself points developers at.
  2. **Unimplemented override + unnamed bypass** — the script never reads a commit message (`exit $status`, unconditional), and editing a frozen file *and* regenerating `FROZEN.sha256` in the same change satisfies every check (`manifest_count != 2` rejects only an emptied or extended manifest, never a re-pinned one).
- **Disclosure:** leg 2's first half substantially overlaps open QA `c8218865da` (*"CLAUDE.md's description of golden-rule enforcement layer 1 over-states what the hook does"*) — the same false claim, restated in the script banner rather than in `CLAUDE.md`. The **same-commit re-pin bypass** and the **`sha256sum`-absent skip** are new. Related: `9abbb7b146` (gate fails to prevent *deletion*) — a distinct mechanism, not merged.

---

### DEDUP-15-09 — story-020's compensating controls for its fail-open self-heal are nominal, not real (2 instances)
- **originalIds:** `F-04`, `NOTE-1`
- **contract:function:** `src/StableStakerV2.sol :: initiateMigration` / `setYieldStrategy`
- **root cause class:** unsatisfied acceptance condition / compensating control does not exist
- **severity:** QA (operational) · **novelty:** NEW · **provenance:** story-faithfulness
- **The code is faithful** — `PrincipalDivergence` is emitted unconditionally before the `booked > 0` guard, `ProtocolPrincipalSwept` captures the previously-discarded return, and the `"StableStaker: incomplete exit"` post-check is retained byte-identically. What is missing is the off-chain half the story itself names as the thing that makes the new silence safe. Instances:
  1. **No alert owner.** Story-020's Concerns specify the monitoring rule verbatim (*"sum `ProtocolPrincipalSwept.credited` per token since the last `PoolReset`, and page when a `PrincipalDivergence.booked` exceeds that sum"*) and state *"Nobody owns that alert yet."* The story carried that as its own `[medium]` non-blocking finding and **auto-completed anyway**. The bound on the fail-open conversion is currently vacuous.
  2. **The surviving tripwire has no conforming-strategy coverage.** The sole test proving it still trips, `test_postCheck_incompleteExitReverts`, depends on `UnderRealizingStrategy.relinquishPrincipal` being a **no-op stub** (`test/Migration.t.sol:845`) — i.e. the tripwire is exercised only by a mock that deliberately violates the base contract. Faithful to story-020 and not a deviation, but consolidated here under this project's standing precedent that a no-op mock stub can fake a permanence result.
- **Law-1 override was tested and did not trigger:** the harm hypothesis (the self-heal writing down user-claimable principal) is refuted against the real dependency — `_withdrawInternal` debits the requested amount, so residual `booked` after `_routeExit(P)` is exactly the sweep excess, protocol money by the empty-pool gate. Filed under Law 2.

---

## 3. Reconciliation-only (no finding filed)

| Ledger entry | Disposition this run |
|---|---|
| `f7991b64ad` `ss14l8` L-08 — *terminal migration ignores the set-aside buffer* | **PROPOSE FIXED** on V2, implemented exactly as its own `recommendation.fix` prescribed (`:521-524`, `min(R,P)` cap retained). Human confirmation required. **Close with the DEDUP-15-01 and DEDUP-15-07 caveats attached** — the fix does not reach buffer already swept into the strategy, and its size depends on an unasserted off-chain config. |
| `d1aa40605d` `ss14m1` M-01 — *`setYieldStrategy` sweep bricks terminal migration* | **SPLIT — DO NOT CLOSE.** Fixed on V2 (D3 removes the brick). **Still open on V1/mainnet:** DOLA and USDC on `0xbce8ABC09BaEDCabE93419bF875f6186e182079A` revert `"incomplete exit"` today; V1 is frozen and unpatchable, and `CrossVersionMigrator.initiateMigration` forwards *into* V1's `require`. Remedy exists (`AYieldStrategy.relinquishPrincipalAsOwner`, strategy-owner) — recoverable, not permanent. Root cause also preserved on V2: the unrecorded sweep still happens, now merely logged. |
| `69c7666eee` — *underwater buffer FCFS at par*, Medium, **wont-fix** | **RE-RAISED** as DEDUP-15-02 with full disclosure. Owner's `reclassNote` left intact. |
| `0790a76a00` — *rescueERC20 sweeps the buffer*, Low, open | **IMPACT RE-WEIGH** (DEDUP-15-06). Same fingerprint. Do not re-file. |
| `7cdb92fdc7` `ss14l6` — *unvalidated one-way door*, Low, open | **NARROW, do not close.** Partially fixed by story-021. Residual precondition leg → DEDUP-15-04 (in-place). Fail-open leg → DEDUP-15-03 (new fingerprint, `incompleteFixOf`). |
| `d47619d29f` — *`phUSDPerDay` floors to 0*, Low, open | `MR-15-04` matched it. **Unchanged; DO NOT RE-FILE.** Listed only so the pattern tier's coverage is auditable. |
| `59eebbf87b` (unbounded per-user loop), `7b0717792d` (unused `EnumerableSet.add/remove` return) | Re-matched by `SA-10` / `SA-08`. Already ledgered, unchanged. **Do not re-file.** |
| `f84992e9ac` L-04 (`migrateIn` dangling `forceApprove`), `35e9be8d59`/`69c7666e` (`_routeExit` par payout, byte-identical V1↔V2) | Re-observed, unchanged, already ledgered. Not re-filed. |
| All findings against `src/versions/v1/StableStakerV1.sol` | **NONE FILED.** The normalized V1↔V2 diff contains only the six declared deltas plus the frozen header and two rename lines; storage layout identical, neither contract proxied. Every V1 defect is a re-raise of already-ledgered deployed behaviour, deliberately preserved by story-019. Reconcile, do not action. |

---

## 4. Fingerprint drift — `src/StableStaker.sol` → `src/StableStakerV2.sol` (MECHANICAL LIST)

Story-019 renamed `src/StableStaker.sol` → `src/StableStakerV2.sol` (and froze a copy at `src/versions/v1/StableStakerV1.sol`). Fingerprints are `sha256(contract:function:rootCauseClass[:entryPoint])`, so **every ledger entry whose contract basis is `src/StableStaker.sol` will fail to reconcile at HEAD and risks being re-filed as new**. Derived mechanically (`contract` field containing `src/StableStaker.sol`): **28 of 46 entries**.

**At-risk (14 — live status, will be re-scanned and can be silently duplicated):**

| Fingerprint | Status | Sev | Function (match key across the rename) |
|---|---|---|---|
| `0790a76a00` | open | low | `rescueERC20` — *also touched this run (DEDUP-15-06)* |
| `59eebbf87b` | open | low | `batchMigrate` (+ `CrossVersionMigrator.migrate`) |
| `7b0717792d` | open | info | `add` (EnumerableSet return) |
| `b5218ab272` | submitted | medium | `migrateOut` |
| `dab5a65613` | fix-pending | medium | `setYieldStrategy` — **`fix-pending` is never suppressed; drift here is the highest-consequence case** |
| `4f143a9573` | open | low | `migrate → depositFor → _routeDeposit` (scope-extended) |
| `a56f87780b` | open | low | `withdrawDisabled` |
| `d47619d29f` | open | low | `phUSDPerDay` — *re-matched this run by MR-15-04* |
| `796f775ff3` | open | info | `initiateMigration` (state-after-call) |
| `ss9l1-fina` | open | low | `finalizeAndReset` |
| `787e9faceb` | submitted-qa | low | `setYieldStrategy` (dust-stake grief) |
| `b197e829fb` | submitted-qa | low | `setYieldStrategy` / `finalizeAndReset` (NatSpec/dead branch) |
| `86fcf00ef7` | open | qa | `finalizeAndReset` (revived-pool window) |
| `d1aa40605d` | open | medium | `setYieldStrategy → initiateMigration` — **the V1/V2 split entry; see §3** |
| `f7991b64ad` | open | low | `initiateMigration` (buffer ignored) — **propose-fixed this run** |

**Also drifted but currently suppressed (14 — `fixed` / `acknowledged` / `wont-fix` / `info` / `false-positive`).** Drift still matters for these: a suppressed entry that fails to reconcile stops suppressing, and a `fixed` one that reappears would be mis-flagged as a **REGRESSION** rather than as drift.
`3d61c9552f` (ack, `migrateOut`) · `69c7666eee` (wont-fix, `_routeExit` — **re-raised this run**) · `35e9be8d59` (wont-fix, `migrateOut`) · `e4567dc343` (wont-fix, `userMigrate`) · `eae10d6031` (fixed, `depositFor`) · `678e6fa207` (fixed, `setYieldStrategy`) · `dc361b7d20` (fixed, `initiateMigration`) · `0dca43f315` (ack, `emergencyWithdraw`) · `dbdc3ac9b9` (ack, `setYieldStrategy`) · `969722dc9e` (ack, `setYieldStrategy`) · `8d5ceff20c` (fixed, `depositFor`/`_exitPosition`) · `c603257563` (info, `setYieldStrategy`/`initiateMigration`) · `b806f4008a` (false-positive, `StableStakerMigrator.migrate → depositFor`) · plus `b5218ab272`/`4f143a9573` counted above.

**A second, independent drift found this stage (not in the brief):** two entries are fingerprinted on `src/versions/IStableStakerV1.sol`, but the file at HEAD is `src/versions/**v1**/IStableStakerV1.sol` (directory verified). Both will fail to reconcile:
- `e3553aa70b` — open, low — *story-015's snapshot-extraction ritual targets master HEAD rather than the deployed commit*
- `9e9dbdc475` — open, qa — *`IStableStakerV1.sol` NatSpec inaccuracies*

**Handling rule for this run (finding-manager / `/ledger`):** every entry above must be matched across the rename by **`function` + root-cause class**, not by `contract`, and re-based to the new path. **No entry in this list may be filed as NEW, and none may be flagged REGRESSION, on the strength of a path change alone.** The two Medium/`fix-pending` cases (`dab5a65613`, `d1aa40605d`) and the `submitted` one (`b5218ab272`) should be re-based by hand and diffed against the start-of-run snapshot before the ledger is written.

---

## 5. Parked — `manual-review.json` (nothing dropped silently)

| Parked ID | Original | Reason |
|---|---|---|
| `MR-15-03` | pattern-matcher MR-15-03 | `versionOf` infers version 1 from a reverting `staticcall`. Real and correct as written, but gates no control flow (consumed only by the `MigratedAcrossVersions` event), so filing above informational would overstate it. **Explicitly NOT merged into DEDUP-15-05** — the brief's grouping with the "no floor on R" cluster was mistaken; different contract, function and root cause. Routed because "V1 must never gain a `STAKER_VERSION` getter" is a live invariant whose only enforcement is the frozen-file hash check — i.e. DEDUP-15-08. |
| `NOTE-2` | story-faithfulness | Stories 020 and 021 sit in `auto-complete/`, an **unenumerated** state (`CLAUDE.md` lists `complete\|incomplete\|review\|archive`), both machine-approved with reduced independence, and 020 auto-completed carrying its own `[medium]` finding (= DEDUP-15-09). Process/registry item, not a code finding. |
| `NOTE-4` | story-faithfulness | `GOLDEN-RULE-OVERRIDE` appears verbatim in commit `21a7cef`, which did **not** retire V1 — any future tooling that greps history for the marker gets a false positive. Hygiene note; interacts with DEDUP-15-08. |
| `SA-13` | static-analyzer | `StableStakerV1` implements the `IStableStakerMigratable` surface without declaring inheritance. Frozen file — cannot be fixed in place by design. Adjacent to open QA `9e9dbdc475`; routed rather than dropped so triage can decide whether to fold it in. |

**Flagged for human review (in-band, not parked):** DEDUP-15-01's severity. The code-scanner filed Medium while conceding Low is defensible — the stranded value remains protocol-owned inside the strategy and is recoverable by the strategy owner (`totalWithdrawal` / `withdrawAsOwner`), which engages the standing "protocol capital is opportunity cost, not loss" carve-out; against that, the *user-facing* haircut is real, uncapped, contradicts the intent of the change shipped in the same commit, and step 1 of its path is already history on two live mainnet pools. Carried at Medium into severity-classifier with the contest recorded rather than resolved here.

---

## 6. Dropped — tool artifacts cleared by manual review (one line each)

| SAST class | Reason dropped |
|---|---|
| `SA-01`…`SA-05` reentrancy-no-eth (`stake`, `depositFor`, `setYieldStrategy`, `initiateMigration`, `migrateIn`) | Every flagged entry point carries `nonReentrant`; migrator paths add `onlyOwner`/`onlyMigrator`; the full reentrancy-class walk (classic / cross-contract / cross-function / read-only / 721 / 1155 / 777) was performed and cleared. Cross-function state-write ordering artifact. |
| `SA-06` reentrancy-benign, `SA-07` reentrancy-events | Event-ordering only; no state consequence. |
| `SA-08` unused-return | Almost entirely deliberate `EnumerableSet.add/remove` returns — already ledgered `7b0717792d`. The one instance with signal (`_routeExit`'s discarded delta) is carried in **DEDUP-15-05**. |
| `SA-09` uninitialized-local | `uint256 total; uint256 count;` loop accumulators relying on the zero default. Benign as written. |
| `SA-10` calls-loop | Already ledgered `59eebbf87b` (unbounded per-user external-call loop). Not re-filed. |
| `SA-11` timestamp-dependence (12) | No manipulable window: accrual is monotonic in `block.timestamp` and `claimTimedOut` uses a multi-hour `MIN_TIMEOUT`. Several instances are `require(totalStaked == 0)` strict-equality checks the detector misfiles as time logic. Retained by policy at Tier 1, resolved here. |
| `SA-12` modifier-order | `nonReentrant` not declared first — style; the guard is effective regardless of declaration order. |
| `SA-13` missing-inheritance | **Not dropped — parked** (§5). |
| `SA-14` centralization (aggregate, 24 owner-gated entry points) | Law 3: the owner is trusted for knowing actions; a detector count is not a footgun. The two *non-obvious* footguns found by manual review are filed as DEDUP-15-06 and DEDUP-15-04. |
| Semgrep (146) | `p/smart-contracts` contains no Solidity security rules; all 146 are `solidity.performance.*` / `best-practice.*`. Coverage evidence only, not security evidence. |
| Aderyn pragma/PUSH0/zero-check/literal/modifier-once/costly-loop (26), Slither `naming-convention`/`assembly`/`missing-zero-check`/`low-level-calls` (7) | Dropped at Tier 1 under the standing noise policy; re-confirmed here. `low-level-calls` are the three `staticcall` version probes with no value transfer — their *security* content is carried in DEDUP-15-03. |
