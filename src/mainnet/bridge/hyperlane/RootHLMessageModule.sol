// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {
    IRootHLMessageModule, IMessageSender
} from "../../../interfaces/mainnet/bridge/hyperlane/IRootHLMessageModule.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract RootHLMessageModule is IRootHLMessageModule {
    /// @inheritdoc IRootHLMessageModule
    address public immutable bridge;
    /// @inheritdoc IRootHLMessageModule
    address public immutable mailbox;

    constructor(address _bridge, address _mailbox) {
        bridge = _bridge;
        mailbox = _mailbox;
    }

    /// @inheritdoc IMessageSender
    function quote(uint256 _destinationDomain, bytes calldata _messageBody) external payable returns (uint256) {
        return Mailbox(mailbox).quoteDispatch({
            destinationDomain: uint32(_destinationDomain),
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _messageBody
        });
    }

    /// @inheritdoc IMessageSender
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable override {
        if (msg.sender != bridge) revert NotBridge();
        uint32 domain = uint32(_chainid);
        Mailbox(mailbox).dispatch{value: msg.value}({
            _destinationDomain: domain,
            _recipientAddress: TypeCasts.addressToBytes32(address(this)),
            _messageBody: _message
        });

        emit SentMessage({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: msg.value,
            _message: string(_message)
        });
    }
}
