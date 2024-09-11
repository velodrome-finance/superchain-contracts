// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

interface ITokenBridge {
    error NotBridge();
    error ZeroAmount();
    error ZeroAddress();

    event SentMessage(uint32 indexed _destination, bytes32 indexed _recipient, uint256 _value, string _message);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
    function xerc20() external view returns (address);

    /// @notice Returns the address of the mailbox contract that is used to bridge by this contract
    function mailbox() external view returns (address);

    /// @notice Returns the address of the security module contract used by the bridge
    function securityModule() external view returns (IInterchainSecurityModule);

    /// @notice Burns xERC20 tokens from the sender and triggers a x-chain transfer
    /// @param _amount The amount of xERC20 tokens to send
    /// @param _chainid The chain id of the destination chain
    function sendToken(uint256 _amount, uint256 _chainid) external payable;
}
