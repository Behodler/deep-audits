# [CARRYOVER] L-15 — global setAsideBufferRecipient cross-client buffer subsidy footgun

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger reflax-yield-vault`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol#L353-L372` (`_distributeBuffer`); sibling `ERC4626YieldStrategy.sol#L310-L329` this run
- **First seen:** reflax-yield-vault-15  ·  **Still present as of:** reflax-yield-vault-16
- **Original report:** [reports/reflax-yield-vault/15/findings/low/L-15-global-buffer-recipient-cross-client-subsidy.json](../../../15/findings/low/L-15-global-buffer-recipient-cross-client-subsidy.json)
- **Fingerprint:** `adfdab34…`

Re-observed this run: the `_distributeBuffer` global-recipient aggregate transfer is structurally identical on the newly-in-scope `ERC4626YieldStrategy` sibling (:310-329); the multi-client cross-subsidy footgun applies equally. lastSeenRun bumped; severity/status unchanged (Low).

See the original report for the full description, impact, attack path, and recommendation.
