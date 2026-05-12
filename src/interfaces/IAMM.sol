// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AMM Interface
/// @notice Minimal interface for the Super-App automated market maker module.
interface IAMM {
    /// @notice Adds liquidity to the pool.
    /// @param amount0 Amount of token0 supplied.
    /// @param amount1 Amount of token1 supplied.
    /// @param to Account receiving LP shares.
    /// @return liquidity Amount of LP shares minted.
    function addLiquidity(uint256 amount0, uint256 amount1, address to) external returns (uint256 liquidity);

    /// @notice Removes liquidity from the pool.
    /// @param liquidity Amount of LP shares burned.
    /// @param to Account receiving withdrawn tokens.
    /// @return amount0 Amount of token0 returned.
    /// @return amount1 Amount of token1 returned.
    function removeLiquidity(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swaps an exact input amount for an output token.
    /// @param tokenIn Token supplied to the pool.
    /// @param amountIn Amount of tokenIn supplied.
    /// @param minAmountOut Minimum acceptable output amount.
    /// @param to Account receiving output tokens.
    /// @return amountOut Amount of output token received.
    function swapExactIn(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        returns (uint256 amountOut);
}
