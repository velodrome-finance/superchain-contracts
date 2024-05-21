// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {StakingRewards} from "../StakingRewards.sol";
import {IPool} from "../../../interfaces/pools/IPool.sol";
import {ModeConverter} from "../extensions/ModeConverter.sol";
import {IFeeSharing} from "../../../interfaces/IFeeSharing.sol";
import {IModeStakingRewardsFactory} from
    "../../../interfaces/gauges/stakingrewards/extensions/IModeStakingRewardsFactory.sol";

/// @notice StakingRewards wrapper with fee sharing support
contract ModeStakingRewards is StakingRewards {
    function initialize(address _stakingToken, address _rewardToken) public virtual override {
        super.initialize({_stakingToken: _stakingToken, _rewardToken: _rewardToken});
        address sfs = IModeStakingRewardsFactory(msg.sender).sfs();
        uint256 tokenId = IModeStakingRewardsFactory(msg.sender).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }

    /// @dev Internal helper function to deploy Fee Converter contracts
    function _deployFeeConverter(address _stakingToken, address _targetToken) internal override returns (address) {
        return address(
            new ModeConverter({
                _stakingRewardsFactory: msg.sender,
                _poolFactory: IPool(_stakingToken).factory(),
                _targetToken: _targetToken
            })
        );
    }
}
