# Severity Classification — reflax-yield-vault run-17 @ `cdd0743`

- **Project**: reflax-yield-vault · **Branch**: `master` · **Commit**: `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9` `[story-050] previewExitFor on IYieldStrategy`
- **Input**: `reports/reflax-yield-vault/17/sanitized.md` — 16 findings, 0 suppressed
- **Date**: 2026-08-31 · **Agent**: severity-classifier · **Ledger NOT modified**

## Counts

| Severity | Count | Findings |
|---|---|---|
| **High** | **0** | — |
| **Medium** | **0** | — |
| **Low** | **12** | `-01 -02 -03 -04 -05 -06 -07 -08 -09 -13 -14 -15` |
| **QA** | **3** | `-10 -11 -16` |
| **Centralization** | **0** | — |
| **Informational** | **1** | `-12` |
| **Total** | **16** | |

Cross-cutting tags: `faithfulness: true` ×4 (`-01 -02 -10 -13` → `spec-conformance.md`, labels `F-17-01..04`);
owner-footgun (Law 3) ×1 (`-07`); regression ×0; flagged for human review ×3 (`-02 -06 -14`).

---

## 0. The classification axis, stated once and applied uniformly

`previewExitFor` has **zero consumers** at every sibling repo's current top-level HEAD (verified twice
independently, untruncated). Every finding in this run was therefore tested against one question:

> **Does the harm land on the live execution path today, or does it require a consumer of the new view?**

- **View-only harm ⇒ Low.** The defect is demonstrated in code (root cause is *not* speculative), but there
  is no victim until a consumer lands. This is not the C4 "speculation on future code" invalid category —
  that category requires an *undemonstrated root cause*; here the root causes are PoC'd and only the
  consumer is future. So the findings are **filed at Low, not dropped**, each with a named escalation
  trigger instead of a hedged label.
- **Execution-path harm ⇒ judged on its own merits**, independent of the consumer. Two findings reach the
  live path (`-06`, `-14`) and one is a pre-existing live property re-surfaced by the new view (`-04`).
  Each is argued below on the Medium limbs, not waved through.

**No finding is Medium this run.** The single closest is `-06`, and §2.6 names the one unresolved fact that
would flip it. **No finding is High**: none exhibits direct asset theft or a valid attack path free of
hypotheticals — every candidate path routes through either a consumer that does not exist or an
owner-accepted design premise.

**The aggregate risk is the headline, not any single label.** `WATCH-17-03` — the `stable-staker` submodule
bump to a story-050 commit — escalates **five** findings (`-01 -02 -03 -04 -05`) to Medium **simultaneously**,
and coincides with the existing Medium re-evaluation gates on `F-03` / `52f9b84a54ec9a65` and `F-16-003` /
`c705bd94ec78fd23`. That is a single event converting a clean Low run into a five-Medium run with **no
scanner signal in between**. It must be handled in one pass and must survive triage.

### Economic rules applied (named, per instruction)

| Rule | Where applied | Effect |
|---|---|---|
| **Externally-derived yield over-payment = opportunity cost, never a value-leak finding** | `-13` | Buffer depletion explicitly **not** filed as a leak; only the availability leg is filed. |
| **Minter-cushion commingled share cap is BY DESIGN (deficit direction, V1)** | `-03` (applied), `-06` (**considered and NOT applied**) | `-03`'s client-vs-client transfer leg is suppressed as dedup framed it; `-06` is the **surplus** direction, which the memo's premise does not reach — suppression correctly declined. |
| **That premise is VOID for stable-staker V2** (V2 emits Antimatter, redeemable into unbacked phUSD) | `-06` (the deciding fact), `-03` (dilution leg) | The dilution leg is **live and routed, not suppressed** — to the cross-project unbacked-phUSD channel (`yield-claim-nft` `DEDUP-001` / `antimatter` run-01), parked as `MR-17-03`. Endorsed here, restated so it cannot be lost. |
| **Fail-loud can be the correct design** | `-04` instance (a) | A `minOut` revert is a slippage guard *functioning*, not a defect. Only the *false green* is filed. |
| **In-source NatSpec carries no suppression authority; falsely-exhaustive docs raise severity** | `-01 -02 -05 -15` | story-050's "guarantees" wording is the *subject*, cited as aggravating in four findings. |
| **Assume a non-malicious owner; non-obvious footguns are in scope** | `-07` (footgun kept), `-16` (footgun test failed ⇒ QA) | Applied in both directions. |

---

## 1. Classified findings

### DEDUP-17-01 — base `netGuaranteed` is a ceiling, not a floor, when the share cap binds — **LOW** · `faithfulness: true` (`F-17-01`)

- **C4 limb**: QA/Low — *function incorrect as to spec*. Does not reach the Medium value-leak limb because
  the mis-quote is consumed by nobody.
- **Impact**: The base default's published exit floor over-states deliverable underlying by the full
  vault deficit (PoC: `1000e18` quoted, `500e18` delivered after a 50% drawdown), on a function whose
  NatSpec uses the word "guarantees".
- **Assumptions**: a below-par vault position. **External requirements**: a consumer that trusts the quote.
- **Why not Medium.** `StableStakerV2._isUnderwater` **strictly dominates** the cap-binding condition on the
  armed `withdraw()` path — 696 M-state exhaustive integer search over the live semantics (210 M cap-binding
  states, 0 counterexamples), 150 k fuzz + a 105-case grid against the real contracts in the real two-client
  topology. **This is not a Halmos proof — the symbolic tier returned 0 `[PASS]` / 7 `[TIMEOUT]`. Never
  write "symbolically verified".**
- **The dominance is contingent, and the contingency is unguarded.** It rests on two invariants — `p ≤ D`
  (`AYieldStrategy.sol:48`, `totalDeposited == Σ clientBalances`) and `a ≤ p` (`:772-776`, the withdraw
  amount capped to available principal). **Neither is pinned by any test.** A future change breaking either
  re-arms this at Medium **with no scanner signal**. Parked as `MR-17-05`; this must survive triage.
- **Escalation trigger**: (a) `WATCH-17-03` — `stable-staker` bumps `lib/reflax-yield-vault` to a story-050
  commit and gates a user-facing path on `netGuaranteed`; **or** (b) either dominance invariant
  (`AYieldStrategy.sol:48`, `:772-776`) ceases to hold. Either ⇒ **Medium**.
- **NON-COLLAPSE (carried)**: must not absorb `-03`. A fix copying `_exitFloor` into the base closes this and
  **spreads `-03` to the direct strategy**.
- **vs. source**: source proposed "Low today · potential-Medium on wiring" (pattern DB rates the class HIGH).
  **Agreed at Low**, with the hedge resolved into the trigger above rather than left in the label.

### DEDUP-17-02 — both previews built on fee-free `convertToAssets` — **LOW (evidence gap; flagged for human review)** · `faithfulness: true` (`F-17-02`)

- **C4 limb**: QA/Low — *function incorrect as to spec* **today**. Would satisfy the Medium value-leak limb
  ("value leak with stated assumptions, but external requirements") the moment the external requirement is
  shown to hold.
- **Impact**: The published exit guarantee is breached on **every** exit from a fee-charging vault — census
  fires on **203 of 203** executed direct exits. At a 5% redeem fee: `netGuaranteed 1000e18`,
  `previewRedeem 950e18`, delivered `950e18`. Aggravated by the contract now shipping **two exit previews
  that disagree by the vault's exit fee, with the newer one carrying the word "guarantees"** — story-050
  criterion 10 deliberately forbade `previewExitFor` from using the fee-aware `previewRedeem` it already
  exposes at `ERC4626YieldStrategy.sol:83-85`.
- **Load-bearing**: `assertEq(posValue, net)` passes, so `F-01-050`'s proposed remedy (cap by
  `_positionValue()`) is **numerically identical to the number it was meant to correct**. Any fix must read
  a fee-aware quote.
- **`ECON-A`'s stale Low is NOT inherited — and the gate is NOT closed either.** `F-16-003`'s gate
  ("re-weigh severity against the *actual* vault wired at the integration point, not inherit ECON-A's stale
  Low") is **TRIPPED** this run by the Tokemak `autoDOLA`/`autoUSD` wiring. But tripping the gate is not the
  same as passing through it: the re-weigh requires one fact **this run never measured** — the deployed
  Autopools' actual `previewRedeem` vs `convertToAssets` divergence. I decline both to inherit the stale Low
  *and* to assert a Medium on an assumed fee. **This is recorded as an unresolved evidence gap, not a
  settled Low.**
- **Escalation trigger — a measurement, not a code change**: read `previewRedeem(convertToShares(1e18))` vs
  `convertToAssets(convertToShares(1e18))` on the deployed `autoDOLA` and `autoUSD` at mainnet HEAD. **Any
  non-zero divergence ⇒ Medium immediately** (magnitude scales linearly with the fee, on every exit).
  Owed before run-18; it is a one-command check and it is the highest-value open question in this run.
- **vs. source**: source proposed Low with the gate noted. **Process disagreement**: a tripped gate left
  un-adjudicated is how a stale Low survives a second run. Filed at Low with the gap named and an owner.

### DEDUP-17-03 — per-account quote floored against the GLOBAL share balance — **LOW**

- **C4 limb**: QA/Low — *function incorrect as to spec*. The value-transfer leg that would reach Medium is
  suppressed on a stated, dated premise (below).
- **Impact**: N clients are each quoted a floor only one can be paid. PoC: two `980.1e18` floors against a
  `1000e18` position (Σ = **1.96×**); the second client receives `20e18` (2.0% of its quote) and is debited
  its **full** `990e18` via the protocol-favouring write-down at `AYieldStrategy.sol:781-783`. Three-client
  invariant run: Σ `netGuaranteed` `30,000e18` vs realizable `26,730e18` (+12.2%), and **not** an artifact of
  the mock's redemption throttle (`v2_shortfallUnthrottled` 387/108).
- **What is filed**: the **over-issued guarantee** — a view that legitimises an FCFS drain by telling each
  client it will be paid. **What is suppressed**: the standalone client-vs-client value transfer, under the
  minter-cushion memo — `PhusdStableMinter` has no strategy-withdraw path and cannot race. **No per-client
  cap is recommended.** Scope accepted exactly as dedup framed it; **not widened**.
- **Escalation trigger**: `WATCH-17-E2` (`MR-17-06`) — **any future story giving `PhusdStableMinter` a
  strategy-exit path kills the premise and makes this a live Medium immediately**; also `WATCH-17-03`.
  Because the trigger lives in a *different repo's stories*, no scanner in this project will fire on it.
- **Disclosures carried**: `M-03` / `3c8331040bba6a7b…` (Medium, `merged`, fingerprint retained for exactly
  this match) — same shape, different primitive: `M-03`'s deficit is AMM slippage bounded by
  `slippageToleranceBps × tradeSize` with a `minOut` revert; the direct leg here is an **unbounded vault
  drawdown** and `vault.redeem` carries **no `minOut` at all**. `M-03` stays `merged`. `M-01-run12` /
  `fdda8f53151ab76e` (`false-positive`) is **not** re-escalated and **not** cited as support.

### DEDUP-17-04 — `netGuaranteed > 0` is a false green; three independent reasons `withdraw` is not executable — **LOW**

- **C4 limb**: QA/Low. Weighed **explicitly** against the Medium availability limb and held below it — see
  the three-part reasoning below, which is the closest call in the run after `-06`.
- **Impact**: The whole `withdraw` / `withdrawAsOwner` / `totalWithdrawal` path of the market strategy is
  bricked for **every** client while the condition holds (`_disposeShares` is the single shared exit hook),
  while the new preview reports green. `INV-3` is the **dominant** failure mode on both strategies
  (`v3_nonZeroQuoteRevert` 127 direct / 90 market).
- **Why not Medium on the availability limb**, instance by instance — the enumeration matters because
  **each needs a different code change, and a fix landing only one is an INCOMPLETE FIX, not a fix**:
  - **(a) AMM price blindness (market).** The revert is a `minOut` slippage guard **doing its job**. Under
    the standing *fail-loud-is-a-feature* rule this is not an availability defect; refusing to sell into a
    10% discount is correct. Only the *green quote* is the defect, and it has no consumer.
  - **(b) Vault redemption throttle (direct).** Zero occurrences of `maxRedeem`/`maxWithdraw` in first-party
    `src/`; `_disposeShares` calls `vault.redeem` unconditionally (`r_redeemThrottleBind` 127/66). This is
    the instance closest to Medium — it is **not** a guard functioning, it is an unhandled external
    precondition. Held at Low because the revert is loud, retryable, self-clearing, and **no code change
    creates liquidity the Autopool will not pay**: a `maxRedeem`-aware partial exit improves UX, it does not
    improve availability of the assets.
  - **(c) Finite AMM depth (market).** Same disposition as (a); the floor is depth-blind, so a large request
    breaches `minOut` at an unmoved mid-price (gross `19,800e18`, quoted `19,602e18`, AMM would pay
    `14,882.7e18`).
- **Remedies exist and were enumerated, not asserted**: `relinquishPrincipal` (`AYieldStrategy.sol:682`,
  **client-callable**) and `relinquishPrincipalAsOwner` (`:687`) both write principal down with no external
  call. Bricked normal path, two working escape hatches — **no "permanent freeze" claim is made**.
- **Escalation trigger**: (a) `WATCH-17-03` — a consumer gating a user-facing withdraw on `netGuaranteed > 0`
  ⇒ **Medium**; **or** (b) evidence that instance (b)'s throttle binds for a **sustained** period on the
  deployed Autopools (i.e. that "self-clearing" is false) ⇒ **Medium** on the availability limb **with no
  consumer needed**.
- **CRITICAL DE-CONFLICTION (carried, must not be lost at triage)**: `M-02` / `d7f6c2dfd5807769…` (Medium,
  `false-positive`) must **NOT** be inherited. Same code, **different claim** — `M-02` is *value extraction
  by a sandwicher*, refuted on concentrated-liquidity pool topology; this is *liveness*, on a surface that
  did not exist at `M-02`'s commit. The refutation is about **profitability**, not about the quote's
  **blindness**. A triage pass that pattern-matches this onto `M-02` would suppress a live finding.
  Stable-staker `M-07` / `969722dc9eedb961…` (`acknowledged`) is a **foreign-ledger** status with no
  suppression authority here, and its disposition (operator discipline) does not reach a permissionless
  integrator-facing view.

### DEDUP-17-05 — the quoted floor is not honoured across a real quote→execute gap — **LOW**

- **C4 limb**: QA/Low. This is the **most severe shape in the run** and it is stated plainly below why it
  is nonetheless not Medium.
- **Impact**: silent ~99% under-delivery. `19,602e18` quoted at T1; `181.9e18` delivered at T2 — **0.93% of
  the guarantee, with no revert, no event, no signal**. `_disposeShares` re-derives `minOut` inline from
  live state (`:245-246`), so a floor quoted at T1 is silently replaced by a lower floor at T2.
- **What stops it being Medium — stated plainly, three things, and all three are contingent:**
  1. **Nobody sees the quote.** Zero consumers; the divergence is unobserved and unrelied-on today.
  2. **The delivery shortfall itself is already owner-accepted.** "Debited for the requested amount
     regardless of what was received" is `AYieldStrategy.sol:781-783` by explicit design (*"shortfall accrues
     as yield"*), and the FCFS-at-par socialization it implements is `stable-staker` `69c7666eee33698e…`
     — **`wont-fix`, "intended design, confirmed by protocol owner"**. What is **new** at `cdd0743` is only
     that the protocol now *publishes a number under the word "guarantees"* that this accepted design will
     not honour. Until someone relies on it, that is an API-contract defect, not a new loss primitive.
  3. **The PoC's two-exit-capable-client premise does not hold in the deployed wiring** (the minter cannot
     exit). The gap still opens on a price move alone, but the demonstrated 99% magnitude does not.
- **Why it is nonetheless not QA**: the floor's atomic correctness is an **unenforced convention** — the same
  expression copied across three places (`:127-135`, `:245-246`, `t.sol:44-52`, pattern `D-5`), an equality
  nothing checks. It holds atomically (256,000 forge + 209,901 medusa calls, no counterexample) and
  **evaporates the moment the gap is real**, which is the only mode in which a STATICCALL preview is useful.
- **Distinctness is load-bearing** (accepted as argued): different harm from `-04` (silent vs revert),
  different root cause (the quote is not a snapshot), and **different mitigation** — the floor must become
  **enforceable** as a caller-supplied `minOut` passed into `withdraw`, which `-04`'s AMM-quote fix does not
  deliver. Filing it under `-04` would let the wrong fix close it.
- **Escalation trigger**: any consumer that **persists a `netGuaranteed` across blocks** — an off-chain
  keeper, or a two-phase `totalWithdrawal` flow — ⇒ **Medium** (value leak, stated assumptions, external
  requirement = a price move in the gap). `WATCH-17-03`.
- **Disclosure carried**: stable-staker `M-01` / `2b9a89d29c34df41…` (Medium, `wont-fix`) is **adjacent, not
  a duplicate**; its reasoning ("nothing in stable-staker can fix it") carries **no authority over reflax
  code**, where the fix *is* a code change. Fingerprint correction confirmed: `2b9a89d2…` is the par-exit
  front-run entry, **not** `69c7666e…`; memory `stable-staker-run15-notes` repair is owed.

### DEDUP-17-06 — one-directional write-down; the market pays out over-delivery from the commingled position — **LOW (flagged for human review — the run's strongest Medium candidate)**

- **C4 limb**: QA/Low *as classified*, but this finding sits **on the Medium value-leak limb's boundary**
  and dedup routed it here explicitly for adjudication. The adjudication follows; a human can flip it in
  one read.
- **Impact**: `_withdrawInternal` documents (`:757-760`) that *"principal is decremented by the REQUESTED
  (capped) amount … Any shortfall stays as protocol-owned yield"* — it books the **downside** as protocol
  yield but **pays out the upside** to the exiter. Confirmed at source: `clientBalances[token][holder] -=
  amount` at `:781-783` is unconditional on `sharesDisposed`. PoC at a 5% premium to NAV: principal debited
  `10,101.0e18`, underlying delivered `10,575.1e18` — **+474e18 paid out of the commingled position**. The
  asymmetry is undocumented and **repeatable** (exit whenever the AMM bids above NAV).
- **This is the only finding in the run whose harm needs no consumer of `previewExitFor`.** It is on the live
  execution path at HEAD.
- **The Medium case (stated in full, not buried)**: stated assumptions — an exit-capable client exits while
  the AMM bids above NAV; external requirement — the Curve pool trading above NAV. Value demonstrably leaves
  the commingled position. Ledger conservation `Σ clientBalances == totalDeposited` **holds** (0 skews in
  256,000 calls × 2 strategies) — **the skew is in value, not in the books, which is precisely why no
  accounting invariant catches it**.
- **The Low case, and the one fact that decides between them**: with the deployed wiring there is exactly
  **one** exit-capable client, so the over-delivery is a transfer from the minter's cushion to
  StableStaker's stakers.
  - Under **V1**, that is protocol-owned capital moving to protocol users — misallocation, not economic
    loss; the minter cannot redeem, so no user is diluted. **Low.**
  - Under **V2**, the premise is **VOID**: V2 emits Antimatter, redeemable into **unbacked** phUSD, so
    draining the cushion is **real dilution borne by the minter's constituency**. **Medium.**
  - **Deciding fact, owed and unresolved: which `StableStaker` version is wired at the integration point.**
  Per the conservative rule (uncertain ⇒ classify lower, flag for review) this rests at **Low**.
- **Suppression correctly NOT applied**: the minter-cushion memo declares the commingled cap by design in the
  **deficit** direction (minters cannot redeem ⇒ cushion, not counterparty). This is the **surplus**
  direction. The memo's premise does not reach it. **Recall beats tidiness (Law 1).**
- **The V2 dilution leg is live and is NOT silently suppressed**: routed to the cross-project unbacked-phUSD
  channel (`yield-claim-nft` `DEDUP-001` / `antimatter` run-01), parked as `MR-17-03`. Routing endorsed;
  restated here so it cannot be lost between two reports.
- **Escalation trigger**: `StableStakerV2` (Antimatter-emitting) confirmed as the wired client at the
  integration point ⇒ **Medium** immediately, no further evidence needed.
- **Adjacent, do not collapse**: `QA-09` / `86409a56b6fc3c8b` (open, orphaned vault value) — same commingled-
  residual accounting, **opposite direction**.
- **vs. source**: source carried Low "pending severity-classifier, flagged for second opinion". **Adjudicated:
  Low stands, but the Medium case is materially stronger than a bare Low label conveys**, and the deciding
  fact is a one-question lookup. Do not let this settle at Low by default.

### DEDUP-17-07 — `previewExitFor` returns `(0,0)` for five operationally unrelated states — **LOW · owner footgun (Law 3, operational hazard)**

- **C4 limb**: QA/Low — *state handling / incorrect as to spec*, classified by the impact the footgun unlocks.
- **Impact**: Four states return **bit-identical `(0,0)`**: unknown account, zero `netWanted` on a funded
  account, drained account, and — the footgun — `slippageToleranceBps == MAX_BPS` on an account with a **live
  `990e18` principal** (`assertGt(principalOf(...), 0)` passes). A funded client signals **indistinguishably
  from an account that never existed**. Feeding `grossToRequest == 0` back in reverts rather than no-op'ing.
  A **fifth**, worse state: post-`emergencyWithdraw`, `shares == 0` with principal booked ⇒ positive gross so
  the `(0,0)` sentinel does **not** fire, `netGuaranteed 0`, then a zero-size swap → `DEDUP-17-08`.
- **Law-3 test applied**: *would a competent, non-malicious owner be surprised that raising slippage
  tolerance makes a funded client indistinguishable from an unknown one to every integrator?* **Yes ⇒
  footgun ⇒ report.** This is an operational hazard with safe-config guidance, **not** a malicious-admin
  vector — there is no malicious-owner leg in this finding at all, and the reckless-admin invalid category
  does **not** apply (the harm is the opposite of obvious).
- **Escalation trigger**: a consumer treating `(0,0)` as "not a client" (skip / de-register / write off) while
  principal is live ⇒ **Medium** (state corruption in the consumer, not just a bad quote).
- **Safe-config guidance (carry into the QA bundle under `L-01`)**: `require(_bps <= 1000)` in the setter;
  never deploy at the zero default; pause deposits before temporarily raising tolerance;
  `require(creditedPrincipal > 0)` in `_depositInternal`; monitor
  `previewExitFor(token, <known-funded client>, 1)` as a `MAX_BPS` canary.
- **Ownership**: `L-01` / `6460e35331dff5c2` owns the setter's *boundaries* and the deposit-side blast radius,
  **not** the alarm ambiguity. The split is along ownership, not the boundary. Confirmed correct.

### DEDUP-17-08 — test AMM adapter more permissive than production; `_disposeShares` bricks on a zero-size swap — **LOW**

- **C4 limb**: QA/Low — *state handling*, plus a test-fidelity assurance gap.
- **Impact**: `CurveAMMAdapter.sol:129` enforces `require(amountIn > 0)`; `MockAMMAdapter` does not, and
  **every** market test — including all 13 new preview tests — runs against the mock. Two reachable paths to
  `amountIn == 0`: (1) `vault.balanceOf(strategy) == 0` with principal still booked (post-`emergencyWithdraw`,
  or after another client drains the position per `-03`); (2) `convertToShares(gross) == 0` for a dust exit
  once share price exceeds one underlying unit.
- **The test-fidelity half is the more important half**: the mock is more permissive than production on
  **exactly the edge story-050 steers callers into**, which is why a 13-test green suite proves nothing here.
  Corroborated by the repo's own control test `testControl_repoMockAmm_hasInfiniteDepthAndAcceptsZeroIn`.
- **Remedy enumeration was RUN, not asserted** (per the `absence-of-remedy` precedent): `withdraw`/
  `withdrawAsOwner` revert; `totalWithdrawal` silently no-ops at `:294`; `relinquishPrincipal` (`:682`) and
  `relinquishPrincipalAsOwner` (`:687`) both succeed with **no external call**. **Bricked normal path with two
  working escape hatches — not a permanent freeze.**
- **Escalation trigger**: either escape hatch being removed or owner-gated (in particular
  `relinquishPrincipal` ceasing to be client-callable) ⇒ the brick becomes a **freeze** ⇒ **Medium**.
- **Disclose, do NOT collapse**: `L-13` / `1456259d8ac60c11…` (Low, open) is the same share-flooring root
  cause in `_totalWithdraw`; **different function, different fix** (`L-13` wants revert-or-skip there; this
  wants `if (sharesToSell == 0) return 0;` in `_disposeShares` **plus** the `amountIn > 0` guard added to
  `MockAMMAdapter`). **Fixing one leaves the other live.**

### DEDUP-17-09 — `netWanted * MAX_BPS` panics on `type(uint256).max` in the market override — **LOW**

- **C4 limb**: QA/Low — *function incorrect as to spec*.
- **Impact**: The two implementations of **one interface member diverge on the standard "give me everything"
  sentinel**: the base returns the capped principal (`1000e18`, no revert); the market reverts a bare
  `Panic(0x11)`. Asserted boundary: `netWanted > 11579208923731619542357098500868790785326998466564056403945758400791312963`.
  story-050 criterion 9 explicitly demanded a neighbouring division edge be *distinguishable from a bare
  `Panic(0x12)`* — this ships a bare `Panic(0x11)` on a **more** plausible input.
- **Why Low, not QA**: it is not an absurd-input filter case. `type(uint256).max` is the idiomatic
  max-withdrawal sentinel; a consumer switching between the two strategies behind one interface gets a
  revert from one and an answer from the other. One-line fix:
  `Math.min(netWanted, availablePrincipal)` before the gross-up.
- **Escalation trigger**: none realistic — no asset path. Stays Low even under `WATCH-17-03`.
- **vs. source**: source proposed "QA / Low". **Firmly Low** — interface-member divergence on the standard
  sentinel is a spec defect, not a style nit.

### DEDUP-17-10 — `ceilDiv` gross-up compensates the bps leg but not the share round-trip — **QA** · `faithfulness: true` (`F-17-03`)

- **C4 limb**: QA — dust rounding, *known-benign*.
- **Impact**: `netGuaranteed` can land **1 wei** below `netWanted`, contradicting story-050's claimed
  property. Analytic bound `netWanted − netGuaranteed ≤ ⌈A/S⌉ + 2` raw base units; 256-run fuzz, no
  counterexample.
- **Why QA and not higher**: `ROUNDING-DIRECTION` classifies it **known-benign** — `ceilDiv` rounds the
  *request* up (protocol-favouring) and the double floor rounds the *quote* down. **No user-favouring leg,
  no repeatable round-trip profit.** `DIVISION-PRECISION` refuted (mul-before-div throughout). Under the
  loss-of-yield/dust rule, dust ⇒ QA.
- **Escalation trigger**: a user-favouring rounding leg appearing on the same path, or a bound that scales
  with position size rather than with `⌈A/S⌉`. Neither exists today.
- **CHANNEL DISAGREEMENT with the source pass.** Severity QA is agreed; **the channel is not**. This is a
  deviation from story-050's stated behaviour, so under Law 2 it is tagged `faithfulness: true` and routed to
  **`spec-conformance.md` as `F-17-03`**, *not* dropped into the QA/gas bundle. A pure behavioural deviation
  with no security impact is still reported where the owner will see it.
- **Process signal for the report writer**: **two consecutive stories (043, 050) have each claimed a provable
  property that the ERC4626 double round-down does not deliver** — see `F-01` / `ec9191e420d54444…`
  (deposit side; **disclose, do not collapse** — this is the exit side, on a function that did not exist at
  `F-01`'s commit).

### DEDUP-17-11 — market `previewExitFor` override sealed against subclassing — **QA**

- **C4 limb**: QA — code quality / extensibility.
- **Impact**: the market declares `external view override` where the deliberate base at
  `AYieldStrategy.sol:571-577` is `external view virtual override`. Every other overridable hook
  (`_disposeShares`, `_positionValue`, `getTotalShares`) stays reachable; this one is the exception —
  in a repo with a demonstrated forked-variant habit (`NFTStakerPriceScaled`, `StableStakerV1/V2`) and
  **five defects (`-01`..`-05`) a subclass would want to patch**. One-word fix.
- **"Unused view functions" invalid category does NOT apply** — the finding is not "a view is unused", it is
  that the override is sealed.
- **Escalation trigger**: a forked variant actually being created that needs to patch `previewExitFor` and
  cannot ⇒ **Low**.

### DEDUP-17-12 — adding `previewExitFor` to `IYieldStrategy` breaks four implementers at the next bump — **INFORMATIONAL**

- **C4 limb**: Informational — build hygiene. No runtime path, no asset path.
- **Impact**: four `IYieldStrategy` implementers (`stable-staker` ×2, `stable-yield-accumulator` ×2) resolve
  the interface through a **remapping to the live reflax submodule** — no repo vendors its own copy — so all
  four fail to compile at the next bump. **All four are in `test/`: a build break in test suites, not a
  runtime break.** `phoenix-phase-2-staging` has zero implementers; `antimatter`'s mock declares no interface
  inheritance and is unaffected.
- **Escalation trigger — named and parked**: `MR-17-04`. story-faithfulness `WATCH-17-01` claims **six**
  implementers; two are in **unregistered** repos and outside this run's evidence base. One matters
  disproportionately: `deployment-staging/src/mocks/MockYieldStrategy.sol:12` is cited in **`src/`, not
  `test/`**, which would escalate a test-only break to a **deployable-contract** break ⇒ **Low or Medium**.
  The enumeration **does not assert it exists**; it flags the claim as unverifiable. **Register
  `deployment-staging` or confirm it is dead before the next reflax bump.**
- **This finding carries the run's load-bearing fact**: zero consumers of `previewExitFor`, verified twice
  independently and untruncated (`grep -rn "previewExitFor" lib/` → hits only under `reflax-yield-vault/`;
  symbolic pass re-derived the same per-submodule counts). **`WATCH-17-03` escalates `-01`..`-05` at once.**

### DEDUP-17-13 — story-025's mandated safeguard is structurally incapable of firing — **LOW** · `faithfulness: true` (`F-17-04`)

- **C4 limb**: QA/Low — *function incorrect as to spec*, on the **availability** side. Explicitly **not** the
  value-leak limb.
- **Impact**: `_routeExit`'s `guardUnderwater` branch returns the **full requested `amount`** from
  StableStaker's own idle balance and calls `relinquishPrincipal` (a pure write-down,
  `AYieldStrategy.sol:700-716`, *"vault shares are deliberately untouched"*). Therefore `received == needed`
  **by construction**, the mandated `StableStaker:` revert **can never fire**, and story-025's acceptance
  test (*"assert the idle buffer is untouched … in the lying-preview scenario"*) passes trivially against a
  full-credit mock while being **unsatisfiable** against a real below-par strategy. **A green checklist here
  is a false negative.** Downstream: the buffer is thin by construction (10% of skim proceeds,
  `MigrateStableStakerMainnet.s.sol:597`); one large staker's whole-position `autoAnnihilate` empties it,
  after which `_routeExit` takes `revert("StableStaker: strategy underwater")` and **every other staker's
  `withdraw()` is bricked** until the position recovers or the owner refunds.
- **Economic rule applied**: buffer depletion itself is **opportunity cost** under the externally-derived-yield
  rule and is **explicitly not filed as a value leak**. Only the availability leg is filed.
- **Why the "speculation on future code" invalid category does not apply**: that category requires an
  *undemonstrated root cause*. The root cause is **demonstrated in code today**. Only the *escalation* is
  future-conditioned, and it is capped at Low behind a dated trigger. The naive "consumer trusts
  `netGuaranteed`, buffer eats the difference" finding is deliberately **not** filed.
- **Escalation trigger (conjunction of all three)** ⇒ **Medium**: (1) `stable-staker` bumps
  `lib/reflax-yield-vault` to a story-050 commit **and** lands `autoAnnihilate`; (2) `autoAnnihilate` sources
  through `_routeExit(..., guardUnderwater = true)`; (3) the wired strategy can go below par (**true today**
  for both Tokemak-Autopool direct strategies and the USDe market strategy).
- **Channel (Law 2)**: `spec-conformance.md` as **`F-17-04`** — **not** the QA bundle. Rides the existing
  `F-03` / `52f9b84a54ec9a65` gate and feeds `QA-09` / `86409a56b6fc3c8b`. **Not a duplicate of either**:
  `F-03` is double-counting across the call; this is the consumer's own safeguard being inert. Handle both
  gates in the same pass as `WATCH-17-03`.
- **Story state note (Law 2)**: story-025 sits in the `incomplete` folder — a landed dependency whose story is
  not closed out is itself worth the owner's attention.

### DEDUP-17-14 — `_totalWithdraw` silently early-returns on `totalShares == 0 || totalDeposited == 0` — **LOW (flagged; one verification owed)**

- **C4 limb**: QA/Low — *incorrect state handling*.
- **Impact**: `if (totalShares == 0 || totalDeposited[token] == 0) { return; }` at both
  `ERC4626YieldStrategy.sol:185` and `ERC4626MarketYieldStrategy.sol:293`. The consequence is traced, which
  is what lifts it above a bare `incorrect-equality` detector hit: **the two-phase `totalWithdrawal` window
  is consumed by the silent no-op while principal stays booked.** The caller is told nothing.
- **Escalation trigger — a checkable fact, owed before this rests**: if the consumed window **cannot be
  re-initiated** (i.e. the owner cannot re-open `totalWithdrawal` after a burned no-op), an owner migration
  is **permanently blocked** by a silent return ⇒ **Medium** on the availability limb. If it can be
  re-initiated, Low is correct. **Finding-manager / report-writer: resolve this before the QA bundle closes.**
- **vs. source**: static pass filed both instances as "Medium-potential"; dedup carried Low. **Low agreed**,
  but the Medium hinges on one unasked question, named above rather than left implicit.
- **Ledger caveat for finding-manager**: `L-13` / `1456259d8ac60c11…` is the *market* `_totalWithdraw`
  **share-flooring** instance. This is the **zero-shares / zero-deposits guard** at the top of the same
  function, on **both** contracts — different condition, different fix, different `rootCauseClass`, different
  fingerprint. **Confirm `L-13` does not already cover the market site before minting a second entry there;
  the direct-strategy site is unambiguously new either way.**

### DEDUP-17-15 — direct strategy discards `vault.redeem`'s return — **LOW**

- **C4 limb**: QA/Low — *incorrect state handling*. Rated Low rather than QA because of leverage, not impact.
- **Impact**: `vault.redeem(sharesToRedeem, recipient, address(this));` at
  `ERC4626YieldStrategy.sol:135` discards the return. `previewExitFor`'s NatSpec mandates **in capitals** that
  consumers MUST measure the actual balance delta across `withdraw`; **the strategy's own exit does not**, and
  `vault.redeem` carries **no `minOut`**. That combination is exactly why the direct-strategy failures in
  `-01` and `-02` are **silent under-delivery rather than reverts**.
- **Why it is not SAST noise**: it is the **mechanical enabler** of `-01` and `-02`, and the highest-leverage
  single line in the run — capturing the return and comparing it to the quoted floor **converts `-01` and
  `-02` from silent to loud in one line**. Not a style nit; the missing tripwire.
- **Escalation trigger**: none standalone — it is a mitigation multiplier. Its value is that it **caps** the
  escalation of `-01`/`-02` if landed before `WATCH-17-03`. **Recommend landing this first.**
- Distinct from `QA-06` / `8019f1c9c6de5e43` (EnumerableSet returns) and `L-06` / `0f534a726502d274`
  (skim return semantics) — different call sites.

### DEDUP-17-16 — raw `approve` with unchecked boolean return in the `ERC4626YieldStrategy` constructor — **QA**

- **C4 limb**: QA — code quality.
- **Impact**: `IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);` at
  `ERC4626YieldStrategy.sol:50`. USDT's `approve` returns no data, so a `bool`-decoding call **reverts at
  deployment**. Failure is **deploy-time and loud — nothing deploys.**
- **Two invalid categories tested; neither applies.** (1) *Approve race / `safeApprove` front-running*: that
  pattern is the ERC20 allowance double-spend across an `approve(x) → approve(y)` transition. This is a
  one-shot constructor approve with the strategy's own configured vault as spender — no race, no
  front-run, no allowance transition. (2) *Non-standard/weird ERC-20 (except USDT)*: **USDT is the explicit
  carve-out and USDT is the token that trips this** — the carve-out *is* the basis, not a suppression.
- **Law-3 note**: correctly **not** filed as a footgun — the failure is loud and pre-deployment, so it fails
  the surprise test. **QA is the right severity.**
- **Why kept**: one-line `SafeERC20.forceApprove` fix on the **only unguarded ERC20 call in `src/`**, and
  `CFG-01` / `0c12a2cfaf4b026a` (open) is evidence the wired-vault configuration **has already been wrong
  once**.
- **Escalation trigger**: none. Stays QA.

---

## 2. Disagreements with the source pass

| Finding | Source proposal | This pass | Direction | Basis |
|---|---|---|---|---|
| `-02` | Low (gate noted as tripped) | **Low + declared evidence gap**, flagged | process, not label | A *tripped* `F-16-003` gate that is never adjudicated is exactly how `ECON-A`'s stale Low survives another run. The re-weigh needs one unmeasured fact (deployed autopool `previewRedeem` vs `convertToAssets`); an on-chain check is owed before run-18. |
| `-06` | Low, "flagged for second opinion" | **Low, adjudicated, top Medium candidate** | held, but escalated in visibility | Only finding whose harm needs no preview consumer. V1 ⇒ Low (protocol-owned capital); **V2 ⇒ Medium (real dilution via unbacked phUSD)**. Decided by which StableStaker version is wired. Conservative rule applies; the Medium case is stated in full so it cannot settle at Low by default. |
| `-09` | QA / Low | **Low** | up (within band) | Interface-member divergence on the idiomatic `type(uint256).max` sentinel is a spec defect, not an absurd input. |
| `-10` | QA, QA bundle | **QA, `spec-conformance.md` `F-17-03`** | channel only | **Law 2**: a story deviation is never buried in the QA/gas bundle, even with no security impact. |
| `-14` | Low (static: "Medium-potential") | **Low + named verification** | held | The Medium hinges on whether a burned `totalWithdrawal` window can be re-initiated. Question asked explicitly rather than left implicit. |
| `-12` | Informational | **Informational** | agreed | But `MR-17-04` (`deployment-staging/src/` implementer) would move it to Low/Medium; the trigger is named, not hedged into the label. |
| `-01`,`-03`,`-04`,`-05` | "Low today · potential-Medium on wiring" | **Low** | agreed | Hedge removed from the label and expressed as a named escalation trigger per finding, per instruction. |

**No finding was inflated to Medium on a hypothetical consumer, and no real defect was deflated to QA to keep
the report clean.** The twelve Lows are all demonstrated root causes; four of them (`-01 -02 -10 -13`) are
additionally routed to `spec-conformance.md` so they are visible to the owner independent of the QA bundle.

## 3. Triage obligations this classification creates

1. **`WATCH-17-03` must survive triage.** One `stable-staker` submodule bump escalates `-01 -02 -03 -04 -05`
   to Medium simultaneously and coincides with the `F-03` and `F-16-003` gates. Handle in one pass.
2. **`MR-17-05` must survive triage.** `-01`'s Low rests on two invariants (`AYieldStrategy.sol:48`,
   `:772-776`) that **no test pins** — this re-arms at Medium **with no scanner signal**.
3. **`MR-17-06` / `WATCH-17-E2` must survive triage.** `-03`'s suppression premise dies if
   `PhusdStableMinter` ever gains a strategy-exit path; the trigger lives in another repo's stories.
4. **`MR-17-03` must retain an owner.** The V2 unbacked-phUSD dilution leg is **live**, routed to
   `yield-claim-nft` `DEDUP-001` / `antimatter` run-01 — routed, not dropped.
5. **Three measurements owed before run-18**, each of which could move a severity:
   `-02` (deployed autopool exit-fee divergence), `-06` (which StableStaker version is wired),
   `-14` (is a burned `totalWithdrawal` window re-initiable). None is expensive; all three are unasked.
6. **Known-issues suppression authority is absent for this project** (empty cache, null source pointer, seven
   months stale). No finding here was suppressed on those grounds; re-extraction is owed to project-manager.
