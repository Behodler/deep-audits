# Intent — `dev` (phoenix-phase-2-staging @ f929b5b)

**Entry point:** `npm run dev`
**Chain:** anvil, chainId 31337, `http://localhost:8545`. **Never mainnet.**
**Diff base:** `1d8a3a7..f929b5b` (9 commits, **zero `[story-NNN]` tags`).

```
npm run clean:local && npm run start:anvil \
  & sleep 3 && LOCAL_PROMO_KENDU=true npm run deploy:local \
  && ./simulate-yield.sh && npm run extract:addresses \
  && npm run generate:ts-anvil && npm run serve
```

`&` binds looser than `&&`: this is **two** pipelines, not one. Pipeline A (`clean:local && start:anvil`)
is backgrounded and its exit status is discarded; pipeline B is the foreground chain, gated on nothing but
`sleep 3`.

---

## Stated purpose

Authoritative source is **story 003 — "Local Anvil deployment orchestration"** (`complete/phStaging2-local-deploy/`),
whose acceptance criteria are quoted verbatim below. The `//local-deploy` package.json comment
("Story 003 — local Anvil deployment orchestration") is the author's restatement of it; `dev` itself carries
no doc-comment of its own.

- [x] "Running `yarn dev` starts Anvil, deploys all contracts, and serves API on port 3001" — **MET** (empirically; see side-effects.json)
- [x] "GET http://localhost:3001/contracts returns all deployed contract addresses" — **MET after a full `dev`**, but see L-`local.json` finding: **FAILS standalone**
- [x] "GET http://localhost:3001/health returns success response" — **MET, but vacuously**: `/health` returns HTTP 200 `"status":"ok"` even when `/contracts` 404s
- [x] "GET .../contracts/Phlimbo returns Phlimbo contract address" — MET
- [x] "progress.31337.json contains deployment and configuration status for all contracts" — MET (72 contracts)
- [x] "All mock contracts implement required interfaces for Phase 2 integration testing" — MET (`forge build` green)
- [x] "Deployment sequence follows IntegrationChecklist.md ordering" — MET

## What `dev` is a REHEARSAL of

This is the load-bearing question for this entry point. `dev` is not merely a dev-stack boot; it is the
**local mirror of the mainnet promotion-ready cutover**, and its output is read as *evidence about mainnet*.
Its own source says so, at `script/DeployMocks.s.sol:95`:

> "…`DeployMainnetPromotionReady.s.sol` so the local `_setDesiredAPYTwoStep` and the mainnet one are the
> same code operating through the same interface."

What it rehearses, and how faithfully:

| Mainnet shape | `dev` at HEAD | Faithful? |
|---|---|---|
| PhlimboV2 → V3 cutover (story 076 Phase 4e) | Phase 7.4, chunked `migrate`, completeness gate, mint-authority handover | yes |
| Dispatcher swap `pull → setDispatcher → setHook → replaceDispatcher` (story 079 / L-01) | Phase 7.6, index 1 | yes — **L-01's fix landed** |
| Terminal residual-privilege revoke (story 079 / L-04) | `_sweepResidualPrivileges`, last statement before `stopBroadcast`, + declarative end-state ACL table | yes — **L-04's fix landed** |
| Kendu promo **DORMANT** on day one (story 076: "No `startPromotion` call anywhere") | **ARMED**, and the dormant leg is **unreachable through `dev`** | **NO** — see finding `pps28l1` |
| NudgeStreamer: USDC stream only | armed leg registers + seeds phUSD and Kendu too | deliberate, documented divergence |

The script is unusually honest about the divergence — `DeployMocks.s.sol:1984`:

> `///      Do not read the armed leg's behaviour as a prediction of mainnet's.`

…which is precisely why pinning `dev` to the armed leg matters: `dev` is the only entry point most
developers ever run, and it is pinned to the leg its own author says must not be read as a prediction.

## Declared pre-conditions

`DeployMocks.run()` declares **almost none**. Explicitly:

- `vm.envUint("ANVIL_PRIVATE_KEY")` (`:387`) — **required, and not exported by the `dev` key or by any
  `.envrc` in the submodule.** Documented only in the project `CLAUDE.md:476`. Absent ⇒ the chain aborts at step 2.
- `vm.envOr("LOCAL_PROMO_KENDU", true)` (`:398`) — optional; `dev` **hardcodes it to `true`**.

**Not declared, and materially absent:**

- **No `require(block.chainid == 31337)`** — only `console.log("Chain ID:", block.chainid)` at `:392`.
  This is standing ledger finding `L-02 ce524709d965` (open).
- **No genesis-freshness assertion** (e.g. `require(vm.getNonce(deployer) == 0)`). This is the gap that
  actually matters, and it is *not* the same gap as L-02 — see `pps28h?`/`pps28m1`: a stale anvil is
  **also** chainId 31337, so the L-02 fix as filed would not catch it.
- **No anvil readiness probe** — `sleep 3`, no `cast block-number` poll, no port check.
- **No port-ownership check** — nothing verifies that the anvil answering on 8545 is the one pipeline A started.

## Declared post-conditions

These are genuinely good where they exist, and are the script's strongest feature:

- `_sweepResidualPrivileges` (`:1917`): `phUSD.setMinter(deployer,false)` then a **declarative end-state ACL
  table** — `_requireLiveMinter` × 10, "deployer + PhlimboV2 OUT, V3 + minter + staker + 5 hooks IN".
- Phase 7.6 `_rehearseDispatcherSwap`: conservation gate on `hook.pull()` —
  `"CONSERVATION FAILED: the phUSD realised by hook.pull() does not equal the mint debt it retired - do NOT relax this gate"`.
- `_armLocalKenduPromotion` (armed leg only): 4 `require`s incl. `promoRewardBalance() == LOCAL_PROMO_KENDU_AMOUNT`.
- Dormant leg: `promoToken() == address(0)`, `promoRewardBalance() == 0`.
- `_seedNudgeStream`: `require(received == amount, "nudge seed token is fee-on-transfer: ...")` — a real
  fee-on-transfer probe. **Armed leg only at HEAD** (see `pps28l4`).

All of them assert the **end state**. **None** of them assert anything about the *chain they ran on*.

## Law-2 grading (stories in `closure-manifest.json.storyDocs[]`)

Enumerated the complete tree: `find ~/code/product-owner/stories/phStaging2 -type f -name '*.md' | wc -l` → **81 files**,
all states (`complete/`, `auto-complete/`; there is no `incomplete/`, `review/` or `archive/` under phStaging2),
all sprint folders. Highest number is **080**.

| Work shipped in this delta | Story | Verdict |
|---|---|---|
| `StableStaker` → `StableStakerV1` retype; antimatter submodule | 080 (prep) | 080 names `f929b5b` as its base; **unmerged** on `sprint/stable-staker-v2` |
| Gating the phUSD/Kendu nudge streams on `LOCAL_PROMO_KENDU` | 079 | **CONTRADICTS 079**, which states verbatim: "**Do NOT gate the Kendu nudge stream.** `_seedNudgeStream` … stays unconditional." |
| `LOCAL_PROMO_KENDU=true` added to the `dev` key | 079 | **CONTRADICTS 079's own checklist**: "Confirm no mainnet script, no `src/` contract and no **`package.json` key** was modified" |
| OpenZeppelin top-level v5.6.1 pin + 9 canonicalization remaps | — | **THE STORY DOES NOT EXIST.** `5.6.1` appears nowhere in the tree; no story mentions an OZ pin, version or remapping change. 080 neither authorises nor presupposes it. |
| `script/archives/**` sweep (108 files) + `skip` directive | — | **THE STORY DOES NOT EXIST.** The only archives mandate anywhere is 080's two-file `git mv` *out* of archives, which says "Do not touch them; they are mainnet history" and explicitly **rejects** removing the skip. |
| Deletion of ~170 (measured: **246**) package.json keys | — | **THE STORY DOES NOT EXIST.** No story mentions a purge. 075 *adds* `promotion-ready:verify`; nothing anywhere authorises removing it. |

This is an absence of acceptance criteria for shipped work, established by full enumeration — **not** an
unavailability of external documents. It compounds standing ledger entry `Q-01 1c98937375ad` (open), which
already records that the "story 079" baseline has no acceptance criteria to be graded against.

## Terminating success signal

**There is none.** `npm run serve` (`node server/index.js`) blocks forever. `dev` therefore has no exit-0
success condition: a developer judges success by reading console output. Ctrl-C kills the foreground server
but **leaves pipeline A's anvil running** — which is exactly the stale-anvil precondition for the next `dev`.
