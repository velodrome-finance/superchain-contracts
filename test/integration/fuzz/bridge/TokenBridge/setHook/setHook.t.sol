// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract SetHookIntegrationFuzzTest is TokenBridgeTest {
    MockCustomHook public hook;

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork({forkId: rootId});
    }

    function testFuzz_WhenTheCallerIsNotOwner(address _caller) external {
        // It should revert with {OwnableUnauthorizedAccount}
        vm.assume(_caller != rootTokenBridge.owner());

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootTokenBridge.setHook({_hook: _caller});
    }

    function testFuzz_WhenTheCallerIsOwner(address _hook) external {
        // It should set new hook
        // It should emit {HookSet} event
        vm.prank(rootTokenBridge.owner());
        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.HookSet({_newHook: _hook});
        rootTokenBridge.setHook({_hook: _hook});

        assertEq(rootTokenBridge.hook(), _hook);
    }
}
