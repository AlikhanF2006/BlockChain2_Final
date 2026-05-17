# DeFi Super-App
Created by Alikhan & Azamat & Alikhan:)
DeFi Super-App is a full-stack decentralized protocol developed for the Blockchain Technologies 2 Final Project.

The project follows **Option A — DeFi Super-App** and combines an AMM, lending protocol, ERC-4626 yield vault, Chainlink-style oracle integration, DAO governance, The Graph subgraph, and React frontend.

The protocol is deployed and verified on **Arbitrum Sepolia**.

---

## 1. Project Overview

This repository contains a complete decentralized protocol with smart contracts, tests, frontend, subgraph, deployment scripts, verified contract addresses, CI checks, and final documentation.

Main protocol parts:

- Constant-product AMM with LP tokens and slippage protection
- Lending pool with collateral, borrowing, repayment, health factor, and liquidation logic
- ERC-4626 tokenized yield vault
- Chainlink-style oracle adapter with stale price protection
- ERC20Votes + ERC20Permit governance token
- OpenZeppelin Governor + TimelockController DAO
- UUPS upgradeable contracts
- Factory contract using CREATE and CREATE2
- Inline Yul assembly benchmarked against Solidity
- The Graph subgraph for indexing protocol events
- React + Wagmi frontend for user interaction

---

## 2. Key Features

- AMM token swap
- Add liquidity to AMM pool
- Lending deposit, borrow, repay, and collateral withdrawal
- ERC-4626 vault deposit and withdrawal
- DAO self-delegation
- Governance proposal creation
- Proposal state tracking
- Chainlink oracle price validation
- Slippage protection
- Reentrancy protection
- Access-controlled privileged functions
- Subgraph indexing for protocol events
- GitHub Actions CI pipeline

---

## 3. Technology Stack

| Layer | Technology |
|---|---|
| Smart Contracts | Solidity, Foundry, OpenZeppelin |
| Frontend | React, TypeScript, Wagmi, Viem |
| Indexing | The Graph |
| Oracle | Chainlink-style AggregatorV3 adapter |
| Network | Arbitrum Sepolia |
| Testing | Foundry |
| Security | Slither, manual review |
| CI/CD | GitHub Actions |

---

## 4. Architecture Overview

The protocol contains the following main components:

| Component | Purpose |
|---|---|
| GovToken | ERC20Votes + ERC20Permit governance token |
| DeFiGovernor | DAO governance contract |
| DeFiTimelock | TimelockController with 2-day delay |
| AMMFactory | Factory contract using CREATE and CREATE2 |
| AMMPool | Constant-product AMM pool |
| LendingPool | Upgradeable lending protocol |
| YieldVault | ERC-4626 vault |
| ChainlinkAdapter | Oracle adapter with stale price checks |
| InterestRateModel | Linear interest rate model |
| The Graph Subgraph | Indexes protocol events |
| React dApp | User interface for protocol interaction |

Main user flows:

- User connects wallet through the React dApp.
- The frontend interacts with deployed contracts on Arbitrum Sepolia.
- Protocol contracts emit events.
- The Graph indexes protocol events.
- The frontend can read indexed protocol data from the subgraph.
- LendingPool and YieldVault use ChainlinkAdapter for price validation.
- GovToken, DeFiGovernor, and DeFiTimelock control governance actions.

Full architecture diagrams, sequence diagrams, storage layout, trust assumptions, and design decisions are included in the final project report.

---

## 5. Verified Contracts — Arbitrum Sepolia

| Contract | Address | Arbiscan |
|---|---|---|
| GovToken | `0xd86d5004815e58451100A2Ba9a9A35B8d11b94e2` | [View](https://sepolia.arbiscan.io/address/0xd86d5004815e58451100A2Ba9a9A35B8d11b94e2) |
| InterestRateModel | `0x95c9feE44D295331527648F581762386F7a1E65C` | [View](https://sepolia.arbiscan.io/address/0x95c9feE44D295331527648F581762386F7a1E65C) |
| ChainlinkAdapter | `0x86ac334fC8B6bF231604d8B64A84c9Ef6962d775` | [View](https://sepolia.arbiscan.io/address/0x86ac334fC8B6bF231604d8B64A84c9Ef6962d775) |
| AMMFactory | `0xFC6CDB0Bd25c2146464fdB7b6fb53FEd3C8Be9a4` | [View](https://sepolia.arbiscan.io/address/0xFC6CDB0Bd25c2146464fdB7b6fb53FEd3C8Be9a4) |
| AMMPool | `0x61165963D67bEbd3e5C1BEad6d0C9D849f13A35B` | [View](https://sepolia.arbiscan.io/address/0x61165963D67bEbd3e5C1BEad6d0C9D849f13A35B) |
| DeFiTimelock | `0xC9B50035aD84808AbE6b83fb148562A8B97B46F6` | [View](https://sepolia.arbiscan.io/address/0xC9B50035aD84808AbE6b83fb148562A8B97B46F6) |
| DeFiGovernor | `0xf223786104C878Bbf1D8a0b036DD07DB32Fa3DDf` | [View](https://sepolia.arbiscan.io/address/0xf223786104C878Bbf1D8a0b036DD07DB32Fa3DDf) |
| LendingPool Proxy | `0x052BD2B635369c231E954A1F34A49d5182184877` | [View](https://sepolia.arbiscan.io/address/0x052BD2B635369c231E954A1F34A49d5182184877) |
| LendingPool Implementation | `0xE86C7b40573c0F2cc3Be989801582D209FC90Cdb` | [View](https://sepolia.arbiscan.io/address/0xE86C7b40573c0F2cc3Be989801582D209FC90Cdb) |
| YieldVault Proxy | `0xdbCdEcEF8c567b691e072200420f3f324971fd68` | [View](https://sepolia.arbiscan.io/address/0xdbCdEcEF8c567b691e072200420f3f324971fd68) |
| YieldVault Implementation | `0x87Fa5BC9CadFEfc30485716f9DDBb9A0BCBEAe73` | [View](https://sepolia.arbiscan.io/address/0x87Fa5BC9CadFEfc30485716f9DDBb9A0BCBEAe73) |

Full deployment data is stored in:

`deployments/421614.json`

---

## 6. Subgraph

The project includes The Graph subgraph configuration:

- `subgraph/subgraph.yaml`
- `subgraph/schema.graphql`
- `subgraph/src/`

Subgraph endpoint:

`https://api.studio.thegraph.com/query/1753299/defi-super-app/v0.0.1`

Build subgraph:

```bash
cd subgraph
npm install
npm run codegen
npm run build
```

The subgraph indexes protocol events and is used for protocol data reading and analysis.

---

## 7. Frontend dApp

The frontend is located in:

`frontend/`

The frontend supports:

- MetaMask wallet connection
- Arbitrum Sepolia network detection
- Token balances
- Voting power
- Delegate address
- AMM swap
- Add liquidity
- Lending deposit, borrow, repay, and withdraw collateral
- Vault deposit and withdraw
- Governance delegate and proposal creation
- Proposal state display
- Readable transaction error messages

Run frontend:

```bash
cd frontend
npm install
npm run dev
```

Open:

`http://localhost:5173`

---

## 8. Local Development

Install Foundry dependencies:

```bash
forge install
```

Build contracts:

```bash
forge build
```

Run all tests:

```bash
forge test -vvv
```

Generate coverage:

```bash
forge coverage --ir-minimum --report lcov
```

Run formatter check:

```bash
forge fmt --check
```

Run Slither:

```bash
slither . --filter-paths "lib|test|script" --exclude-low --exclude-informational
```

Build frontend:

```bash
cd frontend
npm install
npm run build
```

Build subgraph:

```bash
cd subgraph
npm install
npm run codegen
npm run build
```

---

## 9. Testing Summary

The project includes:

- 176 passing tests
- Unit tests
- Fuzz tests
- Invariant tests
- Fork tests
- Security case study tests
- Full governance lifecycle test

Important tested flows:

- AMM add liquidity
- AMM remove liquidity
- AMM swap
- Lending deposit collateral
- Borrow
- Repay
- Liquidation
- ERC-4626 deposit and withdraw
- Vault rounding invariants
- Oracle stale price checks
- Governance propose → vote → queue → execute
- UUPS upgrade authorization
- Reentrancy case study
- Access-control case study

Run tests:

```bash
forge test -vvv
```

---

## 10. Security

Security controls used in the project:

- Checks-Effects-Interactions pattern
- ReentrancyGuard on sensitive flows
- Ownable / role-based privileged functions
- Timelock-controlled governance actions
- Chainlink oracle staleness checks
- SafeERC20 for token transfers
- No `tx.origin` authorization
- No deprecated `transfer` / `send` usage
- Slither check with zero High and zero Medium findings

Run Slither:

```bash
slither . --filter-paths "lib|test|script" --exclude-low --exclude-informational
```

Expected result:

`0 High / 0 Medium findings`

The full security audit is included in the final project report.

---

## 11. Governance

Governance stack:

- ERC20Votes governance token
- OpenZeppelin Governor
- TimelockController with 2-day delay
- Voting delay: 1 day
- Voting period: 1 week
- Quorum: 4%
- Proposal threshold: 1%

Governance lifecycle:

`propose → vote → queue → execute`

The full governance lifecycle is demonstrated in the Foundry test suite.

On testnet, governance uses real delay settings, so some frontend actions require waiting for the correct proposal state.

---

## 12. CI/CD

GitHub Actions runs on every push and pull request.

CI checks include:

- Build and Test
- Coverage
- Frontend Build
- Lint
- Slither
- Subgraph Build

Current final status:

`All checks passing`

---

## 13. Documentation

Project documentation:

| Document | Path |
|---|---|
| Final Project Report | `docs/FINAL_PROJECT_REPORT.pdf` |
| Architecture & Design | Included in final project report |
| Security Audit | Included in final project report |
| Gas Optimization Report | Included in final project report |
| Final Presentation | `presentation/FINAL_PRESENTATION.pdf` |
| Deployment Addresses | `deployments/421614.json` |

---

## 14. Repository Structure

| Folder | Description |
|---|---|
| `src/` | Smart contracts |
| `test/` | Unit, fuzz, invariant, fork, and security tests |
| `script/` | Deployment and verification scripts |
| `frontend/` | React frontend dApp |
| `subgraph/` | The Graph subgraph |
| `deployments/` | Deployed addresses and explorer links |
| `docs/` | Final report and documentation |
| `presentation/` | Final presentation files |

---

## 15. Notes

This repository is prepared as a full-stack decentralized protocol submission.

The README provides:

- Project overview
- Setup commands
- Test commands
- Slither command
- Frontend instructions
- Subgraph instructions
- Verified contract links
- Documentation paths
- Repository structure

---

## 16. Team Members and group SE-2408
- Alikhan Faizrakhman
- Azamat Oralkhanov
- Alikhan Kenzhebek
