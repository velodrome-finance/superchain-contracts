// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

import {IMessageSender} from "../IMessageSender.sol";

interface IHLMessageBridge is IMessageSender {
    error NotBridge();
    error InvalidCommand();
    error NotModule();

    event SentMessage(uint32 indexed _destination, bytes32 indexed _recipient, uint256 _value, string _message);

    /// @notice Returns the address of the bridge contract that this module is associated with
    function bridge() external view returns (address);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
    function xerc20() external view returns (address);

    /// @notice Returns voter on current chain
    function voter() external view returns (address);

    /// @notice Returns the address of the mailbox contract that is used to bridge by this contract
    function mailbox() external view returns (address);

    /// @notice Returns the address of the security module contract used by the bridge
    function securityModule() external view returns (IInterchainSecurityModule);
}
