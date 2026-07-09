# L-01 (run-19 consolidation) — CORRECTED adjudication

**Finding:** `InPlaceNFTStakerMigrator` immutable `stakedId` has no live-parity assertion against the staker's owner-mutable `stakedId()`. Consolidates into open run-18 **L-01** as the *post-deploy `setStakedId`-reissue* strand (run-18 L-01 = the *deploy-time mis-wire* strand; same root cause: immutable `stakedId` never asserts parity with `staker.stakedId()`).

**Severity: Low (CONFIRMED by severity-auditor via source trace; not Medium).**

## Corrected mechanics (supersedes code-scanner CODE-005 / DEDUP-19-004 narrative)

The code-scanner's original impact claim — "a `setStakedId` reissue kills `claimTimedOut` and voids the `rescueERC1155` `totalParked` floor" — is **WRONG-DIRECTION**. Verified against source (`src/InPlaceNFTStakerMigrator.sol` L242-289, `src/NFTStakerDepletion.sol` L748-768):

- The physically-parked ERC1155 units are `oldId`. `migrator.stakedId` is **immutable** = `oldId`, fixed at construction. They stay aligned forever.
- `setStakedId(newId)` is gated `onlyOwner` + `totalStaked == 0`, so it can only fire *after* all users are parked (during migration `totalStaked > 0` ⇒ it reverts). What drifts is only `staker.stakedId()` → `newId`.
- **`claimTimedOut` (L254)** transfers `migrator.stakedId` = `oldId` → matches parked tokens → **WORKS. Escape hatch intact.**
- **`rescueERC1155` (L283-284)** floors against `balanceOf(this, migrator.stakedId)` = `balanceOf(oldId)` vs `totalParked`; parked tokens are `oldId` → **floor guards the correct balance → INTACT.**
- **`migrateIn` → `staker.depositFor(user, amt)` (staker L760)** pulls `stakedToken.safeTransferFrom(migrator, staker, staker.stakedId()=newId, amt)` from the migrator, which holds only `oldId` → **REVERTS.**

## Actual impact

The **owner's `migrateIn` re-injection path bricks** after a mid-migration `setStakedId` reissue. This is the *only* real consequence. Fully mitigated: parked users self-rescue via the permissionless `claimTimedOut` after `migrationTimeout` (1–30 days). No theft, no permanent principal loss, no permissionless griefing, no floor void, no hatch kill. → **Low** (visible operator footgun, owner-recoverable).

## CORRECTED remediation (the original proposal is HARMFUL)

- **DO NOT** switch `claimTimedOut` / `rescueERC1155` to read `staker.stakedId()` — that would break the currently-working hatch and floor (the migrator holds `oldId`, not `newId`).
- **DO** assert `migrator.stakedId == staker.stakedId()` at the entry of `migrateIn` (fail-loud before the re-injection loop), **or** prevent `setStakedId` on the staker while `totalParked > 0` at the migrator, **or** add a migrator-side guard that blocks the reissue window while parked stake is outstanding.

## Ledger note (re-audit trap)

Run-18 L-01's current/proposed fix is a **constructor cross-check**, which passes at deploy then drifts on a later `setStakedId`. A constructor-only patch must **NOT** be auto-flipped to `fixed` — the dynamic strand requires a live parity assert at `migrateIn` (or a `totalParked>0` reissue guard). Record incomplete-fix / re-audit trap on the L-01 ledger entry.

## Cross-check: NFTStakerMigrator (Q-01 / DEDUP-19-005)

Distinct contract, distinct failure mode: its dead `stakedId` immutable is never referenced by `migrate()`; a mismatch is a clean atomic revert-and-rollback (no fund risk). Stays QA. Kept separate from L-01.
