// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

import {LendingPool} from "../../src/lending/LendingPool.sol";
import {InterestRateModel} from "../../src/lending/InterestRateModel.sol";
import {ChainlinkAdapter} from "../../src/oracle/ChainlinkAdapter.sol";
import {YieldVault} from "../../src/vault/YieldVault.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {MockAggregator} from "../helpers/MockAggregator.sol";

contract YieldVaultInvariantHandler is Test {
    YieldVault public vault;
    MockERC20 public asset;
    address public user = makeAddr("vault-invariant-user");
    uint256 public lastAssets;

    constructor(YieldVault vault_, MockERC20 asset_) {
        vault = vault_;
        asset = asset_;
        asset.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        asset.approve(address(vault), type(uint256).max);
        vm.stopPrank();
        lastAssets = vault.totalAssets();
    }

    function deposit(uint256 assets) external {
        assets = bound(assets, 1, 100 ether);
        vm.prank(user);
        vault.deposit(assets, user);
        uint256 current = vault.totalAssets();
        assertGe(current, lastAssets);
        lastAssets = current;
    }
}

contract YieldVaultTest is Test {
    MockERC20 internal collateral;
    MockERC20 internal asset;
    MockAggregator internal collateralFeed;
    MockAggregator internal assetFeed;
    ChainlinkAdapter internal oracle;
    LendingPool internal pool;
    YieldVault internal vault;

    address internal user = makeAddr("user");
    address internal borrower = makeAddr("borrower");

    function setUp() public {
        vm.warp(10_000);
        collateral = new MockERC20("Collateral", "COL");
        asset = new MockERC20("Asset", "AST");
        collateralFeed = new MockAggregator(8, 2_000e8);
        assetFeed = new MockAggregator(8, 1e8);

        address[] memory tokens = new address[](2);
        address[] memory feeds = new address[](2);
        tokens[0] = address(collateral);
        tokens[1] = address(asset);
        feeds[0] = address(collateralFeed);
        feeds[1] = address(assetFeed);
        oracle = new ChainlinkAdapter(tokens, feeds);

        LendingPool poolImplementation = new LendingPool();
        ERC1967Proxy poolProxy = new ERC1967Proxy(address(poolImplementation), "");
        pool = LendingPool(address(poolProxy));
        pool.initialize(address(collateral), address(asset), address(oracle), address(new InterestRateModel()));

        YieldVault vaultImplementation = new YieldVault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = YieldVault(address(vaultProxy));
        vault.initialize(address(asset), address(pool));

        asset.mint(user, 2_000_000 ether);
        collateral.mint(borrower, 10_000 ether);
        asset.mint(borrower, 1_000_000 ether);

        vm.startPrank(user);
        asset.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(borrower);
        collateral.approve(address(pool), type(uint256).max);
        asset.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function test_Deposit_ForwardsToLendingPool() public {
        vm.prank(user);
        vault.deposit(1_000 ether, user);

        assertEq(pool.deposits(address(vault)), 1_000 ether);
        assertEq(asset.balanceOf(address(vault)), 0);
    }

    function test_Withdraw_PullsFromLendingPool() public {
        vm.startPrank(user);
        vault.deposit(1_000 ether, user);
        vault.withdraw(400 ether, user, user);
        vm.stopPrank();

        assertEq(pool.deposits(address(vault)), 600 ether);
    }

    function test_TotalAssets_IncludesInterest() public {
        vm.prank(user);
        vault.deposit(5_000 ether, user);
        _borrowFromPool(10 ether, 1_000 ether);

        vm.warp(block.timestamp + 365 days);
        pool.accrueInterest();

        assertGt(vault.totalAssets(), 5_000 ether);
    }

    function test_ERC4626_RoundingInvariant_SharesToAssets() public {
        vm.prank(user);
        vault.deposit(1_000 ether, user);

        uint256 shares = 123 ether;
        assertLe(vault.convertToShares(vault.convertToAssets(shares)), shares);
    }

    function test_ERC4626_RoundingInvariant_AssetsToShares() public {
        vm.prank(user);
        vault.deposit(1_000 ether, user);

        uint256 assets = 123 ether;
        assertLe(vault.convertToAssets(vault.convertToShares(assets)), assets);
    }

    function test_ERC4626_PreviewDeposit_Conservative() public {
        uint256 preview = vault.previewDeposit(100 ether);
        vm.prank(user);
        uint256 actual = vault.deposit(100 ether, user);

        assertLe(preview, actual);
    }

    function test_ERC4626_MaxDeposit() public {
        assertEq(vault.maxDeposit(user), type(uint256).max);
        vault.pause();
        assertEq(vault.maxDeposit(user), 0);
    }

    function test_ERC4626_MaxMint() public {
        assertEq(vault.maxMint(user), type(uint256).max);
        vault.pause();
        assertEq(vault.maxMint(user), 0);
    }

    function test_Pause_BlocksDeposit_AllowsWithdraw() public {
        vm.prank(user);
        vault.deposit(1_000 ether, user);

        vault.pause();

        vm.prank(user);
        vm.expectRevert();
        vault.deposit(1 ether, user);

        vm.prank(user);
        vault.withdraw(100 ether, user, user);
    }

    function testFuzz_DepositThenWithdraw(uint256 assets) public {
        assets = bound(assets, 1, 1e24);
        asset.mint(user, assets);
        uint256 beforeBalance = asset.balanceOf(user);

        vm.startPrank(user);
        uint256 shares = vault.deposit(assets, user);
        vault.redeem(shares, user, user);
        vm.stopPrank();

        assertLe(asset.balanceOf(user), beforeBalance);
    }

    function _borrowFromPool(uint256 collateralAmount, uint256 borrowAmount) internal {
        vm.prank(borrower);
        pool.depositCollateral(collateralAmount);
        vm.prank(borrower);
        pool.borrow(borrowAmount);
    }
}

contract YieldVaultInvariantTest is Test {
    MockERC20 internal collateral;
    MockERC20 internal asset;
    ChainlinkAdapter internal oracle;
    LendingPool internal pool;
    YieldVault internal vault;
    YieldVaultInvariantHandler internal handler;

    function setUp() public {
        vm.warp(10_000);
        collateral = new MockERC20("Collateral", "COL");
        asset = new MockERC20("Asset", "AST");
        MockAggregator collateralFeed = new MockAggregator(8, 2_000e8);
        MockAggregator assetFeed = new MockAggregator(8, 1e8);

        address[] memory tokens = new address[](2);
        address[] memory feeds = new address[](2);
        tokens[0] = address(collateral);
        tokens[1] = address(asset);
        feeds[0] = address(collateralFeed);
        feeds[1] = address(assetFeed);
        oracle = new ChainlinkAdapter(tokens, feeds);

        LendingPool poolImplementation = new LendingPool();
        ERC1967Proxy poolProxy = new ERC1967Proxy(address(poolImplementation), "");
        pool = LendingPool(address(poolProxy));
        pool.initialize(address(collateral), address(asset), address(oracle), address(new InterestRateModel()));

        YieldVault vaultImplementation = new YieldVault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = YieldVault(address(vaultProxy));
        vault.initialize(address(asset), address(pool));

        handler = new YieldVaultInvariantHandler(vault, asset);
        targetContract(address(handler));
    }

    function invariant_TotalAssetsGrowsMonotonically() public {
        assertGe(vault.totalAssets(), handler.lastAssets());
    }
}
