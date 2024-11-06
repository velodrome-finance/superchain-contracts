// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageSender} from "../IMessageSender.sol";

interface IRootHLMessageModule is IMessageSender {
    error AlreadyVotedOrDeposited();
    error SpecialVotingWindow();
    error DistributeWindow();
    error NotBridgeOwner();

    event HookSet(address indexed _newHook);

    /// @notice Returns the address of the bridge contract that this module is associated with
    function bridge() external view returns (address);

    /// @notice Returns the address of the xerc20 contract that is used to bridge by this contract
    function xerc20() external view returns (address);

    /// @notice Returns the address of the mailbox contract that is used to bridge by this contract
    function mailbox() external view returns (address);

    /// @notice Returns the address of the voter contract that sets voting power
    function voter() external view returns (address);

    /// @notice Returns the address of the hook contract used after dispatching a message
    /// @dev If set to zero address, default hook will be used instead
    function hook() external view returns (address);

    /// @notice Sets the address of the hook contract that will be used in x-chain messages
    /// @dev Can use default hook by setting to zero address
    /// @param _hook The address of the new hook contract
    function setHook(address _hook) external;
}
