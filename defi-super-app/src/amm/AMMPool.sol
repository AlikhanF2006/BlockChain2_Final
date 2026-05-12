// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {LPToken} from "../tokens/LPToken.sol";

/// @title Constant Product AMM Pool
/// @notice UUPS-upgradeable x*y=k pool for two ERC20 tokens.
/// @dev Storage layout for upgrade safety:
/// slot 0: Initializable bookkeeping
/// slot 1: OwnableUpgradeable owner
/// slot 2: ReentrancyGuardUpgradeable status
/// slot 3: address tokenA
/// slot 4: address tokenB
/// slot 5: uint112 reserveA | uint112 reserveB | uint32 blockTimestampLast
/// slot 6: LPToken lpToken
/// slot 7: uint256 kLast
/// Future versions must append storage only after slot 7.
contract AMMPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InsufficientAmount();
    error DeadlineExpired();
    error InvalidToken();
    error Overflow();

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address indexed to);
    event Sync(uint112 reserveA, uint112 reserveB);

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant FEE_NUMERATOR = 997;
    uint256 internal constant FEE_DENOMINATOR = 1000;

    address public tokenA;
    address public tokenB;
    uint112 internal reserveA;
    uint112 internal reserveB;
    uint32 internal blockTimestampLast;
    LPToken public lpToken;
    uint256 internal kLast;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _tokenA, address _tokenB, address _lpToken) external initializer {
        if (_tokenA == address(0) || _tokenB == address(0) || _lpToken == address(0) || _tokenA == _tokenB) {
            revert InvalidToken();
        }

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        tokenA = _tokenA;
        tokenB = _tokenB;
        lpToken = LPToken(_lpToken);
    }

    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (amountADesired == 0 || amountBDesired == 0 || to == address(0)) revert InsufficientAmount();

        (uint112 _reserveA, uint112 _reserveB,) = getReserves();
        uint256 totalSupply = lpToken.totalSupply();

        if (_reserveA == 0 && _reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
            uint256 rootK = _sqrt(amountA * amountB);
            if (rootK <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            liquidity = rootK - MINIMUM_LIQUIDITY;
            lpToken.mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            uint256 amountBOptimal = _quote(amountADesired, _reserveA, _reserveB);
            if (amountBOptimal <= amountBDesired) {
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = _quote(amountBDesired, _reserveB, _reserveA);
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
            liquidity = _min((amountA * totalSupply) / _reserveA, (amountB * totalSupply) / _reserveB);
        }

        if (amountA < amountAMin || amountB < amountBMin || liquidity == 0) revert InsufficientAmount();

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        lpToken.mint(to, liquidity);

        _update(IERC20(tokenA).balanceOf(address(this)), IERC20(tokenB).balanceOf(address(this)));
        emit LiquidityAdded(to, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (liquidity == 0 || to == address(0)) revert InsufficientAmount();

        uint256 totalSupply = lpToken.totalSupply();
        if (totalSupply == 0) revert InsufficientLiquidity();

        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;
        if (amountA < amountAMin || amountB < amountBMin || amountA == 0 || amountB == 0) {
            revert InsufficientAmount();
        }

        lpToken.burn(msg.sender, liquidity);
        _update(uint256(reserveA) - amountA, uint256(reserveB) - amountB);

        IERC20(tokenA).safeTransfer(to, amountA);
        IERC20(tokenB).safeTransfer(to, amountB);
        emit LiquidityRemoved(to, amountA, amountB, liquidity);
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address tokenIn, address to, uint256 deadline)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (amountIn == 0 || to == address(0)) revert InsufficientAmount();

        bool isAIn = tokenIn == tokenA;
        if (!isAIn && tokenIn != tokenB) revert InvalidToken();

        address tokenOut = isAIn ? tokenB : tokenA;
        uint112 reserveIn = isAIn ? reserveA : reserveB;
        uint112 reserveOut = isAIn ? reserveB : reserveA;
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        amountOut = getAmountOutAssembly(amountIn, reserveIn, reserveOut);
        if (amountOut < amountOutMin || amountOut == 0) revert InsufficientOutputAmount();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 newReserveIn = uint256(reserveIn) + amountIn;
        uint256 newReserveOut = uint256(reserveOut) - amountOut;
        if (isAIn) {
            _update(newReserveIn, newReserveOut);
        } else {
            _update(newReserveOut, newReserveIn);
        }

        IERC20(tokenOut).safeTransfer(to, amountOut);
        emit Swap(msg.sender, tokenIn, amountIn, amountOut, to);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
    }

    /// @dev Assembly version saves ~70 gas vs Solidity in the included Foundry benchmark.
    function getAmountOutAssembly(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        assembly {
            let amountInWithFee := mul(amountIn, 997)
            if iszero(eq(div(amountInWithFee, 997), amountIn)) {
                mstore(0x00, 0x35278d12)
                revert(0x1c, 0x04)
            }

            let numerator := mul(amountInWithFee, reserveOut)
            if and(iszero(iszero(amountInWithFee)), iszero(eq(div(numerator, amountInWithFee), reserveOut))) {
                mstore(0x00, 0x35278d12)
                revert(0x1c, 0x04)
            }

            let scaledReserve := mul(reserveIn, 1000)
            if iszero(eq(div(scaledReserve, 1000), reserveIn)) {
                mstore(0x00, 0x35278d12)
                revert(0x1c, 0x04)
            }

            let denominator := add(scaledReserve, amountInWithFee)
            if lt(denominator, scaledReserve) {
                mstore(0x00, 0x35278d12)
                revert(0x1c, 0x04)
            }

            amountOut := div(numerator, denominator)
        }
    }

    function getReserves() public view returns (uint112 _reserveA, uint112 _reserveB, uint32 _blockTimestampLast) {
        _reserveA = reserveA;
        _reserveB = reserveB;
        _blockTimestampLast = blockTimestampLast;
    }

    function lastK() external view returns (uint256) {
        return kLast;
    }

    function _update(uint256 balanceA, uint256 balanceB) internal virtual {
        if (balanceA > type(uint112).max || balanceB > type(uint112).max) revert Overflow();
        reserveA = uint112(balanceA);
        reserveB = uint112(balanceB);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        kLast = balanceA * balanceB;
        emit Sync(reserveA, reserveB);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _quote(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        return (amountIn * reserveOut) / reserveIn;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
