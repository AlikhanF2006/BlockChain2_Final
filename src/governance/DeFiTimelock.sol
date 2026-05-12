// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title DeFi Timelock
/// @notice Governance execution delay controller.
/// @dev Role model:
/// PROPOSER_ROLE is granted to DeFiGovernor after deployment.
/// EXECUTOR_ROLE is granted to address(0), allowing anyone to execute queued operations after MIN_DELAY.
/// DEFAULT_ADMIN_ROLE is temporarily granted to the deployer for bootstrap role setup and must be revoked.
contract DeFiTimelock is TimelockController {
    uint256 public constant MIN_DELAY = 2 days;

    constructor() TimelockController(MIN_DELAY, new address[](0), new address[](0), address(0)) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
