// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract SetPaymasterVaultIntegrationFuzzTest is RootHLMessageModuleTest {
    function testFuzz_WhenTheCallerIsNotBridgeOwner(address _caller) external {
        // It should revert with {NotBridgeOwner}
        vm.assume(_caller != rootMessageBridge.owner());

        vm.prank(_caller);
        vm.expectRevert(IRootHLMessageModule.NotBridgeOwner.selector);
        rootMessageModule.setPaymasterVault({_paymasterVault: _caller});
    }

    modifier whenTheCallerIsBridgeOwner() {
        vm.startPrank(rootMessageBridge.owner());
        _;
    }

    function testFuzz_WhenTheVaultIsNotTheAddressZero(address _vault) external whenTheCallerIsBridgeOwner {
        // It should set the new paymaster vault
        // It should emit a {PaymasterVaultSet} event
        vm.assume(_vault != address(0));

        vm.expectEmit(address(rootMessageModule));
        emit IPaymaster.PaymasterVaultSet({_newPaymaster: _vault});
        rootMessageModule.setPaymasterVault({_paymasterVault: _vault});

        assertEq(rootMessageModule.paymasterVault(), _vault);
    }
}
