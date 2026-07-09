# QA Report for yield-claim-nft — Run 16

**Scan type:** COLD full scan (`--full`)
**Commit:** `f46a5cb7a90726215d49619ce76cb297f56e290a`
**Report dir:** `reports/yield-claim-nft-16/`
**New findings this run:** **0 High / 0 Medium / 0 Low / 0 QA / 0 Centralization**

This run produced **zero genuinely-new findings**. All 7 deduplication candidates (YCN16-C1..C7)
reconciled to pre-existing ledger entries — no new labels minted, no regressions, no status flips.
This QA bundle is therefore a **re-confirmation snapshot**: every item below is **still-open
carryover** re-observed and re-confirmed at `f46a5cb`, not a fresh discovery. Severities are
preserved exactly as previously triaged; nothing is escalated.

Deterministic SAST (Slither, Aderyn, Semgrep) ran clean this run with no new HM candidates — see
`reports/yield-claim-nft-16/static/`. The automated 4naly3er QA/gas report is attached as
Appendix A (`4naly3er-report.md`).

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (still-open carryover) | 4 |
| QA (still-open carryover) | 1 |
| Centralization (still-open carryover) | 0 new; see note |
| **New this run** | **0** |

Additional non-finding sections (not counted above): QA hardening notes (informational),
one cleared-but-recorded manual-review item (Law-1 visibility), and the 4naly3er appendix.

> Carryover scope note: this bundle re-confirms the specific still-open Low/QA items the run-16
> cold scan re-observed at `f46a5cb`. Other open ledger entries not re-surfaced by this run's
> candidates (e.g. L-04, L-05, L-07, L-10, Q-05, Q-09, Q-10, C-01) remain open in the ledger at
> their prior severities and are unaffected by this snapshot.

---

## Low Risk Findings (still-open carryover)

### [L-02] setRatio accepts ratio == MAX_RATIO, contradicting the documented strict-less-than invariant <!-- id: ycn16l2 -->

**Location:** `src/hooks/BalancerPoolerMintDebtHook.sol#L77-L82`; `src/hooks/UniboostMintDebtHook.sol#L95-L101`
**Status:** open carryover (qa-bundled; fingerprint `5425119c…`; first seen run-08).

**Description:** Both hooks guard `setRatio` with an inclusive `if (newRatio > MAX_RATIO) revert`,
which admits `ratio == MAX_RATIO (50)`, while the NatSpec states the ratio must be **strictly less
than** `MAX_RATIO`. Spec-vs-code boundary nit; no asset impact.

**Run-16 instanceNote (new datum, not a new label — same fingerprint):** `DEFAULT_RATIO` was raised
`30 → 50` (commit `924b188`), so the **deployed default now equals `MAX_RATIO == 50`** and sits
exactly on the inclusive boundary the NatSpec forbids, on **both** hooks. The deduplicator
mis-flagged this as new (F-16-01 / PATTERN-001 / CODE-003); the sanitizer reconciled it under L-02.
No severity change.

**Recommendation:** Either tighten the guard to `>= MAX_RATIO` (enforce the documented strict-`<`
invariant) or correct the NatSpec to state `<=`. Given the deployed default is now exactly 50,
reconcile spec and code before the next hook deployment.

---

### [L-06] Single-sided LP-add relies solely on an off-chain keeper floor with no on-chain price reference (MEV sandwich) <!-- id: ycn16l6 -->

**Location:** `src/dispatchers/BalancerPoolerV2.sol#L269-L275` (and the Uniboost buy-and-pool instance)
**Status:** open carryover (Low; fingerprint `342075df…`; first seen run-10).

**Description:** `pool()`/`unlockCallback` performs a single-sided sUSDS LP-add bounded only by an
off-chain keeper-supplied `minBPT`/min floor, with no on-chain oracle/TWAP reference. A sandwich
attacker can move the pool within the floor tolerance. The path is **keeper-gated** and POL-only
(protocol-owned liquidity), bounding the impact.

**Run-16 note:** The Uniboost buy-and-pool MEV-sandwich instance (YCN16-C4) was re-observed via the
cold scan — same off-chain-floor root-cause class, keeper-gated and bounded by
`minPairOut`/`minTargetOut`/`minLP`. No new exploit path; **stays Low, not re-escalated.**

**Recommendation:** Add an on-chain price/TWAP sanity reference for the LP-add, or keep the keeper
floor tight and the entry point permissioned (as today). No fix required for Low severity.

---

### [L-09] Uniboost has no hookTypeId guard: an unwired/wrong dispatch hook silently accrues zero phUSD debt (M-04 fail-open class reborn) <!-- id: ycn16l9 -->

**Location:** `src/dispatchers/Uniboost.sol` (hook invoked via base `src/dispatchers/ATokenDispatcherV2.sol#L125`)
**Status:** open carryover (Low, non-obvious Law-3 footgun; fingerprint `563df2e6…`; first seen run-13). **Awaiting owner triage — do not auto-suppress.**

**Description:** The base `ATokenDispatcherV2._dispatch` calls `hook.onDispatch` unconditionally with
no `hookTypeId()` marker check (unlike the M-04-fixed NudgeRatchet), and the constructor defaults
`hook = DefaultDispatchHook()` (no-op). If the owner opens dispatches without
`setHook(uniboostMintDebtHook)`, every dispatch forwards prime with **zero phUSD debt** — no revert,
no event. This is the third dispatcher to copy the M-04 fail-open pattern and the one most analogous
to the M-04-fixed NudgeRatchet. Recoverable; no theft → under-accrual / over-backed.

**Run-16 note:** Fail-open still present (YCN16-C2 Uniboost portion) — still **open**, unchanged Low.
Deliberately **NOT** folded into wont-fix Q-08 (BalancerPoolerV2): distinct fingerprint/contract; the
Q-08 owner acceptance covers only the live BalancerPoolerV2, not this newly-in-scope Uniboost.

**Recommendation:** Apply the M-04-fixed NudgeRatchet `hookTypeId()` marker guard to the Uniboost
dispatch path (fail-closed on default/unwired hook). Operationally: always `setHook` before opening
dispatches and verify debt accrual on the first dispatch.

---

### [L-11] MultiPooler.pool same-pool in-batch floor staleness reverts the atomic batch (self-inflicted DoS) or degrades a floor-bounded LP add <!-- id: ycn16l11 -->

**Location:** `src/MultiPooler.sol#L60-L67`
**Status:** open carryover (Low, non-obvious Law-3 footgun; fingerprint `531916f4…`; first seen run-14). **QA-bundle candidate; do not auto-suppress.**

**Description:** `MultiPooler.pool` batches `Uniboost.pool` calls atomically (all-or-nothing;
`onlyPooler` trusted keeper). If two `PoolCall` rows target dispatchers on the **same UniV2 pool**,
an earlier row's swaps move the shared reserves and stale the later row's off-chain-computed min
floors. Primary impact: the whole atomic batch reverts against the staled on-chain floors →
self-inflicted DoS (wasted gas, no loss). Secondary: a floor-bounded degraded LP add. POL-only, no
theft, keeper-avoidable. The default one-pool-per-dispatcher deployment is unaffected.

**Recommendation:** Do not co-batch same-pool dispatchers in a single `MultiPooler.pool` call; if
unavoidable, order the rows and size each floor to tolerate in-batch reserve drift from earlier rows
on the shared pool.

---

## QA Findings (still-open carryover)

### [Q-11] Delay-release variant drops the sibling NudgeRatchet's in-contract require(bal >= amount) backing tripwire from _dispatch <!-- id: ycn16q11 -->

**Location:** `src/dispatchers/NudgeRatchetDelayRelease.sol#L131-L143`
**Status:** open carryover (QA / defensive-assertion gap; fingerprint `205afcf0…`; first seen run-15). **Kept deliberately SEPARATE from suppressed DEDUP-001.**

**Description:** `NudgeRatchetDelayRelease._dispatch` omits the sibling `NudgeRatchet`'s in-contract
`require(bal >= amount)` backing tripwire (defense-in-depth relocated off-contract to NFTMinterV2's
measured-delta discipline). **Not a live bug:** dispatch is `onlyMinter` and NFTMinterV2 dispatches
exactly its measured `actualReceived`, so accrued mint-debt == on-contract USDC by construction and
the dropped assertion is trivially satisfied. Latent **only** under speculative future code — a
non-default `setMinter()` repoint to a caller passing an un-measured amount not backed by an actual
`transferFrom` — which does not exist at `f46a5cb`. C4 discounts speculation on future code without a
demonstrated root cause → QA robustness gap, not Medium.

**Run-16 status re-check (resolves manual-review MR-16-005):** Verified that
`NudgeRatchetDelayRelease._dispatch` **still omits** the `require(bal >= amount)` tripwire. The
sibling's tripwire lives on `NudgeRatchet` (`NudgeRatchet.sol:97`), **not** on this DelayRelease
variant, so Q-11 is **still live — NOT flipped to fixed.** Kept separate from suppressed DEDUP-001
(this is the narrower in-contract on-chain assertion, not the external phUSD backing model).

**Recommendation:** Restore parity with the sibling — read `IERC20(_token).balanceOf(address(this))`
in `_dispatch` and `require(bal >= amount)` (stays view; trivially satisfied in the honest
held-balance path) to keep the backing invariant self-defended in-contract.

---

## Centralization Risks

No **new** centralization findings this run. The prior centralization entry **C-01**
(`replaceDispatcher` re-points token/metadata under existing holders, `src/NFTMinterV2.sol#L227-L247`,
fingerprint `2c8d…`/`070f…`) remains open in the ledger at its prior severity and was not re-surfaced
by this run's candidates. No escalation.

---

## QA Hardening Notes (informational — parked this run, non-exploit)

These were surfaced by SAST this run and **parked visibly** (Law-1 recall) rather than promoted to
security candidates. Owner is trusted (Law 3); none is a demonstrated bug. Included as informational
hardening for owner consideration.

### [Q-HARDEN-1] Single-step Ownable across the suite (STATIC-024 / MR-16-002)

`Ownable.transferOwnership` is single-step across ~7 contracts (dispatchers/hooks/NFTMinterV2); no
two-step accept. **Overlaps existing Q-04** (`setMinter emits no event, and V2 uses single-step
Ownable`). A mistyped owner is a reckless-admin (C4 known-invalid) class, hence not a security
candidate. Hardening: consider `Ownable2Step` for the owner-transfer path.

### [Q-HARDEN-2] Uniboost implements IUniboostPooler but does not inherit it (STATIC-023 / MR-16-003)

`src/dispatchers/Uniboost.sol` matches the `IUniboostPooler` signature but does not `is`-inherit the
interface. Signatures match today (code-scanner cleared it), but `MultiPooler` calls Uniboost via the
interface with **no compile-time sync guarantee** — a future one-sided signature change would break
silently. Given this suite's ABI-drift history, a notable dev footgun. Hardening: declare
`Uniboost is IUniboostPooler`.

### [Q-HARDEN-3] abi.encodeWithSelector instead of abi.encodeCall (STATIC-026 / MR-16-004)

A single site uses `abi.encodeWithSelector` (hand-rolled selector + args, no compile-time arg
type-check) rather than `abi.encodeCall`. No current mismatch demonstrated, but — again given the
suite's selector-drift lineage (M-04) — a future args/selector mismatch would be a plausible footgun.
Hardening: prefer `abi.encodeCall` for compile-time type safety. (4naly3er corroborates as NC-1.)

---

## Cleared-but-Recorded (Law-1 visibility)

Recorded so the clearing decisions stay auditable, per Law 1 (never silently drop a
plausibly-security-relevant item). None is an active finding.

### MR-16-001 — ERC1155 receive-hook reentrancy on the NFTMinterV2 mint path — CLEARED

`src/NFTMinterV2.sol` `_executeMint`/`mintFor` (~L196) mints ERC1155 (inbound `onERC1155Received`
hook) with no `nonReentrant` guard. **Cleared by code-scanner CODE-006 at high confidence:** CEI is
complete — `config.price` is grown and the `dispatch(nonReentrant)` completes **before** `_mint`
fires the receiver hook, so any re-entry is a fresh, fully-paid mint with no broken accounting.
Parked for human confirmation, not promoted.
**Reopen trigger:** if a future change adds a **per-wallet or supply cap checked-before-written** on
the mint path, this reopens (check-then-effect across the receiver-hook boundary).

### BalancerPoolerV2 divide-before-multiply / unchecked-return cluster — INVESTIGATED and CLEARED

The BalancerPoolerV2 divide-before-multiply ordering and unchecked external-call returns were
investigated this run and cleared: the ordering is **by-design PSM (fixed-rate) math** (no AMM price
curve to lose precision against), and the "unchecked returns" are `SafeERC20` calls plus paths that
**re-read balances** rather than trust return values. (Existing QA entry Q-02, unchecked ERC4626
deposit return in `_dispatch`, remains separately ledgered at QA.)

---

## Appendix A — Automated QA/Gas Report (4naly3er)

Full 4naly3er output: **`reports/yield-claim-nft-16/submissions/4naly3er-report.md`** (137 KB;
GAS-1..GAS-N, NC-1..NC-30, and L-* sections over the 26 in-scope `src/**` contracts at `f46a5cb`).

**Tooling-gap update — 4naly3er now RUNS on this project.** Prior runs (11–15) recorded a persistent
4naly3er remappings gap (the project resolves imports via `foundry.toml` remappings —
`@openzeppelin/contracts/` and `pauser/` — while 4naly3er expects a `remappings.txt` in `BASE_PATH`,
so compilation failed with `pauser/interfaces/IPausable.sol import not found`). This run resolved the
gap by staging a `remappings.txt` alongside a symlink to `src/`, with the two remappings rewritten to
**absolute** submodule paths:

```
@openzeppelin/contracts/=<lib>/yield-claim-nft/lib/immutable/openzeppelin-contracts/contracts/
pauser/=<lib>/yield-claim-nft/lib/mutable/pauser/src/
```

4naly3er then compiled and emitted a full report (`Done` / exit 0). The staging was done entirely in
the scratchpad — **`lib/` was not modified** (read-only source repo preserved). Note the automated
report is baseline noise: nothing in it changes the manual triage above (its NC-1 encodeCall and
NC-2 zero-address items merely corroborate Q-HARDEN-3 and the existing Q-09/Q-01-lineage zero-address
notes).
