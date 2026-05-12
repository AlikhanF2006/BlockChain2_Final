# Gas Report

## L1 vs L2 Gas Comparison

The benchmark script is `script/GasBenchmark.s.sol`. It measures the same six operations on an Arbitrum Sepolia fork and an Ethereum mainnet fork using configured deployed addresses.

Command:

```bash
forge script script/GasBenchmark.s.sol:GasBenchmark
```

Environment limitation:

Gas numbers could not be collected in this workspace because Foundry is not installed and live fork RPC access was unavailable during generation. The table below is prepared for the benchmark output.

| Operation | L1 Gas | L1 Cost (gwei) | L2 Gas | L2 Cost (gwei) | Savings |
| --- | ---: | ---: | ---: | ---: | ---: |
| AMM Swap | pending benchmark | pending benchmark | pending benchmark | pending benchmark | pending benchmark |
| AMM addLiquidity | pending benchmark | pending benchmark | pending benchmark | pending benchmark | pending benchmark |
| Lending deposit | pending benchmark | pending benchmark | pending benchmark | pending benchmark | pending benchmark |
| Lending borrow | pending benchmark | pending benchmark | pending benchmark | pending benchmark | pending benchmark |
| Propose | pending benchmark | pending benchmark | pending benchmark | pending benchmark | pending benchmark |
| castVote | pending benchmark | pending benchmark | pending benchmark | pending benchmark | pending benchmark |

## Yul Assembly Optimization

AMMPool includes both a Solidity and inline assembly implementation of `getAmountOut`. The swap path calls the assembly implementation.

Benchmark source:

- `test/unit/AMM.t.sol::test_GasBenchmark_SolidityVsAssembly`

| Function | Solidity Gas | Assembly Gas | Savings |
| --- | ---: | ---: | ---: |
| getAmountOut (1000x) | pending `forge test -vv` | pending `forge test -vv` | pending benchmark |

## Notes

- L2 execution gas is not the full user cost on Arbitrum; calldata posting and L1 base fee also affect final fee.
- Governance proposal creation is expected to be one of the most expensive operations because arrays and calldata are stored and emitted.
- AMM swaps should be comparatively low-cost due to simple reserve math and no dynamic pool discovery in the pool itself.
