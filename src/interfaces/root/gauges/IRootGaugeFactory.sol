// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootGaugeFactory {
    error ZeroDefaultCap();
    error NotAuthorized();
    error ZeroAddress();
    error NotVoter();

    event NotifyAdminSet(address indexed notifyAdmin);
    event EmissionAdminSet(address indexed _emissionAdmin);
    event DefaultCapSet(uint256 indexed _newDefaultCap);
    event EmissionCapSet(address indexed _gauge, uint256 _newEmissionCap);

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

    /// @notice Reward token supported by this factory
    function rewardToken() external view returns (address);

    /// @notice Minter contract used to mint emissions
    function minter() external view returns (address);

    /// @notice Administrator that can call `notifyRewardWithoutClaim` on gauges
    function notifyAdmin() external view returns (address);

    /// @notice Administrator that can manage emission caps
    function emissionAdmin() external view returns (address);

    /// @notice Default emission cap set on Gauges
    function defaultCap() external view returns (uint256);

    /// @notice Value of Weekly Emissions for given Epoch
    function weeklyEmissions() external view returns (uint256);

    /// @notice Timestamp of start of epoch that `calculateMaxEmissions()` was last called in
    function activePeriod() external view returns (uint256);

    /// @notice Returns the emission cap of a Gauge
    /// @param _gauge The gauge we are viewing the emission cap of
    /// @return The emission cap of the gauge
    function emissionCaps(address _gauge) external view returns (uint256);

    /// @notice Denominator for emission calculations (as basis points)
    function MAX_BPS() external view returns (uint256);

    /// @notice Decay rate of emissions as percentage of `MAX_BPS`
    function WEEKLY_DECAY() external view returns (uint256);

    /// @notice Timestamp of the epoch when tail emissions will start
    function TAIL_START_TIMESTAMP() external view returns (uint256);

    /// @notice Creates a new root gauge
    /// @param _pool Address of the pool contract
    /// @param _rewardToken Address of the reward token
    /// @return gauge Address of the new gauge contract
    function createGauge(address, address _pool, address, address _rewardToken, bool)
        external
        returns (address gauge);

    /// @notice Calculates max amount of emissions that can be deposited into a gauge
    /// @dev    Max Amount is calculated based on total weekly emissions and `emissionCap` set on gauge
    /// @param _gauge Address of the gauge contract
    function calculateMaxEmissions(address _gauge) external returns (uint256);

    /// @notice Set notifyAdmin value on root gauge factory
    /// @param _admin New administrator that will be able to call `notifyRewardWithoutClaim` on gauges.
    function setNotifyAdmin(address _admin) external;

    /// @notice Set emissionAdmin value on root gauge factory
    /// @param _admin New administrator that will be able to manage emission caps
    function setEmissionAdmin(address _admin) external;

    /// @notice Sets the emission cap for a Gauge
    /// @param _gauge Address of the gauge contract
    /// @param _emissionCap The emission cap to be set
    function setEmissionCap(address _gauge, uint256 _emissionCap) external;

    /// @notice Sets the default emission cap for gauges
    /// @param _defaultCap The default emission cap to be set
    function setDefaultCap(uint256 _defaultCap) external;
}
