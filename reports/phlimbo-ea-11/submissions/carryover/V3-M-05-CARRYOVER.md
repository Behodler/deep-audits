# [CARRYOVER] V3-M-05 — PhlimboV3 _claimRewards: a reverting reward transfer freezes a blocklisted staker's phUSD PRINCIPAL on every self-service path (promo leg :873 + stable leg :858)

> **This is a carryover stub, not new analysis.** This finding was triaged
> **`fix-pending`** (a fix was owed) and is reproduced here so it is not lost between
> runs. `fix-pending` is **never suppressed** — it is rescanned, stubbed and surfaced
> exactly like `open` until a human marks it `fixed`. Triage it with `/ledger phlimbo-ea`.

- **Severity:** Medium
- **Status:** fix-pending (fix owed, not yet verified)
- **Location:** `src/PhlimboV3.sol#L844-L877` (`_claimRewards`)
- **First seen:** phlimbo-ea-09  ·  **Still present as of:** phlimbo-ea-11
- **Original report:** [reports/phlimbo-ea-09/submissions/M-01.md](../../../phlimbo-ea-09/submissions/M-01.md)
- **Fingerprint:** `69f8b29a…`

## Run-11 notice — unapplied `fixed` proposal

> **PROPOSAL ONLY — NOT APPLIED.** `fix-pending` is human-set and is never auto-closed by
> `/full-audit`. A fix that merely stops tripping the scanner is not a verified fix.

Run-11 proposes **fix-pending → fixed** at `e04136d`, on 2 independent
confirmations: the finding's own PoC no longer reproduces at HEAD **while still compiling
cleanly** (a genuine fix, not bit-rot), and `INV-PRINCIPAL-LIVE` holds across 628k Foundry +
1.51M Medusa calls with a **differential** mutation (M1 makes the same invariant go red, so the
green carries information). 9 Halmos properties PROVEN, mutation 4/4.

Apply with:

```
/ledger phlimbo-ea fixed 69f8b29a043da5933c6e3adfe7bdf8d443bb4ee98cb36459cd998c5776c64df8
```

### ⚠ CLOSURE CAVEAT — read before applying

> Closing V3-M-05 must **NOT** be recorded as establishing that *“principal cannot freeze”*.
> **V3-M-08** (the hook Medium, new in run-11) still freezes it. V3-M-05's root cause is a
> reverting reward transfer **inside** `_claimRewards`; the hook leg is **outside** it and was
> never in M-05's scope.

Keep **strictly separate** from V3-M-07's proposal — two distinct entries, two distinct
triggers, two separate PoC replays, proposed closed separately on separate evidence.

---

See the original report for the full description, impact, attack path, PoC, and recommendation.
