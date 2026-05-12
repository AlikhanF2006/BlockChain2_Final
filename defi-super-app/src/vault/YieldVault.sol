// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {LendingPool} from "../lending/LendingPool.sol";

/// @title ERC-4626 Yield Vault
/// @notice Vault that forwards deposits into LendingPool and pulls liquidity back for withdrawals.
contract YieldVault is
    Initializable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    LendingPool public lendingPool;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address asset_, address lendingPool_) external initializer {
        __ERC20_init("DeFi Yield Vault", "DYV");
        __ERC4626_init(IERC20(asset_));
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();

        lendingPool = LendingPool(lendingPool_);
        IERC20(asset_).forceApprove(lendingPool_, type(uint256).max);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function totalAssets() public view override returns (uint256) {
        return lendingPool.deposits(address(this));
    }

    function maxDeposit(address user) public view override returns (uint256) {
        user;
        return paused() ? 0 : type(uint256).max;
    }

    function maxMint(address user) public view override returns (uint256) {
        user;
        return paused() ? 0 : type(uint256).max;
    }

    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        return super.mint(shares, receiver);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);
        lendingPool.deposit(assets);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal override {
        lendingPool.withdraw(assets);
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
