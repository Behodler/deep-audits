# Intent — antimatter-pool (story-122 Script B)

Source commit `669cbc1` (read-only). Fork block 26303964.

## Authoritative story
- **story-122** `~/code/product-owner/stories/phStaging2/auto-complete/sya-antimatter-cutover/122-sya-antimatter-mainnet-catch-up.md`
  (state: **auto-complete**, machine-approved, not human-reviewed). Script B spec L119-143; checklist L177-182; review L331-371.
- **story-113** `.../auto-complete/phStaging2-sya-and-pool/113-antimatter-pool-seeder-contract.md` (seeder contract; F3 Decision 7 L177-181, F3/R1 L231, L405-411, L464-465; pricing intent L113).
- Supporting: runbook `docs/SyaAntimatterMainnetCutover.md` L44-66, L90-96; package.json `//antimatter-pool` comment.

## Stated purpose
- [x] Deploy `AntimatterPoolSeeder(OWNER, phUSD, sUSDS, Antimatter, Router02, PhusdSusdsPair, UniPoolerV2)` — done (tx1, 0xdb70…09BE at nonce 1791).
- [x] Move 10% (`lpForBps(1_000)` = 2,258.927 LP) of UniPoolerV2's phUSD/sUSDS LP out of the pooler — done (tx2).
- [x] Unwrap it, burn the 2,457.703 phUSD, mint exactly as much AM (1 AM ≡ 1 phUSD by quantity, story-113 L113) — done (tx5).
- [x] Seed a NEW AM/sUSDS UniV2 pair (0xb6da…a4DA) with all the AM + 2,077.157 sUSDS; LP (2,259.433) to OWNER — done (tx5) on a clean pair.
- [x] Temporary AM minter grant to the seeder, then revoke — done (tx4/tx6) **on the happy path only** (see findings: not on a failed-seed resume).
- [x] Patcher FILLs `AntimatterPoolSeeder` + `AntimatterSusdsPair`; `:verify`; tax ledger.

## Story vs. author restatement (Law 2 gaps)
- Story L141 / script NatSpec L49-50 / runbook L63-64: "F3 `amountBMin=0` acceptable because the pair is created fresh in the same transaction, **guaranteed by step 0**." On chain this is false: step 0 runs only in forge's local pass; tx5 carries no pair-absence check (finding AP-01).
- Story L132 "The revoke (step 8) must always run, even on resume" / runbook L94 "B's minter revoke runs on every run". False when tx5 failed and the pair exists: step 0 aborts before step 8 (finding AP-02).
- Story L142-143 / runbook L46-52: private RPC presented as the R1 mitigation. It hides only pending txs; tx1 (seeder CREATE) is mined publicly ≥3 blocks before tx5 under `--slow`.

## Declared pre-conditions (in-script, local pass)
- chainid == 1; book keys non-zero; code at all 7 targets; `factory.getPair(phUSD,sUSDS) == PhusdSusdsPair`.
- UniPoolerV2.owner() == OWNER; Antimatter.owner() == OWNER.
- Step 0: `factory.getPair(AM,sUSDS) == 0`, unless resume (recorded seeder has code AND OWNER holds any LP of the existing pair).
- Step 1 resume: recorded seeder has code. Step 2: lp > 0 and == poolerLp*1000/10000.
- Step 4: pooler holds ≥ lp. Step 6: `isApprovedMinter(seeder)` after grant.
- Floors: pro-rata unwrap −0.1% (minPhUSD 2,455.249, minSUSDS 2,075.083).

## Declared post-conditions (in-script, same simulated block)
- phUSD supply fell by exactly AM minted; AM supply rose by the same; pair AM reserve == AM minted.
- UniPoolerV2 LP == prior − lp (only if rescued this run).
- OWNER AM/sUSDS LP == liquidity > 0; seeder not a minter; `seeder.amSusdsPair() == factory.getPair`; reserves > 0; seeder holds none of 5 tokens.
- None of these run on chain; they hold for the simulation. Verifier re-checks only the live-state subset plus the record's internal consistency.
