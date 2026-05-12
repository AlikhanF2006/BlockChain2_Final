import { useQuery } from "@tanstack/react-query";
import { addresses } from "../constants/addresses";
import { GET_LOAN_POSITION, GET_POOL, GET_PROPOSALS, graphClient } from "../lib/subgraph";

export type Proposal = {
  id: string;
  proposer: string;
  description: string;
  state: string;
  forVotes: string;
  againstVotes: string;
  abstainVotes: string;
  startBlock: string;
  endBlock: string;
};

export type LoanPosition = {
  id: string;
  borrower: string;
  collateralAmount: string;
  debtAmount: string;
  healthFactor: string;
  lastUpdatedTimestamp: string;
};

export function useProposals() {
  return useQuery({
    queryKey: ["proposals"],
    queryFn: async () => graphClient.request<{ proposals: Proposal[] }>(GET_PROPOSALS)
  });
}

export function useLoanPosition(account?: string) {
  return useQuery({
    queryKey: ["loan-position", account?.toLowerCase()],
    enabled: Boolean(account),
    queryFn: async () =>
      graphClient.request<{ loanPosition: LoanPosition | null }>(GET_LOAN_POSITION, {
        id: account?.toLowerCase()
      })
  });
}

export function usePool() {
  return useQuery({
    queryKey: ["pool", addresses.ammPool],
    queryFn: async () => graphClient.request(GET_POOL, { id: addresses.ammPool.toLowerCase() })
  });
}
