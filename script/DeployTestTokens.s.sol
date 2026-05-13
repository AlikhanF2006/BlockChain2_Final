// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name_, string memory symbol_, address receiver) ERC20(name_, symbol_) {
        _mint(receiver, 1_000_000 ether);
    }
}

contract DeployTestTokens is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast(deployer);

        TestToken tokenA = new TestToken("Token A", "TKNA", deployer);
        TestToken tokenB = new TestToken("Token B", "TKNB", deployer);
        TestToken collateral = new TestToken("Collateral Token", "COL", deployer);
        TestToken borrow = new TestToken("Borrow Token", "BRW", deployer);

        vm.stopBroadcast();

        console2.log("TOKEN_A=", address(tokenA));
        console2.log("TOKEN_B=", address(tokenB));
        console2.log("COLLATERAL_TOKEN=", address(collateral));
        console2.log("BORROW_TOKEN=", address(borrow));
    }
}
