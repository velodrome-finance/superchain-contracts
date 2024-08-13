// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageSender {
    /// @notice Sends a message to the destination module
    /// @dev All message modules must implement this function
    /// @param _sender The address of the message sender
    /// @param _payload The message payload
    /// @param _chainid The chain id of the destination chain
    function sendMessage(address _sender, bytes calldata _payload, uint256 _chainid) external payable;
}
