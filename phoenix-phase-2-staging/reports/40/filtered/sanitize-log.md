# Sanitize log: phoenix-phase-2-staging run 40

Regression 0e190e8..a4f9f3c (master), entryPoint `""`. Input: 11 DEDUP findings + 3 ledger-duplicate groups.
**Ledger not written** (finding-manager upserts).

## Known issues
- `knownIssuesSource` is null. **`src/known-issues.md` does not exist at a4f9f3c.** The 11-entry registry cache cannot be checked against any source, so it carries no suppression authority.
- Each finding was checked against the cache anyway. Two near-misses were rejected:
  - "Mock contracts with unlimited minting" vs DEDUP-005. The defect is on the mainnet RECOVERY path.
  - "External vault/yield strategy behavior" vs DEDUP-006. The defect is a first-party hardcoded venue choice.
- **0 suppressions.**

## Fingerprints
- Scheme: `sha256(contract:function:rootCauseClass)` with an empty entryPoint. The fields are taken verbatim from deduplicated.json, and the full preimages are in sanitized.json.
- No collision with any of the 196 ledger fingerprints.
- The method was validated by reproducing 9a694ae01fe1, 59527bfa8478 and 9fa8eee3010e from their ledger fields.
- Convention drift: run-39 entries prefix the contract with `lib/phoenix-phase-2-staging/` and use PascalCase class names.

## Dispositions

| DEDUP | disposition | fingerprint |
|---|---|---|
| 001 | new | 7d5a26570be9 |
| 002 | new, **re-raise of ycn L-26 wont-fix (disclosed)** | 1d7e436f7dad |
| 003 | new (same class as Q-01 9fa8eee3010e, different contract) | c8fb41a168e1 |
| 004 | new (same class as c358427cf96b / 2f8e1ff5e1ae, different contract) | 85095591a60a |
| 005 | new | 5dce56307136 |
| 006 | new | b7ff538a654c |
| 007 | new (related 9a694ae01fe1, ycn L-26) | 6d49f9353148 |
| 008 | new, spec-conformance | 48d88a589ca4 |
| 009 | still-open, cross-project obligation (ycn L-27 2268ead7cb / F-02-052 5a7732a4ea, fix-pending, **fix not yet landed**, not an incomplete fix) | cb74e7097a24 (no phStaging entry) |
| 010 | new, spec-conformance | 91aa9008aaca |
| 011 | cross-project note refresh (ycn F-03-052 8ab7d54dc97f / Q-21 4c2f9c705c39) | 5030b0e6ce44 (no phStaging entry) |

Ledger duplicates:
- PATTERN-001 + SLITHER-005 → 9a694ae01fe1: still-open, bump lastSeenRun to 40.
- PATTERN-005 → 59527bfa8478: still-open, bump 38 → 40, stays Low (story 103 is in `incomplete/`).
- MR-001 → ycn Q-24 88bfa9493621: cross-project, no phStaging entry.

## Wont-fix disclosure (DEDUP-002)
Prior entry: yield-claim-nft L-26 `b2a29359fde5`, wont-fix, owner triage 2026-10-07. Quoted:

> "I guess, it should just panic and then I'll have to figure out what to do if there is a pair. I think it's safe to mark as won't fix." ... Re-weigh if a hard deadline would expose value, or if no replacement seeder is permissible under the story-052 tax constraint.

DEDUP-002 is kept rather than suppressed, for four reasons:
- It is a different contract: UniswapHelper, story 109, auto-complete.
- The root cause is different: the guard checks only that the pair exists.
- The trigger is an honest user acting through a protocol-shipped helper. L-26 was judged against an adversarial 1-wei grief.
- The fix belongs in the helper, not the escrow.

L-26's own re-weigh condition now holds. BalancerWinddownPlan.md L7 sets the deadlines: withdrawals-only from 30 Oct 2026, and the V3 Vault paused on 30 Nov 2026.

## Wont-fix / acknowledged sweep
None of these suppress any finding:
- 3b7430a7a4b6 (M-03 dev): promotion-ready suite scope.
- cf684d5dc289 (M-01): SSV2 patcher tail.
- SSV2 wont-fix entries: F-02 436848b0e31b, Q-01 ca095edfd77e, F-03 103002cc2990, Q-03 30510f331ea8.
- Acknowledged 85d794b386b1: Sky-pooler `_minter` misconfig.
- The six saga/ys-swap acknowledged and wont-fix entries.

All are different contracts and different defects.

## Regressions / incomplete fixes
**None.**
- Fixed entries on Balancer exits: 3216feb8ce07 (`minAmountsOut=[0,0]`). It did not reappear, because the core enforces non-zero floors at L320-322 and L396-405.
- Fixed entries with a precedent class: L-02 2c82d65e65e1 and L-09 78cb5942d483. Each class recurs only in a different contract, so neither is a regression.
- Fix-pending entries:
  - eda17642828a: story 101 rehearses a different cutover. Run 39 at dfbf2f9 already judged it "not an incomplete fix", and nothing in dfbf2f9..a4f9f3c touches dispatcher-swap rehearsal.
  - 6b63ef6516ac: DepositPageView.sol is unchanged in range.
  - 2c53e944caee: the script was archived (96a991b) after its mainnet run 4e5cca1.
  - None of the three re-flagged with changed code.

## Fixed-proposals
**None warranted by this range.**
- 6af1ae30ed82: it anchors on `_rehearseDispatcherSwap`, deleted at e6eded0 (0 occurrences at a4f9f3c). Story 101 adds one more swap class via the shared core, but MR-30-DEV-01 forbids proposing `fixed` on absence of evidence.
- e0ac78243e5f: not fixed by the range, since local-/mainnet-addresses.ts only gain UniswapHelper. Its premise ("mainnet ships Kendu 0x0") looks expired independently, because mainnet Kendu has been 0xaa95…6C18 since 4e5cca1 (2026-08-12). This is a human question.
