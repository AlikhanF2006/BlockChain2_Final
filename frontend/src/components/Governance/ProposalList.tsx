import { useEffect, useMemo, useState } from "react";
import { encodeAbiParameters, formatEther, keccak256, toBytes, type Address, type Hex } from "viem";
import { useAccount, useBlockNumber, usePublicClient, useReadContract, useWriteContract } from "wagmi";
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

const STORAGE_KEY = "defi-super-app-local-proposal";

export function ProposalList() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();
  const tx = useTransactionToast();
  const block = useBlockNumber({ watch: true });
  const [description, setDescription] = useState("Demo proposal: no-op governance execution");
  const [proposal, setProposal] = useState<LocalProposal | null>(null);

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) setProposal(JSON.parse(saved));
  }, []);

  const votes = useReadContract({
    address: addresses.govToken,
    abi: erc20Abi,
    functionName: "getVotes",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(address) }
  });

  const proposalState = useReadContract({
    address: addresses.governor,
    abi: governorAbi,
    functionName: "state",
    args: proposal ? [BigInt(proposal.id)] : undefined,
    query: { enabled: Boolean(proposal) }
  });

  const snapshot = useReadContract({
    address: addresses.governor,
    abi: governorAbi,
    functionName: "proposalSnapshot",
    args: proposal ? [BigInt(proposal.id)] : undefined,
    query: { enabled: Boolean(proposal) }
  });

  const deadline = useReadContract({
    address: addresses.governor,
    abi: governorAbi,
    functionName: "proposalDeadline",
    args: proposal ? [BigInt(proposal.id)] : undefined,
    query: { enabled: Boolean(proposal) }
  });

  const readableState = proposalState.data !== undefined ? stateNames[Number(proposalState.data)] : "No proposal";

  const descriptionHash = useMemo(() => {
    return proposal ? keccak256(toBytes(proposal.description)) : keccak256(toBytes(description));
  }, [proposal, description]);

  const targets = useMemo(() => [proposal?.target ?? address ?? addresses.governor] as Address[], [proposal, address]);
  const values = useMemo(() => [0n], []);
  const calldatas = useMemo(() => [proposal?.calldata ?? "0x"] as Hex[], [proposal]);

  async function refresh() {
    await Promise.all([votes.refetch(), proposalState.refetch(), snapshot.refetch(), deadline.refetch()]);
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
    const localDescription = description || "Demo proposal";

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

    const saved: LocalProposal = {
      id: id.toString(),
      description: localDescription,
      target: address,
      value: "0",
      calldata: "0x"
    };

    localStorage.setItem(STORAGE_KEY, JSON.stringify(saved));
    setProposal(saved);
    await refresh();
  }

  async function vote(support: 0 | 1 | 2) {
    if (!proposal) return;

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
    if (!proposal) return;

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
    if (!proposal) return;

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

  function clearLocalProposal() {
    localStorage.removeItem(STORAGE_KEY);
    setProposal(null);
  }

  return (
    <section className="panel wide">
      <div className="panel-title">
        <h2>Governance</h2>
        <span>{proposal ? readableState : "0 proposals"}</span>
      </div>

      <div className="metrics">
        <div>
          <span>Voting power</span>
          <strong>{votes.data ? formatEther(votes.data) : "0"}</strong>
        </div>
        <div>
          <span>Current block</span>
          <strong>{block.data?.toString() ?? "Loading"}</strong>
        </div>
        <div>
          <span>Snapshot / Deadline</span>
          <strong>
            {snapshot.data?.toString() ?? "-"} / {deadline.data?.toString() ?? "-"}
          </strong>
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
        <button disabled={!proposal} onClick={clearLocalProposal}>
          Clear Local Proposal
        </button>
      </div>

      {proposal && (
        <article className="proposal">
          <div>
            <span className="badge blue">{readableState}</span>
            <h3>{proposal.description}</h3>
            <p className="muted">Proposal ID: {proposal.id.slice(0, 18)}...</p>
            <p className="muted">Target: {proposal.target}</p>
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
          </div>
        </article>
      )}

      {tx.status && <p className="status">{tx.status}</p>}
    </section>
  );
}
