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

        assertEq(rootMessageModule.gasLimit({_command: Commands.DEPOSIT}), 281_000);
        assertEq(rootMessageModule.gasLimit({_command: Commands.WITHDRAW}), 75_000);
        assertEq(rootMessageModule.gasLimit({_command: Commands.GET_INCENTIVES}), 650_000);
        assertEq(rootMessageModule.gasLimit({_command: Commands.GET_FEES}), 300_000);
        assertEq(rootMessageModule.gasLimit({_command: Commands.CREATE_GAUGE}), 6_710_000);
        assertEq(rootMessageModule.gasLimit({_command: Commands.NOTIFY}), 280_000);
        assertEq(rootMessageModule.gasLimit({_command: Commands.NOTIFY_WITHOUT_CLAIM}), 233_000);
        assertEq(rootMessageModule.gasLimit({_command: Commands.KILL_GAUGE}), 83_000);
        assertEq(rootMessageModule.gasLimit({_command: Commands.REVIVE_GAUGE}), 169_000);
    }
}
