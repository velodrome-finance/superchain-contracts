// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {StandardHookMetadata} from "@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol";
import {IPostDispatchHook} from "@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";

import {ISpecifiesInterchainSecurityModule} from "../interfaces/external/ISpecifiesInterchainSecurityModule.sol";
import {IHookGasEstimator} from "../interfaces/root/bridge/hyperlane/IHookGasEstimator.sol";
import {IHLHandler} from "../interfaces/bridge/hyperlane/IHLHandler.sol";
import {ITokenBridge} from "../interfaces/bridge/ITokenBridge.sol";
import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";

import {Commands} from "../libraries/Commands.sol";
import {ChainRegistry} from "./ChainRegistry.sol";

/// @title Token Bridge Contract
/// @notice General Purpose Token Bridge
contract TokenBridge is ITokenBridge, IHLHandler, ISpecifiesInterchainSecurityModule, ChainRegistry {
    using EnumerableSet for EnumerableSet.UintSet;
    using Commands for bytes;

    /// @inheritdoc ITokenBridge
    uint256 public constant GAS_LIMIT = 200_000;
    /// @inheritdoc ITokenBridge
    address public immutable xerc20;
    /// @inheritdoc ITokenBridge
    address public immutable mailbox;
    /// @inheritdoc ITokenBridge
    address public hook;
    /// @inheritdoc ITokenBridge
    IInterchainSecurityModule public securityModule;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism) ChainRegistry(_owner) {
        xerc20 = _xerc20;
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
        emit InterchainSecurityModuleSet({_new: _ism});
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule
    function interchainSecurityModule() external view returns (IInterchainSecurityModule) {
        return securityModule;
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule
    function setInterchainSecurityModule(address _ism) external onlyOwner {
        securityModule = IInterchainSecurityModule(_ism);
        emit InterchainSecurityModuleSet({_new: _ism});
    }

    /// @inheritdoc ITokenBridge
    function setHook(address _hook) external onlyOwner {
        hook = _hook;
        emit HookSet({_newHook: _hook});
    }

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint256 _chainid) external payable {
        if (_amount == 0) revert ZeroAmount();
        if (_recipient == address(0)) revert ZeroAddress();
        if (!_chainids.contains({value: _chainid})) revert NotRegistered();

        address _hook = hook;
        uint32 domain = uint32(_chainid);
        bytes memory message = abi.encodePacked(_recipient, _amount);
        bytes memory metadata = _generateGasMetadata({_hook: _hook});
        uint256 fee = Mailbox(mailbox).quoteDispatch({
            destinationDomain: domain,
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: message,
            metadata: metadata,
            hook: IPostDispatchHook(_hook)
        });
        if (fee > msg.value) revert InsufficientBalance();

        IXERC20(xerc20).burn({_user: msg.sender, _amount: _amount});

        Mailbox(mailbox).dispatch{value: fee}({
            destinationDomain: domain,
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: message,
            metadata: metadata,
            hook: IPostDispatchHook(_hook)
        });

        uint256 leftover = msg.value - fee;
        if (leftover > 0) payable(msg.sender).transfer(leftover);

        emit SentMessage({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: fee,
            _message: string(message),
            _metadata: string(metadata)
        });
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_sender != TypeCasts.addressToBytes32(address(this))) revert NotBridge();
        if (!_chainids.contains({value: _origin})) revert NotRegistered();

        (address recipient, uint256 amount) = _message.recipientAndAmount();

        IXERC20(xerc20).mint({_user: recipient, _amount: amount});

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }

    function _generateGasMetadata(address _hook) internal view returns (bytes memory) {
        /// @dev If custom hook is set, it should be used to estimate gas
        uint256 gasLimit = _hook == address(0) ? GAS_LIMIT : IHookGasEstimator(_hook).estimateSendTokenGas();
        return StandardHookMetadata.formatMetadata({
            _msgValue: msg.value,
            _gasLimit: gasLimit,
            _refundAddress: msg.sender,
            _customMetadata: ""
        });
    }
}
