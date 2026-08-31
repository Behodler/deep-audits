# Contract Profiles — reflax-yield-vault @ ad12cb1 (run 15, REGRESSION 2f6774d → ad12cb1)

Local-analysis profiles for the story-047/048 regression window. Downstream agents
may treat "verified properties" as axioms; everything under **Scanner attention**
is deliberately deferred to interaction / econ / story-faithfulness scanners.

| Profile | Contract | Role | Status vs baseline |
|---|---|---|---|
| `ERC4626MarketYieldStrategy.profile.json` | `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` | PRIMARY (full) | CHANGED (story-047) |
| `AYieldStrategy.profile.json` | `src/AYieldStrategy.sol` | scope-context parent (full — owns all accounting since 045/046 hoist) | CHANGED (story-047 + 048) |
| `interfaces.light.profile.json` | IYieldStrategy (CHANGED), IAMMAdapter, ICurveRouterNG, IPausable + out-of-scope ERC4626YieldStrategy light note | interfaces (light) | IYieldStrategy CHANGED |
| `CurveAMMAdapter.profile.json` | `src/AMMAdapters/CurveAMMAdapter.sol` | carried forward VERBATIM from run-12 | UNCHANGED (verified `git diff 2306719..ad12cb1 -- src/AMMAdapters/ AMMRoutes.json` = empty) |

## Semantic diff — story-047 (933620d): global setAsideBufferRecipient

OLD behaviour: on a buffered skim, `_distributeBuffer` looped over clients and
`safeTransfer`red each client its own proportional set-aside (`buf`) — the buffer
was a **per-client reserve** ("absorb below-par dips", per still-stale NatSpec).

NEW behaviour:
- `AYieldStrategy` gains `address public setAsideBufferRecipient` (default 0 = unset)
  + `setSetAsideBufferRecipient(address)` (onlyOwner, rejects zero) + event.
- `_distributeBuffer` (both concretes, kept in sync) only **sums** per-client `buf`
  into `totalSetAside`, then makes **one aggregate transfer** to
  `setAsideBufferRecipient`; remainder to the skim `recipient` as before. Rounding
  dust still favors `recipient`; `skimSurplus` return value still reduced by
  `totalSetAside`.
- LOUD GUARD: if `totalBufferShares > 0` while the recipient is unset, the skim
  **reverts** (`"AYieldStrategy: setAsideBufferRecipient not set"`) instead of
  silently misrouting. Zero-buffer deployments never read the new variable
  (back-compat fast path intact). Guard sits after the swap but full-tx revert
  means no funds move.
- Net effect: set-aside value is **redirected from the clients to one global
  protocol sink** (intended: stable-staker). Clients silently lose the dip-absorption
  reserve the in-code docs still promise them.

## Semantic diff — story-048 (ad12cb1)

1. **creditedPrincipal fix** — `ERC4626YieldStrategy._acquireShares` (OUT OF SCOPE,
   noted for parent clarity): books `vault.previewRedeem(sharesReceived)` instead of
   the raw nominal `amount`, so entry fees / share round-down no longer over-credit
   principal. The in-scope **market strategy is untouched** — it already credited a
   slippage-haircut value. The base books whatever the hook reports; base invariant
   unaffected.
2. **Preview functions** — `previewDeposit`/`previewRedeem` added to
   `ERC4626YieldStrategy` only (delegating views). Not in `IYieldStrategy`, **not**
   on the market strategy (where `vault.preview*` would be the wrong oracle anyway).
3. **Withdrawal timing** — `AYieldStrategy`: `WAITING_PERIOD` 24h → **6h**,
   `EXECUTION_WINDOW` 48h → **72h**, `TOTAL_DURATION` 72h → **78h**. The two-phase
   `totalWithdrawal` anti-rug reaction window shrank **4x**; the owner's execution
   window widened 1.5x. State-machine logic itself unchanged.

## New local findings (this window)

| ID | Sev | Where | Summary |
|---|---|---|---|
| LOCAL-BASE-047-001 | local-low (footgun) | `src/AYieldStrategy.sol:51-53, 318-341` | Stale NatSpec still promises per-client buffer return ("returned to the client… reserve to absorb below-par dips"; front-run quirk reasoned as self-benefit) — contradicts story-047 aggregated-to-recipient flow; owner configuring from in-code docs is surprised. |
| LOCAL-BASE-048-001 | local-info | `src/AYieldStrategy.sol:414`, `src/interfaces/IYieldStrategy.sol:101` | Stale "24-hour waiting / 48-hour execution" doc comments vs 6h/72h constants. |
| LOCAL-BASE-048-002 | local-low (trust shift) | `src/AYieldStrategy.sol:84-86` | Rugpull-protection delay cut 24h→6h with no documented rationale; downstream consumers of the 24h guarantee silently lose it → story-faithfulness check. |
| LOCAL-BASE-047-002 | local-info | `src/AYieldStrategy.sol:352-357` | Recipient can be repointed but never cleared to zero; disabling redirection requires zeroing every client buffer. Ops note. |
| LOCAL-MKT-047-001 | local-info | market strategy (absent API) | Preview functions exist only on the direct strategy; integrators coded against them revert on the market strategy. |
| LOCAL-MKT-047-002 | local-info | `…/ERC4626MarketYieldStrategy.sol:368` | Aggregate buffer transfer emits no strategy-level event; recipient-vs-buffer realized split unreconstructable from strategy events. |

Carried (still present, previously ledgered/profiled): LOCAL-MKT-001…006,
LOCAL-BASE-001/002, QA-09 (relinquish-to-zero orphan).

## Scanner attention (deferred, changed-code focused)

1. **Buffer redirection consumer side** → interaction/econ + story-faithfulness:
   does the intended `setAsideBufferRecipient` (stable-staker — likely the
   integration leg of stable-staker M-05, ledger `ss7m5/0dca43f3`) correctly absorb
   bare aggregated ERC20 inflows? Do any clients (SYA) still assume they get their
   buffer back as a dip reserve?
2. **6h anti-rug window** → story-faithfulness: is the relaxation blessed by a
   story, and does any sibling doc still promise 24h?
3. Standing carried lead: **vault-rate vs AMM-realizable-rate divergence**
   (minOut / surplus / totalBalanceOf all vault-rate denominated) → econ-scanner.
4. Do **not** re-report: guard-after-swap (full revert, funds safe), M-03-style
   emergencyWithdraw intent (ledgered wont-fix), per-client→global buffer move as a
   "theft" (owner-intended story-047 design; only the stale docs are the issue).
