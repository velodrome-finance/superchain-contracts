// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract HLTokenBridgeTest is BaseForkFixture {
    function test_InitialState() internal {
        vm.selectFork({forkId: rootId});
        assertEq(rootModule.bridge(), address(rootBridge));
        assertEq(rootModule.mailbox(), address(rootMailbox));
        assertEq(address(rootModule.securityModule()), address(rootIsm));

        vm.selectFork({forkId: leafId});
        assertEq(leafModule.bridge(), address(leafBridge));
        assertEq(leafModule.mailbox(), address(leafMailbox));
        assertEq(address(leafModule.securityModule()), address(leafIsm));
    }
}
