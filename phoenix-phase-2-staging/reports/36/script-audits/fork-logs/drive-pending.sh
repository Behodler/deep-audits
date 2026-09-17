#!/usr/bin/env bash
# run-36 audit driver (NOT sponsor code): story-096 lapsed-window path end-to-end with REAL (non-preview) broadcasts on
# an anvil mainnet fork. Leg 1 is made to halt after Phase 6 by moving initiatedAt to "now" (waiting period) just before
# the execute tx (index 43) is mined; then the window is lapsed and the documented resume + :broadcast tail is replayed.
set -u
set -f
R=http://127.0.0.1:8547
O=0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6
DOLA=0x865377367054516e17014CcdED1e7d814EDC9ce4
YS=0x1760E05356Ec1FBBA159C730781dCfB9920524e2
M=0x94855ACA13952D81507C92D3CdBb2e25D3bbE60C
SC=/tmp/claude-1000/-home-justin-code-audits-phoenix-phase-2-staging/70b162b0-e26e-4f11-b8cc-063b91788388/scratchpad
L=/home/justin/code/audits/phoenix-phase-2-staging/reports/36/script-audits/fork-logs/pending-path
W=/home/justin/code/audits/phoenix-phase-2-staging/work
SK="--skip test/audit-run3*"
SLOT=$(cat $SC/ia_slot)
export CUTOVER_GAS_PRICE_WEI=300000000
mkdir -p $L
cd $W
rm -f server/deployments/progress.stable-staker-v2-cutover.1.json
for i in $(seq 1 60); do cast block-number --rpc-url $R >/dev/null 2>&1 && break; sleep 1; done
cast rpc anvil_impersonateAccount $O --rpc-url $R >/dev/null
cast rpc anvil_setBalance $O 0x16345785D8A0000 --rpc-url $R >/dev/null
cast rpc evm_setAutomine true --rpc-url $R >/dev/null
forge script script/InitiateDolaStrategyWithdrawal.s.sol:InitiateDolaStrategyWithdrawal $SK --rpc-url $R --sender $O --broadcast --skip-simulation --slow --unlocked -vvv > $L/P1-initiate.log 2>&1; echo "initiate exit=$?"
NOW=$(cast block latest -f timestamp --rpc-url $R)
cast rpc anvil_setStorageAt $YS $SLOT $(cast to-uint256 $((NOW - 21600 - 300))) --rpc-url $R >/dev/null; cast rpc evm_mine --rpc-url $R >/dev/null
BASE=$(cast nonce $O --rpc-url $R); EXEC_NONCE=$((BASE + 43)); echo "base nonce $BASE execute nonce $EXEC_NONCE"
cast rpc evm_setAutomine false --rpc-url $R >/dev/null

( # manual miner: before mining the execute, put the withdrawal back into its 6h waiting period so the execute reverts
  flipped=0
  while [ ! -f $SC/stop-miner ]; do
    latest=$(cast nonce $O --block latest --rpc-url $R 2>/dev/null); pending=$(cast nonce $O --block pending --rpc-url $R 2>/dev/null)
    if [ -n "$latest" ] && [ -n "$pending" ] && [ "$pending" -gt "$latest" ]; then
      if [ "$latest" = "$EXEC_NONCE" ] && [ $flipped -eq 0 ]; then
        ts=$(cast block latest -f timestamp --rpc-url $R)
        cast rpc anvil_setStorageAt $YS $SLOT $(cast to-uint256 $ts) --rpc-url $R >/dev/null
        echo "HALT-INJECT: initiatedAt <- $ts before mining nonce $latest (execute)"; flipped=1
      fi
      cast rpc evm_mine --rpc-url $R >/dev/null
    fi
    sleep 0.2
  done ) > $L/P2-miner.log 2>&1 &
MINER=$!
forge script script/CutoverStableStakerV2Mainnet.s.sol:CutoverStableStakerV2Mainnet $SK --rpc-url $R --sender $O --broadcast --skip-simulation --slow --unlocked --legacy --with-gas-price $CUTOVER_GAS_PRICE_WEI --gas-estimate-multiplier 200 -vvv > $L/P3-leg1-broadcast-halts-at-execute.log 2>&1; echo "leg1 forge exit=$?"
touch $SC/stop-miner; wait $MINER; rm -f $SC/stop-miner
cast rpc evm_setAutomine true --rpc-url $R >/dev/null
cp server/deployments/progress.stable-staker-v2-cutover.1.json $L/P3-progress-after-halt.json
echo "after halt: V2 paused? minter principal $(cast call $YS 'principalOf(address,address)(uint256)' $DOLA $M --rpc-url $R) withdrawalStates $(cast call $YS 'withdrawalStates(address,address)(uint256,uint8,uint256)' $DOLA $M --rpc-url $R | tr '\n' ' ')"

# the halt outlives the window
NOW=$(cast block latest -f timestamp --rpc-url $R)
cast rpc anvil_setStorageAt $YS $SLOT $(cast to-uint256 $((NOW - 280800 - 60))) --rpc-url $R >/dev/null; cast rpc evm_mine --rpc-url $R >/dev/null
forge script script/DolaStrategyWithdrawalStatus.s.sol:DolaStrategyWithdrawalStatus $SK --rpc-url $R -vvv > $L/P4-status-lapsed.log 2>&1; grep "effective phase" $L/P4-status-lapsed.log

echo "== resume :preview"
PREVIEW_MODE=true forge script script/CutoverStableStakerV2Mainnet.s.sol:CutoverStableStakerV2Mainnet $SK --rpc-url $R --sender $O --slow -vvv > $L/P5-resume-preview.log 2>&1; echo "resume preview exit=$?"
echo "== resume :broadcast, replaying the npm && tail exactly (backup step omitted)"
bash -c "forge script script/CutoverStableStakerV2Mainnet.s.sol:CutoverStableStakerV2Mainnet $SK --rpc-url $R --sender $O --broadcast --skip-simulation --slow --unlocked --legacy --with-gas-price $CUTOVER_GAS_PRICE_WEI --gas-estimate-multiplier 200 -vvv > $L/P6-resume-broadcast.log 2>&1 && node scripts/patch-mainnet-addresses-stable-staker-v2.js > $L/P7-tail-patch.log 2>&1 && echo TAIL-REACHED-VERIFY > $L/P7-tail-verify-reached.txt"; echo "resume :broadcast chain exit=$?"
ls $L/P7-tail-verify-reached.txt 2>/dev/null || echo ":verify NOT reached by the chain"
cat $L/P7-tail-patch.log
cp server/deployments/progress.stable-staker-v2-cutover.1.json $L/P6-progress-after-resume.json
git checkout -- server/deployments/mainnet-addresses.ts
V2=$(jq -r '.contracts.StableStakerV2.address' $L/P6-progress-after-resume.json)
echo "V2 $V2 paused=$(cast call $V2 'paused()(bool)' --rpc-url $R)"
echo "mainnet-addresses StableStakerV2 key: $(grep -E '^\s*StableStakerV2:' server/deployments/mainnet-addresses.ts)"
echo "== manual :verify (operator must know to run it)"
forge script script/VerifyStableStakerV2Cutover.s.sol:VerifyStableStakerV2Cutover $SK --rpc-url $R -vvv > $L/P8-manual-verify-pending.log 2>&1; echo "manual verify exit=$?"
grep -E "Phase6b: PENDING|per-user|Error" $L/P8-manual-verify-pending.log | head -5
echo DONE-PENDING
