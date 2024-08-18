// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Reward} from "./Reward.sol";

/// @title Base voting reward contract for distribution of rewards by token id
///        on a weekly basis
abstract contract VotingReward is Reward {
    constructor(address _voter, address _authorized, address[] memory _rewards) {
        uint256 _length = _rewards.length;
        for (uint256 i; i < _length; i++) {
            if (_rewards[i] != address(0)) {
                isReward[_rewards[i]] = true;
                rewards.push(_rewards[i]);
            }
        }

        voter = _voter;
        authorized = _authorized;
    }

    /// @inheritdoc Reward
    function getReward(uint256 tokenId, address[] memory tokens) external override nonReentrant {
        // if (!IVotingEscrow(ve).isApprovedOrOwner(sender, tokenId) && sender != voter) revert NotAuthorized();
        _getReward(msg.sender, tokenId, tokens);
    }

    /// @inheritdoc Reward
    function notifyRewardAmount(address token, uint256 amount) external virtual override {}
}
