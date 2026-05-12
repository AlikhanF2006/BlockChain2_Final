// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {Treasury} from "../../src/governance/Treasury.sol";
import {MockERC20} from "../helpers/MockERC20.sol";

contract RejectEth {
    receive() external payable {
        revert("reject");
    }
}

contract TreasuryTest is Test {
    Treasury internal treasury;
    MockERC20 internal token;

    event ETHClaimed(address indexed to, uint256 amount);

    address internal timelock = makeAddr("timelock");
    address internal recipient = makeAddr("recipient");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        treasury = new Treasury(timelock);
        token = new MockERC20("Fee Token", "FEE");
    }

    function test_ConstructorRevertZeroTimelock() public {
        vm.expectRevert(Treasury.InvalidRecipient.selector);
        new Treasury(address(0));
    }

    function test_ReceiveETH() public {
        vm.deal(address(this), 1 ether);

        (bool success,) = address(treasury).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(treasury).balance, 1 ether);
    }

    function test_ClaimERC20ByTimelock() public {
        token.mint(address(treasury), 1_000 ether);

        vm.prank(timelock);
        treasury.claimERC20(address(token), recipient, 400 ether);

        assertEq(token.balanceOf(recipient), 400 ether);
        assertEq(token.balanceOf(address(treasury)), 600 ether);
    }

    function test_ClaimERC20UnauthorizedReverts() public {
        token.mint(address(treasury), 1_000 ether);

        vm.prank(attacker);
        vm.expectRevert();
        treasury.claimERC20(address(token), recipient, 1 ether);
    }

    function test_ClaimETHByTimelock() public {
        vm.deal(address(treasury), 1 ether);

        vm.prank(timelock);
        treasury.claimETH(0.4 ether);

        assertEq(timelock.balance, 0.4 ether);
        assertEq(address(treasury).balance, 0.6 ether);
    }

    function test_ClaimETHPaysTimelockNotArbitraryRecipient() public {
        vm.deal(address(treasury), 1 ether);

        vm.prank(timelock);
        treasury.claimETH(0.4 ether);

        assertEq(timelock.balance, 0.4 ether);
        assertEq(recipient.balance, 0);
    }

    function test_ClaimETHCanClaimFullBalance() public {
        vm.deal(address(treasury), 1 ether);

        vm.prank(timelock);
        treasury.claimETH(1 ether);

        assertEq(timelock.balance, 1 ether);
        assertEq(address(treasury).balance, 0);
    }

    function test_ClaimETHEmitsTimelockRecipient() public {
        vm.deal(address(treasury), 1 ether);

        vm.expectEmit(true, false, false, true);
        emit ETHClaimed(timelock, 0.25 ether);
        vm.prank(timelock);
        treasury.claimETH(0.25 ether);
    }

    function test_ClaimETHSupportsMultipleClaimsToTimelock() public {
        vm.deal(address(treasury), 1 ether);

        vm.prank(timelock);
        treasury.claimETH(0.25 ether);
        vm.prank(timelock);
        treasury.claimETH(0.5 ether);

        assertEq(timelock.balance, 0.75 ether);
        assertEq(address(treasury).balance, 0.25 ether);
    }

    function test_ClaimETHUnauthorizedReverts() public {
        vm.deal(address(treasury), 1 ether);

        vm.prank(attacker);
        vm.expectRevert();
        treasury.claimETH(1 ether);
    }

    function test_ClaimERC20RevertInvalidRecipient() public {
        vm.prank(timelock);
        vm.expectRevert(Treasury.InvalidRecipient.selector);
        treasury.claimERC20(address(token), address(0), 1 ether);
    }

    function test_ClaimERC20RevertZeroAmount() public {
        vm.prank(timelock);
        vm.expectRevert(Treasury.InvalidAmount.selector);
        treasury.claimERC20(address(token), recipient, 0);
    }

    function test_ClaimETHRevertZeroAmount() public {
        vm.prank(timelock);
        vm.expectRevert(Treasury.InvalidAmount.selector);
        treasury.claimETH(0);
    }

    function test_ClaimERC20RevertZeroToken() public {
        vm.prank(timelock);
        vm.expectRevert(Treasury.InvalidRecipient.selector);
        treasury.claimERC20(address(0), recipient, 1 ether);
    }

    function test_ClaimETHRevertWhenRecipientRejects() public {
        RejectEth rejectEth = new RejectEth();
        Treasury rejectingTreasury = new Treasury(address(rejectEth));
        vm.deal(address(rejectingTreasury), 1 ether);

        vm.prank(address(rejectEth));
        vm.expectRevert(Treasury.EthTransferFailed.selector);
        rejectingTreasury.claimETH(1 ether);
    }
}
