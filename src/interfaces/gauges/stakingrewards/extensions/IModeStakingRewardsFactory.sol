// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStakingRewardsFactory} from "../IStakingRewardsFactory.sol";

interface IModeStakingRewardsFactory is IStakingRewardsFactory {
    /// @notice Address of the fee sharing contract.
    /// @return Fee sharing contract address
    function sfs() external view returns (address);

    /// @notice Token Id that sequencer fees are sent to.
    /// @return Token Id
    function tokenId() external view returns (uint256);
}
