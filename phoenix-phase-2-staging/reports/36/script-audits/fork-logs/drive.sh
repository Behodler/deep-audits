#!/usr/bin/env bash
# run-36 audit driver (NOT sponsor code): two-leg cutover broadcast on an anvil mainnet fork (never mainnet).
set -u
set -f
R=http://127.0.0.1:8546
O=0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6
DOLA=0x865377367054516e17014CcdED1e7d814EDC9ce4
YS=0x1760E05356Ec1FBBA159C730781dCfB9920524e2
M=0x94855ACA13952D81507C92D3CdBb2e25D3bbE60C
SC=/tmp/claude-1000/-home-justin-code-audits-phoenix-phase-2-staging/70b162b0-e26e-4f11-b8cc-063b91788388/scratchpad
L=/home/justin/code/audits/phoenix-phase-2-staging/reports/36/script-audits/fork-logs
W=/home/justin/code/audits/phoenix-phase-2-staging/work
SK="--skip test/audit-run3*"
export CUTOVER_GAS_PRICE_WEI=300000000
cd $W
for i in $(seq 1 60); do cast block-number --rpc-url $R >/dev/null 2>&1 && break; sleep 1; done
echo "anvil block $(cast block-number --rpc-url $R)"
cast rpc anvil_impersonateAccount $O --rpc-url $R >/dev/null
cast rpc anvil_setBalance $O 0x16345785D8A0000 --rpc-url $R >/dev/null

echo "== initiate"
forge script script/InitiateDolaStrategyWithdrawal.s.sol:InitiateDolaStrategyWithdrawal $SK --rpc-url $R --sender $O --broadcast --skip-simulation --slow --unlocked -vvv > $L/03-anvil-initiate-broadcast.log 2>&1; echo "initiate exit=$?"
echo "mined withdrawalStates: $(cast call $YS 'withdrawalStates(address,address)(uint256,uint8,uint256)' $DOLA $M --rpc-url $R | tr '\n' ' ')" | tee -a $L/03-anvil-initiate-broadcast.log
NOW=$(cast block latest -f timestamp --rpc-url $R); T=$((NOW - 21600 - 300))
cast rpc anvil_setStorageAt $YS $(cat $SC/ia_slot) $(cast to-uint256 $T) --rpc-url $R >/dev/null; cast rpc evm_mine --rpc-url $R >/dev/null
forge script script/DolaStrategyWithdrawalStatus.s.sol:DolaStrategyWithdrawalStatus $SK --rpc-url $R -vvv > $L/04-anvil-status-startok.log 2>&1
grep "effective phase" $L/04-anvil-status-startok.log

echo "== leg 1 broadcast"
forge script script/CutoverStableStakerV2Mainnet.s.sol:CutoverStableStakerV2Mainnet $SK --rpc-url $R --sender $O --broadcast --skip-simulation --slow --unlocked --legacy --with-gas-price $CUTOVER_GAS_PRICE_WEI --gas-estimate-multiplier 200 -vvv > $L/05-anvil-cutover-broadcast-leg1.log 2>&1; echo "leg1 forge exit=$?"
cp broadcast/CutoverStableStakerV2Mainnet.s.sol/1/run-latest.json $L/05-leg1-run-latest.json
cp server/deployments/progress.stable-staker-v2-cutover.1.json $L/05-leg1-progress.json
node scripts/patch-mainnet-addresses-stable-staker-v2.js > $L/06-anvil-patch-tail-leg1.log 2>&1; echo "patch exit=$?" | tee -a $L/06-anvil-patch-tail-leg1.log
echo "OWNER DOLA after leg1: $(cast call $DOLA 'balanceOf(address)(uint256)' $O --rpc-url $R)" | tee $L/06b-owner-dola-between-legs.txt
echo "minter principal on source: $(cast call $YS 'principalOf(address,address)(uint256)' $DOLA $M --rpc-url $R)" | tee -a $L/06b-owner-dola-between-legs.txt

echo "== leg 2 preview"
PREVIEW_MODE=true forge script script/CutoverStableStakerV2Mainnet.s.sol:CutoverStableStakerV2Mainnet $SK --rpc-url $R --sender $O --slow -vvv > $L/07-anvil-cutover-preview-leg2.log 2>&1; echo "leg2 preview exit=$?"
echo "== leg 2 broadcast"
forge script script/CutoverStableStakerV2Mainnet.s.sol:CutoverStableStakerV2Mainnet $SK --rpc-url $R --sender $O --broadcast --skip-simulation --slow --unlocked --legacy --with-gas-price $CUTOVER_GAS_PRICE_WEI --gas-estimate-multiplier 200 -vvv > $L/08-anvil-cutover-broadcast-leg2.log 2>&1; echo "leg2 forge exit=$?"
cp broadcast/CutoverStableStakerV2Mainnet.s.sol/1/run-latest.json $L/08-leg2-run-latest.json
cp server/deployments/progress.stable-staker-v2-cutover.1.json $L/08-leg2-progress.json
cp server/deployments/mainnet-addresses.ts $SC/mainnet-addresses.pre-patch.ts
node scripts/patch-mainnet-addresses-stable-staker-v2.js > $L/09-anvil-patch-tail-leg2.log 2>&1; echo "patch exit=$?" | tee -a $L/09-anvil-patch-tail-leg2.log
git diff -- server/deployments/mainnet-addresses.ts > $L/09-mainnet-addresses.patch.diff
git checkout -- server/deployments/mainnet-addresses.ts
echo "== verify"
forge script script/VerifyStableStakerV2Cutover.s.sol:VerifyStableStakerV2Cutover $SK --rpc-url $R -vvv > $L/10-anvil-verify.log 2>&1; echo "verify exit=$?"
forge script script/DolaStrategyWithdrawalStatus.s.sol:DolaStrategyWithdrawalStatus $SK --rpc-url $R -vvv > $L/11-anvil-status-postcutover.log 2>&1
grep "effective phase" $L/11-anvil-status-postcutover.log
echo "OWNER DOLA end: $(cast call $DOLA 'balanceOf(address)(uint256)' $O --rpc-url $R)"
echo DONE
