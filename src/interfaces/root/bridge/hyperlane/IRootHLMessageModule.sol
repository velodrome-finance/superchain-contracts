// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageSender} from "../IMessageSender.sol";

interface IRootHLMessageModule is IMessageSender {
    error AlreadyVotedOrDeposited();
    error SpecialVotingWindow();
    error DistributeWindow();
    error NotBridgeOwner();
    error DomainAlreadyAssigned();
    error InvalidChainID();

    event HookSet(address indexed _newHook);
    event DomainSet(uint256 indexed _chainid, uint32 _domain);

    /// @notice Returns the domain of the given chain id
    /// @param _chainid The chain id to get the domain for
    function domains(uint256 _chainid) external view returns (uint32);

    /// @notice Returns the chain id of the given domain
    /// @param _domain The domain to get the chain id for
    function chains(uint32 _domain) external view returns (uint256);

    /// @notice Returns the address of the bridge contract that this module is associated with
    function bridge() external view returns (address);

    /// @notice Returns the address of the xERC20 token that is bridged by this contract
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

    /// @notice Sets the domain of the given chain id
    /// @param _domain The domain to set
    /// @param _chainid The chain id to set the domain for
    function setDomain(uint256 _chainid, uint32 _domain) external;
}
