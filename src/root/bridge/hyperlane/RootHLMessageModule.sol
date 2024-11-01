// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {StandardHookMetadata} from "@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol";
import {IPostDispatchHook} from "@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {
    IRootHLMessageModule, IMessageSender
} from "../../../interfaces/root/bridge/hyperlane/IRootHLMessageModule.sol";
import {IHookGasEstimator} from "../../../interfaces/root/bridge/hyperlane/IHookGasEstimator.sol";
import {IRootMessageBridge} from "../../../interfaces/root/bridge/IRootMessageBridge.sol";
import {IVotingEscrow} from "../../../interfaces/external/IVotingEscrow.sol";
import {IVoter} from "../../../interfaces/external/IVoter.sol";
import {IXERC20} from "../../../interfaces/xerc20/IXERC20.sol";

import {VelodromeTimeLibrary} from "../../../libraries/VelodromeTimeLibrary.sol";
import {GasLimits} from "../../../libraries/GasLimits.sol";
import {Commands} from "../../../libraries/Commands.sol";

/// @title Hyperlane Token Bridge
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract RootHLMessageModule is IRootHLMessageModule {
    using GasLimits for uint256;
    using Commands for bytes;

    /// @inheritdoc IRootHLMessageModule
    address public immutable bridge;
    /// @inheritdoc IRootHLMessageModule
    address public immutable xerc20;
    /// @inheritdoc IRootHLMessageModule
    address public immutable mailbox;
    /// @inheritdoc IRootHLMessageModule
    address public immutable voter;
    /// @inheritdoc IRootHLMessageModule
    address public immutable ve;
    /// @inheritdoc IRootHLMessageModule
    address public hook;

    constructor(address _bridge, address _mailbox) {
        bridge = _bridge;
        xerc20 = IRootMessageBridge(_bridge).xerc20();
        mailbox = _mailbox;
        address _voter = IRootMessageBridge(_bridge).voter();
        voter = _voter;
        ve = IVoter(_voter).ve();
    }

    /// @inheritdoc IMessageSender
    function quote(uint256 _destinationDomain, bytes calldata _messageBody) external view returns (uint256) {
        address _hook = hook;
        uint256 command = _messageBody.command();
        bytes memory _metadata = _generateGasMetadata({_command: command, _hook: _hook});

        return Mailbox(mailbox).quoteDispatch({
            destinationDomain: uint32(_destinationDomain),
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _messageBody,
            metadata: _metadata,
            hook: IPostDispatchHook(_hook)
        });
    }

    /// @inheritdoc IMessageSender
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable override {
        if (msg.sender != bridge) revert NotBridge();
        uint32 domain = uint32(_chainid);

        address _hook = hook;
        uint256 command = _message.command();
        bytes memory _metadata = _generateGasMetadata({_command: command, _hook: _hook});

        if (command <= Commands.WITHDRAW) {
            if (block.timestamp > VelodromeTimeLibrary.epochVoteEnd(block.timestamp)) {
                if (!IVotingEscrow(ve).isApprovedOrOwner({_spender: tx.origin, _tokenId: _message.tokenId()})) {
                    revert NotApprovedOrOwner();
                }
            }
        } else if (command <= Commands.NOTIFY_WITHOUT_CLAIM) {
            uint256 amount = _message.amount();
            IXERC20(xerc20).burn({_user: address(this), _amount: amount});
        } else if (command <= Commands.GET_FEES) {
            if (VelodromeTimeLibrary.epochStart(block.timestamp) <= IVoter(voter).lastVoted(_message.rewardTokenId())) {
                revert AlreadyVotedOrDeposited();
            }
        }

        Mailbox(mailbox).dispatch{value: msg.value}({
            destinationDomain: domain,
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _message,
            metadata: _metadata,
            hook: IPostDispatchHook(_hook)
        });

        emit SentMessage({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: msg.value,
            _message: string(_message),
            _metadata: string(_metadata)
        });
    }

    /// @inheritdoc IRootHLMessageModule
    function setHook(address _hook) external {
        if (msg.sender != Ownable(bridge).owner()) revert NotBridgeOwner();
        hook = _hook;
        emit HookSet({_newHook: _hook});
    }

    function _generateGasMetadata(uint256 _command, address _hook) internal view returns (bytes memory) {
        /// @dev If custom hook is set, it should be used to estimate gas
        uint256 gasLimit =
            _hook == address(0) ? _command.gasLimit() : IHookGasEstimator(_hook).estimateGas({_command: _command});
        return StandardHookMetadata.formatMetadata({
            _msgValue: msg.value,
            _gasLimit: gasLimit,
            _refundAddress: tx.origin,
            _customMetadata: ""
        });
    }
}
