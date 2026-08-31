# QA Report — stable-staker (run-15)

- **Project:** `stable-staker` · **Commit:** `2146428` · **Branch:** `master`
- **Baseline:** `8856781` (run-14) · **Mode:** REGRESSION
- **Scope (first-party):** `src/StableStakerV2.sol`, `src/CrossVersionMigrator.sol`, `src/InPlaceMigrator.sol`, `src/versions/v1/**`, `src/interfaces/**`
- **Companion artifacts:** `submissions/M-01.md` (the run's sole Medium), `submissions/spec-conformance.md` (F-01…F-03), `submissions/4naly3er-report.md` (automated QA/gas — Appendix A)

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 5 |
| Centralization Risk | 0 (see note) |
| QA / Non-security | 4 (one of which, **Q-04**, is a re-verified prior-run entry, not a new finding) |
| **Total** | **9** (8 new this run + 1 re-verification) |

**Centralization note.** No centralization findings are filed. Under this audit's Law-3 rule the owner is
trusted for *knowing* actions, so "the owner can call `setYieldStrategy` / `setMigrator` / `rescueERC20`"
is not reportable — and the automated report's 28 `M-2 Centralization Risk for trusted owners` instances
(Appendix A) are suppressed on that basis. The privileged-surface issues that *are* reportable appear
below as **L-04** and **L-05**, because they are non-obvious owner **footguns**: a competent, non-malicious
owner would be surprised by the consequence, in one case because the contract's own NatSpec tells them the
opposite.

**Faithfulness note.** `Q-02` and `Q-03` (and Low `L-02`) are also Law-2 spec deviations and appear in
`spec-conformance.md` as **F-02**, **F-03** and **F-01** respectively. They are listed here **in addition
to**, never instead of, those entries — a QA bundle does not discharge a faithfulness report.

---

## Low Risk Findings

> **Identity.** Every heading below carries the **ledger's** `issueId`, fingerprint and label verbatim
> (`reports/stable-staker/ledger.json`). The ledger is authoritative for identity; this report presents in
> the ledger's label order. Two entries deliberately carry **no new fingerprint** because they are in-place
> updates of existing ledger entries (**L-02**, **L-04**), and **L-04 carries no `issueId` at all** — it is a
> run-01 entry that never had one, and minting one onto it now is forbidden.

### [L-01] `CrossVersionMigrator`'s pre-flight fails open against a codeless destination <!-- id: ss15l1 -->

- **issueId:** `ss15l1` · **Fingerprint:** `b00122d2255ba3b3ec31e390e1073b34f67d4e1de0cf2bebb1c522533bde21fd` (NEW)
- **Ledger:** `open` · `incompleteFixOf` **`7cdb92fdc71a660cae65b1cdeeaf334092ba889d9a56477f8c8c88bd1947e17f`** (`ss14l6`, this report's L-02)
- **Run finding:** `DEDUP-15-03` · **Root-cause class:** `fail-open-existence-check`

**Location:** [`src/CrossVersionMigrator.sol#L121-L129`](../../../../lib/stable-staker/src/CrossVersionMigrator.sol#L121) (constructor), [`#L214-L239`](../../../../lib/stable-staker/src/CrossVersionMigrator.sol#L214) (`_migratorOf` / `_isRegisteredOn`), [`#L145-L150`](../../../../lib/stable-staker/src/CrossVersionMigrator.sol#L145) (`initiateMigration`)

**Description.** Both destination probes are `staticcall`s that treat an unrecognised shape as
"unverifiable, not wrong":

```solidity
(bool ok, bytes memory data) = staker.staticcall(abi.encodeWithSignature("migrator()"));
if (!ok || data.length < 32) return (address(0), false);   // _migratorOf: waives itself
...
if (!ok || data.length < 64) return true;                   // _isRegisteredOn: waives itself
```

A `staticcall` to an address **with no code** succeeds and returns empty returndata, so both probes waive
themselves and `initiateMigration` proceeds. The constructor checks only non-zero and non-aliased —

```solidity
require(address(_oldStaker) != address(0), "Migrator: zero old staker");
require(address(_newStaker) != address(0), "Migrator: zero new staker");
require(address(_oldStaker) != address(_newStaker), "Migrator: aliased stakers");
```

— and never `code.length > 0`. A typo'd, wrong-network, or not-yet-deployed destination therefore passes
every guard, and the source pool latches the one-way `Migrating` state with emissions stopped against a
destination that does not exist.

This is a genuine Law-3 footgun rather than a reckless-admin mistake: the contract *appears* to validate the
destination and silently does not, and the wiring error it fails open against is the single most likely one.

**Nothing here is permanent.** The PoC drives the freeze **and recovers from it**: one owner transaction
(`oldStaker.setMigrator`) re-points the migrator, and `userMigrate` remains a permissionless self-exit for
every user throughout. A recoverable operational freeze with the self-exit open is not asset loss — hence
Low.

Filed as an **incomplete fix of `7cdb92fdc7`** with its own root-cause class (`fail-open-existence-check`)
so the two do not collide on one fingerprint.

**Recommendation.** Add an existence check in the constructor, where it is cheapest and permanent:

```solidity
require(address(_oldStaker).code.length > 0, "Migrator: old staker not a contract");
require(address(_newStaker).code.length > 0, "Migrator: new staker not a contract");
```

---

### [L-02] `initiateMigration` §C leaves destination preconditions unasserted, and its "uncheckable" claim is false <!-- id: ss14l6 -->

- **issueId:** `ss14l6` · **Fingerprint:** `7cdb92fdc71a660cae65b1cdeeaf334092ba889d9a56477f8c8c88bd1947e17f` (**existing entry — NO new fingerprint**)
- **Ledger:** `open`, first seen run-14 · **narrowed in place this run; do not close, do not re-mint**
- **Run finding:** `DEDUP-15-04` · Also filed as **F-01** in `spec-conformance.md` (Law 2)

**Location:** [`src/CrossVersionMigrator.sol#L145-L150`](../../../../lib/stable-staker/src/CrossVersionMigrator.sol#L145) and the §C NatSpec above it

**Description.** The pre-flight asserts two of the destination-side preconditions and forwards the
irreversible call regardless of the rest. **The leg that actually bites is the destination's pool state**:
after the source has frozen in transaction 1, every `depositFor` in transaction 2 reverts on

```solidity
require(poolState[token] == PoolState.Active, "StableStaker: pool not active");
```

leaving the source in `Migrating` with emissions stopped while the owner repairs the destination.
`userMigrate` stays available to every user in the meantime, so this is a recoverable operational trap —
Low, not Medium.

**The phUSD-minter leg is not the biting leg and is corrected here.** `_settle` mints only
`if (user.amount > 0)`, and a migrating user's destination position is fresh, so `depositFor` mints nothing
and does not need the destination to be an authorized minter at all. Any framing that this "surfaces only
after the source is frozen" is struck.

What does *not* reduce the severity is the in-source NatSpec. §C's claim that the minter precondition is
"uncheckable from here" is **factually false at HEAD**: `phUSD` is public on both staker shapes, and
`FlaxToken.authorizedMinters` / `mintVersion` are external views, so the two-hop probe is constructible. A
falsely-exhaustive in-source claim carries no suppression authority and raises severity rather than
lowering it.

**Recommendation.** Assert the pool-state precondition before forwarding, and either implement the
two-hop minter probe or replace the "uncheckable" claim with an accurate statement of what is and is not
checked:

```solidity
require(newStaker.poolState(token) == PoolState.Active, "Migrator: destination pool not active");
```

> **Ledger note.** This is an **in-place narrowing of `7cdb92fdc7`** — narrow it, do not close it, do not
> mint a new fingerprint. Its `issueId` stays **`ss14l6`** (minted at first sighting in run-14, and stored
> there under the legacy `id` key — a valid alias). It was labelled **L-06** in run-14; labels are
> run-scoped, so the run-15 label `L-02` is presentation only and changes nothing about its identity.

---

### [L-03] Terminal migration has no minimum-realisation floor, and the only number that could supply one is discarded <!-- id: ss15l3 -->

- **issueId:** `ss15l3` · **Fingerprint:** `75649b9e30e799dc6ff65dda4853b8b7b3d7d64f13754dc1762f00dc2cafa648` (NEW)
- **Ledger:** `open` · **Run finding:** `DEDUP-15-05` · **Root-cause class:** `missing-floor-on-irreversible-step`

**Location:** [`src/StableStakerV2.sol#L469`](../../../../lib/stable-staker/src/StableStakerV2.sol#L469) (discarded return value), [`#L496-L527`](../../../../lib/stable-staker/src/StableStakerV2.sol#L496) (the `R` snapshot and the one-way latch)

**Description.** `initiateMigration` realises the whole strategy position with

```solidity
_routeExit(token, P, false);   // :469 — return value deliberately discarded
```

and then measures `R = IERC20(token).balanceOf(address(this))` independently, so that the set-aside buffer
counts toward the payout. The consequence is that `_routeExit`'s return value — **the only on-chain number
that distinguishes a clean sweep from a shortfall** — is thrown away one line before it would be needed.
Downstream, `_withdrawInternal` debits the *requested* (capped) amount, so `booked == 0` and the
`"incomplete exit"` post-check is satisfied by construction; `PrincipalDivergence(token, P, 0, 0)` is
emitted byte-identically to a healthy migration. The migration can therefore latch at **any** `R`,
including `0`, with no lower bound, no revert, and no distinguishing event — after which every staker is
locked to `userMigrate` at that haircut (`withdraw` and `emergencyWithdraw` are both `Active`-gated).

Rated Low, not higher: the shortfall would originate in the external ERC4626 vault, i.e. market loss on
externally-derived capital rather than a protocol value leak, and no attacker-controlled route to force it
was demonstrated (Tier-3 found no sandwich or manipulation leg). What is reportable is the missing bound on
an irreversible step plus the lost observability discriminator.

**Recommendation.** Keep the balance-based `R` (it is deliberate and correct), but *also* consume the
return value as a floor and emit it:

```solidity
uint256 delivered = _routeExit(token, P, false);
require(booked == 0 || delivered + booked >= P, "StableStaker: exit shortfall");
// ... and include `delivered` in the PrincipalDivergence payload
```

This mitigation should be adopted **independently of the disposition of Q-01**.[^floor-adapter]

> **Scope of this entry.** Only the two legs above are rated: the discarded return value at `:469`, and the
> absence of a floor before the one-way latch. A latent *received-decrementing custody adapter* variant was
> examined and is **parked as speculation on future code** (`MR-15-S1` in `manual-review.json`); it
> contributed nothing to this severity and is not a finding.

[^floor-adapter]: Secondary, and explicitly **not** part of this finding's basis: the same floor would also
    stop a future `IYieldStrategy` adapter from silently removing it. That is forward-looking commentary on
    the parked `MR-15-S1` speculation, which is **not rated** and contributed nothing to this severity. The
    finding stands entirely on the two legs demonstrated at HEAD.

---

### [L-04] `rescueERC20` reserves nothing while a strategy is wired, so a routine dust sweep silently deepens a later migration haircut <!-- id: none -->

- **issueId:** **NONE** — this is a run-01 ledger entry that never carried one, and per the mint-once rule none is minted onto it now. **The fingerprint is its selector.**
- **Fingerprint:** `0790a76a00ed176437d53a474145b1b5eac1a0359034e1dde31b98470b9837bb` (**existing entry — NO new fingerprint**)
- **Ledger:** `open`, first seen run-01 · **impact re-weigh in place this run; do not re-file**
- **Run finding:** `DEDUP-15-06`

**Location:** [`src/StableStakerV2.sol#L868-L875`](../../../../lib/stable-staker/src/StableStakerV2.sol#L868)

**Description.** The reserve is computed as

```solidity
uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;
```

so with a strategy wired the **entire** contract balance is rescuable. That was a correct model before
story-020. It is no longer: `initiateMigration` now snapshots `R = balanceOf(address(this))`, which places
the set-aside buffer *inside* the pro-rata migration payout. A routine dust sweep performed while a
strategy is set therefore removes the cushion that would have converted a below-par terminal migration into
a par migration — days later, and with no link between the two actions anywhere in the code or runbook.

This is a **non-obvious owner footgun and is in scope**: the owner is not merely unwarned but actively
misled by the function's own NatSpec, which asserts that with a strategy set "the contract balance is
purely buffer + dust, so the full balance is rescuable" and that the guard exists so "the owner cannot
withdraw user principal". Under this project's standing rule an in-source claim that is false at HEAD
carries no suppression authority and *raises* severity rather than lowering it.

It stays **Low**, deliberately: the swept pot is protocol working capital, not a solvency reserve and not
user principal. No staker was ever entitled to it and nothing sizes it against outstanding principal, so
what is lost is a discretionary protocol-funded top-up. Rating the headline swing as economic loss would be
an overstatement.

**Recommendation.** Correct the NatSpec first — it is the active cause. Then link the sweep to the
migration in the runbook, and optionally reserve the cushion while a terminal migration is still reachable:

```solidity
// while poolState[token] == PoolState.Active and a migration may still be initiated
uint256 reserved = address(yieldStrategy[token]) == address(0)
    ? poolInfo[token].totalStaked
    : _minCushion(token);   // e.g. min(R, P) semantics
```

---

### [L-05] The set-aside cushion is only as large as an unasserted address on a different contract in a different repo <!-- id: ss15l5 -->

- **issueId:** `ss15l5` · **Fingerprint:** `164cb4d2a283f52cf2672af74780d2446fc58a3e4b9c7ffe4f1c476b0fdf0381` (NEW)
- **Ledger:** `open` · **Run finding:** `DEDUP-15-07` · **Root-cause class:** `cross-contract-trust-assumption-unasserted-config`

**Location:** [`src/StableStakerV2.sol#L521`](../../../../lib/stable-staker/src/StableStakerV2.sol#L521) ↔ `lib/reflax-yield-vault :: AYieldStrategy.setAsideBufferRecipient` (`:63`)

**Description.** `StableStakerV2:521` measures the migration cushion as `R = IERC20(token).balanceOf(address(this))`.
Whether the set-aside buffer ever *reaches* that balance is decided entirely by
`AYieldStrategy.setAsideBufferRecipient` — a single owner-settable global on the strategy, in the sibling
repo. Point it at a treasury instead of at the staker and the cushion measured at `:521` is approximately
zero. Nothing in `StableStakerV2` reads, asserts, documents, or even names that address; the failure is
completely silent, and the same bytecode yields a materially different haircut depending on off-chain
configuration.

Kept **separate** from L-04 and Q-01: different site, different actor, different mechanism, non-overlapping
mitigation. **This is the caveat that must travel with the `f7991b64ad` (`ss14l8`) propose-fixed closure**,
and — after this run's re-adjudication of Q-01 — it is now the *only* caveat on that closure.

Low, not higher, for the same ceiling reason as L-04: what the misconfiguration caps is the size of a
discretionary protocol-funded top-up, not user principal.

**Recommendation.** Expose a view on the strategy and assert it at wiring time (or, at minimum, add an
explicit runbook check) that `setAsideBufferRecipient == address(staker)`.

---

## QA / Non-security Findings

### [Q-01] Terminal migration relinquishes `booked` with no realisation attempt, importing its safety from an unasserted sibling-repo property <!-- id: ss15q1 -->

- **issueId:** `ss15q1` · **Fingerprint:** `a943890f11a552f532a98a6e9f42bc5396fe727f088db2824bd1c0bc1d6548b0` (NEW)
- **Ledger:** `open` · **Run finding:** `DEDUP-15-01` · **Severity moved Medium → QA** on a deterministic Tier-3 refutation

**Location:** [`src/StableStakerV2.sol#L496-L527`](../../../../lib/stable-staker/src/StableStakerV2.sol#L496) (the D3 write-down / D4 balance read)

> **Struck claim.** This entry was proposed as a **Medium** asserting ~45,000 USDC of stranded value. **That
> claim is WITHDRAWN as invalid.** Its entire quantum came from `MockYieldStrategy.withdraw`, which pays
> `amount * valueFactorBps / 10000` with no share cap. Both concrete strategies at the top-level
> `lib/reflax-yield-vault` HEAD instead compute `vault.convertToShares(amount)` and cap it to the strategy's
> share balance — and the swept buffer's shares are *in* that balance, so the buffer already softens the
> migration through the strategy leg before D4 ever reads `balanceOf`. Replaying the finding's own inputs
> (`S = 50,000`, `T = 1,000,000`, 90 % of par) against the real strategy yields `R = 945,000` with
> `0.000000` residue — exactly the outcome the finding named as its mitigation's *goal*; the mock reproduces
> `R = 900,000`, isolating the divergence to the test double alone. A finding that reproduces only on a mock
> is not a finding.

**What survives, and why the entry is retained.** `StableStakerV2` relinquishes `booked` with **no
realisation attempt and no comment explaining why that is safe**. It is safe *only* because of a property
of a different repository — `AYieldStrategy._disposeShares`'s `convertToShares → cap to available shares`
prologue — that `StableStakerV2` neither reads, nor asserts, nor documents. That is the same root-cause
family as **L-05**, and it is recorded here because this is the only place it is written down.

**The refutation has named expiry conditions. It is not a general safety property.**

1. It is scoped to the **two concrete strategies present at `lib/reflax-yield-vault` HEAD `0110ce4`**
   (`ERC4626YieldStrategy`, `ERC4626MarketYieldStrategy`) and their shared cap prologue. It says nothing
   about an arbitrary future `IYieldStrategy`.
2. The very mechanism that makes the refutation work — the **global** share cap — was routed to
   `reflax-yield-vault` as **T3-03** and has since been **closed by the owner (2026-08-29) as intended
   design, not a finding.** The multi-client precondition is and remains **confirmed live on mainnet**
   (executed `MigrateSaga2Deploy` broadcast; `ReplaceSYAMainnet.s.sol:208-209` preflight-asserts two clients
   on all three live strategies) — that was never the disputed part. What changed is the reading of it:
   every other authorized client on those vaults is a **phUSD minter, which mints without redeeming**, so no
   client on the losing side holds a redeemable user claim. The global cap *is* the mechanism implementing a
   deliberate cushion, letting minter-side backing absorb shortfall so stable-staker can meet user stake
   obligations at par.

   > **⚠ Corrected — this entry previously said the opposite.** An earlier version of this report said
   > *"tightening that cap to per-client revives this finding's harm"*, framing the global cap as an
   > unasserted property that might one day be tightened. **Do not narrow that cap to per-client.** Doing so
   > would **break the intended cushion**, not fix a defect.

3. Therefore the surviving residual is **not** "a property that might be tightened" but **a deliberate
   cross-repo design dependency that `StableStakerV2` never documents.** Re-run the invariant against any
   newly-landed concrete strategy, and treat any change to `_disposeShares`' cap semantics as a re-audit
   trigger — as a **departure from intended design**, not as a fix. This entry's basis also expires if a
   **redemption-capable (non-minter) client** is ever authorized alongside stable-staker on a shared vault
   position, which would void T3-03's closure with it.

> ### ⚠ Do NOT adopt this finding's original mitigation
> The originally proposed fix — *"withdraw `booked` before relinquishing"* — **must not be implemented.**
> On a single-client strategy it is a **no-op** (there are no shares left to realise once a materially
> below-par exit has been share-capped). On a multi-client strategy it is a **transfer of value *from*
> sibling clients**. It recovers nothing and can cause harm.

**Recommendation.** Document the imported dependency at the relinquish site, naming
`AYieldStrategy._disposeShares` and the cap it relies on, and add the two expiry conditions above to the
migration runbook as re-audit triggers. Additionally, the existing PoC
`test/poc/Run15_CodeScan.t.sol::test_selfHeal_destroys_the_buffer_D4_was_meant_to_spend` passes **only**
because it uses the mock and must either carry that caveat or be re-based on `ERC4626YieldStrategy`.

---

### [Q-02] Frozen-V1 CI gate under-enforces the guarantee its own banner claims <!-- id: ss15q2 -->

- **issueId:** `ss15q2` · **Fingerprint:** `7c99f3744421c61f026ad4e71fadad982f5b96389d739198bff5d08afe95184a` (NEW)
- **Ledger:** `open` · **Run finding:** `DEDUP-15-08` · Also filed as **F-02** in `spec-conformance.md` (Law 2)

**Location:** `.github/scripts/check-migration-surface.sh`

*Also filed as **F-02** in `spec-conformance.md` (Law 2).*

**Description.** The gate's banner claims that "a mismatch is a hard failure … the ONLY deliberate way past
this gate is `GOLDEN-RULE-OVERRIDE`". Both halves are false at HEAD:

1. **Silent skip without GNU `sha256sum`.** On a host lacking the binary, hash verification is skipped with
   `status` untouched, so an **edited** frozen V1 file passes green with only a note on stderr. CI
   (`ubuntu-latest`) has `sha256sum`; the exposure is the local / pre-commit path the story itself directs
   developers to.
2. **`GOLDEN-RULE-OVERRIDE` is unimplemented, and a same-commit re-pin passes.** The script never reads a
   commit message (`exit $status` is unconditional). Separately, editing a frozen file *and* regenerating
   `FROZEN.sha256` in the same change satisfies every check, because the `manifest_count != 2` test rejects
   only an emptied or extended manifest, never a re-pinned one.

**This item is pinned at QA and must never drift above it.** The subject is a shell script with **no
on-chain surface**: it cannot move value, cannot change contract state, and cannot be reached by any
transaction. Nothing on chain changes, and the gate is defence-in-depth over deliberately frozen files. It earns its place because the script asserts a guarantee it does not deliver, and because this gate
is the **sole** enforcement of the invariant "V1 must never gain a `STAKER_VERSION` getter" that a parked
manual-review item depends on. The project's disclosed "Known gap" is scoped to enforcement **layer 2**
(the `PreToolUse` hook) and does not reach **layer 3** (this script), of which the same document claims "no
blind spot" — so the disclosure does not suppress it.

**Recommendation.** Fail hard (`status=1`) when `sha256sum` is unavailable rather than skipping; implement
the `GOLDEN-RULE-OVERRIDE` commit-message check the banner promises, or delete the claim; and reject a
manifest whose *contents* changed, not merely its cardinality.

> **Ledger note.** The first half of leg 2 should be **reconciled against open QA `c8218865da`**, not
> double-filed. The `sha256sum`-absent skip and the same-commit re-pin bypass are genuinely new.

---

### [Q-03] story-020's named compensating controls do not exist <!-- id: ss15q3 -->

- **issueId:** `ss15q3` · **Fingerprint:** `e5b8c1f715c004ce91a44e09a5ad0618e353c15c33eea4a3870702b99ea5533e` (NEW)
- **Ledger:** `open` · **Run finding:** `DEDUP-15-09` · Also filed as **F-03** in `spec-conformance.md` (Law 2)

**Location:** [`src/StableStakerV2.sol :: initiateMigration`](../../../../lib/stable-staker/src/StableStakerV2.sol#L449) / [`setYieldStrategy`](../../../../lib/stable-staker/src/StableStakerV2.sol#L242); `test/Migration.t.sol:845`

*Also filed as **F-03** in `spec-conformance.md` (Law 2).*

**Description.** The code is **faithful** to story-020. What is missing is the off-chain half the story
itself names as the thing that makes its new silence safe:

1. **The monitoring rule has no owner.** story-020 specifies the alert verbatim and then states "Nobody owns
   that alert yet". The story carried that as its own `[medium]` and auto-completed anyway, so the bound on
   the fail-open conversion is currently vacuous.
2. **The tripwire's only test depends on a no-op stub.** The sole test proving the `"incomplete exit"`
   post-check still trips (`test_postCheck_incompleteExitReverts`) relies on
   `UnderRealizingStrategy.relinquishPrincipal` being an **empty-bodied stub** (`test/Migration.t.sol:845`).
   The tripwire has **no conforming-strategy coverage**, and by this project's standing precedent a no-op
   mock stub can manufacture a false permanence/coverage result.

The Law-1 override was tested and did not trigger: the harm hypothesis (the self-heal writing down
user-claimable principal) is refuted against the real dependency, since `_withdrawInternal` debits the
requested amount and residual `booked` after `_routeExit(P)` is exactly the sweep excess — protocol money by
the empty-pool gate. So this is a Law-2 control gap at QA, not a security finding.

**Recommendation.** Assign an owner to the story-020 monitoring rule before the next terminal migration, and
add a `"incomplete exit"` test against a **conforming** strategy that genuinely under-realises, rather than
against a stub whose `relinquishPrincipal` does nothing.

---

### [Q-04] `withdrawDisabled` reports the pool frozen while par exits are in fact being served from the buffer <!-- id: none -->

- **issueId:** *none* — this is a **run-07 entry that never had one, and minting one now is forbidden**
- **Fingerprint:** `a56f87780b2af79ec18efc84289966cc40b1c41a49a4f99b821e9ea49427777c` (**NOT NEW — existing ledger entry**)
- **Ledger:** `open`, severity **Low / QA-tier**, first seen **run-07**, re-verified in source at this HEAD and `lastSeenRun` bumped to run-15
- **Preimage:** `src/StableStaker.sol:withdrawDisabled:stale-view-spec-deviation` — pre-rename, so it no longer reproduces from `contract:function:rootCauseClass` at HEAD. **The fingerprint is the identity and is unchanged.**

> ### ⚠ Filed as a re-verification, NOT as a new finding
> This item was re-derived independently during run-15 triage as an "accessor / state-report mismatch" and
> then matched back to the existing entry on **function + root-cause class** (never on path), exactly as this
> run's fingerprint-drift warning requires. **No new fingerprint was minted and no new entry was filed.** It
> appears here — rather than only in the carryover table below — because it was actually re-read in source
> this run, and because it turned out to be the proximate cause of a wrong belief about pool state held at
> owner level during this run.

**Location:** [`src/StableStakerV2.sol#L750-L761`](../../../../lib/stable-staker/src/StableStakerV2.sol#L750)
(NatSpec `:750-754`, body `:755-761`) · related: `_routeExit` [`#L840-L850`](../../../../lib/stable-staker/src/StableStakerV2.sol#L840)

**The mismatch.** `withdrawDisabled(address token)` returns `_isUnderwater(token, strategy)` — true whenever
`totalBalanceOf < principalOf` — and its NatSpec states that non-migrating withdrawals *"are currently
disabled for `token` because its yield strategy is below par"*. That is **false whenever the on-contract
buffer covers the withdrawal.** `_routeExit`'s underwater branch pays the user **in full, at par**, out of
the buffer: if `t.balanceOf(address(this)) >= amount` it emits `BufferWithdrawn`, calls
`strategy.relinquishPrincipal(token, amount)` and returns `amount`. It reverts
`"StableStaker: strategy underwater"` **only** when the buffer is short. So the view reports the pool as
frozen while par exits are being served for any amount the buffer covers.

**The correct reading of pool state** is **underwater AND buffer below the requested amount** — never
underwater alone. A caller that wants the real answer must compare `token.balanceOf(staker)` against the
intended withdrawal amount; `withdrawDisabled` cannot supply it, because it takes no amount argument.

**Impact — informational, and deliberately not inflated.** No value is at risk and there is no attacker
role; the direction is conservative (it never under-reports). The demonstrated cost is an **incorrect mental
model of when the pool is exposed**: a front-end or operator gating on `withdrawDisabled` gets a wrong
picture, and this run it was the proximate cause of the owner-level belief that *"underwater vaults pause
stable-staker"*. Severity stays **QA**.

**Distinct from `dbdc3ac9b9` (M-06).** That entry is the opposite-direction, hazardous **under**-report
(the signal silently lifted to `false` by an underwater strategy swap). The existing cross-reference on both
ledger entries stands; do not collapse them.

**Recommendation.** Either correct the NatSpec to state what the function actually returns (*"the strategy is
below par; a withdraw may still succeed if the on-contract buffer covers it"*), or give the view an `amount`
argument and return `underwater && token.balanceOf(address(this)) < amount`.

---

## Carryover — still-open prior-run findings NOT re-scanned this run

Recorded here for visibility, not re-adjudicated. This run was a regression scan against baseline
`8856781`; the entries below were **not re-targeted**, so **absence of a finding above is not evidence that
any of them is fixed.** Statuses are as they stand in `reports/stable-staker/ledger.json` — this report
writes nothing to the ledger.

> ### ⚠ `dab5a65613` — Medium, `fix-pending`, NOT re-tested this run
> *"Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers"*
> (`src/StableStakerV2.sol :: setYieldStrategy` — path re-based this run for the story-019 rename; the
> fingerprint is unchanged and remains the entry's identity. Last seen run-10.)
> This is the ledger's **sole `fix-pending` entry** and the only carryover Medium. It was **not
> re-targeted** by this run's scope, so **its silence here is NOT evidence of a fix.** Per the
> `fix-pending` rule it is carried forward in full, keeps its status, and nothing is proposed against it;
> only a human may mark it `fixed`.

| Fingerprint | Sev | Status | Summary | Last seen |
|---|---|---|---|---|
| `dab5a65613` | Medium | **fix-pending** | Idle-pool strategy adoption discards `creditedPrincipal`, shorting last withdrawers | run-10 |
| `59eebbf87b` | Low | open | Unbounded per-user external-call loop in `batchMigrate` + `CrossVersionMigrator.migrate` | run-14 |
| `4f143a9573` | Low | open | Migration credit asymmetry: operator `batchMigrate` books users below principal through a haircut | run-14 |
| `5975838c79` | Low | open | Batch-survival guard tests the SOURCE credit while the revert fires on the destination | run-14 |
| `2f27f8ea6f` | Low | open | NatSpec (E) and story-018 mis-attribute the uncompensated haircut to an underwater SOURCE | run-14 |
| `9abbb7b146` | Low | open | Golden-rule CI gate and `PreToolUse` hook both fail to prevent DELETION of `src/versions/…` (adjacent to Q-02) | run-14 |
| `e3553aa70b` | Low | open | story-015's snapshot-extraction ritual targets `master` HEAD rather than the deploy commit | run-14 |
| `44e66bc63c` | Low | open | `CrossVersionMigrator` has no rescue/sweep path while sibling `InPlaceMigrator` does | run-14 |
| `ss9f3-…` | Low | open | `CLAUDE.md` terminal-migration section documents the superseded active-bool model | run-14 |
| `9e9dbdc475` | QA | open | `IStableStakerV1.sol` NatSpec inaccuracies ("16 events", "Known external consumers") | run-14 |
| `4398bf5c92` | QA | open | `migrate`'s two loops iterate different bounds (`amounts.length` vs the deposit loop) | run-14 |
| `bda951d9f1` | Low | open | Poison/zero-credit user reverts the whole `migrateIn` slice | run-13 |
| `78667e8347` | Low | open | Underwater-migration operator footgun in the in-place flow | run-13 |
| `a08c8eb0b2` | Low | open | Near-`MIN_TIMEOUT` multi-batch self-exit leaves a partially-refilled pool | run-13 |
| `f0cb5f7cdd` | Low | open | `migrateIn` surplus-underfunding batch revert; no cross-slice surplus reservation | run-13 |
| `85b414ad6a` | Low | open | `InPlaceMigrator.rescueERC20` vs top-up budget coupling can brick par-restoration mid-migration | run-13 |
| `bf5018deab` | Low | open | `_reinjectWithTopup` small-principal truncation reverts the `migrateIn` slice | run-13 |
| `a56f87780b` | Low | open | `withdrawDisabled` view over-reports (raw `_isUnderwater` after story-002 added the buffer) — **⚠ EXCEPTION: this one WAS re-verified in source this run; see [Q-04](#q-04-withdrawdisabled-reports-the-pool-frozen-while-par-exits-are-in-fact-being-served-from-the-buffer). `lastSeenRun` bumped to run-15.** | run-15 |
| `d47619d29f` | Low | open | `phUSDPerDay` sub-86400-wei/day budget floors `phusdPerSecond` to 0 (silent zero emission) | run-13 |
| `ss9l1-…` | Low | open | `finalizeAndReset` revives the pool without resetting `phusdPerSecond` / re-wiring `yieldStrategy` | run-13 |
| `86fcf00ef7` | QA | open | Revived-pool permissionless-stake window before `migrateIn` (exploit refuted; emission dilution) | run-13 |
| `f84992e9ac` | QA | open | `migrateIn`'s dangling `forceApprove(staker, balanceOf)` contradicts the in-code comment | run-13 |
| `7b0717792d` | Info | open | Unused return value of `EnumerableSet.add/remove` | run-13 |
| `796f775ff3` | Info | open | `initiateMigration` writes state after the external `strategy.withdraw` call (ordering) | run-13 |

Ledger entries this run **did** touch (in-place re-weighs, proposals, and links — handled by the ledger
layer, listed here so the table above is not read as exhaustive): `0790a76a00` (re-weighed in place by
**L-04**, and it carries **no `issueId`**), `7cdb92fdc7` / `ss14l6` (narrowed in place by **L-02**;
`incompleteFixOf` target of **L-01** / `ss15l1`), `f7991b64ad` /
`ss14l8` (propose-fixed, carrying the **L-05 caveat only**), `d1aa40605d` / `ss14m1` (**split, do not
close** — fixed on V2, still live on V1 mainnet), `c8218865da` (reconciliation target for Q-02),
`69c7666eee` (linked to this run's Medium, `submissions/M-01.md`).

> **Fingerprint-drift warning.** 30 of 46 ledger entries do not reconcile on path at this HEAD (7 carry a
> `null rootCauseClass`), largely because `src/StableStaker.sol` is now `src/StableStakerV2.sol`. Re-base by
> hand on `function` + root-cause class before any ledger write. **No entry may be filed NEW or flagged
> REGRESSION on a path change alone.**

---

## Known-issues provenance — the cached KI set carries reduced authority

The known-issues set used to sanitize this run is a **cached snapshot dated 2026-06-01**, declared as
derived from `lib/stable-staker/CLAUDE.md`. That snapshot **predates the V1/V2 split**, and two of its items
no longer hold:

1. **The blanket owner-trust / centralization-by-design item is NOT re-derivable from the declared source.**
   Grepping `lib/stable-staker/CLAUDE.md` at HEAD `2146428` for `centraliz`, `owner trust`, and
   `trusted owner` returns **no matches**. The item is registry-authored, not sourced from the document it
   cites, and therefore **carries no suppression authority**. (This does not change the Law-3 outcome —
   owner-malice vectors stay suppressed on Law 3's own authority — but the KI must not be cited as the
   basis, and it must not be used to suppress the *footgun* findings L-04 and L-05.)
2. **The "strategy replacement is a documented operational requirement" item has lost its authority.** It
   describes operator discipline ("drain it first or replace only while `totalStaked == 0`"). HEAD now
   **enforces** it:

   ```solidity
   require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty");   // StableStakerV2.sol:251
   require(!_isUnderwater(token, old), "StableStaker: old strategy underwater");
   ```

   An enforced revert is not a known issue, and the item can no longer suppress findings that assume the
   un-guarded behaviour.

**Recommendation.** Re-extract the known-issues set from `lib/stable-staker/CLAUDE.md` at current HEAD
before the next run, and mark every item with the source line it derives from so registry-authored items
cannot masquerade as documented ones. Until then, treat KI-based suppression on this project as advisory.

---

## Appendix A — Automated QA / gas report (4naly3er)

Attached in full as **[`4naly3er-report.md`](./4naly3er-report.md)** (3,580 lines), generated at HEAD
`2146428` over the 7 first-party sources in scope:

```
src/CrossVersionMigrator.sol   src/InPlaceMigrator.sol   src/StableStakerV2.sol
src/interfaces/IStableStaker.sol   src/interfaces/IStableStakerMigratable.sol
src/versions/v1/IStableStakerV1.sol   src/versions/v1/StableStakerV1.sol
```

Invocation (note the tooling gotcha: **argument 3 is a SCOPE LIST, not a remappings file**, and
`remappings.txt` is resolved *relative to `basePath`* — so `basePath` must be the submodule root; a symlink
workaround does **not** work):

```bash
cd tools/4naly3er
yarn analyze /home/justin/code/audits/lib/stable-staker <scope-list>.txt
cp report.md .../reports/stable-staker/15/submissions/4naly3er-report.md
```

Headline counts:

| Class | Issues | Notable |
|---|---|---|
| Medium | 2 (30 instances) | `M-1` fee-on-transfer accounting (2) — **invalid** under C4/known-invalid; `M-2` centralization for trusted owners (28) — **suppressed under Law 3**, see the Centralization note above |
| Low | 11 (72 instances) | `L-5` external calls in an unbounded `for`-loop (2) — **already tracked** as carryover `59eebbf87b`; `L-3` missing `address(0)` checks (2); `L-11` sweeping may break accounting (4) — adjacent to L-04 above |
| Non-critical | 21 (286 instances) | Style, NatSpec `@param` gaps, event indexing, named mappings. **Not promoted** — non-critical noise is discouraged and none of it earns a place in the manual bundle |
| Gas | 14 (405 instances) | Informational only; no gas finding is asserted as a QA item |

Nothing in the automated output produced a manual finding that is not already filed above or already on the
ledger. It is attached as the standard bot-report baseline, not as a source of severity.
