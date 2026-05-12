// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract VulnerableAdmin {
    uint256 public protocolFee;

    function setProtocolFee(uint256 fee) external {
        protocolFee = fee;
    }
}
