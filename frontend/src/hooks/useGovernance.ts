import { useReadContract, useWriteContract } from "wagmi";
import { addresses, erc20Abi } from "../constants/addresses";
import type { Address } from "viem";

export function useVotingPower(account?: Address, snapshotBlock?: bigint) {
  return useReadContract({
    address: addresses.govToken,
    abi: erc20Abi,
    functionName: snapshotBlock ? "getPastVotes" : "getVotes",
    args: account ? (snapshotBlock ? [account, snapshotBlock] : [account]) : undefined,
    query: { enabled: Boolean(account) }
  });
}

export function useGovernance() {
  return useWriteContract();
}
