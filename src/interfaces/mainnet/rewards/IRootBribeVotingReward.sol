// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootBribeVotingReward {
    /// @notice Address of bridge contract used to forward messages
    function bridge() external view returns (address);
    /// @notice Address of voter contract that sets voting power
    function voter() external view returns (address);
}
