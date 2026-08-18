# antimatter — run-01 submissions index

| Field | Value |
|---|---|
| Project | `antimatter` |
| Run | `antimatter-01` |
| Commit | `0bb82d867dba43bc514a508800826f90436c2ee3` |
| Branch | `master` (default branch; no branch audit) |
| Repo | https://github.com/Behodler/antimatter |
| Ledger | `reports/ledgers/antimatter.json` |

## Submitted findings

| Label | ID | Fingerprint | Severity | Title | File |
|---|---|---|---|---|---|
| H-01 | `am1h1` | `033432b0e650af67` | High | An ERC20 allowance over antimatter is a dual-asset authority: a third party spends the grantor's stablecoin and keeps the ~2x phUSD | [H-01.md](H-01.md) |
| M-01 | `am1m1` | `a1c81428a47ad295` | Medium | Understated registered `decimals` fails OPEN, arming a permissionless free mint | [M-01.md](M-01.md) |
| M-02 | `am1m2` | `64807f2b1456d622` | Medium | The antimatter leg mints phUSD against zero collateral; unbounded, unaccounted dilution | [M-02.md](M-02.md) |
| M-03 | `am1m3` | `df5c16e2238a3c1c` | Medium | The daily phUSD cap governs only the stable leg: a cap of X permits 2X | [M-03.md](M-03.md) |
| M-04 | `am1m4` | `abe4305ac8f0c44f` | Medium | `exchangeRate` re-prices only the stable leg: hard 1x issuance floor and near-zero-rate brick | [M-04.md](M-04.md) |
| M-05 | `am1m5` | `6a6a6bcba7b0dff1` | Medium | Shared daily budget: the annihilator extracts 2x per unit and DoSes ordinary minters | [M-05.md](M-05.md) |

Low, Centralization and QA findings (`L-01`–`L-03`, `C-01`, `C-02`, `Q-01`–`Q-04`) are bundled in the QA report. Faithfulness findings (`F-01`–`F-03`, plus `F-04` = M-02 dual-channelled) are routed to the spec-conformance report and are never bundled into QA.

## M-06 — classified but NOT submitted (PARKED)

**`M-06` / `am1m6` / fingerprint `ac6de2faade9adcd` — "Post-conditions confirm the stablecoin LEFT, never that the yield strategy CREDITED it".**

`submittable: false`, `status: PARKED-MANUAL-REVIEW`, `verificationStatus: UNVERIFIED`. **No submission file exists for M-06, deliberately.**

**Why it is not submitted.** *(Park rationale corrected 2026-08-18 in the review pass — the original wording, which blamed a stale `phUSD-stable-minter` pin, was factually wrong. The finding stays parked, but on the corrected ground below.)*

The **minter pin is current, not stale**: antimatter pins `lib/phUSD-stable-minter` at `d6ed1156`, and that commit **is** the minter's remote `master` tip. The stale layer is one level deeper — `lib/phUSD-stable-minter/lib/vault` is pinned at `043ff2c` while vault's remote `master` is `0110ce4`, **11 commits ahead**, and those commits include stories 043/044/048/049, which are exactly the ones that introduced `deposit()` returning `creditedPrincipal`.

So what cannot be adjudicated at commit `0bb82d8` is **which yield-strategy / vault version is actually deployed** — this finding depends entirely on the deployed strategy's `deposit()` return behaviour, and nothing in this repo establishes it. Until that is resolved the finding must not be submitted, PoC'd as fact, or cited as a known shortfall.

**The Medium label is a placeholder, not a verdict.** It was carried forward as the highest input severity (`ECON-004` medium over `CODE-006` low, per the conflicting-severity rule) purely for triage ordering. No downstream stage may read it as a verification result.

**Why it is kept rather than dropped.** Law 1 — recall beats report-tidiness. It is parked in a visible channel (`reports/antimatter-01/manual-review.json`, and in the ledger as `am1m6`) with its reason attached, not discarded into a log nobody reads.

**Manual-review action required to adjudicate it — read the DEPLOYED strategy, not the nested pin.** Resolve from chain the **deployed** yield strategy for the stablecoins actually registered, and measure `creditedPrincipal` versus `amount` there.

> ⚠ **Do not re-check the `phUSD-stable-minter` pin.** It is already current (`d6ed1156` == remote `master` tip) and will still be current on a future run; a run that re-checks *it*, finds it current, and concludes the park is resolved would be answering the wrong question. The open question is the **deployed strategy / vault version**.

If the deployed strategy's `deposit()` returns nothing or credits the full principal (`043ff2c`-era behaviour), close as **not-applicable**. If it credits less than the principal transferred for any registered stablecoin, size the stable leg from the returned value (minter-side fix) and/or assert `mintedForStable` against `minter.calculateMintAmount(stable, stableAmount)` (first-party fix).

**Nothing actionable is gated behind the park.** M-06's actionable half — replacing the unbounded `mintedForStable == 0` check at `lib/antimatter/src/Antimatter.sol:233` with a two-sided assertion against `minter.calculateMintAmount(stable, stableAmount)` — is independently carried by **L-01** and **F-01**, which are not parked, and is also recommended in M-04.

## Open severity disputes — human triage required

**Nothing in this section has been applied.** Severity re-banding is a human triage decision, and the two
review agents (`severity-auditor`, `validity-checker`) disagree with `severity-classifier` on the five items
below. Every label, ledger `status` and fingerprint in this run is therefore **unchanged**: all 19 ledger
entries remain `open` at the severity the classifier assigned. The disputes are recorded here — visibly, per
Law 1 — so a human decides them rather than a pipeline stage settling them silently.

Reasoning in full: `reports/antimatter-01/severity-audit.md` and `reports/antimatter-01/validity-check.md`.

**Note on the commands below.** `/ledger` has **no severity re-band verb**. Accepting a re-band means a human
edits the `severity` field on *both* the finding record (`reports/antimatter-01/findings/<band>/<label>-*.json`)
and the matching ledger entry in `reports/ledgers/antimatter.json` — leaving `status`, `issueId`,
`fingerprint` and `fingerprintBasis` untouched — and moving the write-up between `submissions/<label>.md`
and the QA bundle. The `/ledger` commands given are the ones that *do* apply.

| Item | Proposed by | Proposal | Disagreement |
|---|---|---|---|
| **M-04** `am1m4` `abe4305ac8f0c44f` | severity-auditor | **LOWER** Medium → Low | classifier disagreed; kept at Medium |
| **M-05** `am1m5` `6a6a6bcba7b0dff1` | severity-auditor | **LOWER** Medium → Low | classifier disagreed; kept at Medium |
| **F-01** `am1f1` `3aac91383dcb6060` | severity-auditor | **RAISE** Low → Medium, with **L-01** merged into it | classifier kept F-01 at Low and L-01 separate |
| **Q-04** `am1q4` `507e375d3ef4abfe` | validity-checker | **RELOCATE** out of the numbered QA findings into a tooling-inventory appendix | classifier kept it as a numbered QA finding |
| **M-06** `am1m6` `ac6de2faade9adcd` | validity-checker | **INVALID as filed** (out-of-scope root cause) | classifier parked it at Medium |

### M-04 → proposed LOWER to Low (severity-auditor)

**Reasoning.** The finding decomposes without residue into things already filed: the near-zero-rate brick is
**L-03**, the "unbacked 1x floor" is **M-02**, and the silent re-pricing of `maxMintPerDay` is **M-03**. What is
left once those are removed carries no asset risk and is owner-triggered, which is Low-shaped, not Medium-shaped.
The classifier disagreed, holding that the two *surprising* halves (a safety lever that cannot reach parity, and
one control silently re-pricing another) are a footgun in their own right at Medium.

**If accepted:** re-band `severity` to `low` on the finding record and ledger entry, move the write-up from
`submissions/M-04.md` into `qa-report.md`. No `/ledger` status change — it stays `open`.

### M-05 → proposed LOWER to Low (severity-auditor)

**Reasoning.** First-come-first-served exhaustion of a shared rate limit **is the rate limit working**, not a
DoS defect; the finding also carries no PoC and only `medium` confidence, and the DoS leg needs live antimatter
emission that does not exist yet. The genuinely novel content — that the annihilation path draws 2x per unit of
budget consumed — is **already M-03**, so what is unique to M-05 is Low-grade. The classifier disagreed, treating
the asymmetric consumption of a *shared* budget as a distinct availability impact at Medium.

**If accepted:** re-band `severity` to `low` on the finding record and ledger entry, move the write-up from
`submissions/M-05.md` into `qa-report.md`. No `/ledger` status change — it stays `open`.

### F-01 → proposed RAISE to Medium, absorbing L-01 (severity-auditor)

**Reasoning.** F-01 is **under-called**, and the softener that justified Low — "the harm is bounded by the rate
divergence" — is **false**. `updateExchangeRate` is a bare `onlyOwner` write with **no floor and no timelock**, so
the divergence is unbounded by construction; and `Antimatter.sol:233` accepts **any non-zero** output on a burn
that is **already irreversible**, so a routine owner re-price between submission and execution takes real user
capital with no minimum-output protection. That is user-fund impact, i.e. Medium. **L-01** is the same line, the
same root cause and the same one-line fix, and should merge into it rather than stand as a separate Low. The
classifier kept F-01 at Low on the security limb (no attacker gain, caller-borne harm) and kept L-01 separate.

**If accepted:** re-band `severity` to `medium` on the F-01 finding record and ledger entry, promote it out of
`spec-conformance.md` into its own `submissions/<label>.md` (keeping the F-01 faithfulness cross-reference per
the Law-2 dual-channel rule), and fold L-01's body into it. The merged-away entry is **retired, never deleted**:

```
/ledger antimatter false-positive am1l1 "merged into F-01 (am1f1) per severity-audit; same line :233, same root cause, same fix — not a separate defect"
```

*(If the human prefers to keep L-01 addressable as its own open entry rather than retiring it, skip that command
and simply cross-reference the two. Do not run it unless the merge is accepted.)*

### Q-04 → proposed relocation to an appendix (validity-checker)

**Reasoning.** Q-04 is raw static-analysis output over **mock and harness files** (`SA-011`/`SA-012`/`SA-013`) with
no exploit path and no deployed artefact — "common findings from automated tools without a demonstrated H/M path".
It is legitimately *in scope* (test files are first-party) and legitimately worth **accounting for**, but a numbered
`Q-` slot asserts a claim about the protocol, and this one does not. It belongs in Appendix A beside the 4naly3er
output as a "tool results accounted for" inventory. The classifier kept it as a numbered QA finding.

**If accepted:** move the Q-04 block out of the numbered QA findings in `qa-report.md` into the tool appendix,
drop the `Q-` label, and keep the content and triage note intact (deletion must stay visible). The ledger entry
`am1q4` stays `open` — relocation is a presentation change, not a disposal.

### M-06 → validity-checker rules it INVALID as filed

**Reasoning.** The claimed defect — `PhusdStableMinter` making a bare statement call to `IYieldStrategy.deposit`
and discarding the return — **originates in nested `lib/**` code that is out of scope** for an antimatter audit.
As an antimatter finding about the strategy's crediting behaviour it is invalid. Its **first-party residual** (that
`:233` accepts any non-zero `mintedForStable` instead of asserting against `calculateMintAmount`) is already
carried, unparked, by **L-01** and **F-01** — so ruling M-06 invalid costs the report nothing actionable. The
classifier parked it at a provisional Medium instead.

Note this is **independent of** the park-rationale correction applied above: the corrected rationale (the minter
pin is current; the *deployed strategy/vault version* is what is unknown) is a factual fix that was applied, while
the INVALID ruling is a scope judgement that is **not** applied and awaits a human.

**If accepted:**

```
/ledger antimatter false-positive am1m6 "OOS root cause: defect originates in nested lib/phUSD-stable-minter → lib/vault, not in src/Antimatter.sol; first-party residual already carried by L-01/F-01 (validity-check.md)"
```

*(The alternative — leave it parked and resolve it by reading the **deployed** strategy per the corrected
re-check instruction above — is equally defensible and requires no command.)*

## Evidence provenance (applies to every report in this directory)

- **All PoCs are AUDIT-AUTHORED** and live under `workspace/antimatter/test/audit/**` in the writable audit workspace. They are **not** part of the project's test suite and do **not** exist in `lib/antimatter` at commit `0bb82d8` — verified: that commit contains only `test/Annihilation.t.sol`, `test/Antimatter.t.sol` and three mocks under `test/mocks/`, and zero `test/audit/**` paths. No report cites them as project test coverage.
- **Invariant PASSES are the absence of counterexamples within the stated run depth, not proofs.** Only the four invariant failures are proofs of defect. Where a passing invariant is cited (M-02, `invariant_04`), it is used strictly as a *quantification*, never as reassurance, and no severity rests on it.
- **Halmos `TIMEOUT`/`ERROR` results carry zero safety weight.** Halmos `PROVED` results are cited only as scoping evidence (isolating a hazard as economic rather than a settlement defect), never as all-clears.
- No known-issues document exists for this project at `0bb82d8`, so **zero findings were suppressed on known-issue grounds** at any stage.

## Law 2 status

**UNRESOLVABLE-PENDING-MAPPING.** No story exists for `antimatter` anywhere in `~/code/product-owner/stories/` — verified both by filename glob and by content grep — and `storyDir` is `null` in `registered-projects.json` because antimatter has no entry in `~/code/product-owner/registered-project-list.md`. No `[story-NNN]` tag appears on any of the six commits. Faithfulness was therefore **not graded**, and no report claims a story was checked. A human must add the mapping line before Law-2 resolution is possible.
