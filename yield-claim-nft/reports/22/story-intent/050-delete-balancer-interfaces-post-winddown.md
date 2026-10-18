# Delete Balancer interfaces and BalancerPoolerV2 (after wind-down)

Current Sprint: 22

## ⛔ Execution Gate (BLOCKING)
This story must not execute until the human has cleared: `winddown-confirmed`. This means that after 30 Nov 2026 the human has confirmed on-chain that pooler BPT = 0, owner BPT = 0, and the old BalancerPoolerV2 (`0x7f6874332c4629429d70D15f685A8230323F11F1`) is drained and paused.
The human clears it by adding this exact line, filled in, to THIS file directly under this section:
`GATE CLEARED: winddown-confirmed — <date> — <evidence, e.g. audit report path or tx hash>`

## ⚠️ Required Human Action On Completion

phStaging2 must bump its `lib/yield-claim-nft` pin to include this story ONLY after confirming that `forge build` passes in phStaging2 with the new pin. phStaging2 story 107 handles the bump, or notes it as pending. After that, phlimbo-ui UI step U4 (remove the legacy Balancer displays) follows, in the same release that drops the Balancer keys from `ContractAddresses`.

## Story Overview

After the Balancer wind-down is confirmed complete, delete the Balancer-specific code from yield-claim-nft: the Balancer interfaces and `BalancerPoolerV2` with its tests. Refresh stale Balancer comments in the files that mention it.

Repo: `~/code/reflax-mint/yield-claim-nft` (product-owner project `yield-claim-nft`). Paths are relative to the sprint worktree `worktrees/yield-claim-nft/Balancexit/` (branch `sprint/Balancexit`).

Source plan: `docs/BalancerWinddownPlan.md` §4 "After 30 November", in **phStaging2** (`~/code/reflax-mint/phase-2-staging`, master `3943ae3`). Read it with `git -C ~/code/reflax-mint/phase-2-staging show master:docs/BalancerWinddownPlan.md`.

## Background

Plan §4 "After 30 November" (verbatim):

> - Confirm the Balancer Vault holds none of our value: pooler BPT = 0, owner BPT = 0.
> - Delete the Balancer interfaces in `yield-claim-nft` once nothing compiles against them.
> - Update or delete the Balancer-era memory notes.

Plan §2.2 (verbatim row):

> | `NudgeRatchetDelayRelease`, `MintPageView` | Live / superseded | Comments only | No | Refresh comments whenever a file is next touched |

`Uniboost` comments cite `BalancerPoolerV2` as a design ancestor.

By this point:
- UniPoolerV2 (048) is live at index 4 on mainnet, replacing BalancerPoolerV2 (phStaging2 103, broadcast by the human).
- `PromotionUniV2_Eth` Leg A no longer uses Balancer (049).
- phStaging2 106 removed the DeployMocks rehearsal that deployed `BalancerPoolerV2`.
- The cutover ran through `UniPoolerCutoverEscrow` (yield-claim-nft:052, `src/migration/`), consumed by phStaging2:103. The escrow is deployed on mainnet and pinned by phStaging2. It stays (see Technical Details).

## File Locations

| File | Change |
|---|---|
| `src/interfaces/balancer/BalancerTypes.sol` | Delete |
| `src/interfaces/balancer/IBalancerRouter.sol` | Delete |
| `src/interfaces/balancer/IBalancerVault.sol` | Delete |
| `src/interfaces/balancer/IUnlockCallback.sol` | Delete |
| `src/dispatchers/BalancerPoolerV2.sol` | Delete |
| `test/BalancerPoolerV2.t.sol` (and any other test or mock importing the above) | Delete, or port remaining relevant coverage to UniPoolerV2 tests |
| `test/mocks/MockERC4626Wrapper.sol` | Delete. It mentions `BalancerPoolerV2` only in comments, but its only user is `test/BalancerPoolerV2.t.sol` (verified 2026-10-07), so it is dead once that test is deleted. Re-check with `grep -rln MockERC4626Wrapper src test` before deleting; if anything else uses it, keep it and refresh its comments instead |
| `test/integration/NudgeStreamerDonorIntegration.t.sol` | Imports the Balancer interfaces. Retarget it to UniPoolerV2 if it exercises the donation path; retire (delete) it only if it is purely Balancer-specific. Record the decision as an Autonomous Decision |
| `src/**/NudgeRatchetDelayRelease*.sol`, `src/**/MintPageView*.sol`, `src/dispatchers/Uniboost.sol` | Refresh stale Balancer comments (comments only, no logic change) |
| `src/migration/**` (story 052's `UniPoolerCutoverEscrow.sol`), `test/UniPoolerCutoverEscrow.t.sol`, `test/UniPoolerCutoverEscrow.fork.t.sol`, `test/mocks/MockV3ExitRouter.sol` | **Do NOT delete or modify.** Must still build and pass after the deletions |

Use `grep -rn -i "balancer" src test script` to find every remaining reference.

## Technical Details

- Delete only after confirming that nothing else compiles against these files, using the **Balancer-importer grep** below. Anything still importing them must be either deleted (Balancer-only) or have the import removed.
- **Balancer-importer grep (the acceptance check).** The earlier pattern `interfaces/balancer|BalancerPoolerV2|IBalancer|IUnlockCallback|BalancerTypes` could never return zero hits, even before story 052: `IBalancer` matches the live `IBalancerPoolerMintDebtHook`, and the bare names match comments in files this story keeps. Use this instead (there is no `script/` dir in this repo; run it from the worktree root):

  ```bash
  grep -rnE --include=*.sol \
    'interfaces/balancer/|\bBalancerPoolerV2\b|\bIBalancer(Vault|Router)\b|\bIUnlockCallback\b|\bBalancerTypes\b' \
    src test \
    --exclude-dir=lib --exclude-dir=migration \
    --exclude=UniPoolerCutoverEscrow.t.sol --exclude=UniPoolerCutoverEscrow.fork.t.sol --exclude=MockV3ExitRouter.sol \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|/\*|\*)'
  ```

  Exclusion list, and why each exclusion is safe:
  1. **Identifier narrowing:** `IBalancer` becomes `\bIBalancer(Vault|Router)\b`, and every name is word-bounded. This drops `IBalancerPoolerMintDebtHook` / `BalancerPoolerMintDebtHook` (live, kept) without excluding their files, so a real Balancer import added to them would still be caught.
  2. **Comment lines** (`//`, `///`, `/*`, ` *`) are filtered out. A comment cannot import or reference a type, so no real importer is hidden. Comment-only mentions are handled by the comment-refresh item, not by this check.
  3. **Path exclusions:** `lib/`, `src/migration/`, `test/UniPoolerCutoverEscrow.t.sol`, `test/UniPoolerCutoverEscrow.fork.t.sol`, `test/mocks/MockV3ExitRouter.sol`. These are story 052's escrow files. They declare only local interfaces and import nothing this story deletes (052's own grep proves it), so `forge build` is the backstop if that ever changes.

  Before deletion the grep returns only `src/interfaces/balancer/*`, `src/dispatchers/BalancerPoolerV2.sol`, `test/BalancerPoolerV2.t.sol` and `test/integration/NudgeStreamerDonorIntegration.t.sol`. After this story it must return **nothing** (exit status 1).
- **Hits of the old pattern, verified 2026-10-07** in `worktrees/yield-claim-nft/Balancexit` at `267660b` (before 052 landed, so `src/migration/` did not exist yet). Each is classified here:

  | File | Old-pattern hit | Classification |
  |---|---|---|
  | `src/interfaces/IBalancerPoolerMintDebtHook.sol:4,8` | `IBalancer` prefix of `IBalancerPoolerMintDebtHook` | Legitimate. Live interface, kept. Excluded by identifier narrowing |
  | `src/hooks/BalancerPoolerMintDebtHook.sol:5,12,17,22,64` | `IBalancerPoolerMintDebtHook` import/inheritance, and `BalancerPoolerV2` in NatSpec | Legitimate. Live hook, kept. The import is not a Balancer interface; the `BalancerPoolerV2` mentions are comment-only. You may refresh the comments, but no logic change |
  | `src/interfaces/IUniboostPooler.sol:7` | `BalancerPoolerV2.pool(uint256 minBPT)` in `@dev` NatSpec | Comment-only. Excluded. Refresh optional |
  | `test/UniPoolerV2.t.sol:52,866` | `BalancerPoolerV2` in `@notice` / `@dev` (port provenance) | Comment-only, historical provenance. Excluded. Leave as is |
  | `test/mocks/MockERC4626Wrapper.sol:9,48` | `BalancerPoolerV2` in `@dev` | Comment-only, but the mock's only user is `test/BalancerPoolerV2.t.sol`, so it is a Balancer-only mock. Delete it (see File Locations) |
  | `src/dispatchers/NudgeRatchetDelayRelease.sol:114`, `src/dispatchers/Uniboost.sol:16,18,228` | `BalancerPoolerV2` in NatSpec | Comment-only. Excluded. Refresh per plan §2.2 |
  | `test/integration/NudgeStreamerDonorIntegration.t.sol:12,100,169` (+ comments) | `import {BalancerPoolerV2}`, state var, constructor | **Real importer.** Must be fixed (retarget or retire) |
  | `src/interfaces/balancer/*`, `src/dispatchers/BalancerPoolerV2.sol`, `test/BalancerPoolerV2.t.sol` | Definitions and imports | Deleted by this story |
- **Keep the cutover escrow (yield-claim-nft:052).** `src/migration/` (`UniPoolerCutoverEscrow.sol`) and its tests (`test/UniPoolerCutoverEscrow.t.sol`, `test/UniPoolerCutoverEscrow.fork.t.sol`, `test/mocks/MockV3ExitRouter.sol`) must NOT be deleted or modified by this story, even though they concern the Balancer exit. The escrow is deployed on mainnet and pinned by phStaging2. Its source must stay reproducible from the deployed bytecode for the protocol's accounting record. It declares only local interfaces and imports nothing this story deletes, so it survives the deletions. `git diff --stat <base> -- src/migration test/UniPoolerCutoverEscrow.t.sol test/UniPoolerCutoverEscrow.fork.t.sol test/mocks/MockV3ExitRouter.sol` must be empty at the end.
- Do not delete `IBalancerPoolerMintDebtHook` or anything the mint-debt hook needs, if that lives in yield-claim-nft. `BalancerPoolerMintDebtHook` is a live contract with a historical name and stays. Check whether it lives here (`grep -rn BalancerPoolerMintDebtHook`) and leave it untouched.
- **Cross-repo build note:** phStaging2's mainnet cutover script (story 103) declares its own Balancer exit interfaces, so it does not depend on these files. phStaging2's `script/archives/**` are skipped by `foundry.toml` (`skip = ["script/archives/**"]`) and do not compile. However, phStaging2's live scripts, tests and `src/mocks` may still import `lib/yield-claim-nft/src/interfaces/balancer/*` or `BalancerPoolerV2`. A phStaging2 pin bump past this story must still build. Grep `~/code/reflax-mint/phase-2-staging` (excluding `lib/` and `script/archives/`) for those imports and list them in the execution summary. Do NOT modify phStaging2 in this story. phStaging2 story 107 owns archiving or deleting those importers before it bumps the pin past this story. Expected importers are `script/RevokeBalancerPoolersHoldingPattern.s.sol`, `test/RevokeBalancerPoolers.fork.t.sol`, `script/helpers/UniPoolerCutoverCore.sol`, `script/DeployMainnetUniPoolerCutover.s.sol`, `script/VerifyUniPoolerCutover.s.sol` and `test/UniPoolerCutoverMainnet.fork.t.sol`, plus `test/UniPoolerCutoverCore.t.sol` if it still exists. Your list helps 107. The cutover now runs through the escrow: phStaging2:103 rewired `UniPoolerCutoverCore` to yield-claim-nft:052's `UniPoolerCutoverEscrow` (BPT goes via `withdrawBPT(escrow, …)` and `escrow.exitAndSeed(…)`). So those cutover files also import `lib/yield-claim-nft/src/migration/UniPoolerCutoverEscrow.sol`. That import is NOT a problem for the pin bump because this story keeps the escrow. Report only their imports of the deleted files (typically `BalancerPoolerV2` for the old pooler's `withdrawBPT`/pause calls), and note separately which of them also import the escrow.

## Implementation Notes

- **Gate check first** (see Checklist). It requires both the GATE CLEARED line and phStaging2:106 in a terminal directory.
- **Ordering / predecessors:** phStaging2:106 (direct gate) and yield-claim-nft:052 (explicit). 052 is already implied transitively (050 -> phStaging2:106 -> 104 -> 103 -> yield-claim-nft:052), but it is stated here because this story must keep 052's files. 052's escrow must exist in this branch before the deletions, so that the escrow build/test check is meaningful.
- This is deletion work: no TDD needed, but the full suite must stay green.
- **Commits:** every commit is `[story-050] <message>`, staged by explicit path (`git rm <path>` for deletions).

## Checklist

- [ ] Gate check: confirm a line beginning `GATE CLEARED: winddown-confirmed` exists under the Execution Gate section, and that its predecessor stories (phStaging2:106, i.e. `stories/phStaging2/{complete,auto-complete}/*/106-*.md`) are in complete/ or auto-complete/ (NOT merely review/). If either fails, make NO code changes: append an Autonomous Decision stating which gate or predecessor is missing, report "ABORTED: out-of-order execution — <reason>" in the output, and exit without moving the story.
- [ ] Predecessor check: yield-claim-nft:052 is in complete/ or auto-complete/ (`stories/yield-claim-nft/{complete,auto-complete}/*/052-*.md`) and `src/migration/UniPoolerCutoverEscrow.sol` exists in this branch. If not, abort exactly as in the gate check above.
- [ ] BEFORE deleting anything, run the **Balancer-importer grep** from Technical Details (with its exclusion list) and record its output in the execution summary. Resolve each dependant (delete if Balancer-only, else remove or retarget the import). Also confirm the comment-only hits classified in Technical Details have not changed into real references.
- [ ] `test/integration/NudgeStreamerDonorIntegration.t.sol` no longer depends on BalancerPoolerV2 or the Balancer interfaces: retargeted to UniPoolerV2 if it exercises the donation path (it must still pass), or retired if purely Balancer-specific. The decision is recorded as an Autonomous Decision.
- [ ] Delete `src/interfaces/balancer/{BalancerTypes,IBalancerRouter,IBalancerVault,IUnlockCallback}.sol`, `src/dispatchers/BalancerPoolerV2.sol` and `test/BalancerPoolerV2.t.sol`, plus `test/mocks/MockERC4626Wrapper.sol` (Balancer-only, after re-checking that it has no other user) and any other Balancer-only mocks/tests found above.
- [ ] `BalancerPoolerMintDebtHook` and its interface, if present in this repo, are untouched (comment refresh only, if any).
- [ ] The escrow is untouched: `src/migration/`, `test/UniPoolerCutoverEscrow.t.sol`, `test/UniPoolerCutoverEscrow.fork.t.sol` and `test/mocks/MockV3ExitRouter.sol` show no diff against this story's base commit. After the deletions, `forge build` passes and the escrow suites pass: `forge test --match-path test/UniPoolerCutoverEscrow.t.sol`, and `RPC_MAINNET=<rpc> forge test --match-path test/UniPoolerCutoverEscrow.fork.t.sol` (if no RPC is available, record that as an Autonomous Decision; do not skip silently).
- [ ] Refresh the stale Balancer comments in `NudgeRatchetDelayRelease`, `MintPageView` and `Uniboost` (comments only).
- [ ] After deletion, the Balancer-importer grep (with its exclusion list) returns nothing, and `forge build` and `forge test` (full suite) are both clean.
- [ ] Grep phStaging2 (`~/code/reflax-mint/phase-2-staging`, excluding `lib/` and `script/archives/`) for imports of the deleted files; list the results in the execution summary (do not modify phStaging2).
- [ ] All commits use `[story-050] <message>`, staged by explicit path; the worktree is clean.
- [ ] Final step: end your execution summary with a clearly marked block headed "⚠️ HUMAN ACTION REQUIRED" that restates the Required Human Action On Completion section verbatim, so the user is alerted. Do not perform the action yourself and do not mark it as done.

## Concerns

- phStaging2 compiling against the deleted files does NOT block this story: phStaging2 consumes yield-claim-nft through a pinned submodule, and story 107 archives or deletes the phStaging2 importers before (or together with) bumping the pin past this story. Report the importers you find; do not edit phStaging2.
- Updating or deleting the Balancer-era memory notes is a human task. It is listed in phStaging2 story 107's human action.

## Upstream Change (planned 2026-10-01): yield-claim-nft:051 / phStaging2:108

If this story retargets `test/integration/NudgeStreamerDonorIntegration.t.sol` (or any other test) to UniPoolerV2: after yield-claim-nft:051 the test must create the canonical pair via the router's factory before constructing UniPoolerV2, and must call `setHook` with a non-default hook before any index-4 dispatch.

## Upstream Change (2026-10-07)

- **Grep fixed.** The old zero-hits grep could never pass: `IBalancer` matched the live `IBalancerPoolerMintDebtHook` (and the hook that imports it), and the bare names matched comment-only mentions in `IUniboostPooler.sol`, `test/UniPoolerV2.t.sol`, `test/mocks/MockERC4626Wrapper.sol`, `NudgeRatchetDelayRelease.sol` and `Uniboost.sol`. These hits were verified in the worktree at `267660b`. It is replaced by the Balancer-importer grep in Technical Details, which uses identifier narrowing, a comment-line filter and escrow path exclusions. It still catches every real importer (today: only `test/integration/NudgeStreamerDonorIntegration.t.sol`, besides the files being deleted). `MockERC4626Wrapper.sol` is classified as a Balancer-only mock and deleted.
- **Escrow kept.** yield-claim-nft:052's `src/migration/UniPoolerCutoverEscrow.sol` and its tests/mocks must not be deleted or modified, and are excluded from the grep. The escrow is deployed on mainnet and pinned by phStaging2, so its source must stay reproducible from the bytecode for the accounting record. A checklist item now requires `forge build` and the escrow suites to pass after the deletions.
- **Ordering.** The cutover runs through the escrow (052 consumed by phStaging2:103). The expected phStaging2 importer notes are updated to match, and yield-claim-nft:052 is now an explicit predecessor (it was already implied via 050 -> phStaging2:106 -> 104 -> 103 -> 052), with its own checklist check.
