# Nudge-Lineage PoC Replay — Re-authored against the story-022 `batchMint` API

**Project:** phoenix-nft-staking
**Submodule HEAD:** `0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54` ([story-022] Stage 6)
**Executed from:** `workspace/phoenix-nft-staking` (writable clone; `lib/` never opened read-write)
**Date:** 2026-07-20
**Brief:** discharge the "owed work" flagged at the end of
`tier3-and-poc-validation.md` §14–17 — port the four bit-rotted nudge-lineage PoCs to the
current API, replay them, and re-test the suppression premises D-07 / D-16 / D-20 say have degraded.

**No ledger entry was created, edited, or re-statused by this task.** Everything below is a
*report*. Any status change is the operator's to apply via `/ledger`.

---

## 1. Verdict table

| # | Ledger entry | Original PoC (`.bak`) | Re-authored file | Tests | Verdict |
|---|--------------|----------------------|------------------|-------|---------|
| 1 | **H-01** `858e9e80…` — value-blind nudge gate (status `fixed`) | `poc-H-01.t.sol.bak` | `test/PoC_NudgeLineage_H01.t.sol` | **4/4 PASS** | **STILL-LIVE** |
| 2 | **M-01** `521c20ad…` — MEV / first-claimer front-run (status `fixed`) | `poc-MevFrontrunNudge.t.sol.bak` | `test/PoC_NudgeLineage_MevFrontrunNudge.t.sol` | **2/2 PASS** | **STILL-LIVE** |
| 3 | **H-01** drain lineage (`pocPath` of `858e9e80…`) | `poc-NudgeDrain.t.sol.bak` | `test/PoC_NudgeLineage_NudgeDrain.t.sol` | **3/3 PASS** | **SPLIT** — Variant A **LIKELY-FIXED**, Variant B **STILL-LIVE** |
| 4 | M-01 cross-contract runway lineage | `poc-M-01.t.sol.bak` | `test/PoC_NudgeLineage_M01PriceInflation.t.sol` | **2/2 PASS** | **STILL-LIVE** |

Total **11/11 passing** at `0d1a0b2`. `forge build` clean. The four `.bak` originals are byte-identical
and untouched (`ls -la` timestamps unchanged at `Jul 9 21:57`).

> Every "STILL-LIVE" above means *the mechanic the PoC was written to prove reproduces at HEAD*. It does
> **not** by itself mean the ledger status is wrong — a `fixed`/`wont-fix` status can be correct because
> the *harm* was judged acceptable. Section 3 is where that judgement is re-tested, and that is where the
> load-bearing result is.

### Reproduced numbers

| PoC | Measurement at HEAD |
|-----|---------------------|
| H-01 (A) | attacker pays **5,256.33** pay-token for `count=5`, takes **50,000** pot; honest `count=50` batch pays **110,294.59** and receives **0** |
| H-01 (C) | 3 refill cycles, **150,000** captured, pot at 0 after every cycle |
| H-01 (D) | cost to qualify **5,256.33** vs pot **50,000** → claimant net-**positive** ≈ 9.5× |
| MEV M-01 | searcher outlay **5,256.33**, gains **50,000**; honest qualifier mints 5 NFTs, pays **5,947.05**, receives **0** |
| NudgeDrain B | attacker cost **5e6** (5 USDC-equiv), pot taken **100,000e6** → **20,000×** |
| NudgeDrain C | payout to a 1× payer and a 1000× payer is **byte-identical** — the gate reads a count, never a value |
| M-01 runway | rate **+252 bps**, runway −**780,595 s** (−9 days) per 5-mint round; second round compounds |
| M-01 realizability | ratchet-minted NFTs staked with no restriction → **12.58 phUSD** claimed after 30 d |

---

## 2. What the port changed (and what it deliberately did not)

Two rot layers, both diagnosed in `tier3-and-poc-validation.md` §14–17 and reused, not re-derived:

1. **Path rot.** `yield-claim-nft/V2/interfaces/…` → `yield-claim-nft/interfaces/…` (sibling story-039
   flatten refactor).
2. **API rot.** `setNudgePaymentToken` / `nudgePaymentToken` were deleted by story-022. The reward asset
   is now **caller-selected** per call:
   `batchMint(uint256 count, address recipient, uint256 paymentAmount, address[] rewardTokens, uint256[] minRewards)`.

Porting decisions, all recorded so nobody has to reverse-engineer them:

- The owner-set pot asset became a caller-supplied one-element `rewardTokens` array. This makes the H-01
  and NudgeDrain claims **strictly easier to state**, not harder — the attacker no longer depends on the
  owner having designated the asset (`src/BatchNFTMinter.sol:44-49`, "Permissionless top-up… No owner
  transaction is involved" / "Exogenous reward capture").
- `dispatcherIndex` is owner-pinned state (`src/BatchNFTMinter.sol:101`, resolved at `:315-323`), so every
  ported PoC mints the **same real, non-zero, ramping-price** dispatcher. No PoC uses a free-mint cheat.
- The bespoke `MockUnifiedMinter` in `poc-MevFrontrunNudge.t.sol.bak` (which had to stub the whole
  `INFTMinterV2` surface) was replaced with the project's own `MockITokenMinterV2` + `MockTokenDispatcherV2`.
  Ladder semantics are identical. `PoC_NudgeLineage_M01PriceInflation.t.sol` keeps a unified mock because
  it genuinely needs one address to be both `ITokenMinterV2` (batcher) and `INFTSupply` (staker).
- **No claim was weakened to make a test pass.** Where a claim genuinely died, it is reported as dead and
  the test that proves it dead was *kept* (NudgeDrain Variant A), not deleted.

---

## 3. ⚠ Suppression-premise status — the load-bearing section

This is the Law-1 output. Each accepted entry's suppression rationale is quoted from the ledger and
re-tested against HEAD source + the executed PoCs.

### 3.1 H-01 `858e9e80…` — status `fixed`

> **Ledger rationale (verbatim):** *"story-014 fixed the permissionless caller-chosen-dispatcher drain
> (the run-12 valid High) by owner-pinning the minter and dispatcherIndex; residual value-blindness only
> exploitable via **owner misconfiguration (zero-price pinned dispatcher / over-funded pot) => owner-driven,
> invalid**."*

The rationale has **two** legs. They do not fare the same way.

**Leg 1 — "zero-price pinned dispatcher" — HOLDS. ✅**
`batchMint` exposes no dispatcher-index parameter; the index is owner-pinned state
(`src/BatchNFTMinter.sol:101`, `:315-323`). Proven by
`test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED`: a zero-price dispatcher exists on the
minter, and the attacker's batch is nonetheless forced onto the pinned modest-price index (NFTs land on
`PINNED_INDEX`, zero on `CHEAP_INDEX`). Reaching a free mint requires the owner to pin a zero-price
dispatcher — genuinely owner-driven, and genuinely invalid under Law 3. **This leg of the fix is real and
should not be disturbed.**

**Leg 2 — "over-funded pot ⇒ owner-driven" — ✗ DEAD. This is the loud result.**

At HEAD, over-funding the pot is **not an owner action at all**:

- `src/BatchNFTMinter.sol:44-49` — *"**Permissionless top-up.** Anyone can seed the batch incentive with
  any ERC20 simply by sending it here. **No owner transaction is involved.**"*
- D-20 identifies the actual production funder as `StableYieldAccumulator.claim()` routing `nudgeSplit`%
  to the nudge address (`StableYieldAccumulator.sol:512-516`) — an **unbounded, time-accumulating stream
  with no relationship to mint cost**.

So the "over-funded pot" facet is reached by an automated third-party stream and by any unrelated address,
not by an owner mis-setting a parameter. **Law 3 does not reach it**, and the `=> owner-driven, invalid`
inference that closed it no longer follows from its own premise.

The contract's own safety argument fails identically. `src/BatchNFTMinter.sol:51-61` asserts:

> *"The 'honeypot' framing does not apply, because the pot is **by construction** a fraction of the cost of
> the `nudgeSize` mints required to qualify — every claim is net-positive for the protocol."*

`test_PoC_H01_PotIsNotBoundedByMintCost` executes the counterexample: cost to qualify **5,256.33**, pot
captured **50,000** — the claimant is net-**positive** at protocol expense. Nothing in `batchMint`
enforces the bound; the phrase *"by construction"* is not backed by any code. `test_PayoutIsIndependentOfWhatTheCallerPaid`
isolates the reason: the gate at `src/BatchNFTMinter.sol:349-354` compares a **count to a count**, and the
payout at `:429`/`:452-461` is the **entire** snapshotted balance. A 1× payer and a 1000× payer receive
byte-identical payouts.

**Conclusion.** The *permissionless-drain* High that H-01 was originally filed as remains fixed (leg 1).
But the residual that was dismissed as owner-driven is now reachable without the owner, and the natspec
premise that made it harmless is false as written. **H-01's `fixed` status should not be read as covering
the leg-2 facet.** Note this is the same mechanic as run-20's ECON-001 / F-20-01 and D-20's ECON-004 — the
finding is already surfaced this run under those labels; what is *new* here is that the executable witness
now exists and that the H-01 closure text is what would otherwise suppress it.

### 3.2 M-01 `521c20ad…` — status `fixed` (owner triage 2026-06-09)

The 2026-05-30 acceptance and the 2026-06-09 fix rest on **four** premises. **Three are dead or defective.**

| # | Premise (ledger verbatim) | Status at HEAD |
|---|---------------------------|----------------|
| P1 | *"claiming the nudge requires paying nudgeSize×mintPrice for real mints — the owner-pinned minter/dispatcher make a free claim impossible"* | **HOLDS ✅** — same evidence as H-01 leg 1 |
| P2 | *"ACCEPTANCE INVARIANT (owner-operational, not code-enforced): **keep the nudge pot < nudgeSize×mintPrice**; if the yield funnel ever lets the pot exceed the cost of nudgeSize mints, **pure-profit MEV returns**"* | **✗ DEGRADED / UNENFORCED** |
| P3 | *"nudge reward is a fraction of NFT mint cost, **NFTs have no secondary market** (only the staking pool), so a pure MEV bot cannot recoup in one tx"* | **✗ DEAD** |
| P4 | *"\[FIXED\] …fully closed by the `minReward` slippage floor: if the pot has been front-run, the batch reverts atomically and the honest user pays nothing"* | **✗ CONDITIONAL — and its condition is a `wont-fix`** |

**P2 — the acceptance invariant is self-triggering and unmet.** The ledger states the trigger explicitly:
*"if the yield funnel ever lets the pot exceed the cost of nudgeSize mints, pure-profit MEV returns."*
D-20 records that the funder is an unbounded time-accumulating `nudgeSplit`% stream, so the bound holds only
empirically (~6× margin) and **no longer by construction**. `test_PoC_H01_PotIsNotBoundedByMintCost` and
`test_NudgeDrain_modestPrice_stillNetProfitable` (20,000× profit ratio) execute the triggered condition.
The owner-operational invariant that the acceptance was conditioned on is **not code-enforced anywhere in
`BatchNFTMinter.sol`** — verified by reading the whole file: `nudgeSize` (`:106`) is the owner's only lever
and it constrains a count, never a value.

**P3 — "NFTs have no secondary market / cannot recoup in one tx" — dead, and the run-16 re-triage already
predicted this.** The run-16 note in the same ledger entry says the acceptance invariant *"does NOT bound
loss if the minted NFTs carry realizable value: a searcher who realizes NFT value nets ~pot>0 for **any**
pot size."* D-20 confirms the premise is gone (`NFTMinterV2` is a plain `ERC1155Supply` with no transfer
restriction; units stake at 30–45% APY). `test_M01_NudgeMintedNFTsAreImmediatelyRealizable` now *executes*
it end-to-end: the attacker's purely-ratchet mints are staked with no restriction and claim **12.58 phUSD**
after 30 days. The realizable path is not merely theoretical — it is a live protocol function, and it is
the amplifier the run-16 note said would remove the loss bound.

**P4 — the fix rationale is conditional on a behaviour the project has filed `wont-fix`.** This is the
sharpest item in the section. The 2026-06-09 closure says the harm is *"fully closed by the `minReward`
slippage floor."* Two problems:

1. The floor only fires if the caller **sets** it. Ledger **L-05** `990d8c37…` (status **`wont-fix`**) is
   precisely *"`minReward==0` default silently opts out of the slippage guard"*, closed with:
   *"This obligation now lives at the **integration/UI layer**, not the contract."* So M-01's `fixed`
   depends on the mitigation whose default-off behaviour is an accepted, unfixed Low. The two entries lean
   on each other.
2. Story-022 **widened** the L-05 surface without re-triaging it. The scalar `minReward` became a
   **per-token `minRewards[]` array**, parallel to a **caller-supplied `rewardTokens[]`**. A front-end now
   has to get *two* arrays right, per token, per call, and the natspec is explicit that no protection is
   automatic (`src/BatchNFTMinter.sol:258-266`, *"Array hygiene is the caller's responsibility"*).

`test_M01_searcherFrontrunsHonestNudgeClaimant` executes the un-floored path (the default a naive UI
produces) and reproduces the *exact* harm the 2026-06-09 closure said was eliminated: the honest user mints
5 real NFTs, pays **5,947.05** in real mint cost, and receives **0**.
`test_M01_minRewardsFloorDoesNotStopTheFrontRun` then bounds the mitigation honestly: with a correct floor
the loser's batch reverts and their capital is spared — but the searcher **still takes the entire pot**.
The contract's own natspec agrees (`src/BatchNFTMinter.sol:288-291`): *"NOTE: this does NOT stop a
front-runner from winning the pot — whoever qualifies first still takes the entire balance-based payout;
the floor only stops the loser from minting for less than they declared."*

**Conclusion.** M-01's `fixed` status rests on P1 (sound) plus P2/P3/P4 (degraded, dead, and conditional-on-a-`wont-fix`
respectively). The winner-take-all race the closure accepted as *"an ordinary gas auction among real
participants"* is, with P2 and P3 gone, an ordinary gas auction over a **pure-profit** pot that a bot can
realize without ever intending to participate. That is a different economic object from the one that was
accepted.

### 3.3 L-05 `990d8c37…` — status `wont-fix`

Not re-litigated here (its contract-level reasoning is intact: a `count < nudgeSize` batch must legally
pass a zero floor). Two facts are recorded for the operator:

- The `wont-fix` **transferred an obligation to the front-end**: *"user condition 1 ('a normal user never
  mints-and-gets-zero') holds **ONLY if** the front-end derives and passes a non-zero, pot-based minReward…
  for every nudge-qualifying batch."* `test_M01_searcherFrontrunsHonestNudgeClaimant` demonstrates the
  consequence when that obligation is not met. **Nothing in this run verifies that the front-end meets it.**
  That verification is unowned.
- The obligation **grew** under story-022 (scalar → per-token array + caller-supplied token list) and the
  entry has not been re-read since. Worth a re-triage rather than a carry-forward.

---

## 4. Summary of premise status

| Premise | Source of the claim | Status at `0d1a0b2` | Evidence |
|---------|--------------------|---------------------|----------|
| Attacker cannot pick a cheap/free dispatcher | H-01 fix (story-014), M-01 P1 | **HOLDS ✅** | `test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED`; `BatchNFTMinter.sol:101,:315-323` |
| Over-funding is an **owner** action ⇒ Law-3 invalid | H-01 closure | **✗ DEAD** | `BatchNFTMinter.sol:44-49` (permissionless top-up); D-20 (`StableYieldAccumulator.sol:512-516`) |
| Pot < `nudgeSize × mintPrice` "by construction" | `BatchNFTMinter.sol:51-61`; M-01 P2 | **✗ UNENFORCED** | `test_PoC_H01_PotIsNotBoundedByMintCost` (9.5×), `test_NudgeDrain_modestPrice_stillNetProfitable` (20,000×) |
| Payout is related to what the caller paid | H-01 "value-blind" claim | **✗ FALSE** (gate is count-only) | `test_PayoutIsIndependentOfWhatTheCallerPaid`; `BatchNFTMinter.sol:349-354,:429,:452-461` |
| Minted NFTs have no realizable path | M-01 P3 | **✗ DEAD** | `test_M01_NudgeMintedNFTsAreImmediatelyRealizable` (12.58 phUSD in 30 d) |
| `minReward` floor "fully closes" honest-user overpayment | M-01 P4 (2026-06-09) | **✗ CONDITIONAL on L-05 `wont-fix`** | `test_M01_searcherFrontrunsHonestNudgeClaimant` (0 reward, 5,947 paid) vs `test_M01_minRewardsFloorDoesNotStopTheFrontRun` |

**Net:** of six premises behind the accepted nudge lineage, **one holds**, **four are dead or unenforced**,
and **one is conditional on a separate `wont-fix`**. The lineage's executable witness now exists again and
it does not support the suppressions in their current form.

---

## 5. What this does NOT establish

Stated so the result is not over-read:

- **No principal theft.** Nobody's staked NFTs or phUSD principal are at risk in any of the 11 tests. The
  value at stake is the nudge pot, which is bounded by whatever has been funded into the batcher.
- **No new severity is asserted here.** This task re-tests premises; it does not classify. The run's
  standing severity positions (ECON-001 settled **Medium** at D-22 on live on-chain evidence; F-20-01;
  ECON-004 Low) are unchanged by this document and are the correct place for the severity conversation.
- **The mainnet picture from D-22 still applies and moderates all of the above:** `RatchetBatchNFTMinter`
  holds **0** of everything, `NudgeRatchet.batchMinter()` has been repointed, and no historical loss
  occurred via this path. These PoCs prove the *mechanic*, not present exposure.
- **H-01 leg 1 is a real fix.** Do not use this document to argue the story-014 minter/dispatcher pinning
  should be revisited — `test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED` exists specifically
  to keep that closure proven.
- **The D-16 fix trap still governs any remedy.** The correct fix for the duplicate/pot family is
  `min(snapshot[i], balanceOf(this))` or a dedupe — **never** a `balanceOf` re-read at the payout site,
  which the spec's §4.2 and `BatchNFTMinter.sol:326-344` / `:438-451` warn against in three separate places.

---

## 6. Housekeeping

- Four new files under `workspace/phoenix-nft-staking/test/`:
  `PoC_NudgeLineage_H01.t.sol`, `PoC_NudgeLineage_MevFrontrunNudge.t.sol`,
  `PoC_NudgeLineage_NudgeDrain.t.sol`, `PoC_NudgeLineage_M01PriceInflation.t.sol`.
- The four `.bak` originals are **untouched** (verified by timestamp and size).
- No file under `lib/` was opened read-write. No ledger write of any kind.
- Reproduce with:
  `cd workspace/phoenix-nft-staking && forge test --match-path "test/PoC_NudgeLineage_*" -vv`
