# Mainnet verification — M-03 (`NFTStakerDepletion.sol:756` `_safePay(pending)`; migrator-reachability pivot)

**Date:** 2026-07-21
**Chain:** Ethereum mainnet (chainid 1) — `cast chain-id` → `1`
**RPC:** `RPC_MAINNET` from `/home/justin/code/audits/.envrc` (direnv). **Liveness probe OK**:
`cast block-number` → `25577673`. All reads pinned to `--block 25577673` unless stated.
**Mode:** READ-ONLY. Only `cast call`, `cast code`, `cast keccak`, `cast sig`, `cast logs`, and two
Etherscan **read** endpoints (`getsourcecode`, `getcontractcreation`) were issued.
**No transaction was sent, signed, broadcast, or simulated. No script in
`phoenix-phase-2-staging/script/` was run.**
**Submodule HEAD audited:** `phoenix-nft-staking` @ `c881a428c87ef4ef42ba07a71be5d49101c9006d`
**Finding:** run-21 **M-03**, fingerprint `b3243f42394556ac118ef5656278d13f5e1e0ce3c4dea9ff0895694d69e5af84`
(`CLASS-21-003` / `DEDUP-21-007`). Per `findings/LABEL-MAP.json`, disambiguate by fingerprint — this is
**not** ledger M-03 `58bd104c…`.

---

## VERDICT (up front)

**The pivot fact HOLDS. It resolves the safe way. M-03 stays MEDIUM.**

**No urgent finding. `migrator()` is `address(0)` on all three instances, and the `MigratorSet` event
has never fired on any of them since deployment.** The inference the severity auditor flagged as
"unpaid, and it points unsafe if wrong" is now **read from chain and confirmed** — and confirmed on the
stronger historical form, not merely the point-in-time form.

Two things the reads changed, neither of which moves the severity but both of which belong in the
write-up:

1. **The three instances are not pre-launch — they are live and carrying user funds.** They hold
   **2 / 117 / 13** staked ERC1155 units and **4.94 / 582.77 / 55.01 phUSD** of reward balance
   respectively, and `poolState == Active (0)` on all three. The severity audit's §1.3 framing
   ("`migrator == address(0)` today is *pre-launch state*") understates this: the pools are **in
   production with stakers in them**, so the expected `setMigrator` call is a step taken against a
   *populated* pool, not an empty one.
2. **A break-glass exists here** (unlike the batch minters in the ECON-001 verification):
   `pauser()` is the **Pauser contract** `0x7c5A8EeF…85a3` (owner = the operator EOA) on all three, and
   `paused() == false`. This is a genuine difference from `pauser() == address(0)` seen elsewhere and
   should not be carried over by analogy. Note, however, that it does **not** blunt M-03:
   `depositFor` is explicitly `whenNotPaused`-exempt by design (source `:743-747`: *"Callable while
   paused so a freshly deployed (and possibly paused) target can be seeded"*), so pausing does not
   close the reach-path.

**Reachability framing (the distinction the brief demands).** `depositFor` is `onlyMigrator`-**unreachable
today** — that is a statement about *present* reachability, established by direct read. It is **not** a
statement that it cannot become reachable. `setMigrator` (`src/NFTStakerDepletion.sol:311-314`) is
`onlyOwner`, takes **any** address with **no code check and no empty-pool gate** — its own NatSpec says
so: *"No empty-pool gate — the migrator must be wired before `initiateMigration` is called."* Wiring a
migrator is the scheduled entry point of the migration API these contracts exist to serve. A zero
migrator today bounds present reachability; it does not bound the defect.

---

## 1. Address resolution — how the three stakers were found (answers brief item 1)

**All three resolved. None unresolvable.** The resolution did **not** come from a deployment record —
it came from chain — and that is itself a finding worth recording.

### 1.1 The repo's deployment records are STALE and say the opposite

`lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts:96-98` states:

```
  UniboostStakerEYE: "0x0000000000000000000000000000000000000000",
  UniboostStakerSCX: "0x0000000000000000000000000000000000000000",
  UniboostStakerFLX: "0x0000000000000000000000000000000000000000",
```

under a comment (`:76-80`) reading *"These are **NOT yet deployed on mainnet** — zero-address
placeholders … Patch by hand when they ship."* Likewise:

- `server/deployments/progress.uniboost-cutover.1.json` — the progress file
  `DeployMainnetUniboostCutover.s.sol:157` writes — **does not exist in the repo**.
- `broadcast/DeployMainnetUniboostCutover.s.sol/` — **does not exist**.
- The only `UniboostStaker*` addresses anywhere in the tree are the **anvil 31337** ones in
  `progress.31337.json` / `local-addresses.ts` (`0xab16A69A…`, `0x2a810409…`, `0xCA8c8688…`) — those are
  **local mock addresses and must never be used for mainnet reasoning**.

**They have in fact shipped.** The `uniboost-cutover:broadcast` script chain ends in
`node scripts/patch-mainnet-addresses-uniboost-cutover.js`; that patch step evidently did not land in
the audited commit. Treating `mainnet-addresses.ts` as ground truth would have produced the wrong
answer — "not deployed, finding is hypothetical" — which is the opposite of the true state.
*(Operational note only, offered as a records-hygiene observation; not filed as a finding.)*

### 1.2 Chain-side resolution chain (each link verified, not assumed)

**Step 1 — is the cutover live at all?** Read `NFTMinterV2` (`0x39Af0884…E10F`) dispatcher configs:

```bash
M=0x39Af088408e815844c567037C157B31d48d2E10F
cast call $M "configs(uint256)(address,uint256,uint256,bool)" 1 --rpc-url $RPC_MAINNET --block 25577673
# -> 0x63f4aCE0304d795A458fc2567F2c4eFeB60970CA, 10002000, 2, false
cast call $M "configs(uint256)(address,uint256,uint256,bool)" 2 --block 25577673
# -> 0xea6bAa2170E60e9069646d689730533176c59a03, 10236679, 2, false
cast call $M "configs(uint256)(address,uint256,uint256,bool)" 3 --block 25577673
# -> 0xb490c48701eB44D59af4A530d75B4fd3E79B5ddD, 10022018, 2, false
cast call $M "configs(uint256)(address,uint256,uint256,bool)" 7 --block 25577673
# -> 0xd4ea91f6096A75a1c34A3c25D7725dE1f5c49f68, 70000000, 0, false
```

Indices 1/2/3 carry **growth == 2** and prices just above **10e6**, matching
`UNIBOOST_GROWTH_BPS = 2` and `UNIBOOST_PRICE = 10e6`
(`DeployMainnetUniboostCutover.s.sol:120,123`) — and index 7 is untouched at `70e6 / 0`, exactly as the
story-071 description states. **The cutover has been broadcast.**

**Step 2 — are those dispatchers the cutover's Uniboosts?** Matched on `targetPool`, against the script's
hard-coded pool constants (`:108-110`):

```bash
for D in 0x63f4aCE0… 0xea6bAa21… 0xb490c487…; do
  cast call $D "targetPool()(address)"; cast call $D "hook()(address)"
  cast call $D "recipient()(address)"; cast call $D "donationSplit()(uint256)"
  cast call $D "primeToken()(address)"; cast call $D "owner()(address)"
done
```

| Dispatcher | `targetPool` | matches script constant | `hook()` | `recipient` | `donationSplit` | `primeToken` |
|---|---|---|---|---|---|---|
| `0x63f4aCE0…70CA` | `0x54965801…3BB3` | **`POOL_EYE`** ✔ | `0x0F05c34d…2683` | `0x86866e01…029d` | 50 | USDC |
| `0xea6bAa21…9a03` | `0x319eAd06…AddB` | **`POOL_SCX`** ✔ | `0xfe4Ed16a…4a2A` | `0x86866e01…029d` | 50 | USDC |
| `0xb490c487…5ddD` | `0x6dF6B57F…5e19` | **`POOL_FLX`** ✔ | `0x8F48E543…b33C` | `0x86866e01…029d` | 50 | USDC |

`owner()` on all three = `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (the operator EOA).
`recipient` = the index-4 LSP `BatchNFTMinter` and `donationSplit = 50`, exactly as
`_finalizeUniboost` sets (`:459-464`, `DONATION_SPLIT = 50`). Every link matches the script.

**Step 3 — the stakers.** `_finalizeUniboost` wires `hook.setRecipient(staker)` (`:483`), so each hook's
`recipient()` **is** its staker:

```bash
for H in 0x0F05c34d… 0xfe4Ed16a… 0x8F48E543…; do
  cast call $H "recipient()(address)"; cast call $H "dispatcher()(address)"; cast call $H "mintDebt()(uint256)"
done
```

| Hook | `dispatcher()` (back-reference) | `recipient()` = **staker** | `mintDebt()` |
|---|---|---|---|
| `0x0F05c34d…2683` | `0x63f4aCE0…70CA` ✔ EYE | **`0x66989bb99c1569bf2540f3bB16975801df05864B`** | 0 |
| `0xfe4Ed16a…4a2A` | `0xea6bAa21…9a03` ✔ SCX | **`0x39e85E62d0Ccb83fb87fb525aA259F8f79A70637`** | 0 |
| `0x8F48E543…b33C` | `0xb490c487…5ddD` ✔ FLX | **`0x6E8cA0E37AadF35Df19F5064f279d9CC96a3403b`** | 0 |

The dispatcher back-reference closes the loop in both directions, so the EYE/SCX/FLX labelling is not
inferred from ordering.

**Step 4 — independent corroboration via creation records.** Etherscan `getcontractcreation` (read-only):

| Staker | creator | creation block | timestamp | creation tx |
|---|---|---|---|---|
| `0x66989bb9…864B` (EYE) | `0xCad1a786…D0B6` | **25490911** | 1783550579 | `0x01d6b1f8164989fe11fba67b249c5f4f4a614ef6ae2059996169eee1078d2877` |
| `0x39e85E62…0637` (SCX) | `0xCad1a786…D0B6` | **25490919** | 1783550675 | `0x83f4f4564f19a1ef5d00163a4f780bed564255b8c709ca4ef719be90ef5adfdb` |
| `0x6E8cA0E3…403b` (FLX) | `0xCad1a786…D0B6` | **25490928** | 1783550783 | `0x98c3bc00bb4aa91252fc3ca76523a1715e6f03b377372f664e8d783746e779fc` |

Three deploys by the operator EOA within ~200 seconds — one broadcast, as `uniboost-cutover:broadcast`
describes. **Independently, the decoded constructor arguments settle the identification** (§3.2).

---

## 2. Per-instance reads (answers brief item 2)

All at `--block 25577673`. `migrator()` is the decisive column.

| | **EYE** `0x66989bb99c1569bf2540f3bB16975801df05864B` | **SCX** `0x39e85E62d0Ccb83fb87fb525aA259F8f79A70637` | **FLX** `0x6E8cA0E37AadF35Df19F5064f279d9CC96a3403b` |
|---|---|---|---|
| **`migrator()`** | **`0x0000…0000`** | **`0x0000…0000`** | **`0x0000…0000`** |
| **`MigratorSet` events, ever** | **none** | **none** | **none** |
| `owner()` | `0xCad1a786…D0B6` | `0xCad1a786…D0B6` | `0xCad1a786…D0B6` |
| `pauser()` | `0x7c5A8EeF…85a3` | `0x7c5A8EeF…85a3` | `0x7c5A8EeF…85a3` |
| `paused()` | `false` | `false` | `false` |
| `poolState()` | `0` (**Active**) | `0` (**Active**) | `0` (**Active**) |
| `totalStaked()` | **2** | **117** | **13** |
| `rewardToken()` | phUSD `0xf3B5B661…D605` | phUSD `0xf3B5B661…D605` | phUSD `0xf3B5B661…D605` |
| phUSD balance held | **4.943492516489385128** | **582.766135711987757861** | **55.008495222222463721** |
| `stakedToken()` | `0x39Af0884…E10F` (NFTMinterV2) | same | same |
| `stakedId()` | 1 | 2 | 3 |
| `dispatcherIndex()` | 1 | 2 | 3 |
| `dispatcherHook()` | `0x0F05c34d…2683` ✔ | `0xfe4Ed16a…4a2A` ✔ | `0x8F48E543…b33C` ✔ |
| `depletionWindowMonths()` | 12 | 12 | 12 |
| runtime code size | 13 636 bytes | 13 636 bytes | 13 636 bytes |
| **codehash** | `0xf14545ae217591809426be2761a87d490f385363199a4f076f48ad014e8583de` | **identical** | **identical** |

Commands:

```bash
for S in 0x66989bb99c1569bf2540f3bB16975801df05864B \
         0x39e85E62d0Ccb83fb87fb525aA259F8f79A70637 \
         0x6E8cA0E37AadF35Df19F5064f279d9CC96a3403b; do
  cast call $S "migrator()(address)"            --rpc-url $RPC_MAINNET --block 25577673
  cast call $S "owner()(address)"    ; cast call $S "pauser()(address)"
  cast call $S "paused()(bool)"      ; cast call $S "poolState()(uint8)"
  cast call $S "totalStaked()(uint256)"         ; cast call $S "rewardToken()(address)"
  cast call $S "stakedId()(uint256)" ; cast call $S "dispatcherIndex()(uint256)"
  cast call $S "dispatcherHook()(address)"      ; cast call $S "depletionWindowMonths()(uint256)"
  cast call $S "stakedToken()(address)"
  cast call 0xf3B5B661b92B75C71fA5Aba8Fd95D7514A9CD605 "balanceOf(address)(uint256)" $S
  cast keccak $(cast code $S --rpc-url $RPC_MAINNET --block 25577673)
done
```

Raw `migrator()` returns, verbatim:

```
0x66989bb99c1569bf2540f3bB16975801df05864B -> 0x0000000000000000000000000000000000000000
0x39e85E62d0Ccb83fb87fb525aA259F8f79A70637 -> 0x0000000000000000000000000000000000000000
0x6E8cA0E37AadF35Df19F5064f279d9CC96a3403b -> 0x0000000000000000000000000000000000000000
```

`nft()` / `nftSupply()` revert on all three — those getters do not exist under those names (the ERC1155
handle is `stakedToken()`); expected, not an anomaly.

### 2.1 The stronger form: `setMigrator` has NEVER been called

A point-in-time `migrator() == 0` is compatible with "set, used, then cleared". It is not the case here.
`setMigrator` emits `MigratorSet(address indexed previous, address indexed next)`
(`src/NFTStakerDepletion.sol:251,311-314`), topic0
`0x9d0761a1fa4d686cd87f8dbf8ca52f90cf19c3c4dc36e66ebbf08fc5ba203f2c`. Scanned each address across its
**entire lifetime** (creation block 25490911 → head):

```bash
cast logs --from-block 25490900 --to-block 25577673 --address <staker> \
  0x9d0761a1fa4d686cd87f8dbf8ca52f90cf19c3c4dc36e66ebbf08fc5ba203f2c --rpc-url $RPC_MAINNET
# -> (empty) for all three
```

**Positive control** (mandatory — an empty log result is worthless without one). Same range, same
addresses, `PauserChanged(address,address)` topic
`0x95bb211a5a393c4d30c3edc9a745825fba4e6ad3e3bb949e6bf8ccdfe431a811`, which the deploy script *does*
call (`s.setPauser(PAUSER)`, `:485`):

| Staker | `PauserChanged` hit at block |
|---|---|
| `0x66989bb9…864B` | **25490915** |
| `0x39e85E62…0637` | **25490923** |
| `0x6E8cA0E3…403b` | **25490932** |

The scan machinery returns hits when hits exist. **The `MigratorSet` emptiness is real: `migrator` has
been `address(0)` continuously since construction, and `setMigrator` has never been invoked on any of
the three.**

### 2.2 No candidate migrator is deployed either

`InPlaceNFTStakerMigrator.sol` and `NFTStakerMigrator.sol` exist in
`lib/phoenix-nft-staking/src/`, but neither appears at any mainnet address in
`phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts`, and no phStaging script calls
`setMigrator` on an NFT staker — every `setMigrator` call site in `script/` targets the
**stable-staker / Phlimbo** family (`ResetAndRewire.s.sol`, `MigratePhlimboV1ToV2.s.sol`,
`MigrateSaga2Deploy.s.sol`, `DeployTempStableStakerAndMigrators.s.sol`). This corroborates the chain
reads from the source side and matches the severity auditor's independent check.

---

## 3. Template cross-check — is the deployed code really this source file? (answers brief item 3)

**Established, to byte equality.** This is stronger than the brief asked for, and stronger than
"bytecode alone" usually permits, so the method is given in full.

### 3.1 What could NOT be established the easy way

None of the three is **verified on Etherscan** (`getsourcecode` returns an empty `ContractName` /
`SourceCode` for all three). So the identification rests on a local rebuild, not on a published source.

### 3.2 Constructor arguments — decoded from on-chain creation payloads

The three creation payloads (Etherscan `creationBytecode`) are each **29 050 hex chars** and differ from
one another in **exactly two hex nibbles** — at offsets 28795 and 29051, i.e. inside the appended
constructor arguments. Decoding the trailing `6 × 32` bytes:

| arg | EYE | SCX | FLX | matches script |
|---|---|---|---|---|
| 0 `IERC1155 stakedToken` | `0x39af0884…e10f` | same | same | `NFT_MINTER_V2` ✔ |
| 1 `uint256 stakedId` | **1** | **2** | **3** | `idx` ✔ |
| 2 `IERC20 rewardToken` | `0xf3b5b661…d605` | same | same | `PHUSD` ✔ |
| 3 `address owner` | `0xcad1a786…d0b6` | same | same | `OWNER_ADDRESS` ✔ |
| 4 `INFTSupply` | `0x39af0884…e10f` | same | same | `NFT_MINTER_V2` ✔ |
| 5 `uint256 dispatcherIndex` | **1** | **2** | **3** | `idx` ✔ |

That is exactly, and in order, the constructor invocation at
`DeployMainnetUniboostCutover.s.sol:475-477`:

```solidity
NFTStakerDepletion s = new NFTStakerDepletion(
    IERC1155(NFT_MINTER_V2), idx, IERC20(PHUSD), OWNER_ADDRESS, INFTSupply(NFT_MINTER_V2), idx
);
```

The three init-codes being otherwise **byte-identical** also proves they are one compilation, so any
statement about one instance's code is a statement about all three.

### 3.3 Compiler identification from the deployed metadata trailer

The CBOR trailer of the deployed runtime ends `…64736f6c634300081e` → `solc 0.8.30`. Note this is **not**
`phoenix-nft-staking`'s own pin (`foundry.toml`: `solc = "0.8.20"`); `phoenix-phase-2-staging`'s
`foundry.toml` pins **no** solc, so it resolves the `^0.8.20` pragma to the latest available — 0.8.30.
Staging's other settings are explicit: `optimizer = true`, `optimizer_runs = 10000`, `via_ir = true`.

### 3.4 Local rebuild and byte-for-byte diff — the decisive step

Rebuilt `lib/phoenix-nft-staking/src/NFTStakerDepletion.sol` @ `c881a428` with staging's settings, output
redirected to the scratchpad (**the submodule was not modified**; `git status --porcelain` clean):

```bash
cd lib/phoenix-nft-staking
FOUNDRY_OUT=<scratchpad>/out30 FOUNDRY_OPTIMIZER=true FOUNDRY_OPTIMIZER_RUNS=10000 \
FOUNDRY_VIA_IR=true forge build --contracts src/NFTStakerDepletion.sol --use 0.8.30
```

Gross size agreement, before any masking:

| | local rebuild | on-chain |
|---|---|---|
| runtime | 27 272 hex chars | **27 272** ✔ |
| init-code | 28 666 hex chars | 29 050 − 384 (args) = **28 666** ✔ |

Then diffed the runtime body (metadata trailer excluded) against each deployed runtime, masking only the
15 `immutableReferences` slots the artifact itself declares (7 × slot `50326`, 8 × slot `50329`):

| Instance | body length match | differing hex chars **outside** immutable slots |
|---|---|---|
| EYE `0x66989bb9…864B` | ✔ | **0** |
| SCX `0x39e85E62…0637` | ✔ | **0** |
| FLX `0x6E8cA0E3…403b` | ✔ | **0** |

The 564 raw differing hex chars fall **entirely** inside the declared immutable slots, and decode to the
expected values on every instance:

- slot `50326` → `0x39af088408e815844c567037c157b31d48d2e10f` (NFTMinterV2 — `stakedToken`)
- slot `50329` → `0xf3b5b661b92b75c71fa5aba8fd95d7514a9cd605` (phUSD — `rewardToken`)

**Conclusion: the deployed runtime on all three instances is a build of
`lib/phoenix-nft-staking/src/NFTStakerDepletion.sol` at the audited commit `c881a428`, identical outside
immutables and the metadata hash.** M-03's premise — that the file used as the mainnet deployment
template is the deployed code — is **verified**, not assumed.

### 3.5 What this does and does not establish

- **Does establish:** the deployed code is this exact source. The `_safePay(pending)` form at `:756` is
  therefore in the deployed bytecode, because it is in the source that compiles to it.
- **Does establish** (source side, quoted so the claim is checkable) —
  `src/NFTStakerDepletion.sol:748-756`:
  ```solidity
  function depositFor(address user, uint256 amount) external override nonReentrant onlyMigrator {
      ...
      UserInfo storage info = users[user];
      if (info.amount > 0) {
          uint256 pending = (info.amount * accRewardPerShare) / ACC_PRECISION - info.rewardDebt;
          if (pending > 0) {
              pending = _safePay(pending);          // <-- :756
  ```
  and `:593-594`:
  ```solidity
  function _safePay(uint256 amount) internal returns (uint256) {
      return _safePayTo(msg.sender, amount);
  }
  ```
  Under `onlyMigrator`, `msg.sender` **is** the migrator — so `user`'s settled pending is paid to the
  migrator, while `emit Claimed(user, pending)` (`:757`) affirms payment to the user. The correct form
  exists in the same file and is used on the exit leg — `:733` `paid = _safePayTo(account, pending);` —
  which is what makes `:756` an asymmetry rather than a house convention.
- **Does NOT establish:** I did not disassemble the `depositFor` dispatch path to read `CALLER` out of
  the deployed EVM code independently of the source. The byte-equality result makes that unnecessary —
  identical bytes compile from identical source — but the claim's chain is *source ⇒ bytecode*, not an
  independent bytecode-only decode. Stated plainly per the brief.
- **Does NOT establish:** nothing here was executed or simulated. `depositFor`'s behaviour under a wired
  migrator is inferred from source, not from a fork run.
- **Metadata caveat:** the local rebuild's IPFS metadata hash (`…ccded903…`) differs from the deployed
  one (`…a01a68da…`). Expected — the metadata hash covers source paths, remappings and full settings,
  which differ between my scratchpad build and the staging build. It is not evidence of a source
  difference; the zero-diff body is the operative result.

---

## 4. The urgent branch — not taken (answers brief item 4)

**Not applicable. No `migrator()` is non-zero.** Recording the negative explicitly so a later reader
does not mistake omission for oversight: there is no EOA migrator, no contract migrator, no
story-023-patched migrator, and no unpatched pre-`f3b92c0` migrator wired to any of the three. The
question of *what* the migrator is does not arise, because there is none, and never has been (§2.1).

---

## 5. Verdict on M-03's pivot fact

**HOLDS.**

> *"The three fresh mainnet `NFTStakerDepletion` instances (EYE / SCX / FLX) have `migrator ==
> address(0)`, so `depositFor` is `onlyMigrator`-unreachable today."*

Confirmed by direct read on all three, and strengthened: `setMigrator` has never been called on any of
them since construction, and no candidate migrator contract is deployed. **M-03 remains MEDIUM. No
re-rate. No urgent operator action.**

Amendments owed to the M-03 write-up, all of which *strengthen* the ground the severity auditor asked
for in §1.3 rather than weaken it:

1. **Discharge the verification obligation.** Replace *"inferred from script source"* with the block-
   25577673 reads and the lifetime `MigratorSet` scan in §2/§2.1 of this document. The obligation the
   severity audit logged as **unpaid** is now **paid**.
2. **Correct "pre-launch state" → "live, populated pools."** §1.3 currently reads as if the three
   stakers are idle. They are `Active`, hold 2/117/13 staked units and 4.94/582.77/55.01 phUSD. The
   expected `setMigrator` call will be made against pools **with users already in them** — which
   sharpens, not softens, reach-path 1.
3. **Add the deployment-record staleness as context, not as a finding.** `mainnet-addresses.ts` still
   declares these three `address(0)` / "NOT yet deployed on mainnet". Any future reasoning that starts
   from that file will conclude the finding is hypothetical. It is not.
4. **Do not import the `pauser() == 0` framing from ECON-001.** These three have a real Pauser wired.
   But do not credit it as mitigation either: `depositFor` is deliberately callable while paused
   (`:743-747`), so pause does not close this path.
5. **Keep the framing distinction.** "Unreachable today" is a present-state bound established by read.
   `setMigrator` is `onlyOwner`, unconstrained as to address, has no code check and — by its own
   NatSpec — no empty-pool gate. The defect is latent, not absent.

---

## 6. Limits of this verification

- Read-only throughout. Nothing executed, simulated or signed.
- All state reads pinned to block **25577673**. `migrator()` is mutable by the owner at any time; this
  is a statement about that block, extended backward to construction by the event scan in §2.1, and it
  says **nothing** about any future block.
- The log scan covers blocks 25490900 → 25577673 (creation-1 → head) for the three staker addresses and
  the two topics named. It carries a positive control, so its negatives are load-bearing — but it is
  scoped to those addresses and topics only.
- Etherscan was used for two read endpoints (`getcontractcreation`, `getsourcecode`). The creation-block
  and creator fields are corroborated by the constructor-argument decode and by on-chain `owner()`, so
  the identification does not rest on Etherscan alone.
- The rebuild used staging's declared compiler settings and solc 0.8.30 as read from the deployed
  metadata trailer. The zero-diff result is itself the strongest evidence those settings were right.
- Instance discovery went `NFTMinterV2.configs(1/2/3)` → `targetPool` → `hook` → `recipient`. If a
  fourth `NFTStakerDepletion` instance exists that is *not* reachable from an active dispatcher index,
  this method would not have found it. Scope was the three named in M-03.
