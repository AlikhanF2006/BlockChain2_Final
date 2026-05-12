// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "../../src/oracle/ChainlinkAdapter.sol";

contract MockAggregator is AggregatorV3Interface {
    uint8 public immutable override decimals;
    int256 internal answer;
    uint256 internal updatedAt;

    constructor(uint8 decimals_, int256 answer_) {
        decimals = decimals_;
        answer = answer_;
        updatedAt = block.timestamp;
    }

    function setAnswer(int256 answer_) external {
        answer = answer_;
    }

    function setUpdatedAt(uint256 updatedAt_) external {
        updatedAt = updatedAt_;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer_, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}
