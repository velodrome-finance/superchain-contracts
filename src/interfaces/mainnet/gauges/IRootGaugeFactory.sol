// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootGaugeFactory {
    error NotVoter();

    /// @notice Voter contract address
    function voter() external view returns (address);

    /// @notice XERC20 contract address
    function xerc20() external view returns (address);

    /// @notice Lockbox contract address
    function lockbox() external view returns (address);

    /// @notice Bridge contract address
    function bridge() external view returns (address);

    /// @notice Creates a new root gauge
    /// @param _pool Address of the pool contract
    /// @param _rewardToken Address of the reward token
    /// @return gauge Address of the new gauge contract
    function createGauge(address, address _pool, address, address _rewardToken, bool)
        external
        returns (address gauge);
}
