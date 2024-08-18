// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVotingRewardsFactory {
    error NotVoter();

    /// @notice Returns the address of the voter contract
    /// @return Address of the voter contract
    function voter() external view returns (address);

    /// @notice Returns the address of the bridge contract
    /// @return Address of the bridge contract
    function bridge() external view returns (address);

    /// @notice creates a BribeVotingReward and a FeesVotingReward contract for a gauge
    /// @param _rewards Addresses of pool tokens to be used as valid rewards tokens
    /// @return feesVotingReward Address of FeesVotingReward contract created
    /// @return bribeVotingReward Address of BribeVotingReward contract created
    function createRewards(address[] memory _rewards)
        external
        returns (address feesVotingReward, address bribeVotingReward);
}
