# Decision log — /full-audit nft-staking

Run date: 2026-07-30
Project: phoenix-nft-staking
Submodule range this run: 5015f1b → 9611312 (pointer bumped by /update-lib earlier this session, root commit 630821e)
Mode: autonomous — user instruction: "do not stop to prompt me on anything but record all your fork in the road decisions"

This log records every fork where a judgement call was made instead of asking the user.
Each entry: **decision** / **alternatives** / **basis**.

---

## D-000 — Autonomous operation, log instead of prompt
- **Decision:** run the whole pipeline without pausing; every ambiguity resolved by me and recorded here.
- **Alternatives:** stop at each fork with AskUserQuestion.
- **Basis:** explicit user instruction this turn. Standing preference already recorded in memory (`decision-log-at-forks`).
- **Bias applied at forks:** Law 1 (no exploits) — when in doubt, keep the finding in a *visible* channel rather than suppress; recall beats report-tidiness. Never file an owner-intends-to-fix item as `acknowledged`.

## D-001 — Argument resolution `nft-staking` → `phoenix-nft-staking`
- **Decision:** resolved to `phoenix-nft-staking`.
- **Alternatives:** `yield-claim-nft` (contains "nft" but not the substring "nft-staking"); prompt for disambiguation.
- **Basis:** unique substring match against registry keys / `lib/` dirnames; same resolution `/update-lib` used earlier this session on the same argument.

## D-002 — Run mode: REGRESSION (no `--full`)
- **Decision:** regression scan against the ledger, per command spec, since a ledger with `lastAuditedCommit` exists.
- **Alternatives:** force a cold scan.
- **Basis:** `--full` not passed. Mitigation for the recall risk: new first-party contracts are scanned in full regardless — scope is a denylist, not a gate. Recorded here because a regression scan is narrower than cold, and this is a fork.

## D-003 — CORRECTION: `BatchNFTMinterMultiToken.sol` is NOT a new contract
- **Decision:** treat it as a **modified** in-scope contract, not a new one; do not claim a new contract entered scope this run.
- **What I got wrong:** in my `/update-lib` report I called it new. `git ls-tree -r src/` at both 5015f1b and 9611312 is byte-identical (14 files); the file is `M`, not `A`. It has been in the cached scope array since before run-25.
- **Consequence:** the `newInScope` auto-pull-in path is not exercised this run. Live-glob vs cached-`scope` diff is EMPTY — 13 in-scope contracts, snapshot exact. Recorded because an incorrect "new contract" claim would have mis-framed the run.

## D-004 — Workspace sync method (shallow clone, no remotes, lacks target object)
- **Decision:** sync `workspace/phoenix-nft-staking` 5015f1b→9611312 by adding the local `lib/phoenix-nft-staking` as a temporary fetch source, fetching, then checking out 9611312. Preserve all 38 untracked audit-authored paths; delete nothing.
- **Alternatives:** (a) re-clone the workspace fresh — **rejected**, destroys 16 PoC/invariant/symbolic test files + medusa corpora; (b) fetch from GitHub — unnecessary, objects are already local; (c) leave the workspace stale — **rejected**, PoC replay against 5015f1b proves nothing about HEAD.
- **Basis:** the range adds/deletes no files, so a tracked-only checkout provably cannot collide with the untracked artifacts. `git status` was run first; nothing uncommitted discarded. Memory `never-file-audit-authored-test-files`: those 16 files are audit-authored and must never be filed as project tests.

## D-005 — story-032 landed at HEAD while its story sits in `review`
- **Decision:** scan and grade it as fully in scope; additionally surface the landed-yet-unclosed state as a Law-2 observation in spec-conformance, not as a blocker or a reason to defer.
- **Alternatives:** wait for the story to close; treat `review` as out of scope.
- **Basis:** CLAUDE.md — "the state folder is metadata, not a filter"; a landed feature whose story is not closed out is itself worth flagging.

## D-006 — story-032 removes a guard the registry documents as intentionally absent
- **Decision:** do NOT file the removed admin-time payment-token whitelist gate as a missing guard or weakening. Instead spend the budget re-verifying that the two load-bearing ordering constraints — snapshot-before-pull and refund-before-payout — still hold without it.
- **Alternatives:** file the removed gate as a regression.
- **Basis:** Law 3 (deliberate, documented owner decision — registry `designDecisions` states the absence is intentional) + Law 1 (the *consequences* of removal are exactly where an unknowing footgun hides, so ordering invariants get verified, not assumed). Memory `payment-token-as-nudge-token-decision`: the paymentToken/nudgeToken collision is owner-PERMITTED and its arbitrage ACCEPTED — must not be re-filed.

## D-007 — Workspace clone is now FULL, not shallow (side effect, accepted)
- **Decision:** accept `git fetch --unshallow` having converted `workspace/phoenix-nft-staking` from a shallow to a full clone; do not try to re-shallow it.
- **Basis:** documented consequence of the approved fetch method; harmless and mildly beneficial (future `/recheck` syncs get full history, no shallow-fetch friction). Disk cost only. Noted so a future run isn't surprised the workspace shape changed.

## D-008 — SAST tool-trap mitigations mandated up front
- **Decision:** instructed static-analyzer to (a) NOT use `--filter-paths "lib/"` and to treat any zero-finding `src/` result as a suspected filter bug requiring an unfiltered re-run; (b) point 4naly3er `basePath` at the submodule root, arg 3 being a scope list not a remappings file; (c) treat a clean Semgrep as evidence of nothing.
- **Alternatives:** run the tools with defaults and take the output at face value.
- **Basis:** memories `slither-lib-filter-false-clean` and `4naly3er-remappings-gap-fix` — both traps have previously produced FALSE CLEAN runs in this exact repo. A false clean is a Law-1 failure, so the mitigation is mandatory, not optional.
- **Also:** tools run sequentially with worker flags capped at 2 per memory `wsl2-limit-parallelism` (heavy parallel load has crashed this box).

## D-009 — 4naly3er deferred to the QA bundle rather than re-run in Tier 1
- **Decision:** accept that Tier-1 SAST did not invoke 4naly3er; run it at step 6 (qa-bundler), where the command spec requires its automated QA/gas markdown to be attached anyway.
- **Alternatives:** re-run Tier 1 to add it now.
- **Basis:** Slither 0.11.3 + Aderyn 0.6.8 cover 4naly3er's detector set for security purposes, and its unique value here is the gas/QA appendix that belongs in the QA bundle. The agent recorded it as an explicit coverage gap rather than a silent skip, which satisfies the no-silent-drop rule. Recorded as a fork because skipping a tool is a coverage decision, not a neutral one.

## D-010 — Slither `timestamp` class (67 instances) forwarded, not culled
- **Decision:** keep the whole `timestamp` class in the funnel even though 2 of the flagged sites (`NudgeStreamer.sol:241`, `:270`) are provably Slither mis-attribution (`settled > 0`, `accrued > buffer` are only transitively timestamp-derived).
- **Alternatives:** cull as tool noise at Tier 1.
- **Basis:** the surrounding math is the load-bearing Linear-Depletion logic that has produced real PoC'd findings in this suite (63.26% drift). Culling happens at triage, not at scan. Cost is some dedup work; benefit is not re-missing a known-real class.

## D-011 — `setNudgeStreamer(address(0))` zero-check NOT filed as a bug
- **Decision:** suppress the `missing-zero-check` on `NudgeStreamer.sol:297` as a genuine false positive — passing `address(0)` is a *deliberate disable path*, branched on at `batchMint:530`. "Fixing" it would break intended behaviour.
- **Distinction preserved:** the NON-obvious variant (a silent brick from repointing the streamer) is already ledgered as run-21 M-02 and is NOT collapsed into this suppression.
- **Basis:** Law 3 obvious-vs-surprising test. Recorded because suppressing a tool finding is exactly the kind of call that must be visible, not buried.

## D-012 — Third counterparty in my profiling brief did not exist; brief corrected mid-flight
- **Decision:** accept the profiler's scope correction. No `NFTStaker*` variant is coupled to `BatchNFTMinterMultiToken` (zero grep hits for `nudge`/`NudgeStreamer`/`BatchNFTMinterMultiToken` across all 7 staker variants; the only `BatchNFTMinter` mentions are NatSpec citing it as a precedent for `rescueERC20`). Real counterparties are `NudgeStreamer` + three `yield-claim-nft` V2 interfaces.
- **My error:** I asked for "whichever depletion variant the multi-token minter actually nudges", presupposing a coupling that does not exist.
- **Cross-repo safety check passed:** nested `yield-claim-nft` pins are byte-identical to top-level `lib/yield-claim-nft@d4cc563`, so memory `nested-submodule-pin-stale-trap` does not bite this run.

## D-013 — S-01 and the profiler's LOCAL-NS-01 are ONE finding, not two
- **Decision:** merge at dedup. Static analysis found the *amplifier* (unbounded `pullPendingStream` loop, `BatchNFTMinterMultiToken:532-534`, no `try/catch`); the profiler found a *live cause* (`Σ buffer_i <= balanceOf(this)` is claimed "by construction" but is only a one-shot one-directional measurement, so post-credit erosion over-states the buffer → first pair drains shared balance → sibling `_settle` reverts → `batchMint` bricked for everyone).
- **Alternatives:** file separately as a DoS-shape and an accounting-shape.
- **Basis:** same root cause class, same failure, one fix locus. Filing twice would dilute the report. BUT — the amplifier is independently reachable from *other* revert sources, so the merged finding must state both legs; the fix cannot be "only fix the buffer math".
- **Must NOT be collapsed with:** ledger `bfdb50105e` (wont-fix — different site, `_payRewards`) or `6f46ec80f1` (open — different overclaim). Both disclosed as adjacent, per memory `disclose-when-re-filing-an-owner-wont-fix`.

## D-014 — Falsely-exhaustive NatSpec treated as severity-RAISING, not as documentation nitpick
- **Decision:** the `NudgeStreamer.sol:56-57` claim that the buffer-sum invariant holds "**by construction** rather than by convention" (and `:258`'s "established at ONE site") is folded into the finding as an aggravating factor, not filed as a QA doc-typo.
- **Basis:** memory `in-source-natspec-carries-no-suppression-authority` — falsely-exhaustive docs RAISE severity, because a maintainer reading them will not add the guard the docs claim already exists. Same reasoning applied to the `:659-665` NatSpec that mis-states *why* refund-before-payout matters (its real effect is that the second transfer absorbs erosion, so refund-first charges degradation to the pot, never the caller — an editor "restoring symmetry" would silently move erosion onto callers).

## D-015 — Four unverifiable items parked in a VISIBLE channel, not dropped
- **Decision:** carry all four into manual-review / spec-conformance rather than resolving them by assumption: (1) whether `NFTMinterV2._executeMint` charges exactly `configs().price`; (2) `mint()`'s ignored `bool` return (a non-reverting `false` debits budget and mints nothing — S-03); (3) whether `yield-claim-nft`'s `NudgeRatchet.dispatch` keeps a sent-amount-derived counter that story-031 desynchronises, or carries a stale vendored `INudgeStreamer` (story-031 changed `NudgeCollected.amount`'s meaning under a **byte-identical ABI** — no compile-time or on-chain signal); (4) live config (whitelist contents, `nudgeSize`, streamer registrations) which must be resolved from chain, not deploy records.
- **Basis:** Law 1 — "if a finding must be set aside, park it in a *visible* channel with the reason, never in a log nobody reads." Memory `phstaging-mainnet-addresses-stale-trap` covers (4): deploy records have previously shown 0x0 for live funded instances.
- **Item (3) is the one with teeth** — a silent cross-repo semantic change. Escalating it to the cross-repo check rather than leaving it as a note.

## D-016 — `BatchNFTMinter`'s runtime nudge/payment gate must NOT be reported as dead code
- **Decision:** protect `BatchNFTMinter.sol:261-263` (`BatchMint__NudgeTokenMatchesPaymentToken`) from being triaged as redundant now that the sibling's admin-time check is gone. It is a *runtime* gate on the frozen twin, load-bearing because the twin's refund is an absolute `balanceOf` sweep (`:305`). The twin's payout-before-refund order is the OPPOSITE of the sibling's; both are safe given their own refund source, and the constraint is not transferable between them.
- **Basis:** conflating an admin-time check (deleted, intentionally, story-032) with a runtime check (intact, still needed) would produce a recommendation that breaks the frozen V1. Pre-empting that at triage.

## D-017 — Leg A upgraded: the flush loop ignores `qualifies`, so `nudgeSize == 0` does NOT disable it
- **Decision:** adopt the pattern-matcher's refinement as the primary framing of Leg A. `qualifies` is computed at `BatchNFTMinterMultiToken.sol:510-514`, and *every other* reward-token touch is gated by it (`_snapshotRewards:801` uses `qualifies ? balanceOf : 0`; `_payRewards:831` skips zeros) — but the flush loop at `:528-536` **does not read it**. So story-028's wiring widened the blast radius from qualifying batches to EVERY batch, and the documented disable lever (`nudgeSize == 0`) does not disable the flush.
- **Why this matters more than the raw DoS signature:** it converts "owner mis-registers a token" into "the operator's own documented off-switch does not work", which is squarely a non-obvious footgun (Law 3 → in scope) rather than a hypothetical.
- **Reachability honestly bounded:** narrower than the raw signature — `pullPendingStream` no-ops on unregistered streams (`:222`) and only transfers when `settled > 0`, so an owner-registered stream is a precondition. Recording this so severity is not inflated.
- **Sibling precedent to disclose, not collapse:** ledger `966e717669` (same un-`try/catch`'d-external-call class in `NFTStakerDepletion._syncBudget`).

## D-018 — Geometric-decay under-release: RE-WEIGH an existing Low, do NOT re-file
- **Decision:** do not mint a new finding for `collectNudge`'s permissionless recompute at `:206` re-spreading the whole remaining buffer over a fresh full `duration` (making decay geometric, not linear — ~36.8% of a burst still buffered at the nominal window end, the same decelerating shape as the PoC'd 63.26% drift in `b58b172e2a`). It is already ledgered as `aaebb4b9b0` (L-02, open). Instead: propose a **re-weigh** of that entry and attach the new framing.
- **The new framing (this is the substantive part):** the existing entry frames the mechanism purely as *griefing*. It needs no griefer. Legitimate cadenced seeding — the story-073 phUSD/Kendu top-up streams — resets the window on **every** top-up, so the pot under-releases against its documented behaviour under entirely normal operation. That is a **Law-2** angle the entry does not capture, and Law 2 outranks the report-tidiness argument for leaving a Low alone.
- **Alternatives:** (a) file fresh — rejected, dedup would (correctly) flag it and the ledger would carry two entries for one mechanism; (b) leave `aaebb4b9b0` untouched — rejected, its current framing understates the trigger to the point of being misleading.
- **Not a value leak:** per memory `externally-derived-yield-opportunity-cost-not-loss`, under-release of a yield-funded pot is misallocation/marketing spend, never economic loss. Severity stays capped accordingly.

## D-019 — MR-26-01 sub-wei truncation kept SEPARATE from `aaebb4b9b0`
- **Decision:** keep the sub-wei truncation forfeiture at `NudgeStreamer.sol:240` as its own manual-review item; do not collapse it into the window-reset finding.
- **Basis:** different mechanisms (truncation loss vs window reset). Collapsing would let a fix for one read as a fix for both. Consistent with prior runs' refusal to collapse distinct guards (memory: `run-21` M-03 sole-surviving-guard, `run-09` V3-Q-02 vs pe9m2).

## D-020 — PATTERN-002 (`setNudgeStreamer` no structural probe) retained at Low despite self-refutation
- **Decision:** keep it, narrowed. The agent partially refuted its own finding: for an EOA, solc 0.8.20 retains the `extcodesize` check on void-returning calls, so it reverts loudly. The surviving residual is a **contract with a permissive fallback** → the flush becomes a permanent silent no-op, and the event emits *before* assignment (`:298-299`) so the logs look clean.
- **Alternatives:** kill it as refuted.
- **Basis:** the residual is genuine and is a silent-brick class with real history here (run-21 M-02, stable-yield-accumulator `setRewardToken`). Asymmetry is telling: `NudgeStreamer.registerStream:127` deliberately probes its counterparty via `isNudgeToken`, while this setter probes nothing. Filed at Low, with the self-refutation stated in the finding so no reader over-reads it.

## D-021 — WALK-BACK: my story-032 "over-reach" hypothesis is REFUTED
- **Decision:** withdraw it. I hypothesised that deleting four admin-time reverts when the story asked for one was a Law-2 over-reach. It is not. Story-032 has a dedicated section ("The load-bearing side effect") naming all three config preconditions and their three pinning tests, and Concerns §1 states verbatim: *"this is a genuine behavioural change beyond the one-line ask and is called out here for that reason"* — with the preserve-it alternative explicitly offered and rejected. **Authorised, disclosed, faithful.**
- **Why I'm logging a refutation:** the hypothesis was mine, stated confidently in the scan brief, and a less careful pipeline would have confirmed it. Recording it so the negative result is durable and nobody re-raises it next run.
- **What survived instead:** story-032 twice clears `NudgeStreamer` as "unaffected" on *mechanism* grounds. True of `_nudgeTokenIndex`, false of the reachable state — `isNudgeToken() == true` used to transitively witness a configured payment path, and `registerStream` gates on nothing else. That witness is gone → F-04, Low, a genuine Law-3 footgun the story's own dependency analysis papers over.

## D-022 — ATTRIBUTION CORRECTIONS: two over-claims I mis-assigned to story-030
- **Decision:** accept both corrections; re-file against the correct stories. `git log -S` is the authority, not proximity.
  - **`NudgeStreamer.sol:56-57` / `:258-261` → story-031**, not 030 (`src/NudgeStreamer.sol` appears in ZERO story-030 commits and none of its File Locations; the text did not exist when story-030 ran). This lands *harder* on 031: story-031's own checklist line 168 **instructed the unconditional wording** ("State the real invariant that now holds (`Σ buffer_i <= balanceOf(this)`, established at the credit site)"). The acceptance criterion itself asserted a general invariant from a directional fix, and 031's own review caught it as non-blocking Issue 1 and shipped anyway. → F-02.
  - **`BatchNFTMinterMultiToken.sol:659-665` → story-029**, not 030 (at `5015f1b` it sat at `:634-640`, just *above* Anchor E's quoted `:643-668`; commit `bae1a6e` touches none of it). Still in scope, but on the different basis that it sits inside the same contiguous step-9 comment block Anchor E rewrote, and Anchor E's own new DURABLE RESIDUAL text 20 lines below **contradicts it**. → F-01.
- **Basis:** Law 2 requires grading against the *right* story. A misattributed deviation is both unfair to story-030 and lets the actually-responsible story off the hook.

## D-023 — F-02 severity: a documentation deviation whose ROOT is an acceptance criterion
- **Decision:** treat F-02 as materially more serious than a doc nitpick, because the false guarantee was *mandated by the story's own acceptance criterion* rather than slipping past review — and the review noticed it (non-blocking Issue 1) and shipped anyway.
- **Basis:** memory `in-source-natspec-carries-no-suppression-authority` (falsely-exhaustive docs raise severity), compounded by the process that should have caught it being the process that specified it. Strongest Law-2 finding of the run. Stays a faithfulness finding (no direct exploit) but is cross-referenced from the merged Leg-A/Leg-B finding, because the false guarantee is exactly what would stop a maintainer adding the missing guard.

## D-024 — No UNSAFE-STORY declared for any of the three
- **Decision:** accept the Law-1 override check result: none of stories 030/031/032 has an *intended behaviour* that introduces an exploit. No `securityEscalation` flag on any F finding.
- **Recorded because** this is the check that would escalate a story document itself, and a silent pass is indistinguishable from not having run it. It ran; it passed; this is the record.

## D-025 — F-01 substance: the NatSpec claim is not merely vague, it is false in both halves
- **Decision:** file F-01 on the specific falsity, not on tone. `:664` claims the ordering makes a payout unfundable from an owed refund *"and vice versa"*. Neither half holds: in the ordinary case **both** orderings are solvent (independence comes from *sourcing* — `budget` vs `snapshot` — not from sequence), and in the one erosion case where ordering does bind, refund-first charges the shortfall to `D` then `P`, **succeeding silently** when erosion ≤ `D`. So the `vice versa` half describes what the ordering *causes*, not what it prevents.
- **Basis:** a documentation finding needs a falsifiable claim to be worth filing; this one has two. Note the shipped block asserts construction in paragraph one and admits silent pot absorption in paragraph three — self-contradictory as shipped.

## D-026 — WALK-BACK: Leg B is KILLED; the run's headline candidate collapses to Low
- **Decision:** accept the kill. Exhaustive enumeration (the streamer has ONE state variable and FOUR write sites) shows no plain-ERC20 path by which `balanceOf(streamer)` decreases or `Σ buffer_i` increases without a counterpart: `_settle` moves both by the same `settled`; the credit is `min(measured delta, amount)`; `registerStream` never touches `buffer`; inbound transfers are the safe direction; self-settle is unreachable (`registerStream:127` calls `isNudgeToken` on the streamer, which doesn't implement it).
- **Every surviving mechanism is token-side** (negative rebase, burn-on-hold, admin clawback) = permanently-invalid standalone per C4 known-invalid. **The USDT carve-out does not rescue it:** `destroyBlackFunds` requires Tether to blacklist the streamer first, and a blacklisted streamer already cannot `transfer` — so the blacklist, not the buffer over-statement, is the operative brick.
- **Consequence, stated plainly:** the lead cannot carry High or Medium. I framed this as the run's headline in D-013 and it does not survive contact. Recording the collapse rather than quietly re-labelling it, because a Low that was pitched as a Medium is exactly the kind of drift that erodes report credibility.
- **What remains real** is Leg A only, and on a narrower and better basis — see D-027.

## D-027 — CODE-01 held at Low, with an explicit written REOPEN trigger
- **Decision:** file the unisolated flush loop (`BatchNFTMinterMultiToken.sol:533`) at **Low**, not Medium. Every trigger is owner-obvious, third-party-extraordinary, or C4-invalid, and the owner has two one-transaction escapes. **Reopens at Medium the moment a plainly-reachable trigger is found — the impact side already qualifies.**
- **The genuinely new part** (which my merged-lead framing had missed): `_snapshotRewards:801`'s ternary short-circuits and `_payRewards:831` skips zeros, so a **non-qualifying** batch previously made *zero* nudge-token calls and was **structurally immune**. The ungated flush loop is now that caller's only exposure — for zero benefit. Gating it on `qualifies` is provably behaviour-neutral (`_settle` never recomputes `rewardPerSecond`, so skipping a settle loses nothing).
- **Basis for Low-not-Medium:** honest reachability. Basis for filing at all: the fix is free and behaviour-neutral, and the reverting line (`NudgeStreamer.sol:243`) fails HARD, not soft.

## D-028 — S-03 (discarded `mint()` bool) KILLED, and it closes two profiler unknowns
- **Decision:** kill it outright. `NFTMinterV2._executeMint` (`lib/yield-claim-nft@d4cc563:170-201`) has exactly one `return` — a literal `true`; every failure is a `require` or a SafeERC20 revert; `return false` appears nowhere. The discarded bool at `:650` carries zero information.
- **Bonus:** this resolves D-015 items (1) and (2) — `:183` charges `config.price` and `:188` then ramps, confirming charge-then-ramp, and making the per-iteration `configs()` re-read at `:646` correctly load-bearing. Two of my four parked unknowns are now closed by evidence rather than assumption.
- **Cross-repo hygiene:** read at TOP-LEVEL `lib/yield-claim-nft` HEAD, not a nested pin, per memory `nested-submodule-pin-stale-trap`.

## D-029 — CODE-02 (cross-repo isolation asymmetry) filed here but FIXED elsewhere; not suppressed
- **Decision:** file it in this run even though the fix site is in `yield-claim-nft`, and cross-file rather than suppress. `BalancerPoolerV2` wraps the streamer hop in `try this._psmDonate{} catch` (its NatSpec explicitly swallows "streamer unset, stream not registered"), but `NudgeRatchet.sol:157-160` calls `collectNudge` **bare** — so a revert propagates `collectNudge` → `_dispatch` → `ATokenDispatcherV2.dispatch` → `NFTMinterV2._executeMint:191` → `batchMint:650` and **bricks the mint, not merely the flush**.
- **Why this is the more dangerous of the two:** `NudgeStreamer__NotRegistered` (`:158`) is **plainly reachable with no weird token** if the documented wiring order is reversed, and story-031 *added* a revert (`:199`) to this un-isolated leg. Wider blast radius than CODE-01.
- **Severity flagged for second-opinion review:** filed Low by the scanner, but "bricks the mint via a plainly-reachable config ordering" reads to me like a candidate Medium under the availability limb. I am NOT overriding the scanner unilaterally — routing it to severity-auditor with this dissent recorded. Law 1 favours the higher read if the reachability holds up.
- **Not out of scope:** the root cause is first-party code in a sibling audited repo, not a forked/third-party dep, so the OOS-root-cause exclusion does not apply.

## D-030 — Tier-1 profile CORRECTED on the ERC1155 hook surface
- **Decision:** accept the code-scanner's correction over the profiler. `profiles/BatchNFTMinterMultiToken.md` §1.8 claims no inbound hook surface exists; in fact `recipient` is caller-chosen and OZ `_mint` calls `onERC1155Received`, giving an attacker `count` callback points **inside** the mint loop.
- **Cleared, but for a specific reason that must be preserved:** `batchMint` writes **zero storage** and nothing after `:538` re-derives from `balanceOf`. That is the whole defence. Recorded so a future change that adds a storage write or a post-`:538` balance read is understood to re-open a reentrancy surface that is currently only accidentally safe.

## D-031 — WATCH-NOTE on ledger `2d34673536` (currently `fixed`) — do NOT close the watch
- **Decision:** keep the closure as `fixed` (it holds) but attach a watch-note: story-032 removed the admin barrier that used to blunt its precondition, so the closure now rests **solely** on `budget` never being re-derived from a balance reading. Flag if `budget`'s write sites ever exceed `:604` and `:649`.
- **Basis:** memory `expired-closure-vs-regression` — this suite has already produced closures that went live because their *rationale* expired while the patch stayed intact. This is that shape, caught before it fires. Not a regression, not a reopen; a durable tripwire.

## D-032 — WALK-BACK: `aaebb4b9b0` stays LOW; my escalation-to-Medium hypothesis is refuted
- **Decision:** do NOT escalate. My D-018 reasoning was that "no griefer needed" + "permissionless suppression" would compound into a Medium. They **cancel** instead: precisely *because* no griefer is needed, the permissionless surface adds nothing.
- **The numbers that killed it** (pinned mainnet `duration = 7 days`): routine hourly donor cadence leaves **36.68%** of a burst buffered at the nominal window end; a griefer poking **every block** leaves **36.79%**. The adversary's entire marginal contribution is **0.11 percentage points**. `e^{-t/D}` is a hard upper bound, so suppression is self-limiting (1.83% left at 4×`duration`), not indefinite. Each poke runs `_settle` *first* (`:161`→`:243`), so a poke **pays the pot** before stretching the tail — front-running a victim's `batchMint` makes their pot *larger*. No weapon, no profit, push-only custody.
- **Confirmed correct in D-018:** the no-griefer-needed part. Production donors fire per *mint*, not per ops top-up (`NudgeRatchet.dispatch:156-161` @ `d4cc563`, `BalancerPoolerV2._donate:347`). So the mechanism is normal-operation, as I said — it just isn't severe.
- **Law-2 status:** faithful. Story-028 §Concerns explicitly blesses window-reset-on-deposit ("accepted phlimbo behaviour… deliberate"). The only defect is the headline NatSpec.

## D-033 — ⚠ REMEDIATION TRAP: the griefing framing must be REMOVED, not just supplemented
- **Decision:** actively re-frame `aaebb4b9b0` rather than appending a note. This is the most consequential call of the run.
- **Why:** filed as *griefing*, a reader's natural fix is to **permission `collectNudge`**. That buys **0.11 pp** of protection and **breaks both production donors** (`NudgeRatchet.dispatch` and `BalancerPoolerV2._donate` both call it unconditionally). The current framing therefore points a maintainer at a change that is net-harmful.
- **Replacement framing — the intent gap:** `NudgeStreamer.sol:19-23` claims the contract "streams them linearly to zero over a configured `duration`". It is in fact a **first-order low-pass filter** with time constant `duration`: 99% delivery takes **32.2 days against a 7-day `duration`** (a 4.6× stretch), and 100% never arrives while deposits continue. Steady-state throughput equals inflow exactly; the real artefact is a permanent float of `duration × inflow`. Remediation is documentation plus a runbook note that `duration` sizes a *time constant*, not a drain time.
- **Note for Law 2:** story-030 — the "stop asserting unenforced guarantees" story — swept the docs and left this exact claim standing, while making its sibling sentence load-bearing for suppressing `858e9e807a`/`521c20ad48`. I had that suppression basis re-checked specifically: it **survives** (nobody can accelerate release). Not disturbing those suppressions.

## D-034 — ECON-26-02 filed separately from CODE-01, same code site
- **Decision:** file the disable-lever gap as its own finding (Low/QA) rather than folding it into CODE-01's availability limb, even though both point at `BatchNFTMinterMultiToken.sol:528-536`.
- **Basis:** genuinely different consequences from one omission. CODE-01 is *availability* (a revert bricks batches). ECON-26-02 is *value migration*: `nudgeSize == 0` is documented twice as disabling the feature (`:40-41`, `:269-270`), but the ungated flush turns the disable from *meter-and-pay* into **accumulate-forever** — value moves from the metered streamer into the batchMinter's un-metered balance, with no return path (no streamer withdrawal or deregistration), invisible to `pendingStream`, and swept whole by the first re-enabled qualifier. ~30,000 units for a 30-day disable at 1,000/day. Non-obvious footgun ⇒ in scope under Law 3.
- **One fix closes both**, but a reader who only sees the availability framing will gate the loop and never learn the accumulation happened. Two entries, cross-referenced.

## D-035 — D-015 unknowns: three of four now CLOSED by evidence
- (1) `_executeMint` charges `config.price` — **closed** (D-028).
- (2) ignored `mint()` bool — **closed**, carries zero information (D-028).
- (3) cross-repo `NudgeCollected` desync — **closed as ECON-26-03, QA only.** No `NudgeCollected` consumer exists in `yield-claim-nft`; `NudgeRatchet` keeps no cumulative sent-amount counter; the mint-debt ledger derives from `onDispatch`'s `amount` (`NudgeRatchetMintDebtHook:122-130`), not the credit. Unreachable for USDC regardless. Residual is an off-chain silent under-count with no ABI signal.
- (4) live on-chain config — **REMAINS OPEN**, parked visibly. Must be resolved from chain, not deploy records (memory `phstaging-mainnet-addresses-stale-trap`: records have shown 0x0 for live funded instances). Carried into the report as an operational verification item, not silently dropped.

## D-036 — Run Tier 3, scoped to CONFIRMING the Leg-B negative claim
- **Decision:** run Tier 3 despite zero High/Medium candidates, but scope it narrowly: machine-confirm the `Σ buffer_i <= balanceOf(this)` conservation property that D-026 killed Leg B on.
- **Alternatives:** skip Tier 3 as low-yield given an all-Low finding set.
- **Basis:** D-026 is a **negative** claim ("no plain-ERC20 path exists"), reached by human enumeration of 4 write sites. Negative claims are exactly where a machine check earns its cost, and getting this wrong is a Law-1 miss. Also directly tests the F-02 false-guarantee claim from the other direction.
- **Guardrails imposed:** (a) memory `vacuous-invariant-harness-mock-never-fails` — the harness MUST seed guarded state and carry an abort-on-empty tripwire, or a pass means `0 == 0`; (b) memory `symbolic-timeout-is-not-proof` — a Halmos TIMEOUT is reported as inconclusive, never as verified; (c) agents run **sequentially** with jobs capped at 2 (memory `wsl2-limit-parallelism`).

## D-037 — Leg-B kill is MACHINE-CONFIRMED, and the harness is proven able to fail
- **Decision:** accept D-026's kill as machine-backed. 452,000+ fuzzed calls across two independent engines (Foundry 200k, Medusa 200,310 / 2,001 sequences, 23/23 properties), zero counterexamples under a plain well-behaved ERC20. INV-1/2/3/3c/4 all PASS, revert ratio **0.00%**, no handler ever skipped or always-reverting.
- **The part that makes it worth trusting:** the anti-vacuity tripwire **fired twice during development** and the agent fixed the *harness* both times rather than the assertion — and the harness is **mutation-verified**: a 1-wei-over-crediting mutant (`test/patched/MutantNudgeStreamer.sol`) IS caught by INV-1, with the downstream harm pinned (`ERC20InsufficientBalance(streamer, 1e21, 1e21+1)` on the next `pullPendingStream`, bricking `batchMint`'s loop). So a green INV-1 carries information. This directly discharges memory `vacuous-invariant-harness-mock-never-fails`.
- **Honesty caveat retained in the report, not softened:** this is "no counterexample in N sequences" — absence of evidence, not proof. Untested by design: fee-on-transfer, rebasing, hook-bearing, non-18-decimal tokens, and all batchMinter-side logic (`MinterStub` implements only `isNudgeToken`).

## D-038 — ⚠ CORRECTION: the econ tier's decay figure was ORIENTATION-INVERTED
- **Decision:** correct the number everywhere before it reaches the report, and note that the correction makes the intent gap **worse**, not better.
- **What was wrong:** econ reported "~36.68% of a burst remains buffered at the nominal window end." Measured (settled, 7-day window, 28 even deposits): **61.59% retained / 38.40% released.** Analytically `dB/dt = q − B/D` ⇒ `B(D) = qD(1−1/e)`, so `1/e ≈ 36.8%` is the **RELEASED** share and **~63.2% is RETAINED**.
- **Corroboration:** 63.2% matches the **63.26%** figure from the run-18 depletion PoC (ledger `b58b172e2a`) — the same Linear-Depletion shape, independently arrived at. That agreement is why I trust the corrected orientation over the analytic sketch.
- **Consequence for D-033's re-frame:** unchanged qualitatively (first-order low-pass, not a linear drain; `e^{-t/D}` withholding bound confirmed; buffer settles to exactly 0 after the window, no stuck residue) — but the magnitude of the documented-vs-actual gap nearly doubles. The `NudgeStreamer.sol:19-23` "streams linearly to zero over a configured `duration`" claim is further from reality than the econ pass suggested.
- **Recorded prominently because** an inverted percentage that agrees with a prior PoC by coincidence of digits (36.8 vs 63.2 both derived from `1/e`) is exactly the kind of error that survives review.

## D-039 — Escalate INV-1 to symbolic proof rather than stopping at fuzzing
- **Decision:** hand INV-1 to Halmos, on the invariant-generator's own recommendation.
- **Basis:** INV-1 is arithmetic-only, one storage struct, four write sites — plausibly *provable* for a bounded stream count rather than merely un-falsified. And it is load-bearing: a violation bricks `batchMint`. A load-bearing negative claim deserves a proof attempt, not just 452k samples. Cost is bounded; the downside of being wrong is a Law-1 miss.
- **Pre-committed guardrail:** a Halmos `TIMEOUT` or `UNKNOWN` will be reported as **inconclusive**, never as verified (memory `symbolic-timeout-is-not-proof`). I am writing that down *before* seeing the result so a timeout cannot be quietly re-read as a pass.

## D-040 — Symbolic run did not gate the funnel; dedup started in parallel
- **Decision:** when the symbolic agent returned with Halmos still running (5 processes), I pinged it for an honest partial rather than waiting, and started dedup concurrently.
- **Basis:** symbolic here only *corroborates a kill* (D-039) — it cannot add a finding, only resurrect one. So it is not on the critical path for triage. If it does produce a counterexample, that is an escalation I will handle out of order, and dedup's output would be amended rather than wasted.
- **Guardrail restated to the agent in writing:** unfinished paths must be reported as INCONCLUSIVE-timeout verbatim; a partial ("PROVED for `collectNudge` at ≤3 streams with 64-bit-bounded amounts, remaining sites inconclusive") is a useful result, an over-read pass is not.

## D-041 — Dedup given the upstream merge decisions as FIXED inputs, not suggestions
- **Decision:** hand the deduplicator the seven merge/kill calls already reasoned out (D-013 merge, D-034 keep-separate, dual-routing of CODE-03/F-02, D-019 keep MR-26-01 separate, S-03 kill, S-04 pre-existing, S-05 cull-with-reason) as decided, with instructions not to re-litigate.
- **Alternatives:** let dedup re-derive them independently as a cross-check.
- **Basis:** these calls were made with more context than a dedup pass has (story text, cross-repo reads, 452k-call harness results). Re-deriving them risks a *less*-informed agent collapsing distinctions that were deliberately preserved — the exact failure mode this suite has hit before (memory `run-21`: "M-03 is the SOLE surviving guard, never collapse"). Trade-off accepted: I lose an independent check on the merges, and compensate by requiring a full input→output count reconciliation with every drop accounted for.
- **Explicit no-silent-drop mandate** issued, plus the disclosure duty for `bfdb50105e` and `966e717669` (new fingerprints on a shared root-cause class will NOT trip normal dedup — memory `disclose-when-re-filing-an-owner-wont-fix`).

## D-042 — ⚠ DO NOT APPLY the run-20 proposed-`fixed` on ledger `9135cf7947`
- **Decision:** reject the proposed closure. Dedup found a ledger-vs-source contradiction and chased it: the run-20 proposed-`fixed` cites `BatchNFTMinter.sol:11/:82/:300` for a ReentrancyGuard that **does not exist at `9611312`** — those line numbers are actually `BatchNFTMinterMultiToken.sol`. The guard genuinely existed at `0d1a0b2` (added by `2bf13cb`) and was **deliberately removed** by `fba4991` ("story-022 Stage 7: split multi-token nudge out of the deployed BatchNFTMinter").
- **Classification: EXPIRED CLOSURE, not a regression.** Per memory `expired-closure-vs-regression`, a closure whose rationale evaporated is its own bucket — filing it as a regression would send a reader to restore a patch that was intentionally removed, which is the wrong action.
- **Keep unmerged:** the live condition is already correctly tracked by `c847207db2` (Medium, open, exploit-backed). Two entries, deliberately not collapsed.
- **Nothing was silently closed** — status was `submitted`. Recording this because a proposed-`fixed` citing the wrong file is exactly the kind of thing that gets rubber-stamped, and only a human may apply a `fixed` (CLAUDE.md).

## D-043 — F-02 walked back from `potential-medium` to Low
- **Decision:** accept dedup's recommended walk-back. F-02's Medium rested on the DoS chain, and Leg B's kill removed that chain. The false-guarantee documentation defect is real and remains the strongest Law-2 finding of the run, but it is Low.
- **Basis:** severity must follow the surviving impact, not the original thesis. This is the seventh position abandoned this run and follows directly from D-026. Consistency check passed: I am not keeping a Medium alive on sentiment after killing its mechanism.

## D-044 — Report finalization BLOCKS on `tier3/symbolic.md`
- **Decision:** hold the final report until the symbolic result lands, rather than shipping with the input missing.
- **Basis:** the symbolic target INV-1 **is** the killed Leg B. A plain-ERC20 counterexample would reopen D-26-01 at Medium under its own written reopen trigger; a TIMEOUT proves nothing either way. Shipping "0 High / 0 Medium" while a proof attempt against the one killed candidate is still running would be a Law-1 sequencing error, not merely untidy.
- **Bounded, not open-ended:** if Halmos yields only inconclusive results, the run ships as all-Low with the inconclusiveness stated in the report — not as a verified-clean.

## D-045 — Disclosure statements: `bfdb50105e`'s suppression argument does NOT transfer
- **Decision:** accept and require all eight drafted disclosures, and specifically endorse the finding that `bfdb50105e`'s wont-fix rationale — *"caller chooses both the token and the recipient"* — **does not transfer** to D-26-01, because the flush loop iterates the **owner's** whitelist, not caller-chosen tokens. A suppression that rests on caller-choice cannot cover an owner-controlled iteration.
- **Also required:** the `966e717669` disclosure must state that D-26-01 is the **third** occurrence of the un-`try/catch`'d-external-call class in this ledger. A recurring class deserves to be named as recurring.
- **Plus a cross-PROJECT disclosure for D-26-08** (phStaging run-21 M-02, stable-yield-accumulator `0xd62cbfe8`) that normal dedup structurally cannot see, since fingerprints are per-project. Memory `disclose-when-re-filing-an-owner-wont-fix` is the governing rule.

## D-046 — D-044 UNBLOCKED: symbolic found no counterexample; D-26-01 does NOT reopen
- **Decision:** the Leg-B kill stands; D-26-01 stays Low; the run ships as 0 High / 0 Medium (subject to the CODE-02/D-26-05 severity dissent below). The written reopen trigger was NOT met.
- **What was actually proved** (recording precisely, because "verified" without qualifiers would be the dishonest summary here):
  - `collectNudge` (the only buffer-*increasing* site) — **PROVED at 2 streams** over a wide domain: values/balance/amount < 2^96, `rewardPerSecond` < 2^128, `elapsed` < 2^40, **symbolic** durations in [1, 2^40).
  - `_settle`, `registerStream`, and the `pullPendingStream` external-transfer path — **PROVED at 2 streams** at the same bounds. The last one in the strong **no-brick** form: given only the inductive hypothesis, `:243` **cannot revert** for insufficient pooled custody. That is the exact failure Leg B alleged, disproved directly.
  - Supporting lemma **PROVED**: a settle never exceeds the stream's own buffer, and the amount leaving custody equals *exactly* the buffer decrease.
- **What was NOT proved, stated plainly:** the 3-stream case is **PROVED only below 2^32** and is **INCONCLUSIVE-timeout** at 2^64 and 2^96 (3 attempts: 183s/302s/242s solver budgets). The **N > 2 generalisation is hand-checked code inspection, not machine-proved** — `collectNudge:157`, `pullPendingStream:221`, `registerStream:131` each resolve exactly one `Stream storage` and never read another pair's buffer, so `Σ_{i≠k} buffer_i` is an unchanged constant, matching the passing 2-stream shape. Concretising untouched streams' unread rate fields did not rescue the timeout, so the blow-up is the three-addend aggregate against the nonlinear `rewardPerSecond * elapsed / 1e18` term.
- **Guardrail honoured:** the 600s whole-suite run was **killed before completion and nothing is claimed from it**. Timeouts are reported as INCONCLUSIVE-timeout, never as passes — exactly as pre-committed in D-039 before any result was seen.
- **Anti-vacuity control passed:** the mutation test `check_MUTANT_site1_collectNudge_2streams_expectFail` against the 1-wei over-credit mutant returns **[FAIL] with 4 counterexamples in 27s**. The harness demonstrably falsifies, so the PASSes carry information.
- **Method strength worth noting:** inductive over an arbitrary symbolic pre-state constrained *only* by the invariant plus bit-width bounds — a superset of reachable states, so a PASS is stronger than a reachable-state proof. Real contract, no logic mocked.

## D-047 — Steps 3–5 of the pipeline (PoCs + H/M reports) are NO-OPS this run
- **Decision:** skip PoC generation and H/M submission reports, because there are zero High and zero Medium findings. Do not manufacture a PoC for a Low to make the run look productive.
- **Conditional:** if severity-auditor upholds my D-029 dissent and promotes D-26-05 to Medium, PoC generation and a submission report become **required** for it, and I will run them. Deciding this in advance so the promotion path is not skipped for convenience.
- **Basis:** CLAUDE.md requires a runnable PoC for every High/Medium; it does not ask for PoCs on Lows, and "low-value findings dilute the report."

## D-048 — Zero suppressions accepted as STRUCTURAL, not as leniency
- **Decision:** accept 13-in/13-kept. I probed this specifically because a zero-suppression result is the shape a lazy sanitizer produces, and it held up: the submodule `CLAUDE.md` (118 lines) contains **no mention whatsoever** of `BatchNFTMinter`, `BatchNFTMinterMultiToken`, `NudgeStreamer`, the nudge pot, or the whitelist. KIs #1–#14 are entirely about the `NFTStaker` family; all 13 findings live in the nudge subsystem. Only #15/#16 reach it, and both are narrowly about *pot-size economics* — a claim class this run no longer makes (the economic limb was withdrawn/re-framed upstream at D-032/D-033).
- **Basis for trusting it:** the KIs were re-derived against `9611312` rather than taken from cache, and four suppressions were *declined with reasons* — a sanitizer that declines is one that was actually evaluating.

## D-049 — Endorse the four DECLINED suppressions, especially the KI #12 refusal
- **Decision:** uphold all four declines.
  - **D-26-09/-10 under KI #12** is the closest call and the most important refusal: identical shape (event field meaning shifted, ABI byte-identical, off-chain consumers exposed). Declined because KI #12 rules on **one** prior decision (`ScheduleRecomputed` on `NFTStaker`, audit M-03), not a class. **Generalising a single-instance KI into a class would pre-authorise every future event repoint** — a permanent, invisible suppression surface. That reasoning is correct and I am recording it as the governing precedent.
  - **D-26-08 under KI #1**: `setNudgeStreamer` is outside KI #1's closed seven-setter enumeration, on a different contract, and KI #1 blesses *centralization*, not *silent failure*. The event emits **before** assignment, so a mis-point reads as clean success in logs.
  - **D-26-13 as OOS tool-noise**: the content is an argued design property (sole admission gate on `registerStream`), not a bare `missing-inheritance` hit. Flagged to qa-bundler as the run's marginal entry — honest labelling rather than quiet inclusion or quiet removal.
- **Basis:** Law 1 — an ambiguous suppression is declined, not granted.

## D-050 — D-26-02 narrowed at the LIMB level rather than kept-whole or suppressed
- **Decision:** accept striking only the *magnitude illustration* ("un-metered lump"), which reads onto KI #16's verbatim DO-NOT-FILE item *"'NudgeStreamer fails to cap the payout'"*, while keeping the finding on its actual claim: disable-lever asymmetry, wrong-container custody, absent return path, invisibility. Supported by two in-source "disables the feature" claims verified at HEAD (`:40`, `:271`), and outside every DO-NOT-FILE item and all four carve-outs.
- **Basis:** limb-level surgery is the right granularity here — suppressing the whole finding would have hidden a real footgun behind an economic claim I had already withdrawn; keeping the struck limb would have violated a live KI. Recording it because partial suppressions are easy to apply invisibly.

## D-051 — ⚠ KI PROVENANCE DEFECT: a Law-1 hazard in waiting; fix required, and NOT by me
- **Decision:** route three KI-hygiene defects to project-manager as a registry correction; do not paper over them, and do not fix the registry from within a scan step.
  1. **Provenance is mislabelled — the dangerous one.** `knownIssuesSource` claims all 16 KIs came from the submodule `CLAUDE.md`, but **#15/#16 are registry-authored dated owner decisions absent from that file**. A future sanitizer that "re-derives KIs from `CLAUDE.md`" per the stated source would **silently lose the only two KIs that reach the nudge subsystem — including both sets of Law-1 carve-outs.** That is a suppression-integrity failure waiting to happen.
  2. KI #15's `:62-70` citation is **stale** — the text is now at `:130`.
  3. `knownIssuesExtractedAt 2026-07-26` predates stories 029–032; no re-extraction has covered the nudge subsystem post-story-032.
- **Basis:** memory `phlimbo-ea-known-issues-unfalsifiable` — a sibling project had suppressions blocked precisely because its KI set was not re-derivable. Same class of defect, caught earlier here. Predicates for #15/#16 were verified intact this run (`:95` confirms the deleted gate; `:130` carries the quoted position), so nothing is currently mis-suppressed.

## D-052 — Action handed to the classifier on D-26-11 (potential carve-out proximity)
- **Decision:** require the severity step to test one specific reachability question rather than accept the documentation framing: does the step-5→step-9 erosion path — which charges a refund shortfall to `D` then `P` — reach without a **misbehaving** token? If yes, D-26-11 is a finding in its own right, not a documentation defect.
- **Why it matters:** that path runs *toward* KI #16 carve-out (d) *"ANY CLAIMANT TAKING OTHER USERS' MONEY"* and (b) *"refund > paymentAmount"*. It is un-suppressible either way, but the severity differs enormously between "doc is wrong" and "a claimant can absorb another party's money on a plain token".
- **Basis:** Law 1. This is the single remaining place in the run where a Medium could still be hiding, so it gets an explicit test rather than an inherited label.

## D-053 — Sanitizer's open contingency on D-26-01 is now CLOSED
- **Decision:** the sanitizer noted it could not close D-26-01's symbolic-coverage contingency. D-046 closes it: Halmos found **no counterexample**, and proved the no-brick property directly. D-26-01 stays Low; Leg B is not revived.
- **Recorded** so the contingency is visibly discharged rather than left dangling in two documents that never reference each other.

## D-054 — WALK-BACK: my D-26-05 Medium dissent is REFUTED; Low upheld
- **Decision:** accept Low. I asked for this to be decided against me if the evidence warranted, and it was.
- **Why my premise was wrong:** I argued the wiring-order mistake was a *non-obvious* footgun. `NudgeRatchet`'s own NatSpec (`:23-43`) documents the entire hazard — the exact revert, the blast radius (*"every `dispatch`"*), a numbered required ops ordering with `setNudgeStreamer` explicitly **last**, and the `setBatchMinter` repoint case **my dissent did not account for**. The mistake I posited is precisely the one that list exists to prevent, at the function that causes the harm. Law-3 surprise test **fails** ⇒ not a footgun.
- **Important distinction the classifier got right:** it did NOT defer to the NatSpec's "NOT an audit finding" clause (which carries no suppression authority per memory `in-source-natspec-carries-no-suppression-authority`). What does the work is that the disclosure is **accurate** — the severity-raising rule applies to *falsely*-exhaustive docs. An accurate warning is a real mitigation; a false one is an aggravator. I had been conflating the two.
- **Availability limb, stated for the record:** does not reach Medium because the outage is privileged-triggered, self-diagnosing (named custom error on the first mint), one-tx recoverable, and locks no value. Medium needs attacker-inducible **or** undetectable **or** unrecoverable; it is none of the three.
- **One of my three arguments survived:** story-031's `ZeroReceived` is genuinely **absent** from NudgeRatchet's otherwise-complete revert enumeration. That becomes the finding's actual content.

## D-055 — ⚠⚠ REMEDIATION TRAP #2: do NOT recommend wrapping `collectNudge` in `try/catch`
- **Decision:** strike the obvious-looking fix. This is the second net-harmful remediation caught this run (cf. D-033) and the more dangerous of the two.
- **Why it is harmful:** `ATokenDispatcherV2.dispatch:124-125` runs `_dispatch` **then** `hook.onDispatch(minter, amount, …)`. Swallowing the revert lets `_dispatch` succeed, leaving USDC on the dispatcher while mint-debt accrues against `amount` — the exact direction `NudgeRatchet:148-149` guards against. It is transient and self-healing (correctly NOT filed as unbacked phUSD), but it makes the misconfiguration **silent** — i.e. it moves the contract *into* the D-26-08 silent-failure class in order to escape a Low.
- **Replacement recommendation:** add the missing `ZeroReceived` row to the revert enumeration, document the deliberate divergence from `BalancerPoolerV2`'s `try/catch`, and **keep the revert**.
- **Generalisable lesson worth carrying:** twice this run, the naive fix for a Low would have created a worse problem than the Low. Any "just wrap it in try/catch" or "just permission it" recommendation in this codebase needs the downstream leg traced first.

## D-056 — Q1 answered: no Medium in D-26-11; carve-out (b) is structurally IMPOSSIBLE
- **Decision:** D-26-11 stays a documentation finding (Low). The erosion path requires a **token-side property** — specifically something that reduces the contract's `paymentToken` balance between `:581` and `:708` other than the minter's `transferFrom` of `price` (negative rebase, admin clawback/burn, or a FoT variant debiting `price + fee`). All C4-invalid standalone.
- **The leg that was actually proved** (the in-source comment asserts it but never proves it): the loop's decrement equals the loop's outflow. Verified *at the counterparty* — `batchMint:646` reads `price` from `configs()`, and `NFTMinterV2._executeMint:179-183` (`yield-claim-nft` @ `d4cc563`) reads the same slot and transfers exactly `price`, with the ramp at `:188` happening *after*, same tx, no interleaving write. `rescueERC20` cannot interleave (`nonReentrant`, separate tx) and the dispatcher sweeps its own balance, never the batchMinter's. Therefore `available = P + (credited − C) + D ≥ refund` always, and the `:709` cap is a **provably dead branch**.
- **KI #16 carve-outs discharged:** (b) `refund > paymentAmount` is **structurally impossible**, not merely unobserved (`refund ≤ budget ≤ paymentAmount` at `:604`); (d) does not fire.
- **Replaced with a watch-note, not closed silently:** the proof depends on an **undocumented cross-repo `config.price` coupling**. If that coupling is ever broken, this becomes a real value-transfer finding. That is a durable tripwire of the same shape as D-031.

## D-057 — Two escalation contingencies recorded as live tripwires, not resolved
- **Decision:** carry forward, in the report, that the **≥3-stream INV-1 symbolic gap** (INCONCLUSIVE-timeout above 2^32, N>2 hand-checked) escalates **both D-26-01 and D-26-05 to Medium** if a plain-ERC20 counterexample is ever found.
- **Basis:** honest reporting of what the proof does and does not cover. The run ships all-Low *given* the coverage achieved; the contingency is part of the result, not a footnote to be dropped.

## D-058 — D-26-08 held at Low against a Medium-class cross-project precedent
- **Decision:** uphold Low, on a stated distinction rather than by ignoring the precedent: the phStaging run-21 M-02 / SYA `0xd62cbfe8` analogues were Medium, but here the incentive is *optional*, funds remain *recoverable*, and the EOA case is defeated by solc 0.8.20's retained `extcodesize` check.
- **Basis:** the cross-project disclosure (D-045) is still made in full, so a reader sees the precedent and the distinction together and can disagree with me. Suppressing the comparison would have been the failure; reaching a different conclusion from it openly is legitimate.

## D-059 — Ledger integrity: VERIFIED CLEAN against the pre-run snapshot
- **Outcome:** 78 → 91 (+13). Status histogram **byte-identical** before/after (open 46, wont-fix 18, false-positive 4, fixed 3, fix-pending 3, submitted 3, merged 1). All 3 `fix-pending` (`1c222d5485` High, `a62fe01a25` Medium, `bdf84579b6` Medium) byte-identical; all 18 `wont-fix` byte-identical. 16 pre-existing entries touched, **metadata-only**, every note edit verified **append-only** (original prefix byte-intact).
- **Why this check was mandated:** memory `verify-subagent-ledger-writes` — an agent in this project once silently flipped a HIGH from `fix-pending` to `wont-fix` while reporting only "3 entries differ". The snapshot + full diff requirement exists because of that incident, and this run discharges it explicitly rather than by assertion.
- **No status transition applied anywhere.** `PLA-26-01/-02/-03` are proposals for a human via `/ledger`; the run-21 and run-25 unapplied backlogs were left byte-identical, and `run26.notAppliedByThisRun` points a reader at all three.

## D-060 — ENDORSED: the agent's own judgement call on `lastSeenRun` for `fixed` entries
- **Decision:** uphold its refusal to bump `lastSeenRun` on `b58b172e2a` (M-01, `fixed`) and `2d34673536` (also `fixed`), restoring the former to run-18 and recording *"reconciled, not re-observed"*.
- **Why it is right, and better than my instruction:** dedup listed `b58b172e2a` among "re-confirmed present", and I passed that through. On a `fixed` entry, `lastSeenRun: run-26` reads as **"seen present at run 26" — i.e. a regression signal**. Bumping it would have manufactured a false regression on a closed Medium, which is exactly the highest-signal artifact in this pipeline and therefore the worst thing to fabricate.
- **Recorded as a correction to me**, not as a subagent deviation: my brief was ambiguous and the agent resolved it in the safer direction and flagged it. That is the behaviour I want.

## D-061 — L-01's `try/catch` mitigation PROMOTED from secondary to co-equal primary
- **Decision:** overrule the qa-bundler's demotion. It filed "gate the flush loop on `qualifies`" as the primary fix and "`try/catch` skip-with-event on `pullPendingStream`" as secondary defence-in-depth. I promoted the second to co-equal and required the report to state that the first **alone leaves the primary impact live**.
- **Reasoning:** gating on `qualifies` removes exposure only for **non-qualifying** batches — it restores the structural immunity those callers used to have. A **qualifying** batch still iterates `pullPendingStream` over the whole whitelist, so a single reverting nudge token still bricks it. That brick is L-01's *leading* stated impact, and the `qualifies` gate does not touch it. Shipping the gate as "the fix" would have let a reader close L-01 while the headline failure remained reachable.
- **Tension I had to resolve deliberately:** D-055 says do NOT recommend `try/catch` at L-03's site. Recommending it at L-01's site looks inconsistent, so the asymmetry has to be *argued*, not glossed: swallowing is safe at the flush site (optional to the caller, nothing downstream accrues debt) and harmful at L-03's (`ATokenDispatcherV2.dispatch:124-125` runs `hook.onDispatch` after `_dispatch`, so mint-debt accrues against `amount` while USDC stays put). The bundler's "do not generalise to L-03" note is retained verbatim.
- **Basis:** an incomplete fix that reads as complete is, per CLAUDE.md, more dangerous than an unfixed bug. Same principle as the ⚠ INCOMPLETE FIX ranking, applied pre-emptively at the recommendation stage.

## D-062 — 4naly3er trap avoided; two arithmetic self-corrections accepted
- **Outcome:** `yarn analyze <submodule-root> <scope-list>` with `basePath` at the submodule root, so the submodule's own `remappings.txt` resolved in place; arg 3 a genuine scope list of the 14 first-party `src/*.sol`. **No symlink.** All 14 files parsed, zero unresolved-import or parse errors. Discharges memory `4naly3er-remappings-gap-fix`.
- **Two self-caught errors worth recording** because both are the kind that ship silently: the agent initially mis-read `NFTStakerDepletionV2.sol` as uncovered (its own `[A-Za-z]*` regex dropped the digit — the file appears 50 times), and recomputed appendix totals caught two wrong sums in its first draft (Gas 949→**979**, NC 622→**712**). Related to memory `grep-head-truncation-false-coverage-gap`: a regex artifact almost produced a false coverage-gap claim.
- **Centralization count is 0, stated with a reason** rather than left blank: 4naly3er's `M-2 Centralization Risk for trusted owners` (92 instances) is a blanket `onlyOwner` enumeration that Law 3 suppresses wholesale.

## D-063 — ENDORSED: the knock-on L-02 correction my D-061 override forced
- **Decision:** keep the agent's two consequential edits beyond my instruction. Both L-02 sites had said the `qualifies` gate was *"one fix closes this and L-01"* — which **my** D-061 change made false. They now read: the gate is **part 1 of L-01's fix and closes L-02 in full**, with an explicit note that L-01 additionally needs part 2.
- **Basis:** my override introduced the inconsistency, so declining the follow-through would have left a false claim in two places and made L-02 look like the cheaper fix it no longer is. The agent flagged it as touching a finding I had not asked it to touch, which is the right instinct — and the right call was to make the edit.
- **Anti-harmonisation guard added, which I did not ask for and endorse:** a `tryCatchAsymmetryVsL03` field on the L-01 record carrying the distinction and its `hook.onDispatch` mechanism, marked as a deliberate distinction to preserve in any restatement — so a later agent cannot quietly "harmonise" the two opposite `try/catch` verdicts into one. That is a durable defence against exactly the D-055 trap being re-introduced downstream. Fingerprint `8bee8d5a…` untouched; severity and label unchanged.
- **The agent's own assessment, recorded because it is the honest one:** its draft was "wrong on the substance, not just the emphasis" — it had the gate as the primary fix when the gate does not touch the primary impact at all.

## D-064 — ⚠ L-01 may trip its OWN reopen trigger: `plainTokenReachability: "NIL"` is a factual error
- **The development:** the validity-checker found that L-01's record claims `plainTokenReachability: "NIL"`, which is **wrong**. `_settle` transfers to the batchMinter, so a **USDC pause** — or **USDC/USDT blocklisting of the batchMinter address** — reverts the un-gated flush loop and bricks `batchMint` for everyone. USDC is the actual settlement asset; pause/blocklist is canonical documented behaviour, not a weird-token property. USDT is the *named exception* to the weird-ERC20 known-invalid rule.
- **Why this is serious:** D-027 held L-01 at Low with a trigger I wrote verbatim — *"reopens at Medium if a plainly-reachable trigger is found — the impact side already qualifies."* If an issuer pause or blocklist is plainly reachable, that trigger is met **on its own terms**, and holding L-01 at Low would mean ignoring a condition I set myself when I had no stake in the answer.
- **Decision:** escalated to severity-auditor mid-flight rather than resolved by me, with the standard spelled out both ways: not attacker-inducible (cuts to Low) vs requires no weird token, no owner mistake, no hypothetical (cuts to Medium). Explicitly instructed: do not hold at Low to preserve a tidy "0 High / 0 Medium" headline, and do not raise it merely to avoid an all-Low run. If it goes Medium, PoC + submission report become required and I will run them (per D-047's pre-commitment).
- **Independent of severity, the field is corrected:** read literally, `"NIL"` invites a future reader to dismiss L-01 as weird-token-only. That is precisely a Law-1 miss waiting to happen, so it gets fixed regardless of the severity outcome.
- **Note on process:** this was caught by the *last* agent in the pipeline, checking source rather than trusting the findings' own claims. Worth remembering that the validity gate earned its keep here by disagreeing with the record, not by ratifying it.

## D-065 — Two RESCOPES required before publication (accepted)
- **L-03 → retitle and reband.** Its current title asserts the availability limb that this run itself refuted as a footgun (D-054); standing alone that is a reckless-admin **invalid**. The residual is real and confirmed at source (`NudgeStreamer__ZeroReceived` declared `:93`, reverted `:199`, appears nowhere in `NudgeRatchet`), so the finding survives — retitled to the `ZeroReceived`-omission + failure-semantics-divergence defect, and **QA is the more defensible band** than Low.
- **F-01-031 → pin to the token-independent limbs.** Story-031's review Issue 1 frames the gap as a *rebase carve-out*; importing that framing would turn F-01-031 into a weird-token finding and make it invalid standalone. The defect must rest on the documented-basis error, not on rebase.
- **Basis:** both rescopes make findings *narrower and more defensible*. A title that overstates is the same credibility failure as an inflated severity, and neither survives review.

## D-066 — L-04 is STRONGER than filed; add the citation it omits
- **Decision:** amend L-04 to cite `BatchNFTMinterMultiToken.sol:318-320`, which affirmatively asserts the hazard away: *"adding works while `tokenMinter`/`dispatcherIndex` are unset … and **no longer an ordering constraint on deployment scripts**."*
- **Why it matters:** an operator who strands donor throughput is not being reckless — they followed **shipped documentation stating the constraint was lifted**. That converts L-04 from "owner should have known" to "the code told the owner it was safe", which is the strongest possible form of the Law-3 non-obvious-footgun test. The finding currently does not cite this at all.
- **Recorded** because a strengthening found at the validity gate is as much a correction as a downgrade, and this one was found by reading source rather than the finding's own claims.

## D-067 — L-01 NOT raised on the USDC/USDT challenge; reopen trigger made FALSIFIABLE
- **Decision:** accept Low. The vector was not missed — the record's own `severityNote` already named "third-party-extraordinary (Circle/Tether pause or blocklist)". Redecided on a branch analysis: with USDC on **both** legs, a global pause bricks `batchMint` at the payment pull `:581` **regardless**, so the flush loop adds nothing (non-incremental); otherwise it is escapable in **one** owner transaction. Not attacker-inducible, not undetectable, not unrecoverable ⇒ Medium's availability limb is not cleared.
- **Rule vs severity, distinguished:** the USDT carve-out makes blocklist-driven reverts **in scope as a matter of rule** — it does **not** set severity. I had been treating the carve-out as if it did.
- **L-03 fails the incremental test harder:** `NudgeRatchet`'s prime token is USDC and the mint payment arrives in that same USDC, so a pause bricks the mint before `dispatch` is even reached.
- **The improvement I care about most here:** my D-027 reopen trigger ("if a plainly-reachable trigger is found") was **vague** — unfalsifiable in practice, which is why it failed to fire cleanly on this challenge. Replaced with a falsifiable one: **L-01 becomes Medium if either one-transaction escape is removed.** A trigger that cannot be checked is not a safeguard.
- **`plainTokenReachability: "NIL"` confirmed a factual error** and corrected: it contradicts the record's own `severityNote`, and fixing it moves L-01's `try/catch` mitigation onto a **plain-asset** justification. The fix's case strengthens even though the label does not move.

## D-068 — ⚠⚠ DELIVERY FAILURE: the `aaebb4b9b0` re-frame reached NO deliverable
- **The defect:** `qa-report.md:46` points readers at `submissions/carryover/`, **which does not exist**. So the run-26 re-frame of open entry `aaebb4b9b0` — the "`duration` is a time constant, not a drain time" intent gap, ~63% retained at the nominal window end, and the **reversed remediation** ("never permission `collectNudge`") — lands in no document a reader will open.
- **Why this is the most serious problem found in the review pass, ahead of every severity question:** D-033 is the single most consequential call of this run. Filed as griefing, the natural fix breaks both production donors. The whole point was to redirect a maintainer away from a net-harmful change — and it was parked where nobody would see it. That is precisely what Law 1's *visible-channel* clause exists to prevent: "never in a log nobody reads."
- **Decision:** create `submissions/carryover/` and publish the re-frame there as a first-class deliverable before the run is called complete. A correct conclusion that reaches no reader is indistinguishable from not having reached it.

## D-069 — Q-03 DROPPED (the only LOWER in the severity audit)
- **Decision:** drop it. Its own text says "impact: None at this commit" and "This is not a security finding"; its origin is unvalidated Slither noise; C4 puts it out of scope twice over (tool finding without a demonstrated H/M path, and unused-view-adjacent).
- **Basis:** dropping risks nothing Law 1 protects, and it was already flagged marginal by two independent gates (sanitizer, then validity-checker: "drop first if trimming"). Keeping it would be padding. Final tally becomes 9 Low + 2 QA + 1 Info.

## D-070 — WATCH-26-04 OVERSTATED; corrected on partial disagreement with me
- **Decision:** accept the partial disagreement with my D-054 acceptance. Accurate documentation is a legitimate mitigation **only on the surprise/likelihood limb** — it cannot move impact or recoverability, and **those code limbs hold L-03 at Low on their own**. So WATCH-26-04's claim that deleting the NatSpec would *invalidate* the Low is too strong: it would mean **re-weigh**, not automatic escalation.
- **Also extended:** the runbook lives in the *other* repo, and `setNudgeStreamer`'s own NatSpec (`:292-299`) discloses nothing — so the mitigation must cover that **third site** too.
- **Recorded as a correction to me:** I had accepted "accurate docs are severity-reducing" without bounding *which limb* they reduce. The bounded version is right.

## D-071 — Affirmative non-coupling statement required in the report
- **Decision:** state affirmatively that L-01's recommended escape hatch `setNudgeTokenWhitelist(token, false)` does **NOT** arm L-03's mint-brick — verified: `collectNudge` does not consult the batchMinter whitelist at all (only `registerStream:127` does).
- **Basis:** readers will reasonably suspect the two interact, and an unstated non-interaction reads as an unexamined one. Also fold in the L-02 wording fix: `rescueERC20` exists on the **destination** (`:386-389`), so the flush moves value from a no-rescue container into a rescuable one.
- **Systemic-entry recommendation accepted:** the thrice-recurring un-`try/catch`'d-external-call class justifies a **consolidated systemic ledger entry**, not a severity raise on any single instance.

## D-072 — Q-03 REMOVED rather than status-flagged; enum integrity preserved
- **Decision:** endorse deleting the entry outright rather than inventing a status. No canonical status describes "withdrawn pre-publication", and `false-positive` would be **wrong** — the observation is true, it is merely out of C4 scope. Inventing a status would corrupt the enum for every future query.
- **Safeguard that makes the deletion acceptable:** the full record is preserved verbatim under `run26.withdrawn26.recordAsFiled`, and the label `Q-03` is **retired** (not recycled). So the drop is reversible and auditable — deletion without that preservation would have been a silent drop.

## D-073 — Off-by-one caught in my own remediation brief
- **Decision:** accept the correction from `:318-320` to **`:317-320`** for L-04's affirmative-contradiction citation — the quoted sentence begins at line 317. I passed the severity audit's line range through without re-checking it.
- **Recorded** because a citation that does not contain the quote it claims to is the same class of defect as the `9135cf7947` proposed-`fixed` citing the wrong file (D-042), and this run has now hit it twice from opposite directions.

## D-074 — Count reconciliation published rather than quietly harmonised
- **Final tally: 8 Low · 3 QA · 1 Informational** = 12 findings, 13 records. My brief said "9 Low + 2 QA + 1 Info", which was the intermediate state *after* the Q-03 drop but *before* the L-03 reband — the reband moves one finding between bands without changing the total. Both figures describe the same 12 findings.
- **Decision:** publish an explicit `§Count reconciliation` in the QA report rather than silently picking one number, since the QA table itself reads 5 Low · 3 QA (8) and the balance is the 4 Law-2 Lows + 1 Informational in `spec-conformance.md`, with dual-routed L-06/F-04-030 counted once.
- **Basis:** three defensible numbers for one finding set is exactly how a reader loses trust. Showing the arithmetic is better than asserting a total.
- **Ledger: 91 → 91.** −1 (Q-03 withdrawn) +1 (`SYS-26-01`) — run-26's net contribution stays 13 entries; only the composition changed. Snapshot diff PASS: 0 status changes, 0 severity changes, 0 removals of pre-existing entries; all 3 `fix-pending` and all 18 `wont-fix` byte-identical.

## D-075 — Closing the two flagged residuals rather than shipping with them open
- **Residual A (the one that matters):** the carryover set does **not** reproduce the 3 `fix-pending` entries (**1 High** + 2 Medium). The agent flagged this instead of filling it, reasoning it could not write a run-26 header for them without an unsupported claim (`a62fe01a25`'s contract *was* rewritten in range).
  - **Decision: fill it.** CLAUDE.md is explicit that `fix-pending` is "**never suppressed** — rescanned, stubbed, and shown by `/open-issues` exactly like `open`", precisely so that an incomplete or absent fix cannot go unnoticed while someone depends on it landing. A High in that state missing from the deliverable is the exact failure mode that rule exists to prevent. The honest resolution is a carryover copy that states the re-verification was **not performed this run** — not omission.
- **Residual B:** three severity-audit corrections recorded as `severityAuditCorrectionsNOTApplied` (WATCH-26-03 joint re-weigh, the Q-01-vs-L-06 discriminator, the D1.2 code-invariant watch). **Decision: apply them now** — they were correctly parked visibly rather than dropped, but "visibly owed" is not a resting state for the last pass of a run.
- **Not fixing:** the intermediate artifacts (`classified-findings.md`, `sanitized-findings.md`, `dedup-report.md`) still describe Q-03 and the pre-rescope L-03 as filed. Left as-is deliberately — they are a *historical record of what the pipeline concluded at each stage*, and rewriting them would destroy the audit trail that makes the rescopes reviewable. The deliverables are authoritative; the intermediates are provenance.

## D-076 — Carryover layout: spec followed over run-25 precedent
- **Decision:** keep H/M carryover copies at `submissions/H-01-C1.md`, `M-02-C1.md`, `M-05-C1.md`, and QA carryover under `submissions/carryover/`. Run-25 put its H/M copies inside `submissions/carryover/` instead, so the two runs are now laid out differently.
- **Basis:** this matches the `/full-audit` spec exactly (`M-01 (audit 09) → submissions/M-01-C1.md` vs `L-02, L-04 → submissions/carryover/qa-report-09.md`). Run-25 deviated; the spec wins. Both the README and the QA bundle link the new locations, so a reader following either path lands correctly.
- **Cost accepted:** cross-run layout inconsistency. Flagged here so a future run normalises deliberately rather than picking whichever it happens to see first.

## D-077 — The M-02 carryover became the most valuable thing in the closeout
- **What surfaced** while writing a header that was only supposed to say "not re-verified": three facts about `a62fe01a25` that materially undermine its carried-forward `fix-pending`:
  1. `_snapshotRewards`/`_payRewards` hash identically at `5015f1b` and `9611312` — **but `_snapshotRewards` was rewritten in the *preceding* range** `d75229d..5015f1b` (story-029, 18→17 lines) and never re-proven. **Two consecutive audits have now passed over it.**
  2. The finding's **premise may have shifted and run-26 did not test it** — both functions now iterate the owner-controlled `_nudgeTokens` whitelist rather than a caller-supplied array, and NatSpec at `:789-791` self-certifies *"Duplicate entries are structurally impossible … by construction, not by scan"* — which may restate the very §4.5 reasoning the original report **proved false**. Flagged as carrying **no suppression authority** (memory `in-source-natspec-carries-no-suppression-authority`).
  3. **The fix plan's anchor is gone** — `if (rewardToken == paymentToken) continue;` was deleted in the run-25 range, so the documented dedupe insertion point **does not exist at HEAD**. A human following the fix plan would find nothing there.
- **Why I'm recording this as a decision, not a finding:** run-26 did not scan `NFTStakerDepletion`, so none of this is a run-26 finding and it must not be dressed as one. It is a *re-verification debt* statement — and it is exactly why omitting the `fix-pending` carryover (D-075 Residual A) would have been the worst call of the run. The omission would have hidden a stale fix plan pointing at deleted code.
- **Also recorded:** M-05 has been carried by **four consecutive runs (23–26)** without re-evaluation (last real look: run-22), and it is the load-bearing backstop for the M-03/M-04/M-08 wont-fixes (memory `phoenix-nft-staking-migration-cluster-triage`: never collapse those).

---

# Closing summary

**Run:** `reports/phoenix-nft-staking/26/` · `phoenix-nft-staking` @ `9611312` · REGRESSION over `5015f1b..9611312` (13 commits, 13 files, all `M`).

**Result:** 0 High · 0 Medium · 8 Low · 3 QA · 1 Informational · 0 regressions. Ledger 78 → 91. Snapshot diff clean: no pre-existing status or severity changed; 3 `fix-pending` and 18 `wont-fix` byte-identical throughout.

**Positions I abandoned during the run (9).** Recorded because the pattern matters more than any single finding: Leg B killed (D-026, then machine-confirmed D-037/D-046) · story-032 over-reach refuted (D-021) · two story-030 attributions reassigned by `git log -S` (D-022) · `aaebb4b9b0` escalation refuted at 0.11pp (D-032) · decay figure orientation-inverted (D-038) · F-02 Medium→Low (D-043) · my D-26-05 Medium dissent refuted (D-054) · "accurate docs reduce severity" bounded to the surprise limb only (D-070) · a citation off-by-one I passed through unchecked (D-073).

**Two net-harmful remediations caught (D-033, D-055)** — permissioning `collectNudge` (breaks both production donors for 0.11pp) and wrapping `collectNudge` in `try/catch` (converts a loud failure into silent mint-debt accrual). Twice the obvious fix was worse than the finding.

**The most serious defect found was a delivery failure, not a severity error (D-068):** the `aaebb4b9b0` re-frame reached no deliverable at all because `qa-report.md` pointed at a directory that did not exist.

**Highest-value durable output:** the re-verification debt on `a62fe01a25` (D-077) — a `fix-pending` Medium whose fix plan anchors on code deleted two ranges ago.

**Owed to a human (nothing auto-applied):** `/recheck phoenix-nft-staking a62fe01a25` first, then `1c222d5485` and `bdf84579b6`; three `/ledger` proposals (`PLA-26-01/-02/-03`); the registry KI-provenance fix (D-051); and MR-26-05 — live on-chain config must be resolved **from chain, not deploy records**.

## D-078 — VERIFICATION CHALLENGE: Medusa leg RETRACTED; Halmos + Foundry CONFIRMED
- **Trigger:** the user asked directly whether the Tier-3 results were hallucinated, noting that in prior runs Halmos had **died and been assumed to pass** under a weaker model. Correct challenge to make; I re-ran the toolchain myself rather than restating the agents' reports.
- **CONFIRMED — Halmos (halmos 0.3.3 installed, all 10 test names match the JSON):** re-ran live and reproduced `check_site2_settleNeverRevertsForInsufficientCustody` **PASS** (40.17s live vs 39.75s reported), `check_site3_registerStream_2streams` **PASS** (14 paths, matching), `check_lemma_settleNeverExceedsOwnBuffer` **PASS** (10 paths, matching), `check_site1_collectNudge_3streams` genuinely **`[TIMEOUT]` with NO counterexample** (queries dumped to `/tmp/...-timeout`), and the mutant control **FAIL with 4 counterexamples**.
- **The exact historical trap is live in this tool and was navigated correctly:** Halmos renders a TIMEOUT in its summary line as `0 passed; 1 failed`, so an undecided query can be misread as a pass *or* as a finding. The agent classified all three as INCONCLUSIVE-timeout with zero safety weight, which is right.
- **CONFIRMED — Foundry invariants:** 5/5 PASS, **128,000 calls per invariant**, 0 reverts, `invariant_INV4_harnessIsLive` (the anti-vacuity tripwire) passing.
- **⚠ RETRACTED — Medusa. The second-engine leg is NOT SUBSTANTIATED and is treated as NOT RUN.** `medusa-run26.json` is a *config*, not results; its declared `corpusDirectory: medusa-corpus-run26` **does not exist** while `medusa-corpus-run22` and two others do (so corpus persistence demonstrably works here); and Medusa 1.5.1 **cannot compile the target** in this environment (unresolved `@openzeppelin/...`, `pauser/...`, `./INudgeStreamer.sol`). The figures "200,310 calls / 2,001 sequences / 23-of-23 properties / 0 failures" have **no supporting artifact** and appear to be arithmetic on `testLimit: 200000` / `callSequenceLength: 100`.
- **My own failure, stated plainly:** I relayed "452,000+ calls across two independent engines" and "machine-confirmed on two engines" to the user as fact. That was unverified. The number was load-bearing in how I justified the Leg-B kill.
- **Effect on conclusions: NONE — but the support is narrower than I claimed.** The kill rests on the Halmos inductive proof plus the Foundry campaign, both reproduced. Medusa was corroboration, not load-bearing. Corrected framing everywhere: **~640,000 fuzzed calls on ONE engine plus a reproduced symbolic proof.** All claims of two-engine agreement are withdrawn.
- **Minor discrepancies recorded:** no-brick test shows 9 paths in `symbolic-results.json` vs **10** live; the report's "200,000 calls/invariant (2000x100)" does not match the **128,000** reproduced at repo defaults.
- **Artifacts corrected:** `tier3/invariants.md` carries a verification banner and its Medusa section is marked RETRACTED (pre-correction copy at `tier3/invariants.md.preverify`); `submissions/qa-report.md` and `submissions/spec-conformance.md` had their two-engine / 452k claims replaced with the corrected single-engine figures.
- **Process lesson:** a subagent's *self-reported* tool output is not evidence. Halmos and Foundry left reproducible artifacts and survived; Medusa left only a config and did not. Future runs should require a results artifact (corpus dir or results JSON) per engine before any campaign figure is quoted, and the orchestrator should spot-reproduce at least one load-bearing test per tier.
