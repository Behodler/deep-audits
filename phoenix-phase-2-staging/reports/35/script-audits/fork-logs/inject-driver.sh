#!/usr/bin/env bash
# run-35 audit harness (NOT sponsor code). Manual-mining driver for an anvil cutover broadcast.
# Mines every pending tx one block at a time. When OWNER's next pending nonce == TRIGGER_NONCE
# (the Phase 6b setStablecoinEnabled(DOLA,false) tx), first submits INJECT (a third-party tx) so it
# lands in the same block, i.e. AFTER forge's local pass baked Phase 6b calldata and BEFORE the
# execute / approve(R) / noMintDeposit(R) transactions are mined.
# Usage: inject-driver.sh <rpc> <trigger_nonce> <mode: skim|none> <logfile>
set -u
RPC=$1; TRIGGER=$2; MODE=$3; LOG=$4
OWNER=0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6
SYA=0x0cD353bfda674D04823B2826ffafB83B560D21B6
YS_DOLA=0x1760E05356Ec1FBBA159C730781dCfB9920524e2
DOLA=0x865377367054516e17014CcdED1e7d814EDC9ce4
CLAIMER=0x00000000000000000000000000000000000C1A1B
injected=0
echo "driver start $(date -u +%T) trigger=$TRIGGER mode=$MODE" >> "$LOG"
while true; do
  [ -f /tmp/claude-1000/run35-driver-stop ] && { echo "stop flag" >> "$LOG"; exit 0; }
  latest=$(cast nonce $OWNER --block latest --rpc-url $RPC 2>/dev/null)
  pending=$(cast nonce $OWNER --block pending --rpc-url $RPC 2>/dev/null)
  if [ -n "$latest" ] && [ -n "$pending" ] && [ "$pending" -gt "$latest" ]; then
    if [ "$latest" = "$TRIGGER" ] && [ $injected -eq 0 ] && [ "$MODE" = "skim" ]; then
      cast rpc anvil_setBalance $SYA 0xDE0B6B3A7640000 --rpc-url $RPC >/dev/null
      h=$(cast send $YS_DOLA "skimSurplus(address,address)" $DOLA $CLAIMER --from $SYA --unlocked \
          --legacy --gas-price 250000000 --gas-limit 2000000 --async --rpc-url $RPC 2>>"$LOG")
      echo "INJECT skimSurplus(DOLA, claimer) as SYA tx=$h at OWNER latest nonce $latest" >> "$LOG"
      injected=1
    fi
    cast rpc evm_mine --rpc-url $RPC >/dev/null
    echo "mined block $(cast block-number --rpc-url $RPC) (OWNER latest nonce was $latest)" >> "$LOG"
  fi
  sleep 0.2
done
