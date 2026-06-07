# Story Intents Digest — phlimbo-ea (src/Phlimbo.sol)

Feeds the **story-faithfulness (Law 2)** scanner for a `--full` cold scan.

- Project: `phlimbo-ea`  | Submodule: `lib/phlimbo-ea` (read-only) | HEAD: `1b1a32c`
- In-scope file: `src/Phlimbo.sol` (contract `PhlimboEA`, V1 — deployed)
- Contract today: `Ownable, Pausable, ReentrancyGuard` MasterChef-style dual-reward staking yield farm.
  Stake phUSD; earn **phUSD** (minted at `desiredAPYBps`) + **stable/USDC** (pushed in via `collectReward`,
  paid out on a **Linear Depletion** schedule `rewardPerSecond = rewardBalance / depletionDuration`).

## IMPORTANT — story-tag provenance (read first)

- Only **two** commits in this repo carry a strict bracketed `[story-NNN]` subject: `[story-020]` and
  `[story-021]`. **Neither touches `src/Phlimbo.sol`** — they add `PhlimboV2.sol` and `MigratorV1V2.sol`
  (out of scope) and the V1 file is explicitly left untouched. They are listed below only as context /
  Law-1 contrast (V2 is where the V1 depletion bug is fixed).
- The stories that actually **govern `Phlimbo.sol`** are referenced **inline** in commit bodies as
  "story 005", "story 006", "story 008", "Story 014", "story 015". These are treated as the authoritative
  `[story-NNN]` intents for this scan.
- Several behavior-defining commits touching `Phlimbo.sol` carry **no story number at all** (notably the
  EMA→Linear-Depletion migration and the opening of `collectReward`). They are captured below as
  **foundational (untagged)** because the scanner must still check faithfulness of the current behavior.
- There are **no `docs/` design docs** and **no acceptance-criteria README** in the submodule. The only
  in-repo design narrative is `lib/phlimbo-ea/CLAUDE.md` (contract inventory) and the commit bodies.
  The parent project (`lib/phoenix-phase-2-staging`) supplies deployment/migration intent.

---

## Stories governing src/Phlimbo.sol

### story-005 — Invert yield collection (push model) [commit c29bb44, inline "story 005"]
- **Intent:** Phlimbo no longer *pulls/harvests* from yield strategies. Instead an external accumulator
  *pushes* yield in via `collectReward(amount)` (transferFrom). Remove all `IYieldStrategy` deps. Stable
  reward distribution is smoothed over time (originally via EMA; superseded — see foundational note below).
- **Governs:** `collectReward`, the pool-accrual model, removal of strategy imports, generic `rewardToken`
  in place of a specific stable. Acceptance: deposits/claims work without any strategy contract; rewards
  only enter through `collectReward`.

### story-006 — Dynamic phUSD emission from desiredAPY [commit b6044fb, inline "story 006"]
- **Intent:** phUSD is minted to stakers at a rate derived from a target APY:
  `phUSDPerSecond = (totalStaked * desiredAPYBps) / 10000 / SECONDS_PER_YEAR`. Rate recomputed whenever
  `totalStaked` changes (stake/withdraw) and whenever APY changes. `totalStaked == 0` ⇒ rate 0.
- **Governs:** `_updatePhUSDEmissionRate`, `setDesiredAPY`, `phUSDPerSecond`, and the phUSD branch of
  `_updatePool` / `_claimRewards` / `pendingPhUSD`. Acceptance: emission tracks APY × stake; zero-APY and
  zero-stake are valid and emit nothing.

### story-008 — Security-remediation bundle (audit findings) [no single commit; remediations below]
A prior review (referred to as "story 008") produced findings whose fixes each cite it. As an intent, the
story = "harden V1 against the enumerated CRITICAL/HIGH issues." Constituent remediations touching `Phlimbo.sol`:
- **CRITICAL-1 — SafeERC20** [a45dcb6]: all token moves use `safeTransfer`/`safeTransferFrom`. Governs every
  transfer in `collectReward`/`stake`/`withdraw`/`_claimRewards`/`emergencyTransfer`.
- **HIGH-1 — first-depositor share inflation** [29820b2]: `MINIMUM_STAKE = 1e15` enforced in `stake`;
  withdrawal **dust prevention** forces full withdrawal if remainder `< MINIMUM_STAKE`. Governs `stake`,
  `withdraw`. (Listed in registry known-issues as *intended*, not a bug.)
- **HIGH-2 — pendingStable projection** [64eda5a]: view functions project rewards over elapsed time so
  UIs see accurate pending without a state-changing poke. Governs `pendingStable` (and `pendingPhUSD` parity).
- **HIGH-3 — forbid same-block reward inflation** [d85a3aa]: EMA-era guard against same-block
  `collectReward`. **Now subsumed** by Linear-Depletion `_updatePool` early-return `block.timestamp <= lastRewardTime`;
  the explicit guard/`lastClaimTimestamp` no longer exist. Scanner: verify the protection survived the model swap.
- **HIGH-5 — emergency pause + withdraw** [d46506a]: `emergencyTransfer(recipient)` moves all tokens out and
  then `_pause()`s atomically; users get a no-rewards `pauseWithdraw(amount)` exit usable `whenPaused`.
  Governs `emergencyTransfer`, `pauseWithdraw`. **See Law-1 candidate #2 — the stated user-recovery intent
  is in tension with the implementation.**

### story-014 — Two-step APY (preview/commit) [commit 50e468a, "(Story 014)"; MEDIUM-3/4]
- **Intent:** `setDesiredAPY(bps)` is a 2-call preview→commit. First call emits `IntendedSetAPY` and stores
  pending state (no change). Second call with the **same** value within **100 blocks** commits the change
  (`_updatePool` then `_updatePhUSDEmissionRate`). A different value or a >100-block gap resets to preview.
  Goals: owner can catch fat-finger mistakes; never lockable into an un-settable APY.
- **Governs:** `setDesiredAPY`, `pendingAPYBps`/`pendingAPYBlockNumber`/`apySetInProgress`,
  `getPendingAPYInfo`, events `IntendedSetAPY`/`DesiredAPYUpdated`. Acceptance: a single call never changes
  APY; commit requires identical value within window; state can always progress.

### story-015 — User-action events [commit 01609fc, "story 015"; LOW-6]
- **Intent:** Emit `Staked`, `Withdrawn`, `RewardsClaimed` with correct params/context. Observability only.
- **Governs:** event emission in `stake`, `withdraw`, `_claimRewards`. Acceptance: events fire with the
  recipient/amount actually applied (note `Withdrawn` should reflect the dust-adjusted amount, and `Staked`
  the `recipient`, not necessarily `msg.sender`).

---

## Foundational commits touching src/Phlimbo.sol with NO story number (scan anyway)

These define current behavior and have no `[story-NNN]` to anchor faithfulness — treat the commit body +
`CLAUDE.md` as the de-facto spec.

- **EMA → Linear Depletion migration** [2f678c3, untagged]: replaced EMA smoothing with
  `rewardPerSecond = rewardBalance / depletionDuration`, **"recalculating only when the balance changes
  (deposits or claims)."** Introduced `rewardBalance`, `depletionDuration`, `rewardPerSecond`;
  `setAlpha`→`setDepletionDuration`. **This is the current stable-reward model and the single most important
  thing to check — see Law-1 candidate #1.**
- **Open `collectReward` to anyone** [7529a45, untagged]: removed the `yieldAccumulator`-only restriction;
  *any* caller with approved tokens may push rewards. Added `ReentrancyGuard`/`nonReentrant` to
  `collectReward`. Rationale in body: `safeTransferFrom` means the caller funds it. **See Law-1 candidate #3.**
- **`stake(amount, recipient)` for composability** [3ba089d, untagged]: added `recipient` (zero ⇒ msg.sender);
  caller always funds via `safeTransferFrom(msg.sender,...)`, position/claims/event keyed to `recipient`.
- **Mutable Pauser dependency** [d17afe7 / 7445946, untagged] and earlier **EYE-removal simple pauser**
  [1768ba6, untagged]: `pause()`/`unpause()` gated on `msg.sender == pauser`; owner sets `pauser` via
  `setPauser` (zero address disables pausing). Implements `IPausable`.
- **Earliest scaffolding** [ae98c1e red, 5e7df6f green, untagged]: MasterChef-style dual-reward skeleton.
- **EMA-era constructor fix** [dbfdd44, untagged]: initialized `lastClaimTimestamp` — **obsolete** after the
  Linear-Depletion swap (variable no longer exists); ignore except to confirm no dead remnant.

---

## Parent-project context (lib/phoenix-phase-2-staging)

- **[story-049] PhlimboEA V1 → PhlimboV2 silent migration** [parent commit 6150b73]: off-chain snapshot +
  `MigratePhlimboV1ToV2.s.sol`. Flow: `emergencyTransfer(owner)` to **drain + pause V1 atomically**, deploy
  V2 mirroring `depletionDuration`, seed obligations from snapshot, settle USDC+phUSD debt, re-stake V1
  deposits into V2, then `withdrawAll`/revoke mint role/mirror pauser. Validated on a mainnet fork preview:
  19 surviving stakers, 13,615.682 phUSD total (== `v1.totalStaked` exactly), 80.887836 USDC pending.
  **Relevance to scope:** this is the *intended* real-world use of V1's `emergencyTransfer` — the owner
  drains principal to itself and re-distributes off the V1 contract. Confirms `emergencyTransfer` draining
  staked principal is a **knowing owner action** (Law 3 trusted) in this deployment, which sharpens the
  Law-1 reading of `pauseWithdraw` below.
- Parent deploys V1 as `PhlimboEA` (mainnet `0x3984eBC84d45a889dDAc595d13dc0aC2E54819F4`); rewards consolidated
  to USDC by `StableYieldAccumulator` and pushed via `collectReward`. Zero-APY operation is expected.

## Out-of-scope successor stories (context only; do NOT scan against Phlimbo.sol)

- **[story-020] PhlimboV2** [ac42de6]: fixes the V1 depletion-rate bug (rate no longer recomputed in
  `_updatePool`), adds a `migrator` role (explicit `user` param) and an optional `IPhlimboHook`. V1 untouched.
- **[story-021] MigratorV1V2** [1b1a32c]: chunkable V1→V2 migrator (seed/settle/migrate/withdrawAll).

---

## Law-1 override candidates (story intent looks potentially UNSAFE — flag for security scanner)

1. **Linear-Depletion rate re-anchoring (HEADLINE).** The story-005/2f678c3 intent says the rate is
   "recalculated only when the balance changes (deposits or claims)." The implementation **also** recomputes
   `rewardPerSecond = rewardBalance / depletionDuration` inside `_updatePool` (line ~416, on *every*
   interaction that distributes), and inside `collectReward` (every push) and `setDepletionDuration`.
   `lib/phlimbo-ea/CLAUDE.md` states this outright: *"Has the V1 rate-recompute bug: `rewardPerSecond` is
   recomputed on every stake/withdraw/claim, effectively re-anchoring the depletion window on each user
   interaction"* — driving the effective rate toward zero so stable rewards **under-distribute / stall**
   (funds accrue but pay out ever more slowly). The fix exists only in PhlimboV2. **This is a faithful-to-
   nobody, known-unsafe behavior in the in-scope contract — Law 1 + Law 2 both implicated. Prime PoC target.**

2. **`pauseWithdraw` user-exit promise vs. `emergencyTransfer` draining principal.** The HIGH-5/story-008
   commit body asserts: *"After emergencyTransfer removes all tokens... Users can safely exit via
   pauseWithdraw()."* But `emergencyTransfer` transfers the **entire** `phUSD.balanceOf(this)` — which
   includes all **staked principal** — to `recipient`, then pauses. With the contract drained, `pauseWithdraw`
   reverts for every user (`safeTransfer` of phUSD the contract no longer holds). So the advertised on-chain
   user recovery path does **not** exist after an `emergencyTransfer`; recovery depends entirely on the owner
   re-distributing off-chain (which is exactly what parent story-049 does). `pauseWithdraw` *is* coherent
   after a plain `pause()` (no drain). Scanner: flag the **contradiction between the story's stated user-
   safety guarantee and the implementation**; severity hinges on whether a plain-pause path is the only one
   users can rely on. (The drain itself is a *knowing* owner action ⇒ Law 3 trusted; the **mislabelled
   safety guarantee** is the issue.)

3. **Permissionless `collectReward` + window reset (griefing/rate-dilution).** story-7529a45 opens
   `collectReward` to any caller. Each call sets `rewardPerSecond = rewardBalance / depletionDuration`,
   **restarting the full depletion window from now**. A griefer can repeatedly push **dust** to continually
   re-stretch distribution and dilute the payout rate to existing stakers (cost = gas + dust they forfeit
   into the pot). Combined with candidate #1's re-anchoring, stable-reward delivery can be indefinitely
   slowed. `nonReentrant` + `safeTransferFrom` (the body's cited protections) do **not** address this rate-
   manipulation vector. Flag as a plausible griefing / value-delay vector; quantify against `depletionDuration`.

> Minor parity check (not Law-1): story-015 wants `Withdrawn` to reflect the **actual** (dust-adjusted)
> amount and `Staked` to use `recipient`. The code emits `actualWithdrawAmount` and `recipient` — appears
> faithful; confirm.
