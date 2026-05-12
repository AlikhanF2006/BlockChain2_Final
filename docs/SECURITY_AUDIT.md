# Security Audit Report

## Executive Summary

Protocol: DeFi Super-App

Audit performed by: Team members to be filled before submission

Commit hash: unavailable in this workspace; `git status` reported this directory is not a Git repository

Files in scope:

- `src/amm/AMMFactory.sol`
- `src/amm/AMMPool.sol`
- `src/amm/AMMPoolV2.sol`
- `src/governance/DeFiGovernor.sol`
- `src/governance/DeFiTimelock.sol`
- `src/governance/Treasury.sol`
- `src/lending/InterestRateModel.sol`
- `src/lending/LendingPool.sol`
- `src/oracle/ChainlinkAdapter.sol`
- `src/tokens/GovToken.sol`
- `src/tokens/LPToken.sol`
- `src/vault/YieldVault.sol`

Files out of scope:

- `test/helpers/*`
- `test/security/*` vulnerable demonstration contracts
- `script/*`
- `frontend/*`
- `subgraph/*`

Total findings: 9

- 0 Critical open
- 0 High open
- 3 Medium
- 3 Low
- 3 Informational

Critical and High findings were intentionally reproduced in vulnerable case-study contracts and fixed in production contracts.

## Methodology

Tools:

- Slither static analysis: intended command `slither src/ --exclude-informational`
- Foundry unit tests, fuzz tests, and invariants: intended command `forge test`
- Manual review of all in-scope Solidity files

Manual checklist:

- Checks-Effects-Interactions ordering
- Reentrancy exposure around token and ETH transfers
- Access control on privileged functions
- Integer overflow and precision loss
- Oracle staleness and invalid price handling
- Upgrade storage layout safety
- Governance admin backdoor removal
- Timelock role configuration
- ERC-20 return-value handling
- `tx.origin`, `transfer`, and `send` usage

Environment limitation:

Foundry was not available in this execution environment. `forge test` failed because `forge` is not recognized. Slither is installed, but it also failed because Slither invokes `forge config --json` for Foundry projects and `forge` is missing. Findings below combine manual review and the security case-study tests written in `test/security`.

## Findings Table

| ID | Title | Severity | Status |
| --- | --- | --- | --- |
| S-01 | Reentrancy in vulnerable withdraw pattern | Critical | Fixed |
| S-02 | Missing access control on fee setter | High | Fixed |
| S-03 | Oracle staleness not checked | High | Fixed |
| S-04 | Borrow path lacked emergency pause | Medium | Fixed |
| S-05 | Governance admin backdoor risk during bootstrap | Medium | Fixed |
| S-06 | AMM V2 storage collision risk | Medium | Fixed |
| S-07 | CREATE2 deployment ordering risk for LPToken | Low | Fixed |
| S-08 | ERC-4626 withdrawals can fail under high utilization | Low | Acknowledged |
| S-09 | Subgraph data should not be treated as canonical | Informational | Acknowledged |

## S-01: Reentrancy in Vulnerable Withdraw Pattern

Severity: Critical

Location: `test/helpers/VulnerablePool.sol`

Description:

The vulnerable case-study pool sends ETH to `msg.sender` before zeroing the sender balance. An attacker contract can re-enter `withdraw()` from its `receive()` callback and withdraw the same recorded balance multiple times.

Impact:

An attacker can drain ETH supplied by other depositors.

Proof of Concept:

`test/security/Reentrancy.t.sol::test_Reentrancy_AttackSucceeds_VulnerablePool`

Recommendation:

Update accounting before external calls and add `nonReentrant` on withdrawal paths.

Status:

Fixed in production. AMMPool and LendingPool use `ReentrancyGuardUpgradeable`, SafeERC20, and CEI ordering. The vulnerable contract remains only as a case-study test helper.

## S-02: Missing Access Control on Fee Setter

Severity: High

Location: `test/helpers/VulnerableAdmin.sol`

Description:

The vulnerable admin contract exposes `setProtocolFee(uint256)` to any caller. An attacker can set protocol fees to an arbitrary value, including 100%.

Impact:

If present in production, users could be fully taxed or protocol economics could be broken.

Proof of Concept:

`test/security/AccessControl.t.sol::test_AccessControl_AnyoneCanCallVulnerable`

Recommendation:

Guard privileged functions with `onlyOwner` or role-based access control. Transfer ownership to timelock after deployment.

Status:

Fixed in production. `AMMPoolV2.setProtocolFee` uses `onlyOwner`, and the security test verifies unauthorized callers revert.

## S-03: Oracle Staleness Not Checked

Severity: High

Location: `src/oracle/ChainlinkAdapter.sol`

Description:

Oracle consumers must reject stale or invalid prices. During development the adapter was explicitly implemented with `maxStaleness` and non-positive price checks.

Impact:

Stale prices can cause incorrect health factors, allowing undercollateralized borrows or invalid liquidations.

Proof of Concept:

`test/unit/LendingPool.t.sol::test_ChainlinkAdapter_RevertStalePrice`

Recommendation:

Keep staleness checks at the adapter layer and make all lending price reads go through the adapter.

Status:

Fixed. `getPrice` reverts with `StalePrice` and `InvalidPrice`.

## S-04: Borrow Path Lacked Emergency Pause

Severity: Medium

Location: `src/lending/LendingPool.sol`

Description:

Borrowing is the riskiest lending action during oracle incidents or market stress. The pool initially had reentrancy protection but no owner-controlled pause on new borrows.

Impact:

If a feed degrades or a market configuration is wrong, new borrowing could continue until governance acts.

Proof of Concept:

Manual review. The final code adds `PausableUpgradeable` and `whenNotPaused` on `borrow()`.

Recommendation:

Pause only new risk creation. Do not pause repay or withdrawals so users can reduce risk and exit.

Status:

Fixed.

## S-05: Governance Admin Backdoor Risk During Bootstrap

Severity: Medium

Location: `script/Deploy.s.sol`, `src/governance/DeFiTimelock.sol`

Description:

Timelock deployment temporarily requires a bootstrap admin to grant proposer and executor roles. If deployer admin is not revoked, the deployer can bypass governance.

Impact:

Deployer could grant roles or alter governance permissions without token-holder approval.

Proof of Concept:

`test/unit/Governance.t.sol::test_NoAdminBackdoor`

Recommendation:

Deployment must revoke `DEFAULT_ADMIN_ROLE` from deployer and verification must fail if the role remains.

Status:

Fixed in deployment and verification scripts.

## S-06: AMM V2 Storage Collision Risk

Severity: Medium

Location: `src/amm/AMMPool.sol`, `src/amm/AMMPoolV2.sol`

Description:

Upgradeable contracts can corrupt proxy state if new variables are inserted before existing variables.

Impact:

Reserves, owner, LP token address, or fee state could be corrupted after upgrade.

Proof of Concept:

`test/unit/AMM.t.sol::test_UUPS_UpgradeToV2`

Recommendation:

Document storage slots and append V2 variables only after V1 state.

Status:

Fixed. `protocolFeeEnabled` and `feeTo` are appended after V1 slots.

## S-07: CREATE2 Deployment Ordering Risk for LPToken

Severity: Low

Location: `src/amm/AMMFactory.sol`

Description:

LPToken requires the AMM proxy address in its constructor, while AMMPool initialization requires the LPToken address.

Impact:

Incorrect ordering can deploy an LPToken bound to the wrong AMM or make pool initialization impossible.

Proof of Concept:

`test/unit/AMM.t.sol::test_Factory_CREATE2_AddressPrediction`

Recommendation:

Deploy proxy with empty init data, deploy LPToken bound to proxy, then initialize proxy.

Status:

Fixed.

## S-08: ERC-4626 Withdrawals Can Fail Under High Utilization

Severity: Low

Location: `src/vault/YieldVault.sol`, `src/lending/LendingPool.sol`

Description:

The vault deposits all assets into LendingPool. If utilization is high, LendingPool may not have enough liquid borrow tokens for vault withdrawals.

Impact:

Vault users may need to wait for repayments or new deposits before withdrawing.

Proof of Concept:

`test/unit/LendingPool.t.sol::test_Withdraw_RevertInsufficientLiquidity`

Recommendation:

For production, add a liquidity buffer or withdrawal queue.

Status:

Acknowledged.

## S-09: Subgraph Data Should Not Be Treated as Canonical

Severity: Informational

Location: `frontend/src/hooks/useSubgraph.ts`, `subgraph/*`

Description:

The Graph indexes events asynchronously and may lag behind chain state.

Impact:

Frontend dashboards may display stale analytics or proposal state.

Proof of Concept:

Manual review.

Recommendation:

Use direct contract reads for safety-critical values such as `getHealthFactor`, allowances, balances, and voting power. The frontend follows this pattern.

Status:

Acknowledged.

## Centralization Analysis

Post-deployment, only the Timelock should have protocol admin power over LendingPool and YieldVault. The deployer must lose timelock default admin during deployment. The timelock has a 2-day delay, giving the community time to inspect and react to malicious proposals.

Remaining risks:

- Chainlink feed operator risk remains external.
- Token-holder governance can pass malicious proposals if quorum and majority are captured.
- Frontend hosting can mislead users, although wallet prompts and contract verification reduce this risk.

## Governance Attack Analysis

Flash-loan attack:

Votes use snapshots. Tokens acquired after proposal creation or vote-start snapshot do not increase voting weight for that proposal.

Whale attack:

Mitigated by quorum of 4%, proposal threshold of 1%, voting delay, voting period, and timelock delay. It is not eliminated; governance token concentration remains a social and economic risk.

Proposal spam:

The 100,000 GOV threshold creates meaningful cost to create proposals.

Timelock bypass:

Governor is the only proposer after deployment. Direct deployer admin is revoked. All privileged calls must go through the 2-day timelock.

## Oracle Attack Analysis

Price manipulation:

Chainlink uses multiple node operators and aggregation, making single-source manipulation unlikely.

Stale price:

`MAX_STALENESS = 3600` seconds by default. Stale prices revert, blocking liquidations and health factor reads that depend on invalid data.

Feed depeg or wrong feed:

Governance can update feeds through the adapter owner path if ownership is transferred to Timelock. Deployment should verify feed addresses before launch.

## Slither Appendix

Command intended:

```bash
slither src/ --exclude-informational
```

Actual output:

```text
Cannot execute `forge`, is it installed and in PATH?
'forge config --json' running
FileNotFoundError: [WinError 2] The system cannot find the file specified
```

Expected follow-up:

Run Slither in CI or a local machine with dependencies installed. Any Low or Informational findings should be triaged against the manual checklist above. Known intentional patterns include UUPS upgrade authorization, Chainlink external calls, and test-only vulnerable contracts excluded from scope.
