# [CARRYOVER] V3-L-02 — PhlimboV3 _tryTransfer abi.decode reverts on short return-data, bricks batchClaim chunk (token-gated)

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open — re-verified live and untouched at `bf42c12`)
- **Location:** `src/PhlimboV3.sol#L816-L820` (`_tryTransfer` / `batchClaim`)
- **First seen:** phlimbo-ea-07 · **Still present as of:** phlimbo-ea-08
- **Original report:** [reports/phlimbo-ea-07/audit/submissions/qa-report.md](../../../../phlimbo-ea-07/audit/submissions/qa-report.md)
- **Fingerprint:** `c0e37955…`

## Why this carryover matters more than its Low severity suggests

This defect was **live and OPEN in the ledger** when `story-025` **copied the helper
byte-identically into `src/MigratorV2V3.sol`** (md5 `9b80f3419b748e1c9a1de632827e3418`) —
replicating the class into a second contract, under NatSpec that unconditionally promises
forwarding "never reverts" and "can never brick a pass". That replication is tracked separately
as **`V3-L-07` / `08-04` (Low)** and **`F-08-01`** in this run's spec-conformance report.

> *Scoping correction:* an earlier draft described the migrator copy as landing on a **worse**
> token leg (`promoToken` being arbitrary and owner-selected). That framing is **withdrawn as
> falsified by source** — `startPromotion`'s mandatory `safeTransferFrom` (`PhlimboV3.sol:346`)
> precedes the `promoToken` assignment, so a short-returning token can never be installed as
> `promoToken`. The propagation entry stands on its doc-vs-code core, not on token realism.

**Fixing this helper alone will NOT fix the migrator — the code is duplicated, not shared.**
Both copies need the length check:

```solidity
return callSuccess && (returndata.length == 0 || (returndata.length >= 32 && abi.decode(returndata, (bool))));
```

Its faithfulness twin **V3-F-02** (also open, also carried over this run) owns the doc-vs-code
deviation; this entry owns the DoS severity. **Not double-counted.**

See the original report for the full description, impact, attack path, and recommendation.
