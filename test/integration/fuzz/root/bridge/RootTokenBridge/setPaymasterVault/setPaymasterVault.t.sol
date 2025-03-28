// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootTokenBridge.t.sol";

contract SetPaymasterVaultIntegrationFuzzTest is RootTokenBridgeTest {
    function testFuzz_WhenTheCallerIsNotOwner(address _caller) external {
        // It should revert with {OwnableUnauthorizedAccount}
        vm.assume(_caller != rootTokenBridge.owner());

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootTokenBridge.setPaymasterVault({_paymasterVault: _caller});
    }

    modifier whenTheCallerIsOwner() {
        vm.startPrank(rootTokenBridge.owner());
        _;
    }

    function testFuzz_WhenTheVaultIsNotTheAddressZero(address _vault) external whenTheCallerIsOwner {
        // It should set the new paymaster vault
        // It should emit a {PaymasterVaultSet} event
        vm.assume(_vault != address(0));

        vm.expectEmit(address(rootTokenBridge));
        emit IPaymaster.PaymasterVaultSet({_newPaymaster: _vault});
        rootTokenBridge.setPaymasterVault({_paymasterVault: _vault});

        assertEq(rootTokenBridge.paymasterVault(), _vault);
    }
}
