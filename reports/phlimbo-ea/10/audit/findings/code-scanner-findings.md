# code-scanner findings — phlimbo-ea run-10

- Submodule HEAD: `e32588d`
- Scope: `src/PhlimboV3.sol` (stories 029 & 030), `src/MigratorV2V3.sol`
- Tier-2 interaction-level analysis. Local properties trusted from profiles where `verified`.

Adjudication of the five Tier-1 threads: **2 confirmed (Low), 3 refuted.** No High/Medium
cross-contract bug found; the story-029/030 fixes are structurally sound, with two residual
footguns below.

---

## CODE-001 (CONFIRMED, Low / QA — incomplete fix of V3-M-05)

- **type:** denial-of-service (principal freeze), cross-contract governance footgun
- **contract:** `src/PhlimboV3.sol`
- **function:** `_claimRewards`
- **line:** 863 (`phUSD.mint(beneficiary, pendingPhUSDAmount)`), lineStart 861, lineEnd 864
- **severity hint:** Low (recoverable + privileged-only trigger; report as operational hazard /
  incomplete-fix note, NOT Medium — see reasoning)

**Claim (thread A1):** the phUSD **mint** leg in `_claimRewards` is the one token move story-029
did NOT wrap in `_tryTransfer`. The stable (:875) and promo (:899) legs now bank-on-failure; the
mint leg still reverts inline. Because `_claimRewards` is invoked by `stake`/`withdraw`/`claim`
(and by the auto-claim inside them), a reverting mint bricks the **principal** path — the exact
V3-M-05 failure class ("reverting transfer freezes principal"). So M-05 is only **partially**
closed: closed for the two ERC20 legs, open for the mint leg.

**Revert reachability (decisive):** `FlaxToken.mint`
(`lib/immutable/flax-token-v2/src/FlaxToken.sol:58-69`) reverts only when
- `!_authorizedMinters[msg.sender].canMint` — PhlimboV3's minter role revoked via
  `setMinter(phlimboV3, false)`, or
- `minterInfo.mintVersion != mintVersion` — a global `revokeAllMintPrivileges()` bump.

Base OZ `_mint(recipient, amount)` otherwise reverts only on `recipient == address(0)`
(beneficiary is `msg.sender`/user, guarded non-zero) or 2^256 supply overflow (impossible).
**There is no unprivileged revert path**, and no supply cap / pausability on phUSD.

**Why this is NOT a full Medium (and why the original M-05 was):** the original M-05 had an
**unprivileged** external trigger — a USDC-class `rewardToken` blocklisting a user address needs no
protocol permission. The mint-leg residual requires a **privileged phUSD-governance action**
(revoke minter or bump version) and is fully **recoverable** by re-authorizing the minter. That is
strictly less severe.

**Why it is still in scope (Law 3 footgun, not owner-malice):** `revokeAllMintPrivileges()` is
phUSD's *global* emergency kill-switch, designed to be pulled when **any one** minter across the
Phoenix phUSD ecosystem is compromised — it bumps `mintVersion`, deauthorizing **every** minter at
once. A phUSD-token operator invoking it to contain an unrelated minter incident would not expect
the side effect of **freezing every PhlimboV3 staker's principal** (they cannot withdraw because the
auto-claim mint reverts). That surprising cross-contract consequence is a genuine footgun. Safe-config
guidance: either (a) wrap the mint leg in a bank-on-failure path mirroring the stable/promo legs
(`unclaimablePhUSDOf`), or (b) operationally ensure PhlimboV3's minter authorization is restored (or
never globally revoked) so principal paths stay live.

**Note for triage:** this is the *residual* of a previously-reported Medium (V3-M-05). Per the
incomplete-fix discipline, surface it explicitly rather than letting M-05 auto-close as fully fixed —
the fix left the principal-freeze door open on one leg. Recommend recording as a Low operational
hazard with an incomplete-fix flag against the M-05 ledger entry (do NOT auto-flip M-05 → fixed).

---

## CODE-002 (CONFIRMED, Low / informational — banked funds unrecoverable under migrator delegation)

- **type:** stranded funds / missing recovery path (design gap)
- **contract:** `src/PhlimboV3.sol` + `src/MigratorV2V3.sol` (interaction)
- **function:** `PhlimboV3._claimRewards` (:876, :902 bank-to-`beneficiary`) ↔ `MigratorV2V3` (no
  V3-bank pull function)
- **severity hint:** Low (exotic precondition, no theft, owner-recoverable via `emergencyTransfer`)

**Claim (thread A2):** banked stable/promo is credited to `beneficiary` (== `msg.sender`), which
under migrator delegation is the **MigratorV2V3 contract**, not `user`. If a `_claimRewards` stable
or promo transfer to the migrator fails, PhlimboV3 records
`unclaimableStableOf[MigratorV2V3] += pending` (:876) or
`unclaimablePromoOf[promoToken][MigratorV2V3] += pending` (:902). Recovery requires a call to
`PhlimboV3.claimUnclaimableStable()` / `claimUnclaimablePromo(token)` with
`msg.sender == MigratorV2V3`. **MigratorV2V3 exposes no function that makes either call** (it has
`claimUnclaimable` only for its *own* bank, plus `migrate`/`migrateOne`/`seedUsers`/`skipCurrent`/
`withdrawAll`). The banked amount is therefore stranded inside PhlimboV3 under the migrator's
identity, unclaimable by any actor. The migrator's own balance-delta forwarding (`migrateOne` :260-272)
measures `balanceAfter - balanceBefore == 0` on the failed leg, so the user is never made whole
either.

**Reachability (why Low):** requires the *failure* of a stable/promo transfer whose recipient is the
migrator contract — i.e. a USDC-class `rewardToken` (or partner promo token) **blocklisting the
migrator's own address**, during a straggler/second migration pass where the user already holds a V3
position with accrued pending (first-pass `stake` early-returns at `userDetails.amount == 0`, so no
pending routes to the migrator). This precondition is implausible in practice — USDC does not
blocklist arbitrary fresh contracts. No funds are lost to the protocol: PhlimboV3's owner
`emergencyTransfer` can still sweep the physical balance out-of-band.

**Fix guidance:** either force auto-claim beneficiary to `user` on the migrator delegation path
(so banks accrue to a puller-capable EOA), or add a thin `pullV3Bank(token)`-style forwarder on
MigratorV2V3 that calls `phlimboV3.claimUnclaimable*` and re-forwards to `user`. Surface as
informational — a real recovery gap on an exotic trigger.

---

## CODE-003 (REFUTED — reentrancy; shared OZ lock covers all new external-call paths)

- **thread 3.** Refuted as an exploitable finding. The static flags (SLI-005..008, ADE-015..017)
  are CEI-ordering informational, not exploitable.

Every value-moving function carries `nonReentrant`: `batchClaim` (:469), `claimUnclaimablePromo`
(:580), `claimUnclaimableStable` (:603), `collectReward` (:628), `stake` (:653), `withdraw` (:698),
`claim` (:748). `_claimRewards`/`_tryTransfer` are internal and reached only from those guarded
entries. OZ v5 `ReentrancyGuard` is a **single shared lock**, so any re-entry from a callback
(malicious promo/ERC777-style token in `_tryTransfer`, or the post-op `hook.on*` calls) into **any**
guarded function reverts `ReentrancyGuardReentrantCall`. The only non-guarded state mutators reachable
mid-callback are owner-gated (`finalizePromotion`, `abortFlush`, `emergencyTransfer`, `pause`) — an
attacker in a token callback is not the owner, so no cross-function path exists.

Ordering is additionally CEI-safe where it matters: `batchClaim` aligns `promoDebt` (:487) **before**
the transfer (:490); the pull functions zero the per-user entry and decrement the aggregate
(:583-584, :606-607) **before** `safeTransfer`. **Read-only reentrancy:** V3's public views are
reward-**pending** getters (`pendingStable`/`pendingPromo`/`pendingPhUSD`), not price/share-price
oracles, and no in-scope integrator consumes them as such; the transient window where `acc*` is
updated but the caller's debt is not yet realigned is not read by any external protocol here. No
exploit. **Confirmed: the lock covers every new external-call path.**

---

## CODE-004 (REFUTED as H/M — `_tryTransfer` correct for in-scope tokens; one weird-token robustness note)

- **thread 4.** `PhlimboV3._tryTransfer` (:916-919). Classifies correctly for the tokens in scope:
  - returns `true` → success; returns `false` → banked; reverts → `callSuccess == false` → banked;
    no-return (USDT-style) → `returndata.length == 0` → success. All correct.
- **Codeless-address pitfall:** `.call` to an address with no code returns `success == true` with
  empty returndata → misclassified as a successful transfer. Not reachable: `rewardToken` is
  construction-fixed and `promoToken` is owner-set through `startPromotion` (validated non-zero, not
  phUSD/rewardToken). Owner would not set a codeless token (Law 3 obvious misconfig).
- **Malformed-returndata revert:** if a token returns non-empty returndata that is not cleanly
  decodable as `bool` (e.g. 1–31 bytes), `abi.decode(returndata, (bool))` **reverts**, and that
  revert is un-caught — breaking `_tryTransfer`'s "never revert" guarantee and re-bricking
  `batchClaim`/`_claimRewards` (the M-01/M-05 class). Only a **non-standard/weird ERC-20** produces
  such returndata; that token class is C4 known-invalid and, for `promoToken`, owner-vetted. Noted as
  a robustness caveat only — **not a valid H/M** under the known-invalid weird-token exclusion. If a
  belt-and-braces hardening is wanted, guard with `returndata.length == 32` before decode.

---

## CODE-005 (REFUTED — divide-before-multiply is dust, not exploitable)

- **thread 5.** SLI-026 (`_updatePool` :796/:835) and SLI-028 (`pendingPromo` :996).
- The flagged pattern is `rate = (balance * PRECISION) / duration` (computed at the recompute sites
  `collectReward`/`setDepletionDuration`/`topUpPromotion`/`setPromoDepletionDuration`), then
  `potential = rate * timeElapsed / PRECISION`. The rate is **pre-scaled by `PRECISION` (1e18)**
  before the division, so the per-second rate retains ~1e18 units of precision; the only loss is the
  `(balance * PRECISION) % duration` truncation at rate-compute — sub-wei-per-share dust over the
  whole window. The subsequent share accrual `acc += (toDistribute * PRECISION) / totalStaked` is
  multiply-before-divide (correct). Any residual dust is swept as `leftover` by `finalizePromotion`
  (:538). Standard MasterChef accrual precision; **not exploitable** — refuted as dust.

---

### Summary table

| ID | Thread | Verdict | Sev hint | Loc |
|---|---|---|---|---|
| CODE-001 | A1 phUSD mint leg | CONFIRMED | Low (incomplete-fix of M-05) | PhlimboV3._claimRewards:863 |
| CODE-002 | A2 migrator bank custody | CONFIRMED | Low/info | PhlimboV3._claimRewards:876/902 ↔ MigratorV2V3 |
| CODE-003 | reentrancy | REFUTED | — | shared nonReentrant lock covers all |
| CODE-004 | _tryTransfer | REFUTED (H/M) | robustness note | PhlimboV3._tryTransfer:916 |
| CODE-005 | div-before-mul | REFUTED | dust | _updatePool:796 / pendingPromo:996 |
