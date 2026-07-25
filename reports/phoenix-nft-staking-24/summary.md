# Run phoenix-nft-staking-24 — REGRESSION

- Type: Regression scan (new feature, cold scan of the new contract)
- Submodule: `9785bb9` → `d75229d`
- Date: 2026-07-24
- Verdict: **0 High · 0 Medium · 4 Low · 1 QA** + 2 spec-conformance (Law 2). No regressions, no incomplete fixes.

## Change set — story-028 (3 commits: `febb9b5`, `73398ca`, `d75229d`)
- `src/NudgeStreamer.sol` — NEW first-party contract (201L). Buffers bursty `(batchMinter, token)` donations and streams them linearly to zero over `duration`. Ownable + ReentrancyGuard + SafeERC20; ports PhlimboV2 linear-depletion math (recompute-rewardPerSecond-on-deposit-only). **Cold-scanned.**
- `src/BatchNFTMinterMultiToken.sol` (+43) — wiring: `nudgeStreamer` storage + `setNudgeStreamer` (onlyOwner, `address(0)`=disabled), `isNudgeToken` O(1) view, and a pre-snapshot flush loop in `batchMint` calling `pullPendingStream` for each whitelisted token inside `nonReentrant`.

This activated the standing **WATCH-23-nudgestreamer-wiring** note (both conditions — concrete implementation + wired consumer — now true).

## What passed (verified, not assumed)
- **Interface conformance:** NudgeStreamer matches INudgeStreamer signatures + msg.sender semantics.
- **Phlimbo port faithfulness:** `rewardPerSecond` recomputed ONLY in `collectNudge` + `registerStream`, never in `_settle`/`pullPendingStream`/view. No residual rate-drift (the run-18 M-01 / phlimbo Linear-Depletion class is genuinely avoided — traced: partial flush leaves `windowEnd` intact).
- **Solvency:** `_accrued` caps every settle at `buffer`; over-emission impossible; dust floors to protocol.
- **Reentrancy:** dual `nonReentrant`; settle transfers to the batchMinter (no receive hook); standard-token safe.
- **Wiring:** pre-snapshot, inside `nonReentrant`, `address(0)`-disabled and byte-for-byte backward-safe.

## Findings (all NEW; all on NudgeStreamer/wiring) → submissions/qa-report.md
- **L-01** — NudgeStreamer holds permissionless donor funds but has no rescue; buffers strand when a batchMinter is decommissioned / a token permanently de-whitelisted. (Law-3 footgun; recoverable under supported ops → Low.)
- **L-02** — `collectNudge` dust window-reset griefing throttles the nudge incentive to a decaying trickle. (Economically-irrational; no loss → Low.)
- **L-03** — Time-throttle-not-value-cap: NatSpec overclaims burst-capture prevention (false-sense-of-mitigation). WATCH-23 resolution. (Also F-028-01.)
- **L-04** — Streamer flush ignores the runtime payment-token skip → streamed buffer can leak to caller via the step-10 sweep under an owner repoint. (Misconfig-conditional.)
- **Q-01** — INudgeStreamer under-documents no-op/onlyOwner/recompute-on-deposit-only semantics the wiring relies on. (Also F-028-02.)

Two disputed severities (L-01: code Medium vs econ Low; L-02: Low vs Medium-availability) were arbitrated to **Low** by an independent severity pass with a Law-1 symmetry check (no live-exploit understatement).

## Spec-conformance (Law 2) → submissions/spec-conformance.md
- **F-028-01** — story-028's anti-snipe purpose only partially achieved (time-throttle, not value-cap). Cluster-adjacent to `858e9e80`/`521c20ad`/`43e8c486` (all wont-fix); disclosure block included; not an override.
- **F-028-02** — INudgeStreamer interface under-documentation.

## Ledger reconciliation (no status changes)
- `521c20ad` (M-01, wont-fix): **partially mitigated, NOT fixed** — immediate snipe defeated, winner-take-all race relocated to end of window. Do not mark fixed.
- `43e8c486` (run-22 M-01, wont-fix): aggregate ceiling **unchanged** by streamer (delayed ≤ `duration`). Not re-armed, not fixed.
- `858e9e80` (H-01, wont-fix): untouched.
- No regressions / no incomplete-fix signals (flush is additive + `address(0)`-gated).

## WATCH-23 disposition
Addressed this run. Resolution: the streamer is a genuine IMMEDIATE-burst mitigation but NOT an aggregate-cap; it does not fix the wont-fix over-funding cluster, and its NatSpec oversells that (L-03/F-028-01). Recommend keeping a lighter watch until the NatSpec is corrected and L-02 (reset-griefing) is triaged.
