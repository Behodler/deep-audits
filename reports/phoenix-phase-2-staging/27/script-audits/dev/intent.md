# Intent — `dev` (phoenix-phase-2-staging, run-27, regression / fix-verification)

HEAD `1d8a3a7515adca7819c530a01a87c132863a5ae2` (master) · baseline `e1db0f1` · chain **31337** local anvil
(no mainnet fork; `forkAvailable: false` per `entry-manifest.json`, and correctly so — every address in this
closure is minted fresh at run time).

## 0. Authoritative intent source (Law 2)

`package.json` carries **no** `//dev` doc comment, so the entry point's intent is carried by:

1. **Story 079** — `~/code/product-owner/stories/phStaging2/complete/phStaging2-script-audit-26/079-rehearse-cutover-mechanics-toggle-kendu-promo-and-sweep-deployer-grant.md`
   (state: `complete`; base commit recorded in the document == the audited HEAD). **This is the authoritative
   acceptance criteria for the delta**, and it is unusually self-disclosing: it names its own most-likely
   reward-hacking failure mode (vacuous mint-debt conservation) and records a live regression it deliberately
   ships (Decision 4).
2. `script/DeployMocks.s.sol`'s own header/NatSpec blocks.
3. Stories 073 / 076 / 077 / 078 for surrounding context (see `closure-manifest.json` → `storyDocs`).

Story numbers resolved by globbing the whole `phStaging2` tree; `079` returned exactly **one** hit, so there
is no ambiguity. Note the separate Law-2 wrinkle graded in `cluster-analysis.md`: story **078:301** says
"Do not modify `DeployMocks.s.sol`", and HEAD modifies exactly that file.

## 1. Stated purpose of the entry point (unchanged at HEAD)

`dev` builds the entire local anvil chain the Phoenix UI is developed against. Its two declared purposes are
(a) **rehearsing the mainnet cutover** and (b) **giving the UI a realistic chain to bind against**. Run-26
found three points where the script served (b) at the cost of (a), silently. Story 079 remediates exactly
those three.

## 2. Stated purpose of the story-079 delta (+293 / −1, one file)

- [x] **L-01** — add a local `Phase 7.6` (`_rehearseDispatcherSwap`, `:1768`, called `:1271`) that performs
      **one genuine dispatcher swap** on index 1 (`uniboostEYE`) in the mainnet fail-closed order
      `hook.pull() -> hook.setDispatcher(new) -> new.setHook(hook) -> replaceDispatcher(idx, new)`, with
      assertions, so `setDispatcher` / `replaceDispatcher` / `hook.pull()` stop executing **zero** times locally.
- [x] **L-03** — gate the Kendu promo **call site** on `armKenduPromo = vm.envOr("LOCAL_PROMO_KENDU", true)`
      (`:213` / `:398` / gate `:2174`), default ON, so the **dormant** promo state — the one mainnet ships on
      day one — becomes reachable locally. The helper body and its four post-condition `require`s stay untouched.
- [x] **L-04** — add a terminal `_sweepResidualPrivileges` (`:1914`, called `:1558`, last statement before
      `vm.stopBroadcast()`) that revokes the deployer's phUSD grant and asserts the **whole** end-state ACL
      declaratively via the two-field `canMint && mintVersion == phUSD.mintVersion()` idiom.

Explicitly out of scope per the story: L-02 (`clean:local` staleness), Q-01 (the 22 in-source `Story 079`
attribution references), all mainnet scripts, `src/`, `package.json`, `.envrc`.

## 3. Declared pre-conditions (asserted before the mutating work)

| # | Check | Site | Empirical result |
|---|---|---|---|
| P1 | `nftMinterV2.dispatcherToIndex(uniboostEYE) == REHEARSAL_SWAP_INDEX (1)` | `:1774` | PASS (armed + dormant) |
| P2 | **VACUITY GATE** `mintDebtBefore > 0` before `pull()` | `:1786-1789` | PASS, **and load-bearing** — the ledger read `0` before `_accrueIndex1MintDebt` and `5015015000000000000` after |
| P3 | `newUb.primeToken() == rewardToken` (hook `scale` is immutable) | `:1813-1816` | PASS |
| P4 | `rewardToken.decimals() == 6` | `:1818` | PASS |
| P5 | `armKenduPromo` resolved once, logged before Phase 1 | `:398-402` | PASS (logged at log line 105, between "Chain ID" and "Phase 1") |

## 4. Declared post-conditions (asserted after each mutation)

| # | Check | Site | Empirical result |
|---|---|---|---|
| Q1 | `hook.mintDebt() == 0` after `pull()` | `:1795` | PASS |
| Q2 | **CONSERVATION** recipient phUSD delta == `mintDebtBefore` | `:1796-1799` | PASS, non-vacuous (delta = 5.015015e18) |
| Q3 | **Intermediate window** `hook.dispatcher() == new` while `configs(1).dispatcher == old` | `:1828-1834` | PASS (structural; see residual finding DEV27-02) |
| Q4 | `configs(1).dispatcher == newUb` | `:1841` | PASS — on-chain `0xdB05A386…4402` |
| Q5 | `price`/`growth` preserved across `replaceDispatcher` | `:1842` | PASS (`10040060` / `10`) |
| Q6 | `disabled` preserved | `:1843` | PASS (`false`) |
| Q7 | `price < 1e12` ("6-decimal-shaped") | `:1846` | PASS — but see DEV27-01: index-1-specific, would fail at index 4 |
| Q8 | `newUb.hook() == hook` (hook REUSED) | `:1849` | PASS — both old and new point at `0x2B0d36FA…0dd5` |
| Q9 | `hook.recipient()` / `hook.ratio()` unchanged | `:1850-1851` | PASS (`0xD49a0e9A…17Be` / `50`) |
| Q10 | `dispatcherToIndex` moved old→new (both directions) | `:1852-1853` | PASS (`new → 1`, `old → 0`) |
| Q11 | `deployments["UniboostEYE"].addr == newUb` | `:1866` | PASS; `local-addresses.ts` and `/contracts/UniboostEYE` both name `0xdB05A386…4402` |
| Q12 | index-7 static pins: `hookTypeId == keccak256("NudgeRatchetMintDebtHook.v1")`, `ratio == 100` | `:1893-1901` | PASS |
| Q13 | **ACL table** 10 rows, two-field idiom | `:1921-1930` | PASS — independently reproduced by `cast call` |
| Q14 | dormant leg: `promoToken == address(0)`, `promoRewardBalance == 0` | `:2179-2180` | PASS |
| Q15 | armed leg: 4 original promo `require`s | `:2205-2208` (helper unchanged) | PASS, byte-identical to baseline |

## 5. Declared conditions NOT asserted (gaps)

- `tokenIdToDispatcher[1]` is repointed by `replaceDispatcher` (`NFTMinterV2.sol:244`) and drives `uri(id)`
  metadata, but Phase 7.6 asserts only `configs` and both directions of `dispatcherToIndex` (OBS-04).
  **Empirically the repoint did happen** (`tokenIdToDispatcher(1) == 0xdB05A386…4402`), so no live defect —
  this is an assertion-coverage gap, and the mainnet script shares it.
- The intermediate-window property is asserted as **state**, never as an **executed revert** (story Decision 9,
  live probe deliberately skipped) → DEV27-02.
- The run-26 recommendation's second clause — run `VerifyPromotionReady.s.sol` against the local end state —
  was explicitly **not adopted** (story Concerns: the verifier hard-codes mainnet addresses).

## 6. Intended side effects (per the manifest's `mutated` set)

`hook.pull()` ×1, `hook.setDispatcher` ×1, `newUb.setHook` ×1, `replaceDispatcher(1, newUb)` ×1,
`phUSD.setMinter(deployer, false)` ×1 (terminal), plus the greenfield deploy set. Everything observed on chain
is accounted for in `side-effects.json`; the two writes that are **new state the baseline did not produce** and
are only indirectly implied by the stated purpose are recorded there as `intended: partially` —
`_accrueIndex1MintDebt`'s extra index-1 NFT mint (price ratchet + prime residue) and the retirement of a
dispatcher that still holds 20.03 USDC.
