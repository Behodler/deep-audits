# reflax-yield-vault-18 — run context (project-manager setup)

- Run label: `reflax-yield-vault-18`; dir: `/home/justin/code/audits/reflax-yield-vault/reports/18/` (layout `<project>/reports/NN/`; 00–17 exist, 13 is absent from the sequence — historical gap, not reused)
- Mode: regression (no `--full`)
- Branch: `master` (currentBranch == defaultBranch == git HEAD branch)
- HEAD: `4788ed41747b923165745af748a078bfb534ba20` (src tree clean)
- Baseline: `cdd07434a62ae4e1b158eef97dbfef3f2f47d6d9` (kind `branch-baseline`, branchBaselines.master, lastRun reflax-yield-vault-17; ancestor of HEAD verified). Top-level mirror agrees.

## Range cdd0743..4788ed4 (2 commits)
- `25276b8` [story-051] Revert previewExitFor from IYieldStrategy (pure deletion, 494 lines)
- `4788ed4` [story-052] CurveAMMAdapter.setRoute enforces Curve Router NG contiguity (M-01)

## Changed files (12)
In scope (5): src/AMMAdapters/CurveAMMAdapter.sol, src/AMMAdapters/ICurveRouterNG.sol, src/AYieldStrategy.sol, src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol, src/interfaces/IYieldStrategy.sol
Out of scope by project `outOfScope` (`test/`) but story-relevant: test/mocks/MockCurveRouterNG.sol, test/unit/CurveAMMAdapter.routeGap.t.sol (ADDED), test/unit/CurveAMMAdapter.t.sol, test/unit/ERC4626MarketYieldStrategy.t.sol, test/unit/ERC4626YieldStrategy.t.sol
Non-sol: CLAUDE.md (new contiguity rule; notes live mainnet adapter 0x2D02…D6f PREDATES the check), foundry.toml (read-only fs_permission for AMMRoutes.json)

newInScope: [] — every changed in-scope file is already in the registry snapshot.

## Computed scope (denylist: first-party .sol minus lib/** minus outOfScope) — 7 files, matches snapshot
src/AYieldStrategy.sol; src/AMMAdapters/CurveAMMAdapter.sol; src/AMMAdapters/IAMMAdapter.sol; src/AMMAdapters/ICurveRouterNG.sol; src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol; src/concreteYieldStrategies/ERC4626YieldStrategy.sol; src/interfaces/IYieldStrategy.sol
Excluded: src/mocks/MockERC20.sol and all test/** (explicit project outOfScope). outOfScope entries Legacy/, AutoPoolYieldStrategy.sol, UniV4StableYieldStrategy.sol match no file at HEAD (stale, harmless).

## Known issues
Registry `knownIssues`: 0. Re-checked at HEAD: src/CLAUDE.md (no Known Issues / Out of Scope section; the skimSurplus return-vs-event note is documentation, not an accepted issue) and src/docs/*.md (3 files, no such sections). Known-issue suppression authority: NONE — sanitizer must not suppress on KI grounds. Registry not modified.

## Ledger (key `.entries`, 65 entries; also `scanLog`, `inboundCrossRepoObligations`)
Status: open 54, false-positive 6, downgraded-to-centralization 2, fixed 1, merged 1, wont-fix 1
Severity: low 36, qa 12, medium 6, faithfulness 6, high 3, centralization 1, informational 1
Index: `ledger-index.json` (fingerprint, label, title, contract, function, severity, status, firstSeenRun, lastSeenRun, branch, branchesSeen)

## Stories (both auto-complete = final state; one hit each, no ambiguity)
- story-051: ~/code/product-owner/stories/vault-RM/auto-complete/exit-preview-revert/051-revert-exit-preview-from-iyieldstrategy.md
- story-052: ~/code/product-owner/stories/vault-RM/auto-complete/curve-adapter-m01/052-curve-amm-adapter-route-contiguity-m01.md
Full text + commit bodies: `story-intents.md`

## Candidate ledger matches
story-052 "M-01" is NOT this ledger's M-01 (9addc259f322, _skimSurplus duplicate clients, already fixed). Per the story it is sya-harvester audit-01 M-01 (gap-route strand; CurveAMMAdapter named as the template the bug was copied from). Local entries addressed:
- b28e77daefb3 L-07 open — setRoute accepts tokenIn==tokenOut and internal zero-gap segments (primary fix candidate; tokenIn==tokenOut only rejected indirectly via k>=1 — verify)
- 90f3fa166e20 L-10 false-positive — setRoute lastToken validation (code replaced; keep FP)
- 6e771a84e82d L-12 open — swap does not re-check amountOut (swap untouched by story-052 → stays open)
previewExitFor removed by story-051 (fixed-by-removal candidates; verify no remaining symbol — grep of src/ at HEAD returns zero hits for previewExitFor/_exitFloor):
- 5351fd4d3f8c L-18, 302656e23443 L-19, 833f7f6c728a L-21, 6476515055d8 L-24, 63fa9e3e62bf L-26, e868f28953a9 QA-10, b5b58717f3b1 QA-11, 25d53af10717 INFO-01 (function previewExitFor)
- 6f57473e6b01 L-20 (_exitFloor, deleted)
- 7a66fe7d5a96 L-22 (_disposeShares "quoted floor not honoured") — premise depended on the quote; re-evaluate, _disposeShares itself survives
Survive the revert (functions untouched): L-23 e6088a0ec55e, L-25 10f4bd34e9cf, L-27 d9bd595066ef (cross-repo), L-28 38c9b2bae75f, L-29 704404968a8f, QA-12 1b33361313ce.

## Workspace
`/home/justin/code/audits/reflax-yield-vault/work` synced to 4788ed4 (detached; tracked tree byte-identical to src HEAD). 43 untracked audit files preserved (backup tar in scratchpad). `forge build` FAILS unmodified: 8 audit-authored run-17 harnesses call the deleted previewExitFor. With `--skip` of those 8, build PASSES; DominanceRun17Grounding (7/7) and CurveAMMAdapter.routeGap (21/21) pass.
Skip set: test/poc-run17-*, test/invariant/RealisticExitPreview*, test/invariant/MedusaRealisticExit.sol, test/invariant/mocks/RealisticERC4626Vault.sol, test/symbolic/DominanceRun17.t.sol

## Other flags
- story-051 records EIP-170 oversize pre-existing at cdd0743, improved by the revert: ERC4626MarketYieldStrategy 1,651 bytes over, ERC4626YieldStrategy 54 over; CI profile `ci` missing.
- CLAUDE.md: live mainnet CurveAMMAdapter 0x2D02…D6f predates the contiguity check — owner setRoute there is unguarded (footgun candidate).
