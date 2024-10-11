// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {ILeafHLMessageModule, IHLHandler} from "../../interfaces/bridge/hyperlane/ILeafHLMessageModule.sol";
import {ILeafMessageBridge} from "../../interfaces/bridge/ILeafMessageBridge.sol";
import {IPoolFactory} from "../../interfaces/pools/IPoolFactory.sol";
import {ILeafGauge} from "../../interfaces/gauges/ILeafGauge.sol";
import {ILeafVoter} from "../../interfaces/voter/ILeafVoter.sol";
import {IReward} from "../../interfaces/rewards/IReward.sol";
import {Commands} from "../../libraries/Commands.sol";
import {IXERC20} from "../../interfaces/xerc20/IXERC20.sol";
import {ISpecifiesInterchainSecurityModule} from "../../interfaces/external/ISpecifiesInterchainSecurityModule.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract LeafHLMessageModule is ILeafHLMessageModule, ISpecifiesInterchainSecurityModule, Ownable {
    using SafeERC20 for IERC20;
    using Commands for bytes;

    /// @inheritdoc ILeafHLMessageModule
    address public immutable bridge;
    /// @inheritdoc ILeafHLMessageModule
    address public immutable xerc20;
    /// @inheritdoc ILeafHLMessageModule
    address public immutable voter;
    /// @inheritdoc ILeafHLMessageModule
    address public immutable mailbox;
    /// @inheritdoc ILeafHLMessageModule
    IInterchainSecurityModule public securityModule;
    /// @inheritdoc ILeafHLMessageModule
    uint256 public receivingNonce;

    constructor(address _owner, address _bridge, address _mailbox, address _ism) Ownable(_owner) {
        bridge = _bridge;
        xerc20 = ILeafMessageBridge(_bridge).xerc20();
        voter = ILeafMessageBridge(_bridge).voter();
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule
    function interchainSecurityModule() external view returns (IInterchainSecurityModule) {
        return securityModule;
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule
    function setInterchainSecurityModule(address _ism) external onlyOwner {
        securityModule = IInterchainSecurityModule(_ism);
        emit InterchainSecurityModuleChanged({_new: _ism});
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_origin != 10) revert NotRoot();
        if (TypeCasts.bytes32ToAddress(_sender) != address(this)) revert NotModule();

        uint256 command = _message.command();

        if (command <= Commands.WITHDRAW) {
            if (_message.nonce() != receivingNonce) revert InvalidNonce();
            receivingNonce += 1;
        }

        if (command == Commands.DEPOSIT) {
            address gauge = _message.toAddress();
            (uint256 amount, uint256 tokenId) = _message.amountAndTokenId();
            address fvr = ILeafVoter(voter).gaugeToFees({_gauge: gauge});
            IReward(fvr)._deposit({amount: amount, tokenId: tokenId});
            address ivr = ILeafVoter(voter).gaugeToIncentive({_gauge: gauge});
            IReward(ivr)._deposit({amount: amount, tokenId: tokenId});
        } else if (command == Commands.WITHDRAW) {
            address gauge = _message.toAddress();
            (uint256 amount, uint256 tokenId) = _message.amountAndTokenId();
            address fvr = ILeafVoter(voter).gaugeToFees({_gauge: gauge});
            IReward(fvr)._withdraw({amount: amount, tokenId: tokenId});
            address ivr = ILeafVoter(voter).gaugeToIncentive({_gauge: gauge});
            IReward(ivr)._withdraw({amount: amount, tokenId: tokenId});
        } else if (command == Commands.GET_INCENTIVES) {
            address ivr = ILeafVoter(voter).gaugeToIncentive({_gauge: _message.toAddress()});

            address owner = _message.owner();
            uint256 tokenId = _message.tokenId();
            address[] memory tokens = _message.tokens();
            IReward(ivr).getReward({_recipient: owner, _tokenId: tokenId, _tokens: tokens});
        } else if (command == Commands.GET_FEES) {
            address fvr = ILeafVoter(voter).gaugeToFees({_gauge: _message.toAddress()});

            address owner = _message.owner();
            uint256 tokenId = _message.tokenId();
            address[] memory tokens = _message.tokens();
            IReward(fvr).getReward({_recipient: owner, _tokenId: tokenId, _tokens: tokens});
        } else if (command == Commands.CREATE_GAUGE) {
            (
                address poolFactory,
                address votingRewardsFactory,
                address gaugeFactory,
                address token0,
                address token1,
                uint24 _poolParam
            ) = _message.createGaugeParams();

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
        } else if (command == Commands.NOTIFY) {
            address gauge = _message.toAddress();
            uint256 amount = _message.amount();
            IXERC20(xerc20).mint({_user: address(this), _amount: amount});
            IERC20(xerc20).safeIncreaseAllowance({spender: gauge, value: amount});
            ILeafGauge(gauge).notifyRewardAmount({amount: amount});
        } else if (command == Commands.NOTIFY_WITHOUT_CLAIM) {
            address gauge = _message.toAddress();
            uint256 amount = _message.amount();
            IXERC20(xerc20).mint({_user: address(this), _amount: amount});
            IERC20(xerc20).safeIncreaseAllowance({spender: gauge, value: amount});
            ILeafGauge(gauge).notifyRewardWithoutClaim({amount: amount});
        } else if (command == Commands.KILL_GAUGE) {
            address gauge = _message.toAddress();
            ILeafVoter(voter).killGauge({_gauge: gauge});
        } else if (command == Commands.REVIVE_GAUGE) {
            address gauge = _message.toAddress();
            ILeafVoter(voter).reviveGauge({_gauge: gauge});
        } else {
            revert InvalidCommand();
        }

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
