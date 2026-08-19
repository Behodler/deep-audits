# Cluster analysis — `dev` (run-27, regression / fix-verification)

HEAD `1d8a3a7` · baseline `e1db0f1` · both legs executed live against chain 31337. Every claim below is
backed by a file under `evidence/`; nothing is inferred from source alone.

---

## 1. `script/interactions/FundTestUser.s.sol` — BROKEN BY THE DELTA (confirmed empirically)

The closure mapper ranked this first and predicted the break. **Reproduced.**

```
$ npm run test:fund-user          # on a fresh chain, immediately after `npm run dev`
  │   └─ ← [Revert] Not authorized to mint
  └─ ← [Revert] Not authorized to mint
Error: script failed: Not authorized to mint
FUNDUSER_EXIT=1
```

`FundTestUser.s.sol:46` calls `MockPhUSD(phUSD).mint(testUser, phUSDAmount)` inside a broadcast opened with
`AddressLoader.getDefaultPrivateKey()` (anvil #0 = the deployer). The revert is `MockPhUSD.sol:48`. The
in-source comment one line above the failing call — `// Mint phUSD (deployer is authorized minter)` — is now
**false**, which is the part a future reader will trip on.

**This is a cluster interaction, not a contract bug.** The fix to L-04 (correct, and exactly what run-26
recommended) removed a privilege that a sibling script silently depended on. Story 079 found it, recorded it
as Decision 4, and deliberately declined to fix it to honour its own single-file constraint. Both of its
validators agreed and both recommended scheduling the one-liner.

**Independent consumer sweep (I did not take the mapper's word for it).** Repo-wide across
`script/interactions/`, `*.sh`, and the docs:

| Consumer | Mints phUSD as deployer? | Affected |
|---|---|---|
| `FundTestUser.s.sol:46` | **yes** | **BROKEN** |
| `simulate-yield.sh:44` | no — `MockDola.mint`, permissionless | no |
| `MintPhUSD.s.sol:41` | no — routes through `PhusdStableMinter` (own grant `:1131`) | no |
| `FullFlowTest.s.sol:106,113` | no — `minter.mint` | no |
| `TestNudgePayout` / `TestBalancerDonation` / `TestNFTMintAndClaimFlow` | no — permissionless mocks + `NFTMinterV2.mint` | no |
| `MintPhUSDMainnet.s.sol:73` | mainnet script, not on any local path | no |

There is **no second consumer**, so the severity is not raised by a missed dependent. It is, however,
raised slightly above "obscure utility" by documentation exposure: `script/interactions/README.md` points at
`npm run test:fund-user` four times (`:47`, `:283`, `:352`, `:383` — the last reading *"Fund test user
first"*), so the broken command sits inside the documented developer workflow.

Filed as **DEV27-R01**.

---

## 2. `DeployMainnetPromotionReady.s.sol` — the mirrored source of truth

### 2a. Ordering fidelity: PASS, in real transaction order

The mainnet ordering contract (`:148`) is
`hook.pull() -> hook.setDispatcher(new) -> new.setHook(hook) -> replaceDispatcher(idx, new)`.

Parsed out of the **broadcast bundle** (by `function` field of each dispatched tx, not by source occurrence):

| leg | pull | setDispatcher | setHook (of the new dispatcher) | replaceDispatcher |
|---|---|---|---|---|
| A armed | tx **355** | tx **359** | tx **360** | tx **361** |
| B dormant | tx **352** | tx **356** | tx **357** | tx **358** |
| run-26 baseline | **0 (absent)** | **0** | **0** | **0** |

Strictly increasing, in the mandated order, on both legs. A local rehearsal that asserted the right things in
the wrong order would rehearse nothing; this one does not have that defect.

### 2b. Coverage: 1 of 5 — an honest but material residual

| idx | class | prime | mainnet | local |
|---|---|---|---|---|
| 1 | Uniboost | USDC 6dp (`scale 1e12`) | swap | **swap** |
| 2 | Uniboost | USDC 6dp | swap | none |
| 3 | Uniboost | USDC 6dp | swap | none |
| 4 | BalancerPoolerV2 | **USDS 18dp** (`scale 1`) + **BPT custody shift** | swap | **none, of any kind** |
| 7 | NudgeRatchet | USDC 6dp, `DEFAULT_RATIO 100` | swap | 2 static assertions only |

Indices 2 and 3 are genuine duplicates of index 1 and their absence costs nothing. Index 7's two
distinguishing claims are honestly pinned statically (`hookTypeId`, `ratio == 100`) — I confirmed both
assertions execute and pass.

**Index 4 is the real gap, and it is the one that matters most.** Its mainnet swap carries a BPT custody
transfer old→new governed by a five-clause safety doctrine and a resume guard
(`DeployMainnetPromotionReady.s.sol:1385-1420`) — the single highest-value movement in the entire cutover —
and it is the only index whose hook `scale` is `1` rather than `1e12`.

Worse, the local rehearsal is **not re-targetable** to it despite appearances. `REHEARSAL_SWAP_INDEX` reads
like a knob, but `_rehearseDispatcherSwap` hard-codes the index-1 shape in three places:
`newUb` is constructed as a `Uniboost`; the prime assertion demands `decimals() == 6`; and
`require(price < 1e12, "index price is not 6-decimal-shaped")` (`:1846`) would **fail outright** at index 4,
where the registered price is `10 * 10**18`. So the class of defect the local rehearsal can catch is
specifically "a 6-decimal Uniboost swap went wrong" — not "a cutover swap went wrong".

Is the rehearsal still worth having? Yes — the *ordering* property it regression-gates is
class-independent, and that was L-01's actual subject. But the coverage claim should not be over-read.
Filed as **DEV27-01** (Low).

### 2c. The fail-closed assertion pins the premise, not the consequence

Run-26's recommendation clause (iii) asked for proof "that a mint attempted in the intermediate window
**REVERTS** rather than succeeding". Story 079 Decision 9 substituted a structural assertion:

```solidity
require(hook.dispatcher() == address(newUb), "intermediate window: hook did not repoint ...");
(address midDispatcher,,,) = nftMinterV2.configs(idx);
require(midDispatcher == oldUb, "intermediate window: the index already moved ...");
```

The rationale (a reverting call inside an active broadcast is recorded into the bundle and fails
`deploy:local`) is sound, and the story explicitly permits the substitution. But the two assertions restate
the *setup* — hook points at new, index points at old — and derive the revert by reasoning about
`UniboostMintDebtHook.onDispatch:129` (`if (msg.sender != dispatcher) revert OnlyDispatcher();`). They never
touch `onDispatch`. Delete line 129 and the entire local rehearsal still passes green while the fail-closed
property — the whole reason the ordering exists — is gone.

That is a regression-gate hole in the exact contract this phase was added to gate. Filed as **DEV27-02**
(Low). The remediation is cheap: bracket a `try nftMinterV2.mint(...)` probe outside the broadcast, exactly
as *Implementation Notes* step 6 already describes.

### 2d. OBS-03: the swap retires a dispatcher holding prime, on both artifacts

`Uniboost._dispatch` streams `donationSplit%` of the prime to the recipient and **retains the rest** for a
later `pool()` (split is 50). `_accrueIndex1MintDebt` now deterministically adds to that retained balance and
Phase 7.6 retires the holder immediately, with no sweep.

Measured on chain: the retired incumbent holds **20.030020 USDC** — 50% of four index-1 mints
(`10000000 + 10010000 + 10020010 + 10030030`) — of which **5.015015 USDC (25%) was created by the fix
itself**; the other 15.015 pre-existed. So the fix did not invent the residue class, it converted a *live
retained balance on the live dispatcher* into a *residue on an off-index dispatcher*.

I probed recoverability rather than asserting it: `Uniboost.rescueERC20(USDC, deployer, 20030020)` executed
against the retired contract returned status `0x1` and left balance `0`. `pool()` also remains callable
(`poolerAuthVersion(MultiPooler) == authVersion == 1`). **The value is parked, not lost.**

The cross-artifact half is the part worth recording: mainnet `_swapUniboost` has **no sweep either**, and its
incumbents are live dispatchers that have been accruing real retained USDC from real user mints. Post-cutover
the retained-prime pot silently splits across two addresses, and any pooling automation bound to the address
book will call `pool()` on a dispatcher whose retained balance is zero — reverting `"Uniboost: nothing to
pool"` until fresh mints accrue. That magnitude is **not measured here** (no mainnet fork was in scope for
`dev`); flagged for the promotion-ready entry point. Filed as **DEV27-03** (Low, mainnet leg tagged
`unverified`).

### 2e. OBS-04: `tokenIdToDispatcher` is repointed but not asserted

`NFTMinterV2.replaceDispatcher:244` writes `tokenIdToDispatcher[index] = newDispatcher`, and `uri(id)` reads
that mapping to build the NFT's metadata JSON. Phase 7.6 asserts `configs` and **both** directions of
`dispatcherToIndex` — thorough — but not this third mapping.

**Can the omission hide a real defect?** Empirically no defect exists here today:
`tokenIdToDispatcher(1) == 0xdB05A386…4402`, correctly repointed. And the write is unconditional in the same
function that satisfies the asserted `configs` write, so no plausible input makes one land without the other.
The realistic failure it would miss is a future edit to `replaceDispatcher` that drops line 244 — in which
case every index-1 NFT's `uri()` would silently keep resolving through the **retired** dispatcher's metadata,
a stale-but-plausible string that nothing would flag. Low value, but the assertion is one line and the
neighbouring assertions are already exhaustive. Filed as **DEV27-04** (QA). Note the mainnet script shares
this omission.

---

## 3. `VerifyPromotionReady.s.sol` — recommendation not adopted (correctly)

Run-26's L-01 recommendation had a second clause: run story 075's verifier against the local end state.
Story 079's Concerns declines it because the verifier hard-codes mainnet addresses and parameterising it
would edit a mainnet script — outside the story's stated scope. That reasoning holds; I confirmed the
verifier is read-only and address-hard-coded. Not filed as a finding; recorded so the clause is not lost.

---

## 4. Predecessor / successor consistency

- `DeployMainnetUniboostCutover.s.sol:723` reads `deployments["UniboostEYE"].addr`. The in-place repoint at
  `:1864-1866` keeps that key single-valued: `contractNames` receives `"UniboostEYE"` exactly once (`:668`),
  and the emitted `progress.31337.json` carries exactly one `UniboostEYE` entry, holding the replacement.
  Decision 8's rationale for editing in place rather than `_trackDeployment`ing checks out.
- `script/interactions/TestNudgePayout.s.sol:119` mints at index 1 but resolves through `configs` at mint
  time, so the repoint is transparent to it. Confirmed by the post-swap mint probe: a fresh
  `NFTMinterV2.mint(1, deployer)` after the run succeeds (status `0x1`) and accrues
  `5020030000000000000 == 10040060 * 1e12 * 50 / 100`, with the donation leg reaching the NudgeStreamer.
  **The local chain ends fully working**, which was the checklist's own bar.

---

## 5. Law-2 grading

### 5a. Story 078:301 — "Do not modify `DeployMocks.s.sol`" — **nominal, confirmed**

The directive is the trailing clause of a bullet about `DROPPED_CONTRACT_NAMES`, inside 078's own constraints
section. Story 079 is later and names that file as its **sole** in-scope file. Decisive test: the added lines
contain **zero** occurrences of `DepositPageView` / `MintPageView` / `ViewRouter` / `DROPPED_CONTRACT_NAMES` /
`DepositView`, and the one deleted line is the Kendu call site. The delta cannot disturb what 078 was
protecting. The closure mapper's grading is **upheld**; no finding.

### 5b. Story 079's 18-item checklist — spot-checked, **no over-tick found**

This repo has a history here (run-22's `ForgeLocalPassPrecedesBroadcast`, run-26's `daab9e86d033` checklist
over-tick), so I re-proved the load-bearing boxes rather than reading them:

| Checklist claim | Independently verified | How |
|---|---|---|
| mint-debt conservation non-vacuous | **YES, and the gate is load-bearing** | `mintDebt` read `0` before `_accrueIndex1MintDebt` and `5015015000000000000` after. Without the accrual the assertion would have been vacuous — the story's stated top risk was real and is genuinely prevented. Story's figure reproduced to the wei on both legs. |
| both legs run | **YES** | armed: 394 txs, exit 0. dormant: the real `npm run dev` end-to-end through `serve`, 391 txs. |
| ACL end state (deployer + V2 out, V3 + minter + staker + 5 hooks in) | **YES** | all 10 rows read back with `cast call authorizedMinters` against `mintVersion() == 1` |
| single-file diff | **YES** | `git diff --name-status` = `M script/DeployMocks.s.sol`, nothing else |
| 22 in-source `Story 079` refs byte-identical | **YES** | 22 at both commits, text diff empty across 6 files (only line numbers shift) |
| `local-addresses.ts` names the replacement | **YES** | `:34` = `0xdB05A386…4402` == `configs(1).dispatcher` |
| `/health` `deploymentsLoaded: true` | **YES** | both legs |
| toggle logged top-of-`run()` and in the summary | **YES** | log lines 105 and 437 |
| index-7 static pins | **YES** | both assertions execute and pass |
| price/growth/`disabled` preserved, `dispatcherToIndex` moved both ways | **YES** | on-chain read-back |

**All 18 hold.** That is worth stating plainly: this is the first script-audit story in this family where the
Review's "18/18 verified" survives independent re-execution. The story also disclosed its own shipped
regression rather than burying it. Faithfulness grade: **high**.

The single substantive deviation from *Implementation Notes* is Decision 9 (structural instead of live
intermediate-window probe), which the story text explicitly permits — so it is not an infidelity, but it does
leave the gate hole in **DEV27-02**.

### 5c. Q-01 (`1c98937375ad`) — **STILL FULLY OPEN, and mildly aggravated**

Q-01 is that six scripts attribute their most substantial change to a *"Story 079"* that does not exist.
A document numbered 079 now exists — but it is the **run-26 remediation story**, and it says so itself
(*"This story is NOT that missing story… Q-01 remains open"*), lists Q-01 as explicitly out of scope, and
instructs the executor not to touch the 22 references. I confirmed all 22 are byte-identical at HEAD.

So the referenced work — the PhlimboV2→V3 cutover rehearsal, DepositPageViewV3, the address-book restructure —
**still has no acceptance criteria anywhere**. Grade: **not fixed, not partially addressed, still fully
open.** If anything it is slightly worse: the number is now taken, so a reader resolving `Story 079` from the
source lands on a document describing none of the work that cites it. Recorded as a verification note with
verdict `STILL-LIVE` and `doNotRefile: true` — the existing entry already covers it and must not be
auto-closed.

---

## 6. Skipped-step / half-configured check

The `dev` entry point has no skipped-step siblings in the mainnet sense — it builds a greenfield chain each
run and `clean:local` guarantees a fresh leg. The relevant question is instead *"does the chain end
functional?"*, answered affirmatively in §4 (post-swap mint probe, `/health`, `/contracts`).

One standing structural note, unchanged and **not re-filed**: `DeployMocks` writes
`"deploymentStatus": "completed"` unconditionally at `:2605` during forge's local pass, so a half-finished
broadcast is indistinguishable from a clean one in the artifact — which is precisely why the story-074
resume-leg handling is un-rehearsable locally. That is ledger entry `1e8cc0dc58ba0ecb`, still live at HEAD,
cited by the L-01 under verification here, and it must **not** be re-minted as a new finding.
