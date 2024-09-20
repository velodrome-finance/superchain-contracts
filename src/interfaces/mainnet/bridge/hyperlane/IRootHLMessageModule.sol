// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageSender} from "../IMessageSender.sol";

interface IRootHLMessageModule is IMessageSender {
    /// @notice Returns the address of the bridge contract that this module is associated with
    function bridge() external view returns (address);

    /// @notice Returns the address of the mailbox contract that is used to bridge by this contract
    function mailbox() external view returns (address);

    /// @notice Returns the nonce of the next message to be sent
    function sendingNonce() external view returns (uint256);
}
