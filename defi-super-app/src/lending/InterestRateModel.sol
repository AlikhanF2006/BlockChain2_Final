// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Linear Interest Rate Model
/// @notice WAD-scaled annual borrow and supply rates.
contract InterestRateModel {
    uint256 public constant WAD = 1e18;
    uint256 public constant BASE_RATE = 2e16;
    uint256 public constant SLOPE = 20e16;
    uint256 public constant RESERVE_FACTOR = 10e16;

    function getBorrowRate(uint256 totalBorrows, uint256 totalLiquidity) external pure returns (uint256) {
        if (totalLiquidity == 0) return BASE_RATE;
        uint256 utilization = totalBorrows * WAD / totalLiquidity;
        if (utilization > WAD) utilization = WAD;
        return BASE_RATE + (utilization * SLOPE / WAD);
    }

    function getSupplyRate(uint256 totalBorrows, uint256 totalLiquidity) external pure returns (uint256) {
        if (totalLiquidity == 0) return 0;
        uint256 utilization = totalBorrows * WAD / totalLiquidity;
        if (utilization > WAD) utilization = WAD;
        uint256 borrowRate = BASE_RATE + (utilization * SLOPE / WAD);
        return borrowRate * utilization / WAD * (WAD - RESERVE_FACTOR) / WAD;
    }
}
