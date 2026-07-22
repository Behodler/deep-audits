# Plan — Reject duplicate `rewardTokens` entries in `BatchNFTMinterMultiToken`

**Target repo:** `phoenix-nft-staking` (audited as `lib/phoenix-nft-staking`, **read-only** here — implement upstream)
**Audited commit:** `c881a42` (`[story-022]`)
**Primary file:** `src/BatchNFTMinterMultiToken.sol` (`_snapshotRewards`, `:416-436`)
**Ledger entry:** `a62fe01a25e28fe7c327b65728e15408017525d9611a92d3363b7066c6c437ad` — label `M-02`, status **open**, severity **Medium**
**Author/decision:** owner (justin), 2026-07-21
**Status:** ready to pick up. Target file is **not deployed** — patchable now, which is the argument for landing it before it ships.

---

## 1. Decision

Reject a `rewardTokens` array that lists the same token more than once, with a dedicated error, inside
the existing `_snapshotRewards` loop and before any funds move.

The array is currently deliberately not deduped (`:258-266`, `:412-415`), on the stated grounds that a
duplicate "harms only the careless caller." **That reasoning is false**, and §2 shows why. This change
makes the contract's behaviour match what its documentation already claims.

---

## 2. Why — the "fails closed" defence is conditional, and the condition is attacker-chosen

`_snapshotRewards` takes one `balanceOf` **per listed entry**, so a token listed `k` times is
snapshotted `k` times against the same pre-loop balance. `_payRewards` then pays that snapshot `k`
times.

Let `P` = the prior pot at snapshot time, `D` = the reward-token donations this batch's own mints
generate during the loop.

| Step | Balance | Caller receives |
|---|---|---|
| pre-loop snapshot | `P` | — (`snapshot[0] = snapshot[1] = P`) |
| after mint loop | `P + D` | — |
| `_payRewards` i=0 | `D` | `P` |
| `_payRewards` i=1 | `D - P` | `P` (total `2P`) |

The second transfer succeeds **iff `D >= P`**. Below that it reverts and the batch rolls back — that is
the "fails closed" case, and it is why the defect reads as benign on inspection.

**The harm.** The second `P` is paid out of `D` — this batch's own donations, which the
snapshot-before-loop design (`:326-344`, `:390-399`) exists specifically to reserve for the *next*
claimant. So:

- the **next honest batcher** finds a pot of `D - P` instead of `D`;
- the incentive budget depletes faster than the design intends;
- the §4.2 property *"a caller cannot be paid out of their own batch's donations"* — the one the inline
  comments call "load-bearing" and pin with `test_OwnDonationsDoNotRefundToBatcher` — is broken.

The loss does **not** land on the duplicate-lister's own capital. This is not caller self-harm and must
not be triaged as "array hygiene."

### Evidence (run-21, executed against real source, not reasoning)

| Evidence | Result |
|---|---|
| `invariant_nudgeSolvency` (`tier3-invariants.md` §4) | **BROKEN**, reproducing across cold corpora |
| `invariant_nudgeNoSelfFund` (`tier3-invariants.md` §4) | **BROKEN**, reproducing across cold corpora |
| `PoC_DuplicateRewardWithDonations` (`poc-replay.md` §4.3) | **PASS** — defect reproduced |

Measured: `paid = 30,000,000` against `prePot = 15,000,000` (2× over-pay) at `count = 8`, `listLen = 2`;
a second cold corpus gave `36,000,000` against `18,000,000`, `excess = 12,000,000`.

⚠ Halmos corroborates but its harness is a hand transcription and carries **no authoritative weight**
(TG-4). The two invariants and the PoC are the authoritative evidence.

### Secondary consequence worth stating

Because the extra payment is funded from the caller's **own** donations, it acts as a rebate on their
own spend. With `batchDonationSize = 15`, a qualifying batch donates ~15% of its cost, so the duplicate
returns roughly that much — **lowering the effective cost of qualifying for the nudge.**

That matters beyond this entry: the `wont-fix` disposition of ledger `858e9e80…` (value-blind gate) and
`521c20ad…` (MEV race), both re-closed 2026-07-21, rest on the nudge being *loss-making to chase*
(~634 USDS qualifying cost vs a ~94.95 USDC pot at mainnet block 25577241). Those closures assume
nobody is exploiting this. It does not invert the relation on today's numbers, but it pushes toward it.

---

## 3. The change

`src/BatchNFTMinterMultiToken.sol` — new error alongside the existing ones (`:112-133`):

```solidity
/// @dev Reverted when `rewardTokens` lists the same token more than once.
///      A duplicate snapshots the same PRE-LOOP balance k times and pays it k
///      times, so the caller collects this batch's own donations — breaking the
///      §4.2 donate-forward property that reserves them for the next claimant.
///      Rejected outright rather than silently deduped, so the caller sees why
///      their array was refused. Fires before any funds move.
error BatchMint__DuplicateRewardToken(address token);
```

Inside the existing `_snapshotRewards` loop, immediately after the payment-token exclusion
(`:426-428`):

```solidity
 for (uint256 i; i < tokenCount; ++i) {
     address rewardToken = rewardTokens[i];
     if (rewardToken == paymentToken) {
         revert BatchMint__RewardTokenIsPaymentToken(rewardToken);
     }
+    for (uint256 j; j < i; ++j) {
+        if (rewardTokens[j] == rewardToken) {
+            revert BatchMint__DuplicateRewardToken(rewardToken);
+        }
+    }
     uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;
     // …unchanged
```

Properties preserved deliberately:

- **`_snapshotRewards` stays `private view`.** This is load-bearing: it is what makes
  `IERC20(rewardToken).balanceOf(...)` compile to a `STATICCALL`, so a caller-supplied "token" cannot
  reenter or mutate state on the read leg. Any fix that needs storage forfeits this.
- **Runs before any funds move**, same position in the normative order as the payment-token exclusion,
  so a rejected call pulls nothing and mints nothing.
- **Fires unconditionally**, including when `qualifies == false` — matching the payment-token guard, so
  a cheap sub-threshold call cannot be used to probe behaviour.

### Gas

O(n²) comparisons, which `:412-415` currently cites as the reason not to dedupe. The constant defeats
the label: each comparison is a couple of `MLOAD`s plus loop overhead, order ~30 gas. At 10 tokens that
is 45 comparisons ≈ 1.3k gas — well under 1% of a single ERC20 `transfer`. Honest callers list one or
two tokens, where the cost is nil.

---

## 4. Rejected alternatives

| Option | Why rejected |
|---|---|
| **Storage `EnumerableSet`** | OZ's `EnumerableSet` is mapping-backed and **cannot be instantiated in memory** — Solidity mappings are storage-only. The storage version forces `_snapshotRewards` to drop `view`, **losing the STATICCALL guarantee on the attacker-controlled read leg**, costs ~20k gas per cold `SSTORE`, and needs clearing or nonce-ing to avoid cross-call bleed. Functionally possible, strictly worse. |
| **Zero-pin later duplicates** (`available = 0` instead of revert) | Also correct, but silently changes what the caller's `minRewards[i]` means and can surface as a confusing `BatchMint__RewardBelowMinimum` instead of the real reason. Explicit error is more legible and equally fail-closed. |
| **Accumulate per unique token, then pay once** | Same O(n²) comparison cost, more code, and it *accepts* malformed input rather than refusing it. No benefit over rejecting. |
| **Re-read balances at payout instead of using the snapshot** | Would "fix" duplicates by accident and **reintroduce the self-funding round-trip** the snapshot exists to prevent (`:326-344`). Explicitly forbidden by the inline comments and by `test_OwnDonationsDoNotRefundToBatcher`. Do not do this. |
| **Leave as-is, document harder** | The documentation is already the source of the false model (§5). Documenting the same wrong claim more loudly does not close a broken invariant. |

---

## 5. Documentation that must change in the same commit

Two NatSpec passages currently assert the false "self-harm only" model and will re-seed it in the next
reader if left:

- **`:258-266`** (`batchMint` docs) — *"Duplicate entries both snapshot the same balance and the second
  transfer fails closed; … There is deliberately no dedupe pass — it would be O(n^2) gas charged to
  every honest caller to protect one careless one."*
- **`:412-415`** (`_snapshotRewards` docs) — *"Duplicate entries are NOT deduped (§4.5): both snapshot
  the same balance, the first transfer drains it and the second fails closed, harming only the careless
  caller."*

Both must state that duplicates are **rejected**, and that the old "fails closed" claim held only while
in-batch donations were below the prior pot. Update `docs/multi-token-nudge.md` §4.5 to match.

> This is the specific comment that produced the wrong conclusion during triage on 2026-07-21 — it was
> cited as a basis for treating duplicates as caller self-harm before the run-21 invariant evidence was
> checked. Leaving it in place would repeat that.

---

## 6. Verification (TDD — red → green → refactor, Foundry only)

Per `lib/phoenix-nft-staking/CLAUDE.md`: all work is TDD, Foundry only, no Hardhat/Truffle, and **no
`script/` directory may be added to this repo.**

Write the failing test first:

1. **Red** — `test_DuplicateRewardTokenIsRejected`: qualifying batch, `rewardTokens = [T, T]`, expect
   revert `BatchMint__DuplicateRewardToken(T)`. Must fail before the change.
2. **Regression witness** — a test configured **with non-zero in-batch donations** such that `D >= P`,
   asserting the caller receives exactly `P` (not `2P`) and the contract retains exactly `D`. This is
   the case the existing §6 witness never configures — see `Q-01` in §7.
3. **Negative control** — `rewardTokens = [A, B]` distinct: unchanged behaviour, both paid once.
4. **Order/position control** — duplicate present on a **non-qualifying** call (`count < nudgeSize`)
   still reverts, and reverts *before* any pull or mint (assert balances unmoved).
5. **Preserved property** — `test_OwnDonationsDoNotRefundToBatcher` must still pass untouched.

Then re-run the run-21 evidence and require it to flip:

- `invariant_nudgeSolvency` — must go **BROKEN → HOLDING** across cold corpora.
- `invariant_nudgeNoSelfFund` — must go **BROKEN → HOLDING** across cold corpora.
- `PoC_DuplicateRewardWithDonations` — PoC convention is **PASS = defect reproduced**, so after the fix
  this must **FAIL to reproduce** (the defect is gone). A PoC that no longer *compiles* is inconclusive
  bit-rot, not a fix.

Run cold (fresh corpora), not from a cached corpus — both invariants are reported as reproducing across
cold runs and a warm corpus can mask a re-break.

---

## 7. Scope boundary — what this does NOT fix

- **`src/BatchNFTMinter.sol` (frozen, mainnet-deployed) is unaffected.** It has no `_payRewards` and no
  caller-supplied `rewardTokens`, so this defect does not exist there. It is also unpatchable. No action.
- **DO NOT COLLAPSE with run-21 `M-02` / `c847207d…`** (missing `ReentrancyGuard` on the frozen deployed
  minter). Same arithmetic condition, **two independent routes, two different files** — a dedupe pass
  fixes one and not the other, and `nonReentrant` cannot be added to a frozen deployed file at all.
- **LINK, DO NOT MERGE with ledger `Q-01` `cabd4a3d…`.** That is the *test-coverage* defect — the §6
  witness never configures donations, which is why this went unnoticed. Distinct artifact, distinct fix,
  and item 2 in §6 above is what closes it.
- This does not touch the value-blind gate (`858e9e80…`) or the MEV race (`521c20ad…`), both `wont-fix`
  as of 2026-07-21. It only removes one route that quietly subsidises them (§2).

---

## 8. Ledger follow-ups

1. On landing + verification, propose `a62fe01a…` → `fixed` via `/ledger phoenix-nft-staking fixed a62fe01a`.
   **A human applies it** — `/analyze`, `/full-audit`, and `/recheck` may only *propose*.
2. **Correction owed on `990d8c37…` (`L-05`).** Its 2026-07-21 note asserts, as part of the wont-fix
   basis, that *"duplicate `rewardTokens` entries fail closed on the second `safeTransfer`."* That claim
   is **false as written** — it holds only when `D < P`. It must be struck and replaced with a pointer
   to `a62fe01a…`. The entry's other supporting facts (fake token defeats only the supplier's own floor;
   unconditional payment-token exclusion; STATICCALL read leg; `nonReentrant` payout) are unaffected and
   the `wont-fix` disposition stands.
3. `Q-01` `cabd4a3d…` closes on §6 item 2, not on this code change.
