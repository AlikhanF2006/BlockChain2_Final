// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IChainlinkAdapter {
    function getPrice(address token) external view returns (uint256 price, uint8 decimals);
}

/// @title Chainlink Price Adapter
/// @notice Wraps Chainlink feeds with feed existence, positivity, and staleness checks.
contract ChainlinkAdapter is IChainlinkAdapter, Ownable {
    error StalePrice(address token, uint256 updatedAt);
    error InvalidPrice(address token, int256 answer);
    error FeedNotFound(address token);
    error LengthMismatch();

    uint256 public constant MAX_STALENESS = 3600;

    mapping(address => AggregatorV3Interface) public feeds;
    uint256 public maxStaleness;

    constructor(address[] memory tokens, address[] memory feedAddresses) Ownable(msg.sender) {
        if (tokens.length != feedAddresses.length) revert LengthMismatch();
        maxStaleness = MAX_STALENESS;
        for (uint256 i = 0; i < tokens.length; i++) {
            _addFeed(tokens[i], feedAddresses[i]);
        }
    }

    function getPrice(address token) external view returns (uint256 price, uint8 decimals) {
        AggregatorV3Interface feed = feeds[token];
        if (address(feed) == address(0)) revert FeedNotFound(token);

        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        if (block.timestamp - updatedAt > maxStaleness) revert StalePrice(token, updatedAt);
        if (answer <= 0) revert InvalidPrice(token, answer);

        return (uint256(answer), feed.decimals());
    }

    function addFeed(address token, address feed) external onlyOwner {
        // CEI: checks, effects, interactions.
        _addFeed(token, feed);
    }

    function setMaxStaleness(uint256 newMax) external onlyOwner {
        // CEI: checks, effects, interactions.
        maxStaleness = newMax;
    }

    function _addFeed(address token, address feed) internal {
        if (token == address(0) || feed == address(0)) revert FeedNotFound(token);
        feeds[token] = AggregatorV3Interface(feed);
    }
}
