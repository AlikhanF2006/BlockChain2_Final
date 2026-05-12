# Slither High/Medium Justifications

The project was analyzed with:

```bash
slither . --filter-paths "lib|test|script" --exclude-low --exclude-informational
```

The remaining High/Medium findings are reviewed below.

## Treasury ETH withdrawal

- Detectors: `arbitrary-send-eth`, `low-level-calls`
- Location: `Treasury._claimETH`
- Status: accepted and mitigated
- Justification: the Treasury must be able to release ETH to governance-selected recipients. The public ETH paths are restricted by `TIMELOCK_ROLE`, reject zero recipient and zero amount, use `nonReentrant`, check the low-level call result, and emit events before the transfer.

## AMM and Lending reentrancy reports

- Detectors: `reentrancy-no-eth`, `reentrancy-benign`, `reentrancy-events`
- Locations: `AMMPool`, `AMMPoolV2`, `LendingPool`, `AMMFactory`
- Status: false positive or accepted design with mitigation
- Justification: AMM and lending token-moving entrypoints use `ReentrancyGuardUpgradeable` and `nonReentrant`. Slither does not fully model the guard across UUPS upgradeable inheritance and trusted protocol token calls. `AMMPoolV2._update` is internal and only reached through guarded external AMM functions. `AMMFactory.createPair` deploys trusted project contracts (`AMMPool`, `ERC1967Proxy`, `LPToken`) and does not call user-controlled code before recording the pair.

## Fixed-point math ordering

- Detector: `divide-before-multiply`
- Locations: `InterestRateModel`, `LendingPool`
- Status: accepted
- Justification: the code uses WAD-scaled fixed-point math. Intermediate divisions intentionally bound values such as utilization and rates before later scaling. Reordering all operations would increase overflow risk and could change expected rounding behavior covered by tests.

## Strict equality checks

- Detector: `incorrect-equality`
- Locations: `AMMPool`, `LendingPool`
- Status: false positive
- Justification: equality comparisons are zero-value guards, first-liquidity branch checks, and exact debt/index reset checks. They are not comparisons against attacker-controlled prices or randomness.

## Timestamp usage

- Detector: `timestamp`
- Locations: `AMMPool`, `LendingPool`, `ChainlinkAdapter`
- Status: accepted
- Justification: timestamps are used for user-supplied swap/liquidity deadlines, interest accrual elapsed time, and Chainlink staleness checks. They are not used as randomness.

## Assembly

- Detector: `assembly`
- Location: `AMMPool.getAmountOutAssembly`
- Status: accepted
- Justification: the assembly implementation is a bounded arithmetic optimization for deterministic constant-product swap output. It is cross-checked against the Solidity implementation in tests.
