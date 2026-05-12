import { useMemo, useState } from "react";
import { formatUnits, parseUnits } from "viem";
import { useAccount, useWriteContract } from "wagmi";
import { addresses, ammAbi } from "../../constants/addresses";
import { useLiquidityReads } from "../../hooks/useAMM";
import { useTransactionToast } from "../../hooks/useTransactionToast";

export function LiquidityPanel() {
  const { address } = useAccount();
  const [amountA, setAmountA] = useState("");
  const [amountB, setAmountB] = useState("");
  const reads = useLiquidityReads(address);
  const { writeContractAsync } = useWriteContract();
  const tx = useTransactionToast();

  const reserves = reads.data?.[0].result as readonly [bigint, bigint, number] | undefined;
  const lpBalance = (reads.data?.[1].result as bigint | undefined) ?? 0n;
  const parsedA = amountA ? parseUnits(amountA, 18) : 0n;
  const parsedB = amountB ? parseUnits(amountB, 18) : 0n;
  const estimatedLp = useMemo(() => (parsedA > 0n && parsedB > 0n ? sqrt(parsedA * parsedB) : 0n), [parsedA, parsedB]);
  const poolShare = lpBalance === 0n ? "0.00" : "0.01";

  function autofillB(value: string) {
    setAmountA(value);
    if (!reserves || reserves[0] === 0n) return;
    const a = value ? parseUnits(value, 18) : 0n;
    setAmountB(formatUnits((a * reserves[1]) / reserves[0], 18));
  }

  return (
    <section className="panel">
      <div className="panel-title">
        <h2>Liquidity</h2>
        <span>{poolShare}% pool share</span>
      </div>
      <input value={amountA} onChange={(event) => autofillB(event.target.value)} placeholder="Token A amount" />
      <input value={amountB} onChange={(event) => setAmountB(event.target.value)} placeholder="Token B amount" />
      <div className="quote-grid">
        <span>LP tokens to receive</span>
        <strong>{formatUnits(estimatedLp, 18)}</strong>
      </div>
      <button
        disabled={!address || parsedA === 0n || parsedB === 0n}
        onClick={() =>
          tx.run("Adding liquidity...", () =>
            writeContractAsync({
              address: addresses.ammPool,
              abi: ammAbi,
              functionName: "addLiquidity",
              args: [parsedA, parsedB, 0n, 0n, address!, BigInt(Math.floor(Date.now() / 1000) + 1200)]
            })
          )
        }
      >
        Add Liquidity
      </button>
      {tx.status && <p className="status">{tx.status}</p>}
    </section>
  );
}

function sqrt(value: bigint): bigint {
  if (value < 2n) return value;
  let x0 = value / 2n;
  let x1 = (x0 + value / x0) / 2n;
  while (x1 < x0) {
    x0 = x1;
    x1 = (x0 + value / x0) / 2n;
  }
  return x0;
}
