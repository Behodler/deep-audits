# Tier-2 Code-Level Interaction Findings — `phoenix-nft-staking` run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312` (read-only)
- **Mode**: REGRESSION. Changed in-scope: `src/BatchNFTMinterMultiToken.sol`, `src/NudgeStreamer.sol`, `src/INudgeStreamer.sol`
- **Inputs consumed**: `profiles/{BatchNFTMinterMultiToken,NudgeStreamer,INudgeStreamer,BatchNFTMinter,NFTStaker,NFTStakerDepletionV2}.md`, `tier1/static-analysis.md`
- **Cross-repo reads (top-level HEADs, not nested pins)**: `lib/yield-claim-nft` @ `d4cc563`

---

## 0. Executive summary

| ID | Site | Class | Severity read |
|---|---|---|---|
| **CODE-01** | `BatchNFTMinterMultiToken.sol:528-536` | availability — unisolated cross-contract flush loop, fires even for non-qualifying batches | **Low** |
| **CODE-02** | `NudgeStreamer.sol:158`, `:199` → `yield-claim-nft/NudgeRatchet.sol:157-160` | cross-contract failure-isolation asymmetry; a streamer revert bricks the **mint**, not just the flush | **Low** (cross-repo; root cause in `yield-claim-nft`) |
| **CODE-03** | `NudgeStreamer.sol:55-62`, `:250-265` | falsely-exhaustive NatSpec on a load-bearing custody invariant | **QA/Low** (tier-1 `LOCAL-NS-01`; DoS half adjudicated down — see §1) |
| **CODE-04** | `BatchNFTMinterMultiToken.sol:289` vs `NudgeStreamer.sol:15-17` | duck-typed structural guard, no compiler enforcement | **QA** |

**KILLED**: the merged Leg-A+Leg-B High/Medium lead as framed (Leg B is not plain-ERC20 reachable — §1), **S-03** entirely (§4), and four reentrancy-class candidates (§5).

---

## 1. The merged lead — Leg B is KILLED; Leg A survives, rescoped and downgraded

### 1.1 Question 1 — is Leg B reachable, and by what mechanism?

Leg B claims the aggregate custody invariant `Σ buffer_i <= balanceOf(streamer)` (asserted at `NudgeStreamer.sol:56-62` and `:258`) can be broken by *post-credit* erosion. I enumerated **every** way `balanceOf(streamer)` can decrease, or `Σ buffer_i` increase, without a matching counterpart. Exhaustive, because the streamer has exactly one state variable and four write sites:

| Mechanism | Site | Reachable with a plain ERC20? |
|---|---|---|
| `_settle` outbound transfer | `:242-243` | Decrements `buffer` and `balanceOf` by the **same** `settled`. Invariant-neutral. **Not a mechanism.** |
| `collectNudge` credit | `:193-201` | Credit is `min(measured delta, amount)`. Cannot over-credit in either direction. **Not a mechanism.** |
| `registerStream` re-registration | `:134-140` | Settles at the old rate, then writes `duration`/`rewardPerSecond`/`lastUpdate` only. **Never touches `buffer`.** **Not a mechanism.** |
| Direct `transfer` to the streamer (bypassing `collectNudge`) | — | *Increases* balance with no buffer credit → surplus idle. **Safe direction** (and permanently stranded — ledger `4a1d8edc92`). |
| Negative rebase | token-side | **NO — weird ERC20 only.** |
| Deflationary burn-on-hold | token-side | **NO — weird ERC20 only.** |
| Token-admin clawback / balance-zeroing of a holder | token-side | **NO — weird ERC20 / token-admin only.** |
| `recipientBatchMinter == address(this)` (self-settle: `buffer` down, balance flat) | `:243` | Wrong direction (*under*-states), and unreachable anyway: `registerStream:127` calls `isNudgeToken` on the streamer, which does not implement it → reverts. |
| Streamer approving a third party to pull | — | No `approve` call exists anywhere in the contract. |
| Reentrancy during `registerStream` (not `nonReentrant`) into `collectNudge` | `:134` → `:152` | Needs a transfer-hook token. Even then: `_settle` has completed, `collectNudge` credits a measured receipt and recomputes over the old `duration`, then `registerStream` overwrites `duration`/`rewardPerSecond`/`lastUpdate` from the *current* `s.buffer`. Consistent — **no over-statement, and hook-token-only regardless.** |

**Conclusion: there is NO plain-ERC20 path to an over-stated aggregate buffer.** For a well-behaved ERC20 the invariant at `:258` genuinely holds — the profiler's §1.5 "NOT preserved against post-credit balance erosion" is correct as a *statement about the token*, but every instantiation of it is a weird-ERC20 property.

**The USDT carve-out does not rescue it.** USDT is the one non-standard token C4 keeps in scope here, and it does have a balance-zeroing admin path (`destroyBlackFunds` on a blacklisted holder). But that requires Tether to blacklist the streamer first — and **a blacklisted streamer cannot `transfer` at all**, so `_settle`'s `safeTransfer` at `:243` already reverts before any buffer over-statement becomes the operative cause. The blacklist, not Leg B, is the brick. Leg B adds nothing on the USDT path.

**Verdict: Leg B KILLED as a standalone finding.** Its only reachable mechanisms are fee-on-transfer/rebasing/deflationary/clawback token behaviours, which are permanently-invalid standalone findings for this project (C4 known-invalid, USDT excepted, and the USDT case collapses as above). This materially caps the merged lead: it cannot carry a High or a Medium.

### 1.2 Question 2 — does the shared-balance-drain step actually follow?

Yes — *conditionally on* Leg B, which is why it does not land. Confirmed the failure is hard, not soft:

```solidity
// NudgeStreamer.sol:238-246
function _settle(Stream storage s, address recipient, address token) private {
    uint256 settled = _accrued(s);
    s.lastUpdate = block.timestamp;
    if (settled > 0) {
        s.buffer -= settled;
        IERC20(token).safeTransfer(recipient, settled);   // <-- :243, THE REVERTING LINE
```

`_accrued` (`:266-271`) caps at the **per-stream** `buffer` only; it consults `balanceOf` nowhere. So when the aggregate is over-stated, `:243` attempts a transfer the streamer cannot fund and `SafeERC20.safeTransfer` propagates the token's revert verbatim (`ERC20InsufficientBalance(streamer, held, settled)` for an OZ token; `"ERC20: transfer amount exceeds balance"` for USDC/USDT-class). There is **no** try/catch, no `min(settled, balanceOf)` clamp, and no partial-settle fallback. `pullPendingStream:224` calls `_settle` unguarded, so it reverts too. Confirmed: fails **hard**, exactly as the lead described.

Note the asymmetry that makes this survivable in practice even under Leg B: `pullPendingStream:222` returns silently for an **unregistered** stream (`s.duration == 0`), which is the property that makes the blind loop safe for unregistered entries. It is *not* a fail-soft for a registered one.

### 1.3 Question 3 — is there anything that defeats Leg A?

**No. Verified, corroborating the profiler and ledger `4a1d8edc92`.**

```solidity
// BatchNFTMinterMultiToken.sol:528-536
{
    address _nudgeStreamer = nudgeStreamer;
    if (_nudgeStreamer != address(0)) {
        uint256 nudgeCount = _nudgeTokens.length;
        for (uint256 i; i < nudgeCount; ++i) {
            INudgeStreamer(_nudgeStreamer).pullPendingStream(_nudgeTokens[i]);   // :533 — bare call
        }
    }
}
```

- No `try/catch` at `:533`; no per-token isolation; no skip-on-failure; no continue-on-revert.
- `NudgeStreamer` has **no** `pause`, **no** `rescueERC20`, **no** owner withdrawal, and **no** deregistration path. `s.duration` is written only at `:136`, and `:126` rejects `duration == 0`, so a registered pair can never be un-registered. Verified by exhaustive write-site enumeration.
- The only owner lever is on the *batchMinter* side: `setNudgeStreamer(address(0))` (`:297-300`) disables the whole flush, and `setNudgeTokenWhitelist(token, false)` removes the offending entry from the loop. **Both are real escapes** — this is the reason CODE-01 is a Low and not a Medium: an owner can restore `batchMint` availability in one transaction. The cost is that de-whitelisting strands that stream's buffer permanently (`4a1d8edc92`), so the escape converts an availability outage into stranded value.

### 1.4 Question 4 — smallest concrete brick scenario

Because Leg B is weird-token-only, the *cheapest honest* trigger is not Leg B. Ranked by realism:

**Scenario A (most realistic, no weird token): blocklist/pause on a real nudge token.**

1. Owner whitelists USDC as a nudge token (`setNudgeTokenWhitelist(USDC, true)`).
2. Owner registers a stream: `streamer.registerStream(batchMinter, USDC, 7 days)`.
3. A donor funds it: `collectNudge(batchMinter, USDC, 10_000e6)` → `buffer = 10_000e6`, `rewardPerSecond` set.
4. Time passes; `pendingStream > 0`.
5. Circle pauses USDC, **or** blocklists either the streamer or the batchMinter.
6. **Any** caller calls `batchMint(count, recipient, paymentAmount, minRewards)` — qualifying or not, any `count`, any `paymentAmount`.
7. `:533` → `pullPendingStream(USDC)` → `_settle` → `:243` `safeTransfer` → revert `"Blacklistable: account is blacklisted"` (or `"Pausable: paused"`).
8. **`batchMint` reverts for every user.** Recovery: owner calls `setNudgeStreamer(0)` or de-whitelists USDC.

Precondition is a third-party action — extraordinary, which is what holds this at Low.

**Scenario B (the Leg-B path, for completeness — weird token, C4-invalid standalone).** Same as above with a negative-rebasing nudge token; after step 3 a rebase shrinks the streamer's balance below `Σ buffer_i`; step 7 reverts `ERC20InsufficientBalance(streamer, held, settled)`. Two registered pairs on the same token make it sharper (first pair settles fully, sibling's `_settle` reverts), but one pair suffices.

**PoC shape** (for `workspace/phoenix-nft-staking`, if the classifier wants one): deploy a `MockBlocklistERC20`, whitelist + register + fund, warp 1 day, blocklist the streamer, then `vm.expectRevert` on `batchMint`. The scenario needs no attacker capital and no attacker contract — that is the notable part; the *trigger* is what is expensive.

### 1.5 CODE-01 — the finding, as it actually stands

- **Contract:line**: `src/BatchNFTMinterMultiToken.sol:533` (loop `:531-534`, block `:528-536`), inside `batchMint` (`:464-727`)
- **Root cause**: an unbounded, unisolated loop of external calls into a semi-trusted contract, on a path where **every** iteration is optional for the caller's own outcome, with no `try/catch`.
- **Failure path / exact revert**: §1.4 above; reverting line is `NudgeStreamer.sol:243`, propagated through `pullPendingStream:224` → `:533`.
- **Preconditions**: `nudgeStreamer != address(0)`, at least one whitelisted token with a registered, non-empty stream, and one revert trigger from §1.4.
- **Who is harmed**: every `batchMint` caller. Not the protocol's funds — nothing is lost, and the pot/buffer are intact — purely availability, and the owner holds two one-transaction escapes (§1.3).
- **The genuinely new, plainly-reachable part — non-qualifying batches lost their structural immunity.** This is the incremental harm the lead did not name, and it needs no weird token:
  - `_snapshotRewards:801` reads `available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0` — the ternary **short-circuits**, so a non-qualifying batch makes **zero** `balanceOf` calls on nudge tokens.
  - `_payRewards:831` is `if (amount == 0) continue;` — with an all-zero snapshot a non-qualifying batch makes **zero** `transfer` calls on nudge tokens.
  - Therefore, before the flush loop existed, a caller with `count < nudgeSize` was **structurally immune** to any nudge-token misbehaviour. The flush loop at `:528-536` is **not gated on `qualifies`** and is now that caller's *only* nudge-token exposure — for **zero benefit**, since a non-qualifying batch pays out nothing.
  - **The fix is behaviour-neutral, and I verified that**: `_settle` advances `lastUpdate` but never recomputes `rewardPerSecond` (write sites are `:139` and `:206` only), and `_accrued` derives from `block.timestamp - lastUpdate`. Skipping a settle therefore loses **nothing** — the same accrual is settled by the next qualifying batch's flush. Gating the loop on `qualifies` changes no reward arithmetic anywhere.
- **Recommendation** (two independent, both cheap):
  1. `if (_nudgeStreamer != address(0) && qualifies) { … }` — provably behaviour-neutral (above), removes the exposure entirely for non-qualifying callers, and saves them N external calls of gas.
  2. `try INudgeStreamer(_nudgeStreamer).pullPendingStream(_nudgeTokens[i]) {} catch { emit StreamFlushSkipped(_nudgeTokens[i]); }` — mirrors the isolation contract the sibling `BalancerPoolerV2._dispatch` already applies to the *same* streamer hop (§2). A skipped flush is a no-op: the buffer stays put and streams out at the next batch.
- **Severity read: Low.** Availability impact is real and total while it lasts, but every enumerated trigger is individually either owner-obvious (broken/non-ERC20 token whitelisted), third-party-extraordinary (Circle/Tether blocklist or pause), C4-permanently-invalid (weird-token erosion), or owner-observable (gas growth on an owner-grown whitelist). Nothing is lost, and the owner has two single-transaction escapes. I found **no** plainly-reachable, non-owner, non-third-party trigger — which is precisely why this is not a Medium. If a later run finds one, this reopens **at Medium**: the impact side already qualifies ("protocol function/availability impacted"); only the precondition side is holding it down.
- **Disclosure / do-not-collapse**: distinct from ledger `bfdb50105e` (wont-fix — a shrinking token reverting the batch at the `_payRewards` site, `:833`). Same *class*, different *site*, and materially wider blast radius: `_payRewards` is skipped for zero amounts and for non-qualifying batches, the flush loop is skipped for neither. Also distinct from `4a1d8edc92` (no rescue on the streamer) — they **compound**: the owner's escape from CODE-01 is the action that triggers `4a1d8edc92`.

---

## 2. CODE-02 — cross-contract failure-isolation asymmetry: a streamer revert bricks the *mint*, not just the flush

This is the interaction-level finding the lead did not anticipate, and it has a **wider blast radius than CODE-01**. Both production donors were read at top-level `lib/yield-claim-nft@d4cc563`.

**`BalancerPoolerV2` isolates the streamer hop. `NudgeRatchet` does not.**

```solidity
// yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol:_dispatch  — ISOLATED
try this._psmDonate(remainingUSDS) {}
catch { emit DonationSkipped(remainingUSDS); }   // collectNudge lives inside _psmDonate
```
Its NatSpec (`:299-307`) names this explicitly, including "**streamer unset, stream not registered**" among the reverts it deliberately swallows, and story-047 is documented as having put the streamer hop *inside* the envelope on purpose: "*A streamer misconfiguration therefore parks USDS and emits `DonationSkipped` rather than reverting the mint*."

```solidity
// yield-claim-nft/src/dispatchers/NudgeRatchet.sol:157-160  — NOT ISOLATED
address streamer = nudgeStreamer;
require(streamer != address(0), "NudgeRatchet: nudgeStreamer unset");
IERC20(_token).forceApprove(streamer, bal);
INudgeStreamer(streamer).collectNudge(batchMinter, _token, bal);   // bare — any revert propagates
```

**Propagation chain (all four hops verified in source):**

`NudgeStreamer.collectNudge` revert → `NudgeRatchet._dispatch:160` → `ATokenDispatcherV2.dispatch` → `NFTMinterV2._executeMint:191` → `NFTMinterV2.mint:159` → `BatchNFTMinterMultiToken.batchMint:650`.

So a streamer revert on the NudgeRatchet leg does not merely skip a flush — **it reverts the mint itself**, for every minter on that dispatcher, batched or single. Reachable revert sources inside `collectNudge`:

- `NudgeStreamer__NotRegistered()` (`:158`) — **plainly reachable, no weird token.** Fires whenever `streams[batchMinter][_token].duration == 0`. The documented wiring order (`NudgeRatchet.sol:42-43`) is `registerStream` **then** `setNudgeStreamer`; performing them in the reverse order bricks every mint through that dispatcher until `registerStream` lands.
- `NudgeStreamer__ZeroReceived()` (`:199`) — **new at story-031**, this run's diff. Not reachable for USDC, but story-031 strictly *added* a revert to a function on an un-isolated path, and the interface NatSpec (`INudgeStreamer.sol:8-18`) documents the semantics change without noting that one leg cannot absorb it.
- `_settle`'s `safeTransfer` at `:243` — same triggers as CODE-01 §1.4, now bricking the mint rather than the flush.
- `NudgeStreamer__ZeroAmount()` (`:163`) — already defended on both donor sides by load-bearing `bal > 0` / `gemAmt > 0` guards, both explicitly commented as such. Correctly handled; noted so a future editor does not remove them.

**Severity read: Low.** All reachable triggers fail **closed** and are recoverable in one owner transaction (`registerStream`, or `setNudgeStreamer` on the dispatcher); no value is lost; the wiring order is documented at `NudgeRatchet.sol:29-43`. What makes it reportable rather than nothing is the **asymmetry**: the same protocol wraps the same external hop to the same contract in an explicit, documented, story-mandated isolation envelope on one dispatcher and leaves it bare on the other, and story-031 widened the un-isolated leg's revert surface. A competent owner reading `BalancerPoolerV2`'s isolation contract would reasonably assume it applies to the streamer hop generally — Law-3 footgun test: **surprise ⇒ report.**

**Scope note for the finding-manager**: the reverting lines (`NudgeStreamer.sol:158`, `:199`, `:243`) are in scope for this project; the missing `try/catch` (`NudgeRatchet.sol:157-160`) is in `yield-claim-nft` and should be cross-filed to that project's ledger (adjacent to the run-19 stories 046/047 streamer-routing entries). Do not suppress it here on the grounds that the fix site is elsewhere.

---

## 3. CODE-03 / CODE-04 — adjudications of the tier-1 and static-analysis leads

**CODE-03 (tier-1 `LOCAL-NS-01`, `NudgeStreamer.sol:55-62` + `:250-265`) — VALID as a documentation finding; its DoS half is adjudicated DOWN.**

The NatSpec claim is genuinely over-broad: `:56-57` says the credit is correct "**by construction** rather than by convention", and `:258-265` states `Σ buffer_i <= balanceOf(this)` as established "at ONE site". Per §1.1 the construction closes the **fee/shortfall direction at credit time** and nothing else, and the text does not say so. Per repo policy, in-source NatSpec carries no suppression authority, and a falsely-exhaustive claim on a load-bearing invariant **raises** rather than lowers severity — a future editor reading `:258` will believe the aggregate is structurally guaranteed and will not add the clamp that isn't there.

But the consequence chain the tier-1 profile attached to it ("⇒ `batchMint` bricked") is **not independently reachable** (§1.1), so the finding is a documentation-accuracy issue, not a DoS. **QA/Low.** Distinct from ledger `6f46ec80f1` (a *different* overclaim — burst-capture) and `bfdb50105e`; new claim, new site, introduced at `2ba764e`. Recommendation: reword `:55-62` and `:250-265` to name the direction actually closed ("credit-time shortfall"), and state plainly that post-credit erosion is undefended — then CODE-01's recommendation #2 becomes the structural answer rather than the missing one.

**CODE-04 (static-analysis S-02) — QA only. Assessed and downgraded.**

`NudgeStreamer.registerStream:127` uses `IMultiTokenNudgeWhitelist(batchMinter).isNudgeToken(token)` as its sole structural guard; `BatchNFTMinterMultiToken:159` declares `Ownable, Pausable, ReentrancyGuard, IPausable` and **not** the interface, even though `:289` implements a byte-identical signature (`isNudgeToken(address) external view returns (bool)` — same selector; the call works today, verified).

Signature-drift hazard, honestly weighed: a rename or signature change on either side compiles clean and then **fails closed** — `registerStream` reverts on empty returndata, at an `onlyOwner` admin call, with no funds in motion. There is no path where drift produces a *false accept* except an owner supplying an address with a permissive `fallback`, which is obvious owner error (Law 3, suppress). Declared `external view` ⇒ `STATICCALL` ⇒ cannot reenter or mutate. So: worth fixing (`contract BatchNFTMinterMultiToken is …, IMultiTokenNudgeWhitelist` makes the compiler enforce a guard the design already leans on, and the interface should move out of `NudgeStreamer.sol` into its own file), but **not a security finding**. QA.

---

## 4. S-03 — KILLED

**Claim**: `BatchNFTMinterMultiToken.sol:650` discards `nftMinter.mint()`'s `bool` while `budget` is debited at `:649` **before** the call, so a `false`-returning minter would burn budget and mint nothing.

**Read at top-level `lib/yield-claim-nft@d4cc563` (not a nested pin), `src/NFTMinterV2.sol:159-201`:**

```solidity
function mint(uint256 index, address recipient) external returns (bool) {
    return _executeMint(index, recipient, "");
}

function _executeMint(uint256 index, address recipient, bytes memory extraData) internal returns (bool) {
    require(!paused, "Contract is paused");
    require(config.dispatcher != address(0), "NFTMinterV2: index not registered");
    require(!config.disabled, "NFTMinterV2: dispatcher is disabled");
    …
    return true;      // :200 — the ONLY return statement
}
```

`_executeMint` has exactly **one** `return`, a literal `true`, on the sole success path. Every failure mode is a hard revert: three `require`s (`:171`, `:173`, `:174`), `SafeERC20.safeTransferFrom` (`:183`), the dispatcher's own `dispatch` (`:191`, itself `whenNotPaused`), and OZ `_mint`'s acceptance check (`:196`). There is **no `return false` anywhere in the contract**, so the discarded `bool` at `:650` carries zero information and can never mask a no-op. **S-03 KILLED** — it is not even a QA item beyond "prefer `require(mint(...))` for future-proofing against a swapped minter", and the minter is owner-pinned.

**Two bonus verifications, closing tier-1 profile §6 items 1 and 2** (`BatchNFTMinterMultiToken.md`), which were explicitly left unverified:

- **Charge-then-ramp is CONFIRMED**: `:183` charges `config.price` via `safeTransferFrom`, `:188` then ramps `config.price += price * growthBasisPoints / 10000`. So the pre-mint `configs()` re-read at `BatchNFTMinterMultiToken:646` returns exactly what that mint will charge. The NatSpec claim at `:631-636` is **accurate**, and the per-iteration re-read is correctly load-bearing. Item 1 CLOSED.
- **`mint` charges exactly `price`, never more**: `:183` transfers `price` and nothing else; the batchMinter's allowance at `:648` is exactly `price`, so an over-charge would revert (fail closed) and an under-charge is impossible. Item 2 CLOSED.

Legacy `BatchNFTMinter.sol:287` — same analysis, same kill.

---

## 5. Reentrancy-class checklist — every row walked

| Class | Verdict |
|---|---|
| **Classic single-fn** | CLEARED. `NudgeStreamer._settle:240-243` writes `lastUpdate` and `buffer` **before** the transfer; a reentrant `pullPendingStream` finds `_accrued == 0`. `batchMint` performs zero storage writes at all. |
| **Cross-contract (A→B→A)** | CLEARED, but note the real path tier 1 missed the shape of: `batchMint:650` → `NFTMinterV2.mint` → `NudgeRatchet._dispatch` → `NudgeStreamer.collectNudge` → `_settle:243` → `safeTransfer` **to the batchMinter, mid-mint-loop, after the `:538` snapshot**. This is a genuine A→C→B→A value flow. Harmless, and I verified *why*: the arriving amount raises the batchMinter's balance, and (a) `budget` is tracked, never re-derived from `balanceOf` after `:604`, so the refund cannot capture it; (b) `snapshot` was frozen at `:538`, so `_payRewards:833` cannot pay it out; (c) it becomes `D`, benefiting the *next* claimant. **This also re-verifies ledger `2d34673536`'s closure through a path story-032 newly made cheap** — see §6. |
| **Cross-function** | CLEARED. `batchMint` is `nonReentrant` and storage-write-free; `NudgeStreamer`'s two value-moving entries are both `nonReentrant`. The one un-guarded entry is `registerStream` (`onlyOwner`), analysed in §1.1 row 10 — consistent, and hook-token-only. |
| **Read-only reentrancy** | CLEARED, with the window identified honestly. `NudgeStreamer.pendingStream:230` is the only public view another protocol could consume, and there **is** a transient window: between `:194` (`transferFrom`) and `:201` (`buffer += received`) tokens have arrived but the buffer is not yet credited, so `pendingStream` **under**-states. Under-statement is the safe direction, the window needs a transfer-hook token to be observable, and I confirmed by grep across `phoenix-nft-staking/src`, `yield-claim-nft/src`, and `phoenix-phase-2-staging` that there is **no on-chain consumer** of `pendingStream` — the only reader is a staging console log (`script/interactions/TestNudgePayout.s.sol:170`) and the off-chain UI. No integrator to victimise. |
| **ERC721 receive-hook** | N/A — no ERC721 anywhere in the flow. |
| **ERC1155 receive-hook** | CLEARED — **and this corrects tier 1.** `BatchNFTMinterMultiToken.md` §1.8 states "no inbound ERC1155 receive-hook surface … the minted NFTs go to `recipient`, never to `address(this)`". True about `address(this)`, but `recipient` is **caller-chosen** (`batchMint`'s 2nd arg) and `NFTMinterV2._executeMint:196` calls OZ `_mint(recipient, id, 1, "")`, which invokes `onERC1155Received` on a contract recipient — so an attacker **does** get a callback point inside the mint loop, `count` times. Cleared anyway, and the reason is structural, not accidental: re-entering `batchMint` is blocked by `nonReentrant`; `rescueERC20` is `onlyOwner`; the hook cannot move tokens *out* of the batchMinter (no allowance); and every post-`:538` balance-derived quantity is either the tracked `budget` or the frozen `snapshot`, so pushing balance *in* only inflates `D` for the next claimant. Recording the surface because the profile denies it exists, and a future edit that introduced a single storage write or a `balanceOf` re-derivation inside `batchMint` would make it live. |
| **ERC777 `tokensReceived`/`tokensToSend`** | N/A for reachability — requires an ERC777 nudge/payment token, i.e. weird-ERC20 (C4-invalid). Mechanically identical to the hook-token rows above; all clear for the same reasons. |

---

## 6. Positive verifications and watch-notes (no finding)

- **Ledger `2d34673536` (fixed) — closure HOLDS, but its second line of defence is gone.** The mechanism (streamed buffer leaking to the caller via the step-10 sweep) remains closed by the tracked, budget-sourced refund. I re-verified it through the *new* mid-mint-loop settle path (§5, cross-contract row) as well as the `:533` flush path. **Watch-note**: story-032 deleted the admin-time `BatchMint__RewardTokenIsPaymentToken` check, which is what previously made the precondition (`paymentToken ∈ _nudgeTokens`) awkward to reach. The closure now rests **solely** on `budget` never being re-derived from `balanceOf` after `:604`. Not an expired closure — but any future edit re-deriving `budget` from a balance reading reopens `2d34673536` *and* `ycn19h1` at once, and the admin barrier that used to blunt it is no longer there. Flag if `budget`'s write sites ever exceed `:604` and `:649`.
- **No reentrancy-lock deadlock between the flush loop and the mid-mint `collectNudge`.** The `:531-534` loop makes N *separate* calls, each entering and releasing `NudgeStreamer`'s `nonReentrant` independently, and all complete before the mint loop at `:645`. So `collectNudge` at `:650`-depth finds the guard free. Worth stating: had the flush been wrapped in a single streamer-side guarded call, **every** `batchMint` through the NudgeRatchet dispatcher would revert `ReentrancyGuardReentrantCall`. Cleared, but fragile to a future "batch the flush into one streamer call" optimisation.
- **Both donor-side zero-amount guards are load-bearing and correct.** `NudgeRatchet:157` (`bal > 0`) and `BalancerPoolerV2:324` (`gemAmt > 0`) each exist solely to avoid `NudgeStreamer__ZeroAmount()` and are commented as such. Do not let a future cleanup remove them.
- **`INudgeStreamer` is vendored into `yield-claim-nft` via a `phoenix-nft-staking/` remapping** (`import {INudgeStreamer} from "phoenix-nft-staking/INudgeStreamer.sol"`), i.e. a submodule pin, not a copy. story-031 correctly kept the signature unchanged, so no ABI drift on the three dispatcher call sites. Verified.
- **Not re-filed** (tier-1 confirmed present, ledger-tracked): `4a1d8edc92`, `aaebb4b9b0`, `6f46ec80f1`, `cf332bf46c`, `6b8faaf6dc`, `bfdb50105e`, `51aed27661`, `38ea47b14c`, `990d8c37b4`, `43e8c48626`.
- **Not re-filed** (settled per run instructions): `paymentToken == nudgeToken` collision and its arbitrage (owner-permitted 2026-07-25); caller-supplied `rewardTokens` (structurally impossible); both ordering constraints (verified at `9611312` by tier 1); NFT redemption value (none).
