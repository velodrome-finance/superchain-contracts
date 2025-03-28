// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SetPaymasterVaultIntegrationConcreteTest is RootHLMessageModuleTest {
    function test_WhenTheCallerIsNotBridgeOwner() external {
        // It should revert with {NotBridgeOwner}
        vm.prank(users.charlie);
        vm.expectRevert(IRootHLMessageModule.NotBridgeOwner.selector);
        rootMessageModule.setPaymasterVault({_paymasterVault: users.charlie});
    }

    modifier whenTheCallerIsBridgeOwner() {
        vm.startPrank(rootMessageBridge.owner());
        _;
    }

    function test_WhenTheVaultIsTheAddressZero() external whenTheCallerIsBridgeOwner {
        // It should revert with {InvalidAddress}
        vm.expectRevert(IPaymaster.InvalidAddress.selector);
        rootMessageModule.setPaymasterVault({_paymasterVault: address(0)});
    }

    function test_WhenTheVaultIsNotTheAddressZero() external whenTheCallerIsBridgeOwner {
        // It should set the new paymaster vault
        // It should emit a {PaymasterVaultSet} event
        PaymasterVault vault = new PaymasterVault({_owner: users.owner, _vaultManager: address(rootMessageModule)});

        vm.expectEmit(address(rootMessageModule));
        emit IPaymaster.PaymasterVaultSet({_newPaymaster: address(vault)});
        rootMessageModule.setPaymasterVault({_paymasterVault: address(vault)});

        assertEq(rootMessageModule.paymasterVault(), address(vault));
    }
}
