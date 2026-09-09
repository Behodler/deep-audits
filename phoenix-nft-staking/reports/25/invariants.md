# Tier-3 Invariant Verification — phoenix-nft-staking run-25

- **Project / commit**: `phoenix-nft-staking` @ `5015f1b` (story-029)
- **Workspace**: `/home/justin/code/audits/workspace/phoenix-nft-staking` (source verified byte-clean vs `5015f1b` after the mutation control — `git diff --stat src/` empty)
- **Harness (audit-authored)**: `/home/justin/code/audits/workspace/phoenix-nft-staking/test/AuditInvariant_EconValueBound.t.sol`
- **Runner**: Foundry `forge` invariant runner
- **Result**: **INV-25-01 FAILED**, **INV-25-02 FAILED**. Both with self-contained, deterministically-replayable counterexamples.

> ⚠️ **`test/AuditInvariant_EconValueBound.t.sol` is AUDIT-AUTHORED.** It does **not** exist in
> the upstream repository at `5015f1b` and must **never** be cited as a project test, nor
> exported into a submission as though the project ships it. The only project artefacts cited
> below are `test/PoC_PaymentTokenCollision.t.sol` and
> `test/BatchNFTMinterMultiTokenBudgetInvariant.t.sol`, both of which are in `git ls-tree 5015f1b`.

---

## 0. What was NOT duplicated

The project's own `test/BatchNFTMinterMultiTokenBudgetInvariant.t.sol` is good and was left
untouched. It was re-run as a control (see §5) and is **green at 128,000 calls per invariant**.
It proves the **refund side**:

- `refund <= budget <= paymentAmount`, and `totalPaid == paymentAmount - refund`;
- the pot leaves **atomically** — exactly `0` (non-qualifying) or `-P` (qualifying), never partially.

Its blind spot is that both properties are **relational within the contract's own accounting**.
Neither relates the **pot payout** to **what the caller paid**. `qualifies` compares a *count* to a
*count* and pays out a *value*; the two quantities never appear in one expression (`:510`, ECON-006).
That is the gap the two invariants below close.

---

## 1. Configuration (the project's own fixture)

Taken verbatim from `test/PoC_PaymentTokenCollision.t.sol` so every number below is directly
comparable to it:

| Quantity | Value |
|---|---|
| payment token | USDC stand-in, **6 decimals** |
| index 1 ("ratchet") | USDC-prime, `price = 10.000000`, `growthBasisPoints = 0` |
| index 7 ("pay") | PAY-prime — the admissible index at whitelist-write time |
| `nudgeSize` | **5** |
| `DUST_THRESHOLD` | `1e6` = **1.000000 whole USDC** at 6dp |
| collision staged by | whitelist USDC while index 7 pinned (L324-327 defence-in-depth passes), then `setDispatcherIndex(1)` — one owner tx, blessed by `docs/multi-token-nudge.md` §4.1 |
| `NudgeStreamer` | **not wired** — it is a timing throttle, not a value cap (run-24 note); omitting it keeps counterexamples minimal and does not change the sign |

The dispatcher leg models `NudgeRatchet._dispatch` faithfully: it sweeps the **full** payment-token
balance to the batch minter (its own NatSpec: *"DESIGN: this sweeps the FULL token balance, not the
`amount` argument"*), not the `amount` argument.

---

## 2. INV-25-01 — no atomic profit — **FAILED**

**Property.** For any successful `batchMint`, in payment-token terms:

```
payoutToRecipient + refundToMsgSender  <=  paymentAmount
```

This is the property `docs/multi-token-nudge.md` §1/§5 asserts (*"winning requires paying more into
the protocol than the pot is worth"*) and that no line of `BatchNFTMinterMultiToken` enforces.

**Command**

```bash
cd /home/justin/code/audits/workspace/phoenix-nft-staking
FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=500 \
  forge test --match-contract AuditInvariant_NoAtomicProfitTest -vv
```

**Result**

```
[FAIL: INV-25-01: a batchMint caller received more payment-token value
       (nudge payout + refund) than it supplied as paymentAmount]
invariant_NoAtomicProfitFromQualifyingBatch()   (failed on the FIRST run)
```

Configured budget 256 runs × 500 depth = 128,000 calls; the property is violated within the first
run, so the campaign terminates immediately. Zero handler reverts.

### 2a. Counterexample — fuzzer-discovered, 3 calls, replays standalone

Obtained unshrunk (`FOUNDRY_INVARIANT_SHRINK_RUN_LIMIT=0`, `cache/invariant` cleared):

| # | call | decoded | effect |
|---|---|---|---|
| 1 | `batchMintFuzzed(10336, 2777)` | `count = 8`, `paymentAmount = 80.002777` | 8 mints; refund `2777` is **sub-dust** → forfeited into `P`. `P = 0.002777` |
| 2 | `honestMintAndDispatch(2.503e45)` | 1 honest mint @ 10.000000, then dispatcher sweeps its **whole** balance | sweeps back the **80.000000 the searcher itself paid in call 1**, plus the honest 10.000000. `P = 90.002777` |
| 3 | `batchMintFuzzed(210000000, 7513)` | `count = 8 >= nudgeSize`, `paymentAmount = 80.007513` | qualifies; whole pot paid to caller-chosen `recipient` |

**Measured at call 3** (`test_witness_INV2501_replayFuzzerSequence`, PASS):

```
replay: pot at claim             :  90002777   (90.002777 USDC)
replay: paymentAmount supplied   :  80007513   (80.007513 USDC)
replay: value received           :  90002777
replay: atomic profit            :   9995264   (+9.995264 USDC, one transaction)
```

This is the **ECON-001 × ECON-002 composition** the fuzzer found on its own: the searcher's own
qualifying cost is recycled back into the pot by the dispatcher, so the second claim is a
near-free round trip plus the honest-mint accretion — and 8 free NFTs.

### 2b. Counterexample — the econ-scanner's headline case, reproduced exactly

`test_witness_INV2501_qualifyingBatchIsAnAtomicProfit` (PASS):

```
pot at claim (USDC 6dp)          : 210000000   (21 honest mints × 10.000000)
paymentAmount supplied (USDC 6dp):  50000000   (nudgeSize 5 × 10.000000)
value received (payout + refund) : 210000000
atomic profit (USDC 6dp)         : 160000000   (+160.000000 USDC)
count                            :         5
```

Return on capital deployed: **4.2× in one atomic transaction**, plus 5 free NFTs, no price risk,
no hold period. This matches the econ-scanner's 200-for-50 figure and the project's own passing
`test_PaymentTokenAsNudge_qualifyingBatchStillEarnsThePot`.

### 2c. Note on the shrunk trace — do not use it

Foundry's shrinker replays candidate sub-sequences against a handler whose **sticky violation flag
is already false**, so for this class of invariant the printed shrunk sequence is *not* guaranteed
to be a self-contained reproduction. The run's shrunk output was a single
`batchMintFuzzed(4.879e72, 0)` call which, replayed from a fresh state, **reverts and does not
reproduce**. The two witnesses in §2a/§2b are the load-bearing artefacts; they are ordinary
`test_` functions that replay from `setUp` and are asserted, not printed.

---

## 3. INV-25-02 — the pot must not be self-feeding — **FAILED**

**Property.** Across a sequence of batches, the standing pot `P` must not grow except through an
explicit funding action. The handler performs **exactly one** funding action — a 30.000000 USDC
seed in its constructor — and no other; every subsequent increase is caller-forfeited residue from
the sub-`DUST_THRESHOLD` else-branch at `:662`. Growth is accumulated as a **sum of positive
deltas**, not an absolute level, so a qualifying drain cannot mask accretion between drains.

**Command**

```bash
cd /home/justin/code/audits/workspace/phoenix-nft-staking
FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=500 \
  forge test --match-contract AuditInvariant_PotNotSelfFeedingTest -vv
```

**Result**

```
[FAIL: INV-25-02: the standing nudge pot grew without any funding action;
       sub-dust refunds are forfeited into it: 882091 != 0]
invariant_PotDoesNotGrowWithoutExplicitFunding()
```

Counterexample: **one call** to `nonQualifyingSubDustBatch` — a single ordinary non-qualifying
batch whose frontend over-quoted by `0.882091 USDC` — grew the pot by that amount, permanently.
(Repeat runs land on different sub-dust amounts: `429106`, `440755`, `882091` — the channel is the
finding, not the specific value.)

### 3a. Monotonicity witness

`test_witness_INV2502_potGrowsMonotonicallyFromForfeitedDust` (PASS) drives 72 ordinary
non-qualifying batches at the maximum sub-dust slack and asserts the pot grew on **every single
one**:

```
pot growth from 72 non-qualifying batches (USDC 6dp): 71999928   (71.999928 USDC)
cumulative unfunded growth ghost                    : 71999928
growth events                                       : 72 / 72
```

`71.999928 > 71.60` — the break-even pot for the fixture config (`C = 50.000000` + ~$21.60 gas).
**72 ordinary batches, with no owner funding action whatsoever, arm a profitable ECON-001 snipe.**

This is the **time-bounded-closure** evidence: the safe-config the two `wont-fix` closures rest on
(`43e8c486`: *"keep Σ(pot_i) < nudgeSize × mintPrice"*) is **not a configuration a non-malicious
owner can hold**. It decays on its own at a rate set by third-party frontend quoting behaviour.
Per `expired-closure-vs-regression` this is an **expiring closure, not a regression** — there is no
patch to restore; the correct disposition is a standing monitor on `P` vs `nudgeSize × price`.

---

## 4. Anti-vacuity validation (mandatory — this project has a documented history)

### 4a. Tripwires in the harness

Each invariant contract carries an `afterInvariant()` that fails **by name** on:

- `TRIPWIRE: the handler was never called`
- `TRIPWIRE: no batch ever succeeded`
- `TRIPWIRE: the pot was never non-empty; the invariant would be vacuous`
- `TRIPWIRE: the QUALIFYING branch was never exercised`
- `TRIPWIRE: the NON-QUALIFYING branch was never exercised`
- `TRIPWIRE: the SUB-DUST-REFUND branch was never exercised`

### 4b. Mutation control — INV-25-01 flips green ↔ red on the story-029 delta

The task's specified mutation was applied to `src/BatchNFTMinterMultiToken.sol`: the pre-story-029
runtime skip restored in `_snapshotRewards`:

```solidity
(,, IERC20 _pt) = _resolvePaymentPath();
if (rewardToken == address(_pt)) continue;   // AUDIT MUTATION (run-25)
```

Result under the mutation:

| | unmutated `5015f1b` | mutated (skip restored) |
|---|---|---|
| `invariant_NoAtomicProfitFromQualifyingBatch` | **FAIL** (first run) | **PASS — 256 runs, 128,000 calls, 0 reverts** |
| all six `afterInvariant` tripwires | (not reached) | **all held** — pot non-empty, qualifying / non-qualifying / sub-dust branches all exercised |
| `test_witness_INV2501_...AtomicProfit` (asserts the violation) | PASS | **FAIL** — correctly inverted |
| `invariant_PotDoesNotGrowWithoutExplicitFunding` | FAIL (`882091`) | **FAIL (`440755`)** — correctly *unchanged*: the dust channel is independent of the snapshot skip |

**INV-25-01 is therefore proven load-bearing and non-vacuous.** It is green exactly when the
payment-token skip is present and red exactly when story-029's deletion of it is in place — it
measures the delta and nothing else. The 128,000-call green run under the mutation additionally
proves the harness *is capable of passing*, so the failure is a property of the code, not of a
broken driver.

INV-25-02 requires no mutation control: a **failing** invariant with a deterministic, self-contained
replay cannot be vacuous.

**Source was restored after the mutation** — `git diff --stat src/` is empty and `forge build`
is clean.

### 4c. Control — the project's own harness stays green

```bash
FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=500 \
  forge test --match-path test/BatchNFTMinterMultiTokenBudgetInvariant.t.sol
```

```
[PASS] invariant_RefundNeverExceedsPaymentAmount()   (runs: 256, calls: 128000, reverts: 0)
[PASS] invariant_PotOnlyLeavesViaQualifyingPayout()  (runs: 256, calls: 128000, reverts: 0)
Suite result: ok. 2 passed; 0 failed  (98.04s)
```

Both project invariants hold at 128,000 calls **on the same commit, in the same collision
configuration, in the same transaction shapes** where INV-25-01 fails on the first run. That is the
blind spot stated empirically: refund-side accounting is sound; the payout is not bounded by what
the caller paid.

---

## 5. Honesty statement on run depth

- INV-25-01 and INV-25-02 **FAILED** — these are positive results (counterexamples exist), and both
  are backed by `test_` replays that reproduce from a fresh `setUp` with concrete asserted numbers.
  They are not "absence of evidence".
- The one **passing** campaign reported here is the mutated-source control at
  **256 runs / 128,000 calls**, and the project's own harness at **256 runs / 128,000 calls
  per invariant**. Both are *"no counterexample found in 128,000 calls"* — **absence of evidence,
  not proof of safety**. Only Halmos `[PASS]` would be a proof. Neither green result should be
  written up as "verified safe".
- **Medusa 1.5.1 is installed** but was not run. Reason stated plainly: the properties already fail
  deterministically under `forge` on the first run, with two independently replayable witnesses and
  a mutation control that flips them; a second stateful fuzzer adds no evidence to an
  already-falsified property, and the handlers depend on Foundry `vm.prank` to drive the dispatcher
  sweep. Echidna was not run for the same reason. This is a deliberate omission, not a degraded run.

---

## 6. Files

| Artefact | Path |
|---|---|
| Harness (**audit-authored**, not upstream) | `/home/justin/code/audits/workspace/phoenix-nft-staking/test/AuditInvariant_EconValueBound.t.sol` |
| Project harness re-run as control (upstream) | `/home/justin/code/audits/workspace/phoenix-nft-staking/test/BatchNFTMinterMultiTokenBudgetInvariant.t.sol` |
| Project PoC supplying the fixture (upstream) | `/home/justin/code/audits/workspace/phoenix-nft-staking/test/PoC_PaymentTokenCollision.t.sol` |
| This report | `/home/justin/code/audits/reports/phoenix-nft-staking/25/invariants.md` |

## 7. Invariant register

| id | name | type | maps to | runner | verdict |
|---|---|---|---|---|---|
| INV-25-01 | `invariant_NoAtomicProfitFromQualifyingBatch` | value conservation / no free value | ECON-001 (+ ECON-002, ECON-006) | forge | **FAIL** — counterexample `+160.000000 USDC` on a `50.000000 USDC` batch; fuzzer-found 3-call sequence `+9.995264 USDC` |
| INV-25-02 | `invariant_PotDoesNotGrowWithoutExplicitFunding` | monotonicity / accumulator routing | ECON-003 (+ ECON-005) | forge | **FAIL** — pot grew `0.882091 USDC` in one call; `71.999928 USDC` over 72 batches, monotone, 72/72 growth events |
