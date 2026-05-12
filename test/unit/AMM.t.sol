// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

import {AMMFactory} from "../../src/amm/AMMFactory.sol";
import {AMMPool} from "../../src/amm/AMMPool.sol";
import {AMMPoolV2} from "../../src/amm/AMMPoolV2.sol";
import {LPToken} from "../../src/tokens/LPToken.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {MockReentrantToken} from "../helpers/MockReentrantToken.sol";

contract AMMInvariantHandler is Test {
    AMMPool public pool;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    address public trader = makeAddr("invariant-trader");
    uint256 public lastK;

    constructor(AMMPool pool_, MockERC20 tokenA_, MockERC20 tokenB_) {
        pool = pool_;
        tokenA = tokenA_;
        tokenB = tokenB_;
        tokenA.mint(trader, 1_000_000 ether);
        tokenB.mint(trader, 1_000_000 ether);
        vm.startPrank(trader);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();
        lastK = pool.lastK();
    }

    function swapAForB(uint256 amountIn) external {
        amountIn = bound(amountIn, 1e6, 10 ether);
        _swap(address(tokenA), amountIn);
    }

    function swapBForA(uint256 amountIn) external {
        amountIn = bound(amountIn, 1e6, 10 ether);
        _swap(address(tokenB), amountIn);
    }

    function _swap(address tokenIn, uint256 amountIn) internal {
        vm.prank(trader);
        try pool.swapExactTokensForTokens(amountIn, 0, tokenIn, trader, block.timestamp + 1) {
            uint256 currentK = pool.lastK();
            assertGe(currentK, lastK);
            lastK = currentK;
        } catch {}
    }
}

contract AMMFactoryHarness is AMMFactory {
    function exposedComputeCreateAddress(address deployer, uint256 nonce) external pure returns (address) {
        return _computeCreateAddress(deployer, nonce);
    }
}

contract AMMTest is Test {
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    AMMPool internal pool;
    LPToken internal lpToken;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal feeTo = makeAddr("feeTo");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKNA");
        tokenB = new MockERC20("Token B", "TKNB");
        (pool, lpToken) = _deployPool(address(tokenA), address(tokenB));
        _mintAndApprove(alice, 1_000_000 ether, 1_000_000 ether);
        _mintAndApprove(bob, 1_000_000 ether, 1_000_000 ether);
    }

    function test_AddLiquidity_FirstDeposit() public {
        vm.prank(alice);
        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            pool.addLiquidity(100 ether, 200 ether, 100 ether, 200 ether, alice, block.timestamp + 1);

        assertEq(amountA, 100 ether);
        assertEq(amountB, 200 ether);
        assertEq(liquidity, _sqrt(100 ether * 200 ether) - pool.MINIMUM_LIQUIDITY());
        assertEq(lpToken.balanceOf(alice), liquidity);
        (uint112 reserveA, uint112 reserveB,) = pool.getReserves();
        assertEq(reserveA, 100 ether);
        assertEq(reserveB, 200 ether);
    }

    function test_AddLiquidity_SecondDeposit_MaintainsRatio() public {
        _addInitialLiquidity();

        vm.prank(bob);
        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            pool.addLiquidity(100 ether, 300 ether, 100 ether, 200 ether, bob, block.timestamp + 1);

        assertEq(amountA, 100 ether);
        assertEq(amountB, 200 ether);
        assertGt(liquidity, 0);
    }

    function test_AddLiquidity_SecondDeposit_UsesAmountAOptimal() public {
        _addInitialLiquidity();

        vm.prank(bob);
        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            pool.addLiquidity(300 ether, 100 ether, 50 ether, 100 ether, bob, block.timestamp + 1);

        assertEq(amountA, 50 ether);
        assertEq(amountB, 100 ether);
        assertGt(liquidity, 0);
    }

    function test_AddLiquidity_RevertDeadlineExpired() public {
        vm.prank(alice);
        vm.expectRevert(AMMPool.DeadlineExpired.selector);
        pool.addLiquidity(100 ether, 100 ether, 0, 0, alice, block.timestamp - 1);
    }

    function test_AddLiquidity_RevertZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(AMMPool.InsufficientAmount.selector);
        pool.addLiquidity(0, 100 ether, 0, 0, alice, block.timestamp + 1);
    }

    function test_AddLiquidity_RevertZeroRecipient() public {
        vm.prank(alice);
        vm.expectRevert(AMMPool.InsufficientAmount.selector);
        pool.addLiquidity(100 ether, 100 ether, 0, 0, address(0), block.timestamp + 1);
    }

    function test_AddLiquidity_RevertMinimumLiquidity() public {
        vm.prank(alice);
        vm.expectRevert(AMMPool.InsufficientLiquidity.selector);
        pool.addLiquidity(10, 10, 0, 0, alice, block.timestamp + 1);
    }

    function test_AddLiquidity_RevertInsufficientAmountA() public {
        _addInitialLiquidity();
        vm.prank(bob);
        vm.expectRevert(AMMPool.InsufficientAmount.selector);
        pool.addLiquidity(100 ether, 300 ether, 101 ether, 0, bob, block.timestamp + 1);
    }

    function test_AddLiquidity_RevertInsufficientAmountB() public {
        _addInitialLiquidity();
        vm.prank(bob);
        vm.expectRevert(AMMPool.InsufficientAmount.selector);
        pool.addLiquidity(100 ether, 300 ether, 0, 201 ether, bob, block.timestamp + 1);
    }

    function test_RemoveLiquidity_ProportionalReturn() public {
        _addInitialLiquidity();
        uint256 liquidity = lpToken.balanceOf(alice) / 2;

        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = pool.removeLiquidity(liquidity, 0, 0, alice, block.timestamp + 1);

        assertApproxEqAbs(amountA, 50 ether, 1000);
        assertApproxEqAbs(amountB, 100 ether, 1000);
    }

    function test_RemoveLiquidity_RevertInsufficientAmounts() public {
        _addInitialLiquidity();
        uint256 liquidity = lpToken.balanceOf(alice) / 2;

        vm.prank(alice);
        vm.expectRevert(AMMPool.InsufficientAmount.selector);
        pool.removeLiquidity(liquidity, 51 ether, 0, alice, block.timestamp + 1);
    }

    function test_RemoveLiquidity_RevertDeadlineExpired() public {
        _addInitialLiquidity();
        uint256 liquidity = lpToken.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(AMMPool.DeadlineExpired.selector);
        pool.removeLiquidity(liquidity, 0, 0, alice, block.timestamp - 1);
    }

    function test_RemoveLiquidity_RevertZeroLiquidity() public {
        _addInitialLiquidity();

        vm.prank(alice);
        vm.expectRevert(AMMPool.InsufficientAmount.selector);
        pool.removeLiquidity(0, 0, 0, alice, block.timestamp + 1);
    }

    function test_RemoveLiquidity_RevertZeroRecipient() public {
        _addInitialLiquidity();
        uint256 liquidity = lpToken.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(AMMPool.InsufficientAmount.selector);
        pool.removeLiquidity(liquidity, 0, 0, address(0), block.timestamp + 1);
    }

    function test_Swap_CorrectAmountOut() public {
        _addInitialLiquidity();
        uint256 expected = pool.getAmountOut(10 ether, 100 ether, 200 ether);

        vm.prank(bob);
        uint256 amountOut = pool.swapExactTokensForTokens(10 ether, 0, address(tokenA), bob, block.timestamp + 1);

        assertEq(amountOut, expected);
        assertEq(tokenB.balanceOf(bob), 1_000_000 ether + expected);
    }

    function test_Swap_TokenBForTokenA() public {
        _addInitialLiquidity();
        uint256 expected = pool.getAmountOut(10 ether, 200 ether, 100 ether);

        vm.prank(bob);
        uint256 amountOut = pool.swapExactTokensForTokens(10 ether, 0, address(tokenB), bob, block.timestamp + 1);

        assertEq(amountOut, expected);
        assertEq(tokenA.balanceOf(bob), 1_000_000 ether + expected);
    }

    function test_Swap_RevertInsufficientOutput() public {
        _addInitialLiquidity();
        uint256 expected = pool.getAmountOut(10 ether, 100 ether, 200 ether);

        vm.prank(bob);
        vm.expectRevert(AMMPool.InsufficientOutputAmount.selector);
        pool.swapExactTokensForTokens(10 ether, expected + 1, address(tokenA), bob, block.timestamp + 1);
    }

    function test_Swap_RevertDeadlineExpired() public {
        _addInitialLiquidity();

        vm.prank(bob);
        vm.expectRevert(AMMPool.DeadlineExpired.selector);
        pool.swapExactTokensForTokens(10 ether, 0, address(tokenA), bob, block.timestamp - 1);
    }

    function test_Swap_RevertZeroAmount() public {
        _addInitialLiquidity();

        vm.prank(bob);
        vm.expectRevert(AMMPool.InsufficientAmount.selector);
        pool.swapExactTokensForTokens(0, 0, address(tokenA), bob, block.timestamp + 1);
    }

    function test_Swap_RevertInvalidToken() public {
        _addInitialLiquidity();
        MockERC20 invalidToken = new MockERC20("Invalid", "INV");

        vm.prank(bob);
        vm.expectRevert(AMMPool.InvalidToken.selector);
        pool.swapExactTokensForTokens(1 ether, 0, address(invalidToken), bob, block.timestamp + 1);
    }

    function test_Swap_RevertInsufficientLiquidityBeforeDeposit() public {
        vm.prank(bob);
        vm.expectRevert(AMMPool.InsufficientLiquidity.selector);
        pool.swapExactTokensForTokens(1 ether, 0, address(tokenA), bob, block.timestamp + 1);
    }

    function test_Swap_ReentrancyProtected() public {
        MockReentrantToken reentrant = new MockReentrantToken();
        MockERC20 paired = new MockERC20("Paired", "PAIR");
        (AMMPool reentrantPool,) = _deployPool(address(reentrant), address(paired));

        reentrant.mint(alice, 1_000 ether);
        paired.mint(alice, 1_000 ether);
        vm.startPrank(alice);
        reentrant.approve(address(reentrantPool), type(uint256).max);
        paired.approve(address(reentrantPool), type(uint256).max);
        reentrantPool.addLiquidity(100 ether, 100 ether, 0, 0, alice, block.timestamp + 1);
        vm.stopPrank();

        reentrant.mint(bob, 100 ether);
        paired.mint(bob, 100 ether);
        vm.startPrank(bob);
        reentrant.approve(address(reentrantPool), type(uint256).max);
        paired.approve(address(reentrantPool), type(uint256).max);
        vm.stopPrank();

        reentrant.configureAttack(address(reentrantPool), address(paired));
        reentrant.setAttackEnabled(true);

        vm.prank(bob);
        vm.expectRevert();
        reentrantPool.swapExactTokensForTokens(1 ether, 0, address(reentrant), bob, block.timestamp + 1);
    }

    function test_GetAmountOut_MatchesAssembly() public {
        for (uint256 i = 1; i < 100; i++) {
            uint256 amountIn = i * 1e15;
            assertEq(
                pool.getAmountOut(amountIn, 100 ether, 200 ether),
                pool.getAmountOutAssembly(amountIn, 100 ether, 200 ether)
            );
        }
    }

    function test_Factory_CreatePair() public {
        AMMFactory factory = new AMMFactory();
        address pair = factory.createPair(address(tokenA), address(tokenB));

        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair);
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pair);
        assertEq(factory.allPairs(0), pair);
    }

    function test_Factory_RevertDuplicatePair() public {
        AMMFactory factory = new AMMFactory();
        factory.createPair(address(tokenA), address(tokenB));

        vm.expectRevert(AMMFactory.PairExists.selector);
        factory.createPair(address(tokenB), address(tokenA));
    }

    function test_Factory_RevertIdenticalAddresses() public {
        AMMFactory factory = new AMMFactory();

        vm.expectRevert(AMMFactory.IdenticalAddresses.selector);
        factory.createPair(address(tokenA), address(tokenA));
    }

    function test_Factory_RevertZeroAddress() public {
        AMMFactory factory = new AMMFactory();

        vm.expectRevert(AMMFactory.ZeroAddress.selector);
        factory.createPair(address(0), address(tokenA));
    }

    function test_Factory_GetPairReversedOrder() public {
        AMMFactory factory = new AMMFactory();
        address pair = factory.createPair(address(tokenA), address(tokenB));

        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair);
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pair);
        assertEq(factory.allPairsLength(), 1);
    }

    function test_Factory_CREATE2_AddressPrediction() public {
        AMMFactory factory = new AMMFactory();
        address predicted = factory.predictPairAddress(address(tokenA), address(tokenB));
        address pair = factory.createPair(address(tokenA), address(tokenB));
        assertEq(pair, predicted);
    }

    function test_Factory_ComputeCreateAddressNonceBranches() public {
        AMMFactoryHarness harness = new AMMFactoryHarness();

        assertTrue(harness.exposedComputeCreateAddress(address(this), 0) != address(0));
        assertTrue(harness.exposedComputeCreateAddress(address(this), 0x80) != address(0));
        assertTrue(harness.exposedComputeCreateAddress(address(this), 0x100) != address(0));
        assertTrue(harness.exposedComputeCreateAddress(address(this), 0x10000) != address(0));
        assertTrue(harness.exposedComputeCreateAddress(address(this), 0x1000000) != address(0));
    }

    function test_UUPS_UpgradeToV2() public {
        _addInitialLiquidity();
        AMMPoolV2 v2 = new AMMPoolV2();

        pool.upgradeToAndCall(address(v2), "");
        AMMPoolV2 upgraded = AMMPoolV2(address(pool));
        upgraded.setProtocolFee(true, feeTo);

        assertTrue(upgraded.protocolFeeEnabled());
        assertEq(upgraded.feeTo(), feeTo);
        assertEq(upgraded.tokenA(), address(tokenA));
        assertEq(upgraded.tokenB(), address(tokenB));
    }

    function test_V2_SetProtocolFeeDisabledAllowsZeroFeeTo() public {
        AMMPoolV2 v2 = new AMMPoolV2();
        pool.upgradeToAndCall(address(v2), "");
        AMMPoolV2 upgraded = AMMPoolV2(address(pool));

        upgraded.setProtocolFee(false, address(0));

        assertFalse(upgraded.protocolFeeEnabled());
        assertEq(upgraded.feeTo(), address(0));
    }

    function test_V2_SetProtocolFeeRevertZeroFeeToWhenEnabled() public {
        AMMPoolV2 v2 = new AMMPoolV2();
        pool.upgradeToAndCall(address(v2), "");
        AMMPoolV2 upgraded = AMMPoolV2(address(pool));

        vm.expectRevert(AMMPool.InvalidToken.selector);
        upgraded.setProtocolFee(true, address(0));
    }

    function test_V2_SetProtocolFeeRevertUnauthorized() public {
        AMMPoolV2 v2 = new AMMPoolV2();
        pool.upgradeToAndCall(address(v2), "");
        AMMPoolV2 upgraded = AMMPoolV2(address(pool));

        vm.prank(alice);
        vm.expectRevert();
        upgraded.setProtocolFee(true, feeTo);
    }

    function test_V2_MintsProtocolFeeOnLiquidityGrowth() public {
        _addInitialLiquidity();
        AMMPoolV2 v2 = new AMMPoolV2();
        pool.upgradeToAndCall(address(v2), "");
        AMMPoolV2 upgraded = AMMPoolV2(address(pool));
        upgraded.setProtocolFee(true, feeTo);

        vm.prank(bob);
        upgraded.addLiquidity(100 ether, 200 ether, 0, 0, bob, block.timestamp + 1);

        assertGt(lpToken.balanceOf(feeTo), 0);
        assertTrue(upgraded.protocolFeeEnabled());
    }

    function test_UUPS_RevertUnauthorizedUpgrade() public {
        AMMPoolV2 v2 = new AMMPoolV2();

        vm.prank(alice);
        vm.expectRevert();
        pool.upgradeToAndCall(address(v2), "");
    }

    function test_PoolInitializeRevertInvalidToken() public {
        AMMPool implementation = new AMMPool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        AMMPool invalidPool = AMMPool(address(proxy));

        vm.expectRevert(AMMPool.InvalidToken.selector);
        invalidPool.initialize(address(tokenA), address(tokenA), address(lpToken));
    }

    function test_GetAmountOutRevertZeroInput() public {
        vm.expectRevert(AMMPool.InsufficientLiquidity.selector);
        pool.getAmountOut(0, 100 ether, 200 ether);
    }

    function test_GetAmountOutAssemblyRevertZeroReserve() public {
        vm.expectRevert(AMMPool.InsufficientLiquidity.selector);
        pool.getAmountOutAssembly(1 ether, 0, 200 ether);
    }

    function testFuzz_Swap(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e6, 1e24);
        _addInitialLiquidityLarge();
        uint256 expected = pool.getAmountOutAssembly(amountIn, 1_000_000 ether, 1_000_000 ether);

        vm.prank(bob);
        uint256 amountOut = pool.swapExactTokensForTokens(amountIn, 0, address(tokenA), bob, block.timestamp + 1);

        assertEq(amountOut, expected);
        assertGt(amountOut, 0);
    }

    function testFuzz_AddRemoveLiquidity(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1e6, 1e24);
        amountB = bound(amountB, 1e6, 1e24);

        vm.prank(alice);
        (,, uint256 liquidity) = pool.addLiquidity(amountA, amountB, 0, 0, alice, block.timestamp + 1);

        vm.prank(alice);
        (uint256 returnedA, uint256 returnedB) = pool.removeLiquidity(liquidity, 0, 0, alice, block.timestamp + 1);

        assertGt(returnedA, 0);
        assertGt(returnedB, 0);
    }

    function testFuzz_GetAmountOutMatchesAssembly(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view {
        amountIn = bound(amountIn, 1, 1e24);
        reserveIn = bound(reserveIn, 1, 1e24);
        reserveOut = bound(reserveOut, 1, 1e24);

        assertEq(
            pool.getAmountOut(amountIn, reserveIn, reserveOut),
            pool.getAmountOutAssembly(amountIn, reserveIn, reserveOut)
        );
    }

    function test_GasBenchmark_SolidityVsAssembly() public {
        uint256 gasBefore = gasleft();
        for (uint256 i = 0; i < 1000; i++) {
            pool.getAmountOut(10 ether + i, 100 ether, 200 ether);
        }
        uint256 solidityGas = gasBefore - gasleft();

        gasBefore = gasleft();
        for (uint256 i = 0; i < 1000; i++) {
            pool.getAmountOutAssembly(10 ether + i, 100 ether, 200 ether);
        }
        uint256 assemblyGas = gasBefore - gasleft();

        emit log_named_uint("getAmountOut Solidity x1000", solidityGas);
        emit log_named_uint("getAmountOut Assembly x1000", assemblyGas);
    }

    function _deployPool(address token0, address token1)
        internal
        returns (AMMPool deployedPool, LPToken deployedLpToken)
    {
        AMMPool implementation = new AMMPool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        deployedLpToken = new LPToken(address(proxy));
        deployedPool = AMMPool(address(proxy));
        deployedPool.initialize(token0, token1, address(deployedLpToken));
    }

    function _mintAndApprove(address user, uint256 amountA, uint256 amountB) internal {
        tokenA.mint(user, amountA);
        tokenB.mint(user, amountB);
        vm.startPrank(user);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function _addInitialLiquidity() internal {
        vm.prank(alice);
        pool.addLiquidity(100 ether, 200 ether, 0, 0, alice, block.timestamp + 1);
    }

    function _addInitialLiquidityLarge() internal {
        vm.prank(alice);
        pool.addLiquidity(1_000_000 ether, 1_000_000 ether, 0, 0, alice, block.timestamp + 1);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract AMMInvariantTest is Test {
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    AMMPool internal pool;
    LPToken internal lpToken;
    AMMInvariantHandler internal handler;
    address internal alice = makeAddr("alice");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKNA");
        tokenB = new MockERC20("Token B", "TKNB");

        AMMPool implementation = new AMMPool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        lpToken = new LPToken(address(proxy));
        pool = AMMPool(address(proxy));
        pool.initialize(address(tokenA), address(tokenB), address(lpToken));

        tokenA.mint(alice, 2_000_000 ether);
        tokenB.mint(alice, 2_000_000 ether);
        vm.startPrank(alice);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        pool.addLiquidity(1_000_000 ether, 1_000_000 ether, 0, 0, alice, block.timestamp + 1);
        vm.stopPrank();

        handler = new AMMInvariantHandler(pool, tokenA, tokenB);
        targetContract(address(handler));
    }

    function invariant_KNeverDecreases() public {
        assertGe(pool.lastK(), handler.lastK());
    }

    function invariant_LPSupplyBacksNonZeroReserves() public view {
        (uint112 reserveA, uint112 reserveB,) = pool.getReserves();
        if (reserveA > 0 && reserveB > 0) {
            assertGt(lpToken.totalSupply(), pool.MINIMUM_LIQUIDITY());
        }
    }
}
