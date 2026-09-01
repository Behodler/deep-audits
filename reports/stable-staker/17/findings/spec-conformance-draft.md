# Spec Conformance (Law 2) — stable-staker run-17

> **F-label reconciliation (2026-09-01).** Canonical mapping is the published `submissions/spec-conformance.md`:
> F-01=CLASS-001, F-02=CLASS-009, F-03=CLASS-010, F-04=CLASS-011, F-05=CLASS-012, F-06=CLASS-002.
> This draft's original F-01 (the fee-charging ERC4626 shortfall item, CLASS-002) has been renumbered **F-06**.
> F-02..F-05 are unchanged and already agree with the published report.

Scan type: story-faithfulness | Source: `lib/stable-staker` @ `96d39ed` | Range `fa06de5..96d39ed` (11 commits, all `[story-025]`)

**Stories checked:** story-025.

**Story document resolved (mandatory retrieval, done):**
`~/code/product-owner/stories/stable-staker/auto-complete/stable-staker-auto-annihilate/025-force-annihilation-on-claim.md`
— single hit across the whole `stable-staker` tree (globbed `025-*.md` and `025.*-*.md` over all
state folders). 1339 lines, three execution rounds appended in place.

**State-folder note.** `auto-complete` is *machine* approval, not human review. The final stamp
reads `**Approved by**: story-batch workflow (machine approval — not human-reviewed)`, acting on a
`**Review Status**: ISSUES_FOUND` triaged non-blocking by the same automated driver. Every round of
execution and review ran `--inline-delegation` with a self-declared `Independence: reduced`. Round 2
was **rejected outright** by its own reviewer (`## Review Failure Report - 2026-08-31T23:02:24Z`,
`[high]`) and round 3 is the fix-forward for that rejection. The acceptance criteria below are
therefore authoritative *text*; their sign-off carries no independent-human weight, and the two
`[low]` items carried forward at auto-completion are open by the story's own admission.

**Commit-vs-document divergence:** none material. The 11 commit subjects are an accurate index of
the three rounds the document records (`50af50d`/`339bdd4`/`afa7b80` = round 1; `f0649e8`/`3a134ce`/
`1aeccb2`/`57eb02d` = round 2; `7112756`/`9346933`/`a961e10` = round 3; `96d39ed` = polish).

---

## Conformance matrix — story-025

Verified at `96d39ed`. The story's own checklist is reproduced against landed code.

| Story requirement | Landed |
|---|---|
| `bool public claimEnabled`, false on deployment | `src/StableStakerV2.sol:100` (no initializer) |
| `setClaimEnabled(bool) external onlyOwner` emitting `ClaimEnabledSet` | `:279-282` |
| `require(claimEnabled, "StableStaker: claim disabled")` first statement of `claim()` | `:440` |
| `_exitPosition` antimatter mint left **ungated**, with a comment saying so | `:842-847` |
| `claim` docstring no longer calls it "the only user-facing path that mints" | `:426-438` |
| `AutoAnnihilated(token, user, antimatterBurned, principalConsumed, excessMinted)` | `:194-200` |
| decimals-scale helper, live read, `require(dec <= 18)` | `_antimatterScale`, `:1122-1126` |
| `IAntimatter` extended with `annihilate` + `toStableAmount`; NatSpec corrected | `src/interfaces/IAntimatter.sol` |
| `autoAnnihilate` guarded `nonReentrant whenNotPaused poolExists` + `PoolState.Active` | `:516-517` |
| stable sourced via `_routeExit(token, gross, true)`, not idle balance | `:578` |
| annihilated amount floored to a multiple of `scale` | `netWanted = capped / scale` (`:548`); `annihilatable = netUsed * scale` (`:593`) |
| sub-unit dust carried in `unclaimedReward`, never minted | `:552` |
| four-part bookkeeping (`user.amount`, `totalStaked`, re-based `rewardDebt`, `_stakers.remove`) | `:565-571` |
| excess minted straight to the caller | `:602-604` |
| `forceApprove(…, netUsed)` … `forceApprove(…, 0)` bracketing `annihilate` | `:598-601` |
| registered-stable coupling surfaced as BOTH a view and an explicit revert | `autoAnnihilateAvailable` `:1051`; `require(...)` `:521` |
| GROSS (not net) capped at `user.amount`; both ledgers debited by the GROSS | `:558`, `:565-566` |
| preview treated as advisory; real balance delta MEASURED and floored | `:578-589` |
| over-delivery forwarded to the caller | `:605-608` |
| `src/versions/` and `FROZEN.sha256` byte-unchanged | `git diff fa06de5..96d39ed -- src/versions/` empty |

**Arithmetic conservation holds.** `owed = capped + excessBase`, `capped = netWanted*scale + dust`;
minted = `netUsed*scale` (annihilated) + `excessBase + (netWanted-netUsed)*scale` (raw) =
`netWanted*scale + excessBase`; `dust` re-booked. Nothing is created or stranded, so the
emission-cap invariant survives. Antimatter's own `toStableAmount` decimals cross-check
(`lib/antimatter/src/Antimatter.sol:326-329`, `DecimalsMismatch`) is real, so the NatSpec claim at
`:1117-1121` that the live decimals read "has an independent auditor on every call" is **true**.

**Verdict: substantively faithful.** Five deviations follow — one with real availability impact.

---

### F-06 (draft label F-01 — renumbered to the canonical published mapping) — the rounding allowance does not cover a fee-charging ERC4626 vault, so the round-2 blocking defect survives at fee scale on the intended production target

- **type:** faithfulness (story-completeness) with availability escalation
- **storyTag:** story-025 (round 3, Autonomous Decision 1)
- **severity:** potential-medium
- **contract/function:** `src/StableStakerV2.sol` — `autoAnnihilate`
- **line:** 589 (range 578-592); constants at `:70`, `:78`
- **lawImpacted:** 2, escalating to 1 (availability of the only reward path)
- **confidence:** high

**specText** — the acceptance criterion, from the story's own `## Review Failure Report -
2026-08-31T23:02:24Z`, "Recommendations for Next Attempt", verbatim:

> "- [x] Re-derive the shortfall floor so a double-rounded-down ERC4626 delivery of
>       `amount - 1` (or a routine haircut) does **not** revert `autoAnnihilate`."

and the failure report's own statement of impact:

> "Because `claimEnabled == false` by default, `autoAnnihilate` is the **only** reward path, so
> the story's stated goal fails in production."

**specSource:** story doc, `## Review Failure Report - 2026-08-31T23:02:24Z` (blocking `[high]`),
plus `## Autonomous Decisions — Round 3`, Decision 1.

**actualBehavior.** Round 3 shipped `EXIT_ROUNDING_ALLOWANCE = 2` raw units plus
`EXIT_ROUNDING_ALLOWANCE_BPS = 1` (one basis point):

```solidity
uint256 allowance = EXIT_ROUNDING_ALLOWANCE + (netFloor * EXIT_ROUNDING_ALLOWANCE_BPS) / MAX_BPS;
uint256 floorWithAllowance = netFloor > allowance ? netFloor - allowance : 0;
require(received > 0 && received >= floorWithAllowance, "StableStaker: exit shortfall");
```

`ERC4626YieldStrategy` does **not** override `previewExitFor` — confirmed by grep over
`lib/reflax-yield-vault/src/`: the only two implementations are `AYieldStrategy.sol:571` and
`ERC4626MarketYieldStrategy.sol:162`. So it inherits `AYieldStrategy`'s capped identity
(`netGuaranteed = grossToRequest`, `AYieldStrategy.sol:580-581`), `netFloor` collapses to `gross`,
and the check becomes `received >= gross - 2 - gross/10_000`.

`ERC4626YieldStrategy._disposeShares` (`:126-135`) redeems `vault.convertToShares(amount)` —
the **fee-free** ideal conversion — and the vault's `redeem` returns assets *net of the vault's
fee*. On a fee-charging vault the delivery is short by the fee, not by 1–2 wei. Any exit fee above
**1 basis point** therefore trips `"StableStaker: exit shortfall"`, and with `claimEnabled == false`
on deployment `autoAnnihilate` is the only reward path — a complete reward-path DoS.

The story knows this and ships anyway (Decision 1, verbatim):

> "A larger bps tolerance (e.g. 50 bps to also absorb a fee-charging vault's over-quote) was
> rejected — it widens the claim-gate-bypass window by a real, extractable margin for a case nobody
> has yet configured, and a fee-charging vault genuinely wants its own `previewExitFor` override in
> vault-RM rather than a fudge factor here."

**"a case nobody has yet configured" is the load-bearing premise, and it is contestable.**
`ERC4626YieldStrategy` is the strategy wired against Tokemak-style autopools (`autoDOLA`/`autoUSD`)
— the same fee behaviour that reflax-yield-vault run-16 filed as L-16 (fee-blind NAV
over-statement). The deferred `previewExitFor` override does **not** exist at the pinned
`lib/reflax-yield-vault` commit `cdd0743`, so there is no landed remedy anywhere in the tree.

**deviation.** The criterion the round-2 reviewer set was "a routine haircut does not revert". Round
3 satisfies it only for *rounding*-scale shortfall (≤ 2 units + 1 bp) and explicitly not for
fee-scale shortfall. The test fixture cannot detect the residual for the same structural reason the
round-2 fixture could not detect the original: `MockERC4626Vault` is OpenZeppelin's reference
`ERC4626` plus a donation helper and charges **no fee**, so the round-3 regression proves only the
double-round-down case.

**Recommended posture.** Either land the `previewExitFor` override on `ERC4626YieldStrategy` in
vault-RM before this reaches a fee-charging vault, or make `autoAnnihilateAvailable(token)` refuse a
vault whose `previewRedeem` is materially below `convertToAssets` so the failure is a legible
pre-flight rather than a revert deep inside the only reward path. Do not simply widen the bps leg —
Decision 1's objection to that is sound.

---

### F-02 — CLAUDE.md's headline description of `autoAnnihilate` still states the round-1 net debit, which round 2 identified as the underflow bug

- **type:** invariant-violation (documentation asserts a behaviour the code does not have)
- **storyTag:** story-025 (round 2, "The agreed design (human decision)", item 4)
- **severity:** low
- **contract/function:** `lib/stable-staker/CLAUDE.md` — "The claim gate and `autoAnnihilate` (story 025)", opening paragraph; code at `src/StableStakerV2.sol:565-566`
- **lawImpacted:** 2
- **confidence:** high

**specText** — CLAUDE.md as landed at `96d39ed`, verbatim:

> "…annihilates it against a slice of the caller's **own booked principal**, decrements
> `userInfo.amount` and `poolInfo.totalStaked` **by the stable half**, and Antimatter mints the
> resulting phUSD straight to the caller."

**specSource:** `lib/stable-staker/CLAUDE.md`, added by `afa7b80`, not corrected by `57eb02d` or
`a961e10`.

**actualBehavior.** `:565-566` debit the **GROSS**, not the stable half:

```solidity
user.amount -= gross;
pool.totalStaked -= gross;
```

**deviation.** "By the stable half" is precisely the net-based debit the story's round-2 reopen
identifies as a live bug — *"if the cap stays on the net amount then `user.amount -= stableNeeded`
underflows for exactly the user annihilating their whole position"*. A later bullet in the same
CLAUDE.md section states the correct gross semantics and calls capping the gross "load-bearing", so
the document contradicts itself, and the wrong version is the one a reader meets first. Per the
project's standing rule that a falsely-exhaustive doc raises rather than lowers severity, this is
filed rather than waived: it is the summary sentence a future implementer will copy.

**Fix:** replace "by the stable half" with "by the gross the strategy exit consumed".

---

### F-03 — `autoAnnihilateAvailable` reports `true` in exactly the state where `autoAnnihilate` reverts, inverting Autonomous Decision 4's stated rationale

- **type:** faithfulness
- **storyTag:** story-025 (round 2, Autonomous Decision 4)
- **severity:** low
- **contract/function:** `src/StableStakerV2.sol` — `autoAnnihilateAvailable` / `autoAnnihilate`
- **line:** 1058-1060 (view early-return); interacts with `:557`
- **lawImpacted:** 2
- **confidence:** high

**specText** — story doc, Autonomous Decisions Round 2, Decision 4, verbatim:

> "The probe is skipped when the strategy custodies nothing for the pool, because then there is no
> principal to annihilate against and the reward-outran-principal path still legitimately works —
> reporting `false` there would be the inconsistent answer."

and the round-2 checklist criterion it answers: *"the view stays consistent with what the call will
do"*.

**actualBehavior.** The view early-returns `true` whenever the strategy holds nothing for the pool:

```solidity
IYieldStrategy strategy = yieldStrategy[token];
if (address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0) {
    return true;
}
```

But a staker can hold `user.amount > 0` while the strategy custodies nothing — principal sitting
idle in the contract after a buffer-path `relinquishPrincipal`, or a strategy set before any
deposit routes into it. In that state `netWanted > 0`, and **both** `previewExitFor`
implementations cap `grossToRequest` at the strategy's own per-account ledger
(`AYieldStrategy.sol:579-581`, `ERC4626MarketYieldStrategy.sol:181-184`), which is zero — so
`grossQuote == 0` and `:557` reverts:

```solidity
require(netWanted == 0 || grossQuote > 0, "StableStaker: exit unavailable");
```

**deviation.** Decision 4 reasons that `false` would be the inconsistent answer in this state. The
code makes `true` the inconsistent answer: the view greenlights a button that the transaction then
refuses. The UI cannot distinguish it without simulating, which is the exact failure mode Decision 4
exists to prevent. This is a live-state case, not the `>18 decimals` cosmetic drift already carried
forward from round 1.

**Fix:** the early-return should be conditional on the caller actually needing a strategy exit —
i.e. return `true` on `principalOf == 0` only when the reward-outran-principal path is the one being
taken, not unconditionally.

---

### F-04 — on the underwater path the caller is handed a grossed-up par draw on the shared buffer, and the docs describe only the un-grossed draw

- **type:** faithfulness (undocumented behaviour on a value-moving path)
- **storyTag:** story-025 (round 3, Decision 3 / CLAUDE.md underwater carve-out)
- **severity:** low
- **contract/function:** `src/StableStakerV2.sol` — `autoAnnihilate`
- **line:** 605-608 (range 578-608)
- **lawImpacted:** 2
- **confidence:** high

**specText** — CLAUDE.md as landed, the round-3 carve-out, verbatim:

> "The carve-out is the **underwater** path, which `autoAnnihilate` shares with `withdraw` and does
> not change: when `_isUnderwater` is true, `_routeExit` pays the whole request out of the idle
> balance plus `relinquishPrincipal` and returns the nominal amount without measuring anything."

**actualBehavior.** True as far as it goes, but incomplete on the consequence. `_routeExit`'s
underwater branch (`:1184-1192`) returns the *nominal* `gross` without touching the strategy, so
`received == gross`. `gross` was grossed **up** by the strategy's slippage tolerance for a haircut
that does not occur on this path, so:

```solidity
netUsed  = received < netWanted ? received : netWanted;   // == netWanted
surplus  = received - netUsed;                            // == gross - netWanted  > 0
...
IERC20(token).safeTransfer(msg.sender, surplus);
```

The caller receives `netWanted` worth of annihilation **plus** `gross - netWanted` in raw
stablecoin, both funded entirely from the contract's idle balance — the shared
underwater-withdrawal buffer — and `relinquishPrincipal(token, gross)` writes the strategy's booked
principal down by the inflated figure too.

**deviation.** The caller is not over-credited (`user.amount` is debited by the same `gross`), so
this is **not** a value leak and **not** a Law-1 escalation: an equivalent `withdraw` already draws
at par from the buffer. What is undisclosed is the *rate*: `autoAnnihilate` draws the
slippage-tolerance-inflated `gross` from a scarce, first-come buffer for a transaction that
economically needs only `netWanted`, accelerating buffer exhaustion against later stakers by the
gross-up factor. The story's round-2 checklist claims *"confirm the idle buffer is untouched across
every case above"* and enumerates only the full-credit, haircut, whole-position and lying-preview
scenarios; the round-2 reviewer's own `[low]` noted no test covers `autoAnnihilate` against an
underwater strategy, and none was added in round 3.

**Fix:** either skip the gross-up when `_isUnderwater` is true (request `netWanted`, since no
haircut applies), or document the amplification explicitly in the carve-out paragraph. Add the
missing underwater test — round 3 corrected `MockYieldStrategy.previewExitFor` to honour
`valueFactorBps` specifically so this case *could* be tested, and then did not test it.

---

### F-05 — the strategy's own per-client cap silently converts annihilatable reward into raw minted Antimatter, a gate-bypass widening the story never modelled

- **type:** faithfulness (story-completeness)
- **storyTag:** story-025 (round 2, "Front-running analysis"; round 1 auditor note)
- **severity:** low
- **contract/function:** `src/StableStakerV2.sol` — `autoAnnihilate`
- **line:** 596 (range 554-596)
- **lawImpacted:** 2
- **confidence:** medium

**specText** — story doc, round-2 design, item 2, verbatim:

> "Cap the **GROSS** figure at the caller's own principal (`user.amount`) — **not** the net figure."

and the front-running analysis's bound on the raw-mint path:

> "It is bounded: `ERC4626MarketYieldStrategy` enforces `minOut = idealUnderlying * (MAX_BPS -
> slippageToleranceBps) / MAX_BPS` internally and reverts before `autoAnnihilate` ever sees the
> proceeds, so the extractable amount is capped at the tolerance…"

**actualBehavior.** There is a **second** cap the story does not account for. Both `previewExitFor`
implementations independently cap `grossToRequest` at the strategy's per-client ledger
`clientBalances[token][address(this)]`. When that cap binds, `grossQuote` — and with it `gross`,
`netFloor` and ultimately `netUsed` — shrinks below `netWanted`, and the undelivered remainder is
minted **raw**:

```solidity
uint256 excess = excessBase + (netWanted - netUsed) * scale;
...
if (excess > 0) { antimatter.mint(msg.sender, excess); }
```

On `ERC4626MarketYieldStrategy` this cap binds structurally, not exceptionally:
`_acquireShares` books `creditedPrincipal = _creditedPrincipal(amount)` — the haircut value, not
the nominal deposit — so the strategy's `clientBalances` is *permanently* below the pool's nominal
`totalStaked`. Any exit large relative to the strategy's booked balance therefore routes part of the
reward through the raw-mint path.

**deviation.** The story's bound on the raw-mint path is the AMM slippage tolerance. The real bound
is `min(user.amount, clientBalances[token][staker])`, and the second term is neither
user-controllable (so this is not an attack vector) nor bounded by the tolerance (so the story's
"capped at the tolerance" claim is not the whole picture). Given the memory note that V2's
Antimatter is redeemable into unbacked phUSD, the raw-mint path deserves an accurate bound in the
story rather than an understated one — though **conservation still holds** (`owed` in equals
annihilated + raw-minted + carried dust), so no antimatter is created that the caller was not
already owed, and this is **not** a Law-1 escalation.

**Fix:** documentation. State the true bound on the `excess` path in CLAUDE.md's front-running
bullet, and note that on the market strategy the credited-principal gap makes partial raw-minting
the normal case rather than the exceptional one.

---

## Law-1 override — checked, does not fire

Assessed independently of conformance: *if the code did exactly what the story says, would that be
exploitable?* Three candidates were examined and all three are declined, deliberately and with
reasons, so that a later reader does not re-litigate them:

1. **The `excess` raw-mint loophole around the closed `claim` gate.** The story's auditor note
   accepts it explicitly. The quantity minted is exactly what `claim()` would have minted for the
   same `owed` — no antimatter is created beyond the accrual the emission cap already governs, so
   there is no dilution of the unbacked-phUSD backing set. The gate is stated, repeatedly and in
   both the story and CLAUDE.md, as a UX mechanism and never a security boundary; nothing in the
   contract's safety argument rests on antimatter being unobtainable. **Not an escalation.**
   The memory-noted V2 carve-out (Antimatter redeems into unbacked phUSD, so over-payment is real
   dilution rather than opportunity cost) was applied and does not bite here, because there is no
   over-payment — only a change of delivery form.
2. **Self-sandwiching the exit to widen the raw-mint path.** Analysed in the story, bounded by the
   strategy's own `minOut`, and costed at a real AMM round trip. F-05 corrects the *statement* of
   the bound but does not make it extractable: the second cap is protocol-level, not caller-set.
   **Not an escalation.**
3. **The underwater buffer draw (F-04).** The caller is debited the same `gross` they receive, and
   an equivalent `withdraw` already draws at par from the same buffer. No value is extracted beyond
   what the pre-existing, deliberate buffer semantics already permit. **Not an escalation**, filed
   as a Low.

No `story-unsafe` finding is raised for story-025.

## Docs-only commits — claim verification

`afa7b80`, `57eb02d`, `a961e10` and the polish `96d39ed` were checked against the code that landed.

- **`afa7b80` (round-1 docs).** Claim gate, dust rule, `_routeExit` sourcing, `PoolState.Active`,
  migration carve-out, two-pause note, registered-stable coupling and the verbatim auditor note all
  match code. **One claim did not survive round 2 and was never corrected → F-02.**
- **`57eb02d` (round-2 docs).** The gross-vs-net bullet, the advisory-preview bullet and the worked
  example (100 principal → withdraw 100, receive 98, annihilate 98, mint 2) all reproduce exactly
  against `:554-596`. Accurate.
- **`a961e10` (round-3 docs).** The rounding-allowance bullet is accurate about *why* the allowance
  exists and about the `AYieldStrategy` capped identity — including the admission that the preview
  "over-quotes on a fee-charging vault" — but it then asserts the allowance leaves only "a genuinely
  short delivery" reverting, without disclosing that a fee-charging vault's delivery **is** short by
  that measure and bricks the only reward path → **F-06**. The underwater carve-out added this round
  is accurate but incomplete → **F-04**. The `autoAnnihilateAvailable` bullet
  ("A strategy that can guarantee nothing at all … makes `autoAnnihilateAvailable(token)` false")
  is stated unconditionally and is false when the strategy custodies nothing → **F-03**.
- **`96d39ed` (polish).** Corrects `MockERC4626Vault`'s `SafeERC20Lite` rationale. **Verified
  true:** the file inherits OpenZeppelin `ERC4626`, which imports `SafeERC20`, so the replacement
  comment ("saves nothing in bytecode terms") is accurate where the original was not. Test-only.

## Open items the story itself carries (not re-filed here)

- `[low]` the 1 bp proportional leg scales with exit size (story: Auto-Completed Round 3).
- `[low]` `floorWithAllowance` degenerates to `received > 0` when `netFloor <= 2` units + 1 bp;
  untested (story: Auto-Completed Round 3).
- `[low]` `autoAnnihilateAvailable` does not probe the `decimals() > 18` bound (story: Round 1).
- `[nit]` the cross-repo UI follow-up story (`phase-2-staging` submodule bump, wagmi regen, dead
  `wagmi.config.ts:75` artifact path) has still not been created after three rounds.
