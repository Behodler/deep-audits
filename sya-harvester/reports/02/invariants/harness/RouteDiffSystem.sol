// SPDX-License-Identifier: MIT
// AUDIT-AUTHORED (sya-harvester-02 invariant-generator). Not part of the upstream suite.
pragma solidity 0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";

import {SYAHarvester} from "../../../src/SYAHarvester.sol";
import {ICurveRouterNG} from "../../../src/interfaces/ICurveRouterNG.sol";
import {SYAHarvesterMutantNoGap} from "../mutants/SYAHarvesterMutantNoGap.sol";
import {SYAHarvesterMutantNoEnd} from "../mutants/SYAHarvesterMutantNoEnd.sol";
import {MockSYA} from "../../mocks/MockSYA.sol";
import {InvToken, InvStrategy, InvActor} from "./InvDoubles.sol";
import {RouterNGv11Model, CurvePoolModel} from "./RouterNGv11Model.sol";

/// @notice Holds tokens like the harvester would and executes a STORED route against the Router NG v1.1
///         model, so the system can observe exactly which tokens the router delivers to a receiver.
contract RouteProbe {
    function run(RouterNGv11Model router, SYAHarvester.CurveRoute memory r, uint256 amt)
        external
        returns (bool ok, bytes memory err, uint256 out)
    {
        (bool a,) = r.path[0].call(abi.encodeCall(IERC20.approve, (address(router), amt)));
        a;
        try router.exchange(r.path, r.swapParams, amt, 0, r.pools, address(this)) returns (uint256 o) {
            return (true, "", o);
        } catch (bytes memory e) {
            return (false, e, 0);
        }
    }
}

/// @notice Differential route system (run-02, src @ 6b862aa, story-007 validator).
///         P1 (delivery): setRoute accepts => the Router NG v1.1 model, executing the STORED route, either
///            reverts or delivers ONLY sya.rewardToken() to the receiver (checked with a probe on every
///            accepted route, over arbitrary fuzzed path / swapParams / pools).
///         P2 (no residue): the harvester never holds any route / intermediate token beyond third-party
///            donations, over sequences of setRoute / clearRoute / harvest / donations; after a successful
///            harvest every non-exempt strategy token and the reward token are at zero.
///         P3 (spec): setRoute's accept/reject decision AND error selector equal an independent transcription
///            of the story-007 specification (order: ZeroAddress, Start, Gap, Token, End, per-hop SwapParams/Pools).
///         P4 (swap_type >= 9): a route whose executed row has swap_type >= 9 is ACCEPTED, the probe reverts
///            Error("Bad swap type") and a harvest selling that token reverts (fail-loud, nothing moves).
///         P5 (stored == input): an accepted route is stored verbatim.
contract RouteDiffSystem {
    Vm internal constant hvm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant JUNK = address(0xDEAD0001); // codeless

    uint8 public immutable variant; // 0 real harvester, 1 mutant no-gap-check, 2 mutant no-end-check

    IPoolManager public manager;
    SYAHarvester public harvester;
    MockSYA public sya;
    RouterNGv11Model public router;
    RouteProbe public probe;
    InvActor public actor;
    PoolKey public ethKey;

    // tokens: 0 R(USDC,6) 1 T(USDe,18) 2 U(DOLA,18) 3 X1(crvUSD) 4 X2(FRAX) 5 Y(no pool)
    InvToken[6] public tok;
    uint256 public constant NT = 6;
    CurvePoolModel[7] public pools;
    InvStrategy[3] public strategies; // T, U, R
    address public syaReward;

    // ---- ghosts ----
    uint256 public constant V_DELIVERY = 0; // P1
    uint256 public constant V_RESIDUE = 1; // P2
    uint256 public constant V_SPEC = 2; // P3
    uint256 public constant V_SWAPTYPE = 3; // P4
    uint256 public constant V_STORED = 4; // P5
    uint256 public constant V_ETH = 5; // harvester ETH != 0 / caller ETH delta != ethOut
    uint256 public constant NV = 6;
    uint256[6] public violations;
    string public lastNote;

    uint256[6] public donated; // per token, harvester donations not yet consumed
    uint256 public routesAccepted;
    uint256 public routesRejected;
    uint256[6] public acceptedByK;
    uint256 public probesDelivered;
    uint256 public probesReverted;
    uint256 public harvestCalls;
    uint256 public harvestOk;
    uint256 public harvestOkFuzzedRoute; // success while a non-seed route was live and used
    uint256 public swapTypeChecks;
    uint256 public swapTypeHarvestReverts;
    mapping(address => bool) public fuzzedLive; // token's stored route is not the seed route
    bytes4 public lastSpecErr;
    bytes4 public lastGotErr;

    struct Route {
        address[11] path;
        uint256[5][5] sp;
        address[5] pl;
    }

    constructor(uint8 _variant) payable {
        variant = _variant;
        hvm.deal(address(this), 1_000_000 ether);
        manager = IPoolManager(address(new PoolManager(address(this))));
        PoolModifyLiquidityTest lp = new PoolModifyLiquidityTest(manager);

        tok[0] = new InvToken("USDC", 6);
        tok[1] = new InvToken("USDe", 18);
        tok[2] = new InvToken("DOLA", 18);
        tok[3] = new InvToken("crvUSD", 18);
        tok[4] = new InvToken("FRAX", 18);
        tok[5] = new InvToken("Y", 18);

        ethKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tok[0])),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        manager.initialize(ethKey, SQRT_PRICE_1_1);
        tok[0].mint(address(this), 1e30);
        tok[0].approve(address(lp), type(uint256).max);
        lp.modifyLiquidity{value: 100 ether}(
            ethKey, IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e20, salt: 0}), ""
        );

        // pools: P0[T,R] P1[T,X1] P2[X1,R] P3[U,R] P4[X1,X2,R] P5[U,X2] P6[T,U] (P2,P4 with underlying)
        pools[0] = _pool(1, 0, 99, false);
        pools[1] = _pool(1, 3, 99, false);
        pools[2] = _pool(3, 0, 99, true);
        pools[3] = _pool(2, 0, 99, false);
        pools[4] = _pool(3, 4, 0, true);
        pools[5] = _pool(2, 4, 99, false);
        pools[6] = _pool(1, 2, 99, false);

        sya = new MockSYA(address(tok[0]));
        syaReward = address(tok[0]);
        router = new RouterNGv11Model();
        probe = new RouteProbe();

        if (_variant == 0) {
            harvester = new SYAHarvester(address(this), manager, IStableYieldAccumulator(address(sya)), ICurveRouterNG(address(router)));
        } else if (_variant == 1) {
            harvester = SYAHarvester(payable(address(new SYAHarvesterMutantNoGap(address(this), manager, IStableYieldAccumulator(address(sya)), ICurveRouterNG(address(router))))));
        } else {
            harvester = SYAHarvester(payable(address(new SYAHarvesterMutantNoEnd(address(this), manager, IStableYieldAccumulator(address(sya)), ICurveRouterNG(address(router))))));
        }

        strategies[0] = new InvStrategy(address(tok[1]));
        strategies[1] = new InvStrategy(address(tok[2]));
        strategies[2] = new InvStrategy(address(tok[0]));
        for (uint256 i = 0; i < 3; i++) sya.addYieldStrategy(address(strategies[i]), strategies[i].token());
        strategies[0].set(1000e18, 10000);
        strategies[1].set(500e18, 10000);
        strategies[2].set(200e6, 10000);

        harvester.setEthPool(ethKey);
        // seed routes: T direct via P0, U 2-hop via P5 (U->X2) then P4 (X2->R)
        Route memory rt;
        rt.path[0] = address(tok[1]);
        rt.path[1] = address(pools[0]);
        rt.path[2] = address(tok[0]);
        rt.sp[0] = [uint256(0), 1, 1, 10, 2];
        harvester.setRoute(address(tok[1]), rt.path, rt.sp, rt.pl);
        Route memory ru;
        ru.path[0] = address(tok[2]);
        ru.path[1] = address(pools[5]);
        ru.path[2] = address(tok[4]);
        ru.path[3] = address(pools[4]);
        ru.path[4] = address(tok[0]);
        ru.sp[0] = [uint256(0), 1, 1, 20, 2];
        ru.sp[1] = [uint256(1), 2, 1, 30, 3];
        harvester.setRoute(address(tok[2]), ru.path, ru.sp, ru.pl);
        // anti-vacuity: routes really stored
        require(harvester.getRoute(address(tok[1])).configured && harvester.getRoute(address(tok[1])).path[1] == address(pools[0]), "seed T");
        require(harvester.getRoute(address(tok[2])).configured && harvester.getRoute(address(tok[2])).path[3] == address(pools[4]), "seed U");

        actor = new InvActor();
    }

    receive() external payable {}

    function _pool(uint256 a, uint256 b, uint256 c, bool und) internal returns (CurvePoolModel p) {
        uint256 n = c == 99 ? 2 : 3;
        address[] memory cs = new address[](n);
        uint8[] memory ds = new uint8[](n);
        cs[0] = address(tok[a]);
        cs[1] = address(tok[b]);
        ds[0] = tok[a].decimals();
        ds[1] = tok[b].decimals();
        if (n == 3) {
            cs[2] = address(tok[c]);
            ds[2] = tok[c].decimals();
        }
        p = new CurvePoolModel(cs, ds, und);
        for (uint256 i = 0; i < n; i++) InvToken(cs[i]).mint(address(p), ds[i] == 6 ? 1e30 : 1e42);
    }

    // =====================================================================
    //                              ALPHABETS
    // =====================================================================

    function _anyToken(uint256 s) internal view returns (address) {
        uint256 x = s % 8;
        if (x < 6) return address(tok[x]);
        if (x == 6) return ETH_ADDR;
        return address(0);
    }

    function _anyPoolSlot(uint256 s) internal view returns (address) {
        uint256 x = s % 12;
        if (x < 7) return address(pools[x]);
        if (x == 7) return JUNK;
        if (x == 8) return address(router);
        if (x == 9) return address(tok[s / 12 % 6]); // a token used as a "pool"
        return address(0);
    }

    function _anyAddr(uint256 s) internal view returns (address) {
        return s % 2 == 0 ? _anyToken(s >> 1) : _anyPoolSlot(s >> 1);
    }

    // =====================================================================
    //                          ROUTE GENERATION
    // =====================================================================

    /// Graph walk over the pool set from `token`, up to `hops` hops, preferring a pool holding R on the
    /// final hop; then optional single-field mutations.
    function _genStructured(address token, uint256 seed) internal view returns (Route memory r) {
        r.path[0] = token;
        address cur = token;
        uint256 hops = 1 + seed % 5;
        seed >>= 3;
        uint256 h;
        for (h = 0; h < hops; h++) {
            bool last = h + 1 == hops;
            (CurvePoolModel p, uint256 i) = _pickPool(cur, seed, last);
            seed >>= 8;
            if (address(p) == address(0)) break;
            uint256 n = p.nCoins();
            uint256 j;
            (bool hasR, uint256 ir) = p.coinIndex(address(tok[0]));
            if (last && hasR && ir != i) j = ir;
            else j = (i + 1 + seed % (n - 1)) % n;
            seed >>= 4;
            r.path[2 * h + 1] = address(p);
            r.path[2 * h + 2] = p.coins(j);
            uint256 pt = [uint256(1), 10, 2, 20, 30][seed % 5];
            seed >>= 3;
            uint256 st = seed % 16 == 0 ? 2 : 1;
            seed >>= 4;
            r.sp[h] = [i, j, st, pt, n];
            cur = p.coins(j);
        }
        // mutations
        uint256 m = seed % 6;
        seed >>= 3;
        for (uint256 q = 0; q < m && q < 3; q++) {
            uint256 kind = seed % 4;
            seed >>= 2;
            uint256 idx = seed;
            seed >>= 8;
            if (kind == 0) r.path[1 + idx % 10] = _anyAddr(seed);
            else if (kind == 1) r.sp[idx % 5][(idx >> 3) % 5] = _smallOrHuge(seed);
            else if (kind == 2) r.pl[idx % 5] = _anyAddr(seed);
            else r.path[1 + idx % 10] = address(0);
            seed >>= 16;
        }
    }

    function _smallOrHuge(uint256 s) internal pure returns (uint256) {
        if (s % 7 == 0) return type(uint256).max - (s >> 8) % 3;
        return (s >> 3) % 13;
    }

    function _pickPool(address cur, uint256 seed, bool last) internal view returns (CurvePoolModel, uint256) {
        CurvePoolModel[7] memory c;
        uint256[7] memory ix;
        uint256 n;
        int256 rPick = -1;
        for (uint256 p = 0; p < 7; p++) {
            (bool f, uint256 i) = pools[p].coinIndex(cur);
            if (!f) continue;
            (bool hasR,) = pools[p].coinIndex(address(tok[0]));
            if (last && hasR && cur != address(tok[0]) && rPick < 0) rPick = int256(n);
            c[n] = pools[p];
            ix[n] = i;
            n++;
        }
        if (n == 0) return (CurvePoolModel(address(0)), 0);
        uint256 pick = (rPick >= 0 && seed % 4 != 0) ? uint256(rPick) : seed % n;
        return (c[pick], ix[pick]);
    }

    function _genRandom(address token, uint256 seed) internal view returns (Route memory r) {
        r.path[0] = token;
        for (uint256 i = 1; i < 11; i++) {
            uint256 s = uint256(keccak256(abi.encode(seed, i)));
            r.path[i] = s % 3 == 0 ? address(0) : (i % 2 == 1 ? _anyPoolSlot(s >> 2) : _anyToken(s >> 2));
        }
        uint256 s2 = uint256(keccak256(abi.encode(seed, "sp")));
        for (uint256 h = 0; h < 5; h++) {
            if ((s2 >> h) & 1 == 1) r.sp[h] = [(s2 >> 8) % 3, (s2 >> 12) % 3, (s2 >> (16 + h)) % 10, uint256(10), 2];
        }
        if (s2 % 5 == 0) r.pl[(s2 >> 40) % 5] = _anyAddr(s2 >> 50);
    }

    // =====================================================================
    //                              ACTIONS
    // =====================================================================

    /// Owner registers an arbitrary (fuzzed) route. Every outcome is checked.
    function act_setRouteFuzz(uint8 tokSel, uint256 seed, bool structured) public {
        address token = _routeToken(tokSel);
        Route memory r = structured ? _genStructured(token, seed) : _genRandom(token, seed);
        _tryRoute(token, r, false);
    }

    /// Owner registers a structurally valid route with swap_type >= 9 on one executed row (P4).
    function act_setRouteBadSwapType(uint8 tokSel, uint256 st, uint8 rowSeed) public {
        address token = tokSel % 2 == 0 ? address(tok[1]) : address(tok[2]);
        Route memory r;
        r.path[0] = token;
        uint256 k;
        if (token == address(tok[1])) {
            r.path[1] = address(pools[0]);
            r.path[2] = address(tok[0]);
            r.sp[0] = [uint256(0), 1, 1, 10, 2];
            k = 1;
        } else {
            r.path[1] = address(pools[5]);
            r.path[2] = address(tok[4]);
            r.path[3] = address(pools[4]);
            r.path[4] = address(tok[0]);
            r.sp[0] = [uint256(0), 1, 1, 20, 2];
            r.sp[1] = [uint256(1), 2, 1, 30, 3];
            k = 2;
        }
        uint256 bad = st % 3 == 0 ? 9 : (st % 3 == 1 ? 9 + (st >> 2) % 100 : type(uint256).max - (st >> 2) % 1000);
        if (bad < 9) bad = 9;
        r.sp[rowSeed % k][2] = bad;
        swapTypeChecks++;
        bool accepted = _tryRoute(token, r, true);
        if (!accepted) {
            _flag(V_SWAPTYPE, "swap_type>=9 route rejected (validator changed: update CODE-02-001)");
            return;
        }
        // harvest selling exactly that token must revert; balances must not move
        uint256 sIdx = token == address(tok[1]) ? 0 : 1;
        if (strategies[sIdx].pendingDelivery() < 1e15) strategies[sIdx].set(100 * 1e18, 10000);
        uint8 mask = sIdx == 0 ? 2 : 1; // exempt the OTHER yield token (bit0 = T, bit1 = U, bit2 = R)
        (bool ok, bytes memory ret,) = _harvest(mask, 0);
        if (ok) _flag(V_SWAPTYPE, "harvest succeeded through a swap_type>=9 row");
        else if (keccak256(ret) != keccak256(abi.encodeWithSignature("Error(string)", "Bad swap type"))) {
            _flag(V_SWAPTYPE, "harvest reverted, but not with Error(Bad swap type)");
        } else {
            swapTypeHarvestReverts++;
        }
    }

    function act_clearRoute(uint8 tokSel) public {
        address token = _routeToken(tokSel);
        harvester.clearRoute(token);
        fuzzedLive[token] = false;
    }

    function act_setYield(uint8 s, uint256 amount, uint16 bpsSeed) public {
        uint256 i = s % 3;
        uint256 d = i == 2 ? 6 : 18;
        amount = amount % 10 == 0 ? amount % 1e6 : amount % (20_000 * 10 ** d);
        strategies[i].set(amount, 5000 + uint256(bpsSeed) % 5001);
    }

    /// Third-party donation of any alphabet token to the harvester (tracked) or to the router (untracked).
    function act_donate(uint8 tokSel, uint256 amount, bool toRouter) public {
        uint256 t = tokSel % NT;
        amount = amount % 4 == 0 ? 1 : amount % (t == 0 ? 1e9 : 1e21);
        if (amount == 0) amount = 1;
        if (toRouter) {
            tok[t].mint(address(router), amount);
        } else {
            tok[t].mint(address(harvester), amount);
            donated[t] += amount;
        }
    }

    function act_harvest(uint8 exemptMask, uint256 minSeed) public {
        _harvest(exemptMask, minSeed % 3 == 0 ? 0 : minSeed % 1e9);
    }

    // =====================================================================
    //                              INTERNALS
    // =====================================================================

    function _routeToken(uint8 s) internal view returns (address) {
        uint256 x = s % 8;
        if (x < 3) return address(tok[1]);
        if (x < 6) return address(tok[2]);
        if (x == 6) return address(tok[0]); // reward-token route (k = 0 case)
        return address(tok[3]); // non-strategy token
    }

    function _tryRoute(address token, Route memory r, bool expectAccept) internal returns (bool accepted) {
        bytes4 spec = _specErr(token, r);
        bytes4 got;
        try harvester.setRoute(token, r.path, r.sp, r.pl) {
            accepted = true;
        } catch (bytes memory e) {
            got = e.length >= 4 ? bytes4(e) : bytes4(0xffffffff);
        }
        if (got != spec) {
            lastSpecErr = spec;
            lastGotErr = got;
            _flag(V_SPEC, "setRoute decision/selector differs from story-007 spec transcription");
        }
        if (!accepted) {
            routesRejected++;
            return false;
        }
        routesAccepted++;
        uint256 k;
        while (k < 5 && r.path[2 * k + 1] != address(0)) k++;
        acceptedByK[k]++;
        SYAHarvester.CurveRoute memory s = harvester.getRoute(token);
        if (!s.configured || keccak256(abi.encode(s.path, s.swapParams, s.pools)) != keccak256(abi.encode(r.path, r.sp, r.pl))) {
            _flag(V_STORED, "stored route != input route");
        }
        fuzzedLive[token] = true;
        _probe(token, s, expectAccept);
    }

    /// P1: execute the stored route from the probe; only the reward token may arrive.
    function _probe(address token, SYAHarvester.CurveRoute memory s, bool expectBadSwapType) internal {
        if (token == ETH_ADDR) return;
        uint256 amt = token == address(tok[0]) ? 1000e6 : 1000e18;
        InvToken(token).mint(address(probe), amt);
        uint256[6] memory pre;
        for (uint256 t = 0; t < NT; t++) pre[t] = tok[t].balanceOf(address(probe));
        uint256 ethPre = address(probe).balance;
        (bool ok, bytes memory err, uint256 out) = probe.run(router, s, amt);
        for (uint256 t = 0; t < NT; t++) {
            uint256 post = tok[t].balanceOf(address(probe));
            if (!ok) {
                if (post != pre[t]) _flag(V_DELIVERY, "reverted probe moved balances");
                continue;
            }
            if (address(tok[t]) == syaReward) {
                if (post != pre[t] - (token == syaReward ? amt : 0) + out || out == 0) {
                    _flag(V_DELIVERY, "reward delivery != returned amount");
                }
            } else if (address(tok[t]) == token) {
                if (post != pre[t] - amt) _flag(V_DELIVERY, "input not fully consumed");
            } else if (post != pre[t]) {
                _flag(V_DELIVERY, "accepted route delivered a NON-reward token to the receiver");
            }
        }
        if (address(probe).balance != ethPre) _flag(V_DELIVERY, "accepted route delivered ETH");
        if (ok) probesDelivered++;
        else probesReverted++;
        if (expectBadSwapType) {
            if (ok || keccak256(err) != keccak256(abi.encodeWithSignature("Error(string)", "Bad swap type"))) {
                _flag(V_SWAPTYPE, "probe of swap_type>=9 route did not revert Bad swap type");
            }
        }
        // return probe input leftovers are irrelevant: probe balances are only compared as deltas
    }

    function _harvest(uint8 exemptMask, uint256 minEthOut) internal returns (bool ok, bytes memory ret, uint256 ethOut) {
        harvestCalls++;
        uint256 m = exemptMask % 8;
        uint256 n;
        for (uint256 i = 0; i < 3; i++) if (m & (1 << i) != 0) n++;
        address[] memory ex = new address[](n);
        uint256 c;
        for (uint256 i = 0; i < 3; i++) if (m & (1 << i) != 0) ex[c++] = address(strategies[i]);
        bool usedFuzzed = (m & 1 == 0 && fuzzedLive[address(tok[1])] && strategies[0].pendingDelivery() > 0)
            || (m & 2 == 0 && fuzzedLive[address(tok[2])] && strategies[1].pendingDelivery() > 0);

        uint256[6] memory pre;
        for (uint256 t = 0; t < NT; t++) pre[t] = tok[t].balanceOf(address(harvester));
        uint256 aEth = address(actor).balance;
        (ok, ret, ethOut) = actor.doHarvest(harvester, ex, 0, minEthOut);
        if (!ok) {
            for (uint256 t = 0; t < NT; t++) {
                if (tok[t].balanceOf(address(harvester)) != pre[t]) _flag(V_RESIDUE, "reverted harvest moved harvester balances");
            }
            return (ok, ret, ethOut);
        }
        harvestOk++;
        if (usedFuzzed) harvestOkFuzzedRoute++;
        // consumed by a successful harvest: reward token, and every non-exempt strategy token
        donated[0] = 0;
        if (m & 1 == 0) donated[1] = 0;
        if (m & 2 == 0) donated[2] = 0;
        _checkResidue();
        if (address(harvester).balance != 0) _flag(V_ETH, "harvester ETH != 0 after success");
        if (address(actor).balance != aEth + ethOut) _flag(V_ETH, "caller ETH delta != ethOut");
        if (ethOut < minEthOut) _flag(V_ETH, "ethOut < minEthOut");
    }

    function _checkResidue() internal {
        for (uint256 t = 0; t < NT; t++) {
            if (tok[t].balanceOf(address(harvester)) != donated[t]) {
                _flag(V_RESIDUE, "harvester holds route/intermediate token beyond donations");
            }
        }
    }

    /// P2 as a pure state predicate (checked after every call by forge/medusa)
    function residueClean() public view returns (bool) {
        for (uint256 t = 0; t < NT; t++) {
            if (tok[t].balanceOf(address(harvester)) != donated[t]) return false;
        }
        return address(harvester).balance == 0;
    }

    // ---------------------------------------------------------------------
    // Independent transcription of the story-007 setRoute specification (NOT copied from src):
    // ZeroAddress; Start; Gap (path[2k+1..10] zero); Token (path[2i] != 0, 0<i<k); End (path[2k] == reward);
    // per hop h=0..4: h<k -> swap_type != 0 else SwapParams(h); h>=k -> row all zero else SwapParams(h),
    // pools[h] == 0 else Pools(h).
    // ---------------------------------------------------------------------
    function _specErr(address token, Route memory r) internal view returns (bytes4) {
        if (token == address(0)) return SYAHarvester.ZeroAddress.selector;
        if (r.path[0] != token) return SYAHarvester.InvalidRouteStart.selector;
        uint256 k;
        for (uint256 h = 0; h < 5; h++) {
            if (r.path[2 * h + 1] == address(0)) break;
            k = h + 1;
        }
        for (uint256 i = 2 * k + 1; i <= 10; i++) if (r.path[i] != address(0)) return SYAHarvester.InvalidRouteGap.selector;
        for (uint256 i = 1; i < k; i++) if (r.path[2 * i] == address(0)) return SYAHarvester.InvalidRouteToken.selector;
        if (r.path[2 * k] != syaReward) return SYAHarvester.InvalidRouteEnd.selector;
        for (uint256 h = 0; h < 5; h++) {
            if (h < k) {
                if (r.sp[h][2] == 0) return SYAHarvester.InvalidRouteSwapParams.selector;
            } else {
                for (uint256 f = 0; f < 5; f++) if (r.sp[h][f] != 0) return SYAHarvester.InvalidRouteSwapParams.selector;
                if (r.pl[h] != address(0)) return SYAHarvester.InvalidRoutePools.selector;
            }
        }
        return bytes4(0);
    }

    function _flag(uint256 kind, string memory note) internal {
        if (violations[kind] == 0) lastNote = note;
        violations[kind]++;
    }

    function v(uint256 i) external view returns (uint256) {
        return violations[i];
    }

    function rewardToken() external view returns (address) {
        return syaReward;
    }

    // ---------------- Medusa properties ----------------
    function property_delivery() public view returns (bool) { return violations[V_DELIVERY] == 0; }
    function property_noResidue() public view returns (bool) { return violations[V_RESIDUE] == 0 && residueClean(); }
    function property_specConformance() public view returns (bool) { return violations[V_SPEC] == 0; }
    function property_swapTypeFailLoud() public view returns (bool) { return violations[V_SWAPTYPE] == 0; }
    function property_storedEqualsInput() public view returns (bool) { return violations[V_STORED] == 0; }
    function property_ethPayout() public view returns (bool) { return violations[V_ETH] == 0; }
}

contract RouteDiffSystemReal is RouteDiffSystem {
    constructor() payable RouteDiffSystem(0) {}
}

/// Mutant: gap check deleted. P3 (strict spec) must kill it; P1/P2 measure whether the deletion is
/// safety-relevant (expected: NOT, because InvalidRouteEnd already checks the router-delivered path[2k]).
contract RouteDiffSystemMutantNoGap is RouteDiffSystem {
    constructor() payable RouteDiffSystem(1) {}
}

/// Mutant: end check deleted: P3 and P1/P2 must kill it (accepted route delivers a non-reward token).
contract RouteDiffSystemMutantNoEnd is RouteDiffSystem {
    constructor() payable RouteDiffSystem(2) {}
}
