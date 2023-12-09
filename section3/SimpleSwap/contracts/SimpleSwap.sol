// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    // Implement core logic here
    IERC20 private immutable _tokenA;
    IERC20 private immutable _tokenB;
    uint256 private _reserveA;
    uint256 private _reserveB;

    using Math for uint256;

    constructor(address tokenA, address tokenB) ERC20("SimpleSwap", "SSWAP") {
        require(isContract(tokenA), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(isContract(tokenB), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(tokenA != tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        _tokenA = IERC20(token0);
        _tokenB = IERC20(token1);
    }

    /// @notice Swap tokenIn for tokenOut with amountIn
    /// @param tokenIn The address of the token to swap from
    /// @param tokenOut The address of the token to swap to
    /// @param amountIn The amount of tokenIn to swap
    /// @return amountOut The amount of tokenOut received
    function swap(address tokenIn, address tokenOut, uint256 amountIn) public returns (uint256 amountOut) {
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(tokenIn == address(_tokenA) || tokenIn == address(_tokenB), "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == address(_tokenA) || tokenOut == address(_tokenB), "SimpleSwap: INVALID_TOKEN_OUT");

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == address(_tokenA) ? (_reserveA, _reserveB) : (_reserveB, _reserveA);

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut == 0) revert("SimpleSwap: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(tokenOut).approve(address(this), amountOut);
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transferFrom(address(this), msg.sender, amountOut);

        _update();
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function _addLiquidity(
        uint amountADesired,
        uint amountBDesired
    ) internal virtual returns (uint amountA, uint amountB, uint liquidity) {
        (uint reserveA, uint reserveB) = getReserves();
        uint256 totalSupply = totalSupply();
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
            // 想質押的B數量大於算出來的該質押的B數量
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }

            liquidity = Math.min(
            amountA * totalSupply / reserveA,
            amountB * totalSupply / reserveB
            );
        }
    }

    /// @notice Add liquidity to the pool
    /// @param amountAIn The amount of tokenA to add
    /// @param amountBIn The amount of tokenB to add
    /// @return amountA The actually amount of tokenA added
    /// @return amountB The actually amount of tokenB added
    /// @return liquidity The amount of liquidity minted
    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (amountAIn == 0 || amountBIn == 0) revert("SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        (uint reserveA, uint reserveB) = getReserves();
        (amountA, amountB, liquidity) = _addLiquidity(amountAIn, amountBIn);
        _tokenA.transferFrom(msg.sender, address(this), amountA);
        _tokenB.transferFrom(msg.sender, address(this), amountB);
        _reserveA = reserveA + amountA;
        _reserveB = reserveB + amountB;

        _mint(msg.sender, liquidity);
        emit AddLiquidity(address(msg.sender), amountA, amountB, liquidity);
    }

    /// @notice Remove liquidity from the pool
    /// @param liquidity The amount of liquidity to remove
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function removeLiquidity(uint256 liquidity) public returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) revert("SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        uint _totalSupply = totalSupply();

        uint balanceA = _tokenA.balanceOf(address(this));
        uint balanceB = _tokenB.balanceOf(address(this));
        amountA = liquidity * balanceA / _totalSupply; // using balances ensures pro-rata distribution
        amountB = liquidity * balanceB / _totalSupply;

        emit Transfer(address(this), address(0), liquidity);
        _burn(msg.sender, liquidity);

        _tokenA.approve(address(this), amountA);
        _tokenB.approve(address(this), amountB);

        _tokenA.transferFrom(address(this), msg.sender, amountA);
        _tokenB.transferFrom(address(this), msg.sender, amountB);

        _update();
        emit RemoveLiquidity(address(msg.sender), amountA, amountB, liquidity);
    }

    function getReserves() public view returns (uint256 reserveA, uint256 reserveB) {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    function getTokenA() public view returns (address tokenA) {
        tokenA = address(_tokenA);
    }

    function getTokenB() public view returns (address tokenB) {
        tokenB = address(_tokenB);
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    // 用 amountA 得出相同價值的 amountB
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    // 用 amountIn 可以換出多少 amountOut
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        amountOut = (reserveOut * amountIn) / (reserveIn + amountIn);
    }

    function _update() internal {
        uint256 balanceA = _tokenA.balanceOf(address(this));
        uint256 balanceB = _tokenB.balanceOf(address(this));
        _reserveA = balanceA;
        _reserveB = balanceB;
    }
}