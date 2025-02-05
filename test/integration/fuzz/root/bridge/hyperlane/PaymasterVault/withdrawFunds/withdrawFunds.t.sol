// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../PaymasterVault.t.sol";

contract WithdrawFundsIntegrationFuzzTest is PaymasterVaultTest {
    uint256 public amount;

    function testFuzz_WhenCallerIsNotOwner(address _caller) external {
        // It should revert with {OwnableUnauthorizedAccount}
        vm.assume(_caller != rootModuleVault.owner());

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        rootModuleVault.withdrawFunds({_recipient: _caller, _amount: amount});
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(rootModuleVault.owner());
        _;
    }

    modifier whenRecipientIsNotAddressZero(address _recipient) {
        vm.assume(_recipient != address(0) && _recipient != address(rootModuleVault));
        vm.assume(_recipient.code.length == 0);
        /// @dev Avoid precompiled addresses
        assumeNotPrecompile(_recipient);
        _;
    }

    modifier whenAmountIsGreaterThanZero(uint256 _amount) {
        amount = bound(_amount, 1, MAX_TOKENS);
        _;
    }

    function testFuzz_WhenTransferIsNotSuccessful() external {}

    function testFuzz_WhenTransferIsSuccessful(address _recipient, uint256 _balance, uint256 _amount)
        external
        whenCallerIsOwner
        whenRecipientIsNotAddressZero(_recipient)
        whenAmountIsGreaterThanZero(_amount)
    {
        // It should transfer the amount to recipient
        // It should emit a {FundsWithdrawn} event
        _balance = bound(_balance, amount, MAX_TOKENS);

        // Seed vault with ETH
        vm.deal(address(rootModuleVault), _balance);

        uint256 oldBal = _recipient.balance;

        vm.expectEmit(address(rootModuleVault));
        emit IPaymasterVault.FundsWithdrawn({_recipient: _recipient, _amount: amount});
        rootModuleVault.withdrawFunds({_recipient: _recipient, _amount: amount});

        assertEq(address(rootModuleVault).balance, _balance - amount);
        assertEq(_recipient.balance, oldBal + amount);
    }
}
