// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageRecipient} from "@hyperlane/core/contracts/interfaces/IMessageRecipient.sol";

interface IHLHandler is IMessageRecipient {
    error NotMailbox();
    error NotRoot();

    event ReceivedMessage(uint32 indexed _origin, bytes32 indexed _sender, uint256 _value, string _message);

    /// @notice Callback function used by the mailbox contract to handle incoming messages
    /// @param _origin The domain from which the message originates
    /// @param _sender The address of the sender of the message
    /// @param _message The message payload
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override;
}
