# Mainnet verification — ECON-001 (`paymentAmount = 0` zero-contribution sweep)

**Date:** 2026-07-21
**Chain:** Ethereum mainnet (chainid 1) — `cast chain-id` → `1`
**RPC:** `RPC_MAINNET` from `/home/justin/code/audits/.envrc` (direnv). **Liveness probe OK**:
`cast block-number` → `25577241`. All reads pinned to `--block 25577241` unless stated.
**Mode:** READ-ONLY. Only `cast call`, `cast balance`, `cast code`, `cast keccak`, `cast sig` were issued.
**No transaction was sent, signed, or simulated. No script in `phoenix-phase-2-staging/script/` was run.**
**Submodule HEAD audited:** `phoenix-nft-staking` @ `c881a428c87ef4ef42ba07a71be5d49101c9006d`

---

## VERDICT (up front)

**It resolves DOWNWARD. There is NO present exposure. Recommended severity: MEDIUM.**

- The **mechanic is real in code** and I do not discount it: `batchMint` accepts `paymentAmount = 0`,
  approves the minter for `type(uint256).max` rather than `paymentAmount`, mints out of the *contract's*
  payment-token balance, and step 10 sweeps the whole remaining balance to `msg.sender` ungated. That is
  live, unpatched, byte-for-byte, on **two** mainnet-deployed instances.
- But **no funds are exposed right now.** On both live frozen instances the **payment token balance is
  exactly zero**, and has been zero across every historical block sampled. The attack needs
  `R >= C` (contract-held payment token ≥ the mint cost) merely to get past step 7; at `R = 0` the
  mint reverts and the transaction dies before reaching the sweep.
- The econ agent's warning was **correct and is now confirmed by direct reads**: the USDC sitting on
  `0x86866e01…` is that contract's **`nudgePaymentToken`**, *not* its payment token
  (payment token there is **USDS**). It is therefore reachable only through the `count >= nudgeSize (40)`
  nudge gate, **not** through the step-10 sweep. Do not describe it as sweepable.
- **`BatchNFTMinterMultiToken` is NOT deployed anywhere** — confirmed by selector probe against every
  known instance (§2). Per the brief this is *not* used to discount the finding; the identical mechanic
  is live on the frozen file.

No operator emergency action is required. Hardening asks are in §7.

---

## 1. Instance census — which addresses are actually live

Candidate `BATCH_MINTER` constants harvested from `lib/phoenix-phase-2-staging/script/*.sol`:

```bash
grep -rniE "BATCH_?MINTER" --include=*.sol script/ | grep -oiE "BATCH[A-Z_]*\s*=\s*0x[0-9a-fA-F]{40}" | sort -u
# BATCH_MINTER = 0x4ef0fDe49360ed31c68ED442Ff263CC6291041f3
# BATCH_MINTER = 0x6e9886AfDF07DD67dc70b8335E4e9DF14B445071
# BATCH_MINTER = 0x81896F48a95AbeA255cd38a3010E985b6051A1C7
# BATCH_MINTER = 0x86866e01a115C17892Ed04c548F2e8638851029d
# BATCH_MINTER = 0xD3104A6e6D53b37061856fe1f31296D8962f9e01
```

Plus the on-chain sink pointer:

```bash
cast call 0x7A4eD11160A06bB1C5b59091575d59707BE97a72 "batchMinter()(address)" --rpc-url $RPC_MAINNET --block 25577241
# -> 0x86866e01a115C17892Ed04c548F2e8638851029d
```

So the two addresses named in the brief are **still the right ones**, and three legacy instances also
still have code. Full probe:

```bash
for X in <each>; do
  cast code $X --block 25577241 | wc -c                     # size
  cast keccak $(cast code $X --block 25577241)              # codehash
  cast call $X "dispatcherIndex()(uint256)"
  cast call $X "nudgePaymentToken()(address)"
  cast call $X "nudgeSize()(uint256)"
  cast call $X "paused()(bool)"
done
```

| Address | code size | codehash (trunc) | `dispatcherIndex` | `nudgePaymentToken` | `nudgeSize` | `paused` |
|---|---|---|---|---|---|---|
| `0x4ef0fDe4…41f3` (drained 2026-05-28) | 2993 | `0xac30807a9cd72cae` | *reverts* | `0x0` | 0 | *reverts* |
| `0x6e9886Af…5071` | 4910 | `0xa0aa78cc9ab112a5` | 4 | `0x0` | 0 | false |
| `0x81896F48…A1C7` (RatchetBatchNFTMinter) | 4923 | `0x0c2f553caec40226` | **7** | **USDS** `0xdC03…384F` | 40 | false |
| `0x86866e01…029d` (**live NudgeRatchet sink**) | 4923 | `0x0c2f553caec40226` | **4** | **USDC** `0xA0b8…eB48` | 40 | false |
| `0xD3104A6e…9e01` | 1717 | `0x9a614153e3e79a06` | *reverts* | *reverts* | — | *reverts* |

`0x81896F48…` and `0x86866e01…` have **identical codehashes** — the same frozen single-token
`BatchNFTMinter` bytecode, differing only in storage config.

`owner()` on both = `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (the operator EOA).
`pauser()` on both = `0x0000000000000000000000000000000000000000`, `paused()` = `false` — **no break-glass**,
unchanged from run-20.

---

## 2. Which code is deployed — selector probe (answers brief item 1)

```bash
cast sig "batchMint(address,address,uint256,uint256,address,uint256)"   # 0xf466eb7c  legacy caller-param version
cast sig "batchMint(uint256,address,uint256,uint256)"                   # 0x047a6afd  FROZEN single-token
cast sig "batchMint(uint256,address,uint256,address[],uint256[])"       # 0xca0ced0b  BatchNFTMinterMultiToken (new this cycle)
```

Searching each deployed runtime bytecode for those selectors:

| Address | `0xf466eb7c` legacy | `0x047a6afd` frozen | `0xca0ced0b` multi-token |
|---|---|---|---|
| `0x4ef0fDe4…41f3` | **YES** | NO | NO |
| `0x6e9886Af…5071` | NO | **YES** | NO |
| `0x81896F48…A1C7` | NO | **YES** | NO |
| `0x86866e01…029d` | NO | **YES** | NO |
| `0xD3104A6e…9e01` | **YES** | NO | NO |

**Conclusion:** the two instances in question run the **frozen single-token `BatchNFTMinter`**.
**`BatchNFTMinterMultiToken` is not deployed at any known address — CONFIRMED.** Its `batchMint`
selector `0xca0ced0b` appears in none of the five runtimes.

(`nudgePaymentToken()` = `0x72ad5375` is present in `0x81896F48…` bytecode, corroborating the frozen
identity independently of the `batchMint` selector.)

---

## 3. Resolved config: which token is payment, which is nudge (answers brief item 2)

```bash
M=0x39Af088408e815844c567037C157B31d48d2E10F   # NFTMinterV2, tokenMinter() of both instances
cast call $M "configs(uint256)(address,uint256,uint256,bool)" 7 --block 25577241
# -> 0xd4ea91f6096A75a1c34A3c25D7725dE1f5c49f68, 70000000, 0, false
cast call $M "configs(uint256)(address,uint256,uint256,bool)" 4 --block 25577241
# -> 0x7f74388bc970dE5e2822036A1aD06fCCd156786b, 15857984493945286891, 1, false

cast call 0xd4ea91f6096A75a1c34A3c25D7725dE1f5c49f68 "primeToken()(address)"   # 0xA0b8…eB48
cast call 0x7f74388bc970dE5e2822036A1aD06fCCd156786b "primeToken()(address)"   # 0xdC03…384F

cast call $M "getPrice(uint256)(uint256)" 7   # 70000000            = 70.000000 USDC
cast call $M "getPrice(uint256)(uint256)" 4   # 15857984493945286891 = 15.857984… USDS

cast call 0xdC035D45d973E3EC169d2276DDab16f1e407384F "symbol()(string)"  # "USDS"
cast call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 "symbol()(string)"  # "USDC"
```

| Instance | dispatcher | **payment token** (= the swept asset, `primeToken`) | cost per mint | **nudge token** | `nudgeSize` |
|---|---|---|---|---|---|
| `0x81896F48…` | idx 7 → `0xd4ea91f6…` | **USDC** (6dp) | **70.000000 USDC** | USDS | 40 |
| `0x86866e01…` | idx 4 → `0x7f74388b…` | **USDS** (18dp) | **15.857984 USDS** | USDC | 40 |

The two are **mirror images**. This is exactly the ambiguity the econ agent refused to guess at, and it
resolves against the "219.99 USDC is sweepable" reading: on `0x86866e01…` **USDC is the nudge asset,
USDS is the swept asset.**

`DUST_THRESHOLD` is `internal constant` (`BatchNFTMinter.sol:70`, `1e6`) so it is not callable —
`cast call "DUST_THRESHOLD()(uint256)"` reverts on both, as expected, not an anomaly.

---

## 4. Balances — the size of the pot (answers brief item 3)

```bash
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDS=0xdC035D45d973E3EC169d2276DDab16f1e407384F
cast call $USDC "balanceOf(address)(uint256)" <addr> --block 25577241
cast call $USDS "balanceOf(address)(uint256)" <addr> --block 25577241
cast balance <addr> --block 25577241
```

| Address | USDC (6dp) | USDS (18dp) | ETH | PhUSD | sUSDS | Flax | AutoUSDC |
|---|---|---|---|---|---|---|---|
| `0x81896F48…` | **0** | **0** | 0 | 0 | 0 | 0 | 0 |
| `0x86866e01…` | `94953127` = **94.953127** | **0** | 0 | 0 | 0 | 0 | 0 |
| `0x7A4eD111…` NudgeRatchet | 0 | 0 | 0 | — | — | — | — |
| `0x4ef0fDe4…` | 0 | 0 | 0 | — | — | — | — |
| `0x6e9886Af…` | 0 | 0 | 0 | — | — | — | — |
| `0xD3104A6e…` | 0 | 0 | 0 | — | — | — | — |

Other tokens probed via `mainnet-essential-addresses.json`
(PhUSD `0xf3B5…D605`, sUSDS `0xa393…7fbD`, Flax `0x0cf7…a9E8`, AutoUSDC `0xa756…0D35`) — **all zero**
on both live instances.

**The only non-zero ERC20 anywhere in the census is 94.953127 USDC on `0x86866e01…`, and that is its
NUDGE token, not its payment token.**

Historical sampling (archive reads) — the payment-token balance is not merely momentarily zero:

```bash
for blk in 25400000 25450000 25500000 25540000 25570000 25577241; do ... done
```

| block | `0x86866e01…` USDS (payment) | `0x86866e01…` USDC (nudge) | `0x81896F48…` USDC (payment) |
|---|---|---|---|
| 25400000 | **0** | 87.986833 | **0** |
| 25450000 | **0** | 89.057887 | **0** |
| 25500000 | **0** | 109.168687 | **0** |
| 25540000 | **0** | 270.014282 | **0** |
| 25570000 | **0** | 94.196570 | **0** |
| 25577241 | **0** | 94.953127 | **0** |

The USDC pot rises and then drops (270 → 94 between 25540000 and 25570000) — the nudge is being **paid
out through its intended gate** and re-accumulating. The USDS payment-token balance is flat zero
throughout. `0x81896F48…` has never held USDC in the sampled window.

---

## 5. The decisive arithmetic (answers brief item 4)

Notation from ECON-001: `R` = contract-held payment-token balance at call time, `C` = dispatcher charge
for `count` mints. Frozen source, `lib/phoenix-nft-staking/src/BatchNFTMinter.sol`:

```
283:  paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);   // 0 is accepted
284:  paymentToken.forceApprove(address(nftMinter), type(uint256).max);          // NOT paymentAmount
      for (i < count) nftMinter.mint(_dispatcherIndex, recipient);              // spends R, not the caller
305:  uint256 remaining = paymentToken.balanceOf(address(this));
307:      paymentToken.safeTransfer(msg.sender, remaining);                      // whole balance, ungated
308:      totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0; // floors at 0
```

(The multi-token twin is the same code at `BatchNFTMinterMultiToken.sol:357/360/381/383/384`.)

**`count >= nudgeSize` is NOT needed for the sweep leg.** The nudge snapshot and the step-10 sweep are
independent: the sweep fires for any `count >= 1` provided `remaining / DUST_THRESHOLD != 0`. The
`nudgeSize` gate only matters if the attacker additionally wants the nudge pot.

### `0x86866e01…` (the live NudgeRatchet sink — the one holding money)

- payment token = **USDS**, `R = 0`.
- `count = 1`, `paymentAmount = 0`: step 283 pulls 0 (no allowance needed, USDS permits zero-value
  `transferFrom`). Step 284 approves max. Step 7 the dispatcher tries to pull **15.857984 USDS** out of a
  contract holding **0** → **the mint reverts** → the whole transaction reverts. **Attack dies at the
  funding boundary.**
- To also take the 94.95 USDC nudge, the attacker needs `count >= 40`, i.e. `C ≈ 40 × 15.86 ≈ 634 USDS`
  (more, since index 4 ratchets upward per mint) present in the contract. `R = 0`. **Dead.**
- The 94.95 USDC is obtainable only by *paying* ~634+ USDS for 40 mints — the designed, loss-making-for-
  the-attacker nudge bounty. That is the intended mechanism, not a drain.

### `0x81896F48…` (RatchetBatchNFTMinter, retained as UI entrypoint)

- payment token = **USDC**, `R = 0`.
- `count = 1`, `paymentAmount = 0`: step 7 needs **70.000000 USDC** from a contract holding 0 → revert.
  **Dead.**

### Is there any inflow route that would arm it?

I traced the funders, because a zero balance is only meaningful if nothing is about to fill it.

```bash
cast call 0x7f74388bc970dE5e2822036A1aD06fCCd156786b "batchMinter()(address)"        # 0x86866e01…
cast call 0x7f74388bc970dE5e2822036A1aD06fCCd156786b "batchDonationSize()(uint256)"  # 15
cast call 0xd4ea91f6096A75a1c34A3c25D7725dE1f5c49f68 "batchMinter()(address)"        # 0x86866e01…
cast call 0x3bbe928340c61a65cb6c4a87b3fb59b6f3f7606a "nudge()(address)"              # 0x86866e01…
cast call 0x3bbe928340c61a65cb6c4a87b3fb59b6f3f7606a "nudgeSplit()(uint256)"         # 30
cast call 0x26f89f4b46eb164303985795ee20b15bb1edb38a "batchMinter()(address)"        # 0x6e9886Af… (old pooler → inert instance)
```

All three live routes into `0x86866e01…` deliver **USDC**, which is its **nudge** token:

- Dispatcher 4 is a Sky-route `BalancerPoolerV2`. Its donation carve-out swaps USDS→USDC through the Sky
  PSM and delivers the **gem (USDC) straight to `batchMinter`**
  (`lib/yield-claim-nft/src/dispatchers/BalancerPoolerV2.sol:260`,
  `ISkyPSM(psm).buyGem(batchMinter, gemAmt); // USDC delivered straight to batchMinter`).
  It **never** sends USDS back to the batch minter.
- The SYA at `0x3bbe…606a` routes `nudgeSplit = 30`% of claim USDC to `nudge = 0x86866e01…`. USDC again.
- `NudgeRatchet` forwards its USDC balance to `batchMinter` (`NudgeRatchet.sol:100`). USDC again.

**There is no live route that deposits USDS into `0x86866e01…`, nor USDC into `0x81896F48…`.** That is
why the historical payment-token balance is flat zero rather than transiently zero.

---

## 6. What blocks it today (answers brief item 5)

| Candidate blocker | Status |
|---|---|
| `paused()` | **NOT a blocker** — `false` on both, and `pauser() == address(0)` on both, so pause cannot even be invoked. |
| Allowance / zero-value `transferFrom` | **NOT a blocker** — `paymentAmount = 0` needs neither allowance nor balance; both USDC and USDS accept zero-value `transferFrom`. |
| `nudgeSize` gate | **NOT a blocker for the sweep leg** — step 10 is ungated; only the nudge leg needs `count >= 40`. |
| `nudgePaymentToken == paymentToken` guard (`:259-262`) | Passes cleanly on both (USDC vs USDS, and USDS vs USDC) — not a blocker. |
| **Zero payment-token balance (`R = 0`)** | **THE blocker.** The mint at step 7 reverts for lack of contract-held payment token, so the transaction never reaches the sweep. |

The single thing standing between the live code and a working zero-contribution sweep is **an empty
payment-token balance**, sustained only by the fact that nobody currently routes the payment token into
these contracts. It is a configuration property, not a code guarantee, and there is no pause and no
reliable rescue (`rescueERC20` is owner-only and the contract's own NatSpec at `:190-205` calls it "a
race the owner will usually lose").

---

## 7. Severity recommendation

**MEDIUM.** Same landing as run-20 D-22, but reached by a different and now fully-evidenced route.

Facts that keep it **off High**, all read directly from mainnet at block 25577241:

1. Both live frozen instances hold **0** of their payment token, and 0 of every other probed ERC20 except
   the 94.95 USDC nudge pot.
2. The 94.95 USDC is **not** reachable by the step-10 sweep — it is `nudgePaymentToken` on an instance
   whose payment token is USDS. The econ agent's explicit warning is **confirmed correct**; asserting
   otherwise would have been a factual error in the report.
3. At `R = 0`, the attack **reverts at step 7**, before the sweep line is ever executed. There is no
   "steal 0" edge case — the transaction fails.
4. The payment-token balance has been zero across every sampled historical block, and **no live inflow
   route deposits the payment token** into either instance. ⚠ Sampling, not a log scan (see §9) — this
   supports "durably zero across the sampled range", **not** a claim that no loss ever occurred via this
   path.
5. **The attacker cannot create the funding precondition themselves** — self-funding is net-neutral, the
   compound `count = 40` case is loss-making (~634 USDS for 40 NFTs plus a 94.95 USDC pot), and residue
   below `DUST_THRESHOLD` cannot accumulate to a single free mint (§5). The funding requirement is
   therefore a genuine, attacker-uncontrolled external requirement.

⚠ **Struck from this list (run-20 R-6):** *"`BatchNFTMinterMultiToken` — where the finding is filed — is
not deployed."* That is a **deployment-status fact and is forbidden as a severity bound**. It is recorded
in §2 as census context only, and `M-01.md` explicitly rejects it as a ground. It must not be read as a
reason the finding is held off High.

Facts that keep it **at Medium rather than Low/informational** (the mechanic is real, and I am not
discounting it on non-deployment):

1. The composition is unpatched and live: `paymentAmount` has no lower bound, the approval is
   `type(uint256).max` and not `paymentAmount`, and the step-10 sweep has no comparison against what the
   caller actually pulled in. `totalPaid`'s own floor-at-0 (`:308`) is the contract admitting the refund
   can exceed the contribution.
2. **The arming condition is one owner action or one donation away.** Any USDS reaching `0x86866e01…`
   ≥ 15.86, or any USDC reaching `0x81896F48…` ≥ 70, is immediately extractable by a `paymentAmount = 0`
   caller at gas cost only. The NatSpec at `:63-68` *invites* exactly this ("simply donates to the next
   caller"), and the owner has repeatedly repointed sinks between these instances
   (`FixRatchetBatchMinterSink`, `DisableNudgeAndDivertDonations`, `DispatcherReplaceSkyPoolerAtIndex4`).
3. **Compound case worth stating explicitly:** if a USDS balance ≥ ~634 ever lands on `0x86866e01…`, a
   `paymentAmount = 0` / `count = 40` caller takes **the 40 NFTs, the USDS remainder, AND the whole USDC
   nudge pot** in one transaction, having contributed nothing. The nudge gate does not protect the pot
   against a caller who is spending the contract's own money.
4. **No break-glass:** `pauser() == address(0)` and `paused() == false` on both. If the hazard is armed,
   the owner has no pause and the documented rescue is a mempool race — and this is the same MEV
   environment that drained `0x4ef0fDe4…` of 61.297674 USDC in 14 blocks
   (`lib/phoenix-phase-2-staging/docs/batch-nft-minter-nudge-drain-fix.md`).

Framing: **latent-if-funded**, with a Law-3 footgun character — the owner's own incident doc already
records being surprised by the sibling version of this line. Concrete hardening asks:

- Cap the approval at `paymentAmount` (line 284 / multi-token 360). This alone kills the mechanic: at
  `paymentAmount = 0` the mint reverts at the allowance boundary regardless of balance, and the invariant
  becomes structural rather than balance-dependent.
- Bound the refund by the caller's own pull: establish and test the property **`refund <= paymentAmount`,
  always** (per run-20 D-35, do not apply an unvalidated patch — establish the property).
- Set a non-zero `pauser` on `0x81896F48…` and `0x86866e01…`. Free, immediate, and currently absent.

---

## 8. Residual note (not ECON-001, flagged because it surfaced during the census)

`0x4ef0fDe49360ed31c68ED442Ff263CC6291041f3` and `0xD3104A6e6D53b37061856fe1f31296D8962f9e01` still have
code and still expose the **legacy caller-parameter** `batchMint` (`0xf466eb7c`) — the signature whose
caller-supplied `paymentToken` the incident doc identifies as an alternative drain line
("a caller can pass `paymentToken = USDC` and the end-of-batch dust sweep hands the whole USDC balance to
any caller"). Both currently hold **0** of every token probed, and `0x4ef0fDe4…` has its nudge disabled
(`nudgePaymentToken == 0`, `nudgeSize == 0`, applied by `DisableNudgeAndDivertDonations` at blocks
25196736-25196740, all receipts `0x1`). They are inert honeypots: **any ERC20 that ever lands on them is
stealable by anyone.** Operational note only — do not route funds to these addresses, and treat any
accidental transfer to them as lost. No action is requested and no finding is filed here.

---

## 9. Limits of this verification

- Read-only. Nothing was simulated or executed; exploitability of the sweep is inferred from source plus
  the config/balance reads above, not from a fork execution.
- Balance enumeration was by explicit token list (USDC, USDS, PhUSD, sUSDS, Flax, AutoUSDC, ETH). No
  token-indexer API was used, so an exotic ERC20 balance would not have been seen — however, only the
  resolved **payment token** is sweepable by step 10, and both payment tokens were read directly as zero,
  so this gap cannot change the verdict.
- Historical sampling is six spot blocks between 25400000 and 25577241, not a full log scan. It supports
  "the payment-token balance is durably zero", not a proof that it was never non-zero for a single block.
- `0x6e9886Af…5071` (frozen code, dispatcher 4, nudge disabled, all balances zero) was profiled but not
  analysed in depth; it is the sink of the *old* pooler `0x26f89f4b…` and is currently unfunded.
