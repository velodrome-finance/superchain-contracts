// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract LeafEscrowTokenBridgeTest is BaseForkFixture {
    LeafEscrowTokenBridge leafEscrowTokenBridge;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork({forkId: leafId});
        leafEscrowTokenBridge = LeafEscrowTokenBridge(address(leafTokenBridge));
    }
}
