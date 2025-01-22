// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootTokenBridge.t.sol";

contract SetModuleIntegrationConcreteTest is RootTokenBridgeTest {
    function test_WhenCallerIsNotOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootTokenBridge.setModule({_module: users.charlie});
    }

    modifier whenCallerIsOwner() {
        _;
    }

    function test_WhenModuleIsZeroAddress() external whenCallerIsOwner {
        // It reverts with {ZeroAddress}
        vm.prank(users.owner);
        vm.expectRevert(ITokenBridge.ZeroAddress.selector);
        rootTokenBridge.setModule({_module: address(0)});
    }

    function test_WhenModuleIsNotZeroAddress() external whenCallerIsOwner {
        // It sets new module
        // It emits {ModuleSet}
        address module =
            address(new RootHLMessageModule({_bridge: address(rootMessageBridge), _mailbox: address(rootMailbox)}));

        vm.prank(users.owner);
        vm.expectEmit(address(rootTokenBridge));
        emit IRootTokenBridge.ModuleSet({_sender: users.owner, _module: module});
        rootTokenBridge.setModule({_module: module});

        assertEq(rootTokenBridge.module(), module);
    }

    function testGas_setModule() external whenCallerIsOwner {
        address module =
            address(new RootHLMessageModule({_bridge: address(rootMessageBridge), _mailbox: address(rootMailbox)}));

        vm.prank(users.owner);
        rootTokenBridge.setModule({_module: module});
        vm.snapshotGasLastCall("RootTokenBridge_setModule");
    }
}
