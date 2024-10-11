// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootVotingRewardsFactory} from "../../interfaces/root/rewards/IRootVotingRewardsFactory.sol";

import {RootIncentiveVotingReward} from "./RootIncentiveVotingReward.sol";
import {RootFeesVotingReward} from "./RootFeesVotingReward.sol";

contract RootVotingRewardsFactory is IRootVotingRewardsFactory {
    /// @inheritdoc IRootVotingRewardsFactory
    address public immutable bridge;
    /// @inheritdoc IRootVotingRewardsFactory
    mapping(address => mapping(uint256 => address)) public recipient;

    constructor(address _bridge) {
        bridge = _bridge;
    }

    /// @inheritdoc IRootVotingRewardsFactory
    function setRecipient(uint256 _chainid, address _recipient) external {
        recipient[msg.sender][_chainid] = _recipient;
        emit RecipientSet({_caller: msg.sender, _chainid: _chainid, _recipient: _recipient});
    }

    /// @inheritdoc IRootVotingRewardsFactory
    function createRewards(address, address[] memory _rewards)
        external
        returns (address feesVotingReward, address incentiveVotingReward)
    {
        incentiveVotingReward =
            address(new RootIncentiveVotingReward({_bridge: bridge, _voter: msg.sender, _rewards: _rewards}));
        feesVotingReward = address(
            new RootFeesVotingReward({
                _bridge: bridge,
                _voter: msg.sender,
                _incentiveVotingReward: incentiveVotingReward,
                _rewards: _rewards
            })
        );
    }
}
