// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICrossChainRegistry {
    event ChainRegistered(uint256 indexed _chainid, address indexed _module);
    event ChainDeregistered(uint256 indexed _chainid);
    event ModuleAdded(address indexed _module);
    event ModuleSet(uint256 indexed _chainid, address indexed _module);

    error ChainAlreadyAdded();
    error ChainNotRegistered();
    error InvalidChainId();
    error ModuleAlreadyAdded();
    error ModuleNotAdded();

    /// @notice Add support for a chain with messages forwarded to a given module
    /// @dev Check module code if adding a new module for the first time
    /// @param _chainid Chain ID to add
    /// @param _module Module to forward messages to, must be registered
    function registerChain(uint256 _chainid, address _module) external;

    /// @notice Remove support for a chain
    /// @param _chainid Chain ID to remove
    function deregisterChain(uint256 _chainid) external;

    /// @notice Add a module to be used for message forwarding
    /// @dev Modules are deployed on other chains at the same address
    /// @dev Modules are not trusted by default and must be checked prior to usage
    /// @param _module Module to register
    function addModule(address _module) external;

    /// @notice Update a module used by a chain for message forwarding
    /// @param _chainid Chain ID to update
    /// @param _module Module to forward messages to
    function setModule(uint256 _chainid, address _module) external;

    /// @notice Get message module for a given chain
    /// @param _chainid Chain ID to check
    function chains(uint256 _chainid) external view returns (address);

    /// @notice Get list of supported chains
    function chainids() external view returns (uint256[] memory);

    /// @notice Check if a chain is supported
    /// @param _chainid Chain ID to check
    function containsChain(uint256 _chainid) external view returns (bool);

    /// @notice Get list of registered modules
    function modules() external view returns (address[] memory);

    /// @notice Check if a module is registered
    /// @param _module Module to check
    function containsModule(address _module) external view returns (bool);
}
