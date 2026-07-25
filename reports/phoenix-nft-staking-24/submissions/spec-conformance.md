# Spec-Conformance Report (Law 2) — phoenix-nft-staking run-24

- Submodule: `9785bb9` → `d75229d` (story-028)
- Stories checked: **story-028** (commits `febb9b5`, `73398ca`, `d75229d`)
- Date: 2026-07-24

Story-028 was verified faithful on the load-bearing checks: **INudgeStreamer conformance PASS**, **PhlimboV2 linear-depletion port PASS** (recompute-on-deposit-only holds; no residual rate-drift — after a partial flush, `buffer/rate` still completes depletion exactly at the original `windowEnd`), and **batchMint wiring PASS** (pre-snapshot, inside `nonReentrant`, `address(0)`-disabled and backward-safe). Two deviations below.

---

## F-028-01 — Story's anti-snipe *purpose* is only partially achieved: time-throttle, not value-cap (story-unsafe / oversell)

- **Law impacted:** 2 (with Law-1 relevance to the accepted snipe cluster)
- **Contract:** `src/NudgeStreamer.sol` `pullPendingStream` / `_accrued` :164–200
- **Spec text (story-028 `febb9b5` body + `NudgeStreamer.sol` :20–23):** *"Buffers bursty donations … and streams them linearly to zero over a configured duration, so that whoever calls `batchMint` right after a burst can no longer capture a disproportionate share of the reward pot."*
- **Actual behavior:** Accrual is metered purely by wall-clock `elapsed`, capped at `buffer`. After `duration` elapses, `_accrued == buffer`, so a single qualifying `batchMint` captures the entire buffered burst. The mechanism raises the **time** cost of capture but does not reduce the total value extractable per qualifying cost, and does not touch the value-blind count-only gate that is the root cause of the snipe cluster.
- **Deviation:** The literal claim (a `batchMint` *right after* a burst captures ~0) is faithfully met. But the streamer is a time-throttle, not a value-cap: the aggregate ceiling (Σ buffer_i eventually payable per one qualifying cost) is unchanged, and a patient attacker still drains the full streamed buffer via a count-only-qualifying `batchMint` after the window. An owner who deploys NudgeStreamer believing it *mitigates* the burst-capture / over-funding snipe retains full (time-shifted) exposure. Reliance risk = false sense of mitigation.
- **Confidence:** high. **Not a new exploit** (no security escalation): the aggregate exposure is identical to, and already accepted under, the wont-fix cluster. This is a mitigation-completeness / oversell caveat.

### Disclose-when-re-filing (cluster-adjacent — mandatory)
- **Prior cluster entries named:** `858e9e80` (H-01, wont-fix), `521c20ad` (M-01, wont-fix), `43e8c486` (run-22 M-01, wont-fix, restored this session).
- **Their acceptance basis (quoted):** the NFT has no redemption value, ~6.7x margin, sunk cost; *"the pot is by construction a fraction of the cost of the `nudgeSize` mints required to qualify … If someone over-funds this contract beyond the mint cost and a bot snipes it, that is still correct behaviour; the error was in the sender."*
- **Re-file basis (why distinct, not a duplicate/override):** F-028-01 asserts **no new economic ceiling** — the aggregate exposure equals the already-accepted `43e8c486`. It is a documentation/intent footgun new to story-028: the streamer's NatSpec claims callers "can no longer capture a disproportionate share," which a competent owner may read as an aggregate bound and, on that belief, relax the funding discipline the wont-fix acceptances depend on. The prior wont-fixes are **not** overridden; F-028-01 rides alongside them.
- **Suggested disposition:** correct the NatSpec (bounds rate/timing of a single burst, not aggregate per qualifying cost; funding discipline remains load-bearing). If a wording fix is intended → `fix-pending` (per CLAUDE.md, "will fix" ⇒ fix-pending, never `acknowledged`). If accepted as-is → `acknowledged` is defensible since the cluster is already accepted.

---

## F-028-02 — `INudgeStreamer` interface under-documents load-bearing semantics the wiring relies on

- **Law impacted:** 2 (documentation faithfulness)
- **Contract:** `src/INudgeStreamer.sol` :15–27
- **Spec text (`INudgeStreamer.sol` :15–16):** *"///@dev msg.sender is a batchMinter  function pullPendingStream(address token) external;"*
- **Actual behavior / gap:** The frozen interface is silent on three semantics the implementation and `batchMint` depend on: (a) `pullPendingStream` silently **no-ops** for an unregistered token (`NudgeStreamer.sol` :166) — the property that lets `batchMint` loop blindly over the whole whitelist (`BatchNFTMinterMultiToken.sol` :441–443, *"Unregistered tokens are a cheap no-op … loop blindly"*); (b) `registerStream` is `onlyOwner` and reverts for non-whitelisted / non-multitoken targets; (c) the recompute-on-deposit-only invariant.
- **Deviation:** Doc-only; the concrete implementation is correct. A second implementer of `INudgeStreamer` could reasonably revert on an unregistered `pullPendingStream`, which would brick `batchMint`'s flush loop.
- **Confidence:** high.
- **Suggested disposition:** document the no-op-on-unregistered contract, the `onlyOwner` + whitelist guard, and the recompute-on-deposit-only invariant in the interface NatSpec.
