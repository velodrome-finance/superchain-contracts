// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract SetHookIntegrationConcreteTest is TokenBridgeTest {
    MockCustomHook public hook;

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: rootId});
        hook = new MockCustomHook();
    }

    function test_WhenTheCallerIsNotOwner() external {
        // It should revert with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootTokenBridge.setHook({_hook: address(hook)});
    }

    function test_WhenTheCallerIsOwner() external {
        // It should set new hook
        // It should emit {HookSet} event
        vm.prank(rootTokenBridge.owner());
        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.HookSet({_newHook: address(hook)});
        rootTokenBridge.setHook({_hook: address(hook)});

        assertEq(rootTokenBridge.hook(), address(hook));
    }
}
