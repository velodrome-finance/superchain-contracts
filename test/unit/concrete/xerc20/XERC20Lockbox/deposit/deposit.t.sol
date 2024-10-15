// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20Lockbox.t.sol";

contract DepositUnitConcreteTest is XERC20LockboxTest {
    function test_GivenAnyAmount() external {
        // It should transfer the amount of ERC20 tokens from the caller to the lockbox
        // It should mint the amount of XERC20 tokens to the caller
        // It should emit a {Deposit} event
        uint256 amount = TOKEN_1 * 100_000;
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

    function testGas_deposit() external {
        uint256 amount = TOKEN_1 * 100_000;
        deal(address(rewardToken), users.alice, amount);

        vm.startPrank(users.alice);
        rewardToken.approve(address(lockbox), amount);

        lockbox.deposit(amount);
        snapLastCall("XERC20Lockbox_deposit");
    }
}
