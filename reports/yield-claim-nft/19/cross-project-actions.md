# Cross-Project Actions — yield-claim-nft run-19

- **Project:** `yield-claim-nft` @ `d4cc563264c7d57cf4c22e9ba561743484a305cd` (stories 046 / 047)
- **Source:** `sanitized-findings.md` → CROSS-PROJECT-ACTIONS (XP-01 … XP-05)
- **Status of this file:** **action items only.** Run-19 wrote **no other project's ledger**. Every item below still needs to be applied on the target project by a human or by a run scoped to that project. They are recorded here so nothing falls between two ledgers (Law 1).

| ID | Target project | Type | Required? |
|---|---|---|---|
| XP-01 | `phoenix-nft-staking` | mirror a live finding under the **same fingerprint** | **REQUIRED (Law 1)** |
| XP-02 | `phoenix-nft-staking` | anti-collapse note on an existing wont-fix | recommended |
| XP-03 | `stable-yield-accumulator` | lead / route-or-accept | recommended |
| XP-04 | `phoenix-nft-staking` | mis-credit guard note | recommended |
| XP-05 | `phoenix-nft-staking` | new entry in its own right | recommended |

---

## XP-01 — `phoenix-nft-staking`: mirror the run-19 H-01 root cause. **REQUIRED BY LAW 1.**

**Action.** File the upstream root cause on the `phoenix-nft-staking` ledger using the **same fingerprint** as the `yield-claim-nft` entry, so the two entries link rather than diverge:

```
fingerprint: d06e3191ca39615a9fd31804c64ec00c93abf55a7f81c190b5d03c1bd62f271a
basis:       BatchNFTMinterMultiToken.sol:batchMint:prime-token-nudge-token-collision-ungated-dust-sweep
contract:    src/BatchNFTMinterMultiToken.sol
function:    batchMint (:479-486), _snapshotRewards (:558)
```

**Substance.** The step-10 dust sweep is **not gated on `qualifies`**, so with `count = 1 < nudgeSize = 5` the whole accumulated nudge pot leaves via the dust refund. The mint is funded out of the pot itself (step-6 unbounded allowance), so the caller needs no budget of their own.

**PoC.** `workspace/yield-claim-nft/test/run19-Tier3Nudge.t.sol::Run19_T1_PaymentTokenCollision` — 4/4 pass.

**Upstream remedy.** Gate the step-10 dust sweep on `qualifies`, or exclude nudge-whitelisted balances from it. **No line of `yield-claim-nft` changes in any candidate remedy** — which is exactly why the primary filing belongs upstream.

**Why this is required, not optional (Law 1, MR-03).** The finding is live on the `yield-claim-nft` ledger *only as an integration-hazard cross-reference* (this repo's three USDC-prime dispatchers manufacture the reachability). It must remain live on **at least one** ledger at all times. Mirroring is required; disappearing is not an option. If a triager later closes the `yield-claim-nft` cross-reference on the grounds that "the root cause is upstream", the upstream entry must already exist.

**Prior-decision disclosure (do not read this as an override).** Two `phoenix-nft-staking` entries are `wont-fix` on adjacent sweep behaviour — `fcaca00259…` (run-20 M-01, step-10 whole-balance sweep) and `7a1718e9a9…` (run-21 M-01, `paymentAmount = 0` free-mint + whole-balance sweep). Both carry the operator's own exemption, quoted verbatim:

> **"THIS IS NOT AN ACCEPTANCE OF THE CONSTRUCT ON THE UNDEPLOYED TWIN."**

This run-19 root cause lives on exactly that undeployed twin (`BatchNFTMinterMultiToken.sol`). Filing it is therefore a **re-file into a gap the owner's decision explicitly left open**, not an override of a wont-fix. Attach this disclosure to the upstream entry.

**Related upstream entries.** `2d34673536…` (L-04, **open** Low — "streamer flush ignores the runtime payment-token skip → streamed buffer leaks to caller via step-10 sweep"): run-19's H-01 is a **re-weigh** of that open Low, upward, because this repo's dispatcher topology supplies the reachability it was missing. `fb17fc6d07…` (M-06, **open** Medium — nothing ties `dispatcherIndex`'s `primeToken` to the contract's funding assets) is the owner-side arming mechanism for the precondition.

---

## XP-02 — `phoenix-nft-staking`: do **not** let `858e9e80…` absorb run-19 M-05

**Action.** Add a note to `phoenix-nft-staking` entry `858e9e80…` (H-01, `wont-fix`, value-blind nudge gate) recording that a **sibling instance of the same MEV class exists on `yield-claim-nft`** as ledger `M-05` (`e6fbf0d6…`, `NudgeRatchetDelayRelease.release()` back-run).

**Why.** Same class, **different contract, different repo, different fingerprint**. Without the note, a future triager can close both with one decision and silently dispose of an untriaged Medium. The `yield-claim-nft` M-05 entry already carries the reciprocal `doNotCollapse` field.

---

## XP-03 — `stable-yield-accumulator`: unbuffered nudge split (MR-04 lead)

**Action.** Route as a lead to the `stable-yield-accumulator` ledger, **or** accept as intended — but record the decision either way.

**Substance.** `StableYieldAccumulator.claim()`'s 30% `nudgeSplit` still pays the batch-minter **directly and unbuffered**. A `claim()`-funded spike into the same nudge pot is therefore instantaneously capturable by the next 40-batcher. The stories 046/047 anti-burst throttle covers **one of two** funding sources.

**Why recorded.** So the streamer mitigation is not miscredited as protocol-wide.

---

## XP-04 — `phoenix-nft-staking`: mis-credit guard (CV-09)

**Action.** Record on the `phoenix-nft-staking` ledger that the `NudgeStreamer` is a **rate cap (delay, not denial)**, not a value cap.

**Substance.** A flush yields `min(elapsed / D, 1) · buffer`, and the batch-minter then snapshots its **whole balance**, winner-take-all. **Do not read the run-19 range as closing any pre-existing `phoenix-nft-staking` nudge over-funding / aggregate-pot finding.**

**Law-2 status.** Clean — story-faithfulness confirms no NatSpec line, story line or `CLAUDE.md` text claims the streamer is a value cap, so there is no faithfulness defect here. The risk being guarded against is **mis-credit on the other ledger**, which is real.

---

## XP-05 — `phoenix-nft-staking`: `NudgeStreamer` has no owner rescue

**Action.** Worth an entry on the `phoenix-nft-staking` ledger in its own right.

**Substance.** `NudgeStreamer` has **no owner rescue path**, verified exhaustively against its complete function list: `registerStream`, `collectNudge`, `pullPendingStream`, `pendingStream`, `_settle`, `_accrued`.

**Why it matters here.** This absence is the **load-bearing precondition** of two run-19 `yield-claim-nft` findings: `M-06` (`25a9ab3e…`, stream-retirement stranded buffer) and the `test_T2d` leg of the `L-08` expired closure (blacklisting the streamer permanently strands already-buffered pooled funds). If a rescue path is ever added upstream, both weaken — and both should be re-checked.

> **Caveat carried from run-19's `M-06` reclass:** the *permanence* claim was disproved twice on the `yield-claim-nft` side (`NudgeStreamer.sol:118-119` settles before reset, so a double `registerStream(old, token, 1)` recovers the buffer; and `val-M03-terminal-reversal.t.sol` shows the pointer setters carry no one-way lock). XP-05 is about the **absence of a first-class owner rescue**, not about permanent loss.
