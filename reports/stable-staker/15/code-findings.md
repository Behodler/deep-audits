# Code-Level Findings — stable-staker run-15 (Tier-2 interaction scan)

- **HEAD:** `2146428` · **Baseline:** `8856781` (run-14) · **Mode:** regression
- **Scope scanned:** `src/StableStakerV2.sol`, `src/versions/v1/StableStakerV1.sol`, `src/CrossVersionMigrator.sol`, `src/InPlaceMigrator.sol`
- **Cross-repo reads (top-level submodule HEADs, per the nested-pin rule):** `lib/reflax-yield-vault/src/AYieldStrategy.sol`, `lib/flax-token/src/FlaxToken.sol`
- **PoCs:** `workspace/stable-staker/test/poc/Run15_CodeScan.t.sol` — 2/2 PASS
- **Ledger consulted:** `reports/stable-staker/ledger.json` (46 entries) before every novelty claim.

---

## CODE-001 — `initiateMigration`'s self-heal *relinquishes* the swept buffer instead of *withdrawing* it, defeating the same story's own D4 buffer-softening

- **Severity:** Medium (arguable Low — see Impact)
- **Contract:function:** `src/StableStakerV2.sol :: initiateMigration` (lines 466–516)
- **Root cause class:** intra-story self-inconsistency / value-routing (write-down where a realization was required)
- **Confidence:** high — PoC `test_selfHeal_destroys_the_buffer_D4_was_meant_to_spend`
- **New this run** (both halves land in commit `69c6fef`; no ledger entry matches).

Story-020 makes two changes in one commit that pull in opposite directions.

```solidity
// src/StableStakerV2.sol:469
_routeExit(token, P, false);                                   // realizes only P

// :479
uint256 booked = address(strategy) == address(0) ? 0 : strategy.principalOf(token, address(this));
// :485
emit PrincipalDivergence(token, P, booked, booked);
// :490
if (booked > 0) {
    strategy.relinquishPrincipal(token, booked);               // <-- WRITE-DOWN, no tokens move
}
...
// :521
uint256 R = IERC20(token).balanceOf(address(this));            // D4: "so the set-aside buffer counts"
if (R > P) { R = P; }
```

- **D4** (`R = balanceOf`) exists so that on-contract working capital (**B2**) softens a below-par
  migration "before any user is haircut" (its own comment, :513–517).
- **D3** (the self-heal) fires on exactly the `booked > 0` condition whose *known cause* is
  `setYieldStrategy`'s idle sweep — i.e. **B2 that was previously swept into the strategy**. It
  disposes of that capital with `relinquishPrincipal`, which by design "touches recorded principal
  only — no vault shares move" (`AYieldStrategy._relinquishInternal`, lines 667–684 of
  `lib/reflax-yield-vault/src/AYieldStrategy.sol`). The tokens therefore stay inside the strategy and
  **never reach the balance D4 is about to measure**.

**Exploit path (no attacker needed — the ordinary operational sequence):**
1. Owner wires a strategy while the pool is empty; 50,000 USDC of B2 is swept in
   (`ProtocolPrincipalSwept`). `clientBalances = 50,000`.
2. Users stake 1,000,000. `clientBalances = 1,050,000`, `totalStaked = P = 1,000,000`.
3. Strategy drifts to 90% of par.
4. `initiateMigration`: `_routeExit(P)` realizes 900,000; `booked = 50,000` is **relinquished**;
   `R = 900,000`. Users are paid 90.0%.
5. Had the 50,000 been *withdrawn* rather than written off, it would have realized 45,000 more:
   `R = 945,000`, users paid **94.5%**.

**Impact:** in a below-par terminal migration preceded by any idle sweep, stakers take a strictly
larger principal haircut than realizable protocol capital required — 45,000 USDC of stranded value
on the PoC's numbers. Per the standing econ carve-out the money is not *lost* (it remains inside the
strategy as protocol-owned surplus, recoverable by the strategy owner via `totalWithdrawal` /
`withdrawAsOwner`), which is why Low is defensible; it is filed at Medium because the user-facing
haircut is real, uncapped, and directly contradicts the stated intent of the change shipped
alongside it. Note the memory-recorded fact that **live DOLA and USDC on V1 are already in the
swept-divergence state**, so step 1 is history, not hypothesis.

**Recommended mitigation:** realize before writing off —
`strategy.withdraw(token, booked, address(this))` first, then `relinquishPrincipal` only on whatever
residue survives. That both feeds D4 and keeps the tripwire below.

---

## CODE-002 — CrossVersionMigrator pre-flight fails open against a **codeless** destination: the one-way door opens for the most likely wiring mistake

- **Severity:** Low
- **Contract:function:** `src/CrossVersionMigrator.sol :: initiateMigration` (145–150), `_migratorOf` (214–218), `_isRegisteredOn` (231–239), constructor (121–129)
- **Root cause class:** fail-open validation / missing existence check
- **Confidence:** high — PoC `test_CVM_preflight_failsOpen_on_codeless_destination`
- **Relation to ledger:** **incomplete fix of** `L-06 (low, open) — "initiateMigration is an unvalidated one-way door: no destination precondition checked"`. Story-021 addresses the *recognised-shape* case only. **Do not file as a fresh discovery — reconcile against L-06.**

```solidity
function initiateMigration(address token) external onlyOwner {
    require(_isRegisteredOn(address(newStaker), token), "Migrator: destination token not registered");
    (address destMigrator, bool probed) = _migratorOf(address(newStaker));
    require(!probed || destMigrator == address(this), "Migrator: destination not wired");
    oldStaker.initiateMigration(token);          // ONE-WAY DOOR
}
```

A `staticcall` to an address with **no code** succeeds and returns empty data. Therefore:

- `_isRegisteredOn`: `ok == true`, `data.length == 0 < 64` → `return true` (fail-open);
- `_migratorOf`: `ok == true`, `data.length == 0 < 32` → `probed == false` → `!probed` satisfies the require.

The constructor checks `!= address(0)` and `_oldStaker != _newStaker` but **not** `code.length > 0`.
The guard's own stated purpose — "a wiring mistake discovered at the first `migrate` call is
discovered too late" (NatSpec section C) — is thus unmet precisely for a typo'd, wrong-network or
not-yet-deployed destination, which is the dominant real-world instance of that mistake. The
docs' claim that a failing probe means "a staker shape this migrator does not recognise" is
*false* in this case: it means there is no contract at all.

The same fail-open also swallows an out-of-gas `staticcall` (63/64 rule) — non-adversarial here
since both entry points are `onlyOwner`, but it means probe failure is not evidence of "unknown
shape".

**Impact — enumerated, no permanence claimed.** The PoC drives the freeze *and* the recovery. After
the bad `initiateMigration`, the source pool is latched `Migrating`: `stake` / `withdraw` /
`emergencyWithdraw` are blocked and emission accrual is frozen (`_updatePool` early-returns).
Value is **not** stuck; every remedy below exists and is reachable:
- `oldStaker.setMigrator` (`onlyOwner`, present on the deployed V1 at `StableStakerV1.sol:230`) →
  repoint to a correctly-constructed migrator, which may then call `batchMigrate` (`Migrating` is
  already engaged) and complete the hop. The PoC does exactly this and recovers Alice at par.
- `newStaker.setMigrator`, `newStaker.addToken` — destination side.
- `userMigrate` — permissionless self-exit at the snapshot credit.
- `oldStaker.finalizeAndReset` (`onlyOwner`) once drained, then `setYieldStrategy` to re-wire.
So the consequence is an operational freeze plus lost emissions for the repair window, not a loss.

**Recommended mitigation:** `require(address(_newStaker).code.length > 0 && address(_oldStaker).code.length > 0, "Migrator: codeless staker")` in the constructor; and correct section (C)'s advisory prose, which currently over-claims what a failed probe implies.

---

## CODE-003 — Precondition #9 (destination phUSD minter authorization) is unenforced, but the consequence is smaller than documented

- **Severity:** QA / informational (**refutes** the profile's framing that it "surfaces only after the source is frozen" in a damaging way)
- **Contract:function:** `src/CrossVersionMigrator.sol :: migrate` → `StableStakerV2.depositFor`
- **Confidence:** high (read-through, no PoC needed)

`depositFor` → `_settle(user, info, pool)` mints **only** when `user.amount > 0`
(`StableStakerV2.sol`, `_settle`). A migrating user's position on the *destination* is fresh
(`amount == 0`), and `_updatePool` never mints. **`depositFor` therefore does not require the
destination to be an authorized minter**, and the migration completes. Authorization is first
needed at a later `claim` / `stake` / `withdraw` on the destination.

Remedy enumeration (per the absence-of-remedy rule): `FlaxToken.setMinter(address,bool)` is plain
`onlyOwner` (`lib/flax-token/src/FlaxToken.sol:44`) and always available; nothing about the frozen
source constrains it. No value is stuck and there is no timing trap. This is a documentation
correction on `CrossVersionMigrator` NatSpec section (C) and the profile's precondition table,
not a security finding.

---

## CODE-004 — The `"incomplete exit"` post-check has lost its ability to distinguish a sweep surplus from an under-delivering strategy, because the discriminator is deliberately discarded

- **Severity:** Low (defensive / future-strategy)
- **Contract:function:** `src/StableStakerV2.sol :: initiateMigration` (466–495)
- **Root cause class:** weakened tripwire / lost invariant discriminator
- **Confidence:** medium (conditional on a non-`AYieldStrategy` custody adapter)

The hypothesis "a partially-failed exit can now proceed silently where V1 aborted" is **REFUTED for
the current strategy family**, and the refutation should be recorded:
`AYieldStrategy._withdrawInternal` (lines 732–752) decrements `clientBalances` by the **requested
(capped)** amount, not by what `_disposeShares` delivered — "shortfall accrues as yield". So after
`_routeExit(token, P, false)` the client principal is always driven to `0` when the strategy was at
or below par, `booked == 0`, and V1's `require` never fired on a below-par exit either. V1's check
only ever fired on `clientBalances > P`, i.e. the idle-sweep surplus, which is protocol money by
construction (the sweep is gated on `totalStaked == 0`).

The residual is narrower but real. V2 discards `_routeExit`'s return value — the balance delta,
which is the *only* on-chain number that separates "booked is sweep surplus" (protocol money) from
"booked is principal the exit failed to deliver" (user money). Under any future custody adapter that
writes principal down by *received* rather than *requested*, `booked` is the user shortfall, the
self-heal relinquishes it, the post-check is satisfied by construction, `R` collapses to whatever
landed, and terminal migration proceeds with **no floor of any kind** on `R` — it will book an
arbitrarily small `R`, down to the B2 balance alone, and haircut every staker pro-rata with no
retry (V1 would have reverted and left the position intact and re-attemptable). The
`PrincipalDivergence` event records the number but gates nothing.

**Recommended mitigation:** keep the delta —
`uint256 received = _routeExit(token, P, false); require(booked == 0 || received + booked >= P, "StableStaker: exit shortfall");`
Combined with CODE-001's "withdraw before relinquish", this restores the tripwire without
reinstating the ss14m1 brick.

---

## Reconciliations, refutations and cleared checks (no new finding)

| Hypothesis | Outcome |
|---|---|
| **H3 — `R = min(balanceOf, P)` donation griefing** | **REFUTED.** A donation can only raise `R` toward `P`; credits are `Σ floor(p_i·min(R,P)/P) ≤ R ≤ balance`, so the idle pile always covers them. `rescueERC20` is unaffected: while `Migrating` the strategy is cleared so `reserved = totalStaked`, and in a below-par migration `bal < reserved` makes the require fail for *any* non-zero amount, blocking rescue outright. In pure idle-hold mode `balance ≥ totalStaked` always holds (`rescueERC20` fences it and staking credits 1:1), so `R == P` exactly as in V1. Donation strictly benefits users; **no unlock**. |
| **H2 — reentrancy / ordering around the self-heal** | **CLEARED.** `initiateMigration` is `nonReentrant`; the strategy's `deposit`/`withdraw`/`relinquishPrincipal` are each `nonReentrant` on their side; there is no ERC721/1155/777 hook, no `receive`/`fallback`, and the only re-entry surface is a malicious ERC20, excluded by the project's weird-token carve-out. `principalOf` cannot be manipulated *within* the transaction. Cross-transaction, any *other* authorized client of the strategy can inflate our `clientBalances` via `deposit(token, amt, staker)` (the `recipient` argument is arbitrary) — but the inflation is then relinquished, i.e. the griefer burns their own tokens for no effect. Cross-function and read-only reentrancy: the public views (`pendingReward`, `withdrawDisabled`, `userInfo`, `poolInfo`, `migrationInfo`) are not consumed as a price/oracle by any in-scope contract, and no in-scope integrator reads them mid-callback. |
| **H5 — `InPlaceMigrator.migrateIn` whole-balance approval** | **ALREADY LEDGERED — do not re-file.** Ledger `L-04 (qa, open) — "InPlaceMigrator.migrateIn dangling forceApprove(staker, balanceOf) contradicts the in-code comment"`. Still present verbatim at `migrateIn`; the in-source claim "no dangling allowance" remains false whenever a B3 surplus exceeds the consumed top-ups. Rated honestly: the allowance is to the **immutable** `staker`, whose only pull path is `depositFor`, itself `onlyMigrator` (i.e. this contract), so there is no third party who can draw it. QA is the correct rating; the false-exhaustiveness of the comment is the reason it should not be closed as "documented". |
| **H6 — `_routeExit` underwater par-payout (FCFS)** | **UNCHANGED and ALREADY LEDGERED.** Byte-identical in V1 and V2 (normalized diff shows no delta in `_routeExit`). Ledger: `medium, wont-fix — "Underwater withdraw buffer is FCFS at par, socializing strategy loss onto slow stakers"`. Not re-filed. |
| **ss14m1 / ledger `M-01 (medium, open)` — idle sweep bricks terminal migration** | **Impact fixed** by D3 on V2 (the brick is gone). **Root cause preserved:** `setYieldStrategy` still performs the unrecorded sweep, it is now merely logged (`ProtocolPrincipalSwept`). Propose `fixed` for the *brick* only, and note CODE-001 as a side effect the fix introduced. V1 remains bricked and unpatchable — off-chain `relinquishPrincipalAsOwner` runbook still required. |
| **ss14l8 / ledger `L-08 (low, open)` — buffer ignored in R** | **Fixed** by D4 on V2 — subject to CODE-001, which shows the fix does not reach buffer that was previously swept into the strategy. |
| **Findings against `src/versions/v1/StableStakerV1.sol`** | **NONE FILED.** Mechanically confirmed the normalized V1↔V2 diff contains only the six declared deltas (D1–D6) plus the frozen header and the two rename lines; storage layout is identical and neither contract is proxied, so no V1↔V2 storage-collision class exists. Every V1 defect is a **V1 re-raise** of already-ledgered deployed behaviour, deliberately preserved. Reconcile, do not action. |

## Reentrancy-class checklist (mandatory walk)

| Class | Result |
|---|---|
| Classic single-fn | Cleared — all value-moving externals `nonReentrant`; profile-verified. |
| Cross-contract (A→B→A) | Cleared — the only B is `AYieldStrategy`/`FlaxToken`, both first-party and `nonReentrant`/no-callback; neither calls back into the staker. |
| Cross-function (sibling state) | Cleared — OZ `ReentrancyGuard` is contract-wide, so the guarded set shares one lock. |
| Read-only | Cleared — no in-scope integrator reads staker views as a price/oracle; `withdrawDisabled` is the only view touching the strategy and is advisory. |
| ERC721 `onERC721Received` | N/A — no NFT surface. |
| ERC1155 receive hooks | N/A. |
| ERC777 `tokensReceived`/`tokensToSend` | Excluded by the project's standing weird-ERC20 carve-out; `_pullToken` measures a balance delta so accounting survives regardless. |
