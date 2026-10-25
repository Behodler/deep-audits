// SPDX-License-Identifier: MIT
// AUDIT-AUTHORED (sya-harvester-01 invariant-generator). Not part of the upstream suite.
pragma solidity 0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {TransientStateLibrary} from "v4-core/src/libraries/TransientStateLibrary.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {IStableYieldAccumulator} from "stable-yield-accumulator/src/interfaces/IStableYieldAccumulator.sol";

import {SYAHarvester} from "../../../src/SYAHarvester.sol";
import {ICurveRouterNG} from "../../../src/interfaces/ICurveRouterNG.sol";
import {MockSYA} from "../../mocks/MockSYA.sol";
import {MockERC1155} from "../../mocks/MockERC1155.sol";
import {InvToken, RouterNGModel, InvStrategy, InvActor, ForceSend} from "./InvDoubles.sol";

/// @notice Stateful harvest system + handler. Runs unchanged under forge (targetContract) and Medusa
///         (property_* functions, constructor setup, no pranks).
/// @dev Safety properties are checked INSIDE act_harvest, in the same transaction as the harvest, so
///      V4 transient deltas are still readable; a breach increments a ghost counter that the
///      invariant_/property_ functions assert is zero.
contract HarvestSystem {
    using TransientStateLibrary for IPoolManager;

    Vm internal constant hvm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    // ---------------- configuration ----------------
    bool public immutable allowGapRoutes; // owner may register Router-NG-divergent routes (CODE-001 footgun)
    bool public immutable allowOverDelivery; // strategies may deliver > reported surplus (CODE-005)
    bool public immutable allowDust; // griefer donations (CODE-002)

    // ---------------- system ----------------
    IPoolManager public manager;
    PoolModifyLiquidityTest public lpRouter;
    SYAHarvester public harvester;
    MockSYA public sya;
    RouterNGModel public router;
    MockERC1155 public nft;
    InvToken public usdc;
    InvToken public usde;
    InvToken public dola;
    InvToken public crvusd; // intermediate hop token, NOT a strategy token
    InvStrategy[3] public strategies; // usde, dola, usdc
    InvActor[3] public actors;
    PoolKey public ethKey;

    address public constant POOL_USDE_USDC = address(0xA001);
    address public constant POOL_USDE_CRV = address(0xA002);
    address public constant POOL_CRV_USDC = address(0xA003);
    address public constant POOL_DOLA_USDC = address(0xA004);
    address public constant POOL_DOLA_CRV = address(0xA005);
    address public constant GRIEFER = address(0xBAD);

    // ---------------- ghosts ----------------
    uint256 public constant V_STATELESS = 0; // non-exempt strategy token / reward / ETH left after success
    uint256 public constant V_STRANDED = 1; // any token balance of the harvester INCREASED across a success
    uint256 public constant V_MIN_ETH_OUT = 2; // caller got < minEthOut, or ETH gained != returned ethOut
    uint256 public constant V_V4_DELTAS = 3; // nonzero delta count / harvester currency delta != 0
    uint256 public constant V_CONSERVATION = 4; // token or ETH created/destroyed across a harvest
    uint256 public constant V_SYA_PAYMENT = 5; // SYA balance delta != its computed payment
    uint256 public constant V_ALLOWANCE = 6; // residual harvester allowance to SYA or router
    uint256 public constant V_NFT = 7; // harvester holds NFT units / caller NFT delta wrong
    uint256 public constant L_DUST_GRIEF = 8; // revert caused by dust of a non-delivering token (CODE-002)
    uint256 public constant L_OVER_DELIVERY = 9; // revert on SYA allowance pull (CODE-005)
    uint256 public constant L_OTHER = 10; // any other unexplained revert
    uint256 public constant L_DUST_NATURAL = 11; // router dust revert on a strategy's own tiny delivery (CODE-002 natural)
    uint256 public constant N_GHOSTS = 12;

    uint256[12] public violations;
    uint256 public harvestCalls;
    uint256 public harvestSuccesses;
    uint256 public harvestExpectedReverts;
    bytes4 public lastUnexpectedSelector;
    bytes public lastUnexpectedRevert;
    string public lastViolationNote;

    // fuzz-relevant state
    bool public gapRoutePresent; // any stored route is Router-NG-divergent
    bool public rateShockActive; // any pool rate set below 90%
    mapping(uint256 => bytes4) public firstViolationSelector;

    constructor(bool _gap, bool _over, bool _dust) payable {
        allowGapRoutes = _gap;
        allowOverDelivery = _over;
        allowDust = _dust;
        hvm.deal(address(this), 1_000_000 ether);

        manager = IPoolManager(address(new PoolManager(address(this))));
        lpRouter = new PoolModifyLiquidityTest(manager);

        usdc = new InvToken("USDC", 6);
        usde = new InvToken("USDe", 18);
        dola = new InvToken("DOLA", 18);
        crvusd = new InvToken("crvUSD", 18);

        // Native-ETH / USDC V4 pool, raw 1:1, deep liquidity (mirrors HarvesterFixture)
        ethKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(usdc)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        manager.initialize(ethKey, SQRT_PRICE_1_1);
        usdc.mint(address(this), 1e30);
        usdc.approve(address(lpRouter), type(uint256).max);
        lpRouter.modifyLiquidity{value: 100 ether}(
            ethKey, IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e20, salt: 0}), ""
        );

        sya = new MockSYA(address(usdc));
        router = new RouterNGModel();
        usdc.mint(address(router), 1e30);
        crvusd.mint(address(router), 1e40);
        // 18-dec -> 6-dec at 1:1 value, 18 -> 18 at 1:1
        router.setRate(POOL_USDE_USDC, address(usde), address(usdc), 1e6);
        router.setRate(POOL_USDE_CRV, address(usde), address(crvusd), 1e18);
        router.setRate(POOL_CRV_USDC, address(crvusd), address(usdc), 1e6);
        router.setRate(POOL_DOLA_USDC, address(dola), address(usdc), 1e6);
        router.setRate(POOL_DOLA_CRV, address(dola), address(crvusd), 1e18);

        harvester = new SYAHarvester(
            address(this), manager, IStableYieldAccumulator(address(sya)), ICurveRouterNG(address(router))
        );

        nft = new MockERC1155();
        nft.setAuthorizedBurner(address(sya), true);
        sya.setNFTMinter(address(nft));
        sya.setNftMode(MockSYA.NftMode.Burn); // live behaviour by default

        strategies[0] = new InvStrategy(address(usde));
        strategies[1] = new InvStrategy(address(dola));
        strategies[2] = new InvStrategy(address(usdc));
        for (uint256 i = 0; i < 3; i++) {
            sya.addYieldStrategy(address(strategies[i]), strategies[i].token());
        }
        // Realistic seeded state (vacuity guard): every strategy has pending yield from block 0
        strategies[0].set(1000e18, 10000);
        strategies[1].set(500e18, 10000);
        strategies[2].set(200e6, 10000);

        harvester.setEthPool(ethKey);
        harvester.setRoute(address(usde), _routeShape(address(usde), 0), _params(), _pools());
        harvester.setRoute(address(dola), _routeShape(address(dola), 1), _params(), _pools());

        for (uint256 i = 0; i < 3; i++) {
            actors[i] = new InvActor();
            actors[i].approveNft(address(nft), address(harvester));
            nft.mint(address(actors[i]), 1, 5);
        }
    }

    receive() external payable {}

    // =====================================================================
    //                              ACTIONS
    // =====================================================================

    /// @notice Set a strategy's pending yield and how much of it skimSurplus really delivers
    function act_setYield(uint8 stratSeed, uint256 amount, uint16 deliverSeed) public {
        uint256 s = stratSeed % 3;
        uint8 d = s == 2 ? 6 : 18;
        // 0 .. 20k units of value; occasionally tiny (natural sub-dust yield)
        amount = amount % 10 == 0 ? amount % 1e6 : amount % (20_000 * 10 ** d);
        uint256 maxBps = allowOverDelivery ? 12000 : 10000;
        uint256 bps = 5000 + uint256(deliverSeed) % (maxBps - 5000 + 1);
        strategies[s].set(amount, bps);
    }

    /// @notice SYA over-estimate knob (live calculateClaimAmount over-estimates for some strategies)
    function act_setOverEstimate(uint16 bps) public {
        sya.setOverEstimateBps(uint256(bps) % 1500);
    }

    /// @notice Owner (re)registers a route. Honest config: Router-NG-contiguous shapes only.
    function act_setRoute(uint8 tokenSeed, uint8 shapeSeed) public {
        address t = tokenSeed % 2 == 0 ? address(usde) : address(dola);
        uint8 nShapes = allowGapRoutes ? 5 : 2;
        uint8 shape = shapeSeed % nShapes;
        harvester.setRoute(t, _routeShape(t, shape), _params(), _pools());
        _refreshGapFlag();
    }

    /// @notice Owner clears a route (obvious owner action; resulting RouteNotConfigured is expected)
    function act_clearRoute(uint8 tokenSeed) public {
        address t = tokenSeed % 2 == 0 ? address(usde) : address(dola);
        harvester.clearRoute(t);
        _refreshGapFlag();
    }

    /// @notice Market move on a Curve pool, 50%..150% of par
    function act_shockRate(uint8 poolSeed, uint16 bpsSeed) public {
        uint256 bps = 5000 + uint256(bpsSeed) % 10001;
        uint256 p = poolSeed % 5;
        if (p == 0) router.setRate(POOL_USDE_USDC, address(usde), address(usdc), 1e6 * bps / 10000);
        if (p == 1) router.setRate(POOL_USDE_CRV, address(usde), address(crvusd), 1e18 * bps / 10000);
        if (p == 2) router.setRate(POOL_CRV_USDC, address(crvusd), address(usdc), 1e6 * bps / 10000);
        if (p == 3) router.setRate(POOL_DOLA_USDC, address(dola), address(usdc), 1e6 * bps / 10000);
        if (p == 4) router.setRate(POOL_DOLA_CRV, address(dola), address(crvusd), 1e18 * bps / 10000);
        // Any adverse move counts: multi-hop shocks COMPOUND (0.914 x 0.935 = 0.855 < 0.90 discount),
        // so a per-pool 90% threshold misclassified the intended loud underflow (medusa run-1 artefact).
        if (bps < 10000) rateShockActive = true;
    }

    /// @notice SYA NFT gating: Burn (live) or Ignore (post-gating-off)
    function act_setNftMode(bool burn) public {
        sya.setNftMode(burn ? MockSYA.NftMode.Burn : MockSYA.NftMode.Ignore);
    }

    /// @notice Third-party donation to the harvester (tokens, NFT strays, forced ETH)
    function act_donate(uint8 what, uint256 amount) public {
        if (!allowDust) return;
        uint256 w = what % 6;
        amount = amount % 4 == 0 ? 1 : amount % 1e13; // mostly dust
        if (amount == 0) amount = 1;
        if (w == 0) usde.mint(address(harvester), amount);
        if (w == 1) dola.mint(address(harvester), amount);
        if (w == 2) usdc.mint(address(harvester), amount % 1e7 + 1);
        if (w == 3) crvusd.mint(address(harvester), amount);
        if (w == 4) nft.mint(address(harvester), 1, 1);
        if (w == 5) new ForceSend{value: amount % 1e12 + 1}(payable(address(harvester)));
    }

    struct Snap {
        uint256[4] h; // harvester token balances usdc, usde, dola, crv
        uint256[4] sum; // total of every tracked holder, per token
        uint256 hEth;
        uint256 aEth;
        uint256 pmEth;
        uint256 syaUsdc;
        uint256 syaCollected;
        uint256 aNft;
        uint256 hNft;
    }

    /// @notice Public harvest by one of three actors
    function act_harvest(uint8 actorSeed, uint8 exemptMask, uint256 minSeed, bool withNft) public {
        harvestCalls++;
        InvActor a = actors[actorSeed % 3];
        address[] memory ex = _exempt(exemptMask);
        uint256 idx = withNft ? 1 : 0;
        if (nft.balanceOf(address(a), 1) == 0) nft.mint(address(a), 1, 3);
        uint256 minEthOut = minSeed % 3 == 0 ? 0 : minSeed % 2e9; // typical ethOut ~1e8..2e10 wei at raw 1:1

        // pre-classification inputs for liveness
        bool[3] memory isEx;
        for (uint256 i = 0; i < ex.length; i++) {
            for (uint256 s = 0; s < 3; s++) if (ex[i] == address(strategies[s])) isEx[s] = true;
        }
        bool overDelivery = sya.calculateClaimAmount(ex) * 10100 / 10000 < _paymentIfClaimed(isEx);
        // "donated" = a third-party balance is present AND no strategy's own delivery is sub-dust by itself
        // (a natural 0 < delivery < 1e12 wei 18-dec yield rounds to 0 USDC-wei in the model router)
        bool naturalDust = (!isEx[0] && strategies[0].pendingDelivery() > 0 && strategies[0].pendingDelivery() < 1e12)
            || (!isEx[1] && strategies[1].pendingDelivery() > 0 && strategies[1].pendingDelivery() < 1e12);
        bool donated = !naturalDust
            && ((!isEx[0] && usde.balanceOf(address(harvester)) > 0) || (!isEx[1] && dola.balanceOf(address(harvester)) > 0));

        Snap memory pre = _snap(a);
        (bool ok, bytes memory ret, uint256 ethOut) = a.doHarvest(harvester, ex, idx, minEthOut);

        if (ok) {
            harvestSuccesses++;
            _checkSuccess(a, pre, ethOut, minEthOut, isEx, idx);
        } else {
            _classifyRevert(ret, isEx, overDelivery, donated);
        }
    }

    // =====================================================================
    //                     POST-HARVEST SAFETY CHECKS
    // =====================================================================

    function _checkSuccess(InvActor a, Snap memory pre, uint256 ethOut, uint256 minEthOut, bool[3] memory isEx, uint256 idx)
        internal
    {
        Snap memory post = _snap(a);

        // (1) stateless: reward token, ETH and every NON-EXEMPT strategy token at zero
        if (post.h[0] != 0) _flag(V_STATELESS, "harvester USDC != 0 after success");
        if (!isEx[0] && post.h[1] != 0) _flag(V_STATELESS, "harvester USDe != 0 after success (non-exempt)");
        if (!isEx[1] && post.h[2] != 0) _flag(V_STATELESS, "harvester DOLA != 0 after success (non-exempt)");
        if (post.hEth != 0) _flag(V_STATELESS, "harvester ETH != 0 after success");
        // (1b) no stranding of the caller's paid-for value: no balance may GROW across a harvest
        for (uint256 t = 0; t < 4; t++) {
            if (post.h[t] > pre.h[t]) _flag(V_STRANDED, "harvester token balance grew across a successful harvest");
        }

        // (2) caller receives >= minEthOut, exactly the returned amount
        if (ethOut < minEthOut) _flag(V_MIN_ETH_OUT, "ethOut < minEthOut");
        if (post.aEth != pre.aEth + ethOut) _flag(V_MIN_ETH_OUT, "caller ETH delta != returned ethOut");

        // (3) V4 deltas net to zero (still the same tx: transient storage readable)
        if (manager.getNonzeroDeltaCount() != 0) _flag(V_V4_DELTAS, "NonzeroDeltaCount != 0");
        if (manager.currencyDelta(address(harvester), Currency.wrap(address(usdc))) != 0) {
            _flag(V_V4_DELTAS, "harvester USDC delta != 0");
        }
        if (manager.currencyDelta(address(harvester), Currency.wrap(address(0))) != 0) {
            _flag(V_V4_DELTAS, "harvester ETH delta != 0");
        }
        if (manager.isUnlocked()) _flag(V_V4_DELTAS, "PoolManager left unlocked");

        // conservation (no mint/burn in a harvest): every tracked-holder total unchanged
        for (uint256 t = 0; t < 4; t++) {
            if (post.sum[t] != pre.sum[t]) _flag(V_CONSERVATION, "token total changed across harvest");
        }
        if (post.aEth + post.pmEth + post.hEth != pre.aEth + pre.pmEth + pre.hEth) {
            _flag(V_CONSERVATION, "ETH total changed across harvest");
        }

        // (4) SYA receives exactly its computed payment; allowances reset
        if (post.syaUsdc - pre.syaUsdc != post.syaCollected - pre.syaCollected) {
            _flag(V_SYA_PAYMENT, "SYA USDC delta != computed payment");
        }
        if (usdc.allowance(address(harvester), address(sya)) != 0) _flag(V_ALLOWANCE, "USDC->SYA allowance != 0");
        _checkAllowances();

        // NFT: harvester ends with none of index; caller delta = (strays refunded) - (1 if burned)
        if (idx != 0) {
            if (post.hNft != 0) _flag(V_NFT, "harvester holds NFT units after success");
            int256 expected = int256(pre.hNft) - (sya.nftMode() == MockSYA.NftMode.Burn ? int256(1) : int256(0));
            if (int256(post.aNft) - int256(pre.aNft) != expected) _flag(V_NFT, "caller NFT delta wrong");
        } else if (post.hNft > pre.hNft) {
            _flag(V_NFT, "harvester NFT balance grew with idx 0");
        }
    }

    function _checkAllowances() internal {
        address[4] memory toks = [address(usdc), address(usde), address(dola), address(crvusd)];
        for (uint256 t = 0; t < 4; t++) {
            if (IERC20(toks[t]).allowance(address(harvester), address(router)) != 0) {
                _flag(V_ALLOWANCE, "token->router allowance != 0");
            }
        }
    }

    // =====================================================================
    //                         REVERT CLASSIFICATION
    // =====================================================================

    function _classifyRevert(bytes memory ret, bool[3] memory isEx, bool overDelivery, bool donated) internal {
        bytes4 sel = ret.length >= 4 ? bytes4(ret) : bytes4(0);
        bool expected;
        uint256 cls = L_OTHER;

        if (
            sel == SYAHarvester.InsufficientEthOut.selector || sel == SYAHarvester.Unprofitable.selector
                || sel == MockSYA.ZeroAmount.selector || sel == MockSYA.NoValidNFT.selector
        ) {
            expected = true;
        } else if (sel == bytes4(keccak256("Error(string)"))) {
            string memory reason = _reason(ret);
            bytes32 h = keccak256(bytes(reason));
            if (h == keccak256("Invalid index") || h == keccak256("NFT minter not configured")) {
                expected = true;
            } else if (h == keccak256("Received nothing")) {
                cls = donated ? L_DUST_GRIEF : L_DUST_NATURAL; // router dust revert on a sub-threshold balance
            } else if (
                h == keccak256("RouterNG: call to empty pool") || h == keccak256("RouterNG: empty output token")
                    || h == keccak256("RouterNG: pool cannot swap pair")
            ) {
                expected = gapRoutePresent; // loud consequence of a divergent owner route (CODE-001 family)
            }
        } else if (sel == bytes4(keccak256("Panic(uint256)"))) {
            // intended loud failure when proceeds cannot repay the borrow
            expected = rateShockActive || gapRoutePresent;
        } else if (sel == SYAHarvester.RouteNotConfigured.selector) {
            address tok = _addrArg(ret);
            uint256 s = tok == address(usde) ? 0 : 1;
            // expected only if that strategy actually delivered yield this call (owner cleared route)
            if (!isEx[s] && strategies[s].pendingDelivery() > 0) expected = true;
            else cls = L_DUST_GRIEF;
        } else if (sel == IERC20Errors.ERC20InsufficientAllowance.selector) {
            cls = overDelivery ? L_OVER_DELIVERY : L_OTHER;
        }

        if (expected) {
            harvestExpectedReverts++;
        } else {
            lastUnexpectedSelector = sel;
            lastUnexpectedRevert = ret;
            if (firstViolationSelector[cls] == bytes4(0)) firstViolationSelector[cls] = sel;
            violations[cls]++;
        }
    }

    // =====================================================================
    //                  GLOBAL (STATE-ONLY) INVARIANT CHECKS
    // =====================================================================

    /// @notice (5) every stored route, under REAL Router NG semantics, starts at its token and ends at
    ///         sya.rewardToken()
    function routeRegistrySound() public view returns (bool) {
        address[2] memory toks = [address(usde), address(dola)];
        for (uint256 i = 0; i < 2; i++) {
            SYAHarvester.CurveRoute memory r = harvester.getRoute(toks[i]);
            if (!r.configured) continue;
            if (r.path[0] != toks[i]) return false;
            if (router.resolveOutput(r.path) != sya.rewardToken()) return false;
        }
        return true;
    }

    function noResidualAllowances() public view returns (bool) {
        address[4] memory toks = [address(usdc), address(usde), address(dola), address(crvusd)];
        for (uint256 t = 0; t < 4; t++) {
            if (IERC20(toks[t]).allowance(address(harvester), address(router)) != 0) return false;
            if (IERC20(toks[t]).allowance(address(harvester), address(sya)) != 0) return false;
        }
        return true;
    }

    function v(uint256 i) public view returns (uint256) {
        return violations[i];
    }

    // =====================================================================
    //                               HELPERS
    // =====================================================================

    // shapes: 0 contiguous direct; 1 contiguous 2-hop via crvUSD;
    //         2 GAP: [t, poolT/crv, crvUSD, 0 ... 0, USDC@10]  (CODE-001 fork shape)
    //         3 GAP: [t, poolT/crv, crvUSD, 0, 0, poolCrv/USDC, USDC]
    //         4 empty first pool: [t, 0, USDC]
    function _routeShape(address t, uint8 shape) internal view returns (address[11] memory p) {
        address direct = t == address(usde) ? POOL_USDE_USDC : POOL_DOLA_USDC;
        address toCrv = t == address(usde) ? POOL_USDE_CRV : POOL_DOLA_CRV;
        p[0] = t;
        if (shape == 0) {
            p[1] = direct;
            p[2] = address(usdc);
        } else if (shape == 1) {
            p[1] = toCrv;
            p[2] = address(crvusd);
            p[3] = POOL_CRV_USDC;
            p[4] = address(usdc);
        } else if (shape == 2) {
            p[1] = toCrv;
            p[2] = address(crvusd);
            p[10] = address(usdc);
        } else if (shape == 3) {
            p[1] = toCrv;
            p[2] = address(crvusd);
            p[5] = POOL_CRV_USDC;
            p[6] = address(usdc);
        } else {
            p[2] = address(usdc);
        }
    }

    function _refreshGapFlag() internal {
        address[2] memory toks = [address(usde), address(dola)];
        bool g;
        for (uint256 i = 0; i < 2; i++) {
            SYAHarvester.CurveRoute memory r = harvester.getRoute(toks[i]);
            if (r.configured && router.resolveOutput(r.path) != address(usdc)) g = true;
        }
        gapRoutePresent = g;
    }

    function _params() internal pure returns (uint256[5][5] memory p) {
        p[0] = [uint256(0), 1, 1, 1, 2];
        p[1] = [uint256(0), 1, 1, 1, 2];
    }

    function _pools() internal pure returns (address[5] memory) {}

    function _exempt(uint8 mask) internal view returns (address[] memory ex) {
        mask = mask % 8;
        uint256 n;
        for (uint256 i = 0; i < 3; i++) if (mask & (1 << i) != 0) n++;
        ex = new address[](n);
        uint256 k;
        for (uint256 i = 0; i < 3; i++) if (mask & (1 << i) != 0) ex[k++] = address(strategies[i]);
    }

    /// payment SYA will pull if the claim goes ahead (MockSYA pricing on DELIVERED amounts)
    function _paymentIfClaimed(bool[3] memory isEx) internal view returns (uint256) {
        uint256 norm;
        if (!isEx[0]) norm += strategies[0].pendingDelivery();
        if (!isEx[1]) norm += strategies[1].pendingDelivery();
        if (!isEx[2]) norm += strategies[2].pendingDelivery() * 1e12;
        return norm * (10000 - sya.discountRate()) / 10000 / 1e12;
    }

    function _snap(InvActor a) internal view returns (Snap memory s) {
        address[4] memory toks = [address(usdc), address(usde), address(dola), address(crvusd)];
        for (uint256 t = 0; t < 4; t++) {
            IERC20 tok = IERC20(toks[t]);
            s.h[t] = tok.balanceOf(address(harvester));
            uint256 sum = s.h[t] + tok.balanceOf(address(manager)) + tok.balanceOf(address(sya))
                + tok.balanceOf(address(router)) + tok.balanceOf(GRIEFER);
            for (uint256 i = 0; i < 3; i++) {
                sum += tok.balanceOf(address(actors[i])) + tok.balanceOf(address(strategies[i]));
            }
            s.sum[t] = sum;
        }
        s.hEth = address(harvester).balance;
        s.aEth = address(a).balance;
        s.pmEth = address(manager).balance;
        s.syaUsdc = usdc.balanceOf(address(sya));
        s.syaCollected = sya.totalCollected();
        s.aNft = nft.balanceOf(address(a), 1);
        s.hNft = nft.balanceOf(address(harvester), 1);
    }

    function _flag(uint256 kind, string memory note) internal {
        if (violations[kind] == 0) lastViolationNote = note;
        violations[kind]++;
    }

    function _reason(bytes memory ret) internal pure returns (string memory) {
        if (ret.length < 68) return "";
        bytes memory body = new bytes(ret.length - 4);
        for (uint256 i = 0; i < body.length; i++) body[i] = ret[i + 4];
        return abi.decode(body, (string));
    }

    function _addrArg(bytes memory ret) internal pure returns (address a) {
        if (ret.length < 36) return address(0);
        assembly {
            a := mload(add(ret, 36))
        }
    }
}

/// Honest owner (Router-NG-contiguous routes only), no donations, delivered <= reported.
/// Every invariant is expected to hold here; a failure would be a NEW finding.
contract HarvestSystemHonest is HarvestSystem {
    constructor() payable HarvestSystem(false, false, false) {}

    function property_stateless() public view returns (bool) { return violations[V_STATELESS] == 0; }
    function property_noStranding() public view returns (bool) { return violations[V_STRANDED] == 0; }
    function property_minEthOut() public view returns (bool) { return violations[V_MIN_ETH_OUT] == 0; }
    function property_v4DeltasZero() public view returns (bool) { return violations[V_V4_DELTAS] == 0; }
    function property_conservation() public view returns (bool) { return violations[V_CONSERVATION] == 0; }
    function property_syaPaymentExact() public view returns (bool) { return violations[V_SYA_PAYMENT] == 0; }
    function property_allowancesReset() public view returns (bool) { return violations[V_ALLOWANCE] == 0 && noResidualAllowances(); }
    function property_nft() public view returns (bool) { return violations[V_NFT] == 0; }
    function property_routeRegistrySound() public view returns (bool) { return routeRegistrySound(); }
    function property_liveness_dust() public view returns (bool) { return violations[L_DUST_GRIEF] == 0; }
    function property_liveness_overDelivery() public view returns (bool) { return violations[L_OVER_DELIVERY] == 0; }
    function property_liveness_other() public view returns (bool) { return violations[L_OTHER] == 0; }
    function property_liveness_naturalDust() public view returns (bool) { return violations[L_DUST_NATURAL] == 0; }
}

/// Adversarial: owner may register Router-NG-divergent routes that pass setRoute (CODE-001),
/// strategies may over-deliver vs estimate (CODE-005), third parties donate dust/strays (CODE-002).
contract HarvestSystemAdversarial is HarvestSystem {
    constructor() payable HarvestSystem(true, true, true) {}

    function property_stateless() public view returns (bool) { return violations[V_STATELESS] == 0; }
    function property_noStranding() public view returns (bool) { return violations[V_STRANDED] == 0; }
    function property_minEthOut() public view returns (bool) { return violations[V_MIN_ETH_OUT] == 0; }
    function property_v4DeltasZero() public view returns (bool) { return violations[V_V4_DELTAS] == 0; }
    function property_conservation() public view returns (bool) { return violations[V_CONSERVATION] == 0; }
    function property_syaPaymentExact() public view returns (bool) { return violations[V_SYA_PAYMENT] == 0; }
    function property_allowancesReset() public view returns (bool) { return violations[V_ALLOWANCE] == 0 && noResidualAllowances(); }
    function property_nft() public view returns (bool) { return violations[V_NFT] == 0; }
    function property_routeRegistrySound() public view returns (bool) { return routeRegistrySound(); }
    function property_liveness_dust() public view returns (bool) { return violations[L_DUST_GRIEF] == 0; }
    function property_liveness_overDelivery() public view returns (bool) { return violations[L_OVER_DELIVERY] == 0; }
    function property_liveness_other() public view returns (bool) { return violations[L_OTHER] == 0; }
    function property_liveness_naturalDust() public view returns (bool) { return violations[L_DUST_NATURAL] == 0; }
}
