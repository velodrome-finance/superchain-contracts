// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageRecipient} from "@hyperlane/core/contracts/interfaces/IMessageRecipient.sol";
import {IInterchainSecurityModule} from "@hyperlane/core/contracts/interfaces/IInterchainSecurityModule.sol";

interface IBridge is IMessageRecipient {
    error NotMailbox();
    error NotValidGauge();

    event SentMessage(uint32 indexed _destination, bytes32 indexed _recipient, uint256 _value, string _message);
    event ReceivedMessage(uint32 indexed _origin, bytes32 indexed _sender, uint256 _value, string _message);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
    function xerc20() external view returns (address);

    /// @notice Returns the address of the mailbox contract that is used to bridge by this contract
    function mailbox() external view returns (address);

    /// @notice Returns the address of the security module contract used by the bridge
    function securityModule() external view returns (IInterchainSecurityModule);

    /// @notice Callback function used by the mailbox contract to handle incoming messages
    /// @param _origin The domain from which the message originates
    /// @param _sender The address of the sender of the message
    /// @param _message The message payload
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable override;

    /// @notice Transfers an amount of the bridged token to the destination domain
    /// @dev Requires approval for amount in order to bridge
    /// @dev Tokens are sent to the same address as msg.sender
    /// @param _amount The amount of the xERC20 token to transfer
    /// @param _domain The domain to which the tokens should be sent
    function transfer(uint256 _amount, uint32 _domain) external payable;
}
