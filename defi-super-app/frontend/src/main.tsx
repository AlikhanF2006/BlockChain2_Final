import React from "react";
import { createRoot } from "react-dom/client";

function App() {
  return (
    <main>
      <h1>DeFi Super-App</h1>
      <p>Token layer scaffold ready for Arbitrum Sepolia deployment.</p>
    </main>
  );
}

const root = document.getElementById("root");

if (!root) {
  throw new Error("Root element #root not found");
}

createRoot(root).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
