// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ILeafVoter} from "../interfaces/voter/ILeafVoter.sol";

import {VotingReward} from "./VotingReward.sol";

/// @title Superchain Incentive Reward Contract
/// @notice Reward contract for distribution of incentives to voters
contract BribeVotingReward is VotingReward {
    constructor(address _voter, address _authorized, address[] memory _rewards)
        VotingReward(_voter, _authorized, _rewards)
    {}

    /// @inheritdoc VotingReward
    function notifyRewardAmount(address token, uint256 amount) external override nonReentrant {
        if (!isReward[token]) {
            if (!ILeafVoter(voter).isWhitelistedToken(token)) revert NotWhitelisted();
            isReward[token] = true;
            rewards.push(token);
        }

        _notifyRewardAmount(msg.sender, token, amount);
    }
}
