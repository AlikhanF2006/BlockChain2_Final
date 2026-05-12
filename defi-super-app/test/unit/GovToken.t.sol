// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GovToken} from "../../src/tokens/GovToken.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

/// @title GovToken Unit Tests
/// @notice Unit test coverage for initial supply, permits, delegation, minting access, vote movement, and transfers.
contract GovTokenTest is TestHelpers {
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    GovToken internal token;

    uint256 internal alicePrivateKey;
    address internal aliceSigner;

    /// @notice Deploys a new governance token before each test.
    function setUp() public {
        alicePrivateKey = 0xA11CE;
        aliceSigner = vm.addr(alicePrivateKey);
        alice = aliceSigner;

        vm.prank(deployer);
        token = new GovToken();
    }

    /// @notice Verifies the full initial supply is minted to the deployer.
    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(token.balanceOf(deployer), token.INITIAL_SUPPLY());
    }

    /// @notice Verifies an EIP-2612 permit signature sets allowance and consumes the nonce.
    function test_Permit() public {
        uint256 amount = 1_000 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(alice);

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, alice, bob, amount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        token.permit(alice, bob, amount, deadline, v, r, s);

        assertEq(token.allowance(alice, bob), amount);
        assertEq(token.nonces(alice), nonce + 1);
    }

    /// @notice Verifies token holders can delegate voting power to themselves.
    function test_Delegate() public {
        uint256 amount = 100 ether;

        vm.prank(deployer);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.delegate(alice);

        assertEq(token.getVotes(alice), amount);
    }

    /// @notice Verifies only the default admin can mint new governance tokens.
    function test_MintOnlyAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1 ether);

        vm.prank(deployer);
        token.mint(alice, 1 ether);

        assertEq(token.balanceOf(alice), 1 ether);
    }

    /// @notice Verifies delegated votes move correctly when delegated token balances transfer.
    function test_VotesTrackTransfer() public {
        uint256 amount = 100 ether;
        uint256 transferAmount = 40 ether;

        vm.startPrank(deployer);
        token.transfer(alice, amount);
        token.delegate(deployer);
        vm.stopPrank();

        vm.prank(alice);
        token.delegate(alice);

        assertEq(token.getVotes(alice), amount);

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.getVotes(alice), amount - transferAmount);
        assertEq(token.getVotes(bob), 0);

        vm.prank(bob);
        token.delegate(bob);

        assertEq(token.getVotes(bob), transferAmount);
    }

    /// @notice Fuzzes transfers from the deployer to arbitrary non-zero recipients.
    /// @param to Recipient address.
    /// @param amount Requested transfer amount.
    function testFuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 0, token.balanceOf(deployer));

        vm.prank(deployer);
        bool success = token.transfer(to, amount);

        assertTrue(success);
        assertEq(token.balanceOf(to), to == deployer ? token.INITIAL_SUPPLY() : amount);
    }
}
