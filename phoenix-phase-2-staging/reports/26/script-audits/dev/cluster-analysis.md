# Cluster analysis — `dev` vs the promotion-ready cutover suite

**This is the heart of purpose (a): "test the whole sequence of cutovers."**

Method: every promotion-ready / cutover sibling from story 072 onwards is graded MIRRORED / PARTIAL / OMITTED
against what `dev` actually executed on the live anvil run (`evidence/dev-script-narrative.log`, 25 phases,
381 broadcast transactions, 70 contract creations, 0 reverts). For each gap, the question answered is not
"is a step missing" but **"what class of bug is the local rehearsal therefore blind to?"** — because a
rehearsal that cannot fail on a defect is a rehearsal that conceals it.

**Sanctioned divergences are excluded from the gap list.** Story 072/073 explicitly declare these and they
are NOT reported as defects: the 6-hour stream window vs mainnet's 7 days; three streams locally vs USDC-only
endogenous funding on mainnet; phUSD/Kendu seeded by a synthetic deployer-donor; two coexisting batch-minter
ABIs; the flat 90% rehearsal budget move; `--gas-estimate-multiplier 300`.

---

## The headline number

| call | `DeployMocks.s.sol` | `DeployMainnetPromotionReady.s.sol` |
|---|---|---|
| `setDispatcher` | **0** | 9 |
| `replaceDispatcher` | **0** | 9 |
| `hook.pull()` | **0** | 3+ |

Every mechanism the mainnet script uses to *replace a live dispatcher* is executed zero times locally.
Verified on-chain: `NFTMinterV2.nextIndex == 8`, with `configs[1..7]` each populated exactly once and never
repointed (`evidence/cast-live-state.log`).

---

## Per-behaviour grading

| # | Behaviour (mainnet Phase) | Status in `dev` | Blind spot created |
|---|---|---|---|
| a | NudgeStreamer + push→`collectNudge` conversion on all donors | **MIRRORED (superset)** — 3 streams vs mainnet's 1 | none |
| b | Redeploy 4 donor dispatchers (BalancerPoolerV2 idx4 six-arg, Uniboost ×3, NudgeRatchet idx7) | **PARTIAL** — right shapes, right indices, **wrong mechanic**: deployed greenfield, never swapped in | see **G-1** |
| c | BatchNFTMinterMultiToken + USDC/phUSD/Kendu whitelist + `registerStream` | **MIRRORED in shape** | none (config divergence sanctioned) |
| d | NFTStakerDepletion → V2 via NFTStakerMigrator | **FULLY MIRRORED ×3** | none |
| e | Retire the old batch minter (`setPauser(OWNER)` + `pause()`) | **OMITTED** | see **G-2** |
| f | Hooks REPOINTED not redeployed: `pull → setDispatcher → setHook → replaceDispatcher` | **OMITTED ENTIRELY** | see **G-1** — the largest gap |
| g | PhlimboV3 + two-step APY + mint grant + MigratorV2V3 + V2 wind-down | **FULLY MIRRORED** + local-only addition | see **G-5** (the addition) |
| h | DepositPageViewV3 + `setPage("deposit")` | **FULLY MIRRORED**, including the displacement | none |
| k | Story 074 write-once BPT custody baseline across resume legs | **NO ANALOGUE** | see **G-3** |
| l | Story 075 standalone post-broadcast verifier (`VerifyPromotionReady.s.sol`) | **NO ANALOGUE** | see **G-4** |
| m | Mainnet preamble: phlimbo-v2 snapshot, staleness gate, backup, address patcher | **NO ANALOGUE** | see **G-3** |

---

## G-1 — The dispatcher-repoint ordering is not rehearsed at all *(largest gap)*

`DeployMainnetPromotionReady.s.sol:145-156` documents the per-index order and states the failure mode in its
own words:

> `hook.pull()  ->  hook.setDispatcher(new)  ->  new.setHook(hook)  ->  replaceDispatcher(idx, new)`
>
> "During the window between `setDispatcher` and `replaceDispatcher`, the OLD dispatcher is still on the index
> but the hook now rejects it … so mints on that index REVERT. That is the correct failure direction.
> **The reverse order would put the new dispatcher live on the index while it still carried the fresh
> `DefaultDispatchHook` that `ATokenDispatcherV2`'s constructor gave it, so mints would SUCCEED while accruing
> no mint debt — a silent value leak. Never do that.**"

The riskiest ordering in the entire cutover — the one whose wrong direction is *silent* rather than
loud — is executed **zero times** on the local chain. The local chain has no incumbent to displace: it
deploys the post-cutover dispatcher set greenfield.

**Blind to:** (i) a reordering regression in the mainnet script's per-index sequence; (ii) the hook-identity
guard `NudgeRatchet._dispatch`'s `hookTypeId() == EXPECTED_HOOK_TYPE_ID`, which only bites when a hook is
*reused* across a swap; (iii) the mainnet script's own claim that `replaceDispatcher` preserves
`price`/`growthBasisPoints` (asserted at `:1366-1372` and `:1536`, never exercised locally); (iv) the
non-default `NudgeRatchetMintDebtHook.DEFAULT_RATIO == 100` vs 50 on the other two hook types — a ratio reset
that would only be visible on a repoint.

**Not demonstrated by execution.** Reproducing the reverse-order leak on the live chain would have required
deploying a fresh six-arg `BalancerPoolerV2` plus hook and repointing index 4. That was **not run**, so no
claim is made here about the mainnet script's ordering being wrong — the finding is strictly that `dev`
cannot tell you either way. The absence itself is proven (grep counts + on-chain `configs[1..7]`).

**Fix shape:** a Phase 7.6 that, after the greenfield set is live, deploys one replacement dispatcher and
performs a real `pull → setDispatcher → setHook → replaceDispatcher` on a single index, asserting mint-debt
conservation across the swap. One index is enough to make the ordering executable and therefore testable.

## G-2 — Old-minter retirement is not rehearsed

Mainnet Phase 3 rescues the old batch minter's USDC to OWNER, `collectNudge`s it into the new stream, then
retires the old minter via `setPauser(OWNER)` + `pause()`. `dev` has no incumbent batch minter and no
analogue.

**Blind to:** the rescue-then-donate ordering (rescuing after the streamer is registered vs before), and the
"retired but not bricked" end state. The pot-rescue arithmetic — how much lands in the stream vs stays with
OWNER — is never checked against a real balance.

## G-3 — No resume/idempotency leg, by design; and no snapshot preamble

`DeployMocks` is documented at `:1818-1822` as non-resumable ("every local run is a FRESH leg by
construction"), and writes `deploymentStatus: "completed"` unconditionally, so the local progress file can
**never** record `in_progress` or `failed`. The mainnet counterpart *is* resume-guarded.

**Blind to:** the entire progress-poisoning failure class that story 074 and the `//promotion-ready:resume`
doc treat as the cutover's sharpest edge — a Ledger broadcast dying mid-phase, a stale progress file naming
contracts that were never deployed, and a resumed leg re-deploying or double-migrating. Story 074's
write-once BPT custody baseline exists precisely to survive that, and it is structurally un-rehearsable here.

This is the one gap where the reasoning "a resume branch would be dead code that silently rots" is genuinely
good — but the consequence stands: **the highest-risk failure mode of the mainnet cutover has no local
rehearsal at all**, and no story requires one.

## G-4 — No post-broadcast verifier

Story 075 adds a standalone `VerifyPromotionReady.s.sol` (+326 lines). `dev` has no analogue and never runs
it. Story 075 closed via `auto-complete` (machine approval, not human-reviewed) and **its own declared primary
regression gate, `npm run promotion-ready:dry`, was never run.**

**Blind to:** whether the verifier itself is correct. A verifier that passes vacuously — asserting conditions
that are true regardless — is exactly the class of defect that a rehearsal exists to catch, and the local
chain is the only free place to catch it. `dev` could run the verifier against its own end state at near-zero
cost and does not.

## G-5 — The local chain deliberately shows the UI a state mainnet asserts it is NOT in

`_armLocalKenduPromotion` (`:1902-1921`) arms a 10,000-Kendu / 1-day promotion on PhlimboV3. Verified live:
`promoToken == MockKendu`, `promoPhase == Active`, `promoRewardBalance == 10,000e18`.

Story 076 asserts the exact opposite for mainnet: `promoToken == address(0)`, Kendu deliberately unset, and
Phase 7 asserts the negative.

**Assessment: admissible, but it is the one place the rehearsal deliberately inverts a stated mainnet
invariant.** The justification is sound and argued in place — with no promotion running, every new V3 UI
field (13/16/17/18/19 plus three unclaimable banks on `DepositPageViewV3`) reads zero, which is
indistinguishable from a broken binding. It is also sequenced dead-last so the migrator's `promoToken`-delta
path stays dormant during the migration, which is the careful choice.

**But the inverse is never rehearsed.** No local run produces the *dormant* promo state that mainnet will
actually ship, so the UI's dormant-promo rendering path — the one that goes live on day one — is the one
path `dev` never exercises. Combined with `DEV26-01` (mainnet's `Kendu` key is `0x000…0`), a UI developer
working against `dev` sees an active promotion on a live Kendu token where mainnet will present a dormant
promotion on the zero address. Filed as `DEV26-04`.

**Fix shape:** an env toggle (`LOCAL_PROMO=off`) or a second phase that arms then *ends* the promotion, so
both the active and dormant renderings are reachable locally.

---

## Sibling-script interaction: `AddressLoader.sol` (new coupling this delta)

`script/interactions/AddressLoader.sol` was rewritten this delta from hardcoded literals to
`vm.readFile("server/deployments/local.json")`. Every `interact:*` / `view:*` / `admin:*` / `test:*` key now
structurally depends on `dev` having run. Its own comment records that the old constants had drifted to a
code-less address and "the scripts built on it had been failing silently long before the PhlimboV3 cutover".

Two consequences:

1. **Positive.** This is a real improvement, and `AddressLoader` **added** `require(block.chainid == 31337)` —
   with the rationale "on mainnet that is an approve/transfer to a stranger's contract". The pattern was
   available in this very delta and was not applied to `DeployMocks.s.sol`, which is composed almost entirely
   of anvil relaxations. Filed as `DEV26-05`.
2. **New failure surface.** `clean:local` deletes `local.json`. Every interaction script therefore breaks
   between the clean and the end of `deploy:local`, and — because `clean:local` does **not** delete the `.ts`
   outputs — the JSON consumers fail loudly while the TypeScript consumer (the external UI, purpose (b))
   silently keeps stale addresses. Verified: after `clean:local`, `local.json` and `progress.31337.json` are
   gone and `/contracts` returns HTTP 404 and `deploymentsLoaded:false`, while `local-addresses.ts` is
   byte-identical (`sha c8e0355fbc73`) and still names `PhlimboV3` at `0xC32609C9…`. Filed as `DEV26-02`.

---

## Verdict

`dev` is a **good end-state rehearsal and a poor cutover rehearsal**. Everything greenfield (a, c, d, g, h) is
faithfully reproduced and — notably — genuinely self-checked, with non-vacuous post-conditions that the run
confirmed pass. The un-storied "Story 079" work is correct on its own terms.

But its stated purpose (a) is *the sequence of cutovers*, and the three behaviours that define a cutover as
distinct from a deployment — **repointing a live dispatcher (G-1), retiring an incumbent (G-2), and surviving
a half-finished broadcast (G-3)** — are exercised zero times. The script's structure explains why: the local
chain has no incumbents. That is a reason, not a remedy, and G-1 is cheap to fix on one index.
