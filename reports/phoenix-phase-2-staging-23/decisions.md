# Decision Log — phoenix-phase-2-staging run-23

**Date:** 2026-08-03
**Run:** `reports/phoenix-phase-2-staging-23/`
**Command:** `/audit-script` (suite audit)
**Submodule commit:** `c4396b19aea6b7b09573ba90e2e65ca9293d20a1` (`c4396b1`), branch `master`
**Subject:** the story-072 `promotion-ready` script family

This log records decisions taken at forks during run-23, per the decision-log-at-forks
convention. Rationale is recorded verbatim as agreed at the fork.

---

## Decision 1 — Suite scope

The user asked for the story-072 scripts audited collectively. The audited suite is the
5 real keys: `promotion-ready:snapshot`, `promotion-ready:dry`,
`promotion-ready:broadcast`, `promotion-ready:resume`, `promotion-ready:verify`.
`:verify` is story-075's key but is chained into `:broadcast`/`:resume`, so it is inside
the suite's operational closure.

**Supporting evidence (`package.json` @ `c4396b1`):** all five keys exist
(lines 283, 286, 288, 290, 292). `promotion-ready:broadcast` (line 288) and
`promotion-ready:resume` (line 290) both terminate in `&& npm run promotion-ready:verify`,
which is the mechanical basis for pulling `:verify` into the closure. Line 284 carries the
project's own human-readable order-of-execution note
(`promotion-ready:snapshot` then `promotion-ready:dry` then `promotion-ready:broadcast`),
consistent with treating the family as one operational unit rather than five independent
entry points.

---

## Decision 2 — Fingerprint namespacing

`entryPoint` follows where the ROOT CAUSE lives, not which npm key is typed. Root cause in
`DeployMainnetPromotionReady.s.sol` / `package.json` / the JS chain →
`entryPoint = "promotion-ready:broadcast"` (matches run-22's ledger entryPoint so its 12
open findings reconcile rather than minting fresh fingerprints). Root cause SOLELY in the
new `script/VerifyPromotionReady.s.sol` → `entryPoint = "promotion-ready:verify"`.
Rationale: run-22 filed 12 findings under `promotion-ready:broadcast`; re-namespacing them
would silently orphan an open Medium and 8 Lows (Law 1 recall failure).

**Operational consequence.** Two `script-audits/` output directories exist for this run,
one per `entryPoint` namespace:

- `script-audits/promotion-ready:broadcast/` — the 4 keys whose root-cause surface is the
  deploy script, `package.json`, or the JS chain (`:snapshot`, `:dry`, `:broadcast`,
  `:resume`).
- `script-audits/promotion-ready:verify/` — findings whose root cause is solely inside
  `script/VerifyPromotionReady.s.sol`.

A finding that touches both surfaces is namespaced to `promotion-ready:broadcast` (the
pre-existing namespace), never split, so reconciliation against run-22 stays exact.

> **Superseded in part by Decision 3 (2026-08-03):** the two directories above are named
> in the hyphen form on disk (`promotion-ready-broadcast/`, `promotion-ready-verify/`).
> The `entryPoint` values quoted in this section are unchanged.

---

## Decision 3 — Directory naming vs. `entryPoint` value (2026-08-03)

The on-disk `script-audits/` directories use the **hyphen form**:

- `script-audits/promotion-ready-broadcast/`
- `script-audits/promotion-ready-verify/`

Two reasons: consistency with run-22's on-disk convention, and avoiding `:` in path names,
where it collides with forge's `path:Contract` separator syntax.

The ledger/finding **`entryPoint` field is unchanged** and remains the colon form —
`promotion-ready:broadcast` and `promotion-ready:verify`. That string is what fingerprint
reconciliation keys on (`sha256(contract:function:rootCauseClass[:entryPoint])`), so it
must continue to match run-22's ledger entries exactly; renaming it would mint fresh
fingerprints and orphan run-22's open findings (the Law-1 recall failure Decision 2 exists
to prevent).

**The directory name and the `entryPoint` value are deliberately NOT the same string.**
Do not "fix" either one to match the other: the directory is a display/storage path, the
`entryPoint` is a fingerprint input.

---

## Note — known-issues data is stale (suppression caveat)

The project's known-issues data was extracted **2026-01-09**, is **V1-era**, and holds
**11 entries**. It therefore predates the entire `promotion-ready` family and most of the
current contract surface. KI-based suppression in this run is **low-confidence and must
not be used to drop a security-relevant finding** (Law 1: recall beats report tidiness).

If a candidate finding appears to match a known issue, it is routed to the visible
manual-review / spec-conformance channel with the KI reference and the staleness caveat
attached — never silently suppressed.

---

## Environment / reproducibility

- **Fork mode:** available (`forkAvailable = true`).
- **Fork block (liveness probe at run start):** `25670926`.
- **RPC provider:** Alchemy (`eth-mainnet.g.alchemy.com`); key path segment masked.
- **`ETHERSCAN_API_KEY`:** present.
- **Execution root:** `workspace/phoenix-phase-2-staging/` @ `c4396b1`.
  `lib/` is read-only for the duration of this run. Nothing is broadcast.

---

## Decision 4 — Severity walk-back: run-23's only Medium is refuted (2026-08-03)

**Outcome: run-23 has ZERO Highs and ZERO Mediums.** Final tally **0 High / 0 Medium / 5 Low / 1 QA**.

### What was refuted

Run-23 filed **`M-01`** (`f59e177a97c88429…`, entryPoint `promotion-ready:broadcast`) as a
**Medium** on one premise and one premise only: that a mis-resolved snapshot address produces a
**partially-applied, irreversible mainnet cutover**, because the guards sit inside Phase 6 after
Phases 1-5 have already dispatched. Its own `justification` said so explicitly — *"converting an
atomic pre-broadcast abort into a mid-sequence revert IS the impact"*.

**That premise is false.** An adversarial PoC validation established empirically, via an
independent probe (`forge script` run without `--broadcast`), that:

- forge executes `run()` as **one local EVM frame first**, and only dispatches if that frame
  returns successfully. A later revert **unwinds the entire frame** — both broadcast-recorded
  actions were rolled back, forge exited `1`, and **nothing dispatched**.
- `--skip-simulation` skips the **per-transaction pre-send check**, **not** the local pass.
- The guard's inputs (`users.length` from `vm.readFile`, `preTotal` from local forked state) are
  **fully deterministic** in the local pass, so the `:1550` guard **always fires pre-broadcast**.

The real outcome is an **atomic pre-broadcast abort**: zero transactions signed, zero mined, and
forge's non-zero exit halts the `&&` chain (`package.json:288`) so the patch and verify legs never
run. Corroboration: the project's **own `package.json:287`** states this mechanism verbatim.

### Two further validator findings, recorded because they weaken the finding

1. **Causal inertness.** `_loadSnapshotUsers` (`:1599-1601`) reads only `.users` and never
   `.address`. A probe that corrupted `.address` while leaving `users` intact **reverted nothing**.
   The address mismatch is therefore **causally inert on its own**; only an empty user list fires
   `:1550`, and the PoC set that **by fixture construction**. The causal step *"mis-resolved address
   ⇒ empty/wrong user list"* was **asserted, never demonstrated**.
2. **Factual correction.** The finding described the three stakers as covering *"2 / 156 / 13
   users"*. Those are **stake units** from the migrate log. The **actual snapshot user counts are
   1 / 2 / 3** (EYE / SCX / FLX), verified from `scripts/snapshots/depletion-stakers-latest.json`.

### Actions taken

- **Downgraded to Low and relabelled `M-01` → `L-05`** (`findings/medium/M-01.json` →
  `findings/low/L-05.json`). **Fingerprint `f59e177a97c88429…` is UNCHANGED** — severity is not a
  fingerprint input, and the ledger entry must stay joinable.
- Impact and attack path **rewritten honestly**: the failure **is** atomic pre-broadcast; every
  claim of a partially-applied cutover is removed. The surviving defect is precondition hygiene —
  Phase 6 never asserts the snapshot targeted the same staker addresses (no `.address`/`.chainId`
  provenance check, and `resolveAddress()` accepts `0x0`), so a mis-resolved snapshot is caught
  **late and only incidentally**, by the empty-user-list guard, rather than by an explicit Phase 0
  precondition.
- The old `justification` is **retained verbatim** as `justificationRetracted` — the walk-back is
  recorded, not quietly edited.
- **PoC re-scoped, not deleted.** `workspace/phoenix-phase-2-staging/test/SnapshotAddressMismatchOrdering.t.sol`
  is marked `supportsWeakerClaim: true`. It supports only: (a) the `:1550` guard exists, is
  fail-closed, and emits exactly `"snapshot user list is empty but V1 still holds stake"`; (b)
  `_loadSnapshotUsers` never reads `.address`; (c) Phase 1-5 state survives **only** under a
  *counterfactual* model where Phases 1-5 and Phase 6 are separate top-level transactions — a split
  with **no counterpart in the real invocation**. It is **audit-authored and untracked**; it must
  never be presented as an upstream project test.
- **Relationship to run-22 `L-07`** (`b28492ce9719af2d…`): the dedup discriminator that kept them
  separate — *"L-07 is atomic pre-broadcast, F-06 is mid-sequence"* — is **FALSE; both are atomic
  pre-broadcast**. They are **still not collapsed**, on a corrected basis: **different root causes,
  different fixes**. L-07 is *file absence / staleness with no Phase 0 probe*; `L-05` is *content
  provenance* — the file may exist and be perfectly fresh yet describe the wrong addresses, fixed by
  asserting `.stakers.<key>.address == V1_STAKER_<X>` and `.chainId == 1` and rejecting `0x0` in
  `resolveAddress()`. **SN-23-01's stated rationale is superseded** by this corrected one on both
  ledger entries, which now cross-reference each other. The false discriminator is left standing
  nowhere.
- **Off-chain observation, recorded as evidence not as a finding.** `vm.writeFile` is a filesystem
  cheatcode and is **not** subject to EVM rollback, so a failed local pass still leaves
  `server/deployments/progress.promotion-ready.1.json` claiming steps that were never broadcast.
  Genuine but **off-chain only**, and already covered by ledger entries L-02 / L-03 / L-07 and the
  `:resume` doc key. Filed as an **evidence note on L-03** (`ea648ec5eab0c926…`), flagged
  **unverified**. **No new finding was minted.**
- **Ledger:** entry count unchanged at **111**; `lastAuditedCommit` (`0e190e8`), `branchBaselines`
  and every human-set status untouched; the `fixed` proposals on `2c53e944…` and `4fd16423…` were
  **not** applied and remain `open` with proposal-only fields.

### Standing lesson for this project

**`ForgeLocalPassPrecedesBroadcast` is a recurring trap on `phoenix-phase-2-staging`** — the family
was already on this ledger from run-22, and this run's finding **inverted the family's own
semantics**. Before grading ANY script finding on **mid-sequence-failure** grounds, an auditor must
first establish that a mid-sequence state can exist at all: on a `forge script` entry point whose
`run()` is a single frame, **it cannot**. A revert anywhere in `run()` is an atomic pre-broadcast
abort, and the severity must be graded on the *diagnostic* cost of a late abort, never on an
imagined partially-applied deployment.
