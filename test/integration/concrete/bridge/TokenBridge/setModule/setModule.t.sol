// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract SetModuleIntegrationConcreteTest is TokenBridgeTest {
    function test_WhenCallerIsNotOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootTokenBridge.setModule(address(0));
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenModuleIsZeroAddress() external whenCallerIsOwner {
        // It reverts with {ZeroAddress}
        vm.expectRevert(abi.encodeWithSelector(IBridge.ZeroAddress.selector));
        rootTokenBridge.setModule({_module: address(0)});
    }

    function test_WhenModuleIsNotZeroAddress() external whenCallerIsOwner {
        // It sets new module
        // It emits {SetModule}
        address module =
            address(new HLUserTokenBridge(address(rootTokenBridge), address(rootMailbox), address(rootIsm)));

        vm.expectEmit(address(rootTokenBridge));
        emit IBridge.SetModule({_sender: users.owner, _module: module});
        rootTokenBridge.setModule({_module: module});

        assertEq(rootTokenBridge.module(), module);
    }
}
