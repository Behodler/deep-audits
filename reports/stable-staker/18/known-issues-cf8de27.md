# stable-staker — Known Issues re-extraction @ cf8de27

**Run:** stable-staker-18
**Extracted:** 2026-09-01
**Source (declared):** `lib/stable-staker/CLAUDE.md` at commit `cf8de2718816a1c7df794dafb9d567e5694d826d` (613 lines)
**Supersedes:** the 26-item cache extracted at `96d39ed` (registry `knownIssues`, `knownIssuesExtractedAtCommit: 96d39ed4…`)
**Reason for re-extraction:** `CLAUDE.md` is in the `96d39ed..cf8de27` delta (stories 026 / 027 / 028). The `96d39ed` cache is therefore stale and carries **no suppression authority** until replaced by this file.

Verified again this run: `README.md` is a generic Foundry template with no Scope/Known-Issues section; no `known-issues.md` exists at HEAD. `CLAUDE.md` is the sole declared source.

**Count: 34** (N1–N34). Prior cache: 26.

---

## 1. Disposition summary vs the 96d39ed cache

| Fate | Items |
|---|---|
| KEPT verbatim in substance (re-anchored only) | N1, N2, N3, N4, N5, N7, N8, N9, N10, N11, N12, N13, N14, N15, N17, N19, N21, N22, N25 |
| MATERIALLY CHANGED | N6, N16, N20, N23, N24 |
| **GONE — suppression authority REVOKED** | **N18, N26** |
| NEW (stories 026 / 027 / 028) | N27, N28, N29, N30, N31, N32, N33, N34 |

Preserved rulings, carried forward unchanged and re-affirmed against HEAD:

- **N19 — caveat STANDS, no suppression authority.** Its self-justification still cites a section *"idle balance is automatically buffer"*. Verified at cf8de27: that string occurs exactly once in the file, at `:221`, and that occurrence **is the citation itself** — the cited section still does not exist. N19 evidences intent and nothing more.
- **N24 — LIMITED AUTHORITY** (ruled 2026-09-01, run 17), and story 028 narrows it further; see N24 below.
- **C8 (owner-trust / centralization) — registry-only, authority NONE.** Re-verified at cf8de27: `CLAUDE.md` contains no occurrence of "centraliz", "owner trust", or "trusted". Must never suppress an owner footgun (N23, N31, N34 are all footguns and stay in scope under Law 3).
- **C9-clause ("emergencyWithdraw callable even while paused") — registry-only, authority LIMITED.** Still derived from code, not from the declared source. May suppress a pause-interaction finding only; never generalize to "always callable" (`PoolState.Active` is still required).
- **C7 (drain-before-replacing-strategy operational requirement) — GONE / superseded** by the code-enforced empty-pool gate (now N8, `CLAUDE.md:331`). Authority NONE.

---

## 2. Items GONE from CLAUDE.md at HEAD — authority REVOKED

These two were live in the `96d39ed` cache and have been **deleted from the source by story 028**. They may not suppress anything from this run onward. Any finding they previously suppressed must be re-reasoned from scratch, not carried as suppressed.

### GONE-1 — former **N18**: the exit floor's rounding allowance
> *Cached text:* "The exit floor carries a ROUNDING allowance and only a rounding allowance (`EXIT_ROUNDING_ALLOWANCE` = 2 raw units + `EXIT_ROUNDING_ALLOWANCE_BPS` = 1 bp), sized so an honest ERC4626 double-rounding does not revert while a genuinely short delivery — or a preview lying to widen the raw-mint path around a closed claim — still reverts."

**Verification:** `grep -c EXIT_ROUNDING_ALLOWANCE CLAUDE.md` = **0** at cf8de27. The entire floor was removed — CLAUDE.md:155-157 now lists "no shortfall floor, no rounding allowance" among the complexity story 028 buys back. **Authority: NONE.**

### GONE-2 — former **N26**: `previewExitFor` advisory-only + measured-delta + `"exit shortfall"` revert
> *Cached text:* "The `previewExitFor` quote is ADVISORY ONLY … so it over-quotes on a fee-charging vault. The real balance delta is therefore measured and a delivery below the pro-rated guarantee reverts `'StableStaker: exit shortfall'`."

**Verification:** the quote-and-floor design was reverted out (vault-RM story 051 + stable-staker story 027). At cf8de27, `CLAUDE.md:192-200` describes it only in the **past tense** as "An earlier design", and the string `"StableStaker: exit shortfall"` survives solely inside that historical paragraph and in the story-028 narrative. **The measured-delta half survives** but with a completely different consequence (top-up, not revert) — that is now **N28/N30**, not N26. **Authority: NONE.**

> **Reconciliation flag for the sanitizer (not a ruling):** several OPEN ledger entries from run 17 are anchored on the code these two items described — `d5e4a0e6…` (L-02, shortfall floor blind to fee-charging vault), `7e86c0cf…` (L-04, dust-window `exit shortfall`), `19c0886b…` (L-06, `autoAnnihilateAvailable`), `8c5b7ecf…` (L-08, raw-mint bound), `eff1ce4b…` (L-05, gross draw from shared buffer), `d84cdfd4…` (L-09, docs), `9eb327d5…` (Q-01, `previewExitFor` first production consumer). Their subject code was **deleted**, not fixed-in-place. Route them to reconciliation; do **not** auto-suppress under a known issue and do **not** read non-reproduction as a verified fix.

---

## 3. Materially changed items

### N6 (CHANGED) — actual-received vs requested accounting
`[CLAUDE.md:333-337]` Exits forward the **actual received** amount (balance delta) while internal principal accounting is decremented by the **requested** amount; sub-amount differences remain protocol-owned yield/loss.
**Change:** the cached LIMIT clause is obsolete. It read "autoAnnihilate measures the delta and reverts 'StableStaker: exit shortfall' (N18/N26)". At HEAD `autoAnnihilate` still measures the delta but **never reverts on a shortfall** — it covers the gap with minted phUSD (N28). Rewritten limit: N6 applies to `withdraw` / `emergencyWithdraw` / `initiateMigration`; the `autoAnnihilate` path is governed by N28–N31 instead. Do not suppress an `autoAnnihilate` exit-path finding with N6.

### N16 (CHANGED) — the claim gate
`[CLAUDE.md:102-121]` `claimEnabled` is owner-settable and **false on deployment**; while down, `autoAnnihilate(token)` is the reward path. Declared a teaching phase, not a permanent design; `setClaimEnabled(true)` reopens claim in one transaction.
**Change:** the signature is now `autoAnnihilate(address token)` — the caller-supplied `minPhUSDOut` was **removed** (see N32). The cached item quoted the two-argument form.

### N20 (CHANGED, and now broader) — self-sandwiching
`[CLAUDE.md:228-238]` Verbatim heading: *"Self-sandwiching is bounded, extractable, and ACCEPTED — this is the front-running note."* A caller who sandwiches their own `autoAnnihilate` through `ERC4626MarketYieldStrategy`'s AMM **keeps the sandwich profit and is still paid the frictionless figure**, because the protocol mints the difference. Bounded three ways: the strategy's own `minOut` from `slippageToleranceBps`; a real AMM round trip; and the caller's own stake and accrual. *"Shifting exit slippage onto the protocol is the explicit goal, so this is priced in rather than defended against."*
**Change:** the cached rationale — "a worse AMM rate annihilates less and mints more raw Antimatter … extraction is capped at the tolerance" — is **superseded**; raw Antimatter is no longer the leakage vehicle (N28). The accepted-extraction claim is now *larger* than it was, and it carries a new **owner obligation**: *"The operational lever is `slippageToleranceBps` — set it as tightly as the market allows."* An unset/loose tolerance is an owner footgun in scope under Law 3; N20 accepts the *bounded* leak, not an unbounded one.

### N23 (CHANGED) — was "two-pause deadlock", now **THREE pause surfaces**
`[CLAUDE.md:248-254]` `Antimatter.annihilate` is `whenNotPaused` against Antimatter's own pauser, which StableStaker does not control; **`PhusdStableMinter` adds a third pauser of its own, plus a per-stablecoin `enabled` flag and a rolling 24h `maxMintPerDay` cap**, reached on every annihilation. With `claimEnabled == false`, a pause on **any** of them leaves stakers with no reward path at all. Intended response is operational: the owner flips `claimEnabled` true for the duration. An obligation on the StableStaker owner key — **owner footgun, in scope under Law 3**.

### N24 (CHANGED — NARROWED by story 028; run-17 LIMITED AUTHORITY ruling PRESERVED)
`[CLAUDE.md:255-279]` "Auditor note — annihilation exceeding principal". Story 028 adds an explicit scope paragraph at `:257-260`: the note is now about reward that outran the caller's principal **outright and nothing else**; the earlier, wider version that also covered Antimatter displaced by an exit shortfall is **superseded**, because a shortfall no longer displaces anything into raw Antimatter. `excess` now has exactly one source.
**Authority ruling, carried forward unchanged from run 17:** LIMITED. It establishes INTENT only — it suppresses a Law-2 "unintended bypass" framing and **nothing else**. Its rationale bullet 2 ("takes a long time at realistic emission rates") remains **falsely exhaustive**: it addresses only organic accrual growing the numerator, not a caller shrinking the denominator by withdrawing principal to ~0 while the story-022 backlog stays booked in `unclaimedReward`. Its bullet 3 ("flipped on within weeks") is an unenforced operational assertion. Its closing paragraph binds the other way and is unchanged at `:277-279`: *"Nothing in the protocol's safety argument may depend on antimatter being unobtainable while the flag is false"* — so `claimEnabled` may not be cited to discount any finding's severity.

---

## 4. NEW items (stories 026 / 027 / 028)

### N27 — V2 can mint phUSD; this is NOT a dual-emissions design (story 026)
`[CLAUDE.md:25-38]` V2 holds a second minimal local interface `src/interfaces/IPhUSD.sol` (`mint`, `mintVersion`, `authorizedMinters` — the latter two forming the probe `phUSDMintAvailable()`) for **exactly one purpose**: covering the `autoAnnihilate` exit shortfall. The token is resolved **live** via `phUSDToken()` off Antimatter's mutable `phUSD`, never cached and never a constructor argument. Antimatter remains the sole reward token for claims, withdrawals, deposits, APY accounting and migration. Verbatim: *"A reader who finds phUSD minting in V2 and infers a dual-emissions design has inferred wrong."*

### N28 — **story-028: the exit shortfall is COVERED BY THE PROTOCOL in freshly minted phUSD** *(the item the coordinator asked about — YES, it is documented as known and accepted)*
`[CLAUDE.md:139-160]` Verbatim heading: *"**The exit shortfall is measured, then COVERED BY THE PROTOCOL in freshly minted phUSD** (story 028)."*

`autoAnnihilate` requests exactly the net the annihilation needs (already capped at the caller's own `user.amount`), debits `user.amount` and `pool.totalStaked` by that request, takes `_routeExit`'s measured balance delta as the amount it may actually annihilate — and then pays the caller what a **frictionless** annihilation would have paid, minting the difference as new phUSD. Worked example at a 3% haircut, verbatim from the source:

```
request      100 U from the yield strategy
received      97 U          (measured balance delta; 3 U lost to the exit)
mint           97 A         to the staker itself
annihilate     97 A + 97 U  ->  194 phUSD delivered
frictionless  100 A + 100 U ->  200 phUSD
staker mints    6 phUSD     the deficit
--------------------------------------------------------------
the caller receives 200 phUSD, is debited 100 U of principal and 100 A of accrual
```

The acceptance is explicit and verbatim:

> "This deliberately shifts slippage risk off the user and onto the protocol, as a gift funded by phUSD inflation. It buys back a whole class of complexity: no exit preview, no gross-up arithmetic, no shortfall floor, no rounding allowance, and no revert path for an under-delivering strategy. All divisions floor, always in the protocol's favour — 199.999 phUSD instead of 200 is correct and accepted. **Antimatter remains the sole reward token**; phUSD minting happens here and nowhere else."

**Suppression authority: LIMITED, and it does not extend to backing.** The item documents intent for the *mechanism* (protocol absorbs exit slippage as phUSD inflation) and for the *rounding direction*, so a finding framed purely as "the protocol pays the user's slippage" or "the payout floors by a wei" is covered. It says nothing about, and therefore cannot suppress: (a) whether the freshly minted phUSD is **backed** — the mint is unbacked inflation by construction, and the standing repo memory that Phoenix over-payment is mere opportunity cost is **void for V2**; (b) the size or unboundedness of the inflation across many callers or many calls; (c) the interaction with N20's now-larger accepted extraction, where a self-sandwiching caller is paid the frictionless figure out of that same inflation. Those are Law-1 questions the source does not address.

### N29 — the payout target is COMPUTED, not `2 × annihilated`
`[CLAUDE.md:162-167]` Verbatim: *"Do not read the payout as `2 x annihilated`."* That identity holds only while the stable minter's `exchangeRate` is exactly `1e18`, *"which is what the test fixture happens to register"*. The target is `netWanted * scale + phUSDMinter.calculateMintAmount(token, netWanted)`, reached by a two-hop **live** read `antimatter.phUSDMinter()` → `calculateMintAmount`, declared locally as `src/interfaces/IPhusdStableMinter.sol`. The concrete `PhusdStableMinter` is never imported into `src/` (two relative imports into a third level of submodule nesting).
**Note for the scanners:** the source itself concedes the test fixture pins `exchangeRate == 1e18`, i.e. the non-unity rate path is documented but **not fixture-covered**.

### N30 — "A returned quote is not a promise"
`[CLAUDE.md:169-181]` `calculateMintAmount` **ignores** `enabled`, the minter's own pause, and the rolling 24h `maxMintPerDay` cap, and **returns 0 rather than reverting** for an unregistered stablecoin. The target is computed from it, but what was actually **delivered** is derived by measuring a phUSD balance delta — `annihilate` is called with `recipient = address(this)` precisely so that delta exists. A cap or pause biting at `PhusdStableMinter` reverts the whole call atomically and the caller keeps their principal and accrual.

### N31 — the top-up **fails closed**, and a global revoke can close the reward path
`[CLAUDE.md:183-190]` If the deficit cannot be minted — `phUSDMintAvailable()` false, *"which `phUSD.revokeAllMintPrivileges()` can cause with no transaction ever touching this contract"* — the call reverts `"StableStaker: phUSD mint unavailable"` rather than silently falling back to minting the displaced Antimatter raw. Reverting was chosen because the fallback pays a different asset than promised and hides an operational fault. Verbatim cost statement: *"The cost is that a revoked grant closes the reward path while `claimEnabled` is false — the same shape as the two-pause deadlock below, with the same answer, `setClaimEnabled(true)`."* A frictionless exit needs no top-up and is unaffected.
**Authority: intent only.** The remedy is operational and depends on an owner noticing an off-contract, un-evented revocation; that is an **owner footgun in scope under Law 3** (Law 3 exempts obvious misuse, not non-obvious cross-contract consequences), and C8 may not suppress it.

### N32 — `minPhUSDOut` removed: a deliberate breaking ABI change
`[CLAUDE.md:112-117]` Story 028 removed the caller-supplied `minPhUSDOut` from `autoAnnihilate`'s signature — *"a **breaking ABI change**, free because V2 is undeployed and `phase-2-staging` has no V2 deploy script."* The rationale: the caller gains nothing from a floor on a payout StableStaker itself now guarantees. It is **not** dropped to zero — an exact floor, sized against the amount actually being annihilated, is still handed to Antimatter, as the only in-path guard against the exchange rate moving or a mint cap biting between quote and burn.
**Note:** the "free" premise is a checkable factual claim about a sibling repo (`phase-2-staging` has no V2 deploy script), not a design decision — verify it rather than accept it.

### N33 — no strategy-side availability condition remains
`[CLAUDE.md:225-227]` Verbatim: *"There is no strategy-side availability condition left: delivery is measured, never pre-judged, so even a strategy that delivers nothing at all simply makes the whole payout a top-up. `autoAnnihilateAvailable(token)` answers only the stable-minter registration question."*
**Change note:** this replaces the cached statement that a strategy guaranteeing nothing (100% slippage tolerance, answering `(0,0)`) makes `autoAnnihilateAvailable` false and `autoAnnihilate` revert. That behaviour is **gone**; a zero-delivery strategy now produces a 100%-inflation-funded payout. Directly relevant to open entry `19c0886b…` (L-06).

### N34 — wiring step 3: the phUSD mint grant, and the global-revoke sweep
`[CLAUDE.md:281-309]` The deployment runbook gains a step 3: *"phUSD owner calls `phUSD.setMinter(address(staker), true)`. **This is not a reward-token change.**"* Read `staker.phUSDMintAvailable()` back afterwards — the two-condition probe (`canMint` AND a current `mintVersion`) is *"the only honest check that the grant took"*. Ordering constraint: `phUSDToken()` resolves live off `antimatter.phUSD()`, so step 3 must come **after** Antimatter's `setPhUSD`, and a later `setPhUSD` rotation needs the grant re-issued on the incoming token. Verbatim hazard: *"Beware `phUSD.revokeAllMintPrivileges()`: it bumps a GLOBAL `mintVersion` and de-authorises every minter at once, with no per-minter transaction and no event naming the staker."*
Migration wiring restated: V2 and onward need **both** grants (Antimatter approved-minter = the reward token; phUSD minter rights = purely shortfall cover); the frozen V1 needs only phUSD, which *was* its reward token.

---

## 5. Items KEPT (re-anchored to cf8de27)

- **N1** `[:85-100]` Core emission-cap invariant; since story 022 the carrying statement is `sum(unclaimedReward) + minted <= cap`. `_updatePool` is the only writer of `accAntimatterPerShare`.
- **N2** `[:92-96]` Integer-division dust always rounds DOWN (protocol's favour); empty-pool windows accrue nothing; flash staking earns nothing — by design. *Extended by story 028* `[:157]`: "All divisions floor, always in the protocol's favour — 199.999 phUSD instead of 200 is correct and accepted." (Open entry `9ee2d98f…` / Q-04 disputes the "always rounds DOWN" claim by 1 wei; unchanged by this re-extraction.)
- **N3** `[:96-97]` `antimatterPerDay` settles the pool at the OLD rate before changing it — by design.
- **N4** `[:45-49]` Deferred booking (story 022): `emergencyWithdraw` forfeits the `unclaimedReward` backlog as well as live pending ("no reward, principal out", never mints); `claim` is still `whenNotPaused`, so a pause withholds the backlog too.
- **N5** `[:336-343]` Yield stays protocol-owned: stakers get principal plus Antimatter emissions only; the farm never reads `totalBalanceOf` to credit a user; accrued yield accumulates in the strategy as protocol-owned surplus (skimmed via `skimSurplus`).
- **N7** `[:345-352]` Underwater withdraw block: while below par, `withdraw` reverts `"StableStaker: strategy underwater"`. `emergencyWithdraw` and `initiateMigration` are intentionally NOT blocked. `withdrawDisabled(token)` is the public view.
- **N8** `[:331]` `setYieldStrategy` reverts `"StableStaker: pool not empty"` unless `totalStaked == 0` — code-enforced, empty-pool-only. Supersedes cached C7.
- **N9** `[:353-366]` Terminal migration is terminal: once engaged a token's pool can never resume healthy operation (no resume path); `stake`/`withdraw`/`emergencyWithdraw`/the old staker's `depositFor` are blocked while active to preserve the `P` snapshot.
- **N10** `[:376-381]` `CrossVersionMigrator` deliberately does NOT carry `InPlaceMigrator`'s story-013 surplus-funded top-up; a cross-version migration through an underwater strategy credits the uniform snapshot haircut. Stated as a real product difference wanting a human decision before running on a live, underwater user base.
- **N11** `[:499-511]` Frozen V1 defects `ss14m1` and `ss14l8` are preserved **deliberately** in `src/versions/v1/`. An audit re-filing those two against `src/versions/` should be triaged "deliberately preserved", not actioned.
- **N12** `[:15-18]` The byte-frozen `src/versions/v1/StableStakerV1.sol` emits phUSD and always will — the live mainnet V1 instance is deployed and unpatchable; correct and permanent, not an oversight.
- **N13** `[:525-533]` V1 has no `STAKER_VERSION` getter, so a static call to it reverts; version probes must use low-level `staticcall` and treat a revert as "version 1". The frozen `StableStakerV1.sol` must never gain the getter (`test/StableStakerV1Frozen.t.sol` asserts its absence).
- **N14** `[:399-403]` Known fallout of the story-018 `StableStakerMigrator` removal, deliberately left unrepaired as a cross-repo follow-up: `phase-2-staging`'s `script/DeployTempStableStakerAndMigrators.s.sol` and `test/YsSwapMigrationHardening.t.sol` import the deleted contract and no longer compile.
- **N15** `[:441-445]` Known gap in the migration-surface `PreToolUse` hook: it only fires when `stable-staker` is the session's project root, and this repo is normally driven as a submodule.
- **N17** `[:134-137]` Sub-unit dust left by the decimals flooring stays in `unclaimedReward` — not minted, not transferred; accrues to the next call, rounds in the protocol's favour.
- **N19** `[:204-224]` The idle buffer is never the payer **on a solvent strategy**; story 028 does not change that, and now argues it *by construction* (only the measured `netUsed` is approved and annihilated; the top-up is freshly minted phUSD, not a draw on any pooled asset), asserted against a deliberately fat buffer across the haircut grid in `test/AutoAnnihilate.t.sol`. The carve-out is the **underwater** path: when `_isUnderwater`, `_routeExit` pays the whole request from idle balance plus `relinquishPrincipal` and returns the nominal amount without measuring. **CAVEAT (unchanged, re-verified at cf8de27):** the carve-out justifies itself by citing a section *"idle balance is automatically buffer"* that **does not exist** in `CLAUDE.md` at HEAD — the sole occurrence of that string, at `:221`, is the citation itself. N19 evidences intent and carries **NO suppression authority**.
- **N21** `[:242-249]` Registered-stable coupling: `Antimatter.toStableAmount` reverts `StablecoinNotRegistered` unless the pool token is registered with `PhusdStableMinter`. `autoAnnihilate` pre-flights it (`"StableStaker: token not annihilatable"`); `autoAnnihilateAvailable(token)` exposes it.
- **N22** `[:246-247]` Migration carve-out: the Antimatter mint inside `_exitPosition` is deliberately NOT gated by `claimEnabled`, because gating it would let a closed claim gate brick migration.
- **N25** `[:127-133]` Decimals scale is read **live** from `IERC20Metadata(token).decimals()` rather than cached at `addToken`: a cache would need backfilling for pools already registered on live instances and mis-scales silently if decimals move, whereas a live read fails closed. Antimatter cross-checks the same number against the stable minter's registration (`DecimalsMismatch`).

---

## 6. Related source change worth recording (not itself a known issue)

`[CLAUDE.md:594-601]` The `lib/reflax-yield-vault` pin moved `cdd0743` → **`25276b8`**, described as vault-RM story 051's revert of `IYieldStrategy.previewExitFor`. Verbatim: *"the pin deliberately moved FORWARD past the revert rather than back to `0110ce4`, so vault-RM story 049's live-on-mainnet `convertToAssets` fix in `ERC4626YieldStrategy._depositToVault` is retained."* Every direct implementer of the interface in this repo's tests must match the interface exactly or the suite will not compile.

---

## 7. Sanitizer usage rules for run 18

1. This file, at commit `cf8de27`, is the **only** authoritative known-issues set for run 18. The registry's 26-item `knownIssues` array is stale and must not be applied.
2. **N18 and N26 suppress nothing.** Findings previously covered by them go to reconciliation, not to the suppressed bucket.
3. **N19 suppresses nothing** (unanchored self-citation).
4. **N24 is intent-only**, limited exactly as stated above; `claimEnabled` may never be cited to discount severity.
5. **C8 suppresses nothing.** N20's `slippageToleranceBps` obligation, N23's three pause surfaces, N31's revoked-grant path, and N34's global-revoke sweep are **owner footguns in scope under Law 3**, not centralization noise.
6. **N28 does not cover backing or unboundedness.** It authorises the mechanism and the rounding direction only.
