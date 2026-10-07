// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// run-21 Tier-3 engine-neutral stateful harness for UniPoolerV2 @ 267660b (story-051 fixes).
// No cheatcodes: the same core is driven by forge invariant (Run21Invariant.t.sol) and Medusa
// (MedusaRun21.sol). The core is owner + authorized pooler keeper + NFT buyer; separate Actor
// contracts play the donor, swapper, skimmer and an unprivileged attacker.
//
// Invariants (ghost flags; once tripped they stay tripped and record a counterexample):
//   INV1  L-25 no-strand: each successful pool() leaves <= wei-dust sUSDS/phUSD from that zap.
//   INV2  quote/execute: pool(a, quote.phusdOut, quote.expectedLP) in the quote's state never
//         reverts, and LP received >= quote.expectedLP.
//   INV3  L-21 guard: hook == constructor default => index-4 mint reverts HookNotSet with all
//         balances unchanged; hook != default => never reverts HookNotSet.
//   INV4  pooler-held LP never decreases except via owner rescueERC20.

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UniPoolerV2} from "../../src/dispatchers/UniPoolerV2.sol";
import {NFTMinterV2} from "../../src/NFTMinterV2.sol";
import {IDispatchHook} from "../../src/interfaces/IDispatchHook.sol";
import {DefaultDispatchHook} from "../../src/hooks/DefaultDispatchHook.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {MockDispatchHook} from "../mocks/MockDispatchHook.sol";
import {MockUniV2AmmPair, MockUniV2AmmRouter} from "../mocks/MockUniV2Amm.sol";

contract R21Token is ERC20 {
    constructor(string memory n) ERC20(n, n) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Unprivileged external actor; never bubbles reverts.
contract R21Actor {
    function exec(address target, bytes calldata data) external returns (bool ok, bytes memory ret) {
        (ok, ret) = target.call(data);
    }
}

abstract contract Run21Core {
    // ---------------------------------------------------------------- deployment
    R21Token public usds;
    MockERC4626 public sUsds;
    R21Token public phusd;
    MockUniV2AmmPair public pair;
    MockUniV2AmmRouter public router;
    NFTMinterV2 public minter;
    UniPoolerV2 public pooler; // may be a mutant with an identical ABI
    MockDispatchHook public mockHook;
    address public defaultHook; // the constructor-deployed DefaultDispatchHook (_defaultHook)
    R21Actor public donor;
    R21Actor public swapper;
    R21Actor public skimmer;
    R21Actor public attacker;

    uint256 public constant INDEX = 4; // pooler registered at NFTMinterV2 index 4, like mainnet
    uint256 public constant MINT_PRICE = 1_000e18;
    address public constant NFT_RECIPIENT = address(0xB0B);
    uint256 internal constant CAP = 1 << 100; // keep every pair balance well under uint112

    bytes4 internal constant SEL_HOOK_NOT_SET = bytes4(keccak256("UniPoolerV2__HookNotSet()"));
    bytes4 internal constant SEL_INSUFFICIENT_LP = bytes4(keccak256("UniPoolerV2__InsufficientLP(uint256,uint256)"));

    // ---------------------------------------------------------------- ghosts
    bool public inv1Broken;
    bool public inv2Broken;
    bool public inv3Broken;
    bool public inv4Broken;
    string public inv1Why;
    string public inv2Why;
    string public inv3Why;
    string public inv4Why;

    uint256 public lpFloor; // sum(pooled LP) - sum(owner-rescued LP)
    uint256 public lastLP;

    uint256 public maxResidS; // largest per-zap sUSDS residual seen (wei)
    uint256 public maxResidP; // largest per-zap phUSD residual seen (wei)
    uint256 public zapsAboveNaive2Wei; // informational: zaps whose residual > 2 wei + a/1e12
    uint256 public zapsAboveRepoAbsTol; // informational: residual > repo _dustTol WITHOUT the a/1e12 term
    string public worstZap;
    string public firstAbsBreach; // details of the zap with the largest residual (either side)

    // call stats
    uint256 public nPoolCalls;
    uint256 public nPoolOk;
    uint256 public nPoolExactOk;
    uint256 public nPoolAfterUnsynced; // successful pools that started with an unsynced pair
    uint256 public nPoolSkipped; // quote reverted / zero floors
    uint256 public nMintCalls;
    uint256 public nMintOk;
    uint256 public nMintOkFreshDefault; // documented escape hatch (story-051): fresh DefaultDispatchHook
    uint256 public nMintGuardReverts;
    uint256 public nDonations;
    uint256 public nSwaps;
    uint256 public nSkims;
    uint256 public nSyncs;
    uint256 public nHookToggles;
    uint256 public nOwnerRescues;
    uint256 public nAttackerAttempts;
    uint256 public nAttackerSuccess;
    uint256 public nSeedPooler;

    uint8 public hookMode; // 0 = constructor default, 1 = MockDispatchHook, 2 = fresh DefaultDispatchHook

    constructor(bool sUSDSFirst, uint256 rS, uint256 rP) {
        usds = new R21Token("USDS");
        sUsds = new MockERC4626("sUSDS", "sUSDS", address(usds), 10000);
        for (uint256 i = 0; i < 64; i++) {
            phusd = new R21Token("phUSD");
            if ((address(sUsds) < address(phusd)) == sUSDSFirst) break;
            sUsds = new MockERC4626("sUSDS", "sUSDS", address(usds), 10000); // re-roll both sides
        }
        require((address(sUsds) < address(phusd)) == sUSDSFirst, "ordering");
        pair = new MockUniV2AmmPair(address(sUsds), address(phusd));
        router = new MockUniV2AmmRouter(pair);

        donor = new R21Actor();
        swapper = new R21Actor();
        skimmer = new R21Actor();
        attacker = new R21Actor();

        pooler = UniPoolerV2(_newPooler(address(sUsds), address(phusd), address(router), address(pair)));
        defaultHook = address(pooler.hook()); // == _defaultHook immutable
        mockHook = new MockDispatchHook();

        minter = new NFTMinterV2(address(this));
        minter.registerDispatcher(address(0x1001), 1e18, 0);
        minter.registerDispatcher(address(0x1002), 1e18, 0);
        minter.registerDispatcher(address(0x1003), 1e18, 0);
        minter.registerDispatcher(address(pooler), MINT_PRICE, 0);
        require(minter.dispatcherToIndex(address(pooler)) == INDEX, "index");

        pooler.setMinter(address(minter));
        pooler.setAuthorizedPooler(address(this), true);
        usds.approve(address(minter), type(uint256).max);

        // seed the pair (third-party LP holder 0x5EED)
        _dealSUSDS(address(pair), rS);
        phusd.mint(address(pair), rP);
        pair.mint(address(0x5EED));

        // seed the pooler: two real index-4 mints (hook set), one zap -> pooler holds LP + sUSDS
        pooler.setHook(IDispatchHook(address(mockHook)));
        hookMode = 1;
        usds.mint(address(this), 2 * MINT_PRICE);
        minter.mint(INDEX, NFT_RECIPIENT);
        minter.mint(INDEX, NFT_RECIPIENT);
        (, uint256 qOut, uint256 qLP) = pooler.quotePool(MINT_PRICE);
        pooler.pool(MINT_PRICE, qOut, qLP);
        lpFloor = pair.balanceOf(address(pooler));
        lastLP = lpFloor;
        require(lpFloor > 0 && sUsds.balanceOf(address(pooler)) >= MINT_PRICE, "seed");
    }

    function _newPooler(address s, address p, address r, address pr) internal virtual returns (address);

    // ---------------------------------------------------------------- helpers
    function _bound(uint256 x, uint256 lo, uint256 hi) internal pure returns (uint256) {
        if (hi <= lo) return lo;
        return lo + (x % (hi - lo + 1));
    }

    function _dealSUSDS(address to, uint256 amount) internal {
        usds.mint(address(this), amount);
        usds.approve(address(sUsds), amount);
        sUsds.deposit(amount, to);
    }

    function _sel(bytes memory err) internal pure returns (bytes4 s) {
        if (err.length < 4) return bytes4(0);
        assembly {
            s := mload(add(err, 32))
        }
    }

    function _pairBalances() internal view returns (uint256 bS, uint256 bP) {
        bS = sUsds.balanceOf(address(pair));
        bP = phusd.balanceOf(address(pair));
    }

    function _reservesSP() internal view returns (uint256 rS, uint256 rP) {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        (rS, rP) = pair.token0() == address(sUsds) ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    }

    function _unsynced() internal view returns (bool) {
        (uint256 bS, uint256 bP) = _pairBalances();
        (uint256 rS, uint256 rP) = _reservesSP();
        return bS != rS || bP != rP;
    }

    /// @dev Repo-derived wei-dust bound (test/UniPoolerV2.t.sol::_dustTol): a few wei, times the
    ///      pair price either way, times (2 + a/r0); plus a 1e-12 relative allowance.
    function _dustTol(uint256 rS, uint256 rP, uint256 a, uint256 r0) internal pure returns (uint256) {
        return (4 + 4 * (rS / rP) + 4 * (rP / rS)) * (2 + a / r0) + a / 1e12;
    }

    /// @dev INV4 per-step check: LP may only fall by what the owner rescued in this step.
    function _checkLP(uint256 ownerRescued) internal {
        uint256 cur = pair.balanceOf(address(pooler));
        if (!inv4Broken && cur + ownerRescued < lastLP) {
            inv4Broken = true;
            inv4Why = string.concat("LP fell from ", _u(lastLP), " to ", _u(cur), " (owner rescued ", _u(ownerRescued), ")");
        }
        lastLP = cur;
    }

    function _u(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 t = v;
        uint256 len;
        while (t != 0) {
            len++;
            t /= 10;
        }
        bytes memory b = new bytes(len);
        while (v != 0) {
            b[--len] = bytes1(uint8(48 + v % 10));
            v /= 10;
        }
        return string(b);
    }

    // ---------------------------------------------------------------- actions: keeper
    struct Zap {
        uint256 a;
        uint256 qOut;
        uint256 qLP;
        uint256 sBefore;
        uint256 pBefore;
        uint256 lpBefore;
        uint256 r0;
        bool exact;
        bool wasUnsynced;
    }

    /// @param exact true => floors are the quote's (phusdOut, expectedLP) exactly; false => 1 wei floors.
    function act_pool(uint256 aSeed, bool exact) public {
        nPoolCalls++;
        Zap memory z;
        z.sBefore = sUsds.balanceOf(address(pooler));
        if (z.sBefore < 1e12) {
            nPoolSkipped++;
            _checkLP(0);
            return;
        }
        z.a = _bound(aSeed, 1e12, z.sBefore);
        z.exact = exact;
        try pooler.quotePool(z.a) returns (uint256, uint256 o, uint256 l) {
            z.qOut = o;
            z.qLP = l;
        } catch {
            nPoolSkipped++;
            _checkLP(0);
            return;
        }
        if (z.qOut == 0 || z.qLP == 0) {
            nPoolSkipped++;
            _checkLP(0);
            return;
        }
        z.wasUnsynced = _unsynced();
        z.pBefore = phusd.balanceOf(address(pooler));
        z.lpBefore = pair.balanceOf(address(pooler));
        (z.r0,) = _pairBalances(); // post-sync sUSDS reserve
        try pooler.pool(z.a, exact ? z.qOut : 1, exact ? z.qLP : 1) {
            _afterPoolOk(z);
        } catch (bytes memory err) {
            _afterPoolRevert(z, err);
        }
        _checkLP(0);
    }

    function _afterPoolOk(Zap memory z) internal {
        nPoolOk++;
        if (z.exact) nPoolExactOk++;
        if (z.wasUnsynced) nPoolAfterUnsynced++;
        uint256 lpGot = pair.balanceOf(address(pooler)) - z.lpBefore;
        lpFloor += lpGot;
        // INV1: residual from this zap
        uint256 residS = sUsds.balanceOf(address(pooler)) - (z.sBefore - z.a);
        uint256 residP = phusd.balanceOf(address(pooler)) - z.pBefore;
        bool newMax = residS > maxResidS || residP > maxResidP;
        if (residS > maxResidS) maxResidS = residS;
        if (residP > maxResidP) maxResidP = residP;
        if (residS > 2 + z.a / 1e12 || residP > 2 + z.a / 1e12) zapsAboveNaive2Wei++;
        (uint256 rS, uint256 rP) = _reservesSP();
        uint256 tol = _dustTol(rS, rP, z.a, z.r0);
        uint256 absTol = tol - z.a / 1e12;
        if (residS > absTol || residP > absTol) {
            if (zapsAboveRepoAbsTol == 0) {
                firstAbsBreach = string.concat(
                    "a=", _u(z.a), " residS=", _u(residS), " residP=", _u(residP), " absTol=", _u(absTol)
                );
                firstAbsBreach = string.concat(
                    firstAbsBreach, " postRS=", _u(rS), " postRP=", _u(rP), " preRS=", _u(z.r0),
                    z.wasUnsynced ? " unsynced=1" : " unsynced=0"
                );
            }
            zapsAboveRepoAbsTol++;
        }
        if (newMax) {
            worstZap = string.concat(
                "a=", _u(z.a), " residS=", _u(residS), " residP=", _u(residP), " absTol=", _u(absTol)
            );
            worstZap = string.concat(worstZap, " tol=", _u(tol), " postRS=", _u(rS), " postRP=", _u(rP), " preRS=", _u(z.r0));
        }
        if (!inv1Broken && (residS > tol || residP > tol)) {
            inv1Broken = true;
            inv1Why = string.concat(
                "a=", _u(z.a), " residS=", _u(residS), " residP=", _u(residP), " tol=", _u(tol),
                " unsyncedBefore=", z.wasUnsynced ? "1" : "0"
            );
        }
        // INV2: LP received >= quote.expectedLP
        if (!inv2Broken && lpGot < z.qLP) {
            inv2Broken = true;
            inv2Why = string.concat("a=", _u(z.a), " lpGot=", _u(lpGot), " < quoteLP=", _u(z.qLP));
        }
    }

    function _afterPoolRevert(Zap memory z, bytes memory err) internal {
        // INV2: the quote said this zap is feasible in this exact state; any revert is a break
        // (InsufficientLP / router INSUFFICIENT_OUTPUT_AMOUNT are the story-051 failure modes).
        if (inv2Broken) return;
        inv2Broken = true;
        bytes4 s = _sel(err);
        string memory kind =
            s == SEL_INSUFFICIENT_LP ? "InsufficientLP" : (s == bytes4(0x08c379a0) ? "Error(string)" : "other");
        inv2Why = string.concat(
            "pool reverted (", kind, ") a=", _u(z.a), z.exact ? " exact=1" : " exact=0", " qOut=", _u(z.qOut)
        );
        inv2Why = string.concat(inv2Why, " qLP=", _u(z.qLP), z.wasUnsynced ? " unsyncedBefore=1" : " unsyncedBefore=0");
    }

    // ---------------------------------------------------------------- actions: NFT buyer (index 4)
    function act_mintIndex4() public {
        nMintCalls++;
        usds.mint(address(this), MINT_PRICE);
        bool isDefault = address(pooler.hook()) == defaultHook;
        uint256 myU = usds.balanceOf(address(this));
        uint256 plU = usds.balanceOf(address(pooler));
        uint256 plS = sUsds.balanceOf(address(pooler));
        uint256 plLP = pair.balanceOf(address(pooler));
        uint256 nft = minter.balanceOf(NFT_RECIPIENT, INDEX);
        try minter.mint(INDEX, NFT_RECIPIENT) {
            nMintOk++;
            if (hookMode == 2) nMintOkFreshDefault++;
            if (isDefault && !inv3Broken) {
                inv3Broken = true;
                inv3Why = "index-4 mint SUCCEEDED while hook == constructor default";
            }
        } catch (bytes memory err) {
            bytes4 s = _sel(err);
            if (isDefault) {
                if (s == SEL_HOOK_NOT_SET) nMintGuardReverts++;
                else if (!inv3Broken) {
                    inv3Broken = true;
                    inv3Why = "hook == default but mint reverted with a selector other than HookNotSet";
                }
                bool unchanged = usds.balanceOf(address(this)) == myU && usds.balanceOf(address(pooler)) == plU
                    && sUsds.balanceOf(address(pooler)) == plS && pair.balanceOf(address(pooler)) == plLP
                    && minter.balanceOf(NFT_RECIPIENT, INDEX) == nft;
                if (!unchanged && !inv3Broken) {
                    inv3Broken = true;
                    inv3Why = "guarded mint revert left balances changed";
                }
            } else if (s == SEL_HOOK_NOT_SET && !inv3Broken) {
                inv3Broken = true;
                inv3Why = "hook != default but mint reverted HookNotSet";
            } else if (!inv3Broken) {
                // not part of INV3's claim, but a hooked dispatch should not revert at all here
                inv3Broken = true;
                inv3Why = "hooked index-4 mint reverted unexpectedly";
            }
        }
        _checkLP(0);
    }

    // ---------------------------------------------------------------- actions: owner
    function act_setHook(uint8 mode) public {
        nHookToggles++;
        mode = mode % 3;
        if (mode == 0) pooler.setHook(IDispatchHook(defaultHook));
        else if (mode == 1) pooler.setHook(IDispatchHook(address(mockHook)));
        else pooler.setHook(IDispatchHook(address(new DefaultDispatchHook())));
        hookMode = mode;
        _checkLP(0);
    }

    function act_ownerRescueLP(uint256 amtSeed) public {
        uint256 lp = pair.balanceOf(address(pooler));
        uint256 amt = _bound(amtSeed, 0, lp / 10);
        if (amt == 0) {
            _checkLP(0);
            return;
        }
        nOwnerRescues++;
        pooler.rescueERC20(address(pair), address(this), amt);
        lpFloor -= amt;
        _checkLP(amt);
    }

    /// @dev Extra sUSDS onto the pooler (stand-in for dispatch volume) so zap sizes span the pool.
    function act_seedPooler(uint256 amtSeed) public {
        (uint256 bS,) = _pairBalances();
        uint256 amt = _bound(amtSeed, 1e12, bS * 2);
        if (bS + sUsds.balanceOf(address(pooler)) + amt > CAP) return;
        nSeedPooler++;
        _dealSUSDS(address(pooler), amt);
        _checkLP(0);
    }

    // ---------------------------------------------------------------- actions: third parties
    function act_donate(bool sSide, uint256 amtSeed) public {
        (uint256 bS, uint256 bP) = _pairBalances();
        uint256 b = sSide ? bS : bP;
        uint256 amt = _bound(amtSeed, 1, b / 2 + 1);
        if (b + amt > CAP) return;
        nDonations++;
        if (sSide) {
            _dealSUSDS(address(donor), amt);
            donor.exec(address(sUsds), abi.encodeCall(IERC20.transfer, (address(pair), amt)));
        } else {
            phusd.mint(address(donor), amt);
            donor.exec(address(phusd), abi.encodeCall(IERC20.transfer, (address(pair), amt)));
        }
        _checkLP(0);
    }

    function act_swap(bool sellSUSDS, uint256 amtSeed) public {
        (uint256 rS, uint256 rP) = _reservesSP();
        uint256 rIn = sellSUSDS ? rS : rP;
        uint256 amt = _bound(amtSeed, 1e6, (rIn * 3) / 10);
        if (rIn + amt > CAP) return;
        address tIn = sellSUSDS ? address(sUsds) : address(phusd);
        address tOut = sellSUSDS ? address(phusd) : address(sUsds);
        if (sellSUSDS) _dealSUSDS(address(swapper), amt);
        else phusd.mint(address(swapper), amt);
        swapper.exec(tIn, abi.encodeCall(IERC20.approve, (address(router), amt)));
        address[] memory path = new address[](2);
        path[0] = tIn;
        path[1] = tOut;
        (bool ok,) = swapper.exec(
            address(router),
            abi.encodeCall(MockUniV2AmmRouter.swapExactTokensForTokens, (amt, 0, path, address(swapper), block.timestamp))
        );
        if (ok) nSwaps++;
        _checkLP(0);
    }

    function act_skim() public {
        (bool ok,) = skimmer.exec(address(pair), abi.encodeCall(MockUniV2AmmPair.skim, (address(skimmer))));
        if (ok) nSkims++;
        _checkLP(0);
    }

    function act_sync() public {
        pair.sync();
        nSyncs++;
        _checkLP(0);
    }

    /// @dev Unprivileged attacker tries every LP-moving entry point on the pooler.
    function act_attacker(uint8 which, uint256 amtSeed) public {
        nAttackerAttempts++;
        uint256 lp = pair.balanceOf(address(pooler));
        uint256 amt = _bound(amtSeed, 1, lp == 0 ? 1 : lp);
        bytes memory data;
        which = which % 3;
        if (which == 0) data = abi.encodeCall(UniPoolerV2.rescueERC20, (address(pair), address(attacker), amt));
        else if (which == 1) data = abi.encodeCall(UniPoolerV2.pool, (1e12, 1, 1));
        else data = abi.encodeCall(UniPoolerV2.setAuthorizedPooler, (address(attacker), true));
        (bool ok,) = attacker.exec(address(pooler), data);
        if (ok) nAttackerSuccess++;
        _checkLP(0);
    }

    // ---------------------------------------------------------------- property views
    function ok_inv1() public view returns (bool) {
        return !inv1Broken;
    }

    function ok_inv2() public view returns (bool) {
        return !inv2Broken;
    }

    function ok_inv3() public view returns (bool) {
        return !inv3Broken;
    }

    function ok_inv4() public view returns (bool) {
        return !inv4Broken && pair.balanceOf(address(pooler)) >= lpFloor;
    }
}

contract Run21CoreReal is Run21Core {
    constructor(bool sFirst, uint256 rS, uint256 rP) Run21Core(sFirst, rS, rP) {}

    function _newPooler(address s, address p, address r, address pr) internal override returns (address) {
        return address(new UniPoolerV2(s, p, r, pr, address(this)));
    }
}
