import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";
import { newMockEvent } from "matchstick-as/assembly/index";
import { Sync } from "../generated/AMMPool/AMMPool";

export function createSyncEvent(pool: Address, reserveA: BigInt, reserveB: BigInt): Sync {
  let event = changetype<Sync>(newMockEvent());
  event.address = pool;
  event.parameters = new Array<ethereum.EventParam>();
  event.parameters.push(new ethereum.EventParam("reserveA", ethereum.Value.fromUnsignedBigInt(reserveA)));
  event.parameters.push(new ethereum.EventParam("reserveB", ethereum.Value.fromUnsignedBigInt(reserveB)));
  return event;
}
