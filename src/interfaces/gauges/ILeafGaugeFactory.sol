// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILeafGaugeFactory {
    /// @notice Voter contract
    function voter() external view returns (address);
    /// @notice Factory contract that produces pools that this gauge will link to
    function factory() external view returns (address);
    /// @notice XERC20 contract, also is the reward token used by the gauge
    function xerc20() external view returns (address);
    /// @notice Velodrome bridge contract
    function bridge() external view returns (address);

    /// @notice Creates a new gauge
    /// @param _token0 Token0 address
    /// @param _token1 Token1 address
    /// @param _stable True if the pool is a stable pool
    /// @param _feesVotingReward Reward token for fees voting
    /// @param isPool True if the gauge is linked to a pool
    function createGauge(address _token0, address _token1, bool _stable, address _feesVotingReward, bool isPool)
        external
        returns (address gauge);
}
