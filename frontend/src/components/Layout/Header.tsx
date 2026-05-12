import { ConnectButton } from "@rainbow-me/rainbowkit";
import { formatEther } from "viem";
import { useAccount, useBalance, useReadContracts } from "wagmi";
import { addresses, erc20Abi } from "../../constants/addresses";

function shortAddress(value?: string) {
  return value ? `${value.slice(0, 6)}...${value.slice(-4)}` : "Not connected";
}

export function Header() {
  const { address } = useAccount();
  const ethBalance = useBalance({ address });
  const reads = useReadContracts({
    contracts: [
      { address: addresses.govToken, abi: erc20Abi, functionName: "balanceOf", args: address ? [address] : undefined },
      { address: addresses.govToken, abi: erc20Abi, functionName: "getVotes", args: address ? [address] : undefined },
      { address: addresses.govToken, abi: erc20Abi, functionName: "delegates", args: address ? [address] : undefined }
    ],
    query: { enabled: Boolean(address) }
  });

  const govBalance = reads.data?.[0].result as bigint | undefined;
  const votingPower = reads.data?.[1].result as bigint | undefined;
  const delegate = reads.data?.[2].result as string | undefined;

  return (
    <header className="app-header">
      <div>
        <h1>DeFi Super-App</h1>
        <span className="network-pill">Arbitrum Sepolia</span>
      </div>
      <div className="wallet-strip">
        <span>{shortAddress(address)}</span>
        <span>{ethBalance.data ? `${Number(formatEther(ethBalance.data.value)).toFixed(4)} ETH` : "0 ETH"}</span>
        <span>{govBalance ? `${Number(formatEther(govBalance)).toFixed(2)} GOV` : "0 GOV"}</span>
        <span>{votingPower ? `${Number(formatEther(votingPower)).toFixed(2)} votes` : "0 votes"}</span>
        <span>Delegate {shortAddress(delegate)}</span>
        <ConnectButton />
      </div>
    </header>
  );
}
