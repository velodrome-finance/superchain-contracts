// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IVotingRewardsFactory} from "../interfaces/rewards/IVotingRewardsFactory.sol";

import {IncentiveVotingReward} from "./IncentiveVotingReward.sol";
import {FeesVotingReward} from "./FeesVotingReward.sol";

/// @title Velodrome Superchain Voting Rewards Factory
/// @notice Creates voting rewards contracts for Velodrome pools
contract VotingRewardsFactory is IVotingRewardsFactory {
    /// @inheritdoc IVotingRewardsFactory
    address public immutable voter;
    /// @inheritdoc IVotingRewardsFactory
    address public immutable bridge;

    constructor(address _voter, address _bridge) {
        voter = _voter;
        bridge = _bridge;
    }

    /// @inheritdoc IVotingRewardsFactory
    function createRewards(address[] memory _rewards)
        external
        returns (address feesVotingReward, address incentiveVotingReward)
    {
        if (msg.sender != voter) revert NotVoter();
        feesVotingReward = address(new FeesVotingReward({_voter: voter, _authorized: bridge, _rewards: _rewards}));
        incentiveVotingReward =
            address(new IncentiveVotingReward({_voter: voter, _authorized: bridge, _rewards: _rewards}));
    }
}
