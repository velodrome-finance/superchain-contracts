// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPostDispatchHook} from "@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";

import {ITokenBridge, BaseTokenBridge} from "../../bridge/BaseTokenBridge.sol";
import {IRootTokenBridge} from "../../interfaces/root/bridge/IRootTokenBridge.sol";
import {IRootHLMessageModule} from "../../interfaces/root/bridge/hyperlane/IRootHLMessageModule.sol";
import {IHLHandler} from "../../interfaces/bridge/hyperlane/IHLHandler.sol";
import {IXERC20Lockbox} from "../../interfaces/xerc20/IXERC20Lockbox.sol";
import {IXERC20} from "../../interfaces/xerc20/IXERC20.sol";

import {Commands} from "../../libraries/Commands.sol";

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

██████╗  ██████╗  ██████╗ ████████╗████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗
██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝
██████╔╝██║   ██║██║   ██║   ██║      ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗
██╔══██╗██║   ██║██║   ██║   ██║      ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝
██║  ██║╚██████╔╝╚██████╔╝   ██║      ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗
╚═╝  ╚═╝ ╚═════╝  ╚═════╝    ╚═╝      ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝

*/

/// @title Velodrome Superchain Root Token Bridge
/// @notice General Purpose Token Bridge
contract RootTokenBridge is BaseTokenBridge, IRootTokenBridge {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using Commands for bytes;

    /// @inheritdoc IRootTokenBridge
    IXERC20Lockbox public immutable lockbox;
    /// @inheritdoc IRootTokenBridge
    IERC20 public immutable erc20;

    /// @inheritdoc IRootTokenBridge
    address public module;

    constructor(address _owner, address _xerc20, address _module, address _ism)
        BaseTokenBridge(_owner, _xerc20, IRootHLMessageModule(_module).mailbox(), _ism)
    {
        lockbox = IXERC20Lockbox(IXERC20(_xerc20).lockbox());
        erc20 = lockbox.ERC20();
        module = _module;
    }

    /// @inheritdoc ITokenBridge
    function sendToken(address _recipient, uint256 _amount, uint256 _chainid)
        external
        payable
        virtual
        override(BaseTokenBridge, ITokenBridge)
    {
        if (_amount == 0) revert ZeroAmount();
        if (_recipient == address(0)) revert ZeroAddress();
        if (!_chainids.contains({value: _chainid})) revert NotRegistered();

        _send({_amount: _amount, _recipient: _recipient, _chainid: _chainid});
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable virtual override {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_sender != TypeCasts.addressToBytes32(address(this))) revert NotBridge();
        uint256 chainid = IRootHLMessageModule(module).chains({_domain: _origin});
        if (chainid == 0) chainid = _origin;
        if (!_chainids.contains({value: chainid})) revert NotRegistered();

        (address recipient, uint256 amount) = _message.recipientAndAmount();

        IXERC20(xerc20).mint({_user: address(this), _amount: amount});

        IERC20(xerc20).safeIncreaseAllowance({spender: address(lockbox), value: amount});
        lockbox.withdraw({_amount: amount});
        erc20.safeTransfer({to: recipient, value: amount});

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }

    /// @inheritdoc IRootTokenBridge
    function setModule(address _module) external onlyOwner {
        if (_module == address(0)) revert ZeroAddress();
        module = _module;
        emit ModuleSet({_sender: msg.sender, _module: _module});
    }

    function _send(uint256 _amount, address _recipient, uint256 _chainid) internal {
        uint32 domain = IRootHLMessageModule(module).domains({_chainid: _chainid});
        if (domain == 0) domain = uint32(_chainid);

        address _hook = hook;
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

        erc20.safeTransferFrom({from: msg.sender, to: address(this), value: _amount});
        erc20.safeIncreaseAllowance({spender: address(lockbox), value: _amount});
        lockbox.deposit({_amount: _amount});

        IXERC20(xerc20).burn({_user: address(this), _amount: _amount});

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
}
