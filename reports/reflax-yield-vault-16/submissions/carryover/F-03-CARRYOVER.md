# [CARRYOVER] F-03 — cross-protocol integration assumption for stable-staker M-05 relinquishPrincipal wiring

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Faithfulness (Medium re-eval gate ARMED — fires next stable-staker run)
- **Status:** open (still-open)
- **Location:** `src/AYieldStrategy.sol#L638` (`relinquishPrincipal`); consumer `lib/stable-staker/src/StableStaker.sol:786`
- **First seen:** reflax-yield-vault-14  ·  **Still present as of:** reflax-yield-vault-16
- **Original report:** [reports/reflax-yield-vault-14/findings/faithfulness/F-03-stable-staker-m05-integration-assumption.json](../../../reflax-yield-vault-14/findings/faithfulness/F-03-stable-staker-m05-integration-assumption.json)
- **Fingerprint:** `52f9b84a…`

**Gate carried, not fired.** Annotated this run **"magnitude = external vault fee config"**: the StableStaker:786 consumer reads `principalOf`, now sourced on `ERC4626YieldStrategy` from the fee-blind `convertToAssets` credit (new ECON-A / L-16). At the deployed autopools the NAV over-statement is sub-bps (Low), but the SAME path is a Medium if a future strategy is wired to a non-trivial-exit-fee vault — so the gate must re-weigh severity against the actual vault wired at the integration point, not inherit ECON-A's stale Low. The Medium re-evaluation fires in the **next stable-staker regression run**, together with DEDUP-15-005 (buffer-inflow attribution).

See the original report for the full description, impact, and recommendation.
