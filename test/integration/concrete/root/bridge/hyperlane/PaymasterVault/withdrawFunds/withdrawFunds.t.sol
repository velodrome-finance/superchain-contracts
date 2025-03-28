// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PaymasterVault.t.sol";

contract WithdrawFundsIntegrationConcreteTest is PaymasterVaultTest {
    function test_WhenCallerIsNotOwner() external {
        // It should revert with {OwnableUnauthorizedAccount}
        uint256 amount = TOKEN_1;
        address recipient = users.alice;

        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootModuleVault.withdrawFunds({_recipient: recipient, _amount: amount});
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(rootModuleVault.owner());
        _;
    }

    function test_WhenRecipientIsAddressZero() external whenCallerIsOwner {
        // It should revert with {ZeroAddress}
        uint256 amount = TOKEN_1;
        address recipient = address(0);

        vm.expectRevert(IPaymasterVault.ZeroAddress.selector);
        rootModuleVault.withdrawFunds({_recipient: recipient, _amount: amount});
    }

    modifier whenRecipientIsNotAddressZero() {
        _;
    }

    modifier whenAmountIsGreaterThanZero() {
        _;
    }

    function test_WhenTransferIsNotSuccessful()
        external
        whenCallerIsOwner
        whenRecipientIsNotAddressZero
        whenAmountIsGreaterThanZero
    {
        // It should revert with {ETHTransferFailed}
        uint256 amount = TOKEN_1;
        /// @dev Setting a contract with no receive support as recipient
        address recipient = address(rootPoolFactory);

        // Seed vault with ETH
        vm.deal(address(rootModuleVault), amount);

        vm.expectRevert(IPaymasterVault.ETHTransferFailed.selector);
        rootModuleVault.withdrawFunds({_recipient: recipient, _amount: amount});
    }

    function test_WhenTransferIsSuccessful()
        external
        whenCallerIsOwner
        whenRecipientIsNotAddressZero
        whenAmountIsGreaterThanZero
    {
        // It should transfer the amount to recipient
        // It should emit a {FundsWithdrawn} event
        uint256 amount = TOKEN_1;
        address recipient = users.alice;

        // Seed vault with ETH
        vm.deal(address(rootModuleVault), amount);

        uint256 oldBal = recipient.balance;

        vm.expectEmit(address(rootModuleVault));
        emit IPaymasterVault.FundsWithdrawn({_recipient: recipient, _amount: amount});
        rootModuleVault.withdrawFunds({_recipient: recipient, _amount: amount});

        assertEq(address(rootModuleVault).balance, 0);
        assertEq(recipient.balance, oldBal + amount);
    }
}
