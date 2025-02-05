// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {TypeCasts} from "@hyperlane/core/contracts/libs/TypeCasts.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/IERC20.sol";

import {IHLHandler} from "../interfaces/bridge/hyperlane/IHLHandler.sol";
import {ILeafVoter} from "../interfaces/voter/ILeafVoter.sol";
import {IReward} from "../interfaces/rewards/IReward.sol";
import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";
import {IVoter} from "../interfaces/external/IVoter.sol";
import {ILeafRestrictedTokenBridge} from "../interfaces/bridge/ILeafRestrictedTokenBridge.sol";
import {LeafTokenBridge} from "./LeafTokenBridge.sol";
import {Commands} from "../libraries/Commands.sol";

/// @title Velodrome Superchain Leaf Restricted Token Bridge
/// @notice Token Bridge for Restricted XERC20 tokens on leaf chains
contract LeafRestrictedTokenBridge is LeafTokenBridge, ILeafRestrictedTokenBridge {
    using EnumerableSet for EnumerableSet.UintSet;
    using Commands for bytes;
    using SafeERC20 for IERC20;

    /// @inheritdoc ILeafRestrictedTokenBridge
    uint32 public constant BASE_CHAIN_ID = 8453;
    /// @inheritdoc ILeafRestrictedTokenBridge
    address public immutable voter;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism, address _voter)
        LeafTokenBridge(_owner, _xerc20, _mailbox, _ism)
    {
        voter = _voter;
    }

    /// @inheritdoc IHLHandler
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override {
        if (msg.sender != mailbox) revert NotMailbox();
        if (_sender != TypeCasts.addressToBytes32(address(this))) revert NotBridge();
        if (!_chainids.contains({value: _origin})) revert NotRegistered();

        (address recipient, uint256 amount) = _message.recipientAndAmount();
        address incentiveReward = block.chainid == BASE_CHAIN_ID
            ? IVoter(voter).gaugeToBribe({_gauge: recipient})
            : ILeafVoter(voter).gaugeToIncentive({_gauge: recipient});

        if (incentiveReward != address(0)) {
            IXERC20(xerc20).mint({_user: address(this), _amount: amount});
            IERC20(xerc20).safeIncreaseAllowance({spender: incentiveReward, value: amount});
            IReward(incentiveReward).notifyRewardAmount({token: xerc20, amount: amount});
        } else {
            // should only be reachable on chain id 8453
            IXERC20(xerc20).mint({_user: recipient, _amount: amount});
        }

        emit ReceivedMessage({_origin: _origin, _sender: _sender, _value: msg.value, _message: string(_message)});
    }
}
