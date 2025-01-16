// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafMessageBridge.t.sol";

contract SetModuleIntegrationConcreteTest is LeafMessageBridgeTest {
    function test_WhenCallerIsNotOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        leafMessageBridge.setModule({_module: users.charlie});
    }

    modifier whenCallerIsOwner() {
        _;
    }

    function test_WhenModuleIsZeroAddress() external whenCallerIsOwner {
        // It reverts with {ZeroAddress}
        vm.prank(users.owner);
        vm.expectRevert(ILeafMessageBridge.ZeroAddress.selector);
        leafMessageBridge.setModule({_module: address(0)});
    }

    function test_WhenModuleIsNotZeroAddress() external whenCallerIsOwner {
        // It sets new module
        // It emits {ModuleSet}
        address module = address(
            new LeafHLMessageModule({
                _owner: users.owner,
                _bridge: address(leafMessageBridge),
                _mailbox: address(rootMailbox),
                _ism: address(rootIsm)
            })
        );

        vm.prank(users.owner);
        vm.expectEmit(address(leafMessageBridge));
        emit ILeafMessageBridge.ModuleSet({_sender: users.owner, _module: module});
        leafMessageBridge.setModule({_module: module});

        assertEq(leafMessageBridge.module(), module);
    }

    function testGas_setModule() external whenCallerIsOwner {
        address module = address(
            new LeafHLMessageModule({
                _owner: users.owner,
                _bridge: address(leafMessageBridge),
                _mailbox: address(rootMailbox),
                _ism: address(rootIsm)
            })
        );

        vm.prank(users.owner);
        leafMessageBridge.setModule({_module: module});
        vm.snapshotGasLastCall("LeafMessageBridge_setModule");
    }
}
