# Mainnet verification — ECON-001 (BatchNFTMinter step-10 payment-token sweep vs. NudgeRatchet USDC sink)

**Date:** 2026-07-20
**Chain:** Ethereum mainnet (chainid 1)
**RPC:** `RPC_MAINNET` from `/home/justin/code/audits/.envrc` (Alchemy) — **liveness probe OK**, `cast block-number` → `25572875`
**Mode:** read-only. Only `cast call` / `cast balance` were issued. No transaction was sent.

---

## Verdict (up front)

**The pot is NOT currently exposed. Current exposed balance = 0 USDC.**

`NudgeRatchet.batchMinter` has already been **repointed on-chain** away from `RatchetBatchNFTMinter` to the
original `BatchNFTMinter`, by `FixRatchetBatchMinterSink.s.sol`, whose two mainnet transactions are recorded
in the repo broadcast log with `status 0x1` (success) at blocks `25356884` / `25356885`. The current
`RatchetBatchNFTMinter` USDC balance is **0**, and it was **also 0 at the block immediately before the fix**.

**Severity supported by the evidence: Medium**, not High. The High branch of the stated criterion
("a non-trivial USDC balance is sitting there right now") is **refuted by direct on-chain reads**.

The hazard is real and latent: the vulnerable wiring is one owner `setBatchMinter` call away from returning,
the sweep sink is still `count == 1`-callable, and neither batch-minter instance has a pauser set.

---

## 1. `RatchetBatchNFTMinter` address and `dispatcherIndex()`

Full address (from `FixRatchetBatchMinterSink.s.sol:73`, `RATCHET_BATCH_MINTER`):

> **`0x81896F48a95AbeA255cd38a3010E985b6051A1C7`**

```bash
cast call 0x81896F48a95AbeA255cd38a3010E985b6051A1C7 "dispatcherIndex()(uint256)" --rpc-url $RPC_MAINNET
# -> 7
```

`dispatcherIndex() == 7`. Matches `DeployMainnetNudgeRatchet.s.sol:458` (`setDispatcherIndex(7)`).

Other reads on the same instance:

```bash
cast call 0x81896F48a95AbeA255cd38a3010E985b6051A1C7 "owner()(address)"              # 0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6
cast call 0x81896F48a95AbeA255cd38a3010E985b6051A1C7 "tokenMinter()(address)"        # 0x39Af088408e815844c567037C157B31d48d2E10F (NFTMinterV2)
cast call 0x81896F48a95AbeA255cd38a3010E985b6051A1C7 "nudgePaymentToken()(address)"  # 0xdC035D45d973E3EC169d2276DDab16f1e407384F (USDS)
```

---

## 2. `configs(7)` and the resulting payment token

```bash
cast call 0x39Af088408e815844c567037C157B31d48d2E10F "configs(uint256)(address,uint256,uint256,bool)" 7 --rpc-url $RPC_MAINNET
# -> 0xd4ea91f6096A75a1c34A3c25D7725dE1f5c49f68   (dispatcher)
#    70000000                                      (price, 6dp = 70 USDC)
#    0
#    false

cast call 0xd4ea91f6096A75a1c34A3c25D7725dE1f5c49f68 "primeToken()(address)" --rpc-url $RPC_MAINNET
# -> 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
```

**Yes — the index-7 payment token is canonical USDC (`0xA0b8…eB48`).**
`BatchNFTMinter.batchMint` derives `paymentToken` exactly this way
(`phoenix-nft-staking/src/BatchNFTMinter.sol:320-322`: `configs(_dispatcherIndex)` → `dispatcher.primeToken()`),
and the step-10 sweep at line 381-383 sends `paymentToken.balanceOf(address(this))` to `msg.sender`
with no `qualifies` / `nudgeSize` gate. So the sweep asset on `0x81896F48…` **is USDC**. The mechanic
described in the finding is real; only the live wiring has changed.

Note also that dispatcher 7's *price* currently reads **70 USDC**, not the 10 USDC the fix script reset it to
— consistent with the ratchet having advanced after the fix ran (the script's own post-condition
`require(getPrice(7) == 10e6)` passed at execution time; see §6).

For contrast, index 4 (the sink the fix repoints to):

```bash
cast call 0x39Af088408e815844c567037C157B31d48d2E10F "configs(uint256)(address,uint256,uint256,bool)" 4
# -> 0x7f74388bc970dE5e2822036A1aD06fCCd156786b, 15731633015217427875, 1, false
cast call 0x7f74388bc970dE5e2822036A1aD06fCCd156786b "primeToken()(address)"
# -> 0xdC035D45d973E3EC169d2276DDab16f1e407384F  (USDS)
```

---

## 3. `NudgeRatchet.batchMinter()` — repointed?

`NudgeRatchet` = `0x7A4eD11160A06bB1C5b59091575d59707BE97a72`

```bash
cast call 0x7A4eD11160A06bB1C5b59091575d59707BE97a72 "batchMinter()(address)" --rpc-url $RPC_MAINNET
# -> 0x86866e01a115C17892Ed04c548F2e8638851029d
```

**REPOINTED.** It no longer points at `RatchetBatchNFTMinter` (`0x81896F48…`); it points at the
**original `BatchNFTMinter` `0x86866e01a115C17892Ed04c548F2e8638851029d`**, exactly the target constant
`ORIGINAL_BATCH_MINTER` in `FixRatchetBatchMinterSink.s.sol:69`.

Why that sink is safe for the same USDC flow — verified on-chain:

```bash
cast call 0x86866e01a115C17892Ed04c548F2e8638851029d "dispatcherIndex()(uint256)"      # 4
cast call 0x86866e01a115C17892Ed04c548F2e8638851029d "nudgePaymentToken()(address)"    # USDC 0xA0b8…eB48
cast call 0x86866e01a115C17892Ed04c548F2e8638851029d "nudgeSize()(uint256)"            # 40
```

Its own sweep asset is `primeToken(dispatcher 4)` = **USDS**, so incoming USDC is *not* swept by step 10;
USDC is instead its `nudgePaymentToken`, payable only behind the `count >= nudgeSize (40)` gate. The
entrypoint/sink identity that created the self-refund is broken.

`NudgeRatchet._dispatch` still forwards 100% of its USDC balance
(`yield-claim-nft/src/dispatchers/NudgeRatchet.sol:100`, `safeTransfer(batchMinter, bal)`) — the forwarding
behaviour is unchanged; only the destination moved.

---

## 4. Current balances — the size of the exposed pot

```bash
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDS=0xdC035D45d973E3EC169d2276DDab16f1e407384F
cast call $USDC "balanceOf(address)(uint256)" 0x81896F48a95AbeA255cd38a3010E985b6051A1C7  # 0
cast call $USDS "balanceOf(address)(uint256)" 0x81896F48a95AbeA255cd38a3010E985b6051A1C7  # 0
cast balance 0x81896F48a95AbeA255cd38a3010E985b6051A1C7                                    # 0
```

| Address | Role | USDC (6dp) | USDS (18dp) | ETH |
|---|---|---|---|---|
| `0x81896F48…` RatchetBatchNFTMinter | sweep-exposed instance | **0** (0.00 USDC) | 0 | 0 |
| `0x86866e01…` original BatchNFTMinter | current sink | 219996570 (**219.99 USDC**) | 0 | — |
| `0x7A4eD111…` NudgeRatchet | forwarder | 0 | — | — |

**The exposed pot right now is 0 USDC.**

The 219.99 USDC that *did* accumulate sits on `0x86866e01…`, where it is the intended whale-nudge bounty:
it is **not** that contract's payment token (USDS is), so the un-gated step-10 sweep cannot take it; claiming
it requires paying for 40 index-4 mints at ~15.73 USDS each (≈629 USDS). That is the designed, paid-for nudge.

Historical check (archive reads) confirming the pot never accumulated on the wrong instance:

```bash
cast call $USDC "balanceOf(address)(uint256)" 0x81896F48… --block 25356883   # 0  (pre-fix)
cast call $USDC "balanceOf(address)(uint256)" 0x81896F48… --block 25356884   # 0  (fix block)
```

This matches the fix script's own narrative: the self-refund meant every forwarded USDC was handed straight
back to the batch-minting caller in the same transaction, so no balance ever sat there between blocks.

---

## 5. `nudgeSize()` and pauser / paused state

```bash
cast call 0x81896F48a95AbeA255cd38a3010E985b6051A1C7 "nudgeSize()(uint256)"  # 40
cast call 0x81896F48a95AbeA255cd38a3010E985b6051A1C7 "pauser()(address)"     # 0x0000000000000000000000000000000000000000
cast call 0x81896F48a95AbeA255cd38a3010E985b6051A1C7 "paused()(bool)"        # false
cast call 0x86866e01a115C17892Ed04c548F2e8638851029d "pauser()(address)"     # 0x0000000000000000000000000000000000000000
cast call 0x86866e01a115C17892Ed04c548F2e8638851029d "paused()(bool)"        # false
```

- `nudgeSize() == 40` on `0x81896F48…` (as deployed by `DeployMainnetNudgeRatchet.s.sol` step 15).
- **The audit agent's claim is CONFIRMED: `pauser == address(0)` on `0x81896F48…`, and it is not paused.**
  `BatchNFTMinter.setPauser` documents `address(0)` as "pausing disabled", and `pause()` is `pauser`-only,
  so there is no pause break-glass on that instance.
- The same is true of the **currently-live sink** `0x86866e01…` — also `pauser == 0x0`, also unpaused. This is
  the instance actually holding 219.99 USDC.
- The only remaining owner lever is `rescueERC20` (owner-only). The contract's own NatSpec
  (`BatchNFTMinter.sol:190-205`) states plainly that this is **not a reliable escape hatch** while
  `batchMint` is live — "a race the owner will usually lose", and "pause first, then rescue" is the only
  dependable sequence. With `pauser == 0`, that dependable sequence is unavailable on both instances.

---

## 6. `FixRatchetBatchMinterSink.s.sol` — what it does, and has it run?

File: `/home/justin/code/audits/lib/phoenix-phase-2-staging/script/FixRatchetBatchMinterSink.s.sol`

**Remediation performed (two owner-only calls, no deployments, idempotent):**

1. `NudgeRatchet.setBatchMinter(0x86866e01…)` — move the USDC sink off `RatchetBatchNFTMinter` onto the
   original `BatchNFTMinter`. Guarded by pre-checks that the target's `nudgePaymentToken() == USDC` and
   `dispatcherIndex() != 7`, plus a constant-level `require(ORIGINAL != RATCHET, "sink must differ from
   entrypoint (self-refund)")`.
2. `NFTMinterV2.setPrice(7, 10_000_000)` — reset index-7 to the 10 USDC genesis price after a single test
   mint ratcheted it to 10.1.

Both steps are skip-if-already-correct, and the script ends with `require`s asserting both post-conditions.

The header comment (lines 12-22) is the owner documenting the discovery independently: `RatchetBatchNFTMinter`
was *both* the UI batch-mint entrypoint *and* the dispatcher sink, so a ratchet `batchMint` "swept its own USDC
back in during the loop and then refunded it to the caller (self-refund: count < nudgeSize, USDC counted as
`remaining`)". `RatchetBatchNFTMinter` is **intentionally retained** as the UI entrypoint; only the sink moved.

**Has it executed on mainnet? YES.**

Broadcast artifact `/home/justin/code/audits/lib/phoenix-phase-2-staging/broadcast/FixRatchetBatchMinterSink.s.sol/1/run-latest.json`
(chain 1) records two CALLs with successful receipts:

| tx | call | args | block | status |
|---|---|---|---|---|
| `0x652f2259d33ce483d937657633c71ea617fc45606068b3c916bb51d8ed213b27` | `setBatchMinter(address)` | `0x86866e01a115C17892Ed04c548F2e8638851029d` | `0x182ea54` = 25356884 | `0x1` |
| `0xaee1349e52f2f461787556d852c71e1ca1ad203d35f80720b7c7bf030648f992` | `setPrice(uint256,uint256)` | `7`, `10000000` | `0x182ea55` = 25356885 | `0x1` |

Independent on-chain corroboration (not just the artifact): `NudgeRatchet.batchMinter()` reads
`0x86866e01…` today (§3). Step 2's effect is no longer visible (`getPrice(7) == 70000000`), which is
expected — the price ratchets upward on each subsequent mint; the script's terminal
`require(getPrice(7) == 10e6)` could only have passed at execution time.

---

## Severity assessment

**Medium.**

Facts supporting Medium over High, all read directly from mainnet at block 25572875:

1. The sink is repointed (`NudgeRatchet.batchMinter() == 0x86866e01…`), so no new USDC flows to the
   sweep-exposed instance.
2. `RatchetBatchNFTMinter` holds **0 USDC, 0 USDS, 0 ETH** right now. There is no pot to steal.
3. It also held 0 USDC pre-fix — the self-refund returned funds within the same transaction, so no
   inter-block balance ever existed. No loss occurred historically via this path.
4. The USDC that exists (219.99 on `0x86866e01…`) is **not** sweepable there: that instance's payment token
   is USDS; USDC is its gated nudge reward requiring 40 paid mints.

Facts that keep it *at* Medium rather than Low/informational:

1. The un-gated step-10 sweep is unchanged in `BatchNFTMinter.sol:381-383` — the root cause is a live code
   property, not removed; only the configuration that fed it was corrected.
2. `RatchetBatchNFTMinter` is deliberately retained and still live, still `dispatcherIndex == 7`, still with
   USDC as its swept payment token. Any future `setBatchMinter` back to it — or any donation/airdrop of USDC
   to it — is immediately sweepable by a `count == 1` caller.
3. **No break-glass on either instance:** `pauser == address(0)` on both `0x81896F48…` and `0x86866e01…`,
   and `rescueERC20` is documented by the contract itself as an unreliable mempool race. If the hazard is
   re-armed, the owner has no pause to fall back on.

Recommended framing: a **latent-if-repointed owner footgun** (Law 3 non-obvious consequence — the owner did
in fact get surprised by it once and had to write a corrective script), with a concrete hardening ask:
set a `pauser` on both batch-minter instances, and/or gate the step-10 refund so it cannot return more than
the caller's own unspent payment.

## Things not read / limits of this verification

- No transaction was simulated or sent; the exploitability of the sweep is inferred from source
  (`BatchNFTMinter.sol:315-383`) plus the config reads above, not from a fork execution.
- `NudgeRatchet.token()` is not a public getter on that contract (the `cast call` reverted); the USDC identity
  of the ratchet's prime asset was established instead via `configs(7)` → `dispatcher.primeToken()`, which is
  the same value `BatchNFTMinter` itself derives.
- Balances of assets other than USDC, USDS and ETH on `0x81896F48…` were not enumerated (no token-index API
  was used); only the tokens relevant to this finding were checked.
