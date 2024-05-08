// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingRewardsFactory {
    error NotWhitelistedToken();
    error AlreadyApproved();
    error NotNotifyAdmin();
    error GaugeExists();
    error NotApproved();
    error ZeroAddress();

    event ApproveKeeper(address indexed keeper);
    event UnapproveKeeper(address indexed keeper);
    event SetNotifyAdmin(address indexed _notifyAdmin);
    event StakingRewardsCreated(
        address indexed pool, address indexed rewardToken, address indexed stakingRewards, address creator
    );

    /// @notice Address of the fee sharing contract.
    /// @return Fee sharing contract address
    function sfs() external view returns (address);

    /// @notice Token Id that sequencer fees are sent to.
    /// @return Token Id
    function tokenId() external view returns (uint256);

    /// @notice Notify admin address
    function notifyAdmin() external view returns (address);

    /// @notice Token Registry address
    function tokenRegistry() external view returns (address);

    /// @notice Pool => Gauge
    function gauges(address _pool) external view returns (address);

    /// @notice Gauge => Pool
    function poolForGauge(address _gauge) external view returns (address);

    /// @notice Set new notify admin
    /// @dev    Only callable by current notify admin
    /// @param _notifyAdmin New notify admin address
    function setNotifyAdmin(address _notifyAdmin) external;

    /// @notice Create new staking rewards contract
    /// @param _pool Pool address
    /// @param _rewardToken Reward token address
    /// @return stakingRewards New staking rewards contract address
    function createStakingRewards(address _pool, address _rewardToken) external returns (address);

    /// @notice Approves the given address as a Keeper
    ///         Cannot approve address(0).
    ///         Cannot approve an address that is already approved.
    /// @dev    Only callable by Owner
    /// @param _keeper address to be approved
    function approveKeeper(address _keeper) external;

    /// @notice Revokes the Keeper permission from the given address
    ///         Cannot unapprove an address that is not approved.
    /// @dev    Only callable by Owner
    /// @param _keeper address to be approved
    function unapproveKeeper(address _keeper) external;

    /// @notice Get all Keeper addresses approved by the Factory
    function keepers() external view returns (address[] memory);

    /// @notice Check if an address is approved as a Keeper within the Factory.
    /// @param _keeper address to check in registry.
    /// @return True if address is approved, else false
    function isKeeper(address _keeper) external view returns (bool);

    /// @notice Get the length of the stored Keepers array
    function keepersLength() external view returns (uint256);
}
