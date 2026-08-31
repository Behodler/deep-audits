# Spec-Conformance Report — reflax-yield-vault

**Run:** reflax-yield-vault-16
**Audited commit:** `0110ce4` (story-049; baseline `ad12cb1`)
**Story checked:** `story-049` (YS-01 — credit principal via `convertToAssets`, Tokemak Autopool STATICCALL fix)
**Channel:** Law-2 (Faithfulness to stories). Intentionally **separate from the QA/gas bundle** — these are story/spec deviations and conformance records, not gas or style noise.

---

## Scope and conventions

This run reviewed the story-049 diff and, for the first time, treated **`src/concreteYieldStrategies/ERC4626YieldStrategy.sol` as in-scope** (DISC-15-004 resolved: the file is now in registered scope because stories now actively change it). story-049 changed exactly one credit line in `_acquireShares` (`previewRedeem(sharesReceived)` → `convertToAssets(sharesReceived)`).

**Headline: story-049 is FAITHFUL on behaviour** (it correctly fixes the Autopool STATICCALL brick), but it left its own NatSpec stale, producing one new faithfulness deviation (**F-16-003**). The value leg of the same change is the operational-hazard Low **ECON-A** (in the QA bundle), not a faithfulness item.

| ID | Subject | Verdict / Status | Origin | Severity-on-this-channel |
|----|---------|------------------|--------|--------------------------|
| **F-16-003** | `_acquireShares` NatSpec says "credits the full nominal amount (no haircut)" but code credits `convertToAssets(sharesReceived)` | DEVIATES · open | **NEW (this run)** | Faithfulness (doc fix; value leg = **ECON-A / L-16**) |
| **F-16-004** | `totalWithdrawal` NatSpec "24h/48h" vs 6h/72h constants at `AYieldStrategy.sol:414` | DEVIATES · open | **MIRROR of existing F-05 — NOT a new entry** | see F-05 (bumped to run-16) |
| FAITH-16-001 | story-049 implementation conformance | CONFORMS | verification record | none |
| F-03 | Cross-protocol integration assumption for stable-staker M-05 wiring of `relinquishPrincipal` | open · gate armed | carryover (first seen run-14) | Faithfulness — Medium re-eval gate fires next stable-staker run; annotated "magnitude = external vault fee config" |
| F-01 / F-02 / F-04 / F-05 | prior-run faithfulness | open — not re-triggered this run (outside story-049 diff) | ledger | unchanged; F-05 lastSeenRun bumped (absorbs F-16-004) |

---

## F-16-003 — `_acquireShares` NatSpec "no haircut" contradicts the `convertToAssets` credit (NEW)

**Status:** open · **Origin:** new (reflax-yield-vault-16) · **Story:** `story-049` (commit `0110ce4`)
**Location:** `src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L93-L95` (NatSpec) vs `#L115` (code)
**Fingerprint:** `c705bd94…` (`sha256(...:_acquireShares-natspec:full-nominal-no-haircut-contradicts-converttoassets-credit)`, empty `entryPoint`)
**Cross-reference:** **ECON-A / L-16** carries the value leg (fee-blind `convertToAssets` over-states redeemable NAV). This entry is the documentation contradiction only.

### What the story says (intent)

> story-049: "credit principal via `convertToAssets`" — book the current exchange-rate value of the shares actually received (so entry-fee / share-rounding discrepancies are not over-credited), and use `convertToAssets` (not `previewRedeem`) because some real vaults (Tokemak Autopools) revert with `StateChangeDuringStaticCall` inside `previewRedeem`.

### What the stale docs still say

> `ERC4626YieldStrategy.sol:93`: "@return creditedPrincipal The principal the base should book — the full nominal `amount`"
> `ERC4626YieldStrategy.sol:95`: "@dev Direct ERC4626 deposit: credits the full nominal amount (no haircut)."

### Actual behavior at this commit

`ERC4626YieldStrategy.sol:115`: `creditedPrincipal = vault.convertToAssets(sharesReceived);` — a value **below** the nominal `amount` whenever the vault has any entry-fee / share-rounding discrepancy, i.e. **a haircut**. The inline comment three lines above the credit (`:112-114`) even explains the haircut, directly contradicting the `@dev` block. An integrator reading the NatSpec would wrongly conclude the full deposited amount is booked as principal.

### Recommendation

Update `ERC4626YieldStrategy.sol:93/95` NatSpec to state that `_acquireShares` credits the current exchange-rate value of the shares actually received (`convertToAssets(sharesReceived)`), **not** the full nominal amount — drop the "no haircut" claim.

---

## F-16-004 — `totalWithdrawal` 24h/48h NatSpec vs 6h/72h code (MIRROR of F-05 — NOT a new entry)

The `AYieldStrategy.sol:414` "24-hour / 48-hour" NatSpec-vs-`6h/72h`-constants contradiction surfaced again this run. It is the **same site already filed as F-05** in run-15 (fingerprint `15597805…`). Per the no-double-filing rule, **no new entry is created**: F-05's `lastSeenRun` is bumped to `reflax-yield-vault-16` and F-16-004 maps to it. The registry `designDecision` was corrected this run (ACTION-15-001 closed); the in-code NatSpec sites remain the open fix surface tracked by F-05.

---

## F-03 — Cross-protocol integration assumption for stable-staker M-05 wiring (carryover, gate carried + annotated)

**Status:** open · **Origin:** carryover (first seen reflax-yield-vault-14) · **Fingerprint:** `52f9b84a…`
**Original report:** [`reports/reflax-yield-vault/14/findings/faithfulness/F-03-stable-staker-m05-integration-assumption.json`](../../14/findings/faithfulness/F-03-stable-staker-m05-integration-assumption.json)

### Annotation this run

F-03's StableStaker:786 consumer reads `principalOf`, which is now sourced (on `ERC4626YieldStrategy`) from the fee-blind `convertToAssets` credit (**ECON-A / L-16**). The Medium re-evaluation gate is **carried, not fired** (it fires in the next stable-staker regression run). It is annotated **"magnitude = external vault fee config"**: at the deployed autopools the NAV over-statement is sub-bps (Low), but the same code path is a **Medium** if a future strategy is wired to a non-trivial-exit-fee vault — so the gate must re-weigh severity against the *actual* vault wired at the integration point, not inherit ECON-A's stale Low. DEDUP-15-005 (buffer-inflow attribution) rides the same next-stable-staker-run trigger.

---

## Conformance verification record (no finding)

### FAITH-16-001 — story-049 implementation: CONFORMS

Verified at `0110ce4`: `_acquireShares` credits `vault.convertToAssets(sharesReceived)` (`ERC4626YieldStrategy.sol:115`); the `convertToAssets`-over-`previewRedeem` choice is the correct STATICCALL-safe fix for the Tokemak Autopool `StateChangeDuringStaticCall` brick (YS-01); no other contract surface changed. The behaviour conforms to the story's stated intent. The two residuals are **not** faithfulness failures of the *behaviour*: (1) the fee-blindness of `convertToAssets` (a value-leg operational hazard — **ECON-A / L-16**, magnitude-bound to external vault fee config), and (2) the stale `_acquireShares` NatSpec (**F-16-003**, the only behaviour-vs-doc contradiction).

---

## Triage

F-16-003 is an `open` doc deviation (single-line NatSpec fix at `ERC4626YieldStrategy.sol:93/95`). F-16-004 is absorbed by the existing open F-05 (no separate triage). F-03 stays `open` with its Medium re-eval gate **carried** to the next stable-staker run, annotated "magnitude = external vault fee config". F-01/F-02/F-04/F-05 remain open in the ledger, un-triggered on behaviour this run. Triage with `/ledger reflax-yield-vault`.
