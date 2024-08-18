// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {IMessageBridge} from "../interfaces/bridge/IMessageBridge.sol";
import {IMessageSender} from "../interfaces/bridge/IMessageSender.sol";

/// @title Message Bridge Contract
/// @notice General purpose message bridge contract
contract MessageBridge is IMessageBridge, Ownable {
    /// @inheritdoc IMessageBridge
    address public immutable voter;
    /// @inheritdoc IMessageBridge
    address public module;

    constructor(address _owner, address _voter, address _module) Ownable(_owner) {
        voter = _voter;
        module = _module;
    }

    /// @inheritdoc IMessageBridge
    function setModule(address _module) external onlyOwner {
        if (_module == address(0)) revert ZeroAddress();
        module = _module;
        emit SetModule({_sender: msg.sender, _module: _module});
    }

    /// @inheritdoc IMessageBridge
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable {
        IMessageSender(module).sendMessage{value: msg.value}({_chainid: _chainid, _message: _message});
    }
}
