# Dedup log: run 38, entry point `balancer-holding`

Input: 2 candidates. Output: 2 kept, 0 merged, 0 dropped, 0 routed to manual-review.

## Phase 1: Exact match
There are no duplicate contract:function:line tuples. Candidate 0 is `script/VerifyBalancerHolding.s.sol:run` L17-31. Candidate 1 is `script/RevokeBalancerPoolersHoldingPattern.s.sol` contract NatSpec L14-15.

## Phase 2: Root cause
- DEDUP-001 (candidate 0): IncompletePostconditionCoverage. The verifier and the story-103 step-0 precondition only check four hardcoded addresses.
- DEDUP-002 (candidate 1): MisleadingDocumentation. The NatSpec misattributes the grant provenance to WhitelistPoolersV2.

Both concern the authorized-pooler set, but they have distinct root causes, files and fixes. They are not merged.

## Ledger duplicate check (jq projections only; ledger not modified)
- phoenix-phase-2-staging ledger: no entry with entryPoint `balancer-holding`. No entry on VerifyBalancerHolding, RevokeBalancerPoolersHoldingPattern, authVersion, pooler-set revocation or WhitelistPoolersV2 provenance. No duplicates.
- yield-claim-nft ledger (top-level key is `entries`, not `findings`): no finding on BalancerPoolerV2 auth versioning (authVersion, incrementAuthVersion, setAuthorizedPooler, onlyAuthorizedPooler). No duplicates.

## Cross-references (recorded in `crossReferences`, not merged)
- DEDUP-001 to yield-claim-nft L-06 `342075dfba3c…` (open): the BalancerPoolerV2.pool minBPT-only sandwich. This is the hazard the holding pattern contains, and DEDUP-001's 5th-pooler path re-exposes it. The two findings live in different projects and have different root causes.
- DEDUP-001 to yield-claim-nft L-03 `e29ae08ed999…` (fixed): limitRaw=0 donation-swap floor. Context only.
- DEDUP-001 to phoenix-phase-2-staging `d32e99aa64bb…` (open, `dispatcher-replace-sky-pooler`): stale offline minBPT. Sibling context only.

## Filtering
Nothing was removed. DEDUP-002 is informational in tone, but it is not tool noise. It affects how story-103 step 7 re-derives the re-authorization list, so it is a Law-2 operator hazard and is kept for QA.
