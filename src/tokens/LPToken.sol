// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title AMM Liquidity Provider Token
/// @notice ERC20 token representing AMM liquidity provider shares.
contract LPToken is ERC20 {
    /// @notice Reverts when a caller other than the AMM attempts a privileged action.
    /// @param caller Address that attempted the restricted action.
    error NotAMM(address caller);

    /// @notice Reverts when the AMM address is the zero address.
    error ZeroAMMAddress();

    /// @notice AMM contract allowed to mint and burn LP shares.
    address public immutable amm;

    /// @notice Creates the LP share token and binds minting and burning to one AMM.
    /// @param amm_ AMM contract authorized to mint and burn LP shares.
    constructor(address amm_) ERC20("DeFi AMM LP Token", "DLP") {
        if (amm_ == address(0)) {
            revert ZeroAMMAddress();
        }

        amm = amm_;
    }

    /// @notice Mints LP shares to a liquidity provider.
    /// @dev Callable only by the configured AMM contract.
    /// @param to Account receiving newly minted LP shares.
    /// @param amount Number of LP shares to mint.
    function mint(address to, uint256 amount) external onlyAMM {
        // CEI: checks, effects, interactions.
        _mint(to, amount);
    }

    /// @notice Burns LP shares from a liquidity provider.
    /// @dev Callable only by the configured AMM contract.
    /// @param from Account whose LP shares are burned.
    /// @param amount Number of LP shares to burn.
    function burn(address from, uint256 amount) external onlyAMM {
        // CEI: checks, effects, interactions.
        _burn(from, amount);
    }

    /// @notice Restricts a function to the configured AMM contract.
    /// @dev Reverts with NotAMM when msg.sender is not amm.
    modifier onlyAMM() {
        if (msg.sender != amm) {
            revert NotAMM(msg.sender);
        }
        _;
    }
}
