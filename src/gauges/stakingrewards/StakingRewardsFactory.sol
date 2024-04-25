// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IStakingRewardsFactory} from "../../interfaces/gauges/stakingrewards/IStakingRewardsFactory.sol";
import {StakingRewards} from "../../gauges/stakingrewards/StakingRewards.sol";

contract StakingRewardsFactory is IStakingRewardsFactory {
    /// @inheritdoc IStakingRewardsFactory
    address public notifyAdmin;

    constructor(address _notifyAdmin) {
        notifyAdmin = _notifyAdmin;
        emit SetNotifyAdmin({_notifyAdmin: _notifyAdmin});
    }

    /// @inheritdoc IStakingRewardsFactory
    function setNotifyAdmin(address _notifyAdmin) external {
        if (msg.sender != notifyAdmin) revert NotNotifyAdmin();
        if (_notifyAdmin == address(0)) revert ZeroAddress();
        notifyAdmin = _notifyAdmin;
        emit SetNotifyAdmin({_notifyAdmin: _notifyAdmin});
    }

    /// @inheritdoc IStakingRewardsFactory
    function createStakingRewards(address _pool, address _feesVotingReward, address _rewardToken, bool isPool)
        external
        returns (address stakingRewards)
    {
        stakingRewards = address(new StakingRewards(_pool, _feesVotingReward, _rewardToken, isPool));
    }
}
