# Script review: `antimatter-pool` (story-122 Script B)

**Project:** phoenix-phase-2-staging @ `669cbc1` (master) · **Run:** 44 (script audit) · **Fork block:** 26303964
**Forge target:** `script/CutoverAntimatterPoolMainnet.s.sol:CutoverAntimatterPoolMainnet`; verifier `script/VerifyAntimatterPoolCutover.s.sol`; contract `src/periphery/AntimatterPoolSeeder.sol`
**Story:** story-122 (`~/code/product-owner/stories/phStaging2/auto-complete/sya-antimatter-cutover/122-sya-antimatter-mainnet-catch-up.md`; state `auto-complete`, machine-approved, not human-reviewed). Seeder design: story-113 (`.../auto-complete/phStaging2-sya-and-pool/113-antimatter-pool-seeder-contract.md`).
**Nothing was broadcast to mainnet.** Execution covered the preview on a mainnet fork, a broadcast-mode run on a local anvil fork (impersonated OWNER, no Ledger) and fork tests. The patcher was run only against scratch copies of `mainnet-addresses.ts`.

---

## Operational bottom line

> **Broadcast Script B (`antimatter-pool`) BEFORE Script A (`sya-harvester`).**

The runbook (`docs/SyaAntimatterMainnetCutover.md` L15) currently allows "A and B, in either order". That order decides whether the two Mediums below can happen at all.
- **B first:** no third party holds Antimatter (AM) during B. `totalSupply == 0`, claims are disabled, and no StableStakerV2 position has reward greater than principal. A front-runner can only create an empty pair, which is harmless (`test_r44_05`), or donate sUSDS one-sided, which the attacker loses (`test_r44_06`).
- **A first:** A's last transaction opens `StableStakerV2.claim`. 205.42 AM of pending reward becomes claimable by 32 positions, and any AM holder can pre-price the pair B is about to seed.

**Evidence:** the M-01 control test `test_PoC_M01_control_noScriptA_cannotReproduce` runs the identical attack sequence without Script A. The attacker cannot price the pair, the seed lands at 2,457.70 AM : 2,077.157 sUSDS, and 1e-6 sUSDS buys only about 1.2e-6 AM. The same sequence after Script A (`test_PoC_M01_frontRunStealsSeededAM`) lets the attacker buy 2,452.65 AM for 1e-6 sUSDS.

B-before-A is an interim control, not a fix. M-01 and M-02 each also need a code fix (see the register). Do not rely on the private RPC: it hides only pending transactions, and tx1 to tx4 are mined publicly before the seed.

---

## 1. Does it do what it intends?

**On the clean path: yes.** In the fork preview and the anvil broadcast run, all six transactions behaved as specified, and every storage write (prestateTracer diffMode) is explained by the story:

| tx | what | result |
|---|---|---|
| 1 | Deploy `AntimatterPoolSeeder` at `0xdb70…09BE` (OWNER nonce 1791) | as intended |
| 2 | `UniPoolerV2.rescueERC20`: 10% slice, 2,258.927 LP, to OWNER | as intended; pooler keeps no LP accounting, so nothing breaks |
| 3 | `PhusdSusdsPair.approve(seeder, lp)` | exact amount, consumed by tx5 |
| 4 | `Antimatter.setApprovedMinter(seeder, true)` | as intended |
| 5 | `seed`: unwrap, burn 2,457.703 phUSD, mint 2,457.703 AM, create pair `0xb6da…a4DA` with 2,457.703 AM + 2,077.157 sUSDS, LP 2,259.433 to OWNER | as intended; the seeded price equals phUSD's pair price (0.8452 sUSDS, about $0.942), per story-113 L113 |
| 6 | `setApprovedMinter(seeder, false)` | minter set restored to `[StableStakerV2]` |

All in-script post-conditions passed, along with the verifier (progress-only and book-filled), the patcher (FILL, then idempotent SAME), the story's fork tests (6/6) and the audit's fork suite (18/18). The resume matrix (crash after each of tx1 to tx6, then resume) completes every case with one slice only, neutral supply, the revoke done and the verifier passing. A double rescue and a double mint are both impossible (`test_r44_12`). There is no third-party mint window between tx4 and tx6, because `seed()` is `onlyOwner` (`test_r44_01`).

**Where it does not do what it intends:**
- **The pair-absent precondition is not enforced on chain (M-01, F-01).** The story, the script NatSpec (L49-52) and the runbook (L63-64) all say F3 (`amountBMin = 0`) is safe because "step 0 guarantees" a fresh pair. Step 0 runs only in forge's local pass. The mined `seed()` accepts any pre-existing pair in which AM is cheap.
- **The "always-run" revoke does not always run (antimatter-pool L-01 (pps44l1), F-02).** If tx5 reverts and a foreign pair exists, every resume aborts at Step 0 before Step 8, and the seeder stays an approved AM minter.
- **The verifier cannot tell a real seed from a fake one (antimatter-pool L-02 (pps44l2)).** Its live checks are `reserves > 0` and `OWNER LP > 0`, and everything else compares the progress record with itself.

## 2. Unintended side effects

On the clean path, **none**. The only effects beyond the story are inherent or inert:
- the UniV2 protocol-fee LP mint to `feeTo` on the burn (1.4e-6 relative, inside the 0.1% floors);
- the seeder's standing phUSD self-allowance, which only the seeder can use on its own balance;
- the seeder's `onlyOwner` `seed`/`rescueERC20`, which cannot mint again without a new minter grant.

The unintended effects arise only under adversarial interleaving, and all of them were fork-reproduced:
- **AM-cheap front-run, after A (M-01):** tx5 succeeds and puts all 2,457.70 protocol-minted AM in a pair the attacker priced at 1 AM : 1e-12 sUSDS. The attacker buys 2,452.65 AM for 1e-6 sUSDS: **+$1,319.14 realized** net of a $1 seed cost, or **+$2,168.13 marked to market**. The protocol's LP redeems about 6.05 AM + 1e-6 sUSDS instead of 2,457.70 AM + 2,077.16 sUSDS. The verifier would pass. This is reasoned, not executed on the drained state: its live seed checks are only reserves > 0 and OWNER LP > 0, and its record checks compare local-pass figures to each other.
- **AM-dear front-run plus dust LP, after A (M-02):** tx5 reverts and the revoke is skipped. After the attacker sends OWNER 1 wei of LP, the resume "completes" with only the revoke. The progress file says `completed` / `seeded=true`, the real patcher FILLs the attacker-created (canonical, deterministic) pair into the address book as the protocol's seeded pool, and `:verify` passes. No AM is minted and the LP slice sits on OWNER unconverted.
- **Dust to the seeder address (L-03):** 1 wei of any of five tokens, sent to the nonce-predictable seeder address, blocks the preview before deploy, or fails `:verify` permanently after deploy until OWNER calls `seeder.rescueERC20`. This is fail-loud, and funds are never at risk.

## 3. Knock-on and cluster problems

- **Script A ordering (the enabling condition).** The runbook's claim that A and B touch "disjoint state" is true for storage and false economically: A's `setClaimEnabled` creates the AM float that M-01 and M-02 need. This is filed on the sya-harvester side as **sya-harvester L-01 (pps44l4)** (availability: B aborts on a pre-created pair) and as the unsafe-story flag **sya-harvester F-01**. It is not re-filed here.
- **Script C (`uniswap-helper`, successor).** C's precondition checks that book `AntimatterSusdsPair` is non-zero, equals `factory.getPair(AM, sUSDS)` and has code. It cannot tell a seeded pair from a foreign one. In the M-02 spoof the book certifies the attacker-created (canonical) pair as the seeded pool. C's ordering guard (`script/DeployUniswapHelperMainnet.s.sol` L205-220), which exists to stop C until B has really landed, would therefore pass, and C would deploy UniswapHelper's AM routes over an attacker-priced pair. The helper resolves `amPair()` lazily (see the NatSpec at `script/DeployUniswapHelperMainnet.s.sol` L202-204). The address is not wrong; the certification is. **This step is inferred, not executed.** Verify it in a uniswap-helper script audit.
- **CutoverStableStakerV2Mainnet (predecessor).** It defines the minter set `[StableStakerV2]`. B restores that set exactly on every happy-path and resume run. The exception is the failed-seed path (antimatter-pool L-01 (pps44l1)).
- **UniPoolerPool / BalancerLPMigrator (siblings).** The slice is fixed at first sizing and persisted, so `pool()` calls between runs cannot cause a second rescue. Reserve moves between the local pass and tx5 are bounded by the 0.1% floors. No finding.
- **Antimatter economics.** At the seeded price there is no buy-and-annihilate arbitrage (a 100 sUSDS loop loses $14.71; `test_r44_07`). Holders get more by selling AM into the pool than by annihilating it. This is intended per story-113 L113 and is informational only. The only profitable path is M-01, which buys AM below fair value from a pool the attacker priced.

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| [M-01](../../submissions/antimatter-pool/M-01.md) | Medium (borderline High) | Step 0 (pair absent) runs only in the local pass. After tx1, an AM holder pre-prices the pair AM-cheap, and `seed()` (`amountBMin = 0`) pours all 2,457.70 AM in, of which the attacker buys about 99.8% for 1e-6 sUSDS | Enforce the precondition in `seed()` (`minSUSDSPaired` floor or require a fresh pair) so tx5 reverts; until then broadcast B strictly before A; correct the runbook's private-RPC claim | `src/periphery/AntimatterPoolSeeder.sol` L179-248; `script/CutoverAntimatterPoolMainnet.s.sol` L49-52, L258-271 |
| [M-02](../../submissions/antimatter-pool/M-02.md) | Medium | Resume gate accepts any pair where OWNER holds 1 wei of LP. An induced seed revert plus dust LP makes the cutover report `completed`, `:verify` pass and the patcher certify the attacker-created (canonical) pair as the seeded pool | On resume, require chain evidence of THIS seed (tx hash, or OWNER LP ≥ recorded liquidity > 0 with ≥ 99% share and AM reserve ≥ amMinted); never trust a local-pass record | `script/CutoverAntimatterPoolMainnet.s.sol` L262-268 |
| [L-01](../../submissions/qa-report.md) | Low | The "always-run" minter revoke does not run when the seed failed and a foreign pair exists: Step 0 aborts first, so the seeder stays an approved AM minter | Revoke any recorded seeder that `isApprovedMinter` before any Step-0 abort; document the manual `setApprovedMinter(seeder,false)` | `script/CutoverAntimatterPoolMainnet.s.sol` L258-271 vs L404-413 |
| [L-02](../../submissions/qa-report.md) | Low (disclosed) | Verifier anchors no recorded figure to chain state (only reserves > 0, OWNER LP > 0), so a never-seeded or foreign-priced pair verifies | Assert OWNER LP share ≥ 99%, AM supply ≥ recorded amMinted and a pair-price sanity band, or read the seed receipt's `Seeded` event | `script/VerifyAntimatterPoolCutover.s.sol` L54-85 |
| [L-03](../../submissions/qa-report.md) | Low | 1 wei of any of five tokens at the predictable seeder address blocks B before deploy or fails `:verify` after deploy; `_requireSeederEmpty` demands absolute zero | Compare seeder balances to pre-seed values (as the contract does) or tolerate dust; document `seeder.rescueERC20` as the remedy | `script/CutoverAntimatterPoolMainnet.s.sol` L156-163 |
| [F-01](../../submissions/spec-conformance.md) | Spec (Medium weight; unsafe story) | Story-122 says F3 is safe because "step 0 guarantees" a fresh pair, and the runbook names a private RPC as the mitigation; on chain neither holds | Amend story-122 L142 and the runbook: F3 is acceptable only with an on-chain guard in `seed()`; the private RPC covers only the seed tx's mempool exposure; require B-before-A until the guard lands | story-122 L142; script L49-50; runbook L47-52, L63-64 |
| [F-02](../../submissions/spec-conformance.md) | Spec (Low weight) | Story-122 says the revoke "must always run, even on resume"; a failed seed with an existing pair aborts before it | Revoke any recorded seeder that `isApprovedMinter` before any Step-0 abort; document the manual revoke in the runbook | story-122 L132; script Step 0 vs Step 8 |

Not counted as separate findings: the AP-06 runbook private-RPC misdescription is merged into M-01 (same root window), and F-01 and F-02 are spec-conformance records that sit alongside M-01 and L-01. The QA report (`../../submissions/qa-report.md`) is the target for the Low labels.

---

## Referenced, not re-filed

| Ledger | Finding | Status | Relevance |
|---|---|---|---|
| antimatter | M-02 `64807f2b1456` ("half of every annihilation's phUSD is minted against no incoming value") | wont-fix | M-01 uses annihilate only as the realization path. The wont-fix rationale presumes AM reaches its intended holders. It does not cover protocol-minted AM captured by an attacker at a price the attacker set, so it does not transfer to M-01, and M-01 is not a re-file of it. |
| phoenix-phase-2-staging (this run) | sya-harvester L-01 (`pps44l4`) | open | A-before-B is the enabling condition for M-01 and M-02. Filed on the sya-harvester entry point and cross-referenced here. |

Same-family prior entries (not duplicates; different script, contract or direction): unipooler-cutover L-03 `4f454372eed2` (pair must be empty vs absent), dev L-01 `9a694ae01fe1` (UniPoolerCutoverCore pair poisoning), unipooler-cutover Q-02 `e2909097a253` (weak resume predicate), balancer-holding L-01 `59527bfa8478` (verifier coverage). balancer-lp-migrator L-01 `357565f8425a` (wont-fix, UI-side floors) is scoped to user migrations through phlimbo-ui, and its disposition does not transfer to the owner-script `seed()`.

## Human-review flags

1. **M-01 severity: Medium, borderline High.** Re-rate to **Plausible High** if the owner commits to the A-before-B order and broadcasts B unchanged. The enabling precondition is then no longer hypothetical.
2. **M-02 possible downgrade, to be re-weighed.** The classifier noted a possible Low because the downstream Script C effect was inferred. Since then the PoC has **proven** the address-book poisoning (the real patcher certifies the attacker-created canonical pair as the seeded pool). Only Script C acting on that entry remains inferred. Re-weigh with that narrower residual. Downgrade to Low if Script C gains a chain-anchored pair check, or if the runbook requires pair inspection after a tx5 revert.
3. **Script C was not executed** against the spoofed book. Confirm in a uniswap-helper script audit.
4. **Bytecode verification.** The Antimatter and UniPoolerV2 deployed bytecode is not Etherscan-verified. Fork behaviour matched the nested-pin source on every path exercised.

## Evidence

- Dedicated PoCs: `phoenix-phase-2-staging/work/test/audit-run44/AntimatterPoolPoC44.fork.t.sol`. Diff: `reports/44/pocs/AntimatterPoolPoC44.diff`. Logs: `reports/44/pocs/logs/` (3/3 pass; 21/21 in-suite under `FOUNDRY_PROFILE=audit44`). Tripwires: M-01 fails against a `minSUSDSPaired` seeder with `InsufficientSUSDS(2457703431, 2075083110422466836443)`; M-02 fails against a hardened resume gate with the Step-0 ABORT.
- Exploratory suite: `work/test/audit-run44/AntimatterPoolRun44.fork.t.sol` (18/18), with logs in `logs/forktest-run44-antimatter.log`.
- State diffs and receipts: `logs/artifacts/diff1..6.json`, `scriptB-anvil-run-latest.json`. Spoof artifacts: `logs/patcher-spoof.log`, `logs/artifacts/progress.spoof-after-dustLP.json`.
- Inputs: `intent.md`, `side-effects.json`, `cluster-analysis.json`, `manual-review-and-references.json`. Classified records: `reports/44/findings/{medium,low,faithfulness}/antimatter-pool__*.json`.
