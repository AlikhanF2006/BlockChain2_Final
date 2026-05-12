// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title UUPS Upgrade Base Re-Export
/// @notice Thin wrapper that exposes OpenZeppelin's UUPSUpgradeable type under the project namespace.
/// @dev To upgrade: deploy new impl, call upgradeToAndCall(newImpl, data) from owner.
abstract contract ProxyAdmin is UUPSUpgradeable {}
