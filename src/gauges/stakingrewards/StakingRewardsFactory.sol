// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IFeeSharing} from "../../interfaces/IFeeSharing.sol";
import {ITokenRegistry} from "../../interfaces/gauges/tokenregistry/ITokenRegistry.sol";
import {IStakingRewardsFactory} from "../../interfaces/gauges/stakingrewards/IStakingRewardsFactory.sol";
import {StakingRewards} from "../../gauges/stakingrewards/StakingRewards.sol";
import {IPool} from "../../interfaces/pools/IPool.sol";

contract StakingRewardsFactory is IStakingRewardsFactory, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IStakingRewardsFactory
    address public immutable sfs;

    /// @inheritdoc IStakingRewardsFactory
    uint256 public immutable tokenId;

    /// @inheritdoc IStakingRewardsFactory
    address public immutable tokenRegistry;

    /// @inheritdoc IStakingRewardsFactory
    address public notifyAdmin;

    /// @inheritdoc IStakingRewardsFactory
    address public immutable router;

    /// @inheritdoc IStakingRewardsFactory
    mapping(address => address) public gauges;

    /// @inheritdoc IStakingRewardsFactory
    mapping(address => address) public poolForGauge;

    /// @dev Array of approved Keeper addresses
    EnumerableSet.AddressSet internal _keeperRegistry;

    constructor(
        address _notifyAdmin,
        address _tokenRegistry,
        address _router,
        address _sfs,
        address _recipient,
        address[] memory _keepers
    ) Ownable(msg.sender) {
        for (uint256 i = 0; i < _keepers.length; i++) {
            _approveKeeper(_keepers[i]);
        }
        notifyAdmin = _notifyAdmin;
        tokenRegistry = _tokenRegistry;
        router = _router;
        sfs = _sfs;
        tokenId = IFeeSharing(_sfs).register(_recipient);
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
        if (gauges[_pool] != address(0)) revert GaugeExists();
        if (_rewardToken == address(0) || _pool == address(0)) revert ZeroAddress();
        (address token0, address token1) = IPool(_pool).tokens();
        ITokenRegistry _tokenRegistry = ITokenRegistry(tokenRegistry);
        if (!_tokenRegistry.isWhitelistedToken(token0) || !_tokenRegistry.isWhitelistedToken(token1)) {
            revert NotWhitelistedToken();
        }

        stakingRewards = address(
            new StakingRewards({_stakingToken: _pool, _rewardToken: _rewardToken, _sfs: sfs, _tokenId: tokenId})
        );
        gauges[_pool] = stakingRewards;
        poolForGauge[stakingRewards] = _pool;
        emit StakingRewardsCreated({
            pool: _pool,
            rewardToken: _rewardToken,
            stakingRewards: stakingRewards,
            creator: msg.sender
        });
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
