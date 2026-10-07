#!/usr/bin/env bash
# run-21 tripwire mutant generator. Source: ../../src/dispatchers/UniPoolerV2.sol (== src/ @ 267660b).
# Each mutant is a renamed local copy; work/src and src/ are never modified.
set -euo pipefail
cd "$(dirname "$0")"
SRC=../../src/dispatchers/UniPoolerV2.sol
mk() { # name sed-expr
  local name=$1; shift
  { echo "// AUTO-GENERATED run-21 tripwire mutant ($name). DO NOT DEPLOY."; cat "$SRC"; } \
  | sed -e 's#from "\.\./#from "../../../src/#' -e 's#from "\./#from "../../../src/dispatchers/#' \
        -e "s/contract UniPoolerV2 is/contract UniPoolerV2_$name is/" "$@" > "mutants/UniPoolerV2_$name.sol"
}
# M1: drop sync() before sizing the zap (story-051 change 2, pool side)
mk M1_NoSync -e '/IUniswapV2Pair(_pair).sync();/d'
# M2: quotePool reads stored reserves instead of live balances (story-051 change 2, quote side)
mk M2_QuoteReserves -e 's/(uint256 rS, uint256 rP) = _balances();/(uint256 rS, uint256 rP) = _reserves();/'
# M3: drop the default-hook guard (story-051 change 1 / ycn20l21)
mk M3_NoHookGuard -e '/if (address(hook) == _defaultHook) revert UniPoolerV2__HookNotSet();/d'
# M4: rescueERC20 loses onlyOwner (LP leak path)
mk M4_OpenRescue -e 's/function rescueERC20(address token, address to, uint256 amount) external onlyOwner {/function rescueERC20(address token, address to, uint256 amount) external {/'
for f in mutants/*.sol; do echo "== $f"; diff "$SRC" <(tail -n +2 "$f" | sed -e 's#from "\.\./\.\./\.\./src/dispatchers/#from "./#' -e 's#from "\.\./\.\./\.\./src/#from "../#' -e 's/contract UniPoolerV2_[A-Za-z0-9_]* is/contract UniPoolerV2 is/') || true; done
