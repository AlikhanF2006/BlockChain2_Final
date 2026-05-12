import { parseUnits } from "viem";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { addresses, lendingAbi } from "../constants/addresses";

export function useLending(amountText: string) {
  const { address } = useAccount();
  const amount = amountText ? parseUnits(amountText, 18) : 0n;
  const { writeContractAsync } = useWriteContract();
  const healthFactor = useReadContract({
    address: addresses.lendingPool,
    abi: lendingAbi,
    functionName: "getHealthFactor",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) }
  });

  return { amount, healthFactor: healthFactor.data, writeContractAsync };
}
