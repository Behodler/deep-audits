# Spec-Conformance Report (Law-2 Faithfulness) — stable-staker-07

> **Scope.** This is the Law-2 *faithfulness* report: deviations between what a
> `[story-NNN]` commit / the submodule `CLAUDE.md` spec **says** a feature does and
> what the code at HEAD **actually** does. It is **separate from the QA bundle**.
> Findings here whose deviation *also* carries asset/value/availability impact are
> ALSO reported under an H/M label with their own PoC; those are cross-referenced,
> not duplicated.

- **Project:** stable-staker
- **Run:** stable-staker-07
- **Audited commit (HEAD):** `7e9ef80a916081148e28df60ef6daf83c9157a3b`
- **Source:** `lib/stable-staker/src/StableStaker.sol`, `lib/stable-staker/src/StableStakerMigrator.sol`
- **Faithfulness findings:** F-01 (Low), F-02 (QA/Low) + M-03 faithfulness cross-reference

---

## F-01 — `batchMigrate` re-books migrants below principal through a haircutting destination strategy, breaking the userMigrate/batchMigrate equivalence guarantee

- **Severity:** Low (faithfulness)
- **Fingerprint:** `4f143a95`
- **Faithfulness:** yes · **Footgun:** yes (non-obvious, owner-config-dependent) · **PoC:** not required at Low
- **Story violated:** `story-004` ("Replace migrateOut with terminal migration state machine"), commit `f5f6039`
- **Location (actual path):** `batchMigrate` (`src/StableStaker.sol` ~L429-450) → migrator redeposit → destination `depositFor` (L531) → `_routeDeposit` (L656-662)

### What the spec says

`story-004` (commit `f5f6039`) states the terminal-migration design's equivalence guarantee:

> "batchMigrate + userMigrate then pay a fixed credit p_i\*min(R,P)/P from the
> idle pile, making payouts order- and method-independent (closes ss2m1/M-01)."

The submodule `CLAUDE.md` ("Terminal migration mode", ~L89-92) restates it as a hard invariant:

> "every exit — operator `batchMigrate` or permissionless `userMigrate` — pays a
> fixed credit `p_i·min(R,P)/P` from the idle pile, so payouts are independent of
> batch composition, ordering, and **batch-vs-self**. Equal principal ⇒ equal payout."

And the migrator's own contract doc (`CLAUDE.md` ~L17-18) promises principal preservation:

> "moves a batch of users from one `StableStaker` to another with zero user action,
> **preserving principal** and minting earned rewards."

The stated intent: a user must end up in the same economic position whether the operator sweeps them out with `batchMigrate` or they exit themselves with `userMigrate`.

### What the code actually does

The equal-credit guarantee holds only for the **exit** leg on the *old* staker: both `batchMigrate` and `userMigrate` funnel through `_exitPosition` and pay `p_i·min(R,P)/P`. But the two paths diverge **after** that equal credit is computed:

- **`userMigrate`** transfers the credit to the user's **own wallet** (L502) — they exit the system entirely with full value in hand; they are *not* re-deposited anywhere.
- **`batchMigrate`** hands the aggregate to the migrator (L448), which redeposits each per-user credit into the **destination (new) staker** via `depositFor` → `_routeDeposit` (L531 → L656-662). If the destination has a haircutting (market) `IYieldStrategy` wired for the token at migration time, `_routeDeposit` returns `credited = strategy.deposit(...) = amount·(1 - slip)` (L661), and the user is booked **below** their migrated principal.

So two equal-principal users diverge purely by exit method: the self-exiter keeps full value, the batch-migrated user is silently haircut by the destination's `slippageToleranceBps`. This contradicts the explicit "batch-vs-self … equal principal ⇒ equal payout" invariant and the migrator's "preserving principal" promise — the equivalence the story closed `ss2m1`/M-01 on is only preserved on the credit side, not end-to-end.

### Honest severity and disposition

Low, not Medium: the value delta equals the *normal entry slippage* any new depositor into a haircutting strategy would take, is bounded by the destination's `slippageToleranceBps`, and is **zero** when the destination is idle or full-credit (the typical state of a freshly deployed migration target). It is a **non-obvious owner footgun** (migrating into a destination that already has a haircutting strategy wired), surfaced here per Law 2 rather than buried.

**Safe-config guidance:** migrate into an idle / full-credit destination (wire the destination's yield strategy *after* the migration batch completes), or normalize credit across both exit paths so `batchMigrate` redeposits at the same effective value `userMigrate` delivers.

---

## F-02 — `withdrawDisabled` view over-reports after story-002 added the buffer path: returns raw `_isUnderwater`, not "withdraw is blocked"

- **Severity:** QA/Low (faithfulness)
- **Fingerprint:** `a56f8778`
- **Faithfulness:** yes · **Footgun:** no · **PoC:** not required
- **Story context:** `story-002` ("Add buffer path to `_routeExit`", commit `48be4e2`)
- **Location:** `withdrawDisabled` (`src/StableStaker.sol` L594-600); spec text in `CLAUDE.md` ~L81-82

### What the spec says

The submodule `CLAUDE.md` ("Underwater withdraw block", ~L81-82) documents the view's contract:

> "`withdrawDisabled(token)` is a cheap public view returning **`true` while withdraw
> is blocked** (and `false` when no strategy is set)."

The on-chain NatSpec (L590-593) frames the same promise around *withdrawals being disabled*:

> "True when non-migrating withdrawals are currently disabled for `token` because its
> yield strategy is below par (`totalBalanceOf < principalOf`)."

The documented contract is: `true` ⇔ a withdraw would currently be refused.

### What the code actually does

```solidity
function withdrawDisabled(address token) external view returns (bool) {
    IYieldStrategy strategy = yieldStrategy[token];
    if (address(strategy) == address(0)) {
        return false;
    }
    return _isUnderwater(token, strategy);   // raw underwater, NOT "blocked"
}
```

The view returns the raw underwater predicate (`totalBalanceOf < principalOf`). That equation was the exact disabled-condition **before** `story-002`. But `story-002` (commit `48be4e2`) added the buffer path to `_routeExit`:

> "When a token's yield strategy is underwater and the contract holds sufficient idle
> ERC20 balance, withdraw is now served from that buffer instead of touching the
> strategy."

After that change, "withdraw is blocked" became a **strict subset** of "underwater": while the strategy is below par, a withdraw whose amount the on-contract buffer can cover **still succeeds** (it is served from the buffer, not the strategy). So `withdrawDisabled` now returns `true` in cases where a withdraw would in fact go through — the view **over-reports** disabled. Its documented contract ("true while withdraw is blocked") no longer matches the code.

### Honest severity and disposition

QA/Low, **no value at risk**. The error is in the **conservative** direction only — the view can report `true` (don't withdraw) when a withdraw would actually succeed, but it never reports `false` (safe to withdraw) when one would be refused. Worst case is a UX false-negative: an off-chain UI discourages a withdraw that would have worked via the buffer. This is *not* the invalid "unused view" category — it is a documented public view whose stated behaviour drifted from the code after `story-002`.

**Recommendation:** either (a) make the view buffer-aware (return `true` only when underwater *and* the on-contract buffer cannot cover a reference amount), or (b) update the docs/NatSpec to state the view reports "strategy below par" rather than "withdraw blocked," since blocking is now buffer-dependent.

---

## M-03 — Faithfulness cross-reference: terminal-mode exit is not mint-free, breaking emergencyWithdraw's "a broken mint path can never trap principal" invariant

- **Severity:** Medium (reported individually with PoC — **not duplicated here**)
- **Fingerprint:** `e4567dc3`
- **Faithfulness:** yes (this section is the Law-2 cross-reference only)
- **Full report:** [`submissions/M-03-terminal-exit-not-mint-free.md`](./M-03-terminal-exit-not-mint-free.md)

This Medium finding carries a Law-2 faithfulness dimension and is recorded here for traceability. The full description, impact, attack path, PoC, and recommendation live in the Medium submission above — this is a pointer, not a re-report.

**Spec text violated.** `emergencyWithdraw`'s NatSpec (`src/StableStaker.sol` ~L300-303) states the escape-hatch invariant:

> "Escape hatch: withdraw the caller's full principal for `token`, forfeiting any
> pending reward. Works while paused and never touches reward accounting, **so a
> broken mint path can never trap principal**."

**Deviation.** Once terminal migration is engaged, `emergencyWithdraw` is blocked (`require(!migrationInfo[token].active)`, L307) and its role is taken over by `userMigrate`/`batchMigrate`. But the replacement is **not** mint-free: `_exitPosition` mints the migrant's frozen pending phUSD (L479-481) **before** the principal transfer. If the staker's phUSD minter right is revoked while a token is `active` (a plausible decommissioning step), every exit with `pending > 0` reverts on the `phUSD.mint` and principal is trapped — exactly the failure mode the documented invariant promised the escape hatch could never suffer. The invariant is preserved by `emergencyWithdraw` itself but **not** by its terminal-mode replacement.

See [`submissions/M-03-terminal-exit-not-mint-free.md`](./M-03-terminal-exit-not-mint-free.md) for the full finding.
