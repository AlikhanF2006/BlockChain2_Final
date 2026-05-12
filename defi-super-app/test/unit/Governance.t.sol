// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {Test} from "forge-std/Test.sol";

import {DeFiGovernor} from "../../src/governance/DeFiGovernor.sol";
import {DeFiTimelock} from "../../src/governance/DeFiTimelock.sol";
import {Treasury} from "../../src/governance/Treasury.sol";
import {GovToken} from "../../src/tokens/GovToken.sol";
import {MockERC20} from "../helpers/MockERC20.sol";

contract GovernanceTest is Test {
    GovToken internal token;
    DeFiTimelock internal timelock;
    DeFiGovernor internal governor;
    Treasury internal treasury;
    MockERC20 internal usdc;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal recipient = makeAddr("recipient");

    function setUp() public {
        token = new GovToken();
        timelock = new DeFiTimelock();
        governor = new DeFiGovernor(token, timelock);
        treasury = new Treasury(address(timelock));
        usdc = new MockERC20("USD Coin", "USDC");

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        token.transfer(alice, 500_000 ether);
        token.transfer(bob, 150_000 ether);
        token.transfer(carol, 50_000 ether);

        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);
        vm.prank(carol);
        token.delegate(carol);
        vm.roll(block.number + 1);

        usdc.mint(address(treasury), 10_000e6);
    }

    function test_FullGovernanceCycle() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _claimFeesProposal(1000e6);

        vm.prank(bob);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(Governor.ProposalState.Succeeded));

        governor.queue(targets, values, calldatas, keccak256(bytes(description)));
        assertEq(uint256(governor.state(proposalId)), uint256(Governor.ProposalState.Queued));

        vm.warp(block.timestamp + timelock.MIN_DELAY() + 1);
        governor.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(uint256(governor.state(proposalId)), uint256(Governor.ProposalState.Executed));
        assertEq(usdc.balanceOf(recipient), 1000e6);
    }

    function test_Proposal_Defeated_BelowQuorum() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _claimFeesProposal(1000e6);

        vm.prank(bob);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(Governor.ProposalState.Defeated));
    }

    function test_Proposal_RevertBeforeDelay() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _claimFeesProposal(1000e6);
        bytes32 descriptionHash = keccak256(bytes(description));

        vm.prank(bob);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.expectRevert();
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    function test_Proposal_RevertBelowThreshold() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _claimFeesProposal(1000e6);

        vm.prank(carol);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, description);
    }

    function test_VotingPower_SnapshotAtProposal() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _claimFeesProposal(1000e6);

        vm.prank(bob);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(bob);
        token.transfer(carol, 150_000 ether);

        vm.prank(bob);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 150_000 ether);
    }

    function test_TimelockDelay_Is2Days() public view {
        assertEq(timelock.getMinDelay(), 2 days);
    }

    function test_NoAdminBackdoor() public view {
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock)));
    }

    function testFuzz_VotingPower(uint256 delegateAmount) public {
        delegateAmount = bound(delegateAmount, 1, 1_000_000 ether);
        address delegatee = makeAddr("delegatee");
        token.transfer(delegatee, delegateAmount);
        vm.prank(delegatee);
        token.delegate(delegatee);
        vm.roll(block.number + 1);

        assertEq(token.getVotes(delegatee), delegateAmount);
    }

    function _claimFeesProposal(uint256 amount)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(Treasury.claimFees, (address(usdc), recipient, amount));
        description = "Claim protocol USDC fees";
    }
}
