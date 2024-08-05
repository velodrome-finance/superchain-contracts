// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";

import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";
import {IBridge} from "../interfaces/bridge/IBridge.sol";
import {ILeafGauge} from "../interfaces/gauges/ILeafGauge.sol";

/// @notice Bridge contract for use only by Velodrome contracts
contract Bridge is IBridge {
    using SafeERC20 for IERC20;

    /// @inheritdoc IBridge
    address public immutable xerc20;
    /// @inheritdoc IBridge
    address public immutable mailbox;
    /// @inheritdoc IBridge
    IInterchainSecurityModule public immutable securityModule;

    constructor(address _xerc20, address _mailbox, address _ism) {
        xerc20 = _xerc20;
        mailbox = _mailbox;
        securityModule = IInterchainSecurityModule(_ism);
    }

    /// @inheritdoc IBridge
    function transfer(uint256 _amount, uint32 _domain) external payable {
        IXERC20(xerc20).burn({_user: msg.sender, _amount: _amount});

        Mailbox(mailbox).dispatch({
            _destinationDomain: _domain,
            _recipientAddress: TypeCasts.addressToBytes32(address(this)),
            _messageBody: abi.encode(msg.sender, _amount)
        });

        emit SentMessage({
            _destination: _domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: msg.value,
            _message: string(abi.encode(msg.sender, _amount))
        });
    }

    /// @inheritdoc IBridge
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override {
        if (msg.sender != mailbox) revert NotMailbox();
        (address recipient, uint256 amount) = abi.decode(_message, (address, uint256));

        IXERC20(xerc20).mint({_user: address(this), _amount: amount});

        IERC20(xerc20).safeIncreaseAllowance({spender: recipient, value: amount});
        ILeafGauge(recipient).notifyRewardAmount({amount: amount});

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
