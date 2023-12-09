// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Callee } from "v2-core/interfaces/IUniswapV2Callee.sol";

// This is a practice contract for flash swap arbitrage
contract Arbitrage is IUniswapV2Callee, Ownable {
    struct CallbackData {
        address borrowPool;
        address borrowToken;
        address repayPool;
        address repayToken;
        uint256 borrowAmount;
        uint256 repayAmount;
        uint256 repayAmountOut;
    }
    //
    // EXTERNAL NON-VIEW ONLY OWNER
    //

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{ value: address(this).balance }("");
        require(success, "Withdraw failed");
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(msg.sender, amount), "Withdraw failed");
    }

    //
    // EXTERNAL NON-VIEW
    //

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        require(sender == address(this), "Sender must be this contract");
        require(amount0 > 0 || amount1 > 0, "One of the amount must be greater 0");

        // 4. decode callback data
        CallbackData memory cbd = abi.decode(data, (CallbackData));

        // 5. swap WETH for USDC in higher price pool
        IERC20(cbd.borrowToken).transfer(cbd.repayPool, cbd.borrowAmount);
        IUniswapV2Pair(cbd.repayPool).swap(0, cbd.repayAmountOut, address(this), "");

        // 6. repay USDC to lower pool
        IERC20(cbd.repayToken).transfer(cbd.borrowPool, cbd.repayAmount);
    }

    // Method 1 is
    //  - borrow WETH from lower price pool
    //  - swap WETH for USDC in higher price pool
    //  - repay USDC to lower pool
    // Method 2 is
    //  - borrow USDC from higher price pool
    //  - swap USDC for WETH in lower pool
    //  - repay WETH to higher pool
    // for testing convenient, we implement the method 1 here
    function arbitrage(address priceLowerPool, address priceHigherPool, uint256 borrowETH) external {
        require(priceLowerPool != priceHigherPool, "Price lower pool and price higher pool must be different");
        require(borrowETH > 0, "Borrow ETH must be greater 0");

        // 1. get borrow token and repay token
        address borrowToken = IUniswapV2Pair(priceLowerPool).token0();
        address repayToken = IUniswapV2Pair(priceLowerPool).token1();

        // 2. get amountIn and amountOut
        uint256 amountIn = _getAmountIn(
            borrowETH,
            IERC20(repayToken).balanceOf(address(priceLowerPool)),
            IERC20(borrowToken).balanceOf(address(priceLowerPool))
        );
        uint256 amountOut = _getAmountOut(
            borrowETH,
            IERC20(borrowToken).balanceOf(address(priceHigherPool)),
            IERC20(repayToken).balanceOf(address(priceHigherPool))
        );

        CallbackData memory callbackData = CallbackData(
            priceLowerPool,
            borrowToken,
            priceHigherPool,
            repayToken,
            borrowETH,
            amountIn,
            amountOut
        );

        // 3. flash swap from lower price pool
        IUniswapV2Pair(priceLowerPool).swap(borrowETH, 0, address(this), abi.encode(callbackData));
    }

    //
    // INTERNAL PURE
    //

    // copy from UniswapV2Library
    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = numerator / denominator + 1;
    }

    // copy from UniswapV2Library
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
