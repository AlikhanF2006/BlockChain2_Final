// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {AMMFactory} from "../src/amm/AMMFactory.sol";
import {ChainlinkAdapter} from "../src/oracle/ChainlinkAdapter.sol";
import {DeFiGovernor} from "../src/governance/DeFiGovernor.sol";
import {DeFiTimelock} from "../src/governance/DeFiTimelock.sol";
import {GovToken} from "../src/tokens/GovToken.sol";
import {InterestRateModel} from "../src/lending/InterestRateModel.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";
import {YieldVault} from "../src/vault/YieldVault.sol";

/// @title Full Protocol Deployment Script
/// @notice Deploys the DeFi Super-App to Arbitrum Sepolia and writes deployments/421614.json.
/// @dev Dependency graph and deployment order:
/// 1. GovToken: no dependencies.
/// 2. InterestRateModel: no dependencies.
/// 3. ChainlinkAdapter: no dependencies; feeds are added after token addresses are known.
/// 4. AMMFactory: no dependencies.
/// 5. DeFiTimelock: no dependencies; bootstrap admin is deployer then revoked.
/// 6. DeFiGovernor: depends on GovToken and DeFiTimelock.
/// 7. Timelock roles: Governor becomes proposer, address(0) executor, deployer admin revoked.
/// 8. LendingPool implementation + ERC1967Proxy: proxy deployed with deterministic CREATE2 salt.
/// 9. LendingPool proxy initialized with collateral, borrow token, oracle, and rate model.
/// 10. YieldVault implementation + ERC1967Proxy: proxy deployed with deterministic CREATE2 salt.
/// 11. YieldVault proxy initialized with borrow token and LendingPool.
/// 12. LendingPool ownership transferred to Timelock.
/// 13. YieldVault ownership transferred to Timelock.
/// 14. AMM pair created through AMMFactory for tokenA/tokenB.
/// 15. Chainlink ETH/USD feed added for Arbitrum Sepolia.
/// 16. GovToken mint role transferred to Timelock.
/// 17. deployments/421614.json written for frontend, scripts, and verification.
contract Deploy is Script {
    bytes32 internal constant LENDING_IMPL_SALT = keccak256("defi-super-app.lending.impl.v1");
    bytes32 internal constant LENDING_PROXY_SALT = keccak256("defi-super-app.lending.proxy.v1");
    bytes32 internal constant VAULT_IMPL_SALT = keccak256("defi-super-app.vault.impl.v1");
    bytes32 internal constant VAULT_PROXY_SALT = keccak256("defi-super-app.vault.proxy.v1");
    address internal constant ARBITRUM_SEPOLIA_ETH_USD_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    struct Tokens {
        address tokenA;
        address tokenB;
        address collateralToken;
        address borrowToken;
    }

    struct Core {
        GovToken govToken;
        InterestRateModel interestRateModel;
        ChainlinkAdapter oracle;
        AMMFactory ammFactory;
    }

    struct Governance {
        DeFiTimelock timelock;
        DeFiGovernor governor;
    }

    struct LendingDeployment {
        LendingPool implementation;
        LendingPool lendingPool;
    }

    struct VaultDeployment {
        YieldVault implementation;
        YieldVault yieldVault;
    }

    Tokens internal tokens;
    Core internal core;
    Governance internal governance;
    LendingDeployment internal lending;
    VaultDeployment internal vault;
    address internal pair;

    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        _loadTokens();

        vm.startBroadcast(deployer);

        _deployCore();
        _deployGovernance();
        _setupRoles(deployer);

        _deployLending();
        _deployVault();

        lending.lendingPool.transferOwnership(address(governance.timelock));
        vault.yieldVault.transferOwnership(address(governance.timelock));

        _setupAmmAndOracle();
        _transferMintRole(deployer);
        _writeDeployments();

        vm.stopBroadcast();

        console2.log("Deployment complete. Addresses written to deployments/421614.json");
    }

    function _loadTokens() internal {
        tokens = Tokens({
            tokenA: vm.envAddress("TOKEN_A"),
            tokenB: vm.envAddress("TOKEN_B"),
            collateralToken: vm.envAddress("COLLATERAL_TOKEN"),
            borrowToken: vm.envAddress("BORROW_TOKEN")
        });
    }

    function _deployCore() internal {
        core.govToken = new GovToken();
        core.interestRateModel = new InterestRateModel();
        core.oracle = new ChainlinkAdapter(new address[](0), new address[](0));
        core.ammFactory = new AMMFactory();
    }

    function _deployGovernance() internal {
        governance.timelock = new DeFiTimelock();
        governance.governor = new DeFiGovernor(core.govToken, governance.timelock);
    }

    function _setupRoles(address deployer) internal {
        governance.timelock.grantRole(governance.timelock.PROPOSER_ROLE(), address(governance.governor));
        governance.timelock.grantRole(governance.timelock.EXECUTOR_ROLE(), address(0));
        governance.timelock.revokeRole(governance.timelock.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _deployLending() internal {
        lending.implementation = _deployLendingImplementation();
        lending.lendingPool = LendingPool(
            _deployProxy(
                LENDING_PROXY_SALT,
                address(lending.implementation),
                abi.encodeCall(
                    LendingPool.initialize,
                    (tokens.collateralToken, tokens.borrowToken, address(core.oracle), address(core.interestRateModel))
                )
            )
        );
    }

    function _deployVault() internal {
        vault.implementation = _deployVaultImplementation();
        vault.yieldVault = YieldVault(
            _deployProxy(
                VAULT_PROXY_SALT,
                address(vault.implementation),
                abi.encodeCall(YieldVault.initialize, (tokens.borrowToken, address(lending.lendingPool)))
            )
        );
    }

    function _setupAmmAndOracle() internal {
        pair = core.ammFactory.getPair(tokens.tokenA, tokens.tokenB);
        if (pair == address(0)) {
            pair = core.ammFactory.createPair(tokens.tokenA, tokens.tokenB);
        }

        core.oracle.addFeed(tokens.collateralToken, ARBITRUM_SEPOLIA_ETH_USD_FEED);
        core.oracle.addFeed(tokens.borrowToken, ARBITRUM_SEPOLIA_ETH_USD_FEED);
    }

    function _transferMintRole(address deployer) internal {
        bytes32 mintRole = core.govToken.DEFAULT_ADMIN_ROLE();
        core.govToken.grantRole(mintRole, address(governance.timelock));
        core.govToken.renounceRole(mintRole, deployer);
    }

    function _deployLendingImplementation() internal returns (LendingPool implementation) {
        address predicted = vm.computeCreate2Address(LENDING_IMPL_SALT, keccak256(type(LendingPool).creationCode));
        if (predicted.code.length > 0) return LendingPool(predicted);
        return new LendingPool{salt: LENDING_IMPL_SALT}();
    }

    function _deployVaultImplementation() internal returns (YieldVault implementation) {
        address predicted = vm.computeCreate2Address(VAULT_IMPL_SALT, keccak256(type(YieldVault).creationCode));
        if (predicted.code.length > 0) return YieldVault(predicted);
        return new YieldVault{salt: VAULT_IMPL_SALT}();
    }

    function _deployProxy(bytes32 salt, address implementation, bytes memory initData)
        internal
        returns (address proxy)
    {
        bytes memory creationCode = abi.encodePacked(
            type(ERC1967Proxy).creationCode, abi.encode(implementation, initData)
        );
        address predicted = vm.computeCreate2Address(salt, keccak256(creationCode));
        if (predicted.code.length > 0) return predicted;
        return address(new ERC1967Proxy{salt: salt}(implementation, initData));
    }

    function _writeDeployments() internal {
        vm.writeFile(
            "deployments/421614.json",
            string.concat(_deploymentHeader(), _coreEntries(), _governanceEntries(), _proxyEntries(), "\n  }\n}\n")
        );
    }

    function _deploymentHeader() internal view returns (string memory) {
        return string.concat(
            "{\n",
            '  "network": "arbitrum-sepolia",\n',
            '  "chainId": 421614,\n',
            '  "deployedAt": "',
            vm.toString(block.number),
            '",\n',
            '  "contracts": {\n'
        );
    }

    function _coreEntries() internal view returns (string memory) {
        return string.concat(
            _namedEntry("GovToken", address(core.govToken), true),
            _namedEntry("InterestRateModel", address(core.interestRateModel), true),
            _namedEntry("ChainlinkAdapter", address(core.oracle), true),
            _namedEntry("AMMFactory", address(core.ammFactory), true),
            _namedEntry("AMMPool", pair, true)
        );
    }

    function _governanceEntries() internal view returns (string memory) {
        return string.concat(
            _namedEntry("DeFiTimelock", address(governance.timelock), true),
            _namedEntry("DeFiGovernor", address(governance.governor), true)
        );
    }

    function _proxyEntries() internal view returns (string memory) {
        return string.concat(
            _namedProxyEntry("LendingPool", address(lending.lendingPool), address(lending.implementation), true),
            _namedProxyEntry("YieldVault", address(vault.yieldVault), address(vault.implementation), false)
        );
    }

    function _namedEntry(string memory name, address account, bool comma) internal view returns (string memory) {
        return string.concat('    "', name, '": ', _entry(account), comma ? ",\n" : "\n");
    }

    function _namedProxyEntry(string memory name, address proxy, address implementation, bool comma)
        internal
        view
        returns (string memory)
    {
        return string.concat('    "', name, '": ', _proxyEntry(proxy, implementation), comma ? ",\n" : "\n");
    }

    function _entry(address account) internal view returns (string memory) {
        return string.concat(
            '{"address":"',
            vm.toString(account),
            '","blockExplorer":"https://sepolia.arbiscan.io/address/',
            vm.toString(account),
            '"}'
        );
    }

    function _proxyEntry(address proxy, address implementation) internal view returns (string memory) {
        return string.concat(
            '{"proxy":"',
            vm.toString(proxy),
            '","implementation":"',
            vm.toString(implementation),
            '","blockExplorer":"https://sepolia.arbiscan.io/address/',
            vm.toString(proxy),
            '"}'
        );
    }
}
