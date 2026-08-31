# QA Report — antimatter (run-01)

**Project**: antimatter (`lib/antimatter`)
**Commit audited**: `0bb82d867dba43bc514a508800826f90436c2ee3`
**Branch**: `master`
**Repo**: https://github.com/Behodler/antimatter
**Report family**: `reports/antimatter/01`

## Scope of this document

This is the single QA bundle for run-01. It carries every Low, Centralization, and QA/Non-Critical
finding from this run. High and Medium findings are submitted individually as
`submissions/H-01.md` and `submissions/M-0*.md` and are **not** restated here.

Faithfulness findings (`F-01`, `F-02`, `F-03`) are **deliberately excluded**: story-conformance is a
Law-2 concern and is adjudicated in `submissions/spec-conformance.md`, not in this bundle. `M-06` is
parked in `manual-review.json` and is likewise not included — parked because the **deployed
yield-strategy/vault version is unknown** (the `phUSD-stable-minter` pin `d6ed1156` is current; the
nested `lib/vault` pin `043ff2c` is 11 commits behind vault master `0110ce4`), not because the minter
pin is stale. Re-check it against the **deployed** strategy, not the minter pin — see `README.md`.

## Provenance of proofs — read before citing any PoC

Every proof-of-concept referenced below is **audit-authored**, written for this audit and living
under `workspace/antimatter/test/audit/**`. These files:

- are **NOT** part of the antimatter project's own test suite,
- do **NOT** exist in the submodule at any commit, and
- must **never** be cited as project test coverage, nor filed as a project test path.

They demonstrate the behaviour described; they say nothing about how well the project tests itself.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| Centralization Risk | 2 |
| QA / Non-Critical | 4 |
| **Total** | **9** |

Severities here are deliberately unflattering. This is the low-value channel: nothing in this
document puts user funds at risk along a path an attacker controls, and several entries are expected
to die in triage. They are recorded rather than dropped so the decision to dismiss them is a visible
one (Law 1: recall beats report-tidiness).

| Label | Issue ID | Fingerprint | Ledger severity |
|-------|----------|-------------|-----------------|
| L-01 | `am1l1` | `ad4b779566291190` | low |
| L-02 | `am1l2` | `5c89b2d372ec9286` | low |
| L-03 | `am1l3` | `0ed1c6e3270816c5` | low |
| C-01 | `am1c1` | `2a844d32db2eb0f9` | low |
| C-02 | `am1c2` | `3a90280bed325637` | qa |
| Q-01 | `am1q1` | `8c2dcc57bcd3be05` | qa |
| Q-02 | `am1q2` | `c330566040a453ea` | qa |
| Q-03 | `am1q3` | `0174ea0bd59a9b12` | qa |
| Q-04 | `am1q4` | `507e375d3ef4abfe` | qa |

All fingerprints are the legacy form `sha256(contract:function:rootCauseClass)[:16]` with an empty
`entryPoint`, carried verbatim from the ledger so a later run reconciles rather than re-files.

---

## Low Risk Findings

### [L-01] `mintedForStable` is a balance delta, not an attribution: phUSD arriving mid-call is forwarded to the caller-chosen recipient <!-- id: am1l1 -->

**Fingerprint**: `ad4b779566291190` (`src/Antimatter.sol:annihilateFrom:BalanceDeltaMistakenForAttribution`)

**Location**: [`src/Antimatter.sol#L220-L237`](https://github.com/Behodler/antimatter/blob/0bb82d867dba43bc514a508800826f90436c2ee3/src/Antimatter.sol#L220-L237)

**Description**: `annihilateFrom` measures the stable leg as a *balance delta* across the mint call and
forwards the whole delta to the caller-supplied `recipient`:

```solidity
uint256 phUSDBefore = _phUSD.balanceOf(address(this));       // :220
...
minter.mint(stable, stableAmount);                            // :227
...
uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;  // :232
if (mintedForStable == 0) revert PhUSDNotReceived();          // :233
_phUSD.mint(recipient, amount);                               // :236
IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable); // :237
```

The delta is never compared against what `PhusdStableMinter` actually minted — a value obtainable
exactly via `minter.calculateMintAmount(stable, stableAmount)`. Any phUSD that lands on Antimatter
inside the `:220`–`:232` window is therefore attributed to this annihilation and paid out.

Note the asymmetry with the stablecoin side. On the stable leg the same measured-balance pattern is
what makes `:230` **fail closed** (`StableNotDeposited`). On the phUSD leg the identical pattern turns
an unexpected inbound into free value instead of a revert.

The only non-trusted code that executes inside the window is the stablecoin's own transfer path at
`:222`, and `stable` must have been registered by the owner — which is what holds this at Low.

**Impact**: phUSD arriving mid-call is swept to a caller-chosen address. Audit PoC: 500e18 injected
from the stablecoin's transfer hook, the annihilator walks away with 700e18 instead of 200e18.

**PoC** (audit-authored — see provenance note above): `workspace/antimatter/test/audit/Tier2b.t.sol`
- `test_midCallPhUSDInjectionIsForwardedToRecipient` — 500e18 injected from the stable's hook; annihilator receives 700e18. **Passing.**
- `test_preExistingPhUSDDonationIsNotSwept` — control: a pre-call 500e18 donation *is* correctly excluded by the `:220` snapshot and remains stuck (owner-recoverable via `rescueERC20`). **Passing.**

**Recommendation**: Derive the expected stable leg from the minter and use the balance delta only as
an equality assertion, so an unexpected inbound reverts rather than paying out.

```solidity
uint256 expected = minter.calculateMintAmount(stable, stableAmount);
uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;
if (mintedForStable != expected) revert PhUSDNotReceived();
```

---

### [L-02] Once phUSD and the minter are both wired, the phUSD address can never be changed — the two setters mutually lock <!-- id: am1l2 -->

**Fingerprint**: `5c89b2d372ec9286` (`src/Antimatter.sol:setPhUSD, setPhUSDMinter:MutuallyLockingSetters`)

**Location**: [`src/Antimatter.sol#L124-L145`](https://github.com/Behodler/antimatter/blob/0bb82d867dba43bc514a508800826f90436c2ee3/src/Antimatter.sol#L124-L145)

**Description**: The two setters each validate against the other, and there is no ordering of calls
that escapes the pair:

- `setPhUSD` (`:127-129`) rejects any address the currently-configured minter does not mint.
- `setPhUSDMinter` (`:140-141`) rejects any minter that does not mint the currently-configured phUSD.
- `PhusdStableMinter.phUSD` is **immutable**, so the minter cannot be bent to a new phUSD.
- Neither setter accepts `address(0)`, so neither side can be unwired to break the deadlock.

The result is that `setPhUSD` — a function whose name advertises a re-pointable address — is
effectively one-way after first configuration. This is not documented anywhere.

**Impact**: No funds at risk. But a phUSD redeployment would force a full Antimatter redeployment,
and Antimatter is non-upgradeable with no migration path, so every outstanding antimatter balance
would be lost. This is a Law-3 footgun: an owner reading two independent setters would reasonably
believe either can be re-pointed, and would discover otherwise only at the moment a migration is
actually needed — the worst possible time to learn it.

Held at Low because phUSD is intended to be permanent, so the trigger may never arrive.

**PoC** (audit-authored): `workspace/antimatter/test/audit/Tier2.t.sol`
- `test_L_phUSDCanNeverBeMigratedOnceMinterWired` — both call orderings revert. **Passing.**

**Recommendation**: Either document the one-way property directly on `setPhUSD`, or add an owner-only
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

**Location**: [`src/Antimatter.sol#L232-L233`](https://github.com/Behodler/antimatter/blob/0bb82d867dba43bc514a508800826f90436c2ee3/src/Antimatter.sol#L232-L233)

**Description**: When `floor(amount * exchangeRate / 1e18)` truncates to zero, the stable leg mints
nothing and the zero-guard at `:233` reverts the **entire** annihilation — including the antimatter
leg, which was still perfectly valid.

The guard itself is the right instinct: it catches a minter that fails to deliver. The problem is
that it doubles as an undiagnosable configuration error. Two consequences:

1. `exchangeRate = 0`, a natural way for an owner to express "stop paying the stable half", instead
   **hard-bricks** annihilation for that stablecoin entirely.
2. A near-zero rate bricks it only for *small* amounts, producing an amount-dependent revert that
   looks like a heisenbug from outside.

In both cases the surfaced error is `PhUSDNotReceived`, which reads as *"the minter failed to
deliver"* — pointing the operator at the wrong contract entirely, not at their own rate setting.

`setStablecoinEnabled(false)` already exists as the honest per-stable kill switch, which is why
`rate = 0` reads as a misapprehension rather than an intended mechanism. This is the same
misapprehension documented in M-04.

**Impact**: Liveness only; no value loss.

**Evidence** (symbolic, not a PoC): `reports/antimatter/01/tier3/halmos-p4-nonzero.txt` — property
REFUTED with a concrete witness, `amount = 524288000000000000`, `rate = 1 wei`. Recorded as reachable
only symbolically; a fuzzer over sensible rates would not reach it.

**Recommendation**: Bound `exchangeRate` away from zero at registration/update time, and separate the
diagnostics so an operator is told which contract is actually at fault:

```solidity
if (mintedForStable == 0) revert StableLegRoundedToZero(stable, stableAmount);
```

Failing that, document `PhUSDNotReceived` as also covering "the configured exchangeRate rounds this
amount's stable leg to zero".

---

## Centralization Risks

### [C-01] `FlaxToken.revokeAllMintPrivileges` silently voids every outstanding antimatter claim, and Antimatter exposes no view of its own authorisation status <!-- id: am1c1 -->

**Fingerprint**: `2a844d32db2eb0f9` (`src/Antimatter.sol:annihilateFrom:UpstreamMintPrivilegeRevocationUnobservable`)

**Location**: [`src/Antimatter.sol#L236`](https://github.com/Behodler/antimatter/blob/0bb82d867dba43bc514a508800826f90436c2ee3/src/Antimatter.sol#L236)

**Description**: Antimatter's entire value rests on a mint authorisation held by a **third, independent
principal** — FlaxToken's owner — which is revocable wholesale via the documented global kill switch
`revokeAllMintPrivileges` (`mintVersion++`).

What makes this a reportable footgun rather than a trusted-owner non-issue (Law 3) is that the
condition is **unobservable**:

1. There is no per-minter event on revocation.
2. There is no view on **either** contract reporting whether Antimatter is currently an authorised,
   current-version minter.
3. Recovery requires `setMinter` on **both** contracts. Re-authorising only `PhusdStableMinter` —
   the obvious one, since ordinary minting visibly resumes — leaves annihilation silently dead.
4. Off-chain UIs still see a configured, registered, non-paused system throughout, because
   `toStableAmount` continues to return successfully.

A competent, non-malicious FlaxToken owner reaching for the documented global kill switch would be
surprised to learn it also voids every antimatter claim, and would have no signal telling them so.

**Impact**: Every outstanding antimatter token becomes permanently inert. Antimatter is a reward token
with no purchase price, so no user capital is destroyed — but the entire outstanding claim is.

**Likelihood**: Low; a deliberate, emergency-scoped action. The finding is about the *silence* of the
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

**Location**: [`src/Antimatter.sol#L201`](https://github.com/Behodler/antimatter/blob/0bb82d867dba43bc514a508800826f90436c2ee3/src/Antimatter.sol#L201)

**Description**: Antimatter is not `Pausable` and exposes no owner lever to halt annihilation. Stopping
it requires one of:

- `PhusdStableMinter`'s pauser or owner,
- `FlaxToken`'s owner, or
- the yield strategy's owner

— all principals independent of `Antimatter.owner()`, with nothing requiring them to be the same
party. The only *fast* lever, `FlaxToken.revokeAllMintPrivileges`, is global and causes collateral
damage: it silently de-authorises `PhusdStableMinter` too (see C-01).

This is an operational observation, **not** a malicious-owner finding: no owner needs to misbehave
for the incident-response path to be missing.

**Impact**: No direct asset impact — incident-response capability only. If a defect is found in
Antimatter itself, its own owner cannot stop it. H-01 demonstrates that "a defect exists in
Antimatter" is not a hypothetical premise.

**Why only QA**: the composition is arguably deliberate — Antimatter keeps no stablecoin list of its
own and defers control to the minter by design. The gap is in the runbook as much as in the code.

**Recommendation**: Either document the incident-response runbook (who to call, in what order), or add
an owner-settable `annihilationPaused` flag checked at the top of `annihilateFrom`, so the contract's
own owner holds a proportionate, non-global lever.

---

## QA / Non-Critical

### [Q-01] `toStableAmount` is a decimals-only rescale and is not a phUSD preview; the local `decimals` also shadows `ERC20.decimals()` <!-- id: am1q1 -->

**Fingerprint**: `8c2dcc57bcd3be05` (`src/Antimatter.sol:toStableAmount:MisleadingHelperNamingAndShadowing`)

**Location**: [`src/Antimatter.sol#L246-L257`](https://github.com/Behodler/antimatter/blob/0bb82d867dba43bc514a508800826f90436c2ee3/src/Antimatter.sol#L246-L257)

**(a) Missing preview.** `toStableAmount` is the only public preview on the annihilation path, and it
ignores `exchangeRate` entirely — it is a pure decimals rescale. The phUSD actually delivered is
`amount + floor(amount * exchangeRate / 1e18)`. At any rate other than `1e18`, an integrator deriving
an expected payout from this function is wrong on the stable leg.

The asymmetry itself is by design and internally coherent (stable leg priced at rate, antimatter leg
always at 1). The QA item is the **absence** of a matching phUSD-side preview, which leaves
`toStableAmount` looking like one.

**(b) Shadowing.** The local `decimals` at `:250` shadows the inherited
`ERC20.decimals()` / `IERC20Metadata.decimals()`.

**Recommendation**:
- Add a real preview and document `toStableAmount` as the input-side rescale only:
  ```solidity
  function previewAnnihilate(address stable, uint256 amount)
      external view returns (uint256 stableAmount, uint256 phUSDOut);
  ```
  composing `minter.calculateMintAmount`.
- Rename the local to `stableDecimals`.

*Note*: the economic consequence of an unbounded, un-timelocked `exchangeRate` is DEDUP-005 and is
deliberately not re-adjudicated here.

---

### [Q-02] `recipient` is guarded against `address(0)` but not against `address(this)` — an annihilation can come to rest on the contract <!-- id: am1q2 -->

**Fingerprint**: `c330566040a453ea` (`src/Antimatter.sol:annihilateFrom:RecipientSelfAddressUnguarded`)

**Location**: [`src/Antimatter.sol#L203`](https://github.com/Behodler/antimatter/blob/0bb82d867dba43bc514a508800826f90436c2ee3/src/Antimatter.sol#L203)

**Description**: `:203` rejects `recipient == address(0)` but accepts `address(this)`. `:236` then mints
`amount` phUSD to Antimatter and `:237` transfers `mintedForStable` from Antimatter to itself, so the
full ~2x payout settles on the contract with the antimatter **already burned**.

**Impact**: Self-inflicted caller error with no attacker gain. Mitigating facts: the phUSD is recoverable
by the owner via `rescueERC20` (`:263`), and a later annihilation's `phUSDBefore` snapshot at `:220`
correctly excludes it, so it is not swept to the next annihilator (control-tested under L-01). No
partial settlement state is created.

**PoC** (audit-authored): `workspace/antimatter/test/audit/Tier2b.t.sol`
- `test_recipientSelfStrandsPhUSD` — 200e18 phUSD settles on the Antimatter contract, antimatter already burned. **Passing.**

**Recommendation**: `address(this)` is exactly as cheap to reject as `address(0)`.

```solidity
if (recipient == address(0)) revert RecipientZeroAddress();
if (recipient == address(this)) revert RecipientSelfAddress();
```

---

### [Q-03] `approvedMinters()` copies the whole `EnumerableSet` to memory with no bound <!-- id: am1q3 -->

**Fingerprint**: `0174ea0bd59a9b12` (`src/Antimatter.sol:approvedMinters:UnboundedSetCopyInView`)

**Location**: [`src/Antimatter.sol#L174`](https://github.com/Behodler/antimatter/blob/0bb82d867dba43bc514a508800826f90436c2ee3/src/Antimatter.sol#L174)

**Description**: `EnumerableSet.values()` is unbounded. This is an external view, so no on-chain caller
is forced through it today, but it will gas-out for an off-chain reader once the set grows large, and
any future on-chain consumer inherits the unbounded loop.

**Recommendation**: Paginate, or keep `approvedMinterAt` / `approvedMinterCount` (`:169`, `:164`) as
the supported iteration path and document `values()` as off-chain-only.

> **Triage note — likely triage-death.** The approved-minter set is expected to hold a handful of
> entries, so the growth premise may simply never hold. Recorded rather than deleted so the dismissal
> is a visible decision.

---

### [Q-04] Static-analysis findings in audit-harness and mock files (`test/**`) <!-- id: am1q4 -->

**Fingerprint**: `507e375d3ef4abfe` (`test/**:multiple:ToolNoiseInTestHarness`)

**Location**: `test/**` — test and mock files only. **No production contract is implicated.**

**Description**: Slither and Aderyn raised the following in test-harness and mock files. They are
recorded for completeness and are **explicitly not being presented as protocol issues**:

| ID | File | Detail |
|----|------|--------|
| SA-011 | `test/Antimatter.t.sol` (`test_transfer`, :46) | Return value of `antimatter.transfer(stranger, 4e18)` ignored. Slither `unchecked-transfer` + Aderyn `unsafe-erc20-operation` / `unchecked-return` at the same line. |
| SA-012 | `test/Annihilation.t.sol` (:62, :133, :155, :285) | `approve()` / ERC20 return values ignored across `_fund`, `test_thirdPartySpendsAntimatterAllowance`, `test_selfAnnihilationDoesNotSpendAllowance`, `test_reentrantStableIsBlocked`. Corroborated by Aderyn at identical lines. |
| SA-013 | `test/mocks/ReentrantStable.sol` (:16-17) | Address state variables assigned in constructor/setter without zero-check. |

**Impact**: None. These are audit-harness and mock files.

**Recommendation**: None required. If desired, use `SafeERC20` in test helpers for consistency.

> **Triage note — likely triage-death, and deliberately not inflated.** This entry exists so the
> automated tools' output is accounted for rather than silently discarded. It should not be read as
> nine findings' worth of signal; it is three clusters of tool noise in non-production code.

---

## Appendix A — Automated report (4naly3er)

Generated with 4naly3er, the C4-standard automated QA/gas report generator, over
`src/Antimatter.sol` at commit `0bb82d867dba43bc514a508800826f90436c2ee3`. Also written standalone to
`reports/antimatter/01/submissions/4naly3er-report.md`.

### Run provenance and two caveats

**1. Remappings.** antimatter has **no `remappings.txt`** — its remappings live in `foundry.toml` by
design, so a parent project can override them. 4naly3er reads `remappings.txt` relative to its
`basePath` and cannot read `foundry.toml`. Because `lib/` is strictly read-only, the four remappings
were transcribed verbatim from `foundry.toml` into a `remappings.txt` in the **writable workspace
clone** (`workspace/antimatter/`, gitignored), and 4naly3er was pointed at that clone as `basePath`.
Imports resolved and the contract compiled — **this run is not import-truncated.** The scope file was
restricted to `src/Antimatter.sol`, so the workspace's audit-authored tests did not enter the report.

**2. One detector was skipped — a tool bug, not a scope gap.** 4naly3er crashed inside its
`NC/uselessOverride` detector with `TypeError: Cannot read properties of undefined (reading
'nodeType')`, raised from `solidity-ast`'s `findAll` traversal. This is a version skew between the
solc 0.8.27 AST and 4naly3er's pinned `solidity-ast`, and it aborts the whole run rather than the one
detector. The detector was temporarily wrapped in a guard to let the remaining detectors complete;
**the tool was restored to its original state afterwards.** The skipped detector reports unused
`override` parameter names — a purely cosmetic NC class that this repository discourages reporting
anyway, so nothing of QA value was lost. Every other detector ran to completion.

### Results at a glance

| Class | Issues | Instances |
|-------|-------:|----------:|
| Gas Optimizations | 3 | 22 |
| Non-Critical | 7 | 52 |
| Low | 4 | 4 |
| Medium (tool-labelled) | 1 | 6 |

The tool's single "Medium" is `M-1 Centralization Risk for trusted owners` (6 instances) — the generic
`onlyOwner` sweep every 4naly3er run produces. Under Law 3 this is **not** a finding on its own; the
centralization concerns actually worth reporting are adjudicated above as C-01 and C-02. Likewise the
tool's `L-2 Division by zero not prevented` touches the same `toStableAmount` scale arithmetic
discussed in Q-01 and L-03, but the tool reaches it generically rather than by the reasoning recorded
there. None of the tool's Low/NC/Gas output was promoted into the manual findings above; it is
attached as a baseline, not as evidence.

The full generated report follows verbatim.

---

##### 4naly3er raw output


#### Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | For Operations that will not overflow, you could use unchecked | 13 |
| [GAS-2](#GAS-2) | Avoid contract existence checks by using low level calls | 4 |
| [GAS-3](#GAS-3) | Functions guaranteed to revert when called by normal users can be marked `payable` | 5 |
##### <a name="GAS-1"></a>[GAS-1] For Operations that will not overflow, you could use unchecked

*Instances (13)*:
```solidity
File: src/Antimatter.sol

4: import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

5: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

8: import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

9: import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

10: import {IFlax} from "@phUSD/IFlax.sol";

11: import {PhusdStableMinter} from "@phUSDMinter/PhusdStableMinter.sol";

232:         uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;

239:         emit Annihilated(stable, from, recipient, amount, stableAmount, amount + mintedForStable);

254:         uint256 scale = 10 ** (18 - decimals);

255:         uint256 stableAmount = amount / scale;

256:         if (stableAmount * scale != amount) revert AmountNotRepresentable(amount, decimals);

```

##### <a name="GAS-2"></a>[GAS-2] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (4)*:
```solidity
File: src/Antimatter.sol

219:         uint256 stableBefore = IERC20(stable).balanceOf(address(this));

220:         uint256 phUSDBefore = _phUSD.balanceOf(address(this));

230:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

232:         uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;

```

##### <a name="GAS-3"></a>[GAS-3] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (5)*:
```solidity
File: src/Antimatter.sol

124:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

136:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

151:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

179:     function mint(address to, uint256 amount) external onlyApprovedMinters {

263:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```


#### Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | `constant`s should be defined rather than using magic numbers | 2 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 21 |
| [NC-3](#NC-3) | Consider disabling `renounceOwnership()` | 1 |
| [NC-4](#NC-4) | Functions should not be longer than 50 lines | 11 |
| [NC-5](#NC-5) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 2 |
| [NC-6](#NC-6) | Take advantage of Custom Error's return value property | 14 |
| [NC-7](#NC-7) | Constants should be defined rather than using magic numbers | 1 |
##### <a name="NC-1"></a>[NC-1] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (2)*:
```solidity
File: src/Antimatter.sol

252:         if (decimals > 18) revert UnsupportedDecimals(decimals);

254:         uint256 scale = 10 ** (18 - decimals);

```

##### <a name="NC-2"></a>[NC-2] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (21)*:
```solidity
File: src/Antimatter.sol

10: import {IFlax} from "@phUSD/IFlax.sol";

101:     IFlax public phUSD;

125:         if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();

137:         if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();

138:         IFlax _phUSD = phUSD;

139:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

152:         if (minter == address(0)) revert ApprovedMinterZeroAddress();

154:         if (changed) emit ApprovedMinterSet(minter, approved);

202:         if (amount == 0) revert ZeroAmount();

203:         if (recipient == address(0)) revert RecipientZeroAddress();

205:         IFlax _phUSD = phUSD;

206:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

208:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

214:         if (from != msg.sender) _spendAllowance(from, msg.sender, amount);

230:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

233:         if (mintedForStable == 0) revert PhUSDNotReceived();

248:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

251:         if (yieldStrategy == address(0)) revert StablecoinNotRegistered(stable);

252:         if (decimals > 18) revert UnsupportedDecimals(decimals);

256:         if (stableAmount * scale != amount) revert AmountNotRepresentable(amount, decimals);

264:         if (to == address(0)) revert RecipientZeroAddress();

```

##### <a name="NC-3"></a>[NC-3] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

21: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

```

##### <a name="NC-4"></a>[NC-4] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (11)*:
```solidity
File: src/Antimatter.sol

124:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

136:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

151:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

159:     function isApprovedMinter(address minter) external view returns (bool) {

164:     function approvedMinterCount() external view returns (uint256) {

169:     function approvedMinterAt(uint256 index) external view returns (address) {

174:     function approvedMinters() external view returns (address[] memory) {

179:     function mint(address to, uint256 amount) external onlyApprovedMinters {

201:     function annihilateFrom(address stable, address from, address recipient, uint256 amount) external nonReentrant {

246:     function toStableAmount(address stable, uint256 amount) public view returns (uint256) {

263:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

##### <a name="NC-5"></a>[NC-5] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (2)*:
```solidity
File: src/Antimatter.sol

113:         if (msg.sender != owner() && !_approvedMinters.contains(msg.sender)) {

214:         if (from != msg.sender) _spendAllowance(from, msg.sender, amount);

```

##### <a name="NC-6"></a>[NC-6] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (14)*:
```solidity
File: src/Antimatter.sol

125:         if (address(newPhUSD) == address(0)) revert PhUSDZeroAddress();

128:             revert PhUSDMinterMismatch(minter.phUSD(), address(newPhUSD));

137:         if (address(newMinter) == address(0)) revert PhUSDMinterZeroAddress();

139:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

141:             revert PhUSDMinterMismatch(newMinter.phUSD(), address(_phUSD));

152:         if (minter == address(0)) revert ApprovedMinterZeroAddress();

202:         if (amount == 0) revert ZeroAmount();

203:         if (recipient == address(0)) revert RecipientZeroAddress();

206:         if (address(_phUSD) == address(0)) revert PhUSDNotSet();

208:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

230:         if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();

233:         if (mintedForStable == 0) revert PhUSDNotReceived();

248:         if (address(minter) == address(0)) revert PhUSDMinterNotSet();

264:         if (to == address(0)) revert RecipientZeroAddress();

```

##### <a name="NC-7"></a>[NC-7] Constants should be defined rather than using magic numbers

*Instances (1)*:
```solidity
File: src/Antimatter.sol

254:         uint256 scale = 10 ** (18 - decimals);

```


#### Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 1 |
| [L-2](#L-2) | Division by zero not prevented | 1 |
| [L-3](#L-3) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
| [L-4](#L-4) | Sweeping may break accounting if tokens with multiple addresses are used | 1 |
##### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

21: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

```

##### <a name="L-2"></a>[L-2] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

255:         uint256 stableAmount = amount / scale;

```

##### <a name="L-3"></a>[L-3] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
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

*Instances (1)*:
```solidity
File: src/Antimatter.sol

7: import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

```

##### <a name="L-4"></a>[L-4] Sweeping may break accounting if tokens with multiple addresses are used
There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (1)*:
```solidity
File: src/Antimatter.sol

263:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```


#### Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 6 |
##### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (6)*:
```solidity
File: src/Antimatter.sol

21: contract Antimatter is ERC20, Ownable, ReentrancyGuard {

119:     constructor(address initialOwner) ERC20("Antimatter", "AM") Ownable(initialOwner) {}

124:     function setPhUSD(IFlax newPhUSD) external onlyOwner {

136:     function setPhUSDMinter(PhusdStableMinter newMinter) external onlyOwner {

151:     function setApprovedMinter(address minter, bool approved) external onlyOwner {

263:     function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {

```

