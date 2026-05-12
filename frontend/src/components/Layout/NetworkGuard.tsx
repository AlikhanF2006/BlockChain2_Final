import { arbitrumSepolia } from "wagmi/chains";
import { useChainId, useSwitchChain } from "wagmi";
import type { ReactNode } from "react";

export function NetworkGuard({ children }: { children: ReactNode }) {
  const chainId = useChainId();
  const { switchChain, isPending } = useSwitchChain();

  if (chainId !== arbitrumSepolia.id) {
    return (
      <main className="network-lock">
        <section className="banner">
          <strong>Wrong Network — Please switch to Arbitrum Sepolia</strong>
          <button onClick={() => switchChain({ chainId: arbitrumSepolia.id })} disabled={isPending}>
            {isPending ? "Switching..." : "Switch Network"}
          </button>
        </section>
      </main>
    );
  }

  return <>{children}</>;
}
