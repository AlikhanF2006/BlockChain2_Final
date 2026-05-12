import { BigDecimal, BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Borrow,
  CollateralDeposited,
  CollateralWithdrawn,
  Deposit,
  Liquidation,
  Repay,
  Withdraw
} from "../generated/LendingPool/LendingPool";
import { BorrowEvent, LoanPosition } from "../generated/schema";

const ZERO_BI = BigInt.zero();
const ZERO_BD = BigDecimal.zero();

function eventId(txHash: Bytes, logIndex: BigInt): string {
  return txHash.toHexString().concat("-").concat(logIndex.toString());
}

function getPosition(user: Bytes, timestamp: BigInt): LoanPosition {
  let id = user.toHexString();
  let position = LoanPosition.load(id);
  if (position == null) {
    position = new LoanPosition(id);
    position.borrower = user;
    position.collateralAmount = ZERO_BI;
    position.debtAmount = ZERO_BI;
    position.healthFactor = ZERO_BD;
  }
  position.lastUpdatedTimestamp = timestamp;
  return position;
}

function refreshHealth(position: LoanPosition): void {
  if (position.debtAmount.equals(ZERO_BI)) {
    position.healthFactor = BigDecimal.fromString("999999");
  } else {
    position.healthFactor = position.collateralAmount.toBigDecimal().div(position.debtAmount.toBigDecimal());
  }
}

export function handleDeposit(event: Deposit): void {
  event;
}

export function handleWithdraw(event: Withdraw): void {
  event;
}

export function handleCollateralDeposited(event: CollateralDeposited): void {
  let position = getPosition(event.params.user, event.block.timestamp);
  position.collateralAmount = position.collateralAmount.plus(event.params.amount);
  refreshHealth(position);
  position.save();
}

export function handleCollateralWithdrawn(event: CollateralWithdrawn): void {
  let position = getPosition(event.params.user, event.block.timestamp);
  position.collateralAmount = position.collateralAmount.minus(event.params.amount);
  refreshHealth(position);
  position.save();
}

export function handleBorrow(event: Borrow): void {
  let position = getPosition(event.params.user, event.block.timestamp);
  position.debtAmount = position.debtAmount.plus(event.params.amount);
  refreshHealth(position);
  position.save();

  let borrowEvent = new BorrowEvent(eventId(event.transaction.hash, event.logIndex));
  borrowEvent.position = position.id;
  borrowEvent.amount = event.params.amount;
  borrowEvent.timestamp = event.block.timestamp;
  borrowEvent.save();
}

export function handleRepay(event: Repay): void {
  let position = getPosition(event.params.user, event.block.timestamp);
  position.debtAmount = event.params.amount.ge(position.debtAmount) ? ZERO_BI : position.debtAmount.minus(event.params.amount);
  refreshHealth(position);
  position.save();
}

export function handleLiquidation(event: Liquidation): void {
  let position = getPosition(event.params.borrower, event.block.timestamp);
  position.debtAmount = event.params.repaid.ge(position.debtAmount) ? ZERO_BI : position.debtAmount.minus(event.params.repaid);
  position.collateralAmount = event.params.seized.ge(position.collateralAmount)
    ? ZERO_BI
    : position.collateralAmount.minus(event.params.seized);
  refreshHealth(position);
  position.save();
}
