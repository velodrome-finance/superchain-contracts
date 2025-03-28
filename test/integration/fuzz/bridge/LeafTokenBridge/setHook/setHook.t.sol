// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafTokenBridge.t.sol";

contract SetHookIntegrationFuzzTest is LeafTokenBridgeTest {
    MockCustomHook public hook;

    function testFuzz_WhenTheCallerIsNotOwner(address _caller) external {
        // It should revert with {OwnableUnauthorizedAccount}
        vm.assume(_caller != rootTokenBridge.owner());

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        leafTokenBridge.setHook({_hook: _caller});
    }

    function testFuzz_WhenTheCallerIsOwner(address _hook) external {
        // It should set new hook
        // It should emit {HookSet} event
        vm.prank(leafTokenBridge.owner());
        vm.expectEmit(address(leafTokenBridge));
        emit ITokenBridge.HookSet({_newHook: _hook});
        leafTokenBridge.setHook({_hook: _hook});

        assertEq(leafTokenBridge.hook(), _hook);
    }
}
