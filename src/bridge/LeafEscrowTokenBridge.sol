// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {StandardHookMetadata} from "@hyperlane/core/contracts/hooks/libs/StandardHookMetadata.sol";

import {IHookGasEstimator} from "../interfaces/root/bridge/hyperlane/IHookGasEstimator.sol";
import {ILeafEscrowTokenBridge} from "../interfaces/bridge/ILeafEscrowTokenBridge.sol";
import {LeafTokenBridge, BaseTokenBridge, ITokenBridge} from "./LeafTokenBridge.sol";

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

██╗     ███████╗ █████╗ ███████╗███████╗███████╗ ██████╗██████╗  ██████╗ ██╗    ██╗████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗
██║     ██╔════╝██╔══██╗██╔════╝██╔════╝██╔════╝██╔════╝██╔══██╗██╔═══██╗██║    ██║╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝
██║     █████╗  ███████║█████╗  █████╗  ███████╗██║     ██████╔╝██║   ██║██║ █╗ ██║   ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗  
██║     ██╔══╝  ██╔══██║██╔══╝  ██╔══╝  ╚════██║██║     ██╔══██╗██║   ██║██║███╗██║   ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝  
███████╗███████╗██║  ██║██║     ███████╗███████║╚██████╗██║  ██║╚██████╔╝╚███╔███╔╝   ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗
╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝

*/

/// @title Velodrome Superchain Leaf Escrow Token Bridge
/// @notice Leaf Token Bridge wrapper with escrow support
contract LeafEscrowTokenBridge is LeafTokenBridge, ILeafEscrowTokenBridge {
    /// @inheritdoc ILeafEscrowTokenBridge
    uint256 public constant ROOT_CHAINID = 10;

    constructor(address _owner, address _xerc20, address _mailbox, address _ism)
        LeafTokenBridge(_owner, _xerc20, _mailbox, _ism)
    {}

    /// @inheritdoc ILeafEscrowTokenBridge
    function sendTokenAndLock(address _recipient, uint256 _amount, uint256 _tokenId) external payable {
        if (_tokenId == 0) revert ZeroTokenId();
        bytes memory message = abi.encodePacked(_recipient, _amount, _tokenId);

        _send({_amount: _amount, _recipient: _recipient, _chainid: ROOT_CHAINID, _message: message});
    }

    function _generateGasMetadata(address _hook, uint256 _value, bytes memory _message)
        internal
        view
        override
        returns (bytes memory)
    {
        uint256 gasLimit;
        uint256 length = _message.length;
        /// @dev If custom hook is set, it should be used to estimate gas
        if (length == Commands.SEND_TOKEN_LENGTH) {
            gasLimit = _hook == address(0) ? GAS_LIMIT() : IHookGasEstimator(_hook).estimateSendTokenGas();
        } else if (length == Commands.SEND_TOKEN_AND_LOCK_LENGTH) {
            gasLimit = _hook == address(0) ? GAS_LIMIT_LOCK() : IHookGasEstimator(_hook).estimateSendTokenAndLockGas();
        } else {
            revert InvalidCommand();
        }

        return StandardHookMetadata.formatMetadata({
            _msgValue: _value,
            _gasLimit: gasLimit,
            _refundAddress: msg.sender,
            _customMetadata: ""
        });
    }

    /// @inheritdoc ITokenBridge
    function GAS_LIMIT() public pure override(BaseTokenBridge, ITokenBridge) returns (uint256) {
        return 190_000;
    }

    /// @inheritdoc ILeafEscrowTokenBridge
    function GAS_LIMIT_LOCK() public pure returns (uint256) {
        return 432_000;
    }
}
