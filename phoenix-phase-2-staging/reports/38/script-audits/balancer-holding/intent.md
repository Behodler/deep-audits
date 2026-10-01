# Intent — balancer-holding (RevokeBalancerPoolersHoldingPattern / VerifyBalancerHolding)

Source commit `a309040` (master). Story: **phStaging2:099** — `~/code/product-owner/stories/phStaging2/review/phStaging2-Balancexit/099-revoke-balancer-poolers-holding-pattern.md`
(state **review/**, Review Status **ISSUES_FOUND** 2026-10-01T02:06:08Z — the code has landed while the story is not closed).
Commits: `54189f4` (script, verifier, fork test), `a309040` (npm keys). Plan: `docs/BalancerWinddownPlan.md` §4 "Holding pattern until the cutover" (`3943ae3`).
Downstream consumer: phStaging2:103 (incomplete/) — gate `holding-broadcast` + cutover step 0 precondition.

## Stated purpose (story 099 = authoritative; plan §4; NatSpec/`//BalancerHolding` = author restatement)
- [x] ONE owner tx, `BalancerPoolerV2(0x7f68…11F1).incrementAuthVersion()`, revokes all four authorized poolers (OWNER `0xCad1…D0B6`, MultiPooler `0xd1E5…7b51`, `0x186c…a77F` (EIP-7702 delegated EOA), `0x6309…d476`) — **fork-verified** (side-effects.json, `test_r38_01`).
- [x] Afterwards nobody (of the four) can `pool()` sUSDS into the dying Balancer pool — **fork-verified** with sUSDS actually present on the pooler (`test_r38_04`, `test_r38_06`).
- [x] Mints are unaffected; sUSDS accumulates on the pooler — **fork-verified through a real `NFTMinterV2.mint(4, …)`**, not just a pranked `dispatch` (`test_r38_04`): 17.8815 USDS → 16.0907 sUSDS parked on 0x7f68, 8.9408 phUSD mint debt accrued (50%), 0 BPT minted, no `Pooled`.
- [x] Idempotent: if all four are already unauthorized, nothing is sent — **fork-verified** (`test_r38_03`: 0 storage changes, 0 events on second run).
- [x] Changes no addresses → no mainnet-addresses backup/patcher tail (confirmed in package.json).
- [x] `:verify` is read-only and fails `verify: pooler still authorized` until the broadcast lands — **verified live** (forge exit 1 today; all four "STILL AUTHORIZED") and passes in the simulated post-broadcast world (`test_r38_02`).
- [x] Required precondition for story 103 step 0 (see cluster-analysis.md for the gaps in how 103 consumes it).

## Story-099 checklist graded (Law 2)
| Checklist item | Grade | Evidence |
|---|---|---|
| Fork test written first: after revocation each of the 4 `pool()` reverts with the auth error; NFTMinter dispatch at index 4 still succeeds; skips without RPC | **Met** (ordering not provable — same commit) | upstream test 4/4 PASS with RPC, 4/4 SKIP without (`test/audit-run38/upstream-fork-test.log`). Dispatch is tested by `vm.prank(NFTMinter).dispatch`, which the story explicitly permits; run-38 adds a real-mint test that confirms it. |
| Script calls `incrementAuthVersion()` on 0x7f68, PREVIEW_MODE convention, preview asserts all four unauthorized "read the same way `onlyAuthorizedPooler` checks" | **Met** | `_isAuthorized` (L77-79) is byte-for-byte the modifier predicate (BalancerPoolerV2.sol L136-139). |
| Read-only verify entry point | **Met** | `VerifyBalancerHolding.run()` is `view`. |
| npm keys + `//BalancerHolding` citing story 099, Ledger flags as template, no backup/patcher tail, `&& verify` tail | **Met** | package.json; HD path identical to the other 3 Ledger keys signing as 0xCad1. |
| `forge build` passes | **Met** | workspace builds. |
| `forge test` passes (full suite) | **NOT met as written** | 54 pre-existing failures (stable-staker-v2-cutover progress file vs live mainnet); story review already records ISSUES_FOUND. Not introduced by 099. |
| Preview runs clean, shows version bump and all four unauthorized | **Met** | `test/audit-run38/preview.log`. |
| Commits `[story-099]`, explicit paths | **Met** | `54189f4`, `a309040`. |
| HUMAN ACTION block | **Met in story; action outstanding** | live `authVersion == 1` at block 26,094,460 — nothing broadcast. |

Required Human Action (verbatim in story): (1) broadcast before 30 Oct 2026 then `:verify`, record tx hash as story-103 `holding-broadcast` gate evidence; (2) extension decision by 16 Oct; (3) contact `0xc65f…e8db` LP owner. Items 2–3 are outside this script.

## Declared pre-conditions (require before the state change) — RevokeBalancerPoolersHoldingPattern.run()
- `block.chainid == 1` (L104)
- `BALANCER_POOLER_V2.code.length > 0` (L105)
- `owner() == OWNER` (L106)
- Implicit gate: `_countAuthorized() > 0` over the **four hardcoded** addresses, else return with no tx (L116-119)

## Declared post-conditions (require after the state change; run locally in both preview and broadcast)
- `authVersion == before + 1` (L138)
- for each of the four: `poolerAuthVersion[p] != authVersion` (L139-142)

## Verifier (VerifyBalancerHolding.run(), file L17-31)
- `block.chainid == 1`
- for each of the four hardcoded addresses: `!_isAuthorized(p)`
- Does **not** assert `authVersion() > 1`, does not consider any address outside the four, cannot see a later `setAuthorizedPooler(x, true)` for x ∉ four (fork-verified, `test_r38_08`).

## Gaps between story and restatement
- NatSpec L14-15 and plan §4 attribute `0x186c`/`0x6309` to `WhitelistPoolersV2`; on chain their 0x7f68 grants are OWNER `Temp.s.sol` txs (`cb56e196…`, `bf66c239…`); WhitelistPoolersV2 targeted the older pooler `0x26F8…b38A` (and also `0x3E90…Eb28`, which is NOT authorized on 0x7f68). Story 099 itself states the correct provenance. Informational.
