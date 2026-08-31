# Intent — `dev` (DeployMocks.s.sol + the local orchestration chain)

- **Project:** phoenix-phase-2-staging @ `3fb4e34`
- **Entry point (ledger discriminator):** `dev`
- **Story tag:** Story 003 (local-deploy orchestration) extended by **Story 073**
- **Target chain:** local anvil, chainId 31337. **Not** a mainnet fork.
- **Forge target:** `script/DeployMocks.s.sol:DeployMocks::run()` — 1946 lines, no `setUp()`,
  no `PREVIEW_MODE` branch, no resume/checkpoint read.

---

## Stated purpose

From the `package.json` doc comments (`//local-deploy`, `//extract-addresses`, `//generate-ts`,
`//serve-and-dev`) and the script's own header NatSpec. Note there is **no `//dev` doc comment** —
the `dev` key itself is undocumented; its intent is assembled from its four constituent stories.

- [ ] **P1.** Wipe local deployment state (`clean:local`) and start a fresh anvil at 31337.
- [ ] **P2.** Cold-deploy the entire Phoenix Phase-2 system against **mocked external dependencies**,
      so the whole graph exists locally without touching mainnet.
- [ ] **P3.** *(Story 073)* Mirror the mainnet NudgeStreamer cutover planned in story 072:
      `NudgeStreamer` + `BatchNFTMinterMultiToken` carrying USDC/phUSD/Kendu, `NudgeRatchet`
      restored at dispatcher index 7, and `setNudgeStreamer` fanned out to all six donors.
- [ ] **P4.** *(Story 073)* Run a **V1 → `NFTStakerMigrator` → `NFTStakerDepletionV2` migration
      REHEARSAL** three times (EYE/SCX/FLX), so story 072's riskiest mainnet phase can be dry-run
      for free. The author's own scope statement: the rehearsal proves **ORDERING**
      (settle+freeze before moving the budget); it explicitly does **not** prove **SIZING**.
- [ ] **P5.** Simulate a DOLA yield tick (`./simulate-yield.sh`) so `ERC4626YieldStrategy(DOLA)`
      has claimable yield for `StableYieldAccumulator`.
- [ ] **P6.** Extract the address book → `local.json` (`extract-addresses.js 31337`).
- [ ] **P7.** Regenerate the TypeScript address interface → `addresses.ts` + `local-addresses.ts`
      (`generate-ts-addresses.js 31337`; chainId 1 is a hard `REFUSING:` branch).
- [ ] **P8.** Serve the address book over HTTP on `:3001` for the Phoenix UI.

**The user's framing of the main purpose: UI preparation + an integration functionality check.**
P6–P8 are therefore first-class deliverables, not a postscript.

### Explicitly declared NON-goals (in-source)
- Mainnet fidelity of the mocks. `LOCAL_STREAM_DURATION = 6 hours` (vs mainnet's 7 days) is
  flagged *"Do NOT 'fix' this to match mainnet."*
- Stream parity: *"mainnet registers a stream for USDC ONLY, leaving phUSD and Kendu
  whitelisted-but-unregistered with permanently zero rewards. All three are registered here so the
  UI can render three non-zero reward slots. Do not read local behaviour as a prediction of
  mainnet's."* (`DeployMocks.s.sol:1556-1560`)
- `MOCK_NUDGE_SIZE = 25` is deliberately lowered from mainnet's 40 "for dev ergonomics".

---

## Declared pre-conditions (in-script `require`, before/around the mutation they guard)

All 17 in-script `require`s. There are **no `assert`s** anywhere in the file.

| # | Line | Condition | Class |
|---|------|-----------|-------|
| 1 | `:438` | `usdeAmmSlippageBps (10) <= usdeSlippageToleranceBps` — *"would brick USDe deposits"* | pre-condition, config-consistency |
| 2 | `:885` | `nftMinterV2.dispatcherToIndex(nudgeRatchet) != 0` | post-registration |
| 3 | `:1578` | `nftMinterV2.dispatcherToIndex(balancerPoolerV2) != 0` | pre-condition for the whitelist step |
| 4 | `:1586` | `balancerPoolerV2.primeToken() == usds` — flagged in-source as **"THE SINGLE HIGHEST-RISK LINE IN THIS STORY"**: `setNudgeTokenWhitelist(USDC, true)` reverts `BatchMint__RewardTokenIsPaymentToken` if the added token equals the pinned dispatcher's `primeToken()`. Asserted here so a mock rewire fails loudly rather than three calls later. | **drift guard** |
| 5 | `:1689` | `dispatcherToIndex(uniboost) != 0` (rehearsal) | pre-condition |
| 6 | `:1755` | `v1.totalStaked() == 3` — *"rehearsal: expected 3 staked units on V1"* | pre-condition (rehearsal fixture) |
| 7 | `:1858` | `dispatcherToIndex(dispatcher) != 0` (staker deploy) | pre-condition |
| 8 | `:1886` | `dispatcherToIndex(dispatcher) != 0` (nudgeless batch minter) | pre-condition |

## Declared post-conditions (in-script `require`, after the mutation)

| # | Line | Condition | Proves |
|---|------|-----------|--------|
| 9 | `:467` | `yieldStrategyUSDe.slippageToleranceBps() == usdeSlippageToleranceBps` | setter landed |
| 10 | `:889` | `ratchetIndex == 7` — MintPageView hard-codes index 7; the disabled index-6 placeholder exists solely so this lands on 7 | UI slot pinning |
| 11 | `:1129` | `stableYieldAccumulator.nudgeStreamer() == nudgeStreamer` | **the only donor whose `setNudgeStreamer` is post-asserted** |
| 12 | `:1603` | `batchNFTMinter.getNudgeTokens().length == 3` | whitelist cardinality |
| 13 | `:1661` | `received == amount` — *"nudge seed token is fee-on-transfer: streamer received < sent"* | **fee-on-transfer probe** |
| 14 | `:1664` | `bufferAfter - bufferBefore == amount` | buffer credited |
| 15 | `:1710` | `v1.totalStaked() == 0` — *"rehearsal: V1 still holds stake"* | migration drained V1 |
| 16 | `:1711` | `v2.totalStaked() == preMigrationTotal` | migration preserved total |
| 17 | `:1712` | `phUSD.balanceOf(v2) > 0` | V2 has *some* reward budget |

---

## Gaps in the self-declared spec (what the script does NOT assert)

These are the deviations between the author's own spec and the surface the script mutates. Each is
carried into the findings.

1. **No `block.chainid` guard of any kind.** `:290` merely *logs* the chain id. All seven
   `DeployMainnet*` scripts carry `require(block.chainid == 1)` twice. The project's own
   `CLAUDE.md` mandates that anvil relaxations "must be gated behind an explicit
   `block.chainid == 31337` branch and clearly commented — never share an unsafe default code path
   between local and real networks." Nothing in this script enforces that.
2. **Story 073's headline state is never asserted.** There is no post-condition on
   `streams(batchMinter, token).duration == 21600`, on any buffer being non-zero, or on
   `pendingStream` accruing. The accrual assertions were deliberately removed
   (`script/interactions/TestNudgePayout.s.sol:164`). The three numbers the story reports
   (phUSD 5,000e18 / Kendu 50,000e18 / USDC 44.86) are **self-reported console output with no
   on-chain assertion behind them**. Re-derived independently in `side-effects.json`.
3. **`setNudgeStreamer` post-assert asymmetry.** SYA is post-asserted (`:1129`). The other five
   donors — `BalancerPoolerV2` (`:784`), `NudgeRatchet` (`:844`), three `Uniboost`s (`:1534`) —
   and the batch minter itself (`:1630`) are not.
4. **`phUSD.setMinter(deployer, true)` is granted twice and never revoked** (`:1648` inside
   `_seedNudgeStream`, `:1731` inside the migration rehearsal). No `setMinter(deployer, false)`
   exists anywhere in the file, and no post-condition checks the grant's final state.
5. **`require #13` (the fee-on-transfer probe) is vacuous by construction.** It runs only against
   `MockKendu` and `MockPhUSD`, both of which are defined to have no transfer fee. It cannot fail
   locally. It is nevertheless the *only* defence that exists anywhere for
   `NudgeStreamer.collectNudge`'s unmeasured buffer credit — there is no on-chain guard. See
   finding **DEV-01**.
6. **`require #17` (`phUSD.balanceOf(v2) > 0`) is a weak post-condition.** It proves the V2 staker
   received a non-zero budget; it does **not** prove the budget is correctly sized. The 90% split
   the rehearsal uses is disclaimed in-source by the author. Ten percent of each V1 budget is left
   behind, and no post-condition observes it.
7. **`deploymentStatus: "completed"` is a hard-coded string literal** (`:1922`), written by
   `_writeProgressFile()` (`:1918-1945`) after `vm.stopBroadcast()` — i.e. during forge's **local
   execution phase, before any transaction is broadcast**. Nothing derives it from broadcast
   success. Empirically confirmed in `side-effects.json`.

---

## Access / trust model

- Signer: `vm.envUint("ANVIL_PRIVATE_KEY")` (`:285`) — the publicly-known anvil default key
  `0xac09…ff80`, also hard-coded in `simulate-yield.sh`. Not parameterized, not gated by chain id.
- The deployer EOA ends the run as: owner of essentially every deployed contract, an authorized
  phUSD minter, and the repointed `pauser` of the three retired V1 stakers.
- Law 3 note: the owner is trusted and non-malicious. The findings below concern **non-obvious
  consequences** a competent operator would be surprised by, and what a hand-port of this script to
  mainnet would inherit.
