// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Test} from "forge-std/Test.sol";

import {DeFiGovernor} from "../../src/governance/DeFiGovernor.sol";
import {DeFiTimelock} from "../../src/governance/DeFiTimelock.sol";
import {Treasury} from "../../src/governance/Treasury.sol";
import {GovToken} from "../../src/tokens/GovToken.sol";
import {MockERC20} from "../helpers/MockERC20.sol";

contract GovernanceParamsTest is Test {
    GovToken internal token;
    DeFiTimelock internal timelock;
    DeFiGovernor internal governor;
    Treasury internal treasury;
    MockERC20 internal usdc;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
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
        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);
        vm.roll(block.number + 1);

        usdc.mint(address(treasury), 10_000e6);
    }

    function test_GovernorParameters() public view {
        assertEq(governor.votingDelay(), governor.VOTING_DELAY_BLOCKS());
        assertEq(governor.votingPeriod(), governor.VOTING_PERIOD_BLOCKS());
        assertEq(governor.proposalThreshold(), governor.PROPOSAL_THRESHOLD());
        assertEq(governor.quorumNumerator(), governor.QUORUM_NUMERATOR());
    }

    function test_GovernorQuorumReflectsFourPercent() public view {
        uint256 expected = token.totalSupply() * governor.QUORUM_NUMERATOR() / governor.quorumDenominator();

        assertEq(governor.quorum(block.number - 1), expected);
    }

    function test_GovernorSupportsInterface() public view {
        assertTrue(governor.supportsInterface(type(IGovernor).interfaceId));
    }

    function test_ProposalStatePendingAndActive() public {
        uint256 proposalId = _createProposal();
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        vm.roll(block.number + governor.votingDelay() + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
    }

    function test_ProposalNeedsQueuingAfterSuccess() public {
        uint256 proposalId = _createProposal();
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        assertTrue(governor.proposalNeedsQueuing(proposalId));
    }

    function _createProposal() internal returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(treasury);
        calldatas[0] = abi.encodeCall(Treasury.claimERC20, (address(usdc), recipient, 1000e6));

        vm.prank(bob);
        proposalId = governor.propose(targets, values, calldatas, "Claim protocol USDC fees");
    }
}
