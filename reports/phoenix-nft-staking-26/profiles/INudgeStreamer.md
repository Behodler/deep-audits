# Contract Profile — `src/INudgeStreamer.sol`

- **Commit**: `9611312`; last changed at `2ba764e` (`[story-031]`)
- **Solidity**: `^0.8.20` · **LOC**: 43 · pure interface, no state, no code
- **Depth**: FULL (in-scope changed file)

---

## 1. Verified local properties

An interface declares no behaviour, so there are no runtime properties to verify. The auditable properties are **ABI stability** and **documentation faithfulness**.

### 1.1 ABI — unchanged at `2ba764e`

`git diff d2506c1 2ba764e -- src/INudgeStreamer.sol` is **comment-only**. All four selectors are byte-identical:

| Declaration | Changed? |
|---|---|
| `collectNudge(address,address,uint256)` | signature unchanged; **semantics changed** (§2) |
| `pullPendingStream(address)` | no |
| `pendingStream(address,address) view returns (uint256)` | no |
| `registerStream(address,address,uint256)` | no |

**VERIFIED — no ABI break.** This is deliberate and correctly reasoned at `:20-23`: donors `forceApprove` an exact amount and ignore returndata, and sibling repos compile against **vendored copies** of this interface. Adding a `returns (uint256 credited)` would have forced every vendored copy to be regenerated in lockstep. Keeping the signature is the right call for a multi-repo deployment.

### 1.2 Interface hygiene

- `import {IERC20} …` at `:4` is **unused** — no declaration in the file references `IERC20`. Dead import; harmless, pre-existing (not introduced at `2ba764e`). QA-tier at most.
- Uses the abbreviated `uint` alias for `amount` (`:27`) and `duration` (`:41`) while `pendingStream` returns `uint256` (`:36`). Cosmetic inconsistency; identical ABI.
- No `@notice`/`@title` on individual functions, no custom errors declared, no events declared. `registerStream`'s `onlyOwner` gate and `pullPendingStream`'s guaranteed-no-op-on-unregistered contract — both of which `BatchNFTMinterMultiToken.batchMint` structurally depends on — remain **undocumented here**. Ledger `cf332bf46c` (QA, open) covers exactly this; story-031 addressed the `collectNudge` portion only. **Re-confirmed, partially addressed, do not close.**

---

## 2. The story-031 semantic change — the load-bearing content of this file

The entire diff is the doc block at `:8-23`, and it is the **only place in the ABI surface** where the request-vs-credit distinction is expressed. Verbatim contract now promised to integrators:

```
`amount` is a REQUEST, not a credit. The stream is credited with the
receipt measured across the pull, capped at `amount`:
`min(balanceAfter - balanceBefore, amount)`.
```

Checked against `NudgeStreamer.sol:193-199` — **the documentation is faithful to the implementation**:

| Documented claim | Implementation | Faithful? |
|---|---|---|
| credit is `min(balanceAfter − balanceBefore, amount)` | `:195-196` | ✅ exact |
| FoT/taxed token credits **less** than `amount` | `:196` cap only binds upward | ✅ |
| a token pushing extra balance in credits **exactly** `amount`, surplus uncredited | `:196` | ✅ |
| `rewardPerSecond` derived from the **credited** value | `:206` reads `s.buffer`, which took `received` | ✅ |
| `NudgeCollected.amount` reports the credited receipt | `:211` emits `received` | ✅ |
| non-zero `amount` delivering nothing **reverts** | `:199` `NudgeStreamer__ZeroReceived` | ✅ |
| credited amount deliberately **not** returned | `void` return | ✅ |

**No documentation-vs-code divergence in this file.** (Contrast `NudgeStreamer.sol:55-62`, where the *implementation* file makes a broader "by construction" custody claim that does not survive balance-decreasing tokens — see `profiles/NudgeStreamer.md` §5.1. That overclaim is **not** repeated here; `INudgeStreamer` confines itself to the pull window, which is exactly the scope the code establishes.)

---

## 3. Interface abstraction — the integrator's contract

What a **donor** may assume:
- `collectNudge` is permissionless, push-only, and reverts if `(recipientBatchMinter, token)` is unregistered.
- The donor's ERC20 allowance to the streamer is consumed for the full `amount` regardless of any transfer tax (the token takes its cut on its own side), so no residual allowance is stranded.
- **The credited amount is not observable on-chain.** A donor cannot learn what landed; it must read `NudgeCollected` off-chain or query `streams(batchMinter, token).buffer`.

What a **batchMinter** may assume:
- `pullPendingStream(token)` is a no-op — **not** a revert — for an unregistered token. Undocumented here, documented only in the implementation (`NudgeStreamer.sol:216-217`). This is the property `BatchNFTMinterMultiToken:532-534` relies on to loop blindly over its whole whitelist.
- It receives the settled stream directly; `msg.sender` is both the key and the recipient.

What an **owner** may assume:
- `registerStream` is `onlyOwner` (**undocumented in this interface**) and gates on the target's `isNudgeToken`.

What **nobody** may assume:
- there is no deregistration, no pause, and no rescue declared — and none exists in the implementation.

---

## 4. Local findings

### 4.1 LOCAL-INS-01 — silent semantic repoint of `NudgeCollected.amount` across an unchanged ABI

- **Type**: off-chain consumer hazard
- **Severity**: local-low / QA (same root cause as `profiles/NudgeStreamer.md` §5.2 — **file once, not twice**)

Because the ABI is byte-identical, a vendored copy of this interface in a sibling repo compiles unchanged against both the old and new `NudgeStreamer`, and an indexer reading `NudgeCollected` sees the same topic and field layout with a different meaning. **There is no on-chain or compile-time signal of the change.** The doc block at `:8-23` is the only notice, and vendored copies will carry the *old* comment until manually resynced — which is precisely the population most likely to still assume the sent amount.

- **Recommendation**: bump a version marker, or resync the vendored copies in the same release wave. If any donor contract derives an accounting figure from its own sent amount, that figure now over-states the pot for taxed tokens.
- **UNVERIFIED / handoff**: the production donor is `NudgeRatchet.dispatch` in `yield-claim-nft`. I did not read it (out of scope for this profile) and therefore **cannot say** whether a vendored stale copy or a sent-amount-derived counter exists there. This is a cross-repo item for the interaction scanner, and it is only reachable at all if a taxed or rebasing token is the nudge asset.

### 4.2 LOCAL-INS-02 — unused `IERC20` import

- **Severity**: QA. `:4`. Pre-existing, not introduced by story-031.

### 4.3 Already-filed, re-confirmed

`cf332bf46c` (QA, open) — interface under-documents no-op / `onlyOwner` / recompute-on-deposit-only. **Partially addressed**: `collectNudge` is now thoroughly documented; `pullPendingStream`'s no-op contract, `registerStream`'s `onlyOwner`, and recompute-on-deposit-only remain absent (`:30-42`). Do not close.

---

## 5. Could not verify

1. Whether vendored copies of this interface in sibling repos have been resynced to the `2ba764e` doc block. Cross-repo.
2. Whether any external donor implementation relies on the sent amount. Cross-repo (see §4.1).
