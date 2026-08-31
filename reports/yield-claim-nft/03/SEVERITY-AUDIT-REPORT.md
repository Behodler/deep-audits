# Severity Audit Report: yield-claim-nft V2 (Round 03)

**Project**: yield-claim-nft (V2 stories 24-28)
**Auditor**: severity-auditor-agent
**Date**: 2026-04-16
**Scope Notes**: Owner-driven attacks are out of scope. Dodgy tokens are out of scope.

---

## Summary

| Finding | Claimed | Assessed | Agreement | Confidence |
|---------|---------|----------|-----------|------------|
| M-01    | Medium  | Medium   | Yes       | High       |
| M-02    | Medium  | Medium   | Yes       | High       |

**Overstatements detected**: 0
**Understatements detected**: 0
**Deduplication risk**: M-01 and M-02 share root cause location (mintFor lines 206-214)

---

## M-01: mintFor() bypasses global pause check

**Claimed**: Medium | **Assessed**: Medium | **Agreement**: Yes

### Independent Analysis

**Code reviewed**: `NFTMinterV2.sol` lines 206-214 (mintFor) vs line 171 (_executeMint pause check)

The finding is factually correct. The `_executeMint()` function enforces `require(!paused)` at line 171, but `mintFor()` at line 206 performs no pause check. The PoC conclusively demonstrates that `mintFor()` succeeds while the contract is paused.

### Trigger Assessment

- **Can an unprivileged user trigger this?** Yes. Any user holding V1 NFTs can call `NFTMigrator.migrate()`, which is permissionless. The migrator is an authorized minter and calls `mintFor()` on behalf of the user.
- **Attacker profile**: Any V1 NFT holder during an emergency pause window.

### Financial Impact Assessment

- **Direct financial impact?** No. No funds are transferred during `mintFor()` -- it is a free mint path. The minted NFTs represent future yield claims, but no tokens move at mint time.
- **Indirect financial impact?** Conditional. If a dispatcher was paused because of a vulnerability, NFTs minted during the pause could later be used to claim yield from the compromised dispatcher. This is plausible but requires a specific downstream scenario.

### Protocol Function Assessment

- **Is protocol function impacted?** Yes. The global pause mechanism, implemented via the IPausable/Global Pauser pattern, is a core safety feature. Having `mintFor()` bypass it means the emergency stop cannot fully halt all minting activity. This is a genuine protocol function impairment.

### High Severity Check

| Criteria | Met? | Reasoning |
|----------|------|-----------|
| Direct asset theft/loss | No | No funds move during mintFor |
| No conditions required | No | Requires active emergency pause + V1 NFT holdings |
| Valid attack path | Yes | Permissionless trigger via migrate() |
| PoC proves impact | Yes | Clean demonstration of pause bypass |

**Verdict**: Does not meet High. No direct asset theft or loss. The impact is on protocol safety mechanisms, which is squarely Medium territory.

### Low Severity Check

| Criteria | Met? | Reasoning |
|----------|------|-----------|
| Pure spec deviation | No | Pause is a security-critical mechanism |
| No security impact | No | Bypass of emergency stop has real consequences |

**Verdict**: Exceeds Low. The pause mechanism exists for incident response, and its bypass has tangible security implications.

### Final Assessment

**Medium is correct.** Protocol function (emergency pause) is genuinely impacted. The permissionless trigger via `migrate()` strengthens the finding. No direct asset theft rules out High. The security implications of a broken emergency stop rule out Low.

---

## M-02: mintFor() ignores per-dispatcher disabled flag

**Claimed**: Medium | **Assessed**: Medium | **Agreement**: Yes

### Independent Analysis

**Code reviewed**: `NFTMinterV2.sol` line 174 (`require(!config.disabled)` in `_executeMint`) vs lines 206-214 (`mintFor()` with no disabled check)

The finding is factually correct. The `_executeMint()` enforces the `disabled` flag at line 174, but `mintFor()` does not read `config.disabled` at all. The PoC demonstrates both the direct `mintFor()` bypass and the migration-path bypass through `NFTMigrator.migrate()`.

### Trigger Assessment

- **Can an unprivileged user trigger this?** Yes. Same as M-01 -- any V1 NFT holder can call `NFTMigrator.migrate()` permissionlessly.
- **Attacker profile**: Any V1 NFT holder whose V1 index maps to a disabled V2 dispatcher.

### Financial Impact Assessment

- **Direct financial impact?** No. Same rationale as M-01 -- `mintFor()` is a free mint path with no token transfer.
- **Indirect financial impact?** Conditional. If a dispatcher was disabled because of a vulnerability, the minted NFTs could be used to interact with the compromised dispatcher. This is plausible but downstream.

### Protocol Function Assessment

- **Is protocol function impacted?** Yes. The per-dispatcher `disabled` flag is a granular safety control. The owner sets it to halt minting for specific dispatchers (e.g., during strategy wind-down or in response to a dispatcher vulnerability). Having `mintFor()` ignore this flag undermines the owner's ability to selectively protect users.

### High Severity Check

| Criteria | Met? | Reasoning |
|----------|------|-----------|
| Direct asset theft/loss | No | No funds move during mintFor |
| No conditions required | No | Requires disabled dispatcher + V1 NFT holdings |
| Valid attack path | Yes | Permissionless trigger via migrate() |
| PoC proves impact | Yes | Clean demonstration of disabled flag bypass |

**Verdict**: Does not meet High. Same reasoning as M-01.

### Low Severity Check

| Criteria | Met? | Reasoning |
|----------|------|-----------|
| Pure spec deviation | No | Disabled flag is a safety mechanism |
| No security impact | No | Bypass allows minting against compromised dispatchers |

**Verdict**: Exceeds Low. The disabled flag serves a security purpose and its bypass has real consequences.

### Final Assessment

**Medium is correct.** Protocol safety function (per-dispatcher disable) is genuinely impacted. Permissionless trigger strengthens the case. No direct asset theft rules out High. Security implications rule out Low.

---

## Deduplication Risk Note

M-01 and M-02 both target the same code location: `mintFor()` at lines 206-214 of NFTMinterV2.sol. The root cause is the same -- `mintFor()` was written with minimal guards compared to `_executeMint()`. A C4 judge may elect to group these as a single finding ("mintFor missing safety guards").

However, the findings address distinct safety mechanisms (global pause vs per-dispatcher disable) with independent remediations. Separate submissions are defensible, but the deduplication risk should be acknowledged.

---

## Overall Verdict

Both findings are **correctly classified as Medium**. No overstatement detected. The submissions are well-written with clean PoCs that conclusively prove the stated behavior. The severity reasoning aligns with C4 criteria: protocol function is impacted, but no direct asset theft occurs.
