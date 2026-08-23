> ## ⚠ SUPERSEDED IN PART — 2026-08-23. Every `M-07` reference below is stale.
>
> Ledger entry `am3m7` (`aa6a092cacb3c93c`, `M-07`) was triaged **wont-fix** by the owner on
> 2026-08-23 and the audit accepts the reasoning; see the withdrawal banner at the top of
> `submissions/M-07.md` for the full argument. **This run raised 0 surviving Mediums.** The body
> below is preserved verbatim as the audit record, but wherever it treats `M-07` as a live Medium it
> is superseded. Four specific rules stated below are **withdrawn**:
>
> 1. **The `FLAG-04` publication rule** — `L-03` (`0ed1c6e3270816c5`) is no longer proposed for a
>    low → medium re-weigh and does not publish as an appendix to `submissions/M-07.md`. At `R = 0`
>    the delivered total is exactly `amount`, so any floor above `amount` reverts; `L-03` therefore
>    reaches only a caller who passes the documented, deliberate zero waiver. It stays **Low** and
>    **open**. No summary should read "1 Medium loss channel (2 entries)" — the correct count is
>    **0 Mediums**.
> 2. **`Q-06`'s binding closure bar on `M-07`** is **moot**, since `M-07` is closed by triage rather
>    than by a fix and there is nothing left for a project test to prove.
> 3. **`Q-06`'s re-weigh condition** (hold at QA while `M-07` is open, re-weigh to Low on its
>    closure) is withdrawn along with the inert-band limb it rested on. `Q-06` survives at QA on its
>    **independent** limb only: one floor test is named for a condition it does not actually test.
> 4. **`F-05`'s second limb** — that story-003's carried-forward `[medium]` is a real defect
>    dispositioned "on a rationale the arithmetic refutes" — is withdrawn. `F-05` survives at Low on
>    its **first** limb only, which never depended on `M-07`: story-003 was planned, executed **and**
>    reviewed by the same harness with no independent reviewer, then machine-approved.
>
> Nothing here is retracted into silence. `L-03`, `Q-06` and `F-05` all remain **open** in the
> ledger on their surviving limbs, and `M-07` carries reopen triggers on its ledger entry.

---

# QA Report — antimatter (run-03)

**Project**: antimatter (`lib/antimatter`)
**Commit audited**: `3a96fb7de072b29515986f92282cdece7b12d4ca`
**Previous audited commit**: `c91bc1a44424b853247a3849732bf89547defdec` (run-02)
**Scan mode**: regression (`c91bc1a..3a96fb7`)
**Branch**: `master`
**Repo**: https://github.com/Behodler/antimatter
**Report family**: `reports/antimatter-03`
**Delta**: `[story-003] Add a minPhUSDOut slippage floor to annihilate`

---

## Scope of this document

This is the **single** QA bundle for run-03. It carries every Low, Centralization and QA/Non-Critical
finding raised **this run**, plus a clearly-separated carryover section holding the **full text** of
every QA-band ledger entry that remains open at `3a96fb7`.

**Carryover bodies are full copies, not stubs.** Every open QA-band ledger entry on this project has
`reportPath: null` — there is no prior submission file to copy forward — so each carryover section
below was **synthesised from the ledger record and re-verified against the source at `3a96fb7`**.
Skipping a null-path entry would make a still-open finding disappear from the submission layer, which
is a Law-1 failure; none was skipped.

**One new Medium was raised this run** (`M-07`, `aa6a092cacb3c93c`) and is submitted individually as
`submissions/M-07.md`. It is **not** in this bundle. Two entries in this bundle carry **binding
closure conditions on `M-07`** — see `Q-06` and the `Q-05` residue note.

### Deliberate exclusions — none of them suppressions

| Entry | Fingerprint | Where it went instead | Why |
|---|---|---|---|
| `F-05` (new this run) | — | `submissions/spec-conformance.md` | Faithfulness is **Law 2** and routes to the spec-conformance report at whatever band it lands. It must never be absorbed into the QA bundle. |
| `F-03` (carryover, open) | `9d06644ddad24e5a` | `submissions/spec-conformance.md` | Same rule. |
| `F-01` (carryover, `fix-pending`) | `3aac91383dcb6060` | spec-conformance / incomplete-fix channel | Same rule, plus `fix-pending` means a fix is **owed** and the entry is never suppressed. Cross-referenced from `Q-05` below because `Q-05` exists to stop `F-01` being falsely closed. |
| `F-04` (carryover, open) | `d34180996ba41ff8` | `submissions/spec-conformance.md` | The ledger entry carries a **binding routing directive** (*"ROUTED TO submissions/spec-conformance.md ONLY — NEVER THE QA BUNDLE, AT ANY BAND"*). Its **status this run is recorded below** under *Carryover — status-only entries* so it is not silently dropped, but its body is not reproduced here. |
| `M-07` (new this run) | `aa6a092cacb3c93c` | `submissions/M-07.md` | Medium findings are submitted individually. |
| `L-04`, `L-05` | `25088b59893f37e0`, `3a8dbad19ba9104e` | — | **`acknowledged`** on the ledger: accepted and disposed of by the owner. Suppressed from carryover by design. Named here so the absence is visible. |
| `H-01`, `M-01` | `033432b0e650af67`, `a1c81428a47ad295` | — | `fixed` (2026-08-20). Out of band and closed. |
| `M-02`…`M-06` | — | — | `wont-fix`. Out of band. `M-04` is nevertheless **disclosed in full** inside `L-06` below, per the mandatory wont-fix disclosure. |

---

## Provenance of proofs — read before citing any PoC

Every proof-of-concept referenced below is **audit-authored**, written for this audit and living under
`workspace/antimatter/test/audit/**`. These files:

- are **NOT** part of the antimatter project's own test suite,
- do **NOT** exist in the submodule at any commit, and
- must **never** be cited as project test coverage, nor filed as a project test path.

The one exception is `Q-06`, whose entire subject is `test/Annihilation.t.sol` — a **genuine project
file present in `git ls-tree` at `3a96fb7`**. Every line and floor value quoted in `Q-06` was read
from that project file.

---

## Tooling coverage — what the tools did and did not prove

The automated pass covered all **6** in-scope first-party files (`src/Antimatter.sol`,
`test/Annihilation.t.sol`, `test/Antimatter.t.sol` and the three `test/mocks/*`). The full 4naly3er
output is attached as **Appendix A** and standalone as `submissions/4naly3er-report.md`.

> **Semgrep contributed NO security coverage this run.** All **40 of 40** results were **INFO-level
> style and performance rules**; zero WARNING and zero ERROR. `p/smart-contracts` has no Solidity
> vulnerability detectors. A clean Semgrep run on this repository is **evidence of nothing** and
> nothing in this bundle should be read as implying otherwise.

---

## Summary

### New this run

| Severity | Count |
|----------|-------|
| Low Risk | 1 |
| Centralization Risk | 0 |
| QA / Non-Critical | 1 |
| **Total** | **2** |

| Label | Issue ID | Fingerprint | Band | Note |
|-------|----------|-------------|------|------|
| L-06 | `am3l6` | `6ce80dacbcf6d566` | low | **PRE-EXISTING at `c91bc1a`, not delta-induced.** Carries **mandatory wont-fix disclosure WFD-01** against ledger `M-04`. |
| Q-06 | `am3q6` | `4ab41ae7b5b220a0` | qa | Carries a **binding closure bar on `M-07`**. |

The run-03 `L-XX`/`Q-XX` sequence covers **only run-03's own findings**. Nothing is renumbered around
the carryover, and carryover entries keep the labels and issue IDs of the run that first minted them.

### Carryover — still open at `3a96fb7`

| Label | Issue ID | Fingerprint | Ledger band | Status this run |
|-------|----------|-------------|-------------|-----------------|
| L-01 | `am1l1` | `ad4b779566291190` | qa | **RE-ARMED.** The check that neutralised it was deleted. **Proposed re-weigh qa → low.** |
| L-02 | `am1l2` | `5c89b2d372ec9286` | low | unchanged |
| L-03 | `am1l3` | `0ed1c6e3270816c5` | low | **NOT fixed.** The named revert is gone; the same lines now **settle silently**. Inherited arithmetic **corrected**. **Proposed re-weigh low → medium** — if applied it publishes as an **appendix to `submissions/M-07.md`**, not as a standalone Medium; count it as **1 Medium loss channel (2 entries)**. |
| F-02 | `am1f2` | `78612be9264d2b49` | low | **WORSENED** — second selector change in three stories |
| C-01 | `am1c1` | `2a844d32db2eb0f9` | low | unchanged |
| C-02 | `am1c2` | `3a90280bed325637` | qa | unchanged |
| C-03 | `am2c3` | `2e9152785e3dc975` | qa | unchanged |
| Q-01 | `am1q1` | `8c2dcc57bcd3be05` | qa | unchanged |
| Q-02 | `am1q2` | `c330566040a453ea` | qa | unchanged (line refs moved) |
| Q-03 | `am1q3` | `0174ea0bd59a9b12` | qa | unchanged |
| Q-04 | `am1q4` | `507e375d3ef4abfe` | qa | unchanged |
| Q-05 | `am2q5` | `1b960956475d434a` | qa | **PROPOSED FIXED — moot by deletion, not a verified fix.** Residue travels to `M-07`. |
| F-04 | `am2f4` | `d34180996ba41ff8` | low | **PROPOSED FIXED — moot by deletion.** Body routed to `spec-conformance.md`; status recorded here only. |

> **Every fingerprint above and below is carried VERBATIM from `reports/ledgers/antimatter.json`.**
> **None was re-derived at this stage.** This project's `fingerprintDriftTrap` is live: 12 ledger
> entries are basis'd on the retired function name `annihilateFrom`, and story-003 has now changed the
> `annihilate` signature a **second** time (trailing `uint256 minPhUSDOut`). Re-deriving any basis
> would mint a new hash for an existing defect and silently re-file it as new.

> **Proposals, not applications.** Every "re-weigh" and "propose fixed" below is a **proposal to
> `/ledger`**. No status is flipped by this document; only a human applies one.

Severities here are deliberately unflattering. This is the low-value channel: nothing in this document
puts user funds at risk along a path an unprivileged attacker controls, and several entries are
expected to die in triage. They are recorded rather than dropped so the decision to dismiss them is a
**visible** one (Law 1: recall beats report-tidiness).

---

## Low Risk Findings

### [L-06] The caller, not the protocol, picks which registered stablecoin to pair with, and the pairing is by quantity rather than value, so a depegged stable whose manually-maintained `exchangeRate` has not yet been cut is every annihilator's dominant choice <!-- id: am3l6 -->

**Fingerprint**: `6ce80dacbcf6d566` (`src/Antimatter.sol:annihilate:CallerChoosesCheapestRegisteredStableAtParQuantity`)
**Location**: [`src/Antimatter.sol#L283-L304`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L283-L304) (`toStableAmount`), with the free caller parameter at [`#L226`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L226) and the call site at [`#L235`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L235).

> **PRE-EXISTING AT `c91bc1a`. NOT DELTA-INDUCED BY story-003.** State this before anything else or a
> reader will mistake it for a story-003 regression. story-003 touched neither `toStableAmount` nor
> the caller's freedom to choose `stable`. It is filed now because this run looked at the pairing
> arithmetic, not because the delta created it.

**Description**

`stable` is a **free, caller-supplied parameter** of `annihilate`:

```solidity
function annihilate(address stable, address recipient, uint256 amount, uint256 minPhUSDOut) external nonReentrant {
    ...
    uint256 stableAmount = toStableAmount(stable, amount);   // :235
```

and `toStableAmount` is a **pure decimal rescale with no price input whatsoever** — no rate, no
oracle, no timestamp:

```solidity
function toStableAmount(address stable, uint256 amount) public view returns (uint256) {
    PhusdStableMinter minter = phUSDMinter;
    if (address(minter) == address(0)) revert PhUSDMinterNotSet();

    (address yieldStrategy,, uint8 decimals,,,,) = minter.stablecoinConfigs(stable);
    if (yieldStrategy == address(0)) revert StablecoinNotRegistered(stable);
    if (decimals > 18) revert UnsupportedDecimals(decimals);
    ...
    uint256 scale = 10 ** (18 - decimals);
    uint256 stableAmount = amount / scale;
    if (stableAmount * scale != amount) revert AmountNotRepresentable(amount, decimals);
    return stableAmount;                                                          // :283-304
}
```

`1e18` of antimatter therefore pairs with **exactly one whole unit** of whichever registered stable
the caller names, *regardless of what that unit is currently worth*. There are **zero `block.` reads
anywhere in `src/`** (verified), so nothing on this path is time-aware.

The only per-asset compensation that exists is the minter's manually-maintained `exchangeRate`:

- `PhusdStableMinter.sol:138` — `updateExchangeRate(...) external onlyOwner`, a manual act with **no
  staleness field written and none read**, no oracle, and no timestamp.

**Path**

1. A registered stablecoin `S` depegs to $0.60. Its registered `exchangeRate` is still `1e18`, because
   cutting it is a manual owner transaction with no staleness bound.
2. `toStableAmount` prices `S` at **par quantity** — it has no price input to do otherwise.
3. Because the caller names the asset, every annihilator's **dominant strategy** during the owner's
   latency window is to pair against `S`, buying the phUSD half at a discount to par, rather than
   against a stable trading at $1.00.
4. The protocol receives `S` at par against a phUSD mint priced at the stale rate.

**Impact**: potential **protocol-side dilution**, not user loss. phUSD minted against collateral whose
market value is below the registered rate is unbacked, and per the run-01 finding on this project that
is **real dilution, not opportunity cost**. The channel is Antimatter-**adjacent**, not
Antimatter-specific — see below.

**Why Low, and why the deflator is stated rather than hidden.** The C4 Medium limb genuinely in play is
*"leak value with a hypothetical attack path with stated assumptions, but external requirements"*, and
this report does not pretend it is unengaged. Two things hold it at Low, and the first is decisive:

1. **Marginal capability is zero, established from source rather than assumed.**
   `PhusdStableMinter.mint(address stablecoin, uint256 amount) external nonReentrant`
   (`PhusdStableMinter.sol:203`) is **permissionless** — no access control, gated only on `!paused`,
   `config.enabled` and the rolling 24h cap. `onlyOwner` appears on `registerStablecoin`,
   `updateExchangeRate`, `setStablecoinEnabled`, `approveYS` and `setMaxMintPerDay`, and on **none of
   the user functions**. Anyone holding the depegged `S` can mint phUSD directly against the stale
   rate, in whatever size the daily cap allows, **without holding a single unit of antimatter** — and
   in strictly **larger** size than the annihilate path, which is additionally bounded by the caller's
   antimatter balance. What `annihilate` adds is only that the annihilator's **asset selection** is
   unconstrained. A real asymmetry, but no dilution capability an actor did not already possess more
   cheaply. This is the same marginal-capability test the pipeline applied to `L-04` in run-02.
2. **The conjunction is asserted, not observed.** It needs a real depeg **and** unresolved owner
   latency **and** at least two registered stables to choose between. None of the three is established
   at HEAD; Antimatter is not wired into staging (run-01).

**Where the root cause actually lives**: the absence of any staleness bound on `exchangeRate` is in the
**nested dependency** `PhusdStableMinter` (`lib/antimatter/lib/phUSD-stable-minter/`), which is outside
first-party scope. It is parked as **MR-03-D-08** rather than filed against the dependency. What is
filed *here* is the first-party contribution only: **Antimatter hands asset selection to the caller and
pairs by quantity.**

> **Also parked, and not discharged by this Low**: **MR-03-D-07** (front-runnable depeg lever, sanitizer
> `FLAG-06`) is the one parked item carried by no ledger entry and no finding. A promotion decision is
> still owed on it.

**Recommendation**

**All of the following are first-party and land entirely inside `src/Antimatter.sol` or its operational
envelope. This finding is fixable without touching the nested minter**, and it should not be closed as
an out-of-scope root cause.

1. **Bound the caller's selection freedom by policy** — gate `annihilate`'s `stable` parameter behind
   an owner-maintained allowlist **narrower** than the minter's registry. Antimatter already keeps an
   `EnumerableSet` for approved minters (`:187-189`) and already knows how to reject an unregistered
   asset (`StablecoinNotRegistered`, `:288`), so the pattern costs one set and one check. This is the
   direct fix for the first-party defect actually filed here: that **the caller, not the protocol,
   picks the asset**.
2. **Observe staleness at the Antimatter boundary.** Antimatter can enforce a freshness requirement it
   does not have to trust the minter to enforce: record the `exchangeRate` this contract last observed
   per stable alongside the `block.timestamp` at which it changed, and revert if the pairing is
   attempted against a rate that has sat unchanged past an owner-set bound. There are currently **zero
   `block.` reads anywhere in `src/`** — this is the cheapest way to make the path time-aware without
   any change to the dependency.
3. **Add a per-asset sanity check on the pairing.** `toStableAmount` today applies a pure decimal
   rescale with no price input at all (`:300-303`). An owner-set per-asset bound — a floor/ceiling on
   the rate Antimatter will pair at, or a rejection of any registered stable whose rate is exactly the
   default `1e18` while another registered stable's is not — turns a silent par assumption into an
   explicit, reviewable one.
4. **Restrict the registered set to a single stable**, which removes the selection channel entirely.
   Blunt, but it is available today and requires no code change: the finding needs **at least two**
   registered stables to have a choice at all.
5. **Document the operational requirement** — that a depeg response must cut the rate *before* the
   market does, and that the latency window is adversarially selected against rather than merely
   exposed. This is the minimum that must happen even if none of 1–4 is adopted.

> **Out-of-scope context, stated last and deliberately not led with.** The *shared* root cause — the
> absence of any staleness bound on `exchangeRate` — lives in the nested dependency
> `PhusdStableMinter` (`lib/antimatter/lib/phUSD-stable-minter/`, `updateExchangeRate` at
> `PhusdStableMinter.sol:138`), which is **outside first-party scope for this audit** and is parked as
> **MR-03-D-08**. A staleness bound or oracle cross-check there would fail the stale-rate mint closed
> for **every** consumer, not just Antimatter, and is the better protocol-wide answer. **It is offered
> as context only.** This finding is filed against Antimatter's own contribution and is fixable by
> items 1–5 above without it; the presence of a better out-of-scope fix is not grounds to close the
> in-scope one.

> ### WFD-01 — MANDATORY WONT-FIX DISCLOSURE
>
> **Prior entry**: **`M-04`** — `abe4305ac8f0c44f`, status **`wont-fix`**, triaged **2026-08-19** by a
> human.
>
> **Its triage reason, quoted verbatim**:
>
> > *"The stable leg is handled by phUSD-minter stable security. The exchange rate is there in case of
> > a depeg. But the 1:1 with antimatter is unrelated. The antimatter was earned elsewhere. It already
> > has its value. phUSD is just realizing that."*
>
> **Is this a re-file of `M-04`? NO.** `M-04` is **within-asset** re-pricing — the rate re-prices only
> the stable leg of one *named* asset. This finding is **cross-asset selection**: the caller names
> *which* registered stable to pair, and `toStableAmount` is a pure decimal rescale with no price
> input. Different mitigation. **No ledger fingerprint covers selection.**
>
> **Basis for raising it anyway.** The owner's triage explicitly names the depeg case as known and
> deliberately handled (*"the exchange rate is there in case of a depeg"*). What the triage does not
> address, and could not have, is **(a)** the **latency** of that manual handling — no staleness bound,
> no oracle, no timestamp anywhere on the path — and **(b)** that the **caller**, not the protocol,
> chooses the asset, which converts a latency window into a **dominant strategy**.
>
> **This finding does NOT override `M-04`.** It does not re-weigh, override or reopen
> `abe4305ac8f0c44f`, which remains `wont-fix` at the owner's human-set disposition. It is filed as
> **adjacent-but-distinct at Low**.

**PoC**: not required at Low. The mechanism is established by reading `toStableAmount` against
`PhusdStableMinter.mint`; there is no disputed runtime behaviour.

---

## QA / Non-Critical

### [Q-06] No test in the suite passes a floor inside the inert band `(0, amount]`, so the suite cannot fail if the inert range is ever made worse — and one floor test is named for a condition it does not test <!-- id: am3q6 -->

**Fingerprint**: `4ab41ae7b5b220a0` (`test/Annihilation.t.sol:slippageFloorSuite:GuardRangeUntestable`)
**Location**: [`test/Annihilation.t.sol#L296-L383`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/test/Annihilation.t.sol#L296-L383)
**Project file, not audit-authored**: `test/Annihilation.t.sol` is present in `git ls-tree` at
`3a96fb7`. No audit-authored path is cited in this finding.

**Description — two verified coverage defects.**

**(a) Dead band.** The guard under test is:

```solidity
uint256 totalPhUSD = amount + mintedForStable;                                        // :259
if (totalPhUSD < minPhUSDOut) revert InsufficientPhUSDOut(minPhUSDOut, totalPhUSD);   // :260
```

Every floor value in the suite was read line by line at `3a96fb7` against `amount == 100e18`:

| Test | Line | `minPhUSDOut` |
|---|---:|---:|
| `test_shortPhUSDMintReverts` | 302 | `200e18` |
| `test_shortPhUSDMintClearingFloorSucceeds` | 319 | `150e18` |
| `test_overPhUSDMintNowSucceeds` | 335 | `200e18` |
| `test_floorMetExactlySucceeds` | 348 | `200e18` |
| `test_zeroExchangeRateReverts` | 359 | `200e18` |
| `test_zeroMinPhUSDOutDisablesFloor` | 374 | `0` |

Every **non-floor** call site in the file passes `minPhUSDOut == 0` by stated convention (`:65`).
**Not one value in the entire suite lands in `(0, amount]`.**

Consequence: **deleting the guard at `src/Antimatter.sol:260` entirely would leave the suite green
except for the four tests that assert `InsufficientPhUSDOut`** — and *widening* the inert band would
not fail a single test.

**(b) Misnamed test.** `test_zeroExchangeRateReverts` (`:359`) is named for the **rate**, but its
assertion is on the **floor**:

```solidity
/// A zero exchange rate takes the stable half and mints nothing for it, leaving the caller
/// with the antimatter half alone. A caller who stated a floor is protected from that.
function test_zeroExchangeRateReverts() public {
    minter.updateExchangeRate(address(usdc), 0);
    _fund(user, 100 ether, usdc, 100e6);

    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(Antimatter.InsufficientPhUSDOut.selector, 200 ether, 100 ether));
    antimatter.annihilate(address(usdc), user, 100 ether, 200 ether);       // :359-365
}
```

At a zero rate **with the floor waived the call settles** — which the very next test (`:374`)
demonstrates. A reader scanning test names for zero-rate safety finds a **green test asserting the
opposite of the live behaviour**.

**Impact**: none directly — the suite is not deployed. The impact is second-order, and it is the reason
this is filed rather than culled: this suite is **the mechanism by which `M-07` shipped behind a green
69/0 run**, and it is the artifact a future reviewer will consult when deciding whether `M-07`'s fix is
complete. The inert band is not merely untested, it is **untestable by construction from the suite as
written**, so the natural post-fix ritual — land the fix, run `forge test`, see 69 green — proves
nothing.

**Why QA and not Low.** A test suite is not a deployed asset, and the loss it failed to catch is
already carried at Medium as `M-07`. Re-counting the same impact against the suite that missed it would
be double-counting. What earns it a place in the report is defect **(b)**: a green test named
`test_zeroExchangeRateReverts` **positively asserts a safety property the code does not have** — the
falsely-exhaustive-documentation class relocated out of a comment and into a **test name**. The standing
rule that falsely exhaustive in-source documentation *raises* rather than lowers severity is applied
here to stop this being culled as a nitpick, not to manufacture impact.

> **RE-WEIGH CONDITION (binding, severity-classifier).** If `aa6a092cacb3c93c` (`M-07`) is ever marked
> `fixed`, or if any change to `src/Antimatter.sol:260` is proposed as closing it, **`Q-06` MUST BE
> RE-WEIGHED TO LOW before that closure is accepted.** `Q-06` is held at QA only while `M-07` is open
> and independently visible, so a reader misled by the suite can still recover the truth from the
> ledger. The moment `M-07` is closed, the suite becomes the only surviving account of whether the floor
> works — and it is an account that **cannot distinguish a working floor from a deleted one**.

> **CLOSURE BAR ON `M-07` (`aa6a092cacb3c93c`).** `M-07` may be marked `fixed` **only** on evidence of
> a **project** test — in `lib/antimatter`'s own `test/`, **not** `workspace/antimatter/test/audit/**` —
> that passes a floor **strictly inside `(0, amount]`** against a rate below parity and asserts the
> resulting revert. **A green 69/0 run does NOT satisfy this bar and must never be cited as satisfying
> it**: the suite is green today, with the defect live.

**Recommendation**

1. Add a test that passes a floor **inside** the inert band — e.g. `amount == 100e18`,
   `minPhUSDOut == 100e18`, `exchangeRate 6e17` — and assert the intended post-fix behaviour (revert,
   or rejection of a floor that cannot bind). *Today that test would pass while asserting a `160e18`
   settlement, which is itself the demonstration.*
2. Rename `test_zeroExchangeRateReverts` to name what it asserts, e.g.
   `test_zeroRateWithNonZeroFloorRevertsOnTheFloor`, so no reader takes it as evidence that a zero rate
   is guarded.
3. Add a boundary pair at `minPhUSDOut == amount` and `minPhUSDOut == amount + 1`, so the guard's real
   edge is pinned by a test rather than by a proof living outside the repository.

> **Not collapsed into**:
> - `507e375d3ef4abfe` (`Q-04`) — a SAST-noise bucket, not a coverage claim.
> - `aa6a092cacb3c93c` (`M-07`) — one is the defect, the other is why the suite missed it. Collapsing
>   them would let the fix close the tripwire that is supposed to verify the fix.
> - `1b960956475d434a` (`Q-05`, proposed fixed) — `Q-05`'s guard is deleted, but its **false-confidence
>   class has relocated into a test name** and is carried here. Closing `Q-05` must not be read as that
>   class being retired.

---
---

# Carryover — open ledger entries at `3a96fb7`

Every section below is a **full copy** synthesised from the ledger record and re-verified against the
source at `3a96fb7`. All carried from runs 01 and 02, all with `reportPath: null`. Labels, issue IDs and
fingerprints are **the originating run's** and are **not** restamped.

## Carryover — Low Risk

### [L-03] The stable leg can be zero, and the named revert that used to stop it has been deleted — the same lines now settle silently <!-- id: am1l3 -->

**Fingerprint**: `0ed1c6e3270816c5` (`src/Antimatter.sol:annihilateFrom:RoundToZeroStableLegBricksAnnihilation`)
**Status**: `open`. **PROPOSED RE-WEIGH: low → medium.**
**Location**: [`src/Antimatter.sol#L256-L264`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L256-L264) *(run-01: `:232-:233`; run-02: `:234-:235`)*

> **DO NOT PRESENT THIS AS FIXED.** Its named error `PhUSDNotReceived` was **deleted** by this delta, so
> the *stated brick* is gone. The **same lines now settle silently instead of reverting.** A grep that
> finds `PhUSDNotReceived` absent and concludes "fixed" is reading the disappearance of the **alarm** as
> the disappearance of the **condition**.

**What the entry used to say, and the arithmetic correction.** This entry's inherited title — *"a
near-zero `exchangeRate` … the stable leg rounds to zero"* — carries an **arithmetic error that Tier 3
refuted this run**:

> **THERE IS NO NEAR-ZERO ROUNDING BAND.** `mintedForStable == amount * R / 1e18` **exactly**. The
> stable leg is zero only at **`R == 0`** — or on genuine dust, where `amount * R < 1e18`. The
> "amount-dependent heisenbug at a near-zero rate" framing from run-02 is **withdrawn**; it described a
> band that does not exist. Use the corrected arithmetic.

**What the code does now.** At `c91bc1a` a pre-burn guard existed:

```solidity
uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);  // c91bc1a :234
if (expectedForStable == 0) revert PhUSDNotReceived();                         // c91bc1a :235 — DELETED
```

At `3a96fb7` there is no such guard. The path is:

```solidity
uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;              // :256

// The caller's floor, measured against the total both halves come to.
uint256 totalPhUSD = amount + mintedForStable;                                        // :259
if (totalPhUSD < minPhUSDOut) revert InsufficientPhUSDOut(minPhUSDOut, totalPhUSD);   // :260

_phUSD.mint(recipient, amount);                                                       // :263
IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);                      // :264
```

At `R == 0`, `mintedForStable == 0`, and `totalPhUSD == amount`. With the default `minPhUSDOut == 0` —
which the contract's own NatSpec at `:224-225` explicitly permits — the check at `:260` passes, the
antimatter is **burned**, the stablecoin is **pulled and deposited**, and the caller receives **the
antimatter half only**. The stablecoin half is consumed for **nothing**. No revert, no event
distinguishing the case, no diagnostic naming the rate.

**Impact**: at `c91bc1a` this was liveness-only, because the burn could not happen. At `3a96fb7` a
caller who does not supply a floor **loses the stablecoin half outright**, silently. That is a change of
kind, not of degree, and is the basis for the proposed re-weigh.

**Reachability — the narrow, defensible framing.** `exchangeRate` has **no decay, no oracle and no
timestamp** (verified from source: `updateExchangeRate` at `PhusdStableMinter.sol:138` writes no
staleness field and none is read). A stale rate therefore sits at **whatever the owner last wrote**, so
the honest claim is *not* "this needs no owner action at all" — that is too strong, and an auditor will
correctly reject it. The reachable no-further-action case is the **recovery-lag** one: the owner
lowered the rate in response to a depeg, **the stable recovered, and the rate was never restored**. No
new owner action is required for the window to persist, because persistence is the default behaviour of
a value nothing decays.

Note also which direction each finding needs, because they are opposites:

- The **common** staleness direction is **stale-high** — the rate still quotes par after the asset fell.
  That **over-mints**, and it is `L-06`'s direction, not this one's.
- Caller loss here needs **stale-low** (in the limit, `R == 0`): the rate is below what the asset is now
  worth. That is **strictly narrower** than stale-high, and it is stated as narrower rather than
  papered over.

> ### IF THE RE-WEIGH IS APPLIED — DESTINATION, STATED SO THE INSTRUCTION IS ACTIONABLE
>
> **It does NOT become a standalone Medium.** On application it leaves this QA bundle and is published
> as an **APPENDIX TO `submissions/M-07.md`**, carrying its own fingerprint **`0ed1c6e3270816c5`
> verbatim** (never `M-07`'s `aa6a092cacb3c93c`, and never re-derived) so the two stay separately
> reconcilable in the ledger.
>
> **Summaries must read "1 Medium loss channel (2 entries)" — never "2 Mediums".** `M-07` and this
> entry are **one loss channel with two orthogonal mitigations**, and counting them as two Mediums is
> exactly the double-counting the no-double-counting rule forbids. The single channel is *"the caller
> can lose the stablecoin half without the floor stopping it"*; the two orthogonal mitigations are
> **(M-07)** make the floor able to bind below the antimatter half, and **(L-03)** refuse to settle a
> zero stable leg at all. Either alone leaves the other's case live, which is why they are two entries
> rather than one.
>
> **Do not collapse them, either.** `M-07` is about **which floors can bind**; this is about **what
> happens when `R == 0` and no floor was supplied** — a caller who passed `minPhUSDOut == 0`, the
> documented and default-shaped value, is outside `M-07` entirely because there is no floor to be
> inert. Collapsing them would let a fix to one close the other.
>
> Until a human applies the re-weigh via `/ledger`, it stays in this bundle at Low.

`setStablecoinEnabled(false)` already exists as the honest per-stable kill switch, which is why
`rate = 0` reads as a misapprehension rather than an intended mechanism. This is the same
misapprehension documented in ledger `M-04` (`abe4305ac8f0c44f`, `wont-fix`).

**Evidence** (symbolic, not a PoC): `reports/antimatter-01/tier3/halmos-p4-nonzero.txt` — property
REFUTED with a concrete witness. Note that this witness belongs to the **withdrawn** near-zero framing;
the surviving `R == 0` case needs no symbolic reasoning to reach.

**Recommendation**: restore an explicit zero-leg guard with an error that names the actual cause, and
bound `exchangeRate` away from zero at registration/update time:

```solidity
if (mintedForStable == 0) revert StableLegMintedNothing(stable, stableAmount);
```

Failing that, document unambiguously that `minPhUSDOut == 0` at `R == 0` means **giving up the
stablecoin half for nothing** — the NatSpec at `:224-225` says this, but only a caller who reads the
`@param` block will ever see it, and the default value is the unsafe one.

---

### [L-02] Once phUSD and the minter are both wired, the phUSD address can never be changed — the two setters mutually lock <!-- id: am1l2 -->

**Fingerprint**: `5c89b2d372ec9286` (`src/Antimatter.sol:setPhUSD, setPhUSDMinter:MutuallyLockingSetters`)
**Status**: `open` — unchanged at `3a96fb7`.
**Location**: [`src/Antimatter.sol#L136-L158`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L136-L158) *(run-01: `:124-:145`; run-02: `:142-:163`)*

**Description**: The two setters each validate against the other, and there is no ordering of calls that
escapes the pair:

```solidity
if (address(minter) != address(0) && minter.phUSD() != address(newPhUSD)) {
    revert PhUSDMinterMismatch(minter.phUSD(), address(newPhUSD));            // setPhUSD :140-142
}
...
if (newMinter.phUSD() != address(_phUSD)) {
    revert PhUSDMinterMismatch(newMinter.phUSD(), address(_phUSD));           // setPhUSDMinter :153-155
}
```

- `setPhUSD` rejects any address the currently-configured minter does not mint.
- `setPhUSDMinter` rejects any minter that does not mint the currently-configured phUSD.
- `PhusdStableMinter.phUSD` is **immutable**, so the minter cannot be bent to a new phUSD.
- Neither setter accepts `address(0)` (`:138`, `:150`), so neither side can be unwired to break the
  deadlock.

`setPhUSD` — a function whose name advertises a re-pointable address — is effectively **one-way** after
first configuration. This is not documented anywhere.

**Impact**: no funds at risk. But a phUSD redeployment would force a full Antimatter redeployment, and
Antimatter is non-upgradeable with no migration path, so every outstanding antimatter balance would be
lost. This is a **Law-3 footgun**: an owner reading two independent setters would reasonably believe
either can be re-pointed, and would discover otherwise only at the moment a migration is actually needed
— the worst possible time to learn it.

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

### [F-02] The invariant trip-wire `CLAUDE.md` nominates for "never expose a burn" is a four-name denylist, not an invariant check — and it now names one signature that never existed while missing the one that did <!-- id: am1f2 -->

**Fingerprint**: `78612be9264d2b49` (`test/Annihilation.t.sol:test_noPublicBurnEntryPoints:DenylistTestSubstitutedForInvariant`)
**Status**: `open` — **WORSENED by this delta.** Stays **Low**.
**Location**: [`test/Annihilation.t.sol#L451-L468`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/test/Annihilation.t.sol#L451-L468), denylist at `:457-458`.

> **Routing note.** This entry carries an `F-` label from run-01 and has a Law-2 aspect. Unlike `F-01`,
> `F-03`, `F-04` and `F-05`, its ledger record carries **no** spec-conformance-only routing directive,
> and its substance is a **test-suite quality defect** — QA-appropriate. It is carried here at the
> parent's direction; its Law-2 framing is visible in `spec-conformance.md`.

**Description**: The project's nominated invariant — *"never expose a burn"* — is implemented as a
hard-coded list of four function **signature strings**:

```solidity
// The last entry is the two-argument `annihilate(address,uint256)`, a *different* selector
// from the real entry point `annihilate(address,address,uint256,uint256)`. It is here to
// forbid a shortened burn shortcut, not the annihilation function itself.
string[4] memory signatures =
    ["burn(uint256)", "burn(address,uint256)", "burnFrom(address,uint256)", "annihilate(address,uint256)"];  // :457-458

for (uint256 i = 0; i < signatures.length; i++) {
    vm.prank(user);
    (bool ok,) = address(antimatter).call(abi.encodeWithSignature(signatures[i], user, 1 ether));
    assertFalse(ok, signatures[i]);
}
```

A denylist of four names cannot express *"no public burn exists"*. It can only express *"these four
names are not callable"*. Any fifth name — a future `redeem`, `destroy`, `annihilateAll` — passes the
test by existing under a name nobody thought to add.

**Worsened by this delta — second selector change in three stories.** The denylist is now doubly wrong:

- It **still names `annihilate(address,uint256)`**, a two-argument signature that **has never existed in
  this contract at any commit**. The comment at `:454-456` acknowledges this is a deliberate probe for a
  hypothetical shortcut — but it means one of the four slots tests nothing real.
- It **does not name `annihilate(address,address,uint256)`** — the three-argument signature that **did
  exist at `c91bc1a`** and has now been **removed** by story-003's addition of the trailing
  `uint256 minPhUSDOut`. That is a genuinely retired burn entry point, and it is exactly the kind of
  thing this test claims to catch.

The signature has now moved **twice in three stories** (`annihilateFrom` → `annihilate(address,address,uint256)`
→ `annihilate(address,address,uint256,uint256)`), and the denylist tracked neither change. A hand-maintained
list of names is structurally unable to keep up with a function whose signature is still moving.

**Impact**: none to deployed code. The cost is **false confidence**: a green
`test_noPublicBurnEntryPoints` is being read as an invariant proof, and it is not one.

**Complementary evidence**: the dynamic complement of this property *is* covered — the invariant
`invariant_08_supplyOnlyMovesViaMintAndAnnihilation` **passes**. That is the check that actually bears
weight; the denylist is the one that looks like it does.

**Recommendation**: replace the name list with a property that does not depend on knowing the names —
assert over the contract's ABI/selector surface, or lean on
`invariant_08_supplyOnlyMovesViaMintAndAnnihilation` and delete the denylist rather than maintaining a
list that has now been wrong at two consecutive commits. At minimum, remove the phantom
`annihilate(address,uint256)` entry and add the retired `annihilate(address,address,uint256)`.

---

## Carryover — Centralization Risks

### [C-01] `FlaxToken.revokeAllMintPrivileges` silently voids every outstanding antimatter claim, and Antimatter exposes no view of its own authorisation status <!-- id: am1c1 -->

**Fingerprint**: `2a844d32db2eb0f9` (`src/Antimatter.sol:annihilateFrom:UpstreamMintPrivilegeRevocationUnobservable`)
**Status**: `open` — unchanged at `3a96fb7`.
**Location**: [`src/Antimatter.sol#L263`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L263) *(run-01: `:236`; run-02: `:260`)*

**Description**: Antimatter's entire value rests on a mint authorisation held by a **third, independent
principal** — FlaxToken's owner — which is revocable wholesale via the documented global kill switch
`revokeAllMintPrivileges` (`mintVersion++`).

```solidity
// The antimatter half, minted straight to the recipient.
_phUSD.mint(recipient, amount);                                   // :263
```

What makes this a reportable footgun rather than a trusted-owner non-issue (Law 3) is that the condition
is **unobservable**:

1. There is no per-minter event on revocation.
2. There is no view on **either** contract reporting whether Antimatter is currently an authorised,
   current-version minter.
3. Recovery requires `setMinter` on **both** contracts. Re-authorising only `PhusdStableMinter` — the
   obvious one, since ordinary minting visibly resumes — leaves annihilation **silently dead**.
4. Off-chain UIs still see a configured, registered, non-paused system throughout, because
   `toStableAmount` continues to return successfully.

A competent, non-malicious FlaxToken owner reaching for the documented global kill switch would be
surprised to learn it also voids every antimatter claim, and would have **no signal** telling them so.

**Still the last unguarded post-burn dependency.** Run-02 sharpened this entry on the grounds that more
failure modes now execute *before* the burn, leaving the `IFlax` mint as the only post-burn assumption
on the path. **That remains true at `3a96fb7`**: the delta added a floor check at `:260`, which is also
pre-mint, so the `_phUSD.mint` at `:263` is still the last thing on the path that can fail after the
antimatter is already burned at `:239`.

**Impact**: every outstanding antimatter token becomes permanently inert. Antimatter is a reward token
with no purchase price, so no user capital is destroyed — but the entire outstanding **claim** is.

**Likelihood**: low; a deliberate, emergency-scoped action. The finding is about the **silence of the
aftermath**, not the frequency of the trigger.

**Recommendation**:
1. Expose a view on Antimatter reporting whether it is currently an authorised, current-version phUSD
   minter, so the condition is observable without simulating an annihilation.
2. Record the two-contract re-authorisation requirement in the incident runbook, **explicitly naming
   Antimatter as the easy one to forget**.

---

### [C-02] Antimatter has no kill switch of its own — every lever that can halt annihilation belongs to a different principal <!-- id: am1c2 -->

**Fingerprint**: `3a90280bed325637` (`src/Antimatter.sol:annihilateFrom:NoLocalPauseAuthority`)
**Ledger band**: `qa` (kept in this section for topical grouping; it carries QA weight, not Low weight)
**Status**: `open` — unchanged at `3a96fb7`.
**Location**: [`src/Antimatter.sol#L226`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L226) *(run-01: `:201`; run-02: `:221`)*

**Description**: Antimatter is not `Pausable` and exposes no owner lever to halt annihilation:

```solidity
function annihilate(address stable, address recipient, uint256 amount, uint256 minPhUSDOut) external nonReentrant {  // :226
```

Stopping it requires one of:

- `PhusdStableMinter`'s pauser or owner,
- `FlaxToken`'s owner, or
- the yield strategy's owner

— all principals independent of `Antimatter.owner()`, with nothing requiring them to be the same party.
The only *fast* lever, `FlaxToken.revokeAllMintPrivileges`, is global and causes collateral damage: it
silently de-authorises `PhusdStableMinter` too (see `C-01`).

This is an operational observation, **not** a malicious-owner finding: no owner needs to misbehave for
the incident-response path to be missing.

**Impact**: no direct asset impact — incident-response capability only. If a defect is found in
Antimatter itself, its own owner cannot stop it. This run's `M-07` is a fresh demonstration that *"a
defect exists in Antimatter"* is not a hypothetical premise.

**Why only QA**: the composition is arguably deliberate — Antimatter keeps no stablecoin list of its own
and defers control to the minter by design. The gap is in the runbook as much as in the code.

**Multiplied by `C-03`**: the single owner key that would hold any such lever also has no two-step
transfer.

**Recommendation**: either document the incident-response runbook (who to call, in what order), or add
an owner-settable `annihilationPaused` flag checked at the top of `annihilate`, so the contract's own
owner holds a proportionate, non-global lever.

---

### [C-03] Antimatter inherits single-step OpenZeppelin `Ownable` rather than `Ownable2Step` <!-- id: am2c3 -->

**Fingerprint**: `2e9152785e3dc975` (`src/Antimatter.sol:(inherited Ownable):SingleStepOwnershipTransfer`)
**Ledger band**: `qa` (kept in this section for topical grouping)
**Status**: `open` — unchanged at `3a96fb7`.
**Location**: [`src/Antimatter.sol#L8`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L8), [`#L22`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L22)

```solidity
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";   // :8
...
contract Antimatter is ERC20, Ownable, ReentrancyGuard {              // :22
```

Antimatter inherits single-step OpenZeppelin `Ownable`; consider `Ownable2Step`.

Combined with `C-02` (`3a90280bed325637`, no local pause authority), **every incident lever the protocol
has runs through one owner key whose transfer has no undo.**

**Not a regression, and not introduced by any delta.** Verified in run-02: `Ownable` traces to the
repository's initial commit `a94fd72`, and neither `0bb82d8..c91bc1a` nor `c91bc1a..3a96fb7` touches the
import at `:8` or the inheritance at `:22`. `origin: new` on the ledger entry means *new to the ledger*,
not *new to the code*. Any downstream stage that files it as a regression is wrong.

**Recommendation**: inherit `Ownable2Step` so ownership transfer requires the incoming owner to call
`acceptOwnership`. One-line change, no behavioural cost, and it composes with the incident-response
runbook `C-02` already asks for.

> **Deliberately narrow.** The mistyped-`transferOwnership` narrative was **stripped**: that consequence
> is obvious, no competent owner is surprised by it, and it therefore fails the Law-3 surprise test and
> hits the reckless-admin carve-out. Declining that escalation does not license withholding the finding
> (Law 1 forbids that), which is why the structural observation survives at QA. Source: 4naly3er L-2 /
> L-12, re-raised again this run (Appendix A) — a common automated-tool finding, which C4 discounts **as
> a severity ceiling only, never as a suppression**. A reasonable `/ledger` triage outcome is
> `wont-fix`; that is a human call.

---

## Carryover — QA / Non-Critical

### [L-01] `mintedForStable` is an unattributed balance delta — **RE-ARMED**: the exact-equality check that neutralised it has been deleted, and mid-call phUSD injection is again counted and forwarded to a caller-chosen recipient <!-- id: am1l1 -->

**Fingerprint**: `ad4b779566291190` (`src/Antimatter.sol:annihilateFrom:BalanceDeltaMistakenForAttribution`)
**Status**: `open` — **RE-ARMED THIS RUN. PROPOSED RE-WEIGH: qa → low.**
**Location**: [`src/Antimatter.sol#L244-L264`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L244-L264) *(run-01: `:220-:237`; run-02: `:244-:257`)*

> **DO-NOT-CLOSE marker (from run-02) REMAINS BINDING.** It was binding through a re-wording and a
> human-authorised downgrade, and the event this run is the **opposite** of a fix.

**Root cause — unchanged since run-01, byte for byte.** The stable leg is measured as a balance delta
across the mint call, and that delta is attributed to the caller-chosen recipient regardless of who
actually sent the phUSD:

```solidity
uint256 phUSDBefore = _phUSD.balanceOf(address(this));                    // :244
...
minter.mint(stable, stableAmount);                                        // :251
...
uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;  // :256
...
IERC20(address(_phUSD)).safeTransfer(recipient, mintedForStable);         // :264
```

**What changed — the neutralising check is gone.** At `c91bc1a` the window `[:244, :256]` was closed by:

```solidity
uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);              // c91bc1a :234
...
if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(...);                 // c91bc1a :257 — DELETED
```

That exact-equality post-condition was **the only thing** turning a mis-forward into a revert. story-003
removed it and replaced it with the caller-supplied floor at `:260`, which compares the total against a
**minimum** and therefore does not care that the total is **too large**.

**Impact — reverted to the run-01 value leak.** phUSD arriving on Antimatter inside `[:244, :256]` is
again **counted as this annihilation's stable leg and forwarded** to the caller-chosen recipient at
`:264`. **Re-proved live at this HEAD**: 500e18 injected from the stablecoin's transfer hook; the
annihilator received **700e18** instead of 200e18.

**Related effect — the floor is not a guarantee about phUSD minted for the pair.** Because injected
phUSD inflates `mintedForStable`, it inflates `totalPhUSD` at `:259` and can push a caller's
`minPhUSDOut` **over the line** at `:260`. So a passing floor check does **not** establish that the
protocol minted that much phUSD *for this pair*; it establishes only that that much phUSD *arrived*.
Any reading of `minPhUSDOut` as a statement about the exchange rate the caller received is unsound while
the delta is unattributed.

**Reachability — the run-02 correction still applies and is not withdrawn.** Control genuinely does leave
the contract inside the window: `safeTransferFrom` (`:246`), `forceApprove` (`:247`) and `minter.mint`
(`:251`, which itself reaches the yield strategy). **No hook on Antimatter and no re-entry is required**
— `nonReentrant` guards **re-entry into `annihilate`**, not an **outbound** `phUSD.transfer(antimatter, x)`
by a callee holding control. But **exactly three actors get execution in that window — the `stable`
token, the minter, and the yield strategy — and all three are owner-configured.** An unprivileged
attacker gets **no execution at all**: a donation *before* the call is baselined out by the `:244`
snapshot, and a donation *after* `:256` is irrelevant. No front-run or sandwich reaches inside the
interval.

**Why the proposed re-weigh qa → low, and not higher.** The human downgrade to QA on 2026-08-20 rested
on *"no permissionless vector"* **and** on the marginal-capability deflator — a hostile registered token
could brick its own pair more cheaply by reverting `transferFrom`. The first premise still holds. **The
second no longer does**: the deflator applied when the symptom was an *availability brick* (a capability
the token already had). The symptom is now **value extraction to a caller-chosen recipient**, which
reverting `transferFrom` does **not** achieve. The capability is no longer marginal, so the QA band no
longer fits; Low does. It is not proposed above Low because the reachability finding is unchanged — the
trigger-holder is still an owner-configured actor, not the public.

**Sub-defect (unchanged)**: when Antimatter's phUSD balance *decreases* within the window — a mid-call
phUSD **departure** — the subtraction at `:256` underflows into a bare `Panic(0x11)` rather than a named
error. Same reachability caveat.

**Law-3 verdict**: footgun, **in scope**. A competent owner registering a hook-bearing token would not
connect *"this token moves phUSD on transfer"* with *"annihilators can be over-paid out of protocol
mint"*.

**PoC** (audit-authored — see provenance note):
`workspace/antimatter/test/audit/Tier2b.t.sol`, `Tier2Delta.t.sol`
- `test_midCallPhUSDInjectionIsForwardedToRecipient` — the value leak. **Passing at `0bb82d8` and again
  at `3a96fb7`** (500e18 injected, annihilator received 700e18).
- `test_preExistingPhUSDDonationIsNotSwept` — control: a pre-call donation *is* correctly excluded by the
  `:244` snapshot and remains stuck (owner-recoverable via `rescueERC20`). **Passing.**
- `test_midCallPhUSDInjectionNowReverts` — the run-02 brick behaviour. **No longer applicable at
  `3a96fb7`**; the error it expects no longer exists.

**Recommendation**: **attribute rather than measure.** Credit the recipient with the minter's own quoted
amount and use the balance delta only as an assertion that nothing unexpected happened, with a named
error for the underflow:

```solidity
uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);
uint256 balanceNow = _phUSD.balanceOf(address(this));
if (balanceNow < phUSDBefore) revert PhUSDBalanceDecreased(phUSDBefore, balanceNow);
uint256 delta = balanceNow - phUSDBefore;
if (delta < expectedForStable) revert PhUSDShortMint(expectedForStable, delta);
// pay out expectedForStable, not the measured delta; sweep any excess to the owner
```

Note the `<` rather than `!=`: it catches a **short mint** without turning an **over-arrival** into a
brick, and paying out `expectedForStable` rather than `delta` removes the forwarding channel entirely.
Restoring the deleted `!=` check would close the leak but re-open run-02's availability defect; this
form closes both.

---

### [Q-01] `toStableAmount` is a decimals-only rescale and is not a phUSD preview; the local `decimals` also shadows `ERC20.decimals()` <!-- id: am1q1 -->

**Fingerprint**: `8c2dcc57bcd3be05` (`src/Antimatter.sol:toStableAmount:MisleadingHelperNamingAndShadowing`)
**Status**: `open` — both halves survive verbatim at `3a96fb7`.
**Location**: [`src/Antimatter.sol#L283-L304`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L283-L304) *(run-01: `:246-:257`; run-02: `:280-:301`)*

**(a) Missing preview.** `toStableAmount` is the only public preview on the annihilation path, and it
ignores `exchangeRate` entirely — it is a pure decimals rescale. The phUSD actually delivered is
`amount + floor(amount * exchangeRate / 1e18)`. At any rate other than `1e18`, an integrator deriving an
expected payout from this function is wrong on the stable leg.

The asymmetry itself is by design and internally coherent (stable leg priced at rate, antimatter leg
always at 1). The QA item is the **absence** of a matching phUSD-side preview, which leaves
`toStableAmount` looking like one.

**(b) Shadowing.** The local `decimals`, destructured from `minter.stablecoinConfigs(stable)` at `:287`,
shadows the inherited `ERC20.decimals()` / `IERC20Metadata.decimals()`, and surfaces in an ABI-visible
signature — `DecimalsMismatch(address,uint8,uint256)` at `:298` — where an integrator decoding the revert
meets the shadowing name directly.

**Aggravated, and now aggravated twice over.** The NatSpec at `:281-282` still positively endorses the
misreading this entry warns about:

```solidity
///      Off-chain callers using this as a quote helper therefore depend on `stable` being
///      responsive.                                                              // :281-282
```

**And this delta makes the gap materially worse**: story-003 added `minPhUSDOut`, a parameter whose own
NatSpec at `:222-223` instructs the caller to *"Compute it off chain"* — while the contract still exposes
**no preview that can compute it**. `toStableAmount` returns a quantity of `stable`, not a quantity of
phUSD. The one public helper an integrator would reach for to size a slippage floor is the one helper
that cannot size it.

In-source NatSpec carries **no suppression authority** on this project and, where falsely exhaustive,
**raises** rather than lowers severity. Recorded on this entry rather than filed fresh. No escalation
above QA is proposed; status unchanged.

**Recommendation**:
- Add a real preview and document `toStableAmount` as the input-side rescale only:
  ```solidity
  function previewAnnihilate(address stable, uint256 amount)
      external view returns (uint256 stableAmount, uint256 phUSDOut);
  ```
  composing `minter.calculateMintAmount`. Then correct the `:281-282` NatSpec to point at it, and point
  `minPhUSDOut`'s *"Compute it off chain"* at it too.
- Rename the local to `stableDecimals`.

*Note*: the economic consequence of an unbounded, un-timelocked `exchangeRate` is `DEDUP-005` /
`L-06` territory and is deliberately not re-adjudicated here.

---

### [Q-02] `recipient` is guarded against `address(0)` but not against `address(this)` — an annihilation can come to rest on the contract <!-- id: am1q2 -->

**Fingerprint**: `c330566040a453ea` (`src/Antimatter.sol:annihilateFrom:RecipientSelfAddressUnguarded`)
**Status**: `open` — unchanged at `3a96fb7`; line references moved.
**Location**: [`src/Antimatter.sol#L228`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L228) *(run-01: `:203`; run-02: `:223`)*

**Description**:

```solidity
if (recipient == address(0)) revert RecipientZeroAddress();     // :228 — rejects zero, accepts address(this)
```

`:263` then mints `amount` phUSD to Antimatter and `:264` transfers `mintedForStable` from Antimatter to
itself, so the full ~2x payout settles on the contract with the antimatter **already burned** at `:239`.

**Impact**: self-inflicted caller error with no attacker gain. Mitigating facts: the phUSD is recoverable
by the owner via `rescueERC20` (`:309`), and a later annihilation's `phUSDBefore` snapshot at `:244`
correctly excludes it, so it is not swept to the next annihilator (control-tested under `L-01`). No
partial settlement state is created.

**Note on the new floor**: `minPhUSDOut` provides **no** protection here. The floor at `:260` is checked
before the payout and passes normally; the phUSD is then delivered to `address(this)`. A caller who
carefully computed a floor still loses everything to their own typo.

**PoC** (audit-authored): `workspace/antimatter/test/audit/Tier2b.t.sol`
- `test_recipientSelfStrandsPhUSD` — 200e18 phUSD settles on the Antimatter contract, antimatter already
  burned. **Passing.**

**Recommendation**: `address(this)` is exactly as cheap to reject as `address(0)`.

```solidity
if (recipient == address(0)) revert RecipientZeroAddress();
if (recipient == address(this)) revert RecipientSelfAddress();
```

---

### [Q-03] `approvedMinters()` copies the whole `EnumerableSet` to memory with no bound <!-- id: am1q3 -->

**Fingerprint**: `0174ea0bd59a9b12` (`src/Antimatter.sol:approvedMinters:UnboundedSetCopyInView`)
**Status**: `open` — unchanged at `3a96fb7`.
**Location**: [`src/Antimatter.sol#L187-L189`](https://github.com/Behodler/antimatter/blob/3a96fb7de072b29515986f92282cdece7b12d4ca/src/Antimatter.sol#L187-L189) *(run-01: `:174`; run-02: `:192`)*

```solidity
/// @notice The full approved minter set.
function approvedMinters() external view returns (address[] memory) {
    return _approvedMinters.values();                                  // :188
}
```

**Description**: `EnumerableSet.values()` is unbounded. This is an external view, so no on-chain caller
is forced through it today, but it will gas-out for an off-chain reader once the set grows large, and any
future on-chain consumer inherits the unbounded loop.

**Recommendation**: paginate, or keep `approvedMinterAt` / `approvedMinterCount` (`:182`, `:177`) as the
supported iteration path and document `values()` as off-chain-only.

> **Triage note — likely triage-death.** The approved-minter set is expected to hold a handful of
> entries, so the growth premise may simply never hold. Recorded rather than deleted so the dismissal is
> a **visible** decision.

---

### [Q-04] Static-analysis findings in audit-harness and mock files (`test/**`) <!-- id: am1q4 -->

**Fingerprint**: `507e375d3ef4abfe` (`test/**:multiple:ToolNoiseInTestHarness`)
**Status**: `open` — unchanged. Instance counts grew again with story-003's floor tests. This is **test
growth**, not a regression and not a widening defect. No escalation.
**Location**: `test/**` — test and mock files only. **No production contract is implicated.**

**Description**: Slither and Aderyn raise the following in test-harness and mock files. They are recorded
for completeness and are **explicitly not being presented as protocol issues**:

| ID | File | Detail |
|----|------|--------|
| SA-011 | `test/Antimatter.t.sol` (`test_transfer`) | Return value of `antimatter.transfer(stranger, 4e18)` ignored. Slither `unchecked-transfer` + Aderyn `unsafe-erc20-operation` / `unchecked-return` at the same line. |
| SA-012 | `test/Annihilation.t.sol` | `approve()` / ERC20 return values ignored across `_fund` and several negative tests. Corroborated by Aderyn at identical lines. |
| SA-013 | `test/mocks/ReentrantStable.sol` (`:16-17`) | Address state variables assigned in constructor/setter without zero-check. |

4naly3er's run-03 pass adds the same class in bulk — see Appendix A, where the great majority of the
190 `GAS-5`, 139 `NC-4` and 93 `L-10` instances land in `test/**` and `test/mocks/**`.

**Impact**: none. These are audit-harness and mock files.

**Recommendation**: none required. If desired, use `SafeERC20` in test helpers for consistency.

> **Triage note — likely triage-death, and deliberately not inflated.** This entry exists so the
> automated tools' output is **accounted for rather than silently discarded**. It should not be read as
> hundreds of findings' worth of signal; it is a handful of clusters of tool noise in non-production
> code. **It is not, and must not be read as, a coverage claim about the test suite** — that is `Q-06`,
> which is a different thing entirely.

---

## Carryover — status-only entries

Two carryover entries describe **code that no longer exists**. Their sections are recorded here so
neither disappears, but neither is presented as a verified fix.

### [Q-05] The exact-equality quote check that this entry described has been **deleted** — PROPOSED FIXED, moot by deletion <!-- id: am2q5 -->

**Fingerprint**: `1b960956475d434a` (`src/Antimatter.sol:annihilate:MisleadingGuardFramingOverstatesCoverage`)
**Status**: `open` on the ledger. **PROPOSED `fixed` — MOOT BY DELETION, NOT A VERIFIED FIX.**

`Q-05` reported that the comment at `c91bc1a:232-233` and the error name `PhUSDAmountMismatch` presented
the exact-equality check as protection against being short-changed, when it was not a slippage or
minimum-output guard. **story-003 deleted the entire construct**: `calculateMintAmount`,
`expectedForStable`, `PhUSDAmountMismatch` and the `!=` post-condition are all absent at `3a96fb7`
(verified against the contract's full error list). There is no misleading comment left to mislead anyone,
because there is no check left.

> **This is a disposal by deletion, not a fix.** Nobody corrected the comment or renamed the error; the
> code it described was removed for an unrelated reason. It is proposed `fixed` on that basis and a human
> should apply it knowing the distinction — a future re-introduction of a quote check would not be a
> regression against a repaired guard, it would be new code needing fresh review.

> **RESIDUE — THIS TRAVELS, IT DOES NOT DIE WITH `Q-05`.** The one observation `Q-05` made that is
> **still true at `3a96fb7`** is that **a floor of `[1, amount]` waives protection as completely as `0`
> does.** That residue is carried on **`M-07`** (`aa6a092cacb3c93c`, `submissions/M-07.md`), which is
> exactly the finding about the floor's inert band. It is **not** carried on `Q-05`, and closing `Q-05`
> must not be read as retiring it.

> **`Q-05`'s false-confidence CLASS also survives**, relocated from a code comment into a **test name** —
> carried on **`Q-06`** above. See `Q-06`'s not-collapsed-into note.

> **`Q-05`'s FALSE-CLOSURE BLOCK on `F-01` (`3aac91383dcb6060`) is NOT discharged by this.** `F-01` is
> `fix-pending` — a fix is **owed** — and is adjudicated in the spec-conformance / incomplete-fix
> channel, not here. The `WATCH-02-02` attestation stands: `F-01` requires evidence of a
> **caller-supplied minimum-output parameter**. story-003 has now **added** one (`minPhUSDOut`), so
> `F-01`'s closure is live and genuinely arguable for the first time — **but `M-07` reports that the
> parameter it added is inert for every floor at or below the antimatter half.** Whether that satisfies
> `F-01` is a spec-conformance judgement and is **not** made in this document.

### [F-04] The settlement post-condition this entry reported as unstoried has been **deleted** — PROPOSED FIXED, moot by deletion <!-- id: am2f4 -->

**Fingerprint**: `d34180996ba41ff8` (`src/Antimatter.sol:annihilate:UnstoriedBehaviouralChangeToSettlementPath`)
**Status**: `open` on the ledger. **PROPOSED `fixed` — MOOT BY DELETION, NOT A VERIFIED FIX.**

**BODY ROUTED ELSEWHERE.** This ledger entry carries a binding routing directive — *"ROUTED TO
`submissions/spec-conformance.md` ONLY — NEVER THE QA BUNDLE, AT ANY BAND"* — because Law 2 is a routing
law before it is a severity law. Its full text is in `submissions/spec-conformance.md`. **Only its status
is recorded here**, so that a reader of the QA bundle does not find it simply missing.

In one line: `F-04` reported that the untagged commit `c91bc1a` (*"more precise mint requirement"*)
rewrote the phUSD settlement post-condition with no story authorising it, while story-001's acceptance
checklist line 198 still self-certified that the assertion had been preserved. **story-003 has now
deleted that post-condition outright.** The unstoried code is gone; the **process** finding — a closed
story self-certifying a property the code did not have — is a Law-2 matter and is adjudicated in the
spec-conformance report, where the run-03 entry `F-05` covers the same class on story-003's own
acceptance record.

---
---

## Appendix A — Automated report (4naly3er)

> **THIS APPENDIX IS AUTOMATED TOOL OUTPUT. It is not a reasoned finding and nothing in it has been
> adjudicated, deduplicated against the ledger, or severity-classified.** It is attached because
> 4naly3er is the C4-standard automated QA/gas baseline and the Low/QA section is expected to carry it.
> Tool severities (`L-n`, `M-n`, `NC-n`, `GAS-n`) are **4naly3er's own labels** and have **no relation**
> to this report's `L-XX` / `C-XX` / `Q-XX` labels or to C4 severity. Do not cite an item from this
> appendix as an audit finding.

**Generated this run** over all **6** in-scope first-party files at commit
`3a96fb7de072b29515986f92282cdece7b12d4ca`. **Not re-run for this bundle** — the artifact is
`reports/antimatter-03/tier1/4naly3er-report.md` and is attached standalone as
**`reports/antimatter-03/submissions/4naly3er-report.md`** (3,135 lines).

### Results at a glance

| Category | Issue types | Notes |
|---|---:|---|
| Gas Optimizations (`GAS-1`…`GAS-12`) | 12 | Style/gas only. Dominated by `GAS-5` (190 instances) and `GAS-8` (54) — the great majority in `test/**`. |
| Non Critical (`NC-1`…`NC-23`) | 23 | Style/documentation. `NC-4` (139) and `NC-22` (71) dominate. |
| Low (`L-1`…`L-15`) | 15 | See below. |
| Medium (`M-1`, `M-2`) | 2 | Neither promoted — see below. |

### Which tool items are already adjudicated in this report

| Tool item | Disposition |
|---|---|
| `L-2` "Use a 2-step ownership transfer pattern" (1), `L-12` "Use `Ownable2Step.transferOwnership`" (3) | **Promoted** — this is carryover `C-03` (`2e9152785e3dc975`). Automated-tool provenance applies as a **severity ceiling only**, never as a suppression. |
| `L-5` "`decimals()` is not part of the ERC-20 standard" (1) | Corroborates the `toStableAmount` metadata dependency already carried by acknowledged `L-05` (`3a8dbad19ba9104e`). Not re-filed. |
| `L-7` "Division by zero not prevented" (1) | The `10 ** (18 - decimals)` scale at `:300`; guarded by `if (decimals > 18) revert UnsupportedDecimals` at `:289`. **Not a defect.** |
| `L-1`, `L-6`, `L-15` (approve/unsafe ERC20) | The `forceApprove` pattern at `:247`/`:253` is the correct one; remaining instances are `test/**` and belong to `Q-04`. |
| `L-10` "Prevent accidentally burning tokens" (93) | Overwhelmingly `test/**` and mocks. `Q-04`. |
| `L-4`, `L-13`, `L-14`, `L-3`, `L-8`, `L-9`, `L-11` | Generic; no first-party defect established. Recorded, not promoted. |
| `M-1` "Contracts are vulnerable to fee-on-transfer accounting" (2) | **NOT promoted.** Adjudicated **INVALID** in run-02: the settlement path fails closed on two independent legs (`StableNotDeposited` at `:254`, and the measured stable balance). Fee-on-transfer is additionally a C4 known-invalid unless explicitly in scope. Kept out of the ledger on that basis rather than filed and triaged away. |
| `M-2` "Centralization Risk for trusted owners" (6) | **NOT promoted as such.** Law 3: the owner is trusted for knowing actions, and a generic "owner has privileges" listing is exactly the noise that rule exists to suppress. The **non-obvious** owner footguns in this class are filed on their merits as `C-01`, `C-02`, `C-03` and `L-06`. |

The full generated report — every instance, verbatim — is
`reports/antimatter-03/submissions/4naly3er-report.md`.

### Semgrep — stated explicitly so nobody reads silence as coverage

Semgrep contributed **no security coverage this run**: **40 of 40** results were **INFO-level style and
performance rules**, zero WARNING, zero ERROR. `p/smart-contracts` contains no Solidity vulnerability
detectors. Nothing in this bundle, and nothing in this appendix, should be read as implying Semgrep
cleared anything.

---

## Index of every entry named in this document

| Label | Issue ID | Fingerprint | Where |
|---|---|---|---|
| L-06 | `am3l6` | `6ce80dacbcf6d566` | **this bundle**, Low (new) |
| Q-06 | `am3q6` | `4ab41ae7b5b220a0` | **this bundle**, QA (new) |
| L-01 | `am1l1` | `ad4b779566291190` | **this bundle**, carryover QA — re-armed, proposed qa → low |
| L-02 | `am1l2` | `5c89b2d372ec9286` | **this bundle**, carryover Low |
| L-03 | `am1l3` | `0ed1c6e3270816c5` | **this bundle**, carryover Low — proposed low → medium; on application it publishes as an **appendix to `submissions/M-07.md`** carrying `0ed1c6e3270816c5` verbatim. **1 Medium loss channel (2 entries)**, never 2 Mediums. |
| F-02 | `am1f2` | `78612be9264d2b49` | **this bundle**, carryover Low — worsened |
| C-01 | `am1c1` | `2a844d32db2eb0f9` | **this bundle**, carryover Centralization |
| C-02 | `am1c2` | `3a90280bed325637` | **this bundle**, carryover Centralization |
| C-03 | `am2c3` | `2e9152785e3dc975` | **this bundle**, carryover Centralization |
| Q-01 | `am1q1` | `8c2dcc57bcd3be05` | **this bundle**, carryover QA |
| Q-02 | `am1q2` | `c330566040a453ea` | **this bundle**, carryover QA |
| Q-03 | `am1q3` | `0174ea0bd59a9b12` | **this bundle**, carryover QA |
| Q-04 | `am1q4` | `507e375d3ef4abfe` | **this bundle**, carryover QA |
| Q-05 | `am2q5` | `1b960956475d434a` | **this bundle**, status-only — proposed fixed (moot by deletion); residue on `M-07`, class on `Q-06` |
| F-04 | `am2f4` | `d34180996ba41ff8` | status-only here; **body in `spec-conformance.md`** — proposed fixed (moot by deletion) |
| M-07 | `am3m7` | `aa6a092cacb3c93c` | **`submissions/M-07.md`** — carries `Q-06`'s closure bar |
| F-05 | — | — | **`submissions/spec-conformance.md`** |
| F-03 | `am1f3` | `9d06644ddad24e5a` | **`submissions/spec-conformance.md`** |
| F-01 | `am1f1` | `3aac91383dcb6060` | **`submissions/spec-conformance.md`** / incomplete-fix channel — `fix-pending`, never suppressed |
| L-04 | `am2l4` | `25088b59893f37e0` | not carried — `acknowledged` |
| L-05 | `am2l5` | `3a8dbad19ba9104e` | not carried — `acknowledged` |
| M-04 | `am1m4` | `abe4305ac8f0c44f` | not carried — `wont-fix`; **disclosed verbatim inside `L-06` (WFD-01)** |
