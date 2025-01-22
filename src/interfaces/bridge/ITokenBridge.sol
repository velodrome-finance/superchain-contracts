// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

interface ITokenBridge {
    error NotBridge();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();

    event HookSet(address indexed _newHook);
    event SentMessage(
        uint32 indexed _destination, bytes32 indexed _recipient, uint256 _value, string _message, string _metadata
    );

    /// @notice Max gas limit for token bridging transactions
    /// @dev Can set a different gas limit by using a custom hook
    function GAS_LIMIT() external view returns (uint256);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
    function xerc20() external view returns (address);

    /// @notice Returns the address of the mailbox contract that is used to bridge by this contract
    function mailbox() external view returns (address);

    /// @notice Returns the address of the hook contract used after dispatching a message
    /// @dev If set to zero address, default hook will be used instead
    function hook() external view returns (address);

    /// @notice Returns the address of the security module contract used by the bridge
    function securityModule() external view returns (IInterchainSecurityModule);

    /// @notice Sets the address of the hook contract that will be used in bridging
    /// @dev Can use default hook by setting to zero address
    /// @param _hook The address of the new hook contract
    function setHook(address _hook) external;

    /// @notice Burns xERC20 tokens from the sender and triggers a x-chain transfer
    /// @dev If bridging from/to Root, ERC20 tokens are wrapped into xERC20 for bridging and unwrapped back when received.
    /// @param _recipient The address of the recipient on the destination chain
    /// @param _amount The amount of xERC20 tokens to send
    /// @param _chainid The chain id of the destination chain
    function sendToken(address _recipient, uint256 _amount, uint256 _chainid) external payable;
}
