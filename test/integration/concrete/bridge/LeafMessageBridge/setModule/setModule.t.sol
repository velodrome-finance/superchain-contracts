// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafMessageBridge.t.sol";

contract SetModuleIntegrationConcreteTest is LeafMessageBridgeTest {
    function test_WhenCallerIsNotOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootMessageBridge.setModule({_module: users.charlie});
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenModuleIsZeroAddress() external whenCallerIsOwner {
        // It reverts with {ZeroAddress}
        vm.expectRevert(ILeafMessageBridge.ZeroAddress.selector);
        rootMessageBridge.setModule({_module: address(0)});
    }

    function test_WhenModuleIsNotZeroAddress() external whenCallerIsOwner {
        // It sets new module
        // It emits {SetModule}
        address module = address(
            new LeafHLMessageModule({
                _bridge: address(rootMessageBridge),
                _mailbox: address(rootMailbox),
                _ism: address(rootIsm)
            })
        );

        vm.expectEmit(address(rootMessageBridge));
        emit ILeafMessageBridge.SetModule({_sender: users.owner, _module: module});
        rootMessageBridge.setModule({_module: module});

        assertEq(rootMessageBridge.module(), module);
    }
}
