// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IReentrantPool {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address tokenIn, address to, uint256 deadline)
        external
        returns (uint256 amountOut);
}

contract MockReentrantToken is ERC20 {
    address public pool;
    address public pairedToken;
    bool public attackEnabled;

    constructor() ERC20("Reentrant Token", "RNT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function configureAttack(address pool_, address pairedToken_) external {
        pool = pool_;
        pairedToken = pairedToken_;
    }

    function setAttackEnabled(bool enabled) external {
        attackEnabled = enabled;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (attackEnabled && from != address(0) && to == pool) {
            attackEnabled = false;
            IReentrantPool(pool).swapExactTokensForTokens(1, 0, pairedToken, from, block.timestamp);
        }
    }
}
