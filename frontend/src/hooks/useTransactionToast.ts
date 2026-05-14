import { useState } from "react";
import { ContractFunctionRevertedError, type BaseError, type Hex } from "viem";
import { usePublicClient } from "wagmi";

type TxRunner = () => Promise<Hex>;

function friendlyError(error: unknown): string {
  const err = error as BaseError & { code?: number; shortMessage?: string };
  const message = err?.shortMessage ?? err?.message ?? "Unknown error";

  if (err?.code === 4001 || message.toLowerCase().includes("user rejected")) {
    return "Transaction cancelled";
  }

  const revert = err?.walk?.((cause) => cause instanceof ContractFunctionRevertedError);
  if (revert instanceof ContractFunctionRevertedError) {
    const name = revert.data?.errorName;
    if (name) return `Transaction failed: ${name}`;
  }

  return `Transaction failed: ${message.slice(0, 100)}`;
}

export function useTransactionToast() {
  const [status, setStatus] = useState<string>("");
  const [hash, setHash] = useState<Hex | undefined>();
  const publicClient = usePublicClient();

  async function run(label: string, runner: TxRunner): Promise<Hex | undefined> {
    try {
      setStatus(label);

      const txHash = await runner();
      setHash(txHash);
      setStatus("Confirming...");

      if (publicClient) {
        const receipt = await publicClient.waitForTransactionReceipt({
          hash: txHash,
          confirmations: 1
        });

        if (receipt.status === "success") {
          setStatus("Confirmed");
          return txHash;
        }

        setStatus("Transaction failed on-chain");
        setHash(undefined);
        return undefined;
      }

      setStatus("Submitted");
      return txHash;
    } catch (error) {
      setStatus(friendlyError(error));
      setHash(undefined);
      return undefined;
    }
  }

  return { status, hash, run, setStatus };
}
