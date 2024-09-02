// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageBridge {
    error InvalidCommand();
    error ZeroAddress();
    error NotAuthorized(uint256 command);

    event SetModule(address indexed _sender, address indexed _module);

    /// @notice Returns the address of the module contract that is allowed to send messages x-chain
    function module() external view returns (address);

    /// @notice Returns the address of the voter contract
    /// @dev Used to verify the sender of a message
    function voter() external view returns (address);

    /// @notice Returns the address of the Pool Factory associated with Bridge
    /// @dev Pool Factory maintains the same address across all Leaf Chains but differs on the Root Chain
    function poolFactory() external view returns (address);

    /// @notice Returns the address of the Gauge Factory associated with Bridge
    /// @dev Gauge Factory maintains the same address across all Chains
    function gaugeFactory() external view returns (address);

    /// @notice Sets the address of the module contract that is allowed to send messages x-chain
    /// @dev Module handles x-chain messages
    /// @param _module The address of the new module contract
    function setModule(address _module) external;

    /// @notice Sends a message to the msg.sender via the module contract
    /// @param _message The message
    /// @param _chainid The chain id of chain the recipient contract is on
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable;
}
