# Carryover Spec-Conformance report — originating audit 15 (carried into yield-claim-nft-22)

> **Carryover Spec-Conformance report — audit 15** (pruned copy of `yield-claim-nft/reports/15/submissions/spec-conformance.md`, taken from the run-21 pruned carryover `reports/21/submissions/carryover/spec-conformance-15.md`, re-checked against the ledger at run 22. Faithfulness (Law-2) records belong to the spec-conformance channel, not the QA bundle). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **F-01-043**.
> Removed as no longer live: **none since run 21**.
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | F-01-043 | — | `6753c76b07091ec7c0cfa05e4bde4c307ce6d4a82e10c9c8445eb8e8e9bf4268` | `open` | yield-claim-nft-15 | yield-claim-nft-16 | no (carried; code unchanged) | `src/dispatchers/NudgeRatchetDelayRelease.sol` |

<details><summary>Provenance notes from the run-21 carryover header (kept verbatim: label-collision warnings, facet and instance notes)</summary>

> Pruned copy of `yield-claim-nft/reports/15/submissions/spec-conformance.md` (commit `f46a5cb`), carried at `267660b`. Retained (still `open`): **F-01-043**. Removed: none; summary, test-coverage notes and notes sections not copied.
> Relative links resolve from the original report's directory. *Text below each heading is a verbatim copy; the `Carryover status` block is added by the run-21 qa-bundler.* These are faithfulness (Law-2) records: they belong to the spec-conformance channel, not the QA bundle, and are carried here only so the run-21 carryover set is complete per `ledger-reconciliation.json`.

</details>

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

> **Carryover status (run 21, `267660b`).** Ledger **F-01-043** · fingerprint `6753c76b07091ec7c0cfa05e4bde4c307ce6d4a82e10c9c8445eb8e8e9bf4268` · status **`open`** · severity `informational` · first seen `yield-claim-nft-15` · last seen `yield-claim-nft-16` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
