# Classified Findings — stable-staker run-15

- **Project:** stable-staker · **HEAD:** `2146428` · **Baseline:** `8856781` (run-14) · **Branch:** `master` · **Mode:** REGRESSION
- **Stage:** severity-classifier (after deduplicator → sanitizer, before finding-manager)
- **Inputs:** `sanitized-findings.md` (9 surviving), `invariant-results.md` (Tier-3), `code-findings.md`, `econ-findings.md`, `faithfulness-findings.md`, `pattern-findings.md`, `manual-review.json`
- **Criteria:** C4 High(3) / Medium(2) / QA-Low, as constrained by the project's Three-Law hierarchy.
- **Not rated (parked, by instruction):** `MR-15-S1` (DEDUP-15-05's latent received-decrementing-adapter leg — C4 "speculation on future code"), `MR-15-03`, `MR-15-N2`, `MR-15-N4`, `SA-13`.

---

## 0. Headline

**0 High · 1 Medium · 4 Low · 3 QA** in `stable-staker`, plus **1 Medium routed to `reflax-yield-vault`**.

**One severity moved:** `DEDUP-15-01` **Medium → QA**, on a deterministic Tier-3 refutation. Everything else
is confirmed at its proposed value. **No REGRESSION and no INCOMPLETE-FIX** is asserted this run.

---

## 1. Summary table

| ID | Contract : function | Proposed | **Final** | C4 criterion | Moved? |
|---|---|---|---|---|---|
| **DEDUP-15-01** | `StableStakerV2 :: initiateMigration` (D3/D4) | Medium | **QA (documentation / unasserted-dependency watch)** | QA — no demonstrated impact against deployed code; residual is a documentation + cross-repo-assumption note | **YES — Medium → QA.** Refuted by Tier-3 EXHIBIT A/C; the 45,000 figure is a `MockYieldStrategy` artifact |
| **DEDUP-15-02** | `StableStakerV2 :: _routeExit` ↔ `initiateMigration` | Medium | **Medium** | Medium — value leak between user cohorts with stated assumptions + external requirements; assets not at *direct* risk | No |
| **DEDUP-15-03** | `CrossVersionMigrator :: initiateMigration` / `_migratorOf` / `_isRegisteredOn` / ctor | Low | **Low** | QA/Low — state handling + non-obvious owner footgun; freeze is recoverable, self-exit stays open | No |
| **DEDUP-15-04** | `CrossVersionMigrator :: initiateMigration` (§C) | Low | **Low** (`faithfulness: true` → `F-01`) | QA/Low — unasserted precondition (recoverable operational trap) + spec deviation (falsely-exhaustive NatSpec) | No |
| **DEDUP-15-05** | `StableStakerV2 :: initiateMigration` (469, 496–527) | Low | **Low** | QA/Low — missing bound on an irreversible step + lost observability discriminator; no demonstrated attacker-controlled path | No |
| **DEDUP-15-06** | `StableStakerV2 :: rescueERC20` | Low | **Low** | QA/Low — non-obvious owner footgun (Law 3, in scope); the swept pot is working capital, not user assets | No |
| **DEDUP-15-07** | `StableStakerV2:521` ↔ `AYieldStrategy:63` | Low | **Low** | QA/Low — unasserted cross-contract config assumption; caps the *size of a discretionary top-up*, not user principal | No |
| **DEDUP-15-08** | `.github/scripts/check-migration-surface.sh` | QA | **QA** (`faithfulness: true` → `F-02`) | QA — CI/process control under-enforces its own stated guarantee; no on-chain impact | No |
| **DEDUP-15-09** | `StableStakerV2 :: initiateMigration` / `setYieldStrategy` | QA | **QA** (`faithfulness: true` → `F-03`) | QA — compensating control named by the story does not exist; code itself is faithful | No |
| **T3-03** | `reflax-yield-vault :: AYieldStrategy._disposeShares` | (observation) | **Medium — ROUTED TO `reflax-yield-vault`** | Medium — cross-client value transfer under a supported multi-client config; stated assumptions + external requirements. **Escalates to High if a live ≥2-client-on-one-vault deployment is confirmed** | **YES — observation → Medium**, and re-homed to the sibling project |

**Plausibility:** no High is asserted, so no plausible/implausible split applies. The single Medium
(`DEDUP-15-02`) is **plausible** — permissionless, ~$5 gas, no capital, no privileged access.

---

## 2. DEDUP-15-01 — re-adjudicated against Tier-3

**Final: QA (documentation + unasserted-dependency watch-note). The Medium and the 45,000 USDC
stranded-value claim are WITHDRAWN as INVALID.**

**Why the Medium does not survive.** The finding's entire quantum came from `MockYieldStrategy.withdraw`,
which pays `amount * valueFactorBps / 10000` with no share cap. Both concretes present at the top-level
`lib/reflax-yield-vault` HEAD (`ERC4626YieldStrategy`, `ERC4626MarketYieldStrategy`) instead compute
`vault.convertToShares(amount)` and cap it to the strategy's share balance — and the swept buffer's shares
are *in* that balance, so the buffer already softens the migration through the strategy leg, before D4 ever
reads `balanceOf`. Tier-3 **EXHIBIT A** replays CODE-001's own inputs (`S = 50,000`, `T = 1,000,000`, 90 % of
par) on the real strategy and gets `R = 945,000` with `0.000000` protocol residue left behind — *exactly the
counterfactual the finding named as its mitigation's outcome*. **EXHIBIT C** reproduces `R = 900,000` on the
mock, isolating the divergence to the mock alone. The fuzzed corollary `if (P − R > 2) assertEq(residual, 0)`
holds over 5,000 runs: a materially below-par exit is share-capped, has therefore already consumed every
share, and leaves nothing for a "withdraw before relinquish" mitigation to realise. **A finding that only
reproduces on a mock is not a finding**, and this one reproduces only on a mock. Per the standing rule that a
mock-based permanence/loss result is false until re-run against the real dependency, the Medium is struck.
This is a *refutation on a deterministic exhibit*, not a green fuzz campaign, so it is load-bearing.

**What narrower true statement survives (and why it is not deleted).** Two things, both QA-tier:

1. **The code reads as if it strands value, and its safety is imported, not asserted.** `StableStakerV2`
   relinquishes `booked` with no realisation attempt and no comment explaining why that is safe. It is safe
   *only* because of a property of a sibling repo — `AYieldStrategy._disposeShares`'s `convertToShares → cap
   to available shares` prologue — that `StableStakerV2` neither reads, asserts, nor documents. That is the
   same root-cause family as DEDUP-15-07 (unasserted cross-contract assumption) and the reason DEDUP-15-05's
   floor recommendation should be kept **independently of this disposition**.
2. **The refutation has an explicit expiry.** Tier-3 §5.2 / T3-03 shows the very mechanism that makes the
   refutation work — the *global* share cap. **Corrected 2026-08-29:** T3-03 is **closed by the owner as
   intended design, not a defect** — the other clients are phUSD minters that mint without redeeming, so the
   global cap is a deliberate cushion for stable-staker's par exits, not an accounting oversight. An earlier
   version of this paragraph said the harm returns "if T3-03 is *fixed* into a per-client cap"; that is
   inverted. **Narrowing the cap to per-client would break the intended cushion.** The live expiry is a new
   concrete `IYieldStrategy` whose write-down rule differs (INV-2 shows precisely what breaks), or a
   redemption-capable client being authorized alongside stable-staker. Deleting the entry would remove the
   tripwire.

**Scope caveat, stated as required.** *The refutation is scoped to the two concrete strategies present at the
current top-level `lib/reflax-yield-vault` HEAD (`0110ce4`). It is not a statement about an arbitrary future
`IYieldStrategy`. INV-1 must be re-run against any newly-landed concrete strategy before this closure is
carried forward, and it must be re-run before any change to `_disposeShares`' cap semantics (T3-03).*

**Housekeeping this disposition requires:** the existing PoC
`test/poc/Run15_CodeScan.t.sol::test_selfHeal_destroys_the_buffer_D4_was_meant_to_spend` passes **only**
because it uses the mock, and must carry that caveat or be re-based on `ERC4626YieldStrategy`. The
DEDUP-15-01 caveat attached to the `f7991b64ad` (`ss14l8`) propose-fixed closure is **also withdrawn** — the
`ss14l8` fix *does* reach buffer already swept into the strategy, via the strategy leg. The **DEDUP-15-07
caveat on that closure stands unchanged.** Finally, the finding's proposed mitigation ("withdraw `booked`
first") must **not** be adopted: on a single-client strategy it is a no-op (INV-1), and on a multi-client one
it is a transfer *from* sibling clients (T3-03) — it recovers nothing and can cause harm.

---

## 3. Per-finding classification

### DEDUP-15-01 — self-heal relinquishes rather than realises the swept buffer
```json
{"id":"CLASS-15-01","originalId":"DEDUP-15-01","severity":"qa","plausibility":"n/a","regression":false,
 "faithfulness":false,
 "classification":{
  "assetImpact":"None demonstrated against deployed code. The claimed 45,000 USDC of stranded value does not exist on either concrete strategy at reflax HEAD; residue is exactly 0 whenever P-R>2.",
  "attackPath":["No attacker. The original path was an ordinary operational sequence, and step 4 of it produces R = 945,000, not R = 900,000, on the real strategy."],
  "likelihood":"n/a - refuted",
  "assumptions":"Refutation assumes the two concretes at lib/reflax-yield-vault HEAD 0110ce4 and their shared convertToShares-then-cap prologue.",
  "externalRequirements":"Revives if a new concrete strategy lands with a different write-down rule (INV-2), or if a redemption-capable (non-minter) client is authorized alongside stable-staker on a shared vault position. CORRECTED 2026-08-29: this previously read 'or if T3-03's global share cap is narrowed to per-client' -- T3-03 is now closed as INTENDED DESIGN, so narrowing that cap would BREAK the intended cushion rather than fix a defect, and must not be recommended."},
 "justification":"The Medium rested entirely on MockYieldStrategy's uncapped proportional withdraw; the deterministic Tier-3 exhibits show the real strategy already delivers the finding's own proposed outcome. Overstating this would be a rejection-grade error, and C4 has no category for a defect that reproduces only in a test double. What remains true is narrow and non-security: StableStakerV2's correctness here is imported from an unasserted sibling-repo property, and it is documented nowhere. That is QA-tier documentation plus a watch-note whose expiry conditions are named, not a Medium."}
```
**Justification (prose).** See §2. Retained at QA rather than marked INVALID solely because two true,
useful statements survive — the unasserted cross-repo dependency, and the named expiry conditions of the
refutation — and because deleting the entry would remove the only place those are recorded.

### DEDUP-15-02 — par-exit front-run on the migration cushion
```json
{"id":"CLASS-15-02","originalId":"DEDUP-15-02","severity":"medium","plausibility":"plausible","regression":false,
 "faithfulness":false,"linkedLedgerEntry":"69c7666eee","reRaiseOfWontFix":true,
 "classification":{
  "assetImpact":"Exact zero-sum transfer between users: on the worked example the front-runner goes 95e6 -> 100e6 and the remaining cohort goes 855e6 -> 850e6. Protocol balance sheet unaffected (B2 is spent either way).",
  "attackPath":["1. Strategy goes below par (depeg / impairment).",
    "2. Operator broadcasts initiateMigration (or CrossVersionMigrator.initiateMigration).",
    "3. Any staker whose position <= B2 front-runs the mempool with withdraw(full position).",
    "4. _routeExit's underwater branch pays them at par out of B2 and relinquishes the claim without moving shares.",
    "5. initiateMigration snapshots R = balanceOf(this) against a B2 reduced by exactly that payout; every remaining staker's pro-rata credit falls."],
  "likelihood":"medium-high within the window - permissionless, no capital, no flash loan, ~$5 of gas, profitable above roughly $1k of position at a 5% haircut; rationed FCFS by B2 size, so it is a race rather than an unbounded drain.",
  "assumptions":"The pool is below par at migration time; B2 is non-zero; the attacker's position fits within remaining B2; the migration transaction is visible in the mempool.",
  "externalRequirements":"An underwater strategy AND a broadcast migration. Exposure is STRICTLY the pre-Migrating window: Tier-3 INV-3 proved that once Migrating is latched, allocation is pro-rata and bit-identical under any batch composition or ordering, so there is no in-Migrating leg."},
 "justification":"Medium, confirmed on the merits and independently of the prior triage."}
```
**Justification (prose).** This sits exactly on the C4 Medium line and does not cross it. Against Medium:
the transfer is real, quantified, permissionless, essentially free, and needs no privileged access — a
concrete value leak with a demonstrated mechanism. Against High: nothing is stolen from the protocol and
nothing is taken from a victim's own balance. The front-runner withdraws *their own principal* through a path
the protocol deliberately offers while `Active`; the harm is the delta between two legitimate allocation
rules (par/FCFS vs pro-rata) applied to one pot, it is hard-bounded by `B2` (working capital, not a solvency
reserve), and it materialises only under two external conditions the attacker does not control. That is
textbook "value leak with stated assumptions but external requirements" → **Medium**, not High.
On the re-raise: judged here purely on merits, and the merits are unchanged by the prior `wont-fix`. It is
worth recording *why* the closure is stale rather than the closure being wrong — its `triageReason` rested on
"there is no incremental victim (the slow staker is baseline-unchanged vs a no-buffer world)", which was true
under V1 (the buffer never entered the migration payout) and was falsified by story-020 (`R = balanceOf(this)`
puts B2 in the pro-rata pool). The un-disputed first clause of the closure stands. **Route to `/ledger` for
human re-triage linked to `69c7666eee`; do not file as a naive new discovery and do not override the owner's
`reclassNote`.** The recommended mitigation is the zero-code-change runbook step
`pause() → initiateMigration() → unpause()` (`withdraw` is `whenNotPaused`, `initiateMigration` is not),
which is strictly narrower than the two fixes the owner previously rejected.

### DEDUP-15-03 — CrossVersionMigrator pre-flight fails open on a codeless destination
```json
{"id":"CLASS-15-03","originalId":"DEDUP-15-03","severity":"low","plausibility":"n/a","regression":false,
 "faithfulness":false,"incompleteFixOf":"7cdb92fdc7","footgun":true,
 "classification":{
  "assetImpact":"None. No value moves. The source pool latches Migrating against a destination that does not exist.",
  "attackPath":["1. Owner passes a typo'd / wrong-network / not-yet-deployed destination address.",
    "2. The staticcall probe to a codeless address returns ok == true with short data, so _migratorOf and _isRegisteredOn each waive themselves.",
    "3. initiateMigration proceeds; the source pool freezes into the one-way Migrating state with emissions stopped.",
    "4. Recovery: oldStaker.setMigrator re-points the migrator (demonstrated in the PoC); userMigrate remains a permissionless self-exit throughout."],
  "likelihood":"low-moderate - requires an owner input error, but the wiring mistake it fails open against is the single most likely one, and the guard reads as though it catches it.",
  "assumptions":"Non-malicious owner making an ordinary configuration error.",
  "externalRequirements":"None beyond the owner action."},
 "justification":"Recoverable operational freeze, no asset loss - Low."}
```
**Justification (prose).** A genuine Law-3 footgun and not a "reckless admin mistake": the consequence is
non-obvious precisely because the contract appears to validate the destination and silently does not, so a
competent non-malicious owner would be surprised. It is not Medium: no assets are at risk, and the
availability impact is bounded and recoverable — one owner transaction re-points the migrator, and
`userMigrate` stays open for every user in the meantime, so nobody is trapped. Per the standing calibration, a
recoverable operational freeze with the self-exit still open is not asset loss. Filed as an **incomplete fix
of `7cdb92fdc7`** with its own root-cause class (`fail-open-existence-check`) so the two do not collide on one
fingerprint. The fix is a constructor `code.length` guard.

### DEDUP-15-04 — destination preconditions unasserted; §C's "uncheckable" claim is false
```json
{"id":"CLASS-15-04","originalId":"DEDUP-15-04","severity":"low","plausibility":"n/a","regression":false,
 "faithfulness":true,"specConformanceLabel":"F-01","inPlaceReweighOf":"7cdb92fdc7","newFingerprint":false,
 "classification":{
  "assetImpact":"None. A destination already in Migrating reverts every depositFor in the SECOND owner transaction, after the source has been frozen.",
  "attackPath":["1. Owner initiates a cross-version migration to a destination whose poolState is not Active.",
    "2. Source freezes (tx 1 succeeds); depositFor reverts 'StableStaker: pool not active' (tx 2).",
    "3. Source sits in Migrating with emissions frozen while the owner fixes the destination; userMigrate remains available to every user."],
  "likelihood":"low - an operational sequencing error, not an attack.",
  "assumptions":"Non-malicious owner; destination pool in a non-Active state at migrate time.",
  "externalRequirements":"None."},
 "justification":"Low, and separately a genuine spec deviation that must not be buried in the QA bundle."}
```
**Justification (prose).** Two legs, correctly weighted. The **pool-state** leg is a real post-freeze
operational trap but is recoverable with users' self-exit intact → Low, exactly as the recoverable-freeze
calibration prescribes. The **minter** leg is a documentation defect only: `_settle` mints only
`if (user.amount > 0)` and a migrating user's destination position is fresh, so `depositFor` mints nothing and
does not need the destination to be an authorized minter at all; F-03's "surfaces only after the source is
frozen" framing is struck. Severity is *not* reduced below Low by the in-source NatSpec: §C's claim that the
minter precondition is "uncheckable from here" is factually false at HEAD (`phUSD` is public on both shapes;
`FlaxToken.authorizedMinters` / `mintVersion` are external views, so the two-hop probe is constructible), and
per the standing rule a falsely-exhaustive in-source claim carries **no suppression authority and raises
severity rather than lowering it**. **Tagged `faithfulness: true` and routed to `spec-conformance.md` as
`F-01`** in addition to the QA report — a story/spec deviation is never bundled into QA noise. This is an
**in-place re-weigh of `7cdb92fdc7`: narrow it, do not close it, do not mint a new fingerprint.**

### DEDUP-15-05 — no minimum-realisation floor on the irreversible step (demonstrated leg only)
```json
{"id":"CLASS-15-05","originalId":"DEDUP-15-05","severity":"low","plausibility":"n/a","regression":false,
 "faithfulness":false,"ratedLegs":["discarded _routeExit return value (:469)","no floor on R before the one-way Migrating latch"],
 "notRated":["MR-15-S1 - received-decrementing custody adapter (C4 speculation on future code; PARKED, must not influence this rating)"],
 "classification":{
  "assetImpact":"No value is created or destroyed by the defect itself. The exposure is that a terminal, irreversible migration can latch at ANY R, including 0, with no lower bound and no revert.",
  "attackPath":["1. _routeExit(token, P, false) is called and its return value is DISCARDED at :469.",
    "2. ERC4626YieldStrategy._disposeShares redeems with no minimum out; whatever the vault delivers in that block is what lands.",
    "3. _withdrawInternal debits the REQUESTED (capped) amount, so booked == 0 and the 'incomplete exit' post-check is satisfied by construction - the discriminator that could have caught this was thrown away one line earlier.",
    "4. PrincipalDivergence(token, P, 0, 0) is emitted - byte-identical to a clean migration - and the pool latches the one-way Migrating state.",
    "5. Every staker is then locked to userMigrate at that haircut: withdraw and emergencyWithdraw are both Active-gated."],
  "likelihood":"low - requires a genuinely impaired vault at that block; no attacker-controlled path was demonstrated, and Tier-3 found no sandwich or manipulation leg.",
  "assumptions":"Under-delivery originates in the external vault, i.e. it is market loss on externally-derived capital, not a protocol value leak.",
  "externalRequirements":"An impaired or illiquid ERC4626 vault at the migration block."},
 "justification":"Missing bound on an irreversible step plus lost observability - Low."}
```
**Justification (prose).** Rated on the demonstrated leg only, as instructed. This is defensive hardening and
observability, not a live loss vector: the shortfall is external market loss on the vault position, which the
standing calibration forbids rating as a protocol value leak, and no attacker-controlled route to force it was
found. What is genuinely reportable is that the *only* discriminator capable of supplying a floor is
deliberately discarded, that the resulting event payload is indistinguishable from a clean migration, and that
the step is irreversible with no user opt-out. Tier-3 **T3-02 confirms this residual as filed** and states the
mitigation should be kept **regardless of DEDUP-15-01's disposition** — it is what stops a future adapter from
silently deleting the floor, which is exactly the risk INV-2 exhibits. One-line fix:
`uint256 delivered = _routeExit(token, P, false); require(booked == 0 || delivered + booked >= P, "StableStaker: exit shortfall");`
plus emitting `delivered`. **The latent received-decrementing-adapter leg (`MR-15-S1`) is NOT rated here** and
contributed nothing to this severity; it stays parked and re-enters scope the day such an adapter ships.

### DEDUP-15-06 — `rescueERC20` reserves nothing while a strategy is set
```json
{"id":"CLASS-15-06","originalId":"DEDUP-15-06","severity":"low","plausibility":"n/a","regression":false,
 "faithfulness":false,"footgun":true,"inPlaceReweighOf":"0790a76a00","newFingerprint":false,
 "classification":{
  "assetImpact":"The sweep removes B2 - protocol working capital - from the contract. Users' consequence is a larger haircut at a later below-par migration than they would otherwise have received, i.e. the loss of a discretionary protocol-funded top-up, not the loss of their own principal.",
  "attackPath":["1. Owner reads rescueERC20's NatSpec, which asserts the contract balance is 'purely buffer + dust' and cannot touch user value.",
    "2. Owner performs a routine dust sweep while a strategy is set (rescueERC20 reserves totalStaked only when no strategy is set).",
    "3. Days later a below-par terminal migration measures R = balanceOf(this) against a B2 that is now gone, converting a par migration into a haircut migration."],
  "likelihood":"moderate - a routine operational action, actively encouraged by documentation that was accurate before story-020 and is incomplete after it.",
  "assumptions":"Non-malicious owner. Malicious-owner variants are suppressed under Law 3 and are NOT filed.",
  "externalRequirements":"A subsequent below-par terminal migration."},
 "justification":"Non-obvious footgun over working capital - Low, and deliberately not inflated."}
```
**Justification (prose).** In scope as a Law-3 footgun and not suppressible: the owner is not merely unwarned
but actively misled by the contract's own NatSpec, so surprise is manufactured rather than merely likely, and
KI#8 (the only candidate suppressor) has no authority. It is nevertheless **Low, not Medium**, and the reason
is the standing framing: **B2 is working capital, not a solvency reserve.** No staker was ever entitled to it,
nothing sizes it against outstanding principal, and `rescueERC20` may sweep it at the owner's discretion by
design. Losing a discretionary protocol-funded top-up is not a user loss, and rating the headline swing
figure as economic loss would be exactly the overstatement this pipeline rejects. The reportable defect is the
misleading NatSpec plus the missing runbook linkage. **In-place impact re-weigh of `0790a76a00` — same
fingerprint, do not re-file.** Fix is NatSpec + runbook (optionally, reserve `min(R, P)` while `Migrating` is
reachable).

### DEDUP-15-07 — the `ss14l8` cushion is only as large as an unasserted off-chain config
```json
{"id":"CLASS-15-07","originalId":"DEDUP-15-07","severity":"low","plausibility":"n/a","regression":false,
 "faithfulness":false,"footgun":true,"crossRepoDependency":"lib/reflax-yield-vault :: AYieldStrategy.setAsideBufferRecipient (:63)",
 "classification":{
  "assetImpact":"None directly. A single off-chain address, set once on the strategy, silently determines whether the ss14l8 fix delivers its promised cushion or approximately zero.",
  "attackPath":["1. setAsideBufferRecipient is pointed at a treasury rather than at the staker.",
    "2. The set-aside buffer therefore never arrives on StableStakerV2's own balance.",
    "3. StableStakerV2:521 reads R = balanceOf(this) and measures a cushion of ~0; nothing anywhere reads or asserts the recipient."],
  "likelihood":"moderate - one address, set once, on a different contract in a different repo, with nothing in the runbook connecting the two.",
  "assumptions":"Non-malicious owner; a below-par terminal migration to make the shortfall visible.",
  "externalRequirements":"Configuration lives in the sibling repo and is invisible from stable-staker."},
 "justification":"Unasserted cross-contract assumption capping a discretionary top-up - Low."}
```
**Justification (prose).** Same ceiling logic as 15-06: what is at stake is the *size of a protocol-funded
cushion*, not user principal, so it cannot be rated as loss. What makes it a real footgun rather than noise is
that the staker never reads and never asserts the value its own advertised fix depends on, and the failure is
completely silent. Kept **separate** from 15-01 and 15-06 (different site, different actor, different
mechanism, non-overlapping mitigation). **This is the caveat that must accompany the `f7991b64ad` (`ss14l8`)
propose-fixed closure** — and after §2 it is now the *only* caveat on that closure, since the DEDUP-15-01
caveat is withdrawn. Fix: a view on the strategy plus an assertion (or at minimum a documented runbook check)
that `setAsideBufferRecipient == address(staker)`.

### DEDUP-15-08 — frozen-V1 CI gate under-enforces its own stated guarantee
```json
{"id":"CLASS-15-08","originalId":"DEDUP-15-08","severity":"qa","plausibility":"n/a","regression":false,
 "faithfulness":true,"specConformanceLabel":"F-02","overlaps":"c8218865da (leg 2 first half)","adjacent":"9abbb7b146",
 "classification":{
  "assetImpact":"None on chain. The gate is a process control over src/versions/**.",
  "attackPath":["Instance 1: on a host without GNU sha256sum the hash verification is skipped with `status` untouched, so an EDITED frozen V1 passes green with only a note on stderr.",
    "Instance 2: the script never reads a commit message (exit $status is unconditional), so GOLDEN-RULE-OVERRIDE is unimplemented; and editing a frozen file while regenerating FROZEN.sha256 in the same change satisfies every check, because manifest_count != 2 rejects only an emptied or extended manifest, never a re-pinned one."],
  "likelihood":"low on CI (ubuntu-latest has sha256sum); the exposure is the local / pre-commit path the story itself directs developers to.",
  "assumptions":"None.",
  "externalRequirements":"A developer running the gate locally, or a same-commit edit-plus-re-pin."},
 "justification":"Process-control weakness plus a false in-source claim - QA, and a Law-2 deviation."}
```
**Justification (prose).** QA is the honest rating: nothing on chain changes, and the gate is a
defence-in-depth layer over deliberately frozen files. It earns its place in the report for two reasons.
First, the script's own banner claims "a mismatch is a hard failure … the ONLY deliberate way past this gate
is `GOLDEN-RULE-OVERRIDE`", which is false in both instances — a **Law-2 deviation**, so this is tagged
`faithfulness: true` and routed to `spec-conformance.md` as **`F-02`** rather than buried in the QA/gas
bundle. Second, CLAUDE.md's disclosed "Known gap" (N7) is scoped to enforcement **layer 2** (the `PreToolUse`
hook) and does not reach **layer 3** (this CI script), of which the same document claims "no blind spot" — so
the disclosure does not suppress it. Note the standing link: this gate is the *sole* enforcement of the
invariant "V1 must never gain a `STAKER_VERSION` getter" that parked `MR-15-03` depends on. Leg 2's first half
should be **reconciled against open QA `c8218865da`**, not double-filed; the `sha256sum`-absent skip and the
same-commit re-pin bypass are genuinely new.

### DEDUP-15-09 — story-020's compensating controls are nominal
```json
{"id":"CLASS-15-09","originalId":"DEDUP-15-09","severity":"qa","plausibility":"n/a","regression":false,
 "faithfulness":true,"specConformanceLabel":"F-03",
 "classification":{
  "assetImpact":"None. The code is faithful to story-020; what is missing is the off-chain half the story itself names as the thing that makes its new silence safe.",
  "attackPath":["Instance 1: story-020 specifies the monitoring rule verbatim and states 'Nobody owns that alert yet'; the story carried that as its own [medium] and auto-completed anyway, so the bound on the fail-open conversion is currently vacuous.",
    "Instance 2: the sole test proving the 'incomplete exit' tripwire still trips (test_postCheck_incompleteExitReverts) depends on UnderRealizingStrategy.relinquishPrincipal being a NO-OP STUB (test/Migration.t.sol:845) - the tripwire has no conforming-strategy coverage."],
  "likelihood":"n/a - a control gap, not an exploit.",
  "assumptions":"None.",
  "externalRequirements":"None."},
 "justification":"Unsatisfied acceptance condition - QA, filed under Law 2."}
```
**Justification (prose).** The Law-1 override was tested and did not trigger: the harm hypothesis (the
self-heal writing down user-claimable principal) is refuted against the real dependency, since
`_withdrawInternal` debits the requested amount and residual `booked` after `_routeExit(P)` is exactly the
sweep excess — protocol money by the empty-pool gate. So this is a **Law-2 item at QA**, tagged
`faithfulness: true` and routed to `spec-conformance.md` as **`F-03`**. Instance 2 is recorded under this
project's standing precedent that a no-op mock stub can fake a permanence result — the same defect class
Tier-3 was built to avoid, and the reason the tripwire's coverage claim should not be trusted as written.
Process context (parked `MR-15-N2`): story-020 sat in the unenumerated `auto-complete/` state and
auto-completed carrying its own `[medium]`, so no human ratification step existed at which that would have
become a follow-on story.

---

## 4. Cross-repo finding — T3-03 · **belongs to `reflax-yield-vault`, NOT `stable-staker`**

> **ROUTING NOTICE.** This finding's root cause is in `lib/reflax-yield-vault` (`AYieldStrategy` and its
> concretes) at HEAD `0110ce4`. It must be filed on the **`reflax-yield-vault` ledger**
> (`reports/ledgers/reflax-yield-vault.json`), not on `stable-staker`'s. It is recorded here only so it is
> not lost between projects, and because it is the mechanism that makes INV-1 pass — **it must not be
> "fixed" without re-running INV-1 and re-opening DEDUP-15-01.**

```json
{"id":"CLASS-15-X1","originalId":"T3-03","project":"reflax-yield-vault","severity":"medium",
 "plausibility":"plausible","regression":false,"faithfulness":false,
 "escalationTrigger":"HIGH if a live deployment is confirmed with >=2 authorized clients sharing one vault position",
 "classification":{
  "assetImpact":"One client's exit is satisfied out of a sibling client's backing. Tier-3 EXHIBIT D: with a sibling holding 1,000,000 alongside the staker's 1,000,000 and a 40% loss on the combined position, the staker exits AT PAR and the sibling goes 600,000 -> 200,000.000001. The entire realised loss lands on the client that did not move.",
  "attackPath":["1. Two or more authorized clients share one AYieldStrategy over one ERC4626 vault (a first-class supported configuration - _authorizedClients is an EnumerableSet with authorizedClientCount()).",
    "2. The combined vault position falls below par.",
    "3. Client A withdraws or exits. _disposeShares computes vault.convertToShares(amount) and caps it at vault.balanceOf(address(this)) - the strategy's TOTAL share balance, not client A's pro-rata slice.",
    "4. Client A is therefore paid at or near par out of shares that back client B.",
    "5. Client B's remaining claim is now backed by whatever shares survive; its users absorb the whole loss."],
  "likelihood":"medium - no malice and no special tooling required; the first client to exit wins, which creates a standing bank-run incentive between clients whenever a shared position is impaired.",
  "assumptions":"At least two authorized clients on one strategy over one shared vault position; that position below par. Multi-client is explicitly supported by the base contract, but this classification does NOT assert that such a deployment is live today - that must be verified in reflax-yield-vault before finalising severity.",
  "externalRequirements":"An impaired shared vault position, and a multi-client strategy configuration."},
 "justification":"Medium now, High if a live multi-client-on-one-vault deployment is confirmed."}
```
**Justification (prose).** The mechanism is proved by a deterministic exhibit, not a fuzz campaign, and the
loss is real, large and lands on a party that took no action — that is squarely asset compromise via a valid
attack path, with no hand-wavy hypotheticals in the mechanism itself. It is rated **Medium rather than High
only because of an unverified precondition**: the harm needs at least two authorized clients sharing one vault
position, and while `AYieldStrategy` supports that as a first-class configuration (`_authorizedClients` is an
`EnumerableSet`, with `authorizedClientCount()` and `authorizedClientList()` on the public surface), this
classification could not confirm from `stable-staker` that such a deployment is live. Per the "when uncertain,
classify lower" rule that makes it a value leak with stated assumptions and external requirements → Medium,
carrying an **explicit escalation trigger: confirm the deployed client set per strategy per token in
`reflax-yield-vault`; if any strategy has ≥2 authorized clients over one vault, re-classify as High.**
Two consequences must travel with it: (a) **SUPERSEDED 2026-08-29 —** it is the mechanism behind INV-1's PASS,
and this paragraph previously said narrowing the cap to a per-client slice "re-opens DEDUP-15-01 and requires
INV-1 to be re-run", implying per-client capping is the fix. The owner has since closed T3-03 as **intended
design**: narrowing the cap would **break the deliberate cushion**. Any change to `_disposeShares`' cap
semantics remains an INV-1 re-run trigger, but as a departure from intent, not a remedy; and (b) it independently kills
CODE-001's proposed "withdraw `booked` before relinquishing" mitigation, which on a multi-client strategy
would be a transfer *from* siblings rather than a recovery of stranded value.

---

## 5. Routing and downstream instructions

**Submissions (`submissions/<label>.md`, one per High/Medium, PoC required):**
- `M-01` ← `DEDUP-15-02`. Must carry the disclosure block verbatim (prior entry `69c7666eee` named, its
  `triageReason` quoted, the re-file basis stated, the un-disputed first clause conceded, `reclassNote` not
  overridden) and be **linked to `69c7666eee`, never filed as a naive new discovery**. Flagged for human
  re-triage at `/ledger`.

**Spec-conformance report (`spec-conformance.md`) — Law 2, never bundled into QA noise:**
- `F-01` ← `DEDUP-15-04` (§C NatSpec "uncheckable from here" is factually false; 2 of 5 preconditions asserted)
- `F-02` ← `DEDUP-15-08` (script banner over-states the gate's guarantee; `GOLDEN-RULE-OVERRIDE` unimplemented)
- `F-03` ← `DEDUP-15-09` (story-020's named compensating controls do not exist)

**QA report (`qa-report.md`) — Low + QA:** `DEDUP-15-01` (QA), `DEDUP-15-03`, `DEDUP-15-04`, `DEDUP-15-05`,
`DEDUP-15-06`, `DEDUP-15-07` (Low); `DEDUP-15-08`, `DEDUP-15-09` (QA). The three faithfulness items appear in
the QA bundle **in addition to**, never instead of, their `F-xx` entries.

**Cross-repo:** `T3-03` → `reflax-yield-vault` ledger as a Medium with the escalation trigger above.

**Ledger handling (unchanged from sanitizer, restated so it is not lost):**
- **No new fingerprint** for `DEDUP-15-04` (in-place narrowing of `7cdb92fdc7`) or `DEDUP-15-06` (in-place
  re-weigh of `0790a76a00`).
- `DEDUP-15-03` is `incompleteFixOf` `7cdb92fdc7` with its own root-cause class.
- `f7991b64ad` (`ss14l8`): **propose-fixed only**, closed with the **DEDUP-15-07 caveat only** — the
  DEDUP-15-01 caveat is withdrawn per §2.
- `d1aa40605d` (`ss14m1`): **SPLIT, do not close** — fixed on V2, still live on V1 mainnet.
- `dab5a65613`: sole `fix-pending`, not re-flagged this run — **carry forward in full, keep `fix-pending`,
  propose nothing.**
- **Fingerprint drift:** 30 of 46 entries cannot reconcile on path (7 with `null rootCauseClass`). Re-base by
  hand on `function` + root-cause class and diff against the start-of-run snapshot before any ledger write.
  **No entry may be filed NEW or flagged REGRESSION on a path change alone.**

**Not rated, by instruction:** `MR-15-S1`, `MR-15-03`, `MR-15-N2`, `MR-15-N4`, `SA-13` — all remain visibly
parked in `manual-review.json`.
