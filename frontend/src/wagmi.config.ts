import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { arbitrumSepolia } from "wagmi/chains";
import { fallback, http } from "wagmi";

const alchemyRpcUrl =
  import.meta.env.VITE_ALCHEMY_RPC_URL ??
  import.meta.env.ALCHEMY_RPC_URL ??
  "https://arb-sepolia.g.alchemy.com/v2/demo";

export const config = getDefaultConfig({
  appName: "DeFi Super-App",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ?? "00000000000000000000000000000000",
  chains: [arbitrumSepolia],
  transports: {
    [arbitrumSepolia.id]: fallback([
      http(alchemyRpcUrl),
      http("https://sepolia-rollup.arbitrum.io/rpc")
    ])
  },
  ssr: false
});
