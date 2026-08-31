# QA Report — phoenix-nft-staking run-24

- Submodule: `9785bb9` → `d75229d` (story-028: NudgeStreamer + batchMint wiring)
- Mode: REGRESSION (new feature: `src/NudgeStreamer.sol`, cold scan; `src/BatchNFTMinterMultiToken.sol` wiring)
- Date: 2026-07-24
- Severity summary: **0 High · 0 Medium · 4 Low · 1 QA**

All findings below are on the newly-landed `NudgeStreamer` and its wiring. Two disputed severities (L-01, L-02) were arbitrated down to Low by an independent severity pass, with a Law-1 symmetry check confirming no live-exploit path is being understated. No PoC is required (C4 mandates PoCs only for High/Medium).

---

## L-01 — NudgeStreamer holds permissionless donor funds but has no rescue; buffers can strand when a batchMinter is decommissioned or a funded token is permanently de-whitelisted

**Contract:** `src/NudgeStreamer.sol` (whole contract — no `rescue`/owner-withdraw exists); `collectNudge` :137–156; `pullPendingStream` :164–169; `_settle` :182–190. Coupled to `src/BatchNFTMinterMultiToken.sol` `batchMint` flush loop :445–451, `setNudgeTokenWhitelist` :250–274, `setNudgeStreamer` :230–233.

**Root cause:** Funds in `streams[batchMinter][token].buffer` exit only via `_settle`, reachable only through `pullPendingStream`, whose storage key is `msg.sender` = the batchMinter. The batchMinter invokes it solely inside `batchMint`'s loop over its **current** `getNudgeTokens()` whitelist. `collectNudge` gates deposits on `s.duration != 0` only — it never re-checks `isNudgeToken`, so donors can keep funding a stream for a token that is no longer whitelisted. `NudgeStreamer` has no owner rescue of any kind.

**Impact (Low — Law-3 footgun):** Under all *supported* operations the funds are recoverable — while `duration != 0`, `collectNudge`'s pre-settle continues pushing accrued to the batchMinter on any donor call, and de-whitelist / streamer-repoint both reverse cleanly (re-whitelist the token, or point `nudgeStreamer` back and flush). Value is genuinely *lost* only in terminal owner actions: **decommissioning a batchMinter while its buffer is non-empty** (buffers are keyed to a now-dead address) or permanently abandoning a de-whitelisted/old-streamer path. These are non-obvious consequences of ordinary owner maintenance → in scope as an operational hazard, not a value-leak Medium. Note a naive "add owner rescue" fix has its own hazard: it would let the owner divert third-party donations, so the pass-through-no-custody design is defensible.

**Recommendation / safe config:** Before decommissioning a batchMinter or permanently repointing/removing a funded token, **drain the streamer first** (let `batchMint` flush all registered tokens, or point `nudgeStreamer` back long enough to settle). Optionally: have `collectNudge` revert (or emit a warning) when `!isNudgeToken`, and/or gate `setNudgeTokenWhitelist(token,false)` on a zero buffer, so donors cannot fund a dead stream.

---

## L-02 — `collectNudge` window-reset griefing: permissionless dust deposits throttle the nudge incentive to a decaying trickle

**Contract:** `src/NudgeStreamer.sol` `collectNudge` :137–156 (settle at :146, then `rewardPerSecond = buffer * PRECISION / duration` recompute over a fresh full window from now, :152–153).

**Root cause:** `collectNudge` is permissionless (any caller supplying `amount`). Every call settles accrued at the old rate then re-amortizes the entire remaining buffer over a **new** full `duration` from `now`. An attacker calling `collectNudge(batchMinter, token, 1 wei)` each block perpetually resets the window, so the buffer drips out as a geometrically-decaying trickle and the tail never fully drains.

**Impact (Low — economically-irrational griefing):** No theft and no value loss — settled funds always flow to the batchMinter; only the *timing* of an already-metered drip is stretched. The attacker pays perpetual per-block gas for zero profit (self-punishing), the affected feature is an optional anti-MEV smoothing incentive (not core mint/stake availability), and the owner has a backstop (`setNudgeStreamer(address(0))` restores direct-donation immediacy, at the cost of the feature). This does not meet the C4 "protocol function/availability impacted" Medium bar.

**Recommendation:** Consider a minimum deposit size or a cooldown/dust-threshold on `collectNudge` window resets, or restrict `collectNudge` to known donors if immediacy of the incentive is operationally important. Otherwise document the `setNudgeStreamer(0)` backstop as the mitigation.

---

## L-03 — Time-throttle, not value-cap: `NudgeStreamer` NatSpec overclaims burst-capture prevention (false-sense-of-mitigation footgun)

**Contract:** `src/NudgeStreamer.sol` NatSpec :19–33 ("so that whoever calls `batchMint` right after a burst can no longer capture a disproportionate share of the reward pot"); mechanism `_accrued` :195–200 (`min(rewardPerSecond*elapsed/PRECISION, buffer)`); wiring `src/BatchNFTMinterMultiToken.sol` :445–453.

**Root cause:** The streamer meters accrual purely by wall-clock elapsed time, capped at `buffer`. Once `elapsed >= duration`, `_accrued == buffer`, so a single qualifying `batchMint` flushes the **entire** buffer of every whitelisted token into the pot before the snapshot. It raises the **time** cost of capture but does **not** reduce the total value extractable, and does not touch the value-blind count-only gate that is the root cause of the accepted (wont-fix) snipe cluster. The literal claim ("a `batchMint` *right after* a burst captures ~0") is faithfully met — a same-block flush accrues 0 — but the aggregate ceiling a sole patient searcher extracts per one qualifying cost is unchanged from ledger `43e8c486` (run-22 M-01), merely delayed by up to `duration`.

**Impact (Low — Law-3 footgun; no new economic exposure):** This does **not** re-arm `43e8c486` (the aggregate ceiling is unchanged) and does **not** fix it. The hazard is reliance: a competent, non-malicious owner reading the NatSpec summary may believe the streamer *bounds* disproportionate capture and relax the funding discipline that the wont-fix acceptances of `858e9e80` (H-01) and `43e8c486` (M-01) explicitly rest on ("the pot is by construction a fraction of the cost of the `nudgeSize` mints required to qualify"). See also the spec-conformance report (F-028-01).

**Recommendation:** Correct the NatSpec to state the streamer bounds the *rate/timing* of a single burst, not the *aggregate per qualifying cost*, and that the `43e8c486`/`858e9e80` funding discipline (keep Σ pot_i < one qualifying cost) remains load-bearing. Related: ledger `521c20ad` (MEV front-run, wont-fix) is **partially mitigated but NOT fixed** — the winner-take-all race is relocated to the end of the streaming window, not eliminated.

---

## L-04 — Streamer flush ignores the runtime payment-token skip → streamed buffer can leak to the caller via the step-10 sweep (owner-repoint misconfig)

**Contract:** `src/BatchNFTMinterMultiToken.sol` flush loop :445–451 (loops **every** whitelist token) vs `_snapshotRewards` payment-token skip ~:558 and step-10 dust sweep ~:480–482.

**Root cause:** `_snapshotRewards` skips any whitelist entry equal to the derived payment token (the §4.1 runtime guard for the owner-repoint case). The streamer flush loop does **not** apply that skip — it calls `pullPendingStream` for every whitelisted token. If the owner later repoints `tokenMinter`/`dispatcherIndex` so a streamer-registered whitelisted token *becomes* the derived payment token, step 3.5 dumps that token's streamed buffer into the batchMinter's payment-token balance, the snapshot skips it, and step 10 refunds the entire payment-token balance — including the just-flushed stream — to `msg.sender`.

**Impact (Low — misconfig-conditional):** Requires the owner-repoint misconfiguration the §4.1 skip was built for. The streamer widens that pre-existing edge from "idle pot swept" to "streamer buffer actively drained into the sweep." No unprivileged theft absent the misconfig.

**Recommendation:** Apply the same payment-token skip inside the flush loop (skip `pullPendingStream` for the derived payment token), or re-derive/validate the reward-vs-payment asset separation on repoint. Related to ledger `fb17fc6d` (M-06, dispatcherIndex/primeToken coupling) and the run-21 M-01 sweep findings.

---

## Q-01 — `INudgeStreamer` interface under-documents the no-op / onlyOwner / recompute-on-deposit-only semantics that `batchMint` structurally relies on

**Contract:** `src/INudgeStreamer.sol` :15–27 (and the implementation semantics in `src/NudgeStreamer.sol` :110, :164–169).

**Root cause:** The frozen interface is silent on three load-bearing semantics the wiring depends on: (a) `pullPendingStream` **silently no-ops** for an unregistered token (`NudgeStreamer.sol` :166) — the property that lets `batchMint` loop blindly over the whole whitelist; (b) `registerStream` is `onlyOwner` and reverts for non-whitelisted / non-multitoken targets; (c) the recompute-on-deposit-only invariant. A second implementer of `INudgeStreamer` could reasonably revert on an unregistered `pullPendingStream`, which would brick `batchMint`'s flush loop.

**Impact (QA — documentation):** The concrete implementation is correct; this is an interface-contract documentation gap that could mislead a future re-implementer. See spec-conformance report (F-028-02).

**Recommendation:** Document the no-op-on-unregistered contract of `pullPendingStream`, the `onlyOwner` + whitelist guard on `registerStream`, and the recompute-on-deposit-only invariant directly in `INudgeStreamer`.

---

## Reconciliation note (no status changes proposed)

- `521c20ad` (M-01, wont-fix) — MEV first-claimer front-run: **partially mitigated, NOT fixed**. The immediate same-block snipe is defeated; the winner-take-all race relocates to the end of the streaming window. Do not mark fixed.
- `43e8c486` (run-22 M-01, wont-fix) — aggregate over-funding: **ceiling unchanged** by the streamer (delayed ≤ `duration`). Not re-armed, not fixed.
- `858e9e80` (H-01, wont-fix) — value-blind gate: untouched by story-028.
- No regressions and no incomplete-fix signals: the flush is purely additive and `address(0)`-gated (byte-for-byte prior behavior when disabled).

*4naly3er automated QA/gas output not attached this run (2-file additive regression; all surfaces hand-analyzed). Re-run `/full-audit --full` if a full automated sweep is desired.*
