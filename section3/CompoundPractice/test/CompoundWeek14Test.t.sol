// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "test/helper/CompoundWeek14SetUp.sol";
import "src/FlashLoanReceiver.sol";

contract CompoundWeek14Test is CompoundWeek14SetUp {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    uint constant tokenAInitBalance = 2500 * 1e6;
    uint constant tokenBInitBalance = 2500 * 1e18;

    function setUp() override public {
        super.setUp();
        // Initial balance
        deal(address(USDC), user1, tokenAInitBalance);
        deal(address(UNI), user1, tokenBInitBalance);
    }

    function test_liquidate() public {
        // Set oracle price and collateral factor
        vm.startPrank(admin);

        simplePriceOracle.setDirectPrice(address(USDC), 1 * 1e30);
        simplePriceOracle.setDirectPrice(address(UNI), 5 * 1e18);
        uint success = proxyComptroller._setCollateralFactor(CToken(address(cUNI)), 0.5 * 1e18);
        require(success == 0, "Set collateral factor fail");
        vm.stopPrank();

        // Mint 1000 cUNI
        vm.startPrank(user1);
        uint mintAmount = 1000 * 10 ** UNI.decimals();
        UNI.approve(address(cUNI), mintAmount);
        cUNI.mint(mintAmount);
        assertEq(cUNI.balanceOf(user1), mintAmount);

        // User1 enter cUNI in market
        address[] memory cTokens = [address(cUNI)];
        uint[] memory successes = proxyComptroller.enterMarkets(cTokens);
        require(successes[0] == 0, "enter market fail");

        // User1 borrow 2500 USDC
        uint borrowAmount = 2500 * 10 ** USDC.decimals();
        success = cUSDC.borrow(borrowAmount);
        require(success == 0, "borrow fail");
        assertEq(USDC.balanceOf(user1), tokenAInitBalance + borrowAmount);
        vm.stopPrank();

        // Change UNI price to $4
        vm.startPrank(admin);
        simplePriceOracle.setDirectPrice(address(UNI), 4 * 1e18);
        vm.stopPrank();

        // Check shortfall
        (,, uint256 shortfall) = proxyComptroller.getAccountLiquidity(address(user1));
        require(shortfall > 0, "shortfall is not correct");

        // User2 liquidate user1
        vm.startPrank(user2);
        uint closeFactorMantissa = proxyComptroller.closeFactorMantissa();
        uint liquidateAmount = borrowAmount * closeFactorMantissa / 1e18;
        bytes memory receiverData = abi.encode(
            address(user1),
            cUSDC,
            cUNI,
            address(UNI)
        );
        flashLoanReceiver.execute(address(USDC), liquidateAmount, receiverData);
        vm.stopPrank();
        // Target profit should greater than 63 USDC
        assertGt(USDC.balanceOf(address(flashLoanReceiver)), 63 * 10 ** USDC.decimals());
    }

}