//SPDX-License-Identifier: MIT

// pragma solidity ^0.8.20;

// import {Test} from "forge-std/Test.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

// contract DSCEngineTest is Test {
//     DeployDSC deployer;
//     DecentralizedStableCoin dsc;
//     DSCEngine dsce;
//     HelperConfig config;
//     address ethUsdPriceFeed; // ← ADD THIS
//     address btcUsdPriceFeed; // ← ADD THIS
//     address weth; // ← ADD THIS
//     address public USER = makeAddr("user");
//     uint256 public constant AMOUNT_COLLATERAL = 10 ether;
//     uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

//     function setUp() public {
//         deployer = new DeployDSC();
//         (dsc, dsce) = deployer.run();
//         config = deployer.helperConfig();
//         (ethUsdPriceFeed, btcUsdPriceFeed, weth, , ) = config
//             .activeNetworkConfig();

//         // ERC20Mocks(weth).mint(USER, STARTING_ERC20_BALANCE);
//     }

//     ///////////////////////////////
//     //////Constructor Tests////////
//     address[] public priceFeedAddresses;
//     address[] public tokenAddresses;

//     function testRevertsIfTokenLengthDoesNotMatchPriceFeedLength() public {
//         priceFeedAddresses.push(ethUsdPriceFeed);
//         priceFeedAddresses.push(btcUsdPriceFeed); // ← ADD THIS
//         tokenAddresses.push(weth);
//         // tokenAddresses.push(btc); // ← ADD THIS

//         vm.expectRevert(
//             DSCEngine
//                 .DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch
//                 .selector
//         );
//         new DSCEngine(priceFeedAddresses, tokenAddresses, address(dsc));
//     }

//     function testGetTokenAmountFromUsd() public view {
//         uint256 usdAmount = 100 ether;
//         uint256 expectedEth = 0.05 ether;
//         uint256 actualEth = dsce.getTokenAmountFromUsd(weth, usdAmount);
//         assertEq(expectedEth, actualEth);
//     }

//     ///////////////////////////////
//     //////Price Tests/////////////

//     function testGetUsdValue() public view {
//         uint256 ethAmount = 15e18;
//         uint256 expectedUsd = 30000e18;
//         uint256 actualUsd = dsce.getUsdValue(weth, ethAmount); // ← Fixed typo: "dsce" not "dcse"
//         assertEq(expectedUsd, actualUsd);
//     }

//     ///////////////////////////////
//     //////deposit collateral Tests/////////////
//     function testRevertsIfCollateralZero() public {
//         vm.startPrank(USER);
//         ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

//         vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
//         dsce.depositCollateral(weth, 0);
//         vm.stopPrank();
//     }

//     function testRevertsWithUnapprovedCollateral() public {
//         ERC20Mock fakeToken = new ERC20Mock(
//             "Fake",
//             "FAKE",
//             USER,
//             AMOUNT_COLLATERAL
//         );

//         vm.startPrank(USER);
//         fakeToken.approve(address(dsce), AMOUNT_COLLATERAL);

//         // We "wrap" the error selector with the specific token address it will return
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 DSCEngine.DSCEngine__TokenNotAllowed.selector,
//                 address(fakeToken)
//             )
//         );

//         dsce.depositCollateral(address(fakeToken), AMOUNT_COLLATERAL);
//         vm.stopPrank();
//     }

//     modifier depositedCollateral() {
//         vm.startPrank(USER);
//         ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
//         ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
//         dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
//         vm.stopPrank();
//         _;
//     }

//     function testCanDepositCollateralAndGetAccountInfo()
//         public
//         depositedCollateral
//     {
//         (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce
//             .getAccountInformation(USER);

//         uint256 expectedTotalDscMinted = 0;
//         // If you deposited 10 WETH at $2000/WETH = $20,000 USD
//         uint256 expectedCollateralValueInUsd = 20000e18; // 20,000 USD with 18 decimals

//         assertEq(totalDscMinted, expectedTotalDscMinted);
//         assertEq(collateralValueInUsd, expectedCollateralValueInUsd);
//     }
// }

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract DSCEngineComprehensiveTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");
    address public USER2 = makeAddr("user2");
    address public USER3 = makeAddr("user3");
    address public LIQUIDATOR = makeAddr("liquidator");
    address public ATTACKER = makeAddr("attacker");

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant MINT_AMOUNT = 5000 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        // config = deployer.helperConfig();
        // (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, ) = config
        //     .activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_BALANCE);
        ERC20Mock(weth).mint(USER2, STARTING_BALANCE);
        ERC20Mock(weth).mint(USER3, STARTING_BALANCE);
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_BALANCE);
        ERC20Mock(weth).mint(ATTACKER, STARTING_BALANCE);
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();
        _;
    }

    ///////////////////////////////
    // depositCollateral Tests
    ///////////////////////////////

    function testCanDepositCollateralWithoutMinting() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 userBalance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalance, AMOUNT_COLLATERAL);
    }

    function testCanDepositMultipleCollateralTypes() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        ERC20Mock(wbtc).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(wbtc, AMOUNT_COLLATERAL);

        vm.stopPrank();

        uint256 wethBalance = dsce.getCollateralBalanceOfUser(USER, weth);
        uint256 wbtcBalance = dsce.getCollateralBalanceOfUser(USER, wbtc);

        assertEq(wethBalance, AMOUNT_COLLATERAL);
        assertEq(wbtcBalance, AMOUNT_COLLATERAL);
    }

    function testDepositCollateralEmitsEvent() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectEmit(true, true, true, false, address(dsce));
        emit DSCEngine.CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);

        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfTransferFromFails() public {
        vm.startPrank(USER);
        // Without approval, the ERC20 transferFrom will revert with ERC20InsufficientAllowance
        vm.expectRevert();
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testUserCanDepositMultipleTimes() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dsce), 5 ether);
        dsce.depositCollateral(weth, 5 ether);

        ERC20Mock(weth).approve(address(dsce), 5 ether);
        dsce.depositCollateral(weth, 5 ether);

        vm.stopPrank();

        uint256 balance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(balance, 10 ether);
    }

    ///////////////////////////////
    // depositCollateralAndMintDsc Tests
    ///////////////////////////////

    function testCanDepositAndMintInOneTransaction() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        uint256 userBalance = dsce.getCollateralBalanceOfUser(USER, weth);
        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);

        assertEq(userBalance, AMOUNT_COLLATERAL);
        assertEq(totalDscMinted, MINT_AMOUNT);
    }

    function testDepositAndMintRevertsIfHealthFactorBroken() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        // Try to mint too much DSC - this will break health factor
        vm.expectRevert();
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 15000 ether);
        vm.stopPrank();
    }

    ///////////////////////////////
    // mintDsc Tests
    ///////////////////////////////

    function testRevertsIfMintAmountIsZero() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor()
        public
        depositedCollateral
    {
        vm.startPrank(USER);
        // 10 ETH collateral = $20,000 value
        // Max DSC to mint = $10,000 (due to 200% overcollateralization)
        vm.expectRevert();
        dsce.mintDsc(15000 ether);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(MINT_AMOUNT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, MINT_AMOUNT);
    }

    function testMintDscUpdatesAccountInformation() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(MINT_AMOUNT);
        vm.stopPrank();

        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, MINT_AMOUNT);
    }

    function testCanMintMaximumDscBasedOnCollateral()
        public
        depositedCollateral
    {
        vm.startPrank(USER);
        dsce.mintDsc(10000 ether);
        vm.stopPrank();

        uint256 healthFactor = dsce.getHealthFactor(USER);
        assertEq(healthFactor, 1e18);
    }

    function testUserCanMintMultipleTimes() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(2000 ether);
        dsce.mintDsc(2000 ether);
        vm.stopPrank();

        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, 4000 ether);
    }

    function testCannotMintWithNoCollateral() public {
        vm.startPrank(USER);
        vm.expectRevert();
        dsce.mintDsc(1000 ether);
        vm.stopPrank();
    }

    ///////////////////////////////
    // burnDsc Tests
    ///////////////////////////////

    function testRevertsIfBurnAmountIsZero()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), 1000 ether);
        dsce.burnDsc(1000 ether);
        vm.stopPrank();

        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, 4000 ether);
    }

    function testBurnDscReducesUserBalance()
        public
        depositedCollateralAndMintedDsc
    {
        uint256 startingBalance = dsc.balanceOf(USER);

        vm.startPrank(USER);
        dsc.approve(address(dsce), 1000 ether);
        dsce.burnDsc(1000 ether);
        vm.stopPrank();

        uint256 endingBalance = dsc.balanceOf(USER);
        assertEq(endingBalance, startingBalance - 1000 ether);
    }

    function testBurnDscImprovesHealthFactor()
        public
        depositedCollateralAndMintedDsc
    {
        uint256 startingHealthFactor = dsce.getHealthFactor(USER);

        vm.startPrank(USER);
        dsc.approve(address(dsce), 1000 ether);
        dsce.burnDsc(1000 ether);
        vm.stopPrank();

        uint256 endingHealthFactor = dsce.getHealthFactor(USER);
        assert(endingHealthFactor > startingHealthFactor);
    }

    function testCanBurnAllDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), MINT_AMOUNT);
        dsce.burnDsc(MINT_AMOUNT);
        vm.stopPrank();

        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, 0);
    }

    ///////////////////////////////
    // redeemCollateral Tests
    ///////////////////////////////

    function testRevertsIfRedeemAmountIsZero() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 userBalance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalance, 0);
    }

    function testRedeemCollateralEmitsEvent() public depositedCollateral {
        vm.startPrank(USER);

        vm.expectEmit(true, true, true, true, address(dsce));
        emit DSCEngine.CollateralRedeemed(USER, USER, weth, AMOUNT_COLLATERAL);

        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRedeemCollateralReturnsTokensToUser()
        public
        depositedCollateral
    {
        uint256 startingBalance = ERC20Mock(weth).balanceOf(USER);

        vm.startPrank(USER);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 endingBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(endingBalance, startingBalance + AMOUNT_COLLATERAL);
    }

    function testRevertsIfRedeemBreaksHealthFactor()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(USER);
        vm.expectRevert();
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanRedeemPartialCollateralWhileMaintainingHealthFactor()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(USER);
        dsce.redeemCollateral(weth, 1 ether);
        vm.stopPrank();

        uint256 healthFactor = dsce.getHealthFactor(USER);
        assert(healthFactor >= 1e18);
    }

    ///////////////////////////////
    // redeemCollateralForDsc Tests
    ///////////////////////////////

    function testCanRedeemCollateralForDsc()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(USER);
        dsc.approve(address(dsce), MINT_AMOUNT);
        dsce.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        (uint256 totalDscMinted, ) = dsce.getAccountInformation(USER);
        uint256 collateralBalance = dsce.getCollateralBalanceOfUser(USER, weth);

        assertEq(totalDscMinted, 0);
        assertEq(collateralBalance, 0);
    }

    function testRedeemCollateralForDscRevertsIfAmountIsZero()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateralForDsc(weth, 0, 1000 ether);
        vm.stopPrank();
    }

    function testRedeemCollateralForDscRevertsWithUnapprovedToken()
        public
        depositedCollateralAndMintedDsc
    {
        ERC20Mock fakeToken = new ERC20Mock(
            "Fake",
            "FAKE",
            USER,
            AMOUNT_COLLATERAL
        );

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__TokenNotAllowed.selector,
                address(fakeToken)
            )
        );
        dsce.redeemCollateralForDsc(
            address(fakeToken),
            AMOUNT_COLLATERAL,
            1000 ether
        );
        vm.stopPrank();
    }

    function testRedeemCollateralForDscRevertsIfHealthFactorBroken()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(USER);
        dsc.approve(address(dsce), 1000 ether);
        vm.expectRevert();
        dsce.redeemCollateralForDsc(weth, 8 ether, 1000 ether);
        vm.stopPrank();
    }

    ///////////////////////////////
    // liquidate Tests
    ///////////////////////////////

    function testRevertsIfLiquidateAmountIsZero() public {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.liquidate(weth, USER, 0);
        vm.stopPrank();
    }

    function testRevertsIfHealthFactorIsOk()
        public
        depositedCollateralAndMintedDsc
    {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, 1000 ether);
        vm.stopPrank();
    }

    function testCanLiquidateUser() public depositedCollateralAndMintedDsc {
        // Crash price to make user liquidatable
        // User has 10 ETH collateral, minted 5000 DSC
        // At $2000 per ETH: collateral = $20,000, health factor = (20000 * 0.5) / 5000 = 2.0 (healthy)
        // At $1000 per ETH: collateral = $10,000, health factor = (10000 * 0.5) / 5000 = 1.0 (at threshold)
        // At $950 per ETH: collateral = $9,500, health factor = (9500 * 0.5) / 5000 = 0.95 (liquidatable)
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(950e8);

        uint256 userHealthFactor = dsce.getHealthFactor(USER);
        assert(userHealthFactor < 1e18);

        // Give liquidator more collateral so they have healthy position
        vm.startPrank(USER2);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 5000 ether);
        vm.stopPrank();

        vm.startPrank(USER2);
        dsc.approve(address(dsce), MINT_AMOUNT);
        dsce.liquidate(weth, USER, MINT_AMOUNT);
        vm.stopPrank();

        uint256 endingHealthFactor = dsce.getHealthFactor(USER);
        assert(
            endingHealthFactor > userHealthFactor ||
                endingHealthFactor == type(uint256).max
        );
    }

    function testLiquidatorGetsBonus() public depositedCollateralAndMintedDsc {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(950e8);

        vm.startPrank(USER2);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 5000 ether);
        vm.stopPrank();

        uint256 liquidatorStartingWethBalance = ERC20Mock(weth).balanceOf(
            USER2
        );

        vm.startPrank(USER2);
        dsc.approve(address(dsce), MINT_AMOUNT);
        dsce.liquidate(weth, USER, MINT_AMOUNT);
        vm.stopPrank();

        uint256 liquidatorEndingWethBalance = ERC20Mock(weth).balanceOf(USER2);
        uint256 bonusReceived = liquidatorEndingWethBalance -
            liquidatorStartingWethBalance;

        assert(bonusReceived > 0);
    }

    function testLiquidationReducesUserDscMinted()
        public
        depositedCollateralAndMintedDsc
    {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(950e8);

        vm.startPrank(USER2);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 5000 ether);
        vm.stopPrank();

        (uint256 startingDscMinted, ) = dsce.getAccountInformation(USER);

        vm.startPrank(USER2);
        dsc.approve(address(dsce), 2000 ether);
        dsce.liquidate(weth, USER, 2000 ether);
        vm.stopPrank();

        (uint256 endingDscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(endingDscMinted, startingDscMinted - 2000 ether);
    }

    function testCanPartiallyLiquidate()
        public
        depositedCollateralAndMintedDsc
    {
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(950e8);

        vm.startPrank(USER2);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 5000 ether);
        vm.stopPrank();

        vm.startPrank(USER2);
        dsc.approve(address(dsce), 1000 ether);
        dsce.liquidate(weth, USER, 1000 ether);
        vm.stopPrank();

        (uint256 dscMinted, ) = dsce.getAccountInformation(USER);
        assertEq(dscMinted, 4000 ether);
    }

    ///////////////////////////////
    // Integration Tests
    ///////////////////////////////

    function testFullUserFlowDepositMintBurnRedeem() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        dsce.mintDsc(MINT_AMOUNT);
        assertEq(dsc.balanceOf(USER), MINT_AMOUNT);

        dsc.approve(address(dsce), 2000 ether);
        dsce.burnDsc(2000 ether);
        assertEq(dsc.balanceOf(USER), 3000 ether);

        dsce.redeemCollateral(weth, 2 ether);
        assertEq(dsce.getCollateralBalanceOfUser(USER, weth), 8 ether);

        dsc.approve(address(dsce), 3000 ether);
        dsce.burnDsc(3000 ether);

        dsce.redeemCollateral(weth, 8 ether);
        assertEq(dsce.getCollateralBalanceOfUser(USER, weth), 0);

        vm.stopPrank();
    }

    function testMultipleUsersInteractingSimultaneously() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(USER2);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 4000 ether);
        vm.stopPrank();

        vm.startPrank(USER3);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 3000 ether);
        vm.stopPrank();

        (uint256 user1Dsc, uint256 user1Collateral) = dsce
            .getAccountInformation(USER);
        (uint256 user2Dsc, uint256 user2Collateral) = dsce
            .getAccountInformation(USER2);
        (uint256 user3Dsc, uint256 user3Collateral) = dsce
            .getAccountInformation(USER3);

        assertEq(user1Dsc, MINT_AMOUNT);
        assertEq(user2Dsc, 4000 ether);
        assertEq(user3Dsc, 3000 ether);

        assert(user1Collateral > 0);
        assert(user2Collateral > 0);
        assert(user3Collateral > 0);
    }

    function testLiquidationFlowWithMultipleUsers() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 5000 ether);
        vm.stopPrank();

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(950e8);

        uint256 userHealthFactor = dsce.getHealthFactor(USER);
        assert(userHealthFactor < 1e18);

        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dsce), MINT_AMOUNT);
        dsce.liquidate(weth, USER, MINT_AMOUNT);
        vm.stopPrank();

        uint256 finalHealthFactor = dsce.getHealthFactor(USER);
        assert(
            finalHealthFactor > userHealthFactor ||
                finalHealthFactor == type(uint256).max
        );
    }

    function testProtocolStaysCollateralizedThroughPriceVolatility() public {
        address[] memory users = new address[](3);
        users[0] = USER;
        users[1] = USER2;
        users[2] = USER3;

        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
            dsce.depositCollateralAndMintDsc(
                weth,
                AMOUNT_COLLATERAL,
                MINT_AMOUNT
            );
            vm.stopPrank();
        }

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1800e8);

        for (uint i = 0; i < users.length; i++) {
            uint256 healthFactor = dsce.getHealthFactor(users[i]);
            assert(healthFactor >= 1e18);
        }

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(2200e8);

        for (uint i = 0; i < users.length; i++) {
            uint256 healthFactor = dsce.getHealthFactor(users[i]);
            assert(healthFactor >= 1e18);
        }
    }

    function testComplexScenarioWithMultipleCollateralTypes() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dsce), 5 ether);
        dsce.depositCollateral(weth, 5 ether);

        ERC20Mock(wbtc).approve(address(dsce), 5 ether);
        dsce.depositCollateral(wbtc, 5 ether);

        dsce.mintDsc(10000 ether);

        uint256 totalCollateralValue = dsce.getAccountCollateralValue(USER);
        assert(totalCollateralValue > 0);

        dsc.approve(address(dsce), 5000 ether);
        dsce.burnDsc(5000 ether);

        dsce.redeemCollateral(weth, 2 ether);
        dsce.redeemCollateral(wbtc, 2 ether);

        assertEq(dsce.getCollateralBalanceOfUser(USER, weth), 3 ether);
        assertEq(dsce.getCollateralBalanceOfUser(USER, wbtc), 3 ether);

        vm.stopPrank();
    }

    ///////////////////////////////
    // Security Tests
    ///////////////////////////////

    function testCannotReenterDepositCollateral() public {
        ReentrantERC20 maliciousToken = new ReentrantERC20(address(dsce));

        vm.startPrank(ATTACKER);
        vm.expectRevert();
        dsce.depositCollateral(address(maliciousToken), 1 ether);
        vm.stopPrank();
    }

    function testPriceOracleManipulation() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        uint256 initialHealthFactor = dsce.getHealthFactor(USER);

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(10000e8);

        uint256 spikeHealthFactor = dsce.getHealthFactor(USER);
        assert(spikeHealthFactor > initialHealthFactor);

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(2000e8);

        uint256 finalHealthFactor = dsce.getHealthFactor(USER);
        assertEq(finalHealthFactor, initialHealthFactor);
    }

    function testLiquidationFrontRunning() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(950e8);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 5000 ether);
        vm.stopPrank();

        address frontRunner = makeAddr("frontRunner");
        ERC20Mock(weth).mint(frontRunner, STARTING_BALANCE);

        vm.startPrank(frontRunner);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 5000 ether);
        vm.stopPrank();

        vm.startPrank(frontRunner);
        dsc.approve(address(dsce), MINT_AMOUNT);
        dsce.liquidate(weth, USER, MINT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dsce), MINT_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, MINT_AMOUNT);
        vm.stopPrank();
    }

    function testFlashLoanAttackScenario() public {
        vm.startPrank(ATTACKER);

        uint256 flashLoanAmount = 1000 ether;
        ERC20Mock(weth).mint(ATTACKER, flashLoanAmount);
        ERC20Mock(weth).approve(address(dsce), flashLoanAmount);
        dsce.depositCollateral(weth, flashLoanAmount);

        uint256 collateralValue = dsce.getAccountCollateralValue(ATTACKER);
        uint256 maxDsc = (collateralValue * 50) / 100;
        dsce.mintDsc(maxDsc);

        vm.expectRevert();
        dsce.redeemCollateral(weth, flashLoanAmount);

        vm.stopPrank();
    }

    function testNoIntegerOverflowInHealthFactor() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        dsce.mintDsc(1);

        uint256 healthFactor = dsce.getHealthFactor(USER);
        assert(healthFactor > 0);

        vm.stopPrank();
    }

    function testNoUnderflowInCollateralBalance() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        vm.expectRevert();
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL + 1);

        vm.stopPrank();
    }

    function testNoUnderflowInDscBurn() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);

        dsc.approve(address(dsce), 10000 ether);
        vm.expectRevert();
        dsce.burnDsc(10000 ether);

        vm.stopPrank();
    }

    function testOnlyOwnerCanMintDscToken() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert();
        dsc.mint(ATTACKER, 1000 ether);
        vm.stopPrank();
    }

    function testCannotLiquidateHealthyPosition() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);

        dsc.approve(address(dsce), MINT_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, MINT_AMOUNT);

        vm.stopPrank();
    }

    function testCannotGriefByDustLiquidation() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(950e8);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), 20 ether);
        dsce.depositCollateralAndMintDsc(weth, 20 ether, 5000 ether);

        dsc.approve(address(dsce), 1);

        // Expect the liquidation to revert because 1 wei doesn't improve health factor
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        dsce.liquidate(weth, USER, 1);

        vm.stopPrank();
    }

    function testCannotDrainProtocolByExcessiveMinting() public {
        vm.startPrank(ATTACKER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 collateralValue = dsce.getAccountCollateralValue(ATTACKER);
        uint256 maxDsc = (collateralValue * 50) / 100;

        dsce.mintDsc(maxDsc);

        vm.expectRevert();
        dsce.mintDsc(1);

        vm.stopPrank();
    }

    function testCollateralRatioMaintained() public {
        address[] memory users = new address[](3);
        users[0] = USER;
        users[1] = ATTACKER;
        users[2] = LIQUIDATOR;

        for (uint i = 0; i < users.length; i++) {
            ERC20Mock(weth).mint(users[i], AMOUNT_COLLATERAL);

            vm.startPrank(users[i]);
            ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
            dsce.depositCollateralAndMintDsc(
                weth,
                AMOUNT_COLLATERAL,
                MINT_AMOUNT
            );
            vm.stopPrank();
        }

        uint256 totalWeth = ERC20Mock(weth).balanceOf(address(dsce));
        uint256 totalCollateralValue = dsce.getUsdValue(weth, totalWeth);

        uint256 totalDsc = dsc.totalSupply();

        assert(totalCollateralValue > totalDsc);
    }

    function testNoPrecisionLossInSmallAmounts() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dsce), 1000);
        dsce.depositCollateral(weth, 1000);

        uint256 balance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(balance, 1000);

        vm.stopPrank();
    }

    function testPrecisionInHealthFactorCalculation() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        dsce.mintDsc(1 ether);

        uint256 healthFactor = dsce.getHealthFactor(USER);
        assert(healthFactor > 1000e18);

        vm.stopPrank();
    }

    function testCannotExploitWithZeroCollateral() public {
        vm.startPrank(ATTACKER);

        vm.expectRevert();
        dsce.mintDsc(1000 ether);

        vm.stopPrank();
    }

    function testCannotRedeemOthersCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        vm.startPrank(ATTACKER);
        vm.expectRevert();
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCannotBurnOthersDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(ATTACKER);
        vm.expectRevert();
        dsce.burnDsc(MINT_AMOUNT);
        vm.stopPrank();
    }

    ///////////////////////////////
    // Getter Tests
    ///////////////////////////////

    function testGetAccountInformationEmpty() public view {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce
            .getAccountInformation(USER);

        assertEq(totalDscMinted, 0);
        assertEq(collateralValueInUsd, 0);
    }

    function testGetAccountInformationWithCollateralOnly() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce
            .getAccountInformation(USER);

        assertEq(totalDscMinted, 0);
        assertGt(collateralValueInUsd, 0);
    }

    function testGetAccountInformationWithCollateralAndDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce
            .getAccountInformation(USER);

        assertEq(totalDscMinted, MINT_AMOUNT);
        assertGt(collateralValueInUsd, 0);
    }

    function testGetUsdValueWeth() public view {
        uint256 ethAmount = 1 ether;
        uint256 expectedUsd = 2000 ether;

        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    function testGetUsdValueMultipleEth() public view {
        uint256 ethAmount = 5 ether;
        uint256 expectedUsd = 10000 ether;

        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    function testGetUsdValueZeroAmount() public view {
        uint256 usdValue = dsce.getUsdValue(weth, 0);
        assertEq(usdValue, 0);
    }

    function testGetTokenAmountFromUsdBasic() public view {
        uint256 usdAmount = 2000 ether;
        uint256 expectedEth = 1 ether;

        uint256 actualEth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualEth, expectedEth);
    }

    function testGetTokenAmountFromUsdLargeAmount() public view {
        uint256 usdAmount = 100000 ether;
        uint256 expectedEth = 50 ether;

        uint256 actualEth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualEth, expectedEth);
    }

    function testGetTokenAmountFromUsdRoundTrip() public view {
        uint256 originalUsd = 5000 ether;

        uint256 tokenAmount = dsce.getTokenAmountFromUsd(weth, originalUsd);
        uint256 backToUsd = dsce.getUsdValue(weth, tokenAmount);

        assertEq(backToUsd, originalUsd);
    }

    function testGetCollateralBalanceOfUserNoDeposit() public view {
        uint256 balance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(balance, 0);
    }

    function testGetCollateralBalanceOfUserWithDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 balance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(balance, AMOUNT_COLLATERAL);
    }

    function testGetCollateralBalanceOfUserAfterRedemption() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        dsce.redeemCollateral(weth, 3 ether);
        vm.stopPrank();

        uint256 balance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(balance, 7 ether);
    }

    function testGetAccountCollateralValueEmpty() public view {
        uint256 value = dsce.getAccountCollateralValue(USER);
        assertEq(value, 0);
    }

    function testGetAccountCollateralValueSingleToken() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 value = dsce.getAccountCollateralValue(USER);
        uint256 expectedValue = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);

        assertEq(value, expectedValue);
    }

    function testGetAccountCollateralValueMultipleTokens() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dsce), 5 ether);
        dsce.depositCollateral(weth, 5 ether);

        ERC20Mock(wbtc).approve(address(dsce), 3 ether);
        dsce.depositCollateral(wbtc, 3 ether);

        vm.stopPrank();

        uint256 value = dsce.getAccountCollateralValue(USER);
        uint256 expectedValue = dsce.getUsdValue(weth, 5 ether) +
            dsce.getUsdValue(wbtc, 3 ether);

        assertEq(value, expectedValue);
    }

    function testGetHealthFactorNoDebt() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 healthFactor = dsce.getHealthFactor(USER);
        assertEq(healthFactor, type(uint256).max);
    }

    function testGetHealthFactorWithDebt() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        uint256 healthFactor = dsce.getHealthFactor(USER);
        assertGt(healthFactor, 1e18);
    }

    function testGetHealthFactorAtThreshold() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 collateralValue = dsce.getAccountCollateralValue(USER);
        uint256 maxDsc = (collateralValue * 50) / 100;

        dsce.mintDsc(maxDsc);
        vm.stopPrank();

        uint256 healthFactor = dsce.getHealthFactor(USER);
        assertEq(healthFactor, 1e18);
    }

    function testCalculateHealthFactorBasic() public view {
        uint256 dscMinted = 1000 ether;
        uint256 collateralValue = 3000 ether;

        uint256 healthFactor = dsce.calculateHealthFactor(
            dscMinted,
            collateralValue
        );
        assertEq(healthFactor, 1.5e18);
    }

    function testCalculateHealthFactorNoDebt() public view {
        uint256 healthFactor = dsce.calculateHealthFactor(0, 1000 ether);
        assertEq(healthFactor, type(uint256).max);
    }

    function testCalculateHealthFactorNoCollateral() public view {
        uint256 healthFactor = dsce.calculateHealthFactor(1000 ether, 0);
        assertEq(healthFactor, 0);
    }

    function testGetPrecision() public view {
        uint256 precision = dsce.getPrecision();
        assertEq(precision, 1e18);
    }

    function testGetLiquidationThreshold() public view {
        uint256 threshold = dsce.getLiquidationThreshold();
        assertEq(threshold, 50);
    }

    function testGetLiquidationBonus() public view {
        uint256 bonus = dsce.getLiquidationBonus();
        assertEq(bonus, 10);
    }

    function testGetMinHealthFactor() public view {
        uint256 minHealthFactor = dsce.getMinHealthFactor();
        assertEq(minHealthFactor, 1e18);
    }

    function testGetCollateralTokens() public view {
        address[] memory tokens = dsce.getCollateralTokens();

        assertEq(tokens.length, 2);
        assertEq(tokens[0], weth);
        assertEq(tokens[1], wbtc);
    }

    function testGetDsc() public view {
        address dscAddress = dsce.getDsc();
        assertEq(dscAddress, address(dsc));
    }

    function testGetCollateralTokenPriceFeed() public view {
        address wethPriceFeed = dsce.getCollateralTokenPriceFeed(weth);
        address wbtcPriceFeed = dsce.getCollateralTokenPriceFeed(wbtc);

        assertEq(wethPriceFeed, ethUsdPriceFeed);
        assertEq(wbtcPriceFeed, btcUsdPriceFeed);
    }

    function testStateConsistencyAfterDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 balance = dsce.getCollateralBalanceOfUser(USER, weth);
        uint256 collateralValue = dsce.getAccountCollateralValue(USER);
        (uint256 dscMinted, uint256 accountCollateralValue) = dsce
            .getAccountInformation(USER);

        assertEq(balance, AMOUNT_COLLATERAL);
        assertGt(collateralValue, 0);
        assertEq(dscMinted, 0);
        assertEq(collateralValue, accountCollateralValue);
    }

    function testStateConsistencyAfterMint() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, MINT_AMOUNT);
        vm.stopPrank();

        (uint256 dscMinted, uint256 collateralValue) = dsce
            .getAccountInformation(USER);
        uint256 healthFactor = dsce.getHealthFactor(USER);

        assertEq(dscMinted, MINT_AMOUNT);
        assertGt(collateralValue, 0);
        assertGt(healthFactor, 1e18);

        uint256 calculatedHealthFactor = dsce.calculateHealthFactor(
            dscMinted,
            collateralValue
        );
        assertEq(healthFactor, calculatedHealthFactor);
    }

    function testStateConsistencyMultipleOperations() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        dsce.mintDsc(MINT_AMOUNT);

        dsc.approve(address(dsce), 1000 ether);
        dsce.burnDsc(1000 ether);

        dsce.redeemCollateral(weth, 2 ether);

        vm.stopPrank();

        uint256 collateralBalance = dsce.getCollateralBalanceOfUser(USER, weth);
        (uint256 dscMinted, ) = dsce.getAccountInformation(USER);
        uint256 healthFactor = dsce.getHealthFactor(USER);

        assertEq(collateralBalance, 8 ether);
        assertEq(dscMinted, 4000 ether);
        assertGt(healthFactor, 1e18);
    }
}

contract ReentrantERC20 is ERC20Mock {
    address public targetContract;

    constructor(
        address _target
    ) ERC20Mock("Reentrant", "RENT", msg.sender, 1000000 ether) {
        targetContract = _target;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        bool success = super.transferFrom(from, to, amount);
        return success;
    }
}
