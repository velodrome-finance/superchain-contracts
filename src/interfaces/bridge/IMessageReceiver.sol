// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageReceiver {
    /// @notice Receives a message from the bridge
    /// @dev Any contract that wants to receive a message from the bridge must implement this
    /// @param _message The message payload
    function receiveMessage(bytes calldata _message) external;
}
