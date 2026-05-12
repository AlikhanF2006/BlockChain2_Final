import { useMemo, useState } from "react";
import { formatUnits, parseUnits } from "viem";
import { useAccount, useWriteContract } from "wagmi";
import { addresses, lendingAbi } from "../../constants/addresses";
import { useLoanPosition } from "../../hooks/useSubgraph";
import { useLending } from "../../hooks/useLending";
import { useTransactionToast } from "../../hooks/useTransactionToast";

export function LoanDashboard() {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");
  const { data } = useLoanPosition(address);
  const lending = useLending(amount);
  const { writeContractAsync } = useWriteContract();
  const tx = useTransactionToast();
  const parsed = amount ? parseUnits(amount, 18) : 0n;
  const position = data?.loanPosition;

  const hf = useMemo(() => {
    if (lending.healthFactor && lending.healthFactor < 10n ** 30n) return Number(formatUnits(lending.healthFactor, 18));
    return Number(position?.healthFactor ?? "999");
  }, [lending.healthFactor, position?.healthFactor]);

  const gaugeClass = hf < 1.1 ? "danger" : hf <= 1.5 ? "warning" : "healthy";

  return (
    <section className="panel wide">
      <div className="panel-title">
        <h2>Lending</h2>
        <span className={gaugeClass}>{hf > 100 ? "No debt" : hf.toFixed(2)}</span>
      </div>
      <div className="metrics">
        <div><span>Collateral</span><strong>{position?.collateralAmount ?? "0"}</strong></div>
        <div><span>Debt</span><strong>{position?.debtAmount ?? "0"}</strong></div>
        <div><span>Health factor</span><strong>{hf > 100 ? "Max" : hf.toFixed(3)}</strong></div>
      </div>
      <input value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="Amount" />
      <div className="action-row">
        <button
          disabled={!address || parsed === 0n}
          onClick={() => tx.run("Borrowing...", () => writeContractAsync({ address: addresses.lendingPool, abi: lendingAbi, functionName: "borrow", args: [parsed] }))}
        >
          Borrow
        </button>
        <button
          disabled={!address || parsed === 0n}
          onClick={() => tx.run("Repaying...", () => writeContractAsync({ address: addresses.lendingPool, abi: lendingAbi, functionName: "repay", args: [parsed] }))}
        >
          Repay
        </button>
      </div>
      <div className="action-row">
        <button
          disabled={!address || parsed === 0n}
          onClick={() => tx.run("Depositing collateral...", () => writeContractAsync({ address: addresses.lendingPool, abi: lendingAbi, functionName: "depositCollateral", args: [parsed] }))}
        >
          Deposit Collateral
        </button>
        <button
          disabled={!address || parsed === 0n}
          onClick={() => tx.run("Withdrawing collateral...", () => writeContractAsync({ address: addresses.lendingPool, abi: lendingAbi, functionName: "withdrawCollateral", args: [parsed] }))}
        >
          Withdraw Collateral
        </button>
      </div>
      {tx.status && <p className="status">{tx.status}</p>}
    </section>
  );
}
