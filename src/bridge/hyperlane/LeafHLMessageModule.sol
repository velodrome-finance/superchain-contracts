// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";

import {ILeafHLMessageModule, IHLHandler} from "../../interfaces/bridge/hyperlane/ILeafHLMessageModule.sol";
import {ILeafMessageBridge} from "../../interfaces/bridge/ILeafMessageBridge.sol";
import {IPoolFactory} from "../../interfaces/pools/IPoolFactory.sol";
import {ILeafGauge} from "../../interfaces/gauges/ILeafGauge.sol";
import {ILeafVoter} from "../../interfaces/voter/ILeafVoter.sol";
import {IReward} from "../../interfaces/rewards/IReward.sol";

import {Commands} from "../../libraries/Commands.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract LeafHLMessageModule is ILeafHLMessageModule {
    using SafeERC20 for IERC20;

    /// @inheritdoc ILeafHLMessageModule
    address public immutable bridge;
    /// @inheritdoc ILeafHLMessageModule
    address public immutable xerc20;
    /// @inheritdoc ILeafHLMessageModule
    address public immutable voter;
    /// @inheritdoc ILeafHLMessageModule
    address public immutable mailbox;
    /// @inheritdoc ILeafHLMessageModule
    IInterchainSecurityModule public immutable securityModule;
    /// @inheritdoc ILeafHLMessageModule
    uint256 public receivingNonce;

    constructor(address _bridge, address _mailbox, address _ism) {
        bridge = _bridge;
        xerc20 = ILeafMessageBridge(_bridge).xerc20();
        voter = ILeafMessageBridge(_bridge).voter();
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_origin != 10) revert NotRoot();
        if (TypeCasts.bytes32ToAddress(_sender) != address(this)) revert NotModule();
        (uint256 nonce, bytes memory unwrappedMessage) = abi.decode(_message, (uint256, bytes));
        if (nonce != receivingNonce) revert InvalidNonce();
        receivingNonce += 1;

        (uint256 command, bytes memory messageWithoutCommand) = abi.decode(unwrappedMessage, (uint256, bytes));

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
            (address poolFactory, bytes memory payload) = abi.decode(messageWithoutCommand, (address, bytes));
            (address votingRewardsFactory, address gaugeFactory, address token0, address token1, uint24 _poolParam) =
                abi.decode(payload, (address, address, address, address, uint24));

            address pool = IPoolFactory(poolFactory).getPool({tokenA: token0, tokenB: token1, fee: _poolParam});

            if (pool == address(0)) {
                pool = IPoolFactory(poolFactory).createPool({tokenA: token0, tokenB: token1, fee: _poolParam});
            }
            ILeafVoter(voter).createGauge({
                _poolFactory: poolFactory,
                _pool: pool,
                _votingRewardsFactory: votingRewardsFactory,
                _gaugeFactory: gaugeFactory
            });
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
            ILeafMessageBridge(bridge).mint({_recipient: address(this), _amount: amount});
            IERC20(xerc20).safeIncreaseAllowance({spender: gauge, value: amount});
            ILeafGauge(gauge).notifyRewardAmount({amount: amount});
        } else if (command == Commands.NOTIFY_WITHOUT_CLAIM) {
            (address gauge, uint256 amount) = abi.decode(messageWithoutCommand, (address, uint256));
            ILeafMessageBridge(bridge).mint({_recipient: address(this), _amount: amount});
            IERC20(xerc20).safeIncreaseAllowance({spender: gauge, value: amount});
            ILeafGauge(gauge).notifyRewardWithoutClaim({amount: amount});
        } else if (command == Commands.KILL_GAUGE) {
            address gauge = abi.decode(messageWithoutCommand, (address));
            ILeafVoter(voter).killGauge({_gauge: gauge});
        } else if (command == Commands.REVIVE_GAUGE) {
            address gauge = abi.decode(messageWithoutCommand, (address));
            ILeafVoter(voter).reviveGauge({_gauge: gauge});
        } else {
            revert InvalidCommand();
        }

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
