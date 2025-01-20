// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract TokenBridgeTest is BaseForkFixture {
    function setUp() public virtual override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_InitialState() public {
        assertEq(leafTokenBridge.owner(), users.owner);
        assertEq(leafTokenBridge.xerc20(), address(leafXVelo));
        assertEq(leafTokenBridge.mailbox(), address(leafMailbox));
        assertEq(leafTokenBridge.hook(), address(0));
        assertEq(address(leafTokenBridge.securityModule()), address(0));
        assertEq(address(leafTokenBridge).balance, 0);

        uint256[] memory chainids = leafTokenBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
