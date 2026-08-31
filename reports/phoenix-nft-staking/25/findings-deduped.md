# Consolidated (Deduplicated) Findings — phoenix-nft-staking run-25

> ## ⚠ SUPERSEDED IN PART — M-01 AND M-02 WITHDRAWN (2026-07-26)
>
> **Run-25 `M-01` (`pns25m1` / `DEDUP-25-01` / ledger `96823199d298…`) and `M-02` (`pns25m2` /
> `DEDUP-25-02` / ledger `c7a410602b29…`) were WITHDRAWN by owner correction on 2026-07-26 and are
> now ledger status `false-positive`.** Every reference below that treats M-01 or M-02 as a live
> Medium — including cross-references, re-weigh recommendations, KI-scope determinations and
> "value is priced in M-01" pointers — is **superseded**. See `submissions/M-01.md` for the full
> reasoning.
>
> **In one line:** the nudge pot is funded by *externally-derived yield on protocol-owned capital*,
> never principal and never user deposits, so a pot exceeding one qualifying batch's cost is an
> accepted **subsidy rate / marketing spend** (opportunity cost), not a value leak. `NudgeStreamer`
> meters release so the market finds a clearing price; empirically the pot has never once reached
> 50 % of the qualifying cost before someone minted. Recorded as `registered-projects.json` **KI #16**.
>
> **Still reportable (Law 1 — narrow suppression):** (a) the pot leaving without `nudgeSize` real
> mints paid; (b) `refund > paymentAmount`; (c) a non-qualifying batch extracting pot-sized value;
> (d) **a claimant taking other users' money** — which is why **M-03 survives** (forfeited sub-dust
> residue is other callers' money), re-weigh to **Low** *proposed*, not applied.
>
> **Run-25's reading of KI #15 carve-out (d) was too broad** — (d) covers *accidental* over-funding,
> not a deliberately-set subsidy rate. Every MR-05 / "re-weigh" / "acceptance-scope drift"
> recommendation below that rests on that reading is **withdrawn**.
>
> **Ledger entries `43e8c48626ee…` and `858e9e807abe…` are untouched** — run-25's re-weigh of them
> is **withdrawn**; their `wont-fix` rationale stands unchallenged. The **surviving accurate residue**
> of M-01 is the documentation mismatch already filed as **L-02** (`75305ec0…` / `a7dffb34…`), whose
> correct fix is to **restate the sentence as a subsidy policy, not to add a code bound** — and no
> value claim attaches to it.

---

- **Project**: `phoenix-nft-staking` @ `5015f1b` (regression of **story-029**, baseline `d75229d`)
- **Delta**: `git diff --stat d75229d..5015f1b` changes exactly **one** `src/` file — `src/BatchNFTMinterMultiToken.sol`
- **Inputs consolidated**: `scan-code.md` (CODE-001…006), `scan-econ.md` (ECON-001…006), `scan-faithfulness.md` (F-25-01…04), `pattern-matches.md` (P-01…05, NM-01…08), `invariants.md` (INV-25-01, INV-25-02), `static-analysis.md` (SA-*), `profiles/BatchNFTMinterMultiToken.md`
- **Parked, not dropped**: `manual-review.json` MR-01…MR-05 (Law-1 visible channel)
- **Consolidated findings**: **11**

> **RECONSTRUCTION NOTE.** The deduplicator's own write of this file was blocked by the harness. Reconstructed at the next pipeline step from the deduplicator's consolidation map plus the underlying scan artefacts listed above, so the artefact is not lost (Law 1: no silent drops). Content is sourced verbatim-in-substance from those scans; no new analysis was introduced at reconstruction time.

---

## Consolidation map

| id | label | title | contract:line | severity proposed | merged from |
|---|---|---|---|---|---|
| DEDUP-25-01 | ~~M-01~~ **WITHDRAWN 2026-07-26 (false-positive)** | Payment-token nudge pot payable on value-blind count-only gate; Σ(pots) 4× one qualifying batch cost; atomic profit invariant-proven | `BatchNFTMinterMultiToken.sol` `_snapshotRewards`/`batchMint` :749-765, gate :507-511, payout :790 | Medium (ceiling High) | P-01, ECON-001, F-25-01, INV-25-01 |
| DEDUP-25-02 | ~~M-02~~ **WITHDRAWN 2026-07-26 (false-positive, with parent M-01)** | NudgeRatchet `_dispatch` sweeps FULL balance, recycling 100% of the qualifying cost back into the pot; pot self-re-arms at exactly C | `batchMint` :621-627 ↔ yield-claim-nft `NudgeRatchet.sol:156-161` @ `d4cc563` (was mis-cited as `:100`, deleted code) | Medium | ECON-002 |
| DEDUP-25-03 | M-03 | Self-feeding pot ⇒ both wont-fix closures are TIME-BOUNDED (expiring closure, NOT a regression) | `batchMint` :659-668, const :146 | Low → flagged for Medium re-weigh | ECON-003, INV-25-02 |
| DEDUP-25-04 | ~~L-01~~ **MERGED INTO M-03** | Decimals-blind `DUST_THRESHOLD = 1e6`; sub-dust forfeiture now permanent + pot-directed; `totalPaid` misreports it | `batchMint` :659-668, :146, :666 | Low (Medium argument recorded) | CODE-001, P-02, ECON-005, F-25-04 |
| DEDUP-25-05 | L-02 | Docs assert a "by construction" cost bound the code never expresses (`qualifies` compares count to count, pays a value) | :507-511 ↔ `docs/multi-token-nudge.md:56-60` | Low/QA | ECON-006, F-25-02 |
| DEDUP-25-06 | L-03 | Cross-repo budget/charge lockstep watch-note; live `price` allowance across two callbacks | `batchMint` :621-627 | Low (watch-note) | CODE-004, NM-01, NM-02 |
| DEDUP-25-07 | L-04 | Fork drift: V1 `BatchNFTMinter.sol` never received story-029, still carries BOTH closed root causes | `BatchNFTMinter.sol` :280, :284, :305 | Low (watch-note) | CODE-006 |
| DEDUP-25-08 | Q-01 | `available` cap cannot do what its comment claims; non-binding on every constructible path | `batchMint` :647-661 | QA | CODE-002, P-03 (part 2) |
| DEDUP-25-09 | Q-02 | FoT + transfer-hook payment token restores `budget` mid-pull; fee charged to `P` | `batchMint` :576-581 | QA/Low | CODE-005, P-03 (part 1), P-04 |
| DEDUP-25-10 | Q-03 | The `:580` `min` is a single point of failure for TWO properties, only one documented | `batchMint` :562-581 → :664 | QA | CODE-003, NM-06 |
| DEDUP-25-11 | Q-04 | docs §4.1 "SAFE BY CONSTRUCTION" heading exceeds the construction actually built | `docs/multi-token-nudge.md:200, :213` | QA | F-25-03 |

---

## ⛔ DEDUP-25-01 (M-01) — **WITHDRAWN 2026-07-26** — Payment-token pot is payable on a value-blind count-only gate

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `_snapshotRewards` / `batchMint`
- **Lines**: gate `:507-511`; skip-deletion site `:749-765`; payout `:790`
- **Severity proposed**: **Medium**, ceiling **High** (High on deployment behind a value-forwarding dispatcher)
- **Confidence**: high — asserted by the project's own passing test and by a failing Tier-3 invariant
- **Delta**: yes

```solidity
qualifies = _nudgeSize != 0 && count >= _nudgeSize;                                 // :510 — count vs count, pays a VALUE
uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;   // :758
```

Story-029 **deleted** the runtime `if (rewardToken == paymentToken) continue;` from `_snapshotRewards`. Every whitelisted token — now **including the derived `primeToken()`** — is snapshotted pre-pull, floor-checked, and paid in full at `:790` to a caller-chosen `recipient` on the unchanged count-only gate. The gate itself was not touched; story-029 **widened what the gate can release**.

**Numbers, from the project's own fixture** (`test/PoC_PaymentTokenCollision.t.sol`, USDC 6dp, `price = 10.000000`, `nudgeSize = 5`, `growthBasisPoints = 0`):

| Term | Pre-029 (triage baseline) | Post-029 (`5015f1b`) |
|---|---|---|
| pot set entering Σ | whitelist **minus** the payment token | whitelist, **no exclusion** |
| Σ(pots) at fixture config | `0` USDC | **200.000000 USDC** |
| cost of one qualifying batch `C = nudgeSize × price` | `50.000000 USDC` | `50.000000 USDC` (unchanged) |
| Σ / C | `0` — premise **held** | **4.00× — premise INVERTED** |

Searcher ledger: `+200.000000` pot, `−50.000000` mints, `−~21.60` gas ⇒ **+~128.40 USDC net and 5 free NFTs**, atomic, 2.56× on capital deployed. Break-even pot `P > C + gas ≈ 71.60`, i.e. **8 ratchet mints** at fixture price, **6** at the mainnet-observed `price = 70.000000`.

**Witnesses (no new PoC needed — the repo ships one):**
- `test_PaymentTokenAsNudge_qualifyingBatchStillEarnsThePot` (`:354-368`), **passing**, asserts `assertEq(usdc.balanceOf(nftRecipient), pot)` with `pot == 200_000000`.
- **INV-25-01 `invariant_NoAtomicProfitFromQualifyingBatch` — FAILED on the first run** (256×500 = 128,000-call budget, zero handler reverts). Two self-contained replaying witnesses: `+160.000000 USDC` on a `50.000000 USDC` batch, and a fuzzer-found 3-call sequence at `+9.995264 USDC`. Mutation-controlled and non-vacuous (`invariants.md` §4b).

**Story-faithfulness (F-25-01, Law 1 over Law 2)**: the implementation is **faithful** — commit `0318089` §3.2 asks for exactly this ("paid out like every other whitelisted token"), and the falsified-test rename `…CollisionIsSkippedNotReverted` → `…IsPaidNotSkipped` confirms intent. The defect is in the **story's own justification**: it is safe only under the inherited premise "the pot is by construction a fraction of the cost", which no code establishes (DEDUP-25-05). An unsafe *intent* is escalated, not blessed.

**Re-file disclosure** (`disclose-when-refiling-owner-wontfix`), carried into the writeup:
- **Prior entries named**: ledger `43e8c48626ee74b51d538bd9ed12bf4898b976818f6fb44fea844ff3757daefe` (M-01, **wont-fix**) and `858e9e807abee888b378db210bae982f23fe7b5d91052321e204d7ba568579b7` (H-01, **wont-fix**).
- **Quoted rationales**: `43e8c486` — *"Safe config remains: keep Σ(pot_i) < nudgeSize*mintPrice … RE-ARM trigger unchanged: re-rate the moment a live/pending deployment funds the whitelist so Σ(pot_i) approaches/exceeds one qualifying cost."* `858e9e80` — *"THE 6.7x MARGIN IS REAL"*, with RE-RATE triggers (b) *"nudge pot … exceeding nudgeSize x 70.000000 USDC"* and (e) *"deployment of src/BatchNFTMinterMultiToken.sol behind any value-forwarding dispatcher."*
- **Re-file basis**: both Σ figures were computed over a pot set that **structurally excluded the payment token**, because at triage time `_snapshotRewards` skipped it at runtime. Story-029 deleted that skip and added a pool to Σ. The prior arithmetic is therefore not a statement about `5015f1b`. Root-cause class changed (`_snapshotRewards` scope, not the gate) ⇒ new fingerprint.
- **NOT an override**: both wont-fixes stand untouched; this supplies only the delta. Their own re-arm triggers (b) and (e) are **met**, not bypassed — `NudgeRatchet` *is* a value-forwarding dispatcher.

**Assumptions stated**: requires deployment with (i) the payment token whitelisted as a nudge token and (ii) `dispatcherIndex` resolving to that prime token. `docs/multi-token-nudge.md` §4.1 **affirmatively blesses** configuration (ii) as *"permitted and safe, not forbidden"*, so this is not an owner error and Law 3 does not suppress it. The ledger records **zero present on-chain exposure** (run-20: pot 0 USDC, `NudgeRatchet.batchMinter()` repointed) — which is why this is Medium today rather than High.

**Remediation** — ⛔ **WITHDRAWN 2026-07-26. DO NOT IMPLEMENT.** A value-aware payout cap would break the intended subsidy mechanism. ~~(single shared fix with DEDUP-25-02/-25-05 and both ledger entries): make the payout value-aware — cap the total nudge payout against the payment actually charged this batch (`paymentAmount - refund`, already computed at `:664`) — or make the gate a value gate.

---

## ⛔ DEDUP-25-02 (M-02) — **WITHDRAWN 2026-07-26** — The qualifying cost is not a cost: the dispatcher recycles 100 % of it

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint` ↔ `lib/yield-claim-nft/src/dispatchers/NudgeRatchet.sol:156-161` @ `d4cc563` `NudgeRatchet.sol:156-161` @ yield-claim-nft `d4cc563` (**CORRECTED**: the former `:100` leaf `safeTransfer(batchMinter, bal)` is DELETED at `d4cc563` with no fallback; the forward is now `forceApprove(streamer, bal)` + `collectNudge(batchMinter, _token, bal)`, metered by `NudgeStreamer` over `duration`. The nested gitlink `lib/mutable/yield-claim-nft` is pinned at the STALE `aa86be6`.)
- **Lines**: `:621-627` (`nftMinter.mint` at `:626`)
- **Severity proposed**: **Medium** — this is what makes DEDUP-25-01 repeatable rather than one-shot
- **Confidence**: high (mechanism), medium (that production wires both legs simultaneously)
- **Delta**: the loop's *cash* leg is new — pre-029 the payment token was excluded from payout, so the returning value could not be claimed back out

```
batchMint step 6+7 ──price──► NFTMinterV2._executeMint
                               safeTransferFrom(msg.sender, config.dispatcher, price)
                                        ▼
                              NudgeRatchet._dispatch  (:130-162 @ d4cc563)
                               forceApprove(streamer, bal)
                               INudgeStreamer(streamer).collectNudge(batchMinter, _token, bal)
                                        ▼
                              NudgeStreamer (:137-156) settle @ OLD rate, buffer += bal,
                               rewardPerSecond = buffer*1e18/duration   ← WINDOW RESET
                                        ▼
                     delivered LINEARLY over `duration` to the batch minter
                                        ▼
                     harvested by the NEXT batch's :530 pullPendingStream, counted at :535
```

`_dispatch`'s own NatSpec: *"DESIGN: this sweeps the FULL token balance, not the `amount` argument."* The sweep is **metered, not instant**: `NudgeStreamer` is value-conserving (`_settle` :182-190 has no fee/burn/skim/retention branch; `_accrued` :195-200 caps at `buffer`, preventing over-transfer but never withholding; floor dust stays in the buffer and streams later), so **total delivered = total deposited**.

Steady-state per claim cycle (numerically UNCHANGED — conservation gives a lossless loop the same fixed point): equilibrium buffer `B* = C·D/T`, per-cycle recovery `A = C`, net cash `A − C = 0`, plus `nudgeSize` NFTs, minus gas. **The "second claim is a pure `C → C` round-trip" and every "next block" claim are WITHDRAWN.** Metering charges the attacker three costs the instantaneous model missed: recovery is linear over `D`; one full `C` (350 USDC at mainnet config) is permanently escrowed in flight and **never recovered by the searcher** (on exit it is donated to whoever harvests next); and the exploit becomes an **interruptible multi-day race** any competing qualifying batch can win. Amortised NFT cost at mainnet config (`price=70`, `nudgeSize=5`, `C=350`, gas≈21.60): n=1 → 74.32 (a LOSS); n=10 → 11.32 (84% discount); n=50 → 5.72 (92%); n→∞ → 4.32 (94%).

This directly falsifies the load-bearing economic claim in `docs/multi-token-nudge.md` §1 and in KI #15 — *"a bot that claims it must first pay more payment-token into the protocol than it extracts in reward; every claim is net-positive for the protocol"*. In the collision configuration the bot's payment **does not stay with the protocol**.

`NudgeStreamer` does **not** close this: it is a **timing throttle, not a value cap** (`_accrued = min(rewardPerSecond * elapsed / PRECISION, buffer)`, `NudgeStreamer.sol:195-200`; concurs with this project's own run-24 note). A patient searcher recovers 100 % of `C` after `duration`. `batchMint` pulls `pullPendingStream` over the whole whitelist at `:530`, immediately **before** `_snapshotRewards` at `:535`, so streamed value lands in the pot and is counted in the same call that pays it out. **`duration` (D) is an explicit severity parameter and this run did NOT pin the deployed value** — it should be stated on the ledger entry.

**FOURTH arming condition**: the full ops ordering (whitelist → `registerStream` → `setNudgeStreamer`) must be complete. `nudgeStreamer == address(0)`, `NudgeStreamer__NotRegistered` and `NudgeStreamer__NotWhitelisted` each hard-revert the **entire `batchMint`**, because the dispatch happens inside the mint loop. An incompletely-wired deployment is bricked, not exploitable.

**MERGE**: DEDUP-25-02 is MERGED INTO DEDUP-25-01 / M-01 as Leg 2 — zero standalone impact, pure amplifier, fully closed by M-01's fix. Its `setDispatcherIndex` payment-loop assert is PRESERVED as a distinct deploy-time control (M-01 Mitigation 2). Its KI #15 falsification is carried VERBATIM and is timing-independent.

**Law-3 framing**: two *ordinary* owner settings compose — `NudgeRatchet.batchMinter = <this contract>` (its designed purpose) and `BatchNFTMinterMultiToken.dispatcherIndex = <the ratchet index>` (blessed by docs §4.1). A competent, non-malicious owner would be **surprised** that the batch minter paying its mints through the dispatcher that funds its own pot creates a closed loop. Surprise ⇒ footgun ⇒ in scope.

**Cross-repo assumption, stated**: both legs were read at source; **neither was verified against a live deployment** — the ledger records the current mainnet wiring as repointed and the pot as empty. This is the arming condition, stated honestly, not assumed.

**Safe config**: never set `dispatcherIndex` to an index whose dispatcher forwards to this contract; or make the payout value-aware; or take a haircut.

---

## DEDUP-25-03 (M-03) — Self-feeding pot converts both wont-fix closures into EXPIRING closures

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Lines**: `:659-668`, constant `:146`
- **Severity proposed**: **Low** as a standalone leak — **flagged for Medium re-weigh**, because the finding *is the expiry* of two ledger closures
- **Confidence**: high (mechanism), medium (rate — depends on frontend quoting slack)
- **Delta**: yes — pre-029 the residue was **recoverable** by a later sweep; post-029 it is not

Post-029 the refund's source is the tracked `budget` (this call's credit only), so residue from a prior call is **permanently unreachable by any refund** and can leave only via `_payRewards` (the pot) or `rescueERC20`. Per batch the forfeiture is `0 … 999,999` raw units = **0 … 0.999999 USDC**, accreting into `P` monotonically with **no cap and no owner action**.

| config | `C` | target `P` | @ max 0.999999/batch | @ realistic 0.5 USDC frontend slack |
|---|---|---|---|---|
| fixture: `price = 10`, `nudgeSize = 5` | 50.00 | 71.60 | **72 batches** | **144 batches** |
| mainnet: `price = 70`, `nudgeSize = 5` | 350.00 | 371.60 | **372 batches** | **744 batches** |

**INV-25-02 `invariant_PotDoesNotGrowWithoutExplicitFunding` — FAILED.** One call to `nonQualifyingSubDustBatch` grew the pot by `0.882091 USDC`, permanently. Monotonicity witness `test_witness_INV2502_potGrowsMonotonicallyFromForfeitedDust` (PASS): **72 ordinary non-qualifying batches, no owner funding action whatsoever, grew the pot 71.999928 USDC — past the 71.60 break-even** and armed a profitable DEDUP-25-01 snipe. Growth is accumulated as a sum of positive deltas, so a qualifying drain cannot mask accretion between drains. 72/72 growth events.

**Classification (per `expired-closure-vs-regression`)**: this is **NOT a code regression** — no prior fix was reverted. It is an **expiring closure**: the rationale behind `43e8c486` / `858e9e80` has a finite shelf life measured in batch count. It belongs in its own bucket and must **not** be written up as "restore the patch" — there is no patch to restore. The `43e8c486` safe-config *"keep Σ(pot_i) < nudgeSize × mintPrice"* is **not a configuration a non-malicious owner can hold**; it decays on its own at a rate set by third-party frontend quoting behaviour.

**Correct disposition**: a **standing monitor** on `P` versus `nudgeSize × price`, not a one-time re-check. (Note the dust channel is the *slow* one — DEDUP-25-02's ratchet channel arms the same condition in 6-8 mints. The dust channel matters because it survives even if the ratchet wiring is removed.)

---

## DEDUP-25-04 (~~L-01~~ — **MERGED INTO M-03**, see M-03.md; removed from qa-report.md) — Decimals-blind `DUST_THRESHOLD`; forfeiture is permanent, pot-directed, and misreported

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Lines**: `:659-668`, constant `:146`, misreport at `:666`
- **Severity proposed**: **Low** (Medium argument recorded)
- **Confidence**: high (mechanism), medium (impact sizing) · **Delta**: yes

```solidity
uint256 internal constant DUST_THRESHOLD = 1e6;                     // :146 — raw wei, no decimals normalisation
uint256 available = paymentToken.balanceOf(address(this));          // :660
uint256 refund = budget > available ? available : budget;           // :661
if (refund / DUST_THRESHOLD != 0) {                                 // :662  == refund >= 1e6
    paymentToken.safeTransfer(msg.sender, refund);
    totalPaid = paymentAmount - refund;
} else {
    totalPaid = paymentAmount;                                      // :666  surplus kept, silently
}
```

Two independent facts compose into a defect neither has alone:

1. `DUST_THRESHOLD` is a raw-wei constant with **no decimals normalisation**, while the payment token is not fixed — it is `ITokenDispatcherV2(dispatcher).primeToken()` (`_resolvePaymentPath`, `:705`), owner-repointable.

   | `primeToken` decimals | `1e6` raw units equals | max forfeited per batch | at $1/token |
   |---|---|---|---|
   | **18** (phUSD) | `1e-12` token | `0.000000000000999999` | **$1.0 × 10⁻¹²** |
   | **6** (USDC) | `1.000000` token | **`0.999999` token** | **$1.00** |

   **10¹² more value forfeited per batch at 6 decimals.** The NatSpec at `:142-145` documents only the benign 18-decimal arm.
2. The gate is **all-or-nothing**: a refund of 999,999 units is dropped *in its entirety*.

**The escalating fact**: the 6-decimal arm is **not a hypothetical repoint**. `NudgeRatchet`'s constructor *mandates* it — `require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC")` (`NudgeRatchet.sol:84` @ yield-claim-nft `d4cc563`; was mis-cited as `:44` against the stale nested gitlink `aa86be6`). On the dispatcher family this contract exists to serve, `DUST_THRESHOLD` is **structurally 1.000000 whole payment tokens, by deploy-time enforcement upstream**. This is the default on the intended path, not a misconfiguration.

**Concrete failure path**: prime token USDC, `price = 25.000000`, `nudgeSize = 10`. Caller batches `count = 4` with `paymentAmount = 100.500000` (a 0.5 USDC frontend margin). `budget = 500000` at `:661`; `500000 / 1e6 == 0` ⇒ else-branch; no transfer; `totalPaid = 100_500000`. The caller is reported as having spent their full quote, 0.5 USDC stays behind, and it is now part of `P`.

**Disclosure gap (F-25-04)**: `docs/multi-token-nudge.md:305-310` describes the *destination* of the residue (*"they stay behind as pot — which is the correct owner for them"*) but not the **accounting misreport** at `:666`, so an integrator has no reason to reconcile `totalPaid` against an observed balance delta.

**Medium argument recorded for severity-classifier**: it is (i) systematic rather than edge-case on a 6-decimal prime token — mandated, in fact; (ii) invisible in the return value, so no off-chain consumer can detect it; and (iii) self-feeding into the pot that DEDUP-25-01 draws on (this is the mechanism behind DEDUP-25-03's expiry). Filed Low because it is bounded per call and small relative to a batch's mint cost.

**Law-3 test**: would a competent, non-malicious owner wiring the batch minter behind `NudgeRatchet` be surprised that per-batch refunds under one whole USDC vanish, permanently, into the nudge pot, while `totalPaid` reports the caller spent their full `paymentAmount`? **Yes. Surprise ⇒ footgun ⇒ report.**

**Safe config**: scale the threshold off `IERC20Metadata(paymentToken).decimals()`; or lower the constant to `1e2` (dust at 6dp, still absorbs JS slack); or make the branch partial rather than all-or-nothing.

---

## DEDUP-25-05 (L-02) — Docs assert a "by construction" cost bound the code never expresses

- **Contract / function**: `docs/multi-token-nudge.md` §1 / §4.1 ↔ `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Lines**: `:507-511` (code) ↔ `docs/multi-token-nudge.md:56-60` and `:299-302`
- **Severity proposed**: **Low / QA** (the *value* consequence is priced in DEDUP-25-01, not here)
- **Confidence**: high · **Delta**: the docs were rewritten in this range

**specText** (`docs/multi-token-nudge.md:56-60`, verbatim):

> "The pot is a *nudge*: **by construction** it is a fraction of the cost of the `nudgeSize` mints required to qualify. A bot that claims it must first pay more payment-token into the protocol than it extracts in reward. **Every claim is net-positive for the protocol; there is no configuration of this mechanism under which claiming is profitable-in-isolation.**"

and `:299-302` — the ground offered for the 2026-07-25 owner acceptance:

> "That is intended: the pot is by construction a fraction of the cost of the qualifying mints, so every claim is net-positive for the protocol. Making the comparison legible does not change the economics."

**actualBehavior**:

```solidity
qualifies = _nudgeSize != 0 && count >= _nudgeSize;   // :510
```

`qualifies` reads `count` and `nudgeSize` and **nothing else**. It never reads `paymentAmount`, `price`, `budget`, or `snapshot[i]`. **No expression anywhere in the file relates the pot to the cost.** The phrase "by construction" names a construction that does not exist; the universally-quantified clause is refuted by the project's own fixture (pot 200.000000 USDC vs qualifying cost 50.000000 USDC) and its own passing assertion at `:354-368`.

Two aggravating specifics:

1. The fallback backstop at docs §4.6 — *"qualifying still costs `nudgeSize` real mints at the ramping price"* — is **void at `growthBasisPoints == 0`**, which is how the project's own ratchet index is configured (`setConfig(RATCHET_INDEX, RATCHET_PRICE, 0)`, `PoC_PaymentTokenCollision.t.sol:112`; test comments confirm *"growth is 0 on this index"*).
2. The claim is not decorative prose: it is the **stated basis of an owner acceptance** and of KI #15's suppression. A false premise propagated into a suppression rule is a Law-1 concern about future recall.

The gate's asymmetry stated plainly: **a count is compared to a count, and a value is paid out.** The two quantities are never in the same expression.

**Remediation** — ⛔ **CORRECTED 2026-07-26: take the SECOND option only.** The cap option is withdrawn (M-01 is a false-positive; a code bound would break the subsidy mechanism). ~~(single shared fix with DEDUP-25-01): cap the total nudge payout against the payment actually charged this batch (`paymentAmount - refund`, already computed at `:664`) — which turns the sentence into a construction; **or** rewrite the sentence to say what is true: *the relation is an operational funding discipline, unenforced by the contract, and must be monitored.*

---

## DEDUP-25-06 (L-03) — Budget/charge lockstep is a silent cross-repo invariant; live `price` allowance across two callbacks

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Lines**: `:621-627` (`:625`)
- **Severity proposed**: **Low (watch-note)** — not a bug today
- **Confidence**: medium as a hazard; the escape is verified sound **today**
- **Delta**: yes — the invariant is newly load-bearing; pre-029 nothing depended on it

```solidity
paymentToken.forceApprove(address(nftMinter), price);   // :624
budget -= price;                                        // :625  (quoted, never measured)
nftMinter.mint(_dispatcherIndex, recipient);            // :626
```

The outflow leg is **quoted, not measured** — the deliberate inverse of the inbound bracket at `:577-579`. Correctness therefore rests on a property of a **different repository**: `NFTMinterV2._executeMint` debiting this contract exactly `config.price`, exactly once, per `mint`. Verified at source (`yield-claim-nft/src/NFTMinterV2.sol:183`, the **sole** `transferFrom` in the file) — it holds today, including under the standard fee-on-transfer model, because the fee is skimmed from what the *dispatcher receives* and the batcher is still debited the full `price` (NM-01, margin comfortable).

The hazard is what happens if it stops holding, and how invisible that would be:

1. `_executeMint` makes **two** external calls after the debit and before returning — `ATokenDispatcherV2(config.dispatcher).dispatch(...)` (`:191`) and `_mint(recipient, …)` (`:196`), the latter firing `onERC1155Received` on a **caller-chosen `recipient`**.
2. With a payment token that does **not** decrement allowance on `transferFrom`, the `forceApprove(minter, price)` written at `:624` is **still standing** during both callbacks.
3. It is unexploitable today for one reason only: the minter's single `transferFrom` sources `msg.sender`, so a callback cannot make it spend *this contract's* allowance. Any future `mintOnBehalf(address from, …)`, batching inside `_executeMint`, or a second charge would immediately re-open `ad36260f` against `P` — with **no local signal** in phoenix-nft-staking, because `budget` would simply be wrong rather than reverting.

**NM-02 escape confirmed at source — THIN MARGIN.** The `onERC1155Received` hook fires on a caller-chosen contract **inside** the mint loop. It escapes for three independent reasons, all of which must continue to hold: (1) `nonReentrant` at `:464` blocks re-entering `batchMint`; (2) `budget -= price` at `:625` executes *before* the mint at `:626`, so the hook cannot observe an un-decremented budget — CEI holds *within* the iteration; (3) the standing allowance is exactly one mint's price and is spender-locked as above. **The margin on (2) and (3) is thin**: moving the decrement after the mint, or widening the approval, makes this live. **The per-iteration absolute approval is load-bearing, not a cosmetic tidy-up** — record it as an invariant to protect.

**Recommendation**: measure the outflow leg (a `balanceOf` bracket around the single `mint`, a legitimate narrow bracket by the file's own `:597-599` rule — *provided* the payment token is not itself donated back as `D` inside the same call, which it may be, so this is not free), or add an explicit post-loop assertion that the aggregate debit equals `Σ price`.

Filed as a watch-note **so the `ad36260f` `fixed` proposal is not read as unconditional.**

---

## DEDUP-25-07 (L-04) — Fork drift: V1 `BatchNFTMinter.sol` never received story-029

- **Contract / function**: `src/BatchNFTMinter.sol` :: `batchMint`
- **Lines**: `:280`, `:284`, `:305` (block `:284-308`)
- **Severity proposed**: **Low (fork-drift watch-note)**
- **Confidence**: high · **Delta**: no (pre-existing shape, newly divergent)

Grep-confirmed at `5015f1b`:

```
src/BatchNFTMinter.sol:284:  paymentToken.forceApprove(address(nftMinter), type(uint256).max);
src/BatchNFTMinter.sol:290:  paymentToken.forceApprove(address(nftMinter), 0);
src/BatchNFTMinter.sol:305:  uint256 remaining = paymentToken.balanceOf(address(this));
src/BatchNFTMinter.sol:306:  if (remaining / DUST_THRESHOLD != 0) {
src/BatchNFTMinter.sol:307:      paymentToken.safeTransfer(msg.sender, remaining);
```

This is the **exact pre-029 shape**: unbounded approval (the `ad36260f` root cause) plus a `balanceOf`-sourced sweep (the `ycn19h1` root cause), with `nudgeAmount` likewise taken from `balanceOf(address(this))` at `:280`. If this contract is deployed and holds a nudge pot, **both closed issues are live on it.**

Story-faithfulness confirms the file is **blob-identical** to `d75229d` (`eb8cf65f`), so this is divergence by omission, not a change.

Consistent with this project's existing fork-drift tracking (`NFTStakerPriceScaled` / `DepletionV2` / `NFTStakerPriceScaledMigrateReady` clones), this is the **fourth clone under drift watch**. It is flagged rather than filed as a new Medium because it is presumed covered by the existing `ad36260f` / `858e9e80` entries against the pre-029 design — **but only if V1 is not separately deployed with a pot.** That is a question for the human triager, not something this scan can resolve.

---

## DEDUP-25-08 (Q-01) — The `available` cap cannot do what its comment says it does

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Lines**: `:647-661` (`:660`)
- **Severity proposed**: **QA** · **Impact today: none** · **Delta**: yes (the comment block is new)
- **Confidence**: high (the claim is demonstrably false); **not currently exploitable**

The comment at `:647-655` retains the cap *"only so an unforeseen shortfall degrades into a smaller refund rather than a revert."* It cannot serve that purpose. `available` is an **absolute** `balanceOf` and therefore equals `P + (credited − C) + D`. A shortfall in the caller's own credit does not make `available` bind until `P` **and** this batch's donations `D` have *already* been consumed in full. **In exactly the scenario the comment names, the shortfall is silently absorbed by the pot instead of degrading the refund.** A cap that did what the prose claims would have to be caller-scoped, and no such quantity is tracked after `:581`.

Separately, the cap is **provably non-binding today**: `budget ≤ credited` (`:580` `min`) and `available = P + (credited − C) + D ≥ credited − C ≥ budget`, so `refund == budget` on every constructible path. It is dead code that reads as a safety net.

**Merged residual from the suppressed DEDUP-25-09** (sanitizer §2, preserved rather than dropped): `budget` is a **one-shot measurement pinned once at `:581` and never re-validated**, so **any** post-`:581` erosion of this contract's payment-token holdings is charged to `P`, silently. This needs **no** weird token — P-03 ranks a negative-rebase prime token as an independent mechanism. **P-04's DoS tail rides here too**: once such erosion exceeds `P + D`, the step-9/10 swap turns a silent pot shrink into a `batchMint` **revert on the payout leg**.

Filed because the residual is the same `balanceOf` conflation story-029 was written to eliminate, sitting at the one site the file elsewhere explicitly forbids absolute reads (`:585-605`), with a comment that would mislead the next author into believing a protection exists — exactly the shape that lets a future erosion mechanism pass review.

**Recommendation**: either delete the cap and let an impossible shortfall revert honestly, or track a caller-scoped quantity and cap on that.

---

## DEDUP-25-09 (Q-02) — FoT + transfer-hook payment token restores `budget` mid-pull; the fee is charged to `P`

> **STATUS: SUPPRESSED by the sanitizer** as C4 known-invalid (requires two simultaneous weird-ERC20 properties). Retained here for the audit trail; its token-agnostic residual and P-04's DoS tail were **merged forward into DEDUP-25-08**. See `findings-sanitized.md` §2 and FLAG-02.

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Lines**: `:576-581` (`:579`)
- **Severity proposed**: **QA / Low** · **Confidence**: medium (mechanism sound), low (reachability) · **Delta**: yes

The `min` at `:580` blocks a mid-pull donation from *raising* `budget` above `paymentAmount` — but it does **not** stop a mid-pull donation from *restoring* `budget` to `paymentAmount` when the caller's real credit was lower.

Requires the payment token to be **both** fee-on-transfer **and** to expose a transfer hook (ERC777 `tokensToSend`, or an ERC1363-style callback):

1. Attacker calls `batchMint(count=1, recipient=attacker, paymentAmount=100e6, …)`; token fee 10 %.
2. Inside `safeTransferFrom` (`:578`) the sender-side hook fires with the attacker in control. `nonReentrant` blocks re-entering `batchMint` — but **not an inbound transfer landing inside the window**, as the file's own comment at `:563-565` acknowledges.
3. The attacker pushes `10e6` in during the window ⇒ `credited = 90e6 + 10e6 = 100e6` ⇒ `budget = 100e6`.
4. `Σ price = 25e6` ⇒ `refund = 75e6`, but true credit was `90 − 25 = 65e6`. The `10e6` fee **shortfall** is absorbed by `P`. Where the attacker controls the token's fee sink, the fee is extractable.

`credited` cannot exceed the sum of *all* inbound transfers in the window, so the caller is never credited a third party's standing balance; the leak is precisely the fee.

---

## DEDUP-25-10 (Q-03) — The `:580` `min` is a single point of failure for two properties, only one documented

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Lines**: `:562-581` (`:580`), consequence at `:664`
- **Severity proposed**: **QA** · **Confidence**: high · **Delta**: yes

```solidity
budget = credited < paymentAmount ? credited : paymentAmount;   // :580
...
totalPaid = paymentAmount - refund;                             // :664  — guard REMOVED
```

`d75229d` had `totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0`. Story-029 deliberately removed the `>` guard (commit `0318089` §3.3 names its absence as the marker of the fix). The removal is **safe**, but *only* because `refund ≤ budget ≤ paymentAmount`, which holds **solely** because of the `min` at `:580`. The 20-line comment at `:562-571` justifies that `min` entirely as a **donation-routing** defence and mentions underflow in one clause of one sentence.

A future author reasoning only about donation routing — relaxing the cap to a floor, or replacing `min` with the measured `credited` on the grounds that "measuring is strictly more honest" — reintroduces an **underflow revert DoS** at `:664` with no local warning and no test name pointing at it. The two obligations should be pinned at the `min` site.

(Profile §9 note 2 and pattern near-miss NM-06 reached this independently.)

---

## DEDUP-25-11 (Q-04) — docs §4.1 "SAFE BY CONSTRUCTION" heading exceeds the construction actually built

- **Location**: `docs/multi-token-nudge.md:200`, `:213`
- **Severity proposed**: **QA** · **Confidence**: medium · **Delta**: yes
- **Candidate merge with DEDUP-25-05 at report time.**

> "### 4.1 The payment token MAY be a reward token — **SAFE BY CONSTRUCTION** (story 029)"
>
> "**The construct is now permitted and safe, not forbidden.**"

What story-029 established **by construction**, and what this run independently verified, is precisely two properties — `refund <= budget <= paymentAmount` (the pot cannot leave through the **refund**), and the minter's allowance bounded at the exact per-mint price. Both are real and both are invariant-proven. The section **body** scopes itself correctly to those two. The **heading and the standalone sentence do not**: they read as an unconditional blessing of the collision configuration, while the residual exposure lives in the third exit path — the **qualifying payout** at `:790`, which no construction bounds.

Note this is the *mirror image* of the same section's own self-correction, which deletes a previously false claim and says so — the section is otherwise a model of honest revision; the heading simply did not get the same treatment.

**Suggested wording**: *"the payment token MAY be a reward token — the refund path is safe by construction (story 029); the payout path remains bounded only by funding discipline (§1)."*

---

## Fix-completeness verdicts carried forward to the sanitizer

| fingerprint | label | ledger status | story-029 effect |
|---|---|---|---|
| `ad36260fc91f…` | M-07 medium | **fix-pending** | **COMPLETE — propose `fixed`.** `:624` approves the exact next `price` (absolute write); `:623` reverts `BatchMint__PaymentBudgetExhausted` *before* the approval when `price > budget`; `:631` zeroes unconditionally. `NFTMinterV2._executeMint` has exactly one `transferFrom` (sourcing `msg.sender`), so `Σ price_i ≤ budget ≤ credited` and the pot `P` is **structurally unreachable by the minter**. No residual path constructible. Human applies; do **not** auto-flip. Carry DEDUP-25-06 / DEDUP-25-07 as the two things that could un-fix it. |
| `1c222d548523…` | H-01 high | **fix-pending** | **NOT IMPLICATED.** Root cause is `src/NFTStakerDepletion.sol :: depositFor` paying the migrator; `git diff --stat d75229d..5015f1b` lists exactly one `src/` file and it is not that one. Neither fixed nor regressed. No action. |
| `43e8c48626ee…` | M-01 medium | **wont-fix** | ⛔ **RE-WEIGH WITHDRAWN 2026-07-26 — this entry stands unchallenged; its `wont-fix` rationale is intact and was NOT touched.** ~~RE-WEIGH (DEDUP-25-01, DEDUP-25-03). Prior Σ was computed over a pot set that excluded the payment token; story-029 adds a pool. Its own re-arm trigger is met. **Do not inherit; do not clobber the status.** |
| `858e9e807abe…` | H-01 high | **wont-fix** | ⛔ **RE-WEIGH WITHDRAWN 2026-07-26 — this entry stands unchallenged; its `wont-fix` rationale is intact and was NOT touched.** ~~RE-WEIGH (DEDUP-25-01, DEDUP-25-03). The value-blind count-only gate at `:510` is untouched and now releases one more pool; its re-arm triggers (b) and (e) are met. Same disclosure obligation. **Do not clobber the status.** |

---

## Not re-filed (scope discipline)

- **KI #15's accepted same-denomination nudge arbitrage.** The four claims it suppresses — *"batching is profitable"*, *"the pot is sniped by MEV bots"*, *"payment token should not be whitelisted as a nudge token"*, *"`setNudgeTokenWhitelist` no longer rejects the payment token"* — appear **nowhere** in this file. DEDUP-25-01 and DEDUP-25-03 are filed under KI #15's own carve-out **(d)** (*"the aggregate over-funding class … about the pot being too LARGE relative to cost"*), i.e. **inside the carve-out, not inside the acceptance**. See `manual-review.json` MR-05.
- KI #15 carve-outs (a)/(b)/(c) are **clean**: no path lets the pot leave without `nudgeSize` real mints; `refund > paymentAmount` is invariant-proven impossible; a non-qualifying batch takes nothing (`test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing`, passing). **`ycn19h1` is genuinely closed at the root story-029 names.**
- Local arithmetic (Tier 1), and the per-token wont-fixes' underlying value-blindness (only the aggregate delta is filed).

## Parked in `manual-review.json` (visible channel, nothing dropped)

MR-01 (14 Aderyn reentrancy potential-highs + 38/8/6 Slither reentrancy results, all pre-existing and outside the regression range) · MR-02 (P-05/SA-006 streamer flush loop, owner-bounded array ⇒ Law-3 gas ceiling) · MR-03 (SA-017 `amount == 0` skip-guard strict equality, benign) · MR-04 (margin register: NM-03/04/05/07/08 + P-04 escape reasons) · MR-05 (the KI #15 scope determination).

---

## No-silent-drop reconciliation

**Input count**: 5 pattern hits + 8 near-misses + 6 CODE + 6 ECON + 4 F-25 + 2 INV + 621 SAST = **652**. **Output**: 11 consolidated findings · 4 ledger verdicts · 1 scope determination · 5 parked entries · ~591 SAST removed with a per-class reason (gas/style/centralization/timestamp/zero-check lint classes, each named in `static-analysis.md`). **Zero silent drops.**

SAST results folded INTO a reasoned finding (the only survivors): `SA-001`, `SA-002`, `SA-004`, `SA-010`, `SA-013` → DEDUP-25-06 · `SA-058`, `SA-059`, `SA-060`, `SA-132`, `SA-133`, `SA-136`, `SA-138` → DEDUP-25-07.
