# Sanitization + Ledger Reconciliation — reflax-yield-vault run-17 @ `cdd0743`

- **Project**: reflax-yield-vault · **Branch**: `master` (`currentBranch == defaultBranch`) · **Commit**: `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9` `[story-050] previewExitFor on IYieldStrategy`
- **Input**: `reports/reflax-yield-vault/17/dedup.md` — 16 findings `DEDUP-17-01..16`, plus 4 folds, 15 removals, 8 parked (`manual-review.json`)
- **Ledger**: `reports/reflax-yield-vault/ledger.json` — 49 entries; `branchBaselines.master.lastAuditedCommit = 0110ce44e1b9da0944595765eb0ae12affc50d7e`, `lastRun: reflax-yield-vault-16`
- **Date**: 2026-08-31 · **Agent**: sanitizer · **Ledger NOT modified** (finding-manager's lane)

## Result

| | count |
|---|---|
| Input findings | 16 |
| **Suppressed** | **0** |
| **Passed through** | **16** |
| Flagged for human review | 3 (`DEDUP-17-13`, `DEDUP-17-14`, `DEDUP-17-16`) |
| Ledger relation: NEW | 16 |
| Ledger relation: still-open match | 0 |
| Ledger relation: REGRESSION | 0 |
| Still-open carryover owed to finding-manager | **38** |
| Proposed `fixed` flips | **0** |

---

## 0. Integrity checks (run first, reported explicitly)

1. **Ledger snapshot matches.** `sha256(reports/reflax-yield-vault/ledger.json)` =
   `cb213b50d1076db17d4351aea94583be50e7a0564ca01f0a1d9d1fb1f7d5fed1`, byte-identical to the pre-audit
   snapshot at `/tmp/.../scratchpad/ledger-snapshot-preaudit.json`. **The live ledger has not drifted; no
   delegated write has touched it this run.**
2. **Known-issues suppression is UNAVAILABLE — reported as a gap, not exercised.**
   `registered-projects.json` for this project records `knownIssuesCount: 0`, `knownIssues: []`,
   `knownIssuesSource: null`, `knownIssuesExtractedAt: 2026-01-23T12:00:00Z` — **seven months stale
   against `cdd0743`**, with a null source pointer even though the declared sources
   (`lib/reflax-yield-vault/CLAUDE.md`, `docs/`) do exist. An empty cache is **not** evidence that no
   known issues exist; it is evidence that none were extracted.
   **Consequence: this pass has ZERO known-issues suppression authority, and exercised none.** No finding
   below is removed on known-issues grounds. Per **Error Handling → Missing Known Issues**: warn and
   proceed without filtering. **Owed to project-manager: a re-extraction against HEAD before the next run**
   (same defect class as `phstaging-known-issues-cache-unfalsifiable` and
   `phlimbo-ea-known-issues-unfalsifiable`).
3. **In-source NatSpec carries no suppression authority.** `previewExitFor`'s NatSpec — which mandates in
   capitals that consumers MUST measure the balance delta, and uses the word "guarantees" — is the
   *subject* of `DEDUP-17-01/-02/-05/-15`, not a disposal of them. Per the standing precedent
   (`in-source-natspec-carries-no-suppression-authority`), a falsely-exhaustive doc comment **raises**
   severity. Applied as written: it suppressed nothing and is cited as aggravating in four findings.
4. **Non-canonical statuses left untouched.** `merged` ×1 (`M-03` / `3c8331040bba6a7b`) and
   `downgraded-to-centralization` ×2 (`H-01` / `f4eb23ce86d3e24d`, `H-03` / `2a3d559aeea8fba6`) are
   **human-set**. Not normalized, not overwritten, not reinterpreted. `M-03`'s own merge note explicitly
   retains its fingerprint "so a future standalone recurrence can still be matched" — honoured in
   `DEDUP-17-03` as a disclosure, not a re-open.
5. **Status census of the 49 entries**: 38 `open`, 6 `false-positive`, 2 `downgraded-to-centralization`,
   1 `fixed`, 1 `wont-fix`, 1 `merged`. **No `fix-pending` entries exist in this ledger**, so no
   `FIX-PENDING` / `⚠ FIX-PENDING STILL LIVE` heading applies this run.
6. **Regression surface is small and clear.** Exactly one entry is `fixed`: `M-01` / `9addc259f322848c`
   (`_skimSurplus` over-skim via duplicate `clients[]`). No run-17 finding touches that root cause class,
   so **no REGRESSION is raised**.
7. **Diff is additive.** `git diff --stat 0110ce44..cdd0743` over `src/` touches 4 files, +171 lines, with
   `IYieldStrategy.sol` and the two preview implementations accounting for all of it. Nothing in the delta
   removes or rewrites the code any open entry sits on.

---

## 1. C4 known-invalid list — applied finding by finding

Applied per the genuine list; **not** applied as a proxy for the missing known-issues cache.

| Invalid category | Result this run |
|---|---|
| Non-standard/weird ERC-20 (except USDT) | **Not applied** to `DEDUP-17-16` — see §2.16; the carve-out *is* the finding. |
| Fee-on-transfer tokens | Not raised by any finding. `DEDUP-17-02` is an **ERC4626 vault exit fee**, a first-class ERC4626 feature the strategy's own quote is blind to — not a fee-on-transfer token. Category does not reach it. |
| Approve race / `safeApprove` front-running | **Not applied** to `DEDUP-17-16` — see §2.16. |
| User input mistakes / phishing | Not applicable. |
| Unused view functions | **Not applied** to `DEDUP-17-11`. The finding is not "a view is unused"; it is that the override is **sealed** (`override` without `virtual`) against a repo with a demonstrated forked-variant habit. |
| Reckless admin mistakes (Law 3) | **Not applied** to `DEDUP-17-07` — see §2.7. Applied *upstream by dedup* to the `setRoute` validation gaps (obvious failure mode), which is correct and not revisited. **No "malicious owner" vector appears anywhere in the 16.** |
| Speculation on future code without demonstrated root cause | **Partially applicable, already honoured** in `DEDUP-17-13`: the root cause (`_routeExit`'s `received == needed` by construction ⇒ the mandated revert is unreachable) is **demonstrated in code today**; only the *escalation* is future-conditioned, and it is capped at Low behind a dated three-part trigger. Kept. |
| Automated-tool findings without a demonstrated H/M exploit path | Dedup already removed 11 SAST duplicates and 3 noise items. The 3 SAST survivors (`-14`, `-15`, `-16`) each carry a mechanism argument beyond the detector hit; all three are filed at **Low/QA**, not H/M. Correct. |
| Issues in parent/forked contracts with OOS root cause | Not applicable — every finding is on first-party `src/`. `SA-021` (`src/mocks/`) was already removed OOS by dedup against the project's `outOfScope` denylist, which is the right basis. |

---

## 2. Per-finding disposition

Every finding: **KEEP**. Ledger relation is **NEW** for all 16 — `previewExitFor` did not exist at
`0110ce44`, so no run-17 shape can match an existing fingerprint, and the three findings on pre-existing
surfaces (`-14`, `-15`, `-16`) each carry a `rootCauseClass` distinct from the entry nearest them.
`entryPoint` is absent for all 16 (contract scan, not `/audit-script`), so fingerprints reproduce the
legacy `sha256(contract:function:rootCauseClass)` form.

### DEDUP-17-01 — base `netGuaranteed` is a ceiling not a floor when the share cap binds
- **KEEP.** No suppression basis. **NEW** — `AYieldStrategy.sol:571-583 previewExitFor` did not exist at baseline.
- Carried constraint: cite the symbolic basis as *696 M-state exhaustive integer search / 150 k fuzz / 105-case grid*, **never** "symbolically verified" (0 `[PASS]`, 7 `[TIMEOUT]`).
- **NON-COLLAPSE honoured**: must not absorb `DEDUP-17-03`; a fix that copies `_exitFloor` into the base closes this and **spreads** `-03` to the direct strategy.

### DEDUP-17-02 — both previews built on fee-free `convertToAssets`; the published guarantee is breached on every fee-charging exit
- **KEEP.** **NEW.** Explicitly **not** suppressed under any known-issue or NatSpec basis.
- **RE-FILE DISCLOSURE (carried verbatim) — `ECON-A` / `c50c08f9ee587c02e38e089dd7aa2ee3ae64a9623bb1e6f1d138154b21fc7887` (Low, `open`) and `F-16-003` / `c705bd94ec78fd233ec72a1599f746cfe051b4357aaf5851fb041abd41d55d98` (faithfulness, `open`).**
  `ECON-A` title: *"ERC4626YieldStrategy credits principal via fee-blind convertToAssets, persistently over-stating redeemable NAV."* Its `severityScaling`, verbatim:
  > "Magnitude-bound to the EXTERNAL vault fee/curve config, NOT this contract. Over-credit scales LINEARLY with vault exit fee (PoC: 1% fee -> 10e18 over-credit on 1000e18). A future strategy wired to a non-trivial-exit-fee vault makes this SAME code path a MEDIUM. Retain the F-03 StableStaker:786 integration gate with 'magnitude = external vault fee config' annotation (severity-auditor carry-forward)."

  `F-16-003`'s live gate, verbatim from `reports/reflax-yield-vault/16/submissions/spec-conformance.md:65`:
  > "the gate must re-weigh severity against the *actual* vault wired at the integration point, not inherit ECON-A's stale Low."

  **Re-file basis:** same primitive (fee-blind `convertToAssets`), different function, different claim, different consequence — `ECON-A` is deposit-side crediting on `_acquireShares`; this is an exit-side **published delivery guarantee** on a function that did not exist at `ECON-A`'s commit. **Run-17 TRIPS `F-16-003`'s gate** (deployed wiring is Tokemak `autoDOLA`/`autoUSD`). **File as a new entry cross-linked to `ECON-A` and `F-16-003`; do NOT merge into `ECON-A` (fingerprint is `_acquireShares`); do NOT inherit `ECON-A`'s stale Low without the gate's re-weigh.** Adjacent open: `L-11` / `abd28a2f46c12893`, `L-09` / `c6ec246f7e58dd29`.
- Sanitizer note: `ECON-A` and `F-16-003` are `open`, not `acknowledged` — they carry **no** suppression authority in any case.

### DEDUP-17-03 — per-account `netGuaranteed` floored against the GLOBAL share balance; N clients quoted a floor only one can be paid
- **KEEP.** **NEW.**
- **Scope of the standalone-value-transfer suppression is accepted as dedup framed it, and not widened.** Suppressed leg: *client-vs-client value transfer* (minter-cushion memo — `PhusdStableMinter` has no strategy-withdraw path, cannot race; no per-client cap recommended). **What is filed is the over-issued guarantee**, a view that legitimises an FCFS drain. **Reopen trigger `WATCH-17-E2` (parked `MR-17-06`): any future story giving `PhusdStableMinter` a strategy-exit path kills the premise and makes this a live Medium immediately.**
- **RE-FILE DISCLOSURE (carried verbatim) — `M-03` / `3c8331040bba6a7b62e136e08e6bb36f4c992ca6186b5dd21913e7e981b96434` (Medium, `merged` into `M-02`).** Title: *"Requested-not-received decrement socialises slippage, causing last-withdrawer shortfall."* Merge note, verbatim:
  > "No standalone loss primitive; amplifies M-02's slippage leak by concentrating the share-backing deficit onto the last withdrawer via the requested-not-received decrement. Confirmed by poc-validation.md counterfactual (fair deposits + adverse withdrawals only -> no concentrated shortfall). **Fingerprint retained so a future standalone recurrence can still be matched.**"

  **Re-file basis:** same shape, different primitive — `M-03` is `ERC4626MarketYieldStrategy._withdrawInternal` with an AMM-slippage deficit bounded by `slippageToleranceBps × tradeSize` and a `minOut` revert; the direct leg here is `ERC4626YieldStrategy`, the deficit is an **unbounded vault drawdown**, and `vault.redeem` carries **no `minOut` at all**. **`M-03` stays `merged`** — human-set, not touched.
- `M-01-run12` / `fdda8f53151ab76e` (`false-positive`, realizable-solvency collapse) is **NOT** re-escalated and is **not** cited as support (hard-guard memory honoured).

### DEDUP-17-04 — `netGuaranteed > 0` is a false green: three independent reasons `withdraw` is not executable
- **KEEP.** **NEW.** Instances (a) AMM price blindness, (b) vault redemption throttle, (c) finite AMM depth are carried **enumerated**, each with its own sub-remedy, so a partial fix reads as partial.
- **CRITICAL DE-CONFLICTION (carried verbatim) — `M-02` / `d7f6c2dfd580776dd3193942b89806b893ac95ff56a752a5e5bd7c501cb41416` (Medium, `false-positive`) must NOT be inherited.** `triageNote` closes, verbatim:
  > "2026-06-09: Rejected as false-positive. The use of convertToShares/convertToAssets is intentional — the design allows in-block swaps without MEV fear precisely because the AMM pool is concentrated liquidity. A small slippage tolerance covers 99% of deposit/withdrawal scenarios. The NAV reference is not exploitably skewed in this pool topology. **No valid attack path.**"

  Same code, **different claim**: `M-02` is *value extraction by a sandwicher* (refuted on pool topology); this is *the new preview reporting green while `withdraw` is guaranteed to revert* — **liveness**, on a surface that did not exist at `M-02`'s commit. The refutation is about profitability, not about the quote's blindness. **A triage pass that pattern-matches this onto `M-02` and inherits `false-positive` would suppress a live finding.** This sanitizer pass explicitly declines that inheritance. `L-12` / `6e771a84e82df3c1` (open) is adjacent context, not a duplicate.
- **RE-FILE DISCLOSURE (carried verbatim) — stable-staker `M-07` (`ss9m7`) / `969722dc9eedb9615…` (Medium, `acknowledged`).** Title: *"setYieldStrategy underwater guard is rate-based, bypassed by AMM execution slippage (incomplete fix of M-06)."* `triageNote`, verbatim:
  > "Owner-acknowledged 2026-06-09: real Medium footgun confirmed, won't-fix in code. Disposition: in-place setYieldStrategy on an AMM/execution-priced market yield strategy with staked users is prohibited operationally — a full terminal migration … must be used instead… Handled by operator caution / phStaging script discipline, not a code change."

  **Re-file basis:** different repo, different function, and its disposition is an **operational prohibition on an owner action**. This finding is the same blindness on a **permissionless, integrator-facing view that now publishes the blind number under the word "guarantees"** — a larger blast radius no operator discipline reaches, because the consumer is not the operator. **`acknowledged` on `969722dc…` carries no suppression authority here, and none was applied.** (It is also a *foreign-ledger* status; this project's ledger is the only suppression authority for this project.)

### DEDUP-17-05 — the quoted floor is not honoured across a real quote→execute gap
- **KEEP.** **NEW.** Distinctness from `-03`/`-04` accepted as argued (different harm — silent 99% under-delivery vs. revert; different root cause — the quote is not a snapshot; **different mitigation** — the floor must become enforceable as a caller-supplied `minOut`, which `-04`'s AMM-quote fix does not deliver).
- **DISCLOSURE (carried verbatim) — stable-staker `M-01` / `2b9a89d29c34df41aee609d0b5f2c6ae82c1e509877261424c2c20f317fbb0c3` (Medium, `wont-fix`).** `triageReason`, verbatim:
  > "OWNER DECISION 2026-08-29, recorded in the owner's own terms. The finding is VALID — this is explicitly NOT a rejection on the merits and NOT a severity downgrade. It is closed wont-fix because the mitigation is OPERATIONAL rather than a code change, and is OUT OF SCOPE FOR THIS REPO: the pause() -> initiateMigration() -> unpause() sequence belongs in the deployment script that performs the migration, which lives in phoenix-phase-2-staging. Nothing in stable-staker can fix it."

  **ADJACENT, NOT A DUPLICATE.** `2b9a89d2…` is a stable-staker buffer-ordering value transfer between stakers; this is a reflax quote→execute gap where the strategy's own floor is silently re-derived. Its `wont-fix` reasoning ("nothing in stable-staker can fix it") carries **no authority over reflax code**, where the fix *is* a code change. **Not suppressed.**
  Fingerprint correction carried forward: `2b9a89d29c34df41…` is the par-exit front-run entry; `69c7666eee33698e…` is the older, different FCFS-at-par entry. Memory `stable-staker-run15-notes` cites the wrong one — repair owed, outside this lane.

### DEDUP-17-06 — one-directional protocol-favouring write-down; the market strategy pays out over-delivery from the commingled position
- **KEEP.** **NEW.** **Minter-cushion suppression correctly NOT applied**: the memo declares the commingled share cap by design in the **deficit** direction (minters cannot redeem ⇒ cushion, not counterparty). This is the **surplus** direction — an exiter extracting more than it was debited out of backing the cushion supplies. The memo's premise does not reach it. Routed to severity-classifier / severity-auditor for adjudication rather than suppressed (**Law 1: recall beats tidiness**).
- Adjacent open: `QA-09` / `86409a56b6fc3c8b` (orphaned vault value) — same commingled-residual accounting, opposite direction. **Disclose, do not collapse.**

### DEDUP-17-07 — `previewExitFor` returns `(0,0)` for five operationally unrelated states
- **KEEP — and the reckless-admin invalid category is explicitly NOT applied.**
  Suppression basis considered and **rejected**: *"Reckless admin mistakes — owner acting maliciously, or a misconfig whose harm is obvious (Law 3)."* Neither limb is met. There is **no malicious-owner vector** in this finding at all, and the harm is the opposite of obvious: state (d) — `slippageToleranceBps == MAX_BPS` on an account with a **live `990e18` principal** (`assertGt(principalOf(...), 0)` passes) — signals **bit-identically to an account that never existed**. That is precisely the Law-3 exception: *a non-obvious owner footgun that unknowingly enables an exploit or breaks a story is NOT OOS — keep it as an operational hazard with safe-config guidance.* **Test applied: would a competent, non-malicious owner be surprised that raising slippage tolerance makes a funded client indistinguishable from an unknown one to every integrator? Yes ⇒ footgun ⇒ report.**
- **NEW** — the `(0,0)`-overloading API-contract defect has no existing owner. **`L-01` / `6460e35331dff5c2` does NOT cover it** — `L-01` owns both *boundaries* of the setter and the deposit-side blast radius (per its own title and `run08Note`), but not the **alarm ambiguity**. The split at §2.1 of dedup is along ownership, not along the boundary, and is **confirmed correct**.
- Fifth state carried: post-`emergencyWithdraw`, `shares == 0` with principal booked ⇒ positive gross (sentinel does **not** fire), `netGuaranteed 0`, then a zero-size swap → `DEDUP-17-08`.
- Safe-config guidance to carry into the QA bundle under `L-01`: `require(_bps <= 1000)` in the setter; never deploy at the zero default; pause deposits before temporarily raising tolerance; `require(creditedPrincipal > 0)` in `_depositInternal`; monitor `previewExitFor(token, <known-funded client>, 1)` as a `MAX_BPS` canary.

### DEDUP-17-08 — test AMM adapter more permissive than production; `_disposeShares` bricks on a zero-size swap
- **KEEP.** **NEW.** Remedy enumeration was **run, not asserted** (`relinquishPrincipal` `:682` client-callable and `relinquishPrincipalAsOwner` `:687` both succeed with no external call) — no "no remedy exists" claim, per the `absence-of-remedy-claims-need-enumeration` precedent. Bricked normal path with two working escape hatches, not a permanent freeze.
- **DISCLOSURE (carried verbatim) — `L-13` / `1456259d8ac60c118795b770323769ed2bf565c67dee884a6d814daded7bbc4e` (Low, `open`).** Title: *"`_totalWithdraw` state-inconsistency: migration recorded as executed even when `sharesToSell` floors to 0 for a tiny-balance client (principal left on books, nothing moved)."* **Disclose, do NOT collapse** — identical share-flooring root cause, different function and different fix (`L-13` wants revert-or-skip in `_totalWithdraw`; this wants `if (sharesToSell == 0) return 0;` in `_disposeShares` **plus** the `amountIn > 0` guard added to `MockAMMAdapter`). Fixing one leaves the other live.

### DEDUP-17-09 — `netWanted * MAX_BPS` panics on `type(uint256).max` in the market override while the base answers it
- **KEEP.** **NEW.** Not filtered as an absurd input: the two implementations of **one interface member diverge on the standard "give me everything" sentinel**, and story-050 criterion 9 demanded a neighbouring division edge be distinguishable from a bare `Panic(0x12)` — this ships a bare `Panic(0x11)` on a more plausible input. One-line fix.

### DEDUP-17-10 — `ceilDiv` gross-up compensates the bps leg but not the share round-trip
- **KEEP** at QA/informational. Not suppressed; the `ROUNDING-DIRECTION` **known-benign** classification is what sets the severity, not a suppression (no user-favouring leg, no repeatable round-trip profit; bound `≤ ⌈A/S⌉ + 2` raw base units, 256-run fuzz, no counterexample). **NEW.**
- **DISCLOSURE (carried verbatim) — `F-01` / `ec9191e420d544443d4625c9b2150cf725b06328b41eb4c58e0ff2572bb5ee04` (faithfulness, `open`).** Title: *"story-043 'provable solvency invariant' overstated: ERC4626 double round-down means `convertToAssets(convertToShares(creditedPrincipal))` can be a few wei below `creditedPrincipal`."* **Disclose, do NOT collapse** — same arithmetic, same overstated-story shape, but `F-01` is the **deposit** side (`_depositInternal`/`_creditedPrincipal`) and this is the **exit** side, on a function that did not exist at `F-01`'s commit. **Process signal for the report writer: two consecutive stories (043, 050) have each claimed a provable property the ERC4626 double round-down does not deliver.**

### DEDUP-17-11 — market `previewExitFor` override sealed against subclassing
- **KEEP** at QA. **"Unused view functions"** invalid category **not applied** — see §1. **NEW.**

### DEDUP-17-12 — adding `previewExitFor` to `IYieldStrategy` breaks four non-`AYieldStrategy` implementers at the next bump
- **KEEP** at Informational. **NEW.** Enumeration was run untruncated over registered submodules at their own HEADs, excluding nested `lib/**` (per `grep-head-truncation-false-coverage-gap` and `nested-submodule-pin-stale-trap`). Build break in **test** suites, not runtime. The two unverifiable claims are **not asserted** and are parked as `MR-17-04`.
- **Zero consumers, verified twice independently, is the load-bearing fact keeping `-01`..`-05` at Low.** `WATCH-17-03` (the `stable-staker` submodule bump) escalates five findings at once and coincides with `F-03`'s and `F-16-003`'s existing Medium re-evaluation gates — **handle in one pass.**

### DEDUP-17-13 — story-025's "measure the delta and revert" safeguard cannot fire on a below-par strategy
- **KEEP — FLAGGED for human review** (partial-match to the "speculation on future code" invalid category).
  Basis for keeping: the invalid category is *"speculation on future code **without demonstrated root cause**"*. The root cause **is** demonstrated in code today — `_routeExit`'s `guardUnderwater` branch returns the full requested `amount` from idle and calls `relinquishPrincipal` (a pure write-down), so `received == needed` **by construction** and the mandated `StableStaker:` revert is **unreachable**; story-025's acceptance test is unsatisfiable against a real below-par strategy. Only the *escalation* is future-conditioned, and it is already capped at **Low behind a dated three-part trigger**, with the naive "consumer trusts `netGuaranteed`" finding deliberately **not** filed. Dedup's own C4 check reached the same conclusion. Flagged so a human can confirm the Low cap is the right resting place rather than a park.
  Harm is **availability, not value leak** — buffer depletion is **opportunity cost** under the externally-derived-yield rule and is explicitly not filed as a leak.
- **NEW.** Rides the existing `F-03` / `52f9b84a54ec9a65` (open) gate and feeds `QA-09` / `86409a56b6fc3c8b` (open). **Not a duplicate of either** — `F-03` is double-counting across the call; this is the consumer's own safeguard being inert. **Channel: `spec-conformance.md`, not the QA bundle.**

### DEDUP-17-14 — `_totalWithdraw` silently early-returns on `totalShares == 0 || totalDeposited == 0`
- **KEEP — FLAGGED for finding-manager.** Not tool noise: the consequence is traced (the two-phase `totalWithdrawal` window is **consumed** by the silent no-op while principal stays booked), which is what lifts it above a bare `incorrect-equality` detector hit.
- **NEW**, with a caveat to resolve at upsert: `L-13` / `1456259d8ac60c118795b770323769ed2bf565c67dee884a6d814daded7bbc4e` (Low, `open`) is the *market* `_totalWithdraw` **share-flooring** instance. This is the **zero-shares / zero-deposits guard** at the top of the same function, on **both** contracts — different condition, different fix, so a different `rootCauseClass` and a different fingerprint. **Finding-manager must confirm the `L-13` fingerprint does not already cover the market site before minting a second entry there; the direct-strategy site is unambiguously new either way.**

### DEDUP-17-15 — direct strategy discards `vault.redeem`'s return
- **KEEP.** **NEW.** Survives as a finding rather than SAST noise because it is the **mechanical enabler** of `-01` and `-02`: `previewExitFor`'s NatSpec mandates in capitals that consumers measure the balance delta, the strategy's own exit does not, and `vault.redeem` carries no `minOut` — which is exactly why the direct failures are **silent** rather than reverting. Capturing the return and comparing it to the quoted floor converts `-01`/`-02` from silent to loud in one line. Distinct from `QA-06` / `8019f1c9c6de5e43` and `L-06` / `0f534a726502d274` (different call sites).

### DEDUP-17-16 — raw `approve` with unchecked boolean return in the `ERC4626YieldStrategy` constructor
- **KEEP — FLAGGED for human review** (two invalid categories were tested against it; **neither applies**).
  1. **"Approve race condition / `safeApprove` front-running" — DOES NOT APPLY.** That invalid pattern is the ERC20 allowance double-spend: a spender front-runs a `approve(x) → approve(y)` transition to spend `x + y`. This finding is **not** that. It is an **unchecked `bool` return on a single one-shot `approve` in a constructor**, where the failure mode is a **decode revert at deployment**, and the spender is the strategy's own configured vault. No race, no front-run, no allowance transition. Dropping it under this heading would be a category error.
  2. **"Non-standard/weird ERC-20 (except USDT)" — DOES NOT APPLY**, because **USDT is the explicit carve-out and USDT is the token that trips this**: USDT's `approve` returns no data, so a `bool`-decoding call reverts. The carve-out *is* the finding's basis, not a suppression of it.
  **Law-3 note:** correctly **not** filed as a footgun — the failure is deploy-time and loud (nothing deploys), so it fails the surprise test. **QA is the right severity**, kept for the one-line `SafeERC20.forceApprove` fix on the only unguarded ERC20 call in `src/`, with `CFG-01` / `0c12a2cfaf4b026a` (open) as evidence the wired-vault configuration has already been wrong once.
- **NEW.**

---

## 3. Ledger reconciliation — carryover and proposals

### 3.1 Still-open carryover — 38 entries owed to finding-manager

**None of the 16 run-17 findings matches an existing fingerprint, so no entry is marked `still-open` by
re-observation this run.** The 38 `open` entries were **not re-scanned** (the regression diff is confined
to the 4 additive `src/` files) and therefore must be **carried forward in full** per CARRYOVER: the
original report copied forward verbatim, never a pointer stub — H/M as `submissions/<label>-C<n>.md`, QA
as `submissions/carryover/qa-report-<NN>.md` per originating audit.

`L-01`, `L-03`, `L-04`, `L-05`, `L-06`, `L-07`, `C-01`, `L-01-run11`, `L-02-run11`, `L-03-run11`,
`L-04-run11`, `L-05-run11`, `L-06-run11`, `L-07-run11`, `L-08`, `L-09`, `L-11`, `L-12`, `L-13`, `L-14`,
`L-15`, `QA-01`, `QA-02`, `QA-03`, `QA-04`, `QA-05`, `QA-06`, `QA-07`, `QA-08`, `QA-09`, `F-01`, `F-02`,
`F-03`, `F-04`, `F-05`, `ECON-A`, `CFG-01`, `F-16-003`.

Two of these gain **recorded extensions** rather than new entries (dedup §2.1, §2.2), which finding-manager
should append to the existing entries, **not** mint as new fingerprints:
- **`L-01` / `6460e35331dff5c2`** — blast-radius extension: `CODE-03`'s owner-footgun half + `ECON-003`. Fold **confirmed correct** against `L-01`'s own title (*"setter missing sane cap"*) and `run08Note`; story-050 adds a **third dependent surface**.
- **`L-01-run11` / `3ab43381ffaf861f`** — site extension: the same CEI violation in `_totalWithdraw` on both contracts. Exploitability **REFUTED on mechanism** (`PM-3`); **CONDITIONAL — reopen if a hook-bearing token or callback-capable adapter is introduced.**

**Not carried over** (already human-triaged disposals): `M-02`, `M-04`, `M-02-run11`, `M-01-run12`, `H-02`,
`L-10` (`false-positive` ×6); `L-02` (`wont-fix`); `M-03` (`merged`); `H-01`, `H-03`
(`downgraded-to-centralization`); `M-01` (`fixed`).

### 3.2 Entries run-17 plausibly resolves — **PROPOSE ONLY, and the proposal is: NONE**

I examined the `0110ce44..cdd0743` delta for anything that would close an open entry. **It closes nothing.**
The change is purely **additive** (`+171` lines across `AYieldStrategy.sol`, both concrete strategies, and
`IYieldStrategy.sol`; no open entry's code is removed or rewritten). Specifically checked and **still live
at HEAD**:
- **`F-02` / `fd58cf00a7e3abab`** (`IYieldStrategy.sol` NatSpec staleness) is the one entry the diff might
  plausibly have touched — story-050 added 50 lines of NatSpec to that exact file. It has **not** been
  fixed: `grep -n "SurplusTracker\|SurplusWithdrawer" src/interfaces/IYieldStrategy.sol` still returns
  `:113` and `:125`. **No flip proposed.**

**Zero `fixed` proposals this run.** Per the standing rule, a status is never auto-flipped, and a fix that
merely stops tripping the scanner is not a verified fix — here not even that much happened.

### 3.3 Non-canonical statuses — recorded, untouched

| Label | Fingerprint | Status | Handling |
|---|---|---|---|
| `M-03` | `3c8331040bba6a7b62e136e08e6bb36f4c992ca6186b5dd21913e7e981b96434` | `merged` (into `M-02`) | Human-set. Left as-is. Its note retains the fingerprint for future standalone matching — `DEDUP-17-03` is disclosed against it, **not** filed as a re-open. |
| `H-01` | `f4eb23ce86d3e24d…` | `downgraded-to-centralization` | Human-set. Left as-is. Not normalized to `open` or to `wont-fix`. |
| `H-03` | `2a3d559aeea8fba6…` | `downgraded-to-centralization` | Human-set. Left as-is. |

None of the three is a suppression source for any run-17 finding, and none was used as one.

### 3.4 Regression / fix-pending headings

- **REGRESSION: none.** The sole `fixed` entry (`M-01` / `9addc259f322848c`, `_skimSurplus` over-skim) is
  untouched by run-17's root-cause classes.
- **FIX-PENDING: not applicable.** This ledger contains **zero** `fix-pending` entries, so neither
  `FIX-PENDING (fix not yet landed)` nor `⚠ FIX-PENDING STILL LIVE (possible incomplete fix)` is raised.
- **`abandoned`: none.** Single-branch project; `currentBranch == defaultBranch == master`.

### 3.5 Branch stamping

Every finding passed on carries `branch: "master"` and enters `branchesSeen: ["master"]`. Branch is **not**
part of the fingerprint. The baseline consulted was `branchBaselines.master.lastAuditedCommit =
0110ce44e1b9da0944595765eb0ae12affc50d7e` — the correct per-branch baseline; no cross-branch diff was used.

---

## 4. Gaps and defects surfaced by this pass (owed elsewhere)

1. **Known-issues cache is empty and seven months stale with a null source pointer** — see §0.2. **No
   suppression authority exists for this project until it is re-extracted from
   `lib/reflax-yield-vault/CLAUDE.md` and `docs/` at HEAD.** Owed to project-manager before run-18. This
   pass suppressed **nothing** on known-issues grounds, so no finding was lost to it — but the reverse risk
   (a genuine sponsor-acknowledged issue re-filed as new) is live and unquantifiable.
2. **Fingerprint mis-citation in `dedup.md` §3.1.** The `SA-005` removal row cites *"`L-07` /
   `1a4e3e8f13bd…`"*. `1a4e3e8f13bdc492` is **`L-03`** (`AYieldStrategy.setSetAsideBuffer`, aggregate
   buffer cap). `L-07`'s actual fingerprint is **`b28e77daefb32529`** (`CurveAMMAdapter.setRoute`), which
   is the entry whose title dedup quotes. **The label and the removal basis are right; the hash is wrong.**
   Flagged so finding-manager does not propagate the wrong hash. (Every other fingerprint cited in
   `dedup.md` — 20 of them — was checked against the ledger and is **correct**.)
3. **Ledger recall gap (`MR-17-08`) stands**: `lastRun` is still `reflax-yield-vault-16` @ `0110ce44`.
   No run-17 shape is ledgered, so **none can reconcile by fingerprint on run-18 until finding-manager
   writes**. Compounded by the run-wide fingerprint-drift risk: `previewExitFor` is a new function, so every
   re-file relation in §2 mints a fresh hash that dedup cannot catch automatically next run. Same class as
   `phstaging-ledger-fingerprint-drift-ratchet-mainnet` and `antimatter-fingerprint-drift-on-rename`.
4. **Suppressions with expiries are parked and visible**, not buried: `MR-17-06` (`WATCH-17-E2`, the
   minter-cushion premise under `DEDUP-17-03`) and `MR-17-05` (the `p ≤ D` / `a ≤ p` dominance contingency
   that re-arms `-01` and `-03` at Medium **with no scanner signal**). Both must survive triage.
5. **`MR-17-01` is a sanitizer-adjacent disagreement worth a human minute**: dedup parked the missing
   `vault.asset() == underlyingToken` check because the scanning agent called its failure mode obvious. If
   the vault's `asset()` differs only in **decimals**, every `convertTo*` mis-scales **silently** — which
   passes the Law-3 surprise test and would make it an in-scope footgun rather than a parked item.
6. **Memory repair owed** (outside this lane): `stable-staker-run15-notes` cites `69c7666e…` for the
   par-exit front-run; the correct fingerprint is `2b9a89d29c34df41…`, verified against
   `reports/stable-staker/ledger.json` this run.
