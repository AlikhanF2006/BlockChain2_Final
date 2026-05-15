import { useEffect, useMemo, useState } from "react";
import { formatEther, keccak256, toBytes, type Address, type Hex } from "viem";
import { useAccount, usePublicClient, useReadContract, useWriteContract } from "wagmi";
import { addresses, erc20Abi } from "../../constants/addresses";
import { useTransactionToast } from "../../hooks/useTransactionToast";

const governorAbi = [
  {
    type: "function",
    name: "propose",
    stateMutability: "nonpayable",
    inputs: [
      { name: "targets", type: "address[]" },
      { name: "values", type: "uint256[]" },
      { name: "calldatas", type: "bytes[]" },
      { name: "description", type: "string" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "hashProposal",
    stateMutability: "view",
    inputs: [
      { name: "targets", type: "address[]" },
      { name: "values", type: "uint256[]" },
      { name: "calldatas", type: "bytes[]" },
      { name: "descriptionHash", type: "bytes32" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "state",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "uint8" }]
  },
  {
    type: "function",
    name: "proposalSnapshot",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "proposalDeadline",
    stateMutability: "view",
    inputs: [{ name: "proposalId", type: "uint256" }],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "clock",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint48" }]
  },
  {
    type: "function",
    name: "castVote",
    stateMutability: "nonpayable",
    inputs: [
      { name: "proposalId", type: "uint256" },
      { name: "support", type: "uint8" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "queue",
    stateMutability: "nonpayable",
    inputs: [
      { name: "targets", type: "address[]" },
      { name: "values", type: "uint256[]" },
      { name: "calldatas", type: "bytes[]" },
      { name: "descriptionHash", type: "bytes32" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "execute",
    stateMutability: "payable",
    inputs: [
      { name: "targets", type: "address[]" },
      { name: "values", type: "uint256[]" },
      { name: "calldatas", type: "bytes[]" },
      { name: "descriptionHash", type: "bytes32" }
    ],
    outputs: [{ type: "uint256" }]
  }
] as const;

const stateNames = [
  "Pending",
  "Active",
  "Canceled",
  "Defeated",
  "Succeeded",
  "Queued",
  "Expired",
  "Executed"
];

type LocalProposal = {
  id: string;
  description: string;
  target: Address;
  value: string;
  calldata: Hex;
};

const STORAGE_KEY = "defi-super-app-local-proposals";

export function ProposalList() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();
  const tx = useTransactionToast();

  const [description, setDescription] = useState("Demo proposal: no-op governance execution");
  const [proposals, setProposals] = useState<LocalProposal[]>([]);

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      try {
        setProposals(JSON.parse(saved));
      } catch {
        localStorage.removeItem(STORAGE_KEY);
      }
    }
  }, []);

  const votes = useReadContract({
    address: addresses.govToken,
    abi: erc20Abi,
    functionName: "getVotes",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address), refetchInterval: 10_000 }
  });

  const governorClock = useReadContract({
    address: addresses.governor,
    abi: governorAbi,
    functionName: "clock",
    query: { refetchInterval: 10_000 }
  });

  async function refresh() {
    await Promise.all([votes.refetch(), governorClock.refetch()]);
  }

  function saveProposals(next: LocalProposal[]) {
    setProposals(next);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  }

  async function delegateToMyself() {
    if (!address) return;

    await tx.run("Delegating votes...", () =>
      writeContractAsync({
        address: addresses.govToken,
        abi: erc20Abi,
        functionName: "delegate",
        args: [address],
        gas: 150_000n,
        maxFeePerGas: 500_000_000n,
        maxPriorityFeePerGas: 0n
      })
    );

    await refresh();
  }

  async function createProposal() {
    if (!address || !publicClient) return;

    const localTargets = [address] as Address[];
    const localValues = [0n];
    const localCalldatas = ["0x"] as Hex[];
    const localDescription = description.trim() || `Demo proposal ${Date.now()}`;

    const hash = await tx.run("Creating proposal...", () =>
      writeContractAsync({
        address: addresses.governor,
        abi: governorAbi,
        functionName: "propose",
        args: [localTargets, localValues, localCalldatas, localDescription],
        gas: 600_000n,
        maxFeePerGas: 500_000_000n,
        maxPriorityFeePerGas: 0n
      })
    );

    if (!hash) return;

    await publicClient.waitForTransactionReceipt({ hash, confirmations: 1 });

    const id = await publicClient.readContract({
      address: addresses.governor,
      abi: governorAbi,
      functionName: "hashProposal",
      args: [localTargets, localValues, localCalldatas, keccak256(toBytes(localDescription))]
    });

    const newProposal: LocalProposal = {
      id: id.toString(),
      description: localDescription,
      target: address,
      value: "0",
      calldata: "0x"
    };

    const next = [newProposal, ...proposals.filter((item) => item.id !== newProposal.id)];
    saveProposals(next);
    await refresh();
  }

  function clearAllLocalProposals() {
    localStorage.removeItem(STORAGE_KEY);
    setProposals([]);
  }

  function removeOneProposal(id: string) {
    const next = proposals.filter((item) => item.id !== id);
    saveProposals(next);
  }

  return (
    <section className="panel wide">
      <div className="panel-title">
        <h2>Governance</h2>
        <span>{proposals.length} proposals</span>
      </div>

      <div className="metrics">
        <div>
          <span>Voting power</span>
          <strong>{votes.data ? formatEther(votes.data) : "0"}</strong>
        </div>
        <div>
          <span>Governor clock</span>
          <strong>{governorClock.data?.toString() ?? "Loading"}</strong>
        </div>
        <div>
          <span>Flow</span>
          <strong>Pending → Active → Vote → Queue → Execute</strong>
        </div>
      </div>

      <div className="action-row">
        <button disabled={!address} onClick={delegateToMyself}>
          Delegate to Myself
        </button>
      </div>

      <input
        value={description}
        onChange={(event) => setDescription(event.target.value)}
        placeholder="Proposal description"
      />

      <div className="action-row">
        <button disabled={!address} onClick={createProposal}>
          Create Proposal
        </button>
        <button disabled={proposals.length === 0} onClick={clearAllLocalProposals}>
          Clear All Local Proposals
        </button>
      </div>

      {proposals.map((proposal) => (
        <ProposalCard
          key={proposal.id}
          proposal={proposal}
          governorClock={governorClock.data ? BigInt(governorClock.data) : undefined}
          onRemove={() => removeOneProposal(proposal.id)}
        />
      ))}

      {tx.status && <p className="status">{tx.status}</p>}
    </section>
  );
}

function ProposalCard({
  proposal,
  governorClock,
  onRemove
}: {
  proposal: LocalProposal;
  governorClock?: bigint;
  onRemove: () => void;
}) {
  const { writeContractAsync } = useWriteContract();
  const tx = useTransactionToast();

  const proposalState = useReadContract({
    address: addresses.governor,
    abi: governorAbi,
    functionName: "state",
    args: [BigInt(proposal.id)],
    query: { refetchInterval: 10_000 }
  });

  const snapshot = useReadContract({
    address: addresses.governor,
    abi: governorAbi,
    functionName: "proposalSnapshot",
    args: [BigInt(proposal.id)],
    query: { refetchInterval: 10_000 }
  });

  const deadline = useReadContract({
    address: addresses.governor,
    abi: governorAbi,
    functionName: "proposalDeadline",
    args: [BigInt(proposal.id)],
    query: { refetchInterval: 10_000 }
  });

  const readableState = proposalState.data !== undefined ? stateNames[Number(proposalState.data)] : "Loading";

  const descriptionHash = keccak256(toBytes(proposal.description));
  const targets = [proposal.target] as Address[];
  const values = [BigInt(proposal.value)];
  const calldatas = [proposal.calldata] as Hex[];

  const hint = useMemo(() => {
    if (!governorClock || !snapshot.data || !deadline.data) return "Loading proposal state...";

    if (readableState === "Pending" && snapshot.data > governorClock) {
      return `Wait ${snapshot.data - governorClock} governor clock units until voting becomes Active.`;
    }

    if (readableState === "Active" && deadline.data > governorClock) {
      return `Voting is open. ${deadline.data - governorClock} governor clock units left.`;
    }

    if (readableState === "Succeeded") return "Proposal succeeded. Queue is available.";
    if (readableState === "Queued") return "Proposal queued. Execute after Timelock delay.";
    if (readableState === "Executed") return "Proposal executed.";
    if (readableState === "Defeated") return "Proposal defeated.";

    return "Follow the enabled button for the next step.";
  }, [governorClock, snapshot.data, deadline.data, readableState]);

  async function refresh() {
    await Promise.all([proposalState.refetch(), snapshot.refetch(), deadline.refetch()]);
  }

  async function vote(support: 0 | 1 | 2) {
    await tx.run(
      support === 1 ? "Voting For..." : support === 0 ? "Voting Against..." : "Voting Abstain...",
      () =>
        writeContractAsync({
          address: addresses.governor,
          abi: governorAbi,
          functionName: "castVote",
          args: [BigInt(proposal.id), support],
          gas: 300_000n,
          maxFeePerGas: 500_000_000n,
          maxPriorityFeePerGas: 0n
        })
    );

    await refresh();
  }

  async function queueProposal() {
    await tx.run("Queueing proposal...", () =>
      writeContractAsync({
        address: addresses.governor,
        abi: governorAbi,
        functionName: "queue",
        args: [targets, values, calldatas, descriptionHash],
        gas: 500_000n,
        maxFeePerGas: 500_000_000n,
        maxPriorityFeePerGas: 0n
      })
    );

    await refresh();
  }

  async function executeProposal() {
    await tx.run("Executing proposal...", () =>
      writeContractAsync({
        address: addresses.governor,
        abi: governorAbi,
        functionName: "execute",
        args: [targets, values, calldatas, descriptionHash],
        value: 0n,
        gas: 500_000n,
        maxFeePerGas: 500_000_000n,
        maxPriorityFeePerGas: 0n
      })
    );

    await refresh();
  }

  return (
    <article className="proposal">
      <div>
        <span className="badge blue">{readableState}</span>
        <h3>{proposal.description}</h3>
        <p className="muted">Proposal ID: {proposal.id.slice(0, 24)}...</p>
        <p className="muted">Target: {proposal.target}</p>
        <p className="muted">
          Snapshot / Deadline: {snapshot.data?.toString() ?? "-"} / {deadline.data?.toString() ?? "-"}
        </p>
        <p className="muted">{hint}</p>
      </div>

      <div className="action-row">
        <button disabled={readableState !== "Active"} onClick={() => vote(1)}>
          Vote For
        </button>
        <button disabled={readableState !== "Active"} onClick={() => vote(0)}>
          Vote Against
        </button>
        <button disabled={readableState !== "Active"} onClick={() => vote(2)}>
          Vote Abstain
        </button>
      </div>

      <div className="action-row">
        <button disabled={readableState !== "Succeeded"} onClick={queueProposal}>
          Queue
        </button>
        <button disabled={readableState !== "Queued"} onClick={executeProposal}>
          Execute
        </button>
        <button onClick={onRemove}>
          Remove from UI
        </button>
      </div>

      {tx.status && <p className="status">{tx.status}</p>}
    </article>
  );
}
