# Tier-3 Symbolic Verification — run 26

**Subject:** `src/NudgeStreamer.sol` @ workspace commit `9611312`
**Tool:** Halmos 0.3.3 (Z3 backend), single-threaded (`--solver-threads 1`) per the WSL2 constraint
**Property under proof (per token):**

> `Σ buffer_i <= token.balanceOf(address(streamer))` over every registered
> `(batchMinter, token)` stream.

**Bottom line:** buffer conservation is now **machine-proved inductively for the
2-stream aggregate over a very wide domain (values < 2^96, rates < 2^128, elapsed
< 2^40, symbolic durations), and for the 3-stream aggregate only over a narrow
domain (values < 2^32)**. The 3-stream case at wider bounds is
**INCONCLUSIVE-timeout**. Combined with the reduction argument in §5 — which is a
code-inspection argument, not a machine proof — the property is *proved* for plain
ERC20s in the sense that matters operationally, but the N>2 generalisation rests on
one hand-checked step. **No counterexample was found against the real contract at
any bound.**

---

## 1. Method — inductive, not exploratory

Each test installs an **arbitrary symbolic pre-state** into the **real**
`NudgeStreamer` (buffers, `rewardPerSecond`, `lastUpdate`, `duration`, and the
streamer's token balance are all unconstrained symbolic 256-bit words), assumes
**only** the invariant itself as the inductive hypothesis, executes **one real
state transition**, and asserts the invariant in the post-state.

The pre-state is a **superset of the reachable states**, so a `[PASS]` here is
strictly stronger than a reachable-state proof. (The converse also holds: a
`[FAIL]` would have to be checked for pre-state reachability before being
believed. None occurred.)

The pre-state is installed by `PokableStreamer.poke`, a subclass setter that writes
the same `Stream` struct the contract writes. **No production logic is overridden,
mocked, or altered** — `collectNudge`, `_settle`, `_accrued` and `registerStream`
execute verbatim from `src/NudgeStreamer.sol`.

**Token model:** `SymPlainERC20`, a plain ERC20 with `balanceOf`/`allowance` as
symbolic storage maps and standard `transfer`/`transferFrom` semantics
(decrement-then-increment, allowance decrement, checked-arithmetic revert on
insufficiency). **No** fee-on-transfer, **no** rebase, **no** transfer hooks, **no**
admin clawback, **no** blocklist, **no** reentrancy. This is deliberate: the claim
being proved is the plain-token claim Tier 2 asserted.

## 2. Artifacts — ALL AUDIT-AUTHORED, NEVER PROJECT TESTS

| Path | Role |
|---|---|
| `workspace/phoenix-nft-staking/test/Symbolic_Run26_BufferConservation.t.sol` | the proofs (untracked in git; carries a NOT-A-PROJECT-TEST header) |
| `workspace/phoenix-nft-staking/test/Symbolic_Run26_MutantFalsification.t.sol` | anti-vacuity control (untracked; expected result is `[FAIL]`) |
| `workspace/phoenix-nft-staking/test/patched/MutantNudgeStreamer.sol` | pre-existing 1-wei over-credit mutant, reused |

Both new files are untracked (`git status --short` → `??`). Neither may be cited as
project test coverage.

## 3. Declared bounds

Three nested domains are used. Every `[PASS]` below is valid **only** inside the
domain named on its row.

| Name | buffers / streamer balance / deposit `amount` | `rewardPerSecond` | `elapsed` (= `block.timestamp - lastUpdate`) | `duration` |
|---|---|---|---|---|
| **D96** (widest) | `< 2^96` | `< 2^128` | `< 2^40` | symbolic, `[1, 2^40)` |
| **D64** | `< 2^64` | `< 2^80` | `< 2^32` | fixed `7 days` (or symbolic where noted) |
| **D32** (narrowest) | `< 2^32` | `< 2^48` | `< 2^24` | symbolic, `[1, 2^24)` |

Additional assumptions, in all tests:
- `elapsed <= block.timestamp` (otherwise `:267` underflows — a revert path, not a violation).
- The payee's pre-balance is set to `0` so a plain `+=` on the recipient cannot
  overflow (an overflow there is a token-side revert, not a conservation failure).
- Donor allowance is `type(uint256).max`; donor balance is symbolic (`< 2^96`) in
  the 2-stream tests and concrete-maximal in the 3-stream tests.
- `block.timestamp` is symbolic (Halmos default).

Why these bounds are not a material weakening at **D96**: `2^96` native units is
≥ 7.9e10 tokens at 18 dp, far above any real supply, and the bounds are what keep
`buffer * 1e18 / duration` and `rewardPerSecond * elapsed / 1e18` overflow-free —
so the solver spends its budget on the accounting rather than on revert paths.
At **D32** the bound *is* material and is called out as such in §4.

## 4. Results — per write site

Per-test solver timeouts used: **120 s** (lemma, mutant control), **180 s**,
**240 s**, **300 s**, and one **600 s** whole-suite run that was **killed before
completion** and is therefore reported as inconclusive, not as a result.

### Write site 1 — `collectNudge` (`:193-206`) — the only site that INCREASES buffer

| Test | Domain | Result |
|---|---|---|
| `check_site1_collectNudge_2streams` | **D96**, symbolic durations, symbolic donor balance | **[PASS]** — 36 paths, 4.25 s |
| `check_site1_collectNudge_3streams` | **D96**, `duration = 7 days` | **INCONCLUSIVE-timeout** (37 paths, 183.7 s of a 180 s assertion budget; also unfinished in the killed 600 s run) |
| `check_site1_collectNudge_3streams_b64` | **D64** | **INCONCLUSIVE-timeout** (42 paths, 302.6 s @ 300 s) |
| `check_site1_collectNudge_3streams_aggregate` | **D64**, untouched streams' unread rate fields concretised | **INCONCLUSIVE-timeout** (40 paths, 242.6 s @ 240 s) |
| `check_site1_collectNudge_3streams_aggregate_b32` | **D32** | **[PASS]** — 39 paths, 7.8 s |

**Verdict: PROVED at 2 streams over D96. PROVED at 3 streams only over D32
(values < 2^32). The 3-stream case over D64 and D96 is INCONCLUSIVE-timeout.**

In every timing case the cost is in `models:` (assertion-model solving), not in
path exploration — the solver could not decide the query, it did not run out of
paths. Concretising the two untouched streams' `rewardPerSecond`/`lastUpdate` (a
sound step: `collectNudge` resolves exactly one `Stream storage s` at `:157` and
never reads another pair's rate fields) did **not** rescue termination, so the
blow-up is the three-addend aggregate against the nonlinear
`rewardPerSecond * elapsed / 1e18` term, not the extra symbolic fields.

### Write site 2 — `_settle` (`:242-243`) via `pullPendingStream`

| Test | Domain | Result |
|---|---|---|
| `check_site2_settle_2streams` | **D96**, symbolic durations | **[PASS]** — 12 paths, 0.53 s |
| `check_lemma_settleNeverExceedsOwnBuffer` | **D96**, 1 stream | **[PASS]** — 10 paths, 0.19 s |

The lemma proves both halves of the settle step: the post-state buffer never grew,
**and** the amount that left custody is *exactly* the buffer decrease
(`token.balanceOf(recipient) == bufferBefore - bufferAfter`). That is the
conservation of the settle leg, not merely its non-violation.

**Verdict: PROVED over D96.**

### Write site 3 — `registerStream` (`:134-140`)

| Test | Domain | Result |
|---|---|---|
| `check_site3_registerStream_2streams` | **D96**, symbolic old and new durations | **[PASS]** — 14 paths, 0.56 s |

Proves two things: the invariant is preserved, **and** the untouched stream's
`buffer` is bit-for-bit unchanged (`bufferOf(m2) == otherBefore`) — i.e. the
`s.duration`/`s.rewardPerSecond`/`s.lastUpdate` rewrite cannot leak into a
sibling's buffer.

**Verdict: PROVED over D96.**

### Write site 4 — the external-transfer path, `:243` (the reverting line)

| Test | Domain | Result |
|---|---|---|
| `check_site2_settleNeverRevertsForInsufficientCustody` | **D96**, 2 streams | **[PASS]** — 9 paths, 39.8 s |

This is the **strong, load-bearing form**: the transition is invoked through a
low-level `call` and the assertion is `ok == true`. Given only the inductive
hypothesis, `pullPendingStream` **cannot revert** — so a stream can never be
un-affordable out of pooled custody. This is the exact failure whose occurrence
bricks `BatchNFTMinterMultiToken.batchMint` (which loops `pullPendingStream` over
the whole nudge whitelist in one tx with no `try/catch`).

**Verdict: PROVED over D96 for 2 streams.** This is the single most valuable result
in this document.

### Anti-vacuity control — the harness can falsify

| Test | Result |
|---|---|
| `check_MUTANT_site1_collectNudge_2streams_expectFail` | **[FAIL]** — 4 counterexamples, 40 paths, 27.1 s |

Same test shape, pointed at `MutantNudgeStreamer` (identical to the real contract
except `s.buffer += received; s.buffer += 1;` at `:201`). Halmos found
counterexamples immediately. **A `[PASS]` next door therefore carries information**;
this is not a vacuous harness.

## 5. The N-stream reduction — a hand argument, flagged as such

The machine proof covers 2 streams at D96 and 3 at D32. The step from there to
arbitrary N is **code inspection, not a machine proof**, and must be read as such:

1. `collectNudge(bm, token, amount)` resolves exactly one storage struct,
   `streams[bm][token]` (`:157`), and every subsequent read/write on the path
   (`_settle`, `_accrued`, `:201`, `:206`) goes through that one `Stream storage s`.
   Likewise `pullPendingStream` (`:221`) and `registerStream` (`:131`).
2. Therefore `Σ_{i≠k} buffer_i` is **unchanged** by any single transition, and no
   individual untouched `buffer_i` is ever read on the path.
3. So the N-stream invariant reduces to `buffer_k' + C <= balance'` for an
   arbitrary symbolic constant `C` — which is exactly the shape of the 2-stream
   test, whose second stream is fully symbolic and never touched.

Step 3 is why the 2-stream D96 proof is the substantive one and the 3-stream tests
are a cross-check rather than the main event. But the reduction is an argument a
human made; if it is wrong, the 3-stream timeouts are where the error would hide.
That is the honest residual.

## 6. Counterexamples

**None against the real contract, at any bound, at any write site.** The only
`[FAIL]` in this tier is the deliberate mutant in §4's control row. Consequently
there is **nothing here that resurrects any previously-killed finding**, and no
question of plain-ERC20 vs weird-token reachability arises.

## 7. What was proved / what was NOT

**Proved (machine-checked `[PASS]`, inductive, real contract, plain ERC20):**
- `collectNudge` preserves `Σ buffer <= balanceOf(streamer)` — 2 streams, values
  < 2^96, rates < 2^128, elapsed < 2^40, symbolic durations.
- `collectNudge` preserves it at 3 streams — values < 2^32 only.
- `_settle` preserves it, and settles *exactly* the buffer decrease — 2 streams, D96.
- `registerStream` preserves it and does not touch a sibling's buffer — 2 streams, D96.
- **`pullPendingStream` cannot revert for insufficient custody** given the
  hypothesis — 2 streams, D96. (The no-brick property.)
- The harness can falsify: the 1-wei over-credit mutant is caught.

**NOT proved:**
- The 3-stream aggregate at D64 or D96 — **INCONCLUSIVE-timeout**, three separate
  attempts (183 s, 302 s, 242 s solver budgets). A timeout proves **nothing** and
  is **not** evidence of safety.
- Any N > 3 by machine. Covered only by the §5 hand reduction.
- Anything about non-plain tokens. Fee-on-transfer, rebasing, hook-bearing,
  blocklisting and clawback tokens are **entirely outside this model** — in
  particular this says nothing about `LOCAL-NS-01` (post-credit balance erosion),
  which is a token-side property the symbolic token deliberately does not have.
- Reentrancy, multi-transaction sequences (each test is one transition; the
  inductive argument is what chains them), the `batchMinter` side, and non-18-dp
  behaviour (decimals are irrelevant to this property but were not varied).
- The one 600 s whole-suite run was **killed before completion**; nothing is
  claimed from it.

## 8. Reproduction

```bash
cd workspace/phoenix-nft-staking
forge clean   # halmos needs --ast artifacts; a plain `forge build` poisons the cache

# the proofs (site 2, site 3, site-4 no-revert, lemma, 2-stream site 1) — all fast
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract Symbolic_Run26_BufferConservation \
  --function check_site2 --solver-timeout-assertion 120000 --solver-threads 1 --statistics
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract Symbolic_Run26_BufferConservation \
  --function check_site1_collectNudge_2streams --solver-timeout-assertion 120000 --solver-threads 1
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract Symbolic_Run26_BufferConservation \
  --function check_site3 --solver-timeout-assertion 120000 --solver-threads 1
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract Symbolic_Run26_BufferConservation \
  --function check_lemma --solver-timeout-assertion 120000 --solver-threads 1

# the D32 3-stream pass
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract Symbolic_Run26_BufferConservation \
  --function check_site1_collectNudge_3streams_aggregate_b32 \
  --solver-timeout-assertion 180000 --solver-threads 1

# the anti-vacuity control — EXPECTED [FAIL]
PATH="$HOME/.foundry/bin:$PATH" ~/.local/bin/halmos \
  --contract Symbolic_Run26_MutantFalsification \
  --solver-timeout-assertion 120000 --solver-threads 1
```

Findings to file from this tier: **none.** No counterexample against the real
contract. The three 3-stream timeouts are recorded above as inconclusive and must
not be cited as verification.
