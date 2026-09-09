# Spec-Conformance Report (Law 2 — Story Faithfulness)

**Project:** yield-claim-nft
**Commit:** aa86be6
**Run:** reports/yield-claim-nft/13/
**Stories checked:** story-040 (Uniboost dispatcher), story-041 (UniboostMintDebtHook)
**Date:** 2026-06-24

> This report covers **Law-2 faithfulness deviations only** — places where the
> implementation diverges from the intent expressed in its `[story-NNN]` commit,
> contract NatSpec, or the TDD test suite that serves as the de-facto acceptance
> spec in this repo. It is deliberately **separate from the QA bundle**: QA is
> gas/style/state-handling noise, whereas faithfulness is Law 2 and is reported
> **regardless of security severity**. None of the deviations below rose above
> Low/QA on the security axis, but each is documented here because a story said
> one thing and the code does another.

## Summary

- **story-040 (Uniboost dispatcher): FAITHFUL — no deviations.** Its detailed
  commit narrative (donation-split-then-retain `_dispatch`, authorized-pooler-gated
  `pool()` doing swap-prime→pair / ~half-pair→target / two-sided `addLiquidity`
  with LP accruing on-contract as POL, verbatim pooler-auth + `rescueERC20` copy
  from `BalancerPoolerV2`, minimal UniV2 interfaces, 54-test suite) is implemented
  clause-for-clause.
- **story-041 (UniboostMintDebtHook): 2 faithfulness gaps** — F-04-041 and
  F-05-041 — plus one NatSpec wording nit (L-02 facet). The hook's *scale math
  direction* and *>18-dp rejection* are faithful; the gaps are about **what the
  scale is bound to** and **whether the hook is actually invoked**.

### Law-1 override check: NO unsafe story intent

Per the law hierarchy, before reporting a faithful-but-deviating implementation we
must confirm no *story's own intent* would introduce an exploit (Law 1 over Law 2).
It does not:

- **Debt-on-gross convention** (debt accrues on the gross dispatched `amount` even
  though `donationSplit%` is forwarded out) is **explicitly documented** intent and
  **over-backs** phUSD relative to retained prime — the protocol is conservatively
  over-collateralised. Safe direction.
- **`addLiquidity(..., 0, 0, ...)`** zero min-amounts in `pool()` are bounded by the
  two upstream swap floors (`minPairOut`, `minTargetOut`) the authorized pooler
  chooses plus the post-call `require(liquidity >= minLP)`. The story asks for a
  bounded add, not an unprotected one; whether `minLP` alone is a sufficient
  sandwich floor is a code/econ question, not a story-intent question.

So Law 2 governs here, and the deviations are reported as faithfulness gaps.

---

## F-04-041 — "prime-decimals-aware" binds to an arbitrary ctor arg, not to the paired prime

**Story / spec text deviated from**

story-041 commit subject (`aa86be6`):

> [story-041] Add UniboostMintDebtHook with **prime-decimals-aware** phUSD debt accrual

Contract NatSpec (`UniboostMintDebtHook.sol:18-23`):

> Mirrors `BalancerPoolerMintDebtHook` exactly, but is **prime-decimals-aware**: the
> constructor reads `IERC20Metadata(primeToken_).decimals()` once and sets the
> immutable `scale = 10 ** (18 - decimals)`. This makes the hook correct for a
> 6-decimal prime (USDC/USDT, `scale == 1e12`), an 18-decimal prime … or any `<= 18`-dp prime.

The natural reading of "prime-decimals-aware … debt accrual" is a guarantee that
the hook's decimal scale matches the prime it actually accrues debt **against** —
i.e. the prime the paired Uniboost dispatcher dispatches.

**Actual behavior** (`UniboostMintDebtHook.sol:81-92`)

`scale` is derived from an **independent, unvalidated** constructor argument
`primeToken_`:

```solidity
constructor(address initialOwner, address dispatcher_, address phUSD_, address primeToken_) ... {
    ...
    uint8 d = IERC20Metadata(primeToken_).decimals();   // line 85
    require(d <= 18, "decimals>18");
    dispatcher = dispatcher_;                             // line 87 — separate, unrelated arg
    ...
    scale = 10 ** (18 - d);                               // line 89
}
```

`dispatcher_` and `primeToken_` are two distinct address parameters with **no
on-chain tie**. Nothing asserts `primeToken_ == Uniboost(dispatcher_).primeToken()`.
The hook is "aware" of *whatever* decimals the deploy-time `primeToken_` exposes,
not of the dispatcher's prime.

**Gap and consequence**

The story/NatSpec implies decimals-awareness is bound to the paired prime; the
code binds it to an arbitrary input. If a deployer passes a `primeToken_` whose
decimals differ from `dispatcher.primeToken()` (e.g. an 18-dp token while the live
Uniboost dispatches 6-dp USDC), `scale` is wrong and **every** accrual is
mis-scaled by `10^(±k)` for the life of the immutable. Direction matters: an
under-scale under-backs phUSD (protocol-favouring, safe); an over-scale
(`primeToken_` has *fewer* decimals than the real prime) over-accrues debt and
would over-mint phUSD on `pull()`. Because both args are same-typed addresses and
either is silently "valid," this is a **non-obvious owner footgun** (Law 3:
in-scope operational hazard, not "reckless admin").

**Remediation**

Read decimals live from `ITokenDispatcherV2(dispatcher).primeToken()` in the
constructor, or `require(primeToken_ == dispatcher.primeToken())` at construction
(and re-assert on `setDispatcher`). At minimum the deployment story must assert the
equality off-chain.

**Cross-reference:** appears in this run's QA as **L-10** (and code-scanner
LEAD-B). It did **not** rise above Low on the security axis, but is reported here
because story intent (awareness bound to the paired prime) and implementation
(awareness bound to an unbound ctor arg) diverge.

---

## F-05-041 — "debt accrues on every dispatch" is silently defeatable by a missing `setHook`

**Story / spec text deviated from**

story-041 commit subject (`aa86be6`): "… phUSD **debt accrual**" — debt accrues on
dispatch routed through the Uniboost dispatcher.

Contract NatSpec (`UniboostMintDebtHook.sol:11-17`):

> `IDispatchHook` implementation that accrues a phUSD *mint debt* **on every dispatch
> routed through a specific `Uniboost` dispatcher**.

There is also an established repo precedent: the sibling NudgeRatchet line carried
exactly this guarantee via a `hookTypeId` marker guard, added as the story-037 /
Audit **M-04** fix precisely because a silently-unwired hook bit it.

**Actual behavior** (`UniboostMintDebtHook.sol:124-136` + wiring)

`onDispatch` is gated to `dispatcher` (line 129, prevents external inflation) but
there is **no reciprocal guarantee** that the Uniboost dispatcher actually calls
*this* hook:

- Uniboost inherits `ATokenDispatcherV2`, whose hook **defaults to a no-op
  `DefaultDispatchHook`** and is only swapped by an owner `setHook()` call.
- Uniboost performs **no `hookTypeId` check** (unlike `NudgeRatchet._dispatch`,
  which requires `hookTypeId() == EXPECTED`).
- `UniboostMintDebtHook` exposes **no `hookTypeId()` marker at all** (neither the
  contract nor `IUniboostMintDebtHook` declares one).

So "debt accrues on every dispatch" holds **only if** the owner remembers to call
`Uniboost.setHook(uniboostMintDebtHook)`. If skipped, every dispatch buy-and-pools
prime while accruing **zero** phUSD debt — with no revert and no event. Both test
suites pass in isolation (dispatcher tests use `DefaultDispatchHook` / a mock; hook
tests call `onDispatch` directly), so the omission is not surfaced by CI.

**Gap and consequence**

The story's accrual guarantee is silently defeatable by a wiring omission the
system does not self-detect, and it **regresses the M-04 hardening precedent** the
repo already established for the same hook family. A non-malicious owner who
deploys the buy-and-pool dispatcher and forgets the separate `setHook` step would
be **surprised** that no phUSD debt accrued (the entire point of pairing the hook)
— non-obvious footgun, in scope as an operational hazard. Note neither story-040
nor story-041 *explicitly texts* a `hookTypeId` requirement, so this is a soft
faithfulness gap (under-delivery of the implied "on every dispatch" guarantee plus
regression of the M-04 precedent), not a hard text contradiction.

**Remediation**

Add a `hookTypeId()` marker to `UniboostMintDebtHook` + `IUniboostMintDebtHook` and
enforce it inside `Uniboost._dispatch` (mirroring `NudgeRatchet.sol:86-89`), or have
the deployment story assert `Uniboost.hook() == uniboostMintDebtHook`.

**Cross-reference:** appears in this run's QA as **L-09** (and code-scanner LEAD-A;
prior M-04 / story-037). Did **not** rise above Low on the security axis; reported
here as a Law-2 deviation regardless.

---

## L-02 (faithfulness facet) — `setRatio` accepts `ratio == MAX_RATIO` against "strictly <" NatSpec

**Story / spec text deviated from**

Contract NatSpec, `UniboostMintDebtHook.sol`:

> `MAX_RATIO` … "Exclusive upper bound on `ratio`. Max settable ratio is
> `MAX_RATIO - 1`." (line 30)
> `ratio` … "Percentage of dispatched prime that becomes debt. **Strictly
> `< MAX_RATIO`**." (line 55)
> `setRatio` `@param newRatio` … "Must be **strictly less than** `MAX_RATIO` (50)."
> (line 95)

**Actual behavior** (`UniboostMintDebtHook.sol:96-97`)

```solidity
function setRatio(uint8 newRatio) external onlyOwner {
    if (newRatio > MAX_RATIO) revert RatioTooHigh();   // line 97 — inclusive
    ...
}
```

The guard is `> MAX_RATIO`, so `newRatio == 50` (`== MAX_RATIO`) is **accepted**,
contradicting the NatSpec's "strictly `< MAX_RATIO`" / "max settable is
`MAX_RATIO - 1`" wording.

**Gap and consequence**

A pure comment/code wording mismatch (same one present in
`BalancerPoolerMintDebtHook`). **Zero security impact** — `ratio == 50` is still a
≤50% debt ratio and the accrual math floors safely. Documented here only so the
spec and code are reconciled; the fix is one character (`>=`) or a NatSpec
correction.

**Cross-reference:** appears in this run's QA as **L-02**. QA-level only; recorded
here as the faithfulness facet (spec text vs code wording).

---

## Notes

- story-041's commit body is a single subject line (no bulleted acceptance
  criteria), so intent was supplemented by the contract NatSpec and the TDD suite
  (`test/UniboostMintDebtHook.t.sol`) as the de-facto acceptance spec.
- Faithful-and-intended items (verified, not deviations): debt-on-gross over-backing
  convention (documented), scale-math direction + `<=18`-dp rejection (does **not**
  reproduce the M-03 sign-flip over-mint trap), and the full story-040 dispatcher
  narrative.
- Per Law 1 (recall over tidiness), both F-04-041 and F-05-041 are surfaced here in
  a visible channel even though their security severity ceiling is Low/QA; their
  value-impact severity is owned by code-scanner (LEAD-A/LEAD-B) and econ-scanner.
