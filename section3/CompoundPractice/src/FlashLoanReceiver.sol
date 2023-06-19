pragma solidity 0.8.13;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import "compound-protocol/contracts/CErc20.sol";
import "v3-periphery/interfaces/ISwapRouter.sol";
import {
IFlashLoanSimpleReceiver,
IPoolAddressesProvider,
IPool
} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

contract FlashLoanReceiver is IFlashLoanSimpleReceiver {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        // Decode params
        (address borrower, address liquidatedCToken, address rewardedCToken, address rewardedToken)
        = abi.decode(params, (address, address, address, address));

        // Liquidate CToken for compound
        IERC20(asset).approve(liquidatedCToken, amount);
        uint256 liquidateResult = CErc20(liquidatedCToken).liquidateBorrow(borrower, amount, CErc20(rewardedCToken));
        require(liquidateResult == 0, "liquidate failed");

        // Redeem rewardedToken with all rewardedCToken
        CErc20(rewardedCToken).redeem(CErc20(rewardedCToken).balanceOf(address(this)));

        // Swap uni back to usdc
        uint256 swapAmount = IERC20(rewardedToken).balanceOf(address(this));
        IERC20(rewardedToken).approve(UNISWAP_ROUTER, swapAmount);
        ISwapRouter.ExactInputSingleParams memory swapParams =
        ISwapRouter.ExactInputSingleParams({
            tokenIn: rewardedToken,
            tokenOut: asset,
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: swapAmount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 totalLoan = amount + premium;
        uint256 amountOut = ISwapRouter(UNISWAP_ROUTER).exactInputSingle(swapParams);
        require(amountOut >= totalLoan, "amountOut not enough");
        // Repay token
        IERC20(asset).approve(msg.sender, totalLoan);
        return true;
    }

    function execute(address asset, uint256 amount, bytes memory data) external {
        // Use AAVE asset pool for flash loan
        POOL().flashLoanSimple(
            address(this),
            asset,
            amount,
            data,
            0
        );
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }
}