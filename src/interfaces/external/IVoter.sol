// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFactoryRegistry} from "src/interfaces/external/IFactoryRegistry.sol";

interface IVoter {
    error GaugeAlreadyKilled();
    error GaugeAlreadyRevived();
    error NotEmergencyCouncil();
    error ZeroAddress();

    event GaugeKilled(address indexed gauge);
    event GaugeRevived(address indexed gauge);

    /// @dev Gauge => Amount claimable
    function claimable(address gauge) external view returns (uint256);

    /// @notice Address of Minter.sol
    function minter() external view returns (address);

    /// @notice Set new emergency council.
    /// @dev Throws if not called by emergency council.
    /// @param _emergencyCouncil .
    function setEmergencyCouncil(address _emergencyCouncil) external;

    function vote(uint256 _tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external;

    function gauges(address _pool) external view returns (address);

    function gaugeToFees(address _gauge) external view returns (address);

    function gaugeToBribe(address _gauge) external view returns (address);

    function createGauge(address _poolFactory, address _pool) external returns (address);

    function factoryRegistry() external view returns (IFactoryRegistry);

    /// @dev Utility to distribute to gauges of pools in array.
    /// @param _gauges Array of gauges to distribute to.
    function distribute(address[] memory _gauges) external;

    function isAlive(address _gauge) external view returns (bool);

    function killGauge(address _gauge) external;

    /// @notice Revives a killed gauge. Gauge will can receive emissions and deposits again.
    /// @dev Throws if not called by emergency council.
    ///      Throws if gauge is not killed.
    /// @param _gauge .
    function reviveGauge(address _gauge) external;

    function isWhitelistedToken(address _token) external view returns (bool);

    function emergencyCouncil() external view returns (address);

    function ve() external view returns (address);

    /// @notice Claim emissions from gauges.
    /// @param _gauges Array of gauges to collect emissions from.
    // function claimRewards(address[] memory _gauges) external;

    /// @notice Claim fees for a given NFT.
    /// @dev Utility to help batch fee claims.
    /// @param _fees    Array of FeesVotingReward contracts to collect from.
    /// @param _tokens  Array of tokens that are used as fees.
    /// @param _tokenId Id of veNFT that you wish to claim fees for.
    function claimFees(address[] memory _fees, address[][] memory _tokens, uint256 _tokenId) external;

    /// @notice Called by users to update voting balances in voting rewards contracts.
    /// @param _tokenId Id of veNFT whose balance you wish to update.
    function poke(uint256 _tokenId) external;

    /// @notice Called by users to reset voting state. Required if you wish to make changes to
    ///         veNFT state (e.g. merge, split, deposit into managed etc).
    ///         Cannot reset in the same epoch that you voted in.
    ///         Can vote or deposit into a managed NFT again after reset.
    /// @param _tokenId Id of veNFT you are reseting.
    function reset(uint256 _tokenId) external;

    /// @notice Standard OZ IGovernor using ve for vote weights.
    function governor() external view returns (address);

    /// @notice Whitelist (or unwhitelist) token for use in bribes.
    /// @dev Throws if not called by governor.
    /// @param _token .
    /// @param _bool .
    function whitelistToken(address _token, bool _bool) external;
}
