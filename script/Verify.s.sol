// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {DeFiGovernor} from "../src/governance/DeFiGovernor.sol";
import {DeFiTimelock} from "../src/governance/DeFiTimelock.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";
import {YieldVault} from "../src/vault/YieldVault.sol";

contract Verify is Script {
    error VerificationFailed(string check);

    function run() external view {
        string memory json = vm.readFile("deployments/421614.json");
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address timelockAddress = vm.parseJsonAddress(json, ".contracts.DeFiTimelock.address");
        address governorAddress = vm.parseJsonAddress(json, ".contracts.DeFiGovernor.address");
        address lendingPoolAddress = vm.parseJsonAddress(json, ".contracts.LendingPool.proxy");
        address yieldVaultAddress = vm.parseJsonAddress(json, ".contracts.YieldVault.proxy");

        DeFiTimelock timelock = DeFiTimelock(payable(timelockAddress));
        DeFiGovernor governor = DeFiGovernor(payable(governorAddress));
        LendingPool lendingPool = LendingPool(lendingPoolAddress);
        YieldVault yieldVault = YieldVault(yieldVaultAddress);

        _require(timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddress), "Governor is not timelock proposer");
        _require(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)), "Timelock executor is not open");
        _require(!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), deployer), "Deployer admin backdoor remains");
        _require(timelock.getMinDelay() == 2 days, "Timelock delay is not 2 days");
        _require(governor.votingDelay() == 7200, "Governor votingDelay mismatch");
        _require(governor.votingPeriod() == 50400, "Governor votingPeriod mismatch");
        _require(governor.quorumNumerator() == 4, "Governor quorum numerator mismatch");
        _require(lendingPool.owner() == timelockAddress, "LendingPool owner is not timelock");
        _require(yieldVault.owner() == timelockAddress, "YieldVault owner is not timelock");

        console2.log(unicode"✓ All checks passed — no admin backdoor remains");
    }

    function _require(bool condition, string memory message) internal pure {
        if (!condition) revert VerificationFailed(message);
    }
}
