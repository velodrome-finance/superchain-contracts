// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract SetInterchainSecurityModuleIntegrationConcreteTest is TokenBridgeTest {
    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotTheOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        leafTokenBridge.setInterchainSecurityModule({_ism: address(0)});
    }

    function test_WhenTheCallerIsTheOwner() external {
        // It sets the new InterchainSecurityModule
        // It emits the {InterchainSecurityModuleSet} event
        vm.startPrank(users.owner);

        vm.expectEmit(address(leafTokenBridge));
        emit ISpecifiesInterchainSecurityModule.InterchainSecurityModuleSet({_new: address(1)});
        leafTokenBridge.setInterchainSecurityModule({_ism: address(1)});

        assertEq(address(leafTokenBridge.securityModule()), address(1));
    }

    function testGas_setInterchainSecurityModule() external {
        vm.prank(users.owner);
        leafTokenBridge.setInterchainSecurityModule({_ism: address(1)});
        snapLastCall("TokenBridge_setInterchainSecurityModule");
    }
}
