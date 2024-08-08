// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Bridge.t.sol";

contract SetModuleIntegrationConcreteTest is BridgeTest {
    function test_WhenCallerIsNotOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootBridge.setModule(address(0));
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenModuleIsZeroAddress() external whenCallerIsOwner {
        // It reverts with {ZeroAddress}
        vm.expectRevert(abi.encodeWithSelector(IBridge.ZeroAddress.selector));
        rootBridge.setModule({_module: address(0)});
    }

    function test_WhenModuleIsNotZeroAddress() external whenCallerIsOwner {
        // It sets new module
        // It emits {SetModule}
        address module = address(new HLTokenBridge(address(rootBridge), address(rootMailbox), address(rootIsm)));

        vm.expectEmit(address(rootBridge));
        emit IBridge.SetModule({_sender: users.owner, _module: module});
        rootBridge.setModule({_module: module});

        assertEq(rootBridge.module(), module);
    }
}
