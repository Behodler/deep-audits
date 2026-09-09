# Pattern-match summary — yield-claim-nft (run 10, cold scan)

- Commit: `cf75ec9` | Pattern DB: `patterns/vulnerability-patterns.json` (29 patterns)
- Scope: V2 mint→dispatch system (NFTMinterV2, NFTMigrator, ATokenDispatcherV2, BalancerPoolerV2, BurnerV2, GatherV2, BalancerPoolerMintDebtHook, DefaultDispatchHook) + V1 context.
- Result: **5 findings (medium/high confidence the pattern applies)** + **5 manual-review (low confidence)**. Confidence = does the pattern *apply*; severity = impact if it does.

## Ranked leads for the interaction scanners

| Rank | Pattern | Where | Pot. sev | Conf | Why it matters |
|------|---------|-------|----------|------|----------------|
| 1 | MISSING-SLIPPAGE (LP-add sandwich) | `BalancerPoolerV2.pool/unlockCallback` (269-311) | medium | med | Single-sided UNBALANCED Balancer V3 add; `minBPT` floor is **pooler-supplied, no on-chain reference**. Confirm keeper sizes it from `getIdealBPT()`. → econ-scanner |
| 2 | REENTRANCY-ERC777 (cross-index) | `NFTMinterV2._executeMint` (170-201) | low | med | Minter is **unguarded**; external `dispatch` + ERC1155 `_mint` receiver hook allow cross-index re-entry. CEI bounds impact. Ledger L-01. → code-scanner |
| 3 | DOS-UNBOUNDED-LOOP | `NFTMigrator.migrate` (62-76) | medium | high | Nested per-unit `mintFor` loop, unbounded by holder balance. **Ledger M-01/M-02 wont-fix (migration done)** — do not re-escalate without evidence it's live. |
| 4 | RETURN-VALUE-IGNORE | `BalancerPoolerV2._dispatch` (218) | low | high | `IERC4626(sUSDS).deposit` return discarded; self-correcting (balance re-read). Ledger Q-02. |
| 5 | INCORRECT-OPERATOR | `BalancerPoolerMintDebtHook.setRatio` (78) | low | high | `>` should be `>=`; accepts ratio==50 vs documented strict-<50. Ledger L-02. |

## Manual review (low confidence — routed, not dropped)
- **MR-01 MINT-ON-DEMAND-OVERMINT** — `BalancerPoolerMintDebtHook` mints phUSD = uncapped accrued `mintDebt`. Mitigated (OnlyDispatcher, owner-pinned recipient, zero-before-mint). Residual = unbacked-phUSD economics, already **suppressed as DEDUP-001** (owner-trust + OOS backing). Visible, not re-escalated.
- **MR-02 ERC4626-INFLATION** — protocol is a *depositor into* sUSDS, not a vault issuer → N/A.
- **MR-03 MISSING-SLIPPAGE (V1)** — V1 `BalancerPooler.dispatch` defaults `minBpt=0` (zero-slippage LP add). Verify V1 is deprecated.
- **MR-04 DIVISION-PRECISION** — donation/debt rounding is multiply-before-divide, floor-toward-protocol; benign.
- **MR-05 CENTRALIZATION-ADMIN** — `replaceDispatcher` (C-01) / `setHook` / `setPSM` / `setBatchMinter` owner footguns; documented/known.

## Structurally absent (true negatives)
No oracle, ecrecover/signatures, proxy/initialize/delegatecall, unsafe downcast, raw-ETH/selfdestruct, cross-chain, or MasterChef accPerShare/rewardDebt accounting. The donation leg's sandwich/slippage and stale-approval risk is neutralised by the fixed-rate Sky PSM route + allowance reset-to-0 (story-034). "ATokenDispatcher" = *Abstract* token dispatcher, **not** Aave aToken — no Aave integration exists despite the brief.
