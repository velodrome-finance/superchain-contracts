// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILeafGaugeFactory {
    error NotAuthorized();
    error ZeroAddress();
    error NotVoter();

    event SetNotifyAdmin(address indexed notifyAdmin);

    /// @notice Voter contract
    function voter() external view returns (address);
    /// @notice XERC20 contract, also is the reward token used by the gauge
    function xerc20() external view returns (address);
    /// @notice Velodrome bridge contract
    function bridge() external view returns (address);
    /// @notice Administrator that can call `notifyRewardWithoutClaim` on gauges
    function notifyAdmin() external view returns (address);

    /// @notice Set notifyAdmin value on leaf gauge factory
    /// @param _admin New administrator that will be able to call `notifyRewardWithoutClaim` on gauges.
    function setNotifyAdmin(address _admin) external;

    /// @notice Creates a new gauge
    /// @param _pool Pool to create a gauge for
    /// @param _feesVotingReward Reward token for fees voting
    /// @param isPool True if the gauge is linked to a pool
    function createGauge(address _pool, address _feesVotingReward, bool isPool) external returns (address gauge);
}
