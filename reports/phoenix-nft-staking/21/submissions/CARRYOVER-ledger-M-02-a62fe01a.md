<!--
ID: a62fe01a (ledger fingerprint — this record mints NO new finding ID and NO run-21 M-nn label)
C4 Submission Metadata — STILL-OPEN LEDGER CARRYOVER (Medium), new executed evidence this run
Title: Duplicate `rewardTokens` entries pay the same pre-loop snapshot k times — the "fails closed" defence is conditional on zero in-batch donations
Record kind: CARRYOVER. NOT a new finding. NOT a regression. NOT labelled M-nn in this run's sequence.
Project: phoenix-nft-staking
Run: phoenix-nft-staking-21 @ c881a428c87ef4ef42ba07a71be5d49101c9006d
Ledger fingerprint: a62fe01a25e28fe7c327b65728e15408017525d9611a92d3363b7066c6c437ad
Ledger label: M-02   ·   Ledger status: open   ·   Severity at HEAD: medium — UNCHANGED
Classified as: CLASS-21-017 (originalId DEDUP-21-003)
Contract at HEAD: src/BatchNFTMinterMultiToken.sol (_snapshotRewards / _payRewards)
Root Cause Link: https://github.com/Behodler/phoenix-nft-staking/blob/c881a428c87ef4ef42ba07a71be5d49101c9006d/src/BatchNFTMinterMultiToken.sol#L452-L461
Evidence: tier3-invariants.md §4 · poc-replay.md §4.3
-->

**Severity: Medium — unchanged.** **Ledger label `M-02`. No new run-21 label is minted.**

> **⚠ Why this record exists.** This entry is an **open ledger Medium** whose evidence was **upgraded
> this run from reasoning to executed counterexamples**. Prior to this run it appeared in `submissions/`
> only as a passing cross-reference. It is written up here so a reader sees the new evidence without
> having to open `classified-findings.json`.

> **⚠ Label-collision guard.** This is **ledger `M-02` = `a62fe01a…`**. It is **not** run-21's `M-02`
> `c847207d…` (missing `ReentrancyGuard` on the frozen deployed minter). Disambiguate by fingerprint,
> never by label.

## Finding description and impact

### The defect (unchanged at HEAD)

1. `rewardTokens` is **deliberately not deduped** — documented at `:258-266` and `:412-415`.
2. `_snapshotRewards` takes one `balanceOf` **per listed entry**, so a duplicated token is snapshotted
   `k` times.
3. `_payRewards` then pays that snapshot `k` times.
4. The *"fails closed"* defence holds **only when there are zero in-batch donations**. With donations at
   or above the prior pot it does **not** fail closed, and the caller is paid out of **their own batch's
   donations**.

### ⚠ New this run — executed, against real source

Previously argued from reasoning; now reproduced:

| Evidence | Result |
|---|---|
| `invariant_nudgeSolvency` (tier3-invariants.md §4) | **BROKEN**, reproducing across cold corpora |
| `invariant_nudgeNoSelfFund` (tier3-invariants.md §4) | **BROKEN**, reproducing across cold corpora |
| `PoC_DuplicateRewardWithDonations` (poc-replay.md §4.3) | **PASS** — defect reproduced |

Measured: `paid = 30,000,000` against `prePot = 15,000,000` — a **2× over-pay** — at `count = 8`,
`listLen = 2`. A second cold corpus gave `paid = 36,000,000` against `prePot = 18,000,000`. The spec §4.2
property *"a caller cannot be paid out of their own batch's donations"* is broken with
**`excess = 12,000,000`**.

⚠ Halmos corroborates but its harness is a hand transcription, so it carries **no authoritative weight**
here (TG-4). The two invariants and the PoC above run against the **actual contract** and are the
authoritative evidence.

### Why it remains Medium and not High

**The attacker fully controls the precondition** — they list the duplicate themselves — so the bound is
**not reachability**. What bounds it is **magnitude**: extraction is capped by the pot, i.e. by what the
contract holds at snapshot time plus the batch's own donations. A value leak bounded by the pot is a
Medium; it is not theft of an unbounded balance. Severity is **unchanged from the ledger**, not re-rated.

## Recommended mitigation steps

### 1. Code

Dedupe `rewardTokens` on entry, or accumulate per unique token address before paying, so a snapshot can
be paid at most once.

### 2. Ledger hygiene — relocation only, and do not collapse

- **PURE RELOCATION (PLA-07)** — re-anchor `a62fe01a…` to
  `src/BatchNFTMinterMultiToken.sol:_payRewards:452`. `_payRewards` no longer exists on the frozen file,
  so this is the **same defect at a new address: not a new finding, and NOT a fix.**
- **LINK, DO NOT MERGE** with ledger `Q-01` `cabd4a3d…` — the §6 witness never configures donations; that
  is the **test-coverage** defect, a distinct artifact with a distinct fix.
- **DO NOT COLLAPSE** with run-21 `M-02` / `CLASS-21-002` (`c847207d…`): same arithmetic condition, **two
  independent routes, two different files**. A dedupe pass fixes one and not the other, and
  `nonReentrant` cannot be added to a frozen deployed file at all.
