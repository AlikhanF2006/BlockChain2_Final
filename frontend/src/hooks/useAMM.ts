import { useMemo } from "react";
import { formatUnits, parseUnits, type Address } from "viem";
import { useAccount, useReadContract, useReadContracts, useWriteContract } from "wagmi";
import { addresses, ammAbi, erc20Abi } from "../constants/addresses";

export function useAMM(tokenIn: Address, amountText: string) {
  const { address } = useAccount();
  const amount = amountText ? parseUnits(amountText, 18) : 0n;
  const { writeContractAsync } = useWriteContract();

  const reserves = useReadContract({
    address: addresses.ammPool,
    abi: ammAbi,
    functionName: "getReserves"
  });

  const poolTokenA = useReadContract({
    address: addresses.ammPool,
    abi: ammAbi,
    functionName: "tokenA"
  });

  const poolTokenB = useReadContract({
    address: addresses.ammPool,
    abi: ammAbi,
    functionName: "tokenB"
  });

  const balance = useReadContract({
    address: tokenIn,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) }
  });

  const allowance = useReadContract({
    address: tokenIn,
    abi: erc20Abi,
    functionName: "allowance",
    args: address ? [address, addresses.ammPool] : undefined,
    query: { enabled: Boolean(address) }
  });

  const [reserveIn, reserveOut] = useMemo(() => {
    const data = reserves.data;
    const onchainTokenA = poolTokenA.data?.toLowerCase();
    const onchainTokenB = poolTokenB.data?.toLowerCase();

    if (!data || !onchainTokenA || !onchainTokenB) return [0n, 0n];

    const [reserveA, reserveB] = data;
    const selected = tokenIn.toLowerCase();

    if (selected === onchainTokenA) return [reserveA, reserveB];
    if (selected === onchainTokenB) return [reserveB, reserveA];

    return [0n, 0n];
  }, [reserves.data, poolTokenA.data, poolTokenB.data, tokenIn]);

  const quote = useMemo(() => {
    if (amount === 0n || reserveIn === 0n || reserveOut === 0n) return 0n;
    const amountInWithFee = amount * 997n;
    return (amountInWithFee * reserveOut) / (reserveIn * 1000n + amountInWithFee);
  }, [amount, reserveIn, reserveOut]);

  const priceImpact = useMemo(() => {
    if (amount === 0n || reserveIn === 0n || reserveOut === 0n || quote === 0n) return "0.00";
    const spotOut = (amount * reserveOut) / reserveIn;
    if (spotOut === 0n) return "0.00";
    const impactBps = ((spotOut - quote) * 10000n) / spotOut;
    return (Number(impactBps) / 100).toFixed(2);
  }, [amount, quote, reserveIn, reserveOut]);

  return {
    amount,
    quote,
    reserveIn,
    reserveOut,
    formattedQuote: formatUnits(quote, 18),
    priceImpact,
    balance: balance.data ?? 0n,
    allowance: allowance.data ?? 0n,
    reserves,
    writeContractAsync
  };
}

export function useLiquidityReads(account?: Address) {
  return useReadContracts({
    contracts: [
      { address: addresses.ammPool, abi: ammAbi, functionName: "getReserves" },
      { address: addresses.lpToken, abi: erc20Abi, functionName: "balanceOf", args: account ? [account] : undefined }
    ],
    query: { enabled: Boolean(account) }
  });
}
