// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Converter} from "../Converter.sol";
import {IFeeSharing} from "../../../interfaces/IFeeSharing.sol";
import {IModeStakingRewardsFactory} from
    "../../../interfaces/gauges/stakingrewards/extensions/IModeStakingRewardsFactory.sol";

/// @notice Converter wrapper with fee sharing support
contract ModeConverter is Converter {
    constructor(address _stakingRewardsFactory, address _poolFactory, address _targetToken)
        Converter(_stakingRewardsFactory, _poolFactory, _targetToken)
    {
        address sfs = IModeStakingRewardsFactory(_stakingRewardsFactory).sfs();
        uint256 tokenId = IModeStakingRewardsFactory(_stakingRewardsFactory).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }
}
