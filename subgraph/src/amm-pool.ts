import { Address, BigDecimal, BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  LiquidityAdded,
  LiquidityRemoved,
  Swap as SwapEvent,
  Sync,
  AMMPool as AMMPoolContract
} from "../generated/AMMPool/AMMPool";
import { Pool, Swap } from "../generated/schema";

const ZERO_BI = BigInt.zero();
const ZERO_BD = BigDecimal.zero();

function eventId(txHash: Bytes, logIndex: BigInt): string {
  return txHash.toHexString().concat("-").concat(logIndex.toString());
}

function getPool(address: Address, timestamp: BigInt): Pool {
  let id = address.toHexString();
  let pool = Pool.load(id);
  if (pool == null) {
    pool = new Pool(id);
    let contract = AMMPoolContract.bind(address);
    let tokenATry = contract.try_tokenA();
    let tokenBTry = contract.try_tokenB();
    pool.tokenA = tokenATry.reverted ? Bytes.empty() : tokenATry.value;
    pool.tokenB = tokenBTry.reverted ? Bytes.empty() : tokenBTry.value;
    pool.reserveA = ZERO_BI;
    pool.reserveB = ZERO_BI;
    pool.totalVolumeUSD = ZERO_BD;
    pool.totalLiquidityUSD = ZERO_BD;
    pool.txCount = ZERO_BI;
    pool.createdAtTimestamp = timestamp;
  }
  return pool;
}

function refreshReserves(pool: Pool, address: Address): void {
  let contract = AMMPoolContract.bind(address);
  let reserves = contract.try_getReserves();
  if (!reserves.reverted) {
    pool.reserveA = reserves.value.value0;
    pool.reserveB = reserves.value.value1;
    pool.totalLiquidityUSD = pool.reserveA.plus(pool.reserveB).toBigDecimal();
  }
}

export function handleSwap(event: SwapEvent): void {
  let pool = getPool(event.address, event.block.timestamp);
  let swap = new Swap(eventId(event.transaction.hash, event.logIndex));
  swap.pool = pool.id;
  swap.sender = event.params.sender;
  swap.tokenIn = event.params.tokenIn;
  swap.amountIn = event.params.amountIn;
  swap.amountOut = event.params.amountOut;
  swap.timestamp = event.block.timestamp;
  swap.blockNumber = event.block.number;
  swap.save();

  refreshReserves(pool, event.address);
  pool.totalVolumeUSD = pool.totalVolumeUSD.plus(event.params.amountIn.toBigDecimal());
  pool.txCount = pool.txCount.plus(BigInt.fromI32(1));
  pool.save();
}

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let pool = getPool(event.address, event.block.timestamp);
  refreshReserves(pool, event.address);
  pool.txCount = pool.txCount.plus(BigInt.fromI32(1));
  pool.save();
}

export function handleLiquidityRemoved(event: LiquidityRemoved): void {
  let pool = getPool(event.address, event.block.timestamp);
  refreshReserves(pool, event.address);
  pool.txCount = pool.txCount.plus(BigInt.fromI32(1));
  pool.save();
}

export function handleSync(event: Sync): void {
  let pool = getPool(event.address, event.block.timestamp);
  pool.reserveA = event.params.reserveA;
  pool.reserveB = event.params.reserveB;
  pool.totalLiquidityUSD = pool.reserveA.plus(pool.reserveB).toBigDecimal();
  pool.save();
}
