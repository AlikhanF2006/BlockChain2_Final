// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

import {LendingPool} from "../../src/lending/LendingPool.sol";
import {InterestRateModel} from "../../src/lending/InterestRateModel.sol";
import {ChainlinkAdapter} from "../../src/oracle/ChainlinkAdapter.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {MockAggregator} from "../helpers/MockAggregator.sol";

contract LendingPoolTest is Test {
    MockERC20 internal collateral;
    MockERC20 internal borrowAsset;
    MockAggregator internal collateralFeed;
    MockAggregator internal borrowFeed;
    ChainlinkAdapter internal oracle;
    InterestRateModel internal irm;
    LendingPool internal pool;

    address internal lender = makeAddr("lender");
    address internal borrower = makeAddr("borrower");
    address internal liquidator = makeAddr("liquidator");

    function setUp() public {
        vm.warp(10_000);
        collateral = new MockERC20("Collateral", "COL");
        borrowAsset = new MockERC20("Borrow", "BRW");
        collateralFeed = new MockAggregator(8, 2_000e8);
        borrowFeed = new MockAggregator(8, 1e8);

        address[] memory tokens = new address[](2);
        address[] memory feeds = new address[](2);
        tokens[0] = address(collateral);
        tokens[1] = address(borrowAsset);
        feeds[0] = address(collateralFeed);
        feeds[1] = address(borrowFeed);
        oracle = new ChainlinkAdapter(tokens, feeds);
        irm = new InterestRateModel();

        LendingPool implementation = new LendingPool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        pool = LendingPool(address(proxy));
        pool.initialize(address(collateral), address(borrowAsset), address(oracle), address(irm));

        borrowAsset.mint(lender, 2_000_000 ether);
        borrowAsset.mint(liquidator, 2_000_000 ether);
        collateral.mint(borrower, 10_000 ether);

        vm.startPrank(lender);
        borrowAsset.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(borrower);
        collateral.approve(address(pool), type(uint256).max);
        borrowAsset.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.prank(liquidator);
        borrowAsset.approve(address(pool), type(uint256).max);
    }

    function test_Deposit_UpdatesBalance() public {
        _depositLiquidity(1_000 ether);
        assertEq(pool.deposits(lender), 1_000 ether);
        assertEq(pool.totalDeposits(), 1_000 ether);
    }

    function test_Withdraw_CorrectAmount() public {
        _depositLiquidity(1_000 ether);
        uint256 beforeBalance = borrowAsset.balanceOf(lender);

        vm.prank(lender);
        pool.withdraw(400 ether);

        assertEq(borrowAsset.balanceOf(lender), beforeBalance + 400 ether);
        assertEq(pool.deposits(lender), 600 ether);
    }

    function test_Withdraw_RevertInsufficientLiquidity() public {
        _openBorrow(1 ether, 1_000 ether, 1_000 ether);

        vm.prank(lender);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.withdraw(1 ether);
    }

    function test_Borrow_UpdatesDebtWithIndex() public {
        _openBorrow(10 ether, 500 ether, 5_000 ether);

        assertEq(pool.borrows(borrower), 500 ether);
        assertEq(pool.borrowIndex(borrower), pool.globalBorrowIndex());
        assertEq(pool.currentDebt(borrower), 500 ether);
    }

    function test_Repay_ClearsDebt() public {
        _openBorrow(10 ether, 500 ether, 5_000 ether);

        vm.prank(borrower);
        pool.repay(type(uint256).max);

        assertEq(pool.currentDebt(borrower), 0);
        assertEq(pool.borrows(borrower), 0);
    }

    function test_Repay_PartialRepay() public {
        _openBorrow(10 ether, 500 ether, 5_000 ether);

        vm.prank(borrower);
        pool.repay(200 ether);

        assertEq(pool.currentDebt(borrower), 300 ether);
        assertEq(pool.totalBorrows(), 300 ether);
    }

    function test_Borrow_RevertUnderCollateralized() public {
        _depositLiquidity(5_000 ether);
        vm.prank(borrower);
        pool.depositCollateral(1 ether);

        vm.prank(borrower);
        vm.expectRevert(LendingPool.UnderCollateralized.selector);
        pool.borrow(1_600 ether);
    }

    function test_Liquidation_HealthyPosition_Reverts() public {
        _openBorrow(10 ether, 500 ether, 5_000 ether);

        vm.prank(liquidator);
        vm.expectRevert(LendingPool.HealthyPosition.selector);
        pool.liquidate(borrower, 100 ether);
    }

    function test_Liquidation_UnhealthyPosition_Succeeds() public {
        _openBorrow(1 ether, 1_000 ether, 5_000 ether);
        collateralFeed.setAnswer(1_000e8);

        uint256 beforeCollateral = collateral.balanceOf(liquidator);
        vm.prank(liquidator);
        pool.liquidate(borrower, 100 ether);

        assertGt(collateral.balanceOf(liquidator), beforeCollateral);
        assertEq(pool.currentDebt(borrower), 900 ether);
    }

    function test_Liquidation_SeizedAmountWithBonus() public {
        _openBorrow(1 ether, 1_000 ether, 5_000 ether);
        collateralFeed.setAnswer(1_000e8);

        vm.prank(liquidator);
        pool.liquidate(borrower, 100 ether);

        assertEq(collateral.balanceOf(liquidator), 0.105 ether);
    }

    function test_InterestAccrual_OverTime() public {
        _openBorrow(10 ether, 500 ether, 5_000 ether);
        vm.warp(block.timestamp + 365 days);
        pool.accrueInterest();

        assertGt(pool.globalBorrowIndex(), 1e18);
        assertGt(pool.totalBorrows(), 500 ether);
    }

    function test_HealthFactor_BelowOneAfterPriceDrop() public {
        _openBorrow(1 ether, 1_000 ether, 5_000 ether);
        collateralFeed.setAnswer(1_000e8);

        assertLt(pool.getHealthFactor(borrower), 1e18);
    }

    function test_ChainlinkAdapter_RevertStalePrice() public {
        collateralFeed.setUpdatedAt(block.timestamp - 7200);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.StalePrice.selector, address(collateral), block.timestamp - 7200));
        oracle.getPrice(address(collateral));
    }

    function test_ChainlinkAdapter_RevertNegativePrice() public {
        collateralFeed.setAnswer(-1);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.InvalidPrice.selector, address(collateral), int256(-1)));
        oracle.getPrice(address(collateral));
    }

    function testFuzz_DepositWithdraw(uint256 amount) public {
        amount = bound(amount, 1, 1e24);
        borrowAsset.mint(lender, amount);
        vm.startPrank(lender);
        pool.deposit(amount);
        pool.withdraw(amount);
        vm.stopPrank();

        assertEq(pool.deposits(lender), 0);
    }

    function _depositLiquidity(uint256 amount) internal {
        vm.prank(lender);
        pool.deposit(amount);
    }

    function _openBorrow(uint256 collateralAmount, uint256 borrowAmount, uint256 liquidity) internal {
        _depositLiquidity(liquidity);
        vm.prank(borrower);
        pool.depositCollateral(collateralAmount);
        vm.prank(borrower);
        pool.borrow(borrowAmount);
    }
}
