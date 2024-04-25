// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IStakingRewardsFactory} from "../../interfaces/gauges/stakingrewards/IStakingRewardsFactory.sol";
import {StakingRewards} from "../../gauges/stakingrewards/StakingRewards.sol";

contract StakingRewardsFactory is IStakingRewardsFactory {
    function createStakingRewards(address _pool, address _feesVotingReward, address _rewardToken, bool isPool)
        external
        returns (address stakingRewards)
    {
        stakingRewards = address(new StakingRewards(_pool, _feesVotingReward, _rewardToken, msg.sender, isPool));
    }
}
