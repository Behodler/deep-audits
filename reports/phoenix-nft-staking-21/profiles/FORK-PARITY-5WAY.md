# FORK-PARITY-5WAY — phoenix-nft-staking hand-maintained clone families

- Run: `phoenix-nft-staking-21`
- Submodule HEAD: `c881a42`
- Prior baseline: run-20 @ `0d1a0b2` (`FORK-PARITY-4WAY.md`)
- Watch note: `WATCH-17-maintenance-coupling-drift`, **now covering FIVE files across TWO
  families** (4 stakers + 2 batch minters, sharing `NFTStakerDepletion` ↔ nothing; the "5-way"
  name refers to the 5 clone *relationships*, not 5 files)

| Family | Files | Relationship | Status this run |
|---|---|---|---|
| **A — stakers** | `NFTStaker`, `NFTStakerPriceScaled`, `NFTStakerDepletion`, `NFTStakerPriceScaledMigrateReady` | 4 hand-maintained copies, 3 legs | **NO NEW DIVERGENCE** — all 4 byte-identical to run-20 |
| **B — batch minters** | `BatchNFTMinter` (frozen/deployed), `BatchNFTMinterMultiToken` | 2 copies, 1 leg, **NEW THIS RUN** | **SPLIT CLAIM VERIFIED CLEAN** |

---

## A. Staker family — no new divergence

### A.0 Byte-identity check vs the run-20 baseline

`sha256` of each file at `0d1a0b2` vs `c881a42`:

| File | run-20 | run-21 | Result |
|---|---|---|---|
| `src/NFTStaker.sol` | `7c3f4b76ca112836` | `7c3f4b76ca112836` | **IDENTICAL** |
| `src/NFTStakerPriceScaled.sol` | `f8ceab75c9b8d96a` | `f8ceab75c9b8d96a` | **IDENTICAL** |
| `src/NFTStakerDepletion.sol` | `30438e61c618cf5c` | `30438e61c618cf5c` | **IDENTICAL** |
| `src/NFTStakerPriceScaledMigrateReady.sol` | `6392fe9eea882537` | `6392fe9eea882537` | **IDENTICAL** |
| `src/INFTStakerMigratable.sol` | `86e33eab691a65a1` | `86e33eab691a65a1` | **IDENTICAL** |
| `src/INFTSupply.sol` | `60ca5a557e9dc87e` | `60ca5a557e9dc87e` | **IDENTICAL** |

(Truncated to 16 hex chars for readability; full digests reproducible with
`git show <rev>:<path> | sha256sum`.)

**Conclusion: zero staker-family churn this cycle.** Every leg-by-leg divergence table in
run-20's `FORK-PARITY-4WAY.md` §1–§3 carries forward **verbatim and unmodified**. Downstream
agents may treat those conclusions as axioms without re-derivation.

### A.1 Standing rule — RE-VERIFIED HOLDING

> **story-020's depletion rate/window fix must NOT be mirrored into the APY/runway copies.**

Symbol census at `c881a42`:

| File | `depletionWindowMonths` | `targetAPY` | Emission model |
|---|---|---|---|
| `NFTStaker.sol` | **0** | 16 | APY/runway |
| `NFTStakerPriceScaled.sol` | **0** | 16 | APY/runway + `priceScale` |
| `NFTStakerDepletion.sol` | 11 | 3 | linear depletion |
| `NFTStakerPriceScaledMigrateReady.sol` | **0** | 17 | APY/runway + `priceScale` |

**HOLDING.** The depletion-window machinery remains confined to `NFTStakerDepletion.sol`; no
APY/runway copy has acquired it. Since all four files are byte-identical to run-20, this is
guaranteed rather than merely observed.

### A.2 The `pns20h1` root-cause divergence is STILL LIVE in Family A

This is the one Family-A item that changed *status* this run, without any Family-A file
changing.

| Staker | `depositFor` pre-credit settlement | Line |
|---|---|---|
| `NFTStakerDepletion` | `pending = _safePay(pending)` → **pays `msg.sender`, i.e. the migrator** | `:756` |
| `NFTStakerPriceScaledMigrateReady` | `pending = _safePayTo(user, pending)` → pays the user | `:887` |

Full `_safePay` / `_safePayTo` census:

```
NFTStakerDepletion.sol                 _safePay: :549 :567 :582 :756   _safePayTo: :733
NFTStakerPriceScaledMigrateReady.sol   _safePay: :627 :652 :671        _safePayTo: :855 :887
```

The single divergent site is `Depletion:756` vs `PriceScaledMigrateReady:887`. Both
contracts' *migration-exit* path (`:733` / `:855`) correctly uses `_safePayTo(account, …)`;
only the `depositFor` **entry** path diverges.

**Status change this run:** story-023 fixed `pns20h1` **migrator-side**, not staker-side. The
divergence itself is untouched and remains in the source tree. Three consequences that
downstream must carry:

1. `NFTStakerDepletion` is deployed and immutable — this is the stated and legitimate reason
   for the migrator-side compensation (`NFTStakerMigrator.sol:37-46`).
2. **But the file is not marked frozen.** Unlike `BatchNFTMinter.sol` (which now carries a
   `DEPLOYED — FROZEN` banner at `:14-19`), `NFTStakerDepletion.sol` has no such marker. A
   *future fresh deployment* of `NFTStakerDepletion` inherits the `:756` bug, and any
   orchestrator that is not one of the two patched migrators is exposed. This is an
   **owner/maintainer footgun**, surfaced per Law 3: a competent maintainer redeploying the
   depletion staker would be surprised to inherit an already-audited High.
3. Recommendation for the report: either fix `:756` to `_safePayTo(user, pending)` (source-only
   change, deployed instance unaffected), or add a `DEPLOYED — FROZEN`-style banner naming
   `pns20h1`. The current state — a known-buggy line left unmarked in a live source tree with
   the fix living in a *different* contract — is exactly the maintenance-coupling hazard
   `WATCH-17` exists to track.

### A.3 Watch-note carry-forward

`WATCH-17-maintenance-coupling-drift` remains **ACTIVE** for Family A. Next run must:
- re-run the A.0 digest table;
- re-run the A.1 symbol census;
- re-check A.2 (`Depletion:756` still `_safePay`?), and if `depositFor` is edited on *either*
  clone, diff both.

---

## B. Batch-minter family — the story-022 Stage 7 split (NEW)

### B.0 The claim under test

Commit `fba4991` ("[story-022] Stage 7: split multi-token nudge out of the deployed
BatchNFTMinter") claims the change is a **"pure file/name split plus verbatim restore — no
design change"**. Two falsifiable sub-claims:

- **B1** — `src/BatchNFTMinter.sol` at HEAD is its state at `99a55ac` apart from one added
  `@notice`.
- **B2** — `src/BatchNFTMinterMultiToken.sol` at HEAD is body-identical to
  `src/BatchNFTMinter.sol` at `0d1a0b2` apart from the contract/`@title` rename.

### B1 — `git diff 99a55ac c881a42 -- src/BatchNFTMinter.sol`

**Result: exactly one hunk, six added lines, zero deletions, zero modifications.**

```diff
@@ -11,6 +11,12 @@ import {IPausable} from "pauser/interfaces/IPausable.sol";
 /// @title BatchNFTMinter
+/// @notice **DEPLOYED — FROZEN.** This file is the live, on-chain version of the
+///         batch mint helper and is kept here only so the deployed bytecode has
+///         matching source and a regression suite. Do NOT change it. All new
+///         nudge/reward work belongs in `src/BatchNFTMinterMultiToken.sol`, the
+///         caller-selected multi-token sibling described by
+///         `docs/multi-token-nudge.md`.
 /// @notice Helper that loops `ITokenMinterV2.mint(...)` `count` times in a single
```

`99a55ac` is `[story-022] Refresh stale .gas-snapshot baseline before multi-token nudge work`
— the last commit before Stage 1 (`447287a`). **B1 VERIFIED. The restore is genuinely
verbatim.**

### B2 — `diff BatchNFTMinter.sol@0d1a0b2  BatchNFTMinterMultiToken.sol@c881a42`

**Result: exactly two hunks, two changed lines.**

```diff
-/// @title BatchNFTMinter
+/// @title BatchNFTMinterMultiToken

-contract BatchNFTMinter is Ownable, Pausable, ReentrancyGuard, IPausable {
+contract BatchNFTMinterMultiToken is Ownable, Pausable, ReentrancyGuard, IPausable {
```

Both hunks are identifier renames. Every import, every state variable, every error, every
event, every modifier, every function body, and every comment is byte-identical. **B2
VERIFIED. No design change, no logic delta, nothing unannounced.**

### B3 — Function-by-function divergence table (frozen ↔ multi-token)

This table is the *design* divergence between the two live files, i.e. the delta the
multi-token nudge introduced back in Stages 3–5 (`2bf13cb`) and which Stage 7 merely relocated.
It is **intended divergence**, not drift.

| Element | `BatchNFTMinter` (frozen) | `BatchNFTMinterMultiToken` | Class |
|---|---|---|---|
| Inheritance | `Ownable, Pausable, IPausable` `:62` | `+ ReentrancyGuard` `:82` | **intended** — new caller-controlled callee |
| `nudgePaymentToken` state | `address public` `:87` | **REMOVED** | intended |
| `setNudgePaymentToken` | `:149` `onlyOwner` | **REMOVED** | intended |
| `NudgePaymentTokenChanged` event | `:111` | **REMOVED** | intended |
| `BatchMint__NudgeTokenMatchesPaymentToken` | `:98` (no args) | → `BatchMint__RewardTokenIsPaymentToken(address)` `:119` | intended |
| — | — | `+ BatchMint__ArrayLengthMismatch(uint256,uint256)` `:121` | intended |
| `BatchMint__RewardBelowMinimum` | `(uint256,uint256)` `:108` | `(address,uint256,uint256)` `:133` | intended |
| `batchMint` signature | `(uint256 count, address recipient, uint256 paymentAmount, uint256 minReward)` `:238` | `(uint256, address, uint256, address[] calldata rewardTokens, uint256[] calldata minRewards)` `:294` | **intended, ABI-BREAKING** |
| `batchMint` modifiers | `whenNotPaused` `:243` | `whenNotPaused nonReentrant` `:300` | intended |
| Nudge eligibility | `nudgeSize != 0 && count >= nudgeSize && nudgePaymentToken != 0` `:279` | `nudgeSize != 0 && count >= nudgeSize` `:352` — **token no longer owner-gated** | intended, **widened** |
| Payment-token exclusion | single check, `:260-263`, pre-pull, only when nudge configured | per-element, `:426-428`, pre-pull, **unconditional** even on non-qualifying calls | intended, hardened |
| `minReward` floor | checked **AFTER** the mint loop `:296` | checked **BEFORE** the pull and loop `:431` | intended (gas), see `BatchNFTMinter.md` LOCAL-101 |
| Reward snapshot | single `balanceOf` `:280` | `_snapshotRewards` loop `:416-436`, `private view` | intended |
| Reward payout | single `safeTransfer` `:301` | `_payRewards` loop `:452-461` | intended |
| `rescueERC20` | `:181`, described as "the missing escape hatch" | `:208`, explicitly documented as **unreliable / a race the owner usually loses** `:190-201` | intended, **materially weakened** |
| Steps 1–10 ordering | implicit | explicitly numbered `:301-387` | doc only |
| Constant `DUST_THRESHOLD = 1e6` | `:70` | `:90` | identical |
| Dust sweep logic | `:305-311` | `:381-387` | **identical** |
| Mint loop | `:286-288` | `:363-365` | **identical** |
| Approve/revoke ordering | `:284` / `:290` | `:360` / `:368` | **identical** |

**No unintended divergence found.** Every delta in the table traces to a story-022 stage
commit, and Stage 7 itself introduced none.

### B4 — Two design deltas that downstream must weigh (not drift, but scope)

1. **The owner's nudge-asset lever is gone.** The frozen contract let the owner pin exactly
   one payout asset (`nudgePaymentToken`); the sibling lets any qualifying caller name *any*
   ERC20 the contract holds (`rewardTokens`, `:38-41`). If the ledger carries an
   owner-accepted residual for the nudge front-run / over-funding class, that acceptance was
   granted against the *narrower* design. **Do not auto-suppress the class on the sibling
   under the old triage.** See `BatchNFTMinterMultiToken.md` §7.
2. **`rescueERC20` degraded from an escape hatch to a race.** Frozen: `:173-180` calls it "the
   missing escape hatch". Sibling: `:191-201` calls it "**NOT a reliable escape hatch** … a
   race the owner will usually lose", with "pause first, then rescue" as the only dependable
   sequence. This is honestly documented, but it is a **reduction in owner recourse** that the
   prior triage did not contemplate.

### B5 — Watch note (NEW)

`WATCH-21-batchminter-fork-drift` — **OPEN**. Two hand-maintained copies now exist with
identical mint/approve/dust logic. `BatchNFTMinter.sol` is frozen and must never change; any
future fix to the shared logic (the mint loop `:286`/`:363`, the approve/revoke ordering
`:284,:290`/`:360,:368`, or the dust sweep `:305`/`:381`) lands **only** on the multi-token
copy and creates a permanent, intentional divergence between source and deployed bytecode.
Next run must re-run B1 (`git diff 99a55ac HEAD -- src/BatchNFTMinter.sol` must stay a
single `@notice` hunk) and re-derive the B3 table.
