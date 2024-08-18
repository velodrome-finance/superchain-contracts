// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IRootBribeVotingReward} from "../../interfaces/mainnet/rewards/IRootBribeVotingReward.sol";

contract RootBribeVotingReward is IRootBribeVotingReward {
    /// @inheritdoc IRootBribeVotingReward
    address public immutable bridge;
    /// @inheritdoc IRootBribeVotingReward
    address public immutable voter;

    constructor(address _bridge, address _voter, address[] memory _rewards) {
        voter = _voter;
        bridge = _bridge;
    }
}
