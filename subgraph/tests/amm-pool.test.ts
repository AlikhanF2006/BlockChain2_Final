import { assert, describe, test, clearStore, afterEach } from "matchstick-as/assembly/index";
import { Address, BigInt } from "@graphprotocol/graph-ts";
import { handleSync } from "../src/amm-pool";
import { createSyncEvent } from "./utils";

describe("AMMPool mappings", () => {
  afterEach(() => {
    clearStore();
  });

  test("handleSync creates pool and updates reserves", () => {
    let event = createSyncEvent(Address.fromString("0x0000000000000000000000000000000000000001"), BigInt.fromI32(100), BigInt.fromI32(200));
    handleSync(event);

    assert.fieldEquals("Pool", "0x0000000000000000000000000000000000000001", "reserveA", "100");
    assert.fieldEquals("Pool", "0x0000000000000000000000000000000000000001", "reserveB", "200");
  });
});
