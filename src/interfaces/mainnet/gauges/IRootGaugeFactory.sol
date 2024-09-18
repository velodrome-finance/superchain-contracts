// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootGaugeFactory {
    error NotVoter();
    error NotAuthorized();
    error ZeroAddress();

    event SetNotifyAdmin(address indexed notifyAdmin);

    /// @notice Voter contract address
    function voter() external view returns (address);

    /// @notice XERC20 contract address
    function xerc20() external view returns (address);

    /// @notice Lockbox contract address
    function lockbox() external view returns (address);

    /// @notice Address of bridge contract used to forward x-chain messages
    function messageBridge() external view returns (address);

    /// @notice Pool factory associated with this gauge factory
    function poolFactory() external view returns (address);

    /// @notice Voting rewards factory contract address
    function votingRewardsFactory() external view returns (address);

    /// @notice Administrator that can call `notifyRewardWithoutClaim` on gauges
    function notifyAdmin() external view returns (address);

    /// @notice Set notifyAdmin value on root gauge factory
    /// @param _admin New administrator that will be able to call `notifyRewardWithoutClaim` on gauges.
    function setNotifyAdmin(address _admin) external;

    /// @notice Creates a new root gauge
    /// @param _pool Address of the pool contract
    /// @param _rewardToken Address of the reward token
    /// @return gauge Address of the new gauge contract
    function createGauge(address, address _pool, address, address _rewardToken, bool)
        external
        returns (address gauge);
}
