// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

contract MockPriceFeed {
    uint8 public immutable decimals;
    int256 public immutable answer;

    constructor(uint8 decimals_, int256 answer_) {
        decimals = decimals_;
        answer = answer_;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, answer, block.timestamp, block.timestamp, 1);
    }
}

contract DeployMockFeeds is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast(deployer);

        MockPriceFeed collateralFeed = new MockPriceFeed(8, 2000e8);
        MockPriceFeed borrowFeed = new MockPriceFeed(8, 1e8);

        vm.stopBroadcast();

        console2.log("COLLATERAL_FEED=", address(collateralFeed));
        console2.log("BORROW_FEED=", address(borrowFeed));
    }
}
