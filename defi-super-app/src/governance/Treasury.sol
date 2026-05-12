// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Protocol Treasury
/// @notice Holds protocol fees and releases funds only through timelock-governed calls.
contract Treasury is AccessControl {
    using SafeERC20 for IERC20;

    error EthTransferFailed();
    error InvalidRecipient();

    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    address public immutable timelock;

    event FeesClaimed(address indexed token, address indexed to, uint256 amount);

    constructor(address timelock_) {
        if (timelock_ == address(0)) revert InvalidRecipient();
        timelock = timelock_;
        _grantRole(DEFAULT_ADMIN_ROLE, timelock_);
        _grantRole(TIMELOCK_ROLE, timelock_);
    }

    receive() external payable {}

    function claimFees(address token, address to, uint256 amount) external onlyRole(TIMELOCK_ROLE) {
        // CEI: checks, effects, interactions.
        if (to == address(0)) revert InvalidRecipient();
        if (token == address(0)) {
            (bool success,) = to.call{value: amount}("");
            if (!success) revert EthTransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        emit FeesClaimed(token, to, amount);
    }
}
