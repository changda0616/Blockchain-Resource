// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Callee } from "v2-core/interfaces/IUniswapV2Callee.sol";
import { IWETH9 } from "./test/interfaces/IWETH9.sol";

// This is a pracitce contract for flash swap arbitrage
contract Arbitrage is IUniswapV2Callee, Ownable {
    struct CallbackData {
        address borrowPool;
        address targetSwapPool;
        address borrowToken;
        address debtToken;
        uint256 borrowAmount;
        uint256 debtAmount;
        uint256 debtAmountOut;
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
    
    // This is the uniswapV2Call for Method 1
    // function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
    //     require(sender == address(this), "Sender must be this contract");
    //     require(amount0 > 0 || amount1 > 0, "amount0 or amount1 must be greater than 0");

    //     // 3. decode callback data
    //     CallbackData memory decodeData = abi.decode(data, (CallbackData));
    //     // The msg sender for the below ERC20 transfer is this Abritirage contract
    //     IERC20(decodeData.borrowToken).transfer(decodeData.targetSwapPool, decodeData.borrowAmount);
    //     // 4. swap WETH to USDC
    //     IUniswapV2Pair(decodeData.targetSwapPool).swap(0, decodeData.debtAmountOut, address(this), "");
    //     // 5. repay USDC to lower price pool
    //     IERC20(decodeData.debtToken).transfer(decodeData.borrowPool, decodeData.debtAmount);
    // }

    // // Method 1 is
    // //  - borrow WETH from lower price pool
    // //  - swap WETH for USDC in higher price pool
    // //  - repay USDC to lower pool
    // // for testing convenient, we implement the method 1 here
    // function arbitrage(address priceLowerPool, address priceHigherPool, uint256 borrowETH) external {
    //     // 1. finish callbackData
    //     // 2. flash swap (borrow WETH from lower price pool)
    //     address priceLowerPoolToken0 = IUniswapV2Pair(priceLowerPool).token0(); // WETH
    //     address priceLowerPoolToken1 = IUniswapV2Pair(priceLowerPool).token1(); // USDC

    //     (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(priceLowerPool).getReserves();
    //     (uint112 priceHigherPoolReserve0, uint112 priceHigherPoolreserve1, ) = IUniswapV2Pair(priceHigherPool)
    //         .getReserves();
    //     // get how much we need to payback if we want 5 ETH out
    //     uint256 repayAmountIn = _getAmountIn(borrowETH, reserve1, reserve0);
    //     uint256 usdcWillGetFromHigherPricePool = _getAmountOut(
    //         borrowETH,
    //         priceHigherPoolReserve0,
    //         priceHigherPoolreserve1
    //     ); // get how much USDC

    //     CallbackData memory callbackData;
    //     callbackData.borrowPool = priceLowerPool;
    //     callbackData.targetSwapPool = priceHigherPool;
    //     callbackData.borrowToken = priceLowerPoolToken0;
    //     callbackData.debtToken = priceLowerPoolToken1;
    //     callbackData.borrowAmount = borrowETH;
    //     callbackData.debtAmount = repayAmountIn;
    //     callbackData.debtAmountOut = usdcWillGetFromHigherPricePool;

    //     // Uncomment next line when you do the homework
    //     IUniswapV2Pair(priceLowerPool).swap(borrowETH, 0, address(this), abi.encode(callbackData));
    // }
    
    // This is the uniswapV2Call for Method 2
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        require(sender == address(this), "Sender must be this contract");
        require(amount0 > 0 || amount1 > 0, "amount0 or amount1 must be greater than 0");

        // 3. decode callback data
        CallbackData memory decodeData = abi.decode(data, (CallbackData));

        IERC20(decodeData.borrowToken).transfer(decodeData.targetSwapPool, decodeData.borrowAmount);
        // 4. swap USDC to WETH
        IUniswapV2Pair(decodeData.targetSwapPool).swap(decodeData.debtAmountOut, 0, address(this), "");
        // 5. repay WETH to higher price pool
        IERC20(decodeData.debtToken).transfer(decodeData.borrowPool, decodeData.debtAmount);

        uint256 _balance = IERC20(decodeData.debtToken).balanceOf(address(this));
        IWETH9(decodeData.debtToken).withdraw(_balance);
        (bool sent, ) = payable(tx.origin).call{ value: _balance }("");
        require(sent, "Failed to send Ether");
    }

    // // Method 2 is
    // //  - borrow USDC from higher price pool
    // //  - swap USDC for WETH in lower pool
    // //  - repay WETH to higher pool
    function arbitrage2(address priceLowerPool, address priceHigherPool, uint256 borrowUSDC) external {
        // 1. finish callbackData
        // 2. flash swap (borrow USDC from higher price pool)
        address priceLowerPoolToken0 = IUniswapV2Pair(priceLowerPool).token0(); // WETH
        address priceLowerPoolToken1 = IUniswapV2Pair(priceLowerPool).token1(); // USDC

        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(priceLowerPool).getReserves();
        (uint112 priceHigherPoolReserve0, uint112 priceHigherPoolreserve1, ) = IUniswapV2Pair(priceHigherPool)
            .getReserves();
        // get how much we need to payback if we want 500 USDC out
        uint256 repayAmountIn = _getAmountIn(borrowUSDC, priceHigherPoolReserve0, priceHigherPoolreserve1);
        // get how much WETH we will get from the lower price pool
        uint256 ethWillGetFromLowerPricePool = _getAmountOut(borrowUSDC, reserve1, reserve0);

        CallbackData memory callbackData;
        callbackData.borrowPool = priceHigherPool;
        callbackData.targetSwapPool = priceLowerPool;
        callbackData.borrowToken = priceLowerPoolToken1;
        callbackData.debtToken = priceLowerPoolToken0;
        callbackData.borrowAmount = borrowUSDC;
        callbackData.debtAmount = repayAmountIn;
        callbackData.debtAmountOut = ethWillGetFromLowerPricePool;

        // Uncomment next line when you do the homework
        IUniswapV2Pair(priceHigherPool).swap(0, borrowUSDC, address(this), abi.encode(callbackData));
    }

    receive() external payable {}

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
