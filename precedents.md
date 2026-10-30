# Triage Precedents

The common law of this audit: general rulings, made by a human while triaging, about how a **class** of finding is judged. The **precedent-triager** agent applies them automatically during `/analyze`, `/full-audit` and `/audit-script`, and every application is recorded in `<project>/reports/NN/triage-decisions.md` for human override.

## How this file works

- **Authority.** Only a human makes, widens, narrows or retires a precedent, via `/ledger <project> precedent add|narrow|retire` or by confirming a draft that `/ledger` proposes after a triage. The model never writes one on its own judgement.
- **Status.** `active` and `narrowed` precedents are applied. `draft` precedents are **never applied**: they await a human ruling, usually because the evidence is auditor-derived or conflicts with another ruling. `retired` precedents are never applied and never deleted, because ledger entries cite them.
- **Premise first.** Every applicable precedent lists the conditions that must still hold at HEAD. precedent-triager checks each one with cited evidence before applying. A failed premise or a fired `reopenWhen` trigger means **⚠ EXPIRED PRECEDENT**: the finding is kept at full severity and flagged.
- **Effects.** `suppress` writes ledger status `precedent-suppressed` and the finding is not reported. `downgrade` and `escalate` move severity to `to` and keep `originalSeverity`. `annotate` attaches guidance without changing severity or status.
- **Law-1 limits.** These cannot be overridden by any precedent. A precedent never suppresses a High. It never touches a regression, a `fix-pending` entry or an incomplete fix. It never overrides a human status. It only *proposes* changes to entries that are already `open`.
- **Conflicts.** The precedent serving the lower-numbered law wins (security > story > owner trust). If that does not decide it, neither is applied and the conflict is flagged.
- **Scope of this file.** Project-specific dispositions of single findings stay in each ledger's `triageReason`. Tooling and method lessons stay in memory. Only reasons that decide *other* findings belong here.

Seeded 2026-10-31 from the auto-memory and from the triage reasons in all nine ledgers. Provenance cites the issue ID or label, the fingerprint prefix and the date. Quotes are verbatim.

---

## Owner trust (Law 3)

### P-001 — Do not report malicious-owner or obvious-misuse vectors
```yaml
id: P-001
status: active
effect: suppress
scope: global
appliesWhen: >-
  The exploit requires the owner/admin to act maliciously, or to make a mistake whose harmful
  consequence is obvious to a competent operator (e.g. set price = 0, point at a malicious token,
  pause to grief, revoke the protocol's own mint authority).
premise:
  - The triggering action is held only by the owner/admin role (not permissionless, not a keeper).
  - A competent, non-malicious owner would NOT be surprised by the consequence.
reopenWhen:
  - The path becomes reachable by a non-owner (permissionless, keeper, delegated role).
provenance: >-
  CLAUDE.md Law 3; memory owner-driven-attacks-invalid. Owner rulings: phlimbo V2-M-02 6ff5594bcd
  ("obvious owner shutdown action with a safe operational ordering => trusted"); reflax H-01
  f4eb23ce86 / H-03 2a3d559aee (timelock "cosmetic by design in an owner-trusted model"); ycn Q-08 96c60b723f.
```
The surprise test decides it. If the consequence would surprise a well-meaning owner, P-002 applies instead.

### P-002 — Non-obvious owner footguns are in scope and must not be stripped
```yaml
id: P-002
status: active
effect: escalate        # no `to`: keep severity, mark priority elevated, forbid suppression as owner-driven
scope: global
appliesWhen: >-
  An owner action a careful operator would plausibly take has a non-obvious consequence that
  unknowingly enables an exploit (Law 1) or breaks a story (Law 2) — including when documentation
  or a runbook over-claims completeness and so leads the owner into it.
premise:
  - The consequence is not foreseeable from the function's name, NatSpec, or runbook.
reopenWhen: []
provenance: >-
  CLAUDE.md Law 3; memory audit-three-law-hierarchy. Example: SYA run-14 setRewardToken brick
  0xd62cbfe8 (runbook claimed "three failure modes" and omitted the setter).
```
Frame these as operational hazards with safe-config guidance, at honest severity.

### P-003 — Footguns an attended sole operator will not fall into are accepted, with a compensating control
```yaml
id: P-003
status: active
effect: suppress
scope: phoenix-phase-2-staging, stable-staker:migration
appliesWhen: >-
  A deployment/migration/cutover script or migration path has an ordering or precondition hazard
  that only bites if the operator runs it carelessly, and the owner has ruled it operator
  responsibility.
premise:
  - The owner is the sole operator and runs the step attended.
  - The compensating control named in the finding's triage (runbook step, pause wrapper) still exists.
reopenWhen:
  - The step becomes unattended, keeper-driven, permissionless, or delegated to a second operator.
  - The script's preconditions change.
provenance: >-
  Owner: phStaging cf684d5dc2 (2026-09-18) "a footgun the owner, as sole operator, will not
  accidentally fall into"; 18ca984219 / 97e987d078 (06-15) "accepted as operator responsibility …
  do NOT re-escalate unless the script's preconditions change"; 85095591a6 / 8142ab6d39 (10-19);
  stable-staker e4567dc343 "IF MIGRATION IS EVER MADE PERMISSIONLESS, KEEPER-DRIVEN, OR OTHERWISE
  UNATTENDED" → revisit.
```

### P-004 — A dependency held by the same principals is owner trust, not an external trigger
```yaml
id: P-004
status: active
effect: downgrade
to: low
scope: global
appliesWhen: >-
  A finding's trigger is the revocation or misconfiguration of an authority (e.g. phUSD mint role)
  held by the same principals that own the affected contract.
premise:
  - The authority and the affected contract share an owner on-chain at HEAD (verify; this is
    convention, not a code guarantee).
reopenWhen:
  - Ownership of the dependency and the contract diverge.
provenance: >-
  Human 2026-07-16 on phlimbo V3-M-07: mint authority is "the same principals", revocation is
  "cutting off nose to spite the face" (later fixed anyway for regression detection). SYA run-14
  reopen trigger: "sharing an owner — which is convention, not a code guarantee".
```

## Value and loss framing

### P-005 — Integer-division dust that rounds in the protocol's favour is by design
```yaml
id: P-005
status: active
effect: suppress
scope: global
appliesWhen: >-
  Rounding/truncation leaves dust (bounded by one unit of the token's precision per operation, or
  a stated per-batch bound) on the protocol side of a user↔protocol accounting step.
premise:
  - The rounding direction favours the protocol (verify the direction at HEAD; "always rounds
    down" claims have been off by 1 wei — stable-staker run-16 Q-04).
  - Dust per operation is bounded and does not compound across operations.
  - The loss is solvency dust, not a shortfall in value delivered to a user.
reopenWhen:
  - Rounding favours the user (extractable by repetition).
  - Truncation zeroes an entire emission or payout (e.g. amountPerDay < 86400 → zero rate,
    stable-staker-07 L-01 d47619d2) — that is a distinct, reportable class.
provenance: >-
  stable-staker known issue #2 ("Integer-division dust always rounds DOWN (protocol's favour) … by
  design", from stable-staker/src/CLAUDE.md), applied by the user to 35e9be8d59 (2026-06-01).
  Owner on phoenix M-03 38ea47b14c (2026-07-26): "that sort of dust shuffling is acceptable in DeFi".
  phlimbo SolvencyDetermination.md:64-65 "surplus favouring the protocol".
```
NatSpec stating "all rounding favours the protocol" (reflax ERC4626 strategies, StableStakerV2:639) is **not** evidence for the premise (see P-033). Verify the direction from the arithmetic.

### P-006 — Over-payment funded by externally-derived yield is opportunity cost, not value leak
```yaml
id: P-006
status: narrowed
effect: downgrade
to: qa
scope: global
appliesWhen: >-
  A finding's impact is "the protocol pays out more than it receives" from a pot or incentive
  funded by yield on protocol-owned principal (nudge pots, batchMinter, phlimbo rewards).
premise:
  - The funding source is externally-derived yield, not principal and not user deposits.
  - The emitted token is not redeemable into unbacked value by its holder.
reopenWhen:
  - Principal or user funds are impaired.
  - A claimant takes OTHER USERS' money (e.g. forfeited refunds accreted into the pot).
  - The contract is StableStakerV2 or any emitter of Antimatter (redeemable via annihilate).
provenance: >-
  Owner 2026-07-26 on phoenix M-01 96823199d2 / M-02 c7a410602b: "MARKETING SPEND"; the pot "has
  NEVER ONCE reached even 50%" of qualifying cost. Narrowed 2026-08-31 (stable-staker run-16) for
  StableStakerV2. Memory externally-derived-yield-opportunity-cost-not-loss.
```
`NudgeStreamer` metering is a rate control for price discovery, not a failed cap. Falsifying an inaccurate docs sentence ("every claim is net-positive") is a documentation finding, not a vulnerability.

### P-007 — Commingled share caps across strategy clients socialize losses by design
```yaml
id: P-007
status: narrowed
effect: suppress
scope: reflax-yield-vault, stable-staker
appliesWhen: >-
  The global-vs-per-client share cap in _disposeShares (ERC4626YieldStrategy /
  ERC4626MarketYieldStrategy) lets one client's redemption draw on the pool shared with others.
premise:
  - Every non-staker client on the vault is a non-redeeming minter (check the live client set per
    strategy and token).
  - The losing side is the minter cushion, not a redeeming user claim.
reopenWhen:
  - A redeeming (non-minter) second client is authorized on a shared vault.
  - The finding concerns the surplus direction (reflax L-23 e6088a0ec5) or StableStakerV2's
    Antimatter leg — not covered.
provenance: >-
  Owner 2026-08-29: "The phUSD minter, being a client who can't withdraw, allows its balance to be
  diluted or tapped into by stable-staker … a cushion for stable-staker withdrawals during bad times."
```
Never recommend narrowing to a per-client cap: that breaks the cushion. This does not bless the ordering of exits among stable-staker's own users.

### P-008 — The designed Antimatter half of phUSD issuance settles already-earned yield
```yaml
id: P-008
status: active         # activated 2026-10-31 by owner, with the reconciliation below
effect: suppress
scope: antimatter, stable-staker:StableStakerV2, phoenix-phase-2-staging:PhusdStableMinter
appliesWhen: >-
  Findings that the designed 1:1 Antimatter half of phUSD issuance bypasses daily caps, budgets,
  or collateral. NOT covered: Antimatter emitted beyond schedule or entitlement, which is priced
  as real phUSD dilution (stable-staker-v2-emits-antimatter-premise-void stands for that excess).
premise:
  - Antimatter magnitude stays yield-scale (much smaller than principal).
  - Antimatter is emitted only per schedule/entitlement.
reopenWhen:
  - Antimatter is emitted beyond schedule or entitlement (that excess is priced as dilution).
provenance: >-
  Owner: antimatter M-02 64807f2b14 "antimatter was generated from prior stablecoin staked … value
  in the protocol that has already been generated"; M-03..M-05 (2026-08-19) "Antimatter earned its
  legs elsewhere"; stable-staker L-01 9c5733dfad (09-02) "relative magnitudes … cover the concern";
  reflax L-31 b9203a0da7 (10-28). Conflict with memory stable-staker-v2-emits-antimatter-premise-void
  (auditor, 08-31) resolved by owner 2026-10-31: the designed 1:1 half is accepted; AM beyond
  entitlement is dilution and stays reportable.
```

### P-009 — Value-positive donations and sweeps into protocol-owned liquidity are not findings
```yaml
id: P-009
status: active
effect: suppress
scope: global
appliesWhen: >-
  An "attack" whose only effect is to donate value to the protocol: donating to an external ERC4626
  to move its rate, or a whole-balance sweep that can only route stray funds into POL.
premise:
  - Every path of the donated/swept value ends in protocol-owned liquidity or protocol balance.
  - No third party's funds are swept (accidental user sends are a separate, QA-level question).
reopenWhen:
  - The rate move can be monetized elsewhere for more than the donation.
provenance: >-
  Owner on ycn L-13 ac8eadefd1 (2026-07-18): "DESIRED FEATURE … donated ETH only ever reaches
  protocol-owned LP"; "I like that feature". reflax M-02-run11 c7329862eb (sUSDe donation, manual review).
```

### P-010 — "No funds at risk" UI or dev-workflow inconvenience is not Medium
```yaml
id: P-010
status: active
effect: downgrade
to: low
scope: global
appliesWhen: >-
  The impact is a UI showing the wrong thing, a dev/test workflow going stale, or a factual error
  in a story — with no asset, availability or value impact on chain.
premise:
  - No funds and no on-chain function are affected.
reopenWhen:
  - The UI error leads users to sign a transaction that loses value.
provenance: >-
  Owner phStaging M-02 8aa45828a2 (2026-09-08): "not medium as no funds are at risk. It's just a UI
  inconvenience"; L-07 6b63ef6516; L-02 ec29eacd95. In /audit-script, a defect outside the entry
  point's closure is a scope decision (M-03 3b7430a7a4: "A SCOPE DECISION, NOT A JUDGEMENT THAT THE
  UNDERLYING DEFECT IS INVALID") — re-file it under the right entry point, never drop it.
```

### P-011 — Fee-on-transfer is invalid, except where it drains pooled balances of other tokens or users
```yaml
id: P-011
status: active
effect: escalate        # no `to`: a FoT finding of the pooled-balance class must not be stripped by the C4 FoT rule
scope: global
appliesWhen: >-
  A fee-on-transfer finding where crediting the amount sent rather than received is drawn against
  a balance pooled across other tokens, streams, or users.
premise:
  - The shortfall lands on a party other than the depositor of the taxed token.
reopenWhen: []
provenance: >-
  Owner set phStaging M-01 a753907e2a fix-pending (2026-07-29): one taxed token drains sibling
  streams. Otherwise FoT stays invalid (phlimbo V3-L-04, run-11: startPromotion rejects FoT).
```

## Slippage, MEV and front-running

### P-012 — MEV bounded by a configured slippage tolerance is accepted
```yaml
id: P-012
status: active
effect: suppress
scope: global
appliesWhen: >-
  Sandwich/MEV exposure on a swap or LP operation whose loss is capped by a slippage floor fixed at
  signing, where the value at risk is protocol-owned liquidity or capped per call.
premise:
  - The floor is mandatory and not stale (cross-repo: the minOut floor in reflax, obligation XR-18-02).
  - The attacker's breakeven exceeds the configured tolerance (e.g. 120 bps live vs 142 bps breakeven).
reopenWhen:
  - Tolerance is raised to or above breakeven, or the floor becomes optional/stale.
  - User funds rather than POL are exposed.
provenance: >-
  Owner ycn L-22 a846cc40e6 (2026-10-01): "That's the nature of tolerance. We're literally
  tolerating an attack of this size." Also ycn L-15 e64f73d629, L-06 342075dfba, L-23 c15c71fd22
  ("a lightning strike rather than a common inconvenience"); stable-staker M-01 4a5a00bbcc
  (09-02) "The yield strategies have max slippage settings"; reflax M-02 d7f6c2dfd5 "We accept the residual."
```

### P-013 — `deadline = block.timestamp` on keeper-gated calls with fixed floors is not a finding
```yaml
id: P-013
status: active
effect: suppress
scope: global
appliesWhen: >-
  A swap/LP call uses deadline = block.timestamp (or none), its min-out floors are fixed at signing,
  and the caller is a permissioned keeper/owner.
premise:
  - Min-outs are fixed at signing, not computed on-chain at execution.
  - The caller is permissioned.
reopenWhen:
  - The call is permissionless, or the floor is computed at execution time.
provenance: >-
  Owner 2026-10-01, ycn Q-12 69f9f9ca67 and Q-20 a9037a2f96: "a held keeper transaction can only
  execute within the same tolerance bound … delay gives a front-runner nothing beyond what
  same-block manipulation already gets." Not ruled for Uniboost.pool.
```

### P-014 — Front-running an incentive pot is accepted when a caller-set minimum protects the honest user
```yaml
id: P-014
status: narrowed
effect: suppress
scope: phoenix-nft-staking, yield-claim-nft (nudge pots, BatchNFTMinter, NFTBonfire)
appliesWhen: >-
  First-claimer or winner-take-all front-running of a protocol-funded incentive pot, where the
  front-runner must genuinely participate, or a caller-set minPayout/minReward reverts the honest
  user's transaction before they lose anything but gas. Includes same-denomination arbitrage when
  paymentToken is also a nudge token.
premise:
  - The pot stays below the qualifying cost.
  - The UI passes a non-zero minimum.
reopenWhen:
  - The argument depends on NFTs having no redemption value — EXPIRED since NFTBonfire (ycn MR23-001).
  - Over-funding is permissionless and the mechanism is value-blind (phoenix 858e9e80 premise died at run-20).
provenance: >-
  User on phoenix M-01 521c20ad48 (2026-05-30): "a front-runner who claims must genuinely join the
  protocol". Owner ycn Q-26 fcb67df2d2 / L-29 589c642bd0 (2026-10-27): "the min payout protects
  against front running as much as anything can be expected to." Owner 2026-07-25 on paymentToken
  ∈ nudgeWhitelist (memory payment-token-as-nudge-token-decision).
```

### P-015 — Slippage floors and minimums are the UI's responsibility
```yaml
id: P-015
status: active
effect: suppress
scope: global
appliesWhen: >-
  A user-facing function accepts a caller-supplied floor (minOut, minReward, minPayout) and the
  finding is that a 0 or 1-wei value leaves the caller unprotected.
premise:
  - The parameter is caller-supplied and documented, and the owner has said the UI sets it.
reopenWhen:
  - The floor is hardcoded in a script or contract rather than supplied by the UI.
  - The function is called by another contract that passes 0.
provenance: >-
  User phoenix L-05 990d8c37b4 (2026-05-30) "front-end enforcement is the responsible owner"; owner
  phStaging L-01 357565f842 (2026-10-30) "I'll deal with it on the ui side"; ycn Q-26.
```

## Failure, recovery and lifecycle

### P-016 — Recoverability caps severity
```yaml
id: P-016
status: active
effect: downgrade
to: low
scope: global
appliesWhen: >-
  A brick, freeze or stuck-funds condition triggered by owner configuration (or a blue-chip-only
  token assumption), where nothing is stolen and the owner can recover or migrate away.
premise:
  - A concrete recovery path exists at HEAD and is enumerated with evidence (every owner-settable
    pointer and every onlyOwner on the wired strategy — never assert "no remedy" unchecked).
  - The trigger is owner-held.
reopenWhen:
  - The trigger becomes reachable by a third party.
  - Recovery requires a contract upgrade that does not exist.
provenance: >-
  Owner antimatter L-04 25088b5989 / L-05 3a8dbad19b (2026-08-21): "we're not just willy nilly
  adding any old token … I'd rather plan for exploits and recovery from bricking than try to
  anticipate every brick. If funds are stuck … we must be able to always migrate away." phlimbo
  V3-M-08 4f97b39e8f (07-17): "nothing malicious or permanent".
```

### P-017 — On attended, permissioned paths a loud revert is a working alarm
```yaml
id: P-017
status: active
effect: downgrade
to: qa
scope: global
appliesWhen: >-
  A finding that a permissioned, attended operation reverts (rather than booking, try/catching, or
  skipping) when a dependency is disabled or misconfigured.
premise:
  - The path is permissioned and attended (onlyOwner/onlyMigrator/keeper run by the owner).
  - The revert is loud (named error or preview-detectable) and recoverable in one call.
  - The proposed non-reverting fix would defer the failure rather than deliver the asset.
reopenWhen:
  - The path is permissionless or unattended.
  - The deferred state would land in a channel already filed as lossy.
provenance: >-
  Owner rejection of stable-staker run-16 migration-exit booking fix; ycn L-26 b2a29359fd ("it should
  just panic"); ycn L-24 8511fd5206; sya-harvester L-05 3dc3002290 (2026-10-26, "fails loudly,
  wallet/eth_call preview catches it"). Memory fail-loud-is-a-feature-not-a-defect.
```
Never recommend try/catch or booking without answering who is present, whether the fix delivers the asset, and where the deferred state lands.

### P-018 — Emergency exits are ejector seats; they are terminal and intentionally costly
```yaml
id: P-018
status: active
effect: suppress
scope: phlimbo-ea, stable-staker:emergency paths
appliesWhen: >-
  Findings that an emergency path (phlimbo emergencyTransfer / pauseWithdraw, stable-staker
  emergencyWithdraw) leaves accounting stale so a later resume bricks, or that the exit forfeits
  rewards / takes a haircut from the exiter.
premise:
  - The emergency path remains owner-only (emergencyTransfer) or a self-exit for the exiter.
  - No deployment script calls emergencyTransfer followed by unpause() (terminal-by-intent holds).
  - The penalty falls on the exiter, not on third parties.
reopenWhen:
  - emergencyTransfer gains a non-owner caller.
  - A script resumes in place after emergencyTransfer.
  - The cost lands on other users (stable-staker 0dca43f315 inter-user transfer stays fix-pending).
  - A non-terminal migrator path (e.g. MigratorV2V3.withdrawAll) — not covered.
provenance: >-
  Owner 2026-07-15 (phlimbo V3-M-02 d3a5b3ecc5): "the purpose of these emergencyWithdrawals is to
  flee a buggy contract … we don't interact with the landing gear, the engine, the navigation."
  [story-022] SolvencyDetermination.md §1: recovery is out-of-band. phlimbo V2-M-03 b99e80230c "an
  implicit penalty to encourage users to not use this unless it is absolutely necessary".
```
Never propose accounting, flush or reset logic inside an ejector seat: if the accounting is the bug, the escape must not traverse it.

### P-019 — Frozen, already-deployed contracts get compensating controls, not code fixes
```yaml
id: P-019
status: active
effect: suppress
scope: phoenix-nft-staking (V1 BatchNFTMinter, NFTStakerDepletion), stable-yield-accumulator
appliesWhen: >-
  A finding in a contract the owner has declared deployed and frozen, where the owner has named an
  operational control instead of a fix.
premise:
  - The file is the deployed one (verify bytecode/address); undeployed twins and clones are NOT covered.
  - The named compensating control is in place (e.g. non-zero pauser, payment token not routed).
reopenWhen:
  - The contract is redeployed or a clone is wired live.
  - The compensating control is removed.
provenance: >-
  Owner phoenix H-01 1c222d5485 (2026-07-21): "the owner will not alter deployed source"; phoenix
  M-01 fcaca00259, M-01 7a1718e9a9, L-04 21b51d41f3 ("FROZEN and UNFIXABLE BY DESIGN"); SYA M-01
  ecc2d126dd "Won't fix the current contract as it is already deployed, but will ensure all tokens
  are properly configured".
```

### P-020 — Contracts being retired accept their findings, conditional on retirement landing
```yaml
id: P-020
status: active
effect: suppress
scope: global
appliesWhen: >-
  A finding in a contract the owner has declared deprecated or being replaced, excluding its
  migration-execution path.
premise:
  - The retirement/migration is complete or actively proceeding, and no user funds remain.
reopenWhen:
  - The migration stalls, is abandoned, or the contract is reused.
  - The finding is in the migration execution path itself (MigratorV1V2, MigratorV2V3, cutover escrow).
provenance: >-
  phlimbo V1 (2026-06-08, "V1 deprecated — all users migrated"); owner 2026-07-17 bulk phlimbo V2-*
  ("does NOT cover the migration execution path"); ycn L-06 (BalancerPooler retiring); ycn M-05
  e6fbf0d61c (replaced by NudgeStreamer); ycn L-28 lifetime-bound escrow.
```

### P-021 — An operational or cross-repo fix closes the finding in the repo that owns the fix
```yaml
id: P-021
status: active
effect: annotate
scope: global
appliesWhen: >-
  A contract-repo finding whose agreed fix lives in a deployment script, deployment state, or a
  sibling repo (e.g. pause wrappers owed by phStaging migration scripts).
premise:
  - The downstream script/state actually carries the fix at HEAD (verify there, not here).
reopenWhen:
  - The downstream guard is removed or the fix never lands.
provenance: >-
  Owner stable-staker M-01 2b9a89d29c (2026-08-29): "mitigation is OPERATIONAL … belongs in the
  deployment script"; ycn L-27 2268ead7cb and F-02-052 5a7732a4ea (fixes in phStaging story-103);
  ycn L-30 694537414c ("only the fork test decides"); reflax L-02 81ee07506e ("never read a rescan
  as an incomplete fix").
```
Annotation: a rescan of unchanged contract code is **not** an incomplete fix. Verify the fix where it lives.

## Migrations and buffers

### P-022 — Never top up users from protocol-held value to make a bounded migration loss whole
```yaml
id: P-022
status: active
effect: suppress
scope: phoenix-phase-2-staging, stable-staker:migration
appliesWhen: >-
  A finding (or mitigation) that a bounded, small cutover/migration loss to stakers should be made
  whole by routing protocol-held value back through a temporary top-up or depositFor path.
premise:
  - The loss is bounded and small.
reopenWhen:
  - The loss is unbounded or material relative to stakes.
provenance: >-
  Owner phStaging F-02 436848b0e3 (2026-09-14): "deliberate safe approach: routing protocol-held
  value back to users … would open back-door exploit surface. Do not re-file". Reconciles with the
  owner's "err toward the user" migration intent (2026-08-28) via the owner's own priority: never
  opening an exploit vector outranks erring toward the user.
```
Never recommend a top-up or a per-client cap as mitigation.

### P-023 — In-place `setYieldStrategy` on a market strategy with staked users is prohibited
```yaml
id: P-023
status: active
effect: escalate
to: medium
scope: stable-staker, phoenix-phase-2-staging
appliesWhen: >-
  A script or code path swaps the yield strategy in place on a pool with staked users while the
  strategy is market/execution-priced, instead of running the full terminal migration.
premise:
  - The pool has totalStaked > 0 at the time the script runs.
reopenWhen: []
provenance: >-
  Owner stable-staker ss9m7 969722dc9e (2026-06-09); memory phstaging-no-inplace-setyieldstrategy.
```

### P-024 — The set-aside buffer is working capital, not a solvency reserve
```yaml
id: P-024
status: active
effect: suppress
scope: stable-staker, reflax-yield-vault, phoenix-phase-2-staging
appliesWhen: >-
  Findings that the set-aside buffer is too small to protect late withdrawers in an underwater
  episode, or that a lowered buffer percentage (e.g. 25% → 10%, or 0 on sDOLA) is a defect in itself.
premise:
  - The ordered terminal migration (fixed (R,P) snapshot) remains available to protect users.
reopenWhen:
  - The terminal migration is blocked or unavailable (then buffer size matters — see stable-staker idle-sweep).
provenance: >-
  Owner-clarified 2026-08-28 (fractional-reserve analogy); phStaging M-03 7b7f46a883 owner wont-fix.
  Memory protocol-set-aside-buffer-concept.
```
Annotation for every buffer finding: say which of the three "buffers" is meant (staker-held set-aside, principal desync, accrued yield).

### P-025 — FCFS at par from the buffer during transient dips is intended
```yaml
id: P-025
status: active
effect: suppress
scope: stable-staker:buffer withdrawal path
appliesWhen: >-
  Non-migrating users withdrawing at par from the buffer FCFS during a transient, mean-reverting dip.
premise:
  - The path is the buffer withdrawal, not emergencyWithdraw share over-redemption (0dca43f3, a larger class — never absorbed).
reopenWhen:
  - The dip is not transient (bank run) — that belongs to the pro-rata migration.
provenance: >-
  Owner 69c7666eee (2026-06-01): "avoid sparking panic … a non-migrating user cannot be forced to realise a loss".
```

### P-026 — FCFS value shift bounded by a short migration window is dust
```yaml
id: P-026
status: active
effect: suppress
scope: phoenix-nft-staking:in-place migrations
appliesWhen: >-
  Slice-ordering or FCFS transfer between users during an in-place migration that completes in a
  few consecutive transactions.
premise:
  - The migration completes in minutes / a handful of transactions.
  - The M-05 stake-wedge gate is in place (fix-pending backstop).
reopenWhen:
  - Many slices or hours-plus of stagger ("a multi-day migration would itself signal a problem").
provenance: >-
  Operator triage 2026-07-23 on phoenix M-03 58bd104c00, M-04 a0967cceac, M-08 6d2d6284c5.
```
Never collapse these three into one entry: M-05 is the load-bearing backstop.

## Process, stories and environments

### P-027 — An addition the story omitted but the feature needs is not a spec deviation
```yaml
id: P-027
status: active
effect: suppress
scope: global (Law-2 faithfulness findings)
appliesWhen: >-
  A disclosed implementation addition the story did not mention, which is required for the
  feature to function; or a fix that rejects the audit's suggested mitigation but closes the root
  cause another way.
premise:
  - The addition is disclosed (commit body / docs) and functionally required.
  - The root cause is actually closed (verify).
reopenWhen:
  - The addition changes user-visible economics the story specified.
provenance: >-
  Owner phStaging F-03 103002cc29 (2026-09-14): "a human oversight in the story, not an
  implementation defect … Do not re-file". Memory phstaging-run36.
```

### P-028 — Choices written into a story are not Law-3 surprises
```yaml
id: P-028
status: draft          # auditor + severity-auditor derived; awaiting owner ruling
effect: downgrade
to: qa
scope: global
appliesWhen: >-
  A finding framed as a non-obvious owner footgun where the behaviour was explicitly specified in
  the owner's own story (e.g. "burn half").
premise:
  - The story text specifies the behaviour, not merely implies it.
reopenWhen: []
provenance: Memory yield-claim-nft-run18 Q-16.
```

### P-029 — NudgeStreamer liveness and registration are protocol-wide assumptions
```yaml
id: P-029
status: active
effect: suppress
scope: yield-claim-nft, phoenix-nft-staking (nudge donors)
appliesWhen: >-
  Per-donor findings that a donor depends on NudgeStreamer being live or registered, or proposals
  for per-donor rescue remedies.
premise:
  - The dependency is the shared streamer, not a donor-specific misconfiguration.
reopenWhen: []
provenance: >-
  Owner 2026-07-25 (memory yield-claim-nft-run19-notes); owner phStaging M-02 f7de907d79
  (2026-07-29): nudgeStreamer == address(0) is an intended steady state.
```

### P-030 — The deploy ladder is anvil → mainnet; no Sepolia rung is intentional
```yaml
id: P-030
status: active
effect: suppress
scope: phoenix-phase-2-staging
appliesWhen: A finding that a script lacks a testnet (Sepolia) rehearsal leg.
premise: []
reopenWhen: []
provenance: Owner 2026-07-29 (memory no-sepolia-rung-intentional).
```
Annotation: the fork/PREVIEW run and the script's own asserts are the safety net, so judge those harder.

### P-031 — DeployMocks is a UI mock, not a mainnet rehearsal
```yaml
id: P-031
status: active
effect: suppress
scope: phoenix-phase-2-staging:dev
appliesWhen: >-
  Findings that the DeployMocks/dev stack omits or diverges from a mainnet script's wiring or end state.
premise: []
reopenWhen: []
provenance: >-
  Owner 2026-09-15 on Q-01 ca095edfd7 ("out of scope and also wrong") and Q-03 30510f331e ("invalid
  too"). Older dev rehearsal-fidelity entries (eda17642 fix-pending, 6af1ae30, 12bcca3b) were NOT
  ruled on and are not covered.
```

### P-032 — stable-staker's source-repo EIP-170 oversize is deliberate
```yaml
id: P-032
status: active
effect: suppress
scope: stable-staker
appliesWhen: The source repo's unoptimized build exceeds 24,576 B.
premise:
  - phoenix-phase-2-staging/foundry.toml at HEAD still sets optimizer = true and via_ir = true (read the file).
reopenWhen:
  - The deployment profile loses optimizer/via_ir.
provenance: Owner 2026-08-29 (memory stable-staker-eip170-suspended-deliberately).
```
Annotation: the tested bytecode is not the deployed bytecode. Track whether a CI job runs the suite under the staging profile.

## Evidence standards

### P-033 — Self-certifying text in the audited source has no suppression authority
```yaml
id: P-033
status: active
effect: annotate
scope: global
appliesWhen: >-
  A finding that in-source NatSpec or comments pre-adjudicate ("not an audit finding", "all
  rounding favours the protocol", "there are three failure modes").
premise: []
reopenWhen: []
provenance: Memory in-source-natspec-carries-no-suppression-authority (SYA run-14).
```
The comment is never evidence for a premise of another precedent. Trace the claim to a story document. If it traces to none, the finding stands and the self-certification is itself filed as an F-XX finding. Over-claiming docs *raise* severity.

### P-034 — A proven arithmetic identity is not a defect
```yaml
id: P-034
status: active
effect: suppress
scope: global
appliesWhen: >-
  A finding whose core is a symbolic/fuzz PASS proving a property that would hold of every correct
  implementation of the same pattern (e.g. a slippage floor is inert below the guaranteed minimum output).
premise:
  - The generality test passes: name the comparable correct primitive (e.g. Uniswap amountOutMin).
  - The NatSpec states the semantics the "victim" would need to misread.
reopenWhen:
  - A correctly-used version of the feature still suffers the harm.
provenance: Owner reversed antimatter am3m7 to wont-fix (2026-08-23); memory symbolic-identity-is-not-a-finding.
```
When reversing, narrow rather than close: limbs that never depended on the withdrawn claim stay open.

### P-035 — Auditor narrowings of C4 known-invalid categories
```yaml
id: P-035
status: draft          # auditor-derived, not owner rulings
effect: annotate
scope: global
appliesWhen: >-
  A finding that would be stripped under a C4 known-invalid category: "unused view", "approve
  race", or "future code speculation".
premise: []
reopenWhen: []
provenance: >-
  reflax QA-11 b5b58717f3 ("unused view" does not cover a sealed override); QA-12 1b33361313 ("approve
  race" does not cover a one-shot constructor approve with an unchecked bool); INFO-01 25d53af107
  ("future code" does not apply when the mechanism exists today and only the date is future).
```
