# Spec-Conformance Report (Law 2 — Story Faithfulness)

**Project:** yield-claim-nft
**Run:** yield-claim-nft-10
**Audited commit:** `cf75ec9520fd16b19e20c4b77ada2be28d7d4382`
**Scope:** Deviations between implemented behavior and the intent recorded in
`[story-NNN]` commit messages and in-file NatSpec.

> This report is **separate from the QA/Low bundle** by design. Faithfulness is **Law 2**
> (features must do what their story says); QA/Low is severity triage of state-handling
> issues. A deviation appears here whenever implemented behavior diverges from a documented
> story/spec, *regardless* of whether it also carries asset/value impact. Where a deviation
> additionally has Law-1 security/value impact, that impact is tracked under its own
> `L-`/`DEDUP-` id and cross-referenced below — the faithfulness entry is the spec-conformance
> half of the same issue, not a duplicate.
>
> No design docs exist in this repo (README is the Foundry template). Story intent was
> recovered solely from `[story-NNN]` commit bodies, in-file NatSpec, and the project
> registry. No acceptance criteria were invented.

| ID | Story | Deviation | Carries Law-1 security/value impact? | Cross-ref |
|------|-----------------------|-----------------------------------------------------|--------------------------------------|----------------------|
| F-01 | story-030 / `924b188` | `ratio` cap docstrings say `< 50`; code permits `== 50` | No — pure spec-conformance (stale/self-contradictory spec) | ledger L-02 / DD-02 |
| F-02 | story-034 (+ story-030)| No on-chain coupling of `batchDonationSize` + `ratio` | Yes — but the security claim is suppressed OOS | L-05 (guardrail) / **DEDUP-001** (suppressed) |
| F-03 | story-022             | `mintFor` ignores `config.disabled` ("new mints are blocked") | No — pure spec-conformance footgun (Low op-hazard only) | L-04 |

---

## F-01 — `ratio` invariant: docstrings/story say strictly `< MAX_RATIO`; code permits `== MAX_RATIO`

- **Derived from:** story-030 (commit `c94bf40`), later mutated by `924b188` ("raised ratio because sUSDS appreciation")
- **Finding refs:** FAITH-001 · ledger **L-02** / DD-02
- **Location:** `src/V2/hooks/BalancerPoolerMintDebtHook.sol#L23-L82` (constructor L66-L73, `setRatio` L77-L82)
- **Classification:** **Pure spec-conformance.** No demonstrated security or value impact.

### What the spec says

story-030 commit body (`c94bf40`), "Key design points":

> * `ratio` is `uint8`, seeded to `DEFAULT_RATIO = 30`, strictly
>   capped below `MAX_RATIO = 50`.

In-file NatSpec at HEAD reinforces the strict-less-than invariant in three places:

> `/// @notice Exclusive upper bound on `ratio`. Max settable ratio is `MAX_RATIO - 1`.` (L23)
>
> `/// @notice Percentage of dispatched USDS that becomes debt. Strictly `< MAX_RATIO`.` (L42)
>
> `/// @param  newRatio Must be strictly less than `MAX_RATIO` (50).` (L76)

### What the code actually does

The constant and the default were changed without updating any of the prose:

```solidity
uint8 public constant MAX_RATIO = 50;      // L24 — but the docstring above it still says "exclusive"
uint8 public constant DEFAULT_RATIO = 50;  // L27 — equals MAX_RATIO
...
ratio = DEFAULT_RATIO;                      // L71 — constructor seeds ratio == 50 == MAX_RATIO
...
function setRatio(uint8 newRatio) external onlyOwner {
    if (newRatio > MAX_RATIO) revert RatioTooHigh();   // L78 — rejects only > 50, so 50 is accepted
```

So the constructor seeds `ratio == MAX_RATIO`, and `setRatio` admits any `newRatio` in
`[0, 50]`. Commit `924b188` deliberately raised `DEFAULT_RATIO` 30 → 50 and relaxed the
bound from `>= MAX_RATIO` to `> MAX_RATIO`, but left every "strictly `< MAX_RATIO`"
docstring and the story-030 statement untouched.

### The gap

The documented invariant (`ratio` strictly `< 50`, i.e. max settable `49`) is violated by
both the constructor default (50) and by `setRatio` (50 is reachable). The Halmos-proved
reachable set for `ratio` is `[0, 50]`, contradicting the "exclusive upper bound / max
`MAX_RATIO - 1`" prose. The spec is now **internally self-contradictory** — the comments
and story say `< 50`, the code permits `== 50`. Under the conflicting-sources rule, the
stale/ambiguous spec *is* the finding.

### Impact

None demonstrated. At `ratio == 50` with the default donation configuration disabled,
100% of dispatched USDS is pooled as sUSDS backing while only 50% is accrued as phUSD
mint-debt — phUSD is over-backed ~2:1, which is exactly the appreciation-driven rationale
`924b188` cites for the raise. The hazard is a stale invariant misleading a future
reviewer or integrator about the true cap, not a live exploit.

### Recommendation

Reconcile spec and code. Either (a) re-tighten `setRatio` to `revert` on
`newRatio >= MAX_RATIO` and lower `DEFAULT_RATIO` below 50, **or** (b) update the three
docstrings + the `DEFAULT_RATIO` comment to state that 50 is the valid maximum and drop
the "exclusive upper bound" / "`MAX_RATIO - 1`" wording. Bring story-030's statement into
agreement with whichever is chosen.

---

## F-02 — story-034 accrues mint-debt on GROSS USDS but exports a donation slice with no on-chain coupling of the two knobs

- **Derived from:** story-034 (commit `cf75ec9`), interacting with story-030's `ratio`
- **Finding refs:** FAITH-002 · operator-guardrail leg → **L-05** · the unbacked-phUSD *security* claim → **DEDUP-001 (suppressed, OOS)**
- **Location:** `src/V2/dispatchers/BalancerPoolerV2.sol#L202-L232` (`_dispatch`; gross-accrual NatSpec L198-L200), `setBatchDonationSize` L160-L164; coupled knob `BalancerPoolerMintDebtHook.setRatio` L77-L82
- **Classification:** **Faithful implementation of an under-specified design.** Carries a **Law-1 security/value dimension, but that dimension is OOS and hard-suppressed under DEDUP-001** — it is *not* re-litigated here. The in-scope surviving leg is the missing operator guardrail (L-05).

### What the spec says

story-034 commit body (`cf75ec9`):

> - Move donation into _dispatch: wrap pooling portion to sUSDS, sweep raw USDS,
>   convert USDS->USDC via Sky PSM buyGem straight to batchMinter

`_dispatch` NatSpec (L198-L200) makes the gross-accrual choice explicit:

> The base class then calls `hook.onDispatch(minter, amount)`
> with the **gross** amount, so mint-debt accrues on the full dispatched USDS
> regardless of donation outcome.

### What the code actually does

The story is **faithfully implemented** — this is not an implementation gap:

```solidity
uint256 donationUSDS = donationEnabled ? (amount * batchDonationSize) / 100 : 0;  // L212
uint256 poolingUSDS = amount - donationUSDS;                                       // L213
// only poolingUSDS is wrapped to sUSDS and retained as backing (L216-L219)
// donationUSDS is swept and shipped out to batchMinter via the PSM (L221-L231)
```

The hook then accrues phUSD mint-debt on the **gross** `amount` (`(amount * ratio)/100`,
hook L111), which `pull()` later mints. The two parameters that jointly determine backing
live in **separate contracts with separate owner setters and no on-chain link**:
`BalancerPoolerV2.setBatchDonationSize` (cap `<= 100`, L160-L164) and
`BalancerPoolerMintDebtHook.setRatio` (cap 50, L77-L82).

### The gap

story-034 is faithful, but the story's own design leaves the safe envelope
(`batchDonationSize + ratio <= 100`) **unenforced on-chain**. phUSD is minted at `ratio%`
of gross while only `(100 - batchDonationSize)%` of that same USDS is retained as backing,
so any owner configuration with `batchDonationSize + ratio > 100` under-retains backing
relative to debt minted. Nothing on-chain rejects or even links the two knobs, and they
sit in different contracts — a non-obvious cross-contract parameter interaction (Law-3
footgun, in scope). Default config (donation disabled, `ratio 50`) is over-backed ~2:1, so
the design is **safe under sane/default settings**; the under-backing is a
parameter-interaction hazard, not an unconditional unsafe story.

### Impact

**Two-layered, and the layers are deliberately separated:**

- **In scope (reported as L-05):** the *missing on-chain invariant* — the operator
  guardrail. A competent, non-malicious owner would be surprised that two independently
  capped knobs in two different contracts can silently sum past the solvency boundary with
  no on-chain guard or warning. This is the surviving, classified finding.
- **Out of scope / suppressed (DEDUP-001):** the downstream "phUSD becomes unbacked / value
  leaks from the backing model" *security* claim. Per ledger entry DEDUP-001 it is
  hard-suppressed as an owner-driven, out-of-scope external phUSD-backing-model speculation
  (KI-1/KI-4), corroborated by econ-scanner REFUTE-A (backing arithmetic unchanged from the
  pre-story-034 baseline) and the Tier-3 invariant run (no permissionless trigger).
  **It is tracked there and is not re-asserted in this report.**

### Recommendation

Couple the two knobs — enforce `batchDonationSize + ratio <= 100` through a shared
validation path on both setters, **or** accrue mint-debt on the net `poolingUSDS` rather
than the gross `amount` — and/or document the backing invariant the owner must preserve.

---

## F-03 — `mintFor` (privileged) ignores `config.disabled`, contradicting the flag's documented "new mints are blocked" semantics

- **Derived from:** story-022 (commit `7791933`)
- **Finding refs:** FAITH-003 · ledger **L-04**
- **Location:** `src/V2/NFTMinterV2.sol#L206-L214` (`mintFor`); `disabled` semantics at struct comment L24 + permissionless guards in `_executeMint` L171-L174; parallel privileged `burn` L341-L345
- **Classification:** **Pure spec-conformance** (Low operational hazard). No fund movement; no Law-1 asset/value cross-reference.

### What the spec says

story-022 commit body (`7791933`):

> - Add authorizedMinters mapping and mintFor() for privileged minting

The `disabled` flag's documented semantics, `DispatcherConfig` struct (L24):

> `bool disabled; // if true, new mints are blocked but existing NFTs remain valid`

The permissionless mint path honors both `paused` and `disabled` (`_executeMint`, L171-L174):

```solidity
require(!paused, "Contract is paused");                                  // L171
DispatcherConfig storage config = configs[index];
require(config.dispatcher != address(0), "NFTMinterV2: index not registered");
require(!config.disabled, "NFTMinterV2: dispatcher is disabled");         // L174
```

### What the code actually does

`mintFor` enforces **only** the authorization gate and index registration — neither
`paused` nor `config.disabled`:

```solidity
function mintFor(uint256 index, address recipient) external {
    require(authorizedMinters[msg.sender], "NFTMinterV2: caller is not authorized minter");  // L207
    require(configs[index].dispatcher != address(0), "NFTMinterV2: index not registered");   // L208
    _mint(recipient, index, 1, "");                                                          // L211
    ...
}
```

The privileged `burn` (L341-L345) is likewise unguarded by `paused`/`disabled` (gated only
to `authorizedBurners`).

### The gap — two sub-points, only one is a deviation

1. **Pause-bypass (deliberate, faithful — NOT a deviation):** `mintFor` is the privileged
   migration primitive (the `NFTMigrator` is the only wired `authorizedMinter`). The
   reverted story-033 explicitly justified a pause-exempt migration path ("migrations are a
   one-shot cleanup and must remain executable even if the standard mint path is paused").
   Bypassing `paused` is therefore consistent with the owner's stated migration design and
   is treated as intended.
2. **Disabled-bypass (the actual deviation):** **No story authorizes ignoring
   `config.disabled`,** and doing so contradicts the flag's documented semantics ("new mints
   are blocked"). An owner who sets `configs[index].disabled = true` to block new mints
   would be surprised that the privileged path keeps minting that index. This is the
   non-obvious footgun that survives.

### Impact

Low. `mintFor`/`burn` are gated to owner-set `authorizedMinters`/`authorizedBurners`
(trusted roles — a malicious authorized minter is owner misconfiguration, out of scope
under Law 3). No payment or dispatch occurs and `mintFor` issues exactly 1 claim NFT, so
there is **no fund movement and no net inflation** — supply stays 1:1 against the migration
intent. The residual issue is a **kill-switch completeness gap**: the `disabled` flag is not
authoritative across all mint paths, contradicting its documented meaning. This is the
spec-conformance half of L-04; it carries no Law-1 asset/value cross-reference.

### Recommendation

Decide and document intent. If `disabled` is meant to be authoritative for **all** mint
paths, add `require(!configs[index].disabled, ...)` to `mintFor` (and consider `burn`),
keeping the deliberate pause-exemption. Otherwise, document that `disabled` blocks only the
paid path and that authorized minters bypass it, so the "new mints are blocked" semantics
are not silently violated.

---

## Summary

- **F-01** — pure spec-conformance (stale, self-contradictory `ratio` invariant). No
  security/value impact. Cross-ref: ledger **L-02 / DD-02**.
- **F-02** — faithful implementation of an under-specified design; the surviving in-scope
  finding is the **missing on-chain `batchDonationSize + ratio <= 100` guardrail (L-05)**.
  Its Law-1 unbacked-phUSD security claim is **suppressed out-of-scope under DEDUP-001** and
  is referenced, not re-litigated, here.
- **F-03** — pure spec-conformance footgun (`mintFor` bypasses `config.disabled`). Low
  operational hazard, no fund movement. Cross-ref: **L-04**.

**Carries a Law-1 security/value cross-reference:** F-02 only (and that dimension is
DEDUP-001, suppressed OOS — L-05 is the in-scope guardrail half). **Pure spec-conformance:**
F-01 and F-03.
