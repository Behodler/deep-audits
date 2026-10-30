# Spec-Conformance Report (Law-2 Faithfulness): reflax-yield-vault-18

- **Project**: reflax-yield-vault · **Branch**: `master` · **Commit**: `4788ed41747b923165745af748a078bfb534ba20` `[story-052] CurveAMMAdapter.setRoute enforces Curve Router NG contiguity (M-01)`
- **Range**: `cdd0743..4788ed4` (regression, `branchBaselines.master` from run-17)
- **Date**: 2026-10-28

## Scope and conventions

Law-2 entries are reported **here** and are never folded into the QA bundle. A behavioural deviation from a story is
reported where the owner will see it, even when its security impact is nil. `F-06` is a new faithfulness ledger entry
in its own right. The two **cross-reference** sections (QA-14, L-31) are the faithfulness **channel** for findings
ledgered **once** under their QA/Low label. They are not separate ledger entries and they have no fingerprints of their own.

| # | Deviation | Verdict | Ledgered as | Security leg |
|---|---|---|---|---|
| **F-06** | `src/CLAUDE.md:258` says the routeGap test asserts **every** `AMMRoutes.json` route. The test checks two hard-coded keys. | DEVIATES (doc overstates coverage) · open · **validity: invalid, proposed false-positive** | **F-06** · `ryv18f6` · `7ef86352a3dd` | None. Hardening point absorbed into **M-05** (formerly L-30) recommendation (d). |
| **X-QA-14** | story-052's stated goal ("only store routes where the router actually delivers `tokenOut`") vs its step 7 denylist `{0, 9}` | Code faithful to the letter. **The gap is in the story itself.** | **QA-14** · `ryv18q14` · `46109c7be1f6` | Availability freeze until overwrite (owner footgun). See QA bundle. |
| **X-L-31** | stable-staker story-028's "bounded by `slippageToleranceBps`" rationale does not hold for the direct `ERC4626YieldStrategy` | Story rationale **false for 2 of 3 live strategies** | **L-31** · `ryv18l31` · `b9203a0da756` | Low, borderline Medium (unverified manipulable leg). See QA bundle. **Route to stable-staker.** |
| note | story-051 premise "StableStakerV2 is undeployed … exposure is zero" has **expired** | Harmless for 051 | not filed | n/a |
| note | story-051 gate 2 `forge build --sizes` exits 1 (EIP-170) | Pre-existing, disclosed, accepted | not filed | n/a |

---

## 1. Stories audited this run

Both tags were resolved by globbing the whole `~/code/product-owner/stories/vault-RM/` tree across every state and sprint folder. Each returned exactly one hit (`reports/18/story-intents.md`).

| Story | Commit | Document | State |
|---|---|---|---|
| **story-051**: Revert `previewExitFor` from `IYieldStrategy` | `25276b8` | `/home/justin/code/product-owner/stories/vault-RM/auto-complete/exit-preview-revert/051-revert-exit-preview-from-iyieldstrategy.md` | `auto-complete` |
| **story-052**: CurveAMMAdapter route contiguity (M-01 class) | `4788ed4` | `/home/justin/code/product-owner/stories/vault-RM/auto-complete/curve-adapter-m01/052-curve-amm-adapter-route-contiguity-m01.md` | `auto-complete` |

**Approval provenance.** `auto-complete` is a final state, equivalent to `complete`. Both stories reached it through
story-batch **machine approval**, and no human has reviewed either one. Every phase of both stories declares
*"Independence: reduced"*. Two process points follow from that:

- **story-052**: implementation, validators and state transitions all ran inside one agent. The TDD red phase was
  **reconstructed post hoc** (Decision 7: validator temporarily reverted to the old code, 14/21 failed). There was one commit and no
  RED/GREEN split, which deviates from the vault `CLAUDE.md` TDD mandate. The story discloses this. The independent evidence for
  052 is this run's profiler probes and a 21/21 workspace replay, not the story's self-verification.
- **story-051**: the TDD red phase was **waived** on purpose because the change is a pure deletion ("There is no test that fails
  before a deletion and passes after it"). A substitute 5-point gate was recorded instead. The second review did not re-measure the 349 pre-revert
  test count (it corroborated it arithmetically only).

### Verdicts

| Story | Faithfulness | Law-1 override (unsafe story?) |
|---|---|---|
| story-051 | **FAITHFUL.** All 10 criteria PASS, except gate 2 which is *not met as worded, disclosed* (see Note B). `git diff --quiet 0110ce4 HEAD -- src/interfaces/IYieldStrategy.sol src/AYieldStrategy.sol` holds byte-identical. `previewExitFor|_exitFloor` grep is empty. The 20 named tests were deleted. Downstream: stable-staker `87b34c0 [story-027]` pins `25276b8` and has zero code call sites. | **Not unsafe.** The deleted surface was a view-only sizing aid that enforced nothing (run-17 L-22). Every enforced protection survives byte-identical: execution `minOut`, principal cap, dominance. |
| story-052 | **FAITHFUL.** Steps 1–8 PASS (step 5 equivalent, step 7 to the letter). `AMMRoutes.json` is unchanged and both of its routes pass. `swap`/`getRoute`/`isPairFullyConfigured`/`IAMMAdapter` are untouched. The required documentation of the source-vs-bytecode divergence is present. | **Not unsafe.** The live adapter `0x2D02…D6f` stays on the old validator. That is owner-only exposure (`setRoute` is `onlyOwner`), and both live routes were verified contiguous on-chain. The residual is **M-05** (`ryv18m5`, formerly L-30; promoted to Medium at final review, because a gapped deposit route silently strands deposits on the live adapter). Separately, the story's own spec gap is carried as **QA-14** (below). |

---

## 2. Deviations

### F-06 (`ryv18f6`): `src/CLAUDE.md` claims the routeGap test asserts every `AMMRoutes.json` route, but it checks two hard-coded keys (validity: invalid — proposed false-positive, absorbed into M-05 (d))

> **Final-review note (2026-10-28).** The validity review found this deviation **invalid**. `AMMRoutes.json` holds exactly two routes and the test asserts both, so "every route" is true at HEAD. The same sentence also says "add a case there", which documents that coverage is added by hand. The ledger entry stays `open` with `proposedStatus: false-positive`; a human applies it with `/ledger reflax-yield-vault false-positive 7ef86352a3dd`. The suggestion to enumerate keys with `vm.parseJsonKeys` is absorbed into M-05 (`ryv18m5`, formerly L-30) recommendation (d). The section below is kept unchanged as the original finding text.

- **Ledger**: F-06 · issueId `ryv18f6` · fingerprint `7ef86352a3dd0da4c49898d99614c27e5c24b3420d97a3a7e45c88fea897065f` · status `open` · origin `new`
- **Story**: story-052 (`auto-complete`). The sentence was added by commit `4788ed4` (story Decision 6, "Optional doc notes taken").
- **Location**: [`src/CLAUDE.md#L258`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/CLAUDE.md#L258-L258). Related: [`test/unit/CurveAMMAdapter.routeGap.t.sol#L368-L382`](https://github.com/Behodler/reflax-yield-vault/blob/master/test/unit/CurveAMMAdapter.routeGap.t.sol#L368-L382)

**What the story says.** story-052, checklist:

> - [x] `AMMRoutes.json` unchanged — assert in a test that both its routes pass.

The project `CLAUDE.md` sentence the story added (`src/CLAUDE.md:258`):

> `test/unit/CurveAMMAdapter.routeGap.t.sol` asserts every route in this file passes; add a case there when adding a Curve route.

**What the code actually does.** `test/unit/CurveAMMAdapter.routeGap.t.sol:368-382` parses two keys by name and does not enumerate the file:

```solidity
function test_routeGap_canonicalAMMRoutesAccepted() public {
    string memory json = vm.readFile(string.concat(vm.projectRoot(), "/AMMRoutes.json"));
    ...
    (address usdeAddr, address susdeAddr) = _setRouteFromJson(a, json, "USDe-sUSDe", "USDe", "sUSDe");
    (address susdeAddr2, address usdeAddr2) = _setRouteFromJson(a, json, "sUSDe-USDe", "sUSDe", "USDe");
    ...
    assertTrue(a.isPairFullyConfigured(usdeAddr, susdeAddr), "both canonical directions stored");
}
```

**Deviation.** The story's own criterion ("both its routes") is met. The `CLAUDE.md` sentence claims something stronger: that the
test enumerates the file ("every route"). That is not true. If a route is added to `AMMRoutes.json` and no matching test case is added, nothing asserts it.
The sentence's instruction to "add a case there" partly mitigates this. Decision 5's rationale ("hardcoding … would not catch future edits to
the file") holds only for edits to the two existing entries.

**Security cross-reference.** No direct impact. The false assurance matters most for **M-05**, formerly L-30
(`reports/18/findings/medium/M-05-live-adapter-gapped-route-strands-deposits.json`). The live mainnet adapter `0x2D02…D6f` lacks
the new validator, so the off-chain check that `CLAUDE.md` prescribes for that adapter is the only safeguard. A reader who trusts "every route"
could skip it. **Escalation trigger:** re-weigh to Low if a route is added to `AMMRoutes.json` and deployed without the test asserting it.

**Recommendation.** Reword the sentence to *"asserts both canonical USDe↔sUSDe routes pass"*, or make the claim true by iterating
`vm.parseJsonKeys(json, ".Curve.RouterNG.routes")` in the test.

---

### Cross-reference: QA-14 (`ryv18q14`): story-052's stated goal vs its step-7 swap_type denylist (a gap in the story itself)

- **Ledgered as**: **QA-14** · issueId `ryv18q14` · fingerprint `46109c7be1f676f2c5d3ec1bc0ef80b613a97fa80f75f8c24fd85327c479ed91` · status `open`. This section is its faithfulness face (source `FAITH-001`). It is **one** ledger entry, not two.
- **Story**: story-052 (`auto-complete`), Story Overview vs Technical Details step 7
- **Location**: [`src/AMMAdapters/CurveAMMAdapter.sol#L124-L127`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/AMMAdapters/CurveAMMAdapter.sol#L124-L127). NatSpec sites: `CurveAMMAdapter.sol:91-92` and `src/AMMAdapters/ICurveRouterNG.sol:19-20`

**What the story says.** The stated goal (story-052, line 10):

> Replace the weak "last non-zero entry must equal tokenOut" check in `setRoute` with the Curve Router NG v1.1 contiguity rule ported from `SYAHarvester.sol`, so that the adapter can only store routes where the router actually delivers `tokenOut`.

The enumerated rule (Technical Details, step 7):

> 7. Executed swapParams rows must have swap_type ≠ 0 and ≠ 9 (9 is rejected by Router NG v1.1).

**What the code actually does.** It implements step 7 exactly as written (`CurveAMMAdapter.sol:124-127`):

```solidity
if (h < k) {
    uint256 swapType = swapParams[h][2];
    if (swapType == 0 || swapType == 9) revert InvalidRouteSwapParams(h);
}
```

Router NG v1.1 dispatches only swap_types `1..8`. Values `10..type(uint256).max` are therefore accepted and stored, but the router
cannot execute them, so every later swap reverts. This was confirmed by profiler probe `test_swapTypeAboveNineAccepted` (PASS), by invariant
`RESIDUAL_swapTypeInRange` (expected FAIL, forge + medusa), and by Halmos `check_residual_swapTypeInRange` (expected FAIL) with replay
`test_replay_swapType12Accepted`. The NatSpec copies the story's wording ("swap_type … not 0 and not 9 (Router NG v1.1 rejects
both)"), so it reads as if swap_type validity is enforced.

**Deviation.** This is **not an implementation deviation.** The code is faithful to step 7 to the letter. The story's
enumerated rule leaves out part of the router's rejected set, so it does not deliver the story's own stated goal. The story is internally
inconsistent, and the Law-2 defect is in the story document.

**Security cross-reference.** QA-14 (`ownerFootgun: true`). There is no asset loss. A route with an out-of-range swap_type, stored by an owner
who trusts the validator, freezes the market strategy's deposit/withdraw/skim until the owner overwrites it. The failure is loud and recoverable
(there is no `clearRoute` lock-in). The owner previously triaged the direct analogue in sya-harvester (run-02 L-05, `sh2l5` / `3dc3002290`, swap_type ≥ 9) as QA
on 2026-10-26. See `qa-report.md` for the security leg.

**Recommendation.** **Amend story-052 step 7** (or open a follow-up story) to an allowlist: *"Executed swapParams rows must have
1 ≤ swap_type ≤ 8"*. In code: `if (swapType == 0 || swapType > 8) revert InvalidRouteSwapParams(h);`. Avoid the `st - 1 >= 8`
idiom, which panics `0x11` on 0. Update the NatSpec at `CurveAMMAdapter.sol:91-92` and `ICurveRouterNG.sol:19-20` to match.

---

### Cross-reference: L-31 (`ryv18l31`): stable-staker story-028's "bounded by `slippageToleranceBps`" rationale does not hold for the direct `ERC4626YieldStrategy`

- **Ledgered as**: **L-31** · issueId `ryv18l31` · fingerprint `b9203a0da756999a35ee8f9afed342b6e0f1d764cd706d2e499350d01b11717d` · status `open` · `faithfulness: true`, `crossRepo: true`
- **Story**: **stable-staker** story-028, `/home/justin/code/product-owner/stories/stable-staker/auto-complete/phusd-shortfall/028-cover-annihilation-shortfall-with-minted-phusd.md` (`auto-complete`)
- **Location (this repo)**: [`src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L126-L140`](https://github.com/Behodler/reflax-yield-vault/blob/master/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L126-L140) (`_disposeShares`)
- **Location (consumer)**: `stable-staker/src/src/StableStakerV2.sol:494-501` (NatSpec), `:574-580` (measured-delta top-up), at stable-staker HEAD `cf8de27`
- **Route to: stable-staker lane.** The correction belongs to story-028's rationale and to the V2 consumer, not to a vault-RM story.

**What the story says.** story-028, Concerns (lines 325-332):

> **The top-up is extractable, and this is the accepted cost of the design.** A user who sandwiches
> their own `autoAnnihilate` through `ERC4626MarketYieldStrategy`'s AMM keeps the sandwich profit AND
> still receives the frictionless payout, because the protocol mints the difference. It is bounded
> three ways: the strategy enforces `minOut = idealUnderlying * (MAX_BPS - slippageToleranceBps) /
> MAX_BPS` internally and reverts below it, so extraction per call is capped at the configured
> tolerance; it costs a real AMM round trip; and it is bounded by the caller's own stake and accrued
> antimatter. **Human decision: accepted.**

The consumer NatSpec (`StableStakerV2.sol:496-499`) is also scoped to AMM-backed strategies. *Final-review correction: an earlier version of this section left out the words "through an AMM-backed strategy" and presented the bound as general.*

> A caller who sandwiches their own exit through an AMM-backed strategy keeps the sandwich profit AND is still paid the frictionless figure. It is bounded by the strategy's own `slippageToleranceBps` (which reverts below its floor), by a real AMM round trip, and by the caller's own stake and accrual.

For **direct** strategies, story-028 assumes that the top-up is rounding-scale (line 83: "rounding-scale, not haircut-scale"; checklist line 310 tests the real `ERC4626YieldStrategy` at a non-integral share price).

**What the code actually does.** `ERC4626YieldStrategy` has **no** `slippageToleranceBps` (grep: zero hits; the field exists only
on `ERC4626MarketYieldStrategy.sol:37`). Its exit redeems with no minimum and throws away the return value (`ERC4626YieldStrategy.sol:126-140`):

```solidity
function _disposeShares(uint256 amount, address recipient) internal override returns (uint256 sharesDisposed) {
    uint256 sharesToRedeem = vault.convertToShares(amount);
    ...
    // Redeem shares for underlying tokens — sent directly to recipient
    vault.redeem(sharesToRedeem, recipient, address(this));
    sharesDisposed = sharesToRedeem;
}
```

StableStakerV2 measures what was delivered and mints `(target − delivered)` as phUSD (`StableStakerV2.sol:574-580`):

```solidity
uint256 received = _routeExit(token, gross, true);
// MEASURED DELTA. ... the difference in VALUE is made up in freshly minted phUSD, never out of the idle buffer.
uint256 netUsed = received < netWanted ? received : netWanted;
...
(phUSDPaid, phUSDMinted) = _annihilateAndTopUp(token, netUsed, netWanted, scale);
```

**Deviation.** Story-028's `slippageToleranceBps` bound is scoped, correctly, to `ERC4626MarketYieldStrategy`. For direct strategies the story relies on a different premise: that the top-up is rounding-scale. The live **DOLA** (`0x981c7BE1…B7EE` over sDOLA)
and **USDC** (`0xaFDf8DeA…AB83` over autoUSD) strategies are direct `ERC4626YieldStrategy` instances, and the live V2
`0xA6d3…B58F` is the redeeming client of all three strategies. On the USDC pool the rounding-scale premise fails.
Measured today: sDOLA leaks rounding only (~1 wei/call). autoUSD has a static 1.38 bps discount
(`previewRedeem` 16,356.04 vs `convertToAssets` 16,358.30 USDC), minted as phUSD on every USDC `autoAnnihilate`. That is dust and reward-bounded.
That shortfall is not rounding-scale, so it breaks the story's premise. A possible **manipulation** leg is **unverified** (no Tokemak source was available locally and no fork probe was run). It is tracked only as an escalation trigger and is not part of the deviation. phUSD minted through V2 is real dilution, because V2 emits Antimatter.

**Security cross-reference.** **L-31** (Low). The finding rests on the proven 1.38 bps autoUSD shortfall, which breaks story-028's rounding-scale assumption for direct strategies. The manipulation leg is unverified and appears only as an escalation trigger.
Escalation triggers are in the finding JSON. See `qa-report.md` for the security leg. Disclosures: L-29 `704404968a8f` is the same function with a distinct
root and must not be collapsed into this one. L-27 `d9bd595066ef` is in the stable-staker lane.

**Recommendation.** Do either one of the following:
- In vault-RM, add a delivery floor to `ERC4626YieldStrategy._disposeShares`: capture `vault.redeem`'s return value and require it to be at least
  `previewRedeem(shares) * (1 − tolerance)`.
- In **stable-staker**, correct story-028's rationale and the `StableStakerV2.sol:496-501` NatSpec to name the market strategy only, and add a
  consumer-side per-call cap on the phUSD top-up for direct-strategy pools.

The rationale correction is owed to the stable-staker lane either way.

---

### Note A (not filed): story-051's "StableStakerV2 is undeployed, exposure zero" premise has expired

story-051 (lines 105-106, 435):

> `StableStakerV2` is **undeployed** — mainnet runs the frozen V1 at `0xbce8ABC09BaEDCabE93419bF875f6186e182079A` …
>
> Nothing is deployed on either side, so the exposure is zero.

StableStakerV2 is now **live** on mainnet (`0xA6d3…B58F`; CutoverStableStakerV2Mainnet broadcast, 21/21 receipts; ECON-001).
**This is harmless for story-051.** Live V2 was deployed from stable-staker `cf8de27`, which pins the vault at `25276b8`, after the preview was
stripped. The reverted surface therefore never reached a live consumer. This note exists so the expired premise is not cited again as
a reason that some vault-RM↔stable-staker gap has zero exposure. The same expiry is behind the "premise changed" flag on carryover **F-03**.

### Note B (not filed): story-051 gate 2 `forge build --sizes` exits 1 (EIP-170)

story-051 Implementation Notes, gate point 2:

> 2. `forge build --sizes` succeeds

The command exits 1 on the EIP-170 runtime size limit, and it exits 1 at base `cdd0743` too, so the failure is pre-existing. The revert **reduces** it:
`ERC4626MarketYieldStrategy` goes from 2,694 to 1,651 bytes over the limit, and `ERC4626YieldStrategy` from 411 to 54 bytes over. The story's checkbox records this honestly:

> **records a KNOWN PRE-EXISTING FAILURE, not a pass.** … The box is ticked for the gate being *honestly recorded and shown non-regressive*, never for the command succeeding

The human send-back sanctioned this resolution. Plain `forge build` and `FOUNDRY_OPTIMIZER=true forge build --sizes` both exit 0.
It is **not filed**: EIP-170 tracking belongs to the size/config follow-up story that story-051 itself calls for ("`foundry.toml` sets no optimizer
and CI's `FOUNDRY_PROFILE: ci` resolves to a `[profile.ci]` that does not exist"). That story has **not been opened**.

---

## 3. Carryover: still-open faithfulness entries from prior audits

These entries were not re-analysed at audit 18. Each one is carried in full, one file per originating audit:

| File | Entries | Ledger fingerprints | Run-18 note |
|---|---|---|---|
| [`carryover/spec-conformance-12.md`](carryover/spec-conformance-12.md) | F-01, F-02 | `ec9191e420d54444`, `fd58cf00a7e3abab` | Unchanged (line drift only) |
| [`carryover/spec-conformance-14.md`](carryover/spec-conformance-14.md) | F-03 | `52f9b84a54ec9a65` | **Premise changed**: StableStakerV2 is live. Re-evaluation owed by the stable-staker lane. |
| [`carryover/spec-conformance-15.md`](carryover/spec-conformance-15.md) | F-04, F-05 | `6711114c7f9d6211`, `1559780543e8b9ba` | F-05 stale 24h/48h NatSpec re-located to `IYieldStrategy.sol:101` / `AYieldStrategy.sol:414`. Not resolved. |
| [`carryover/spec-conformance-16.md`](carryover/spec-conformance-16.md) | F-16-003 | `c705bd94ec78fd23` | Unchanged |
| [`carryover/spec-conformance-17.md`](carryover/spec-conformance-17.md) | F-17-01..04 (channels of L-18, L-19, QA-10, L-27) | `5351fd4d3f8c`, `302656e23443`, `e868f28953a9`, `d9bd595066ef` | L-18/L-19/QA-10 **PROPOSED fixed-by-removal** (story-051 deleted the code). They stay `open` until a human applies the change. L-27 is cross-repo and now live. |

Proposed status changes are applied by a human only, via `/ledger reflax-yield-vault fixed <fingerprint>`. This report does not change any ledger status.
