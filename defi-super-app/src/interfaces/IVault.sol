// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Vault Interface
/// @notice Minimal interface for the Super-App yield vault module.
interface IVault {
    /// @notice Deposits assets into the vault.
    /// @param assets Amount of underlying assets supplied.
    /// @param receiver Account receiving vault shares.
    /// @return shares Amount of vault shares minted.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Withdraws assets from the vault.
    /// @param assets Amount of underlying assets withdrawn.
    /// @param receiver Account receiving underlying assets.
    /// @param owner Account whose vault shares are burned.
    /// @return shares Amount of vault shares burned.
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /// @notice Returns the total amount of underlying assets managed by the vault.
    /// @return assets Total managed assets.
    function totalAssets() external view returns (uint256 assets);
}
