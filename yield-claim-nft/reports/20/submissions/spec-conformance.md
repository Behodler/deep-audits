# Spec-Conformance Report (Law-2 Faithfulness): yield-claim-nft, run 20

- **Run:** `yield-claim-nft-20` · regression `d4cc563..2bfa090` · branch `master` · HEAD `2bfa0905b30a10dafcfd8944dad3503b3b802d18`
- **Stories in range:** story-048 (`UniPoolerV2`, new contract) and story-049 (`PromotionUniV2_Eth` Leg A moved from Balancer to Uniswap V2). Both stories sit in **auto-complete**, which is a final state: agent review passed and no formal human review has taken place.
  - story-048: `~/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/048-unipoolerv2-uniswap-v2-zap-pooler.md`
  - story-049: `~/code/product-owner/stories/yield-claim-nft/auto-complete/yield-claim-nft-Balancexit/049-promotion-univ2-eth-leg-a-uniswap-v2.md`
  - Supporting plan: phStaging2 `docs/BalancerWinddownPlan.md` §4 Stage 1a / Stage 2 / §5. Verbatim copies are in `reports/20/story-intents.md`.
- **Also in range:** a pin bump of story-029 (nft-staking, `lib/` only, out of scope here). story-043 code is unchanged, so it was not re-graded.

## Purpose

This report covers Law 2 only: does each feature do what its `[story-NNN]` document says? It is kept separate from the QA bundle. When a deviation also has security impact, the deviation carries its own security label (H/M/L/Q), and this report links to it instead of filing it twice.

## Verdicts

| Story | Verdict |
|---|---|
| story-048 | **Faithful in code.** Every checked criterion holds. Once the contract-name prefix is normalised, `_dispatch`, `_psmDonate` and every retained setter, auth and rescue function are byte-identical to `BalancerPoolerV2`. The Balancer surface is removed. The constructor checks `{token0, token1} == {sUSDS, phUSD}` in either order and reads no reserves. `pool()` carries `onlyAuthorizedPooler whenNotPaused nonReentrant`, reverts on zero floors and on an empty pair, uses the closed-form `s` exactly as the plan gives it, and keeps the LP on the pooler. There is no price ceiling and no `pauser()`. **Two documentation/spec deviations** are recorded below (F-01-048, F-02-048), and **one story claim is falsified empirically** (cross-reference to L-25). |
| story-049 | **Faithful.** `BALANCER_VAULT`, `BALANCER_POOL`, `unlockCallback`, `IUnlockCallback` and the Balancer imports are all gone; a grep for `balancer|unlock` returns nothing. `_swapSusdsForPhusd` uses `UNIV2_ROUTER.swapExactTokensForTokens` along `[sUSDS, phUSD]` with an exact approval that is reset afterwards. `pool()` now reverts when `minPhusdOut == 0`. Legs B and C are unchanged apart from comments. |

**Law-1 override check: no story was escalated as unsafe.** Five candidates were evaluated and not escalated. See *Evaluated, not escalated* below.

---

## F-01-048: `UniPoolerV2` inherits F-01-047 verbatim. `DonationSkipped` and the `_dispatch` NatSpec still list "dust", but the dust branch is a silent no-op

- **Ledger:** `ycn20f1` · fingerprint `771101e7d7e664ff84c4633629744ba385dc7497405a081ce5be48eed925f23d` · informational · status `open`
- **Location:** `src/dispatchers/UniPoolerV2.sol` L129-L131 (`DonationSkipped` NatSpec) and L284-L286 (`_dispatch` NatSpec). The dust branch itself is in `_psmDonate`, L349-L353.
- **Relation:** a new-contract instance of **F-01-047** (`5d6538f7…`, open, `BalancerPoolerV2`). It is filed as its own entry because story-050 deletes `BalancerPoolerV2`. If it were folded in, F-01-047 would close as code-removed while the same wrong documentation lives on in the replacement. Related monitoring gap: **L-18** (`482cefc3…`, open), which this run gains a UniPoolerV2 second location.

### Story text (what was directed)

> **Kept verbatim.** `_dispatch`, `_psmDonate`, `setBatchDonationSize`, … `rescueERC20` (also the LP exit), and `primeToken() == USDS`. Keep all events, errors and storage semantics the dispatch suite relies on.
>
> (story-048, Technical Details)

### Actual behaviour

Because the code was copied verbatim, the run-19 documentation defect was copied with it:

```solidity
/// @notice Emitted when a donation attempt is silently skipped (PSM outage / fee spike /
///         dust). `usdsParked` USDS stays on the contract for the next dispatch to retry.
event DonationSkipped(uint256 usdsParked);                                   // L129-L131
...
///      so any PSM failure (outage, fee spike, empty reserve, dust) parks the USDS instead   // L285
```

`_psmDonate` turns a dust sweep (`gemAmt == 0`) into a clean no-op (L349-L353: *"a dust-sized sweep whose gemAmt floors to zero must short-circuit to a clean no-op here rather than propagate a revert into the caller's catch"*). No revert ever reaches the `catch`, so `DonationSkipped` is **never** emitted for dust. The new contract-level NatSpec (L26-L32) leaves dust off its failure list, so the contract now contradicts itself.

### Deviation

Documented behaviour diverges from shipped behaviour. The code is correct. An operator who monitors `DonationSkipped` as the dust signal will never see it fire.

### Recommendation

Remove "dust" from the `DonationSkipped` and `_dispatch` NatSpec. The change touches comments only, so it does not breach story-048's verbatim-code clause.

---

## F-02-048: the BalancerWinddownPlan Pauser steps conflict with story-048, and neither document names the pool-only kill switch

- **Ledger:** `ycn20f2` · fingerprint `49c7408c9404f84553b678d315f699d83eb62e6723b22f3930eaaa384980fc22` · informational · status `open` · footgun
- **Location:** `src/dispatchers/UniPoolerV2.sol` (contract surface: no `pauser()`. `pause()` is `onlyMinter` in the base `ATokenDispatcherV2`. `dispatch` is `whenNotPaused`.)
- **Nature:** the supporting plan conflicts with the authoritative story. **The code follows the story and has no defect.** The risk falls on the phStaging2:100/103 cutover script, which is written from the plan.

### Plan text (what the cutover author will read)

> Stage 1a Tests: "Dispatch still works while the pooler is paused."
>
> Stage 2, step 7 (Configure `UniPoolerV2`): "Register with the Pauser."
>
> Stage 2, step 10: "**Retire the old pooler:** pause it and unregister it from the Pauser."
>
> (BalancerWinddownPlan.md §4)

### Story text (authoritative)

> **The plan's test "Dispatch still works while the pooler is paused" contradicts the code.** `ATokenDispatcherV2.dispatch` is `whenNotPaused`, so dispatch cannot work while the pooler is paused.
>
> **Do NOT add a `pauser()`** to make the dispatcher Pauser-registrable. … `Pauser.register` requires `IPausable(c).pauser() == Pauser`, dispatchers have none, and no prior dispatcher cutover registered one.
>
> (story-048, Concerns, implemented as Autonomous Decision 5)

### Actual behaviour

`UniPoolerV2` has no `pauser()`, so it cannot be registered with the Pauser and plan step 7 would revert. `BalancerPoolerV2` was never registered, so the "unregister" in step 10 does nothing. Pausing either pooler blocks `dispatch`, which takes down index-4 mints together with `pool()`. The failure is loud and loses no funds. The plan's underlying goal of stopping pooling while keeping mints running *can* be met with owner `incrementAuthVersion()`, which revokes every authorized pooler of `pool()` and leaves `_dispatch` untouched. **Neither the plan nor the story names that lever.**

### Recommendation

Amend the plan as follows:
- Delete the Pauser registration in Stage 2 step 7 and the unregister in step 10.
- Rewrite the Stage 1a test as "dispatch works while `pool()` is unavailable".
- Record `incrementAuthVersion()` as the pool-only kill switch.

Check this when script-auditor runs on the `unipooler-cutover` entry point.

---

## Cross-reference: L-25, a story-048 claim falsified by a passing PoC (Law-2 aspect of a security finding)

- **Security filing:** **L-25** `ycn20l25` · fingerprint `8ec2be7d59270e73e7f7c2cf1759514ebc94d198324477c8f2a22f4b82c54ef7` · Low · QA bundle. It has no separate F label, so it is not filed twice.
- **PoC:** `yield-claim-nft/work/test/run20/DonationStrand.t.sol` (`test_donationFrontRun_strandsPhusd`, `test_donationFrontRun_quoteNotAValidFloor_andFreeToRepeat`, `test_donationFrontRun_exactRevert`). The broken Tier-3 invariants P1, P4 and P8 were reproduced independently by forge and medusa.

### Story / plan text (what was claimed)

> **Why it can't be sized off-chain.** … Deriving `s` from the reserves the swap actually executes against removes that failure mode entirely:
> - A front-run changes `s` and the price we buy at, but not the leftover, which stays near zero.
> - The worst the front-run can do is make us buy at a worse price, and that is what the slippage parameters bound.
>
> Tests: "A front-run reserve shift reverts on `minPhusdOut` or `minLP`, and **never strands a refund**."
>
> (plan §4 Stage 1a, copied verbatim into story-048 Background)

The contract NatSpec repeats both claims: *"a front-run changes `s` and the price we buy at but never the leftover"* (L50-L51) and *"the quote remains a valid floor"* (L429).

### Actual behaviour

The claims hold only for **swap-style** front-runs. `pool()` and `quotePool()` size `s` from `getReserves()` without calling `sync()`. An unsynced sUSDS **donation** to the pair gets absorbed by the `swap()`, so the zap is sized against stale reserves:

- **Strand:** a 0.5% donation (5,105.88 sUSDS into a 1M/1.06M pool) followed by `pool(100,000, quote·0.99)` succeeds and leaves **229.398 phUSD** on the pooler. The dust bound is tens of wei. The phUSD is protocol-held and recoverable only by owner `rescueERC20`.
- **DoS:** a 2% donation makes `pool(a, quoteOut·0.99, quoteLP·0.99)` revert with `UniPoolerV2__InsufficientLP(48746147894859096248178, 49179748976765704050059)`. The attacker then `skim()`s the donation back, so the attack can be repeated for gas alone. The quote is therefore **not** a valid floor.

### Deviation and disposition

The story makes a factual safety claim that is false for one front-run class. The security severity is honestly Low: no value leaves the protocol, the strand is paid for by the attacker at about 22x, and the DoS costs only gas and is neutralised by `sync`/`skim`. The **spec text should be corrected** whether or not the code is changed. Recommendation: call `IUniswapV2Pair(pair).sync()` (or `skim` to self) at the top of `pool()` before reading reserves, and correct the NatSpec and the story/plan wording to "for swap-style front-runs".

---

## Cross-reference: Q-21 / ECON-002, the plan §5 depth premise (plan-premise error, not a code deviation)

- **Filing:** **Q-21** `ycn20q21` · fingerprint `4c2f9c705c39776aba9242b9c1871f1e165a8f55faeeaefb93abe594e58b41e6` · informational, carried in the QA bundle with sizing guidance. story-faithfulness deliberately files no separate F entry, to avoid a duplicate.

### Plan text

> **Worked example at today's reserves** (X ≈ 33,804, Y ≈ 34,817, p ≈ 0.971): … Δ = 1,000 → 0.9996
>
> **The pool is shallow:** about $1k of sUSDS moves phUSD from 0.971 to peg, so a modest `pool()` can lift the price above $1.
>
> (BalancerWinddownPlan.md §5)

### Actual behaviour

Plan §5 sizes the zap against the **full** Balancer pool depth. Stage 2 step 4 seeds the V2 pair with only the protocol's **62.9%** of the BPT, about 19.1k sUSDS and 21.9k phUSD per side, which makes the pair about 1.59x shallower. phUSD therefore crosses $1 at roughly a **$636** zap, not roughly $1k. The designed arbitrage skim on POL (no price ceiling, which is intended) is larger per zap than the plan states. The outcome depends on an open plan question: whether the `0xc65f…e8db` EOA (37.1% of the BPT) migrates.

### Disposition

The story is not unsafe: the arbitrage skim is a deliberate and bounded design cost under Law 3. The numeric premise is wrong, though, and the keeper sizes zaps from it. Before Stage 2, either redo §5 at 62.9% depth or settle the EOA question. The keeper should split `pool()` into chunks so that post-zap spot stays at or below $1. The same corrected depth also feeds **L-23** (`c15c71fd…`, shared-venue coupling).

---

## Cross-reference: L-21, the verbatim `_dispatch` clause versus a Law-1-sanctioned guard (FAITH-003, folded)

- **Filing:** **L-21** `ycn20l21` · fingerprint `6867d791…` · Low footgun.
- story-048 requires `_dispatch` to be copied **verbatim**, and *"any new guard or modifier belongs on UniPoolerV2, never on `ATokenDispatcherV2`."* The code is faithful, and so it has no non-default-hook guard. If the cutover skips or reorders `setHook`, index-4 mints accrue zero mint-debt and fail open.
- Law-1 evaluation: the story is **not** unsafe. The problem is an owner-omission footgun, not an exploit. If the owner adopts an in-`_dispatch` guard, **Law 1 outranks Law 2**: record a waiver on the verbatim clause so that a later scan does not grade the guard as a story-048 deviation. A guard supplied through the constructor, outside `_dispatch`, needs no waiver.

---

## Evaluated, not escalated

| Story | Candidate | Verdict |
|---|---|---|
| story-048 | `_dispatch` copied verbatim with no hook guard (CODE-001) | Not story-unsafe: an owner-omission footgun, filed as L-21 |
| story-048 / plan §5 | "Deliberately no price ceiling" together with the depth premise (ECON-002) | Not story-unsafe: a deliberate, bounded design cost. The premise error is filed as Q-21 |
| story-049 | Leg A buys on the protocol-owned pair that UniPoolerV2 zaps into (CODE-002) | Not story-unsafe: the venue is the explicit story intent. The keeper-sequencing coupling is L-23 |
| story-048 | A front-run in the favourable direction succeeds instead of reverting (Decision 7) | Faithful: the "reverts" checklist item targets the adverse shift |
| story-048 | `pair_` is checked against the token set only, not against `factory.getPair` | No criterion breached: an obvious misconfiguration (Law 3). The hardening is Q-19 and the third-party pre-seed facet is L-24 |

---

## Summary

| Label | issueId | Fingerprint | Story | Kind | Status |
|---|---|---|---|---|---|
| F-01-048 | ycn20f1 | `771101e7…` | 048 | documentation deviation (inherited from F-01-047) | open (new) |
| F-02-048 | ycn20f2 | `49c7408c…` | 048 / plan | spec conflict (plan vs story), footgun | open (new) |
| L-25 (xref) | ycn20l25 | `8ec2be7d…` | 048 / plan | story claim falsified by a passing PoC | Low, QA bundle |
| Q-21 (xref) | ycn20q21 | `4c2f9c70…` | plan §5 | plan-premise error | informational, QA bundle |
| L-21 (xref) | ycn20l21 | `6867d791…` | 048 | verbatim clause vs Law-1 guard | Low, QA bundle |

**Carried forward below (still open):** F-01-043, F-01-045, F-01-047, F-02-046, F-03-046. F-01-044 is wont-fix and is not carried.

**Proposed for human action (no status changed):** **F-01-045** (`25212e80…`) should be re-affirmed against story-049 or retired as superseded. Its "story-045 fully faithful across 8 intents" verdict was graded against the Balancer Leg A that `a4d80f4` removed. It is **not** a fix candidate. **F-01-047** stays open: run 20 links its UniPoolerV2 instance (F-01-048) to it and does not attach that instance as a second location.

---

# Carryover: prior open faithfulness records (verbatim full copies)

Each record below is still **open** in the ledger. Law 1 says an open finding is never dropped from view and never reduced to a pointer, so each record is reproduced **in full** from its originating report rather than linked. A metadata header is placed above each copy. F-01-044 (`3e638eb9…`) is **wont-fix** and is not carried. Line numbers and links were accurate at each originating commit, and the relative links follow that run's directory layout (`reports/yield-claim-nft/NN/`, `lib/yield-claim-nft/src/…`). Re-verify every location against HEAD `2bfa090` before acting.

---

## [C] F-01-043 — Intended debt/release decoupling (story-unsafe note; RESOLVED out-of-scope)

> **Carryover: copied in full from `yield-claim-nft-15`.** This record first appeared in **audit 15** as **F-01-043**. It was **not triaged**, and is **still valid**. `NudgeRatchetDelayRelease.sol` is unchanged in this range, so the record was not re-examined and is carried for recall only. `lastSeenRun` was **not** bumped. Triage it with `/ledger yield-claim-nft`.

- **Original label:** F-01-043 (run `yield-claim-nft-15`) · **Story:** story-043
- **Status:** open (untriaged, informational)
- **Fingerprint (unchanged):** `6753c76b07091ec7c0cfa05e4bde4c307ce6d4a82e10c9c8445eb8e8e9bf4268`
- **First seen:** yield-claim-nft-15 · **Last seen:** yield-claim-nft-16 · **Still open as of:** yield-claim-nft-20
- **Original report:** [yield-claim-nft/reports/15/submissions/spec-conformance.md](../../15/submissions/spec-conformance.md)

*The text below is a verbatim copy of the original section. Its original heading was `## F-01-043 — Intended debt/release decoupling (story-unsafe note; RESOLVED out-of-scope)`.*

**Classification:** story-unsafe note, **NOT** a security finding. Faithful code;
the question is about the story's *own* design, escalated under Law 1 and resolved.

**Story / NatSpec intent text deviated-toward**

The contract's NatSpec header makes the decoupling an explicit, accepted design
property (`src/dispatchers/NudgeRatchetDelayRelease.sol:20-36`):

> KNOWN / ACCEPTED DESIGN PROPERTIES — these are intentional; DO NOT re-flag as findings:
>   * Debt/release timing is DECOUPLED ON PURPOSE. phUSD mint-debt accrues (and the
>     downstream staker may realise phUSD via the hook's `pull()`) at DISPATCH time, while
>     the USDC backing it can still be sitting on this contract, un-released. There is
>     therefore an intended, admin-controlled window in which phUSD has been realised but
>     the corresponding USDC has NOT yet reached the batchMinter. This is the whole point
>     of the contract (rate-controlled release), not an accounting bug.
>   * No unbacked phUSD is created by this. The USDC that backs the accrued debt is HELD on
>     this contract from dispatch onward; `release` only RELOCATES that existing backing to
>     the batchMinter (it never mints or burns), so total system backing is conserved at
>     all times. The only thing the release schedule changes is WHERE the backing sits
>     (dispatcher vs. sink), never WHETHER it exists.
>   * Release rate is a trusted admin lever. `release` is gated to an owner-managed
>     `releasers` whitelist; the owner deliberately controls how fast held USDC flows to
>     the batchMinter. Slow/withheld releases are an operational choice, not a liveness bug.
>   * `rescueERC20` can withdraw held `_token` (USDC). This is an accepted owner power with
>     the same trust assumption as `setBatchMinter`; see its NatSpec.

**Actual behavior** (`_dispatch` L131-143 + `release` L108-111)

The implementation faithfully realises the decoupling: mint-debt accrues against
`amount` in `hook.onDispatch` at dispatch time (base `ATokenDispatcherV2.dispatch`,
unchanged), while the backing USDC is held on the dispatcher and can only be moved
to the `batchMinter` sink by a whitelisted releaser calling `release(amount)` at an
admin-controlled rate. There is no implementation-vs-intent gap.

**The Law-1 escalation that was raised**

story-faithfulness flagged the *story's own* safety argument. The NatSpec rests on
"total **system** backing is conserved" (USDC exists somewhere), but the solvency
invariant relevant to a holder who has *realised* phUSD is "the **sink** the claim
redeems against is funded when the claim is realised." During the intended hold
window, phUSD can be realised via `hook.pull()` while the `batchMinter` sink holds
**0 USDC**, and the dispatcher-held USDC is unreachable to anyone but the releaser —
a transient (and, if releases lag, unbounded) under-funded-sink window set by an
admin lever. This is **not** the `rescueERC20` owner-footgun (an acknowledged Law-3
owner power, out of scope): the window exists under *normal* operation of the core
feature even with a benign releaser, because realisation and sink-funding are
separated by design.

**econ-scanner resolution — OUT OF SCOPE (DEDUP-001)**

econ-scanner resolved the escalation: **no in-scope contract couples
USDC-at-`batchMinter` to phUSD minting or redemption.** The phUSD redemption-backing
model is the **external** one already suppressed in the ledger as **DEDUP-001
(owner-driven external backing / unbacked-phUSD)**. The under-funded-sink concern
only bites if phUSD redeems specifically against the `batchMinter` sink's
instantaneous USDC balance; within the audited boundary it does not, and prior
Tier-3 work (run-13) showed the NudgeRatchet/hook path runs ≥2:1 over-backed with no
over-mint (double-mint/under-backing REFUTED). The implementation faithfully
realises the story, and the story's own design is acceptable **within the audited
boundary**. Recorded here, not promoted to a Medium.


---

## [C] F-01-045 — story-045 PromotionUniV2_Eth rework is FULLY FAITHFUL and Law-1 safe (NEW, informational — headline record)

> **Carryover: copied in full from `yield-claim-nft-18`.** This record first appeared in **audit 18** as **F-01-045**. It was **not triaged** and is still `open`. **⚠ Its premise is now stale.** `a4d80f4` (story-049) removed the Balancer Leg A that this "fully faithful" verdict graded. The record now describes superseded code. **Human action proposed:** re-affirm it against story-049 or retire it as superseded. This is not a fix candidate, and its status was not changed. `lastSeenRun` was **not** bumped. Triage it with `/ledger yield-claim-nft`.

- **Original label:** F-01-045 (run `yield-claim-nft-18`) · **Story:** story-045
- **Status:** open (⚠ re-affirm or retire proposed)
- **Fingerprint (unchanged):** `25212e80eef98ec3619636caee5f37b7c420f98df662b9e59db6473e5c2e8367`
- **First seen:** yield-claim-nft-18 · **Last seen:** yield-claim-nft-18 · **Still open as of:** yield-claim-nft-20
- **Original report:** [yield-claim-nft/reports/18/submissions/spec-conformance.md](../../18/submissions/spec-conformance.md)

*The text below is a verbatim copy of the original section. Its original heading was `## F-01-045 — story-045 PromotionUniV2_Eth rework is FULLY FAITHFUL and Law-1 safe (NEW, informational — headline record)`.*

- **Status:** open (informational faithfulness record; NOT a security finding)
- **Contract:** `src/dispatchers/PromotionUniV2_Eth.sol` (`pool`)
- **Story:** `[story-045]` (commit a7ab9db)
- **Fingerprint:** `25212e80…`
- **Verdict:** **FAITHFUL and Law-1 safe** across all 8 intent items.

### Story text

The `[story-045]` commit (a7ab9db) directs the PromotionUniV2_Eth rework to a
**"60/30/10 split, burn-half phUSD, WBTC insurer reserve."**

### Behavior vs. intent — item-by-item conformance

| # | story-045 intent | Contract evidence | Conforms |
|---|---|---|---|
| 1 | **60/30/10 pool split** | split computed at `PromotionUniV2_Eth.sol#L383-L385` | ✅ |
| 2 | **Burn half of the pooled phUSD leg** | half-burn at `#L395-L396` | ✅ |
| 3 | **WBTC insurer-reserve leg** | reserve wiring at `#L108`, `#L162`, `#L267`, `#L275` | ✅ |
| 4 | **Settable `_legC` path** | insurer/reserve leg settable | ✅ |
| 5 | **Insurer role** | insurer role present and enforced on the reserve leg | ✅ |
| 6 | **Consolidated `Pooled` event** | single consolidated `Pooled` emission | ✅ |
| 7 | **`rescueERC20` WBTC-exclusion** | WBTC excluded from rescue at `#L521` (reserve cannot be swept out via rescue) | ✅ |
| 8 | **Donation-split computed on gross** | donation-split taken on the gross amount, not net | ✅ |

All eight items implement the story action exactly as written. There is **no story deviation** and
**no Law-1 concern** — the reworked flow is backing-accretive and intra-protocol, with no theft or
drain vector introduced by the rework.

### Empirical clearance (coverage caveat CLEARED)

The Tier-3 **fork run executed 70/70 pass** and all four rework invariants — **60/30/10 split**,
**burn-half**, **WBTC-reserve**, and **LP-accrual** — were **empirically confirmed on a mainnet
fork** (block 25,550,000). The faithfulness verdict therefore rests on direct on-chain-fork
observation, not static reasoning alone.

> **Separate coverage note (not a faithfulness defect):** the run-16 **stateful-fuzz** harness is
> stale — it calls the pre-story-045 5-arg `pool()` and no longer compiles against the 6-arg
> signature, so Medusa/Foundry invariant *campaigns* do not exercise the reworked flow. That gap is
> tracked as **Q-17** in the QA bundle. It does not weaken this record: the deterministic fork unit
> tests provide direct coverage of the same invariants this run.

### Faithfulness caveats (carried alongside the FAITHFUL verdict)

**Caveat 1 — carried footgun (L-13 / F-01-044), UNCHANGED by story-045.**
The whole-balance ETH sweep in `_legB` plus the open `receive()` (Leg B, `#L453`; open
`receive()`, `#L533`) **survives the story-045 rework unchanged**. Story-faithfulness confirms the
rework did not touch that path. Both twins remain **wont-fix** — the owner has affirmatively
declared the whole-balance sweep an intended feature — and the framing is **sweep +
`rescueETH`-front-run**, *not* accidental-send; Tier-3 INV-4 fork-proved the swept value only ever
reaches protocol-owned LP (non-theft). See F-01-044 below and the L-13 carryover stub.

**Caveat 2 — NatSpec under-explains the burn's dual role (cross-ref Q-16).**
The story **action** ("burn half") is faithfully implemented (item 2 above), and the NatSpec's
*justification* — that the burn exists "so pooled values match" — is **correct**, not misleading:
because Leg A is deliberately over-sized to **60%** of capital, burning half of it is **precisely**
what pulls the pooled phUSD from 60% down to the ~30% that value-matches the ~30% pooled-promotion
leg, so the burn genuinely **is** part of the value-match mechanism. What the NatSpec **omits** is
that this same burn is simultaneously an intentional **~30%-of-every-`pool()`-capital permanent
deflationary spend** that produces zero LP. The **story is faithful; the in-code rationale is
correct but under-explains** (it documents the value-match half of the burn's role and is silent on
the deflationary-spend half). This is recorded here in the Law-2 channel for visibility, and is the
basis for **Q-16** in the QA bundle — retained so a maintainer, reading only the value-match half,
does not delete or resize the burn as "redundant to the leg sizing" (which would break both the
value-match and the intended deflationary economics). Fork-confirmed: 5,000e6 USDC → 1,359e18 phUSD
burned, backing-accretive and Law-1 clean.

### Disposition

**KEEP visible** as a faithfulness / spec-conformance record (informational), consistent with
F-01-043 / F-01-044. **Do NOT** promote to a security finding; **do NOT** bury.


---

## [C] F-01-047 — `DonationSkipped` is still documented as a dust signal, but the dust branch no longer emits it

> **Carryover: copied in full from `yield-claim-nft-19`.** This record first appeared in **audit 19** as **F-01-047**. It was **not triaged**, and is **still valid**. It was **re-observed this run** (`lastSeenRun` set to yield-claim-nft-20) on `BalancerPoolerV2`, whose code is unchanged. Its new-contract instance on `UniPoolerV2` is filed separately as **F-01-048** (`771101e7…`) and **linked** here, not attached, so this entry cannot close as code-removed when story-050 deletes BalancerPoolerV2. The security framing is still **L-18**, counted once. Triage it with `/ledger yield-claim-nft`.

- **Original label:** F-01-047 (run `yield-claim-nft-19`) · **Story:** story-047
- **Status:** open (untriaged, informational)
- **Fingerprint (unchanged):** `5d6538f76fbe2018c1a1bbcd0bbc4130e730b3f49d2951d3c02e1a06ed8bae67`
- **First seen:** yield-claim-nft-19 · **Last seen:** yield-claim-nft-20 · **Still open as of:** yield-claim-nft-20
- **Original report:** [yield-claim-nft/reports/19/submissions/spec-conformance.md](../../19/submissions/spec-conformance.md)

*The text below is a verbatim copy of the original section. Its original heading was `## F-01-047 — `DonationSkipped` is still documented as a dust signal, but the dust branch no longer emits it`.*

- **Type:** faithfulness — documented-behaviour / monitoring-fidelity deviation · **Law 2**
- **Severity:** informational (QA-level); **cross-references QA finding L-03** (ledger **L-18**)
- **Contract:** `src/dispatchers/BalancerPoolerV2.sol` — `_psmDonate` (event declaration `:134`, guard `:329`)
- **Story:** `[story-047]` (commit `d4cc563`)
- **Counting:** counted **once**, in the QA bundle as L-03. This record is its Law-2 framing, **not** a second finding.

### Spec text

The event's own NatSpec, present in the tree at `d4cc563` and **unchanged** by this commit:

> "Emitted when a donation attempt is silently skipped (PSM outage / fee spike / **dust**).
> `usdsParked` USDS stays on the contract for the next dispatch to retry."

The **same commit's** new contract-level NatSpec, giving operators their monitoring instruction:

> "This means a **streamer misconfiguration is quiet**: watch `DonationSkipped` and the contract's
> USDS balance."

And the authorising story bullet:

> "guard the whole PSM+streamer body behind `if (gemAmt > 0)` so a dust sweep is a clean no-op
> instead of a caught revert"

### Shipped behaviour

Under `e4de393`, `require(gemAmt > 0, "BalancerPoolerV2: donation dust")` reverted into the caller's
`catch`, which emitted `DonationSkipped(remainingUSDS)`. Under `d4cc563` the `if (gemAmt > 0)` guard
returns normally, so **a dust sweep emits nothing at all** — no `DonationSkipped`, no
`BatchDonatedViaPSM`.

### The deviation

The *code change itself is story-authorised* — bullet 4 asks for "a clean no-op instead of a caught
revert" and that is exactly what shipped. This is **not** an unauthorised behaviour change.

The deviation is that **the resulting event loss is acknowledged nowhere**. The contract's own
documented observability contract was not updated in the same commit, and the same commit **doubles
down** by telling operators to monitor `DonationSkipped` — at precisely the moment that event became
the sole signal for a widened failure set. The `DonationSkipped` NatSpec still advertises **dust**
as a trigger it can no longer signal. Dust-driven skips are now invisible in logs while the
documentation says otherwise.

### Impact

Bounded and low. The condition requires `usdsAmount * WAD / (conv * (WAD + tout))` to floor to zero
— a sub-1e-6-USDC sweep. The USDS parks and is re-swept, so **no value is at risk**. This is a
monitoring-fidelity defect, not a loss path.

### Suggested resolution

Either emit `DonationSkipped(usdsAmount)` from the `else` of the guard, or strike "dust" from the
event's NatSpec and say so in the contract-level ops note. Confidence: high.


---

## [C] F-02-046 — a story cannot pre-declare a hazard out of scope: the mandatory-streamer NatSpec's "NOT an audit finding" is correct for deploy-ordering, over-broad for repoint

> **Carryover: copied in full from `yield-claim-nft-19`.** This record first appeared in **audit 19** as **F-02-046**. It was **not triaged**, and is **still valid**. `NudgeRatchet.setBatchMinter` is unchanged in this range, so the record is carried for recall only. `lastSeenRun` was **not** bumped. Triage it with `/ledger yield-claim-nft`.

- **Original label:** F-02-046 (run `yield-claim-nft-19`) · **Story:** story-046
- **Status:** open (untriaged, informational)
- **Fingerprint (unchanged):** `26baeb3e77d7ae79803b614ddabc1f382a525fcc532b9513532844df6a6b1ea6`
- **First seen:** yield-claim-nft-19 · **Last seen:** yield-claim-nft-19 · **Still open as of:** yield-claim-nft-20
- **Original report:** [yield-claim-nft/reports/19/submissions/spec-conformance.md](../../19/submissions/spec-conformance.md)

*The text below is a verbatim copy of the original section. Its original heading was `## F-02-046 — a story cannot pre-declare a hazard out of scope: the mandatory-streamer NatSpec's "NOT an audit finding" is correct for deploy-ordering, over-broad for repoint`.*

- **Type:** story-unsafe (Law-1 override check applied; `securityEscalation: false` after assessment) · **Law 3** disposition
- **Severity:** accepted **operational hazard** (Law-3 footgun); **cross-references QA finding L-01** (ledger **L-16**), which is now the sole security-side carrier — the Medium drafted as `M-02` was **withdrawn** and folded into `L-01` (see `M-02.md`)
- **Contracts:** `src/dispatchers/NudgeRatchet.sol:155-160`, `src/dispatchers/Uniboost.sol:246-250`, `src/dispatchers/PromotionUniV2_Eth.sol:392-396`
- **Story:** `[story-046]` (commit `1745e83`)
- **Counting:** the availability impact is counted **once**, as QA `L-01` (ledger `L-16`). It was previously counted as `M-02`; that Medium was withdrawn on 2026-07-25 when its stranding argument was refuted by mint atomicity, and `L-01` absorbed it. This record is the Law-2/Law-3 framing and remains a single, non-double-counted cross-reference.

### Spec text

`[story-046]`, shipped verbatim into all three contracts' NatSpec:

> "If the streamer is set but ops forgot `registerStream(batchMinter, _token, duration)` on it,
> every `dispatch` reverts `NudgeStreamer__NotRegistered()`. **This is the accepted consequence of
> the mandatory-streamer decision, NOT an audit finding.** … Repointing `batchMinter` to an address
> with no registered stream re-arms the same failure mode; register the new pair first."

### Assessment of the "NOT an audit finding" claim, on its merits

A story is a specification of intent, not a scoping authority over the audit. The claim was
therefore assessed rather than accepted, and it **splits**.

**The revert path is confirmed.** `NFTMinterV2._executeMint` (`src/NFTMinterV2.sol:191`) calls
`dispatch` with **no try/catch**, so a `NudgeStreamer__NotRegistered()` bubbles all the way out and
**every user mint at that dispatcher index reverts**. `NudgeRatchet` has no donation-disable switch
and no `bal == 0` escape once it holds any balance, so the brick is total for that index.

**No value is at risk.** The user's `safeTransferFrom` of `price` happens inside the same reverting
transaction (`NFTMinterV2.sol:183`), so nothing is stranded and no NFT is minted against a lost
payment. Recovery is cheap in principle: the minter owner can set `config.disabled` on the index, or
the streamer owner can call `registerStream`. Availability-only, owner-fixable, no residual state
damage.

**Deploy-ordering case — the claim is CORRECT (Law 3, suppress).** A freshly deployed dispatcher
with `nudgeStreamer == address(0)` fails **loudly and immediately** on the very first dispatch,
before any user traffic. That consequence is obvious to a competent operator. Not a finding.

**Repoint case — the claim is NOT correct (Law 3, in scope as a footgun).** `setBatchMinter(new)` /
`setRecipient(new)` on a **live** dispatcher **succeeds silently** and arms
`NudgeStreamer__NotRegistered()` on every subsequent user mint. Clearing it requires calls on **two
other contracts** — `batchMinter.setNudgeTokenWhitelist(token, true)`, then
`NudgeStreamer.registerStream(...)`, the latter `onlyOwner` on a contract in a **different
repository** (`phoenix-nft-staking`) that may not share the dispatcher's owner key. The dispatcher
exposes **no view and no guard** that would surface the missing registration before it bites, and
`setBatchMinter` does not check it. **A competent, non-malicious owner would be surprised** — which
is exactly the Law-3 footgun test. The same shape applies to `Uniboost` / `PromotionUniV2_Eth` when
an owner *enables* a previously-dormant donation (`setDonationSplit(>0)` / `setRecipient(x)`)
without a wired streamer.

### Disposition

**No Law-1 escalation** — no exploit, no value loss, no unrecoverable state. But the correct
disposition is **not** "not a finding": it is **known, accepted, and recorded as an operational
hazard with safe-config guidance**, which is what this entry does. The blanket NatSpec disclaimer is
retained as owner intent for the deploy-ordering half and **overridden for the repoint half**.

### Suggested resolution (non-blocking)

Have `setBatchMinter` / `setRecipient` optionally probe
`INudgeStreamer(nudgeStreamer).pendingStream(newSink, token)` — a registered pair is a cheap
positive signal — or ship a runbook item binding every sink repoint to the corresponding
`registerStream` call. Confidence: high.


---

## [C] F-03-046 — a fifth donor was left un-routed: `NudgeRatchetDelayRelease` still pays the sink directly

> **Carryover: copied in full from `yield-claim-nft-19`.** This record first appeared in **audit 19** as **F-03-046**. It was **not triaged** as a faithfulness record and is still `open`. Its security framing, run-19 **M-01** (ledger **M-05** `e6fbf0d6…`), is owner **wont-fix**. That disposition is not transferred automatically to this Law-2 record. A human should decide at `/ledger` whether it closes this record too. `lastSeenRun` was **not** bumped. Triage it with `/ledger yield-claim-nft`.

- **Original label:** F-03-046 (run `yield-claim-nft-19`) · **Story:** story-046 / story-047
- **Status:** open (security twin M-05 is wont-fix)
- **Fingerprint (unchanged):** `38151cebd72ff17b57d3f901f2e20ad14d6128338b5b18f38efbd12ce21fa2ac`
- **First seen:** yield-claim-nft-19 · **Last seen:** yield-claim-nft-19 · **Still open as of:** yield-claim-nft-20
- **Original report:** [yield-claim-nft/reports/19/submissions/spec-conformance.md](../../19/submissions/spec-conformance.md)

*The text below is a verbatim copy of the original section. Its original heading was `## F-03-046 — a fifth donor was left un-routed: `NudgeRatchetDelayRelease` still pays the sink directly`.*

- **Type:** faithfulness — **coverage gap** (not a literal deviation) · **Law 2**
- **Severity:** informational; this is the **Law-2 framing of security finding M-01**
- **Contract:** `src/dispatchers/NudgeRatchetDelayRelease.sol:109` — `IERC20(_token).safeTransfer(batchMinter, amount)`
- **Stories:** `[story-046]` (commit `1745e83`) and `[story-047]` (commit `d4cc563`)
- **Counting:** counted **once**, as **M-01**. **Do NOT double-count as a second security finding.**

### Spec text

`[story-046]` scopes itself to **"three V2 dispatchers"** — `NudgeRatchet`, `Uniboost`,
`PromotionUniV2_Eth` — and `[story-047]` adds a fourth, `BalancerPoolerV2`. Neither mentions
`NudgeRatchetDelayRelease`.

The **purpose** both stories import from the dependency, per `NudgeStreamer`'s contract NatSpec
(`lib/phoenix-nft-staking/src/NudgeStreamer.sol`):

> "Buffers bursty donations per `(batchMinter, token)` and streams them linearly to zero over a
> configured `duration`, **so that whoever calls `batchMint` right after a burst can no longer
> capture a disproportionate share of the reward pot.**"

### Shipped behaviour

`release(amount)` delivers a **lump** of USDC straight to `batchMinter`, bypassing the streamer
entirely. All four *other* donors into the same sink are now metered; this one is not.

### The deviation

**Strictly against the story text, there is none.** Story-046 scopes itself to three named
dispatchers and story-047 to `BalancerPoolerV2`; neither names `NudgeRatchetDelayRelease`. Per
"don't invent criteria", the implementation is faithful to what was asked.

It is recorded here because **the goal the two stories import from the dependency is only partially
achieved**. A mempool-visible `release(X)` remains front-runnable / back-runnable by a `batchMint`
caller — which is precisely the burst-capture the streamer exists to prevent. The stated purpose was
adopted; the coverage was not completed.

### Empirical result (why this carries a security label as M-01)

This is not a theoretical gap. The M-01 PoC (`reports/yield-claim-nft/19/pocs/run19-Tier3Nudge.patch`,
contract `Run19_T4_DelayReleaseBackrun`) captured a **50,000 USDC lump at 100% in the same block**,
while the streamed contrast arm captured **0**. The un-routed leg reproduces exactly the behaviour
the routed legs now prevent.

### Mitigating context

`release` is `onlyReleaser`, so the burst *timing* is admin-chosen rather than attacker-chosen, and
the contract is *itself* a rate-control throttle by design — a manual one instead of a linear one.
The residual is the single-block capture window around each `release` transaction.

> **Do not collapse this into the `phoenix-nft-staking` nudge-front-running entry (ledger
> `858e9e80`, wont-fix).** Different contract, different repository, different fingerprint. The MEV
> class is related; the finding is not the same finding.

### Suggested resolution

Either route `release()` through `collectNudge` as well (a one-line change, same shape as
`NudgeRatchet`), or add an explicit NatSpec line stating that this dispatcher is **deliberately**
outside the streamer because it already provides admin rate control. Confidence: high.

