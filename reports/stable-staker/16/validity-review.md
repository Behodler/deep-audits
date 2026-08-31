# Validity Review — stable-staker, audit run 16

- **Reviewer:** validity-checker · **Date:** 2026-08-31
- **Commit under review:** `fa06de5` (branch `master`) · nested pin `lib/antimatter` = `a5570ce`
- **Documents reviewed:** `submissions/H-01.md`, `submissions/M-01.md`, `submissions/qa-report.md`, `submissions/spec-conformance.md`
- **Context read:** `classified.md`, `sanitized.md`, `findings-deduped.md`, `reports/stable-staker/ledger.json`

## Verdict summary

| Item | Verdict | One-line reason |
|---|---|---|
| **H-01** | **VALID** | Permissionless two-tx path, PoC re-run green, all citations exact, pin correctly disambiguated |
| **M-01** | **VALID** | Passes the surprise test decisively; docs affirmatively assert the falsified property; Medium correctly bounded |
| **QA bundle (L-01..L-07, Q-01..Q-04)** | **VALID** | No H/M contamination, no F-findings, exclusions documented |
| **spec-conformance F-01..F-04** | **NEEDS-REVISION** | F-02 carries stale Antimatter line numbers from the wrong commit |
| **Bundle completeness** | **NEEDS-REVISION (blocking)** | `M-02.md` and the carryover copies are announced but absent |

No finding in this run matches any C4 known-invalid category. Zero malicious-owner vectors were filed.

---

## 1. C4 known-invalid screen

Checked every finding against: non-standard/weird ERC-20 (USDT excepted), fee-on-transfer, approve race /
`safeApprove` front-running, CryptoPunks, user input mistakes / phishing, unused view functions, speculation on
future code, tool-noise without an H/M exploit path, and root cause in an out-of-scope parent/forked contract.

**All clear.** Specifically:

- **No token-behaviour findings.** The only ERC-20 assumption anywhere is `MockERC20` standing in for USDC in
  both PoCs, used as a plain well-behaved token. Nothing rests on rebasing, fee-on-transfer, or a missing return
  value. `lib/antimatter`'s prior "FoT permanently invalid" disposition is not re-litigated here.
- **No approve-race / allowance findings.**
- **No user-mistake findings.** H-01's actor is an unprivileged attacker acting deliberately; M-01 has no
  attacker at all.
- **No unused-view findings.** L-02 (`pendingReward` reads zero for a fully-owed settled user) touches a view
  function but is correctly filed **Low**, not H/M, and is an accuracy defect in a value integrators read — not
  the "unused view" category.
- **Root cause is in-scope in every case.** H-01's root cause is `src/StableStakerV2.sol:817-822` — first-party.
  `lib/antimatter/src/Antimatter.sol:294` appears only as the *realization* leg proving the harm is economic, not
  as the defect. That is the correct use of an out-of-scope dependency: it establishes impact, it is not the bug.
  M-01's root cause is `src/StableStakerV2.sol:619-620` — first-party.
- **Not tool noise.** Both H/M carry independent, re-run PoCs. The 4naly3er output is quarantined in Appendix A
  of the QA report and is not promoted into any finding.
- **Not speculation.** Both findings demonstrate the root cause at shipped trunk code, with executed PoCs.

### Reckless-admin screen (Law 3) — applied per finding

The QA report's claim that **zero centralization labels** were issued and every owner-facing item was filed by
unlocked impact is confirmed against `classified.md:263` (6 items so classified). No document anywhere contains a
"a malicious owner could…" construction. Law 3 compliance is clean.

---

## 2. M-01 — the contestable finding, judged in full

### The surprise test

> Trigger: `Antimatter.setApprovedMinter(staker, false)` during ordinary incident response or decommissioning.
> Question: would a competent, non-malicious owner be surprised that this freezes 100% of a migrating pool's principal?

**Yes — decisively. This is a valid non-obvious footgun, not a reckless admin mistake.** Four independent grounds,
each verified against source at `fa06de5`:

1. **The consequence is in a different contract from the action.** The operator acts on `Antimatter`, a token
   contract. The harm lands in `StableStakerV2`, a custody contract. Nothing at the call site of
   `setApprovedMinter` (`lib/antimatter/src/Antimatter.sol:188`, verified) hints that principal custody depends on it.

2. **The project's own operator-facing documentation asserts the exact opposite, unconditionally.** I read
   `lib/stable-staker/CLAUDE.md:12-13` at `fa06de5` and the quote reproduces **verbatim**:

   > "That is deliberate robustness: a revoked minter role, or any Antimatter revert, can no longer brick a
   > principal path."

   There is no migration carve-out. `docs/deferred-reward-accrual-plan.md:37-38` repeats it ("The principal paths
   now never call the reward token at all, so its availability can neither trap nor degrade principal handling") —
   also verified verbatim. An operator who *does* their homework reaches the wrong conclusion. This is the
   strongest possible form of the surprise test: the harm is not merely non-obvious, it is **affirmatively
   mis-taught**.

3. **The in-source NatSpec makes the same false claim, twice.** Verified at `fa06de5`:
   `src/StableStakerV2.sol:391-392` ("Works while paused and never mints, so a broken mint path can never trap
   principal") and `:829-831` ("Never calls Antimatter, so a revoked minter role cannot brick the principal paths
   that reach here"). Both are true of `stake`/`withdraw`/`emergencyWithdraw` and false of the terminal migration
   exit. Per the standing rule that in-source NatSpec carries no suppression authority and that falsely-exhaustive
   docs *raise* severity, this is aggravating, not mitigating.

4. **The failure is state-conditional and therefore invisible in normal operation.** It only bites while
   `poolState == Migrating`. Revoke on an `Active` pool and nothing breaks — which actively trains the operator
   that the action is safe.

**The "obvious harm" reading fails.** An obvious misconfig is one where the operator can see the consequence from
the action — setting a price to zero, pointing at a malicious token. Here the operator cannot see it from either
contract, and the two documents they would consult tell them it cannot happen. Verdict: **VALID**.

### The `renounceOwnership` leg — the classifier was right

**I agree with the classifier, and with M-01's own reasoning, that this leg does not carry the finding to High.**
`renounceOwnership` is the canonical irreversible action; every competent operator understands that calling it
permanently disables all `onlyOwner` functions, `setApprovedMinter` included. The consequence of *that step* is
obvious even though the consequence of the *first* step is not. Resting a High on an obvious-consequence admin
action would be exactly the reckless-admin invalid pattern.

I verified the permanence mechanics are nonetheless real and correctly stated, so the branch is legitimately worth
*stating*: `StableStakerV2.antimatter` is `immutable` at `:60` with no setter (verified), and at the `a5570ce` pin
`Antimatter` is declared `contract Antimatter is ERC20, Ownable, Pausable, ReentrancyGuard, IPausable` — plain
`Ownable`, **not** `Ownable2Step`, with no `renounceOwnership` override anywhere in the file (grep returned no
override). M-01 handles this correctly: the branch is prominent, its severity contribution is argued and
**rejected**, and the rejection reasoning ((a) second independent discretionary act, (b) obvious-consequence,
(c) demonstrated single-call recovery) is sound. **Medium is the right label, and it is right for the right reasons.**

### Ledger hygiene

- **Fingerprint preserved verbatim.** Report carries `e4567dc343655af93ee23650220f46606aaa27ed173364f87f5d9038937d059d`;
  ledger carries the identical string. ✅ No re-mint.
- **Prior status was `wont-fix`, never `fixed`.** Confirmed in `ledger.json`. ✅
- **The report does NOT claim a regression.** It states plainly: *"This is NOT a regression… the finding was never
  marked `fixed`, and no patch for it was ever written."* ✅ Correct, and it correctly names the re-file ground as
  falsified closure.
- **`triageReason` quoted verbatim and in full.** Byte-compared against `ledger.json`. ✅ Exact match, including the
  "obvious admin misstep… and recoverable" clause it goes on to contest. The prior `reclassNote` is not overridden,
  and the conceded half (the `(R,P)` snapshot freeze is intended design) is carried forward untouched.

This is a model disclosure for re-filing an owner `wont-fix`.

---

## 3. H-01 — validity and evidentiary chain

**VALID.** Not overstated.

- **Permissionless.** Two transactions, no privileged role, no MEV requirement, no race. The owner's only
  contribution is an *omission*, and the exploit actor is an unprivileged external address. This does not touch the
  reckless-admin exclusion.
- **The absence claim is mechanically verified.** H-01 asserts "nothing in the codebase ever zeroes
  `antimatterPerSecond`." I enumerated every occurrence in `src/StableStakerV2.sol` at `fa06de5`: lines
  24, 28, 33 (comments), 70 (declaration), 140 (event), **217 (the only write — the owner setter)**, 750 and 822
  (reads). **Confirmed: `:217` is the sole write and no automatic zeroing path exists.** The claim survives the
  enumeration standard that absence-of-remedy claims are held to. It is also correctly *not* overstated into "the
  owner cannot fix it" — mitigation 3 explicitly recommends `antimatterPerDay(token, 0)`.
- **The novelty is correctly located.** The 1-wei-captures-100% mechanic is ordinary MasterChef behaviour and would
  be a non-finding on its own. What makes it reportable is story-023's token swap: the emitted unit is now
  redeemable through permissionless `annihilate` into unbacked phUSD, so the emission has a real cost basis. H-01
  makes exactly this argument and does not pretend the share-math itself is novel. That is honest framing.
- **The harm is measured, not asserted.** `test_dilutionIsRealizable` runs the real `annihilate` and measures phUSD
  supply against backing. The distinction between the ~900k stablecoin *liquidity* requirement and *capital at
  risk* is correctly drawn — it returns inside the same call.
- **Not padded.** The anti-inflation note is present and correct: H-01, M-02 and L-06 share a root class, are kept
  separate for distinct triggers/remedies, and the reader is explicitly told **not to total them**. Counter-argument
  5 concedes the emission-cap known-issue holds and attacks only its cost basis — a legitimate, narrow move rather
  than a suppression override.

**Contestability, stated honestly:** the strongest counter is that the enabling state needs a pool that is both
armed and empty, which reads like an external requirement (⇒ Medium). H-01 anticipates this as counter-argument 1
and answers it with reachability case (d) — organic emptying is the terminal state of *every* pool — which the PoC
reaches with real calls only, no `vm.store`. Given the verified absence of any automatic disarm, I find that answer
persuasive. **High stands**, and the counter-argument is preserved in the report so a reader can weigh it.

---

## 4. Evidentiary chain — verification performed

### 4.1 Code citations spot-checked (11, exceeding the required 6) — all against `git show fa06de5`

| Citation | Verdict |
|---|---|
| `StableStakerV2.sol:806-826` (`_updatePool`, incl. `:817-819`, `:822`, `:824`) | ✅ **Exact**, line-for-line |
| `StableStakerV2.sol:333` `require(credited > 0, ...)` | ✅ Exact |
| `StableStakerV2.sol:385` `antimatter.mint(msg.sender, owed);` | ✅ Exact |
| `StableStakerV2.sol:613-622` (`_exitPosition`, root cause `:619-620`) | ✅ **Exact**, line-for-line |
| `StableStakerV2.sol:347` / `:397` pool-not-active guards | ✅ Both exact |
| `StableStakerV2.sol:675` `"stakers remain"` | ✅ Exact |
| `StableStakerV2.sol:912-914` `rescueERC20` reserved/require | ✅ Exact |
| `StableStakerV2.sol:60` `IAntimatter public immutable antimatter;` | ✅ Exact |
| `StableStakerV2.sol:391-392` / `:829-831` NatSpec quotes | ✅ Both verbatim |
| `StableStakerV2.sol:214-218` `antimatterPerDay` | ✅ Exact |
| `CLAUDE.md:12-13`, `docs/deferred-reward-accrual-plan.md:37-38` | ✅ Both verbatim |

**Zero incorrect citations in `H-01.md`, `M-01.md`, or `qa-report.md`.** One defect in `spec-conformance.md` — §5.

Minor, non-blocking: `M-01.md` cites the docs quote as `docs/deferred-reward-accrual-plan.md:35-38`; the quoted
sentence actually spans `:37-38`. The cited range contains it, so the quote is not wrong — merely loose. No action required.

### 4.2 The `lib/antimatter` pin — verified, and the directional claim is correct

```
$ git -C lib/stable-staker ls-tree HEAD lib/antimatter
160000 commit a5570ce1e96873dc1bc42252580efeab4c88f206	lib/antimatter
```

- **H-01 cites `a5570ce:294` — CORRECT.** Verified in the nested checkout (`lib/stable-staker/lib/antimatter`,
  HEAD = `a5570ce1e968…`): line 294 is `_phUSD.mint(recipient, amount);`, preceded by the comment
  *"The antimatter half, minted straight to the recipient."* This is the unbacked mint.
- **The `:263` disambiguation note is CORRECT.** Top-level `lib/antimatter` HEAD is `3a96fb7`, and its line 263 is
  the identical `_phUSD.mint(recipient, amount);`. H-01's reader note is accurate.
- **The Pausable directional claim is CORRECT — I verified the direction specifically, since it was reversed once
  before.** At `a5570ce`, line 24: `contract Antimatter is ERC20, Ownable, Pausable, ReentrancyGuard, IPausable`.
  At `3a96fb7`, line 22: `contract Antimatter is ERC20, Ownable, ReentrancyGuard`. **The pin HAS `Pausable`; the
  newer top-level HEAD DROPPED it.** H-01 states exactly this. ✅ The prior correction held.

H-01's handling of the nested-pin trap is exemplary and should be the template.

### 4.3 PoCs — re-run by me, output pasted

Both files exist. Executed `forge test --match-path 'test/poc/Run16_*' -vvv` in
`/home/justin/code/audits/workspace/stable-staker`:

```
Ran 3 tests for test/poc/Run16_M01_MigrationExitMintTrap.t.sol:Run16M01PoCTest
[PASS] test_migrationExitRevertsWhenMinterRevoked() (gas: 440040)
Logs:
  expected revert data (NotApprovedMinter(staker)):
  0x6830132b0000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b
[PASS] test_principalIsFullyTrapped() (gas: 460400)
Logs:
  trapped principal (USDC wei) : 1000000000000
  staker USDC balance          : 1000000000000
  stakerCount                  : 2
[PASS] test_recoveryByReApproval() (gas: 494268)
Logs:
  Alice recovered (USDC wei): 600000000000
  Bob credit to migrator    : 400000000000
  AM minted on recovery     : 299999999999999998080000
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 13.53ms (3.70ms CPU time)

Ran 3 tests for test/poc/Run16_H01_EmptyPoolEmissionCliff.t.sol:Run16H01PoCTest
[PASS] test_dilutionIsRealizable() (gas: 666999)
Logs:
  AM annihilated (18dp)        : 899999999999000000000000
  USDC supplied by attacker    : 899999999999
  phUSD supply increase        : 1799999999998000000000000
  new backing deposited (18dp) : 899999999999000000000000
  UNBACKED phUSD minted        : 899999999999000000000000
  attacker phUSD balance       : 1799999999998000000000000
[PASS] test_dustStakeCapturesFullEmission() (gas: 424053)
Logs:
  antimatterPerDay          : 10000000000000000000000
  antimatterPerSecond       : 115740740740740740
  elapsed seconds (90 days) : 7776000
  full-rate stream for window (elapsed * perSecond): 899999999999999994240000
  attacker capital (USDC wei): 1
  attacker AM minted        : 899999999999999994240000
[PASS] test_emptyPoolAccruesNothing() (gas: 284260)
Logs:
  acc before empty window   : 99999999999999999360000000000
  acc after  empty window   : 99999999999999999360000000000
  lastRewardTime advanced by: 7776000
  Alice claimable before    : 9999999999999999936000
  Alice AM actually minted  : 9999999999999999936000
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 13.57ms (3.48ms CPU time)

Ran 2 test suites in 2.27s (27.10ms CPU time): 6 tests passed, 0 failed, 0 skipped (6 total tests)
[exited with code 0]
```

**6/6 pass, observed by me.** Every logged number in both submission documents reproduces **byte-identically**
against my own run — including the `NotApprovedMinter` selector `0x6830132b`, the 100%-of-budget equality
(`899999999999999994240000` in both the "full-rate stream" and "attacker AM minted" rows), and the unbacked-phUSD
figure. The transcripts pasted in the reports are genuine, not reconstructed.

Non-vacuity checks confirmed present: both suites carry tripwires asserting the pre-exploit state actually holds,
and `test_emptyPoolAccruesNothing` shows `acc before == acc after` — a real measured invariant, not `0 == 0`.
The `MockYieldStrategy` caveat is correctly disclosed and correctly reasoned: it sits on the **backed** half only
and cannot manufacture the measured dilution.

### 4.4 No finding rests on an audit-authored test file

```
$ git -C lib/stable-staker ls-tree -r HEAD --name-only | grep -i "poc\|Run16"
(no output)
```

Neither PoC is in the project tree, and **neither is cited as project code** — both are referenced only by their
`workspace/stable-staker/test/poc/…` paths, correctly labelled as audit artifacts.

I additionally verified the non-Solidity files F-04 relies on **are** genuine project code at `fa06de5`:
`.github/scripts/check-migration-surface.sh` and `.claude/hooks/protect-migration-surface.sh` are both in
`git ls-tree fa06de5`, and their cited lines match — `:88` is
`FROZEN_FILES=(src/versions/v1/StableStakerV1.sol src/versions/v1/IStableStakerV1.sol)` (which does substantiate
F-04's "the vendored pair is not covered"), and hook `:38` is
`PROTECTED=(initiateMigration batchMigrate depositFor)`. ✅ No misattribution.

---

## 5. Defects requiring action

### DEFECT 1 — `spec-conformance.md` F-02 carries Antimatter line numbers from the wrong commit — **NEEDS-REVISION**

`spec-conformance.md:227-228` cites `lib/antimatter/src/Antimatter.sol:226-267` and states *"`:263` mints the AM
half as phUSD with no stablecoin behind it."*

**Those are `3a96fb7` line numbers, not the `a5570ce` pin the project compiles against.** At `a5570ce`:

- line **263** is `PhusdStableMinter minter = phUSDMinter;` — **not** a mint at all;
- `annihilate` begins at **:253** and ends at **:298**, not `:226-267` (`:226` is mid-NatSpec);
- the unbacked mint is at **:294**.

This is precisely the error that was caught and corrected in `H-01.md` — the correction did not propagate to
`spec-conformance.md`. It is a citation defect, not a substantive one: the underlying claim is true and is proven
at the correct line by H-01. But a reader following F-02's pointer lands on an assignment statement and will
reasonably conclude the finding is sloppy.

**Fix:** in F-02, replace `:226-267` → `:253-298` and `:263` → `:294`, and add H-01's one-line pin note. The same
`grep -n "Antimatter.sol:" ` sweep should be run over `classified.md` before it is relied on downstream — it
carries the identical stale `:263` at line 200.

### DEFECT 2 — the submission bundle is incomplete — **NEEDS-REVISION (blocking)**

`submissions/` contains only `H-01.md`, `M-01.md`, `qa-report.md`, `spec-conformance.md`. But:

- **`M-02.md` is missing.** `classified.md:14` labels M-02 **MEDIUM** (`finalizeAndReset` revives a pool at a stale
  emission rate). `qa-report.md:8` states High/Medium findings "`H-01`, `M-01`, `M-02` are submitted individually",
  and `H-01.md` twice refers the reader to M-02 for the revival remedy it deliberately does not cover. **No such
  document exists.** A Medium that every other document points at, and that carries a remedy H-01 explicitly
  disclaims, would ship into a void.
- **`submissions/carryover/` does not exist.** `qa-report.md:232` states L-06 (`86fcf00ef786f496`) "is copied —
  pruned to what remains open — by finding-manager into `submissions/carryover/`". The directory is absent.
- **The `C-1` carryover copy is missing.** `qa-report.md:233` states the `dab5a65613c7af50` Medium (`fix-pending`,
  `HTQ-14-02` HOLD armed) "is copied in full to `submissions/`". It is not there.

The *decisions* here are all correct — L-06 is rightly kept out of the QA bundle and not renumbered, and C-1 is
rightly not filed as centralization. The defect is purely that the promised artifacts were never written. Under
Law 1 (recall beats report-tidiness), a Medium announced-as-submitted but absent from the bundle is the exact
failure mode the visible-channel rule exists to prevent.

**Fix:** produce `M-02.md`, `submissions/carryover/L-06.md`, and the `C-1` copy before submission — or amend the
three cross-references to say where those findings actually live. Do not ship the bundle with dangling pointers.

---

## 6. Bundle-hygiene checks

| Check | Result |
|---|---|
| QA report contains no High/Medium findings | ✅ Contents are exactly `L-01`..`L-05`, `L-07`, `Q-01`..`Q-04`. No H/M. |
| `F-01`..`F-04` are NOT in the QA bundle | ✅ Explicitly excluded and routed, at `qa-report.md:8` and `:234`. Only cross-references appear. |
| 4naly3er output quarantined | ✅ Appendix A, clearly marked verbatim tool output, not promoted into findings. |
| No finding overstated relative to evidence | ✅ H-01's High is argued against its own strongest counter; M-01's High case is raised and **rejected** by the author. |
| No padding | ✅ Anti-inflation note present; risk explicitly declared non-additive across H-01/M-02/L-06. |
| Label collisions | ✅ `L-06` reserved to the carryover entry and not reused; this run's new Tier-3 Low is `L-07`. Handled deliberately. |
| Tier-3 honesty section | ✅ Gaps stated as gaps; `fail_on_revert=true` flagged as load-bearing. |
| `MR-16-01` disposal | ✅ Correctly left in manual review, unclassified, "Medium if confirmed" — parked in a visible channel, not dropped. |

---

## 7. Bottom line

**Both High/Medium findings are solid and should ship.** H-01 and M-01 are well-evidenced, correctly severity-bounded,
free of every C4 known-invalid pattern, and their PoCs reproduce byte-identically under my own execution. M-01's
re-file disclosure is the cleanest handling of an owner `wont-fix` re-weigh I have reviewed. H-01's nested-pin
citation discipline should be the template for the rest of the run.

**Two fixes are required before submission**, neither of which touches the validity of any finding:

1. Correct the stale `Antimatter.sol` line numbers in `spec-conformance.md` F-02 (`:226-267`→`:253-298`, `:263`→`:294`),
   and sweep `classified.md:200` for the same error.
2. Write the announced-but-missing `M-02.md`, `submissions/carryover/L-06.md`, and the `C-1` carryover copy — or
   amend the cross-references that point at them.


---

## Post-review note — H-01 retracted 2026-08-31 (mechanism disproved)

**This review validated `H-01`, and it missed the defect that actually sinks it.**

The finding's mechanism was disproved in session on 2026-08-31: `_updatePool`'s empty branch
(`src/StableStakerV2.sol:816-819`) sets `pool.lastRewardTime = block.timestamp` and returns, and `stake`
calls `_updatePool` at `:327` **before** `pool.totalStaked += credited` at `:335`. The pool is therefore
still empty at that call, `lastRewardTime` fast-forwards, and the new staker's `rewardDebt` is set
against an index that never advanced. **The dormant window is discarded, not banked** — textbook
MasterChef, and correct behaviour. The PoC warped 90 days *after* the 1-wei stake, so it only ever
showed a sole dust-sized staker collecting the full rate **going forward**; `test_emptyPoolAccruesNothing`
(`accAntimatterPerShare` unchanged, `lastRewardTime` advanced) was the **refutation**, read as support.

What survives is Low: emission is time-denominated and TVL-independent, so an armed pool with negligible
stake still mints at its full scheduled rate, and post-story-023 those tokens are claims on unbacked
phUSD — but the emission is **budgeted** and merely misallocated, no staker is deprived, and any genuine
staker dilutes the dust holder pro rata at once. Re-labelled **`L-09`**, severity **High → Low**, status
**`wont-fix`** by owner decision of 2026-08-31 (`issueId` `ss16h1` unchanged; report retained at
`submissions/H-01.md`).

**Process signal, recorded as fact.** Both adversarial passes — this one and its counterpart
(`severity-audit.md` §1 / `validity-review.md` §1) — affirmed the finding, and **neither identified the
`:817-819` fast-forward**. Each re-verified the claims the report made (time-denominated numerator,
1-wei entry, permissionless `annihilate`, unbacked mint at `Antimatter.sol:294`) and each found those
claims true; what went unchallenged was the report's *framing* of what happens before the stake — the
one premise on which the severity rested. The mechanism error therefore survived classification plus two
independent adversarial passes. Verifying every cited line is not the same as testing the causal story
the lines are assembled into.

Nothing else in this review is altered or withdrawn by this note.
