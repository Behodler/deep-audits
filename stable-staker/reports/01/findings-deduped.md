# Deduplicated & Consolidated Findings — stable-staker

- **Audit run:** `reports/stable-staker/01/` · **commit:** f524cc3 · **dedup date:** 2026-06-01
- **Sources:** `code-findings.md`, `econ-findings.md`, `static-analysis.md` (normalized SAST), `pattern-matches.md`, plus referenced profiler items (LOCAL-002, LOCAL-M01/M03).

## DEDUP-001 — Underwater-pool migration is bricked: `migrateOut` returns *requested* principal while the migrator re-deposits requested amounts against the *received haircut* payout
- **Original ids:** CODE-001 (code-scanner) + ECON-002 (econ-scanner) **merged**; corroborated by profiler LOCAL-M01, pattern #2 (RETURN-VALUE-IGNORE/strategy-trust), atomicity per LOCAL-M03.
- **Severity:** Medium · **Type:** cross-contract accounting mismatch → DoS of the migration escape hatch
- **Locations:**
  - `src/StableStaker.sol:migrateOut` — return `amounts[i]=amt` @324; `totalPrincipal+=amt` @325; `payout=_routeExit(token,totalPrincipal,false)` @334; `safeTransfer(msg.sender,payout)` @335
  - `src/StableStaker.sol:_routeExit` @488-507 (balance-delta return @504-506)
  - `src/StableStakerMigrator.sol:migrate` — `amounts=oldStaker.migrateOut(...)` @46; `total=Σamounts` @48-51; `forceApprove(newStaker,total)` @57; `depositFor(token,users[i],amounts[i])` @60-65
  - `src/StableStaker.sol:depositFor`→`_pullToken` (`safeTransferFrom(migrator,...)`) @356/457-461
- **Root cause:** `migrateOut` returns each user's *requested* principal (`amounts[i]=amt`, @324) but transfers only the *measured-received* aggregate (`payout=_routeExit(...,false)`, @334). The ERC4626 strategy decrements principal by the requested amount while delivering only the shares' current value, so below par `payout < Σamounts`. The migrator approves and pulls `Σ requested` via `depositFor`, exceeding its haircut balance.
- **Trigger:** strategy set → vault dips below par (`withdrawDisabled` true, `migrateOut` not blocked by design) → `migrate(token,users)` → `migrateOut` forwards haircut `payout` but returns full requested amounts → redeposit loop drains the haircut then a later `depositFor`→`safeTransferFrom` reverts on insufficient balance → whole `migrate` tx reverts atomically.
- **Impact:** The marquee zero-user-action incident migration is unavailable in exactly the below-par incident it exists for; only works at/above par. No fund loss / no state corruption (atomic revert) → caps at Medium. Counterfactual: re-crediting requested would mint phantom principal on the destination. `forceApprove(total)` also over-grants.
- **Fix:** return actually-delivered per-user amounts (pro-rata `amt*payout/totalPrincipal`, dust round-down), or have the migrator redeposit pro-rata against its realized post-`migrateOut` balance, or redeem each user individually.

## DEDUP-002 — Underwater `withdraw` buffer is FCFS at par: early withdrawers exit loss-free, socializing the full strategy loss onto late/emergency/migrating users
- **Original ids:** ECON-001 (econ-scanner); buffer-drain lead also flagged by pattern #2/#4.
- **Severity:** Medium · **Type:** economic — unfair loss socialization / bank-run ordering
- **Location:** `src/StableStaker.sol:_routeExit` @494-502 (buffer branch, `if (t.balanceOf(this)>=amount) return amount;` @498, else `revert("strategy underwater")`), reached from `withdraw` @258.
- **Root cause:** Below par, a non-migrating `withdraw` is paid in full **at par** from the finite shared protocol-owned buffer (strategy shares NOT redeemed), FCFS with no proportional haircut. A pooled loss is borne entirely by whoever is slow.
- **Trigger:** strategy below par by shortfall `S`, buffer `B`; `withdrawDisabled` flips (race is on-chain observable) → fast actors/MEV `withdraw` until buffer drained (each at par) → remaining `withdraw` reverts → late users forced to `emergencyWithdraw`/`migrateOut` and eat the entire `S`, vs a fair `S/totalStaked` each.
- **Impact:** Loss not distributed pro-rata; buffer subsidizes early exiters, residual loss dumped on the last cohort. Not a documented design.
- **Fix:** while underwater either block the solvent `withdraw` path (force everyone through the haircut path), or apply the current par-ratio (`totalBalanceOf/principalOf`) to buffer payouts so all withdrawers take the same proportional haircut.

## DEDUP-003 — `rescueERC20` can sweep the entire underwater buffer (`reserved=0` when a strategy is set), bricking pending par-withdrawals
- **Original ids:** ECON-003 + profiler LOCAL-002 + code-scanner Lead 3 + pattern #5 (rescue branch) **four-way merge**.
- **Severity:** Low / QA (centralization-adjacent) · **Type:** spec tension / owner-trust
- **Location:** `src/StableStaker.sol:rescueERC20` @521-528 (`reserved = yieldStrategy[token]!=0 ? 0 : totalStaked`, the `=0` branch @523), interacting with `_routeExit` buffer branch @494-501.
- **Root cause:** With a strategy set, `rescueERC20` treats `reserved=0` and lets the owner sweep the entire on-contract balance — which is exactly the buffer backing DEDUP-002's at-par underwater `withdraw`. Sweeping (or front-running a pending underwater `withdraw`) flips that withdraw to `revert("strategy underwater")`.
- **Trigger:** owner-only; strategy set + below par → `rescueERC20(token,...)` removes the buffer.
- **Impact:** Owner can remove the protocol-owned reserve backing at-par underwater withdrawals. Owner-only (trusted role), swept funds are protocol-owned → no theft of accounted user principal. Not rug-enabling → QA/Low.
- **Fix:** reserve buffer from rescue when a strategy is set (e.g. `max(0, principalOf-totalBalanceOf)`), or document the buffer as discretionary.

## DEDUP-004 — Unbounded per-user external-call loop in `migrateOut`/`migrate` (batch DoS / gas griefing)
- **Original ids:** pattern #1 (DOS-UNBOUNDED-LOOP) + L-static-2 (Slither `calls-loop` / Aderyn `costly-loop`, corroborated) **merged**.
- **Severity:** Low (permissioned, operator-controllable, recoverable by re-batching) · **Type:** unbounded loop / DoS
- **Location:** `src/StableStaker.sol:migrateOut` `phUSD.mint` in loop @327 (loop @312); `src/StableStakerMigrator.sol:migrate` `depositFor` in loop @60-62.
- **Root cause/trigger:** per-iteration external calls over an operator-supplied `users[]`; an over-sized batch (or the full `getStakers` set) can exceed block gas and brick that batch; one reverting callee fails the whole tx.
- **Impact:** DoS of a batch only if operator over-sizes it; `getStakersRange` paging + off-chain batching mitigate → Low. (Orthogonal to DEDUP-001 on the same functions.)
- **Fix:** enforce/document a max batch size; rely on existing paging.

## DEDUP-005 — Unused return value of `EnumerableSet.add/remove`
- **Original ids:** M-static-4 (Slither `unused-return`, downgraded).
- **Severity:** QA / Informational · **Type:** code-quality
- **Location:** `src/StableStaker.sol` — `stake` add@233, `depositFor` add@361, `withdraw` remove@250, `emergencyWithdraw` remove@287, `migrateOut` remove@323.
- **Note:** Benign for `EnumerableSet` (idempotent membership); QA-bundle candidate, not a security finding.

---

## Folded to "no finding / mitigated" (NOT carried)
- **Reentrancy hits** M-static-1 (`migrateOut`, Aderyn HIGH), M-static-2 (`stake`), M-static-3 (`depositFor`), and pattern #3 — all **guard-mitigated** per code-scanner Lead 2: every mutating entrypoint carries `nonReentrant`; the strategy is itself `nonReentrant` and never calls back into `StableStaker`; only `phUSD`/staked-token could re-enter and both are trusted by the documented model.

## Filtered as noise / by-design / OOS
- L-static-1 (reentrancy-events, guarded) — Low noise.
- L-static-3 (missing zero-address on `setMigrator`/`setPauser`) — admin-mistake class, QA per project conventions.
- L-static-4 (uninitialized local accumulators) — default-0, written before read, style nit.
- pattern #2 (strategy-trust) — actionable manifestation resolved into DEDUP-001/002; strategy is owner-trusted, no separate finding.
- pattern #4 (reward-debt rounding) — mul-before-div, dust rounds DOWN, protective; confirmed sound (code Lead 4, econ #2).
- pattern #5 / Aderyn centralization-risk (8) — documented owner-trust design; only the rescue `reserved=0` sub-item promoted (DEDUP-003).
- Semgrep (40 INFO gas/style) — no security relevance.
- 9 documented known issues — out of scope, by-design.

## Counts
- **Raw ingested: 18** — code 1, econ 3, static 8, pattern 5, profiler 1.
- **Deduplicated: 5** (DEDUP-001..005) — Medium 2, Low 1, Low/QA 1, QA/Info 1.
- **Raw → deduped: 18 → 5.**
