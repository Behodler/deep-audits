# Plan of Action — Full YS-swap Decommission + phUSD Minter Replacement

**For:** story-planner agent (phoenix-phase-2-staging). Last story = `story-064`; new work starts at `story-065`.
**Goal:** Complete the story-060 YS-swap migration into a *full decommission*: move every client off the old `ERC4626YieldStrategy` DOLA/USDC builds (`0x90ce…7F9` / `0x90af…470`), redeploy the phUSD minter onto the V2 strategies, make the **minter the shortfall shock-absorber** so StableStaker users are always made whole, and brick the old strategies so any later interaction reverts.
**Audit context:** run-13 (`reports/phoenix-phase-2-staging-13/`), submodule HEAD `e935a05`. This plan supersedes the broken/unwired `script/PhusdMinterRepoint.s.sol` (run-13 finding YS-20 `6fd3eddc`) — the redeploy path makes that script obsolete; delete it.

---

## 0. Hard invariant — NEVER revoke or renounce ownership

No story in this plan revokes, renounces, or transfers **ownership** of any contract. The owner must retain full control of every contract throughout — including the **dead** old strategies (so residual can still be swept and the owner stays the admin of an inert contract). The "revokes" in this plan are strictly **narrower role grants** — `mintAuthority`, `client` (`setClient(false)`), and `authorizedWithdrawer` — never `owner`. Concretely: no `renounceOwnership()`, no `transferOwnership()` away from the owner, no `Ownable`/`Ownable2Step` owner change anywhere. The "kill" in §E is achieved by zeroing balances + removing client/withdrawer roles + an optional pause flag, all while **ownership stays with the current owner**.

## A. The master ordering (the safety crux — cross-cuts all stories)

The old strategy is **below par** (over-credit bug overstated booked principal vs realizable assets). Ordering decides who eats the shortfall. Per owner decision: **StableStaker users must withdraw whole; the parked phUSD-minter TVL absorbs the hit.** Execute in exactly this order:

1. **Unblock** — grant owner `authorizedWithdrawer` on the 3 old strategies; fix gather off-by-one; add staker pause break-glass (§F fold-ins). Without these the suite cannot run.
2. **Stand up the V2 minter** — deploy new minter, register both stablecoins → V2 strategies, set caps, grant phUSD mint authority. (Does not move funds yet.)
3. **Cut new mint flow over** — repoint every caller of the old minter to the new minter; **revoke the old minter's mint authority + client status** so no new collateral lands in old strategies.
4. **Compute the shortfall and pre-fund the staker from the minter** — before the staker migration finalizes, measure `shortfall = staker_booked_principal − staker_realizable_assets` on the old strategies, withdraw that amount from the **minter's** old-strategy allotment, and inject it so the staker realizes **full** principal (zero pro-rata haircut to staker users).
5. **Migrate the staker** (existing 5 wired scripts) — now realizes whole because of the pre-fund.
6. **Evacuate + re-seed the minter** — `withdrawAsOwner` the minter's *remaining* old-strategy position and `noMintDeposit` it into the new minter's V2 position. New position = `minter_booked − shortfall − dust` (the accepted minter haircut). Log below-par transparently; do **not** revert on below-par.
7. **SYA deregister old strategies** (§C).
8. **Final residual sweep + kill old strategies** (§E) — sweep residual to treasury, log it, then disable.

> **Why pre-fund (step 4) instead of changing socialization logic:** topping up the strategy's assets before `finalizeAndReset` makes the existing pro-rata `(R,P)` snapshot see no shortfall, so staker users get full principal **without a stable-staker contract change**. The minter is the explicit source of the top-up. If a script-level injection point into the strategy/migration is not reachable, the fallback is a stable-staker code change to route shortfall to a designated absorber address — flag which one is feasible (see §G open question 4).

---

## B. story-065 — Minter as shortfall shock-absorber in the YS-swap migration
**Intent:** StableStaker depositors are user funds and must always be withdrawable at full booked principal; the phUSD minter is parked TVL and may take a haircut. Re-shape the migration so any below-par shortfall on the old strategies is routed to the minter, never socialized onto staker users.
**Requirements:**
- In the skim/leg-1 stage, compute `stakerShortfall` per token = staker booked principal − realizable assets (`convertToAssets`) on the old strategy.
- Withdraw `stakerShortfall` from the minter's allotment in the old strategy (owner is authorized withdrawer) and inject it into the staker's strategy/migration **before** `finalizeAndReset` snapshots `(R,P)` (reuse the suite's existing skim/donation injection vector if possible).
- If `stakerShortfall > minter_total_allotment` (minter can't cover it): **hard revert** with a clear message — do not silently socialize onto staker users; this is an operator-escalation condition.
**Acceptance:** on a mainnet fork, after migration a migrated staker withdraws **100%** of booked principal (no haircut); the minter's re-seeded V2 position equals its booked principal minus the contributed shortfall and dust; an assertion proves `staker_realized == staker_booked`.

## C. story-066 — Deploy & cut over a new phUSD minter onto V2
**Intent:** Replace the live 4-field minter (`0x435B…77E5`) — which is ABI-incompatible with the current scripts (YS-20) — with a fresh `PhusdStableMinter` (source `d6ed115`) wired to the V2 strategies from birth.
**Requirements:**
- Deploy a new `PhusdStableMinter` (d6ed115 / latest).
- `setClient(newMinter, true)` on `ysDolaV2` and `ysUsdcV2`; `registerStablecoin(DOLA → ysDolaV2, rate, 18)` and `registerStablecoin(USDC → ysUsdcV2, rate, 6)`; `approveYS` for each.
- **`setMaxMintPerDay = 4000` for each token** — confirm denomination/decimals before encoding (§G open question 1).
- Grant the new minter **phUSD mint authority** on the phUSD token; **revoke** mint authority + client status from the **old** minter so it can no longer mint or deposit.
- Enumerate and repoint **every** reference to the old minter address (front-end config, on-chain callers, addresses files) → new minter (§G open question 2).
**Acceptance:** new minter mints phUSD backed by V2; daily cap enforced at 4000/token; old minter `mint()` reverts (mint authority revoked); no caller still points at the old minter.

## D. story-067 — SYA deregister old strategies
**Intent:** story-061 wired SYA to V2 but *left* the old `YS_DOLA`/`YS_USDC` registrations ("deferred to YS-12"). Remove them so SYA references only V2.
**Requirements:**
- Call SYA's deregister/remove path for the old DOLA/USDC strategies (`setWithdrawer(old, false)` + the remove-yield-strategy function — confirm the exact selector, §G open question 3).
- Post-assert: `SYA.getYieldStrategies()` contains **only** the V2 strategies for DOLA/USDC; `YS_USDE` handling unchanged.
**Acceptance:** fork check shows old strategies absent from SYA; SYA yield reads/claims succeed against V2 only.

## E. story-068 — Decommission (kill) the old strategies
**Intent:** Make the 3 old strategy contracts inert so any state-changing interaction hereafter reverts, after preserving residual.
**Requirements (in order):**
1. **Final residual sweep:** `redeem`/withdraw the entire remaining underlying to treasury; **log the swept residual amount per token** (this is the value the owner will inspect as a follow-up — see "residual" note at top of plan).
2. **Deregister from every client:** remove the old strategies as a client/strategy on StableStaker, SYA, old minter, new minter — anything that routes to them.
3. **Revoke all `authorizedWithdrawer`s.**
4. **Disable hard if a flag exists:** if `ERC4626YieldStrategy`/`AYieldStrategy` has a pause/disable/kill function, set it so external mutating calls revert (§G open question 5). If no such flag exists, document that the achievable guarantee is "all client-gated and withdrawer-gated functions revert with `unauthorized`, balances zeroed" and verify the modifier coverage on every external mutating function. **Do NOT `renounceOwnership()`** — the owner remains admin of the inert contract (per §0).
**Acceptance:** post-kill, deposit/withdraw/skim on each old strategy reverts; balances are zero; residual swept and logged; a PoC shows a representative interaction reverting.

## F. story-069 — package.json entry points + cleanup
**Intent:** Wire the new operations as proper entry points per the suite convention and remove the obsolete script.
**Requirements:**
- Add `migrate:phusd-minter-replace` (+ `:preview`) and `migrate:ys-old-strategy-decommission` (+ `:preview`) following the **`<key>-preview && <broadcast>`** hard-gate convention, **no `--skip-simulation`**, no unwired scripts.
- Delete `script/PhusdMinterRepoint.s.sol` (obsoleted by story-066) so it can't be hand-broadcast (closes YS-20 / YS-23).
- Document the full ordered runbook (§A) in `package.json`'s `//ys-swap-migration` comment block.
**Acceptance:** every new script is preview-gated; `grep` finds no `--skip-simulation` and no committed-but-unwired `script/*.s.sol`.

---

## F. Existing open run-13 findings to FOLD IN (the fix is incomplete without these)
These are hard prerequisites or same-blast-radius hygiene — do not ship the decommission while they're open:
- **YS-02 `106d5c6e` (leg1 DOA):** owner is not an `authorizedWithdrawer` on the 3 **old** strategies → `skimSurplus` reverts. Grant it in a preflight (also required for §A step 4 and §E). Make the leg-1 preflight assert **withdrawer status**, not just `owner()`.
- **YS-04 `8168c808` (gather off-by-one):** `scripts/gather-migration-inputs.js` uses an inclusive end against the half-open `getStakersRange` → drops the last staker per page → preflight DoS. Fix the range math before any run.
- **YS-21 `be9a5a92` (live-staker pause, no break-glass):** the suite contract-globally pauses the **live** staker (freezing the unrelated USDe pool). Add a **standalone unpause/break-glass** script so a mid-suite halt doesn't strand live users.
- **YS-22 `10fac478` (pauser-restore catch-path):** cleanup's JSON catch-path leaves the deployer EOA as pauser. Fix the restore to fail loud on missing state rather than warn-and-skip.

---

## G. Open questions the planner/implementer MUST resolve on-chain/source (don't assume)
1. **maxMintPerDay denomination & decimals** — is the cap in stablecoin units or phUSD, and what decimals (DOLA 18, USDC 6)? Encode `4000` accordingly.
2. **Old-minter reference set** — who calls the old minter to mint phUSD (front-end, mint authority contract, other modules)? All must be repointed before revoking the old minter.
3. **SYA deregister selector** — confirm SYA exposes a remove-yield-strategy function (counterpart to `addYieldStrategy`) and its exact signature.
4. **Shortfall injection vector** — confirm a script-level way to inject assets into the staker's strategy/migration before `finalizeAndReset` (skim/donation path). If none, story-065 needs a stable-staker code change instead — flag scope.
5. **Old-strategy kill mechanism** — does `ERC4626YieldStrategy`/`AYieldStrategy` have a pause/disable/kill flag? If not, confirm every external mutating function is client- or withdrawer-gated so deregistration achieves "reverts hereafter."
6. **Shared-pool topology** — do the old minter and staker deposit into the *same* old strategy instance (commingled shares) or separate instances? This determines whether §A step 4's pre-fund is necessary at all (separate instances ⇒ no cross-contamination ⇒ shortfall logic simplifies).

---

## H. Suggested story sequence for the planner
`story-065` (shock-absorber) → `story-066` (new minter) → `story-067` (SYA deregister) → `story-068` (kill) → `story-069` (entry points + cleanup), with the §F fold-ins attached to whichever story touches that script (YS-02→leg1, YS-04→gather, YS-21/22→deploy+cleanup). Each story should state intent, declared pre/post-conditions, and a fork-based acceptance test, consistent with the existing story-060…064 style.
