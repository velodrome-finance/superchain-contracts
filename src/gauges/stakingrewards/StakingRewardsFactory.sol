// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IStakingRewardsFactory} from "../../interfaces/gauges/stakingrewards/IStakingRewardsFactory.sol";
import {StakingRewards} from "../../gauges/stakingrewards/StakingRewards.sol";

contract StakingRewardsFactory is IStakingRewardsFactory, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IStakingRewardsFactory
    address public notifyAdmin;

    /// @dev Array of approved Keeper addresses
    EnumerableSet.AddressSet internal _keeperRegistry;

    constructor(address _notifyAdmin, address[] memory _keepers) Ownable(msg.sender) {
        for (uint256 i = 0; i < _keepers.length; i++) {
            _approveKeeper(_keepers[i]);
        }
        notifyAdmin = _notifyAdmin;
        emit SetNotifyAdmin({_notifyAdmin: _notifyAdmin});
    }

    /// @inheritdoc IStakingRewardsFactory
    function setNotifyAdmin(address _notifyAdmin) external {
        if (msg.sender != notifyAdmin) revert NotNotifyAdmin();
        if (_notifyAdmin == address(0)) revert ZeroAddress();
        notifyAdmin = _notifyAdmin;
        emit SetNotifyAdmin({_notifyAdmin: _notifyAdmin});
    }

    /// @inheritdoc IStakingRewardsFactory
    function createStakingRewards(address _pool, address _rewardToken) external returns (address stakingRewards) {
        stakingRewards = address(new StakingRewards(_pool, _rewardToken));
    }

    /// @inheritdoc IStakingRewardsFactory
    function approveKeeper(address _keeper) public virtual onlyOwner {
        _approveKeeper(_keeper);
    }

    // @dev Private approve function to be used in constructor
    function _approveKeeper(address _keeper) private {
        if (_keeper == address(0)) revert ZeroAddress();
        if (_keeperRegistry.contains(_keeper)) revert AlreadyApproved();

        _keeperRegistry.add(_keeper);
        emit ApproveKeeper(_keeper);
    }

    /// @inheritdoc IStakingRewardsFactory
    function unapproveKeeper(address _keeper) external virtual onlyOwner {
        if (!_keeperRegistry.contains(_keeper)) revert NotApproved();

        _keeperRegistry.remove(_keeper);
        emit UnapproveKeeper(_keeper);
    }

    /// @inheritdoc IStakingRewardsFactory
    function keepers() external view returns (address[] memory) {
        return _keeperRegistry.values();
    }

    /// @inheritdoc IStakingRewardsFactory
    function isKeeper(address _keeper) external view returns (bool) {
        return _keeperRegistry.contains(_keeper);
    }

    /// @inheritdoc IStakingRewardsFactory
    function keepersLength() external view returns (uint256) {
        return _keeperRegistry.length();
    }
}
