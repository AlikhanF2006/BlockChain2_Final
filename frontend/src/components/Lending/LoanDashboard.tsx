import { useMemo, useState } from "react";
import { formatUnits, parseUnits } from "viem";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { addresses, lendingAbi } from "../../constants/addresses";
import { useLending } from "../../hooks/useLending";
import { useTransactionToast } from "../../hooks/useTransactionToast";

const erc20Abi = [
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" }
    ],
    outputs: [{ type: "bool" }]
  },
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" }
    ],
    outputs: [{ type: "uint256" }]
  }
] as const;

export function LoanDashboard() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const [amount, setAmount] = useState("");
  const lending = useLending(amount);
  const { writeContractAsync } = useWriteContract();
  const tx = useTransactionToast();
  const parsed = amount ? parseUnits(amount, 18) : 0n;

  const collateral = lending.collateralBalance ?? 0n;
  const debt = lending.debtBalance ?? 0n;

  const hf = useMemo(() => {
    if (lending.healthFactor && lending.healthFactor < 10n ** 30n) {
      return Number(formatUnits(lending.healthFactor, 18));
    }
    return 999;
  }, [lending.healthFactor]);

  const gaugeClass = hf < 1.1 ? "danger" : hf <= 1.5 ? "warning" : "healthy";

  async function runAndRefresh(label: string, runner: () => Promise<`0x${string}`>) {
    const hash = await tx.run(label, runner);
    if (hash) await lending.refetch();
  }

  async function approveIfNeeded(token: `0x${string}`, amount: bigint) {
    if (!address) throw new Error("Wallet not connected");

    const allowance = await publicClient?.readContract({
      address: token,
      abi: erc20Abi,
      functionName: "allowance",
      args: [address, addresses.lendingPool]
    });

    if (allowance && allowance >= amount) {
      return;
    }

    await writeContractAsync({
      address: token,
      abi: erc20Abi,
      functionName: "approve",
      args: [addresses.lendingPool, amount * 100n],
      gas: 120_000n,
      maxFeePerGas: 500_000_000n,
      maxPriorityFeePerGas: 0n
    });
  }

  return (
    <section className="panel wide">
      <div className="panel-title">
        <h2>Lending</h2>
        <span className={gaugeClass}>{debt === 0n ? "No debt" : hf.toFixed(2)}</span>
      </div>

      <div className="metrics">
        <div><span>Collateral</span><strong>{formatUnits(collateral, 18)}</strong></div>
        <div><span>Debt</span><strong>{formatUnits(debt, 18)}</strong></div>
        <div><span>Health factor</span><strong>{debt === 0n ? "Max" : hf.toFixed(3)}</strong></div>
      </div>

      <input value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="Amount" />

      <div className="action-row">
        <button
          disabled={!address || parsed === 0n}
          onClick={() =>
            runAndRefresh("Borrowing...", () =>
              writeContractAsync({
                address: addresses.lendingPool,
                abi: lendingAbi,
                functionName: "borrow",
                args: [parsed],
                gas: 300_000n,
                maxFeePerGas: 500_000_000n,
                maxPriorityFeePerGas: 0n
              })
            )
          }
        >
          Borrow
        </button>

        <button
          disabled={!address || parsed === 0n}
          onClick={() =>
            runAndRefresh("Repaying...", async () => {
              await approveIfNeeded(addresses.borrowToken, parsed);
              return writeContractAsync({
                address: addresses.lendingPool,
                abi: lendingAbi,
                functionName: "repay",
                args: [parsed],
                gas: 300_000n,
                maxFeePerGas: 500_000_000n,
                maxPriorityFeePerGas: 0n
              });
            })
          }
        >
          Repay
        </button>
      </div>

      <div className="action-row">
        <button
          disabled={!address || parsed === 0n}
          onClick={() =>
            runAndRefresh("Depositing collateral...", async () => {
              await approveIfNeeded(addresses.collateralToken, parsed);
              return writeContractAsync({
                address: addresses.lendingPool,
                abi: lendingAbi,
                functionName: "depositCollateral",
                args: [parsed],
                gas: 300_000n,
                maxFeePerGas: 500_000_000n,
                maxPriorityFeePerGas: 0n
              });
            })
          }
        >
          Deposit Collateral
        </button>

        <button
          disabled={!address || parsed === 0n}
          onClick={() =>
            runAndRefresh("Withdrawing collateral...", () =>
              writeContractAsync({
                address: addresses.lendingPool,
                abi: lendingAbi,
                functionName: "withdrawCollateral",
                args: [parsed],
                gas: 300_000n,
                maxFeePerGas: 500_000_000n,
                maxPriorityFeePerGas: 0n
              })
            )
          }
        >
          Withdraw Collateral
        </button>
      </div>

      {tx.status && <p className="status">{tx.status}</p>}
    </section>
  );
}
