// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IMessageBridge} from "../interfaces/bridge/IMessageBridge.sol";
import {IMessageSender} from "../interfaces/bridge/IMessageSender.sol";
import {IVoter} from "../interfaces/external/IVoter.sol";

import {Commands} from "../libraries/Commands.sol";

/// @title Message Bridge Contract
/// @notice General purpose message bridge contract
contract MessageBridge is IMessageBridge, Ownable {
    /// @inheritdoc IMessageBridge
    address public immutable voter;
    /// @inheritdoc IMessageBridge
    address public immutable poolFactory;
    /// @inheritdoc IMessageBridge
    address public immutable gaugeFactory;
    /// @inheritdoc IMessageBridge
    address public module;

    constructor(address _owner, address _voter, address _module, address _poolFactory, address _gaugeFactory)
        Ownable(_owner)
    {
        voter = _voter;
        module = _module;
        poolFactory = _poolFactory;
        gaugeFactory = _gaugeFactory;
    }

    /// @inheritdoc IMessageBridge
    function setModule(address _module) external onlyOwner {
        if (_module == address(0)) revert ZeroAddress();
        module = _module;
        emit SetModule({_sender: msg.sender, _module: _module});
    }

    /// @inheritdoc IMessageBridge
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable {
        (uint256 command, bytes memory messageWithoutCommand) = abi.decode(_message, (uint256, bytes));
        if (command == Commands.CREATE_GAUGE) {
            if (msg.sender != gaugeFactory) revert NotAuthorized(Commands.CREATE_GAUGE);
        } else if (command == Commands.GET_REWARD) {
            (address gauge,) = abi.decode(messageWithoutCommand, (address, bytes));
            if (msg.sender != IVoter(voter).gaugeToBribe(gauge)) revert NotAuthorized(Commands.GET_REWARD);
        }

        IMessageSender(module).sendMessage{value: msg.value}({_chainid: _chainid, _message: _message});
    }
}
