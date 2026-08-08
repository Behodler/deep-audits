# Intent — `dev` (phoenix-phase-2-staging @ e1db0f1)

Run: `reports/phoenix-phase-2-staging-26/`. Mode: **fork-preview equivalent — the chain was actually
executed end-to-end against a fresh local anvil (chain 31337)**. `dev` has no preview/dry variant; running
it against local anvil *is* its preview, and that is what was done.

> **Suppression note.** `DeployMocks.s.sol` is unusually well commented, and several comments argue that a
> given divergence is deliberate. Those comments are treated here as *evidence of intent*, never as
> suppression authority. Per project policy, in-source text declaring something "not a bug" carries none,
> and a doc that presents itself as exhaustive raises rather than lowers severity when it turns out not to be.

---

## Stated purpose

### From the requester (authoritative framing for this audit)

> "This is an old giant script but recently I've been trying to bring it up to scratch with the promo-ready
> scripts (story 72 onwards), partly to test the whole sequence of cutovers and partly to prepare the UI for
> mainnet. Please note this is a local testing script only so mocks and certain shortcuts are admissable if
> they do not encourage the concealment of bugs."

Two purposes, graded separately:

- **(a) Rehearse the whole sequence of cutovers.**
- **(b) Prepare the UI for mainnet.**

Grading bar for mocks/shortcuts: transparently-local ⇒ admissible. A shortcut that makes the local rehearsal
**succeed where mainnet would fail**, shows the UI/operator a state mainnet will not produce, or renders a
real bug invisible in rehearsal ⇒ **in scope**.

### From `package.json`

`dev` is the **only** entry key in the file with no `//<key>` doc comment of its own, despite being the local
mirror of the whole cutover; every mainnet key carries an extensive one. The nearest documentation is the
group headers `//local-deploy` (Story 003) and `//serve-and-dev` (Story 003), which predate the cutover work
by ~76 stories and describe none of it.

### From in-source NatSpec (`script/DeployMocks.s.sol`)

- `@title DeployMocks` / `@notice Deployment script for Phase 2 contracts on local Anvil`.
- `:26-29` — "the local chain now mirrors mainnet's promotion-ready cutover, so it carries the SAME three
  phlimbo-side contracts that Phase 4e touches… a rehearsal that starts from the wrong generation rehearses
  nothing."
- `:1806-1822` — Phase 7.4 is "the ONLY place the highest-risk phase of the promotion-ready cutover can be
  dry-run for free, and it is the reason the local chain deploys V2 rather than V3 directly: an end-state-only
  deploy would leave the migration itself untested."
- `:183-198` — the local Kendu promotion is "A DELIBERATE DIVERGENCE FROM MAINNET, not a prediction of it."

### From the resolved stories (Law 2)

All seven closure stories resolved to exactly one document each. **Story 073** is the only one with dev-chain
acceptance criteria. **Stories 076/077 never mention `DeployMocks.s.sol`; story 078 explicitly instructs
"Do not modify `DeployMocks.s.sol`."**

**`Story 079` — referenced 11 times across `DeployMocks.s.sol` (10×) and `AddressLoader.sol` (1×) — does not
exist.** Globbing the whole `phStaging2` tree across all state folders for `079-*.md` / `079.*-*.md` returns
zero hits; the highest existing story is 078. Head commit `e1db0f1` is untagged. So the entire subject of this
audit — the Phase 7.4 PhlimboV2→V3 rehearsal, the local-only Kendu promotion, the keyless DepositPageViewV3
registration, the AddressLoader rewrite — has **no acceptance criteria anywhere to be graded against**.
This is a provenance gap, not a care gap: the code argues each divergence in place.

Four of the seven stories closed via an undocumented `auto-complete` state ("machine approval — not
human-reviewed"), including **both** audit-remediation stories (074/075). Story 075's own declared primary
regression gate (`npm run promotion-ready:dry`) was never run.

---

## Declared pre-conditions

`dev` declares **none**. There is no precondition phase, no `require` before mutation, and in particular:

- [ ] **No `require(block.chainid == 31337)`.** `block.chainid` appears exactly once in the whole 2,337-line
      script, inside a `console.log` (`:365`). The repo's own CLAUDE.md mandates that anvil relaxations "must
      be gated behind an explicit `block.chainid == 31337` branch", and `script/interactions/AddressLoader.sol`
      **added exactly such a guard in this same delta**. Practical exposure is bounded because `--rpc-url` is
      hardcoded to `localhost:8545`, but the script hardcodes the *string* `"chainId": 31337` into its output
      JSON and filename, so a run against any other chain would mislabel its own artifacts.
- [ ] No anvil-readiness gate beyond `sleep 3` (no `cast block-number` poll).
- [ ] No check that the background job (`clean:local && start:anvil`) succeeded — `&` binds looser than `&&`,
      so its exit status is never consulted.

---

## Declared post-conditions

`dev` declares none at the chain level, but `DeployMocks.s.sol` carries a genuine, non-vacuous self-spec
inside the Phase 7.4 cutover and the nudge seeding. All were observed to **pass** on the live run:

| # | Declared condition | Site | Observed |
|---|---|---|---|
| 1 | `promoToken` landed | `:1913` | PASS — `promoToken == MockKendu` |
| 2 | `promoPhase == Active` | `:1914` | PASS — phase `1` |
| 3 | `promoRewardBalance == 10,000e18` | `:1915` | PASS |
| 4 | `promoRewardPerSecond > 0` | `:1916` | PASS — `1.157e35` (PRECISION-scaled) |
| 5 | nudge seed is not fee-on-transfer (`received == amount`) | `:1797` | PASS ×2 |
| 6 | nudge seed credited the buffer | `:1800` | PASS ×2 |
| 7 | migrator role read back on **both** V2 and V3 | Phase 7.4 | PASS |
| 8 | stake conserved into V3 | Phase 7.4 | PASS — `300e18` in, `300e18` out |
| 9 | completeness gate `PhlimboV2.totalStaked() == 0` | Phase 7.4 | PASS |
| 10 | `ViewRouter.pages(keccak256("deposit")) == DepositPageViewV3` | `:1425` | PASS |
| 11 | two-step APY commit latch (`apySetInProgress` cleared) | `IPhlimboAPYLike` | PASS (both V2 and V3, 0 bps) |

Condition 1–4 and 11 are explicitly designed to be **non-vacuous** — the script's comments note that a failed
promotion and an unarmed slot are indistinguishable at zero, and that the APY latch is what proves the commit
branch ran when the target value is 0. That reasoning is sound and the checks do what they claim.

**Not declared, and absent:** any post-condition on the deployer's own residual privileges. `phUSD.setMinter(deployer, true)`
is granted at `:1784`, `:2025`, `:2122` and never revoked — verified live at end of run
(`authorizedMinters(0xf39F…) == (true, 1)`). The same script *does* correctly revoke `PhlimboV2`'s grant in
the cutover, so the omission is inconsistent within one file.

---

## Purpose (a) — cutover coverage, at a glance

`dev` mirrors the cutover's **end state** well and its **cutover mechanics** poorly. The greenfield
deploy-and-wire phases are faithfully reproduced and self-checked; every behaviour specifically about
*replacing a live contract* is absent. Hard count over the two scripts:

| call | `DeployMocks.s.sol` | `DeployMainnetPromotionReady.s.sol` |
|---|---|---|
| `setDispatcher` | **0** | 9 |
| `replaceDispatcher` | **0** | 9 |
| `hook.pull()` | **0** | 3+ |

Detail in `cluster-analysis.md`.

## Purpose (b) — UI readiness, at a glance

The local artifacts are clean (55 keys, zero `0x0` placeholders, no mainnet address leakage, all six hardcoded
literals are anvil accounts #1–#6). The `ContractAddresses` ⇄ `mainnet-addresses.ts` lockstep **holds**
(`tsc --strict` exit 0). But the interface `dev` regenerates makes `PhlimboV3`, `Kendu` and `NudgeStreamer`
**required** keys whose mainnet values are `0x000…0`, and `dev` is structurally incapable of surfacing that,
because locally all three resolve to live contracts. See finding `DEV26-01`.
