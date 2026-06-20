# Final C4 Known-Invalid / Validity Review — yield-claim-nft run-11

- Project: yield-claim-nft
- Story: story-035 (NudgeRatchet dispatcher + NudgeRatchetMintDebtHook)
- Audited commit: b8322ee83725ccba97a0ca5d1ddc5210aadb8441
- Scope confirmed: `src/V2/dispatchers/NudgeRatchet.sol`, `src/V2/dispatchers/ATokenDispatcherV2.sol`, `src/V2/hooks/NudgeRatchetMintDebtHook.sol`, `src/V2/hooks/DefaultDispatchHook.sol` — all in-scope (registered-projects.json).
- Reviewed: M-03-submission.md, M-04-submission.md + medium finding JSONs.

---

## M-03 — Decimal-scale mismatch under-mints phUSD mint-debt by ~1e12x

**Verdict: VALID** (no known-invalid pattern matched)

Checks:
- non-standard/weird token: NOT detected. USDC is a standard, in-scope 6-decimal ERC-20. The bug is the protocol's OWN missing `6 -> 18` normalization, copied verbatim from the 18-decimal USDS sibling `BalancerPoolerMintDebtHook` (`(amount * ratio) / 100`, no `*1e12`) onto a token whose 6-decimal nature is deploy-guarded at `NudgeRatchet.sol:38`. This is a hardcoded-decimal copy-paste defect, not a "weird ERC-20" assumption. The USDT/weird-token exclusion does not apply.
- fee-on-transfer: NOT detected.
- approve-race: NOT detected.
- user mistake / phishing: NOT detected — fires under correct user behaviour.
- admin/owner mistake: NOT detected — the defect manifests under fully correct wiring (`setHook` + `setMinter` done); no operator error required.
- DEDUP-001 (unbacked phUSD over-mint) suppression: NOT applicable. DEDUP-001 suppresses the unbacked/over-mint direction; M-03 is the exact INVERSE — an under-mint that fails safe with respect to phUSD solvency (no unbacked phUSD created). The finding correctly carries a MANDATORY-RE-AUDIT-ON-FIX flag so the fix cannot over-correct past `1e12` and flip into DEDUP-001 / Law-1 territory. Directionally opposite, so no suppression collision.
- out-of-scope / parent-fork root cause: NOT detected — root cause is in-scope `NudgeRatchetMintDebtHook.sol:114-115`.

Justification: The root cause is a self-contained decimal-normalization defect in in-scope protocol code (`NudgeRatchetMintDebtHook.onDispatch`), verified against source at b8322ee: the 6-decimal USDC `amount` is fed into an 18-decimal phUSD debt with no `1e12` scale-up, then realized 1:1 as 18-dp phUSD wei in `pull()`. None of the C4 known-invalid categories apply — USDC is standard, no FoT, no admin/user error, and the under-mint direction is the safe inverse of the suppressed DEDUP-001 over-mint concern. Medium (protocol function impaired, no theft/drain) is the correct framing. VALID for submission.

---

## M-04 — Unwired-dispatch zero-debt value leak (default empty hook if owner forgets setHook)

**Verdict: VALID** (Law-3 non-obvious owner footgun — in-scope per three-law hierarchy; not "reckless admin")

Checks:
- non-standard token / FoT / approve-race / user mistake: NOT detected.
- admin/owner mistake (the decisive check): the project known-issues list "Owner-driven attacks are out of scope" and "Owner trust assumptions". Per Law-3 (CLAUDE.md), those clauses cover owner MALICE and OBVIOUS-harm misconfigs only; a NON-OBVIOUS footgun that unknowingly enables a value leak or breaks a story is explicitly carved IN-scope as an operational hazard. Applying the Law-3 test — "would a competent, non-malicious owner be SURPRISED by this consequence?" — the answer is yes:
  - No revert and no event fire when the debt-bearing hook is left unwired (verified at `ATokenDispatcherV2.sol`: `dispatch` calls `hook.onDispatch` unconditionally against the default `DefaultDispatchHook` sentinel; no guard, no signal).
  - There is no retroactive backfill path for the un-accrued debt window.
  - Strongest hidden-consequence evidence: the project's OWN integration test `test_integration_mintNFTWithNudgeRatchetDispatcher` (NudgeRatchet.t.sol:160-182) exercises this exact dispatch path WITHOUT calling `setHook`, performs a full mint, and passes — asserting only the USDC flow, never any phUSD mint-debt accrual. The developers themselves did not detect the missing accrual; the path is invisible from the existing suite. That is the textbook signature of a non-obvious footgun, not an obvious misconfig (price=0, malicious-token repoint).
  - The submission is framed as an operational hazard with safe-config guidance at honest Medium (recoverable going forward, no theft/drain) — NOT as a "malicious owner could…" vector. It does not violate the no-malicious-owner rule.
- out-of-scope: NOT detected — root cause is in-scope `ATokenDispatcherV2.sol:51` (constructor default) + `NudgeRatchet.sol:60` + `DefaultDispatchHook.sol:12`.

Justification: This is the Law-3 footgun exception, not a "reckless admin mistake". The consequence of omitting `setHook` (USDC ships out while zero phUSD mint-debt accrues, with no revert/event and no backfill) is non-obvious — demonstrably so, since the project's own integration test silently passes over the unwired path. A competent, non-malicious owner would be surprised, which places the finding in-scope as an operational hazard per the three-law hierarchy and the CLAUDE.md known-invalid carve-out. It is presented with safe-config guidance at honest Medium severity, not as a malicious-owner attack, so it is neither noise nor a suppressed owner-malice vector. VALID for submission.

---

## Summary

| Finding | Verdict | Matched known-invalid pattern |
|---|---|---|
| M-03 | VALID | none |
| M-04 | VALID | none (Law-3 footgun exception applies; not "reckless admin") |

Both findings clear the C4 known-invalid / out-of-scope filter and the three-law hierarchy. No submission should be withheld on validity grounds.
