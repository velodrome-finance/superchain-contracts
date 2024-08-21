// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ILeafVoter} from "../interfaces/voter/ILeafVoter.sol";

import {VotingReward} from "./VotingReward.sol";

/// @title Superchain Fees Reward Contract
/// @notice Reward contract for distribution of fees to voters
contract FeesVotingReward is VotingReward {
    constructor(address _voter, address _authorized, address[] memory _rewards)
        VotingReward(_voter, _authorized, _rewards)
    {}

    /// @inheritdoc VotingReward
    function notifyRewardAmount(address token, uint256 amount) external override nonReentrant {
        if (ILeafVoter(voter).gaugeToFees(msg.sender) != address(this)) revert NotGauge();
        if (!isReward[token]) revert InvalidReward();

        _notifyRewardAmount(msg.sender, token, amount);
    }
}
