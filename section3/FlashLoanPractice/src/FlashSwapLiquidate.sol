pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IUniswapV2Callee} from "v2-core/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";

contract FlashSwapLiquidate is IUniswapV2Callee  {
    IERC20 public USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    CErc20 public cUSDC = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    CErc20 public cDAI = CErc20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    IUniswapV2Router02 public router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory public factory =
        IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    struct CallbackData {
        address borrower;
        address tokenIn;
        address tokenOut;
        uint256 repayAmount;
        uint256 liquidateAmount;
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        require(sender == address(this), "Sender must be this contract");
        require(
            amount0 > 0 || amount1 > 0,
            "amount0 or amount1 must be greater than 0"
        );

        CallbackData memory decodeData = abi.decode(data, (CallbackData));

        IERC20(decodeData.tokenOut).approve(
            address(cUSDC),
            decodeData.liquidateAmount
        );
        cUSDC.liquidateBorrow(
            decodeData.borrower,
            decodeData.liquidateAmount,
            cDAI
        );
        // get cDAI, redeem
        uint balance = cDAI.balanceOf(address(this));
        cDAI.approve(address(cDAI), balance);
        cDAI.redeem(balance);
        // get DAI, repay
        IERC20(DAI).transfer(msg.sender, decodeData.repayAmount);
        console.log(DAI.balanceOf(address(this)));
    }

    function liquidate(address borrower, uint256 amountOut) external {
        // TODO
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(USDC);
        address pool = IUniswapV2Factory(factory).getPair(
            address(DAI),
            address(USDC)
        );

        uint256 repayAmount = IUniswapV2Router02(router).getAmountsIn(
            amountOut,
            path
        )[0];


        CallbackData memory decodeData;
        decodeData.borrower = borrower;
        decodeData.liquidateAmount = amountOut; // USDC
        decodeData.repayAmount = repayAmount; // DAI repay
        decodeData.tokenIn = path[0]; // DAI
        decodeData.tokenOut = path[1]; // USDC
        IUniswapV2Pair(pool).swap(
            0,
            amountOut,
            address(this),
            abi.encode(decodeData)
        );
    }
}
