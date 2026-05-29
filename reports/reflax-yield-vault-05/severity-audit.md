# Severity Audit — phoenix-vault-05 (severity-auditor)

Independent second-opinion review against the C4 severity bar. Verdicts are formed from a fresh
read of the in-scope contract (`ERC4626MarketYieldStrategy.sol`, skim loop `:462-488`, withdraw
`:302-339`), the PoC-validator's results, and the submission drafts. No bias from the original
classifier intended.

**Bottom line: I CONFIRM all six severity assignments and the M-03→M-02 merge.** No overstatement
found; no understatement found. One borderline call (M-01) is examined in depth below and upheld.

| Label | Claimed | Assessed | Agreement | Confidence |
|---|---|---|---|---|
| M-01 | Medium | Medium | CONFIRM | High |
| M-02 | Medium | Medium | CONFIRM | High |
| M-03 (merged) | merged→M-02 | merged→M-02 | CONFIRM | High |
| L-01 | QA/Low | QA/Low | CONFIRM | High |
| L-02 | QA/Low | QA/Low | CONFIRM | High |
| C-01 | Centralization | Centralization | CONFIRM | High |

---

## M-01 — over-skim via duplicate `clients[]` — CONFIRM Medium (the key call)

This is the finding most at risk of mis-rating in *either* direction. I considered three positions:

**Position A — downgrade to Low/QA (needs a trusted-role mistake, not externally exploitable).**
Rejected. The C4 High bar excludes *reckless admin mistakes*, but it does not blanket-exclude every
issue reachable through a privileged role. The distinction the framework draws is:
- A **reckless/arbitrary** admin action with no realistic non-malicious path (e.g. "owner sets
  slippage to 100%", "owner steals via emergencyWithdraw") → not a valid HM, that's the centralization
  bundle.
- A **latent accounting defect** that converts a *plausible, non-malicious operational input* into
  silent third-party loss → a valid finding; the trusted gate caps **likelihood/severity**, not
  validity.
M-01 is the second kind. The over-skim is not the operator's *intent*; the operator intends to skim
surplus and passes a list that, through a routine off-chain assembly bug (re-run appends, paginated
overlap, same client under two labels), contains a duplicate. The contract has **no guard** that
collapses or rejects the duplicate, and crucially the loss lands on *third parties* (client B is
20k short on a 100k deposit, per the confirmed PoC) — not on the party who made the mistake. A
defect that silently under-backs non-consenting third parties' principal is above QA. Low/QA is
wrong.

**Position B — upgrade to High (confirmed principal loss / loss-of-funds).**
Rejected. The C4 High bar requires assets stolen/lost/compromised "directly or via a valid attack
path without hypotheticals." There is **no external attacker** here and **no attacker profit
primitive** — the over-skimmed value goes to the configured skim *recipient* (a trusted destination),
not to an adversary. The trigger requires a privileged `onlyAuthorizedWithdrawer` call carrying a
malformed array. That is not an attack path; it is an operational fault path. Real loss + privileged
non-malicious trigger + no attacker = the textbook C4 Medium shape ("assets not at *direct* risk …
value leak with stated assumptions"). High would be overstatement.

**Position C — Medium. CONFIRMED.**
The loss is real and proven (dual-confirmed: Halmos exact-2× counterexample for `[A,A]`/`[A,A,B,B]`
with `[A,B]` proven safe; Foundry+Medusa invariant break; deterministic PoC with B 20k short). The
root cause is a concrete code defect (per-occurrence accumulation `:476` ceilinged only by total
held shares `:481` — I verified both lines), not speculation. The privileged trigger and the
no-external-attacker property are the two facts that hold it below High. Medium is exactly right.

**Likelihood/impact cross-check (matrix):** Likelihood = Low-to-Medium (needs a privileged call +
a duplicate; realistic via keeper-script bugs, not exotic). Impact = High (silent third-party
principal under-backing, unbounded by anything except total surplus skimmable in one batch). Low/Med
likelihood × High impact → Medium on the matrix. Consistent.

**One caveat for the report (not a severity change):** the submission's impact framing leans on the
loss being "borne by clients other than the duplicated one." That's correct, but the magnitude is
bounded by *true aggregate surplus across the batch*, not by principal — the `:481` held-shares
ceiling still caps the absolute over-skim. The PoC's 2× is the right worst-case characterization
(duplicate every client → skim 2× surplus). No inflation; just make sure the report does not imply
*arbitrary* principal drain. It reads correctly as written (assertion 4 is the concrete bounded loss).

Verdict: **CONFIRM Medium. Confidence: High.**

---

## M-02 — NAV-anchored minOut execution-price-blind — CONFIRM Medium

Considered downgrade to Low (conditional leak bounded by an admin param). Rejected: this is the
canonical C4 Medium "value leak under stated assumptions with external requirements." The external
requirements (public mempool, profitably-skewable pool, active sandwicher) are real and *stated*,
and the leak is concrete and proven by PoC (~5k per 1M trade = bps×tradeSize, swap clears the NAV
floor yet delivers below fair value). That is more than a spec deviation, so Low understates it.

Considered upgrade to High. Correctly rejected by the classifier and I concur: the severity rationale
in the submission (`:47-53`) is sound — sUSDe NAV is not atomically manipulable (no flash-loan lever
to move `totalAssets()/totalSupply()` within a tx; mint/burn move both in lockstep), so there is no
atomic-theft primitive on the in-scope route. The "no swap deadline" point legitimately *aggravates*
exposure but does not by itself create theft. High would be overstatement on the current route.

The forward-looking note (`:53`) — that the *same code* over an atomically-manipulable ERC4626 share
price escalates to High — is correctly framed as a **deployment constraint**, not a claim about the
present route. That is the right way to flag it without inflating the current severity. Good.

**Matrix:** Likelihood Medium (MEV sandwiching of public Curve swaps with no deadline is realistic),
Impact Medium (bounded per-swap leak = bps×size, recurring across every value-moving path). Medium ×
Medium → Medium. Consistent.

Verdict: **CONFIRM Medium. Confidence: High.**

---

## M-03 → merged into M-02 — CONFIRM the merge (do NOT keep as separate Medium)

The PoC-validator's counterfactual is decisive and I independently agree with its logic:
- CASE A (fair deposits, adverse withdraw leg): slippage distributes **evenly** — every withdrawer
  absorbs ~500 each, no concentration, no singled-out last exiter.
- The dramatic "last withdrawer eats the whole 5,000 pool deficit" result manifests **only** when the
  M-02 deposit-side leak is injected first to under-collateralize the pool from inception.

This proves M-03 has **no standalone loss primitive**: the requested-not-received decrement (`:335-336`)
is a *distribution/amplification* mechanism, not a loss source. Its precondition is another finding's
leak. A finding whose only loss requires another finding to fire first cannot stand as an independent
Medium without double-counting the same dollars. Merging it into M-02 as an "impact amplification"
section is the correct severity call.

**Does the merge inflate M-02?** No. M-02's Medium rating is justified by its *own* loss primitive
(the per-swap bps×size leak), which is already proven independently of M-03. The amplification section
(`M-02-nav-anchored-minout.md:55-71`) explicitly states "no standalone loss primitive … requires
M-02's deposit-side leak," so it adds worst-case *characterization* (the leak concentrates onto one
silent victim rather than spreading) without adding new dollars to the impact. The same 5,000 is
either spread or concentrated — total loss is unchanged. M-02 stays Medium with or without the
amplifier; the amplifier strengthens the *narrative*, not the *severity*. No inflation.

(If anything, the amplifier slightly *raises plausibility of harm* by making the loss silent and
concentrated rather than diffuse, which supports — never undermines — the Medium. Still Medium.)

Verdict: **CONFIRM merge. M-02 severity not inflated. Confidence: High.**

---

## L-01 — slippageBps default-0 + missing cap — CONFIRM QA/Low

Two sub-issues, both correctly Low:
- (a) default-0 → `minOut == ideal` → swaps revert until configured: availability-until-first-config,
  fixed by a single owner call. No asset loss, no third-party harm. Self-evidently Low.
- (b) `setSlippageTolerance` only checks `_bps <= MAX_BPS`, no sane upper cap (Halmos: `bps==MAX_BPS
  ⇒ minOut==0`). The "owner sets 100% slippage" path is an **excluded reckless-admin narrative** and
  is correctly *not* the stated impact. The stated impact is missing input validation. Low.

Not understated: there is no realistic non-malicious path by which (b) produces third-party loss
(unlike M-01, the bad value here *is* the admin's direct choice, not a latent miscount of a benign
input). Correctly distinguished from M-01. **CONFIRM QA/Low.**

---

## L-02 — whole-batch revert on single zero-address entry — CONFIRM QA/Low

`require(client != address(0))` inside the loop (`:470`, verified) reverts the entire batch — an
inconsistency vs the graceful `continue` for `principal==0`/`surplus==0`, plus an unbounded
caller-supplied array. This is a self-inflicted availability/robustness nit by the trusted caller:
no third-party harm, no asset loss, recoverable by resubmitting a clean array. Liveness annoyance,
not a protocol-availability impact in the Medium sense. **CONFIRM QA/Low.** Not understated.

---

## C-01 — Centralization / owner-power bundle — CONFIRM Centralization

`setRoute`, `setSlippageTolerance`, `depositAsOwner`, `withdrawAsOwner`, `emergencyWithdraw`, skim
recipient, two-phase `totalWithdrawal`. Key mitigating facts verified in the classification: the
withdrawer redirects *yield only*, never principal (INV-2 verified), and the timelock is sound and
not bypassable. These are designed/authorized owner powers. Per C4 these belong in the centralization
bundle, not as standalone HM. **CONFIRM Centralization.**

Not understated: I checked specifically whether any owner power reaches *principal* outside the
timelock (which would push toward Medium/High rug-risk). The classification states principal is never
redirected by the withdrawer and emergency/bypass powers are timelock-gated. If that INV-2 claim is
accurate (it is asserted as verified), Centralization is correct. The only residual is the standard
"trust the owner" risk inherent to the design, which is exactly what the centralization bundle is for.

---

## Cross-cutting observations

1. **No High is the correct top severity.** I actively looked for a path to High on M-01 and M-02 and
   found none that survives the "no hypotheticals / valid attack path" test. M-01 lacks an attacker;
   M-02 lacks an atomic manipulation primitive on the in-scope route. The distribution (0 High, 2 net
   Medium after merge, 2 Low, 1 Centralization) is honest.

2. **The M-03 merge is the single most important integrity decision in this set** and it was made
   correctly — keeping it separate would have been the one real overstatement risk (double-counting
   one leak as two Mediums). Caught and resolved.

3. **No finding is understated.** L-01/L-02/C-01 each lack a third-party-loss or protocol-availability
   primitive that would justify Medium. The M-01 vs L-01(b) contrast is the right line: latent
   miscount of a benign input (M-01, Medium) vs admin's own bad parameter choice (L-01b, QA).

Overall confidence: **High** across the board.
