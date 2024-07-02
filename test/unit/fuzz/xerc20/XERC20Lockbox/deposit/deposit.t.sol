// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Lockbox.t.sol";

contract DepositUnitConcreteTest is XERC20LockboxTest {
    function test_GivenAnyAmount(uint256 _amount) external {
        // It should transfer the amount of ERC20 tokens from the caller to the lockbox
        // It should mint the amount of XERC20 tokens to the caller
        // It should emit a {Deposit} event
        uint256 amount = bound(_amount, 1, MAX_TOKENS);
        deal(address(rewardToken), users.alice, amount);

        vm.startPrank(users.alice);
        rewardToken.approve(address(lockbox), amount);

        vm.expectEmit(address(lockbox));
        emit IXERC20Lockbox.Deposit({_sender: users.alice, _amount: amount});
        lockbox.deposit(amount);

        assertEq(rewardToken.balanceOf(users.alice), 0);
        assertEq(rewardToken.balanceOf(address(lockbox)), amount);
        assertEq(xVelo.balanceOf(users.alice), amount);
    }
}
