// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "../../src/oracle/ChainlinkAdapter.sol";

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract ForkTest is Test {
    address internal constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address internal constant DAI_WHALE = 0x28C6c06298d514Db089934071355E5743bf21d60;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function test_Fork_ChainlinkFeed_LivePrice() public view {
        (, int256 answer,, uint256 updatedAt,) = AggregatorV3Interface(ETH_USD_FEED).latestRoundData();
        assertGt(answer, 0);
        assertGt(updatedAt, 0);
    }

    function test_Fork_USDC_TransferIntegration() public {
        address receiver = makeAddr("receiver");

        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(receiver, 100e6);

        assertEq(IERC20(USDC).balanceOf(receiver), 100e6);
    }

    function test_Fork_UniswapV2Router_Integration() public {
        address trader = makeAddr("trader");
        vm.prank(DAI_WHALE);
        IERC20(DAI).transfer(trader, 1_000 ether);

        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = WETH;

        vm.startPrank(trader);
        IERC20(DAI).approve(UNISWAP_V2_ROUTER, 1_000 ether);
        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(100 ether, 0, path, trader, block.timestamp + 1);
        vm.stopPrank();

        assertGt(IERC20(WETH).balanceOf(trader), 0);
    }
}
