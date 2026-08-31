# Validity Check — reflax-yield-vault run-17 @ `cdd0743`

- **Project**: reflax-yield-vault · **Branch**: `master` · **Commit**: `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9` `[story-050] previewExitFor on IYieldStrategy`
- **Input**: `severity-classification.md` (16 findings), `sanitized.md`, `dedup.md`
- **Date**: 2026-08-31 · **Agent**: validity-checker · **Ledger NOT modified** · `lib/` read-only

## Result

| Verdict | Count | Findings |
|---|---|---|
| **VALID** | **15** | `-01 -02 -03 -04 -05 -06 -07 -08 -09 -10 -11 -12 -14 -15 -16` |
| **VALID-IF-RESCOPED** | **1** | `-13` (filing location / fingerprint basis, not the merits) |
| **INVALID** | **0** | — |

**Nothing is dropped.** No C4 known-invalid rule reaches any of the 16 on its terms. Law 1 governs: a
wrongly-dropped finding is worse than an extra Low, and I found no case where the invalid list applies
rather than merely resembles.

---

## 0. Location integrity — the check this suite has been burned by

Precedent: `never-file-audit-authored-test-files` — a finding must point at a path present in
`git ls-tree cdd0743` in the source repo, never at a PoC or harness this run wrote into
`workspace/reflax-yield-vault/`.

**Every one of the 16 findings' `Contract/function` field points at first-party `src/` at `cdd0743`.
Zero findings point at an audit artifact.** Verified line by line against the commit:

| Finding | Filed location | Verified at `cdd0743` |
|---|---|---|
| `-01` | `src/AYieldStrategy.sol:571-583 previewExitFor` | ✅ function at `:571`, body `grossToRequest = min(netWanted, clientBalances[...]); netGuaranteed = grossToRequest;` |
| `-02` | `AYieldStrategy.sol:571-583` + `ERC4626MarketYieldStrategy.sol:127-137 _exitFloor` | ✅ `_exitFloor` at `:127`, `convertToAssets` at `:133` |
| `-03` | `ERC4626MarketYieldStrategy.sol:127-186`; `AYieldStrategy.sol:571-583` | ✅ |
| `-04` | `ERC4626MarketYieldStrategy.sol:162-186`; `ERC4626YieldStrategy.sol:126-138 _disposeShares` | ✅ |
| `-05` | `ERC4626MarketYieldStrategy.sol` `_exitFloor:127-135` vs inline `minOut` `:245-246` | ✅ `minOut` recomputed at `:246`, byte-identical expression to `:134` |
| `-06` | `AYieldStrategy.sol:778-783 _withdrawInternal` | ✅ `clientBalances[token][balanceHolder] -= amount;` at `:781`, unconditional on `sharesDisposed`; the documented protocol-favouring rule is in NatSpec at `:761-763` |
| `-07` | `ERC4626MarketYieldStrategy.sol:162-186` + base `:571-583` | ✅ `denominator == 0 ⇒ return (0,0)` at `:171-173` |
| `-08` | `src/AMMAdapters/CurveAMMAdapter.sol:129` vs `test/mocks/MockAMMAdapter.sol` | ✅ **production first** — see §2 below |
| `-09` | `ERC4626MarketYieldStrategy.sol:174 previewExitFor` | ✅ function present; **line drift**, see §3 |
| `-10` | `ERC4626MarketYieldStrategy.sol:162-183` (line 174) | ✅ same drift |
| `-11` | `ERC4626MarketYieldStrategy.sol:162-166` | ✅ declared `external view override` at `:162-166`; base at `AYieldStrategy.sol:571-577` is `external view virtual override` |
| `-12` | `src/interfaces/IYieldStrategy.sol:79` | ✅ `previewExitFor` declaration at `:79` |
| `-13` | `AYieldStrategy.sol:571-583`, x-ref `stable-staker/src/StableStakerV2.sol:876-895` | ⚠ see §1 |
| `-14` | `ERC4626YieldStrategy.sol:185` + `ERC4626MarketYieldStrategy.sol:293` | ✅ `if (totalShares == 0 \|\| totalDeposited[token] == 0) { return; }` at both, exact lines |
| `-15` | `ERC4626YieldStrategy.sol:135 _disposeShares` | ✅ `vault.redeem(sharesToRedeem, recipient, address(this));` at `:135`, return discarded |
| `-16` | `ERC4626YieldStrategy.sol:50 constructor` | ✅ `IERC20(_underlyingToken).approve(_erc4626Vault, type(uint256).max);` at `:50` |

The audit-authored files (`poc-run17-preview-exit.t.sol`, `poc-run17-econ-exit-preview.t.sol`,
`poc-run17-pattern-match.t.sol`, `test/invariant/RealisticExitPreviewPoc.t.sol`,
`test/symbolic/**`, `DominanceRun17Grounding.t.sol`) appear **only in Evidence fields**, which is correct
and required. Confirmed absent from the source repo:
`git grep -l "RealisticExitPreview\|poc-run17\|DominanceRun17" cdd0743` → **no hits**.

`test/mocks/MockAMMAdapter.sol` and `test/mocks/MockERC4626Vault.sol`, cited by `-08` and by the
test-fidelity arguments, **are** in the source tree at `cdd0743` — they are the sponsor's own fixtures,
not ours. Citing them is legitimate.

**One citation defect found — must be corrected before the report goes out.**
`severity-classification.md` §`DEDUP-17-08` says the finding is *"Corroborated by **the repo's own
control test** `testControl_repoMockAmm_hasInfiniteDepthAndAcceptsZeroIn`"*, and §`DEDUP-17-04` similarly
cites `testControl_repoMockVault_cannotExpressAnExitFee` as *"the repo's own control tests"*.
`git grep -n "testControl_" cdd0743` returns **zero hits**. Those are **Tier-3 controls this run wrote**
(dedup describes them correctly as "the Tier-3 control"); the classifier's phrasing re-attributes them to
the sponsor. This is not a finding-location defect and does not invalidate `-04` or `-08` — the control
tests are corroboration, and the production facts they corroborate (`CurveAMMAdapter.sol:129` guard
present, `MockAMMAdapter` guard absent) are directly verifiable in the tree, which I did. But the wording
must change to "this run's control test" so no reader takes an audit artifact for sponsor evidence.

---

## 1. Per-finding verdicts

### `DEDUP-17-01` — base `netGuaranteed` is a ceiling not a floor — **VALID**
All six invalid headings tested; none reaches it. Not a token-behaviour finding (no weird-ERC20, no FoT).
Root cause is in first-party `src/AYieldStrategy.sol`, demonstrated by PoC, not speculative. No owner
action in the path, so Law 3 is not engaged. See §2 on the "unused view" heading, which is the only one
with any surface area here and which I hold does not apply.

### `DEDUP-17-02` — both previews built on fee-free `convertToAssets` — **VALID**
**Fee-on-transfer heading tested and explicitly REJECTED.** The rule is *"Fee-on-transfer tokens (unless
explicitly in scope)"* and it concerns an **ERC20 that takes a cut on `transfer`**. This finding concerns
an **ERC4626 vault exit fee** — the standard-mandated divergence between `previewRedeem` and
`convertToAssets`, which EIP-4626 requires implementations to express. The underlying token here is
unmodified; the fee is charged by the vault on redemption, and `ERC4626YieldStrategy` already exposes the
fee-aware quote at `:83-85`. The token is not weird; the **strategy reads the wrong one of two standard
ERC4626 methods**. The sibling `phlimbo-ea` ruling that FoT is permanently invalid concerns FoT *tokens*
and has no reach here. Sanitizer's §1 disposition on this row is correct and I endorse it verbatim.
Non-standard-ERC20 heading likewise does not apply: no ERC20 quirk is invoked.

### `DEDUP-17-03` — per-account quote floored against the GLOBAL share balance — **VALID**
No invalid heading applies. Note for the record: the *suppressed* leg (client-vs-client value transfer) is
suppressed under the **minter-cushion memo**, a project premise — not under a C4 invalid category — and
the surviving leg (over-issued guarantee) is filed. That is a scope decision already made upstream and
correctly scoped; I do not widen it and I do not use it to invalidate. The reopen trigger `WATCH-17-E2` /
`MR-17-06` is the expiry on that suppression and must survive triage.

### `DEDUP-17-04` — `netGuaranteed > 0` is a false green — **VALID**
The one heading worth testing is *"issues in parent/forked contracts where root cause is OOS"*: instance
(b)'s precondition is the **external** Autopool's `maxRedeem` throttle. It does not apply. The root cause
filed is not the Autopool's behaviour — it is that first-party `_disposeShares` calls `vault.redeem`
**unconditionally** and the first-party preview reports green regardless. Verified: zero occurrences of
`maxRedeem`/`maxWithdraw` in `src/` at `cdd0743`. Under the standing rule "misuse of OOS functions →
VALID", an in-scope contract failing to consult a standard-mandated ERC4626 precondition is a first-party
defect. Instances (a) and (c) are entirely first-party.
Also confirmed: the `M-02` `false-positive` and stable-staker `M-07` `acknowledged` inheritances the
sanitizer declined are correctly declined — a **foreign-ledger** status has no suppression authority here,
and `M-02`'s refutation is about *profitability*, a different claim. Inheriting either would have been an
invalid suppression, not a valid one.

### `DEDUP-17-05` — quoted floor not honoured across a quote→execute gap — **VALID**
Not a user-input-mistake finding: nothing here requires the consumer to enter wrong data — the consumer
does exactly what the NatSpec instructs and is under-delivered. Not speculation: the divergence mechanism
(`minOut` re-derived inline at `:246` rather than carried from the quote) is demonstrated in code and in
a passing PoC. The stable-staker `M-01` / `2b9a89d2…` `wont-fix` correctly carries **no authority** —
its stated reason is that *"nothing in stable-staker can fix it"*, which is a statement about that repo,
and the fix here is a reflax code change.

### `DEDUP-17-06` — one-directional write-down; market pays out over-delivery — **VALID**
The heading that could apply is *"intentional design flagged as a bug"*. It does not. The NatSpec at
`AYieldStrategy.sol:761-763` declares the **deficit** direction intentional (*"principal is decremented by
the REQUESTED (capped) amount … Any shortfall stays as protocol-owned yield"*). The finding is the
**surplus** direction, which that text does not cover and which is undocumented anywhere. Verified at
source: `clientBalances[token][balanceHolder] -= amount` at `:781` is unconditional on `sharesDisposed`,
so the asymmetry is real and not a reading error. Per
`in-source-natspec-carries-no-suppression-authority`, a doc comment that declares one direction intended
cannot dispose of the other. Sanitizer's refusal to apply the minter-cushion suppression is correct — the
memo's premise (minters cannot redeem ⇒ cushion, not counterparty) reaches only the deficit direction.

### `DEDUP-17-07` — `(0,0)` for five unrelated states; `MAX_BPS` footgun — **VALID (owner footgun, right side of the Law-3 line)**
This is the finding the brief asked me to adjudicate, and **the classifier put it on the correct side.**
Verified at source:
- `setSlippageTolerance` (`ERC4626MarketYieldStrategy.sol:89-94`) permits **exactly** `MAX_BPS`:
  `require(_bps <= MAX_BPS, ...)`.
- At `MAX_BPS` the preview returns `(0,0)` (`:170-173`) for a client with live principal, bit-identically
  to an unknown account (base and override both).

Law-3 test, applied in full:
- **Is there a malicious-owner leg?** No. The finding makes no claim requiring owner malice. The
  invalid heading *"owner acting maliciously"* is not engaged at all.
- **Is the harm OBVIOUS to a competent operator?** No. Widening slippage tolerance is a plausible,
  well-intentioned operational response to a volatile pool. The *stated* consequence (a looser `minOut`)
  is obvious. The consequence this finding names — that every integrator calling the published interface
  now cannot tell a funded `990e18` client from an account that never existed — is **not** obvious, is
  not documented, and is not derivable from the setter's own signature.
- **Would a competent, non-malicious owner be surprised?** **Yes.** ⇒ footgun ⇒ **report**.

Aggravating and decisive: the NatSpec at `:155-160` claims the `(0,0)` return *"lets a caller distinguish
'this strategy can guarantee no output' from a low-level failure and handle it as the operational alarm it
is."* The contract does not deliver that distinction — the same `(0,0)` is returned for an unknown
account and a zero request. So this is a defect **against the design's own stated purpose**, not a
mislabelling of intended behaviour. Under `in-source-natspec-carries-no-suppression-authority` the
falsely-exhaustive claim **raises** the finding rather than disposing of it.
The safe-config guidance (`require(_bps <= 1000)`; never deploy at the zero default; the
`previewExitFor(token, <known-funded client>, 1)` `MAX_BPS` canary) is the correct footgun framing —
operational hazard, not attack.

### `DEDUP-17-08` — production adapter rejects `amountIn == 0`, mock does not — **VALID; filing location CONFIRMED CORRECT**
The brief's specific check: **confirmed.** The primary location is
`src/AMMAdapters/CurveAMMAdapter.sol:129`, production first-party source, verified present at `cdd0743`:

```solidity
require(amountIn > 0, "CurveAMMAdapter: amountIn must be > 0");
```

`test/mocks/MockAMMAdapter.sol` has **no such guard** — verified: its `swap` goes straight from
`amountOut = (amountIn * rate) / 1e18` to the `minAmountOut` check, with no zero-input precondition. The
mock is named as the **contrast**, never as the defect site. The defect asserted — production reverts on a
reachable zero-size swap — is a production-behaviour claim, and the two reachable paths
(`vault.balanceOf(strategy) == 0` with principal booked; `convertToShares(gross) == 0` on dust) are
first-party state.

**One rescope note for finding-manager, not a validity objection.** The *reverting* line is
`CurveAMMAdapter:129`, but that `require` is correct defensive code. The **originating** defect is that
`ERC4626MarketYieldStrategy._disposeShares` passes an unguarded `sharesToSell == 0` into it — which is
also where the recommended fix (`if (sharesToSell == 0) return 0;`) lands. Fingerprinting this on
`CurveAMMAdapter.swap` would encode the defect as living in the adapter's correct guard. Recommend the
primary `contract:function` be `ERC4626MarketYieldStrategy._disposeShares`, with `CurveAMMAdapter:129` and
the mock divergence carried as the mechanism. This changes the hash, not the merits.

Automated-tool heading does not apply — this is a code-scan mechanism finding with an enumerated
remedy set, not a detector hit.

### `DEDUP-17-09` — `netWanted * MAX_BPS` panics on `type(uint256).max` — **VALID**
Not a user-input-mistake finding. That heading covers a user typing a wrong value and losing funds;
`type(uint256).max` is the **idiomatic max-withdrawal sentinel**, and the defect is that one interface
member answers it on one implementation and panics on the other. Divergence between two implementations
of a single published interface member is a spec defect. No token, admin, or scope heading applies.
See §2 for the unused-view heading.

### `DEDUP-17-10` — `ceilDiv` compensates the bps leg but not the share round-trip — **VALID**
Dust rounding, filed at QA and routed to `spec-conformance.md`. No invalid heading applies. Not
automated-tool noise (it came from the story-faithfulness pass with an analytic bound and a 256-run fuzz).
The Law-2 routing (a story deviation is never buried in the QA/gas bundle) is correct and I endorse it.

### `DEDUP-17-11` — market override sealed against subclassing — **VALID**
**"Unused view functions" heading tested and correctly rejected by the sanitizer.** The claim is not "a
view is unused" — it is that the override is declared `external view override` where the base is
`external view virtual override`, verified at `:162-166` vs `AYieldStrategy.sol:571-577`. That is a
statement about the inheritance surface, and it would be equally true of a heavily-used function. Filed at
QA, which is where a one-word extensibility defect belongs.

### `DEDUP-17-12` — interface addition breaks four implementers at the next bump — **VALID**
**"Speculation on future code without a demonstrated root cause" tested and REJECTED, and the distinction
holds cleanly here.** The rule's operative words are *without a demonstrated root cause*. Everything
material exists **today** and I re-verified all of it independently:
- The root cause exists today: `previewExitFor` is declared on `IYieldStrategy.sol:79` at `cdd0743`.
- The affected implementers exist today at their own current HEADs — enumeration re-run untruncated:
  `stable-staker/test/Migration.t.sol:924`, `stable-staker/test/mocks/MockYieldStrategy.sol:26`,
  `stable-yield-accumulator/test/StableYieldAccumulator.t.sol:112` and `:215`. Exactly four. Confirmed
  `phoenix-phase-2-staging` has zero **code** implementers (its only hit is a markdown plan document) and
  `antimatter` has none.
- The consequence is mechanically determined, not speculative: a non-abstract contract missing an
  interface member does not compile.

Only the **date** is future (the next submodule bump), not the mechanism. That is a different thing from
speculating about code nobody has written. Filed at Informational, which correctly reflects that the break
is test-suite-only; `MR-17-04` (the unverifiable `deployment-staging/src/` claim) is correctly parked as
**unasserted** rather than filed, which is exactly the right handling of the genuinely speculative half.

**Independent re-verification of the run's load-bearing fact.** I re-ran the consumer census across every
registered submodule at its own HEAD, excluding nested `lib/**`: `antimatter 0, phlimbo-ea 0,
phoenix-nft-staking 0, phoenix-phase-2-staging 0, stable-staker 0, stable-yield-accumulator 0,
yield-claim-nft 0, reflax-yield-vault 32`. **Zero consumers confirmed a third time, independently.**
This is the fact holding `-01`..`-05` at Low, and `WATCH-17-03` is the correct single trigger.

### `DEDUP-17-13` — story-025's mandated safeguard cannot fire — **VALID-IF-RESCOPED**
**The merits are sound and the "speculation" heading does not apply.** I verified the mechanism directly
against `lib/stable-staker` HEAD (`fa06de5`), `src/StableStakerV2.sol:876` `_routeExit`:

```solidity
if (guardUnderwater && _isUnderwater(token, strategy)) {
    if (t.balanceOf(address(this)) >= amount) {
        emit BufferWithdrawn(token, msg.sender, amount);
        strategy.relinquishPrincipal(token, amount);
        return amount;                      // <-- full requested amount, from idle
    }
    revert("StableStaker: strategy underwater");
}
```

and against reflax `AYieldStrategy._relinquishInternal` (`:700-716`), whose NatSpec states *"vault shares
are deliberately untouched"* — confirmed: the body writes `clientBalances` and `totalDeposited` only, with
no external call. So the underwater branch returns `amount` unconditionally, `received == needed` **by
construction**, and the mandated revert is unreachable on that path. **The root cause is demonstrated in
code at HEAD, not speculated.** Only the escalation (the `autoAnnihilate` conjunction) is future-dated,
and it is already capped at Low behind a three-part trigger. The naive "consumer trusts `netGuaranteed`"
finding is correctly **not** filed. The externally-derived-yield rule is correctly applied — buffer
depletion is opportunity cost and is filed only on the **availability** leg, not as a value leak.

**The rescope.** The filed `Contract/function` is `reflax src/AYieldStrategy.sol:571-583 previewExitFor`
with stable-staker's `_routeExit` as a cross-reference. That is backwards: **the defect is entirely in
`StableStakerV2._routeExit`.** reflax's `previewExitFor` is not wrong here, and `relinquishPrincipal`
behaves exactly as documented. Filing it on reflax `previewExitFor` mints a fingerprint
(`AYieldStrategy:previewExitFor:<class>`) that (a) will collide conceptually with `-01`..`-05`, which are
genuinely about that function, and (b) will never be matched by a stable-staker scan that walks over the
actual defective code.

**Rescope to apply:** record the finding's `contract:function` as
`StableStakerV2._routeExit` and carry it as a cross-repo integration entry, exactly as the existing
`F-03` / `52f9b84a54ec9a65` precedent does in this ledger. Keep the `spec-conformance.md` `F-17-04`
channel and the Low cap — those are right. This is a **filing correction, not a merits objection**; the
finding must not be dropped and must not lose its trigger.
This is *not* the "issues in parent/forked contracts where root cause is OOS" invalid heading:
`stable-staker` is a registered, first-party, separately-audited project in this suite, not a third-party
or forked dependency. Cross-repo is a routing question here, never an invalidity one.

### `DEDUP-17-14` — `_totalWithdraw` silent early return — **VALID**
**"Common findings from automated tools without a demonstrated H/M exploit path" tested.** The heading
does not invalidate it. Read precisely, the rule removes a bare detector hit *submitted as H/M*. This is a
Slither `incorrect-equality` hit that (a) carries a traced consequence beyond the detector's output — the
two-phase `totalWithdrawal` window is consumed by the silent no-op while principal stays booked — and
(b) **is filed at Low, not H/M**, so the rule's own condition is not met. Both sites verified verbatim at
`ERC4626YieldStrategy.sol:185` and `ERC4626MarketYieldStrategy.sol:293`. Kept.

### `DEDUP-17-15` — direct strategy discards `vault.redeem`'s return — **VALID**
Same heading, same disposition. Verified at `ERC4626YieldStrategy.sol:135`: the return of `vault.redeem`
is discarded and there is no `minOut` on that call. It survives as a finding rather than `unused-return`
noise because it carries a mechanism argument — it is why `-01`/`-02` fail **silently** instead of
reverting — and it is filed at Low. Not H/M, so the rule does not bite.

### `DEDUP-17-16` — raw `approve` with unchecked bool in the constructor — **VALID**
Both candidate headings tested; the sanitizer's reasoning **holds and I verified it at source**.

1. **Approve race / `safeApprove` front-running — DOES NOT APPLY.** That C4 invalid covers the ERC20
   allowance double-spend across an `approve(x) → approve(y)` transition, where a spender front-runs the
   change to spend `x + y`. Verified at `ERC4626YieldStrategy.sol:50`: this is a **single one-shot
   `approve` inside the constructor**, the spender is the strategy's own `_erc4626Vault` (validated
   non-zero on the line above), and there is no second `approve` and no allowance transition anywhere in
   the contract. There is no transaction to front-run — the code runs at deployment. The asserted failure
   mode is a **`bool`-decode revert on a token that returns no data**, which is a different defect
   entirely. The sanitizer's characterisation is correct and the reasoning survives scrutiny.
2. **Non-standard/weird ERC-20 — DOES NOT APPLY, because USDT is the carve-out and USDT is the trigger.**
   The rule is *"Non-standard/weird ERC-20 tokens (**except USDT**)"*. USDT's `approve` returns no data,
   so a `bool`-decoding call reverts. This finding is **squarely inside the exception**, which means the
   carve-out is the finding's *basis*, not a suppression of it. Confirmed: the finding rests on USDT
   specifically and invokes no other token quirk — no rebasing, no deflationary, no fee-on-transfer leg.

**Law 3 correctly not invoked**: the failure is deploy-time and loud (nothing deploys), so it fails the
surprise test, and QA is the right severity. Kept for the one-line `SafeERC20.forceApprove` fix.

---

## 2. The "unused view functions (QA at best)" heading — argued explicitly

The brief is right that this is the heading with the most surface area, since `previewExitFor` has **zero
consumers** (re-verified independently, §1 `-12`) and the entire run-17 delta is that function. If the
heading applied, most of the report would collapse. **It does not apply, for three reasons, and I state
them because "no consumer" resembles "unused" closely enough to be waved through.**

1. **The rule targets a dead getter; this is a published interface member.** The rule's purpose is that a
   view nobody calls has no impact path, so a defect in it cannot hurt anyone. That reasoning holds for a
   vestigial helper left behind by a refactor. `previewExitFor` is the **opposite**: story-050 added it to
   `IYieldStrategy.sol:79` — the protocol's **external integration contract** — specifically so that
   external consumers *would* call it. Zero consumers is its state on day one of a deliberately published
   API, not evidence that it is vestigial. Applying an "it's dead code" rule to a freshly-published
   integration surface inverts the rule's intent.

2. **A demonstrated wrong return value is not the same as a harmless dead getter.** Every one of
   `-01`..`-05`, `-07`, `-09` asserts a specific numeric or behavioural falsehood in what the function
   returns, each with a passing PoC against real contracts — `1000e18` quoted / `500e18` delivered;
   `19,602e18` quoted / `181.9e18` delivered; two `980.1e18` floors against one `1000e18` position; a bare
   `Panic(0x11)` where the sibling implementation answers. These are demonstrated defects in a value the
   protocol publishes under the word "guarantees". The rule was never a licence to ship wrong numbers on a
   documented interface.

3. **The rule is a severity cap, and the cap is already respected — and that limb belongs to the severity
   audit, not to me.** The rule as written is *"Unused view functions (**QA at best**)"* — a ceiling on
   severity, not a validity test. It cannot make a finding invalid; at most it argues a Low should be a
   QA. Every affected finding is already at **Low or QA**, and zero-consumer status is precisely the
   stated reason the classifier held all of `-01`..`-05` below Medium. The one place where the
   QA-vs-Low band is genuinely arguable under this heading is `-09` (a spec divergence with no asset path
   on a function nothing calls) and `-11` (already QA). **I flag `-09`'s band as a question for the
   severity audit and take no position on it here** — per the brief, I do not re-litigate severity, and
   the band question is not a validity question either way.

**Conclusion: the heading invalidates nothing in this run.** Sanitizer §1 reached the same result on the
narrower ground that `-11` is about sealing rather than disuse; I endorse that and extend the reasoning to
cover the whole `previewExitFor` set, which the sanitizer left implicit.

---

## 3. Accuracy notes for the report writer (none affect validity)

1. **Correct the control-test attribution.** `testControl_repoMockAmm_hasInfiniteDepthAndAcceptsZeroIn`
   and `testControl_repoMockVault_cannotExpressAnExitFee` are **this run's** Tier-3 controls, not the
   sponsor's — `git grep "testControl_" cdd0743` returns zero hits. `dedup.md` says "Tier-3 control"
   (correct); `severity-classification.md` says "the repo's own control test" (wrong) in `-04` and `-08`.
   Fix the wording before submission. Precedent: `never-file-audit-authored-test-files`.
2. **Line-citation drift in `-09` and `-10`.** Both cite
   `ERC4626MarketYieldStrategy.sol:174` for the `Math.ceilDiv(netWanted * MAX_BPS, denominator)`
   gross-up. At `cdd0743` that statement is on **line 176** (`:174` is the closing brace of the
   `denominator == 0` guard). The function, the expression, and the mechanism are all correct — only the
   line number is off by two. Worth fixing so a reader following the citation lands on the code.
3. **`-08` fingerprint basis** — see §1: prefer `ERC4626MarketYieldStrategy._disposeShares` as the
   primary `contract:function` over `CurveAMMAdapter.swap`, which is the correct guard rather than the
   defect.
4. **`-13` rescope** — see §1. This is the only verdict in the run that is not a plain VALID, and it is a
   filing correction, not a merits objection.

## 4. Suppression-authority statement

I suppressed nothing, and I record what authority was and was not available:
- **Known-issues cache carries no authority** for this project (`knownIssuesCount: 0`,
  `knownIssuesSource: null`, extracted 2026-01-23, seven months stale against `cdd0743`). The sanitizer
  exercised none; neither did I. An empty cache is not evidence that no known issues exist. Re-extraction
  owed to project-manager before run-18. Same class as
  `phstaging-known-issues-cache-unfalsifiable` / `phlimbo-ea-known-issues-unfalsifiable`.
- **In-source NatSpec carries no suppression authority** and was used in the opposite direction —
  as aggravating in `-01`, `-02`, `-05`, `-06`, `-07`, `-15`.
- **Foreign-ledger statuses carry no authority here** — stable-staker `M-07` (`acknowledged`) and
  `M-01` (`wont-fix`) were correctly declined as suppressions for `-04` and `-05`.
- **No finding in this run rests on a malicious-owner premise.** Verified across all 16.
