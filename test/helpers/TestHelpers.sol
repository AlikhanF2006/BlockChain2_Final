// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

/// @title Test Helpers
/// @notice Shared addresses and utility helpers for Foundry tests.
abstract contract TestHelpers is Test {
    /// @notice Default deployer test account.
    address internal deployer = makeAddr("deployer");

    /// @notice First user test account.
    address internal alice = makeAddr("alice");

    /// @notice Second user test account.
    address internal bob = makeAddr("bob");

    /// @notice Third user test account.
    address internal carol = makeAddr("carol");

    /// @notice Gives ERC20 tokens to an account by directly setting the token balance storage slot.
    /// @param token ERC20 token address.
    /// @param to Account receiving the token balance.
    /// @param amount Token amount to assign.
    function dealTokens(address token, address to, uint256 amount) internal {
        deal(token, to, amount, true);
    }

    /// @notice Starts impersonating a caller for subsequent calls.
    /// @param caller Account to impersonate.
    function prankAs(address caller) internal {
        vm.startPrank(caller);
    }

    /// @notice Stops the current caller impersonation.
    function stopPrank() internal {
        vm.stopPrank();
    }

    /// @notice Executes a single ERC20 transfer as an impersonated caller.
    /// @param token ERC20 token being transferred.
    /// @param caller Account sending the transfer.
    /// @param to Account receiving the transfer.
    /// @param amount Amount transferred.
    function prankTransfer(address token, address caller, address to, uint256 amount) internal {
        vm.prank(caller);
        IERC20(token).transfer(to, amount);
    }
}
