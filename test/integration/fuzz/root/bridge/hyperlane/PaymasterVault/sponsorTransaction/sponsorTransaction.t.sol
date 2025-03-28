// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PaymasterVault.t.sol";

contract SponsorTransactionIntegrationFuzzTest is PaymasterVaultTest {
    function testFuzz_WhenCallerIsNotVaultManager(address _caller) external {
        // It should revert with {NotVaultManager}
        vm.assume(_caller != address(rootMessageModule));
        uint256 amount = TOKEN_1;

        vm.prank(_caller);
        vm.expectRevert(IPaymasterVault.NotVaultManager.selector);
        rootModuleVault.sponsorTransaction({_value: amount});
    }

    modifier whenCallerIsVaultManager() {
        vm.startPrank(address(rootMessageModule));
        _;
    }

    function testFuzz_WhenTransferIsNotSuccessful(uint256 _ethBalance, uint256 _amount)
        external
        whenCallerIsVaultManager
    {
        // It should revert with {ETHTransferFailed}
        _amount = bound(_amount, 1, MAX_TOKENS);
        _ethBalance = bound(_ethBalance, 0, _amount - 1);

        vm.deal(address(rootModuleVault), _ethBalance);

        vm.expectRevert(IPaymasterVault.ETHTransferFailed.selector);
        rootModuleVault.sponsorTransaction({_value: _amount});
    }

    function testFuzz_WhenTransferIsSuccessful(uint256 _ethBalance, uint256 _amount)
        external
        whenCallerIsVaultManager
    {
        // It should transfer the ETH amount to vault manager
        _ethBalance = bound(_ethBalance, 1, MAX_TOKENS);
        _amount = bound(_amount, 1, _ethBalance);

        vm.deal(address(rootModuleVault), _ethBalance);
        assertEq(address(rootMessageModule).balance, 0);

        rootModuleVault.sponsorTransaction({_value: _amount});

        assertEq(address(rootMessageModule).balance, _amount);
    }
}
