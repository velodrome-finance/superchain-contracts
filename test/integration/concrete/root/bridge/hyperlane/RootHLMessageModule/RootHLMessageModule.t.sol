// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootHLMessageModuleTest is BaseForkFixture {
    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageModule.bridge(), address(rootMessageBridge));
        assertEq(rootMessageModule.xerc20(), address(rootXVelo));
        assertEq(rootMessageModule.mailbox(), address(rootMailbox));
        assertEq(rootMessageModule.voter(), address(mockVoter));
        assertEq(rootMessageModule.hook(), address(0));
        assertEq(rootMessageModule.domains(leaf), leafDomain);
        assertEq(rootMessageModule.chains(leafDomain), leaf);
    }
}
