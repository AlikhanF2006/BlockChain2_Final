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

  const collateralBalance = useReadContract({
    address: addresses.lendingPool,
    abi: lendingAbi,
    functionName: "collateralBalance",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) }
  });

  const debtBalance = useReadContract({
    address: addresses.lendingPool,
    abi: lendingAbi,
    functionName: "borrows",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) }
  });

  async function refetch() {
    await Promise.all([
      healthFactor.refetch(),
      collateralBalance.refetch(),
      debtBalance.refetch()
    ]);
  }

  return {
    amount,
    healthFactor: healthFactor.data,
    collateralBalance: collateralBalance.data,
    debtBalance: debtBalance.data,
    writeContractAsync,
    refetch
  };
}
