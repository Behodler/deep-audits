# Spec-Conformance Report (Law 2 — Story Faithfulness)

**Project:** yield-claim-nft
**Commit:** f46a5cb
**Run:** reports/yield-claim-nft-15/
**Stories checked:** story-043 (NudgeRatchetDelayRelease dispatcher)
**Mode:** regression
**Date:** 2026-06-27

> This report covers **Law-2 faithfulness only** — places where the implementation
> diverges from the intent expressed in its `[story-NNN]` commit, contract NatSpec,
> or the TDD test suite that serves as the de-facto acceptance spec in this repo
> (`lib/yield-claim-nft/docs/` does not exist; contract NatSpec is treated as the
> authoritative spec). It is deliberately **separate from the QA bundle**: QA is
> gas/style/state-handling noise, whereas faithfulness is Law 2 and is reported
> **regardless of security severity**. Per Law 1 (recall over report-tidiness), any
> plausibly-security-relevant note is surfaced here in a visible channel rather than
> buried in a scan log — see F-01-043 below.

## Summary

- **story-043 (NudgeRatchetDelayRelease): FAITHFUL — 0 deviations.** All six
  acceptance criteria pass. The contract is a faithful sibling of `NudgeRatchet`
  whose only intended diffs (hold-on-dispatch vs sweep, the `release(amount)` path,
  the `releasers` whitelist, and the `rescueERC20` hatch) match the `f46a5cb`
  commit body and the NatSpec header clause-for-clause.
  - HOLDS USDC on `_dispatch` (no forward) — `_dispatch` is `view`, no transfer/sweep. PASS
  - Releases only via whitelisted `release(amount)` (`onlyReleaser nonReentrant`). PASS
  - Mint-debt side UNCHANGED from `NudgeRatchet` (`hook.onDispatch` accrues `amount*1e12`). PASS
  - Owner controls `batchMinter` + `releasers` whitelist (`onlyOwner`, non-zero guard). PASS
  - USDC 6-decimal deploy guard in constructor. PASS
  - M-04 hook-type guard preserved (default/wrong hook revert loudly). PASS
- **Test conformance: STRONG.** Every claimed behaviour has at least one positive
  and, where applicable, negative test, **including the M-04 default-hook /
  wrong-hook revert pair** that the prior silent-gap lesson (story-037 / Audit M-04)
  demands, plus an end-to-end integration test (NFTMinterV2 → dispatcher held →
  release). No regression of the M-03 (1e12 decimal scaling) or M-04 (hook-type
  guard) guarantees — scaling lives in the unchanged hook; this dispatcher does no
  arithmetic.

### Law-1 override check: ONE story-design note recorded (F-01-043)

Per the law hierarchy, before blessing a faithful implementation we must confirm no
*story's own intent* would introduce an exploit (Law 1 over Law 2). story-043 is
faithful, but its **intended** debt/release decoupling raised a Law-1 escalation
candidate. It was routed to and **resolved by** econ-scanner as out-of-scope under
the existing ledger suppression DEDUP-001. It is recorded below in full so the
suppression stays auditable and visible — not as a security Medium.

---

## F-01-043 — Intended debt/release decoupling (story-unsafe note; RESOLVED out-of-scope)

**Classification:** story-unsafe note, **NOT** a security finding. Faithful code;
the question is about the story's *own* design, escalated under Law 1 and resolved.

**Story / NatSpec intent text deviated-toward**

The contract's NatSpec header makes the decoupling an explicit, accepted design
property (`src/dispatchers/NudgeRatchetDelayRelease.sol:20-36`):

> KNOWN / ACCEPTED DESIGN PROPERTIES — these are intentional; DO NOT re-flag as findings:
>   * Debt/release timing is DECOUPLED ON PURPOSE. phUSD mint-debt accrues (and the
>     downstream staker may realise phUSD via the hook's `pull()`) at DISPATCH time, while
>     the USDC backing it can still be sitting on this contract, un-released. There is
>     therefore an intended, admin-controlled window in which phUSD has been realised but
>     the corresponding USDC has NOT yet reached the batchMinter. This is the whole point
>     of the contract (rate-controlled release), not an accounting bug.
>   * No unbacked phUSD is created by this. The USDC that backs the accrued debt is HELD on
>     this contract from dispatch onward; `release` only RELOCATES that existing backing to
>     the batchMinter (it never mints or burns), so total system backing is conserved at
>     all times. The only thing the release schedule changes is WHERE the backing sits
>     (dispatcher vs. sink), never WHETHER it exists.
>   * Release rate is a trusted admin lever. `release` is gated to an owner-managed
>     `releasers` whitelist; the owner deliberately controls how fast held USDC flows to
>     the batchMinter. Slow/withheld releases are an operational choice, not a liveness bug.
>   * `rescueERC20` can withdraw held `_token` (USDC). This is an accepted owner power with
>     the same trust assumption as `setBatchMinter`; see its NatSpec.

**Actual behavior** (`_dispatch` L131-143 + `release` L108-111)

The implementation faithfully realises the decoupling: mint-debt accrues against
`amount` in `hook.onDispatch` at dispatch time (base `ATokenDispatcherV2.dispatch`,
unchanged), while the backing USDC is held on the dispatcher and can only be moved
to the `batchMinter` sink by a whitelisted releaser calling `release(amount)` at an
admin-controlled rate. There is no implementation-vs-intent gap.

**The Law-1 escalation that was raised**

story-faithfulness flagged the *story's own* safety argument. The NatSpec rests on
"total **system** backing is conserved" (USDC exists somewhere), but the solvency
invariant relevant to a holder who has *realised* phUSD is "the **sink** the claim
redeems against is funded when the claim is realised." During the intended hold
window, phUSD can be realised via `hook.pull()` while the `batchMinter` sink holds
**0 USDC**, and the dispatcher-held USDC is unreachable to anyone but the releaser —
a transient (and, if releases lag, unbounded) under-funded-sink window set by an
admin lever. This is **not** the `rescueERC20` owner-footgun (an acknowledged Law-3
owner power, out of scope): the window exists under *normal* operation of the core
feature even with a benign releaser, because realisation and sink-funding are
separated by design.

**econ-scanner resolution — OUT OF SCOPE (DEDUP-001)**

econ-scanner resolved the escalation: **no in-scope contract couples
USDC-at-`batchMinter` to phUSD minting or redemption.** The phUSD redemption-backing
model is the **external** one already suppressed in the ledger as **DEDUP-001
(owner-driven external backing / unbacked-phUSD)**. The under-funded-sink concern
only bites if phUSD redeems specifically against the `batchMinter` sink's
instantaneous USDC balance; within the audited boundary it does not, and prior
Tier-3 work (run-13) showed the NudgeRatchet/hook path runs ≥2:1 over-backed with no
over-mint (double-mint/under-backing REFUTED). The implementation faithfully
realises the story, and the story's own design is acceptable **within the audited
boundary**. Recorded here, not promoted to a Medium.

---

## Test-coverage notes (informational — behave as designed, NOT violations)

story-faithfulness flagged two untested claims. Both paths behave exactly as their
NatSpec describes and are recorded as coverage notes, **not** faithfulness findings
— unlike the M-04 unwired-hook case, where the untested path was actually broken.

1. **`rescueERC20` never exercised against the real `_token` (USDC).** Every
   `rescueERC20` test rescues a stray `Mock18Decimals`; none rescues the actual
   `_token`, so the single most safety-relevant property the NatSpec asserts (L115-117:
   that it CAN drain live backing and "can leave debt under-backed") is documented but
   never tested. `rescueERC20` is a plain `safeTransfer` that works identically
   regardless of token, and draining live backing is an **accepted owner power (Law 3)**,
   so a test would not surface a hidden bug. Coverage note only.

2. **Intentionally-omitted `bal >= amount` path untested.** `_dispatch` deliberately
   omits the sibling's defensive `balance >= amount` require (NatSpec L128-130) —
   debt accrues against `amount` whether or not USDC was actually deposited, by design,
   trusting `NFTMinterV2` to `transferFrom` exactly `price*qty` before `dispatch`. No
   test dispatches with `amount` > deposited USDC to exercise the absent guard; all
   tests pre-mint `USDC == amount`. The omission is **intentional and faithful** (this
   contract holds rather than sweeps), so it is not a deviation from story-043 — flagged
   only so downstream interaction/econ analysis carries the minter-trust assumption
   forward.

---

## Notes

- story-043's commit body plus the detailed NatSpec header (L11-36, enumerating the
  KNOWN/ACCEPTED design properties) and the TDD suite served as the de-facto
  acceptance spec; **no acceptance criteria were invented** — `lib/yield-claim-nft/docs/`
  does not exist and CLAUDE.md carries no story-043 feature spec.
- Faithful-and-intended items (verified, not deviations): hold-vs-sweep `_dispatch`,
  the `release` relocate-only semantics with backing conservation across partial
  releases, the `releasers` whitelist, the USDC 6-dp deploy guard, the preserved M-04
  hook-type guard, and the unchanged `amount*1e12` mint-debt accrual via the hook.
- F-01-043 is surfaced here in a visible channel per Law 1 (recall over tidiness)
  even though it resolves out-of-scope; its suppression rationale (DEDUP-001) is
  recorded so it can be re-litigated if a future story ever couples phUSD redemption
  to the `batchMinter` sink balance.
