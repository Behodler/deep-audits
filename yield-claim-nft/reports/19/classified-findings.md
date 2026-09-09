# Classified Findings — yield-claim-nft run-19

- **Project:** `yield-claim-nft` @ `d4cc563` (stories 046 / 047)
- **Stage:** severity classification (C4 criteria) — input: `sanitized-findings.md/.json` (11 survivors), `tier3/invariants.md`, `consolidated-findings.md`
- **Machine-readable:** `classified-findings.json`
- **No ledger write performed.** Labels below are classification output; `finding-manager` applies them.

## Counts

| | |
|---|---|
| Classified | **11** |
| High | **1** (plausible) |
| Medium | **3** |
| Low | **5** |
| QA | **2** |
| Centralization (`C-XX`) | **0** |
| Regressions | **0** |
| Incomplete fixes | **0** |
| Expired closures | **1** (CLASS-19-02 → L-08) |
| Owner footguns (Law-3 in-scope) | **3** |
| Faithfulness-tagged (→ spec-conformance) | **3** |
| Shadow classification (suppressed, proposal only) | **1** (DEDUP-19-04 → L-13) |

### ⚠ Label collision warning

The ledger already carries `M-01`–`M-04`, `L-01`–`L-15`, `Q-01`–`Q-17`, `C-01`, `F-*`. Each finding therefore carries **two** labels:

- **`c4Label`** — run-scoped C4 submission label (`H-01`, `M-01`, …), required by the C4 output spec.
- **`ledgerLabel`** — the continuing per-project sequence, to be used on the ledger upsert.

Run-scoped `M-01/M-02/M-03` are **not** the ledger's `M-01/M-02/M-03` (migrate() gas DoS, late-dispatcher brick, decimal under-mint — all `fixed`). Run-scoped `H-01` is also not the run-02 report's `H-01/H-02` (KI-7). **`finding-manager` must upsert under `ledgerLabel`, never `c4Label`.**

---

## Severity table

| c4 | ledger | id | Finding | Severity | Plaus. | Evidence | Doubt |
|---|---|---|---|---|---|---|---|
| **H-01** | H-01 | DEDUP-19-01 | Nudge/payment token collision — whole pot swept by any `batchMint` caller | **High** | **Plausible** | T3 PoC + control | ⚠ H vs M |
| **M-01** | M-05 | DEDUP-19-03 | `NudgeRatchetDelayRelease.release()` lump 100% back-runnable | **Medium** | — | T3 PoC + contrast | ⚠ M vs H |
| **M-02** | L-08 (reopen, ↑Low→Med) | DEDUP-19-02 | Mandatory-streamer wedge + unreachable resident USDC (**expired closure**) | **Medium** | — | T3 PoC + pos. control | — |
| **M-03** | M-06 | DEDUP-19-05 | Stream retirement strands one duration's donations (footgun) | **Medium** | — | T3 sized | ⚠ M vs L |
| **L-01** | L-16 | DEDUP-19-06 | Repoint silently arms `NudgeStreamer__NotRegistered` (footgun) | **Low** | — | T3 selector match | ⚠ L vs M |
| **L-02** | L-17 | DEDUP-19-07 | Donation-disable strands parked USDS; live `psm.gem()` read (footgun) | **Low** | — | T2 | mild |
| **L-03** | L-18 | DEDUP-19-08 | Dust branch went event-silent as `DonationSkipped` became sole signal | **Low** | — | T2 | — |
| **L-04** | L-19 | DEDUP-19-09 | `Uniboost` prime token unconstrained, no failure isolation | **Low** | — | T2 | — |
| **L-05** | L-20 | DEDUP-19-10 | Burns against the leg output, pools against the whole balance | **Low** | — | T2 | mild |
| **Q-01** | Q-18 | DEDUP-19-11 | Streamer `forceApprove` is the sole unpaired approval | **QA** | — | refuted (R-03) | — |
| **Q-02** | Q-17 (note expansion) | DEDUP-19-12 | Whole test tree failed to compile ⇒ zero regression coverage | **QA** | — | `forge build` fail | mild |
| *(shadow)* | *L-13 `wont-fix`* | DEDUP-19-04 | `_legB` whole-balance ETH swap dilutes the slippage floor 11× | **Medium (shadow)** | — | T3 fork PoC | ⚠ M vs L |

---

## H-01 · DEDUP-19-01 — **High, Plausible**

`lib/phoenix-nft-staking/.../BatchNFTMinterMultiToken.sol:_snapshotRewards:558` + `batchMint:479-486` · first-party contribution: `NudgeRatchet` / `Uniboost` / `PromotionUniV2_Eth`
Fingerprint `d06e3191…` · **footgun: true** · **not centralization** · **regression: false**

**Asset impact.** The entire standing nudge pot — real USDC donated by prior minters — leaves to an unprivileged caller. Measured: **190.0 of a 200 USDC pot** in one call, plus another **100 USDC** on refill. Extraction is exactly `pot − mintPrice`, bounded above by nothing.

**Attack path.**
1. *Precondition (owner, non-malicious, one routine tx):* `setDispatcherIndex(i)` selects a USDC-prime dispatcher, so `_resolvePaymentPath` derives USDC as the payment token while USDC remains on the nudge whitelist. **Three of four in-scope dispatchers are USDC-prime**, so the hazardous selection is the majority choice.
2. Honest minters fund the stream; a window elapses; the flush lands the pot on the batch-minter.
3. **Any address** calls `batchMint(count = 1, recipient = self, paymentAmount = 1 wei, [0])` — no role, no allowlist, no budget.
4. `count(1) < nudgeSize(5)` ⇒ `qualifies == false` ⇒ `_payRewards` never runs, snapshot all zero.
5. Value leaves through the **step-10 dust sweep, which is not gated on `qualifies`**.
6. The mint is funded **out of the pot itself** (step-6 unbounded allowance), so the 1 wei is nominal and the NFT is a bonus.
7. Repeatable on every refill.

**Likelihood.** The exploit step has *zero* preconditions and is PoC'd (`Run19_T1_PaymentTokenCollision`, 4/4, control arm extracts **0** before the repoint). The **precondition** is honestly moderate: the live config at `d4cc563` does **not** resolve payment to USDC (the batch path prices in an 18-dp PAY token, per T4), so this is **not exploitable at the current on-chain configuration**. It needs one deliberate, ordinary owner tx. What makes it real rather than hypothetical: `setDispatcherIndex` is a designed routine mutator; three of four dispatchers are USDC-prime; and **nothing warns** — no guard rejects `paymentToken ∈ nudgeWhitelist`, no event, no view.

**Why High.** The C4 High bar is *"assets can be stolen … via a valid attack path that does not have hand-wavy hypotheticals."* The attack path contains **no** hypotheticals; only its enabling configuration is conditional, and that condition is a single routine owner action whose consequence is invisible. Per **Law 3**, a *non-obvious* owner footgun is classified by the impact it unlocks — up to High for direct asset loss — and per the sanitizer this is **not** a centralization finding, because the value is taken by an **unprivileged third party**, not by the owner. Plausibility is **Plausible**, not Implausible: no validator collusion, no black swan, no price manipulation.

> ⚠ **Genuine doubt: High vs Medium.** Medium is arguable — a value leak with a stated assumption plus an external requirement (the owner repoint) is literally the C4 Medium wording, and the configuration is not live today. Resolved to **High** because the loss is total, repeatable, taken by an unprivileged party, funded by other users' money, and completely unsignalled. Under Law 1, understating a PoC'd permissionless total-drain to keep the report tidy is the wrong error. **Collapse condition:** add an on-chain guard rejecting `paymentToken ∈ nudgeWhitelist`, or gate the step-10 dust sweep on `qualifies` — the guard is both the fix and the severity collapse.

**Scope caveat (carry verbatim on the entry).** Root-cause lines sit in the project's own nested `lib/phoenix-nft-staking`. Kept live under **Law 1** as an integration hazard against the first-party dispatchers, and **mirrored upstream under XP-01 using the same fingerprint**. It must remain live on at least one ledger at all times.

---

## M-01 · DEDUP-19-03 — **Medium** (top of band)

`src/dispatchers/NudgeRatchetDelayRelease.sol:release:107-110` · fingerprint `e6fbf0d6…` · **faithfulness: true → F-03-046**

**Asset impact.** The entire released lump is diverted from the honest-batcher population to one searcher. Measured: **50,000 USDC captured 100% in the same block** for a cost of 5 mint prices; the next honest batcher pays the same 5 mint costs and receives **0**.

**Attack path.** `release()` transfers the lump **directly** to the batch-minter, bypassing the `NudgeStreamer`. It is `onlyReleaser` but mempool-visible. A searcher back-runs it in the **same block** with `batchMint(count = 5, minRewards = [lump])` — the floor set to the whole lump makes the capture risk-free (take everything, or revert and pay only gas). Pot emptied: `balanceOf(searcher) == LUMP`, `balanceOf(batch) == 0`.

**Likelihood: high.** No owner error, no misconfiguration, no unusual market state. The **contrast arm** proves the exposure is path-specific: the same 50,000 USDC routed through the streamer by `NudgeRatchet` yields the same-block back-runner **exactly 0**, with ≥ `LUMP−1` still buffered.

**Why Medium, not High.** No assets are stolen in the C4 High sense: the captor performs the paid action the contract is designed to reward and receives it through the **intended payout path** — no accounting break, no unauthorized withdrawal. What is impaired is the protocol's **stated function**: four contracts' NatSpec advertise the anti-burst property as system-wide, and this path defeats it, leaking the full value of every release to whoever wins one block race. That is a value leak with stated assumptions and an external requirement (a searcher) — the C4 Medium definition.

> ⚠ **Genuine doubt: Medium vs High.** High is arguable (100% of a 50,000 USDC lump, PoC'd, no preconditions, honest users get 0). Held at Medium because the recipient is a legitimate participant paying the required mint cost through the sanctioned reward path — mis-distribution of an incentive, not theft of custodied assets. It rises to High if the released lump is shown to be **user-attributed** rather than protocol-discretionary value.

**Do not collapse** into `phoenix-nft-staking` `858e9e80` (same MEV class, different contract, repo and fingerprint) — XP-02.

---

## M-02 · DEDUP-19-02 — **Medium** · ⚠ **EXPIRED CLOSURE of L-08** (not a regression, not an incomplete fix)

`src/dispatchers/NudgeRatchet.sol:_dispatch:156-161` · reconciles to **L-08 `0b97f155…`** (`fixed`) · contingency fingerprint `03864c76…`

**Asset impact — two halves.**
1. **Availability:** while the streamer path is broken, **every user mint at that index reverts**. `NudgeRatchet` is the only one of five donors with no try/catch, no `donationSplit`, and a `batchMinter` that cannot be zeroed — there is no degraded mode.
2. **Stranded value:** resident USDC is unreachable by **any** actor. An owner raw call to `rescueERC20(address,address,uint256)` returns `false` (selector absent); the **positive control** on a freshly deployed `NudgeRatchetDelayRelease` returns `true`; the only forwarding path is the reverting one. `test_T2d` goes further: a USDC blacklist on the **shared** streamer bricks `NudgeRatchet` *and* `Uniboost` **and permanently strands the already-buffered pooled funds** (`pullPendingStream` reverts on `_settle`'s outbound transfer; `NudgeStreamer` has no owner rescue at all — XP-05).

**Triggers.** (A) `nudgeStreamer == address(0)`, the post-deploy default ⇒ `Error("NudgeRatchet: nudgeStreamer unset")`. (B) `(batchMinter, USDC)` unregistered ⇒ `NudgeStreamer__NotRegistered()`, selector-matched. (C) **third party, no privileges:** USDC blacklists the shared streamer — external, uncontrollable, and uniquely **irreversible**.

**Why Medium.** Assets are not stolen, but availability is impaired outright and value is stranded with no escape hatch for anyone — squarely the C4 Medium wording. Not High: the dominant triggers are recoverable configuration states rather than an attacker-controlled path, and no third party gains what the protocol loses.

**Severity is raised, not inherited.** An expired closure normally inherits at least its prior severity (L-08 was **Low**). The behaviour classified on its merits at `d4cc563` is materially worse than what L-08 described — a total availability wedge plus a third-party-triggerable irreversible strand of the **pooled** buffer — so it is classified **Medium**.

> ⚠ **DO NOT tell any reviewer to restore the sweep — it is already there.** The story-038 patch is **intact** at `src/dispatchers/NudgeRatchet.sol:142-162`. What expired is the *rationale*: L-08 was closed explicitly *"on whether out-of-band USDC becomes recoverable, NOT on literal `rescueERC20` presence"*, and story-046 turned the sweep's only delivery leg into an external cross-repo call that can revert. The remedy is a **new** escape hatch, and/or a donation-disable so a mis-wire degrades instead of bricking.

**Contingency.** If the human **declines** the L-08 reopen, the *wedge* half must still be filed as a new entry — fingerprint `03864c76…`, basis `NudgeRatchet.sol:_dispatch:mandatory-streamer-liveness-wedge` — **at Medium**. Declining the reopen must not erase both halves.

**Author pre-declaration.** The NatSpec pre-declares the wedge *"NOT an audit finding"*. Per Law 1 an author's say-so does not auto-suppress; the declaration covers the deliberate liveness coupling, not the second-order consequence (escape hatch omitted on a rationale that no longer holds), which is the load-bearing half.

---

## M-03 · DEDUP-19-05 — **Medium** (owner footgun / operational hazard)

All four dispatchers' `setBatchMinter` / `setRecipient` / `setNudgeStreamer` · fingerprint `25a9ab3e…` · **footgun: true**

**Asset impact.** One stream duration's donated USDC — `B* = ρ·D`, cadence-independent — becomes **permanently** unreachable. Measured range at the observed ~77.6 USDC per 40-batch: **11 → 4,656 USDC** across the `D` × cadence grid. `NudgeStreamer` has **no owner rescue or sweep** (verified exhaustively against its complete function list).

**Sequence (no attacker — this is owner sequencing).** Retiring a stream stops the donor-side `collectNudge` path immediately. The only other exit is the old batchMinter calling `pullPendingStream`, which `BatchNFTMinterMultiToken` does in exactly one place, inside `batchMint`, and which requires **all** of: not paused · `tokenMinter != 0` · `dispatcherIndex != 0` · token still whitelisted · someone paying for ≥1 real mint. Any **one** of four ordinary decommissioning actions — `pause()`, `setTokenMinter(0)`, `setDispatcherIndex(0)`, unwhitelisting — destroys it forever (`_resolvePaymentPath` runs at step 2, **before** the step-3.5 flush).

**Likelihood: medium-to-high at the next migration**, and this is decisive: the project's **existing `MigrateBatchNFTMinter.s.sol`** retirement step recovers the pot via `balanceOf(oldBatchMinter)` — **structurally blind to the streamer buffer**, and it predates the streamer. An operator following the repo's own script trips this. Nothing surfaces the buffer: no event at retirement, no dispatcher view, and the only read is `pendingStream(oldBatchMinter, token)`, which a migration operator has no reason to call.

**Why Medium.** A Law-3 operational hazard classified by the impact it unlocks: value is **permanently lost** (not stolen), bounded but non-dust, and the triggering sequence is the one the repo's own script already performs. Not High — no attacker, no theft, and correct-ordered recovery is cheap (wait ≥ `D`, one `batchMint(1)` flushes the whole buffer, then `rescueERC20`; ~13 USDS plus gas). Not Low — the harm is irreversible once the decommissioning tx lands and there is no signal at the decision point, i.e. a competent, non-malicious owner **would be surprised**, which is exactly the Law-3 keep test.

> ⚠ **Genuine doubt: Medium vs Low — parameter-dependent.** At the bottom of the grid the exposure is ~11 USDC (dust ⇒ Low/QA ops note); at the top it is ~4,656 USDC. The deciding parameter, the live stream `duration`, is **unknown in every reviewed repo (MR-01)**. Supply the live `duration` + batch cadence and this can be re-pinned without re-analysis.

**Safe-config guidance (belongs in the dispatchers' ops NatSpec *and* in `MigrateBatchNFTMinter.s.sol`).** Repoint the donor first → wait ≥ `duration` → read `pendingStream` and confirm → one `batchMint(1, …)` on the old instance → `rescueERC20` → **only then** pause / unset `tokenMinter` / unset `dispatcherIndex` / unwhitelist.

---

## L-01 · DEDUP-19-06 — **Low** (owner footgun)

`NudgeRatchet:155-160` · `Uniboost:246-250` · `PromotionUniV2_Eth:392-396` · fingerprint `b0aa0f58…` · **footgun: true**

**Impact: availability only.** `setBatchMinter(new)` / `setRecipient(new)` on a **live** dispatcher succeeds **silently** and arms `NudgeStreamer__NotRegistered()` on every subsequent user mint. Clearing it requires `setNudgeTokenWhitelist` on the batchMinter **then** `registerStream` on a contract in a **different repository** that may not share the owner key. No value is at risk — the revert is tx-atomic and the user's payment rolls back — and `NFTMinterV2`'s `config.disabled` is an owner backstop.

**Why Low.** Availability-only, tx-atomic, no unrecoverable state, loud and immediately visible on the first mint, owner-recoverable with a documented backstop. It stays **in** the report (not suppressed under KI-1/KI-4) because the repoint sub-case is genuinely surprising — the arming is silent and the cure lives in another repo. The **deploy-ordering sub-case was correctly suppressed** (SUB-02): it fails on the first dispatch before any user traffic, so a competent owner is not surprised.

> ⚠ **Genuine doubt: Low vs Medium.** The literal C4 wording *"availability could be impacted"* fits — minting at that index is fully down until fixed, and the cross-repo key dependency can extend the outage past one transaction. Held at **Low** because the outage is self-inflicted, instantly and loudly detected, causes no user loss, and is owner-recoverable. **Re-weigh to Medium if the `registerStream` key is genuinely held by a different party with a slow process.**

**Author pre-declaration.** The shipped *"NOT an audit finding"* NatSpec is **correct for deploy-ordering** and **over-broad for repoint**. A story cannot pre-declare a hazard out of scope.

**Do not merge** with M-02/DEDUP-19-02 (there it additionally strands funds with no rescue) or with M-03/DEDUP-19-05 (same `contract:function`, different `rootCauseClass`, different fingerprint).

---

## L-02 · DEDUP-19-07 — **Low** (owner footgun)

`BalancerPoolerV2._dispatch:287-295` · `_psmDonate:345` · `setPSM:227-231` · fingerprint `79a2cd4a…` · **footgun: true**

**(a)** The sweep-and-retry that recovers parked USDS lives **inside** `if (donationEnabled)`. Disable the donation while USDS is parked and it is never re-swept, never wrapped to sUSDS, stops being productive collateral and does not contribute to `pool()` — recoverable only via `rescueERC20:437`, while the NatSpec (`:257-261`) presents re-sweeping as *the* recovery mechanism **without noting it is conditional**.
**(b)** `gem` is read **live** from `ISkyPSM(psm).gem()` on every call and `psm` is owner-settable; a `setPSM` repoint to a different-gem PSM silently yields an unregistered pair ⇒ `NotRegistered` ⇒ caught ⇒ USDS parks behind **one** `DonationSkipped` — and per L-03 that event is now the only signal. `BalancerPoolerV2` is the **sole live-gem-read of the four** (`PromotionUniV2_Eth` pins USDC `constant`, `NudgeRatchet` pins a 6-dp immutable), so the asymmetry is first-party.

**Why Low.** No theft, no permanent loss, no user-facing availability impact (dispatch still succeeds — only the donation is skipped), full recovery via `rescueERC20:437`, and **phUSD backing is not impaired** in either sub-instance (CV-07 / R-06). Kept in scope rather than suppressed as an obvious misconfig because the failure is **silent and single-event** rather than loud — the Law-3 surprise test is met. *Mild doubt vs Medium if a large USDS balance parks and the misdirecting NatSpec delays discovery; held at Low because the funds stay under owner control throughout and no third party benefits.*

---

## L-03 · DEDUP-19-08 — **Low** · **faithfulness: true → F-01-047**

`BalancerPoolerV2._psmDonate:329-350` · fingerprint `482cefc3…`

`require(gemAmt > 0, …)` became `if (gemAmt > 0) { … }`. The old `require` reverted into the caller's `catch`, which emitted `DonationSkipped`; the `if` returns normally and emits **nothing** — exactly as the caught region's contents widened to PSM + streamer wiring + the streamer's own outbound settle, collapsing every distinct wiring failure into one undifferentiated event. The documentation was not updated and doubles down, telling operators to *"watch `DonationSkipped` and the contract's USDS balance"*. The same event-silent shape exists **natively** at `Uniboost:246` and `PromotionUniV2_Eth:392`.

**Why Low.** Observability, not value: `_psmDonate` is atomic, parked USDS is re-swept, and **phUSD backing is not impaired** (R-06 found no unbacked-phUSD path in any failure mode; CV-07 confirms the ≥2:1 cushion). Placed at Low rather than pure QA because the degraded signal is **load-bearing for L-02**, where a silent value-parking condition is now detectable only through the one event that has been made ambiguous. The guard itself is **correct and load-bearing** (it keeps `NudgeStreamer__ZeroAmount()` out of the catch), and story-047 bullet 4 **authorises the change** — but authorisation of a change is not disposal of its consequence.

---

## L-04 · DEDUP-19-09 — **Low**

`Uniboost._dispatch:246-251` · constructor `:115-130` · fingerprint `9fdcb0c6…`

`NudgeRatchet` and `NudgeRatchetDelayRelease` enforce `decimals() == 6` at construction; `Uniboost` takes `primeToken_` **free, with no guard at all** — an asymmetry against its own siblings. Post-story-046 the donation branch has **no try/catch**, so a live donation depends on **two** token movements inside a foreign contract instead of one leaf transfer, converting three premises from contract-level guarantees into **deployment policy** simultaneously: the CV-06 read-only-reentrancy hook-free-token clearance, blacklist isolation, and the streamer's shared-balance solvency invariant.

**Why Low.** A deploy-time guard asymmetry and a loss of failure isolation, with **no exploit at the live USDC topology**. KI-2 correctly removes the malicious-token vector and KI-3 / the C4 FoT rule remove the generic fee-on-transfer claim (SUB-03/SUB-04); what survives is first-party and independent of both.

> **MR-02 is NOT closed by this classification.** The cross-stream shared-balance solvency claim remains parked with two tiers disagreeing on where the loss lands. If MR-02 resolves in favour of the whole-streamer-solvency reading, that is a **separate finding at a higher severity**, not a re-weigh of this one.

---

## L-05 · DEDUP-19-10 — **Low** · documented-property deviation

`PromotionUniV2_Eth.pool:451-454` · `_addPhusdPromoLiquidity:463-467` · fingerprint `1c1e0001…`

`phusdBurned = phusdAcquired / 2` uses Leg A's **return value**; `_addPhusdPromoLiquidity` reads `balanceOf(address(this))`. Residual or donated phUSD is therefore pooled **without a matching burn**, so the documented *"half burned, halves value-matched"* property holds only for a contract starting each `pool()` at zero. `minLP` bounds the outcome ⇒ documentation fidelity and a drifting burn ratio, **not a value leak**. *Mild doubt vs pure QA; held at Low because the deviation is in a value-accounting property the economics documentation asserts, not merely in a comment.*

> ⚠ **Explicitly NOT folded into L-13 / DEDUP-19-04** despite the identical whole-balance shape: different asset (phUSD, not ETH), different consequence (documentation fidelity, not slippage-floor dilution), different fix. Folding it in would silently retire it under an owner decision **never made about it**. Also distinct from **L-15** (same `contract:function`, different `rootCauseClass`).

---

## Q-01 · DEDUP-19-11 — **QA**

`BalancerPoolerV2:346` (+ `NudgeRatchet:160`, `Uniboost:250`, `PromotionUniV2_Eth:396`) · fingerprint `11d8b865…`

Every **other** `forceApprove` in these contracts is paired with a zeroing reset; the streamer approve is the sole unpaired one. **Exploitability affirmatively refuted (R-03)** — exact approve, exact pull, same call, atomic rollback. Retained purely as hardening because the safe-today property rests on an **external, cross-repo** implementation detail rather than a local invariant. **Not** the C4 known-invalid approve-race / `safeApprove` front-running pattern.

---

## Q-02 · DEDUP-19-12 — **QA** (rank **first** in the QA bundle)

Reconciles to **Q-17 `696cc345…`** (`open`) — **still-open, note expansion; do not file a new entry.**

`forge build` **failed** at `d4cc563` (`test/Tier3PromotionInvariants.t.sol:120`, 5-arg `pool()` against the current 6-arg signature). For the duration of the bit-rot the project shipped stories 046/047 with **zero executable regression coverage** — every prior finding's guard test was silently not running. Repaired in the **workspace clone only** (`lib/` untouched); the repair is **not upstream**. Q-17 remains only **partially** addressed: with the arity fixed, `test_guided_sequence_holdsAllInvariants` compiles and then fails at *runtime* with `PromotionUniV2_Eth: nudgeStreamer unset` — incidentally a **fourth independent reproduction** of the L-01 mandatory-streamer class.

**Why QA.** Not an exploit, no on-chain impact, so it cannot carry Low or above under C4 — severity measures impact on assets/function, and a broken harness has neither; its cost is assurance, which the QA lane carries. *Mild doubt vs Low.* Ranked first in the bundle because its blast radius is larger than the Q-17 entry states — Q-17 was filed as *"the reworked split/burn/WBTC flow is not fuzzed"*, but the accurate statement is that the **whole suite** was unrunnable. Report it honestly at QA, rank it first, **do not inflate and do not bury**.

---

## Shadow classification — DEDUP-19-04 (**SUPPRESSED**, proposal only)

**Status: suppressed.** Matched ledger **L-13** (`ac8eadef…`, `wont-fix`, owner triage 2026-07-18), twin **F-01-044** (`3e638eb9…`, `wont-fix`). Not in the survivor set, **not re-filed, no new fingerprint minted**. The owner's decision stands until the owner re-decides. The shadow severity below exists solely so the owner can re-triage **with a number in hand**.

**Shadow severity: Medium.** (`c4LabelIfReopened: M-04`; ledger `L-13` raised Low → Medium on reopen.)

**Evidence.** `Run19_T5_LegBUnboundedEth`, 3/3 pass, mainnet fork @ block 25,550,000, live UniV2 router/factory + Sky PSM + sUSDS + Balancer V3, **no mocked AMM**, current 6-arg `pool()`.

| arm | stray ETH | identical `minPromoOut` = 478.315e18, identical 12 ETH sandwich | outcome |
|---|---|---|---|
| **T5b** | 0 | honest floor | `pool()` **REVERTS** `UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT` — the floor does its job |
| **T5c** | 1.61794 ETH | same floor | `pool()` **SUCCEEDS**; a **third party exits +0.296774 ETH** |

Floor dilution **11.00×**; `address(disp).balance == 0` afterwards — the entire balance was swapped, not the leg output.

**Basis for re-triage.** The load-bearing clause of the owner's `wont-fix` is *"Non-theft (Tier-3 INV-4 fork-proved donated ETH only ever reaches protocol-owned LP, **never a third party**)."* T5b/T5c contradicts that clause directly. The loss channel is **not** the donated ETH's *destination* — which is indeed protocol-owned LP, exactly as INV-4 found — it is the **11× dilution of the slippage floor**, which INV-4 never tested: the same sandwich the honest floor **rejects** becomes **accepted** purely because of ETH the pooler did not put there.

**Honest likelihood — two arms that must not be conflated.**
- **Attacker-funded arm:** an attacker supplying the stray ETH donates **1.61794 ETH** permanently into protocol-owned LP to earn **0.296774 ETH** of sandwich profit — **net −1.32 ETH**. Not self-financing; it must not be presented to the owner as a profitable standalone attack.
- **Stale-residual arm:** where the stray ETH is already resident from a partial Leg B (`rescueETH`'s own NatSpec concedes this), the sandwich needs **no donation at all** and is free profit at protocol expense. **This is the arm that carries the severity.**

**Why Medium and not High.** The profitable arm requires a pre-existing residual the attacker cannot reliably create at a profit, and the donated ETH still reaches protocol-owned LP.

> ⚠ **Genuine doubt: Medium vs Low.** Low is defensible — the attacker-funded arm is net-negative and the profitable arm depends on a residual the protocol can simply sweep. Medium was chosen because the stale-residual arm needs no attacker action beyond the sandwich, and a slippage floor that can be silently made 11× too loose is a **control failure**, not a parameter choice. The owner's own operational note (*"sweep/rescue stray ETH before authorizing a `pool()` call"*) **is** the mitigation — make it a hard precondition in the pooler runbook, or enforce it on-chain, and **Low** is correct.

**Action: recommend only.** Apply the `run19Note` and the `lastSeenRun` bump; **do not change status, do not mint a new fingerprint, do not overwrite `triageReason` or `footgunNote`.** If the owner reaffirms `wont-fix`, record the T5 evidence so the *"never a third party"* clause is **corrected** rather than left standing as fact.

---

## Cross-cutting classification notes

**Centralization (`C-XX`): zero this run.** All 69 Tier-1 `centralization-risk` hits were suppressed at sanitization under Law 3 (owner trusted for **knowing** actions) plus KI-1/KI-4. The three footguns (M-03, L-01, L-02) are **not** centralization findings — they are non-obvious operational hazards classified by the impact they unlock, per the Law-3 exception. **H-01 is likewise not centralization**: the value is taken by an unprivileged third party.

**Faithfulness (Law 2) — three findings, never bundled into QA/gas noise.** M-01 → `F-03-046`; L-03 → `F-01-047`; L-05 → NatSpec burn-ratio fidelity. Each is counted **once**: the security classification here and the `F-XX` spec-conformance entry are two framings of one root cause, not two findings.

**Reporting.** Individual submissions: **H-01, M-01, M-02, M-03**. QA bundle: **L-01 … L-05, Q-01, Q-02** (Q-02 ranked first). All four individual submissions are already PoC-backed at Tier 3 (T1, T4, T2); **M-03 is *sized* by T3 rather than exploited — a runnable retirement-sequence PoC should be generated before submission.**

**Human-review flags (five).**

| Finding | Doubt | Decider |
|---|---|---|
| H-01 | High vs Medium | Does the live payment path ever resolve to a nudge-whitelisted token, and will a guard be added? |
| M-01 | Medium vs High | Is the released lump user-attributed value or protocol-discretionary incentive? |
| M-03 | Medium vs Low | The live stream `duration` (MR-01): ~11 USDC ⇒ Low, ~4,656 USDC ⇒ Medium |
| L-01 | Low vs Medium | Is the cross-repo `registerStream` key held by a different party with a slow process? |
| Shadow-04 | Medium vs Low | Owner re-triage of L-13 / F-01-044 against the T5b/T5c differential |

**Parked and still open (not classified, not dropped):** MR-01, MR-02, MR-03, MR-04, MR-05, MR-06, MR-07.
