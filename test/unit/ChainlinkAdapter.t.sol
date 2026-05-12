// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ChainlinkAdapter} from "../../src/oracle/ChainlinkAdapter.sol";
import {MockAggregator} from "../helpers/MockAggregator.sol";

contract ChainlinkAdapterTest is Test {
    ChainlinkAdapter internal adapter;
    MockAggregator internal feed;

    address internal token = makeAddr("token");
    address internal otherToken = makeAddr("otherToken");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        vm.warp(10_000);
        feed = new MockAggregator(8, 2_000e8);

        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);
        tokens[0] = token;
        feeds[0] = address(feed);
        adapter = new ChainlinkAdapter(tokens, feeds);
    }

    function test_ConstructorRevertLengthMismatch() public {
        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](0);

        vm.expectRevert(ChainlinkAdapter.LengthMismatch.selector);
        new ChainlinkAdapter(tokens, feeds);
    }

    function test_AddFeedSuccess() public {
        MockAggregator newFeed = new MockAggregator(18, 1 ether);

        adapter.addFeed(otherToken, address(newFeed));

        assertEq(address(adapter.feeds(otherToken)), address(newFeed));
    }

    function test_AddFeedUnauthorizedReverts() public {
        MockAggregator newFeed = new MockAggregator(18, 1 ether);

        vm.prank(attacker);
        vm.expectRevert();
        adapter.addFeed(otherToken, address(newFeed));
    }

    function test_AddFeedRevertZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.FeedNotFound.selector, address(0)));
        adapter.addFeed(address(0), address(feed));
    }

    function test_GetPriceSuccessAndDecimals() public view {
        (uint256 price, uint8 decimals) = adapter.getPrice(token);

        assertEq(price, 2_000e8);
        assertEq(decimals, 8);
    }

    function test_GetPriceRevertStalePrice() public {
        feed.setUpdatedAt(block.timestamp - adapter.maxStaleness() - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkAdapter.StalePrice.selector, token, block.timestamp - adapter.maxStaleness() - 1
            )
        );
        adapter.getPrice(token);
    }

    function test_GetPriceRevertNegativePrice() public {
        feed.setAnswer(-1);

        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.InvalidPrice.selector, token, int256(-1)));
        adapter.getPrice(token);
    }

    function test_GetPriceRevertMissingFeed() public {
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.FeedNotFound.selector, otherToken));
        adapter.getPrice(otherToken);
    }

    function test_SetMaxStaleness() public {
        adapter.setMaxStaleness(7200);

        assertEq(adapter.maxStaleness(), 7200);
    }

    function test_SetMaxStalenessUnauthorizedReverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        adapter.setMaxStaleness(7200);
    }
}
