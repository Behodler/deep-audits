> **Carryover QA report — audit 21** (cut down from `reports/phoenix-nft-staking-21/submissions/qa-report.md`).
> Retained below: **L-04** only.
>
> ⚠ **THIS IS A NARROWED CARRYOVER, NOT A DISPOSITION-BASED PRUNE — READ THIS BEFORE INFERRING ANYTHING FROM AN ABSENCE.**
> The other run-21 QA entries — **L-01, L-02, L-03, L-05, Q-01, Q-02**, plus that report's own
> carryover, parked-triage, tool-gap, operational, housekeeping and drift-watch sections — are
> **omitted by selection, NOT because they were fixed, acknowledged, wont-fixed or found invalid**.
> Run-25 carried forward only the entries this run's findings **recur on** plus the never-suppressed
> `fix-pending` set (see `carryover/README.md` for the selection rule). Their absence here carries
> **no information about their status**. For the complete set of undealt-with findings, run
> **`/open-issues phoenix-nft-staking`**; the full original report is at
> `reports/phoenix-nft-staking-21/submissions/qa-report.md`.
>
> Labels are the originals. `L-04` stays `L-04`; the gaps are the omissions named above, not renumbering.
> Line numbers were accurate at the originating commit (`c881a42`); re-verify against current HEAD (`5015f1b`).

**Why L-04 is retained:** run-25 `L-02` (`DEDUP-25-05`, reported in `submissions/spec-conformance.md`)
is a **recurrence of this entry**, not a new finding. No new fingerprint was minted; only `lastSeenRun`
was bumped to `phoenix-nft-staking-25`. The docs were rewritten in range and **the claim survived
verbatim**.

- **Fingerprint:** `75305ec0242b81580370518010c737b002a788ded54868271aec77d0c4542fa9` — **unchanged this run**
- **Status:** `open` (untriaged)  ·  **Severity:** Low (unchanged)
- **First seen:** phoenix-nft-staking-21  ·  **Still present as of:** phoenix-nft-staking-25
- **Original report:** [reports/phoenix-nft-staking-21/submissions/qa-report.md](../../../phoenix-nft-staking-21/submissions/qa-report.md)

> ⚠ **DO NOT COLLAPSE** with ledger `F-20-07` `a7dffb34…` (carried at `F-20-07-C1.md` in this same
> directory). **Same claim, two artefacts** — `75305ec0…` is the **code** site, `a7dffb34…` is the
> **doc** site. Different artefacts, different fixes. Collapsing loses whichever site is not chosen
> as canonical.
>
> ⚠ **DO NOT RE-ADD A VALUE CLAIM TO THIS ENTRY.** Its deliberate deferral of the value consequence
> to the nudge lineage is load-bearing anti-double-counting. In run-25 the value consequence is
> priced in **`M-01` (`pns25m1`) only**.
>
> **Run-25 escalation argument** (see `submissions/spec-conformance.md` §3): the falsified premise
> this entry names is now the **quoted justification of KI #15's suppression rule** and of the
> 2026-07-25 owner acceptance. A false premise doing load-bearing work in a rule that removes
> findings from view is a Law-1 recall concern. That argues for **re-weighing this open entry**, not
> for minting a new finding.

*The text below is a verbatim copy of the L-04 entry from the original audit-21 QA report.*

---

### [L-04] The NatSpec honeypot dismissal is asserted as an invariant but enforced nowhere <!-- id: pns21l4 -->

**Location**: [`src/BatchNFTMinterMultiToken.sol:56-61`](../../../lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol) — NatSpec; gate at `:352`, payout at `:452-461`
**Fingerprint**: `75305ec0242b…`

**Description**: The contract's NatSpec at `:56-61` dismisses the honeypot framing by asserting that *"the pot is by construction a fraction of the cost of the `nudgeSize` mints."* Nothing in the code establishes that relation:

- the gate at `:352` is purely numeric (`count >= nudgeSize`);
- the payout at `:452-461` is winner-take-all against a pre-loop `balanceOf` snapshot.

The asserted invariant is therefore an **off-chain funding-discipline property presented as a structural one**. It holds only while whoever funds the pot keeps it small relative to `nudgeSize × price`. At mainnet parameters today it *does* hold (94.95 USDC pot vs ~634 USDS to qualify) — which is precisely why the reopened `H-01` nudge lineage is not presently profitable.

**Impact**: none standalone. This is the **unenforced premise** beneath the value-blind nudge lineage: if the pot ever exceeds the cost of `nudgeSize` mints, farming the nudge becomes net-profitable. The value path itself is carried by the ledger `H-01` reopen (`858e9e80…`) and is deliberately **not** double-counted here.

**Recommendation**: either enforce the claimed relation on-chain (bound the payout by a function of `nudgeSize × price`), or strike the claim from the NatSpec and state plainly that pot sizing is an operational responsibility **with a named owner**. The second is cheap and honest; the first is what would let the `H-01` lineage be closed structurally rather than by configuration.

**Ledger note**: ⚠ **Do not collapse** with spec-conformance `F-21-04` (classified label; input `F-21-06` / ledger `F-20-07` `a7dffb34…`). The **same claim exists at two artifacts** — `src/BatchNFTMinterMultiToken.sol:56-61` (this finding, the code site) and `docs/multi-token-nudge.md:42-46` (the doc site). Collapsing loses whichever site is not chosen as canonical.

---

