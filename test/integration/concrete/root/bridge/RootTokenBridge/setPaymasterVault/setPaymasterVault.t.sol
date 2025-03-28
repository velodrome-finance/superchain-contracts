// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootTokenBridge.t.sol";

contract SetPaymasterVaultIntegrationConcreteTest is RootTokenBridgeTest {
    function test_WhenTheCallerIsNotOwner() external {
        // It should revert with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootTokenBridge.setPaymasterVault({_paymasterVault: users.charlie});
    }

    modifier whenTheCallerIsOwner() {
        vm.startPrank(rootTokenBridge.owner());
        _;
    }

    function test_WhenTheVaultIsTheAddressZero() external whenTheCallerIsOwner {
        // It should revert with {InvalidAddress}
        vm.expectRevert(IPaymaster.InvalidAddress.selector);
        rootTokenBridge.setPaymasterVault({_paymasterVault: address(0)});
    }

    function test_WhenTheVaultIsNotTheAddressZero() external whenTheCallerIsOwner {
        // It should set the new paymaster vault
        // It should emit a {PaymasterVaultSet} event
        PaymasterVault vault = new PaymasterVault({_owner: users.owner, _vaultManager: address(rootTokenBridge)});

        vm.expectEmit(address(rootTokenBridge));
        emit IPaymaster.PaymasterVaultSet({_newPaymaster: address(vault)});
        rootTokenBridge.setPaymasterVault({_paymasterVault: address(vault)});

        assertEq(rootTokenBridge.paymasterVault(), address(vault));
    }
}
