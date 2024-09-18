// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IChainRegistry {
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidChain();

    event ChainRegistered(uint256 indexed _chainid);
    event ChainDeregistered(uint256 indexed _chainid);

    /// @notice Returns set of all registered chain ids
    /// @return An array of all registered chain ids
    function chainids() external view returns (uint256[] memory);

    /// @notice Checks if a chain is registered
    /// @param _chainid The chain id to check
    /// @return True if the chain is registered, false otherwise
    function contains(uint256 _chainid) external view returns (bool);

    /// @notice Registers a new chain
    /// @dev Only callable by the owner, allows messages to the registered chain
    /// @param _chainid The chain id to register
    function registerChain(uint256 _chainid) external;

    /// @notice Deregisters a chain
    /// @dev Only callable by the owner, disallows messages to the deregistered chain
    /// @param _chainid The chain id to deregister
    function deregisterChain(uint256 _chainid) external;
}
