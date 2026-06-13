# Script Audit — phoenix-phase-2-staging :: story-060 "Yield Strategy Swap" suite

**Run:** `reports/phoenix-phase-2-staging-12/`
**Submodule HEAD:** `b27c6ac` (story-060)
**Mode:** fork-preview — shared sequential anvil, mainnet block 25297358
**Entry points audited (5):** `migrate:ys-swap-deploy → leg1 → reset → leg2 → cleanup`

Story-060 is a five-script migration suite that swaps the buggy plain `ERC4626YieldStrategy`
(DOLA/USDC) on the live StableStaker for fixed V2 strategies, via a temp-staker bounce. Each leg
was audited on one shared anvil fork, each leg advancing state for the next.

---

## Headline

**The suite as written does not complete on mainnet.** The story-060 fix line
`creditedPrincipal = vault.previewRedeem(sharesReceived)` (`ERC4626YieldStrategy._acquireShares:113`,
vault @ ad12cb1) reverts with `StateChangeDuringStaticCall` because autoDOLA/autoUSDC are Tokemak
Autopools whose `previewRedeem` mutates state internally — solc issues the `view` call as a
STATICCALL. A top-level `eth_call` succeeds (why off-chain checks missed it). The doc's own
prescribed `convertToAssets` works. **(YS-01, Medium, PoC-validated.)**

**Good news, verified empirically:** once `convertToAssets` is applied, the migration genuinely
restores users — a fork withdraw smoke-test returned full principal + reward to a migrated staker.

---

## Findings — 0 High · 4 Medium (+1 referral) · 12 Low · 2 QA

| ID | Sev | Entry point | Summary | PoC |
|----|-----|-------------|---------|-----|
| YS-01 | Medium | deploy | `previewRedeem` STATICCALL-reverts on Tokemak Autopools → V2 deposits dead on arrival | ✅ `test/PoC_YS01_PreviewRedeemBrick.t.sol` (5/5) |
| YS-03 | Medium | deploy | SYA never repointed to V2 → DOLA/USDC yield silently uncollectable, 10% buffer is dead config | — |
| YS-09 | Medium | reset | `--skip-simulation` + non-idempotent: YS-01's revert lands mid-suite after `finalizeAndReset`, pools left Active/strategyless/unpaused/non-resumable; empty-pool gate griefable | — |
| YS-10 | Medium | cleanup | verify-5b USDC band rejects the *correct* post-migration state → finalizer bricks, temp staker phUSD minter never revoked | ✅ `test/PoC_YS10_CleanupBandRevert.t.sol` (3/3) |
| YS-12 | Low | deploy | phUSD minter left on the *old* buggy strategies (~13.8k DOLA / ~11.9k USDC). Scoped `/analyze` complete: minter code **unaffected** (decoupled mint, no redeem) → operational repoint follow-up, no minter-code fix | — |
| YS-02 | Low | leg1 | owner not an authorized withdrawer → `skimSurplus` reverts at first mutation (one-line `setWithdrawer` fix) | — |
| YS-04 | Low | leg1 | `gather-migration-inputs.js` half-open-range off-by-one drops last staker per pool → suite DoS; recurs at leg2 | — |
| YS-05 | Low | leg2 | undisclosed ~0.026% DOLA / ~0.016% USDC `convertToAssets` re-deposit haircut vs doc's "1:1" | — |
| YS-06 | Low | leg1 | count-only staleness guard misses equal-count membership drift (both legs) | — |
| YS-07 | Low | leg1 | skim sent to original staker not treasury → ~13.5 USDe orphaned, ~$3 to phUSD minter | — |
| YS-08 | Low | deploy | set-aside buffer pinned 25%→10% (silent downgrade vs live config) | — |
| YS-11 | Low | cleanup | migrator2 left set on the live staker after "COMPLETE" → one-call irreversible re-migration footgun | — |
| YS-13 | Low | deploy | non-idempotent broadcast / no resume path | — |
| YS-14 | Low | deploy | V2 strategies + temp staker deployed without pauser registration | — |
| YS-15 | Low | reset | wires JSON addresses + grants unlimited approval with no on-chain identity preflight | — |
| YS-16 | Low | reset | leaked `PREVIEW_MODE` turns broadcast into an exit-0 no-op that still patches mainnet-addresses.ts | — |
| YS-17 | Low | reset | doc/NatSpec/code three-way disagreement on expected post-wire principal | — |
| YS-18 | QA | deploy | stale NatSpec on the fixed strategy (`_acquireShares` still says "full nominal amount") | — |
| YS-19 | QA | leg1 | `viem` undeclared in package.json → gather can't run from a clean checkout | — |

---

## Per-script narrative reviews

> Note: these live in colon-named subdirectories (`migrate:ys-swap-*`), which some file
> explorers/editors hide. Open them by full path in a terminal or editor.

- **deploy** — `script-audits/migrate:ys-swap-deploy/review.md` · [`intent.md`]
- **leg1** — `script-audits/migrate:ys-swap-leg1/review.md` · [`intent.md`]
- **reset** — `script-audits/migrate:ys-swap-reset/review.md` · [`intent.md`]
- **leg2** — `script-audits/migrate:ys-swap-leg2/review.md` · [`intent.md`]
- **cleanup** — `script-audits/migrate:ys-swap-cleanup/review.md` · [`intent.md`]

Each `review.md` is structured around the three audit questions (intent vs implementation /
unintended side effects / knock-on problems) and includes the fork side-effects, the exact revert
mechanisms, and the documented fork fixups used to audit successor legs past the YS-01 brick.

## Findings (structured JSON)
`findings/medium/` (5) · `findings/low/` (12) · `findings/qa/` (2). PoCs in
`workspace/phoenix-phase-2-staging/test/PoC_YS01_*.t.sol` and `PoC_YS10_*.t.sol` (8/8 passing).

## Compliance
ss9m7 (no in-place YS-swap) honored — this *is* the prescribed full-migration; story-010 gate and
story-011 `credited>0` compliant; ss9l1 avoided in the happy path.

## Housekeeping
- The suite cannot be validated end-to-end against a faithful fork until the one-line
  `previewRedeem → convertToAssets` fix lands (the audit patched it via `anvil_setCode` to reach
  the later legs).
- `lib/phoenix-phase-2-staging/known-issues.md` does not exist on disk — the sanitizer fell back to
  registration-time known issues. Worth fixing the path.

**Ledger:** `reports/ledgers/phoenix-phase-2-staging.json` — 22 → 41 entries
(36 open / 3 fixed / 1 acknowledged / 1 referral); `lastAuditedCommit=b27c6ac`,
`lastRun=phoenix-phase-2-staging-12`.

Next: `/list-findings phoenix-phase-2-staging` · `/ledger phoenix-phase-2-staging`
