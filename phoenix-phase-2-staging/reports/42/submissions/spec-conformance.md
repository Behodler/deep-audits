# Spec Conformance (Law 2): phoenix-phase-2-staging, script audit of the `dev` entry point (run 42)

- **Project:** `phoenix-phase-2-staging` @ [`d0060cb`](https://github.com/Behodler/phoenix-phase-2-staging/tree/d0060cb82d91f43c94c8d7f7a34fb50988957ac3) (`d0060cb82d91f43c94c8d7f7a34fb50988957ac3`), branch `master`, read-only
- **Run:** `phoenix-phase-2-staging-42` (`/audit-script phoenix-phase-2-staging dev`)
- **Delta:** `dfbf2f9..d0060cb` (entry-point baseline `entryPointBaselines.dev`)
- **Story tree:** `~/code/product-owner/stories/phStaging2/` (all state and sprint folders)
- **New Law-2 findings:** 0. **Recurrences:** 1 (`F-03`, below). **Stories graded FAITHFUL for the dev slice:** 116, 115, 114, 113, 112, 110/109/111, 106/107/103/105, 104 (see `script-audits/dev/candidate-findings.json` → `storyGrading`).

## Summary

| Label | issueId | Severity | Title | Origin | Ledger status |
|---|---|---|---|---|---|
| F-03 | `pps28f3` | Low | Shipped work with no story (run-42 recurrence) | still-open (recurrence of audit 28) | `open` (unchanged) |

## F-03: Shipped work with no story (run-42 recurrence): `dev-local.sh`'s API-port pre-flight (9762281) and `package.json` commits 18b5ac6 and 58c3b4f carry no `[story-NNN]` tag and no story covers them <!-- id: pps28f3 -->

- **issueId:** `pps28f3` (minted at audit 28; carried, not re-minted)
- **Fingerprint:** `da94d1ba03fd07a0a6bedfab78b0aed8d00cb8c6aee0054489a5adb8b978d130`
- **Fingerprint basis:** `lib/phoenix-phase-2-staging/package.json:n/a (repository-level):ShippedWorkWithoutAcceptanceCriteria:dev` (reproduced byte-for-byte; no new ledger entry)
- **Entry point:** `dev`  ·  **Branch:** `master`  ·  **First seen:** phoenix-phase-2-staging-28  ·  **Recurred at:** phoenix-phase-2-staging-42
- **Original report:** [`../../28/submissions/spec-conformance.md`](../../28/submissions/spec-conformance.md); carried verbatim in [`carryover/qa-report-28.md`](carryover/qa-report-28.md) Part B.
- **Finding record:** [`../findings/low/F-03-shipped-work-without-story-recurrence.json`](../findings/low/F-03-shipped-work-without-story-recurrence.json)

### The requirement (`registered-projects.json` → `storyPolicy`)

> Stories are the Law-2 source of truth and they live OUTSIDE this repo, in the product-owner stories tree. A `[story-NNN]` git commit subject is a POINTER to a story document, not the story itself: the commit line is a one-line summary, the document holds the acceptance criteria. Any faithfulness judgement (contract audit or script audit) MUST read the story document; never conclude 'the story is external / unavailable' and never grade faithfulness from the commit subject alone.

> Story document (authoritative acceptance criteria) > `[story-NNN]` commit message body > <project>/src/CLAUDE.md and <project>/src/docs/*.md > designDecisions/systemAssumptions in this registry. Where the document and the commit disagree, the document wins and the divergence is itself reportable.

The project's own `CLAUDE.md` and the root `CLAUDE.md` restate it: a `[story-NNN]` commit subject is the pointer that links shipped behaviour to the acceptance criteria it is graded against. A commit with no tag and no matching story document has nothing to be graded against.

### The deviation: three un-storied commits in the `dev` closure

| Commit | Date | Subject | Files in the `dev` closure | Story |
|---|---|---|---|---|
| `9762281` | 2026-10-18 | anvil deployment and port blocking check | `dev-local.sh` (+47 lines: the `API_PORT` pre-flight with `ss`/`lsof`/`/dev/tcp` listener discovery and pid/cwd reporting), plus regenerated tracked broadcast and `server/deployments/*` address books | **None.** No tag, and no story under `phStaging2` covers it. Story 081 (`auto-complete`), which created `dev-local.sh`, specifies only the `:8545` ownership and genesis-freshness gates. |
| `18b5ac6` | 2026-10-24 | Accounting layer | `package.json` (5 lines), alongside `scripts/ledger-record.js` (417 lines), `ledger/*`, `CLAUDE.md` | **None.** No tag, no covering story. |
| `58c3b4f` | 2026-10-20 | sepolia deploy | `package.json`, `script/helpers/UniswapHelperLocalStack.sol`, chain-11155111 broadcasts, `CLAUDE.md` | **None.** No tag, no covering story. |

Every other `package.json` commit in the delta is tagged (`[story-103]`, `[story-104]`, `[story-105]`, `[story-106]`, `[story-107]`, `[story-111]`).

Out-of-delta context: untagged `6c9416d` (2026-09-14) flipped `start:anvil`'s block time from 2 to 5. That is what made `dev-local.sh`'s "byte-identical to the start:anvil key" comment false (ledger `Q-03`, `111b6f04c9b7`, still present).

### Why this is Low, and a Law-2 note rather than a defect

The behaviour itself is sound. Re-running `./dev-local.sh` against the live stack exited 1 with `Error: port 3001 is already in use ... kill 35345` before `clean:local` and deleted nothing, so the gate fails safe. Nothing on-chain or user-facing is wrong. The gap is that the gate and the two `package.json` changes have **no acceptance criteria**. A later edit, such as dropping the `ss`/`lsof` fallback, cannot be graded against anything. This is the same systemic root that audit 28 filed as `F-03`, so it is folded into that entry as a recurrence and not opened as a sibling.

### Recommendation

Add `[story-NNN]` tags or retroactive story documents for `9762281`, `18b5ac6` and `58c3b4f`:

1. Retro-file a short story, or an addendum to story 081, that states the API-port gate's acceptance criteria: refuse when `API_PORT` has any listener on any interface, check before `clean:local`, and print the pid and cwd.
2. Cover the "Accounting layer" (`scripts/ledger-record.js` and its `package.json` key) and the "sepolia deploy" `package.json`/`UniswapHelperLocalStack.sol` changes the same way.
3. Alternatively, document these as **chores exempt from the story policy**, for example as an explicit exemption list in the project `CLAUDE.md`, so the gap is a recorded decision and not an omission.
4. Tag future `dev-local.sh` / `package.json` commits with their story.

### Ledger action (run 42)

`lastSeenRun` set to `phoenix-phase-2-staging-42`. The run-42 commits were appended to the entry's `note`. **Status unchanged (`open`)** and severity unchanged (`low`). No new entry was opened and the issueId was not re-minted. To triage: `/ledger phoenix-phase-2-staging <action> da94d1ba03fd`.

## Other Law-2 entries carried this run (not re-filed)

These open faithfulness entries are carried verbatim in `carryover/` and are not restated here:

| Label | issueId | Fingerprint | Run-42 verdict | Carried in |
|---|---|---|---|---|
| F-01 | `pps39f1` | `b8036903340e…` | STILL-PRESENT (empirically confirmed) | [`carryover/qa-report-39.md`](carryover/qa-report-39.md) |
| F-02 | `pps28f2` | `beb259209f88…` | NOT RE-EXAMINED | [`carryover/qa-report-28.md`](carryover/qa-report-28.md) |
| F-01 | `pps30f1` | `d862aec474e0…` | NOT RE-EXAMINED | [`carryover/qa-report-30.md`](carryover/qa-report-30.md) |
| F-01 | `pps28f1` | `dcf756f7a897…` | STILL-PRESENT (ruling-sensitive) | [`carryover/qa-report-28.md`](carryover/qa-report-28.md) |
| F-04 | `pps29f4` | `ee5aae66ac65…` | NOT RE-EXAMINED | [`carryover/qa-report-29.md`](carryover/qa-report-29.md) |

**Statuses changed by audit 42: NONE.**
