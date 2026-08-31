# Historical-Pattern Match — reflax-yield-vault run 17 @ `cdd0743`

- **Project**: reflax-yield-vault · **Commit**: `cdd0743` `[story-050] GREEN: previewExitFor on IYieldStrategy…`
- **Pattern DB**: `/home/justin/code/audits/patterns/vulnerability-patterns.json` **v1.1, 35 patterns** (all 35 loaded and checked)
- **Scan type**: `pattern-matching` (Tier 1) · **Scan date**: 2026-08-31
- **Inputs consumed, NOT re-derived**: `contract-profiles.md`, `story-faithfulness.md` (F-01-050, F-02-050),
  `static-analysis.md` (SA-001…SA-021), `code-scan.md` (CODE-01…CODE-07).
- **Ledger consulted**: `reports/reflax-yield-vault/ledger.json`, 49 entries.

New evidence authored for this pass lives at
`/home/justin/code/audits/workspace/reflax-yield-vault/test/poc-run17-pattern-match.t.sol`
(4 tests, **4 passed**):

```
forge test --match-path test/poc-run17-pattern-match.t.sol -vv
```

Nothing in `lib/` was modified. The 30 pre-existing untracked artifacts in `workspace/` were preserved.

---

## 1. Pattern hits on the established findings

Every established finding is **classified, not re-filed**. Where a pattern match changes how the
finding should be weighed, that is stated explicitly.

### F-01-050 → `YIELD-PRINCIPAL-ACCOUNTING-SKEW` (HIGH) — **match strengthens; and the proposed remedy does not close the class**

The pattern's `vulnerableWhen` bullet 2 is verbatim the F-01 condition:

> "withdraw allowed while `totalBalanceOf < principalOf` (underwater) forcing loss onto non-exiting users"

and its `note` names this exact code: *"stable-staker + reflax-yield-vault strategy routing"*.
Four of the six `codeSignatures` (`totalBalanceOf`, `principalOf`, `yieldStrategy`, `skimSurplus`)
are present in `src/AYieldStrategy.sol`. **Match strengthens F-01-050**: the catalogued severity is
HIGH, which supports the story-faithfulness note that F-01 escalates to Medium the moment a consumer
is wired, and argues against letting it settle at Low permanently.

**Load-bearing addition (probe `testPM3_DirectPreviewOverQuotesOnExitFeeVault`, PASS).** F-01-050
proposes, as its stronger remedy, *"make the base default share-aware — cap `netGuaranteed` by the
underlying value of the shares actually held, which is what `_positionValue()` already exposes"*.
That remedy does **not** close the class, because `_positionValue()` is built on the same fee-blind
conversion:

```solidity
// src/concreteYieldStrategies/ERC4626YieldStrategy.sol:61-63
function _positionValue() internal view override returns (uint256) {
    return vault.convertToAssets(vault.balanceOf(address(this)));
}
```

Against a spec-compliant exit-fee vault (5% redeem fee; `convertTo*` fee-blind exactly as ERC4626
mandates), the probe measures:

```
previewExitFor netGuaranteed: 1000000000000000000000
previewRedeem (fee-aware)   :  950000000000000000000
_positionValue (fee-blind)  : 1000000000000000000000
actually delivered          :  950000000000000000000
```

`assertEq(posValue, net)` passes — the proposed cap is numerically identical to the number it was
meant to correct. Any fix must read a fee-aware quote, not `_positionValue()`.

The same probe surfaces a **self-contradiction inside one contract**: `ERC4626YieldStrategy` already
exposes an honest, fee-aware exit quote —

```solidity
// src/concreteYieldStrategies/ERC4626YieldStrategy.sol:83-85
function previewRedeem(uint256 shares) external view returns (uint256 assets) {
    return vault.previewRedeem(shares);
}
```

— and story-050 deliberately forbade `previewExitFor` from using it (story criterion 10, STATICCALL
safety). The contract therefore now ships **two exit previews that disagree by the vault's exit fee**,
with the *newer* one carrying the word "guarantees".

**Ledger reconciliation.** This is the same root cause as open ledger entry
**`ECON-A` / `c50c08f9ee587c02e38e089dd7aa2ee3ae64a9623bb1e6f1d138154b21fc7887`** (Low, **open**) —
*"ERC4626YieldStrategy credits principal via fee-blind convertToAssets, persistently over-stating
redeemable NAV"* — extended to a **new surface** (`previewExitFor`'s stated guarantee) and to a
**new consequence** (a documented delivery floor that delivery breaches). Treat as a scope extension
of `ECON-A`, **not** a new finding and **not** a duplicate to be dropped. Related open entries:
`L-11` (*"totalBalanceOf and principalOf use different data sources"*) and `F-16-003`.

### CODE-01 → `YIELD-PRINCIPAL-ACCOUNTING-SKEW` (HIGH) — **match strengthens**

CODE-01's mechanism is the pattern's `vulnerableWhen` bullet 1 plus bullet 2 acting together:
principal is decremented by the REQUESTED amount

```solidity
// src/AYieldStrategy.sol:780-783
// Decrement by the REQUESTED (capped) amount, not what was received — shortfall accrues as yield.
clientBalances[token][balanceHolder] -= amount;
totalDeposited[token] -= amount;
```

while the global share cap in `_exitFloor` (`ERC4626MarketYieldStrategy.sol:127-135`) means two
clients are quoted 1.96x the position. The pattern's `notVulnerableWhen` bullet 1 ("shortfall
explicitly accrues to protocol-owned surplus (documented rounding rule)") **is** satisfied by the
comment above — which is why the *decrement* leg alone is not a finding — but bullet 2 ("withdraw
reverts while strategy underwater") is **not** satisfied, so the mitigation is partial. **Match
strengthens CODE-01.**

**Ledger recurrence (in-project).** Ledger entry **`M-03`** — *"Requested-not-received decrement
socialises slippage, causing last-withdrawer shortfall"*, Medium, status **`merged`** — is the same
class on the `withdraw` path. CODE-01 is that class **reborn on the quote surface**: the defect is no
longer only that the last withdrawer is short, but that the protocol now hands each of them a
document saying they will not be. Do not collapse CODE-01 into `M-03`: `M-03` is disposed as merged
and its fingerprint does not cover `previewExitFor`.

### CODE-02 → **no catalogued pattern**; nearest is `TWO-STEP-COMMIT-WINDOW` (MEDIUM, partial) — **and a prior false-positive must NOT be used to kill it**

`MISSING-SLIPPAGE` is the natural first guess and is **REFUTED**: `minOut` is present and enforced
(`ERC4626MarketYieldStrategy.sol:250`), which is precisely *why* CODE-02 is a revert rather than an
under-delivery. The nearest catalogued shape is `TWO-STEP-COMMIT-WINDOW`, whose `vulnerableWhen`
bullet 1 generalises exactly:

> "step 2 re-reads a live value instead of the value snapshotted at step 1"

`previewExitFor` (step 1) is quoted from vault state; `withdraw` (step 2) re-reads live AMM state that
step 1 could not see at all. That is an **analogical, medium-confidence** match — the pattern is
written for setter windows, and the DB has **no pattern for quote-versus-execution divergence**. See
§4 for the new-pattern proposal.

**Critical de-confliction (Law 1).** Ledger entry
**`M-02` / `d7f6c2dfd580776dd3193942b89806b893ac95ff56a752a5e5bd7c501cb41416`** — *"NAV-anchored
minOut is execution-price-blind, enabling sandwich value leak"* — is triaged **`false-positive`**, and
its surface overlaps CODE-02's almost word for word. **They are different claims and CODE-02 survives
`M-02`'s refutation:**

| | `M-02` (false-positive) | CODE-02 (run-17) |
|---|---|---|
| Claim | NAV-anchored `minOut` lets a sandwicher **extract value** | NAV-anchored floor makes the **new preview report green while `withdraw` is guaranteed to revert** |
| Harm | value leak | liveness / false pre-flight signal |
| Refuted by | concentrated-liquidity pool, no valid sandwich (memory `reflax-yield-vault-realizable-solvency-collapse`) | *not addressed* — the refutation is about profitability, not about the quote's blindness |
| Surface | `_disposeShares` (pre-existing) | `previewExitFor` (new at `cdd0743`) |

A future triage pass that pattern-matches CODE-02 onto `M-02` and inherits `false-positive` would
suppress a live finding. Recorded here so it cannot happen silently. Ledger entry `L-12` (open,
*"CurveAMMAdapter.swap does not independently verify amountOut >= minAmountOut"*) is adjacent context,
not a duplicate.

### CODE-03 → `INCORRECT-OPERATOR` (MEDIUM) for the footgun half — **match strengthens the footgun, not the `(0,0)` half**

The `(0,0)` overloading is an API-contract defect with no catalogued pattern. The **owner-footgun half
does match**, on `INCORRECT-OPERATOR`'s `vulnerableWhen` bullet 2 — *"cap/threshold comparison lets the
exact boundary value through when it should be excluded"*:

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:89-92
function setSlippageTolerance(uint256 _bps) external onlyOwner {
    require(_bps <= MAX_BPS, "ERC4626MarketYieldStrategy: slippage tolerance exceeds MAX_BPS");
```

The pattern's own guard rail — *"Confirm the boundary value actually matters before reporting"* — is
satisfied by CODE-03's own evidence: at exactly `MAX_BPS`, `_creditedPrincipal` books zero on every
deposit and the only alarm is a `(0,0)` indistinguishable from an empty account. `CENTRALIZATION-ADMIN`
(LOW) also matches the `onlyOwner` signature but adds nothing: its note is the standard C4 Low framing,
and CLAUDE.md Law 3 already routes non-obvious footguns to report, which CODE-03 does.

Adjacent open ledger entry **`L-01`** — *"slippageToleranceBps default-0 plus setter missing sane cap
(missing validation)"* — is the *lower* boundary of the same setter. CODE-03's footgun is the *upper*
boundary and is not covered by `L-01`'s fingerprint.

### CODE-04 → **no catalogued pattern** — and it is a **recurrence of an open in-project ledger entry**

No pattern in v1.1 covers test-double fidelity. But CODE-04's **second mechanism** (a dust exit where
`convertToShares(gross) == 0` at a share price above one underlying unit) is the same defect already
on the ledger as **`L-13` / `1456259d8ac60c118795b770323769ed2bf565c67dee884a6d814daded7bbc4e`** (Low,
**open**) — *"`_totalWithdraw` state-inconsistency: migration recorded as executed even when
`sharesToSell` floors to 0 for a tiny-balance client (principal left on books, nothing moved)"*.
`L-13` is the `_totalWithdraw` instance; CODE-04 is the `_disposeShares`/`previewExitFor` instance of
the identical share-flooring root cause. **Disclose, do not collapse** — the fixes are in different
functions (`L-13` wants a revert-or-skip in `_totalWithdraw`; CODE-04 wants
`if (sharesToSell == 0) return 0;` in `_disposeShares`). Corroborated independently by static analysis
**SA-008** (`vault.redeem` return value discarded at `ERC4626YieldStrategy.sol:135` — the strategy's own
exit never measures the delta it demands of its consumers).

### F-02-050 → `ROUNDING-DIRECTION` (MEDIUM) — **match reveals a KNOWN-BENIGN shape; confirms QA is the right severity**

All the signatures fire (`ceilDiv(`, `/ totalSupply`, `/ totalAssets`). But the pattern's
`notVulnerableWhen` bullet 1 — *"every rounding decision favours the protocol"* — holds here:
`Math.ceilDiv` rounds the **request** up (the user asks for more gross, and is debited more principal
for it), and the `convertToAssets(convertToShares(·))` double-floor rounds the **quote** down. Both
directions are conservative; there is no leg that rounds in the user's favour and no repeatable
round-trip profit. Combined with code-scan's H-3 bound (`netWanted − netGuaranteed ≤ ⌈A/S⌉ + 2` raw
units, 256-run fuzz, no counterexample), **`ROUNDING-DIRECTION` classifies F-02-050 as benign** and
supports its QA severity. It is a documentation defect (the story's stated property is not what the
code establishes), not a value leak. `DIVISION-PRECISION` is separately **REFUTED**: both new
expressions multiply before dividing (`netWanted * MAX_BPS / denominator`,
`idealUnderlying * (MAX_BPS - bps) / MAX_BPS`).

**In-project recurrence.** F-02-050 is the **exit-side twin of open ledger entry `F-01` /
`ec9191e420d544443d4625c9b2150cf725b06328b41eb4c58e0ff2572bb5ee04`** — *"story-043 'provable solvency
invariant' overstated: ERC4626 double round-down means `convertToAssets(convertToShares(creditedPrincipal))`
can be a few wei below `creditedPrincipal`"*. Same arithmetic, same overstated-story shape, deposit
side then, exit side now. Two consecutive stories have claimed a provable property that the double
round-down does not deliver. That is a **process signal**, not just a second dust finding.

### Summary table

| Finding | Pattern ID(s) | Confidence | Effect of the match |
|---|---|---|---|
| F-01-050 | `YIELD-PRINCIPAL-ACCOUNTING-SKEW` | high | **Strengthens** (catalogued HIGH); + proves the proposed remedy is inert; extends open ledger `ECON-A` |
| CODE-01 | `YIELD-PRINCIPAL-ACCOUNTING-SKEW` | high | **Strengthens**; mitigation only partial; recurrence of merged `M-03` on a new surface |
| CODE-02 | `TWO-STEP-COMMIT-WINDOW` (analogical); `MISSING-SLIPPAGE` **refuted** | medium | No catalogued home → **new-pattern candidate**; must NOT inherit `M-02`'s false-positive |
| CODE-03 | `INCORRECT-OPERATOR` (footgun half); `CENTRALIZATION-ADMIN` (adds nothing) | high / low | **Strengthens** the footgun half; `(0,0)` half uncatalogued |
| CODE-04 | none | — | **New-pattern candidate**; dust leg is a recurrence of open `L-13` |
| F-02-050 | `ROUNDING-DIRECTION`; `DIVISION-PRECISION` **refuted** | high | **Known-benign shape** — confirms QA; recurrence of open `F-01` |

---

## 2. Unmatched patterns chased on this delta

Patterns that apply to a preview/quote-versus-execution surface and that no prior pass on this run
had run against the story-050 delta. All verdicts carry quoted evidence.

### 2.1 CONFIRMED — `INCORRECT-OPERATOR` (boundary), NEW instance: unbounded `netWanted` overflows the market gross-up before the cap

`previewExitFor` multiplies by `MAX_BPS` **before** it caps to the account's principal:

```solidity
// src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol:174-183
grossToRequest = Math.ceilDiv(netWanted * MAX_BPS, denominator);
...
uint256 availablePrincipal = clientBalances[token][account];
if (grossToRequest > availablePrincipal) {
    grossToRequest = availablePrincipal;
}
```

The base default caps **first** and cannot overflow:

```solidity
// src/AYieldStrategy.sol:580-582
uint256 availablePrincipal = clientBalances[token][account];
grossToRequest = netWanted > availablePrincipal ? availablePrincipal : netWanted;
netGuaranteed = grossToRequest;
```

Probe `testPM1_MaxNetWantedOverflowsMarketButNotDirect` (PASS):

```
direct  gross @ uint256.max: 1000000000000000000000   (= the capped principal, no revert)
market  @ uint256.max      : reverts, Panic(0x11) arithmetic overflow
market overflow boundary   : netWanted > 11579208923731619542357098500868790785326998466564056403945758400791312963
```

The boundary is exact and asserted: `boundary` returns the capped principal; `boundary + 1` reverts.

**Why this matters beyond an absurd input.** `type(uint256).max` is the standard "give me everything"
sentinel and the base default honours it. So the two implementations of one interface member **diverge
on the idiomatic max-request**: `ERC4626YieldStrategy` answers, `ERC4626MarketYieldStrategy` panics.
And story-050 mandated (criterion 9) that a division edge be *"distinguishable from a bare
`Panic(0x12)`"*; the same function still ships a bare `Panic(0x11)` on a neighbouring edge, reached by
a much more plausible input than `slippageToleranceBps == MAX_BPS`. **Severity: QA / Low** — a view
reverting on an extreme argument, with the caller's own cap as the workaround. One-line fix: cap to
`availablePrincipal` before the gross-up, or `Math.min(netWanted, availablePrincipal)` first.

### 2.2 CONFIRMED — `YIELD-PRINCIPAL-ACCOUNTING-SKEW`, NEW instance: the direct-strategy preview is blind to a vault withdrawal limit

`_disposeShares` on the direct strategy calls `vault.redeem` with **no `maxRedeem` check**, and
nothing in first-party `src/` reads `maxRedeem`/`maxWithdraw` at all:

```
$ grep -rn "maxRedeem\|maxWithdraw" src/          →  (no output)
```

```solidity
// src/concreteYieldStrategies/ERC4626YieldStrategy.sol:129-137
uint256 sharesToRedeem = vault.convertToShares(amount);
uint256 availableShares = vault.balanceOf(address(this));
if (sharesToRedeem > availableShares) { sharesToRedeem = availableShares; }
vault.redeem(sharesToRedeem, recipient, address(this));
```

Probe `testPM2_DirectPreviewGreenWhileWithdrawGuaranteedToRevert` (PASS) against a Tokemak-Autopool-shaped
vault that throttles redemptions (`maxRedeem` = 10e18 of a 1000e18 position):

```
gross quoted      : 900000000000000000000
netGuaranteed     : 900000000000000000000     <-- FULL guarantee
vault.maxRedeem   :  10000000000000000000
withdraw(gross)   : reverts, "exceeds withdrawal limit"
```

This is **CODE-02's shape on the strategy story-050 says needs no override**, reached by a different
mechanism (vault-side redemption limit rather than AMM price), and it is **not** F-01-050 (which is the
underwater share-cap case; here the position is fully solvent and `balanceOf` is untouched). It is
realistic for this exact deployment: run-16 recorded `ERC4626YieldStrategy` targeting Tokemak
autoDOLA/autoUSD, and the repo already ships `test/mocks/MockRestrictedERC4626Vault.sol` explicitly
modelling an sUSDe-style cooldown — so the codebase **knows** this vault class exists, and the preview
still does not model it. **Severity: Low today, potential-Medium on wiring** — same escalation trigger
as F-01-050 and CODE-02 (WATCH-17-03).

### 2.3 REFUTED — `REENTRANCY-READONLY` (HIGH)

Signature match is strong: `function convertToAssets(`, `function convertToShares(` are both read by
`_exitFloor` (`ERC4626MarketYieldStrategy.sol:128`, `:132`), and `previewExitFor` is exactly the
"external view a downstream integrator consumes as an oracle" the pattern targets. The pattern's note
instructs flagging even when this contract is itself safe. **Refuted on the mechanism, with evidence:**
no third party can obtain control while a `withdraw` is in flight. The only outbound calls are
`ammAdapter.swap` → `router.exchange`; the value legs are the vault share ERC20 and a plain ERC20
underlying, with **zero hook-bearing tokens in scope** (`grep -rn "selfdestruct\|delegatecall" src/`
→ 0; no ERC777/ERC721/ERC1155 anywhere in `src/`), and every value-moving entry point carries
`nonReentrant` (`src/AYieldStrategy.sol:417, 464, 628, 646, 663, 677, 682, 687`).

Static analysis **SA-003/SA-004** do name `previewExitFor` as a cross-function reader of
`clientBalances`/`totalDeposited` written *after* the external call in `_totalWithdraw`
(`ERC4626MarketYieldStrategy.sol:309`, `ERC4626YieldStrategy.sol:194`) — so the *window* is real; what
is missing is any actor who can read it. That window's consequence (an over-quote against un-zeroed
principal) is already CODE-01. **Not a separate finding.** Recorded because a future run that adds a
hook-bearing token, a callback-capable AMM adapter, or a router with a swap callback re-opens it —
this refutation is conditional on the token set, not structural.

### 2.4 REFUTED — `FLASH-LOAN-PRICE` (HIGH) and `ORACLE-STALE` / `ORACLE-ROUNDID` (MEDIUM)

`FLASH-LOAN-PRICE` signature `balanceOf(address(this))` fires at `ERC4626MarketYieldStrategy.sol:129`
and the quote is a spot read of the vault rate. Refuted as a profit vector: for a spec-compliant
ERC4626 vault, `deposit`/`redeem` are rate-neutral, so a flash loan cannot move `convertToShares`; the
only lever is a **donation**, which raises everyone's quote at the donor's expense. This is also
already adjudicated in-project — ledger entry **`M-02-run11` /
`c7329862eb0ec516f03b9b0b3e545ceffc63fdb4b997c4779e12079a80c47db4`**, *"vault.convertToAssets /
convertToShares used as price oracle … manipulable by donating underlying to the vault"*, status
**`false-positive`**. Story-050's NatSpec independently discloses the within-block manipulability.
Adjacent open entry `L-09` (time-weighted-rate divergence) is unchanged by this delta.

`ORACLE-STALE`/`ORACLE-ROUNDID`: **no match, zero signatures** — `grep -rn "latestRoundData\|AggregatorV3" src/`
returns 0. No Chainlink feed exists in this project.

### 2.5 REFUTED — `ERC4626-INFLATION` and `FIRST-DEPOSITOR-ATTACK` (both HIGH)

Both fire on category ("an ERC4626 project") and both are structurally impossible here: the strategies
issue **no shares of their own**.

```
$ grep -rn "totalSupply\|_mint(" src/ --include=*.sol | grep -v src/mocks   →  (no output)
```

Accounting is a 1:1 `clientBalances` ledger in underlying units; there is no `totalSupply()==0` branch
and no exchange rate to inflate. The third-party vault's own inflation resistance is out of scope
(root cause OOS per CLAUDE.md).

### 2.6 REFUTED / NOT APPLICABLE — remaining patterns

| Pattern | Verdict | Evidence |
|---|---|---|
| `UNPROTECTED-INIT`, `STORAGE-COLLISION` | **Refuted** | Sole `initialize` occurrence in `src/` is a NatSpec `@param` comment at `AYieldStrategy.sol:852`; no proxy, no `delegatecall` (0 occurrences) |
| `SIGNATURE-REPLAY`, `PERMIT-FRONTRUN`, `CROSS-CHAIN-REPLAY` | **Refuted** | `ecrecover` 0 occurrences; no permit/EIP-712 path; single-chain |
| `SELFDESTRUCT-FORCE-ETH` | **Refuted** | `selfdestruct` 0 occurrences; no `receive()`/ETH balance logic on the changed path |
| `WEAK-PRNG`, `DOUBLE-VOTING`, `TIMELOCK-BYPASS`, `REENTRANCY-ERC777`, `REENTRANCY-ERC721-RECEIVE`, `REENTRANCY-CROSS-FUNCTION` | **Refuted** | No randomness, no governance token, no ERC777/721/1155; cross-function reentrancy cleared by contract-wide OZ `ReentrancyGuard` (code-scan's mandatory walk, not re-derived) |
| `DOS-UNBOUNDED-LOOP` | **Checked, pre-existing, not in delta** | Loops at `ERC4626MarketYieldStrategy.sol:396,436` and `ERC4626YieldStrategy.sol:275,315` over the owner-managed `clients[]` set; already ledger `L-02` (**wont-fix**) and SA-012/SA-013. `previewExitFor` contains no loop |
| `RETURN-VALUE-IGNORE` | **Checked, already filed** | SA-008/SA-009; not re-derived here |
| `FEE-ON-TRANSFER-ACCOUNTING` | **Refuted as filed** | Per CLAUDE.md, fee-on-transfer tokens are a known-invalid class; the *vault-fee* variant is real but is `ECON-A` extended (see §1), not this pattern |
| `REWARD-ACCRUAL-ORDER`, `REWARD-RUNWAY-DEPLETION`, `EMISSION-WINDOW-BOUNDARY`, `MINT-ON-DEMAND-OVERMINT`, `BATCH-PAYOUT-FIXED-POT` | **Refuted (no signature)** | Zero hits for `accRewardPerShare`, `rewardDebt`, `_updatePool`, `rewardRate`, `windowEnd`, `nudgeSize`, `phusdPerSecond` in `src/`. This project has no emission accumulator — it is a strategy adapter, not a farm. Run per the staking-yield "run on every project" rule; recorded as checked-with-no-match |

**Skipped per the DB skip rule**: `FRONTRUN-APPROVE` (LOW) — its `note` places approve-race in the
C4 known-invalid set. It does match by signature (`safeIncreaseAllowance`, 4 occurrences in `src/`,
including `ERC4626MarketYieldStrategy.sol:249` on the exit path). **No HM twist exists**: code-scan
already established the residual strategy→adapter allowance is unexploitable because
`CurveAMMAdapter.swap` transfers `from: msg.sender` only. Adjacent open ledger entry `L-02-run11`
covers the housekeeping. Not routed to manual review.

---

## 3. Cross-project recurrence

Evidence base: all 8 `reports/*/ledger.json` parsed programmatically (560 finding nodes, no
truncation), the run report tree, and a direct scan of all 54 first-party `Mock*.sol` sources.

### 3.1 Linear-Depletion class — **REFUTED as a mechanism, CONFIRMED as the parent family**

**Refuted, mechanically.** The Linear-Depletion class is *per-interaction full-window re-spread*: a
rate is re-anchored over a fresh window on every touch, turning a linear drain into exponential decay
with **1 − 1/e ≈ 63%** retained at the nominal window end. That machinery does not exist in this
project:

```
$ grep -rn "accRewardPerShare|rewardDebt|_updatePool|_recomputeSchedule|rewardRate|
            depletionDuration|lastRewardTime|windowEnd|rewardPerSecond" src/ (excl. src/mocks)
→ 0 hits for every one of the nine identifiers
```

reflax-yield-vault is a strategy adapter, not an emission engine; there is no schedule to re-anchor
and no ≈63% constant anywhere in the run-17 evidence. **Do not import the class fingerprint here.**

The catalogued homes, for the record (all verified in-ledger):

| Project | Entry | Fingerprint | Sev | Status |
|---|---|---|---|---|
| phlimbo-ea | **M-04** — *"'Linear Depletion' implemented as exponential decay: rewardPerSecond re-anchored on every interaction (~63% delivered in-window, stranded tail)"* | `9f7c191e06a1618a…` | medium | **acknowledged** (*"V1 deprecated — all users migrated to PhlimboV2"*) |
| phlimbo-ea | **M-02** (folded in, downgraded to low) | `484fd7f20068dbf2…` | low | **acknowledged** |
| phlimbo-ea | **V3-L-01** — permissionless `collectReward` re-anchors over a fresh `depletionDuration` | `5d5e3767521f7367…` | low | **open** ← living descendant |
| phoenix-nft-staking | **M-01** (run-18) — *"per-interaction full-window re-spread… ~63.26% delivered"* | `b58b172e2af4ec08…` | medium | **fixed** @`321d0a9` |
| phoenix-nft-staking | **M-03** — *"POSSIBLE INCOMPLETE FIX of M-01 — migrateIn slice ordering reaches the class through the migration path"* | `58bd104c00695265…` | medium | **wont-fix** |
| phoenix-nft-staking | **L-02** — NudgeStreamer is a first-order low-pass filter, ~63% **retained** at window end (the "36.7% retained" figure is orientation-inverted and must not be requoted) | `aaebb4b9b056d02b…` | low | **open** |

**Confirmed, at the parent level — and this is the useful half.** All six of those entries, plus this
run's F-01-050, F-02-050 and CODE-02, share a strictly larger family: **a documented model that the
implementation does not follow, where the document is the thing consumers act on.** phlimbo's NatSpec
said "linear" and the code decayed; story-043 claimed a "provable solvency invariant" the double
round-down does not deliver (open reflax ledger `F-01`, `ec9191e420d54444…`); story-050 says
`netGuaranteed` is a **floor** and on the direct strategy it is a **ceiling**. The recurring
remediation is also identical: phoenix `L-02`'s authoritative note settles on
*"REMEDIATION: DOCUMENTATION plus a RUNBOOK NOTE… Not a code change"*, which is exactly F-01-050's
cheaper remedy ("narrow the interface NatSpec so it stops promising a delivery guarantee the default
cannot make"). **Recommendation:** when F-01-050 is triaged, weigh it against phlimbo M-04's
disposition — that one was only survivable because the contract was already deprecated. `previewExitFor`
is brand new and about to acquire its first consumer.

### 3.2 Mock-more-permissive-than-production — **CONFIRMED, and this project is now a repeat offender**

The seed is real and confirmed at source: `lib/stable-staker/test/mocks/MockYieldStrategy.sol:137`,
`function relinquishPrincipalAsOwner(address, uint256) external override {}` — an empty body under a
section header the file itself writes as `// ==== IYieldStrategy UNUSED-BY-STAKER STUBS ====`, with
four more empty overrides beside it (`:139 emergencyWithdraw`, `:141 totalWithdrawal`,
`:151 setSetAsideBuffer`, `:157 setSetAsideBufferRecipient`). Its sibling `relinquishPrincipal` (`:130`)
**is** real, so the `AsOwner` variant is the one that silently no-ops.

The class is well-populated across the suite — `phoenix-nft-staking` **Q-02** (`d0ed2cf440cf1612…`,
qa, **wont-fix**: `MockERC1155.mint()` skips `_checkOnERC1155Received` entirely, so the guard is never
reached) and **Q-01** (`cabd4a3d4f08fa71…`, qa, **open**: a witness test that *"passes GREEN while
run-20 M-02 is live on exactly the property it claims to certify"*); `phlimbo-ea` **V3-Q-06**
(`a3e4ecf4a95c3b8d…`, qa, open); `yield-claim-nft` **Q-17** (`696cc3452e1c247e…`, qa, open);
and the 285-line `reports/phoenix-phase-2-staging/21/script-audits/dev/mock-fidelity.md`, whose verdict
on `MockAutoDOLA` is *"**the mock is MORE PERMISSIVE than reality in the exact line the code was
hardened for**"* and whose bottom line is *"a good functional and wiring rehearsal, and a **null
economic rehearsal**"*.

**CODE-04 is the same shape, and it is not alone.** Sweeping the run-17 fixtures turned up **four more
divergences** beyond CODE-04's `MockAMMAdapter` missing `require(amountIn > 0)`:

| # | Divergence | Evidence |
|---|---|---|
| **D-1** | `MockAMMAdapter.swap` has no `amountIn > 0` guard | CODE-04 (established) — `src/AMMAdapters/CurveAMMAdapter.sol:129` vs `test/mocks/MockAMMAdapter.sol:63` (its only `require` is the `minAmountOut` check) |
| **D-2** | `MockAMMAdapter` has **infinite depth and a size-independent price**: `amountOut = (amountIn * rate) / 1e18` (`test/mocks/MockAMMAdapter.sol:60`), reserves pre-minted. A real Curve route's output is concave in size, so a large `grossToRequest` can breach `minOut` **from depth alone**, at an unmoved mid-price | `test/mocks/MockAMMAdapter.sol:56-63` |
| **D-3** | `MockERC4626Vault`'s only fee knob is **deposit-only**. `redeem` pays `_convertToAssetsInternal(shares)` exactly and `previewRedeem` is identical to `convertToAssets`, so the **exit** leg is fee-free no matter what `setFeeBps` is set to | `test/mocks/MockERC4626Vault.sol:49-58, :96-115`; proven by probe `testPM4_MockVaultFeeIsDepositOnly` (PASS): `convertToAssets == previewRedeem == redeem returned == 1000e18` at `setFeeBps(500)` |
| **D-4** | `MockERC4626Vault.maxRedeem/maxWithdraw` return the **whole balance unconditionally** (`:127-133`); there is no withdrawal queue, cooldown or limit. `_disposeShares` never checks either | proven by probe `testPM2_…` (§2.2) |
| **D-5** | **Not a mock — a self-referential oracle.** The test helpers `_exitFloor` and `_grossUp` (`test/unit/ERC4626MarketYieldStrategy.t.sol:44-58`) are line-for-line re-implementations of the production internals, so `assertEq(netGuaranteed, _exitFloor(gross))` compares the implementation to a **copy of itself**, never to what `_disposeShares` delivers. And `_disposeShares` does **not** call `_exitFloor` — it recomputes `minOut` inline at `ERC4626MarketYieldStrategy.sol:245-246`. The NatSpec's claim that quote and swap floor *"cannot drift apart"* is enforced by convention across **three** copies, with a test oracle that cannot detect the drift | `ERC4626MarketYieldStrategy.sol:127-135` vs `:237-246` vs `ERC4626MarketYieldStrategy.t.sol:44-52` |

**Which of the 13 new market preview tests are affected — concretely:**

| # | Test (`test/unit/ERC4626MarketYieldStrategy.t.sol`) | Affected by |
|---|---|---|
| 1 | `testPreviewExitForGrossesUpForHaircut` :389 | **D-5** (asserts against the mirror) |
| 2 | `testPreviewExitForZeroSlippageIsIdentity` :404 | — clean (pure numeric) |
| 3 | `testPreviewExitForAtFivePercentTolerance` :419 | **D-5** |
| 4 | `testPreviewExitForAtMaxBpsReturnsZeroWithoutPanic` :435 | — clean |
| 5 | `testPreviewExitForCapsToAccountPrincipal` :452 | **D-5** |
| 6 | `testPreviewExitForUnknownAccountReturnsZero` :467 | — clean |
| 7 | `testPreviewExitForZeroNetWanted` :476 | — clean as written, but it is the state **D-1** makes unfeedable-forward on mainnet |
| 8 | `testPreviewExitForRevertsForWrongToken` :487 | — clean |
| 9 | `testPreviewExitForRoundTripDeliversAtLeastFloor` :494 | **D-2, D-3** (executes the swap on an infinite-depth, fee-free rig) |
| 10 | `testPreviewExitForRoundTripAtUnfavorableRateClearsFloor` :511 | **D-2, D-3** — the 0.995 rate is size-independent; on a real pool the same rate at a larger size breaches `minOut` |
| 11 | `testPreviewExitForFavorableAMMExceedsQuote` :532 | **D-2, D-3** |
| 12 | `testPreviewExitForShareBalanceCapBinds` :552 | **D-5** — and it never withdraws, so the case the author *knew* about is quoted but never executed |
| 13 | `testPreviewExitForSurvivesStaticcall` :572 | — clean |

**And the 7 direct-strategy tests** (`test/unit/ERC4626YieldStrategy.t.sol`): `:1603`, `:1615`, `:1626`
quote against a vault with no exit fee and no redemption limit (**D-3, D-4**); `:1653`
`testPreviewExitForRoundTripDeliversAtLeastFloor` is the load-bearing one — it is the **only** direct
test that executes, and **both** probes in §2.2 and §1 (PM-2, PM-3) show it inverting to a failure the
moment the vault is a realistic Tokemak- or fee-charging one. `:1638`, `:1647`, `:1671` are clean.

Net: **5 of 13 market tests rest on a self-referential oracle, 3 execute on a frictionless AMM, and the
single executing direct test is the one that would fail against the vault class this strategy is
actually aimed at.** The suite is green; it is not evidence.

⚠ **Recall gap surfaced by this sweep:** `reports/reflax-yield-vault/ledger.json` still has
`lastRun: reflax-yield-vault-16` at `0110ce44…`. CODE-01…CODE-07, F-01-050 and F-02-050 are **not yet
ledgered**, so none of them can be reconciled by fingerprint on the next run until finding-manager
runs. Flagged, not fixed here (out of this agent's lane).

### 3.3 Quote/preview divergence from execution — **CONFIRMED: this suite has filed the class ten times**

Yes — repeatedly, across five projects, and the triage history is the most decision-relevant output of
this pass:

| Project | Entry | Fingerprint | Sev | **Status** | Substance |
|---|---|---|---|---|---|
| reflax | **ECON-A** (= run-16 `L-16`) | `c50c08f9ee587c02…` | low | **open** | *"credits principal via fee-blind convertToAssets, persistently over-stating redeemable NAV"* — **direct parent of F-01-050's fee leg (§1)** |
| reflax | **F-16-003** | `c705bd94ec78fd23…` | faithfulness | **open** | the doc twin of ECON-A; `16/spec-conformance.md:65` carries a Medium re-evaluation gate — *"must re-weigh severity against the actual vault wired at the integration point, not inherit ECON-A's stale Low"* |
| reflax | **M-02** | `d7f6c2dfd580776d…` | medium | **false-positive** | NAV-anchored `minOut` execution-price-blind — see the de-confliction table in §1; **CODE-02 must not inherit this** |
| reflax | **M-02-run11** | `c7329862eb0ec516…` | medium | **false-positive** | `convertTo*` as oracle, donation-manipulable |
| reflax | **F-01** | `ec9191e420d54444…` | faithfulness | **open** | double round-down vs a claimed "provable" invariant — **parent of F-02-050** |
| stable-staker | **M-01** "par-exit front-run" | `2b9a89d29c34df41…` | medium | **wont-fix** | *"The finding is VALID — explicitly NOT a rejection on the merits and NOT a severity downgrade… closed wont-fix because the mitigation is OPERATIONAL… belongs in the deployment script"* ⚠ memory cites `69c7666e…`; that is the **older** entry (*"Underwater withdraw buffer is FCFS at par"*, medium, wont-fix, *"Intended design (confirmed by protocol owner)"*). `2b9a89d2…` is the story-020 re-raise |
| stable-staker | **M-07** (`ss9m7`) | `969722dc9eedb961…` | medium | **acknowledged** | *"That guard is blind to AMM EXECUTION slippage: a strategy whose rate reads solvent… can still return less than principal when its position is actually unwound through an AMM"* — **the closest sibling of CODE-02 anywhere in the suite** |
| phoenix-phase-2-staging | **YS-01** | `28d5044e…` | medium | **acknowledged** | *"the story-060 fix line (`vault.previewRedeem`) reverts against the real Tokemak Autopool vaults"* |
| phoenix-phase-2-staging | **MR-DEV-001** | (parked run-note) | — | parked | *"the story-060 / YS-01 Tokemak fix is one-directional"* |
| stable-yield-accumulator | **L-06** | `90bcf376…` | low | **open** | *"Preview (snapshot estimate) diverges from charged amount (actual skim) with no payment ceiling"* — the cleanest in-class exemplar |
| antimatter | **Q-05** | `1b960956475d434a` | qa | **open** | *"the new exact-equality quote check is not a slippage or minimum-output guard, yet its comment and error name present it as protection"* |
| yield-claim-nft | **L-11** / **L-15** | `531916f4…` / `e64f73d6…` | low | open / **wont-fix** | in-batch floor staleness; five min-out floors with *"NO on-chain price reference"* (owner-accepted 2026-07-19) |

**What the triage history says about run-17.** The class is chronically filed at Low/QA and chronically
disposed as `acknowledged` / `wont-fix` / `false-positive`. Two of those dispositions carry conditions
that run-17 satisfies:

1. `stable-staker` **M-07** was `acknowledged` on a guard *"blind to AMM execution slippage"*. CODE-02
   is the same blindness on a surface that now **publishes** the blind number to external consumers,
   under the word "guarantees". Same mechanism, strictly larger blast radius.
2. reflax **F-16-003**'s spec-conformance gate already instructs the next reader **not to inherit
   ECON-A's stale Low** but to re-weigh against the vault actually wired. §1 and §2.2 supply exactly
   that evidence (Tokemak withdrawal limits; a 5% exit fee costing 5% of the "guarantee"). The gate is
   live and this run trips it.

**Class-fusion note (carried from the sweep).** Class 2 and Class 3 are the same failure at the Tokemak
boundary: `MockAutoDOLA`'s un-overridden OpenZeppelin `previewRedeem` (a Class-2 divergence) is exactly
what hid `YS-01`/`MR-DEV-001` (Class 3), and `ECON-A`'s fee-blind `convertToAssets` exists *only*
because `previewRedeem` had to be abandoned after `YS-01`. Run-17 completes the loop: story-050 built a
new guarantee on that same fee-blind primitive, and the repo's own mocks (D-3, D-4) cannot see it.

---

## 4. Novel shapes — new-pattern candidates

Three established findings have **no home in v1.1**. Proposed additions, with detection heuristics:

### 4.1 `PREVIEW-EXECUTION-DIVERGENCE` (proposed, severity MEDIUM)

> A read-only preview/quote reports a value derived from a **strict subset** of the state its own
> execution path consumes, so it returns a healthy figure in states where execution is guaranteed to
> revert or to under-deliver.

Covers **CODE-02**, **PM-2** (§2.2), the fee leg of **F-01-050**, `stable-staker` M-07
(`969722dc…`), `stable-yield-accumulator` L-06 (`90bcf376…`), and `phoenix-phase-2-staging` YS-01
(`28d5044e…`). This is the single largest uncatalogued family in the suite.

```json
{
  "id": "PREVIEW-EXECUTION-DIVERGENCE",
  "name": "Preview/Quote Blind to a Leg of Its Own Execution Path",
  "category": "defi",
  "severity": "MEDIUM",
  "codeSignatures": ["function preview", "function quote", "netGuaranteed", "minOut",
                     "convertToAssets(", "convertToShares(", "returns (uint256 grossToRequest"],
  "vulnerableWhen": [
    "the preview reads a strict SUBSET of the state its execution path reads (enumerate both, diff them)",
    "the execution path enforces a floor (minOut/require) the preview cannot evaluate",
    "the execution path calls an external contract whose limits (maxRedeem/maxWithdraw/cooldown/queue/depth) the preview never queries",
    "the preview uses a fee-blind conversion where execution charges a fee",
    "the quote is documented as a guarantee/floor rather than an estimate"
  ],
  "notVulnerableWhen": [
    "preview and execution share ONE code path (the preview calls the same internal helper execution calls)",
    "the preview returns a distinguishable failure signal when its floor cannot be met",
    "the NatSpec states the quote is non-binding AND names each leg it does not model"
  ],
  "note": "Detection heuristic: list every external read on the execution path, then every external read in the preview; every read in the first set and not the second is a blind leg. Severity rises when a consumer is wired and when the return value is named as a guarantee."
}
```

### 4.2 `MIRRORED-INVARIANT-DRIFT` (proposed, severity LOW→MEDIUM)

> A safety-critical expression is **duplicated** rather than shared between a quote and its execution,
> and the test oracle is a **third** copy — so the tests cannot detect the two production copies
> drifting apart.

Covers **D-5** above and generalises the run-17 `_exitFloor` / `_disposeShares` / test-helper triple.

```json
{
  "id": "MIRRORED-INVARIANT-DRIFT",
  "name": "Duplicated Invariant with a Self-Referential Test Oracle",
  "category": "code-quality",
  "severity": "LOW",
  "codeSignatures": ["Mirrors", "mirrors .* exactly", "cannot drift apart", "line-for-line"],
  "vulnerableWhen": [
    "an expression appears verbatim in >=2 production functions instead of one shared internal",
    "a test helper re-implements the production expression and is used as the assertion's expected value",
    "NatSpec asserts the copies 'cannot drift apart' with no compile-time or test-time enforcement"
  ],
  "notVulnerableWhen": [
    "the quote calls the same internal helper the execution calls",
    "the test asserts the quote against an OBSERVED execution result, not against a recomputation"
  ],
  "note": "Detection: grep for a duplicated arithmetic chain across a preview and its executor, then check whether the test's expected value is computed or observed. A NatSpec promise of non-drift is evidence FOR the pattern, not against it."
}
```

### 4.3 `MOCK-PERMISSIVENESS-GAP` (proposed, severity LOW)

> A test double omits a precondition, fee, limit, or hook the production counterpart enforces, so the
> suite is green on states that revert or under-deliver in production.

Covers **CODE-04**, D-2/D-3/D-4, and the whole Class-2 corpus above (`stable-staker`
MockYieldStrategy empty overrides; `phoenix-nft-staking` Q-02 `d0ed2cf4…`; `phlimbo-ea` V3-Q-06
`a3e4ecf4…`; `yield-claim-nft` Q-17 `696cc345…`; the `mock-fidelity.md` corpus). Existing memory
`mock-no-op-stub-fakes-permanence` and `vacuous-invariant-harness-mock-never-fails` are two instances
of one pattern that the DB does not yet carry.

```json
{
  "id": "MOCK-PERMISSIVENESS-GAP",
  "name": "Test Double More Permissive Than Production",
  "category": "code-quality",
  "severity": "LOW",
  "codeSignatures": ["contract Mock", "test/mocks/", "external override {}"],
  "vulnerableWhen": [
    "an override in a mock has an EMPTY body while the production function mutates state",
    "production has a require()/limit/fee/hook the mock omits (diff the guard sets function by function)",
    "the mock's price/rate is a constant function (no depth, no impact)",
    "a fee knob exists on one leg only (e.g. deposit) while the code under test is exercised on the other",
    "a 'max'/limit view returns type(uint256).max or the full balance unconditionally"
  ],
  "notVulnerableWhen": [
    "the mock is deliberately built to REPRODUCE a production divergence and says so in NatSpec",
    "the omitted behaviour is unreachable on every path under test (enumerate the paths)"
  ],
  "note": "Positive exemplar in this repo: reflax test/mocks/MockStateChangingPreviewVault.sol, built specifically to reproduce Tokemak's StateChangeDuringStaticCall. Report a hit as test-fidelity (Low) and name which tests it invalidates — a passing suite is not evidence for the property the mock cannot model."
}
```

`CODE-03`'s `(0,0)`-overloading half and `CODE-05`/`CODE-06` (sealed override, ABI drift) are genuine
QA/informational shapes but are too generic to earn a pattern entry; recorded as no-match, no candidate.

---

## Machine-readable summary

```json
{
  "project": "reflax-yield-vault",
  "commit": "cdd0743",
  "scanTimestamp": "2026-08-31T00:00:00Z",
  "scanType": "pattern-matching",
  "patternDbVersion": "1.1",
  "patternsChecked": 35,
  "patternsSkipped": [
    { "id": "FRONTRUN-APPROVE", "reason": "DB note places approve-race in the C4 known-invalid set; signature matches (safeIncreaseAllowance x4 in src/) but no HM twist — code-scan established the residual strategy->adapter allowance is unexploitable because CurveAMMAdapter.swap transfers from msg.sender only. Not routed to manualReview." }
  ],
  "classifications": [
    { "finding": "F-01-050", "patternIds": ["YIELD-PRINCIPAL-ACCOUNTING-SKEW"], "effect": "strengthens", "confidence": "high",
      "note": "Catalogued HIGH. Probe testPM3 proves the finding's own proposed remedy (_positionValue cap) is numerically identical to the over-quote it would correct. Extends open ledger ECON-A c50c08f9ee587c02e38e089dd7aa2ee3ae64a9623bb1e6f1d138154b21fc7887; do not re-file, do not drop." },
    { "finding": "CODE-01", "patternIds": ["YIELD-PRINCIPAL-ACCOUNTING-SKEW"], "effect": "strengthens", "confidence": "high",
      "note": "notVulnerableWhen bullet 1 satisfied (documented surplus rule at AYieldStrategy.sol:780), bullet 2 not. Recurrence of merged ledger M-03 on a new surface." },
    { "finding": "CODE-02", "patternIds": ["TWO-STEP-COMMIT-WINDOW"], "effect": "analogical-only", "confidence": "medium",
      "note": "MISSING-SLIPPAGE REFUTED (minOut present and enforced at ERC4626MarketYieldStrategy.sol:250). CRITICAL: must NOT inherit ledger M-02 d7f6c2dfd580776dd3193942b89806b893ac95ff56a752a5e5bd7c501cb41416 (false-positive) — that entry claims sandwich VALUE LEAK, CODE-02 claims false-green LIVENESS signal. New-pattern candidate PREVIEW-EXECUTION-DIVERGENCE." },
    { "finding": "CODE-03", "patternIds": ["INCORRECT-OPERATOR", "CENTRALIZATION-ADMIN"], "effect": "strengthens-footgun-half", "confidence": "high",
      "note": "require(_bps <= MAX_BPS) at ERC4626MarketYieldStrategy.sol:90 is the boundary-inclusion instance. The (0,0)-overloading half has no catalogued pattern. Ledger L-01 covers the LOWER boundary of the same setter only." },
    { "finding": "CODE-04", "patternIds": [], "effect": "no-catalogued-home", "confidence": "high",
      "note": "New-pattern candidate MOCK-PERMISSIVENESS-GAP. Its dust leg (convertToShares -> 0) is a recurrence of open ledger L-13 1456259d8ac60c118795b770323769ed2bf565c67dee884a6d814daded7bbc4e on a different function; disclose, do not collapse. Corroborated by SA-008." },
    { "finding": "F-02-050", "patternIds": ["ROUNDING-DIRECTION"], "effect": "known-benign", "confidence": "high",
      "note": "notVulnerableWhen bullet 1 holds: ceilDiv rounds the request up (protocol-favouring), the double floor rounds the quote down. No user-favouring leg, no repeatable round-trip profit. Confirms QA severity. DIVISION-PRECISION refuted (mul-before-div throughout). Exit-side recurrence of open ledger F-01 ec9191e420d544443d4625c9b2150cf725b06328b41eb4c58e0ff2572bb5ee04." }
  ],
  "newInstancesChased": [
    { "id": "PM-1", "patternId": "INCORRECT-OPERATOR", "verdict": "CONFIRMED", "severity": "low",
      "contract": "src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol", "function": "previewExitFor", "line": 174,
      "description": "netWanted * MAX_BPS is evaluated BEFORE the principal cap, so netWanted > type(uint256).max/10000 reverts Panic(0x11). The base default (AYieldStrategy.sol:580) caps first and returns the principal, so the two implementations of one interface member diverge on the idiomatic type(uint256).max 'give me everything' sentinel. Story criterion 9 demanded the neighbouring division edge be distinguishable from a bare Panic; this one is not.",
      "poc": "workspace/reflax-yield-vault/test/poc-run17-pattern-match.t.sol::testPM1_MaxNetWantedOverflowsMarketButNotDirect",
      "confidence": "high" },
    { "id": "PM-2", "patternId": "YIELD-PRINCIPAL-ACCOUNTING-SKEW", "verdict": "CONFIRMED", "severity": "low", "severityOnWiring": "medium",
      "contract": "src/concreteYieldStrategies/ERC4626YieldStrategy.sol", "function": "previewExitFor (inherited) / _disposeShares", "line": 137,
      "description": "Zero occurrences of maxRedeem/maxWithdraw in src/. _disposeShares calls vault.redeem unconditionally, and the inherited preview quotes a FULL guarantee against a Tokemak-Autopool-shaped vault throttling redemptions. Quoted 900e18 guaranteed, maxRedeem 10e18, withdraw reverts. Distinct from F-01-050 (that is the underwater share-cap case; here the position is fully solvent). Realistic: run-16 recorded this strategy targeting Tokemak autoDOLA/autoUSD, and the repo already ships MockRestrictedERC4626Vault modelling an sUSDe cooldown.",
      "poc": "workspace/reflax-yield-vault/test/poc-run17-pattern-match.t.sol::testPM2_DirectPreviewGreenWhileWithdrawGuaranteedToRevert",
      "confidence": "high" },
    { "id": "PM-3", "patternId": "REENTRANCY-READONLY", "verdict": "REFUTED", "severity": null,
      "description": "Signatures fire (convertToAssets/convertToShares read by _exitFloor at :128/:132; previewExitFor is an integrator-facing view). Refuted on mechanism: no third party can obtain control mid-withdraw — only outbound calls are ammAdapter.swap -> router.exchange, both value legs are hookless ERC20s, zero ERC777/721/1155 in src/, nonReentrant on all 8 value-moving entry points. SA-003/SA-004 confirm the state window exists but no actor can read it; its consequence is already CODE-01. CONDITIONAL on the token set — re-open if a hook-bearing token or a callback-capable adapter is introduced.",
      "confidence": "high" },
    { "id": "PM-4", "patternId": "FLASH-LOAN-PRICE", "verdict": "REFUTED", "severity": null,
      "description": "Spot vault-rate read at ERC4626MarketYieldStrategy.sol:128-132, but a spec-compliant ERC4626's deposit/redeem are rate-neutral; only a donation moves the rate, at the donor's expense and in every client's favour. Already adjudicated in-project: ledger M-02-run11 c7329862eb0ec516f03b9b0b3e545ceffc63fdb4b997c4779e12079a80c47db4, false-positive.",
      "confidence": "high" },
    { "id": "PM-5", "patternId": "ERC4626-INFLATION,FIRST-DEPOSITOR-ATTACK", "verdict": "REFUTED", "severity": null,
      "description": "Structurally impossible: zero occurrences of totalSupply or _mint( in first-party src/ (excluding src/mocks). The strategies issue no shares; accounting is a 1:1 clientBalances ledger in underlying units. The third-party vault's own inflation resistance is OOS (root cause OOS).",
      "confidence": "high" },
    { "id": "PM-6", "patternId": "ORACLE-STALE,ORACLE-ROUNDID,SIGNATURE-REPLAY,PERMIT-FRONTRUN,CROSS-CHAIN-REPLAY,UNPROTECTED-INIT,STORAGE-COLLISION,SELFDESTRUCT-FORCE-ETH,WEAK-PRNG,DOUBLE-VOTING,TIMELOCK-BYPASS,REENTRANCY-ERC777,REENTRANCY-ERC721-RECEIVE,REENTRANCY-CROSS-FUNCTION,REWARD-ACCRUAL-ORDER,REWARD-RUNWAY-DEPLETION,EMISSION-WINDOW-BOUNDARY,MINT-ON-DEMAND-OVERMINT,BATCH-PAYOUT-FIXED-POT", "verdict": "REFUTED", "severity": null,
      "description": "Checked-with-no-match; zero code signatures for each (greps enumerated in section 2.6). The five staking-yield patterns were run per the run-on-every-project rule: this project has no emission accumulator.",
      "confidence": "high" }
  ],
  "crossProjectRecurrence": {
    "linearDepletion": { "verdict": "REFUTED as a mechanism, CONFIRMED as the parent family",
      "evidence": "zero hits in src/ for accRewardPerShare|rewardDebt|_updatePool|_recomputeSchedule|rewardRate|depletionDuration|lastRewardTime|windowEnd|rewardPerSecond; no ~63% (1-1/e) constant anywhere in run-17",
      "catalogued": ["phlimbo-ea M-04 9f7c191e06a1618a acknowledged", "phlimbo-ea M-02 484fd7f20068dbf2 acknowledged", "phlimbo-ea V3-L-01 5d5e3767521f7367 open", "phoenix-nft-staking M-01 b58b172e2af4ec08 fixed", "phoenix-nft-staking M-03 58bd104c00695265 wont-fix", "phoenix-nft-staking L-02 aaebb4b9b056d02b open"],
      "parentFamily": "documented model the implementation does not follow, where the document is what consumers act on: phlimbo NatSpec 'linear' vs exponential decay; reflax F-01 'provable solvency invariant'; story-050 'floor' that is a ceiling. Shared remediation shape is documentation-first (phoenix L-02: 'REMEDIATION: DOCUMENTATION plus a RUNBOOK NOTE... Not a code change'), which is exactly F-01-050's cheaper remedy." },
    "mockMorePermissive": { "verdict": "CONFIRMED",
      "seedConfirmed": "lib/stable-staker/test/mocks/MockYieldStrategy.sol:137 relinquishPrincipalAsOwner external override {} (empty), plus :139/:141/:151/:157",
      "newDivergencesFound": ["D-2 MockAMMAdapter infinite depth / size-independent price (test/mocks/MockAMMAdapter.sol:56-63)", "D-3 MockERC4626Vault fee is deposit-only, redeem leg fee-free (test/mocks/MockERC4626Vault.sol:49-58,:96-115; proven by testPM4)", "D-4 MockERC4626Vault maxRedeem/maxWithdraw unconditional (:127-133)", "D-5 test helpers _exitFloor/_grossUp are a THIRD copy of a production expression _disposeShares itself duplicates inline (ERC4626MarketYieldStrategy.sol:127-135 vs :237-246 vs t.sol:44-52)"],
      "testsAffected": { "selfReferentialOracle": ["testPreviewExitForGrossesUpForHaircut:389", "testPreviewExitForAtFivePercentTolerance:419", "testPreviewExitForCapsToAccountPrincipal:452", "testPreviewExitForShareBalanceCapBinds:552"], "frictionlessAMM": ["testPreviewExitForRoundTripDeliversAtLeastFloor:494", "testPreviewExitForRoundTripAtUnfavorableRateClearsFloor:511", "testPreviewExitForFavorableAMMExceedsQuote:532"], "directStrategyLoadBearing": ["ERC4626YieldStrategy.t.sol:1653 testPreviewExitForRoundTripDeliversAtLeastFloor — inverts to a failure under PM-2 and PM-3"], "clean": ["market :404,:435,:467,:476,:487,:572", "direct :1638,:1647,:1671"] } },
    "previewExecutionDivergence": { "verdict": "CONFIRMED — filed 10+ times across 5 projects",
      "entries": ["reflax ECON-A c50c08f9ee587c02 low open", "reflax F-16-003 c705bd94ec78fd23 faithfulness open (Medium re-eval gate live)", "reflax M-02 d7f6c2dfd580776d medium FALSE-POSITIVE (do not inherit for CODE-02)", "reflax M-02-run11 c7329862eb0ec516 medium false-positive", "reflax F-01 ec9191e420d54444 faithfulness open", "stable-staker M-01 2b9a89d29c34df41 medium wont-fix (valid; mitigation operational, owed by phStaging script)", "stable-staker M-07/ss9m7 969722dc9eedb961 medium acknowledged (guard blind to AMM execution slippage — closest sibling of CODE-02)", "phStaging YS-01 28d5044e medium acknowledged", "stable-yield-accumulator L-06 90bcf376 low open", "antimatter Q-05 1b960956475d434a qa open", "yield-claim-nft L-11 531916f4 low open / L-15 e64f73d6 low wont-fix"],
      "memoryCorrection": "memory stable-staker-run15-notes cites 69c7666e for par-exit front-run; 69c7666eee33698e7f4f2cce7ab94406e40929494e19a2517a2a324e5c9ea73d is the OLDER 'Underwater withdraw buffer is FCFS at par' entry (wont-fix, intended design). The story-020 re-raise is 2b9a89d29c34df41aee609d0b5f2c6ae82c1e509877261424c2c20f317fbb0c3." }
  },
  "newPatternCandidates": ["PREVIEW-EXECUTION-DIVERGENCE", "MIRRORED-INVARIANT-DRIFT", "MOCK-PERMISSIVENESS-GAP"],
  "errors": [],
  "recallGaps": ["reports/reflax-yield-vault/ledger.json lastRun is still reflax-yield-vault-16 @ 0110ce44; run-17 findings (F-01-050, F-02-050, CODE-001..007) are unledgered and cannot reconcile by fingerprint until finding-manager runs"]
}
```
