// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DSCEngine
 * @author Foloprunsho Paul
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
 * This stablecoin has the properties:
 * 1. Exogenous Collateral
 * 2. dollar pegged
 * 3. algorithmically stable
 * its is similar to DAI if DAI had no governance, no fees, and was backed only by WETH and WBTC
 *
 * our DSC system should always be overcollateralized. at no point should the value of all the collateral be less than the value of all the dollar backed value DSC.
 *
 * @notice this contract is the core of the DSC system. It handles all the logic for minting and redeeming DSC,
 * as well as depositing and withdrawing collateral.
 * @notice this contract is very loosely based on the MakerDAO DSS (DAI Stablecoin System)
 *
 */
contract DSCEngine is ReentrancyGuard {
    ////////////////////  Errors  ////////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressMustBeSameLength();
    error DSCEngine__NotAllowedToken();

    ////////// State Variables////////// ////////
    mapping(address token => address pricefeed) private s_pricefeeds; // token address -> pricefeed address
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // user address -> token address -> amount deposited
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    DecentralizedStableCoin private immutable i_dsc;

    ////////////////////  Events  ////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    ////////////////////  Modifiers  ////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_pricefeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    //////////////////  Functions  ////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_pricefeeds[tokenAddresses[i]] = priceFeedAddress[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////// External Functions  ////////////////////
    function depositCollateralAndMintDSC() external {}

    function redeemCollateralForDSC() external {}

    function reedemCollateral() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    /* * @notice this function will deposit collateral into the DSC system
     *@notice follows CEI (Checks-Effects-Interactions) pattern
     * @param tokenCollateralAddress the address of the token to deposit as collateral
     * @param amountCollateral the amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        require(success, "Transfer failed");
    }

    /*
     *  @notice follow CEI
     *  @param amountDscToMint the amont of decentralized stablecoin to mint
     * @notice they musthave more collateral value than the minimum threshold
     * 
     */

    function mintDSC(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    ///////////Private $ Internal view  Functions/////////////
    /*  * @notice this function returns the health factor of a user
    returns how close to liqiuidation they are
    if a user goes below 1 they can be liquidated
    1 = collateral value / debt value * liquidation threshold
     * 
     * @param user
     */
    function _healthFactor(address user) private view returns (uint256) {}
    function _revertIfHealthFactorIsBroken(address user) internal view {}
}
