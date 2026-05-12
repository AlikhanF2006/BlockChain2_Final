// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/// @title DeFi Governance Token
/// @notice ERC20 governance token with EIP-2612 permits, vote checkpoints, and admin-controlled minting.
contract GovToken is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    /// @notice Initial governance token supply minted to the deployer.
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 1e18;

    /// @notice Creates the governance token and grants admin rights to the deployer.
    /// @dev Mints the complete initial supply to msg.sender and initializes the permit domain.
    constructor() ERC20("DeFi Gov Token", "DGT") ERC20Permit("DeFi Gov Token") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice Mints new governance tokens to an account.
    /// @dev Restricted to DEFAULT_ADMIN_ROLE.
    /// @param to Account receiving the minted tokens.
    /// @param amount Number of tokens to mint.
    function mint(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // CEI: checks, effects, interactions.
        _mint(to, amount);
    }

    /// @notice Returns the current permit nonce for an owner.
    /// @dev Resolves the multiple inheritance override required by ERC20Permit and Nonces.
    /// @param owner Account whose nonce is being queried.
    /// @return Current nonce used for EIP-2612 signatures.
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /// @notice Updates balances, total supply, and governance vote checkpoints.
    /// @dev Required by OpenZeppelin v5 when combining ERC20 and ERC20Votes.
    /// @param from Token sender, or zero address for minting.
    /// @param to Token recipient, or zero address for burning.
    /// @param value Amount of tokens being moved.
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }
}
