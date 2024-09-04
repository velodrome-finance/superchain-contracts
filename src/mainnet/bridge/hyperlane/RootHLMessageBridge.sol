// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Address} from "@openzeppelin5/contracts/utils/Address.sol";
import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {IHLMessageBridge, IMessageSender} from "src/interfaces/bridge/hyperlane/IHLMessageBridge.sol";
import {IMessageReceiver} from "src/interfaces/bridge/IMessageReceiver.sol";
import {ILeafVoter} from "src/interfaces/voter/ILeafVoter.sol";
import {IMessageBridge} from "src/interfaces/bridge/IMessageBridge.sol";
import {IReward} from "src/interfaces/rewards/IReward.sol";

import {Commands} from "src/libraries/Commands.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract RootHLMessageBridge is IHLMessageBridge {
    using Address for address;

    /// @inheritdoc IHLMessageBridge
    address public immutable bridge;
    /// @inheritdoc IHLMessageBridge
    address public immutable xerc20;
    /// @inheritdoc IHLMessageBridge
    address public immutable voter;
    /// @inheritdoc IHLMessageBridge
    address public immutable mailbox;
    /// @inheritdoc IHLMessageBridge
    IInterchainSecurityModule public immutable securityModule;

    constructor(address _bridge, address _mailbox, address _ism) {
        bridge = _bridge;
        xerc20 = IMessageBridge(_bridge).xerc20();
        voter = IMessageBridge(_bridge).voter();
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
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
