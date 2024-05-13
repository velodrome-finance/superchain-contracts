// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Converter.t.sol";

contract CompoundTest is ConverterTest {
    function test_WhenCallerIsNotGauge() external {
        // It should revert with NotAuthorized
        vm.expectRevert(IConverter.NotAuthorized.selector);
        feeConverter.compound();
    }

    modifier whenCallerIsGauge() {
        vm.startPrank(feeConverter.gauge());
        _;
    }

    function test_GivenConverterHasNoBalanceInTargetToken() external whenCallerIsGauge {
        // It should not transfer any tokens
        // It should not emit Event
        assertEq(rewardToken.balanceOf(address(feeConverter)), 0);
        uint256 oldGaugeBal = rewardToken.balanceOf(address(stakingRewards));
        uint256 oldConverterBal = rewardToken.balanceOf(address(feeConverter));
        assertEq(oldConverterBal, 0);

        feeConverter.compound();

        assertEq(rewardToken.balanceOf(address(stakingRewards)), oldGaugeBal);
        assertEq(rewardToken.balanceOf(address(feeConverter)), oldConverterBal);
    }

    function test_GivenConverterHasBalanceInTargetToken() external whenCallerIsGauge {
        // It should transfer all converted tokens to Gauge
        // It should emit a {Compound} event
        uint256 amount = TOKEN_1 * 1000;
        deal(address(rewardToken), address(feeConverter), amount);

        assertEq(rewardToken.balanceOf(address(feeConverter)), amount);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), 0);

        vm.expectEmit(address(feeConverter));
        emit IConverter.Compound({balanceCompounded: amount});
        feeConverter.compound();

        assertEq(rewardToken.balanceOf(address(feeConverter)), 0);
        assertEq(rewardToken.balanceOf(address(stakingRewards)), amount);
    }
}
