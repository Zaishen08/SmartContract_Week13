// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {ComptrollerInterface} from "compound-protocol/contracts/ComptrollerInterface.sol";
import {Comptroller} from "compound-protocol/contracts/Comptroller.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {PriceOracle} from "compound-protocol/contracts/PriceOracle.sol";
import {InterestRateModel} from "compound-protocol/contracts/InterestRateModel.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract CompoundWeek14SetUp is Test {
  address payable admin = payable(makeAddr("admin"));

  Unitroller unitroller;
  Comptroller comptroller;
  Comptroller proxyComptroller;
  SimplePriceOracle simplePriceOracle;
  PriceOracle priceOracle;

  ERC20 USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  ERC20 UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

  string nameA = "cTokenA";
  string symbolA = "cTA";
  uint8 decimalsA = 18;
  uint exchangeRateMantissaA = 1 * 1e6;

  string nameB = "cTokenB";
  string symbolB = "cTB";
  uint8 decimalsB = 18;
  uint exchangeRateMantissaB = 1 * 1e18;

  CErc20Delegator cUSDC;
  CErc20Delegator cUNI;

  function setUp() public virtual {
    // Fork ethereum mainnet
    string memory rpc = vm.envString("MAINNET_RPC_URL");
    uint256 forkId = vm.createFork(rpc);
    vm.selectFork(forkId);
    vm.rollFork(17_465_000);

    vm.startPrank(admin);
    // Initialize Comptroller
    unitroller = new Unitroller();
    comptroller = new Comptroller();
    simplePriceOracle = new SimplePriceOracle();
    priceOracle = simplePriceOracle;
    uint closeFactor = 0.5e18;
    uint liquidationIncentive = 1.08 * 1e18;

    unitroller._setPendingImplementation(address(comptroller));
    comptroller._become(unitroller);

    // Set value and delegate call
    proxyComptroller = Comptroller(address(unitroller));
    proxyComptroller._setCloseFactor(closeFactor);
    proxyComptroller._setLiquidationIncentive(liquidationIncentive);
    proxyComptroller._setPriceOracle(priceOracle);

    // Deploy cUSDC
    InterestRateModel interestRateModelA = new WhitePaperInterestRateModel(0, 0);
    CErc20Delegate cDelegateA = new CErc20Delegate();
    cUSDC = new CErc20Delegator(
      address(USDC),
      proxyComptroller,
      interestRateModelA,
      exchangeRateMantissaA,
      nameA,
      symbolA,
      decimalsA,
      admin,
      address(cDelegateA),
      new bytes(0)
    );

    // Deploy cUNI
    InterestRateModel interestRateModelB = new WhitePaperInterestRateModel(0, 0);
    CErc20Delegate cDelegateB = new CErc20Delegate();
    cUNI = new CErc20Delegator(
      address(UNI),
      proxyComptroller,
      interestRateModelB,
      exchangeRateMantissaB,
      nameB,
      symbolB,
      decimalsB,
      admin,
      address(cDelegateB),
      new bytes(0)
    );

    // Add cUSDC and cUNI to market
    proxyComptroller._supportMarket(CToken(address(cUSDC)));
    proxyComptroller._supportMarket(CToken(address(cUNI)));

    // Provide initialized liquidity
    uint mintAmount = 2500 * 10 ** USDC.decimals();

    deal(address(USDC), admin, mintAmount);
    USDC.approve(address(cUSDC), mintAmount);
    cUSDC.mint(mintAmount);

    deal(address(UNI), admin, mintAmount);
    UNI.approve(address(cUNI), mintAmount);
    cUNI.mint(mintAmount);
    vm.stopPrank();
  }
}
