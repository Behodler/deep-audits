<!--
ID: ss12l3
CARRYOVER COPY — stable-staker run-16
Fingerprint: 86fcf00ef786f496fb1f7de0bb9df75d6a87c5187336681ba1a43be549d882c2
Fingerprint preimage: src/StableStaker.sol:finalizeAndReset:revived-pool-permissionless-stake-window-emission-dilution
Label this run: L-06 (reserved to this carryover; NOT reused by the run-16 QA bundle)
Severity: LOW — re-weighed QA -> Low this run · Ledger status: open
Source of this copy: reports/stable-staker/12/submissions/qa-report.md, section [L-03] (ss12l3)
Run: stable-staker-16 · Commit: fa06de5 (branch `master`)
-->

# [L-06] *(carryover)* Revival-window permissionless-stake race before `migrateIn`

> **Carryover copy, pruned to what remains open.** This is a **pre-existing open ledger entry from
> run-12**, not a new run-16 finding. It is reproduced here rather than merged into
> `submissions/qa-report.md`, and it is **not renumbered** — label `L-06` is reserved to it, which is why
> this run's new Tier-3 Low is `L-07`.

## Carryover status

| | |
|---|---|
| **Ledger fingerprint (verbatim)** | `86fcf00ef786f496fb1f7de0bb9df75d6a87c5187336681ba1a43be549d882c2` |
| **Ledger id / original label** | `ss12l3` / `L-03` (run-12 QA bundle) |
| **Ledger status** | **`open`** |
| **Severity** | **QA → LOW** this run (re-weigh; rationale in `classified.md §4`) |
| **First seen / last seen** | `stable-staker-12` (`ffa4947`) / `stable-staker-13` (`d95f4a6`) |
| **Contract / function** | `src/StableStakerV2.sol` / `finalizeAndReset` (path drift repaired at run-15; fingerprint unchanged) |
| **Root-cause class** | `revived-pool-permissionless-stake-window-emission-dilution` |
| **Law basis** | Law-3 operational footgun. The exploit angle is **REFUTED** and kept in a visible channel per Law 1. |
| **Cross-refs** | `ss9l1` (= this run's `L-08`), `ss10l1`, `H-01` |

**Ledger writes performed by this document: 0.** The severity here is a proposal for a human at `/ledger`.

## Why it was re-weighed QA → Low this run

The entry's stored rationale ends: *"emission-share dilution (normal MasterChef TVL dilution … not a
leak)"*. **Story-023 inverts that final step.** Under Antimatter, emission dilution **is** the leak: the
emitted unit is redeemable through the permissionless `Antimatter.annihilate`, whose antimatter half is
minted as phUSD with no stablecoin behind it (`lib/antimatter/src/Antimatter.sol:294`, at the nested pin
`a5570ce` that `stable-staker` records and compiles against — **not** top-level HEAD `3a96fb7`, whose line
numbers differ).

**Low, not Medium**, because its incremental exposure above `H-01` / `L-08` is a single narrow operational
window inside one migration session. **Not QA**, because the residual is now a real value leak rather than
a redistribution note. It is a **one-notch correction of a now-inverted rationale**, and it deliberately
does **not** import `H-01`'s realization impact figure.

## What remains open — the refutations are preserved verbatim and still hold

The following were independently refuted by two Tier-2 agents at run-12 and are **carried forward
unchanged**. They are not re-litigated, and none of them is what the re-weigh touches:

> **The theft / first-depositor-inflation / sandwich vectors were independently REFUTED.** Reward
> accounting is a MasterChef accumulator (`accAntimatterPerShare` / `rewardDebt`), **not** a
> `totalAssets`-derived share price, so there is no inflatable share price; parked principal is
> unreachable by outsiders; and each parked user's `depositFor` credits *their own* `amt` to *their own*
> `userInfo`.

**Only the closing step — "so the residual is harmless" — fails.** That is the whole of what changed.

## Description (what is still live)

After `finalizeAndReset` returns a fully-drained pool to `Active`, `stake` is permissionless again before
the operator runs `migrateIn`. A third party can therefore stake into the transiently-empty revived pool
during the `out → reset → rewire → in` session, and take an emission share that would otherwise have gone
to the migrating users.

**Location (run-16 tree, `fa06de5`)**:
- [`src/StableStakerV2.sol:673-684`](https://github.com/Behodler/stable-staker/blob/fa06de57729a37914b1db0490ec7f3e18e220828/src/StableStakerV2.sol#L673-L684) — `finalizeAndReset` → `Active`
- [`src/StableStakerV2.sol:333`](https://github.com/Behodler/stable-staker/blob/fa06de57729a37914b1db0490ec7f3e18e220828/src/StableStakerV2.sol#L333) — `stake` requires only `credited > 0`, and is permissionless
- `src/InPlaceMigrator.sol` — `migrateIn` is `onlyOwner`, so the operator cannot close the window by racing it

## Impact

No principal theft, no inflation skim. The residual is emission-share dilution of the migrating users'
window — which, since story-023, is realizable dilution of the protocol's phUSD backing rather than a
neutral redistribution note. Bounded by the length of one migration session.

**Not additive with `H-01` or `L-08`.** `H-01` is the class parent and carries the realization impact for
the whole class. A reader must not total the three as three independent losses.

## Recommendation (distinct — this is why the entry is not collapsed)

Wrap the entire `out → reset → rewire → in` session in `pause()` / `unpause()`. Both `finalizeAndReset`
and `depositFor` run while paused, so pausing the pool across the window closes the permissionless-stake
gap without blocking the migration itself, eliminating the interloper window entirely.

**Do NOT collapse this into `H-01`, and do NOT collapse it into `L-08`.** Its trigger (the race inside the
revival window) and its remedy (the operational pause-wrap of the migration session) are unique to it;
`L-08`'s remedy lives inside `finalizeAndReset` itself and additionally carries a `yieldStrategy`
re-binding leg this entry does not have. Bundle the three for the operator as one "revival-window"
runbook item if convenient, but keep three ledger entries.
