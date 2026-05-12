import { useState } from "react";
import { formatEther } from "viem";
import { useAccount } from "wagmi";
import { addresses, governorAbi } from "../../constants/addresses";
import { useGovernance, useVotingPower } from "../../hooks/useGovernance";
import { useTransactionToast } from "../../hooks/useTransactionToast";
import type { Proposal } from "../../hooks/useSubgraph";

export function VoteModal({ proposal, onClose }: { proposal: Proposal; onClose: () => void }) {
  const { address } = useAccount();
  const [support, setSupport] = useState<0 | 1 | 2>(1);
  const [reason, setReason] = useState("");
  const governance = useGovernance();
  const tx = useTransactionToast();
  const votingPower = useVotingPower(address, BigInt(proposal.startBlock));

  return (
    <div className="modal-backdrop">
      <section className="modal">
        <div className="panel-title">
          <h2>Vote</h2>
          <button onClick={onClose}>Close</button>
        </div>
        <p>{proposal.description}</p>
        <p className="muted">Voting power {(votingPower as any).data ? formatEther((votingPower as any).data as bigint) : "0"}</p>
        <div className="segmented">
          <button className={support === 1 ? "selected" : ""} onClick={() => setSupport(1)}>For</button>
          <button className={support === 0 ? "selected" : ""} onClick={() => setSupport(0)}>Against</button>
          <button className={support === 2 ? "selected" : ""} onClick={() => setSupport(2)}>Abstain</button>
        </div>
        <input value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Reason" />
        <button
          disabled={!address}
          onClick={() =>
            tx.run("Voting...", () =>
              governance.writeContractAsync({
                address: addresses.governor,
                abi: governorAbi,
                functionName: "castVoteWithReason",
                args: [BigInt(proposal.id), support, reason]
              })
            )
          }
        >
          Submit Vote
        </button>
        {tx.status && <p className="status">{tx.status}</p>}
      </section>
    </div>
  );
}
