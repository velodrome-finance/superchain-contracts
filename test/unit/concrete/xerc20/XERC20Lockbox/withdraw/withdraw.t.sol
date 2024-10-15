// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Lockbox.t.sol";

contract WithdrawUnitConcreteTest is XERC20LockboxTest {
    function test_GivenAnyAmount() external {
        // It should burn the amount of XERC20 tokens from the caller
        // It should transfer the amount of ERC20 tokens from the lockbox to the caller
        // It should emit a {Withdraw} event
        uint256 amount = TOKEN_1 * 100_000;
        deal(address(rewardToken), users.alice, amount);

        vm.startPrank(users.alice);
        rewardToken.approve(address(lockbox), amount);

        lockbox.deposit(amount);

        xVelo.approve(address(lockbox), amount);

        vm.expectEmit(address(lockbox));
        emit IXERC20Lockbox.Withdraw({_sender: users.alice, _amount: amount});
        lockbox.withdraw(amount);

        assertEq(rewardToken.balanceOf(users.alice), amount);
        assertEq(rewardToken.balanceOf(address(lockbox)), 0);
        assertEq(xVelo.balanceOf(users.alice), 0);
    }

    function testGas_withdraw() external {
        uint256 amount = TOKEN_1 * 100_000;
        deal(address(rewardToken), users.alice, amount);

        vm.startPrank(users.alice);
        rewardToken.approve(address(lockbox), amount);

        lockbox.deposit(amount);

        xVelo.approve(address(lockbox), amount);
        lockbox.withdraw(amount);
        snapLastCall("XERC20Lockbox_withdraw");
    }
}
