// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageRecipient} from "@hyperlane/core/contracts/interfaces/IMessageRecipient.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {ITokenBridge} from "../ITokenBridge.sol";

interface IHLTokenBridge is ITokenBridge, IMessageRecipient {
    error NotBridge();
    error NotMailbox();
    error NotValidGauge();

    event SentMessage(uint32 indexed _destination, bytes32 indexed _recipient, uint256 _value, string _message);
    event ReceivedMessage(uint32 indexed _origin, bytes32 indexed _sender, uint256 _value, string _message);

    /// @notice Returns the address of the bridge contract that this module is associated with
    function bridge() external view returns (address);

    /// @notice Returns the address of the mailbox contract that is used to bridge by this contract
    function mailbox() external view returns (address);

    /// @notice Returns the address of the security module contract used by the bridge
    function securityModule() external view returns (IInterchainSecurityModule);

    /// @notice Callback function used by the mailbox contract to handle incoming messages
    /// @param _origin The domain from which the message originates
    /// @param _sender The address of the sender of the message
    /// @param _message The message payload
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override;
}
