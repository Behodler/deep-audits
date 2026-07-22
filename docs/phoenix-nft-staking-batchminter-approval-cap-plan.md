# Plan — Cap the minter approval at `paymentAmount` in `BatchNFTMinterMultiToken`

**Target repo:** `phoenix-nft-staking` (audited as `lib/phoenix-nft-staking`, **read-only** here — implement upstream)
**Audited commit:** `c881a42`
**Primary file:** `src/BatchNFTMinterMultiToken.sol` (`batchMint`, `:360`)
**Ledger entries:** `7a1718e9…` (M-01, composition) · `fcaca002…` (M-01, step-10 sweep leg) · `ad36260f…` (M-07, `forceApprove` leg)
**Author/decision:** owner (justin), 2026-07-21
**Companion:** `phoenix-nft-staking-duplicate-reward-token-dedupe-plan.md` — **land both in the same commit**

---

## 1. Decision

Cap the minter allowance at the amount the caller actually pulled in.

```diff
-        paymentToken.forceApprove(address(nftMinter), type(uint256).max);
+        // Never let the minter spend more than THIS caller pulled in. At
+        // paymentAmount == 0 the mint reverts at the allowance boundary
+        // regardless of what the contract holds, so the bound is structural
+        // rather than balance-dependent.
+        paymentToken.forceApprove(address(nftMinter), paymentAmount);
```

The existing revoke at `:368` (`forceApprove(…, 0)`) stays as-is.

**Scope of this plan is the UNDEPLOYED file only.** The frozen, mainnet-deployed
`src/BatchNFTMinter.sol` carries the identical construct at `:284` and **cannot be changed** — the three
ledger entries above are accepted `wont-fix` *against that file*. This plan exists so the same defect is
not re-shipped in the twin that has not yet deployed.

---

## 2. Why

`batchMint` composes three separately-filed legs into a zero-cost drain:

1. no lower bound on `paymentAmount` — `0` is accepted (`:357`);
2. the minter is approved for `type(uint256).max`, **not** `paymentAmount` (`:360`);
3. step 10 sweeps the **whole remaining** payment-token balance to `msg.sender`, ungated (`:381-383`).

A caller passing `paymentAmount = 0` therefore mints NFTs paid for out of value somebody else put in the
contract, and takes the remainder. `totalPaid`'s floor at `0` (`:384`) is the contract itself admitting
the refund can exceed the contribution.

PoC-proven 11/11 at `c881a42` (`workspace/phoenix-nft-staking/test/PoC_EconZeroPaymentSweep.t.sol`):
7 against the frozen deployed file, 4 against this twin. `testA1` — attacker pre-balance `0`,
pre-allowance `0`, ends `+490.000000` payment token and `+1` NFT, `totalPaid == 0`, outlay gas only.
`testA5` is the falsifying control: on an empty contract the attack dies at the funding boundary with
`ERC20InsufficientBalance(batch, 0, 10000000)`.

**Why the cap is the right leg to cut.** The precondition today is `R >= C` (contract-held payment token
≥ the mint cost), and `R = 0` on both live instances with no inflow route delivering the payment token —
which is what holds the finding at Medium. But that is a **balance** property, re-armed by any donation
or by an ordinary sink repoint. Capping the approval makes it an **allowance** property: at
`paymentAmount = 0` the mint reverts no matter what the contract holds, and no funding state can re-arm
it. It converts an operational bound into a structural one.

**Why now.** The fix is available only while this file is undeployed. Once it ships it is frozen, exactly
like its twin — and the twin's own incident history shows how that ends: `0x4ef0fDe4…` lost
**61.297674 USDC in 14 blocks** (`lib/phoenix-phase-2-staging/docs/batch-nft-minter-nudge-drain-fix.md`),
in the same MEV environment where the documented `rescueERC20` remedy is, per the contract's own NatSpec
(`:191-201`), *"a race the owner will usually lose."* Both live instances have `pauser() == address(0)`,
so there is no break-glass either.

---

## 3. Verification (TDD — red → green → refactor, Foundry only)

Per `lib/phoenix-nft-staking/CLAUDE.md`: TDD, Foundry only, and **no `script/` directory** in this repo.

1. **Red** — `test_ZeroPaymentAmountCannotMintFromContractBalance`: seed the contract with payment token
   `R > C`, call `batchMint(count = 1, recipient = attacker, paymentAmount = 0, [], [])`, assert it
   **reverts at the allowance boundary**. Must fail before the change (today it succeeds and pays out).
2. **Boundary** — `paymentAmount` exactly equal to the cumulative dispatcher charge succeeds; one wei
   short reverts. This pins that the cap does not break legitimate batches on the ramping price.
3. **Ramping-price control** — a batch on a dispatcher with `growthBasisPoints > 0` where the cumulative
   cost exceeds `count × currentPrice`: confirm the caller must pass the true cumulative amount and that
   the surplus-refund path (`:381-387`) still returns the excess. **This is the regression risk** — an
   under-quoted front-end starts reverting where it previously silently drew on contract balance.
4. **Green** — re-run `PoC_EconZeroPaymentSweep.t.sol`. The 4 `PoC_ZeroPaymentSweep_MultiToken` tests
   (`testB1`–`testB4`) must **no longer reproduce** the defect. PoC convention is **PASS = defect
   reproduced**, so they must flip; a PoC that merely fails to *compile* is inconclusive bit-rot, not a
   fix. The 7 `PoC_ZeroPaymentSweep_DeployedBatchNFTMinter` tests **must still reproduce** — that file is
   frozen and unfixed, and their continuing to pass is the correct result, not a failure.
5. **Unchanged** — the full upstream suite stays green (412 tests / 0 failed at `c881a42`).

---

## 4. What this does NOT fix

- **The step-10 whole-balance sweep itself** (`fcaca002…`) is untouched. With the cap in place a caller
  can no longer mint on someone else's money, but a caller who *does* pull in `paymentAmount` still
  sweeps any pre-existing residual on top of their own refund. Establishing `refund <= paymentAmount`
  is a separate, larger change — per run-20 D-35, **establish the property and test it, do not ship an
  unvalidated patch**. Not attempted here.
- **The frozen deployed `src/BatchNFTMinter.sol`.** Unfixable. The compensating controls are
  operational: do not route payment token to either instance, and set a non-zero `pauser`
  (ledger `919b71fd…`, still open — `pauser() == address(0)` on both live instances, and setting one is
  free and immediate).
- **The nudge economics.** `858e9e80…` (value-blind gate) and `521c20ad…` (MEV race) are accepted
  `wont-fix` and are not addressed by this change.

---

## 5. Ledger consequences

The three entries are being closed `wont-fix` **against the frozen deployed file**, where no remedy
exists. That closure must not be read as accepting the construct on this file.

**Tracking:** this fix rides in the same commit as the duplicate-`rewardTokens` dedupe, which is tracked
by ledger `a62fe01a…` at **`fix-pending`** — a status that is never suppressed and never auto-closed. So
the cap has a live, rescanned entry behind it even though its own three entries are suppressed. If the
two fixes are ever split into separate commits, **raise `ad36260f…` back to `fix-pending`**, or the cap
loses its tracking.
