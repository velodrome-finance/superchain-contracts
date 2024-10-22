// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {LeafGauge} from "../LeafGauge.sol";
import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";
import {IModeFeeSharing} from "../../interfaces/extensions/IModeFeeSharing.sol";

/// @notice Gauge wrapper with fee sharing support
contract ModeLeafGauge is LeafGauge {
    constructor(
        address _stakingToken,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        address _bridge,
        bool _isPool
    ) LeafGauge(_stakingToken, _feesVotingReward, _rewardToken, _voter, _bridge, _isPool) {
        address sfs = IModeFeeSharing(_voter).sfs();
        uint256 tokenId = IModeFeeSharing(_voter).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }
}
