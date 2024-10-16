// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafMessageBridge.t.sol";

contract SetModuleIntegrationFuzzTest is LeafMessageBridgeTest {
    function testFuzz_WhenCallerIsNotOwner(address _caller) external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.assume(_caller != users.owner);

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        leafMessageBridge.setModule({_module: _caller});
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function testFuzz_WhenModuleIsNotZeroAddress(address _module) external whenCallerIsOwner {
        // It sets new module
        // It emits {ModuleSet}
        vm.assume(_module != address(0));

        vm.expectEmit(address(leafMessageBridge));
        emit ILeafMessageBridge.ModuleSet({_sender: users.owner, _module: _module});
        leafMessageBridge.setModule({_module: _module});

        assertEq(leafMessageBridge.module(), _module);
    }
}
