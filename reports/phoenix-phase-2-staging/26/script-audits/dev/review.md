# Script Review — `dev`

**Project:** phoenix-phase-2-staging
**Entry point:** `dev` (`package.json`)
**Commit:** `e1db0f1ca67f878f0f1a109fefc0319c8883bbba` (`e1db0f1`), branch `master`
**Baseline:** `3fb4e34` (`entryPointBaselines.dev`, set by run-21)
**Run:** `reports/phoenix-phase-2-staging/26/`
**Mode:** `/audit-script`, regression (per entry point), with full empirical execution

**Result: 0 High, 0 Medium, 4 Low, 1 QA.** Five prior ledger entries were re-observed and all remain open;
one `fix-pending` Medium replayed as *likely fixed* and is proposed — not applied — for closure.

This document is the narrative supplement. The scored artifacts are
[`../../findings/low/`](../../findings/low/), [`../../findings/qa/`](../../findings/qa/),
[`../../submissions/qa-report.md`](../../submissions/qa-report.md) and
[`../../submissions/spec-conformance.md`](../../submissions/spec-conformance.md). No
`submissions/<label>.md` files are owed this run, and their absence is affirmative rather than
accidental: those are minted per High/Medium finding and there are none.

---

## 0. The frame this review is graded against

The requester's own words are load-bearing and are quoted here because every judgement below turns on them:

> "This is an old giant script but recently I've been trying to bring it up to scratch with the promo-ready
> scripts (story 72 onwards), partly to test the whole sequence of cutovers and partly to prepare the UI for
> mainnet. Please note this is a local testing script only so mocks and certain shortcuts are admissable if
> they do not encourage the concealment of bugs."

That sets two purposes, graded separately throughout:

- **(a) rehearse the whole sequence of cutovers**
- **(b) prepare the UI for mainnet**

And it sets a dividing line that is applied to every candidate in this run:

> **Admissible:** a shortcut that is *transparently local* — a mock token, an anvil test key, a compressed
> stream window, a synthetic donor. These are non-findings and were filtered as such.
>
> **In scope:** a shortcut that makes the local rehearsal **pass where mainnet would fail**, that shows the
> UI or the operator **a state mainnet will not produce**, or that renders **a real bug invisible** in
> rehearsal. That is the concealment bar, and it is the bar every finding below clears.

The inverse error was guarded against too: nothing was downgraded on the grounds that "it's only a test
script." All four Low grades rest on demonstrated blast radius, not on the artifact's status.

One more standing rule, applied and worth stating: `DeployMocks.s.sol` is unusually well commented and
several comments argue a given divergence is deliberate. **Those comments are evidence of intent and carry
no suppression authority.** Three such comments were encountered — the Kendu arming at
`DeployMocks.s.sol:183-198`, the `0x0` placeholder convention in `mainnet-addresses.ts`, and the
zero-streamer sentinel at `BatchNFTMinterMultiToken:198-203` — and **none of them was used to remove a
finding.** A comment records what the author did, not what they were asked to do.

---

## 1. What was actually run

`dev` is the only entry key in this `package.json` with **no preview, dry or non-broadcasting sibling**.
Every mainnet key can be rehearsed; this one cannot. Running it against a fresh local anvil *is* its
preview, so that is what was done — a real, complete, end-to-end execution from the writable
`workspace/` clone, never from `lib/`.

| | |
|---|---|
| Command | `npm run dev` (full chain, clean workspace) |
| Chain | local anvil, chain id **31337** |
| Wall clock | ~15 minutes, ending in the intended long-lived state |
| Phases completed | **25** |
| Blocks mined | **865** |
| Broadcast transactions | **381** |
| Contract creations | **70** (+6 factory-created UniV2 pairs) |
| Reverts | **0** |
| Terminal state | API listening on `:3001`, anvil still mining |

All eight steps of the chain succeeded, including the two that most often fail silently:
`simulate-yield.sh` produced a **real** observable effect (`MockAutoDOLA.totalAssets` 6000.00 → 8300.00
DOLA — not the silent no-op its structure permits), and `extract:addresses` mapped 72 progress keys to 55
flat contracts with the four zero-address checkpoint markers correctly dropped.

**The script's eleven self-asserted post-conditions all passed, and they are not vacuous.** This deserves
credit: the script's own comments reason explicitly that a failed promotion and an unarmed slot are
indistinguishable at zero, and that the two-step APY latch is what proves the commit branch ran when the
committed value is `0`. That reasoning is correct and the checks do what they claim. Verified passing:
`promoToken` landed, `promoPhase == Active`, `promoRewardBalance == 10,000e18`, `promoRewardPerSecond > 0`,
both nudge seeds non-fee-on-transfer and buffer-credited, migrator role read back on **both** V2 and V3,
stake conserved `300e18` in / `300e18` out, completeness gate `PhlimboV2.totalStaked() == 0`,
`ViewRouter.pages(keccak256("deposit")) == DepositPageViewV3`, and the APY latch cleared on both contracts.

**No mainnet fork was needed or used.** `dev` is 31337-only; the closure records **zero** `RPC_MAINNET` and
zero Etherscan calls, and the only `--rpc-url` anywhere in the closure is the hardcoded
`http://localhost:8545`. The mainnet RPC liveness probe was green (head block **25698985**), so no
expired-key alert was owed — it simply was not needed. The one `--fork-url` used by this audit points at
`http://127.0.0.1:8545`, i.e. the live *local* anvil from the run above.

### Two precision notes on the evidence

Stated because this review's value is that a reader can tell proven from inferred:

1. **Two of the five live-state fork tests reverted** (`test_A_deployerRetainsPhUSDMintAuthority`,
   `test_E_dispatcherSetIsGreenfieldNotRepointed` — `EvmError: Revert`, an ABI-shape problem in the test,
   not a chain state result). The claims they were written to carry are **not** resting on them: both are
   established instead by direct `cast` reads in
   [`evidence/cast-live-state.log`](evidence/cast-live-state.log) — `authorizedMinters(0xf39Fd6e5…) ==
   (true, 1)`, and `nextIndex == 8` with `configs[1..7]` enumerated. Three tests passed and carry the
   cutover end-state, the UI divergence and the zero-sink acceptance.
2. **The event list is incomplete and is labelled so.** `forge script --broadcast` prints receipts, not
   decoded logs, and the broadcast artifact was consumed by the `clean:local` demonstration. The events
   recorded in [`side-effects.json`](side-effects.json) are inferred from console output plus post-hoc
   storage reads, not from decoded receipt logs. No finding rests on an event count.

---

## 2. Findings register

Ranked by impact within severity. **L-01 leads** — not because it is the largest realised harm today (it
is a coverage gap) but because it has the highest impact ceiling and the clearest next action.

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-01** | Low | The rehearsal reproduces the cutover's **end state** but none of its **cutover mechanics**: `setDispatcher`, `replaceDispatcher` and `hook.pull()` are executed **zero** times locally against 9/9/3+ on the mainnet script. Verified on chain: `configs[1..7]` each populated exactly once, never repointed. | Add a Phase 7.6 that deploys **one** replacement dispatcher and performs a genuine `pull → setDispatcher → setHook → replaceDispatcher` on a single index, asserting mint-debt conservation, `price`/`growthBasisPoints` preservation, and that a mint in the intermediate window **reverts**. Separately, run `VerifyPromotionReady.s.sol` against the local end state — it is free there. | `script/DeployMocks.s.sol` · `run` |
| **L-02** | Low | `clean:local` deletes the JSON artifacts but leaves `addresses.ts` / `local-addresses.ts` stale, so the in-repo JSON consumers fail **loudly** while the external UI — the only consumer purpose (b) cares about — keeps stale addresses **silently**. | Add both `.ts` files to the `clean:local` rm list so an aborted run leaves nothing rather than something stale. If they must survive, have `generate:ts-anvil` stamp a run id into both and have the UI bootstrap assert it against `GET /health` — but deletion is simpler and fails in the safe direction. | `package.json` · `clean:local` |
| **L-03** | Low | The local chain arms a live Kendu promotion on PhlimboV3 (`promoPhase == Active`, `10,000e18`) — the arming is admissible, but the **dormant** state story 076 says mainnet will actually ship is unreachable locally, so the day-one UI rendering path is never exercised. | Make both promo states reachable: gate the call on `LOCAL_PROMO=off`, or add a follow-on phase that arms *then ends* the promotion so one command reaches the dormant/depleted rendering. Keep the four non-vacuous post-condition `require`s — they are correct and must not be relaxed. | `script/DeployMocks.s.sol:1902-1921` · `_armLocalKenduPromotion` |
| **L-04** | Low | The script grants itself `phUSD.setMinter(deployer, true)` at three sites and never revokes it — while correctly revoking `PhlimboV2`'s grant in the same run, which makes the ACL read as swept when it is not. Live at end of run. | Revoke with `phUSD.setMinter(deployer, false)` at the end of `run()` and assert it, mirroring the Phase 7.4 wind-down's own pattern. Better: add a terminal **residual-privilege sweep** phase asserting the full expected end-state ACL, so a future grant that forgets to clean up fails the run. | `script/DeployMocks.s.sol:1784, 2025, 2122` |
| **Q-01** (= **F-01**) | QA | "Story 079" — the attribution on the entire subject of this audit — **does not exist**; and story 078, the one in-scope story that mentions the file, says *"Do not modify `DeployMocks.s.sol`."* | Write the missing story retrospectively and tag it (or re-attribute to a real number), correcting the **22 in-source references across 6 files**; and resolve the story-078 contravention explicitly in writing. Secondarily: document the `auto-complete` state and have a human re-review 074/075, running story 075's never-run gate. | `script/DeployMocks.s.sol` · `run` / `_rehearsePhlimboV3Cutover` / `_armLocalKenduPromotion` |

**No `C-XX` label was issued.** L-04 was the only Centralization candidate and was placed in Low instead:
no protocol asset sits behind the residual key, and calling a local-chain privilege residue a trust
concentration would misdescribe it.

**Why nothing reached Medium.** The live question for this run was whether a *rehearsal* defect can be
Medium. It can — a defect that makes the rehearsal green while the real cutover is broken is a genuine
verification-integrity harm — but only when the causal chain is **demonstrated** rather than hypothesised.
Two candidates were tested against that bar (L-01, L-02) and both fail at the same link: the second step,
*a real defect that the rehearsal would conceal*, is not demonstrated in either case. L-01 disclaims it in
its own record; L-02's demonstrated half stops at a local development UI. Both hold at Low. That is not
report-tidying — both are reported in full, at the top of the bucket, with the mainnet script's own
warning quoted verbatim.

---

## 3. Purpose (a) — rehearse the whole sequence of cutovers

**Verdict: `dev` is a good end-state rehearsal and a poor cutover rehearsal.**

Everything greenfield is faithfully reproduced and genuinely self-checked. But the three behaviours that
distinguish a *cutover* from a *deployment* — repointing a live dispatcher, retiring an incumbent, and
surviving a half-finished broadcast — are executed zero times. The structural reason is honest and stated
in the script itself: the local chain has no incumbents to displace. That is a reason, not a remedy.

### The lead result

| call | `DeployMocks.s.sol` | `DeployMainnetPromotionReady.s.sol` |
|---|---|---|
| `setDispatcher` | **0** | 9 |
| `replaceDispatcher` | **0** | 9 |
| `hook.pull()` | **0** | 3+ |

The mainnet script documents the required order at `:148-150` and states the failure mode in its own words:

> `hook.pull() -> hook.setDispatcher(new) -> new.setHook(hook) -> replaceDispatcher(idx, new)`
>
> "During the window between `setDispatcher` and `replaceDispatcher`, the OLD dispatcher is still on the
> index but the hook now rejects it … so mints on that index REVERT. That is the correct failure direction.
> **The reverse order would put the new dispatcher live on the index while it still carried the fresh
> `DefaultDispatchHook` that `ATokenDispatcherV2`'s constructor gave it, so mints would SUCCEED while
> accruing no mint debt — a silent value leak. Never do that.**"

The riskiest ordering in the entire cutover — the one whose wrong direction is **silent** rather than loud
— is the one the local mirror never executes.

**What is proven and what is not.** The *absence* is proven: grep counts over both scripts, plus the
on-chain enumeration showing `NFTMinterV2.nextIndex == 8` with `configs[1..7]` each populated exactly once
and never repointed ([`evidence/cast-live-state.log`](evidence/cast-live-state.log)). **The leak itself was
not reproduced.** Doing so would have required deploying a fresh six-arg `BalancerPoolerV2` plus hook and
repointing index 4, which was not run. **No claim is made here that the mainnet ordering is wrong** — the
finding is strictly that `dev` cannot tell you either way.

What the rehearsal is therefore blind to: a reordering regression in the mainnet script's per-index
sequence; the hook-identity guard `NudgeRatchet._dispatch`'s `hookTypeId() == EXPECTED_HOOK_TYPE_ID`, which
only bites when a hook is *reused* across a swap; the mainnet script's own assertion that
`replaceDispatcher` preserves `price` and `growthBasisPoints` (`:1366-1372`, `:1536`, never exercised
locally); and the non-default `NudgeRatchetMintDebtHook.DEFAULT_RATIO == 100` against 50 on the other two
hook types — a ratio reset visible only on a repoint.

### Also absent

- **Old-minter retirement.** Mainnet Phase 3 rescues the old batch minter's USDC to OWNER, `collectNudge`s
  it into the new stream, then retires the minter via `setPauser(OWNER)` + `pause()`. `dev` has no
  incumbent and no analogue, so the rescue-then-donate ordering and the "retired but not bricked" end state
  are never checked against a real balance.
- **Resume / progress-poisoning (story 074).** `DeployMocks` is documented as non-resumable and writes
  `deploymentStatus: "completed"` unconditionally, so the local progress file can *never* record
  `in_progress` or `failed`. The write-once BPT custody baseline across resume legs has no local analogue
  and is un-rehearsable by construction. The stated reason — a resume branch would be dead code that
  silently rots — is genuinely good reasoning, and the consequence still stands: the mainnet cutover's
  sharpest failure mode has no local rehearsal, and no story requires one.
- **The standalone verifier (story 075).** `VerifyPromotionReady.s.sol` (+326 lines) is never run locally.
  A verifier that passes *vacuously* is exactly the defect class a rehearsal exists to catch, and the local
  chain is the only free place to catch it. This one is nearly free to fix.
- **The mainnet preamble** — phlimbo-v2 snapshot, staleness gate, backup, address patcher — has no analogue.

### The escalation trigger, recorded deliberately

L-01 becomes **Medium or higher** the moment someone demonstrates an actual ordering defect, or a
hook / `price` / `growthBasisPoints` regression, in `DeployMainnetPromotionReady.s.sol`. That would be a
**new finding at that entry point**, not a re-grade of this one. **Recommendation: the next
`promotion-ready` audit should carry it as an explicit hypothesis to test**, rather than discovering it by
accident.

---

## 4. Purpose (b) — prepare the UI for mainnet

**Verdict: the local half is clean and works; the cross-chain half has a structural blind spot that `dev`
cannot see by design.**

**What is clean, and was checked rather than assumed.** The generated local artifacts carry 55 keys, **zero
`0x0` placeholders**, and **zero mainnet address leakage**. All six 20-byte literals in the script are
well-known anvil default accounts #1–#6, split into two deliberately disjoint actor sets so an NFT-side
reward transfer cannot be mistaken for a phlimbo-side one — no real USDC, no Sky PSM, no Balancer, no
Curve, and notably no owner constant, all of which `DeployMainnetPromotionReady.s.sol` does carry. The
`ContractAddresses` ⇄ `mainnet-addresses.ts` lockstep holds: `tsc --noEmit --strict --skipLibCheck` exits
**0** ([`evidence/tsc-mainnet-addresses.log`](evidence/tsc-mainnet-addresses.log)). The name→address
mapping is **by name** from the progress file, never positional-CREATE matching against broadcast
artifacts — the fragile positional pattern exists only in the mainnet patcher family, and the local path is
on the safe side. `DepositPageViewV3` is correctly keyless, `ViewRouter` is the sole resolution path, and
its `getData` returns a live 23-field tuple.

**The blind spot.** `mainnet-addresses.ts` imports its `ContractAddresses` interface from `addresses.ts`,
and `addresses.ts` is **regenerated from anvil data on every local run**. That interface makes
`PhlimboV3`, `Kendu` and `NudgeStreamer` **required** keys — and on mainnet all three are satisfied by
`0x000…0` (`mainnet-addresses.ts:53, 78, 142`). A `string` cannot distinguish a real address from a zero
one, so the drift guard reads green while three of the newest contracts in the system resolve to
`address(0)`.

`dev` is **structurally incapable** of surfacing this, and that is the point worth carrying forward: on the
local chain all three keys resolve to live, funded contracts — PhlimboV3 holding the 300e18 migrated stake,
Kendu with an armed promotion, NudgeStreamer with three funded buffers. **The rehearsal validates the
address book's *shape* and never its *values*.** The placeholder set has also **grown** since it was first
filed, from two keys to three: the defect is getting worse, not decaying.

This reconciled as a **re-observation of existing ledger entry `3177eed94ecb`**, not a new finding — same
root cause, same file pair, and decisively the same fix. It is not re-scored here. The recommendation is
now sharper than run-21's: add a `scripts/check-mainnet-addresses.js` gate that fails on any `0x0{40}` and
wire it into the `promotion-ready:dry` / `promotion-ready:broadcast` preamble, so the cutover cannot
broadcast against placeholders.

The second purpose-(b) item is **L-03**: a UI developer working against `dev` sees an *active* promotion on
a *live* Kendu token, where mainnet will present a *dormant* promotion on the *zero address*. Both halves
of that mismatch are individually defensible; together they mean the day-one state is the one state never
rendered.

---

## 5. What was rehearsed well

Credit where it is owed, and stated as precisely as the gaps:

- **Greenfield deploy-and-wire is faithful.** The NudgeStreamer plus push→`collectNudge` conversion across
  all donors is a **superset** of mainnet's (three streams to mainnet's one).
  `BatchNFTMinterMultiToken` with USDC/phUSD/Kendu whitelisting and `registerStream` is mirrored in shape.
  `DepositPageViewV3` + `setPage("deposit")` is fully mirrored **including the displacement** — the
  V1-shaped page is registered first and then displaced, exactly as mainnet Phase 4f does it.
- **The staker migration is a genuine rehearsal, not a stand-in.** `NFTStakerDepletion → V2` via
  `NFTStakerMigrator` is fully mirrored, three times over.
- **The PhlimboV3 cutover is the real thing, and it is the reason the local chain deploys V2 rather than V3
  directly.** The script says so at `:1806-1822` — an end-state-only deploy would leave the migration
  itself untested. That judgement is correct and it paid off. Verified live: stake **conserved at 300e18**
  through a chunked two-pass migration (chunk size 2, three actors), `PhlimboV2` drained to **0**, phUSD
  mint authority moved **V2 → V3** (`authorizedMinters(PhlimboV2) == (false, 1)`,
  `authorizedMinters(PhlimboV3) == (true, 1)`), the migrator role set on **both** sides with read-back and
  then revoked on V2, the two-step APY latch committed on both, and V2 deliberately **not** paused so a
  late staker can still exit.
- **These rehearsals have already fed corrections back into the mainnet plan** — which is the whole point
  of having them, and is the strongest argument for closing L-01's remaining gap rather than accepting it.
- **The un-storied work behaves correctly on its own terms.** Q-01 is a provenance finding and must not be
  misread as a correctness one: the code was checked empirically and there is no behavioural deviation, no
  exploit, and no asset at risk.

---

## 6. Shortcuts examined and correctly **not** filed

"We looked and it's fine" is information, so these negatives are recorded rather than left implicit. Each
was tested against the concealment bar and passed it.

**Sanctioned divergences — declared in stories 072/073, deliberately not re-litigated:** the 6-hour local
stream window against mainnet's 7 days; three local streams against USDC-only endogenous funding on
mainnet; phUSD and Kendu seeded by a synthetic deployer-donor; two coexisting batch-minter ABIs; the flat
90% rehearsal budget move (which story 072 itself says not to copy); `--gas-estimate-multiplier 300`.

**True negatives established on direct evidence:**

- **No mainnet RPC is reached by any step of the chain.** The only `--rpc-url` in the closure is the
  hardcoded `http://localhost:8545`. Checked explicitly because it would have been a finding if true.
- **No mainnet address or owner constant leaks into the local script.** All six literals are anvil
  accounts; the local artifacts contain zero mainnet addresses and zero `0x0` placeholders.
- **`simulate-yield.sh` is not a silent no-op on the happy path.** Its structure permits one — it sources
  targets from the progress file with no `cast code` probe, both `totalAssets()` reads are `2>/dev/null`,
  and `cast send` to an EOA-shaped target succeeds as a plain call — but the hazard is reachable only
  through a partially-broadcast deploy, which did not occur. Real before/after values were printed. The
  *coverage* half of the observation (it simulates yield only for the DOLA leg) is folded into L-01, so the
  substantive part is filed, not dropped.
- **The JSON consumers fail loudly, as intended.** `server/index.js` re-reads both files on every request,
  so removing them flips `deploymentsLoaded` to `false` and `/contracts` to 404. That is the safe
  direction; L-02 exists precisely because the **TypeScript** consumer does not share it.

---

## 7. Hypotheses tested and refuted — these are results

### (i) The double `clean:local` deleting the live anvil's tmp state — **refuted, with one branch parked**

`dev` runs `clean:local` twice: once in job 1 before anvil starts, and again ~3 seconds later inside
`deploy:local` — i.e. **after** anvil is up. The second run ends in `rm -rf ~/.foundry/anvil/tmp/*`, which
looked like it would delete the working files of the *running* anvil. The `~/.foundry` leg was added in
this delta (commit `7d3862e`).

**Observed-consequence half: solidly negative.** `~/.foundry/anvil/tmp/` was sampled every 0.5 s for 30 s
spanning **both** `clean:local` runs and was **empty at all 60 samples**
([`evidence/anvil-tmp-watch.log`](evidence/anvil-tmp-watch.log)). Anvil in this invocation — no `--state`,
no `--fork-url` — never writes there. The chain survived: all 381 broadcast transactions landed and it was
still mining at block 799.

**The untested branch is parked, not closed.** Whether a *concurrently running forked* anvil belonging to
another task would have state in that directory was never exercised. A `rm -rf` inside a project script
that reaches **outside the repository into shared per-user state**, with an untested destructive branch,
does not belong only in a refuted list. It is held in the visible channel as **`MR-26-DEV-01`**
([`manual-review.json`](manual-review.json)) — not filed as a finding, because no consequence was observed
and filing on an undemonstrated branch would be overstatement. The resolution is one command: start a
second `anvil --fork-url $RPC_MAINNET --state <dir>` alongside, run `clean:local`, observe. If confirmed,
the fix is to scope the cleanup to the repository and never `rm -rf` a shared user directory the project
does not own.

### (ii) A near-miss false positive, recorded as method

Run-21's `AuditDevStreamerWiring.t.sol` hardcodes that run's addresses and **must** be run with
`--fork-url`. Run un-forked, a `.call()` to a code-less address returns `ok == true` — which reads exactly
like *"the donor accepted `address(0)`"*, a finding that would have been entirely fabricated by the harness.

This is recorded because it is the project's standing vacuous-harness hazard in a new costume: the failure
mode is not a test that fails wrongly but a test that **passes wrongly**. The correction applied here was
to re-run forked with **code-length tripwires in `setUp`**, so the suite cannot pass vacuously. The claim
that survives — that `BatchNFTMinterMultiToken.setNudgeStreamer(address(0))` is accepted while three
buffers are funded — was then confirmed on the live chain with those tripwires in place
([`evidence/live-state-fork-test.log`](evidence/live-state-fork-test.log), `test_D`). Any future re-run
must keep the fork and the tripwires; a green un-forked run is not evidence of anything.

---

## 8. Prior-finding reconciliation

Five prior ledger entries were re-observed at `e1db0f1`. **All five remain open. None was closed, narrowed,
or re-filed under a new fingerprint.**

| Fingerprint | Ledger label | Status | This run's contribution |
|---|---|---|---|
| `3177eed94ecb…` | L-03 | still open | Placeholder set **grew** two keys → three (PhlimboV3 joined Kendu and NudgeStreamer); guard confirmed green over three zero addresses at 55 required keys; new argument that `dev` is structurally blind to it. See §4. |
| `ce524709d965…` | L-02 | still open | `AddressLoader.sol:48` **added** the `block.chainid == 31337` guard in this same delta; `DeployMocks.s.sol` still has `block.chainid` exactly once, inside a `console.log` at `:365`. |
| `a37137b3e369…` | Q-03 | still open | Counts re-measured live: 17 advertised vs 55 served — and the array contains **three affirmatively false** entries naming contracts that exist on no chain (`USDT`, `YieldStrategyUSDT`, `YieldStrategyUSDS`). Story 078 edited this exact array without reconciling the rest. |
| `f7de907d7981…` | M-02 | still open | **First live-chain confirmation** of what was previously reasoned from source: `setNudgeStreamer(address(0))` accepted while three buffers were funded. Funds stranded, not lost — recovery by re-pointing the sink is confirmed possible, so severity holds. |
| `1e8cc0dc58ba…` | L-01 | still open | `_writeProgressFile` still hardcodes `deploymentStatus: "completed"` during forge's local pass. New: this same unconditional write is the structural **cause** of the resume-leg sub-gap inside L-01. |

Two nuances are binding on whoever handles these next.

**`ce524709d965` is a sibling adopting the pattern — NOT an incomplete fix.** This was adjudicated
explicitly and the distinction matters. The INCOMPLETE-FIX signal is defined against an entry previously
marked `fixed` or `fix-pending` that then survived. `ce524709d965` has status `open` and has never been
triaged, so **no patch exists that could be partial** and nothing regressed. What happened is that a
sibling file independently adopted the remedy in the same delta; `DeployMocks.s.sol` was not touched for
this purpose at all. Sending a reader to look for a half-landed patch would waste their time on a patch
that does not exist. The fact is preserved as a **priority** signal, not a fix-status one — the remedy was
demonstrably known, understood and applied by the same author in the same commit, and skipped on the
higher-risk 2,337-line file. Severity holds at Low: exposure is unchanged behind the hardcoded
`--rpc-url http://localhost:8545`, and **severity tracks impact, not culpability.**

**`a37137b3e369` carries a split condition.** Q-03 is two-part — the stale `availableContracts` manifest
**and** open CORS. The CORS half was independently re-verified **live** this run at `server/index.js:2`
and `:11` (`app.use(cors())`, no origin allowlist). Collapsing this run's observation into Q-03 is safe
**only while both halves stay open**. If a future fix derives the array from `local.json` but leaves CORS
bare, **Q-03 is not fixed — split the CORS half into its own entry rather than closing it with the manifest
half.**

One phantom was caught and must not propagate: the prior-entry table handed downstream listed
`f7de907d7986`, which matches **zero** ledger entries. The true entry is `f7de907d7981…`, differing at the
twelfth character. Carrying the `…7986` string forward would mint a phantom entry and orphan the real M-02.

---

## 9. The `fix-pending` Medium — proposed fixed, not fixed

**`a753907e2a4c` — NudgeStreamer credits sent-not-received amounts — replayed LIKELY-FIXED.**

The prior PoC was replayed at `e1db0f1`. The tests **assert the bug exists**, so failure means fixed: three
bug-asserting tests now fail (`test_FIND1_A_bufferOverCreditedVsCustody`, `test_FIND1_B_crossPairDrain`,
`test_FIND1_C_oneTaintedTokenRevertsTheWholeLoop`) while the non-vacuity control
`test_FIND1_D_probeIsVacuousOnNoFeeToken` still **passes**
([`evidence/poc-replay-M01-nudgestreamer.log`](evidence/poc-replay-M01-nudgestreamer.log)). Buffer credit
now equals actual custody at 95,000e18 rather than the sent 100,000e18.

**This is a PROPOSAL ONLY. The status remains `fix-pending` and only a human may close it.** A fix that
merely stops tripping the harness is not a verified fix, and there is a specific reason for extra caution
here: **the fix arrived via the `lib/nft-staking` gitlink bump `d2506c1 → 9611312` — a different repository
from the one under audit.** That is precisely the surface most likely to regress silently on a future
gitlink bump, since nothing in this repo's own history would show the change going away.

A human should verify the `nft-staking`-side change directly and, if satisfied, run:

```
/ledger phoenix-phase-2-staging fixed a753907e2a4c
```

The standing obligation to re-weigh `phoenix-nft-staking` `bfdb50105e` (wont-fix) in light of this
finding's PoC case B is unchanged and still outstanding.

---

## 10. Governance caveats

Stated plainly, because each one bounds how much assurance the rest of this report carries.

**(i) No known-issues suppression was applied, and none was available.** The registry declares
`knownIssuesFile` → `lib/phoenix-phase-2-staging/known-issues.md` with 11 entries. **That file does not
exist at HEAD.** The 11 cached KIs are a registry-only snapshot dated 2026-01-09 that cannot be re-derived
from any artifact in the repository — they are unfalsifiable and carry no suppression authority. Under
Law 1, an unverifiable known-issues list must never remove a finding: suppressing on it risks retiring a
live defect on the strength of a document nobody can read. Zero suppressions were applied on known-issue
grounds. Tracked by watch-note **`KI-24-01`**. There were also no legitimate human-status suppressions
available: all 17 `dev` ledger entries are `open`, `fix-pending` or `fixed` — none is `acknowledged`,
`wont-fix` or `false-positive`.

**(ii) Four of the seven in-delta stories closed via an undocumented `auto-complete` state.** Each carries
*"Approved by: story-batch workflow (machine approval — not human-reviewed)"*, and the folder is outside
the documented `complete|incomplete|review|archive` set. Among the four are **both audit-remediation
stories, 074 and 075** — an audit-remediation story that closed without human review is the weakest link in
exactly the chain this rehearsal exists to strengthen — and **story 075's own declared primary regression
gate, `npm run promotion-ready:dry`, was never run.** Story 078, whose instruction Q-01 turns on, is also in
`auto-complete`. This is metadata, not a scope filter: all seven remain in scope and all were read.

**(iii) `SAN-26-DEV-02` — two `dev` ledger entries have unauditable fingerprints.**
`0b497be32114…` (**open**) and `c294d93f772b…` (fixed) are run-05/06-era entries carrying **no
`rootCauseClass`**, so their fingerprints cannot be reproduced under the documented recipe. The open one is
the live risk: a future re-audit that recomputes rather than matches would **re-file it as a new finding**
and orphan the original. Of the 17 `dev` entries tested this run, 15 reproduce exactly — including all four
re-observation targets and the `fix-pending` Medium — and these two are the only misses. **Recommended fix:
backfill `rootCauseClass` on both without touching the stored fingerprints, and record the backfill.**
Human fix only; rewriting either fingerprint would orphan the entry.

**(iv) In-source comments carry no suppression authority.** Three self-certifying comments were encountered
(§0) and none was used to remove a finding. A document that presents itself as exhaustive raises rather
than lowers severity when it turns out not to be.

---

## 11. Story-079 provenance

Summarised only; the full narrative is
[`../../submissions/spec-conformance.md`](../../submissions/spec-conformance.md) (**F-01**), which is that
finding's primary home and must not be reduced to a bundle line.

The work under audit — the Phase 7.4 PhlimboV2→V3 cutover rehearsal, the local-only Kendu promotion, the
keyless `DepositPageViewV3` registration, the `AddressLoader` rewrite — is attributed to **"Story 079",
which does not exist**. This is stated as a positive result, not a lookup failure: an exhaustive glob
across **all four** state folders for `079-*.md` and `079.*-*.md` returns **zero hits**, and the highest
story in the tree is 078. A case-insensitive sweep of `script/` finds **22 references across 6 files**
(the classified record's figure of 11 came from a case-sensitive grep over two files and stands as its own
statement; the count is corrected **upward** here and the discrepancy disclosed rather than silently
substituted). The introducing commit `e1db0f1` is **untagged**, against a delta base that is tagged in the
project's normal convention.

The aggravating fact is that **story 078 says, verbatim, "Do not modify `DeployMocks.s.sol`."** The very
next commit modified it by roughly a third of its length. Two readings are available — the instruction was
superseded by a decision "Story 079" was meant to record, or it was overlooked — and the artifacts do not
distinguish them. **Both fixes start with the same missing document.**

---

## 12. Proven / inferred / untested

A summary index, so a reader can tell them apart without re-deriving it.

**Proven by execution or direct read:** the full 25-phase run and its 381 transactions with 0 reverts; all
eleven self-asserted post-conditions passing and non-vacuous; stake conservation at 300e18 and V2 drained
to 0; the phUSD mint-authority move V2→V3; the deployer's unrevoked grant; `nextIndex == 8` with
`configs[1..7]` populated once and never repointed; the zero-count of `setDispatcher` / `replaceDispatcher`
/ `hook.pull()` in `DeployMocks.s.sol`; `tsc --strict` exit 0 over 55 required keys with three mainnet
zeros; the `clean:local` stale-`.ts` demonstration by before/after sha256; `setNudgeStreamer(0)` accepted
over three funded buffers; the empty `~/.foundry/anvil/tmp/` at 60/60 samples; the non-existence of story
079 and the 22 in-source references; the live CORS half of Q-03.

**Inferred, not directly captured:** the event list (receipts, not decoded logs — labelled incomplete in
`side-effects.json`); the claim that a stale local `.ts` book would cause a *shipped* UI bug (the
mechanism is demonstrated, the downstream bug is not).

**Untested, and named as such:** whether the mainnet script's dispatcher-repoint ordering is actually
correct (L-01 proves only that `dev` cannot tell you); whether `VerifyPromotionReady.s.sol` passes
vacuously; whether the `rm -rf ~/.foundry/anvil/tmp/*` destroys a concurrently-running *forked* anvil's
state (`MR-26-DEV-01`); and whether the `lib/nft-staking` fix behind `a753907e2a4c` is correct at source
rather than merely absent from the PoC's reach.

---

## 13. Suggested order of action

1. **Add the single-index repoint rehearsal (L-01).** Cheapest change with the largest assurance gain, and
   it converts the mainnet cutover's silent failure mode into something regression-testable.
2. **Run `VerifyPromotionReady.s.sol` against the local end state** — free, and it closes story 075's
   never-run gate at the same time.
3. **Human-verify the `nft-staking` fix and close `a753907e2a4c`**, or leave it `fix-pending` — but decide
   deliberately, since the fix lives in another repository.
4. **Add the `0x0` gate to the `promotion-ready` preamble** (`3177eed94ecb`), so the cutover cannot
   broadcast against placeholder addresses.
5. **Add the two `.ts` files to `clean:local` (L-02)** and **revoke the deployer's grant (L-04)** — both
   one-liners that make the rehearsal fail in the safe direction.
6. **Write, or re-attribute, story 079 (Q-01/F-01)** and resolve the story-078 contravention in writing.
7. **Backfill `rootCauseClass` on `0b497be32114`** without touching its fingerprint (`SAN-26-DEV-02`).
8. **Settle `MR-26-DEV-01`** with one forked-anvil command.
