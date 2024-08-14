// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {IHLMessageBridge, IMessageSender} from "../../interfaces/bridge/hyperlane/IHLMessageBridge.sol";
import {IMessageReceiver} from "../../interfaces/bridge/IMessageReceiver.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract HLMessageBridge is IHLMessageBridge {
    /// @inheritdoc IHLMessageBridge
    address public immutable bridge;
    /// @inheritdoc IHLMessageBridge
    address public immutable mailbox;
    /// @inheritdoc IHLMessageBridge
    IInterchainSecurityModule public immutable securityModule;

    constructor(address _bridge, address _mailbox, address _ism) {
        bridge = _bridge;
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
    }

    /// @inheritdoc IMessageSender
    function sendMessage(address _sender, bytes calldata _payload, uint256 _chainid) external payable override {
        if (msg.sender != bridge) revert NotBridge();
        uint32 domain = uint32(_chainid);
        bytes memory message = abi.encode(_sender, _payload);
        Mailbox(mailbox).dispatch{value: msg.value}({
            _destinationDomain: domain,
            _recipientAddress: TypeCasts.addressToBytes32(address(this)),
            _messageBody: message
        });

        emit SentMessage({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: msg.value,
            _message: string(message)
        });
    }

    /// @inheritdoc IHLMessageBridge
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        (address recipient, bytes memory payload) = abi.decode(_message, (address, bytes));

        IMessageReceiver(recipient).receiveMessage({_message: payload});

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
