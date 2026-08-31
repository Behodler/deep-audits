# Audit-tooling rigor revisions — 2026-07-09

Decision log for the rigor-hardening pass on the audit pipeline. Each entry records
a fork in the road, the choice made, and the reasoning, so the choices can be
retroactively accepted or reverted. Nothing here touches `lib/` (read-only) or any
finding/ledger data — only the tooling specs, pattern DB, and the SessionStart hook.

Origin: review of whether the security investigation is rigorous. Confirmed strengths
(three-law hierarchy operationalized, profile-first tiering with verified-only trust,
fingerprinted ledger, visible parking channels) are **left untouched**. This pass
closes the recall-risk gaps.

---

## Decisions

### D1 — Missing vuln classes added as explicit scanner checklists (not just DB entries)
**Fork:** codify the missing DeFi classes in the pattern DB only, or also as first-class
checklist items in the LLM scanners?
**Choice:** both. The pattern DB is grep-signature matching (weak for these classes);
the real discovery muscle is the Tier-2 scanners, so the checklists go there too.
Classes added: ERC721/1155 callback reentrancy (`onERC721Received`/`_safeMint`/
`safeTransferFrom`), read-only reentrancy, cross-function reentrancy (code-scanner);
rounding-direction / round-in-protocol-favor (econ-scanner); weak-PRNG and ERC721
receive-hook surface as local flags (contract-profiler).
**Reasoning:** these are directly relevant to an NFT-staking/minting suite and were the
biggest recall gap. Weak-PRNG + ERC721-callback reentrancy are the classic NFT-mint bugs.

### D2 — Deduplicator silent-drop hole closed
**Fork:** leave dedup's "Phase 4: remove below quality threshold" as-is, or force it to
route removals to the visible parked channel like the sanitizer does?
**Choice:** route. Any confidence-based or quality-threshold removal now writes to
`manual-review.json` with a reason instead of vanishing.
**Reasoning:** Law 1 — recall beats tidiness; a pre-triage silent drop is exactly the
hole the parking channels exist to prevent. Cull at triage (`/ledger`), not in dedup.

### D3 — poc-validator standalone-vs-workspace contradiction reconciled
**Fork:** which PoC style is authoritative — the standalone (forge-std-only, inlined
mocks) that poc-validator mandated, or the workspace-first (imports real project
contracts) that CLAUDE.md, poc-generator, and ~100% of real PoCs use?
**Choice:** workspace-first is authoritative; standalone is a C4-export fallback only.
**Reasoning:** a PoC against inlined mocks proves a bug in the mock, not in the code.
The standalone mandate was a dead letter (every real PoC would fail it) and, if ever
enforced literally, would *degrade* rigor. Standalone still matters at C4-submission
time (evaluator pastes into a fresh project), so it is kept as an export/repackaging
step, not the primary validation gate.

### D4 — "Symbolic verification" wording — resolved empirically (see Halmos smoke test)
**Fork:** keep calling Tier-3b "symbolic" (Halmos), or rename to fuzzing to avoid
smuggling false safety?
**Finding:** Halmos 0.3.3 is installed and symbolic runs HAVE executed historically with
real findings (e.g. `reports/phlimbo-ea/03/.../SYMBOLIC-002-*.json`,
`reports/reflax-yield-vault/11/symbolic-results.json`). The earlier claim that no
symbolic artifacts exist was based on only the three newest run dirs.
**Smoke test (2026-07-09, Halmos 0.3.3, forge 1.5.1):** ran two properties on a share-math
contract. Result: Halmos **found the counterexample** for a deliberately-false property
(`check_bogusNoLoss` → FAIL with concrete witness) — so it genuinely detects bugs, the
security-relevant direction. But it **TIMED OUT** proving a true property
(`check_roundsDown` → [TIMEOUT] after 20s) — nonlinear `a*b <= c*d` over full uint256 is
the well-known Halmos/Z3 weak spot.
**Choice: KEEP "symbolic" — it is real, installed, and finds bugs a fuzzer can miss — but
harden the interpretation so a non-proof can never masquerade as safety.** Specifically:
1. `[PASS]` is the ONLY outcome that counts as proof. `[TIMEOUT]` and `[ERROR]` are
   **inconclusive**, carry ZERO safety weight, and must be surfaced as "unverified — needs
   bounded-input proof or manual review", never recorded or implied as "proved safe".
2. Every run that invokes Tier-3b MUST write `symbolic-results.json` with per-test outcome
   (pass/fail/timeout/error). A report's safety claim must cite an actual `[PASS]` artifact,
   not prose. If symbolic was skipped or every property timed out, the run says so explicitly.
3. Recommend input-bounding (uint64/uint128) to dodge nonlinear-timeout — but the proof is
   then only over the bounded domain and the test MUST state that scope. A bounded proof is
   honest; an unbounded [TIMEOUT] relabelled as pass is not.
**Reasoning:** renaming to "fuzzing" would *understate* it (it found a bug the fuzzer might
miss); leaving the "proves for ALL inputs" wording unqualified would *overstate* it (timeouts
are frequent). The fix targets the exact smuggling risk: TIMEOUT ≠ PASS.

### D5 — pattern DB: add missing classes, honestly label the staking patterns, fix grep-bait
**Fork:** tag the 7 `staking-yield` patterns `"scope": "phoenix-suite"` (implying skip on
non-Phoenix), or leave them general?
**Revised choice (changed from initial plan):** do NOT add a `scope` field. On re-reading,
those 7 patterns carry *general* MasterChef signatures (`accRewardPerShare`, `rewardDebt`,
`_updatePool`) **plus** Phoenix regression hooks (`accPhusdPerShare`, `nudgeSize`). They
genuinely generalize to any yield-farm fork, so tagging them narrow-scope would *lose*
discovery on a future non-Phoenix fork. Instead I documented the reality in
`pattern-matcher.md` ("STAKING-YIELD PATTERNS: GENERAL + REGRESSION HOOKS"): run them
everywhere; a general-signature hit is real discovery, a Phoenix-signature hit is a
regression check. **Added** 6 new general patterns to the DB (bumped to v1.1, 29→35):
`REENTRANCY-ERC721-RECEIVE`, `REENTRANCY-READONLY`, `REENTRANCY-CROSS-FUNCTION`,
`ROUNDING-DIRECTION`, `WEAK-PRNG`, `FEE-ON-TRANSFER-ACCOUNTING`. **Tightened** the worst
grep-bait: `INCORRECT-OPERATOR` no longer keys on bare `require(`/`if (` — now on
deadline/threshold/window/cap boundary signatures, with a note not to flag every comparison.
**Kept** all existing patterns (nothing deleted).
**Reasoning:** the user audits only their own (Phoenix/Behodler) DeFi, so a mislabel has low
operational cost today — but honest generality costs nothing and protects a future fork.

### D6 — pattern-matcher.md housekeeping
**Choice:** replace the hardcoded stale `patternsChecked: 22` with "count from DB (do not
hardcode)"; add an ERROR HANDLING section (missing scope, zero hits, unreadable
contract, DB parse error); make the skip rule precise (skip only patterns whose `note`
explicitly says C4-QA/known-issue, and even then route to manualReview, never silent).

### D7 — session-start.sh: version pinning + functional readiness
**Fork:** add download checksums (needs known-good hashes, unavailable offline) or a
lighter reproducibility improvement?
**Choice:** (a) pin tool versions via override env vars with documented defaults so runs
are reproducible and a version can be rolled back; (b) upgrade the readiness check from
"on PATH" to "actually executes" (`--version`/`--help` probe) so a broken binary reports
missing, not ready. Deferred: cryptographic checksum verification (needs a maintained
hash manifest; noted as a follow-up, not silently skipped).
**Reasoning:** version pinning is the high-value half of reproducibility and is safe to
add; checksum pinning needs infra I can't fabricate without smuggling in fake assurance.

### D8 — severity-auditor downgrade-bias balanced
**Choice:** keep the skepticism-of-High discipline but add an explicit symmetric rule that
understating a real High/Medium is a Law-1 miss (false negative), not a safe default, and
strengthen the upgrade path. A self-audit protecting user funds must not be systematically
biased toward down-classification.

---

## Deferred / explicitly NOT done (surfaced, not silently skipped)

- **Cryptographic checksum verification of tool downloads** (session-start.sh). Needs a
  maintained hash manifest of known-good binaries; fabricating one would be fake assurance.
  Version pinning (D7) is the reproducibility half that *is* safe to add now. Follow-up:
  add a `toolchain.lock` with sha256s if supply-chain integrity becomes a priority.
- **Strengthening the remaining grep-bait signatures** (`SELFDESTRUCT-FORCE-ETH`,
  `DOUBLE-VOTING`). Only `INCORRECT-OPERATOR` (the worst) was tightened this pass. The other
  two are weak-ish but not misleading; left for a later pattern-DB sweep.
- **Making Halmos a mandatory-and-green Tier-3 gate for every project.** It runs today but is
  often skipped or times out. The D4 honesty fixes ensure a skip/timeout is now *visible*
  rather than mistaken for verification; making symbolic mandatory needs per-project bounded
  harnesses — a separate, larger effort.

## Files changed this pass

- `.claude/agents/code-scanner.md` — reentrancy-class checklist (D1)
- `.claude/agents/econ-scanner.md` — rounding-direction checklist (D1)
- `.claude/agents/contract-profiler.md` — weak-PRNG local flag + ERC721/1155 inbound-hook surface (D1)
- `.claude/agents/deduplicator.md` — route below-threshold removals to manual-review, no silent drops (D2)
- `.claude/agents/poc-validator.md` — workspace-first authoritative, standalone = C4-export (D3)
- `.claude/agents/symbolic-analyzer.md` — TIMEOUT/ERROR ≠ PASS; domain-scoped proofs; write results always (D4)
- `.claude/agents/invariant-generator.md` — passing fuzz ≠ proof; record run depth (D4)
- `.claude/commands/analyze.md` — Tier-3 honesty rule in the orchestration (D4)
- `patterns/vulnerability-patterns.json` — v1.1, +6 general patterns, tightened INCORRECT-OPERATOR (D5)
- `.claude/agents/pattern-matcher.md` — non-hardcoded count, error-handling, precise skip rule, staking-pattern reality note (D6)
- `.claude/hooks/session-start.sh` — version pins (env-overridable, latest-fallback) + functional readiness probe (D7)
- `.claude/agents/severity-auditor.md` — symmetry rule; understating a High is a Law-1 miss (D8)

Nothing in `lib/`, `reports/`, `workspace/`, or any ledger was modified.
