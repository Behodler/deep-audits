# Open ledger entries NOT re-observed this run — visibility index

> **Not carryover stubs, and not a clean bill of health.** Run-20 was a regression scan focused on
> the story-021/022 diff plus the new fourth staker clone. These ledger entries remain `open` /
> `submitted`. **Absence of re-observation is NOT evidence of a fix and MUST NOT be read as one.**
> No status change is proposed for any of them. Listed here so they stay visible in the run you
> actually review (Law 1).

| Fingerprint | Ledger label | Contract | Why not re-observed |
|---|---|---|---|
| `f293859f…` | L-06 | `src/NFTStaker.sol` | not in this run's changed-file focus |
| `c3cda1d8…` | L-07 | `docs/runway-dynamics-and-apy-as-policy.md` | docs drift, not re-scanned |
| `0200236f…` | L-08 | `src/NFTStakerPriceScaled.sol` | still open; per D-15 now ALSO inherited verbatim onto copy #4 (`NFTStakerPriceScaledMigrateReady.sol`). Recorded as inherited against this entry; **no new fingerprint minted** |
| `e7bccb02…` | L-01 | `src/InPlaceNFTStakerMigrator.sol` | still open. **TRAP-3 / WATCH-19-L01:** do NOT repoint `claimTimedOut` / `rescueERC1155` to `newId`. run-20 L-04 and L-05 both trip on this |
| `966e7176…` | L-02 | `src/NFTStakerDepletion.sol` | still open. Analogue re-observed on copy #4 as run-20 **L-06** (disclosed, not collapsed) |
| `a18927e1…` | L-03 | `src/NFTStakerDepletion.sol` | still open. Analogue re-observed on copy #4 as run-20 **M-05** (disclosed, not collapsed; materially narrower there) |
| `ced20f2e…` | L-01 | `src/NFTStakerDepletion.sol` | still open (`depositFor` unconditional tail restart). Directly adjacent to the run-20 **M-03** arbitration |
| `51e8255b…` | L-02 | `src/NFTStakerDepletion.sol` | still open (`finalizeAndReset` dormant window). Adjacent to run-20 **L-05** |
| `d37ab4bb…` | L-03 | `src/NFTStaker.sol` | still open. Recurrence on copy #4 disclosed as run-20 **Q-05** |
| `d1cf8ef7…` | L-04 | `script/DeployBatchNFTMinter.s.sol` | still open, **PARTIALLY RESOLVED and NARROWED** — see the proposed `/ledger note`. Coverage hole (D-11): Aderyn does not analyze this file |
| `8b155727…` | Q-01 | `src/NFTStakerMigrator.sol` | still open (dead immutable `stakedId`). **Do not collapse** with run-20 L-02 — same contract, different root cause |
| `37783e03…` | Q-02 | `src/NFTStakerDepletion.sol` | still open (`_syncBudget` stale NatSpec) |

⚠ **Label-collision guard (R-3):** the labels in this table are **ledger** labels from earlier runs.
They are not run-20's labels. Disambiguate by fingerprint.
