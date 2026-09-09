# Spec Conformance (Law 2) — phoenix-nft-staking, run 21

**Project:** `phoenix-nft-staking`
**Run:** `phoenix-nft-staking-21`
**Baseline commit:** `0d1a0b2`
**HEAD audited:** `c881a42`
**Stories checked:** `story-023` (`f3b92c0`), `story-022` Stage 7 (`fba4991`), `story-022` Stage 8 (`a261604`)

---

## How to read this report

This is the **Law 2 (faithfulness-to-stories)** report. It is a **separate deliverable from the QA
bundle** and must not be read as one. Nothing here is gas, style, or naming noise: every item is a
place where the shipped code, the normative documentation, or a story's own stated justification
**disagrees with each other**. A protocol whose spec has drifted from its code loses the ability to
tell a bug from a feature, which is why these are tracked in their own stream at honest severity
rather than bundled with lint.

Three items also carry security impact and are cross-referenced to their labels in the security
stream (`M-03`, `L-02`, `L-04`). Where an item has **no** security impact, that is stated plainly
rather than implied.

**Law 1 outranks Law 2.** One item in this report — the story-023 justification gap — is not "the
code deviates from the story". It is the harder case: **the story's own stated reason for declining
a source-level fix is only half true**, and the half that is false leaves an already-audited High
live in a file that mainnet deploys from. It is flagged separately and first, before the numbered
deviations, for that reason.

### ⚠ Label mapping — the F-numbers were resequenced

The severity-classifier **renumbered** the story-faithfulness tier's findings. Both the input IDs and
the final labels have the form `F-21-nn`, and **they do not line up**. Every item below is anchored
to its `classId`; resolve by `classId` or by content, never by assuming the numbers match.

| Input ID (story-faithfulness) | `classId` | **Final label** | Severity | Subject |
|---|---|---|---|---|
| `F-21-01` | `CLASS-21-003` | **`M-03`** (security stream) | medium | story-023 justification gap — `NFTStakerDepletion.sol:756` |
| `F-21-02` | `CLASS-21-011` | **`F-21-01`** | low | `INFTStakerMigratable` silent on the settlement trap |
| `F-21-03` | `CLASS-21-006` | **`L-03`** (security stream) | low | constructor probes `rewardToken()` but not `pendingReward()` |
| `F-21-04` | `CLASS-21-012` | **`F-21-02`** | qa | "Both branches are handled" — two-branch claim, three-branch space |
| `F-21-05` | `CLASS-21-013` | **`F-21-03`** | qa | disclosure covers the forward case, not the escrow case |
| `F-21-06` | `CLASS-21-014` | **`F-21-04`** | low | "contract references repointed" done as a literal-string repoint |
| `F-21-07` | `CLASS-21-015` | **`F-21-05`** | low | CLAUDE.md Feature Specification covers 1 of 11 contracts |
| `F-21-08` | `CLASS-21-021` | **carryover, ledger `F-20-07`** (no new label) | low | honeypot dismissal is a funding practice, not a structure |
| `F-21-09` | `CLASS-21-010` | **`Q-02`** (QA bundle) | qa | stale `"BatchNFTMinter:"` revert string after the rename |
| `F-21-10` | `CLASS-21-016` | **`F-21-06`** | qa | `BatchNFTMinterMultiToken` currently unreachable end-to-end |

Note the two traps this table exists to prevent: input `F-21-01` is **not** final `F-21-01` (it is
`M-03`), and input `F-21-06` is **not** ledger `F-20-07` (it is final `F-21-04`; ledger `F-20-07` is
input `F-21-08`).

---

## ⚠ TOP FLAG — Law 1 over Law 2: the story's justification is only half true

**Also filed in the security stream as `M-03`** — fingerprint `b3243f42394556ac118ef5656278d13f5e1e0ce3c4dea9ff0895694d69e5af84`, `classId` `CLASS-21-003`, input ID `F-21-01`.

### The spec text, verbatim

From the `[story-023]` commit body (`f3b92c0`):

> `NFTStakerDepletion.depositFor` settles the incoming user's pending phUSD with
> `_safePay(pending)`, which pays `msg.sender` -- the migrator -- instead of the
> user. **That staker is deployed and immutable, so the remediation lands on the
> migrator side.**

and, as the commit's closing line:

> **NO staker contract is modified.**

### The actual behaviour at HEAD

Both statements are **literally true of the deployed instances, and false of the file**. That
distinction is the whole finding.

`git show --stat f3b92c0` confirms the second claim exactly: the commit touches only `.gas-snapshot`,
`src/IStakerViews.sol`, `src/InPlaceNFTStakerMigrator.sol`, `src/NFTStakerMigrator.sol` and three
test files. No staker was modified. **That is the problem, not the reassurance.**

`src/NFTStakerDepletion.sol` is not a frozen archive of deployed bytecode — it is the **live
deployment template**, and it carries **no `DEPLOYED`/`FROZEN` banner** to tell a maintainer
otherwise. Fresh mainnet instances are minted from it:

- `lib/phoenix-phase-2-staging/script/DeployMainnetUniboostCutover.s.sol:478` —
  `new NFTStakerDepletion(...)`, three mainnet instances (EYE / SCX / FLX) under phStaging story-071.
- `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol:1461-1472` — deploys more.

Every instance deployed from here ships the defect intact. At `src/NFTStakerDepletion.sol:756`:

```solidity
pending = _safePay(pending);
if (pending > 0) emit Claimed(user, pending);
```

`_safePay` pays `msg.sender`. Inside `depositFor` — which is `onlyMigrator` — `msg.sender` **is the
migrator**, so an existing staker's earned phUSD is routed to the orchestrator while
`Claimed(user, pending)` is emitted at `:757` claiming the user was paid.

### The repo documents this pattern as wrong while shipping it as the template

The correct form is **already in-tree**, in a sibling file, with NatSpec that names the defect
explicitly. `src/NFTStakerPriceScaledMigrateReady.sol:869-876`, verbatim:

> ```
> ///         DELTA vs `NFTStakerDepletion.depositFor`: the pre-credit
> ///         settlement pays via `_safePayTo(user, ...)` rather than
> ///         `_safePay(...)`. `msg.sender` here is the MIGRATOR, so the
> ///         `_safePay` form would route an existing staker's earned phUSD to
> ///         the orchestrator while emitting `Claimed(user, ...)`. Only
> ///         reachable when the deposit target already holds a position (a
> ///         partial `InPlaceNFTStakerMigrator` round-trip, or migrating into
> ///         a staker the user is already in), but wrong in every case.
> ```

and the corresponding line at `src/NFTStakerPriceScaledMigrateReady.sol:887` is `pending =
_safePayTo(user, pending);`.

So the repository simultaneously (a) documents the `_safePay` form as **"wrong in every case"**,
(b) ships the corrected form in one staker, and (c) leaves the wrong form in the staker that the
mainnet cutover script actually deploys — with no in-file warning at the point a maintainer would
need to see it.

### Residual reach-paths that survive a migrator-side-only remedy

1. **Direct EOA / multisig caller.** `depositFor` is `onlyMigrator`, and `setMigrator`
   (`src/NFTStakerDepletion.sol:311-314`) accepts **any** address — no code-size check, no lifecycle
   gate. An operator address wired as migrator reaches `depositFor` directly and receives the user's
   settlement, with `Claimed(user, …)` still emitted. **No migrator-side fix can reach this path.**
2. **Any pre-`f3b92c0` migrator instance already deployed and wired.** The fix lands only on
   *redeploy + re-run `setMigrator` on both stakers*; the commit body never states that prerequisite.
3. **Any future third orchestrator** — see `F-21-01` below.
4. **Every future `NFTStakerDepletion` deployment.**

### Mitigating fact — stated so the severity is not read as higher than it is

`DeployMainnetUniboostCutover.s.sol` **never calls `setMigrator`** (verified: zero occurrences in the
file). The three new mainnet stakers therefore have `migrator == address(0)`, and **`depositFor` is
unreachable on them today**. No NFT-staking migrator appears in phStaging's scripts yet either. The
hazard is **latent, not active** — which is precisely why it is Medium and not High. It is not
dismissed, because latency here is a property of today's wiring, not of the code.

### Also verified clean

`batchMigrate` vs `migrate` was checked and is **correct**: the exit leg uses
`_safePayTo(account, pending)` at `src/NFTStakerDepletion.sol:733`. The misroute is confined to the
`depositFor` push leg.

### Deviation class

**Story-justification defect (Law 1 over Law 2).** This is not "the code fails to implement the
story" — the story was implemented faithfully and well. It is that the story's stated *reason* for
scoping the remediation to the migrator rests on a premise ("that staker is deployed and immutable")
that is true of instances and false of the file, and the gap between those two readings is where an
already-audited High survives.

### Ledger consequence

**Do NOT auto-flip `1c222d548523…` (ledger `H-01`, run-20, `fix-pending`) to `fixed`.** The mechanism
is good; the *closure* is not. `M-03` (`b3243f42…`) exists as its own entry specifically so that a
later flip of `1c222d54…` to `fixed` cannot orphan the residual source-tree hazard. **Both entries
must exist simultaneously** — never collapse them.

**Recommended:** change `:756` to `_safePayTo(user, pending)` for future instances (zero cost, matches
the in-tree sibling), and keep the forwarding as the compensating control for the already-deployed
stakers. Mirror the change across all four staker copies — it does not auto-propagate.

---

## Credit where it is due — what story-023 got right

A Law-2 report that lists only deviations misrepresents a good commit. Each claim below was
**independently traced at HEAD**, not taken on the NatSpec's word.

**1. The `require(captured <= owed)` bound is fail-closed and cannot misfire on a legitimate
migration.** `_syncBudget` (`src/NFTStakerDepletion.sol:423-435`) runs `_updatePool()` at `:424`
**before** `dispatcherHook.pull()` at `:429`. `_updatePool` (`:448-472`) and `pendingReward`
(`:799-813`) consume identical inputs — same `accRewardPerShare`, `rewardRate`, `windowEnd`, the same
`reward > rewardBudget` cap, the same `totalStaked > 0` / `Active` guards — at the same
`block.timestamp`. The `pending` settled at `:754` therefore equals the pre-call projection exactly,
and `_safePayTo` can only pay less, never more. The bound is genuinely a **tripwire, not a haircut**.

**2. The self-disabling claim holds.** `NFTStakerPriceScaledMigrateReady.depositFor` settles via
`_safePayTo(user, …)` at `:887`, so the migrator's balance is unchanged, `captured == 0`, and the
`if (captured > 0)` branch at `src/NFTStakerMigrator.sol:223` is skipped. Pinned by
`testVersionAgnosticPairDepletionVsPriceScaled` and `testVersionAgnosticInPlaceAgainstPriceScaled`.

**3. D-6 line-for-line parity holds.** `src/NFTStakerMigrator.sol:214-241` and
`src/InPlaceNFTStakerMigrator.sol:311-338` differ **only** in the staker handle (`newStaker` vs
`staker`) and a revert-string prefix (`"Migrator:"` vs `"InPlace:"`). Given that fork drift is the
exact mechanism that produced the original defect, holding this parity byte-identical is the right
call and was executed correctly.

**4. The shipped design is materially STRONGER than this audit's own run-20 proposed patch, in five
places.** The workspace patch was never merged and carries no authority; this comparison is
corroboration only, and it runs in upstream's favour.

| | run-20 audit patch | **story-023 (shipped)** |
|---|---|---|
| Reentrancy | none | `ReentrancyGuard` + `nonReentrant` on `migrate` / `migrateIn` / `claimForwarded` |
| Bound on the capture | **none** — would have forwarded any mid-call foreign inflow to whichever user the loop was on | `require(captured <= owed)` against the pre-call `pendingReward` |
| Blocklisted recipient | `safeTransfer` → **whole batch reverts** (a batch-DoS the patch shipped with) | escrow-on-failure + permissionless, self-only `claimForwarded()` |
| Owner reach into escrowed value | `rescueERC20` unconditional | floored by `totalUnforwarded` (`NFTStakerMigrator.sol:270-274`, `InPlaceNFTStakerMigrator.sol:392-396`) |
| InPlace rescue | untouched | `totalUnforwarded` floor **retrofitted** onto the existing contract |

Both added the missing rescue primitives to `NFTStakerMigrator`, which previously had none — that
closes ledger **`L-02` `cb1b52790cf1…`** (proposed `fixed`).

**5. The `Claimed`-event telemetry deviation was disclosed voluntarily**, at
`src/NFTStakerMigrator.sol:70-76`, before any auditor raised it. `F-21-03` below narrows that
disclosure; it does not retract the credit.

---

## F-21-01 — The interface that DEFINES the migrator role is silent about the trap story-023 exists to defend against

- **Final label:** `F-21-01` · **Input ID:** `F-21-02` · **`classId`:** `CLASS-21-011`
- **Fingerprint:** `1ad1434cf14db7e3e31dcd308cdfec25046e614ccf7feec28992dcc17dc43a0a`
- **Severity:** Low · **Security impact:** none directly; it is the missing guardrail for the hazard filed at Medium as **`M-03`**
- **Location:** `src/INFTStakerMigratable.sol:40-46` (`depositFor`)

### The spec text, verbatim

Story-023 names fork drift as the very thing it is defending against, at
`src/NFTStakerMigrator.sol:204-205`:

> ```
> ///      line-for-line identical to `InPlaceNFTStakerMigrator`'s (plan
> ///      decision D-6 — a divergence here is exactly the fork drift that
> ///      produced `pns20h1`).
> ```

The commit body records the deliberate decision not to widen the shared interface:

> `- NEW src/IStakerViews.sol: local rewardToken()/pendingReward(address)`
> `  extension; INFTStakerMigratable is deliberately left unwidened (D-5).`

### The actual behaviour at HEAD

`src/INFTStakerMigratable.sol:40-46` is the one artifact that *constitutes* the migrator role — the
only thing a fourth orchestrator author would read. Verbatim:

> ```
> /// @notice Permissioned deposit crediting `user` with `amount` ERC1155
> ///         units pulled from the caller (the migrator). Only valid while the
> ///         pool is `Active`, so it credits the new/healthy staker, never the
> ///         frozen one.
> /// @param  user   The user to credit.
> /// @param  amount The ERC1155 stake amount to deposit on the user's behalf.
> function depositFor(address user, uint256 amount) external;
> ```

It says **nothing** about `depositFor` settling to `msg.sender`, and nothing about the
capture-and-forward obligation that story-023 established as load-bearing for correctness. The
obligation exists in the two implementations and **nowhere in the contract that defines the role**.

D-5's reasoning — that this is "purely a migrator-local concern" — is **right about the type system
and wrong about hazard disclosure**. A third-party orchestrator written against the interface alone
compiles cleanly, omits the capture-and-forward leg, and silently captures users' rewards, with no
compile-time signal and no documentary warning.

### Deviation class

**Obligation-not-expressed-in-the-defining-artifact.** The story treats a correctness requirement as
implementation-local when the interface is what propagates it.

### Remediation

Document the capture-and-forward obligation in `INFTStakerMigratable.depositFor`'s NatSpec, and if
possible express it **structurally** (e.g. an accompanying `expectedSettlementRecipient()` or an
explicit forwarding hook) so it cannot be omitted silently.

---

## F-21-02 — "Both branches are handled" is a two-branch claim over a three-branch space

- **Final label:** `F-21-02` · **Input ID:** `F-21-04` · **`classId`:** `CLASS-21-012`
- **Fingerprint:** `ffdb34131dd45e9e73535624218f61af2d4d94aa48b215f9635d722f05db58e2`
- **Severity:** QA · **Security impact:** the undocumented third branch is the mechanism behind **`L-02`** (`7af123b5…`) — **linked, not merged**
- **Location:** `src/NFTStakerMigrator.sol:224-226` (`_depositForAndForward`)

### The spec text, verbatim

`src/NFTStakerMigrator.sol:224-226`:

> ```
> // Raw `transfer` inside `try`, NOT `safeTransfer`: SafeERC20
> // reverts rather than returning, which would defeat the `catch` on
> // non-reverting-false tokens. Both branches are handled.
> ```

The commit body makes the same two-branch claim:

> `- Escrow-on-failure (try/catch on raw transfer, handling both the revert and`
> `  the false-return branch) keeps a blocklisted recipient from bricking a whole`
> `  batch;`

### The actual behaviour at HEAD

The behaviour space has **three** branches, not two:

1. transfer reverts — handled by the `catch` (`NFTStakerMigrator.sol:236-240`);
2. transfer returns `false` without moving tokens — handled by the `else` (`:231-234`);
3. **transfer moves the tokens and returns `false`, or returns no data at all** — **not handled**.

A token returning **no data** on success fails the `returns (bool ok)` ABI decode. The outcome is
either an uncaught revert — the exact failure the `try/catch` exists to prevent — or, worse, a
**double-count**: the tokens are already gone, yet `unforwarded[user]` and `totalUnforwarded` are
credited anyway at `:232-233`, which then makes `balance - totalUnforwarded` underflow-revert
permanently in `rescueERC20` and lets `claimForwarded` pay out of another user's escrow.

`SafeERC20` handles all three, which is what makes the deliberate choice to avoid it the source of
the gap.

**Unreachable today:** the constructor pins `rewardToken` to the staker's own phUSD, a standard
bool-returning OZ ERC20, and weird-ERC20 behaviour is a C4 known-invalid class. Filed **QA and
explicitly not escalated**. `testG` / `testG2` cover the revert and false-return branches; there is
no no-return-data mock.

### Not suppressed because

The project's cached `systemAssumption` — *"OpenZeppelin used for all standard primitives (… SafeERC20)
— custom reimplementations prohibited"* — **cuts toward this finding, not against it**. It is not a
suppression basis.

### Deviation class

**Over-broad completeness claim.** The implementation's own documented claim is narrower than the
behaviour space it operates over.

### Remediation

Either adopt `SafeERC20` on the forward leg, or correct the claim to enumerate the third branch and
state explicitly why it is accepted. **Do not collapse with `L-02`** — same mechanism, different
fixes (arithmetic clamp vs. SafeERC20 adoption / documentation).

---

## F-21-03 — Disclosure covers the successful forward but not the ESCROWED case

- **Final label:** `F-21-03` · **Input ID:** `F-21-05` · **`classId`:** `CLASS-21-013`
- **Fingerprint:** `6e37fdb633e7a49ffac35ce3860fb0625ea6f5bfdbb07496208be065aed1fd05`
- **Severity:** QA · **Security impact:** none directly
- **Location:** `src/NFTStakerMigrator.sol:70-76` (disclosure) vs. `:231-234` (escrow branch); `src/NFTStakerDepletion.sol:756-757` (the `Claimed` emission)

### The spec text, verbatim

Story-023 discloses the telemetry deviation honestly — `src/NFTStakerMigrator.sol:70-76`:

> ```
> ///         OFF-CHAIN RECONCILIATION CAVEAT. The staker still emits
> ///         `Claimed(user, pending)` before the forward completes, so a settled
> ///         payment can traverse TWO transfers (staker -> migrator -> user) under
> ///         ONE `Claimed` event. Indexers keying on `Claimed` alone will
> ///         mis-source the payment; join it with `RewardForwarded` /
> ///         `RewardForwardFailed` from this contract to reconstruct the true
> ///         flow. No on-chain change compensates for this.
> ```

**Credit this** — it is a voluntary disclosure of a real deviation, made before any auditor raised it.

### The actual behaviour at HEAD

The disclosure describes the **successful-forward** branch: two transfers, one `Claimed` event, and a
reconciliation recipe that works. It does not cover the branch story-023 itself introduced.

In the **escrow** branch (`src/NFTStakerMigrator.sol:231-234` and `:237-239`), `Claimed(user, X)` is
already on-chain and final — emitted at `src/NFTStakerDepletion.sol:757` — while the user holds
**nothing**. The value sits in `unforwarded[user]` and must be retrieved by the user calling
`claimForwarded()` themselves. There is **no on-chain link** between the `Claimed` event and the
escrow, and no event fires on the user's own address at claim time to close the loop.

A user whose reward escrows therefore has no documented way to learn that the accounting considers
them paid while their balance shows nothing — **indefinitely**.

### Deviation class

**Incomplete disclosure of a story-introduced branch.** Same mechanism family as `L-02`, but a
distinct artifact (disclosure, not arithmetic) with a distinct fix.

### Remediation

Document the escrowed case and the `claimForwarded` recovery route wherever the successful-forward
case is documented, and emit an event on escrow so the condition is observable off-chain.

---

## F-21-04 — "Contract references repointed" was executed as a literal-string repoint only

- **Final label:** `F-21-04` · **Input ID:** `F-21-06` · **`classId`:** `CLASS-21-014`
- **Fingerprint:** `de7f81c5256323c44df1469a6676733010099ff33b0bc475f444da0d40eced79`
- **Severity:** Low · **Security impact:** none directly, but the affected document is the **normative spec** on which suppression decisions in this very audit depend
- **Location:** `docs/multi-token-nudge.md` §2 / §7 / §8

### The spec text, verbatim

`[story-022]` Stage 7 commit body (`fba4991`):

> `- docs/multi-token-nudge.md: Status flipped to implemented; contract references`
> `  repointed at the sibling`

### The actual behaviour at HEAD

The literal `BatchNFTMinter` strings **were** repointed correctly — none are left mis-pointing. But
`docs/multi-token-nudge.md` is a **delta spec**, written against a contract that was being edited in
place. Stage 7 invalidated that framing (the original contract was restored and a new sibling
created) without rewriting the document, so statements repointed *by name* retain the *semantics* of
the single-token predecessor they were written about:

- **`docs/multi-token-nudge.md:70-74`** lists four things as removed:

  > ```
  > Removed:
  > - storage `address public nudgePaymentToken`
  > - `setNudgePaymentToken(address)` / `NudgePaymentTokenChanged`
  > - `error BatchMint__NudgeTokenMatchesPaymentToken` (replaced, see below)
  > - the scalar `uint256 minReward` parameter
  > ```

  All four are **still live** in the frozen contract at `src/BatchNFTMinter.sol:87`, `:149-152`,
  `:111`, `:98`, `:242`. **Nothing was removed.**

- **`docs/multi-token-nudge.md:297`** still instructs:

  > `3. Implement: remove `nudgePaymentToken` state + setter, add `ReentrancyGuard`,`

  — actively wrong at HEAD; the state and setter are load-bearing on the restored frozen contract.

- **`docs/multi-token-nudge.md:353`**'s acceptance check is now unobservable:

  > `- existing single-token nudge cases: **+2-3k** (the guard) and otherwise flat;`

  Those cases now run against the **restored frozen contract**, which gained neither the guard nor
  `nonReentrant`.

- Six further implicit references still equivocate between the two contracts:
  `docs/multi-token-nudge.md:12-19`, `:109-111`, `:124-126`, `:160-162`, `:214`, `:314`.

### Stated for balance

The rest of the document's behavioural conformance is **excellent** and was checked exhaustively
against `src/BatchNFTMinterMultiToken.sol`: all §2 signatures and custom errors match exactly; all ten
§3 ordering steps appear in order; §4.1's *unconditional* payment-token exclusion is correct at
`src/BatchNFTMinterMultiToken.sol:426-428` — ahead of the `qualifies` ternary at `:429` and ahead of
the pull at `:357`; §4.2's four-site comment requirement is met; §4.3–§4.6 conform; and all 21 named
§6 tests are present by exact name. This finding is **not** a blanket criticism of the document.

### Not suppressed because

`docs/multi-token-nudge.md` is the **normative spec** for the new nudge behaviour (D-04) — it is the
designated replacement for the stale `CLAUDE.md`. A defect in it cannot be suppressed by the artifact
it replaces.

### ⚠ Fix trap — carried forward

Ledger **`L-03` `58b6c48605701f13…`** carries a fix trap: §4.1 requires the payment-token exclusion to
run **unconditionally**. This scan **re-confirms** the trap is still live and correct at
`src/BatchNFTMinterMultiToken.sol:426-428`. **Do not "fix" `L-03` by conditioning the guard on
`qualifies`.**

### Remediation

Re-derive §2 / §7 / §8 against `src/BatchNFTMinterMultiToken.sol` **as it actually is**, rather than
against the renamed predecessor.

---

## F-21-05 — Stage 8 rewrote the project structure accurately but left the authoritative spec covering 1 of 11 contracts

- **Final label:** `F-21-05` · **Input ID:** `F-21-07` · **`classId`:** `CLASS-21-015`
- **Fingerprint:** `3835e88a8c27564cfe160e37eae3560d3133444835f3bbd3111992c83ada4271`
- **Severity:** Low · **Security impact:** none directly — **but META-LOAD-BEARING on this audit's own suppression machinery**
- **Location:** `CLAUDE.md:31`, `:33` ("Feature Specification")

### The spec text, verbatim

`lib/phoenix-nft-staking/CLAUDE.md:31`:

> `Treat the list below as the authoritative spec. When the user asks for a new feature, cross-reference this list and remind them of any items still outstanding.`

and `:33`, asserting **in the singular**:

> `The emission model is the **variable-runway / owner-set APY target** — the owner configures a target APY for the average NFT, …`

`docs/multi-token-nudge.md:304` carried the instruction that was supposed to keep this current:

> `Update CLAUDE.md if the nudge is described there`

*(Line anchors are given at HEAD `c881a42`. The story-faithfulness tier cited `:44-45`/`:47`; the
normative text is at `:31`/`:33` in the file as it stands. Same statements, corrected anchors.)*

### The actual behaviour at HEAD

That "authoritative spec" describes **one of eleven** files in `src/`. The eleven at HEAD are:
`BatchNFTMinter.sol`, `BatchNFTMinterMultiToken.sol`, `INFTStakerMigratable.sol`, `INFTSupply.sol`,
`IStakerViews.sol`, `InPlaceNFTStakerMigrator.sol`, `NFTStaker.sol`, `NFTStakerDepletion.sol`,
`NFTStakerMigrator.sol`, `NFTStakerPriceScaled.sol`, `NFTStakerPriceScaledMigrateReady.sol`.

Absent from the spec entirely: **`NFTStakerDepletion`** — a *different* emission model, and the one
actually on mainnet three times over — plus both price-scaled variants, both migrators, both minters,
and all three interfaces. A case-insensitive grep of `CLAUDE.md` for
`batch|nudge|multi-token|depletion|pricescaled|migrator` yields two hits, neither a spec reference.

The `docs/multi-token-nudge.md:304` instruction was **conditional** (*"if the nudge is described
there"*); the condition evaluated false, so the instruction silently terminated as a no-op and the
multi-token nudge never entered the spec at all.

Since `CLAUDE.md` is a designated Law-2 story source, anyone cross-referencing it for a change to the
depletion staker or either minter gets **no acceptance criteria whatsoever**.

### Why this is Low and not QA — it is load-bearing on the audit itself

`CLAUDE.md` is the registered `knownIssuesSource` for this project. Its narrowness is:

- the reason **zero** cached known-issue suppressions could be applied this run, and
- the reason two cached `designDecisions` are actively contradicted at HEAD.

The risk is process, not exploitation: a stale suppression list hiding a live bug in a future run.

### Not suppressed because — circularity bar

Suppressing a finding **about the staleness of the known-issues source** *using that source* is
precisely the failure mode the run's hard constraint exists to prevent.

### Also verified accurate

The `"NOT a deployment or staging repo"` block at `CLAUDE.md:95-111` is **fully accurate** and well
written. Project Structure at `:113-118` has no phantom entries, though it omits `docs/`,
`snapshots/`, `.gas-snapshot` and `test/mocks/`.

### Remediation

1. Widen the Feature Specification to cover all eleven first-party contracts, or add a real
   *Known Issues / Out of Scope* section.
2. **Then** re-extract `registered-projects.json`'s cached `knownIssues`.
   **Re-extraction is BLOCKED until the spec is widened** — a re-extraction against today's file would
   simply re-cache the same 1-of-11 coverage.

---

## F-21-06 — Tracking note: the newly landed `BatchNFTMinterMultiToken` is currently unreachable end-to-end

- **Final label:** `F-21-06` · **Input ID:** `F-21-10` · **`classId`:** `CLASS-21-016`
- **Fingerprint:** `130363a930a51b1383bec8205d127e569ccda73dae09216f5ddee2b75a41ab5b`
- **Severity:** QA (scope/tracking record) · **Security impact:** none
- **Location:** `CLAUDE.md:95-111` ("NOT a deployment or staging repo")

### The spec text, verbatim

`CLAUDE.md:95-101`:

> ```
> ## ⚠️ This is NOT a deployment or staging repo
>
> This submodule is **contract source and tests only**. It has no `script/` directory
> and must not acquire one.
>
> - **Never** add a Foundry deployment script (`script/*.s.sol`), …
> ```

### The actual behaviour at HEAD

Eight stages of story-022 landed `src/BatchNFTMinterMultiToken.sol`. It has **no deploy path here**
(correctly forbidden by the rule above) **and none there**: a grep of the entire
`phoenix-phase-2-staging` repo for `BatchNFTMinterMultiToken` returns **zero** hits. The contract
cannot currently be exercised end-to-end.

This is a normal intermediate state. It is recorded so it is not assumed shipped.

### ⚠ This note must NEVER be used to discount a severity

Run-20 ruling **R-6** applies: *"not deployed" is a deployment-status fact, not a severity bound.* It
is written down solely so a reader knows **which** exposure statements are bounded by it and which are
not:

- **Bounded by it:** the present exposure of `M-01`, ledger `M-02` (`a62fe01a…`) and the ledger
  `H-01` reopen **on the new file**.
- **NOT bounded by it — entirely unaffected:** the frozen, mainnet-**deployed** twin
  `src/BatchNFTMinter.sol`, where the byte-equivalent code is live today.

### Remediation

**Track:** when the deploy path lands, every finding on `src/BatchNFTMinterMultiToken.sol` must be
re-read for present exposure — starting with `M-01`'s escalation trigger.

---

## Verified faithful — no finding

### story-022 Stage 7: "a pure file/name split plus a verbatim restore — no design change"

The claim, verbatim from `fba4991`:

> ``BatchNFTMinter` is deployed and must stay frozen. Stages 0-6 modified it in`
> `place (a planning defect, not an execution defect). This commit is a pure`
> `file/name split plus a verbatim restore -- no design change.`

and:

> `- src/BatchNFTMinter.sol, test/BatchNFTMinter.t.sol and`
> `  test/BatchNFTMinterNudge.t.sol restored byte-identical from 99a55ac, save for`
> `  one added @notice on the contract marking it deployed/frozen`

**Mechanically verified TRUE.** Both halves of the claim were checked by diff, not by reading:

- **The frozen file vs. its pre-story-022 state:** `git diff 99a55ac fba4991 -- src/BatchNFTMinter.sol`
  reports **`1 file changed, 6 insertions(+)`** — and all six inserted lines are the
  `@notice **DEPLOYED — FROZEN.**` block at `src/BatchNFTMinter.sol:14-19`. **Zero deletions, zero
  modifications.** The restore is byte-identical exactly as claimed.
- **The new file vs. the pre-split contract:** diffing `fba4991^:src/BatchNFTMinter.sol` against
  `fba4991:src/BatchNFTMinterMultiToken.sol` yields **exactly two changed lines** — the `@title` at
  `:14` and the `contract` declaration at `:82`. The body, including the private `_snapshotRewards` /
  `_payRewards` helpers, is untouched.

Six added `@notice` lines on the frozen file, two changed lines on the new one. The claim is exact.

### story-022 Stage 8: script deletion, and why deletion-not-repair was the right call

Verified and faithful. `script/` is gone at HEAD; a repo-wide grep for `DeployBatchNFTMinter` outside
`lib/` returns only the three intentional prose mentions at `CLAUDE.md:97`, `:100`, `:108`; and the
`script/` bullet was correctly dropped from Project Structure.

**The deployment procedure is not left dangling, and the deleted script's own root cause verifiably
does not exist in the repo it redirects to.** `CLAUDE.md:108-111` justifies the deletion on the
grounds that the script *"had stopped setting a required constructor-adjacent config on the contract
it deployed"*. In the staging repo,
`lib/phoenix-phase-2-staging/script/MigrateBatchNFTMinter.s.sol:430` calls
`setNudgePaymentToken(USDC)` and **asserts** it at `:443`, plus the prime-token exclusion at `:456`.
The redirect target does the thing the deleted script had stopped doing. **Deletion rather than repair
was the safe call.**

---

## Carryover — ledger `F-20-07`: STILL OPEN, re-anchored

- **Ledger label:** `F-20-07` · **Input ID:** `F-21-08` · **`classId`:** `CLASS-21-021`
- **Fingerprint:** `a7dffb34c9904a7fa9fb9e5f831bb72c04f70cd239b5631dda9d25bf5845ce51`
- **Ledger status:** `open` — **unchanged**
- **Severity at HEAD:** Low — **unchanged**, re-derived at HEAD and still standing
- **Consumes no new label** (it reconciles to an open ledger entry) and **cannot be suppressed**

> **This is a re-anchor, not a status change.** The finding is neither newly discovered nor resolved;
> only its line references move, and a second site is added.

### Re-anchoring

| | run-20 | **run-21** |
|---|---|---|
| Doc site | `docs/multi-token-nudge.md:41` | **`docs/multi-token-nudge.md:42-46`** |
| Code site | — | **`src/BatchNFTMinterMultiToken.sol:56-61`** (new second site) |

Stage 7 repointed the contract name at `docs/multi-token-nudge.md:50` but left the claim itself
verbatim — **and carried it into a new contract's NatSpec**, which is why a second site now exists.

### The spec text, verbatim

`docs/multi-token-nudge.md:42-46`:

> ```
> The pot is a *nudge*: by construction it is a fraction of the cost of the
> `nudgeSize` mints required to qualify. A bot that claims it must first pay more
> payment-token into the protocol than it extracts in reward. Every claim is
> net-positive for the protocol; there is no configuration of this mechanism
> under which claiming is profitable-in-isolation.
> ```

The same claim now also sits at `src/BatchNFTMinterMultiToken.sol:56-61`:

> ```
> ///      framing does not apply, because the pot is by construction a fraction of
> ///      the cost of the `nudgeSize` mints required to qualify — every claim is
> ///      net-positive for the protocol. If someone over-funds this contract
> ///      beyond the mint cost and a bot snipes it, that is still correct
> ///      behaviour; the error was in the sender.
> ```

### The actual behaviour at HEAD

**No code enforces any ratio, cap, or value comparison.** Both files were read in full, plus a
non-truncated grep of every comparison operator. In `src/BatchNFTMinterMultiToken.sol` every
comparison is one of:

- `:352` — a **count** gate (`count >= nudgeSize`), purely numeric;
- `:363` / `:424` / `:454` — loop bounds;
- `:382` / `:384` — payment-token dust and refund arithmetic;
- `:431` — `available < minReward`, a **caller**-protective minimum, never a protocol-protective maximum;
- `:456` — a zero skip.

`paymentAmount` (`:297`, `:357`, `:384`, `:386`) **never shares an expression** with `snapshot`,
`available`, or any reward amount, and the contract never reads the dispatcher's price at all (only
`primeToken()` at `:322`). The frozen sibling is identical in conclusion.

The claim is therefore an **off-chain funding-discipline property presented as a structural one**.

The document concedes as much three lines later, at `docs/multi-token-nudge.md:48-50`:

> ```
> If someone erroneously over-funds the contract beyond the mint cost and a bot
> snipes it, that is still correct behaviour — the error was in the sender, not in
> `BatchNFTMinterMultiToken`.
> ```

That sentence and "there is no configuration of this mechanism under which claiming is
profitable-in-isolation" cannot both be true. And the claim is falsifiable from **owner-reachable
state alone**: `setNudgeSize` (`src/BatchNFTMinterMultiToken.sol:166-169`) has **no lower bound**, so
`nudgeSize = 1` makes a single mint qualify for the entire balance of every listed token, while the
pot side is permissionless and unbounded.

### Why it stays here and not in the security stream

Disposition unchanged from run-20: **spec-conformance report only, no `L-xx` label.** The claim is
load-bearing under **both** reopened expired closures — it is the premise on which the nudge lineage's
dismissal rested — but the value impact is already fully accounted for in those existing nudge
findings. Filing it in the security stream would **double-count one defect**.

### ⚠ Do not collapse with `L-04`

Run-21 **`L-04`** (`75305ec0242b81580370518010c737b002a788ded54868271aec77d0c4542fa9`) is the **code-site
twin** of this finding — the same claim, at `src/BatchNFTMinterMultiToken.sol:56-61`, filed in the
security stream. **Same claim, two artifacts.** Collapsing them loses whichever site is not chosen as
canonical.

### Remediation

Rewrite §1 to state the margin as an **operational** invariant that must be monitored, with a named
owner — or enforce it in code by bounding the payout as a value-based fraction of what the batch
actually paid. The second option is what would let the reopened nudge lineage be closed
**structurally** rather than by configuration.

---

## Proposed ledger actions (human applies via `/ledger`)

| Fingerprint | Label | Now | Proposal |
|---|---|---|---|
| `1c222d548523…` | `H-01` (run-20) | `fix-pending` | **KEEP `fix-pending`.** Do **not** flip to `fixed` — see the TOP FLAG. Record the migrator-side fix as *likely-fixed-for-covered-paths*. |
| `cb1b52790cf1…` | `L-02` | `open` | **Propose `fixed`** — `rescueERC20` / `rescueERC1155` landed in story-023. |
| `a7dffb34c990…` | `F-20-07` | `open` | **Remains `open`.** Re-anchor to `docs/multi-token-nudge.md:42-46`; **add** `src/BatchNFTMinterMultiToken.sol:56-61` as a second site. Status unchanged. |

### Do-not-collapse register (spec-conformance stream)

| Pair | Reason |
|---|---|
| `M-03` (`b3243f42…`) ↔ ledger `H-01` (`1c222d54…`) | `M-03` is the **residual source-tree hazard that survives** the migrator-side fix. If `1c222d54…` is ever flipped to `fixed` while `:756` stays unmarked, the hazard would have **no ledger representation at all**. Both must exist simultaneously. |
| `F-21-02` ↔ `L-02` (`7af123b5…`) | Same mechanism, **different fixes**: arithmetic clamp vs. SafeERC20 adoption / documentation. |
| ledger `F-20-07` (`a7dffb34…`) ↔ `L-04` (`75305ec0…`) | Same claim, **two artifacts** (doc site vs. code site). |
| `L-03` (`afa52000…`) ↔ ledger `L-01` (`e7bccb02…`) | Same constructor, different root-cause class, different fix. **Link, do not merge.** |
