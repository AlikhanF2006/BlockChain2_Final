// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {InterestRateModel} from "../../src/lending/InterestRateModel.sol";

contract InterestRateModelTest is Test {
    InterestRateModel internal model;

    function setUp() public {
        model = new InterestRateModel();
    }

    function test_BorrowRate_ZeroLiquidityUsesBaseRate() public view {
        assertEq(model.getBorrowRate(0, 0), model.BASE_RATE());
    }

    function test_SupplyRate_ZeroLiquidityIsZero() public view {
        assertEq(model.getSupplyRate(100 ether, 0), 0);
    }

    function test_BorrowRate_ZeroUtilization() public view {
        assertEq(model.getBorrowRate(0, 1_000 ether), model.BASE_RATE());
    }

    function test_BorrowRate_BelowMaximumUtilization() public view {
        uint256 expected = model.BASE_RATE() + model.SLOPE() / 2;
        assertEq(model.getBorrowRate(500 ether, 1_000 ether), expected);
    }

    function test_BorrowRate_MaximumUtilization() public view {
        assertEq(model.getBorrowRate(1_000 ether, 1_000 ether), model.BASE_RATE() + model.SLOPE());
    }

    function test_BorrowRate_UtilizationCapsAtMaximum() public view {
        assertEq(model.getBorrowRate(2_000 ether, 1_000 ether), model.BASE_RATE() + model.SLOPE());
    }

    function test_SupplyRate_BelowMaximumUtilization() public view {
        uint256 utilization = 5e17;
        uint256 borrowRate = model.BASE_RATE() + (utilization * model.SLOPE() / model.WAD());
        uint256 expected = borrowRate * utilization / model.WAD() * (model.WAD() - model.RESERVE_FACTOR()) / model.WAD();

        assertEq(model.getSupplyRate(500 ether, 1_000 ether), expected);
    }

    function test_SupplyRate_MaximumUtilization() public view {
        uint256 borrowRate = model.BASE_RATE() + model.SLOPE();
        uint256 expected = borrowRate * (model.WAD() - model.RESERVE_FACTOR()) / model.WAD();

        assertEq(model.getSupplyRate(1_000 ether, 1_000 ether), expected);
    }
}
