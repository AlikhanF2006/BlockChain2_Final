import type { Address } from "viem";

export const arbitrumSepoliaChainId = 421614;

export const addresses = {
  ammPool: "0x61165963D67bEbd3e5C1BEad6d0C9D849f13A35B" as Address,
  lendingPool: "0x052BD2B635369c231E954A1F34A49d5182184877" as Address,
  yieldVault: "0xdbCdEcEF8c567b691e072200420f3f324971fd68" as Address,
  governor: "0xf223786104C878Bbf1D8a0b036DD07DB32Fa3DDf" as Address,
  govToken: "0xd86d5004815e58451100A2Ba9a9A35B8d11b94e2" as Address,
  tokenA: "0xE18EC14794334Bc8615DaC6a047a5a7C9ffF4153" as Address,
  tokenB: "0xD35f09887f22617A6F7967F0f2C399b4ad407Ddd" as Address,
  borrowToken: "0x0F09435E745E8F72f3f8A0e0bE51747Eee808307" as Address,
  collateralToken: "0xbc3D5377CA5bC004ef5D277f42148a3B049Fe0ee" as Address,
  lpToken: "0x77Df80E8d2408586Eec2F2496058FE43DDBC1B11" as Address
};

export const tokenOptions = [
  { label: "Token A", address: addresses.tokenA },
  { label: "Token B", address: addresses.tokenB }
];

export const erc20Abi = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" }
    ],
    outputs: [{ type: "bool" }]
  },
  {
    type: "function",
    name: "delegates",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "address" }]
  },
  {
    type: "function",
    name: "getVotes",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "getPastVotes",
    stateMutability: "view",
    inputs: [
      { name: "account", type: "address" },
      { name: "timepoint", type: "uint256" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "delegate",
    stateMutability: "nonpayable",
    inputs: [{ name: "delegatee", type: "address" }],
    outputs: []
  },
] as const;

export const ammAbi = [
  {
    type: "function",
    name: "tokenA",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "address" }]
  },
  {
    type: "function",
    name: "tokenB",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "address" }]
  },
  {
    type: "function",
    name: "getReserves",
    stateMutability: "view",
    inputs: [],
    outputs: [
      { type: "uint112" },
      { type: "uint112" },
      { type: "uint32" }
    ]
  },
  {
    type: "function",
    name: "getAmountOut",
    stateMutability: "pure",
    inputs: [
      { name: "amountIn", type: "uint256" },
      { name: "reserveIn", type: "uint256" },
      { name: "reserveOut", type: "uint256" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "swapExactTokensForTokens",
    stateMutability: "nonpayable",
    inputs: [
      { name: "amountIn", type: "uint256" },
      { name: "amountOutMin", type: "uint256" },
      { name: "tokenIn", type: "address" },
      { name: "to", type: "address" },
      { name: "deadline", type: "uint256" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "addLiquidity",
    stateMutability: "nonpayable",
    inputs: [
      { name: "amountADesired", type: "uint256" },
      { name: "amountBDesired", type: "uint256" },
      { name: "amountAMin", type: "uint256" },
      { name: "amountBMin", type: "uint256" },
      { name: "to", type: "address" },
      { name: "deadline", type: "uint256" }
    ],
    outputs: [
      { type: "uint256" },
      { type: "uint256" },
      { type: "uint256" }
    ]
  }
] as const;

export const lendingAbi = [
  {
    type: "function",
    name: "getHealthFactor",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "collateralBalance",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "borrows",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "borrow",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: []
  },
  {
    type: "function",
    name: "repay",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: []
  },
  {
    type: "function",
    name: "depositCollateral",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: []
  },
  {
    type: "function",
    name: "withdrawCollateral",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: []
  }
] as const;

export const vaultAbi = [
  {
    type: "function",
    name: "totalAssets",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "deposit",
    stateMutability: "nonpayable",
    inputs: [
      { name: "assets", type: "uint256" },
      { name: "receiver", type: "address" }
    ],
    outputs: [{ type: "uint256" }]
  },
  {
    type: "function",
    name: "withdraw",
    stateMutability: "nonpayable",
    inputs: [
      { name: "assets", type: "uint256" },
      { name: "receiver", type: "address" },
      { name: "owner", type: "address" }
    ],
    outputs: [{ type: "uint256" }]
  }
] as const;

export const governorAbi = [
  {
    type: "function",
    name: "castVoteWithReason",
    stateMutability: "nonpayable",
    inputs: [
      { name: "proposalId", type: "uint256" },
      { name: "support", type: "uint8" },
      { name: "reason", type: "string" }
    ],
    outputs: [{ type: "uint256" }]
  }
] as const;
