// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILeafVoter {
    error NotAGauge();
    error ZeroAddress();
    error NotAuthorized();
    error GaugeAlreadyKilled();
    error GaugeAlreadyRevived();

    event GaugeCreated(
        address indexed poolFactory,
        address indexed votingRewardsFactory,
        address indexed gaugeFactory,
        address pool,
        address bribeVotingReward,
        address feeVotingReward,
        address gauge
    );
    event GaugeKilled(address indexed gauge);
    event GaugeRevived(address indexed gauge);
    event WhitelistToken(address indexed token, bool indexed _bool);

    /// @notice Address of bridge contract used to forward x-chain messages
    function bridge() external view returns (address);

    /// @dev Pool => Gauge
    function gauges(address _pool) external view returns (address);

    /// @dev Gauge => Pool
    function poolForGauge(address _gauge) external view returns (address);

    /// @dev Gauge => Fees Voting Reward
    function gaugeToFees(address _gauge) external view returns (address);

    /// @dev Gauge => Bribes Voting Reward
    function gaugeToBribe(address _gauge) external view returns (address);

    /// @notice Check if a given address is a gauge
    /// @param _gauge The address to be checked
    /// @return Whether the address is a gauge or not
    function isGauge(address _gauge) external view returns (bool);

    /// @notice Check if a given gauge is alive
    /// @param _gauge The address of the gauge to be checked
    /// @return Whether the gauge is alive or not
    function isAlive(address _gauge) external view returns (bool);

    /// @notice Returns the number of times a token has been whitelisted
    /// @param _token Address of token to view whitelist count
    /// @return Number of times token has been whitelisted
    function whitelistTokenCount(address _token) external view returns (uint256);

    /// @notice Get all Whitelisted Tokens approved by the Voter
    /// @return Array of Whitelisted Token addresses
    function whitelistedTokens() external view returns (address[] memory);

    /// @notice Paginated view of all Whitelisted Tokens
    /// @dev    Should not assume the last Token returned is at index matching given `_end`,
    ///         because if `_end` exceeds `length`, implementation defaults to `length`
    /// @param _start Index of first Token to be fetched
    /// @param _end End index for pagination
    /// @return _tokens Array of whitelisted tokens
    function whitelistedTokens(uint256 _start, uint256 _end) external view returns (address[] memory _tokens);

    /// @notice Check if a given token is whitelisted
    /// @param _token The address of the token to be checked
    /// @return Whether the token is whitelisted or not
    function isWhitelistedToken(address _token) external view returns (bool);

    /// @notice Get the length of the whitelistedTokens array
    function whitelistedTokensLength() external view returns (uint256);

    /// @notice Create a new gauge
    /// @dev Only callable by Message Bridge
    /// @param _poolFactory .
    /// @param _pool .
    /// @param _votingRewardsFactory .
    /// @param _gaugeFactory .
    function createGauge(address _poolFactory, address _pool, address _votingRewardsFactory, address _gaugeFactory)
        external
        returns (address _gauge);

    /// @notice Kills a gauge. The gauge will not receive any new emissions and cannot be deposited into.
    ///         Can still withdraw from gauge.
    /// @dev Only callable by Message Bridge
    ///      Throws if gauge already killed.
    /// @param _gauge .
    function killGauge(address _gauge) external;

    /// @notice Revives a killed gauge. Gauge will can receive emissions and deposits again.
    /// @dev Only callable by Message Bridge
    ///      Throws if gauge is not killed.
    /// @param _gauge .
    function reviveGauge(address _gauge) external;

    /// @notice Claim emissions from gauges.
    /// @param _gauges Array of gauges to collect emissions from.
    function claimRewards(address[] memory _gauges) external;
}
