// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {IBridge} from "src/interfaces/bridge/IBridge.sol";
import {IHLTokenBridge, ITokenBridge} from "src/interfaces/bridge/hyperlane/IHLTokenBridge.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge emissions between chains
contract RootHLTokenBridge is IHLTokenBridge {
    /// @inheritdoc IHLTokenBridge
    address public immutable bridge;
    /// @inheritdoc IHLTokenBridge
    address public immutable mailbox;
    /// @inheritdoc IHLTokenBridge
    IInterchainSecurityModule public immutable securityModule;

    constructor(address _bridge, address _mailbox, address _ism) {
        bridge = _bridge;
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
    }

    /// @inheritdoc ITokenBridge
    function transfer(address _sender, uint256 _amount, uint256 _chainid) external payable override {
        if (msg.sender != bridge) revert NotBridge();
        uint32 domain = uint32(_chainid);
        bytes memory message = abi.encode(_sender, _amount);
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
}
