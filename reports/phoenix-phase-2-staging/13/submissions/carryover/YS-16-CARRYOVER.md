# [CARRYOVER] YS-16 (691e85a6) — PREVIEW_MODE env leakage silently turns the broadcast entry into a no-op that still patches mainnet-addresses.ts

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low
- **Status:** open (still-open) — UNVERIFIED; **candidate for targeted re-verification**
- **Entry point:** `migrate:ys-swap-reset`
- **Location:** `script/ResetAndRewire.s.sol#L174-L183` + package.json + scripts/patch-mainnet-addresses-ys-swap.js (`run`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** story-062 removed `--skip-simulation` and prepended a preview hard-gate, but the specific YS-16 mechanism — PREVIEW_MODE env leaking into the BROADCAST leg, turning it into a zero-tx no-op that still runs the `&&` patcher — is not demonstrably closed by prepending a preview gate. No explicit fix-verdict. STILL-OPEN.
- **Original report:** [reports/phoenix-phase-2-staging/12/findings/low/YS-16-preview-mode-env-leak-patches-registry.json](../../../12/findings/low/YS-16-preview-mode-env-leak-patches-registry.json)
- **Fingerprint:** `691e85a6`

See the original report for the full description, impact, attack path, and recommendation.
