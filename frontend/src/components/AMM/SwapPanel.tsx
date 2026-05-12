import { useMemo, useState } from "react";
import { formatUnits, parseUnits, type Address } from "viem";
import { useAccount } from "wagmi";
import { addresses, ammAbi, erc20Abi, tokenOptions } from "../../constants/addresses";
import { useAMM } from "../../hooks/useAMM";
import { useTransactionToast } from "../../hooks/useTransactionToast";

export function SwapPanel() {
  const { address } = useAccount();
  const [tokenIn, setTokenIn] = useState<Address>(addresses.tokenA);
  const [amountText, setAmountText] = useState("");
  const [slippageBps, setSlippageBps] = useState(50);
  const amm = useAMM(tokenIn, amountText);
  const tx = useTransactionToast();
  const tokenOut = tokenIn.toLowerCase() === addresses.tokenA.toLowerCase() ? addresses.tokenB : addresses.tokenA;

  const minOut = useMemo(() => (amm.quote * BigInt(10000 - slippageBps)) / 10000n, [amm.quote, slippageBps]);
  const hasBalance = amm.amount <= amm.balance;
  const approved = amm.amount > 0n && amm.allowance >= amm.amount;
  const amountValid = amm.amount > 0n;
  const arbiscan = tx.hash ? `https://sepolia.arbiscan.io/tx/${tx.hash}` : "";

  return (
    <section className="panel">
      <div className="panel-title">
        <h2>Swap</h2>
        <span>{amm.priceImpact}% impact</span>
      </div>
      <div className="field-row">
        <select value={tokenIn} onChange={(event) => setTokenIn(event.target.value as Address)}>
          {tokenOptions.map((token) => (
            <option key={token.address} value={token.address}>{token.label}</option>
          ))}
        </select>
        <input value={amountText} onChange={(event) => setAmountText(event.target.value)} placeholder="0.0" />
        <button onClick={() => setAmountText(formatUnits(amm.balance, 18))}>Max</button>
      </div>
      <div className="quote-grid">
        <span>Minimum received</span>
        <strong>{formatUnits(minOut, 18)}</strong>
        <span>Slippage</span>
        <input
          type="number"
          value={slippageBps / 100}
          onChange={(event) => setSlippageBps(Math.max(0, Number(event.target.value) * 100))}
        />
      </div>
      {!hasBalance && <p className="error">Insufficient balance</p>}
      {amountValid && hasBalance && !approved && <p className="muted">Approve first</p>}
      <div className="action-row">
        <button
          disabled={!amountValid || !hasBalance || approved}
          onClick={() =>
            tx.run("Approving...", () =>
              amm.writeContractAsync({
                address: tokenIn,
                abi: erc20Abi,
                functionName: "approve",
                args: [addresses.ammPool, amm.amount]
              })
            )
          }
        >
          Approve
        </button>
        <button
          disabled={!amountValid || !hasBalance || !approved || !address}
          onClick={() =>
            tx.run("Swapping...", () =>
              amm.writeContractAsync({
                address: addresses.ammPool,
                abi: ammAbi,
                functionName: "swapExactTokensForTokens",
                args: [amm.amount, minOut, tokenIn, address!, BigInt(Math.floor(Date.now() / 1000) + 1200)]
              })
            )
          }
        >
          Swap
        </button>
      </div>
      <p className="muted">Output token {tokenOut}</p>
      {tx.status && <p className="status">{tx.status}</p>}
      {tx.hash && <a href={arbiscan} target="_blank" rel="noreferrer">View transaction</a>}
    </section>
  );
}
