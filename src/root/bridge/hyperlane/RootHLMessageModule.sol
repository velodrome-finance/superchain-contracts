// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {StandardHookMetadata} from "@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol";
import {IPostDispatchHook} from "@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol";
import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";

import {
    IRootHLMessageModule, IMessageSender
} from "../../../interfaces/root/bridge/hyperlane/IRootHLMessageModule.sol";
import {IHookGasEstimator} from "../../../interfaces/root/bridge/hyperlane/IHookGasEstimator.sol";
import {IRootMessageBridge} from "../../../interfaces/root/bridge/IRootMessageBridge.sol";
import {IVoter} from "../../../interfaces/external/IVoter.sol";
import {IXERC20} from "../../../interfaces/xerc20/IXERC20.sol";
import {Paymaster} from "./Paymaster.sol";
import {GasRouter} from "./GasRouter.sol";

import {VelodromeTimeLibrary} from "../../../libraries/VelodromeTimeLibrary.sol";
import {Commands} from "../../../libraries/Commands.sol";

/// @title Root Hyperlane Message Module
/// @notice Hyperlane module used to bridge arbitrary messages between chains
contract RootHLMessageModule is IRootHLMessageModule, Paymaster, GasRouter {
    using EnumerableSet for EnumerableSet.AddressSet;
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
    address public hook;
    /// @inheritdoc IRootHLMessageModule
    mapping(uint256 => uint32) public domains;
    /// @inheritdoc IRootHLMessageModule
    mapping(uint32 => uint256) public chains;

    constructor(
        address _bridge,
        address _mailbox,
        address _paymasterVault,
        uint256[] memory _commands,
        uint256[] memory _gasLimits
    ) Paymaster(_paymasterVault) GasRouter(Ownable(_bridge).owner(), _commands, _gasLimits) {
        bridge = _bridge;
        xerc20 = IRootMessageBridge(_bridge).xerc20();
        mailbox = _mailbox;
        voter = IRootMessageBridge(_bridge).voter();
    }

    /// @dev Overrides Paymaster access control
    modifier onlyWhitelistManager() override {
        if (msg.sender != Ownable(bridge).owner()) revert NotBridgeOwner();
        _;
    }

    /// @inheritdoc IMessageSender
    function quote(uint256 _destinationDomain, bytes calldata _messageBody) external view returns (uint256) {
        uint256 command = _messageBody.command();
        /// @dev If sponsoring is required, no quote is returned
        if (_requiresSponsoring({_command: command})) {
            return 0;
        }
        address _hook = hook;
        bytes memory _metadata = _generateGasMetadata({_command: command, _hook: _hook, _value: 0});

        return Mailbox(mailbox).quoteDispatch({
            destinationDomain: uint32(_destinationDomain),
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _messageBody,
            metadata: _metadata,
            hook: IPostDispatchHook(_hook)
        });
    }

    /// @inheritdoc IRootHLMessageModule
    function setDomain(uint256 _chainid, uint32 _domain) external {
        if (msg.sender != Ownable(bridge).owner()) revert NotBridgeOwner();
        if (_chainid == 0) revert InvalidChainID();
        if (chains[_domain] != 0) revert DomainAlreadyAssigned();
        delete chains[domains[_chainid]];
        domains[_chainid] = _domain;
        if (_domain != 0) {
            chains[_domain] = _chainid;
        }
        emit DomainSet({_chainid: _chainid, _domain: _domain});
    }

    /// @inheritdoc IMessageSender
    function sendMessage(uint256 _chainid, bytes calldata _message) external payable override {
        if (msg.sender != bridge) revert NotBridge();
        uint32 domain = domains[_chainid];
        if (domain == 0) domain = uint32(_chainid);

        address _hook = hook;
        uint256 command = _message.command();
        bytes memory _metadata = _generateGasMetadata({_command: command, _hook: _hook, _value: msg.value});

        if (command <= Commands.NOTIFY_WITHOUT_CLAIM) {
            uint256 amount = _message.amount();
            IXERC20(xerc20).burn({_user: address(this), _amount: amount});
        } else if (command <= Commands.GET_FEES) {
            if (block.timestamp > VelodromeTimeLibrary.epochVoteEnd(block.timestamp)) revert SpecialVotingWindow();
            if (block.timestamp <= VelodromeTimeLibrary.epochVoteStart(block.timestamp)) revert DistributeWindow();
            if (VelodromeTimeLibrary.epochStart(block.timestamp) <= IVoter(voter).lastVoted(_message.tokenId())) {
                revert AlreadyVotedOrDeposited();
            }
        }

        /// @dev If sponsoring is required, fetch quote & pull funds from vault
        uint256 fee;
        if (_requiresSponsoring({_command: command})) {
            fee = Mailbox(mailbox).quoteDispatch({
                destinationDomain: domain,
                recipientAddress: TypeCasts.addressToBytes32(address(this)),
                messageBody: _message,
                metadata: _metadata,
                hook: IPostDispatchHook(_hook)
            });
            if (fee > 0) {
                _metadata = _generateGasMetadata({_command: command, _hook: _hook, _value: fee});
                _sponsorTransaction({_fee: fee});
            }
        } else {
            fee = msg.value;
        }

        Mailbox(mailbox).dispatch{value: fee}({
            destinationDomain: domain,
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _message,
            metadata: _metadata,
            hook: IPostDispatchHook(_hook)
        });

        emit SentMessage({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: fee,
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

    /// @dev Helper to check if x-chain transaction requires sponsoring
    function _requiresSponsoring(uint256 _command) internal view returns (bool) {
        /// @dev Sponsor transactions from whitelisted addresses or for the Notify command during distribute window
        return (_command == Commands.NOTIFY && block.timestamp <= VelodromeTimeLibrary.epochVoteStart(block.timestamp))
            || _whitelist.contains(tx.origin);
    }

    function _generateGasMetadata(uint256 _command, address _hook, uint256 _value)
        internal
        view
        returns (bytes memory)
    {
        /// @dev If custom hook is set, it should be used to estimate gas
        uint256 gasLimit =
            _hook == address(0) ? gasLimit[_command] : IHookGasEstimator(_hook).estimateGas({_command: _command});
        return StandardHookMetadata.formatMetadata({
            _msgValue: _value,
            _gasLimit: gasLimit,
            _refundAddress: tx.origin,
            _customMetadata: ""
        });
    }
}
