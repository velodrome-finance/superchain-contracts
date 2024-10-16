// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract TokenBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootTokenBridge.owner(), users.owner);
        assertEq(rootTokenBridge.xerc20(), address(rootXVelo));
        assertEq(rootTokenBridge.mailbox(), address(rootMailbox));
        assertEq(address(rootTokenBridge.securityModule()), address(rootIsm));
        assertEq(address(rootTokenBridge).balance, 0);

        uint256[] memory chainids = rootTokenBridge.chainids();
        assertEq(chainids.length, 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafTokenBridge.owner(), users.owner);
        assertEq(leafTokenBridge.xerc20(), address(leafXVelo));
        assertEq(leafTokenBridge.mailbox(), address(leafMailbox));
        assertEq(address(leafTokenBridge.securityModule()), address(leafIsm));
        assertEq(address(leafTokenBridge).balance, 0);

        chainids = leafTokenBridge.chainids();
        assertEq(chainids.length, 0);
    }
}
