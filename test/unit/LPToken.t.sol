// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {LPToken} from "../../src/tokens/LPToken.sol";

contract LPTokenTest is Test {
    LPToken internal lpToken;

    address internal amm = makeAddr("amm");
    address internal alice = makeAddr("alice");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        lpToken = new LPToken(amm);
    }

    function test_ConstructorRevertZeroAMM() public {
        vm.expectRevert(LPToken.ZeroAMMAddress.selector);
        new LPToken(address(0));
    }

    function test_MintOnlyAMM() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(LPToken.NotAMM.selector, attacker));
        lpToken.mint(alice, 1 ether);

        vm.prank(amm);
        lpToken.mint(alice, 1 ether);

        assertEq(lpToken.balanceOf(alice), 1 ether);
    }

    function test_BurnOnlyAMM() public {
        vm.prank(amm);
        lpToken.mint(alice, 1 ether);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(LPToken.NotAMM.selector, attacker));
        lpToken.burn(alice, 1 ether);

        vm.prank(amm);
        lpToken.burn(alice, 0.4 ether);

        assertEq(lpToken.balanceOf(alice), 0.6 ether);
    }
}
