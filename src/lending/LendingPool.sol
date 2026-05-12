// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ChainlinkAdapter} from "../oracle/ChainlinkAdapter.sol";
import {InterestRateModel} from "./InterestRateModel.sol";

/// @title Lending Pool
/// @notice UUPS-upgradeable lending market with one collateral asset and one borrow asset.
/// @dev Storage layout for upgrade safety:
/// slot 0: Initializable bookkeeping
/// slot 1: OwnableUpgradeable owner
/// slot 2: ReentrancyGuardUpgradeable status
/// slot 3: PausableUpgradeable paused flag
/// slot 4: mapping _deposits
/// slot 5: mapping borrows
/// slot 6: mapping borrowIndex
/// slot 7: mapping collateralBalance
/// slot 8: mapping depositIndex
/// slot 9: totalDeposits
/// slot 10: totalBorrows
/// slot 11: globalBorrowIndex
/// slot 12: globalDepositIndex
/// slot 13: lastAccrualTimestamp
/// slot 14: oracle
/// slot 15: interestRateModel
/// slot 16: collateralToken
/// slot 17: borrowToken
/// Future versions must append storage after slot 17.
contract LendingPool is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    error InsufficientBalance();
    error InsufficientLiquidity();
    error UnderCollateralized();
    error HealthyPosition();
    error InvalidAmount();
    error InvalidAddress();

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidation(address indexed borrower, address indexed liquidator, uint256 repaid, uint256 seized);
    event InterestAccrued(uint256 interest, uint256 globalBorrowIndex);

    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant LTV = 75e16;
    uint256 public constant LIQUIDATION_THRESHOLD = 80e16;
    uint256 public constant LIQUIDATION_BONUS = 5e16;

    mapping(address => uint256) internal _deposits;
    mapping(address => uint256) public borrows;
    mapping(address => uint256) public borrowIndex;
    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public depositIndex;

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public globalBorrowIndex;
    uint256 public globalDepositIndex;
    uint256 public lastAccrualTimestamp;
    ChainlinkAdapter public oracle;
    InterestRateModel public interestRateModel;
    address public collateralToken;
    address public borrowToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _collateralToken, address _borrowToken, address _oracle, address _interestRateModel)
        external
        initializer
    {
        if (
            _collateralToken == address(0) || _borrowToken == address(0) || _oracle == address(0)
                || _interestRateModel == address(0) || _collateralToken == _borrowToken
        ) revert InvalidAddress();

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
        oracle = ChainlinkAdapter(_oracle);
        interestRateModel = InterestRateModel(_interestRateModel);
        globalBorrowIndex = WAD;
        globalDepositIndex = WAD;
        lastAccrualTimestamp = block.timestamp;
    }

    function accrueInterest() public {
        uint256 elapsed = block.timestamp - lastAccrualTimestamp;
        // slither-disable-next-line incorrect-equality
        if (elapsed == 0) return;

        // slither-disable-next-line incorrect-equality
        if (totalBorrows == 0 || totalDeposits == 0) {
            lastAccrualTimestamp = block.timestamp;
            return;
        }

        uint256 borrowRate = interestRateModel.getBorrowRate(totalBorrows, totalDeposits);
        uint256 interestFactor = Math.mulDiv(borrowRate, elapsed, SECONDS_PER_YEAR);
        uint256 interest = Math.mulDiv(totalBorrows, interestFactor, WAD);

        globalBorrowIndex = Math.mulDiv(globalBorrowIndex, WAD + interestFactor, WAD);
        if (totalDeposits > 0 && interest > 0) {
            globalDepositIndex = Math.mulDiv(globalDepositIndex, totalDeposits + interest, totalDeposits);
        }
        totalBorrows += interest;
        totalDeposits += interest;
        lastAccrualTimestamp = block.timestamp;

        emit InterestAccrued(interest, globalBorrowIndex);
    }

    function deposit(uint256 amount) external nonReentrant {
        // CEI: checks, effects, interactions.
        if (amount == 0) revert InvalidAmount();
        accrueInterest();
        _accrueDepositor(msg.sender);

        _deposits[msg.sender] += amount;
        totalDeposits += amount;
        IERC20(borrowToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        // CEI: checks, effects, interactions.
        if (amount == 0) revert InvalidAmount();
        accrueInterest();
        _accrueDepositor(msg.sender);
        if (_deposits[msg.sender] < amount) revert InsufficientBalance();
        if (_availableLiquidity() < amount) revert InsufficientLiquidity();

        _deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        IERC20(borrowToken).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        // CEI: checks, effects, interactions.
        if (amount == 0) revert InvalidAmount();
        accrueInterest();

        collateralBalance[msg.sender] += amount;
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        // CEI: checks, effects, interactions.
        if (amount == 0) revert InvalidAmount();
        accrueInterest();
        if (collateralBalance[msg.sender] < amount) revert InsufficientBalance();

        collateralBalance[msg.sender] -= amount;
        if (getHealthFactor(msg.sender) < WAD) revert UnderCollateralized();

        IERC20(collateralToken).safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        // CEI: checks, effects, interactions.
        if (amount == 0) revert InvalidAmount();
        accrueInterest();
        if (_availableLiquidity() < amount) revert InsufficientLiquidity();

        uint256 debt = currentDebt(msg.sender);
        borrows[msg.sender] = debt + amount;
        borrowIndex[msg.sender] = globalBorrowIndex;

        if (getHealthFactor(msg.sender) < WAD) revert UnderCollateralized();

        totalBorrows += amount;
        IERC20(borrowToken).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        // CEI: checks, effects, interactions.
        if (amount == 0) revert InvalidAmount();
        accrueInterest();

        uint256 debt = currentDebt(msg.sender);
        // slither-disable-next-line incorrect-equality
        if (debt == 0) revert InvalidAmount();
        uint256 paid = amount > debt ? debt : amount;

        uint256 remaining = debt - paid;
        borrows[msg.sender] = remaining;
        // slither-disable-next-line incorrect-equality
        borrowIndex[msg.sender] = remaining == 0 ? 0 : globalBorrowIndex;
        totalBorrows = paid > totalBorrows ? 0 : totalBorrows - paid;
        IERC20(borrowToken).safeTransferFrom(msg.sender, address(this), paid);

        emit Repay(msg.sender, paid);
    }

    function liquidate(address borrower, uint256 repayAmount) external nonReentrant {
        // CEI: checks, effects, interactions.
        if (repayAmount == 0) revert InvalidAmount();
        accrueInterest();
        if (getHealthFactor(borrower) >= WAD) revert HealthyPosition();

        uint256 debt = currentDebt(borrower);
        uint256 paid = repayAmount > debt ? debt : repayAmount;
        uint256 seized = _collateralToSeize(paid);
        if (seized > collateralBalance[borrower]) seized = collateralBalance[borrower];

        uint256 remaining = debt - paid;
        borrows[borrower] = remaining;
        // slither-disable-next-line incorrect-equality
        borrowIndex[borrower] = remaining == 0 ? 0 : globalBorrowIndex;
        totalBorrows = paid > totalBorrows ? 0 : totalBorrows - paid;
        collateralBalance[borrower] -= seized;
        IERC20(borrowToken).safeTransferFrom(msg.sender, address(this), paid);

        IERC20(collateralToken).safeTransfer(msg.sender, seized);
        emit Liquidation(borrower, msg.sender, paid, seized);
    }

    function currentDebt(address user) public view returns (uint256) {
        uint256 principal = borrows[user];
        uint256 userIndex = borrowIndex[user];
        // slither-disable-next-line incorrect-equality
        if (principal == 0 || userIndex == 0) return 0;
        return principal * globalBorrowIndex / userIndex;
    }

    function deposits(address user) public view returns (uint256) {
        uint256 amount = _deposits[user];
        uint256 userIndex = depositIndex[user];
        // slither-disable-next-line incorrect-equality
        if (amount == 0) return 0;
        if (userIndex == 0) return amount;
        return amount * globalDepositIndex / userIndex;
    }

    function getHealthFactor(address user) public view returns (uint256) {
        uint256 debt = currentDebt(user);
        // slither-disable-next-line incorrect-equality
        if (debt == 0) return type(uint256).max;

        (uint256 collateralPrice, uint8 collateralDecimals) = oracle.getPrice(collateralToken);
        (uint256 borrowPrice, uint8 borrowDecimals) = oracle.getPrice(borrowToken);
        uint256 collateralValue =
            Math.mulDiv(collateralBalance[user], collateralPrice, 10 ** uint256(collateralDecimals));
        uint256 debtValue = Math.mulDiv(debt, borrowPrice, 10 ** uint256(borrowDecimals));
        // slither-disable-next-line incorrect-equality
        if (debtValue == 0) return type(uint256).max;

        return Math.mulDiv(collateralValue, LTV, debtValue);
    }

    function availableLiquidity() external view returns (uint256) {
        return _availableLiquidity();
    }

    function pause() external onlyOwner {
        // CEI: checks, effects, interactions.
        _pause();
    }

    function unpause() external onlyOwner {
        // CEI: checks, effects, interactions.
        _unpause();
    }

    function _availableLiquidity() internal view returns (uint256) {
        return totalDeposits > totalBorrows ? totalDeposits - totalBorrows : 0;
    }

    function _accrueDepositor(address user) internal {
        _deposits[user] = deposits(user);
        depositIndex[user] = globalDepositIndex;
    }

    function _collateralToSeize(uint256 paid) internal view returns (uint256) {
        (uint256 collateralPrice, uint8 collateralDecimals) = oracle.getPrice(collateralToken);
        (uint256 borrowPrice, uint8 borrowDecimals) = oracle.getPrice(borrowToken);
        uint256 repayValue = Math.mulDiv(paid, borrowPrice, 10 ** uint256(borrowDecimals));
        uint256 collateralAmount = Math.mulDiv(repayValue, 10 ** uint256(collateralDecimals), collateralPrice);
        return Math.mulDiv(collateralAmount, WAD + LIQUIDATION_BONUS, WAD);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
