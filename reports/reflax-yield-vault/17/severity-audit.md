# Independent Severity Audit — reflax-yield-vault run-17 @ `cdd0743`

- **Agent**: severity-auditor · **Date**: 2026-08-31 · **Ledger NOT modified** · `lib/` read-only
- **Input**: `severity-classification.md` (0 High · 0 Medium · 12 Low · 3 QA · 1 Info)
- **Brief**: the run's live risk is **understatement**, not overstatement — every finding was held at
  Low on one shared premise. Audit the premise and the classifications resting on it.

## Verdict in one line

**No severity changes recommended.** Zero High, zero Medium is **correct** — but for reasons the
classification only *asserted*. Four of the run's five open questions are now **closed by measurement
or source read**, and one of the run's stated reasons for holding at Low is **materially wrong and must
be struck**. The label survives; the reasoning does not.

| # | Finding | Claimed | Assessed | Agree | Confidence | Basis of the change in *reasoning* |
|---|---|---|---|---|---|---|
| 1 | `DEDUP-17-05` | Low | **Low** | ✅ | High | Deployed-topology premise now *confirmed*, not assumed |
| 2 | `DEDUP-17-06` | Low (flagged) | **Low** | ✅ | High | **V1 is wired. No V2 artifact exists anywhere.** Flag closed |
| 3 | `DEDUP-17-04` | Low | **Low** | ✅ | Medium-High | Held on **corrected** grounds; "two escape hatches" is false |
| 4 | `DEDUP-17-14` | Low (flagged) | **Low** | ✅ | High | Window **is** re-initiable — hinge answered NEGATIVE |
| 5 | `DEDUP-17-02` | Low (gap) | **Low** | ✅ | High | Gap **closed on-chain**; divergence real but ~0.005% |
| — | `DEDUP-17-08` | Low | **Low** | ✅ | Medium-High | Same false-remedy correction as `-04` |
| — | all others | as filed | as filed | ✅ | — | No inflation found (see §7) |

---

## 0. The load-bearing premise — independently re-verified

```
grep -rn "previewExitFor" lib/ | grep -v "^lib/reflax-yield-vault/"   →  0 hits
grep -rn "previewExitFor" lib/reflax-yield-vault                       → 32 hits
```

Run untruncated across all nine top-level submodule HEADs (`antimatter 3a96fb7`, `phlimbo-ea f279c62`,
`phoenix-nft-staking 9611312`, `phoenix-phase-2-staging 1d8a3a7`, `reflax-yield-vault cdd0743`,
`stable-staker fa06de5`, `stable-yield-accumulator 6eab35c`, `yield-claim-nft d4cc563`).

**Premise CONFIRMED — third independent verification.** `previewExitFor` has zero consumers. The
view-only-harm ⇒ Low axis is legitimately available, and the C4 *"speculation on future code"* invalid
category correctly does **not** apply (root causes are demonstrated, only the consumer is future).

**The axis is sound. What follows is whether it was applied honestly, and whether the findings that
do *not* need a consumer were argued correctly.**

---

## 1. `DEDUP-17-05` — quote→execute gap, 99% silent shortfall — **LOW CONFIRMED**

**The Medium case, stated at full strength.** `19,602e18` quoted at T1; `181.9e18` delivered at T2 —
0.93% of the guarantee, **no revert, no event, no signal**. `_disposeShares` re-derives `minOut` inline
from live state (`:245-246`), so the quoted floor is silently replaced. That is textbook C4 value-leak
limb shape: *value leak with stated assumptions (a consumer persists the quote) and external
requirements (a price move in the gap)*. Silent under-delivery is strictly worse than a revert, and the
run itself calls this "the most severe shape in the run".

**The Low case, and why it wins.**

1. **No value leaks *because of the quote*, because nothing reads the quote.** `previewExitFor` is a
   pure view. A view whose output enters no decision cannot cause a loss. The Medium limb needs value
   to actually leak; here the leak is fully counterfactual on a consumer that does not exist.
2. **The delivery shortfall itself is not new and is owner-accepted.** `AYieldStrategy.sol:781-783`
   debits the requested amount regardless of receipts by explicit design; the FCFS-at-par socialization
   is `stable-staker` `69c7666eee33698e…`, **`wont-fix`, "intended design, confirmed by protocol owner"**.
   What `cdd0743` adds is only that a number is now *published* under the word "guarantees".
3. **The 99% magnitude is not reproducible in the deployed wiring — now CONFIRMED, not assumed.** The
   PoC needs two exit-capable clients. In the live `ResumeStableStakerMigration` broadcast (chain 1)
   each strategy receives `setClient(…, true)` for exactly two addresses — `PhusdStableMinter`
   (`0x435B0A18…`) and `StableStaker` (`0xbce8ABC0…`) — and **only `StableStaker` receives
   `setWithdrawer(true)`**. One exit-capable client. The classification asserted this; it is now evidenced.

**COMMIT: Low.** The finding is an **API-contract defect on a view with zero readers**, layered over an
owner-accepted execution-side design. It is not QA — the atomic floor equality is an unenforced
convention replicated across three sites (`:127-135`, `:245-246`, `t.sol:44-52`) that evaporates exactly
in the quote→execute mode a STATICCALL preview exists for. Low is the right band, and the distinctness
argument versus `-04` (silent vs revert; different mitigation — a caller-supplied `minOut` on `withdraw`)
is **load-bearing and correct**: filing it under `-04` would let the wrong fix close it.

---

## 2. `DEDUP-17-06` — one-directional write-down — **LOW CONFIRMED, deciding fact RESOLVED**

This was the run's designated highest-value question. **It is now answered.**

### Which StableStaker version is wired: **V1**

| Evidence | Source |
|---|---|
| `StableStaker: "0xbce8ABC09BaEDCabE93419bF875f6186e182079A"` | `phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts:146` |
| `CREATE` recorded as `contractName: "StableStaker"`, ctor args `["0xf3B5…D605" (PhUSD), "0xCad1…D0B6" (owner)]` | `broadcast/ResumeStableStakerMigration.s.sol/1/run-latest.json` (chain 1, 2026-06-10) |
| That two-arg shape is **V1's** `constructor(IFlax _phUSD, address)` | `stable-staker/src/versions/v1/StableStakerV1.sol:202` |
| **V2's** ctor is `constructor(IAntimatter, address)` — **not** what was deployed | `stable-staker/src/StableStakerV2.sol:194` |
| `grep '"contractName": "StableStakerV2"' broadcast/` → **zero hits, all chains incl. 1 and 31337** | `phoenix-phase-2-staging` @ `1d8a3a7` |
| `StableStakerV2` appears in **no** script, address registry, or broadcast in the staging repo | ditto |
| No `Antimatter` key in `mainnet-addresses.ts` | ditto |

**V1 is wired. StableStakerV2 has never been deployed or broadcast anywhere.** Under V1 the
over-delivery moves protocol-owned minter cushion to protocol users — misallocation, not economic loss;
the minter cannot redeem, so no user is diluted.

**Assessment: LOW is CORRECT, and the "flagged for human review" flag can be CLOSED.** The classifier
reached the right label by the conservative rule; it is now the right label on evidence.

**But do not let this read as settled.** Three things keep it live, and they belong in the ledger entry:

- The harm is real, repeatable and **needs no preview consumer** — it is on the live execution path at
  HEAD. `clientBalances[token][holder] -= amount` at `:781-783` is unconditional on `sharesDisposed`;
  downside is booked as protocol yield, upside is paid to the exiter. **+474e18 out of the commingled
  position at a 5% premium.** Ledger conservation holds, which is precisely why no accounting invariant
  catches it — the skew is in value, not in the books.
- **`StableStakerV2` is the evergreen, actively-developed contract, and V1 is slated for retirement**
  (owner, 2026-08-29). This Low has a **short shelf-life by design**: the protocol's own roadmap is the
  escalation trigger. Under V2, AM is redeemable via `annihilate` into unbacked phUSD, so cushion
  depletion becomes real dilution ⇒ **Medium**.
- **Reopen trigger (hard, no further evidence needed):** any `StableStakerV2` deployment wired as a
  client of a reflax strategy ⇒ **Medium immediately**. Second trigger: `PhusdStableMinter` gaining
  `setWithdrawer(true)` or any strategy-exit path.

The classifier's refusal to apply the minter-cushion suppression here is **endorsed**: that memo covers
the **deficit** direction (minters cannot redeem ⇒ cushion, not counterparty). This is the **surplus**
direction and the memo's premise does not reach it. Recall beats tidiness (Law 1).

---

## 3. `DEDUP-17-04` — market exit bricks for all clients — **LOW CONFIRMED, on CORRECTED grounds**

### ⚠ The classification contains a material error that must be struck

> "Bricked normal path, two working escape hatches — **no 'permanent freeze' claim is made**."

**`relinquishPrincipal` is not an escape hatch. It moves zero assets.** Verified at source,
`AYieldStrategy.sol:695-716`:

```solidity
// Write down recorded principal ONLY — vault shares are deliberately untouched.
clientBalances[token][balanceHolder] -= amount;
totalDeposited[token] -= amount;
```

No `transfer`, no `redeem`, no `swap`. It **forfeits the claim**. It is weaker than the suite's
*ejector-seat* category (`emergencyTransfer`-style terminal exits at least move funds); this is
claim abandonment — a donation to the protocol.

The correct statement is: **while the condition holds, no path returns underlying to the client.** The
enumerated "remedies" do not remedy availability, and the run's own `absence-of-remedy` precedent —
which exists to stop *false permanence* claims — was here inverted into a **false-remedy** claim. That
is the understatement pattern the brief asked me to hunt, and it appears verbatim in **`-08` as well**.
Both bullets must be rewritten before the QA bundle closes.

### Does the correction flip the severity? **No — but only because of what I measured.**

Availability *is* an explicit Medium limb, so with the false remedy removed, Low now has to be earned
by the three instances themselves:

- **(a) AMM price blindness / (c) finite depth (market).** The revert is a `minOut` slippage guard
  **doing its job**. Refusing to sell into a 10% discount is correct behaviour, and the condition is
  transient and self-clearing. The owner additionally holds a lever (`slippageToleranceBps`,
  `ERC4626MarketYieldStrategy.sol:91-92`) — though note the tension: exercising it *is* the `-07`
  footgun. Availability is impaired only while an adverse market holds. **Not Medium.**
- **(b) Vault redemption throttle (direct).** This is the genuine Medium candidate — not a guard
  functioning, but an unhandled external precondition (`_disposeShares` calls `vault.redeem`
  unconditionally; zero `maxRedeem`/`maxWithdraw` occurrences in first-party `src/`). The
  classification's escalation trigger was *"evidence that the throttle binds for a sustained period on
  the deployed Autopools"*. **I measured it at block 25878009:**

| Wired strategy | Vault | `balanceOf(strategy)` | `maxRedeem(strategy)` | Binds? |
|---|---|---|---|---|
| `YieldStrategyDola 0x1760E053…` | Tokemak autoDOLA `0x79eB84B5…` | `13357.32e18` | `13357.32e18` | **No — 100.0000%** |
| `YieldStrategyUSDC 0xaFDf8DeA…` | Tokemak autoUSD `0xa7569A44…` | `15062.70e18` | `15062.70e18` | **No — 100.0000%** |

Both Autopools `paused() == false`. Each deployed strategy's `vault()` was confirmed to be exactly the
Autopool measured. **Trigger (b) is NEGATIVE on live state.**

**COMMIT: Low.** Earned by (i) transience/self-clearing, (ii) an owner lever, (iii) a **measured**
non-binding throttle — not by the remedies that were claimed and do not exist.

**Endorsed and must survive triage:** the `M-02` / `d7f6c2dfd5807769…` de-confliction. `M-02` was
refuted on *profitability* of a sandwich; this is *liveness*, on a surface that did not exist at `M-02`'s
commit. A triage pass that pattern-matches the two would suppress a live finding.

---

## 4. `DEDUP-17-14` — silent early-return burns the `totalWithdrawal` window — **LOW CONFIRMED**

The classification named the hinge: *"if the consumed window cannot be re-initiated, an owner migration
is permanently blocked ⇒ Medium on the availability limb."* **Answered from source — it CAN be
re-initiated.**

`AYieldStrategy._executeWithdrawal` (`:879-892`) resets the state **before** dispatching:

```solidity
state.status = WithdrawalStatus.None;
state.initiatedAt = 0;
state.balance    = 0;
_totalWithdraw(token, client, withdrawAmount);   // may silently return
```

So when `_totalWithdraw` no-ops (`ERC4626YieldStrategy.sol:185` / `ERC4626MarketYieldStrategy.sol:293`),
the state is already back to `None`. `totalWithdrawal` re-entered on the next call routes to
`_initiateWithdrawal` (`:855`), whose only gate is `require(balance > 0)` — and `balanceOf` →
`principalOf` → `clientBalances` (`:593-595`), which the no-op left **untouched**. Principal booked ⇒
balance > 0 ⇒ **re-initiation succeeds**. `_updateWithdrawalStatus` also expires stale windows to
`Expired`, which `totalWithdrawal` treats identically to `None`.

**No permanent block exists. The Medium leg is closed.** Residual harm is a wasted 6h `WAITING_PERIOD`
per attempt plus a caller told nothing — a real state-handling defect, correctly **Low**. Not QA: the
consequence is traced, which is what lifts it above a bare `incorrect-equality` detector hit.

Carry the classifier's ledger caveat unchanged: `L-13` / `1456259d8ac60c11…` is the *market*
share-flooring instance; this is the zero-shares/zero-deposits guard on **both** contracts — different
condition, different fix, different `rootCauseClass`. The direct-strategy site is unambiguously new.

---

## 5. `DEDUP-17-02` — previews built on fee-free `convertToAssets` — **LOW CONFIRMED, GAP CLOSED**

`RPC_MAINNET` from the repo-root `.envrc` is **live** (block 25878009; no key expiry — nothing to alert).

### The check the classification asked for, run

The reflax `addresses.json` address could not be used (see §6). The **actually wired** vaults, taken from
each deployed strategy's own `vault()`, were measured:

**Tokemak autoDOLA `0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d`** (asset = DOLA)
```
convertToShares(1e18)             = 842299129881071773
convertToAssets(shares)           = 1000000014462599280
previewRedeem(shares)             =  999952721565253485
divergence (convertToAssets−preview) = 47292897345795  →  0.004729%
```

**Tokemak autoUSD `0xa7569A44f348d3D70d8ad5889e50F78E33d80D35`** (asset = USDC)
```
convertToShares(1e6)              = 908708949392523931
convertToAssets(shares)           = 999999
previewRedeem(shares)             = 999946
divergence                        = 53             →  0.005300%
```

**Result: divergence is NON-ZERO on both live Autopools, and it is in the harmful direction** —
`convertToAssets` (what `netGuaranteed` is built on) **over-states** what `redeem` actually delivers.
The root cause is confirmed live, not hypothetical. `previewWithdraw` diverges from `convertToShares`
in the matching direction.

### Do I honor the classification's trigger — *"any non-zero divergence ⇒ Medium immediately"*?

**No, and I justify the refusal affirmatively rather than for tidiness.**

That trigger was written as a *proxy* for "does the wired vault charge a real exit fee", with a 5%
illustrative figure. The measurement resolves the proxy into a number: **~0.005%, i.e. ~0.5 basis
points.** The C4 Medium value-leak limb requires value to leak *materially*. A 0.005% overstatement of a
quote that **no code reads** is three orders of magnitude below anything that limb contemplates — and by
the run's own `ROUNDING-DIRECTION` dust rule (which sent `-10` to QA), a 0.005% protocol-adverse
divergence would be QA-tier on magnitude alone.

`-02` stays at **Low** on its *spec-deviation* weight, which is where its real substance lives: the
contract now ships **two exit previews that disagree**, the newer one carrying the word "guarantees",
after story-050 criterion 10 deliberately forbade `previewExitFor` from using the fee-aware
`previewRedeem` it already exposes at `ERC4626YieldStrategy.sol:83-85`. That is a genuine Law-2
faithfulness defect and it is correctly routed to `spec-conformance.md` as `F-17-02`.

### ⚠ Required correction — the trigger as written will now force a FALSE Medium

`F-16-003`'s gate is **tripped and now adjudicated**: `ECON-A`'s stale Low is **not** inherited, and the
re-weigh lands on **Low with a measurement behind it**. But left as-is, *"any non-zero divergence ⇒
Medium"* reads as satisfied at the next triage and would manufacture a Medium on 0.5 bps. **Replace it
with a magnitude threshold**, e.g.:

> `convertToAssets/previewRedeem` divergence on a wired Autopool **≥ 10 bps** (or any step change in
> Tokemak's fee parameters) ⇒ re-weigh to Medium.

This is the one place in the run where the *overstatement* guard needed to fire, and it fires against a
trigger rather than a finding.

---

## 6. New evidence surfaced in passing — `addresses.json` is wrong in **two** places

Measured on mainnet at block 25878009:

| `addresses.json` `"1"` entry | Value | On-chain reality |
|---|---|---|
| `autoDOLA` | `0x0538C8bAc84E95A9dF8aC10Aad17DbE81b9E36ee` | **`"vaDAI Pool"` / `vaDAI`** — `asset()` **reverts**; not an ERC4626. Real autoDOLA is `0x79eB84B5E30Ef2481c8f00fD0Aa7aAd6Ac0AA54d` |
| `MainRewarder` | `0x79dD22579112d8a5F7347c5976bC7b9812C2D4EA` | **zero code — no contract at this address at all** |
| `DOLA` | `0x8653773670…` | ✅ "Dola USD Stablecoin" |
| `TOKE` | `0x2e9d637882…` | ✅ "Tokemak" |
| `autoUSD` | *absent* | Wired and live (`0xa7569A44…`) despite story-049 targeting it |

The `autoDOLA` half is the **known open Low `L-17`** (run-16). The **`MainRewarder` dead-address half
appears to be new**, and is strictly worse than a wrong-but-live address: a deploy fed from this file
targets nothing.

**Severity: Low — an addendum to `L-17`, NOT a new Medium.** Nothing on chain is misconfigured: the
live strategies point at the correct Autopools (verified via each strategy's own `vault()`). The harm is
confined to a deploy-input artifact and would surface loudly. Filed rather than dropped (Law 1: recall
over tidiness), sized honestly rather than inflated.

---

## 7. Inflation sanity check — is any of the 12 Lows actually QA or Info?

**No finding is materially inflated.** Two rest partly on reasoning that is not a severity criterion;
both survive on their own merits and I recommend **keeping both at Low**:

- **`-09`** (`netWanted * MAX_BPS` panics on `type(uint256).max`). The closest Low→QA call in the run:
  no asset path, no consumer, and the classification concedes it stays Low even under `WATCH-17-03`.
  **Kept at Low** — two implementations of one interface member diverge on the idiomatic
  max-withdrawal sentinel (base returns capped principal; market reverts a bare `Panic(0x11)`), which is
  a spec defect rather than an absurd-input filter, and applying the run's own view-only-harm ⇒ Low axis
  uniformly demands it. Borderline ⇒ do not downgrade.
- **`-15`** (`vault.redeem` return discarded). Rated Low *"because of leverage, not impact"*. **Fix
  leverage is not a severity criterion** and that phrasing should be corrected. **Kept at Low** on its
  own footing: it is the mechanical enabler that makes `-01`/`-02` silent rather than loud, on the live
  path, with no `minOut` on `vault.redeem`. The recommendation to land it first is sound *as sequencing
  advice*, and should be stated as such rather than as severity basis.

`-10`, `-11`, `-16` at QA and `-12` at Informational are all correctly placed. `-07`'s Law-3 footgun
treatment is correct in both directions (kept for `-07`, declined for `-16`, where the failure is
loud and pre-deployment and so fails the surprise test). `-16`'s handling of the two invalid categories
(approve-race; weird-ERC20-except-USDT) is right: **USDT is the explicit carve-out and USDT is the token
that trips it**, so the carve-out is the basis, not a suppression.

---

## 8. Understatement audit — the direction the brief asked me to prioritise

Systematically checked for a Low that risks assets, a Medium mislabelled as theft, or an
under-described impact:

- **No finding demonstrates direct asset theft.** No High is being suppressed.
- **`-06` is the only finding whose harm needs no preview consumer**, and its deciding fact resolves to
  **V1 ⇒ Low**. That is a *resolution*, not a deferral — and its shelf-life is short.
- **`-04(b)`'s Medium leg was tested against live state, not argued away** — the throttle does not bind.
- **`-14`'s Medium leg was tested against source, not left open** — the window is re-initiable.
- **`-02`'s Medium leg was tested on chain, not assumed** — divergence real, magnitude dust.
- **The one place the run *did* understate is a reasoning defect, not a label**: the false-remedy claim
  in `-04` and `-08`. Struck above.

**Every Low in this run is now backed by a measurement or a source read rather than an unasked
question.** Four of the five obligations the classification listed as "owed before run-18" are closed
here; the fifth (`MR-17-04`, the unregistered `deployment-staging` implementer) remains open and is a
registration task, not a severity question.

---

## 9. Obligations I am carrying forward

1. **Strike the false-remedy bullets in `-04` and `-08`** before the QA bundle closes.
   `relinquishPrincipal` moves zero assets; say "no path returns underlying while the condition holds",
   and support Low on transience + owner lever + the measured non-binding throttle.
2. **Rewrite `-02`'s escalation trigger** with a magnitude threshold. As written it is mechanically
   tripped and will manufacture a false Medium.
3. **Close `-06`'s and `-14`'s "flagged for human review" flags**; replace with the hard reopen triggers
   recorded above.
4. **Record the block and the numbers** (block 25878009; autoDOLA 0.004729%, autoUSD 0.005300%;
   maxRedeem 100% on both) in the ledger entries so run-18 re-measures rather than re-argues.
5. **`WATCH-17-03`, `MR-17-05`, `MR-17-06`, `MR-17-03` must all survive triage** — endorsed unchanged.
   One `stable-staker` bump escalates `-01`..`-05` simultaneously with no scanner signal in between.
6. **File the `MainRewarder` dead-address as an addendum to `L-17`**, at Low.
7. **Known-issues suppression authority remains absent** for this project. No finding here was
   suppressed on those grounds; re-extraction is owed to project-manager.
