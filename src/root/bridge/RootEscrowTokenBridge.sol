// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";

import {IVotingEscrow} from "../../interfaces/external/IVotingEscrow.sol";
import {IVoter} from "../../interfaces/external/IVoter.sol";
import {RootTokenBridge, BaseTokenBridge, ITokenBridge} from "./RootTokenBridge.sol";
import {IRootEscrowTokenBridge} from "../../interfaces/root/bridge/IRootEscrowTokenBridge.sol";
import {IRootHLMessageModule} from "../../interfaces/root/bridge/hyperlane/IRootHLMessageModule.sol";
import {IHLHandler} from "../../interfaces/bridge/hyperlane/IHLHandler.sol";
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

██████╗  ██████╗  ██████╗ ████████╗███████╗███████╗ ██████╗██████╗  ██████╗ ██╗    ██╗████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗
██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝██╔════╝██╔════╝██╔════╝██╔══██╗██╔═══██╗██║    ██║╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝
██████╔╝██║   ██║██║   ██║   ██║   █████╗  ███████╗██║     ██████╔╝██║   ██║██║ █╗ ██║   ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗
██╔══██╗██║   ██║██║   ██║   ██║   ██╔══╝  ╚════██║██║     ██╔══██╗██║   ██║██║███╗██║   ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝
██║  ██║╚██████╔╝╚██████╔╝   ██║   ███████╗███████║╚██████╗██║  ██║╚██████╔╝╚███╔███╔╝   ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗
╚═╝  ╚═╝ ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝

*/

/// @title Velodrome Superchain Root Escrow Token Bridge
/// @notice Root Token Bridge wrapper with escrow support
contract RootEscrowTokenBridge is RootTokenBridge, IRootEscrowTokenBridge {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using Commands for bytes;

    /// @inheritdoc IRootEscrowTokenBridge
    IVotingEscrow public immutable escrow;

    constructor(address _owner, address _xerc20, address _module, address _paymasterVault, address _ism)
        RootTokenBridge(_owner, _xerc20, _module, _paymasterVault, _ism)
    {
        escrow = IVotingEscrow(IVoter(IRootHLMessageModule(_module).voter()).ve());
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_sender != TypeCasts.addressToBytes32(address(this))) revert NotBridge();
        uint256 chainid = IRootHLMessageModule(module).chains({_domain: _origin});
        if (chainid == 0) chainid = _origin;
        if (!_chainids.contains({value: chainid})) revert NotRegistered();

        uint256 length = _message.length;
        if (length == Commands.SEND_TOKEN_LENGTH) {
            (address recipient, uint256 amount) = _message.recipientAndAmount();
            IXERC20(xerc20).mint({_user: address(this), _amount: amount});

            IERC20(xerc20).safeIncreaseAllowance({spender: address(lockbox), value: amount});
            lockbox.withdraw({_amount: amount});
            erc20.safeTransfer({to: recipient, value: amount});
        } else if (length == Commands.SEND_TOKEN_AND_LOCK_LENGTH) {
            (address recipient, uint256 amount, uint256 tokenId) = _message.sendTokenAndLockParams();
            IXERC20(xerc20).mint({_user: address(this), _amount: amount});

            IERC20(xerc20).safeIncreaseAllowance({spender: address(lockbox), value: amount});
            lockbox.withdraw({_amount: amount});
            erc20.safeIncreaseAllowance({spender: address(escrow), value: amount});
            try escrow.depositFor({_tokenId: tokenId, _value: amount}) {}
            catch {
                erc20.safeDecreaseAllowance({spender: address(escrow), requestedDecrease: amount});
                erc20.safeTransfer({to: recipient, value: amount});
            }
        } else {
            revert InvalidCommand();
        }

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }

    /// @inheritdoc ITokenBridge
    function GAS_LIMIT() public pure override(BaseTokenBridge, ITokenBridge) returns (uint256) {
        return 76_000;
    }
}
