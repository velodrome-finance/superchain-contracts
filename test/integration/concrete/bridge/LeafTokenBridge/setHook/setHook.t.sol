// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafTokenBridge.t.sol";

contract SetHookIntegrationConcreteTest is LeafTokenBridgeTest {
    MockCustomHook public hook;

    function setUp() public virtual override {
        super.setUp();

        hook = new MockCustomHook(users.owner, defaultCommands, defaultGasLimits);
    }

    function test_WhenTheCallerIsNotOwner() external {
        // It should revert with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        leafTokenBridge.setHook({_hook: address(hook)});
    }

    function test_WhenTheCallerIsOwner() external {
        // It should set new hook
        // It should emit {HookSet} event
        vm.prank(leafTokenBridge.owner());
        vm.expectEmit(address(leafTokenBridge));
        emit ITokenBridge.HookSet({_newHook: address(hook)});
        leafTokenBridge.setHook({_hook: address(hook)});

        assertEq(leafTokenBridge.hook(), address(hook));
    }
}
