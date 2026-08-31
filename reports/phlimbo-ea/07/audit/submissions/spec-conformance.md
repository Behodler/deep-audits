# Spec-Conformance Report — phlimbo-ea-07 (Law 2: Faithfulness to Stories)

**Project:** phlimbo-ea
**Run:** phlimbo-ea-07
**Commit:** 7045a96
**Scope of this pass:** V3 subsystem — `src/PhlimboV3.sol`, `src/MigratorV2V3.sol` (the only code new at 7045a96). V1/V2 are unchanged and out of this faithfulness pass.

> **What this report is.** This is the Law-2 (story/spec faithfulness) channel. It documents places where the code deviates from what its `[story-NNN]` / NatSpec / `SolvencyDetermination.md` text says it does. It is deliberately kept **separate from the QA/gas bundle** — faithfulness is a distinct law, not a style or gas class.
>
> **Severity accounting (no double-counting).** Each deviation below is **Low-severity as a standalone spec-conformance item.** The underlying *security* impact of each is owned by a separate security finding (cross-referenced in each section). The spec-conformance entry contributes the "the documentation is wrong / the promised behavior does not hold" angle; it does **not** re-bill the security severity. Read the cross-referenced security finding for the exploit/DoS severity.

---

## F-01 — MigratorV2V3 story self-contradiction: the documented recovery path is unreachable while bricked

- **Contract / function:** `src/MigratorV2V3.sol` — `migrate` / `seedUsers` (reseed guard ~L114; reward-forward `safeTransfer` L187/L190/L193; `withdrawAll` L210-229)
- **Story / spec:** story-023 (contract-level NatSpec, HEAD 7045a96)
- **Standalone severity:** Low (faithfulness)
- **Security cross-reference:** **M-01 — MigratorV2V3 reverting-reward-recipient migration brick** (DEDUP-02). The DoS severity (Medium, owner-recoverable via redeploy) is owned there; prior-art ledger **V2-M-01** (same availability-DoS class on the retired V1→V2 migrator, different root cause). Law-1 note: **not** a fund-loss escalation — users retain their V2 positions and `withdrawAll` recovers stranded balances, so this is a recoverable liveness hazard.

**Spec text (quoted).** The NatSpec offers an in-contract operational escape from a reverting reward recipient:

> "Recovery note: reward forwarding uses safeTransfer, so a recipient that cannot receive the reward token (e.g. a blocklisted address) reverts the batch. As with MigratorV1V2, the operational escape is to exclude such addresses from the seed list (or deploy and re-wire a fresh migrator)."

The **same document** simultaneously forbids the action that "exclude from the seed list" requires:

> "once a pass has completed (migrateIterator == -1) the owner may call seedUsers again with a fresh straggler list. **Reseeding mid-pass is forbidden.**"

and the code enforces exactly that with the reseed guard (~L114):

> `require(!seeded || migrateIterator == -1)`

**Actual behavior.** The primary documented recovery — "exclude such addresses from the seed list" — is **unreachable while the migration is bricked**:

1. A `safeTransfer` of a positive reward delta to a frozen/blocklisted recipient reverts the whole `migrate` chunk (L187/L190/L193).
2. The cursor stays pinned at the offending index, so `migrateIterator` can **never** reach `-1`.
3. Re-seeding to exclude that address requires `migrateIterator == -1` (the L114 guard, restated by the NatSpec's own "reseeding mid-pass is forbidden") — which the brick itself prevents.
4. `withdrawAll` deliberately does **not** reset the pass (L210-229), so it cannot break the deadlock either.

The **only** recovery that actually works is the *secondary* escape parenthetically noted — deploy a fresh migrator and re-wire it via `setMigrator` on both V2 and V3 (a full redeploy).

**Deviation.** Spec self-contradiction: the documented in-contract recovery path is contradicted by the same document's mid-pass reseed prohibition and by the L114 guard. The story **overstates in-contract recoverability**; true recovery is only a full redeploy. Confidence: high.

---

## F-02 — PhlimboV3.batchClaim "the flush must never brick" principle is undermined by an unchecked `abi.decode`

- **Contract / function:** `src/PhlimboV3.sol` — `batchClaim` (banking L458-464) / `_tryTransfer` (L816-820, decode at ~L819)
- **Story / spec:** story-022 (Phase 3 + `batchClaim` NatSpec, ~L435) + `SolvencyDetermination.md` §4 (banked failed-transfer invariant)
- **Standalone severity:** Low (faithfulness / invariant-violation)
- **Security cross-reference:** **L-02 — `_tryTransfer` short-returndata `abi.decode` reverts and bricks the `batchClaim` chunk** (DEDUP-06). The DoS severity (Low, gated by the owner-vetted-promo-token trust assumption) is owned there. No ledger prior-art — `_tryTransfer` / `batchClaim` / the never-brick guarantee are V3-only constructs.

**Spec text (quoted).** The rotation state machine's flush is documented as un-brickable, precisely so a bad recipient cannot strand a promotion in `Flushing`:

> "Failed transfers (e.g. blocklisted recipients) are banked into `unclaimablePromo` — **the flush must never brick.**"

and the header design principle (L26-35) makes flush completeness load-bearing: rotation is a "cursor-guaranteed batchClaim flush."

**Actual behavior.** The never-brick principle is correctly implemented for outright transfer **failure**: `batchClaim` banks the staker's pending into `unclaimablePromo` (L458-464), and that banking logic is itself faithful. But the non-reverting primitive `_tryTransfer` (L816-820) does:

> `abi.decode(returndata, (bool))`  *(no length check)*

A promo token that returns **non-empty return-data shorter than 32 bytes** makes `abi.decode` **revert**. That revert propagates out of `_tryTransfer` and reverts the entire `batchClaim` chunk — bricking the very flush the invariant was designed to protect. `finalizePromotion` then cannot be reached (`flushCursor` can never advance past that staker), stranding the rotation in `Flushing` (with `unpause` also blocked while `Flushing`).

**Deviation.** The stated invariant "the flush must never brick" does **not fully hold**: it survives a *compliant* failing transfer (return `false` / revert cleanly → banked) but **not** a non-standard token that returns short, non-empty return-data. The banking design is faithful; the unchecked `abi.decode` edge case undermines it. Confidence: medium. Mitigating context: partner promo tokens are owner-vetted per promotion, which keeps the likelihood low — this is flagged here because it contradicts an explicitly documented design principle, not because it is a likely-to-fire exploit.

---

## DEDUP-03b — pauseWithdraw post-drain revert on V3 = the F-01 / V2-F-01 false-recovery-promise class (carryover)

- **Contract / function:** `src/PhlimboV3.sol` — `pauseWithdraw` (post-drain revert), compounding with `emergencyTransfer`
- **Story / spec:** story-008 HIGH-5 — the "safe pauseWithdraw exit after a drain" promise
- **Standalone severity:** Low (faithfulness / spec-conformance)
- **Ledger class (carryover):** ledger **F-01** (V1 `src/Phlimbo.sol`, status `acknowledged`) and ledger **V2-F-01** (V2 `src/PhlimboV2.sol`, status `open`, routed spec-conformance) — this is the **same false-recovery-promise class re-appearing on V3**.
- **Law-3 classification:** the owner drain via `emergencyTransfer` is a **KNOWING** owner action (trusted). This sub-part is therefore **not** a fresh H/M — it is the Law-2 spec deviation of story-008's safe-exit promise, tracked here for V3 continuity.
- **Distinct from:** the **new** security Medium **M-02 — emergencyTransfer leaves promo bookkeeping stale, bricking core functions on resume** (DEDUP-03a). M-02 is a separate, *non-obvious* owner footgun (Law 3, in-scope) on the promo-phase bookkeeping; DEDUP-03b is the KNOWING-action spec-conformance angle. **They compound in the same function but are distinct root causes — do not double-count.**

**Spec text (quoted).** story-008 HIGH-5 promises a safe user exit via `pauseWithdraw` even after an emergency drain. The faithfulness violation is that the promise does not hold once `emergencyTransfer` has swept the balance.

**Actual behavior.** After `emergencyTransfer` drains the contract, `pauseWithdraw` reverts for everyone (there is no balance to return), so the documented "safe pauseWithdraw exit after a drain" is not achievable — the exact deviation already recorded on V1 (ledger F-01) and V2 (ledger V2-F-01), now re-expressed on V3.

**Disposition.** Spec-conformance **carryover**, cross-referenced to ledger **F-01 / V2-F-01**. The sanitizer routed the primary/substantive V3 promo-stale footgun to M-02 (security) and split this pauseWithdraw-post-drain sub-part here to the spec-conformance channel per the F-01/V2-F-01 class. Owner KNOWING action ⇒ no fresh security label. Confidence: high.

---

## Verified-faithful (no deviation) — recorded for completeness

The story-faithfulness pass confirmed the following as FAITHFUL and raised **no** Law-1 story-unsafe override (documented here so a reader sees they were checked, not skipped):

- **story-023** — live-read chunked V2→V3 migration; reward-delta forwarding (each user gets exactly their V2-pending rewards, principal nets exactly, no cross-user contamination); straggler second pass forwards V3 auto-claimed rewards.
- **story-022** — None→Active→Flushing rotation state machine; `accPromoPerShare` is **never** reset across promotions (matches `SolvencyDetermination.md` 2.1).
- **story-022 / `SolvencyDetermination.md` §2** — phUSD reward minted on demand with no funded-budget cap. **Not a finding / not a Law-1 escalation:** this is the deliberate, explicitly documented mint-based solvency model (no pre-funded pool; solvency == active mint privilege; emission bounded by `totalStaked * desiredAPYBps / 10000 / SECONDS_PER_YEAR`). The only residual — `desiredAPYBps` having no upper bound — is owner-trusted magnitude (Law 3), tracked as the config-conditional item **DEDUP-04** (held under the shipped zero-APY default per KI-10; re-classify HIGH only if a non-zero-APY config ships), **not** an unsafe story.

---

## Cross-reference summary

| Spec-conformance item | Standalone severity | Security finding that owns the impact | Ledger prior-art / class |
|---|---|---|---|
| **F-01** (migrator recovery self-contradiction) | Low (faithfulness) | **M-01** (DEDUP-02) — migrator reverting-recipient brick, Medium (recoverable) | ledger **V2-M-01** (same availability-DoS class, retired V1→V2 migrator) |
| **F-02** (`batchClaim` "never brick" undermined) | Low (faithfulness) | **L-02** (DEDUP-06) — `_tryTransfer` short-returndata decode revert, Low | none (V3-only construct) |
| **DEDUP-03b** (pauseWithdraw post-drain revert) | Low (spec-conformance) | none new — owner KNOWING action (Law 3); distinct from security **M-02** (DEDUP-03a, promo-stale resume brick) | ledger **F-01** / **V2-F-01** (false-recovery-promise class) |

**Not double-counted:** F-01 / F-02 / DEDUP-03b carry only the faithfulness angle. Their security impact is billed once, on M-01 / L-02 / (DEDUP-03a M-02 for the compounding footgun) respectively.
