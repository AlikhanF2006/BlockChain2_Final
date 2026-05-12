// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AMMPool} from "../src/amm/AMMPool.sol";
import {DeFiGovernor} from "../src/governance/DeFiGovernor.sol";
import {GovToken} from "../src/tokens/GovToken.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";

contract GasBenchmark is Script {
    struct Result {
        uint256 ammSwap;
        uint256 addLiquidity;
        uint256 lendingDeposit;
        uint256 lendingBorrow;
        uint256 propose;
        uint256 castVote;
    }

    function run() external {
        uint256 arbFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));

        Result memory l2 = _measure(arbFork, "L2");
        Result memory l1 = _measure(mainnetFork, "L1");

        console2.log("Operation                 | L1 Gas | L2 Gas | Savings");
        _print("AMM Swap", l1.ammSwap, l2.ammSwap);
        _print("AMM addLiquidity", l1.addLiquidity, l2.addLiquidity);
        _print("Lending deposit", l1.lendingDeposit, l2.lendingDeposit);
        _print("Lending borrow", l1.lendingBorrow, l2.lendingBorrow);
        _print("Governor propose", l1.propose, l2.propose);
        _print("Governor castVote", l1.castVote, l2.castVote);
    }

    function _measure(uint256 forkId, string memory label) internal returns (Result memory result) {
        vm.selectFork(forkId);
        string memory json = vm.readFile("deployments/421614.json");
        address user = vm.envAddress("BENCHMARK_USER");
        AMMPool amm = AMMPool(vm.parseJsonAddress(json, ".contracts.AMMPool.address"));
        LendingPool lending = LendingPool(vm.parseJsonAddress(json, ".contracts.LendingPool.proxy"));
        DeFiGovernor governor = DeFiGovernor(payable(vm.parseJsonAddress(json, ".contracts.DeFiGovernor.address")));
        GovToken govToken = GovToken(vm.parseJsonAddress(json, ".contracts.GovToken.address"));
        address tokenA = vm.envAddress("TOKEN_A");
        address tokenB = vm.envAddress("TOKEN_B");
        address borrowToken = vm.envAddress("BORROW_TOKEN");

        vm.startPrank(user);
        IERC20(tokenA).approve(address(amm), type(uint256).max);
        IERC20(tokenB).approve(address(amm), type(uint256).max);
        IERC20(borrowToken).approve(address(lending), type(uint256).max);

        uint256 gasBefore = gasleft();
        try amm.swapExactTokensForTokens(1e15, 0, tokenA, user, block.timestamp + 1200) {} catch {}
        result.ammSwap = gasBefore - gasleft();

        gasBefore = gasleft();
        try amm.addLiquidity(1e15, 1e15, 0, 0, user, block.timestamp + 1200) {} catch {}
        result.addLiquidity = gasBefore - gasleft();

        gasBefore = gasleft();
        try lending.deposit(1e15) {} catch {}
        result.lendingDeposit = gasBefore - gasleft();

        gasBefore = gasleft();
        try lending.borrow(1e12) {} catch {}
        result.lendingBorrow = gasBefore - gasleft();

        address[] memory targets = new address[](1);
        targets[0] = address(govToken);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(GovToken.mint, (user, 1 ether));

        gasBefore = gasleft();
        uint256 proposalId;
        try governor.propose(targets, values, calldatas, string.concat("Benchmark ", label)) returns (uint256 id) {
            proposalId = id;
        } catch {}
        result.propose = gasBefore - gasleft();

        vm.roll(block.number + governor.votingDelay() + 1);
        gasBefore = gasleft();
        if (proposalId != 0) {
            try governor.castVote(proposalId, 1) {} catch {}
        }
        result.castVote = gasBefore - gasleft();

        vm.stopPrank();
    }

    function _print(string memory op, uint256 l1Gas, uint256 l2Gas) internal view {
        uint256 savings = l1Gas > l2Gas && l1Gas != 0 ? ((l1Gas - l2Gas) * 100) / l1Gas : 0;
        console2.log(op);
        console2.log("  L1 Gas:", l1Gas);
        console2.log("  L2 Gas:", l2Gas);
        console2.log("  Savings %:", savings);
    }
}
