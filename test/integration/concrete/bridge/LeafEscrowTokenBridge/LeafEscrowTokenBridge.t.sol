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

    function test_InitialState() public view {
        assertEq(leafEscrowTokenBridge.owner(), users.owner);
        assertEq(leafEscrowTokenBridge.xerc20(), address(leafXVelo));
        assertEq(leafEscrowTokenBridge.mailbox(), address(leafMailbox));
        assertEq(leafEscrowTokenBridge.hook(), address(0));
        assertEq(address(leafEscrowTokenBridge.securityModule()), address(0));
        assertEq(leafEscrowTokenBridge.ROOT_CHAINID(), 10);
        assertEq(address(leafTokenBridge).balance, 0);

        uint256[] memory chainids = leafEscrowTokenBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
