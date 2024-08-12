// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IVotingRewardsFactory} from "src/interfaces/external/IVotingRewardsFactory.sol";

contract MockVotingRewardsFactory is IVotingRewardsFactory {
    /// @inheritdoc IVotingRewardsFactory
    function createRewards(address, address[] memory)
        external
        pure
        returns (address feesVotingReward, address bribeVotingReward)
    {
        // mock addresses to test gauge creation
        feesVotingReward = address(12);
        bribeVotingReward = address(13);
    }
}
