# Final Quality Validation — yield-claim-nft run-11 Medium submissions

- Project: yield-claim-nft (story-035, NudgeRatchet)
- Audited commit: b8322ee83725ccba97a0ca5d1ddc5210aadb8441
- Validator: report-validator
- Date: 2026-06-17
- Scope: M-03 (decimal under-mint, 1e12x), M-04 (unwired-dispatch zero-debt leak)

## Verification method

- Every `file:line` citation in both submissions read against source at b8322ee.
- Both PoCs executed from `workspace/yield-claim-nft` (HEAD == b8322ee). Both PASS.
- Submission PoC bodies confirmed equivalent to the executed workspace PoCs
  (`poc-M01-decimal-undermint.t.sol` -> M-03, `poc-M02-unwired-zero-debt.t.sol` -> M-04;
  only class/test-name label renames M01->M03 / M02->M04).
- Finding JSONs cross-checked for consistency with submission claims.

NOTE on PoC build: the workspace `test/` dir contains unrelated stale PoCs
(`poc-ECON-RAW-00x`, `poc-M01-migrate-gas-dos`, `poc-M02-late-dispatcher-brick`,
`poc-H-01`) that reference removed `BalancerPoolerV2` members and break a whole-dir
`forge build`. They were moved aside to compile/run the two target PoCs in isolation,
then restored. This is workspace hygiene only and does NOT affect the two submitted
PoCs, which compile and pass standalone. Recommend pruning the stale workspace PoCs.

---

## M-03 — Decimal under-mint (1e12x) — VALID

Structure: PASS. Metadata comment (ID/Title/Severity/Root Cause Link/PoC File/Faithfulness
tag/Latent-Hazard) present. No `#` headings. Sections: Finding description and impact,
Recommended mitigation steps, Proof of Concept (with run command). Code-links present.

Citation resolution at b8322ee — all PASS:
- NudgeRatchetMintDebtHook.sol#L114 `uint256 added = (amount * ratio) / 100;` — exact.
- L115 `if (added == 0) return;` — exact.
- L128 `phUSD.mint(recipient, debt);` — exact.
- NudgeRatchet.sol#L38 `require(IERC20Metadata(token_).decimals() == 6, ...)` — exact.
- L112-L118 onDispatch block quoted verbatim — matches.

PoC asserted values — PASS (live logs):
- 5 USDC (amount=5e6) -> realized phUSD = 5e6 wei; intended = 5e18 wei; intended == realized * 1e12.
- $1,000,000 USDC (amount=1e12) -> realized = 1e12 wei; intended == realized * 1e12.
- Test output: intended 5000000000000000000, realized 5000000, shortfall 4999999999995000000. Exact match.

Severity honesty — PASS: Claimed Medium. Explicitly framed as UNDER-mint that fails SAFE
(no unbacked phUSD, no theft, no drain), protocol-function-impaired. Report explicitly
disclaims a theft/drain vector. No overstatement.

Latent-hazard callout — PASS: "Latent hazard on fix (mandatory re-audit)" section present;
states over-correction past exactly 1e12 flips to unbacked phUSD over-mint (DEDUP-001 /
Law-1), fix must land at exactly *1e12 (or dynamically 10**(phUSDdec - tokenDec)), and the
fix MUST be re-audited. Metadata `Latent-Hazard: MANDATORY-RE-AUDIT-ON-FIX` matches JSON.

LLM-nonsense / quality — PASS: precise, quantified, no hedging filler.

Issues: none blocking.
Minor (non-blocking):
- PoC instructs placement under repo `test/`; the project's real NudgeRatchet tests live
  in `test/V2/`. Imports `../src/...` and `./mocks/MockMintable.sol` resolve correctly from
  `test/` (root), so the stated placement is internally consistent and works as written.
  `MockUSDC6` reference is accurate (mirrors `test/V2/NudgeRatchetMintDebtHook.t.sol:13`).

Verdict: VALID.

---

## M-04 — Unwired-dispatch zero-debt leak (Law-3 footgun) — VALID

Structure: PASS. Metadata comment present (ID/Title/Severity/Root Cause Link/PoC File/
Classification). No `#` headings. Sections present incl. Safe-config guidance subsection
and Proof of Concept with run command. Code-links present.

Citation resolution at b8322ee — all PASS:
- ATokenDispatcherV2.sol#L50-L52 constructor `hook = new DefaultDispatchHook();` (L51) — exact.
- L94 `function setHook(IDispatchHook newHook) external onlyOwner` — exact (sole wire-in).
- L118-L126 `dispatch(...)` -> `_dispatch(...)` then `hook.onDispatch(...)` unconditional — exact.
- DefaultDispatchHook.sol#L12 `function onDispatch(address, uint256, bytes calldata) external {}` — exact.
- NudgeRatchet.sol#L59-L61 `_dispatch` `safeTransfer(batchMinter, amount)` — exact.
- NudgeRatchet.t.sol:160-182 — VERIFIED: `test_integration_mintNFTWithNudgeRatchetDispatcher`
  occupies exactly lines 160-182, omits `setHook`, asserts only the USDC flow + NFT mint,
  and makes NO mintDebt assertion. The "passes silently on the unwired path" claim is
  factually correct and is the strongest evidence for the non-obvious footgun.

PoC asserted values — PASS (live logs):
- batchMinter received +10e6 USDC; ratchet holds 0; NFT minted; nudgeHook.mintDebt() == 0.
- Test output: "USDC dispatched to batchMinter: 10000000", "phUSD debt recorded by hook: 0". Exact match.

Severity honesty — PASS: Claimed Medium as a recoverable, value-leak operational hazard
gated on operator (mis)configuration (hook deployed but not wired). Fails SAFE re: phUSD
solvency. Explicitly not High; no theft/drain claimed. In-scope per three-law hierarchy as
a non-obvious owner footgun (Law-3), correctly argued — the project's own silently-passing
integration test is cited as proof the consequence is hidden. Justification is honest.

LLM-nonsense / quality — PASS: concrete, evidenced, actionable mitigation (sentinel-hook
guard + fix the silent test). No filler.

Issues: none blocking.
Minor (non-blocking):
- PoC mirrors the integration wiring and reuses `MockMintable`/`NFTMinterV2`; imports
  resolve from repo `test/`. `MockUSDC` reference (mirrors `test/V2/NudgeRatchet.t.sol`) is
  accurate.

Verdict: VALID.

---

## Overall

| Report | Verdict | Blocking issues |
|--------|---------|-----------------|
| M-03   | VALID   | none |
| M-04   | VALID   | none |

Both Medium submissions are submission-ready. Citations resolve at b8322ee, PoCs compile
and pass with assertions matching the reported figures, severity is honestly justified
(both fail safe; M-03 under-mint not theft, M-04 recoverable Law-3 footgun), and the
required M-03 latent-hazard / mandatory-re-audit callout is present. No overstatement, no
LLM-nonsense.

Non-blocking follow-up: prune the stale unrelated PoCs in `workspace/yield-claim-nft/test/`
that break a whole-directory `forge build`.
