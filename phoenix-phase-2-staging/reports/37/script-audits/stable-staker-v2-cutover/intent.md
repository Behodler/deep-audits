# Intent — stable-staker-v2-cutover (run-37, DELTA ONLY: 91ed727..1349be8)

Scope: commit 1349be8 "Cutover: ZERO set-aside buffer for V2 on the sDOLA destination strategy".
No `[story-NNN]` tag. The rest of the cutover is out of scope for this run.

## Authoritative story text (Law 2) — what the stories say about the buffer
- Story 091 (`auto-complete`, phStaging2-stable-staker-v2/091-cutover-sdola-strategy-source-destination-split.md)
  - L97: "Read V1's buffer pct from the source strategy and apply it to the destination for V2 (`setSetAsideBuffer(V2, pct)`). Recipient is V2 on the destination."
  - L195-197 Decision 6: "V2's buffer pct on the destination = V1's pct read from the source in Phase 0."
- Story 082 (`auto-complete`) L73: Phase 4 `setSetAsideBuffer(v2, <value read from V1>)`; L172 expects DOLA 10 / USDC 10 / USDe 25.
- Story 089 (DeployMocks, `auto-complete`): V2 on the mock sDOLA strategy at 10% + recipient V2 (UI mock; not a rehearsal).
- No story in `~/code/product-owner/stories/phStaging2/` (all state folders, all sprints; latest is 097) authorises a
  zero buffer on the sDOLA destination. The commit therefore deviates from 091 Decision 6 / 082 L73 as written.

## Stated purpose of the delta (commit message + `_targetBufferPct` NatSpec)
- [x] DOLA: V2's `setAsideBufferSize` on the sDOLA ERC4626YieldStrategy is **0** (fresh strategy default; Phase 4
      calls `setSetAsideBuffer(V2, 0)` only if a resumed run finds a non-zero value).
- [x] USDC / USDe: unchanged — V2 gets V1's pct copied from the (same) source strategy.
- [x] Phase 7 still repoints the sDOLA strategy's `setAsideBufferRecipient` to V2 (unread while every client pct is 0).
- [x] Keying is on the destination STRATEGY (`_destinationStrategyFor(t) == sdolaStrategy`), not the token.
- [x] Verifier (`VerifyStableStakerV2Cutover`) inherits the predicate: asserts 0 on sDOLA, V1's pct elsewhere.
- [x] Fork test: `assertGt(sourcePct(V1), 0)` and `assertEq(sys.setAsideBufferSize(v2), 0)`.

## Safety premise the delta rests on (verified in side-effects.json)
- `StableStakerV2._routeExit` reads V2's idle balance only when `totalBalanceOf(V2) < principalOf(V2)`.
- Claim: on the sDOLA strategy that condition cannot become true, because (i) sDOLA's DOLA-per-share is monotone
  non-decreasing, and (ii) every strategy rounding is protocol-favouring.

## Declared pre-conditions (require before/at the write)
- Phase 4 L1022-1037: V2 client set, V2 pool empty, V2 idle == 0, `setYieldStrategy` landed.
- `_destinationStrategyFor(DOLA)` reverts while `sdolaStrategy == 0` (no silent fallback to autoDOLA).

## Declared post-conditions
- Phase 4 L1043-1045: `_donePoolBufferCopied(t)` i.e. `setAsideBufferSize(V2) == _targetBufferPct(t)`.
- Phase 8 L1496-1499: same equality re-asserted; L1500-1501 recipient == V2 when the strategy exposes one.
- Verifier L268-275: same predicate against live chain.

## Runbook / doc text not updated by the delta
- `package.json` L49 `//StableStakerV2Cutover`: "set-aside buffer pct copied from V1's source" (stale for DOLA).
- Script header NatSpec L68-73 WAS updated.
