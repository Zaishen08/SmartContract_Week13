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
import { CToken } from "compound-protocol/contracts/CToken.sol";
import {TestERC20} from "../../contracts/TestERC20.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";


contract CompoundWeek13SetUp is Test {
  address payable admin = payable(makeAddr("admin"));
  Unitroller unitroller;
  Comptroller comptroller;
  Comptroller proxyComptroller;
  SimplePriceOracle simplePriceOracle;
  PriceOracle priceOracle;

  ERC20 TokenA;
  ERC20 TokenB;

  string nameA = "CTokenA";
  string symbolA = "cTA";
  uint8 decimalsA = 18;
  string nameB = "CTokenB";
  string symbolB = "cTB";
  uint8 decimalsB = 18;

  CErc20Delegate cDelegateeA;
  CErc20Delegator cDelegatorA;
  CErc20Delegate cDelegateeB;
  CErc20Delegator cDelegatorB;

  function setUp() public virtual {
    vm.startPrank(admin);
    // 1. Deploy Comptroller
    unitroller = new Unitroller();
    comptroller = new Comptroller();
    simplePriceOracle = new SimplePriceOracle();
    priceOracle = simplePriceOracle;
    uint closeFactor = 0;
    uint liquidationIncentive = 0;
    unitroller._setPendingImplementation(address(comptroller));
    comptroller._become(unitroller);

    // Execute delegate call
    proxyComptroller = Comptroller(address(unitroller));
    proxyComptroller._setLiquidationIncentive(liquidationIncentive);
    proxyComptroller._setCloseFactor(closeFactor);
    proxyComptroller._setPriceOracle(priceOracle);

    // Deploy underlying Erc20 token ABC
    TokenA = new ERC20("TokenA", "TA");
    TokenB = new ERC20("TokenB", "TB");

      // Deploy CToken
      uint baseRatePerYearA = 0;
      uint mutliplierPerYearA = 0;
      InterestRateModel interestRateModelA = new WhitePaperInterestRateModel(baseRatePerYearA, mutliplierPerYearA);
      uint exchangeRateMantissaA = 1 * 1e18;
      cDelegateeA = new CErc20Delegate();
      cDelegatorA = new CErc20Delegator(
        address(TokenA),
        proxyComptroller,
        interestRateModelA,
        exchangeRateMantissaA,
        nameA,
        symbolA,
        decimalsA,
        payable(admin),
        address(cDelegateeA),
        "0x0"
      );

      // 4. Deploy CToken
      uint baseRatePerYearB = 0;
      uint mutliplierPerYearB = 0;
      InterestRateModel interestRateModelB = new WhitePaperInterestRateModel(baseRatePerYearB, mutliplierPerYearB);
      uint exchangeRateMantissaB = 1 * 1e18;
      cDelegateeB = new CErc20Delegate();
      cDelegatorB = new CErc20Delegator(
        address(TokenB),
        proxyComptroller,
        interestRateModelB,
        exchangeRateMantissaB,
        nameB,
        symbolB,
        decimalsB,
        payable(admin),
        address(cDelegateeB),
        "0x0"
      );

    // 5. Add CTokenA, CTokenB to market
    proxyComptroller._supportMarket(CToken(address(cDelegatorA)));
    proxyComptroller._supportMarket(CToken(address(cDelegatorB)));

    // 6. Provide liquidity
    uint mintAmountA = 1000 * 10 ** TokenA.decimals();
    uint mintAmountB = 1000 * 10 ** TokenA.decimals();

    deal(address(TokenA), admin, mintAmountA);
    TokenA.approve(address(cDelegatorA), mintAmountA);
    cDelegatorA.mint(mintAmountA);

    deal(address(TokenB), admin, mintAmountB);
    TokenB.approve(address(cDelegatorB), mintAmountB);
    cDelegatorB.mint(mintAmountB);

    vm.stopPrank();
  }
}
