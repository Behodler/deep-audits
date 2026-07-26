> **⚠ POST-RUN CORRECTION (applies to every `NudgeRatchet` citation below).**
> This scan cited the STALE nested gitlink `lib/phoenix-nft-staking/lib/mutable/yield-claim-nft`
> @ `aa86be6`. The authoritative source is the top-level `lib/yield-claim-nft` @ **`d4cc563`**.
> At `d4cc563`: the `_dispatch` leaf `IERC20(_token).safeTransfer(batchMinter, bal)` cited here as
> **`NudgeRatchet.sol:100` is DELETED, with no fallback branch** — it is replaced by
> `forceApprove(streamer, bal)` + `INudgeStreamer(streamer).collectNudge(batchMinter, _token, bal)`
> at **`:156-161`**, metered by `NudgeStreamer` over `duration`. The 6-decimal constructor guard
> cited as **`:44`** is now at **`:84`**. `NudgeStreamer` is value-conserving (total delivered =
> total deposited), so every *conservation* conclusion below survives; every *instantaneous /
> next-block timing* conclusion does not. See `submissions/M-01.md` for the corrected mechanism.

# Economic / Design Scan — phoenix-nft-staking run-25 (story-029)

- **Target**: `lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol` @ `5015f1b`
- **Tier**: 2 (protocol-wide economic / cross-contract value flow)
- **Inputs consumed**: `profiles/BatchNFTMinterMultiToken.md`, `pattern-matches.md` (P-01, P-02, P-03), `scan-code.md` (CODE-001, §C KI-15 note), `lib/phoenix-nft-staking/docs/multi-token-nudge.md`, ledger `reports/ledgers/phoenix-nft-staking.json`, KI #15 (`registered-projects.json`)
- **Cross-repo source read** (value-flow closure, not re-profiled): `lib/mutable/yield-claim-nft/src/dispatchers/NudgeRatchet.sol`, `src/NudgeStreamer.sol`
- **Scan type**: economic. Local arithmetic deferred to Tier 1 and not re-derived.

> **Bottom line.** The two `wont-fix` entries were both closed on the premise
> *"Σ(nudge pots) < the cost of one qualifying batch"*. At the project's **own story-029
> fixture config**, and with the **project's own passing test** as the witness, that premise is
> **inverted 4×**: `assertEq(usdc.balanceOf(nftRecipient), pot)` in
> `test_PaymentTokenAsNudge_qualifyingBatchStillEarnsThePot` pays a **200.000000 USDC** pot for a
> **50.000000 USDC** qualifying cost. Worse, the inversion is not an owner over-funding accident —
> it is **reached and re-armed by ordinary protocol usage**, because `NudgeRatchet._dispatch`
> forwards **100 % of every mint's payment** into the very pot the batch minter pays out.

---

## Quoted prior rationale (the re-weigh baseline)

**Ledger `43e8c48626ee…` (M-01, `wont-fix`, operator 2026-07-24)** — the aggregate entry:

> "story-025's whole-whitelist payout pays the qualifying recipient the PRIOR-accumulated pot of
> EVERY whitelisted nudge token in one event … for a SINGLE qualifying cost … break-even shifts
> from 'each pot < qualifying cost' to 'SUM(pot_i) < qualifying cost'."
>
> "**[OPERATOR 2026-07-24]** STATUS: open -> wont-fix. Owner-accepted as a bounded operational
> property … **Safe config remains: keep Σ(pot_i) < nudgeSize\*mintPrice**, or scale the qualifying
> cost by token count, or pay one nudge token per qualifying batch. **RE-ARM trigger unchanged:
> re-rate the moment a live/pending deployment funds the whitelist so Σ(pot_i) approaches/exceeds
> one qualifying cost.**"

**Ledger `858e9e807abe…` (H-01, `wont-fix`, operator 2026-07-21)** — the per-token entry:

> "(3) The NFT's only residual value is the budget-bounded NFTStaker phUSD emission stream: at
> mainnet block 25577241, 40 NFTs x 15.857984 USDS = ~634 notional against a 94.953127 USDC pot;
> even at MAX_TARGET_APY (0.5e18) that is ~317 USDS-equivalent/year against a ~539 gap, i.e. ~1.7
> YEARS of uninterrupted max-APY emissions merely to break even, before discounting. No searcher
> prices that as profit. **THE 6.7x MARGIN IS REAL.**"
>
> "WONT-FIX, NOT ACKNOWLEDGED — deliberately: this entry carries live **RE-ARM TRIGGERS** … RE-RATE
> TO HIGH IMMEDIATELY on any of: (a) nudge pot on 0x86866e01…029d exceeding ~634 USDS-equivalent
> (nudgeSize x current mint price); (b) nudge pot on 0x81896F48…A1C7 exceeding nudgeSize x
> 70.000000 USDC; (c) ANY reduction of `nudgeSize` or of the per-mint price that lowers the
> qualifying cost below the standing pot … (d) `NudgeRatchet.batchMinter()` (0x7A4eD111…) repointed
> such that the donation stream lands where the pot outgrows the qualifying cost; **(e) deployment
> of src/BatchNFTMinterMultiToken.sol behind any value-forwarding dispatcher.**"

Both rationales are **quantitative claims about a specific pot set at a specific moment**. Story-029
changes the pot set (adds the payment token) and this scan finds that the feeding mechanism makes the
inequality hold in the *wrong* direction under ordinary operation. Neither entry is silently
inherited and neither is overridden — see the disclosure blocks below.

---

## Configuration used for all numbers

Taken from the project's own artefacts, not invented:

| Quantity | Value | Source |
|---|---|---|
| payment token | USDC, **6 decimals** | `PoC_PaymentTokenCollision.t.sol:91,196`; **enforced** by `NudgeRatchet` ctor: `require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC")` (`NudgeRatchet.sol:44`) |
| `price` (ratchet index) | `10.000000 USDC`, `growthBasisPoints = 0` | `PoC_PaymentTokenCollision.t.sol:91`, `setConfig(RATCHET_INDEX, RATCHET_PRICE, 0)` :112 |
| `nudgeSize` | `5` | :93 |
| pot at attack time | `20 × 10 = 200.000000 USDC` | `_accumulatePot()`, :96-184 |
| gas, `count = 5` | ~**360,000** | `.gas-snapshot`: `batchMintN_10 = 526,327`, `batchMintN_25 = 1,027,652` ⇒ ~33,422/iter, ~192,107 base |
| gas cost | **$21.60** @ 20 gwei, ETH $3,000 | derived |
| mainnet cross-check price | `70.000000 USDC` | ledger re-arm trigger (b) |

---

## 1. ECON-001 — Σ(pots) INCLUDING the new payment-token pool is **4× ABOVE** one qualifying batch cost: the `wont-fix` premise is inverted, not merely narrowed

- **Type**: `rounding/value-blind payout` → protocol-wide value leak (rebirth of a closed rationale)
- **Severity**: **potential-medium**, ceiling **high** (C4 Medium: value leak with stated assumptions + external requirement; escalates to High on deployment — this is trigger (e))
- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint` / `_snapshotRewards`
- **Line**: 510 (gate) · **lineStart**: 507 · **lineEnd**: 511; payout path `:535 → :678 → :790`; skip-deletion site `:749-765`
- **Confidence**: **high** — the arithmetic is asserted by the project's own passing test
- **Delta**: yes (story-029 deleted the runtime skip; the pool is new to the sum)

### The code

```solidity
qualifies = _nudgeSize != 0 && count >= _nudgeSize;          // L510 — count vs count, pays a VALUE
...
uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;   // L758
```

`_snapshotRewards` no longer carries `if (rewardToken == paymentToken) continue;`. Every whitelisted
token — **including the derived `primeToken()`** — is snapshotted pre-pull, floor-checked, and paid in
full at `:790` to a caller-chosen `recipient`.

### The numbers

| Term | Pre-029 (triage baseline) | Post-029 (`5015f1b`) |
|---|---|---|
| pot set entering Σ | whitelist **minus** the payment token | whitelist, **no exclusion** |
| Σ(pots) at fixture config | `0` USDC (USDC was the payment token ⇒ skipped) | **200.000000 USDC** |
| cost of one minimal qualifying batch `C = nudgeSize × price` | `5 × 10 = 50.000000 USDC` | `5 × 10 = **50.000000 USDC**` (unchanged) |
| Σ / C | `0` — premise **held** | **4.00× — premise INVERTED** |

**Answer to question 1: NO.** Σ(pots) including the newly-added payment-token pot does **not** fall
below the cost of one qualifying batch. It is **four times above it** at the configuration the project
itself stages.

### Attack scenario (concrete, with the project's own witness)

1. Owner whitelists USDC as a nudge token while `dispatcherIndex` resolves to a **non-USDC** prime
   token — admissible, the L324-327 defence-in-depth check passes.
2. Ordinary users mint 20 NFTs on the NudgeRatchet index. `NudgeRatchet._dispatch` sweeps its **full
   USDC balance** to `batchMinter` (`NudgeRatchet.sol:100`), directly or metered through
   `NudgeStreamer`. Pot `P = 200.000000 USDC`.
3. Owner repoints `dispatcherIndex` at the USDC-prime index — **one transaction**, and per
   `docs/multi-token-nudge.md` §4.1 this is now explicitly **"permitted and safe, not forbidden"**.
4. Any unprivileged searcher calls `batchMint(5, ownAddress, 50_000000, [0])`.
   - `snapshot[usdc] = 200_000000` (pre-pull, uncontaminated).
   - `budget = 50_000000`; five mints at `price = 10_000000` consume it exactly; `refund = 0`.
   - `_payRewards` transfers **200.000000 USDC** to `recipient`.

**This is exactly `test_PaymentTokenAsNudge_qualifyingBatchStillEarnsThePot`
(`test/PoC_PaymentTokenCollision.t.sol:354-368`), currently PASSING, and asserted as *intended*:**

```solidity
uint256 cost = NUDGE_SIZE * RATCHET_PRICE;   // 50.000000 USDC
batch.batchMint(NUDGE_SIZE, nftRecipient, cost, _mins(0));
assertEq(usdc.balanceOf(nftRecipient), pot, "a qualifying batcher is paid the whole pot as a nudge");
```

with `pot == 200_000000`. **No PoC needs to be written; the repo ships one.**

### Profitability

| Line | USDC |
|---|---|
| received (pot) | **+200.000000** |
| paid (5 mints @ 10) | **−50.000000** |
| gas (~360k @ 20 gwei, ETH $3,000) | **−~21.60** |
| **net cash** | **+~128.40** |
| plus | **5 NFTs, free** |

Return on capital deployed: **2.56×** in one transaction, atomic, no price risk, no hold period.

**Break-even pot**: `P > C + gas = 50 + 21.60 ≈ 71.60 USDC`, i.e. **8 ratchet mints** since the last
claim. At the mainnet-observed `price = 70.000000 USDC`: `C = 350`, break-even `P > 371.60`, i.e.
**6 mints**. Generally: profitable after `m > nudgeSize + gasCost/price` mints.

### Why this is a REBIRTH and must be filed fresh (question 2)

Per `disclose-when-refiling-owner-wontfix`:

- **Prior entries named**: `43e8c48626ee74b51d538bd9ed12bf4898b976818f6fb44fea844ff3757daefe`
  (M-01, `wont-fix`) and `858e9e807abee888b378db210bae982f23fe7b5d91052321e204d7ba568579b7`
  (H-01, `wont-fix`). Rationales quoted verbatim above.
- **Re-file basis**: `43e8c486`'s safe-config is *"keep Σ(pot_i) < nudgeSize\*mintPrice"* and its
  Σ was computed over a pot set that **structurally excluded the payment token**, because at triage
  time `_snapshotRewards` skipped it at runtime. Story-029 **deleted that skip**
  (profile §4, "the old body contained `if (rewardToken == paymentToken) continue;` … that line is
  **deleted**"), adding a pool to the sum. The prior arithmetic is therefore not a statement about
  `5015f1b`. `858e9e80`'s "6.7× margin" is likewise a point measurement (94.95 USDC pot vs ~634
  cost) that the same delta re-denominates.
- **Root-cause class changed** ⇒ new fingerprint expected (`_snapshotRewards` scope, not the gate).
- **NOT an override**: both prior wont-fixes stand untouched. This supplies only the delta —
  the payment-token pool entering Σ, and the resulting sign flip.
- **Their own re-arm triggers are met**, not bypassed: (b) *"nudge pot … exceeding nudgeSize x
  70.000000 USDC"* and (e) *"deployment of src/BatchNFTMinterMultiToken.sol behind any
  value-forwarding dispatcher"*. `NudgeRatchet` **is** a value-forwarding dispatcher.

### Affected parties

The pot is drawn from the **honest mint-fee flow** and the **nudge-claimant population**, not from
protocol equity — see §4.

### Assumptions stated

`BatchNFTMinterMultiToken` is deployed with (i) USDC whitelisted as a nudge token and (ii)
`dispatcherIndex` resolving to a USDC-prime dispatcher. The ledger records **zero present on-chain
exposure** (run-20: *"RatchetBatchNFTMinter holds 0 USDC … NudgeRatchet.batchMinter() has been
REPOINTED"*), which is why this is filed **Medium, ceiling High**, and not High today. The docs
affirmatively bless configuration (ii) as safe, so it is **not** an owner error and Law 3 does not
suppress it.

---

## 2. ECON-002 — The qualifying cost is not a cost: `NudgeRatchet` recycles 100 % of it back into the pot, so the pot **self-re-arms at exactly `C` after every claim**

- **Type**: cross-contract value-flow loop / unintended arbitrage cycle
- **Severity**: **potential-medium** (this is what makes ECON-001 repeatable rather than one-shot)
- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint` ↔ `NudgeRatchet._dispatch`
- **Line**: 626 (`nftMinter.mint`) · **lineStart**: 621 · **lineEnd**: 627; counterparty
  `lib/mutable/yield-claim-nft/src/dispatchers/NudgeRatchet.sol:100`
- **Confidence**: **high** (mechanism), **medium** (that production wires both legs simultaneously)
- **Delta**: the loop's *cash* leg is new — pre-029 the payment token was excluded from payout, so
  the returning value could not be claimed back out

### The cross-contract flow

```
batchMint step 6+7  ──price──►  NFTMinterV2._executeMint
                                  safeTransferFrom(msg.sender, config.dispatcher, price)
                                          │
                                          ▼
                                NudgeRatchet._dispatch          (NudgeRatchet.sol:83-101)
                                  IERC20(_token).safeTransfer(batchMinter, bal)   ← 100 % OF BALANCE
                                          │
                                          ▼
                       BatchNFTMinterMultiToken payment-token balance  ==  D
                                          │  (throttled, not capped, if NudgeStreamer is interposed)
                                          ▼
                       next call's pre-pull snapshot  ==  P'
```

`_dispatch`'s own NatSpec confirms the sweep is total and deliberate: *"DESIGN: this sweeps the FULL
token balance, not the `amount` argument."*

### Why the docs' load-bearing economic claim fails

`docs/multi-token-nudge.md` §1 and KI #15 both rest on:

> "A bot that claims it must first pay more payment-token into the protocol than it extracts in
> reward. **Every claim is net-positive for the protocol**; there is no configuration of this
> mechanism under which claiming is profitable-in-isolation."

In the collision configuration the bot's payment **does not stay with the protocol**. It transits
`NFTMinterV2 → NudgeRatchet → batchMinter` and lands back in the pot as `D`. Per §4.2 donate-forward,
`D` arrives *after* the snapshot, so it is not refunded to this batcher — it seeds the **next** one.

Steady-state ledger per claim cycle, ignoring honest mints:

| Actor | Δ |
|---|---|
| searcher | `+P − C` cash, `+count` NFTs, `−gas` |
| pot | `−P + C` ⇒ **re-armed to exactly `C`** |
| protocol (USDC retained) | **0** |

So the *second* claim is a pure `C → C` round-trip: the searcher recovers their entire qualifying
cost and keeps `nudgeSize` NFTs for the price of gas alone. **The qualifying cost stops being a
cost.** Every honest third-party mint on that index pushes the cycle strictly positive.

The `NudgeStreamer` does not close this — it is a **timing throttle, not a value cap**
(`_accrued = min(rewardPerSecond * elapsed / PRECISION, buffer)`, `NudgeStreamer.sol:192-199`; and
this project's own run-24 note records the same conclusion). A patient searcher recovers 100 % of
`C` after `duration`.

### Attack scenario

1. Arm as in ECON-001 (or simply wait — see the break-even mint counts above).
2. Claim: pay `C`, receive `P`, leave `D = C` behind.
3. Wait `duration` (streamer) or zero blocks (direct wiring).
4. Repeat. Each cycle costs ~$21.60 of gas and yields `nudgeSize` NFTs plus any honest-mint accretion.

### Profitability

Perpetual, gas-bounded. Break-even per cycle: honest-mint accretion since last claim
`> gas ≈ $21.60`, i.e. **≥ 3 honest mints at `price = 10 USDC`** (or ≥ 1 at `price = 70`) — plus the
free NFTs on every cycle regardless.

### Law-3 framing

Two ordinary owner settings compose: `NudgeRatchet.batchMinter = <this contract>` (its designed
purpose) and `BatchNFTMinterMultiToken.dispatcherIndex = <the ratchet index>` (blessed by §4.1). A
competent, non-malicious owner would be **surprised** that the batch minter paying its mints through
the dispatcher that funds its own pot creates a closed loop in which the qualifying cost returns to
the claimant. **Surprise ⇒ footgun ⇒ in scope.**

**Safe config**: never set `dispatcherIndex` to an index whose dispatcher forwards to this contract;
or make the payout value-aware (`payout ≤ Σ prices actually charged this batch`); or take a haircut.

---

## 3. ECON-003 — CODE-001's sub-dust residue makes the pot **self-feeding with no cap**, converting both `wont-fix` closures into **TIME-BOUNDED (expiring) closures**

- **Type**: accumulator value routing / expiring closure
- **Severity**: **potential-low** as a standalone leak; **the finding is the expiry**, which is an
  **operational hazard** on the two ledger entries
- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Line**: 662 · **lineStart**: 659 · **lineEnd**: 668 (constant `:146`)
- **Confidence**: high (mechanism), medium (rate — depends on frontend quoting slack)
- **Delta**: yes — pre-029 the residue was **recoverable** by a later sweep; post-029 it is not

### Question 3, answered with numbers

CODE-001 establishes that post-029 the refund source is `budget` (this call's credit only), so residue
from a prior call is **permanently unreachable by any refund** and can leave only via `_payRewards`
(the pot) or `rescueERC20`. Per batch, the forfeiture is `0 … 999,999` raw units = **0 … 0.999999
USDC**, and it accretes into `P` monotonically with **no cap and no owner action**.

Batches required for the dust channel *alone* to arm a profitable snipe (`P > C + gas`):

| config | `C` | target `P` | @ max 0.999999/batch | @ realistic 0.5 USDC frontend slack (CODE-001's own example) |
|---|---|---|---|---|
| fixture: `price = 10`, `nudgeSize = 5` | 50.00 | 71.60 | **72 batches** | **144 batches** |
| mainnet: `price = 70`, `nudgeSize = 5` | 350.00 | 371.60 | **372 batches** | **744 batches** |

**Therefore: yes, `P` grows to profitability given enough batches, with no owner funding action at
all.** The `43e8c486` safe-config *"keep Σ(pot_i) < nudgeSize\*mintPrice"* is not a configuration a
non-malicious owner can hold — it decays on its own at a rate set by third-party frontend quoting
behaviour.

### Classification (per `expired-closure-vs-regression`)

This is **not a code regression** — no prior fix was reverted. It is an **expiring closure**: the
rationale behind `43e8c486`/`858e9e80` has a finite shelf life measured in batch count. It belongs in
its own bucket and must not be written up as "restore the patch", because there is no patch to
restore. The correct disposition is a **standing monitor** on `P` versus `nudgeSize × price`, not a
one-time re-check.

(Note the dust channel is the *slow* one. ECON-002's ratchet channel arms the same condition in
**6-8 mints**. The dust channel matters because it survives even if the ratchet wiring is removed.)

---

## 4. Who funds `P`, and who bears the loss (question 4)

| channel | funder | mechanism | cap |
|---|---|---|---|
| 1 — dominant | **honest NFT minters** (third party) | `NudgeRatchet._dispatch` sweeps 100 % of every mint's USDC to `batchMinter` (`NudgeRatchet.sol:100`) | none |
| 2 — self-feeding | **non-qualifying batchers** (third party) | sub-`DUST_THRESHOLD` refund forfeiture, `:662` else-branch, silently reported as `totalPaid = paymentAmount` | none |
| 3 — declared intended | anyone | permissionless top-up (`docs` §1 "Intended side effects") | none |
| 4 — recycled | **the previous claimant** | ECON-002 loop | `= C` |

**The loss is NOT borne by protocol equity, and it is NOT borne by the owner.** It is borne by:

1. **The intended nudge-claimant population** — honest batchers who would have been paid this
   incentive. The pot is winner-take-all (`docs` §5), so a searcher arming on the `P > C` inequality
   captures the entire incentive budget that mint-fee flow accrued for them.
2. **The upstream mint-fee flow** — value that transited `NFTMinterV2 → NudgeRatchet` and was
   earmarked as a batching incentive leaves to an actor who performed no batching service beyond the
   minimum `nudgeSize`.
3. **Non-qualifying batchers specifically** (channel 2) — a silent, repeatable, caller-funded
   subsidy from every over-quoting batcher to whoever next satisfies the count-only gate. It is
   invisible in the return value, so no off-chain consumer can detect it.

Materially, this is a **redistribution among protocol users**, not a treasury drain — which is the
honest reason ECON-001 is Medium rather than High absent deployment. It is also precisely why the
docs' *"every claim is net-positive for the protocol"* framing mis-locates the harm: the protocol's
balance sheet is not the injured party, so a claim can be protocol-neutral and still strip the
incentive budget from the population it was raised for.

---

## 5. ECON-004 — KI #15 scope statement: story-029 **WIDENED** the accepted risk beyond what was accepted

- **Type**: operational hazard / acceptance-scope drift
- **Severity**: **QA / operational** — this mints **no new finding**; it is a scope determination
- **Confidence**: high

**The accepted arbitrage is NOT re-filed.** KI #15 forbids filing *"batching is profitable"*, *"the
pot is sniped by MEV bots"*, *"payment token should not be whitelisted as a nudge token"*, or
*"setNudgeTokenWhitelist no longer rejects the payment token"*. None of those is filed here.

**Statement requested: YES, the risk is wider than what was accepted.** Three specific respects:

1. **KI #15 carves it out explicitly.** Its own narrow-scope clause preserves at full severity
   *"(d) the aggregate over-funding class (858e9e80…, and the run-22 sigma-pots Medium), which is
   about the pot being too LARGE relative to cost — a different claim from the comparison being
   easy."* ECON-001 and ECON-003 are exactly class (d). They are **inside the carve-out, not inside
   the acceptance.**
2. **The acceptance's own premise is falsified by ECON-002.** KI #15 accepts on the ground that
   *"the pot is by construction a fraction of the cost of the nudgeSize mints required to qualify —
   every claim is net-positive for the protocol."* With `NudgeRatchet` recycling 100 % of the cost,
   the claim is **cash-neutral to the protocol** and the pot is not bounded below the cost by any
   construction — no code enforces the relation (see ECON-005). An acceptance covers the risk **as
   it stood**; it cannot cover a risk whose stated bound does not exist.
3. **The accepted risk was static; the delivered risk is self-arming.** KI #15 contemplates a pot
   that *"will be taken promptly whenever it exceeds the qualifying cost"* — framed as an owner
   over-funding event. ECON-002 (6-8 mints) and ECON-003 (72-744 batches) make the threshold cross
   **without any funding event at all**.

**Recommended disposition**: re-confirm the acceptance against the enlarged surface, or narrow it.
Do not treat the 2026-07-25 acceptance as covering ECON-001/002/003.

---

## 6. ECON-005 — `DUST_THRESHOLD` is decimals-blind and the intended dispatcher **mandates** the bad arm (P-02 quantification)

- **Type**: owner footgun (Law 3, non-obvious consequence)
- **Severity**: **potential-low** (this is the econ quantification of P-02 / CODE-001, **not** a
  separate finding — dedup against CODE-001)
- **Line**: 146 · **lineStart**: 659 · **lineEnd**: 668

```solidity
uint256 internal constant DUST_THRESHOLD = 1e6;   // L146, raw wei, no decimals normalisation
if (refund / DUST_THRESHOLD != 0) { … } else { totalPaid = paymentAmount; }   // L662, all-or-nothing
```

**Per-batch forfeiture, quantified as requested:**

| `primeToken` decimals | `1e6` raw units equals | max forfeited per batch | at $1/token |
|---|---|---|---|
| **18** (phUSD) | `1e-12` token | `0.000000000000999999` token | **$1.0 × 10⁻¹²** |
| **6** (USDC) | `1.000000` token | **`0.999999` token** | **$1.00** |

**Ratio: 1 × 10¹² more value forfeited per batch at 6 decimals than at 18** for equally-priced
tokens. The NatSpec at `:142-145` (*"For an 18-decimal token this is ~10⁻¹² of a unit"*) documents
only the benign arm.

**The escalating fact this scan adds to P-02**: the 6-decimal arm is **not a hypothetical repoint**.
`NudgeRatchet`'s constructor *requires* it:

```solidity
require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");
```
(`NudgeRatchet.sol:44`)

So on the dispatcher family this contract exists to serve, `DUST_THRESHOLD` is **structurally
1.000000 whole payment tokens**, by deploy-time enforcement upstream. The footgun is not "if the
owner repoints at a 6dp token" — it is **the default on the intended path**.

**Law-3 test**: would a competent, non-malicious owner wiring the batch minter behind `NudgeRatchet`
be surprised that per-batch refunds under one whole USDC vanish, permanently, into the nudge pot, while
`totalPaid` reports the caller spent their full `paymentAmount`? **Yes. Surprise ⇒ footgun ⇒ report.**

**Safe config**: scale off `IERC20Metadata(paymentToken).decimals()`; or lower the constant to `1e2`
(dust at 6dp, still absorbs JS slack); or make the branch partial rather than all-or-nothing.

---

## 7. ECON-006 — The value-blind `qualifies` gate is **not faithful** to the economic intent stated in `docs/multi-token-nudge.md`

- **Type**: intent verification / documentation-vs-implementation mismatch
- **Severity**: **QA / Low** (the *consequence* is already priced in ECON-001; this entry records the
  spec deviation)
- **Line**: 510 · **lineStart**: 507 · **lineEnd**: 511
- **Confidence**: high

**Documentation states an invariant.** `docs/multi-token-nudge.md` §1 ("Why the 'honeypot' framing
does not apply"):

> "The pot is a *nudge*: **by construction** it is a fraction of the cost of the `nudgeSize` mints
> required to qualify. A bot that claims it must first pay more payment-token into the protocol than
> it extracts in reward."

and §5:

> "That is acceptable precisely because of §1: **winning requires paying more into the protocol than
> the pot is worth.** Bot competition here is a subsidy to the protocol, not an extraction from it."

**Implementation enforces nothing of the kind.**

```solidity
qualifies = _nudgeSize != 0 && count >= _nudgeSize;    // L510
```

`qualifies` is a function of `count` and `nudgeSize` **only**. It never reads `paymentAmount`, never
reads `price`, never reads `budget`, and never compares anything to `snapshot[i]`. There is **no
code path anywhere in the file** that relates the pot to the cost. The phrase *"by construction"*
names a construction that does not exist — it is an aspiration about how the owner will fund, stated
in the grammar of an invariant.

**Two supporting observations:**

1. `docs` §4.6 offers *"qualifying still costs `nudgeSize` real mints **at the ramping price**"* as
   the economic backstop. The ramp is **void at `growthBasisPoints == 0`**, which is how the project's
   own ratchet index is configured (`setConfig(RATCHET_INDEX, RATCHET_PRICE, 0)`,
   `PoC_PaymentTokenCollision.t.sol:112`) and the test comments confirm (*"growth is 0 on this
   index"*, :358). At flat pricing the cost is exactly `nudgeSize × price` with no escalation
   working against a searcher.
2. The gate's asymmetry is stark and worth stating plainly: **a count is compared to a count, and a
   value is paid out.** The two quantities are never in the same expression.

**Discrepancy and impact**: the documented economic guarantee is unbacked. A reader of the docs — or
an operator configuring the whitelist against them — will believe a bound is enforced that is not.
This is the root of why ECON-001's premise inversion goes undetected by the contract itself.

**Remediation (single shared fix with ECON-001 and the two ledger entries)**: make the payout
value-aware — cap the total nudge payout at some fraction of the payment actually charged this batch
(`paymentAmount - refund`, which the contract already computes at `:664`), or make the gate a value
gate. Either turns the docs' claim into a construction.

---

## 8. Checks run and cleared (no economic finding)

| Question | Verdict | Basis |
|---|---|---|
| Cross-contract rounding composition (deposit-leg down in A + withdraw-leg up in B) | **N/A** | This contract holds no shares, no accumulator, no conversion. The only division is `refund / DUST_THRESHOLD` (a threshold test, not a conversion). Round-trip checklist walked; no share/asset/debt conversion exists to rank. |
| Round-trip: can a batcher end with more payment token than they started, absent a pot? | **No.** | `refund ≤ budget = min(credited, paymentAmount)`. With `P = 0` and no qualifying payout, the batcher ends at `−C` exactly. Only a **non-empty pot** makes the round-trip positive, and that is ECON-001, not a rounding leak. |
| Does the refund leg round in the user's favour? | **No.** | Sub-threshold residue rounds toward the **protocol's pot**, i.e. away from the user (`:666`). Direction is protocol-favouring; the defect is **magnitude** at 6dp (ECON-005), not direction. |
| Oracle dependency / price manipulation | **No oracle.** | `price` comes from `nftMinter.configs()` — an owner-pinned minter's own state, re-read immediately before each charge (profile §3). No TWAP, no reserves read, no external price feed. Flash-loan surface: none — nothing in the value flow is priced off a manipulable pool. |
| Flash-loan amplification of ECON-001 | **No.** | The attack needs `C` of payment token (50 USDC at fixture config) and is already trivially self-funded. A flash loan adds fees for no benefit; `count` scaling does not increase the payout (the pot is fixed at snapshot). |
| Cross-pool contamination between whitelisted nudge tokens | **None.** | `snapshot[i]` is per-token and `_payRewards` transfers each independently; no shared accumulator. The **aggregation** across tokens for one cost is `43e8c486`'s existing (accepted) class, re-weighed in ECON-001, not a new contamination path. |
| Liquidation cascade / bad debt | **N/A** | No collateral, no debt, no liquidation in this contract. |
| Governance attack vector | **N/A** | No governance surface; owner-only setters, Law 3. |
| MEV: does `minRewards` help a loser? | **No, by documented design.** | `docs` §5: *"`minRewards` protects the loser … but does nothing to help them win."* Winner-take-all is declared intended. Not re-filed. |
| Does the step-9/10 swap create an economic underfunding? | **No.** | Balance at payout `= P + (credited − C) + D − refund` with `refund ≤ budget ≤ credited`; `≥ P + D` remains and `_payRewards` needs `P`. (Concurs with scan-code §D and P-04.) |
| Fee-arbitrage between `BatchNFTMinter` (V1) and `BatchNFTMinterMultiToken` | **No cross-contract arb.** | The two do not share a pot or a dispatcher wiring; V1 is frozen. V1's unpatched shape is the fork-drift watch-note at CODE-006, not an arbitrage path. |
| Accumulated precision loss across calls | **Only ECON-003.** | The single accreting quantity in the system is the sub-dust residue, covered above. `NudgeStreamer`'s `PRECISION`-scaled rate keeps dust in the buffer by design (`NudgeStreamer.sol:50-52`). |

---

## 9. Coverage, assumptions, and errors

- **Profile-first**: value-flow surfaces taken from `profiles/…§5` (entry points) and `§8` (every
  payment-token exit path). Source was read **selectively** — `:507-511`, `:525-545`, `:555-585`,
  `:615-700`, `:749-765` — only to confirm the suspected protocol-wide issues above.
- **Verified properties trusted** (profile §10, all tagged *verified*): checked arithmetic,
  `nonReentrant` coverage, access control, absent randomness, zero post-call allowance. Not
  re-derived.
- **Properties re-examined rather than inherited**: the profile's §9 note that *"the pot is invisible
  to the refund"* is true of the refund's **source** but not its **ceiling**. Confirmed against
  source; it does not change any conclusion here (P-03 owns that thread).
- **Cross-repo assumption, stated**: ECON-002 depends on `NudgeRatchet.batchMinter` resolving to this
  contract (directly or via `NudgeStreamer`) **and** `dispatcherIndex` resolving to that ratchet's
  index. Both legs read from source; **neither was verified against a live deployment** — the ledger
  records the current mainnet wiring as repointed and the pot as empty. This is the arming condition,
  stated honestly, not assumed.
- **`NudgeRatchet` growth basis points on mainnet were not read** (no fork access this scan). All
  ramp-free arithmetic uses the project's own fixture (`growthBasisPoints = 0`). A non-zero live ramp
  raises `C` and pushes the break-even mint count up proportionally; it does not change the sign of
  the ECON-002 recycling loop.
- **Not re-filed**: KI #15's accepted same-denomination arbitrage; the per-token wont-fixes'
  underlying value-blindness (only the aggregate delta is filed); local arithmetic (Tier 1).
- **Errors**: none. All targeted files readable.
