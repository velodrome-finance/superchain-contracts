// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {IPostDispatchHook} from "@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";

import {IHLHandler} from "../interfaces/bridge/hyperlane/IHLHandler.sol";
import {ITokenBridge} from "../interfaces/bridge/ITokenBridge.sol";
import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";
import {BaseTokenBridge} from "./BaseTokenBridge.sol";

import {Commands} from "../libraries/Commands.sol";

/*

██╗   ██╗███████╗██╗      ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗
██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔════╝
██║   ██║█████╗  ██║     ██║   ██║██║  ██║██████╔╝██║   ██║██╔████╔██║█████╗
╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██║  ██║██╔══██╗██║   ██║██║╚██╔╝██║██╔══╝
 ╚████╔╝ ███████╗███████╗╚██████╔╝██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║
███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

██╗     ███████╗ █████╗ ███████╗████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗
██║     ██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝
██║     █████╗  ███████║█████╗     ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗
██║     ██╔══╝  ██╔══██║██╔══╝     ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝
███████╗███████╗██║  ██║██║        ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗
╚══════╝╚══════╝╚═╝  ╚═╝╚═╝        ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝

*/

/// @title Velodrome Superchain Leaf Token Bridge
/// @notice General Purpose Leaf Token Bridge
contract LeafTokenBridge is BaseTokenBridge {
    using EnumerableSet for EnumerableSet.UintSet;
    using Commands for bytes;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism)
        BaseTokenBridge(_owner, _xerc20, _mailbox, _ism)
    {}

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint256 _chainid) external payable virtual override {
        bytes memory message = abi.encodePacked(_recipient, _amount);

        _send({_amount: _amount, _recipient: _recipient, _chainid: _chainid, _message: message});
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable virtual override {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_sender != TypeCasts.addressToBytes32(address(this))) revert NotBridge();
        if (!_chainids.contains({value: _origin})) revert NotRegistered();

        (address recipient, uint256 amount) = _message.recipientAndAmount();

        IXERC20(xerc20).mint({_user: recipient, _amount: amount});

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }

    function _send(uint256 _amount, address _recipient, uint256 _chainid, bytes memory _message) internal {
        if (_amount == 0) revert ZeroAmount();
        if (_recipient == address(0)) revert ZeroAddress();
        if (!_chainids.contains({value: _chainid})) revert NotRegistered();

        address _hook = hook;
        bytes memory metadata = _generateGasMetadata({_hook: _hook, _value: msg.value});

        uint32 domain = uint32(_chainid);
        uint256 fee = Mailbox(mailbox).quoteDispatch({
            destinationDomain: domain,
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _message,
            metadata: metadata,
            hook: IPostDispatchHook(_hook)
        });
        if (fee > msg.value) revert InsufficientBalance();

        IXERC20(xerc20).burn({_user: msg.sender, _amount: _amount});

        Mailbox(mailbox).dispatch{value: fee}({
            destinationDomain: domain,
            recipientAddress: TypeCasts.addressToBytes32(address(this)),
            messageBody: _message,
            metadata: metadata,
            hook: IPostDispatchHook(_hook)
        });

        uint256 leftover = msg.value - fee;
        if (leftover > 0) payable(msg.sender).transfer(leftover);

        emit SentMessage({
            _destination: domain,
            _recipient: TypeCasts.addressToBytes32(address(this)),
            _value: fee,
            _message: string(_message),
            _metadata: string(metadata)
        });
    }
}
