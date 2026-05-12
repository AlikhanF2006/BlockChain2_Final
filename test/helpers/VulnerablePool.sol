// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract VulnerablePool {
    mapping(address => uint256) public balanceOf;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balanceOf[msg.sender];
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH_TRANSFER_FAILED");
        balanceOf[msg.sender] = 0;
    }
}
