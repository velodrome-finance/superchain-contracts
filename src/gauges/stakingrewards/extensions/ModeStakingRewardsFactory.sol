// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IFeeSharing} from "../../../interfaces/IFeeSharing.sol";
import {StakingRewardsFactory} from "../StakingRewardsFactory.sol";
import {ModeStakingRewards} from "../extensions/ModeStakingRewards.sol";
import {IModeStakingRewardsFactory} from
    "../../../interfaces/gauges/stakingrewards/extensions/IModeStakingRewardsFactory.sol";

/// @notice StakingRewardsFactory wrapper with fee sharing support
contract ModeStakingRewardsFactory is StakingRewardsFactory, IModeStakingRewardsFactory {
    /// @inheritdoc IModeStakingRewardsFactory
    address public immutable sfs;
    /// @inheritdoc IModeStakingRewardsFactory
    uint256 public immutable tokenId;

    constructor(
        address _admin,
        address _tokenRegistry,
        address _router,
        address _sfs,
        address _recipient,
        address[] memory _keepers
    ) StakingRewardsFactory(_admin, _tokenRegistry, _router, _keepers) {
        sfs = _sfs;
        tokenId = IFeeSharing(_sfs).register(_recipient);
    }

    /// @dev Internal helper function to deploy StakingRewards contracts
    function _deployStakingRewards(address _pool, address _rewardToken) internal override returns (address) {
        return address(
            new ModeStakingRewards({_stakingToken: _pool, _rewardToken: _rewardToken, _sfs: sfs, _tokenId: tokenId})
        );
    }
}
