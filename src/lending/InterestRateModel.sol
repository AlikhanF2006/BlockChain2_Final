// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Linear Interest Rate Model
/// @notice WAD-scaled annual borrow and supply rates.
contract InterestRateModel {
    uint256 public constant WAD = 1e18;
    uint256 public constant BASE_RATE = 2e16;
    uint256 public constant SLOPE = 20e16;
    uint256 public constant RESERVE_FACTOR = 10e16;

    function getBorrowRate(uint256 totalBorrows, uint256 totalLiquidity) external pure returns (uint256) {
        if (totalLiquidity == 0) return BASE_RATE;
        uint256 utilization = Math.mulDiv(totalBorrows, WAD, totalLiquidity);
        if (utilization > WAD) utilization = WAD;
        return BASE_RATE + Math.mulDiv(utilization, SLOPE, WAD);
    }

    function getSupplyRate(uint256 totalBorrows, uint256 totalLiquidity) external pure returns (uint256) {
        if (totalLiquidity == 0) return 0;
        uint256 utilization = Math.mulDiv(totalBorrows, WAD, totalLiquidity);
        if (utilization > WAD) utilization = WAD;
        uint256 borrowRate = BASE_RATE + Math.mulDiv(utilization, SLOPE, WAD);
        return Math.mulDiv(Math.mulDiv(borrowRate, utilization, WAD), WAD - RESERVE_FACTOR, WAD);
    }
}
