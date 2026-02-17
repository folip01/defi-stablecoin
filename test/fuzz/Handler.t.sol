//SPDX-License-Identfier: MIT
//handler is going to narrow down the way we call functions

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintDscCalled;
    address[] public usersWithCollateral;
    MockV3Aggregator public ethUsdPriceFeed;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dsce = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
    }

    // function mintDsc(uint256 amountDsc) public {
    //     (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(msg.sender);
    //     int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);

    //     if (maxDscToMint <= 0) {
    //         return;
    //     }
    //     timesMintDscCalled++;
    //     // 1. Bound the amount so it's not 0 (which usually reverts in the Engine)
    //     // and not so large it overflows the mock's supply
    //     amountDsc = bound(amountDsc, 1, 1_000_000e18);
    //     if (amountDsc == 0) {
    //         return;
    //     }
    //     vm.prank(msg.sender);
    //     dsce.mintDsc(amountDsc);
    //     vm.stopPrank();
    //     timesMintDscCalled++;
    // }
    function mintDsc(uint256 amountDsc, uint256 addressSeed) public {
        // 1. If no one has deposited yet, we can't mint!
        if (usersWithCollateral.length == 0) {
            return;
        }

        // 2. Pick a real user from our list using the seed
        address sender = usersWithCollateral[addressSeed % usersWithCollateral.length];

        // 3. Get THAT specific user's info
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);

        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint <= 0) {
            return;
        }

        amountDsc = bound(amountDsc, 1, uint256(maxDscToMint));

        vm.prank(sender); // Prank as the RICH user, not the random fuzzer
        dsce.mintDsc(amountDsc);
        vm.stopPrank();

        timesMintDscCalled++; // Now this will finally go up!
    }

    //reedeem collateral <-
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // 1. Bound the amount so it's not 0 (which usually reverts in the Engine)
        // and not so large it overflows the mock's supply
        amountCollateral = bound(amountCollateral, 1, 1_000_000e18);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        usersWithCollateral.push(msg.sender);
        vm.stopPrank();
    }

    // function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    //     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    //     uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);
    //     // 1. Bound the amount so it's not 0 (which usually reverts in the Engine)
    //     // and not so large it overflows the mock's supply
    //     amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

    //     if (amountCollateral == 0) {
    //         return;
    //     }

    //     dsce.redeemCollateral(address(collateral), amountCollateral);
    // }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral, uint256 addressSeed) public {
        // 1. Safety check: If nobody has deposited, we can't redeem!
        if (usersWithCollateral.length == 0) {
            return;
        }

        // 2. Pick a REAL user who previously deposited
        address sender = usersWithCollateral[addressSeed % usersWithCollateral.length];

        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        // 3. Check THAT specific user's balance
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }

        // 4. MUST PRANK so the Engine knows which user is withdrawing
        vm.prank(sender);
        dsce.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function updateCollateralPrice(uint96 newPrice) public {
        int256 newPrieInt = int256(uint256(newPrice));
        ethUsdPriceFeed.updateAnswer(newPrieInt);
    }

    //Helper functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
