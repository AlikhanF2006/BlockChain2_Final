// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {GovToken} from "../src/tokens/GovToken.sol";
import {LPToken} from "../src/tokens/LPToken.sol";

/// @title Deployment Script
/// @notice Deploys the token layer for the DeFi Super-App.
contract Deploy is Script {
    /// @notice Deploys GovToken and LPToken using the broadcaster as the AMM placeholder for LPToken.
    /// @return govToken Deployed governance token.
    /// @return lpToken Deployed LP token.
    function run() external returns (GovToken govToken, LPToken lpToken) {
        vm.startBroadcast();

        govToken = new GovToken();
        lpToken = new LPToken(msg.sender);

        vm.stopBroadcast();
    }
}
