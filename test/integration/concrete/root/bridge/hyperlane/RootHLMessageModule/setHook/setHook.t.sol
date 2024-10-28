// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SetHookIntegrationConcreteTest is RootHLMessageModuleTest {
    MockCustomHook public hook;

    function setUp() public virtual override {
        super.setUp();

        hook = new MockCustomHook();
    }

    function test_WhenTheCallerIsNotBridgeOwner() external {
        // It should revert with {NotBridgeOwner}
        vm.prank(users.charlie);
        vm.expectRevert(IRootHLMessageModule.NotBridgeOwner.selector);
        rootMessageModule.setHook({_hook: address(hook)});
    }

    function test_WhenTheCallerIsBridgeOwner() external {
        // It should set new hook
        // It should emit {HookSet} event
        vm.prank(rootMessageBridge.owner());
        vm.expectEmit(address(rootMessageModule));
        emit IRootHLMessageModule.HookSet({_newHook: address(hook)});
        rootMessageModule.setHook({_hook: address(hook)});

        assertEq(rootMessageModule.hook(), address(hook));
    }
}
