// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMMPool} from "./AMMPool.sol";

/// @title Constant Product AMM Pool V2
/// @notice Upgrade demonstration that appends protocol-fee storage to AMMPool.
/// @dev V1 storage is preserved exactly:
/// slot 0: Initializable bookkeeping
/// slot 1: OwnableUpgradeable owner
/// slot 2: ReentrancyGuardUpgradeable status
/// slot 3: tokenA
/// slot 4: tokenB
/// slot 5: reserveA | reserveB | blockTimestampLast
/// slot 6: lpToken
/// slot 7: kLast
/// V2 appends:
/// slot 8: bool protocolFeeEnabled
/// slot 9: address feeTo
/// Appending after V1 slot 7 prevents collisions with existing proxy state.
contract AMMPoolV2 is AMMPool {
    bool public protocolFeeEnabled;
    address public feeTo;

    event ProtocolFeeSet(bool enabled, address indexed feeTo);

    function setProtocolFee(bool enabled, address _feeTo) external onlyOwner {
        if (enabled && _feeTo == address(0)) revert InvalidToken();
        protocolFeeEnabled = enabled;
        feeTo = _feeTo;
        emit ProtocolFeeSet(enabled, _feeTo);
    }

    /// @dev When enabled, mints 1/6 of growth in sqrt(k) to feeTo, matching the Uniswap V2 fee-switch model.
    function _update(uint256 balanceA, uint256 balanceB) internal virtual override {
        if (protocolFeeEnabled && feeTo != address(0) && kLast != 0) {
            uint256 rootK = _sqrt(balanceA * balanceB);
            uint256 rootKLast = _sqrt(kLast);
            if (rootK > rootKLast) {
                uint256 totalSupply = lpToken.totalSupply();
                uint256 numerator = totalSupply * (rootK - rootKLast);
                uint256 denominator = rootK * 5 + rootKLast;
                uint256 liquidity = numerator / denominator;
                if (liquidity > 0) {
                    lpToken.mint(feeTo, liquidity);
                }
            }
        }

        super._update(balanceA, balanceB);
    }
}
