// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Lockbox.t.sol";

contract WithdrawUnitConcreteTest is XERC20LockboxTest {
    function test_GivenAnyAmount(uint256 _depositAmount, uint256 _withdrawAmount) external {
        // It should burn the amount of XERC20 tokens from the caller
        // It should transfer the amount of ERC20 tokens from the lockbox to the caller
        // It should emit a {Withdraw} event
        uint256 depositAmount = bound(_depositAmount, 1, MAX_TOKENS);
        uint256 withdrawAmount = bound(_withdrawAmount, 1, depositAmount);
        deal(address(rewardToken), users.alice, depositAmount);

        vm.startPrank(users.alice);
        rewardToken.approve(address(lockbox), depositAmount);

        lockbox.deposit(depositAmount);

        xVelo.approve(address(lockbox), withdrawAmount);

        vm.expectEmit(address(lockbox));
        emit IXERC20Lockbox.Withdraw({_sender: users.alice, _amount: withdrawAmount});
        lockbox.withdraw(withdrawAmount);

        uint256 amountRemaining = depositAmount - withdrawAmount;
        assertEq(rewardToken.balanceOf(users.alice), withdrawAmount);
        assertEq(rewardToken.balanceOf(address(lockbox)), amountRemaining);
        assertEq(xVelo.balanceOf(users.alice), amountRemaining);
    }
}
