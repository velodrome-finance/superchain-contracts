// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";

import {IFactoryRegistry} from "../../interfaces/external/IFactoryRegistry.sol";
import {IRootMessageBridge} from "../../interfaces/mainnet/bridge/IRootMessageBridge.sol";
import {IMessageSender} from "../../interfaces/mainnet/bridge/IMessageSender.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";
import {IWETH} from "../../interfaces/external/IWETH.sol";

import {CrossChainRegistry} from "../../bridge/CrossChainRegistry.sol";
import {Commands} from "../../libraries/Commands.sol";

/// @title Root Message Bridge Contract
/// @notice General purpose message bridge contract
/// @dev For notify reward amount, tokens will always be forwarded to the module
/// @dev The module can then use any mechanism available to it to send the tokens cross chain
contract RootMessageBridge is IRootMessageBridge, CrossChainRegistry {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IWETH;
    using SafeERC20 for IERC20;

    /// @inheritdoc IRootMessageBridge
    address public immutable xerc20;
    /// @inheritdoc IRootMessageBridge
    address public immutable voter;
    /// @inheritdoc IRootMessageBridge
    address public immutable factoryRegistry;
    /// @inheritdoc IRootMessageBridge
    address public immutable weth;

    constructor(address _owner, address _xerc20, address _voter, address _weth) CrossChainRegistry(_owner) {
        xerc20 = _xerc20;
        voter = _voter;
        factoryRegistry = IVoter(_voter).factoryRegistry();
        weth = _weth;
    }

    receive() external payable {
        if (msg.sender != weth) revert NotWETH();
    }

    /// @inheritdoc IRootMessageBridge
    function sendMessage(uint256 _chainid, bytes calldata _message) external {
        if (!_chainids.contains({value: _chainid})) revert ChainNotRegistered();
        address module = chains[_chainid];

        (uint256 command, bytes memory messageWithoutCommand) = abi.decode(_message, (uint256, bytes));
        if (command == Commands.DEPOSIT) {
            (address gauge,) = abi.decode(messageWithoutCommand, (address, bytes));
            if (msg.sender != IVoter(voter).gaugeToFees(gauge)) revert NotAuthorized(Commands.DEPOSIT);
        } else if (command == Commands.WITHDRAW) {
            (address gauge,) = abi.decode(messageWithoutCommand, (address, bytes));
            if (msg.sender != IVoter(voter).gaugeToFees(gauge)) revert NotAuthorized(Commands.WITHDRAW);
        } else if (command == Commands.CREATE_GAUGE) {
            (address factory,) = abi.decode(messageWithoutCommand, (address, bytes));
            (, address gaugeFactory) = IFactoryRegistry(factoryRegistry).factoriesToPoolFactory(factory);
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
            IERC20(xerc20).safeTransferFrom({from: msg.sender, to: module, value: amount});
        } else if (command == Commands.NOTIFY_WITHOUT_CLAIM) {
            if (!IVoter(voter).isAlive(msg.sender)) revert NotValidGauge();
            (, uint256 amount) = abi.decode(messageWithoutCommand, (address, uint256));
            IERC20(xerc20).safeTransferFrom({from: msg.sender, to: module, value: amount});
        } else if (command == Commands.KILL_GAUGE) {
            if (msg.sender != IVoter(voter).emergencyCouncil()) revert NotAuthorized(Commands.KILL_GAUGE);
        } else if (command == Commands.REVIVE_GAUGE) {
            if (msg.sender != IVoter(voter).emergencyCouncil()) revert NotAuthorized(Commands.REVIVE_GAUGE);
        } else {
            revert InvalidCommand();
        }

        uint256 fee = IMessageSender(module).quote({_destinationDomain: _chainid, _messageBody: _message});
        IWETH(weth).safeTransferFrom({from: tx.origin, to: address(this), value: fee});
        IWETH(weth).withdraw({wad: fee});

        IMessageSender(module).sendMessage{value: fee}({_chainid: _chainid, _message: _message});
    }
}
