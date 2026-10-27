# Run-42 carryover index (entry point `dev`)

All **53** `dev` ledger entries that are `open` (48) or `fix-pending` (5) as of `phoenix-phase-2-staging-42` are carried in full:

- **Medium (full copies, beside new submissions):** [`../M-01-C1.md`](../M-01-C1.md) = run 21 M-01 `a753907e2a4c…` (fix-pending); [`../M-01-C2.md`](../M-01-C2.md) = run 28 M-01 `11311795cd60…` (fix-pending). `-C<n>` follows originating-run order. The fingerprints tell the two M-01s apart.
- **Low / QA / Faithfulness (one cut-down file per originating audit):** `qa-report-05.md`, `-21`, `-26`, `-27`, `-28`, `-29`, `-30`, `-39`. Each file starts with a run-42 index that gives every retained entry's verdict, proposed action and exact `/ledger` command, followed by the verbatim body.
- Proposals collected in one place: [`../../script-audits/dev/proposed-status-changes.md`](../../script-audits/dev/proposed-status-changes.md).
- **Statuses changed by audit 42: NONE.**

| Orig. run | Label | issueId | Fingerprint | Sev | Status | Run-42 verdict | Proposed | File |
|---|---|---|---|---|---|---|---|---|
| 05 | (none) | — | `0b497be32114` | qa | open | LIKELY-FIXED | fixed | [qa-report-05.md](qa-report-05.md) |
| 21 | L-01 | — | `1e8cc0dc58ba` | low | open | STILL-PRESENT | — | [qa-report-21.md](qa-report-21.md) |
| 21 | L-02 | — | `ce524709d965` | low | open | LIKELY-FIXED | fixed | [qa-report-21.md](qa-report-21.md) |
| 21 | L-03 | — | `3177eed94ecb` | low | open | NOT RE-EXAMINED | — | [qa-report-21.md](qa-report-21.md) |
| 21 | L-04 | — | `dcce8f512418` | low | open | NOT RE-EXAMINED | — | [qa-report-21.md](qa-report-21.md) |
| 21 | L-05 | — | `4c3e1fb7f2d3` | low | open | STILL-PRESENT | — | [qa-report-21.md](qa-report-21.md) |
| 21 | L-06 | — | `c76a8f9f9479` | low | open | NOT RE-EXAMINED | — | [qa-report-21.md](qa-report-21.md) |
| 21 | L-07 | — | `1b461cb4d56c` | low | open | NOT RE-EXAMINED | — | [qa-report-21.md](qa-report-21.md) |
| 21 | L-08 | — | `daab9e86d033` | low | open | NOT RE-EXAMINED | — | [qa-report-21.md](qa-report-21.md) |
| 21 | L-09 | — | `acabc052baaa` | low | open | NOT RE-EXAMINED | — | [qa-report-21.md](qa-report-21.md) |
| 21 | M-01 | — | `a753907e2a4c` | medium | fix-pending | LIKELY-FIXED | fixed | [../M-01-C1.md](../M-01-C1.md) |
| 21 | M-02 | — | `f7de907d7981` | low | open | STILL-PRESENT | — | [qa-report-21.md](qa-report-21.md) |
| 21 | Q-01 | — | `6537da6fb748` | qa | open | OBSOLETE | close obsolete (wontfix) | [qa-report-21.md](qa-report-21.md) |
| 21 | Q-02 | — | `f5bb2b654c9a` | qa | open | STILL-PRESENT | — | [qa-report-21.md](qa-report-21.md) |
| 21 | Q-03 | — | `a37137b3e369` | qa | open | STILL-PRESENT | — | [qa-report-21.md](qa-report-21.md) |
| 21 | Q-04 | — | `a807cc7a6699` | qa | open | NOT RE-EXAMINED | — | [qa-report-21.md](qa-report-21.md) |
| 26 | L-01 | `pps26l1` | `eda17642828a` | low | fix-pending | OBSOLETE | close obsolete (wontfix) | [qa-report-26.md](qa-report-26.md) |
| 26 | L-03 | `pps26l3` | `12bcca3b617c` | low | fix-pending | STILL-PRESENT (code) / ruling-obsolete | wontfix (ruling) | [qa-report-26.md](qa-report-26.md) |
| 26 | L-04 | `pps26l4` | `b8e3d59139ae` | low | fix-pending | LIKELY-FIXED | fixed | [qa-report-26.md](qa-report-26.md) |
| 26 | Q-01 | `pps26q1` | `1c98937375ad` | qa | open | OBSOLETE (function) / ruling-invalid — HOLD | HOLD | [qa-report-26.md](qa-report-26.md) |
| 27 | L-01 | `pps27l1` | `65db3324e7d0` | low | open | OBSOLETE | close obsolete (wontfix) | [qa-report-27.md](qa-report-27.md) |
| 27 | L-02 | `pps27l2` | `6af1ae30ed82` | low | open | OBSOLETE | close obsolete (wontfix) | [qa-report-27.md](qa-report-27.md) |
| 27 | L-03 | `pps27l3` | `19e2e0c2d6a3` | low | open | OBSOLETE | close obsolete (wontfix) | [qa-report-27.md](qa-report-27.md) |
| 27 | L-04 | `pps27l4` | `9ee101a0cc41` | low | open | OBSOLETE | close obsolete (wontfix) | [qa-report-27.md](qa-report-27.md) |
| 27 | Q-01 | `pps27q1` | `9067d8a232b5` | qa | open | OBSOLETE | close obsolete (wontfix) | [qa-report-27.md](qa-report-27.md) |
| 27 | Q-02 | `pps27q2` | `e0ac78243e5f` | qa | open | OBSOLETE | close obsolete (wontfix) | [qa-report-27.md](qa-report-27.md) |
| 28 | F-01 | `pps28f1` | `dcf756f7a897` | low | open | STILL-PRESENT (ruling-sensitive) | — | [qa-report-28.md](qa-report-28.md) |
| 28 | F-02 | `pps28f2` | `beb259209f88` | low | open | NOT RE-EXAMINED | — | [qa-report-28.md](qa-report-28.md) |
| 28 | F-03 | `pps28f3` | `da94d1ba03fd` | low | open | STILL-PRESENT (recurrence) | — | [qa-report-28.md](qa-report-28.md) |
| 28 | L-01 | `pps28l1` | `c35f8cdc52dc` | low | open | NOT RE-EXAMINED | — | [qa-report-28.md](qa-report-28.md) |
| 28 | L-02 | `pps28l2` | `88af91804ec2` | low | open | STILL-PRESENT | — | [qa-report-28.md](qa-report-28.md) |
| 28 | L-03 | `pps28l3` | `669de8af7eb9` | low | open | LIKELY-FIXED | fixed | [qa-report-28.md](qa-report-28.md) |
| 28 | L-04 | `pps28l4` | `8cd3c3bad599` | low | open | STILL-PRESENT | — | [qa-report-28.md](qa-report-28.md) |
| 28 | L-05 | `pps28l5` | `c8c6fe8557a8` | low | open | STILL-PRESENT | — | [qa-report-28.md](qa-report-28.md) |
| 28 | L-06 | `pps28l6` | `bd268808fbd5` | low | open | STILL-PRESENT | — | [qa-report-28.md](qa-report-28.md) |
| 28 | L-07 | `pps28l7` | `98e727214903` | low | open | LIKELY-FIXED | fixed | [qa-report-28.md](qa-report-28.md) |
| 28 | M-01 | `pps28m1` | `11311795cd60` | medium | fix-pending | LIKELY-FIXED | fixed | [../M-01-C2.md](../M-01-C2.md) |
| 28 | Q-01 | `pps28q1` | `d7242d7c43ac` | qa | open | NOT RE-EXAMINED | — | [qa-report-28.md](qa-report-28.md) |
| 28 | Q-02 | `pps28q2` | `d3aa1e35c995` | qa | open | STILL-PRESENT | — | [qa-report-28.md](qa-report-28.md) |
| 29 | F-04 | `pps29f4` | `ee5aae66ac65` | low | open | NOT RE-EXAMINED | — | [qa-report-29.md](qa-report-29.md) |
| 29 | L-06 | `pps29l6` | `08adbb692840` | low | open | STILL-PRESENT | — | [qa-report-29.md](qa-report-29.md) |
| 29 | L-07 | `pps29l7` | `49b9904ee12a` | low | open | STILL-PRESENT (empirically confirmed) | — | [qa-report-29.md](qa-report-29.md) |
| 29 | Q-03 | `pps29q3` | `111b6f04c9b7` | qa | open | STILL-PRESENT | — | [qa-report-29.md](qa-report-29.md) |
| 30 | F-01 | `pps30f1` | `d862aec474e0` | low | open | NOT RE-EXAMINED | — | [qa-report-30.md](qa-report-30.md) |
| 30 | L-01 | `pps30l1` | `4fd01c83c32d` | low | open | NOT RE-EXAMINED | — | [qa-report-30.md](qa-report-30.md) |
| 30 | L-03 | `pps30l3` | `85754b285c30` | low | open | NOT RE-EXAMINED | — | [qa-report-30.md](qa-report-30.md) |
| 30 | Q-01 | `pps30q1` | `bb029fb3cabf` | qa | open | NOT RE-EXAMINED | — | [qa-report-30.md](qa-report-30.md) |
| 30 | Q-02 | `pps30q2` | `66671224826b` | qa | open | NOT RE-EXAMINED | — | [qa-report-30.md](qa-report-30.md) |
| 30 | Q-03 | `pps30q3` | `e15cd2e25141` | qa | open | NOT RE-EXAMINED | — | [qa-report-30.md](qa-report-30.md) |
| 39 | F-01 | `pps39f1` | `b8036903340e` | qa | open | STILL-PRESENT (empirically confirmed) | — | [qa-report-39.md](qa-report-39.md) |
| 39 | L-01 | `pps39l1` | `9a694ae01fe1` | low | open | OBSOLETE | close obsolete (wontfix) | [qa-report-39.md](qa-report-39.md) |
| 39 | Q-01 | `pps39q1` | `9fa8eee3010e` | qa | open | STILL-PRESENT | — | [qa-report-39.md](qa-report-39.md) |
| 39 | Q-02 | `pps39q2` | `c35d7cea7c0c` | qa | open | NOT RE-EXAMINED | — | [qa-report-39.md](qa-report-39.md) |
