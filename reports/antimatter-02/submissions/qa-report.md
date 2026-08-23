# QA Report — antimatter (run-02)

**Project**: antimatter (`lib/antimatter`)
**Commit audited**: `c91bc1a44424b853247a3849732bf89547defdec`
**Previous audited commit**: `0bb82d867dba43bc514a508800826f90436c2ee3` (run-01)
**Scan mode**: regression (`0bb82d8..c91bc1a`)
**Branch**: `master`
**Repo**: https://github.com/Behodler/antimatter
**Report family**: `reports/antimatter-02`

## Scope of this document

This is the single QA bundle for run-02. It carries every Low, Centralization and QA/Non-Critical
finding raised **this run**, plus a clearly-separated carryover section holding the full text of the
run-01 QA-band entries that remain open at `c91bc1a`.

**No new High or Medium finding was raised this run.** There are therefore no individual
`submissions/H-*.md` or `submissions/M-*.md` files for run-02; the open High and Mediums are the
run-01 entries, whose status is governed by the ledger.

Two exclusions are deliberate and neither is a suppression:

- **`F-04` is not here.** Story-conformance is a Law-2 concern and is adjudicated in
  `submissions/spec-conformance.md`, at whatever band it lands. It must never be absorbed into this
  bundle. The same rule keeps carryover `F-01`, `F-02` and `F-03` out of the carryover section below;
  `F-01` is nevertheless **cross-referenced** by `Q-05`, because `Q-05` exists to stop `F-01` being
  falsely closed.
- **The fee-on-transfer finding (`374e69850c5fc60a`) is not here and is not in the ledger.** It was
  adjudicated **INVALID** — the settlement path fails closed on two independent legs — and was kept
  out of the ledger on that basis rather than filed and triaged away. 4naly3er raises the same
  observation generically as its tool-`M-1`; see Appendix A for why it is not promoted.

## Provenance of proofs — read before citing any PoC

Every proof-of-concept referenced below is **audit-authored**, written for this audit and living
under `workspace/antimatter/test/audit/**`. These files:

- are **NOT** part of the antimatter project's own test suite,
- do **NOT** exist in the submodule at any commit, and
- must **never** be cited as project test coverage, nor filed as a project test path.

They demonstrate the behaviour described; they say nothing about how well the project tests itself.

## Tooling coverage

All **6** in-scope first-party files — `src/Antimatter.sol`, `test/Annihilation.t.sol`,
`test/Antimatter.t.sol` and the three `test/mocks/*` — were analysed by all **4** tools (Slither
0.11.3, Aderyn 0.6.8, Semgrep 1.163.0, 4naly3er). That coverage was reached **only after working
around each tool's default test-exclusion**: on its default invocation, *every one of the four
covered exactly 1 of 6 files while exiting successfully*.

| Tool | Default invocation | Why | Authoritative pass |
|------|-------------------|-----|--------------------|
| Slither | 1 of 6 (`src/Antimatter.sol`), exit 255 = "findings present" | crytic-compile's foundry integration skips `test/**` | `--foundry-compile-all` → 6 of 6, 121 first-party results |
| Aderyn | 1 of 6, exit 0, "Ingesting 1 compiled files" | reads `foundry.toml`'s `src = "src"` | scratchpad project with `src='allsrc'` → 6 source units, 752 SLOC |
| Semgrep | 1 of 6, exit 0 | built-in ignore list drops `test/` **even when the paths are named explicitly on the command line** | flat copy outside the ignore globs → 6 files, 42 results |
| 4naly3er | did not run at all (see Appendix A) | bundled solc capped at 0.8.26 against a `^0.8.27` pragma | `solc-0.8.27` added → 6 files, GAS 12 / NC 23 / L 15 / M 2 |

The point is not the workarounds; it is that **a green exit code proved nothing about coverage**.
Every count above is falsifiable from `reports/antimatter-02/tier1/tool-invocations.json` and the
saved per-tool artifacts.

Two recorded traps were re-tested rather than assumed:

- **Slither `--filter-paths`.** Both `"lib/"` and `"antimatter/lib/"` returned 4 results, not 0, so
  the catastrophic false-clean did not reproduce on 0.11.3 with this layout. Filtering was still not
  used: the unfiltered pass yields 12 first-party records against the filtered 4, and
  `shadowing-local` (the seed for carryover `Q-01`'s part (b)) **disappears under both filters**
  because the shadowed element lives in `lib/openzeppelin-contracts`. First-party selection was done
  in post-processing instead, which is falsifiable from the artifacts.
- **Semgrep `p/smart-contracts`.** 42 results, **all INFO**, zero WARNING or ERROR. This is a
  gas/style ruleset with no Solidity vulnerability detectors. A clean Semgrep run on this repo is
  evidence of nothing and must not be cited as one. One result (`use-ownable2step`) is retained,
  purely as corroboration of 4naly3er L-2/L-12 under `C-03`.

## Summary

### New this run

| Severity | Count |
|----------|-------|
| Low Risk | 1 |
| Centralization Risk | 1 |
| QA / Non-Critical | 2 |
| **Total** | **4** |

> **Severity revision, 2026-08-20 (human-authorised).** `L-05` was **downgraded Low → QA** and moved
> into the QA / Non-Critical section below; `L-01` (carryover) was **downgraded Low → QA** and moved
> into the carryover QA section. **Both remain `open`; neither is closed, and neither is renumbered** —
> `L-01` and `L-05` keep their labels, so the `L-` prefix no longer implies the Low band for these two.
> Counts above are post-revision. Reasons are recorded on each entry and in
> `reports/ledgers/antimatter.json`.

| Label | Issue ID | Fingerprint | Ledger severity | Note |
|-------|----------|-------------|-----------------|------|
| L-04 | `am2l4` | `25088b59893f37e0` | low | new in this delta |
| L-05 | `am2l5` | `3a8dbad19ba9104e` | **qa** (was `low`, downgraded 2026-08-20) | new in this delta; band still **conditional on a mutable registry** — re-raises to Medium on one registration tx |
| C-03 | `am2c3` | `2e9152785e3dc975` | qa | new to the **ledger**, not to the **code** |
| Q-05 | `am2q5` | `1b960956475d434a` | qa | carries a false-closure block on `F-01` |

All fingerprints are the legacy form `sha256(contract:function:rootCauseClass)[:16]` with an empty
`entryPoint`, carried verbatim from the ledger so a later run reconciles rather than re-files. Each
was verified not to collide with any of the 19 pre-existing ledger fingerprints. `Q-05`'s basis is
minted on the **new** function name `annihilate` — correct, and not fingerprint drift.

`L-04` and `L-05` share a call site (`toStableAmount:292`) and a delta. **They must not be
collapsed**: different trigger classes, different fixes, and neither fix fixes the other. Both are
owed. See the do-not-collapse note under each.

### Carryover from run-01 (still open at `c91bc1a`)

| Label | Issue ID | Fingerprint | Ledger severity | Status this run |
|-------|----------|-------------|-----------------|-----------------|
| L-01 | `am1l1` | `ad4b779566291190` | **qa** (was `low`, downgraded 2026-08-20) | **re-worded, downgraded, NOT closed** — impact inverted; **no permissionless vector** |
| L-02 | `am1l2` | `5c89b2d372ec9286` | low | unchanged |
| L-03 | `am1l3` | `0ed1c6e3270816c5` | low | guard moved pre-burn; **brick remains** |
| C-01 | `am1c1` | `2a844d32db2eb0f9` | low | unchanged, **sharpened** by the delta |
| C-02 | `am1c2` | `3a90280bed325637` | qa | unchanged |
| Q-01 | `am1q1` | `8c2dcc57bcd3be05` | qa | unchanged, **aggravated in framing** |
| Q-02 | `am1q2` | `c330566040a453ea` | qa | unchanged (line refs moved) |
| Q-03 | `am1q3` | `0174ea0bd59a9b12` | qa | unchanged |
| Q-04 | `am1q4` | `507e375d3ef4abfe` | qa | unchanged; instance count grew as **test growth** |
| F-01 | `am1f1` | `3aac91383dcb6060` | low | **cross-reference only** — faithfulness, adjudicated in `spec-conformance.md`; see `Q-05` |

Carryover bodies are **full copies**, not stubs, and appear in the clearly-separated section below.
The run-02 `L-XX`/`C-XX`/`Q-XX` sequence covers only run-02's own findings; nothing is renumbered
around the carryover.

Severities here are deliberately unflattering. This is the low-value channel: nothing in this
document puts user funds at risk along a path an attacker controls, and several entries are expected
to die in triage. They are recorded rather than dropped so the decision to dismiss them is a visible
one (Law 1: recall beats report-tidiness).

---

## Low Risk Findings

### [L-04] The new `decimals()` staticcall copies unbounded return data, so a registered token can make `toStableAmount` — and every annihilation of that pair — cost more gas than a block allows <!-- id: am2l4 -->

**Fingerprint**: `25088b59893f37e0` (`src/Antimatter.sol:toStableAmount:UnboundedReturndataCopyOnMetadataCall`)

**Location**: [`src/Antimatter.sol#L288-L295`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L288-L295)

**New in this delta**: yes. At `0bb82d8` `toStableAmount` made **no external call to `stable` at
all**. The call site is introduced by story-002 (`f48f30d`) as the fix for ledger `M-01`.

**Description**: The metadata cross-check reads the token's own decimals through a raw low-level
call:

```solidity
(bool ok, bytes memory data) = stable.staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));  // :292
if (!ok || data.length != 32) revert DecimalsUnavailable(stable);                                // :293
```

`bytes memory data` allocates and `RETURNDATACOPY`s the callee's **entire** return buffer into
memory **before** `data.length != 32` is ever evaluated. Memory expansion is quadratic, so the caller
pays for a size the callee chooses. All remaining gas is forwarded, so a `decimals()` that simply
burns gas reaches the same outcome via the 63/64 rule.

The `StablecoinNotRegistered` guard at `:285` runs first, so no caller can aim `toStableAmount` at an
address of their own choosing — owner registration is the only way in, and the realistic vehicle for
the hostile behaviour appearing *after* registration is an upgradeable proxy.

**Impact**: Denial of service only — nothing is stolen, burned or stranded. The revert precedes
`_burn` at `:239`, so holders keep their tokens and their entitlement. Two things die for the
affected pair: `annihilate` (which reaches `toStableAmount` at `:230`), and the **public
`toStableAmount` quote helper** relied on by front-ends and integrators.

**Measured** (audit-authored PoC — see provenance note above):
`workspace/antimatter/test/audit/Tier2Delta.t.sol`

| `decimals()` return size | Gas |
|---|---:|
| 32 bytes | 16,782 |
| 640 KB | 1,815,823 |
| 6.4 MB | 158,677,386 |
| 64 MB | out-of-gas under a 30,000,000 cap |

- `test_returndataBombGasCost` — the table above. **Passing.**
- `test_returndataBombBricksQuote` — reverts out-of-gas under a 30,000,000 gas cap. **Passing.**

**Why only Low — and why the deflator is stated rather than hidden**: the exclusive trigger-holder is
the registered token itself, and such a token can already deny annihilation for its own pair more
cheaply (revert `transferFrom`, pause, blacklist Antimatter). That marginal-capability deflator is
**IMMATERIAL, NOT ABSENT**, and it is recorded here precisely so the Low is not read as understated:
a returndata gas bomb *also* kills the public `toStableAmount` quote helper, which a `transferFrom`
revert does **not** — a view-only quote never reaches `transferFrom`, so off-chain quoting, front-end
previews and integrator calls keep working under a `transferFrom` revert and stop working under this
one. The residual marginal capability is real but small: a view-function outage on a pair that is
already unusable for settlement.

Not raised to Medium: no meaningful capability is newly granted, nothing is consumed, no unprivileged
attacker participates and no value leaks. Not suppressed as "weird ERC-20" (the root cause is
caller-side and token-independent) nor as a reckless admin mistake (registration is the intended
operation; the hostile behaviour appears afterwards). Law-3 verdict: **footgun, in scope** —
registration-**gated**, not owner-**caused**, and a competent non-malicious owner would be surprised
that registering a token hands that token a block-gas-limit lever over a public view function on the
settlement path.

**Recommendation**: read exactly one word and ignore the rest — an assembly staticcall with a 32-byte
output buffer plus an explicit `returndatasize() == 32` check, and/or cap the forwarded gas
(`{gas: 30000}` is ample for any real `decimals()`).

```solidity
// 32-byte output buffer; nothing beyond it is ever copied, and the gas is metered.
bool ok;
uint256 actualDecimals;
assembly {
    let ptr := mload(0x40)
    mstore(ptr, shl(224, 0x313ce567))                        // decimals()
    ok := staticcall(30000, stable, ptr, 4, ptr, 32)
    ok := and(ok, eq(returndatasize(), 32))                  // exactly one word, or nothing
    actualDecimals := mload(ptr)
}
if (!ok) revert DecimalsUnavailable(stable);
if (actualDecimals != decimals) revert DecimalsMismatch(stable, decimals, actualDecimals);
```

The stated reason at `:289-291` for preferring a raw staticcall over `try/catch` — an uncatchable
`uint8` decode of a value above 255 — remains valid and is entirely unaffected. Bounding the copy and
metering the gas does **not** weaken the `M-01` cross-check in any way: that check needs exactly 32
bytes and a few thousand gas.

> **Do not collapse with L-05 (`3a8dbad19ba9104e`).** Same call site, same delta, **different trigger
> class and different fix**. L-04 needs a hostile or broken token and is defence-in-depth; L-05 is
> reachable by an honest token and is an operational hazard. **L-05's fix does not fix L-04**:
> `bytes memory data` at `:292` copies all returndata *before* any check runs, so moving the
> cross-check to registration time, caching it, or changing what happens on an unavailable answer
> leaves the unbounded copy exactly where it is on every call that still performs one. Conversely,
> bounding the copy does not make an unavailable `decimals()` available. **Both fixes are owed.**

---

## Centralization Risks

### [C-03] Antimatter inherits single-step OpenZeppelin `Ownable` rather than `Ownable2Step` <!-- id: am2c3 -->

**Fingerprint**: `2e9152785e3dc975` (`src/Antimatter.sol:(inherited Ownable):SingleStepOwnershipTransfer`)
**Ledger severity**: `qa` (kept in this section for topical grouping)

**Location**: [`src/Antimatter.sol#L8`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L8), [`#L22`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L22)

Antimatter inherits single-step OpenZeppelin `Ownable`; consider `Ownable2Step`.

Combined with `C-02` (`3a90280bed325637`, no local pause authority), every incident lever the
protocol has runs through one owner key whose transfer has no undo.

**Not a regression, and not introduced by this delta.** Verified: `Ownable` traces to the
repository's initial commit `a94fd72`, and the `0bb82d8..c91bc1a` diff does not touch the import at
`:8` or the inheritance at `:22`. This is a **run-01 coverage gap** surfaced by the 4naly3er repair
between runs (4naly3er and Semgrep did not run in run-01), not a defect introduced by `c91bc1a`. Any
downstream stage that files it as a regression, or attributes it to `c91bc1a`, is wrong. `origin:
new` on the ledger entry means *new to the ledger*, not *new to the code*.

**Recommendation**: inherit `Ownable2Step` so ownership transfer requires the incoming owner to call
`acceptOwnership`. One-line change, no behavioural cost, and it composes with the incident-response
runbook `C-02` already asks for.

> **Deliberately narrow.** The mistyped-`transferOwnership` narrative was **stripped**: that
> consequence is obvious, no competent owner is surprised by it, and it therefore fails the Law-3
> surprise test and hits the reckless-admin carve-out. Declining that escalation does not license
> withholding the finding (Law 1 forbids that), which is why the structural observation survives at
> QA. Source: 4naly3er L-2 / L-12 — a common automated-tool finding, which C4 discounts **as a
> severity ceiling only, never as a suppression**. A reasonable `/ledger` triage outcome is
> `wont-fix`; that is a human call.

---

## QA / Non-Critical

### [Q-05] The new exact-equality quote check is not a slippage or minimum-output guard, yet its comment and error name present it as protection against being short-changed <!-- id: am2q5 -->

**Fingerprint**: `1b960956475d434a` (`src/Antimatter.sol:annihilate:MisleadingGuardFramingOverstatesCoverage`)

**Location**: [`src/Antimatter.sol#L232-L257`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L232-L257)

**Description**: The delta adds a quote and an exact-equality post-condition:

```solidity
// What the minter says it will mint for that deposit. Measuring against its own quote,
// rather than merely against zero, means a short mint cannot pass unnoticed.          // :232-233
uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);          // :234
...
uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;               // :256
if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(expectedForStable, mintedForStable); // :257
```

**This check is not a tautology, and this report does not call it one.** `mintedForStable` is a
**balance delta** — Antimatter's phUSD balance after the mint minus the `:244` snapshot — not the
minter's return value. The exact equality therefore **does** catch mid-call phUSD injection, proven by
this run's own PoC: `Tier2Delta.t.sol::test_midCallPhUSDInjectionNowReverts` reverts
`PhUSDAmountMismatch(100e18, 100e18+1)` when a hooked stablecoin injects 1 wei of phUSD mid-call. The
check genuinely narrows carryover `L-01`'s donation-attribution gap. Dismissing working protection is
an error in its own right.

**What the check does cover**:
- A minter whose `mint()` disagrees with its own `calculateMintAmount()` — genuine protection against
  a future or swapped minter.
- Third-party phUSD arriving at Antimatter between the `:244` snapshot and the `:256` read — proven.

**What it does not cover**: anything the caller saw at signing time. `PhusdStableMinter.mint` computes
its own `phUSDAmount` at `PhusdStableMinter.sol:212` by calling the **same public view with identical
arguments in the same transaction against the same config storage**. Both sides therefore re-quote at
whatever rate is live at execution, so an owner rate change mid-flight is *tracked* by the check
rather than resisted by it:

1. Owner calls `minter.updateExchangeRate(usdc, 0.5e18)` while Alice's `annihilate(usdc, alice, 100e18)`
   is pending.
2. Alice lands at the new rate: 100 AM burned, 100 USDC pulled, **150 phUSD delivered instead of the
   200 she saw when she signed**, with the burn already irreversible.
3. `expectedForStable` (50e18) **equals** `mintedForStable` (50e18) — because the check re-quotes at
   the new rate too — so `PhUSDAmountMismatch` does not fire and the code reports success.

There is **no caller-supplied minimum-output parameter anywhere in `annihilate`**. A reader of the
comment at `:232-233` and of the error name `PhUSDAmountMismatch` would reasonably believe otherwise.

**Impact**: none from the check itself, which does real work. The impact it fails to prevent is ledger
`F-01`'s, unchanged.

**Why this is filed, and why it must survive triage.** QA is the honest band and inflating it would
be overstatement. But this finding's value is not its band — it is a **tripwire**. The new code now
*looks like* the guard `F-01` asked for without being it, and that is strictly worse for a future
reader than the guard's plain absence was: a triager comparing `F-01`'s recommendation against
`:234`/`:257` would find an apparent match and close a live finding. The standing rule that falsely
exhaustive in-source docs **raise** severity is applied here to stop this being culled as a nitpick,
not to manufacture impact.

> **FALSE-CLOSURE BLOCK — `F-01` (`3aac91383dcb6060`, status `open`). Watch item `WATCH-02-02`.**
>
> `F-01` is *"no minimum-output guard on an already-irreversible burn"*, and no minimum-output guard
> exists at `c91bc1a`.
>
> **`F-01` may be marked `fixed` ONLY on evidence of a CALLER-SUPPLIED minimum-output parameter**
> (e.g. `uint256 minPhUSDOut` checked as `amount + mintedForStable >= minPhUSDOut` before `:260`).
> The `:234`/`:257` exact-equality pair does **NOT** satisfy this and **must never be cited as
> satisfying it**: both sides re-quote from the same view in the same transaction, so the check tracks
> an owner rate change instead of resisting it.
>
> This block is **preserved intact** through this run's re-wording. Narrowing what the check is
> accused of *being* does not change what it fails to *be*; its ability to catch mid-call injection is
> irrelevant to `F-01`, which is about binding the price the caller saw at signing time.

> **Re-weigh condition (binding).** If `F-01` is ever **closed**, or if this guard is ever **cited as
> closing it**, `Q-05` must be re-weighed to **Low**. It is held at QA only because `F-01` remains open
> and independently visible, so the framing defect costs a reader nothing they cannot recover from the
> ledger. The moment `F-01` is closed — or closed on the strength of this check — the misleading
> comment becomes the only surviving account of what the settlement path guarantees, and the reader
> has no correction available.

**Not collapsed into `F-04`.** This is a defect in what the code's own comment claims, not a deviation
from a story — no story speaks to this post-condition at all, which is exactly what `F-04` reports.
Collapsing them would hide the `F-01` tripwire inside a process finding.

**Recommendation**: either

1. reword `:232-233` to state what the check actually covers — *"the minter's `mint()` must agree with
   its own `calculateMintAmount()`, and no third-party phUSD may arrive mid-call; this is NOT a
   slippage or minimum-output guard"* — and rename the error accordingly; or
2. close `F-01` properly by adding a `uint256 minPhUSDOut` parameter to `annihilate` and checking
   `amount + mintedForStable >= minPhUSDOut` before `:260`.

Option 2 subsumes option 1 and is preferred.

---

### [L-05] An honest, correctly-registered stablecoin whose `decimals()` is not `view` is rejected by the new cross-check, and the minter's own mint path keeps working — so the failure is invisible to mint-path monitoring <!-- id: am2l5 -->

**Fingerprint**: `3a8dbad19ba9104e` (`src/Antimatter.sol:toStableAmount:ExternalMetadataLivenessOnCriticalPath`)

**Location**: [`src/Antimatter.sol#L288-L295`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L288-L295)

> **BAND: QA — downgraded from Low on 2026-08-20 (human-authorised, recorded not re-litigated).**
> **Status is unchanged: `open`. Label is unchanged: `L-05` — not renumbered.**
>
> **Reason: likelihood is near-zero on the only reportable trigger.** After the rescope below, **T3**
> is the *entire* reportable core (T1/T2 are sponsor-intended fail-closed design per story-002).
> Stablecoins that clear the bar for registration as protocol collateral are authored by well-funded
> teams, so a `decimals()` that is not `view` is **not a plausible oversight**. This *corroborates*
> the deciding evidence already recorded below — the dated human attestation at story-002:258 and
> staging's registered set (USDC 6dp, DOLA 18dp, USDe 18dp, all standard `view` getters) — it does
> not replace it.
>
> **What survives the downgrade, unchanged:** the **detection asymmetry** (leg (b)) — which is the
> durable part and is **not** about token quality; the **mitigation guidance**, including that the
> fail-open fallback must **not** be the headline fix; and the **do-not-collapse** note against
> `L-04`.
>
> **The QA band, like the prior Low, is CONDITIONAL ON A MUTABLE REGISTRY and re-raises to Medium on
> a single registration transaction.** The escalation trigger below is **live and unmodified**.

**New in this delta**: yes. At `0bb82d8` `toStableAmount` made no call to `stable` at all; the
dependency is introduced by story-002 (`f48f30d`) as the fix for ledger `M-01`.

**Scope of this entry — read first.** This finding reports **two things only**:

**(a) Trigger T3.** An **honest**, correctly-registered token whose `decimals()` is not declared
`view` is rejected by `STATICCALL` (`ok == false`) and reverts `DecimalsUnavailable`, even though its
registration is correct and its answer would have **matched**. PoC-proven.

**(b) The detection asymmetry.** `PhusdStableMinter.mint` keeps working for that same token, because
it reads its own stored `config.decimals` at `PhusdStableMinter.sol:254` and never queries the token.
The mint-path smoke test therefore passes green while the antimatter product is dead for that pair.

Two other triggers are **documented context, not defects, and are not reported as such**:

> **T1** — a registered upgradeable stablecoin stops answering `decimals()` after an implementation
> change. **T2** — the owner registers an old-style token that never had `decimals()` at all.
>
> Both are **sponsor-intended design, on the record.** story-002's "Why not try/catch" section
> (lines 129-160) enumerates empty return data, an address with no code and a reverting `decimals()`,
> and states: *"Both approaches fail closed, which is the security property."* Reporting them as
> defects would flag intended design as a bug. They belong on the registration checklist.

**The mechanism is not the staticcall.** `toStableAmount` is declared `public view`, so a
state-mutating `decimals()` fails **identically** under `try/catch`. Switching call form would not
admit a T3 token. The defect is that the design places a **liveness dependency on a third-party
token's metadata being callable in a view context at settlement time**. story-002's justification for
preferring a raw staticcall stands and is not challenged here.

**Description / path** (no attacker is required — this is a liveness and configuration hazard, and is
classified as one):

1. The owner registers stablecoin `S` on `PhusdStableMinter` with the **correct** decimals (say 18).
   `S` is honest: it implements `decimals()`, it answers 18, and its transfer/approve/balance
   semantics are entirely standard. Its `decimals()` is simply not declared `view` — it increments a
   read counter, lazily caches, or emits.
2. Any `toStableAmount(S, x)` reaches the staticcall at `:292`. `STATICCALL` rejects the
   state-mutating callee, so `ok == false`, and `:293` reverts `DecimalsUnavailable(S)` — despite the
   registered value and the token's own answer **agreeing**.
3. Every `annihilate(S, ...)` therefore reverts, for every holder, until the configuration changes.
4. **Detection asymmetry**: `minter.mint(S, ...)` continues to work perfectly. A mint-path smoke test
   passes green while the antimatter product is dead for that pair.
5. Recovery: the owner registers a working alternative stablecoin, or holders pair against any other
   already-registered one.

**Impact**: no loss; **delayed realisation**. The revert happens in `toStableAmount` (reached from
`:230`), strictly **before** `_burn` at `:239` and before any transfer, so no antimatter is burned,
no stablecoin is pulled and no phUSD is minted. Antimatter is inert held alone and its entire value
is the phUSD annihilation emits, so while the condition persists that already-distributed reward
entitlement cannot be realised against the affected stablecoin. A holder who exits during the outage
takes whatever discount the market applies to a temporarily unredeemable claim — a market consequence
of an outage, not a protocol loss, and not counted as a value leak here.

**PoC** (audit-authored): `workspace/antimatter/test/audit/Tier2Delta.t.sol`
- `test_statefulDecimalsBricksHonestToken` — a token with
  `function decimals() public returns (uint8) { reads++; return 18; }`, registered with
  `decimals = 18` (**correct**), reverts `DecimalsUnavailable(token)` on `toStableAmount`.
  **Passing — T3 proven.** T1 and T2 are not PoC'd and are not reported as defects.

**Why QA (downgraded from Low), and what the band actually rests on.** The C4 Medium clause *"the function of the protocol
or its availability could be impacted"* **is engaged on its face**, and is declined on the likelihood
of the triggering configuration, not on mechanism. Two deflators carry it: the path fails closed
before the burn, so this is delayed realisation rather than loss and the value-leak limb never
engages; and `stable` is a free parameter, so holders route around the affected token whenever a
second stablecoin is registered. The compound case that would make this a protocol-wide outage — sole
registered stablecoin, no replacement — is a conjunction of terms none of which is observed at
`c91bc1a`.

Two deflators were **struck** and must not be reintroduced: *"nothing is consumed"* argues the wrong
limb (C4's availability clause is written to cover exactly the case where nothing is consumed), and
*"one owner transaction restores service"* contradicts this finding's own evidence — one-transaction
recovery presupposes the owner **knows** service is down, which leg (b) asserts they would not.

What keeps this reportable at all — rather than absorbed — is that detection asymmetry, confirmed
against `PhusdStableMinter.sol:254`, and newly introduced by this delta. It was also what held the
finding at the top of Low before the 2026-08-20 downgrade; the downgrade turns on the **likelihood of
the T3 trigger**, not on the asymmetry, which is unaffected.

> **Band condition — CONDITIONAL ON A MUTABLE REGISTRY. Still live at the QA band.**
> This QA band, exactly like the Low it replaced, is conditional, not settled. It flips to Medium on a **single registration transaction**:
> registering one stablecoin whose `decimals()` does not answer a `STATICCALL` is sufficient, and
> nothing in the code prevents it or reports it. The band is a statement about the registry's current
> contents — which the protocol does not freeze — and not about the code, which behaves identically
> in every configuration.
>
> **Triage ask — ANSWERED 2026-08-20**: the human accepted a severity that depends on a mutable
> configuration, at the **QA** band, on the likelihood reasoning above, and kept the escalation
> trigger live. The registration-time check below still makes the band unconditional and is still the
> recommended fix.

**The band rests on one piece of evidence and nothing else.** story-002
(`~/code/product-owner/stories/antimatter/auto-complete/annihilate/002-cross-check-registered-decimals-against-token.md:258`)
attests that *"every stablecoin of interest exposes `decimals()`"*, framing `DecimalsUnavailable` as a
guard against a **future** registration rather than a live condition. Corroboration: staging registers
USDC (6dp), DOLA (18dp) and USDe (18dp), all with standard `view` getters — none is a T3 token.
Neither the attestation nor the corroboration constrains a **future** registration; both describe a
set that one transaction can change. If this evidence goes stale, the band moves.

**Escalate to Medium if**:
- **Primary trigger**: any stablecoin is registered on Antimatter's minter whose `decimals()` does not
  answer a `STATICCALL` with exactly 32 bytes. **Verify by calling `toStableAmount(S, 1e18)` at
  registration time** — the mint path cannot detect this, because `PhusdStableMinter.mint` reads only
  its own stored `config.decimals` at `minter:254` and never queries the token.
- Any future change moves the `toStableAmount` call **after** `_burn`, so a revert can strand
  consumed assets.

*(A previous trigger — "exactly one stablecoin is registered while antimatter is distributed as a
staking reward" — was struck: it tests the wrong condition (a sole **healthy** stablecoin is not this
finding at all, while one T3 token among five is this finding for every holder paired against it) and
is not checkable from any artifact in this repo. The replacement above tests the actual defect and is
verifiable with a single `eth_call`.)*

**Recommendation (primary)**: **cross-check once at registration/acceptance time on Antimatter's
side, and cache the result.** Verify the token's `decimals()` against the minter's registered value
when the stablecoin is accepted, store the verified value, and read the cached value on the
settlement path. This fixes T3 — a token that answers correctly once is never rejected later for
*how* it answers — **without introducing any fail-open branch**, and it converts a settlement-time
liveness dependency into a one-time registration-time check. It also makes the escalation trigger
above impossible to satisfy silently.

**If accepted as-is**: document that `decimals()` must be callable in a static context and add it to
the registration checklist; keep at least two independently-implemented stablecoins registered at all
times; widen the `DecimalsUnavailable` NatSpec (today "does not report usable decimals at all") to say
"**through a static call**"; and run a monitor that calls `toStableAmount(S, 1e18)` per registered
`S`, because the mint path cannot detect this failure.

> **A fail-open fallback is NOT the recommendation and must not ship as the headline mitigation.**
> The rejected line — *"treat an unavailable `decimals()` as no independent confirmation available
> and fall back to the minter's registered value, keeping the hard revert only for a `decimals()`
> that answers and disagrees"* — **re-opens exactly the fail-open path that ledger `M-01`
> (`a1c81428a47ad295`, fix-pending) exists to close**, for every token that can make its `decimals()`
> unavailable, which a lying token controls. story-002 chose fail-closed deliberately and named it
> "the security property". Reversing a story-sanctioned security property is an **owner decision**,
> to be raised as such — not a line item in a recommendations list.

**Relationship to `M-01`**: the cross-check this finding critiques **is** the fix for `M-01`, and
Tier-3 INV6 plus Halmos SYM-2 confirm it closes `M-01`'s exploit path in both directions. This
finding is the **cost** of that fix, not an argument to revert it — which is exactly why the
fail-open fallback was removed from the recommendation. Separately, `M-01`'s closure is
boundary-scoped (correct for Antimatter, silent for `PhusdStableMinter`'s own permissionless mint);
that warning is carried by `MR-02-P3` and `WATCH-02-03` and is not restated as a finding here.

> **Do not collapse with L-04 (`25088b59893f37e0`).** Same call site, same delta; different trigger
> class, different fix, and neither fix fixes the other. **Both are owed.**

---


---
---

# CARRYOVER — run-01 QA-band entries still open at `c91bc1a`

Everything below was **first filed in run-01** and remains `open` in
`reports/ledgers/antimatter.json` at this commit. Bodies are reproduced in full from each entry's
`findingPath` (every `reportPath` is `null`), with line references updated to `c91bc1a` where the
delta moved them. **Issue IDs and labels are the originating run's and are not restamped**: these are
`am1*`, not `am2*`, and they do not participate in run-02's numbering.

Note the API rename in this delta: run-01's `annihilateFrom(address stable, address from, address
recipient, uint256 amount)` is now `annihilate(address stable, address recipient, uint256 amount)`
at `:221`, burning `msg.sender`'s own balance. Fingerprint bases are **not** recomputed on the new
name — they reproduce from the recorded `fingerprintBasis` verbatim.

`F-01` (`am1f1`, `3aac91383dcb6060`, open) is **not reproduced here**: it is a Law-2 faithfulness
finding adjudicated in `submissions/spec-conformance.md`. It is cross-referenced by `Q-05` above,
whose false-closure block governs when it may be closed.

---

## Carryover — Low Risk

### [L-02] Once phUSD and the minter are both wired, the phUSD address can never be changed — the two setters mutually lock <!-- id: am1l2 -->

**Fingerprint**: `5c89b2d372ec9286` (`src/Antimatter.sol:setPhUSD, setPhUSDMinter:MutuallyLockingSetters`)
**Status**: `open` — unchanged at `c91bc1a`.

**Location**: [`src/Antimatter.sol#L142-L163`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L142-L163) *(run-01: `:124-:145`)*

**Description**: The two setters each validate against the other, and there is no ordering of calls
that escapes the pair:

- `setPhUSD` (`:145-147`) rejects any address the currently-configured minter does not mint.
- `setPhUSDMinter` (`:158-160`) rejects any minter that does not mint the currently-configured phUSD.
- `PhusdStableMinter.phUSD` is **immutable**, so the minter cannot be bent to a new phUSD.
- Neither setter accepts `address(0)`, so neither side can be unwired to break the deadlock.

The result is that `setPhUSD` — a function whose name advertises a re-pointable address — is
effectively one-way after first configuration. This is not documented anywhere.

**Impact**: no funds at risk. But a phUSD redeployment would force a full Antimatter redeployment, and
Antimatter is non-upgradeable with no migration path, so every outstanding antimatter balance would be
lost. This is a Law-3 footgun: an owner reading two independent setters would reasonably believe
either can be re-pointed, and would discover otherwise only at the moment a migration is actually
needed — the worst possible time to learn it.

Held at Low because phUSD is intended to be permanent, so the trigger may never arrive.

**PoC** (audit-authored): `workspace/antimatter/test/audit/Tier2.t.sol`
- `test_L_phUSDCanNeverBeMigratedOnceMinterWired` — both call orderings revert. **Passing.**

**Recommendation**: either document the one-way property directly on `setPhUSD`, or add an owner-only
atomic re-wire that preserves the no-drift invariant without welding the pair permanently:

```solidity
function rewire(IFlax newPhUSD, PhusdStableMinter newMinter) external onlyOwner {
    if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();
    if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();
    if (newMinter.phUSD() != address(newPhUSD)) {
        revert PhUSDMinterMismatch(newMinter.phUSD(), address(newPhUSD));
    }
    phUSD = newPhUSD;
    phUSDMinter = newMinter;
}
```

---

### [L-03] A near-zero `exchangeRate` turns a soft throttle into a hard brick, and the revert blames the wrong contract <!-- id: am1l3 -->

**Fingerprint**: `0ed1c6e3270816c5` (`src/Antimatter.sol:annihilateFrom:RoundToZeroStableLegBricksAnnihilation`)
**Status**: `open` — **the guard moved, the brick remains.**

**Location**: [`src/Antimatter.sol#L234-L235`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L234-L235) *(run-01: `:232-:233`)*

**What changed this run**: the zero-quote check now runs **pre-burn**, on the minter's quote rather
than on the post-mint balance delta:

```solidity
uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);  // :234
if (expectedForStable == 0) revert PhUSDNotReceived();                         // :235
...
_burn(msg.sender, amount);                                                     // :239
```

That is a real improvement: the call now **fails earlier and cheaper**, before `_burn` at `:239` and
before any external interaction, so nothing is consumed and no allowance is spent on a doomed call.

**What did not change**: **the brick itself remains.** When `floor(amount * exchangeRate / 1e18)`
truncates to zero, the stable leg quotes nothing and the guard reverts the **entire** annihilation —
including the antimatter leg, which was still perfectly valid. Two consequences, both unaltered:

1. `exchangeRate = 0`, a natural way for an owner to express *"stop paying the stable half"*, instead
   **hard-bricks** annihilation for that stablecoin entirely.
2. A near-zero rate bricks it only for *small* amounts, producing an amount-dependent revert that
   looks like a heisenbug from outside.

And the surfaced error is still `PhUSDNotReceived`, which reads as *"the minter failed to deliver"* —
pointing the operator at the wrong contract entirely, not at their own rate setting. The error is
named, but it is named **wrongly** for this cause.

`setStablecoinEnabled(false)` already exists as the honest per-stable kill switch, which is why
`rate = 0` reads as a misapprehension rather than an intended mechanism. This is the same
misapprehension documented in `M-04`.

**Impact**: liveness only; no value loss — now strictly so, since the revert precedes the burn.

**Evidence** (symbolic, not a PoC): `reports/antimatter-01/tier3/halmos-p4-nonzero.txt` — property
REFUTED with a concrete witness, `amount = 524288000000000000`, `rate = 1 wei`. Recorded as reachable
only symbolically; a fuzzer over sensible rates would not reach it.

**Recommendation**: bound `exchangeRate` away from zero at registration/update time, and separate the
diagnostics so an operator is told which contract is actually at fault:

```solidity
if (expectedForStable == 0) revert StableLegRoundedToZero(stable, stableAmount);
```

Failing that, document `PhUSDNotReceived` as also covering *"the configured `exchangeRate` rounds this
amount's stable leg to zero"*.

---

## Carryover — Centralization Risks

### [C-01] `FlaxToken.revokeAllMintPrivileges` silently voids every outstanding antimatter claim, and Antimatter exposes no view of its own authorisation status <!-- id: am1c1 -->

**Fingerprint**: `2a844d32db2eb0f9` (`src/Antimatter.sol:annihilateFrom:UpstreamMintPrivilegeRevocationUnobservable`)
**Status**: `open` — unchanged, and **sharpened** by this delta.

**Location**: [`src/Antimatter.sol#L260`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L260) *(run-01: `:236`)*

**Description**: Antimatter's entire value rests on a mint authorisation held by a **third,
independent principal** — FlaxToken's owner — which is revocable wholesale via the documented global
kill switch `revokeAllMintPrivileges` (`mintVersion++`).

What makes this a reportable footgun rather than a trusted-owner non-issue (Law 3) is that the
condition is **unobservable**:

1. There is no per-minter event on revocation.
2. There is no view on **either** contract reporting whether Antimatter is currently an authorised,
   current-version minter.
3. Recovery requires `setMinter` on **both** contracts. Re-authorising only `PhusdStableMinter` — the
   obvious one, since ordinary minting visibly resumes — leaves annihilation silently dead.
4. Off-chain UIs still see a configured, registered, non-paused system throughout, because
   `toStableAmount` continues to return successfully.

A competent, non-malicious FlaxToken owner reaching for the documented global kill switch would be
surprised to learn it also voids every antimatter claim, and would have no signal telling them so.

**Sharpened by this delta**: more failure modes now execute **before** the burn, which leaves the
`IFlax` mint at `:260` as the **last remaining post-burn assumption on the whole path**. That makes
this entry's *"Antimatter exposes no view of its own authorisation status"* the sole unguarded
post-burn dependency. A sharpening of this finding, not a new one; status unchanged.

**Impact**: every outstanding antimatter token becomes permanently inert. Antimatter is a reward token
with no purchase price, so no user capital is destroyed — but the entire outstanding claim is.

**Likelihood**: low; a deliberate, emergency-scoped action. The finding is about the *silence* of the
aftermath, not the frequency of the trigger.

**Recommendation**:
1. Expose a view on Antimatter reporting whether it is currently an authorised, current-version phUSD
   minter, so the condition is observable without simulating an annihilation.
2. Record the two-contract re-authorisation requirement in the incident runbook, explicitly naming
   Antimatter as the easy one to forget.

---

### [C-02] Antimatter has no kill switch of its own — every lever that can halt annihilation belongs to a different principal <!-- id: am1c2 -->

**Fingerprint**: `3a90280bed325637` (`src/Antimatter.sol:annihilateFrom:NoLocalPauseAuthority`)
**Ledger severity**: `qa` (kept in this section for topical grouping; it carries QA weight, not Low weight)
**Status**: `open` — unchanged at `c91bc1a`.

**Location**: [`src/Antimatter.sol#L221`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L221) *(run-01: `:201`)*

**Description**: Antimatter is not `Pausable` and exposes no owner lever to halt annihilation.
Stopping it requires one of:

- `PhusdStableMinter`'s pauser or owner,
- `FlaxToken`'s owner, or
- the yield strategy's owner

— all principals independent of `Antimatter.owner()`, with nothing requiring them to be the same
party. The only *fast* lever, `FlaxToken.revokeAllMintPrivileges`, is global and causes collateral
damage: it silently de-authorises `PhusdStableMinter` too (see `C-01`).

This is an operational observation, **not** a malicious-owner finding: no owner needs to misbehave for
the incident-response path to be missing.

**Impact**: no direct asset impact — incident-response capability only. If a defect is found in
Antimatter itself, its own owner cannot stop it. The open High `H-01` demonstrates that *"a defect
exists in Antimatter"* is not a hypothetical premise.

**Why only QA**: the composition is arguably deliberate — Antimatter keeps no stablecoin list of its
own and defers control to the minter by design. The gap is in the runbook as much as in the code.

**Multiplied by `C-03`** (new this run): the single owner key that would hold any such lever also has
no two-step transfer.

**Recommendation**: either document the incident-response runbook (who to call, in what order), or add
an owner-settable `annihilationPaused` flag checked at the top of `annihilate`, so the contract's own
owner holds a proportionate, non-global lever.

---

## Carryover — QA / Non-Critical

### [Q-01] `toStableAmount` is a decimals-only rescale and is not a phUSD preview; the local `decimals` also shadows `ERC20.decimals()` <!-- id: am1q1 -->

**Fingerprint**: `8c2dcc57bcd3be05` (`src/Antimatter.sol:toStableAmount:MisleadingHelperNamingAndShadowing`)
**Status**: `open` — both halves survive verbatim, and the delta **aggravates** the framing.

**Location**: [`src/Antimatter.sol#L280-L301`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L280-L301) *(run-01: `:246-:257`)*

**(a) Missing preview.** `toStableAmount` is the only public preview on the annihilation path, and it
ignores `exchangeRate` entirely — it is a pure decimals rescale. The phUSD actually delivered is
`amount + floor(amount * exchangeRate / 1e18)`. At any rate other than `1e18`, an integrator deriving
an expected payout from this function is wrong on the stable leg.

The asymmetry itself is by design and internally coherent (stable leg priced at rate, antimatter leg
always at 1). The QA item is the **absence** of a matching phUSD-side preview, which leaves
`toStableAmount` looking like one.

**(b) Shadowing.** The local `decimals`, destructured from `minter.stablecoinConfigs(stable)` at
`:284`, shadows the inherited `ERC20.decimals()` / `IERC20Metadata.decimals()`.

**Aggravated this run — on both halves:**

- **(a)** New NatSpec at `:278-279` **positively endorses** reading `toStableAmount` as a quote
  helper: *"Off-chain callers using this as a quote helper therefore depend on `stable` being
  responsive."* That is the exact misreading this entry warns about, now blessed in-source. In-source
  NatSpec carries **no suppression authority** on this project and, where falsely exhaustive, raises
  rather than lowers severity.
- **(b)** The shadowed local now propagates into an ABI-visible signature:
  `DecimalsMismatch(address,uint8,uint256)` at `:295` surfaces the shadowing name in the error
  interface, where an integrator decoding the revert meets it directly.

Recorded on this entry rather than filed fresh. No escalation above QA is proposed; status unchanged.

**Recommendation**:
- Add a real preview and document `toStableAmount` as the input-side rescale only:
  ```solidity
  function previewAnnihilate(address stable, uint256 amount)
      external view returns (uint256 stableAmount, uint256 phUSDOut);
  ```
  composing `minter.calculateMintAmount`. Then correct the `:278-279` NatSpec to point at it.
- Rename the local to `stableDecimals`.

*Note*: the economic consequence of an unbounded, un-timelocked `exchangeRate` is `DEDUP-005` and is
deliberately not re-adjudicated here.

---

### [Q-02] `recipient` is guarded against `address(0)` but not against `address(this)` — an annihilation can come to rest on the contract <!-- id: am1q2 -->

**Fingerprint**: `c330566040a453ea` (`src/Antimatter.sol:annihilateFrom:RecipientSelfAddressUnguarded`)
**Status**: `open` — unchanged at `c91bc1a`; line references moved.

**Location**: [`src/Antimatter.sol#L223`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L223) *(run-01: `:203`)*

**Description**: `:223` rejects `recipient == address(0)` but accepts `address(this)`. `:260` then
mints `amount` phUSD to Antimatter and `:261` transfers `mintedForStable` from Antimatter to itself,
so the full ~2x payout settles on the contract with the antimatter **already burned** at `:239`.

**Impact**: self-inflicted caller error with no attacker gain. Mitigating facts: the phUSD is
recoverable by the owner via `rescueERC20` (`:306`), and a later annihilation's `phUSDBefore` snapshot
at `:244` correctly excludes it, so it is not swept to the next annihilator (control-tested under
`L-01`). No partial settlement state is created.

**PoC** (audit-authored): `workspace/antimatter/test/audit/Tier2b.t.sol`
- `test_recipientSelfStrandsPhUSD` — 200e18 phUSD settles on the Antimatter contract, antimatter
  already burned. **Passing.**

**Recommendation**: `address(this)` is exactly as cheap to reject as `address(0)`.

```solidity
if (recipient == address(0)) revert RecipientZeroAddress();
if (recipient == address(this)) revert RecipientSelfAddress();
```

---

### [Q-03] `approvedMinters()` copies the whole `EnumerableSet` to memory with no bound <!-- id: am1q3 -->

**Fingerprint**: `0174ea0bd59a9b12` (`src/Antimatter.sol:approvedMinters:UnboundedSetCopyInView`)
**Status**: `open` — unchanged at `c91bc1a`.

**Location**: [`src/Antimatter.sol#L192`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L192) *(run-01: `:174`)*

**Description**: `EnumerableSet.values()` is unbounded. This is an external view, so no on-chain caller
is forced through it today, but it will gas-out for an off-chain reader once the set grows large, and
any future on-chain consumer inherits the unbounded loop.

**Recommendation**: paginate, or keep `approvedMinterAt` / `approvedMinterCount` (`:187`, `:182`) as
the supported iteration path and document `values()` as off-chain-only.

> **Triage note — likely triage-death.** The approved-minter set is expected to hold a handful of
> entries, so the growth premise may simply never hold. Recorded rather than deleted so the dismissal
> is a visible decision.

---

### [Q-04] Static-analysis findings in audit-harness and mock files (`test/**`) <!-- id: am1q4 -->

**Fingerprint**: `507e375d3ef4abfe` (`test/**:multiple:ToolNoiseInTestHarness`)
**Status**: `open` — unchanged. Instance count grew from 3 clusters to 12; this is **test growth**
from story-002's `vm.expectRevert` negative tests, **not** a regression and **not** a widening defect.
No escalation.

**Location**: `test/**` — test and mock files only. **No production contract is implicated.**

**Description**: Slither and Aderyn raised the following in test-harness and mock files. They are
recorded for completeness and are **explicitly not being presented as protocol issues**:

| ID | File | Detail |
|----|------|--------|
| SA-011 | `test/Antimatter.t.sol` (`test_transfer`) | Return value of `antimatter.transfer(stranger, 4e18)` ignored. Slither `unchecked-transfer` + Aderyn `unsafe-erc20-operation` / `unchecked-return` at the same line. |
| SA-012 | `test/Annihilation.t.sol` | `approve()` / ERC20 return values ignored across `_fund` and several negative tests. Corroborated by Aderyn at identical lines. |
| SA-013 | `test/mocks/ReentrantStable.sol` (`:16-17`) | Address state variables assigned in constructor/setter without zero-check. |

Run-02's full-coverage passes add the same class in bulk: 74 first-party Slither results in
`test/Annihilation.t.sol`, 39 in `test/Antimatter.t.sol`, and 226 Aderyn instances in
`test/Annihilation.t.sol`. All test-harness and mock code.

**Impact**: none. These are audit-harness and mock files.

**Recommendation**: none required. If desired, use `SafeERC20` in test helpers for consistency.

> **Triage note — likely triage-death, and deliberately not inflated.** This entry exists so the
> automated tools' output is accounted for rather than silently discarded. It should not be read as
> hundreds of findings' worth of signal; it is a handful of clusters of tool noise in non-production
> code, counted against more files than run-01 could see.

---

### [L-01] `mintedForStable` is a balance delta, not an attribution: the unattributed window `[:244, :256]` is now enforced by exact equality, so phUSD arriving mid-call reverts the whole annihilation instead of being mis-forwarded <!-- id: am1l1 -->

**Fingerprint**: `ad4b779566291190` (`src/Antimatter.sol:annihilateFrom:BalanceDeltaMistakenForAttribution`)
**Status**: `open` — **RE-WORDED in run-02, DOWNGRADED to the QA band on 2026-08-20, NOT closed.**

> **BAND: QA — downgraded from Low on 2026-08-20 (human-authorised, recorded not re-litigated).**
> **Status is unchanged: `open`. Label is unchanged: `L-01` — not renumbered. The DO-NOT-CLOSE
> marker below REMAINS BINDING: this is a downgrade, not a closure.**
>
> **Reason: there is NO PERMISSIONLESS VECTOR, and run-02's "griefing brick" wording overstated the
> finding by implying an arbitrary attacker.** The corrected framing is stated under *Impact* and
> *Reachability* below; the run-02 wording is retained as history rather than deleted.

**Location**: [`src/Antimatter.sol#L244-L257`](https://github.com/Behodler/antimatter/blob/c91bc1a44424b853247a3849732bf89547defdec/src/Antimatter.sol#L244-L257) *(run-01: `:220-:237`)*

**Root cause — UNCHANGED, byte for byte.** The stable leg is still measured as a balance delta across
the mint call, and that delta is still attributed to the caller-chosen recipient regardless of who
actually sent the phUSD:

```solidity
uint256 phUSDBefore = _phUSD.balanceOf(address(this));                     // :244
...
minter.mint(stable, stableAmount);                                         // :251
...
uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;   // :256
if (mintedForStable != expectedForStable)
    revert PhUSDAmountMismatch(expectedForStable, mintedForStable);        // :257
```

Every wei of phUSD that lands on Antimatter inside the `[:244, :256]` window is still counted as this
annihilation's stable leg. The defect is exactly where it was.

**Impact — INVERTED.**

- **Was (run-01)**: **value leak**. Mid-call phUSD was silently **forwarded** to the caller-chosen
  recipient. Run-01 PoC: 500e18 injected from the stablecoin's transfer hook; the annihilator walked
  away with 700e18 instead of 200e18.
- **Now (`c91bc1a`)**: an **availability brick reachable only by an owner-configured actor**. The new
  exact-equality post-condition at `:257` makes the same injection **revert the entire annihilation**.
  The mechanism is demonstrable: the invariant harness reproduced
  `PhUSDAmountMismatch(100e18, 100e18+1)` on a **1-wei** injection
  (`workspace/antimatter/test/audit/Tier2Delta.t.sol::test_midCallPhUSDInjectionNowReverts`).
  *(Run-02 called this a "griefing brick". That wording is superseded — see* **Reachability** *below —
  and is retained here only as history.)*

**Reachability — CORRECTED 2026-08-20. NO PERMISSIONLESS VECTOR.**

Control *genuinely does* leave the contract inside the `[:244, :256]` window. That window contains
three external calls — `safeTransferFrom` (`:246`), `forceApprove` (`:247`) and `minter.mint`
(`:251`, which itself reaches the yield strategy) — so **no hook on Antimatter and no re-entry is
required**. `nonReentrant` guards **re-entry into `annihilate`**; it does **not** stop a callee making
an **outbound** `phUSD.transfer(antimatter, 1)` while it holds control.

**But exactly three actors get execution in that window — the `stable` token, the minter, and the
yield strategy — and all three are owner-configured.** An unprivileged attacker gets **no execution at
all**: a donation *before* the call is baselined out by the `:244` snapshot, and a donation *after*
`:256` is irrelevant. **No front-run or sandwich reaches inside the interval.**

**Consequence**: this is a **Law-3 footgun conditional on a hostile or buggy registered token** (or a
hostile/buggy minter or yield strategy), not a griefing vector open to the public. And a token with
that power can brick its own pair **far more cheaply** by simply reverting `transferFrom` — the same
**marginal-capability deflator** already applied to `L-04`. That is why the band is **QA**, not Low.
It remains **one finding whose impact inverted**, not a fix plus a new finding.

**Sub-defect (survives the downgrade)**: when Antimatter's phUSD balance *decreases* within the
window — a mid-call phUSD **departure** — the delta subtraction at `:256` underflows into a bare
`Panic(0x11)` rather than a named error. **Same reachability caveat**: owner-configured actors only.

**Law-3 verdict**: footgun, **in scope, at the QA band**. A competent owner registering a hook-bearing
token would not connect *"this token moves phUSD on transfer"* with *"annihilation is bricked for this
pair"* — that surprise is what keeps it reportable. What it is **not** is an attacker-controlled
griefing lever: the `nonReentrant` guard settles **re-entry**, and the `:244` snapshot settles
**third-party donation**; the residual is an **outbound transfer by one of the three owner-configured
callees** while it holds control.

> **DO NOT CLOSE (binding).** Do not mark this fixed on the strength of the `:257` check. The check
> changes the **symptom**, not the root cause, and the new symptom is an availability defect rather
> than a value leak. Closing it would lose the surviving root cause.

**Related**: `Q-05` (`1b960956475d434a`) records that this same check is genuinely load-bearing here —
which is precisely why `Q-05` does **not** call it a tautology.

**PoC** (audit-authored — see provenance note): `workspace/antimatter/test/audit/Tier2b.t.sol` (run-01)
and `workspace/antimatter/test/audit/Tier2Delta.t.sol` (run-02)
- `test_midCallPhUSDInjectionIsForwardedToRecipient` — the run-01 value-leak behaviour. **Passing at `0bb82d8`.**
- `test_preExistingPhUSDDonationIsNotSwept` — control: a pre-call donation *is* correctly excluded by
  the snapshot and remains stuck (owner-recoverable via `rescueERC20`). **Passing.**
- `test_midCallPhUSDInjectionNowReverts` — the run-02 availability brick (harness-injected; see
  **Reachability** — the injector stands in for an owner-configured callee, not an arbitrary attacker).
  **Passing at `c91bc1a`.**

**Root cause — STILL OPEN, unchanged by the downgrade.** `mintedForStable` at `:256` is an
**unattributed balance delta**, not *"what the minter minted for this call"*. Nothing about the band
change touches it.

**Recommendation (surviving substance).** The narrowest improvement is to relax the post-condition:
**`mintedForStable < expectedForStable` is strictly better than `!=`** — it still catches a **short
mint**, without turning an **over-arrival** into a brick. Beyond that, attribute rather than measure. Credit the recipient with the minter's own quoted
amount and use the balance delta only as an assertion that nothing unexpected happened — and give the
underflow a named error so the failure is diagnosable:

```solidity
uint256 balanceNow = _phUSD.balanceOf(address(this));
if (balanceNow < phUSDBefore) revert PhUSDBalanceDecreased(phUSDBefore, balanceNow);
uint256 delta = balanceNow - phUSDBefore;
if (delta != expectedForStable) revert PhUSDAmountMismatch(expectedForStable, delta);
// pay out expectedForStable, not the measured delta
```

Note this does **not** by itself resolve the availability brick: as long as any unexpected inbound
aborts settlement, one of the three owner-configured callees can still stop the pair (per
**Reachability** above, no unprivileged party can). Sweeping any excess to the owner — recoverable via
`rescueERC20` — rather than reverting is the direction that removes the lever entirely.

---
---

## Appendix A — Automated report (4naly3er)

Generated with 4naly3er, the C4-standard automated QA/gas report generator, over all **6** in-scope
first-party files at commit `c91bc1a44424b853247a3849732bf89547defdec`. The full generated report is
attached standalone as **`reports/antimatter-02/submissions/4naly3er-report.md`** (3,061 lines; the
source artifact is `reports/antimatter-02/tier1/4naly3er-report.md`). Its Low and Medium sections —
the QA-relevant ones — are reproduced verbatim below; the Gas and Non-Critical sections are in the
standalone file.

### These findings are new to the REPORT, not new to the CODE

**4naly3er was silently broken before this run and produced nothing in run-01.** Its bundled compiler
list topped out at **solc 0.8.26** while the project's pragma is **`^0.8.27`**, so
`semver.satisfies(version, pragma)` matched **no** version, `filteredSources` was empty for every
candidate, **no compile promise was ever created**, and `compileAndBuildAST` returned an array of
`undefined` ASTs. The tool then crashed in the first detector to dereference one
(`TypeError: Cannot read properties of undefined (reading 'nodeType')`, raised from
`src/issues/NC/uselessOverride.ts`) — a crash that names an AST-walking style detector and reads like
a parser incompatibility, which it is not. No "cannot compile AST" message is printed on that path,
so the real cause was silent.

**Repair**: `yarn add -E "solc-0.8.27@npm:solc@0.8.27"` in `tools/4naly3er`. Strictly additive, left
in place (any future `^0.8.27` project needs it); `tools/4naly3er` is its own git repo, so
`git checkout package.json yarn.lock` reverts it. Running each of the 6 files alone crashed
identically before the repair, proving the failure was tool-level rather than file-specific.

**The consequence for reading this appendix**: everything below was **already true at `0bb82d8`**
unless its line numbers say otherwise. **Nothing here is a regression, and nothing here should be
attributed to `c91bc1a`.** `C-03` above is the one item promoted out of this appendix into a finding,
and it carries that provenance statement explicitly.

### Run provenance and remappings

- **Base path.** antimatter has **no `remappings.txt`** — its remappings live in `foundry.toml` by
  design, so a parent project can override them. 4naly3er reads `remappings.txt` relative to its
  `BASE_PATH` and cannot read `foundry.toml`, and `lib/antimatter` is strictly read-only. `BASE_PATH`
  was therefore the **writable workspace clone** (`workspace/antimatter/`, gitignored), verified
  byte-identical to `lib/antimatter` on all 6 in-scope files by `diff` before scanning.
- **Argument semantics.** `yarn analyze <BASE_PATH> <SCOPE_FILE> <GITHUB_URL>` — argument 2 is a
  **scope list**, not a remappings file. No symlink workaround was used.
- **A second failure, also fixed.** `PhusdStableMinter.sol` is pulled in via
  `@phUSDMinter/=lib/phUSD-stable-minter/src/`, so its relative import
  `../lib/vault/src/interfaces/IYieldStrategy.sol` resolved to `lib/vault/...` rather than
  `lib/phUSD-stable-minter/lib/vault/...`, and 4naly3er's naive `findImports` cannot recover the real
  path. Fixed with an augmented `remappings.txt` at `BASE_PATH`: the full 15-entry `forge remappings`
  output plus 4 shim entries for the nested-dep prefixes. The exact file used is saved as
  `tier1/4naly3er-remappings-used.txt`. The workspace `remappings.txt` (untracked/generated) was
  restored afterwards; `lib/antimatter` was never touched. Slither, Aderyn and Semgrep had all
  completed before that file was touched, so none of their results are affected.

### Results at a glance

| Class | Issues | Instances |
|-------|-------:|----------:|
| Gas Optimizations | 12 | 288 |
| Non-Critical | 23 | 455 |
| Low | 15 | 133 |
| Medium (tool-labelled) | 2 | 8 |

Compare run-01's attempt (3 GAS / 7 NC / 4 L / 1 M over `src/Antimatter.sol` only) — the growth is
**scope and repair**, not code decay.

**How the tool's output maps to this report:**

- **tool-`L-2` / `L-12` (Ownable2Step)** — the **only** item promoted, as `C-03`, and capped at QA
  because it is a common automated-tool finding with no demonstrated H/M path. Corroborated by
  Semgrep's single retained result (`use-ownable2step`).
- **tool-`L-5` (`decimals()` is not part of ERC-20)** — the tool reaches it generically, and on a
  test file. The reasoned form of this concern is `L-05` above, which declines the weird-ERC-20
  carve-out on the grounds that `decimals()` being **optional** makes a token without it
  standard-conformant, not weird — and that T3's token implements it correctly anyway.
- **tool-`L-9` (external call recipient may consume all transaction gas)** — fires only on a test
  file, but it is the generic shape of `L-04`. `L-04` is filed on the measured production call site at
  `:292`, not on this instance.
- **tool-`L-7` (division by zero not prevented)** — touches the same `toStableAmount` scale arithmetic
  discussed in `Q-01` and `L-03`; reached generically rather than by the reasoning recorded there.
- **tool-`M-1` (fee-on-transfer)** — **not promoted, and deliberately not in the ledger.** The
  fee-on-transfer finding (`374e69850c5fc60a`) was adjudicated **INVALID**: the settlement path fails
  closed on two independent legs. This is the tool reaching the pattern generically without the
  path-specific reasoning that refutes it.
- **tool-`M-2` (centralization risk for trusted owners, 6 instances)** — the generic `onlyOwner` sweep
  every 4naly3er run produces. Under Law 3 this is **not** a finding on its own; the centralization
  concerns actually worth reporting are adjudicated above as `C-01`, `C-02` and `C-03`.

None of the tool's Low/NC/Gas output was promoted into the manual findings above other than as noted.
It is attached as a **baseline**, not as evidence.

### 4naly3er raw output — Low and Medium sections (verbatim)

#### Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 3 |
| [L-2](#L-2) | Use a 2-step ownership transfer pattern | 1 |
| [L-3](#L-3) | Some tokens may revert when zero value transfers are made | 4 |
| [L-4](#L-4) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-5](#L-5) | `decimals()` is not a part of the ERC-20 standard | 1 |
| [L-6](#L-6) | Deprecated approve() function | 3 |
| [L-7](#L-7) | Division by zero not prevented | 1 |
| [L-8](#L-8) | Empty Function Body - Consider commenting why | 1 |
| [L-9](#L-9) | External call recipient may consume all transaction gas | 1 |
| [L-10](#L-10) | Prevent accidentally burning tokens | 96 |
| [L-11](#L-11) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 6 |
| [L-12](#L-12) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 3 |
| [L-13](#L-13) | Sweeping may break accounting if tokens with multiple addresses are used | 7 |
| [L-14](#L-14) | `symbol()` is not a part of the ERC-20 standard | 1 |
| [L-15](#L-15) | Unsafe ERC20 operation(s) | 4 |
##### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (3)*:
```solidity
File: test/Annihilation.t.sol

62:         stable.approve(address(antimatter), type(uint256).max);

136:         antimatter.approve(spender, type(uint256).max);

354:         evil.approve(address(antimatter), type(uint256).max);

```

##### <a name="L-2"></a>[L-2] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

22: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

```

##### <a name="L-3"></a>[L-3] Some tokens may revert when zero value transfers are made
Example: https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (4)*:
```solidity
File: src/Antimatter.sol

246:         IERC20(stable).safeTransferFrom(msg.sender, address(this), stableAmount);

261:         IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);

308:         token.safeTransfer(to, amount);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

15:         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

```

##### <a name="L-4"></a>[L-4] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:
```solidity
File: test/mocks/ReentrantStable.sol

17:         attacker = attacker_;

```

##### <a name="L-5"></a>[L-5] `decimals()` is not a part of the ERC-20 standard
The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (1)*:
```solidity
File: test/Antimatter.t.sol

21:         assertEq(antimatter.decimals(), 18);

```

##### <a name="L-6"></a>[L-6] Deprecated approve() function
Due to the inheritance of ERC20's approve function, there's a vulnerability to the ERC20 approve and double spend front running attack. Briefly, an authorized spender could spend both allowances by front running an allowance-changing transaction. Consider implementing OpenZeppelin's `.safeApprove()` function to help mitigate this.

*Instances (3)*:
```solidity
File: test/Annihilation.t.sol

62:         stable.approve(address(antimatter), type(uint256).max);

136:         antimatter.approve(spender, type(uint256).max);

354:         evil.approve(address(antimatter), type(uint256).max);

```

##### <a name="L-7"></a>[L-7] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

298:         uint256 stableAmount = amount / scale;

```

##### <a name="L-8"></a>[L-8] Empty Function Body - Consider commenting why

*Instances (1)*:
```solidity
File: test/mocks/MockYieldStrategy.sol

19:     function setClient(address, bool) external {}

```

##### <a name="L-9"></a>[L-9] External call recipient may consume all transaction gas
There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (1)*:
```solidity
File: test/Annihilation.t.sol

421:             (bool ok,) = address(antimatter).call(abi.encodeWithSignature(signatures[i], user, 1 ether));

```

##### <a name="L-10"></a>[L-10] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (96)*:
```solidity
File: src/Antimatter.sol

145:         if (address(minter) != address(0) && minter.phUSD() != address(newPhUSD)) {

146:             revert PhUSDMinterMismatch(minter.phUSD(), address(newPhUSD));

171:         bool changed = approved ? _approvedMinters.add(minter) : _approvedMinters.remove(minter);

172:         if (changed) emit ApprovedMinterSet(minter, approved);

178:         return _approvedMinters.contains(minter);

198:         _mint(to, amount);

228:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

234:         uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);

239:         _burn(msg.sender, amount);

247:         IERC20(stable).forceApprove(address(minter), stableAmount);

247:         IERC20(stable).forceApprove(address(minter), stableAmount);

251:         minter.mint(stable, stableAmount);

253:         IERC20(stable).forceApprove(address(minter), 0);

253:         IERC20(stable).forceApprove(address(minter), 0);

257:         if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(expectedForStable, mintedForStable);

261:         IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);

263:         emit Annihilated(stable, msg.sender, recipient, amount, stableAmount, amount + mintedForStable);

282:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

284:         (address yieldStrategy,, uint8 decimals,,,,) = minter.stablecoinConfigs(stable);

```

```solidity
File: test/Annihilation.t.sol

40:         phUSD.setMinter(address(minter), true);

40:         phUSD.setMinter(address(minter), true);

44:         minter.registerStablecoin(address(usdc), address(strategy), 1e18, 6);

45:         minter.approveYS(address(usdc), address(strategy));

46:         minter.registerStablecoin(address(dola), address(strategy), 1e18, 18);

47:         minter.approveYS(address(dola), address(strategy));

51:         antimatter.setPhUSDMinter(minter);

77:         assertEq(strategy.principal(address(usdc), address(minter)), 100e6, "deposited to vault");

77:         assertEq(strategy.principal(address(usdc), address(minter)), 100e6, "deposited to vault");

77:         assertEq(strategy.principal(address(usdc), address(minter)), 100e6, "deposited to vault");

91:         assertEq(strategy.principal(address(dola), address(minter)), 100 ether);

91:         assertEq(strategy.principal(address(dola), address(minter)), 100 ether);

91:         assertEq(strategy.principal(address(dola), address(minter)), 100 ether);

109:         minter.updateExchangeRate(address(usdc), 95e16); // 0.95 phUSD per USDC

263:         minter.setPauser(address(this));

264:         minter.pause();

300:         vm.mockCall(

301:             address(minter),

320:         vm.mockCall(

321:             address(minter),

333:         minter.updateExchangeRate(address(usdc), 0);

347:         minter.registerStablecoin(address(evil), address(strategy), 1e18, 18);

348:         minter.approveYS(address(evil), address(strategy));

367:         antimatter.setPhUSDMinter(minter);

390:         emit Antimatter.PhUSDMinterSet(address(minter), address(minter));

390:         emit Antimatter.PhUSDMinterSet(address(minter), address(minter));

392:         antimatter.setPhUSDMinter(minter);

468:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 6);

469:         minter.approveYS(address(liar), address(strategy));

480:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 18);

481:         minter.approveYS(address(liar), address(strategy));

534:         minter.registerStablecoin(ghost, address(strategy), 1e18, 6);

551:         minter.registerStablecoin(address(fat), address(strategy), 1e18, 24);

552:         minter.approveYS(address(fat), address(strategy));

563:         minter.registerStablecoin(address(liar), address(strategy), 1e18, 6);

564:         minter.approveYS(address(liar), address(strategy));

576:         assertEq(strategy.principal(address(liar), address(minter)), 0, "nothing deposited");

576:         assertEq(strategy.principal(address(liar), address(minter)), 0, "nothing deposited");

576:         assertEq(strategy.principal(address(liar), address(minter)), 0, "nothing deposited");

```

```solidity
File: test/Antimatter.t.sol

84:         assertFalse(antimatter.isApprovedMinter(minter));

84:         assertFalse(antimatter.isApprovedMinter(minter));

89:         emit Antimatter.ApprovedMinterSet(minter, true);

91:         antimatter.setApprovedMinter(minter, true);

93:         assertTrue(antimatter.isApprovedMinter(minter));

93:         assertTrue(antimatter.isApprovedMinter(minter));

95:         assertEq(antimatter.approvedMinterAt(0), minter);

98:         assertEq(all[0], minter);

103:         antimatter.setApprovedMinter(minter, true);

104:         antimatter.setApprovedMinter(minter2, true);

108:         emit Antimatter.ApprovedMinterSet(minter, false);

109:         antimatter.setApprovedMinter(minter, false);

112:         assertFalse(antimatter.isApprovedMinter(minter));

112:         assertFalse(antimatter.isApprovedMinter(minter));

113:         assertTrue(antimatter.isApprovedMinter(minter2));

113:         assertTrue(antimatter.isApprovedMinter(minter2));

115:         assertEq(antimatter.approvedMinterAt(0), minter2);

120:         antimatter.setApprovedMinter(minter, true);

121:         antimatter.setApprovedMinter(minter, true);

128:         antimatter.setApprovedMinter(minter, true);

129:         antimatter.setApprovedMinter(minter, false);

130:         antimatter.setApprovedMinter(minter, true);

133:         assertTrue(antimatter.isApprovedMinter(minter));

133:         assertTrue(antimatter.isApprovedMinter(minter));

136:         vm.prank(minter);

143:         antimatter.setApprovedMinter(minter, false);

150:         antimatter.setApprovedMinter(minter, true);

155:         antimatter.setApprovedMinter(minter, true);

159:         antimatter.setApprovedMinter(minter, false);

172:         antimatter.setApprovedMinter(minter, true);

174:         vm.prank(minter);

194:         antimatter.setApprovedMinter(minter, true);

195:         antimatter.setApprovedMinter(minter, false);

198:         vm.prank(minter);

199:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, minter));

199:         vm.expectRevert(abi.encodeWithSelector(Antimatter.NotApprovedMinter.selector, minter));

```

```solidity
File: test/mocks/MockStable.sol

19:         _mint(to, amount);

```

```solidity
File: test/mocks/ReentrantStable.sol

22:         _mint(to, amount);

```

##### <a name="L-11"></a>[L-11] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (6)*:
```solidity
File: src/Antimatter.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/Annihilation.t.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/Antimatter.t.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/mocks/MockStable.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/mocks/MockYieldStrategy.sol

2: pragma solidity ^0.8.27;

```

```solidity
File: test/mocks/ReentrantStable.sol

2: pragma solidity ^0.8.27;

```

##### <a name="L-12"></a>[L-12] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
Use [Ownable2Step.transferOwnership](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol) which is safer. Use it as it is more secure due to 2-stage ownership transfer.

**Recommended Mitigation Steps**

Use <a href="https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol">Ownable2Step.sol</a>
  
  ```solidity
      function acceptOwnership() external {
          address sender = _msgSender();
          require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
          _transferOwnership(sender);
      }
```

*Instances (3)*:
```solidity
File: src/Antimatter.sol

8: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: test/Annihilation.t.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

```solidity
File: test/Antimatter.t.sol

6: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

##### <a name="L-13"></a>[L-13] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (7)*:
```solidity
File: src/Antimatter.sol

306:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

```solidity
File: test/Annihilation.t.sol

431:     function test_rescueERC20OnlyOwner() public {

434:         antimatter.rescueERC20(IERC20(address(usdc)), recipient, 1e6);

437:     function test_rescueERC20ReturnsTrappedTokens() public {

441:         antimatter.rescueERC20(IERC20(address(usdc)), recipient, 42e6);

447:     function test_rescueERC20RejectsZeroRecipient() public {

450:         antimatter.rescueERC20(IERC20(address(usdc)), address(0), 1);

```

##### <a name="L-14"></a>[L-14] `symbol()` is not a part of the ERC-20 standard
The `symbol()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (1)*:
```solidity
File: test/Antimatter.t.sol

20:         assertEq(antimatter.symbol(), "AM");

```

##### <a name="L-15"></a>[L-15] Unsafe ERC20 operation(s)

*Instances (4)*:
```solidity
File: test/Annihilation.t.sol

62:         stable.approve(address(antimatter), type(uint256).max);

136:         antimatter.approve(spender, type(uint256).max);

354:         evil.approve(address(antimatter), type(uint256).max);

```

```solidity
File: test/Antimatter.t.sol

46:         antimatter.transfer(stranger, 4 ether);

```


#### Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 2 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 6 |
##### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues
Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (2)*:
```solidity
File: src/Antimatter.sol

246:         IERC20(stable).safeTransferFrom(msg.sender, address(this), stableAmount);

```

```solidity
File: test/mocks/MockYieldStrategy.sol

15:         IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

```

##### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (6)*:
```solidity
File: src/Antimatter.sol

22: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

137:     constructor(address initialOwner) ERC20("Antimatter", "AM") Ownable(initialOwner) {}

142:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

154:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

169:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

306:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```
