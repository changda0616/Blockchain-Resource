// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    IERC20 internal tokenA;
    IERC20 internal tokenB;

    uint256 private reserveA;
    uint256 private reserveB;

    // Implement core logic here
    constructor(address _tokenA, address _tokenB) ERC20("SimpleSwapPair", "SSP") {
        // check if tokenA, tokenB is the same address
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        // check if tokenA, tokenB is contracts
        require(Address.isContract(_tokenA), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(Address.isContract(_tokenB), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        (address sortedTokenA, address sortedTokenB) = _sortTokens(_tokenA, _tokenB);
        tokenA = IERC20(sortedTokenA);
        tokenB = IERC20(sortedTokenB);
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function _sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        require(_tokenA != _tokenB, "SimpleSwap: IDENTICAL_ADDRESSES");
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(token0 != address(0), "SimpleSwap: ZERO_ADDRESS");
    }

    function _getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint _amountOut) {
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY");
        // XY = (X+X') * (Y+Y')
        // Y' = X'*Y / (X+X')
        _amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    function _update(uint balance0, uint balance1) private {
        reserveA = balance0;
        reserveB = balance1;
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 _amountOut) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == address(tokenA) || tokenOut == address(tokenB), "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        _amountOut = _getAmountOut(
            amountIn,
            IERC20(tokenIn).balanceOf(address(this)),
            IERC20(tokenOut).balanceOf(address(this))
        );

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, _amountOut);
        _update(tokenA.balanceOf(address(this)), tokenB.balanceOf(address(this)));
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, _amountOut);
    }

    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) external returns (uint256 _amountA, uint256 _amountB, uint256 _liquidity) {
        require(amountAIn != 0 && amountBIn != 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        (uint256 _reserveA, uint256 _reserveB) = getReserves();
        // A-> 45 * (10 **18), B -> 20 * (10 **18)
        if (_reserveA == 0 && _reserveB == 0) {
            (_amountA, _amountB) = (amountAIn, amountBIn);
        } else {
            uint256 amountBOptimal = (amountAIn * _reserveB) / _reserveA;
            if (amountBOptimal < amountBIn) {
                (_amountA, _amountB) = (amountAIn, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBIn * _reserveA) / _reserveB;
                (_amountA, _amountB) = (amountAOptimal, amountBIn);
            }
        }
        _liquidity = Math.sqrt(_amountA * _amountB);
        tokenA.transferFrom(msg.sender, address(this), _amountA);
        tokenB.transferFrom(msg.sender, address(this), _amountB);
        _update(tokenA.balanceOf(address(this)), tokenB.balanceOf(address(this)));
        _mint(msg.sender, _liquidity);
        emit AddLiquidity(msg.sender, _amountA, _amountB, _liquidity);
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 _amountA, uint256 _amountB) {
        require(liquidity != 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");
        IERC20(address(this)).transferFrom(msg.sender, address(this), liquidity);

        uint _totalSupply = totalSupply();
        uint _balanceA = tokenA.balanceOf(address(this));
        uint _balanceB = tokenB.balanceOf(address(this));
        _amountA = (liquidity * _balanceA) / _totalSupply;
        _amountB = (liquidity * _balanceB) / _totalSupply;
        _burn(address(this), liquidity);
        tokenA.transfer(msg.sender, _amountA);
        tokenB.transfer(msg.sender, _amountB);
        _update(_balanceA - _amountA, _balanceB - _amountA);
        emit RemoveLiquidity(msg.sender, _amountA, _amountB, liquidity);
    }

    function getReserves() public view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = reserveA;
        _reserveB = reserveB;
    }

    function getTokenA() external view returns (address _tokenA) {
        _tokenA = address(tokenA);
    }

    function getTokenB() external view returns (address _tokenB) {
        _tokenB = address(tokenB);
    }
}
