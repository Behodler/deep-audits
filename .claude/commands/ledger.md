View and triage the persistent findings ledger for a project
# Purpose
Inspect and update `reports/<project>/ledger.json` — the persistent record of which findings are open, fixed, or triaged across audit runs. Triage decisions recorded here are respected by future `/analyze` and `/full-audit` runs (acknowledged/wont-fix/false-positive findings are suppressed; `fix-pending` findings keep being rescanned; reappearing fixed findings are flagged as regressions).

# Arguments
- `$ARGUMENTS` format: `<project-name> [action] [selector] [note]`
- Project name is case-insensitive (normalized to lowercase-kebab).
- **`<selector>` names one finding.** Preferred form is the issue ID (`pps26l1`); a fingerprint
  prefix, a run label (`L-01`), or a plain-English description also work — see **Selecting a
  finding** below. Older revisions of this command called this argument `<fingerprint>`; the
  fingerprint still works, it is just no longer the only thing that does.
- Actions:
  - *(none)* → list the ledger
  - `fixpending <selector> [note]` → mark `fix-pending` — **valid finding, fix owed.** Stays in the scan.
  - `ack <selector> [note]` → mark `acknowledged` — **disposal.** Suppressed from future scans.
  - `wontfix <selector> [note]` → mark `wont-fix`
  - `false-positive <selector> [note]` → mark `false-positive`
  - `fixed <selector>` → mark `fixed` (records current submodule commit)
  - `reopen <selector>` → set back to `open` (also the way to undo an abandonment)
  - `abandon-branch <branch> [note] [--force]` → mark every finding seen **only** on `<branch>` as `abandoned` — the branch was discarded, so the code carrying them is gone
  - `abandon <selector> [note]` → mark one finding `abandoned` (same meaning, single entry)
  - `branches` → group the ledger by branch and show which branches are gone upstream

## Selecting a finding

Selectors are typed by a human at a terminal, so this command **resolves intent rather than
parsing syntax**. Full ladder and safety rules: **finding-manager → FINDING SELECTOR
RESOLUTION** and `docs/issue-id-scheme.md`. In short, all of these reach the same entry:

```
/ledger phoenix-phase-2-staging wontfix pps26l4      # issue ID — preferred
/ledger phoenix-phase-2-staging wontfix PPS-26-L-4   # punctuation/case ignored
/ledger phoenix-phase-2-staging wontfix 26l4         # project already known from arg 1
/ledger phoenix-phase-2-staging wontfix b8e3d591     # fingerprint prefix
/ledger phoenix-phase-2-staging wontfix L-04         # run label, newest run
/ledger phoenix-phase-2-staging wontfix "deployer minter grant"   # description
```

Two rules make this safe rather than reckless:

- **Announce any non-exact resolution** before writing: `Resolved "deployer minter grant" → pps26l4  b8e3d591  "…"`.
- **Confirm before a fuzzy mutation.** A match by run label or free text (ladder rungs 4–5) must
  be confirmed by the human *before* the status write lands. Triaging the wrong entry marks a
  live bug `wont-fix` — the Law-1 failure this ledger exists to prevent. An issue-ID or
  fingerprint match is exact and needs no confirmation.
- Ambiguity lists up to 5 ranked candidates and asks; it never picks the top one silently.
  Zero matches lists the nearest few rather than just failing.

Note that a typo costing one clarifying round trip is the *intended* behaviour — a syntax
error must never crash the command or, worse, hit the wrong finding.

## Choosing between `fixpending` and `ack`

These two look similar in a triage conversation ("yes, that's real") but have **opposite** downstream effects. Get this right:

| | `fixpending` | `ack` |
|---|---|---|
| Means | valid, **and we're fixing it** | valid, **and we're living with it** |
| Future scans | **rescanned** (never suppressed) | **suppressed** |
| Carryover stub | yes | no |
| `/open-issues` | shown as undealt-with | hidden as dealt-with |

## Choosing between `abandon-branch` and the other disposals

`abandoned` is not a verdict on the finding — it says the *code* went away with a discarded branch. Keep it distinct:

| | `abandoned` | `wont-fix` / `ack` | `fixed` |
|---|---|---|---|
| Means | the branch carrying it was discarded; the code no longer exists | the code exists, we're living with the issue | the code exists and the issue was repaired |
| Set by | `/ledger … abandon-branch` (human) | human triage | human, after verification |
| Future scans | suppressed | suppressed | rescanned for regression |
| Reversible | yes — `reopen` restores it if the branch returns | yes | yes (regression) |

**Never abandon a finding that was also seen on another branch**, and never abandon findings from a branch that was **merged** into the trunk — merging moves the code onto the trunk, so those findings are live. Both cases are hard refusals, not warnings (Law 1: a suppressed live bug is the exact failure mode the ledger exists to prevent).

**If the human says "acknowledged, will fix" — or anything else that promises a fix — that is `fixpending`, NOT `ack`.** The word "acknowledged" in their sentence describes accepting the finding, not disposing of it. Choosing `ack` there silently removes a live bug from every future scan, which is the exact failure `fix-pending` exists to prevent (Law 1: recall beats report-tidiness). When a triage instruction is ambiguous between the two, **ask** — do not guess, and do not default to `ack`.

# Orchestration Flow

## 1. Resolve Project
Invoke **project-manager**: "Resolve friendly name (lowercase-kebab)" and locate `reports/<project>/ledger.json`. If absent, report that no ledger exists yet (run `/analyze` first).

## 2a. List (no action)
Invoke **finding-manager**: "Load and summarize the ledger"
```
Ledger: phoenix-nft-staking   (branch feat/nudge-v3 @ a1b2c3d, updated 2026-05-24)
  baselines: master 9611312 (run -26) · feat/nudge-v3 a1b2c3d (run -27)
─────────────────────────────────────────────────────────────────
OPEN (3)
  H  pns9h1    a1f9..  Reward debt accounting drain        first phoenix-nft-staking-09 · last -12
  M  pns11m2   7c2e..  Missing staleness check on oracle   first phoenix-nft-staking-11 · last -12
  L  pns12l3   3b80..  Unindexed event                     first phoenix-nft-staking-12 · last -12
FIX-PENDING (1)   ← still scanned; fix owed
  H  pns14h1   88ae..  Promo flush over-credit             "will fix: gate accrual on phase"
FIXED (7)
  H  pns8h2    9d44..  Migrator drain via unstakeFor       fixed at 0fae12 (phoenix-nft-staking-08)
ACKNOWLEDGED (2)   ← suppressed from future scans
  C  —         5e11..  Single-admin migrator key (by design)   "trusted multisig"
WONT-FIX (0)   FALSE-POSITIVE (0)
ABANDONED (1)   ← branch discarded; code no longer exists
  M  pns25m4   c40b..  Streamer double-credit on rewire        branch feat/spike-v2 (discarded 2026-07-30)
```
The **issue ID** column comes first — it is the handle to quote and to type back into this
command. The fingerprint prefix stays as the secondary, machine-side key. Entries predating the
ID backfill print `—`; that is expected, not damage, and they are still addressed by fingerprint.
List `FIX-PENDING` in its own section directly after `OPEN` — **never** collapse it into `ACKNOWLEDGED`. The two sections carry opposite scan semantics, so the annotations above ("still scanned" / "suppressed") are load-bearing: keep them. `ABANDONED` likewise gets its own section: it is a disposal by *code deletion*, not by decision, and merging it into `WONT-FIX` would misrepresent both.

Annotate each finding with its branch when the ledger holds more than one — `branch feat/x` for a branch-only finding, `branch feat/x +master` when `branchesSeen` covers several.

## 2c. Branches view (`branches`)
Invoke **project-manager** for branch state and **finding-manager** for the partition:
```
Branches: phoenix-nft-staking     (currentBranch feat/nudge-v3 · defaultBranch main)
──────────────────────────────────────────────────────────────────────────────
  main             live      baseline 9611312 (run -26)   22 findings (18 also elsewhere)
  feat/nudge-v3    live      baseline a1b2c3d (run -27)    5 findings (3 only on this branch)
  feat/spike-v2    GONE ⚠    baseline 71abe3e (run -25)    4 findings (2 only on this branch, 2 also on main)
      → not merged into main. Retire the branch-only pair with:
        /ledger phoenix-nft-staking abandon-branch feat/spike-v2
        (the 2 findings also seen on main stay open — they are trunk bugs)
```
A branch is `GONE` when `origin/<branch>` no longer resolves after `git fetch --prune`. **Reporting a gone branch never changes a status** — it only offers the command.

## 2b. Update (action given)
Invoke **finding-manager**: "Update ledger entry status"
- Resolve the selector via finding-manager → FINDING SELECTOR RESOLUTION (issue ID → fingerprint prefix → run label → description). Announce any non-exact resolution; **confirm with the human before writing** when the match came from a run label or free text.
- Apply the new status to the resolved entry.
- For `fixed`, record `fixedAtCommit` = current submodule HEAD.
- For `fix-pending`, leave `fixedAtCommit` **null** — a fix is owed, not landed. Record the plan in the note.
- Store the optional note. Set `updatedAt`.
- Never delete entries — status changes only (preserves regression detection).
- Confirm the change, naming the entry by **issue ID first** (`pns14h1`, fingerprint `88ae7589`). When setting `fix-pending`, state in the confirmation that the finding **stays in the scan** and remains visible to `/open-issues`; when setting `acknowledged`, state that it is now **suppressed from future scans**. The human should never have to infer which of the two they got.

## 2d. Abandon a branch (`abandon-branch <branch> [note] [--force]`)
Invoke **project-manager** first for the two safety checks, then **finding-manager** to write.

1. **Fetch & classify the branch** — `git -C lib/<sub> fetch --prune origin`, then `remote_branch_exists`. If the branch is **still live upstream**, say so and ask for confirmation before continuing (abandoning findings on a branch that still exists is usually a mistake — the user may have meant a different branch name).
2. **Merged-branch guard (hard refuse).** `branch_is_merged(name, branch)` — if `<branch>` was merged into `defaultBranch`, **refuse**: its code is now trunk code and its findings are live. Print:
   `<branch> was merged into <defaultBranch> — its findings are trunk findings, not abandoned. Run /full-audit <project> to reconcile them against the trunk.`
   Only `--force` plus an explicit human note overrides this, and the note is recorded verbatim on every entry touched.
3. **Partition** via `branch_findings(name, branch)`:
   - `onlyOnBranch` (`branchesSeen == [branch]`) → eligible.
   - `alsoElsewhere` → **left untouched**, and listed by label + title in the output so the user sees exactly what survived and why.
   - Entries with no `branch` field (pre-dating the metadata) count as trunk → never eligible.
4. **Apply** to the eligible set: `status: "abandoned"`, `abandonedBranch: <branch>`, `abandonedAt: <now>`, plus the note. Do **not** clear `branch`/`branchesSeen`, do not delete entries, and do not touch `branchBaselines` — the branch's baseline stays as history.
5. **Report** both sets and the reversal command:
```
Abandoned 2 findings from feat/spike-v2 (branch gone upstream, not merged into main):
  pns25m4  M-04  c40b1e77  Streamer double-credit on rewire
  pns25l9  L-09  8fe2a013  Unindexed rewire event
Left open — also seen on other branches (NOT abandoned):
  pns9h2   H-02  a1f9c2b0  Reward-debt drain          also on main
  pns11m7  M-07  7c2e4419  Oracle staleness           also on main
Undo with: /ledger phoenix-nft-staking reopen pns25m4
```
Never print only the abandoned count — the untouched list is the proof that nothing live was buried.

`abandon <fingerprint>` applies the same status to a single entry, with the same merged-branch refusal and the same "also seen elsewhere" warning (which, for a single explicit fingerprint, is a confirmation prompt rather than a hard refuse).

# Agent Delegation
- **project-manager**: resolve name, locate ledger, fetch/prune, branch liveness + merge checks, branch/finding partition
- **finding-manager**: read/update ledger entries, apply abandonment

# Critical Rules
1. **Statuses set here are authoritative** — automated runs never overwrite them.
2. **Never delete ledger entries** — a `fixed` entry must persist so a reappearance is caught as a regression.
3. **Two stable identifiers, both accepted.** `issueId` (`pps26l1`) is the human handle — minted once at first sighting, never recomputed, printed first. `fingerprint` (`sha256(contract:function:rootCauseClass[:entryPoint])`) is the machine key that later scans re-derive from the code; unique prefixes are accepted. Never write one where the other belongs, and never renumber an `issueId`.
3a. **Resolve selectors, don't parse them.** Walk the ladder, announce non-exact matches, confirm before a fuzzy *mutation*, list candidates on ambiguity. A malformed selector must never crash the command and must never silently hit the wrong finding.
4. **`ack` is a disposal; `fixpending` is not** — `ack` suppresses the finding from every future scan. Only use it when the finding will *not* be fixed. A promise to fix is `fixpending`. If the instruction is ambiguous, ask rather than defaulting to `ack`.
5. **Abandonment is human-only, branch-exact, and never applies to merged branches.** No scan sets `abandoned`; only entries seen *solely* on the discarded branch are eligible; a branch merged into the trunk is refused outright. Always print what was left untouched.
6. **`fix-pending` is never auto-resolved** — only a human `/ledger … fixed` closes it. `/analyze`, `/full-audit`, and `/recheck` may *propose* the flip; they never apply it.
