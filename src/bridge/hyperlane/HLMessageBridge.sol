// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";

import {IHLMessageBridge, IHLHandler} from "../../interfaces/bridge/hyperlane/IHLMessageBridge.sol";
import {IMessageBridge} from "../../interfaces/bridge/IMessageBridge.sol";
import {IPoolFactory} from "../../interfaces/pools/IPoolFactory.sol";
import {ILeafGauge} from "../../interfaces/gauges/ILeafGauge.sol";
import {ILeafVoter} from "../../interfaces/voter/ILeafVoter.sol";
import {IReward} from "../../interfaces/rewards/IReward.sol";

import {Commands} from "../../libraries/Commands.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract HLMessageBridge is IHLMessageBridge {
    using SafeERC20 for IERC20;

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

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_origin != 10) revert NotRoot();
        if (TypeCasts.bytes32ToAddress(_sender) != address(this)) revert NotModule();

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
        } else if (command == Commands.GET_INCENTIVES) {
            (address gauge, bytes memory payload) = abi.decode(messageWithoutCommand, (address, bytes));
            address ivr = ILeafVoter(voter).gaugeToBribe({_gauge: gauge});
            IReward(ivr).getReward({_payload: payload});
        } else if (command == Commands.GET_FEES) {
            (address gauge, bytes memory payload) = abi.decode(messageWithoutCommand, (address, bytes));
            address fvr = ILeafVoter(voter).gaugeToFees({_gauge: gauge});
            IReward(fvr).getReward({_payload: payload});
        } else if (command == Commands.NOTIFY) {
            (address gauge, uint256 amount) = abi.decode(messageWithoutCommand, (address, uint256));
            IMessageBridge(bridge).mint({_recipient: address(this), _amount: amount});
            IERC20(xerc20).safeIncreaseAllowance({spender: gauge, value: amount});
            ILeafGauge(gauge).notifyRewardAmount({amount: amount});
        } else {
            revert InvalidCommand();
        }

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
