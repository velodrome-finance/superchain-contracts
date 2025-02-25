// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITokenBridge} from "./ITokenBridge.sol";

interface ILeafEscrowTokenBridge is ITokenBridge {
    error InvalidCommand();
    error ZeroTokenId();

    /// @notice Returns the chain id of the root chain
    function ROOT_CHAINID() external returns (uint256);

    /// @notice Max gas limit for token bridging transactions with locking
    /// @dev Can set a different gas limit by using a custom hook
    function GAS_LIMIT_LOCK() external view returns (uint256);

    /// @notice Burns xERC20 tokens from the sender and triggers a x-chain transfer
    /// Unwrapped tokens are added to the lock with tokenId on root
    /// @dev If not possible to add to the lock, unwrapped tokens are sent to the recipient on root
    /// @param _recipient The address of the recipient on the root chain
    /// @param _amount The amount of xERC20 tokens to send
    /// @param _tokenId The token id of the lock to deposit tokens for on the root chain
    function sendTokenAndLock(address _recipient, uint256 _amount, uint256 _tokenId) external payable;
}
