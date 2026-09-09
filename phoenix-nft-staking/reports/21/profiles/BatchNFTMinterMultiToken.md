# Contract profile — `src/BatchNFTMinterMultiToken.sol`

- Run: `phoenix-nft-staking-21`
- Submodule HEAD: `c881a42`
- Profiled: **COLD** (file is NEW at `fba4991`, story-022 Stage 7)
- Solidity: `^0.8.20` — checked arithmetic, no `unchecked` blocks, no assembly
- LOC: 462 (313 of which are NatSpec/comment)
- Inheritance: `Ownable`, `Pausable`, `ReentrancyGuard`, `IPausable` (`:82`)

## 1. Provenance

`BatchNFTMinterMultiToken.sol@c881a42` is byte-identical to `BatchNFTMinter.sol@0d1a0b2`
**apart from two lines** — the `@title` (`:14`) and the `contract` declaration (`:82`).
Mechanically verified; see `FORK-PARITY-5WAY.md` §B. **No unannounced change is hiding in the
"pure rename" commit.**

Consequence for downstream agents: **every run-20 finding filed against `BatchNFTMinter`'s
multi-token nudge now lives on THIS contract under a NEW fingerprint
(`BatchNFTMinterMultiToken:batchMint:*`) and will NOT be caught by fingerprint dedup.**
Reconcile by root-cause class, not by hash. See §7.

## 2. External / public surface

| Function | Vis | Access | Guards | State written | External calls |
|---|---|---|---|---|---|
| `constructor(address)` `:85` | — | — | — | `Ownable._owner` | none |
| `setTokenMinter(ITokenMinterV2)` `:150` | external | `onlyOwner` | none (callable while paused) | `tokenMinter` | none |
| `setDispatcherIndex(uint256)` `:159` | external | `onlyOwner` | none | `dispatcherIndex` | none |
| `setNudgeSize(uint256)` `:166` | external | `onlyOwner` | none | `nudgeSize` | none |
| `setPauser(address)` `:173` | external | `onlyOwner` | none | `pauser` | none |
| `pause()` `:181` | external | `onlyPauser` `:142` | — | `Pausable._paused` | none |
| `unpause()` `:186` | external | `onlyPauser` | — | `Pausable._paused` | none |
| `rescueERC20(IERC20,address,uint256)` `:208` | external | `onlyOwner` | **no `nonReentrant`**, callable while paused | none | CALL `token.transfer` |
| `batchMint(uint256,address,uint256,address[],uint256[])` `:294` | external | **permissionless** | `whenNotPaused`, `nonReentrant` | none directly | see §4 |

Internal: `_snapshotRewards(...) private view` `:416`, `_payRewards(...) private` `:452`.

There are **no view getters** other than the four public auto-getters
(`tokenMinter`, `dispatcherIndex`, `nudgeSize`, `pauser`) and OZ's `owner()`/`paused()`.

## 3. State variables and mutators

| Var | Type | Written by | Read by |
|---|---|---|---|
| `DUST_THRESHOLD` `:90` | `uint256 constant = 1e6` (internal) | — | `batchMint:382` |
| `tokenMinter` `:94` | `ITokenMinterV2` | `setTokenMinter` | `batchMint:310` |
| `dispatcherIndex` `:101` | `uint256` | `setDispatcherIndex` | `batchMint:315` |
| `nudgeSize` `:106` | `uint256` | `setNudgeSize` | `batchMint:351` |
| `pauser` `:110` | `address` | `setPauser` | `onlyPauser:143` |

**The contract holds no per-user accounting whatsoever.** All value routing is derived from
live `balanceOf` reads. There is no `nudgePaymentToken` — the owner's only lever over the
nudge is the numeric `nudgeSize` gate (this is the design delta vs. the frozen sibling).

## 4. `batchMint` — call graph, in execution order

| Step | Line | Call | Opcode | Target trust |
|---|---|---|---|---|
| 2 | `:320` | `INFTMinterV2(nftMinter).configs(idx)` | **STATICCALL** | owner-pinned, trusted |
| 2 | `:322` | `ITokenDispatcherV2(dispatcher).primeToken()` | **STATICCALL** | derived from trusted minter |
| 4 | `:429` | `IERC20(rewardTokens[i]).balanceOf(this)` | **STATICCALL** | **caller-supplied / untrusted** |
| 5 | `:357` | `paymentToken.safeTransferFrom(msg.sender, this, amt)` | CALL | derived, semi-trusted |
| 6 | `:360` | `paymentToken.forceApprove(nftMinter, max)` | CALL | " |
| 7 | `:364` | `nftMinter.mint(idx, recipient)` × `count` | CALL | owner-pinned, trusted |
| 8 | `:368` | `paymentToken.forceApprove(nftMinter, 0)` | CALL | " |
| 9 | `:458` | `IERC20(rewardTokens[i]).safeTransfer(recipient, amt)` | CALL | **caller-supplied / untrusted** |
| 10 | `:381` | `paymentToken.balanceOf(this)` | **STATICCALL** | derived |
| 10 | `:383` | `paymentToken.safeTransfer(msg.sender, remaining)` | CALL | derived |

### 4.1 STATICCALL re-verification (carried standing question from run-20)

**VERIFIED, and on a stronger basis than run-20.** Two independent proofs:

1. **Compiler-enforced.** `_snapshotRewards` is declared `private view` (`:421`). Solidity's
   state-mutability checker rejects any `CALL`-opcode external call inside a `view` function;
   only `STATICCALL` is legal there. The file compiles (`forge build`), therefore the
   `balanceOf` at `:429` is *necessarily* a `STATICCALL`. A hostile `rewardTokens[i]` cannot
   mutate any state at the snapshot read — its `balanceOf` executes in a static context and
   any `SSTORE`/`CALL`/`LOG` it attempts reverts.
2. **Bytecode census.** Opcode scan of `out/BatchNFTMinterMultiToken.sol/…json`
   `deployedBytecode` (PUSH-data-aware) yields exactly **4 `STATICCALL`, 4 `CALL`,
   1 `DELEGATECALL`**. The four `STATICCALL` sites correspond 1:1 to the four `view` call
   sites in the table above (`configs`, `primeToken`, reward `balanceOf`, payment
   `balanceOf`).

The `DELEGATECALL` is not from this contract's source; it is inside inherited OZ library code
paths — **unverified provenance**, noted for completeness, not believed to be a hook.

### 4.2 The one arbitrary-code window that DOES exist

`_payRewards` `:458` is a real `CALL` into a caller-chosen address. Verified properties of
that window:

- `nonReentrant` (`:300`) blocks re-entry into `batchMint`. Every other state-changing
  function is `onlyOwner` or `onlyPauser`, so there is **no reachable re-entrant target**.
- **The minter allowance is already revoked** — `forceApprove(nftMinter, 0)` at `:368` runs
  *before* `_payRewards` at `:378`. There is no outstanding ERC20 approval during the
  arbitrary-code window. This ordering is load-bearing; a refactor that moves the revoke
  after the payout would open a live-approval window to arbitrary code.
- The contract holds no user accounting to corrupt, so a re-entrancy that *did* land could
  only affect `paymentToken` balance, and the dust sweep at `:381-387` routes to
  `msg.sender` — the caller themselves. Self-harm only.

## 5. Verified local properties

| Property | Status | Evidence |
|---|---|---|
| Checked arithmetic | **verified** | `^0.8.20`, no `unchecked`, no assembly |
| Weak randomness | **verified absent** | no `block.timestamp` / `prevrandao` / `blockhash` / `difficulty` anywhere |
| Reentrancy guard on the only permissionless entrypoint | **verified** | `batchMint` `:300` |
| No live ERC20 approval during untrusted-callee window | **verified** | `:368` precedes `:378` |
| Hostile `balanceOf` cannot mutate state | **verified** (§4.1) | `private view` + bytecode census |
| Payment-token exclusion runs unconditionally, pre-funds-movement | **verified** | `:426-428` inside the `:424` loop; `_snapshotRewards` invoked at `:354`, before the pull at `:357` |
| `minRewards` floor checked pre-pull, pre-mint | **verified** | `:431-433`, reached from `:354` |
| Array length equality enforced | **verified** | `:304-306` |
| Initializer protection | **n/a** | not upgradeable; plain `constructor` |
| Access control on all state-changing admin fns | **verified** | `onlyOwner` on `:150/:159/:166/:173/:208`; `onlyPauser` on `:181/:186` |
| Unbounded loops | **VIOLATED (2 sites, accepted-by-design)** | `:363` `count`; `:424`/`:454` `rewardTokens.length` — see LOCAL-002 |
| No ERC721/1155 receive hooks | **verified** | contract is not a receiver; `nftMinter.mint(idx, recipient)` mints to `recipient`, never to this contract |
| No ERC777 path | **likely** | phUSD/USDC assumed; caller-supplied reward tokens could be ERC777 — but `nonReentrant` covers it |

## 6. Local findings

**LOCAL-001 — `rescueERC20` is documented-unreliable; escrowless design means any ERC20 sent
here is claimable by the next qualifying caller.** `:208`, `:190-201`.
This is *stated intent* (`:51-61`, `:190-201`) with an explicit "do not use this address as
custody" warning and an explicit "pause first, then rescue" operational sequence. Not a bug in
itself. Surfaced because it is the **owner-footgun surface** for this contract: the safe-config
guidance the owner must follow is non-obvious (the rescue path *silently loses a race* rather
than reverting). Severity: defer to classifier; local weight **low / operational**.

**LOCAL-002 — two unbounded loops in a permissionless function.** `:363` iterates `count`
times; `:424` and `:454` iterate `rewardTokens.length`. Both are caller-supplied and
caller-gas-paid, bounded only by the block gas limit. No griefing vector against a third party
was found: there is no shared queue, no per-user state, and a failed call reverts atomically.
Explicitly acknowledged at `:262-266` ("bounded only by the block gas limit and are paid for
by the caller") and the no-dedupe decision is justified as O(n²) avoidance. Severity: local
**informational**, not a DoS.

**LOCAL-003 — `_payRewards` uses `safeTransfer`, so one bad entry reverts the whole batch.**
`:458`. Duplicate entries in `rewardTokens` (`:412-415`) both snapshot the same balance; the
first transfer drains it and the second reverts on insufficient balance. Same for a
non-transferable / blacklisting token. This is **fail-closed self-DoS** — only the careless
caller is harmed, and it is documented at `:258-266`. Contrast with the migrators, which
deliberately use raw `transfer` in `try`/`catch` for exactly this reason. Severity: local
**QA**.

**No local finding is raised for:**
- the nudge front-run / MEV race — **cross-actor economic, defer to econ-scanner**, and see §7;
- over-funding the contract beyond mint cost — **owner footgun, defer**, see §7;
- fee-on-transfer / rebasing reward tokens (`:252-256`) — caller-elected, and FoT is
  permanently known-invalid for this suite.

## 7. Dedup / carryover hazard (READ THIS, downstream)

The following run-20 root-cause classes were filed against `BatchNFTMinter` and are now
**verbatim live on `BatchNFTMinterMultiToken`** under new fingerprints:

1. **Nudge front-run / MEV.** `:288-291` states the floor "does NOT stop a front-runner from
   winning the pot". Ledger history: `phoenix-nft-staking` BatchNFTMinter nudge M-01 →
   story-014 fix → MEV front-run **survived** and was carried as an accepted residual.
2. **Over-funding footgun.** `:56-61` ("If someone over-funds this contract beyond the mint
   cost and a bot snipes it, that is still correct behaviour; the error was in the sender").

Per the standing rule on re-filing an owner-accepted issue on a new contract: **do not silently
suppress these under the old fingerprint, and do not silently re-file them as new either.**
Name the prior ledger entry, quote its triage reason, and state the re-file basis — which here
is *"the same accepted residual, now on a second, not-yet-deployed contract, with the owner's
mitigation lever (`nudgePaymentToken`) removed"*. That last clause is a **material widening**:
the frozen sibling let the owner pin a single payout token; this one lets the caller name any
token the contract holds. Downstream must decide whether the prior acceptance still covers it.

## 8. Trust assumptions

- `tokenMinter` and the dispatcher it resolves are **trusted, owner-configured** (`:21-32`).
  Pinning them to owner state is the mitigation for the historical no-op-minter drain vector.
- `paymentToken` is **derived**, never caller-supplied (`:322`) — a wrong/zero payment asset
  cannot be passed.
- `rewardTokens[i]` are **fully untrusted, caller-supplied** addresses. Two call sites each
  (`balanceOf` STATICCALL, `safeTransfer` CALL).
- The "donate-forward" ordering (snapshot at `:354`, pay at `:378`) is the **only** thing
  preventing a caller from funding their own reward inside one transaction. It is pinned by
  `test_OwnDonationsDoNotRefundToBatcher`. Any refactor moving the balance read to the payout
  site silently collapses the incentive. Flagged at `:327-344` and `:440-447`; treat as an
  invariant for `invariant-generator`.
