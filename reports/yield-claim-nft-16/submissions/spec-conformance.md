# Spec-Conformance / Faithfulness Report — yield-claim-nft

**Project:** yield-claim-nft
**Run:** yield-claim-nft-16
**Commit:** `f46a5cb7a90726215d49619ce76cb297f56e290a`
**Scan type:** COLD full scan — story-faithfulness (Law 2)
**Stories checked:** story-030, story-035, story-036, story-037, story-038, story-040, story-041, story-042, story-043, commit-924b188 (ratio raise)

---

## About this report (Law 2 — faithfulness to stories)

This document is the **faithfulness / spec-conformance** artefact and is governed by **Law 2** of the audit hierarchy (faithfulness to the `[story-NNN]` intent and NatSpec). It is deliberately **separate from the QA/gas bundle** (`qa-report.md`), which is a Law-3/quality artefact.

A faithfulness deviation that also carries **security or value impact** would additionally appear in an H/M submission report, with the `F-XX` record acting as its cross-reference. **Neither deviation in this run carries such impact** — both are informational/QA-grade — so this report stands alone with no companion H/M report.

**Run-16 produced no new Law-2 escalations.** This is a **re-confirmation** pass: every focus-area story (035/036/037/038/040/041/042/043) was verified FAITHFUL, and the two spec-conformance records below are pre-existing (one folds into ledger QA finding L-02, one is a carryover). No new `F-XX` label was minted.

---

## F-16-01 — `setRatio` NatSpec claims an exclusive cap but the code cap is inclusive (QA)

- **Severity:** QA (doc/code conformance)
- **Law impacted:** 2 (faithfulness)
- **Security / value impact:** **None** — protocol stays heavily over-backed either way
- **Ledger disposition:** **Folded into L-02** (fingerprint `5425119c…`) — this is **not a new label**, it is an L-02 echo. Cross-reference: ledger entry L-02 (`setRatio accepts ratio == MAX_RATIO, contradicting documented strict-less-than invariant`).
- **Contracts:** `src/hooks/BalancerPoolerMintDebtHook.sol` (setRatio, L77–82) and `src/hooks/UniboostMintDebtHook.sol` (setRatio, L95–101)

### Spec text (what the story/NatSpec says)

BalancerPoolerMintDebtHook NatSpec (L23/L42/L76), identical NatSpec on UniboostMintDebtHook (L30/L55/L95):

> "Exclusive upper bound on `ratio`. Max settable ratio is `MAX_RATIO - 1`."
> "@param newRatio Must be strictly less than `MAX_RATIO` (50)."
> field doc: "Strictly `< MAX_RATIO`."

story-030 body (git commit `c94bf40`):

> "ratio … strictly capped below MAX_RATIO = 50"

### Actual behavior (what the code does)

`setRatio` guards with:

```solidity
if (newRatio > MAX_RATIO) revert RatioTooHigh();
```

This **accepts `newRatio == 50`** (inclusive cap; max settable is 50, not 49). Furthermore, commit `924b188` ("raised ratio because sUSDS appreciation") raised `DEFAULT_RATIO` from **30 → 50** on both hooks **without touching the guard or the NatSpec** — so the **deployed default value itself equals `MAX_RATIO == 50`** and sits exactly on the inclusive boundary the NatSpec forbids. A strict-below-50 cap could not admit the default the protocol now ships.

### Resolution (which source is authoritative)

**CODE is authoritative.** The later commit `924b188` establishes the newest intent: a default ratio of 50 requires an inclusive `<= MAX_RATIO` guard, so the guard is faithful to current intent and it is the **NatSpec that is stale documentation**, never doc-synced when the default was raised. Contrast the sibling `NudgeRatchetMintDebtHook`, whose story-035 deliberately made **both** guard and NatSpec inclusive ("200 is accepted") — the two USDS/prime hooks were simply never brought into that sync.

**No security or value impact:** ratio 50 vs 49 mints phUSD at 50% vs 49% of prime dispatched; both are far below 100%, so the protocol is over-backed either way. Pure doc/code conformance nit. Recommendation: correct the stale NatSpec on both hooks to state the inclusive bound.

> The deduplicator mis-flagged this as a new label (`F-16-01`/`PATTERN-001`/`CODE-003`); the sanitizer reconciled all three under **L-02**, whose `lastSeenRun` was bumped 13→16. `NudgeRatchetMintDebtHook`'s NatSpec is self-consistent and is **not** part of this record.

---

## F-01-043 — story-043 solvency-window record (informational, carryover)

- **Severity:** Informational / OOS-under-DEDUP-001
- **Law impacted:** 2 (faithfulness) — Law-1 override evaluated and **does not fire**
- **Security / value impact:** **None in scope** (no unprivileged path); kept as a **visible** spec-conformance record per the Law-1 recall rule
- **Ledger disposition:** carryover (fingerprint `6753c76b…`), `lastSeenRun` 16; carryover stub written this run
- **Contract:** `src/dispatchers/NudgeRatchetDelayRelease.sol` (`_dispatch` / `release`, L108–143)

### Spec text (story intent)

story-043 (git commit `f46a5cb`):

> "Sibling of NudgeRatchet that HOLDS USDC on `_dispatch` (no transfer) … `onlyReleaser`-gated `release(amount)` forwarding held USDC to batchMinter … Mint-debt logic unchanged via the base hook."

In-source dev NatSpec (L20–34):

> "Debt/release timing is DECOUPLED ON PURPOSE. phUSD mint-debt accrues (and the downstream staker may realise phUSD via the hook's `pull()`) at DISPATCH time, while the USDC backing it can still be sitting on this contract, un-released."

### Actual behavior

The implementation is **FAITHFUL** to story-043 across all acceptance criteria:
- `_dispatch` is no-transfer (holds USDC on-contract);
- `hook.onDispatch` still accrues mint-debt against `amount` at dispatch time via the unchanged base hook;
- `release(amount)` is `onlyReleaser` + `nonReentrant` and `safeTransfer`s the held USDC to `batchMinter`;
- the `hookTypeId` marker guard is preserved.

**There is no conformance deviation.** This is recorded as a **story-unsafe review item**: the story's own intent creates an admin-controlled window in which phUSD debt is realizable (via `hook.pull()` minting) *before* the backing USDC has reached `batchMinter`.

### Law-1 override evaluation — DOES NOT FIRE

The backing USDC is **held on this contract from dispatch onward**; `release()` only **relocates** existing backing, so total system backing is conserved throughout the window. There is **no unprivileged path** to unbacked phUSD. The only way to break backing is the **trusted owner** calling `rescueERC20` to pull `_token` (the A4 footgun, a Law-3 owner action). Because no permissionless actor can violate the cross-contract backing invariant, this is **not a security escalation** and is correctly held **OOS under DEDUP-001** (the phUSD unbacked-mint boundary is an external protocol-token trust assumption, suppressed and auditable in the ledger).

Per the Law-1 recall rule (recall beats report-tidiness), the record is kept **visible** here rather than dropped.

---

## Confirmed INTENTIONAL — not a deviation: `hookTypeId` enforcement asymmetry

**Assessment: INTENTIONAL. Not a faithfulness deviation.**

Only 2 of 4 dispatchers (`NudgeRatchet` and `NudgeRatchetDelayRelease`) enforce the `hookTypeId` marker guard; `Uniboost` and `BalancerPoolerV2` do not. This asymmetry was assessed and is **by design**:

- **story-037 is explicitly scoped** — "Add … to `NudgeRatchet._dispatch`" — and story-043 inherited the same pattern. **No story mandates** that `Uniboost`/`BalancerPoolerV2` enforce hook-type binding.
- The `Uniboost`/`Balancer` debt hooks expose **no `hookTypeId()` function**, so symmetric enforcement is not even expressible without an interface change — consistent with the stories.
- The fail-open direction is **under-accrual** (a wrong/no-op hook ⇒ zero debt ⇒ protocol over-backed, never unbacked) — i.e. **safe**.

This is the pre-existing **L-09** operational footgun (Uniboost fail-open), **not** a new story-faithfulness finding and **not** a Law-1 escalation. (Note: L-09 stays distinct from the wont-fix **Q-08** BalancerPoolerV2 fail-open — different fingerprints/contracts, not merged.)

---

## Faithful confirmations (no deviation)

| Story | Contract(s) | Verdict |
|-------|-------------|---------|
| story-036 | `NudgeRatchetMintDebtHook` | FAITHFUL — 6-dp USDC scaled ×1e12 to 18-dp phUSD, floored; correct M-03 direction, no 1e30 magnitude trap; ctor hard-guards `decimals()==6` |
| story-037 | `NudgeRatchet`, `NudgeRatchetDelayRelease` | FAITHFUL — both require `hookTypeId() == keccak256("NudgeRatchetMintDebtHook.v1")`; 3 literal copies byte-identical at f46a5cb (drift-watch CLEAR) |
| story-038 | `NudgeRatchet` | FAITHFUL — full-balance sweep with `require(bal >= amount)` defense-in-depth; surplus = over-backing (safe) |
| story-040/041 | `Uniboost`, `UniboostMintDebtHook` | FAITHFUL — donation carve + gross-amount debt accrual + 3-step buy-and-pool; hook scale `10**(18-d)` prime-decimals-aware |
| story-042 | `MultiPooler`, `Uniboost` | FAITHFUL — 4-arg `pool(amountIn,…)` with `>0` + `<=balance` checks; MultiPooler atomic all-or-nothing `onlyPooler` batch |

---

## Summary

- **New Law-2 escalations this run:** 0
- **Faithfulness records surfaced:** 2 — **F-16-01** (QA doc/code, folded into ledger **L-02**) and **F-01-043** (informational, carryover, OOS-under-DEDUP-001)
- **Both are informational/QA** — neither carries security/value impact, so neither has a companion H/M report and this report stands alone
- **hookTypeId asymmetry:** confirmed **INTENTIONAL** (story-037 scoped to NudgeRatchet only), not a deviation
- All focus-area stories (035/036/037/038/040/041/042/043) verified **FAITHFUL**
- Every dispatcher fail-open direction is **under-accrual (over-backing)**; the only backing-breaking paths are trusted owner/releaser (Law-3). No new Law-1 escalation.
