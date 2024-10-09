// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Ownable} from "@openzeppelin5/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {IHLHandler} from "../interfaces/bridge/hyperlane/IHLHandler.sol";
import {ITokenBridge} from "../interfaces/bridge/ITokenBridge.sol";
import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";
import {ISpecifiesInterchainSecurityModule} from "../interfaces/external/ISpecifiesInterchainSecurityModule.sol";

import {Commands} from "../libraries/Commands.sol";
import {ChainRegistry} from "./ChainRegistry.sol";

/// @title Token Bridge Contract
/// @notice General Purpose Token Bridge
contract TokenBridge is ITokenBridge, IHLHandler, ISpecifiesInterchainSecurityModule, ChainRegistry {
    using EnumerableSet for EnumerableSet.UintSet;
    using Commands for bytes;

    /// @inheritdoc ITokenBridge
    address public immutable xerc20;
    /// @inheritdoc ITokenBridge
    address public immutable mailbox;
    /// @inheritdoc ITokenBridge
    IInterchainSecurityModule public securityModule;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism) ChainRegistry(_owner) {
        xerc20 = _xerc20;
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

    /// @inheritdoc ITokenBridge
    function sendToken(uint256 _amount, uint256 _chainid) external payable {
        if (_amount == 0) revert ZeroAmount();
        if (!_chainids.contains({value: _chainid})) revert NotRegistered();

        IXERC20(xerc20).burn({_user: msg.sender, _amount: _amount});

        uint32 domain = uint32(_chainid);
        bytes memory message = abi.encodePacked(msg.sender, _amount);
        Mailbox(mailbox).dispatch{value: msg.value}({
            _destinationDomain: domain,
            _recipientAddress: TypeCasts.addressToBytes32(address(this)),
            _messageBody: message
        });

        emit SentMessage({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: msg.value,
            _message: string(message)
        });
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_sender != TypeCasts.addressToBytes32(address(this))) revert NotBridge();

        (address recipient, uint256 amount) = _message.recipientAndAmount();

        IXERC20(xerc20).mint({_user: recipient, _amount: amount});

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
