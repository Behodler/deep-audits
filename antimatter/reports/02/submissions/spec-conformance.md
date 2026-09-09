# Spec-Conformance Report (Law 2) — antimatter-02

**Project:** antimatter · **Commit:** `c91bc1a` (`c91bc1a44424b853247a3849732bf89547defdec`) · **Branch:** `master`
**Repo:** https://github.com/Behodler/antimatter · **Run:** antimatter-02 (regression scan, `0bb82d8..c91bc1a`)

Law-2 findings are labelled `F-xx` and reported here at honest severity. They are **never** folded
into the QA/gas bundle — a deviation from stated behaviour is not noise.

| Label | issueId | Fingerprint | Severity | Status | Subject |
|---|---|---|---|---|---|
| **F-04** | `am2f4` | `d34180996ba41ff8` | Low | **new this run** | Untagged commit `c91bc1a` rewrites the settlement post-condition; no story authorises it, story-001 forbade touching it, and story-001's checklist still certifies it was preserved |
| F-01 | `am1f1` | `3aac91383dcb6060` | Low | open — **carried over** (§6) | Measured-balance discipline applied only nominally to the phUSD leg |
| F-02 | `am1f2` | `78612be9264d2b49` | Low | open — **carried over** (§6) | The nominated no-burn trip-wire is a four-name denylist, not an invariant |
| F-03 | `am1f3` | `9d06644ddad24e5a` | Low | open — **carried over** (§6) | Header NatSpec justifies the unbacked mint with a redemption symmetry that does not exist |

Delta under review — three commits, of which two carry story tags and one does not:

| Commit | Subject | Story |
|---|---|---|
| `c394ee3` | `[story-001] Replace annihilateFrom with annihilate to close third-party minting vector` | story-001 |
| `f48f30d` | `[story-002] Cross-check registered decimals against the token in toStableAmount` | story-002 |
| `c91bc1a` | `more precise mint requirement` | **none** → F-04 |

---

## 1. Law-2 status change — story resolution is FIXED, and faithfulness is GRADED for the first time

> **Read this first.** At run-01 this project's story mapping was **UNRESOLVED**: `registered-projects.json`
> carried `storyDir: null` and every faithfulness verdict was reported as
> **UNRESOLVABLE-PENDING-MAPPING**, because antimatter had no entry in
> `~/code/product-owner/registered-project-list.md` (run-01 spec-conformance §1, checks (a)–(d)).
> **That gap is now closed.** This is the **first run in which Law-2 story faithfulness could
> actually be graded for antimatter** — the verdicts below are graded conformance, not deferral.

The mapping was **re-derived mechanically, not guessed**, by the route `CLAUDE.md` prescribes:

1. **Registry line — HIT.** `~/code/product-owner/registered-project-list.md` **line 32** reads:

   ```
   antimatter:reflax-mint/antimatter
   ```

2. **Mechanical verification of that line.**
   `git -C ~/code/reflax-mint/antimatter remote get-url origin` → `git@github.com:Behodler/antimatter.git`.
   The remote's basename, `antimatter`, equals the audit project name, so the mapping resolves by the
   authoritative rule rather than by resemblance.

3. **Story tree confirmed present.** `~/code/product-owner/stories/antimatter/` exists and carries the
   sprint directory `annihilate/`. `registered-projects.json:496` now records `storyDir: "antimatter"`,
   with the supersession of the stale 2026-08-18 UNRESOLVED note documented at `:497`.

Run-01's four negative checks were therefore **correct at the time and are now stale**: the mapping line
had not yet been written when they ran. Run-01's re-grade trigger #1 ("a human adds an `antimatter`
mapping") has fired, and this report is the re-grade.

**Stories resolved for this delta.** Globbing the whole project tree (not one sprint, not one state
folder) resolves both tags to exactly one document each:

- `story-001` → `~/code/product-owner/stories/antimatter/auto-complete/annihilate/001-replace-annihilate-from-with-annihilate.md`
- `story-002` → `~/code/product-owner/stories/antimatter/auto-complete/annihilate/002-cross-check-registered-decimals-against-token.md`

Both were read in full and graded clause by clause below. Nothing in this report is a
"story unavailable" non-answer.

---

## 2. story-001 — CONFORMS IN FULL (14 of 14 clauses)

**Story:** *Replace `annihilateFrom` with `annihilate` to close the third-party minting vector*
**Implementing commit:** `c394ee3` · **State folder:** `auto-complete/` (see §5)
**Motivation:** this audit's own run-01 **H-01** — the dual-asset allowance vector.

The story's central demand (story-001:20–30) is that `annihilateFrom(stable, from, recipient, amount)`
be replaced by `annihilate(stable, recipient, amount)`, with both halves taken from `msg.sender`. That is
what landed at `src/Antimatter.sol:221`:

```solidity
221:    function annihilate(address stable, address recipient, uint256 amount) external nonReentrant {
...
239:        _burn(msg.sender, amount);
...
246:        IERC20(stable).safeTransferFrom(msg.sender, address(this), stableAmount);
```

### Per-clause verdicts

| # | Story clause (line) | Verdict | Evidence at `c91bc1a` |
|---|---|---|---|
| 1 | :194 "Write the failing tests first (TDD), then make them pass." | CONFORM | Story record documents red-then-green; test file grew +59/−38 in the same commit. Process clause, self-reported. |
| 2 | :195 / :38–39 **HARD REQUIREMENT** — "This is a hard replacement. **Do not keep `annihilateFrom`, and do not add a deprecated shim or overload** — the vulnerable signature must not remain reachable." | **CONFORM** | `grep -rn annihilateFrom` over the **entire tree including `lib/`** returns **0 hits**. No shim, no overload, no dead NatSpec reference. The only external entry point is `annihilate` at `:221`. |
| 3 | :196 / :28–29 **HARD REQUIREMENT** — "the `_spendAllowance` call is **deleted, not merely made conditional**" | **CONFORM** | `grep -rn _spendAllowance src/` returns **0 hits**. `:237–239` replaces it with a comment stating why none is needed: *"A self-burn takes no allowance, so none is checked or spent."* |
| 4 | :197 / :120–121 "`_burn(from, …)` → `_burn(msg.sender, …)`; `safeTransferFrom(from, …)` → `safeTransferFrom(msg.sender, …)`" | CONFORM | `:239` `_burn(msg.sender, amount)`; `:246` `safeTransferFrom(msg.sender, address(this), stableAmount)`. `recipient` is never debited. |
| 5 | :198 / :122–126 "the check order, the burn-before-interactions ordering, the balance snapshots, the `forceApprove`/reset pair, the `StableNotDeposited` and `PhUSDNotReceived` assertions … stays exactly as it is" | **CONFORM as landed at `c394ee3`** | Verified byte-for-byte in the story commit. **⚠ NO LONGER TRUE AT `c91bc1a` — this is exactly the divergence F-04 records. See §4.** |
| 6 | :199 / :130–144 Rename `Annihilated.from` → `annihilator`, emit `msg.sender`, update NatSpec | CONFORM | `src/Antimatter.sol:106–113` declares `address indexed annihilator`; `:263` emits `msg.sender` in that position; `:101` NatSpec updated. |
| 7 | :200 Rewrite the NatSpec for the new signature, remove all mention of acting on another holder's behalf, state the self-burn requires no allowance | CONFORM | `:210–213`: *"The antimatter half is a burn of the caller's own balance, so no antimatter allowance is consulted or spent — an allowance over another holder confers no power here."* No residual third-party language. |
| 8 | :201 Update the `{annihilateFrom}` cross-reference in `rescueERC20`'s NatSpec | CONFORM | `:304`: *"A backstop only. `{annihilate}` settles whole or not at all…"* |
| 9 | :202–203 Update all 19 call sites to the 3-arg form; delete `test_thirdPartySpendsAntimatterAllowance` and `test_selfAnnihilationDoesNotSpendAllowance` | CONFORM | `test/Annihilation.t.sol` now holds **21** `antimatter.annihilate(` call sites, all 3-arg (19 converted + 2 added by the new tests). Both named tests return **0 hits**. |
| 10 | :204 Add a test proving an antimatter allowance grants no power — a `type(uint256).max` spender cannot touch the holder's antimatter, stablecoin or approval | CONFORM | `test_antimatterAllowanceGrantsNoPowerOverHolder` at `test/Annihilation.t.sol:133`. |
| 11 | :205–206 Add a test proving the stablecoin is pulled from `msg.sender` not `recipient`; add a test that annihilating without a stable approval reverts and burns nothing | CONFORM | `test_stableIsPulledFromCallerNotRecipient` at `:150`; `test_annihilateWithoutStableApprovalRevertsAndBurnsNothing` at `:275`. |
| 12 | :207–208 / :172–177 Keep `test_noPublicBurnEntryPoints` passing **without weakening it**; **"Keep all four entries"**; add the clarifying comment. Update `ReentrantStable` so the reentrancy test still proves the guard | CONFORM | `test/Annihilation.t.sol:416–417` retains all four signatures unchanged; `:413–415` adds the clarifying comment. `test/mocks/ReentrantStable.sol:29` now calls `antimatter.annihilate(address(this), attacker, 1 ether)` and `:7` doc-comment is updated. **Note: this clause now *codifies* open finding F-02 — see §6.2.** |
| 13 | :209 Update both `CLAUDE.md` policy sections to name `annihilate`, keeping the rules intact | CONFORM | `lib/antimatter/CLAUDE.md:93`, `:95`, `:110` now name `annihilate`; both rules' substance is unchanged. |
| 14 | :210 `forge fmt --check`, `forge build --sizes`, `forge test -vvv` all clean | CONFORM | Story record: 50/50 pass, Antimatter 13,328 bytes runtime, fmt/build clean at `c394ee3`. |

**Verdict: 14 / 14 CONFORM.** The two hard requirements — no surviving `annihilateFrom` in any form,
and outright deletion rather than conditioning of `_spendAllowance` — are the strongest results here,
because each is checkable by a negative grep and each returns zero. The vector run-01 H-01 described is
closed at the root: with no `from` parameter, there is no third-party path to another holder's
stablecoin approval to close in the first place.

---

## 3. story-002 — CONFORMS IN FULL (9 of 9 clauses)

**Story:** *Cross-check the registered `decimals` against the token in `toStableAmount` (audit M-01)*
**Implementing commit:** `f48f30d` · **State folder:** `auto-complete/` (see §5)
**Motivation:** this audit's own run-01 **M-01** (ledger `a1c81428a47ad295`).

### Per-clause verdicts

| # | Story clause (line) | Verdict | Evidence at `c91bc1a` |
|---|---|---|---|
| 1 | :205 TDD — failing tests first | CONFORM | Story record documents red-then-green; `+30/−0` in `src/`, `+128/−0` in tests, **zero deletions**. |
| 2 | :206 / :104 Add the `IERC20Metadata` import alongside the other `@openzeppelin` imports, after `SafeERC20` | CONFORM | `src/Antimatter.sol:7` — `import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";`, placed immediately after the `SafeERC20` line at `:6`. |
| 3 | :207 / :116–126 Declare `DecimalsMismatch(address,uint8,uint256)` and `DecimalsUnavailable(address)` with house-style NatSpec; `actual` deliberately `uint256` | CONFORM | `:66` `error DecimalsMismatch(address stable, uint8 registered, uint256 actual);` — the mandated asymmetric widths; `:70` `error DecimalsUnavailable(address stable);`. Both carry `@notice`/`@param` blocks. |
| 4 | :208 / :94–99 **Mandated insertion position** — after `if (decimals > 18) revert UnsupportedDecimals(decimals);` and **before** `uint256 scale = …` | **CONFORM** | `:286` is the `decimals > 18` guard; `:292–295` is the cross-check; `:297` is `uint256 scale = …`. Exactly the specified slot, for the specified reason (`:288`: *"Last among the validations: the two above are free, this one costs an external call."*). |
| 5 | :209 / :30–33 **MANDATED FORM** — use the low-level `staticcall`; **"Do not use `try/catch`"**; do **not** prefer the token's value over the registry — disagreement must revert (fail closed) | **CONFORM** | `:292–295` reproduces the story's snippet exactly:<br>`(bool ok, bytes memory data) = stable.staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));`<br>`if (!ok \|\| data.length != 32) revert DecimalsUnavailable(stable);`<br>`uint256 actualDecimals = abi.decode(data, (uint256));`<br>`if (actualDecimals != decimals) revert DecimalsMismatch(stable, decimals, actualDecimals);`<br>No `try`/`catch` anywhere in `src/`. Neither side's value is preferred; disagreement reverts. |
| 6 | :210 Extend `toStableAmount`'s NatSpec to state the cross-check and that disagreement or unavailability reverts | CONFORM | `:271–279` states both errors by name, the understated-decimals rationale, the fail-closed choice, and the off-chain-quote consequence the story anticipated at :198–201. |
| 7 | :211–221 The twelve named test clauses (happy path ×2, M-01 understated, overstated, `uint256`-returning, >255, empty returndata, short returndata, reverting `decimals()`, codeless address, ordering preserved ×2, end-to-end) | **CONFORM — all present** | Thirteen test functions at `test/Annihilation.t.sol:456–580`, one per named case: `…AcceptsCorrectlyRegisteredSixDecimals` (:456), `…EighteenDecimals` (:461), `…RevertsWhenRegisteredDecimalsUnderstated` (:466), `…Overstated` (:478), `…AcceptsUint256ReturningToken` (:490), `…RevertsOnDecimalsAboveUint8Range` (:497), `…OnEmptyDecimalsReturnData` (:507), `…OnShortDecimalsReturnData` (:515), `…WhenDecimalsCallReverts` (:523), `…OnCodelessStable` (:531), `test_unregisteredStableStillWinsOverDecimalsCheck` (:541), `test_unsupportedDecimalsStillWinsOverDecimalsCheck` (:549), `test_understatedDecimalsExploitIsClosedEndToEnd` (:561). |
| 8 | :222 All pre-existing tests pass unmodified | CONFORM | The six-decimal and eighteen-decimal fixtures (`usdc` 6/6, `dola` 18/18) are consistently registered, so the happy path is untouched; story record reports 63/63 passing. |
| 9 | :223 `forge fmt --check`, `forge build --sizes`, `forge test -vvv` all clean | CONFORM | Story record at `f48f30d`: clean fmt/build, 63/63 tests. |

**Verdict: 9 / 9 CONFORM.** Two results deserve naming. First, the story **deliberately diverged from
this audit's own recommended `try/catch` text** (story-002:130–159, :227–232) and reasoned the
divergence out in full — a return-data decode failure is raised in the calling context and is therefore
uncatchable, so the audit's snippet could never have reached its own `DecimalsUnavailable` branch. The
implementation follows the story, not the audit, and the story is right. That is a correct Law-2
outcome, and the deviation is documented in the story's Concerns rather than left silent. Second, the
ordering clause is verified positively, not assumed: `StablecoinNotRegistered` (`:285`) and
`UnsupportedDecimals` (`:286`) both still pre-empt the new check, with a dedicated test for each.

---

## 4. F-04 — `am2f4` · `d34180996ba41ff8` · Low

**An untagged commit rewrites the annihilation settlement post-condition on top of a two-story
fix-wave: no story authorises it, story-001 explicitly forbade touching that logic, and story-001's
acceptance checklist still self-certifies that it was preserved**

`src/Antimatter.sol` · `annihilate` · L229–L248 → now L230–L257 at HEAD (quote at **L234**, guard at **L257**)
Commit: `c91bc1a` — *"more precise mint requirement"* · **Story tag: NONE**

> ### LEAD WITH THIS: **NO CODE CHANGE IS REQUIRED.**
> The change `c91bc1a` makes is **safe, tested, and strictly stricter** than the check it replaced. It
> is, in substance, **this audit's own run-01 F-01 recommended mitigation implemented very nearly
> verbatim**. This finding is **not** criticism of the fix. What is owed is a **story** — so that a
> future regression of this post-condition has acceptance criteria to be graded against.

### 4.1 What changed

`c91bc1a` (16 lines in `src/`, 51 lines of new tests) replaced the post-hoc non-zero check with a
pre-computed quote plus an exact-equality assertion:

```solidity
232:        // What the minter says it will mint for that deposit. Measuring against its own quote,
233:        // rather than merely against zero, means a short mint cannot pass unnoticed.
234:        uint256 expectedForStable = minter.calculateMintAmount(stable, stableAmount);
235:        if (expectedForStable == 0) revert PhUSDNotReceived();
...
256:        uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;
257:        if (mintedForStable != expectedForStable) revert PhUSDAmountMismatch(expectedForStable, mintedForStable);
```

The prior form was a single post-hoc line — `if (mintedForStable == 0) revert PhUSDNotReceived();` —
sitting where `:257` now sits.

### 4.2 The Law-2 deviation

Neither story sanctions a change to the phUSD settlement post-condition.

- **story-002 is confined to `toStableAmount`** (story-002:44–45: *"`toStableAmount` is the **single**
  place scaling happens. Story 001 explicitly leaves it alone, so this story owns it outright."*). It
  says nothing about settlement.
- **story-001 explicitly placed this logic out of bounds.** Required delta #5, lines 122–126:

  > *"Everything else — the check order, the burn-before-interactions ordering, the balance snapshots,
  > the `forceApprove`/reset pair, the **`StableNotDeposited` and `PhUSDNotReceived` assertions**, the
  > split `_phUSD.mint(recipient, amount)` + `safeTransfer(recipient, mintedForStable)` delivery —
  > stays exactly as it is. **This story is a signature and authorisation change, not a rewrite of the
  > settlement logic.**"*

  `PhUSDNotReceived` is named in a do-not-touch list, and the scope statement is explicit.

`c91bc1a` lands **after** both story commits, carries **no `[story-NNN]` tag**, and no story anywhere
under `~/code/product-owner/stories/antimatter/` authorises it. It is un-storied work riding on a
two-story fix-wave; the fix-wave's traceability (H-01 ← story-001, M-01 ← story-002) does not extend to
it. `c91bc1a` is the **only** untagged commit in the `0bb82d8..c91bc1a` delta.

### 4.3 The evidentiary core — a closed story that self-certifies a preservation that no longer holds

**story-001, acceptance checklist, line 198, is TICKED:**

```
- [x] Preserve the existing settlement order and all balance-measured assertions unchanged
      (`StableNotDeposited`, `PhUSDNotReceived`, `forceApprove` reset).
```

- **That statement was TRUE at `c394ee3`**, when story-001 landed. §2 clause 5 grades it CONFORM on
  that basis.
- **That statement is FALSE at `c91bc1a`.** `PhUSDNotReceived` has been **repurposed** (below) and the
  settlement post-condition has been **replaced** by an exact-equality check against a pre-computed
  quote.

**A closed story therefore self-certifies as satisfied while the code has diverged from it** — on the
one function every open finding on this project passes through. The story record is no longer a
description of the code, and nothing in the story tree records the decision that changed it. That is
the finding's durable gap, and it is evidenced from the story's own artefact rather than from the
auditor's reading of it.

### 4.4 Side effect: `PhUSDNotReceived` is retained by name but REPURPOSED

This is the part most likely to bite an integrator, and neither story mentions it:

| | Before `c91bc1a` | At `c91bc1a` |
|---|---|---|
| `PhUSDNotReceived` **means** | "the minter delivered nothing" | "the minter's **quote** was zero" (`:235`) |
| and **fires** | **after** the burn (`_burn` at `:239`) | **before** the burn (`:235` precedes `:239`) |
| "minter delivered nothing" now surfaces as | — | `PhUSDAmountMismatch(expected, 0)` at `:257` |

The selector survives; its meaning does not. **Any off-chain monitor keying on the old selector's
meaning is silently re-pointed** — it will now see `PhUSDNotReceived` for a condition it never used to
signal, and will stop seeing it for the condition it was written to catch. The pre-burn firing position
is also a behavioural change in its own right: a class of failure that previously reverted after the
burn (and rolled back) now reverts before it.

### 4.5 Why this is Low, and why it is here rather than in the QA bundle

**Asset impact: NONE.** The new post-condition is strictly stricter than the one it replaces: every
state the old check accepted and the new one rejects is a state in which the caller received less than,
or differently from, the minter's own quote.

One hypothesis was tested and is **NEGATIVE**: that a partially-binding daily cap could make the
minter's actual mint differ from its own quote, so a previously-succeeding annihilation now reverts.
`PhusdStableMinter.mint:221` enforces the cap as
`require(config.mintedToday + phUSDAmount <= config.maxMintPerDay, "Daily mint limit exceeded")` —
all-or-nothing, never a partial mint — and it calls the same `calculateMintAmount` on the same config in
the same transaction. The only reachable divergence is extra phUSD arriving on Antimatter between the
`phUSDBefore` snapshot (`:244`) and the delta read (`:256`) — a callback from a hookful stablecoin during
`safeTransferFrom`, or from the yield strategy during `minter.mint`. That case previously
**over-credited** the caller-chosen recipient (open ledger finding L-01) and now **reverts**. No
legitimate flow that succeeded before `c91bc1a` fails after it.

**Routing is not negotiable.** Law 2 is a routing law before it is a severity law: this finding belongs
in spec-conformance and **never** in the QA/gas bundle, at any band. It is deliberately **not**
collapsed into the run's QA finding Q-05, which covers the over-claiming comment at `:232–233` on the
same commit. Both point at the same missing review, but Q-05 carries the F-01 false-closure tripwire and
belongs in the QA bundle; collapsing them would hide that tripwire inside a process finding.

**Band.** Low. The code is safe, tested, strictly stricter, and substantially the audit's own
recommendation, so no security escalation is engaged and Medium is not in play. It is not mere QA
either, for a checkable reason: an unreviewed, untagged behavioural change to `annihilate`'s settlement
post-condition landed in the **same delta** as the fixes for the project's only open High and its open
Medium, in the **one function every open finding passes through**, story-001 had **explicitly** placed
that assertion out of bounds, **and** story-001's checklist still carries a ticked box asserting it was
preserved.

### 4.6 Recommendation

1. **No code change.** Leave `:234`, `:235` and `:257` exactly as they are.
2. **Write the story** — amend story-002 or add story-003 — recording this decision, its acceptance
   criteria and its failure-mode analysis, so the exact-equality post-condition has a documented intent
   to be graded against in future regressions.
3. **Correct story-001's acceptance checklist at line 198**, which now certifies a preservation that no
   longer holds.
4. **Address Q-05 in that story:** the comment at `:232–233` claims coverage the check does not provide,
   and the story is the right place to decide whether the intent is the narrow check that exists or the
   slippage guard the comment describes.
5. **Document the `PhUSDNotReceived` repurposing** (§4.4) in the same story, for off-chain consumers.

---

## 5. Process observation — machine-approved stories with zero independent validation

**This is a Law-2 process fact, not a code finding. No finding is filed for it and no code change
follows from it.** It is recorded because it bears on how much weight the two CONFORM verdicts above
can carry.

**(a) Both stories sit in a non-canonical state folder.** The canonical states are
`complete` / `incomplete` / `review` / `archive`. Both of these sit in **`auto-complete/`**:

```
~/code/product-owner/stories/antimatter/auto-complete/annihilate/001-replace-annihilate-from-with-annihilate.md
~/code/product-owner/stories/antimatter/auto-complete/annihilate/002-cross-check-registered-decimals-against-token.md
```

**(b) Both carry a machine-approval stamp.** story-001:403–405 and story-002:376–378 each open an
`## Auto-Completed` block reading:

> **Approved by**: story-batch workflow (**machine approval — not human-reviewed**)

**(c) Both record, in their own text, that ZERO independent validation ran — in either phase.**

- **story-001**, Review Results §Validation Results (:323–350), labels **every one of the four steps**
  "(inline — `<agent>` unavailable)": base-commit validation (:324), file-change review (:327), claim
  validation (:331), purpose alignment (:344). Its own Issues Found section states it plainly at
  :355–360:

  > *"**No independent validation ran, in either phase.** … So story 001 has been **self-verified twice
  > and independently verified zero times.** … If independence matters for a security-motivated change
  > like this one, re-run `/review-work antimatter:001` from a session that can dispatch subagents
  > before any completion transition."*

  The auto-complete block carries that forward as a **[medium]** non-blocking finding (:409) and adds
  that the completion orchestration itself was also uninstrumented (:415–421).

- **story-002** records the same at :382:

  > *"[medium] Review ran without independent validator subagents (no agent-dispatch tool available), so
  > base-commit, file-change, claim and purpose validation were the reviewing session's own inline
  > analysis rather than four independent verdicts."*

  Its orchestration note (:389–399) confirms story-manager, repo-manager, base-commit-validator and
  workflow-validator were likewise never dispatched.

**Why this is worth surfacing.** These are the fixes for **this project's only open High**
(`033432b0e650af67`, run-01 H-01, `fix-pending`) and for an **open Medium** (`a1c81428a47ad295`,
run-01 M-01). Both were reviewed by the session that wrote them, twice, with the non-independence
labelled rather than hidden — and then **machine-approved** to a completed state and moved to
`auto-complete/` without a human in the loop.

**In this audit's favour, and stated so the observation is not overweighted:** the inline checks were
specific and falsifiable, and **this run independently re-derived the load-bearing ones**. The zero-hit
`annihilateFrom` grep, the zero-hit `_spendAllowance` grep, the four retained trip-wire entries, the
mandated `staticcall` form and its mandated insertion position were each verified here against
`c91bc1a` source, not taken from the story record. Both stories conform. The process gap is real, but
it did **not** produce a substantive defect in either story's work.

**The one thing the gap did let through is F-04** — a third, untagged, unreviewed commit that landed on
the same worktree after both stories closed, changing logic story-001 had placed out of bounds, with
nothing in the story tree recording it.

---

## 6. Carryover — open faithfulness findings from antimatter-01

Ledger entries `3aac91383dcb6060` (F-01), `78612be9264d2b49` (F-02) and `9d06644ddad24e5a` (F-03) are
all **`open` and untriaged**, and all were re-observed as **still live at `c91bc1a`**. Per the repo's
carryover convention they are reproduced **in full** below rather than linked, so this run is readable
without following a pointer. All three have `reportPath: null` in the ledger — run-01 issued no
per-finding submission file for faithfulness findings — so the bodies are sourced from each entry's
`findingPath` and from run-01's own `spec-conformance.md` §2, which is the original report text.

**Labels are the originals.** F-01, F-02 and F-03 keep their run-01 labels; the new finding this run is
F-04. Line numbers in the copied bodies were accurate at `0bb82d8` and are annotated where the code has
since moved.

### ⚠ WATCH-02-02 — F-01 MUST NOT BE MARKED FIXED ON THE STRENGTH OF THE `:257` CHECK

> **This is the highest-probability false closure in the entire `0bb82d8..c91bc1a` delta, and it is
> stated here rather than buried in the ledger because that is where it will be read.**
>
> `c91bc1a` implements **F-01's own recommended mitigation TEXT very nearly verbatim** — run-01 F-01
> recommended *"assert `mintedForStable` against `minter.calculateMintAmount(stable, stableAmount)`"*,
> and `:234`/`:257` do exactly that. **It leaves F-01's actual DEFECT intact.**
>
> F-01's defect is that a caller has **no way to bound the outcome of an already-irreversible burn**.
> At `c91bc1a`:
>
> - There is still **no caller-supplied minimum-output parameter** anywhere in `annihilate`
>   (`src/Antimatter.sol:221` — the signature is unchanged: `stable`, `recipient`, `amount`).
> - **Both sides of the `:257` equality re-quote at the rate live at execution.** `expectedForStable`
>   is computed at `:234`, inside the same transaction, from the same `exchangeRate` that
>   `minter.mint` will use at `:251`. The check binds the minter to its own quote; it binds **nothing
>   the caller saw at signing time**. If the owner moves `exchangeRate` between submission and
>   inclusion, the quote moves with it and the equality still passes.
>
> **Any future run proposing `3aac91383dcb6060` fixed on the strength of the `:234`/`:257`
> exact-equality pair must be REJECTED.** Closure requires evidence of a **caller-supplied minimum
> output** — e.g. a `uint256 minPhUSDOut` parameter checked as
> `amount + mintedForStable >= minPhUSDOut` before `:260`. The counter-evidence attestation required
> before closure is filed this run as **Q-05** (`1b960956475d434a`, `falseClosureBlock`).
>
> **Related, and equally not-closed:** ledger **L-01** (`ad4b779566291190`) is **not** closed by the
> same check. Its root cause — the unattributed balance delta at `:256` — survives the delta
> byte-for-byte; only its **impact** inverted, from a silent mis-forward into a `PhUSDAmountMismatch`
> griefing brick. That entry is **re-worded, not closed**; closing it would lose the surviving root
> cause.
>
> **Fingerprint drift warning.** `3aac91383dcb6060` is fingerprinted on the **old** function name
> (`fingerprintBasis: src/Antimatter.sol:annihilateFrom:MissingMinimumOutputGuardOnIrreversibleBurn`).
> `annihilate` renamed that function, so **re-deriving this fingerprint from `c91bc1a` source yields a
> different hash and silently re-files the finding as new**. Carry it verbatim from the ledger. Twelve
> entries are drift-affected in total; F-01 is one of the two the deduplicator's list originally
> missed.

---

### 6.1 [C] F-01 — The spec's measured-balance discipline is applied in full to the stablecoin leg but only nominally to the phUSD leg

> **Carryover — copied in full from `antimatter-01`.** This issue originally appeared in **audit 01**
> as **F-01**, was **not triaged**, and is **still valid** as of audit 02.
> Triage it with `/ledger antimatter`.

- **Carryover of:** F-01 (run antimatter-01) · **issueId:** `am1f1`
- **Severity:** Low (unchanged since first report)
- **Status:** `open` (untriaged) — **and see WATCH-02-02 above before proposing any closure**
- **Fingerprint:** `3aac91383dcb6060` (carried verbatim; **drift-affected, never re-derive**)
- **Fingerprint basis:** `src/Antimatter.sol:annihilateFrom:MissingMinimumOutputGuardOnIrreversibleBurn`
- **First seen:** antimatter-01 · **Still present as of:** antimatter-02 (`c91bc1a`)
- **Original location:** `src/Antimatter.sol#L230-L237` (`annihilateFrom`), guard at L233
- **Location at HEAD:** `src/Antimatter.sol#L253-L257` (`annihilate`), guard now at **L257**
- **Source record:** `reports/antimatter/01/findings/faithfulness/F-01-the-spec-s-measured-balance-discipline-is-applied-in-full.json`
- **Original report:** `reports/antimatter/01/submissions/spec-conformance.md` §2 (`reportPath` is null — no standalone file was issued)

*The text below is a verbatim copy of the original report. Line numbers and links were accurate at the
originating commit `0bb82d8`; re-verify against current HEAD before acting.*

---

**Spec text violated** — `lib/antimatter/CLAUDE.md` § *"Annihilation settles whole or not at all"*:

> `annihilateFrom` must never come to rest in a partial state: antimatter burned without the
> stablecoin deposited, phUSD minted for one half only, or the stablecoin left sitting on this
> contract. **Burn before the external calls, verify by measured balances rather than assumption,
> and let anything unexpected revert.**

**Actual behaviour.** The stablecoin leg honours the discipline in full — L230 measures and fails
closed on a strict inequality:

```solidity
230:        if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();
231:
232:        uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;
233:        if (mintedForStable == 0) revert PhUSDNotReceived();
```

The phUSD leg does not. L233 rejects **only the exact value zero**. Measurement is used for
residue detection (L219 / L230, strict `!=`) but never for *expectation* checking — and it is the
phUSD leg where the burn (L215) has already become irreversible. Any non-zero quantity is accepted
on trust, including one wildly below what the stable deposit should have produced.
*"Anything unexpected"* does not revert; only *"nothing at all"* does.

`annihilateFrom` exposes **no minimum-output / expected-phUSD / slippage parameter** at all, so a
caller has no way to bound the outcome of an already-irreversible burn. If `exchangeRate` is low, or
is changed by the owner between transaction submission and execution, the holder's antimatter is
burned at full quantity while the stable half returns almost no phUSD — and the transaction
**succeeds**.

**Why Low, and why it is here rather than in QA.** Honest Low on the security limb: no attacker
gain, the harm is caller-borne and bounded by the rate divergence, and it does not breach the
whole-or-nothing invariant as enumerated (no rest state has antimatter burned with stable
undeposited, and nothing is stranded). Rate-setting itself is Law-3 owner territory. It is routed
here rather than into the QA bundle because it is a **partial implementation of a written
CLAUDE.md discipline**, not an interaction defect — Law-2 deviations are never buried in QA noise.

**Recommendation.** Add a `minOut` / expected-phUSD parameter to `annihilateFrom`, or assert
`mintedForStable` against `minter.calculateMintAmount(stable, stableAmount)`. Mitigation is shared
with L-01 (see `qa-report.md`) and with **M-06**.

---

**Run-02 re-observation (not part of the original body).** The recommendation's *second* limb —
assert against `calculateMintAmount` — is now implemented at `:234`/`:257`. The *first* limb, the
`minOut` parameter, is **not**, and it is the limb that carries the defect. **STILL OPEN, STILL LIVE.**
No closure is proposed. See WATCH-02-02.

---

### 6.2 [C] F-02 — The invariant trip-wire CLAUDE.md nominates for "never expose a burn" is a four-name denylist, not an invariant check

> **Carryover — copied in full from `antimatter-01`.** This issue originally appeared in **audit 01**
> as **F-02**, was **not triaged**, and is **still valid** as of audit 02.
> Triage it with `/ledger antimatter`.

- **Carryover of:** F-02 (run antimatter-01) · **issueId:** `am1f2`
- **Severity:** Low (unchanged since first report)
- **Status:** `open` (untriaged)
- **Fingerprint:** `78612be9264d2b49` (carried verbatim; **not** drift-affected)
- **Fingerprint basis:** `test/Annihilation.t.sol:test_noPublicBurnEntryPoints:DenylistTestSubstitutedForInvariant`
- **First seen:** antimatter-01 · **Still present as of:** antimatter-02 (`c91bc1a`)
- **Original location:** `test/Annihilation.t.sol#L341-L355`, probe list at L344–L345
- **Location at HEAD:** `test/Annihilation.t.sol#L410-L426`, probe list now at **L416–L417** (content unchanged)
- **Source record:** `reports/antimatter/01/findings/faithfulness/F-02-the-invariant-trip-wire-claude-md-nominates-for-never.json`
- **Original report:** `reports/antimatter/01/submissions/spec-conformance.md` §2 (`reportPath` is null)

**⚠ NEW THIS RUN — F-02 IS NOW *CODIFIED* BY story-001.** The denylist is no longer merely
inherited: story-001 line 175 **instructs** that it be preserved as-is —

> *"Keep all four entries: the 2-arg `annihilate(address,uint256)` entry still usefully forbids a
> shortened burn shortcut. Add a brief comment so a future reader does not mistake it for forbidding
> the new 3-arg entry point."*

and story-001's Concerns (:225–228) reason the decision out as deliberate, citing the CLAUDE.md
instruction not to weaken the trip-wire. The implementation complied exactly (§2 clause 12), so the
story is **CONFORMANT** — but the effect is that the denylist's shape now has **written authority**
behind it, where before it was only an artefact. **A future author reading story-001 will conclude the
four-name array is the intended design.** F-02's remediation therefore now requires amending
story-001's instruction as well as the test.

*The text below is a verbatim copy of the original report. Line numbers and links were accurate at the
originating commit `0bb82d8`; re-verify against current HEAD before acting.*

---

**Spec text violated** — `lib/antimatter/CLAUDE.md` § *"Antimatter must never expose a burn"*:

> No `burn`, no `burnFrom`, no `ERC20Burnable`, no owner-callable "clawback", no `transfer` to
> `address(0)` path, and **no new entry point that reaches `_burn` except `annihilateFrom`.**
>
> `test_noPublicBurnEntryPoints` in `test/Annihilation.t.sol` **is a trip-wire for this rule.** It
> is not the rule — do not weaken or delete it to accommodate a new burn path.

**Actual behaviour.** The nominated trip-wire probes a hardcoded four-name guess list:

```solidity
344:        string[4] memory signatures =
345:            ["burn(uint256)", "burn(address,uint256)", "burnFrom(address,uint256)", "annihilate(address,uint256)"];
```

Three ways this fails to enforce what the rule states:

1. **It is a denylist, not a property.** The rule prohibits **ANY** new entry point reaching
   `_burn`. A burn named `redeem`, `destroy`, or `clawback` — or an `annihilate` **overload of a
   different arity** — is simply not in the list, and the test passes green. The very shape of
   defect the rule exists to catch is the shape the test cannot see.
2. **Two of the rule's named cases are never probed at all.** The rule also names *"no owner-callable
   clawback"* and *"no `transfer` to `address(0)` path"*. Neither appears in the probe list.
   Transfer-to-zero happens to be closed — but by OpenZeppelin v5.6.1's `ERC20._update`
   (`ERC20InvalidReceiver`), i.e. by the base class, not by anything this repo asserts. If the base
   class changed, nothing here would notice.
3. **The one-argument probe is mis-encoded.** All four signatures are dispatched through the same
   two-argument call (`abi.encodeWithSignature(signatures[i], user, 1 ether)`), so the
   `burn(uint256)` probe passes trailing calldata the decoder ignores: it would decode
   `amount = uint256(uint160(user)) = 2827` wei, not `1 ether`. It would still trip a naive
   `burn(uint256)`, but only because the address literal happens to be a small non-zero number. The
   probe is not testing what it reads as testing.

**The trip-wire is not load-bearing.** This is already demonstrated, not hypothetical: H-01's
invariant violation — a burn effected from the grantor's ledger via an ERC20 allowance — coexists
with this test passing green.

**Substance vs. guard.** The invariant itself **HOLDS**: `src/Antimatter.sol` contains exactly one
`_burn` (inside the annihilation function) and one `_mint` (`onlyApprovedMinters`); no
`ERC20Burnable` inheritance, no `burn`/`burnFrom`/clawback function. The defect is in the **guard**,
not the current code — but CLAUDE.md designates this test as the enforcement mechanism for a
load-bearing invariant and instructs future authors not to weaken it, so the false assurance is the
whole harm.

**Recommendation.** Replace the name-denylist with a real property assertion — `totalSupply` is
non-decreasing across every non-annihilation external call, exercised with fuzzed calldata — or
a source assertion (exactly one `_burn` occurrence, inside the annihilation function). Add explicit
probes for the clawback and transfer-to-zero cases the rule names, and fix the one-argument encoding.
*(Note: the audit's Tier-3 harness under `workspace/antimatter/test/audit/invariant/` is a usable
template, but it is **audit-authored** and must never be cited as project coverage.)*

---

**Run-02 re-observation (not part of the original body).** The probe array is byte-identical at
`c91bc1a`, relocated to `test/Annihilation.t.sol:416–417`; the added comment at `:413–415` clarifies
scope but changes no probe. The substantive invariant still holds — `src/Antimatter.sol` still contains
exactly one `_burn`, at `:239` inside `annihilate`. **STILL OPEN, STILL LIVE**, and now additionally
codified by story-001:175 as noted above.

---

### 6.3 [C] F-03 — The contract-header NatSpec justifies the unbacked mint with a redemption symmetry that does not exist, and states a 2x output the code does not guarantee

> **Carryover — copied in full from `antimatter-01`.** This issue originally appeared in **audit 01**
> as **F-03**, was **not triaged**, and is **still valid** as of audit 02.
> Triage it with `/ledger antimatter`.

- **Carryover of:** F-03 (run antimatter-01) · **issueId:** `am1f3`
- **Severity:** Low (unchanged since first report)
- **Status:** `open` (untriaged)
- **Fingerprint:** `9d06644ddad24e5a` (carried verbatim; **not** drift-affected)
- **Fingerprint basis:** `src/Antimatter.sol:contract-header NatSpec:NatSpecOverstatesGuarantee`
- **First seen:** antimatter-01 · **Still present as of:** antimatter-02 (`c91bc1a`)
- **Original location:** `src/Antimatter.sol#L13-L20`, claim at L16–L18
- **Location at HEAD:** `src/Antimatter.sol#L14-L21`, claim at **L17–L19** — **text unchanged by the delta**
- **Source record:** `reports/antimatter/01/findings/faithfulness/F-03-the-contract-header-natspec-justifies-the-unbacked-mint.json`
- **Original report:** `reports/antimatter/01/submissions/spec-conformance.md` §2 (`reportPath` is null)

*The text below is a verbatim copy of the original report. Line numbers and links were accurate at the
originating commit `0bb82d8`; re-verify against current HEAD before acting.*

---

**Spec text (the claim itself):**

```solidity
16: /// @dev Antimatter is handed out as a staking reward across the protocol. Held on its own it is
17: ///      inert; brought together with an equal quantity of a supported stablecoin it annihilates,
18: ///      and the pair is emitted as phUSD — twice the quantity, since both halves are redeemed.
```

**Actual behaviour — both clauses are false.**

**(a) "both halves are redeemed" — phUSD has NO redemption path anywhere in the protocol.**
Verified across every repo: nothing anywhere redeems phUSD for an underlying asset. The stable leg's
phUSD is minted by `PhusdStableMinter.mint` against a real stablecoin deposit forwarded to a yield
strategy. The antimatter leg's phUSD is minted at **`src/Antimatter.sol:236`**:

```solidity
235:        // The antimatter half, minted straight to the recipient.
236:        _phUSD.mint(recipient, amount);
```

— with **no asset entering the protocol for it**. Nothing is "redeemed" on that half; antimatter is
itself an unbacked staking reward minted freely at L179–L180. The word *"redeemed"* imports a
backing that does not exist, and it is doing load-bearing rhetorical work: it is the entire stated
justification for the unbacked mint.

**(b) "twice the quantity" — contradicted by the repo's own passing test.** The total is
`amount + mintedForStable` (L239), where `mintedForStable` honours the stable minter's
`exchangeRate`. The project's own green test `test_annihilateHonoursMinterExchangeRate`
(`test/Annihilation.t.sol:108-117`) asserts **195**, not 200:

```solidity
108:    function test_annihilateHonoursMinterExchangeRate() public {
109:        minter.updateExchangeRate(address(usdc), 95e16); // 0.95 phUSD per USDC
...
117:        assertEq(phUSD.balanceOf(user), 195 ether, "100 AM + 95 from the stable");
```

The header's headline arithmetic is refuted by the repository's own test suite. The real figure is
`amount * (1 + exchangeRate/1e18)` (see M-04).

**Kept deliberately separate from M-02 — do not collapse.** Different root cause (a documentation
defect), different remediation (correct the comment, not bound the emission), different affected
reader (integrators), and decisively: collapsing it would let the doc defect vanish the moment the
economic finding is triaged as accepted-by-design. That separation is the point. Filing F-03 does
**not** dampen the economic impact of the unbacked mint, which is M-02's to size.

**Recommendation.** Correct L16–L18: only the stablecoin half is a redemption; the antimatter half
is an uncollateralised mint. State the `exchangeRate` dependence of the total rather than a flat 2x.

---

**Run-02 re-observation (not part of the original body).** The header text is **untouched** by all
three delta commits; the claim now sits at `src/Antimatter.sol:17-19`, and the unbacked mint it
justifies is now at `:260`. `test_annihilateHonoursMinterExchangeRate` still asserts 195 ether, at
`test/Annihilation.t.sol:108`. **STILL OPEN, STILL LIVE**, verbatim.

**One new consideration for run-02.** Story-001's Background (:43–46) **repeats the false claim
verbatim** — *"the pair is emitted as phUSD — twice the quantity, since both halves are redeemed"* — so
the inaccuracy has now propagated from the contract header into the product-owner story tree. Correcting
the NatSpec should be accompanied by correcting that story line, or the next story written from this
background will inherit it again.

---

## 7. Standing rules applied in this report

**In-source NatSpec, `CLAUDE.md`, and a story document carry NO suppression authority.** None of them
can retire a finding, downgrade one, or serve as evidence that a behaviour is safe. A document
declaring a behaviour intended establishes only that it is *intended*; whether it is *safe* is decided
against Law 1, which outranks Law 2. This applies with particular force to §5: a story marked
`auto-complete` and stamped "machine approval — not human-reviewed" is a record of what was intended,
not a warrant that it is correct — and story-001:198's ticked box is the demonstration, since it
certifies a preservation that no longer holds (§4.3).

**A falsely-exhaustive document RAISES severity rather than lowering it.** Both carried findings turn
on this: F-02, because CLAUDE.md nominates a test as *the* trip-wire for a load-bearing invariant and
that test cannot detect what its own rule prohibits; and F-03, because the header NatSpec was — at
run-01 — the project's only intent artefact, and it is wrong in both of its clauses. F-03 is
*mitigated* this run only in the sense that stories now exist; it is *aggravated* by the fact that
story-001:43–46 reproduced the false claim.

**Sanitizer note.** No known-issues document exists for this project at `c91bc1a`
(`knownIssuesFile` / `knownIssuesSource` both null, `knownIssues` empty), so known-issue suppression has
no authority over anything in this report. F-04 passed the sanitizer (`PASS`) and the validity checker
(`VALID`): the known-invalid list does not reach it, because every item on that list disqualifies a
class of *vulnerability claim* and F-04 makes no vulnerability claim at all (`assetImpact: NONE`,
`attackPath: []`, `securityEscalation: false`). Nor is it speculation — it is graded against a named
story document and a landed commit.

**Fingerprint discipline.** Twelve of the nineteen pre-existing ledger fingerprints are basis-anchored
on the **old** function name `annihilateFrom` and will **not** re-derive from current source. Carry
them verbatim from `reports/antimatter/ledger.json`; never recompute. The two fingerprints newly
minted this run on the **new** name — F-04 `d34180996ba41ff8` and Q-05 `1b960956475d434a` — are
correctly minted on `annihilate` and are **not** drift.
