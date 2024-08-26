// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Address} from "@openzeppelin5/contracts/utils/Address.sol";
import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {IHLMessageBridge, IMessageSender} from "../../interfaces/bridge/hyperlane/IHLMessageBridge.sol";
import {IMessageReceiver} from "../../interfaces/bridge/IMessageReceiver.sol";
import {ILeafVoter} from "../../interfaces/voter/ILeafVoter.sol";
import {IPoolFactory} from "../../interfaces/pools/IPoolFactory.sol";
import {IMessageBridge} from "../../interfaces/bridge/IMessageBridge.sol";
import {IReward} from "../../interfaces/rewards/IReward.sol";

import {Commands} from "../../libraries/Commands.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract HLMessageBridge is IHLMessageBridge {
    using Address for address;

    /// @inheritdoc IHLMessageBridge
    address public immutable bridge;
    /// @inheritdoc IHLMessageBridge
    address public immutable voter;
    /// @inheritdoc IHLMessageBridge
    address public immutable mailbox;
    /// @inheritdoc IHLMessageBridge
    IInterchainSecurityModule public immutable securityModule;

    constructor(address _bridge, address _mailbox, address _ism) {
        bridge = _bridge;
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

    /// @inheritdoc IHLMessageBridge
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        (uint256 command, bytes memory messageWithoutCommand) = abi.decode(_message, (uint256, bytes));

        if (command == Commands.DEPOSIT) {
            (address gauge, bytes memory payload) = abi.decode(messageWithoutCommand, (address, bytes));
            address fvr = ILeafVoter(voter).gaugeToFees({_gauge: gauge});
            IReward(fvr)._deposit({_payload: payload});
            address ivr = ILeafVoter(voter).gaugeToBribe({_gauge: gauge});
            IReward(ivr)._deposit({_payload: payload});
        } else if (command == Commands.WITHDRAW) {
            (address gauge, bytes memory payload) = abi.decode(messageWithoutCommand, (address, bytes));
            address fvr = ILeafVoter(voter).gaugeToFees({_gauge: gauge});
            IReward(fvr)._withdraw({_payload: payload});
            address ivr = ILeafVoter(voter).gaugeToBribe({_gauge: gauge});
            IReward(ivr)._withdraw({_payload: payload});
        } else if (command == Commands.CREATE_GAUGE) {
            (address token0, address token1, bool stable) = abi.decode(messageWithoutCommand, (address, address, bool));
            address poolFactory = IMessageBridge(bridge).poolFactory();

            address pool = IPoolFactory(poolFactory).getPool({tokenA: token0, tokenB: token1, stable: stable});
            if (pool == address(0)) {
                pool = IPoolFactory(poolFactory).createPool({tokenA: token0, tokenB: token1, stable: stable});
            }
            ILeafVoter(voter).createGauge({_poolFactory: poolFactory, _pool: pool});
        } else {
            revert InvalidCommand();
        }

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
