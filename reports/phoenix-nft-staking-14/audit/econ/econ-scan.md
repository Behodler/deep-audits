# Economic / Design Scan — BatchNFTMinter nudge pot (story-015 `minReward`)

- **Project:** phoenix-nft-staking
- **Commit:** `9be4a87`
- **Contract:** `src/BatchNFTMinter.sol`
- **Scan type:** economic / mechanism-design (Tier 2)
- **Scan timestamp:** 2026-05-29T19:10:21Z
- **Scope:** single-contract economic review of the winner-take-all nudge pot and the story-015 `minReward` slippage guard, in the context of ledger finding **M-01 (pns13m1, ACKNOWLEDGED)**.
- **Inputs:** profile `reports/phoenix-nft-staking-14/audit/profiles/BatchNFTMinter.md` (trusted for verified local arithmetic / access-control properties); source read selectively (L227–294, L181–224 NatSpec) to confirm payout ordering and the floor-check semantics.

---

## Executive verdict on M-01

**M-01 status: PARTIALLY-MITIGATED — residual MEV finding remains open, severity drops High → Medium.**

`minReward` is a genuine and correct improvement: it converts a guaranteed-loss footgun (mint-and-pay for a reward already gone) into an atomic all-or-nothing. But it remediates only the *victim's wasted spend*, not the *root cause* M-01 was filed against — a public, balance-based, winner-take-all pot whose qualification gate (`count >= nudgeSize`) is observable in the mempool and therefore freely front-runnable. The MEV race the triage described still exists; the front-runner still wins the entire pot every time. The fix is the one the triage explicitly *recommended* and accepted, so M-01 should not be re-escalated, but it is **not "fixed"** — it is a documented, narrowed residual. The recommendation now should be a design change (per-claimer share / commit-reveal / pull-based accrual), not another slippage knob.

---

## Findings

### ECON-001 — `minReward` mitigates loser cost but does not resolve M-01's MEV race (residual)

- **id:** ECON-001
- **type:** mev / mechanism-design / mitigation-scope
- **severity:** potential-medium
- **contract:** src/BatchNFTMinter.sol
- **function:** batchMint
- **line:** 270
- **lineStart:** 268
- **lineEnd:** 285
- **confidence:** high

**Description.** The nudge reward is `nudgeAmount = IERC20(nudgeToken).balanceOf(address(this))` (L271) — the *entire* live pot, paid to the first batch in which `count >= nudgeSize`. `minReward` (L278–280) reverts a batch when the deliverable amount is below the caller's declared floor, but it does nothing to the winner-take-all structure or to the public, mempool-visible qualification gate. The economically rational play is unchanged from pre-fix: a searcher watches for the pot to be funded (a yield-funnel transfer into the contract is an on-chain event), and front-runs any qualifying `batchMint` with their own qualifying `batchMint` at higher priority fee, sweeping the full pot.

**Economic impact.** 100% of each pot funding accrues to whichever actor wins the gas/priority auction, not to the user the incentive was meant to "nudge." The intended incentive — reward genuine large minters — is captured by MEV searchers who pay for `nudgeSize` real mints only when the pot value exceeds (mint cost + gas + priority bid). Because the pot is the full balance and is observable, the searcher's expected value is positive whenever `pot > nudgeSize * mintPrice + gas`, and they can size the priority bid up to (`pot - costs`), extracting nearly the whole surplus from honest participants.

**Attack scenario.**
1. Yield funnel transfers USDC into BatchNFTMinter; pot balance is now public.
2. Honest user submits `batchMint(count = nudgeSize, recipient = self, paymentAmount, minReward = pot)`.
3. Searcher sees it in the mempool, copies it with a higher priority fee (and/or backruns the funding tx directly).
4. Searcher's tx lands first, drains the full pot via the L283 `safeTransfer`.
5. Honest user's tx now reads `nudgeAmount = 0 < minReward` and reverts (L278) — they correctly pay nothing, but they also never receive the reward.

**Why this is the residual, not a new bug.** This is exactly the harm M-01 described. `minReward` was the triage's accepted remedy and it does what it claimed (the dev's NatSpec L220–224 is explicit: it "does NOT stop a front-runner from winning the pot"). So the *victim-overpay* leg of M-01 is closed; the *MEV-capture-of-the-pot* leg is not. The fix **shifts** harm (loser no longer overpays) rather than **eliminating** it (pot is still 100% MEV-capturable).

**Profitability.** Profitable for the searcher whenever `pot > nudgeSize * currentMintPrice + gas`. Since the pot is winner-take-all and the searcher mints real NFTs (which they keep / can resell), the marginal cost is often well below the pot, so the race is reliably profitable while the feature is funded.

**affectedParties:** legitimate large minters (the intended "nudged" actors) — they receive 0% of the pot; protocol intent (incentive is captured by searchers rather than steering behavior).

**Recommendation (design-level, supersedes "add another knob").** A slippage floor cannot fix a winner-take-all race because the value is binary and fully visible. Options, in rough order of robustness: (a) make the reward *per-qualifying-mint accrual* claimable pull-style rather than full-balance to first caller, so there is no single sweepable jackpot; (b) cap the per-call payout to a fixed `nudgeReward` amount instead of `balanceOf`, so the pot can serve many claimers and the EV of sniping any single claim collapses; (c) commit-reveal or batched/auction settlement of the nudge. At minimum, document M-01 as a *known, accepted MEV exposure* with the `balanceOf`-payout rationale, since the current code does not match the "resolved" framing.

---

### ECON-002 — `minReward == 0` default silently opts out of the M-01 fix

- **id:** ECON-002
- **type:** footgun / spec-deviation
- **severity:** potential-low
- **contract:** src/BatchNFTMinter.sol
- **function:** batchMint
- **line:** 278
- **lineStart:** 277
- **lineEnd:** 280
- **confidence:** high

**Description.** The floor check `if (nudgeAmount < minReward)` never trips when `minReward == 0` (the backward-compatible default). A caller — or an integrating UI that forgets to populate the parameter — who passes `0` gets **exactly the pre-fix behavior**: they mint and pay even if the pot was already drained, receiving `nudgeAmount == 0`. The protection is opt-in and the safe default (`minReward = expected pot`) is the caller's responsibility, with no on-chain nudge toward it.

**Economic impact.** Any integrator that does not wire `minReward` to the live pot size re-exposes the original M-01 victim-overpay harm in full. This is the most likely real-world failure mode of the fix: the guard exists but is bypassed by the default value.

**affectedParties:** users routed through an integration that defaults `minReward` to `0`.

**Recommendation.** Off-chain callers MUST default `minReward` to the expected pot balance, not `0`. Consider documenting prominently that `minReward == 0` opts out of M-01 protection. (A stricter on-chain option: when the nudge feature is active and `count >= nudgeSize`, require `minReward > 0` — but this breaks the documented backward-compatible path, so it is a product decision.)

---

### ECON-003 — Forced-revert guard does not create a permanent denial-of-reward / lock

- **id:** ECON-003
- **type:** liveness / griefing (negative result)
- **severity:** informational
- **contract:** src/BatchNFTMinter.sol
- **function:** batchMint
- **line:** 278
- **lineStart:** 268
- **lineEnd:** 285
- **confidence:** high

**Description.** I checked whether `minReward` reverts can be weaponized into a state where the pot becomes permanently unclaimable, or where an attacker keeps it locked indefinitely. They cannot, for the following reasons:

- The revert is purely a function of the *caller's own* declared `minReward` vs the *live* `balanceOf`. It carries no persisted state (the contract holds no per-user accounting — confirmed in profile §3). One caller's revert cannot poison another caller's call.
- A revert rolls back atomically; it does not consume or move the pot. The pot remains exactly where it was for the next caller.
- There is no way for an attacker to force *other* users' `minReward` to a value that always exceeds the pot — `minReward` is each caller's own argument. An attacker can only make *their own* call revert.
- A funded pot is always claimable by submitting `count >= nudgeSize` with `minReward <= pot` (e.g. `minReward = 0` always succeeds in claiming whatever is present). So the pot can never be bricked by the floor mechanic.

**Interaction with `rescueERC20`.** `rescueERC20` (L175) is `onlyOwner` and can move the nudge token out at any time, including while paused. This is the intended escape hatch (profile §8, trust assumption 4) and a documented centralization acceptance, not a griefing vector: only the trusted owner can invoke it, and the owner can already redirect the pot via the nudge setters. It does, however, mean the "reward" any honest caller declares via `minReward` can be rug-pulled between the user signing and the tx landing if the owner front-runs with a rescue — but `minReward` correctly protects the user here too (their batch reverts, they pay nothing). So `rescueERC20` does not weaken the `minReward` guarantee; it is covered by the same floor check.

**Conclusion.** No new permanent-lock or denial-of-reward vulnerability is introduced by the fix. This finding is recorded as a *negative result* so the question raised in the brief is explicitly closed.

---

### ECON-004 — No-callback confirmation for the value-out path (defers to profile LOCAL-002)

- **id:** ECON-004
- **type:** reentrancy-surface (economic relevance)
- **severity:** informational
- **contract:** src/BatchNFTMinter.sol
- **function:** batchMint
- **line:** 282
- **lineStart:** 282
- **lineEnd:** 293
- **confidence:** medium

**Description.** Economically, the only double-spend worth checking is whether the full-balance nudge payout (L283) and balance-driven dust sweep (L287–289) can be re-entered to drain the pot twice from a single funding. They cannot under the project's standard-ERC20 trust assumption: the payout and sweep are both `balanceOf`-driven and read fresh, so the *first* `safeTransfer` zeroes the pot and any re-entrant qualifying batch reads `nudgeAmount == 0` (reverting if `minReward > 0`, paying `0` otherwise). No double-spend of one pot funding results. The only callback edge is a non-standard ERC-777-style nudge/payment token handing control to `recipient` — out of scope per the project's known-invalid token list. This restates profile LOCAL-002; no separate economic exploit is established. Adding OZ `ReentrancyGuard` remains cheap defense-in-depth.

---

## Residual risk assessment for M-01

| Dimension | Pre-fix (M-01 as filed) | Post-fix (story-015) |
|---|---|---|
| Loser pays mint cost for a sniped reward | Yes (guaranteed loss) | **No** — atomic revert when `minReward` set |
| Front-runner wins the entire pot | Yes | **Yes (unchanged)** |
| Pot is mempool-visible winner-take-all jackpot | Yes | **Yes (unchanged)** |
| Intended "nudged" user receives the reward | Only if not front-run | Only if not front-run |
| Protection requires correct caller input | n/a | **Yes** — `minReward == 0` opts out |

**Severity of residual:** **Medium.** No assets are stolen from the protocol or from a user *who sets `minReward`* — the victim-overpay vector (the part that was closest to a direct user loss) is closed. What remains is value *leakage of the incentive budget to MEV* and a *protocol-intent mismatch* (the nudge does not reliably steer the behavior it pays for). That is squarely C4 Medium territory (protocol function/value-leak under stated external conditions, no direct theft from a protected user), down from the original High framing. The `minReward == 0` opt-out (ECON-002) is Low. No High residual: there is no permissionless path that *steals* a protected user's funds — the front-runner spends real money to mint real NFTs and the loser is made whole by the revert.

**Recommended ledger action:** keep M-01 (pns13m1) **open as residual / partially-mitigated** rather than `fixed`, re-tagged as a Medium MEV/incentive-capture finding, with a pointer to ECON-001's design-level recommendation. The triage's accepted remedy (`minReward`) is implemented correctly, so this is not a regression — it is the explicitly-narrowed remainder. ECON-002 should be filed as a Low integration footgun.

---

## Notes / assumptions

- Trusted from profile (not re-verified): checked arithmetic, dust-threshold math benign, access control on setters, `tokenMinter`/`dispatcher` owner-pinned & trusted, standard-ERC20 token assumption.
- Economic analysis assumes the pot is funded in discrete, observable transfers (yield funnel) — the stated funding model. If funding were continuous/streamed the jackpot framing softens slightly but the winner-take-all sweep still captures the accumulated balance at claim time.
- No PoC required for a residual MEV/incentive-design finding; the mechanism is established directly from the payout ordering. If escalated for submission, a Foundry PoC demonstrating front-run capture (two `batchMint` calls in one block, second reverts on `minReward`) is straightforward to add.
