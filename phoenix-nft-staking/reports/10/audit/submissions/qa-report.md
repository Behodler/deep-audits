# QA Report — phoenix-nft-staking

This report bundles the Low-severity findings produced during the audit of the `phoenix-nft-staking` package (`BatchNFTMinter` + `NFTStaker`). Each item is a defense-in-depth or operational-hardening recommendation that does not, on its own, constitute a demonstrated High/Medium exploit at the production wiring (single-dispatcher, `paymentToken == rewardToken == phUSD`, `NFTMinterV2._mint`). They are recorded here so a fix-pass developer can close cheap gaps and so any future deployment that diverges from the production wiring (multi-dispatcher, alternate prime token, migration to `_safeMint`, exotic ERC20 nudge tokens) does not silently re-open them.

A separate "Centralization" section is included at the end as a brief acknowledgement; per project documentation (CLAUDE.md), owner control over `BatchNFTMinter` parameters and `NFTStaker` configuration is intentional design and is not enumerated as findings.

---

## [L-01] Missing `nonReentrant` on `batchMint` (defense-in-depth)

**Severity rationale**: Low — no demonstrated H/M exploit against the standard ERC20s the project actually supports (phUSD, USDC). The class of attacks that would benefit from a guard here (ERC777 hooks, rebasing, fee-on-transfer, double-entry-point) is excluded by the C4 known-invalid list unless explicitly in scope. Adding `nonReentrant` is a one-line cheap hardening consistent with the project's stated preference for OpenZeppelin primitives.

**Description**: `BatchNFTMinter.batchMint` is not protected by a `nonReentrant` modifier. The function performs an inner mint loop with a live max-approval to `nftMinter` (see L-03) and a post-loop `safeTransfer` of `nudgePaymentToken` to the recipient. While the standard ERC20s used in production do not provide a recipient hook to re-enter from, the absence of `ReentrancyGuard` means the contract relies on (a) the caller not configuring a hooked nudge token and (b) the downstream minter not invoking arbitrary recipient code. Both assumptions are external to this contract and worth pinning down with a guard.

**Code reference**: `lib/phoenix-nft-staking/src/BatchNFTMinter.sol:109-166` (function body), critical lines 144-154 (`balanceOf`, `safeTransfer`, `NudgePaid` event).

**Recommended mitigation**: Inherit OpenZeppelin's `ReentrancyGuard` and tag `batchMint` with `nonReentrant`. Additionally, document explicitly in the NatSpec for `setNudgePaymentToken` that `nudgePaymentToken` MUST be a standard non-rebasing, non-fee-on-transfer, non-hooked ERC20.

---

## [L-02] Token rotation strands prior nudge balance; no atomic kill-switch (operational hardening)

**Severity rationale**: Low — surviving substance after sanitization (the owner-frontrun and config-driven-DoS sub-issues are intentional centralization patterns and are filtered as known-invalid). The remaining concern is operational: the rotation-back jackpot and the kill-switch race are both contingent on H-01's underlying mechanic. If H-01 is fixed (per-batch cap or `recipient == msg.sender`), the residual exposure here collapses to "stranded balance with no on-chain rescue path", which is a recoverable misconfiguration rather than an asset-loss vector.

**Description**: `setNudgeSize` and `setNudgePaymentToken` take effect immediately with no atomic-sweep, no balance check, no timelock, and no pause path. `BatchNFTMinter` does not inherit `Pausable` (in contrast to `NFTStaker`, which does). Three operational consequences follow:

1. *Stranded funds on rotation* — `setNudgePaymentToken` overwrites the token without checking `IERC20(currentToken).balanceOf(this) == 0`. After rotation, the previous token sits on the contract with no rescue path. `NFTStaker` uses the analogous `totalStaked == 0` guard for `setStakedId` at line 231-235; the absence of a parallel guard here is asymmetric.
2. *Rotation-back jackpot* — when the owner eventually rotates back to recover the stranded balance, the rotation tx is publicly visible; a searcher bundling `batchMint(...)` immediately after will drain the entire stranded balance in a single block (the same mempool-race shape as H-01).
3. *No kill-switch under attack* — when H-01's drain is observed live, the owner's only recourse is `setNudgeSize(0)` or `setNudgePaymentToken(address(0))`. Both are visible in the mempool and a searcher will frontrun the disable tx with one final `batchMint`. The disable does not atomically protect the pool — it only blocks future qualifying calls.

**Code reference**: `lib/phoenix-nft-staking/src/BatchNFTMinter.sol:69-79` (setters); contract-level (no `Pausable`, no `sweep`).

**Recommended mitigation**:
- Inherit `Pausable` and gate `batchMint` with `whenNotPaused`. Wire `pause()` / `unpause()` to the global pauser already used by `NFTStaker`. This gives the owner an atomic kill-switch that does not depend on a setter race.
- Add an atomic `setNudgePaymentTokenAndSweep(address newToken, address sweepTo)` rotation path that transfers the old balance in the same tx that updates the token.
- Add a generic `sweep(address token, address to, uint256 amount)` admin function (paired with `Pausable`) for stranded balances of any token.
- Optionally require `IERC20(currentToken).balanceOf(this) == 0` before `setNudgePaymentToken` is allowed to change the token, mirroring `NFTStaker.setStakedId`'s guard.

---

## [L-03] ERC1155 receiver-hook reentrancy vector — closed at production wiring (defense-in-depth)

**Severity rationale**: Low — the vector described in the raw finding does NOT materialize at the deployed configuration. `NFTMinterV2._executeMint` calls OpenZeppelin's `_mint` (not `_safeMint`) at `lib/yield-claim-nft/src/V2/NFTMinterV2.sol:196`, and OpenZeppelin's `ERC1155._mint` does not invoke `_doSafeTransferAcceptanceCheck`. Without the receiver hook firing, no reentrancy entrypoint exists and the live max-approval cannot be abused via this path. The recommendation is forward-looking: if `NFTMinterV2` is ever migrated to `_safeMint` (or to any path that invokes arbitrary recipient code), this finding becomes live and the mitigations below become required.

**Description**: `batchMint` pulls `paymentAmount` of `paymentToken` and grants `nftMinter` an unbounded approval (`type(uint256).max`) for the duration of the mint loop, with no `nonReentrant` modifier. The theoretical reentrancy vector requires `nftMinter.mint` to invoke recipient code — currently it does not, because `_mint` is the non-safe variant. The cross-submodule dependency (`yield-claim-nft.NFTMinterV2`) is mutable and exposes only `ITokenMinterV2` to `BatchNFTMinter`; any change from `_mint` to `_safeMint` would need to flow through the project's change-request process.

**Code reference**: `lib/phoenix-nft-staking/src/BatchNFTMinter.sol:128-135` (mint loop with live max-approval); verification anchor `lib/yield-claim-nft/src/V2/NFTMinterV2.sol:196` (`_mint(recipient, resolvedTokenId, 1, "")`).

**Recommended mitigation**:
- Add `ReentrancyGuard` and tag `batchMint` with `nonReentrant` (overlaps with L-01 — a single import closes both).
- Scope the approval to the exact `paymentAmount` rather than `type(uint256).max` so any reentrant call attempting to drain through the approval is at minimum bounded by the per-call budget.
- Optional defense-in-depth: snapshot `paymentToken.balanceOf(address(this))` before and after the loop and revert if it diverged by more than the dispatcher's expected charge for `count` mints.
- Track the `_mint` vs `_safeMint` choice in `NFTMinterV2` as a cross-submodule dependency: if it ever changes, the mitigations above become required.

---

## [L-04] No guard preventing `nudgePaymentToken == NFTStaker.rewardToken` (defensive hardening)

**Severity rationale**: Low — at the production wiring (single dispatcher, `paymentToken == rewardToken == phUSD`), the existing `nudgePaymentToken != paymentToken` guard at lines 121-126 incidentally protects against the rewardToken collision. The "multi-dispatcher with non-phUSD prime token" scenario is forward-looking speculation; the misconfigured-recipient worst case is a reckless-admin-mistake pattern (C4 known-invalid). The fix is cheap and worth recording so future deployments cannot silently re-open the asymmetry.

**Description**: The contract enforces `nudgePaymentToken != paymentToken` but does NOT enforce `nudgePaymentToken != rewardToken`, where `rewardToken` is `NFTStaker`'s emission asset. In single-dispatcher production wiring, `paymentToken == rewardToken == phUSD`, so the existing equality guard transitively blocks the rewardToken collision. In any multi-dispatcher deployment where one dispatcher uses a non-phUSD prime token (e.g. USDC), the existing distinctness guard would still permit `nudgePaymentToken = phUSD` — which would route staker emissions into the nudge pot.

**Code reference**: `lib/phoenix-nft-staking/src/BatchNFTMinter.sol:76-79` (`setNudgePaymentToken`); existing equality guard at lines 121-126.

**Recommended mitigation**: Pass `NFTStaker`'s `rewardToken` into `BatchNFTMinter` at construction as an immutable, and revert in `setNudgePaymentToken` if `newToken == rewardToken`. Optionally maintain an owner-configurable forbidden-tokens list for additional protocol-internal tokens, and document explicitly in NatSpec that the nudge token MUST be an external incentive token the protocol does not consume elsewhere.

---

## [L-05] Unbounded `count` allows single-tx `latestPrice` flash spike (tail-risk grief)

**Severity rationale**: Low — not a clean theft path. (a) The attacker's existing stake doesn't retroactively accrue at the spiked rate; (b) the mint payment partly funds `V` via the dispatcher hook (50% of mint-debt routes to `NFTStaker`), so the attacker partially self-funds the rate spike; (c) the solvency invariant `balance == rewardBudget + committedDebt` ensures stakers can't claim more than `V`. Net effect is transient runway compression and permanent NFT price-ladder push, neither of which is a clean asset loss. Recorded as Low because a cheap mitigation exists and the same fix reduces M-01's per-cycle damage as a side effect.

**Description**: `count` is unbounded by the contract — any caller can pass an arbitrarily large `count` (subject only to gas limits and `paymentAmount` coverage). A single tx can compound `latestPrice` by `r^count`, where `r = 1 + growthBasisPoints/10_000`. Worked example: at `growth_bps = 250`, a `count = 200` batch produces `r^200 ≈ 138x` price jump in one tx; on `NFTStaker`'s next interaction the new `R` is ~138x larger and the runway is ~138x smaller, potentially exhausting the budget within a single block. The result is honest stakers see accelerated runway depletion and the NFT price ladder is permanently pushed beyond reasonable demand. Distinct from M-01 in that this finding does NOT depend on the nudge feature being active or attractive — it applies to any large-count batch regardless of nudge balance.

**Code reference**: `lib/phoenix-nft-staking/src/BatchNFTMinter.sol:131-134` (mint loop with no `MAX_BATCH_SIZE`).

**Recommended mitigation**: Cap `count` to a reasonable maximum (e.g. `MAX_BATCH_SIZE = 100`) via `require(count <= MAX_BATCH_SIZE, ...)` — analogous to `NFTStaker`'s `MAX_TARGET_APY` bound. Cheapest and most direct. Document the relationship between batch size and `NFTStaker` schedule recompute behavior so off-chain monitoring can flag suspicious large batches. As an alternative (more invasive), cap the per-recompute `latestPrice` jump in `NFTStaker` to dampen flash spikes regardless of caller.

---

## Centralization Risks

Per project documentation (CLAUDE.md), owner control over `BatchNFTMinter` parameters (`setNudgeSize`, `setNudgePaymentToken`, `setPaymentAmount`, `setNudgeRecipient` etc.) and `NFTStaker` configuration (`setStakedId`, `setTargetAPY`, `pause`/`unpause` etc.) is intentional design. These privileges are documented and trusted under the project's threat model, and reckless-admin-mistake patterns are explicitly listed as C4 known-invalid for this audit. No centralization findings are reported.

L-02 above touches operational hardening for the owner's response surface (kill-switch, atomic sweep on rotation) — those recommendations are filed as Low rather than as centralization risks because they harden the *non-malicious* owner's response to an active attack, not because they limit owner power.
