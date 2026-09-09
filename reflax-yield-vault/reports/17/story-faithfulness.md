# Story Faithfulness (Law 2) — reflax-yield-vault run-17

- **Project**: reflax-yield-vault
- **Submodule HEAD**: `cdd0743`
- **Delta reviewed**: `0110ce4..cdd0743` (2 commits, +506/-13)
- **Scan type**: story-faithfulness (regression)
- **Scan date**: 2026-08-31

## Story resolution

| Field | Value |
|---|---|
| Tag | `story-050` |
| Document | `/home/justin/code/product-owner/stories/vault-RM/auto-complete/yield-strategy-exit-preview/050-exit-preview-on-iyieldstrategy.md` |
| Glob hits | exactly 1 (unambiguous) |
| State folder | **`auto-complete`** |
| Title | Exit Preview on IYieldStrategy: Size a Withdrawal Against the Strategy's Haircut |
| Sprint | 22 (`yield-strategy-exit-preview`) |
| Base commit stamped in story | `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9` (matches HEAD) |

**State note.** The story sits in `auto-complete`, and its own trailer reads
*"Approved by: story-batch workflow (machine approval — not human-reviewed)"*, with both the
Execute and Review steps run under `--inline-delegation` and self-declared
*"Independence: reduced"*. The acceptance criteria are therefore fully specified but have never
been signed off by a human. Two of the three findings below sit in exactly the blind spot that
review pass declared out of its own reach.

## Verification performed

Suite re-run from `/home/justin/code/audits/workspace/reflax-yield-vault` at `cdd0743`:
`forge test --match-test PreviewExitFor` → **20 passed, 0 failed** (13 market + 7 direct), matching
the story's claim. The 15 failures in a full `forge test` are all audit-authored `test/poc-*.t.sol`
files resident in the workspace, not repo tests; `test/unit/ERC4626*` is 202/202 green.

Both findings below were proven with throwaway probes run against the real strategies in the
workspace and then deleted; neither probe was left on disk.

## Criterion-by-criterion grading

| # | Story criterion (quoted) | Verdict |
|---|---|---|
| 1 | "Write the failing tests FIRST, per the repo's mandatory TDD rule" | **Satisfied** — `a438ce0` touches only `test/`; `previewExitFor` does not exist in `src/` at that commit, so the suite could not compile. |
| 2 | Declare `previewExitFor(address token, address account, uint256 netWanted) external view returns (uint256 grossToRequest, uint256 netGuaranteed)` on `IYieldStrategy`, "adjacent to `withdraw`" | **Satisfied** — declared immediately after `withdraw`, signature byte-identical to the human-decided shape. The "do not substitute a forward-only preview" instruction was honoured. |
| 3 | Natspec in the `deposit`/`@return creditedPrincipal` house style, "prose-heavy … spelling out the direct-vs-market split explicitly" | **Satisfied** — 50 added lines, direct-vs-market split spelled out in both `@return` blocks. |
| 4 | "Natspec states in the strongest terms that `netGuaranteed` is a FLOOR … and that consumers MUST measure the actual balance delta after `withdraw`" | **Satisfied** — all three story-mandated reasons (AMM pays ≥ minOut; live-state manipulable within a block; `convertToAssets` is fee-free) are present and enumerated. |
| 5 | "Cross-reference the CLAUDE.md `## skimSurplus return value vs. SurplusSkimmed events` caveat" | **Satisfied** — quoted verbatim including "THE GAP CAN BE LARGE IN EITHER DIRECTION"; the target section exists at `CLAUDE.md:201`. |
| 6 | `virtual` default on `AYieldStrategy`, "the capped identity", placed near `principalOf`/`totalBalanceOf` | **Satisfied as written — but see F-01.** Placed at `AYieldStrategy.sol:552`. |
| 7 | "Default replicates the base's per-account cap `min(netWanted, clientBalances[token][account])`; do NOT build it on `getTotalShares()`" | **Satisfied** — reads `clientBalances` directly; `getTotalShares()` not referenced. |
| 8 | Market `override` "mirroring `_disposeShares` lines 160-168 only (NOT line 225, 276, or the deposit-side line 107)" | **Satisfied** — `_exitFloor` is a line-for-line mirror of `_disposeShares`' `convertToShares` → share-balance cap → `convertToAssets` → bps haircut chain. Confirmed `_totalWithdraw`/`_skimSurplus`/`_creditedPrincipal` are untouched, and that the `setAsideBufferRecipient` leg lives only in `_skimSurplus`, never on the `withdraw` path. |
| 9 | "Add an explicit `slippageToleranceBps == MAX_BPS` division-by-zero guard; decide the behaviour, document it, and make it distinguishable from a bare `Panic(0x12)`" | **Satisfied** — `denominator == 0` short-circuits to `(0, 0)`, documented at length, asserted by value in `testPreviewExitForAtMaxBpsReturnsZeroWithoutPanic`. The story left the choice to the executor, so Decision 2 is inside the story's grant. |
| 10 | "Build the preview exclusively on `convertToShares`/`convertToAssets`; … never calls `previewRedeem`, `previewWithdraw`, or the strategy's own `previewRedeem` wrapper" | **Satisfied** — verified by inspection of the `src/` diff (no such call site) and by two live tests, including a low-level `staticcall` and `MockStateChangingPreviewVault`. Both pass on re-run. |
| 11 | "Document the `convertToAssets` fee-free limitation (over-quotes on a fee-charging vault)" | **Satisfied** — stated in the interface natspec and again on `_exitFloor`. |
| 12 | "Confirm by inspection that `ERC4626YieldStrategy` needs NO override … and say so explicitly" | **Partially satisfied.** No override was added and the claim is made in the commit body and in a test-section comment. The *reasoning offered* ("no `minOut`, no bps") is incomplete: `ERC4626YieldStrategy._disposeShares` also applies a share-balance cap, which the default does not model. See **F-01**. |
| 13 | Test: identity/default path on `ERC4626YieldStrategy` | **Satisfied** (`testPreviewExitForIsIdentityOnDirectStrategy`). |
| 14 | Test: account-cap replication | **Satisfied** on both strategies, plus a per-account-not-global test. |
| 15 | Test: STATICCALL safety reusing `MockStateChangingPreviewVault` | **Satisfied** (`ERC4626YieldStrategy.t.sol:1671`). |
| 16 | Test: gross-up "at several `slippageToleranceBps` values, INCLUDING 0 and INCLUDING the `MAX_BPS` edge" | **Satisfied** — 0, 100 (setUp default), 500, and `MAX_BPS`. |
| 17 | Test: round-trip "asserting `delivered >= netGuaranteed` (never equality)" | **Satisfied** — three round trips (neutral, unfavourable, favourable); no equality assertion on any AMM-executed path. |
| 18 | Test: favourable-AMM case where delivery exceeds the quote | **Satisfied** (`testPreviewExitForFavorableAMMExceedsQuote`, `assertGt`). |
| 19 | Test: "share-balance-cap case where `vault.balanceOf(address(this))` binds before the requested amount does" | **Partially satisfied.** Covered on the market strategy only (`testPreviewExitForShareBalanceCapBinds`, which correctly asserts `netGuaranteed < principal`). The identical cap on the direct strategy is untested — and F-01 shows it is also unhandled. |
| 20 | Add an exit-side twin of `_haircut()` rather than overloading it | **Satisfied** (`_exitFloor`/`_grossUp` test helpers, kept separate). |
| 21 | `EXIT PREVIEW TESTS` banner adjacent to the withdraw/slippage sections | **Satisfied** (market `:382`, direct `:1597`). |
| 22 | "Confirm updating the six downstream direct implementers … is NOT done here" | **Satisfied** — no downstream repo touched. Story-declared, human-decided out of scope. See WATCH-17-01. |
| 23 | Wiring a consumer | **Not requested.** The story states "It does NOT change any downstream repo"; the intended consumer (`stable-staker` story 025) is explicitly blocked on the submodule bump. The unwired surface is therefore faithful, not a gap. |
| 24 | `forge build` / `forge fmt --check` / full suite green | **Satisfied** for the 20 new tests, independently re-run. |

Rounding direction (Decision 3, `Math.ceilDiv`) was not specified by the story and is inside the
executor's grant; it is also the protocol-favouring direction the repo mandates. Not a deviation —
but see **F-02** for the leg `ceilDiv` does not cover.

---

## Findings

### F-01-050 — `previewExitFor` over-quotes `netGuaranteed` on direct strategies when the share-balance cap binds

- **id**: `FAITH-001`
- **type**: `story-unsafe` (story-premise defect; the code is faithful to the story's letter)
- **faithfulness**: true · **securityEscalation**: false (see escalation trigger)
- **storyTag**: story-050
- **severity**: **Low** (potential-Medium once a consumer is wired)
- **contract**: `src/AYieldStrategy.sol` (default) as reached through `src/concreteYieldStrategies/ERC4626YieldStrategy.sol`
- **function**: `previewExitFor` · **lineStart** 571 · **lineEnd** 582
- **lawImpacted**: 2 · **confidence**: high (empirically proven)

**specText**

> `@return netGuaranteed` — "The net underlying the strategy **guarantees** will be delivered if
> exactly `grossToRequest` is withdrawn. Direct strategies return `grossToRequest`."
> — shipped natspec, `src/interfaces/IYieldStrategy.sol`

> "No `minOut`, no bps. So the base default — the capped identity — is CORRECT for this strategy,
> and it is the reason only the market strategy needs an override."
> — story-050, *Technical Details → `ERC4626YieldStrategy` — NO exit haircut*

**specSource**: story document `050-exit-preview-on-iyieldstrategy.md` (`auto-complete`), plus the
interface natspec delivered by `cdd0743`.

**actualBehavior**

The story's own quotation of `ERC4626YieldStrategy._disposeShares` (lines 126-138) contains two
reducers, not one:

```solidity
uint256 sharesToRedeem = vault.convertToShares(amount);
uint256 availableShares = vault.balanceOf(address(this));
if (sharesToRedeem > availableShares) {
    sharesToRedeem = availableShares;      // <-- second cap, never modelled by the default
}
vault.redeem(sharesToRedeem, recipient, address(this));
```

The story reasoned only about the absence of a bps haircut and concluded the capped identity is
"CORRECT". It is not, whenever the strategy's held shares are worth less than the account's booked
principal — the same underwater condition the market override *does* handle and does test. The base
default returns `netGuaranteed == grossToRequest == principal` regardless.

Proven against the real `ERC4626YieldStrategy` (probe run in `workspace/`, since deleted): deposit
1000e18, then a 50% vault loss so `convertToShares(principal) > vault.balanceOf(strategy)`:

```
grossToRequest: 1000000000000000000000
netGuaranteed : 1000000000000000000000
delivered     : 500000000000000000000
```

`delivered` is **half** `netGuaranteed`. The market strategy under the identical condition reports
honestly — its own `testPreviewExitForShareBalanceCapBinds` asserts
`assertLt(netGuaranteed, principal, "an underwater position cannot guarantee its own principal")`.
The direct strategy has no equivalent test (story criterion 19 was implemented on one strategy only),
which is why the gap survived the machine review.

**deviation**

`netGuaranteed` is documented and named as a **floor**. On direct strategies in a deficit position
it is a **ceiling**, and the error is unbounded in percentage terms (100% of the deficit). The
asymmetry is unintended: the story asked for one function whose meaning is uniform across strategies,
and shipped one whose worst-case guarantee is honest on the market strategy and false on the direct
one — precisely inverting the reader's expectation, since the direct strategy is the one documented
as "deducts nothing".

**Why Low, not Medium, today.** Nothing consumes `previewExitFor` yet — the story deliberately ships
the surface unwired, and its natspec mandates in capitals that consumers MUST measure the actual
balance delta across `withdraw`. A compliant consumer is protected. The bug is a false guarantee, not
a live value leak.

**Escalation trigger (raise to Medium).** When `stable-staker` bumps its `lib/reflax-yield-vault`
submodule and story 025 `autoAnnihilate` starts sizing against `netGuaranteed`: that consumer's
stated job is to "withdraw principal and burn exactly the received stable", and a consumer that
sizes a burn against this floor on a direct strategy in deficit re-introduces exactly the shortfall
this story exists to eliminate — the shortfall then being paid out of StableStaker's shared
underwater-withdrawal buffer. Re-weigh at the next stable-staker run.

**Suggested remedy (owner's call).** Either make the base default share-aware — cap `netGuaranteed`
by the underlying value of the shares actually held, which is what `_positionValue()` already
exposes to the base — or narrow the interface natspec so it stops promising a delivery guarantee
the default cannot make, and add the missing direct-strategy share-cap round-trip test. The second
is cheaper; the first is the one that makes the word "guarantees" true.

---

### F-02-050 — the ceil gross-up compensates the bps leg but not the share round-trip, so `netGuaranteed` can land below `netWanted`

- **id**: `FAITH-002`
- **type**: `faithfulness`
- **faithfulness**: true · **securityEscalation**: false
- **storyTag**: story-050
- **severity**: **QA / informational**
- **contract**: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol`
- **function**: `previewExitFor` · **line** 174 · **lineStart** 162 · **lineEnd** 183
- **lawImpacted**: 2 · **confidence**: high (empirically proven)

**specText**

> "Rounding down would quote a gross whose floor lands one unit *below* `netWanted` — precisely the
> shortfall this story exists to let a consumer avoid … Alternatives: Floor division; the tests
> assert `netGuaranteed >= netWanted`, which would then fail at non-dividing tolerances such as the
> 5% case."
> — story-050, *Autonomous Decisions → Decision 3: Ceil-rounding the gross-up*

**specSource**: story document, Decision 3; the corresponding live assertions are
`assertGe(netGuaranteed, netWanted, "the guaranteed floor must cover what the caller wanted")`
(`ERC4626MarketYieldStrategy.t.sol:400`) and `assertGe(netGuaranteed, 100e18)` (`:431`).

**actualBehavior**

`Math.ceilDiv` corrects only the bps inversion. `_exitFloor` then performs
`convertToAssets(convertToShares(gross))`, which truncates **twice**, so the round trip loses up to
one assets-per-share unit before the haircut is applied. The stated property
`netGuaranteed >= netWanted` therefore holds only while the vault share price divides cleanly — which
is exactly the condition every existing test happens to sit in, because `MockERC4626Vault` is 1:1 at
`setUp` and no preview test moves the price without also binding a cap.

Probe (workspace, since deleted): 1000e18 deposited at the default 1% tolerance, then
`simulateYield` to a non-dividing share price, sweeping `netWanted` across 200 consecutive wei with
an explicit assertion that no cap binds — worst observed shortfall **1 wei**, reproduced at both a
near-unity and a ~3x share price. The magnitude is bounded by the assets-per-share unit, so it stays
dust at 18 decimals.

**deviation**

The story's stated rationale for choosing `ceilDiv` is that the quote must never land below
`netWanted`. That property is not actually established by the implementation; it is established by
the test fixture. Filed as QA because the residual is dust and because the story's own framing —
`netGuaranteed` is advisory, consumers must measure — already absorbs it. It is recorded so the next
reader does not mistake the passing `assertGe` for a general proof.

---

## Watch notes (not findings)

- **WATCH-17-01 — interface breaking change, story-declared.** Adding `previewExitFor` to
  `IYieldStrategy` breaks the six downstream direct implementers the story enumerates in Concerns 1
  (`stable-staker/test/mocks/MockYieldStrategy.sol:26`,
  `stable-staker/test/Migration.t.sol:924`, `stable-yield-accumulator/test/StableYieldAccumulator.t.sol:112`
  and `:215`, `phusd-stable-minter/test/PhusdStableMinter.t.sol:66`,
  `deployment-staging/src/mocks/MockYieldStrategy.sol:12` — note that last one is in `src/`, not
  `test/`). Human-decided out of scope; breakage lands at each repo's own submodule bump. Not a
  faithfulness finding — recorded so the next cross-repo run does not re-derive it as a surprise.
- **WATCH-17-02 — machine-approved story.** `story-050` was auto-completed by the story-batch
  workflow with no human review, and both Execute and Review ran inline with self-declared reduced
  independence. F-01 and F-02 are both inside the blind spot that review declared. The acceptance
  criteria may still be revised.
- **WATCH-17-03 — F-01 re-weigh at the stable-staker bump.** See the escalation trigger on F-01.

## Machine-readable summary

```json
{
  "project": "reflax-yield-vault",
  "scanTimestamp": "2026-08-31T00:00:00Z",
  "scanType": "story-faithfulness",
  "storiesChecked": ["story-050"],
  "storyStates": { "story-050": "auto-complete" },
  "findings": [
    {
      "id": "FAITH-001",
      "label": "F-01-050",
      "type": "story-unsafe",
      "faithfulness": true,
      "securityEscalation": false,
      "storyTag": "story-050",
      "severity": "low",
      "contract": "src/AYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 571, "lineStart": 571, "lineEnd": 582,
      "specText": "story-050: \"No minOut, no bps. So the base default - the capped identity - is CORRECT for this strategy\"; shipped natspec: \"netGuaranteed: The net underlying the strategy guarantees will be delivered\"",
      "specSource": "~/code/product-owner/stories/vault-RM/auto-complete/yield-strategy-exit-preview/050-exit-preview-on-iyieldstrategy.md + src/interfaces/IYieldStrategy.sol@cdd0743",
      "actualBehavior": "On ERC4626YieldStrategy the default returns netGuaranteed == principal even when vault.balanceOf(strategy) binds in _disposeShares. Proven: quote 1000e18, delivered 500e18 after a 50% vault loss.",
      "deviation": "netGuaranteed is documented as a floor but is a ceiling on direct strategies in deficit; the market override handles and tests the same cap, the base does not.",
      "lawImpacted": 2,
      "confidence": "high"
    },
    {
      "id": "FAITH-002",
      "label": "F-02-050",
      "type": "faithfulness",
      "faithfulness": true,
      "securityEscalation": false,
      "storyTag": "story-050",
      "severity": "qa",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol",
      "function": "previewExitFor",
      "line": 174, "lineStart": 162, "lineEnd": 183,
      "specText": "story-050 Decision 3: \"Rounding down would quote a gross whose floor lands one unit below netWanted - precisely the shortfall this story exists to let a consumer avoid\"",
      "specSource": "story document, Autonomous Decisions -> Decision 3",
      "actualBehavior": "Math.ceilDiv corrects the bps inversion only; convertToAssets(convertToShares(gross)) truncates twice, so netGuaranteed lands up to 1 wei below netWanted at a non-dividing share price with no cap binding.",
      "deviation": "The stated netGuaranteed >= netWanted property holds only for the 1:1 mock fixture, not in general.",
      "lawImpacted": 2,
      "confidence": "high"
    }
  ]
}
```
