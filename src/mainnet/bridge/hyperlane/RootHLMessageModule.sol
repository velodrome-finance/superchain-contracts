// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {StandardHookMetadata} from "@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol";

import {
    IRootHLMessageModule, IMessageSender
} from "../../../interfaces/mainnet/bridge/hyperlane/IRootHLMessageModule.sol";
import {IRootMessageBridge} from "../../../interfaces/mainnet/bridge/IRootMessageBridge.sol";
import {IXERC20} from "../../../interfaces/xerc20/IXERC20.sol";
import {Commands} from "../../../libraries/Commands.sol";
import {GasLimits} from "../../../libraries/GasLimits.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract RootHLMessageModule is IRootHLMessageModule {
    using GasLimits for uint256;

    /// @inheritdoc IRootHLMessageModule
    address public immutable bridge;
    /// @inheritdoc IRootHLMessageModule
    address public immutable xerc20;
    /// @inheritdoc IRootHLMessageModule
    address public immutable mailbox;
    /// @inheritdoc IRootHLMessageModule
    mapping(uint256 => uint256) public sendingNonce;

    constructor(address _bridge, address _mailbox) {
        bridge = _bridge;
        xerc20 = IRootMessageBridge(_bridge).xerc20();
        mailbox = _mailbox;
    }

    /// @inheritdoc IMessageSender
    function quote(uint256 _destinationDomain, bytes calldata _messageBody) external view returns (uint256) {
        return Mailbox(mailbox).quoteDispatch({
            destinationDomain: uint32(_destinationDomain),
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _messageBody
        });
    }

    /// @inheritdoc IMessageSender
    function sendMessage(uint256 _chainid, bytes memory _message) external payable override {
        if (msg.sender != bridge) revert NotBridge();
        uint32 domain = uint32(_chainid);

        (uint256 command, bytes memory messageWithoutCommand) = abi.decode(_message, (uint256, bytes));
        if (command <= Commands.WITHDRAW) {
            _message = abi.encode(sendingNonce[_chainid], messageWithoutCommand);
            _message = abi.encode(command, _message);
            sendingNonce[_chainid] += 1;
        } else if (command == Commands.NOTIFY) {
            (, uint256 amount) = abi.decode(messageWithoutCommand, (address, uint256));
            IXERC20(xerc20).burn({_user: address(this), _amount: amount});
        } else if (command == Commands.NOTIFY_WITHOUT_CLAIM) {
            (, uint256 amount) = abi.decode(messageWithoutCommand, (address, uint256));
            IXERC20(xerc20).burn({_user: address(this), _amount: amount});
        }

        bytes memory _metadata = _generateGasMetadata({_command: command});
        Mailbox(mailbox).dispatch{value: msg.value}({
            destinationDomain: domain,
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _message,
            hookMetadata: _metadata
        });

        emit SentMessage({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: msg.value,
            _message: string(_message),
            _metadata: string(_metadata)
        });
    }

    function _generateGasMetadata(uint256 _command) internal view returns (bytes memory) {
        return StandardHookMetadata.formatMetadata({
            _msgValue: msg.value,
            _gasLimit: _command.gasLimit(),
            _refundAddress: tx.origin,
            _customMetadata: ""
        });
    }
}
