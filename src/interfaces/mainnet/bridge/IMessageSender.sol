// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageSender {
    error NotBridge();

    event SentMessage(uint32 indexed _destination, bytes32 indexed _recipient, uint256 _value, string _message);

    /// @notice Sends a message to the destination module
    /// @dev All message modules must implement this function
    /// @param _chainid The chain id of the destination chain
    /// @param _message The message
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable;
}
