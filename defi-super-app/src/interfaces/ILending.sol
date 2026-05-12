// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Lending Interface
/// @notice Minimal interface for the Super-App lending and borrowing module.
interface ILending {
    /// @notice Supplies an asset to the lending market.
    /// @param asset Token supplied.
    /// @param amount Amount supplied.
    /// @param onBehalfOf Account credited with the deposit.
    function supply(address asset, uint256 amount, address onBehalfOf) external;

    /// @notice Withdraws a supplied asset from the lending market.
    /// @param asset Token withdrawn.
    /// @param amount Amount withdrawn.
    /// @param to Account receiving the withdrawn asset.
    /// @return withdrawn Amount actually withdrawn.
    function withdraw(address asset, uint256 amount, address to) external returns (uint256 withdrawn);

    /// @notice Borrows an asset from the lending market.
    /// @param asset Token borrowed.
    /// @param amount Amount borrowed.
    /// @param to Account receiving the borrowed asset.
    function borrow(address asset, uint256 amount, address to) external;

    /// @notice Repays borrowed debt.
    /// @param asset Token repaid.
    /// @param amount Amount repaid.
    /// @param onBehalfOf Borrower whose debt is reduced.
    /// @return repaid Amount of debt repaid.
    function repay(address asset, uint256 amount, address onBehalfOf) external returns (uint256 repaid);
}
