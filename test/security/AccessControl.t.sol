// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

import {AMMPoolV2} from "../../src/amm/AMMPoolV2.sol";
import {DeFiTimelock} from "../../src/governance/DeFiTimelock.sol";
import {LPToken} from "../../src/tokens/LPToken.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {VulnerableAdmin} from "../helpers/VulnerableAdmin.sol";

contract AccessControlSecurityTest is Test {
    address internal attacker = makeAddr("attacker");
    address internal feeTo = makeAddr("feeTo");

    function test_AccessControl_AnyoneCanCallVulnerable() public {
        VulnerableAdmin vulnerable = new VulnerableAdmin();

        vm.prank(attacker);
        vulnerable.setProtocolFee(10000);

        assertEq(vulnerable.protocolFee(), 10000);
    }

    function test_AccessControl_OnlyOwnerCanSetFee() public {
        AMMPoolV2 pool = new AMMPoolV2();

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), attacker));
        pool.setProtocolFee(true, attacker);
    }

    function test_AccessControl_TimelockOwnsAMM() public {
        (AMMPoolV2 pool,) = _deployPoolV2();
        DeFiTimelock timelock = new DeFiTimelock();
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(this));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        pool.transferOwnership(address(timelock));
        assertEq(pool.owner(), address(timelock));

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), address(this)));
        pool.setProtocolFee(true, feeTo);

        bytes memory data = abi.encodeCall(AMMPoolV2.setProtocolFee, (true, feeTo));
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("set-protocol-fee");
        timelock.schedule(address(pool), 0, data, predecessor, salt, timelock.MIN_DELAY());

        vm.warp(block.timestamp + timelock.MIN_DELAY() + 1);
        timelock.execute(address(pool), 0, data, predecessor, salt);

        assertTrue(pool.protocolFeeEnabled());
        assertEq(pool.feeTo(), feeTo);
    }

    function _deployPoolV2() internal returns (AMMPoolV2 pool, LPToken lpToken) {
        MockERC20 tokenA = new MockERC20("Token A", "TKNA");
        MockERC20 tokenB = new MockERC20("Token B", "TKNB");
        AMMPoolV2 implementation = new AMMPoolV2();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        lpToken = new LPToken(address(proxy));
        pool = AMMPoolV2(address(proxy));
        pool.initialize(address(tokenA), address(tokenB), address(lpToken));
    }
}
