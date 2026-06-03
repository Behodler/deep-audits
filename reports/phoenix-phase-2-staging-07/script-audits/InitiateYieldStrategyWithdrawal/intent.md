# Intent — InitiateYieldStrategyWithdrawal (`migrate:ss-initiate-mainnet`)

Story 054 — Mainnet StableStaker migration, **SET 1 of 2 (PHASE-1 "initiate")**.
HEAD `ddf7a414e290199cefe82ed29ba5ec2cf72ceff0`. Fork block ~25232709–25232738.

## Stated purpose (from `@notice` NatSpec + package.json key)
- [x] Open the 24h total-withdrawal window on the **three live mainnet yield strategies** so they can later be drained and replaced by versions supporting `setAsideBuffer`.
- [x] Call `totalWithdrawal(token, client)` **once per strategy** — DOLA (`0xE7aEC2…`), USDC (`0x8b4A75…`), USDe (`0xFc629b…`) — with `client = PHUSD_STABLE_MINTER 0x435B0A…`.
- [x] Because each strategy is in `WithdrawalStatus.None`, each call routes into phase-1 `_initiateWithdrawal`: snapshot the client's principal, set status `Initiated`, emit `WithdrawalInitiated(token, client, balance, initiatedAt, executableAt = initiatedAt + 24h)`.
- [x] **NO funds move** in this script. Token transfers belong to phase-2 (story 055).
- [x] Operator records each `executableAt`; story 055 (set 2) re-calls the same function inside `[executableAt, executableAt + 48h]` to execute (drain).

## Declared pre-conditions (`require` before each `totalWithdrawal`, per strategy)
- `strategy.owner() == OWNER_ADDRESS (0xCad1a78…)` — else `onlyOwner` reverts on broadcast; fail loud early.
- `strategy.underlyingToken() == token` (DOLA/USDC/USDe) — wrong-token drift guard.
- `!strategy.paused()` — `totalWithdrawal` is `whenNotPaused`.
- `strategy.principalOf(token, minter) > 0` — initiating an empty position reverts in `_initiateWithdrawal` ("no balance to withdraw").
- `withdrawalStates(token, minter).status == 0 (None) || == 3 (Expired)` — guards the in-waiting-period revert AND accidental re-run after story 055 executed.

## Declared post-conditions
- **None encoded.** The script asserts only pre-conditions; it performs no post-`totalWithdrawal` assert that `withdrawalStates(token, minter).status` actually transitioned to `Initiated`, and no smoke read of the emitted `executableAt`. The "computed executableAt" it logs is recomputed in the script (`block.timestamp + WAITING_PERIOD`), **not** read back from the contract — so a contract-side anomaly would not be caught. (See finding: missing post-condition.)

## AYieldStrategy semantics relied on (lib/vault/src/AYieldStrategy.sol)
- `WAITING_PERIOD = 24h`, `EXECUTION_WINDOW = 48h`, `TOTAL_DURATION = 72h`.
- State machine: `None → Initiated (0–24h) → Executable (24–72h) → Expired (>72h)`. A second `totalWithdrawal` call dispatches by current status: `Initiated` ⇒ **revert** (still waiting); `Executable` ⇒ execute/drain; `None`/`Expired` ⇒ re-initiate.
- `_executeWithdrawal` drains the **cached snapshot `state.balance`** (not the live balance) and resets status to `None`.
- **Withdrawal state does NOT gate `deposit`/`withdraw`/`skimSurplus`/yield** — those check only `whenNotPaused`/`onlyAuthorizedClient`. Initiation is a pure timer; the strategy keeps operating normally between phase 1 and phase 2.
