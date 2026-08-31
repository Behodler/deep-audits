> **Carryover QA report — audit 24** (cut down from `reports/phoenix-nft-staking/24/submissions/qa-report.md`).
> Retained below, still open / untriaged as of audit 26: **L-01, L-02, L-03, Q-01**.
> Removed as no longer live: **L-04** (`2d34673536…`) — **`fixed`** at `5015f1b`, re-verified
> still-fixed this run through two independent paths (the `:533` flush and the newly-cheap
> mid-mint-loop settle); it carries its own tripwire as `WATCH-26-01`.
> Labels are the originals — the gap at `L-04` is that removal, not an omission.
> Line numbers were accurate at the originating commit (`d75229d`); **re-verify against current
> HEAD (`9611312`)** before acting — `src/NudgeStreamer.sol` and
> `src/BatchNFTMinterMultiToken.sol` have both been rewritten in range since.

> ⚠ **`L-02` BELOW IS SUPERSEDED IN FRAMING BY §RE-FRAME (RUN-26), WHICH FOLLOWS IT.** The run-24
> griefing characterisation is **replaced, not supplemented**. Read the re-frame before acting on
> `L-02`, and in particular **do not** implement the run-24 recommendation to restrict
> `collectNudge` to known donors — run-26 measured that fix and it buys **0.11 percentage points**
> while breaking both production donors. The original text is retained verbatim below because the
> reader is entitled to see what was replaced.

> **Why this file exists.** `aaebb4b9b0…` was re-confirmed present and materially **re-framed** by
> run-26. Without this file that re-frame — a reversed remediation and a corrected quantitative
> claim — would have reached no deliverable and lived only in the ledger and `dedup-report.md`.
> That is the Law-1 "visible channel" failure this file closes.

---

# QA Report — phoenix-nft-staking run-24

- Submodule: `9785bb9` → `d75229d` (story-028: NudgeStreamer + batchMint wiring)
- Mode: REGRESSION (new feature: `src/NudgeStreamer.sol`, cold scan; `src/BatchNFTMinterMultiToken.sol` wiring)
- Date: 2026-07-24
- Severity summary **as retained here**: **0 High · 0 Medium · 3 Low · 1 QA** (originally 4 Low · 1 QA; `L-04` removed as fixed)

All findings below are on the newly-landed `NudgeStreamer` and its wiring. Two disputed severities (L-01, L-02) were arbitrated down to Low by an independent severity pass, with a Law-1 symmetry check confirming no live-exploit path is being understated. No PoC is required (C4 mandates PoCs only for High/Medium).

---

## L-01 — NudgeStreamer holds permissionless donor funds but has no rescue; buffers can strand when a batchMinter is decommissioned or a funded token is permanently de-whitelisted

**Contract:** `src/NudgeStreamer.sol` (whole contract — no `rescue`/owner-withdraw exists); `collectNudge` :137–156; `pullPendingStream` :164–169; `_settle` :182–190. Coupled to `src/BatchNFTMinterMultiToken.sol` `batchMint` flush loop :445–451, `setNudgeTokenWhitelist` :250–274, `setNudgeStreamer` :230–233.

**Root cause:** Funds in `streams[batchMinter][token].buffer` exit only via `_settle`, reachable only through `pullPendingStream`, whose storage key is `msg.sender` = the batchMinter. The batchMinter invokes it solely inside `batchMint`'s loop over its **current** `getNudgeTokens()` whitelist. `collectNudge` gates deposits on `s.duration != 0` only — it never re-checks `isNudgeToken`, so donors can keep funding a stream for a token that is no longer whitelisted. `NudgeStreamer` has no owner rescue of any kind.

**Impact (Low — Law-3 footgun):** Under all *supported* operations the funds are recoverable — while `duration != 0`, `collectNudge`'s pre-settle continues pushing accrued to the batchMinter on any donor call, and de-whitelist / streamer-repoint both reverse cleanly (re-whitelist the token, or point `nudgeStreamer` back and flush). Value is genuinely *lost* only in terminal owner actions: **decommissioning a batchMinter while its buffer is non-empty** (buffers are keyed to a now-dead address) or permanently abandoning a de-whitelisted/old-streamer path. These are non-obvious consequences of ordinary owner maintenance → in scope as an operational hazard, not a value-leak Medium. Note a naive "add owner rescue" fix has its own hazard: it would let the owner divert third-party donations, so the pass-through-no-custody design is defensible.

**Recommendation / safe config:** Before decommissioning a batchMinter or permanently repointing/removing a funded token, **drain the streamer first** (let `batchMint` flush all registered tokens, or point `nudgeStreamer` back long enough to settle). Optionally: have `collectNudge` revert (or emit a warning) when `!isNudgeToken`, and/or gate `setNudgeTokenWhitelist(token,false)` on a zero buffer, so donors cannot fund a dead stream.

> **RUN-26 ANNOTATIONS on `4a1d8edc929b…` (status unchanged — `open`, Low).**
>
> 1. **Magnitude re-sized (ECON-26-M1).** The permanently-buffered float is `duration × inflow_rate`,
>    **structurally and always** — not "leftover dust". At the pinned mainnet `duration = 7 days`
>    the streamer holds **seven days of aggregate nudge inflow at all times**, across
>    `{USDC, phUSD, Kendu}` per registered batchMinter. Size the stranding risk at
>    `7 × daily inflow × registered pairs`.
> 2. **It now compounds with two run-26 findings, and must not be collapsed into either.**
>    Run-26 `L-01`'s escape hatch from the mint brick — `setNudgeTokenWhitelist(token,false)` — **is
>    the action that triggers this entry**, converting an availability outage into permanently
>    stranded value; and run-26 `L-04` is the **pre-commission mirror** of this entry's
>    decommission case (*"story-032 opened a new route into needing the rescue you don't have"*).
> 3. **One change closes three items.** A `rescueERC20`-equivalent, or a `deregisterStream`, on
>    `NudgeStreamer` closes **this entry**, **run-26 `L-04`**, and the permanent-de-whitelist
>    stranding together. Weigh that against the original counter-argument above (a rescue lets the
>    owner divert donor funds) — a `deregisterStream` that settles to the registered batchMinter
>    rather than to an owner-chosen address satisfies both.

---

## L-02 — `collectNudge` window-reset griefing: permissionless dust deposits throttle the nudge incentive to a decaying trickle

**Contract:** `src/NudgeStreamer.sol` `collectNudge` :137–156 (settle at :146, then `rewardPerSecond = buffer * PRECISION / duration` recompute over a fresh full window from now, :152–153).

**Root cause:** `collectNudge` is permissionless (any caller supplying `amount`). Every call settles accrued at the old rate then re-amortizes the entire remaining buffer over a **new** full `duration` from `now`. An attacker calling `collectNudge(batchMinter, token, 1 wei)` each block perpetually resets the window, so the buffer drips out as a geometrically-decaying trickle and the tail never fully drains.

**Impact (Low — economically-irrational griefing):** No theft and no value loss — settled funds always flow to the batchMinter; only the *timing* of an already-metered drip is stretched. The attacker pays perpetual per-block gas for zero profit (self-punishing), the affected feature is an optional anti-MEV smoothing incentive (not core mint/stake availability), and the owner has a backstop (`setNudgeStreamer(address(0))` restores direct-donation immediacy, at the cost of the feature). This does not meet the C4 "protocol function/availability impacted" Medium bar.

**Recommendation:** Consider a minimum deposit size or a cooldown/dust-threshold on `collectNudge` window resets, or restrict `collectNudge` to known donors if immediacy of the incentive is operationally important. Otherwise document the `setNudgeStreamer(0)` backstop as the mitigation.

---

### RE-FRAME (RUN-26) — `aaebb4b9b056d02beb26e1ba3e119d880686356de828177d483c17163b284e45`

- **Ledger entry:** `aaebb4b9b056…` · **Original label:** L-02 (run `phoenix-nft-staking-24`)
- **Severity:** Low — **unchanged**, and committed at Low by the run-26 econ tier
- **Status:** `open` (untriaged) — **unchanged**
- **First seen:** `phoenix-nft-staking-24` (`d75229d`) · **Re-confirmed present as of:** `phoenix-nft-staking-26` (`9611312`)
- **Location at HEAD:** `src/NudgeStreamer.sol` — the claim at `:19-23` (sentence at `:20-21`), mechanism `collectNudge` `:152-211`, `_accrued` `:250-272`
- **Fingerprint:** unchanged this run. No new fingerprint was minted; only `lastSeenRun` was bumped.
- **This is a REPLACEMENT of the framing above, not a supplement.**

**The griefing framing must stop being the primary characterisation.** A griefer's entire marginal
contribution is **0.11 percentage points**: a griefer poking `collectNudge` every block leaves
**36.79%** released at `t = D`, against **36.68%** released under an ordinary hourly donor cadence.
The attacker is not the mechanism — the *ordinary donor cadence* is.

**Why the framing matters, and why it is not cosmetic.** Filed as griefing, the natural fix is to
**permission `collectNudge`**. That fix buys 0.11 pp and **breaks both production donors**:
`NudgeRatchet.dispatch` and `BalancerPoolerV2._donate` both call `collectNudge` unconditionally,
neither is the streamer's owner, and there is no donation-disable switch to fall back on
(story-046 removed the direct-transfer fallback deliberately). **Do NOT permission
`collectNudge`.** That remediation must not be filed against this entry.

**The correct framing — an intent gap.** `src/NudgeStreamer.sol:19-23` states that the contract
*"[buffers] bursty donations per `(batchMinter, token)` and streams them **linearly to zero over a
configured `duration`**"*. It does not. Because every deposit re-amortises the whole remaining
buffer over a fresh full window, the streamer is a **first-order low-pass filter with time constant
`duration`** — a behaviour that is unachievable-as-described under *any* repeated-deposit regime,
griefer or not:

- **~63% of a burst is still retained at the nominal window end.** Analytically `1 − 1/e ≈ 63.2%`;
  measured **61.59% retained / 38.40% released** over 28 discrete deposits.
- **⚠ ORIENTATION CORRECTION.** `1/e ≈ 36.8%` is the **RELEASED** share, not the retained share. An
  earlier note in this project's ledger quoted *"~36.7% **retained**"*; that figure was
  **orientation-inverted and must not be requoted**. The corrected figure independently matches the
  **63.26%** measured by the run-18 depletion PoC (ledger `b58b172e2a…`, `fixed`) — two unrelated
  derivations of the same constant agreeing is what raises this from arithmetic to a confirmed
  property.
- **99% delivery takes `D · ln 100 = 32.2 days` against a configured `duration` of 7 days** — a
  **4.6× stretch**.
- **Steady-state throughput is CORRECT** (`B* = i·D`, release rate `= i`). What is wrong is a
  **permanent float**, which is also why this is not a value-leak finding: nothing is lost, and the
  error direction *favours* the protocol.

**Remediation (replaces the run-24 recommendation).** **Documentation, plus a runbook note that
`duration` sizes a TIME CONSTANT, not a drain time.** Not a code change. Specifically **not**
permissioning `collectNudge`, and specifically **not** a minimum-deposit or cooldown gate on the
window reset — both target the griefer, who contributes 0.11 pp. If an operator needs a genuine
drain time `T`, they must size `duration` against the filter (`T ≈ D · ln(1/ε)`), not against `T`.

**Law-2 status: FAITHFUL.** The *behaviour* conforms to its story — story-028 §Concerns explicitly
blessed window-reset-on-deposit as *"accepted phlimbo behaviour… deliberate"*. The defect is
confined to the **headline NatSpec** at `:19-23` (and its echoes at story-028 `:19`,
`docs/multi-token-nudge.md:463` and `:568-572`) claiming a behaviour the accepted design does not
produce. No `story-unsafe` flag.

**Two suppressions that this re-frame does NOT disturb — checked this run, and they survive.**
`858e9e807a…` (H-01, `wont-fix`) and `521c20ad48…` (M-01, `wont-fix`) rest on story-030's metering
sentence. The run-26 econ tier probed that ground specifically and reports it **intact**: nobody can
**accelerate** release (`rate = buffer/D`, accrual capped at `buffer`, the fastest full drain is
still "wait `duration`"), and the failure direction is *slower* release — a smaller instantaneous
pot, which under story-030's own clearing-price argument is *better* price discovery. **Those two
wont-fixes stand; nothing here reopens them.**

**⚠ DO NOT COLLAPSE with `MR-26-01`** (sub-wei truncation forfeiture at `src/NudgeStreamer.sol:240`,
parked in `manual-review.json`). Window-**reset** and **truncation** are different mechanisms with
different fixes; collapsing them loses one. Nor with run-26 `Q-01` / `F-01-031`, which are a
different NatSpec claim (pooled custody) at a different site.

---

## L-03 — Time-throttle, not value-cap: `NudgeStreamer` NatSpec overclaims burst-capture prevention (false-sense-of-mitigation footgun)

**Contract:** `src/NudgeStreamer.sol` NatSpec :19–33 ("so that whoever calls `batchMint` right after a burst can no longer capture a disproportionate share of the reward pot"); mechanism `_accrued` :195–200 (`min(rewardPerSecond*elapsed/PRECISION, buffer)`); wiring `src/BatchNFTMinterMultiToken.sol` :445–453.

**Root cause:** The streamer meters accrual purely by wall-clock elapsed time, capped at `buffer`. Once `elapsed >= duration`, `_accrued == buffer`, so a single qualifying `batchMint` flushes the **entire** buffer of every whitelisted token into the pot before the snapshot. It raises the **time** cost of capture but does **not** reduce the total value extractable, and does not touch the value-blind count-only gate that is the root cause of the accepted (wont-fix) snipe cluster. The literal claim ("a `batchMint` *right after* a burst captures ~0") is faithfully met — a same-block flush accrues 0 — but the aggregate ceiling a sole patient searcher extracts per one qualifying cost is unchanged from ledger `43e8c486` (run-22 M-01), merely delayed by up to `duration`.

**Impact (Low — Law-3 footgun; no new economic exposure):** This does **not** re-arm `43e8c486` (the aggregate ceiling is unchanged) and does **not** fix it. The hazard is reliance: a competent, non-malicious owner reading the NatSpec summary may believe the streamer *bounds* disproportionate capture and relax the funding discipline that the wont-fix acceptances of `858e9e80` (H-01) and `43e8c486` (M-01) explicitly rest on ("the pot is by construction a fraction of the cost of the `nudgeSize` mints required to qualify"). See also the spec-conformance report (F-028-01).

**Recommendation:** Correct the NatSpec to state the streamer bounds the *rate/timing* of a single burst, not the *aggregate per qualifying cost*, and that the `43e8c486`/`858e9e80` funding discipline (keep Σ pot_i < one qualifying cost) remains load-bearing. Related: ledger `521c20ad` (MEV front-run, wont-fix) is **partially mitigated but NOT fixed** — the winner-take-all race is relocated to the end of the streaming window, not eliminated.

> **RUN-26 ANNOTATION on `6f46ec80f1fb…` (status unchanged — `open`, Low).** Re-confirmed present at
> `9611312`. **Keep separate from run-26 `Q-01` / `F-01-031`:** this entry is the *burst-capture /
> time-throttle-not-value-cap* overclaim; those are a **new** claim at a **new** site (the
> pooled-custody invariant asserted *"by construction"*, introduced at `2ba764e`). Same class —
> falsely-exhaustive in-source guarantee on a load-bearing property, which now has **seven** live
> members in this ledger — different claims, different fixes. A single documentation-accuracy sweep
> is the efficient remediation for the class; it is not a reason to collapse the entries.

---

## Q-01 — `INudgeStreamer` interface under-documents the no-op / onlyOwner / recompute-on-deposit-only semantics that `batchMint` structurally relies on

**Contract:** `src/INudgeStreamer.sol` :15–27 (and the implementation semantics in `src/NudgeStreamer.sol` :110, :164–169).

**Root cause:** The frozen interface is silent on three load-bearing semantics the wiring depends on: (a) `pullPendingStream` **silently no-ops** for an unregistered token (`NudgeStreamer.sol` :166) — the property that lets `batchMint` loop blindly over the whole whitelist; (b) `registerStream` is `onlyOwner` and reverts for non-whitelisted / non-multitoken targets; (c) the recompute-on-deposit-only invariant. A second implementer of `INudgeStreamer` could reasonably revert on an unregistered `pullPendingStream`, which would brick `batchMint`'s flush loop.

**Impact (QA — documentation):** The concrete implementation is correct; this is an interface-contract documentation gap that could mislead a future re-implementer. See spec-conformance report (F-028-02).

**Recommendation:** Document the no-op-on-unregistered contract of `pullPendingStream`, the `onlyOwner` + whitelist guard on `registerStream`, and the recompute-on-deposit-only invariant directly in `INudgeStreamer`.

> **RUN-26 ANNOTATION on `cf332bf46c6c…` — ⚠ PARTIALLY ADDRESSED, DO NOT CLOSE. Status unchanged
> (`open`, QA).** Two run-26 findings sit adjacent to this entry and **neither is it**: run-26
> `L-05` is an **unvalidated setter** (`setNudgeStreamer` accepts any address with no structural
> probe), and this entry is the **`INudgeStreamer` documentation** gap. Limb (a) — the
> no-op-on-unregistered contract — is precisely what run-26 verified at `src/NudgeStreamer.sol:222`
> and what run-26 `L-01` depends on, so the property is now audited but still **undocumented in the
> interface**. Fix them together; do not close this entry against either.
> *A third adjacent item, run-26 `Q-03` (missing interface declaration / compiler enforcement of the
> duck-typed guard), was **WITHDRAWN before publication** — see `../qa-report.md` §"Withdrawn before
> publication". Its withdrawal changes nothing about this entry, which remains open.*

---

## Reconciliation note (no status changes proposed)

- `521c20ad` (M-01, wont-fix) — MEV first-claimer front-run: **partially mitigated, NOT fixed**. The immediate same-block snipe is defeated; the winner-take-all race relocates to the end of the streaming window. Do not mark fixed.
- `43e8c486` (run-22 M-01, wont-fix) — aggregate over-funding: **ceiling unchanged** by the streamer (delayed ≤ `duration`). Not re-armed, not fixed.
- `858e9e80` (H-01, wont-fix) — value-blind gate: untouched by story-028.
- No regressions and no incomplete-fix signals: the flush is purely additive and `address(0)`-gated (byte-for-byte prior behavior when disabled).

*4naly3er automated QA/gas output not attached this run (2-file additive regression; all surfaces hand-analyzed). Re-run `/full-audit --full` if a full automated sweep is desired.*

---

*Carryover assembled by run-26. **No status was changed by this file** — all four retained entries
stay exactly as the human left them, and no `fixed` is proposed against any of them. Triage with
`/ledger phoenix-nft-staking`; the complete set of undealt-with findings is
`/open-issues phoenix-nft-staking`.*
