import { GraphQLClient, gql } from "graphql-request";

export const SUBGRAPH_URL =
  import.meta.env.VITE_SUBGRAPH_URL ?? "https://api.studio.thegraph.com/query/00000/defi-super-app/version/latest";

export const graphClient = new GraphQLClient(SUBGRAPH_URL);

export const GET_PROPOSALS = gql`
  query GetProposals {
    proposals(orderBy: createdAtTimestamp, orderDirection: desc, first: 20) {
      id
      proposer
      description
      state
      forVotes
      againstVotes
      abstainVotes
      startBlock
      endBlock
    }
  }
`;

export const GET_LOAN_POSITION = gql`
  query GetLoanPosition($id: ID!) {
    loanPosition(id: $id) {
      id
      borrower
      collateralAmount
      debtAmount
      healthFactor
      lastUpdatedTimestamp
    }
  }
`;

export const GET_POOL = gql`
  query GetPool($id: ID!) {
    pool(id: $id) {
      id
      reserveA
      reserveB
      totalVolumeUSD
      totalLiquidityUSD
      txCount
    }
  }
`;
