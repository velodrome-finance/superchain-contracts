// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract HLUserTokenBridgeTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootTokenModule.bridge(), address(rootTokenBridge));
        assertEq(rootTokenModule.mailbox(), address(rootMailbox));
        assertEq(address(rootTokenModule.securityModule()), address(rootIsm));
        assertEq(address(rootTokenModule).balance, 0);

        vm.selectFork({forkId: leafId});
        assertEq(leafTokenModule.bridge(), address(leafTokenBridge));
        assertEq(leafTokenModule.mailbox(), address(leafMailbox));
        assertEq(address(leafTokenModule.securityModule()), address(leafIsm));
        assertEq(address(leafTokenModule).balance, 0);
    }
}
