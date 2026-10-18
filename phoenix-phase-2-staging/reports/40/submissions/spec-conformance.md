# Spec Conformance (Law 2): phoenix-phase-2-staging, full-audit contract scan (run 40)

**Project**: `phoenix-phase-2-staging`  ·  **Run**: `phoenix-phase-2-staging-40`
**Commit**: `a4f9f3c66ee133a7cacb79f4d24300bba5945966` (`a4f9f3c`), branch `master`
**Baseline**: `0e190e8` (`branchBaselines.master`), regression scan over `0e190e8..a4f9f3c`
**Entry point**: none (contract scan, `entryPoint: ""`)
**Focus**: the UniPooler cutover (`script/helpers/UniPoolerCutoverCore.sol`, stories 100 / 103) and `src/periphery/UniswapHelper.sol` (stories 109 / 111)
**Fork evidence**: mainnet block 26181500 (pinned), `work/test/audit-run40/*`, `reports/40/tier3/invariants.md`

This run raises **two new Law-2 findings**, `F-01` (`pps40f1`) and `F-02` (`pps40f2`). Neither has
asset, value or availability impact of its own, so **neither owes a separate High/Medium label or
report**. Three QA-channel findings carry a faithfulness facet and are cross-referenced below rather
than re-labelled: `Q-02` (story-103 respec, story-unsafe), `L-02` (story-109 rationale, Law-1 story-unsafe)
and `L-04` (story-100 / plan recovery-mode premise). Their full text is in `qa-report.md`.

A visible **OBLIGATIONS** section tracks the cross-project fixes story 103 still owes to yield-claim-nft.

Story documents were resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree;
each tag returned exactly one document. All plan line numbers refer to
`docs/BalancerWinddownPlan.md` at `a4f9f3c`.

| Story | Path (under `~/code/product-owner/stories/phStaging2/`) | State |
|---|---|---|
| 100 | `auto-complete/phStaging2-Balancexit/100-pin-bump-balancer-mock-exits-unipooler-cutover-core.md` | auto-complete |
| 103 | `incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md` | **incomplete** |
| 109 | `auto-complete/phStaging2-Balancexit/109-uniswap-helper-contract.md` | auto-complete |
| 111 | `auto-complete/phStaging2-Balancexit/111-uniswap-helper-mainnet-deploy-script.md` | auto-complete |

---

## F-01: Story 103 contradicts itself, and the plan's Stage 2 still prescribes the OWNER-EOA custody flow <!-- id: pps40f1 -->

- **issueId:** `pps40f1`  ·  **Fingerprint:** `48d88a589ca41396cb6e2c835c34bbf9296be43ffd0537d45e02e3df53bacab5`
- **Fingerprint input:** `story-103 text / docs/BalancerWinddownPlan.md section 4 Stage 2:n/a (spec):story-internal-contradiction`
- **Severity:** QA (faithfulness channel). **Status:** open (new).
- **Story:** 103, `~/code/product-owner/stories/phStaging2/incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md`. State: **`incomplete`**.
- **Source plan:** `docs/BalancerWinddownPlan.md` §4 Stage 2 (L376-428), the output of story 108.
- **Landed code implementing the superseded flow:** `script/helpers/UniPoolerCutoverCore.sol` L341, L362, L373, L425-430, L521 (story 100, which predates the requirement).

### What story 103 requires (verbatim)

*Upstream Change (2026-10-07): no funds through any EOA (yield-claim-nft:052)*:

> **Requirement:** the human requires that no protocol funds (BPT, sUSDS, phUSD, USDS) transit the owner EOA `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` or any other EOA during the cutover, so that it is provable on-chain, for tax and accounting, that these funds move contract-to-contract.

Checklist L203 (amended 2026-10-10, F-02-052):

> **Owner BPT is out of scope (amended 2026-10-10, F-02-052).** The script never transfers owner BPT into the escrow, and it must NOT revert on a non-zero owner BPT balance: anyone can donate BPT to the owner, so such a revert would be a grief vector.

### What the same story still says (verbatim)

Background, *Cutover sequence* (L59-71). The heading claims the plan's version "is corrected", but the steps it lists are the superseded EOA flow:

> 0. Preconditions `require`d: authorized-pooler set revoked (story 099); pair absent or reserves (0,0); every config value read live from the old pooler.
> …
> 2. `BalancerPoolerV2.withdrawBPT(OWNER, fullBalance)`.
> 3. Exit the OWNER's whole BPT balance: `removeLiquidityProportional` before 30 Oct, `removeLiquidityRecovery` after …
> 4. Router02 `addLiquidity(sUSDS, phUSD, allRecoveredSUSDS, allRecoveredPhUSD, min, min, to = UniPoolerV2, deadline)` from the owner; this creates the pair.
> …
> 9. `rescueERC20(sUSDS, UniPoolerV2, balance)` + USDS dust sweep.

Technical Details, L150:

> **Preconditions:** the script itself `require`s the revocation on-chain (all four poolers unauthorized on `0x7f68`) and pair absence or (0,0) reserves.

### What the source plan says (verbatim, §4 Stage 2)

> 2. … If the pair's sUSDS or phUSD balance exceeds its reserve (an unsynced pre-donation), call `pair.skim(OWNER)` first.
> 4. **Take the BPT out:** `BalancerPoolerV2.withdrawBPT(OWNER, fullBalance)`.
> … **Donation disabled** …: `rescueERC20(USDS, OWNER, fullBalance)`, then approve and `sUSDS.deposit(amount, UniPoolerV2)` from OWNER.

and the griefing-recovery text (L414):

> If the seed does revert, … the recovered sUSDS and phUSD sit on OWNER. The operator re-runs from step 6 with a reviewed recovery.

### Actual behaviour

The authoritative, incomplete story contradicts itself, and its named source plan contradicts its
latest requirement. An executor reading top-down meets the EOA-custody flow first: Background
L59-71, then the L150 precondition. Only later does it reach the 2026-10-07 / 2026-10-10 amendments
that forbid that flow. The landed core (story 100) implements the superseded flow exactly:
- `withdrawBPT(p.owner, bal)` at L362;
- the exit of `balanceOf(p.owner)` at L373;
- the owner-sourced Router02 seed at L425-430;
- the owner-BPT revert in `_assertRetired` at L551-554.

**Impact.** There is no Law-1 exploit, because EOA custody by a trusted owner is not an attack path.
This is the documentary root that would turn **L-01** (`pps40l1`, 7d5a26570be9) from latent into live,
if story 103 ships on the un-rewired core. It also puts at risk the on-chain tax/accounting
provability the human asked for.

**Recommendation.** Before story 103 executes, mark Background L59-71 and L150 as superseded by the
2026-10-07 / 2026-10-10 amendments, the way story 100 L52 did. Add an escrow-flow note to plan §4 Stage 2.

**Related:** L-01 (7d5a26570be9), Q-02 (6d49f9353148), F-02 (91aa9008aaca), and the OBLIGATIONS section below.

---

## F-02: Story 103 names the wrong third-party BPT holders <!-- id: pps40f2 -->

- **issueId:** `pps40f2`  ·  **Fingerprint:** `91aa9008aaca30a35a88b0dda81d906ae8ba4b7beb915fca13298562d5991364`
- **Location:** story-103 text (L116, L213)
- **Fingerprint input:** `script/helpers/UniPoolerCutoverCore.sol (story-103 Concerns):n/a (story text):story-stale-holder-list`. The fingerprint preimage is retained from dedup for ledger stability. Its contract token is a label artefact: the defect is in the story text, not in the core contract.
- **Severity:** QA / informational (faithfulness channel). **Status:** open (new).
- **Story:** 103, `~/code/product-owner/stories/phStaging2/incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md`. State: **`incomplete`**.
- **Chain evidence:** BPT balances read at mainnet block 26181448.

### What story 103 says (verbatim)

Concerns, L213:

> **BPT held by third parties** (`0xE74E…1322`, `0x5f97…d2`, `0xde44…3D07`) is out of scope. Only owner-held BPT is exited, and verify reports any residual owner BPT.

### What the source plan says (verbatim)

`docs/BalancerWinddownPlan.md` L62-65:

> | EOA `0xc65faaafbbda520791f344d33497485edf58e8db` (nonce 177, not referenced anywhere in this repo) | 12,036.97 | 37.1% | 11,289 sUSDS + 12,921 phUSD |
> …
> **Open question: who owns `0xc65f…e8db`?** If it's a team wallet, it should exit alongside the protocol. If it's a third party, they need warning, because their liquidity is 37% of our depth.

and open question #1 (L531):

> | 1 | Who owns the `0xc65f…e8db` LP (37%)? | Known to the owner, who will contact them directly |

### Actual behaviour

At block 26181448, all three addresses the story names hold **0 BPT**. The only non-protocol holder is
`0xc65faaafbbda520791f344d33497485edf58e8db`, with **12,036.97 BPT**: 37.1% of supply,
about 10,957 sUSDS + 13,309 phUSD, roughly $24.4k. Story 103 never names this holder. The plan's
"warn the 37% LP" obligation therefore has no story checkpoint, and verify's holder report points at
the wrong addresses.

The cutover is mechanically fair to this LP:
- The proportional exit leaves the per-BPT claim unchanged. Balancer rounds in the pool's favour, so the remaining LPs gain dust.
- The spot price is unchanged.
- A recovery-mode exit after 30 Oct is also proportional.

The remnant-arbitrage leakage to this LP after Stage 4 is already in the ledger as yield-claim-nft Q-25
`b4c10f0f8938` and is not re-filed.

**Recommendation.** Amend story 103's third-party bullet to name `0xc65f…e8db` (12,036.97 BPT at block
26181448). Have verify print the Balancer pool's post-cutover holder set.

---

## Cross-references: QA-channel findings with a faithfulness facet

These findings are reported in `qa-report.md` under their own labels. They are listed here because
each one also grades a story. None gets a separate F label.

### Q-02 (`pps40q2`, 6d49f9353148): story-103 respec turns a skim-healable donation into a grief, and the `_assertRetired` owner-BPT clause conflicts with the 2026-10-10 amendment

- **Story:** 103, `incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md` (**incomplete**). Type: story-unsafe (Law 1, marginal).
- **Spec text (checklist L202, verbatim):**
  > Step 2 drops the skim entirely: neither `newPooler` nor the escrow exists at step 2, so step 2 only asserts the pair is empty (reserves AND balances (0,0)) or records its state, and any unsynced donation is skimmed to `newPooler` inside `escrow.exitAndSeed`.
- **Spec text (checklist L203, verbatim):**
  > it must NOT revert on a non-zero owner BPT balance: anyone can donate BPT to the owner, so such a revert would be a grief vector.
- **Actual / consequence:**
  - **Step 2.** If step 2 asserts balances == (0,0) with no skim, a 1-wei *unsynced* transfer to the pair fails the simulation at step 2. Yet `escrow.exitAndSeed` would have skimmed that same donation harmlessly to `newPooler` (escrow L365-366).
  - **`_assertRetired`.** The current core still has `require(... balanceOf(p.owner) == 0, "UniPoolerCutoverCore: BPT remains")` at L551-554. Unless the rewire removes it, a 1-wei BPT donation to OWNER griefs the run.
  - **Severity.** Fail-closed, and strictly weaker than the already-ledgered sync brick (9a694ae01fe1).
- **Spec correction:** assert reserves == (0,0) only, leave balances to the escrow skim, and drop the owner-BPT clause from `_assertRetired`. Related: yield-claim-nft L-26 b2a29359fde5 (wont-fix), disclosed alongside.

### L-02 (`pps40l2`, 1d7e436f7dad): story 109's stated safety rationale is not achieved (Law 1 overrides)

- **Story:** 109, `auto-complete/phStaging2-Balancexit/109-uniswap-helper-contract.md` (**auto-complete**). The runbook wording is in story 111, `auto-complete/phStaging2-Balancexit/111-uniswap-helper-mainnet-deploy-script.md` (**auto-complete**). Type: story-unsafe (Law 1).
- **Story 109 text (L79-80, verbatim):**
  > For liquidity operations, resolve the pair at call time via `IUniswapV2Factory(router.factory()).getPair(sUSDS, phUSD)`, and revert with a custom error if it is zero.
  > Two reasons. First, it stops `Router02.addLiquidity` from silently creating the pair before story 103's cutover seeds it at the intended price. Second, it lets the helper be deployed on mainnet before the pair exists.
- **Deploy-script NatSpec (`script/DeployUniswapHelperMainnet.s.sol` L43-46, verbatim):**
  > `PhusdSusdsPair` stays a zero placeholder until story 103's cutover (broadcast at Stage 4) creates the pair. The helper resolves it at call time via `factory.getPair`, so it can be deployed first; until the pair exists every swap and liquidity call reverts
- **Actual:**
  - The helper meets the *letter* of story 109: it never creates the pair. It does not meet the story's *purpose*, which is to stop seeding before the cutover, because `_requirePair` (L428) checks existence, not emptiness.
  - The pair exists from cutover step 1 onward, and earlier if anyone calls the permissionless `createPair`. In that window an honest `addLiquiditySUSDS` / `addLiquidityUSDS` call makes the caller the first LP. That permanently bricks the current seeding contracts: core step 2 (`"UniPoolerCutoverCore: pair reserves not empty"`) and the escrow (`UniPoolerCutoverEscrow__PairNotEmpty`, `0x247b45ec`). Finishing then needs new re-price-then-mint code, with the recovery exit as the backstop. Fork-proven: `test_CODE005_helperFirstLPBricksCoreStep2AndEscrow`.
- **Disclosure:** L-02 re-raises yield-claim-nft L-26 `b2a29359fde5` (owner wont-fix 2026-10-07, "it should just panic and then I'll have to figure out what to do if there is a pair"), on a different contract and trigger. The L-26 re-weigh condition is partly met by the 30 Oct / 30 Nov deadlines.
- **Spec correction:** the helper's add paths revert when either reserve is 0. Story 111 and the runbook should stop presenting "pair does not exist" as the safety boundary. Land the fix before story 111 broadcasts.

### L-04 (`pps40l4`, 5dce56307136): the story-100 / plan recovery-mode premise does not hold on mainnet

- **Story:** 100, `auto-complete/phStaging2-Balancexit/100-pin-bump-balancer-mock-exits-unipooler-cutover-core.md` (**auto-complete**). Pending in 103, `incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md` (**incomplete**).
- **Story 100 text (L112, verbatim):**
  > Add a switch so the rehearsal can simulate "pool paused": proportional reverts, recovery works.
- **Story 103 text (Background, quoting plan §4 Stage 2, verbatim):**
  > The BPT can still be recovered through `removeLiquidityRecovery`, and step 3 already allows for that.
- **Story 103 text (Technical Details, fork test case 2, verbatim):**
  > Case 2 runs the recovery-exit path. Mock the Balancer pause on the fork if feasible (e.g. `vm.mockCall` on the vault's pause query, or etching)
- **Plan text (L21, L38, verbatim):**
  > | 30 Oct | Pools paused, withdrawals-only, Recovery Mode enabled where needed | …
  > Once the pool or Vault is paused, `enableRecoveryMode` becomes permissionless, so LPs can always get out proportionally.
- **Actual:**
  - On Balancer V3, "paused" and "in Recovery Mode" are separate states. The core's RECOVERY branch (`_step5ExitBalancer`, L381-386) never calls `Vault.enableRecoveryMode(pool)`.
  - `MockBalancerVault.removeLiquidityRecovery` gates on `require(poolPaused, ...)` (L243). That conflates the two states, so `test_cutover_recovery` proves a property that does not hold on mainnet.
  - On the fork, step 5 in RECOVERY mode reverts `PoolNotInRecoveryMode` (`0xef029adf`). `enableRecoveryMode` reverts `SenderNotAllowed` (`0x23dada53`) for OWNER and for a stranger *while the pool is live*.
  - **Final review:** the pool-paused path is now fork-verified. In `yield-claim-nft/work/test/UniPoolerCutoverEscrow.fork.t.sol::test_fork_case2_pausedPoolRecoveryExitSeedsNewPooler` (block 26136000), an arbitrary address calls `enableRecoveryMode` after `pausePool`, and the recovery exit seeds the new pooler (PASS). The **Vault-paused-only** case (after 30 Nov) is untested.
  - This fails closed in simulation. The remedy is one call that the plan says becomes permissionless once the pool is paused.
- **Owed by story 103:** a permissionless `enableRecoveryMode` call in the RECOVERY branch; a fork test that forces a pause, covering both the pool-paused and the Vault-paused cases, and calls the real `enableRecoveryMode`; and a mock that models Recovery Mode as a separate state. Story 103's suggested `vm.mockCall` on the pause query would reproduce the same conflation.

---

## OBLIGATIONS: cross-project fixes owed by story 103 (not landed)

**DEDUP-009** · tracker fingerprint `cb74e7097a2455f2f7f6065743988aea513fe94ca4c2f898f80e19f0e5a25101`.
There is no phStaging ledger entry, so the obligation is not tracked twice.

- **Owed to:**
  - yield-claim-nft **L-27** `2268ead7cba40c09` (`ycn22l27`, **fix-pending**)
  - yield-claim-nft **F-02-052** `5a7732a4ea711f11` (`ycn22f2`, **fix-pending**)
- **Routed to:** story 103, `~/code/product-owner/stories/phStaging2/incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md`. State: **`incomplete`**.
- **Status at `a4f9f3c`:** **NOT LANDED.** This is not an incomplete fix: the fix was never attempted, because story 103 has not been implemented.

| Check | Status |
|---|---|
| Continued yield-claim-nft rescans of L-27 / F-02-052 | Do **not** treat as an incomplete fix |
| Status flips applied by this run | None |
| Notes appended to the two ycn entries | Yes, run 40 |

What run 40 observed:
- **Core unchanged.** `UniPoolerCutoverCore.sol` has no escrow interface and no `bpt()` guard.
  - Step 4 is still `withdrawBPT(p.owner, bal)` (L362).
  - Step 5 still exits `balanceOf(p.owner)` (L373).
  - `_assertRetired` still requires owner BPT == 0 (L551-554), which is the revert-on-owner-BPT the 2026-10-10 amendment forbids.
- **Pin bump.** `lib/yield-claim-nft` now pins `0fd6bdf`, which contains `src/migration/UniPoolerCutoverEscrow.sol`. It arrived through the non-story commit `a4f9f3c` ("Update yield-claim-nft to latest"), not the separate `[story-103]` commit the checklist requires. UniPoolerV2 is unchanged.
- **Runbook tolerance.** `docs/UniPoolerCutoverRunbookNotes.md` (ccb4d15) sets the `exitAndSeed` tolerance to 1% (ycn L-28). That is safe only in the escrow flow. Applied to the current EOA core, a wider exit tolerance widens the L-01 seed-shortfall window.

### Story-103 checklist items still open (all `- [ ]` at a4f9f3c)

None of story 103's new files exist yet:
- `script/DeployMainnetUniPoolerCutover.s.sol`
- `script/VerifyUniPoolerCutover.s.sol`
- `test/UniPoolerCutoverMainnet.fork.t.sol`
- the `minAmountsOut` quote helper
- `scripts/patch-mainnet-addresses-unipooler-cutover.js`
- the `unipooler-cutover:*` npm keys and their guard test

The items that discharge L-27 / F-02-052 are:

1. **Rewire the core to the escrow flow** (checklist L202). Deploy the escrow (operator = OWNER) after step 3 and before step 4. Change step 4 to `withdrawBPT(escrow, bal)`. Replace steps 5+6 with `escrow.exitAndSeed(mode, minAmountsOut, deadline)`. Route parked USDS as `rescueERC20(usds, escrow, x)` + `escrow.wrapUsds()`.
2. **BPT-address guard (L-27, amended 2026-10-08).** Add `require(old.pool() == escrow.bpt())` with a descriptive message immediately before `withdrawBPT(escrow, bal)`. Repeat it before any `withdrawBPT` or BPT transfer into an existing escrow (a resume from receipts, or a re-run after `abort()`). `old.pool()` is read live, never cached. The core's escrow interface declares `function bpt() external view returns (address)`.
3. **Operational rule (L-27)** stated in the script header: never call `BalancerPoolerV2.setPool` on `0x7f6874332c4629429d70D15f685A8230323F11F1` while an escrow pointing at it is live.
4. **Owner BPT out of scope (F-02-052, amended 2026-10-10).** Never transfer owner BPT into the escrow, and remove the revert on a non-zero owner BPT balance (today's `_assertRetired` L551-554). Verify only *reports* residual owner BPT.
5. **`_checkMinAmountsOut` on the escrow balance.** Compute it after step 4 on the escrow's BPT balance (the old pooler's BPT only, read live), not on `balanceOf(owner)`.
6. **Fork test (L-27).** Have OWNER call `old.setPool(X)`, then run the funding step. Assert the core reverts with the guard's message **before** `withdrawBPT`, and that neither BPT nor X moved into the escrow.
7. **Fork test (052).** Compute `minAmountsOut` over the escrow's BPT after `withdrawBPT(escrow, bal)` and assert `exitAndSeed` succeeds. Record the owner's live BPT (expected 0) without transferring it.
8. **Fork invariant (052).** The owner EOA's BPT, sUSDS, phUSD and USDS balances never increase at any step.
9. **Fork assertion (052).** On a paused pool, `removeLiquidityProportional` reverts and `removeLiquidityRecovery` succeeds. This ties to L-04: it must use the real `enableRecoveryMode`.
10. **Pin bump as its own `[story-103]` commit (052).** The pin is already at `0fd6bdf` via `a4f9f3c`. The story's commit-provenance requirement is unmet, but the code requirement is met.
11. **Update the DeployMocks rehearsal (story 101) and `test/UniPoolerCutoverCore.t.sol` (story 100)** to the escrow flow, including the owner-balance never-increases invariant on the local stack.

**Close condition.** Close ycn L-27 / F-02-052 only after an `/audit-script unipooler-cutover` run
verifies the rewired core.

**L-01 handling.** When story 103 lands, **re-check L-01 (`pps40l1`, 7d5a26570be9); do not pre-close it**.
The escrow rewire should dissolve L-01's root cause, which is multi-tx OWNER-EOA custody with no resume. That
has to be verified against the landed code, not assumed from the story text. The same applies to
L-03 (85095591a60a, no resume gates) and Q-01 (c8fb41a168e1, simulation-only post-conditions), which
live in the same core.

---

## Sepolia excluded by user directive

Every Sepolia leg was excluded from this run by user directive. The clauses below were **not graded**,
and their omission is not a pass:

| Source | Clause skipped | Story state |
|---|---|---|
| Story 102, `auto-complete/phStaging2-Balancexit/102-contract-addresses-extraction-wagmi-hooks-stage1.md` | `sepolia-addresses.ts` zero placeholders and the Sepolia key-set check; extraction zero-address skip deferred to story 104 | auto-complete |
| Story 110, `auto-complete/phStaging2-Balancexit/110-uniswap-helper-anvil-routes-and-address-key.md` | `sepolia-addresses.ts` UniswapHelper placeholder | auto-complete |
| Story 111, `auto-complete/phStaging2-Balancexit/111-uniswap-helper-mainnet-deploy-script.md` | "**Sepolia deployment is out of scope.**" (L105); already out of scope in the story itself | auto-complete |
| Story 103, `incomplete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md` | Required Human Action clearing story 104's `stage2-audit` gate (story 104, `incomplete/phStaging2-Balancexit/104-deploymocks-sepolia-fresh-unipooler-stage3.md`, is the Sepolia stage) | incomplete |
| `docs/BalancerWinddownPlan.md` | Stage 3 (Sepolia fresh deployment) and Stage 4 step 4 (`deploy:sepolia`) | plan |
| Story 098, `auto-complete/phStaging2-sepolia/098-deploy-mocks-sepolia-fresh-full-surface.md` (`DeployMocksSepolia`) | Not graded | auto-complete |

The `RPC_SEPOLIA` / `DEPLOYER_SEPOLIA_pk` env-var facts in stories 100 and 103 ("Shared phStaging2
facts") were likewise not exercised.
