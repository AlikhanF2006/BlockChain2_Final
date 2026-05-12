import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  VoteCast
} from "../generated/DeFiGovernor/DeFiGovernor";
import { Proposal, Vote } from "../generated/schema";

const ZERO_BI = BigInt.zero();

export function handleProposalCreated(event: ProposalCreated): void {
  let proposal = new Proposal(event.params.proposalId.toString());
  proposal.proposer = event.params.proposer;
  let targets = new Array<Bytes>();
  for (let i = 0; i < event.params.targets.length; i++) {
    targets.push(event.params.targets[i]);
  }
  proposal.targets = targets;
  proposal.description = event.params.description;
  proposal.state = "Pending";
  proposal.forVotes = ZERO_BI;
  proposal.againstVotes = ZERO_BI;
  proposal.abstainVotes = ZERO_BI;
  proposal.startBlock = event.params.startBlock;
  proposal.endBlock = event.params.endBlock;
  proposal.createdAtTimestamp = event.block.timestamp;
  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (proposal == null) return;

  let vote = new Vote(event.params.proposalId.toString().concat("-").concat(event.params.voter.toHexString()));
  vote.proposal = proposal.id;
  vote.voter = event.params.voter;
  vote.support = event.params.support;
  vote.weight = event.params.weight;
  vote.reason = event.params.reason;
  vote.timestamp = event.block.timestamp;
  vote.save();

  if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight);
  } else if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight);
  } else if (event.params.support == 2) {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight);
  }
  proposal.state = "Active";
  proposal.save();
}

export function handleProposalQueued(event: ProposalQueued): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (proposal == null) return;
  proposal.state = "Queued";
  proposal.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = Proposal.load(event.params.proposalId.toString());
  if (proposal == null) return;
  proposal.state = "Executed";
  proposal.save();
}
