// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PaymasterVault.t.sol";

contract SponsorTransactionIntegrationConcreteTest is PaymasterVaultTest {
    function test_WhenCallerIsNotVaultManager() external {
        // It should revert with {NotVaultManager}
        uint256 amount = TOKEN_1;

        vm.prank(users.charlie);
        vm.expectRevert(IPaymasterVault.NotVaultManager.selector);
        rootModuleVault.sponsorTransaction({_value: amount});
    }

    modifier whenCallerIsVaultManager() {
        vm.startPrank(address(rootMessageModule));
        _;
    }

    function test_WhenTransferIsNotSuccessful() external whenCallerIsVaultManager {
        // It should revert with {ETHTransferFailed}
        uint256 amount = address(rootModuleVault).balance + 1;

        vm.expectRevert(IPaymasterVault.ETHTransferFailed.selector);
        rootModuleVault.sponsorTransaction({_value: amount});
    }

    function test_WhenTransferIsSuccessful() external whenCallerIsVaultManager {
        // It should transfer the ETH amount to vault manager
        uint256 amount = TOKEN_1;

        vm.deal(address(rootModuleVault), amount);
        assertEq(address(rootMessageModule).balance, 0);

        rootModuleVault.sponsorTransaction({_value: amount});

        assertEq(address(rootMessageModule).balance, amount);
    }
}
