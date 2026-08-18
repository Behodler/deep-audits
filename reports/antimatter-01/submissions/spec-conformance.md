# Spec-Conformance Report (Law 2) — antimatter-01

**Project:** antimatter · **Commit:** `0bb82d8` (`0bb82d867dba43bc514a508800826f90436c2ee3`) · **Branch:** `master`
**Repo:** https://github.com/Behodler/antimatter · **Run:** antimatter-01 (cold scan)

Law-2 findings are labelled `F-xx` and reported here at honest severity. They are **never** folded
into the QA/gas bundle — a deviation from stated behaviour is not noise.

| Label | issueId | Fingerprint | Severity | Subject |
|---|---|---|---|---|
| F-01 | `am1f1` | `3aac91383dcb6060` | Low | Measured-balance discipline applied only nominally to the phUSD leg |
| F-02 | `am1f2` | `78612be9264d2b49` | Low | The nominated no-burn trip-wire is a four-name denylist, not an invariant |
| F-03 | `am1f3` | `9d06644ddad24e5a` | Low | Header NatSpec justifies the unbacked mint with a redemption symmetry that does not exist |
| F-04 | — (see M-02) | `64807f2b1456d622` | Medium | **Cross-reference only.** M-02 dual-channelled; `specStatus: FAITHFUL-BUT-UNSAFE` |

---

## 1. Story resolution status — UNRESOLVABLE-PENDING-MAPPING

> **Read this before reading anything below.** Law-2 story faithfulness for this project is
> **DEFERRED, not passed.** There is no written story for the antimatter feature anywhere in the
> product-owner tree, so conformance to a story could not be graded at all. Nothing in this report
> should be read as "the feature matches its story"; no story was found to match it against.

The lens was **run**, not skipped. Four independent negative checks were executed at `0bb82d8`, each
capable on its own of locating the story had one existed:

**(a) Registry mapping — MISS.** `~/code/product-owner/registered-project-list.md` contains no line
matching `antimatter` (case-insensitive). The project is unmapped, so no `storyDir` can be resolved
by the authoritative route. `registered-projects.json` correspondingly carries `storyDir: null`.

**(b) Directory glob of the stories tree — MISS.** `~/code/product-owner/stories/` holds **29**
project directories; none is antimatter, and none is a plausible alias for it:

```
ROP, asset-mapper-RM, behodler3-tokenlaunch-RM, church, defi-llama-adapters,
defi-llama-pegged-assets, deployment-staging-RM, flax-token-RM, iChaplet, interview,
landing-page, liturgy-newsletter, managed-liquidity-RM, mvc, nft-staking, pauser-RM,
phStaging2, phlimbo, phlimbo-ui, phoenix, phusd-minter, reflax, reflax-contracts,
reflax-ui, stable-staker, tidlywiki, vault-RM, yield-accumulator, yield-claim-nft, ys-router
```

**(c) Content grep over the ENTIRE stories tree — ZERO HITS.**
`grep -ril "antimatter\|annihilat"` across every project directory, every state folder
(`complete` / `incomplete` / `review` / `archive`) and every sprint folder matched **no files**.
This check exists precisely to defeat a misnamed `storyDir`: if the story lived under an unexpected
directory name, its content would still mention antimatter or annihilation. It does not. The story
does not exist under any name.

**(d) Commit-tag check — NONE.** None of the repository's **6** commits carries a `[story-NNN]`
tag:

| Commit | Subject |
|---|---|
| `0bb82d8` | `annihilate` |
| `a0eaee1` | `annihilate` |
| `b930f46` | `don't change submodules hook` |
| `95cadf6` | `set up minting` |
| `bc31862` | `set up minting` |
| `a94fd72` | `Initialize antimatter Foundry project with Antimatter ERC20` |

Only `a94fd72` has a commit body (scaffold notes); no commit points at a story.

**Conclusion.** This is a **registry gap** — antimatter is not registered with product-owner — not
an inaccessible or unreadable document. The feature has **no written story anywhere in the
product-owner tree**, so faithfulness to a story cannot be graded. Law-2 story conformance is
**DEFERRED**; it is explicitly **NOT closed and NOT passed**.

**What F-01…F-04 were graded against instead.** In the absence of a story, the only authoritative
intent artefacts that exist at `0bb82d8` are:

- `lib/antimatter/CLAUDE.md` § *"Antimatter must never expose a burn"*
- `lib/antimatter/CLAUDE.md` § *"Annihilation settles whole or not at all"*
- `src/Antimatter.sol:13-20` — the contract-header NatSpec

Every finding below is a deviation from one of those three, not from a story.

**Re-grade trigger.** Re-run the Law-2 lens when **either** of the following happens:

1. A human adds an `antimatter` mapping to `~/code/product-owner/registered-project-list.md`
   (and the resolved `storyDir` is cached into `registered-projects.json`); **or**
2. A story document covering antimatter / annihilation is written anywhere under
   `~/code/product-owner/stories/`.

Until then the intent behind the unbacked-mint design (F-04 / M-02) has **no written authority
beyond an in-source comment that is itself inaccurate** (F-03) — which is why M-02's
"it is intended" defence carries no weight.

---

## 2. Findings

### F-01 — `am1f1` · `3aac91383dcb6060` · Low
**The spec's measured-balance discipline is applied in full to the stablecoin leg but only nominally to the phUSD leg**

`src/Antimatter.sol` · `annihilateFrom` · L230–L237 (guard at **L233**)
[src/Antimatter.sol#L230-L237](https://github.com/Behodler/antimatter/blob/master/src/Antimatter.sol#L230-L237)

**Spec text violated** — `lib/antimatter/CLAUDE.md` § *"Annihilation settles whole or not at all"*:

> `annihilateFrom` must never come to rest in a partial state: antimatter burned without the
> stablecoin deposited, phUSD minted for one half only, or the stablecoin left sitting on this
> contract. **Burn before the external calls, verify by measured balances rather than assumption,
> and let anything unexpected revert.**

**Actual behaviour.** The stablecoin leg honours the discipline in full — L230 measures and fails
closed on a strict inequality:

```solidity
230:        if (IERC20(stable).balanceOf(address(this)) != stableBefore) revert StableNotDeposited();
231:
232:        uint256 mintedForStable = _phUSD.balanceOf(address(this)) - phUSDBefore;
233:        if (mintedForStable == 0) revert PhUSDNotReceived();
```

The phUSD leg does not. L233 rejects **only the exact value zero**. Measurement is used for
residue detection (L219 / L230, strict `!=`) but never for *expectation* checking — and it is the
phUSD leg where the burn (L215) has already become irreversible. Any non-zero quantity is accepted
on trust, including one wildly below what the stable deposit should have produced.
*"Anything unexpected"* does not revert; only *"nothing at all"* does.

`annihilateFrom` exposes **no minimum-output / expected-phUSD / slippage parameter** at all, so a
caller has no way to bound the outcome of an already-irreversible burn. If `exchangeRate` is low, or
is changed by the owner between transaction submission and execution, the holder's antimatter is
burned at full quantity while the stable half returns almost no phUSD — and the transaction
**succeeds**.

**Why Low, and why it is here rather than in QA.** Honest Low on the security limb: no attacker
gain, the harm is caller-borne and bounded by the rate divergence, and it does not breach the
whole-or-nothing invariant as enumerated (no rest state has antimatter burned with stable
undeposited, and nothing is stranded). Rate-setting itself is Law-3 owner territory. It is routed
here rather than into the QA bundle because it is a **partial implementation of a written
CLAUDE.md discipline**, not an interaction defect — Law-2 deviations are never buried in QA noise.

**Recommendation.** Add a `minOut` / expected-phUSD parameter to `annihilateFrom`, or assert
`mintedForStable` against `minter.calculateMintAmount(stable, stableAmount)`. Mitigation is shared
with L-01 (see `qa-report.md`) and with **M-06**. Note that M-06 is deliberately **PARKED**
(`submittable: false`), and the reason is *not* the one originally recorded: antimatter's pin of
`phUSD-stable-minter` (`d6ed1156`) **is** that repo's remote `master` tip and is therefore current.
The unadjudicated variable is one layer deeper — `phUSD-stable-minter/lib/vault` is pinned at
`043ff2c` against vault master `0110ce4` (11 commits, incl. stories 043/044/048/049 which introduced
`deposit()` returning `creditedPrincipal`) — so **which yield-strategy/vault version is actually
deployed** cannot be established at commit `0bb82d8`. Adjudicate it by reading the **deployed**
strategy, never the minter pin. No `submissions/M-06.md` exists or will be written, by design — see
the run `README.md`. Read M-06 at its finding record instead:
`reports/antimatter-01/findings/medium/M-06-post-conditions-confirm-the-stablecoin-left-never-that.json`.

---

### F-02 — `am1f2` · `78612be9264d2b49` · Low
**The invariant trip-wire CLAUDE.md nominates for "never expose a burn" is a four-name denylist, not an invariant check**

`test/Annihilation.t.sol` · `test_noPublicBurnEntryPoints` · L341–L355 (probe list at **L344–L345**)
[test/Annihilation.t.sol#L341-L355](https://github.com/Behodler/antimatter/blob/master/test/Annihilation.t.sol#L341-L355)

**Spec text violated** — `lib/antimatter/CLAUDE.md` § *"Antimatter must never expose a burn"*:

> No `burn`, no `burnFrom`, no `ERC20Burnable`, no owner-callable "clawback", no `transfer` to
> `address(0)` path, and **no new entry point that reaches `_burn` except `annihilateFrom`.**
>
> `test_noPublicBurnEntryPoints` in `test/Annihilation.t.sol` **is a trip-wire for this rule.** It
> is not the rule — do not weaken or delete it to accommodate a new burn path.

**Actual behaviour.** The nominated trip-wire probes a hardcoded four-name guess list:

```solidity
344:        string[4] memory signatures =
345:            ["burn(uint256)", "burn(address,uint256)", "burnFrom(address,uint256)", "annihilate(address,uint256)"];
```

Three ways this fails to enforce what the rule states:

1. **It is a denylist, not a property.** The rule prohibits **ANY** new entry point reaching
   `_burn`. A burn named `redeem`, `destroy`, or `clawback` — or an `annihilate` **overload of a
   different arity** — is simply not in the list, and the test passes green. The very shape of
   defect the rule exists to catch is the shape the test cannot see.
2. **Two of the rule's named cases are never probed at all.** The rule also names *"no owner-callable
   clawback"* and *"no `transfer` to `address(0)` path"*. Neither appears in the probe list.
   Transfer-to-zero happens to be closed — but by OpenZeppelin v5.6.1's `ERC20._update`
   (`ERC20InvalidReceiver`), i.e. by the base class, not by anything this repo asserts. If the base
   class changed, nothing here would notice.
3. **The one-argument probe is mis-encoded.** All four signatures are dispatched through the same
   two-argument call (`abi.encodeWithSignature(signatures[i], user, 1 ether)`), so the
   `burn(uint256)` probe passes trailing calldata the decoder ignores: it would decode
   `amount = uint256(uint160(user)) = 2827` wei, not `1 ether`. It would still trip a naive
   `burn(uint256)`, but only because the address literal happens to be a small non-zero number. The
   probe is not testing what it reads as testing.

**The trip-wire is not load-bearing.** This is already demonstrated, not hypothetical: H-01's
invariant violation — a burn effected from the grantor's ledger via an ERC20 allowance — coexists
with this test passing green.

**Substance vs. guard.** The invariant itself **HOLDS at `0bb82d8`**: `src/Antimatter.sol` contains
exactly one `_burn` (L215, inside `annihilateFrom`) and one `_mint` (L180, `onlyApprovedMinters`);
no `ERC20Burnable` inheritance, no `burn`/`burnFrom`/clawback function. Tier-3 `invariant_08` proves
it dynamically as an exact equality over 76,800 calls per campaign on both Foundry and Medusa, with
~3,000 annihilations reverting *after* reaching `_burn` and not one unaccounted unit. The defect is
in the **guard**, not the current code — but CLAUDE.md designates this test as the enforcement
mechanism for a load-bearing invariant and instructs future authors not to weaken it, so the false
assurance is the whole harm.

**Recommendation.** Replace the name-denylist with a real property assertion — `totalSupply` is
non-decreasing across every non-`annihilateFrom` external call, exercised with fuzzed calldata — or
a source assertion (exactly one `_burn` occurrence, inside `annihilateFrom`). Add explicit probes
for the clawback and transfer-to-zero cases the rule names, and fix the one-argument encoding.
*(Note: the audit's Tier-3 harness under `workspace/antimatter/test/audit/invariant/` is a usable
template, but it is **audit-authored** and must never be cited as project coverage.)*

---

### F-03 — `am1f3` · `9d06644ddad24e5a` · Low
**The contract-header NatSpec justifies the unbacked mint with a redemption symmetry that does not exist, and states a 2x output the code does not guarantee**

`src/Antimatter.sol` · contract-header NatSpec · L13–L20 (claim at **L16–L18**)
[src/Antimatter.sol#L13-L20](https://github.com/Behodler/antimatter/blob/master/src/Antimatter.sol#L13-L20)

**Spec text (the claim itself):**

```solidity
16: /// @dev Antimatter is handed out as a staking reward across the protocol. Held on its own it is
17: ///      inert; brought together with an equal quantity of a supported stablecoin it annihilates,
18: ///      and the pair is emitted as phUSD — twice the quantity, since both halves are redeemed.
```

**Actual behaviour — both clauses are false.**

**(a) "both halves are redeemed" — phUSD has NO redemption path anywhere in the protocol.**
Verified across every repo: nothing anywhere redeems phUSD for an underlying asset. The stable leg's
phUSD is minted by `PhusdStableMinter.mint` against a real stablecoin deposit forwarded to a yield
strategy. The antimatter leg's phUSD is minted at **`src/Antimatter.sol:236`**:

```solidity
235:        // The antimatter half, minted straight to the recipient.
236:        _phUSD.mint(recipient, amount);
```

— with **no asset entering the protocol for it**. Nothing is "redeemed" on that half; antimatter is
itself an unbacked staking reward minted freely at L179–L180. The word *"redeemed"* imports a
backing that does not exist, and it is doing load-bearing rhetorical work: it is the entire stated
justification for the unbacked mint.

**(b) "twice the quantity" — contradicted by the repo's own passing test.** The total is
`amount + mintedForStable` (L239), where `mintedForStable` honours the stable minter's
`exchangeRate`. The project's own green test `test_annihilateHonoursMinterExchangeRate`
(`test/Annihilation.t.sol:108-117`) asserts **195**, not 200:

```solidity
108:    function test_annihilateHonoursMinterExchangeRate() public {
109:        minter.updateExchangeRate(address(usdc), 95e16); // 0.95 phUSD per USDC
...
117:        assertEq(phUSD.balanceOf(user), 195 ether, "100 AM + 95 from the stable");
```

The header's headline arithmetic is refuted by the repository's own test suite. The real figure is
`amount * (1 + exchangeRate/1e18)` (see M-04).

**Kept deliberately separate from M-02 — do not collapse.** Different root cause (a documentation
defect), different remediation (correct the comment, not bound the emission), different affected
reader (integrators), and decisively: collapsing it would let the doc defect vanish the moment the
economic finding is triaged as accepted-by-design. That separation is the point. Filing F-03 does
**not** dampen the economic impact of the unbacked mint, which is M-02's to size.

**Recommendation.** Correct L16–L18: only the stablecoin half is a redemption; the antimatter half
is an uncollateralised mint. State the `exchangeRate` dependence of the total rather than a flat 2x.

---

### F-04 — cross-reference to **M-02**, not a separate finding

> **F-04 is NOT a separate ledger entry.** There is no `am1f4`. F-04 is the *faithfulness
> cross-reference* for **M-02** (`64807f2b1456d622`, Medium), which is dual-channelled: its primary
> label and its report are M-02, and it appears here only so that the spec-conformance record shows
> the behaviour is **intended, not accidental**. Triage it as M-02; there is nothing separate to
> triage here.

**M-02 — Half of every annihilation's phUSD is minted against no incoming value, and the resulting
liability is unbounded, unscheduled and unrecorded.**
`src/Antimatter.sol` · `annihilateFrom` / `mint` · L179–L239 (unbacked mint at L236, uncapped mint at L179)
Full report: `submissions/M-02.md`.

**specStatus: FAITHFUL-BUT-UNSAFE.**

The declared intent is explicit — CLAUDE.md: *"antimatter's entire value to a holder is that it
annihilates into phUSD worth twice its quantity"*; `src/Antimatter.sol:188-189`: *"this contract
mints the phUSD for the antimatter half"*. The code implements that intent **precisely**: L236 mints
exactly `amount` phUSD to the recipient for the antimatter half. On the Law-2 axis alone, the
implementation is faithful.

**Law 1 overrides Law 2.** A faithful implementation of an unsafe design is still reportable. The
intent *itself* is the hazard: antimatter is minted with no cap and no backing (L179), and every
outstanding unit is a standing, permanently exercisable claim on 1e18 freshly-minted phUSD that no
asset backs. phUSD's collateral ratio is diluted by the entire outstanding antimatter supply, and
the dilution is realisable by any holder at will. Tier-3 `invariant_04` quantifies it as an exact
equality over 76,800 calls: `phUSD.totalSupply()` minus custodied stablecoin (18dp-normalised)
equals cumulative antimatter burned — the pass is not an all-clear, it is the *measurement* that the
uncollateralised leg is exactly 1:1 with antimatter burned.

**"It is intended" is not a defence here, and specifically not on this project.** The design's only
written justification is the contract-header NatSpec — and that justification is **false in both of
its clauses** (F-03: phUSD has no redemption path, and the 2x is refuted by the repo's own test). A
reader calibrating emission policy against L16–L18 is calibrating against something inaccurate, and
there is no story to appeal to instead (§1). The intent is therefore recorded, not blessed.

**Re-weigh trigger (carried from M-02).** Re-weigh as **High** if antimatter emission is ever wired
to a permissionless or automated/high-volume minter via `setApprovedMinter` (L151), or if a phUSD
redemption path is ever built (the exposure converts from peg pressure into on-chain insolvency).

---

## 3. Standing rule — documentation carries no suppression authority

Two rules were applied throughout this report and are restated here because they determine how F-01,
F-02 and F-03 were weighed:

**In-source NatSpec and `CLAUDE.md` carry NO suppression authority.** Neither a contract comment nor
a repo-level `CLAUDE.md` can retire a finding, downgrade one, or serve as evidence that a behaviour
is safe. A document declaring a behaviour intended establishes only that it is *intended*; whether it
is *safe* is decided against Law 1, which outranks it. This is why M-02 is filed at full Medium
despite being demonstrably deliberate, and why the *presence* of an intent statement at
`src/Antimatter.sol:188-189` earns it nothing.

**A falsely-exhaustive document RAISES severity rather than lowering it.** A doc that presents itself
as complete or authoritative and is wrong is worse than no doc, because readers stop looking. Both
apply directly here:

- **F-03** — the header NatSpec is the **only** intent artefact this project has (no story, no
  `storyDir`, no story tag on any commit — §1). An integrator reading L13–L20 would conclude both
  phUSD legs are asset-backed. Being the sole artefact makes its inaccuracy weigh more, not less.
- **F-02** — CLAUDE.md nominates `test_noPublicBurnEntryPoints` as *the* trip-wire for a load-bearing
  invariant and instructs future authors not to weaken it. A green test that cannot detect what its
  own rule prohibits is precisely the false assurance that lets a real defect through — as H-01 shows
  it already has.

**Sanitizer note.** No known-issues document exists for this project at `0bb82d8`
(`knownIssuesFile`/`knownIssuesSource` both null, `knownIssues` empty — verified at HEAD), so
known-issue suppression has no authority over anything in this report. The ledger was empty before
this run, so there is no prior entry any of these findings reconcile against; all four are `origin:
new`, `firstSeenRun: antimatter-01`, `branch: master`.
