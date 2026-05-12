// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

import {AMMPool} from "../../src/amm/AMMPool.sol";
import {LPToken} from "../../src/tokens/LPToken.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {MockReentrantToken} from "../helpers/MockReentrantToken.sol";
import {ReentrancyAttacker} from "../helpers/ReentrancyAttacker.sol";
import {VulnerablePool} from "../helpers/VulnerablePool.sol";

contract ReentrancySecurityTest is Test {
    address internal victim = makeAddr("victim");
    address internal attacker = makeAddr("attacker");

    function test_Reentrancy_AttackSucceeds_VulnerablePool() public {
        VulnerablePool pool = new VulnerablePool();
        ReentrancyAttacker exploit = new ReentrancyAttacker(pool);

        vm.deal(victim, 10 ether);
        vm.prank(victim);
        pool.deposit{value: 10 ether}();

        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        exploit.attack{value: 1 ether}();

        assertGt(address(exploit).balance, 1 ether);
        assertLt(address(pool).balance, 10 ether);
    }

    function test_Reentrancy_AttackFails_WithGuard() public {
        MockReentrantToken reentrant = new MockReentrantToken();
        MockERC20 paired = new MockERC20("Paired", "PAIR");
        (AMMPool pool,) = _deployPool(address(reentrant), address(paired));

        reentrant.mint(victim, 1_000 ether);
        paired.mint(victim, 1_000 ether);
        vm.startPrank(victim);
        reentrant.approve(address(pool), type(uint256).max);
        paired.approve(address(pool), type(uint256).max);
        pool.addLiquidity(100 ether, 100 ether, 0, 0, victim, block.timestamp + 1);
        vm.stopPrank();

        reentrant.mint(attacker, 10 ether);
        paired.mint(attacker, 10 ether);
        vm.startPrank(attacker);
        reentrant.approve(address(pool), type(uint256).max);
        paired.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        (uint112 reserveABefore, uint112 reserveBBefore,) = pool.getReserves();
        reentrant.configureAttack(address(pool), address(paired));
        reentrant.setAttackEnabled(true);

        vm.prank(attacker);
        vm.expectRevert();
        pool.swapExactTokensForTokens(1 ether, 0, address(reentrant), attacker, block.timestamp + 1);

        (uint112 reserveAAfter, uint112 reserveBAfter,) = pool.getReserves();
        assertEq(reserveAAfter, reserveABefore);
        assertEq(reserveBAfter, reserveBBefore);
    }

    function _deployPool(address token0, address token1) internal returns (AMMPool pool, LPToken lpToken) {
        AMMPool implementation = new AMMPool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        lpToken = new LPToken(address(proxy));
        pool = AMMPool(address(proxy));
        pool.initialize(token0, token1, address(lpToken));
    }
}
