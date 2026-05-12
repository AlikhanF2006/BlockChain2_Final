import { useMemo, useState } from "react";
import { useBlockNumber } from "wagmi";
import { useProposals, type Proposal } from "../../hooks/useSubgraph";
import { VoteModal } from "./VoteModal";

const stateClass: Record<string, string> = {
  Pending: "gray",
  Active: "blue",
  Succeeded: "green",
  Defeated: "red",
  Queued: "yellow",
  Executed: "purple"
};

export function ProposalList() {
  const { data, isLoading } = useProposals();
  const block = useBlockNumber({ watch: true });
  const [selected, setSelected] = useState<Proposal | null>(null);
  const proposals = data?.proposals ?? [];

  return (
    <section className="panel wide">
      <div className="panel-title">
        <h2>Governance</h2>
        <span>{isLoading ? "Loading" : `${proposals.length} proposals`}</span>
      </div>
      <div className="proposal-list">
        {proposals.map((proposal) => (
          <ProposalRow
            key={proposal.id}
            proposal={proposal}
            currentBlock={block.data ?? 0n}
            onVote={() => setSelected(proposal)}
          />
        ))}
      </div>
      {selected && <VoteModal proposal={selected} onClose={() => setSelected(null)} />}
    </section>
  );
}

function ProposalRow({ proposal, currentBlock, onVote }: { proposal: Proposal; currentBlock: bigint; onVote: () => void }) {
  const forVotes = BigInt(proposal.forVotes);
  const againstVotes = BigInt(proposal.againstVotes);
  const total = forVotes + againstVotes;
  const progress = total === 0n ? 0 : Number((forVotes * 100n) / total);
  const remaining = useMemo(() => {
    const end = BigInt(proposal.endBlock);
    return end > currentBlock ? `${end - currentBlock} blocks` : "Closed";
  }, [currentBlock, proposal.endBlock]);

  return (
    <article className="proposal">
      <div>
        <span className={`badge ${stateClass[proposal.state] ?? "gray"}`}>{proposal.state}</span>
        <h3>{proposal.description}</h3>
        <p className="muted">Ends in {remaining}</p>
      </div>
      <div className="progress"><span style={{ width: `${progress}%` }} /></div>
      <button disabled={proposal.state !== "Active"} onClick={onVote}>Vote</button>
    </article>
  );
}
