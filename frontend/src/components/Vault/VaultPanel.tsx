import { useState } from "react";
import { formatUnits, parseUnits } from "viem";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { addresses, vaultAbi } from "../../constants/addresses";
import { useTransactionToast } from "../../hooks/useTransactionToast";

export function VaultPanel() {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");
  const parsed = amount ? parseUnits(amount, 18) : 0n;
  const { writeContractAsync } = useWriteContract();
  const tx = useTransactionToast();

  const totalAssets = useReadContract({
    address: addresses.yieldVault,
    abi: vaultAbi,
    functionName: "totalAssets"
  });

  async function runAndRefresh(label: string, runner: () => Promise<`0x${string}`>) {
    const hash = await tx.run(label, runner);
    if (hash) await totalAssets.refetch();
  }

  return (
    <section className="panel">
      <div className="panel-title">
        <h2>Vault</h2>
        <span>{totalAssets.data ? formatUnits(totalAssets.data, 18) : "0"} assets</span>
      </div>

      <input value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="Assets" />

      <div className="action-row">
        <button
          disabled={!address || parsed === 0n}
          onClick={() =>
            runAndRefresh("Depositing...", () =>
              writeContractAsync({
                address: addresses.yieldVault,
                abi: vaultAbi,
                functionName: "deposit",
                args: [parsed, address!],
                gas: 500_000n,
                maxFeePerGas: 500_000_000n,
                maxPriorityFeePerGas: 0n
              })
            )
          }
        >
          Deposit
        </button>

        <button
          disabled={!address || parsed === 0n}
          onClick={() =>
            runAndRefresh("Withdrawing...", () =>
              writeContractAsync({
                address: addresses.yieldVault,
                abi: vaultAbi,
                functionName: "withdraw",
                args: [parsed, address!, address!],
                gas: 500_000n,
                maxFeePerGas: 500_000_000n,
                maxPriorityFeePerGas: 0n
              })
            )
          }
        >
          Withdraw
        </button>
      </div>

      {tx.status && <p className="status">{tx.status}</p>}
    </section>
  );
}
