// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../FeesVotingReward.t.sol";

contract NotifyRewardAmountIntegrationConcreteTest is FeesVotingRewardTest {
    using stdStorage for StdStorage;

    address token;

    function test_WhenCallerIsNotTheGauge() external {
        // It should revert with NotGauge
        vm.prank(users.charlie);
        vm.expectRevert(IReward.NotGauge.selector);
        leafFVR.notifyRewardAmount(token, TOKEN_1);
    }

    modifier whenCallerIsTheGauge() {
        vm.startPrank(address(leafGauge));
        _;
    }

    function test_WhenTokenIsNotReward() external whenCallerIsTheGauge {
        // It should revert with InvalidReward
        vm.expectRevert(IReward.InvalidReward.selector);
        leafFVR.notifyRewardAmount(token, TOKEN_1);
    }

    modifier whenTokenIsReward() {
        token = address(new TestERC20("not reward", "NR", 18));
        stdstore.target(address(leafFVR)).sig("isReward(address)").with_key(address(token)).checked_write(true);
        _;
    }

    function test_WhenAmountIsZero() external whenCallerIsTheGauge whenTokenIsReward {
        // It should revert with ZeroAmount
        uint256 amount = 0;
        vm.expectRevert(IReward.ZeroAmount.selector);
        leafFVR.notifyRewardAmount(token, amount);
    }

    function test_WhenAmountIsNotZero() external whenCallerIsTheGauge whenTokenIsReward {
        uint256 amount = TOKEN_1;
        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        uint256 tokenRewardsPerEpoch = leafFVR.tokenRewardsPerEpoch(token, epochStart);

        deal(token, address(leafGauge), amount);
        uint256 senderBalance = IERC20(token).balanceOf(address(leafGauge));
        uint256 incentiveBalance = IERC20(token).balanceOf(address(leafFVR));
        IERC20(token).approve(address(leafFVR), amount);

        // It should emit {NotifyReward}
        vm.expectEmit(address(leafFVR));
        emit IReward.NotifyReward({_sender: address(leafGauge), _reward: token, _epoch: epochStart, _amount: amount});
        leafFVR.notifyRewardAmount(token, amount);

        // It should transfer amount from sender to fees contract
        assertEq(IERC20(token).balanceOf(address(leafGauge)), senderBalance - amount);
        assertEq(IERC20(token).balanceOf(address(leafFVR)), incentiveBalance + amount);

        // It should update tokenRewardsPerEpoch mapping
        assertEq(leafFVR.tokenRewardsPerEpoch(token, epochStart), tokenRewardsPerEpoch + amount);
    }
}
