// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SetHookIntegrationFuzzTest is RootHLMessageModuleTest {
    function testFuzz_WhenTheCallerIsNotBridgeOwner(address _caller) external {
        // It should revert with {NotBridgeOwner}
        vm.assume(_caller != rootMessageBridge.owner());

        vm.prank(_caller);
        vm.expectRevert(IRootHLMessageModule.NotBridgeOwner.selector);
        rootMessageModule.setHook({_hook: _caller});
    }

    function testFuzz_WhenTheCallerIsBridgeOwner(address _hook) external {
        // It should set new hook
        // It should emit {HookSet} event
        vm.prank(rootMessageBridge.owner());
        vm.expectEmit(address(rootMessageModule));
        emit IRootHLMessageModule.HookSet({_newHook: _hook});
        rootMessageModule.setHook({_hook: _hook});

        assertEq(rootMessageModule.hook(), _hook);
    }
}
