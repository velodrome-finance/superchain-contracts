// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";

import {IRootMessageBridge} from "../../interfaces/mainnet/bridge/IRootMessageBridge.sol";
import {IMessageSender} from "../../interfaces/mainnet/bridge/IMessageSender.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";
import {IXERC20} from "../../interfaces/xerc20/IXERC20.sol";

import {ChainRegistry} from "../../bridge/ChainRegistry.sol";
import {Commands} from "../../libraries/Commands.sol";

/// @title Root Message Bridge Contract
/// @notice General purpose message bridge contract
contract RootMessageBridge is IRootMessageBridge, ChainRegistry {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @inheritdoc IRootMessageBridge
    address public immutable xerc20;
    /// @inheritdoc IRootMessageBridge
    address public immutable voter;
    /// @inheritdoc IRootMessageBridge
    address public immutable gaugeFactory;
    /// @inheritdoc IRootMessageBridge
    address public module;

    constructor(address _owner, address _xerc20, address _voter, address _module, address _gaugeFactory)
        ChainRegistry(_owner)
    {
        xerc20 = _xerc20;
        voter = _voter;
        module = _module;
        gaugeFactory = _gaugeFactory;
    }

    /// @inheritdoc IRootMessageBridge
    function setModule(address _module) external onlyOwner {
        if (_module == address(0)) revert ZeroAddress();
        module = _module;
        emit SetModule({_sender: msg.sender, _module: _module});
    }

    /// @inheritdoc IRootMessageBridge
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable {
        if (!_chainids.contains({value: _chainid})) revert NotRegistered();

        (uint256 command, bytes memory messageWithoutCommand) = abi.decode(_message, (uint256, bytes));
        if (command == Commands.DEPOSIT) {
            (address gauge,) = abi.decode(messageWithoutCommand, (address, bytes));
            if (msg.sender != IVoter(voter).gaugeToFees(gauge)) revert NotAuthorized(Commands.DEPOSIT);
        } else if (command == Commands.WITHDRAW) {
            (address gauge,) = abi.decode(messageWithoutCommand, (address, bytes));
            if (msg.sender != IVoter(voter).gaugeToFees(gauge)) revert NotAuthorized(Commands.WITHDRAW);
        } else if (command == Commands.CREATE_GAUGE) {
            if (msg.sender != gaugeFactory) revert NotAuthorized(Commands.CREATE_GAUGE);
        } else if (command == Commands.GET_INCENTIVES) {
            (address gauge,) = abi.decode(messageWithoutCommand, (address, bytes));
            if (msg.sender != IVoter(voter).gaugeToBribe(gauge)) revert NotAuthorized(Commands.GET_INCENTIVES);
        } else if (command == Commands.GET_FEES) {
            (address gauge,) = abi.decode(messageWithoutCommand, (address, bytes));
            if (msg.sender != IVoter(voter).gaugeToFees(gauge)) revert NotAuthorized(Commands.GET_FEES);
        } else if (command == Commands.NOTIFY) {
            if (!IVoter(voter).isAlive(msg.sender)) revert NotValidGauge();
            (, uint256 amount) = abi.decode(messageWithoutCommand, (address, uint256));
            IXERC20(xerc20).burn({_user: msg.sender, _amount: amount});
        } else {
            revert InvalidCommand();
        }

        IMessageSender(module).sendMessage{value: msg.value}({_chainid: _chainid, _message: _message});
    }
}
