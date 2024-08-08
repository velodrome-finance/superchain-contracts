// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBridge} from "../../interfaces/bridge/IBridge.sol";
import {IHLTokenBridge, ITokenBridge} from "../../interfaces/bridge/hyperlane/IHLTokenBridge.sol";

/// @title Hyperlane Token Bridge
/// @notice Bridge used by Velodrome contracts to bridge emissions
contract HLTokenBridge is IHLTokenBridge {
    using SafeERC20 for IERC20;

    /// @inheritdoc IHLTokenBridge
    address public immutable bridge;
    /// @inheritdoc IHLTokenBridge
    address public immutable mailbox;
    /// @inheritdoc IHLTokenBridge
    IInterchainSecurityModule public immutable securityModule;

    constructor(address _bridge, address _mailbox, address _ism) {
        bridge = _bridge;
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
    }

    /// @inheritdoc ITokenBridge
    function transfer(address _sender, uint256 _amount, uint256 _chainid) external payable override {
        /// TODO: rename? due to clash with transfer on erc20
        if (msg.sender != bridge) revert NotBridge();
        uint32 domain = uint32(_chainid);
        bytes memory message = abi.encode(_sender, _amount);
        Mailbox(mailbox).dispatch({
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

    /// @inheritdoc IHLTokenBridge
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        (address recipient, uint256 amount) = abi.decode(_message, (address, uint256));

        IBridge(bridge).mint({_user: address(bridge), _amount: amount});

        IBridge(bridge).notify({_recipient: recipient, _amount: amount});

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
