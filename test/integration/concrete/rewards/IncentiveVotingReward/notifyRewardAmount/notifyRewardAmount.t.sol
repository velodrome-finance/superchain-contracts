// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../IncentiveVotingReward.t.sol";

contract NotifyRewardAmountIntegrationConcreteTest is IncentiveVotingRewardTest {
    using stdStorage for StdStorage;

    address token;

    modifier whenTokenIsNotReward() {
        assertFalse(leafIVR.isReward(token));
        _;
    }

    function test_WhenTokenIsNotWhitelisted() external whenTokenIsNotReward {
        // It should revert with NotWhitelisted
        uint256 amount = TOKEN_1;
        vm.expectRevert(IReward.NotWhitelisted.selector);
        leafIVR.notifyRewardAmount(token, amount);
    }

    modifier whenTokenIsWhitelisted() {
        token = address(new TestERC20("not reward", "NR", 18));
        vm.mockCall(
            address(leafVoter),
            abi.encodeWithSelector(IVoter.isWhitelistedToken.selector, address(token)),
            abi.encode(true)
        );
        _;
    }

    function test_WhenAmountIsZero() external whenTokenIsNotReward whenTokenIsWhitelisted {
        // It should revert with ZeroAmount
        uint256 amount = 0;
        vm.expectRevert(IReward.ZeroAmount.selector);
        leafIVR.notifyRewardAmount(token, amount);
    }

    function test_WhenAmountIsNotZero() external whenTokenIsNotReward whenTokenIsWhitelisted {
        uint256 amount = TOKEN_1;
        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        uint256 tokenRewardsPerEpoch = leafIVR.tokenRewardsPerEpoch(token, epochStart);

        assertFalse(leafIVR.isReward(token));
        uint256 rewardsLength = leafIVR.rewardsListLength();

        deal(token, address(this), amount);
        uint256 senderBalance = IERC20(token).balanceOf(address(this));
        uint256 incentiveBalance = IERC20(token).balanceOf(address(leafIVR));
        IERC20(token).approve(address(leafIVR), amount);

        // It should emit {NotifyReward}
        vm.expectEmit(address(leafIVR));
        emit IReward.NotifyReward({_sender: address(this), _reward: token, _epoch: epochStart, _amount: amount});
        leafIVR.notifyRewardAmount(token, amount);

        // It should update rewards mapping to true
        assertTrue(leafIVR.isReward(token));
        // It should add token to the list of rewards
        assertEq(leafIVR.rewardsListLength(), rewardsLength + 1);
        assertEq(leafIVR.rewards(rewardsLength), token);

        // It should transfer amount from sender to incentive contract
        assertEq(IERC20(token).balanceOf(address(this)), senderBalance - amount);
        assertEq(IERC20(token).balanceOf(address(leafIVR)), incentiveBalance + amount);

        // It should update tokenRewardsPerEpoch mapping
        assertEq(leafIVR.tokenRewardsPerEpoch(token, epochStart), tokenRewardsPerEpoch + amount);
    }

    function test_WhenTokenIsReward() external {
        token = address(new TestERC20("not reward", "NR", 18));
        stdstore.target(address(leafIVR)).sig("isReward(address)").with_key(address(token)).checked_write(true);

        uint256 amount = TOKEN_1;
        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        uint256 tokenRewardsPerEpoch = leafIVR.tokenRewardsPerEpoch(token, epochStart);

        deal(token, address(this), amount);
        uint256 senderBalance = IERC20(token).balanceOf(address(this));
        uint256 incentiveBalance = IERC20(token).balanceOf(address(leafIVR));
        IERC20(token).approve(address(leafIVR), amount);

        // It should emit {NotifyReward}
        vm.expectEmit(address(leafIVR));
        emit IReward.NotifyReward({_sender: address(this), _reward: token, _epoch: epochStart, _amount: amount});
        leafIVR.notifyRewardAmount(token, amount);

        // It should transfer amount from sender to incentive contract
        assertEq(IERC20(token).balanceOf(address(this)), senderBalance - amount);
        assertEq(IERC20(token).balanceOf(address(leafIVR)), incentiveBalance + amount);

        // It should update tokenRewardsPerEpoch mapping
        assertEq(leafIVR.tokenRewardsPerEpoch(token, epochStart), tokenRewardsPerEpoch + amount);
    }
}
