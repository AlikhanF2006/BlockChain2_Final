import { Header } from "./components/Layout/Header";
import { NetworkGuard } from "./components/Layout/NetworkGuard";
import { SwapPanel } from "./components/AMM/SwapPanel";
import { LiquidityPanel } from "./components/AMM/LiquidityPanel";
import { LoanDashboard } from "./components/Lending/LoanDashboard";
import { VaultPanel } from "./components/Vault/VaultPanel";
import { ProposalList } from "./components/Governance/ProposalList";

export default function App() {
  return (
    <NetworkGuard>
      <Header />
      <main className="app-shell">
        <div className="grid two">
          <SwapPanel />
          <LiquidityPanel />
        </div>
        <div className="grid two">
          <LoanDashboard />
          <VaultPanel />
        </div>
        <ProposalList />
      </main>
    </NetworkGuard>
  );
}
