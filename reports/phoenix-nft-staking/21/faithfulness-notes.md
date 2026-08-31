# Story-faithfulness (Law 2) — phoenix-nft-staking run 21

**Scope:** three commits since baseline `0d1a0b2`, at HEAD `c881a42`.
**Stories checked:** `story-023` (f3b92c0), `story-022` stage 7 (fba4991), `story-022` stage 8 (a261604).
**Carryover re-derived:** ledger `F-20-07`.
**Outputs:** `reports/phoenix-nft-staking/21/faithfulness-findings.json` (10 findings, 3 proposed ledger actions, 6 verified claims).

---

## ⚠ TOP FLAG — Law 1 over Law 2: the story's own remedy is structurally incomplete

**F-21-01 — `src/NFTStakerDepletion.sol:756` is unchanged, and the reason given for leaving it is only half true.**

Story-023 declines a source fix on this basis:

> "That staker is deployed and immutable, so the remediation lands on the migrator side." … "**NO staker contract is modified.**"
> — commit `f3b92c0` body

That is true of the *instances*. It is not true of the *file*. `src/NFTStakerDepletion.sol` is the live deployment template, and it was used to mint fresh mainnet instances **after** the defect was known:

- `lib/phoenix-phase-2-staging/script/DeployMainnetUniboostCutover.s.sol:478` — `new NFTStakerDepletion(...)`, three mainnet instances (EYE/SCX/FLX) under phStaging story-071.
- `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:1461-1472` — deploys more.

Every instance deployed from here on ships `_safePay(pending)` at `:756` and `Claimed(user, pending)` at `:757`. The correct form already exists in-tree at `src/NFTStakerPriceScaledMigrateReady.sol:887`, whose own NatSpec at `:869-876` calls the `_safePay` form **"wrong in every case."** The repo documents the pattern as wrong and simultaneously ships it as the template.

**Residual reach-paths that survive a migrator-side-only remedy** (the explicit question posed to this scan):

1. **Direct EOA / multisig caller.** `depositFor` is `onlyMigrator`, and `setMigrator` (`src/NFTStakerDepletion.sol:311-314`) takes **any** address — no code-size check, no lifecycle gate. An operator address wired as migrator reaches `depositFor` directly and receives the user's settlement, with `Claimed(user, …)` still emitted. Nothing in either migrator can prevent this.
2. **Any pre-`f3b92c0` migrator instance already deployed and wired.** The fix lands only on **redeploy + re-run `setMigrator` on both stakers**, and the commit body never states that prerequisite. (Mitigating: no NFT-staking migrator appears in phStaging's scripts yet, and `DeployMainnetUniboostCutover.s.sol` never calls `setMigrator` — so the three new mainnet stakers currently have `migrator == address(0)` and `depositFor` is unreachable on them *today*.)
3. **Any future third orchestrator** — see F-21-02.
4. **Every future `NFTStakerDepletion` deployment.**

`batchMigrate` vs `migrate` was checked and is **clean**: the exit leg uses `_safePayTo(account, pending)` at `:733`. The misroute is confined to the `depositFor` push leg.

**Ledger consequence: do NOT auto-flip `1c222d548523` (H-01, fix-pending) to `fixed`.** The mechanism is good; the closure is not.

**Recommended:** fix `:756` to `_safePayTo(user, pending)` for future instances (zero cost, matches the in-tree sibling) and keep the forwarding as the compensating control for the three already-deployed stakers.

---

## story-023 — the mechanism itself: verified correct

Setting F-21-01 aside, this is a well-built fix and the run should say so plainly.

**The `require(captured <= owed)` bound cannot misfire on a legitimate migration.** I traced this rather than taking the NatSpec's word for it. `_syncBudget` (`src/NFTStakerDepletion.sol:423-435`) runs `_updatePool()` at `:424` **before** `dispatcherHook.pull()` at `:429`. `_updatePool` (`:448-472`) and `pendingReward` (`:799-813`) consume identical inputs — same `accRewardPerShare`, `rewardRate`, `windowEnd`, the same `reward > rewardBudget` cap, the same `totalStaked > 0` / `Active` guards — at the same `block.timestamp`. So the `pending` settled at `:754` equals the pre-call projection exactly, and `_safePayTo` can only pay less, never more. The bound is genuinely a tripwire and it is fail-closed.

**The self-disabling claim holds.** `NFTStakerPriceScaledMigrateReady.depositFor` settles via `_safePayTo(user, …)` at `:887`, so the migrator's balance is unchanged, `captured == 0`, and the branch at `NFTStakerMigrator.sol:223` is skipped. Pinned by `testVersionAgnosticPairDepletionVsPriceScaled` and `testVersionAgnosticInPlaceAgainstPriceScaled`.

**D-6 holds.** `NFTStakerMigrator.sol:214-241` and `InPlaceNFTStakerMigrator.sol:311-338` differ only in the staker handle and a revert-string prefix.

### Differential vs the audit's own run-20 candidate patch

Corroboration only — the workspace patch was never merged and carries no authority.

**Upstream is materially STRONGER in five places** (credit these; the run must not understate a good fix):

| | run-20 patch | story-023 |
|---|---|---|
| Reentrancy | none | `ReentrancyGuard` + `nonReentrant` on `migrate`/`migrateIn`/`claimForwarded` |
| Bound on the capture | **none** — would have forwarded any mid-call foreign inflow to whichever user the loop was on | `require(captured <= owed)` against the pre-call `pendingReward` |
| Blocklisted recipient | `safeTransfer` → **whole batch reverts** (a batch-DoS the patch shipped with) | escrow-on-failure + permissionless self-only `claimForwarded()` |
| Owner reach into escrowed value | `rescueERC20` unconditional | floored by `totalUnforwarded` (`NFTStakerMigrator.sol:270-274`, `InPlaceNFTStakerMigrator.sol:392-396`) |
| InPlace rescue | untouched | `totalUnforwarded` floor retrofitted |

Both added the missing rescue primitives to `NFTStakerMigrator`, which previously had none — that closes ledger **L-02 `cb1b52790cf1`** (proposed `fixed`).

**Upstream is weaker in exactly ONE place — F-21-04.** The patch used `safeTransfer`; upstream deliberately swapped to a raw `transfer` inside `try/catch` and asserts at `NFTStakerMigrator.sol:224-226` that *"Both branches are handled."* There is a third branch: a token returning **no data** on success fails the `returns (bool ok)` ABI decode. Outcome is either an uncaught revert (the exact failure the try/catch exists to prevent) or — worse — a **double-count**: tokens already gone, yet `unforwarded[user]`/`totalUnforwarded` credited anyway, which then makes `balance - totalUnforwarded` underflow-revert permanently and lets `claimForwarded` pay out of another user's escrow. `SafeERC20` handles all three. **Unreachable today** — the constructor pins `rewardToken` to the staker's own phUSD, a standard bool-returning OZ ERC20 — and weird-ERC20 is a C4 known-invalid class, so this is filed **QA, explicitly not escalated**. `testG`/`testG2` cover the revert and false-return branches; there is no no-return-data mock.

**Shared blind spots — neither side caught these:**

- **F-21-01(1)** the EOA-as-migrator path (out of the migrator's reach by construction — only a source fix or a `setMigrator` code-size check closes it).
- **F-21-02** the shared interface stays silent about the trap. Story-023 names fork drift as the very thing it is defending against (`NFTStakerMigrator.sol:204-205`), yet `INFTStakerMigratable.sol:40-46` — the one artifact a fourth orchestrator author would read — says nothing about `depositFor` settling to `msg.sender`. D-5's "purely a migrator-local concern" is right about the type system and wrong about hazard disclosure.
- **F-21-03** "version-agnostic across every staker exposing `depositFor`" (`NFTStakerMigrator.sol:48-50`) is over-stated by one getter. The sequence needs **three** — `depositFor`, `rewardToken()`, `pendingReward(address)` — and the constructor probes only the first two (`:133-140`). A staker missing `pendingReward` constructs fine and reverts on the **first** `migrate`, i.e. after `initiateMigration` has frozen emissions and (in-place) after the ERC1155 is parked; recovery is then `claimTimedOut` after ≥1 day, stake only, no re-entry.
- **F-21-05** the `Claimed(user, X)` telemetry deviation. Story-023 discloses it honestly (`NFTStakerMigrator.sol:70-76`) — credit that — but the disclosure covers the *successful* forward. In the escrow branch `Claimed(user, X)` is on-chain and final while the user holds nothing and must discover `claimForwarded()` themselves, with no on-chain link between the two. QA.

---

## story-022 stage 7 — split: spec side

Byte-identity is the contract-profiler's job and was not duplicated here. On the **spec** side the doc is in unusually good shape: every behavioural claim in `docs/multi-token-nudge.md` was checked against `src/BatchNFTMinterMultiToken.sol` and **conforms** — all §2 signatures and custom errors exactly, all ten §3 ordering steps in order, §4.1's *unconditional* payment-token exclusion (`MT.sol:426-428`, ahead of the `qualifies` ternary at `:429` and ahead of the pull at `:357`), §4.2's four-site comment requirement, §4.3–§4.6, and all 21 named §6 tests present by exact name.

**F-21-06** is the one real gap: the doc is a *delta spec* written against a contract being edited in place, and Stage 7 invalidated that framing without rewriting it. The literal `BatchNFTMinter` strings were repointed correctly (none left mis-pointing), but:

- `doc:70-74` lists four things as **"Removed:"** — `nudgePaymentToken`, `setNudgePaymentToken`/`NudgePaymentTokenChanged`, `BatchMint__NudgeTokenMatchesPaymentToken`, the scalar `minReward`. All four are still live in the frozen contract (`BatchNFTMinter.sol:87, 149-152, 111, 98, 242`). Nothing was removed.
- `doc:297-298` still instructs *"remove `nudgePaymentToken` state + setter"* — actively wrong at HEAD.
- `doc:353`'s acceptance check (*"existing single-token nudge cases: +2-3k (the guard)"*) is now unobservable: those cases run against the restored frozen contract, which gained neither the guard nor `nonReentrant`.
- Six further implicit references still equivocate between the two contracts (`doc:12-19`, `:109-111`, `:124-126`, `:160-162`, `:214`, `:314`).

**F-21-09** (QA): `BatchNFTMinterMultiToken.sol:143` still reverts with `"BatchNFTMinter: caller is not pauser"` — byte-identical to the frozen sibling's `:119`, so `vm.expectRevert` cannot tell them apart. A faithful consequence of "body untouched", but the rename was in scope.

⚠ Note for triage: ledger **L-03 `58b6c48605701f13`** carries a FIX TRAP (§4.1 requires the exclusion to run *unconditionally*). This scan **re-confirms** the trap is still live and correct at `MT.sol:426-428` — do not "fix" L-03 by conditioning the guard on `qualifies`.

---

## story-022 stage 8 — script deletion: clean

Verified and faithful. `script/` is gone; a repo-wide grep for `DeployBatchNFTMinter` outside `lib/` returns only the three intentional prose mentions at `CLAUDE.md:97, 100, 108`; the `script/` bullet was correctly dropped from Project Structure.

**The deployment procedure is NOT left dangling — and F2's root cause verifiably does not exist in the repo it redirects to.** `lib/phoenix-phase-2-staging/script/MigrateBatchNFTMinter.s.sol:430` calls `setNudgePaymentToken(USDC)` and asserts it at `:443`, plus the prime-token exclusion at `:456`. Deletion-rather-than-repair was the safe call.

**F-21-10** (QA tracking note): a grep of the entire phStaging repo for `BatchNFTMinterMultiToken` returns **zero** hits. Eight stages of story-022 landed a contract that has no deploy path here (forbidden) and none there. Normal intermediate state — recorded so it is not assumed shipped.

**F-21-07** is the substantive stage-8 finding, and it is a Law-2 issue in its own right. `CLAUDE.md:44-45` declares *"Treat the list below as the authoritative spec"*, and `:47` asserts in the singular that *"The emission model is the variable-runway / owner-set APY target."* That spec describes **one of eleven** files in `src/`. Absent entirely: `NFTStakerDepletion` — a **different** emission model and the one actually on mainnet three times over — plus both price-scaled variants, both migrators, both minters, and all three interfaces. A case-insensitive grep of `CLAUDE.md` for `batch|nudge|multi-token|depletion|pricescaled|migrator` yields two hits, neither a spec reference. `docs/multi-token-nudge.md:304` instructed *"Update CLAUDE.md if the nudge is described there"* — the conditional evaluated false, so the instruction silently terminated as a no-op and the multi-token nudge never entered the spec. Since `CLAUDE.md` is a designated Law-2 story source, anyone cross-referencing it for a change to the depletion staker or either minter gets **no acceptance criteria at all**.

(The `"NOT a deployment or staging repo"` block at `:98-111` is itself fully accurate. Project Structure at `:113-118` has no phantom entries but omits `docs/`, `snapshots/`, `.gas-snapshot`, `test/mocks/`.)

---

## Carryover — F-20-07: STILL STANDS, re-anchored and slightly strengthened

Re-derived at HEAD. Stage 7 repointed the contract name at `doc:50` but left the claim itself verbatim and **carried it into a new contract's NatSpec** (`src/BatchNFTMinterMultiToken.sol:56-61`). The claim now sits at `docs/multi-token-nudge.md:42-46` (run-20 anchored it at `:41`):

> "The pot is a *nudge*: by construction it is a fraction of the cost of the `nudgeSize` mints required to qualify… there is no configuration of this mechanism under which claiming is profitable-in-isolation."

Both files were read in full plus a non-truncated grep of every comparison operator. **No code enforces any ratio, cap, or value comparison.** In `BatchNFTMinterMultiToken.sol` every comparison is: `:352` a **count** gate, `:363`/`:424`/`:454` loop bounds, `:382`/`:384` payment-token dust and refund arithmetic, `:431` `available < minReward` (a **caller**-protective minimum, never a protocol-protective maximum), `:456` a zero skip. `paymentAmount` (`:297, :357, :384, :386`) never shares an expression with `snapshot`, `available`, or any reward amount; the contract never reads the dispatcher's price at all (only `primeToken()` at `:322`). The frozen sibling is identical in conclusion.

The doc contradicts itself three lines later at `doc:48-50` (*"If someone erroneously over-funds the contract… the error was in the sender"*), conceding the invariant is operator-maintained. And it is falsifiable from owner-reachable state alone: `setNudgeSize` (`MT.sol:166-169`) has no lower bound, so `nudgeSize = 1` makes a single mint qualify for the entire balance of every listed token, while the pot side is permissionless and unbounded.

Disposition unchanged from run-20: **spec-conformance report only**, no `L-xx` label. The value impact stays accounted for in the existing nudge findings; filing it in the security stream would double-count.

---

## Proposed ledger actions (human applies)

| Fingerprint | Label | Now | Proposal |
|---|---|---|---|
| `1c222d548523` | H-01 | fix-pending | **KEEP fix-pending.** Do not flip to `fixed` — see F-21-01. |
| `cb1b52790cf1` | L-02 | open | **Propose `fixed`** — `rescueERC20`/`rescueERC1155` landed in story-023. |
| `a7dffb34c9904a7f` | F-20-07 | open | **Remains open**; re-anchor to `docs/multi-token-nudge.md:42-46`, add `MT.sol:56-61` as a second site. |
