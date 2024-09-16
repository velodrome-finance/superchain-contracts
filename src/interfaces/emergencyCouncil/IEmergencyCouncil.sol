// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEmergencyCouncil {
    /// @notice Voter contract
    function voter() external view returns (address);

    /// @notice VotingEscrow contract
    function votingEscrow() external view returns (address);

    /// @notice Bridge contract used to communicate x-chain
    function bridge() external view returns (address);

    /// @notice Kills a gauge. The gauge will not receive any new emissions and cannot be deposited into.
    ///         Can still withdraw from gauge.
    /// @dev Throws if not called by owner.
    ///      Throws if gauge already killed.
    /// @param _gauge .
    function killRootGauge(address _gauge) external;

    /// @notice Kills a gauge on the leaf chain by dispatching a message to the bridge contract.
    /// @dev Throws if not called by owner.
    /// @param _chainid of the leaf chain where the gauge is located.
    /// @param _gauge .
    function killLeafGauge(uint256 _chainid, address _gauge) external;

    /// @notice Revives a killed gauge. Gauge will receive emissions and deposits again.
    /// @dev Throws if not called by owner.
    /// @param _gauge .
    function reviveRootGauge(address _gauge) external;

    /// @notice Revives a killed gauge on the leaf chain. Gauge will receive emissions and deposits again.
    /// @dev Throws if not called by owner.
    /// @param _chainid of the leaf chain where the gauge is located.
    /// @param _gauge .
    function reviveLeafGauge(uint256 _chainid, address _gauge) external;

    /// @notice Set pool name
    /// @dev Throws if not called by owner.
    /// @param _pool .
    /// @param _name String of new name
    function setPoolName(address _pool, string memory _name) external;

    /// @notice Set pool symbol
    /// @dev Throws if not called by owner.
    /// @param _pool .
    /// @param _symbol String of new symbol
    function setPoolSymbol(address _pool, string memory _symbol) external;

    /// @notice Set Managed NFT state. Inactive NFTs cannot be deposited into.
    /// @param _mTokenId managed nft state to set
    /// @param _state true => inactive, false => active
    function setManagedState(uint256 _mTokenId, bool _state) external;
}
