# Carryover QA Report — originating audit 20 (carried into yield-claim-nft-21)

> **Carryover QA report — audit 20.** Run 20's `submissions/qa-report.md` **was never written**, so there is no original document to prune. This file is rebuilt from run 20's per-finding records `yield-claim-nft/reports/20/findings/{low,qa}/*.json` (originating commit `2bfa0905`); field text is copied verbatim from those records and laid out in the QA-report format. Carried at `267660b`, run 21.
> Retained (still `fix-pending` in the ledger; `fix-pending` is never suppressed): **L-21, L-25, Q-19, Q-21**. Three of the four are verified **FIX-COMPLETE** at `267660b` and proposed `fixed`; the status stays `fix-pending` until a human applies `/ledger`. Q-21 is **NOT-ADDRESSED**.
> Removed as disposed (owner triage 2026-10-01, `wont-fix`): **L-22** (`a846cc40e6`), **L-23** (`c15c71fd22`), **L-24** (`8511fd5206`), **Q-20** (`a9037a2f96`). Faithfulness records F-01-048/F-02-048 are carried separately in `spec-conformance-20.md`.
> Locations link to `2bfa090` (where the findings were made). The run-21 status block under each entry gives the `267660b` lines.
> Issue IDs are the run-20 IDs from the records (`ycn20…`), copied verbatim.

## Low Risk Findings

### [L-21] UniPoolerV2._dispatch (verbatim copy) has no non-default-hook guard: an index-4 cutover that skips or reorders setHook leaves the no-op DefaultDispatchHook wired, so every index-4 mint succeeds while accruing zero phUSD mint-debt <!-- id: ycn20l21 -->

**Severity:** Low *(borderline — Medium is arguable on the M-04 precedent (same class filed Medium). Kept Low because the debt is protocol-own revenue, recoverable by an owner mint, and no party profits. If the owner considers mintDebt load-bearing for phUSD backing/emission accounting, re-weigh to Medium.)*

**Location:** [`src/dispatchers/UniPoolerV2.sol#L290-L320`](https://github.com/Behodler/yield-claim-nft/blob/2bfa0905b30a10dafcfd8944dad3503b3b802d18/src/dispatchers/UniPoolerV2.sol#L290-L320) (`_dispatch`) at `2bfa090`

**Description:** CODE-001 (cross-contract chain: three owner writes on three contracts plus replaceDispatcher(4); only the setHook omission fails open). LOCAL-UP-001 adds the BalancerPoolerMintDebtHook-has-no-hookTypeId detail. FAITH-003 is the story-side annotation and is folded in, not filed separately.

**Impact:** Protocol-own revenue accounting: BalancerPoolerMintDebtHook.mintDebt (ratio% of dispatched USDS, realised by pull() as phUSD minted to the protocol's own recipient) silently stays 0 for every index-4 mint while the DefaultDispatchHook is wired. No user funds move; no third party gains; USDS still flows into POL. The shortfall is reconstructible from Dispatched/mint events and can be made good by an owner mint. Secondary facet: separate-tx setDispatcher/replaceDispatcher ordering opens a fail-LOUD index-4 mint outage window (OnlyDispatcher revert), no loss.

**Likelihood:** low-medium - requires an owner sequencing omission in a multi-step, multi-contract cutover; non-obvious because NudgeRatchet (M-04 fix) fails closed in the identical situation

**Assumptions:** Non-malicious owner; setHook skipped or reordered in the story-048 cutover

**External requirements:** Owner operational error; no attacker

**Path:**

1. Owner deploys UniPoolerV2 (ctor wires no-op DefaultDispatchHook)
2. Cutover replaceDispatcher(4) executes before / without setHook(BalancerPoolerMintDebtHook)
3. Every index-4 mint succeeds; _dispatch has no non-default-hook guard; onDispatch is a no-op
4. mintDebt never accrues; no revert, no event signalling the omission

**Secondary facet:** Fail-LOUD mint outage window: with hook.setDispatcher (plan step 6) and replaceDispatcher (step 8) in separate Ledger txs, index-4 mints through the still-registered BalancerPoolerV2 revert OnlyDispatcher in between; batchMint too if BatchNFTMinterMultiToken.dispatcherIndex == 4. No funds lost. Same mitigation (atomic ordering), so kept inside this finding.

**Law-2 annotation:** story-048 mandates a verbatim _dispatch. FAITH-003: the code is faithful; the story is NOT unsafe (owner-omission footgun, not an exploit). A concrete-only guard (constructor-supplied hook, or stored defaultHook compared in _dispatch) is Law-1-sanctioned; if the owner adopts the in-_dispatch guard, record a waiver on the verbatim clause so later Law-2 scans do not flag it.

**Severity justification:** Non-obvious Law-3 footgun, so in scope, but impact is a recoverable, attacker-less under-accrual of the protocol's own mint-debt (no theft, no user loss, no availability loss). Severity follows the closest sibling L-09 (Uniboost, same base-class fail-open, open Low) rather than M-04: M-04's Medium predates the established sibling precedent and the M-04 fix is per-concrete. Q-08's wont-fix rationale (live, no retrofit) does not transfer to undeployed UniPoolerV2 - a pre-deploy guard is cheap.

**Prior wont-fix disclosure:** Q-08 `96c60b723f` is `wont-fix` (triaged 2026-06-17). Owner's reason, verbatim: "Owner REJECTED — intentional: BalancerPoolerV2 is LIVE and will not be retrofitted with the hookTypeId guard. The guard asymmetry vs NudgeRatchet is an accepted operational state on a deployed contract (Law-3 owner-trusted). Valid finding, accepted-not-fixed (not a false-positive — the guard genuinely is absent; the owner accepts the exposure on the live contract)." Why it does not transfer: Q-08's rationale is scoped to BalancerPoolerV2 being LIVE and not retrofittable. UniPoolerV2 is a new, UNDEPLOYED contract (story-048 gates its deployment on this audit); adding a guard is a pre-deploy choice, not a retrofit. Different contract, different fingerprint: a new instance, not a reopen of Q-08. Q-08 itself stays wont-fix and is NOT attached to.

**Recommendation:** Concrete-only guard on UniPoolerV2 (store default hook, require(address(hook) != defaultHook)) or add hookTypeId() to the pooler hook. Cutover: setHook before or atomically with replaceDispatcher(4); hook.setDispatcher last or same tx.

**Safe-config guidance:** Add a concrete-only guard (stored defaultHook compared in _dispatch, or hookTypeId() on the pooler hook) pre-deploy, with a story-048 verbatim-clause waiver; otherwise setHook before or atomically with replaceDispatcher(4), and verify a DebtAccrued on the first index-4 mint.

**Fingerprint:** `6867d791f35ac9ac3b0058eec51525b64dc8bf3f7172fab2d23936d5d2ecf0bc` (`UniPoolerV2.sol:_dispatch:fail-open-hook-wiring`)

> **Carryover status (run 21, `267660b`).** Ledger **L-21** · `6867d791f3…` · status **`fix-pending`** · last seen `yield-claim-nft-21`.
> **Fix verification: FIX-COMPLETE → proposed `fixed` (human applies: `/ledger yield-claim-nft fixed 6867d791`).** `_dispatch` now opens with `if (address(hook) == _defaultHook) revert UniPoolerV2__HookNotSet();` (`UniPoolerV2.sol:356`; `_defaultHook` captured at `:230`). Evidence: INV3_L21_hookGuard PASS (forge 1M calls + Medusa 674k), falsified by mutant M3; Halmos P1a/P1b/P1c/P1d/P2a/P2c PASS; P2b (depth-2) UNVERIFIED. Residuals parked in manual review: MR21-01 (fresh-`DefaultDispatchHook` opt-out, documented in story-051), MR21-02 (cutover ordering window, fail-loud). Full write-up in `../qa-report.md` § Fix verification.

---

### [L-25] UniPoolerV2.pool/quotePool size the zap from getReserves() without sync(): an unsynced token donation to the pair is absorbed in swap(), stranding non-dust phUSD on the pooler (229 phUSD on a 100k zap after a 0.5% donation) or reverting pending pool() with InsufficientLP, with the donation recoverable via skim() for gas only <!-- id: ycn20l25 -->

**Severity:** Low *(borderline — Medium would require sustained availability loss that matters: pool() delay does not affect users, funds, or the mint path, and keeper countermeasures (private RPC already recommended by L-22; sync() at top of pool()) are trivial. Re-weigh to Medium only if pool() latency becomes economically load-bearing (e.g., a time-sensitive peg defence relying on zaps).)*

**Location:** [`src/dispatchers/UniPoolerV2.sol#L386-L458`](https://github.com/Behodler/yield-claim-nft/blob/2bfa0905b30a10dafcfd8944dad3503b3b802d18/src/dispatchers/UniPoolerV2.sol#L386-L458) (`pool`) at `2bfa090`

**Description:** UniPoolerV2.pool/quotePool size the zap from getReserves() without sync(): an unsynced token donation to the pair is absorbed in swap(), stranding non-dust phUSD on the pooler (229 phUSD on a 100k zap after a 0.5% donation) or reverting pending pool() with InsufficientLP, with the donation recoverable via skim() for gas only

**Impact:** (a) Strand: 0.5% sUSDS donation -> 229.398 phUSD left on the pooler after a 100k zap (PoC). The phUSD is protocol-held, not lost; owner rescueERC20 recovers it. The attacker's donation (5,105.88 sUSDS, ~22x the stranded value) is absorbed into pair reserves owned ~100% by the pooler, so the protocol is net UP. (b) DoS: 2% donation -> pool() reverts UniPoolerV2__InsufficientLP(48746147894859096248178, 49179748976765704050059); attacker skim()s the donation back (gas-only, requires bundling or it is skimmed by any searcher). Dispatch/mint path unaffected (P9).

**Likelihood:** low - zero-profit griefing; requires bundling a public keeper tx; defeated by private submission or a keeper-side pair.sync()/skim() before pool()

**Assumptions:** Keeper submits publicly; pooler is ~100% LP post-cutover (strand case net-positive for protocol)

**External requirements:** Attacker willing to pay gas per griefed call with no return

**Path:**

1. Attacker sees keeper pool(a, quote*0.99, quoteLP*0.99) in the public mempool
2. Bundles: transfer x sUSDS to pair (no sync) -> keeper tx -> pair.skim(attacker)
3. Keeper tx reverts InsufficientLP; attacker recovers x; repeat per keeper attempt
4. Alt: smaller x lets pool() succeed but strands phUSD (attacker forfeits x to LPs)

**Severity justification:** No value leaves the protocol (strand is rescuable and paid for by the attacker at >= 22x; DoS is gas-only and permissionlessly neutralised by sync/skim). Availability impact is limited to delaying a keeper-only POL-compounding call; user mints are unaffected. C4 treats zero-profit, per-call griefing of a non-core keeper function with a trivial operational counter as Low, not Medium. The falsified spec claim is a real Law-2 defect, surfaced via faithfulness cross-reference.

**Faithfulness cross-reference (story-048):** Falsifies story-048 / NatSpec claims that a front-run 'never [changes] the leftover' and that quotePool's expectedLP 'remains a valid floor' (true only for swap-style front-runs). story-048 is auto-complete. Filed under its security label L-25 at honest Low; spec-conformance report must cross-reference it (no separate F label, to avoid double-filing).

**Proof of Concept (run 20):** `yield-claim-nft/work/test/run20/DonationStrand.t.sol` — tests `test_donationFrontRun_strandsPhusd`, `test_donationFrontRun_quoteNotAValidFloor_andFreeToRepeat`, `test_donationFrontRun_exactRevert`; status at run 20: passing. Strand: 1M sUSDS / 1.06M phUSD pool; 5,105.88 sUSDS (0.5%) transferred to pair; pool(100,000, quote*0.99) succeeds, leaves 229.398 phUSD on pooler (dust bound: tens of wei); phUSD only moves via owner rescueERC20 DoS: 2% donation -> pool(a, quoteOut*0.99, quoteLP*0.99) reverts UniPoolerV2__InsufficientLP(48746147894859096248178, 49179748976765704050059); attacker skim()s the donation back -> repeatable for gas

**Recommendation:** Call IUniswapV2Pair(pair).sync() (or skim to self) at the top of pool() before reading reserves; correct the NatSpec / story-048 claim.

**Fingerprint:** `8ec2be7d59270e73e7f7c2cf1759514ebc94d198324477c8f2a22f4b82c54ef7` (`UniPoolerV2.sol:pool:unsynced-reserve-sizing`)

> **Carryover status (run 21, `267660b`).** Ledger **L-25** · `8ec2be7d59…` · status **`fix-pending`** · last seen `yield-claim-nft-21`.
> **Fix verification: FIX-COMPLETE → proposed `fixed` (human applies: `/ledger yield-claim-nft fixed 8ec2be7d`).** `pool()` calls `IUniswapV2Pair(_pair).sync()` immediately before `_reserves()` (`:462-463`); `quotePool` sizes from `_balances()` (`:502`, `:531-533`). Evidence: INV1_L25_noStrand / INV1b / INV2_quoteExecuteConsistent PASS on both engines, falsified by mutants M1/M2; Halmos P4 PASS; 115/115 unit and 7/7 fork tests (real feeTo-on pair).
> ⚠ **Label hazard:** story-051, commit `267660b` and the tests call this fix **`ycn20l24`**. That ID is **L-24** `8511fd5206` (`wont-fix`, dust pre-seed), which this fix does not touch. Select by fingerprint `8ec2be7d` only.
> ⚠ **PoC bit-rot:** the run-20 PoC above no longer compiles at `267660b` (`DeadRouter` lacks `factory()`, required by the new canonical-pair constructor check). Replay is **INCONCLUSIVE** (MR21-06); the verdict does not rest on it. Refresh the PoC before any `/recheck 8ec2be7d`.

---

## QA Findings

### [Q-19] UniPoolerV2 constructor validates only the pair's token set, not pair_ == router.factory().getPair(sUSDS, phUSD); combined with a permissionless, possibly-empty factory pair, the cutover can be decoupled (non-canonical pair) or permanently griefed (dust pre-seed at an arbitrary ratio, MINIMUM_LIQUIDITY lock) <!-- id: ycn20q19 -->

**Severity:** QA

**Location:** [`src/dispatchers/UniPoolerV2.sol#L159-L179`](https://github.com/Behodler/yield-claim-nft/blob/2bfa0905b30a10dafcfd8944dad3503b3b802d18/src/dispatchers/UniPoolerV2.sol#L159-L179) (`constructor`) at `2bfa090`

**Description:** pool()/quotePool size s and read reserves from _pair while router executes on factory pair: mis-sized s, wrong quote, LP minted is a different token than pair() reports (rescuable). Floors bound loss.

**Impact:** If deployed with a token-matching pair from a different factory, pool()/quotePool size from _pair while the router executes on the factory pair: mis-sized zaps bounded by floors; LP lands as a different token (rescuable).

**Likelihood:** low

**Assumptions:** Deploy script passes a non-canonical pair

**External requirements:** Owner deploy error

**Path:**

1. Owner-supplied constructor argument only; no third-party path

**Severity justification:** Missing deploy-time validation (require(factory.getPair(sUSDS, phUSD) == pair_)). Supplying the wrong pair address is an obvious-consequence misconfiguration (story-faithfulness already suppressed it under Law 3), floors bound any loss, and LP is rescuable. QA hardening.

**Split from:** DEDUP-20-04 facet A; sibling L-24 8511fd5206fbe9a6 (L-24, `wont-fix` — dust pre-seed facet; **not** closed or reopened by this entry).

**Recommendation:** constructor require(factory.getPair(sUSDS, phUSD) == pair_) or cutover-script assertion

**Fingerprint:** `098396142dcb5a8179009d4a0d844130b32b814cc03fb982240a8aabd6d63953` (`UniPoolerV2.sol:constructor:pair-not-bound-to-router-factory`)

> **Carryover status (run 21, `267660b`).** Ledger **Q-19** · `098396142d…` · status **`fix-pending`** · last seen `yield-claim-nft-21`.
> **Fix verification: FIX-COMPLETE → proposed `fixed` (human applies: `/ledger yield-claim-nft fixed 09839614`).** The constructor now requires `IUniswapV2Factory(IUniswapV2Router02(router_).factory()).getPair(sUSDS_, phUSD_) == pair_` and reverts `UniPoolerV2__PairNotCanonical` otherwise (`:220-221`), after the token-set check. Evidence: Halmos P3a (IFF) and P3b PASS. Residual MR21-03: the trust root is the caller-supplied `router_` (trusted deploy input, Law 3). This closes Q-19 only; the shared title's dust pre-seed half is **L-24** (`wont-fix`) and is unchanged.

---

### [Q-21] Plan §5 sizes the zap against the full Balancer pool (~33.8k/34.8k) but the cutover seeds the V2 pair with only the protocol's 62.9% of BPT (~19.1k sUSDS / 21.9k phUSD per side, ~1.59x shallower): phUSD crosses $1 at a ~$636 zap, not ~$1k, so the intended no-ceiling arb skim on POL is larger than the plan states <!-- id: ycn20q21 -->

**Severity:** QA / Informational

**Location:** [`src/dispatchers/UniPoolerV2.sol#L386-L451`](https://github.com/Behodler/yield-claim-nft/blob/2bfa0905b30a10dafcfd8944dad3503b3b802d18/src/dispatchers/UniPoolerV2.sol#L386-L451) (`pool`) at `2bfa090`

**Description:** Not story-unsafe (deliberate design cost; arbitrageur posts $1 collateral per phUSD — per project memory this is closer to accepted design cost than loss). Surfaced because the depth premise is wrong. Depends on the open question whether EOA 0xc65f...e8db (37.1% BPT) migrates. Also corrects the depth premise used in DEDUP-20-03.

**Impact:** Plan §5 sizes zaps against full Balancer depth (~33.8k/34.8k) but the V2 seed is the protocol's 62.9% (~19.1k sUSDS / 21.9k phUSD): phUSD crosses $1 at a ~$636 zap, not ~$1k, so the intended POL arb skim per zap is larger than the plan states.

**Likelihood:** medium if plan numbers are used as-is

**Assumptions:** Keeper follows plan §5 sizing

**External requirements:** none

**Path:**

1. Keeper sizes zaps per plan -> overshoots $1 -> arbitrageurs skim the excess from POL (intended mechanism, mis-sized)

**Plan premise:** BalancerWinddownPlan §5 worked example (X ≈ 33,804, Y ≈ 34,817) vs 62.9% protocol BPT seed (~19.1k sUSDS / 21.9k phUSD)

**Open question:** Whether EOA 0xc65f…e8db (37.1% BPT) migrates into the V2 pair before Stage 2

**Severity justification:** Planning-document premise error affecting operator sizing of an intended (by-design) arb skim on POL; not a code defect and the skim itself is designed behaviour. Informational, carried in the QA bundle with sizing guidance (chunk pool() so post-zap spot <= $1).

**Recommendation:** Redo plan §5 at 62.9% depth or resolve the EOA question before Stage 2; keeper chunks pool() so post-zap spot <= $1.

**Fingerprint:** `4c2f9c705c39776aba9242b9c1871f1e165a8f55faeeaefb93abe594e58b41e6` (`UniPoolerV2.sol:pool:plan-zap-sizing-overstates-seeded-depth`)

> **Carryover status (run 21, `267660b`).** Ledger **Q-21** · `4c2f9c705c…` · status **`fix-pending`** · last seen `yield-claim-nft-21`.
> **Fix verification: NOT-ADDRESSED — stays `fix-pending`, still live.** The fix owed is a correction to BalancerWinddownPlan §5 (deferred to phStaging2:108, not landed at pin `a309040`). The run-21 edit to `pool()` was the L-25 sync fix, not an attempt at Q-21, so this is **not** an incomplete fix. Run-21 econ re-quantification: phUSD still crosses $1 at a ~$636 zap; the sync fix leaves that threshold unchanged but makes it computable from `quotePool` (donation sensitivity $423–$855).
