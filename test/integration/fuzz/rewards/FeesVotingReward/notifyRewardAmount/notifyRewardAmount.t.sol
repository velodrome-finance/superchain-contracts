// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../FeesVotingReward.t.sol";

contract NotifyRewardAmountIntegrationFuzzTest is FeesVotingRewardTest {
    using stdStorage for StdStorage;

    address token;

    function test_WhenCallerIsNotTheGauge(address _caller) external {
        // It should revert with NotGauge
        vm.assume(_caller != address(leafGauge));
        vm.prank(_caller);
        vm.expectRevert(IReward.NotGauge.selector);
        leafFVR.notifyRewardAmount(token, TOKEN_1);
    }

    modifier whenCallerIsTheGauge() {
        vm.startPrank(address(leafGauge));
        _;
    }

    modifier whenTokenIsReward() {
        token = address(new TestERC20("not reward", "NR", 18));
        stdstore.target(address(leafFVR)).sig("isReward(address)").with_key(address(token)).checked_write(true);
        _;
    }

    function test_WhenAmountIsNotZero(uint256 _amount) external whenCallerIsTheGauge whenTokenIsReward {
        _amount = bound(_amount, 1, type(uint256).max);
        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        uint256 tokenRewardsPerEpoch = leafFVR.tokenRewardsPerEpoch(token, epochStart);

        deal(token, address(leafGauge), _amount);
        uint256 senderBalance = IERC20(token).balanceOf(address(leafGauge));
        uint256 bribeBalance = IERC20(token).balanceOf(address(leafFVR));
        IERC20(token).approve(address(leafFVR), _amount);

        // It should emit {NotifyReward}
        vm.expectEmit(address(leafFVR));
        emit IReward.NotifyReward({_sender: address(leafGauge), _reward: token, _epoch: epochStart, _amount: _amount});
        leafFVR.notifyRewardAmount(token, _amount);

        // It should transfer amount from sender to fees contract
        assertEq(IERC20(token).balanceOf(address(leafGauge)), senderBalance - _amount);
        assertEq(IERC20(token).balanceOf(address(leafFVR)), bribeBalance + _amount);

        // It should update tokenRewardsPerEpoch mapping
        assertEq(leafFVR.tokenRewardsPerEpoch(token, epochStart), tokenRewardsPerEpoch + _amount);
    }
}
