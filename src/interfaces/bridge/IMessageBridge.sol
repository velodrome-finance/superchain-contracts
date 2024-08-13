// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMessageBridge {
    error ZeroAddress();

    event SetModule(address indexed _sender, address indexed _module);

    /// @notice Returns the address of the module contract that is allowed to send messages x-chain
    function module() external view returns (address);

    /// @notice Sets the address of the module contract that is allowed to send messages x-chain
    /// @dev Module handles x-chain messages
    /// @param _module The address of the new module contract
    function setModule(address _module) external;

    /// @notice Sends a message to the msg.sender via the module contract
    /// @dev Payload is forwarded to msg.sender.receiveMessage()
    /// @param _payload The message payload
    /// @param _chainid The chain id of chain the recipient contract is on
    function sendMessage(bytes calldata _payload, uint256 _chainid) external payable;
}
