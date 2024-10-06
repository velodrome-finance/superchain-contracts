// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageSender {
    error NotBridge();

    event SentMessage(
        uint32 indexed _destination, bytes32 indexed _recipient, uint256 _value, string _message, string _metadata
    );

    /// @notice Sends a message to the destination module
    /// @dev All message modules must implement this function
    /// @param _chainid The chain id of the destination chain
    /// @param _message The message
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable;

    /// @notice Quotes the amount of native token required to dispatch a message
    /// @param _destinationDomain The chain id of the destination chain
    /// @param _messageBody The message body to be dispatched
    /// @return The amount of native token required to dispatch the message
    function quote(uint256 _destinationDomain, bytes calldata _messageBody) external payable returns (uint256);
}
