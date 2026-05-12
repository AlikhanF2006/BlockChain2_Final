// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Protocol Treasury
/// @notice Holds protocol fees and releases funds only through timelock-governed calls.
contract Treasury is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error EthTransferFailed();
    error InvalidAmount();
    error InvalidRecipient();

    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    address public immutable timelock;

    event ETHClaimed(address indexed to, uint256 amount);
    event ERC20Claimed(address indexed token, address indexed to, uint256 amount);

    constructor(address timelock_) {
        if (timelock_ == address(0)) revert InvalidRecipient();

        timelock = timelock_;
        _grantRole(DEFAULT_ADMIN_ROLE, timelock_);
        _grantRole(TIMELOCK_ROLE, timelock_);
    }

    receive() external payable {}

    function claimETH(uint256 amount) external nonReentrant onlyRole(TIMELOCK_ROLE) {
        if (amount == 0) revert InvalidAmount();

        emit ETHClaimed(timelock, amount);

        // slither-disable-next-line arbitrary-send-eth
        // slither-disable-next-line low-level-calls
        (bool success,) = payable(timelock).call{value: amount}("");
        if (!success) revert EthTransferFailed();
    }

    function claimERC20(address token, address to, uint256 amount) external nonReentrant onlyRole(TIMELOCK_ROLE) {
        _validateClaim(to, amount);

        if (token == address(0)) revert InvalidRecipient();

        emit ERC20Claimed(token, to, amount);
        IERC20(token).safeTransfer(to, amount);
    }

    function _validateClaim(address to, uint256 amount) internal pure {
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
    }
}
