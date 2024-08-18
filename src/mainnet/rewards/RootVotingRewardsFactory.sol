// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootVotingRewardsFactory} from "../../interfaces/mainnet/rewards/IRootVotingRewardsFactory.sol";

import {RootBribeVotingReward} from "./RootBribeVotingReward.sol";
import {RootFeesVotingReward} from "./RootFeesVotingReward.sol";

contract RootVotingRewardsFactory is IRootVotingRewardsFactory {
    /// @inheritdoc IRootVotingRewardsFactory
    address public immutable bridge;

    constructor(address _bridge) {
        bridge = _bridge;
    }

    /// @inheritdoc IRootVotingRewardsFactory
    function createRewards(address, address[] memory _rewards)
        external
        returns (address feesVotingReward, address bribeVotingReward)
    {
        // bribeVotingReward = address(new RootBribeVotingReward(msg.sender, _rewards));
        feesVotingReward = address(new RootFeesVotingReward({_bridge: bridge, _voter: msg.sender, _rewards: _rewards}));
    }
}
